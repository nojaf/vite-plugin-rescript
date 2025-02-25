module NpmRunPath = {
  type env

  @module("npm-run-path")
  external npmRunPathEnv: unit => env = "npmRunPathEnv"
}

module ChildProcess = {
  type t = {
    pid: int,
    killed: bool,
  }

  @module("node:child_process")
  external spawn: (string, array<string>) => t = "spawn"

  @module("node:child_process")
  external execSync: string => t = "execSync"

  @send
  external toString: t => string = "toString"

  module Chunk = {
    type t
    @send
    external toString: t => string = "toString"
  }

  @send @scope("stdout")
  external onStdoutData: (t, @as(json`"data"`) _, Chunk.t => unit) => unit = "on"

  @send @scope("stderr")
  external onStderrData: (t, @as(json`"data"`) _, Chunk.t => unit) => unit = "on"

  @send
  external onClose: (t, @as(json`"close"`) _, int => unit) => unit = "on"

  @module("node:child_process")
  external execWithCallbacks: (string, {..}, (Null.t<Exn.t>, string, string) => unit) => unit =
    "exec"

  let execAsync = cmd => {
    Promise.make((resolve, reject) => {
      execWithCallbacks(
        cmd,
        {
          "encoding": "utf-8",
          "env": NpmRunPath.npmRunPathEnv(),
        },
        (error, stdout, stderr) => {
          switch error {
          | Null.Value(error) => reject(error)
          | Null.Null =>
            if stderr->String.trim->String.length > 0 {
              reject(Error.make(stderr->String.trim))
            } else {
              resolve(stdout->String.trim)
            }
          }
        },
      )
    })
  }
}

module Process = {
  @module("node:process") @scope("process")
  external kill: (int, @as(json`"SIGKILL"`) _) => bool = "kill"
}

module Path = {
  @module("node:path")
  external join: (string, string) => string = "join"

  @module("node:path")
  external dirname: string => string = "dirname"

  @module("node:path")
  external resolve: string => string = "resolve"
}

module FsPromises = {
  type mode
  module Constants = {
    @module("node:fs/promises") @scope("constants")
    external rOK: mode = "R_OK"
  }

  external access: (string, mode) => Js.Promise.t<unit> = "access"

  let fileExists = async path => {
    try {
      await access(path, Constants.rOK)
      true
    } catch {
    | _ => false
    }
  }

  @module("node:fs/promises")
  external readFile: (string, @as(json`"utf-8"`) _) => Js.Promise.t<string> = "readFile"
}
