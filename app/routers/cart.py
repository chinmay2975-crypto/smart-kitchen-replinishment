import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.security import decode_token
from app.models.orm import DeviceReading

logger = logging.getLogger("smart_kitchen.cart")
router = APIRouter(prefix="/api/v1/cart", tags=["cart"])

MOCK_DELIVERY_LEAD_DAYS = 3


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


class CartItemResponse(BaseModel):
    cart_item_id: str
    container_id: str
    item_name: str
    quantity: float
    status: str
    estimated_delivery: Optional[str] = None
    created_at: str


class CheckoutResponse(BaseModel):
    message: str
    items_placed: int
    estimated_delivery: str


class DeliverResponse(BaseModel):
    message: str
    container_id: str
    new_quantity: float


@router.get("", response_model=list[CartItemResponse])
async def get_cart(
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """List cart items for the authenticated user, both still pending and
    already placed, so the frontend can show orders dynamically as they move
    through the flow."""
    result = await db.execute(
        text("""
            SELECT cart_item_id, container_id, item_name, quantity,
                   status, estimated_delivery, created_at
            FROM cart_items
            WHERE user_id = :uid AND status IN ('pending_cart', 'placed', 'delivered')
            ORDER BY created_at DESC
        """),
        {"uid": user_id},
    )
    rows = result.fetchall()
    return [
        CartItemResponse(
            cart_item_id=str(row[0]),
            container_id=str(row[1]),
            item_name=row[2],
            quantity=float(row[3]),
            status=row[4],
            estimated_delivery=str(row[5]) if row[5] else None,
            created_at=str(row[6]),
        )
        for row in rows
    ]


@router.post("/checkout", response_model=CheckoutResponse)
async def checkout_cart(
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """Place all pending-cart items for the user, assigning a mock estimated delivery date."""
    estimated_delivery = (datetime.now(timezone.utc) + timedelta(days=MOCK_DELIVERY_LEAD_DAYS)).date()

    result = await db.execute(
        text("""
            UPDATE cart_items
            SET status = 'placed',
                estimated_delivery = :delivery,
                updated_at = NOW()
            WHERE user_id = :uid AND status = 'pending_cart'
            RETURNING cart_item_id
        """),
        {"uid": user_id, "delivery": estimated_delivery},
    )
    placed_ids = result.fetchall()
    await db.commit()

    logger.info("Checked out %d cart item(s) for user %s", len(placed_ids), user_id)

    return CheckoutResponse(
        message="Cart checked out successfully",
        items_placed=len(placed_ids),
        estimated_delivery=str(estimated_delivery),
    )


@router.post("/{cart_item_id}/deliver", response_model=DeliverResponse)
async def mark_order_delivered(
    cart_item_id: str,
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """
    Simulate a placed order being delivered: restock the container by
    writing a new device_reading (as a real sensor would report after
    someone refills it) and mark the cart item delivered.
    """
    item_result = await db.execute(
        text("""
            SELECT c.container_id, c.quantity, d.reorder_level, d.reorder_quantity
            FROM cart_items c
            JOIN devices d ON d.device_id = c.container_id
            WHERE c.cart_item_id = :cid AND c.user_id = :uid AND c.status = 'placed'
        """),
        {"cid": cart_item_id, "uid": user_id},
    )
    row = item_result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Placed order not found")

    container_id, cart_quantity, reorder_level, reorder_quantity = row
    restock_amount = float(reorder_quantity) if reorder_quantity is not None else float(cart_quantity)
    new_quantity = float(reorder_level or 0) + restock_amount

    reading = DeviceReading(
        user_id=user_id,
        device_id=container_id,
        feed_id="delivery_simulation",
        reading_value=new_quantity,
        unit="gram",
        metadata_json={"source": "delivery_simulation", "cart_item_id": cart_item_id},
    )
    db.add(reading)

    await db.execute(
        text("""
            UPDATE cart_items
            SET status = 'delivered', updated_at = NOW()
            WHERE cart_item_id = :cid
        """),
        {"cid": cart_item_id},
    )
    await db.commit()

    logger.info(
        "Order %s delivered: container %s restocked to %.2fg",
        cart_item_id, container_id, new_quantity
    )

    return DeliverResponse(
        message="Order marked as delivered and container restocked",
        container_id=str(container_id),
        new_quantity=new_quantity,
    )
