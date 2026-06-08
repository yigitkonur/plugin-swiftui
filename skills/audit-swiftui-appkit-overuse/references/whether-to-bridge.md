# Reference — The WHETHER-to-Bridge Decision Tree

This skill audits **whether an AppKit bridge should exist**, not how it is wired (that is
`audit-swiftui-appkit-interop`). Every `NSViewRepresentable` / `NSViewControllerRepresentable` /
`NSHostingView` / system-AppKit call costs a `make`/`update`/Coordinator handshake, a responder-chain
edge, and a Swift-6 isolation boundary. The default posture is **stay in SwiftUI**; a bridge must earn
its keep.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## The decision tree (apply to every bridge)

```
For each AppKit bridge / system call:
 1. Is there a NATIVE SwiftUI control/API for this exact thing?
      NO  → it may be a JUSTIFIED hatch — go to 3.
      YES → go to 2.
 2. Does that native API exist AT THE PROJECT'S DEPLOYMENT FLOOR (read in ORIENT)?
      YES → OVERUSE. Flag (over-01…over-06). Show the SwiftUI ✅.
      NO  → JUSTIFIED-FOR-NOW (e.g. rich-text TextEditor(text:selection:) needs macOS 26).
            Record status: justified; note "remove the bridge when the floor reaches macOS 26" (over-07).
 3. Does the AppKit view add CAPABILITY SwiftUI structurally lacks?
      (hierarchical NSOutlineView · NSTableView-grade grid · behind-window NSVisualEffectView ·
       precise first-responder / field-editor control · advanced NSTextView layout)
      YES → JUSTIFIED escape hatch. status: justified. DO NOT FLAG. (justified-escape-hatches.md)
      NO  → OVERUSE with no native equal named? Re-check step 1 against swiftui-ctx; if still no
            native API and no special capability, flag as an unjustified bridge and say what is missing.
```

**Two sides, one audit.** A clean run reports *both* the overuse defects (flag) **and** the confirmed
escape hatches (`status: justified`). Confirming the warranted bridges is as much the job as flagging
the unnecessary ones — it stops a later refactor from churning a correct `NSOutlineView` into a broken
`OutlineGroup`.

## Why each AppKit boundary is a liability (the cost you are weighing)

- Every representable owes BOTH `makeNSView` and `updateNSView` or it silently goes stale; a `@Binding`
  owes a `makeCoordinator()` + delegate or the AppKit→SwiftUI direction is dead — the whole class of
  bugs `audit-swiftui-appkit-interop` exists to catch. A native SwiftUI control has none of that.
- The Coordinator boundary is exactly where Swift 6 strict-concurrency bites (`@Sendable` closure
  touching main-actor state). Fewer bridges = fewer isolation edges.
- AppKit controls don't auto-adopt Liquid Glass, Dynamic Type, or the system tint the way SwiftUI
  controls do — a bridged `NSButton` looks subtly non-native next to a `Button`.

## VERIFY the replacement before flagging

Never flag a bridge until you have **confirmed the SwiftUI replacement exists at the floor**. In step
VERIFY run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup <SwiftUI-api> --json` for the
`consensus` shape + `recommended` permalink + `introduced_macos`, and confirm the floor via Sosumi
(`references/source-directory.md`). For a multi-API replacement use the recipe, e.g.
`swiftui-ctx recipe menubar-app` (MenuBarExtra), `swiftui-ctx recipe draggable-reorder` (Transferable),
`swiftui-ctx recipe nsview-bridge` (the bridge itself, to judge what it actually wraps). CLI contract:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Floor values:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

## The bridge-ledger artifact (optional go-beyond)

`swiftui-audits/appkit-overuse/_bridge-ledger.md` — one row per AppKit bridge in the project:
`site · what it wraps · native candidate · floor · verdict (overuse | justified | justified-for-now)`.
A reviewer sees the entire AppKit surface and its justification at a glance, and a future refactor knows
which bridges are load-bearing.

## Seam ownership (don't double-own)

Per `${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md`: **overuse owns WHETHER**, interop owns
HOW (every shared site cross_refs both). For `NSOpenPanel`/`NSItemProvider`, overuse decides *whether*,
`sandbox-files` owns bookmark/payload correctness. For `NSGlassEffectView`, overuse flags the bridge,
`liquid-glass` owns the SwiftUI glass placement. For `NSStatusItem`→`MenuBarExtra`, the scene-activation
trap is `scenes-windows`. For an `NSTableView`/`NSOutlineView` perf justification, `view-performance`
owns the cost argument. Emit a `cross_ref` on every shared site.

---

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://developer.apple.com/documentation/swiftui/nsviewrepresentable | primary-doc | high | Required `makeNSView`/`updateNSView`; bridge is the sanctioned escape, not the default. Accessed 2026-06-07. |
| https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass | primary-doc | high | SwiftUI controls auto-adopt the new design; bridged AppKit controls do not. Accessed 2026-06-07. |
| https://developer.apple.com/videos/play/wwdc2022/10075/ | primary-doc (WWDC22 "Use SwiftUI with AppKit") | high | Bridge only the piece that needs it; prefer native SwiftUI. Accessed 2026-06-07. |
