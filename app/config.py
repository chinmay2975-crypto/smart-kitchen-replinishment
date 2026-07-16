from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # No real secrets as defaults — these must come from .env locally or
    # from Cloud Run env vars in production. Empty-string defaults mean a
    # misconfigured deployment fails loudly (auth breaks) instead of
    # silently running with a hardcoded, publicly-known credential.
    database_url: str = ""
    supabase_url: str = "https://eqjianefzeaighbjegye.supabase.co"
    evaluation_interval_seconds: int = 120
    telemetry_interval_seconds: int = 60
    secret_key: str = ""
    server_token: str = ""
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