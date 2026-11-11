# Build the virtual pointer test helper (pointer.c) once and print its path.
# Source it and call build_pointer; it is cached in ~/.cache/hypr-floating.
build_pointer() {
  local src out
  src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  out="$HOME/.cache/hypr-floating/pointer"
  mkdir -p "$out"
  if [[ ! -x $out/pointer || $src/pointer.c -nt $out/pointer ]]; then
    wayland-scanner client-header "$src/wlr-virtual-pointer-unstable-v1.xml" "$out/pointer-protocol.h"
    wayland-scanner private-code "$src/wlr-virtual-pointer-unstable-v1.xml" "$out/pointer-protocol.c"
    cc "$src/pointer.c" "$out/pointer-protocol.c" -I"$out" -lwayland-client -o "$out/pointer"
  fi
  echo "$out/pointer"
}
