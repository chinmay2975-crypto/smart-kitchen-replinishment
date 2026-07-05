-- Migration: fix device_readings schema drift
-- The live table had an incompatible legacy shape (id/value/feed_id-int/lat/lon/ele)
-- that never matched the app's ORM/queries (reading_id/device_id/reading_value/...).
-- Confirmed empty (0 rows) and unreferenced elsewhere before running this.

DROP TABLE IF EXISTS device_readings CASCADE;

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
