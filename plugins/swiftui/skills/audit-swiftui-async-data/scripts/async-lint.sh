#!/usr/bin/env bash
# async-lint.sh — thin pointer. The toolkit uses ONE shared hybrid lint engine fed declarative rule files
# (the pattern every audit skill inherits). Rules for this skill live in:
#   ../lint/grep-tells.tsv       (tier 1 — flat grep tells)
#   ../lint/ast-grep/*.yml       (tier 2 — structural ast-grep rules)
# Engine + rule-file format + JSON/SARIF shape + safety rails:
#   ${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md
#
# Run the shared runner instead (it forwards every arg to swiftui-lint.sh):
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/scripts/swiftui-lint.sh" \
  --skill audit-swiftui-async-data "$@"
