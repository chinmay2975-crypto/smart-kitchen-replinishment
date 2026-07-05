import logging
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, Depends, HTTPException, Header, Query
from pydantic import BaseModel, Field, validator
from sqlalchemy import text, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.security import decode_token
from app.models.orm import DeviceReading
from app.services.cart_service import maybe_trigger_auto_reorder

logger = logging.getLogger("smart_kitchen.iot")
router = APIRouter(prefix="/api/v1", tags=["iot"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_user_id_from_token(authorization: str = Header(...)) -> str:
    """Extract user_id from the JWT in the Authorization header."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    token = authorization[7:]
    try:
        payload = decode_token(token)
        return payload["sub"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


# ---------------------------------------------------------------------------
# Request/Response Models
# ---------------------------------------------------------------------------

class DeviceReadingRequest(BaseModel):
    device_id: Optional[str] = None
    feed_id: Optional[str] = None
    reading_value: float = Field(..., gt=0, description="Weight reading in grams")
    unit: str = "gram"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    elevation: Optional[float] = None
    external_id: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    created_at: Optional[datetime] = None

    @validator('reading_value')
    def validate_reading_value(cls, v):
        if v < 0:
            raise ValueError('Reading value must be non-negative')
        return v


class DeviceReadingResponse(BaseModel):
    reading_id: int
    user_id: str
    device_id: Optional[str]
    feed_id: Optional[str]
    reading_value: float
    unit: str
    latitude: Optional[float]
    longitude: Optional[float]
    elevation: Optional[float]
    external_id: Optional[str]
    metadata: Dict[str, Any]
    created_at: str


class DeviceDashboardResponse(BaseModel):
    readings: List[DeviceReadingResponse]
    summary: Dict[str, Any]


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/device/reading", response_model=DeviceReadingResponse, status_code=201)
async def create_device_reading(
    req: DeviceReadingRequest,
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a new device reading for the authenticated user.
    The reading is automatically linked to the user's ID for isolation.
    """
    # Validate device_id if provided - ensure it belongs to user's household
    device_uuid = None
    device_row = None
    if req.device_id:
        device_result = await db.execute(
            text("""
                SELECT d.device_id, d.device_name, d.reorder_level, d.reorder_quantity
                FROM devices d
                JOIN households h ON d.household_id = h.household_id
                JOIN household_members hm ON hm.household_id = h.household_id
                WHERE d.device_id = :did AND hm.user_id = :uid AND d.deactivated_at IS NULL
            """),
            {"did": req.device_id, "uid": user_id},
        )
        device_row = device_result.first()
        if not device_row:
            raise HTTPException(
                status_code=403,
                detail="Device not found or does not belong to your household"
            )
        device_uuid = req.device_id

    # Use provided created_at or current time
    reading_time = req.created_at if req.created_at else datetime.now(timezone.utc)

    # Create the reading
    reading = DeviceReading(
        user_id=user_id,
        device_id=device_uuid,
        feed_id=req.feed_id,
        reading_value=req.reading_value,
        unit=req.unit,
        latitude=req.latitude,
        longitude=req.longitude,
        elevation=req.elevation,
        external_id=req.external_id,
        metadata_json=req.metadata or {},
        created_at=reading_time,
    )
    db.add(reading)
    await db.commit()
    await db.refresh(reading)

    logger.info(
        "Created device reading %s for user %s: %.2f %s",
        reading.reading_id, user_id, req.reading_value, req.unit
    )

    # Auto-reorder trigger: if the reading is below the container's reorder_level,
    # add an item to the cart unless one is already pending for this container.
    if device_row is not None:
        await maybe_trigger_auto_reorder(
            session=db,
            device_id=device_uuid,
            user_id=user_id,
            device_name=device_row[1],
            reorder_level=device_row[2],
            reorder_quantity=device_row[3],
            reading_value=req.reading_value,
        )

    return DeviceReadingResponse(
        reading_id=reading.reading_id,
        user_id=str(reading.user_id),
        device_id=str(reading.device_id) if reading.device_id else None,
        feed_id=reading.feed_id,
        reading_value=float(reading.reading_value),
        unit=reading.unit,
        latitude=float(reading.latitude) if reading.latitude else None,
        longitude=float(reading.longitude) if reading.longitude else None,
        elevation=float(reading.elevation) if reading.elevation else None,
        external_id=reading.external_id,
        metadata=reading.metadata_json,
        created_at=str(reading.created_at),
    )


@router.get("/device/dashboard", response_model=DeviceDashboardResponse)
async def get_device_dashboard(
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(100, ge=1, le=1000, description="Max readings to return"),
    offset: int = Query(0, ge=0, description="Number of readings to skip"),
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
):
    """
    Get device readings for the authenticated user's dashboard.
    Returns readings sorted by created_at ascending with summary statistics.
    """
    # Build query with filters
    query = """
        SELECT 
            reading_id, user_id, device_id, feed_id, reading_value, unit,
            latitude, longitude, elevation, external_id, metadata_json, created_at
        FROM device_readings
        WHERE user_id = :uid
    """
    params = {"uid": user_id}

    # Add date filters if provided
    if start_date:
        query += " AND created_at >= :start_date"
        params["start_date"] = start_date
    if end_date:
        query += " AND created_at <= :end_date"
        params["end_date"] = end_date

    # Add ordering and pagination
    query += " ORDER BY created_at ASC LIMIT :limit OFFSET :offset"
    params["limit"] = limit
    params["offset"] = offset

    # Execute query
    result = await db.execute(text(query), params)
    rows = result.fetchall()

    # Format readings
    readings = []
    for row in rows:
        readings.append(DeviceReadingResponse(
            reading_id=row[0],
            user_id=str(row[1]),
            device_id=str(row[2]) if row[2] else None,
            feed_id=row[3],
            reading_value=float(row[4]),
            unit=row[5],
            latitude=float(row[6]) if row[6] else None,
            longitude=float(row[7]) if row[7] else None,
            elevation=float(row[8]) if row[8] else None,
            external_id=row[9],
            metadata=row[10] if row[10] else {},
            created_at=str(row[11]),
        ))

    # Get summary statistics
    summary_query = await db.execute(
        text("""
            SELECT 
                COUNT(*) as total_readings,
                MIN(reading_value) as min_value,
                MAX(reading_value) as max_value,
                AVG(reading_value) as avg_value,
                MIN(created_at) as first_reading,
                MAX(created_at) as latest_reading
            FROM device_readings
            WHERE user_id = :uid
        """),
        {"uid": user_id},
    )
    summary_row = summary_query.first()

    summary = {
        "total_readings": summary_row[0] if summary_row[0] else 0,
        "min_value": float(summary_row[1]) if summary_row[1] else None,
        "max_value": float(summary_row[2]) if summary_row[2] else None,
        "avg_value": float(summary_row[3]) if summary_row[3] else None,
        "first_reading": str(summary_row[4]) if summary_row[4] else None,
        "latest_reading": str(summary_row[5]) if summary_row[5] else None,
    }

    logger.info(
        "Dashboard request for user %s: returned %d readings (total: %d)",
        user_id, len(readings), summary["total_readings"]
    )

    return DeviceDashboardResponse(readings=readings, summary=summary)