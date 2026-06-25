import asyncio
import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_factory
from app.config import get_settings

logger = logging.getLogger("smart_kitchen.engine")
settings = get_settings()


async def run_replenishment_engine() -> None:
    """
    Background evaluation loop.
    Runs every EVALUATION_INTERVAL_SECONDS (default 30s for dev).
    Queries vw_low_stock_alerts, groups by household + supplier,
    checks for existing non-finalised orders, and creates new orders
    with line items inside isolated transactions (SELECT FOR UPDATE).
    """
    logger.info(
        "Replenishment engine started (interval=%ds).",
        settings.evaluation_interval_seconds,
    )

    while True:
        try:
            await _evaluate_and_order()
        except Exception as e:
            logger.error("Error in replenishment evaluation tick: %s", e, exc_info=True)
            # Wait longer before retrying after an error
            await asyncio.sleep(min(settings.evaluation_interval_seconds * 2, 300))
        await asyncio.sleep(settings.evaluation_interval_seconds)


async def _evaluate_and_order() -> None:
    """Single evaluation tick."""
    try:
        async with async_session_factory() as session:
            # Step 1: Query the low-stock view for items that need attention
            low_stock_result = await session.execute(
            text("""
                SELECT
                    v.household_id,
                    v.inventory_id,
                    v.product_id,
                    v.product_name,
                    v.quantity,
                    v.threshold_min,
                    v.stock_status,
                    v.unit_type,
                    p.preferred_supplier_id
                FROM vw_low_stock_alerts v
                JOIN product_catalog p ON v.product_id = p.product_id
                WHERE v.stock_status IN ('low_stock', 'out_of_stock')
            """)
        )
        low_stock_rows = low_stock_result.fetchall()

        if not low_stock_rows:
            logger.debug("No low-stock items found.")
            return

        # Step 2: Filter to households that have auto_replenish = TRUE
        # Build a set of household_ids from the low-stock items
        household_ids = set(row[0] for row in low_stock_rows)

        # Query household_preferences for auto_replenish
        pref_result = await session.execute(
            text("""
                SELECT household_id, user_id
                FROM household_preferences
                WHERE household_id = ANY(:h_ids)
                  AND auto_replenish = TRUE
            """),
            {"h_ids": list(household_ids)},
        )
        auto_replenish_households = set(row[0] for row in pref_result.fetchall())

        if not auto_replenish_households:
            logger.debug("No households with auto_replenish enabled found.")
            return

        # Step 3: Filter rows to only those in auto_replenish households
        qualifying_items = [
            row for row in low_stock_rows
            if row[0] in auto_replenish_households
        ]

        if not qualifying_items:
            logger.debug("No qualifying auto-replenish items after filtering.")
            return

        # Step 4: Group by (household_id, preferred_supplier_id)
        groups: dict[tuple, list] = {}
        for row in qualifying_items:
            household_id = row[0]
            supplier_id = row[8]  # preferred_supplier_id
            # If preferred_supplier_id is None, skip — can't order without a supplier
            if supplier_id is None:
                continue
            key = (household_id, supplier_id)
            groups.setdefault(key, []).append(row)

        if not groups:
            logger.debug("No items with a preferred_supplier_id.")
            return

        # Step 5: Process each group in an isolated transaction with row locks
        for (household_id, supplier_id), items in groups.items():
            await _process_group(session, household_id, supplier_id, items)

        await session.commit()
    except Exception as e:
        logger.error("Error in _evaluate_and_order: %s", e, exc_info=True)
        raise


