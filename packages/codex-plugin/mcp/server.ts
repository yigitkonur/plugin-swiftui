#!/usr/bin/env node

import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

declare const SWIFTUI_PLUGIN_VERSION: string;

type Envelope = {
  ok: boolean;
  schema_version: "v1";
  result: unknown;
  next_actions: Array<{ cmd: string; why: string }>;
  error: null | {
    class: string;
    code: string;
    message: string;
    retryable: boolean;
    suggestion: string | null;
  };
};

const PLUGIN_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CLI = path.join(PLUGIN_ROOT, "scripts", "swiftui-ctx");
const CATALOG = path.join(PLUGIN_ROOT, "catalog");
const MAX_OUTPUT_BYTES = 16 * 1024 * 1024;
const MAX_STDERR_BYTES = 64 * 1024;
const CLI_TIMEOUT_MS = 5 * 60 * 1000;
const activeChildren = new Set<ReturnType<typeof spawn>>();

const envelopeOutputSchema = {
  ok: z.boolean(),
  schema_version: z.literal("v1"),
  result: z.unknown().nullable(),
  next_actions: z.array(z.object({ cmd: z.string(), why: z.string() })),
  error: z.object({
    class: z.string(),
    code: z.string(),
    message: z.string(),
    retryable: z.boolean(),
    suggestion: z.string().nullable(),
  }).nullable(),
};

const platform = z.enum(["macos", "any"]).default("macos").describe("Platform filter; defaults to macOS");
const limit = z.number().int().min(1).max(25).default(6).describe("Maximum number of results, from 1 to 25");
const offline = z.boolean().default(false).describe("Use only the bundled catalog and make no live source request");

function globalArgs(values: { platform?: "macos" | "any"; limit?: number; offline?: boolean }): string[] {
  const args = ["--platform", values.platform ?? "macos", "--limit", String(values.limit ?? 6)];
  if (values.offline) args.push("--offline");
  return args;
}

function isEnvelope(value: unknown): value is Envelope {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Partial<Envelope>;
  return typeof candidate.ok === "boolean"
    && candidate.schema_version === "v1"
    && Array.isArray(candidate.next_actions)
    && Object.prototype.hasOwnProperty.call(candidate, "result")
    && Object.prototype.hasOwnProperty.call(candidate, "error");
}

function executionError(
  code: string,
  message: string,
  suggestion: string | null = null,
  retryable = false,
): Envelope {
  return {
    ok: false,
    schema_version: "v1",
    result: null,
    next_actions: [],
    error: { class: "execution", code, message, retryable, suggestion },
  };
}

