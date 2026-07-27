-- Optionally links a claimed device/container to a real Zoho Inventory
-- catalog Item, so its price can be looked up live from Zoho (see
-- get_zoho_item_by_id in app/services/zoho_service.py) instead of being
-- manually entered per order.
ALTER TABLE devices ADD COLUMN IF NOT EXISTS zoho_item_id VARCHAR(100);
