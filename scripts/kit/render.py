#!/usr/bin/env python3
"""render.py: write (or check) the two blocks every plugin repo shares. Vendored as scripts/kit/render.py.

  python3 scripts/kit/render.py --write [--root DIR]     rewrite the blocks in README.md and AGENTS.md
  python3 scripts/kit/render.py --check [--root DIR]     exit 1 and say which block is stale or missing

README.md carries   <!-- kit:install:start --> ... <!-- kit:install:end -->   (the install / turn on / update / uninstall section)
AGENTS.md carries   <!-- kit:agents:start -->  ... <!-- kit:agents:end -->    (releases, versions, install policy)
Everything is derived from the repo itself: .claude-plugin/marketplace.json (marketplace + plugin names), the git remote (repo),
and whether .agents/plugins/marketplace.json exists (Codex yes or no). Nothing else is configurable on purpose: the point is that
all repos say the same thing. Python 3.9+, standard library only.
"""
import json
import os
import re
import subprocess
import sys

KIT_RAW = "https://raw.githubusercontent.com/yigitkonur/plugin-kit/main/install.sh"


def facts(root):
    mk = json.load(open(os.path.join(root, ".claude-plugin", "marketplace.json")))
    repo = ""
    r = subprocess.run(["git", "-C", root, "remote", "get-url", "origin"], capture_output=True, text=True)
    m = re.search(r"github\.com[:/]([^/]+/[^/.]+?)(?:\.git)?$", r.stdout.strip())
    if m:
        repo = m.group(1)
    repo = repo or os.environ.get("GITHUB_REPOSITORY", "")
    market = mk["name"]
    names = [p["name"] for p in mk["plugins"]]
    cpath = os.path.join(root, ".agents", "plugins", "marketplace.json")
    codex_names = [p["name"] for p in json.load(open(cpath)).get("plugins", [])] if os.path.exists(cpath) else []
    kpath = os.path.join(root, ".github", "kit.json")
    glob = os.path.exists(kpath) and json.load(open(kpath)).get("install") == "global"
    return repo, market, names, codex_names, glob


def install_block(repo, market, names, codex_names, glob):
    ids = ["%s@%s" % (n, market) for n in names]
    cids = ["%s@%s" % (n, market) for n in names if n in codex_names]
    codex = bool(cids)
    many = len(names) > 1
    partial = codex and len(cids) < len(ids)
    o = []
    o.append("## install")
    o.append("")
    if glob:
        o.append("This plugin is the one exception to our install-off rule: it is installed **globally and stays on in every project**, in Claude Code%s." % (" and Codex" if codex else ""))
    else:
        o.append("Every plugin of ours is installed **once, globally, and off**, then **turned on per project**. Nothing runs and no tokens are spent in chats that don't switch it on. It works the same in Claude Code and Codex%s." % ("" if codex else " (this one is Claude Code only for now: no Codex port yet)"))
        if partial:
            o.append("")
            o.append("Codex gets %s; the other plugins here are Claude Code only." % ", ".join("`%s`" % n for n in names if n in codex_names))
    o.append("")
    o.append("### 1. install %s globally" % ("them" if many else "it"))
    o.append("")
    o.append("**Claude Code**")
    o.append("")
    o.append("```sh")
    o.append("claude plugin marketplace add %s" % repo)
    for i in ids:
        o.append("claude plugin install %s -s user%s" % (i, "" if glob or i != ids[0] else "          # stays off: defaultEnabled is false in the manifest"))
    o.append("```")
    o.append("")
    if codex:
        o.append("**Codex** (0.163+)")
        o.append("")
        o.append("```sh")
        o.append("codex plugin marketplace add %s" % repo)
        for i in cids:
            o.append("codex plugin add %s" % i)
        if not glob:
            for i in cids:
                o.append("codex-plugin-project.sh global-off %s%s" % (i, "     # Codex has no enable/disable command; this keeps it off everywhere" if i == cids[0] else ""))
        o.append("```")
        o.append("")
    o.append("All our plugins, both hosts, plus the `plugin` command and the 6-hourly update job, in one line:")
    o.append("")
    o.append("```sh")
    o.append("curl -fsSL %s | sh -s -- --all" % KIT_RAW)
    o.append("```")
    o.append("")
    n = 2
    if not glob:
        o.append("### 2. turn %s on in a project" % ("them" if many else "it"))
        o.append("")
        o.append("```sh")
        o.append("cd your-project")
        w = len("plugin off %s" % names[0]) + 3
        o.append(("plugin on %s" % names[0]).ljust(w) + "# Claude Code" + (" and Codex" if names[0] in codex_names else "") + ", this folder only")
        o.append(("plugin off %s" % names[0]).ljust(w) + "# undo")
        o.append("plugin".ljust(w) + "# or pick from a list (TUI)")
        o.append("```")
        o.append("")
        o.append("By hand, without the `plugin` command:")
        o.append("")
        o.append("```sh")
        for i in ids:
            o.append("claude plugin enable %s --scope project      # undo: claude plugin disable %s --scope project" % (i, i))
        for i in cids:
            o.append("codex-plugin-project.sh on %s . --trust      # undo: codex-plugin-project.sh off %s" % (i, i))
        o.append("```")
        o.append("")
        o.append("Restart `claude`%s in that folder afterwards." % (" / `codex`" if codex else ""))
        if codex:
            o.append("Codex reads a folder's `.codex/config.toml` only when the folder is trusted; `--trust` adds that, and it also enables the folder's hooks and rules, so use it for your own projects only. `plugin` and `codex-plugin-project.sh` come from [plugin-kit](https://github.com/yigitkonur/plugin-kit) (the one-line installer above).")
        o.append("")
        n = 3
    o.append("### %d. updates" % n)
    o.append("")
    o.append("A plugin updates only when its `version` changes, and this repo's `release` workflow bumps it on every shipped change. Machines pick it up with `plugin update`, or by themselves with the 6-hourly job (`plugin autoupdate install`). By hand:")
    o.append("")
    o.append("```sh")
    o.append("claude plugin marketplace update %s && claude plugin update %s" % (market, ids[0]))
    if codex:
        o.append("codex plugin marketplace upgrade %s        # then start a new session" % market)
    o.append("```")
    o.append("")
    o.append("No GitHub SSH key on the machine? `export CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` (`plugin install` sets it in Claude's settings for you).")
    o.append("")
    o.append("### %d. uninstall" % (n + 1))
    o.append("")
    o.append("```sh")
    for i in ids:
        o.append("claude plugin uninstall %s -s user" % i)
    o.append("claude plugin marketplace remove %s" % market)
    if codex:
        for i in cids:
            o.append("codex plugin remove %s" % i)
        o.append("codex plugin marketplace remove %s" % market)
    o.append("```")
    return "\n".join(o)


