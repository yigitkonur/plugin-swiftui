# Liquid Glass (macOS 26)

> The single highest API-hallucination domain in this skill. Liquid Glass shipped at **WWDC25 (June 9, 2025)** in **macOS 26 Tahoe** — so almost no pre-2025 training data holds the real API. AI fails two opposite ways: it **invents** a plausible name (`.glassBackground()`, `.liquidGlass()`, `LiquidGlassView`, `.material(.glass)`), or it knows the real `glassEffect()` but **breaks the design rules** (glass on content, glass-on-glass, no container, no availability gate).
>
> macOS-only. Every ✅ compiles against the macOS SDK and is gated on the **macOS** arm; iOS appears solely as ❌ contrast or to note where a symbol behaves differently than on macOS. Verified against the Apple docs snapshot of 2026-06-07 (macOS 26 Tahoe, Xcode 26, Swift 6.3.2).

**What it is.** Liquid Glass is a real-time light-lensing **material**, not a blur and not `NSVisualEffectView` renamed. Content behind it stays visible (optically bent, not Gaussian-smeared), and the glass picks up tint from whatever sits beneath it. It is a **navigation-layer** material: it floats above content so content can shine through. Treat it as a tinted pane between two layers — you declare *placement, shape, tint*; the system owns lensing, motion highlights, and accessibility adaptation.

**Why AI gets this wrong.** (a) **Recency** — the names, the `Glass` struct, and the container model are all new in the macOS 26 SDK; a pre-mid-2025 corpus has zero exposure and confabulates in Apple's usual shape (`.somethingBackground()`, `.material(...)`). (b) **Word without discipline** — even models that ingested some 2025 content absorb the *word* "glass" but not the rules Apple attaches (navigation only, never glass-on-glass, group in a container because glass can't sample glass), producing real-name + wrong-placement that compiles but looks broken. (c) **No availability awareness** — every glass symbol is `macOS 26.0+`; Mac users routinely run N-1, so shipping apps target macOS 14/15 *and* 26, and an ungated call is a build break.

---

## The real API surface (macOS-available only)

All of the following are confirmed `macOS 26.0+` from Apple primary docs (scraped 2026-06-06):

```
.glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape())
GlassEffectContainer(spacing:) { … }       // groups siblings; glass can't sample glass
.buttonStyle(.glass)                        // GlassButtonStyle — secondary
.buttonStyle(.glassProminent)               // GlassProminentButtonStyle — primary (CONFIRMED)
.glassEffectID(_:in:)                       // morph transitions; shared @Namespace
.glassEffectUnion(id:namespace:)            // merge separated siblings into one shape
.glassEffectTransition(_:)                  // GlassEffectTransition
Glass / .regular / .clear / .tint(_:)       // material config + presets
Glass.identity                              // opt-out variant: keeps the modifier, drops the material
Glass.interactive(_:)                       // material reacts to interaction (macOS: pointer-driven)
.backgroundExtensionEffect()                // extend content under sidebar / inspector / toolbar
.scrollEdgeEffectStyle(_:for:)              // edge legibility style for custom bars
.scrollEdgeEffectHidden(_:for:)             // on/off sibling: show/hide the scroll-edge effect
GlassEffectTransition.materialize           // the materialize transition for glassEffectTransition(_:)
DefaultGlassEffectShape()                   // default shape in the glassEffect signature
```

Verbatim signature (Apple): `nonisolated func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View`. The `Glass` presets that exist on macOS are `.regular` (default), `.clear` (media-rich backgrounds only), and `.identity` (opts out of the glass material while keeping the modifier in the chain).