async def _process_group(
    session: AsyncSession,
    household_id: uuid.UUID,
    supplier_id: uuid.UUID,
    items: list,
) -> None:
    """
    Process one (household, supplier) group:
      - SELECT FOR UPDATE on the matching inventory_current rows
      - Check for existing non-finalised orders to prevent duplicates
      - Create a single parent replenishment order + line items
      - Mock API dispatch log
    """
    inventory_ids = [row[1] for row in items]  # inventory_id

    # Lock the inventory rows we're about to process
    lock_result = await session.execute(
        text("""
            SELECT inventory_id, quantity, threshold_min, threshold_max, product_id, unit_type
            FROM inventory_current
            WHERE inventory_id = ANY(:inv_ids)
            FOR UPDATE
        """),
        {"inv_ids": inventory_ids},
    )
    locked_rows = lock_result.fetchall()

    if not locked_rows:
        logger.debug("No inventory rows to lock for group (%s, %s).", household_id, supplier_id)
        return

    # Check for existing non-finalised orders for this household + supplier
    existing_order_result = await session.execute(
        text("""
            SELECT order_id
            FROM replenishment_orders
            WHERE household_id = :h_id
              AND supplier_id = :s_id
              AND order_status IN ('pending', 'approved', 'submitted', 'shipped')
            LIMIT 1
        """),
        {
            "h_id": household_id,
            "s_id": supplier_id,
        },
    )
    existing_order = existing_order_result.first()

    if existing_order is not None:
        logger.info(
            "Skipping group (%s, %s) — active order %s already exists.",
            household_id,
            supplier_id,
            existing_order[0],
        )
        return

    # Fetch supplier API endpoint for mock log
    supplier_result = await session.execute(
        text("SELECT api_endpoint, supplier_name FROM suppliers WHERE supplier_id = :s_id"),
        {"s_id": supplier_id},
    )
    supplier_row = supplier_result.first()
    api_endpoint = supplier_row[0] if supplier_row else "unknown"
    supplier_name = supplier_row[1] if supplier_row else "Unknown"

    # Create the parent order
    order_id = uuid.uuid4()
    now = datetime.now(timezone.utc)

    # Calculate total amount (use threshold_max - current quantity as order qty)
    total_amount = 0.0

    await session.execute(
        text("""
            INSERT INTO replenishment_orders
                (order_id, household_id, supplier_id,
                 order_status, order_type, created_at, updated_at)
            VALUES
                (:oid, :hid, :sid,
                 'pending', 'automatic', :now, :now)
        """),
        {
            "oid": order_id,
            "hid": household_id,
            "sid": supplier_id,
            "now": now,
        },
    )

    # Insert line items for each locked inventory row
    for row in locked_rows:
        inv_id = row[0]
        current_qty = float(row[1]) if row[1] is not None else 0.0
        thr_min = float(row[2]) if row[2] is not None else 0.0
        thr_max = float(row[3]) if row[3] is not None else thr_min * 5
        product_id = row[4]
        unit_type = row[5]

        # Order enough to restock to threshold_max (capped at min 1 unit)
        shortfall = round(thr_max - current_qty, 3)
        order_qty = max(shortfall, 1.0)

        # Simple price estimation (mock)
        unit_price = 0.0
        if unit_type == "kg":
            unit_price = 120.0  # ₹120/kg for rice/atta
        elif unit_type == "liter":
            unit_price = 450.0  # ₹450/liter for olive oil
        else:
            unit_price = 50.0

        total_price = round(order_qty * unit_price, 2)
        total_amount += total_price

        await session.execute(
            text("""
                INSERT INTO order_line_items
                    (order_id, product_id, quantity_ordered,
                     unit_type, unit_price, total_price)
                VALUES
                    (:oid, :pid, :qty,
                     :unit, :uprice, :tprice)
            """),
            {
                "oid": order_id,
                "pid": product_id,
                "qty": order_qty,
                "unit": unit_type,
                "uprice": unit_price,
                "tprice": total_price,
            },
        )

    # Update total_amount on the parent order
    await session.execute(
        text("""
            UPDATE replenishment_orders
            SET total_amount = :amount
            WHERE order_id = :oid
        """),
        {"amount": round(total_amount, 2), "oid": order_id},
    )

    # Replenish inventory — add the ordered quantity back to stock
    for row in locked_rows:
        inv_id = row[0]
        current_qty = float(row[1]) if row[1] is not None else 0.0
        thr_min = float(row[2]) if row[2] is not None else 0.0
        thr_max = float(row[3]) if row[3] is not None else thr_min * 5
        unit_type = row[5]

        shortfall = round(thr_max - current_qty, 3)
        order_qty = max(shortfall, 1.0)
        new_qty = round(current_qty + order_qty, 3)

        await session.execute(
            text("""
                UPDATE inventory_current
                SET quantity = :new_qty,
                    last_updated = :now
                WHERE inventory_id = :inv_id
            """),
            {
                "new_qty": new_qty,
                "now": now,
                "inv_id": inv_id,
            },
        )
        logger.info(
            "REPLENISHED inventory %s: %.3f %s -> %.3f %s (added %.3f)",
            inv_id,
            current_qty,
            unit_type,
            new_qty,
            unit_type,
            order_qty,
        )

    # MOCK API DISPATCH (no real HTTP call)
    logger.info(
        "MOCK API DISPATCH SUCCESS: Order %s sent to supplier endpoint %s [supplier=%s]",
        order_id,
        api_endpoint,
        supplier_name,
    )
    print(
        f"MOCK API DISPATCH SUCCESS: Order {order_id} "
        f"sent to supplier endpoint {api_endpoint}"
    )
