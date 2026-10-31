#!/usr/bin/env bash
# Install the Cosmalia session: copies files/ onto /, so the repo layout is
# the install layout. This does NOT make Cosmalia the greeter default.
#
#   ./scripts/install.sh             # session files only
#   ./scripts/install.sh --default   # ... and preselect it in gtkgreet
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "run this as your user, not root: it uses sudo for /usr and must" >&2
    echo "reload the current user's systemd manager." >&2
    exit 1
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
src="$root/files"

case ${1:-} in
    ''|--default) ;;
    -h|--help)
        sed -n '2,6p' "$0"
        exit 0
        ;;
    *)
        echo "usage: $0 [--default]" >&2
        exit 1
        ;;
esac

# If the files are already package-managed, copying over them only makes pacman's
# file list lie. Rebuild the package instead.
if pacman -Qq cosmalia-session >/dev/null 2>&1; then
    echo "cosmalia-session is installed as a package; pacman owns these" >&2
    echo "files. Bump pkgver/pkgrel in PKGBUILD and run 'makepkg -fi' instead." >&2
    exit 1
fi

# The old name installed the launcher in /usr/local/bin; copying the new tree
# over it would leave that file behind.
if pacman -Qq cosmic-comp-traffic-session >/dev/null 2>&1; then
    echo "the old cosmic-comp-traffic-session package is installed. Replace it" >&2
    echo "with cosmalia-session (or remove it) before running this script." >&2
    exit 1
fi

# The session starts these directly, so a missing one is a broken install,
# not a warning.
missing=0
for bin in /usr/bin/cosmic-comp /usr/bin/noctalia /usr/bin/cosmic-settings-daemon; do
    if [[ ! -x $bin ]]; then
        echo "error: $bin is missing or not executable" >&2
        missing=1
    fi
done
if (( missing )); then
    exit 1
fi

if ! pacman -Qq cosmic-comp-traffic >/dev/null 2>&1; then
    echo "warning: cosmic-comp-traffic is not installed; /usr/bin/cosmic-comp is the" >&2
    echo "         unpatched compositor. Install it first, from" >&2
    echo "         https://github.com/grigio/cosmic-comp-traffic/releases" >&2
fi

while IFS= read -r -d '' f; do
    rel=${f#"$src"/}
    perm=644
    case $rel in */bin/*) perm=755 ;; esac
    printf 'install -m%s %s\n' "$perm" "/$rel"
    sudo install -D -o root -g root -m "$perm" "$f" "/$rel"
done < <(find "$src" -type f -print0 | sort -z)

# The package installs the same helper and docs; keep the source install in
# sync so "sudo cosmalia-session-default" works after the checkout is gone.
sudo install -D -o root -g root -m 755 "$root/scripts/set-default-greetd.sh" \
    /usr/bin/cosmalia-session-default
sudo install -D -o root -g root -m 644 "$root/README.md" \
    /usr/share/doc/cosmalia-session/README.md
sudo install -D -o root -g root -m 644 "$root/LICENSE" \
    /usr/share/licenses/cosmalia-session/LICENSE

systemctl --user daemon-reload
echo "reloaded the systemd user manager"
echo
echo "Cosmalia is installed but was NOT made the greeter default."
echo "Greeters that read /usr/share/wayland-sessions list it already; gtkgreet"
echo "users can run: sudo cosmalia-session-default --list"
echo "That makes it selectable without changing the default."
echo "To make it the default: sudo cosmalia-session-default"

if [[ ${1:-} == --default ]]; then
    sudo /usr/bin/cosmalia-session-default
fi
