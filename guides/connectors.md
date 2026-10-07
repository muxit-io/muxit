---
title: Connector Guide
description: Writing connector configs — the bridge between hardware drivers and the rest of Muxit.
---

# Connector Guide

Connectors are the bridge between your hardware drivers and the rest of Muxit. They wrap a driver with custom methods, computed properties, and configuration — giving each physical device a friendly, high-level API.

## Connector Limits & Enable/Disable

Your license tier determines how many connectors can be active at once — Free allows 3 connectors, Maker raises this to 10, and Pro and above are unlimited. The **TestDevice** connector is always enabled and doesn't count against the limit. [Virtual](https://docs.muxit.io/reference/drivers/virtual.md) (in-memory) connectors count like any other.

**All connectors are visible** in the Hardware panel — disabled ones appear greyed out with a reason. You can choose which connectors to enable:

1. Open the **Hardware** panel (plug icon in the activity bar)
2. Check/uncheck connectors to enable or disable them (within your tier's limit)
3. Click **Save** to persist your selection
4. **Restart the server** for changes to take effect

Your selection is saved in `workspace/config/server.json` under `connectors.enabled`. If no selection exists (first run), the first N connectors are auto-selected.

## Quick Reference

```javascript
// Minimal connector — just a driver and config
export default {
  driver: "MyDriver",
  config: { port: "COM3" },
};
```

```javascript
// The driver is in scope as the closure variable `driver`
driver.voltage           // read property (no parens)
driver.voltage = 12      // write property (assignment)
driver.reset()           // execute action (function call)
```

**Tips:**
- Filename = connector name (e.g., `psu.js` → `connector("psu")`)
- Driver names are case-insensitive
- Use `poll: true` sparingly — each polled property generates I/O
- Test with the REPL: `schema("psu")` to verify your schema

---

## What Connectors Do

A **driver** provides raw hardware access (read voltage, send SCPI command, move motor). A **connector** adds:

- **Configuration** — pass settings like default voltage, serial port, IP address to the driver
- **Custom methods** — compose multiple driver calls into higher-level operations (e.g., `rampTo`, `safeReset`)
- **Computed properties** — derive values from driver properties (e.g., `power = voltage * current`)
- **Reactive polling** — automatically poll properties and push changes to dashboards

## File Location

Connector configs live in `workspace/connectors/` as JavaScript ES modules:

```
workspace/connectors/
├── psu.js
├── robot.js
├── spectrometer.js
└── panel.js
```

The filename (without `.js`) becomes the connector name.

---

## Let the AI write it (SCPI instruments)

For SCPI instruments — oscilloscopes, multimeters, power supplies, signal generators —
the fastest way to add a new device is the chat. Select **Scpi** in the Add
Connector dialog (it carries a `protocol` chip) and click **Set up with AI**, or
just say *"Add my Rigol DP832 at
192.168.1.50"*. The assistant probes the device with `*IDN?`, looks up the programming
manual online, drafts the connector config, validates it, writes it, and hot-reloads —
no server restart. See [AI-assisted SCPI setup](https://docs.muxit.io/guides/ai-scpi-authoring.md).

---

## Security Sandbox

Connector configs run in a **sandboxed V8 engine** (ClearScript). They do **not** have access to Node.js APIs:

- **Blocked:** `fs`, `child_process`, `process`, `net`, `http`, `require()`, dynamic `import()`
- **Allowed:** Standard JS globals (`Math`, `JSON`, `Date`, `Promise`, etc.), transport factories, and script globals (see below)

### Script Globals

Custom methods and properties have access to the same globals as user scripts:

| Global | Description |
|--------|-------------|
| `connector(name)` / `device(name)` | Access another connector by name (returns a proxy) |
| `log.debug/info/warn/error(...)` | Structured logging (appears in server output and EventBus) |
| `console.log/warn/error` | Aliases for `log.info/warn/error` |
| `emit(event, data)` | Publish event to EventBus as `connector:{event}` |
| `delay(ms)` | Async sleep (max 30 seconds) |
| `timestamp()` | Returns ISO 8601 UTC timestamp |
| `createTcpTransport(host, port, opts)` | Create TCP transport for driver config |
| `createSerialTransport(path, opts)` | Create serial transport for driver config |

Example using globals in a custom method:
```javascript
methods: {
  rampTemp: {
    fn: (args) => {
      const target = args?.target ?? 30;
      log.info(`Ramping to ${target}°C`);
      driver.temperature = target;
      emit("temp.changed", { target });
      return driver.temperature;
    },
    description: "Ramp temperature with logging",
  },
},
```

---

## Basic Format

```javascript
// workspace/connectors/psu.js
export default {
  driver: "MockInstrument",
  config: { defaultVoltage: 0, defaultCurrent: 1.0 },
  poll: ["power"],

  methods: {
    rampTo: [async (target) => {
      const current = await driver.voltage;
      const step = (target - current) / 10;
      for (let i = 1; i <= 10; i++) { driver.voltage = current + step * i; await delay(50); }
      return driver.voltage;
    }, "Ramp voltage to target in 10 steps"],
  },

  properties: {
    power: [async () => {
      const v = await driver.measured_voltage;
      const i = await driver.measured_current;
      return Math.round(v * i * 1000) / 1000;
    }, "Calculated power (W)"],
  },
};
```

---

## AI Instructions

You can embed AI instructions directly in your connector config. These appear in the AI system prompt alongside the device listing, giving the AI context about how to safely interact with this device.

```javascript
export default {
  driver: "Fairino",
  ip: "192.168.2.222",

  ai: {
    instructions: "Max speed = 29 when homing. Always ask for confirmation before moves.",
  },

  methods: { /* ... */ },
};
```

The `ai.instructions` string appears in the system prompt right after the device name, before its properties and actions. Use it for:

- **Safety rules** — speed limits, force limits, no-go zones
- **Confirmation requirements** — "always confirm before enabling output"
- **Device context** — what the device is, units, coordinate systems
- **Usage hints** — "take a dark reference before measuring"

This is additive with per-property/per-action notes configured in `server.json` under `ai.access`:

| Location | Scope | Use case |
|----------|-------|----------|
| Connector `ai.instructions` | Whole device | Safety rules, general behavior, device context |
| `server.json` `ai.access` | Per property/action | Hide items from AI, add per-item notes |

---

## Shorthand Syntax

Methods and properties each accept **three definition forms**. All forms are normalized to the object form at init time.

### Methods

```javascript
methods: {
  // 1. Bare function — no description
  goHome: () => driver.home(),

  // 2. Array tuple — [fn, description]
  moveTo: [(x, y, z) => driver.moveL({ pose: [x, y, z] }), "Linear move"],

  // 3. Object — full form (use `fn` or `call` as the function key)
  rampTo: {
    fn: async (target) => { /* ... */ },
    description: "Ramp voltage to target",
  },
  // Equivalent using `call`:
  scan: {
    call: async () => { /* ... */ },
    description: "Take a measurement",
  },
}
```

### Properties

```javascript
properties: {
  // 1. Bare function — no description, no poll
  position: () => driver.tcpPos,

  // 2. Array tuple — [getter, description, options?]
  power: [async () => (await driver.v) * (await driver.i), "Power (W)", { poll: true }],

  // 3. Object — full form
  idle: {
    get: () => driver.motionDone,
    poll: true,
    description: "Robot is idle",
  },
}
```

The optional third element in the array tuple is an options object that can include `poll`, `set`, or any other property options.

### Top-level `poll` shorthand

Instead of setting `poll: true` on each property, list polled property names at the top level:

```javascript
export default {
  driver: "Fairino",
  poll: ["position", "joints", "idle"],

  properties: {
    position: () => driver.tcpPos,
    joints: () => driver.jointPos,
    idle: () => driver.motionDone,
  },
};
```

---

## Fields

### `driver` (required)

The name of the driver to use. Must match a registered driver name (case-insensitive lookup).

```javascript
driver: "MockInstrument"     // Tier 1: JS driver
driver: "Fairino"            // Tier 3: C# native driver
```

### `config` (optional)

Configuration object passed to `driver.init()`. Contents depend on the driver.

```javascript
config: {
  ip: "192.168.1.100",
  port: 5000,
  defaultVoltage: 0,
}
```

Use `$ENV{VAR_NAME}` to reference environment variables for sensitive values like API keys and passwords:

```javascript
config: {
  ip: "192.168.1.100",
  apiKey: "$ENV{MY_DEVICE_API_KEY}",
  password: "$ENV{DEVICE_PASSWORD}",
}
```

Environment variable references are resolved when the connector loads. A warning is logged if a referenced variable is not set.

### `methods` (optional)

Custom methods that compose driver calls. The function's parameters mirror the script-side call exactly (`psu.rampTo(5)` → `(target) => …`); the driver itself is in scope as the closure variable `driver`.

### `properties` (optional)

Computed properties that derive values from driver properties. Object fields: `get()` (getter), `set(value)` (optional setter), `poll` (enable reactive polling), `description`. The driver is in scope as `driver`.

Reading a driver property inside a connector returns a Promise. Returning it as is works (`get: () => driver.voltage`), but to combine values, make the getter `async` and `await` each read; otherwise a template string shows `[object Promise]` and arithmetic gives `NaN`:

```javascript
resolution: { get: async () => `${await driver.width}x${await driver.height}` },
power:      { get: async () => (await driver.voltage) * (await driver.current), poll: true },
```

### `hide` / `expose` (optional)

Control which properties and actions appear in the external schema (hardware panel, MCP tools, AI system prompt). Both driver items and custom items (defined in `methods` / `properties` below) can be hidden or exposed. Hidden items remain fully callable from scripts and from within your connector's own code — only external visibility is affected.

Use `hide` (blacklist) to remove specific driver items:

```javascript
export default {
  driver: "Fairino",
  // Hide raw motion commands — connector exposes friendlier moveTo/moveToJ
  hide: ["moveJ", "moveL", "moveCart", "pause", "resume"],
  methods: {
    moveTo: { fn: (x, y, z, rx, ry, rz, opts) => driver.moveL({ pose: [x,y,z,rx,ry,rz], ...opts }), description: "Linear move" },
  },
};
```

Use `expose` (whitelist) to show only specific driver items — useful when a driver has many items and you want a minimal surface:

```javascript
export default {
  driver: "Fairino",
  expose: ["speed", "enabled", "tcpPos", "jointPos", "motionDone"],
  methods: { /* custom methods are always visible */ },
};
```

**Rules:**
- `hide` and `expose` are **mutually exclusive** — specifying both is an error
- Both driver items AND custom methods / properties (defined in `methods` / `properties`) can be hidden or exposed
- Matching is **case-insensitive**
- Streams are also filtered by the same list
- Hidden items are still polled if configured and still callable from scripts — hiding only affects discoverability (what shows up in the Hardware panel, MCP tools, and the AI system prompt)

#### Editing visibility from the GUI

Expand a connector in the **Connectors** panel and click the pencil (✎) in
the card header to enter edit mode. Every property, action, and stream gets
an eye icon on its row — filled means visible, hollow means hidden. Items
that are currently hidden appear greyed out in edit mode so you can toggle
them back on. Each section header also has **hide all** / **show all**
shortcuts for bulk changes. Click the pencil again to leave edit mode; the
panel returns to the plain, read-only view.

Visibility changes are written back to the connector's `.js` source (the
top-level `hide: [...]` array — any existing `expose:` whitelist is cleared
to keep the file consistent) and the connector is hot-reloaded. The AI picks
up the new surface on its next turn — no server restart is required.

#### Editing driver config from the GUI

In edit mode the expanded view also shows a **Config** section listing the
connector's current driver-config values. Primitive entries (string, number,
boolean) have inline editors; committing a change rewrites the matching
literal in the `.js` source and hot-reloads the connector. Non-primitive
values (expressions, transports, nested objects) are rendered read-only —
edit the file directly to change them. Internal framework keys (anything
starting with `_`, e.g. `_workspacePath`) are never shown.

