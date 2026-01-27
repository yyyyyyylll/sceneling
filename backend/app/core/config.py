from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    APP_NAME: str = "SceneLing API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # Database (开发环境用 SQLite，生产环境用 PostgreSQL)
    DATABASE_URL: str = "sqlite+aiosqlite:///./sceneling.db"
    # 生产环境: DATABASE_URL: str = "postgresql+asyncpg://postgres:password@localhost:5432/sceneling"

    # JWT
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_DAYS: int = 30

    # Apple Sign In
    APPLE_TEAM_ID: str = ""
    APPLE_CLIENT_ID: str = ""  # Your app's bundle ID
    APPLE_KEY_ID: str = ""
    APPLE_PRIVATE_KEY: str = ""

    # Qwen VL (通义千问多模态)
    DASHSCOPE_API_KEY: str = ""

    # Aliyun TTS
    ALIYUN_ACCESS_KEY_ID: str = ""
    ALIYUN_ACCESS_KEY_SECRET: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
