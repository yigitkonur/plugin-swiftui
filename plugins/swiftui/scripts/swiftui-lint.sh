#!/usr/bin/env bash
# swiftui-lint.sh — the toolkit's ONE shared hybrid lint runner (a LOCATOR, never the judge).
#
# Every audit skill feeds DECLARATIVE rule files into this engine; the engine locates candidate
# code lines and emits unified JSON + SARIF. An LLM agent then READS each hit and decides — the
# engine never reports a finding as fact.
#
# Usage:
#   swiftui-lint.sh --skill <skill-name> [--dir <path>|file...] [--json out.json] [--sarif out.sarif]
#   swiftui-lint.sh --rules <lint-dir>   [--dir <path>|file...] ...
#
#   --skill NAME   discover rules at  ${PLUGIN}/skills/<NAME>/lint/   (grep-tells.tsv + ast-grep/*.yml)
#   --rules DIR    use an explicit lint dir (same layout) instead of --skill
#   --dir PATH     scan a directory (recursively, *.swift); may be repeated; bare file args also work
#   --json FILE    write JSON report to FILE  (default: stdout)
#   --sarif FILE   write SARIF 2.1.0 to FILE  (default: not written unless requested)
#   --no-ast       force grep-only (proves graceful degradation; also auto-engaged if ast-grep absent)
#   --quiet        suppress the human banner on stderr
#
# Two tiers (hybrid):
#   Tier 1 — grep/ripgrep over  lint/grep-tells.tsv  (flat presence / deprecation strings; robust even
#            on files that don't parse).
#   Tier 2 — ast-grep over      lint/ast-grep/*.yml  (STRUCTURAL rules grep can't express: containment,
#            gate-scope, co-occurrence). Run with ZERO install via `npx --package @ast-grep/cli ast-grep`.
#            Faster: `brew install ast-grep`. If ast-grep is unreachable, the runner degrades to grep-only
#            with an explicit notice and NEVER hard-fails the audit.
#
# Safety rails (ast-grep's one real risk is a silent parse failure → a false negative):
#   (a) grep tier ALWAYS runs (fallback that needs no parse).
#   (b) a per-file PARSE PROBE (ast-grep `kind: ERROR` + a brace/paren-balance heuristic) surfaces
#       "this file did not fully parse" as a WARNING so a missed finding can't masquerade as clean.
#   Pin: tree-sitter-swift >= 0.7.1 (ships inside @ast-grep/cli >= 0.39; verified on 0.43.0).
#
# Exit: 2 if any tier-1 or tier-2 rule of severity `hard` matched; else 0. Warnings/advisories/parse
# warnings never fail the run. (Matches the house lint contract: 0 = clean, 2 = block.)
set -uo pipefail

# ---- resolve the plugin root (this script lives at ${PLUGIN}/scripts/) -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---- args -----------------------------------------------------------------
SKILL=""; RULES_DIR=""; JSON_OUT=""; SARIF_OUT=""; NO_AST=0; QUIET=0
TARGETS=()
val() { [ "$2" -ge 2 ] || { echo "swiftui-lint: $1 requires a value" >&2; exit 64; }; }  # $1=flag $2=remaining argc
while [ "$#" -gt 0 ]; do
  case "$1" in
    --skill)  val "$1" "$#"; SKILL="$2"; shift 2;;
    --rules)  val "$1" "$#"; RULES_DIR="$2"; shift 2;;
    --dir)    val "$1" "$#"; TARGETS+=("$2"); shift 2;;
    --json)   val "$1" "$#"; JSON_OUT="$2"; shift 2;;
    --sarif)  val "$1" "$#"; SARIF_OUT="$2"; shift 2;;
    --no-ast) NO_AST=1; shift;;
    --quiet)  QUIET=1; shift;;
    -h|--help) sed -n '2,40p' "$0"; exit 0;;
    *) TARGETS+=("$1"); shift;;
  esac
done

log() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*" >&2; }

# ---- resolve the lint dir -------------------------------------------------
if [ -z "$RULES_DIR" ] && [ -n "$SKILL" ]; then
  RULES_DIR="$PLUGIN_ROOT/skills/$SKILL/lint"
fi
if [ -z "$RULES_DIR" ]; then
  echo "swiftui-lint: need --skill <name> or --rules <dir>" >&2; exit 64
