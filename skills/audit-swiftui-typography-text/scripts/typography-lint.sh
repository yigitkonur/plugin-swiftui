#!/usr/bin/env bash
# typography-lint.sh — thin pointer. The toolkit uses ONE shared hybrid lint engine fed declarative rule
# files (the pattern every audit skill inherits).
#
# Rules for this skill live in:   ../lint/grep-tells.tsv       (tier 1 — flat grep tells, txt-01 … txt-09)
#                                 ../lint/ast-grep/*.yml       (tier 2 — structural Text + Text rule)
# The engine + rule-file format + JSON/SARIF shape + safety rails:
#                                 ${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md
#
# Run the shared runner instead (it forwards every arg to swiftui-lint.sh):
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/scripts/swiftui-lint.sh" \
  --skill audit-swiftui-typography-text "$@"
