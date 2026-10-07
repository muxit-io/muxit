---
title: WebSocket API Reference
description: Complete WebSocket protocol specification for MuxitServer.
---

# WebSocket API Reference

MuxitServer exposes a WebSocket server for browser clients. All messages are JSON objects with a `type` field.

## Connection

```
ws://localhost:8765/ws
wss://localhost:8765/ws  (when HTTPS enabled)
```

Default port is 8765, configurable in `workspace/config/server.json`.

### WebSocket Authentication

The auth token is sent via the `Sec-WebSocket-Protocol` header to avoid token exposure in server/proxy access logs:

```javascript
// Browser client — token sent as subprotocol
const ws = new WebSocket("ws://localhost:8765/ws", ["muxit", "auth-YOUR_TOKEN"]);
```

The server extracts the token from any subprotocol prefixed with `auth-`, and accepts the `muxit` subprotocol. Query string `?token=` is still accepted for the asset and raw-file URLs (an `<img>` cannot send a header) and for non-browser clients, but is not recommended: query strings end up in proxy and server logs. An account (PIN session) token is **never** read from the query string — send it as the `account-<token>` subprotocol on a socket, or the `X-Muxit-Account` header on HTTP.

## Authentication

### Local Access (Loopback)
The UI auto-fetches the auth token via `GET /api/auth/token` (loopback-only endpoint). No user interaction needed.

