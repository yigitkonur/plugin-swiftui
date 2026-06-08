# Controls, Styles & Pointer Interaction (macOS)

The control-styling and pointer-affordance layer of a Mac app: `.formStyle(.grouped)` for settings, Mac-density `buttonStyle`/`listStyle`/`pickerStyle`, `.onHover` cursor affordances, right-click `.contextMenu`, `.focusable()` + `@FocusState` keyboard focus, `.help` tooltips, and `.controlSize`. **The Mac is pointer-driven, not touch** — it has a cursor, a right mouse button, and a Tab-key focus ring. iOS has none of those, so the entire affordance vocabulary below is absent from iOS-trained habits. The result is code that compiles and looks plausible on iOS but reads as "an iPad app in a window" on macOS.

**As of 2026-06-07 · macOS 26 (Tahoe) · Swift 6.2 toolchain.** Symbol names, availability floors, and deprecations cross-checked against the Apple developer documentation. **macOS-only:** every code block compiles on a Mac target; iOS-only behavior appears *only* as ❌ contrast. Where Apple renders a multi-platform availability string, only the macOS arm is reproduced.

---

## Why AI gets this wrong

**(1) No cursor in the corpus.** iOS is touch — no hover, no tooltip, no right-click. The training data therefore has almost no `.onHover`, `.help`, or right-click `.contextMenu` code, so AI never emits the pointer affordances a Mac user expects. **(2) iOS `Form` already looks grouped.** On iOS a `Form` renders grouped/inset by default, so models never learn to ask for `.formStyle(.grouped)` — but on macOS the *default* form is ungrouped and non-native. **(3) Keyboard focus is invisible on touch.** Tab traversal and the focus ring are central to Mac usability but have no touch analog, so `.focusable()` + `@FocusState` are rarely modeled and custom views silently drop out of the Tab order. **(4) iOS-flavored control density.** AI leaves `listStyle`/`buttonStyle`/`controlSize` at defaults that read oversized on macOS — no `.listStyle(.sidebar)`, no compact `.controlSize`, no `.menu` picker.

---

## The six mistakes

### 1. Plain `Form` with no `.formStyle(.grouped)`

On macOS the default `Form` is **not** the grouped, inset, label-aligned style users expect from System Settings. iOS forms look grouped out of the box, so AI assumes the same and ships an ungrouped, foreign-looking settings pane.

```swift
// ❌ WRONG — ungrouped on macOS; looks native only on iOS
Form {
    TextField("Name", text: $name)
    Toggle("Enabled", isOn: $enabled)
}                                   // no formStyle -> non-native macOS settings look
```

```swift
// ✅ CORRECT — grouped is the macOS System-Settings idiom
Form {
    TextField("Name", text: $name)
    Toggle("Enabled", isOn: $enabled)
}
.formStyle(.grouped)                // standard macOS grouped/inset settings (macOS 13.0+)
```

### 2. No `.onHover` affordance (treats the Mac like touch)

Macs have a pointer; native rows, cards, and custom controls highlight or change the cursor when the pointer moves over them. Omitting `.onHover` makes interactive elements feel dead. There is **no iOS equivalent**, so AI never writes it.

```swift
// ❌ WRONG — custom row gives zero pointer feedback (fine on touch, dead on Mac)
Text("Open")
    .padding(6)                     // no hover highlight, no cursor change
```

```swift
// ✅ CORRECT — pointer-driven highlight; macOS has a cursor to respond to
struct HoverRow: View {
    @State private var hovering = false
    var body: some View {
        Text("Open")
            .padding(6)
            .background(hovering ? Color.accentColor.opacity(0.15) : .clear)
            .onHover { hovering = $0 }          // pointer enter/exit (macOS/Mac Catalyst)
    }
}
```

### 3. No right-click `.contextMenu`

Right-click contextual menus are a **primary** Mac interaction. AI's touch-trained habits surface actions only as on-screen buttons or swipe gestures, so right-clicking a row does nothing. The same modifier exists on iOS but fires via *long-press* — the right-click idiom is the Mac's.

```swift
// ❌ WRONG — actions only as buttons; right-click is dead on macOS
HStack {
    Text(item.title)
    Spacer()
    Button("Rename") { rename(item) }       // chrome where a right-click menu belongs
    Button("Delete") { delete(item) }
}
```

```swift
// ✅ CORRECT — right-click menu, the Mac idiom (also long-press on iOS)
Text(item.title)
    .contextMenu {
        Button("Rename") { rename(item) }
        Button("Delete", role: .destructive) { delete(item) }
    }
```

