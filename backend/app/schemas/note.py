from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from uuid import UUID

from app.models.note import NoteType


class NoteCreate(BaseModel):
    scene_id: Optional[UUID] = None
    type: NoteType
    content_en: str
    content_cn: str
    phonetic: Optional[str] = None
    pos: Optional[str] = None
    role: Optional[str] = None


class NoteResponse(BaseModel):
    id: UUID
    scene_id: Optional[UUID]
    type: NoteType
    content_en: str
    content_cn: str
    phonetic: Optional[str]
    pos: Optional[str]
    role: Optional[str]
    review_count: int
    created_at: datetime

    class Config:
        from_attributes = True


class NoteListItem(BaseModel):
    id: UUID
    type: NoteType
    content_en: str
    content_cn: str
    phonetic: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True
