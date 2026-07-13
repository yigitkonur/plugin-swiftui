#!/usr/bin/env node

import { cp, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DIST = path.join(ROOT, "dist");
const CODEX_SOURCE = path.join(ROOT, "packages", "codex-plugin", "plugin");
const COMMON_PATHS = [
  "bin",
  "catalog",
  "CLI.md",
  "LICENSE",
  "references",
  "skills",
  "swiftui-scan",
  "VERSION",
];
const RUNTIME_SCRIPTS = [
  "audit-gate.sh",
  "audit-scan.py",
  "audit-signals.tsv",
  "macos-swiftui-lint.sh",
  "sosumi.sh",
  "swiftui-ctx",
  "swiftui-lint.sh",
];
const ROOT_NOTE = `\n## Bundled resource root\n\nLet \`<swiftui-plugin-root>\` be the absolute plugin directory two levels above this \`SKILL.md\`. Resolve that path before running commands or opening shared references. When these instructions say \`swiftui-ctx\`, invoke \`<swiftui-plugin-root>/scripts/swiftui-ctx\`; do not assume the command is on \`PATH\`.\n`;

function shouldCopy(source) {
  const base = path.basename(source);
  return ![".build", ".DS_Store", "__pycache__", "node_modules"].includes(base)
    && !base.endsWith(".pyc");
}

async function copyInto(source, destination) {
  await cp(source, destination, { recursive: true, filter: shouldCopy });
}

async function copyCommon(destination) {
  for (const relative of COMMON_PATHS) {
    await copyInto(path.join(ROOT, relative), path.join(destination, relative));
  }
  await mkdir(path.join(destination, "scripts"), { recursive: true });
  for (const script of RUNTIME_SCRIPTS) {
    await copyInto(path.join(ROOT, "scripts", script), path.join(destination, "scripts", script));
  }
}

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const paths = [];
  for (const entry of entries) {
    const current = path.join(directory, entry.name);
    if (entry.isDirectory()) paths.push(...await walk(current));
    else paths.push(current);
  }
  return paths;
}

function addRootNote(text) {
  if (text.includes("## Bundled resource root")) return text;
  const match = text.match(/^---\n[\s\S]*?\n---\n/);
  if (!match) return text;
  return `${match[0]}${ROOT_NOTE}${text.slice(match[0].length)}`;
}

function conciseSkillDescription(name) {
  if (name === "audit-macos-swiftui-full") return "Orchestrate a complete macOS SwiftUI audit across all relevant domains, then aggregate evidence-backed findings and a nativeness score.";
  if (name.startsWith("audit-swiftui-")) {
    const domain = name.slice("audit-swiftui-".length).replaceAll("-", " ");
    return `Audit macOS SwiftUI ${domain} for correctness, current APIs, and production conventions. Use for that domain or as part of a full audit.`;
  }
  if (name === "build-macos-swiftui") return "Build or revise a production macOS SwiftUI app using native scenes, state, commands, settings, and current platform conventions.";
  if (name === "macos-app-patterns") return "Find production patterns for complete macOS SwiftUI features such as menu bar apps, settings, windows, and AppKit bridges.";
  if (name === "swiftui-examples") return "Ground SwiftUI code in ranked examples from shipping macOS apps before choosing APIs, argument shapes, or implementation patterns.";
  if (name === "swiftui-modernize") return "Modernize existing macOS SwiftUI code by replacing deprecated APIs with verified current production patterns.";
  return "Use this bundled SwiftUI workflow when its named macOS development domain applies.";
}

function normalizeCodexFrontmatter(text) {
  const match = text.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) return text;
  let lines = match[1].split("\n");
  const compatibility = lines.find((line) => line.startsWith("compatibility:"));
  lines = lines.filter((line) => !line.startsWith("compatibility:"));
  const name = lines.find((line) => line.startsWith("name:"))?.slice("name:".length).trim() ?? "";
  lines = lines.map((line) => line.startsWith("description:") && line.length > 280
    ? `description: ${conciseSkillDescription(name)}`
    : line);
  const suffix = compatibility
    ? `\nCompatibility: ${compatibility.slice("compatibility:".length).trim()}\n`
    : "";
  return `---\n${lines.join("\n")}\n---\n${suffix}${text.slice(match[0].length)}`;
}

async function adaptCodexMarkdown(destination) {
  const roots = [path.join(destination, "skills"), path.join(destination, "references")];
  for (const root of roots) {
    for (const file of await walk(root)) {
      if (!file.endsWith(".md")) continue;
      let text = await readFile(file, "utf8");
      text = text
        .replace(/\$\{CLAUDE_PLUGIN_ROOT(?::-[^}]*)?\}/g, "<swiftui-plugin-root>")
        .replaceAll("$CLAUDE_PLUGIN_ROOT", "<swiftui-plugin-root>");
      if (path.basename(file) === "SKILL.md") {
        text = normalizeCodexFrontmatter(text);
        text = addRootNote(text);
      }
      await writeFile(file, text);
    }
  }
}

async function readVersion() {
  return (await readFile(path.join(ROOT, "VERSION"), "utf8")).trim();
}

async function assertVersion(file, version) {
  const parsed = JSON.parse(await readFile(file, "utf8"));
  if (parsed.version !== version) {
    throw new Error(`${path.relative(ROOT, file)} has version ${parsed.version}; expected ${version}`);
  }
}

async function buildClaude(version) {
  const destination = path.join(DIST, "claude-swiftui-plugin");
  await mkdir(destination, { recursive: true });
  await copyCommon(destination);
  for (const relative of ["agents", "commands", "hooks", "README.md"]) {
    await copyInto(path.join(ROOT, relative), path.join(destination, relative));
  }
  await mkdir(path.join(destination, ".claude-plugin"), { recursive: true });
  await copyInto(path.join(ROOT, ".claude-plugin", "plugin.json"), path.join(destination, ".claude-plugin", "plugin.json"));
  await copyInto(path.join(ROOT, "packages", "claude-plugin", "package.json"), path.join(destination, "package.json"));
  await assertVersion(path.join(destination, "package.json"), version);
  await assertVersion(path.join(destination, ".claude-plugin", "plugin.json"), version);
}

async function buildCodex(version) {
  const destination = path.join(DIST, "codex-swiftui-plugin");
  await mkdir(destination, { recursive: true });
  await copyCommon(destination);
  await copyInto(path.join(ROOT, "hooks"), path.join(destination, "hooks"));
  await copyInto(CODEX_SOURCE, destination);
  await copyInto(path.join(ROOT, "packages", "codex-plugin", "package.json"), path.join(destination, "package.json"));
  await adaptCodexMarkdown(destination);
  await mkdir(path.join(destination, "mcp"), { recursive: true });
  await build({
    entryPoints: [path.join(ROOT, "packages", "codex-plugin", "mcp", "server.ts")],
    outfile: path.join(destination, "mcp", "server.mjs"),
    bundle: true,
    platform: "node",
    format: "esm",
    target: "node18",
    define: { SWIFTUI_PLUGIN_VERSION: JSON.stringify(version) },
    legalComments: "none",
  });
  await assertVersion(path.join(destination, "package.json"), version);
  await assertVersion(path.join(destination, ".codex-plugin", "plugin.json"), version);
}

const version = await readVersion();
await rm(DIST, { recursive: true, force: true });
await mkdir(DIST, { recursive: true });
await buildClaude(version);
await buildCodex(version);
console.log(`assembled Claude and Codex plugin packages at version ${version}`);
