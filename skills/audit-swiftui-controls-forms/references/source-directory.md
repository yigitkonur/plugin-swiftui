# Reference — Apple/WWDC/Practitioner Source Map (the VERIFY map)

The navigable official-source map the auditor uses in step VERIFY to confirm any ≤~70%-confidence
controls/forms claim. **Always fetch Apple docs via Sosumi** — the shared fetch protocol with the curl/CLI
commands and the JSON-404 caveat is `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`; this
file is the controls-specific *map* of which pages to fetch. The **practice** side (consensus shape +
permalinked example) comes from `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`. Floor
values live in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## How to verify (summary; full protocol in the shared sosumi reference)

1. **Does the symbol exist + what's its macOS floor?** Fetch
   `https://sosumi.ai/documentation/swiftui/<symbol-path>` and read the `**Available on:** … macOS N+ …`
   line. Cross-check `introduced_macos` from `swiftui-ctx lookup <api> --json` against it and against
   `floors-master.md`. Absence of a macOS arm = **`macOS ABSENT`** (platform-wrong, e.g. `WheelPickerStyle`)
   — replace, never gate. A `lookup` **exit 3** corroborates "no shipping Mac app uses it."
2. **Floor discrepancy (the corpus-vs-spec gap).** `swiftui-ctx` reports `focusable` at `10.15`, but
   `floors-master.md` **corrects** `focusable`/`focused`/`@FocusState` to **macOS 12.0+** and `help` to
   **11.0+**. The reconciled floor in `floors-master.md` wins — use it for any gate.
3. **Style cases.** `.pickerStyle(.wheel)` / `WheelPickerStyle` is the headline platform-wrong case
   (macOS ABSENT). `ControlSize.extraLarge` exists (macOS 14.0+) but resolves to `.large` on macOS — confirm
   on the `controlsize` page and carry it as a no-op, not a gating issue.
4. **Seam deferral.** Hover/cursor/right-click/drag → `pointer-gestures`; VoiceOver focus / labels →
   `accessibility`; `controlSize` as a layout axis → `layout-and-tables`; `.buttonStyle(.glass)` → `liquid-glass`.

---

## A. SwiftUI controls / styles / focus symbol map

Human doc path = `developer.apple.com/documentation/swiftui/<path>` (fetch via `sosumi.ai/...`). Floors are
the reconciled truth in `floors-master.md` — never restate them here.

| Symbol | Path |
|---|---|
| `formStyle(_:)` (`.grouped`/`.columns`/`.automatic`) | `view/formstyle(_:)` |
| `focusable(_:)` (**macOS 12.0+**, floors-master-corrected) | `view/focusable(_:)` |
| `focused(_:)` / `@FocusState` | `view/focused(_:)` · `focusstate` |
| `help(_:)` (**macOS 11.0+**, floors-master-corrected) | `view/help(_:)` |
| `listStyle(_:)` (`.sidebar`/`.inset`/`.bordered`/`.plain`) | `view/liststyle(_:)` |
| `buttonStyle(_:)` (`.bordered`/`.borderless`/`.plain`/`.link`/`.accessoryBar`/`.accessoryBarAction`) | `view/buttonstyle(_:)` · `design/human-interface-guidelines/buttons` |
| `pickerStyle(_:)` (`.menu`/`.segmented`/`.inline`/`.radioGroup`) | `view/pickerstyle(_:)` |
| `WheelPickerStyle` / `.pickerStyle(.wheel)` (**macOS ABSENT** — compile error) | `wheelpickerstyle` |
| `controlSize(_:)` / `ControlSize` (`.extraLarge` = no-op, resolves to `.large`) | `view/controlsize(_:)` · `controlsize` |

**Absent from the macOS index → platform-wrong (replace, never gate):** `WheelPickerStyle` /
`.pickerStyle(.wheel)`. **No-op trap (real but ineffective on macOS):** `ControlSize.extraLarge`.

## B. Apple conceptual / HIG pages

| Page | Path | Anchors |
|---|---|---|
| HIG — Buttons | `design/human-interface-guidelines/buttons` (verify exact path against current HIG) | Mac button styles; `.link`/`.accessoryBar` floors; icon-only buttons need a tooltip |
| HIG — Settings | `design/human-interface-guidelines/settings` | the grouped System-Settings pane look (cf-01) |
| Pickers / Menus | `documentation/swiftui/picker` · `documentation/swiftui/pickerstyle` | the macOS pop-up vs segmented vs wheel (cf-06/07) |
| Focus & keyboard | `documentation/swiftui/focusstate` | keyboard focus + focus ring on macOS (cf-02) |

## C. WWDC sessions (`developer.apple.com/videos/play/wwdc<year>/<id>`)

| id | Title | Covers |
|---|---|---|
| wwdc2021/10057 | SwiftUI Accessibility: Beyond the basics | keyboard focus, `@FocusState`, the focus ring (cf-02) |
| wwdc2020/10037 | Build a SwiftUI app for tvOS / focus model | `focusable` and focus traversal (cf-02, focus model) |
| wwdc2022/110339 | What's new in SwiftUI | `Form`/settings styling and control density on macOS (cf-01/05) |

## D. Practitioners (corroboration only — never primary; label findings `confidence:` low / verified-by-research)

| Source | URL | Reliable for | Trust |
|---|---|---|---|
| SerialCoder.dev | `serialcoder.dev/text-tutorials/macos-tutorials/macos-programming-implementing-a-focusable-text-field-in-swiftui/` | focusable text field + `@FocusState` on macOS (cf-02) | high |
| Sarunw | `sarunw.com/posts/swiftui-form-styling/` | `formStyle(.grouped)` on macOS (cf-01) | medium |
| Sarunw | `sarunw.com/posts/swiftui-picker-style/` | `pickerStyle` cases on each platform (cf-06/07) | medium |

---

## Sources

- Sosumi fetch protocol + JSON-404 caveat: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- Practice corpus contract: `${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`.
- All Apple paths above fetched via `https://sosumi.ai/...` (access 2026-06-07).
- Practitioner URLs as listed (trust labelled; corroboration only).
