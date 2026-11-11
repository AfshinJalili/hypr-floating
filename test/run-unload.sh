#!/bin/bash
# Unloading the plugin in a nested Hyprland: it survives, stock behaviour (the bug)
# returns, and loading the plugin again brings the fix back.
# Usage: test/run-unload.sh <hypr-floating.so>
set -uo pipefail
source "$(dirname "$0")/lib.sh"
SO="${1:?usage: run-unload.sh <hypr-floating.so>}"
host_guard_start

LOG_NAME=unload session_start "$SO"
open_class B; open_class A
read -r bx by < <(spot B)
fullscreen fullscreen A
focus_class B
observe "loaded: B focused below A: drawn and clickable" B "$bx" "$by"

hyprctl plugin unload "$SO"; sleep 1.5
alive
echo "    plugins: $(hyprctl plugin list | grep -c 'Plugin ') loaded"

# Stock behaviour: raising A leaves B drawn over it, but the click goes to A.
click 40 $((H - 40)) >/dev/null
d="$(drawn "$bx" "$by")"; c="$(click "$bx" "$by")"
if [[ $d == B && $c == A ]]; then echo "PASS: unloaded: stock behaviour is back (drawn=$d clicked=$c)"
else echo "FAIL: unloaded: expected stock drawn=B clicked=A, got drawn=$d clicked=$c"; FAILED=$((FAILED + 1)); fi
alive

hyprctl plugin load "$SO"; sleep 1
focus_class B
observe "loaded again: B focused below A: drawn and clickable" B "$bx" "$by"
alive
session_stop

host_guard_end
[[ $FAILED == 0 ]] && echo "all PASS" || echo "$FAILED FAIL"
exit $((FAILED != 0))
