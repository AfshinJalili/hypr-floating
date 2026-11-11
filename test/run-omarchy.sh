#!/bin/bash
# The floating layout on Omarchy, in a nested Hyprland that loads Omarchy's own Lua (helpers,
# looks, window rules, saved workspace layouts) but not its autostart, bindings or services.
# lua/omarchy.lua makes Omarchy's floating mode the plugin's layout; Omarchy's own scripts (the
# layout toggle, the bar's reading of the layout, minimizing) run against the nested session,
# with XDG_STATE_HOME in a scratch directory and the bar and notifications stubbed out.
# Usage: test/run-omarchy.sh <hypr-floating.so> [mission-control.so] [scenario ...]
#   scenarios: lua cycle moves reload (default: all)
set -uo pipefail
source "$(dirname "$0")/lib.sh"
SO="$(realpath "${1:?usage: run-omarchy.sh <hypr-floating.so> [mission-control.so] [scenario ...]}")"; shift
MC_SO="$HOME/.local/lib/omarchy-macos/omarchy-macos-mission-control.so"
[[ ${1:-} == *.so ]] && { MC_SO="$(realpath "$1")"; shift; }
export LUA="$HERE/omarchy.lua"
[[ -d ${OMARCHY_PATH:-/usr/share/omarchy}/default/hypr ]] || { echo "SKIP: Omarchy is not installed"; exit 0; }
command -v omarchy-hyprland-workspace-layout-toggle >/dev/null || { echo "SKIP: Omarchy's scripts are not on PATH"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"; nested_stop' EXIT
host_guard_start

# Omarchy's scripts refresh the bar and the dock and send notifications: on the host's desktop,
# which a test must not touch. These stand in for them.
mkdir -p "$TMP/bin"
for stub in omarchy-shell omarchy-notification-send; do printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/$stub"; chmod +x "$TMP/bin/$stub"; done
export PATH="$TMP/bin:$PATH"

# The user's lines of hyprland.lua: a window rule that floats class F (as a dialog floats), and the integration.
cat >"$TMP/user.lua" <<EOF
hl.window_rule({ match = { class = "^F" }, float = true })
dofile("$ROOT/lua/omarchy.lua")
EOF

# ... and the same with input:follow_mouse left to the user, as this user's hyprland.lua wants it
cat >"$TMP/user-hover.lua" <<EOF
hl.window_rule({ match = { class = "^F" }, float = true })
loadfile("$ROOT/lua/omarchy.lua")({ follow_mouse = false })
EOF

# state <name>: a saved-layouts directory as this user has it: workspace 1 dwindle, the default floating
state() {
  mkdir -p "$TMP/$1/omarchy/workspace-layouts"
  echo 'o.workspace_mode({ workspace = "1", mode = "dwindle" })' >"$TMP/$1/omarchy/workspace-layouts/1.lua"
  echo 'o.workspace_mode({ default = "floating" })' >"$TMP/$1/omarchy/workspace-layouts/default.lua"
}
start() { # <log name> <state name> <user lua file or empty> [plugin.so ...]
  STATE="$TMP/$2"
  LOG_NAME=$1 SESSION_ENV="XDG_STATE_HOME='$STATE' USER_LUA='${3:-}'" session_start "$SO" "${@:4}"
  expect "no config errors" "$(hyprctl configerrors | tr -d '[:space:]')" ""
}
omarchy() { XDG_STATE_HOME="$STATE" "$@" 2>/dev/null; } # one of Omarchy's scripts, against the nested session
toggle() { omarchy omarchy-hyprland-workspace-layout-toggle >/dev/null; sleep 1.5; }
bar_mode() { omarchy omarchy-hyprland-workspace-layout-current "$@"; }
follow_mouse() { hyprctl getoption input:follow_mouse -j | jq -r .int; }
omarchy_tagged() { hyprctl clients -j | jq '[.[].tags[] | select(startswith("omarchy-mode") or startswith("omarchy-floating"))] | length'; }

# titlebar <class>: Omarchy's titlebar is drawn over the window's top edge, in its bar colour
BAR_HEX=
titlebar() {
  [[ -n $BAR_HEX ]] || BAR_HEX="$(hyprctl getoption plugin:hyprbars:bar_color -j | jq -r '.int // empty' | awk '{ printf "%06x", $1 % 16777216 }')"
  read -r x y w h < <(geom "$1")
  local px hex
  for px in $((x + w / 3)) $((x + w / 2)) $((x + 2 * w / 3)); do
    hex="$(WAYLAND_DISPLAY="$NESTED_SOCKET" grim -g "$px,$((y - 15)) 1x1" -t ppm - | tail -c3 | od -An -tx1 | tr -d " \n")"
    [[ $hex == "$BAR_HEX" ]] && return 0
  done
  return 1
}

scenario_lua() {
  echo "== lua: Omarchy's own floating mode, without lua/omarchy.lua, the plugin loaded: the plugin stays out of the way"
  state lua
  start omarchy-lua lua ""
  workspace 2; open_class A
  expect "Omarchy floats A with its own tags" "$(win A | jq -r '[(.floating | tostring), (.tags[] | select(startswith("omarchy-") and (endswith("*") | not)))] | join(" ")')" "true omarchy-floating-workspace omarchy-mode-floated"
  workspace 1; open_class C
  expect_desc C tiled "workspace 1 is dwindle: C tiles"
  hyprctl reload >/dev/null; sleep 2
  expect "after a reload: A still floats" "$(win A | jq -r .floating)" true
  alive; session_stop
}

# expect_all <what> <expected desc> <class ...>
expect_all() { local c; for c in "${@:3}"; do expect_desc "$c" "$2" "$1: $c"; done; }

scenario_cycle() {
  echo "== cycle: Omarchy's layout toggle on a floating workspace, every window together, one press each"
  state cycle
  start omarchy-cycle cycle "$TMP/user.lua"
  expect "workspace 1 keeps the layout Omarchy saved" "$(layout_of 1)" dwindle
  workspace 2
  expect "workspace 2 has the plugin's layout (Omarchy's default)" "$(layout_of 2)" floating
  expect "the bar reads workspace 2 as floating" "$(bar_mode)" floating
  expect "focus follows clicks on the floating workspace" "$(follow_mouse)" 0
  open_class A                   # floated by the layout
  expect_ok "a titlebar on A" titlebar A
  open_class B; float_off B; float_on B   # floated by hand
  open_class T; float_off T      # tiled by hand
  open_class F                   # floated by a rule, as a dialog
  open_class C                   # minimized below
  open_class P; fullscreen maximized P
  expect_all "on the floating workspace" "$FLOATS" A B F
  expect_desc T "$TILED_HERE" "T tiled by hand"
  expect "Omarchy's Lua floats nothing: no window has its tags" "$(omarchy_tagged)" 0
  focus_class C; omarchy omarchy-hyprland-window-minimize; sleep 1
  expect "Omarchy minimized C" "$(win C | jq -r .workspace.name)" special:minimized
  focus_class A

  toggle
  expect "press 1: the bar reads dwindle" "$(bar_mode)" dwindle
  expect "press 1: workspace 2 is dwindle" "$(layout_of 2)" dwindle
  expect_all "press 1, dwindle" tiled A B T
  expect_desc F floating "press 1: the rule-floated F stays floating"
  expect_desc P floating "press 1: the maximized P is left as it is"
  expect_not "press 1: no titlebar on A" titlebar A
  expect "press 1: focus follows the pointer again" "$(follow_mouse)" 1

  toggle
  expect "press 2: the bar reads scrolling" "$(bar_mode)" scrolling
  expect "press 2: workspace 2 scrolls" "$(layout_of 2)" scrolling
  expect_all "press 2, scrolling" tiled A B T
  expect_desc F floating "press 2: F stays floating"

  toggle
  expect "press 3: the bar reads floating" "$(bar_mode)" floating
  expect "press 3: workspace 2 has the plugin's layout" "$(layout_of 2)" floating
  expect_all "press 3, floating" "$FLOATS" A B T F
  expect_ok "press 3: the titlebar is back on A" titlebar A
  expect "press 3: focus follows clicks" "$(follow_mouse)" 0
  expect "press 3: the saved file is gone, workspace 2 follows the default" "$(ls "$STATE/omarchy/workspace-layouts" | tr '\n' ' ')" "1.lua default.lua "

  toggle
  expect "press 4: the bar reads dwindle" "$(bar_mode)" dwindle
  expect_all "press 4, dwindle" tiled A B T
  expect_desc F floating "press 4: F stays floating"
  expect_not "press 4: no titlebar on A" titlebar A

  fullscreen maximized P
  expect_desc P tiled "P leaves maximized on the dwindle workspace: it tiles"
  run 'hl.dispatch(hl.dsp.window.move({ workspace = "2", window = "class:^C$" }))' 1.2   # what Omarchy's dock does
  expect_desc C tiled "C, minimized while workspace 2 floated, comes back to dwindle: it tiles"
  expect "Omarchy's Lua floats nothing: no window has its tags" "$(omarchy_tagged)" 0
  alive; session_stop
}

scenario_moves() {
  echo "== moves: a window carried between workspaces and monitors takes the destination's mode"
  state moves
  start omarchy-moves moves "$TMP/user.lua" "$MC_SO"
  hyprctl output create headless >/dev/null; sleep 2
  mon2="$(hyprctl monitors -j | jq -r '.[] | select(.name != "WAYLAND-1") | .name')"
  ws2="$(hyprctl monitors -j | jq -r --arg m "$mon2" '.[] | select(.name == $m) | .activeWorkspace.id')"
  echo "    second monitor $mon2, workspace $ws2"
  expect "the bar reads the second monitor's workspace as floating" "$(bar_mode "$ws2")" floating
  workspace 1; open_class A; open_class F
  expect_desc A tiled "A on the dwindle workspace 1"
  move_to A 3
  expect "workspace 3 is on the first monitor" "$(hyprctl workspaces -j | jq -r '.[] | select(.id == 3) | .monitor')" WAYLAND-1
  expect_desc A "$FLOATS" "dwindle 1 -> floating 3, same monitor: A floats"
  move_to A 1
  expect_desc A tiled "floating 3 -> dwindle 1: A tiles"
  move_to A "$ws2"
  expect "A is on the other monitor" "$(hyprctl clients -j | jq -r '.[] | select(.class == "A") | .monitor')" "$(hyprctl monitors -j | jq -r --arg m "$mon2" '.[] | select(.name == $m) | .id')"
  expect_desc A "$FLOATS" "dwindle 1 -> floating $ws2 on the other monitor: A floats"
  move_to A 1
  expect_desc A tiled "and back across monitors: A tiles"
  move_to F "$ws2"; move_to F 1
  expect_desc F floating "F, floated by a rule, stays floating across moves"
  alive; session_stop
}

scenario_reload() {
  echo "== reload: the user's state (default floating, workspace 1 dwindle) survives a reload; follow_mouse left alone"
  state reload
  start omarchy-reload reload "$TMP/user-hover.lua"
  workspace 2; open_class A; open_class B; float_off B
  expect "{ follow_mouse = false }: focus still follows the pointer on the floating workspace" "$(follow_mouse)" 1
  fullscreen maximized A; open_class T
  expect "a window opening on the floating workspace brings the maximized A back to its size" "$(win A | jq -r .fullscreen)" 0
  workspace 1; open_class C
  hyprctl reload >/dev/null; sleep 2
  expect "no config errors after the reload" "$(hyprctl configerrors | tr -d '[:space:]')" ""
  expect_desc A "$FLOATS" "after a reload: A floats"
  expect_desc B "$TILED_HERE" "after a reload that changes no layout: the user's tiled B stays tiled"
  expect_desc C tiled "after a reload: C on workspace 1 tiles"
  expect "the bar reads workspace 1 as dwindle" "$(bar_mode 1)" dwindle
  expect "the default reads floating" "$(omarchy omarchy-hyprland-workspace-layout-default)" floating
  expect "Omarchy's Lua floats nothing: no window has its tags" "$(omarchy_tagged)" 0
  hyprctl plugin unload "$SO" >/dev/null; sleep 1.5
  alive
  expect_desc A tiled "plugin unloaded: A tiles"
  alive; session_stop
}

SCENARIOS=("$@"); [[ ${#SCENARIOS[@]} == 0 ]] && SCENARIOS=(lua cycle moves reload)
for s in "${SCENARIOS[@]}"; do "scenario_$s"; done

host_guard_end
[[ $FAILED == 0 ]] && echo "all PASS" || echo "$FAILED FAIL"
exit $((FAILED != 0))
