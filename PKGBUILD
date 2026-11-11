# Maintainer: Afshin Jalili
#
# Builds the commit hyprpm.toml pins for the Hyprland that is installed (scripts/source-rev.sh),
# so the plugin matches it. Rebuild the package after a Hyprland upgrade: a plugin only loads
# into the Hyprland it was built for.
pkgname=hypr-floating-git
pkgver=r0.0000000
pkgrel=1
pkgdesc='Hyprland plugin: a floating workspace layout, and a floating window drawn over a full-screen one takes the clicks'
arch=(x86_64)
url='https://github.com/AfshinJalili/hypr-floating'
license=(BSD-3-Clause)
depends=('hyprland>=0.56' 'hyprland<0.58')
makedepends=(git cmake pkgconf)
source=("$pkgname::git+$url.git")
sha256sums=(SKIP)

pkgver() {
  cd "$pkgname"
  local rev
  rev=$(scripts/source-rev.sh)
  printf 'r%s.%s' "$(git rev-list --count "$rev")" "$(git rev-parse --short "$rev")"
}

prepare() {
  cd "$pkgname"
  git checkout -q "$(scripts/source-rev.sh)"
}

build() {
  cmake -S "$pkgname" -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
  cmake --build build
}

package() {
  install -Dm755 build/hypr-floating.so "$pkgdir/usr/lib/hypr-floating/hypr-floating.so"
  install -Dm644 "$pkgname/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
