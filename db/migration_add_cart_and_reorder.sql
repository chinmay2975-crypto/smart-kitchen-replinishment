-- Migration: add auto-reorder cart feature
-- Safe to run against an already-deployed database (uses IF NOT EXISTS guards).

ALTER TABLE devices
    ADD COLUMN IF NOT EXISTS reorder_level    NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS reorder_quantity NUMERIC(10,2);

CREATE TABLE IF NOT EXISTS cart_items (
    cart_item_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id        UUID NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    container_id   UUID NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
    item_name      VARCHAR(255) NOT NULL,
    quantity       NUMERIC(10,2) NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'pending_cart'
                   CHECK (status IN ('pending_cart', 'placed', 'cancelled')),
    estimated_delivery DATE,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cart_items_user_status ON cart_items(user_id, status);
CREATE INDEX IF NOT EXISTS idx_cart_items_container_status ON cart_items(container_id, status);
