#!/usr/bin/env python3
"""check-manifests.py: the checks every yigitkonur plugin repo shares. Vendored as scripts/kit/check-manifests.py.

  python3 scripts/kit/check-manifests.py [--validate] [--root DIR]
  python3 scripts/kit/check-manifests.py --write-hashes [--root DIR]     (plugin-kit's sync.sh uses this)

Checks (each failure prints one FAIL line; exit 1 when there is any):
  1 Claude marketplace: every entry has a plugin folder with .claude-plugin/plugin.json of the same name; versions agree
    (plugin.json == marketplace entry; for a one-plugin marketplace also metadata.version).
  2 Install policy: plugin.json has "defaultEnabled": false (installed globally, off, switched on per project). A repo whose
    .github/kit.json says {"install": "global"} (research) is installed globally and ON everywhere: the opposite is enforced.
  3 Codex: .codex-plugin/plugin.json (same name, same version, ./ paths that exist) and .agents/plugins/marketplace.json
    (same marketplace name, a local ./ source, policy.installation and policy.authentication, category). A plugin has both a
    Codex manifest and a Codex marketplace entry, or neither (Claude only); one without the other is a failure.
  4 No stray backup files tracked (*.bak, *.orig, *.rej, ~, .DS_Store).
  5 Vendored kit files match scripts/kit.sha256 (scripts/kit/*, .github/workflows/release.yml).
  6 README.md and AGENTS.md carry the rendered kit blocks and they are current (scripts/kit/render.py --check).
  7 .github/workflows/ci.yml carries the shared manifests job unchanged (between the kit:manifests markers).
  --validate also runs `claude plugin validate --strict` on the repo root and every plugin folder.
"""
import hashlib
import json
import os
import re
import subprocess
import sys

KIT_FILES = ["scripts/kit/release.py", "scripts/kit/check-manifests.py", "scripts/kit/secret-scan.py", "scripts/kit/check-links.py",
             "scripts/kit/render.py", "scripts/kit/ci-manifests.yml", ".github/workflows/release.yml"]
errors = []


def fail(msg):
    errors.append(msg)
    print("FAIL  " + msg)


