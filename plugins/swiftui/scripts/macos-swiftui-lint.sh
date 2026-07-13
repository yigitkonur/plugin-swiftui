#!/usr/bin/env bash
# macos-swiftui-lint.sh — grep tells for macOS SwiftUI defects.
# Usage: macos-swiftui-lint.sh [file-or-dir ...]   (default: current dir)
# Exit: 2 if any [hard-fail] rule matched, else 0. Warnings never fail the run.
# Full rule list + replacements: skills/build-macos-swiftui/references/lint-checklist.md
set -uo pipefail

# ---- collect .swift files -------------------------------------------------
files=()
if [ "$#" -eq 0 ]; then set -- "."; fi
for arg in "$@"; do
  if [ -d "$arg" ]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$arg" -type f -name '*.swift' 2>/dev/null)
  elif [ -f "$arg" ] && case "$arg" in *.swift) true;; *) false;; esac; then
    files+=("$arg")
  fi
done
if [ "${#files[@]}" -eq 0 ]; then echo "macos-swiftui-lint: no .swift files in: $*"; exit 0; fi

hard=0; warn=0
# flag ID SEV ERE MESSAGE  — SEV is "hard" or "warn"
flag() {
  local id="$1" sev="$2" ere="$3" msg="$4" hit
  hit=$(grep -HnE "$ere" "${files[@]}" 2>/dev/null) || return 0
  [ -z "$hit" ] && return 0
  while IFS= read -r line; do
    printf '%s  [%s/%s] %s\n' "$line" "$id" "$sev" "$msg"
  done <<< "$hit"
  if [ "$sev" = "hard" ]; then hard=$((hard+1)); else warn=$((warn+1)); fi
}

echo "== macos-swiftui-lint: scanning ${#files[@]} file(s) =="

# ---- version drift / deprecation -----------------------------------------
flag R1  hard 'NavigationView[[:space:]]*\{'                         'NavigationView → NavigationStack / NavigationSplitView (Mac sidebar)'
flag R2  warn '\.foregroundColor\('                                  '.foregroundColor → .foregroundStyle'
flag R3  warn '\.cornerRadius\('                                     '.cornerRadius → .clipShape(.rect(cornerRadius:))'
flag R4  warn '\.onChange\(of:[^)]*\)[[:space:]]*\{[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in' 'single-param onChange → two-param { old, new in }'
flag R5  warn '\.tabItem[[:space:]]*\{'                               '.tabItem → Tab(...) {}'
flag R7  warn '\.navigationBarTitle\(|navigationBarTitleDisplayMode'  'navigationBarTitle → .navigationTitle (iOS-only on Mac)'
flag R8  warn 'placement:[[:space:]]*\.navigationBar(Leading|Trailing)' 'navigationBar* placement is iOS-only → .primaryAction/.principal/.navigation'
flag R6  warn 'Text\([^)]*\)[[:space:]]*\+[[:space:]]*Text\('          'Text + Text concatenation deprecated (macOS 26) → string interpolation'
flag R40 warn '\.dropDestination\(for:[^)]+action:[^)]+isTargeted:' 'dropDestination(for:action:isTargeted:) deprecated macOS 26.5 → dropDestination(for:isEnabled:action:)'
flag R41 warn 'MagnificationGesture'                                  'MagnificationGesture deprecated macOS 26.5 → MagnifyGesture (macOS 14+)'
flag R42 warn 'RotationGesture'                                        'RotationGesture deprecated macOS 26.5 → RotateGesture (macOS 14+)'
flag R43 warn 'Font\.system\([^,)]+,[[:space:]]*design:[^,)]+\)'      'Font.system(_:design:) design-only form deprecated macOS 26.5 → Font.system(_:design:weight:)'
flag R44 warn '\.accentColor\('                                        '.accentColor deprecated macOS 26.5 → .tint(_:) (macOS 12+)'
# Note: .foregroundColor → .foregroundStyle is already covered by R2 above.

