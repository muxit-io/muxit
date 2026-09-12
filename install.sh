#!/usr/bin/env bash
# Muxit installer for Linux (Ubuntu / Debian / derivatives) and macOS.
#
# Usage (end-user):
#   curl -fsSL https://raw.githubusercontent.com/muxit-io/muxit/main/install.sh | bash
#
# Or with options:
#   curl -fsSL https://raw.githubusercontent.com/muxit-io/muxit/main/install.sh | bash -s -- --no-apt
#
# Flags:
#   --install-dir <path>    Override install dir (default: $HOME/.local/share/muxit).
#   --no-apt                Skip system-dependency install (apt on Linux,
#                           Homebrew on macOS). Useful for unattended re-installs
#                           or non-apt distros.
#   --no-symlink            Skip creating ~/.local/bin/muxit.
#   --yes                   Don't prompt for confirmation; assume yes everywhere.
#
# What this script does:
#   1. Detects OS / arch. Linux: apt-only Ubuntu/Debian, x86_64 + aarch64.
#      macOS: Apple Silicon (arm64) + Intel (x86_64).
#   2. Installs system packages — Linux (sudo apt): ffmpeg,
#      libappindicator3-1, xdg-utils; macOS (Homebrew): ffmpeg.
#      Asks for confirmation unless --yes.
#   3. Linux only: adds $USER to the `dialout` group (serial-port access).
#      macOS needs no group for serial (/dev/tty.* / /dev/cu.*).
#   4. Queries GitHub Releases API for the matching muxit-<rid>-<tag>.tar.gz.
#   5. Downloads the tarball + checksums.txt and verifies SHA256.
#   6. Stops any running muxit, then extracts into ~/.local/share/muxit/.
#      An existing workspace/ directory is preserved (never overwritten).
#      macOS: clears the Gatekeeper quarantine xattr so the unsigned binary runs.
#   7. Symlinks ~/.local/bin/muxit → installdir/muxit so it's on $PATH.
#   8. Prints how to launch.
#
# Per-user install: no sudo for the extract step, only for `apt install` and
# `usermod` (Linux). Nothing outside of ~/.local/{share,bin}/ is touched on disk.
#
# NOTE (macOS): release binaries are not yet code-signed or notarized, so
# Gatekeeper would normally block them. This script clears the quarantine
# attribute on the extracted tree; if you download manually instead, run
# `xattr -dr com.apple.quarantine <install-dir>` yourself. Vision drivers
# (Webcam / Onvif) are unavailable on macOS — there is no OpenCV native
# runtime for it — but the rest of Muxit runs normally.

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
INSTALL_DIR="${HOME}/.local/share/muxit"
DO_APT=1
DO_SYMLINK=1
ASSUME_YES=0
REPO="muxit-io/muxit"

# ─── Colors / helpers ────────────────────────────────────────────────────────
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  C_BOLD=$'\033[1m'; C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_RESET=$'\033[0m'
else
  C_BOLD=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi

section() { printf "\n%s== %s ==%s\n" "$C_CYAN" "$1" "$C_RESET"; }
info()    { printf "  %s\n" "$1"; }
ok()      { printf "  %s✓%s %s\n" "$C_GREEN" "$C_RESET" "$1"; }
warn()    { printf "  %s⚠%s %s\n" "$C_YELLOW" "$C_RESET" "$1"; }
die()     { printf "\n%sError:%s %s\n" "$C_RED" "$C_RESET" "$1" >&2; exit 1; }

confirm() {
  local prompt="$1"
  if [[ $ASSUME_YES -eq 1 ]]; then return 0; fi
  read -r -p "  $prompt [Y/n] " ans </dev/tty || return 1
  [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]
}

# ─── Args ────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --no-apt)      DO_APT=0; shift ;;
    --no-symlink)  DO_SYMLINK=0; shift ;;
    --yes|-y)      ASSUME_YES=1; shift ;;
    -h|--help)     sed -n '2,30p' "$0"; exit 0 ;;
    *)             die "Unknown option: $1 (use --help)" ;;
  esac
done

# ─── Sanity ──────────────────────────────────────────────────────────────────
section "Muxit installer"
info "Install dir: $INSTALL_DIR"

