# Reference — Right-to-left layout & layout direction (loc-08/10)

Arabic, Hebrew, Farsi, and Urdu read right-to-left; AppKit/SwiftUI mirror most layout automatically
**if** the code uses direction-relative APIs. The defects are the places that hard-code a physical
direction. Floor values: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. Verify symbols via
Sosumi (`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`).

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## What mirrors for free (so it is NOT a defect)

SwiftUI's alignments are already direction-relative: `.leading`/`.trailing`, `HorizontalAlignment`,
`Edge.Set.leading`/`.trailing`, `.padding(.leading, …)`, `HStack` ordering — all flip automatically in
RTL. Do **not** flag `.leading`/`.trailing`; they are the correct, RTL-safe choice. (`TextAlignment`
has only `.leading`/`.center`/`.trailing` — there is no `.left`, so there is nothing to migrate there.)

## loc-08 — directional SF Symbols don't mirror

A *named-direction* SF Symbol (`"arrow.left"`, `"chevron.right"`, `"arrow.right.circle"`) shows the same
glyph in RTL, so a "back" chevron points the wrong way for an RTL reader. The **semantic** symbols
(`.backward`/`.forward`, e.g. `"chevron.backward"`, `"arrow.backward"`) mirror automatically.

```swift
// ❌ physical direction — does not mirror
Image(systemName: "chevron.left")
Label("Back", systemImage: "arrow.left")
// ✅ semantic direction — mirrors in RTL
Image(systemName: "chevron.backward")
Label("Back", systemImage: "arrow.backward")
```

For a custom asset that genuinely encodes direction and must flip, use
`.flipsForRightToLeftLayoutDirection(true)` (or provide a mirrored asset). A symbol that is *not*
directional in meaning (`"arrow.left"` used as a decorative logo) is not loc-08 — READ to decide.

## loc-10 — hard-coded horizontal offset / position

`.offset(x:)` and `.position(x:)` use absolute coordinates that do not mirror; a badge nudged
`+8` to the right stays on the right in RTL, landing on the wrong edge. Derive the sign from the
environment, or prefer alignment/padding which mirror:

```swift
// ❌ absolute — same physical side in every language
.offset(x: 8)
// ✅ direction-aware
@Environment(\.layoutDirection) private var layoutDirection
…
.offset(x: layoutDirection == .rightToLeft ? -8 : 8)
// ✅ better — use a mirroring layout primitive instead of an offset
.padding(.trailing, 8)
```

A vertical-only `.offset(y:)` is unaffected by RTL (not a defect). The broader concern of **mirroring
whole layout containers** seams to `audit-swiftui-layout-and-tables` — note and route, don't double-own.
Preview coverage of `\.layoutDirection` (and `\.locale`) seams to `audit-swiftui-previews`.

---

## Sources

- Apple — `layoutDirection`, `flipsForRightToLeftLayoutDirection(_:)`, SF Symbols directionality,
  fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/swiftui/environmentvalues/layoutdirection`,
  `/documentation/swiftui/view/flipsforrighttoleftlayoutdirection(_:)`,
  `/documentation/swiftui/layoutdirection`.
- WWDC — "Get it right ... to left" (`/videos/play/wwdc2022/10107`), via Sosumi; Apple HIG — Right to
  left (`/design/human-interface-guidelines/right-to-left`).
