#!/bin/bash
# Print the commit of this repository to build for the Hyprland that is installed: the one
# hyprpm.toml (on main) pins for its commit, otherwise main, as hyprpm chooses. Used by
# scripts/install.sh and by the PKGBUILD, so the choice lives here only.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
commit=$(Hyprland --version | sed -n 's/.* at commit \([0-9a-f]\{40\}\).*/\1/p' | head -1)
[[ -n $commit ]] || { echo "hypr-floating: cannot read the installed Hyprland's commit" >&2; exit 1; }

manifest=main
git -C "$REPO" rev-parse -q --verify origin/main >/dev/null && manifest=origin/main
pin=$(git -C "$REPO" show "$manifest:hyprpm.toml" | sed -n "s/.*\"$commit\", *\"\([0-9a-f]\{7,40\}\)\".*/\1/p" | head -1)
git -C "$REPO" rev-parse --verify "${pin:-$manifest}^{commit}"
