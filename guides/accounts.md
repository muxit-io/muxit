---
title: Accounts
description: Admin, engineer and operator sign-in with PINs — who did what, and who may do what.
---

# Accounts

Accounts put a name on what happens in Muxit, and let a station be handed to
people who should only press its controls. Three roles, one file, a PIN each.

::: tip Nothing changes until you add one
Without any accounts Muxit behaves exactly as it always has: nobody is asked who
they are, there is no sign-in chip, and a single-user home lab never sees any of
this. Everything below is opt-in from the first account.
:::

::: warning Pro tier and above
Accounts need a **Pro** license or higher, like [operator mode](https://docs.muxit.io/guides/operator-mode.md).
A machine that has held the license keeps its accounts for **60 days** after
the license stops checking out, and says so every day it does — see
[If the license lapses](https://docs.muxit.io/guides/operator-mode.md#if-the-license-lapses) for what
you see and what to do. After that the file is ignored: no sign-in, no
attribution, and the startup banner says so loudly.
:::

## Roles

| Role | Sees | May | PIN |
|---|---|---|---|
| **Operator** | The operator dashboards only, on any install | Press dashboard controls, start scripts in `operator/`, stop anything, answer prompts | 4+ digits |
| **Engineer** | The full interface | Everything an engineer does: edit, configure, set the safety level | 6+ digits |
| **Admin** | The full interface | Everything an engineer does, plus **Settings › Accounts** | 6+ digits |

Only an admin creates, changes or removes accounts and sets the sign-in policy.
The last admin cannot be removed or demoted.

A signed-in **operator is an operator everywhere** — not only on a station
running operator mode. On an ordinary install they get the operator shell (or a
notice, if there is no operator dashboard) and every refusal tells them to sign
in as an engineer. On a station running operator mode, an **engineer or admin
signing in lifts the gate for their own connection** and gets the full
interface — that is how a locked station is serviced without editing config
and restarting.

## Setting up

1. Open Muxit **on the machine itself**, or from a browser that has signed in
   with the [remote-access](https://docs.muxit.io/guides/remote-access.md) password.
2. **Settings › Accounts › Create admin account.** Choose an id (`j.smith`), a
   display name and a PIN of at least 6 digits.
3. Sign in as that admin when offered. You are then asked once what someone
   who is *not* signed in should get. The default is **everything** — anyone at
   the machine keeps full access whether or not they sign in, which suits a
   shared bench and is not what you want if the accounts are there to keep
   people out. The other answers are **dashboards only** (operator mode) and a
   **sign-in screen**. Any answer can be changed at any time under
   **Anonymous visitors**.
4. **Add account** for each engineer and operator. Changes take effect
   immediately — no restart.

The first account has to be an admin. Creating it needs no tooling beyond the
app: while no admin exists, the server accepts the request from the machine
itself or from a caller holding the remote-access session — and from nobody
else, so a stranger on the network cannot own the station before you do.

::: details Keep the admin PIN somewhere the lab can find it
If the last admin's PIN is lost, the only way back is to delete
`workspace/config/accounts.json` on the server and restart. That removes every
account and the sign-in policy; Settings › Accounts then offers to create a new
admin. Anything done before the new accounts exist is recorded without a name.
:::

## Signing in

**In the full interface** the chip at the right of the status bar shows who is
signed in. Click it to sign in, switch user or sign out. Switching does not
reload the page: your open editor tabs stay where they are.

**On the operator shell** the header has **Sign in**, and once somebody is
signed in, **Switch** and **Sign out**. The PIN pad opens over the live
dashboard, so a shift change never takes the dashboard down.

**On a phone** the same three live under the **More** tab, in an *Account*
card that appears once the server has accounts.

A session ends after the idle timeout (default 15 minutes, set under
Settings › Accounts) so one shift's work is never recorded against the previous
shift's operator. When that happens mid-work the sign-in panel comes up over
whatever you were doing; sign in and carry on. Whatever was refused is **not**
retried for you — press it again deliberately.

Sessions live in the server's memory and end when it restarts.

What **Sign out** does depends on the anonymous-visitor policy below. Under
`full` it only stops attaching your name to what happens next — your access is
unchanged, because it was never gated; the chip says so next to the button.
Under `dashboard`, signing out drops that browser to the operator shell. Under
`login`, it drops the connection to read-only, and the next change asks for a
PIN.

## Anonymous visitors — the policy

What a connection that has **not** signed in gets. Set under **Settings ›
Accounts › Anonymous visitors**; stored in `accounts.json`, not `server.json`,
so only an admin can change it, and it takes effect immediately.

| | `full` (default) | `dashboard` | `login` |
|---|---|---|---|
| Anyone who does not sign in | Works exactly as before accounts existed | Gets the operator shell — this **is** [operator mode](https://docs.muxit.io/guides/operator-mode.md) | May **look** but not act |
| The full interface | Opens for anyone; the chip offers sign-in | Only for a signed-in engineer or admin | Asks for an engineer or admin first |
| Dashboards | Viewable by anyone | Viewable by anyone; controls work without a name | Viewable by anyone; controls prompt for sign-in |
| Authoring | Anyone | Refused (`OPERATOR_MODE_RESTRICTED`) | Refused until signed in (`OPERATOR_SIGN_IN_REQUIRED`) |
| The `/mcp` endpoint | Anyone | Refused | Refused until the MCP client sends an engineer's or admin's account token as `X-Muxit-Account` |
| Suits | A shared dev lab where a name is nice to have | A production station or kiosk | A fixed lab where every change must carry a name |

`login` cannot be chosen until an admin or engineer exists — otherwise the
interface could never be opened again. `dashboard` needs a license that covers
operator mode (Pro) and at least one dashboard under `dashboards/operator/`;
the setup is in the [operator mode guide](https://docs.muxit.io/guides/operator-mode.md). The
**Operator dashboards** group on the same page lists what the station has,
picks the one it opens on, and shows which of them have the Ask panel on.

::: tip What "login" does and does not protect
It guarantees that every **act** — a control press, a script start, a config
change — carries a name. It does **not** hide live readings from an anonymous
connection on the network: a wall display is meant to be read across the room,
and the alternative is a screen nobody can look at without somebody's
credentials parked on it all shift. Use [remote access](https://docs.muxit.io/guides/remote-access.md)
with a password if the readings themselves are confidential. The same is true
of `dashboard`: it hides the *editor*, not the readings.
:::

## Attribution

A signed-in person is named on every safety confirmation and, on the **Lab**
tier, in every row of the [audit log](https://docs.muxit.io/guides/safety.md#audit-log) as
`operator:j.smith`, `engineer:m.chen` or `admin:root`. Pro gets the access
control; Lab gets the paper trail. The identity always flows — the audit log
simply does not write on tiers without it.

Attribution is only as good as the discipline around it. One operator PIN
shared by a whole shift produces a perfectly consistent audit log that says one
person did everything. Give each person their own account, and sign out — or
let the idle timeout do it — when you leave a shared screen.

## Remote access and proxies

Remote access and accounts are two different credentials, sent together:

- `X-Auth-Token` (HTTP) / `auth-…` (WebSocket subprotocol) — the remote-access
  session or startup token. Whether this browser may talk to the server at all.
- `X-Muxit-Account` (HTTP) / `account-…` (WebSocket subprotocol) — the account
  session. Who is talking.

A PIN is never accepted in place of the remote-access password. If you put a
reverse proxy in front of Muxit, pass both headers and the WebSocket
subprotocols through unchanged, or everyone will appear anonymous.

## The file

`workspace/config/accounts.json`, written by the server. PINs are stored as
PBKDF2-SHA256 hashes and can be replaced but never read back.

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

Any role that is not exactly `admin` or `engineer` is an operator, and any
policy that is not exactly `dashboard` or `login` is `full` — a typo can never
hand out the unlock or lock the interface. A corrupt file loads as "no
accounts".

Sign-in attempts are limited two ways. Each source address gets five attempts a minute. And
after five wrong PINs an account locks for 30 seconds — from every address at once — doubling
with each further failure up to 15 minutes; attempts made while it is locked are refused
without extending it. An id that does not exist locks the same way, so probing for ids costs
the same as probing PINs. The sign-in response carries `retryAfter` (seconds) for either
limit, and a successful sign-in clears only that account's own count.

## See also

- [Operator Mode](https://docs.muxit.io/guides/operator-mode.md) — the locked station accounts were built for
- [Safety](https://docs.muxit.io/guides/safety.md#audit-log) — the audit log that names people
- [Remote Access](https://docs.muxit.io/guides/remote-access.md) — the transport credential
- [Subscription plans](https://docs.muxit.io/reference/subscription-plans.md#user-accounts)
