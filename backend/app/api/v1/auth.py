from fastapi import APIRouter, HTTPException, status
from datetime import datetime, timedelta
from jose import jwt
from sqlalchemy import select

from app.api.deps import DBSession, CurrentUser
from app.core.config import settings
from app.models.user import User
from app.schemas.auth import AppleAuthRequest, TokenResponse, UserBrief
from app.services.apple_auth import verify_apple_token

router = APIRouter()


def create_access_token(user_id: str) -> str:
    """创建 JWT token"""
    expire = datetime.utcnow() + timedelta(days=settings.ACCESS_TOKEN_EXPIRE_DAYS)
    to_encode = {"sub": user_id, "exp": expire}
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


@router.post("/apple", response_model=TokenResponse)
async def apple_login(request: AppleAuthRequest, db: DBSession):
    """Apple ID 登录"""
    # 验证 Apple token
    apple_user_id = await verify_apple_token(request.identity_token)
    if not apple_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Apple token"
        )

    # 查找或创建用户
    result = await db.execute(
        select(User).where(User.apple_id == apple_user_id)
    )
    user = result.scalar_one_or_none()
    is_new_user = False

    if not user:
        # 创建新用户
        user = User(
            apple_id=apple_user_id,
            nickname=request.full_name or "SceneLing 用户",
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
        is_new_user = True

    # 生成 token
    token = create_access_token(str(user.id))

    return TokenResponse(
        token=token,
        user=UserBrief(
            id=str(user.id),
            nickname=user.nickname,
            avatar_url=user.avatar_url,
            is_new_user=is_new_user
        )
    )


@router.get("/me", response_model=UserBrief)
async def get_me(current_user: CurrentUser):
    """获取当前用户信息"""
    return UserBrief(
        id=str(current_user.id),
        nickname=current_user.nickname,
        avatar_url=current_user.avatar_url,
        is_new_user=False
    )
