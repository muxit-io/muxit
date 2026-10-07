---
title: Installation
description: Install Muxit on Windows, macOS, or Linux — one command, no prerequisites.
---

# Installation

Get Muxit running on your machine in under a minute. Muxit ships a
self-contained binary for **Windows (x64)**, **macOS (Apple Silicon / Intel)**,
and **Linux (x64 / ARM64)** — no runtime to install.

## Quick Install (Recommended)

**Windows** — open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/muxit-io/muxit/main/install.ps1 | iex
```

This downloads the latest release, extracts it to `%LOCALAPPDATA%\muxit`, and adds it to your PATH.

**macOS / Linux** — open a terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/muxit-io/muxit/main/install.sh | bash
```

The same script detects your OS and CPU architecture and pulls the matching
build — Apple Silicon (`osx-arm64`) or Intel (`osx-x64`) on macOS; `linux-x64`
or `linux-arm64` on Linux. On macOS it also clears the Gatekeeper quarantine
attribute so the unsigned binary launches. See the
[Linux install guide](https://docs.muxit.io/guides/install-linux.md) for distro-specific notes and the
[macOS notes](https://docs.muxit.io/getting-started/system-requirements.md#macos-notes) for what's
supported.

No prerequisites required on any platform — the binary is fully self-contained.

## Manual Download

If you prefer to install manually, grab the archive for your platform from the
[GitHub Releases](https://github.com/muxit-io/muxit/releases/latest) page (the
file name includes the release version):

- **Windows** — download `muxit-win-x64-v<version>.zip`, extract to a folder
  (e.g. `C:\muxit`), and run `muxit.exe`.
- **macOS** — download `muxit-osx-arm64-v<version>.tar.gz` (Apple Silicon) or
  `muxit-osx-x64-v<version>.tar.gz` (Intel), extract it, run
  `xattr -dr com.apple.quarantine <folder>` once to clear Gatekeeper, then run
  `./muxit`.
- **Linux** — download `muxit-linux-x64-v<version>.tar.gz` or
  `muxit-linux-arm64-v<version>.tar.gz`, extract it, and run `./muxit`.

## System Requirements

| Requirement | Details |
|-------------|---------|
| **OS** | Windows 10 or later (x64); macOS 12+ (Apple Silicon / Intel); Linux x64 / ARM64 |
| **Runtime** | None — self-contained binary, no .NET or Node.js needed |
| **Disk space** | ~150 MB |
| **Network** | Required for AI features and license activation; optional otherwise |

See [System Requirements](https://docs.muxit.io/getting-started/system-requirements.md) for the full
platform matrix and the macOS feature notes.

## First Run

After installing, start Muxit:

```powershell
muxit 
```

This starts the server and opens your default browser to `http://localhost:8765`.

On first run, you'll see the **Workspace Setup** screen. Create a new workspace or open an existing one to get started. See [Workspaces](https://docs.muxit.io/guides/workspaces.md) for details.

Other start modes:

```powershell
muxit --nogui               # Start without opening browser
muxit --no-tray             # Start without system tray icon
muxit --port=9000           # Use a custom port
```

## Verify It Works

Once the server is running and the browser opens:

1. **Check the Hardware panel** — Click the plug icon in the left Activity Bar. You should see **test-device** listed with live properties (temperature, label, count, etc.)
2. **Open a demo dashboard** — In the Explorer sidebar, expand `dashboards/` and click `demo.dashboard.json`. You should see live gauges and widgets
3. **Run a script** — In the Explorer sidebar, expand `scripts/` and click `hello.js`. Click the **Run** button in the editor toolbar. Check the Output panel at the bottom for log messages

If you see the test device with updating values, Muxit is working correctly.

---

## What's Included

Muxit ships as a single self-contained package — no hardware needed to get started:

| Category | What's Included |
|----------|----------------|
| **MuxitServer** | Self-contained .NET 9.0 binary (no runtime install needed) |
| **Built-in drivers** | TestDevice, Webcam, ONVIF (IP camera), FileAccess, MqttBridge, WebhookNotifier, EmailNotifier |
| **Example connectors** | test-device, webcam, gui, store, and more in `workspace/connectors/` |
| **Example scripts** | hello.js, examples/sinewave.js, examples/psu-voltage-ramp.js, the `tutorials/` series, and more |
| **Example dashboards** | demo, test-device, gcode, psu, and more |
| **Example agents** | temperature-monitor, pick-and-place |
| **Documentation** | Built-in at `/docs/` in the web UI |

The **TestDevice** is a simulated device that exercises every data type (strings, numbers, booleans, arrays, objects). It's always available and doesn't count against your connector limit — making it the perfect learning tool.

---

## Updating

The easiest way is straight from the app: **Help → Check for Updates…**. When a
newer release is available, Muxit downloads it, installs it in place, and
restarts onto the new version automatically — the page reconnects on its own
when the server is back, and no second browser tab is opened. Your workspace
files (connectors, scripts, dashboards, agents, config) are preserved; everything
the release ships — the binary, its runtime files, the web UI under `wwwroot/`
and `workspace-template/` — is replaced. The previous version is kept in a
`.muxit-update-backup/` folder next to the binary until the update has been
applied, and is removed on the next start.

In-app self-install works on Windows x64, Linux x64, Linux arm64, macOS x64 and
macOS arm64. On other platforms (or builds that can't self-install) the menu
offers a download link instead.

You can also update from the command line:

```bash
muxit update
```

Or re-run the platform installer, which detects the existing installation and
updates in place:

```powershell
irm https://raw.githubusercontent.com/muxit-io/muxit/main/install.ps1 | iex
```

Muxit also checks for updates automatically on startup and surfaces them in the
Help menu.

---

## Troubleshooting

**Installer fails to download** — Check your internet connection. The installer fetches from GitHub Releases. Corporate firewalls may block `raw.githubusercontent.com`.

**Port 8765 already in use** — Another instance of Muxit (or another program) is using the port. Stop the other process or use `--port=9000` to pick a different port.

**`muxit` command not found after install** — Close and reopen your terminal. The installer adds the install directory to your user PATH, but existing terminal sessions need to be restarted.

**Windows SmartScreen warning** — On first run, Windows may show a SmartScreen warning because the binary isn't code-signed yet. Click "More info" then "Run anyway".

**No system tray icon on Windows** — the tray's native library needs the
Microsoft Visual C++ Redistributable (x64), which a clean Windows image does not
have; Windows Sandbox is where this usually shows up. Install it from
<https://aka.ms/vs/17/release/vc_redist.x64.exe> and restart Muxit. `install.ps1`
does this for you. Nothing else depends on it — without the runtime the server
runs normally, just without the tray icon, and the startup log says so.

**No window appears on Windows** — This is expected. Muxit runs in the background behind its system tray icon (near the clock) rather than in a console window, so there's no terminal to accidentally close. Right-click the tray icon for **Open GUI** and **View Logs**, or browse to `http://localhost:8765`. Running `muxit` from a terminal still prints its logs there.

**macOS "cannot be opened" / Gatekeeper** — The macOS builds aren't notarized yet, so Gatekeeper quarantines a downloaded archive. The install script clears this for you; if you extracted a `.tar.gz` by hand, run `xattr -dr com.apple.quarantine <install-dir>` once, then launch `./muxit`.

For more help, see the [Troubleshooting Guide](https://docs.muxit.io/guides/troubleshooting.md).
