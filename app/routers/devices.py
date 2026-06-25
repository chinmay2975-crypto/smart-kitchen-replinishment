import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Header
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

class DeviceInfoResponse(BaseModel):
    device_id: str
    device_name: str
    device_type: str
    is_online: bool
    last_seen_at: str | None = None
    mqtt_topic: str | None = None

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
                   d.is_online, d.last_seen_at, d.mqtt_topic
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
                   d.household_id, d.firmware_ver, d.config_json
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
        latest_telemetry=latest_telemetry,
    )


@router.post("/claim", response_model=DeviceInfoResponse)
async def claim_device(
    req: ClaimDeviceRequest,
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """Claim a device by its UID/MAC address and assign it to the user's household."""
    # Find the device by UID (mqtt_topic or device_name match)
    result = await db.execute(
        text("""
            SELECT device_id, device_name, device_type, is_online, last_seen_at, mqtt_topic
            FROM devices
            WHERE (mqtt_topic = :uid OR device_name = :uid)
              AND deactivated_at IS NULL
            LIMIT 1
        """),
        {"uid": req.device_uid},
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Device not found. Check the UID.")

    device_id = row[0]

    # Check if device is already claimed by another household
    check_claimed = await db.execute(
        text("SELECT household_id FROM devices WHERE device_id = :did AND household_id IS NOT NULL"),
        {"did": device_id},
    )
    if check_claimed.first():
        raise HTTPException(status_code=409, detail="Device already claimed by another household")

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

    # Assign device to household
    now = datetime.now(timezone.utc)
    await db.execute(
        text("""
            UPDATE devices
            SET household_id = :hid, is_online = TRUE, last_seen_at = :now,
                device_name = :dname
            WHERE device_id = :did
        """),
        {
            "hid": household_id,
            "now": now,
            "dname": req.device_name,
            "did": device_id,
        },
    )
    await db.commit()

    return DeviceInfoResponse(
        device_id=str(device_id),
        device_name=req.device_name,
        device_type=row[2],
        is_online=True,
        last_seen_at=str(now),
        mqtt_topic=row[5],
    )