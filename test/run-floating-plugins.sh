#!/bin/bash
# The floating layout next to the omarchy-macos titlebars and Mission Control plugins in one
# nested Hyprland: the titlebars draw a bar on the windows the layout floated, and Mission
# Control opens and closes over a floating workspace, with nothing crashing or changing.
# Usage: test/run-floating-plugins.sh <hypr-floating.so> [titlebars.so mission-control.so]
set -uo pipefail
source "$(dirname "$0")/lib.sh"
SO="$(realpath "${1:?usage: run-floating-plugins.sh <hypr-floating.so> [titlebars.so mission-control.so]}")"; shift
BARS_SO="${1:-$HOME/.local/lib/omarchy-macos/omarchy-macos-titlebars.so}"
MC_SO="${2:-$HOME/.local/lib/omarchy-macos/omarchy-macos-mission-control.so}"
export LUA="$HERE/floating.lua"
host_guard_start

# bar_at <class>: the titlebar's colour (ff8800) is on screen along the window's top edge
# (a few points, so the title text and the buttons do not hide it)
bar_at() {
  read -r x y w h < <(geom "$1")
  local px cy hex
  for px in $((x + w / 4)) $((x + w / 2)) $((x + 3 * w / 4)); do
    for cy in $((y - 15)) $((y + 15)); do
      hex="$(WAYLAND_DISPLAY="$NESTED_SOCKET" grim -g "$px,$cy 1x1" -t ppm - | tail -c3 | od -An -tx1 | tr -d " \n")"
      [[ $hex == ff8800 ]] && return 0
    done
  done
  return 1
}

echo "== titlebars and Mission Control over a floating workspace"
LOG_NAME=with-plugins BARS=1 session_start "$SO" "$BARS_SO" "$MC_SO"
echo "    plugins: $(hyprctl plugin list | grep 'Plugin ' | tr '\n' ' ')"
for p in hypr-floating hyprbars mission-control; do
  expect "plugin $p is loaded" "$(hyprctl plugin list -j | jq -r --arg p "$p" 'any(.[]; .name == $p)')" true
done
open_class A; open_class B
expect_desc A "$CLAIMED"; expect_desc B "$CLAIMED"
expect "the titlebars plugin has a bar on A" "$(hyprctl decorations class:A | grep -c Hyprbar)" 1
expect_ok "a bar is drawn on A" bar_at A
expect_ok "a bar is drawn on B" bar_at B
layout 1 dwindle
expect_desc A tiled "workspace 1 dwindle: A tiled"
expect_not "dwindle: no bar on A" bar_at A
layout 1 floating
expect_ok "floating again: the bar is back on A" bar_at A
for i in 1 2; do
  hyprctl mission_control >/dev/null; sleep 1.5
  alive
  hyprctl mission_control >/dev/null; sleep 1.5
  alive
done
expect_desc A "$CLAIMED" "after Mission Control: A unchanged"; expect_desc B "$CLAIMED" "after Mission Control: B unchanged"
expect_ok "after Mission Control: the bar is still on A" bar_at A
move_to B 2
expect_desc B tiled "B carried to a dwindle workspace while the other plugins run"
move_to B 1
expect_desc B "$CLAIMED" "and back"
hyprctl plugin unload "$SO" >/dev/null; sleep 1.5
alive
expect_desc A tiled "unloading hypr-floating beside the others: A tiles"
expect_not "unloaded: no bar on a tiled A" bar_at A
hyprctl plugin load "$SO" >/dev/null; sleep 1.5
alive
expect_desc A "$CLAIMED" "loaded again: A floats"
session_stop

host_guard_end
[[ $FAILED == 0 ]] && echo "all PASS" || echo "$FAILED FAIL"
exit $((FAILED != 0))
