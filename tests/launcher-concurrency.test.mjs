import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const WRAPPER = path.join(ROOT, "scripts", "swiftui-ctx");
const FIXTURES = path.join(ROOT, "tests", "fixtures");

function run(env) {
  return new Promise((resolve, reject) => {
    const child = spawn("bash", [WRAPPER, "doctor", "--json"], { env });
    const stdout = [];
    const stderr = [];
    child.stdout.on("data", (chunk) => stdout.push(chunk));
    child.stderr.on("data", (chunk) => stderr.push(chunk));
    child.on("error", reject);
    child.on("close", (status) => resolve({
      status,
      stdout: Buffer.concat(stdout).toString("utf8"),
      stderr: Buffer.concat(stderr).toString("utf8"),
    }));
  });
}

test("parallel cold starts share one launcher bootstrap", async (t) => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "swiftui-launcher-"));
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const count = path.join(temporary, "curl-count");
  const swiftCount = path.join(temporary, "swift-count");
  const pluginRoot = path.join(temporary, "plugin");
  await mkdir(pluginRoot);
  await writeFile(path.join(pluginRoot, "VERSION"), await readFile(path.join(ROOT, "VERSION")));
  const env = {
    ...process.env,
    PATH: `${FIXTURES}:${process.env.PATH}`,
    PLUGIN_ROOT: pluginRoot,
    XDG_CACHE_HOME: path.join(temporary, "cache"),
    FAKE_SWIFTUI_BINARY: path.join(FIXTURES, "fake-swiftui-ctx.mjs"),
    FAKE_CURL_COUNT: count,
    FAKE_SWIFT_COUNT: swiftCount,
  };
  delete env.SWIFTUI_CTX_BIN;
  const results = await Promise.all([run(env), run(env)]);
  for (const result of results) {
    assert.equal(result.status, 0, result.stderr);
    assert.equal(JSON.parse(result.stdout).ok, true);
  }
  assert.equal(await readFile(count, "utf8"), "x");
  await assert.rejects(readFile(swiftCount), { code: "ENOENT" });
});
