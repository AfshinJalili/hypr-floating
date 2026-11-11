#!/bin/bash
# Check spec/Stacking.tla and spec/Floating.tla with TLC, and that the variants without
# the plugin's rules fail the way the models say they do.
# Usage: spec/check.sh [--big]     --big also checks four windows of Stacking (about 500k states)
# Needs Java and tla2tools.jar: downloaded once into ~/.local/share/hypr-floating-tools/
# (a Temurin JRE, and TLC from tlaplus/tlaplus), each checked against a pinned sha256.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOLS="${HYPR_FLOATING_TOOLS:-$HOME/.local/share/hypr-floating-tools}"
JRE_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/OpenJDK21U-jre_x64_linux_hotspot_21.0.13_9.tar.gz"
JRE_SHA="a535a1df9c6284d9618872984e026ae0352d1f7e9e0605425c0e6114f47351dd"
TLA_URL="https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar"
TLA_SHA="936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"

fetch() { # <url> <sha256> <file>
  [[ -f $3 ]] && return 0
  curl -fsSL "$1" -o "$3.part" && echo "$2  $3.part" | sha256sum -c --status - && mv "$3.part" "$3" || { rm -f "$3.part"; echo "could not fetch $1" >&2; exit 1; }
}

mkdir -p "$TOOLS/dl"
fetch "$JRE_URL" "$JRE_SHA" "$TOOLS/dl/jre.tar.gz"
fetch "$TLA_URL" "$TLA_SHA" "$TOOLS/dl/tla2tools.jar"
if [[ ! -x $TOOLS/jre/bin/java ]]; then
  mkdir -p "$TOOLS/jre" && tar xzf "$TOOLS/dl/jre.tar.gz" -C "$TOOLS/jre" --strip-components=1
fi
JAVA="$TOOLS/jre/bin/java"

FAILED=0
META="$(mktemp -d)"; trap 'rm -rf "$META"' EXIT

# tlc <module> <cfg> <expected exit code> <description>
#   0: no error found, 12: an invariant is violated, 13: a temporal property is violated
tlc() {
  local module="$1" cfg="$2" want="$3" what="$4" out rc
  out="$("$JAVA" -XX:+UseParallelGC -Xmx4g -cp "$TOOLS/dl/tla2tools.jar" tlc2.TLC -workers auto -metadir "$META/$cfg" -config "$HERE/$cfg.cfg" "$HERE/$module.tla" 2>&1)"
  rc=$?
  echo "== $cfg: $what"
  echo "$out" | grep -E "^(Error:|Model checking completed|[0-9]+ states generated)" | head -4
  if [[ $rc == "$want" ]]; then echo "PASS: $cfg exited $rc as expected"
  else echo "FAIL: $cfg exited $rc, expected $want"; echo "$out" | tail -30; FAILED=1; fi
  [[ ${SHOW_TRACE:-0} == 1 && $want != 0 ]] && echo "$out" | sed -n '/^Error: The behavior/,/^[0-9]* states generated/p'
}

tlc Stacking Stacking            0  "both rules: every property holds (3 windows)"
tlc Stacking Stacking_stock      12 "stock Hyprland: the bug, a window drawn over full screen whose clicks go to the full-screen window"
tlc Stacking Stacking_stock_top  12 "stock Hyprland: what is on top is not what the click reaches"
tlc Stacking Stacking_stock_above 12 "stock Hyprland: a window stacked above the full-screen window is hidden"
tlc Stacking Stacking_rule1      12 "rule 1 without rule 2: a window focused below the full-screen window is hidden and loses focus"
tlc Floating Floating            0  "the floating layout: the workspace's mode is the truth, every property holds (3 windows, 2 workspaces, the minimized one, a group)"
tlc Floating Floating_claimed    12 "the old rule, tiling again only what the layout floated: a window floated by hand stays floating where nothing floats"
tlc Floating Floating_nomove     12 "without the move rule: a window carried to a floating workspace stays tiled"
tlc Floating Floating_noexit     12 "without the unload rule: a floated window stays floating once nothing floats it"
tlc Floating Floating_all        13 "without the own-nature exception: a dialog or a rule-floated window is tiled"
tlc Floating Floating_frozen     12 "the own nature read once, where the window opens: a window a workspace's rule floated stays floating where nothing floats it"
[[ ${1:-} == --big ]] && tlc Stacking Stacking_4 0 "both rules, 4 windows"

[[ $FAILED == 0 ]] && echo "all as expected" || echo "unexpected results"
exit $FAILED
