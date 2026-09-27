export default function StatCard({ label, value, sublabel, accent }) {
  return (
    <div className="card" style={{ padding: '20px 22px' }}>
      <div style={{ fontSize: 13, color: 'var(--ink-muted)', fontWeight: 600 }}>{label}</div>
      <div
        className="mono"
        style={{ fontSize: 32, fontWeight: 500, marginTop: 6, color: accent || 'var(--ink)' }}
      >
        {value}
      </div>
      {sublabel && (
        <div style={{ fontSize: 12.5, color: 'var(--ink-muted)', marginTop: 4 }}>{sublabel}</div>
      )}
    </div>
  );
}
