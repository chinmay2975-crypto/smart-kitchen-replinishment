import logging
import os
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy import text
from app.config import get_settings

settings = get_settings()
logger = logging.getLogger("smart_kitchen.database")

# Safety: ensure the database URL uses the asyncpg dialect
# This handles cases where the env var might use postgresql:// instead of postgresql+asyncpg://
database_url = settings.database_url
if database_url and database_url.startswith("postgresql://"):
    database_url = database_url.replace("postgresql://", "postgresql+asyncpg://", 1)
    logger.info("Converted database URL to use asyncpg dialect")

# For Supabase, SSL is required. The connection string already has ?ssl=require
# appended in the .env / config defaults.
engine = create_async_engine(
    database_url,
    pool_size=5,
    max_overflow=10,
    echo=False,
    connect_args={"ssl": "require"} if "supabase" in database_url else {},
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db():
    """Dependency that provides a database session."""
    try:
        async with async_session_factory() as session:
            try:
                yield session
            finally:
                await session.close()
    except Exception as e:
        logger.error("Database session error: %s", e, exc_info=True)
        raise


async def ensure_auth_tables() -> None:
    """
    Create the minimal authentication tables required by the current backend
    if the connected development database was initialized with an older schema.
    Existing tables/data are left untouched.

    NOTE: In production (Supabase), tables are created via the init_supabase.sql
    script. This function is a no-op when running against Supabase to avoid
    interfering with the managed schema.
    """
    # Skip table creation when connected to Supabase (production)
    if "supabase" in settings.database_url:
        return

    statements = [
        "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"",
        """
        CREATE TABLE IF NOT EXISTS app_users (
            user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            email VARCHAR(255) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            full_name VARCHAR(150) NOT NULL,
            phone VARCHAR(20) UNIQUE,
            role VARCHAR(20) NOT NULL DEFAULT 'homeowner',
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS households (
            household_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            name VARCHAR(200) NOT NULL,
            address_line1 VARCHAR(255),
            address_line2 VARCHAR(255),
            city VARCHAR(100),
            state VARCHAR(100),
            postal_code VARCHAR(20),
            country VARCHAR(100) DEFAULT 'IN',
            timezone VARCHAR(50) DEFAULT 'Asia/Kolkata',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            owner_id UUID REFERENCES app_users(user_id)
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS household_members (
            household_id UUID REFERENCES households(household_id) ON DELETE CASCADE,
            user_id UUID REFERENCES app_users(user_id) ON DELETE CASCADE,
            role VARCHAR(20) DEFAULT 'member',
            joined_at TIMESTAMPTZ DEFAULT NOW(),
            PRIMARY KEY (household_id, user_id)
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS household_preferences (
            preference_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            household_id UUID REFERENCES households(household_id) ON DELETE CASCADE,
            user_id UUID REFERENCES app_users(user_id) ON DELETE CASCADE,
            auto_replenish BOOLEAN DEFAULT TRUE,
            notify_low_stock BOOLEAN DEFAULT TRUE,
            notify_expiry BOOLEAN DEFAULT TRUE,
            preferred_replenish_day VARCHAR(20) DEFAULT 'monday',
            notification_channels JSONB DEFAULT '["push", "email"]',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE (household_id, user_id)
        )
        """,
        "CREATE INDEX IF NOT EXISTS idx_app_users_email ON app_users(email)",
    ]

    async with engine.begin() as conn:
        for statement in statements:
            await conn.execute(text(statement))


async def check_db_empty() -> bool:
    """Return True if the app_users table has zero rows (DB is fresh)."""
    async with async_session_factory() as session:
        result = await session.execute(text("SELECT COUNT(*) FROM app_users"))
        count = result.scalar()
        return count == 0