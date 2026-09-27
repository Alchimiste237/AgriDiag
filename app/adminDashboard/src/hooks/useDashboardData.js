import { useCallback, useEffect, useState } from 'react';
import { fetchFarmers, fetchScans, mapScan } from '../utils/dataService';

/**
 * Load live scans + farmers from Supabase with loading/error state.
 * Always real database data — never static mock data. Callers render
 * dedicated empty/error states based on `loading`/`error`/`scans`.
 */
export function useDashboardData() {
  const [scans, setScans] = useState([]);
  const [farmers, setFarmers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [scanRows, farmerRows] = await Promise.all([fetchScans(), fetchFarmers()]);
      const farmerMap = {};
      farmerRows.forEach((f) => {
        farmerMap[f.id] = f;
      });
      setScans(scanRows.map((s) => mapScan(s, farmerMap)));
      setFarmers(farmerRows);
    } catch (err) {
      console.warn('Failed to load dashboard data from Supabase:', err);
      setError(err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    reload();
  }, [reload]);

  // setScans is exposed so pages can optimistically update the in-memory
  // list (e.g. ScanLog marks a scan verified while the DB write completes).
  return { scans, setScans, farmers, loading, error, reload };
}
