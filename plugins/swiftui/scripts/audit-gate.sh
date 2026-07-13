#!/usr/bin/env bash
# audit-gate.sh — the toolkit's PRE-SHIP GATE (mechanical LOCATE-tier, CI-friendly).
#
# Loops the ONE shared lint runner (swiftui-lint.sh) over ALL 28 audit-swiftui-* skills against a
# target directory, tallies hard/warn/adv per skill + grand total, prints a per-skill + total summary
# to stderr, emits one combined JSON to stdout, and EXITS 2 if ANY skill reports a hard finding (else 0).
#
# This is the mechanical gate: a hard finding here means a human-driven full audit
# (skills/audit-macos-swiftui-full) is required before shipping. It LOCATES only — it never decides a
# finding is real (an LLM agent READs each hit in the full audit). It does NOT reimplement the lint; it
# reuses swiftui-lint.sh.
#
# Usage:
#   bash scripts/audit-gate.sh [--strict|--advisory] <target-dir>
#   bash scripts/audit-gate.sh <target-dir> > gate.json
#
# Make it executable once:  chmod +x scripts/audit-gate.sh
#
# Exit: 2 if any skill has a hard finding (CI block); 0 otherwise. (Matches the house lint contract.)
set -uo pipefail

# ---- resolve the plugin root (this script lives at ${PLUGIN}/scripts/, same as swiftui-lint.sh) ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINT="$SCRIPT_DIR/swiftui-lint.sh"

MODE="auto"
TARGET="."
while [ "$#" -gt 0 ]; do
  case "$1" in
    --strict) MODE="strict"; shift ;;
    --advisory) MODE="advisory"; shift ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    -*) echo "audit-gate: unknown option: $1" >&2; exit 64 ;;
    *) TARGET="$1"; shift ;;
  esac
done
if [ ! -e "$TARGET" ]; then
  echo "audit-gate: target not found: $TARGET" >&2; exit 64
fi
if [ ! -x "$LINT" ] && [ ! -f "$LINT" ]; then
  echo "audit-gate: shared runner not found: $LINT" >&2; exit 64
fi
command -v jq >/dev/null 2>&1 || { echo "audit-gate: jq is required (brew install jq)." >&2; exit 69; }

# Default to strict. In auto mode, the neutral project setting can make hard findings advisory;
# the legacy Claude settings file remains a temporary fallback.
STRICT=1
if [ "$MODE" = "advisory" ]; then
  STRICT=0
elif [ "$MODE" = "auto" ]; then
  TARGET_ABS="$(cd "$TARGET" 2>/dev/null && pwd || printf '%s' "$TARGET")"
  PROJECT_ROOT="$(git -C "$TARGET_ABS" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$TARGET_ABS")"
  SETTINGS=""
  [ -f "$PROJECT_ROOT/.swiftui-plugin/settings.md" ] && SETTINGS="$PROJECT_ROOT/.swiftui-plugin/settings.md"
  [ -z "$SETTINGS" ] && [ -f "$PROJECT_ROOT/.claude/swiftui.local.md" ] && SETTINGS="$PROJECT_ROOT/.claude/swiftui.local.md"
  if [ -n "$SETTINGS" ]; then
    STRICT_VALUE="$(sed -n '/^---$/,/^---$/{ /^strict_audit:[[:space:]]*/{ s/^strict_audit:[[:space:]]*//; s/^"\(.*\)"$/\1/; p; }; }' "$SETTINGS" | head -1)"
    [ "$STRICT_VALUE" = "false" ] && STRICT=0
  fi
fi

# ---- discover all 28 audit skills (skills with a lint/ dir) -----------------------------------------
SKILLS=()
for d in "$PLUGIN_ROOT"/skills/audit-swiftui-*; do
  [ -d "$d/lint" ] || continue
  SKILLS+=("$(basename "$d")")
