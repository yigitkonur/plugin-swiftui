#!/usr/bin/env python3
"""validate-skills.py — dependency-free Agent Skills spec check for every skill in skills/.

Enforces the invariants that actually matter (no external package needed):
  - SKILL.md exists with a parseable YAML-ish frontmatter block
  - name: present, == directory name, ^[a-z0-9-]+$, <= 64 chars
  - description: present, <= 1024 chars, contains no '<' or '>' (spec forbids angle brackets)
  - no orphan routes: every ${CLAUDE_PLUGIN_ROOT}/<file> and (references/<file>) the body points to exists
Also validates the two plugin manifests are valid JSON. Exits non-zero on any failure (CI fail-fast).
"""
import json, os, re, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAME_RE = re.compile(r"^[a-z0-9-]+$")
errs = []


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    fm = {}
    for line in m.group(1).splitlines():
        mm = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if mm:
            fm[mm.group(1)] = mm.group(2).strip()
    # description may run multi-line until the next key; recapture it whole
    dm = re.search(r"^description:\s*(.*?)(?=\n[A-Za-z_-]+:\s|\Z)", m.group(1), re.S | re.M)
    if dm:
        fm["description"] = dm.group(1).strip()
    return fm


def check_skill(d):
    name = os.path.basename(d)
    sk = os.path.join(d, "SKILL.md")
    if not os.path.isfile(sk):
        errs.append(f"{name}: no SKILL.md"); return
    text = open(sk).read()
    fm = frontmatter(text)
    if fm is None:
        errs.append(f"{name}: missing/!parseable frontmatter"); return
    n = fm.get("name", "")
    if n != name:
        errs.append(f"{name}: name '{n}' != dir")
    if not NAME_RE.match(n) or len(n) > 64:
        errs.append(f"{name}: name must be ^[a-z0-9-]+$ and <=64")
    desc = fm.get("description", "")
    if not desc:
        errs.append(f"{name}: empty description")
    if len(desc) > 1024:
        errs.append(f"{name}: description {len(desc)} > 1024")
    if "<" in desc or ">" in desc:
        errs.append(f"{name}: description contains angle bracket (spec forbids)")
    # orphan routes
    for ref in re.findall(r"\$\{CLAUDE_PLUGIN_ROOT\}/([A-Za-z0-9_./-]+\.(?:md|sh|tsv|json|py|yml))", text):
        if not os.path.exists(os.path.join(ROOT, ref)):
            errs.append(f"{name}: dangling ${{CLAUDE_PLUGIN_ROOT}}/{ref}")
    for ref in re.findall(r"\((references/[A-Za-z0-9_./-]+\.md)\)", text):
        if not os.path.exists(os.path.join(d, ref)):
            errs.append(f"{name}: dangling link {ref}")


def main():
    skills = sorted(glob.glob(os.path.join(ROOT, "skills", "*")))
    for d in skills:
        if os.path.isdir(d):
            check_skill(d)
    for mf in (".claude-plugin/plugin.json", ".claude-plugin/marketplace.json"):
        try:
            json.load(open(os.path.join(ROOT, mf)))
        except Exception as e:
            errs.append(f"{mf}: invalid JSON ({e})")
    if errs:
        print("validate-skills: FAIL")
        for e in errs:
            print("  -", e)
        sys.exit(1)
    print(f"validate-skills: {len(skills)} skills OK + manifests valid")


if __name__ == "__main__":
    main()
