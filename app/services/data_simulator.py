import asyncio
import logging
import random
import uuid
from datetime import datetime, timezone

from sqlalchemy import text, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_factory, check_db_empty
from app.models.orm import (
    AppUser,
    Household,
    HouseholdMember,
    Device,
    ProductCatalog,
    InventoryCurrent,
    HouseholdPreference,
    SensorReading,
    Supplier,
)
from app.config import get_settings
from app.core.security import get_password_hash
from app.models.orm import DeviceReading
from app.services.cart_service import maybe_trigger_auto_reorder

logger = logging.getLogger("smart_kitchen.simulator")
settings = get_settings()

DEFAULT_CONTAINER_CAPACITY_GRAMS = 500.0


async def seed_initial_simulation_data() -> None:
    """Seed mock data on startup if the database is empty."""
    if not await check_db_empty():
        logger.info("Database already seeded — skipping initialisation.")
        return

    logger.info("Seeding initial simulation data ...")

    async with async_session_factory() as session:
        async with session.begin():
            # 1. Mock user
            user_id = uuid.uuid4()
            user = AppUser(
                user_id=user_id,
                email="santosh@kitchen.demo",
                password_hash=get_password_hash("password123"),
                full_name="Santosh Demo",
                phone="+91-9876543210",
                role="homeowner",
                is_active=True,
            )
            session.add(user)

            # 2. Household
            household_id = uuid.uuid4()
            household = Household(
                household_id=household_id,
                name="Santosh's Kitchen",
                address_line1="42, MG Road",
                city="Bangalore",
                state="Karnataka",
                postal_code="560001",
                country="IN",
                timezone="Asia/Kolkata",
                owner_id=user_id,
            )
            session.add(household)

            # 3. Household membership
            membership = HouseholdMember(
                household_id=household_id,
                user_id=user_id,
                role="owner",
            )
            session.add(membership)
            await session.flush()

            # 4. Smart scale device
            device_id = uuid.uuid4()
            device = Device(
                device_id=device_id,
                household_id=household_id,
                device_name="Pantry Smart Scale",
                device_type="smart_scale",
                mqtt_topic="kitchen/pantry/scale_001",
                firmware_ver="2.1.0",
                is_online=True,
                last_seen_at=datetime.now(timezone.utc),
                config_json={"calibration_offset": 0.0, "unit": "gram"},
            )
            session.add(device)

            # 5. Fetch a supplier (seeded in init.sql) to use as preferred
            supplier_result = await session.execute(
                text("SELECT supplier_id FROM suppliers LIMIT 1")
            )
            supplier_row = supplier_result.first()
            supplier_id = supplier_row[0] if supplier_row else None

            # 6. Products
            products_data = [
                {
                    "product_name": "Basmati Rice",
                    "category": "pantry",
                    "unit_type": "kg",
                    "sku": "RICE-BAS-001",
                    "default_threshold_min": 0.50,
                    "default_threshold_max": 5.00,
                    "preferred_supplier_id": supplier_id,
                },
                {
                    "product_name": "Whole Wheat Atta",
                    "category": "pantry",
                    "unit_type": "kg",
                    "sku": "ATTA-WW-001",
                    "default_threshold_min": 0.50,
                    "default_threshold_max": 5.00,
                    "preferred_supplier_id": supplier_id,
                },
                {
                    "product_name": "Olive Oil",
                    "category": "pantry",
                    "unit_type": "liter",
                    "sku": "OIL-OLV-001",
                    "default_threshold_min": 0.10,
                    "default_threshold_max": 1.00,
                    "preferred_supplier_id": supplier_id,
                },
            ]

            product_ids = []
            for pd in products_data:
                product = ProductCatalog(
                    household_id=household_id,
                    sku=pd["sku"],
                    product_name=pd["product_name"],
                    category=pd["category"],
                    unit_type=pd["unit_type"],
                    default_threshold_min=pd["default_threshold_min"],
                    default_threshold_max=pd["default_threshold_max"],
                    preferred_supplier_id=pd["preferred_supplier_id"],
                )
                session.add(product)
                await session.flush()
                product_ids.append((product.product_id, pd))

            # 7. Inventory current (near max capacity)
            inventory_items = [
                {
                    "product_id": product_ids[0][0],
                    "quantity": 4.50,
                    "unit_type": "kg",
                    "threshold_min": 0.50,
                    "threshold_max": 5.00,
                },
                {
                    "product_id": product_ids[1][0],
                    "quantity": 4.50,
                    "unit_type": "kg",
                    "threshold_min": 0.50,
                    "threshold_max": 5.00,
                },
                {
                    "product_id": product_ids[2][0],
                    "quantity": 0.90,
                    "unit_type": "liter",
                    "threshold_min": 0.10,
                    "threshold_max": 1.00,
                },
            ]

            for inv in inventory_items:
                inventory = InventoryCurrent(
                    household_id=household_id,
                    product_id=inv["product_id"],
                    device_id=device_id,
                    quantity=inv["quantity"],
                    unit_type=inv["unit_type"],
                    location="pantry",
                    threshold_min=inv["threshold_min"],
                    threshold_max=inv["threshold_max"],
                )
                session.add(inventory)

            # 8. Household preferences (auto-replenish enabled)
            preference = HouseholdPreference(
                household_id=household_id,
                user_id=user_id,
                auto_replenish=True,
                notify_low_stock=True,
                notify_expiry=True,
                preferred_replenish_day="monday",
                notification_channels=["push", "email"],
            )
            session.add(preference)

        logger.info("Seed data committed successfully.")


