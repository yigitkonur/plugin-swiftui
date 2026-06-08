#!/usr/bin/env bash
# audit-selftest.sh — regression guard for the audit lint engine.
# For each tests/fixtures/<domain>.swift (a file with KNOWN violations) + its <domain>.expect
# (the rule_ids that MUST fire), run swiftui-lint.sh --skill audit-swiftui-<domain> and assert
# every expected rule_id appears. Catches regex/YAML rule rot that would otherwise pass CI silently.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$ROOT"
FIX="$ROOT/tests/fixtures"
ENGINE="$ROOT/scripts/swiftui-lint.sh"

fail=0; checks=0; files=0
for sw in "$FIX"/*.swift; do
  base="$(basename "$sw" .swift)"
  exp="$FIX/$base.expect"
  [ -f "$exp" ] || continue
  files=$((files+1))
  # swiftui-lint exits 2 on hard findings — swallow it; we only read the JSON on stdout.
  got="$(bash "$ENGINE" --skill "audit-swiftui-$base" --quiet "$sw" 2>/dev/null || true)"
  ids="$(printf '%s' "$got" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: print(""); sys.exit()
print(" ".join(sorted({f.get("rule_id","") for f in d.get("findings",[])})))' )"
  while read -r id; do
    case "$id" in ''|\#*) continue;; esac
    checks=$((checks+1))
    case " $ids " in
      *" $id "*) ;;
      *) echo "FAIL [$base] expected rule '$id' did not fire. got: ${ids:-<none>}"; fail=1;;
    esac
  done < "$exp"
done

if [ "$files" -eq 0 ]; then echo "audit-selftest: no fixtures found" >&2; exit 1; fi
if [ "$fail" -eq 0 ]; then
  echo "audit-selftest: $checks expected rules fired across $files fixtures ✓"
else
  echo "audit-selftest: FAILURES (a lint rule regressed — see above)" >&2; exit 1
fi
