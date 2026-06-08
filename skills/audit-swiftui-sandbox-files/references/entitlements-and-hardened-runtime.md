# Entitlements & Hardened Runtime (sf-04 · sf-09)

The App Sandbox is opt-in **per entitlement**. Enabling the sandbox key without the capability keys you
actually use means even a user-picked URL is unreadable and `URLSession` is blocked — a **silent runtime
failure, not a compile error**, which is why a model that reasons only about Swift never catches it. The
`.entitlements` plist and `Info.plist` are **not `*.swift`** — the shared lint (`*.swift`-only) cannot see
them, so ORIENT reads them by hand.

---

## sf-04 — sandbox on, capability keys missing

```xml
<!-- ❌ WRONG — App Sandbox enabled but no capability keys: panel reads AND URLSession silently fail -->
<dict>
    <key>com.apple.security.app-sandbox</key> <true/>
    <!-- nothing else: even fileImporter's URL can't be read; URLSession is blocked -->
</dict>
```

```xml
<!-- ✅ CORRECT — declare exactly the capabilities you use (MyApp.entitlements), no more -->
<dict>
    <key>com.apple.security.app-sandbox</key>                      <true/>   <!-- required for App Store -->
    <key>com.apple.security.files.user-selected.read-write</key>  <true/>   <!-- or …read-only -->
    <key>com.apple.security.network.client</key>                  <true/>   <!-- ONLY if you make requests -->
    <!-- add only if you persist app-scoped (not document-scoped) bookmarks: -->
    <!-- <key>com.apple.security.files.bookmarks.app-scope</key>  <true/> -->
</dict>
```

**The audit match (sf-04):** the Swift code uses a file/network/bookmark API, but the `.entitlements`
lacks the matching key — or `com.apple.security.app-sandbox` is absent on a Mac App Store target.

| API in the Swift code | Required entitlement key |
|---|---|
| `fileImporter`/`fileExporter`, `NSOpenPanel`/`NSSavePanel`, reading a picked URL | `com.apple.security.files.user-selected.read-write` (or `.read-only` if you never write) |
| `URLSession` / any outbound request | `com.apple.security.network.client` |
| persisting an **app-scoped** `bookmarkData(options: [.withSecurityScope])` | `com.apple.security.files.bookmarks.app-scope` |
| any sandboxed Mac App Store build | `com.apple.security.app-sandbox` |

Declare every key you use and **no more** — each entitlement widens the attack surface and App Review
questions unused ones. Use `.read-only` if you never write the user's files. `fix_mode: flag-only` —
never blind-add an entitlement; the right key depends on the app's distribution model and the panel
wiring, which the audit surfaces but does not decide.

---

## The sandbox ON-vs-OFF fork (one architectural decision)

Sandbox is the default and the App Store gate, but it is a wall, not a suggestion. An app that must read a
private framework, install a session-wide `CGEventTap`, spawn ad-hoc subprocesses, or call
`AXIsProcessTrustedWithOptions` (global accessibility) **cannot be sandboxed at all** — it ships
**Developer ID + notarization only** (no Mac App Store) and omits `com.apple.security.app-sandbox`.

| | Sandbox ON (default, this skill) | Sandbox OFF (notch/overlay/automation app) |
|---|---|---|
| Mac App Store | required & eligible | impossible |
| Arbitrary file reach | user-consent + bookmarks only | free (TCC still gates some dirs) |
| Private frameworks / `CGEventTap` / subprocesses | forbidden | allowed (notarization scans malware, not API policy) |
| Distribution | App Store **or** Developer ID | Developer ID + notarization only |

Both still want **Hardened Runtime ON** for notarization. Pick sandbox-ON unless a capability above forces
OFF; **do not disable the sandbox to "make file code work"** — that is the sf-01 fix done wrong, not a
fix.

---

## sf-09 — Hardened-Runtime `com.apple.security.cs.*` gaps

```text
❌ WRONG — Developer-ID app that loads plug-ins / uses a JIT (V8, embedded scripting) / injects,
           with Hardened Runtime OFF or no com.apple.security.cs.* exceptions
           → notarization fails, or the app crashes at launch with a code-signing error.
```

```xml
<!-- ✅ CORRECT — Hardened Runtime ON; add ONLY the cs.* exceptions you truly need (most apps need NONE).
     A JIT runtime (e.g. a bundled Node) is typically signed SEPARATELY with these before the bundle is re-signed: -->
<dict>
    <key>com.apple.security.cs.allow-jit</key>                       <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
</dict>
```

Developer-ID distribution requires the **Hardened Runtime**, which *tightens* defaults (no unsigned-dylib
loading, no JIT, no `DYLD_*` injection) unless you opt back in with a specific `com.apple.security.cs.*`
exception. Most apps need none. Codesigning / notarization *mechanics* are out of scope (that is the
`publish-macos-app` skill) — but the Hardened-Runtime **entitlements** are in scope for "why does my
notarized build crash at launch." Carry sf-09 as **advisory**: the exact `com.apple.security.cs.*` page
bodies were not verbatim-captured, so write `source: verify against Xcode 26 SDK` — never assert an exact
`cs.*` key string as fact without confirming it against the SDK.

---

## Sources

| URL | Type | Confidence | Key fact |
|---|---|---|---|
| https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.app-sandbox | primary-doc | high (symbol) / medium (body) | App Sandbox entitlement key — *"A Boolean value that indicates whether the app may use access control technology to contain damage…"*. Symbol/page confirmed; body JS-rendered. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.user-selected.read-write | primary-doc | high (symbol) / medium (body) | The user-selected file read-write entitlement that a panel-derived URL needs. Symbol confirmed; body JS-rendered. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client | primary-doc | high (symbol) / medium (body) | The outbound-network entitlement `URLSession` needs under the sandbox. Symbol confirmed; body JS-rendered. Accessed 2026-06-06. |
| https://developer.apple.com/documentation/security/hardened-runtime | primary-doc | high (page) / low (body) | Hardened Runtime tightens defaults (no JIT/unsigned-memory/`DYLD_*`) unless a `com.apple.security.cs.*` exception is declared. Body + exact `cs.*` key bodies JS-rendered, **not verbatim-captured**. Accessed 2026-06-06. |

The `com.apple.security.app-sandbox` floor (macOS 10.7+) is cross-checked against
`${CLAUDE_PLUGIN_ROOT}/references/_shared/floors-master.md`; all pages fetched via Sosumi (access
2026-06-07). The Apple doc bodies render via JavaScript and the exact `com.apple.security.cs.*` page
bodies were not scraped — where an entitlement string or a `cs.*` key matters, **verify against Xcode 26
SDK**.
