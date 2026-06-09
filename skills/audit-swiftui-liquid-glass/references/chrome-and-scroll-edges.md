# Reference — Chrome Auto-Adoption & Scroll-Edge Effects

How macOS 26 hands chrome glass for free, the leftover overrides that block it, scroll-edge effects,
and the constrained-`TextEditor` opaque-toolbar trap. Floors live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; real symbols in `glass-api-surface.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## Free chrome — what auto-adopts glass on an SDK rebuild

Recompiling on the macOS 26 SDK **auto-glasses** standard chrome: Toolbar, Sidebar, Menu bar, Dock,
Window controls, `NSPopover`, and Sheets. Hand-applying `.glassEffect()` to chrome that already adopts
glass fights the system and risks glass-on-glass.

**glass-10 — re-glassed free chrome (warning, flag-only).** `.glassEffect()` on a
`NavigationSplitView` sidebar, a `.toolbar`, or a sheet container.
✅ rely on auto-adoption; hand-apply glass only to genuinely custom floating controls. Use
`backgroundExtensionEffect()` to extend content under a sidebar/inspector rather than glassing the
sidebar itself.

> **Auto-adoption opportunity finder (go-beyond):** detect hand-applied `.glassEffect()` on chrome that
> would adopt glass for free and recommend **deleting** the manual call — the inverse of the usual "add
> glass" advice.

---

## Leftover overrides that BLOCK glass

**glass-11 — deprecated toolbar overrides left on the toolbar (warning; fix_mode: auto).**
`.toolbarBackground(.visible, …)` (formally deprecated macOS 13.0–exact closing version: verify against Xcode 26 SDK) and `.toolbarColorScheme(_:)`
**block glass rendering** on the toolbar. Under auto-glass they have no purpose; removal restores intended rendering.
Safe to auto-fix (deletion only). (`toolbarBackgroundVisibility(_:for:)` is itself macOS 15.0+ — see
floors-master — and is the symbol used to *hide* a shared toolbar background where that is the goal.)

macOS title-bar/toolbar polish that frequently accompanies glass adoption (flag, show the pattern):
`.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`, `window.titlebarAppearsTransparent`,
`ToolbarItemGroup` + `.sharedBackgroundVisibility(.hidden)` to split the shared glass background.

---

## Scroll-edge effects

`scrollEdgeEffectStyle(_:for:)` styles the automatic/soft/hard fade where content meets chrome;
`scrollEdgeEffectHidden(_:for:)` removes it. Both are macOS 26.0+ (floors-master). Apple's own example
uses `.scrollEdgeEffectStyle(.hard, for: .all)`, confirming `.hard` is a valid macOS style.

> **VERIFY AGAINST XCODE 26 SDK — do not assert as fact:** the macOS scroll-edge **default** style
> (`.hard` claimed; iOS `.soft`) is observed behavior, not a scraped fact. Carry it as advisory with the
> unverified flag; confirm on a Mac before stating it.

**glass-12 — `TextEditor` in a `NavigationSplitView` detail forces an opaque toolbar (warning,
flag-only — community-sourced).** A constrained scroll region in the detail column drags the window
toolbar to opaque-with-border, losing glass for the whole window.
```swift
// ✅ soften the top scroll edge on the constrained editor
TextEditor(text: $text)
    .scrollEdgeEffectStyle(.soft, for: .top)
```
> **VERIFY AGAINST XCODE 26 SDK:** this pitfall is community-sourced and may not reproduce on every
> layout. Flag it, show the `.soft` suggestion, never silent-fix; confirm on a Mac.

---

## Double transparency

**glass-13 — `.glassEffect()` + `.background(.ultraThinMaterial)` on one view (advisory, flag-only).**
Two transparency systems stacked on one view. ✅ use one system per view (branch, don't stack).
> **VERIFY AGAINST XCODE 26 SDK:** an early-beta crash from this combination is community-reported and
> **unverified** against the shipping SDK. Flag as advisory; never assert the crash as fact.

---

## Sources

- Apple — "Adopting Liquid Glass" (auto-adoption of system bars, `backgroundExtensionEffect`
  rationale): `https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass`
  (via Sosumi, accessed 2026-06-07).
- Apple — `scrollEdgeEffectStyle(_:for:)` / `scrollEdgeEffectHidden(_:for:)` / `backgroundExtensionEffect()`,
  macOS 26.0+: `/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)` etc. (via Sosumi, 2026-06-07).
- tgrinblatt/tyler-app-style (shipping macOS-26 title-bar/toolbar reference):
  `https://github.com/tgrinblatt/tyler-app-style` (accessed 2026-06-07, medium trust — corroboration
  only).
- Community report of the constrained-`TextEditor` opaque-toolbar pitfall and the double-transparency
  crash — unverified; carried as flags, not facts.
