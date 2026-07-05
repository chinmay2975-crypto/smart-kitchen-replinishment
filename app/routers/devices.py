import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Header, Query
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.security import decode_token

logger = logging.getLogger("smart_kitchen.devices")
router = APIRouter(prefix="/api/v1/devices", tags=["devices"])


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
# Models
# ---------------------------------------------------------------------------

class ClaimDeviceRequest(BaseModel):
    device_uid: str = Field(..., min_length=1, description="MAC address or UID of the device")
    device_name: str = Field(..., min_length=1, max_length=100)
    reorder_level: float | None = Field(None, ge=0, description="Reading threshold below which an auto-reorder is triggered")
    reorder_quantity: float | None = Field(None, gt=0, description="Quantity to reorder when the reorder_level is crossed")

class DeviceInfoResponse(BaseModel):
    device_id: str
    device_name: str
    device_type: str
    is_online: bool
    last_seen_at: str | None = None
    mqtt_topic: str | None = None
    reorder_level: float | None = None
    reorder_quantity: float | None = None
    current_quantity: float | None = None
    current_quantity_updated_at: str | None = None

class DeviceDetailResponse(DeviceInfoResponse):
    household_id: str | None = None
    firmware_ver: str | None = None
    config_json: dict = {}
    latest_telemetry: dict | None = None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/", response_model=list[DeviceInfoResponse])
