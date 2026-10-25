#!/usr/bin/env python3
"""Decide the next version of a Claude Code plugin repo from its commits, and write it everywhere it lives.

Usage: release.py [--root DIR] [--plugin NAME] [--level auto|patch|minor|major] [--apply] [--notes-out FILE] [--github-output]
Dry run unless --apply. Python 3.9+, stdlib only; works on any plugin repo, so each repo vendors this one file
(scripts/kit/release.py). The canonical copy is yigitkonur/plugin-kit/release/release.py; change it there and run sync.sh.

Why: Claude Code updates an installed plugin only when its computed version changes (the manifest `version` string
first), so every shipped change must bump it, and the bump must reach every place the version is written.

Level (auto): commits since the last release tag, merges and release commits left out. A commit counts only if it
changed at least one SHIPPED file: in a repo whose marketplace points at subfolders (source "./plugins/<name>") that is anything
under those folders; otherwise everything except docs, tests, evals, CI and root markdown/license files (see IGNORED_*). A repo can
state its own list in .github/release.json: {"shipped": ["skills/", "agents/", "hooks/", "bin/", "lib/"]} (plus .claude-plugin/ always).
  feat -> minor; fix, perf -> patch; `type!:` or "BREAKING CHANGE" -> major (minor while the major is 0).
  docs, ci, chore, test, style, build, refactor -> no release.
  A `Release-Level: minor|major` line in a commit body raises the level for that commit. A commit with no conventional prefix counts as a patch.
Release tags: v<x.y.z> and <plugin>--v<x.y.z> (what `claude plugin tag` makes); either form counts as "the last release".
Writes, wherever the old version string is the value of a "version" key: .claude-plugin/plugin.json,
.claude-plugin/marketplace.json, every nested <dir>/.claude-plugin/plugin.json and <dir>/.codex-plugin/plugin.json,
`__version__ = "old"` in lib/*/__init__.py, and CHANGELOG.md (an "## Unreleased" section is renamed; otherwise one is
generated from the commit subjects).
--plugin NAME (marketplaces that carry several plugins with their own versions, e.g. ./plugins/a and ./plugins/b): release only that
plugin. Its version is the one in <source>/.claude-plugin/plugin.json (else its marketplace entry); only commits that touch its folder
count; the last release is the newest <NAME>--v<x.y.z> tag; the bump rewrites its plugin.json files and its own marketplace entry (not
the catalog's metadata.version or the other plugins); the CHANGELOG gets "## NAME x.y.z - date"; the only tag is NAME--v<x.y.z>.
Prints JSON. With --github-output also writes released, version, tag, cli_tag, name to $GITHUB_OUTPUT.
Exit 0 on a clean decision (release or none); non-zero on a repo it cannot read.
"""
import argparse
import datetime
import glob
import json
import os
import re
import subprocess

# Not shipped to the people who install the plugin: a commit that touches only these never releases.
IGNORED_DIRS = (".github/", "docs/", "doc/", "tests/", "test/", "evals/", "spikes/", "scripts/ci/", "scripts/kit/", ".claude/")
IGNORED_ROOT = re.compile(r"^(README|CHANGELOG|AGENTS|CLAUDE|CONTRIBUTING|LICENSE|NOTICE|CODEOWNERS)[^/]*$|^\.gitignore$|^\.gitattributes$")
SKIP_WALK = {"node_modules", ".git", "tests", "test", "evals", "docs", "fixtures", ".claude"}
CONV = re.compile(r"^(?P<type>[a-zA-Z]+)(\([^)]*\))?(?P<bang>!)?:\s*(?P<subject>.+)$")
RANK = {"none": 0, "patch": 1, "minor": 2, "major": 3}
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
RELTAG = re.compile(r"^(?:v|.+--v)(\d+)\.(\d+)\.(\d+)$")


def git(root, *args):
    r = subprocess.run(["git", "-C", root] + list(args), capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("release.py: git %s failed: %s" % (" ".join(args), r.stderr.strip()[:200]))
    return r.stdout


def manifests(root):
    """Every file that carries the plugin version, relative to root."""
    found = []
    for dirpath, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_WALK]
        base = os.path.basename(dirpath)
        for f in files:
            rel = os.path.relpath(os.path.join(dirpath, f), root)
            if f == "plugin.json" and base in (".claude-plugin", ".codex-plugin"):
                found.append(rel)
            elif f == "marketplace.json" and base == ".claude-plugin":
                found.append(rel)
    return sorted(found, key=lambda p: (p.count("/"), p))


