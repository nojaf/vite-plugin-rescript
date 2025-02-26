[![NPM Version](https://img.shields.io/npm/v/@nojaf/vite-plugin-rescript)](https://www.npmjs.com/package/@nojaf/vite-plugin-rescript)


# vite-plugin-rescript

This is a simple Vite plugin that starts `rescript` (or `rewatch`) at the beginning of the Vite pipeline.
It will ignore any ReScript files being watched by Vite.

## Install

This plugin is not published on npm; please fetch it from Git instead.

```sh
bun install -D @nojaf/vite-plugin-rescript
```

## Configuration

In your `vite.config.js`:

```js
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import rescript from "@nojaf/vite-plugin-rescript";

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

## Publish

(for maintainers)

```shell
bun publish --dry-run
bun publish  --access=public
```