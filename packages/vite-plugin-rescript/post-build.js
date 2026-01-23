const lastArg = Bun.argv.at(-1);
// build --target=node src/Plugin.res.mjs --outdir . --entry-naming \"index.[ext]\"
if (lastArg && lastArg.endsWith("src/Plugin.res.mjs")) {
  const buildOutput = await Bun.build({
    entrypoints: [lastArg],
    outdir: ".",
    naming: "index.[ext]",
    production: true,
    minify: false,
    target: "node",
    external: ["semver"],
  });
  console.log(`Bundled ${lastArg} to ${buildOutput.outputs[0].path}`);
}
