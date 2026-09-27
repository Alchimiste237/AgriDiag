import L from 'leaflet';

// CARTO's public basemap endpoints now require an API key — without one the
// tiles load with an "API key required" watermark pasted over the map.
// Default to OpenStreetMap's standard tiles (no key needed). If a CARTO key
// is provided via VITE_CARTO_API_KEY (see .env.example), use CARTO instead.
const CARTO_API_KEY = import.meta.env.VITE_CARTO_API_KEY || '';

const OSM_URL = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const OSM_ATTR =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';

const CARTO_URL = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
const CARTO_ATTR =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>';

/**
 * Creates the Leaflet tile layer for the app's maps.
 * @param {object} [options] Extra L.tileLayer options (subdomains, maxZoom…).
 * @returns {L.TileLayer}
 */
export function createBasemapLayer(options = {}) {
  const useCarto = CARTO_API_KEY !== '';
  const url = useCarto ? `${CARTO_URL}?apikey=${CARTO_API_KEY}` : OSM_URL;
  const attribution = useCarto ? CARTO_ATTR : OSM_ATTR;

  return L.tileLayer(url, {
    attribution,
    ...(useCarto ? { subdomains: 'abcd', maxZoom: 20 } : { maxZoom: 19 }),
    ...options,
  });
}