def read_json(root, rel):
    try:
        return json.load(open(os.path.join(root, rel), encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def current(root):
    """(version, plugin name). The root plugin.json wins, then the first marketplace entry, then nested plugin.json files."""
    files = manifests(root)
    plugin_files = [f for f in files if f.endswith("plugin.json")]
    market_files = [f for f in files if f.endswith("marketplace.json")]
    root_plugin = ".claude-plugin/plugin.json"
    order = ([root_plugin] if root_plugin in plugin_files else [])
    name = None
    for rel in order:
        d = read_json(root, rel)
        if d.get("version"):
            return d["version"], d.get("name")
    for rel in market_files:
        d = read_json(root, rel)
        for pl in d.get("plugins", []):
            name = name or pl.get("name")
            if pl.get("version"):
                return pl["version"], pl.get("name")
        if d.get("metadata", {}).get("version"):
            return d["metadata"]["version"], name
    for rel in plugin_files:
        d = read_json(root, rel)
        if d.get("version"):
            return d["version"], d.get("name")
    raise SystemExit("release.py: no version found in any plugin.json or marketplace.json")


def plugin_entry(root, name):
    """(marketplace file, source folder 'plugins/x/') for the named plugin."""
    for rel in manifests(root):
        if rel.endswith("marketplace.json"):
            for pl in read_json(root, rel).get("plugins", []):
                if pl.get("name") == name and isinstance(pl.get("source"), str):
                    return rel, os.path.normpath(pl["source"]).replace(os.sep, "/") + "/"
    raise SystemExit("release.py: plugin %r not found in any marketplace.json" % name)


def plugin_files(root, folder):
    return [rel for rel in manifests(root) if rel.startswith(folder) and rel.endswith("plugin.json")]


def plugin_current(root, name):
    market, folder = plugin_entry(root, name)
    for rel in plugin_files(root, folder):
        v = read_json(root, rel).get("version")
        if v:
            return v
    for pl in read_json(root, market).get("plugins", []):
        if pl.get("name") == name and pl.get("version"):
            return pl["version"]
    raise SystemExit("release.py: no version for plugin %r" % name)


def write_plugin_versions(root, name, old, new):
    market, folder = plugin_entry(root, name)
    done = []
    for rel in plugin_files(root, folder):
        n = replace_in(os.path.join(root, rel), old, new, r'"version"\s*:\s*"%s"')
        if n:
            done.append("%s (%d)" % (rel, n))
    path = os.path.join(root, market)
    text = open(path, encoding="utf-8").read()
    at, end = entry_span(text, name)
    seg, n = re.subn(r'("version"\s*:\s*")%s(")' % re.escape(old), lambda m: m.group(1) + new + m.group(2), text[at:end])
    if n:
        open(path, "w", encoding="utf-8").write(text[:at] + seg + text[end:])
        done.append("%s (%d)" % (market, n))
    return done


def entry_span(text, name):
    """(start, end) of the marketplace entry called `name`, found structurally so the order of its keys does not matter."""
    dec = json.JSONDecoder()
    i = text.index("[", re.search(r'"plugins"\s*:', text).end()) + 1
    while True:
        while text[i] in " \t\r\n,":
            i += 1
        if text[i] == "]":
            raise SystemExit("release.py: no marketplace entry called %s" % name)
        obj, end = dec.raw_decode(text, i)
        if obj.get("name") == name:
            return i, end
        i = end


def last_release_tag(root, name=None):
    best, best_key = None, None
    for t in git(root, "tag", "--list").split():
        m = RELTAG.match(t)
        if m and name and not t.startswith(name + "--v"):
            continue
        if m:
            key = tuple(int(x) for x in m.groups())
            if best_key is None or key > best_key:
                best, best_key = t, key
    return best


def plugin_dirs(root):
    """Directories the marketplace ships when every plugin lives in a subfolder (./plugins/<name>); otherwise None (the repo root ships)."""
    dirs = []
    for rel in manifests(root):
        if not rel.endswith("marketplace.json"):
            continue
        for pl in read_json(root, rel).get("plugins", []):
            src = pl.get("source")
            if not isinstance(src, str) or os.path.normpath(src) in (".", ""):
                return None
            dirs.append(os.path.normpath(src).replace(os.sep, "/") + "/")
    return tuple(dirs) or None


def shipped_config(root):
    """Optional .github/release.json {"shipped": ["skills/", "agents/", ...]}: the folders and files that reach installers, when the default guess is wrong."""
    try:
        v = json.load(open(os.path.join(root, ".github", "release.json"), encoding="utf-8")).get("shipped")
        return tuple(v) if v else None
    except (OSError, ValueError):
        return None


def shipped(path, dirs=None):
    if dirs:
        return path.startswith(dirs) or path.startswith(".claude-plugin/")
    return not (path.startswith(IGNORED_DIRS) or IGNORED_ROOT.match(path))


def commits_since(root, name=None):
    base = last_release_tag(root, name)
    dirs = shipped_config(root) or ((plugin_entry(root, name)[1],) if name else plugin_dirs(root))
    rng = "%s..HEAD" % base if base else "HEAD"
    raw = git(root, "log", "--no-merges", "--name-only", "--format=%x1e%H%x1f%s%x1f%b%x1f", rng)
    out = []
    for rec in raw.split("\x1e"):
        rec = rec.strip("\n")
        if not rec:
            continue
        head, _, files = rec.partition("\x1f\n") if "\x1f\n" in rec else (rec, "", "")
        sha, subject, body = (head.split("\x1f") + ["", ""])[:3]
        if subject.startswith("chore(release)"):
            continue
        paths = [f for f in files.split("\n") if f.strip()]
        out.append({"sha": sha, "subject": subject, "body": body, "shipped": any(shipped(p, dirs) for p in paths)})
    return base, out


def decide(commits, major):
    level, why = "none", []
    for c in commits:
        if not c["shipped"]:
            continue
        m = CONV.match(c["subject"])
        lv = "none"
        trailer = re.search(r"^Release-Level:[ \t]*(minor|major)[ \t]*$", c["body"], re.I | re.M)
        if m:
            t = m.group("type").lower()
            if m.group("bang") or "BREAKING CHANGE" in c["body"]:
                lv = "minor" if major == 0 else "major"
            elif t == "feat":
                lv = "minor"
            elif t in ("fix", "perf"):
                lv = "patch"
        else:
            lv = "patch"
        if trailer:                              # an explicit trailer only raises the level (major stays minor while the major is 0)
            tl = "minor" if (trailer.group(1).lower() == "minor" or major == 0) else "major"
            if RANK[tl] > RANK[lv]:
                lv = tl
        if lv != "none":
            why.append("%s: %s" % (lv, c["subject"]))
        if RANK[lv] > RANK[level]:
            level = lv
    return level, why


def bump(version, level):
    ma, mi, pa = map(int, SEMVER.match(version).groups())
    if level == "major":
        return "%d.0.0" % (ma + 1)
    if level == "minor":
        return "%d.%d.0" % (ma, mi + 1)
    return "%d.%d.%d" % (ma, mi, pa + 1)


def replace_in(path, old, new, pattern):
    text = open(path, encoding="utf-8").read()
    out, n = re.subn(pattern % re.escape(old), lambda m: m.group(0).replace(old, new), text)
    if n:
        open(path, "w", encoding="utf-8").write(out)
    return n


def write_versions(root, old, new):
    done = []
    for rel in manifests(root):
        n = replace_in(os.path.join(root, rel), old, new, r'"version"\s*:\s*"%s"')
        if n:
            done.append("%s (%d)" % (rel, n))
    for p in glob.glob(os.path.join(root, "lib", "*", "__init__.py")):
        n = replace_in(p, old, new, r'__version__\s*=\s*"%s"')
        if n:
            done.append("%s (%d)" % (os.path.relpath(p, root), n))
    return done


def changelog(root, new, commits, name=None):
    p = os.path.join(root, "CHANGELOG.md")
    today = datetime.date.today().isoformat()
    head = "## %s%s - %s" % (name + " " if name else "", new, today)
    if not os.path.isfile(p):
        text = "# Changelog\n\n"
    else:
        text = open(p, encoding="utf-8").read()
    have = re.search(r"^## .*%s\b.*$" % re.escape((name + " " if name else "v?") + new), text, re.M) if name else re.search(r"^## v?%s\b.*$" % re.escape(new), text, re.M)
    if have:                                     # a human already wrote this version's section: keep it, publish it
        b = text.find("\n## ", have.end())
        return p, text[have.end():b if b > 0 else len(text)].strip() + "\n"
    m = re.search(r"^## Unreleased[ \t]*$", text, re.M) if not name else None
    renamed = False
    if m:
        end = text.find("\n## ", m.end())
        if text[m.end():end if end >= 0 else len(text)].strip():
            text = text[:m.start()] + head + text[m.end():]
            renamed = True
        else:                                    # an empty Unreleased heading: drop it and generate from the commits
            text = text[:m.start()] + text[m.end():].lstrip("\n")
    if not renamed:
        lines = ["- %s (%s)" % (c["subject"], c["sha"][:7]) for c in commits if c["shipped"]]
        section = head + "\n\n" + "\n".join(lines) + "\n\n"
        i = text.find("\n## ")
        text = (text[:i + 1] + section + text[i + 1:]) if i >= 0 else text.rstrip("\n") + "\n\n" + section
    open(p, "w", encoding="utf-8").write(text)
    a = text.index(head)
    b = text.find("\n## ", a + 3)
    return p, text[a:b if b > 0 else len(text)].split("\n", 1)[1].strip() + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--plugin", help="release only this plugin of a multi-plugin marketplace")
    ap.add_argument("--level", default="auto", choices=["auto", "patch", "minor", "major"])
    ap.add_argument("--apply", action="store_true", help="write the files (default: only say what would happen)")
    ap.add_argument("--notes-out", help="write the release notes (the changelog section) here")
    ap.add_argument("--github-output", action="store_true", help="append released/version/tag/cli_tag/name to $GITHUB_OUTPUT")
    a = ap.parse_args()
    root = os.path.abspath(a.root)
    if a.plugin:
        old, name = plugin_current(root, a.plugin), a.plugin
    else:
        old, name = current(root)
    if not SEMVER.match(old):
        raise SystemExit("release.py: version %r is not x.y.z" % old)
    base, commits = commits_since(root, a.plugin)
    level, why = decide(commits, int(old.split(".")[0]))
    # a human already moved the manifest above the last release: release exactly that
    base_ver = RELTAG.match(base).groups() if base else None
    manual = base_ver is not None and tuple(int(x) for x in old.split(".")) > tuple(int(x) for x in base_ver)
    if a.level != "auto":
        level, why = a.level, ["forced: --level %s" % a.level]
    result = {"current": old, "name": name, "since": base, "commits": len(commits), "level": level, "reasons": why, "release": level != "none" or manual}
    if manual and a.level == "auto":
        result.update(level="manual", reasons=["manifest already at %s, above %s; releasing it as is" % (old, base)])
        new = old
    elif level != "none":
        new = bump(old, level)
    else:
        new = None
    if new:
        if (not a.plugin and git(root, "tag", "--list", "v" + new).strip()) or (name and git(root, "tag", "--list", "%s--v%s" % (name, new)).strip()):
            raise SystemExit("release.py: tag for %s already exists but the files say %s; check out the newest main" % (new, old))
        result.update(version=new, tag="%s--v%s" % (name, new) if a.plugin else "v" + new, cli_tag="" if a.plugin else ("%s--v%s" % (name, new) if name else ""))
        if a.apply:
            result["written"] = ((write_plugin_versions(root, a.plugin, old, new) if a.plugin else write_versions(root, old, new)) if new != old else [])
            cl, notes = changelog(root, new, commits, a.plugin)
            result["written"].append("CHANGELOG.md")
            if a.notes_out:
                open(a.notes_out, "w", encoding="utf-8").write(notes or "\n".join("- " + c["subject"] for c in commits) + "\n")
    if a.github_output and os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as f:
            f.write("released=%s\nversion=%s\ntag=%s\ncli_tag=%s\nname=%s\n" % (str(result["release"] and a.apply).lower(), result.get("version", ""), result.get("tag", ""), result.get("cli_tag", ""), name or ""))
    print(json.dumps(result, indent=1))


if __name__ == "__main__":
    main()
