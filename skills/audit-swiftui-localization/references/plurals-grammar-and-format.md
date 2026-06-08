# Reference — Pluralization, grammar agreement & locale-aware formatting (loc-06/07)

The two ways a translated string is still *wrong* after the literal reaches the catalog: it was
assembled by string-building (so plurals and grammar can't vary per language), or a number/date was
formatted with a locale-unaware API. Floor values: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.
✅ shapes are the swiftui-ctx consensus (`swiftui-ctx lookup <api> --json`); verify via Sosumi.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## loc-06 — sentences built by interpolation / `+` (no plural or grammar agreement)

Plural rules differ wildly across languages (English has 2 forms, Arabic has 6, Russian has 3). Grammar
agreement (gender, case) cannot be expressed by gluing Swift strings together. The catalog handles this
**if** the variable is interpolated into a *localizable literal* and the variations are authored in the
catalog (the `%lld`/`%@` placeholders + automatic grammar agreement, `^[…](inflect: true)`).

```swift
// ❌ assembled in Swift — frozen to one plural form, no agreement
Text("\(count) items selected")
Text("Deleted " + String(count) + " files")
// ✅ a localizable literal with a placeholder; author plural variations in the String Catalog
Text("\(count) items selected")   // SAME source line — but the catalog key now has plural variations
// (the catalog stores: "%lld item selected" / "%lld items selected", varied per language)
// grammar agreement example (automatic, via the catalog's inflect markup):
Text("^[\(count) file](inflect: true) remaining")
```

The defect is **not** the interpolation syntax itself — it is the absence of catalog plural/inflect
variations behind it (or, worse, building the whole sentence with `+`). The lint tell
`Text("…\(…)")` LOCATES; READ confirms whether the catalog varies it. `InflectionRule` /
automatic grammar agreement is **macOS 12.0+** (floors-master). Reach for `String(localized:)` with a
`String.LocalizationValue` when the string is built outside a `Text`.

## loc-07 — locale-unaware number/date formatting

`String(format: "%.2f", price)`, a hand-built `DateFormatter`/`NumberFormatter` without a `\.locale`,
or `value.description` all hard-code US conventions (decimal point, MDY dates, no grouping). Use a
**`FormatStyle`** — it reads the environment locale automatically:

```swift
// ❌ locale-unaware
Text("Total: " + String(format: "%.2f", amount))
let df = DateFormatter(); df.dateStyle = .medium       // no locale set → device-default, not content
// ✅ FormatStyle / .formatted() — locale-aware, no manual formatter
Text(amount, format: .currency(code: "USD"))
Text(count, format: .number)
Text(date, format: .dateTime.year().month().day())
Text(date.formatted(.relative(presentation: .named)))
```

`Text.init(_:format:)` (the `FormatStyle` overload) is **macOS 15.0+**; `.formatted()` / `FormatStyle`
on the value types are macOS 12.0+ (floors-master). When the formatted value is *async-loaded* data, the
date/number `FormatStyle` choice seams to `audit-swiftui-async-data` — note and route, don't double-own.

A formatter that *is* given an explicit `\.locale` and is genuinely needed (e.g. parsing a fixed wire
format) is not loc-07 — that is correct, deliberate locale control.

---

## Sources

- Apple — `FormatStyle`, `Text.init(_:format:)`, String Catalog plural/grammar variations,
  `InflectionRule`, fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/foundation/formatstyle`,
  `/documentation/swiftui/text/init(_:format:)`,
  `/documentation/foundation/formatstyle/numberformatstyle`,
  `/documentation/xcode/localizing-strings-that-contain-plurals`.
- WWDC21 — "What's new in Foundation" (`/videos/play/wwdc2021/10109`, `FormatStyle`; grammar agreement engine); WWDC23 — "Discover
  String Catalogs" (`/videos/play/wwdc2023/10155`, plurals & grammar agreement), via Sosumi.
