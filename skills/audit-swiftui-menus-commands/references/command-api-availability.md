# Reference — Command-API Availability (menu-10)

This skill owns the **command-API floors in depth**; the blanket "is every floored API gated" sweep
belongs to `audit-swiftui-availability-gating` (the net). The cross-cutting gating *rule* (the macOS
arm, the `*` wildcard, the wrong-arm failure, reading multi-platform strings) is NOT restated here — it
lives in `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`, and floor *values* are the
reconciled truth in `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. This file adds which
command symbols are floored above macOS 11 and the gating application.

**As of:** 2026-06-07 · macOS 26 (Tahoe).

---

## The floors that drive menu-10

Most command APIs are `macOS 11.0+` and need no gate in any realistic Mac target. A few are floored
higher; gate them only when the project's `MACOSX_DEPLOYMENT_TARGET` (or `Package.swift` `platforms:`,
read in ORIENT) is **below** the floor.

| Symbol | Floor (per floors-master) | Gate needed when target < |
|---|---|---|
| `.commands { }`, `CommandMenu`, `CommandGroup`, `CommandGroupPlacement` (most cases) | macOS 11.0+ | macOS 11 |
| `keyboardShortcut(_:modifiers:)` | macOS 11.0+ | macOS 11 |
| `@FocusedValue` / `@FocusedBinding` / `FocusedValueKey` / `focusedValue(_:_:)` | macOS 11.0+ | macOS 11 |
| `SidebarCommands()` / `ToolbarCommands()` / `TextEditingCommands()` / `TextFormattingCommands()` / `EmptyCommands()` | macOS 11.0+ | macOS 11 |
| `@Entry` macro (on `FocusedValues`) | macOS 10.15+ (back-deploys; **Xcode 15+/Swift 5.9+ to expand** _(toolchain requirement — verify-SDK)_) | macOS 10.15 (runtime) — but the toolchain caveat is build-env, not a runtime gate |
| `ImportFromDevicesCommands()` | macOS 12.0+ | **macOS 12** |
| `CommandGroupPlacement.singleWindowList` | macOS 13.0+ | **macOS 13** |
| `commandsRemoved()` / `commandsReplaced(content:)` (scene modifiers) | macOS 13.0+ | **macOS 13** |
| `InspectorCommands()` | macOS 14.0+ | **macOS 14** |

The practically-floored ones (the menu-10 grep tell) are **`.singleWindowList`**, **`commandsRemoved`**,
**`commandsReplaced`** (macOS 13), **`InspectorCommands()`** (macOS 14), and **`ImportFromDevicesCommands()`**
(macOS 12). The macOS-11 group is gated only on the rare pre-11 target.

---

## The gating application

```swift
// ❌ ungated; MACOSX_DEPLOYMENT_TARGET = 12.0 → build error on macOS 12/13
Window("Console", id: "console") { ConsoleView() }
    .commandsReplaced { ConsoleCommands() }       // macOS 13.0+

// ✅ gate on the macOS arm (the rule itself is in _shared/macos-arm-gating.md)
if #available(macOS 13.0, *) {
    Window("Console", id: "console") { ConsoleView() }
        .commandsReplaced { ConsoleCommands() }
}
```

`commandsRemoved()` suppresses a scene's menu commands; `commandsReplaced(content:)` substitutes a new
`Commands` set — both are **scene** modifiers (not view modifiers). VERIFY any floor you're unsure of
against `swiftui-ctx lookup <api>` (`introduced_macos`) cross-checked with the Sosumi `doc:` floor and
`floors-master.md`. A wrong-arm gate (`#available(iOS …)` guarding a command symbol in a Mac target) is
the wrong-arm failure in `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md` — flag it, gate
on `macOS`. (SEAM: a *missed* gate this skill doesn't catch is `audit-swiftui-availability-gating`'s
blanket net — emit `cross_ref: audit-swiftui-availability-gating` on a gating finding.)

---

## Sources

- Apple — fetched via Sosumi (access 2026-06-07): `/documentation/swiftui/scene/commandsremoved()`
  (*"Removes all commands defined by the modified scene."* `macOS 13.0+`),
  `/documentation/swiftui/scene/commandsreplaced(content:)` (`macOS 13.0+`),
  `/documentation/swiftui/importfromdevicescommands` (`macOS 12.0+`),
  `/documentation/swiftui/inspectorcommands` (`macOS 14.0+`),
  `/documentation/swiftui/commandgroupplacement` (`.singleWindowList` `macOS 13.0+`). Paths + protocol
  in `source-directory.md` + `${CLAUDE_PLUGIN_ROOT}/references/_shared/sosumi-reference.md`.
- Floor values: `${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`. Gating rule:
  `${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`.
- Practice (floor cross-check): `swiftui-ctx lookup <api> --json` `introduced_macos`
  (`${CLAUDE_PLUGIN_ROOT}/references/_shared/swiftui-ctx-reference.md`), accessed 2026-06-07.
