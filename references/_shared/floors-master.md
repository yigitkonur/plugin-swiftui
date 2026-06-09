# Shared Reference — macOS Availability & Deprecation Floor Map

The single source of truth for every macOS-availability floor and deprecation the audit
toolkit gates on. **macOS-only:** where Apple renders a multi-platform availability string,
only the macOS arm is reproduced. Every skill that gates an API reads floors from here — do
**not** restate a floor table inside a skill's own `references/`. To verify any
&lt;100%-confidence floor, re-fetch the Apple page via
`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2 toolchain · Xcode 26 SDK.
Floors confirmed against the `developer.apple.com` JSON availability endpoints (access date
2026-06-07) unless flagged `verify-SDK`.

---

## How to read this table

- **macOS floor** = lowest macOS that supports the *current* symbol. Gate on the **macOS arm**:
  `#available(macOS NN, *)` (never the iOS arm — see
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`).
- **Deprecated?** = the deprecation window's closing OS + the successor symbol.
- **`macOS ABSENT`** = the symbol has no macOS arm at all; using it on a Mac target is a
  compile error or a no-op, **not** a gating problem. Never present it as a Mac API.
- **`verify-SDK`** = carry as a flag, do not assert; re-confirm against the Xcode 26 SDK / Sosumi.

---

## 1. Master floor / deprecation table (alphabetical)

| Symbol | macOS floor | Deprecated? (OS → successor) |
|---|---|---|
| `@Bindable` | macOS 14.0+ | No |
| `@Entry` macro | macOS 10.15+ (back-deploys; needs Xcode 15+ / Swift 5.9+ to expand) | No |
| `@FocusState` | macOS 12.0+ | No |
| `@Model` macro | macOS 14.0+ | No |
| `@Model` class inheritance (`@Model class X: Y`) | macOS 26.0+ | No |
| `@NSApplicationDelegateAdaptor` | macOS 11.0+ | No |
| `@Observable` macro | macOS 14.0+ | No |
| `@ObservationIgnored` macro | macOS 14.0+ | No |
| `@Previewable` macro | macOS 14.0+ | No |
| `@ScaledMetric` | macOS 11.0+ | No |
| `accessibilityAction(_:_:)` | macOS 10.15+ | No |
| `accessibilityAddTraits(_:)` | macOS 11.0+ | No |
| `accessibilityChartDescriptor(_:)` | macOS 12.0+ | No |
| `accessibilityChildren(children:)` | macOS 12.0+ | No |
| `accessibilityElement(children:)` | macOS 10.15+ | No |
| `accessibilityFocused(_:)` | macOS 12.0+ | No |
| `accessibilityHidden(_:)` | macOS 11.0+ | No |
| `accessibilityHint(_:)` | macOS 13.0+ | No |
| `accessibilityLabel(_:)` (StringProtocol/Text overloads macOS 11.0+; LocalizedStringResource overload macOS 13.0+) | macOS 11.0+ | No |
| `accessibilityLabel(content:)` (closure form) | macOS 15.0+ | No |
| `accessibilityRepresentation(representation:)` | macOS 12.0+ | No |
| `accessibilityRotor(_:entries:)` | macOS 13.0+ | No |
| `accessibilitySortPriority(_:)` | macOS 11.0+ | No |
| `accessibilityShowsLargeContentViewer()` | macOS 12.0+ | No |
| `accessibilityValue(_:)` | macOS 11.0+ | No |
| `accessibilityValue(_:isEnabled:)` (closure form) | macOS 15.0+ | No |
| `accentColor(_:)` / `.accentColor` | macOS 10.15+ | **Yes (26.5 → `.tint(_:)`)** |
| `AccessibilityChildBehavior` (`.combine`/`.ignore`/`.contain`) | macOS 10.15+ | No |
| `AccessibilityFocusState` (property-wrapper type) | macOS 12.0+ | No |
| `AccessibilityRotorContent` | macOS 12.0+ | No |
| `AccessibilityTraits` type | macOS 10.15+ | No |
| `AccessibilityTraits.isButton/.isImage/.isHeader/.isSelected/.isLink/.isStaticText/.playsSound/.updatesFrequently` | macOS 10.15+ | No |
| `AccessibilityTraits.isToggle` | macOS 14.0+ (**NOT 10.15**) | No |
| `animation(_:)` — single-arg implicit | macOS 10.15+ | **Yes (introduced 10.15, deprecated at 12.0 → `animation(_:value:)` / `withAnimation`)** |
| `animation(_:value:)` | macOS 10.15+ | No |
| `AreaMark` | macOS 13.0+ | No |
| `AreaPlot` | macOS 15.0+ | No |
| `AsymmetricTransition` (struct) | macOS 14.0+ | No (factory `.asymmetric(insertion:removal:)` floor: `verify-SDK`) |
| `AttributedTextFormattingDefinition` (protocol) | macOS 26.0+ | No |
| `AttributedTextSelection` (struct) | macOS 26.0+ | No |
| `AXChartDescriptor` / `AXChartDescriptorRepresentable` | macOS 12.0+ | No |
| `BarMark` | macOS 13.0+ | No |
| `BarPlot` | macOS 15.0+ | No |
| `Chart` | macOS 13.0+ | No |
| `Charts` (framework) / `ChartProxy` | macOS 13.0+ | No |
| `chartScrollableAxes(_:)` | macOS 14.0+ (**NOT 15**) | No |
| `chartScrollPosition(x:)` | macOS 14.0+ | No |
| `chartXSelection(value:)` | macOS 14.0+ (**NOT 15**) | No |
| `clipShape(_:style:)` | macOS 10.15+ | No |
| `com.apple.security.app-sandbox` (entitlement) | macOS 10.7+ | No |
| `CommandGroupPlacement` (most cases) | macOS 11.0+ | No |
| `CommandGroupPlacement.singleWindowList` | macOS 13.0+ | No |
| `commandsRemoved()` / `commandsReplaced()` | macOS 13.0+ (iOS 16.0+) | No |
| `contentTransition(_:)` | macOS 13.0+ | No |
| `ContentUnavailableView` | macOS 14.0+ | No |
| `controlSize(_:)` | macOS 10.15+ | No |
| `ControlSize.extraLarge` | macOS 14.0+ (resolves to `.large` on macOS — no-op) | No |
| `copyable(_:)` | macOS 13.0+ | No |
| `cornerRadius(_:)` | macOS 10.15+ | **Yes (→ `clipShape(.rect(cornerRadius:))`; exact window `verify-SDK`)** |
| `defaultLaunchBehavior(_:)` / `SceneLaunchBehavior` | macOS 15.0+ | No |
| `dismissWindow` / `DismissWindowAction` | macOS 14.0+ (**NOT 13; trails `openWindow` by one release**) | No |
| `DisclosureGroup` | macOS 11.0+ | No |
| `draggable(_:)` | macOS 13.0+ | No |
| `DragConfiguration` / `DropConfiguration` | macOS 26.0+ | No |
| `dropDestination(for:action:isTargeted:)` (3-arg Bool-returning) | macOS 13.0+ | **Yes (26.5 → `dropDestination(for:isEnabled:action:)`)** |
| `dropDestination(for:isEnabled:action:)` (successor) | macOS 26.0+ | No |
| `EnvironmentValues.accessibilityDifferentiateWithoutColor` | macOS 10.15+ | No |
| `EnvironmentValues.accessibilityReduceMotion` | macOS 10.15+ | No |
| `EnvironmentValues.accessibilityReduceTransparency` | macOS 10.15+ | No |
| `EnvironmentValues.accessibilityVoiceOverEnabled` | macOS 12.0+ | No |
| `EnvironmentValues.colorScheme` | macOS 10.15+ | No |
| `EnvironmentValues.colorSchemeContrast` | macOS 10.15+ | No |
| `fileExporter(...)` / `fileImporter(...)` | macOS 11.0+ | No |
| `focusable(_:)` | macOS 12.0+ (**NOT 10.15 — corpus error corrected**) | No |
| `focused(_:)` | macOS 12.0+ | No |
| `Font.system(_:design:)` (design-only, no `weight:`) | macOS 10.15+ | **Yes (26.5 → `system(_:design:weight:)`)** |
| `Font.system(_:design:weight:)` (current overload) | macOS 13.0+ | No |
| `foregroundColor(_:)` | macOS 10.15+ | **Yes (26.5 → `.foregroundStyle(_:)`)** |
| `foregroundStyle(_:)` | macOS 12.0+ | No |
| `formStyle(_:)` | macOS 13.0+ | No |
| `FocusedValueKey` protocol | macOS 11.0+ | No |
| `Glass` type + `.regular`/`.clear`/`.identity` statics | macOS 26.0+ | No |
| `Glass.interactive(_:)` | macOS 26.0+ (**NOT iOS-only — pointer-driven on Mac**) | No |
| `Glass.tint(_:)` | macOS 26.0+ | No |
| `GlassButtonStyle` / `.buttonStyle(.glass)` | macOS 26.0+ | No |
| `GlassProminentButtonStyle` / `.buttonStyle(.glassProminent)` | macOS 26.0+ | No |
| `GlassEffectContainer` | macOS 26.0+ | No |
| `GlassEffectTransition.materialize` | macOS 26.0+ | No |
| `glassEffect(_:in:)` | macOS 26.0+ | No |
| `glassEffectID(_:in:)` / `glassEffectTransition(_:)` / `glassEffectUnion(id:namespace:)` | macOS 26.0+ | No |
| `.glassBackgroundEffect()` | visionOS 1.0+ — **macOS ABSENT (platform-wrong)** | N/A |
| `HierarchicalShapeStyle.quinary` / all levels | macOS 12.0+ | No |
| `help(_:)` | macOS 11.0+ (**NOT 10.15 — corpus error corrected**) | No |
| `#Index` (SwiftData) | macOS 15.0+ | No |
| `HistoryDescriptor` | macOS 15.0+ | No |
| `HistoryDescriptor.sortBy` (sorted-history path) | macOS 26.0+ (member badge: `verify-SDK`) | No |
| `HiddenTitleBarWindowStyle` / `.hiddenTitleBar` | macOS 11.0+ | No |
| `InflectionRule` | macOS 12.0+ | No |
| `ImageRenderer` | macOS 13.0+ | No |
| `ImportFromDevicesCommands` | macOS 12.0+ | No |
| `InspectorCommands` | macOS 14.0+ | No |
| `inspector(isPresented:content:)` | macOS 14.0+ | No |
| `inspectorColumnWidth(_:)` / `(min:ideal:max:)` (Apple example uses **225 pts**) | macOS 14.0+ | No |
| `KeyframeAnimator` | macOS 14.0+ | No |
| `LabeledContent` | macOS 13.0+ | No |
| `lineLimit(_:reservesSpace:)` | macOS 13.0+ | No |
| `LineMark` | macOS 13.0+ | No |
| `LinePlot` | macOS 15.0+ | No |
| `List(_:children:rowContent:)` (hierarchical) | macOS 12.0+ | No |
| `LocalizedStringResource` | macOS 13.0+ | No |
| `MagnificationGesture` | macOS 10.15+ | **Yes (26.5 → `MagnifyGesture`)** |
| `MagnifyGesture` | macOS 14.0+ | No |
| `matchedGeometryEffect(id:in:…)` | macOS 11.0+ | No |
| `Material` struct | macOS 12.0+ | No |
| `MenuBarExtra` | macOS 13.0+ | No |
| `MenuBarExtraStyle` / `menuBarExtraStyle(_:)` | macOS 13.0+ (cases `.menu`/`.window`/`.automatic` confirmed) | No |
| `MeshGradient` | macOS 15.0+ | No |
| `ModelContainer.init(for:configurations:)` (variadic) | macOS 15.0+ | No |
| `ModelContainer.init(for:migrationPlan:configurations:)` | macOS 14.0+ | No |
| `Morphology` | macOS 12.0+ | No |
| `Namespace` / `@Namespace` | macOS 11.0+ | No |
| `navigationDestination(for:)` | macOS 13.0+ | No |
| `NavigationSplitView` / `NavigationSplitViewVisibility` | macOS 13.0+ | No |
| `NavigationStack` | macOS 13.0+ | No |
| `NavigationView` | macOS 10.15+ | **Yes (26.5 → `NavigationStack`/`NavigationSplitView`)** |
| `navigationSplitViewColumnWidth(min:ideal:max:)` | macOS 13.0+ | No (no-op on detail column: `verify-SDK`) |
| `navigationSubtitle(_:)` | macOS 11.0+ (iOS floor is 26.0 — much higher) | No |
| `navigationTitle(_:)` | macOS 11.0+ | No |
| `NSAnimationContext.animate(_:changes:completion:)` | macOS 15.0+ (**corrects shipped doc's "14"**) | No |
| `NSGlassEffectView` | macOS 26.0+ | No |
| `NSHostingMenu` | macOS 14.4+ (**corrects shipped doc's "14"**) | No |
| `NSHostingSizingOptions` / `sizeThatFits(_:nsView:context:)` | macOS 13.0+ | No |
| `NSHostingSceneBridgingOptions` / `sceneBridgingOptions` | macOS 14.0+ | No |
| `NSHostingView` / `NSHostingController` / `NSViewRepresentable` / `NSViewControllerRepresentable` | macOS 10.15+ | No |
| `NSVisualEffectView` | macOS 10.10+ | No (justified escape hatch) |
| `#Preview` macro / preview traits | macOS 14.0+ | No |
| `Preview(_:windowStyle:…)` overload | **visionOS 1.0+ ONLY — macOS ABSENT** | N/A |
| `PreviewModifier` / `.modifier(_:)` trait | macOS 15.0+ (exact badge: `verify-SDK`) | No |
| `preferredColorScheme(_:)` | macOS 11.0+ | No |
| `PhaseAnimator` | macOS 14.0+ | No |
| `PointMark` | macOS 13.0+ | No |
| `PointPlot` | macOS 15.0+ | No |
| `PointerStyle` type / `pointerStyle(_:)` modifier | macOS 15.0+ (no iOS arm) | No |
| `PointerStyle.grabActive` / `.grabIdle` (**NOT `.grabbing`**) | macOS 15.0+ | No |
| `PointerStyle.frameResize(position:directions:)` / `.columnResize` / `.rowResize` | macOS 15.0+ | No |
| `pushWindow` / `PushWindowAction` | **`verify-SDK` — Apple pages show visionOS 2.0+ only; macOS unconfirmed** | N/A |
| `RectangleMark` / `RuleMark` | macOS 13.0+ | No |
| `RectanglePlot` / `RulePlot` | macOS 15.0+ (exact badge: `verify-SDK`) | No |
| `RotationGesture` | macOS 10.15+ | **Yes (26.5 → `RotateGesture`)** |
| `RotateGesture` | macOS 14.0+ | No |
| `scrollEdgeEffectHidden(_:for:)` | macOS 26.0+ | No |
| `scrollEdgeEffectStyle(_:for:)` | macOS 26.0+ (`.hard`/`.soft` default: `verify-SDK`) | No |
| `searchToolbarBehavior(_:)` (correct case `.minimize`) | macOS 26.0+ | No |
| `SectorMark` | macOS 14.0+ (**NOT 13**) | No |
| `SectorPlot` | macOS 15.0+ | No |
| `Settings {}` scene | macOS 11.0+ | No |
| `SettingsLink` | macOS 14.0+ | No |
| `ShapeStyle.tertiary` / hierarchy levels / `.ultraThinMaterial` | macOS 12.0+ | No |
| `SidebarListStyle` (`.sidebar`) | macOS 10.15+ | No |
| `SidebarCommands` | macOS 11.0+ | No |
| `SpatialTapGesture` | macOS 13.0+ | No |
| `SpacerSizing` (`.fixed`/`.flexible`) | macOS 26.0+ | No |
| `Spring` presets: `Animation.bouncy`/`.smooth`/`.snappy` | macOS 14.0+ (**NOT 10.15 — DocC type-property inheritance quirk; WWDC23 provenance = 14**) | No |
| `Spring.spring(duration:bounce:blendDuration:)` overload | macOS 14.0+ (exact badge: `verify-SDK`) | No |
| `startAccessingSecurityScopedResource()` | macOS 10.10+ | No |
| `String.init(localized:…)` / `String.LocalizationValue` | macOS 12.0+ | No |
| `symbolEffect(_:options:value:)` / `(_:options:isActive:)` | macOS 14.0+ | No |
| `Tab` struct | macOS 15.0+ | No |
| `tabItem { … }` | macOS 10.15+ | **Yes (26.5 → `Tab("…") { }`)** |
| `Table` (SwiftUI) | macOS 12.0+ | No |
| `TableColumnForEach` | macOS 14.4+ | No |
| `tableStyle(.inset(alternatesRowBackgrounds:))` | macOS 12.0+ | **Yes (26.5 → `.tableStyle(.inset).alternatingRowBackgrounds()`)** |
| `TextEditor(text:selection:)` (styled/rich-text init) | macOS 26.0+ | No |
| `TextRenderer` (protocol) | macOS 14.0+ | No |
| `textRenderer(_:)` (modifier applying a renderer) | macOS 15.0+ | No |
| `Text("a") + Text("b")` (`Text` `+` operator) | macOS 10.15+ | **Yes (26.0 → Text interpolation / `AttributedString`) — closes at 26.0, one release before the 26.5 set** |
| `Text.init(_:format:)` (FormatStyle→AttributedString overload) | macOS 15.0+ | No |
| `tint(_:)` | macOS 12.0+ | No |
| `ToolbarCommands` | macOS 11.0+ | No |
| `ToolbarItemPlacement.navigationBarLeading` / `.navigationBarTrailing` | **macOS ABSENT — no macOS arm (iOS/iPadOS/Mac Catalyst/tvOS/visionOS only, deprecated → `topBarLeading`/`topBarTrailing` which are themselves macOS-absent)** | N/A — on macOS use `.navigation`/`.primaryAction` |
| `ToolbarItemPlacement.topBarLeading` / `.topBarTrailing` | **macOS ABSENT — compile error on Mac** | N/A — use `.navigation`/`.primaryAction` |
| `ToolbarItemPlacement.primaryAction` | macOS 11.0+ (leads on macOS) | No |
| `ToolbarSpacer` | macOS 26.0+ | No |
| `Transferable` protocol | macOS 13.0+ | No |
| `transition(_:)` | macOS 10.15+ | No |
| `#Unique` (SwiftData) | macOS 15.0+ | No |
| `UtilityWindow` | macOS 15.0+ | No |
| `Window` (scene) | macOS 13.0+ | No |
| `windowIdealPlacement(_:)` | macOS 15.0+ | No |
| `WindowStyle` (protocol) / `WindowGroup` | macOS 11.0+ | No |
| `WindowStyle.volumetric` | **visionOS only — macOS ABSENT** | N/A |
| `WheelPickerStyle` / `.pickerStyle(.wheel)` | **NO macOS arm — compile error on non-Catalyst macOS** | N/A |
| `withAnimation(_:_:)` | macOS 10.15+ | No |

**148 symbols / symbol groups.**

---

## 2. The macOS-26.5 deprecation set (post-date most training data)

Surfaced as a set so the lint and `api-currency` audit catch them together:

1. `dropDestination(for:action:isTargeted:)` → `dropDestination(for:isEnabled:action:)`
2. `MagnificationGesture` / `RotationGesture` → `MagnifyGesture` / `RotateGesture`
3. `Font.system(_:design:)` (design-only) → `Font.system(_:design:weight:)`
4. `foregroundColor(_:)` / `accentColor(_:)` → `foregroundStyle(_:)` / `tint(_:)`
5. `tabItem { … }` → `Tab(…) { }` · `NavigationView` → `NavigationStack`/`NavigationSplitView` ·
   `tableStyle(.inset(alternatesRowBackgrounds:))` → `.tableStyle(.inset).alternatingRowBackgrounds()`

> **What "26.5" means here — verified against the local SDK (`MacOSX26.5.sdk`,
> `SwiftUI.swiftinterface`, 2026-06-09).** Every symbol above is annotated
> `@available(macOS, introduced: …, deprecated: 100000.0, …)`. `100000.0` is Apple's
> **soft-deprecation sentinel**: deprecated *now* (the annotation is already present in the
> macOS 26.5 SDK), with **no fixed removal version**. Xcode/`developer.apple.com` render the
> sentinel as whatever SDK you view it against — so against this corpus's target **macOS 26.5
> SDK it surfaces as "deprecated, 26.5."** Treat "26.5" as *that SDK rendering*, **not** a hard
> removal version; do **not** assert a literal future close (e.g. "27.0"). The lone genuinely
> versioned member is the **`Text` `+` operator**, which carries a concrete `deprecated: 26.0`
> (one cycle earlier) — keep it labelled 26.0. The 1,857-app corpus reports these as
> `deprecated: false` because it was parsed before the doc revision; **this table wins.**

---

## 3. Standing `verify against Xcode 26 SDK` items (carry as flags, never assert)

`pushWindow` macOS availability ·
`navigationSplitViewColumnWidth` no-op on detail · `PreviewModifier` / `.modifier(_:)` exact badge ·
`.asymmetric(insertion:removal:)` factory floor · `Spring.spring(duration:bounce:blendDuration:)`
overload badge · `RectanglePlot` / `RulePlot` exact badge · `scrollEdgeEffectStyle` `.hard`/`.soft`
default · `HistoryDescriptor.sortBy` member badge · inspector 270-vs-225 pt · `cornerRadius`
deprecation window.

*(Resolved 2026-06-09 against the local `MacOSX26.5.sdk`: `@Model` inheritance = macOS 26.0;
`windowIdealPlacement` = 15.0; `#Index` = 15.0; `Text.init(_:format:)` AttributedString = 15.0;
`HistoryDescriptor.sortBy` = 26.0; `RectanglePlot`/`RulePlot` = 15.0; `ToolbarItemPlacement.navigationBar*`
= macOS ABSENT, not a low floor. The deprecation set in §2 carries Apple's `100000` soft-sentinel, not a literal version.)*

---

## Two systematic traps (do not be fooled)

- **DocC type-property inheritance quirk.** A `static var`/type-property's rendered floor can
  inherit its enclosing type's floor. Spring presets render `macOS 10.15` but are really `macOS 14`
  (WWDC23 provenance). Cross-check type-properties against WWDC provenance via Sosumi.
- **`macOS ABSENT` is not a low floor.** `topBarLeading`, `.glassBackgroundEffect()`,
  `WheelPickerStyle`, `WindowStyle.volumetric`, the visionOS `Preview` overload — these have **no**
  macOS arm. They are platform-wrong, not under-gated. Never wrap them in `#available(macOS …)`.

---

## Sources

- `developer.apple.com` SwiftUI / SwiftData / AppKit / Charts / Foundation symbol pages + JSON
  availability endpoints (access date **2026-06-07**), fetched via Sosumi.
- WWDC23 (spring presets provenance) and WWDC25 (Liquid Glass, `@Model` inheritance), via Sosumi.
- Apple-doc fetch path: `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
