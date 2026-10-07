---
title: Virtual Driver
description: Reference for the Virtual built-in driver — an in-memory connector with no hardware, for sharing values between scripts and dashboards.
---

# Virtual

**An in-memory connector with no hardware behind it.** A Virtual connector holds values, computed properties and methods that dashboards and scripts read and write exactly like a device — but nothing is connected. Use it as a shared scratchpad: setpoints a dashboard slider adjusts and a script reads, status text a script writes and a dashboard shows, counters, flags, derived values.

The driver itself declares **no properties and no actions**. Everything the connector exposes comes from the connector file's own `properties:` and `methods:` blocks. State lives in the file's module-scope variables.

::: tip Safety gate
This driver ships with `requiresSafetyGates: false` — there is no hardware to protect, so writes and calls bypass the [safety gate](https://docs.muxit.io/guides/safety.md) entirely and no audit rows are written. See [Per-driver opt-out](https://docs.muxit.io/guides/safety.md#per-driver-opt-out).
:::

## Declaring one

The `driver:` keyword is **optional**. A connector file with no `driver:` / `protocol:` / `engine:` key resolves to Virtual automatically, as long as every top-level key is a standard connector key:

`config`, `properties`, `methods`, `poll`, `ai`, `hide`, `expose`, `safety`, `allowedConnectors`, `allowedHosts`

```javascript
// workspace/connectors/store.js
let setpoint = 20;
let running = false;
let status = "Idle";

export default {
  ai: { instructions: "In-memory store with no hardware attached. Safe to read and write freely." },

  properties: {
    setpoint: { get: () => setpoint, set: (v) => { setpoint = Number(v); },  description: "Target setpoint", poll: true },
    running:  { get: () => running,  set: (v) => { running = Boolean(v); },  description: "Run flag",        poll: true },
    status:   { get: () => status,   set: (v) => { status = String(v); },    description: "Status line",     poll: true },
    summary:  { get: () => `${status} — setpoint ${setpoint}${running ? " (running)" : ""}`, poll: true },
  },

  methods: {
    reset: [() => { setpoint = 20; running = false; status = "Idle"; }, "Restore defaults"],
  },
};
```

`driver: "Virtual"` (or `engine: "Virtual"`) is accepted too if you prefer the keyword spelled out — that's what the **Add Connector** template uses.

### Unknown keys still fail

Only files whose top-level keys are *all* standard resolve to Virtual. A misspelt keyword is an unknown key, so it keeps the usual load error and the connector shows as disabled in the Hardware panel with the offending key named:

```
Connector config missing 'driver' / 'protocol' / 'engine': …/psu.js (unrecognised top-level key: drivr)
```

This is deliberate: `drivr: "Webcam"` must not quietly turn into an empty store.

`.json` connector files are unaffected — they still require an explicit `"driver"` field.

## Properties

None from the driver. A property with a `set` is writable (`R/W`); one with only a `get` is read-only (`R`). The type shown in the Hardware panel is inferred from the last value read.

## Actions

None from the driver. Declare them under `methods:` in any of the three usual forms (bare function, `[fn, "description"]`, `{ fn, description }`).

## Config Options

None. A `config:` block is allowed but ignored by the driver — use it for your own constants if you like.

## Using it

**From a script:**

```javascript
const s = connector("store");
s.setpoint = 42;          // write — dashboards update immediately
if (s.running) { … }      // read
s.reset();                // method
```

**From a dashboard:** bind any widget to `store.setpoint`, `store.running`, `store.status`, … A slider bound to `store.setpoint` writes it; a gauge bound to the same property follows.

**From another connector:** list it in that connector's `allowedConnectors` and call `connector("store")` from its methods.

## Polling and updates

- A **direct property write** (script, dashboard, AI) updates the value and broadcasts a `state:` event immediately. No polling is involved.
- A value changed **inside a method** (`reset()` above) is only noticed by the poller, so mark such properties `poll: true` (or list them in a top-level `poll: [...]` array) to keep dashboards in sync.
- Computed read-only properties (`summary`) are re-read on each poll, so they follow the values they derive from.

## Persistence

**In memory only.** Values reset to the file's initial `let` values whenever the server restarts or the connector reloads. If a value must survive, write it out with [FileAccess](https://docs.muxit.io/reference/drivers/file-access.md) and read it back in a getter or a startup script.

## Limits

Virtual connectors count against your tier's [connector limit](https://docs.muxit.io/reference/subscription-plans.md#connectors) like any other connector.
