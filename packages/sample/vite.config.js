import { defineConfig } from "vite";
// import rescript from "@nojaf/vite-plugin-rescript";
import rescript from "../vite-plugin-rescript/src/Plugin.res.mjs";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    rescript()
  ]
});