async function runCli(args: string[], signal: AbortSignal): Promise<Envelope> {
  if (signal.aborted) return executionError("CANCELLED", "The SwiftUI catalog query was cancelled.");
  return await new Promise((resolve) => {
    const child = spawn("/bin/bash", [CLI, ...args, "--json"], {
      cwd: PLUGIN_ROOT,
      env: { ...process.env, SWIFTUI_CTX_CATALOG: CATALOG },
      stdio: ["ignore", "pipe", "pipe"],
      detached: true,
    });
    activeChildren.add(child);
    const stdout: Buffer[] = [];
    let stderrTail = Buffer.alloc(0);
    let stdoutSize = 0;
    let overflow = false;
    let timedOut = false;
    let settled = false;
    let forceKill: NodeJS.Timeout | undefined;

    const terminate = (signalName: NodeJS.Signals) => {
      if (!child.pid) return;
      try {
        process.kill(-child.pid, signalName);
      } catch {
        child.kill(signalName);
      }
    };
    const finish = (envelope: Envelope) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      if (forceKill) clearTimeout(forceKill);
      signal.removeEventListener("abort", abort);
      activeChildren.delete(child);
      resolve(envelope);
    };
    const stopGracefully = () => {
      terminate("SIGTERM");
      forceKill = setTimeout(() => terminate("SIGKILL"), 2_000);
      forceKill.unref();
    };
    const abort = () => stopGracefully();
    const timeout = setTimeout(() => {
      timedOut = true;
      stopGracefully();
    }, CLI_TIMEOUT_MS);
    timeout.unref();

    child.stdout.on("data", (chunk: Buffer) => {
      stdoutSize += chunk.length;
      if (stdoutSize > MAX_OUTPUT_BYTES) {
        overflow = true;
        stopGracefully();
        return;
      }
      stdout.push(chunk);
    });
    child.stderr.on("data", (chunk: Buffer) => {
      stderrTail = Buffer.concat([stderrTail, chunk]);
      if (stderrTail.length > MAX_STDERR_BYTES) stderrTail = stderrTail.subarray(-MAX_STDERR_BYTES);
    });

    signal.addEventListener("abort", abort, { once: true });
    child.on("error", (error) => {
      finish(executionError("CLI_START_FAILED", error.message, "Run swiftui-ctx doctor to verify the bundled CLI."));
    });
    child.on("close", (code, terminatedBySignal) => {
      if (signal.aborted) {
        finish(executionError("CANCELLED", "The SwiftUI catalog query was cancelled."));
        return;
      }
      if (timedOut) {
        finish(executionError("CLI_TIMEOUT", "swiftui-ctx exceeded the five-minute execution limit.", "Retry after the first-run binary cache is available.", true));
        return;
      }
      if (overflow) {
        finish(executionError("OUTPUT_LIMIT", "swiftui-ctx exceeded the 16 MiB MCP output limit.", "Use a smaller limit or a narrower source span."));
        return;
      }
      const output = Buffer.concat(stdout).toString("utf8").trim();
      try {
        const parsed: unknown = JSON.parse(output);
        if (isEnvelope(parsed)) {
          if ((code === 0) !== parsed.ok) {
            finish(executionError("CLI_STATUS_MISMATCH", `swiftui-ctx exit ${code} disagreed with its v1 envelope.`));
            return;
          }
          finish(parsed);
          return;
        }
      } catch {
        // Return the normalized diagnostic below.
      }
      const diagnostic = stderrTail.toString("utf8").trim();
      finish(executionError(
        "INVALID_CLI_OUTPUT",
        `swiftui-ctx exited ${code ?? terminatedBySignal ?? "without a status"} without a valid v1 JSON envelope.${diagnostic ? ` ${diagnostic}` : ""}`,
        "Run swiftui-ctx doctor to verify the catalog and binary.",
      ));
    });
  });
}

function renderEnvelope(envelope: Envelope): string {
  if (!envelope.ok) {
    const error = envelope.error;
    return error
      ? `${error.code}: ${error.message}${error.suggestion ? `\nTry: ${error.suggestion}` : ""}`
      : "The SwiftUI catalog query failed without an error payload.";
  }
  const next = envelope.next_actions.length
    ? `\n\nNext actions:\n${envelope.next_actions.map((action) => `- ${action.cmd} — ${action.why}`).join("\n")}`
    : "";
  return `${JSON.stringify(envelope.result, null, 2)}${next}`;
}

function result(envelope: Envelope) {
  return {
    content: [{ type: "text" as const, text: renderEnvelope(envelope) }],
    structuredContent: envelope as unknown as Record<string, unknown>,
    isError: !envelope.ok,
  };
}

const server = new McpServer(
  { name: "swiftui-production-intelligence", version: SWIFTUI_PLUGIN_VERSION },
  { instructions: "Read-only production SwiftUI evidence from the bundled swiftui-ctx catalog." },
);

const localAnnotations = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
};

server.registerTool("swiftui_lookup_api", {
  title: "Look up a SwiftUI API",
  description: "Look up a SwiftUI API in 1,857 production macOS apps. Returns consensus argument shapes, ranked examples, deprecation data, and follow-up commands.",
  inputSchema: {
    api: z.string().trim().min(1).max(200).describe("SwiftUI API name or intent"),
    platform,
    limit,
    offline,
  },
  outputSchema: envelopeOutputSchema,
  annotations: localAnnotations,
}, async ({ api, ...options }, extra) => result(await runCli(["lookup", api, ...globalArgs(options)], extra.signal)));

