# Start a nested Hyprland for a test without touching the desktop you work on.
# Source it, then: nested_start <config.lua> [VAR=value ...]
# It opens the nested window, and any output it adds later, silently on an empty
# workspace (NESTED_WORKSPACE, default 9), so focus and the active workspace stay
# where they are, and refuses to run when that workspace has windows. Afterwards HYPRLAND_INSTANCE_SIGNATURE
# points hyprctl at the nested session, $NESTED_SOCKET is its Wayland display
# and $NESTED_PID its process; nested_stop ends it (also run on exit) and
# points hyprctl back at the host.

nested_start() {
  local config="$1"; shift
  local workspace="${NESTED_WORKSPACE:-9}"
  local host="$HYPRLAND_INSTANCE_SIGNATURE"
  local windows
  windows=$(hyprctl workspaces -j | jq --arg ws "$workspace" '[.[] | select(.name == $ws) | .windows] | add // 0')
  if [[ $windows != 0 ]]; then
    echo "workspace $workspace has windows; pick an empty one with NESTED_WORKSPACE" >&2
    return 1
  fi
  local before
  before=$(hyprctl instances -j | jq -r '.[].instance')
  # Every window a nested session opens (more with `hyprctl output create`) has the
  # class aquamarine; keep them all there. render_unfocused keeps frames coming to
  # them though the workspace is out of sight; without frames a nested session
  # stalls on its next mode change or screenshot. The rule lasts until the host
  # reloads its config.
  hyprctl eval "hl.window_rule({ match = { class = \"^aquamarine\$\" }, workspace = \"$workspace silent\", render_unfocused = true })" >/dev/null
  local log="${NESTED_LOG:-/dev/null}"
  local cmd="env $* Hyprland -c '$config' >'$log' 2>&1"
  hyprctl eval "hl.exec_cmd([[$cmd]], { workspace = \"$workspace silent\", render_unfocused = true })" >/dev/null
  # The new instance, as Hyprland lists it: socket names get reused, so look
  # for an instance that was not there before.
  local i instance
  NESTED_SIG= NESTED_SOCKET= NESTED_PID=
  for i in $(seq 80); do
    sleep 0.25
    instance=$(hyprctl instances -j | jq -c --arg before "$before" '[.[] | select(.instance as $i | ($before | split("\n") | index($i)) == null)] | last // empty')
    if [[ -n $instance ]]; then
      NESTED_SIG=$(jq -r .instance <<<"$instance")
      NESTED_SOCKET=$(jq -r .wl_socket <<<"$instance")
      NESTED_PID=$(jq -r .pid <<<"$instance")
      [[ -S $XDG_RUNTIME_DIR/hypr/$NESTED_SIG/.socket.sock && -S $XDG_RUNTIME_DIR/$NESTED_SOCKET ]] && break
    fi
  done
  # Never fall back to the host: a wrong socket would drive the real desktop.
  if [[ -z $NESTED_SOCKET || $NESTED_SOCKET == "$WAYLAND_DISPLAY" || -z $NESTED_SIG || $NESTED_SIG == "$host" || -z $NESTED_PID ]]; then
    echo "nested Hyprland did not start" >&2
    nested_stop
    return 1
  fi
  NESTED_HOST_SIG="$host"
  export HYPRLAND_INSTANCE_SIGNATURE="$NESTED_SIG"
  trap nested_stop EXIT
  sleep 1.5
}

nested_alive() { [[ -n ${NESTED_PID:-} ]] && kill -0 "$NESTED_PID" 2>/dev/null; }

nested_stop() {
  if [[ -n ${NESTED_PID:-} ]]; then
    kill "$NESTED_PID" 2>/dev/null || true
    local i
    for i in $(seq 40); do
      kill -0 "$NESTED_PID" 2>/dev/null || break
      sleep 0.25
    done
    kill -9 "$NESTED_PID" 2>/dev/null || true
  fi
  NESTED_PID=
  # Point hyprctl back at the host.
  [[ -n ${NESTED_HOST_SIG:-} ]] && export HYPRLAND_INSTANCE_SIGNATURE="$NESTED_HOST_SIG"
  return 0
}
