from pydantic import BaseModel
from typing import Optional


class AppleAuthRequest(BaseModel):
    identity_token: str
    authorization_code: str
    full_name: Optional[str] = None
    email: Optional[str] = None


class TokenResponse(BaseModel):
    token: str
    user: "UserBrief"


class UserBrief(BaseModel):
    id: str
    nickname: Optional[str]
    avatar_url: Optional[str]
    is_new_user: bool

    class Config:
        from_attributes = True


TokenResponse.model_rebuild()
