from typing import Optional, List
import hashlib
import time
import base64
import asyncio
import threading
import io
import wave

import dashscope
from dashscope.audio.qwen_tts_realtime import QwenTtsRealtime, QwenTtsRealtimeCallback, AudioFormat

from app.core.config import settings


# 通义千问 TTS 音色映射
# 参考: 通义千问说明.md (支持的音色列表)
VOICE_MAP = {
    "en-US-female": "Serena",
    "en-US-male": "Ethan",
    "zh-CN-female": "Serena",
    "zh-CN-male": "Ethan",
}

DEFAULT_VOICE = "Serena"
DEFAULT_SAMPLE_RATE = 24000
DEFAULT_CHANNELS = 1
DEFAULT_SAMPLE_WIDTH = 2  # 16-bit
DEFAULT_AUDIO_FORMAT = AudioFormat.PCM_24000HZ_MONO_16BIT
DEFAULT_MODEL = settings.QWEN_TTS_MODEL
DEFAULT_WS_URL = settings.QWEN_TTS_WS_URL
DEFAULT_TIMEOUT_SEC = 60


class _QwenTtsCollector(QwenTtsRealtimeCallback):
    def __init__(self) -> None:
        super().__init__()
        self._chunks: List[bytes] = []
        self._done = threading.Event()
        self.error: Optional[str] = None

    def on_close(self, close_status_code, close_msg) -> None:
        if close_status_code != 1000 and not self._done.is_set():
            self.error = f"connection closed: {close_status_code} {close_msg}"
        self._done.set()

    def on_event(self, response: dict) -> None:
        try:
            event_type = response.get("type")
            if event_type == "response.audio.delta":
                delta = response.get("delta")
                if delta:
                    self._chunks.append(base64.b64decode(delta))
            elif event_type in ("response.done", "session.finished"):
                self._done.set()
        except Exception as e:
            self.error = str(e)
            self._done.set()

    def wait(self, timeout: float) -> bool:
        return self._done.wait(timeout)

    def audio(self) -> bytes:
        return b"".join(self._chunks)


def _pcm_to_wav(pcm_data: bytes) -> bytes:
    with io.BytesIO() as buffer:
        with wave.open(buffer, "wb") as wf:
            wf.setnchannels(DEFAULT_CHANNELS)
            wf.setsampwidth(DEFAULT_SAMPLE_WIDTH)
            wf.setframerate(DEFAULT_SAMPLE_RATE)
            wf.writeframes(pcm_data)
        return buffer.getvalue()


async def text_to_speech(text: str, voice: str = "en-US-female") -> Optional[str]:
    """
    使用通义千问 TTS 合成语音，返回 Base64 编码的音频数据 URL
    """
    if not settings.DASHSCOPE_API_KEY:
        text_hash = hashlib.md5(text.encode()).hexdigest()[:8]
        timestamp = int(time.time())
        return f"https://tts.placeholder.com/audio/{text_hash}_{timestamp}.wav"

    try:
        audio_data = await _qwen_tts(text, voice)
        if audio_data:
            audio_base64 = base64.b64encode(audio_data).decode("utf-8")
            return f"data:audio/wav;base64,{audio_base64}"
        return None
    except Exception as e:
        print(f"TTS failed: {e}")
        return None


async def text_to_speech_bytes(text: str, voice: str = "en-US-female") -> Optional[bytes]:
    """
    使用通义千问 TTS 合成语音，返回原始音频字节
    """
    if not settings.DASHSCOPE_API_KEY:
        return None

    try:
        return await _qwen_tts(text, voice)
    except Exception as e:
        print(f"TTS bytes failed: {e}")
        return None


async def _qwen_tts(text: str, voice: str) -> Optional[bytes]:
    """
    使用 DashScope SDK 调用通义千问实时语音合成
    """
    def sync_tts():
        dashscope.api_key = settings.DASHSCOPE_API_KEY

        # 映射音色（支持直接传入通义千问音色）
        speaker = VOICE_MAP.get(voice, voice or DEFAULT_VOICE)

        callback = _QwenTtsCollector()
        qwen_tts = QwenTtsRealtime(
            model=DEFAULT_MODEL,
            callback=callback,
            url=DEFAULT_WS_URL
        )

        qwen_tts.connect()
        qwen_tts.update_session(
            voice=speaker,
            response_format=DEFAULT_AUDIO_FORMAT,
            mode="commit"
        )

        qwen_tts.append_text(text)
        qwen_tts.commit()

        finished = callback.wait(timeout=DEFAULT_TIMEOUT_SEC)
        qwen_tts.finish()

        if not finished or callback.error:
            raise RuntimeError(callback.error or "TTS timeout")

        pcm_audio = callback.audio()
        if not pcm_audio:
            return None

        return _pcm_to_wav(pcm_audio)

    try:
        loop = asyncio.get_running_loop()
        audio_data = await loop.run_in_executor(None, sync_tts)

        if audio_data:
            print(f"TTS success: {len(audio_data)} bytes for '{text[:30]}...'")
            return audio_data
        else:
            print(f"TTS returned empty audio for '{text[:30]}...'")
            return None

    except Exception as e:
        print(f"Qwen TTS error: {e}")
        return None
