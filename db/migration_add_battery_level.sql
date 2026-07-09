-- Adds a simulated battery level (0-100) to devices, shown on the container
-- card alongside the last reading time. There's no real hardware reporting
-- battery yet, so this is seeded on claim and slowly decayed by the
-- background container simulator.
ALTER TABLE devices ADD COLUMN IF NOT EXISTS battery_level NUMERIC(5,2) DEFAULT 100;
