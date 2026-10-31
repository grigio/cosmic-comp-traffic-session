# Cosmalia

Cosmalia is a modern, minimal desktop for Linux that runs in under 1 GB of
RAM. It is built from two projects:

- **[cosmic-comp-traffic](https://github.com/grigio/cosmic-comp-traffic)** — an
  improved fork of `cosmic-comp` with macOS-style traffic-light decorations,
  Wayland blur, animations, `zwlr_foreign_toplevel_manager_v1`, 3-finger
  workspace swipes and in-process Alt+Tab;
- **[Noctalia](https://noctalia.dev)** — the shell: bar/dock, launcher,
  notifications, networking, lock screen, idle/suspend, MPRIS, screensaver and
  a polkit agent.

`cosmalia-session` is the opinionated XDG session that starts them together.
It shows up in any Wayland-capable login manager (greetd, GDM, …); the login
manager itself is installed and configured by you.

## The stack

| Component | Job |
|---|---|
| `cosmic-comp-traffic` | Wayland compositor; installs itself as `/usr/bin/cosmic-comp` |
| `noctalia` | bar, dock, launcher, notifications, networking, lock screen, idle/suspend, MPRIS, polkit agent, screensaver |
| `cosmalia-session` | this package: session launcher, XDG session entry, systemd user target |
| `xdg-desktop-portal-cosmic` | portal backend, mainly for screen sharing/screencast, plus screenshots and the file chooser |
| `cosmic-settings` | settings app, convenient for controlling cosmic-comp features |
| `cosmic-settings-daemon` | serves cosmic-config change notifications, so theme, appearance and keybind edits apply live |
| `cosmic-screenshot` | screenshot utility that goes through the portal |
| `polkit` | ships `polkit-agent-helper-1`, the helper used by the polkit agent |
| `polkit-gnome` | optional fallback polkit agent; Noctalia already registers one, so run only one of the two |
| `gnome-keyring` | Secret Service for browsers and apps; unlocked by PAM at login |

Not included — install them separately if you want them: `voxtype` (voice
typing), `syncthing` (file sync) and `gvfs` (trash, recent files, MTP/network
mounts). Some COSMIC features need more components from the COSMIC desktop or
other services; this session deliberately stays small.

The `cosmic-comp-traffic` package `provides`/`conflicts`/`replaces`
`cosmic-comp`, so `/usr/bin/cosmic-comp` is the patched build. Switching back
to the stock compositor is `sudo pacman -S cosmic-comp`.

## Files

| Repo path | Installed to | What |
|---|---|---|
| `files/usr/bin/cosmalia-session` | same | session launcher: compositor → wait for the socket → import env → session target → settings daemon → Noctalia |
| `files/usr/share/wayland-sessions/cosmalia.desktop` | same | XDG session entry, listed by the greeter as **Cosmalia** |
| `files/usr/lib/systemd/user/cosmalia-session.target` | same | session target, `BindsTo=graphical-session.target` |
| `scripts/install.sh` | — | copies `files/` onto `/` (`--default` also runs the next script) |
| `scripts/set-default-greetd.sh` | `/usr/bin/cosmalia-session-default` | preselects the session in gtkgreet |
| `PKGBUILD`, `cosmalia-session.install` | — | package, built from this tree by CI on every `v*` tag |
| `.github/workflows/arch-package.yml` | — | builds and publishes the package for a release tag |
| `.github/workflows/ci.yml` | — | shellcheck + `makepkg` on every push |

The repo layout mirrors `/`, so installing is a copy and the files can be
diffed against the live ones at any time.

## Install

Three ways, all installing the same files — use one, and prefer the package so
pacman owns `/usr`:

```sh
# A) the published package (recommended)
gh release download v1.2.0 -R grigio/cosmalia-session \
  -p '*.pkg.tar.zst*' -D /tmp/cosmalia-session
cd /tmp/cosmalia-session && sha256sum -c ./*.pkg.tar.zst.sha256
sudo pacman -U ./*.pkg.tar.zst
sudo cosmalia-session-default        # optional: greeter default

# B) build it locally from this checkout
makepkg -fi
sudo cosmalia-session-default        # optional: greeter default

# C) straight from the checkout, no package
./scripts/install.sh              # session only
./scripts/install.sh --default    # ... and make it the greeter default
```

`install.sh` warns if `cosmic-comp-traffic` is not installed, because
`/usr/bin/cosmic-comp` would then be the unpatched compositor; the session
itself also checks this at login and logs the warning. It refuses to run if
either `cosmalia-session` or the old `cosmic-comp-traffic-session` package is
installed, so pacman's file list stays accurate.

### The package

`arch=(any)`, no sources (it packages this tree). It installs the three session
files plus `/usr/bin/cosmalia-session-default` and the docs under
`/usr/share/doc/cosmalia-session/`.

Every `v<major>.<minor>.<patch>` tag is built by
`.github/workflows/arch-package.yml` in an `archlinux:base-devel` container and
attached to its GitHub release. `pkgver` comes from the tag, `pkgrel` from the
number of commits that touched the packaging (`PKGBUILD`, the `.install` file,
`files/`, `scripts/`), so a rebuild of a tag is still an upgrade for pacman.
Locally, `makepkg -f` uses the `pkgver` written in the `PKGBUILD`, or the
injected one:

```sh
SESSION_VERSION=1.2.0 SESSION_PKGREL=4 makepkg -f
```

| | |
|---|---|
| depends | `cosmic-comp` (provided by `cosmic-comp-traffic`), `noctalia`, `cosmic-settings`, `cosmic-settings-daemon`, `cosmic-screenshot`, `xdg-desktop-portal-cosmic`, `polkit`, `gnome-keyring`, `wireplumber` |
| optdepends | `polkit-gnome` (fallback polkit agent), `iproute2` (socket lookup via `ss`) |

`cosmic-comp-traffic` is not in the official repositories, so `makepkg` needs
`--nodeps` unless it is already installed. `noctalia` and the COSMIC packages
are in `extra`.

A post-install message repeats the "run `cosmalia-session-default`" hint, and
`pre_remove` warns to point the greeter at another session first.

### Upgrading from `cosmic-comp-traffic-session`

The package `provides`, `replaces` and `conflicts` with the old name, so
installing `cosmalia-session` replaces the old package and removes its
`cosmic-comp-traffic.desktop`, launcher and systemd target.
`cosmalia-session-default` also drops the old launcher from
`/etc/greetd/environments`, so the greeter does not list a dead entry. If you
installed with `scripts/install.sh` instead, delete the old files by hand:

```sh
sudo rm /usr/share/wayland-sessions/cosmic-comp-traffic.desktop \
        /usr/local/bin/cosmic-comp-traffic-session \
        /usr/lib/systemd/user/cosmic-comp-traffic-session.target
systemctl --user daemon-reload
```

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
-c /usr/bin/cosmalia-session
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
| `cosmic-settings-daemon` | cosmic-config watchers: live theme, appearance and keybind changes |
| `xdg-desktop-portal` + `xdg-desktop-portal-cosmic` | `restart`ed per login: the cosmic backend has no `PartOf=graphical-session.target`, so it survives logout and would otherwise keep a stale `WAYLAND_DISPLAY` |

Already covered without starting anything here:

| Piece | Why it needs no session entry |
|---|---|
| D-Bus user bus (`dbus-broker`/`dbus-daemon`) | started by the user manager |
| `pipewire`, `wireplumber` | socket + enabled unit; audio and screencast |
| `gnome-keyring-daemon` | D-Bus/socket activated; PAM unlocks it at login (see below) |
| `gvfs-*`, `xdg-document-portal` | D-Bus activated on first use, if installed |
| `upower`, `power-profiles-daemon`, NetworkManager | system services, session agnostic |

The keyring is unlocked by PAM at login. Make sure your display manager's PAM
file (`/etc/pam.d/greetd`, `/etc/pam.d/gdm-password`, …) loads
`pam_gnome_keyring.so`; the current greetd config already does.

`cosmic-settings` and `cosmic-screenshot` are installed as part of the stack
but are normal applications: they are launched on demand, not by the session.

Deliberately **not** part of the session:

- `xdg-desktop-portal-gtk`/`-gnome`/`-wlr`: their `.portal` files declare
  `UseIn=gnome`/`gnome`/`wlroots`, which never matches `…:COSMIC`, so they are
  never selected. Keep them only if you also run GNOME or wlroots sessions; the
  cosmic backend covers screenshots, screencast and the file chooser here.
- `gnome-keyring` in the session target: it must outlive the graphical session.
  Only one Secret Service provider may run; `oo7` or `keepassxc` are drop-in
  alternatives (`org.freedesktop.secrets`), gnome-keyring is the one COSMIC
  itself pairs with.
- `polkit-gnome`: Noctalia registers its own polkit agent, so starting
  `polkit-gnome` too would give two agents. Keep it as a fallback for setups
  where Noctalia's agent is disabled; run
  `polkit-gnome-authentication-agent-1` at login in that case.
- `noctalia-labwc-sync.path`, `labwc-4finger-gestures.service`: labwc only
  (`ConditionEnvironment`, `wtype`); cosmic-comp handles both natively.
- `voxtype`, `syncthing`, `gvfs`: useful, but not part of a minimal session.
- COSMIC's own `cosmic-session`/panel/dock: replaced by Noctalia.

`XDG_CURRENT_DESKTOP=cosmalia:COSMIC` — the `:COSMIC` suffix is what makes
xdg-desktop-portal select the cosmic backend; without it screenshots and
screencast have no implementation.

## Logs

```sh
tail -f "$XDG_RUNTIME_DIR/cosmalia-session.log"   # session + noctalia output
journalctl --user -b -u cosmalia-session.target
journalctl -b _COMM=cosmic-comp
```

## Reverting

```sh
# back to the previous greeter default (labwc) or any earlier one:
sudo cp -a /etc/greetd/config.toml.bak.<timestamp> /etc/greetd/config.toml
sudo cp -a /etc/greetd/environments.bak.<timestamp> /etc/greetd/environments

# remove the session (package install):
sudo pacman -R cosmalia-session

# remove the session (install.sh install):
sudo rm /usr/share/wayland-sessions/cosmalia.desktop \
        /usr/bin/cosmalia-session \
        /usr/lib/systemd/user/cosmalia-session.target
systemctl --user daemon-reload

# and the patched compositor, if wanted:
sudo pacman -S cosmic-comp
```
