import { useEffect, useMemo, useState } from 'react';
import L from 'leaflet';
import StatCard from '../components/StatCard';
import StatePanel from '../components/StatePanel';
import { useDashboardData } from '../hooks/useDashboardData';
import { getActiveAlerts } from '../utils/alertEngine';
import { createBasemapLayer } from '../utils/basemap';

// A "hotspot" is any disease + division pair with at least this many cases.
const HOTSPOT_MIN_CASES = 10;
const MAX_HOTSPOTS = 5;

// Palette assigned to hotspots in rank order (matches the legend chips).
const HOTSPOT_COLORS = ['#A83C32', '#C98A2C', '#5C6BC0', '#8D6E63', '#26C6DA'];
const COLOR_HEALTHY = '#2B6E49';
const COLOR_OTHER_DISEASE = '#9AA7B1';

export default function Overview() {
  const { scans: allScans, farmers, loading, error, reload } = useDashboardData();

  // Exclude scans marked incorrect by admin — they should not appear in analytics.
  const scans = useMemo(
    () => allScans.filter((s) => s.ground_truth_label !== 'Incorrect'),
    [allScans],
  );

  // ------------------------------------------------------------------
  // Data-driven hotspots: rank disease+division pairs by case count.
  // ------------------------------------------------------------------
  const hotspots = useMemo(() => {
    const counts = {};
    scans.forEach((s) => {
      const disease = s.disease_label;
      if (!disease || disease.toLowerCase() === 'healthy') return;
      if (!s.lga || s.lga === 'Unknown') return;
      const key = `${s.lga}|||${disease}`;
      counts[key] = (counts[key] || 0) + 1;
    });
    return Object.entries(counts)
      .map(([key, count]) => {
        const [lga, , disease] = key.split('|||');
        return { lga, disease, count };
      })
      .filter((h) => h.count >= HOTSPOT_MIN_CASES)
      .sort((a, b) => b.count - a.count)
      .slice(0, MAX_HOTSPOTS);
  }, [scans]);

  const hotspotColor = useMemo(() => {
    const map = {};
    hotspots.forEach((h, i) => {
      map[`${h.lga}|||${h.disease}`] = HOTSPOT_COLORS[i % HOTSPOT_COLORS.length];
    });
    return map;
  }, [hotspots]);

  // Only show legend entries that actually exist in the data.
  const legend = useMemo(() => {
    const items = hotspots.map((h) => ({
      color: hotspotColor[`${h.lga}|||${h.disease}`],
      label: `${h.disease} — ${h.lga} (${h.count} cases)`,
    }));
    const hasOtherDisease = scans.some(
      (s) => s.disease_label && s.disease_label.toLowerCase() !== 'healthy'
        && !hotspotColor[`${s.lga}|||${s.disease_label}`],
    );
    const hasHealthy = scans.some((s) => s.disease_label?.toLowerCase() === 'healthy');
    if (hasOtherDisease) {
      items.push({ color: COLOR_OTHER_DISEASE, label: 'Other disease detections' });
    }
    if (hasHealthy) {
      items.push({ color: COLOR_HEALTHY, label: 'Healthy detections' });
    }
    return items;
  }, [hotspots, hotspotColor, scans]);

  // ------------------------------------------------------------------
  // Stats
  // ------------------------------------------------------------------
  const stats = useMemo(() => {
    const activeAlerts = getActiveAlerts(scans);
    const deviceFarmerCount = new Set(
      scans.map((s) => s.farmer_code).filter((c) => c && c !== 'Unknown'),
    ).size;
    const farmerCount = farmers.length || deviceFarmerCount;
    return {
      totalFarmers: farmerCount,
      totalScans: scans.length,
      alertsCount: activeAlerts.length,
    };
  }, [scans, farmers]);

  // Top 5 diseases this month
  const top5Diseases = useMemo(() => {
    if (scans.length === 0) return [];
    const diseaseScans = scans.filter((s) => s.disease_label && s.disease_label.toLowerCase() !== 'healthy');
    const totalDiseased = diseaseScans.length;

    const counts = {};
    diseaseScans.forEach((s) => {
      const key = `${s.crop_species} - ${s.disease_label}`;
      counts[key] = (counts[key] || 0) + 1;
    });

    return Object.entries(counts)
      .map(([name, count]) => ({
        name,
        count,
        percentage: totalDiseased > 0 ? Math.round((count / totalDiseased) * 100) : 0,
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);
  }, [scans]);

  // ------------------------------------------------------------------
  // Leaflet map
  // ------------------------------------------------------------------
  useEffect(() => {
    if (loading || error || scans.length === 0) return;
    const container = L.DomUtil.get('outbreak-map');
    if (!container) return;

    const map = L.map('outbreak-map', { scrollWheelZoom: false }).setView([5.5, 12.0], 7);

    createBasemapLayer().addTo(map);

    scans.forEach((scan) => {
      if (!scan.latitude || !scan.longitude) return;

      const disease = scan.disease_label;
      const isHealthy = disease && disease.toLowerCase() === 'healthy';
      const hotspotKey = `${scan.lga}|||${disease}`;
      const hotspot = hotspotColor[hotspotKey];
      const hotspotCount = hotspots.find((h) => `${h.lga}|||${h.disease}` === hotspotKey)?.count || 0;

      let markerColor = COLOR_HEALTHY;
      let markerRadius = 6;
      if (!isHealthy) {
        if (hotspot) {
          markerColor = hotspot;
          markerRadius = 10 + Math.min(hotspotCount, 50) * 0.25; // bigger = more cases
        } else {
          markerColor = COLOR_OTHER_DISEASE;
          markerRadius = 8;
        }
      }

      const circle = L.circleMarker([scan.latitude, scan.longitude], {
        radius: markerRadius,
        fillColor: markerColor,
        color: markerColor,
        weight: 1.5,
        opacity: 0.85,
        fillOpacity: 0.35,
      }).addTo(map);

      circle.bindPopup(`
        <div style="font-family: var(--font-body); font-size: 13px; line-height: 1.4;">
          <h3 style="margin: 0 0 4px 0; color: var(--primary-deep); font-size: 14px; font-family: var(--font-display);">
            ${scan.crop_species} - ${scan.disease_label}
          </h3>
          <div style="color: var(--ink-muted); font-size: 12px; margin-bottom: 6px;">
            ${scan.village} Village, ${scan.lga} LGA
          </div>
          <strong>Farmer:</strong> ${scan.farmer_name || 'Unknown'}<br/>
          <strong>Confidence:</strong> ${Math.round(scan.confidence * 100)}%<br/>
          <strong>Synced:</strong> ${new Date(scan.device_timestamp).toLocaleDateString()}<br/>
          <span class="badge ${scan.verified ? 'badge-verified' : 'badge-unverified'}" style="margin-top: 6px;">
            ${scan.verified ? 'Verified' : 'Needs Verification'}
          </span>
        </div>
      `);
    });

    return () => {
      map.remove();
    };
  }, [scans, hotspots, hotspotColor, loading, error]);

  // ------------------------------------------------------------------
  // Loading / error / empty states
  // ------------------------------------------------------------------
  if (loading) {
    return (
      <div style={{ height: '80vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <p style={{ color: 'var(--ink-muted)' }}>Loading live dashboard data…</p>
      </div>
    );
  }

  if (error) {
    return (
      <>
        <div className="page-header">
          <div>
            <h1>AgroDiag Monitor</h1>
            <p>NGO & Government Outbreak Monitoring and Strategic Data Insights Portal.</p>
          </div>
        </div>
        <StatePanel
          variant="error"
          icon="⚠️"
          title="Could not load live data"
          message="The dashboard could not reach Supabase. Check your connection and that VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY are set correctly."
          actionLabel="Retry"
          onAction={reload}
        />
      </>
    );
  }

  if (scans.length === 0) {
    return (
      <>
        <div className="page-header">
          <div>
            <h1>AgroDiag Monitor</h1>
            <p>NGO & Government Outbreak Monitoring and Strategic Data Insights Portal.</p>
          </div>
        </div>
        <StatePanel
          icon="🌱"
          title="No scans have been synced yet"
          message="The dashboard shows only live data from Supabase. Scan records will appear here as soon as farmers use the AgriDiag app and the app syncs them to the scans table."
          actionLabel="Refresh"
          onAction={reload}
        />
      </>
    );
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1>AgroDiag Monitor</h1>
          <p>NGO & Government Outbreak Monitoring and Strategic Data Insights Portal.</p>
        </div>
      </div>

      {/* Main Metric Cards */}
      <div className="stat-grid">
        <StatCard label="Total Farmers" value={stats.totalFarmers.toLocaleString()} />
        <StatCard label="Total Scans" value={stats.totalScans.toLocaleString()} />
        <StatCard label="Active Alerts" value={stats.alertsCount} accent="var(--danger)" />
        <div className="card" style={{ padding: '20px 22px' }}>
          <div style={{ fontSize: 13, color: 'var(--ink-muted)', fontWeight: 600, marginBottom: 4 }}>
            Verified Scans
          </div>
          <div style={{ fontSize: 24, fontWeight: 700, color: 'var(--primary-deep)' }}>
            {scans.filter((s) => s.verified).length.toLocaleString()}
            <span style={{ fontSize: 14, fontWeight: 500, color: 'var(--ink-muted)' }}>
              {' '}of {stats.totalScans.toLocaleString()}
            </span>
          </div>
          <div style={{ fontSize: 12, color: 'var(--ink-muted)' }}>
            ground-truth verified by the admin team
          </div>
        </div>
      </div>

      {/* Outbreak Map & Sidebar Details */}
      <div className="chart-grid" style={{ gridTemplateColumns: '2fr 1fr', gap: 24 }}>
        {/* Outbreak Map Container */}
        <div className="card" style={{ padding: 20, display: 'flex', flexDirection: 'column' }}>
          <h2 style={{ marginBottom: 12 }}>Disease Outbreak Distribution Map</h2>
          <div
            id="outbreak-map"
            style={{
              height: 420,
              borderRadius: 'var(--radius-md)',
              border: '1px solid var(--border)',
              backgroundColor: 'var(--surface-sunken)',
              zIndex: 1,
            }}
          />
          <div style={{ display: 'flex', gap: 16, marginTop: 12, flexWrap: 'wrap', fontSize: 12 }}>
            {legend.map((item, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span
                  style={{
                    width: 12,
                    height: 12,
                    borderRadius: '50%',
                    backgroundColor: item.color,
                    display: 'inline-block',
                    opacity: 0.75,
                  }}
                />
                <strong style={{ fontWeight: 600 }}>{item.label}</strong>
              </div>
            ))}
            {legend.length === 0 && (
              <span style={{ color: 'var(--ink-muted)' }}>No disease detections with coordinates to map.</span>
            )}
          </div>
        </div>

        {/* Sidebar Panel: Top Diseases */}
        <div className="card" style={{ padding: 24 }}>
          <h2 style={{ marginBottom: 16 }}>Top 5 Scans This Month</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {top5Diseases.length === 0 ? (
              <p style={{ color: 'var(--ink-muted)', fontSize: 14 }}>No disease detections yet</p>
            ) : (
              top5Diseases.map((d, index) => (
                <div key={d.name} style={{ borderBottom: '1px solid var(--border)', paddingBottom: 12 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6, fontSize: 14 }}>
                    <span style={{ fontWeight: 600, color: 'var(--primary-deep)' }}>
                      {index + 1}. {d.name}
                    </span>
                    <span style={{ fontWeight: 700, color: 'var(--ink)' }}>{d.percentage}%</span>
                  </div>
                  <div style={{ width: '100%', height: 8, backgroundColor: 'var(--surface-sunken)', borderRadius: 999, overflow: 'hidden' }}>
                    <div
                      style={{
                        width: `${d.percentage}%`,
                        height: '100%',
                        backgroundColor: d.name.includes('Sigatoka') ? 'var(--danger)' : d.name.includes('Fall Armyworm') ? 'var(--accent)' : 'var(--primary)',
                        borderRadius: 999,
                      }}
                    />
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </>
  );
}
