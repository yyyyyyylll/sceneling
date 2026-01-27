import uuid
from datetime import datetime
from sqlalchemy import String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Scene(Base):
    __tablename__ = "scenes"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE")
    )
    local_photo_id: Mapped[str] = mapped_column(String(255))
    scene_tag: Mapped[str] = mapped_column(String(100))
    scene_tag_cn: Mapped[str] = mapped_column(String(100))
    object_tags: Mapped[dict] = mapped_column(JSON)  # [{en, cn, phonetic, pos}]
    description_en: Mapped[str] = mapped_column(Text)
    description_cn: Mapped[str] = mapped_column(Text)
    expressions: Mapped[dict] = mapped_column(JSON)  # {roles: [{role_en, role_cn, sentences}]}
    category: Mapped[str] = mapped_column(String(50), default="其他")
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )

    # Relationships
    user: Mapped["User"] = relationship(back_populates="scenes")
    notes: Mapped[list["Note"]] = relationship(back_populates="scene", cascade="all, delete-orphan")
