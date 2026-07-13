# Version Drift, Deprecations & Hallucinated APIs (macOS)

> Read AI-generated SwiftUI. Spot the API the model learned from a 2020–2022 corpus, the modifier it invented, and the macOS-26-only call it forgot to gate. Fix all three.
>
> macOS-only. Every ✅ compiles against the macOS SDK; iOS appears solely as ❌ contrast. Verified against the Apple docs snapshot of 2026-06-06 (macOS 26 Tahoe, Xcode 26, Swift 6.3.2).

**Why AI gets this wrong.** Three mechanisms compound. (a) **Training recency** — SwiftUI renames hard every year, but the bulk of any model's corpus is the 2019–2022 surface, so it reflexively emits `NavigationView`, `.foregroundColor`, 1-param `onChange`. (b) **Confident confabulation** — for an unknown surface (especially Liquid Glass) the most *probable* next token is a plausible invention, not an admission of absence. (c) **No availability awareness** — models do not track which macOS version introduced an API, so they emit macOS-26-only calls with no `#available`, which fails to compile against a lower deployment target. The unifying tell: the code *looks* idiomatic and usually compiles, so it survives casual review.

---

## The 9 mistakes (❌ WRONG → ✅ CORRECT)

### 1. `NavigationView` → `NavigationStack` / `NavigationSplitView`

```swift
// ❌ WRONG — deprecated macOS 10.15–26.5; also iOS-shaped (stack where a Mac wants columns)
NavigationView { List(items) { row($0) } }

// ✅ CORRECT — push/stack IA
NavigationStack { List(items) { row($0) } }

// ✅ CORRECT — macOS-idiomatic sidebar (the substitution AI rarely makes)
NavigationSplitView { Sidebar() } detail: { Detail() }
```

`NavigationView` is deprecated on every platform through OS 26.5. On macOS the *right* replacement is usually `NavigationSplitView` (2–3 columns), not the stack — Apple: "Use `NavigationStack` and `NavigationSplitView` instead." Both replacements are macOS 13.0+.

### 2. `.foregroundColor(_:)` → `.foregroundStyle(_:)`

```swift
// ❌ WRONG — deprecated macOS 10.15–26.5
Text("Hi").foregroundColor(.red)

// ✅ CORRECT — same length, accepts ShapeStyle (gradients, hierarchical .primary/.secondary)
Text("Hi").foregroundStyle(.red)
Text("Hi").foregroundStyle(.secondary)
```

`foregroundColor(_:)` is deprecated with explicit "Use `foregroundStyle(_:)` instead." `foregroundStyle` is macOS 12.0+ and adapts to glass vibrancy automatically.

### 3. Single-param `onChange(of:perform:)` → two-param (or zero-param)

```swift
// ❌ WRONG — deprecated 1-param closure (since macOS 14)
.onChange(of: value) { newValue in handle(newValue) }

// ✅ CORRECT — two-parameter (oldValue, newValue), optional `initial:`
.onChange(of: value, initial: false) { oldValue, newValue in handle(newValue) }

// ✅ CORRECT — zero-parameter form
.onChange(of: value) { recompute() }
```

Apple's deprecation text: "`onChange(of:perform:)` was deprecated in iOS 17.0: Use onChange with a two or zero parameter action closure instead." Current signature `onChange<V>(of:initial:_:)` with `(V, V) -> Void` is macOS 14.0+.

### 4. Hallucinated / nonexistent modifiers → verify, then use the real call

```swift
// ❌ WRONG — invented APIs that DO NOT EXIST
.glassBackground()        // not a SwiftUI API
.liquidGlass()            // not a SwiftUI API
.material(.glass)         // not a SwiftUI API
SomeView().cardStyle()    // invented convenience modifier

// ✅ CORRECT — real Liquid Glass names, gated (see §5/§gating)
if #available(macOS 26.0, *) {
    Image(systemName: "star").padding().glassEffect()
}
```

For a brand-new surface the model fabricates a confident name. The **real** Liquid Glass API is `glassEffect(_:in:)`, `GlassEffectContainer`, `GlassButtonStyle` / `.buttonStyle(.glass)` — all `macOS 26.0+`. Treat any unfamiliar modifier as hallucinated until you find it in the docs.

