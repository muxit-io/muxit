---
title: EmailNotifier Driver
description: Reference for the EmailNotifier built-in driver — outbound SMTP e-mail with plain text, HTML, and attachments.
---

# EmailNotifier

Built-in **outbound e-mail** driver, backed by [MailKit](https://github.com/jstedfast/MailKit) for full SMTP support: STARTTLS, implicit-SSL, plain transports, and SASL authentication. Pair with the AI runtime to mail AI-generated run reports, or hook script lifecycle events to send "long run finished" alerts.

For the broader picture see the [Notifications guide](https://docs.muxit.io/guides/notifications.md).

## Properties

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `host` | string | R | SMTP host |
| `port` | int | R | SMTP port |
| `from` | string | R | Default From address |
| `security` | string | R | Transport security (`starttls` \| `ssl` \| `none` \| `auto`) |
| `sendCount` | int | R | Total successful sends |
| `failCount` | int | R | Total failed sends |
| `lastError` | string | R | Error message of the most recent failed send |
| `lastSentAt` | string | R | ISO-8601 timestamp of the most recent successful send |

## Actions

| Action | Args | Description |
|--------|------|-------------|
| `send` | `{ to, subject, body, html?, cc?, bcc?, from?, attachments? }` | Send one e-mail |

`to`, `cc`, and `bcc` accept either a single address or a comma-separated list.

When both `body` (plain) and `html` are provided, the message is sent as `multipart/alternative` so clients that don't render HTML still see the plain version.

`attachments` is an array of files inside the workspace: a relative path (`data/runs/2026-04-30.csv`) resolves against the workspace, and a path outside it is refused with `PATH_OUTSIDE_WORKSPACE`. Each is embedded inline into the MIME message — keep individual attachments under a few MB.

## Streams

| Stream | Description |
|--------|-------------|
| `delivery` | Per-send outcome: `{ outcome, to, subject, error, timestamp }` |

## Config Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `host` | string | — | SMTP host (required) |
| `port` | int | 587 | SMTP port (587 STARTTLS, 465 SSL, 25 plain) |
| `security` | string | `"starttls"` | `starttls` \| `ssl` \| `none` \| `auto` |
| `username` | string | — | Auth username (omit for unauthenticated relay) |
| `password` | string | — | Auth password |
| `from` | string | — | Default From address (overrideable per-send) |
| `timeoutMs` | int | 15000 | Connect/send timeout |

## Common SMTP Settings

| Provider | host | port | security |
|----------|------|------|----------|
| Gmail (App Password) | `smtp.gmail.com` | 587 | `starttls` |
| Microsoft 365 / Outlook | `smtp.office365.com` | 587 | `starttls` |
| Local relay (no auth) | `127.0.0.1` | 25 | `none` |

For Gmail, generate an [App Password](https://support.google.com/accounts/answer/185833) (Google Account → Security → 2-Step Verification → App passwords) and use that as the password.

## Safety

The driver opts **into** the safety gate (`RequiresSafetyGates = true`). The first `send()` to a new recipient triggers a confirmation prompt in the UI; subsequent sends to the same address pass through.

Credentials live in the workspace — keep `email.js` connector files out of any shared repo.

## Example

### Minimal

```javascript
// workspace/connectors/email.js
export default {
  driver: "EmailNotifier",
  config: {
    host:     "smtp.gmail.com",
    port:     587,
    security: "starttls",
    username: "alerts@example.com",
    password: "abcd-efgh-ijkl-mnop",
    from:     "Muxit Lab <alerts@example.com>",
  },
};
```

### AI-generated run report

```javascript
const summary = ai(
  `Summarise this measurement run for a lab colleague.
   Highlight anomalies and suggest a follow-up step.
   Samples: ${samples.join(", ")}`
);

connector("email").send({
  to: "lab@example.com",
  subject: `Run report — ${samples.length} samples`,
  body: summary,
});
```

### With attachment

```javascript
connector("email").send({
  to: "lab@example.com",
  subject: "Daily CSV export",
  body: "See attached for today's measurements.",
  attachments: ["data/runs/2026-04-30.csv"],
});
```

### HTML alternative

```javascript
connector("email").send({
  to: "lab@example.com",
  subject: "Threshold breach",
  body: "Sensor temp 81.2 °C — above 80 °C threshold.",
  html: "<p>Sensor temp <b>81.2 °C</b> — above 80 °C threshold.</p>",
});
```
