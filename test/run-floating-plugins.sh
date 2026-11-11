#!/bin/bash
# The floating layout next to the omarchy-macos titlebars and Mission Control plugins in one
# nested Hyprland: the titlebars draw a bar on the windows the layout floated, Mission
# Control opens and closes over a floating workspace with nothing crashing or changing, and a
# window dropped on another workspace's card in Mission Control takes that workspace's mode.
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

# strip_x <class>: x of the first pixel of the class's colour in Mission Control's workspace strip
strip_x() {
  local want y; want="$(colour "$1")"
  for y in $((H * 10 / 100)) $((H * 12 / 100)) $((H * 14 / 100)) $((H * 16 / 100)); do
    WAYLAND_DISPLAY="$NESTED_SOCKET" grim -g "0,$y ${W}x1" -t ppm - | tail -c $((W * 3)) | od -An -v -tx1 |
      tr -s ' \n' '\n' | grep -v '^$' | paste -d '' - - - | awk -v c="$want" -v y="$y" '$1 == c { print NR + 2, y; f = 1; exit } END { exit !f }' && return 0
  done
  return 1
}
# mc_drop <class> <class on the target card>: open Mission Control, drag the class's tile (the only one
# on the workspace shown) onto the card that shows the other class, release, close
mc_drop() {
  run 'hl.plugin.mission_control.open()' 1.2
  printf 'move %d %d\n' $((W / 2)) $((H * 2 / 3)) | pointer; sleep 0.5
  local to; to="$(strip_x "$2")" || { echo "FAIL: no card shows $2"; FAILED=$((FAILED + 1)); return; }
  read -r tx ty <<<"$to"
  drag_with 272 $((W / 2)) $((H * 6 / 10)) $((tx + 6 - W / 2)) $((ty - H * 6 / 10))
  sleep 0.6
  run 'hl.plugin.mission_control.close()' 1.2
}

echo "== titlebars and Mission Control over a floating workspace"
LOG_NAME=with-plugins BARS=1 session_start "$SO" "$BARS_SO" "$MC_SO"
echo "    plugins: $(hyprctl plugin list | grep 'Plugin ' | tr '\n' ' ')"
for p in hypr-floating hyprbars mission-control; do
  expect "plugin $p is loaded" "$(hyprctl plugin list -j | jq -r --arg p "$p" 'any(.[]; .name == $p)')" true
done
open_class A; open_class B
expect_desc A "$FLOATS"; expect_desc B "$FLOATS"
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
expect_desc A "$FLOATS" "after Mission Control: A unchanged"; expect_desc B "$FLOATS" "after Mission Control: B unchanged"
expect_ok "after Mission Control: the bar is still on A" bar_at A
move_to B 2
expect_desc B tiled "B carried to a dwindle workspace while the other plugins run"
move_to B 1
expect_desc B "$FLOATS" "and back"
echo "== a Mission Control drop takes the mode of the workspace it lands on"
move_to B 3; layout 3 floating
expect_desc B "$FLOATS" "B on the floating workspace 3"
workspace 2; open_class T; workspace 1
mc_drop A T
expect "Mission Control dropped A on workspace 2" "$(workspace_of A)" 2
expect_desc A tiled "floating workspace 1 -> dwindle workspace 2, by a drop: A tiles"
workspace 4; open_class C
mc_drop C B
expect "Mission Control dropped C on workspace 3" "$(workspace_of C)" 3
expect_desc C "$FLOATS" "dwindle workspace 4 -> floating workspace 3, by a drop: C floats"
alive
move_to A 1; workspace 1
hyprctl plugin unload "$SO" >/dev/null; sleep 1.5
alive
expect_desc A tiled "unloading hypr-floating beside the others: A tiles"
expect_not "unloaded: no bar on a tiled A" bar_at A
hyprctl plugin load "$SO" >/dev/null; sleep 1.5
alive
expect_desc A "$FLOATS" "loaded again: A floats"
session_stop

host_guard_end
[[ $FAILED == 0 ]] && echo "all PASS" || echo "$FAILED FAIL"
exit $((FAILED != 0))