async def run_telemetry_simulation() -> None:
    """Background loop: every 10s deduct random weight from each demo
    inventory item. Gated behind ENABLE_SIMULATION — demo data only."""
    logger.info(
        "Telemetry simulation started (interval=%ds).",
        settings.telemetry_interval_seconds,
    )

    while True:
        try:
            await _telemetry_tick()
        except Exception:
            logger.exception("Error in telemetry simulation tick")
        await asyncio.sleep(settings.telemetry_interval_seconds)


async def run_container_simulation() -> None:
    """Background loop: every 10s deduct weight from every real claimed
    container. Always runs (not gated by ENABLE_SIMULATION) since this
    simulates actual user devices, not demo data."""
    logger.info(
        "Container simulation started (interval=%ds).",
        settings.telemetry_interval_seconds,
    )

    while True:
        try:
            await _container_devices_tick()
        except Exception:
            logger.exception("Error in container devices simulation tick")
        await asyncio.sleep(settings.telemetry_interval_seconds)


async def _container_devices_tick() -> None:
    """
    Deplete every claimed device that isn't already handled by the
    inventory_current-based tick above (i.e. real/manually-claimed
    containers, not demo-generated ones). Mirrors a real weight sensor
    slowly reporting less content over time, and can trigger the
    auto-reorder cart just like a real low reading.
    """
    async with async_session_factory() as session:
        result = await session.execute(
            text("""
                SELECT
                    d.device_id,
                    d.device_name,
                    d.reorder_level,
                    d.reorder_quantity,
                    h.owner_id,
                    (SELECT dr.reading_value FROM device_readings dr
                     WHERE dr.device_id = d.device_id
                     ORDER BY dr.created_at DESC LIMIT 1) AS last_reading
                FROM devices d
                JOIN households h ON h.household_id = d.household_id
                WHERE d.deactivated_at IS NULL
                  AND d.device_id NOT IN (
                      SELECT device_id FROM inventory_current WHERE device_id IS NOT NULL
                  )
            """)
        )
        rows = result.fetchall()
        if not rows:
            return

        now = datetime.now(timezone.utc)

        for row in rows:
            device_id, device_name, reorder_level, reorder_quantity, owner_id, last_reading = row
            if owner_id is None:
                continue

            capacity = float(reorder_level) * 2 if reorder_level is not None else DEFAULT_CONTAINER_CAPACITY_GRAMS

            if last_reading is None:
                # Device claimed before initial-fill seeding existed — give it
                # a starting point instead of sitting empty forever.
                new_value = capacity
            else:
                deduction = random.uniform(0.02, 0.05) * capacity
                new_value = max(round(float(last_reading) - deduction, 2), 0.0)

            device_reading = DeviceReading(
                user_id=owner_id,
                device_id=device_id,
                feed_id="simulator",
                reading_value=new_value,
                unit="gram",
                metadata_json={"source": "telemetry_simulator"},
                created_at=now,
            )
            session.add(device_reading)
            await session.flush()

            await maybe_trigger_auto_reorder(
                session=session,
                device_id=device_id,
                user_id=owner_id,
                device_name=device_name,
                reorder_level=reorder_level,
                reorder_quantity=reorder_quantity,
                reading_value=new_value,
            )

        await session.commit()


