import { expect, test, beforeAll } from "bun:test";
import { $ } from "bun";
import { Glob } from "bun";
import path from "node:path";
import { transform } from "../src/Transform.res.mjs";

const glob = new Glob("*.res.mjs");
let testFiles = await Array.fromAsync(glob.scan(import.meta.dir));
testFiles = testFiles.toSorted((a, b) => a.localeCompare(b));

beforeAll(async () => {
    await $`bun rescript build`.quiet();
});

test.each(testFiles)("snapshot", async (file) => {
    const filePath = path.join(import.meta.dir, file);
    const resPath = filePath.replace(".res.mjs", ".res");
    const code = await Bun.file(filePath).text();
    expect(await transform(code, resPath)).toMatchSnapshot();
});