# ---- hallucination / gating ----------------------------------------------
flag R9  hard '\.glassBackground\(|\.liquidGlass\(|\.material\(\.glass|LiquidGlassView' 'INVENTED Liquid Glass API (does not exist) → .glassEffect()/GlassEffectContainer'
flag R10 warn '\.glassBackgroundEffect\('                            '.glassBackgroundEffect is visionOS-only — not macOS'
flag R12 warn '#available\(iOS [0-9]'                                'iOS-arm availability gate in a macOS skill → gate on #available(macOS …)'

# ---- state & observation --------------------------------------------------
flag R14 hard '@ObservedObject[[:space:]]+var[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*[A-Za-z_]' '@ObservedObject with an initializer → view owns it: use @State/@StateObject'
flag R16 warn '@Published'                                           '@Published is illegal inside @Observable — remove if model is @Observable'
flag R18 warn '@EnvironmentObject'                                   '@EnvironmentObject → @Environment(Type.self) for @Observable deps'

# ---- concurrency ----------------------------------------------------------
flag R21 warn 'DispatchQueue\.main\.async'                           'DispatchQueue.main.async → @MainActor / await MainActor.run'
flag R24 warn 'Task\.detached[[:space:]]*\{'                         'Task.detached can cross actor boundaries with non-Sendable capture — verify'

# ---- scenes / menus -------------------------------------------------------
flag R27 warn 'NSStatusItem'                                         'NSStatusItem in a SwiftUI app → MenuBarExtra scene'
flag R33 warn 'showSettingsWindow:|Preferences[[:space:]]*\{'        'stale pre-Settings-scene pattern → Settings {} scene + SettingsLink'

# ---- sandbox / file access ------------------------------------------------
flag R53 warn 'Data\(contentsOf:|FileManager\.default'              'raw file access — ensure fileImporter/NSOpenPanel consent + security-scoped bookmark'
flag R57 warn 'UIPasteboard'                                         'UIPasteboard does not exist on macOS → NSPasteboard / Transferable'

# ---- previews -------------------------------------------------------------
flag R58 warn 'PreviewProvider'                                      'PreviewProvider → #Preview {} macro (+ @Previewable @State)'

# ---- per-file structural checks (need absence detection) ------------------
for f in "${files[@]}"; do
  if grep -qE ':[[:space:]]*NSViewRepresentable|:[[:space:]]*NSViewControllerRepresentable' "$f" 2>/dev/null; then
    if ! grep -qE 'func[[:space:]]+updateNSView' "$f" 2>/dev/null; then
      printf '%s  [R34/hard] NSViewRepresentable with no updateNSView → SwiftUI state never propagates\n' "$f"
      hard=$((hard+1))
    fi
  fi
  # R45: `let` on the line right after an @Relationship → runtime crash
  awk 'prev ~ /@Relationship/ && $0 ~ /^[[:space:]]*let[[:space:]]/ {printf "%s:%d  [R45/hard] `let` on an @Relationship property → runtime crash, use var\n", FILENAME, NR} {prev=$0}' "$f" && \
    grep -qE '@Relationship' "$f" 2>/dev/null && awk 'prev ~ /@Relationship/ && $0 ~ /^[[:space:]]*let[[:space:]]/ {c++} {prev=$0} END{exit (c>0)?0:1}' "$f" 2>/dev/null && hard=$((hard+1))
done

# ---- positive checks (app targets should have Mac chrome) -----------------
if grep -qE '@main|:[[:space:]]*App([[:space:]]|\{)' "${files[@]}" 2>/dev/null; then
  if ! grep -qE 'Settings[[:space:]]*\{|MenuBarExtra|\.commands[[:space:]]*\{' "${files[@]}" 2>/dev/null; then
    echo "WARN  [P1] app target has no Settings {} / MenuBarExtra / .commands {} — macOS chrome likely faked with buttons"
    warn=$((warn+1))
  fi
fi

echo "== done: ${hard} hard-fail rule(s), ${warn} warning rule(s) =="
[ "$hard" -gt 0 ] && exit 2
exit 0
