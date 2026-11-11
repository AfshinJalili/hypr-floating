#!/bin/bash
# The floating layout in a nested Hyprland: a workspace whose layout is "floating"
# floats every window. Each scenario starts its own nested Hyprland and prints PASS
# or FAIL; the script exits non-zero on any FAIL.
# Usage: test/run-floating.sh <hypr-floating.so> [scenario ...]
#   scenarios: open switch toggle fullscreen groups move unload monitors tiled (default: all)
set -uo pipefail
source "$(dirname "$0")/lib.sh"
SO="$(realpath "${1:?usage: run-floating.sh <hypr-floating.so> [scenario ...]}")"; shift
export LUA="$HERE/floating.lua"
host_guard_start

# overlaps <class> <class>: the two windows' boxes share an area
overlaps() {
  read -r ax ay aw ah < <(geom "$1"); read -r bx by bw bh < <(geom "$2")
  ((ax < bx + bw && bx < ax + aw && ay < by + bh && by < ay + ah))
}
# inside <class>: the window lies inside the monitor
inside() { read -r x y w h < <(geom "$1"); ((x >= 0 && y >= 0 && x + w <= W && y + h <= H)); }
# box <step> [monitor width height]: where the layout puts a window at a cascade step: 64% x 68% of the
# monitor (at most 1100 x 760), centred, stepped 24px per step from the middle one (step 2)
box() { awk -v W="${2:-$W}" -v H="${3:-$H}" -v s="$1" 'function r(v) { return int(v + 0.5) }
  BEGIN { w = int(W * 0.64); if (w > 1100) w = 1100; h = int(H * 0.68); if (h > 760) h = 760
          o = (s - 2) * 24; printf "%d %d %d %d", r((W - w) / 2 + o), r((H - h) / 2 + o), w, h }'; }
grouped_count() { win "$1" | jq -r '.grouped | length'; }

scenario_open() {
  echo "== open: new windows float centred and cascaded; drag, resize"
  LOG_NAME=open session_start "$SO"
  expect "workspace 1 reports the layout" "$(layout_of 1)" floating
  open_class A; open_class B
  expect_desc A "$FLOATS" "open: A"; expect_desc B "$FLOATS" "open: B"
  expect "open: A is 64% x 68% of the screen, centred, one cascade step from the middle (-24)" "$(geom A)" "$(box 1)"
  expect "open: B is one step further (+24,+24)" "$(geom B)" "$(box 2)"
  read -r bx by bw bh < <(geom B)
  drag_with 273 $((bx + bw / 2)) $((by + bh / 2)) 100 60
  read -r nx ny nw nh < <(geom B)
  expect "drag: B moved by the pointer's distance (within 10px)" "$(((nx - bx - 100) ** 2 < 100 && (ny - by - 60) ** 2 < 100 && nw == bw && nh == bh))" 1
  expect_desc B "$FLOATS" "drag: B is still floating"
  bx=$nx by=$ny bw=$nw bh=$nh
  drag_with 274 $((bx + bw - 40)) $((by + bh - 40)) -120 -80
  read -r nx ny nw nh < <(geom B)
  expect "resize: B shrank by the pointer's distance (within 12px)" "$(((nw - bw + 120) ** 2 < 144 && (nh - bh + 80) ** 2 < 144))" 1
  expect_desc B "$FLOATS" "resize: B is still floating"
  run 'hl.dispatch(hl.dsp.window.resize({ x = 600, y = 400, relative = false, window = "class:^B$" }))'
  run 'hl.dispatch(hl.dsp.window.move({ x = 100, y = 120, relative = false, window = "class:^B$" }))'
  expect "dispatchers: B resized and moved exactly" "$(geom B)" "100 120 600 400"
  close_class B; close_class A
  open_class C
  expect "after closing both, the next window steps on (cascade keeps going)" "$(desc C)" "$FLOATS"
  alive; session_stop
}

scenario_switch() {
  echo "== switch: dwindle <-> floating, with the layout changed live"
  LOG_NAME=switch WS1_LAYOUT=dwindle session_start "$SO"
  expect "workspace 1 starts as dwindle" "$(layout_of 1)" dwindle
  open_class A; open_class B
  expect_desc A tiled "dwindle: A tiled"; expect_desc B tiled "dwindle: B tiled"
  layout 1 floating
  expect "workspace 1 reports floating" "$(layout_of 1)" floating
  expect_desc A "$FLOATS" "dwindle -> floating: A floated"; expect_desc B "$FLOATS" "dwindle -> floating: B floated"
  open_class F
  expect_desc F "$FLOATS" "a window floated by a rule (a dialog would be the same) floats, marked"
  read -r f0 < <(geom F)
  layout 1 dwindle
  expect "workspace 1 reports dwindle" "$(layout_of 1)" dwindle
  expect_desc A tiled "floating -> dwindle: A tiled again, mark gone"; expect_desc B tiled "floating -> dwindle: B tiled again, mark gone"
  expect_desc F floating "floating -> dwindle: F, floating by its own nature, stays floating, mark gone"
  expect "floating -> dwindle: F did not move" "$(geom F)" "$f0"
  expect_not "dwindle: A and B do not overlap" overlaps A B
  expect_ok "dwindle: A fits the screen" inside A; expect_ok "dwindle: B fits the screen" inside B
  layout 1 floating
  expect_desc A "$FLOATS" "second round: A floated again"; expect_desc B "$FLOATS" "second round: B floated again"
  expect_desc F "$FLOATS" "second round: F floats"
  expect "second round: F did not move" "$(geom F)" "$f0"
  layout 1 dwindle; layout 1 floating; layout 1 dwindle
  expect_desc A tiled "a third and fourth switch: A"; expect_desc F floating "a third and fourth switch: F"
  alive; session_stop
}

scenario_toggle() {
  echo "== toggle: togglefloating on a floating workspace holds until the mode next reaches the window"
  LOG_NAME=toggle session_start "$SO"
  open_class A; open_class B
  float_off A 1.5
  expect_desc A "$TILED_HERE" "A un-floated: tiled"
  expect_ok "A is laid out sanely: inside the screen, a real size" inside A
  expect_desc B "$FLOATS" "B is not touched"
  sleep 1
  expect_desc A "$TILED_HERE" "A is still tiled a second later"
  open_class C
  expect_desc C "$FLOATS" "a new window still floats beside the tiled A"
  expect_desc A "$TILED_HERE" "A stays tiled when C opens"
  float_off B 1.5
  expect_desc B "$TILED_HERE" "B un-floated too"
  expect_not "A and B tile side by side without overlapping" overlaps A B
  expect_ok "A fits the screen" inside A; expect_ok "B fits the screen" inside B
  run 'hl.dispatch(hl.dsp.window.float({ action = "toggle", window = "class:^A$" }))' 1.2
  expect_desc A "$FLOATS" "toggled back to floating"
  expect_desc B "$TILED_HERE" "B is the only tiled window now"
  layout 1 dwindle
  expect_desc A tiled "to dwindle: A, floated by the user, tiles with the rest"
  expect_desc B tiled "to dwindle: B stays tiled"
  expect_desc C tiled "to dwindle: C tiles"
  layout 1 floating
  for c in A B C; do expect_desc $c "$FLOATS" "to floating again: $c floats, B's toggle is over"; done
  alive; session_stop
}

scenario_fullscreen() {
  echo "== fullscreen: full screen and maximize restore the geometry, with the stacking fix"
  LOG_NAME=fullscreen session_start "$SO"
  open_class B; open_class A
  for mode in fullscreen maximized; do
    read -r before < <(geom A)
    fullscreen "$mode" A
    expect_desc A "$FLOATS" "$mode: A still floating"
    [[ $mode == fullscreen ]] && expect "fullscreen: A covers the screen" "$(geom A)" "0 0 $W $H"
    [[ $mode == maximized ]] && expect_ok "maximized: A is bigger than before" test "$(geom A | cut -d' ' -f3)" -gt "$(cut -d' ' -f3 <<<"$before")"
    fullscreen "$mode" A
    expect "$mode: leaving restores A's geometry" "$(geom A)" "$before"
  done
  read -r bx by < <(spot B)
  fullscreen fullscreen A
  focus_class B
  observe "stacking: B focused below the full-screen A is drawn and clickable" B "$bx" "$by"
  observe "stacking: click A beside B" A 40 $((H - 40))
  observe "stacking: A raised, so A is drawn and clickable at B's spot" A "$bx" "$by"
  fullscreen fullscreen A
  layout 1 dwindle
  expect_desc A tiled "full screen over, then the layout changes: A tiles"
  layout 1 floating
  fullscreen maximized A
  layout 1 dwindle
  expect_desc A floating "maximized while the layout changes to dwindle: A is left as it is"
  fullscreen maximized A
  expect_desc A tiled "A leaves maximized: it takes the workspace's mode and tiles"
  alive; session_stop
}

scenario_groups() {
  echo "== groups: a group floats, tiles and floats again as one, every member tagged"
  LOG_NAME=groups session_start "$SO"
  open_class A
  focus_class A
  run 'hl.dispatch(hl.dsp.group.toggle())'
  open_class C
  expect "the group has both" "$(grouped_count A)" 2
  expect_desc A "$FLOATS" "a window opening into the group: the head"; expect_desc C "$FLOATS" "a window opening into the group: the new member"
  for round in 1 2 3; do
    layout 1 dwindle
    expect_desc A tiled "round $round, dwindle: head tiled"; expect_desc C tiled "round $round, dwindle: member tiled"
    layout 1 floating
    expect_desc A "$FLOATS" "round $round, floating: head floats, marked"; expect_desc C "$FLOATS" "round $round, floating: member floats, marked"
  done
  open_class P
  expect "a third member joins" "$(grouped_count A)" 3
  expect_desc P "$FLOATS" "the third member floats, marked"
  move_to A 2
  expect_desc C tiled "the group moved to a dwindle workspace: every member tiles"; expect_desc P tiled "the group moved to a dwindle workspace: the third too"
  move_to A 1
  for c in A C P; do expect_desc $c "$FLOATS" "the group moved back: $c"; done
  alive; session_stop
}

scenario_move() {
  echo "== move: a window carried to another workspace takes that workspace's mode"
  LOG_NAME=move session_start "$SO"
  open_class A; open_class F
  move_to A 2
  expect_desc A tiled "floating -> dwindle workspace: A tiles"
  move_to A 1
  expect_desc A "$FLOATS" "back: A floats"
  move_to F 2
  expect_desc F floating "a rule-floated window carried to the dwindle workspace stays floating, unmarked"
  workspace 2
  open_class D
  expect_desc D tiled "a window opened on the dwindle workspace is tiled"
  move_to D 1
  expect_desc D "$FLOATS" "carried to the floating workspace: floated"
  move_to D 2
  expect_desc D tiled "carried out again: tiled"
  float_on D
  expect_desc D floating "the user floats D on the dwindle workspace"
  move_to D 3
  expect_desc D tiled "carried to another dwindle workspace: the user's float is over, D tiles"
  float_off A 1.5
  expect_desc A "$TILED_HERE" "the user tiles A on the floating workspace"
  move_to A 4
  layout 4 floating
  expect_desc A "$FLOATS" "A carried to another floating workspace: it floats"
  workspace 1
  alive; session_stop
}

scenario_unload() {
  echo "== unload: the windows of floating workspaces tile, but those that float on their own; the session lives"
  LOG_NAME=unload session_start "$SO"
  open_class A; open_class B; open_class F; open_class D
  float_off D; float_on D     # D is floating because the user floated it
  expect_desc D "$FLOATS" "D floated by the user"
  workspace 2; open_class C; float_on C; workspace 1
  expect_desc C floating "C floated by the user on the dwindle workspace 2"
  hyprctl plugin unload "$SO" >/dev/null; sleep 1.5
  alive
  expect "unloaded: workspace 1 has a layout of Hyprland's" "$(layout_of 1)" dwindle
  expect_desc A tiled "unloaded: A tiles"; expect_desc B tiled "unloaded: B tiles"
  expect_desc D tiled "unloaded: D, floated by hand where the layout floats, tiles too"
  expect_desc F floating "unloaded: F (a rule) stays floating, mark gone"
  expect_desc C floating "unloaded: C, on a workspace that never floated, is left alone"
  expect_not "unloaded: A and B do not overlap" overlaps A B
  hyprctl plugin load "$SO" >/dev/null; sleep 1.5
  alive
  expect "loaded again: the layout is back" "$(layout_of 1)" floating
  for c in A B D F; do expect_desc $c "$FLOATS" "loaded again: $c floats"; done
  expect_desc C floating "loaded again: C left alone"
  for i in 1 2 3; do # unload and load right after a window opens and a layout changes, with no pause
    hyprctl eval 'hl.dispatch(hl.dsp.exec_cmd("foot --app-id E sleep 600"))' >/dev/null
    hyprctl plugin unload "$SO" >/dev/null; hyprctl plugin load "$SO" >/dev/null
    sleep 1.2
    alive
  done
  hyprctl eval 'hl.workspace_rule({ workspace = "1", layout = "dwindle" })' >/dev/null
  hyprctl plugin unload "$SO" >/dev/null
  sleep 1.2
  alive
  expect_desc A tiled "unload in the tick after a layout change: A tiled"
  hyprctl plugin load "$SO" >/dev/null; sleep 1.2
  hyprctl plugin unload "$SO" >/dev/null; sleep 1.2   # unload with the layout asked for as dwindle: nothing to give back
  alive; session_stop
}

scenario_monitors() {
  echo "== monitors: a floating workspace on each of two monitors"
  LOG_NAME=monitors session_start "$SO"
  hyprctl output create headless >/dev/null; sleep 2
  mon2="$(hyprctl monitors -j | jq -r '.[] | select(.name != "WAYLAND-1") | .name')"
  # the monitor's logical size: Hyprland scales a headless output
  mw="$(hyprctl monitors -j | jq -r --arg m "$mon2" '.[] | select(.name == $m) | (.width / .scale | floor)')"
  mx="$(hyprctl monitors -j | jq -r --arg m "$mon2" '.[] | select(.name == $m) | .x')"
  mh="$(hyprctl monitors -j | jq -r --arg m "$mon2" '.[] | select(.name == $m) | (.height / .scale | floor)')"
  ws2="$(hyprctl monitors -j | jq -r --arg m "$mon2" '.[] | select(.name == $m) | .activeWorkspace.id')"
  echo "    second monitor $mon2 ${mw}x${mh} at x=$mx, workspace $ws2"
  layout "$ws2" floating
  expect "the second monitor's workspace floats" "$(layout_of "$ws2")" floating
  open_class A
  run "hl.dispatch(hl.dsp.focus({ monitor = \"$mon2\" }))" 0.6
  open_class B
  expect "A is on workspace 1" "$(workspace_of A)" 1; expect "B is on the second monitor's workspace" "$(workspace_of B)" "$ws2"
  expect_desc A "$FLOATS" "monitor 1: A floats"; expect_desc B "$FLOATS" "monitor 2: B floats"
  expect "monitor 2: B floats centred on its own monitor (the cascade's middle step)" "$(geom B)" "$(box 2 "$mw" "$mh" | awk -v mx="$mx" '{ print $1 + mx, $2, $3, $4 }')"
  layout 1 dwindle
  expect_desc A tiled "workspace 1 dwindle: A tiles"; expect_desc B "$FLOATS" "workspace 1 dwindle: B on the other monitor still floats"
  layout 1 floating; layout "$ws2" dwindle
  expect_desc A "$FLOATS" "swapped: A floats"; expect_desc B tiled "swapped: B tiles"
  layout "$ws2" floating
  expect_desc B "$FLOATS" "both floating again: B"
  layout 1 dwindle
  move_to A "$ws2"
  expect "A carried to the other monitor" "$(workspace_of A)" "$ws2"
  expect_desc A "$FLOATS" "tiled on monitor 1 -> floating workspace on monitor 2: A floats"
  move_to B 1
  expect_desc B tiled "floating on monitor 2 -> dwindle workspace on monitor 1: B tiles"
  alive; session_stop
}

scenario_tiled() {
  echo "== tiled: a change between two tiled layouts reaches the windows too"
  LOG_NAME=tiled WS1_LAYOUT=dwindle session_start "$SO"
  open_class A; open_class B; open_class F
  float_on A
  expect_desc A floating "the user floats A on dwindle"
  layout 1 scrolling
  expect "workspace 1 scrolls" "$(layout_of 1)" scrolling
  expect_desc A tiled "dwindle -> scrolling: A tiles with the rest"
  expect_desc F floating "dwindle -> scrolling: F (a rule) stays floating"
  layout 1 dwindle
  float_on B
  hyprctl reload >/dev/null; sleep 2
  expect_desc B floating "a reload that changes no layout leaves the user's float alone"
  alive; session_stop
}

SCENARIOS=("$@"); [[ ${#SCENARIOS[@]} == 0 ]] && SCENARIOS=(open switch toggle fullscreen groups move unload monitors tiled)
for s in "${SCENARIOS[@]}"; do "scenario_$s"; done

host_guard_end
[[ $FAILED == 0 ]] && echo "all PASS" || echo "$FAILED FAIL"
exit $((FAILED != 0))