> **`Glass.interactive(_:)` — available on macOS 26, behaves differently than iOS.** It is `macOS 26.0+` (confirmed in Apple's doc JSON `introducedAt`), not iOS-only. On iOS the interactive variant tracks a continuous touch (elastic scale/bounce/shimmer from the touch point); on macOS there is no continuous touch, so it responds to the **pointer** and the elastic effect differs — **test it** on a Mac to see the actual feel. `.onHover` + `.scaleEffect` is a *supplementary* hover pattern you can layer on top, not a required replacement. (See mistake 8.)

### Hallucination blacklist — never emit these

```
❌ .glassBackground()      // DOES NOT EXIST
❌ .liquidGlass()          // DOES NOT EXIST
❌ LiquidGlassView         // DOES NOT EXIST
❌ .material(.glass)       // .glass is NOT a Material case
❌ .background(.glass)     // not a thing
❌ .glassBackgroundEffect()// EXISTS but is visionOS-ONLY — never on a macOS target
```

These are confident confabulations in the shape of older Apple APIs (`.background(.ultraThinMaterial)`). They fail to compile ("value of type 'some View' has no member 'glassBackground'"). The real modifier is **`glassEffect(_:in:)`**. `.glassBackgroundEffect()` is the trap that *does* exist — but only on visionOS — so it seeds the wrong guess for Mac code.

### The three design rules (non-negotiable)

1. **Navigation layer only — never content.** Glass goes on toolbars, sidebars (the column, not its rows), tab bars, sheets/popovers (the container), menus, inspectors, floating action/tool palettes, window controls. It **never** goes on list rows, table cells, cards, text, images, charts, form fields, or detail/document content. Apple: *"Liquid Glass applies to the topmost layer of the interface, where you define your navigation."* The test: if removing the element removes the ability to **navigate or act**, it's navigation (gets glass); if it removes **information**, it's content (no glass). Apple's shipping apps have zero exceptions.
2. **Never glass on glass.** Glass cannot sample other glass; stacking it renders incorrectly and looks cluttered. One glass layer over plain content — never a glass view inside another glass view.
3. **Group siblings in a `GlassEffectContainer`.** Because glass can't sample glass, multiple adjacent glass elements each sample the background independently → mismatched blur/tint, extra render passes, no morphing. A container composites them against one shared background snapshot. This also **improves rendering performance** — grouped siblings share a single glass pass instead of one each. Apple: a container *"combines multiple Liquid Glass shapes into a single shape that can morph individual shapes into one another."*

---

## The 8 mistakes (❌ WRONG → ✅ CORRECT)

### 1. Inventing the modifier name

```swift
// ❌ WRONG — all four are hallucinated; none compile
MyToolbar().glassBackground()
MyToolbar().liquidGlass()
LiquidGlassView { MyToolbar() }
MyPanel().background(.material(.glass))      // .glass is not a Material case

// ✅ CORRECT — the real modifier, gated on the macOS arm
if #available(macOS 26.0, *) {
    FloatingControls().glassEffect()                  // default: .regular, DefaultGlassEffectShape()
    FloatingControls().glassEffect(.regular, in: .capsule)   // explicit shape
}
```

`.glassBackgroundEffect()` exists but is **visionOS-only** — never use it on a macOS target.

### 2. Glass on the content layer instead of the navigation layer

```swift
// ❌ WRONG — glass on content (rows are content, not chrome)
List {
    ForEach(items) { item in
        Text(item.name).glassEffect()        // DON'T
    }
}

// ✅ CORRECT — glass only on the floating navigation/control layer; content stays plain
ZStack {
    List { /* content — no glass */ }
    VStack {
        Spacer()
        FloatingButton().glassEffect(.regular, in: .capsule)   // .interactive() optional (see mistake 8)
    }
}
```

Glass on a list row tells the visual system a row is structural chrome. It looks wrong and hurts legibility. Apple ships **zero** exceptions: in Finder/Mail/Photos the toolbar and sidebar have glass; rows, message cells, and thumbnails never do.

### 3. Stacking glass on glass

```swift
// ❌ WRONG — second glass layer over the first; glass can't sample glass
VStack {
    HeaderView().glassEffect()
    ContentView().glassEffect()
}

// ✅ CORRECT — a single glass layer over plain content
ZStack {
    ContentView()                            // no glass
    FloatingControls().glassEffect()         // one layer
}
```

### 4. Multiple sibling glass elements without a `GlassEffectContainer`

```swift
// ❌ WRONG — each samples the background independently → inconsistent, slower, can't morph
HStack {
    Button("Edit")   {}.glassEffect()
    Button("Share")  {}.glassEffect()
    Button("Delete") {}.glassEffect()
}

// ✅ CORRECT — one shared sampling region
GlassEffectContainer(spacing: 16) {
    HStack(spacing: 16) {
        Button("Edit")   {}.glassEffect()
        Button("Share")  {}.glassEffect()
        Button("Delete") {}.glassEffect()
    }
}
```

Frame the **inner content**, not the container — the container is layout-transparent. And too *many* containers / too many effects outside containers also degrades performance (each `.glassEffect()` allocates a backdrop layer with offscreen textures) — group, don't sprinkle.

### 5. No `#available` gating for macOS 14/15 users (the macOS-sharpest mistake)

```swift
// ❌ WRONG when the deployment target is below macOS 26 — won't compile
struct ToolbarView: View {
    var body: some View {
        HStack { /* … */ }.glassEffect()     // glassEffect is macOS 26.0+ only
    }
}

// ✅ CORRECT — runtime branch with a pre-26 fallback (.ultraThinMaterial / .regularMaterial)
struct ToolbarView: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            controls.glassEffect()
        } else {
            controls.background(.ultraThinMaterial)   // macOS 15 and earlier
        }
    }
}

// ✅ CORRECT — reusable helper (use ONE transparency system per view: branch between
// .glassEffect() and .background(.ultraThinMaterial); don't stack both — see detection tells)
extension View {
    @ViewBuilder
    func glassIfAvailable() -> some View {
        if #available(macOS 26.0, *) { self.glassEffect() }
        else { self.background(.ultraThinMaterial) }
    }
}
```

Every Liquid Glass symbol is `macOS 26.0+`. Mac users lag on upgrades, so the exact code that ships for an iOS-26-only iPhone fails to build for a macOS-15 target. Gate on the **macOS** arm — `#available(macOS 26.0, *)`, never `iOS 26.0` (a copied iOS gate never fires on a Mac because the wildcard `*` already covers macOS, so the floor is never enforced). Use `@available(macOS 26.0, *)` to mark a whole type/function that only runs on 26+.

### 6. Hand-rolling glass buttons instead of the glass button styles

```swift
// ❌ WRONG — over-engineered custom glass on a plain button (wrong shape/tint behavior)
Button("Save") {}.padding().glassEffect(.regular).clipShape(.capsule)

// ✅ CORRECT — Apple's button styles: .glass (secondary), .glassProminent (primary)
if #available(macOS 26.0, *) {
    HStack {
        Button("Cancel") {}.buttonStyle(.glass)
        Button("Save")   {}.buttonStyle(.glassProminent).tint(.accentColor)   // tint PRIMARY only
    }
}
```

`.buttonStyle(.glass)` → `GlassButtonStyle`; `.buttonStyle(.glassProminent)` → `GlassProminentButtonStyle` (CONFIRMED `macOS 26.0+`). These adapt their shape to context (capsule in toolbars, rounded rect elsewhere). Apple: *"Instead of creating buttons with custom Liquid Glass effects, you can adopt the look and feel of the material with minimal code by using one of the … button style APIs."* Tint the **one** primary action per screen — never two.

### 7. Manually re-glassing chrome that auto-adopts on SDK rebuild

```swift
// ❌ WRONG — re-glassing standard chrome that's already glass for free → risks glass-on-glass
NavigationSplitView { Sidebar().glassEffect() } detail: { Detail() }   // DON'T glass the sidebar
.toolbar { ToolbarItem { Button("Add", systemImage: "plus") {} } }
.toolbarBackground(.visible, for: .windowToolbar)                      // also blocks glass

// ✅ CORRECT — rebuild on the macOS 26 SDK and standard chrome adopts glass automatically;
//             only hand-apply .glassEffect() to genuinely CUSTOM floating controls
NavigationSplitView {
    Sidebar()
        .backgroundExtensionEffect()         // extend content under the floating glass sidebar
} detail: {
    Detail().toolbar { ToolbarItem { Button("Add", systemImage: "plus") {} } }
}
```

Recompiling against the macOS 26 SDK auto-adopts Liquid Glass for **Toolbar, Sidebar, Menu bar, Dock, Window controls, `NSPopover`, and Sheets** — for free. Re-glassing them fights the system and risks glass-on-glass (mistake 3). Removing old overrides matters too: `.toolbarBackground(.visible)` and `.toolbarColorScheme(_:)` from the pre-Tahoe era block glass rendering — delete them.

### 8. Mixing `.regular` with `.clear` (and how `.interactive()` behaves on macOS)

```swift
// ❌ WRONG — never mix .regular with .clear in one group
HStack {
    Button("A") {}.glassEffect(.regular)
    Button("B") {}.glassEffect(.clear)                   // mixed variant in the same group
}

// ✅ CORRECT — one variant per group; .interactive() IS available on macOS 26
@State private var hovered = false
Button("A") {}
    .glassEffect(.regular.interactive())                 // macOS 26: responds to the pointer — test the feel
    .onHover { hovered = $0 }                             // optional supplementary hover layer
    .scaleEffect(hovered ? 1.02 : 1.0)
    .animation(.easeInOut(duration: 0.2), value: hovered)
```

`.regular` and `.clear` have different characteristics and must never be mixed within a group; reserve `.clear` for media-rich, bold, bright content. `Glass.interactive(_:)` **is** `macOS 26.0+` — call it on a macOS path if you want the material to react to interaction; just remember the elastic response is driven by the pointer (no continuous touch), so its feel differs from iOS — verify it on a Mac. `.onHover` + `.scaleEffect` is a supplementary pattern, not a substitute. For morphing between sibling shapes, keep one variant, share a `@Namespace`, and use `glassEffectID(_:in:)` inside a `GlassEffectContainer` (all four required: same container, `@Namespace` + `glassEffectID`, `withAnimation`, and conditional render — not just `.opacity`/hidden).

---

## macOS toolbar & title-bar fixes

Steal these — they are macOS-only window-chrome adjustments that the auto-glass model needs, sourced from a shipping macOS-26 skill (`tgrinblatt/tyler-app-style`) and the macOS pitfalls reference.

```swift
// Transparent window toolbar so glass/content reads cleanly through the title bar (macOS-only)
.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)   // macOS 15.0+ (CONFIRMED)

// AppKit title-bar transparency, applied to the live windows
for window in NSApp.windows {
    window.titlebarAppearsTransparent = true
}

// Remove the toolbar title for a clean glass surface
.toolbar(removing: .title)

// macOS-26 GOTCHA: EVERY ToolbarItem auto-glasses. To opt a group OUT of the shared
// glass platter (each item renders its own / no shared background), use ToolbarItemGroup
// + .sharedBackgroundVisibility(.hidden):
.toolbar {
    ToolbarItemGroup(placement: .primaryAction) {
        Button("Bold",   systemImage: "bold")   {}
        Button("Italic", systemImage: "italic") {}
    }
    .sharedBackgroundVisibility(.hidden)         // macOS 26.0+ ToolbarContent method (CONFIRMED)
}

// Restore the glass toolbar when a constrained TextEditor/scroll view forces it opaque:
.scrollEdgeEffectStyle(.soft, for: .top)         // macOS 26.0+ (CONFIRMED); .hard/.soft default still unverified
```

Swift-6 strict-concurrency detail for AppKit fonts on the Mac: a non-`Sendable` `NSFont` static will not compile under strict concurrency — declare it `nonisolated(unsafe)`:

```swift
// ✅ NSFont is not Sendable → strict concurrency rejects a bare static; mark it explicitly
nonisolated(unsafe) static let dataFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
```

Other macOS specifics: `.backgroundExtensionEffect()` extends sidebar/inspector/hero content under the floating glass chrome (it mirrors the view into the safe-area edges); on macOS the scroll-edge default is `.hard` (crisp divider) where iOS is `.soft`; window corner radii are system-managed (≈16/20/26pt by toolbar config) — do not override with custom clipping.

---

## Scroll-edge effects: macOS defaults to `.hard` (the TextEditor-toolbar trap)

`scrollEdgeEffectStyle(_:for:)` controls how a scrolling region meets the glass bar at its edge. The platform defaults differ, and the macOS default catches people who copy iOS code:

- **macOS:** `.scrollEdgeEffectStyle(.automatic)` resolves to **`.hard`** for *all* edges (top and bottom) — a crisp dividing line between the bar and the content.
- **iOS:** `.automatic` resolves to **`.soft`** for all edges — content fades translucently under the bar glass.

The macOS-sharpest pitfall: a `TextEditor` constrained inside a `NavigationSplitView` detail column forces the toolbar **opaque with a visible border**, losing glass entirely. The fix is to opt the top edge into the soft blend so the glass reads through again:

```swift
// ❌ WRONG — constrained TextEditor in a split-view detail; toolbar goes opaque + bordered, glass lost
NavigationSplitView {
    Sidebar()
} detail: {
    TextEditor(text: $content)              // forces an opaque, hard-bordered toolbar on macOS
}

// ✅ CORRECT — restore the glass toolbar by softening the top scroll edge
NavigationSplitView {
    Sidebar()
} detail: {
    TextEditor(text: $content)
        .scrollEdgeEffectStyle(.soft, for: .top)   // modifier is CONFIRMED macOS 26.0+; this pitfall is community-sourced
}
```

`.hard` vs `.soft` decision — **keep `.hard`** (the reported macOS default) for document-/list-oriented surfaces where a clear toolbar boundary aids readability (text documents, settings lists, tables); **switch to `.soft`** for media-/hero-led surfaces where the bar should feel integrated with the scroll (media browsers, canvas/editor views, image-heavy layouts). Mix per edge: `.scrollEdgeEffectStyle(.soft, for: .top)` with `.scrollEdgeEffectStyle(.hard, for: .bottom)`. To toggle the effect on or off entirely rather than restyle it, use the sibling `.scrollEdgeEffectHidden(_:for:)` (macOS 26.0+). The modifier `scrollEdgeEffectStyle(_:for:)` is confirmed `macOS 26.0+`; what stays **unverified** is the `.hard`-vs-`.soft` default behavior and this constrained-`TextEditor` pitfall (community-sourced) — confirm both on a Mac before relying on them.

---

## Liquid Glass migration notes (Tab placement, state restoration, auto-removing legacy code)

Two migration details that the auto-glass model drops on macOS:

- **`Tab(...)` + `@SceneStorage` for tab selection.** The new `Tab(...)` struct (macOS 15.0+) replaces the old `TabView`-style placement that the Liquid Glass tab look depends on. When you adopt it, tab-selection **state restoration is no longer automatic** — bind the selection to `@SceneStorage` so the active tab survives relaunch/window-restore.
- **Auto-removing the backward-compat `LabelStyle`.** A custom `LabelStyle` you add to keep toolbar items looking right on pre-Tahoe OSes is dead code once you raise the deployment target to macOS 26. Annotate it `@available(macOS, obsoleted: 26)` so the compiler **flags it for removal** the moment the floor moves to 26 — the same auto-removal idiom you use for any legacy AppKit vibrancy helper.

```swift
// ❌ WRONG — Tab selection has no restoration backing; reopening the app loses the active tab
struct RootView: View {
    @State private var selection: Panel = .home
    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: Panel.home) { HomeView() }
            Tab("Stats", systemImage: "chart.bar", value: Panel.stats) { StatsView() }
        }
    }
}

// ✅ CORRECT — @SceneStorage restores the selected tab across launches; legacy LabelStyle self-retires
struct RootView: View {
    @SceneStorage("rootTab") private var selection: Panel = .home   // restoration-backed selection
    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: Panel.home) { HomeView() }
            Tab("Stats", systemImage: "chart.bar", value: Panel.stats) { StatsView() }
        }
    }
}

// ✅ CORRECT — backward-compat toolbar LabelStyle the compiler will force you to delete at the macOS 26 floor
@available(macOS, obsoleted: 26, message: "Drop once the deployment target is macOS 26 — glass styles items.")
struct LegacyToolbarLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.icon; configuration.title }
    }
}
```

The migration is **not backward-compatible**: apps targeting macOS 15 and earlier receive none of the glass behaviors and still need the conditional paths above.

---

## Detection tells

Grep / scan tells for review or a lint pass:

- **Hallucinated names — hard fail:** `.glassBackground(` · `.liquidGlass(` · `LiquidGlassView` · `.material(.glass)` · `.background(.glass)`. None exist on macOS. `.glassBackgroundEffect(` on a macOS target → visionOS-only, flag it.
- **Glass on content:** `.glassEffect()` inside a `List {` / `ForEach {` / `Table {`, or on a card/cell/text/image/full-screen background. Belongs on floating chrome only.
- **Glass-on-glass:** two or more `.glassEffect(` on nested/stacked views without a `GlassEffectContainer` between them.
- **Missing container:** ≥2 sibling `.glassEffect(` / `.buttonStyle(.glass` in one `HStack`/`VStack` with no enclosing `GlassEffectContainer`.
- **Ungated symbols:** any `glassEffect` / `GlassEffectContainer` / `.buttonStyle(.glass` / `glassEffectID` / `glassEffectUnion` / `glassEffectTransition` / `backgroundExtensionEffect` / `scrollEdgeEffectStyle` / `scrollEdgeEffectHidden` / `.sharedBackgroundVisibility` / `Glass.identity` / `Glass.interactive` with no nearby `#available(macOS 26` / `@available(macOS 26` when the deployment target is below macOS 26.
- **Wrong gate arm:** `#available(iOS 26.0, *)` guarding a macOS build — the branch always runs on a Mac and the floor is never enforced. Use `macOS 26.0`.
- **Variant mixing:** `.glassEffect(.regular` and `.glassEffect(.clear` in the same group.
- **Tint spam:** more than one `.tint(` / `.glassProminent` among sibling glass controls — tint the single primary action only.
- **Manual re-glassing of free chrome:** `.glassEffect()` on a standard `.toolbar`, sidebar, or sheet that already auto-adopts; or a leftover `.toolbarBackground(.visible)` / `.toolbarColorScheme(` that blocks glass.
- **Double transparency:** `.glassEffect()` on a view that also has `.background(.ultraThinMaterial)` — stacking two transparency systems. Community-reported as crashing in early betas, but **unverified against the shipping macOS 26 SDK** — test before relying on it either way; regardless, use one system per view.

---

## Canonical pattern

Quote this verbatim. Custom floating glass controls on macOS 26, gated, container-grouped, one variant, supplementary hover feedback (add `.regular.interactive()` if you also want the material itself to react), single tinted primary:

```swift
import SwiftUI

struct FloatingToolPalette: View {
    @Namespace private var ns
    @State private var hovered: Tool?
    @State private var active: Tool = .pencil

    var body: some View {
        if #available(macOS 26.0, *) {
            // ✅ glass on a CUSTOM floating control (navigation layer), grouped in a container
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(Tool.allCases) { tool in
                        Button {
                            withAnimation(.bouncy) { active = tool }
                        } label: {
                            Image(systemName: tool.symbol)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(active == tool ? .glassProminent : .glass)   // tint only the active/primary
                        .glassEffectID(tool.id, in: ns)                            // morph between selections
                        .onHover { hovered = $0 ? tool : nil }                     // supplementary hover (or add .interactive())
                        .scaleEffect(hovered == tool ? 1.04 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: hovered)
                        .accessibilityLabel(tool.label)                            // icon-only → needs a label
                    }
                }
                .padding(8)                                                        // frame INNER content, not the container
            }
        } else {
            // pre-26 fallback: plain material, no glass APIs referenced
            HStack(spacing: 12) {
                ForEach(Tool.allCases) { tool in
                    Button { active = tool } label: {
                        Image(systemName: tool.symbol).frame(width: 28, height: 28)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
    }
}

enum Tool: String, CaseIterable, Identifiable {
    case pencil, eraser, lasso
    var id: String { rawValue }
    var symbol: String { ["pencil": "pencil", "eraser": "eraser", "lasso": "lasso"][rawValue]! }
    var label: String { rawValue.capitalized }
}
```

---

## Sources

- Apple — `glassEffect(_:in:)` (real modifier; `macOS 26.0+`; verbatim `nonisolated func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View`): https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) (scraped 2026-06-06).
- Apple — `GlassEffectContainer` (`macOS 26.0+`; *"combines multiple Liquid Glass shapes into a single shape that can morph…"*): https://developer.apple.com/documentation/swiftui/glasseffectcontainer (scraped 2026-06-06).
- Apple — `GlassButtonStyle` + `.buttonStyle(.glass)` (`macOS 26.0+`): https://developer.apple.com/documentation/swiftui/glassbuttonstyle and https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass (scraped 2026-06-06).
- Apple — `GlassProminentButtonStyle` + `.buttonStyle(.glassProminent)` (`macOS 26.0+`): https://developer.apple.com/documentation/swiftui/glassprominentbuttonstyle and https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent (scraped 2026-06-07).
- Apple — `Glass` and its members `Glass.identity`, `Glass.interactive(_:)`, `Glass.tint(_:)`, plus `glassEffectID(_:in:)`, `glassEffectUnion(id:namespace:)`, `glassEffectTransition(_:)`, `GlassEffectTransition.materialize`, `backgroundExtensionEffect()`, `scrollEdgeEffectStyle(_:for:)`, `scrollEdgeEffectHidden(_:for:)` (all `macOS 26.0+` per doc JSON `introducedAt`). `Glass.interactive(_:)` is confirmed available on macOS 26 (not iOS-only); on macOS it is pointer-driven, so its elastic behavior differs from iOS. Roots: https://developer.apple.com/documentation/swiftui/glass , /glass/identity , /glass/interactive(_:) , /view/glasseffectid(_:in:) , /view/glasseffectunion(id:namespace:) , /view/glasseffecttransition(_:) , /swiftui/glasseffecttransition/materialize , /view/backgroundextensioneffect() , /view/scrolledgeeffectstyle(_:for:) , /view/scrolledgeeffecthidden(_:for:) (scraped 2026-06-07).
- Apple — toolbar visibility modifiers: `.sharedBackgroundVisibility(_:)` (a `ToolbarContent` method, `macOS 26.0+`, CONFIRMED) and `.toolbarBackgroundVisibility(_:for:)` (`macOS 15.0+`, CONFIRMED): https://developer.apple.com/documentation/swiftui/toolbarcontent/sharedbackgroundvisibility(_:) and https://developer.apple.com/documentation/swiftui/view/toolbarbackgroundvisibility(_:for:) (scraped 2026-06-07).
- Apple — Adopting Liquid Glass (navigation-layer-only rule; *"do so sparingly"*; auto-adoption of system bars; background extension): https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass (scraped 2026-06-06).
- Apple — Applying Liquid Glass to custom views (container blends/morphs shapes; too many containers/effects degrade performance): https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views (scraped 2026-06-06).
- WWDC25 — Session 219 "Meet Liquid Glass" and Session 323 "Build a SwiftUI app with the new design" (Jun 9 2025): https://developer.apple.com/videos/play/wwdc2025/219/ and https://developer.apple.com/videos/play/wwdc2025/323/ — design-rule provenance ("navigation layer only", "always avoid glass on glass", "glass cannot sample other glass", never-mix-variants, tint primary only).
- WWDC25 — Session 256 (new design-system / Liquid Glass guidance referenced for the navigation-layer and material rules), Jun 9 2025: https://developer.apple.com/videos/play/wwdc2025/256/ .
- `tgrinblatt/tyler-app-style` (shipping macOS-26 reference) — title-bar/toolbar fixes: `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`, `window.titlebarAppearsTransparent`, auto-glass opt-out via `ToolbarItemGroup` + `.sharedBackgroundVisibility(.hidden)`, `nonisolated(unsafe)` `NSFont`: https://github.com/tgrinblatt/tyler-app-style (captured 2026-06-06).
- diskcleankit (dev.to) — *"Liquid Glass in Swift: official best practices for iOS 26 / macOS Tahoe"* (relays WWDC25 219/323 quotes: navigation-layer only, never glass-on-glass, group in `GlassEffectContainer`, never mix variants, tint primary only, macOS free auto-adoption list): https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo (captured 2026-06-06).
- Donny Wals — *"Grouping Liquid Glass components using glassEffectUnion"* (`glassEffectUnion` grouping conditions: same `id`, same glass style, same tint): https://www.donnywals.com/grouping-liquid-glass-components-using-glasseffectunion-on-ios-26/ (captured 2026-06-06).
- Majid Jabrayilov (swiftwithmajid.com, Jul 2025) — Liquid Glass migration: `Tab` struct replaces the old `TabView` placement, `@SceneStorage` now required for tab-selection restoration, backward-compat `LabelStyle` annotated for auto-removal, migration is not backward-compatible: https://swiftwithmajid.com/2025/07/01/liquid-glass-in-swiftui/ (captured 2026-06-06).

