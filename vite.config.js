import { spawn, execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const currentDir = path.dirname(fileURLToPath(import.meta.url));

function rescriptPlugin() {
  let rescriptProcressRef = null;
  let logger = { info: console.log, warn: console.warn, error: console.error };
  let command = "build";

  return {
    name: "rescript",
    enforce: "pre",
    // Don't watch *.res file with ReScript.
    config: function (config) {
      if (!config.server) {
        config.server = {};
      }
      if (!config.server.watch) {
        config.server.watch = {};
      }

      if (Array.isArray(config.server.watch.ignored)) {
        config.server.watch.ignored.push("**/*.res");
      } else {
        config.server.watch.ignored = ["**/*.res"];
      }
    },
    configResolved: async function (resolvedConfig) {
      logger = resolvedConfig.logger;
      command = resolvedConfig.command;
    },
    buildStart: async function () {
      if (command === "build") {
        logger.info(execSync("rescript").toString().trim());
      } else {
        rescriptProcressRef = spawn("rescript", ["-w"]);
        logger.info(`Spawned bunx rescript -w`);

        // Process standard output
        rescriptProcressRef.stdout.on("data", (data) => {
          logger.info(data.toString().trim());
        });

        // Process standard error
        rescriptProcressRef.stderr.on("data", (data) => {
          logger.error(data.toString().trim());
        });

        // Handle process exit
        rescriptProcressRef.on("close", (code) => {
          console.log(`ReScript process exited with code ${code || 0}`);
        });
      }
    },
    buildEnd: async function () {
      if (rescriptProcressRef && !rescriptProcressRef.killed) {
        const pid = rescriptProcressRef.pid;
        rescriptProcressRef.kill("SIGKILL"); // Default signal is SIGTERM
        logger.info(`ReScript process with PID: ${pid} has been killed`);
      }
    },
  };
}

function honoPlugin() {
  const honoServer = path.join(currentDir, "server", "Server.res.mjs");
  let bunProcressRef = null;
  let logger = { info: console.log, warn: console.warn, error: console.error };
  let command;

  return {
    name: "hone",
    enforce: "pre",
    configResolved: async function (resolvedConfig) {
      logger = resolvedConfig.logger;
      command = resolvedConfig.command;
    },
    buildStart: async function () {
      if (command === "serve" && existsSync(honoServer)) {
        bunProcressRef = spawn("bun", ["--watch", honoServer]);
        logger.info(`Spawned bun --watch ${honoServer}`);

        bunProcressRef.stdout.on("data", (data) => {
          logger.info(data.toString().trim());
        });

        bunProcressRef.stderr.on("data", (data) => {
          logger.error(data.toString().trim());
        });

        bunProcressRef.on("close", (code) => {
          console.log(`bun --watch process exited with code ${code || 0}`);
        });
      }
    },
    buildEnd: async function () {
      if (bunProcressRef && !bunProcressRef.killed) {
        const pid = bunProcressRef.pid;
        bunProcressRef.kill("SIGKILL"); // Default signal is SIGTERM
        logger.info(`bun process with PID: ${pid} has been killed`);
      }
    },
  };
}

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    rescriptPlugin(),
    honoPlugin(),
    react({
      include: ["**/*.res.mjs"],
    }),
  ],
  server: {
    port: 7200,
    proxy: {
      "/api": {
        target: "http://localhost:1792",
        changeOrigin: true,
      },
    },
  },
});
