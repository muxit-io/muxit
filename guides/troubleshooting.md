---
title: Troubleshooting
description: Common issues and solutions for Muxit — server, devices, scripts, dashboards, and AI.
---

# Troubleshooting

Solutions for common issues you may encounter when using Muxit.

## Server Issues

### Server Won't Start

**"Port 8765 already in use"**
Another process is using the default port. Either:
- Stop the other process (possibly another Muxit instance)
- Use a different port: `node start.js server --port=9000`

**`dotnet: command not found`**
The .NET 9.0 SDK is not installed. Install it from [dotnet.microsoft.com/download](https://dotnet.microsoft.com/download). Verify with `dotnet --version`.

**`node: command not found`**
Node.js is not installed. Install Node.js 18+ from [nodejs.org](https://nodejs.org/).

**Build errors**
Make sure you're using .NET 9.0 (not 8.0 or earlier). Run `dotnet --version` to check. If you haven't built yet, run `node build.js` first.

**macOS: "muxit cannot be opened because the developer cannot be verified"**
macOS release builds aren't code-signed or notarized yet, so Gatekeeper quarantines the downloaded binary. The install script clears this automatically. If you unpacked a release archive by hand, run it once:
```bash
xattr -dr com.apple.quarantine /path/to/muxit-install-dir
```
Then launch `./muxit` again. (You can also right-click the binary in Finder → **Open** → **Open** to approve it once.)

**macOS: camera connector won't capture**
On macOS, USB webcams and Onvif/RTSP cameras capture through the system `ffmpeg` binary (the TestDevice video stream is fully self-contained). If capture fails:
- Install ffmpeg: `brew install ffmpeg`.
- For USB webcams, grant camera access under **System Settings → Privacy & Security → Camera** (a CLI launched from Terminal inherits Terminal's grant). The default `device` index is `0`; try other indices if you have multiple cameras.

**macOS: "Recording is not supported on macOS"**
Expected. Video recording uses OpenCV's `VideoWriter`, which has no macOS native runtime, so `record` / `recordStart` are blocked on macOS. Live streaming and snapshots (including flips and digital zoom) work. The optional Vision *detection* driver is likewise OpenCV-based and unavailable on macOS — record or run local CV detection on a Windows or Linux host.

### Can't See the Web UI

**Browser shows blank page**
The web UI needs to be built before the server can serve it:
```bash
node build.js ui
```

**Wrong URL**
Muxit runs on port **8765** by default: `http://127.0.0.1:8765`. If you used `--port=9000`, use that port instead.

**Firewall blocking**
On Windows, open **Settings → Privacy & security → Windows Security → Firewall & network protection → Allow an app through firewall** and allow `muxit.exe` on your active network profile. For a diagnostic view with copy-paste PowerShell fix commands, open **Settings → Server → Network Diagnostics** inside Muxit.

**Browser cache**
Try a hard refresh (`Ctrl+Shift+R`) or open in an incognito/private window.

---

## Viewing Server Logs

Muxit captures every console line into an in-memory ring buffer (the last 500 entries) and exposes it through a live log viewer at `/logs.html`.

### Three ways to open the viewer

- **System tray** → "View Logs" — works even if the GUI is closed.
- **Title bar** → View → Server Logs.
- **Status bar** → "Logs" button, next to "Panel".

All three open `/logs.html` in a new tab. The page streams new entries via Server-Sent Events (no manual refresh) and supports level filtering (debug/info/warn/error), substring search, pause/resume, and download-as-text.

### Multiple instances on one machine

Each Muxit instance runs on its own port (`8765`, `9000`, …). The log viewer URL is `http://localhost:<port>/logs.html`, so each instance shows only its own logs — no cross-talk.

### When the HTTP server isn't reachable

If the server crashes during boot (port conflict, broken config, exception before Kestrel binds), the live viewer is unreachable. Two fallback files are written per workspace — both overwritten in place, never accumulated:

| File | Written |
|------|---------|
| `startup.log` | On every clean exit (also `Ctrl+C`, `Environment.Exit`). |
| `last-crash.log` | On unhandled exception. |

Paths:

- **Windows**: `%LOCALAPPDATA%\Muxit\logs\<workspace-hash>\`
- **macOS / Linux**: `~/.muxit/logs/<workspace-hash>/`

`<workspace-hash>` is a 12-character SHA prefix of the workspace path, so two instances on different workspaces never overwrite each other's files.

When a `last-crash.log` is present from a previous run, the system tray adds a one-shot **"Open Last Crash Log"** entry that opens it in the OS default text editor.

### Loopback only

`/api/logs`, `/api/logs/stream`, `/api/logs/startup`, and `/api/logs/last-crash` reject non-loopback callers (HTTP 403) — even with a valid remote-access token. A leaked session token cannot be used to scrape diagnostics from a remote host.

---

## Device Connection Issues

### Serial Device Not Connecting

**Wrong port name**
Open **Device Manager → Ports (COM & LPT)** and note the COM port assigned to your adapter (e.g. `COM3`, `COM4`). Unplugging and replugging the cable is the fastest way to spot which entry belongs to your device. Put that port name in the connector's `config.port`.

**Baud rate mismatch**
Make sure the `baudRate` in your connector config matches your device. Common rates: 9600, 19200, 38400, 57600, 115200.

**Device not responding**
- Check the USB cable is connected
- Try unplugging and replugging the device
- Check if another program (Arduino IDE, PuTTY, screen) has the port open — only one program can use a serial port at a time

### TCP Device Not Connecting

**Wrong IP or port**
Verify the device IP is reachable:
```bash
ping 192.168.1.100
```

**Firewall blocking**
Ensure the device's port is not blocked by a firewall on either end.

**Device not on the same network**
Make sure your computer and the device are on the same subnet.

---

## Script Issues

### "connector not found" Error

The connector name in your script must match the filename (without `.js`) in `workspace/connectors/`:
- File: `workspace/connectors/psu.js` → Use: `connector("psu")`
- File: `workspace/connectors/my-device.js` → Use: `connector("my-device")`

Also check:
- The connector is **enabled** in the Hardware panel (disabled connectors can't be accessed)
- You spelled the name correctly (case-sensitive)
- The server has been restarted after creating a new connector file

### "require is not defined" or "import is not supported"

Muxit scripts run in a **sandboxed environment** with no access to Node.js modules. You cannot use:
- `require()` or `import`
- `fs`, `path`, `net`, `http`, `child_process`
- `process`, `global`, `globalThis`

Instead, use the provided globals: `connector()`, `log`, `emit()`, `on()`, `delay()`, `ai()`, etc. See the [Script Guide](https://docs.muxit.io/guides/scripts.md) for all available functions.

### Script Won't Stop

Pressing **Stop** ends a script immediately, wherever it is — including in the middle of a `delay()` or a device call. An endless loop is the normal pattern:
```javascript
while (true) {  // ✓ Stops when you click Stop
  delay(100);
}
```

Scripts with tight loops without `delay()` can still be stopped — the V8 engine is interrupted — but they burn CPU until then. Code after the loop and `finally` blocks never run after Stop.

### Script Timeout

Long-running operations (like `delay(60000)`) are abortable — when you click Stop, `delay()` resolves immediately. If a script seems stuck, click Stop in the editor toolbar or the Explorer sidebar.

### "property is read-only" Error

You're trying to write to a property that only supports reading. Check the connector schema — properties marked `R` (read-only) can't be set. Use the Hardware panel to see property access modes.

---

## Dashboard Issues

### Dashboard Not Updating

**Polling not enabled**
Properties must have polling enabled to update automatically. In the connector config, add the property to the `poll` array:
```javascript
poll: ["temperature", "voltage", "current"],
```

Or set `poll: true` on individual computed properties:
```javascript
properties: {
  power: {
    get: async () => (await driver.voltage) * (await driver.current),
    poll: true,
  },
},
```

**Wrong binding path**
Widget bindings must match exactly:
- `connector` field = connector filename (without `.js`)
- `property` field = property name from the driver or connector

Check the Hardware panel to verify the exact property names.

**Connector disabled**
Disabled connectors don't poll or update. Enable it in the Hardware panel.

### Widgets Showing "N/A" or No Data

The connector may not be initialized yet, or the property doesn't exist. Check:
1. The connector is listed in the Hardware panel
2. The property name is correct (case-sensitive)
3. The device is connected and responding

### Dashboard Won't Save

Make sure editor mode is enabled (Settings > Security > Editor Mode). Without editor mode, file writes are blocked.

---

## AI Issues

### AI Chat Not Responding

**License not active**
Muxit AI requires a valid license. Open Settings (gear icon) and check that your license is active under **License**.

**No internet connection**
Muxit AI connects to `api.muxit.io` for AI requests. Check that your machine can reach the internet.

**Model doesn't support tools**
Some models don't support function calling / tool use. Use a capable model like Claude Sonnet/Opus, GPT-4o, or Gemini 2.0 Flash.

### AI Can't See Camera Images

Vision requires:
1. A camera connector configured and initialized (Webcam or ONVIF)
2. A model that supports vision (Claude Sonnet/Opus, GPT-4o, Gemini)
3. The `take_snapshot` tool to be called

### AI Tool Calls Blocked

Tool-call approvals are driven by the current global safety level. In **Observe** and **Assisted** every device write or action may require your approval — click **Allow** in the approval dialog. To skip approvals, change the safety level (via the StatusStrip SafetyChip) to **Active** or **Unrestricted** — but only if you trust the AI's actions.

---

## WebSocket Issues

### Connection Lost / Reconnecting

The WebSocket connection to the server may drop due to:
- Server restart — the browser auto-reconnects
- Network interruption — check your network connection
- Server crash — check the terminal where the server is running for errors

The status bar at the bottom of the UI shows the connection state.

### "Not authenticated" Error

If accessing Muxit remotely:
1. Make sure remote access is enabled (Settings > Remote Access)
2. Enter your password on the login page
3. If your session expired (24 hours), log in again

For local access (localhost), authentication is automatic.

---

## License Issues

### "Connector limit reached"

Your license tier limits the number of active connectors. The **TestDevice** doesn't count against this limit. Options:
- Disable connectors you're not using (Hardware panel)
- Upgrade your license tier

### Trial Expired

Trial features revert to the free tier when the trial ends. Activate a license key to continue using premium features.

### Running on Free, or a paid feature stopped

Open the [server log viewer](#viewing-server-logs) and search for `License`. Muxit logs what it concluded about your license at startup and when the daily re-check changes something, so the log says which case you are in: the license was verified (and until when), the subscription ended, there was no valid license proof and Muxit is waiting to re-check online, it is running on downgrade grace (and until when operator mode and the audit log keep working), the machine's hardware changed enough that the license needs re-activating, or the system clock is behind the last time Muxit ran. The same lines are in `startup.log` when the server will not come up.

If activation said the key was accepted but Muxit could not get its signed license, the tier stays Free until it does: paid features unlock only from that signed license, never from the activation reply alone. Muxit retries in the background and on the next start; check the machine's internet connection, or activate again.

---

## Performance Issues

### High CPU Usage

Too many properties being polled too frequently. Reduce the load:
- Lower the poll rate: set `polling.connectorRate` to 500 (or higher) in the server configuration
- Remove unnecessary properties from the `poll` array
- Disable unused connectors

### Slow Dashboard Updates

- Reduce the number of widgets on a single dashboard
- Lower chart `duration` (less history = less rendering)
- Check that stream-based widgets (canvas, terminal) aren't receiving data faster than they can render

### Server Memory Growing

The server log ring buffer holds 500 entries. If scripts emit large amounts of data via `emit()` or `stream()`, this can grow. Check for scripts that emit data in tight loops without a delay.

---

## Getting More Help

If your issue isn't covered here:

1. Check the [server logs](#viewing-server-logs) — tray → "View Logs", or the bottom panel (`Ctrl+J`) for script output
2. Run in CLI mode (`node start.js cli`) to test drivers directly
3. Check the terminal where the server is running for .NET error output
4. Report issues at [github.com/muxit-io/muxit/issues](https://github.com/muxit-io/muxit/issues)
