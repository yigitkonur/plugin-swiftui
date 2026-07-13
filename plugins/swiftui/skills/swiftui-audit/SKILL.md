---
name: swiftui-audit
description: Run the full evidence-backed macOS SwiftUI audit suite over a project. Use only when explicitly requested with $swiftui-audit.
---

# Full macOS SwiftUI audit

## Bundled resource root

Let `<swiftui-plugin-root>` be the absolute plugin directory two levels above this `SKILL.md`. Resolve that path before running commands and shared references.

1. Resolve the requested target, defaulting to the current directory. Create the output directory and persist the relevance scan:

   ```bash
   mkdir -p swiftui-audits
   python3 "<swiftui-plugin-root>/scripts/audit-scan.py" "<target>" --json swiftui-audits/_scan.json
   ```

2. Read `<swiftui-plugin-root>/skills/audit-macos-swiftui-full/SKILL.md` completely. Follow that orchestrator using `_scan.json` and preserve its dependency waves: guards; state and data; UI domains; boundaries and scoring.
3. When collaboration tools are available, run independent auditors in the same wave concurrently. Otherwise run them serially in the listed order.
4. Write per-finding Markdown under `swiftui-audits/` using `<swiftui-plugin-root>/references/_shared/finding-schema.md`, then create `_SUMMARY.md` and its 0–100 nativeness score.
5. Read `.swiftui-plugin/settings.md`, falling back to `.claude/swiftui.local.md`. With `strict_audit: true` or no setting, label hard findings release-blocking. With `strict_audit: false`, label the same findings advisory. The mechanical `audit-gate.sh` accepts matching `--strict` and `--advisory` modes for CI exit behavior.
6. Apply fixes only when the user requested them and the shared fix-safety protocol permits them. Keep all other findings open.

The lint engine locates candidates; every reported finding still requires source inspection and verification through the bundled corpus and current Apple documentation.