def load(root, rel):
    try:
        with open(os.path.join(root, rel), encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        fail("%s: %s" % (rel, e))
        return {}


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def git_files(root):
    r = subprocess.run(["git", "-C", root, "ls-files"], capture_output=True, text=True)
    return r.stdout.splitlines() if r.returncode == 0 else []


def main(argv):
    root = os.getcwd()
    if "--root" in argv:
        root = os.path.abspath(argv[argv.index("--root") + 1])
    if "--write-hashes" in argv:
        lines = ["%s  %s" % (sha(os.path.join(root, f)), f) for f in KIT_FILES if os.path.exists(os.path.join(root, f))]
        with open(os.path.join(root, "scripts", "kit.sha256"), "w") as fh:
            fh.write("\n".join(lines) + "\n")
        print("wrote scripts/kit.sha256 (%d files)" % len(lines))
        return 0

    mk = load(root, ".claude-plugin/marketplace.json")
    plugins = mk.get("plugins") or []
    if not plugins:
        fail(".claude-plugin/marketplace.json lists no plugins")
    roots = []
    has_codex_mk = os.path.exists(os.path.join(root, ".agents/plugins/marketplace.json"))
    cmk = load(root, ".agents/plugins/marketplace.json") if has_codex_mk else {}
    codex_seen = 0
    kitcfg = load(root, ".github/kit.json") if os.path.exists(os.path.join(root, ".github/kit.json")) else {}
    is_global = kitcfg.get("install") == "global"   # research: installed globally and ON everywhere
    for e in plugins:
        name, src = e.get("name"), e.get("source")
        if not isinstance(src, str):
            fail("marketplace entry %s: source must be a ./ path string" % name)
            continue
        proot = os.path.normpath(os.path.join(root, src))
        rel = os.path.relpath(proot, root)
        roots.append(rel)
        pj = load(root, os.path.join(rel, ".claude-plugin/plugin.json"))
        if pj.get("name") != name:
            fail("%s: plugin.json name %r != marketplace entry %r" % (rel, pj.get("name"), name))
        ver = pj.get("version")
        if not ver:
            fail("%s: plugin.json has no version" % rel)
        if e.get("version") and e["version"] != ver:
            fail("%s: marketplace entry version %s != plugin.json %s" % (name, e["version"], ver))
        if len(plugins) == 1 and (mk.get("metadata") or {}).get("version") not in (None, ver):
            fail("marketplace metadata.version %s != plugin.json %s" % (mk["metadata"]["version"], ver))
        if is_global:
            if pj.get("defaultEnabled") is False:
                fail('%s: .github/kit.json says install=global (on everywhere), so plugin.json must not set "defaultEnabled": false' % rel)
        elif pj.get("defaultEnabled") is not False:
            fail('%s: plugin.json must set "defaultEnabled": false (installed globally, off, switched on per project)' % rel)
        # Codex
        ce = next((x for x in cmk.get("plugins", []) if x.get("name") == name), None)
        source = (ce or {}).get("source") or {}
        csrc = source.get("path")
        croot = os.path.normpath(os.path.join(root, csrc)) if isinstance(csrc, str) else proot
        cj_path = os.path.join(os.path.relpath(croot, root), ".codex-plugin/plugin.json")
        has_codex_pj = os.path.exists(os.path.join(root, cj_path))
        listed = ce is not None
        if has_codex_pj != listed:
            fail("%s: Codex packaging is half there (.codex-plugin/plugin.json: %s, listed in .agents/plugins/marketplace.json: %s). A plugin without a Codex port has neither." % (name, has_codex_pj, listed))
        if has_codex_pj:
            codex_seen += 1
            cj = load(root, cj_path)
            if cj.get("name") != name:
                fail("%s: codex plugin.json name %r != %r" % (cj_path, cj.get("name"), name))
            if cj.get("version") != ver:
                fail("%s: codex version %s != claude version %s" % (cj_path, cj.get("version"), ver))
            for k in ("skills", "mcpServers", "hooks"):
                v = cj.get(k)
                if isinstance(v, str) and (not v.startswith("./") or not os.path.exists(os.path.join(croot, v))):
                    fail("%s: %s path %r must start with ./ and exist" % (cj_path, k, v))
            ce = next((x for x in cmk.get("plugins", []) if x.get("name") == name), None)
            if not ce:
                fail(".agents/plugins/marketplace.json has no entry for %s" % name)
            else:
                pol = ce.get("policy") or {}
                if pol.get("installation") != "AVAILABLE" or not pol.get("authentication") or not ce.get("category"):
                    fail("%s: codex marketplace entry needs policy.installation AVAILABLE, policy.authentication and category" % name)
                s = ce.get("source") or {}
                if (s.get("source") != "local" or not isinstance(csrc, str) or not csrc.startswith("./")
                        or os.path.commonpath([os.path.abspath(root), os.path.abspath(croot)]) != os.path.abspath(root)):
                    fail("%s: codex marketplace source must be a local ./ path inside the repo (found %s)" % (name, s))
    if has_codex_mk and cmk.get("name") != mk.get("name"):
        fail("codex marketplace name %r != claude marketplace name %r" % (cmk.get("name"), mk.get("name")))
    if not codex_seen:
        print("note  Claude only (no Codex packaging)")
    for ce in cmk.get("plugins", []):
        if ce.get("name") not in [p.get("name") for p in plugins]:
            fail(".agents/plugins/marketplace.json lists %s, which is not in the Claude marketplace" % ce.get("name"))

    for f in git_files(root):
        if re.search(r"(\.bak|\.orig|\.rej|~)$", f) or os.path.basename(f) == ".DS_Store":
            fail("stray file tracked: " + f)

    hp = os.path.join(root, "scripts", "kit.sha256")
    if not os.path.exists(hp):
        fail("scripts/kit.sha256 is missing (run plugin-kit's sync.sh)")
    else:
        listed = {}
        for ln in open(hp).read().splitlines():
            if ln.strip():
                h, _, p = ln.partition("  ")
                listed[p] = h
        for f in KIT_FILES:
            if f not in listed:
                fail("%s is not listed in scripts/kit.sha256" % f)
            elif not os.path.exists(os.path.join(root, f)):
                fail("%s is missing" % f)
            elif sha(os.path.join(root, f)) != listed[f]:
                fail("%s differs from the plugin-kit copy (edit it in plugin-kit, then run sync.sh)" % f)

    render = os.path.join(root, "scripts", "kit", "render.py")
    if os.path.exists(render):
        r = subprocess.run([sys.executable, render, "--check", "--root", root], capture_output=True, text=True)
        for ln in (r.stdout + r.stderr).splitlines():
            if ln.strip():
                fail(ln.strip())

    snippet, ci = os.path.join(root, "scripts/kit/ci-manifests.yml"), os.path.join(root, ".github/workflows/ci.yml")
    if os.path.exists(snippet) and os.path.exists(ci):
        want = open(snippet).read().strip("\n")
        m = re.search(r"^[^\n]*# kit:manifests:start.*?# kit:manifests:end[^\n]*$", open(ci).read(), re.S | re.M)
        if not m:
            fail(".github/workflows/ci.yml lacks the kit:manifests job (see scripts/kit/ci-manifests.yml)")
        elif m.group(0).strip("\n") != want:
            fail(".github/workflows/ci.yml: the kit:manifests job differs from scripts/kit/ci-manifests.yml")

    if "--validate" in argv:
        targets = ["."] + sorted({r for r in roots if r != "."})
        for t in targets:
            r = subprocess.run(["claude", "plugin", "validate", "--strict", t], cwd=root, capture_output=True, text=True)
            if r.returncode != 0:
                fail("claude plugin validate --strict %s: %s" % (t, (r.stdout + r.stderr).strip()[-400:]))
            else:
                print("ok    claude plugin validate --strict %s" % t)

    print("check-manifests: %s" % ("OK" if not errors else "%d problem(s)" % len(errors)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
