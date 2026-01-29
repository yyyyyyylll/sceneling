"""
语音识别 API
"""
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
from typing import Optional

from app.services.asr import transcribe_audio, transcribe_audio_with_timestamps

router = APIRouter()


class ASRResponse(BaseModel):
    text: str
    success: bool = True


class ASRDetailedResponse(BaseModel):
    text: str
    words: list = []
    success: bool = True


@router.post("", response_model=ASRResponse)
async def speech_to_text(
    audio: UploadFile = File(..., description="WAV 格式音频文件"),
    language: str = Form(default="en", description="语言代码: en/zh")
):
    """
    语音识别 - 将音频转换为文本（带标点分句）

    - 支持 WAV 格式
    - 自动添加标点符号
    - 支持英语(en)和中文(zh)
    """
    # 验证文件类型
    if not audio.content_type or "audio" not in audio.content_type:
        # 允许 application/octet-stream（iOS 可能发送这个）
        if audio.content_type != "application/octet-stream":
            raise HTTPException(
                status_code=400,
                detail=f"Invalid file type: {audio.content_type}. Expected audio file."
            )

    # 读取音频数据
    audio_data = await audio.read()
    if not audio_data:
        raise HTTPException(status_code=400, detail="Empty audio file")

    # 调用 ASR 服务
    result = await transcribe_audio(audio_data, language=language)

    if result is None:
        raise HTTPException(status_code=500, detail="Speech recognition failed")

    return ASRResponse(text=result, success=True)


@router.post("/detailed", response_model=ASRDetailedResponse)
async def speech_to_text_detailed(
    audio: UploadFile = File(..., description="WAV 格式音频文件"),
    language: str = Form(default="en", description="语言代码: en/zh")
):
    """
    语音识别（详细版）- 返回带时间戳的结果
    """
    audio_data = await audio.read()
    if not audio_data:
        raise HTTPException(status_code=400, detail="Empty audio file")

    result = await transcribe_audio_with_timestamps(audio_data, language=language)

    if result is None:
        raise HTTPException(status_code=500, detail="Speech recognition failed")

    return ASRDetailedResponse(
        text=result.get("text", ""),
        words=result.get("words", []),
        success=True
    )
