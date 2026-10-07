# Operator Mode

Operator mode boots Muxit straight into a dashboard — no file explorer, no code
editor, no settings. It is for the moment a rig stops being something you are
building and becomes something someone *runs*: a bench appliance with a
touchscreen, a station handed to a colleague, a long unattended soak test, a
demo you don't want a stray click to derail.

::: tip What it protects
Operator mode is a **write gate**, not a read gate. When it is on, the server
refuses every message that would *author* something — edit a script or
connector, change config, install a driver, move the safety level, drive the
AI — from **every** anonymous client, not just the operator shell. Reads pass,
and so do the four writes a dashboard is built from.

It does not narrow *device control*: an operator can call anything a dashboard
button could have called. Bounding that is the [safety level](https://docs.muxit.io/guides/safety.md)'s
job, together with a connector's `hide` / `expose` lists. Operator mode stops
the test being **changed**; the safety level bounds what running it may **do**.

Add [accounts](https://docs.muxit.io/guides/accounts.md) and the station can tell people apart:
operators are held to the gate and named in the audit trail, while an engineer
signs in to lift it for their own session.
:::

::: warning Pro tier and above
Operator mode — the locked station, its capability gate and the read-only
chat — needs a **Pro** license or higher, and so do [accounts](https://docs.muxit.io/guides/accounts.md). A station whose license does
not cover it starts as an ordinary Muxit install: the mode simply does not
engage, and the startup banner says so.

The audit trail naming *which* operator did what is a separate **Lab** feature —
Pro gets the access control, Lab gets the paper trail.

**A station that has been licensed keeps operator mode for 60 days** if the
license stops checking out — see *If the license lapses* below. A station that
was never licensed simply never engages the mode.
:::

## Setting it up

The folder *is* the configuration. Put the dashboards and scripts an operator
should have into an `operator/` sub-folder, and that set becomes their whole
world:

```
workspace/
  dashboards/operator/       ← dashboards operators can see
    station.dashboard.json
  scripts/operator/          ← scripts operators can run
    run-test.js
    calibrate.js
```

There is no manifest, allowlist or permissions screen to keep in sync. Add a
file and it appears; delete it and it's gone. Everything outside those two
folders stays invisible in operator mode.

Muxit already keys scripts and dashboards by their path relative to the
workspace folder, so `scripts/operator/run-test.js` is simply the script named
`operator/run-test` — it shows up in your normal Scripts panel and runs the same
way it always did.

## Turning it on

Two ways in, and they are deliberately different in strength.

### Per install — the anonymous-visitor policy

Operator mode is not a switch of its own. It is what happens when the
[accounts](https://docs.muxit.io/guides/accounts.md) policy for **anonymous visitors** is
**Dashboards only**: every browser that has not signed in gets the operator
shell, and the server enforces the gate for it. Set it under **Settings ›
Accounts › Anonymous visitors**, or in `workspace/config/accounts.json`:

```json
{
  "anonymous": "dashboard",
  "accounts": []
}
```

It takes effect immediately, no restart. A file with no accounts listed, as
above, is an anonymous kiosk: everyone is an operator and nobody is asked who
they are. Add an engineer or admin account and that person can sign in on the
station to service it, and change the policy back from Settings; with no such
account, the way out is editing the file and restarting.

**Settings › Accounts › Operator dashboards** lists what the station has and
picks the one to open on start (stored as `ui.operatorDashboard` in
`server.json`). Leave it on *First dashboard found* and a single-dashboard
station needs nothing beyond the policy.

### Per device — `?view=operator`

```
http://192.168.1.40:8765/?view=operator
```

The station's touchscreen runs the operator shell while your laptop keeps the
full interface against the same server. The choice is remembered in that
browser, so a kiosk reopened without the query string still comes up in operator
mode. `?view=full` clears it, as does the **Exit** button in the header.

This is a convenience, not a lock — anyone can edit the URL back, and **the
server does not enforce anything for a `?view=operator` browser**. It carries no
identity the server could trust, so it changes only what that browser renders.
Use it when you want a tidy panel on the shop floor while you keep the full UI
on your laptop; use the policy when it actually has to hold.

When the policy is `dashboard`, it wins, and the Exit button disappears.

## What a locked station accepts

With the anonymous-visitor policy on `dashboard`:

| Passes | Refused |
|--------|---------|
| Live state, streams, connector and driver listings | Editing scripts, connectors, dashboards or config |
| Reading dashboards | The immediate window (`scripts.execute`) |
| `connector.call` — every button, toggle, slider and knob | Renaming connectors, changing visibility, reloading |
| Starting scripts **in the `operator/` folder** | Starting anything outside `operator/` |
| Stopping any running script, including Stop All | Marketplace, driver installs, updates, licensing |
| Answering `ask.*` prompts | Changing the safety level |
| Reading the current safety level | The audit log, agents, vision teaching |
| AI chat, on dashboards that turn it on | AI memory, credits and prompt introspection |

Refusals come back as `OPERATOR_MODE_RESTRICTED` and name the way out.

The **editor API** (`/api/editor/*`) and the **MCP endpoint** (`/mcp`) are
both refused for anonymous callers and operators, and both stay registered, so
a request carrying an engineer's or admin's account token passes. MCP's tools
include `write_script` and `write_connector_config`, so an MCP client on a
locked station needs that token; without one, set the policy back to `full`.

**The safety level is pinned** by consequence, not by a separate setting:
whatever the engineer last selected persists in `safety.state.level`, and
`safety.setLevel` is refused, so an operator cannot escalate to Unrestricted.
Set the level you want before turning operator mode on.

Because `config.set` and the accounts API are both refused, an operator
**cannot turn operator mode off from the UI**. Either sign in as an admin and
change the policy under Settings › Accounts, or edit `"anonymous"` in
`workspace/config/accounts.json` and restart.

## Who is at the station

Out of the box a locked station is an **anonymous operator station**: everyone
who connects is an operator, nobody is asked who they are.

Add [accounts](https://docs.muxit.io/guides/accounts.md) and the station can tell people apart:

- The dashboard stays viewable by anyone. Under the `dashboard` policy anyone
  may press its controls and signing in only adds a name. If every press must
  carry a name, use the `login` policy instead and open the floor screen with
  `?view=operator`: it shows the dashboard, and pressing a control raises the
  PIN pad over it.
- **Sign in**, **Switch** and **Sign out** live in the shell's header. A shift
  change never takes the dashboard down.
- A signed-in **operator** is held to the gate and named in the audit trail.
- A signed-in **engineer or admin** gets the full interface — the server lifts
  the gate for their connection only — which is how a locked station is
  serviced without editing config and restarting.
- A session that idles out mid-shift raises the sign-in panel rather than
  leaving dead controls behind. Whatever was refused is **not** retried for you
  after signing in; press it again deliberately.

Accounts are managed under **Settings › Accounts** by an admin, and the first
admin is created there too. Everything about roles, PINs, the policy and
recovery is in the [Accounts guide](https://docs.muxit.io/guides/accounts.md).

::: tip Who gets the record
Every tier that can run operator mode gets the access control. The **audit
trail** that records *which* operator did what is a separate, higher-tier
feature — the identity always flows, and the audit log simply does not write
on tiers without it. See [Safety](https://docs.muxit.io/guides/safety.md#audit-log).
:::

## AI chat (optional)

Chat is switched on **per dashboard**, not per station: open the dashboard in
the editor and tick **Operator chat** under its Dashboard settings, which
writes `"chat": true` at the top level of the dashboard file. That dashboard
then shows an **Ask** button in the operator shell, while a wall display on the
same station stays clean. Only dashboards under `operator/` count — the flag on
an engineer's dashboard does nothing. The button opens a small panel where the
operator can ask questions about the rig:

> *"Why did unit 4471 fail?"*
> *"What does the chiller's E-042 code mean?"*
> *"Is the supply actually at 5 V right now?"*

The assistant is **read-only**, enforced server-side. It may read device state
and connector schemas, look at scripts and their output, read dashboards, and
search the docs and any instrument manuals you have loaded. It may not write a
property, call an action, start or stop a script, or author anything — those
tools are never offered to the model, and are refused if it calls one anyway.

That narrowing follows **the person, not the station**. Sign in as an engineer
or admin and the chat is the ordinary Muxit assistant with its full toolset —
it can edit connectors and scripts, change settings and drive hardware, on a
locked station just as it would anywhere else, because lifting the gate for
that connection is what the account is for. A signed-in operator gets the
read-only assistant even on a station that never turned operator mode on.

Starting a test is deliberately not on that list. A dashboard button is a
person's decision with a unit in front of them; a model deciding on its own to
start a run is not the same thing. Ask it what happened, not to do something.

Chat is off by default and independent of the rest of operator mode — turning
it on does not widen anything else. It still needs an AI provider configured,
and the Muxit-managed provider is tier-gated as usual.

## If the license lapses

The tier is confirmed by a signed proof that is only good for 24 hours, and the
server refreshes it on the same cadence. So the usual reason a station stops
being Pro is **not** an unpaid invoice — it is a network problem: a firewall
change, a proxy that started intercepting TLS, a VLAN that went down overnight.

Losing operator mode in that moment would be the worst possible failure: the
station would go back to showing the full interface mid-shift — the editor,
settings and every connector, to whoever is standing at it — and nobody would be
told. So it doesn't happen that way.

**A machine that has held a Pro license keeps operator mode for 60 days** after
the last time its license checked out, and says so every day it does:

- a warning on the startup banner,
- a banner across the top of the operator shell, counting down the days,
- a notice on the sign-in screen, where an engineer will see it,
- the same warning in Settings › Server › Operator Mode and Settings › Accounts.

Each of those names **which of the two problems** it is, because they have
completely different fixes:

| What happened | What you see | What to do |
|---|---|---|
| Muxit can't reach the license service | *"Muxit cannot reach the license service to confirm this machine's subscription"* | Check the machine's internet connection. If the subscription is active, nothing else is needed |
| The subscription ended | *"This machine's Muxit subscription has ended"* | Renew the subscription |

A subscription that is **cancelled or revoked** — where the license service
answers and says no, rather than not answering — gets no grace: operator mode
becomes unavailable at that point.

[Accounts](https://docs.muxit.io/guides/accounts.md) and the **Lab audit trail** work the same way,
for the same reason: a station whose sign-in policy silently stopped applying,
or traceability that stops without anyone noticing, is worse for a compliance
customer than either costing money.

**The Pro safety levels are not part of that grace.** While the license is not
confirmed, a station set to Assisted or Active runs at **Observe**: the dashboard
still works, but every write and action is simulated and nothing reaches the
hardware. The station says so — a **Hardware control is off** banner under the
status strip, an amber **Observe · license** chip, and a line on the startup
banner — naming the same two causes as the table above; on the operator shell
it tells the operator to fetch an administrator. The chosen level is kept and
comes back by itself the moment the license checks out again, so a station that
was switched off over a long weekend is back at its level seconds after it
reaches the license service. See [Safety](https://docs.muxit.io/guides/safety.md#when-the-license-no-longer-covers-your-level).

After 60 days operator mode becomes unavailable and the station behaves as an
ordinary Muxit install. A machine that *never* held the license gets no grace at
all — the mode simply never engages.

::: tip Air-gapped stations
This is a grace period, not an offline licensing mode. A station that can never
reach the license service keeps operator mode for 60 days from its last
successful check, and loses it after that. If you need a permanently disconnected
cell, talk to us about offline activation rather than relying on this.
:::

## What the operator sees

- The dashboard, full-bleed and read-only — widgets can't be dragged or resized
  out of shape mid-run.
- A dashboard selector, if there is more than one.
- Live connection state.
- The status strip, with running scripts and **Stop All**.
- Any `ask.*` prompt a script is waiting on, as a modal.

That last one matters. A script blocked on `ask.confirm()` with nothing on
screen to answer it just looks frozen, so the operator shell surfaces prompts
directly instead of inside the chat panel.

`ask.text` is worth knowing about here: a USB barcode scanner is just a
keyboard, and the prompt's input is focused automatically, so

```js
const serial = ask.text('Scan serial number');
```

works by scanning, with no extra setup.

## Recording results

Operator mode has no built-in test-record store. Scripts write their own
results through a [FileAccess connector](https://docs.muxit.io/reference/drivers/file-access.md):

```js
const results = connector('files').openText('results.csv');
const serial = ask.text('Scan serial number');
const v = connector('dut').voltage;
const pass = v > 4.9 && v < 5.1;
results.append([timestamp(), serial, v, pass ? 'PASS' : 'FAIL']);
```

Open that CSV in a tab and the chart refreshes as rows land.

## No operator dashboard?

If operator mode is on but `dashboards/operator/` is empty, Muxit refuses to
enter and shows setup instructions instead. That is on purpose: a blank panel in
front of someone with no way to fix it is worse than an explanation of what to
create.

## See also

- [Accounts](https://docs.muxit.io/guides/accounts.md) — admin, engineer and operator sign-in
- [Dashboards](https://docs.muxit.io/guides/dashboards.md) — building the dashboard operators will use
- [Scripts](https://docs.muxit.io/guides/scripts.md) — `ask.*` prompts and script structure
- [Remote Access](https://docs.muxit.io/guides/remote-access.md) — reaching a station from another machine
- [Configuration](https://docs.muxit.io/reference/configuration.md) — the full `ui` section
