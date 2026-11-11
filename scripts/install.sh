#!/bin/bash
# Build the plugin for the Hyprland installed now and install it to
# ~/.local/lib/hypr-floating/hypr-floating.so, where hyprland.lua loads it from, with
# lua/omarchy.lua beside it as omarchy.lua.
#
# The sources are the commit hyprpm.toml pins for this Hyprland (the hyprland-0.56 branch for
# 0.56.x), otherwise main (scripts/source-rev.sh). --worktree builds the working tree instead,
# for development. HYPR_FLOATING_DEST sets another install directory.
#
# Nothing is loaded into the running Hyprland: a running session keeps the plugin it has, and
# the new build loads at the next login.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${HYPR_FLOATING_DEST:-$HOME/.local/lib/hypr-floating}"

src=$(mktemp -d)
trap 'rm -rf "$src"' EXIT

if [[ ${1:-} == --worktree ]]; then
  echo "hypr-floating: building the working tree"
  git -C "$REPO" ls-files -z --cached --others --exclude-standard | tar -C "$REPO" --null -T - -cf - | tar -x -C "$src"
else
  # The pins the daily CI job adds land on GitHub; use them when online.
  git -C "$REPO" fetch -q origin 2>/dev/null || true
  rev=$("$REPO/scripts/source-rev.sh")
  echo "hypr-floating: building $rev"
  git -C "$REPO" archive "$rev" | tar -x -C "$src"
fi

cmake -S "$src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release >"$src/build.log" 2>&1 &&
  cmake --build "$src/build" -j"$(nproc)" >>"$src/build.log" 2>&1 ||
  { cat "$src/build.log" >&2; echo "hypr-floating: the build failed" >&2; exit 1; }

mkdir -p "$DEST"
# Remove before copying: a running Hyprland may have the old build mapped, and overwriting
# a loaded library in place can crash it.
rm -f "$DEST/hypr-floating.so"
cp "$src/build/hypr-floating.so" "$DEST/"
cp "$src/lua/omarchy.lua" "$DEST/"
echo "hypr-floating: installed to $DEST/hypr-floating.so (and omarchy.lua); it loads at the next login"
echo "hypr-floating: load it from hyprland.lua (see the README)"
