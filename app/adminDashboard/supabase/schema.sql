-- Crop Disease Detector — Supabase schema for the pilot
-- Run this in Supabase: Dashboard → SQL Editor → New query → paste → Run
--
-- Attribution: the mobile app generates its own Farmer ID on first launch
-- (e.g. "AGD-4821") and sends it, plus a name/village/phone snapshot, with
-- every scan. Pre-seeding `farmers` rows is no longer required — the admin
-- dashboard shows the snapshot values directly. The `farmers` table remains
-- for optional linking of scans to a curated farmer registry.

-- ============================================================
-- Tables
-- ============================================================

create table if not exists farmers (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,        -- optional identifier if you still pre-seed farmers (e.g. "F001")
  name text,
  village text,
  phone text,
  lga text,                        -- division/LGA, used by the dashboard to target advisory SMS recipients per division
  created_at timestamptz default now()
);

create table if not exists scans (
  id uuid primary key default gen_random_uuid(),
  farmer_id uuid references farmers(id),   -- optional link to a pre-seeded farmers row
  device_farmer_id text,                   -- app-generated Farmer ID, e.g. "AGD-4821" (sent by the app)
  farmer_name text,                        -- snapshot from the phone at scan time
  farmer_village text,
  farmer_phone text,
  crop_species text not null default 'plantain',
  disease_label text not null,       -- raw model output label, e.g. 'sigatoka'
  confidence numeric not null,       -- 0.0 - 1.0
  image_url text,                    -- Supabase Storage URL, nullable (image upload can be skipped for bandwidth)
  latitude numeric,                  -- GPS latitude
  longitude numeric,                 -- GPS longitude
  state text,                        -- Region/State (e.g., 'Kaduna')
  lga text,                          -- Local Government Area (e.g., 'Chikun')
  device_timestamp timestamptz not null,  -- when the scan happened on the phone
  synced_at timestamptz default now(),

  -- Ground-truth verification, filled in later from the dashboard
  ground_truth_label text,
  verified boolean default false,
  verified_at timestamptz,
  verified_by text
);

-- Migration for databases created before the app-generated Farmer ID flow:
-- (safe to re-run — no-ops if the column already exists)
alter table scans add column if not exists device_farmer_id text;
alter table scans add column if not exists farmer_name text;
alter table scans add column if not exists farmer_village text;
alter table scans add column if not exists farmer_phone text;

-- Migration: farmers gain an optional division/LGA for SMS recipient targeting.
alter table farmers add column if not exists lga text;

create index if not exists idx_scans_crop_disease on scans (crop_species, disease_label);
create index if not exists idx_scans_farmer on scans (farmer_id);
create index if not exists idx_scans_device_farmer on scans (device_farmer_id);
create index if not exists idx_scans_timestamp on scans (device_timestamp);

-- ============================================================
-- Row Level Security
-- ============================================================
-- Pilot-scale policy, intentionally simple:
--   - anon key (used by the farmer app) can INSERT scans/farmers, nothing else.
--   - authenticated users (dashboard admins, logged in via Supabase Auth) get full access.
-- Tighten before a wider rollout — e.g. restrict anon inserts by rate/shape,
-- add per-cooperative scoping if you have multiple admin users later.

alter table farmers enable row level security;
alter table scans enable row level security;

create policy "anon can insert farmers" on farmers
  for insert to anon with check (true);

create policy "admin full access farmers" on farmers
  for all to authenticated using (true) with check (true);

create policy "anon can insert scans" on scans
  for insert to anon with check (true);

create policy "admin full access scans" on scans
  for all to authenticated using (true) with check (true);

-- ============================================================
-- Storage bucket for scan photos (optional — image upload can be
-- disabled in the app to save bandwidth; dashboard works without it)
-- ============================================================
-- Run separately in Storage → New bucket → name it "scan-images", set to public.
-- Then run:

-- create policy "anon can upload scan images" on storage.objects
--   for insert to anon with check (bucket_id = 'scan-images');

-- create policy "anyone can view scan images" on storage.objects
--   for select using (bucket_id = 'scan-images');

-- ============================================================
-- Create your admin login
-- ============================================================
-- Dashboard → Authentication → Users → Add user → set an email + password.
-- Use those credentials to log into the admin dashboard.

-- ============================================================
-- Cleanup demo data (only if you previously ran the removed seed.js)
-- ============================================================
-- The old seed.js wrote 200 synthetic scans + 10 fake farmers (codes
-- F0001..F0010) into this database. Remove them so the dashboard only
-- ever shows real app data:
--
--   delete from scans where farmer_id in (select id from farmers where code like 'F000%');
--   delete from farmers where code like 'F000%';
