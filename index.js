import { spawn, execSync } from "node:child_process";

function rescriptPlugin({ useRewatch = false } = {}) {
  let rescriptProcressRef = null;
  let logger = { info: console.log, warn: console.warn, error: console.error };
  let command = "build";

  function build() {
    return useRewatch ? execSync("rewatch build") : execSync("rescript");
  }

  function watch() {
    return useRewatch ? spawn("rewatch", ["watch"]) : spawn("rescript", ["-w"]);
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
        rescriptProcressRef = watch();
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
          console.log(
            `${useRewatch ? "rewatch" : "rescript"} process exited with code ${code || 0}`,
          );
        });
      }
    },
    buildEnd: async function () {
      if (rescriptProcressRef && !rescriptProcressRef.killed) {
        const pid = rescriptProcressRef.pid;
        rescriptProcressRef.kill("SIGKILL"); // Default signal is SIGTERM
        logger.info(
          `${useRewatch ? "rewatch" : "rescript"} process with PID: ${pid} has been killed`,
        );
      }
    },
  };
}

export default rescriptPlugin;
