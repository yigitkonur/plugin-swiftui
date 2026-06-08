# eval results — swiftui-ctx grounded vs baseline

Deterministic scoring (no human/LLM judge): `swiftc -parse`, deprecated-token count, audit-swiftui-api-currency lint findings, modern-shape regex. Lower deprecated/lint = better.

| task | parses (b/g) | deprecated (b→g) | lint (b→g) | modern shape (b→g) |
|---|---|---|---|---|
| foreground-style | ✓/✓ | 1→0 | 1→0 | 0→1 |
| observable-model | ✓/✓ | 1→0 | 0→0 | 0→1 |
| corner-radius | ✓/✓ | 1→1 | 1→0 | 0→1 |
| tabs | ✓/✓ | 2→0 | 2→0 | 0→1 |
| tint-control | ✓/✓ | 1→0 | 1→0 | 0→1 |

**5 task pairs scored.** grounded wins: modern-shape 5/5 · fewer-deprecated 4/5 · fewer-lint-findings 4/5.

