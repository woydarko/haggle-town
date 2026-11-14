import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: { proxy: { "/api": "http://localhost:8080" } },
  // Two pages: landing at "/", dashboard at "/app/".
  build: { rollupOptions: { input: { main: "index.html", app: "app/index.html" } } },
});
