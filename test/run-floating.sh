#!/bin/bash
# The floating layout in a nested Hyprland: a workspace whose layout is "floating"
# floats every window. Each scenario starts its own nested Hyprland and prints PASS
# or FAIL; the script exits non-zero on any FAIL.
# Usage: test/run-floating.sh <hypr-floating.so> [scenario ...]
#   scenarios: open switch toggle fullscreen groups move unload monitors (default: all)
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
expect_ok() { if "${@:2}"; then echo "PASS: $1"; else echo "FAIL: $1"; FAILED=$((FAILED + 1)); fi; }  # expect_ok <what> <cmd...>
expect_not() { if ! "${@:2}"; then echo "PASS: $1"; else echo "FAIL: $1"; FAILED=$((FAILED + 1)); fi; }
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
  expect_desc A "$CLAIMED" "open: A"; expect_desc B "$CLAIMED" "open: B"
  expect "open: A is 64% x 68% of the screen, centred, one cascade step from the middle (-24)" "$(geom A)" "$(box 1)"
  expect "open: B is one step further (+24,+24)" "$(geom B)" "$(box 2)"
  read -r bx by bw bh < <(geom B)
  drag_with 273 $((bx + bw / 2)) $((by + bh / 2)) 100 60
  read -r nx ny nw nh < <(geom B)
  expect "drag: B moved by the pointer's distance (within 10px)" "$(((nx - bx - 100) ** 2 < 100 && (ny - by - 60) ** 2 < 100 && nw == bw && nh == bh))" 1
  expect_desc B "$CLAIMED" "drag: B is still floating and claimed"
  bx=$nx by=$ny bw=$nw bh=$nh
  drag_with 274 $((bx + bw - 40)) $((by + bh - 40)) -120 -80
  read -r nx ny nw nh < <(geom B)
  expect "resize: B shrank by the pointer's distance (within 12px)" "$(((nw - bw + 120) ** 2 < 144 && (nh - bh + 80) ** 2 < 144))" 1
  expect_desc B "$CLAIMED" "resize: B is still floating and claimed"
  run 'hl.dispatch(hl.dsp.window.resize({ x = 600, y = 400, relative = false, window = "class:^B$" }))'
  run 'hl.dispatch(hl.dsp.window.move({ x = 100, y = 120, relative = false, window = "class:^B$" }))'
  expect "dispatchers: B resized and moved exactly" "$(geom B)" "100 120 600 400"
  close_class B; close_class A
  open_class C
  expect "after closing both, the next window steps on (cascade keeps going)" "$(desc C)" "$CLAIMED"
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
  expect_desc A "$CLAIMED" "dwindle -> floating: A floated and claimed"; expect_desc B "$CLAIMED" "dwindle -> floating: B floated and claimed"
  open_class F
  expect_desc F "$ALONE" "a window floated by a rule is not claimed"
  read -r f0 < <(geom F)
  layout 1 dwindle
  expect "workspace 1 reports dwindle" "$(layout_of 1)" dwindle
  expect_desc A tiled "floating -> dwindle: A tiled again, tags gone"; expect_desc B tiled "floating -> dwindle: B tiled again, tags gone"
  expect_desc F floating "floating -> dwindle: F stays floating, tags gone"
  expect "floating -> dwindle: F did not move" "$(geom F)" "$f0"
  expect_not "dwindle: A and B do not overlap" overlaps A B
  expect_ok "dwindle: A fits the screen" inside A; expect_ok "dwindle: B fits the screen" inside B
  layout 1 floating
  expect_desc A "$CLAIMED" "second round: A floated again"; expect_desc B "$CLAIMED" "second round: B floated again"
  expect_desc F "$ALONE" "second round: F still unclaimed"
  expect "second round: F did not move" "$(geom F)" "$f0"
  layout 1 dwindle; layout 1 floating; layout 1 dwindle
  expect_desc A tiled "a third and fourth switch: A"; expect_desc F floating "a third and fourth switch: F"
  alive; session_stop
}

scenario_toggle() {
  echo "== toggle: togglefloating on a floating workspace sticks"
  LOG_NAME=toggle session_start "$SO"
  open_class A; open_class B
  float_off A 1.5
  expect_desc A "$TILED_HERE" "A un-floated: tiled, no longer claimed"
  expect_ok "A is laid out sanely: inside the screen, a real size" inside A
  expect_desc B "$CLAIMED" "B is not touched"
  sleep 1
  expect_desc A "$TILED_HERE" "A is still tiled a second later"
  open_class C
  expect_desc C "$CLAIMED" "a new window still floats beside the tiled A"
  expect_desc A "$TILED_HERE" "A stays tiled when C opens"
  float_off B 1.5
  expect_desc B "$TILED_HERE" "B un-floated too"
  expect_not "A and B tile side by side without overlapping" overlaps A B
  expect_ok "A fits the screen" inside A; expect_ok "B fits the screen" inside B
  run 'hl.dispatch(hl.dsp.window.float({ action = "toggle", window = "class:^A$" }))' 1.2
  expect_desc A "$ALONE" "toggled back to floating: floating, not claimed"
  expect_desc B "$TILED_HERE" "B is the only tiled window now"
  layout 1 dwindle
  expect_desc A floating "to dwindle: A, floated by the user, stays floating"
  expect_desc B tiled "to dwindle: B stays tiled"
  expect_desc C tiled "to dwindle: C, floated by the layout, tiles"
  layout 1 floating
  expect_desc B "$CLAIMED" "to floating again: B, tiled when the layout came back, is floated"
  expect_desc A "$ALONE" "to floating again: A stays unclaimed"
  alive; session_stop
}