def agents_block(repo, market, names, codex_names, glob):
    codex = bool(codex_names)
    o = []
    o.append("## Releases, versions and installs (shared by every plugin repo)")
    o.append("")
    o.append("- **Never bump a version by hand.** `.github/workflows/release.yml` runs after `ci` is green on `main`. `scripts/kit/release.py` reads the conventional-commit subjects since the last release tag (`feat` is a minor, `fix`/`perf`/unprefixed a patch, `type!:` or a BREAKING CHANGE line a major, a minor while the version is 0.x; docs, ci, chore, test, style, build and refactor release nothing) and counts only commits that touch shipped files%s. It writes every manifest, the marketplace entries and CHANGELOG.md, commits `chore(release): vX [skip ci]`, tags `vX` and `<plugin>--vX` (several plugins: `<plugin>--vX` only) and publishes the GitHub release. `python3 scripts/kit/release.py` with no flags prints what it would do; Actions > release > Run workflow forces a level or a dry run." % (" (in a several-plugin repo, a commit counts for a plugin when it touches that plugin's folder)" if len(names) > 1 else ""))
    o.append("- **One version source: the manifests** (`.claude-plugin/plugin.json`%s, the marketplace entry). Never a constant in code; read the manifest at runtime." % (", `.codex-plugin/plugin.json`" if codex else ""))
    o.append("- Installed copies update only when the version string changes, so a change users should get must reach `main` as a releasing commit type (`feat`, `fix`, `perf`, or `!`).")
    if glob:
        o.append("- **Install policy (the one exception):** installed globally and ON in every project, in both hosts (`.github/kit.json` says `install: global`). `plugin.json` must not set `defaultEnabled: false`.")
    else:
        o.append("- **Install policy:** installed globally and off (`\"defaultEnabled\": false`), switched on per project with `plugin on <name>`. Never document a project-scope install as the way in.")
    o.append("- `scripts/kit/*`, `scripts/kit.sha256`, `.github/workflows/release.yml`, the `kit:manifests` job in `ci.yml` and the blocks between `kit:` markers in README.md and AGENTS.md are copies from [yigitkonur/plugin-kit](https://github.com/yigitkonur/plugin-kit). Change them there and run its `sync.sh`; `scripts/kit/check-manifests.py` fails CI on a local edit.")
    o.append("- Before pushing: `python3 scripts/kit/check-manifests.py --validate`, `python3 scripts/kit/secret-scan.py --tree`, `python3 scripts/kit/check-links.py`, then this repo's own checks.")
    return "\n".join(o)


BLOCKS = [("README.md", "install", install_block), ("AGENTS.md", "agents", agents_block)]


def apply(root, write):
    repo, market, names, codex_names, glob = facts(root)
    bad = []
    for fname, key, fn in BLOCKS:
        path = os.path.join(root, fname)
        start, end = "<!-- kit:%s:start -->" % key, "<!-- kit:%s:end -->" % key
        want = "%s\n%s\n%s" % (start, fn(repo, market, names, codex_names, glob), end)
        text = open(path, encoding="utf-8").read() if os.path.exists(path) else None
        if text is None or start not in text or end not in text:
            bad.append("%s has no %s ... %s block (run render.py --write after placing the markers)" % (fname, start, end))
            continue
        new = re.sub(re.escape(start) + r".*?" + re.escape(end), lambda m: want, text, count=1, flags=re.S)
        if new != text:
            if write:
                open(path, "w", encoding="utf-8").write(new)
                print("rendered %s block in %s" % (key, fname))
            else:
                bad.append("%s: the kit:%s block is stale (python3 scripts/kit/render.py --write)" % (fname, key))
    return bad


def main(argv):
    root = os.getcwd()
    if "--root" in argv:
        root = os.path.abspath(argv[argv.index("--root") + 1])
    write = "--write" in argv
    bad = apply(root, write)
    for b in bad:
        print(b)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
