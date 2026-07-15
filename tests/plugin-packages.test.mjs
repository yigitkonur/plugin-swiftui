import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { lstat, readFile, readdir } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { parseDocument } from "yaml";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CLAUDE = path.join(ROOT, "dist", "claude-swiftui-plugin");
const CODEX = path.join(ROOT, "dist", "codex-swiftui-plugin");
const MARKETPLACE_CODEX = path.join(ROOT, "plugins", "swiftui");

async function walk(directory) {
  const found = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const current = path.join(directory, entry.name);
    found.push(current);
    if (entry.isDirectory()) found.push(...await walk(current));
  }
  return found;
}

async function relativeFiles(directory) {
  const files = [];
  for (const file of await walk(directory)) {
    if (!(await lstat(file)).isDirectory()) files.push(path.relative(directory, file));
  }
  return files.sort();
}

async function json(file) {
  return JSON.parse(await readFile(file, "utf8"));
}

test("all package and binary versions match VERSION", async () => {
  const version = (await readFile(path.join(ROOT, "VERSION"), "utf8")).trim();
  const versionedJson = [
    "package.json",
    "packages/swiftui-core/package.json",
    "packages/claude-plugin/package.json",
    "packages/codex-plugin/package.json",
    "package-lock.json",
    ".claude-plugin/plugin.json",
    "packages/codex-plugin/plugin/.codex-plugin/plugin.json",
  ];
  for (const relative of versionedJson) assert.equal((await json(path.join(ROOT, relative))).version, version, relative);
  const claudeMarketplace = await json(path.join(ROOT, ".claude-plugin/marketplace.json"));
  assert.equal(claudeMarketplace.metadata.version, version);
  assert.equal(claudeMarketplace.plugins[0].version, version);
  assert.equal(claudeMarketplace.plugins[0].source, ".");
  const codexMarketplace = await json(path.join(ROOT, ".agents/plugins/marketplace.json"));
  assert.deepEqual(codexMarketplace.plugins[0].source, {
    source: "local",
    path: "./plugins/swiftui",
  });
  const swift = await readFile(path.join(ROOT, "swiftui-scan/Sources/swiftui-ctx/SwiftUICtx.swift"), "utf8");
  assert.match(swift, new RegExp(`swiftuiCtxVersion = "${version.replaceAll(".", "\\.")}"`));
  assert.equal((await readFile(path.join(ROOT, "plugins/swiftui/VERSION"), "utf8")).trim(), version);
  assert.match(await readFile(path.join(ROOT, "README.md"), "utf8"), new RegExp(`badge/version-${version.replaceAll(".", "\\.")}-blue`));
});

test("committed Codex marketplace plugin matches the assembled package", async () => {
  const assembledPaths = await relativeFiles(CODEX);
  const marketplacePaths = await relativeFiles(MARKETPLACE_CODEX);
  const tracked = spawnSync("git", ["ls-files", "-z", "--", "plugins/swiftui"], {
    cwd: ROOT,
    encoding: "utf8",
  });
  assert.equal(tracked.status, 0, tracked.stderr);
  const trackedPaths = tracked.stdout
    .split("\0")
    .filter(Boolean)
    .map((file) => path.relative("plugins/swiftui", file))
    .sort();
  assert.deepEqual(trackedPaths, marketplacePaths);
  assert.deepEqual(marketplacePaths, assembledPaths);
  for (const relative of assembledPaths) {
    assert.deepEqual(
      await readFile(path.join(MARKETPLACE_CODEX, relative)),
      await readFile(path.join(CODEX, relative)),
      relative,
    );
  }
});

test("assembled packages are isolated and contain only runtime assets", async () => {
  const claudePaths = await walk(CLAUDE);
  const codexPaths = await walk(CODEX);
  for (const file of [...claudePaths, ...codexPaths]) {
    assert.equal((await lstat(file)).isSymbolicLink(), false, `symlink: ${file}`);
    const relative = path.relative(file.startsWith(CODEX) ? CODEX : CLAUDE, file);
    assert.doesNotMatch(relative, /(^|\/)(\.git|data|eval|node_modules|__pycache__|\.build)(\/|$)/);
  }
  await assert.rejects(lstat(path.join(CLAUDE, ".claude-plugin", "marketplace.json")));
  await assert.rejects(lstat(path.join(CODEX, ".claude-plugin")));
  await assert.rejects(lstat(path.join(CODEX, "commands")));
  const runtimeScripts = (await readdir(path.join(CODEX, "scripts"))).sort();
  assert.deepEqual(runtimeScripts, [
    "audit-gate.sh",
    "audit-scan.py",
    "audit-signals.tsv",
    "macos-swiftui-lint.sh",
    "sosumi.sh",
    "swiftui-ctx",
    "swiftui-lint.sh",
  ]);
});

test("Codex package has 37 discoverable skills and four explicit workflows", async () => {
  const skillsRoot = path.join(CODEX, "skills");
  const skills = (await readdir(skillsRoot, { withFileTypes: true })).filter((entry) => entry.isDirectory());
  assert.equal(skills.length, 37);
  let descriptionBudget = 0;
  for (const skill of skills) {
    const text = await readFile(path.join(skillsRoot, skill.name, "SKILL.md"), "utf8");
    const description = text.match(/^description:\s*(.*)$/m)?.[1] ?? "";
    assert.ok(description, `${skill.name} description`);
    descriptionBudget += description.length;
    assert.doesNotMatch(text, /\$\{?CLAUDE_PLUGIN_ROOT/);
  }
  assert.ok(descriptionBudget <= 8_000, `skill descriptions use ${descriptionBudget} characters`);
  for (const name of ["swiftui", "swiftui-review", "swiftui-audit", "swiftui-settings"]) {
    const metadata = await readFile(path.join(skillsRoot, name, "agents", "openai.yaml"), "utf8");
    assert.match(metadata, /allow_implicit_invocation:\s*false/);
  }
});

test("Claude and Codex skill frontmatter parses as YAML", async () => {
  for (const packageRoot of [CLAUDE, CODEX]) {
    const skillFiles = (await walk(path.join(packageRoot, "skills"))).filter((file) => path.basename(file) === "SKILL.md");
    for (const file of skillFiles) {
      const text = await readFile(file, "utf8");
      const frontmatter = text.match(/^---\n([\s\S]*?)\n---\n/)?.[1];
      assert.ok(frontmatter, `frontmatter: ${file}`);
      const parsed = parseDocument(frontmatter);
      assert.deepEqual(parsed.errors, [], `YAML errors in ${file}`);
      assert.equal(parsed.get("name"), path.basename(path.dirname(file)));
      assert.equal(typeof parsed.get("description"), "string");
    }
  }
});

test("Codex manifest wires the bundled MCP server without a hooks field", async () => {
  const manifest = await json(path.join(CODEX, ".codex-plugin", "plugin.json"));
  assert.equal(manifest.skills, "./skills/");
  assert.equal(manifest.mcpServers, "./.mcp.json");
  assert.equal(Object.hasOwn(manifest, "hooks"), false);
  const mcp = await json(path.join(CODEX, ".mcp.json"));
  assert.deepEqual(mcp.mcpServers.swiftui, {
    command: "node",
    args: ["./mcp/server.mjs"],
    cwd: ".",
  });
  assert.ok((await lstat(path.join(CODEX, "mcp", "server.mjs"))).size > 100_000);
});
