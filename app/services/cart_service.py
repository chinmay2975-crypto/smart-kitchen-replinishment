import logging
import uuid

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.orm import CartItem

logger = logging.getLogger("smart_kitchen.cart_service")


async def maybe_trigger_auto_reorder(
    session: AsyncSession,
    device_id: uuid.UUID,
    user_id: uuid.UUID,
    device_name: str,
    reorder_level,
    reorder_quantity,
    reading_value: float,
) -> bool:
    """
    If reading_value is below the container's reorder_level, add a pending
    cart item for it unless one is already pending. Commits if it inserts.
    Returns True if a new cart item was created.
    """
    if reorder_level is None or reading_value >= float(reorder_level):
        return False

    existing_cart_item = await session.execute(
        text("""
            SELECT cart_item_id FROM cart_items
            WHERE container_id = :cid AND status = 'pending_cart'
            LIMIT 1
        """),
        {"cid": device_id},
    )
    if existing_cart_item.first() is not None:
        return False

    cart_item = CartItem(
        user_id=user_id,
        container_id=device_id,
        item_name=f"{device_name} Supply Refill",
        quantity=reorder_quantity if reorder_quantity is not None else 1,
        status="pending_cart",
    )
    session.add(cart_item)
    await session.commit()
    logger.info(
        "Auto-reorder triggered for container %s (reading %.2f < reorder_level %.2f)",
        device_id, reading_value, float(reorder_level)
    )
    return True
