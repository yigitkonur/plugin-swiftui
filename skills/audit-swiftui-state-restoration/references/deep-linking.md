# Reference — Deep linking: URL schemes & activities (sr-09)

A declared deep-link entry point with no handler is dead: the OS launches/activates the app but nothing
consumes the URL/activity. Get the ✅ shape from
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup onOpenURL --json` (the `recommended` permalink is a
real `App` body) rather than a static snippet.

## sr-09 — declared scheme/activity with no handler (warning, flag-only)

ORIENT reads any declared `CFBundleURLSchemes` (custom URL scheme) or `NSUserActivityTypes`/
`CFBundleDocumentTypes` from `Info.plist`/`project.pbxproj`. If one is declared but no
`onOpenURL(perform:)` (macOS 11) / `onContinueUserActivity(_:perform:)` (macOS 11) handler exists in the
scene/view tree, the entry point is non-functional. Conversely, a handler with no declared scheme will
never fire — both halves must exist.

```swift
// ✅ consume the declared scheme at the scene root
WindowGroup {
    ContentView()
        .onOpenURL { url in router.handle(url) }   // myapp://note/42
}
```

`handlesExternalEvents(matching:)` (macOS 11; Mac, iOS, visionOS — **no tvOS/watchOS**) routes an incoming URL to
a *specific* scene; flag a `handlesExternalEvents` matcher with no `onOpenURL` to actually consume the URL.
Window/scene activation semantics themselves are `audit-swiftui-scenes-windows` — emit
`cross_ref: audit-swiftui-scenes-windows` and stay on the *handler-presence* question here.

> Detection limit: the scheme is declared in `Info.plist`, not `.swift`; the grep tell catches a literal
> `CFBundleURLSchemes` string (e.g. in a checked-in plist) and the handler symbols. Confirm the plist
> declaration in ORIENT before reporting a missing handler.

## Sources

- Apple — `onOpenURL(perform:)`, macOS 11.0+:
  `https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:)` (via Sosumi, accessed 2026-06-07).
- Apple — `handlesExternalEvents(matching:)`, macOS 11.0+ (Mac, iOS, visionOS):
  `https://developer.apple.com/documentation/swiftui/scene/handlesexternalevents(matching:)` (via Sosumi, 2026-06-07).
- Apple — `onContinueUserActivity(_:perform:)`, macOS 11.0+:
  `https://developer.apple.com/documentation/swiftui/view/oncontinueuseractivity(_:perform:)` (via Sosumi, 2026-06-07).
- swiftui-ctx practice corpus — `lookup onOpenURL` (introduced_macos 11.0; `recommended`:
  `https://github.com/f/textream/blob/6c34baaef9fea5de30bce619b4ed34cd675d5617/Textream/Textream/TextreamApp.swift#L122`),
  run 2026-06-07.
