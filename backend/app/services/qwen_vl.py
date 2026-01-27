import json
import base64
from typing import Optional
import dashscope
from dashscope import MultiModalConversation

from app.core.config import settings
from app.schemas.scene import SceneAnalyzeResponse


# Prompt 模板
ANALYZE_PROMPT = """你是一个专业的英语学习助手。请分析用户上传的照片，并生成英语学习内容。

## 任务要求

1. **场景识别**：识别照片中的核心场景，输出1个场景标签
2. **物品识别**：识别场景中2-5个关键物品
3. **场景描述**：用英语描述照片内容，不超过50个单词，并提供中文翻译
4. **口语例句**：根据场景推断4个典型角色，每个角色生成2句在此场景下常用的口语表达

## 难度要求
请使用 {cefr_level} 水平的词汇和句型。

## 输出格式
请严格按照以下 JSON 格式输出（不要输出其他任何内容）：

{{
  "scene_tag": "场景英文标签",
  "scene_tag_cn": "场景中文标签",
  "object_tags": [
    {{"en": "英文", "cn": "中文", "phonetic": "音标", "pos": "词性"}}
  ],
  "description": {{
    "en": "英文描述",
    "cn": "中文描述"
  }},
  "expressions": {{
    "roles": [
      {{
        "role_en": "角色英文名",
        "role_cn": "角色中文名",
        "sentences": [
          {{"en": "英文例句", "cn": "中文翻译"}}
        ]
      }}
    ]
  }},
  "category": "分类（学习/生活/旅行/美食/其他）"
}}"""


async def analyze_image(image_data: bytes, cefr_level: str = "B1") -> Optional[SceneAnalyzeResponse]:
    """
    使用千问 VL 多模态模型分析图片
    """
    dashscope.api_key = settings.DASHSCOPE_API_KEY

    # 将图片转为 base64
    image_base64 = base64.b64encode(image_data).decode("utf-8")

    # 构建消息
    messages = [
        {
            "role": "user",
            "content": [
                {
                    "image": f"data:image/jpeg;base64,{image_base64}"
                },
                {
                    "text": ANALYZE_PROMPT.format(cefr_level=cefr_level)
                }
            ]
        }
    ]

    try:
        response = MultiModalConversation.call(
            model="qwen-vl-max",
            messages=messages
        )

        if response.status_code != 200:
            print(f"Qwen VL API error: {response.message}")
            return None

        # 解析返回内容
        content = response.output.choices[0].message.content[0]["text"]

        # 尝试提取 JSON
        # 有时模型会在 JSON 前后加入其他文本
        start = content.find("{")
        end = content.rfind("}") + 1
        if start != -1 and end > start:
            json_str = content[start:end]
            data = json.loads(json_str)
            return SceneAnalyzeResponse(**data)

        return None

    except Exception as e:
        print(f"Image analysis failed: {e}")
        return None
