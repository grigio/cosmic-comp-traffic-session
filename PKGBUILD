# Maintainer: grigio <grigio.org>
#
# Package for the cosmic-comp-traffic session: the launcher, the XDG session
# entry and the systemd user target, all read from files/ in this repo.
# Nothing is downloaded — the repo is the source tree, so $startdir is used in
# package() and there is no source array.
#
#   makepkg -f       # -> cosmic-comp-traffic-session-<pkgver>-<pkgrel>-any.pkg.tar.zst
#   makepkg -fi      # ... and install it
#
# Bump pkgver when the files change, or pkgrel for a packaging-only change.
# Releases are built by .github/workflows/arch-package.yml on every v* tag,
# which injects the tag as pkgver and the packaging commit count as pkgrel:
#
#   SESSION_VERSION=1.2.0 SESSION_PKGREL=4 makepkg -f

pkgname=cosmic-comp-traffic-session
pkgver=${SESSION_VERSION:-1.1.0}
pkgrel=${SESSION_PKGREL:-1}
pkgdesc='Minimal COSMIC session: cosmic-comp-traffic as the compositor, Noctalia as the shell'
arch=(any)
url='https://github.com/grigio/cosmic-comp-traffic-session'
license=(MIT)
# cosmic-comp is provided by cosmic-comp-traffic (it conflicts with the stock
# package), so either build of the compositor satisfies this.
depends=(
  cosmic-comp
  noctalia
)
optdepends=(
  'xdg-desktop-portal-cosmic: screenshots, screencast, file chooser'
  'gnome-keyring: freedesktop Secret Service (COSMIC ships no keyring)'
  'iproute2: find the compositor socket with ss(8) instead of a directory scan'
)
install=cosmic-comp-traffic-session.install
source=()
sha256sums=()

package() {
  install -Dm755 "$startdir/files/usr/local/bin/cosmic-comp-traffic-session" \
    "$pkgdir/usr/local/bin/cosmic-comp-traffic-session"
  install -Dm644 "$startdir/files/usr/share/wayland-sessions/cosmic-comp-traffic.desktop" \
    "$pkgdir/usr/share/wayland-sessions/cosmic-comp-traffic.desktop"
  install -Dm644 "$startdir/files/usr/lib/systemd/user/cosmic-comp-traffic-session.target" \
    "$pkgdir/usr/lib/systemd/user/cosmic-comp-traffic-session.target"

  # Same script as scripts/set-default-greetd.sh, under a name that makes sense
  # once it is on $PATH for an admin.
  install -Dm755 "$startdir/scripts/set-default-greetd.sh" \
    "$pkgdir/usr/bin/cosmic-comp-traffic-session-default"

  install -Dm644 "$startdir/README.md" "$pkgdir/usr/share/doc/$pkgname/README.md"
  install -Dm644 "$startdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
