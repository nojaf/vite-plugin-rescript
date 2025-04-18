open Node
open Vite

external import: string => promise<{..}> = "import"

type pluginOptions = {useRewatch?: bool}

%%private(let rewatchAlreadyRunningRegex = /Rewatch is already running with PID (\d+)/)
%%private(let foundABug = "We've found a bug for you!")
%%private(let warning = "Warning number")

let rescript = (~options: pluginOptions={}): vitePlugin => {
  let useRewatch = options.useRewatch->Option.getOr(false)
  let rescriptProcressRef: ref<option<ChildProcess.t>> = ref(None)
  @warning("-27")
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
  @warning("+27")
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

      let buffer = ref("")

      // Process standard output
      processRef->ChildProcess.onStdoutData(data => {
        buffer := buffer.contents ++ data->ChildProcess.Chunk.toString
        let lines =
          buffer.contents
          ->String.split("\n")
          ->Array.filter(line => !(line->String.includes("rescript: [")))
        buffer := lines->Array.pop->Option.getOr("")
        let hasBugOrWarning =
          lines->Array.some(v => v->String.includes("FAILED:") || v->String.includes(warning))
        if hasBugOrWarning {
          Array.forEach(
            lines,
            line => {
              let errorLineNumber =
                lines
                ->Array.filterMap(
                  line => {
                    let parts = line->String.split("│")
                    switch parts {
                    | [number, _] => number->Int.fromString
                    | _ => None
                    }
                  },
                )
                ->Array.at(2)
                ->Option.getOr(-1)
              let lineText = switch line {
              | line if line->String.includes(foundABug) => line->Picocolors.bold->Picocolors.red
              | line if line->String.includes(`${errorLineNumber->Int.toString} │`) =>
                line->String.replaceRegExp(/^\s+\d+/, Obj.magic(Picocolors.red))
              | line if RegExp.test(/\.res(i?):/, line) => {
                  let colonIndex = line->String.indexOf(":")
                  if colonIndex == -1 {
                    line
                  } else {
                    let path = line->String.slice(~start=0, ~end=colonIndex)
                    let range = line->String.sliceToEnd(~start=colonIndex + 1)
                    Picocolors.cyanBright(path) ++ ":" ++ Picocolors.whiteBright(range)
                  }
                }
              | line if line->String.includes("FAILED:") =>
                line->String.replaceRegExp(/FAILED:/, Obj.magic(Picocolors.redBright))
              | line if line->String.includes(warning) =>
                line->Picocolors.yellowBright->Picocolors.bold
              | _ => line
              }

              logger.error(lineText)
            },
          )
        } else {
          switch lines {
          | [line] if line->String.includes(">>>> Start compiling") =>
            logger.info(Picocolors.cyanBright(line))
          | [line] if line->String.includes(">>>> Finish compiling") =>
            logger.info(
              line->String.replaceRegExp(
                /^(>>>> Finish compiling )(\d+)(.*)$/,
                Obj.magic(
                  (_, lead, number, rest) => {
                    Picocolors.cyanBright(lead) ++ Picocolors.yellowBright(number) ++ rest
                  },
                ),
              ),
            )
          | lines =>
            Array.forEach(
              lines,
              line => {
                logger.info(line->String.trim)
              },
            )
          }
        }
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
