#!/usr/bin/env bash
# sosumi — fetch Apple's SwiftUI/Swift docs as clean Markdown (the SPEC layer; pairs with swiftui-ctx, the
# PRACTICE layer). Sosumi (sosumi.ai / nshipster) renders developer.apple.com to Markdown *with* the
# "**Available on:** macOS N+" availability line that the JS SPA hides — the reliable way to VERIFY that an
# API exists, its availability floor, and its signature. NEVER WebFetch developer.apple.com directly: the SPA
# returns an empty shell and the model confabulates a plausible-but-wrong signature.
#
#   sosumi MenuBarExtra                                   # bare SwiftUI symbol -> /documentation/swiftui/menubarextra
#   sosumi documentation/swiftui/view/searchable          # an explicit doc path
#   sosumi https://developer.apple.com/documentation/swiftui/menubarextra   # a full Apple URL (normalized)
#
# Exit: 0 ok · 2 usage · 4 fetch/network (then try: npx -y @nshipster/sosumi fetch <path>).
set -euo pipefail
arg="${1:-}"
[ -n "$arg" ] || { echo "usage: sosumi <SwiftUI symbol | doc-path | apple-url>" >&2; exit 2; }
case "$arg" in
  http*)                          path="$(printf '%s' "$arg" | sed -E 's#https?://[^/]+/##; s#^/##')" ;;
  /documentation/*|documentation/*) path="${arg#/}" ;;
  */*)                            path="${arg#/}" ;;
  *)  # a bare symbol: strip a leading @/. and any (…) signature, lower-case, assume the SwiftUI namespace
      s="$(printf '%s' "$arg" | sed -E 's/^[@.]+//; s/\(.*$//' | tr '[:upper:]' '[:lower:]')"
      path="documentation/swiftui/$s" ;;
esac
command -v curl >/dev/null 2>&1 || { echo "sosumi: needs curl" >&2; exit 4; }
out="$(curl -fsSL --max-time 25 "https://sosumi.ai/$path" 2>/dev/null)" || {
  echo "sosumi: fetch failed for https://sosumi.ai/$path — retry, or: npx -y @nshipster/sosumi fetch $path" >&2
  exit 4; }
printf '%s\n' "$out"
