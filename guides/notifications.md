---
title: Notifications & Alerts
description: Send messages to users when scripts finish, when sensors breach thresholds, or when something needs attention — via e-mail, ntfy, Discord, Slack, or a generic webhook.
---

# Notifications & Alerts

Muxit runs unattended for long stretches: scripts can take hours, sensors can drift, and hardware can fault while you're away from the browser. The **EmailNotifier** and **WebhookNotifier** built-in drivers let you reach the user out-of-band.

Both ship as drivers (no new script globals), so they live in `workspace/connectors/` next to your instruments and obey the same safety-gate rules.

## Pick a channel

| Channel | Use when… |
|---------|-----------|
| **E-mail** ([EmailNotifier](https://docs.muxit.io/reference/drivers/email-notifier.md)) | You want a record. AI-generated run reports, daily digests, attachments. |
| **ntfy.sh** (`flavor: "ntfy"`) | You want a phone push. Free, zero-config, works on iOS and Android. |
| **Discord** (`flavor: "discord"`) | Your team already lives in a Discord channel. |
| **Slack** (`flavor: "slack"`) | Your team already lives in Slack. |
| **Generic webhook** (`flavor: "generic"`) | Forwarding into n8n, Zapier, Make, or your own backend. |

## Use case 1 — Long-running script finishes

The most common pattern: a script kicks off a calibration, you walk away, and you want to know when it's done — with the results.

```javascript
// … your long-running operation …
const samples = collectSamples();

// Quick push notification — just enough to know it finished.
connector("webhook").notify(
  "Run klaar",
  `Captured ${samples.length} samples`,
  "success"
);

// AI-generated summary, e-mailed for the record.
const summary = ai(
  `Summarise this measurement run. Samples: ${samples.join(", ")}`
);
connector("email").send({
  to: "lab@example.com",
  subject: `Run report — ${samples.length} samples`,
  body: summary,
});
```

The full version lives at `workspace/scripts/demo/15-notifications.js`.

## Use case 2 — Threshold breach

Watch a property and alert only on the **transition** above the threshold (not on every sample). Use a hysteresis margin so a value flapping right at the boundary doesn't spam:

```javascript
const dev = connector("test-device");
const wh = connector("webhook");
const THRESHOLD = 50;
let armed = true;

while (true) {
  const temp = dev.temperature;

  if (temp > THRESHOLD && armed) {
    wh.notify(
      "Temperature alert",
      `test-device at ${temp.toFixed(1)} (threshold ${THRESHOLD})`,
      "error"
    );
    armed = false;
  } else if (temp <= THRESHOLD - 5 && !armed) {
    armed = true; // re-arm after 5-unit hysteresis
  }
  delay(1000);
}
```

The full version lives at `workspace/scripts/demo/16-threshold-alert.js`.

## Use case 3 — Hardware fault

For genuinely critical events (collision, e-stop, gripper fault), reach the user immediately. ntfy is a good fit — it pushes to mobile without per-team setup:

```javascript
on("emergency-stop", () => {
  connector("webhook-ntfy").notify(
    "EMERGENCY STOP",
    "Robot e-stop triggered — check the bench",
    "error" // → ntfy Priority: urgent
  );
});
```

## Use case 4 — Camera snapshot with the alert

Both ntfy and Discord can render an image inline next to the message. The webcam and ONVIF drivers' `snapshot()` actions return base64 JPEG, which the WebhookNotifier accepts directly:

```javascript
const cam = connector("webcam");
const wh  = connector("webhook-ntfy");   // or webhook-discord

wh.notify(
  "Threshold breach",
  "Bench temp 81 °C — sending current view",
  "warn",
  { image: cam.snapshot() }
);
```

Slack incoming webhooks don't accept file uploads — the driver drops the image and emits a `delivery` warn event. To include a snapshot in Slack, host the image on a public URL (e.g. via `FileAccess` and a side webserver) and put the link in the body.

## Severity levels

Both drivers accept the same four levels in `notify(title, body, level)`:

| level | Generic JSON | ntfy Priority | Discord color | Slack color |
|-------|--------------|---------------|---------------|-------------|
| `info` (default) | `info` | `default` | blue | `#3498DB` |
| `success` | `success` | `low` | green | `good` |
| `warn` | `warn` | `high` | orange | `warning` |
| `error` | `error` | `urgent` | red | `danger` |

Reserve `warn`/`error` for genuine alerts; routine status updates should be `info` or `success`.

## E-mail without typing your password

The `password` field in `email.js` is **not** your real e-mail password. There's a separate, scoped, revocable credential for every common path:

| Path | What you put in `password` | Notes |
|------|---------------------------|-------|
| Gmail / Google Workspace | 16-char **App Password** from Google Account → Security → 2-Step Verification → App passwords | Requires 2FA enabled. Revoke any time. |
| Microsoft 365 / Outlook | App password from your tenant's security settings | OAuth2 fallback not yet supported |
| Resend | `re_XXX...` API key (host: `smtp.resend.com`, username: `resend`) | Free tier, dev-friendly, [resend.com](https://resend.com) |
| SendGrid | `SG.XXX...` API key (host: `smtp.sendgrid.net`, username: `apikey`) | Free tier covers small labs |
| Mailgun / Postmark / Brevo / SES | API key as password (per provider docs) | Better deliverability than personal Gmail |
| Local relay (Postfix, smtp4dev) | `host: "127.0.0.1"`, `port: 25`, `security: "none"` — no credentials | Lab-internal only |

The default `email.js` template ships with all four blocks commented out so you can pick the one that fits and uncomment it.

::: tip Why a transactional API service?
If you're sending more than a handful of mails per day, providers like Resend or SendGrid have much better deliverability than personal Gmail (which flags lab automation as suspicious quickly). The setup is the same — a single key in `password` — and the free tiers comfortably cover most labs.
:::

## ntfy — common pitfalls

If your ntfy app shows raw JSON instead of a clean message:

1. **Are you calling `notify(...)`, not `post(...)`?** `post()` bypasses flavor reshaping and sends JSON. Use `notify(title, body, level)` and the driver applies plaintext + headers.
2. **Is `flavor` set to `"ntfy"`?** With `flavor: "generic"` the driver sends JSON regardless of where the URL points.
3. **For markdown**, set `markdown: true` in config — body then renders as markdown in the ntfy app.

## Safety gates

- **EmailNotifier** is gated. The first `send()` to a new recipient triggers a confirmation prompt in the UI; subsequent sends to the same address pass through.
- **WebhookNotifier** is **not** gated. The URL is fixed in the connector config, so there's no runtime target choice to gate. Treat the connector config itself as the trust boundary — review URLs before enabling.

## Connector starters

The workspace template ships ready-to-use stubs:

- `workspace/connectors/email.js`
- `workspace/connectors/webhook.js` (generic)
- `workspace/connectors/webhook-ntfy.js`
- `workspace/connectors/webhook-discord.js`

Drop in your URL/credentials and the connector is live on next workspace reload.
