import { spawn, execSync } from "node:child_process";
// import { absolutePath as binAbsolutePath } from "rescript/cli/bin_path.js"
import * as path from "node:path"

console.log(path.resolve("node_modules"));

const rewatchAlreadyRunningRegex = /Rewatch is already running with PID (\d+)/;

function rescriptPlugin({ useRewatch = false } = {}) {
  let rescriptProcressRef = null;
  let logger = { info: console.log, warn: console.warn, error: console.error };
  let command = "build";

  function build() {
    return useRewatch ? execSync("rewatch build") : execSync("rescript");
  }

  function watch(logger, isRetry = false) {
    return new Promise((resolve, reject) => {
      const processRef = useRewatch
        ? spawn("rewatch", ["watch"])
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
    },
    buildStart: async function () {
      if (command === "build") {
        logger.info(build().toString().trim());
      } else {
        rescriptProcressRef = await watch(logger);
        logger.info(`REQRCH ID: ${rescriptProcressRef.pid}`);
      }
    },
    buildEnd: async function () {
      if (rescriptProcressRef && !rescriptProcressRef.killed) {
        const pid = rescriptProcressRef.pid;
        process.kill(pid, "SIGKILL"); // Default signal is SIGTERM
        logger.info(
          `${useRewatch ? "rewatch" : "rescript"} process with PID: ${pid} has been killed`,
        );
      }
    },
  };
}

export default rescriptPlugin;