### 4. Custom views aren't keyboard-focusable

Mac users navigate by keyboard: Tab moves focus and a focus ring tracks it. A custom interactive view with no `.focusable()` / `@FocusState` can't receive focus, shows no ring, and Tab skips it — inaccessible and non-native. AI omits it because focus traversal is invisible on touch.

```swift
// ❌ WRONG — custom field never joins the Tab order; no focus ring on macOS
struct SearchField: View {
    @State private var text = ""
    var body: some View {
        TextField("Search", text: $text)    // not focusable(); Tab skips it
    }
}
```

```swift
// ✅ CORRECT — participates in keyboard focus + focus ring
struct SearchField: View {
    @FocusState private var focused: Bool   // @FocusState: macOS 12.0+
    @State private var text = ""
    var body: some View {
        TextField("Search", text: $text)
            .focusable()                     // join keyboard focus (macOS 12.0+)
            .focused($focused)               // .focused(_:) — macOS 12.0+
            .onAppear { focused = true }     // focus on appear
    }
}
```

### 5. No `.help` tooltips

On macOS `.help` renders as the standard tooltip after the pointer rests on a view for a moment (and feeds accessibility). Icon-only toolbar/inspector buttons without it are opaque. There is no iOS tooltip analog, so AI rarely emits it — yet it is mandatory polish for any glyph-only control.

```swift
// ❌ WRONG — icon-only button with no tooltip; user can't tell what it does
Button { addItem() } label: { Image(systemName: "plus") }
```

```swift
// ✅ CORRECT — tooltip on hover (macOS) + accessibility label, title case
Button { addItem() } label: { Image(systemName: "plus") }
    .help("Add a new item")                 // standard macOS tooltip on pointer rest
```

### 6. Wrong `listStyle` / `buttonStyle` / `controlSize` density for Mac

iOS-default `List`/`Button`/`Picker` styling reads oversized and non-native on macOS. A sidebar wants `.listStyle(.sidebar)` (source-list look); compact panes want `.bordered`/`.borderless` buttons, a `.menu` picker, and a smaller `.controlSize`.

```swift
// ❌ WRONG — iOS-flavored defaults: oversized sidebar, no compact controls
List(selection: $selection) { /* … */ }     // no .sidebar -> wrong sidebar material
Button("Apply") { }                          // default size reads large in a dense pane
Picker("Size", selection: $size) { … }       // wheel/default style, not the Mac pop-up
```

```swift
// ✅ CORRECT — Mac density: source-list sidebar, bordered + compact, pop-up picker
List(selection: $selection) { /* … */ }
    .listStyle(.sidebar)                     // macOS source-list sidebar

Button("Apply") { }
    .buttonStyle(.bordered)
    .controlSize(.small)                     // compact-pane density (macOS 10.15+)

Picker("Size", selection: $size) { … }
    .pickerStyle(.menu)                      // macOS pop-up button, not a wheel
```

---

## macOS-specific notes

- **`.onHover` and `.help` are pointer-only.** They do nothing on touch iOS, so they are pure Mac affordances AI must be told to add. `.help` text is title-case and especially required on icon-only toolbar buttons and every icon segment of a segmented control.
- **Right-click `.contextMenu` is the Mac idiom.** Same modifier triggers via long-press on iOS, so the *interaction* differs even though the API is shared. Mark destructive items with `role: .destructive` (red) and pair with a non-destructive escape.
- **`Form` is ungrouped by default on macOS.** `.formStyle(.grouped)` is required for the System-Settings look; iOS forms are grouped out of the box. `.columns` and `.automatic` are the other documented styles.
- **Keyboard focus + focus ring are core Mac usability.** `.focusable()` + `@FocusState` are how a custom view joins the Tab order; native controls (`TextField`, `Button`) are already focusable. Space activates a focused button; the focus ring is system-drawn.
- **`.listStyle(.sidebar)`** gives the translucent source-list sidebar (auto-adapts Light/Dark, respects Reduce Transparency).
- **Control density is explicit on macOS.** Prefer `.bordered`/`.borderless`/`.plain` button styles, `.pickerStyle(.menu)`/`.segmented`, and `.controlSize(.small)`/`.mini` for dense panes; `.regular` is the default, `.large` for prominent single actions. `ControlSize.extraLarge` exists (macOS 14.0+) but **resolves to `.large` on macOS** (no distinct visual effect), so the practical case list is `.mini`/`.small`/`.regular`/`.large`.
- **macOS-exclusive button styles, with floors.** `.link` is the link-text style (macOS 10.15+, macOS-only). `.accessoryBar` and `.accessoryBarAction` style buttons for an accessory/find bar (macOS 14.0+, macOS-only) — do **not** group their availability with `.link`'s.
- **Liquid Glass (macOS 26):** `.buttonStyle(.glass)` / `GlassButtonStyle` exist for macOS 26+ and need availability gating; `.glassProminent` is in the doc index but body-unverified — verify against your Xcode 26 SDK.