**CONFIRMED `macOS 26.0+` (Apple doc JSON, scraped 2026-06-07):** `glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)` / `.glassProminent`, `glassEffectID(_:in:)`, `glassEffectUnion(id:namespace:)`, `glassEffectTransition(_:)`, `GlassEffectTransition.materialize`, `Glass` / `.regular` / `.clear` / `.identity` / `.interactive(_:)` / `.tint(_:)`, `backgroundExtensionEffect()`, `scrollEdgeEffectStyle(_:for:)`, `scrollEdgeEffectHidden(_:for:)`, `.sharedBackgroundVisibility(_:)` (a `ToolbarContent` method). **CONFIRMED `macOS 15.0+`:** `.toolbarBackgroundVisibility(_:for:)`. **Behaves differently on macOS (test it):** `Glass.interactive(_:)` is available on macOS 26 but is pointer-driven (no continuous touch), so its elastic feel differs from iOS — verify on a Mac. **NOT on macOS:** `.glassBackgroundEffect()` (visionOS-only). **Still UNVERIFIED — carry, do not assert; confirm on a Mac:** the macOS `.hard` vs iOS `.soft` scroll-edge *default* behavior, and the constrained-`TextEditor`-in-`NavigationSplitView` opaque-toolbar pitfall (both community-sourced). **Community-reported, unverified against the shipping SDK:** the `.glassEffect()` + `.background(.ultraThinMaterial)` double-transparency crash. **Hallucinated — never emit:** `.glassBackground()`, `.liquidGlass()`, `LiquidGlassView`, `.material(.glass)`, `.background(.glass)`.
