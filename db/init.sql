-- ============================================================
-- Smart Kitchen Automated Replenishment System
-- PostgreSQL + TimescaleDB Schema
-- Unified DB: App Tables (Relational) + Device Tables (Time-Series)
-- ============================================================

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- SECTION 1: APP TABLES (Relational)
-- ============================================================

-- 1.1 User Management
CREATE TABLE app_users (
    user_id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email          VARCHAR(255) UNIQUE NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    full_name      VARCHAR(150) NOT NULL,
    phone          VARCHAR(20),
    role           VARCHAR(20) NOT NULL DEFAULT 'homeowner'
                   CHECK (role IN ('homeowner', 'admin', 'supplier')),
    is_active      BOOLEAN DEFAULT TRUE,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- 1.2 Kitchen/Household (multi-tenant)
CREATE TABLE households (
    household_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name           VARCHAR(200) NOT NULL,
    address_line1  VARCHAR(255),
    address_line2  VARCHAR(255),
    city           VARCHAR(100),
    state          VARCHAR(100),
    postal_code    VARCHAR(20),
    country        VARCHAR(100) DEFAULT 'IN',
    timezone       VARCHAR(50) DEFAULT 'Asia/Kolkata',
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    owner_id       UUID REFERENCES app_users(user_id)
);

-- 1.3 Household Membership (many-to-many)
CREATE TABLE household_members (
    household_id   UUID REFERENCES households(household_id) ON DELETE CASCADE,
    user_id        UUID REFERENCES app_users(user_id) ON DELETE CASCADE,
    role           VARCHAR(20) DEFAULT 'member'
                   CHECK (role IN ('owner', 'member', 'viewer')),
    joined_at      TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (household_id, user_id)
);

-- 1.4 Device Registry (metadata for physical devices)
CREATE TABLE devices (
    device_id      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    household_id   UUID REFERENCES households(household_id) ON DELETE CASCADE,
    device_name    VARCHAR(100) NOT NULL,
    device_type    VARCHAR(50) NOT NULL
                   CHECK (device_type IN (
                       'fridge', 'freezer', 'pantry_shelf',
                       'weight_sensor', 'smart_bin', 'barcode_scanner',
                       'temp_humidity_sensor', 'smart_scale', 'cabinet_sensor'
                   )),
    mqtt_topic     VARCHAR(255) UNIQUE NOT NULL,
    firmware_ver   VARCHAR(30),
    is_online      BOOLEAN DEFAULT FALSE,
    last_seen_at   TIMESTAMPTZ,
    config_json    JSONB DEFAULT '{}',
    registered_at  TIMESTAMPTZ DEFAULT NOW(),
    deactivated_at TIMESTAMPTZ,
    reorder_level    NUMERIC(10,2),
    reorder_quantity NUMERIC(10,2),
    battery_level    NUMERIC(5,2) DEFAULT 100
);

-- 1.5 Product/Ingredient Catalog
CREATE TABLE product_catalog (
    product_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    household_id   UUID REFERENCES households(household_id) ON DELETE CASCADE,
    sku            VARCHAR(100),
    product_name   VARCHAR(255) NOT NULL,
    category       VARCHAR(100) NOT NULL
                   CHECK (category IN (
                       'dairy', 'produce', 'meat', 'seafood',
                       'pantry', 'beverages', 'condiments', 'frozen',
                       'snacks', 'bakery', 'spices', 'other'
                   )),
    unit_type      VARCHAR(30) NOT NULL
                   CHECK (unit_type IN ('piece', 'gram', 'kg', 'ml', 'liter',
                                        'oz', 'lb', 'cup', 'tsp', 'tbsp')),
    default_threshold_min NUMERIC(10,2),
    default_threshold_max NUMERIC(10,2),
    image_url      TEXT,
    barcode        VARCHAR(100),
    preferred_supplier_id UUID,
    is_perishable  BOOLEAN DEFAULT FALSE,
    shelf_life_days INTEGER,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (household_id, sku)
);

-- 1.6 Current Inventory State (snapshot)
CREATE TABLE inventory_current (
    inventory_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    household_id   UUID REFERENCES households(household_id) ON DELETE CASCADE,
    product_id     UUID REFERENCES product_catalog(product_id) ON DELETE CASCADE,
    device_id      UUID REFERENCES devices(device_id) ON DELETE SET NULL,
    quantity       NUMERIC(10,2) NOT NULL DEFAULT 0,
    unit_type      VARCHAR(30) NOT NULL,
    location       VARCHAR(100) DEFAULT 'pantry',
    threshold_min  NUMERIC(10,2),
    threshold_max  NUMERIC(10,2),
    expiry_date    DATE,
    batch_lot      VARCHAR(100),
    last_updated   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (household_id, product_id)
);

-- 1.7 Replenishment Orders
CREATE TABLE replenishment_orders (
    order_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    household_id   UUID REFERENCES households(household_id) ON DELETE CASCADE,
    created_by     UUID REFERENCES app_users(user_id),
    supplier_id    UUID,
    order_status   VARCHAR(30) DEFAULT 'pending'
                   CHECK (order_status IN (
                       'pending', 'approved', 'submitted',
                       'shipped', 'delivered', 'cancelled'
                   )),
    order_type     VARCHAR(20) DEFAULT 'automatic'
                   CHECK (order_type IN ('automatic', 'manual')),
    total_amount   NUMERIC(12,2),
    currency       VARCHAR(3) DEFAULT 'INR',
    notes          TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW(),
    delivered_at   TIMESTAMPTZ
);

-- 1.8 Order Line Items
CREATE TABLE order_line_items (
    line_item_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id       UUID REFERENCES replenishment_orders(order_id) ON DELETE CASCADE,
    product_id     UUID REFERENCES product_catalog(product_id),
    quantity_ordered NUMERIC(10,2) NOT NULL,
    quantity_received NUMERIC(10,2),
    unit_type      VARCHAR(30) NOT NULL,
    unit_price     NUMERIC(10,2),
    total_price    NUMERIC(10,2),
    supplier_sku   VARCHAR(100)
);

-- 1.9 Device Readings (for demo data and manual readings)
CREATE TABLE device_readings (
    reading_id     BIGSERIAL PRIMARY KEY,
    user_id        UUID NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    device_id      UUID REFERENCES devices(device_id) ON DELETE SET NULL,
    feed_id        VARCHAR(50),
    reading_value  NUMERIC(10,2) NOT NULL,
    unit           VARCHAR(20) DEFAULT 'gram',
    latitude       NUMERIC(9,6),
    longitude      NUMERIC(9,6),
    elevation      NUMERIC(8,2),
    external_id    VARCHAR(50),
    metadata_json  JSONB DEFAULT '{}',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_device_readings_user_created ON device_readings(user_id, created_at);

-- 1.9b Auto-Reorder Cart (Amazon-style pending cart, separate from replenishment_orders)
CREATE TABLE cart_items (
    cart_item_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id        UUID NOT NULL REFERENCES app_users(user_id) ON DELETE CASCADE,
    container_id   UUID NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
    item_name      VARCHAR(255) NOT NULL,
    quantity       NUMERIC(10,2) NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'pending_cart'
                   CHECK (status IN ('pending_cart', 'placed', 'cancelled', 'delivered')),
    estimated_delivery DATE,
    zoho_sales_order_number VARCHAR(100),
    unit_price     NUMERIC(10,2),
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cart_items_user_status ON cart_items(user_id, status);
CREATE INDEX idx_cart_items_container_status ON cart_items(container_id, status);

-- 1.10 Supplier Registry
CREATE TABLE suppliers (
    supplier_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supplier_name  VARCHAR(200) NOT NULL,
    contact_name   VARCHAR(150),
    email          VARCHAR(255),
    phone          VARCHAR(20),
    website        VARCHAR(255),
    api_endpoint   VARCHAR(255),
    api_key_enc    TEXT,
    is_active      BOOLEAN DEFAULT TRUE,
    delivery_lead_time_hours INTEGER DEFAULT 48,
    min_order_amount NUMERIC(10,2) DEFAULT 0,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- 1.10 Notification / Alert Log
CREATE TABLE alert_log (
    alert_id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    household_id   UUID REFERENCES households(household_id) ON DELETE CASCADE,
    alert_type     VARCHAR(50) NOT NULL
                   CHECK (alert_type IN (
                       'low_stock', 'out_of_stock', 'expiry_warning',
                       'device_offline', 'device_error', 'order_status',
                       'price_change', 'temp_exceeded'
                   )),
    severity       VARCHAR(20) DEFAULT 'info'
                   CHECK (severity IN ('info', 'warning', 'critical')),
    title          VARCHAR(255) NOT NULL,
    message        TEXT,
    is_read        BOOLEAN DEFAULT FALSE,
    is_resolved    BOOLEAN DEFAULT FALSE,
    related_entity_type VARCHAR(50),
    related_entity_id   UUID,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    resolved_at    TIMESTAMPTZ
);

-- 1.11 User Preferences per Household
CREATE TABLE household_preferences (
    preference_id  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    household_id   UUID REFERENCES households(household_id) ON DELETE CASCADE,
    user_id        UUID REFERENCES app_users(user_id) ON DELETE CASCADE,
    auto_replenish BOOLEAN DEFAULT TRUE,
    notify_low_stock BOOLEAN DEFAULT TRUE,
    notify_expiry  BOOLEAN DEFAULT TRUE,
    preferred_replenish_day VARCHAR(20) DEFAULT 'monday'
                   CHECK (preferred_replenish_day IN (
                       'monday','tuesday','wednesday','thursday',
                       'friday','saturday','sunday'
                   )),
    notification_channels JSONB DEFAULT '["push", "email"]',
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (household_id, user_id)
);

-- Indexes for App Tables
CREATE INDEX idx_inventory_household ON inventory_current(household_id);
CREATE INDEX idx_inventory_threshold ON inventory_current(household_id, product_id) WHERE quantity <= threshold_min;
CREATE INDEX idx_orders_household_status ON replenishment_orders(household_id, order_status);
CREATE INDEX idx_alerts_household_unread ON alert_log(household_id, is_read) WHERE NOT is_read;
CREATE INDEX idx_devices_household ON devices(household_id);
CREATE INDEX idx_devices_online ON devices(is_online) WHERE is_online = TRUE;
CREATE INDEX idx_product_barcode ON product_catalog(barcode);
CREATE INDEX idx_users_email ON app_users(email);

-- ============================================================
-- SECTION 2: DEVICE TABLES (Time-Series via TimescaleDB)
-- ============================================================

-- 2.1 Sensor Reading Stream (generic)
CREATE TABLE sensor_readings (
    reading_id     BIGSERIAL,
    device_id      UUID NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
    sensor_type    TEXT NOT NULL
                   CHECK (sensor_type IN (
                       'temperature', 'humidity', 'weight',
                       'fill_level', 'door_status', 'motion',
                       'pressure', 'light', 'gas'
                   )),
    value          NUMERIC(10,4) NOT NULL,
    unit           TEXT NOT NULL,
    metadata_json  JSONB DEFAULT '{}',
    recorded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Convert sensor_readings to hypertable
SELECT create_hypertable(
    'sensor_readings',
    'recorded_at',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- Indexes for time-series queries
CREATE INDEX idx_sensor_device_time ON sensor_readings(device_id, recorded_at DESC);
CREATE INDEX idx_sensor_type_time ON sensor_readings(sensor_type, recorded_at DESC);

-- 2.2 Device Event Log (state changes, door open/close, errors)
CREATE TABLE device_events (
    event_id       BIGSERIAL,
    device_id      UUID NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
    event_type     TEXT NOT NULL
                   CHECK (event_type IN (
                       'door_open', 'door_close', 'item_added',
                       'item_removed', 'error', 'warning',
                       'firmware_update', 'calibration', 'heartbeat',
                       'connection_status', 'low_battery'
                   )),
    event_value    TEXT,
    severity       TEXT DEFAULT 'info',
    payload_json   JSONB DEFAULT '{}',
    recorded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT create_hypertable(
    'device_events',
    'recorded_at',
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE
);

CREATE INDEX idx_events_device_time ON device_events(device_id, recorded_at DESC);
CREATE INDEX idx_events_type_time ON device_events(event_type, recorded_at DESC);

-- 2.3 Inventory Change Stream (time-series audit trail)
CREATE TABLE inventory_changes (
    change_id      BIGSERIAL,
    household_id   UUID NOT NULL REFERENCES households(household_id),
    product_id     UUID NOT NULL REFERENCES product_catalog(product_id),
    device_id      UUID REFERENCES devices(device_id),
    change_type    TEXT NOT NULL
                   CHECK (change_type IN (
                       'added', 'removed', 'adjusted',
                       'expired', 'restocked', 'consumed'
                   )),
    quantity_before NUMERIC(10,2) NOT NULL,
    quantity_after  NUMERIC(10,2) NOT NULL,
    delta_quantity  NUMERIC(10,2) NOT NULL,
    unit_type      TEXT NOT NULL,
    confidence     NUMERIC(5,4) DEFAULT 1.0,
    recorded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

SELECT create_hypertable(
    'inventory_changes',
    'recorded_at',
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE
);

CREATE INDEX idx_inv_changes_household_time ON inventory_changes(household_id, recorded_at DESC);
CREATE INDEX idx_inv_changes_product_time ON inventory_changes(product_id, recorded_at DESC);

-- 2.4 Device Telemetry Summary (pre-aggregated 5-min buckets)
CREATE TABLE telemetry_5min (
    device_id      UUID NOT NULL REFERENCES devices(device_id),
    bucket_time    TIMESTAMPTZ NOT NULL,
    sensor_type    TEXT NOT NULL,
    avg_value      NUMERIC(10,4),
    min_value      NUMERIC(10,4),
    max_value      NUMERIC(10,4),
    sample_count   INTEGER,
    recorded_at    TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (device_id, bucket_time, sensor_type)
);

SELECT create_hypertable(
    'telemetry_5min',
    'bucket_time',
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE
);

-- ============================================================
-- SECTION 3: VIEWS & MATERIALIZED VIEWS
-- ============================================================

-- 3.1 Low Stock Alert View
CREATE VIEW vw_low_stock_alerts AS
SELECT
    i.household_id,
    i.inventory_id,
    i.product_id,
    p.product_name,
    p.category,
    i.quantity,
    i.threshold_min,
    i.unit_type,
    i.location,
    i.expiry_date,
    CASE
        WHEN i.quantity <= 0 THEN 'out_of_stock'
        WHEN i.quantity <= i.threshold_min THEN 'low_stock'
        ELSE 'ok'
    END AS stock_status,
    NOW() - i.last_updated AS age_since_update
FROM inventory_current i
JOIN product_catalog p ON i.product_id = p.product_id
WHERE i.quantity <= COALESCE(i.threshold_min, p.default_threshold_min, 0)
ORDER BY i.quantity ASC;

-- 3.2 Recently Offline Devices View
CREATE VIEW vw_offline_devices AS
SELECT
    d.device_id,
    d.device_name,
    d.device_type,
    d.household_id,
    d.last_seen_at,
    EXTRACT(EPOCH FROM (NOW() - d.last_seen_at)) / 3600 AS hours_offline
FROM devices d
WHERE d.is_online = FALSE
  AND d.deactivated_at IS NULL
ORDER BY d.last_seen_at ASC;

-- ============================================================
-- SECTION 4: RETENTION POLICIES (via TimescaleDB)
-- ============================================================

-- Raw sensor data: keep 90 days
SELECT add_retention_policy('sensor_readings', INTERVAL '90 days', if_not_exists => TRUE);

-- Device events: keep 180 days
SELECT add_retention_policy('device_events', INTERVAL '180 days', if_not_exists => TRUE);

-- Inventory changes: keep 365 days
SELECT add_retention_policy('inventory_changes', INTERVAL '365 days', if_not_exists => TRUE);

-- Telemetry summary: keep 2 years
SELECT add_retention_policy('telemetry_5min', INTERVAL '2 years', if_not_exists => TRUE);

-- ============================================================
-- SECTION 5: COMPRESSION POLICIES (TimescaleDB)
-- ============================================================

ALTER TABLE sensor_readings SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'recorded_at DESC'
);
SELECT add_compression_policy('sensor_readings', INTERVAL '7 days', if_not_exists => TRUE);

ALTER TABLE device_events SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'recorded_at DESC'
);
SELECT add_compression_policy('device_events', INTERVAL '14 days', if_not_exists => TRUE);

-- inventory_changes has FK on household_id, product_id, device_id — all must be in segmentby
ALTER TABLE inventory_changes SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'household_id,product_id,device_id',
    timescaledb.compress_orderby = 'recorded_at DESC'
);
SELECT add_compression_policy('inventory_changes', INTERVAL '14 days', if_not_exists => TRUE);

-- ============================================================
-- SECTION 6: CONTINUOUS AGGREGATES (Downsampling)
-- ============================================================

-- Hourly temperature averages per device
CREATE MATERIALIZED VIEW cagg_hourly_temp
WITH (timescaledb.continuous) AS
SELECT
    device_id,
    time_bucket(INTERVAL '1 hour', recorded_at) AS bucket,
    AVG(value) AS avg_temp,
    MIN(value) AS min_temp,
    MAX(value) AS max_temp,
    COUNT(*) AS sample_count
FROM sensor_readings
WHERE sensor_type = 'temperature'
GROUP BY device_id, bucket
WITH NO DATA;

SELECT add_continuous_aggregate_policy('cagg_hourly_temp',
    start_offset    => INTERVAL '3 days',
    end_offset      => INTERVAL '1 hour',
    schedule_interval => INTERVAL '30 minutes',
    if_not_exists   => TRUE
);

-- Daily weight change summary per device
CREATE MATERIALIZED VIEW cagg_daily_weight
WITH (timescaledb.continuous) AS
SELECT
    device_id,
    time_bucket(INTERVAL '1 day', recorded_at) AS bucket,
    AVG(value) AS avg_weight,
    MIN(value) AS min_weight,
    MAX(value) AS max_weight,
    LAST(value, recorded_at) AS last_weight,
    FIRST(value, recorded_at) AS first_weight,
    COUNT(*) AS sample_count
FROM sensor_readings
WHERE sensor_type = 'weight'
GROUP BY device_id, bucket
WITH NO DATA;

SELECT add_continuous_aggregate_policy('cagg_daily_weight',
    start_offset    => INTERVAL '7 days',
    end_offset      => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists   => TRUE
);

-- ============================================================
-- SECTION 7: SEED DATA (Development Defaults)
-- ============================================================

INSERT INTO suppliers (supplier_id, supplier_name, contact_name, email, phone, is_active, delivery_lead_time_hours, min_order_amount)
VALUES
    (gen_random_uuid(), 'BigBasket', 'Support Team', 'support@bigbasket.com', '1800-123-1234', TRUE, 24, 199.00),
    (gen_random_uuid(), 'Zepto', 'Zepto Ops', 'ops@zepto.in', '1800-200-1234', TRUE, 12, 99.00),
    (gen_random_uuid(), 'Blinkit', 'Blinkit CS', 'care@blinkit.com', '1800-300-5678', TRUE, 10, 49.00),
    (gen_random_uuid(), 'Amazon Fresh', 'Fresh Team', 'fresh@amazon.in', '1800-400-9012', TRUE, 48, 299.00);

-- ============================================================
-- SCHEMA VERIFICATION
-- ============================================================

DO $$
BEGIN
    RAISE NOTICE 'Smart Kitchen Replenishment DB schema initialized successfully.';
    RAISE NOTICE '  - App Tables: 13 relational tables + indexes + views';
    RAISE NOTICE '  - Device Tables: 4 time-series hypertables + continuous aggregates';
    RAISE NOTICE '  - Retention/Compression policies configured for all TS tables';
END $$;