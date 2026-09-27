import { useEffect, useState } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { supabase } from './supabaseClient';
import Sidebar from './components/Sidebar';
import Login from './pages/Login';
import Overview from './pages/Overview';
import Analytics from './pages/Analytics';
import ScanLog from './pages/ScanLog';
import Alerts from './pages/Alerts';
import Retraining from './pages/Retraining';
import './styles/global.css';

export default function App() {
  const [session, setSession] = useState(undefined); // undefined = still checking

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
    });
    return () => listener.subscription.unsubscribe();
  }, []);

  if (session === undefined) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <p style={{ color: 'var(--ink-muted)' }}>Loading…</p>
      </div>
    );
  }

  if (!session) return <Login />;

  // BASE_URL is Vite's `base` ('/' locally, '/<repo>/' on GitHub Pages).
  const basename = import.meta.env.BASE_URL.replace(/\/$/, '');

  return (
    <BrowserRouter basename={basename}>
      <div className="app-shell">
        <Sidebar />
        <main className="main" style={{ flex: 1, minWidth: 0 }}>
          <Routes>
            <Route path="/" element={<Overview />} />
            <Route path="/analytics" element={<Analytics />} />
            <Route path="/scans" element={<ScanLog />} />
            <Route path="/alerts" element={<Alerts />} />
            <Route path="/retraining" element={<Retraining />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  );
}
