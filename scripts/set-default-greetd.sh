#!/usr/bin/env bash
# Make cosmalia-session the entry gtkgreet preselects, or with --list only add
# it to the dropdown while leaving the default alone. This is an explicit,
# opt-in action: the package itself never edits /etc/greetd.
#
# How the default is picked (gtkgreet src/config.c, config_update_command_selector):
#   - the command passed with -c is appended to the session combo *first*,
#   - every line of /etc/greetd/environments is appended after it,
#   - the combo is then set to index 0 (src/window.c).
# So -c is the default and the environments file only fills the dropdown.
# Without -c, gtkgreet uses the first line of environments as index 0, so this
# script prepends the session there.
#
# greetd reads its config once, at startup (greetd/src/main.rs), so the change
# lands at the next greetd start: a reboot, or `systemctl restart greetd` while
# you are logged out.
#
# The package installs this as /usr/bin/cosmalia-session-default. The
# GREETD_CONFIG/GREETD_ENVIRONMENTS overrides exist for testing.
set -euo pipefail

if [[ $EUID -eq 0 ]]; then SUDO=(); else SUDO=(sudo); fi

cmd=${COSMALIA_SESSION:-/usr/bin/cosmalia-session}
conf=${GREETD_CONFIG:-/etc/greetd/config.toml}
envs=${GREETD_ENVIRONMENTS:-/etc/greetd/environments}
old_cmd=/usr/local/bin/cosmic-comp-traffic-session
stamp=$(date +%Y%m%d-%H%M%S)
tmp=""
sed_script=""

usage() {
    cat <<'EOF'
usage: cosmalia-session-default [--list]

  (no option)  make Cosmalia the gtkgreet default and add it to the dropdown
  --list       only add Cosmalia to /etc/greetd/environments; leave the
               default (-c, or the first environments line) unchanged
EOF
}

case ${1:-} in
    '') ;;
    --list) list_only=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
