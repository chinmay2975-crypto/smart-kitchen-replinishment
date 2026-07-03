-- ============================================================
-- Cleanup Script: Remove All Registered User Data
-- ============================================================
-- This script removes all user-created data while preserving:
-- - Database schema
-- - Seed data (suppliers)
-- - Table structures and indexes
-- ============================================================

-- Disable foreign key checks temporarily
SET session_replication_role = replica;

-- ============================================================
-- Delete in reverse dependency order
-- ============================================================

-- 1. Delete household preferences (depends on household_id, user_id)
DELETE FROM household_preferences;

-- 2. Delete household members (depends on household_id, user_id)
DELETE FROM household_members;

-- 3. Delete inventory changes (time-series data)
DELETE FROM inventory_changes;

-- 4. Delete inventory current state (depends on household_id, product_id, device_id)
DELETE FROM inventory_current;

-- 5. Delete order line items (depends on order_id, product_id)
DELETE FROM order_line_items;

-- 6. Delete replenishment orders (depends on household_id, created_by, supplier_id)
DELETE FROM replenishment_orders;

-- 7. Delete devices (depends on household_id)
-- Also need to delete related time-series data
DELETE FROM sensor_readings;
DELETE FROM device_events;
DELETE FROM telemetry_5min;
DELETE FROM devices;

-- 8. Delete product catalog (depends on household_id)
DELETE FROM product_catalog;

-- 9. Delete households (depends on owner_id)
DELETE FROM households;

-- 10. Delete alert log (depends on household_id)
DELETE FROM alert_log;

-- 11. Finally, delete all users
DELETE FROM app_users;

-- Re-enable foreign key checks
SET session_replication_role = DEFAULT;

-- ============================================================
-- Verification Queries
-- ============================================================

-- Verify all user tables are empty
SELECT 'app_users' as table_name, COUNT(*) as row_count FROM app_users
UNION ALL
SELECT 'households', COUNT(*) FROM households
UNION ALL
SELECT 'household_members', COUNT(*) FROM household_members
UNION ALL
SELECT 'household_preferences', COUNT(*) FROM household_preferences
UNION ALL
SELECT 'devices', COUNT(*) FROM devices
UNION ALL
SELECT 'product_catalog', COUNT(*) FROM product_catalog
UNION ALL
SELECT 'inventory_current', COUNT(*) FROM inventory_current
UNION ALL
SELECT 'replenishment_orders', COUNT(*) FROM replenishment_orders
UNION ALL
SELECT 'order_line_items', COUNT(*) FROM order_line_items
UNION ALL
SELECT 'alert_log', COUNT(*) FROM alert_log
UNION ALL
SELECT 'suppliers', COUNT(*) FROM suppliers
UNION ALL
SELECT 'sensor_readings', COUNT(*) FROM sensor_readings
UNION ALL
SELECT 'device_events', COUNT(*) FROM device_events
UNION ALL
SELECT 'telemetry_5min', COUNT(*) FROM telemetry_5min
UNION ALL
SELECT 'inventory_changes', COUNT(*) FROM inventory_changes;

-- ============================================================
-- Reset sequences (if using serial/identity columns)
-- ============================================================

-- Note: This project uses UUIDs, so sequences don't need resetting
-- But if you add any serial columns later, uncomment below:
-- ALTER SEQUENCE IF EXISTS some_table_id_seq RESTART WITH 1;

-- ============================================================
-- Success Message
-- ============================================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Database cleanup completed successfully!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'All user data has been removed.';
    RAISE NOTICE 'Schema and seed data (suppliers) preserved.';
    RAISE NOTICE 'You can now test fresh registrations.';
    RAISE NOTICE '========================================';
END $$;