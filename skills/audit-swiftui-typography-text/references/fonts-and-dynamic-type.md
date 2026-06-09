# Reference — Fonts, Dynamic Type & Monospaced Digits (txt-02 · txt-03 · txt-08)

How fonts are sized so Dynamic Type scales them, the deprecation of the design-only `Font.system`
overload, and stopping live numerics from jiggling. Floor *values* live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## txt-02 — `Font.system(_:design:)` design-only overload (deprecated macOS 26.5)

Per floors-master, `Font.system(_:design:)` (the overload with **no `weight:`**) is **deprecated at
macOS 26.5** → the current overload `Font.system(_:design:weight:)` (macOS 13.0+). The currency *flag* is
api-currency's; this skill owns the craft → emit `cross_ref: api-currency`. This is `fix_mode: auto`: the
mechanical single-answer fix is appending `weight: .regular`.

### ❌ Wrong
```swift
.font(.system(.title, design: .rounded))
```
### ✅ Correct
```swift
.font(.system(.title, design: .rounded, weight: .regular))
```
> grep cannot see that `weight:` is *absent* (the `design:` tell fires on both overloads) — READ the call
> to confirm there is no `weight:` argument before reporting.

## txt-03 — hardcoded font size defeats Dynamic Type

`.font(.system(size: 14))` freezes the glyph size; it ignores the user's text-size setting and breaks
Larger-Text accessibility. This skill owns the mechanics; the trait-level audit is
`audit-swiftui-accessibility` → emit `cross_ref: accessibility`.

### ❌ Wrong
```swift
Text(title).font(.system(size: 17))
Image(systemName: "gear").font(.system(size: 22))
```
### ✅ Correct — a semantic text style (scales automatically)
```swift
Text(title).font(.body)                       // or .system(.body, design: .default, weight: .regular)
```
### ✅ Correct — `@ScaledMetric` when a literal dimension is unavoidable (icons, custom metrics)
Canonical shape from the corpus (`swiftui-ctx lookup ScaledMetric` — consensus `(relativeTo: .body)`, 36%,
recommended example `cmsj/Hammerspoon2` `SettingsConfigView.swift#L23`):
```swift
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 12
Image(systemName: "gear").font(.system(size: iconSize))
```
`@ScaledMetric` is macOS 11.0+ (floors-master) — no gating needed on any modern target.

## txt-08 — live numerics missing `monospacedDigit()`

Proportional digits have unequal widths, so a counter/timer/price that updates each frame re-flows ("digit
jiggle"). Apply `.monospacedDigit()` (or a monospaced-digit font) to fix the column width. grep
over-locates (`.formatted()` / `format:` is common and most is static) — READ to confirm the value updates
live before reporting.

### ❌ Wrong
```swift
Text(elapsed, format: .number)                 // ticks every frame, width shifts
```
### ✅ Correct
```swift
Text(elapsed, format: .number).monospacedDigit()
```

---

## Sources

- `Font.system` overloads + deprecation: `https://sosumi.ai/documentation/swiftui/font/system(_:design:weight:)`
  (access 2026-06-07); floor/deprecation values reconciled in `_shared/floors-master.md`.
- Dynamic Type / `@ScaledMetric`: `https://sosumi.ai/documentation/swiftui/scaledmetric` (access 2026-06-07);
  consensus shape + recommended example via `swiftui-ctx lookup ScaledMetric`
  (`github.com/cmsj/Hammerspoon2/.../SettingsConfigView.swift#L23`, accessed 2026-06-07).
- `monospacedDigit()`: `https://sosumi.ai/documentation/swiftui/text/monospaceddigit()` (access 2026-06-07).
- HIG Typography: `developer.apple.com/design/human-interface-guidelines/typography` (Dynamic Type guidance).
