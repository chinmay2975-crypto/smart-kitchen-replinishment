-- Migration: allow cart_items to reach a 'delivered' terminal status,
-- used when a placed order is marked delivered and restocks its container.

ALTER TABLE cart_items DROP CONSTRAINT IF EXISTS cart_items_status_check;
ALTER TABLE cart_items ADD CONSTRAINT cart_items_status_check
    CHECK (status IN ('pending_cart', 'placed', 'cancelled', 'delivered'));
