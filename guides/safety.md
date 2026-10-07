# Safety

Muxit controls real hardware. Scripts, AI chats, and dashboard widgets all write voltages, move stages, and open valves. One typo on a number can ruin an expensive part.

The safety system adds graduated guard rails without forcing a confirmation prompt on every click. You pick **one** safety level; the level controls what happens for each kind of operation.

## Licensing

Each safety level is a separate license feature — the set you see in the
picker is whatever the current tier unlocks, nothing is hardcoded to
"Free vs Pro". Server distributions ship with these defaults in
`MuxitServer/Config/AppSettings.cs`:

| Feature id | Default tier |
| --- | --- |
| `safety.level.observe` | `free` |
| `safety.level.unrestricted` | `free` |
| `safety.level.assisted` | `pro` |
| `safety.level.active` | `pro` |
| `safety.level.custom` | `lab` |
| `safety.audit` (writes to `audit.jsonl`) | `lab` |

Adding a new tier is a matter of editing
`AppSettings.Features` and `AppSettings.Tiers` — no changes to the safety
subsystem. If Lab wants Observe + Active + Custom but not Unrestricted,
drop its `RequiredTierId` on those three and tighten Unrestricted; the
`SafetyGate` will pick it up via `CheckFeature` on the next request.

The chip is always visible. Levels the current tier can't select appear
in the dialog with a locked radio and a `PRO` badge (or whatever the
gating tier is called). The StatusStrip chip shows the live level on
every tier.

### When the license no longer covers your level

If the level you picked needs a tier this machine no longer has — the
subscription ended, Muxit could not confirm the license, or the workspace
moved to a machine on a lower tier — Muxit drops to **Observe**, the
lowest-risk level: every write and action is *simulated* and nothing
reaches the hardware. It says so wherever someone is looking:

- a banner under the status strip — **Hardware control is off** — in the
  IDE, the operator view and the mobile view, with the reason and the next
  step (renew under **Settings → License**, check the internet connection,
  or, on the operator view, ask an administrator);
- the safety chip turns amber and reads **Observe · license**;
- a warning in the startup banner and the server log.

