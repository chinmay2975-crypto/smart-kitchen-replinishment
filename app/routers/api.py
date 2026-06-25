import logging
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