import hashlib
import time
from typing import Dict, Optional, Tuple

import dashscope
from dashscope import Generation

from app.core.config import settings

_TRANSLATION_PROMPT = """You are a professional translator.
Translate the user's text into Simplified Chinese.
Return only the Chinese translation, no extra punctuation, no quotes, no explanations."""

_CACHE: Dict[str, Dict[str, Tuple[str, float]]] = {}
_SESSION_ACCESS: Dict[str, float] = {}

_MAX_SESSIONS = 200
_MAX_ITEMS_PER_SESSION = 200
_SESSION_TTL_SEC = 2 * 60 * 60


def _now() -> float:
    return time.time()


def _cleanup_cache() -> None:
    now = _now()
    # Remove expired sessions
    expired_sessions = [sid for sid, ts in _SESSION_ACCESS.items() if now - ts > _SESSION_TTL_SEC]
    for sid in expired_sessions:
        _SESSION_ACCESS.pop(sid, None)
        _CACHE.pop(sid, None)

    # Enforce max sessions
    if len(_SESSION_ACCESS) > _MAX_SESSIONS:
        for sid, _ in sorted(_SESSION_ACCESS.items(), key=lambda item: item[1])[: len(_SESSION_ACCESS) - _MAX_SESSIONS]:
            _SESSION_ACCESS.pop(sid, None)
            _CACHE.pop(sid, None)

    # Enforce per-session size
    for sid, items in list(_CACHE.items()):
        if len(items) > _MAX_ITEMS_PER_SESSION:
            # Drop oldest items in this session
            sorted_items = sorted(items.items(), key=lambda item: item[1][1])
            for key, _ in sorted_items[: len(items) - _MAX_ITEMS_PER_SESSION]:
                items.pop(key, None)


def _normalize_text(text: str) -> str:
    return " ".join(text.strip().split())


def _cache_key(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _clean_translation(text: str) -> str:
    cleaned = text.strip()
    if (cleaned.startswith("\"") and cleaned.endswith("\"")) or (
        cleaned.startswith("'") and cleaned.endswith("'")
    ):
        cleaned = cleaned[1:-1].strip()
    return cleaned


async def translate_to_zh(text: str, session_id: Optional[str]) -> Optional[str]:
    if not text or not text.strip():
        return None

    dashscope.api_key = settings.DASHSCOPE_API_KEY
    normalized = _normalize_text(text)
    key = _cache_key(normalized)
    session_key = session_id or "default"

    _cleanup_cache()
    _SESSION_ACCESS[session_key] = _now()

    session_cache = _CACHE.setdefault(session_key, {})
    if key in session_cache:
        cached_text, _ = session_cache[key]
        session_cache[key] = (cached_text, _now())
        return cached_text

    try:
        response = Generation.call(
            model="qwen-turbo",
            messages=[
                {"role": "system", "content": _TRANSLATION_PROMPT},
                {"role": "user", "content": normalized},
            ],
            temperature=0,
        )

        if response.status_code != 200:
            print(f"Translate API error: {response.message}")
            return None

        translation = _clean_translation(getattr(response.output, "text", "") or "")
        if translation:
            session_cache[key] = (translation, _now())
        return translation or None

    except Exception as e:
        print(f"Translate failed: {e}")
        return None
