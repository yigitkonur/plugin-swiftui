# Reference — Color Scheme & Increase-Contrast (ac-05/07)

Two appearance-environment defects: forcing the color scheme app-wide, and ignoring Increase Contrast.
Floor values: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (read, never restate).

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## ac-05 — forced `.preferredColorScheme(_:)` app-wide

`preferredColorScheme(_:)` (macOS 11+) tells SwiftUI which appearance to render *for the views it scopes*.
Applied at the **App / `WindowGroup` / root view** it overrides the user's macOS system setting — a
documented anti-pattern on the Mac, where the user owns the appearance in System Settings.

❌ at the root:
```swift
WindowGroup { ContentView().preferredColorScheme(.dark) }   // hijacks every window
```
✅ remove it and let the system drive appearance; honor `@Environment(\.colorScheme)` where the view needs
to know. A *scoped* `.preferredColorScheme` on a deliberate island (a media canvas that is always dark, a
preview) is legitimate — READ to confirm the scope before flagging. This is `flag-only`: the right fix
depends on intent (delete vs scope down), so show the ✅ and let the dev choose.

## ac-07 — ignoring Increase Contrast

macOS exposes **Increase Contrast** (System Settings → Accessibility → Display). SwiftUI surfaces it as
`@Environment(\.colorSchemeContrast)` → `.standard` | `.increased` (macOS 10.15+). A view that paints its
own custom colors (especially low-contrast grays, tinted-on-tinted text) should branch on it so the
contrast lifts when the user asks for it.

❌ a custom palette with no contrast branch:
```swift
Text(label).foregroundStyle(Color("FaintGray"))   // unreadable under Increase Contrast
```
✅ read the environment and lift:
```swift
@Environment(\.colorSchemeContrast) private var contrast
// …
.foregroundStyle(contrast == .increased ? .primary : .secondary)
```
**This is advisory and READ-gated.** grep can only LOCATE an *existing* `colorSchemeContrast` (to confirm
it is actually branched on); the **absence** case — custom colors that ignore the flag entirely — is a
READ-only judgment grep cannot find. Walk the custom-color sites in READ.

**Seam (cross_ref: accessibility).** This skill detects the *mechanic* (no contrast branch). The WCAG
ratio audit, Differentiate-Without-Color, and the trait-level requirement belong to
`audit-swiftui-accessibility` — emit `cross_ref: accessibility` and file the requirement there. Authority:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/cross-ref-graph.md` (appearance-color ↔ accessibility:
"Differentiate-Without-Color / contrast").

---

## Sources

- Sosumi (fetched via `https://sosumi.ai/...`, access 2026-06-07):
  `documentation/swiftui/view/preferredcolorscheme(_:)`,
  `documentation/swiftui/environmentvalues/colorscheme`,
  `documentation/swiftui/environmentvalues/colorschemecontrast`,
  `documentation/swiftui/colorschemecontrast`.
- Apple HIG — Dark Mode / Accessibility (Display): `developer.apple.com/design/human-interface-guidelines/dark-mode`,
  `developer.apple.com/design/human-interface-guidelines/accessibility`.