# Need: curl, tar, sha256sum (or shasum). No getent — it's a glibc tool absent
# on macOS (which this installer supports) and we never actually call it; the
# Linux dialout-group check below uses `id -nG`, not getent.
for cmd in curl tar; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required command '$cmd' is not on PATH."
done
if command -v sha256sum >/dev/null 2>&1; then
  SHA="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  SHA="shasum -a 256"
else
  die "Neither sha256sum nor shasum is available."
fi

# ─── OS + Architecture ───────────────────────────────────────────────────────
# Map `uname -s`/`uname -m` → .NET RID. Releases ship linux-x64 (Intel/AMD),
# linux-arm64 (Raspberry Pi 4/5 on 64-bit Pi OS, other arm64 SBCs),
# osx-arm64 (Apple Silicon) and osx-x64 (Intel Macs).
# 32-bit ARM (armv7l / armhf) is intentionally not supported — reflash
# the SD card with a 64-bit Pi OS / aarch64 image and re-run.
os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
  Linux)
    case "$arch" in
      x86_64|amd64)         RID="linux-x64" ;;
      aarch64|arm64)        RID="linux-arm64" ;;
      armv7l|armv6l|armhf)  die "32-bit ARM ($arch) is not supported. Reflash with 64-bit Pi OS / aarch64 and re-run." ;;
      *)                    die "Unsupported CPU architecture: $arch (supported: x86_64, aarch64)." ;;
    esac ;;
  Darwin)
    case "$arch" in
      arm64)                RID="osx-arm64" ;;
      x86_64)               RID="osx-x64" ;;
      *)                    die "Unsupported macOS architecture: $arch (supported: arm64, x86_64)." ;;
    esac ;;
  *)
    die "Unsupported OS: $os (this installer supports Linux and macOS)." ;;
esac
info "Platform: $os $arch → $RID"

