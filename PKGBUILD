# Maintainer: grigio <grigio.org>
#
# Package for Cosmalia: a minimal COSMIC-based Wayland desktop (under 1 GB of
# RAM) built on cosmic-comp-traffic and Noctalia. It installs the launcher, the
# XDG session entry, the systemd user units and the optional greeter helper
# from files/ in this repo. Nothing is downloaded — the repo is the source
# tree, so $startdir is used in package() and there is no source array.
#
# The package does NOT edit /etc/greetd and does NOT make Cosmalia the default
# session; `sudo cosmalia-session-default` does that explicitly.
#
#   makepkg -f       # -> cosmalia-session-<pkgver>-<pkgrel>-any.pkg.tar.zst
#   makepkg -fi      # ... and install it
#
# pkgver comes from the nearest v* tag and pkgrel from the number of commits
# that touched packaged files, so a local build matches the CI-built package.
# Both can be overridden, as .github/workflows/arch-package.yml does:
#
#   SESSION_VERSION=1.2.2 SESSION_PKGREL=9 makepkg -f

pkgname=cosmalia-session
pkgver=${SESSION_VERSION:-$(git -C "${startdir:-$PWD}" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}
pkgver=${pkgver:-1.2.2}
_pkgrel=$(git -C "${startdir:-$PWD}" rev-list --count HEAD -- \
  PKGBUILD cosmalia-session.install files README.md LICENSE \
  scripts/set-default-greetd.sh 2>/dev/null || true)
pkgrel=${SESSION_PKGREL:-${_pkgrel:-1}}
(( pkgrel >= 1 )) || pkgrel=1

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
  # The repo layout mirrors /, and git preserves the executable bit on the
  # launcher. Copying the tree as-is means a file added under files/ cannot be
  # forgotten here.
  cp -a "$startdir/files/." "$pkgdir/"

  # The package installs the helper under a name that makes sense once it is
  # on $PATH for an admin.
  install -Dm755 "$startdir/scripts/set-default-greetd.sh" \
    "$pkgdir/usr/bin/cosmalia-session-default"

  install -Dm644 "$startdir/README.md" "$pkgdir/usr/share/doc/$pkgname/README.md"
  install -Dm644 "$startdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
