# Reference — Hallucinated symbols & restoration gating (sr-01/10/11)

## sr-01 — UIKit / invented restoration symbols (hard-fail, flag-only)

SwiftUI on macOS has **no** explicit per-view restoration-identifier system. The symbols below are UIKit
(`UIViewController`/`NSResponder`) restoration or pure inventions; on a SwiftUI Mac target they do not
exist. A `lookup` **exit 3** corroborates the hallucination.

| ❌ symbol | Why wrong | ✅ replacement |
|---|---|---|
| `.restorationIdentifier(_:)` | UIKit `UIView`/`UIViewController`, not SwiftUI | `@SceneStorage` (per-window) / `@AppStorage` (app-wide) |
| `@StateRestoration` | invented property wrapper | `@SceneStorage` |
| `UIStateRestoring` / `restorationClass` | UIKit protocols | SwiftUI scene/app storage |
| `encodeRestorableState` / `decodeRestorableState` | `NSResponder`/`UIViewController` AppKit/UIKit hooks | persist via `@SceneStorage` + `NavigationPath.codable` |
| `@FocusedDocument` | **not a real Apple symbol** (see `${CLAUDE_PLUGIN_ROOT}/references/_shared/hallucination-blacklist.md`) | a custom `FocusedValues` key (`@Entry` on `FocusedValues` + `@FocusedValue`) |

## sr-10 — restorationBehavior ungated under a <macOS 15 floor (warning, flag-only)

`restorationBehavior(_:)` is a **macOS 15.0+** scene modifier (`.automatic` / `.disabled`) controlling
whether the system restores a scene. Under a deployment target below macOS 15 an ungated call fails to
build. This is the one structural tell expressed in `lint/ast-grep/sr-10-restorationbehavior-ungated.yml`
(the call NOT inside an `#available(macOS 15, *)` gate — grep cannot see gate scope). Fires only when the
floor read in ORIENT is below macOS 15.

```swift
// ✅ gate when the floor is < macOS 15
WindowGroup { ContentView() }
    .modify { scene in
        if #available(macOS 15, *) { scene.restorationBehavior(.disabled) } else { scene }
    }
// or raise MACOSX_DEPLOYMENT_TARGET to 15.0 and call it directly.
```

The macOS-arm gating rule (and the wrong-arm `#available(iOS …)` failure) is shared:
`${CLAUDE_PLUGIN_ROOT}/references/_shared/macos-arm-gating.md`.

## sr-11 — focusedSceneValue: two floors (advisory, flag-only)

`focusedSceneValue` has **two overloads with different floors** — this is the FLOOR-SENSITIVE claim, never
assert without VERIFY:

- **key-path overload** `focusedSceneValue(_ keyPath:_ value:)` — **macOS 12.0+**.
- **object overload** `focusedSceneValue(_ value:)` (the `@Observable`/typed form) — **macOS 14.0+**.

READ which overload the code uses, then gate against *its* floor. Until confirmed via swiftui-ctx
`introduced_macos` + Sosumi, carry as `source: verify against Xcode 26 SDK`. The *command routing* that
consumes a focused scene value is `audit-swiftui-menus-commands` — emit
`cross_ref: audit-swiftui-menus-commands`; this skill flags only the availability floor.

## Sources

- Apple — `restorationBehavior(_:)`, macOS 15.0+:
  `https://developer.apple.com/documentation/swiftui/scene/restorationbehavior(_:)` (via Sosumi, accessed 2026-06-07).
- Apple — `focusedSceneValue(_:_:)` (key-path, macOS 12.0+) and `focusedSceneValue(_:)` (object, macOS 14.0+):
  `https://developer.apple.com/documentation/swiftui/view/focusedscenevalue(_:_:)` (via Sosumi, 2026-06-07).
- Apple — UIKit state restoration (`restorationIdentifier`, `UIStateRestoring`) is UIKit-only, confirming
  sr-01: `https://developer.apple.com/documentation/uikit/restoring-your-app-s-state` (via Sosumi, 2026-06-07).
