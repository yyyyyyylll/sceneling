from fastapi import APIRouter

from app.api.v1 import auth, scenes, notes, users, tts

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["认证"])
api_router.include_router(scenes.router, prefix="/scenes", tags=["场景"])
api_router.include_router(notes.router, prefix="/notes", tags=["笔记"])
api_router.include_router(users.router, prefix="/users", tags=["用户"])
api_router.include_router(tts.router, prefix="/tts", tags=["语音合成"])
