#!/usr/bin/env bash
# eval/run.sh — populate eval/out/<id>/{baseline,grounded}.swift for the proof-of-value eval.
#
# Two conditions per task: BASELINE (prompt only) vs GROUNDED (prompt + injected `swiftui-ctx` output).
# Generator is pluggable via $EVAL_GEN_CMD — a command that reads a prompt on stdin and writes Swift to
# stdout (e.g. EVAL_GEN_CMD='codex exec -' or a wrapper around any model). If $EVAL_GEN_CMD is unset,
# we fall back to the committed eval/seeds/<id>/ pairs so `make eval` always produces a real RESULTS.md.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
CTX="$ROOT/scripts/swiftui-ctx"
export SWIFTUI_CTX_CATALOG="${SWIFTUI_CTX_CATALOG:-$ROOT/catalog}"
OUT="$HERE/out"; SEEDS="$HERE/seeds"
GEN="${EVAL_GEN_CMD:-}"

strip_fences() { python3 -c 'import sys,re; t=sys.stdin.read(); m=re.search(r"```(?:swift)?\n(.*?)```",t,re.S); sys.stdout.write(m.group(1) if m else t)'; }

if [ -z "$GEN" ]; then
  echo "eval: EVAL_GEN_CMD unset — scoring committed seeds (set EVAL_GEN_CMD='codex exec -' for a live model run)." >&2
  rm -rf "$OUT"; mkdir -p "$OUT"
  if [ -d "$SEEDS" ]; then cp -R "$SEEDS"/. "$OUT"/ 2>/dev/null || true; fi
  exit 0
fi

echo "eval: generating with EVAL_GEN_CMD=$GEN" >&2
rm -rf "$OUT"; mkdir -p "$OUT"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  id=$(printf '%s' "$line" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
  prompt=$(printf '%s' "$line" | python3 -c 'import json,sys;print(json.load(sys.stdin)["prompt"])')
  gcmd=$(printf '%s' "$line" | python3 -c 'import json,sys;print(json.load(sys.stdin)["ground_cmd"])')
  mkdir -p "$OUT/$id"
  # BASELINE: prompt only
  printf '%s\n' "$prompt" | $GEN | strip_fences > "$OUT/$id/baseline.swift"
  # GROUNDED: prompt + real production usage from the catalog
  eg=$("$CTX" $gcmd 2>/dev/null || true)
  printf '%s\n\n# Real production usage from shipping macOS apps (ground truth — follow this idiom):\n%s\n' "$prompt" "$eg" \
    | $GEN | strip_fences > "$OUT/$id/grounded.swift"
  echo "  generated: $id" >&2
done < "$HERE/tasks.jsonl"
