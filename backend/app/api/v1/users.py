from fastapi import APIRouter
from sqlalchemy import select, func

from app.api.deps import DBSession, CurrentUser
from app.models.scene import Scene
from app.models.note import Note, NoteType
from app.schemas.user import UserResponse, UserStats

router = APIRouter()


@router.get("/profile", response_model=UserResponse)
async def get_profile(current_user: CurrentUser):
    """获取用户信息"""
    return current_user


@router.get("/stats", response_model=UserStats)
async def get_stats(current_user: CurrentUser, db: DBSession):
    """获取用户学习统计"""
    # 场景数
    scenes_result = await db.execute(
        select(func.count(Scene.id)).where(Scene.user_id == current_user.id)
    )
    total_scenes = scenes_result.scalar() or 0

    # 词汇数
    words_result = await db.execute(
        select(func.count(Note.id)).where(
            Note.user_id == current_user.id,
            Note.type == NoteType.VOCABULARY
        )
    )
    total_words = words_result.scalar() or 0

    # 学习天数（简化计算：按创建日期算）
    days_result = await db.execute(
        select(func.count(func.distinct(func.date(Scene.created_at)))).where(
            Scene.user_id == current_user.id
        )
    )
    learning_days = days_result.scalar() or 0

    return UserStats(
        total_scenes=total_scenes,
        total_words=total_words,
        learning_days=learning_days
    )