---

## The other half of pointer interaction: cursor shape & continuous position

`.onHover` answers *"is the pointer over this view?"* (a binary enter/exit), but it neither changes the **cursor shape** nor reports **where** the pointer is. Two macOS modifiers fill that gap and are the natural companions to `.onHover`.

**`pointerStyle(_:)` (macOS 15.0+) — set the cursor shape on hover.** The Mac shows different cursors to signal affordance: a resize cursor on a column divider, an open/closed hand while dragging, a link cursor over something clickable. SwiftUI exposes this declaratively (no `NSCursor.push()/pop()` bookkeeping). There is **no iOS equivalent**, so AI never emits it.

```swift
// ✅ CORRECT — declarative cursor: a resize cursor over a draggable column divider (macOS 15+)
if #available(macOS 15, *) {
    Divider()
        .frame(width: 8)
        .pointerStyle(.columnResize)        // .grabbing / .link / .frameResize(position:) etc.
}
// Other cases: .grabbing (drag in progress), .link (clickable), .frameResize(position: .bottomTrailing)
```

**`onContinuousHover(coordinateSpace:perform:)` (macOS 14.0+) — the pointer's live CGPoint.** Where `.onHover` is binary, this streams `.active(CGPoint)` while the pointer moves inside the frame and `.ended` when it leaves — needed for hover crosshairs, tooltips that track the cursor, or a value readout under the pointer in a chart.

```swift
// ✅ CORRECT — live pointer position inside the frame; binary .onHover can't do this (macOS 14+)
@State private var point: CGPoint?
SomeChart()
    .onContinuousHover(coordinateSpace: .local) { phase in
        switch phase {
        case .active(let p): point = p          // pointer moved to p (in local space)
        case .ended:         point = nil         // pointer left the frame
        }
    }
```

```swift
// ❌ WRONG — .onHover only knows enter/exit, so you can never read the cursor's position
.onHover { inside in /* `inside` is a Bool — no CGPoint available */ }
```

- **Pair them with `.onHover`, don't replace it.** `.onHover` for a highlight on enter/exit; `onContinuousHover` when you need the coordinate; `pointerStyle` to change the cursor itself. All three are pointer-only and absent from iOS habits.
- **Gate by floor:** `onContinuousHover` needs `#available(macOS 14, *)`, `pointerStyle` needs `#available(macOS 15, *)`.

---

## Detection tells

How to catch the mistake cluster in review:

- `Form {` with **no** `.formStyle(` in a macOS settings/pane context → ungrouped non-native form (mistake 1).
- A custom interactive row/card with **no** `.onHover` → missing Mac pointer affordance (mistake 2).
- A row/item view with **no** `.contextMenu` where actions exist → no right-click menu (mistake 3).
- A custom focus-taking view with **no** `.focusable()` / `@FocusState` → not keyboard-reachable, no focus ring (mistake 4).
- Icon-only `Button { } label: { Image(systemName:) }` with **no** `.help(` → no tooltip (mistake 5).
- `NavigationSplitView` sidebar `List` with **no** `.listStyle(.sidebar)` → wrong sidebar material (mistake 6).
- `Button`/`Picker` in a dense pane with no `.controlSize`/`.buttonStyle`/`.pickerStyle` → iOS-oversized density (mistake 6).
- Swipe-to-delete or `.swipeActions` as the *only* way to act on a row → that's the touch idiom; add a right-click `.contextMenu` on macOS.

---

## Canonical pattern

```swift
// Native macOS settings pane: grouped form, tooltips, hover, right-click, keyboard focus, density.
struct SettingsPane: View {
    @State private var name = ""
    @State private var enabled = false
    @State private var hovering = false
    @FocusState private var nameFocused: Bool          // macOS 12.0+

    var body: some View {
        Form {
            TextField("Name", text: $name)
                .focusable().focused($nameFocused)      // join Tab order + focus ring
            Toggle("Enabled", isOn: $enabled)
            Button { showHelp() } label: { Image(systemName: "questionmark.circle") }
                .help("Shows contextual help")          // tooltip on pointer rest (macOS)
                .buttonStyle(.borderless)
                .onHover { hovering = $0 }              // pointer affordance
        }
        .formStyle(.grouped)                            // macOS grouped settings look
        .controlSize(.regular)                          // explicit Mac density
        .contextMenu { Button("Reset") { name = "" } }  // right-click menu
        .onAppear { nameFocused = true }                // focus first field on appear
    }
}
```

