#!/usr/bin/env node

import { cp, mkdir, readFile, rm } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SOURCE = path.join(ROOT, "dist", "codex-swiftui-plugin");
const DESTINATION = path.join(ROOT, "plugins", "swiftui");
const MANIFEST = path.join(SOURCE, ".codex-plugin", "plugin.json");

let plugin;
try {
  plugin = JSON.parse(await readFile(MANIFEST, "utf8"));
} catch (error) {
  throw new Error("Codex plugin is not assembled; run `npm run build:plugins` first.", { cause: error });
}

await rm(DESTINATION, { recursive: true, force: true });
await mkdir(path.dirname(DESTINATION), { recursive: true });
await cp(SOURCE, DESTINATION, { recursive: true });

console.log(`synced marketplace plugin ${plugin.name} ${plugin.version} to ${DESTINATION}`);
