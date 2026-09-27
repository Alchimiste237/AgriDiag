-- Add latitude and longitude columns to the scans table.
-- These are nullable because GPS may be unavailable on the device.

ALTER TABLE scans
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;

-- Index for geographic queries (optional, useful for map views)
CREATE INDEX IF NOT EXISTS idx_scans_location ON scans (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
