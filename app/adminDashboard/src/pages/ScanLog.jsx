import { useEffect, useMemo, useState } from 'react';
import L from 'leaflet';
import { supabase } from '../supabaseClient';
import StatePanel from '../components/StatePanel';
import { useDashboardData } from '../hooks/useDashboardData';
import { createBasemapLayer } from '../utils/basemap';

export default function ScanLog() {
  const { scans, setScans, loading, error, reload } = useDashboardData();
  const [isSaving, setIsSaving] = useState(false);

  // Filters
  const [diseaseFilter, setDiseaseFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');

  // Selected scan for details
  const [selectedScan, setSelectedScan] = useState(null);

  // Leaflet map instance for the details panel
  const [detailMap, setDetailMap] = useState(null);

  // Handle verification (persists to the scans table)
  async function verifyScan(scanId, isCorrect, predictedLabel) {
    const verifiedAt = new Date().toISOString();
    const groundTruth = isCorrect ? predictedLabel : 'Incorrect';

    // Update locally first for immediate UI response
    setScans((prev) =>
      prev.map((s) =>
        s.id === scanId
          ? { ...s, verified: true, ground_truth_label: groundTruth, status: 'Verified' }
          : s,
      ),
    );

    // If selected scan is the one being verified, update details view
    if (selectedScan && selectedScan.id === scanId) {
      setSelectedScan((prev) => ({
        ...prev,
        verified: true,
        ground_truth_label: groundTruth,
        status: 'Verified',
      }));
    }

    setIsSaving(true);
    const { error: saveError } = await supabase
      .from('scans')
      .update({
        verified: true,
        verified_at: verifiedAt,
        ground_truth_label: groundTruth,
        verified_by: 'Admin',
      })
      .eq('id', scanId);
    setIsSaving(false);

    if (saveError) {
      alert(`Could not save verification in database: ${saveError.message}`);
      reload(); // Reload to restore truth in case of error
    }
  }

  // Handle Row Selection
  const handleSelectRow = (scan) => {
    setSelectedScan(scan);
  };

  // Setup/Update map in the details sidebar when selectedScan changes
  useEffect(() => {
    if (!selectedScan || !selectedScan.latitude || !selectedScan.longitude) {
      if (detailMap) {
        detailMap.remove();
        setDetailMap(null);
      }
      return;
    }

    // Small delay to ensure DOM is rendered
    const timer = setTimeout(() => {
      const mapContainer = L.DomUtil.get('scan-detail-map');
      if (!mapContainer) return;

      // If map is already initialized, update its view and marker
      if (detailMap) {
        detailMap.setView([selectedScan.latitude, selectedScan.longitude], 13);
        detailMap.eachLayer((layer) => {
          if (layer instanceof L.Marker) {
            layer.setLatLng([selectedScan.latitude, selectedScan.longitude]);
            layer.bindPopup(`<strong>${selectedScan.farmer_name}</strong><br/>${selectedScan.village} Village`).openPopup();
          }
        });
      } else {
        const map = L.map('scan-detail-map', {
          zoomControl: false,
          scrollWheelZoom: false,
        }).setView([selectedScan.latitude, selectedScan.longitude], 13);

        createBasemapLayer().addTo(map);

        L.marker([selectedScan.latitude, selectedScan.longitude])
          .addTo(map)
          .bindPopup(`<strong>${selectedScan.farmer_name}</strong><br/>${selectedScan.village} Village`)
          .openPopup();

        setDetailMap(map);
      }
    }, 100);

    return () => clearTimeout(timer);
  }, [selectedScan, detailMap]);

  // Clean up map when component unmounts
  useEffect(() => {
    return () => {
      if (detailMap) {
        detailMap.remove();
      }
    };
  }, [detailMap]);

  // Filters Options (derived from live data)
  const diseaseOptions = useMemo(
    () => ['all', ...new Set(scans.map((s) => s.disease_label).filter(Boolean))],
    [scans],
  );

  const filteredScans = useMemo(() => {
    return scans.filter((s) => {
      // Disease filter
      if (diseaseFilter !== 'all' && s.disease_label !== diseaseFilter) return false;

      // Status filter
      if (statusFilter === 'verified' && !s.verified) return false;
      if (statusFilter === 'synced' && s.verified) return false;

      // Search query (Farmer ID, Name, Village, Crop)
      if (searchQuery.trim() !== '') {
        const query = searchQuery.toLowerCase();
        const matchesName = s.farmer_name?.toLowerCase().includes(query);
        const matchesCode = s.farmer_code?.toLowerCase().includes(query);
        const matchesVillage = s.village?.toLowerCase().includes(query);
        const matchesCrop = s.crop_species?.toLowerCase().includes(query);

        if (!matchesName && !matchesCode && !matchesVillage && !matchesCrop) return false;
      }

      return true;
    });
  }, [scans, diseaseFilter, statusFilter, searchQuery]);

  if (loading) {
    return (
      <div style={{ height: '80vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <p style={{ color: 'var(--ink-muted)' }}>Loading scans log…</p>
      </div>
    );
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1>Farmer Scans Log</h1>
          <p>Verify ground-truth diagnostics, trace farmer details, and locate scans on GPS.</p>
        </div>
      </div>

      {error && (
        <StatePanel
          variant="error"
          icon="⚠️"
          title="Could not load live data"
          message="The scans log could not reach Supabase. Check your connection and environment variables."
          actionLabel="Retry"
          onAction={reload}
        />
      )}

      {!error && scans.length === 0 && (
        <StatePanel
          icon="📭"
          title="No scans have been synced yet"
          message="Scans will appear here when the AgriDiag app syncs the first farmer scan to the Supabase scans table."
          actionLabel="Refresh"
          onAction={reload}
        />
      )}

      {!error && scans.length > 0 && (
        /* Grid Shell for Table + Details Panel */
        <div style={{ display: 'grid', gridTemplateColumns: selectedScan ? '1.5fr 1fr' : '1fr', gap: 24, alignItems: 'start' }}>
          {/* Table Side */}
          <div className="card" style={{ padding: '20px 24px' }}>
            {/* Filters Banner */}
            <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap', alignItems: 'center' }}>
              <input
                type="text"
                placeholder="🔍 Search name, code, village, crop..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                style={{ minWidth: 260, flex: 1 }}
              />

              <select value={diseaseFilter} onChange={(e) => setDiseaseFilter(e.target.value)} style={{ minWidth: 150 }}>
                {diseaseOptions.map((d) => (
                  <option key={d} value={d}>
                    {d === 'all' ? 'All Diseases' : d}
                  </option>
                ))}
              </select>

              <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} style={{ minWidth: 140 }}>
                <option value="all">All Statuses</option>
                <option value="verified">Verified Only</option>
                <option value="synced">Synced Only</option>
              </select>

              <div style={{ fontSize: 13, color: 'var(--ink-muted)', fontWeight: 600 }}>
                {filteredScans.length} of {scans.length} found
              </div>
            </div>

            <div style={{ overflowX: 'auto' }}>
              <table>
                <thead>
                  <tr>
                    <th>Farmer ID</th>
                    <th>Name</th>
                    <th>Village</th>
                    <th>Crop</th>
                    <th>Diagnosis</th>
                    <th>Date</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredScans.length === 0 ? (
                    <tr>
                      <td colSpan={7} style={{ textAlign: 'center', color: 'var(--ink-muted)', padding: 32 }}>
                        No farmer scans match the filters.
                      </td>
                    </tr>
                  ) : (
                    filteredScans.map((scan) => (
                      <tr
                        key={scan.id}
                        onClick={() => handleSelectRow(scan)}
                        style={{
                          cursor: 'pointer',
                          background: selectedScan?.id === scan.id ? 'var(--surface-sunken)' : 'transparent',
                          transition: 'background 0.15s ease',
                        }}
                        className="table-row-hover"
                      >
                        <td className="mono" style={{ fontWeight: 600, fontSize: 13 }}>
                          {scan.farmer_code}
                        </td>
                        <td style={{ fontWeight: 500 }}>{scan.farmer_name}</td>
                        <td style={{ color: 'var(--ink-muted)' }}>{scan.village}</td>
                        <td>{scan.crop_species}</td>
                        <td style={{ fontWeight: 600, color: scan.disease_label === 'Healthy' ? 'var(--primary)' : 'var(--ink)' }}>
                          {scan.disease_label}
                        </td>
                        <td className="mono" style={{ fontSize: 13, color: 'var(--ink-muted)' }}>
                          {new Date(scan.device_timestamp).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}
                        </td>
                        <td>
                          <span className={`badge ${scan.verified ? 'badge-verified' : 'badge-unverified'}`}>
                            {scan.verified ? 'Verified' : 'Synced'}
                          </span>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Scan Details Sidebar */}
          {selectedScan && (
            <div className="card" style={{ padding: 24, alignSelf: 'start', position: 'sticky', top: 20 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
                <h2 style={{ fontSize: 18 }}>Scan Details</h2>
                <button
                  onClick={() => setSelectedScan(null)}
                  style={{ background: 'none', border: 'none', fontSize: 18, cursor: 'pointer', color: 'var(--ink-muted)' }}
                >
                  ✕
                </button>
              </div>

              {/* Photo */}
              {selectedScan.image_url ? (
                <div style={{ position: 'relative', marginBottom: 16 }}>
                  <img
                    src={selectedScan.image_url}
                    alt="Leaf scan"
                    style={{
                      width: '100%',
                      height: 180,
                      objectFit: 'cover',
                      borderRadius: 'var(--radius-md)',
                      border: '1px solid var(--border)',
                    }}
                  />
                  <div
                    style={{
                      position: 'absolute',
                      bottom: 8,
                      right: 8,
                      backgroundColor: 'rgba(22, 36, 28, 0.75)',
                      color: 'white',
                      padding: '4px 8px',
                      borderRadius: 4,
                      fontSize: 11,
                      fontWeight: 600,
                    }}
                  >
                    Confidence: {Math.round(selectedScan.confidence * 100)}%
                  </div>
                </div>
              ) : (
                <div style={{ padding: 12, border: '1px dashed var(--border)', borderRadius: 8, textAlign: 'center', color: 'var(--ink-muted)', fontSize: 12, marginBottom: 16 }}>
                  No photo uploaded with this scan
                </div>
              )}

              {/* GPS Mini Map */}
              {selectedScan.latitude && selectedScan.longitude ? (
                <div style={{ marginBottom: 16 }}>
                  <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-muted)', marginBottom: 6 }}>
                    GPS Location ({selectedScan.lga} Division)
                  </div>
                  <div
                    id="scan-detail-map"
                    style={{
                      height: 120,
                      borderRadius: 'var(--radius-sm)',
                      border: '1px solid var(--border)',
                      backgroundColor: 'var(--surface-sunken)',
                      zIndex: 1,
                    }}
                  />
                </div>
              ) : (
                <div style={{ padding: 12, border: '1px dashed var(--border)', borderRadius: 8, textAlign: 'center', color: 'var(--ink-muted)', fontSize: 12, marginBottom: 16 }}>
                  No GPS coordinates available
                </div>
              )}

              {/* Information Grid */}
              <div style={{ fontSize: 13, display: 'grid', gridTemplateColumns: '1fr 1.2fr', gap: '8px 12px', marginBottom: 20 }}>
                <span style={{ color: 'var(--ink-muted)' }}>Farmer Name:</span>
                <strong style={{ color: 'var(--primary-deep)' }}>{selectedScan.farmer_name}</strong>

                <span style={{ color: 'var(--ink-muted)' }}>Farmer ID:</span>
                <span className="mono">{selectedScan.farmer_code}</span>

                <span style={{ color: 'var(--ink-muted)' }}>Village:</span>
                <span>{selectedScan.village}</span>

                <span style={{ color: 'var(--ink-muted)' }}>Crop Species:</span>
                <strong style={{ textTransform: 'capitalize' }}>{selectedScan.crop_species}</strong>

                <span style={{ color: 'var(--ink-muted)' }}>Diagnosis:</span>
                <span style={{ fontWeight: 600 }}>{selectedScan.disease_label}</span>

                <span style={{ color: 'var(--ink-muted)' }}>Date Synced:</span>
                <span>{new Date(selectedScan.device_timestamp).toLocaleString()}</span>

                <span style={{ color: 'var(--ink-muted)' }}>Verification Status:</span>
                <span style={{ display: 'inline-flex', gap: 6, alignItems: 'center' }}>
                  <span className={`badge ${selectedScan.verified ? 'badge-verified' : 'badge-unverified'}`}>
                    {selectedScan.status}
                  </span>
                  {selectedScan.verified && selectedScan.ground_truth_label && (
                    <span style={{ fontSize: 11, color: 'var(--ink-muted)' }}>
                      ({selectedScan.ground_truth_label})
                    </span>
                  )}
                </span>
              </div>

              {/* Verification Actions */}
              {!selectedScan.verified ? (
                <div style={{ display: 'flex', gap: 10 }}>
                  <button
                    className="btn btn-primary"
                    style={{ flex: 1, padding: '10px 12px' }}
                    disabled={isSaving}
                    onClick={() => verifyScan(selectedScan.id, true, selectedScan.disease_label)}
                  >
                    ✓ Correct
                  </button>
                  <button
                    className="btn btn-danger-outline"
                    style={{ flex: 1, padding: '10px 12px' }}
                    disabled={isSaving}
                    onClick={() => verifyScan(selectedScan.id, false, selectedScan.disease_label)}
                  >
                    ✗ Incorrect
                  </button>
                </div>
              ) : (
                <div style={{ padding: 10, backgroundColor: 'var(--surface-sunken)', borderRadius: 8, textAlign: 'center', fontSize: 12, color: 'var(--ink-muted)' }}>
                  Scan verified as <strong>{selectedScan.ground_truth_label}</strong>
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </>
  );
}
