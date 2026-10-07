---
title: Install on Linux
description: Three ways to install Muxit on Ubuntu / Debian and what apt-packages it needs.
---

# Install on Linux

Muxit ships a self-contained `linux-x64` tarball — the .NET runtime is
included, so the host only needs a few system libraries for hardware
features (camera streaming, system tray, serial-port access). Three
installation paths are documented here, in order of convenience.

Tested on **Ubuntu 22.04 LTS** and **Ubuntu 24.04 LTS**. Should work on
any glibc 2.31+ distro (Debian 11+, RHEL/AlmaLinux 8+); only the
package names in step 2 differ on non-apt distros.

---

## 1. One-liner installer (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/muxit-io/muxit/main/install.sh | bash
```

What this does:

1. Detects the distro (apt-only for now — clear error otherwise).
2. Installs `ffmpeg`, `libappindicator3-1`, `xdg-utils` via
   `sudo apt`. Asks for confirmation; skip with `--yes`.
3. Adds your user to the `dialout` group if not already a member
   (needed for `/dev/ttyUSB*` serial-port access).
4. Downloads the latest `muxit-linux-x64-v*.tar.gz` from GitHub
   Releases and verifies the SHA-256 against `checksums.txt`.
5. Extracts into `~/.local/share/muxit/`. An existing
   `workspace/` directory is preserved across reinstalls.
6. Symlinks `~/.local/bin/muxit` → installdir, so `muxit` lands on
   `$PATH`.
7. Prints how to launch.

**Per-user install**: nothing outside `~/.local/{share,bin}/` is
touched on disk. Sudo is only used for the `apt install` and
`usermod` steps.

### Common flags

```bash
# Skip the apt-install step (re-install on a host where deps are already in place)
curl -fsSL .../install.sh | bash -s -- --no-apt

# Install somewhere else
curl -fsSL .../install.sh | bash -s -- --install-dir /opt/muxit

# Don't prompt for anything
curl -fsSL .../install.sh | bash -s -- --yes

# Don't symlink ~/.local/bin/muxit (you launch by full path)
curl -fsSL .../install.sh | bash -s -- --no-symlink
```

### Re-running the installer

Re-running the same command upgrades to the latest release. The
installer wipes and re-extracts only the shipped subdirs (`wwwroot/`,
`runtimes/`, `Assets/`, `workspace-template/`) and the top-level
binaries; **`workspace/` is preserved.**

---

## 2. Manual install

If you don't want to pipe a script into bash, do it by hand:

```bash
# 1. System packages
sudo apt install -y ffmpeg libappindicator3-1 xdg-utils

# 2. Serial-port group (re-login or `newgrp dialout` after this)
sudo usermod -aG dialout $USER

# 3. Download — set VERSION to the latest tag from https://github.com/muxit-io/muxit/releases
VERSION=0.37.0
mkdir -p ~/.local/share/muxit
cd ~/.local/share/muxit
curl -LO https://github.com/muxit-io/muxit/releases/download/v$VERSION/muxit-linux-x64-v$VERSION.tar.gz
curl -LO https://github.com/muxit-io/muxit/releases/download/v$VERSION/checksums.txt

# 4. Verify
grep muxit-linux-x64- checksums.txt | sha256sum --check

# 5. Extract
tar -xzf muxit-linux-x64-v*.tar.gz

# 6. (Optional) put it on PATH
mkdir -p ~/.local/bin
ln -sfn ~/.local/share/muxit/muxit ~/.local/bin/muxit

# 7. Launch
muxit
```

---

## 3. What every system package buys you

| Package | What it enables | Without it |
|---|---|---|
| `ffmpeg` | Onvif IP-camera RTSP streaming | Onvif `start` action throws `Failed to start ffmpeg subprocess` |
| `libappindicator3-1` | System-tray icon (with View Logs / Restart / Quit) | Server runs normally; tray-icon stderr line on boot, no menubar entry |
| `xdg-utils` | Auto-open browser at startup | Server prints the URL; you open it yourself |
| `dialout` group membership | `/dev/ttyUSB*` and `/dev/ttyACM*` access | Serial drivers throw `EACCES` on init |

Muxit checks all of these at startup and prints non-fatal warnings
under **System dependencies** in the boot banner — including the
exact `apt` / `usermod` command to fix each one. So if you skip the
installer entirely, the server itself tells you what's missing.

---

## What about other distros?

The tarball is built against **manylinux_2_28** (glibc 2.28+) and
should run on any reasonable modern distro. Only the package-manager
commands differ:

- **Fedora / RHEL / AlmaLinux** (`dnf`): `sudo dnf install ffmpeg-free libayatana-appindicator-gtk3 xdg-utils`
- **Arch / Manjaro** (`pacman`): `sudo pacman -S ffmpeg libayatana-appindicator xdg-utils`
- **OpenSUSE** (`zypper`): `sudo zypper install ffmpeg libappindicator3-1 xdg-utils`

The `install.sh` one-liner is apt-only for now; native dnf / pacman
support is on the roadmap. Until then, the manual install (step 2
above) works on any distro — just substitute your distro's package
manager for `apt install`.

---

## Uninstall

```bash
rm -rf ~/.local/share/muxit
rm -f ~/.local/bin/muxit
# Optional: remove apt packages if you don't use them otherwise
# sudo apt remove ffmpeg libappindicator3-1 xdg-utils
# Optional: leave dialout group
# sudo gpasswd -d $USER dialout
```

Your workspace is at `~/.local/share/muxit/workspace/`; back it up
before deleting if it has device configs / scripts you want to keep.

---

## Troubleshooting

If something doesn't work, the **"View Logs"** entry in the system
tray (or `http://localhost:8765/logs.html`) shows the live ringbuffer
plus a `System dependencies` banner that calls out anything missing.
See the [troubleshooting guide](https://docs.muxit.io/guides/troubleshooting.md#viewing-server-logs)
for more.

Common ones:

- **"Failed to start `ffmpeg` subprocess"** when starting Onvif → install ffmpeg.
- **"Permission denied" on `/dev/ttyUSB0`** → add user to `dialout` and
  re-login (or `newgrp dialout`).
- **Tray icon not showing** → install `libappindicator3-1` and restart muxit.
  The tray's native library links against the original appindicator soname
  (`libappindicator3.so.1`), not the Ayatana fork. On distros that dropped the
  package (Ubuntu 24.04+), install `libayatana-appindicator3-1` and symlink it:
  `sudo ln -s /usr/lib/x86_64-linux-gnu/libayatana-appindicator3.so.1 /usr/lib/x86_64-linux-gnu/libappindicator3.so.1`.
  Muxit's startup banner prints the exact soname the loader asked for.
- **Browser doesn't auto-open** → install `xdg-utils`, or just visit the
  printed URL yourself.