### 5. Missing `#available` / `@available` gating (the macOS-sharpest mistake)

```swift
// ❌ WRONG if deployment target < macOS 26 — won't compile
struct Toolbar: View {
    var body: some View { content.glassEffect() }   // glassEffect is macOS 26.0+ only
}

// ✅ CORRECT — runtime branch with a fallback for older macOS
struct Toolbar: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            content.glassEffect()
        } else {
            content.background(.regularMaterial)     // macOS 15 and earlier
        }
    }
}
```

`glassEffect` (macOS 26), `@Observable` / `@Bindable` / two-param `onChange` (all macOS 14) carry hard minimum-OS floors. Using one below the project's deployment target is a compile error — see the gating section below, the #1 thing even good artifacts get wrong on macOS.

### 6. `.cornerRadius(_:)` → `.clipShape(RoundedRectangle(cornerRadius:))`

```swift
// ❌ WRONG — deprecated
view.cornerRadius(12)

// ✅ CORRECT — Apple-canonical: clip to a rounded-rect shape (uneven corners supported)
view.clipShape(RoundedRectangle(cornerRadius: 12))
view.clipShape(.rect(topLeadingRadius: 12, bottomTrailingRadius: 12))
```

`cornerRadius(_:)` is deprecated; Apple's text says "Use `clipShape(_:style:)` with `RoundedRectangle` instead." The replacement is **universally safe**: `clipShape(_:style:)` and `RoundedRectangle` are both `macOS 10.15+`, so it works on every macOS target with no gating. (The `.rect(cornerRadius:)` shorthand compiles via type inference too, and `.rect` also feeds the `in:` parameter of `.glassEffect`.) Only caveat: `.foregroundStyle` — not this clip — is `macOS 12.0+`, which matters solely if you target macOS 11.

### 7. `tabItem` / inline-destination `NavigationLink` → `Tab` / `.navigationDestination(for:)`

```swift
// ❌ WRONG — legacy tab item + inline list destination (eagerly builds every destination)
TabView { Home().tabItem { Label("Home", systemImage: "house") } }
List { NavigationLink("Detail", destination: DetailView()) }

// ✅ CORRECT — type-safe Tab + value-based navigation
TabView { Tab("Home", systemImage: "house") { Home() } }
List(items) { item in NavigationLink(item.name, value: item) }
    .navigationDestination(for: Item.self) { DetailView(item: $0) }
```

Inline destinations in a `List`/`ForEach` build every destination up front and break value-based navigation. `.navigationDestination(for:)` is macOS 13.0+. The `Tab(...)` struct is `macOS 15.0+` (Apple-confirmed) — gate it per the gating section for any target below macOS 15. On macOS, also reach for `.tabViewStyle(.sidebarAdaptable)` so the tabs render as a real sidebar.

### 8. `DispatchQueue.main.async` cargo-cult → `@MainActor` / structured concurrency

```swift
// ❌ WRONG (smell) — pre-async/await main-thread hop, overused under modern concurrency
DispatchQueue.main.async { self.items = newItems }

// ✅ CORRECT — stay on the main actor via isolation, not GCD
@MainActor func update(_ newItems: [Item]) { items = newItems }
// or, hopping in from a Sendable context:
await MainActor.run { items = newItems }
```

When a model hits a concurrency problem it reaches for the old GCD hop an unreasonable number of times. Note: "main actor by default" is the **opt-in** Swift 6.2 build mode (`-default-isolation MainActor`), *not* an unconditional language default — so don't assume `@MainActor` is free everywhere either.

### 9. `Text + Text` concatenation → string interpolation

```swift
// ❌ WRONG — the Text `+` operator is deprecated (macOS 10.15–26.0)
Text("Hello ") + Text(name).bold()

// ✅ CORRECT — interpolate; style the whole run, or compose with AttributedString
Text("Hello \(name)").bold()
Text(AttributedString(makeStyledGreeting(name)))   // per-run styling
```

