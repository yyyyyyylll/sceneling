"""
语音识别服务 - 使用 AI 添加标点分句
由于 DashScope ASR 不支持 base64 直接上传，
采用 iOS 原生识别 + qwen-turbo 添加标点的方案
"""
import asyncio
from typing import Optional

import dashscope
from dashscope import Generation

from app.core.config import settings


async def add_punctuation(text: str, language: str = "en") -> str:
    """
    使用 qwen-turbo 给文本添加标点和分句

    Args:
        text: 无标点的文本
        language: 语言代码 ("en" 英语, "zh" 中文)

    Returns:
        添加标点后的文本
    """
    if not text or not text.strip():
        return text

    if not settings.DASHSCOPE_API_KEY:
        print("[ASR] No DASHSCOPE_API_KEY configured")
        return text

    def sync_call():
        dashscope.api_key = settings.DASHSCOPE_API_KEY

        if language == "zh":
            system_prompt = "你是一个文本格式化助手。请给用户的文本添加正确的标点符号（句号、问号、逗号等）。只输出格式化后的文本，不要添加任何解释。"
        else:
            system_prompt = """You are a text punctuation assistant. Your task is to add proper punctuation marks to the user's text.

Rules:
1. Add periods (.) at the end of statements
2. Add question marks (?) at the end of questions
3. Add commas (,) where appropriate for natural pauses
4. Capitalize the first letter of each sentence
5. Capitalize proper nouns (names, places)
6. Fix contractions (dont -> don't, Im -> I'm, etc.)

IMPORTANT: Only output the punctuated text, nothing else. Do not add quotation marks around the result."""

        try:
            response = Generation.call(
                model='qwen-plus',
                messages=[
                    {'role': 'system', 'content': system_prompt},
                    {'role': 'user', 'content': text}
                ]
            )

            if response.status_code == 200:
                result = response.output.get('text', text)
                # 移除可能添加的引号
                result = result.strip('"\'')
                print(f"[ASR] Punctuation added: '{text}' -> '{result}'")
                return result
            else:
                print(f"[ASR] Punctuation API error: {response.message}")
                return text

        except Exception as e:
            print(f"[ASR] Punctuation error: {e}")
            return text

    try:
        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(None, sync_call)
        return result
    except Exception as e:
        print(f"[ASR] Async error: {e}")
        return text


async def transcribe_audio(
    audio_data: bytes,
    language: str = "en",
    add_punctuation_flag: bool = True
) -> Optional[str]:
    """
    此函数保留用于兼容性，但实际上 DashScope ASR 不支持 base64 上传。
    建议使用 iOS 原生识别 + add_punctuation() 的方案。

    Returns:
        None (ASR 功能不可用)
    """
    print("[ASR] Note: DashScope ASR does not support base64 upload.")
    print("[ASR] Please use iOS native recognition + add_punctuation() instead.")
    return None


async def transcribe_audio_with_timestamps(
    audio_data: bytes,
    language: str = "en"
) -> Optional[dict]:
    """
    识别音频并返回带时间戳的分句结果

    Returns:
        {
            "text": "完整文本",
            "words": [...]
        }
    """
    if not settings.DASHSCOPE_API_KEY:
        return None

    # 解析 WAV 获取实际采样率
    sample_rate, _, _ = parse_wav_header(audio_data)

    def sync_recognize():
        dashscope.api_key = settings.DASHSCOPE_API_KEY

        try:
            audio_base64 = base64.b64encode(audio_data).decode("utf-8")

            # 使用 SenseVoice 模型
            recognition = Recognition(
                model="sensevoice-v1",
                format="wav",
                sample_rate=sample_rate,  # 使用实际采样率
                language_hints=[language] if language else None,
            )

            result = recognition.call(audio_content=audio_base64)

            if result.status_code != 200:
                return None

            output = result.output
            if not output:
                return None

            sentence = output.get("sentence", {})
            text = sentence.get("text", "")
            words = sentence.get("words", [])

            return {
                "text": text,
                "words": words
            }

        except Exception as e:
            print(f"[ASR] Error: {e}")
            return None

    try:
        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(None, sync_recognize)
        return result
    except Exception as e:
        print(f"[ASR] Async error: {e}")
        return None
