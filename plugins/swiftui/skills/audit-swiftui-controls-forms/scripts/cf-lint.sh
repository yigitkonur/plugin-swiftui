#!/usr/bin/env bash
# cf-lint.sh — thin pointer. There is no bespoke grep script: the toolkit ships ONE shared hybrid lint
# engine fed declarative rule files (the pattern every audit skill inherits).
#
# Rules for this skill live in:   ../lint/grep-tells.tsv       (tier 1 — flat grep tells: cf-01..cf-08)
#                                 ../lint/ast-grep/*.yml       (tier 2 — structural: cf-01 form-without-
#                                                               formstyle, cf-02 custom-view-not-focusable)
# The engine + rule-file format + JSON/SARIF shape + safety rails:
#                                 ${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md
#
# Run the shared runner instead (it forwards every arg to swiftui-lint.sh):
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/scripts/swiftui-lint.sh" \
  --skill audit-swiftui-controls-forms "$@"
