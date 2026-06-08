# Reference — The 0-100 Nativeness Score & Dashboard

How the meta-audit turns the confirmed smell set into a single **0-100 "iPad-in-a-window" nativeness
score** and a prioritized punch-list, and the exact layout of the `kind: nativeness-dashboard`
`_index.md`. The score is **deterministic from the confirmed findings** (step DETECT, 100%-certainty
only) — never a vibe. The finding schema this index summarizes is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md`.

**As of:** 2026-06-07.

---

## 1. The scoring model (deterministic)

Start at **100** (a perfectly Mac-native app) and **deduct per confirmed smell**, capped per category so
one noisy category can't sink the whole score. Weights reflect how loudly each smell reads as non-native.

| Category (owner) | Smells | Per-instance deduction | Category cap |
|---|---|---|---|
| Pointer affordances (pointer-gestures) | nat-01, nat-04, nat-05, nat-15 | 3 (warn) / 2 (adv) | −20 |
| Control density & forms (controls-forms) | nat-02, nat-03, nat-06, nat-07 | 3 (warn) / 2 (adv) | −20 |
| Data grid & windows (layout-and-tables / scenes-windows) | nat-08, nat-09, nat-10 | 4 | −20 |
| Navigation shell (navigation-toolbars) | nat-11, nat-12 | 5 | −20 |
| Menus & scenes (menus-commands / scenes-windows) | nat-13, nat-14 | 6 | −20 |

`score = max(0, 100 − Σ min(category_cap, Σ per-instance deductions))`.

- **Count distinct sites**, not repeated lines (5 rows missing `.onHover` in one reused row view = **1**
  instance, the view). De-dup by view, not by call site.
- A smell suppressed by the **floor** (e.g. missing `pointerStyle` under a macOS-14 target) is **not**
  counted — it isn't available to expect.
- Structural/shell smells weigh most (nav, menus, scenes) because they shape the *whole* app's feel; a
  single missing tooltip weighs least.

**Bands:** 90–100 *native* · 75–89 *mostly native, polish* · 50–74 *reads iOS-flavored* · 25–49 *clearly
an iPad app in a window* · 0–24 *iOS port, un-Mac-ified*.

---

## 2. The `nativeness-dashboard` `_index.md` layout

Write `swiftui-audits/macos-nativeness/_index.md` with `kind: nativeness-dashboard` in its frontmatter,
then this body, in order:

```markdown
---
kind: nativeness-dashboard
domain: macos-nativeness
score: 68
band: reads iOS-flavored
deployment_target: macOS 14.0
generated_on: 2026-06-07
findings: 9
---

# macOS Nativeness — 68 / 100  (reads iOS-flavored)

## Score breakdown
| Category | Smells found | Deduction | Owner skill |
|---|---|---|---|
| Navigation shell | nat-11 ×1 | −5 | audit-swiftui-navigation-toolbars |
| Menus & scenes | nat-14 ×1 | −6 | audit-swiftui-menus-commands / -scenes-windows |
| Pointer affordances | nat-01 ×3, nat-04 ×2 | −15 | audit-swiftui-pointer-gestures |
| Control density & forms | nat-06 ×1, nat-07 ×1 | −5 | audit-swiftui-controls-forms |
| Data grid & windows | nat-08 ×1 | −4 | audit-swiftui-layout-and-tables |
| **Total** |  | **−32** |  |

## Prioritized punch-list (route each to its owner skill)
1. [nat-11] ContentView wraps the app in NavigationStack → run **audit-swiftui-navigation-toolbars** · `navigation-shell/01-…md`
2. [nat-14] No Settings {} scene; prefs are in-window → run **audit-swiftui-menus-commands** · `menus-scenes/01-…md`
3. [nat-01] RowView has no .onHover (3 sites) → run **audit-swiftui-pointer-gestures** · `pointer-affordances/…`
…

## How to act
This is a META-AUDIT: it routes, it does not fix. Run each owner skill above on the cited files; each
owns the ❌→✅, the floor, and any auto-fix.
```

**Punch-list ordering:** by category weight descending (shell > menus/scenes > data-grid > pointer >
density), then by site count within a category. Structural shell fixes first — they move the score most.

---

## 3. Re-run stability

The score is a pure function of the confirmed finding set, so two runs over unchanged code produce the
**same score and the same dashboard**. After any FIX by a routed owner skill, re-run this meta-audit to
watch the score climb — that is its purpose as the toolkit's nativeness gauge.

---

## Sources

Internal scoring model; cites no external API. The smell definitions + their Apple-doc sources are in
`smell-catalog.md`; the finding schema this index summarizes is the shared
`${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md` (`macos-nativeness` writes its `_index.md`
with the `kind: nativeness-dashboard` discriminator per that schema §1).