done
if [ "${#SKILLS[@]}" -eq 0 ]; then
  echo "audit-gate: no audit-swiftui-* skills with a lint/ dir under $PLUGIN_ROOT/skills" >&2; exit 64
fi

printf '== audit-gate: %d skills over %s ==\n' "${#SKILLS[@]}" "$TARGET" >&2

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

T_HARD=0; T_WARN=0; T_ADV=0; ANY_HARD=0
PER_SKILL_JSON=()

for skill in "${SKILLS[@]}"; do
  out="$TMP/$skill.json"
  # Reuse the shared runner; --quiet so only OUR summary hits stderr. It exits 2 on a hard hit — that
  # is expected and tallied, so don't let `set -e`-style propagation abort the loop.
  bash "$LINT" --skill "$skill" --dir "$TARGET" --json "$out" --quiet >/dev/null 2>&1 || true
  if [ ! -s "$out" ]; then
    printf '{"domain":"%s","error":"no-output","counts":{"hard":0,"warn":0,"adv":0,"total":0}}' "$skill" > "$out"
  fi
  hard=$(jq -r '.counts.hard // 0' "$out"); warn=$(jq -r '.counts.warn // 0' "$out"); adv=$(jq -r '.counts.adv // 0' "$out")
  T_HARD=$((T_HARD+hard)); T_WARN=$((T_WARN+warn)); T_ADV=$((T_ADV+adv))
  [ "$hard" -gt 0 ] && ANY_HARD=1
  flag=""; [ "$hard" -gt 0 ] && flag="  <-- HARD"
  printf '  %-34s hard=%-3s warn=%-3s adv=%-3s%s\n' "$skill" "$hard" "$warn" "$adv" "$flag" >&2
  PER_SKILL_JSON+=("$(jq -c '{domain: (.domain // "?"), hard: (.counts.hard // 0), warn: (.counts.warn // 0), adv: (.counts.adv // 0), total: (.counts.total // 0), parse_warnings: (.parse_warnings // 0)}' "$out")")
done

printf -- '-----------------------------------------------------------------\n' >&2
printf '  TOTAL  hard=%s  warn=%s  adv=%s  (skills=%d)\n' "$T_HARD" "$T_WARN" "$T_ADV" "${#SKILLS[@]}" >&2
if [ "$ANY_HARD" -eq 1 ] && [ "$STRICT" -eq 1 ]; then
  printf '== GATE: FAIL (hard findings present) — full audit required before ship ==\n' >&2
elif [ "$ANY_HARD" -eq 1 ]; then
  printf '== GATE: ADVISORY (hard findings present; strict_audit is false) ==\n' >&2
else
  printf '== GATE: PASS (no hard findings) ==\n' >&2
fi

# ---- combined JSON → stdout ------------------------------------------------------------------------
printf '%s\n' "${PER_SKILL_JSON[@]}" | jq -s \
  --arg target "$TARGET" \
  --argjson hard "$T_HARD" --argjson warn "$T_WARN" --argjson adv "$T_ADV" \
  --argjson nskills "${#SKILLS[@]}" --argjson anyhard "$ANY_HARD" --argjson strict "$STRICT" '
  {
    tool: "audit-gate",
    role: "pre-ship-locator-gate",
    note: (if $strict==1 then "Mechanical LOCATE-tier tally. Hard findings block in strict mode; a full audit must READ each hit." else "Mechanical LOCATE-tier tally. Hard findings are advisory because strict_audit is false; a full audit must still READ each hit." end),
    target: $target,
    skills_run: $nskills,
    strict: ($strict==1),
    gate: (if $anyhard==1 and $strict==1 then "fail" elif $anyhard==1 then "advisory" else "pass" end),
    totals: { hard: $hard, warn: $warn, adv: $adv },
    per_skill: .
  }'

[ "$ANY_HARD" -eq 1 ] && [ "$STRICT" -eq 1 ] && exit 2
exit 0