A favourite AI cargo-cult: `static func +(Text, Text) -> Text` lets you glue styled runs, and models lean on it constantly. Apple now deprecates it — "Text concatenation using the + operator is deprecated… Use Text interpolation instead." Reach for `Text("… \(value) …")` for a uniformly-styled string, or an `AttributedString` when individual runs need different styling. **Note the window closes early:** this operator is gone at `macOS 26.0`, ahead of the `26.5` cutoff most of the other deprecations carry — so it warns sooner.

---

## Gating discipline — the `#available(macOS …)` arm (read this twice)

This is the single thing even strong artifacts get wrong, and it bites macOS harder than iOS: **Mac users lag on OS upgrades**, so Mac apps target lower floors (macOS 13/14/15) where a macOS-26 API *must* be gated. The exact code that compiles for an iOS-26-only iPhone fails for a macOS-13-targeting Mac.

- **Branch gate** — `#available` picks a code path at runtime; always supply an `else` fallback:
  ```swift
  if #available(macOS 26.0, *) { view.glassEffect() }
  else { view.background(.regularMaterial) }
  ```
- **Whole-symbol gate** — `@available` annotates a type/function that uses a floored API end to end:
  ```swift
  @available(macOS 14.0, *)
  struct ModernModel { /* uses @Observable */ }
  ```
- **Use the macOS arm, not the iOS one.** `#available(macOS 26.0, *)` — not `iOS 26.0`. A copied iOS snippet that gates on `iOS` silently does nothing on a Mac build (the wildcard `*` covers macOS, so the branch always runs and the floor is never enforced).
- **Match the floor to the real API:** `glassEffect` / Liquid Glass = macOS 26.0+; `@Observable` / `@Bindable` / two-param `onChange` = macOS 14.0+. Gate to the floor of the *highest* API in the branch.
- **Tell:** any macOS-26 / `@Observable` / `@Bindable` / two-param-`onChange` call with **no** nearby `#available` / `@available` and a deployment target below its floor — that is a build break waiting to happen.

---

## Detection tells (grep / scan)

- `NavigationView {` — deprecated; replace with `NavigationStack` or (macOS) `NavigationSplitView`.
- `.foregroundColor(` — deprecated; replace with `.foregroundStyle(`.
- `.cornerRadius(` — deprecated; replace with `.clipShape(.rect(cornerRadius:`.
- `.onChange(of:` immediately followed by a single-identifier closure `{ newValue in` / `{ value in` — deprecated 1-param form.
- `.tabItem {` — replace with the `Tab(...) { }` API.
- `NavigationLink(` carrying a `destination:` argument **inside a `List` / `ForEach`** — inline destination; move to `.navigationDestination(for:)`.
- `DispatchQueue.main.async` in a file that otherwise uses `async` / `await` — concurrency cargo-cult.
- `Text(` … `) + Text(` — deprecated `Text` `+` concatenation; replace with `Text("… \(value) …")` interpolation or an `AttributedString`.
- `.glassBackground(`, `.liquidGlass(`, `.material(.glass`, `LiquidGlassView`, or any glass-ish modifier — likely hallucinated; the real call is `.glassEffect()` and must be `#available(macOS 26.0, *)`-gated.
- `.interactive()` (or any glass call) gated on `#available(iOS 26, *)` in macOS code — wrong arm; the `*` wildcard already covers macOS so the floor is never enforced. Gate on `#available(macOS 26, *)`. `Glass.interactive(_:)` IS macOS 26.0+ (pointer-driven).
- A macOS-26 / `@Observable` / `@Bindable` / two-param-`onChange` API with **no** nearby `#available` / `@available` — missing gating (see above).
- `#available(iOS …` guarding a macOS build — wrong arm; the gate never fires on macOS.
- Any unfamiliar modifier that "reads right" but isn't in the docs — treat as hallucinated until verified.

---

## Canonical substitutions (quick reference)

