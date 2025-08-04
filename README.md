[![NPM Version](https://img.shields.io/npm/v/@nojaf/vite-plugin-rescript)](https://www.npmjs.com/package/@nojaf/vite-plugin-rescript)

# vite-plugin-rescript

**ReScript v12 beta and higher**

This is a simple Vite plugin that starts `rescript` at the beginning of the Vite pipeline.
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
  ],
});
```

## Why

I prefer to start my dev server using a single command to avoid a split terminal setup.

## Prior art

This repository is equivalent to https://github.com/jihchi/vite-plugin-rescript, which is more mature.
You might want to try that out instead.

## Publish

(for maintainers)

```shell
bun publish --dry-run
bun publish  --access=public
```
