import { expect, test, beforeAll } from "bun:test";
import { $ } from "bun";
import { Glob } from "bun";
import path from "node:path";
import { transform } from "../src/Transform.res.mjs";

const glob = new Glob("*.res.mjs");
for await (const file of glob.scan(import.meta.dir)) {
  if (file.startsWith("test_")) continue;

  const testFilePath = path.join(import.meta.dir, `test_${file}`);
  Bun.write(
    testFilePath,
    `
import { expect, test, beforeAll } from "bun:test";
import { testSnapshot } from "./index.js";
const file = "${file}";
test("snapshot", async () => { await testSnapshot(file); });
`,
  );
}

await $`bun rescript build`.quiet();

export async function testSnapshot(file) {
  const filePath = path.join(import.meta.dir, file);
  const resPath = filePath.replace(".res.mjs", ".res");
  const code = await Bun.file(filePath).text();
  expect(await transform(code, resPath)).toMatchSnapshot();
}
