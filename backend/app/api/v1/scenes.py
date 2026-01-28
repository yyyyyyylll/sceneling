from fastapi import APIRouter, UploadFile, File, HTTPException, status, Query
from typing import Optional
from uuid import UUID

from app.api.deps import DBSession, CurrentUser
from app.models.scene import Scene
from app.schemas.scene import (
    SceneCreate, SceneResponse, SceneListItem, SceneAnalyzeResponse
)
from app.services.qwen_vl import analyze_image
from sqlalchemy import select, desc

router = APIRouter()


@router.post("/analyze", response_model=SceneAnalyzeResponse)
async def analyze_scene(
    image: UploadFile = File(...),
    cefr_level: Optional[str] = "B1"
):
    """上传图片，AI 分析生成学习内容"""
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
