# Helpers for the nested tests. Source it, then:
#   host_guard_start; session_start [plugin.so ...]; ...; session_stop; host_guard_end
# A session is a nested Hyprland (tools/nested.sh): the host session is never touched.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/.."
source "$ROOT/tools/nested.sh"
source "$ROOT/tools/pointer.sh"
POINTER="$(build_pointer)"
LOGDIR="${LOGDIR:-$HERE/logs}"; mkdir -p "$LOGDIR"

FAILED=0

# The host's focused window must be the same after the run as before it.
host_guard_start() { HOST_ACTIVE="$(hyprctl activewindow -j | jq -c '{address, class}')"; }
host_guard_end() {
  local now; now="$(hyprctl activewindow -j | jq -c '{address, class}')"
  if [[ $now == "$HOST_ACTIVE" ]]; then echo "PASS: the host's focused window did not change"
  else echo "FAIL: the host's focused window changed: $HOST_ACTIVE -> $now"; FAILED=1; fi
}

# LUA picks the config (test.lua: every window floats by rule; floating.lua: workspace 1 has the floating layout).
session_start() { # [plugin.so ...]
  NESTED_LOG="$LOGDIR/${LOG_NAME:-nested}.log" nested_start "${LUA:-$HERE/test.lua}" PLUGINS="'$*'" MODE="${MODE_RES:-preferred}" WS1_LAYOUT="${WS1_LAYOUT:-floating}" BARS="${BARS:-0}" OMARCHY_TAGS="${OMARCHY_TAGS:-1}" || exit 1
  read -r W H < <(hyprctl monitors -j | jq -r '.[0] | "\(.width) \(.height)"')
}
# The nested Hyprland must not have crashed, in the middle of the run (alive) or while it shut down.
session_stop() {
  nested_stop
  if grep -qE "Hyprland (has )?crashed|Segmentation fault|SIGSEGV|terminate called|received a fatal signal" "$LOGDIR/${LOG_NAME:-nested}.log" 2>/dev/null; then
    echo "FAIL: the nested Hyprland's log reports a crash (test/logs/${LOG_NAME:-nested}.log)"; FAILED=$((FAILED + 1))
  fi
}

run() { hyprctl eval "$1" >/dev/null; sleep "${2:-0.6}"; }

# wait_until <seconds> <command...>: poll until the command succeeds
wait_until() { local n=$(($1 * 10)); shift; while ((n-- > 0)); do "$@" && return 0; sleep 0.1; done; return 1; }
has_class() { hyprctl clients -j | jq -e --arg c "$1" 'any(.[]; .class == $c and .mapped)' >/dev/null; }
no_class() { ! has_class "$1"; }

# open <class> <colour>: a floating (or, for class T, tiled) foot window of one colour
open() {
  run "hl.dispatch(hl.dsp.exec_cmd(\"foot --app-id $1 -o colors-dark.background=$2 -o colors-light.background=$2 -o colors-dark.alpha=1 -o colors-light.alpha=1 sleep 600\"))" 0.1
  wait_until 15 has_class "$1" || echo "WARN: $1 did not open"
  sleep 0.8
}
colour() { case $1 in A) echo ff0000;; B) echo 0000ff;; C) echo 00ff00;; P) echo ff00ff;; T) echo ffff00;; esac; }
open_class() { open "$1" "$(colour "$1")"; }
focus_class() { run "hl.dispatch(hl.dsp.focus({ window = \"class:^$1\$\" }))"; }
fullscreen() { run "hl.dispatch(hl.dsp.window.fullscreen({ mode = \"$1\", window = \"class:^$2\$\" }))"; } # <mode> <class>
close_class() { run "hl.dispatch(hl.dsp.window.close({ window = \"class:^$1\$\" }))" 0.1; wait_until 10 no_class "$1" || echo "WARN: $1 did not close"; sleep 0.5; }
focused() { hyprctl activewindow -j | jq -r '.class // "none"'; }

# spot <class>: a point 60px inside the window's top left corner
spot() { hyprctl clients -j | jq -r --arg c "$1" '.[] | select(.class == $c) | "\(.at[0] + 60) \(.at[1] + 60)"'; }

pointer() { WAYLAND_DISPLAY="$NESTED_SOCKET" "$POINTER" "$W" "$H"; }
# A real pointer never sits exactly still. Hyprland keeps the window the pointer was last over
# as the click's target (it raises that one) until the pointer moves, so approach the point.
click() { printf 'move %d %d\nwait 80\nmove %d %d\nwait 80\ndown\nwait 60\nup\n' "$(($1 + 3))" "$(($2 + 3))" "$1" "$2" | pointer; sleep 0.5; focused; }

