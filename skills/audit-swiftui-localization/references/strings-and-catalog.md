# Reference — Strings, the String Catalog & translator comments (loc-01/02/03/04/05/09)

How user-facing text reaches a translator on macOS, and the ways SwiftUI code escapes it. Per-platform
floor *values* are not restated here — they live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. The ✅ shapes below are the **swiftui-ctx
consensus** for each API (run `swiftui-ctx lookup <api> --json` to refresh the permalinked example);
verify any uncertain symbol via Sosumi (`${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`).

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## The one fact everything hangs on

`Text` has two initializers that look identical at a call site:

```swift
init(_ key: LocalizedStringKey)        // LITERAL → auto-localizes (the key is the literal)
init(_ content: some StringProtocol)   // a String VARIABLE → NOT localized, shown verbatim
```

`Text("Save")` (a literal) is auto-localized — at build time Xcode extracts `"Save"` into the String
Catalog as a key. `Text(someVar)` silently takes the *other* overload and never reaches the catalog.
This is the single highest-frequency localization defect (loc-02). The same literal-vs-variable split
applies to `Label`, `.navigationTitle`, `Button`, `Toggle`, `.help`, `Picker` row labels, etc.

`swiftui-ctx lookup Text --json` → consensus `(_)` **99%**, `(verbatim)` 1%; recommended current
example (macOS 26, f/textream, authority 409932):
`https://github.com/f/textream/blob/6c34baaef9fea5de30bce619b4ed34cd675d5617/Textream/Textream/NotchOverlayController.swift#L910`.
`lookup LocalizedStringKey --json` → consensus `(_)` **98%**. So shipping Mac apps overwhelmingly pass
a **literal**; a variable is the outlier to scrutinize.

---

## loc-01 / loc-09 — `verbatim:` is an opt-OUT, used both ways wrong

`Text(verbatim:)` deliberately bypasses localization. Two opposite defects:

- **loc-01 — too much.** `Text(verbatim: "Save")` on human-readable UI copy ships English to every
  locale. ❌ `Text(verbatim: "Settings")` → ✅ `Text("Settings")`.
- **loc-09 — too little.** A genuinely non-translatable token — a brand name, a version string, a raw
  number — passed as a *localizable* literal pollutes the catalog with junk keys and risks a translator
  "fixing" your product name. ❌ `Text("Acme 1.0.3")` → ✅ `Text(verbatim: "Acme 1.0.3")`.

The call is **judgment** (human-readable copy vs token), so both are detected in READ, not by a regex,
and carried at the confidence you can defend. A real production opt-out (mac-mouse-fix, the 1% shape):
`https://github.com/noah-nuebling/mac-mouse-fix/blob/1fad847915cee43dbc4f1806f23ac67913462f92/Shared/Math/Curves/CurveVisualizer.swift#L40`
(`Text(verbatim: …)` around a debug/math string — correct, because it is not UI copy).

This `verbatim:` / markdown axis is **shared with `audit-swiftui-typography-text`** (it owns the
*rendering* angle; this skill owns *translatability*). On a shared site emit `cross_ref: typography-text`.

## loc-02 — a `String` variable into `Text`/`Label`/title

❌ `Text(viewModel.statusLine)` / `.navigationTitle(folder.name)` (when the value is UI copy, not data).
✅ Hold the text as a localized type so the variable *is* localized:

```swift
let status = LocalizedStringResource("status.syncing")   // macOS 13+
Text(status)                                             // localized via the resource
// or, for a String you need elsewhere:
let label = String(localized: "status.syncing", comment: "Shown while a sync is running")
```

A bare data value (a filename, a username typed by the user) is *correctly* shown verbatim — that is
not loc-02. The structural lint (`loc-02-nonliteral-text.yml`) only LOCATES; READ decides whether the
variable is UI copy or data.

## loc-03 — legacy `NSLocalizedString`

`NSLocalizedString("key", comment: "…")` is the pre-Catalog macro. It still works but is not the modern
shape and is easy to leave un-migrated. ✅ In SwiftUI, prefer the inline literal key (auto-extracted) or
`String(localized:_:)`:

```swift
// ❌ legacy
Text(NSLocalizedString("welcome.title", comment: "Welcome screen title"))
// ✅ literal key (auto-extracted to the catalog) — or String(localized:) when you need a String
Text("welcome.title")
let s = String(localized: "welcome.title", comment: "Welcome screen title")
```

`String(localized:)` / `String.LocalizationValue` is **macOS 12.0+** and its doc lives under
`/documentation/swift/` (the Swift overlay), **not** `/foundation/` — see `source-directory.md`. If both
this and the generic deprecation sweep fire on the same line, `audit-swiftui-api-currency` is primary;
emit `cross_ref: api-currency`.

## loc-04 — no String Catalog (`.xcstrings`)

The modern container is the **String Catalog** (`Localizable.xcstrings`), not legacy
`.strings`/`.stringsdict`. Checked in ORIENT: `find . -name '*.xcstrings'`. If an app with user-facing
copy ships none (or only loose `.strings`), flag loc-04 — extraction, plural variations, and translator
review all assume a catalog. ✅ Add a String Catalog target file; literal keys auto-populate it on build.

## loc-05 — no `comment:` for translators

A key without a comment gives the translator no context ("Open" — a verb? a state? a door?). Provide a
`comment:` everywhere a literal becomes a key. The real shape (NetNewsWire, macOS-shipping):
`Text("label.text.unread", comment: "Unread")` —
`https://github.com/Ranchero-Software/NetNewsWire/blob/60295842054529c3450b91af15911cecb1a1cc4f/Widget/WidgetBundle.swift#L27`.

```swift
Text("toolbar.refresh", comment: "Toolbar button that reloads all feeds")
```

A `bundle:` argument (e.g. `Text("context", bundle: .module)`) is the right shape for strings owned by a
**package** target — correct, not a defect.

---

## Sources

- Apple — `Text`, `LocalizedStringKey`, `LocalizedStringResource`, `String.init(localized:)`, String
  Catalogs, fetched via Sosumi (access 2026-06-07):
  `https://developer.apple.com/documentation/swiftui/text`,
  `/documentation/swiftui/localizedstringkey`, `/documentation/foundation/localizedstringresource`,
  `/documentation/swift/string/init(localized:table:bundle:locale:comment:)`,
  `/documentation/xcode/localizing-and-varying-text-with-a-string-catalog`.
- WWDC23 — "Discover String Catalogs" (`/videos/play/wwdc2023/10155`); WWDC21 — "Streamline your
  localized strings" (`/videos/play/wwdc2021/10221`), via Sosumi.
- Real macOS examples surfaced by `swiftui-ctx lookup Text` / `lookup LocalizedStringKey` — permalinks
  inline above (f/textream, NetNewsWire, mac-mouse-fix).