fi
if [ ! -d "$RULES_DIR" ]; then
  echo "swiftui-lint: lint dir not found: $RULES_DIR" >&2; exit 64
fi
command -v jq >/dev/null 2>&1 || { echo "swiftui-lint: jq is required for JSON/SARIF output (brew install jq)." >&2; exit 69; }
DOMAIN="$(basename "$(dirname "$RULES_DIR")")"
TELLS="$RULES_DIR/grep-tells.tsv"
AST_DIR="$RULES_DIR/ast-grep"

# ---- collect target .swift files ------------------------------------------
[ "${#TARGETS[@]}" -eq 0 ] && TARGETS=(".")
FILES=()
for t in "${TARGETS[@]}"; do
  if [ -d "$t" ]; then
    while IFS= read -r f; do FILES+=("$f"); done < <(find "$t" -type f -name '*.swift' 2>/dev/null)
  elif [ -f "$t" ] && case "$t" in *.swift) true;; *) false;; esac; then
    FILES+=("$t")
  fi
done
if [ "${#FILES[@]}" -eq 0 ]; then
  echo "swiftui-lint: no .swift files under: ${TARGETS[*]}" >&2
  # still emit a valid empty report
fi

# ---- detect ast-grep ------------------------------------------------------
AST_BIN=""
if [ "$NO_AST" -eq 0 ]; then
  if command -v ast-grep >/dev/null 2>&1; then
    AST_BIN="ast-grep"
  elif command -v sg >/dev/null 2>&1 && sg --version >/dev/null 2>&1; then
    AST_BIN="sg"
  elif command -v npx >/dev/null 2>&1 && npx --no-install --package @ast-grep/cli ast-grep --version >/dev/null 2>&1; then
    AST_BIN="npx --package @ast-grep/cli ast-grep"
  elif command -v npx >/dev/null 2>&1; then
    # first run downloads; still zero-config. Probe once.
    if npx --yes --package @ast-grep/cli ast-grep --version >/dev/null 2>&1; then
      AST_BIN="npx --yes --package @ast-grep/cli ast-grep"
    fi
  fi
fi
AST_MODE="ast-grep"
if [ -z "$AST_BIN" ]; then
  AST_MODE="grep-only (DEGRADED)"
  if [ "$NO_AST" -eq 1 ]; then
    log "NOTICE: ast-grep disabled via --no-ast — running grep tier only. Tier-2 structural rules SKIPPED."
  else
    log "NOTICE: ast-grep unreachable (no binary, no npx) — degrading to grep-only. Tier-2 structural"
    log "        rules SKIPPED. Install for full coverage: brew install ast-grep  (or have npx available)."
  fi
fi

log "== swiftui-lint [$DOMAIN] :: ${#FILES[@]} file(s) :: tier2=$AST_MODE =="

# ---- choose grep engine (ripgrep preferred for --json speed; grep fallback)-
GREP_ENGINE="grep"
command -v rg >/dev/null 2>&1 && GREP_ENGINE="rg"

# ---- accumulate findings as TSV in a temp file ----------------------------
# columns: tier \t rule_id \t severity \t file \t line \t message \t snippet
WORK="$(mktemp)"; trap 'rm -f "$WORK" "$WORK".ast "$WORK".rules' EXIT

emit() { # tier rule sev file line msg snippet
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" >> "$WORK"
}

HARD=0
note_sev() { case "$1" in hard) HARD=$((HARD+1));; esac; }

# ---- TIER 1: grep tells ---------------------------------------------------
if [ -f "$TELLS" ] && [ "${#FILES[@]}" -gt 0 ]; then
  while IFS=$'\t' read -r id sev ere msg; do
    case "$id" in ''|'#'*) continue;; esac
    [ -z "${ere:-}" ] && continue
    if [ "$GREP_ENGINE" = "rg" ]; then
      hits="$(rg -nH --no-heading -e "$ere" "${FILES[@]}" 2>/dev/null)" || hits=""
    else
      hits="$(grep -HnE "$ere" "${FILES[@]}" 2>/dev/null)" || hits=""
    fi
    [ -z "$hits" ] && continue
    while IFS= read -r ln; do
      [ -z "$ln" ] && continue
      file="${ln%%:*}"; rest="${ln#*:}"; lno="${rest%%:*}"; snip="${rest#*:}"
      snip="$(printf '%s' "$snip" | tr '\t' ' ' | sed 's/^[[:space:]]*//')"
      emit grep1 "$id" "$sev" "$file" "$lno" "$msg" "$snip"
      note_sev "$sev"
    done <<< "$hits"
  done < "$TELLS"
