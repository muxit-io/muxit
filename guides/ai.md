---
title: AI & Voice
description: Control lab hardware using natural language — chat, voice, MCP, and autonomous agents.
---

# AI & Voice

Muxit AI lets you control lab hardware using natural language — via chat or voice in the browser UI. It uses a managed AI proxy service with a safety gate that requires user approval before executing device commands.

::: tip In one line
**MCP** (bring your own AI client) and **Local LLM** (Ollama, LM Studio, any OpenAI-compatible endpoint) are **free on every tier** — and so is **text-only** script **`ai()`** when pointed at one of them. The **Muxit-managed AI service** — managed-cloud Chat Panel, voice, `ai()` against Muxit, and AI-assisted SCPI authoring — requires **Maker**. **AI image analysis** — the AI *seeing* a camera frame (Chat Panel + MCP `take_snapshot`, and the `ai(prompt, image)` overload on *any* provider) — also requires **Maker**. **Autonomous Agents** require **Pro**, and the **Vision engine** (real-time object detection, teach-by-example, calibration, visual servoing) is a **premium extension** — install it from the marketplace and license it separately on **Pro and above**. See [AI features by tier](#ai-features-by-tier) below for the full picture.
:::

## AI features by tier

| Capability | Free | Maker | Pro+ |
|---|:--:|:--:|:--:|
| **MCP server** — Claude Desktop / Claude Code / ChatGPT* drives your hardware via your own AI provider | ✓ | ✓ | ✓ |
| **Local LLM** — point Muxit at Ollama, LM Studio, or any OpenAI-compatible endpoint | ✓ | ✓ | ✓ |
| **Chat Panel (against a local LLM)** — built-in chat with tool calling, using your local model | ✓ | ✓ | ✓ |
| **`ai(prompt)` text-only script global (against a local LLM)** — single-shot LLM calls from automations | ✓ | ✓ | ✓ |
| **Connector `ai: { instructions }`** — your safety rules and device context appear in every AI prompt | ✓ | ✓ | ✓ |
| **JS scripts** — write automations (3 on Free, unlimited on Maker+) | ✓ | ✓ | ✓ |
| **Hand-authored connectors** — write `.js` connector configs yourself | ✓ | ✓ | ✓ |
| **`say()`, `ask.confirm/choose/text`** — TTS and dashboard prompts | ✓ | ✓ | ✓ |
| **Muxit-managed AI** — Chat Panel, voice, and `ai()` against the managed cloud proxy (no API key plumbing) | — | ✓ | ✓ |
| **Voice** — speech-to-text input, spoken responses | — | ✓ | ✓ |
| **AI-assisted SCPI authoring** — "Set up with AI" button drafts a connector from a programming manual | — | ✓ | ✓ |
| **AI credits / month** (Muxit-managed only) | — | 500 | 1500 (Pro) / 4000 (Lab) |
| **AI image analysis** — the AI can see camera frames in Chat Panel and MCP (`take_snapshot`) and via the `ai(prompt, image)` overload (any provider) | — | ✓ | ✓ |
| **Vision engine** *(premium extension)* — real-time object detection, teach-by-example, calibration, visual servoing; reached via `call_action`/`read_property` on your Vision connector | — | — | ✓ (Pro + license) |
| **Autonomous Agents** — long-running goal-driven AI | — | — | ✓ (Pro) |

<small>* ChatGPT's connector UI rejects loopback URLs, so it needs a public HTTPS tunnel and the security caveats in the [MCP Server section](#2-mcp-server). Claude Desktop and Claude Code work locally with no extra setup.</small>

### What you get on Free

A lot. Point **Claude Desktop**, **Claude Code**, or **ChatGPT** (with a tunnel — see below) at Muxit's MCP server and your AI client gets the same 57 tools the built-in chat uses — list connectors, read and write properties, call actions, take camera snapshots, run and write scripts, write connector configs. You drive your bench in natural language using your own AI subscription, and Muxit charges nothing for it.

You can also point Muxit's own **Chat Panel** and the script **`ai()`** function at a local LLM — Ollama, LM Studio, or any OpenAI-compatible endpoint — in **Settings → AI Services**. The same chat surface and the same text-only script call, just running against a model you host yourself. Air-gapped labs, fully-offline workflows, and "bring-your-own model" stay on the Free tier. (Attaching an image to `ai()` is **AI image analysis**, a Maker capability — gated even on a local model; text-only inference is what's free.)

You can write JS scripts (up to 3), author connectors by hand, and embed `ai: { instructions }` blocks so any AI that touches your hardware sees your safety rules and device context. `say()`, `ask.confirm`, and dashboard prompts all work. For a one-person lab already using Claude Code or Ollama, this is a complete workflow.

### What Maker unlocks

The things MCP and local LLMs don't give you out of the box — Muxit's managed AI service:

- **Muxit-managed Chat Panel and voice** — same UI as the Free local-LLM chat, but backed by Muxit's hosted proxy. Premium frontier models (Anthropic Claude, OpenAI GPT, and more) without managing API keys, billing, or rate limits yourself. Talk to your bench while your hands are full, see tool calls inline.
- **`ai()` in scripts against Muxit-managed** — `if (ai("Is this reading abnormal?", reading) === "yes") …`. Single-shot inference inside your automations, no API key plumbing. (Free users can already use text-only `ai()` against a local LLM; Maker is what unlocks the managed-cloud route.)
- **AI image analysis** — attach a camera frame to `ai(prompt, image)` (e.g. `ai("Is the part aligned?", connector('webcam').snapshot)`) and the model *sees* it. The same capability powers `take_snapshot` in the Chat Panel and MCP, so the assistant can look at your bench on its own. Works on any provider, managed or local.
- **AI-assisted SCPI authoring** — point the AI at a programming manual; it probes the device, drafts a connector, validates it, and brings it online. Hours of vendor-PDF spelunking become a chat turn.
- **500 AI credits / month** included — managed proxy, no per-request billing to set up.

### Beyond Maker

**Pro** is where heavier vision and autonomy live. Basic **AI image analysis** — the AI seeing a camera frame — is already a **Maker** capability; Pro goes further with the **Vision engine**: OpenCV-backed object detection, teach-by-example, spatial calibration, and visual servoing. It's a separately-licensed **premium extension** that installs on Pro and above; see the [Vision driver reference](https://docs.muxit.io/reference/drivers/vision.md). Pro also unlocks **Autonomous Agents** for long-running goal-driven work — plus a 1500-credit allowance.

## Ways to Use AI

| Method | What it is | Best for |
|--------|-----------|----------|
| **Chat Panel** | Browser sidebar with natural language input | Interactive use in the web UI |
| **MCP Server** | Model Context Protocol over HTTP and stdio | Claude Code, Claude Desktop, MCP-compatible AI tools |

---

## Quick Start

### 1. Chat Panel (Browser Web UI)

The Chat Panel provides a full AI assistant that can control your devices, read sensors, write scripts, and answer questions — all via natural language (text or voice). It uses an agentic tool-calling loop: the LLM decides which tools to call, executes them, and continues until it has a final answer.

Muxit AI is the default — no API keys needed. It uses your Muxit license to authenticate with a managed AI proxy service at `api.muxit.io`.

Click the gear icon to open Settings. Under **AI Services**, select **Muxit AI**.