async def _telemetry_tick() -> None:
    """Single tick: deduct weight, log sensor reading, update inventory_current."""
    async with async_session_factory() as session:
        # Fetch all inventory items that have a device_id
        result = await session.execute(
            text("""
                SELECT
                    i.inventory_id,
                    i.product_id,
                    i.household_id,
                    i.device_id,
                    i.quantity,
                    i.unit_type,
                    i.threshold_min,
                    d.device_name,
                    d.reorder_level,
                    d.reorder_quantity,
                    h.owner_id
                FROM inventory_current i
                JOIN devices d ON d.device_id = i.device_id
                JOIN households h ON h.household_id = i.household_id
                WHERE i.device_id IS NOT NULL
            """)
        )
        rows = result.fetchall()

        if not rows:
            logger.debug("No inventory items with device_id found — skipping tick.")
            return

        now = datetime.now(timezone.utc)

        for row in rows:
            inventory_id = row[0]
            product_id = row[1]
            device_id = row[3]
            current_qty = float(row[4])
            unit_type = row[5]
            device_name = row[7]
            reorder_level = row[8]
            reorder_quantity = row[9]
            owner_id = row[10]

            # Random deduction: 100-200 grams
            deduction_grams = random.uniform(100.0, 200.0)

            # Convert deduction to the item's unit_type
            if unit_type in ("kg",):
                deduction = round(deduction_grams / 1000.0, 3)
            elif unit_type in ("liter", "ml"):
                # Treat grams ≈ ml for water-density liquids; close enough for simulation
                if unit_type == "liter":
                    deduction = round(deduction_grams / 1000.0, 3)
                else:
                    deduction = round(deduction_grams, 1)
            else:
                deduction = round(deduction_grams, 1)

            new_qty = max(round(current_qty - deduction, 3), 0.0)

            # 1. Insert sensor reading (raw weight in grams)
            sensor_reading = SensorReading(
                device_id=device_id,
                sensor_type="weight",
                value=round(deduction_grams, 2),
                unit="gram",
                metadata_json={
                    "inventory_id": str(inventory_id),
                    "product_id": str(product_id),
                    "deduction_in_unit": deduction,
                    "unit_type": unit_type,
                },
                recorded_at=now,
            )
            session.add(sensor_reading)

            # 2. Update inventory_current snapshot
            await session.execute(
                text("""
                    UPDATE inventory_current
                    SET quantity = :new_qty,
                        last_updated = :now
                    WHERE inventory_id = :inv_id
                """),
                {
                    "new_qty": new_qty,
                    "now": now,
                    "inv_id": inventory_id,
                },
            )

            logger.debug(
                "SIM [%s] %.3f%s -> %.3f%s (deducted %.2fg)",
                product_id,
                current_qty,
                unit_type,
                new_qty,
                unit_type,
                deduction_grams,
            )

            # 3. Mirror the container's remaining weight into device_readings
            # (grams) so it shows up in the container view and can trigger
            # the auto-reorder cart, same as a real sensor posting a reading.
            if owner_id is not None:
                remaining_grams = new_qty * 1000.0 if unit_type in ("kg", "liter") else new_qty
                device_reading = DeviceReading(
                    user_id=owner_id,
                    device_id=device_id,
                    feed_id="simulator",
                    reading_value=round(remaining_grams, 2),
                    unit="gram",
                    metadata_json={"source": "telemetry_simulator", "inventory_id": str(inventory_id)},
                    created_at=now,
                )
                session.add(device_reading)
                await session.flush()

                await maybe_trigger_auto_reorder(
                    session=session,
                    device_id=device_id,
                    user_id=owner_id,
                    device_name=device_name,
                    reorder_level=reorder_level,
                    reorder_quantity=reorder_quantity,
                    reading_value=round(remaining_grams, 2),
                )

        await session.commit()