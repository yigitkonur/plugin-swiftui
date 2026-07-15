import { spawnSync } from "node:child_process";
import assert from "node:assert/strict";
import { lstat, mkdir, mkdtemp, readFile, readdir, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const temporary = await mkdtemp(path.join(os.tmpdir(), "swiftui-codex-install-"));
const codexHome = path.join(temporary, "codex-home");
const sourcePlugin = path.join(ROOT, "plugins", "swiftui");

async function relativeFiles(directory) {
  const found = [];
  async function walk(current) {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) await walk(absolute);
      else found.push(path.relative(directory, absolute));
    }
  }
  await walk(directory);
  return found.sort();
}

function codex(args) {
  const result = spawnSync("codex", args, {
    env: { ...process.env, CODEX_HOME: codexHome },
    encoding: "utf8",
  });
  if (result.status !== 0) {
    throw new Error(`codex ${args.join(" ")} failed (${result.status})\n${result.stdout}\n${result.stderr}`);
  }
  return result.stdout;
}

try {
  const version = (await readFile(path.join(ROOT, "VERSION"), "utf8")).trim();
  await mkdir(codexHome, { recursive: true });
  codex(["plugin", "marketplace", "add", ROOT, "--json"]);
  const added = JSON.parse(codex(["plugin", "add", "swiftui@swiftui-plugins", "--json"]));
  assert.equal(added.pluginId, "swiftui@swiftui-plugins");
  assert.equal(added.version, version);

  const installedPlugin = path.resolve(added.installedPath);
  assert.equal((await lstat(installedPlugin)).isDirectory(), true);
  const sourceFiles = await relativeFiles(sourcePlugin);
  const installedFiles = await relativeFiles(installedPlugin);
  assert.deepEqual(installedFiles, sourceFiles, "installed cache must contain the complete generated artifact");
  for (const relative of sourceFiles) {
    assert.deepEqual(
      await readFile(path.join(installedPlugin, relative)),
      await readFile(path.join(sourcePlugin, relative)),
      relative,
    );
  }

  const installed = JSON.parse(codex(["plugin", "list", "--json"]));
  const plugin = installed.installed.find((entry) => entry.pluginId === "swiftui@swiftui-plugins");
  assert.ok(plugin, `installed plugin was not reported: ${JSON.stringify(installed)}`);
  assert.equal(plugin.version, version);
  assert.equal(plugin.enabled, true);

  const skills = (await readdir(path.join(installedPlugin, "skills"), { withFileTypes: true }))
    .filter((entry) => entry.isDirectory());
  assert.equal(skills.length, 37);

  const mcpServers = JSON.parse(codex(["mcp", "list", "--json"]));
  const mcp = mcpServers.find((entry) => entry.name === "swiftui");
  assert.ok(mcp, `installed plugin MCP server was not registered: ${JSON.stringify(mcpServers)}`);
  assert.equal(mcp.enabled, true);
  assert.equal(path.resolve(mcp.transport.cwd), installedPlugin);

  console.log(`Codex tracked marketplace install smoke passed for swiftui ${version}`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
