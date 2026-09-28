import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// GitHub Pages serves the app from /<repo>/ instead of /, so the base path
// must be injected at build time. CI sets VITE_BASE (see .github/workflows).
// Local `npm run dev` / `npm run build` fall back to '/'.
export default defineConfig({
  plugins: [react()],
  base: process.env.VITE_BASE || '/',
  build: {
    rollupOptions: {
      output: {
        // Split the heavy vendor code so React, charts, maps and the
        // Supabase client load in parallel and cache independently.
        manualChunks(id) {
          if (id.includes('node_modules')) {
            if (id.includes('recharts') || id.includes('d3-')) return 'charts';
            if (id.includes('leaflet')) return 'maps';
            if (id.includes('@supabase')) return 'supabase';
            return 'vendor';
          }
        },
      },
    },
  },
});
