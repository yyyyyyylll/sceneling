from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from uuid import UUID

from app.models.user import CEFRLevel


class UserCreate(BaseModel):
    apple_id: str
    nickname: Optional[str] = None
    avatar_url: Optional[str] = None


class UserUpdate(BaseModel):
    nickname: Optional[str] = None
    avatar_url: Optional[str] = None
    cefr_level: Optional[CEFRLevel] = None


class UserResponse(BaseModel):
    id: UUID
    nickname: Optional[str]
    avatar_url: Optional[str]
    cefr_level: CEFRLevel
    created_at: datetime

    class Config:
        from_attributes = True


class UserStats(BaseModel):
    total_scenes: int
    total_words: int
    learning_days: int