**Rules:** (1) `.formStyle(.grouped)` for settings/forms — the macOS default is ungrouped. (2) `.onHover` for pointer affordances — the Mac has a cursor. (3) `.contextMenu` for right-click — a primary Mac interaction, not a long-press. (4) `.focusable()` + `@FocusState` so custom views join the Tab order and show a focus ring. (5) `.help` for tooltips on every icon-only control (title case). (6) Set `.listStyle(.sidebar)`, a button style, a `.pickerStyle(.menu)`, and `.controlSize` explicitly for Mac density — iOS defaults read oversized.

---

## Sources

Apple docs scraped 2026-06-06; availability floors re-confirmed against developer.apple.com 2026-06-07 (`focusable`/`focused` macOS 12.0+, `accessoryBar*` macOS 14.0+, `pointerStyle` macOS 15.0+, `onContinuousHover` macOS 14.0+, `help(_:)` macOS 11.0+). `formStyle(_:)` page body was nav-only on the scrape — **verify against your Xcode 26 SDK** if an exact availability badge is load-bearing.

- `formStyle(_:)` (`.automatic`/`.columns`/`.grouped`; macOS 13.0+ — body nav-only, verify): https://developer.apple.com/documentation/swiftui/view/formstyle(_:)
- `onHover(perform:)` (*"Adds an action to perform when the user moves the pointer over or away from the view's frame."*; pointer-only): https://developer.apple.com/documentation/swiftui/view/onhover(perform:)
- `contextMenu(menuItems:)` (*"Adds a context menu to a view."*; macOS 10.15+; right-click on Mac, long-press on iOS): https://developer.apple.com/documentation/swiftui/view/contextmenu(menuitems:)
- `focusable(_:)` (*"Specifies if the view is focusable."*; `func focusable(_ isFocusable: Bool = true) -> some View`; **macOS 12.0+** — not 10.15): https://developer.apple.com/documentation/swiftui/view/focusable(_:)
- `focused(_:)` (binds focus to a `@FocusState`; macOS 12.0+): https://developer.apple.com/documentation/swiftui/view/focused(_:)
- `@FocusState` (macOS 12.0+): https://developer.apple.com/documentation/swiftui/focusstate
- `help(_:)` (*"Adds help text to a view … people see as a tooltip…"*; macOS 11.0+): https://developer.apple.com/documentation/swiftui/view/help(_:)
- `controlSize(_:)` (*"Sets the size for controls within this view."*; macOS 10.15+): https://developer.apple.com/documentation/swiftui/view/controlsize(_:)
- `ControlSize` (cases `.mini`/`.small`/`.regular`/`.large`; `.extraLarge` exists macOS 14.0+ but resolves to `.large` on macOS): https://developer.apple.com/documentation/swiftui/controlsize
- `pointerStyle(_:)` (*"Sets the pointer style to display when the pointer is over the view."*; macOS 15.0+, macOS-only; `.grabbing`/`.link`/`.columnResize`/`.frameResize(position:)`): https://developer.apple.com/documentation/swiftui/view/pointerstyle(_:)
- `onContinuousHover(coordinateSpace:perform:)` (*"Adds an action to perform when the pointer moves… within the view."*; macOS 14.0+; phases `.active(CGPoint)` / `.ended`): https://developer.apple.com/documentation/swiftui/view/oncontinuoushover(coordinatespace:perform:)
- `listStyle(.sidebar)` / `buttonStyle(.bordered)` / `pickerStyle(.menu)` — current style APIs; `.link` (macOS 10.15+) and `.accessoryBar`/`.accessoryBarAction` (macOS 14.0+) are macOS-exclusive button styles, with **different** floors (HIG Buttons): https://developer.apple.com/design/human-interface-guidelines/buttons
- `.buttonStyle(.glass)` / `GlassButtonStyle` (Liquid Glass, macOS 26.0+; `.glassProminent` body-unverified): https://developer.apple.com/documentation/swiftui/glassbuttonstyle
- SerialCoder.dev — *Implementing a focusable text field in SwiftUI* (macOS): https://serialcoder.dev/text-tutorials/macos-tutorials/macos-programming-implementing-a-focusable-text-field-in-swiftui/
