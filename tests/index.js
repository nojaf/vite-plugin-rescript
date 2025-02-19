import { expect, test, beforeAll } from "bun:test";
import { $ } from "bun";
import { Glob } from "bun";
import path from "node:path";
import { transform } from "../transform";

const glob = new Glob("*.res.mjs");
let testFiles = await Array.fromAsync(glob.scan(import.meta.dir));
testFiles = testFiles.toSorted((a, b) => a.localeCompare(b));

beforeAll(async () => {
    await $`bun rescript build`.quiet();
});

test.each(testFiles)("snapshot", async (file) => {
    const code = await Bun.file(path.join(import.meta.dir, file)).text();
    expect(await transform(code, file)).toMatchSnapshot();
});
