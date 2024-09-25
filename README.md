# vite-plugin-rescript

This is a simple Vite plugin that starts `rescript` (or `rewatch`) at the beginning of the Vite pipeline.
It will ignore any ReScript files being watched by Vite.

## Install

This plugin is not published on npm; please fetch it from Git instead.

```sh
bun install -D git+https://github.com/nojaf/vite-plugin-rescript.git#825e59d061205b73c732e478001131f5e6b23acf
```

## Configuration

In your `vite.config.js`:

```js
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import rescript from "vite-plugin-rescript";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    rescript(),
    react({
      include: ["**/*.res.mjs"],
    }),
  ]
});
```

To use `rewatch` instead:

```js
rescript({ useRewatch: true })
```
note: The plugin specifically looks for `rewatch` in the `rescript` package, so you need version 12 for this to work.

## Why

I prefer to start my dev server using a single command to avoid a split terminal setup.