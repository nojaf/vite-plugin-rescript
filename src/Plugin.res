open Node
open Vite

external import: string => promise<{..}> = "import"

type pluginOptions = {useRewatch?: bool}

%%private(let rewatchAlreadyRunningRegex = /Rewatch is already running with PID (\d+)/)

let rescript = (~options: pluginOptions={}): vitePlugin => {
  let useRewatch = options.useRewatch->Option.getOr(false)
  let rescriptProcressRef: ref<option<ChildProcess.t>> = ref(None)
  let logger: ref<logger> = ref({
    info: (msg, ~options={}) => {
      Console.log(msg)
    },
    warn: (msg, ~options={}) => {
      Console.warn(msg)
    },
    error: (msg, ~options={}) => {
      Console.log(msg)
    },
  })
  let command = ref(Build)
  let rewatchBin = ref(None)
  let outputExtension = ref(".res.mjs")

  let build = () => {
    switch rewatchBin.contents {
    | Some(rewatchBin) if useRewatch => {
        let rewatchProcess = ChildProcess.execSync(`${rewatchBin} build`)
        rescriptProcressRef := Some(rewatchProcess)
        rewatchProcess
      }
    | _ => ChildProcess.execSync("rescript")
    }
  }

  let rec watch = (logger: logger, ~isRetry=false): promise<ChildProcess.t> => {
    Promise.make((resolve: ChildProcess.t => unit, reject) => {
      let processRef = switch rewatchBin.contents {
      | Some(rewatchBin) if useRewatch => ChildProcess.spawn(rewatchBin, ["watch"])
      | _ => ChildProcess.spawn("rescript", ["-w"])
      }

      // Process standard output
      processRef->ChildProcess.onStdoutData(data => {
        logger.info(data->ChildProcess.Chunk.toString->String.trim)
      })

      // Process standard error
      processRef->ChildProcess.onStderrData(data => {
        let error = data->ChildProcess.Chunk.toString->String.trim

        // There can only be one instance of Rewatch and sometimes it does not get closed properly from the last run.
        if useRewatch && !isRetry {
          let match = error->String.match(rewatchAlreadyRunningRegex)
          switch match {
          | Some([_, Some(pids)]) =>
            switch Int.fromString(pids) {
            | Some(pid) =>
              logger.error(`rewatch was already running on ${pids}, trying to kill it and restart.`)
              let isKilled = Process.kill(pid)
              if !isKilled {
                logger.error(`Failed to kill rewatch process with PID ${pids}`)
              }
              watch(logger, ~isRetry=true)
              ->Promise.thenResolve(pref => resolve(pref))
              ->Promise.catch(
                err => {
                  reject(err)
                  Promise.resolve()
                },
              )
              ->Promise.done
            | None => reject(Exn.raiseError("Could not parse PID from rewatch error message"))
            }
          | _ => {
              logger.error(error)
              reject(Exn.raiseError(error))
            }
          }
        }
      })

      let processName = useRewatch ? "rewatch" : "rescript"

      // Handle process exit
      processRef->ChildProcess.onClose(code => {
        logger.info(
          `${processName} process (${processRef.pid->Int.toString}) exited with code ${code->Int.toString}`,
        )
      })

      logger.info(`Spawned ${processName} (${processRef.pid->Int.toString}) in watch mode`)

      resolve(processRef)
    })
  }

  {
    name: "rescript",
    enforce: "pre",
    config: () => {
      {
        server: {
          watch: {
            ignored: ["**/lib/**", "**/*.res"],
          },
        },
      }
    },
    configResolved: async resolvedConfig => {
      logger := resolvedConfig.logger
      command := resolvedConfig.command
      let rescriptConfig = Path.join(Path.dirname(resolvedConfig.configFile), "rescript.json")
      switch await FsPromises.fileExists(rescriptConfig) {
      | true => {
          let rescriptJson = await FsPromises.readFile(rescriptConfig)
          try {
            switch JSON.parseExn(rescriptJson) {
            | JSON.Object(dict{"suffix": JSON.String(suffix)}) => outputExtension := suffix
            | _ => logger.contents.warn("rescript.json should be an object with a 'suffix' key")
            }
          } catch {
          | _ => logger.contents.warn("rescript.json should be a valid JSON object")
          }
        }
      | _ => ()
      }

      if useRewatch {
        try {
          let binPath = await import(
            Path.join(Path.resolve("node_modules"), "rescript/cli/bin_path.js"),
          )
          let rewatchBinPath = Path.join(binPath["absolutePath"], "rewatch.exe")
          rewatchBin := Some(rewatchBinPath)
          logger.contents.info(`rewatchBin found at ${rewatchBinPath}`)
        } catch {
        | e => {
            logger.contents.error(`Option rewatch can only be used using the v12 alpha.`)
            raise(e)
          }
        }
      }
    },
    buildStart: async () => {
      switch command.contents {
      | Build => logger.contents.info(build()->ChildProcess.toString->String.trim)
      | Serve => rescriptProcressRef := Some(await watch(logger.contents))
      }
    },
    buildEnd: async () => {
      rescriptProcressRef.contents->Option.forEach(rescriptProcressRef => {
        if !rescriptProcressRef.killed {
          let pid = rescriptProcressRef.pid
          if Process.kill(pid) {
            let processName = useRewatch ? "rewatch" : "rescript"
            logger.contents.info(`Killed ${processName} process with PID ${pid->Int.toString}`)
          }
        }
      })
    },
  }
}

let default = rescript
