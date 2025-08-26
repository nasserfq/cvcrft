import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";
import react from "@vitejs/plugin-react";

export default defineConfig({
 plugins: [RubyPlugin(), react()],
 build: {
  rollupOptions: {
   input: {
    "entrypoints/resume_form.jsx": "app/frontend/entrypoints/resume_form.jsx",
   },
  },
 },
});
