import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// GitHub Pages serves the app from /<repo>/ instead of /, so the base path
// must be injected at build time. CI sets VITE_BASE (see .github/workflows).
// Local `npm run dev` / `npm run build` fall back to '/'.
export default defineConfig({
  plugins: [react()],
  base: process.env.VITE_BASE || '/',
});
