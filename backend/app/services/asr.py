"""
语音识别服务 - 使用通义千问 SenseVoice
支持自动断句和标点
"""
import base64
import asyncio
import struct
from typing import Optional, Tuple

import dashscope
from dashscope.audio.asr import Recognition

from app.core.config import settings


def parse_wav_header(audio_data: bytes) -> Tuple[int, int, int]:
    """
    解析 WAV 文件头，获取采样率、通道数、位深度

    Returns:
        (sample_rate, channels, bits_per_sample)
    """
    try:
        # WAV header structure:
        # 0-3: "RIFF"
        # 4-7: file size - 8
        # 8-11: "WAVE"
        # 12-15: "fmt "
        # 16-19: fmt chunk size (16 for PCM)
        # 20-21: audio format (1 = PCM)
        # 22-23: num channels
        # 24-27: sample rate
        # 28-31: byte rate
        # 32-33: block align
        # 34-35: bits per sample

        if len(audio_data) < 44:
            return 16000, 1, 16  # 默认值

        # 验证 RIFF 和 WAVE 标识
        if audio_data[0:4] != b'RIFF' or audio_data[8:12] != b'WAVE':
            print("[ASR] Invalid WAV file format")
            return 16000, 1, 16

        channels = struct.unpack('<H', audio_data[22:24])[0]
        sample_rate = struct.unpack('<I', audio_data[24:28])[0]
        bits_per_sample = struct.unpack('<H', audio_data[34:36])[0]

        print(f"[ASR] WAV info: {sample_rate}Hz, {channels}ch, {bits_per_sample}bit")
        return sample_rate, channels, bits_per_sample

    except Exception as e:
        print(f"[ASR] Error parsing WAV header: {e}")
        return 16000, 1, 16


async def transcribe_audio(
    audio_data: bytes,
    language: str = "en",
    add_punctuation: bool = True
) -> Optional[str]:
    """
    使用 SenseVoice 识别音频并返回带标点的文本

    Args:
        audio_data: WAV 格式的音频数据
        language: 语言代码 ("en" 英语, "zh" 中文)
        add_punctuation: 是否添加标点

    Returns:
        识别结果文本（带标点），失败返回 None
    """
    if not settings.DASHSCOPE_API_KEY:
        print("[ASR] No DASHSCOPE_API_KEY configured")
        return None

    # 解析 WAV 获取实际采样率
    sample_rate, channels, bits = parse_wav_header(audio_data)

    def sync_recognize():
        dashscope.api_key = settings.DASHSCOPE_API_KEY

        try:
            audio_base64 = base64.b64encode(audio_data).decode("utf-8")

            # 使用 SenseVoice 模型 - 原生支持标点、情感、语种识别
            recognition = Recognition(
                model="sensevoice-v1",
                format="wav",
                sample_rate=sample_rate,  # 使用实际采样率
                language_hints=[language] if language else None,
            )

            result = recognition.call(audio_content=audio_base64)

            if result.status_code != 200:
                print(f"[ASR] Recognition failed: {result.status_code} - {result.message}")
                print(f"[ASR] Full response: {result}")
                return None

            output = result.output
            if not output:
                print("[ASR] No output in response")
                return None

            print(f"[ASR] Output: {output}")

            # SenseVoice 返回格式
            sentence = output.get("sentence", {})
            text = sentence.get("text", "")

            if text:
                return text

            # 备选：尝试其他字段
            if "text" in output:
                return output["text"]

            return None

        except Exception as e:
            print(f"[ASR] Error: {e}")
            import traceback
            traceback.print_exc()
            return None

    try:
        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(None, sync_recognize)
        return result
    except Exception as e:
        print(f"[ASR] Async error: {e}")
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