Your chosen level stays saved in `server.json`, and it comes back by itself
as soon as the license covers it again — for example when Muxit reaches the
license service after a machine was switched off for a few days. If you pick
a level yourself in the meantime, that choice replaces the saved one.
Clients see the same information as `licenseClamp` in `safety.get` and
`safety.changed` (see the [WebSocket API](https://docs.muxit.io/reference/websocket-api.md#safety-get)).

The audit trail is gated at three stops: the `safety.audit` license
feature, the `safety.audit.enabled` config flag, and the active level's
`Audit` column (Observe/Assisted/Active all default to `On`,
Unrestricted produces no non-Allow outcomes so the file stays empty).

If the license stops checking out, the audit log keeps writing for **60 days**
on a machine that has held the Lab tier, with a warning in the server log each
start that says whether Muxit could not reach the license service (check the
connection) or the subscription ended (renew it). Traceability that stops without anyone noticing is worse than
traceability that costs money — you would keep producing runs believing you
were covered. A machine that never held the tier gets no grace.

The AI confirmation column is **not** gated by any of this — it rides on the
existing `ai` license entitlement.

## The level table

Four built-in levels plus a user-editable **Custom** row. Each column tells the gate what to do with that kind of operation. The six outcomes are **Allow**, **Simulate** (log-only, hardware never sees the write), **Ask once** (cache the approval until the level changes), **Ask every time**, **Typed confirm** (type a release phrase), and **Block** (fail with `SAFETY_BLOCKED`).

| Level | Write (in range) | Write (out of range) | Large change (>25%) | Action | Destructive action | AI confirmation | Audit |
| --- | --- | --- | --- | --- | --- | --- | :-: |
| **Observe** | Simulate | Block | Simulate | Simulate | Block | Ask every time | On |
| **Assisted** | Allow | Block | Ask once | Allow | Ask every time | Ask every time | On |
| **Active** | Allow | Block | Allow | Allow | Ask once | Ask every time | On |
| **Unrestricted** ⚠ | Allow | Allow | Allow | Allow | Allow | Ask every time | On |
| **Custom** | *(user)* | *(user)* | *(user)* | *(user)* | *(user)* | *(user)* | *(user)* |

**Column definitions:**

- **Write (in range)** — a property write whose value is inside the connector's declared `limits.min`/`limits.max`.
- **Write (out of range)** — a property write outside those hard limits. Only Unrestricted (or a sufficiently permissive Custom row) can let these through.
- **Large change** — a write whose delta exceeds `limits.largeChangeFraction` of the declared range (default 25%). Catches "fat finger" typos where the user meant 30 and typed 300.
- **Action** — a non-destructive method call.
- **Destructive action** — a method call the connector flagged via `confirm: { reset: "always" }` or `"typed"`.
- **AI confirmation** — whether the AI must restate numeric writes (with units) and summarize `write_script`/`run_code` calls before they execute. `Ask every time` on every built-in level; only **Custom** may set it to `Allow`.
- **Audit** — whether blocked / simulated / confirmed operations are written to `workspace/logs/audit.jsonl`.

**Level escalation:** switching levels applies on click. **Unrestricted** additionally requires typing `I UNDERSTAND` in the dialog — the typed phrase is the guard-rail; once granted, the level stays active until the user picks a different one. **Custom** is treated as equivalent risk to Assisted for escalation purposes, but the dialog flags the case where any Custom column is more permissive than Assisted's.

Open the chip in the status strip to change the level. The change propagates to every connected dashboard within one tick.

## Custom

Pick **Custom** in the dialog to set each column individually. The selected values persist to `workspace/config/server.json` under `safety.custom`:

```jsonc
{
  "safety": {
    "state": { "level": "Custom", "lastChange": "..." },
    "custom": {
      "writeInRange":      "Allow",
      "writeOutOfRange":   "Block",
      "largeChange":       "AskOnce",
      "action":            "Allow",
      "destructiveAction": "AskOnce",
      "aiConfirm":         "AskEveryTime",
      "audit":             "on"
    }
  }
}
```

Missing keys fall back to Assisted's row, so a minimal Custom block still works.

## Per-connector safety

A connector's `.js` config can carry an optional `safety` block:

```js
export default {
  driver: "Scpi",
  // ...
  safety: {
    limits: {
      voltage: { min: 0, max: 30, step: 0.01, largeChangeFraction: 0.25 },
      current: { min: 0, max: 3 },
    },
    confirm: {
      voltage: "onLargeChange", // once | always | never | typed | onLargeChange
      reset: "always",          // flags the action destructive
      shutdown: "typed",        // flags destructive + promotes to typed confirm
    },
    rate: {
      voltage: 10,     // max 10 writes/sec
      reset: 0.1,      // max 1 per 10s
    },
    interlock: {
      output_on: "safety_relay.state==true",
    },
    safeState: "setSafeDefaults",
    overrideLevel: "Active", // pin this connector to a specific level vs global
  },
}
```

**`limits`** — hard `min`/`max`. The level table decides what to do with out-of-range writes; `largeChangeFraction` (default 0.25) controls what counts as a "large" delta.

**`confirm`** — per-item override of the default outcome, keyed by property or action/method name. `once` caches the first confirmation per level; `always` both flags the action destructive **and** asks every time; `never` skips the prompt even when the level asks for one; `typed` marks destructive and promotes the confirm to the typed-phrase flow; `onLargeChange` falls through to the large-change column.

This block governs **both** confirmation layers — the connector-layer gate (UI, scripts, dashboards) **and** the AI Chat Panel. `never` silences the chat prompt for that item too (e.g. a camera's `pan`/`tilt`), and `always`/`typed` force a chat prompt even for a parameterless action. See [AI confirmation](#ai-confirmation) below for how the two layers interact.

**`rate`** — simple ops-per-second cap per item name. Exceeding it blocks with `SAFETY_BLOCKED`.

**`interlock`** — simple form `"<connector>.<property>==<value>"`. Interlock false blocks the op.

**`safeState`** — method to call for emergency safe-state. Stored but not auto-invoked in Phase 1.

**`overrideLevel`** — bidirectional pin. `"Active"` keeps this connector at Active even during a global Observe session (useful for cheap-to-simulate devices you still want "real" in test envs). `"Assisted"` keeps it gated during a global Unrestricted (protect an expensive connector from a globally permissive session). Accepts `Observe`, `Assisted`, `Active`, or `Unrestricted`; Custom is not accepted here.

## Per-driver opt-out

Some drivers have no path to physical hardware and no destructive actions — a webcam, a file-access driver, an IP camera. Forcing them through the safety gate is friction for no benefit. There are exactly two routes to opt out by declaring `requiresSafetyGates: false` on the driver itself:

- **Officially-signed C# DLL drivers:** `[assembly: RequiresSafetyGates(false)]` in the driver project. The assembly attribute wins over the interface default. Unsigned DLLs cannot opt out — the loader logs a security warning and forces gates back on.
- **Built-in drivers:** implement `bool RequiresSafetyGates => false;` on the `IConnectorDriver` class.

**JS and Python drivers cannot opt out.** A `meta.requiresSafetyGates: false` declaration (JS) or `META["requiresSafetyGates"] = False` (Python) is ignored: the loader logs a security warning and forces gates on.

When the flag is `false`, connectors of that driver never go through the safety gate: no limit checks, no confirmations, no rate caps, no simulate/block logic, and **no audit rows**. Default is `true` — every existing driver remains gated.

This is orthogonal to the per-connector `safety.overrideLevel`. `overrideLevel` pins a *gated* connector to a specific level at runtime; `requiresSafetyGates: false` is a driver-author declaration that the gate doesn't apply at all. A connector whose driver has `requiresSafetyGates: false` ignores `overrideLevel` too — the gate never runs.

Built-in drivers that ship with the flag off:

- `Webcam` — frame capture only, no hardware writes.
- `FileAccess` — workspace-scoped file I/O, already guarded by workspace state.
- `Onvif` — IP-camera PTZ/streaming, non-destructive and recoverable.
- `WebhookNotifier` — the target URL is fixed in config, no runtime target choice.

Built-in drivers that stay gated (default):

- `TestDevice` — kept gated on purpose, so it serves as the easiest example for exploring the safety system (limits, confirms, simulate, audit).
- `MqttBridge` — publishes to topics that may drive downstream IoT devices.
- `EmailNotifier` — sending mail to humans is a destructive action.

Use the flag sparingly. If there's any way a driver call could affect the physical world, keep it on.

## Audit log

Every blocked, simulated, or confirmed operation is appended to `workspace/logs/audit.jsonl` as a flat JSON line:

```json
{"ts":"2026-04-22T14:05:11.123Z","event":"write.blocked","caller":"ai:sess-9c2f","details":{"connector":"psu","item":"voltage","value":99,"rule":"limit.outOfRange"}}
```

Events: `level.change`, `write.blocked`, `action.blocked`, `write.simulated`, `action.simulated`, `confirm.granted`, `confirm.denied`. Readers tolerate unknown event names so a future phase can log every allowed write without migrating the file.

Callers appear as `script:<name>`, `ai:<sessionId>`, `dashboard:<clientId>`, `agent:<name>`, `mcp:<id>`, or `system:<subsystem>`. When somebody is signed in with an [account](https://docs.muxit.io/guides/accounts.md), the person is named instead: `operator:j.smith`, `engineer:m.chen`, `admin:root` — so a run can be attributed to whoever pressed the button. Accounts are a Pro feature; the audit log that records them is Lab, so the identity always flows and the log simply does not write on tiers without it.

Rotation: size-based, default 10 MB (configurable via `safety.audit.maxSizeMb`). Flip `safety.audit.rotateDaily: true` for nightly UTC rotation instead.

Query the last N records over WebSocket with `safety.audit.tail { "n": 200 }`.

## AI confirmation

The AI Chat Panel's tool-call prompts are driven by the **AI confirmation**
column in the safety matrix. Every built-in level ships with `Ask every time`;
only **Custom** can set the column to `Allow`. Switching levels doesn't turn
AI confirmation off — the guard is universal because voice input makes unit
misinterpretation a first-class risk ("15" → 15 V or 15 mV?).

When the column is on, two classes of tool call are parked for plain-text
confirmation:

1. **Numeric writes and actions** — `write_property` and `call_action` whose
   arguments contain any numeric value. The AI must restate every number with
   its unit ("setting voltage to 15 V, current limit to 0.35 A — confirm?")
   and wait for "yes" before it runs. Numbers the user just typed or spoke are
   echoed back too, because voice recognition often drops the unit.
2. **Script authoring and inline code** — `write_script` and `run_code`. The
   AI must summarize what the script will do in plain English (connectors,
   ranges, step sizes, expected duration) and flag any missing details before
   it executes. `run_script` on an already-saved script is *not* gated — the
   authoring step already was.

**Simple actions pass through unchanged.** A parameterless or boolean-only
call like `power_on`, `reset`, or `set_output(true)` carries no numbers and
isn't a script tool, so the AI executes it without a confirmation round-trip.

The confirmation is one-shot. On approval the assistant confirms the parked
call **by reference** — a lightweight internal `confirm_action` carrying only
the parked call's id — so a long script is never re-sent through the model just
to approve it (which used to double the token cost of authoring a script). If
the user changes any value, the assistant issues a fresh call and the gate
re-arms. When the user declines, the AI drops the operation and continues the
conversation normally — no tool runs.

### Per-item overrides for the chat-gate

The numeric heuristic is deliberately broad, so a `write_property` /
`call_action` you consider harmless — panning a camera, nudging a fan
speed — still gets parked for confirmation. To tune this **per property or
per action**, use the connector's [`safety.confirm`](#per-connector-safety)
block. The chat-gate honors the same entries the connector-layer gate does:

| `safety.confirm` value | Chat-gate behaviour |
| --- | --- |
| `never` | **Skip** the prompt for this item, even with numeric args. Use for non-critical, recoverable moves like camera pan/tilt. |
| `always` / `typed` | **Force** a prompt for this item, even when the call carries no numbers (e.g. a parameterless `reset`). |
| `once` / `onLargeChange` / *(unset)* | Fall back to the numeric heuristic (prompt when the args contain any number). |

```js
export default {
  driver: "Onvif",
  // ...
  safety: {
    confirm: {
      pan:  "never",   // AI won't ask before panning
      tilt: "never",   // ...or tilting
      reset: "always", // but always confirm a reset, even with no args
    },
  },
}
```

This keeps one `safety.confirm` line as the single source of truth for an
item across the UI, scripts, and the AI panel — there's no separate AI-only
switch per item. The global column below is still the master on/off.

### Global on/off

Turn the column off for an unattended workflow: pick **Custom** in the
SafetyChip dialog, set `AI confirmation` to `Allow`, and apply. The
behaviour persists under `safety.custom.aiConfirm` in `server.json`. This is
all-or-nothing across every connector; reach for the per-item `never` above
when you only want to exempt specific properties or actions.

### Upgrading from earlier workspaces

Older safety configs had no `aiConfirm` field. On first read they're treated
as `AskEveryTime` — the new safe default. The legacy `confirm_unknown_values`
/ `confirm_all` / `off` modes and their per-level mapping are gone; there is
no separate `ai.safetyMode` to remove.

## WebSocket surface

- `safety.get` — returns current snapshot: `level`, `allowedLevels`, `custom?`, `lastChangeCaller`, `lastChangeAt`, `licensed`.
- `safety.setLevel { target, typedPhrase?, custom? }` — request level change. Escalations prompt via `PromptManager`; Unrestricted requires `typedPhrase`; Custom persists the `custom` block to `server.json`.
- `safety.audit.tail { n }` — last N audit records.
- Broadcast `safety.changed` — every connected dashboard updates its chip within a tick.
- Broadcast `audit.log` — raw audit record fan-out for future UI viewers.

## What's intentionally out of scope in Phase 1

- `safeState` is stored but not auto-invoked. Triggering it on emergency comes with the next phase.
- Interlock parsing supports only the `"conn.prop==value"` form.
- The audit log captures level changes, blocked/simulated writes, and confirmations. A future phase can add `"write"` events for every allowed write without schema migration.
- Agent-specific limits in `AgentSafetyGate` are untouched — they run in parallel with the new gate, not merged.
