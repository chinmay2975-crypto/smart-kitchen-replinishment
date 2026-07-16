-- Stores the Zoho Inventory Sales Order number created for a checked-out
-- cart item, once the async Zoho sync (triggered from POST /cart/checkout
-- via a FastAPI BackgroundTask) completes. NULL until Zoho responds, and
-- stays NULL permanently if ZOHO_ENABLED is off or the sync fails —
-- checkout itself never blocks on or fails because of Zoho.
ALTER TABLE cart_items ADD COLUMN IF NOT EXISTS zoho_sales_order_number VARCHAR(100);
