#!/bin/bash
# hypr-floating next to other plugins in one nested Hyprland: nothing crashes and the
# fix still holds. Mission Control is opened and closed over a full-screen window.
# Usage: test/run-with-plugins.sh <hypr-floating.so> [other-plugin.so ...]
set -uo pipefail
source "$(dirname "$0")/lib.sh"
SO="${1:?usage: run-with-plugins.sh <hypr-floating.so> [other-plugin.so ...]}"
host_guard_start

LOG_NAME=with-plugins session_start "$@"
echo "    plugins: $(hyprctl plugin list | grep 'Plugin ' | tr '\n' ' ')"
open_class B; open_class A
read -r bx by < <(spot B)
fullscreen fullscreen A
focus_class B
observe "a: B focused below A: drawn and clickable" B "$bx" "$by"
observe "b1: click A beside B" A 40 $((H - 40))
observe "b2: B is behind A now: A drawn and clickable at B's spot" A "$bx" "$by"
if [[ -n $(hyprctl commands 2>/dev/null | grep -i mission_control) || $* == *mission-control* ]]; then
  hyprctl mission_control >/dev/null; sleep 1.5
  hyprctl mission_control >/dev/null; sleep 1.5
  echo "    mission control opened and closed"
fi
focus_class B
observe "c: B focused again, after Mission Control: drawn and clickable" B "$bx" "$by"
fullscreen fullscreen A
fullscreen fullscreen A
close_class B
alive
session_stop

host_guard_end
[[ $FAILED == 0 ]] && echo "all PASS" || echo "$FAILED FAIL"
exit $((FAILED != 0))
