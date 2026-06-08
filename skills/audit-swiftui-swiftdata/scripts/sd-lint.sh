#!/usr/bin/env bash
# sd-lint.sh — thin pointer. The toolkit uses ONE shared hybrid lint engine fed declarative rule files
# (the pattern every audit skill inherits). This skill's rules live in:
#   ../lint/grep-tells.tsv       (tier 1 — flat grep tells, sd-01/03/04/05/06/07/08/09/10/11/12)
#   ../lint/ast-grep/*.yml       (tier 2 — structural rules: sd-01 let-on-@Relationship,
#                                 sd-02 relationship-assigned-in-init, sd-11 @Model-subclass)
# Engine + rule-file format + JSON/SARIF shape + safety rails:
#   ${CLAUDE_PLUGIN_ROOT}/references/_shared/lint-architecture.md
#
# Run the shared runner (it forwards every arg to swiftui-lint.sh):
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/scripts/swiftui-lint.sh" \
  --skill audit-swiftui-swiftdata "$@"
