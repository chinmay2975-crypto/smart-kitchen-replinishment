"""
Test script for the Zoho Inventory integration: verifies OAuth token
caching and sales order creation logic against mocked HTTP responses by
default (no real Zoho credentials required). Set ZOHO_LIVE_TEST=1 with
real ZOHO_* env vars populated to additionally run one live smoke call.
"""
import asyncio
import os
import sys
from unittest.mock import AsyncMock, patch

sys.path.insert(0, os.path.dirname(__file__))  # allow `import app...` when run from repo root

from app import config as app_config
from app.services import zoho_service


def _fake_token_response(access_token="fake-access-token"):
    mock_resp = AsyncMock()
    mock_resp.status_code = 200
    mock_resp.json = lambda: {"access_token": access_token, "expires_in": 3600}
    mock_resp.raise_for_status = lambda: None
    return mock_resp


def _fake_salesorder_response(status_code=200, so_number="SO-00123"):
    mock_resp = AsyncMock()
    mock_resp.status_code = status_code
    mock_resp.text = "rate limited" if status_code == 429 else ""
    mock_resp.headers = {"Retry-After": "1"} if status_code == 429 else {}
    mock_resp.json = lambda: {"salesorder": {"salesorder_number": so_number}}
    return mock_resp


async def test_token_caching():
    """A second get_zoho_access_token() call within the cache window must
    NOT re-hit the token endpoint."""
    zoho_service._cached_access_token = None
    zoho_service._cached_token_expiry = 0.0

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = _fake_token_response()

        token1 = await zoho_service.get_zoho_access_token()
        token2 = await zoho_service.get_zoho_access_token()

        assert token1 == token2 == "fake-access-token"
        assert mock_post.call_count == 1, f"expected 1 token call, got {mock_post.call_count}"
    print("PASS: token caching (second call served from cache, 1 HTTP call total)")


async def test_sales_order_creation():
    """create_zoho_sales_order posts the payload and returns Zoho's response."""
    zoho_service._cached_access_token = "cached-token"
    zoho_service._cached_token_expiry = zoho_service.time.monotonic() + 3300

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = _fake_salesorder_response()

        payload = zoho_service.build_sales_order_payload(
            [{"item_name": "Rice 5kg Refill", "quantity": 2}]
        )
        result = await zoho_service.create_zoho_sales_order(payload)

        assert result["salesorder"]["salesorder_number"] == "SO-00123"
        assert mock_post.call_count == 1
    print("PASS: sales order creation (mocked)")


async def test_429_retry():
    """A 429 followed by a 200 should succeed after one retry, sleeping
    Retry-After seconds (patched to avoid a real sleep)."""
    zoho_service._cached_access_token = "cached-token"
    zoho_service._cached_token_expiry = zoho_service.time.monotonic() + 3300

    responses = [_fake_salesorder_response(status_code=429), _fake_salesorder_response(status_code=200)]

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, side_effect=responses) as mock_post, \
         patch("asyncio.sleep", new_callable=AsyncMock) as mock_sleep:
        result = await zoho_service.create_zoho_sales_order({"customer_id": "x", "line_items": []})

        assert result["salesorder"]["salesorder_number"] == "SO-00123"
        assert mock_post.call_count == 2
        mock_sleep.assert_awaited_once_with(1)
    print("PASS: 429 retry (1 retry, honored Retry-After=1s, mocked sleep)")


async def test_live_smoke():
    """Optional: only runs if ZOHO_LIVE_TEST=1 and real credentials are set."""
    if os.environ.get("ZOHO_LIVE_TEST") != "1":
        print("SKIP: live test (set ZOHO_LIVE_TEST=1 with real ZOHO_* env vars to run)")
        return
    settings = app_config.get_settings()
    if not settings.zoho_refresh_token:
        print("SKIP: live test requested but ZOHO_REFRESH_TOKEN not set")
        return
    zoho_service._cached_access_token = None
    zoho_service._cached_token_expiry = 0.0
    token = await zoho_service.get_zoho_access_token()
    assert token
    print("PASS: live token fetch succeeded")


async def main():
    await test_token_caching()
    await test_sales_order_creation()
    await test_429_retry()
    await test_live_smoke()
    print("\nAll Zoho integration tests passed.")


if __name__ == "__main__":
    asyncio.run(main())