# ─── 1. Detect package manager for the system-deps step ──────────────────────
if [[ $DO_APT -eq 1 ]]; then
  if [[ "$os" == "Linux" ]]; then
    if ! command -v apt-get >/dev/null 2>&1; then
      warn "apt-get not found — this script's auto-install supports Ubuntu/Debian only."
      warn "Skipping system-package install. Install manually: ffmpeg libappindicator3-1 xdg-utils"
      DO_APT=0
    fi
  elif [[ "$os" == "Darwin" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      warn "Homebrew (brew) not found — cannot auto-install system packages."
      warn "Skipping. Install Homebrew from https://brew.sh then run: brew install ffmpeg"
      DO_APT=0
    fi
  fi
fi

# ─── 2. System packages ──────────────────────────────────────────────────────
if [[ $DO_APT -eq 1 && "$os" == "Linux" ]]; then
  section "System packages"
  pkgs_needed=()
  # ffmpeg → required for Onvif RTSP capture (subprocess pipeline).
  command -v ffmpeg >/dev/null 2>&1 || pkgs_needed+=("ffmpeg")
  # libappindicator3-1 → system-tray icon (cosmetic; server runs without).
  # The tray's native library links against the ORIGINAL appindicator soname:
  #   $ objdump -p libnotification_icon.so | grep NEEDED
  #   NEEDED  libappindicator3.so.1
  # Installing libayatana-appindicator3-1 does not provide that soname, so it
  # left the tray broken while reporting success. Distros that dropped
  # libappindicator3-1 (Ubuntu 24.04+) need the ayatana package plus a symlink.
  if ! ldconfig -p 2>/dev/null | grep -q "libappindicator3.so.1"; then
    pkgs_needed+=("libappindicator3-1")
  fi
  # xdg-utils → auto-open browser at startup (cosmetic; URL is logged either way).
  command -v xdg-open >/dev/null 2>&1 || pkgs_needed+=("xdg-utils")

  if [[ ${#pkgs_needed[@]} -eq 0 ]]; then
    ok "All system dependencies already installed."
  else
    info "Need to install: ${pkgs_needed[*]}"
    if confirm "Run 'sudo apt install ${pkgs_needed[*]}'?"; then
      sudo apt update
      sudo apt install -y "${pkgs_needed[@]}"
      ok "Packages installed."
    else
      warn "Skipped. Install manually later: sudo apt install ${pkgs_needed[*]}"
    fi
  fi
elif [[ $DO_APT -eq 1 && "$os" == "Darwin" ]]; then
  section "System packages"
  # macOS: only ffmpeg is worth auto-installing (Onvif RTSP capture). The tray
  # icon and browser-open use native APIs (no appindicator / xdg-utils needed).
  # Vision drivers are unavailable on macOS regardless, so OpenCV is moot.
  if command -v ffmpeg >/dev/null 2>&1; then
    ok "ffmpeg already installed."
  else
    info "Need to install: ffmpeg (for Onvif camera capture)"
    if confirm "Run 'brew install ffmpeg'?"; then
      brew install ffmpeg
      ok "ffmpeg installed."
    else
      warn "Skipped. Install manually later: brew install ffmpeg"
    fi
  fi
fi

# ─── 3. Serial-port access ───────────────────────────────────────────────────
# Linux gates serial devices behind the `dialout` group. macOS does not — any
# user can open /dev/tty.* and /dev/cu.* — so there's nothing to do there.
if [[ "$os" == "Linux" ]]; then
  section "Hardware access (dialout group)"
  if id -nG "$USER" | tr ' ' '\n' | grep -qx dialout; then
    ok "User '$USER' is already in 'dialout' group."
  else
    warn "User '$USER' is NOT in 'dialout' group — serial-port drivers will fail with 'Permission denied'."
    if confirm "Add '$USER' to 'dialout' group with sudo?"; then
      sudo usermod -aG dialout "$USER"
      warn "You must log out and back in (or run 'newgrp dialout') for the group change to take effect."
    else
      warn "Skipped. Fix later: sudo usermod -aG dialout $USER && newgrp dialout"
    fi
  fi
fi

# ─── 4. Find latest release ──────────────────────────────────────────────────
section "Latest release"
release_json="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")" \
  || die "Failed to query GitHub Releases API."

tag="$(printf '%s' "$release_json" | grep -oE '"tag_name":\s*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
[[ -n "$tag" ]] || die "Could not parse tag_name from GitHub Releases API."
info "Version: $tag"

# Anchor on the exact tag — releases sometimes carry stale tarballs from
# previous versions, and we must not silently install one of those.
tag_re="${tag//./\\.}"
tar_name="muxit-${RID}-${tag}.tar.gz"
tar_url="$(printf '%s' "$release_json" \
  | grep -oE '"browser_download_url":\s*"[^"]+"' \
  | sed -E 's/.*"([^"]+)".*/\1/' \
  | grep -E "/muxit-${RID}-${tag_re}\.tar\.gz$" | head -1)"
if [[ -z "$tar_url" ]]; then
  if [[ "$RID" == "linux-arm64" ]]; then
    die "Release $tag has no $tar_name asset. linux-arm64 builds were added in v0.32.0 — older releases ship x64 only."
  fi
  if [[ "$RID" == osx-* ]]; then
    die "Release $tag has no $tar_name asset. macOS builds are newly added — only releases that ship an osx-* archive can be installed this way."
  fi
  die "Release $tag has no $tar_name asset."
fi

cs_url="$(printf '%s' "$release_json" \
  | grep -oE '"browser_download_url":\s*"[^"]+"' \
  | sed -E 's/.*"([^"]+)".*/\1/' \
  | grep -E '/checksums\.txt$' | head -1)"

# ─── 5. Download + verify ────────────────────────────────────────────────────
tmpdir="$(mktemp -d -t muxit-install-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

section "Downloading"
info "$tar_name"
curl -fsSL --output "$tmpdir/$tar_name" "$tar_url"
size_mb="$(du -m "$tmpdir/$tar_name" | cut -f1)"
ok "Downloaded (${size_mb} MB)"

if [[ -n "$cs_url" ]]; then
  section "Verifying checksum"
  curl -fsSL --output "$tmpdir/checksums.txt" "$cs_url"
  expected="$(grep "  ${tar_name}\$" "$tmpdir/checksums.txt" | awk '{print $1}' || true)"
  if [[ -z "$expected" ]]; then
    warn "checksums.txt has no entry for $tar_name — skipping verification."
  else
    actual="$(cd "$tmpdir" && $SHA "$tar_name" | awk '{print $1}')"
    if [[ "$expected" != "$actual" ]]; then
      die "Checksum mismatch! Expected $expected, got $actual"
    fi
    ok "OK ($actual)"
  fi
else
  warn "No checksums.txt asset in release — skipping verification."
fi

# ─── 6. Stop any running muxit, then extract ─────────────────────────────────
if pgrep -u "$USER" -x muxit >/dev/null 2>&1; then
  section "Stopping running muxit"
  pkill -u "$USER" -x muxit || true
  sleep 1
fi

section "Installing to $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Preserve user's workspace/ directory across re-installs.
preserved_ws=""
if [[ -d "$INSTALL_DIR/workspace" ]]; then
  preserved_ws="$tmpdir/workspace.bak"
  info "Preserving existing workspace/ directory"
  mv "$INSTALL_DIR/workspace" "$preserved_ws"
fi

# Wipe shipped subdirs and top-level files we recognise; leave anything
# else the user dropped into the dir alone.
for sub in wwwroot runtimes Assets workspace-template; do
  rm -rf "$INSTALL_DIR/$sub"
done
find "$INSTALL_DIR" -maxdepth 1 -type f \
  \( -name 'muxit' -o -name '*.dll' -o -name '*.so' -o -name '*.dylib' -o -name '*.json' -o -name '*.xml' -o -name '*.pdb' \) \
  -delete 2>/dev/null || true

tar -xzf "$tmpdir/$tar_name" -C "$INSTALL_DIR"

if [[ -n "$preserved_ws" ]]; then
  rm -rf "$INSTALL_DIR/workspace"
  mv "$preserved_ws" "$INSTALL_DIR/workspace"
fi

[[ -x "$INSTALL_DIR/muxit" ]] || die "muxit binary not found / not executable at $INSTALL_DIR/muxit after extract."
ok "Extracted."

# macOS: the release archive isn't signed/notarized yet, so files unpacked
# from a downloaded tarball carry the com.apple.quarantine xattr and Gatekeeper
# refuses to run them ("cannot be opened because the developer cannot be
# verified"). Strip the attribute recursively so the binary launches. This is
# a no-op once releases are properly notarized.
if [[ "$os" == "Darwin" ]]; then
  if xattr -dr com.apple.quarantine "$INSTALL_DIR" 2>/dev/null; then
    ok "Cleared Gatekeeper quarantine attribute."
  else
    warn "Could not clear quarantine attr; if launch is blocked run: xattr -dr com.apple.quarantine \"$INSTALL_DIR\""
  fi
fi

# ─── 7. Symlink in ~/.local/bin ──────────────────────────────────────────────
# launch_cmd is what we tell the user to type at the end. If we can't put a
# `muxit` shim on $PATH (or we did but $PATH isn't picking it up in this
# shell), fall back to the absolute path so the install isn't dead-on-arrival.
launch_cmd="$INSTALL_DIR/muxit"
if [[ $DO_SYMLINK -eq 1 ]]; then
  section "Symlink"
  bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"
  ln -sfn "$INSTALL_DIR/muxit" "$bin_dir/muxit"
  ok "$bin_dir/muxit → $INSTALL_DIR/muxit"

  # Heads-up if ~/.local/bin isn't on PATH (rare on modern Ubuntu, common on minimal Debian).
  case ":$PATH:" in
    *":$bin_dir:"*) launch_cmd="muxit" ;;
    *) warn "$bin_dir is NOT on \$PATH. Add this to ~/.bashrc and start a new shell:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
  esac
fi

# ─── 8. Done ─────────────────────────────────────────────────────────────────
section "Done"
info "Installed: $INSTALL_DIR/muxit"
info "Version:   $tag"
printf "\n%sLaunch Muxit:%s\n" "$C_GREEN" "$C_RESET"
printf "  %s\n" "$launch_cmd"
info "Then open http://127.0.0.1:8765 in your browser."
