#!/usr/bin/env python3
"""eval/score.py — deterministic scoring for the swiftui-ctx proof-of-value eval.

Reads eval/out/<id>/{baseline,grounded}.swift (produced by eval/run.sh) and scores each with the
toolkit's OWN oracles — no human grading, no LLM judge:
  1. parses     — `swiftc -parse` exits 0 (syntactically valid Swift)
  2. deprecated — count of deprecated/forbidden API tokens present (lower is better)
  3. lint       — audit-swiftui-api-currency lint findings over the file (lower is better)
  4. shape      — the task's modern consensus shape regex appears (1/0)
Emits a per-task + aggregate grounded-vs-baseline table to eval/RESULTS.md and stdout.
"""
import json, os, re, subprocess, sys, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(HERE, "out")
ENGINE = os.path.join(ROOT, "scripts", "swiftui-lint.sh")
DEP_FILE = os.path.join(ROOT, "hooks", "deprecated-names.txt")
CONDS = ("baseline", "grounded")


def posix2py(rx):  # the tasks use a couple of POSIX classes; map to Python re
    return rx.replace("[[:space:]]", r"\s")


def deprecated_apis():
    apis = set()
    if os.path.isfile(DEP_FILE):
        for ln in open(DEP_FILE):
            ln = ln.strip()
            if ln and not ln.startswith("#"):
                apis.add(ln.split("|", 1)[0])
    return apis


DEP = deprecated_apis()


def parses(path):
    if not shutil.which("swiftc"):
        return None  # unknown — toolchain absent
    r = subprocess.run(["swiftc", "-parse", path], capture_output=True)
    return r.returncode == 0


def deprecated_count(code, forbid):
    toks = set(forbid) | DEP
    return sum(len(re.findall(r"\b" + re.escape(t) + r"\b", code)) for t in toks)


def lint_findings(path):
    if not os.path.isfile(ENGINE):
        return None
    env = dict(os.environ, CLAUDE_PLUGIN_ROOT=ROOT)
    r = subprocess.run(["bash", ENGINE, "--skill", "audit-swiftui-api-currency", "--quiet", path],
                       capture_output=True, text=True, env=env)
    try:
        return len(json.loads(r.stdout).get("findings", []))
    except Exception:
        return None


def shape_ok(code, rx):
    return 1 if re.search(posix2py(rx), code) else 0


def score_file(path, task):
    code = open(path).read() if os.path.isfile(path) else ""
    if not code:
        return None
    return {
        "parses": parses(path),
        "deprecated": deprecated_count(code, task.get("forbid", [])),
        "lint": lint_findings(path),
        "shape": shape_ok(code, task.get("shape_regex", "")),
    }


def main():
    tasks = [json.loads(l) for l in open(os.path.join(HERE, "tasks.jsonl")) if l.strip()]
    rows, agg = [], {"shape_win": 0, "dep_win": 0, "lint_win": 0, "n": 0}
    for t in tasks:
        d = os.path.join(OUT, t["id"])
        b = score_file(os.path.join(d, "baseline.swift"), t)
        g = score_file(os.path.join(d, "grounded.swift"), t)
        if not b or not g:
            continue
        agg["n"] += 1
        if g["shape"] > b["shape"]:
            agg["shape_win"] += 1
        if g["deprecated"] < b["deprecated"]:
            agg["dep_win"] += 1
        if (g["lint"] or 0) < (b["lint"] or 0):
            agg["lint_win"] += 1
        rows.append((t["id"], b, g))

    def cell(v):
        return "—" if v is None else ("✓" if v is True else ("fail" if v is False else str(v)))

    lines = ["# eval results — swiftui-ctx grounded vs baseline", "",
             "Deterministic scoring (no human/LLM judge): `swiftc -parse`, deprecated-token count, "
             "audit-swiftui-api-currency lint findings, modern-shape regex. Lower deprecated/lint = better.", "",
             "| task | parses (b/g) | deprecated (b→g) | lint (b→g) | modern shape (b→g) |",
             "|---|---|---|---|---|"]
    for tid, b, g in rows:
        lines.append(f"| {tid} | {cell(b['parses'])}/{cell(g['parses'])} | "
                     f"{b['deprecated']}→{g['deprecated']} | {cell(b['lint'])}→{cell(g['lint'])} | "
                     f"{b['shape']}→{g['shape']} |")
    n = agg["n"] or 1
    lines += ["", f"**{agg['n']} task pairs scored.** grounded wins: "
              f"modern-shape {agg['shape_win']}/{n} · fewer-deprecated {agg['dep_win']}/{n} · "
              f"fewer-lint-findings {agg['lint_win']}/{n}.", ""]
    if not shutil.which("swiftc"):
        lines.append("> note: `swiftc` absent — `parses` shown as `—` (run on macOS for the compile signal).")
    if agg["n"] == 0:
        lines.append("> no scored pairs — run `bash eval/run.sh` first (set `EVAL_GEN_CMD` for a live model, "
                     "else it scores the committed `eval/seeds/`).")
    report = "\n".join(lines) + "\n"
    open(os.path.join(HERE, "RESULTS.md"), "w").write(report)
    print(report)


if __name__ == "__main__":
    main()
