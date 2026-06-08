# Reference — The Four Load States & Skeletons (async-02 / 03 / 04 / 10)

Every async load renders **four** states: loading · loaded · **empty** · **error**. AI routinely ships only
the happy path (loaded), so three of these are *absence* defects — found by READING the load site, not by a
lint tell. Get the ✅ skeleton shape from `swiftui-ctx`:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup redacted --json` (consensus `(reason)` 94%).

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## The state machine to look for in READ

```swift
enum LoadState<T> { case loading; case loaded(T); case empty; case failed(Error) }
```
A view need not use this exact enum, but every one of the four must reach the screen. The audit question per
load: *what does the user see while it loads, when it returns nothing, and when it throws?*

## async-02 — no loading state (DETECT-only)

An `await` load with no `isLoading` flag, no `ProgressView`, no `.redacted` skeleton — the view shows stale
or blank content until data arrives. **Cannot be grepped** (it is the absence of an indicator). Locate the
load site (`.task`/`Task` tells) and confirm a loading branch renders. ✅ a `ProgressView()` or a redacted
skeleton (async-10) gated on the loading flag.

## async-03 — swallowed error, no error state

`try? await` discards the thrown error; the catch is silent and nothing tells the user. The grep tell
`try\?[[:space:]]*await` locates it.

❌ **WRONG** — error vanishes, UI just stays empty:
```swift
items = (try? await fetch()) ?? []                    // failure looks identical to "no data"
```
✅ **CORRECT** — capture the error and render a failure state:
```swift
do { items = try await fetch() }
catch { loadError = error }                            // rendered: ContentUnavailableView / retry button
```
`ContentUnavailableView` (macOS 14+) is the native empty/error surface — confirm its floor in
`floors-master.md` before prescribing it.

## async-04 — no empty-case view (DETECT-only)

A collection rendered with no branch for "loaded but empty" — the user sees a blank `List`/`Grid` and can't
tell it apart from still-loading or failed. **Cannot be grepped.** In READ, for every `List`/`ForEach`/
`Table`/`LazyVGrid` fed by async data, confirm an empty branch exists (ideally `ContentUnavailableView`).

## async-10 — no `.redacted(.placeholder)` skeleton (DETECT-only)

A polished loading state shows the real layout **redacted** as a skeleton rather than a bare spinner. Its
absence is advisory, not a bug. The grep tell `\.redacted\(` locates *present* skeletons (to confirm they
use `.placeholder` and are driven by the loading flag); the *missing* case is found in READ.

✅ **CORRECT** — consensus shape (`swiftui-ctx lookup redacted`: `(reason)` 94%):
```swift
content.redacted(reason: isLoading ? .placeholder : [])
```

---

## Sources

- Apple — `https://developer.apple.com/documentation/swiftui/view/redacted(reason:)` and
  `/documentation/swiftui/redactionreasons/placeholder` (skeleton redaction), fetched via Sosumi.
  Accessed 2026-06-07.
- Apple — `https://developer.apple.com/documentation/swiftui/contentunavailableview` (the native empty/error
  surface, macOS 14+), via Sosumi. Accessed 2026-06-07.
- swiftui-ctx corpus — `lookup redacted` consensus `(reason)` 94% (macOS floor 11). Accessed 2026-06-07.
