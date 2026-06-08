# Playbook — worked transcripts per scenario

Each block is the exact command sequence an agent should run. `$BIN` = `swiftui-ctx`. Always finish a
write task with `file --smart` on the `recommended` example before emitting code.

## Writing a known call (e.g. a search field)
```
$BIN lookup searchable                  # consensus shapes + recommended example + co_occurs_with
$BIN file <recommended.id> --smart      # the real enclosing view, compilable
```
Read `consensus` to pick the shape (`(text:)` 24% vs `(text:placement:prompt:)` 27%), then write it the dominant way.

## Choosing an overload / argument shape
```
$BIN lookup frame                       # consensus: (width, height) 31% · (maxWidth, alignment) 12% …
$BIN examples frame --shape "(maxWidth, alignment)"   # real call sites of that exact shape
```
Note: `examples` shows a curated ≤25/API sample; the consensus % is over *all* uses (the tool says so in its output).

## Is an API current or deprecated?
```
$BIN deprecated foregroundColor         # ⚠️ DEPRECATED → use .foregroundStyle  (+ next_action)
$BIN lookup foregroundStyle             # real usage of the modern replacement
```
`$BIN deprecated` (no arg) lists every deprecated API still in production use, with its replacement — the audit entry point.

**Floor gaps:** replacements can have a higher macOS floor than the deprecated API — always check `min_macos` in the `lookup` result before swapping. Example: `tabItem(_:)` is macOS 10.15+ Deprecated, but its replacement `Tab` is macOS 15.0+. Using `Tab` on a macOS 13–14 deployment target is a compile error; use `#available(macOS 15, *)` or keep `tabItem` if you must support macOS 13–14.

## Building a known pattern (recipes)
```
$BIN recipes                            # list patterns
$BIN recipe menubar-app                 # template skeleton + real examples (each with a file/permalink next_action)
$BIN file <example> --smart
```
Recipes: `menubar-app · master-detail · settings-screen · settings-form · observable-model · window-scene ·
charts-bar · nsview-bridge · searchable-list · command-palette · draggable-reorder · cached-async-image`.

## Planning a feature from intent (you don't know the API names)
```
$BIN search "command palette"           # intent → APIs (sheet/searchable/keyboardShortcut) + recipe
$BIN lookup keyboardShortcut            # drill into each candidate
```
`search` understands design vocabulary ("sidebar", "menu bar", "drag drop", "reorder", "async image", "settings").

## Reviewing / auditing existing SwiftUI
```
$BIN deprecated                         # what's deprecated in the wild → flag any the code uses
$BIN lookup <api-in-the-code>           # compare the code's call to `consensus`; cite the permalink
$BIN repo <owner/name>                  # if the code is from a corpus repo: its fingerprint + modernity
```

## Debugging a SwiftUI symptom
```
# "@State isn't updating the view"
$BIN lookup State                       # confirm the wrapper + see co_occurs_with
$BIN recipe observable-model            # the correct ownership pattern (@Observable + @State var model)
$BIN file <example> --smart             # a working reference to diff your code against
```

## NSView/NSViewController bridging (where LLMs fail most)
```
$BIN recipe nsview-bridge               # template + real bridges (use the file <permalink> next_action)
$BIN file <permalink> --full            # bridges are best read whole: Coordinator + makeNSView + updateNSView
```

## Reading the `file` modes
- `--smart` (default): tightest useful, anchor-guaranteed span (enclosing `var body`/func if it fits, else the statement, else an anchored window). Start here.
- `--full`: the whole file — for Scene-level patterns (App struct) and NSView bridges.
- `--chain`: just the modifier chain — for a dense `.a().b().c()` call.
- `--decl`: the full enclosing declaration even if large.
