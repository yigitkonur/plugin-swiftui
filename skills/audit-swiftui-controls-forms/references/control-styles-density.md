# Reference — List / Button / Picker Style & Control Density (cf-04 · cf-05 · cf-06 · cf-07 · cf-08)

iOS-default `List`/`Button`/`Picker` styling and control density read **oversized and non-native** on
macOS — the "iPad app in a window" smell. A Mac sidebar wants the source-list material, dense panes want
compact buttons and a `.menu` pop-up picker and a smaller `controlSize`, and two styles are **traps**:
`.pickerStyle(.wheel)` has **no macOS arm** (compile error), and `.controlSize(.extraLarge)` resolves to
`.large` (a no-op). cf-04/05/06/08 are *advisory, flag-only* (density is a judgment); cf-07 is a
**hard-fail** (it won't compile). Floors live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` — read, never restate. The ✅ here is the
swiftui-ctx **consensus shape** backed by a real macOS permalink, not opinion.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2.

---

## cf-04 — sidebar `List` with no `.listStyle(.sidebar)` (advisory, flag-only)

A `List` used as the sidebar column of a `NavigationSplitView` should carry `.listStyle(.sidebar)` to get
the translucent macOS **source-list** material (auto-adapts Light/Dark, respects Reduce Transparency).
Without it the sidebar uses the wrong material and reads as a flat iOS list.

```swift
// ❌ WRONG — sidebar List with no .sidebar style => wrong sidebar material
NavigationSplitView {
    List(selection: $selection) { /* rows */ }
} detail: { /* … */ }
```
```swift
// ✅ CORRECT — macOS source-list sidebar material
NavigationSplitView {
    List(selection: $selection) { /* rows */ }
        .listStyle(.sidebar)                     // macOS source-list sidebar
} detail: { /* … */ }
```

**Grounded in the corpus.** `swiftui-ctx lookup listStyle --json` (run 2026-06-07) returns
`introduced_macos: 10.15`, `deprecated: false`, consensus `(_)` **100%**; its `recommended` macOS-26 example
is **`.listStyle(.sidebar)`** in `f/textream`:
`https://github.com/f/textream/blob/6c34baaef9fea5de30bce619b4ed34cd675d5617/Textream/Textream/ContentView.swift#L571`.
Other documented styles: `.inset`/`.bordered`/`.plain`. **Seam:** `NavigationSplitView` *column sizing* is
`audit-swiftui-navigation-toolbars`' — this skill owns the **list style**; cross_ref nav when the issue is
the column width, not the material.

## cf-05 — `Button` with no explicit style in a dense pane (advisory, flag-only)

A `Button` in a compact Mac pane (inspector, toolbar, settings grid) reads oversized at the iOS default.
Set the Mac style explicitly: `.bordered` / `.borderless` / `.plain`, `.borderedProminent` for a prominent call-to-action (macOS 12.0+), and `.link` for link-text actions.

```swift
// ❌ WRONG — default-styled button reads large in a dense pane
Button("Apply") { }
```
```swift
// ✅ CORRECT — explicit Mac style + compact density (controlSize: see cf-08)
Button("Apply") { }
    .buttonStyle(.bordered)
    .controlSize(.small)                         // compact-pane density (macOS 10.15+)
```

**Grounded in the corpus.** `swiftui-ctx lookup buttonStyle --json` (run 2026-06-07) returns
`introduced_macos: 10.15`, `deprecated: false`, consensus `(_)` **100%**. Note its top `recommended`
example is **`.buttonStyle(.glass)`** (`sindresorhus/Gifski` `CompletedScreen.swift#L120`, macOS-26) — that
specific style is **Liquid Glass and owned by `audit-swiftui-liquid-glass`** (gate on macOS 26); for the
generic Mac density fix use `.bordered`/`.borderless`. **macOS-exclusive button styles, with DIFFERENT
floors:** `.link` (macOS 10.15+), `.accessoryBar` / `.accessoryBarAction` (macOS 14.0+) — do **not** group
their availability. **Seam:** the `controlSize` *sizing axis* split is cf-08 below;
`audit-swiftui-layout-and-tables` owns `controlSize` as a layout axis.

## cf-06 — `Picker` with no `.pickerStyle(.menu)` (advisory, flag-only)

The native macOS picker is a **pop-up button** — `.pickerStyle(.menu)`; `.segmented` is the segmented
control, `.inline`/`.radioGroup` for inline choices. A default/unset picker is non-native on macOS.

```swift
// ❌ WRONG — default/unset picker style on macOS
Picker("Size", selection: $size) { ForEach(sizes, id: \.self) { Text($0) } }
```
```swift
// ✅ CORRECT — the Mac pop-up button (or .segmented for a few options)
Picker("Size", selection: $size) { ForEach(sizes, id: \.self) { Text($0) } }
    .pickerStyle(.menu)                          // macOS pop-up button (not a wheel)
```

**Grounded in the corpus.** `swiftui-ctx lookup pickerStyle --json` (run 2026-06-07) returns
`introduced_macos: 10.15`, `deprecated: false`, consensus `(_)` **100%**; its `recommended` macOS-26 example
is **`.pickerStyle(.segmented)`** in `f/textream`:
`https://github.com/f/textream/blob/6c34baaef9fea5de30bce619b4ed34cd675d5617/Textream/Textream/SettingsView.swift#L638`
(fetched live with `swiftui-ctx file … --smart`; the `Picker` it styles uses a `ForEach` over enum cases).
Put `.pickerStyle(.menu)` (the most native pop-up) or `.segmented` in `## Correct` per the data.
**Picker styles have different floors:** `.menu` (`MenuPickerStyle`) macOS 11.0+; `.inline` (`InlinePickerStyle`) macOS 11.0+; `.segmented` / `.radioGroup` macOS 10.15+. Do **not** use `.menu` on a macOS 10.15 target — fall back to `.segmented` or `.radioGroup`.

## cf-07 — `.pickerStyle(.wheel)` / `WheelPickerStyle` on a Mac target (hard-fail, flag-only)

`WheelPickerStyle` / `.pickerStyle(.wheel)` is the iOS spinning-wheel picker — it has **NO macOS arm**.
Per `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` it is **`macOS ABSENT`** (a compile error
on non-Catalyst macOS), **not** an under-gated symbol. Do **not** wrap it in `#available(macOS …)` — that is
the "macOS ABSENT is not a low floor" trap in `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`.
**Replace** it with a real Mac picker style.

```swift
// ❌ WRONG — .wheel has no macOS arm; compile error on a Mac target
Picker("Hour", selection: $hour) { ForEach(0..<24) { Text("\($0)") } }
    .pickerStyle(.wheel)
```
```swift
// ✅ CORRECT — a real Mac picker style (choose per the data: .menu / .segmented / .inline)
Picker("Hour", selection: $hour) { ForEach(0..<24) { Text("\($0)") } }
    .pickerStyle(.menu)                          // pop-up; or .segmented for few options, .inline for a list
```

**Grounded in the corpus (the existence proof).** `swiftui-ctx lookup WheelPickerStyle --json` (run
2026-06-07) **exits 3 — `not_found`**: *"no usage found for 'WheelPickerStyle'"* with `suggestion: did you
mean: datePickerStyle, MenuPickerStyle, pickerStyle, DefaultPickerStyle, InlinePickerStyle?"* — i.e. **no
shipping Mac app in the 1,857-repo catalog uses it**, corroborating the `macOS ABSENT` floor. This is a
hard-fail but still `flag-only`: the replacement style (`.menu` vs `.segmented` vs `.inline`) depends on the
data, so it is the dev's call, not a mechanical auto-fix.

## cf-08 — `.controlSize(.extraLarge)` no-op (advisory, flag-only)

`ControlSize.extraLarge` **exists** (macOS 14.0+) but **resolves to `.large` on macOS** — it has no distinct
visual effect, so writing it is a silent no-op that signals an iOS-copied mental model. The practical Mac
case list is `.mini` / `.small` / `.regular` / `.large`; dense panes want `.small`/`.mini`, a single
prominent action wants `.large`, `.regular` is the default.

```swift
// ❌ WRONG (no-op) — .extraLarge resolves to .large on macOS
Button("Go") { }.controlSize(.extraLarge)
```
```swift
// ✅ CORRECT — pick a Mac-effective size
Button("Go") { }.controlSize(.large)            // prominent single action
// dense pane:
HStack { /* controls */ }.controlSize(.small)   // applies to the subtree (macOS 10.15+)
```

**Grounded in the corpus.** `swiftui-ctx lookup controlSize --json` (run 2026-06-07) returns
`introduced_macos: 10.15`, `deprecated: false`, consensus `(_)` 100%. The `.extraLarge`-resolves-to-`.large`
no-op is the reconciled fact in floors-master (`ControlSize.extraLarge` macOS 14.0+, "resolves to `.large`
on macOS — no-op"). **Seam:** `controlSize` is a **split axis** — the *density/style variant* (and this
`.extraLarge` no-op) is this skill; `controlSize` as a **layout sizing axis** is
`audit-swiftui-layout-and-tables` — `cross_ref` it when the issue is layout sizing, not control density.

---

## macOS-specific notes

- **`Form` is ungrouped by default on macOS** (cf-01); the documented styles are `.grouped`/`.columns`/
  `.automatic`. **`.listStyle(.sidebar)`** gives the translucent source-list sidebar (auto-adapts Light/Dark,
  respects Reduce Transparency).
- **Control density is explicit on macOS.** Prefer `.bordered`/`.borderless`/`.plain` button styles,
  `.pickerStyle(.menu)`/`.segmented`, and `.controlSize(.small)`/`.mini` for dense panes; `.regular` is the
  default, `.large` for a prominent single action.
- **Two platform traps.** `.pickerStyle(.wheel)` is **macOS ABSENT** (compile error — replace, never gate,
  cf-07). `ControlSize.extraLarge` resolves to `.large` (no-op — pick a real size, cf-08).
- **`.buttonStyle(.glass)` / `Glass.interactive`** are Liquid Glass (macOS 26.0+) and owned by
  `audit-swiftui-liquid-glass` — note in one line and `cross_ref`, don't gate them here.

---

## Sources

- Apple — `listStyle(_:)`: *"Sets the style for lists within this view."* (`.sidebar`/`.inset`/`.bordered`/
  `.plain`; macOS 10.15+): `https://developer.apple.com/documentation/swiftui/view/liststyle(_:)` (via
  Sosumi, accessed 2026-06-07).
