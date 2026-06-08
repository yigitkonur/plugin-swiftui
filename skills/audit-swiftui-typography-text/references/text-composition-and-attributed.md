# Reference — Text Composition, AttributedString & Invented Type APIs (txt-01 · txt-05 · txt-09)

How styled text is correctly composed on macOS 26, the deprecation of the `Text` `+` operator, the right
way to build an `AttributedString`, and the invented type APIs AI hallucinates. Floor *values* live in
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; the invented-name canon is
`${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` — read, never restate.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## txt-01 — `Text + Text` concatenation (deprecated macOS 26.0)

The `Text` `+` operator (`Text("a") + Text("b")`) is **deprecated at macOS 26.0** (per floors-master:
"closes at 26.0, one release before the 26.5 set"). It still resolves but is non-native and warns on a
26.0 floor. The currency *flag* is owned by `audit-swiftui-api-currency`; this skill owns the **positive
craft** → emit `cross_ref: api-currency`.

### ❌ Wrong
```swift
Text("Total: ").bold() + Text("\(amount)").foregroundColor(.green)
```

### ✅ Correct — one `Text` from an `AttributedString` (`AttributeContainer`)
Get the canonical shape from the corpus rather than trusting memory:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup AttributedString --json`. (When the corpus has no
usage it exits 3 — then fall back to interpolation below and confirm via Sosumi.)
```swift
var label = AttributedString("Total: ")
label.font = .body.bold()
var value = AttributedString(amount.formatted())
value.foregroundColor = .green
Text(label + value)            // AttributedString + AttributedString is fine; Text + Text is not
```

### ✅ Correct — string interpolation into a single `Text`
```swift
Text("Total: **\(amount.formatted())**")   // markdown-styled, one Text, no operator
```

## txt-05 — malformed `AttributedString`

`AttributedString` (Foundation, macOS 12+) is correct only when attributes are set through the typed
properties or an `AttributeContainer`, and styled spans are merged with `+` on **`AttributedString`**
values (not `Text`). Defects: building it by `String` concatenation then hoping `Text` styles it; setting
attributes on a `let`; or reaching for a hallucinated init.

### ❌ Wrong
```swift
let s = "Hello " + name                 // plain String — no attributes survive
Text(AttributedString(s)).bold()        // .bold() restyles the WHOLE run, defeating the point
```

### ✅ Correct — `AttributeContainer` for a styled span
```swift
var greeting = AttributedString("Hello ")
var who = AttributedString(name)
who.mergeAttributes(AttributeContainer().font(.body.bold()).foregroundColor(.accentColor))
Text(greeting + who)
```
VERIFY any uncertain `AttributedString` initializer/attribute against Sosumi
(`documentation/foundation/attributedstring`) per `references/source-directory.md`.

## txt-09 — invented type APIs (hard-fail)

These names do **not exist** in SwiftUI on macOS — a `swiftui-ctx lookup` returns **exit 3** with a
did-you-mean `suggestion`, corroborating the hallucination. Map each to its real spelling:

| ❌ Invented | ✅ Real |
|---|---|
| `.fontSize(14)` | `.font(.system(size: 14))` — better: a text style (txt-03) |
| `.font(size: 14)` | `.font(.system(size: 14))` (the `.system(...)` is not optional) |
| `.textStyle(.headline)` | `.font(.headline)` |
| `Text(styled: ...)` | `Text(someAttributedString)` |
| `.attributedText(...)` / `NSAttributedText` | a SwiftUI `AttributedString` passed to `Text` |

Confirm against `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md` before asserting a
name is invented; if the symbol is genuinely unknown to both swiftui-ctx and Sosumi, flag
`source: verify against Xcode 26 SDK`.

---

## Sources

- `Text` operator deprecation + `AttributedString` overloads: Apple SwiftUI `Text` docs via
  `https://sosumi.ai/documentation/swiftui/text` (access 2026-06-07).
- `AttributedString` / `AttributeContainer`: `https://sosumi.ai/documentation/foundation/attributedstring`
  and `.../attributecontainer` (access 2026-06-07).
- WWDC21 session 10109 "What's new in Foundation" (AttributedString introduction);
  WWDC25 "What's new in SwiftUI" (Text composition guidance).
