# Gesture currency, live state & composition (pg-08 … pg-11)

The gesture half of the domain: the deprecated pinch/rotate **rename mechanics** (pg-08/09), missing live
`@GestureState` on a continuous gesture (pg-10), and gesture composition (pg-11). The *flag* that
`MagnificationGesture`/`RotationGesture` are deprecated is owned by `audit-swiftui-api-currency`; **this
skill owns the rewrite** — emit `cross_ref: api-currency` on pg-08/pg-09. Gesture-driven *animation
timing* is `animation-motion`'s.

Floor values are NOT restated — read them from
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The deprecated-rename rows are in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`. The ✅ shape is the swiftui-ctx
**consensus** + a permalinked example — `lookup`/`deprecated` before you cite.

---

## pg-08 / pg-09 — `MagnificationGesture` / `RotationGesture` deprecated (26.5)

Both are real but **deprecated in macOS 26.5**; the replacements `MagnifyGesture` / `RotateGesture` ship
at **macOS 14.0+**. `swiftui-ctx deprecated MagnificationGesture` returns `deprecated:true`,
`migrate_to: MagnifyGesture` — corroborate every flag with it. The value carrier renames too:
`MagnifyGesture.Value.magnification` (was `.magnitude`) and `RotateGesture.Value.rotation`.

```swift
// ❌ WRONG — deprecated 26.5
@GestureState private var scale: CGFloat = 1
content.gesture(MagnificationGesture().updating($scale) { v, s, _ in s = v })
```
```swift
// ✅ CORRECT — MagnifyGesture (macOS 14+). consensus shape is MagnifyGesture() (85% of real uses);
//    verify: swiftui-ctx lookup MagnifyGesture  →  recommended permalink backs the finding's ## Source
@GestureState private var scale: CGFloat = 1
content.gesture(
    MagnifyGesture().updating($scale) { v, s, _ in s = v.magnification }   // .rotation for RotateGesture
)
```

If the project's deployment floor is below macOS 14, the rewrite *also* needs a `#available(macOS 14, *)`
gate (route to `gesture-availability.md`). Because pg-08/09 are a deprecation flag, `cross_ref:
api-currency` and let api-currency own the currency angle; this skill carries the mechanics.

## pg-10 — continuous gesture with no live `@GestureState`

A `DragGesture` / `MagnifyGesture` / `RotateGesture` is *continuous*: it streams a value while in flight.
Without `@GestureState` (`.updating`) — or a committed `@State` written in `.onChanged`/`.onEnded` — the
in-flight value is never read and the interaction feels frozen until release. `@GestureState`
**auto-resets** to its initial value when the gesture ends, which is why it is the idiomatic carrier for
*transient* drag/scale/rotation; persist the committed result to `@State` in `.onEnded`. swiftui-ctx shows
`DragGesture` `co_occurs_with` `onChanged` and the composition operators — read those to confirm.

```swift
// ❌ WRONG — drag with no live state: nothing moves until you let go (and then jumps)
content.gesture(DragGesture())
```
```swift
// ✅ CORRECT — transient offset via @GestureState (auto-resets), committed in .onEnded
@GestureState private var drag: CGSize = .zero
@State private var offset: CGSize = .zero
content
    .offset(x: offset.width + drag.width, y: offset.height + drag.height)
    .gesture(
        DragGesture()
            .updating($drag) { v, s, _ in s = v.translation }     // live, transient
            .onEnded { offset.width += $0.translation.width        // commit
                       offset.height += $0.translation.height }
    )
```
The `DragGesture` consensus shape per `swiftui-ctx lookup DragGesture` is `(minimumDistance:)` (49%) /
`()` (33%) — back the ✅ with its `recommended` permalink.

## pg-11 — `.gesture` where `.simultaneousGesture` / `.highPriorityGesture` is needed (advisory)

