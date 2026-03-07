import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";
import react from "@vitejs/plugin-react-swc";
import path from "path";

export default defineConfig({
 plugins: [
  RubyPlugin(),
  react({
   devTarget: "es2022",
  }),
 ],
 resolve: {
  dedupe: ["react", "react-dom", "react-i18next", "i18next"],
  alias: {
   react: path.resolve("./node_modules/react"),
   "react-dom": path.resolve("./node_modules/react-dom"),
  },
 },
 server: {
  port: 5173,
  strictPort: true,
  hmr: false, // Disable HMR to avoid preamble issues
 },
 build: {
  rollupOptions: {
   input: {
    "entrypoints/resume_form.jsx": "app/frontend/entrypoints/resume_form.jsx",
   },
  },
 },
});