**Model selection:**
- **Auto (recommended)** — Muxit selects the best model for each request based on task complexity and your subscription tier. This is the default.
- **Manual** — Pick a specific model from your favorites list to always use that model.

Credits are included with your Muxit subscription. You can purchase additional credits (top-up packs) at [muxit.io/buy](https://muxit.io/buy) — check out with the same e-mail address as your subscription so the credits are applied to your account.

**Chat model favorites:** You can curate a shortlist of your preferred Muxit AI (cloud) models in Settings under **Chat model favorites**. These appear as shortcuts in the Chat header model picker for quick switching. Local providers (Ollama, LM Studio) list whatever models they have loaded automatically, so favorites don't apply to them.

#### Starting the server

```bash
node start.js server       # MuxitServer (serves web UI at http://127.0.0.1:8765)
node start.js server       # Auto-open browser
```

Open AI Chat by clicking the chat icon in the Activity Bar.

### 2. MCP Server

The MCP server is built directly into MuxitServer (C#), exposing device control tools and resources over the Model Context Protocol. The recommended path is the **HTTP transport** that runs on the live server — both Claude Code and Claude Desktop connect to that same endpoint, so you never have two MuxitServer processes racing for the same workspace.

**HTTP transport** — Available at `/mcp` on the running server (e.g. `http://127.0.0.1:8765/mcp`, or whatever `websocket.port` resolves to). Starts automatically with the server.

**Stdio transport** — Still available for clients that can't speak HTTP MCP, and used by Muxit's own embedded tooling:

```bash
node start.js mcp                    # Via start script
dotnet run --project MuxitServer -- --mcp  # Direct
```

Stdio mode boots a self-contained MuxitServer in the foreground; it does **not** connect to an already-running server, so don't pair it with Claude Desktop/Code while the main server is up — use the HTTP transport instead.

**Claude Code** connects directly to the HTTP endpoint:

```bash
claude mcp add --transport http muxit http://127.0.0.1:8765/mcp
```

Adjust the port if you've overridden `websocket.port`. Muxit must be running when Claude Code starts. This writes the config to `~/.claude.json` so it's available across all your projects.

If you're working in this repository's source tree, the project-level `.mcp.json` at the repo root is already wired up to the same HTTP endpoint — Claude Code picks it up automatically when you launch from this directory.

**Claude Desktop** only speaks stdio MCP, so it needs a bridge. Use [`mcp-remote`](https://www.npmjs.com/package/mcp-remote) to forward stdio to the running HTTP endpoint. Add to `claude_desktop_config.json` (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS, `%APPDATA%\Claude\claude_desktop_config.json` on Windows):

```json
{
  "mcpServers": {
    "muxit": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://127.0.0.1:8765/mcp", "--allow-http"]
    }
  }
}
```

Requires Node.js on the host (`npx` fetches `mcp-remote` on first run). Muxit must be running before you launch Claude Desktop. Fully quit Claude Desktop from the tray and reopen after editing.

**ChatGPT** — ChatGPT's connector UI rejects loopback and private-IP addresses (`127.0.0.1`, `localhost`, `10.*`, `192.168.*`) as **"unsafe url"** and requires a publicly reachable HTTPS endpoint with a valid TLS certificate. This is a constraint of ChatGPT, not Muxit — there's no way to point ChatGPT at the local `/mcp` URL directly.

To use ChatGPT with Muxit you have to expose the local endpoint over a public HTTPS tunnel. Quickest path with [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/):

```bash
cloudflared tunnel --url http://127.0.0.1:8765 --http-host-header 127.0.0.1:8765
# → https://<random-name>.trycloudflare.com
```

`--http-host-header` matters: without it `cloudflared` forwards the public name as the request's `Host`, and Muxit refuses names it does not know as its own (its [DNS-rebinding defence](https://docs.muxit.io/guides/remote-access.md#host-names)) with `403 HOST_NOT_ALLOWED`. A quick tunnel's name changes every run, so presenting the local address is simpler than listing it.

For a tunnel with a fixed name (a named Cloudflare tunnel, `tailscale funnel`, ngrok with a reserved domain), you can instead add that name to `security.hostnames` in `server.json` and restart.

Then in ChatGPT, **Settings → Apps → Advanced settings → Create app**, enter `https://<random-name>.trycloudflare.com/mcp` as the MCP server URL with **No Auth**.

::: danger Security warning — read this before running a tunnel
Muxit's HTTP API treats every loopback request as authenticated, and a tunnel daemon (cloudflared, ngrok, etc.) running on the same machine reaches Muxit *over loopback*. **A public tunnel exposes your hardware to anyone who guesses the URL — they can read sensors, write properties, and run scripts with no credentials.**

Muxit's optional password (`security.remoteAccess` + `X-Auth-Token` header) doesn't help here either: it's bypassed for loopback callers, and it uses a custom header name that ChatGPT's connector can't send.

Acceptable mitigations:
- **Tailscale Funnel** restricted to your tailnet — the tunnel isn't actually public, only your devices can reach it.
- **Cloudflare Access** in front of a Cloudflare Tunnel — adds an auth gate Muxit doesn't ship today.
- A short-lived `cloudflared`/`ngrok` URL spun up only for the duration of a session and torn down right after.

If none of those apply, prefer Claude Desktop or Claude Code, which connect to the local MCP server over stdio and don't need a tunnel at all.
:::

::: tip
Open **Settings > MCP** in the Muxit GUI for ready-to-copy config snippets with your actual server paths.
:::

#### MCP Tools

| Tool | Description | Category |
|------|-------------|----------|
| `list_connectors` | List all devices and capabilities | Device Control |
| `get_connector_schema` | Get full schema for a device | Device Control |
| `read_property` | Read a device property | Device Control |
| `write_property` | Set a device property | Device Control |
| `call_action` | Execute a device action | Device Control |
| `get_device_state` | Snapshot of all cached state | Device Control |
| `list_scripts` | List available and running scripts | Scripts |
| `run_script` | Start a named script (bounded wait, returns `running` on long scripts) | Scripts |
| `run_code` | Execute inline JavaScript (bounded wait, returns `running` on long scripts) | Scripts |
| `stop_script` | Stop a running script | Scripts |
| `get_script_status` | Check status / result / error of a running or recently-finished script | Scripts |
| `get_script_output` | Fetch buffered log output (with `since_seq` cursor) | Scripts |
| `wait_for_script` | Block up to 120s waiting for a running script to finish | Scripts |
| `read_script_source` | Read a script's source code | Files |
| `write_script` | Create or update a script file | Files |
| `read_startup_script` | Read a startup script's source code | Files |
| `write_startup_script` | Create or update a startup script | Files |
| `read_connector_config` | Read a connector config file | Files |
| `write_connector_config` | Create or update a connector config (auto-backup; chat-gated on overwrite) | Files |
| `list_connector_backups` | List automatic backups of connector configs | Files |
| `restore_connector_backup` | Restore a connector config from a backup | Files |
| `list_drivers` | List available drivers | System |
| `get_driver_schema` | Get full schema for a specific driver | System |
| `get_server_config` | Get server configuration (redacted) | System |
| `take_snapshot` | Capture a camera image for visual analysis | Core |
| `list_agents` | List agent configs and running instances | Agents |
| `start_agent` | Start an agent with a goal | Agents |
| `stop_agent` | Stop a running agent | Agents |
| `get_agent_status` | Get current status of an agent | Agents |
| `pause_agent` | Pause a running agent | Agents |
| `resume_agent` | Resume a paused agent | Agents |
| `read_instructions` | Read the central lab instructions file | Instructions |
| `write_instructions` | Update the central lab instructions file | Instructions |
| `list_processes` | List available process definitions | Processes |
| `read_process` | Read a process definition by name | Processes |
| `write_process` | Create or update a process definition | Processes |
| `list_dashboards` | List dashboard files in `workspace/dashboards/` | Dashboards |
| `read_dashboard` | Read a dashboard's JSON content | Dashboards |
| `write_dashboard` | Create or update a `.dashboard.json` file | Dashboards |

#### MCP Resources

| URI | Description |
|-----|-------------|
| `muxit://connectors` | List of all connectors with schemas |
| `muxit://connector/{name}/schema` | Schema for a specific connector |
| `muxit://state` | Current device state snapshot |

---

## Tool-Call Approvals

Tool-call approval prompts are driven by the global safety level (set via the **SafetyChip** in the status strip), not by a separate AI-only switch. In **Observe** and **Assisted**, the Chat Panel shows an approval dialog with the tool name, parameters, and Allow/Deny buttons. In **Active** and **Unrestricted**, tool calls execute without prompting (destructive actions still confirm per the safety policy). See the [Safety Guide](https://docs.muxit.io/guides/safety.md) for the full behaviour table.

**Stop the assistant asking before a specific, non-critical action** — a camera pan/tilt, a fan nudge — without disabling confirmation everywhere: add a per-item entry to that connector's `safety.confirm` block:

```js
safety: { confirm: { pan: "never", tilt: "never" } }
```

`never` skips the prompt for that property/action across the UI, scripts, **and** the AI chat panel; `always`/`typed` force one even for a no-argument action. This is per-item, unlike the global *AI confirmation* column (all-or-nothing). See [per-item overrides for the chat-gate](https://docs.muxit.io/guides/safety.md#per-item-overrides-for-the-chat-gate).

---

## AI Chat Tools

The Chat Panel uses the same tools as the MCP server. The AI assistant decides which tools to call based on your request. Depending on the current safety level, tool calls may show an approval dialog before executing.

### Adding a device (guided setup)

Onboarding a new device — an oscilloscope, multimeter, power supply, Arduino, sensor,
or a FileAccess connector for writing data — is a **dedicated chat flow** you start
explicitly: open the **Connectors panel** and click **"+ Add device"**. That opens the
chat in **device-setup mode** (a banner marks it), which probes the device, looks up its
command set, writes the connector config, and hot-reloads it — no server restart.

Device setup is deliberately separate from normal chat. In setup mode the assistant is
narrowed to the connector-creation toolset — the probe/discover/compose tools, the config
tools, and the core device tools — so it can probe the device, write the connector,
hot-reload it, and then **test it end to end**: read a value back, set a value and confirm
it took, or run reset/self-test. (Those test writes still go through the safety
confirmation gate.) Scripts, agents, dashboards and the like are left out, so the system
prompt carries only the authoring guide and stays small and focused. **Exit setup** in the banner returns
you to a normal session.

Normal chat no longer guesses at device-authoring intent: saying "turn the power supply
off" operates your existing supply, it does **not** drag in the multi-kilobyte onboarding
guide. If you ask to add a device in a normal chat, the assistant points you to the
"+ Add device" button. See [AI-assisted SCPI setup](https://docs.muxit.io/guides/ai-scpi-authoring.md) for the full
walkthrough. (The legacy driver name **GenericScpi** still works in older connector files
via an alias.)

### Open created files in the editor

Whenever the assistant writes or updates a workspace file — a connector, a
script, a startup script, or a dashboard — the chat shows a clickable file
link (e.g. 📄 `scripts/monitor.js`) under that reply. Click it to open the
file in the editor pane: scripts and connectors open as text, dashboards open
in the visual dashboard editor. If the AI rewrites the same file more than once
in a turn, a single link to the latest version is shown.

The link is driven by the tool result, not by the wording of the reply, so it
appears for any file the AI actually saved — including files you asked it to
write under a specific name.

### Guided Tour & Docs Access

The chat has direct access to every page in this documentation site, so "how do I…" questions get real guide content quoted back instead of a best-guess answer. Three tools power this:

| Tool | What it does |
|------|--------------|
| `list_docs` | Enumerates every bundled doc path (guides, getting-started, reference, examples). |
| `search_docs` | Full-text, case-insensitive search — returns the top hits with a short snippet. |
| `read_doc` | Returns the raw markdown for a given path, e.g. `guides/connectors.md`. |

The docs are embedded into the server binary at build time, so they're available offline and always match the running version. The chat picks them up automatically when your question includes phrases like *how do I*, *walk me through*, *tour*, *tutorial*, *getting started*, or *what is*.

The **Help → Guided Tour** menu in the title bar is the fastest way in: each item opens the chat and sends a pre-written starter prompt so the AI walks you through a specific task.

- **Guided Tour (AI)** — "Give me a tour of Muxit"
- **Tour: Install a Driver** — finds the current driver-marketplace procedure
- **Tour: Create a Connector** — walks through the first-connector guide
- **Tour: Drag Properties into a Script** — explains how the hardware pane's drag targets work
- **Tour: Build a Dashboard** — walks through dashboards and widget binding

You can also ask for a tour in your own words — the menu is a convenience, not a gate.

### Vision (Camera Snapshots)

The `take_snapshot` tool captures a single frame from any camera connector (USB webcam, IP camera) and returns it as an image content block. The LLM can then see and describe the image — useful for checking robot positions, reading instrument displays, or verifying alignments.

**Requirements:**
- A camera connector must be configured and initialized
- The LLM model must support vision (Claude Sonnet/Opus, GPT-4o, Gemini)

**Example prompts:**
- "Take a snapshot from the webcam and tell me what you see"
- "Is the robot arm aligned with the target? Check the camera"
- "What's the reading on the oscilloscope display?"

---

## Voice Commands

Voice is a core Muxit feature — control your devices by speaking. The Chat Panel header includes a mic button with a dropdown for voice settings.

Muxit does **not** ask for microphone access at startup. The browser's microphone permission prompt appears the first time you interact with voice — pressing the mic button, opening the voice dropdown, or enabling the wake word. If you never use voice, you are never asked. Decline the prompt and the mic button reports "Microphone access denied" only when you actually try to talk; text chat is unaffected.

### Two Modes

| Mode | How it works |
|------|-------------|
| **Push to Talk (PTT)** | Hold the mic button to talk. Release to stop. Your speech is transcribed and sent as a chat message. |
| **Hands-free** | Click the mic button to toggle listening. Behavior depends on wake word setting. |

**Hands-free sub-modes** (configured in Settings > Voice > Wake Word):

| Wake Word Setting | Hands-free Behavior |
|---|---|
| **Enabled** | Say "Muxit" to start a **conversation**. Muxit listens, sends your command, speaks the AI response (if TTS is on), then automatically resumes listening — no need to say the wake word again. The conversation ends after an adjustable silence timeout (default 10s). |
| **Disabled** | Muxit listens continuously. When you pause speaking, the transcript is automatically sent. If TTS is on, listening pauses while the response is spoken and resumes once playback ends, so the AI's voice isn't fed back into the mic. |

### Conversation Loop

When **TTS** is enabled in hands-free mode, Muxit supports a natural spoken conversation. With **wake word** also enabled:

1. Say "Muxit" to start the conversation
2. Speak your command — it's transcribed and sent to the AI
3. The AI responds and TTS speaks the response
4. Muxit automatically starts listening again (no wake word needed)
5. Continue the conversation naturally
6. When you stop talking, the conversation ends after a configurable idle timeout

With **wake word disabled**, the same speak → respond → resume rhythm applies on every utterance — no trigger phrase needed, but every captured phrase is sent.

**Idle timeout:** Adjust how long Muxit waits for you to speak before ending the conversation. Open the mic dropdown (▾ next to the mic button) and use the **Idle** slider (3–30 seconds, default 10s). You can also manually end the conversation by clicking the Stop button.

### Text-to-Speech

Toggle TTS on/off with the speaker icon in the chat header. When enabled, AI responses are spoken aloud using browser speech synthesis. The AI automatically keeps responses short and voice-friendly.

While Muxit is talking, a **Speaking… [Stop]** row appears below the latest reply in the chat. Click **Stop** to interrupt a long answer without reaching for the header toggle. While you're speaking, your in-progress transcription shows up as a live **You** bubble at the bottom of the chat so it's visible right where the latest reply is.

Configure voice, rate, and pitch in Settings > Voice > Text-to-Speech.

The chat-header toggle controls **AI replies only**. Script `say()` output has its own toggle in the top status strip (next to STOP ALL) so you can mute one source without silencing the other. Both toggles share the same voice / rate / pitch settings.

### Wake Word

Say "Muxit" to start a voice conversation hands-free. Enable in Settings > Voice > Wake Word.

Voice uses browser speech recognition (Web Speech API). Works in Chrome and Edge.

### Settings Apply Instantly

Changes to **Voice**, **AI Services**, and **AI Behavior** settings take effect without a page refresh:

- AI model and system prompt — applied on your next chat message.
- TTS voice, rate, pitch, and enabled toggle — applied on the next utterance.
- Wake word phrase, enable/disable, and microphone selection — applied immediately; the background listener restarts in place.

A small **Saved — applied immediately** badge appears in the top-right of the Settings pane after each change to confirm it was saved.

---

## AI in Scripts

Scripts can make single-shot LLM calls using the `ai()` global:

```javascript
// Text-only query
const answer = ai("Classify this reading as normal or abnormal: 47.3 ohms");
log.info(answer);

// Vision: analyze a camera image
const cam = connector('webcam');
const frame = cam.snapshot;
const description = ai("Describe what you see in this image", frame);
log.info(description);

// Compare images: pass an array to attach several frames in one call.
// Great for before/after ("what changed?") or A/B reference matching.
const fa = connector('fileaccess');
const verdict = ai("Does the current part match A (good) or B (rejected)?", [
  { image: fa.openBinary('refs/good.jpg').read(),     label: "A: good" },
  { image: fa.openBinary('refs/rejected.jpg').read(), label: "B: rejected" },
  { image: cam.snapshot,                              label: "Current" },
]);
log.info(verdict);

// Video recording
const file = cam.record({ seconds: 10 });
log.info(`Recorded: ${file}`);
```

`ai(prompt, image?)` is a single-shot call — no conversation memory, no tool access, no agentic loop. The second argument may be a single base64 JPEG or an **array** of images (bare strings or `{ image, label }` objects, up to 8) when you need the model to compare frames. Reference images can come straight off disk via the [FileAccess driver](https://docs.muxit.io/reference/drivers/file-access.md)'s `openBinary(path).read()`.

---

## Agent Mode

Agents are autonomous AI instances that can coordinate multiple devices to accomplish goals. Unlike the chat loop (which responds to single messages), agents are persistent, goal-oriented, and can react to device events.

### Quick Start

**From chat:**
```
"Pick up the red part and place it in the tray"
```

**From saved config** (`workspace/agents/*.agent.json`):
```json
{
    "name": "pick-and-place",
    "description": "Pick a part and place it in the tray",
    "devices": ["robot", "camera"],
    "autonomy": "supervised",
    "safety": {
        "maxSpeed": 50,
        "workspace": { "x": [0, 600], "y": [-300, 300], "z": [50, 400] },
        "maxForce": 20,
        "requireVisionConfirm": true
    },
    "instructions": "Always approach from above. Verify grip before lifting.",
    "parameters": {
        "partColor": { "type": "string", "default": "red" }
    }
}
```

### Autonomy Levels

| Level | Behavior | Best For |
|-------|----------|----------|
| **supervised** | Each action shown to user in real-time, proceeds unless stopped | First-time tasks, dangerous ops |
| **plan-approve** | Agent creates plan, user approves, then executes freely | Repetitive tasks |
| **guardrails** | Runs freely within safety boundaries, pauses only on limit violation | Trusted tasks |
| **full** | No approval needed (safety limits still enforced) | Well-tested automation |

### Safety Boundaries

Enforced regardless of autonomy level:

| Boundary | Config Key | Description |
|----------|-----------|-------------|
| Workspace limits | `safety.workspace` | Bounding box the robot cannot leave |
| Speed limits | `safety.maxSpeed` | Max velocity as % of device max |
| Force limits | `safety.maxForce` | Max force (N) before emergency stop |
| Rate limits | `safety.maxActionsPerMinute` | Prevent hammering hardware |
| Vision confirm | `safety.requireVisionConfirm` | Camera snapshot before/after critical actions |

When `requireVisionConfirm` is enabled, the safety gate enforces that the agent "looked" within the last 30 seconds before any movement or grip action is allowed — that is, a `take_snapshot`, a `call_action` for the Vision engine's `snapshot` / `identifyObjects` / `locateObject` / `approach`, or a `read_property` of the vision connector's `detections`. If no recent look exists, the action is blocked with an error message prompting the agent to take a snapshot first.

### Operational Limits

| Limit | Default | Config |
|-------|---------|--------|
| Max concurrent agents | 5 | License-gated (Pro and above) — not configurable |
| Approval timeout (supervised mode) | 5 minutes | Not configurable — action is auto-denied if user doesn't respond |
| Max iterations | 100 | `maxIterations` in agent config (-1 for unlimited) |
| Max runtime | 300 seconds | `timeoutSeconds` in agent config |
| Completed agent cleanup | 5 minutes | Completed/failed/stopped agents are removed from the running list after 5 minutes |

### Starting Agents from Chat

You can start an agent directly from the AI chat by describing a multi-step task. The chat system creates an **ad-hoc agent** with default settings:

```
"Pick up the red part and place it in the tray"
```

Ad-hoc agents use **supervised** autonomy by default and inherit the global LLM model. For more control, create a saved config file in `workspace/agents/*.agent.json`.

### Event Triggers

Agents can start automatically when device conditions are met:

```json
{
    "triggers": [
        {
            "event": "state:psu.temperature",
            "condition": "gt:80",
            "cooldownSeconds": 120,
            "goal": "Temperature too high — reduce power"
        }
    ]
}
```

Condition formats: `gt:80`, `lt:10`, `eq:true`, `neq:off`, `changed`

### Process Files

Agents can reference structured procedure files that guide them through complex tasks. Process files live in `workspace/processes/*.process.md` and are linked via the `processFile` config field:

```json
{
    "name": "pick-and-place",
    "devices": ["robot", "camera"],
    "processFile": "pick-and-place",
    "instructions": "Additional agent-specific notes..."
}
```

When the agent starts, the process content is injected into its system prompt. See [Process Definitions](#process-definitions) for the file format.

### Agent Timeline & Transparency

Running agents stream a real-time **timeline** of their execution, showing what the agent is thinking, doing, and observing. Each entry has a type:

| Type | Meaning | Example |
|------|---------|---------|
| `thought` | LLM reasoning text | "I can see the red ball at (320, 240). I'll move above it first." |
| `action` | Tool call being executed | `call_action({connector: "robot", action: "moveJ", ...})` |
| `observation` | Tool result received | `read_property → {"x": 150, "y": 30, "z": 200}` |
| `error` | Tool failure or safety block | `Blocked: moveJ — speed=75% exceeds max 50%` |
| `user_input` | Agent asked a question | "Which object should I pick up?" |

The **Reasoning** field shows the agent's latest LLM output — what it's currently "thinking" before choosing its next action.

**Agent status includes:**
- `iteration` — number of LLM calls made
- `tokensUsed` — approximate tokens consumed
- `elapsedSeconds` — time since start
- `timeline` — full chronological event list
- `reasoning` — latest LLM reasoning text

Use `agent.detail` WebSocket message to fetch the full timeline, or subscribe to `agent.timeline` broadcasts for real-time streaming. The UI's **AgentMonitor** component displays all of this with tabs for Timeline, Plan, and Logs.

### Per-Agent Model Selection (Cost Optimization)

Each agent can override the global LLM model and token limit. Simple agents (monitoring, condition checking) can use cheap models while complex agents (vision-guided manipulation) use premium models.

```json
{
    "name": "temperature-monitor",
    "devices": ["test-device"],
    "model": "google/gemini-2.5-flash",
    "maxTokens": 1024,
    "maxIterations": 30
}
```

**Model cost tiers:**

| Tier | Models | ~Cost/MTok |
|------|--------|-----------|
| $ (cheap) | `google/gemini-2.5-flash`, `deepseek/deepseek-chat-v3-0324`, `openai/gpt-4o-mini` | $0.10–0.30 |
| $$ (mid) | `anthropic/claude-haiku-4-5`, `google/gemini-2.5-pro`, `openai/gpt-4o` | $1–5 |
| $$$ (premium) | `anthropic/claude-sonnet-4-5` | $5–15 |

If `model` is omitted, the agent uses the global model from Settings. Anthropic models automatically use prompt caching for repeated system prompts (~50% input token savings in agent loops).

### Smart Tool Filtering (Automatic Cost Optimization)

Muxit automatically classifies each chat message to determine which tools are relevant, then sends only those tools to the AI model. This dramatically reduces token overhead and improves reliability with cheaper models.

**How it works:**

- **Muxit AI:** A free classifier model analyzes your message before the main AI call. This adds ~100-300ms latency but costs nothing.
- **MCP providers:** Classification is handled by the external AI client.
- **Fallback:** If classification fails, all tools are sent (same as previous behavior).

**Example impact:**

| Request | Tools Sent | Token Savings |
|---------|-----------|---------------|
| "Move robot to 500,500,400" | 6 (core only) | ~80% fewer tool tokens |
| "Write a monitoring script" | 12 (core + scripts) | ~65% fewer tool tokens |
| "Take a photo of the workspace" | 12 (core + vision) | ~65% fewer tool tokens |
| "What's the meaning of life?" | 57 (all tools) | 0% (general fallback) |

**Tool groups:**

| Group | Tools | When Active |
|-------|-------|-------------|
| Core | list_connectors, read/write_property, call_action, get_device_state, get_connector_schema, take_snapshot | Always |
| Scripts | list/run/stop/write scripts, run_code | Script/automation requests |
| Agents | list/start/stop agents, agent status | Agent/autonomous requests |
| Memory | save/delete/list memories | Memory requests |
| Config | connector configs, drivers, server config | Config requests |
| Instructions | instructions, process definitions | Process/instruction requests |

The script API guide (~500 tokens) is also excluded from the system prompt when scripts are not relevant, further reducing costs.

This feature requires no configuration — it's always active and falls back gracefully.

### Inspecting the system prompt (`/prompt`)

Type **`/prompt`** in the chat input to see exactly what the assistant is being told. The command is handled locally — it never goes to the model — and opens an inspector card showing:

- **Total size vs the provider cap.** The Muxit cloud (via OpenRouter) rejects any request whose top-level `system` field exceeds **32 000 characters** with `validation_error: String must contain at most 32000 character(s)`, *before* the call is billed — so an over-budget turn produces no entry in `workspace/logs/ai-tokens-*.jsonl`. The inspector flags this in red so you can catch it without sending a doomed request.
- **A per-section breakdown** — identity, device-authoring guide, connected devices, decision tree, your instructions, etc.
- **A per-connector breakdown** of the *Connected Devices* block. With many connectors enabled (or a device with a large property/action surface like a spectrometer), this section is usually what drives the prompt over the cap.
- The active **tool groups**, **tool names**, **prompt profile**, and **model**.

Pass a message to preview the prompt *for that message* — e.g. `/prompt turn the power supply off` — since intent classification (and therefore which fragments and device schemas are included) depends on what you say. A bare `/prompt` previews a general-chat turn.

If a prompt is over the cap, the quickest levers are: disable a connector you aren't using, set `ai.deviceSchemas` to `"minimal"` (one line per device instead of full inline schemas), switch `ai.promptProfile` to `"minimal"`, or trim your custom instructions.

---

## When to Use What

| Approach | Best For | How It Works |
|----------|----------|-------------|
| **Chat Panel** | Interactive questions, one-off commands | You type, AI responds with tool calls |
| **Scripts with `ai()`** | Automated decisions, classification, vision | Script calls `ai()` for a single LLM response |
| **Agents** | Multi-step autonomous goals, reactive automation | Persistent AI loop: plan, act, observe, re-plan |
| **MCP Tools** | External AI tools (Claude Code/Desktop) | AI calls Muxit tools via MCP |

---

## AI Memory

Muxit AI remembers facts and preferences across sessions. Tell the AI "remember that..." to save a memory, or "forget that..." to remove one.

Memories are stored locally in `workspace/config/ai-memory.json`. Click the **M** button in the Chat Panel header to view, edit, or delete memories.

| Category | Examples |
|----------|---------|
| `preference` | "User prefers metric units" |
| `device` | "The PSU on the left bench is named 'main-psu'" |
| `procedure` | "Calibration: reset PSU, set 5V, wait 10s, read" |
| `note` | "Don't run scripts during backup (2-3am)" |

---

## Vision-Guided Robot Control

Muxit supports closed-loop visual servoing — using camera feedback to guide robot movements in real time. The system uses a two-speed approach:

- **Fast local CV** (Vision engine + OpenCV): Runs color/contour detection at camera frame rate for real-time tracking. No LLM calls, no latency.
- **Slow LLM vision**: Sends a frame to the LLM for high-level scene understanding, object identification, and planning. Used for initial assessment and verification, not tight control loops.

The combination lets agents plan with full visual intelligence but execute with the speed of classical computer vision.

::: tip Where the vision capabilities live
All vision intelligence — identification, location, teaching, calibration, servoing — lives on the **Vision engine connector** as its own actions. The AI reaches them through the generic device-control tools, e.g. `call_action(vision, identifyObjects, { query })` or `read_property(vision, detections)`. The only dedicated core tool is `take_snapshot`, which attaches a camera frame to the conversation. The examples below name the engine actions (`identifyObjects`, `teachObject`, …); older drafts referred to standalone tools (`identify_objects`, `teach_object`) — they map one-to-one.
:::

### Setting Up a Vision Connector

Create a connector config that uses the Vision driver with a webcam source:

```js
// workspace/connectors/vision.js
export default {
  engine: "Vision",
  source: "webcam",        // camera connector to process frames from
  poll: ["fps", "processing"]
};
```

The `source` can be `"webcam"` (default USB camera) or a camera connector name for IP cameras.

### Tracker Types

| Tracker | How It Works | Best For |
|---------|-------------|----------|
| **color** (HSV) | Filters pixels by hue/saturation/value range, finds centroids | Tracking brightly colored objects (red ball, green LED) |
| **contour** | Edge detection + contour finding, returns bounding boxes and areas | Tracking shapes regardless of color (parts, tools, containers) |

Both trackers run locally via OpenCV with no LLM calls, providing detections at frame rate.

### Vision Workflow

The vision system combines two approaches:

| Layer | How to call it | Speed | Capability |
|-------|----------------|-------|------------|
| **Fast CV** | `call_action(vision, addTracker)` + `read_property(vision, detections)` | ~30 fps | Track objects by color/shape (HSV, contour) |
| **AI Vision** | `take_snapshot` | ~2-5s | See a scene, reason about spatial layout |
| **AI Detection** | `call_action(vision, identifyObjects)` | ~2-5s | Find named objects with pixel coordinates and bounding boxes |
| **Spatial** | `call_action(vision, locateObject)` | ~2-5s | Find object and return world (robot) coordinates if calibrated |
| **Teaching** | `call_action(vision, teachObject)` | ~3-5s | Learn an object for persistent real-time tracking |
| **Servoing** | `call_action(vision, approach)` | ~0.1-5s | Iterative guidance to move robot toward an object |

**Typical workflow for vision-guided tasks:**

1. `take_snapshot` — understand what's in the scene
2. `call_action(vision, identifyObjects, { query: "red spoon" })` — find specific object with coordinates
3. `call_action(vision, teachObject, {...})` — learn the object for persistent real-time tracking (saves profile + creates CV tracker)
4. `read_property(vision, detections)` — poll tracker position at high speed during approach
5. `call_action(vision, approach, { object_name: "red spoon" })` — iterative visual servoing to move toward the object (works without calibration)

Use AI actions (`take_snapshot`, `identifyObjects`) for planning and verification. Use the fast CV path (`read_property(vision, detections)`) or `approach` for fast feedback during motion. Use `teachObject` to bridge the gap — AI identifies objects once, then OpenCV tracks them at 30fps.

### AI Object Detection (`identify_objects`)

Sends a camera snapshot to the LLM with a structured detection prompt. Returns named objects with pixel coordinates and an annotated verification image showing bounding boxes drawn over each detected object.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `camera` | string | No | Camera connector name (auto-detects if omitted) |
| `query` | string | No | Specific object to find (e.g., "red spoon"). Omit to detect all visible objects |

**Response:**

```json
[
  {
    "name": "red spoon",
    "center": { "x": 320, "y": 240 },
    "size": { "width": 80, "height": 30 },
    "confidence": "high"
  },
  {
    "name": "metal bowl",
    "center": { "x": 500, "y": 350 },
    "size": { "width": 120, "height": 100 },
    "confidence": "medium"
  }
]
```

**Key differences from `read_detections`:**

| | `identify_objects` | `read_detections` |
|---|---|---|
| Speed | ~2-5 seconds (LLM call) | Instant (local OpenCV) |
| Setup | None | Requires `configure_vision` first |
| Capabilities | Identifies objects by name | Tracks by color/shape only |
| Cost | Uses LLM tokens | Free (local processing) |

Results are cached for 5 seconds — repeated calls within that window are free.

The tool also returns an annotated camera image with green bounding boxes, red centroid dots, and name/confidence labels drawn over each detected object. This image is injected into the AI conversation for visual verification — the LLM can see what it detected and confirm accuracy before proceeding.

### Locating Objects (`locate_object`)

Combines AI object detection with spatial mapping to return physical coordinates.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `camera` | string | Yes | Camera connector name |
| `object_name` | string | Yes | Object to find (e.g., "spoon", "red ball") |

**Response (with calibration):**

```json
{
  "found": true,
  "name": "red spoon",
  "pixel": { "x": 320, "y": 240 },
  "world": { "x": 150.5, "y": -30.2, "z": 85.0 },
  "confidence": "high",
  "calibrated": true
}
```

**Response (without calibration):**

```json
{
  "found": true,
  "name": "red spoon",
  "pixel": { "x": 320, "y": 240 },
  "confidence": "high",
  "calibrated": false,
  "note": "Camera not calibrated — only pixel coordinates available. Use calibrate_camera to enable world coordinate mapping."
}
```

### Spatial Mapping (Camera Calibration)

The `calibrate_camera` tool teaches the system how pixel coordinates map to real-world (robot) coordinates using a teach-by-example approach. No camera intrinsic parameters or lens models needed.

**How it works:**

1. Move the robot end-effector to a position visible in the camera
2. Record the pixel position (from `identify_objects` or `read_detections`) and the robot's known coordinates
3. Repeat for 4+ positions spread across the workspace
4. The system computes a 2D affine transform (least-squares fit)

**Calibration actions:**

| Action | Parameters | Description |
|--------|-----------|-------------|
| `start` | `camera` | Begin a new calibration session |
| `point` | `camera`, `pixel_x`, `pixel_y`, `world_x`, `world_y`, `world_z` | Record a calibration point |
| `finish` | `camera` | Compute transform and save |
| `status` | `camera` | Check calibration state |

**Example calibration flow:**

```
1. calibrate_camera(camera: "webcam", action: "start")
2. Move robot to position (100, 0, 80), see it at pixel (150, 400)
   calibrate_camera(camera: "webcam", action: "point", pixel_x: 150, pixel_y: 400, world_x: 100, world_y: 0, world_z: 80)
3. Repeat for 3-5 more positions...
4. calibrate_camera(camera: "webcam", action: "finish")
```

**Tips for good calibration:**
- Use **at least 4 points** spread across the workspace (corners + center)
- All points should be at roughly the same Z height (the system assumes a flat work plane)
- The more spread out the points, the better the accuracy
- Recalibrate if the camera or its mount moves

**Storage:** Calibration data persists in `workspace/config/calibrations/{camera}.json`.

### Object Teaching (`teach_object`)

The `teach_object` tool bridges AI vision and fast CV tracking. When the LLM identifies an object via `identify_objects` or `take_snapshot`, it can "teach" the object to the vision system — sampling its color, storing a persistent profile, and creating a real-time OpenCV tracker.

**How it works:**

1. AI vision identifies an object (e.g., "screwdriver" at pixel 320, 240)
2. `teach_object` samples the color at that pixel location via `calibrateColor`
3. A profile is saved to `workspace/config/objects.json` with HSV range, typical size, and description
4. A color tracker is auto-created on the vision connector for 30fps tracking
5. A verification snapshot is captured showing the new tracker's detection overlay — this image is returned to the AI conversation so both the LLM and user can confirm the tracker is working correctly
6. On server restart, taught objects auto-restore their trackers

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Object name (e.g., "screwdriver") |
| `camera` | string | Yes | Camera connector name |
| `pixel_x` | number | Yes | Center X pixel coordinate |
| `pixel_y` | number | Yes | Center Y pixel coordinate |
| `width` | number | No | Bounding box width (improves color sampling) |
| `height` | number | No | Bounding box height |
| `description` | string | No | Visual description for context |
| `tracker_type` | string | No | `"color"` (default) or `"contour"` |

**Example conversation:**

> **User:** "Learn what the red ball looks like"
>
> **AI:** *Takes a snapshot, identifies the red ball at pixel (320, 240) with size 60x60.*
> *Calls `teach_object(name: "red ball", camera: "webcam", pixel_x: 320, pixel_y: 240, width: 60, height: 60)`*
>
> "I've taught the vision system to recognize the red ball. Here's the verification image — I can see the green bounding box tracking it correctly in the center of the frame. It's now being tracked in real-time at 30fps."

**Related tools:**
- `forget_object(name)` — Remove a taught object and its tracker
- `list_objects()` — List all taught objects with their profiles

**Storage:** Object profiles persist in `workspace/config/objects.json`.

### Direct Vision Annotation

For faster, cheaper object teaching **without AI**, you can draw bounding boxes directly on the camera feed in the dashboard. This bypasses the LLM entirely — you see it, box it, name it.

**Setup:**
1. Add a **Canvas** widget to your dashboard with `stream` set to `vision:annotated`
2. In the widget config, set `Vision Connector` to `vision` (or your vision connector name)
3. An annotation toolbar appears on the canvas

**Teaching objects:**
1. Click **Draw** in the toolbar — cursor becomes a crosshair
2. Click and drag to draw a bounding box around the object you want to track
3. Type a name in the popup input and press Enter (or click **Teach**)
4. The system samples the color in that region, creates a tracker, and begins real-time tracking immediately
5. You'll see the green tracking box appear within 1-2 frames

**Managing objects:**
- Click an object's label in the overlay to select it
- Click the **X** button to delete (forget) a tracked object
- Press **Escape** to cancel drawing or deselect

This uses the same `vision.teach`, `vision.forget`, and `vision.list` WebSocket messages — see the [WebSocket API reference](https://docs.muxit.io/reference/websocket-api.md) for details.

### Visual Servoing (`approach_object`)

The `approach_object` tool provides iterative guidance for moving a robot toward an object **without calibration**. It works by computing how far the object is from the center of the camera frame, then suggesting a move direction and step size.

**How it works:**

1. Finds the object using fast CV tracking (if taught) or AI detection (fallback)
2. Computes error: how far the object's center is from the frame center (normalized -1 to 1)
3. Returns a suggested move vector proportional to the error
4. The LLM/agent moves the robot, then calls `approach_object` again
5. Repeat until the object is centered (error < 10%)

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `camera` | string | Yes | Camera connector name |
| `object_name` | string | Yes | Object to approach |
| `step_size` | number | No | Move step size in mm (default: 10) |
| `vision_connector` | string | No | Vision connector name (default: "vision") |

**Response:**

```json
{
  "found": true,
  "centered": false,
  "object_name": "screwdriver",
  "pixel": { "x": 450, "y": 180 },
  "frame": { "width": 640, "height": 480 },
  "normalized": { "x": 0.703, "y": 0.375 },
  "error": { "x": 0.406, "y": -0.25 },
  "suggestion": { "dx": -4.1, "dy": 2.5 },
  "distance": "medium",
  "quadrant": "right-top",
  "message": "Object 'screwdriver' is in right-top quadrant. Suggested move: dx=-4.1, dy=2.5 mm."
}
```

**Usage pattern (agent or script):**

```
loop:
  result = approach_object(camera: "webcam", object_name: "screwdriver", step_size: 5)
  if result.centered: break
  robot.moveRelative(result.suggestion.dx, result.suggestion.dy, 0)
  wait 500ms
```

::: tip Axis Mapping
Camera X/Y may not align with robot X/Y depending on camera mounting. Move the robot in one axis and observe the camera to determine the mapping. Save it to AI memory with `save_memory`.
:::

**See also:** `workspace/processes/visual-servo.process.md` — structured procedure for visual servoing tasks.

---

## Central Instructions

Lab-wide AI instructions live in `workspace/config/instructions.md`. This is the "standing orders" file — both AI chat and agents read it. Edit it to customize how the AI behaves in your lab.

### File Format

```markdown
# Lab Instructions

## General
You are controlling a robotics lab. Be careful with motion commands.
Always confirm before moving the robot to a new position.
Prefer slow, safe movements over fast ones.

## Devices
### robot
Collaborative robot arm (Fairino FR series). Max speed 29 when homing.
Always check motionDone before starting new moves.
Coordinates are in mm and degrees.

### webcam
USB webcam for live video streaming.
Safe to adjust quality and mirror settings at any time.

### psu
Power supply unit. Never exceed 30V / 5A.
Always ramp voltage gradually — never jump directly to target.

## Safety
- Never move robot without checking camera first
- Maximum approach speed near objects: 20%
- Always confirm before executing motion commands
- If force readings spike unexpectedly, stop all motion
```

### How It Works

| Priority | Source | Scope |
|----------|--------|-------|
| 1 (highest) | `workspace/config/instructions.md` — `## Devices / ### {name}` | Per-device |
| 2 | `workspace/config/instructions.md` — `## General` + `## Safety` | All AI interactions |
| 3 | Connector config `ai.instructions` field | Per-device fallback |
| 4 (lowest) | Built-in defaults | Always present |

The central file takes priority. If a device has a `### device-name` section in instructions.md, that replaces the connector's `ai.instructions`. If not, the connector-level instructions are used as fallback.

### Hot Reload

The file is watched for changes — edit it and the new instructions take effect on the next AI interaction (no restart needed).

### Editing

- **Via UI:** The instructions editor is available via WebSocket (`instructions.get` / `instructions.set`)
- **Via AI:** Ask the AI to update instructions: "Add a safety rule: never exceed 20% speed near the basket"
- **Via file:** Edit `workspace/config/instructions.md` directly in any text editor

**Tools:** `read_instructions`, `write_instructions`

---

## Process Definitions

Process files are structured "recipes" for complex autonomous tasks. They live in `workspace/processes/*.process.md` and teach the AI how to decompose goals into steps.

### Why Processes?

When a user says "pick up the spoon and drop it in the basket", the AI needs to know:
- What is a spoon? How to find it? (object detection)
- Where is the basket? (spatial awareness)
- How to approach, grasp, transport, and place? (procedure)
- What to do if the grip fails? (error recovery)

Process files capture this procedural knowledge so it can be reused.

### File Format

Files are named `{name}.process.md` and placed in `workspace/processes/`. The format uses markdown with standard sections:

```markdown
# Pick and Place

## Goal
Pick up an object and place it at a target location.

## Requirements
- Devices: robot, camera (or webcam)
- The robot must have a gripper

## Steps
1. **Survey** — Take a camera snapshot. Identify the target object and destination.
2. **Locate object** — Use AI vision to determine the object's position.
   If uncertain, take snapshots from different angles.
3. **Plan approach** — Calculate an approach path. Move to a safe height first.
4. **Approach** — Move above the object at safe speed (max 20%).
   Take a snapshot to verify position.
5. **Grasp** — Lower to grasp height. Close gripper.
   Take a snapshot to verify grip.
6. **Transport** — Lift to safe height. Move to above the destination.
7. **Place** — Lower to placement height. Open gripper.
   Verify placement with camera.
8. **Retreat** — Return to home position.

## Error Handling
- If object not found: ask user to point it out
- If grip fails (object drops): retry from step 4, max 2 retries
- If position uncertain: take additional snapshots

## Safety
- Never exceed 20% speed when near objects
- Always approach from above
- Verify with camera before and after gripping
```

### Using Processes

**With agents:** Reference a process in the agent config:
```json
{
    "name": "pick-and-place",
    "processFile": "pick-and-place",
    "devices": ["robot", "camera"]
}
```

**From AI chat:** The AI can search for relevant processes:
```
User: "Pick up the spoon and put it in the basket"
AI: [calls list_processes] → finds "pick-and-place"
AI: [calls read_process("pick-and-place")] → reads procedure
AI: [calls start_agent with process] → follows the steps
```

**Creating processes:** Ask the AI to create one:
```
"Create a process for inspecting PCBs under the microscope"
```

The AI will use `write_process` to save it to `workspace/processes/`.

### Sections Reference

| Section | Required | Purpose |
|---------|----------|---------|
| `# Title` | Yes | Process name (H1 heading) |
| `## Goal` | Yes | One-line description of what the process achieves |
| `## Requirements` | No | Devices, tools, or conditions needed |
| `## Steps` | Yes | Numbered procedure steps |
| `## Error Handling` | No | What to do when things go wrong |
| `## Safety` | No | Safety constraints specific to this procedure |

**Tools:** `list_processes`, `read_process`, `write_process`

---

## Running on a local LLM

Muxit AI can run against a local model server instead of the managed cloud
proxy. Useful for air-gapped labs, regulated environments, or for cutting cloud
spend on long-running agents.

Local providers are **free on every tier** — including Free. Point Chat Panel
and `ai()` at Ollama, LM Studio, or any OpenAI-compatible endpoint and the
managed-cloud `ai` tier gate is bypassed entirely. (AI image analysis in chat
/ MCP — `take_snapshot` — the **Vision engine** premium extension, and
Autonomous Agents stay Pro-only regardless of provider; they gate on separate
features. The script `ai(prompt, image)` overload against a local model is the
exception — it's free on every tier.)

### Ollama

1. Install [Ollama](https://ollama.com/) and start the daemon (`ollama serve`).
2. Pull a model with tool-use support:
   `ollama pull llama3.2` (or `qwen2.5`, `mistral-nemo`, …).
3. Open **Settings → AI Services**, pick **Ollama**, leave the base URL at
   `http://localhost:11434/v1`, set the model name to match what you pulled,
   and click **Test connection**.

### LM Studio

1. Install [LM Studio](https://lmstudio.ai/) and load a model from the
   "Discover" tab.
2. Open the **Local Server** tab and start the server on port 1234.
3. In Muxit, **Settings → AI Services → LM Studio**. Base URL defaults to
   `http://localhost:1234/v1`. Use `auto` as the model name to pick whatever
   LM Studio currently has loaded.

### Any OpenAI-compatible endpoint

Pick **OpenAI-compatible** for vLLM, llama-server, OpenRouter direct, or any
service exposing `/chat/completions`. Provide the full base URL (including the
`/v1` segment if required) and an API key.

### What works on local providers

- Streaming chat with tool use — works on Ollama ≥ 0.4 and LM Studio
  (current versions). Older releases without OpenAI-style tool support will
  fall back to plain chat without tool calls.
- The `ai()` script global, the agent inference loop, and AI-powered object
  detection all transparently use the active provider.
- Vision works against multimodal models like `llava`, `qwen2-vl`, or
  `llama3.2-vision`. Use `ai("describe this", await camera.snapshot())` from
  scripts.

### What doesn't

- Per-call usage / credits reporting (cloud-only).
- The OpenRouter web-search plugin used for SCPI authoring (cloud-only).

## Output budget and truncated replies

**Max response tokens** (Settings → AI Services, stored as `ai.maxTokens`) caps
how much the model may write in a single response. The default of 2048 keeps
ordinary chat replies short, but it is a hard stop: when the model reaches it,
the provider cuts the response off wherever it happens to be.

For a prose answer that just means a reply that ends mid-sentence — ask the AI
to continue. For a **tool call** it is fatal. The AI writes a tool's arguments
as a single JSON payload, so a script write or a connector-config generation
that runs past the cap leaves a half-written payload that cannot be run. Muxit
detects this and refuses the turn rather than executing a tool with partial
arguments:

> The model hit its 2048-token output limit while writing a tool call, so the
> call was cut off mid-argument and can't be run. Raise "Max response tokens"
> under Settings → AI (`ai.maxTokens`) and try again.

Raise the field and repeat the request. 8192 is a comfortable setting for flows
where the AI writes scripts, connector configs or dashboards; the cost of a
higher cap is only paid when the model actually writes that much. The field
accepts 256–32768 — those are the UI's guard rails against a typo, not a model
limit, so edit `server.json` directly if you need to go outside them.

## Configuration Reference

### AI Config (`server.json`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `ai.provider` | string | `"muxit"` | LLM backend — `"muxit"`, `"ollama"`, `"lmstudio"`, or `"openai-compatible"` |
| `ai.model` | string | provider default | Active model id (cloud uses OpenRouter ids; local uses model name) |
| `ai.maxTokens` | number | `2048` | Max output tokens per response, editable as **Max response tokens** in this panel. Raise for code-generation flows; the lower default keeps chat replies tight. Autonomous agents fall back to `4096` when this key is unset. See [Output budget](#output-budget-and-truncated-replies). |
| `ai.instructions` | string | `""` | Custom AI system prompt |
| `ai.promptProfile` | string | `"standard"` | `"minimal"` strips device schemas + decision tree from the system prompt — fits 4–8K local-LLM context windows |
| `ai.providers.<id>.baseUrl` | string | per provider | Endpoint URL for local providers |
| `ai.providers.<id>.apiKey` | string | `""` | Optional bearer token (openai-compatible only) |
| `ai.providers.<id>.model` | string | per provider | Per-provider default model |
| `ai.access.<connector>.<item>.enabled` | boolean | `true` | Hide a property/action from AI |
| `ai.access.<connector>.<item>.instructions` | string | `""` | Per-property/action AI note |

You can also embed AI instructions directly in connector config files using the `ai.instructions` field — see the [Connector Guide](https://docs.muxit.io/guides/connectors.md#ai-instructions) for details.

### Voice Config (`server.json`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `voice.tts.enabled` | boolean | `false` | Enable text-to-speech for AI chat replies |
| `voice.tts.scriptEnabled` | boolean | `true` | Speak script `say()` output through the status-strip toggle |
| `voice.wakeWord.enabled` | boolean | `false` | Enable "Muxit" wake word |
| `voice.autoSend` | boolean | `true` | Auto-send voice input |
