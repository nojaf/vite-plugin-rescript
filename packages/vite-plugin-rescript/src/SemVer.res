type options = {includePrerelease?: bool}

@module("semver")
external satisfies: (string, string, options) => bool = "satisfies"