fi

# ---- TIER 2: ast-grep structural rules ------------------------------------
AST_RULE_IDS=""
if [ -n "$AST_BIN" ] && [ -d "$AST_DIR" ] && [ "${#FILES[@]}" -gt 0 ]; then
  COMBINED=""
  first=1
  for y in "$AST_DIR"/*.yml "$AST_DIR"/*.yaml; do
    [ -f "$y" ] || continue
    if [ "$first" -eq 0 ]; then COMBINED+=$'\n---\n'; fi
    COMBINED+="$(cat "$y")"
    first=0
  done
  if [ -n "$COMBINED" ]; then
    # JSON stream (one object per line, stream-parseable). $AST_BIN may be multi-word (npx ...).
    ast_json="$($AST_BIN scan --inline-rules "$COMBINED" --json=stream "${FILES[@]}" 2>/dev/null)"
    if [ -n "$ast_json" ]; then
      # parse each JSON object line with jq → TSV. severity comes from the rule's own `severity`.
      while IFS=$'\t' read -r rid file lno sev txt; do
        [ -z "$rid" ] && continue
        # map ast-grep severity (hint|info|warning|error) → toolkit sev (adv|warn|hard)
        case "$sev" in error) tsev=hard;; warning) tsev=warn;; *) tsev=adv;; esac
        # parse-probe rules carry their own meaning; keep their id, force warn
        case "$rid" in parse-*) tsev=warn;; esac
        snip="$(printf '%s' "$txt" | tr '\t\n' '  ' | sed 's/^[[:space:]]*//')"
        emit astgrep "$rid" "$tsev" "$file" "$lno" "$rid" "$snip"
        note_sev "$tsev"
      done < <(printf '%s\n' "$ast_json" | jq -r '
        [ .ruleId, .file, (.range.start.line + 1 | tostring),
          (.severity // "warning"), (.lines // .text // "" | gsub("[\\t\\n]";" ")) ] | @tsv' 2>/dev/null)
    fi
  fi
fi

# ---- PARSE PROBE (safety rail) --------------------------------------------
# (a) ast-grep kind:ERROR (when ast-grep is available); (b) brace/paren balance heuristic ALWAYS.
PARSE_WARN=0
PARSE_PROBE_YML='id: parse-error-node
language: Swift
severity: warning
message: tree-sitter ERROR node — this file did not fully parse; structural (tier-2) rules may have
  silently missed findings here. Read it manually.
rule:
  kind: ERROR'
# bash-3.2 safe "set" of already-flagged files: newline-delimited string + a membership test.
FLAGGED=$'\n'
is_flagged() { case "$FLAGGED" in *$'\n'"$1"$'\n'*) return 0;; *) return 1;; esac; }
mark_flagged() { FLAGGED="$FLAGGED$1"$'\n'; }
if [ -n "$AST_BIN" ] && [ "${#FILES[@]}" -gt 0 ]; then
  probe_json="$($AST_BIN scan --inline-rules "$PARSE_PROBE_YML" --json=stream "${FILES[@]}" 2>/dev/null)" || probe_json=""
  if [ -n "$probe_json" ]; then
    while IFS=$'\t' read -r file lno; do
      [ -z "$file" ] && continue
      is_flagged "$file" && continue
      mark_flagged "$file"
      emit probe parse-incomplete warn "$file" "$lno" \
        "PARSE PROBE: tree-sitter ERROR node — file did not fully parse; tier-2 rules may have missed findings here. Read manually." \
        ""
      PARSE_WARN=$((PARSE_WARN+1))
    done < <(printf '%s\n' "$probe_json" | jq -r '[ .file, (.range.start.line + 1 | tostring) ] | @tsv' 2>/dev/null)
  fi
fi
# brace/paren balance heuristic — catches the error-recovery case ast-grep parses without an ERROR node.
for f in "${FILES[@]}"; do
  is_flagged "$f" && continue
  ob=$(tr -cd '{' < "$f" 2>/dev/null | wc -c | tr -d ' '); ob=${ob:-0}
  cb=$(tr -cd '}' < "$f" 2>/dev/null | wc -c | tr -d ' '); cb=${cb:-0}
  op=$(tr -cd '(' < "$f" 2>/dev/null | wc -c | tr -d ' '); op=${op:-0}
  cp=$(tr -cd ')' < "$f" 2>/dev/null | wc -c | tr -d ' '); cp=${cp:-0}
  if [ "$ob" -ne "$cb" ] || [ "$op" -ne "$cp" ]; then
    mark_flagged "$f"
    emit probe parse-unbalanced warn "$f" 1 \
      "PARSE PROBE: unbalanced braces/parens (open-brace $ob / close $cb, open-paren $op / close $cp) — file likely does not parse; tier-2 rules may have missed findings. Read manually." \
      ""
    PARSE_WARN=$((PARSE_WARN+1))
  fi
done

# ---- tally ----------------------------------------------------------------
TOTAL=$(wc -l < "$WORK" | tr -d ' '); TOTAL=${TOTAL:-0}
WARN=$(awk -F'\t' '$3=="warn"' "$WORK" | wc -l | tr -d ' ')
ADV=$(awk -F'\t' '$3=="adv"' "$WORK" | wc -l | tr -d ' ')
HARDN=$(awk -F'\t' '$3=="hard"' "$WORK" | wc -l | tr -d ' ')

# ---- emit JSON ------------------------------------------------------------
JSON="$(jq -Rs --arg domain "$DOMAIN" --arg ast "$AST_MODE" \
  --argjson nfiles "${#FILES[@]}" --argjson parsewarn "$PARSE_WARN" '
  split("\n") | map(select(length>0)) | map(split("\t")) |
  {
    tool: "swiftui-lint",
    role: "locator",
    note: "Candidate locations only — an LLM agent must READ each hit and decide. Not the arbiter.",
    domain: $domain,
    tier2_engine: $ast,
    files_scanned: $nfiles,
    parse_warnings: $parsewarn,
    counts: {
      hard:   (map(select(.[2]=="hard")) | length),
      warn:   (map(select(.[2]=="warn")) | length),
      adv:    (map(select(.[2]=="adv"))  | length),
      total:  length
    },
    findings: map({
      tier: .[0], rule_id: .[1], severity: .[2],
      file: .[3], line: (.[4]|tonumber? // 0),
      message: .[5], snippet: .[6]
    })
  }' < "$WORK")"

if [ -n "$JSON_OUT" ] && [ "$JSON_OUT" != "-" ]; then printf '%s\n' "$JSON" > "$JSON_OUT"; log "JSON  → $JSON_OUT"; else printf '%s\n' "$JSON"; fi

# ---- emit SARIF 2.1.0 -----------------------------------------------------
if [ -n "$SARIF_OUT" ]; then
  SARIF="$(printf '%s' "$JSON" | jq '
    def lvl(s): if s=="hard" then "error" elif s=="warn" then "warning" else "note" end;
    {
      "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
      version: "2.1.0",
      runs: [ {
        tool: { driver: {
          name: "swiftui-lint",
          informationUri: "https://ast-grep.github.io",
          rules: ( [ .findings[].rule_id ] | unique | map({ id: . }) )
        } },
        results: ( .findings | map({
          ruleId: .rule_id,
          level: lvl(.severity),
          message: { text: .message },
          locations: [ { physicalLocation: {
            artifactLocation: { uri: .file },
            region: { startLine: (if .line>0 then .line else 1 end) }
          } } ]
        }) )
      } ]
    }')"
  if [ "$SARIF_OUT" != "-" ]; then printf '%s\n' "$SARIF" > "$SARIF_OUT"; log "SARIF → $SARIF_OUT"; else printf '%s\n' "$SARIF"; fi
fi

log "== done [$DOMAIN]: ${HARDN} hard, ${WARN} warn, ${ADV} adv, ${PARSE_WARN} parse-warn (${TOTAL} hits) =="
[ "$HARDN" -gt 0 ] && exit 2
exit 0
