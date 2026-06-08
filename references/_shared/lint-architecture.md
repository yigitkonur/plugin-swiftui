# Shared lint architecture — the toolkit's ONE hybrid detection engine

Every audit skill needs a fast **detection accelerator** that *locates* candidate code lines for its
defects. Instead of 28 bespoke bash scripts, the toolkit ships **one shared hybrid lint engine** that
each skill feeds **declarative rule files** into. The engine emits machine-readable **JSON + SARIF**.

> **The engine LOCATES; it never judges.** It surfaces candidate hits. The LLM audit agent then READS
> each hit in full and decides (the skill's READ → DETECT → VERIFY steps). A lint hit is *not* a finding.

The runner: `${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh`.

---

## Two tiers (hybrid)

| Tier | Tool | For | Robustness |
|---|---|---|---|
| **1 — grep** | `rg` (or `grep` fallback) over `lint/grep-tells.tsv` | flat-presence / deprecation-string tells, hallucinated names | works even on files that **don't parse** |
| **2 — ast-grep** | `ast-grep` over `lint/ast-grep/*.yml` | **structural** rules grep can't express: containment, gate-scope, co-occurrence, nesting | needs a parse; guarded by the parse probe |

Tier 1 always runs. Tier 2 runs when ast-grep is reachable; otherwise the runner **degrades to
grep-only with an explicit notice** and never hard-fails the audit.

### ast-grep install / invocation (zero-install default)

```bash
# Zero-install (used automatically by the runner; first run downloads to npx cache):
npx --package @ast-grep/cli ast-grep --version
# Faster, if you run audits often:
brew install ast-grep
```

The runner auto-detects, in order: a native `ast-grep` binary → `sg` → `npx --package @ast-grep/cli
ast-grep`. ast-grep has **built-in Swift support** (tree-sitter-swift) — no Swift toolchain required.
**Grammar pin:** `tree-sitter-swift >= 0.7.1`, shipped inside `@ast-grep/cli >= 0.39` (verified on
`@ast-grep/cli 0.43.0`, ast-grep `0.43.0`). The `#Preview` macro and availability blocks parse fine.

---

## Per-skill rule-file format (what each of the 28 skills carries)

A skill's lint rules live in `${CLAUDE_PLUGIN_ROOT}/skills/<skill-name>/lint/`:

```
skills/<skill-name>/lint/
├── grep-tells.tsv         # tier 1 — one rule per line
└── ast-grep/              # tier 2 — one structural rule per .yml file
    ├── <id>-<slug>.yml
    └── …
```

The runner discovers them by skill name: `swiftui-lint.sh --skill <skill-name> --dir <sources>`
resolves `${PLUGIN}/skills/<skill-name>/lint/`. (Or point it explicitly: `--rules <lint-dir>`.)

### `grep-tells.tsv` (tier 1)

Tab-separated, `#`-comment lines ignored. **4 columns:**

```
id <TAB> severity <TAB> ERE-regex <TAB> message
```

- `id` — the skill's defect id (e.g. `glass-03`).
- `severity` — `hard` | `warn` | `adv`. **`hard` makes the runner exit 2** (CI-blockable); `warn`/`adv`
  inform only.
- `ERE-regex` — an extended-regex the runner greps over every target `*.swift` (no surrounding slashes).
- `message` — the one-line tell the agent reads; keep it actionable (the ❌→✅ hint).

### `ast-grep/*.yml` (tier 2)

One [ast-grep rule](https://ast-grep.github.io/guide/rule-config.html) per file. Required keys:
`id`, `language: Swift`, `severity` (`hint`|`info`|`warning`|`error`), `message`, `rule`. The runner
concatenates every `*.yml` with `---` separators and feeds them via `--inline-rules` (no `sgconfig.yml`
needed). ast-grep severity maps to the toolkit: `error → hard` (exit 2), `warning → warn`, else `adv`.

**Structural patterns that earn a tier-2 rule** (grep cannot express these):

- **Containment / NOT-inside** — "X outside a Y container":
  ```yaml
  rule:
    pattern: $R.glassEffect($$$A)
    not: { inside: { pattern: 'GlassEffectContainer { $$$ }', stopBy: end } }
  ```
- **Nesting / chaining** — `$I.glassEffect($$$A).glassEffect($$$B)` (glass-on-glass).
- **Gate-scope** — an `if #available(iOS …)` block (`kind: if_statement`) whose `condition` is an
  `availability_condition` matching `iOS` **and** whose body (`has: { stopBy: end, regex: … }`) uses the
  domain symbol. This proves the *scope*, not just a string.

**Authoring tip:** dump the AST to find kinds/fields —
`npx --package @ast-grep/cli ast-grep run --lang Swift -p '<pattern>' file.swift --debug-query=ast`.
Test a single rule fast — `… ast-grep scan --inline-rules "$(cat rule.yml)" --json=compact file.swift`.

---

## Output shape

### JSON (stdout, or `--json out.json`)

```jsonc
{
  "tool": "swiftui-lint",
  "role": "locator",
  "note": "Candidate locations only — an LLM agent must READ each hit and decide. Not the arbiter.",
  "domain": "audit-swiftui-liquid-glass",
  "tier2_engine": "ast-grep",          // or "grep-only (DEGRADED)"
  "files_scanned": 5,
  "parse_warnings": 1,                  // count of files the parse probe flagged
  "counts": { "hard": 10, "warn": 14, "adv": 0, "total": 25 },
  "findings": [
    { "tier": "grep1|astgrep|probe", "rule_id": "glass-05-glass-not-in-container",
      "severity": "hard|warn|adv", "file": "…", "line": 12,
      "message": "…", "snippet": "…" }
  ]
}
```

Parses with `jq .` and `python3 -m json.tool`. Consumable by Swift `Codable` / TypeScript.

### SARIF 2.1.0 (`--sarif out.sarif`)

Standard `runs[].results[]` with `ruleId` + `level` (`error`/`warning`/`note` mapped from severity) +
a `physicalLocation`. Ingestible by GitHub code-scanning and SARIF viewers.

### Exit code

`2` if any **hard** rule (tier-1 or tier-2 `error`) matched — a CI step / pre-ship gate can block on it.
Else `0`. Warnings, advisories, and parse warnings never fail the run. (Matches the house lint contract:
`0` = clean, `2` = block.)

---

## Safety rails (ast-grep's one real risk: silent parse failure → false negative)

A tier-2 rule that can't parse a file silently finds nothing there — a missed defect could masquerade as
a clean file. Two rails prevent that:

1. **Grep always runs** — the tier-1 fallback needs no parse, so flat tells survive a parse failure.
2. **Per-file parse probe**, surfaced as a `warn` finding (`rule_id: parse-incomplete` / `parse-unbalanced`)
   and counted in `parse_warnings`:
   - **ast-grep `kind: ERROR`** — flags tree-sitter ERROR nodes (garbage/invalid syntax inside the file).
   - **brace/paren balance heuristic** (always, even grep-only) — catches the **error-recovery** case
     where tree-sitter silently repairs a truncated file and emits *no* ERROR node (e.g. an unclosed
     `Text("x"`). Verified: such a file produces no `kind: ERROR` match, so this heuristic is required.
   A clean file is never flagged; a flagged file says **"read me by hand."**

> `kind: MISSING` is **not** a usable probe — ast-grep's rule validator rejects it. Use `kind: ERROR`
> plus the balance heuristic.

---

## Limitations the fan-out must know

- A tier-2 rule that ast-grep's validator rejects (e.g. a `has`/`inside` with only `regex` and no kind
  anchor) fails the whole inline-rules batch. Anchor relational rules on a `kind` (validated:
  `kind: if_statement` + `all: [ { has: … }, { has: … } ]`). When a structural rule can't be expressed,
  **keep it in the grep tier** and note the limitation here — never drop a rule.
- ast-grep `scan` exits `0` even with matches (it's a locator) — don't gate on its exit code; the runner
  reads its JSON.
- The per-file count semantics ("2+ siblings") still require the agent to READ — the not-in-container
  rule flags *every* glass outside a container, including a benign lone one. That is by design: locate
  generously, judge in the LLM.

---

## Replication checklist for a new audit skill

1. Create `skills/<skill>/lint/grep-tells.tsv` — port the skill's flat tells (id/severity/regex/message).
2. Create `skills/<skill>/lint/ast-grep/<id>-<slug>.yml` for each **structural** tell only.
3. In `SKILL.md`, the LOCATE step + "Detection accelerator" line call
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-lint.sh --skill <skill> --dir <sources> --json … --sarif …`,
   tell the agent to read `parse_warnings`, and route `lint/` in the reference table.
4. No bespoke bash script. (A legacy script may remain only as a thin `exec` pointer to the shared runner.)
