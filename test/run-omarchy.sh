#!/bin/bash
# The floating layout next to Omarchy's own Lua (its saved workspace layouts, its floating
# mode) in a nested Hyprland, and the config change that switches Omarchy's floating mode
# to this layout (examples/omarchy.lua). The nested Hyprland loads only Omarchy's helpers,
# looks, window rules and workspace layouts: not its autostart, bindings or services.
# Usage: test/run-omarchy.sh <hypr-floating.so> [scenario ...]
#   scenarios: lua both conflict switched (default: all)
set -uo pipefail
source "$(dirname "$0")/lib.sh"
SO="$(realpath "${1:?usage: run-omarchy.sh <hypr-floating.so> [scenario ...]}")"; shift
export LUA="$HERE/omarchy.lua"
[[ -d ${OMARCHY_PATH:-/usr/share/omarchy}/default/hypr ]] || { echo "SKIP: Omarchy is not installed"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"; nested_stop' EXIT
host_guard_start

# state <name> [default]: a saved-layouts directory as Omarchy writes it: workspace 1 is dwindle;
# a default of floating only when asked for (the setup this user has).
state() {
  mkdir -p "$TMP/$1/omarchy/workspace-layouts"
  echo 'o.workspace_mode({ workspace = "1", mode = "dwindle" })' >"$TMP/$1/omarchy/workspace-layouts/1.lua"
  [[ ${2:-} == floating ]] && echo 'o.workspace_mode({ default = "floating" })' >"$TMP/$1/omarchy/workspace-layouts/default.lua"
}
start() { # <log name> <state name> <user lua file or empty>
  LOG_NAME=$1 SESSION_ENV="XDG_STATE_HOME='$TMP/$2' USER_LUA='${3:-}'" session_start "$SO"
  expect "no config errors" "$(hyprctl configerrors | tr -d '[:space:]')" ""
}
note() { echo "NOTE: $*"; }

scenario_lua() {
  echo "== lua: Omarchy's floating mode alone, the plugin loaded: Omarchy floats, the plugin stays out of the way"
  state lua floating
  start omarchy-lua lua ""
  workspace 2; open_class A
  expect_desc A "floating wstag ftag" "Omarchy floats A with its own tags"
  workspace 1; open_class C
  expect_desc C tiled "workspace 1 is dwindle: C tiles"
  hyprctl reload >/dev/null; sleep 2
  expect_desc A "floating wstag ftag" "after a reload: A still floats"
  alive; session_stop
}

scenario_both() {
  echo "== both: Omarchy's floating mode and the layout on the same workspaces"
  state both floating
  echo 'hl.config({ general = { layout = "floating" } })' >"$TMP/both.lua"
  start omarchy-both both "$TMP/both.lua"
  workspace 2; open_class A
  expect "workspace 2 has the layout" "$(layout_of 2)" floating
  expect_desc A "floating wstag ftag" "A floats, with Omarchy's tags, and Omarchy's claim"
  note "both active: Omarchy floats the window as it opens, so the layout never claims it; the saved mode is what tiles it again"
  run 'o.workspace_mode({ workspace = "2", mode = "dwindle" })' 1.5
  expect_desc A tiled "Omarchy's own command for workspace 2 (to dwindle) tiles A, the layout having left its tags alone"
  alive; session_stop
}

scenario_conflict() {
  echo "== conflict: Omarchy's Lua knows a mode (workspace 1) but does not float workspace 2; the layout does"
  state conflict
  echo 'hl.config({ general = { layout = "floating" } })' >"$TMP/conflict.lua"
  start omarchy-conflict conflict "$TMP/conflict.lua"
  workspace 2; open_class A
  expect "workspace 2 has the layout" "$(layout_of 2)" floating
  note "with omarchy_tags on, A is: $(desc A). Omarchy's watcher tiles a window carrying omarchy-mode-floated that sits on a workspace its modes do not float, and strips omarchy-floating-workspace"
  expect "known conflict: Omarchy tiles the window the layout floated (the reason examples/omarchy.lua sets omarchy_tags = 0)" "$(win A | jq -r .floating)" false
  alive; session_stop
}

scenario_switched() {
  echo "== switched: examples/omarchy.lua, with the saved default floating mode deleted"
  state switched
  start omarchy-switched switched "$ROOT/examples/omarchy.lua"
  expect "workspace 1 keeps the layout Omarchy saved" "$(layout_of 1)" dwindle
  workspace 2; open_class A; open_class B
  expect "workspace 2 has the layout" "$(layout_of 2)" floating
  expect "Omarchy's bar reads workspace 2 as floating" "$(XDG_STATE_HOME="$TMP/switched" omarchy-hyprland-workspace-layout-current 2)" floating
  expect "Omarchy's bar reads workspace 1 as dwindle" "$(XDG_STATE_HOME="$TMP/switched" omarchy-hyprland-workspace-layout-current 1)" dwindle
  expect "Omarchy's default layout is floating" "$(XDG_STATE_HOME="$TMP/switched" omarchy-hyprland-workspace-layout-default)" floating
  expect_desc A "floating claimed" "A floated by the layout"; expect_desc B "floating claimed" "B floated by the layout"
  expect "A carries the layout's own workspace tag, which the titlebars and opacity follow" "$(win A | jq -r '.tags | index("hypr-floating-workspace") != null')" true
  expect "no window carries an omarchy- tag from the plugin" "$(hyprctl clients -j | jq '[.[].tags[] | select(startswith("omarchy-"))] | length')" 0
  expect "a titlebar on A (Omarchy's titlebars, following the layout's tag)" "$(hyprctl decorations class:A | grep -c Hyprbar)" 1
  workspace 1; open_class C
  expect_desc C tiled "workspace 1: C tiles"
  workspace 2
  hyprctl reload >/dev/null; sleep 2
  expect_desc A "floating claimed" "after a reload: A"; expect_desc B "floating claimed" "after a reload: B"
  float_off A
  expect_desc A tiled "togglefloating sticks"
  layout 2 dwindle
  expect_desc B tiled "Omarchy's layout command on workspace 2 (to dwindle): B tiles"
  layout 2 floating
  expect_desc B "floating claimed" "and back: B floats"
  hyprctl plugin unload "$SO" >/dev/null; sleep 1.5
  alive
  expect_desc B tiled "plugin unloaded: B tiles"
  alive; session_stop
}

SCENARIOS=("$@"); [[ ${#SCENARIOS[@]} == 0 ]] && SCENARIOS=(lua both conflict switched)
for s in "${SCENARIOS[@]}"; do "scenario_$s"; done

host_guard_end
[[ $FAILED == 0 ]] && echo "all PASS" || echo "$FAILED FAIL"
exit $((FAILED != 0))