```
Deprecated → current (macOS):
  NavigationView                        → NavigationStack / NavigationSplitView (prefer Split)
  .foregroundColor(_:)                  → .foregroundStyle(_:)
  .cornerRadius(_:)                     → .clipShape(RoundedRectangle(cornerRadius:))
  .onChange(of:) { newValue in }        → .onChange(of:, initial:) { old, new in }  (or 0-param)
  .tabItem { … }                        → Tab("…", systemImage:) { … }
  NavigationLink(destination:) in List  → .navigationDestination(for:)
  DispatchQueue.main.async              → @MainActor / await MainActor.run
  Text("a") + Text("b")                 → Text("a b")  (interpolation / AttributedString)

DOES NOT EXIST (hallucinations) — never trust without checking docs:
  .glassBackground()   .liquidGlass()   .material(.glass)   LiquidGlassView   .cardStyle()
  REAL Liquid Glass: .glassEffect()  GlassEffectContainer  .buttonStyle(.glass)  — macOS 26.0+ ONLY

ALWAYS gate above your deployment target — on the macOS arm:
  if #available(macOS 26.0, *) { … } else { /* fallback */ }
  @available(macOS 14.0, *) on whole types using @Observable / @Bindable.
```

**Confirmed floors** (Apple docs): `Tab(...)` struct = `macOS 15.0+`; `clipShape(_:style:)` + `RoundedRectangle` = `macOS 10.15+` (universally safe); `GlassProminentButtonStyle` / `.buttonStyle(.glassProminent)` = `macOS 26.0+` (confirmed — struct exists, not deprecated).

---

## Sources

- Paul Hudson, "What to fix in AI-generated Swift code," 2025-12-09 — https://www.hackingwithswift.com/articles/281/what-to-fix-in-ai-generated-swift-code (accessed 2026-06-06). Source for the deprecation/discouraged set (`NavigationView`, `.foregroundColor`, 1-param `onChange`, `.cornerRadius`, `tabItem`, inline `NavigationLink`, `DispatchQueue.main.async`) and hallucination prevalence.
- Apple — `NavigationView` (deprecated `macOS 10.15–26.5`; "Use NavigationStack and NavigationSplitView instead"): https://developer.apple.com/documentation/swiftui/navigationview (scraped 2026-06-06).
- Apple — `foregroundColor(_:)` (deprecated `macOS 10.15–26.5`; "Use foregroundStyle(_:) instead"): https://developer.apple.com/documentation/SwiftUI/View/foregroundColor(_:) (scraped 2026-06-06).
- Apple — `onChange(of:initial:_:)` (current 2-param, `macOS 14.0+`): https://developer.apple.com/documentation/SwiftUI/View/onChange(of:initial:_:)-4psgg (scraped 2026-06-06). Compiler deprecation text via Use Your Loaf — https://useyourloaf.com/blog/swiftui-onchange-deprecation/ (accessed 2026-06-06).
- Apple — `glassEffect(_:in:)` and `GlassEffectContainer` (real Liquid Glass names, `macOS 26.0+`): https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) and https://developer.apple.com/documentation/swiftui/glasseffectcontainer (scraped 2026-06-06).
- Apple — `clipShape(_:style:)` (`macOS 10.15+`) and `RoundedRectangle` (`macOS 10.15+`), the safe `.cornerRadius(_:)` replacement: https://developer.apple.com/documentation/swiftui/view/clipshape(_:style:) and https://developer.apple.com/documentation/swiftui/roundedrectangle (confirmed 2026-06-07).
- Apple — `Tab` struct (`macOS 15.0+`): https://developer.apple.com/documentation/swiftui/tab (confirmed 2026-06-07).
- Apple — `Text` `+` operator `static func +(Text, Text) -> Text` (deprecated `macOS 10.15–26.0`; "Text concatenation using the + operator is deprecated… Use Text interpolation instead"): https://developer.apple.com/documentation/swiftui/text/+(_:_:) (confirmed 2026-06-07).
- Apple — `Observable()` macro (`macOS 14.0+`, gating floor): https://developer.apple.com/documentation/observation/observable() (scraped 2026-06-06).
- Swift 6.2 release (main-actor-by-default is an opt-in `-default-isolation MainActor` build mode, not a language default), Holly Borla, 2025-09-15 — https://swift.org/blog/swift-6.2-released/ (scraped 2026-06-06).
- HN, "Adding a feature because ChatGPT incorrectly thinks it exists" — https://news.ycombinator.com/item?id=44491071 (accessed 2026-06-06; illustrative of API hallucination).
