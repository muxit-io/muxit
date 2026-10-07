---
title: Remote Access
description: Access Muxit from other computers on your network — or anywhere via VPN.
---

# Remote Access

Access Muxit from other computers on your network — or anywhere via VPN.

::: tip Paid feature
Remote access is available from the **Maker** tier upward. On the Free tier
the toggle is disabled in Settings and the server stays bound to `localhost`;
Bonjour/mDNS advertisements are also held back, so nothing leaks onto the
LAN. Open **Settings → Subscription** to upgrade.
:::

## Quick Setup (LAN)

1. Open **Settings > Remote Access** in the Muxit UI
2. Toggle **Enable Remote Access** on
3. Set a **password** (min 8 characters, must include uppercase, lowercase, and a digit)
4. **Restart** the Muxit server
5. Open `http://<server-ip>:8765` on another computer
6. Enter your password — done!

> **Tip:** Find your server's IP address with `ipconfig` (Windows).

Until a password is set, other computers are refused — every API call gets `401` and the login
page says a password is needed. Turning remote access on without one does not open anything.

## How It Works

| Feature | Local (localhost) | Remote (LAN) |
|---------|-------------------|--------------|
| Password required | No | Yes |
| Auth token | Auto-fetched | Obtained via login |
| WebSocket | Connects automatically | Connects after login |
| All APIs | Full access | Full access after login |
| Editor mode | Works if enabled | Works if enabled |

**Local access is never affected.** When accessing Muxit from the same machine (localhost/127.0.0.1), everything works exactly as before — no password, no login page.

## HTTPS (Optional)

Enable **HTTPS (Self-Signed)** in Settings for encrypted connections:

- A self-signed certificate is generated automatically on first use
- Your browser will show a security warning — click "Advanced" > "Accept the Risk" (once per browser)
- All traffic (including your password) is encrypted over the network
- The certificate is stored in `workspace/config/muxit.pfx`

**When to use HTTPS:**
- Shared/untrusted network
- Sensitive data passes through Muxit (API keys, instrument data)
- Prevent password sniffing on the LAN

**When HTTP is fine:**
- Private home/lab network with trusted users

## Settings Reference

