import logging
import random
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.security import decode_token

logger = logging.getLogger("smart_kitchen.api")
router = APIRouter(prefix="/api/v1", tags=["dashboard"])


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


@router.get("/profile")
async def get_profile(
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """Get the authenticated user's profile."""
    result = await db.execute(
        text("""
            SELECT u.user_id, u.full_name, u.email, u.phone, u.role,
                   h.household_id, h.name as household_name
            FROM app_users u
            LEFT JOIN households h ON h.owner_id = u.user_id
            WHERE u.user_id = :uid
        """),
        {"uid": user_id},
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "user_id": str(row[0]),
        "name": row[1],
        "email": row[2],
        "phone": row[3],
        "role": row[4],
        "household": {
            "household_id": str(row[5]) if row[5] else None,
            "name": row[6],
        } if row[5] else None,
    }


@router.get("/dashboard-data")
async def get_dashboard_data(
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """
    Unified endpoint for the dashboard frontend.
    Returns:
      - Current inventory (joined with product_catalog)
      - Top 10 most recent replenishment orders (joined with suppliers)
    """
    # 1. Current inventory with product names
    inventory_result = await db.execute(
        text("""
            SELECT
                i.inventory_id,
                i.household_id,
                i.product_id,
                p.product_name,
                p.category,
                i.quantity,
                i.unit_type,
                i.location,
                i.threshold_min,
                i.threshold_max,
                i.expiry_date,
                i.batch_lot,
                i.last_updated,
                CASE
                    WHEN i.quantity <= 0 THEN 'out_of_stock'
                    WHEN i.quantity <= COALESCE(i.threshold_min, p.default_threshold_min, 0) THEN 'low_stock'
                    ELSE 'ok'
                END AS stock_status
            FROM inventory_current i
            JOIN product_catalog p ON i.product_id = p.product_id
            JOIN households h ON i.household_id = h.household_id
            JOIN household_members hm ON hm.household_id = h.household_id
            WHERE hm.user_id = :uid
            ORDER BY i.last_updated DESC
        """),
        {"uid": user_id},
    )
    inventory_rows = inventory_result.fetchall()

    inventory_list = []
    for row in inventory_rows:
        inventory_list.append({
            "inventory_id": str(row[0]),
            "household_id": str(row[1]),
            "product_id": str(row[2]),
            "product_name": row[3],
            "category": row[4],
            "quantity": float(row[5]) if row[5] is not None else 0.0,
            "unit_type": row[6],
            "location": row[7],
            "threshold_min": float(row[8]) if row[8] is not None else None,
            "threshold_max": float(row[9]) if row[9] is not None else None,
            "expiry_date": str(row[10]) if row[10] is not None else None,
            "batch_lot": row[11],
            "last_updated": str(row[12]) if row[12] is not None else None,
            "stock_status": row[13],
        })

    # 2. Top 10 most recent replenishment orders with supplier info
    orders_result = await db.execute(
        text("""
            SELECT
                o.order_id,
                o.household_id,
                o.supplier_id,
                s.supplier_name,
                s.api_endpoint,
                o.order_status,
                o.order_type,
                o.total_amount,
                o.currency,
                o.created_at,
                o.delivered_at
            FROM replenishment_orders o
            LEFT JOIN suppliers s ON o.supplier_id = s.supplier_id
            JOIN households h ON o.household_id = h.household_id
            JOIN household_members hm ON hm.household_id = h.household_id
            WHERE hm.user_id = :uid
            ORDER BY o.created_at DESC
            LIMIT 10
        """),
        {"uid": user_id},
    )
    orders_rows = orders_result.fetchall()

    # Fetch line items for these orders
    order_ids = [row[0] for row in orders_rows]
    line_items_result = await db.execute(
        text("""
            SELECT
                li.order_id,
                li.product_id,
                p.product_name,
                li.quantity_ordered,
                li.unit_type,
                li.unit_price,
                li.total_price
            FROM order_line_items li
            JOIN product_catalog p ON li.product_id = p.product_id
            WHERE li.order_id = ANY(:oids)
            ORDER BY li.line_item_id
        """),
        {"oids": order_ids},
    )
    line_items_rows = line_items_result.fetchall()

    # Group line items by order_id
    line_items_map: dict = {}
    for row in line_items_rows:
        oid = str(row[0])
        if oid not in line_items_map:
            line_items_map[oid] = []
        line_items_map[oid].append({
            "product_id": str(row[1]),
            "product_name": row[2],
            "quantity_ordered": float(row[3]) if row[3] is not None else 0.0,
            "unit_type": row[4],
            "unit_price": float(row[5]) if row[5] is not None else None,
            "total_price": float(row[6]) if row[6] is not None else None,
        })

    orders_list = []
    for row in orders_rows:
        oid = str(row[0])
        orders_list.append({
            "order_id": oid,
            "household_id": str(row[1]),
            "supplier_id": str(row[2]) if row[2] is not None else None,
            "supplier_name": row[3],
            "api_endpoint": row[4],
            "order_status": row[5],
            "order_type": row[6],
            "total_amount": float(row[7]) if row[7] is not None else None,
            "currency": row[8],
            "created_at": str(row[9]) if row[9] is not None else None,
            "delivered_at": str(row[10]) if row[10] is not None else None,
            "line_items": line_items_map.get(oid, []),
        })

    return {
        "inventory": inventory_list,
        "recent_orders": orders_list,
    }


@router.post("/demo/generate")
async def generate_demo_data(
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
    force: bool = False,
):
    """
    Generate demo data for the authenticated user.
    Creates sample devices, products, and inventory items.
    If force=true, will clear existing demo data and regenerate.
    """
    now = datetime.now(timezone.utc)
    
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
        raise HTTPException(status_code=400, detail="User has no household")
    
    household_id = household_row[0]
    
    # If force=true, clear existing demo data first
    if force:
        logger.info("Force regenerating demo data for user %s", user_id)
        # Delete in correct order to respect foreign key constraints
        await db.execute(text("DELETE FROM sensor_readings WHERE device_id IN "
            "(SELECT device_id FROM devices WHERE household_id = :hid)"), {"hid": household_id})
        await db.execute(text("DELETE FROM inventory_current WHERE household_id = :hid"), {"hid": household_id})
        await db.execute(text("DELETE FROM product_catalog WHERE household_id = :hid"), {"hid": household_id})
        await db.execute(text("DELETE FROM devices WHERE household_id = :hid"), {"hid": household_id})
        await db.commit()
    
    # Check if user already has devices
    device_check = await db.execute(
        text("SELECT COUNT(*) FROM devices WHERE household_id = :hid"),
        {"hid": household_id},
    )
    if device_check.scalar() > 0 and not force:
        return {"message": "Demo data already exists for this household. Use force=true to regenerate.", "created": False}
    
    # Get a supplier for the products
    supplier_result = await db.execute(
        text("SELECT supplier_id FROM suppliers LIMIT 1")
    )
    supplier_row = supplier_result.first()
    supplier_id = supplier_row[0] if supplier_row else None
    
    # Create a smart scale device
    device_id = uuid.uuid4()
    await db.execute(
        text("""
            INSERT INTO devices (device_id, household_id, device_name, device_type,
                                 mqtt_topic, is_online, last_seen_at, config_json)
            VALUES (:did, :hid, 'Pantry Smart Scale', 'smart_scale',
                    :topic, TRUE, :now, '{}')
        """),
        {
            "did": device_id,
            "hid": household_id,
            "topic": f"kitchen/pantry/scale_{uuid.uuid4().hex[:8]}",
            "now": now,
        },
    )
    
    # Create sample products
    products = [
        {
            "name": "Basmati Rice",
            "category": "pantry",
            "unit_type": "kg",
            "sku": "RICE-BAS-001",
            "threshold_min": 0.50,
            "threshold_max": 5.00,
        },
        {
            "name": "Whole Wheat Atta",
            "category": "pantry",
            "unit_type": "kg",
            "sku": "ATTA-WW-001",
            "threshold_min": 0.50,
            "threshold_max": 5.00,
        },
        {
            "name": "Olive Oil",
            "category": "pantry",
            "unit_type": "liter",
            "sku": "OIL-OLV-001",
            "threshold_min": 0.10,
            "threshold_max": 1.00,
        },
    ]
    
    product_ids = []
    for p in products:
        product_id = uuid.uuid4()
        await db.execute(
            text("""
                INSERT INTO product_catalog (product_id, household_id, product_name, category,
                                           unit_type, sku, default_threshold_min, default_threshold_max,
                                           preferred_supplier_id)
                VALUES (:pid, :hid, :name, :cat, :unit, :sku, :tmin, :tmax, :sid)
            """),
            {
                "pid": product_id,
                "hid": household_id,
                "name": p["name"],
                "cat": p["category"],
                "unit": p["unit_type"],
                "sku": p["sku"],
                "tmin": p["threshold_min"],
                "tmax": p["threshold_max"],
                "sid": supplier_id,
            },
        )
        product_ids.append((product_id, p))
    
    # Create inventory items with initial quantities
    inventory_items = [
        {"product_id": product_ids[0][0], "quantity": 4.50, "unit_type": "kg", "threshold_min": 0.50, "threshold_max": 5.00},
        {"product_id": product_ids[1][0], "quantity": 4.50, "unit_type": "kg", "threshold_min": 0.50, "threshold_max": 5.00},
        {"product_id": product_ids[2][0], "quantity": 0.90, "unit_type": "liter", "threshold_min": 0.10, "threshold_max": 1.00},
    ]
    
    for inv in inventory_items:
        inv_id = uuid.uuid4()
        await db.execute(
            text("""
                INSERT INTO inventory_current (inventory_id, household_id, product_id, device_id,
                                             quantity, unit_type, location, threshold_min, threshold_max, last_updated)
                VALUES (:iid, :hid, :pid, :did, :qty, :unit, 'pantry', :tmin, :tmax, :now)
            """),
            {
                "iid": inv_id,
                "hid": household_id,
                "pid": inv["product_id"],
                "did": device_id,
                "qty": inv["quantity"],
                "unit": inv["unit_type"],
                "tmin": inv["threshold_min"],
                "tmax": inv["threshold_max"],
                "now": now,
            },
        )
    
    # Generate sample sensor readings for the device
    for i in range(20):
        reading_time = datetime.now(timezone.utc)
        reading_value = random.uniform(400, 600)  # Random weight in grams
        await db.execute(
            text("""
                INSERT INTO sensor_readings (device_id, sensor_type, value, unit, recorded_at)
                VALUES (:did, 'weight', :val, 'gram', :ts)
            """),
            {
                "did": device_id,
                "val": round(reading_value, 2),
                "ts": reading_time,
            },
        )
    
    await db.commit()
    
    logger.info("Generated demo data for user %s (household %s)", user_id, household_id)
    
    return {
        "message": "Demo data generated successfully",
        "created": True,
        "devices_created": 1,
        "products_created": len(products),
        "inventory_items_created": len(inventory_items),
        "sensor_readings_created": 20,
    }
