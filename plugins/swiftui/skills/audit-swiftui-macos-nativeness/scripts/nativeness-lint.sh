#!/usr/bin/env bash
# nativeness-lint.sh — thin pointer to the toolkit's ONE shared hybrid lint engine, fed this skill's
# declarative rule files (the pattern every audit skill inherits).
#
# Rules for this skill live in:   ../lint/grep-tells.tsv       (tier 1 — flat grep tells / locators)
#                                 ../lint/ast-grep/*.yml       (tier 2 — structural ast-grep rules)
# Engine + rule-file format + JSON/SARIF shape + safety rails:
#                                 ${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md
#
# Run the shared runner (it forwards every arg to swiftui-lint.sh):
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/scripts/swiftui-lint.sh" \
  --skill audit-swiftui-macos-nativeness "$@"
