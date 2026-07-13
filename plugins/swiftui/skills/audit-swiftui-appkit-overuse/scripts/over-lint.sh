#!/usr/bin/env bash
# over-lint.sh — thin pointer. This skill has no bespoke linter; it inherits the toolkit's ONE shared
# hybrid lint engine fed declarative rule files (the pattern every audit skill uses).
#
# Rules for this skill live in:   ../lint/grep-tells.tsv       (tier 1 — flat grep tells)
#                                 ../lint/ast-grep/*.yml       (tier 2 — the structural ast-grep rule)
# The engine + rule-file format + JSON/SARIF shape + safety rails:
#                                 ${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md
#
# Run the shared runner (it forwards every arg to swiftui-lint.sh):
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/scripts/swiftui-lint.sh" \
  --skill audit-swiftui-appkit-overuse "$@"
