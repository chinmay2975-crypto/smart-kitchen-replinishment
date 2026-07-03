#!/usr/bin/env python3
"""
IoT Device Data Simulation Script
Parses CSV files with device readings and bulk-inserts them into the database
linked to a specific user for dashboard visualization.

Usage:
    python simulate_data.py --user-id <user_uuid> --csv <path_to_csv> [--device-id <device_uuid>]
"""

import asyncio
import argparse
import csv
import logging
import uuid
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from pathlib import Path

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.database import async_session_factory
from app.config import get_settings

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("smart_kitchen.simulator")
settings = get_settings()


class CSVReading:
    """Represents a single reading from the CSV file."""
    def __init__(
        self,
        external_id: str,
        reading_value: float,
        feed_id: str,
        created_at: datetime,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        elevation: Optional[float] = None,
    ):
        self.external_id = external_id
        self.reading_value = reading_value
        self.feed_id = feed_id
        self.created_at = created_at
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation


def parse_csv_file(csv_path: str) -> List[CSVReading]:
    """
    Parse the CSV file with format:
    id,value,feed_id,created_at,lat,lon,ele
    
    Returns list of CSVReading objects.
    """
    readings = []
    logger.info(f"Parsing CSV file: {csv_path}")
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for row_num, row in enumerate(reader, start=2):  # Start at 2 (header is line 1)
            try:
                # Parse required fields
                external_id = row.get('id', '').strip()
                value_str = row.get('value', '').strip()
                feed_id = row.get('feed_id', '').strip()
                created_at_str = row.get('created_at', '').strip()
                
                # Parse optional fields
                lat_str = row.get('lat', '').strip()
                lon_str = row.get('lon', '').strip()
                ele_str = row.get('ele', '').strip()
                
                # Validate required fields
                if not external_id or not value_str or not feed_id or not created_at_str:
                    logger.warning(f"Row {row_num}: Missing required fields, skipping")
                    continue
                
                # Parse value
                try:
                    reading_value = float(value_str)
                except ValueError:
                    logger.warning(f"Row {row_num}: Invalid value '{value_str}', skipping")
                    continue
                
                # Parse timestamp - format: "2026-05-24 04:53:55 UTC"
                try:
                    # Remove ' UTC' suffix and parse
                    created_at_str = created_at_str.replace(' UTC', '')
                    created_at = datetime.strptime(created_at_str, '%Y-%m-%d %H:%M:%S')
                    created_at = created_at.replace(tzinfo=timezone.utc)
                except ValueError:
                    logger.warning(f"Row {row_num}: Invalid timestamp '{created_at_str}', skipping")
                    continue
                
                # Parse optional coordinates
                latitude = None
                if lat_str:
                    try:
                        latitude = float(lat_str)
                    except ValueError:
                        pass
                
                longitude = None
                if lon_str:
                    try:
                        longitude = float(lon_str)
                    except ValueError:
                        pass
                
                elevation = None
                if ele_str:
                    try:
                        elevation = float(ele_str)
                    except ValueError:
                        pass
                
                readings.append(CSVReading(
                    external_id=external_id,
                    reading_value=reading_value,
                    feed_id=feed_id,
                    created_at=created_at,
                    latitude=latitude,
                    longitude=longitude,
                    elevation=elevation,
                ))
                
            except Exception as e:
                logger.warning(f"Row {row_num}: Error parsing row: {e}")
                continue
    
    logger.info(f"Successfully parsed {len(readings)} readings from CSV")
    return readings


async def get_or_create_device_for_user(
    session: AsyncSession,
    user_id: str,
    feed_id: str
) -> str:
    """
    Get an existing device for the user or create a new one.
    Returns device_id as string.
    """
    # First, try to find user's household
    household_result = await session.execute(
        text("""
            SELECT h.household_id 
            FROM households h
            JOIN household_members hm ON hm.household_id = h.household_id
            WHERE hm.user_id = :uid AND hm.role = 'owner'
            LIMIT 1
        """),
        {"uid": user_id},
    )
    household_row = household_result.first()
    
    if not household_row:
        raise ValueError(f"User {user_id} has no household. Please create a household first.")
    
    household_id = household_row[0]
    
    # Try to find existing device with this feed_id in user's household
    device_result = await session.execute(
        text("""
            SELECT device_id 
            FROM devices 
            WHERE household_id = :hid 
              AND mqtt_topic = :feed_id
              AND deactivated_at IS NULL
            LIMIT 1
        """),
        {"hid": household_id, "feed_id": f"simulated/feed/{feed_id}"},
    )
    device_row = device_result.first()
    
    if device_row:
        logger.info(f"Found existing device {device_row[0]} for feed {feed_id}")
        return str(device_row[0])
    
    # Create new device
    device_id = uuid.uuid4()
    device_name = f"Simulated Scale {feed_id}"
    device_type = "smart_scale"
    mqtt_topic = f"simulated/feed/{feed_id}"
    
    await session.execute(
        text("""
            INSERT INTO devices (device_id, household_id, device_name, device_type, 
                                mqtt_topic, is_online, last_seen_at, config_json)
            VALUES (:did, :hid, :dname, :dtype, :mtopic, TRUE, NOW(), '{}')
        """),
        {
            "did": device_id,
            "hid": household_id,
            "dname": device_name,
            "dtype": device_type,
            "mtopic": mqtt_topic,
        },
    )
    
    logger.info(f"Created new device {device_id} for user {user_id}")
    return str(device_id)


