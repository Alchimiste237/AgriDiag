import { useMemo, useState } from 'react';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  LineChart,
  Line,
} from 'recharts';
import StatePanel from '../components/StatePanel';
import { useDashboardData } from '../hooks/useDashboardData';

export default function Analytics() {
  const { scans: allScans, loading, error, reload } = useDashboardData();

  // Exclude scans marked incorrect by admin — they should not appear in analytics.
  const scans = useMemo(
    () => allScans.filter((s) => s.ground_truth_label !== 'Incorrect'),
    [allScans],
  );

  const [stateFilter, setStateFilter] = useState('all');
  const [lgaFilter, setLgaFilter] = useState('all');
  const [cropFilter, setCropFilter] = useState('all');
  const [dateRange, setDateRange] = useState('30'); // '7', '14', '30', 'all'

  // Extract filter options dynamically from current loaded scans
  const stateOptions = useMemo(() => ['all', ...new Set(scans.map((s) => s.state).filter(Boolean))], [scans]);
  const lgaOptions = useMemo(() => ['all', ...new Set(scans.map((s) => s.lga).filter(Boolean))], [scans]);
  const cropOptions = useMemo(() => ['all', ...new Set(scans.map((s) => s.crop_species).filter(Boolean))], [scans]);

  // Filter scans
  const filteredScans = useMemo(() => {
    return scans.filter((scan) => {
      if (stateFilter !== 'all' && scan.state !== stateFilter) return false;
      if (lgaFilter !== 'all' && scan.lga !== lgaFilter) return false;
      if (cropFilter !== 'all' && scan.crop_species !== cropFilter) return false;

      if (dateRange !== 'all') {
        const days = parseInt(dateRange);
        const cutoff = new Date();
        cutoff.setDate(cutoff.getDate() - days);
        if (new Date(scan.device_timestamp) < cutoff) return false;
      }
      return true;
    });
  }, [scans, stateFilter, lgaFilter, cropFilter, dateRange]);

  // Chart 1: Diseases by Crop
  const diseasesByCropData = useMemo(() => {
    const dataMap = {};
    filteredScans.forEach((s) => {
      const crop = s.crop_species;
      const disease = s.disease_label || 'Healthy';

      if (!dataMap[crop]) {
        dataMap[crop] = { crop };
      }
      dataMap[crop][disease] = (dataMap[crop][disease] || 0) + 1;
    });
    return Object.values(dataMap);
  }, [filteredScans]);

  // Find all unique diseases in the current filtered set to create Bars dynamically
  const uniqueDiseases = useMemo(() => {
    const diseases = new Set();
    filteredScans.forEach((s) => {
      if (s.disease_label) diseases.add(s.disease_label);
    });
    return Array.from(diseases);
  }, [filteredScans]);

  // Chart 2: Outbreaks over time (Grouped by Day)
  const outbreaksOverTime = useMemo(() => {
    const byDay = {};
    filteredScans.forEach((s) => {
      const dateStr = new Date(s.device_timestamp).toISOString().slice(0, 10);
      byDay[dateStr] = (byDay[dateStr] || 0) + 1;
    });
    return Object.entries(byDay)
      .map(([date, count]) => ({ date, count }))
      .sort((a, b) => new Date(a.date) - new Date(b.date));
  }, [filteredScans]);

  // Export functions (Download CSV)
  const handleExportCSV = () => {
    if (filteredScans.length === 0) {
      alert('No data to export.');
      return;
    }

    const headers = ['Scan ID', 'Farmer ID', 'Farmer Name', 'Village', 'LGA/Division', 'State/Region', 'Crop', 'Disease Diagnosis', 'Confidence', 'Date', 'Status'];
    const rows = filteredScans.map((s) => [
      s.id,
      s.farmer_id || '',
      s.farmer_name || 'Unknown',
      s.village || '',
      s.lga || '',
      s.state || '',
      s.crop_species,
      s.disease_label,
      (s.confidence * 100).toFixed(0) + '%',
      new Date(s.device_timestamp).toLocaleDateString(),
      s.status || 'Synced',
    ]);

    const csvContent = [headers.join(','), ...rows.map((r) => r.map((val) => `"${val.toString().replace(/"/g, '""')}"`).join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `agridiag_cameroon_scan_report_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleExportPDF = () => {
    window.print();
  };

  // Color palette for charts
  const colors = [
    '#2B6E49', // Primary green
    '#C98A2C', // Accent yellow
    '#A83C32', // Danger red
    '#4A8B71', // Light sage
    '#689F38', // Lime green
    '#8D6E63', // Brown
    '#5C6BC0', // Indigo
    '#26C6DA', // Cyan
  ];

  if (loading) {
    return (
      <div style={{ height: '80vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <p style={{ color: 'var(--ink-muted)' }}>Loading analytics data…</p>
      </div>
    );
  }

  return (
    <>
      <div className="page-header">
        <div>
          <h1>Analytics & Insights</h1>
          <p>Analyze crop health trends, outbreak timelines, and filter dataset summaries.</p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn btn-outline" onClick={handleExportCSV}>
            📥 Export CSV
          </button>
          <button className="btn btn-primary" onClick={handleExportPDF}>
            📄 Print / PDF Report
          </button>
        </div>
      </div>

      {error && (
        <StatePanel
          variant="error"
          icon="⚠️"
          title="Could not load live data"
          message="The analytics charts could not reach Supabase. Check your connection and environment variables."
          actionLabel="Retry"
          onAction={reload}
        />
      )}

      {!error && scans.length === 0 && (
        <StatePanel
          icon="📊"
          title="No scans have been synced yet"
          message="Charts, filters and exports are built live from the scans table. They will populate as soon as the AgriDiag app syncs its first scans."
          actionLabel="Refresh"
          onAction={reload}
        />
      )}

      {!error && scans.length > 0 && (
        <>
          {/* Filters Panel */}
          <div className="card" style={{ padding: 20, marginBottom: 24, display: 'flex', flexWrap: 'wrap', gap: 16, alignItems: 'center' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              <label style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-muted)' }}>Region/State</label>
              <select value={stateFilter} onChange={(e) => setStateFilter(e.target.value)} style={{ minWidth: 140 }}>
                {stateOptions.map((s) => (
                  <option key={s} value={s}>{s === 'all' ? 'All Regions' : s}</option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              <label style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-muted)' }}>Division/LGA</label>
              <select value={lgaFilter} onChange={(e) => setLgaFilter(e.target.value)} style={{ minWidth: 140 }}>
                {lgaOptions.map((l) => (
                  <option key={l} value={l}>{l === 'all' ? 'All Divisions' : l}</option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              <label style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-muted)' }}>Crop</label>
              <select value={cropFilter} onChange={(e) => setCropFilter(e.target.value)} style={{ minWidth: 140 }}>
                {cropOptions.map((c) => (
                  <option key={c} value={c}>{c === 'all' ? 'All Crops' : c.charAt(0).toUpperCase() + c.slice(1)}</option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              <label style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink-muted)' }}>Date Range</label>
              <select value={dateRange} onChange={(e) => setDateRange(e.target.value)} style={{ minWidth: 140 }}>
                <option value="7">Last 7 Days</option>
                <option value="14">Last 14 Days</option>
                <option value="30">Last 30 Days</option>
                <option value="all">All Time</option>
              </select>
            </div>

            <div style={{ marginLeft: 'auto', textAlign: 'right' }}>
              <div style={{ fontSize: 24, fontWeight: 700, color: 'var(--primary)' }}>
                {filteredScans.length || '-'}
              </div>
              <div style={{ fontSize: 11, color: 'var(--ink-muted)', textTransform: 'uppercase' }}>Filtered Scans</div>
            </div>
          </div>

          {/* Chart Grid */}
          <div className="chart-grid" style={{ gridTemplateColumns: '1fr 1fr' }}>
            <div className="card" style={{ padding: 24 }}>
              <h2 style={{ marginBottom: 16 }}>Diseases by Crop Type</h2>
              {diseasesByCropData.length === 0 ? (
                <div style={{ height: 280, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ink-muted)', fontStyle: 'italic' }}>
                  No scans match the selected filters.
                </div>
              ) : (
                <ResponsiveContainer width="100%" height={280}>
                  <BarChart data={diseasesByCropData}>
                    <CartesianGrid stroke="var(--border)" vertical={false} />
                    <XAxis dataKey="crop" tick={{ fontSize: 11, fill: 'var(--ink-muted)' }} axisLine={false} tickLine={false} />
                    <YAxis tick={{ fontSize: 11, fill: 'var(--ink-muted)' }} axisLine={false} tickLine={false} allowDecimals={false} />
                    <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8, borderColor: 'var(--border)' }} />
                    <Legend wrapperStyle={{ fontSize: 11 }} />
                    {uniqueDiseases.map((disease, idx) => (
                      <Bar
                        key={disease}
                        dataKey={disease}
                        stackId="a"
                        fill={colors[idx % colors.length]}
                        radius={[2, 2, 0, 0]}
                      />
                    ))}
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>

            <div className="card" style={{ padding: 24 }}>
              <h2 style={{ marginBottom: 16 }}>Outbreaks Over Time</h2>
              {outbreaksOverTime.length === 0 ? (
                <div style={{ height: 280, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ink-muted)', fontStyle: 'italic' }}>
                  No scans match the selected filters.
                </div>
              ) : (
                <ResponsiveContainer width="100%" height={280}>
                  <LineChart data={outbreaksOverTime}>
                    <CartesianGrid stroke="var(--border)" vertical={false} />
                    <XAxis
                      dataKey="date"
                      tick={{ fontSize: 10, fill: 'var(--ink-muted)' }}
                      axisLine={false}
                      tickLine={false}
                      tickFormatter={(d) => d.slice(5)} // Show MM-DD
                    />
                    <YAxis tick={{ fontSize: 11, fill: 'var(--ink-muted)' }} axisLine={false} tickLine={false} allowDecimals={false} />
                    <Tooltip contentStyle={{ fontSize: 12, borderRadius: 8, borderColor: 'var(--border)' }} />
                    <Line type="monotone" dataKey="count" name="Total Scans" stroke="var(--primary)" strokeWidth={3} activeDot={{ r: 6 }} dot={{ r: 2 }} />
                  </LineChart>
                </ResponsiveContainer>
              )}
            </div>
          </div>
        </>
      )}
    </>
  );
}
