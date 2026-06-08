# Reference — Networking, Search Debounce, Remote Images & Refresh (async-05 / 06 / 07 / 08)

The outward-facing async surfaces. Get every ✅ shape from `swiftui-ctx` (not memory):
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx lookup AsyncImage --json`,
`… lookup refreshable --json`, and the cache recipe `… recipe cached-async-image --json`.

**As of:** 2026-06-07 · macOS 26 (Tahoe) · Xcode 26 SDK.

---

## async-05 — raw `URLSession` in the view layer

Networking driven from inside a view, with the decode run on the main actor and the result written without
a checkable isolation hop. The grep tell `URLSession\.` locates it.

❌ **WRONG** — decode blocks the main actor; write dodges the checker:
```swift
.task {
    let (data, _) = try await URLSession.shared.data(from: url)
    DispatchQueue.main.async { self.items = decode(data) }   // un-checkable + on-main decode
}
```
✅ **CORRECT** — keep heavy decode OFF the main actor, write with a checkable annotation. The Swift-6
`@concurrent`/`nonisolated`/`Sendable` correctness is **`concurrency-safety`'s verdict** — emit
`cross_ref: concurrency-safety`; this skill flags that the decode/isolation is wrong, not the exact Swift-6
spelling (see `${CLAUDE_PLUGIN_ROOT}/skills/build-macos-swiftui/references/concurrency.md` mistakes 1, 3, 6):
```swift
.task {
    let (data, _) = try await URLSession.shared.data(from: url)
    let parsed = try await decodeOffMain(data)                // off the main actor
    items = parsed                                            // .task closure is already @MainActor
}
```

## async-06 — `.searchable` query with no debounce

A `.searchable` text binding whose `onChange` fires a network request on **every keystroke** — N requests
for an N-character query, racing each other. The grep tell `\.searchable\(` locates the search field.

❌ **WRONG** — request per keystroke:
```swift
.searchable(text: $query)
.onChange(of: query) { _, q in Task { results = await search(q) } }
```
✅ **CORRECT** — debounce before firing (a `Task` with a sleep that cancellation kills, or an
`AsyncStream`/Combine debounce). The cancel-prior-task + sleep form rides the same generation guard as
async-09:
```swift
.onChange(of: query) { _, q in
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(300))        // debounce — macOS 13+ (use nanoseconds: 300_000_000 on macOS 12)
        guard !Task.isCancelled else { return }
        results = await search(q)
    }
}
```

## async-07 — `AsyncImage(url:)` failure phase ignored / no cache

The url-only `AsyncImage(url:)` shape (90% of corpus usage per `swiftui-ctx lookup AsyncImage`) shows a
blank box on failure and **re-downloads on every cell appearance** — `AsyncImage` has no cache. Fine for a
one-off avatar; in a `List`/`ForEach`/grid it needs a failure phase and a cache. The ast-grep rule
`async-07-asyncimage-no-phase` locates the url-only shape; READ to confirm it sits in a reused cell.

❌ **WRONG** — blank on error, re-downloads every scroll:
```swift
AsyncImage(url: item.thumbnail)                       // in a List row
```
✅ **CORRECT** — handle the phase, and add a cache for lists. The consensus content+placeholder shape and
the cache pattern come from `swiftui-ctx recipe cached-async-image` (a custom `@Observable` loader or a
library — `AsyncImage` is built-in with no cache):
```swift
AsyncImage(url: item.thumbnail) { phase in
    switch phase {
    case .empty:   ProgressView()
    case .success(let image): image.resizable().scaledToFit()
    case .failure: Image(systemName: "photo")          // not a blank box
    @unknown default: EmptyView()
    }
}
```

## async-08 — primary async list with no `.refreshable` (DETECT-only)

A primary data list with no pull-to-refresh — the user has no way to re-fetch. **Cannot be grepped** (it is
the absence of `.refreshable`; the grep tell `\.refreshable\(` confirms *present* ones reuse the loader).
In READ, for each primary async `List`, confirm a `.refreshable { await reload() }` whose action re-runs the
same loader the `.task` uses. Consensus shape `swiftui-ctx lookup refreshable`: `{ }` 93%.

---

## Sources

- Apple — `https://developer.apple.com/documentation/swiftui/asyncimage` and
  `/documentation/swiftui/asyncimagephase` (the phase-handling initializer; no built-in cache), fetched via
  Sosumi. Accessed 2026-06-07.
- Apple — `https://developer.apple.com/documentation/swiftui/view/refreshable(action:)` and
  `/documentation/swiftui/view/searchable(text:placement:prompt:)`, via Sosumi. Accessed 2026-06-07.
- Apple — `https://developer.apple.com/documentation/foundation/urlsession/data(from:delegate:)`
  (async data fetch), via Sosumi. Accessed 2026-06-07.
- swiftui-ctx corpus — `lookup AsyncImage` consensus `(url)` 90% (floor 12); `lookup refreshable` `{ }` 93%
  (floor 12); `recipe cached-async-image` ("AsyncImage is built-in (no cache); for lists/grids real apps add
  a cache"), example `https://github.com/fayazara/bucketdrop/blob/92816bedcd2267022ede0c797d12e593f0997e4b/BucketDrop/SettingsView.swift#L85`.
  Accessed 2026-06-07.
