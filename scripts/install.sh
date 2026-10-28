#!/usr/bin/env bash
# Install the cosmic-comp-traffic session: copies files/ onto /, so the repo
# layout is the install layout.
#
#   ./scripts/install.sh             # session files only
#   ./scripts/install.sh --default   # ... and preselect it in gtkgreet
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
src="$root/files"

case ${1:-} in
    ''|--default) ;;
    *) echo "usage: $0 [--default]" >&2; exit 1 ;;
esac

[[ -x /usr/bin/cosmic-comp ]] || {
    echo "cosmic-comp is not installed (expected from cosmic-comp-traffic)" >&2
    exit 1
}

if ! pacman -Qq cosmic-comp-traffic >/dev/null 2>&1; then
    echo "warning: cosmic-comp-traffic is not installed; /usr/bin/cosmic-comp is the" >&2
    echo "         unpatched compositor. Install it first, from" >&2
    echo "         https://github.com/grigio/cosmic-comp-traffic/releases" >&2
fi

# If the files are already package-managed, copying over them only makes pacman's
# file list lie. Rebuild the package instead.
if pacman -Qq cosmic-comp-traffic-session >/dev/null 2>&1; then
    echo "cosmic-comp-traffic-session is installed as a package; pacman owns these" >&2
    echo "files. Bump pkgver/pkgrel in PKGBUILD and run 'makepkg -fi' instead." >&2
    exit 1
fi

while IFS= read -r -d '' f; do
    rel=${f#"$src"/}
    perm=644
    case $rel in */bin/*) perm=755 ;; esac
    printf 'install -m%s %s\n' "$perm" "/$rel"
    sudo install -D -o root -g root -m "$perm" "$f" "/$rel"
done < <(find "$src" -type f -print0 | sort -z)

systemctl --user daemon-reload
echo "reloaded the systemd user manager"

if [[ ${1:-} == --default ]]; then
    "$root/scripts/set-default-greetd.sh"
fi
