from fastapi import APIRouter, UploadFile, File, HTTPException, status, Query
from fastapi.responses import StreamingResponse
from typing import Optional
from uuid import UUID
import json

from app.api.deps import DBSession, CurrentUser
from app.models.scene import Scene
from app.schemas.scene import (
    SceneCreate, SceneResponse, SceneListItem, SceneAnalyzeResponse
)
from app.services.qwen_vl import analyze_image, analyze_image_basic, generate_expressions
from sqlalchemy import select, desc

router = APIRouter()


@router.post("/analyze", response_model=SceneAnalyzeResponse)
async def analyze_scene(
    image: UploadFile = File(...),
    cefr_level: Optional[str] = "B1"
):
    """上传图片，AI 分析生成学习内容（完整，一次性返回）"""
    # 验证文件类型
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="只支持图片文件"
        )

    # 读取图片内容
    image_data = await image.read()

    # 调用千问 VL 分析
    result = await analyze_image(image_data, cefr_level)
    if not result:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="图片分析失败，请重试"
        )

    return result


@router.post("/analyze/stream")
async def analyze_scene_stream(
    image: UploadFile = File(...),
    cefr_level: Optional[str] = "B1"
):
    """
    上传图片，AI 分析生成学习内容（流式，两阶段返回）

    返回 SSE 事件:
    - {"type": "basic", "data": {...}} - 第一阶段：基础信息（场景、词汇、描述）
    - {"type": "expressions", "data": {...}} - 第二阶段：口语例句
    - {"type": "done"} - 完成
    - {"type": "error", "message": "..."} - 错误
    """
    # 验证文件类型
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="只支持图片文件"
        )

    # 读取图片内容
    image_data = await image.read()

    async def event_generator():
        try:
            # 第一阶段：分析基础信息
            basic_result = await analyze_image_basic(image_data, cefr_level)

            if not basic_result:
                error_data = json.dumps({
                    "type": "error",
                    "message": "图片分析失败，请重试"
                }, ensure_ascii=False)
                yield f"data: {error_data}\n\n"
                return

            # 发送基础信息
            basic_data = json.dumps({
                "type": "basic",
                "data": basic_result
            }, ensure_ascii=False)
            yield f"data: {basic_data}\n\n"

            # 第二阶段：生成口语例句（使用纯文本模型，更快）
            expressions_result = await generate_expressions(
                scene_tag=basic_result.get("scene_tag", ""),
                scene_tag_cn=basic_result.get("scene_tag_cn", ""),
                category=basic_result.get("category", ""),
                description_en=basic_result.get("description", {}).get("en", ""),
                cefr_level=cefr_level
            )

            if expressions_result:
                expressions_data = json.dumps({
                    "type": "expressions",
                    "data": {"expressions": expressions_result}
                }, ensure_ascii=False)
                yield f"data: {expressions_data}\n\n"

            # 完成
            done_data = json.dumps({"type": "done"})
            yield f"data: {done_data}\n\n"

        except Exception as e:
            error_data = json.dumps({
                "type": "error",
                "message": str(e)
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


@router.post("", response_model=SceneResponse, status_code=status.HTTP_201_CREATED)
async def create_scene(
    scene_data: SceneCreate,
    current_user: CurrentUser,
    db: DBSession
):
    """保存场景"""
    scene = Scene(
        user_id=current_user.id,
        local_photo_id=scene_data.local_photo_id,
        scene_tag=scene_data.scene_tag,
        scene_tag_cn=scene_data.scene_tag_cn,
        object_tags=[tag.model_dump() for tag in scene_data.object_tags],
        description_en=scene_data.description_en,
        description_cn=scene_data.description_cn,
        expressions=scene_data.expressions.model_dump(),
        category=scene_data.category
    )
    db.add(scene)
    await db.commit()
    await db.refresh(scene)
    return scene


@router.get("", response_model=list[SceneListItem])
async def list_scenes(
    current_user: CurrentUser,
    db: DBSession,
    category: Optional[str] = None,
    limit: int = Query(default=20, le=100),
    offset: int = 0
):
    """获取场景列表"""
    query = select(Scene).where(Scene.user_id == current_user.id)

    if category and category != "全部":
        query = query.where(Scene.category == category)

    query = query.order_by(desc(Scene.created_at)).offset(offset).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{scene_id}", response_model=SceneResponse)
async def get_scene(
    scene_id: UUID,
    current_user: CurrentUser,
    db: DBSession
):
    """获取场景详情"""
    result = await db.execute(
        select(Scene).where(
            Scene.id == scene_id,
            Scene.user_id == current_user.id
        )
    )
    scene = result.scalar_one_or_none()

    if not scene:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="场景不存在"
        )

    return scene