If a connector fails to initialize (wrong serial port, unreachable host,
...), its card automatically expands into edit mode with the Config section
visible, so you can fix the underlying value without opening the file. Only
`.js` connectors are supported; `.json` configs are read-only in this view.

#### Reading, writing & running from the GUI

Expanding a connector in the **Connectors** panel polls its property values
live. You don't need edit (✎) mode for this — reading, writing, and running
are available in the plain expanded view:

- **Writable properties** (those whose access includes `W`, e.g. `R/W`) show a
  pencil on hover. Click the value to edit it inline — type a new value and
  press **Enter** (or click **Set**) to commit; **Escape** (or **✕**) cancels.
  Boolean properties get a `true`/`false` dropdown. The row updates immediately
  and is reconciled with the device on the next poll.
- **Actions** show a run (▶) button on hover. Parameterless actions run on a
  single click. Actions that take arguments open a small inline form — fill in
  the values (coerced to each argument's declared type) and click **Run**.

Writes and action calls go through the same [safety gate](https://docs.muxit.io/guides/safety.md) as
scripts and the AI assistant, so a blocked or confirmation-gated operation is
handled exactly as it would be elsewhere; a failure shows a small ⚠ on the row
with the reason on hover. None of this affects drag-to-script — you can still
drag any property, action, or stream row into a script editor or dashboard
widget binding.

---

## The Driver Closure Variable

Inside `methods.fn` and `properties.get/set`, the underlying driver is in scope as the closure variable `driver` — a Proxy object with true property syntax:

```javascript
driver.voltage           // → driver.get("voltage")    — property read
driver.voltage = 12      // → driver.set("voltage", 12) — property write
driver.reset()           // → driver.execute("reset")   — action call
```

Function signatures mirror the script-side call exactly:

| Script call            | Connector function           |
|------------------------|------------------------------|
| `psu.start()`          | `start: () => driver.…`      |
| `psu.rampTo(5)`        | `rampTo: (target) => driver.…` |
| `psu.voltage`          | `voltage: { get: () => driver.… }` |
| `psu.voltage = 12`     | `voltage: { set: (v) => { driver.… } }` |

Rules:
1. Known property, direct access → `driver.get(name)` — returns a **Promise** of the value; `await` it
2. Known property, assignment → `driver.set(name, value)`
3. Known action, function call → `driver.execute(name, args)` — returns a Promise of the result
4. Unknown name → throws `ReferenceError: Driver has no property or action '<name>'`. Only names the driver declares exist on `driver`; your own `properties` / `methods` are not on it.

---

## Polling and State Updates

Properties with `poll: true` are automatically read at a fixed interval. When the value changes, it's broadcast to WebSocket subscribers via the `state.batch` message.

The poll interval defaults to 200ms. It is a single global setting for all connectors — `polling.connectorRate` in the server configuration (see [Configuration](https://docs.muxit.io/reference/configuration.md)); it cannot be overridden per connector.

Only changed values trigger updates (deep equality check).

---

## Driver Properties vs Connector Properties

When you expand a connector in the Hardware pane, you see **two kinds of properties**:

- **Driver properties** — declared by the driver itself (e.g., `jointPos`, `tcpPos`, `forceSensor`, `emergencyStop`). These have typed metadata including type, access level (R or R/W), unit, and description.
- **Custom properties** — defined in your connector config's `properties` block (e.g., `position`, `joints`, `idle`). These typically wrap or compute values from driver properties.

Both appear together in the Hardware pane. Each property is tagged with a `source` field (`"driver"` or `"custom"`) so you can tell them apart.

### How they merge

The connector schema includes **all driver properties** plus **all custom properties**. If a custom property has the **same name** as a driver property, the custom version takes priority and the driver version is hidden. This lets you override a driver property with custom logic (e.g., unit conversion, formatting).

Since custom properties usually have different names (e.g., `position` wrapping `tcpPos`), both appear side by side:

```
Properties (from robot connector + Fairino driver):
  position      [custom]   — Current TCP position (your connector wrapper)
  joints        [custom]   — Current joint angles (your connector wrapper)
  idle          [custom]   — Motion idle flag (your connector wrapper)
  tSpeed        [custom]   — Computed total tool speed
  jointPos      [driver]   — Raw joint angles from driver
  tcpPos        [driver]   — Raw TCP pose from driver
  forceSensor   [driver]   — Force/torque sensor data
  emergencyStop [driver]   — E-stop status
  ... (all other driver properties)
```

### Same pattern for methods

Methods work identically — driver actions and custom methods both appear. Custom methods with the same name as a driver action override the driver version.

### Accessing driver properties from scripts

Both custom and driver properties are accessible through the connector proxy in scripts:

```javascript
let r = connector("robot");
r.position;         // custom property (defined in robot.js)
r.jointTorques;     // driver property (from Fairino driver directly)
r.forceSensor;      // driver property
```

---

## Virtual Store Connector Pattern

A **Virtual** connector is an in-memory data store with no hardware. It bridges scripts and dashboards: the values live in the connector file's own variables and are exposed as ordinary properties. No `driver:` keyword is needed — a file whose top-level keys are all standard connector keys resolves to the built-in [Virtual](https://docs.muxit.io/reference/drivers/virtual.md) driver (`driver: "Virtual"` also works if you prefer it explicit).

```javascript
// workspace/connectors/store.js
let value1 = 0;
let input = 50;
let running = false;
let status = "Idle";

export default {
  properties: {
    value1:  { get: () => value1,  set: (v) => { value1 = Number(v); },  poll: true },
    input:   { get: () => input,   set: (v) => { input = Number(v); },   poll: true },
    running: { get: () => running, set: (v) => { running = Boolean(v); }, poll: true },
    status:  { get: () => status,  set: (v) => { status = String(v); },  poll: true },
  },
  methods: {
    reset: [() => { value1 = 0; input = 50; running = false; status = "Idle"; }, "Back to defaults"],
  },
};
```

Bind dashboard widgets (gauge, slider, light, text) to `store.value1`, `store.input`, and so on. Values are not persisted across restarts — write them to a file through [FileAccess](https://docs.muxit.io/reference/drivers/file-access.md) if they need to survive.

**Data flow — property path:**
Script → `store.value1 = 42` → custom setter → `state:` event (immediate) → `state.batch` → dashboard gauge

`poll: true` matters when a **method** changes a value behind the scenes (`reset` above): direct property writes broadcast on their own, but the poller is what picks up changes made inside a method.

**Data flow — stream path:**
Script → `stream("store", "display", base64)` → EventBus → `stream.subscribe` → dashboard canvas

---

## Transports

Drivers that communicate over a network or serial port use a **transport**. Built-in serial JS drivers (`Gcode`, `SerialMonitor`, `Plotter`) accept plain `port` / `baudRate` fields and build the transport internally. TCP drivers, custom JS drivers, and advanced setups (e.g. wiring a TCP simulator to a serial driver) can still pass a pre-built transport via `config._transport`.

### Serial — plain config (recommended for built-in serial drivers)

```javascript
export default {
  driver: "Gcode",
  config: {
    port: "COM3",          // or "/dev/ttyUSB0"
    baudRate: 115200,      // optional, defaults to 115200
    // optional: delimiter, timeout, dataBits, parity, stopBits
  },
};
```

### SCPI over Serial

The built-in [Scpi protocol](https://docs.muxit.io/reference/drivers/scpi.md) picks its Transport from the `connection:` block — no manual `createTcpTransport` plumbing:

```javascript
export default {
  protocol: "Scpi",
  connection: { type: "serial", port: "COM3", baudRate: 9600 },
  config: {
    terminator: "\n",
    timeoutMs: 3000,
    autoConnect: true,
  },
};
```

### TCP Transport

```javascript
import { createTcpTransport } from "createTcpTransport";

export default {
  driver: "Keithley2400",
  config: {
    _transport: createTcpTransport("192.168.1.100", 5000, {
      timeout: 5000,
      delimiter: "\n",
    }),
  },
};
```

### Escape hatch: pre-built serial transport

For writing your own JS driver, or for redirecting a serial-based driver through a non-serial transport (e.g. the GRBL TCP simulator), pass a pre-built transport in `config._transport`:

```javascript
import { createSerialTransport } from "createSerialTransport";

export default {
  driver: "MyJsDriver",
  config: {
    _transport: createSerialTransport("COM3", {
      baudRate: 9600,
      delimiter: "\n",
      timeout: 3000,
    }),
  },
};
```

Transports expose: `connect()`, `write(data)`, `query(command)`, `close()`, and `connected` (getter). Serial transports also support `writeRaw(data)` for raw bytes and an `onData` callback for streaming protocols.

> **Note:** Transport imports in connector configs are validated against an allowlist — only `createSerialTransport` and `createTcpTransport` are permitted.

### Which hosts a TCP transport may reach

`createTcpTransport()` is restricted to the local network. Loopback and the private
ranges — `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16` — are
allowed; anything else is refused with an error naming the two ways to permit it.
A hostname is never treated as private, however local it looks, because Muxit does
not resolve it to decide (that would be a DNS lookup per call, and the answer could
change between the check and the connect). Names have to be listed.

For one endpoint, give the connector a top-level `allowedHosts` array:

```js
export default {
  driver: "MyDriver",
  allowedHosts: ["api.vendor.com", "nas.local"],
  config: {
    _transport: createTcpTransport("api.vendor.com", 443, { timeout: 3000 }),
  },
};
```

`allowedHosts` is additive and applies to that connector alone: it adds names to
what this connector may reach and cannot lift the private-network restriction or
reach another connector's exceptions. To allow every host server-wide instead, set
[`security.allowExternalTransports`](https://docs.muxit.io/reference/configuration.md#security) to `true`
in `config/server.json` — a blunter instrument, and worth preferring `allowedHosts`
over.

The restriction is enforced in the host, outside the sandbox, and is fixed when the
connector's sandbox is built. Connector JS cannot change it.

---

## Schema Output

Connectors automatically generate a schema from driver metadata plus custom methods and properties:

```json
{
  "name": "psu",
  "driver": "MockInstrument",
  "properties": {
    "voltage": { "type": "number", "access": "rw", "unit": "V", "description": "Output voltage" },
    "power": { "type": "object", "access": "r", "description": "Calculated power (W)" }
  },
  "actions": {
    "reset": { "description": "Reset to defaults" },
    "rampTo": { "description": "Ramp voltage to target in 10 steps" }
  },
  "streams": []
}
```

---

## Real Hardware Examples

### BK Precision 9122A (USB-Serial PSU)

Uses the built-in [Scpi protocol](https://docs.muxit.io/reference/drivers/scpi.md) with a declarative schema — each instrument property/method is described once by command + type, and the protocol synthesizes the read/write/dispatch behind the scenes. See the [SCPI reference](https://docs.muxit.io/reference/drivers/scpi.md#declarative-schema) for the full field list.

```javascript
export default {
  protocol: "Scpi",
  connection: { type: "serial", port: "COM3", baudRate: 9600 },
  config: {
    terminator: "\n",
    timeoutMs: 3000,
    autoConnect: true,
    commandIntervalMs: 50,   // slow PSU — pace SCPI ops by 50 ms

    // Declarative schema — protocol turns each entry into a property (get/set)
    // or a method (fire-and-forget command). Trailing "?" = read-only query.
    schema: {
      properties: {
        voltage:          { cmd: "VOLT",       type: "float", unit: "V", description: "Programmed voltage" },
        current:          { cmd: "CURR",       type: "float", unit: "A", description: "Programmed current limit" },
        output:           { cmd: "OUTP",       type: "bool",             description: "Output enable" },
        measured_voltage: { cmd: "MEAS:VOLT?", type: "float", unit: "V" },
        measured_current: { cmd: "MEAS:CURR?", type: "float", unit: "A" },
      },
      methods: {
        local: { cmd: "SYST:LOC",  description: "Return to local control" },
        beep:  { cmd: "SYST:BEEP" },
        save:  { cmd: "*SAV", arg: "int", description: "Save settings to memory" },
      },
    },
  },
  poll: ["voltage", "current", "output", "measured_voltage", "measured_current"],

  methods: {
    on:  [() => { driver.output = true;  }, "Turn output ON"],
    off: [() => { driver.output = false; }, "Turn output OFF"],
    setOutput: {
      fn: (args) => {
        if (args?.voltage != null) driver.voltage = args.voltage;
        if (args?.current != null) driver.current = args.current;
      },
      description: "Set voltage and current: { voltage, current }",
    },
  },

  properties: {
    // Computed power — pure JS layered on the declared measurements.
    power: {
      get: async () => {
        const v = await driver.measured_voltage;
        const i = await driver.measured_current;
        return Math.round(v * i * 1000) / 1000;
      },
      description: "Calculated power (W)",
    },
  },
};
```

Common SCPI commands (`*RST`, `*IDN?`, `*CLS`, `SYST:ERR?`, …) are already exposed by the driver as `driver.reset()`, `driver.identify()`, `driver.clear()`, `driver.readErrors()` — no need to redeclare them in the connector.

Top-level `properties`/`methods` entries override any name declared in `scpi.*`, so you can declare the common 80% and hand-write the vendor quirks (unusual response formats, multi-step sequences, computed values) in the verbose form.

### Serial Monitor (Terminal)

```javascript
export default {
  driver: "SerialMonitor",
  config: {
    port: "COM3",
    baudRate: 9600,
  },

  methods: {
    sendLine: {
      fn: async (args) => {
        const text = typeof args === "string" ? args : args?.text ?? "";
        return driver.sendLine({ text });
      },
      description: "Send a line of text to the serial port",
    },
  },
};
```

### G-code / GRBL CNC

```javascript
export default {
  driver: "Gcode",
  config: {
    port: "COM3",
    baudRate: 115200,
    statusInterval: 250,
  },
  poll: ["status", "position", "progress"],

  methods: {
    park: {
      fn: async () => {
        await driver.send({ command: "G0 Z5 F500" });
        await driver.send({ command: "G0 X0 Y0 F1000" });
      },
      description: "Raise Z and park at origin",
    },
  },
};
```
