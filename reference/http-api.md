---
title: HTTP API Reference
description: Every HTTP route MuxitServer exposes, with the auth rule for each.
---

# HTTP API Reference

The WebSocket carries the live protocol; these HTTP routes cover what a plain request does
better — sign-in, file reads and writes, the first-run picker, diagnostics from another machine.
The [WebSocket API](https://docs.muxit.io/reference/websocket-api.md) page documents the messages; this page documents the routes.

All routes live under `/api/` on the same origin as the UI (`http://127.0.0.1:8765` by default).
Bodies are JSON unless a route says otherwise; error bodies are `{ error, code? }`.

## Auth rules

Four rules apply, in this order, after one check that every request passes first. Each route below names the ones that matter for it.

**Host check.** Every request — every path, WebSocket upgrades and static files included — must name
this server in its `Host` header, or it is refused with 403 `{ error, code: "HOST_NOT_ALLOWED", hint }`
before any rule below is consulted. Allowed: `localhost`, `*.localhost`, `127.0.0.1`, `[::1]`, the
IP address the connection arrived on, the names in `security.hostnames`, and — with remote access
on — this machine's host name, `<host>.local` and the mDNS name. The port is not compared. This is
what stops DNS rebinding: a rebound page is same-origin with itself, so the same-origin rule below
cannot tell it apart, but its `Host` is the attacker's name. Clients that use `127.0.0.1` or
`localhost` are unaffected; see [Host names](https://docs.muxit.io/guides/remote-access.md#host-names) for tunnels and
proxies.

| Rule | What it means |
|------|---------------|
| **Same-origin writes** | Every POST, PUT and DELETE under `/api/` and `/mcp` that carries a browser `Origin` or `Sec-Fetch-Site` header must be same-origin, or it is refused with 403 `CROSS_ORIGIN_BLOCKED`. Non-browser clients send neither header and are unaffected. |
| **Token** | With `security.remoteAccess` on, a non-loopback request needs the remote-access token — password or not; with no password set there is nothing to log in with, so the request gets 401 `REMOTE_PASSWORD_NOT_SET` unless it holds the startup token: `X-Auth-Token: <token>` (or `?token=` for `<img>`-style loads). The token is the `sessionToken` from `POST /api/auth/login`, or the startup token read from `workspace/config/.auth-token` by something with access to the machine. Loopback requests never need it. `/api/auth/login`, `/api/auth/status`, `/api/auth/token` and `/api/eula/*` are exempt so a client can get in before it has one. |
| **Loopback only** | Answers only from the machine itself, whatever token is presented. |
| **Write gate** | The [operator-mode](https://docs.muxit.io/guides/operator-mode.md) verdict, read from the `X-Muxit-Account` header: an admin or engineer passes, a signed-in operator or an anonymous caller on a locked station (or under the `login` visitor policy) gets 403 with `OPERATOR_MODE_RESTRICTED` or `OPERATOR_SIGN_IN_REQUIRED`. Reads are never gated. |

An account-session token (from [`/api/accounts/login`](#accounts)) is a second credential on top of
the transport token — it says *who* is acting, and travels only as `X-Muxit-Account` on HTTP or
the `account-<token>` subprotocol on the socket, never in the query string.

## Remote access

| Route | Auth | Description |
|-------|------|-------------|
| `GET /api/auth/token` | Loopback only, same-origin browser fetch | `{ token }` — the startup token, for the UI's own bootstrap. 403 `{ requiresLogin: true }` from any other host; non-browser clients read `workspace/config/.auth-token` instead |
| `GET /api/auth/status` | None | `{ remoteAccess, isLocal, requiresLogin, hasPassword, httpsEnabled, sessionValid, localAddresses }`. `requiresLogin` is true for every non-loopback caller while remote access is on, even before a password is set (the login page then reports that none is). `sessionValid` is set when the request presents a token, so a UI can detect a stale one after a restart |
| `POST /api/auth/login` | None | `{ password }` → `{ sessionToken }` — the only credential a remote client is given; use it as `X-Auth-Token` and as the WebSocket `auth-<token>` subprotocol. It ends on logout, on a password change and after 24 hours, and a WebSocket opened with it is then closed with code `4401`. 401 `{ error, retryAfter }` on a wrong password, 429 `{ error, retryAfter }` when rate-limited (5 per minute per IP), 503 `{ error, code: "REMOTE_PASSWORD_NOT_SET" }` when no password is configured |
| `POST /api/auth/logout` | Token | Ends the presented session token. `{ status: "logged_out" }` |
| `POST /api/auth/password` | Loopback, or Token | `{ password }` sets the remote-access password (8+ characters, upper, lower, digit). Ends every remote session |
| `DELETE /api/auth/password` | Loopback only | Removes the password. Ends every remote session |

## Accounts

[User accounts](https://docs.muxit.io/guides/accounts.md) — admin, engineer and operator sign-in with a PIN. The
account feature is Pro and up; while the tier blocks it, writes here return 403 with
`blockedReason` and the store is not loaded.

| Route | Auth | Description |
|-------|------|-------------|
| `GET /api/accounts` | Token | `{ available, blockedReason, graceUntil, graceReason, graceCause, configured, hasAdmin, canBootstrap, anonymous, idleTimeoutMinutes, accounts: [{ id, name, role }], roles, pinMinimum: { admin, engineer, operator } }`. Names and roles only, never hashes; readable by anyone who can reach the server, because the sign-in screen needs the list |
| `GET /api/accounts/session` | Token + `X-Muxit-Account` | Who the presented account token belongs to: `{ id, name, role }`, or 401. Lets a reloaded tab restore its session |
| `POST /api/accounts/login` | Token | `{ id, pin }` → `{ token, id, name, role }`. One undifferentiated 401 `{ error, retryAfter }` for an unknown id, a wrong PIN or a lockout (per IP and per account, 30 s doubling to 15 min after five failures) |
| `POST /api/accounts/logout` | Token | Ends the presented account token. `{ ok: true }` |
| `POST /api/accounts` | Admin | `{ id, name, role, pin? }` creates or updates an account; an absent `pin` keeps the current one, a new one ends that account's sessions. → `{ ok, accounts, hasAdmin }`. The first account must be an admin |
| `POST /api/accounts/delete` | Admin | `{ id }` → `{ ok, accounts }`. Ends the account's sessions |
| `POST /api/accounts/policy` | Admin | `{ anonymous?, idleTimeoutMinutes? }` — `anonymous` is `full`, `dashboard` or `login`; `dashboard` needs a license covering operator mode (400 `OPERATOR_MODE_RESTRICTED` otherwise). → `{ ok, anonymous, idleTimeoutMinutes }` |

**Admin** means a caller whose `X-Muxit-Account` resolves to an admin. Before any admin exists,
the three management routes accept a loopback caller or one holding the transport token, so the
first admin can be created; a signed-in operator or engineer never qualifies on their own.

## Operator mode

| Route | Auth | Description |
|-------|------|-------------|
| `GET /api/operator` | Token | Station status for the shell: `{ enabled, licenseBlocked, graceUntil, graceReason, graceCause, chatEnabled, chatDashboards, hasContent, dashboards, landing, scripts, scriptCount, folder, accountsConfigured, anonymous, hasAuthor, accounts }`. `enabled` is the effective state (policy asks for a locked station *and* the license allows it); operator content is whatever sits under `scripts/operator/` and `dashboards/operator/` |

## Dashboards, assets and labels

Always registered, editor mode or not — production panels run with editor mode off and still
need their dashboards, logos and label templates.

| Route | Auth | Description |
|-------|------|-------------|
| `GET /api/dashboards` | Token | `[{ name, path }]`, recursive under `workspace/dashboards/`, forward-slash relative names |
| `GET /api/dashboards/{name}` | Token | The dashboard JSON as text. 400 on a bad name, 404 when missing |
| `PUT /api/dashboards/{name}` | Token, write gate | Body is the dashboard JSON (must parse). → `{ name, path }`. 400 on invalid JSON, 404 when the target folder does not exist |
| `GET /api/assets/{path}` | Token (`?token=` allowed) | A file from `workspace/assets/` with its media type. Images, `mp4`/`webm`, `mp3`/`wav`/`ogg` and `pdf` only; `..` and anything outside the folder are refused |
| `GET /api/labels` | Token | `[{ name, path }]` — the label templates |
| `GET /api/labels/{name}` | Token | Raw template JSON. 400 / 404 as for dashboards |
| `PUT /api/labels/{name}` | Token, write gate | Validate and save. 200 `{ name, path, warnings }`, 400 `{ error, errors }` |
| `DELETE /api/labels/{name}` | Token, write gate | 204, or 404 `{ error }` |

## Connectors and scripts

Creation only — content is edited through the editor routes, and scripts run by name over the
WebSocket.

| Route | Auth | Description |
|-------|------|-------------|
| `POST /api/connectors` | Token, write gate | `{ baseName, content }` writes a new `workspace/connectors/<baseName>.js`, suffixing the name if it exists. → `{ name, fileName, path }` |
| `HEAD /api/connectors/{name}` | Token | 200 when `connectors/<name>.js` exists, 404 otherwise |
| `GET /api/scripts` | Token | `[{ name, fileName, path, running }]` for `workspace/scripts/*.js` |
| `POST /api/scripts` | Token, write gate | Body is the script text; creates `scripts/new-script.js` (or `new-script-N.js`). → `{ name, fileName, path }` |
| `GET /api/startup-scripts` | Token | Same shape for `workspace/startup/*.js`; startup scripts run at boot on Maker and up |
| `POST /api/startup-scripts` | Token, write gate | As `POST /api/scripts`, into `startup/` |

## Editor

Registered only when `security.editorMode` is true. Every route needs the **startup token**
exactly — an account-session token is not enough — and is refused for a gated caller. Paths are
workspace-relative; `config/` is never readable and `config/` and `drivers/` are never writable
(403 `PATH_FORBIDDEN`).

| Route | Description |
|-------|-------------|
| `GET /api/editor/files?path=` | Directory listing: `[{ name, path, type: "directory" \| "file", size? }]`. Empty path is the workspace root; `config/` is hidden |
| `GET /api/editor/files/{path}` | File content as text |
| `HEAD /api/editor/files/{path}` | 200 / 404 |
| `PUT /api/editor/files/{path}` | Body is the new content; creates parent folders |
| `DELETE /api/editor/files/{path}` | 200 / 404 |
| `POST /api/editor/rename` | `{ oldPath, newPath }` — rename or move |
| `POST /api/editor/mkdir` | `{ path }` |
| `GET /api/editor/raw/{path}` | The file with a proper media type (images, video, …) for previews |
| `POST /api/editor/reveal` | `{ path }` — show the file in the OS file manager |
| `POST /api/editor/open-with` | `{ path }` — open with the system default app. Executable and scriptable extensions are refused with 403 `{ error, extension }` |

## Workspaces and the picker

| Route | Auth | Description |
|-------|------|-------------|
| `GET /api/workspaces` | Token | The catalog: `[{ path, name, lastOpened, exists }]`, most recent first. Entries whose folder was deleted are dropped from the catalog first; `exists: false` is left only for a folder whose parent is missing too (a drive or share that is not connected) |
| `GET /api/workspaces/current` | Token | `{ path, name }` of the open workspace |
| `GET /api/boot-mode` | Token | `{ mode: "picker" \| "ready" }` — whether the server is still waiting for a workspace to be chosen |
| `GET /api/picker/slot-status` | Token | `{ atCap, tier?, limit?, taken?, upgradeUrl? }` — the concurrent-instance cap, for the picker's banner |
| `POST /api/workspaces` | Token, write gate | `{ path, name }` creates a workspace in a new or empty directory. → `{ path, name, created: true }` |
| `POST /api/workspaces/open` | Token, write gate | `{ path }` adds an existing workspace to the catalog. → `{ path, name }` |
| `POST /api/workspaces/switch` | Token, write gate | `{ path }` restarts into that workspace. 403 with the cap details when the tier's instance limit is reached |
| `POST /api/workspaces/rename` | Token, write gate | `{ path, name }` renames the catalog entry |
| `POST /api/workspaces/remove` | Token, write gate | `{ path }` removes it from the catalog; no files are deleted |
| `GET /api/workspaces/browse?path=` | Token | Directory list for the folder picker |
| `POST /api/workspaces/browse/mkdir` | Token, write gate | `{ path }` creates a directory for the picker |

## Workspace EULA

Reachable before anything else, because a workspace stays in Sandbox mode (reads work, hardware
writes and `scripts.start` fail with `EULA_NOT_ACCEPTED`) until the EULA is accepted.

| Route | Auth | Description |
|-------|------|-------------|
| `GET /api/eula` | None | `{ currentVersion, isAccepted, reason, acceptedVersion, acceptedAt, acceptedBy, acceptedLicenseId, acceptedInstanceId, writeLockReason, canonicalText, canonicalHash }`. `reason` is `EulaMissing`, `EulaCorrupt` or `EulaOutdated` |
| `GET /api/eula/text?version=` | None | The canonical text as `text/markdown`; 404 `EULA_UNKNOWN_VERSION` for a version the server does not ship |
| `POST /api/eula/accept` | Same-origin | `{ userIdentifier }` → `{ isAccepted, acceptedVersion, acceptedAt, acceptedBy, acceptedLicenseId, acceptedInstanceId }`. Unlocks the workspace |
| `GET /api/eula/history` | None | The append-only acceptance history, newest first |

## Diagnostics and logs

| Route | Auth | Description |
|-------|------|-------------|
| `GET /api/diagnostics/network` | Token | `{ bind, os, interfaces, firewall, mdns, hints, verbose, fixCommands? }`. Full report from loopback; a redacted one (no interface IPs, firewall rules or fix commands) for anyone else, so a leaked token cannot map the host |
| `GET /api/logs` | Loopback only | The server log ring buffer: `[{ level, source, message, time }]`, oldest first |
| `GET /api/logs/stream` | Loopback only | Server-Sent Events, one `data: {…}` per new entry (same shape), after replaying the buffer |
| `GET /api/logs/startup` | Loopback only | The bootstrap log on disk as `text/plain`, 404 when there is none |
| `GET /api/logs/last-crash` | Loopback only | The last crash dump as `text/plain`, 404 when there is none |

## Server

| Route | Auth | Description |
|-------|------|-------------|
| `GET /api/mcp/config` | Token | `{ installDir, workspacePath, port, httpUrl }` — what the Settings MCP setup guide shows |
| `POST /api/server/restart` | Loopback, or Token | Writes the restart marker and exits so the service manager relaunches the server |
| `/mcp` | Token | The [MCP](https://docs.muxit.io/guides/ai.md#_2-mcp-server) endpoint (streamable HTTP). Only a caller who may author gets through: 403 `OPERATOR_MODE_RESTRICTED` for a gated caller, and 403 `OPERATOR_SIGN_IN_REQUIRED` for an anonymous one under the `login` visitor policy — send an engineer's or admin's account token as `X-Muxit-Account` |
