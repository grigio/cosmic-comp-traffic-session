# Maintainer: grigio <grigio.org>
#
# Package for Cosmalia: a minimal COSMIC-based Wayland desktop (under 1 GB of
# RAM) built on cosmic-comp-traffic and Noctalia. It installs the launcher, the
# XDG session entry and the systemd user target from files/ in this repo.
# Nothing is downloaded — the repo is the source tree, so $startdir is used in
# package() and there is no source array.
#
#   makepkg -f       # -> cosmalia-session-<pkgver>-<pkgrel>-any.pkg.tar.zst
#   makepkg -fi      # ... and install it
#
# Bump pkgver when the files change, or pkgrel for a packaging-only change.
# Releases are built by .github/workflows/arch-package.yml on every v* tag,
# which injects the tag as pkgver and the packaging commit count as pkgrel:
#
#   SESSION_VERSION=1.2.0 SESSION_PKGREL=4 makepkg -f

pkgname=cosmalia-session
pkgver=${SESSION_VERSION:-1.2.0}
pkgrel=${SESSION_PKGREL:-1}
pkgdesc='Cosmalia: minimal COSMIC desktop with cosmic-comp-traffic and Noctalia'
arch=(any)
url='https://github.com/grigio/cosmalia-session'
license=(MIT)
# cosmic-comp is provided by cosmic-comp-traffic (it conflicts with the stock
# package), so either build of the compositor satisfies this.
#
# cosmic-settings-daemon is what serves the cosmic-config watchers (theme,
# appearance, keybind changes) over D-Bus; without it nothing reloads live.
# polkit ships polkit-agent-helper-1, the helper used by Noctalia's built-in
# polkit agent. gnome-keyring provides the Secret Service browsers expect.
# wireplumber is the PipeWire session manager; pipewire-pulse only requires the
# virtual pipewire-session-manager, so make the choice explicit.
depends=(
  cosmic-comp
  noctalia
  cosmic-settings
  cosmic-settings-daemon
  cosmic-screenshot
  xdg-desktop-portal-cosmic
  polkit
  gnome-keyring
  wireplumber
)
optdepends=(
  'polkit-gnome: fallback polkit agent when Noctalia built-in agent is disabled'
  'iproute2: find the compositor socket with ss(8) instead of a directory scan'
)
# Renamed from cosmic-comp-traffic-session; let pacman replace the old package
# instead of leaving two sessions with the same files on disk.
provides=(cosmic-comp-traffic-session)
replaces=(cosmic-comp-traffic-session)
conflicts=(cosmic-comp-traffic-session)
install=cosmalia-session.install
source=()
sha256sums=()

package() {
  install -Dm755 "$startdir/files/usr/bin/cosmalia-session" \
    "$pkgdir/usr/bin/cosmalia-session"
  install -Dm644 "$startdir/files/usr/share/wayland-sessions/cosmalia.desktop" \
    "$pkgdir/usr/share/wayland-sessions/cosmalia.desktop"
  install -Dm644 "$startdir/files/usr/lib/systemd/user/cosmalia-session.target" \
    "$pkgdir/usr/lib/systemd/user/cosmalia-session.target"

  # Same script as scripts/set-default-greetd.sh, under a name that makes sense
  # once it is on $PATH for an admin.
  install -Dm755 "$startdir/scripts/set-default-greetd.sh" \
    "$pkgdir/usr/bin/cosmalia-session-default"

  install -Dm644 "$startdir/README.md" "$pkgdir/usr/share/doc/$pkgname/README.md"
  install -Dm644 "$startdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