A plain `.gesture(...)` attached to a view that **already has a built-in gesture** (a `Button`'s tap, a
`Slider`'s drag, a `ScrollView`'s pan, a `List` row's selection) can swallow or be swallowed by that
built-in. Two plain `.gesture(...)` chained onto one receiver also conflict — the later wins. The fix is
to declare intent:

- `.simultaneousGesture(_:)` — your gesture runs **alongside** the built-in (both fire).
- `.highPriorityGesture(_:)` — your gesture runs **instead of** the built-in (yours wins).
- Compose explicitly with `SimultaneousGesture` / `ExclusiveGesture` / `.sequenced(before:)` when you need
  a defined relationship (these appear in `DragGesture`'s `co_occurs_with`).

This is **advisory** and control-specific: whether the built-in actually conflicts depends on the host
control's gesture, which differs across SwiftUI versions — `source: verify against Xcode 26 SDK`. The
tier-2 ast-grep rule `pg-11-stacked-gestures.yml` catches the chained `.gesture().gesture()` form
structurally; the grep tell catches the plain-`.gesture(` presence for the agent to judge.

```swift
// ❌ WRONG — a drag on a row that also selects: the two fight, selection may break
row.gesture(DragGesture().onChanged { … })
```
```swift
// ✅ CORRECT — declare it runs alongside the built-in selection
row.simultaneousGesture(DragGesture().onChanged { … })       // or .highPriorityGesture to override
```

---

## Detection tells (what LOCATE surfaces; you READ and judge)

- `MagnificationGesture` anywhere → pg-08 (deprecated → `MagnifyGesture`, `cross_ref` api-currency).
- `RotationGesture` anywhere → pg-09 (deprecated → `RotateGesture`, `cross_ref` api-currency).
- `DragGesture(` / `MagnifyGesture(` / `RotateGesture(` with no `@GestureState` / `.updating` /
  committed `@State` → pg-10.
- A plain `.gesture(` on a built-in-gesture control, or two `.gesture()` chained on one receiver → pg-11.

---

## Sources

| URL | Claim | Confidence |
|---|---|---|
| https://developer.apple.com/documentation/swiftui/magnifygesture | `MagnifyGesture` — macOS 14.0+; `Value.magnification`; replaces deprecated `MagnificationGesture` | high |
| https://developer.apple.com/documentation/swiftui/magnificationgesture | `MagnificationGesture` — deprecated (26.5) → `MagnifyGesture` | high |
| https://developer.apple.com/documentation/swiftui/rotategesture | `RotateGesture` — macOS 14.0+; `Value.rotation`; replaces deprecated `RotationGesture` | high |
| https://developer.apple.com/documentation/swiftui/gesturestate | `@GestureState` — transient gesture value that auto-resets when the gesture ends | high |
| https://developer.apple.com/documentation/swiftui/view/simultaneousgesture(_:including:) | `.simultaneousGesture` / `.highPriorityGesture` — compose with a built-in gesture | high |
| https://developer.apple.com/documentation/swiftui/draggesture | `DragGesture` — macOS 10.15+; `.translation` value; `.updating`/`.onChanged`/`.onEnded` | high |
| swiftui-ctx `deprecated MagnificationGesture` (corpus of 1,857 macOS apps) | `deprecated:true`, `migrate_to: MagnifyGesture` | high |
| swiftui-ctx `lookup MagnifyGesture` | consensus `()` 85% / `(minimumScaleDelta)` 15%; recommended `noah-nuebling/mac-mouse-fix` `CurveVisualizer.swift#L56` permalink (macOS 14, 10k★); `co_occurs_with` RotateGesture | high |
| swiftui-ctx `lookup DragGesture` | consensus `(minimumDistance)` 49% / `()` 33%; `co_occurs_with` onChanged / SimultaneousGesture / ExclusiveGesture / sequenced | high |

Apple availability strings cross-checked against `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`
and fetched via Sosumi (access 2026-06-07). pg-11's built-in-gesture conflict is control-specific —
`verify against Xcode 26 SDK`. Cite the swiftui-ctx `recommended` permalink in each finding's `## Source`,
not the static snippet.
