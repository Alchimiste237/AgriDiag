/**
 * LeafGauge — the dashboard's signature element.
 * A leaf silhouette that fills bottom-to-top with confidence level,
 * colored by threshold. Used everywhere a confidence/accuracy value is
 * shown, in place of generic circular progress rings or plain badges —
 * it's a small, deliberate nod to what the product actually monitors.
 */
export default function LeafGauge({ value, size = 28, showLabel = true }) {
  const pct = Math.max(0, Math.min(1, value));
  const color = pct >= 0.85 ? 'var(--primary)' : pct >= 0.6 ? 'var(--accent)' : 'var(--danger)';
  const fillHeight = 34 * pct; // leaf's usable vertical fill span within the 40-tall viewBox
  const fillY = 36 - fillHeight;
  const clipId = `leaf-clip-${Math.round(pct * 1000)}-${size}`;

  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
      <svg width={size} height={size} viewBox="0 0 32 40" fill="none" aria-hidden="true">
        <defs>
          <clipPath id={clipId}>
            <path d="M16 2C6 8 3 18 8 28C11 34 16 38 16 38C16 38 21 34 24 28C29 18 26 8 16 2Z" />
          </clipPath>
        </defs>
        {/* leaf outline, unfilled */}
        <path
          d="M16 2C6 8 3 18 8 28C11 34 16 38 16 38C16 38 21 34 24 28C29 18 26 8 16 2Z"
          fill="var(--surface-sunken)"
          stroke="var(--border)"
          strokeWidth="1"
        />
        {/* fill, clipped to leaf shape */}
        <g clipPath={`url(#${clipId})`}>
          <rect x="0" y={fillY} width="32" height="40" fill={color} />
        </g>
        {/* midrib vein for a touch of leaf character */}
        <path d="M16 6V34" stroke="rgba(255,255,255,0.5)" strokeWidth="1" clipPath={`url(#${clipId})`} />
      </svg>
      {showLabel && (
        <span className="mono" style={{ fontSize: 13, color, fontWeight: 500 }}>
          {Math.round(pct * 100)}%
        </span>
      )}
    </span>
  );
}
