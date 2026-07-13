#!/usr/bin/env node

import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PLUGIN_SOURCE = path.join(ROOT, "dist", "codex-swiftui-plugin");
const MARKETPLACE_ROOT = path.join(ROOT, "dist", "codex-dev-marketplace");
const PLUGIN_DESTINATION = path.join(MARKETPLACE_ROOT, "plugins", "swiftui");
const MANIFEST = path.join(PLUGIN_SOURCE, ".codex-plugin", "plugin.json");

let plugin;
try {
  plugin = JSON.parse(await readFile(MANIFEST, "utf8"));
} catch (error) {
  throw new Error("Codex plugin is not assembled; run `npm run build:plugins` first.", { cause: error });
}

await rm(MARKETPLACE_ROOT, { recursive: true, force: true });
await mkdir(path.join(MARKETPLACE_ROOT, ".agents", "plugins"), { recursive: true });
await mkdir(path.dirname(PLUGIN_DESTINATION), { recursive: true });
await cp(PLUGIN_SOURCE, PLUGIN_DESTINATION, { recursive: true });

const marketplace = {
  name: "swiftui-local",
  interface: { displayName: "SwiftUI Local Development" },
  plugins: [{
    name: "swiftui",
    source: { source: "local", path: "./plugins/swiftui" },
    policy: { installation: "AVAILABLE", authentication: "ON_INSTALL" },
    category: "Developer Tools",
  }],
};

await writeFile(
  path.join(MARKETPLACE_ROOT, ".agents", "plugins", "marketplace.json"),
  `${JSON.stringify(marketplace, null, 2)}\n`,
);

console.log(`assembled local Codex marketplace for swiftui ${plugin.version} at ${MARKETPLACE_ROOT}`);
