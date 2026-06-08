#!/usr/bin/env bash
# eval generator — reads a prompt on stdin, returns the model's reply (Swift) on stdout.
# Uses `codex exec` headless, READ-ONLY, in a throwaway dir so it generates text and never touches the repo.
# Wire it in:  EVAL_GEN_CMD='bash eval/gen-codex.sh' make eval
set -uo pipefail
prompt="$(cat)"
tmp="$(mktemp -d)"; msg="$(mktemp)"
printf '%s' "$prompt" \
  | codex exec -s read-only --skip-git-repo-check -C "$tmp" --color never \
      --output-last-message "$msg" - >/dev/null 2>&1 || true
cat "$msg" 2>/dev/null
rm -rf "$tmp" "$msg"
