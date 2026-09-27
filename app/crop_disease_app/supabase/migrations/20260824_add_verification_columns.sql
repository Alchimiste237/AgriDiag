-- Add verification and retraining support columns to scans.
-- verification_status: 'pending' (default), 'verified', 'rejected'
-- admin_notes: free-text notes from the admin when verifying

ALTER TABLE scans
  ADD COLUMN IF NOT EXISTS verification_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS admin_notes text,
  ADD COLUMN IF NOT EXISTS verified_at timestamptz;

-- Index for efficiently querying verified scans (used for retraining)
CREATE INDEX IF NOT EXISTS idx_scans_verification ON scans (verification_status);

-- RLS: only service_role can update verification fields
-- (anon key can still INSERT new scans, but only admin/service-role can verify)
-- These policies are additive — existing INSERT policy still works.

-- View: count of scans per verification status (useful for admin dashboard)
CREATE OR REPLACE VIEW scan_verification_stats AS
SELECT
  verification_status,
  COUNT(*) AS count
FROM scans
GROUP BY verification_status;
