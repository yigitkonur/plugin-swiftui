import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const HOOK = path.join(ROOT, "hooks", "deprecation-guard.sh");

function runHook(payload, cwd, env = {}) {
  return spawnSync("bash", [HOOK], {
    cwd,
    env: { ...process.env, PLUGIN_ROOT: ROOT, ...env },
    input: typeof payload === "string" ? payload : JSON.stringify(payload),
    encoding: "utf8",
  });
}

async function project() {
  const root = await mkdtemp(path.join(os.tmpdir(), "swiftui-hook-"));
  spawnSync("git", ["init", "-q", root]);
  const subdirectory = path.join(root, "Sources", "Feature");
  await mkdir(subdirectory, { recursive: true });
  return { root, subdirectory };
}

test("Codex apply_patch scans added Swift lines but ignores removals", async (t) => {
  const { root, subdirectory } = await project();
  t.after(() => rm(root, { recursive: true, force: true }));
  const added = runHook({ cwd: subdirectory, tool_name: "apply_patch", tool_input: { command: "*** Begin Patch\n*** Update File: View.swift\n@@\n+Text(\"x\").foregroundColor(.red)\n*** End Patch" } }, subdirectory);
  assert.equal(added.status, 0);
  assert.match(added.stdout, /foregroundColor/);
  const removed = runHook({ cwd: subdirectory, tool_name: "apply_patch", tool_input: { command: "*** Begin Patch\n*** Update File: View.swift\n@@\n-Text(\"x\").foregroundColor(.red)\n+Text(\"x\").foregroundStyle(.red)\n*** End Patch" } }, subdirectory);
  assert.equal(removed.stdout, "");
});

test("Codex move-to Swift and Claude Write payloads are normalized", async (t) => {
  const { root } = await project();
  t.after(() => rm(root, { recursive: true, force: true }));
  const moved = runHook({ cwd: root, tool_input: { command: "*** Begin Patch\n*** Update File: View.txt\n*** Move to: View.swift\n@@\n+NavigationView { Text(\"x\") }\n*** End Patch" } }, root);
  assert.match(moved.stdout, /NavigationView/);
  const claude = runHook({ cwd: root, tool_input: { file_path: `${root}/View.swift`, content: "Text(\"x\").accentColor(.red)" } }, root);
  assert.match(claude.stdout, /accentColor/);
});

test("neutral settings win from a nested cwd and missing enabled defaults on", async (t) => {
  const { root, subdirectory } = await project();
  t.after(() => rm(root, { recursive: true, force: true }));
  await mkdir(path.join(root, ".claude"), { recursive: true });
  await writeFile(path.join(root, ".claude", "swiftui.local.md"), "---\nenabled: true\n---\n");
  await mkdir(path.join(root, ".swiftui-plugin"), { recursive: true });
  await writeFile(path.join(root, ".swiftui-plugin", "settings.md"), "---\nenabled: false\n---\n");
  const payload = { cwd: subdirectory, tool_input: { file_path: `${root}/View.swift`, content: "NavigationView {}" } };
  assert.equal(runHook(payload, subdirectory).stdout, "");
  await writeFile(path.join(root, ".swiftui-plugin", "settings.md"), "---\nstrict_audit: true\n---\n");
  assert.match(runHook(payload, subdirectory).stdout, /NavigationView/);
});

test("environment opt-out and malformed payloads are nonblocking", async (t) => {
  const { root } = await project();
  t.after(() => rm(root, { recursive: true, force: true }));
  const payload = { cwd: root, tool_input: { file_path: `${root}/View.swift`, content: "NavigationView {}" } };
  assert.equal(runHook(payload, root, { SWIFTUI_GUARD: "off" }).stdout, "");
  const malformed = runHook("not-json", root);
  assert.equal(malformed.status, 0);
  assert.equal(malformed.stdout, "");
});