server.registerTool("swiftui_search_catalog", {
  title: "Search the SwiftUI catalog",
  description: "Search production SwiftUI APIs and recipes by design intent or keyword. Use when an exact API lookup has no result.",
  inputSchema: {
    query: z.string().trim().min(1).max(300).describe("Keyword or interface intent"),
    platform,
    limit,
    offline,
  },
  outputSchema: envelopeOutputSchema,
  annotations: localAnnotations,
}, async ({ query, ...options }, extra) => result(await runCli(["search", query, ...globalArgs(options)], extra.signal)));

server.registerTool("swiftui_list_examples", {
  title: "List production SwiftUI examples",
  description: "List ranked, paginated production call sites for a SwiftUI API, optionally filtered by argument shape or repository.",
  inputSchema: {
    api: z.string().trim().min(1).max(200).describe("SwiftUI API name"),
    shape: z.string().trim().min(1).max(300).optional().describe("Exact argument shape filter"),
    repo: z.string().trim().min(1).max(200).optional().describe("Repository filter in owner/name form"),
    page: z.number().int().min(1).default(1).describe("One-based result page"),
    platform,
    limit,
    offline,
  },
  outputSchema: envelopeOutputSchema,
  annotations: localAnnotations,
}, async ({ api, shape, repo, page, ...options }, extra) => {
  const args = ["examples", api];
  if (shape) args.push("--shape", shape);
  if (repo) args.push("--repo", repo);
  args.push("--page", String(page), ...globalArgs(options));
  return result(await runCli(args, extra.signal));
});

server.registerTool("swiftui_get_source", {
  title: "Get a production SwiftUI source example",
  description: "Fetch the real source surrounding a catalog example ID or GitHub permalink, using a smart declaration, modifier chain, or full-file span.",
  inputSchema: {
    idOrPermalink: z.string().trim().min(1).max(1000).describe("Example ID from catalog output or GitHub blob permalink"),
    span: z.enum(["smart", "decl", "chain", "full"]).default("smart").describe("Source span to return"),
  },
  outputSchema: envelopeOutputSchema,
  annotations: { ...localAnnotations, openWorldHint: true },
}, async ({ idOrPermalink, span }, extra) => result(await runCli(["file", idOrPermalink, `--${span}`], extra.signal)));

server.registerTool("swiftui_get_recipe", {
  title: "Get a SwiftUI production recipe",
  description: "List available production SwiftUI recipes or return one named multi-API pattern with a template and real examples.",
  inputSchema: {
    name: z.string().trim().min(1).max(200).optional().describe("Recipe name; omit to list recipes"),
  },
  outputSchema: envelopeOutputSchema,
  annotations: localAnnotations,
}, async ({ name }, extra) => result(await runCli(name ? ["recipe", name] : ["recipes"], extra.signal)));

server.registerTool("swiftui_check_deprecated", {
  title: "Check deprecated SwiftUI APIs",
  description: "Check one SwiftUI API for deprecation and its replacement, or list deprecated forms found in production code.",
  inputSchema: {
    api: z.string().trim().min(1).max(200).optional().describe("SwiftUI API to check; omit to list deprecated forms"),
  },
  outputSchema: envelopeOutputSchema,
  annotations: localAnnotations,
}, async ({ api }, extra) => result(await runCli(api ? ["deprecated", api] : ["deprecated"], extra.signal)));

const transport = new StdioServerTransport();
await server.connect(transport);

let shuttingDown = false;
async function shutdown(): Promise<void> {
  if (shuttingDown) return;
  shuttingDown = true;
  for (const child of activeChildren) {
    if (!child.pid) continue;
    try {
      process.kill(-child.pid, "SIGTERM");
    } catch {
      child.kill("SIGTERM");
    }
  }
  await new Promise((resolve) => setTimeout(resolve, 250));
  for (const child of activeChildren) {
    if (!child.pid) continue;
    try {
      process.kill(-child.pid, "SIGKILL");
    } catch {
      child.kill("SIGKILL");
    }
  }
  await server.close();
}

process.once("SIGINT", () => void shutdown().finally(() => process.exit(0)));
process.once("SIGTERM", () => void shutdown().finally(() => process.exit(0)));
