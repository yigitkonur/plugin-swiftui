# Shared Reference — macOS-Arm Gating Discipline

The rule for writing and auditing availability gates in this **macOS-only** toolkit. Every skill that
emits a gate fix points here; do not restate the rule locally. Floor values come from
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`.

**As of:** 2026-06-07.

---

## 1. The rule

Gate a floored API on the **macOS arm**:

```swift
if #available(macOS 26, *) {
    someView.glassEffect(.regular, in: .rect(cornerRadius: 12))
} else {
    someView.background(.ultraThinMaterial)   // pre-26 fallback
}
```

- The platform name is **`macOS`**, and the floor is the **macOS** floor from `floors-master.md`.
- The trailing `*` wildcard is **required** — it covers every other platform the code may compile
  against. Omitting it is a compile error.
- For a property/parameter that needs the gate, use `@available(macOS NN, *)` on the declaration, or
  `if #available(macOS NN, *)` at the use site.

---

## 2. The wrong-arm failure mode (the headline defect)

Gating a macOS-only or macOS-floored API on the **iOS arm** is the central gating bug:

```swift
// WRONG — the macOS path is gated on iOS; on a Mac this branch's availability is wrong.
if #available(iOS 26, *) {
    view.glassEffect(.regular.interactive(), in: .capsule)
}
```

`Glass.interactive(_:)` IS available on macOS 26.0+ (pointer-driven) — the symbol is fine; the **arm
is wrong**. The fix is to gate on `#available(macOS 26, *)`. A wrong-arm gate either fails to compile
on macOS or silently never runs. Flag it as a gating finding, not a hallucination.

---

## 3. Reading a multi-platform availability string

Apple renders strings like `macOS 14.0+ · iOS 17.0+ · watchOS 10.0+`. In this toolkit:

- **Read only the macOS arm.** If macOS is present, that floor is the gate value.
- **If macOS is ABSENT from the array**, the symbol has no Mac arm — it is **platform-wrong**, not
  under-gated. Examples: `ToolbarItemPlacement.topBarLeading`, `.glassBackgroundEffect()`,
  `WheelPickerStyle`, `WindowStyle.volumetric`, the visionOS `Preview` overload. **Never** wrap a
  `macOS ABSENT` symbol in `#available(macOS …)` — replace it with the Mac equivalent (see
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`).
- Beware the **iOS floor being higher than macOS** (e.g. `navigationSubtitle(_:)` is macOS 11.0+ but
  iOS 26.0+) — gating on the iOS number over-gates the Mac.

---

## 4. Audit checklist

1. Every floored API (per `floors-master.md`) has a gate, or the project's deployment target is at or
   above the floor.
2. The gate names **`macOS`**, not `iOS`/`*`-only.
3. The gate's floor matches `floors-master.md` (watch the DocC type-property quirk — verify
   type-property floors via Sosumi).
4. No `macOS ABSENT` symbol is wrapped in a macOS gate; it is replaced, not gated.
5. The `else` fallback (where one is needed) uses a real pre-floor API.

---

## Sources

- Apple availability strings per `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md` (access
  date 2026-06-07, fetched via Sosumi).
- The Swift `#available` / `@available` language feature (`swift.org` / `developer.apple.com`).