async def get_devices(
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """List all devices belonging to the user's household."""
    result = await db.execute(
        text("""
            SELECT d.device_id, d.device_name, d.device_type,
                   d.is_online, d.last_seen_at, d.mqtt_topic,
                   d.reorder_level, d.reorder_quantity,
                   (SELECT dr.reading_value FROM device_readings dr
                    WHERE dr.device_id = d.device_id
                    ORDER BY dr.created_at DESC LIMIT 1) AS current_quantity,
                   (SELECT dr.created_at FROM device_readings dr
                    WHERE dr.device_id = d.device_id
                    ORDER BY dr.created_at DESC LIMIT 1) AS current_quantity_updated_at
            FROM devices d
            JOIN households h ON d.household_id = h.household_id
            JOIN household_members hm ON hm.household_id = h.household_id
            WHERE hm.user_id = :uid AND d.deactivated_at IS NULL
            ORDER BY d.device_name
        """),
        {"uid": user_id},
    )
    rows = result.fetchall()
    return [
        DeviceInfoResponse(
            device_id=str(row[0]),
            device_name=row[1],
            device_type=row[2],
            is_online=row[3],
            last_seen_at=str(row[4]) if row[4] else None,
            mqtt_topic=row[5],
            reorder_level=float(row[6]) if row[6] is not None else None,
            reorder_quantity=float(row[7]) if row[7] is not None else None,
            current_quantity=float(row[8]) if row[8] is not None else None,
            current_quantity_updated_at=str(row[9]) if row[9] is not None else None,
        )
        for row in rows
    ]


@router.get("/{device_id}", response_model=DeviceDetailResponse)
async def get_device_detail(
    device_id: str,
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """Get detailed info about a specific device, including latest telemetry."""
    result = await db.execute(
        text("""
            SELECT d.device_id, d.device_name, d.device_type,
                   d.is_online, d.last_seen_at, d.mqtt_topic,
                   d.household_id, d.firmware_ver, d.config_json,
                   d.reorder_level, d.reorder_quantity,
                   (SELECT dr.reading_value FROM device_readings dr
                    WHERE dr.device_id = d.device_id
                    ORDER BY dr.created_at DESC LIMIT 1) AS current_quantity,
                   (SELECT dr.created_at FROM device_readings dr
                    WHERE dr.device_id = d.device_id
                    ORDER BY dr.created_at DESC LIMIT 1) AS current_quantity_updated_at
            FROM devices d
            JOIN households h ON d.household_id = h.household_id
            JOIN household_members hm ON hm.household_id = h.household_id
            WHERE d.device_id = :did AND hm.user_id = :uid AND d.deactivated_at IS NULL
        """),
        {"did": device_id, "uid": user_id},
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Device not found")

    # Get latest telemetry
    telemetry_result = await db.execute(
        text("""
            SELECT sensor_type, value, unit, recorded_at
            FROM sensor_readings
            WHERE device_id = :did
            ORDER BY recorded_at DESC
            LIMIT 5
        """),
        {"did": device_id},
    )
    telemetry_rows = telemetry_result.fetchall()
    latest_telemetry = None
    if telemetry_rows:
        latest_telemetry = [
            {
                "sensor_type": t[0],
                "value": float(t[1]),
                "unit": t[2],
                "recorded_at": str(t[3]),
            }
            for t in telemetry_rows
        ]

    return DeviceDetailResponse(
        device_id=str(row[0]),
        device_name=row[1],
        device_type=row[2],
        is_online=row[3],
        last_seen_at=str(row[4]) if row[4] else None,
        mqtt_topic=row[5],
        household_id=str(row[6]) if row[6] else None,
        firmware_ver=row[7],
        config_json=row[8] if row[8] else {},
        reorder_level=float(row[9]) if row[9] is not None else None,
        reorder_quantity=float(row[10]) if row[10] is not None else None,
        current_quantity=float(row[11]) if row[11] is not None else None,
        current_quantity_updated_at=str(row[12]) if row[12] is not None else None,
        latest_telemetry=latest_telemetry,
    )


@router.post("/claim", response_model=DeviceInfoResponse)
async def claim_device(
    req: ClaimDeviceRequest,
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """Create and claim a new device for the user's household."""
    # Get user's household
    household_result = await db.execute(
        text("""
            SELECT h.household_id FROM households h
            JOIN household_members hm ON hm.household_id = h.household_id
            WHERE hm.user_id = :uid AND hm.role = 'owner'
            LIMIT 1
        """),
        {"uid": user_id},
    )
    household_row = household_result.first()
    if not household_row:
        raise HTTPException(status_code=400, detail="User has no household. Please register first.")

    household_id = household_row[0]

    # Generate unique MQTT topic based on device name
    base_topic = f"kitchen/{req.device_name.lower().replace(' ', '_')}"
    mqtt_topic = f"{base_topic}_{uuid.uuid4().hex[:8]}"

    # Create new device
    device_id = uuid.uuid4()
    now = datetime.now(timezone.utc)
    await db.execute(
        text("""
            INSERT INTO devices (device_id, household_id, device_name, device_type,
                               mqtt_topic, is_online, last_seen_at, registered_at,
                               reorder_level, reorder_quantity)
            VALUES (:did, :hid, :dname, 'smart_scale', :topic, TRUE, :now, :now,
                    :reorder_level, :reorder_quantity)
        """),
        {
            "did": device_id,
            "hid": household_id,
            "dname": req.device_name,
            "topic": mqtt_topic,
            "now": now,
            "reorder_level": req.reorder_level,
            "reorder_quantity": req.reorder_quantity,
        },
    )
    await db.commit()

    return DeviceInfoResponse(
        device_id=str(device_id),
        device_name=req.device_name,
        device_type="smart_scale",
        is_online=True,
        last_seen_at=str(now),
        reorder_level=req.reorder_level,
        reorder_quantity=req.reorder_quantity,
        mqtt_topic=mqtt_topic,
    )


@router.delete("/{device_id}", status_code=204)
async def delete_device(
    device_id: str,
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """Remove a device from the user's household (soft delete)."""
    result = await db.execute(
        text("""
            UPDATE devices d
            SET deactivated_at = NOW(), is_online = FALSE
            FROM households h, household_members hm
            WHERE d.household_id = h.household_id
              AND hm.household_id = h.household_id
              AND d.device_id = :did
              AND hm.user_id = :uid
              AND d.deactivated_at IS NULL
            RETURNING d.device_id
        """),
        {"did": device_id, "uid": user_id},
    )
    if result.first() is None:
        raise HTTPException(status_code=404, detail="Device not found")
    await db.commit()
    logger.info("Device %s deactivated by user %s", device_id, user_id)


@router.get("/{device_id}/telemetry")
async def get_device_telemetry(
    device_id: str,
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(50, ge=1, le=500),
):
    """Get recent telemetry data for a device."""
    # Verify device belongs to user's household
    device_check = await db.execute(
        text("""
            SELECT d.device_id FROM devices d
            JOIN households h ON d.household_id = h.household_id
            JOIN household_members hm ON hm.household_id = h.household_id
            WHERE d.device_id = :did AND hm.user_id = :uid AND d.deactivated_at IS NULL
        """),
        {"did": device_id, "uid": user_id},
    )
    if not device_check.first():
        raise HTTPException(status_code=404, detail="Device not found")

    # Get recent sensor readings
    result = await db.execute(
        text("""
            SELECT sensor_type, value, unit, recorded_at
            FROM sensor_readings
            WHERE device_id = :did
            ORDER BY recorded_at DESC
            LIMIT :limit
        """),
        {"did": device_id, "limit": limit},
    )
    rows = result.fetchall()

    telemetry = [
        {
            "sensor_type": row[0],
            "value": float(row[1]),
            "unit": row[2],
            "recorded_at": str(row[3]),
        }
        for row in rows
    ]

    # Calculate summary statistics
    if telemetry:
        values = [t["value"] for t in telemetry]
        summary = {
            "count": len(values),
            "min": min(values),
            "max": max(values),
            "avg": sum(values) / len(values),
            "latest": values[0],
        }
    else:
        summary = {
            "count": 0,
            "min": None,
            "max": None,
            "avg": None,
            "latest": None,
        }

    return {
        "device_id": device_id,
        "telemetry": telemetry,
        "summary": summary,
    }
