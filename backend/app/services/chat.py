import dashscope
from dashscope import Generation
from typing import List, Dict, AsyncGenerator, Tuple

from app.core.config import settings


CHAT_SYSTEM_PROMPT = """You are a friendly English learning assistant helping the user practice spoken English.

## Scene Context
- Scene: {scene_tag} ({scene_tag_cn})
- Category: {category}
- Possible roles: {roles}
- User role: {user_role}
- Your role (AI): {ai_role}

## Your Tasks
1. Role-play as one character in the scene and chat with the user
2. Respond only in English; do not include any Chinese translation
3. Adjust difficulty to the user's English level
4. Encourage the user to express more in English
5. Gently correct grammar mistakes when appropriate
6. Keep each reply under 100 words

## Response Format
- English only
- No translation or explanations in Chinese
- If the user makes grammar mistakes, gently correct them with a better phrasing"""


async def chat_with_scene(
    message: str,
    scene_tag: str,
    scene_tag_cn: str,
    category: str,
    roles: List[str],
    user_role: str,
    ai_role: str,
    history: List[Dict[str, str]]
) -> str:
    """
    基于场景进行对话
    """
    dashscope.api_key = settings.DASHSCOPE_API_KEY

    # 构建系统提示
    system_prompt = CHAT_SYSTEM_PROMPT.format(
        scene_tag=scene_tag,
        scene_tag_cn=scene_tag_cn,
        category=category,
        roles=", ".join(roles),
        user_role=user_role,
        ai_role=ai_role
    )

    # 构建消息历史
    messages = [
        {"role": "system", "content": system_prompt}
    ]

    # 添加历史消息
    for msg in history:
        role = "user" if msg.get("is_user") else "assistant"
        messages.append({
            "role": role,
            "content": msg.get("content", "")
        })

    # 添加当前消息
    messages.append({
        "role": "user",
        "content": message
    })

    try:
        response = Generation.call(
            model="qwen-turbo",
            messages=messages
        )

        if response.status_code != 200:
            print(f"Chat API error: {response.message}")
            return "Sorry, I couldn't process your message. (抱歉，我无法处理您的消息。)"

        return response.output.text

    except Exception as e:
        print(f"Chat failed: {e}")
        return "Sorry, something went wrong. (抱歉，出了点问题。)"


async def chat_with_scene_stream(
    message: str,
    scene_tag: str,
    scene_tag_cn: str,
    category: str,
    roles: List[str],
    user_role: str,
    ai_role: str,
    history: List[Dict[str, str]]
) -> AsyncGenerator[Tuple[str, str], None]:
    """
    基于场景进行对话 - 稳定输出（服务端一次性生成）

    Yields:
        Tuple[str, str]: (event_type, content)
        - ("text_delta", "部分文字")
        - ("sentence", "完整句子")  # 用于 TTS
        - ("done", "")
        - ("error", "错误信息")
    """
    dashscope.api_key = settings.DASHSCOPE_API_KEY

    system_prompt = CHAT_SYSTEM_PROMPT.format(
        scene_tag=scene_tag,
        scene_tag_cn=scene_tag_cn,
        category=category,
        roles=", ".join(roles),
        user_role=user_role,
        ai_role=ai_role
    )

    messages = [{"role": "system", "content": system_prompt}]

    for msg in history:
        role = "user" if msg.get("is_user") else "assistant"
        messages.append({
            "role": role,
            "content": msg.get("content", "")
        })

    messages.append({
        "role": "user",
        "content": message
    })

    try:
        response = Generation.call(
            model="qwen-turbo",
            messages=messages
        )

        if response.status_code != 200:
            yield ("error", f"API error: {response.message}")
            return

        full_text = getattr(response.output, "text", "") or ""
        if full_text:
            yield ("final", full_text)

        yield ("done", "")

    except Exception as e:
        print(f"Stream chat failed: {e}")
        yield ("error", str(e))
