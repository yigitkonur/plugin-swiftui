import { spawnSync } from "node:child_process";
import { cp, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const temporary = await mkdtemp(path.join(os.tmpdir(), "swiftui-codex-install-"));
const marketplaceRoot = path.join(temporary, "marketplace");
const pluginRoot = path.join(marketplaceRoot, "plugins", "swiftui");
const codexHome = path.join(temporary, "codex-home");

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
  await mkdir(path.join(marketplaceRoot, ".agents", "plugins"), { recursive: true });
  await cp(path.join(ROOT, "dist", "codex-swiftui-plugin"), pluginRoot, { recursive: true });
  await writeFile(path.join(marketplaceRoot, ".agents", "plugins", "marketplace.json"), JSON.stringify({
    name: "swiftui-smoke",
    interface: { displayName: "SwiftUI Smoke" },
    plugins: [{
      name: "swiftui",
      source: { source: "local", path: "./plugins/swiftui" },
      policy: { installation: "AVAILABLE", authentication: "ON_INSTALL" },
      category: "Developer Tools",
    }],
  }, null, 2));
  await mkdir(codexHome, { recursive: true });
  codex(["plugin", "marketplace", "add", marketplaceRoot, "--json"]);
  codex(["plugin", "add", "swiftui@swiftui-smoke", "--json"]);
  const installed = JSON.parse(codex(["plugin", "list", "--json"]));
  const serialized = JSON.stringify(installed);
  if (!serialized.includes("swiftui") || !serialized.includes("1.4.0")) {
    throw new Error(`installed plugin was not reported by codex plugin list: ${serialized}`);
  }
  const mcpServers = codex(["mcp", "list", "--json"]);
  if (!mcpServers.includes("swiftui")) {
    throw new Error(`installed plugin MCP server was not registered: ${mcpServers}`);
  }
  console.log("Codex isolated install smoke passed for swiftui 1.4.0");
} finally {
  await rm(temporary, { recursive: true, force: true });
}
