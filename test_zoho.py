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


def _fake_item_response(status_code=200, name="Rice 5kg", rate=275.5):
    mock_resp = AsyncMock()
    mock_resp.status_code = status_code
    mock_resp.text = "not found" if status_code >= 400 else ""
    mock_resp.json = lambda: {"item": {"name": name, "rate": rate}}
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


async def test_build_sales_order_payload():
    """reference_number/notes carry the user identity; a line item with a
    linked zoho_item_id is priced from Zoho's catalog (name/rate come from
    the mocked lookup, not our own item_name); an item without one falls
    back to our item_name with no rate (Zoho defaults absent rate to 0)."""
    zoho_service._cached_access_token = "cached-token"
    zoho_service._cached_token_expiry = zoho_service.time.monotonic() + 3300

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = _fake_item_response(name="Rice 5kg", rate=275.5)

        payload = await zoho_service.build_sales_order_payload(
            [
                {"item_name": "Rice 5kg Refill", "quantity": 2, "zoho_item_id": "3996483000000012345"},
                {"item_name": "Oil 1L Refill", "quantity": 1, "zoho_item_id": None},
            ],
            user_id="user-123",
            user_name="Chinmay Potdar",
        )

        assert payload["reference_number"] == "Chinmay Potdar"
        assert payload["notes"] == "App user_id: user-123"
        assert payload["line_items"][0] == {
            "item_id": "3996483000000012345", "name": "Rice 5kg", "rate": 275.5, "quantity": 2,
        }
        assert payload["line_items"][1] == {"name": "Oil 1L Refill", "quantity": 1}
        assert "rate" not in payload["line_items"][1]
        assert mock_get.call_count == 1
    print("PASS: build_sales_order_payload (catalog-priced + fallback line items)")


async def test_sales_order_creation():
    """create_zoho_sales_order posts the payload and returns Zoho's response."""
    zoho_service._cached_access_token = "cached-token"
    zoho_service._cached_token_expiry = zoho_service.time.monotonic() + 3300

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get, \
         patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_get.return_value = _fake_item_response(name="Rice 5kg", rate=275.5)
        mock_post.return_value = _fake_salesorder_response()

        payload = await zoho_service.build_sales_order_payload(
            [{"item_name": "Rice 5kg Refill", "quantity": 2, "zoho_item_id": "3996483000000012345"}],
            user_id="user-123",
            user_name="Chinmay Potdar",
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


async def test_get_zoho_item_by_id():
    """get_zoho_item_by_id fetches and returns name/rate from Zoho's catalog."""
    zoho_service._cached_access_token = "cached-token"
    zoho_service._cached_token_expiry = zoho_service.time.monotonic() + 3300

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = _fake_item_response(name="Rice 5kg", rate=275.5)

        item = await zoho_service.get_zoho_item_by_id("3996483000000012345")

        assert item == {"name": "Rice 5kg", "rate": 275.5}
        assert mock_get.call_count == 1
    print("PASS: get_zoho_item_by_id (mocked catalog fetch)")


def _fake_creditnotes_list_response(balances):
    """balances: list of floats, one open credit note per balance."""
    mock_resp = AsyncMock()
    mock_resp.status_code = 200
    mock_resp.text = ""
    mock_resp.json = lambda: {
        "creditnotes": [
            {"creditnote_id": f"cn-{i}", "balance": b} for i, b in enumerate(balances)
        ]
    }
    return mock_resp


def _fake_ok_response():
    mock_resp = AsyncMock()
    mock_resp.status_code = 200
    mock_resp.text = ""
    mock_resp.json = lambda: {"code": 0, "message": "ok"}
    return mock_resp


async def test_wallet_credit_sufficient_balance():
    """When total open credit >= invoice total, credit is applied — even
    when it takes more than one credit note to fully cover the amount."""
    zoho_service._cached_access_token = "cached-token"
    zoho_service._cached_token_expiry = zoho_service.time.monotonic() + 3300

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get, \
         patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_get.return_value = _fake_creditnotes_list_response([120.0, 100.0])  # 220 total
        mock_post.return_value = _fake_ok_response()

        applied = await zoho_service.apply_wallet_credit_if_sufficient(
            {"invoice_id": "inv-1", "total": 200.0}
        )

        assert applied is True
        # 200 needed: 120 from the first note, 80 from the second — two applies.
        assert mock_post.call_count == 2
    print("PASS: wallet credit applied when balance is sufficient (spans multiple credit notes)")


async def test_wallet_credit_insufficient_balance():
    """When total open credit < invoice total, nothing is applied at all
    (all-or-nothing, no partial application)."""
    zoho_service._cached_access_token = "cached-token"
    zoho_service._cached_token_expiry = zoho_service.time.monotonic() + 3300

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get, \
         patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_get.return_value = _fake_creditnotes_list_response([50.0])  # only 50 available

        applied = await zoho_service.apply_wallet_credit_if_sufficient(
            {"invoice_id": "inv-2", "total": 200.0}
        )

        assert applied is False
        assert mock_post.call_count == 0
    print("PASS: wallet credit skipped entirely when balance is insufficient")


def _fake_creditnote_create_response(amount=100.0, cn_number="CN-00001"):
    mock_resp = AsyncMock()
    mock_resp.status_code = 200
    mock_resp.text = ""
    mock_resp.json = lambda: {
        "creditnote": {"creditnote_number": cn_number, "total": amount, "balance": amount}
    }
    return mock_resp


async def test_create_credit_note():
    """create_credit_note posts a top-up as a Credit Note with the user's
    identity in reference_number/notes, same convention as orders/invoices."""
    zoho_service._cached_access_token = "cached-token"
    zoho_service._cached_token_expiry = zoho_service.time.monotonic() + 3300

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock) as mock_post:
        mock_post.return_value = _fake_creditnote_create_response(amount=250.0)

        result = await zoho_service.create_credit_note(250.0, "Wallet top-up", "user-123", "Chinmay Potdar")

        assert result["creditnote"]["total"] == 250.0
        posted_payload = mock_post.call_args.kwargs["json"]
        assert posted_payload["reference_number"] == "Chinmay Potdar"
        assert posted_payload["line_items"][0] == {"name": "Wallet top-up", "rate": 250.0, "quantity": 1}
    print("PASS: create_credit_note (mocked top-up)")


async def test_get_wallet_balance():
    """get_wallet_balance sums the balance across all open credit notes."""
    zoho_service._cached_access_token = "cached-token"
    zoho_service._cached_token_expiry = zoho_service.time.monotonic() + 3300

    with patch("httpx.AsyncClient.get", new_callable=AsyncMock) as mock_get:
        mock_get.return_value = _fake_creditnotes_list_response([120.0, 80.5])

        balance = await zoho_service.get_wallet_balance()

        assert balance == 200.5
    print("PASS: get_wallet_balance (summed across multiple credit notes)")


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
    await test_build_sales_order_payload()
    await test_sales_order_creation()
    await test_429_retry()
    await test_get_zoho_item_by_id()
    await test_wallet_credit_sufficient_balance()
    await test_wallet_credit_insufficient_balance()
    await test_create_credit_note()
    await test_get_wallet_balance()
    await test_live_smoke()
    print("\nAll Zoho integration tests passed.")


if __name__ == "__main__":
    asyncio.run(main())
