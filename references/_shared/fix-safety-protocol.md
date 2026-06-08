# Shared Reference — Fix-Safety Protocol (the canonical 8-point copy)

Every audit skill in this toolkit **detects and fixes on finished projects**, so fixing is governed.
This is the single canonical copy of the protocol; the orchestrator and every auto-fixing skill
inherit it by pointing here, not by restating it. Do not copy these points into a skill's own
`references/`.

**As of:** 2026-06-07.

---

## The 8 points

1. **Clean-tree gate.** Never apply a fix on a dirty git tree unless the user waives it. Dirty → write
   findings only and tell the user to commit/stash first.
2. **Findings-first.** Always write ALL findings to `swiftui-audits/…` BEFORE any fix. A fix with no
   prior finding on disk is forbidden.
3. **`fix_mode` is law.** Auto-apply ONLY findings with `fix_mode: auto`. A `fix_mode: flag-only`
   finding is surfaced as a suggested diff for human review and is **never** applied.
4. **One commit per finding.** Each applied fix is its own conventional commit citing the finding's
   `rule_id` + file (e.g. `fix(api-currency): cur-02 .foregroundColor → .foregroundStyle in Foo.swift:12`),
   so any single fix is independently revertible.
5. **Cross-skill order (guards first).** When several skills run with fix, the mechanical-rename guards
   land first — `api-currency` → `availability-gating` → `concurrency-safety` — then the domain skills,
   so a domain fix never lands on a soon-to-be-renamed symbol. A domain fix that would touch a
   guard-renamed symbol is a no-op (see §6).
6. **Idempotent.** A fixed finding flips `status: open → fixed`; a re-run detects already-fixed state
   and does not re-apply or duplicate. A fix on a symbol a guard already renamed is a no-op flipping
   to `status: fixed` and citing the guard commit.
7. **Never weaken the check.** No "fix" that deletes an assertion, widens a gate, suppresses a finding,
   or skips a hard-fail to make the tree look clean. The finding measures reality; corrupting the
   check breaks the measurement, not the bug.
8. **Verify after fix.** Re-read the changed lines (and re-run the compile hook where present); record
   the evidence in the finding's `## Fix applied?` field. A claim of "fixed" with no fresh evidence is
   not done.

---

## Cross-skill ordering, made concrete

The load-bearing sequence under `--fix` on a clean tree:

```
guards (SEQUENTIAL):  api-currency → availability-gating → concurrency-safety
domains (per wave):   each active domain skill, one commit per finding
meta (LAST):          macos-nativeness (re-scored for a before/after delta)
```

Fixes are **never** applied inside a parallel detection wave — domain skills run findings-only in
parallel, then fixes are applied serially in guards-first order, so two skills can never race on the
same line.

---

## Sources

This protocol is internal to the toolkit; it cites no external API. Floor/availability facts the
fixes act on live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; gating discipline in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`.