scenario_fullscreen() {
  echo "== fullscreen: full screen and maximize restore the geometry, with the stacking fix"
  LOG_NAME=fullscreen session_start "$SO"
  open_class B; open_class A
  for mode in fullscreen maximized; do
    read -r before < <(geom A)
    fullscreen "$mode" A
    expect_desc A "$CLAIMED" "$mode: A still floating and claimed"
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
  expect_desc A "$CLAIMED" "a window opening into the group: the head"; expect_desc C "$CLAIMED" "a window opening into the group: the new member"
  for round in 1 2 3; do
    layout 1 dwindle
    expect_desc A tiled "round $round, dwindle: head tiled"; expect_desc C tiled "round $round, dwindle: member tiled"
    layout 1 floating
    expect_desc A "$CLAIMED" "round $round, floating: head claimed and tagged"; expect_desc C "$CLAIMED" "round $round, floating: member claimed and tagged"
  done
  open_class P
  expect "a third member joins" "$(grouped_count A)" 3
  expect_desc P "$CLAIMED" "the third member is tagged"
  move_to A 2
  expect_desc C tiled "the group moved to a dwindle workspace: every member tiles"; expect_desc P tiled "the group moved to a dwindle workspace: the third too"
  move_to A 1
  for c in A C P; do expect_desc $c "$CLAIMED" "the group moved back: $c"; done
  alive; session_stop
}

scenario_move() {
  echo "== move: windows carried between a floating and a dwindle workspace"
  LOG_NAME=move session_start "$SO"
  open_class A
  move_to A 2
  expect_desc A tiled "floating -> dwindle workspace: A tiles"
  move_to A 1
  expect_desc A "$CLAIMED" "back: A floats and is claimed"
  workspace 2
  open_class D
  expect_desc D tiled "a window opened on the dwindle workspace is tiled"
  move_to D 1
  expect_desc D "$CLAIMED" "carried to the floating workspace: floated and claimed"
  move_to D 2
  expect_desc D tiled "carried out again: tiled"
  float_on D
  expect_desc D floating "the user floats D on the dwindle workspace"
  move_to D 1
  expect_desc D "$ALONE" "a user-floated window carried in stays unclaimed"
  move_to D 2
  expect_desc D floating "carried out: still floating"
  workspace 1
  alive; session_stop
}

scenario_unload() {
  echo "== unload: only the windows the layout floated tile again; the session lives"
  LOG_NAME=unload session_start "$SO"
  open_class A; open_class B; open_class F; open_class D
  float_off D; float_on D     # D is floating because the user floated it
  expect_desc D "$ALONE" "D floated by the user"
  hyprctl plugin unload "$SO" >/dev/null; sleep 1.5
  alive
  expect "unloaded: workspace 1 has a layout of Hyprland's" "$(layout_of 1)" dwindle
  expect_desc A tiled "unloaded: A (ours) tiles"; expect_desc B tiled "unloaded: B (ours) tiles"
  expect_desc F floating "unloaded: F (a rule) stays floating, tags gone"; expect_desc D floating "unloaded: D (the user's) stays floating, tags gone"
  expect_not "unloaded: A and B do not overlap" overlaps A B
  hyprctl plugin load "$SO" >/dev/null; sleep 1.5
  alive
  expect "loaded again: the layout is back" "$(layout_of 1)" floating
  expect_desc A "$CLAIMED" "loaded again: A floats"; expect_desc B "$CLAIMED" "loaded again: B floats"
  expect_desc F "$ALONE" "loaded again: F untouched"; expect_desc D "$ALONE" "loaded again: D untouched"
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
  expect_desc A "$CLAIMED" "monitor 1: A claimed"; expect_desc B "$CLAIMED" "monitor 2: B claimed"
  expect "monitor 2: B floats centred on its own monitor (the cascade's middle step)" "$(geom B)" "$(box 2 "$mw" "$mh" | awk -v mx="$mx" '{ print $1 + mx, $2, $3, $4 }')"
  layout 1 dwindle
  expect_desc A tiled "workspace 1 dwindle: A tiles"; expect_desc B "$CLAIMED" "workspace 1 dwindle: B on the other monitor still floats"
  layout 1 floating; layout "$ws2" dwindle
  expect_desc A "$CLAIMED" "swapped: A floats"; expect_desc B tiled "swapped: B tiles"
  layout "$ws2" floating
  expect_desc B "$CLAIMED" "both floating again: B"
  alive; session_stop
}

SCENARIOS=("$@"); [[ ${#SCENARIOS[@]} == 0 ]] && SCENARIOS=(open switch toggle fullscreen groups move unload monitors)
for s in "${SCENARIOS[@]}"; do "scenario_$s"; done

host_guard_end
[[ $FAILED == 0 ]] && echo "all PASS" || echo "$FAILED FAIL"
exit $((FAILED != 0))
