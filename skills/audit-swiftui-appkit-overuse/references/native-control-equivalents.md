# Reference — AppKit Control → SwiftUI Control Map (over-01, over-05)

The 1:1 native replacements. When a representable wraps one of these *for plain use*, the bridge is
**overuse** — flag it and show the SwiftUI ✅. Confirm every replacement exists at the project's floor in
VERIFY (`swiftui-ctx lookup` + Sosumi) before flagging.

**As of:** 2026-06-07 · macOS 26 (Tahoe). All SwiftUI controls below are macOS 10.15+ unless noted.

---

## over-01 — the 1:1 control map

| AppKit (wrapped in a representable) | Native SwiftUI | Notes |
|---|---|---|
| `NSButton` | `Button(_:action:)` / `Button(role:)` | toggle-style `NSButton` → `Toggle` |
| `NSTextField` (plain) | `TextField(_:text:)` / `SecureField` | rich/first-responder use may be justified — see `justified-escape-hatches.md` |
| `NSSwitch` | `Toggle(_:isOn:)` | |
| `NSSlider` | `Slider(value:in:)` | |
| `NSStepper` | `Stepper(_:value:in:)` | |
| `NSColorWell` | `ColorPicker(_:selection:)` | macOS 11+ |
| `NSDatePicker` | `DatePicker(_:selection:)` | |
| `NSProgressIndicator` | `ProgressView()` / `ProgressView(value:)` | indeterminate + determinate; **macOS 11+** |
| `NSComboBox` / `NSPopUpButton` | `Picker(_:selection:)` `.pickerStyle(.menu)` | |
| `NSSegmentedControl` | `Picker(...)` `.pickerStyle(.segmented)` | |
| `NSImageView` | `Image(...)` / `AsyncImage` | |
| `NSLevelIndicator` | `Gauge(value:in:)` | macOS 13+ |

**The trap:** an `NSTextField` bridge is *not* automatically over-01 — it is a justified hatch when it
exists for precise first-responder / field-editor / insertion-point control. READ the bridge: if it
only sets/reads `.stringValue` and forwards a delegate, it is over-01; if it overrides
`acceptsFirstResponder` / reaches the field editor, it is justified (and interop owns its HOW).

## over-05 — AppKit glass → SwiftUI glass

`NSGlassEffectView` / `NSGlassEffectContainerView` are the **AppKit** Liquid Glass surfaces. In a
SwiftUI view, bridging them is overuse — SwiftUI has first-class glass: `.glassEffect(_:in:)`,
`GlassEffectContainer`, `.buttonStyle(.glass)` (all macOS 26.0+). Flag the bridge; the SwiftUI glass
*placement/grouping* rules (navigation-layer-only, no glass-on-glass, container grouping) are
`audit-swiftui-liquid-glass` — cross_ref it. Do not restate the glass rules here.

## The ✅ comes from swiftui-ctx, not from this table

The table tells you *which* SwiftUI control replaces the bridge. The **canonical example** in a finding's
`## Correct` / `## Source` is the swiftui-ctx consensus shape + a real permalink, not a hand-written
snippet:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup Toggle --json     # consensus shape + recommended.id
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx file <recommended.id> --smart   # the GitHub permalink for ## Source
```

Floor values (e.g. `ColorPicker` macOS 11, `Gauge` macOS 13) are the reconciled truth in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate. Confirm a SwiftUI
name is real (not an AI hallucination) against
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` and a `lookup` exit-3.

---

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://developer.apple.com/documentation/swiftui/toggle | primary-doc | high | `Toggle(_:isOn:)` — native replacement for `NSSwitch` / checkbox `NSButton`. macOS 10.15+. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/picker | primary-doc | high | `Picker` + `.pickerStyle(.menu/.segmented)` — replaces `NSPopUpButton`/`NSComboBox`/`NSSegmentedControl`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/colorpicker | primary-doc | high | `ColorPicker` — macOS 11.0+, replaces `NSColorWell`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/gauge | primary-doc | high | `Gauge` — macOS 13.0+, replaces `NSLevelIndicator`/level gauges. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) | primary-doc | high | SwiftUI `.glassEffect(_:in:)` — macOS 26.0+, replaces a bridged `NSGlassEffectView`. Accessed 2026-06-07. |
