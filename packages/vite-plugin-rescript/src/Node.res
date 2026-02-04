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
}

module Process = {
  @module("node:process") @scope("process")
  external kill: (int, @as(json`"SIGKILL"`) _) => bool = "kill"

  @scope("process") @val
  external platform: string = "platform"

  @scope("process") @val
  external arch: string = "arch"
}

module Url = {
  @module("node:url")
  external fileURLToPath: string => string = "fileURLToPath"
}

module ImportMeta = {
  @scope("import.meta") @val
  external resolve: string => string = "resolve"
}

module Path = {
  @module("node:path")
  external join: (string, string) => string = "join"

  @module("node:path")
  external dirname: string => string = "dirname"

  @module("node:path")
  external resolve: string => string = "resolve"

  type parseResult = {
    mutable ext: string,
    mutable base: string,
    name: string,
  }

  @module("node:path")
  external parse: string => parseResult = "parse"

  @module("node:path")
  external format: parseResult => string = "format"

  let changeExtension = (path, ext) => {
    let result = parse(path)
    result.ext = ext
    result.base = result.name ++ ext
    format(result)
  }
}

module FsPromises = {
  type mode
  module Constants = {
    @module("node:fs/promises") @scope("constants")
    external rOK: mode = "R_OK"
  }

  external access: (string, mode) => promise<unit> = "access"

  let fileExists = async path => {
    try {
      await access(path, Constants.rOK)
      true
    } catch {
    | _ => false
    }
  }

  @module("node:fs/promises")
  external readFile: (string, @as(json`"utf-8"`) _) => promise<string> = "readFile"
}