esac
if [[ $# -gt 1 ]]; then
    usage >&2
    exit 1
fi
list_only=${list_only:-0}

cleanup_tmp() {
    if [[ -n $tmp ]]; then
        rm -f -- "$tmp"
    fi
    if [[ -n $sed_script ]]; then
        rm -f -- "$sed_script"
    fi
}
trap cleanup_tmp EXIT

new_tmp() {
    [[ -n $tmp ]] && rm -f -- "$tmp"
    tmp=$(mktemp)
}

# Keep the last 3 backups of a file instead of letting them accumulate.
prune_backups() {
    local path=$1 dir base
    dir=$(dirname -- "$path")
    base=$(basename -- "$path")
    "${SUDO[@]}" find "$dir" -maxdepth 1 -name "$base.bak.*" \
        -printf '%T@ %p\n' 2>/dev/null |
        sort -rn | tail -n +4 | cut -d' ' -f2- |
        xargs -r "${SUDO[@]}" rm -f --
}

backup_envs() {
    if [[ -f $envs ]]; then
        "${SUDO[@]}" cp -a -- "$envs" "$envs.bak.$stamp"
    fi
}

# Append at the end if missing. Returns 1 when it was already there.
ensure_in_envs() {
    if grep -qxF -- "$cmd" "$envs" 2>/dev/null; then
        return 1
    fi
    new_tmp
    if [[ -f $envs ]]; then
        cat -- "$envs" >"$tmp"
        if [[ -s $tmp ]] && [[ -n $(tail -c1 "$tmp") ]]; then
            printf '\n' >>"$tmp"
        fi
    fi
    printf '%s\n' "$cmd" >>"$tmp"
    "${SUDO[@]}" install -Dm644 -o root -g root "$tmp" "$envs"
    return 0
}

# Migration from cosmic-comp-traffic-session: it listed its launcher here,
# and that path no longer exists after the rename.
remove_old_env_entry() {
    if [[ -f $envs ]] && grep -qxF -- "$old_cmd" "$envs"; then
        "${SUDO[@]}" sed -i "\|^${old_cmd}$|d" "$envs"
    fi
}

[[ -x $cmd ]] || {
    echo "$cmd is missing, install the session first (./scripts/install.sh" >&2
    echo "or the cosmalia-session package)" >&2
    exit 1
}

if (( list_only )); then
    backup_envs
    if ensure_in_envs; then
        action="added $cmd to $envs (default unchanged)"
    else
        action="already listed in $envs (default unchanged)"
    fi
    remove_old_env_entry
    prune_backups "$envs"

    echo "$action"
    echo "dropdown entry   -> $(grep -cxF -- "$cmd" "$envs" 2>/dev/null || true) line(s) in $envs"
    echo
    echo "The default (-c or the first environments line) was not changed."
    echo "Effective at the next greetd start."
    exit 0
fi

[[ -f $conf ]] || { echo "$conf not found (greetd is not configured here?)" >&2; exit 1; }

if ! grep -qE '^[[:space:]]*command[[:space:]]*=.*gtkgreet' "$conf"; then
    if grep -qE '^[[:space:]]*command[[:space:]]*=.*noctalia-greeter' "$conf"; then
        cat >&2 <<'EOF'
This greetd config uses Noctalia Greeter, which selects the session itself.
Pick "Cosmalia" once in the greeter, or set:

  [session]
  default = "Cosmalia"

in /var/lib/noctalia-greeter/greeter.toml.

To only add Cosmalia to /etc/greetd/environments, run this again with --list.
EOF
    else
        echo "$conf does not run gtkgreet; set the session default in your greeter." >&2
        echo "(Use --list to only edit /etc/greetd/environments.)" >&2
    fi
    exit 1
fi

"${SUDO[@]}" cp -a -- "$conf" "$conf.bak.$stamp"
backup_envs

if grep -qE '^[[:space:]]*command[[:space:]]*=.*-c([[:space:]]|=)' "$conf"; then
    # Rewrite only the -c argument on the command line. Comments and the rest
    # of the line stay untouched. Handles unquoted, "quoted", 'single-quoted',
    # \"TOML-escaped\" and -c=/path arguments. @COSMALIA_CMD@ is substituted
    # in a second pass so the path needs no sed escaping.
    sed_script=$(mktemp)
    cat >"$sed_script" <<'SED'
/^[[:space:]]*command[[:space:]]*=/{
  s|(-c[[:space:]]+)"[^"]*"|\1@COSMALIA_CMD@|
  s|(-c[[:space:]]+)\\"[^"]*\\"|\1@COSMALIA_CMD@|
  s|(-c[[:space:]]+)'[^']*'|\1@COSMALIA_CMD@|
  s|(-c[[:space:]]+)[^"'[:space:]]+|\1@COSMALIA_CMD@|
  s#-c=("[^"]*"|\\"[^"]*\\"|'[^']*'|[^"'[:space:]]+)#-c @COSMALIA_CMD@#
}
SED
    "${SUDO[@]}" sed -i -E -f "$sed_script" "$conf"
    rm -f "$sed_script"
    sed_script=""
    "${SUDO[@]}" sed -i "s|@COSMALIA_CMD@|$cmd|g" "$conf"

    if ! grep -qE "^[[:space:]]*command[[:space:]]*=.*-c[[:space:]]+$cmd([\"'[:space:]]|$)" "$conf"; then
        echo "could not rewrite the -c argument in $conf; edit it by hand." >&2
        exit 1
    fi
    action="rewrote -c in $conf"
else
    # gtkgreet without -c uses the first line of environments as the default.
    new_tmp
    {
        printf '%s\n' "$cmd"
        if [[ -f $envs ]]; then
            grep -vxF -- "$cmd" "$envs" || true
        fi
    } >"$tmp"
    "${SUDO[@]}" install -Dm644 -o root -g root "$tmp" "$envs"
    action="prepended $cmd to $envs (gtkgreet has no -c)"
fi

# Make sure the session is in the dropdown list too. The no -c branch above
# already did this; the -c branch needs it.
ensure_in_envs || true
remove_old_env_entry

prune_backups "$conf"
prune_backups "$envs"

echo "$action"
sed -n 's/^[[:space:]]*command[[:space:]]*=.*/  &/p' "$conf"
echo "dropdown entry   -> $(grep -cxF -- "$cmd" "$envs" 2>/dev/null || true) line(s) in $envs"
echo
echo "Effective at the next greetd start: reboot, or, once logged out,"
echo "  sudo systemctl restart greetd     # now it would end the running session"
