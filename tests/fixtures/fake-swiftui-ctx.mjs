#!/usr/bin/env node

import { writeFileSync } from "node:fs";

const args = process.argv.slice(2);
if (args.includes("--version")) {
  console.log("1.4.0");
  process.exit(0);
}

const command = args[0] ?? "";
const query = args[1] ?? "";
if (command === "lookup" && query === "SlowAPI") {
  process.on("SIGTERM", () => {
    if (process.env.FAKE_SIGNAL_FILE) writeFileSync(process.env.FAKE_SIGNAL_FILE, "terminated");
    process.exit(143);
  });
  setTimeout(() => process.exit(1), 30_000);
  await new Promise(() => {});
}
if (command === "lookup" && query === "MissingAPI") {
  console.log(JSON.stringify({
    ok: false,
    schema_version: "v1",
    result: null,
    next_actions: [],
    error: {
      class: "not_found",
      code: "UNKNOWN_API",
      message: "no usage found for MissingAPI",
      retryable: false,
      suggestion: "run swiftui-ctx search MissingAPI",
    },
  }));
  process.exit(3);
}

console.log(JSON.stringify({
  ok: true,
  schema_version: "v1",
  result: { command, args },
  next_actions: [{ cmd: "swiftui-ctx doctor", why: "fixture follow-up" }],
  error: null,
}));
