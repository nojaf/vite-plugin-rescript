import { spawn, execSync } from "node:child_process";
import * as path from "node:path";
import { transform } from "./transform.js";

const rewatchAlreadyRunningRegex = /Rewatch is already running with PID (\d+)/;

function rescriptPlugin({ useRewatch = false } = {}) {
  let rescriptProcressRef = null;
  let logger = { info: console.log, warn: console.warn, error: console.error };
  let command = "build";
  let rewatchBin = null;

  function build() {
    return useRewatch ? execSync(`${rewatchBin} build`) : execSync("rescript");
  }

  function watch(logger, isRetry = false) {
    return new Promise((resolve, reject) => {
      const processRef = useRewatch
        ? spawn(rewatchBin, ["watch"])
        : spawn("rescript", ["-w"]);

      // Process standard output
      processRef.stdout.on("data", (data) => {
        logger.info(data.toString().trim());
      });

      // Process standard error
      processRef.stderr.on("data", (data) => {
        const error = data.toString().trim();

        // There can only be one instance of Rewatch and sometimes it does not get closed properly from the last run.
        if (useRewatch && !isRetry) {
          const match = error.match(rewatchAlreadyRunningRegex);
          // Try and see what the port in the error message is.
          if (match && match[1]) {
            const pid = parseInt(match[1]);
            if (pid) {
              logger.error(
                `rewatch was already running on ${pid}, trying to kill it and restart.`,
              );
              process.kill(pid, "SIGKILL");
              watch(logger, true).then(resolve).catch(reject);
            }
          }
        } else {
          logger.error(error);
          reject(error);
        }
      });

      // Handle process exit
      processRef.on("close", (code) => {
        console.log(
          `${useRewatch ? "rewatch" : "rescript"} process (${processRef.pid}) exited with code ${code || 0}`,
        );
      });

      logger.info(
        `Spawned ${useRewatch ? "rewatch" : "rescript"} (${processRef.pid}) in watch mode`,
      );

      resolve(processRef);
    });
  }

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

      // bun rewatch calls rewatch.exe immediatly as a child process,
      // it is easier to just start that directly.
      if (useRewatch) {
        try {
          const binPath = await import(
            path.join(path.resolve("node_modules"), "rescript/cli/bin_path.js")
          );
          rewatchBin = path.join(binPath.absolutePath, "rewatch.exe");
          logger.info(`rewatchBin found at ${rewatchBin}`);
        } catch (err) {
          logger.error(`Option rewatch can only be used using the v12 alpha.`);
          throw err;
        }
      }
    },
    buildStart: async function () {
      if (command === "build") {
        logger.info(build().toString().trim());
      } else {
        rescriptProcressRef = await watch(logger);
      }
    },
    transform: transform,
    buildEnd: function () {
      if (rescriptProcressRef && !rescriptProcressRef.killed) {
        const pid = rescriptProcressRef.pid;
        // Default signal is SIGTERM
        if (process.kill(pid, "SIGKILL")) {
          logger.info(
            `${useRewatch ? "rewatch" : "rescript"} process with PID: ${pid} has been killed`,
          );
        }
      }
    },
  };
}

export default rescriptPlugin;
