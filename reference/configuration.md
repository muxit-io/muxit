---
title: Configuration Reference
description: Complete reference for Muxit's server.json configuration file.
---

# Configuration Reference

All Muxit server settings live in `workspace/config/server.json`. You can edit this file directly or use the Settings panel in the web UI.

## File Location

`server.json` lives inside your **workspace**, not next to the executable:

```
<workspace>/config/server.json
```

Not sure where your workspace is? The server logs `Workspace: <path>` on
startup, and the title bar carries a **Workspace: &lt;name&gt;** menu naming the
active one. Typical locations:

| Case | Path |
|------|------|
| Default (portable / installed) | `workspace/` next to `muxit.exe` |
| Install directory not writable | `%LOCALAPPDATA%\Muxit\workspace` (Windows), `~/.muxit/workspace` (macOS / Linux) |
| Dev checkout | `<repo>/workspace` |
| Explicit | whatever you passed to `--workspace` |

The file is created on first run, so a fresh install already has one.

Changes to this file require a **server restart** to take effect (except where noted).

---

## Server

### WebSocket

```json
{
  "websocket": {
    "port": 8765
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `websocket.port` | int | 8765 | WebSocket server port. Also serves the web UI |

Override at startup: `node start.js server --port=9000`

### Polling Rates

```json
{
  "polling": {
    "connectorRate": 200,
    "broadcastRate": 50,
    "clientFlushRate": 100
  }
}
```

| Field | Type | Default | Unit | Description |
|-------|------|---------|------|-------------|
| `polling.connectorRate` | int | 200 | ms | How often to poll connector properties |
| `polling.broadcastRate` | int | 50 | ms | How often to batch state changes for WebSocket |
| `polling.clientFlushRate` | int | 100 | ms | How often clients flush pending state updates |

**Tuning tip:** If you have many polled properties and see high CPU, increase `connectorRate` to 500 or 1000. The default 200ms (5 polls/second) is a good balance for most setups.

### Logging

```json
{
  "logging": {
    "level": "info"
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `logging.level` | string | "info" | Minimum log level: `debug`, `info`, `warn`, `error` |

---

## Connectors

```json
{
  "connectors": {
    "enabled": ["test-device", "webcam", "mqtt"]
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `connectors.enabled` | string[] | (auto) | List of enabled connector names. If absent, the first N connectors are auto-selected based on your license tier |

Connector names correspond to filenames in `workspace/connectors/` (without `.js`). The **TestDevice** is always enabled regardless of this list.

Manage this from the Hardware panel — check/uncheck connectors and click Save.

---

## Scripts

```json
{
  "scripts": {
    "directory": "./scripts",
    "autoStart": []
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `scripts.directory` | string | "./scripts" | Path to the scripts directory (relative to workspace) |
| `scripts.autoStart` | string[] | [] | Script names to start automatically on server launch |

**Auto-start example:** `"autoStart": ["monitor", "mqtt-connect"]` runs these scripts when the server starts.

---

## Drivers

```json
{
  "drivers": {
    "directory": "./drivers"
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `drivers.directory` | string | "./drivers" | Path to the drivers directory (relative to workspace). Holds installed `.muxdriver` packages and (optionally) hand-dropped `.driver.js` files. Each `.muxdriver` is extracted on load into a hidden `.cache/<id>@<version>/` inside this directory |

---

## AI

```json
{
  "ai": {
    "provider": "muxit",
    "model": "anthropic/claude-haiku-4-5",
    "maxTokens": 2048,
    "instructions": "You are Muxit AI, an assistant for a hardware lab.",
    "historyMaxTurns": 12,
    "deviceSchemas": "adaptive",
    "cacheBreakpoints": false,
    "providers": {
      "ollama":   { "baseUrl": "http://localhost:11434/v1", "model": "llama3.2" },
      "lmstudio": { "baseUrl": "http://localhost:1234/v1", "model": "auto" }
    }
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `ai.provider` | string | `"muxit"` | LLM backend — `"muxit"` (cloud proxy), `"ollama"`, `"lmstudio"`, or `"openai-compatible"` |
| `ai.model` | string | provider default | Active model id. Cloud uses OpenRouter ids (`anthropic/claude-haiku-4-5`); local providers use the loaded model name (`llama3.2`, `auto`) |
| `ai.maxTokens` | int | `2048` | Max output tokens per response, editable as **Max response tokens** in Settings → AI Services. Raise for code-generation flows; the lower default keeps general-chat replies tight. A tool call that runs past this cap is refused with `AI_OUTPUT_TRUNCATED` rather than executed with partial arguments — see the [AI guide](https://docs.muxit.io/guides/ai.md#output-budget-and-truncated-replies) |
| `ai.instructions` | string | `""` | Custom system prompt prepended to AI conversations |
| `ai.promptProfile` | string | `"standard"` | `"standard"` keeps the full safety-confirmation fragment and the decision-tree guidance; `"minimal"` strips both for local LLMs with 4–8K context windows and forces `ai.deviceSchemas = "minimal"` regardless of that setting |
| `ai.historyMaxTurns` | int | `12` | Conversation history is capped at this many user turns; older turns are replaced with a single context-notice line. Set to `0` to disable trimming |
| `ai.deviceSchemas` | string | `"adaptive"` | How the system prompt presents `## Connected Devices`. `"full"` always inlines the per-device property/action schema (bytes per device); `"minimal"` always emits a one-line summary and tells the model to call `get_connector_schema(name)` on demand; `"adaptive"` (default) picks minimal unless the user's turn looks like a device interaction (verbs like read/write/set/measure, physical-units keywords, or an explicit connector name) |
| `ai.cacheBreakpoints` | bool | `false` | Attach Anthropic `cache_control: ephemeral` markers to the system prompt so the upstream caches it across turns. Default off until the Muxit cloud proxy is confirmed to forward the markers — see `docs/reference/ai-token-budget.md`. No effect on local OpenAI-compatible providers |
| `ai.favoriteModels` | string[] | `[]` | Model IDs shown in the model picker (e.g., `["anthropic/claude-sonnet-4-5"]`) |
| `ai.providers.<id>.baseUrl` | string | per provider | Endpoint for local providers — `http://localhost:11434/v1` for Ollama, `http://localhost:1234/v1` for LM Studio |
| `ai.providers.<id>.apiKey` | string | `""` | Optional bearer token for `openai-compatible` endpoints |
| `ai.providers.<id>.model` | string | per provider | Per-provider default model — used when the active provider is switched |

AI tool-call approval prompts are driven by the global safety level (see the [Safety Guide](https://docs.muxit.io/guides/safety.md)), not by a separate `ai` config key.

The default Muxit AI cloud provider authenticates with your license key — no separate API keys needed. Local providers (Ollama, LM Studio, OpenAI-compatible) are free on every tier, including Free; once enabled they bypass the cloud entirely so chat, scripts, agents, and vision all run on your own hardware.

For detailed AI setup, see the [AI & Voice Guide](https://docs.muxit.io/guides/ai.md).

---

## Voice

```json
{
  "voice": {
    "stt": {
      "provider": "browser",
      "providers": {
        "browser": {
          "language": "en-US"
        }
      }
    },
    "tts": {
      "enabled": false,
      "provider": "browser",
      "providers": {
        "browser": {
          "voice": "Google UK English Male",
          "rate": 1.1,
          "pitch": 0.9
        }
      }
    },
    "wakeWord": {
      "enabled": false,
      "word": "muxit",
      "sensitivity": 0.5
    },
    "autoSend": true
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `voice.stt.provider` | string | "browser" | Speech-to-text provider (browser Web Speech API) |
| `voice.stt.providers.browser.language` | string | "en-US" | STT language code |
| `voice.tts.enabled` | boolean | false | Enable text-to-speech for AI responses |
| `voice.tts.providers.browser.voice` | string | varies | TTS voice name (browser-dependent) |
| `voice.tts.providers.browser.rate` | number | 1.0 | Speech rate (0.5–2.0) |
| `voice.tts.providers.browser.pitch` | number | 1.0 | Speech pitch (0.5–2.0) |
| `voice.wakeWord.enabled` | boolean | false | Enable "Muxit" wake word for hands-free activation |
| `voice.wakeWord.word` | string | "muxit" | Wake word to listen for |
| `voice.wakeWord.sensitivity` | number | 0.5 | Wake word detection sensitivity (0–1) |
| `voice.autoSend` | boolean | true | Auto-send voice transcription when user pauses |

For detailed voice setup, see the [AI & Voice Guide](https://docs.muxit.io/guides/ai.md#voice-commands).

---

## UI

```json
{
  "ui": {
    "operatorDashboard": "operator/station.dashboard.json"
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `ui.operatorDashboard` | string | — | Dashboard the operator shell opens on (Settings › Accounts › Operator dashboards). Omit to use the first one found |

The operator shell's read-only AI chat has no config key: it is a per-dashboard
flag, `"chat": true` at the top level of the dashboard file (**Operator chat**
in the dashboard editor's settings).

**Operator mode** shows only the dashboards and scripts placed in the
`operator/` sub-folders of `workspace/dashboards/` and `workspace/scripts/`.
There is no switch for it here: a signed-in operator always gets the operator
shell, and every *anonymous* browser gets it when the
[anonymous-visitor policy](#accounts-config-accounts-json) in `accounts.json` is
`"dashboard"` (Settings › Accounts › Anonymous visitors). Under that policy
the server enforces it: every anonymous client is held to a write gate that
refuses authoring, the marketplace, safety-level changes, AI traffic and the
`/mcp` endpoint (`OPERATOR_MODE_RESTRICTED`). The editor API and the immediate
window are refused per request rather than switched off, so a signed-in
engineer or admin still reaches them — and can change the policy from
Settings, with no restart. Requires a Pro license (with a 60-day grace if one
lapses); a station whose license does not cover it runs unlocked and the
startup banner says so.

A single device can opt in without changing config by loading `?view=operator`
— that is presentation only and enforces nothing.

Who may sign in is not configured here. Accounts and the sign-in policy live in
`workspace/config/accounts.json` — see below.

---

## Accounts — `config/accounts.json`

Written by the server from **Settings › Accounts**; you do not normally edit it.
Requires a Pro license (with the same 60-day grace as operator mode); on a lower
tier the file is ignored and the startup banner says so.

```json
{
  "anonymous": "full",
  "idleTimeoutMinutes": 15,
  "accounts": [
    { "id": "root",    "name": "Root",     "role": "admin",    "pinHash": "…", "salt": "…" },
    { "id": "m.chen",  "name": "M. Chen",  "role": "engineer", "pinHash": "…", "salt": "…" },
    { "id": "j.smith", "name": "J. Smith", "role": "operator", "pinHash": "…", "salt": "…" }
  ]
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `anonymous` | string | "full" | What a connection that has not signed in gets. `full`: everything, signing in adds a name. `dashboard`: the operator shell only, held to the operator gate — this is what turns operator mode on (Pro license). `login`: may read but not act, and the full interface asks for an engineer or admin first. Anything else reads as `full` |
| `idleTimeoutMinutes` | number | 15 | Sessions end after this long with no activity (1–480) |
| `accounts[].id` | string | — | Letters, digits, dots, dashes, underscores. Appears in audit rows |
| `accounts[].name` | string | id | Display name |
| `accounts[].role` | string | "operator" | `admin`, `engineer` or `operator`. Anything else is an operator |
| `accounts[].pinHash`, `salt` | string | — | PBKDF2-SHA256, 100 000 iterations, base64. Never the PIN itself |

Lives here rather than in `server.json` because `server.json` is writable by
any engineer through `config.set`, and the sign-in policy must be an admin's to
change. No file means no accounts and no sign-in. A corrupt file loads as no
accounts. Deleting the file is the recovery path when the last admin's PIN is
lost. See the [Accounts guide](https://docs.muxit.io/guides/accounts.md).

---

## Security

```json
{
  "security": {
    "editorMode": true,
    "remoteAccess": false,
    "https": false,
    "bindAddress": "127.0.0.1"
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `security.editorMode` | boolean | true | File explorer, code editor, and immediate window. On by default; set to `false` for a read-only workspace |
| `security.remoteAccess` | boolean | false | Bind to all interfaces (0.0.0.0) for LAN access |
| `security.https` | boolean | false | Enable HTTPS with auto-generated self-signed certificate |
| `security.bindAddress` | string | "127.0.0.1" | Override bind address (advanced). Set to `0.0.0.0` for all interfaces |
| `security.hostnames` | string[] | [] | Extra host names a browser may use to reach Muxit — a Tailscale MagicDNS name, a tunnel or reverse-proxy name. Exact names, or `*.example.com` for every subdomain of a domain you control. A bare `*` is ignored. Restart after changing it. See [Host names](https://docs.muxit.io/guides/remote-access.md#host-names) |
| `security.allowExternalTransports` | boolean | false | Let connector and driver JS open TCP transports to hosts outside the local network. Off by default: `createTcpTransport()` reaches loopback and private ranges (10/8, 172.16/12, 192.168/16, 169.254/16) only. Prefer a connector's `allowedHosts` for a single endpoint |

**Editor mode** is enabled by default — a fresh install can create and edit
connectors and scripts straight away. It is also togglable from
**Settings › Server › Editor Mode** (restart the server afterwards). When it is
off, the file explorer shows a notice, `/api/editor/*` is not registered, and
`scripts.execute` (the immediate window) is rejected.

The `config/` directory is never readable or writable through the editor API, and
`drivers/` is never writable, in either mode. Paths are resolved before they are
checked, so `scripts/../config/server.json` and `./config/server.json` are refused
the same way `config/server.json` is, and nothing outside the workspace is
reachable at all.

**Host names.** Muxit answers only to the names it knows are its own:
`localhost`, `127.0.0.1`, `[::1]`, the address a connection arrived on, the names in
`security.hostnames`, and — with remote access on — this machine's host name,
`<host>.local` and the mDNS name. Any other `Host` header gets `403` with
`code: "HOST_NOT_ALLOWED"`. That is what stops a website from reaching Muxit by
DNS rebinding.

**Remote access password** is stored separately in `workspace/config/security.json` (hashed, never plaintext).
With remote access on and no password set, other computers are refused until one is set.

For detailed remote access setup, see the [Remote Access Guide](https://docs.muxit.io/guides/remote-access.md).

---

## Complete Example

Here's a fully annotated `server.json`:

```json
{
  "websocket": {
    "port": 8765
  },
  "polling": {
    "connectorRate": 200,
    "broadcastRate": 50,
    "clientFlushRate": 100
  },
  "logging": {
    "level": "info"
  },
  "scripts": {
    "directory": "./scripts",
    "autoStart": []
  },
  "drivers": {
    "directory": "./drivers"
  },
  "connectors": {
    "enabled": ["test-device", "webcam"]
  },
  "ai": {
    "provider": "muxit",
    "model": "anthropic/claude-haiku-4-5",
    "maxTokens": 2048,
    "instructions": ""
  },
  "voice": {
    "tts": { "enabled": false },
    "wakeWord": { "enabled": false },
    "autoSend": true
  },
  "security": {
    "editorMode": true,
    "bindAddress": "127.0.0.1"
  }
}
```
