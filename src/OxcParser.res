type program = {body: array<dict<JSON.t>>}

module MagicString = {
  type t

  @send
  external toString: t => string = "toString"

  @send
  external remove: (t, int, int) => unit = "remove"
}

type rec parseResult = {
  program: program,
  magicString: MagicString.t,
}

@module("oxc-parser")
external parseAsync: (string, string) => promise<parseResult> = "parseAsync"
