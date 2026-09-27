// Alert Engine to compute anomaly flags dynamically from scans data
export function getActiveAlerts(scans) {
  if (!scans || scans.length === 0) return [];

  const alerts = [];
  const now = new Date();
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(now.getDate() - 7);

  // 1. Check for Spikes: 10+ cases of the same disease in the same Division/LGA in the last 7 days
  const spikeCounts = {}; // Key: "LGA|Disease|Crop"
  scans.forEach((s) => {
    const timestamp = new Date(s.device_timestamp);
    if (timestamp >= sevenDaysAgo && s.disease_label && s.disease_label.toLowerCase() !== 'healthy') {
      const key = `${s.lga}|${s.disease_label}|${s.crop_species}`;
      spikeCounts[key] = (spikeCounts[key] || 0) + 1;
    }
  });

  Object.entries(spikeCounts).forEach(([key, count]) => {
    if (count >= 10) {
      const [lga, disease, crop] = key.split('|');
      alerts.push({
        id: `alert-spike-${lga}-${disease}`.toLowerCase().replace(/\s+/g, '-'),
        type: 'Spike',
        message: `Spike: ${count} ${disease} cases in ${lga} in last 7 days`,
        severity: count >= 25 ? 'high' : 'medium',
        lga,
        disease,
        crop,
        count,
        date: new Date().toLocaleDateString(),
        sent: false,
      });
    }
  });

  // 2. Check for general outbreaks (e.g. 20+ cases of the same disease in the same Division/LGA overall)
  const outbreakCounts = {};
  scans.forEach((s) => {
    if (s.disease_label && s.disease_label.toLowerCase() !== 'healthy') {
      const key = `${s.lga}|${s.disease_label}|${s.crop_species}`;
      outbreakCounts[key] = (outbreakCounts[key] || 0) + 1;
    }
  });

  Object.entries(outbreakCounts).forEach(([key, count]) => {
    if (count >= 20) {
      const [lga, disease, crop] = key.split('|');
      // Avoid duplicate alert types for same lga/disease
      const alreadyAlerted = alerts.some((a) => a.lga === lga && a.disease === disease);
      if (!alreadyAlerted) {
        alerts.push({
          id: `alert-outbreak-${lga}-${disease}`.toLowerCase().replace(/\s+/g, '-'),
          type: 'Outbreak',
          message: `Outbreak: High ${disease} density in ${lga} (${count} cases)`,
          severity: 'medium',
          lga,
          disease,
          crop,
          count,
          date: new Date().toLocaleDateString(),
          sent: false,
        });
      }
    }
  });

  // 3. Notice alert for unverified scans (if any exist)
  const unverifiedCount = scans.filter((s) => !s.verified).length;
  if (unverifiedCount > 0) {
    alerts.push({
      id: 'alert-notice-unverified',
      type: 'System',
      message: `System: ${unverifiedCount} unverified scans require field check`,
      severity: 'low',
      lga: 'All',
      disease: 'Any',
      crop: 'Any',
      count: unverifiedCount,
      date: new Date().toLocaleDateString(),
      sent: false,
    });
  }

  return alerts;
}
