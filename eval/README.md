# eval — does `swiftui-ctx` actually improve generated SwiftUI?

A deterministic, no-human-judge benchmark: generate SwiftUI for each task **twice** — once from the
prompt alone (*baseline*), once with real production usage injected from the catalog (*grounded*) — and
score both with the toolkit's own oracles. If grounding helps, grounded output should use fewer
deprecated APIs, trip fewer audit-lint findings, and match the modern consensus shape more often.

## Run it

```sh
make eval                              # scores the committed eval/seeds/ (no model needed) → eval/RESULTS.md
EVAL_GEN_CMD='codex exec -' make eval  # live run: generate with a model, then score
```

`EVAL_GEN_CMD` is any command that reads a prompt on **stdin** and writes Swift to **stdout** (a model
CLI or a thin wrapper). With it unset, `eval/run.sh` falls back to the committed `eval/seeds/` pairs so
the harness always produces a real `RESULTS.md`. Live outputs land in `eval/out/` (gitignored).

## How it scores (`eval/score.py`)

Per task, for each condition's `.swift`:
1. **parses** — `swiftc -parse` exits 0 (syntactically valid). `—` if no toolchain.
2. **deprecated** — count of forbidden/deprecated API tokens (from the task + `hooks/deprecated-names.txt`). Lower better.
3. **lint** — `audit-swiftui-api-currency` findings via `scripts/swiftui-lint.sh`. Lower better.
4. **shape** — the task's modern consensus regex appears (1/0).

Aggregate = how often grounded beats baseline on each axis. Tasks live in `tasks.jsonl`
(`prompt`, `ground_cmd`, `forbid`, `shape_regex`).

## Caveat

This is the **experimental** component. The seed run validates the scorer and the methodology end-to-end;
a live `EVAL_GEN_CMD` run measures a specific model. Results feed back into the ranking weights in
`scripts/05_catalog.py` / `08_recipes.py` — treat deltas as directional, not absolute.