async def bulk_insert_historical_data(
    user_id: str,
    csv_path: str,
    device_id: Optional[str] = None,
    batch_size: int = 500,
) -> Dict[str, Any]:
    """
    Bulk insert historical device readings from CSV file.
    
    Args:
        user_id: UUID of the user to link readings to
        csv_path: Path to CSV file with readings
        device_id: Optional device UUID (if not provided, will create/find one)
        batch_size: Number of records to insert per batch
    
    Returns:
        Dict with insertion statistics
    """
    # Parse CSV
    readings = parse_csv_file(csv_path)
    
    if not readings:
        return {"error": "No valid readings found in CSV", "inserted": 0}
    
    # Validate user_id
    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        return {"error": f"Invalid user_id format: {user_id}", "inserted": 0}
    
    stats = {
        "total_readings": len(readings),
        "inserted": 0,
        "skipped": 0,
        "errors": 0,
        "device_id": None,
    }
    
    async with async_session_factory() as session:
        async with session.begin():
            try:
                # Get or create device
                feed_id = readings[0].feed_id if readings else "unknown"
                
                if device_id:
                    # Validate provided device_id
                    device_uuid = uuid.UUID(device_id)
                    stats["device_id"] = device_id
                else:
                    # Auto-create/find device for this user
                    device_id = await get_or_create_device_for_user(session, user_id, feed_id)
                    stats["device_id"] = device_id
                    device_uuid = uuid.UUID(device_id)
                
                # Bulk insert in batches
                for i in range(0, len(readings), batch_size):
                    batch = readings[i:i + batch_size]
                    
                    # Build bulk insert query
                    insert_values = []
                    for reading in batch:
                        insert_values.append({
                            "user_id": user_uuid,
                            "device_id": device_uuid,
                            "feed_id": reading.feed_id,
                            "reading_value": reading.reading_value,
                            "unit": "gram",
                            "latitude": reading.latitude,
                            "longitude": reading.longitude,
                            "elevation": reading.elevation,
                            "external_id": reading.external_id,
                            "metadata_json": {"source": "csv_import", "feed_id": reading.feed_id},
                            "created_at": reading.created_at,
                        })
                    
                    # Use INSERT ... ON CONFLICT DO NOTHING to handle duplicates
                    # (based on external_id if it exists)
                    for val in insert_values:
                        try:
                            await session.execute(
                                text("""
                                    INSERT INTO device_readings 
                                    (user_id, device_id, feed_id, reading_value, unit,
                                     latitude, longitude, elevation, external_id, 
                                     metadata_json, created_at)
                                    VALUES 
                                    (:user_id, :device_id, :feed_id, :reading_value, :unit,
                                     :latitude, :longitude, :elevation, :external_id,
                                     :metadata_json, :created_at)
                                    ON CONFLICT (external_id) DO NOTHING
                                """),
                                val,
                            )
                            stats["inserted"] += 1
                        except Exception as e:
                            logger.debug(f"Error inserting reading {val.get('external_id')}: {e}")
                            stats["errors"] += 1
                
                await session.commit()
                logger.info(
                    f"Successfully inserted {stats['inserted']} readings for user {user_id}"
                )
                
            except Exception as e:
                await session.rollback()
                logger.error(f"Error during bulk insert: {e}", exc_info=True)
                return {
                    "error": str(e),
                    "inserted": stats["inserted"],
                    "total_readings": len(readings),
                }
    
    return stats


async def main():
    """Main entry point for the simulation script."""
    parser = argparse.ArgumentParser(
        description="Bulk insert device readings from CSV into database"
    )
    parser.add_argument(
        "--user-id",
        required=True,
        help="UUID of the user to link readings to"
    )
    parser.add_argument(
        "--csv",
        required=True,
        help="Path to CSV file with device readings"
    )
    parser.add_argument(
        "--device-id",
        help="Optional device UUID (will auto-create if not provided)"
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=500,
        help="Number of records to insert per batch (default: 500)"
    )
    
    args = parser.parse_args()
    
    # Validate CSV file exists
    csv_path = Path(args.csv)
    if not csv_path.exists():
        logger.error(f"CSV file not found: {args.csv}")
        return
    
    logger.info(f"Starting bulk insert for user {args.user_id}")
    logger.info(f"CSV file: {args.csv}")
    logger.info(f"Batch size: {args.batch_size}")
    
    # Run bulk insert
    stats = await bulk_insert_historical_data(
        user_id=args.user_id,
        csv_path=str(csv_path),
        device_id=args.device_id,
        batch_size=args.batch_size,
    )
    
    # Print results
    print("\n" + "="*60)
    print("BULK INSERT RESULTS")
    print("="*60)
    print(f"Total readings in CSV: {stats.get('total_readings', 0)}")
    print(f"Successfully inserted: {stats.get('inserted', 0)}")
    print(f"Errors: {stats.get('errors', 0)}")
    print(f"Device ID: {stats.get('device_id', 'N/A')}")
    
    if 'error' in stats:
        print(f"\nERROR: {stats['error']}")
    
    print("="*60 + "\n")


if __name__ == "__main__":
    asyncio.run(main())