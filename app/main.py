import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import engine, ensure_auth_tables
from app.routers.api import router as api_router
from app.routers.auth import router as auth_router
from app.routers.cart import router as cart_router
from app.routers.devices import router as devices_router
from app.routers.iot import router as iot_router
from app.services.data_simulator import (
    run_telemetry_simulation,
    seed_initial_simulation_data,
)
from app.services.replenishment_engine import run_replenishment_engine

# ---------------------------------------------------------------------------
# Logging configuration
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

logger = logging.getLogger("smart_kitchen")
settings = get_settings()

# ---------------------------------------------------------------------------
# Background task references (for clean shutdown)
# ---------------------------------------------------------------------------
_telemetry_task: asyncio.Task | None = None
_engine_task: asyncio.Task | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan event handler.
    - Seeds initial simulation data on startup (if DB is empty AND simulation enabled).
    - Spins up the telemetry simulation and replenishment engine background loops.
    - Cancels both tasks gracefully on shutdown.
    """
    global _telemetry_task, _engine_task

    logger.info("=== Smart Kitchen Replenishment System starting up ===")

    # Ensure auth tables exist when using an existing/local development database.
    # When connected to Supabase (production), this is a no-op.
    try:
        await ensure_auth_tables()
    except Exception as e:
        logger.warning(f"Could not ensure auth tables: {e}")

    # Only run simulation / seeding in development mode
    if settings.enable_simulation:
        # 1. Seed data (runs once, checks if DB is empty internally)
        try:
            await seed_initial_simulation_data()
        except Exception as e:
            logger.warning(f"Skipping seed data: {e}")

        # 2. Start background simulation tasks
        _telemetry_task = asyncio.create_task(
            run_telemetry_simulation(),
            name="telemetry-simulator",
        )
        _engine_task = asyncio.create_task(
            run_replenishment_engine(),
            name="replenishment-engine",
        )

        logger.info("Background tasks started. Application ready.")
    else:
        # In production, only run the replenishment engine (no simulated telemetry)
        _engine_task = asyncio.create_task(
            run_replenishment_engine(),
            name="replenishment-engine",
        )
        logger.info("Production mode: replenishment engine running, simulation disabled.")

    yield  # Application runs here

    # 3. Graceful shutdown
    logger.info("Shutting down background tasks ...")

    if _telemetry_task is not None:
        _telemetry_task.cancel()
    if _engine_task is not None:
        _engine_task.cancel()

    if _telemetry_task is not None or _engine_task is not None:
        await asyncio.gather(
            _telemetry_task or asyncio.sleep(0),
            _engine_task or asyncio.sleep(0),
            return_exceptions=True,
        )

    # Dispose of the database connection pool
    await engine.dispose()
    logger.info("=== Smart Kitchen Replenishment System shut down ===")


# ---------------------------------------------------------------------------
# FastAPI application factory
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Smart Kitchen Automated Replenishment System",
    description="Backend API for accelerated simulation of inventory telemetry "
                "and automated replenishment order generation.",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — allow requests from the frontend domains
# Using highly permissive configuration to ensure browser requests are not blocked
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routers
app.include_router(api_router)
app.include_router(auth_router)
app.include_router(cart_router)
app.include_router(devices_router)
app.include_router(iot_router)


@app.get("/")
async def root():
    return {
        "service": "Smart Kitchen Automated Replenishment System",
        "status": "running",
        "version": "1.0.0",
        "environment": "production",
    }


@app.get("/health")
async def health():
    return {"status": "healthy"}