- Apple — `buttonStyle(_:)` / HIG Buttons: `.bordered`/`.borderless`/`.plain`; `.borderedProminent`
  (macOS 12.0+); `.link` (macOS 10.15+, macOS-only) and `.accessoryBar`/`.accessoryBarAction` (macOS 14.0+,
  macOS-only) have **different** floors:
  `https://developer.apple.com/design/human-interface-guidelines/buttons` (via Sosumi, accessed 2026-06-07).
- Apple — `pickerStyle(_:)`: `.menu` (`MenuPickerStyle`, macOS 11.0+) / `.inline` (macOS 11.0+) /
  `.segmented` / `.radioGroup` (macOS 10.15+) — floors differ; see cf-06 note above:
  `https://developer.apple.com/documentation/swiftui/view/pickerstyle(_:)` (via Sosumi, accessed 2026-06-07).
- Apple — `WheelPickerStyle`: iOS/watchOS spinning wheel — **macOS ABSENT** (no macOS availability arm):
  `https://developer.apple.com/documentation/swiftui/wheelpickerstyle` (via Sosumi, accessed 2026-06-07).
- Apple — `controlSize(_:)`: *"Sets the size for controls within this view."* — macOS 10.15+; `ControlSize`
  cases `.mini`/`.small`/`.regular`/`.large`, `.extraLarge` exists (macOS 14.0+) but resolves to `.large` on
  macOS: `https://developer.apple.com/documentation/swiftui/controlsize` (via Sosumi, accessed 2026-06-07).
- Practice corpus (the ✅ permalinks / existence proof): `swiftui-ctx lookup listStyle` →
  `https://github.com/f/textream/blob/6c34baaef9fea5de30bce619b4ed34cd675d5617/Textream/Textream/ContentView.swift#L571`;
  `swiftui-ctx lookup pickerStyle` →
  `https://github.com/f/textream/blob/6c34baaef9fea5de30bce619b4ed34cd675d5617/Textream/Textream/SettingsView.swift#L638`;
  `swiftui-ctx lookup WheelPickerStyle` → **exit 3 (no corpus usage)** — corroborates `macOS ABSENT`
  (1,857-repo macOS catalog, SwiftSyntax, macOS 26.5 SDK; accessed 2026-06-07).
