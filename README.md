# cosmic-comp-traffic-session

A minimal Wayland session: `cosmic-comp` from
[cosmic-comp-traffic](https://github.com/grigio/cosmic-comp-traffic) as the
compositor, [Noctalia](https://noctalia.dev) 5.3 as the shell. Nothing else is
started on purpose.

The compositor binary comes from the `cosmic-comp-traffic` package, which
installs itself as `/usr/bin/cosmic-comp` (`provides`/`conflicts`/`replaces`
`cosmic-comp`), so this session is a drop-in replacement for a stock COSMIC
session and can be removed again with `sudo pacman -S cosmic-comp`.

## Files

| Repo path | Installed to | What |
|---|---|---|
| `files/usr/local/bin/cosmic-comp-traffic-session` | same | session launcher: compositor → wait for the socket → import env → session target → Noctalia |
| `files/usr/share/wayland-sessions/cosmic-comp-traffic.desktop` | same | XDG session entry, listed by the greeter |
| `files/usr/lib/systemd/user/cosmic-comp-traffic-session.target` | same | session target, `BindsTo=graphical-session.target` |
| `scripts/install.sh` | — | copies `files/` onto `/` (`--default` also runs the next script) |
| `scripts/set-default-greetd.sh` | — | preselects the session in gtkgreet |

The repo layout mirrors `/`, so installing is a copy and the files can be
diffed against the live ones at any time.

## Install

```sh
cd ~/Code/cosmic-comp-traffic-session
./scripts/install.sh              # session only
./scripts/install.sh --default    # ... and make it the greeter default
```

`install.sh` warns if `cosmic-comp-traffic` is not installed, because
`/usr/bin/cosmic-comp` would then be the unpatched compositor; the session
itself also checks this at login and logs the warning.

## Making it the greeter default

`/etc/greetd/config.toml` runs `cage -s -- gtkgreet -c <command>`. That `<command>`
is the default session, not a fixed one:

- gtkgreet puts the `-c` command first in the session combo
  (`config_update_command_selector` in `gtkgreet/src/config.c`), then appends
  every line of `/etc/greetd/environments`, then selects index 0
  (`gtkgreet/src/window.c`);
- so `-c` is what Enter logs into, and `/etc/greetd/environments` only fills the
  dropdown.

`scripts/set-default-greetd.sh` rewrites just the `-c` argument (backups:
`config.toml.bak.<timestamp>`, `environments.bak.<timestamp>`) and adds the
session to the dropdown list:

```
-c /usr/local/bin/cosmic-comp-traffic-session
```

greetd reads its config once, at startup (`greetd/src/main.rs` → `server::main`),
so the change takes effect at the next greetd start. Restarting `greetd.service`
now would end the running session — the session worker is a child of greetd —
so reboot, or run `sudo systemctl restart greetd` from a TTY while logged out.

## What runs

Started by the session, deliberately:

| Piece | Job |
|---|---|
| `cosmic-comp --no-xwayland` | compositor (traffic lights, soft focus ring, `zwlr_foreign_toplevel_manager_v1`, 3-finger workspace swipe, in-process Alt+Tab) |
| `noctalia` | bar, dock, launcher, notifications, lock screen, idle/suspend, MPRIS, polkit agent, screensaver |
| `xdg-desktop-portal` + `xdg-desktop-portal-cosmic` | `restart`ed per login: the cosmic backend has no `PartOf=graphical-session.target`, so it survives logout and would otherwise keep a stale `WAYLAND_DISPLAY` |

Already covered without starting anything here:

| Piece | Why it needs no session entry |
|---|---|
| `dbus-broker` | user bus, started by the user manager |
| `pipewire`, `wireplumber` | socket + enabled unit; audio and screencast |
| `gnome-keyring-daemon` | D-Bus/socket activated, unlocked by `pam_gnome_keyring.so auto_start` in `/etc/pam.d/greetd` |
| `gvfs-*`, `xdg-document-portal` | D-Bus activated on first use |
| `upower`, `power-profiles-daemon`, NetworkManager | system services, session agnostic |

Deliberately **not** part of the session:

- `xdg-desktop-portal-gtk`/`-gnome`/`-wlr`: their `.portal` files declare
  `UseIn=gnome`/`gnome`/`wlroots`, which never matches `…:COSMIC`, so they are
  never selected. Keep them installed as a FileChooser fallback, don't start
  them here.
- `gnome-keyring` in the session target: it must outlive the graphical session.
  Only one Secret Service provider may run; `oo7` or `keepassxc` are drop-in
  alternatives (`org.freedesktop.secrets`), gnome-keyring is the one COSMIC
  itself pairs with.
- `noctalia-labwc-sync.path`, `labwc-4finger-gestures.service`: labwc only
  (`ConditionEnvironment`, `wtype`); cosmic-comp handles both natively.
- COSMIC's own `cosmic-session`/panel/dock: replaced by Noctalia.

`XDG_CURRENT_DESKTOP=cosmic-comp-traffic:COSMIC` — the `:COSMIC` suffix is what
makes xdg-desktop-portal select the cosmic backend; without it screenshots and
screencast have no implementation.

## Logs

```sh
tail -f "$XDG_RUNTIME_DIR/cosmic-comp-traffic.log"   # session + noctalia output
journalctl --user -b -u cosmic-comp-traffic-session.target
journalctl -b _COMM=cosmic-comp
```

## Reverting

```sh
# back to the previous greeter default (labwc) or any earlier one:
sudo cp -a /etc/greetd/config.toml.bak.<timestamp> /etc/greetd/config.toml
sudo cp -a /etc/greetd/environments.bak.<timestamp> /etc/greetd/environments

# remove the session:
sudo rm /usr/share/wayland-sessions/cosmic-comp-traffic.desktop \
        /usr/local/bin/cosmic-comp-traffic-session \
        /usr/lib/systemd/user/cosmic-comp-traffic-session.target
systemctl --user daemon-reload

# and the patched compositor, if wanted:
sudo pacman -S cosmic-comp
```
