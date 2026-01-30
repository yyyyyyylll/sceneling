"""
语音识别 / 文本标点 API
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.asr import add_punctuation

router = APIRouter()


class PunctuationRequest(BaseModel):
    text: str
    language: str = "en"


class PunctuationResponse(BaseModel):
    text: str
    success: bool = True


@router.post("", response_model=PunctuationResponse)
async def punctuate_text(request: PunctuationRequest):
    """
    文本标点服务 - 给无标点文本添加标点和分句

    - 使用 qwen-turbo 智能添加标点
    - 支持英语(en)和中文(zh)
    - 输入: iOS 原生语音识别的无标点文本
    - 输出: 带标点分句的文本
    """
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="Empty text")

    result = await add_punctuation(request.text, language=request.language)

    return PunctuationResponse(text=result, success=True)
