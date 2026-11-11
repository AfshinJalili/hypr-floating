#!/bin/bash
# What is drawn over a floating full-screen or maximized window takes the clicks.
# Usage: test/run-click.sh <hypr-floating.so | none>
#   With "none" no plugin is loaded: it shows what stock Hyprland does (the bug).
# Every scenario runs in its own nested Hyprland and prints PASS or FAIL; the script
# exits non-zero on any FAIL (with "none": unless the bug shows and tiled full screen is stock).
set -uo pipefail
source "$(dirname "$0")/lib.sh"
PLUGIN="${1:?usage: run-click.sh <hypr-floating.so | none>}"
plugins() { [[ $PLUGIN == none ]] || echo "$PLUGIN"; }
START="session_start $(plugins)"

host_guard_start

for FS in fullscreen maximized; do
  # a: Hyprland draws a floating window it focused (without raising it) over full screen.
  echo "== $FS: a: focus without raising, then click"
  LOG_NAME=a-$FS $START
  open_class B; open_class A
  read -r bx by < <(spot B)
  fullscreen $FS A
  focus_class B
  flags
  observe "[$FS] a: B focused below A: drawn and clickable" B "$bx" "$by"
  session_stop

  # b: raising A leaves B drawn over it in stock Hyprland, but the click goes to A.
  echo "== $FS: b: click A, then click where B is drawn"
  LOG_NAME=b-$FS $START
  open_class B; open_class A
  read -r bx by < <(spot B)
  fullscreen $FS A
  focus_class B; run 'hl.dispatch(hl.dsp.window.bring_to_top())'
  flags
  observe "[$FS] b1: B raised over A: drawn and clickable" B "$bx" "$by"
  observe "[$FS] b2: click A beside B: A" A 40 $((H - 40))
  flags
  observe "[$FS] b3: A raised, so B is behind it: A drawn and clickable at B's spot" A "$bx" "$by"
  focus_class B
  observe "[$FS] b4: B focused again: drawn and clickable" B "$bx" "$by"
  session_stop

  # c: a tiled full-screen window is stock Hyprland's, with or without the plugin.
  echo "== $FS: c: tiled full-screen window"
  LOG_NAME=c-$FS $START
  open_class B; open_class T
  read -r bx by < <(spot B)
  fullscreen $FS T
  flags
  observe "[$FS] c1: B is behind the tiled full-screen T" T "$bx" "$by"
  focus_class B
  observe "[$FS] c2: focused B is over the tiled full-screen T" B "$bx" "$by"
  observe "[$FS] c3: click T beside B" T 40 $((H - 40))
  observe "[$FS] c4: B stays over T (the flag focus set is stock's)" B "$bx" "$by"
  session_stop

  # d: a pinned window is always over full screen; the plugin leaves it alone.
  echo "== $FS: d: pinned window"
  LOG_NAME=d-$FS $START
  open_class P
  run 'hl.dispatch(hl.dsp.window.pin({ window = "class:^P$" }))'
  open_class A
  read -r px py < <(spot P)
  fullscreen $FS A
  flags
  observe "[$FS] d: pinned P below A: drawn and clickable" P "$px" "$py"
  session_stop

  # e: closing the full-screen window brings the others back.
  echo "== $FS: e: closing the full-screen window"
  LOG_NAME=e-$FS $START
  open_class B; open_class C; open_class A
  read -r cx cy < <(spot C)
  fullscreen $FS A
  focus_class C
  close_class A
  flags
  observe "[$FS] e1: A closed: C, the top window, drawn and clickable" C "$cx" "$cy"
  session_stop

  # f: leaving full screen and entering it again.
  echo "== $FS: f: toggle full screen off and on"
  LOG_NAME=f-$FS $START
  open_class B; open_class A
  read -r bx by < <(spot B)
  fullscreen $FS A
  focus_class B
  fullscreen $FS A
  flags
  observe "[$FS] f1: full screen off: B, the top window, drawn and clickable" B "$bx" "$by"
  fullscreen $FS A
  flags
  observe "[$FS] f2: full screen on again: B is above A: drawn and clickable" B "$bx" "$by"
  observe "[$FS] f3: click A beside B: A" A 40 $((H - 40))
  observe "[$FS] f4: A raised, so B is behind it: A drawn and clickable at B's spot" A "$bx" "$by"
  session_stop

  # g: a window that opens over full screen is drawn over it and takes clicks.
  echo "== $FS: g: a new window over full screen"
  LOG_NAME=g-$FS $START
  open_class B; open_class A
  fullscreen $FS A
  open_class C
  read -r cx cy < <(spot C)
  flags
  observe "[$FS] g: new C over A: drawn and clickable" C "$cx" "$cy"
  session_stop
done

if [[ $PLUGIN != none ]]; then
  # h: stacking_fix = 0 gives stock behaviour back: the bug.
  echo "== h: stacking_fix = 0"
  LOG_NAME=h $START
  run 'hl.config({ plugin = { hypr_floating = { stacking_fix = 0 } } })'
  open_class B; open_class A
  read -r bx by < <(spot B)
  fullscreen fullscreen A
  focus_class B
  flags
  d="$(drawn "$bx" "$by")"; c="$(click "$bx" "$by")"
  if [[ $d == B && $c == A ]]; then echo "PASS: h: with stacking_fix = 0 B is drawn over A but the click goes to A (stock)"
  else echo "FAIL: h: with stacking_fix = 0 expected drawn=B clicked=A, got drawn=$d clicked=$c"; FAILED=$((FAILED + 1)); fi
  alive
  session_stop
fi

host_guard_end
if [[ $PLUGIN == none ]]; then
  # The bug must show, and tiled full screen must not be part of it.
  echo "stock Hyprland: $FAILED FAIL lines are the bug (expected: more than 0)"
  exit 0
fi
[[ $FAILED == 0 ]] && echo "all PASS" || echo "$FAILED FAIL"
exit $((FAILED != 0))
