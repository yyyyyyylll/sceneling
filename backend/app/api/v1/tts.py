from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from app.api.deps import CurrentUser
from app.services.aliyun_tts import text_to_speech

router = APIRouter()


class TTSRequest(BaseModel):
    text: str
    voice: str = "en-US-female"


class TTSResponse(BaseModel):
    audio_url: str


@router.post("", response_model=TTSResponse)
async def synthesize_speech(
    request: TTSRequest,
    current_user: CurrentUser
):
    """文本转语音"""
    if not request.text or len(request.text) > 1000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="文本长度需在 1-1000 字符之间"
        )

    audio_url = await text_to_speech(request.text, request.voice)
    if not audio_url:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="语音合成失败"
        )

    return TTSResponse(audio_url=audio_url)
