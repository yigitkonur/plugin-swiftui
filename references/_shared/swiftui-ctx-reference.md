# swiftui-ctx — the practice layer (full capability reference)

`swiftui-ctx` is a bundled CLI over a catalog of **real SwiftUI usage from 1,857 shipping macOS apps**
(SwiftSyntax-parsed against the macOS 26.5 SDK, quality-ranked, every example GitHub-permalinked to a commit).
It answers **"how do shipping Mac apps actually write this?"** — the PRACTICE half — and pairs with **Sosumi**
(Apple docs = the SPEC half); every result carries a `doc:` Sosumi link. Sosumi proves the API exists / its
floor / its signature; swiftui-ctx proves the real idiom, the consensus shape, whether it's
deprecated-in-the-wild, and hands a canonical permalinked example.

**Invoke:** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/swiftui-ctx <command> [flags]` (builds the CLI on first run;
self-locates the bundled `catalog/`). Names normalize — `@State`, `.searchable`, `frame(width:height:)` all
resolve. **Global flags (every command):** `--json` (stable envelope) · `--limit N` (default 6) ·
`--platform macos|any` (default macos; `any` adds iOS/library) · `--offline` (catalog only, no live fetch) ·
`--catalog <dir>`.

## The 16 commands (full surface)
| Command | Use it to… | Key result fields / flags |
|---|---|---|
| `lookup <api>` | **START HERE** — the context pack for one API | `consensus:[{shape,pct}]` (% over ALL uses), `recommended:{id,repo,permalink,src,stars,author_authority,min_macos,score}`, `diverse[]`, `co_occurs_with[]`, `recipes[]`, `introduced_macos`, `deprecated`, `replacement?`, `doc`, `low_corpus`. A protocol/pattern (e.g. `NSViewRepresentable`) soft-redirects to its `recipe`. |
| `examples <api>` | shape-/repo-specific real call sites | `--shape "(text:placement:)"` · `--repo owner/name` · `--page N` · `--limit N`. A curated ≤25/API ranked sample (read `note`; for frequency use `lookup` consensus). |
| `file <id\|permalink>` | the REAL source, live from GitHub | `--smart` (tightest useful span, default) · `--decl` (whole enclosing `var body`/func) · `--chain` (just the modifier chain) · `--full` (whole file) · `--offline` (cached one-line `src`). Returns `{permalink, mode, range, code}`. |
| `deprecated [<api>]` | the anti-pattern engine | no arg → every deprecated API still in production use (the **audit entry point**); `<api>` → `{deprecated, replacement, migrate_to, note, doc}`. |
| `recipe <name>` / `recipes` | whole multi-API production patterns | 12 recipes: menubar-app · master-detail · settings-form · settings-screen · observable-model · window-scene · charts-bar · nsview-bridge · command-palette · searchable-list · draggable-reorder · cached-async-image. `recipe` → `{template, apis[], examples[]}`. |
| `repo <owner/name>` | a corpus repo's production fingerprint | `{stars, platform, author_authority, min_macos_inferred, custom_components, counts:{dim→n}, deprecated_apis_used[]}` — a model of what a clean audit looks like. |
| `search <query>` | intent/keyword → APIs + recipes | alias-aware (`"drag drop"` → draggable/dropDestination + a recipe). |
| `stats` | corpus overview + **the baseline** | `{repos, sdk, dimension_sizes, custom_components, modern_stack:{…adoption %…}}` (from `insights.json`). |
| `doctor` | health check before relying on the CLI | confirms the catalog loads + prints `{version, catalog_dir, repos, sdk}`; exit `5` if no catalog. Run first if a query unexpectedly errors. |
| `bridges [<filter>]` | real AppKit/UIKit bridges | `{count, repos, by_kind, examples:[{name,repo,conforms,permalink}]}`; `<filter>` = a conformance kind or name substring. |
| `settings` | production Settings screens + Form vocab | `{count, repos, form_vocab:[{name,count}], screens:[{name,repo,permalink}]}`. |
| `conformances [<protocol>]` | custom protocol conformers | no arg → all protocols + repo_count; `<protocol>` (Layout, ButtonStyle, Shape…) → `{repo_count, top_repos, examples}` (did-you-mean on miss). |
| `rankings [<dimension>]` | top corpus repos by a ranking | `by_total_unique_apis · by_modifier_breadth · by_custom_components · most_modern_stack` → `[{repo,stars,total_unique_apis,custom_components,min_macos}]`. |
| `insights [<section>]` | corpus-wide signals | `modern-stack · deprecated · cooccurrence · external · components · categories` (no arg → summary) — the benchmark + anti-pattern data behind the nativeness score. |
| `valueBuilders [<filter>]` | browse the value vocabulary | top Font/Color/Animation/gradient builders by real usage → `{total, matched, builders:[{name,total_uses,repo_count,low_corpus}]}`; `<filter>` = a name fragment (`gradient`, `ease`). Per-symbol detail is `lookup`. |

## Per-domain shard commands (which to reach for)
`bridges`/`settings`/`conformances`/`rankings`/`insights`/`valueBuilders` are first-class commands over the
catalog shards (stable envelope + `next_actions`, no raw `jq` needed):
- `bridges [<kind|name>]` — real AppKit/UIKit `NSViewRepresentable`/`NSViewControllerRepresentable` bridges (4,698 across 957 repos) + permalinks → `appkit-interop`, `appkit-overuse`.
- `settings` — real Settings screens + the Form vocab they use (Toggle/Picker/Section counts) → `controls-forms`, `scenes-windows`.
- `conformances [<protocol>]` — custom `ButtonStyle`/`Layout`/`Shape`/`LabelStyle`/`ViewModifier` conformers + permalinks → `appearance-color`, `layout-and-tables`, `drawing-canvas`, `animation-motion`.
- `rankings [<dimension>]` + `insights` — `most_modern_stack`, API breadth, `modern_stack_adoption_pct`, `deprecated_api_usage`, `co_occurrence` → `macos-nativeness` (the benchmark).
- `valueBuilders [<filter>]` — the real Font/Color/Animation/gradient vocabulary ranked by usage (filter by name fragment: `gradient`, `ease`, `bouncy`) → `appearance-color`, `animation-motion`, `typography-text`. Every shard also remains under `catalog/` for direct `jq` reads.

## Capability → audit-move map
- **VERIFY it exists / its floor** → `lookup <api>` (`introduced_macos`; an exit-3 = no real app uses it ⇒ corroborates a hallucination) + Sosumi `doc:`.
- **VERIFY deprecated-in-practice** → `deprecated <api>` (or no-arg corpus list / `insights.deprecated_api_usage`).
- **FIX — the canonical ✅** → `lookup` `consensus` shape + `file <recommended.id> --smart` permalink (+ `recipe <name>` template for a multi-API pattern).
- **CHOOSE the shape** → `examples <api> --shape "(…)"` — real call sites of one exact overload.
- **COMPLETENESS** → `lookup` `co_occurs_with` — flag a missing companion API (e.g. `glassEffect` without `GlassEffectContainer`; `MenuBarExtra` without `menuBarExtraStyle`).
- **BENCHMARK (nativeness / currency score)** → `stats.modern_stack` + `rankings.most_modern_stack` — "real Mac apps adopt X at N%; this app is at M%."
- **BRIDGE / SETTINGS / CUSTOM-STYLE / VALUE / BENCHMARK evidence** → the `bridges` / `settings` / `conformances <p>` / `valueBuilders <f>` / `rankings` / `insights` commands.

## Envelope + exit codes (agent-drivable)
`{ "ok", "schema_version":"v1", "result", "next_actions":[{cmd,why}], "error" }`. Each result ends with
`next_actions` — literal follow-ups (almost always `file <id> --smart` after a `lookup`). Exit: `0` ok · `2`
usage · `3` not-found (`error.suggestion` = did-you-mean) · `4` network (retry once, then `--offline`) · `5`
no catalog (**STOP, tell the user, do NOT fabricate**).

## VERIFY + FIX (the loop)
- **VERIFY (workflow step 5):** for any <100%-confidence finding, run `lookup <api>` (+ `deprecated <api>`),
  cross-check `introduced_macos` against `_shared/floors-master.md` and the Sosumi `doc:`. Use `examples
  --shape` to confirm a specific overload, `co_occurs_with` for a missing companion.
- **FIX (workflow step 7):** the ✅ "Correct" is the **consensus shape + a `file <id> --smart` permalink** (a
  real macOS example), not opinion. Put the shape in `## Correct`, the permalink + Sosumi `doc:` in `##
  Source`. Auto-fix stays gated by `_shared/fix-safety-protocol.md`.
- **Three-source rule:** the shared lint **LOCATES** → the agent **READS** → **Sosumi (spec) + swiftui-ctx
  (practice) + `floors-master.md`** VERIFY → swiftui-ctx hands the canonical **FIX**.

## Caveats
macOS-first corpus (`--platform any` for iOS/library). `consensus` % is over all uses; `examples` is a curated
≤25/API sample (read the %, not the count). `low_corpus:true` (<10 repos) = thin evidence, lean on Sosumi.
The ranking is a heuristic; `recommended` ≈ "how a high-quality, currently-maintained Mac app writes it."

## When the CLI can't run — degrade, never block
The CLI builds on first use and needs a Swift 6 toolchain. If it can't build or run (no toolchain → the
wrapper exits 5 with a notice; a read-only install; exit 5 no-catalog), **the audit still proceeds** — fall
back to **Sosumi** (the spec) + `_shared/floors-master.md` (the reconciled floors) + the shared lint (the
locator). NEVER skip or block a finding just because `swiftui-ctx` is unavailable; you lose the real-corpus
consensus/permalink, not the audit. Note it in the finding's `## Source` ("swiftui-ctx unavailable — verified
via Sosumi + floors-master").

## Sources
- The bundled `swiftui-ctx` CLI + `catalog/` (1,857 macOS repos · SwiftSyntax · macOS 26.5 SDK) — `--help` / `stats`.
- Sosumi (https://sosumi.ai) — the paired spec layer; every `lookup`/`deprecated` result links to it.