# drawn <x> <y>: the class whose colour is on screen there
drawn() {
  local hex; hex="$(WAYLAND_DISPLAY="$NESTED_SOCKET" grim -g "$1,$2 1x1" -t ppm - | tail -c3 | od -An -tx1 | tr -d " \n")"
  case $hex in ff0000) echo A;; 0000ff) echo B;; 00ff00) echo C;; ff00ff) echo P;; ffff00) echo T;; *) echo "?$hex";; esac
}

# observe <what> <expected class> <x> <y>: the window drawn at the point and the one a
# click there reaches must both be the expected one. Prints PASS/FAIL.
observe() {
  local what="$1" want="$2" d c
  d="$(drawn "$3" "$4")"; c="$(click "$3" "$4")"
  if [[ $d == "$want" && $c == "$want" ]]; then echo "PASS: $what (drawn=$d clicked=$c)"
  else echo "FAIL: $what: expected $want, drawn=$d clicked=$c"; FAILED=$((FAILED + 1)); fi
}

# flags: the stacking order and what Hyprland allows over full screen, for the log
flags() { echo "    stack(bottom->top)=$(hyprctl clients -j | jq -c '[.[] | "\(.class):over=\(.allowedOverFullscreen)"]') focused=$(focused)"; }
alive() { nested_alive && echo "PASS: the nested Hyprland is alive" || { echo "FAIL: the nested Hyprland crashed"; FAILED=1; }; }

# --- windows and workspaces, as hyprctl reports them
win() { hyprctl clients -j | jq -c --arg c "$1" '.[] | select(.class == $c)'; }
geom() { win "$1" | jq -r '"\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"'; }
workspace_of() { win "$1" | jq -r '.workspace.id'; }
layout_of() { hyprctl workspaces -j | jq -r --arg id "$1" '.[] | select((.id | tostring) == $id) | .tiledLayout'; }
# desc <class>: floating or tiled, then what marks it: claimed (the layout floated it, the plugin's own
# tag), wstag (omarchy-floating-workspace), ftag (omarchy-mode-floated)
desc() {
  win "$1" | jq -r '[(if .floating then "floating" else "tiled" end),
    (.tags | map(select(. == "hypr-floating-claimed") | "claimed")[]),
    (.tags | map(select(. == "omarchy-floating-workspace") | "wstag")[]),
    (.tags | map(select(. == "omarchy-mode-floated") | "ftag")[])] | join(" ")'
}
CLAIMED="floating claimed wstag ftag"   # floated by the layout
ALONE="floating wstag"                  # floating on its own on a floating workspace
TILED_HERE="tiled wstag"                # kept tiled by the user on a floating workspace

# expect <what> <actual> <expected>: PASS/FAIL
expect() {
  if [[ $2 == "$3" ]]; then echo "PASS: $1 ($2)"
  else echo "FAIL: $1: expected \"$3\", got \"$2\""; FAILED=$((FAILED + 1)); fi
}
expect_ok() { if "${@:2}"; then echo "PASS: $1"; else echo "FAIL: $1"; FAILED=$((FAILED + 1)); fi; }   # expect_ok <what> <cmd...>
expect_not() { if ! "${@:2}"; then echo "PASS: $1"; else echo "FAIL: $1"; FAILED=$((FAILED + 1)); fi; } # expect_not <what> <cmd...>
# expect_desc <class> <expected desc> [what]
expect_desc() { expect "${3:-$1}" "$(desc "$1")" "$2"; }

float_off() { run "hl.dispatch(hl.dsp.window.float({ action = \"off\", window = \"class:^$1\$\" }))" "${2:-1}"; }
float_on() { run "hl.dispatch(hl.dsp.window.float({ action = \"on\", window = \"class:^$1\$\" }))" "${2:-1}"; }
move_to() { run "hl.dispatch(hl.dsp.window.move({ workspace = \"$2\", follow = false, window = \"class:^$1\$\" }))" 1.2; } # <class> <workspace>
layout() { run "hl.workspace_rule({ workspace = \"$1\", layout = \"$2\" })" 1.5; } # <workspace> <dwindle|floating>
workspace() { run "hl.dispatch(hl.dsp.focus({ workspace = \"$1\" }))" 0.6; }

# drag_with <button> <x> <y> <dx> <dy>: press the button at x y, move by dx dy in steps, release
drag_with() {
  local b=$1 x=$2 y=$3 dx=$4 dy=$5
  printf 'move %d %d\nwait 80\nmove %d %d\nwait 80\ndown %d\nwait 80\nmove %d %d\nwait 80\nmove %d %d\nwait 80\nmove %d %d\nwait 80\nup %d\n' \
    $((x + 3)) $((y + 3)) "$x" "$y" "$b" $((x + dx / 3)) $((y + dy / 3)) $((x + 2 * dx / 3)) $((y + 2 * dy / 3)) $((x + dx)) $((y + dy)) "$b" | pointer
  sleep 0.6
}
