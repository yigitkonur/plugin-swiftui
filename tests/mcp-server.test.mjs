import assert from "node:assert/strict";
import { access, cp, mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DIST = path.join(ROOT, "dist", "codex-swiftui-plugin");
const FAKE = path.join(ROOT, "tests", "fixtures", "fake-swiftui-ctx.mjs");
const TOOL_NAMES = [
  "swiftui_check_deprecated",
  "swiftui_get_recipe",
  "swiftui_get_source",
  "swiftui_list_examples",
  "swiftui_lookup_api",
  "swiftui_search_catalog",
];

function cleanEnv(overrides = {}) {
  return Object.fromEntries(Object.entries({ ...process.env, SWIFTUI_CTX_BIN: FAKE, ...overrides }).filter(([, value]) => value !== undefined));
}

async function connect(pluginRoot = DIST, env = {}) {
  const client = new Client({ name: "swiftui-plugin-tests", version: "1.0.0" });
  const transport = new StdioClientTransport({
    command: "node",
    args: [path.join(pluginRoot, "mcp", "server.mjs")],
    cwd: os.tmpdir(),
    env: cleanEnv(env),
    stderr: "pipe",
  });
  await client.connect(transport);
  return client;
}

test("MCP lists exactly six read-only tools with the intended open-world boundary", async (t) => {
  const client = await connect();
  t.after(() => client.close());
  const listed = await client.listTools();
  assert.deepEqual(listed.tools.map((tool) => tool.name).sort(), TOOL_NAMES);
  for (const tool of listed.tools) {
    assert.equal(tool.annotations?.readOnlyHint, true);
    assert.equal(tool.annotations?.destructiveHint, false);
    assert.equal(tool.annotations?.idempotentHint, true);
    assert.equal(tool.annotations?.openWorldHint, tool.name === "swiftui_get_source");
  }
});

test("MCP lookup preserves defaults and the CLI v1 structured envelope", async (t) => {
  const client = await connect();
  t.after(() => client.close());
  const response = await client.callTool({ name: "swiftui_lookup_api", arguments: { api: " MenuBarExtra ", offline: true } });
  assert.equal(response.isError, false);
  assert.equal(response.structuredContent?.ok, true);
  assert.deepEqual(response.structuredContent?.result.args, ["lookup", "MenuBarExtra", "--platform", "macos", "--limit", "6", "--offline", "--json"]);
});

test("MCP maps CLI not-found envelopes to recoverable tool errors", async (t) => {
  const client = await connect();
  t.after(() => client.close());
  const response = await client.callTool({ name: "swiftui_lookup_api", arguments: { api: "MissingAPI" } });
  assert.equal(response.isError, true);
  assert.equal(response.structuredContent?.error.code, "UNKNOWN_API");
  assert.match(response.content[0].text, /search MissingAPI/);
});

test("MCP rejects invalid schema inputs", async (t) => {
  const client = await connect();
  t.after(() => client.close());
  const response = await client.callTool({ name: "swiftui_lookup_api", arguments: { api: "MenuBarExtra", limit: 26 } });
  assert.equal(response.isError, true);
  assert.match(response.content[0].text, /limit/i);
});

test("MCP cancellation terminates the CLI process group", async (t) => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "swiftui-mcp-cancel-"));
  const marker = path.join(temporary, "terminated");
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const client = await connect(DIST, { FAKE_SIGNAL_FILE: marker });
  t.after(() => client.close());
  const controller = new AbortController();
  const request = client.callTool(
    { name: "swiftui_lookup_api", arguments: { api: "SlowAPI" } },
    undefined,
    { signal: controller.signal, timeout: 5_000 },
  );
  setTimeout(() => controller.abort(), 200);
  await assert.rejects(request, /abort/i);
  for (let attempt = 0; attempt < 20; attempt += 1) {
    try {
      await access(marker);
      return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
  }
  assert.fail("fake CLI did not receive SIGTERM after cancellation");
});

test("MCP root resolution works from an installed path containing spaces", async (t) => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), "swiftui plugin "));
  const installed = path.join(temporary, "Codex SwiftUI");
  await cp(DIST, installed, { recursive: true });
  t.after(() => rm(temporary, { recursive: true, force: true }));
  const client = await connect(installed);
  t.after(() => client.close());
  const response = await client.callTool({ name: "swiftui_get_recipe", arguments: {} });
  assert.equal(response.isError, false);
  assert.equal(response.structuredContent?.result.command, "recipes");
});
