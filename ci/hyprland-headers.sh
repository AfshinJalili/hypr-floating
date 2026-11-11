#!/bin/bash
# Install the headers of one Hyprland release into PREFIX, with the exact
# hyprwm libraries that release pins in its flake.lock, so the plugin can be
# compiled against any Hyprland version regardless of what the distro ships.
#
# Usage: ci/hyprland-headers.sh <hyprland-tag> <prefix>
# Then:  PKG_CONFIG_PATH=<prefix>/lib/pkgconfig:<prefix>/share/pkgconfig cmake ...
#
# Needs git, jq, cmake, meson, ninja, a C++ compiler and Hyprland's build
# dependencies (on Arch: the packages ci/arch-deps.txt lists).
set -euo pipefail

TAG="$1"
PREFIX="$(realpath -m "$2")"
WORK="${HYPRBARS_CI_WORK:-$(mktemp -d)}"
JOBS="$(nproc)"

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export CMAKE_PREFIX_PATH="$PREFIX"
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:${LD_LIBRARY_PATH:-}"
mkdir -p "$PREFIX" "$WORK"

git clone -q --depth 1 --branch "$TAG" --recurse-submodules --shallow-submodules \
  https://github.com/hyprwm/Hyprland "$WORK/hyprland"

# The dependency a Hyprland release was built and tested with, by flake input.
pinned_rev() {
  jq -r --arg name "$1" '.nodes[$name].locked.rev // empty' "$WORK/hyprland/flake.lock"
}

# Clone one hyprwm library at the commit Hyprland pins and install it into
# PREFIX. Libraries are built in dependency order.
build_dep() {
  local name="$1" rev
  rev="$(pinned_rev "$name")"
  [[ -n $rev ]] || { echo "flake.lock pins no $name" >&2; exit 1; }
  echo "== $name $rev"
  git init -q "$WORK/$name"
  git -C "$WORK/$name" fetch -q --depth 1 "https://github.com/hyprwm/$name" "$rev"
  git -C "$WORK/$name" checkout -q FETCH_HEAD
  if [[ -f "$WORK/$name/CMakeLists.txt" ]]; then
    cmake -S "$WORK/$name" -B "$WORK/$name/build" -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_TESTING=OFF >/dev/null
    cmake --build "$WORK/$name/build" -j"$JOBS" >/dev/null
    cmake --install "$WORK/$name/build" >/dev/null
  else
    meson setup "$WORK/$name/build" "$WORK/$name" --prefix="$PREFIX" --libdir=lib >/dev/null
    meson install -C "$WORK/$name/build" >/dev/null
  fi
}

for dep in hyprwayland-scanner hyprutils hyprlang hyprland-protocols hyprgraphics hyprcursor aquamarine; do
  build_dep "$dep"
done

echo "== Hyprland $TAG headers"
cmake -S "$WORK/hyprland" -B "$WORK/hyprland/build" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" >/dev/null
make -C "$WORK/hyprland" installheaders PREFIX="$PREFIX" >/dev/null
pkg-config --modversion hyprland
