@unboxed
type command = | @as("serve") Serve | @as("build") Build

type logOptions = {
  clear?: bool,
  timestamp?: bool,
  environment?: string,
}

// https://github.com/vitejs/vite/blob/ea802f8f8bcf3771a35c1eaf687378613fbabb24/packages/vite/src/node/logger.ts#L10
type logger = {
  info: (string, ~options: logOptions=?) => unit,
  warn: (string, ~options: logOptions=?) => unit,
  error: (string, ~options: logOptions=?) => unit,
}

type configServerWatch = {mutable ignored?: array<string>}
type configServer = {mutable watch?: configServerWatch}
type config = {mutable server?: configServer}

type resolvedConfig = {command: command, logger: logger, configFile: string}

type filterHook<'handler> = {
  filter: {
    id: {
      @as("include")
      include_: RegExp.t,
    },
  },
  handler: 'handler,
}

@tag("event")
type change =
  | @as("create") Create
  | @as("update") Update
  | @as("delete") Delete

type changeEvent = {event: change}

type vitePlugin = {
  name: string,
  enforce?: string,
  config?: unit => config,
  configResolved?: resolvedConfig => promise<unit>,
  buildStart?: unit => promise<unit>,
  transform?: filterHook<(string, string) => promise<string>>,
  buildEnd?: unit => promise<unit>,
  watchChange?: (string, changeEvent) => promise<unit>,
  closeBundle?: unit => promise<unit>,
}
