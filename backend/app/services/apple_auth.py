import httpx
from jose import jwt
from typing import Optional

from app.core.config import settings


APPLE_PUBLIC_KEYS_URL = "https://appleid.apple.com/auth/keys"


async def get_apple_public_keys() -> dict:
    """获取 Apple 公钥"""
    async with httpx.AsyncClient() as client:
        response = await client.get(APPLE_PUBLIC_KEYS_URL)
        return response.json()


async def verify_apple_token(identity_token: str) -> Optional[str]:
    """
    验证 Apple Identity Token
    返回 Apple User ID（sub）
    """
    try:
        # 获取 Apple 公钥
        keys = await get_apple_public_keys()

        # 解码 token header 获取 kid
        header = jwt.get_unverified_header(identity_token)
        kid = header.get("kid")

        # 查找对应的公钥
        public_key = None
        for key in keys.get("keys", []):
            if key.get("kid") == kid:
                public_key = key
                break

        if not public_key:
            return None

        # 验证 token
        payload = jwt.decode(
            identity_token,
            public_key,
            algorithms=["RS256"],
            audience=settings.APPLE_CLIENT_ID,
            issuer="https://appleid.apple.com"
        )

        # 返回 Apple User ID
        return payload.get("sub")

    except Exception as e:
        print(f"Apple token verification failed: {e}")
        return None
