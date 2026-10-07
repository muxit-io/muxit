---
title: WebhookNotifier Driver
description: Reference for the WebhookNotifier built-in driver — POSTs notifications to ntfy.sh, Discord, Slack, or any HTTP endpoint.
---

# WebhookNotifier

Built-in **outbound webhook** driver. Each connector sends to one fixed URL; a `flavor` config key reshapes the payload for popular targets so scripts can call a uniform `notify(title, body, level)` regardless of where the message ends up.

For the broader picture see the [Notifications guide](https://docs.muxit.io/guides/notifications.md).

## Properties

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `url` | string | R | Target URL (fixed at config time) |
| `flavor` | string | R | Payload flavor: `generic` \| `ntfy` \| `discord` \| `slack` |
| `sendCount` | int | R | Total successful sends |
| `failCount` | int | R | Total failed sends |
| `lastError` | string | R | Error message of the most recent failed send |
| `lastSentAt` | string | R | ISO-8601 timestamp of the most recent successful send |

## Actions

| Action | Args | Description |
|--------|------|-------------|
| `notify` | `{ title, body, level?, image?, click?, tags? }` | Send a structured notification, reshaped per flavor |
| `post` / `send` | `payload` (string or object) | POST a raw payload — string → text/plain, object → JSON |

`level` is one of `info` (default), `warn`, `error`, `success`.

`image` is optional. Accepts a base64 string (with or without a `data:` prefix), or the path of an image file inside the workspace (relative to it, e.g. `data/snapshots/frame.jpg`); a file outside the workspace is refused with `PATH_OUTSIDE_WORKSPACE`. The camera drivers' `snapshot()` output (base64 JPEG) works directly.

`click` is an optional URL — ntfy and Discord make the notification clickable.

`tags` is ntfy-specific: a comma-separated list of emoji shortcodes (e.g. `"warning,robot"`).

::: warning Always use `notify()` — never `post()` — for ntfy
`post()` bypasses flavor reshaping and arrives in the ntfy app as raw JSON. If the body looks like JSON in your phone, you're calling `post()` (or your `flavor` is set to `generic` against an ntfy URL).
:::

## Streams

| Stream | Description |
|--------|-------------|
| `delivery` | Per-send outcome: `{ outcome, summary, status, body, timestamp }` |

## Config Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `url` | string | — | Target URL (required) |
| `method` | string | `"POST"` | HTTP method |
| `flavor` | string | `"generic"` | `generic` \| `ntfy` \| `discord` \| `slack` |
| `markdown` | bool | `false` | ntfy only — adds `Markdown: yes` header so the body renders as markdown |
| `headers` | object | — | Extra request headers (pinned across every send) |
| `timeoutMs` | int | 10000 | Request timeout in milliseconds |

## Flavors

### `generic`

JSON body, drop-in for n8n, Zapier, Make, or your own backend:

```json
{ "title": "...", "body": "...", "level": "info", "timestamp": "2026-04-30T..." }
```

### `ntfy`

[ntfy.sh](https://ntfy.sh) is a free pub/sub notification service. Pick any unique topic, subscribe with the ntfy app, and POSTs land as push notifications on every subscribed device.

```javascript
// workspace/connectors/webhook-ntfy.js
export default {
  driver: "WebhookNotifier",
  config: {
    flavor: "ntfy",
    url: "https://ntfy.sh/muxit-lab-alerts-CHANGEME",
  },
};
```

The driver sends the body as `text/plain` and maps `level` → ntfy `Priority` header:

| level | Priority |
|-------|----------|
| `info` | `default` |
| `success` | `low` |
| `warn` | `high` |
| `error` | `urgent` |

Pin extra headers via config (e.g. `headers: { "Tags": "test_tube,robot" }`).

#### Markdown

Set `markdown: true` in config to send the body as markdown. ntfy renders headings, links, lists, and code blocks. The flag is ignored when an image is attached (ntfy doesn't render markdown alongside attachments).

```javascript
config: { flavor: "ntfy", url: "...", markdown: true },
```

```javascript
wh.notify(
  "Build report",
  "## Status\n\n- ✅ Tests\n- ⚠️ Lint\n- ❌ Deploy\n\n[Details](http://muxit.local)",
  "warn"
);
```

#### Snapshots

Pass `image` to attach a snapshot to the push notification — ntfy renders it inline. The driver switches to PUT-binary mode under the hood (image bytes as the body, message text moves to the `Message` header).

```javascript
const wh = connector("webhook-ntfy");
const cam = connector("webcam");

// snapshot() returns base64 JPEG — feed directly
wh.notify("Robot status", "Voor inspectie", "info", {
  image: cam.snapshot(),
});

// Or a file on disk
wh.notify("Bench", "End-of-day", "success", {
  image: "C:/muxit/workspace/runs/2026-04-30.jpg",
});
```

#### Tags & click URL

```javascript
wh.notify("Camera drift", "Drift > 0.5 mm", "warn", {
  tags:  "warning,camera",       // emoji shortcodes — see ntfy.sh/docs/emojis/
  click: "http://muxit.local:8765",
});
```

### `discord`

In Discord: **Server Settings → Integrations → Webhooks → New Webhook**. Copy the URL into config.

```javascript
// workspace/connectors/webhook-discord.js
export default {
  driver: "WebhookNotifier",
  config: {
    flavor: "discord",
    url: "https://discord.com/api/webhooks/REPLACE/WITH-YOUR-WEBHOOK-URL",
  },
};
```

`notify()` builds a Discord embed with a color matching the level (info=blue, warn=orange, error=red, success=green). For richer messages (multiple fields, mentions) call `.post(...)` with a full Discord webhook body.

Pass `image` to attach a snapshot — Discord renders it inline in the embed. The driver builds a `multipart/form-data` request with `payload_json` + `files[0]` and references the file via `attachment://<filename>`:

```javascript
connector("webhook-discord").notify(
  "Robot status",
  "Voor inspectie",
  "info",
  { image: connector("webcam").snapshot() }
);
```

### `slack`

Slack Incoming Webhook URL goes in `config.url`. `notify()` builds a `text` + colored attachment. For block-kit messages, use `.post(...)` with a full Slack body.

## Example

### Minimal

```javascript
export default {
  driver: "WebhookNotifier",
  config: {
    flavor: "generic",
    url: "https://example.com/muxit-webhook",
  },
};
```

### Script usage

```javascript
const wh = connector("webhook");

// Structured notification — flavor-aware
wh.notify("Run klaar", "Calibratie voltooid in 12m04s", "success");

// Low-level — full control over the payload
wh.post({
  username: "Muxit",
  embeds: [{
    title: "Run klaar",
    description: "Calibratie voltooid",
    color: 0x2ECC71,
    fields: [
      { name: "Duur", value: "12m04s", inline: true },
      { name: "Resultaat", value: "OK", inline: true },
    ],
  }],
});
```
