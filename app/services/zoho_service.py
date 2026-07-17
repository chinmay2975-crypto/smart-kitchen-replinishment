import asyncio
import logging
import time

import httpx
from sqlalchemy import text

from app.config import get_settings
from app.database import async_session_factory

logger = logging.getLogger("smart_kitchen.zoho")
settings = get_settings()

_TOKEN_URL_PATH = "/oauth/v2/token"
_SALES_ORDER_PATH = "/inventory/v1/salesorders"
_TOKEN_TTL_SECONDS = 3300  # 55 min; Zoho tokens last 60 min — 5 min safety margin
_MAX_429_RETRIES = 3
_DEFAULT_RETRY_AFTER_SECONDS = 5

# Module-level cache — simplest fit given no existing caching layer in this
# repo; time.monotonic() avoids issues if system wall-clock time changes.
_cached_access_token: str | None = None
_cached_token_expiry: float = 0.0


class ZohoAPIError(Exception):
    """Raised when a Zoho API call fails after retries are exhausted."""


async def get_zoho_access_token() -> str:
    """
    Return a cached Zoho OAuth access token, refreshing it via the
    refresh-token grant only when the cache is empty or expired.
    """
    global _cached_access_token, _cached_token_expiry

    now = time.monotonic()
    if _cached_access_token is not None and now < _cached_token_expiry:
        return _cached_access_token

    url = f"{settings.zoho_accounts_base_url}{_TOKEN_URL_PATH}"
    # Sent as a form-encoded POST body, not query params — httpx logs full
    # request URLs (including query strings) at INFO level, which would
    # otherwise leak the refresh token and client secret into Cloud Logging.
    form_data = {
        "refresh_token": settings.zoho_refresh_token,
        "client_id": settings.zoho_client_id,
        "client_secret": settings.zoho_client_secret,
        "grant_type": "refresh_token",
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(url, data=form_data)
    response.raise_for_status()
    data = response.json()
    access_token = data["access_token"]

    _cached_access_token = access_token
    _cached_token_expiry = now + _TOKEN_TTL_SECONDS
    logger.info("Zoho access token refreshed; cached for %ds", _TOKEN_TTL_SECONDS)
    return access_token


def _build_line_item(item: dict) -> dict:
    """items: {"item_name": str, "quantity": float, "unit_price": float | None}.
    rate is omitted (not sent as 0) when unit_price wasn't set — the user
    can check out a pending item without pricing it, and Zoho defaults an
    absent rate to 0 rather than erroring."""
    line_item = {"name": item["item_name"], "quantity": item["quantity"]}
    if item.get("unit_price") is not None:
        line_item["rate"] = item["unit_price"]
    return line_item


def build_sales_order_payload(items: list[dict], user_id: str, user_name: str) -> dict:
    """
    user_name goes in reference_number (visible in the Sales Orders list
    without opening the order); user_id goes in notes (visible on open) —
    both are standard Zoho fields, no custom-field setup required.
    """
    return {
        "customer_id": settings.zoho_customer_id,
        "reference_number": user_name,
        "notes": f"App user_id: {user_id}",
        "line_items": [_build_line_item(item) for item in items],
    }


async def create_zoho_sales_order(order_data: dict) -> dict:
    """
    POST order_data to Zoho Inventory /salesorders. Retries up to
    _MAX_429_RETRIES times on HTTP 429, honoring Retry-After when present.
    Raises ZohoAPIError on non-recoverable failure.
    """
    access_token = await get_zoho_access_token()
    url = f"{settings.zoho_api_base_url}{_SALES_ORDER_PATH}"
    params = {"organization_id": settings.zoho_organization_id}
    headers = {"Authorization": f"Zoho-oauthtoken {access_token}"}

    async with httpx.AsyncClient(timeout=15.0) as client:
        response = None
        for attempt in range(1, _MAX_429_RETRIES + 1):
            response = await client.post(url, params=params, headers=headers, json=order_data)

            if response.status_code != 429:
                break

            retry_after = int(response.headers.get("Retry-After", _DEFAULT_RETRY_AFTER_SECONDS))
            logger.warning(
                "Zoho rate-limited sales order creation (attempt %d/%d); retrying in %ds",
                attempt, _MAX_429_RETRIES, retry_after,
            )
            if attempt < _MAX_429_RETRIES:
                await asyncio.sleep(retry_after)
        else:
            raise ZohoAPIError("Zoho API rate limit exceeded after retries")

    if response.status_code >= 400:
        raise ZohoAPIError(f"Zoho API error {response.status_code}: {response.text}")

    return response.json()


async def sync_checkout_to_zoho(items: list[dict], user_id: str, user_name: str) -> None:
    """
    Background-task entry point: create a Zoho Sales Order for the given
    checkout items and write the resulting salesorder_number back onto each
    cart_items row, using a fresh DB session (the original request's
    session is already closed by the time this runs). Never raises — a
    Zoho outage must never surface as a user-facing failure, since the
    checkout response was already sent.
    """
    try:
        payload = build_sales_order_payload(items, user_id, user_name)
        result = await create_zoho_sales_order(payload)
        salesorder_number = result.get("salesorder", {}).get("salesorder_number")
        if not salesorder_number:
            logger.warning("Zoho response missing salesorder_number for user %s: %s", user_id, result)
            return

        cart_item_ids = [item["cart_item_id"] for item in items]
        async with async_session_factory() as session:
            await session.execute(
                text("""
                    UPDATE cart_items
                    SET zoho_sales_order_number = :so_number, updated_at = NOW()
                    WHERE cart_item_id = ANY(:ids)
                """),
                {"so_number": salesorder_number, "ids": cart_item_ids},
            )
            await session.commit()

        logger.info(
            "Zoho sales order %s created for user %s (%d item(s))",
            salesorder_number, user_id, len(items),
        )
    except Exception:
        logger.exception("Zoho sales order sync failed for user %s (checkout already completed)", user_id)
