import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Header
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.core.security import decode_token
from app.services.zoho_service import sync_direct_checkout_to_zoho

logger = logging.getLogger("smart_kitchen.checkout")
router = APIRouter(prefix="/api/v1", tags=["checkout"])
settings = get_settings()


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


class DirectCheckoutRequest(BaseModel):
    item_id: str = Field(..., min_length=1, description="Zoho Inventory catalog Item ID")
    quantity: float = Field(..., gt=0)


class DirectCheckoutResponse(BaseModel):
    message: str
    item_id: str
    quantity: float


@router.post("/checkout", response_model=DirectCheckoutResponse)
async def direct_checkout(
    req: DirectCheckoutRequest,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a Zoho Sales Order for a single Zoho catalog item, priced from
    Zoho's own Item rate rather than a manually-entered price. Separate
    from /cart/checkout — this doesn't touch cart_items or devices at
    all, it's a direct item_id+quantity order creation.

    Runs the actual Zoho call via BackgroundTasks so this returns
    immediately, same pattern as /cart/checkout.
    """
    user_name = "Unknown User"
    if settings.zoho_enabled:
        user_name_result = await db.execute(
            text("SELECT full_name FROM app_users WHERE user_id = :uid"),
            {"uid": user_id},
        )
        user_name_row = user_name_result.first()
        user_name = user_name_row[0] if user_name_row else user_name

        background_tasks.add_task(
            sync_direct_checkout_to_zoho, req.item_id, req.quantity, user_id, user_name
        )

    return DirectCheckoutResponse(
        message="Order is being created in Zoho" if settings.zoho_enabled else "Zoho integration is disabled",
        item_id=req.item_id,
        quantity=req.quantity,
    )
