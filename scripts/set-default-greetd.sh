#!/usr/bin/env bash
# Make cosmic-comp-traffic-session the entry gtkgreet preselects.
#
# How the default is picked (gtkgreet src/config.c, config_update_command_selector):
#   - the command passed with -c is appended to the session combo *first*,
#   - every line of /etc/greetd/environments is appended after it,
#   - the combo is then set to index 0 (src/window.c).
# So -c is the default and the environments file only fills the dropdown.
#
# greetd reads its config once, at startup (greetd/src/main.rs), so the change
# lands at the next greetd start: a reboot, or `systemctl restart greetd` while
# you are logged out.
#
# The package installs this as /usr/bin/cosmic-comp-traffic-session-default.
set -euo pipefail

cmd=/usr/local/bin/cosmic-comp-traffic-session
conf=/etc/greetd/config.toml
envs=/etc/greetd/environments
stamp=$(date +%Y%m%d-%H%M%S)

[[ -x $cmd ]] || {
    echo "$cmd is missing, install the session first (./scripts/install.sh" >&2
    echo "or the cosmic-comp-traffic-session package)" >&2
    exit 1
}
[[ -f $conf ]] || { echo "$conf not found (greetd is not configured here?)" >&2; exit 1; }

grep -q 'gtkgreet .*-c' "$conf" || {
    echo "$conf does not run gtkgreet with -c; set the default by hand" >&2
    exit 1
}

sudo cp -a "$conf" "$conf.bak.$stamp"
# only the -c argument changes; cage and the rest of the line stay as they are
sudo sed -E -i "s|(-c[[:space:]]+)[^\"[:space:]]+|\1$cmd|" "$conf"

if [[ -f $envs ]]; then
    sudo cp -a "$envs" "$envs.bak.$stamp"
    grep -qxF "$cmd" "$envs" || printf '%s\n' "$cmd" | sudo tee -a "$envs" >/dev/null
else
    printf '%s\n' "$cmd" | sudo tee "$envs" >/dev/null
fi

echo "default session -> $cmd"
sed -n 's/^command[[:space:]]*=.*/  &/p' "$conf"
echo "dropdown entry   -> $(grep -cxF "$cmd" "$envs") line(s) in $envs"
echo
echo "Effective at the next greetd start: reboot, or, once logged out,"
echo "  sudo systemctl restart greetd     # now it would end the running session"
