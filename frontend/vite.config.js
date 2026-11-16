import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// The app calls relative /api URLs; Nginx routes them to Django. For
// `npm run dev` outside Docker, proxy to a locally running backend.
export default defineConfig({
  plugins: [react()],
  server: { proxy: { "/api": "http://localhost:8000" } },
});
