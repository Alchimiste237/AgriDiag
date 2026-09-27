// dataService.js — single source of truth for loading dashboard data.
// Everything here reads live from Supabase; there is intentionally NO
// fallback to static/mock data. Pages render empty or error states instead.
import { supabase } from '../supabaseClient';

export function formatCrop(value) {
  return value ? value.charAt(0).toUpperCase() + value.slice(1) : 'Unknown';
}

export function formatDisease(value) {
  if (!value) return 'Unknown';
  return value
    .replace(/_/g, ' ')
    .split(' ')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

/**
 * Map a raw `scans` row into the shape the UI consumes.
 * The mobile app sends farmer snapshots with every scan; the optional
 * `farmerMap` (from the `farmers` table) is only used as a fallback when a
 * snapshot field is missing.
 */
export function mapScan(s, farmerMap = {}) {
  const farmer = farmerMap[s.farmer_id] || {};
  return {
    id: s.id,
    farmer_id: s.farmer_id,
    farmer_code: s.device_farmer_id || farmer.code || 'Unknown',
    farmer_name: s.farmer_name || farmer.name || 'Unknown',
    village: s.farmer_village || farmer.village || 'Unknown',
    farmer_phone: s.farmer_phone || farmer.phone || '',
    crop_species: formatCrop(s.crop_species),
    disease_label: formatDisease(s.disease_label),
    confidence: parseFloat(s.confidence),
    latitude: s.latitude ? parseFloat(s.latitude) : null,
    longitude: s.longitude ? parseFloat(s.longitude) : null,
    state: s.state || 'Unknown',
    lga: s.lga || 'Unknown',
    image_url: s.image_url,
    device_timestamp: s.device_timestamp,
    verified: !!s.verified,
    verified_at: s.verified_at,
    ground_truth_label: s.ground_truth_label,
    status: s.verified ? 'Verified' : 'Synced',
  };
}

/** Fetch all scans from Supabase, newest first. Throws on error. */
export async function fetchScans() {
  const { data, error } = await supabase
    .from('scans')
    .select('*')
    .order('device_timestamp', { ascending: false });
  if (error) throw error;
  return data || [];
}

/** Fetch all farmers from Supabase. Throws on error. */
export async function fetchFarmers() {
  const { data, error } = await supabase.from('farmers').select('*');
  if (error) throw error;
  return data || [];
}

// ── Retraining helpers ─────────────────────────────────────────────────

/**
 * Compute retraining-ready statistics from the in-memory scan list.
 * Returns an object with counts and breakdowns the Retraining page consumes.
 */
export function computeRetrainingStats(scans) {
  const verified = scans.filter((s) => s.verified);
  const pending = scans.filter((s) => !s.verified);

  // Breakdown of verified scans by crop → disease
  const byCropDisease = {};
  verified.forEach((s) => {
    const crop = s.crop_species || 'Unknown';
    const disease = s.disease_label || 'Unknown';
    if (!byCropDisease[crop]) byCropDisease[crop] = {};
    byCropDisease[crop][disease] = (byCropDisease[crop][disease] || 0) + 1;
  });

  // Breakdown by crop only
  const byCrop = {};
  verified.forEach((s) => {
    const crop = s.crop_species || 'Unknown';
    byCrop[crop] = (byCrop[crop] || 0) + 1;
  });

  // Scans with images (required for retraining)
  const withImages = verified.filter((s) => s.image_url);
  const withoutImages = verified.filter((s) => !s.image_url);

  // Unique diseases in verified set
  const diseases = [...new Set(verified.map((s) => s.disease_label).filter(Boolean))];

  return {
    totalScans: scans.length,
    verifiedCount: verified.length,
    pendingCount: pending.length,
    withImagesCount: withImages.length,
    withoutImagesCount: withoutImages.length,
    byCropDisease,
    byCrop,
    diseases,
    verified,
  };
}

/**
 * Export verified scans as a CSV string suitable for ML retraining.
 * Columns: image_url, label (ground_truth or disease_label), crop_species,
 * confidence, device_timestamp, latitude, longitude, farmer_id.
 */
export function exportVerifiedScansCSV(scans) {
  const verified = scans.filter((s) => s.verified && s.image_url);
  const headers = [
    'image_url',
    'label',
    'crop_species',
    'confidence',
    'device_timestamp',
    'latitude',
    'longitude',
    'farmer_id',
    'ground_truth_label',
    'verified_at',
  ];
  const rows = verified.map((s) => [
    s.image_url || '',
    s.ground_truth_label || s.disease_label || '',
    s.crop_species || '',
    s.confidence,
    s.device_timestamp || '',
    s.latitude ?? '',
    s.longitude ?? '',
    s.farmer_code || '',
    s.ground_truth_label || '',
    s.verified_at || '',
  ]);

  const csvContent = [
    headers.join(','),
    ...rows.map((r) =>
      r.map((val) => `"${String(val).replace(/"/g, '""')}"`).join(',')
    ),
  ].join('\n');
  return csvContent;
}

/**
 * Trigger a retraining job via Supabase Edge Function.
 * Returns { success, message, jobId }.
 * If the edge function is not deployed, returns a fallback message.
 */
export async function triggerRetraining() {
  try {
    const { data, error } = await supabase.functions.invoke('trigger-retraining', {
      body: {},
    });
    if (error) throw error;
    return { success: true, message: data?.message || 'Retraining started', jobId: data?.job_id };
  } catch (err) {
    // Edge function may not be deployed yet — return a helpful fallback
    return {
      success: false,
      message:
        'Retraining endpoint not available. Deploy the trigger-retraining Edge Function to Supabase, or export the verified dataset CSV and run retraining manually.',
      error: err.message,
    };
  }
}
