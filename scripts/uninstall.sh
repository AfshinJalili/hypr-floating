#!/bin/bash
# Remove what scripts/install.sh installed. The running Hyprland keeps the plugin it has
# until the next login; nothing is unloaded from it.
set -euo pipefail

DEST="${HYPR_FLOATING_DEST:-$HOME/.local/lib/hypr-floating}"
rm -f "$DEST/hypr-floating.so"
rmdir "$DEST" 2>/dev/null || true
echo "hypr-floating: removed $DEST/hypr-floating.so"
echo "hypr-floating: take the hl.plugin.load line out of hyprland.lua, or Hyprland logs an error for the missing file"
