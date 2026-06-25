import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import text

from app.database import async_session_factory
from app.config import get_settings

logger = logging.getLogger("smart_kitchen.iot")
router = APIRouter(prefix="/iot", tags=["iot"])
settings = get_settings()


@router.get("/provision")
async def provision_device(
    serverToken: str = Query(...),
    mac: str = Query(...),
):
    """
    ESP8266-style device provisioning endpoint.
    Used by IoT devices to register themselves with the system.
    Compatible with the ESP8266_API-main Node.js server logic.
    """
    if serverToken != settings.server_token:
        raise HTTPException(status_code=403, detail="Invalid server token")

    async with async_session_factory() as session:
        # Check if device exists
        result = await session.execute(
            text("SELECT device_id FROM devices WHERE mqtt_topic = :mac"),
            {"mac": mac},
        )
        row = result.first()

        if row:
            device_id = row[0]
            # Update last_seen
            await session.execute(
                text("UPDATE devices SET last_seen_at = :now WHERE device_id = :did"),
                {"now": datetime.now(timezone.utc), "did": device_id},
            )
            await session.commit()
            return {
                "status": "Re-provisioned",
                "device_id": str(device_id),
            }

        # Create new device
        device_id = uuid.uuid4()
        await session.execute(
            text("""
                INSERT INTO devices (device_id, device_name, device_type, mqtt_topic, is_online, last_seen_at)
                VALUES (:did, :dname, :dtype, :topic, TRUE, :now)
            """),
            {
                "did": device_id,
                "dname": f"ESP8266-{mac[-6:]}",
                "dtype": "smart_scale",
                "topic": mac,
                "now": datetime.now(timezone.utc),
            },
        )
        await session.commit()

        return {
            "status": "Provisioned",
            "device_id": str(device_id),
        }


@router.get("/send")
async def receive_telemetry(
    serverToken: str = Query(...),
    mac: str = Query(...),
    data: str = Query(""),
):
    """
    ESP8266 data ingestion endpoint.
    Accepts telemetry data from IoT devices.
    Compatible with the ESP8266_API-main Node.js /send endpoint.
    """
    if serverToken != settings.server_token:
        raise HTTPException(status_code=403, detail="Invalid server token")

    async with async_session_factory() as session:
        # Find the device by its MAC/UID
        result = await session.execute(
            text("SELECT device_id FROM devices WHERE mqtt_topic = :mac"),
            {"mac": mac},
        )
        row = result.first()
        if not row:
            raise HTTPException(status_code=404, detail="Device not found. Provision the device first.")

        device_id = row[0]

        # Log the sensor reading
        try:
            value = float(data)
        except (ValueError, TypeError):
            value = 0.0

        await session.execute(
            text("""
                INSERT INTO sensor_readings (device_id, sensor_type, value, unit, recorded_at)
                VALUES (:did, 'weight', :val, 'gram', :now)
            """),
            {
                "did": device_id,
                "val": value,
                "now": datetime.now(timezone.utc),
            },
        )

        # Update device last_seen
        await session.execute(
            text("UPDATE devices SET last_seen_at = :now WHERE device_id = :did"),
            {"now": datetime.now(timezone.utc), "did": device_id},
        )

        await session.commit()

    return {
        "status": "OK",
        "message": "Data received",
        "device_id": str(device_id),
    }
