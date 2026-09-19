import logging

from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.core.security import decode_token
from app.services.zoho_service import (
    ZohoAPIError,
    create_credit_note,
    get_wallet_balance,
    list_credit_notes,
    list_invoices,
)

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


async def _get_user_full_name(db: AsyncSession, user_id: str) -> str | None:
    result = await db.execute(
        text("SELECT full_name FROM app_users WHERE user_id = :uid"),
        {"uid": user_id},
    )
    row = result.first()
    return row[0] if row else None


class BalanceResponse(BaseModel):
    balance: float


class TopupRequest(BaseModel):
    amount: float = Field(..., gt=0)
    description: str | None = None


class TopupResponse(BaseModel):
    message: str
    amount: float
    new_balance: float


class TransactionOut(BaseModel):
    type: str  # "credit" (top-up) or "debit" (wallet-paid checkout)
    amount: float
    date: str | None
    number: str | None
    description: str


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

    user_name = await _get_user_full_name(db, user_id) or "Unknown User"

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


@router.get("/transactions", response_model=list[TransactionOut])
async def get_wallet_transactions(
    user_id: str = Depends(get_user_id_from_token),
    db: AsyncSession = Depends(get_db),
):
    """
    Combined credit (top-up) and debit (wallet-paid checkout) history for
    the current user. The wallet's Zoho customer is shared across the whole
    app, so records are attributed to a user by reference_number — the same
    identifier already stamped onto Credit Notes/Invoices as the user's
    full_name (see zoho_service) for exactly this kind of visibility.
    A debit is inferred as (invoice total - invoice balance): the only way
    an invoice's balance drops in this app is wallet credit being applied
    to it, since no other payment method is wired up.
    """
    if not settings.zoho_wallet_enabled:
        raise HTTPException(status_code=400, detail="Zoho wallet is not enabled")

    user_name = await _get_user_full_name(db, user_id)

    try:
        credit_notes = await list_credit_notes(settings.zoho_customer_id)
        invoices = await list_invoices(settings.zoho_customer_id)
    except ZohoAPIError as e:
        logger.exception("Failed to fetch Zoho wallet transactions for user %s", user_id)
        raise HTTPException(status_code=502, detail=f"Could not reach Zoho: {e}")

    transactions: list[TransactionOut] = []

    for cn in credit_notes:
        if user_name and cn.get("reference_number") != user_name:
            continue
        transactions.append(TransactionOut(
            type="credit",
            amount=float(cn.get("total", 0)),
            date=cn.get("date"),
            number=cn.get("creditnote_number"),
            description="Wallet top-up",
        ))

    for inv in invoices:
        if user_name and inv.get("reference_number") != user_name:
            continue
        credit_applied = float(inv.get("total", 0)) - float(inv.get("balance", 0))
        if credit_applied <= 0:
            continue
        transactions.append(TransactionOut(
            type="debit",
            amount=credit_applied,
            date=inv.get("date"),
            number=inv.get("invoice_number"),
            description="Order payment",
        ))

    transactions.sort(key=lambda t: t.date or "", reverse=True)
    return transactions
