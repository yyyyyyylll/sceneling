from fastapi import APIRouter, HTTPException, status, Query
from typing import Optional
from uuid import UUID
from sqlalchemy import select, desc

from app.api.deps import DBSession, CurrentUser
from app.models.note import Note, NoteType
from app.schemas.note import NoteCreate, NoteResponse, NoteListItem

router = APIRouter()


@router.post("", response_model=NoteResponse, status_code=status.HTTP_201_CREATED)
async def create_note(
    note_data: NoteCreate,
    current_user: CurrentUser,
    db: DBSession
):
    """保存单条笔记（词汇/例句）"""
    note = Note(
        user_id=current_user.id,
        scene_id=note_data.scene_id,
        type=note_data.type,
        content_en=note_data.content_en,
        content_cn=note_data.content_cn,
        phonetic=note_data.phonetic,
        pos=note_data.pos,
        role=note_data.role
    )
    db.add(note)
    await db.commit()
    await db.refresh(note)
    return note


@router.get("", response_model=list[NoteListItem])
async def list_notes(
    current_user: CurrentUser,
    db: DBSession,
    type: Optional[NoteType] = None,
    search: Optional[str] = None,
    limit: int = Query(default=50, le=200),
    offset: int = 0
):
    """获取笔记列表"""
    query = select(Note).where(Note.user_id == current_user.id)

    if type:
        query = query.where(Note.type == type)

    if search:
        query = query.where(
            Note.content_en.ilike(f"%{search}%") |
            Note.content_cn.ilike(f"%{search}%")
        )

    query = query.order_by(desc(Note.created_at)).offset(offset).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{note_id}", response_model=NoteResponse)
async def get_note(
    note_id: UUID,
    current_user: CurrentUser,
    db: DBSession
):
    """获取笔记详情"""
    result = await db.execute(
        select(Note).where(
            Note.id == note_id,
            Note.user_id == current_user.id
        )
    )
    note = result.scalar_one_or_none()

    if not note:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="笔记不存在"
        )

    return note
