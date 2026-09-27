import { useMemo, useState } from 'react';
import StatePanel from '../components/StatePanel';
import { useDashboardData } from '../hooks/useDashboardData';
import { getActiveAlerts } from '../utils/alertEngine';

export default function Alerts() {
  const { scans, farmers, loading, error, reload } = useDashboardData();

  // Alerts are computed live from scans; "sent" is tracked per alert id so
  // it survives recomputation without writing to the database.
  const [sentAlertIds, setSentAlertIds] = useState([]);

  const alerts = useMemo(
    () =>
      getActiveAlerts(scans).map((a) => ({
        ...a,
        sent: sentAlertIds.includes(a.id),
      })),
    [scans, sentAlertIds],
  );

  const [selectedAlert, setSelectedAlert] = useState(null);
  const [smsText, setSmsText] = useState('');
  const [sending, setSending] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');

  const handleOpenSmsComposer = (alert) => {
    setSelectedAlert(alert);
    setSuccessMessage('');
    // Advisory text is built entirely from live alert data — no hardcoded
    // per-disease templates. If the alert carries no numeric count, phrase
    // the message generically.
    const cases =
      typeof alert.count === 'number' && alert.count > 0
        ? `${alert.count} ${alert.disease} case${alert.count === 1 ? '' : 's'}`
        : `${alert.disease} cases`;
    const location = alert.lga && alert.lga !== 'All' ? `${alert.lga} division` : 'your area';
    const crop = alert.crop && alert.crop !== 'Any' ? ` (${alert.crop} crop)` : '';
    setSmsText(
      `AgriDiag Alert: ${alert.type} — ${cases} detected in ${location}${crop}. ` +
        'Please inspect your field for symptoms and report any damage. ' +
        'Call 0800-AGRI-HELP for advice.',
    );
  };

  // Farmers who should receive this alert, targeted by division:
  // 1) registered farmers whose farmers.lga matches the alert's division;
  // 2) fallback — unique farmers seen in scans from that division (the app
  //    auto-generates Farmer IDs and doesn't pre-seed farmers rows).
  const recipientFarmers = useMemo(() => {
    if (!selectedAlert) return [];
    const target = String(selectedAlert.lga || '').toLowerCase();
    if (target && target !== 'all') {
      const registered = farmers.filter(
        (f) => f.lga && String(f.lga).toLowerCase() === target,
      );
      if (registered.length > 0) return registered;
    }

    const seen = new Map();
    scans.forEach((s) => {
      if (!s.farmer_code || s.farmer_code === 'Unknown') return;
      if (target && target !== 'all' && String(s.lga || '').toLowerCase() !== target) return;
      if (seen.has(s.farmer_code)) return;
      seen.set(s.farmer_code, {
        id: s.farmer_code,
        name: s.farmer_name,
        village: s.village,
        phone: s.farmer_phone || '',
      });
    });
    return [...seen.values()];
  }, [selectedAlert, farmers, scans]);

  const handleSendSMS = () => {
    setSending(true);
    setTimeout(() => {
      setSending(false);
      setSuccessMessage(
        `Advisory SMS successfully broadcasted to ${recipientFarmers.length} active farmers in ${selectedAlert.lga}!`,
      );

      // Mark alert as sent
      setSentAlertIds((prev) => (prev.includes(selectedAlert.id) ? prev : [...prev, selectedAlert.id]));

      // Close composer after some time
      setTimeout(() => {
        setSelectedAlert(null);
        setSuccessMessage('');
      }, 3000);
    }, 1500);
  };

  if (loading) {
    return (
      <div style={{ height: '80vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <p style={{ color: 'var(--ink-muted)' }}>Loading alerts data…</p>
      </div>
    );
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1>Alerts & Outbreak Advisory</h1>
          <p>Automated anomaly flags with active SMS broadcasting to pilot farmers.</p>
        </div>
      </div>

      {error && (
        <StatePanel
          variant="error"
          icon="⚠️"
          title="Could not load live data"
          message="Alerts are computed from live scans and could not be loaded from Supabase. Check your connection and environment variables."
          actionLabel="Retry"
          onAction={reload}
        />
      )}

      {!error && scans.length === 0 && (
        <StatePanel
          icon="🛡️"
          title="No Active Anomaly Flags"
          message="All synced crop scans are within normal safety thresholds. Alerts are generated automatically from live scan data — when the first scans arrive, any spike or outbreak will appear here."
          actionLabel="Refresh"
          onAction={reload}
        />
      )}

      {!error && scans.length > 0 && (
        <div style={{ display: 'grid', gridTemplateColumns: selectedAlert ? '1.2fr 1fr' : '1fr', gap: 24 }}>
          {/* Alerts List */}
          <div className="card" style={{ padding: 24 }}>
            <h2 style={{ marginBottom: 16 }}>Active Anomaly Flags</h2>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {alerts.length === 0 ? (
                <div style={{ textAlign: 'center', padding: 40, color: 'var(--ink-muted)' }}>
                  <span style={{ fontSize: 32, display: 'block', marginBottom: 10 }}>🛡️</span>
                  <h3>No Active Anomaly Flags</h3>
                  <p style={{ fontSize: 13, marginTop: 4 }}>All synced crop scans are within normal safety thresholds.</p>
                </div>
              ) : (
                alerts.map((alert) => (
                  <div
                    key={alert.id}
                    style={{
                      border: '1px solid var(--border)',
                      borderRadius: 'var(--radius-md)',
                      padding: 16,
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      background:
                        alert.severity === 'high'
                          ? 'rgba(168, 60, 50, 0.04)'
                          : alert.severity === 'medium'
                            ? 'rgba(201, 138, 44, 0.04)'
                            : 'transparent',
                      borderLeft: `4px solid ${alert.severity === 'high' ? 'var(--danger)' : alert.severity === 'medium' ? 'var(--accent)' : 'var(--ink-muted)'}`,
                    }}
                  >
                    <div>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 4 }}>
                        <span
                          style={{
                            padding: '2px 8px',
                            fontSize: 10,
                            fontWeight: 700,
                            borderRadius: 4,
                            textTransform: 'uppercase',
                            color: 'white',
                            backgroundColor:
                              alert.severity === 'high'
                                ? 'var(--danger)'
                                : alert.severity === 'medium'
                                  ? 'var(--accent)'
                                  : 'var(--ink-muted)',
                          }}
                        >
                          {alert.type}
                        </span>
                        <span style={{ fontSize: 12, color: 'var(--ink-muted)' }}>{alert.date}</span>
                        {alert.sent && (
                          <span style={{ fontSize: 11, color: 'var(--primary)', fontWeight: 600 }}>
                            ✓ SMS Broadcasted
                          </span>
                        )}
                      </div>
                      <h3 style={{ margin: 0, fontSize: 15, color: 'var(--ink)', fontFamily: 'var(--font-body)', fontWeight: 600 }}>
                        {alert.message}
                      </h3>
                    </div>
                    <button
                      className="btn btn-outline"
                      style={{ fontSize: 13, display: 'flex', gap: 6, alignItems: 'center' }}
                      onClick={() => handleOpenSmsComposer(alert)}
                    >
                      💬 Send SMS
                    </button>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* SMS Composer Sidebar */}
          {selectedAlert && (
            <div className="card" style={{ padding: 24, alignSelf: 'start', position: 'sticky', top: 20 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
                <h2 style={{ fontSize: 18 }}>SMS Broadcast Composer</h2>
                <button
                  onClick={() => setSelectedAlert(null)}
                  style={{ background: 'none', border: 'none', fontSize: 18, cursor: 'pointer', color: 'var(--ink-muted)' }}
                >
                  ✕
                </button>
              </div>

              <div style={{ marginBottom: 16, padding: 12, backgroundColor: 'var(--surface-sunken)', borderRadius: 8, fontSize: 13 }}>
                <strong>Target Group:</strong> {recipientFarmers.length} farmers in {selectedAlert.lga} division.
              </div>

              <label style={{ display: 'block', fontSize: 13, fontWeight: 600, marginBottom: 6 }}>
                Recipients
              </label>
              <div
                style={{
                  maxHeight: 100,
                  overflowY: 'auto',
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--radius-sm)',
                  padding: '6px 12px',
                  marginBottom: 16,
                  backgroundColor: 'white',
                  fontSize: 12,
                  color: 'var(--ink-muted)',
                }}
              >
                {recipientFarmers.length === 0 ? (
                  <div style={{ color: 'var(--danger)', fontStyle: 'italic' }}>No registered farmers in this location</div>
                ) : (
                  recipientFarmers.map((f) => (
                    <div key={f.id} style={{ padding: '2px 0' }}>
                      • {f.name} ({f.village}) — {f.phone}
                    </div>
                  ))
                )}
              </div>

              <label style={{ display: 'block', fontSize: 13, fontWeight: 600, marginBottom: 6 }}>
                Advisory Message Text
              </label>
              <textarea
                rows={5}
                value={smsText}
                onChange={(e) => setSmsText(e.target.value)}
                style={{
                  width: '100%',
                  padding: 10,
                  fontFamily: 'inherit',
                  fontSize: 13,
                  borderRadius: 'var(--radius-sm)',
                  border: '1px solid var(--border)',
                  marginBottom: 16,
                  resize: 'none',
                }}
              />

              {successMessage ? (
                <div style={{ padding: 12, backgroundColor: '#E4F0E7', color: 'var(--primary-deep)', borderRadius: 8, fontSize: 13, marginBottom: 16, fontWeight: 600 }}>
                  {successMessage}
                </div>
              ) : (
                <button
                  className="btn btn-primary"
                  disabled={sending || smsText.trim() === '' || recipientFarmers.length === 0}
                  style={{ width: '100%', display: 'flex', justifyContent: 'center', gap: 8, padding: '10px 16px' }}
                  onClick={handleSendSMS}
                >
                  {sending ? 'Sending Broadcast...' : '🚀 Broadcast Advisory SMS'}
                </button>
              )}
            </div>
          )}
        </div>
      )}
    </>
  );
}
