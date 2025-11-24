import { $ } from "bun";
import { tmpdir } from "os";
import { join } from "path";

const isDryRun = Bun.argv.includes("--dry-run");
const currentDir = import.meta.dirname;
const rootDir = `${currentDir}/..`;
const libraryDir = `${rootDir}/packages/vite-plugin-rescript`;

const lastVersion = await $`bunx changelog --latest-release`
  .cwd(rootDir)
  .text()
  .then((v) => v.trim());

const notes = await $`bunx changelog --latest-release-full`
  .cwd(rootDir)
  .text()
  .then((v) => v.trim());

const tag = `v${lastVersion}`;

// write notes to a temp file
const notesFile = join(tmpdir(), `release-notes-${lastVersion}.md`);
await Bun.write(notesFile, notes);

if (isDryRun) {
  console.log(`Dry run: Would publish version to NPM for ${lastVersion}`);
  await $`bun publish --dry-run`.cwd(libraryDir);

  console.log(`Dry run: Create GitHub release for ${tag}`);
  console.log(`Notes file: ${notesFile}`);
  console.log(notes);
} else {
  console.log(`Publishing version to NPM for ${lastVersion}`);
  await $`bun publish --access public`.cwd(libraryDir);

  console.log(`Creating GitHub release for ${tag}`);
  await $`gh release create ${tag} --title ${lastVersion} --notes-file ${notesFile}`.cwd(
    rootDir,
  );
  console.log(`Release ${tag} created`);
}