| Setting | Config Path | Default | Description |
|---------|------------|---------|-------------|
| Remote Access | `security.remoteAccess` | `false` | Bind to 0.0.0.0 (all interfaces). Requires **Maker** — on Free, the flag is honoured in config but overridden to loopback at startup. |
| HTTPS | `security.https` | `false` | Enable HTTPS with self-signed cert |
| Bind Address | `security.bindAddress` | `127.0.0.1` | Override bind address (advanced) |
| Extra host names | `security.hostnames` | `[]` | Extra names browsers may use to reach Muxit — see [Host names](#host-names) |

These can also be set directly in `workspace/config/server.json`:

```json
{
  "security": {
    "editorMode": true,
    "remoteAccess": true,
    "https": false,
    "bindAddress": "127.0.0.1"
  }
}
```

## Host Names

Muxit only answers to names it knows are its own. A request whose `Host` header names anything
else is refused with `403` and `"code": "HOST_NOT_ALLOWED"` before it reaches anything else — the
API, the WebSocket, `/mcp`, even the page itself.

This is what stops **DNS rebinding**: a website you visit points its own domain at `127.0.0.1`
and then talks to Muxit "from the same origin". Every other check sees a same-origin request from
the local machine; the name in the `Host` header is the one thing that gives it away.

Always allowed:

- `localhost` (and `*.localhost`), `127.0.0.1`, `[::1]` — on any port
- the IP address the request arrived on, e.g. `http://192.168.1.20:8765` or a Tailscale IP
- the names you list in `security.hostnames`

Also allowed when remote access is on:

- this machine's host name (`LAB-PC`), `LAB-PC.local`, and its DNS domain name
  (`lab-pc.corp.example.com`) if it has one
- the mDNS name, `muxit.local` by default (see [Network Discovery](#network-discovery-bonjour-mdns))

Anything else — a Tailscale MagicDNS name like `lab-pc.tail1234.ts.net`, a tunnel's public name,
a reverse proxy's name, a public IP your router forwards — has to be listed, under
**Settings > Remote Access > Extra host names** or in `server.json`:

```json
{
  "security": {
    "hostnames": ["lab-pc.tail1234.ts.net", "*.lab.example.com"]
  }
}
```

`*.example.com` covers every subdomain of a domain **you control** (not `example.com` itself). A
bare `"*"` or a wildcard over one label such as `"*.com"` is ignored with a warning: either would
let any website back in. Restart the server after changing the list; the startup banner prints
the names it accepts.

Programs that connect to `127.0.0.1` or `localhost` — the CLI, MCP clients, Python scripts — are
not affected.

## Network Discovery (Bonjour/mDNS)

When remote access is enabled, Muxit can advertise itself on your local network using mDNS (also known as Bonjour). This lets any device on the LAN find the server at `muxit.local` without needing to know the IP address.

### Setup

1. Enable **Remote Access** (see above)
2. Open **Settings > Server > Network Discovery**
3. Toggle **Enable mDNS** on (enabled by default)
4. Optionally change the **Hostname** (default: `muxit`)
5. **Restart** the server

Other devices on the network can now reach Muxit at `http://muxit.local:8765`.

### Clean URL (No Port)

To access the server as just `http://muxit.local` (no port number), set the server port to **80**:

- In the GUI: set **Server Port** to `80`
- Or in `server.json`: `"websocket": { "port": 80 }`

### Multiple Instances

If you run multiple Muxit servers on the same network, give each a unique hostname:

```json
{
  "discovery": {
    "enabled": true,
    "hostname": "muxit-lab2"
  }
}
```

This server will be reachable at `muxit-lab2.local`.

### Settings Reference

| Setting | Config Path | Default | Description |
|---------|------------|---------|-------------|
| Enable mDNS | `discovery.enabled` | `true` | Advertise the server via mDNS |
| Hostname | `discovery.hostname` | `muxit` | The `.local` hostname to advertise |

### How It Works

Muxit uses mDNS (multicast DNS, RFC 6762) to respond to `.local` hostname queries on the LAN. It also advertises an `_http._tcp` service for DNS-SD (service discovery), so network browsers and IoT tools can find it automatically.

mDNS is supported natively on Windows 10+.

## Security Details

### Authentication Flow

1. **Local user** opens Muxit → token auto-fetched from `/api/auth/token` (loopback-only) → connected
2. **Remote user** opens Muxit → token fetch returns 403 → login page shown → password submitted → session token issued → connected

### Session Tokens

- Valid for 24 hours
- Stored in browser `sessionStorage` (cleared when tab closes)
- One session per login (multiple tabs share the same session)

### Rate Limiting

Failed login attempts are rate-limited to 5 per minute per IP address. After 5 failed attempts, the IP is blocked for 60 seconds.

### Password Storage

Passwords are hashed using PBKDF2 (SHA-256, 100K iterations) with a random salt. The hash is stored in `workspace/config/security.json` — the plaintext password is never saved.

### Writes Must Come From Muxit's Own Pages

Any website you visit in the same browser can send requests to Muxit's address, and they arrive
looking like local traffic. Muxit therefore refuses any request that **changes** something — creating
a script, editing a connector, adding an account, restarting the server — when the browser says it
came from a different site. Reading is unaffected.

This is invisible in normal use, and it does not apply to tools that aren't browsers: the CLI, MCP
clients and scripts using the WebSocket API send no browser origin and are unaffected.

It does affect one case: **driving Muxit from your own web page served from a different address.**
Those writes will be refused. Use the WebSocket API, or serve your page from Muxit itself.

A reverse proxy in front of Muxit also changes the address the browser sees. Muxit does not read
`X-Forwarded-*` headers. A proxy that passes its own name through as the `Host` is refused until
that name is in [`security.hostnames`](#host-names); one that rewrites the `Host` to `127.0.0.1`
gets through the host check but has its writes refused, because the browser's `Origin` no longer
matches. And, separately, a proxy on the same machine makes every visitor look local to Muxit.
Prefer Tailscale (below) over a proxy.

## Internet Access via Tailscale

For accessing your lab from outside your network, we recommend [Tailscale](https://tailscale.com):

1. Install Tailscale on the Muxit server and your remote device
2. Join both to the same Tailscale network (free for personal use)
3. Enable Remote Access in Muxit Settings
4. Access Muxit via `http://<tailscale-ip>:8765`

Tailscale provides WireGuard encryption, so HTTPS is not needed.

The Tailscale IP works as is. To use the MagicDNS name instead (`http://lab-pc.tail1234.ts.net:8765`),
or to put Muxit behind `tailscale serve`, add that name to [`security.hostnames`](#host-names). The
short name (`http://lab-pc:8765`) is this machine's host name, which is already allowed.

## Troubleshooting

**"Remote access is not enabled" error:**
Enable Remote Access in Settings and restart the server.

**"This server does not answer to the host name …" (`HOST_NOT_ALLOWED`):**
You reached Muxit by a name it does not know is its own — usually a Tailscale MagicDNS name, a
tunnel, or a reverse proxy. Add the name from the message to [`security.hostnames`](#host-names) and
restart. The server's log shows each refused name once a minute.

**"Remote access has no password yet" (`REMOTE_PASSWORD_NOT_SET`):**
Set a password under **Settings > Remote Access** on the server machine (open it at
`http://localhost:8765` there).

**Can't connect from another computer:**

Open **Settings → Server → Network Diagnostics** in the Muxit UI. The panel shows:

- The address Muxit is actually bound to and whether Kestrel's TCP listener is up.
- Your network interfaces and which ones mDNS advertises on.
- On Windows: the active firewall profile, whether an allow rule covers your port, and any `Block` rules for `muxit` that override `Allow` rules.
- mDNS query/answer counters (if the counter stays at 0 while a remote device tries to reach you, packets aren't arriving — usually a router AP-isolation setting or a firewall).
- Copy-paste PowerShell fix commands for the common Windows issues (add allow rule for the port, delete stale block rules, set the active network profile to Private).

The same data is available as JSON at `GET /api/diagnostics/network` if you want to curl it from the problem device.

Common causes, in rough order of frequency:

1. **Windows network category is Public** — the default firewall profile blocks most inbound connections. Either change the network to Private (`Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private`) or add a port-based allow rule: `New-NetFirewallRule -DisplayName "Muxit Server 8765" -Direction Inbound -Protocol TCP -LocalPort 8765 -Profile Any -Action Allow` (run in elevated PowerShell).
2. **A leftover Windows Firewall Block rule** for `muxit.exe` overrides any Allow rules. Delete it: `Get-NetFirewallRule -DisplayName "*muxit*" | Where-Object Action -eq Block | Remove-NetFirewallRule`.
3. **Router "client isolation" or guest Wi-Fi** — many consumer routers block client-to-client traffic on guest SSIDs. Put the problem device on the main SSID or disable isolation in router admin.
4. **Phone connected to a different SSID/VLAN** than the server PC. Check that both show IPs on the same subnet.
5. **Kestrel port binding conflict** — if the diagnostics panel shows `TCP listener: NO — Kestrel did not bind`, another process (IIS, Skype, a previous Muxit run) is holding the port. `netstat -ano | findstr :<port>` finds the owner.
6. **HTTPS enabled, client using `http://`** — when `security.https: true`, Kestrel speaks only TLS on its listener. A plain `http://` request gets a `ERR_CONNECTION_ABORTED`. Use `https://` from every client, or disable HTTPS.

**Forgot password:**
Delete `workspace/config/security.json` on the server machine and restart.

**Browser shows certificate warning (HTTPS):**
Expected with self-signed certificates. Click through the warning once per browser.

## Mobile Access

Muxit includes a touch-optimized mobile interface that activates automatically on screens narrower than 768px (phones and small tablets in portrait). When you open Muxit in a mobile browser, you'll see a simplified five-tab layout:

| Tab | What It Does |
|-----|-------------|
| **Dashboards** | View live dashboard widgets in a vertical flow layout. Swipe between dashboards using the pill bar. |
| **Devices** | Accordion list of connectors with live state values. Tap a property to edit writable values. Trigger actions with buttons. |
| **Chat** | Full-screen AI chat with voice input. Same AI capabilities as the desktop chat sidebar. |
| **Scripts** | Start/stop scripts and view log output with per-script filtering. |
| **More** | Server status, license info, recent error alerts, and a "Switch to Desktop" option. |

A floating microphone button provides voice input from any tab.

### Force Desktop Mode

If you prefer the full desktop interface on a mobile device, tap **More > Switch to Desktop**. To return to the mobile view, clear `muxit-force-desktop` from your browser's localStorage.
