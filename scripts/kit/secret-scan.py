#!/usr/bin/env python3
"""secret-scan.py: fail on secrets and personal data in a plugin repo. Vendored as scripts/kit/secret-scan.py.

  python3 scripts/kit/secret-scan.py [--tree] [--history]      (default: --tree)

Flags: token shapes (Cloudflare, GitHub, Anthropic/OpenAI, AWS, Slack, Sentry, private keys), tracked .env files, a personal
absolute path (/Users/<name>/, /home/<name>/ other than placeholders) and a personal gmail address. A repo can exempt paths
(prefixes, one per line) in .github/secret-scan-ignore, e.g. recorded fixtures that were scrubbed by hand.
"""
import os
import re
import subprocess
import sys

PATTERNS = [
    ("Cloudflare token", re.compile(r"\b(?:cfat|cfut|cfk)_[A-Za-z0-9]{30,}|Bearer [A-Za-z0-9_-]{40}\b")),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{50,}")),
    ("Anthropic/OpenAI key", re.compile(r"\bsk-(?:ant|proj)-[A-Za-z0-9_-]{20,}")),
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("Slack token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}")),
    ("Sentry auth token", re.compile(r"\bsntry[su]_[A-Za-z0-9+/=_-]{40,}")),
    ("private key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----")),
    ("Live View / CDP URL with a credential", re.compile(r"live\.browser\.run/[^ \"]*[?&](?:wss|jwt|token)=[A-Za-z0-9._~%-]{8,}")),
    ("personal e-mail", re.compile(r"[A-Za-z0-9._+-]+@gmail\.com")),
]
# Require an absolute-path boundary; nested repository paths are not home directories.
USER_PATH = re.compile(r"(?<![A-Za-z0-9_./-])(?:/Users/([A-Za-z0-9._-]+)/|/home/([a-z][a-z0-9_-]*)/)")
PLACEHOLDER_USERS = {"you", "your-name", "yourname", "name", "user", "username", "me", "example", "shared", "runner", "ubuntu", "node", "app", "vscode", "alice", "bob", "foo", "dev", "someone", "x"}
ENV_FILE = re.compile(r"(^|/)\.env(\..+)?$|(^|/)lab\.env$")


def git(*args, root="."):
    r = subprocess.run(["git", "-C", root] + list(args), capture_output=True, text=True, errors="replace")
    return r.stdout


def scan_text(label, text, found):
    for name, rx in PATTERNS:
        if rx.search(text):
            found.add("%s: %s" % (label, name))
    for m in USER_PATH.finditer(text):
        user = (m.group(1) or m.group(2) or "").lower()
        if user not in PLACEHOLDER_USERS:
            found.add("%s: local path of a real user (%s)" % (label, m.group(0)))
            break


def main(argv):
    root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip() or "."
    modes = [a for a in argv if a in ("--tree", "--history")] or ["--tree"]
    ignore = []
    ip = os.path.join(root, ".github", "secret-scan-ignore")
    if os.path.exists(ip):
        ignore = [ln.strip() for ln in open(ip).read().splitlines() if ln.strip() and not ln.startswith("#")]
    skip = lambda p: any(p.startswith(i) for i in ignore) or re.search(r"(^|/)(node_modules|dist)/|package-lock\.json$|\.lock$", p)
    found = set()
    if "--tree" in modes:
        files = [f for f in git("ls-files", "-co", "--exclude-standard", root=root).splitlines() if not skip(f)]
        for f in files:
            if ENV_FILE.search(f) and not f.endswith(".env.example"):
                found.add("tree: .env file %s" % f)
                continue
            try:
                data = open(os.path.join(root, f), "rb").read()
            except OSError:
                continue
            if b"\0" in data[:4096]:
                continue
            scan_text("tree " + f, data.decode("utf-8", "replace"), found)
    if "--history" in modes:
        if not git("rev-parse", "--verify", "-q", "HEAD", root=root).strip():
            print("secret-scan: no commits yet")
        else:
            names = set(git("log", "--all", "--name-only", "--pretty=format:", root=root).splitlines())
            for n in names:
                if n and ENV_FILE.search(n) and not n.endswith(".env.example") and not skip(n):
                    found.add("history: .env file %s existed" % n)
            excl = [":(exclude)%s" % i.rstrip("/") for i in ignore] + [":(exclude)package-lock.json", ":(exclude)**/dist/**", ":(exclude)**/node_modules/**"]
            scan_text("history", git("log", "--all", "-p", "--pretty=format:", "--", ".", *excl, root=root), found)
    for f in sorted(found):
        print("secret-scan: " + f, file=sys.stderr)
    if not found:
        print("secret-scan: clean (%s)" % " ".join(m[2:] for m in modes))
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
