from fastapi import APIRouter
from sqlalchemy import select, func

from app.api.deps import DBSession, CurrentUser
from app.models.scene import Scene
from app.schemas.user import UserResponse, UserStats

router = APIRouter()


@router.get("/profile", response_model=UserResponse)
async def get_profile(current_user: CurrentUser):
    """获取用户信息"""
    return current_user


@router.get("/stats", response_model=UserStats)
async def get_stats(current_user: CurrentUser, db: DBSession):
    """获取用户学习统计"""
    # 获取所有场景
    scenes_result = await db.execute(
        select(Scene).where(Scene.user_id == current_user.id)
    )
    scenes = scenes_result.scalars().all()
    total_scenes = len(scenes)

    # 对话数（统计所有场景中的角色数）
    total_dialogues = sum(
        len(scene.expressions.get("roles", [])) if scene.expressions else 0
        for scene in scenes
    )

    # 学习天数（简化计算：按创建日期算）
    days_result = await db.execute(
        select(func.count(func.distinct(func.date(Scene.created_at)))).where(
            Scene.user_id == current_user.id
        )
    )
    learning_days = days_result.scalar() or 0

    return UserStats(
        total_scenes=total_scenes,
        total_dialogues=total_dialogues,
        learning_days=learning_days
    )
