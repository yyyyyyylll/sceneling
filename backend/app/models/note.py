import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey, Integer, Enum as SQLEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
import enum

from app.core.database import Base


class NoteType(str, enum.Enum):
    VOCABULARY = "vocabulary"
    EXPRESSION = "expression"


class Note(Base):
    __tablename__ = "notes"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE")
    )
    scene_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("scenes.id", ondelete="SET NULL"), nullable=True
    )
    type: Mapped[NoteType] = mapped_column(SQLEnum(NoteType))
    content_en: Mapped[str] = mapped_column(String(500))
    content_cn: Mapped[str] = mapped_column(String(500))
    phonetic: Mapped[str | None] = mapped_column(String(100), nullable=True)
    pos: Mapped[str | None] = mapped_column(String(20), nullable=True)  # Part of speech
    role: Mapped[str | None] = mapped_column(String(50), nullable=True)  # For expressions
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    next_review_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )

    # Relationships
    user: Mapped["User"] = relationship(back_populates="notes")
    scene: Mapped["Scene | None"] = relationship(back_populates="notes")
