import logging

from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.core.security import decode_token
from app.services.zoho_service import ZohoAPIError, create_credit_note, get_wallet_balance

logger = logging.getLogger("smart_kitchen.wallet")
router = APIRouter(prefix="/api/v1/wallet", tags=["wallet"])
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


class BalanceResponse(BaseModel):
    balance: float


class TopupRequest(BaseModel):
    amount: float = Field(..., gt=0)
    description: str | None = None


class TopupResponse(BaseModel):
    message: str
    amount: float
    new_balance: float


@router.get("/balance", response_model=BalanceResponse)
async def get_balance(user_id: str = Depends(get_user_id_from_token)):
    """Current total Zoho wallet balance (sum of open Credit Notes) for
    the app's fixed Zoho customer."""
    if not settings.zoho_wallet_enabled:
        raise HTTPException(status_code=400, detail="Zoho wallet is not enabled")
    try:
        balance = await get_wallet_balance()
    except ZohoAPIError as e:
        logger.exception("Failed to fetch Zoho wallet balance for user %s", user_id)
        raise HTTPException(status_code=502, detail=f"Could not reach Zoho: {e}")
    return BalanceResponse(balance=balance)


@router.post("/topup", response_model=TopupResponse)
async def topup_wallet(
    req: TopupRequest,
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """
    Add credit to the wallet by creating a Zoho Credit Note. Synchronous
    (not a background task, unlike checkout) — the user is deliberately
    performing this action and expects to see the result/new balance
    immediately, unlike the fire-and-forget checkout flow.
    """
    if not settings.zoho_wallet_enabled:
        raise HTTPException(status_code=400, detail="Zoho wallet is not enabled")

    user_name_result = await db.execute(
        text("SELECT full_name FROM app_users WHERE user_id = :uid"),
        {"uid": user_id},
    )
    user_name_row = user_name_result.first()
    user_name = user_name_row[0] if user_name_row else "Unknown User"

    try:
        await create_credit_note(req.amount, req.description or "Wallet top-up", user_id, user_name)
        new_balance = await get_wallet_balance()
    except ZohoAPIError as e:
        logger.exception("Wallet top-up failed for user %s", user_id)
        raise HTTPException(status_code=502, detail=f"Could not complete top-up via Zoho: {e}")

    logger.info("Wallet topped up by %.2f for user %s (new balance: %.2f)", req.amount, user_id, new_balance)

    return TopupResponse(
        message="Wallet topped up successfully",
        amount=req.amount,
        new_balance=new_balance,
    )
