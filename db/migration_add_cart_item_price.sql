-- Price entered by the user for a specific pending cart item, right before
-- checkout — lives on the order itself (cart_items), not on the device,
-- since the same container's reorder price can vary between purchases.
ALTER TABLE cart_items ADD COLUMN IF NOT EXISTS unit_price NUMERIC(10,2);
