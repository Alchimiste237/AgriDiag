import { useEffect, useState } from 'react';
import { NavLink } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import { getActiveAlerts } from '../utils/alertEngine';

export default function Sidebar() {
  const [badgeCount, setBadgeCount] = useState(0);

  useEffect(() => {
    let cancelled = false;
    async function loadAlertsCount() {
      try {
        const { data: dbScans, error } = await supabase
          .from('scans')
          .select('lga, disease_label, crop_species, device_timestamp, verified');
        if (cancelled) return;
        if (error || !dbScans || dbScans.length === 0) {
          setBadgeCount(0); // no live data → no badge
          return;
        }
        setBadgeCount(getActiveAlerts(dbScans).length);
      } catch (err) {
        console.warn('Error loading alerts count in sidebar:', err);
        if (!cancelled) setBadgeCount(0);
      }
    }
    loadAlertsCount();
    return () => {
      cancelled = true;
    };
  }, []);

  const navItems = [
    { to: '/', label: 'Overview', icon: '◈' },
    { to: '/analytics', label: 'Analytics', icon: '📊' },
    { to: '/scans', label: 'Farmer Scans', icon: '📋' },
    { to: '/alerts', label: 'Alerts', icon: '🔔', badgeCount: badgeCount },
    { to: '/retraining', label: 'Retraining', icon: '🧠' },
  ];

  return (
    <aside
      style={{
        width: 240,
        background: 'var(--surface)',
        borderRight: '1px solid var(--border)',
        padding: '28px 20px',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div style={{ marginBottom: 40 }}>
        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 21, color: 'var(--primary-deep)' }}>
          AgroDiag Monitor
        </div>
        <div style={{ fontSize: 12, color: 'var(--ink-muted)', marginTop: 2 }}>NGO & Gov Monitoring</div>
      </div>

      <nav style={{ display: 'flex', flexDirection: 'column', gap: 4, flex: 1 }}>
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            style={({ isActive }) => ({
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '10px 14px',
              borderRadius: 8,
              fontSize: 14,
              fontWeight: 600,
              textDecoration: 'none',
              color: isActive ? 'var(--primary-deep)' : 'var(--ink-muted)',
              background: isActive ? 'var(--surface-sunken)' : 'transparent',
              transition: 'background 0.15s ease, color 0.15s',
            })}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span aria-hidden="true" style={{ fontSize: 16 }}>{item.icon}</span>
              {item.label}
            </div>
            {!!item.badgeCount && (
              <span
                style={{
                  backgroundColor: 'var(--danger)',
                  color: 'white',
                  fontSize: 11,
                  fontWeight: 700,
                  padding: '2px 7px',
                  borderRadius: 999,
                }}
              >
                {item.badgeCount}
              </span>
            )}
          </NavLink>
        ))}
      </nav>

      <button
        className="btn btn-outline"
        style={{ fontSize: 13, marginTop: 'auto' }}
        onClick={() => supabase.auth.signOut()}
      >
        Sign out
      </button>
    </aside>
  );
}
