open Node
open Vite
open Dax

external import: string => promise<JSON.t> = "import"

type pluginOptions = {}

type state = {
  rescriptBin: string,
  mutable logger: logger,
  mutable command: command,
  mutable runningRewatch: option<CommandChild.t>,
}

@send
external atUnsafe: (array<'t>, int) => 't = "at"

/*
 const {
  binPaths: { rescript_editor_analysis_exe, rescript_tools_exe },
} = await import(`@rescript/${process.platform}-${process.arch}`);
 */

let rescript = async (_: pluginOptions): vitePlugin => {
  let rescriptVersionText = await sh`rescript --version`->ShellPromise.text
  let rescriptVersion = rescriptVersionText->String.split(" ")->atUnsafe(-1)
  if !SemVer.satisfies(rescriptVersion, ">=12.0.0", {includePrerelease: true}) {
    throw(Failure("Rescript version must be >=12.0.0"))
  }

  let platformImport = await import(`@rescript/${Process.platform}-${Process.arch}`)
  let rescriptBin = switch platformImport {
  | JSON.Object(dict{
      "binPaths": JSON.Object(dict{"rescript_exe": JSON.String(rescriptBin)}),
    }) => rescriptBin
  | _ => throw(Failure("Failed to resolve rescript.exe"))
  }

  // Resolve RESCRIPT_RUNTIME using import.meta.resolve (pure ESM).
  let runtimePkgUrl = ImportMeta.resolve("@rescript/runtime/package.json")
  let rescriptRuntime = runtimePkgUrl->Url.fileURLToPath->Path.dirname

  let pluginState: state = {
    rescriptBin,
    logger: {
      info: (msg, ~options={}) => {
        Console.log(msg)
      },
      warn: (msg, ~options={}) => {
        Console.warn(msg)
      },
      error: (msg, ~options={}) => {
        Console.log(msg)
      },
    },
    command: Build,
    runningRewatch: None,
  }

  {
    name: "rescript",
    enforce: "pre",
    config: () => {
      {
        server: {
          watch: {
            ignored: ["**/lib/**", "**/*.res", "**/*.resi"],
          },
        },
      }
    },
    configResolved: async resolvedConfig => {
      pluginState.logger = resolvedConfig.logger
      pluginState.command = resolvedConfig.command
    },
    buildStart: async () => {
      pluginState.logger.info(
        Picocolors.whiteBright(`About to build ReScript project with version ${rescriptVersion}`),
        ~options={timestamp: true},
      )
      switch pluginState.command {
      | Build => {
          let _ = await sh`rescript build`
        }
      | Serve =>
        pluginState.runningRewatch = Some(
          sh`${pluginState.rescriptBin} watch`
          ->ShellPromise.env("RESCRIPT_RUNTIME", rescriptRuntime)
          ->ShellPromise.noThrow
          ->ShellPromise.spawn,
        )
      }
    },
    closeBundle: async () => {
      switch pluginState.runningRewatch {
      | None => ()
      | Some(cp) => {
          pluginState.logger.info(
            Picocolors.whiteBright("About to kill ReScript process"),
            ~options={timestamp: true},
          )
          pluginState.runningRewatch = None
          CommandChild.kill(cp)

          try {
            let _ = await cp
          } catch {
          | JsExn(e) => pluginState.logger.error(Picocolors.red(`Failed to kill rescript watch`))
          }
        }
      }
    },
  }
}

let default = rescript
