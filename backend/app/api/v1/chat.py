from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional
import json

from app.services.chat import chat_with_scene, chat_with_scene_stream, free_chat_stream
from app.services.aliyun_tts import text_to_speech

router = APIRouter()


class ChatMessage(BaseModel):
    content: str
    is_user: bool


class ChatRequest(BaseModel):
    message: str
    scene_tag: str
    scene_tag_cn: str
    category: str
    roles: List[str]
    user_role: str
    ai_role: str
    history: Optional[List[ChatMessage]] = []


class ChatResponse(BaseModel):
    reply: str


@router.post("", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """AI对话接口 - 非流式"""
    history = [
        {"content": msg.content, "is_user": msg.is_user}
        for msg in (request.history or [])
    ]

    reply = await chat_with_scene(
        message=request.message,
        scene_tag=request.scene_tag,
        scene_tag_cn=request.scene_tag_cn,
        category=request.category,
        roles=request.roles,
        user_role=request.user_role,
        ai_role=request.ai_role,
        history=history
    )

    return ChatResponse(reply=reply)


@router.post("/stream")
async def chat_stream(request: ChatRequest):
    """
    AI对话接口 - 流式 SSE

    返回事件格式:
    - {"type": "text_full", "content": "完整文本"}
    - {"type": "audio", "url": "...", "text": "完整文本"}
    - {"type": "done"}
    - {"type": "error", "content": "错误信息"}
    """
    history = [
        {"content": msg.content, "is_user": msg.is_user}
        for msg in (request.history or [])
    ]

    async def event_generator():
        """SSE 事件生成器"""
        try:
            async for event_type, content in chat_with_scene_stream(
                message=request.message,
                scene_tag=request.scene_tag,
                scene_tag_cn=request.scene_tag_cn,
                category=request.category,
                roles=request.roles,
                user_role=request.user_role,
                ai_role=request.ai_role,
                history=history
            ):
                if event_type == "final":
                    # 发送完整文本
                    data = json.dumps({
                        "type": "text_full",
                        "content": content
                    }, ensure_ascii=False)
                    yield f"data: {data}\n\n"

                    # 生成整段 TTS（等待文本完全生成后再发音）
                    english_text = _extract_english(content)
                    if english_text and len(english_text) > 3:
                        try:
                            audio_url = await text_to_speech(english_text, "en-US-female")
                            if audio_url:
                                data = json.dumps({
                                    "type": "audio",
                                    "url": audio_url,
                                    "text": english_text
                                }, ensure_ascii=False)
                                yield f"data: {data}\n\n"
                        except Exception as tts_err:
                            print(f"[TTS] Error: {tts_err}")

                elif event_type == "done":
                    data = json.dumps({"type": "done"})
                    yield f"data: {data}\n\n"

                elif event_type == "error":
                    data = json.dumps({
                        "type": "error",
                        "content": content
                    }, ensure_ascii=False)
                    yield f"data: {data}\n\n"

        except Exception as e:
            error_data = json.dumps({
                "type": "error",
                "content": str(e)
            }, ensure_ascii=False)
            yield f"data: {error_data}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"
        }
    )


class FreeChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = []


@router.post("/free/stream")
async def free_chat_stream_endpoint(request: FreeChatRequest):
    """
    自由对话接口 - 流式 SSE（无场景限制）

    返回事件格式:
    - {"type": "text_full", "content": "完整文本"}
    - {"type": "audio", "url": "...", "text": "完整文本"}
    - {"type": "done"}
    - {"type": "error", "content": "错误信息"}
    """
    history = [
        {"content": msg.content, "is_user": msg.is_user}
        for msg in (request.history or [])
    ]

    async def event_generator():
        """SSE 事件生成器"""
        try:
            async for event_type, content in free_chat_stream(
                message=request.message,
                history=history
            ):
                if event_type == "final":
                    # 发送完整文本
                    data = json.dumps({
                        "type": "text_full",
                        "content": content
                    }, ensure_ascii=False)
                    yield f"data: {data}\n\n"

                    # 生成整段 TTS
                    english_text = _extract_english(content)
                    if english_text and len(english_text) > 3:
                        try:
                            audio_url = await text_to_speech(english_text, "en-US-female")
                            if audio_url:
                                data = json.dumps({
                                    "type": "audio",
                                    "url": audio_url,
                                    "text": english_text
                                }, ensure_ascii=False)
                                yield f"data: {data}\n\n"
                        except Exception as tts_err:
                            print(f"[TTS] Error: {tts_err}")

                elif event_type == "done":
                    data = json.dumps({"type": "done"})
                    yield f"data: {data}\n\n"

                elif event_type == "error":
                    data = json.dumps({
                        "type": "error",
                        "content": content
                    }, ensure_ascii=False)
                    yield f"data: {data}\n\n"

        except Exception as e:
            error_data = json.dumps({
                "type": "error",
                "content": str(e)
            }, ensure_ascii=False)
            yield f"data: {error_data}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"
        }
    )


def _extract_english(text: str) -> str:
    """
    从混合文本中提取英文部分
    例如: "Hello! (你好！)" -> "Hello!"
    """
    import re
    # 移除括号及其内容（中文翻译）
    result = re.sub(r'\([^)]*[\u4e00-\u9fff][^)]*\)', '', text)
    result = re.sub(r'（[^）]*[\u4e00-\u9fff][^）]*）', '', result)
    return result.strip()
