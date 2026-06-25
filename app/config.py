from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://postgres:Chinmay2005%@db.eqjianefzeaighbjegye.supabase.co:6543/postgres?ssl=require"
    supabase_url: str = "https://eqjianefzeaighbjegye.supabase.co"
    evaluation_interval_seconds: int = 30
    telemetry_interval_seconds: int = 10
    secret_key: str = "d85669c6c3e74554476c5ec4d4407ae9cba3b963e8e8d138ea59c22abdbc2e7c"
    server_token: str = "smart_kitchen_server_token_2024"
    enable_simulation: bool = False

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


_settings_cache: Settings | None = None

def get_settings() -> Settings:
    global _settings_cache
    if _settings_cache is None:
        _settings_cache = Settings()
    return _settings_cache