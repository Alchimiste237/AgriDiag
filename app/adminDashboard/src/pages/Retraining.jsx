import { useMemo, useState } from 'react';
import StatCard from '../components/StatCard';
import StatePanel from '../components/StatePanel';
import { useDashboardData } from '../hooks/useDashboardData';
import {
  computeRetrainingStats,
  exportVerifiedScansCSV,
  triggerRetraining,
} from '../utils/dataService';

export default function Retraining() {
  const { scans, loading, error, reload } = useDashboardData();
  const [exporting, setExporting] = useState(false);
  const [retraining, setRetraining] = useState(false);
  const [retrainResult, setRetrainResult] = useState(null);
  const [selectedCrop, setSelectedCrop] = useState('all');

  const stats = useMemo(() => computeRetrainingStats(scans), [scans]);

  // Filter breakdown by selected crop
  const filteredBreakdown = useMemo(() => {
    if (selectedCrop === 'all') return stats.byCropDisease;
    return { [selectedCrop]: stats.byCropDisease[selectedCrop] || {} };
  }, [stats, selectedCrop]);

  const cropOptions = useMemo(
    () => ['all', ...Object.keys(stats.byCrop).sort()],
    [stats],
  );

  // ── Export CSV ──────────────────────────────────────────────────────
  function handleExportCSV() {
    if (stats.verified.length === 0) {
      alert('No verified scans with images to export.');
      return;
    }
    setExporting(true);
    try {
      const csv = exportVerifiedScansCSV(scans);
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `agridiag_retraining_dataset_${new Date().toISOString().slice(0, 10)}.csv`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    } finally {
      setExporting(false);
    }
  }

  // ── Trigger Retraining ──────────────────────────────────────────────
  async function handleTriggerRetraining() {
    if (stats.verified.length === 0) {
      alert('No verified scans available for retraining. Verify scans first in the Farmer Scans tab.');
      return;
    }
    setRetraining(true);
    setRetrainResult(null);
    try {
      const result = await triggerRetraining();
      setRetrainResult(result);
    } finally {
      setRetraining(false);
    }
  }

  if (loading) {
    return (
      <div style={{ height: '80vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <p style={{ color: 'var(--ink-muted)' }}>Loading retraining data…</p>
      </div>
    );
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1>Model Retraining</h1>
          <p>Manage verified scan datasets and trigger AI model retraining with admin-validated ground-truth labels.</p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button
            className="btn btn-outline"
            onClick={handleExportCSV}
            disabled={exporting || stats.verifiedCount === 0}
          >
            📥 Export Verified CSV
          </button>
          <button
            className="btn btn-primary"
            onClick={handleTriggerRetraining}
            disabled={retraining || stats.verifiedCount === 0}
          >
            {retraining ? '⏳ Starting…' : '🧠 Trigger Retraining'}
          </button>
        </div>
      </div>

      {error && (
        <StatePanel
          variant="error"
          icon="⚠️"
          title="Could not load live data"
          message="Retraining stats could not be loaded from Supabase. Check your connection and environment variables."
          actionLabel="Retry"
          onAction={reload}
        />
      )}

      {!error && scans.length === 0 && (
        <StatePanel
          icon="🧠"
          title="No scans synced yet"
          message="Retraining data is built from verified farmer scans. Once scans are synced and verified, they will appear here as a retraining-ready dataset."
          actionLabel="Refresh"
          onAction={reload}
        />
      )}

      {!error && scans.length > 0 && (
        <>
          {/* ── Metric Cards ──────────────────────────────────────── */}
          <div className="stat-grid">
            <StatCard
              label="Total Scans"
              value={stats.totalScans.toLocaleString()}
              sublabel="All synced from the mobile app"
            />
            <StatCard
              label="Verified (Ready)"
              value={stats.verifiedCount.toLocaleString()}
              sublabel="Admin-validated ground truth"
              accent="var(--primary)"
            />
            <StatCard
              label="Pending Verification"
              value={stats.pendingCount.toLocaleString()}
              sublabel="Awaiting admin review"
              accent={stats.pendingCount > 0 ? 'var(--accent)' : undefined}
            />
            <StatCard
              label="With Images"
              value={stats.withImagesCount.toLocaleString()}
              sublabel={`${stats.withoutImagesCount} missing photos`}
            />
          </div>

          {/* ── Retraining Readiness Bar ──────────────────────────── */}
          <div className="card" style={{ padding: 24, marginBottom: 24 }}>
            <h2 style={{ marginBottom: 12 }}>Dataset Readiness</h2>
            <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 12 }}>
              <div style={{ flex: 1 }}>
                <div
                  style={{
                    width: '100%',
                    height: 12,
                    backgroundColor: 'var(--surface-sunken)',
                    borderRadius: 999,
                    overflow: 'hidden',
                  }}
                >
                  <div
                    style={{
                      width: `${stats.totalScans > 0 ? (stats.verifiedCount / stats.totalScans) * 100 : 0}%`,
                      height: '100%',
                      backgroundColor: 'var(--primary)',
                      borderRadius: 999,
                      transition: 'width 0.4s ease',
                    }}
                  />
                </div>
              </div>
              <span
                className="mono"
                style={{ fontSize: 18, fontWeight: 700, color: 'var(--primary-deep)', minWidth: 50, textAlign: 'right' }}
              >
                {stats.totalScans > 0
                  ? Math.round((stats.verifiedCount / stats.totalScans) * 100)
                  : 0}
                %
              </span>
            </div>
            <div style={{ fontSize: 13, color: 'var(--ink-muted)' }}>
              {stats.verifiedCount} of {stats.totalScans} scans verified by admin.
              {stats.withoutImagesCount > 0 && (
                <span style={{ color: 'var(--accent)' }}>
                  {' '}⚠ {stats.withoutImagesCount} verified scan{stats.withoutImagesCount !== 1 ? 's' : ''} missing images — they will be excluded from retraining.
                </span>
              )}
            </div>
          </div>

          {/* ── Breakdown by Crop & Disease ───────────────────────── */}
          <div className="card" style={{ padding: 24, marginBottom: 24 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h2>Verified Scan Breakdown</h2>
              <select
                value={selectedCrop}
                onChange={(e) => setSelectedCrop(e.target.value)}
                style={{ minWidth: 160 }}
              >
                {cropOptions.map((c) => (
                  <option key={c} value={c}>
                    {c === 'all' ? 'All Crops' : c}
                  </option>
                ))}
              </select>
            </div>

            {Object.keys(filteredBreakdown).length === 0 ? (
              <p style={{ color: 'var(--ink-muted)', fontSize: 14 }}>
                No verified scans yet. Go to <strong>Farmer Scans</strong> to verify scans first.
              </p>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                {Object.entries(filteredBreakdown)
                  .sort((a, b) => {
                    const totalA = Object.values(a[1]).reduce((s, v) => s + v, 0);
                    const totalB = Object.values(b[1]).reduce((s, v) => s + v, 0);
                    return totalB - totalA;
                  })
                  .map(([crop, diseases]) => {
                    const cropTotal = Object.values(diseases).reduce((s, v) => s + v, 0);
                    return (
                      <div key={crop}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                          <h3 style={{ margin: 0, fontSize: 15 }}>{crop}</h3>
                          <span className="mono" style={{ fontSize: 13, color: 'var(--ink-muted)' }}>
                            {cropTotal} verified
                          </span>
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                          {Object.entries(diseases)
                            .sort((a, b) => b[1] - a[1])
                            .map(([disease, count]) => (
                              <div key={disease} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                                <span style={{ fontSize: 13, minWidth: 180, color: 'var(--ink)' }}>
                                  {disease}
                                </span>
                                <div style={{ flex: 1 }}>
                                  <div
                                    style={{
                                      width: '100%',
                                      height: 8,
                                      backgroundColor: 'var(--surface-sunken)',
                                      borderRadius: 999,
                                      overflow: 'hidden',
                                    }}
                                  >
                                    <div
                                      style={{
                                        width: `${(count / cropTotal) * 100}%`,
                                        height: '100%',
                                        backgroundColor:
                                          disease.toLowerCase() === 'healthy'
                                            ? 'var(--primary)'
                                            : 'var(--danger)',
                                        borderRadius: 999,
                                      }}
                                    />
                                  </div>
                                </div>
                                <span
                                  className="mono"
                                  style={{ fontSize: 12, fontWeight: 600, minWidth: 36, textAlign: 'right' }}
                                >
                                  {count}
                                </span>
                              </div>
                            ))}
                        </div>
                      </div>
                    );
                  })}
              </div>
            )}
          </div>

          {/* ── Retrain Result ────────────────────────────────────── */}
          {retrainResult && (
            <div
              className="card"
              style={{
                padding: 20,
                marginBottom: 24,
                borderLeft: `4px solid ${retrainResult.success ? 'var(--primary)' : 'var(--accent)'}`,
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
                <span style={{ fontSize: 20 }}>{retrainResult.success ? '✅' : 'ℹ️'}</span>
                <h3 style={{ margin: 0, fontSize: 15 }}>
                  {retrainResult.success ? 'Retraining Started' : 'Retraining Info'}
                </h3>
              </div>
              <p style={{ margin: 0, fontSize: 13, color: 'var(--ink-muted)', lineHeight: 1.5 }}>
                {retrainResult.message}
              </p>
              {retrainResult.jobId && (
                <p className="mono" style={{ margin: '8px 0 0', fontSize: 12, color: 'var(--ink-muted)' }}>
                  Job ID: {retrainResult.jobId}
                </p>
              )}
            </div>
          )}

          {/* ── How It Works ──────────────────────────────────────── */}
          <div className="card" style={{ padding: 24 }}>
            <h2 style={{ marginBottom: 16 }}>How Retraining Works</h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 20 }}>
              <StepCard
                step="1"
                icon="📋"
                title="Verify Scans"
                description="Admins review farmer scans in the Farmer Scans tab and mark each as Correct or Incorrect, providing the ground-truth label."
              />
              <StepCard
                step="2"
                icon="📥"
                title="Export Dataset"
                description="Download the verified scans as a CSV with image URLs and ground-truth labels, ready for training pipelines."
              />
              <StepCard
                step="3"
                icon="🧠"
                title="Trigger Retraining"
                description="Invoke the retraining pipeline via Supabase Edge Function. The model is retrained on the verified dataset and deployed."
              />
              <StepCard
                step="4"
                icon="🚀"
                title="Deploy Update"
                description="The updated TFLite model is packaged into a new app release. Farmers get improved diagnoses via the mobile app."
              />
            </div>
          </div>
        </>
      )}
    </>
  );
}

function StepCard({ step, icon, title, description }) {
  return (
    <div
      style={{
        padding: 16,
        border: '1px solid var(--border)',
        borderRadius: 'var(--radius-md)',
        position: 'relative',
      }}
    >
      <div
        style={{
          position: 'absolute',
          top: -10,
          left: 16,
          backgroundColor: 'var(--primary)',
          color: 'white',
          fontSize: 11,
          fontWeight: 700,
          padding: '2px 8px',
          borderRadius: 4,
        }}
      >
        Step {step}
      </div>
      <div style={{ fontSize: 28, marginBottom: 8, marginTop: 4 }}>{icon}</div>
      <h3 style={{ margin: '0 0 6px', fontSize: 14, fontFamily: 'var(--font-body)', fontWeight: 700 }}>
        {title}
      </h3>
      <p style={{ margin: 0, fontSize: 12.5, color: 'var(--ink-muted)', lineHeight: 1.5 }}>
        {description}
      </p>
    </div>
  );
}
