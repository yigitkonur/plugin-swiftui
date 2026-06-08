# Reference — Justified Escape Hatches (CONFIRM, never flag) + over-07

The other half of the audit. When a bridge matches one of these, SwiftUI has **no native equal** (or not
at the project's floor) — the bridge is **correct**. Record `status: justified` (the appkit-overuse
additive `status` value in `${CLAUDE_PLUGIN_ROOT}/references/_shared/finding-schema.md`) with the
one-line reason; **do not flag it as a defect**. Confirming these stops a later refactor from churning a
correct bridge into a broken pseudo-SwiftUI control.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## The warranted set

| Escape hatch | Why SwiftUI has no equal | Owner of its HOW |
|---|---|---|
| Rich-text `NSTextView` **below macOS 26** | SwiftUI `TextEditor` is plain-text until macOS 26's `TextEditor(text:selection:)` over `AttributedString`. Below 26, rich text REQUIRES the bridge. | `appkit-interop` (controller-shaped → `NSViewControllerRepresentable`) |
| `NSOutlineView` | SwiftUI's `List`/`OutlineGroup`/`DisclosureGroup` cover simple trees, but column-based hierarchical outlines with cell views, source-list behavior, and large-tree perf have no full SwiftUI equal. | `appkit-interop` · perf → `view-performance` |
| `NSTableView`-grade data grids | SwiftUI `Table` lacks cell-level reuse, column reordering, and the row-count ceiling of `NSTableView`; a heavy spreadsheet/grid stays AppKit. | `view-performance` (the cost argument) |
| **Behind-window** `NSVisualEffectView` | `.ultraThinMaterial` composites *inside* the window — it never samples the desktop behind it. A genuine sidebar/panel needs `NSVisualEffectView(material:.sidebar, blendingMode:.behindWindow)`. | `appkit-interop` (mistake 7) · material choice → `appearance-color` |
| Precise **first-responder / field editor** | `@FocusState` covers SwiftUI-native controls only; custom field editors, insertion-point color, focus rings, and `window.makeFirstResponder(_:)` have no public SwiftUI surface. | `appkit-interop` (mistakes 3) |

When you confirm one of these, emit `status: justified` and a `cross_ref` to the HOW owner so the
interop audit verifies the bridge is *implemented* correctly. The two skills together: overuse says "this
bridge is warranted," interop says "and it is wired right."

## over-07 — the macOS-26 inflection on rich text

This is the one case that flips with the floor:

- **Floor < macOS 26** → a rich-text `NSTextView` bridge is **justified** (status: justified). The native
  `TextEditor(text:selection:)` rich-text editor over `AttributedString` does not exist yet.
- **Floor ≥ macOS 26** AND the bridge handles only plain or lightly-styled text → **over-07** (flag): the
  native `TextEditor(text:selection:)` may remove the bridge. Show it as the ✅. **But** confirm scope
  first: an `NSTextView` used for advanced layout (rulers, multiple text containers, custom layout
  manager, `NSTextLayoutManager` features) is still beyond the native editor — keep it justified.

Because the macOS-26 native rich-text editor is new (post-most-training-data), **VERIFY it before
recommending it**: `swiftui-ctx lookup TextEditor --json` (read `consensus` for the `(text:selection:)`
shape + `recommended` permalink + `introduced_macos`) and confirm the floor via Sosumi
(`references/source-directory.md`). If you cannot confirm the rich-text initializer at macOS 26, carry
over-07 as `advisory` with `source: verify against Xcode 26 SDK` — never assert it as fact. Floor truth:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

---

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://developer.apple.com/documentation/swiftui/texteditor | primary-doc | high | `TextEditor`; the `AttributedString` `selection:` rich-text form is the macOS-26 addition — verify the exact floor against the Xcode 26 SDK. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nstextview | primary-doc | high | Full rich-text engine (layout manager, text containers, rulers) — no full SwiftUI equal below macOS 26. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsoutlineview | primary-doc | high | Column-based hierarchical outline / source list — beyond `OutlineGroup`/`List`. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/appkit/nsvisualeffectview | primary-doc | high | `blendingMode = .behindWindow` samples the desktop; SwiftUI materials composite inside the window. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/swiftui/focusstate | primary-doc | high | `@FocusState` — SwiftUI-native controls only; no public arbitrary-first-responder API. macOS 12.0+. Accessed 2026-06-07. |
