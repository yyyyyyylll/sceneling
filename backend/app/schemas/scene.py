from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from uuid import UUID


class ObjectTag(BaseModel):
    en: str
    cn: str
    phonetic: str
    pos: str


class Sentence(BaseModel):
    en: str
    cn: str


class Role(BaseModel):
    role_en: str
    role_cn: str
    sentences: list[Sentence]


class Expressions(BaseModel):
    roles: list[Role]


class Description(BaseModel):
    en: str
    cn: str


class SceneAnalyzeResponse(BaseModel):
    """AI 分析返回的场景数据"""
    scene_tag: str
    scene_tag_cn: str
    object_tags: list[ObjectTag]
    description: Description
    expressions: Expressions
    category: str


class SceneCreate(BaseModel):
    local_photo_id: str
    scene_tag: str
    scene_tag_cn: str
    object_tags: list[ObjectTag]
    description_en: str
    description_cn: str
    expressions: Expressions
    category: str = "其他"


class SceneResponse(BaseModel):
    id: UUID
    local_photo_id: str
    scene_tag: str
    scene_tag_cn: str
    object_tags: list[ObjectTag]
    description_en: str
    description_cn: str
    expressions: Expressions
    category: str
    created_at: datetime

    class Config:
        from_attributes = True


class SceneListItem(BaseModel):
    id: UUID
    local_photo_id: str
    scene_tag: str
    scene_tag_cn: str
    category: str
    created_at: datetime

    class Config:
        from_attributes = True
