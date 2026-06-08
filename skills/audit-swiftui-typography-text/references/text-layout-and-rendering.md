# Reference — Text Layout & Rendering (txt-04 · txt-06 · txt-07)

Reserving line space, the `TextRenderer` / `textRenderer(_:)` floor split, and replacing hand-rolled label
rows with `LabeledContent`. Floor *values* live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the macOS-arm gating rule is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` — read, never restate.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## txt-04 — `.lineLimit(N)` without `reservesSpace:` (layout jump)

A bare integer `lineLimit` lets the frame grow/shrink as content arrives, so neighbouring views jump.
`lineLimit(_:reservesSpace:)` (macOS 13.0+, floors-master) pins the height to `N` lines up front. The corpus
consensus for `lineLimit` is `(_)` at 100% — i.e. most code ships the bare form, which is exactly the smell
when the frame must stay stable.

### ❌ Wrong
```swift
Text(subtitle).lineLimit(2)                    // collapses to 1 line when subtitle is short → row reflows
```
### ✅ Correct
```swift
Text(subtitle).lineLimit(2, reservesSpace: true)
```
Not every bare `lineLimit` is a defect (a list cell that genuinely flexes is fine) — READ to confirm a
stable frame is wanted. `.lineLimit(nil)` / `.lineLimit(.max)` are out of scope (the grep tell matches only
integers).

## txt-06 — `TextRenderer` / `textRenderer(_:)` floor split

Two distinct floors (floors-master): the **`TextRenderer` protocol is macOS 14.0+**, but the
**`textRenderer(_:)` *modifier* that applies one is macOS 15.0+**. A view that conforms to `TextRenderer`
and applies it with `.textRenderer(...)` must be gated to the **higher** floor (15.0) and on the **macOS
arm** (`#available(macOS 15, *)`, never `iOS`) per the shared arm-gating rule. Report only when the
deployment target is below the relevant floor.

### ❌ Wrong (ungated under a <15 floor)
```swift
someText.textRenderer(MyRenderer())            // crashes/won't build below macOS 15
```
### ✅ Correct
```swift
if #available(macOS 15, *) {
    someText.textRenderer(MyRenderer())
}
```
Canonical real usage from the corpus (`swiftui-ctx lookup textRenderer` recommended example):
`urbanairship/ios-library` `Airship/AirshipCore/Source/Label.swift#L96`.

## txt-07 — hand-rolled label row → `LabeledContent`

`LabeledContent` (macOS 13.0+, floors-master) renders a label/value pair with native alignment,
`Form`/`Settings` styling, and accessibility. A hand-rolled `HStack { Text(label); Spacer(); Text(value) }`
loses all of that. The grep tell (`HStack { … Spacer() … }`) over-locates — READ to confirm it is a
label/value row (typically inside a `Form`) before reporting.

### ❌ Wrong
```swift
HStack { Text("Version"); Spacer(); Text(version) }
```
### ✅ Correct
```swift
LabeledContent("Version", value: version)
```

---

## Sources

- `lineLimit(_:reservesSpace:)`: `https://sosumi.ai/documentation/swiftui/view/linelimit(_:reservesspace:)`
  (access 2026-06-07); consensus shape via `swiftui-ctx lookup lineLimit`.
- `TextRenderer` (protocol) / `textRenderer(_:)` (modifier) floors:
  `https://sosumi.ai/documentation/swiftui/textrenderer` and `.../view/textrenderer(_:)` (access 2026-06-07);
  reconciled in `_shared/floors-master.md`; real usage via `swiftui-ctx lookup textRenderer`
  (`github.com/urbanairship/ios-library/.../Label.swift#L96`, accessed 2026-06-07).
- `LabeledContent`: `https://sosumi.ai/documentation/swiftui/labeledcontent` (access 2026-06-07).
- WWDC23 session 10157 "Create animated symbols & rich text rendering" (TextRenderer).
