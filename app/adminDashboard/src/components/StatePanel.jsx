/**
 * StatePanel — shared empty / error state used across dashboard pages.
 * Shown whenever there is no live data to render (empty database) or the
 * Supabase query failed. It replaces the old silent static-data fallback:
 * the dashboard never fabricates data, it tells the truth about the DB.
 */
export default function StatePanel({ icon = '📭', title, message, actionLabel, onAction, variant = 'empty' }) {
  const accent = variant === 'error' ? 'var(--danger)' : 'var(--ink-muted)';
  return (
    <div
      className="card"
      style={{
        padding: '48px 32px',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
        gap: 8,
      }}
    >
      <span style={{ fontSize: 40, lineHeight: 1 }}>{icon}</span>
      <h3 style={{ margin: 0, fontSize: 17, color: 'var(--ink)' }}>{title}</h3>
      {message && (
        <p style={{ margin: 0, maxWidth: 480, fontSize: 13.5, color: 'var(--ink-muted)', lineHeight: 1.55 }}>
          {message}
        </p>
      )}
      {actionLabel && onAction && (
        <button className="btn btn-outline" onClick={onAction} style={{ marginTop: 12 }}>
          {actionLabel}
        </button>
      )}
      <span style={{ fontSize: 11, color: accent, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.4 }}>
        {variant === 'error' ? 'Live data unavailable' : 'Live database'}
      </span>
    </div>
  );
}