### Host check
The upgrade request's `Host` header must be one of this server's names — `localhost`, `127.0.0.1`,
`[::1]`, the address the connection arrived on, a name from `security.hostnames`, or (with remote
access on) this machine's host name and mDNS name. Anything else gets 403 before the origin or the
token is looked at. That is the DNS-rebinding defence; an `Origin` check alone cannot be one,
because a rebound page's `Origin` matches its own `Host`. See the
[HTTP API auth rules](https://docs.muxit.io/reference/http-api.md#auth-rules).

### Remote Access
When `security.remoteAccess` is enabled, a non-loopback client needs a token. With no password set,
there is no way to get one (`POST /api/auth/login` answers 503) short of the startup token from the
machine itself. Once a password is set:

1. `GET /api/auth/token` returns 403 for non-loopback requests
2. `GET /api/auth/status` returns `{ requiresLogin: true, ... }`
3. `POST /api/auth/login` with `{ "password": "..." }` returns `{ "sessionToken": "<session>" }`
4. Use the session token for WebSocket connections (as the `auth-<token>` subprotocol) and HTTP API calls (`X-Auth-Token` header)

The session ends when the client logs out (`POST /api/auth/logout`), when the password is changed
or removed, and after 24 hours. A WebSocket that was opened with it is then closed by the server
with close code **`4401`**; log in again rather than reconnecting with the same token.

### Account sign-in (operator mode and user accounts)

The remote-access token above says a client may reach the server. A second, independent
credential says *who* is acting: an **account-session token**, issued by
`POST /api/accounts/login { id, pin }` (see the [HTTP API](https://docs.muxit.io/reference/http-api.md#accounts)) on stations
with [user accounts](https://docs.muxit.io/guides/accounts.md). It travels separately from the auth token and is never
read from the query string:

```javascript
// Browser client — both tokens as subprotocols
const ws = new WebSocket("ws://localhost:8765/ws", ["muxit", "auth-YOUR_TOKEN", "account-SESSION_TOKEN"]);
```

```http
X-Muxit-Account: SESSION_TOKEN     # the same token on HTTP calls
```

The server resolves the token on **every message**, not once per connection, so a sign-out or a
shift change takes effect immediately. A stale, unknown or idle-timed-out token resolves to nobody
and the socket is treated as anonymous. To change who a live socket speaks for without reconnecting,
send [`session.identify`](#session-identify).

Whether a message is allowed depends on the resolved identity and the station's
[anonymous-visitor policy](https://docs.muxit.io/guides/operator-mode.md):

| Caller | Station | Verdict |
|--------|---------|---------|
| Admin or engineer | any | every message |
| Signed-in operator | any | the operator surface: dashboard reads and controls, `scripts.start` of scripts under `operator/`, chat only when an operator dashboard opts in |
| Anonymous | policy `full` | every message (the default install) |
| Anonymous | policy `dashboard` (operator mode) | the operator surface, as above |
| Anonymous | policy `login` | reads only; every act needs a sign-in first |

A refused message gets an error with `OPERATOR_SIGN_IN_REQUIRED` when signing in would fix it
(the `login` policy), or `OPERATOR_MODE_RESTRICTED` when it would not. Refusals happen before the
handler runs and before any rate budget is spent. `license.get` also uses the identity: an
anonymous or operator caller gets the tier and feature matrix but not the customer name and
email.

### Password Requirements
Passwords must meet all of the following:
- At least 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one digit

### HTTP API Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/auth/token` | GET | Loopback only | Get startup auth token |
| `/api/auth/status` | GET | None | Check auth requirements |
| `/api/auth/login` | POST | None | Authenticate with password |
| `/api/auth/password` | POST | Local or authenticated | Set/update access password |
| `/api/auth/password` | DELETE | Local only | Remove access password |
| `/api/labels` | GET | Token | List label templates (`[{ name, path }]`) |
| `/api/labels/{name}` | GET / PUT / DELETE | Token | Read, validate + save, or delete `workspace/labels/<name>.label.json` (PUT returns `{ name, path, warnings }`, 400 `{ error, errors }`) |

The full route list, with the auth rule for each, is on the [HTTP API](https://docs.muxit.io/reference/http-api.md) page.

### Rate Limiting
Login attempts are limited to 5 per minute per IP. Returns HTTP 429 with `{ "retryAfter": <seconds> }`.

---

## Message Format

### Request (client → server)

```json
{
  "type": "message.type",
  "requestId": "optional-correlation-id",
  ...
}
```

### Response (server → client)

```json
{
  "type": "response.type",
  "requestId": "echoed-if-provided",
  "value": ...
}
```

### Error

```json
{
  "type": "error",
  "code": "CONN_NOT_FOUND",
  "requestId": "echoed-if-provided",
  "message": "Human-readable error description"
}
```

The `code` field is a structured error code (UPPER_SNAKE_CASE) for programmatic error handling. See [Error Codes](#error-codes) for the full list.

---

## Error Codes

All error responses include a `code` field from the table below. Use these codes for programmatic error handling and when reporting issues.

### Protocol Errors

| Code | Description |
|------|-------------|
| `PROTOCOL_INVALID_JSON` | Message could not be parsed as JSON |
| `PROTOCOL_MISSING_TYPE` | Message has no `type` field |
| `PROTOCOL_UNKNOWN_TYPE` | Message `type` does not match any handler |
| `WS_RATE_LIMITED` | Too many calls per second on this socket. Hardware, script, AI, agent and marketplace types share one budget (`security.rateLimit.callsPerSec`, default 50/s); `labels.preview` has its own (`security.rateLimit.previewsPerSec`, default 5/s). The message names the type and the limit |
| `OPERATOR_MODE_RESTRICTED` | The message is outside the operator surface and the caller is held to it — see [Account sign-in](#account-sign-in-operator-mode-and-user-accounts). Signing in as an operator does not help; an engineer or admin sign-in does |
| `OPERATOR_SIGN_IN_REQUIRED` | The anonymous-visitor policy is `login` and this message is an act. The UI raises the sign-in prompt on this code instead of showing an error |

### Validation Errors

| Code | Description |
|------|-------------|
| `VALIDATION_MISSING_PARAM` | A required parameter is missing from the request |
| `VALIDATION_INVALID_VALUE` | A parameter has an invalid value |

### Connector Errors

| Code | Description |
|------|-------------|
| `CONN_NOT_FOUND` | The specified connector does not exist |
| `CONN_NOT_INITIALIZED` | The connector exists but has not been initialized |
| `CONN_LOAD_FAILED` | The connector config file failed to parse or load |
| `CONN_CALL_FAILED` | A method call on the connector failed |
| `CONN_DISABLED` | The connector is disabled |
| `CONN_LIMIT_REACHED` | License tier connector limit exceeded |
| `CONN_RELOAD_FAILED` | Hot-reload of connectors failed |
| `CONN_METHOD_NOT_FOUND` | `connector.call` named a method or property the connector does not have. The message lists what it does have |

### Driver Errors

| Code | Description |
|------|-------------|
| `DRIVER_NOT_FOUND` | The specified driver does not exist in the registry |
| `DRIVER_LOAD_FAILED` | The driver DLL/assembly failed to load |
| `DRIVER_BLOCKED` | The driver requires a license that is not active |
| `VIDEO_RECORDING_REQUIRES_MAKER` | `record` / `recordStart` on a camera connector need a Maker license or higher |

### Script Errors

| Code | Description |
|------|-------------|
| `SCRIPT_NOT_FOUND` | The script file was not found |
| `SCRIPT_ALREADY_RUNNING` | A script with this name is already running |
| `SCRIPT_EXEC_FAILED` | The script threw an error during V8 execution |
| `SCRIPT_LIMIT_REACHED` | License tier concurrent script limit exceeded |
| `EDITOR_MODE_DISABLED` | `security.editorMode` is off, so `scripts.execute` is refused |
| `PATH_OUTSIDE_WORKSPACE` | A connector or script named a file outside the workspace (File Access `basePath`, an attachment, an image, a recording name, label templates) |

### Prompt Errors

| Code | Description |
|------|-------------|
| `PROMPT_TIMEOUT` | `ask.*` timed out with no `default` configured |
| `PROMPT_NOT_FOUND` | `prompts.answer` referenced an id that is no longer open |

### Agent Errors

| Code | Description |
|------|-------------|
| `AGENT_NOT_FOUND` | The agent config or instance was not found |
| `AGENT_LIMIT_REACHED` | Maximum concurrent agents limit exceeded |
| `AGENT_SAFETY_BLOCKED` | The safety gate blocked the action (rate, workspace, speed, force) |
| `AGENT_DEVICE_MISSING` | A required device for the agent is not available |
| `AGENT_AI_NOT_CONFIGURED` | No AI provider configured for the agent |
| `AGENT_START_FAILED` | The agent failed to start |

### License Errors

| Code | Description |
|------|-------------|
| `LICENSE_LIMIT` | A generic license tier limit was exceeded |
| `LICENSE_ACTIVATION_FAILED` | License key activation failed |
| `LICENSE_EXPIRED` | The license subscription has expired |
| `LICENSE_DEACTIVATION_FAILED` | License deactivation failed |
| `SAFETY_REQUIRES_PRO` | `safety.setLevel` asked for a level the tier does not include (each level is its own feature id). Observe and Unrestricted are on every tier |

### Auth Errors

| Code | Description |
|------|-------------|
| `AUTH_RATE_LIMITED` | Too many login attempts — try again later |
| `AUTH_INVALID_SESSION` | The session token is invalid or expired |
| `AUTH_INVALID_PASSWORD` | The provided password is incorrect |

### Config Errors

| Code | Description |
|------|-------------|
| `CONFIG_READ_FAILED` | Failed to read a configuration file |
| `CONFIG_WRITE_FAILED` | Failed to write a configuration file |
| `CONFIG_INVALID` | The configuration data is invalid |

### AI Errors

| Code | Description |
|------|-------------|
| `AI_NOT_CONFIGURED` | No active Muxit license for AI |
| `AI_REQUEST_FAILED` | The AI/LLM API request failed |
| `AI_REQUIRES_PRO` | The Muxit-managed AI needs a Maker subscription or higher (the code name predates the tier; the gate is Maker). Local providers are not affected |
| `IMAGE_ANALYSIS_REQUIRES_PRO` | An image was attached on a tier without AI image analysis (Maker and up). Reported as a tool result and as `driver.diagnostics`, not as a top-level error |
| `AI_CREDITS_EXHAUSTED` | The Muxit-managed AI refused the call: the month's credits are spent. Top up or wait for the reset |
| `AI_CONTEXT_LENGTH_EXCEEDED` | The conversation no longer fits the model's context window. Start a new chat or pick a model with a larger context |

### Workspace (EULA) Errors

| Code | Description |
|------|-------------|
| `EULA_NOT_ACCEPTED` | The workspace is in Sandbox mode until the EULA is accepted: hardware writes, actions and `scripts.start` are refused; reads and polling keep working. Accept with `eula.accept` or `POST /api/eula/accept` |
| `EULA_UNKNOWN_VERSION` | `?version=` on `/api/eula/text` named a version the server does not ship |
| `EULA_READ_FAILED` / `EULA_WRITE_FAILED` | The acceptance record under `.muxit/` could not be read or written |

### Marketplace Errors

| Code | Description |
|------|-------------|
| `MARKETPLACE_INSTALL_FAILED` | Driver package install failed (download, extract, or validation error) |
| `MARKETPLACE_UNINSTALL_FAILED` | Driver uninstall failed |

### Internal Errors

| Code | Description |
|------|-------------|
| `INTERNAL_ERROR` | An unexpected internal error occurred |

---

## Session Messages

### `session.identify`

Change who a live socket speaks for without reconnecting — a shift change, a sign-in from the
dashboard's PIN pad, or a sign-out. The token is the one `POST /api/accounts/login` returned;
`null` detaches it. The reply names the identity the token resolved to, or `null` when it
resolved to nobody (a stale token identifies no one, which is what a sign-out is). The very next
message is gated as that identity.

```json
{ "type": "session.identify", "requestId": "s1", "token": "SESSION_TOKEN" }
// Response
{ "type": "session.identify", "requestId": "s1", "identity": { "id": "j.smith", "name": "J. Smith", "role": "operator" } }

{ "type": "session.identify", "requestId": "s2", "token": null }
// Response
{ "type": "session.identify", "requestId": "s2", "identity": null }
```

A fresh socket should still present the token as the `account-…` subprotocol on the upgrade, so it
is identified from its first message; this message only covers the switch.

---

## Connector Messages

### `connectors.list`

List all loaded connector names.

```json
// Request
{ "type": "connectors.list", "requestId": "1" }
// Response
{ "type": "connectors.list", "requestId": "1", "value": ["psu", "robot", "panel"] }
```

### `connector.schema`

Get the schema for a single connector.

Pass `"includeHidden": true` to receive items that are filtered out by
`hide`/`expose` — they come back in the same arrays with a `"hidden": true`
flag so the GUI can render them greyed out in a "show hidden" view.

```json
// Request
{ "type": "connector.schema", "requestId": "2", "name": "psu", "includeHidden": false }
// Response
{
  "type": "connector.schema", "requestId": "2",
  "value": {
    "name": "psu", "driver": "MockInstrument",
    "properties": [
      { "name": "voltage", "type": "number", "access": "rw", "unit": "V", "hidden": false }
    ],
    "actions": [
      { "name": "reset", "description": "Reset to defaults", "hidden": false }
    ],
    "streams": [ { "name": "scpi", "hidden": false } ],
    "driverConfig": [
      { "key": "serialPort", "value": "COM8", "type": "string", "editable": true },
      { "key": "baudRate",   "value": 9600,   "type": "number", "editable": true },
      { "key": "transport",  "value": "{…}",  "type": "object", "editable": false }
    ],
    "hiddenItems": [],
    "visibilityMode": "all"
  }
}
```

`driverConfig` mirrors the currently-merged driver config as key/value pairs.
Framework-injected internals (anything whose key starts with `_`, e.g.
`_workspacePath`, `_eventBus`, `_licenseManager`) are omitted from this list.
Only entries with `"editable": true` (primitive string / number / bool / null)
can be changed through [`connector.driverConfig.set`](#connector-driverconfig-set).
`hiddenItems` lists the names currently hidden for the connector (both
driver and custom items); combine it with `includeHidden: true` to render a
visibility-editor UI.

### `connectors.schema`

Get schemas for all connectors at once (only enabled/loaded connectors).

```json
// Request
{ "type": "connectors.schema", "requestId": "3" }
// Response
{ "type": "connectors.schema", "requestId": "3", "value": { "psu": {...}, "robot": {...} } }
```

### `connectors.all`

Get metadata for ALL discovered connectors (enabled + disabled).

```json
// Request
{ "type": "connectors.all", "requestId": "4" }
// Response
{
  "type": "connectors.all", "requestId": "4",
  "value": {
    "enabled": [
      { "name": "test-device", "driver": "TestDevice", "isTestDevice": true },
      { "name": "bk-psu", "driver": "Scpi", "isTestDevice": false }
    ],
    "disabled": [
      { "name": "webcam", "driver": "Webcam", "isTestDevice": false, "reason": "Not enabled (limit: 3 connectors)" }
    ],
    "maxConnectors": 3,
    "enabledNames": ["test-device", "bk-psu"],
    "enabledNonTestCount": 1,
    "tierName": "Free"
  }
}
```

### `connectors.set_enabled`

Update which connectors are enabled. Validates against license limits.

```json
// Request
{ "type": "connectors.set_enabled", "requestId": "5", "connectors": ["bk-psu", "camera", "robot"] }
// Response (success)
{ "type": "connectors.set_enabled", "requestId": "5", "success": true, "requiresRestart": true }
```

### `connectors.reload`

Hot-reload all connectors without server restart.

```json
{ "type": "connectors.reload", "requestId": "6" }
```

### `connector.call`

Call a property (get/set) or action on a connector.

```json
// Read property
{ "type": "connector.call", "requestId": "4", "connector": "psu", "property": "voltage" }

// Write property
{ "type": "connector.call", "requestId": "5", "connector": "psu", "property": "voltage", "args": [12] }

// Execute action
{ "type": "connector.call", "requestId": "6", "connector": "psu", "method": "reset" }

// Response
{ "type": "connector.response", "requestId": "4", "value": 12.0 }
```

### `connector.visibility.set`

Rewrite the top-level `hide: [ ... ]` array in the connector's `.js` source
and hot-reload just that connector. The loader honours the new visibility on
the very next AI turn — no server restart is required. Only `.js` connectors
are supported; `.json` configs have no visibility block.

```json
// Request — make "debugChannel" and "internalCalibrate" invisible to AI + UI
{
  "type": "connector.visibility.set", "requestId": "10",
  "connector": "psu",
  "hidden": ["debugChannel", "internalCalibrate"]
}
// Response
{ "type": "connector.visibility.set", "requestId": "10", "connector": "psu", "success": true }
```

Pass `"hidden": []` to clear the list (everything visible). An existing
top-level `expose: [ ... ]` whitelist is removed when `hidden` is non-empty,
so the file stays consistent with the loader's "hide XOR expose" invariant.

### `connector.driverConfig.set`

Surgically edit a single primitive driver-config value (e.g. a serial port,
baud rate, or IP address) in the connector's `.js` source and hot-reload the
connector. The key is looked up in both the top-level config keys and the
nested `config: { ... }` block; whichever side already holds the key is
updated in place. New keys are appended to `config: { ... }` (creating it if
absent).

```json
// Request — change the BK-PSU serial port from COM8 to COM4
{
  "type": "connector.driverConfig.set", "requestId": "11",
  "connector": "bk-psu", "key": "serialPort", "value": "COM4"
}
// Response
{ "type": "connector.driverConfig.set", "requestId": "11",
  "connector": "bk-psu", "key": "serialPort", "success": true }
```

`value` must be a JSON primitive (string, number, boolean, or null). If the
existing value is a non-primitive expression (identifier, computed value,
template literal with interpolation), the server responds with a
`CONN_RELOAD_FAILED` error and leaves the file untouched — the user is
expected to edit the file directly in that case.

### `connector.rename`

Rename a connector. `newName` is the new basename only — the server preserves
the connector's folder and file extension. The underlying `.js`/`.json` file
is renamed on disk, the `connectors.enabled` list in `server.json` is
updated so the rename survives a restart, and the connector is hot-reloaded
under the new name. Scripts and dashboards that reference the old name keep
referencing it and must be updated by hand.

```json
// Request — rename `psu` to `bk-psu`
{ "type": "connector.rename", "requestId": "12",
  "oldName": "psu", "newName": "bk-psu" }
// Response
{ "type": "connector.rename", "requestId": "12",
  "oldName": "psu", "newName": "bk-psu", "success": true }
```

Validation: `newName` must be non-empty, contain no path separators or invalid
filename characters, and not start with `.` or `_`. The server returns
`VALIDATION_INVALID_VALUE` on naming collisions (another connector or file
already has the target name) and `CONN_NOT_FOUND` if the source connector
doesn't exist. The server also emits `connectors.changed` so other clients
refresh their connector list.

---

## Driver Messages

### `drivers.list`

```json
{ "type": "drivers.list", "requestId": "8" }
// Response
{ "type": "drivers.list", "requestId": "8", "value": [
  {
    "name": "TestDevice", "tier": 0, "version": "1.0.0", "category": "built-in", "group": "utilities",
    "errors": [], "warnings": []
  },
  {
    "name": "Fairino", "tier": 3, "version": "2.0.0", "category": "premium", "group": "motion",
    "errors": [
      {
        "ruleId": "PREMIUM_NOT_SIGNED",
        "severity": "hard",
        "message": "Premium driver 'Fairino.dll' is not signed with the official muxit key. Premium drivers will refuse to initialize."
      }
    ],
    "warnings": []
  }
]}
```

`errors[]` and `warnings[]` are produced by the runtime
[driver validator](https://docs.muxit.io/reference/driver-validation.md). Each entry has `ruleId` (uppercase
snake-case rule identifier), `severity` (`"hard"` or `"soft"`), and a
human-readable `message`. A non-empty `errors[]` means the driver is registered
for visibility but will refuse to initialize. The same fields are returned by
`driver.schema` and `marketplace.detail`.

### `driver.schema`

Get the full API schema for a driver, including all properties, actions with argument details, streams, and the connector template.

```json
{ "type": "driver.schema", "requestId": "9", "name": "TestDevice" }
// Response
{ "type": "driver.schema", "requestId": "9", "name": "TestDevice", "value": {
  "name": "TestDevice",
  "version": "1.0.0",
  "description": "Simulated test device for development...",
  "category": "built-in",
  "tier": 0,
  "properties": [
    { "name": "temperature", "type": "double", "access": "R/W", "unit": "°C", "description": "Current temperature" }
  ],
  "actions": [
    { "name": "setThreshold", "description": "Set the alert threshold", "args": [
      { "name": "value", "type": "double", "description": "Threshold value (0-100)" }
    ]}
  ],
  "streams": ["data"],
  "connectorTemplate": "export default { ... }"
}}
```

### `driver.logs.history`

Recent stdout/stderr lines of a **Python driver**'s subprocess for one connector (the server keeps
a bounded buffer per connector). Empty for connectors that are not Python-backed.

```json
{ "type": "driver.logs.history", "requestId": "d1", "connector": "spectro" }
// Response
{ "type": "driver.logs.history", "requestId": "d1", "connector": "spectro", "value": [
  { "source": "stderr", "level": "warn", "line": "calibration file missing, using defaults", "time": "2026-09-24T10:12:03.117Z" }
] }
```

### `driver.eval`

Evaluate a Python expression inside a running Python driver's process — a REPL for driver
debugging. `value` is whatever the driver returned, JSON-serialised. Fails with `DRIVER_BLOCKED`
when the server has no Python runtime or the driver raised. Both `driver.eval` and
`driver.logs.history` are refused for a gated caller (`OPERATOR_MODE_RESTRICTED`).

```json
{ "type": "driver.eval", "requestId": "d2", "connector": "spectro", "code": "self.device.get_serial()" }
// Response
{ "type": "driver.eval", "requestId": "d2", "connector": "spectro", "value": "AVA-0042" }
```

### `driver.template`

Get the connector config template for a driver.

```json
{ "type": "driver.template", "requestId": "10", "name": "TestDevice" }
```

---

## Label Messages

Behind the **Tools → Label Printing** page and the visual label designer. Everything except `labels.print` and `labels.setTemplate` works without a connector; those two go through the named LabelPrinter connector (safety gate, driver caps and the Pro gate apply). `labels.printers`, `labels.fonts`, `labels.print` and `labels.createConnector` run off the read loop; `labels.preview`, `labels.print` and `labels.createConnector` are rate-limited.

### `labels.printers`

Printers installed on the server's operating system. Cached for 30 s; pass `force` to re-enumerate. Enumeration has a 20 s budget — on timeout the last known list is returned with `stale: true` and an `error` message.

```json
// Request
{ "type": "labels.printers", "requestId": "1", "force": false }
// Response
{ "type": "labels.printers", "requestId": "1", "value": {
  "backend": "windows", "cachedAt": "2026-09-11T10:00:00Z", "stale": false, "error": null,
  "printers": [ { "name": "Brother PT-9700PC", "isDefault": false, "status": "ready", "detail": "ready",
                  "papers": ["24mm x 100mm"], "resolutions": [360], "port": "USB001", "driver": "Brother PT-9700PC", "error": null } ] } }
```

### `labels.connectors`

Every connector whose driver is `LabelPrinter`, with live properties for the initialized ones.

```json
// Response value (array)
[ { "name": "brother", "enabled": true, "disabledReason": null, "initialized": true, "initError": null, "path": "connectors/brother.js",
    "printer": "Brother PT-9700PC", "backend": "windows", "status": "ready", "statusDetail": "ready", "template": "asset-tag",
    "sequence": 12, "jobsPrinted": 3, "jobsFailed": 0, "lastError": "", "printingLicensed": false } ]
```

### `labels.createConnector`

Write `connectors/<name>.js` for a printer from the driver's starter template, enable it and reload connectors.

```json
// Request
{ "type": "labels.createConnector", "requestId": "2", "printer": "Brother PT-9700PC", "name": "brother",
  "paper": "24mm x 100mm", "media": { "width": 24, "height": 100, "unit": "mm" }, "template": "asset-tag" }
// Response
{ "type": "labels.createConnector", "requestId": "2", "value": { "name": "brother", "fileName": "brother.js", "path": "connectors/brother.js",
  "printer": "Brother PT-9700PC", "enabled": true, "disabledReason": null, "initialized": true, "initError": null } }
```

Errors: `VALIDATION_MISSING_PARAM`, `VALIDATION_INVALID_VALUE`, `CONN_LIMIT_REACHED` (checked before the file is written), `CONN_RELOAD_FAILED`.

### `labels.templates`

```json
// Response value
{ "directory": "labels", "templates": [
  { "name": "shipping", "path": "labels/shipping.label.json", "width": 62, "height": 100, "unit": "mm", "dpi": 300, "orientation": "portrait",
    "elements": 8, "barcodes": true, "fields": { "serial": { "required": true, "default": null } }, "placeholders": [], "warnings": [], "errors": [] },
  { "name": "broken", "path": "labels/broken.label.json", "error": "size.width and size.height must be positive" } ] }
```

### `labels.preview`

Render a template (name or inline layout) with sample data. Never license-gated; `{{sequence}}` renders as 1.

```json
// Request
{ "type": "labels.preview", "requestId": "3", "template": "shipping", "data": { "product": "Widget", "serial": "SN-1" }, "dpi": 150 }
// Response
{ "type": "labels.preview", "requestId": "3", "value": { "png": "iVBOR…", "width": 366, "height": 591, "dpi": 150, "warnings": [] } }
```

### `labels.print`

Print through a connector (`ConnectorManager.CallAsync(connector, "print", …)`).

```json
// Request
{ "type": "labels.print", "requestId": "4", "connector": "brother", "template": "shipping", "data": { "product": "Widget", "serial": "SN-1" }, "copies": 2 }
// Response
{ "type": "labels.print", "requestId": "4", "value": { "jobId": "lp-…", "pages": 1, "copies": 2, "printer": "Brother PT-9700PC", "template": "shipping", "spooled": true }, "simulated": false }
```

`value` is `null` with `simulated: true` when the safety gate simulated the call (Observe level). Errors pass through from the driver: `LICENSE_LIMIT`, `SAFETY_BLOCKED`, `CONN_NOT_FOUND`, `CONN_NOT_INITIALIZED`, `CONN_CALL_FAILED`, `VALIDATION_*`.

### `labels.setTemplate`

```json
// Request
{ "type": "labels.setTemplate", "requestId": "5", "connector": "brother", "template": "shipping" }
// Response
{ "type": "labels.setTemplate", "requestId": "5", "value": { "connector": "brother", "template": "shipping" } }
```

### `labels.fonts`

Font families SkiaSharp can resolve on the server (the designer's font dropdown). Enumerated once per server run.

```json
// Response value
{ "fonts": ["Arial", "Consolas", "DejaVu Sans", "Segoe UI"] }
```

### `labels.images`

Image files under `workspace/labels/` (recursive) that an image element's `src` may reference; `name` is relative to that folder.

```json
// Response value
{ "directory": "labels", "images": [ { "name": "logo.png", "size": 4821 }, { "name": "icons/warning.png", "size": 913 } ] }
```

---

## Stream Messages

### `stream.subscribe` / `stream.unsubscribe`

```json
{ "type": "stream.subscribe", "connector": "spectrometer", "stream": "spectrum" }
{ "type": "stream.unsubscribe", "connector": "spectrometer", "stream": "spectrum" }
```

### `stream.data` (server → client)

```json
{
  "type": "stream.data",
  "name": "spectrometer", "stream": "spectrum",
  "data": { "wavelengths": [380, 381, ...], "intensities": [0.1, 0.2, ...] }
}
```

For image streams (webcam), `data` is a base64-encoded JPEG string.

#### Audio streams

Drivers that produce audible output (e.g. AudioSynth, future TTS connectors)
declare a stream named `"audio"`. Each `stream.data` message carries a JSON
string in the `data` field. The default codec is **Opus** (32 kbit/s VBR,
20 ms frames at 48 kHz mono); base64 PCM16 remains a recognised fallback
for emitters that can't link an Opus encoder.

```json
// Default — Opus packet, ~20 ms of audio.
{
  "op": "chunk",
  "data": "<base64-encoded opus packet>",
  "sampleRate": 48000,
  "channels": 1,
  "format": "opus",
  "frameSize": 960
}

// Legacy fallback — base64 PCM16, ~50 ms of audio.
{
  "op": "chunk",
  "pcm": "<base64-encoded little-endian PCM16 samples>",
  "sampleRate": 44100,
  "channels": 1,
  "format": "pcm16"
}

// Stop signal — drop any queued/in-flight audio for this connector.
// Sent when the driver's playback is cancelled before completion.
{ "op": "stop" }
```

Chunks are paced at real-time playback rate so a subscribed client can
schedule them back-to-back without running its jitter buffer dry. Different
connectors that both emit `audio` streams play independently and may overlap
on the same client. Dashboards consume the chunks via the built-in
`ServerAudioRenderer`,
which decodes Opus via the browser-native WebCodecs `AudioDecoder` and
schedules the decoded `AudioBuffer`s through the Web Audio API.

::: tip Wire-format upgrade path
Sustained audio drops from ~1 Mbit/s (base64 PCM16) to ~100–200 kbit/s with
JSON-wrapped Opus. If audio bandwidth ever becomes a bottleneck again — or
when other stream types (video, large file transfers) want to skip the
base64 envelope — the next step is a binary WebSocket frame variant. The
JSON wrapper format stays forward-compatible: clients should ignore unknown
`format` values rather than assume any specific codec. See
`docs/reference/audio-streaming.md` in the repo for the migration plan.
:::

### `driver.diagnostics` (event)

Server → client broadcast emitted during driver scan when a driver has
validation findings (errors or warnings). Lets the Extensions panel show a
badge without polling. The same payload is also embedded in `drivers.list`,
`driver.schema`, and `marketplace.detail` responses.

```json
{
  "type": "driver.diagnostics",
  "driver": "Fairino",
  "category": "premium",
  "errors": [
    { "ruleId": "PREMIUM_NOT_SIGNED", "severity": "hard", "message": "..." }
  ],
  "warnings": []
}
```

See the [Driver Validation reference](https://docs.muxit.io/reference/driver-validation.md) for the rule list.

---

## State Messages

### `state.subscribe`

Subscribe to reactive state updates. Immediately receives current state, then `state.batch` on changes.

```json
{ "type": "state.subscribe" }
// Immediate response
{ "type": "state.batch", "updates": { "psu": { "voltage": 12 }, "robot": { "position": [100, 200, 300] } } }
```

### `state.snapshot`

One-shot state read without ongoing subscription.

```json
{ "type": "state.snapshot", "requestId": "20" }
```

### `state.batch` (server → client)

Pushed every 50ms when polled property values change (delta broadcasting).

```json
{ "type": "state.batch", "updates": { "psu": { "voltage": 12.1, "power": 6.05 } } }
```

---

## Script Messages

> **Startup scripts** placed in `workspace/startup/` run automatically when the server starts on Maker and above; on Free they are listed but not auto-run (each gets a `script.done` with the license reason, and the boot log says `Startup scripts not run`). They appear in script lists with a `startup/` prefix (e.g., `startup/monitor`), can be started by hand with `scripts.start` on any tier, and can be stopped like any other script.

### `scripts.list`

```json
{ "type": "scripts.list", "requestId": "12" }
// Response — includes startup scripts with "startup/" prefix
{ "type": "scripts.list", "requestId": "12", "value": ["hello", "monitor", "startup/log-temps"] }
```

### `scripts.start`

```json
// By name (from workspace/scripts/)
{ "type": "scripts.start", "requestId": "13", "name": "my-script" }
// Startup script (from workspace/startup/) — prefix with "startup/"
{ "type": "scripts.start", "requestId": "13", "name": "startup/log-temps" }
// With inline code
{ "type": "scripts.start", "requestId": "13", "name": "my-script", "code": "log.info('Hello!')" }
```

### `scripts.execute`

Execute synchronously — waits for completion and returns output.

Requires **editor mode** (`security.editorMode`, on by default). With editor
mode off the server replies with an error explaining how to turn it back on.

```json
{ "type": "scripts.execute", "requestId": "15", "name": "my-script", "code": "log.info('Hello!'); 42" }
// Response
{
  "type": "scripts.result", "requestId": "15", "name": "my-script",
  "result": 42,
  "logs": [{ "level": "info", "args": ["Hello!"] }],
  "error": null
}
```

### `scripts.stop`

```json
{ "type": "scripts.stop", "requestId": "14", "name": "my-script" }
```

### `scripts.stopAll`

Emergency stop — cancels every running script. Used by the always-visible
status strip in the web UI.

```json
{ "type": "scripts.stopAll", "requestId": "15" }
```

Response includes the list of names that were running at the time of the call:

```json
{ "type": "scripts.stopAll", "requestId": "15", "stopped": ["foo", "bar"], "count": 2 }
```

### `script.say` (broadcast)

```json
{ "type": "script.say", "script": "temp-monitor", "text": "Temperature is 25.3 degrees", "emotion": null }
```

`emotion` is `null` unless the script passed an `opts.emotion` argument to `say()` (e.g. `"excited"`, `"sad"`). The dashboard's TTS controller forwards the hint to the active provider; the built-in browser provider approximates with rate/pitch tweaks, future server-side providers (chatterbox, cosyvoice, ElevenLabs) will honour it natively.

### `script.done` (broadcast)

Emitted once per script when it finishes — successfully or otherwise. The
`error` field is either `null` (clean completion) or a structured object with
user-relative line/column (the wrapper offset is already applied) so the
dashboard can drop a Monaco marker straight onto the offending row.

```json
// Clean completion
{ "type": "script.done", "script": "monitor", "error": null }

// Failure — line/column refer to the script source as the user wrote it
{
  "type": "script.done",
  "script": "monitor",
  "error": {
    "message": "ReferenceError: foo is not defined",
    "line": 7,
    "column": 1,
    "stack": "ReferenceError: foo is not defined\n    at <anonymous>:7:1",
    "details": "ReferenceError: foo is not defined\n    at <anonymous>:7:1\n..."
  }
}
```

### `script.line` (broadcast)

Phase-2 execution-line trace. Emitted before every blocking host call inside a
running script (`delay`, `await connector.x()`, `ai`, `ask.*`, `say`, `stream`),
throttled to one event per 50ms per script and de-duplicated against the prior
line. Dashboards opt in via `script.line.subscribe` so the per-call cost of
capturing a JS stack is paid only when at least one client cares.

```json
// Subscribe (refcounted server-side)
{ "type": "script.line.subscribe", "requestId": "20" }
// Unsubscribe — last subscriber off ⇒ server skips the trace
{ "type": "script.line.unsubscribe", "requestId": "21" }
// Broadcast while subscribed
{ "type": "script.line", "script": "monitor", "line": 12, "column": 3 }
```

### `connector.error` (broadcast)

Emitted when a connector config fails to parse or load. The dashboard uses
`line` / `column` to place a Monaco error marker on the offending row of the
source `.js` (line numbers are preserved through import-stripping in the
loader).

```json
{
  "type": "connector.error",
  "connector": "psu",
  "file": "/abs/path/to/connectors/psu.js",
  "message": "SyntaxError: Unexpected token '}'",
  "line": 14,
  "column": 1
}
```

---

## Prompt Messages

Interactive prompts opened by a script via `ask.confirm` / `ask.choose` /
`ask.text`. Dashboards subscribe, render each open prompt, and send the user's
answer back. Lifecycle broadcasts (`prompt.open`, `prompt.resolved`) fan out to
every connected client so a prompt stays visible across reconnects.

### `prompts.subscribe` / `prompts.unsubscribe`

```json
{ "type": "prompts.subscribe", "requestId": "30" }
```

Subscribing matters for scripts that set `requireObserver: true` — the server
counts subscribed clients and pauses the prompt timeout while that count is zero.

### `prompts.list`

Snapshot of prompts currently open on the server (useful when a dashboard
reconnects mid-prompt).

```json
{ "type": "prompts.list", "requestId": "31" }
// Response
{
  "type": "prompts.list",
  "prompts": [
    {
      "id": "9f2c0b5a4e11",
      "script": "calibrate",
      "kind": "confirm",
      "message": "Home all axes before run?",
      "openedAt": "2026-04-15T09:12:34.123Z",
      "requireObserver": false,
      "timeoutMs": 30000,
      "hasDefault": true
    }
  ]
}
```

### `prompts.answer`

Deliver a user-supplied answer. The `value` shape must match the prompt kind:
boolean for `confirm`, one of the offered strings for `choose`, any string for
`text`. Mismatches are rejected with `VALIDATION_INVALID_VALUE`.

```json
{ "type": "prompts.answer", "requestId": "32", "id": "9f2c0b5a4e11", "value": true }
```

### `prompt.open` (broadcast)

```json
{
  "type": "prompt.open",
  "id": "9f2c0b5a4e11",
  "script": "calibrate",
  "kind": "choose",
  "message": "Select instrument port",
  "choices": ["COM1", "COM2", "COM3"],
  "openedAt": "2026-04-15T09:12:34.123Z",
  "requireObserver": true,
  "timeoutMs": 120000,
  "hasDefault": true
}
```

### `prompt.resolved` (broadcast)

Sent when a prompt leaves the open set (answered, timed out, or its script
ended). `answeredBy` is `"user"` or `"timeout"`.

```json
{ "type": "prompt.resolved", "id": "9f2c0b5a4e11", "answeredBy": "user" }
```

---

## Agent Messages

### `agent.list`

```json
{ "type": "agent.list", "requestId": "..." }
// Response
{
  "type": "agent.list",
  "configs": [{ "name": "pick-and-place", "description": "...", "devices": ["robot", "camera"], "autonomy": "supervised" }],
  "running": [{ "agentId": "abc123", "name": "pick-and-place", "goal": "...", "status": "executing" }]
}
```

### `agent.start`

```json
{ "type": "agent.start", "name": "pick-and-place", "goal": "Pick up the red part", "parameters": { "partColor": "red" }, "autonomy": "supervised" }
// Response
{ "type": "agent.started", "agentId": "abc123", "name": "pick-and-place", "goal": "Pick up the red part" }
```

### `agent.stop` / `agent.pause` / `agent.resume`

```json
{ "type": "agent.stop", "agentId": "abc123" }
{ "type": "agent.pause", "agentId": "abc123" }
{ "type": "agent.resume", "agentId": "abc123" }
```

### `agent.approve` / `agent.deny`

```json
{ "type": "agent.approve", "agentId": "abc123", "stepId": "step-id" }
{ "type": "agent.deny", "agentId": "abc123", "stepId": "step-id" }
```

### `agent.respond`

Answer a question an agent asked with its `request_user_input` tool. While it waits, the agent's
`agent.state` broadcast reports `status: "waitingforapproval"` and the question is in its
timeline; it gives up after five minutes. The handler sends no reply — the next `agent.state`
shows the agent moving on. An unknown `agentId` is ignored.

```json
{ "type": "agent.respond", "agentId": "abc123", "response": "Use the second tray." }
```

### `agent.status` / `agent.detail`

```json
{ "type": "agent.status", "agentId": "abc123" }
// Returns: { agentId, name, goal, status, iteration, planSteps, reasoning, tokensUsed, elapsedSeconds, ... }

{ "type": "agent.detail", "agentId": "abc123" }
```

`agent.status` response fields: `agentId`, `name`, `goal`, `status`, `iteration`, `planSteps`, `reasoning`, `tokensUsed`, `elapsedSeconds`, `error`, `parameters`, `timelineCount`.

`agent.detail` response includes all status fields plus: `timeline` (last 200 entries), `devices`, `autonomy`, `processFile`.

### `agent.state` (broadcast)

```json
{
  "type": "agent.state",
  "data": {
    "agentId": "abc123def456",
    "name": "pick-and-place",
    "goal": "Pick up the red part",
    "status": "executing",
    "iteration": 5,
    "reasoning": "I can see the red part at position (320, 240). Moving to approach...",
    "tokensUsed": 1500,
    "elapsedSeconds": 45.2,
    "planSteps": [
      { "id": "a1b2c3", "description": "Moving to pick position", "status": "executing" },
      { "id": "d4e5f6", "description": "Close gripper", "status": "pending" }
    ]
  }
}
```

### `agent.timeline` (broadcast)

Streamed in real-time as the agent executes. Types: `thought`, `action`, `observation`, `error`, `user_input`.

```json
{
  "type": "agent.timeline",
  "agentId": "abc123def456",
  "entry": {
    "timestamp": "2025-01-15T10:30:00Z",
    "type": "action",
    "summary": "call_action({connector: \"robot\", action: \"moveJ\", ...})"
  }
}
```

---

### `instructions.get` / `instructions.set`

```json
{ "type": "instructions.get", "requestId": "40" }
// Returns: { type: "instructions.get", content: "# Lab Instructions\n..." }

{ "type": "instructions.set", "requestId": "41", "content": "# Lab Instructions\n## General\n..." }
// Returns: { type: "instructions.set", saved: true }
```

---

## Config Messages

### `config.get` / `config.set`

```json
{ "type": "config.get", "requestId": "30" }

// Dot-path update
{ "type": "config.set", "requestId": "31", "path": "ai.provider", "value": "claude" }
// Patch update
{ "type": "config.set", "requestId": "31", "patch": { "ai": { "model": "anthropic/claude-sonnet-4-5" } } }
```

### `config.test_ai`

Probe the **active** AI provider as configured — one tiny completion, no arguments. For the
Muxit-managed provider a Free tier gets `success: false` with `code: "AI_REQUIRES_PRO"` in the
value rather than an error message. `AI_NOT_CONFIGURED` when there is no AI service at all.

```json
{ "type": "config.test_ai", "requestId": "31b" }
// Response
{ "type": "config.test_ai", "requestId": "31b", "value": { "success": true, "latency": 412, "model": "anthropic/claude-sonnet-4-5" } }
```

### `config.test_provider`

Probe a (possibly unsaved) LLM provider configuration. Used by the AI Services
settings panel to validate Ollama / LM Studio is reachable before persisting.
Returns success / latency / model count.

```json
{ "type": "config.test_provider", "requestId": "31a", "provider": "ollama",
  "baseUrl": "http://localhost:11434/v1", "model": "llama3.2" }
```

```json
{ "type": "config.test_provider", "value": {
    "success": true, "latency": 12, "model": "llama3.2",
    "provider": "ollama", "modelCount": 4,
    "models": [{ "id": "llama3.2", "name": "llama3.2", "provider": "ollama" }]
} }
```

### `models.list`

Fetch available AI models (cached server-side, 6h TTL). Merges in models from
the active local provider's `/models` endpoint when the active provider is
Ollama / LM Studio / openai-compatible.

```json
{ "type": "models.list", "requestId": "32" }
{ "type": "models.list", "requestId": "33", "force": true }
```

Response contains an array of models with pricing:

```json
{
  "type": "models.list",
  "value": {
    "models": [
      {
        "id": "anthropic/claude-sonnet-4-5",
        "name": "Claude Sonnet 4.5",
        "provider": "anthropic",
        "contextLength": 200000,
        "pricing": { "prompt": "0.000003", "completion": "0.000015" }
      }
    ]
  }
}
```

---

## AI Messages

### Client → Server

| Type | Fields | Description |
|------|--------|-------------|
| `ai.chat` | `sessionId`, `message`, `ttsEnabled?`, `mode?` | Send user message, triggers agentic loop. `mode` (`"normal"` \| `"device-authoring"`) sets the session's chat mode; `"device-authoring"` narrows the toolset to the connector-creation set — the probe/discover/compose tools, the config tools, and the core device tools (read/write/action) so it can build, hot-reload, and fully test the new connector — and focuses the system prompt on connector creation. Scripts, agents, dashboards, vision, etc. are left out. Set by the Connectors panel's "Add device" flow; omit for normal chat. |
| `ai.stop` | `sessionId` | Cancel the active chat for that session |
| `ai.contextNotice` | `sessionId`, `notice` | Drop a mid-chat context boundary into the session (e.g. TTS toggled). Appends a user→assistant pair so the LLM adopts the new rules on its next turn. No-op when the session has no messages yet. Response: `{ applied: bool }` |
| `ai.debugPrompt` | `sessionId`, `message?`, `ttsEnabled?`, `mode?` | **Read-only system-prompt inspector** (the chat panel's `/prompt` command). Builds the exact system prompt the next `ai.chat` turn would send for that session + optional message — without calling the LLM and without mutating session state. `mode` previews a given chat mode (defaults to the session's current mode). Response below. |
| `ai.tool_approve` | `requestId` | Approve a pending tool call |
| `ai.tool_deny` | `requestId` | Deny a pending tool call |
| `ai.credits` | — | Credit balance of the active provider. Response `value`: `{ success, usagePercent, provider }` for the Muxit-managed provider; `{ success: false, error: "Credits not applicable for local providers", provider }` for a local one; `code: "AI_REQUIRES_PRO"` on a tier without managed AI |
| `ai.memory.list` | — | The AI's saved memories. Response `value`: `[{ id, content, category, createdAt, source }]` |
| `ai.memory.update` | `id`, `content`, `category?` | Rewrite one memory. Response `{ updated: bool, id }` |
| `ai.memory.delete` | `id` | Forget one memory. Response `{ deleted: bool, id }` |
| `ai.memory.clear` | — | Forget everything. Response `{ success: true }` |

**`ai.debugPrompt` response** — `{ type: "ai.debugPrompt", value: {...} }` where `value` carries:

| Field | Description |
|-------|-------------|
| `systemPrompt` | The full assembled system prompt string |
| `totalChars` | `systemPrompt.length` |
| `limit` | Provider per-field char cap (32000) the Muxit proxy/OpenRouter enforces on the top-level `system` field |
| `exceedsLimit` | `true` when `totalChars > limit` — a real request would be rejected upstream with `validation_error: String must contain at most 32000 character(s)` before any tokens are billed (so no ai-tokens log line is written) |
| `promptProfile` | `"standard"` or `"minimal"` (`ai.promptProfile`) |
| `mode` | `"normal"` or `"device-authoring"` — the chat mode this preview was built for |
| `model` | Active model id |
| `activeGroups` | Tool groups selected for this turn (sorted) |
| `toolCount`, `tools` | Number and names of the tools that would be sent |
| `sections` | `[{ label, chars }]` — per-fragment size breakdown (identity, device-authoring guide, connected devices, …) |
| `devices` | `[{ label, chars }]` — per-connector size breakdown of the "Connected Devices" block; the lever that most often pushes a prompt over the cap |

### Server → Client (Streamed)

| Type | Fields | Description |
|------|--------|-------------|
| `ai.delta` | `content`, `sessionId` | Streaming text chunk |
| `ai.tool_call` | `tool`, `input`, `result` | Tool executed |
| `ai.tool_pending` | `requestId`, `tool`, `input` | Tool awaiting approval |
| `ai.image` | `tool`, `image`, `sessionId` | Camera snapshot captured |
| `ai.chat` | `message`, `toolCalls` | Final response |

---

## Vision Annotation Messages

Direct vision training — draw bounding boxes on a camera feed to teach objects without AI.

### `vision.teach`

Teach an object by sampling color in a drawn bounding box region.

**Request:**
```json
{
  "type": "vision.teach",
  "name": "red_cup",
  "x": 100,
  "y": 80,
  "width": 60,
  "height": 50,
  "visionConnector": "vision",
  "description": "A red coffee cup",
  "trackerType": "color"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique name for the object |
| `x`, `y` | Yes | Top-left corner of bounding box (image pixels) |
| `width`, `height` | Yes | Box dimensions (image pixels) |
| `visionConnector` | No | Vision connector name (default: `"vision"`) |
| `description` | No | Human-readable description |
| `trackerType` | No | `"color"` (default) or `"contour"` |

**Response:**
```json
{ "type": "vision.teach", "success": true, "name": "red_cup", "trackerType": "color", "camera": "webcam" }
```

### `vision.forget`

Remove a taught object and its tracker.

**Request:**
```json
{ "type": "vision.forget", "name": "red_cup", "visionConnector": "vision" }
```

**Response:**
```json
{ "type": "vision.forget", "success": true, "name": "red_cup" }
```

### `vision.list`

List all taught object profiles.

**Request:**
```json
{ "type": "vision.list" }
```

**Response:**
```json
{
  "type": "vision.list",
  "objects": [
    { "name": "red_cup", "description": "A red coffee cup", "trackerType": "color", "camera": "webcam", "createdAt": "2026-04-08T..." }
  ]
}
```

---

## License Messages

### `license.get`

Returns current license state including tier, limits, trials, and usage.

**Response:**
```json
{
  "type": "license.get",
  "value": {
    "tierId": "free",
    "tierName": "Free",
    "maxDrivers": 2,
    "maxConnectors": 3,
    "maxScripts": 2,
    "baseLicenseKey": null,
    "baseValid": false,
    "baseExpiresAt": null,
    "baseLastValidated": null,
    "customerName": null,
    "customerEmail": null,
    "trialDays": 14,
    "entitlements": {},
    "driverTrials": {},
    "allTiers": [
      { "id": "free", "name": "Free", "maxDrivers": 2, "maxConnectors": 3, "maxScripts": 2 },
      { "id": "pro", "name": "Pro", "maxDrivers": -1, "maxConnectors": -1, "maxScripts": -1 }
    ],
    "currentConnectors": 1,
    "currentDrivers": 2,
    "currentScripts": 0
  }
}
```

### `license.activate`

Activate a license key. For base subscriptions, driver entitlements included as subscription add-ons are automatically synced from Polar — no separate driver keys needed. Standalone per-driver keys are also supported as a fallback.

```json
{ "type": "license.activate", "licenseKey": "XXXX-XXXX-XXXX-XXXX" }
```

**Response:**
```json
{
  "type": "license.activate",
  "success": true,
  "value": { "...full license state..." }
}
```

On failure, `success` is `false` and `error` contains a descriptive message:

| Situation | Error message explains |
|-----------|----------------------|
| Key already activated on max instances | How many instances are used, and how to deactivate one |
| Key expired | That renewal is needed via the Polar portal |
| Key inactive / not yet purchased | That the purchase needs to be completed |
| Key disabled | That support should be contacted |
| Network error | That Polar could not be reached (local network issue) |
| Unknown product | That the key doesn't match this application |
| Key accepted, but no signed license | That paid features stay off until Muxit gets the signed license, which it retries in the background and on the next start |

A base subscription's tier comes from the signed license Muxit fetches right after the key is accepted, not from the activation reply. If that fetch fails, the key is kept (so the retry can use it) and `value` still shows the free tier.

### `license.deactivate`

Deactivate the base subscription on this machine. Frees up the activation slot so the key can be used on another machine. Reverts to the free tier.

Freeing the slot is best-effort. If the license server can't be reached, times out, or answers with something other than a license reply (a gateway's error page, for example), the license is still removed from this machine and the call succeeds; only the slot on the server stays in use, and can be freed from the customer portal. The same holds for `license.deactivate_feature` and `license.deactivate_driver`.

```json
{ "type": "license.deactivate" }
```

### `license.deactivate_feature`

Deactivate one standalone feature license (a feature bought on its own rather than through the
subscription). `success` says whether it happened; on failure `error` says why and `value` still
carries the current license payload, so the UI can re-render either way.

```json
{ "type": "license.deactivate_feature", "featureId": "label-printing" }
// Response
{ "type": "license.deactivate_feature", "success": true, "value": { /* same shape as license.get */ } }
```

### `license.deactivate_driver`

Deactivate a standalone per-driver license. Subscription-managed driver entitlements cannot be deactivated individually — manage them from the Polar subscription portal instead.

```json
{ "type": "license.deactivate_driver", "driverId": "my-driver" }
```

### `license.start_trial`

Start a per-driver trial (14 days). The `driverId` field is required.

```json
{ "type": "license.start_trial", "driverId": "my-driver" }
```

> **Note:** Base Pro trials require a license key. Obtain a free trial key from the Muxit store and use `license.activate` instead.

### `license.changed` (broadcast)

Broadcast to all clients whenever license state changes.

---

## Server Log Messages

### `server.logs.history`

Fetch buffered log history (last 500 entries).

### `server.log` (broadcast)

Real-time server log entry.

```json
{ "type": "server.log", "level": "info", "source": "connectors", "message": "Connector 'psu' initialized", "time": "..." }
```

### `server.initializing` (broadcast)

Sent when the server begins background initialization (driver scanning, connector loading). The GUI is already accessible at this point — devices will appear progressively.

```json
{ "type": "server.initializing", "phase": "drivers" }
{ "type": "server.initializing", "phase": "connectors" }
```

### `server.ready` (broadcast)

Sent once all connectors have been initialized and startup scripts have launched. A client that connects after that moment is sent `server.ready` right after the connection opens, so it never waits for a broadcast that already happened.

```json
{ "type": "server.ready" }
```

### `connectors.changed` (broadcast)

Sent after each connector finishes initializing (or fails). Clients should re-fetch the connector list (`connectors.schema`) to get updated data.

```json
{ "type": "connectors.changed" }
```

### `drivers.changed` (broadcast)

Sent after a marketplace install or uninstall completes and the driver registry has re-scanned. Clients should re-fetch the driver list (`drivers.list`) so the Extensions panel's Installed tab updates without needing a reconnect.

```json
{ "type": "drivers.changed" }
```

---

## Safety Messages

The [Safety Gate](https://docs.muxit.io/guides/safety.md) sits between every write and the hardware. These three messages
read and move its global level; the per-connector `safety:` blocks are configuration, not
messages.

### `safety.get`

```json
{ "type": "safety.get", "requestId": "sf1" }
// Response
{ "type": "safety.get", "requestId": "sf1", "snapshot": {
  "level": "Assisted",
  "allowedLevels": ["Observe", "Assisted", "Active", "Unrestricted"],
  "lastChangeCaller": "dashboard:1f3a9c02",
  "lastChangeAt": "2026-09-24T08:00:00.0000000Z",
  "licensed": true,
  "licenseClamp": null
} }
```

`allowedLevels` is what the tier permits. A `Custom` level adds a `custom` object with the
behaviour table (`writeInRange`, `writeOutOfRange`, `largeChange`, `action`, `destructiveAction`,
`audit`, `aiConfirm`).

`licenseClamp` is `null` unless the license, not a person, chose `level`: the saved level needs a
tier this machine does not have, so the gate runs at the lowest level it allows (Observe — every
write and action simulated). It comes back by itself when the license covers it again, with a
`safety.changed` broadcast; any `safety.setLevel` ends it.

```json
"level": "Observe",
"licenseClamp": {
  "configuredLevel": "Active",            // the saved level, restored when the license allows it
  "requiredTier": "Pro",                  // display name of the tier that level needs
  "cause": "unreachable",                 // subscriptionExpired | unreachable | notLicensed
  "since": "2026-10-02T08:00:00.0000000Z", // end date, or last confirmation; null if unknown
  "message": "Hardware control is off: the Active safety level needs Pro, …"
}
```

### `safety.setLevel`

`target` is one of `Observe | Assisted | Active | Unrestricted | Custom`. Escalating to
`Unrestricted` needs `typedPhrase` (the confirmation phrase the UI asks for); `Custom` takes an
optional `custom` behaviour object — unknown or missing keys fall back to Assisted's row. Levels
the tier does not include fail with `SAFETY_REQUIRES_PRO`. `applied` is false when the gate
declined the change (a missing or wrong phrase, for example) and an audit row records the refusal;
the snapshot is returned either way. Refused for a gated caller.

```json
{ "type": "safety.setLevel", "requestId": "sf2", "target": "Unrestricted", "typedPhrase": "I understand" }
// Response
{ "type": "safety.setLevel", "requestId": "sf2", "applied": true, "snapshot": { "level": "Unrestricted", "..." : "..." } }
```

### `safety.audit.tail`

The last `n` audit records (default 100, capped at 10 000). Written on every tier where the active
level's audit column is on: Observe writes simulation records, Unrestricted writes nothing.

```json
{ "type": "safety.audit.tail", "requestId": "sf3", "n": 50 }
// Response
{ "type": "safety.audit.tail", "requestId": "sf3", "records": [
  { "ts": "2026-09-24T08:01:12.4420000Z", "event": "level.change", "caller": "dashboard:1f3a9c02",
    "details": { "from": "Assisted", "to": "Unrestricted", "blocked": true, "reason": "unrestricted typed phrase missing or incorrect" } }
] }
```

### `safety.changed` / `audit.log` (broadcast)

`safety.changed { snapshot }` follows every level change — including one the license makes, in
either direction (`lastChangeCaller` is then `system:license`); `audit.log { record }` follows every
audit row written, in the same shape as `safety.audit.tail` returns.

---

## Workspace EULA Messages

A workspace is in **Sandbox mode** until its EULA is accepted: reads and polling work, hardware
writes, actions and `scripts.start` fail with `EULA_NOT_ACCEPTED`. These two messages mirror
`GET /api/eula` and `POST /api/eula/accept` for clients that are already connected, so the unlock
needs no page reload.

### `eula.status`

```json
{ "type": "eula.status", "requestId": "e1" }
// Response
{ "type": "eula.status", "requestId": "e1", "value": {
  "currentVersion": "1.1.0", "isAccepted": false, "reason": "EulaMissing",
  "acceptedVersion": null, "acceptedAt": null, "acceptedBy": null,
  "acceptedLicenseId": null, "acceptedInstanceId": null,
  "writeLockReason": "EulaMissing", "canonicalHash": "…"
} }
```

### `eula.accept`

`userIdentifier` is required — the name or e-mail that goes into the append-only acceptance
history. Unlocks the workspace on success. Refused for a gated caller; `reason` in the status is
one of `EulaMissing`, `EulaCorrupt`, `EulaOutdated`.

```json
{ "type": "eula.accept", "requestId": "e2", "userIdentifier": "j.smith@example.com" }
// Response
{ "type": "eula.accept", "requestId": "e2", "value": { "isAccepted": true, "acceptedVersion": "1.1.0", "acceptedAt": "…", "acceptedBy": "j.smith@example.com", "acceptedLicenseId": null, "acceptedInstanceId": "…" } }
```

---

## Discovery and Diagnostics Messages

### `discovery.status`

State of the mDNS / Bonjour advertisement (`muxit.local`). `{ running: false, enabled: false }`
when the service is not part of this build or configuration.

```json
{ "type": "discovery.status", "requestId": "n1" }
// Response
{ "type": "discovery.status", "requestId": "n1", "value": {
  "running": true, "enabled": true, "hostname": "bench-pc", "port": 8765, "address": "bench-pc.local",
  "remoteAccess": true, "addresses": ["192.168.1.20"], "advertisedOnInterfaces": ["eth0"], "skippedInterfaces": []
} }
```

### `diagnostics.network`

The same report as `GET /api/diagnostics/network`, always in its **redacted** form: the socket's
peer address is not known to the handler, so interface details, firewall rules and fix commands
are left out. Use the HTTP endpoint from the machine itself for the full report.

```json
{ "type": "diagnostics.network", "requestId": "n2" }
// Response
{ "type": "diagnostics.network", "requestId": "n2", "value": {
  "bind": { "address": "0.0.0.0", "port": 8765, "scheme": "http", "remoteAccess": true, "httpsEnabled": false, "portListening": true },
  "os": { "platform": "…", "isWindows": true, "isLinux": false, "isMacOS": false },
  "interfaces": { "count": 2 }, "firewall": { "…": "…" }, "mdns": { "…": "…" }, "hints": [], "verbose": false
} }
```

---

## MQTT Broker Messages

### `mqtt.broker.status`

Get the status of the built-in MQTT broker.

**Response:**
```json
{
  "type": "mqtt.broker.status",
  "value": {
    "running": true,
    "enabled": true,
    "port": 1883,
    "clientCount": 3,
    "maxClients": 100,
    "hasAuth": false
  }
}
```

### `mqtt.broker.clients`

List currently connected MQTT clients.

**Response:**
```json
{
  "type": "mqtt.broker.clients",
  "value": [
    { "clientId": "esp32-sensor-01", "connectedAt": "2026-03-29T10:15:00Z" },
    { "clientId": "muxit-abc123", "connectedAt": "2026-03-29T10:16:00Z" }
  ]
}
```

---

## Update Messages

### `update.check`

Check for available updates. Returns current and latest version info.

Send `{ "type": "update.check", "force": true }` to bypass the 24-hour cache.

**Response:**
```json
{
  "type": "update.status",
  "value": {
    "currentVersion": "0.1.0",
    "latestVersion": "0.2.0",
    "updateAvailable": true,
    "downloadUrl": "https://github.com/muxit-io/muxit/releases/download/v0.2.0/muxit-win-x64-v0.2.0.zip",
    "releaseNotes": "### Fixed\n- Script pause no longer hangs",
    "selfInstallSupported": true
  }
}
```

`releaseNotes` is the markdown body of the release. It is present only when the
check was answered by the Muxit proxy; on the GitHub fallback path it is
`null`, so treat it as optional.

`downloadUrl` points at the release asset for the **current** platform
(win-x64 `.zip`, linux-x64 / linux-arm64 / osx-x64 / osx-arm64 `.tar.gz`).
`selfInstallSupported` is `true` only when the running build can install an
update in place — i.e. a published self-contained binary on a platform with a
release asset. When it is `false` (e.g. win-arm64, or a dev `dotnet run`),
clients should offer the `downloadUrl` instead of calling `update.apply`.

### `update.apply`

Download the latest release for the current platform, install it in place, and
restart the server onto the new version. Only valid when `selfInstallSupported`
is `true`. Long-running — progress is streamed back as `update.progress`
messages, followed by a single terminal message.

**Streamed progress** (sent repeatedly; no `requestId`):
```json
{ "type": "update.progress", "phase": "downloading", "fraction": 0.42, "message": "12.0 / 28.6 MB" }
```
`phase` is one of `checking`, `downloading`, `extracting`, `applying`, `done`.
`fraction` (0..1) is only meaningful while `phase` is `downloading`.

**Terminal** (carries the original `requestId`):
```json
{ "type": "update.applied", "version": "0.2.0", "restarting": true }
```
After `update.applied` the server writes a restart marker and shuts down ~800 ms
later, then relaunches automatically onto the new binary. The client's socket
drops and should reconnect / reload; the relaunched server does not open a
browser tab of its own. The whole shipped payload is replaced (binary, runtime
assemblies, `wwwroot/`, `workspace-template/`) — on Linux and macOS the `muxit`
launcher is only an apphost and the version lives in `muxit.dll`, so swapping
the launcher alone would restart onto the old code. The workspace is preserved.

On failure (or if a self-install isn't possible / one is already in progress):
```json
{ "type": "update.failed", "error": "An update is already in progress." }
```
If the running build turned out to already be current, an `update.status` with
`updateAvailable: false` is returned instead.

### `update.available` (broadcast)

Emitted on startup when a newer version is available.

```json
{ "type": "update.available", "current": "0.1.0", "latest": "0.2.0", "downloadUrl": "..." }
```

---

## Marketplace Messages

### `marketplace.search`

Search the driver registry. All filter parameters are optional.

```json
{ "type": "marketplace.search", "query": "serial", "group": "communication", "tier": 1, "requestId": "..." }
```

**Response:**
```json
{
  "type": "marketplace.search",
  "value": [
    {
      "id": "community/serial-logger",
      "name": "Serial Logger",
      "version": "1.0.0",
      "description": "Logs serial port data to file",
      "author": { "name": "Jane", "github": "jane" },
      "group": "communication",
      "tier": 1,
      "category": "free",
      "tags": ["serial", "logging"],
      "installed": false,
      "installedVersion": null
    }
  ]
}
```

`category` is either `"free"` or `"premium"` and reflects the manifest declaration for the registry entry. The Extensions panel uses this to render a Premium badge on the Available tab.

### `marketplace.detail`

Get detailed information about a driver (works for registry drivers, marketplace-installed drivers, and locally loaded drivers).

```json
{ "type": "marketplace.detail", "id": "TestDevice", "requestId": "..." }
```

**Response:**
```json
{
  "type": "marketplace.detail",
  "value": {
    "id": "TestDevice",
    "name": "TestDevice",
    "version": "1.0.0",
    "description": "Simulated test instrument",
    "group": "utilities",
    "tier": 0,
    "category": "built-in",
    "installed": true,
    "schema": {
      "properties": [{ "name": "voltage", "type": "double", "access": "R/W", "unit": "V" }],
      "actions": [{ "name": "reset", "description": "Reset to defaults" }],
      "streams": [],
      "connectorTemplate": "..."
    },
    "readme": "...",
    "changelog": "..."
  }
}
```

### `marketplace.install`

Install a driver from the registry by ID, or from a local `.muxdriver` file. Runs as a background task with progress messages.

```json
{ "type": "marketplace.install", "id": "community/serial-logger", "requestId": "..." }
```

Pin a specific version (optional — defaults to the highest-versioned entry for the id):
```json
{ "type": "marketplace.install", "id": "community/serial-logger", "version": "1.2.0", "requestId": "..." }
```

Or from a local file:
```json
{ "type": "marketplace.install", "filePath": "/path/to/driver.muxdriver", "requestId": "..." }
```

**Progress messages** (sent during download/install):
```json
{ "type": "marketplace.install.progress", "driverId": "community/serial-logger", "phase": "downloading", "percent": 45 }
{ "type": "marketplace.install.progress", "driverId": "community/serial-logger", "phase": "complete", "percent": 100 }
```

**Response:**
```json
{ "type": "marketplace.install", "value": { "id": "community/serial-logger", "name": "Serial Logger", "version": "1.0.0", "success": true } }
```

### `marketplace.uninstall`

Remove a marketplace-installed driver.

```json
{ "type": "marketplace.uninstall", "id": "community/serial-logger", "requestId": "..." }
```

### `marketplace.installed`

List all marketplace-installed drivers (does not include built-in or locally-built drivers).

```json
{ "type": "marketplace.installed", "requestId": "..." }
```

### `marketplace.updates`

Check for available updates to installed marketplace drivers.

```json
{ "type": "marketplace.updates", "requestId": "..." }
```

**Response:**
```json
{
  "type": "marketplace.updates",
  "value": [
    { "id": "community/serial-logger", "installedVersion": "1.0.0", "latestVersion": "1.1.0" }
  ]
}
```

### `marketplace.refresh`

Force re-fetch the registry index (bypasses 24-hour cache).

```json
{ "type": "marketplace.refresh", "requestId": "..." }
```

---

## Example: JavaScript Client

```javascript
const ws = new WebSocket("ws://localhost:8765/ws", ["muxit", "auth-YOUR_TOKEN"]);

ws.onopen = () => {
  ws.send(JSON.stringify({ type: "state.subscribe" }));
  ws.send(JSON.stringify({ type: "connector.call", requestId: "1", connector: "psu", property: "voltage" }));
};

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  if (msg.type === "state.batch") console.log("State:", msg.updates);
  else if (msg.type === "connector.response") console.log(`[${msg.requestId}]:`, msg.value);
};
```
