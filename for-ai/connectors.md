---
title: Writing Connectors — Reference for AI Assistants
description: Everything an AI assistant needs to write a working Muxit connector file — file shape, the Scpi, LineText and BinaryStream protocols, drivers, custom properties and methods, safety, and the mistakes to avoid.
---

# Writing Muxit connectors

*A reference for AI assistants. It is self-contained: you can write a correct connector from this
page alone. Read [Rules the runtime enforces](#rules-the-runtime-enforces) before anything else,
and finish with the [checklist](#checklist).*

A **connector** is one JavaScript file that brings one device into Muxit. It names the backend
that talks to the device, says how the device is connected, and can add computed properties,
helper methods, safety limits and instructions for Muxit's own AI. Scripts, dashboards and the AI
then use the device by the connector's name: the file `workspace/connectors/psu.js` is the
connector `psu`, reached from a script as `connector("psu")`.

## The deliverable

- **One file**, `workspace/connectors/<name>.js`. The file name without `.js` is the connector
  name; use lowercase letters, digits, `-` and `_` (`psu`, `bench-dmm`, `arduino_env`).
- **An ES module with a single `export default { … }`.** Plain JavaScript, no TypeScript.
- It runs in a **sandboxed V8 engine inside the Muxit server**: not Node.js, not a browser.
  There are no npm packages and no Node or browser APIs.
- Give the user the whole file, its path, and the values only they can fill in (serial port,
  IP address), called out.

## Rules the runtime enforces

Breaking any of these either stops the file from loading or makes it misbehave quietly.

1. **Pick exactly one backend keyword**: `protocol:` (a built-in wire protocol: `"Scpi"`,
   `"LineText"`, `"BinaryStream"`), `driver:` (a driver that owns its connection), or `engine:`
   (compute over another connector). Leave all three out only for an in-memory
   [Virtual](#virtual-no-hardware) connector.
2. **Top-level keys are fixed.** The recognised keys are `driver`, `protocol`, `engine`,
   `config`, `methods`, `properties`, `poll`, `ai`, `hide`, `expose`, `safety`,
   `allowedConnectors`, `allowedHosts`. Any *other* top-level key (`connection`, `source`, a
   driver option) is handed to the driver as configuration, and `config: { … }` overrides it.
   In a file without a backend keyword, an unrecognised key is a load error.
3. **These strings may not appear anywhere in the file, comments and string literals
   included:** `require(`, `import(`, `eval(`, `Function(`. The loader rejects the file on a text
   match. Do not write `import` statements either: a default import (`import x from "…"`) is an
   error, and the named form is stripped and does nothing — everything you can use is already a
   global.
4. **Inside a connector, every `driver.<name>` read and every `driver.<action>(…)` call returns a
   Promise.** Make the getter or method `async` and `await` each one. Without `await`, arithmetic
   gives `NaN` and template strings show `[object Promise]`. A write, `driver.<name> = value`,
   starts immediately but cannot be awaited — see [The `driver` object](#the-driver-object).
5. **`driver` has only the names the backend declares.** Anything else throws
   `ReferenceError: Driver has no property or action '<name>'`. Your own custom properties and
   methods are *not* on `driver`.
6. **There is no `this` and no `this.state`.** Keep state in module-level `let` variables above
   `export default`.
7. **Return plain values** — numbers, strings, booleans, `null`, arrays, plain objects. Never
   `{ value, unit }`: the unit goes in the `description` (or `unit` field), and dashboards and
   scripts expect a bare number.
8. **Every readable property the backend declares is polled automatically**, each on its own loop
   every 200 ms (server setting `polling.connectorRate`). The `poll` key only switches polling on
   for *your* custom properties. A backend property stops being polled only when a custom
   property of the same name replaces it, so keep protocol schemas to the properties the user
   needs.
9. **Never invent device commands, line formats or register offsets.** Take them from the manual
   or the user, and say which ones you could not verify.

## Choose the backend

| The device… | Backend | Section |
|---|---|---|
| answers SCPI (`*IDN?` works): benchtop PSUs, DMMs, scopes, generators, loads — Rigol, Keysight, Siglent, Tektronix, R&S, Keithley, BK Precision, Owon… | `protocol: "Scpi"` | [Scpi](#protocol-scpi) |
| prints text lines (`TEMP: 25.5`, `V=12.0`): Arduino and ESP32 sketches, hobby supplies, loggers, anything with a serial console | `protocol: "LineText"` | [LineText](#protocol-linetext) |
| sends or answers fixed-layout binary frames: Modbus RTU, custom binary sensors | `protocol: "BinaryStream"` | [BinaryStream](#protocol-binarystream) |
| is a camera, file store, MQTT broker, notifier, label printer, or has an installed Muxit driver (Fairino robot, Avantes spectrometer, G-code machine…) | `driver: "<Name>"` | [Drivers](#using-a-driver) |
| is processed from another connector's output (object detection on a camera feed) | `engine: "<Name>"` | [Engines](#engines) |
| does not exist: shared values for dashboards and scripts | no keyword | [Virtual](#virtual-no-hardware) |
| fits none of these: vendor SDK, stateful or multi-step protocol | a new driver | [Writing Drivers](https://docs.muxit.io/for-ai/drivers.md) |

Use SCPI when the vendor documents SCPI commands, even if the cable is USB or serial. Use LineText
for text that is not SCPI. BinaryStream is only for byte-level frames.

## File anatomy

```js
// workspace/connectors/bench_psu.js
let lastSetpoint = null;                       // module-level state, if you need any

export default {
  protocol: "Scpi",                            // 1. backend: protocol | driver | engine
  connection: { type: "tcp", host: "192.168.1.50", port: 5025 },   // 2. transport (protocols only)

  config: {                                    // 3. options for the backend
    terminator: "\n",
    schema: {                                  //    protocols: what the device understands
      properties: { voltage: { cmd: "VOLT", type: "float", unit: "V", description: "Set voltage" } },
      methods:    { beep: { cmd: "SYST:BEEP", description: "Beep" } },
    },
  },

  properties: { /* computed properties — see Custom properties */ },
  methods:    { /* helper methods — see Custom methods */ },
  poll:       [ /* names of custom properties to poll */ ],

  safety: { limits: { voltage: { min: 0, max: 30 } } },     // 4. hard limits, confirmations
  ai: { instructions: "Bench PSU, 0–30 V. Confirm before enabling the output." },  // 5. for Muxit's AI
};
```

## `connection:` — how the bytes move

Protocol connectors need a top-level `connection:` block. Drivers usually take their own options
in `config` instead — see the driver's reference.

`type` must be `"serial"`, `"tcp"` or `"usbtmc"`; anything else fails to load.

**serial**

| Field | Default | Notes |
|---|---|---|
| `port` | — | `"COM4"` on Windows, `"/dev/ttyUSB0"` / `"/dev/ttyACM0"` on Linux, `"/dev/tty.usbserial-XXXX"` on macOS. Required. |
| `baudRate` | `9600` | Must match the device. |
| `dataBits` | `8` | |
| `parity` | `"none"` | `"none"`, `"odd"`, `"even"`, `"mark"`, `"space"`. |
| `stopBits` | `"1"` | `"1"`, `"1.5"`, `"2"`. |
| `flowControl` | `"none"` | `"none"`, `"xon-xoff"`, `"rts-cts"`, `"both"`. |

**tcp**

| Field | Default | Notes |
|---|---|---|
| `host` | `"127.0.0.1"` | IP address or host name. |
| `port` | `5025` | 5025 is the usual raw-SCPI (LXI) port. |
| `timeoutMs` | `5000` | Connect timeout. |

**usbtmc** — USB instruments that enumerate as USB Test & Measurement class. Works with `Scpi`
only; LineText and BinaryStream never receive data over it.

| Field | Default | Notes |
|---|---|---|
| `vendorId`, `productId` | — | Required. Number (`0x1AB1`) or string (`"0x1AB1"`). |
| `serial` | — | Pick one of several identical instruments by serial number. |
| `interfaceNumber` | `0` | |
| `endpointNumber` | `1` | Bulk OUT endpoint; IN is `0x80 | n`. |

On Windows a USBTMC instrument needs the WinUSB driver bound (Zadig); on Linux, a udev rule.

## Protocol: Scpi

For instruments that speak SCPI. You declare each property once — the command and its type — and
the protocol does the query, the write and the parsing.

**`config` options**

| Option | Default | Meaning |
|---|---|---|
| `terminator` | `"\n"` | Appended to every command; a reply ends at the first terminator (a trailing `\r` is stripped). Some instruments need `"\r\n"` or `"\r"`. |
| `timeoutMs` | `5000` | How long a query waits for its reply. |
| `commandIntervalMs` | `0` | Minimum gap between any two commands. Set 20–100 for slow instruments that drop commands. |
| `autoConnect` | `false` | When `true`, sends `*IDN?` at start-up to fill the `identity` property. The transport opens either way. |
| `schema` | — | `{ properties, methods }`, below. |

**`schema.properties`** — one entry per value:

```js
voltage:          { cmd: "VOLT",       type: "float", unit: "V", description: "Programmed voltage" },
output:           { cmd: "OUTP",       type: "bool",             description: "Output enable" },
measured_voltage: { cmd: "MEAS:VOLT?", type: "float", unit: "V", description: "Measured voltage" },
```

| Field | Meaning |
|---|---|
| `cmd` | Required. Without a trailing `?`, the property is read with `cmd + "?"` and written with `cmd + " " + value`. With a trailing `?`, the command is sent as written and the property is read-only. |
| `type` | `"float"`, `"int"`, `"bool"` or `"string"` (the default). |
| `unit`, `description` | Shown in the UI and to Muxit's AI. |
| `readonly` | `true` makes a property without `?` read-only. |

No other fields exist. `min`, `max`, `enum`, `scale`, `format` and `details` are ignored —
ranges belong in [`safety.limits`](#safety). Parsing on read: `float` and `int` must parse as
numbers or the read fails; `bool` is true for `1`, `ON` or `TRUE` and false for anything else.
On write, `bool` is sent as `ON` / `OFF` — if the instrument wants `1` / `0`, declare the
property as `type: "int"`.

**`schema.methods`** — commands that do something and return nothing:

```js
beep:   { cmd: "SYST:BEEP", description: "Beep once" },
save:   { cmd: "*SAV", arg: "int", description: "Save settings to slot N" },   // psu.save(3) → "*SAV 3"
```

`arg` is a type (`"float"`, `"int"`, `"bool"`, `"string"`) or `{ type, name }`. The method sends
`cmd` or `cmd + " " + value` and returns `"OK"`; it never reads a reply. Always pass the
argument a method declares: without it a script call sends a placeholder (`0`, `OFF` or nothing)
and a call from connector code fails. Do not declare an `arg` the command does not take.

**Built in** — always present, do not redeclare:

| Name | Kind | What it does |
|---|---|---|
| `connected`, `identity`, `lastCommand`, `lastResponse`, `queryCount` | read-only properties | Status; no I/O. |
| `connect()`, `disconnect()` | actions | Open / close the transport. `connect` also queries `*IDN?`. |
| `identify()` | action | `*IDN?` |
| `reset()` | action | `*RST` |
| `clear()` | action | `*CLS` |
| `query(command)` | action | Send any command, return the reply line as a string. |
| `send(command)` | action | Send any command, no reply. |

Do not name schema entries after the built-ins: a schema property called `identity` is never
queried, and a schema method called `query` or `send` hides the raw one.

**What the schema cannot express — use a custom property or method with `driver.query`:**

- Queries with parameters (`MEAS:VOLT? CH1`, `:MEAS:ITEM? VPP,CHAN1`). The schema always sends
  `cmd + "?"`.
- One reply carrying several values (`U=12.00 I=0.103`, `5.012,0.103,12.4`). Never map several
  properties to the same `cmd`. Query once and parse — see the
  [multi-value example](#multi-value-replies).
- Multi-step sequences, or commands whose reply needs custom parsing.

**I/O cost.** Every schema property is queried on every poll cycle — five properties at the
default 200 ms is 25 queries a second — and the protocol has no cache: each `await driver.voltage`
inside your own code is one more query. All queries share one line: a query the instrument never
answers holds it for the full `timeoutMs` on every poll cycle and delays every other property, and
two timeouts in a row trip a breaker that fails all queries until the instrument answers again. So
declare only properties the user wants, and make any command without a query form a method, never
a property.

The legacy `driver: "GenericScpi"` with a flat config and a `config.scpi` block still loads; do not
write new connectors in that shape.

## Protocol: LineText

For devices that print lines of text. Each property recognises a line and keeps the last value it
saw; reading a property never sends anything.

**`config` options:** `terminator` (default `"\n"`; a trailing `\r` on received lines is
stripped), `timeoutMs` (default `5000`, used by `query`), `schema: { properties, methods }`.

**`schema.properties`**

| Field | Meaning |
|---|---|
| `prefix` | Case-sensitive "line starts with". The rest of the line, trimmed, is the value. `"TEMP: "` matches `TEMP: 25.5`. |
| `match` | A regular expression **string** (no flags), when the line needs structure. Backslashes are doubled inside a JS string: `"^V=([-+]?\\d+(?:\\.\\d+)?)$"`. An invalid regex stops the connector loading. |
| `group` | Capture group holding the value, default `1`; `0` is the whole match. A `match` with no capture group never updates. |
| `type` | `"float"`, `"int"`, `"bool"`, `"string"` (default). `float` tolerates trailing text (`25.5 C` → 25.5); `bool` is true for `1`, `ON`, `TRUE`. A value that fails to parse becomes `null`. |
| `unit`, `description` | Labels. |

Give each property a `prefix` or a `match`; with neither it stays `null`. One line can update
several properties. All schema properties are read-only.

**`schema.methods`** — `{ cmd, arg?, description }`. Sends `cmd` or `cmd + " " + value` plus the
terminator and returns `"OK"`. `bool` arguments are sent as `ON` / `OFF`.

**Built in:** properties `lastLine` (every received line) and `connected`; actions
`send(command)` and `query(command)`. `query` sends a line and returns the **next line received,
whatever it is** — on a device that streams lines unprompted, that may be a streamed line rather
than the answer. Do not name schema methods `send` or `query`.

Received bytes are decoded one byte per character, so only plain ASCII survives intact.

## Protocol: BinaryStream

For devices that exchange binary frames. You describe how to find a frame in the byte stream,
where each field sits in it, and — for request/response devices — the request to send.

**`schema.framing`** — byte strings are hex; spaces, `_` and `-` are ignored (`"01 03 00 00"`).

| Field | Default | Meaning |
|---|---|---|
| `header` | — | Bytes every frame starts with; used to resync. **Never on its own** — combine with `size` or a length field, or no frame is ever delivered. |
| `size` | — | Fixed total frame length in bytes (header included). |
| `lengthOffset`, `lengthWidth` | — | Where the length byte(s) sit. Frame length = `lengthOffset + lengthWidth + <length value>` (+2 with Modbus CRC). Use both or neither. |
| `lengthEndian` | `"little"` | `"little"` or `"big"`. |
| `crc` | `"none"` | `"modbus"` appends a CRC-16 to everything sent and checks it on received frames (only with `size` or length framing). Write commands *without* the CRC. Any other value means none. |
| `quietMs` | `50` | Without `header`, `size` or a length field, a frame ends after this many ms of silence. |
| `request` | — | Hex bytes sent to ask for a fresh frame. Required for devices that only answer when asked (Modbus). |
| `maxStaleMs` | `100` | A read older than this sends `request` again. Set it to at least `200` (the poll interval) for about one request per poll cycle. |

**`schema.properties`**

| Field | Default | Meaning |
|---|---|---|
| `offset` | `0` | Byte offset from the start of the frame, **header included**. |
| `width` | — | Bytes: 1, 2 or 4 (8 for float64). **Required** — without it the value is always 0. |
| `type` | `"uint"` | `"uint"`, `"int"` (two's complement — use it for anything that can go negative), `"float"` (width 4 = float32, 8 = float64), `"bool"`. |
| `endian` | `"little"` | Modbus registers are `"big"`. |
| `scale` | `1` | Multiplier, as a **number** (`0.1`, not `"0.1"`). |
| `unit`, `description` | | Labels. |

Unsigned 4-byte values of 2³¹ and above decode as negative numbers; avoid relying on them. All
schema properties are read-only. Without `request`, a read returns the last frame received;
with it, a stale read sends the request and waits for the reply.

**`schema.methods`** — `{ command, argOffset?, argWidth?, argType?, argEndian?, description }`.
`command` is a hex template; with `argOffset` **and** `argWidth`, the argument is packed into it
at that offset. Arguments are packed as integers only (a float is truncated). Returns `"OK"`.

**Built in:** properties `connected` and `lastFrame` (hex string); actions `sendHex(hex)` and
`queryHex(hex)` (returns the next frame as uppercase hex).

## Using a driver

`driver: "<Name>"` picks a backend that owns its connection. Driver names are case-insensitive.
Each driver has its own `config` options and its own properties and actions; take them from the
driver's reference page or its starter template (shown when the user adds a connector for that
driver in Muxit). **Do not guess option names** — an unknown option is silently ignored.

| Driver | What it is | Reference |
|---|---|---|
| `TestDevice` | Simulated device for trying things out (temperature, counters, streams, video). | [test-device](https://docs.muxit.io/reference/drivers/test-device.md) |
| `Webcam` | USB / built-in camera: live stream, `snapshot()`, recording. | [webcam](https://docs.muxit.io/reference/drivers/webcam.md) |
| `Onvif` | IP camera: stream, snapshot, PTZ. | [onvif](https://docs.muxit.io/reference/drivers/onvif.md) |
| `FileAccess` | Read and write files in a workspace folder. | [file-access](https://docs.muxit.io/reference/drivers/file-access.md) |
| `MqttBridge` | Publish and subscribe to an MQTT broker. | [mqtt-bridge](https://docs.muxit.io/reference/drivers/mqtt-bridge.md) |
| `WebhookNotifier` | HTTP notifications: ntfy, Discord, Slack, generic JSON. | [webhook-notifier](https://docs.muxit.io/reference/drivers/webhook-notifier.md) |
| `EmailNotifier` | E-mail over SMTP. | [email-notifier](https://docs.muxit.io/reference/drivers/email-notifier.md) |
| `LabelPrinter` | Label printing from templates. | [label-printer](https://docs.muxit.io/reference/drivers/label-printer.md) |
| `Virtual` | In-memory store; usually written without a keyword. | [Virtual](#virtual-no-hardware) |
| installed drivers | e.g. `Fairino`, `Avantes`, `AudioSynth`, `Midi`, `Gcode`, `Python` | the driver's own page, or its template |

```js
// workspace/connectors/webcam.js
export default {
  driver: "Webcam",
  config: { device: 0 },                  // option names come from the driver's reference
  ai: { instructions: "Bench camera looking at the fixture." },
};
```

Wrap a driver's raw API in friendlier methods, and use `hide` to keep the raw items out of the
UI and Muxit's AI (they stay callable from scripts):

```js
export default {
  driver: "Fairino",
  config: { ip: "192.168.58.2" },
  hide: ["moveL", "moveJ"],
  methods: {
    moveTo: {
      fn: (x, y, z) => driver.moveL({ pose: [x, y, z, 180, 0, 90] }),
      description: "Linear move to x, y, z in mm, tool pointing down",
    },
  },
};
```

## Engines

An engine processes another connector's output instead of talking to hardware. Name the source
connector with `source`:

```js
export default { engine: "Vision", source: "webcam" };
```

## Virtual (no hardware)

A file with no `driver`, `protocol` or `engine` key — and only the recognised top-level keys —
is an in-memory store. State lives in module-level variables and is lost on restart. Use it for
setpoints a dashboard slider adjusts and a script reads, status text, counters and flags.

```js
// workspace/connectors/store.js
let setpoint = 20;
let status = "Idle";

export default {
  properties: {
    setpoint: { get: () => setpoint, set: (v) => { setpoint = Number(v); }, description: "Target (°C)" },
    status:   { get: () => status,   set: (v) => { status = String(v); },   description: "Status line" },
  },
  methods: {
    reset: [() => { setpoint = 20; status = "Idle"; }, "Back to defaults"],
  },
  poll: ["setpoint", "status"],   // so changes made inside reset() reach dashboards
};
```

A direct write (`store.setpoint = 25` from a script or a dashboard) is broadcast at once. A value
changed *inside a method* is only noticed by polling, hence the `poll` list.

## Custom properties

Computed or wrapped values. Three equivalent forms:

```js
properties: {
  uptime: () => Date.now() - startedAt,                                  // bare getter
  power:  [async () => (await driver.voltage) * (await driver.current),  // [getter, description, options]
           "Output power (W)", { poll: true }],
  target: {                                                              // full form
    get: () => target,
    set: (v) => { target = Number(v); },
    description: "Target temperature (°C)",
    poll: true,
  },
},
```

- **`get` is required.** An entry with only `set` is ignored.
- **No `set` means read-only** in the UI and for Muxit's AI.
- **`poll: true`** (or the name in the top-level `poll: [...]`) re-reads it every 200 ms and pushes
  changes to dashboards. Only poll what a dashboard shows live; every poll runs your getter, and
  every `await driver.x` in it is a device query.
- **Getters run on every read** from a script, dashboard or AI. Keep them quick.
- **There is no `type` or `unit` field.** The type is inferred from the value; put the unit in
  the `description`.
- **Setter writes are queued**: the UI shows the new value at once, the setter runs at most once
  per 100 ms with the latest value, and an error it throws only reaches the server log. Writing
  the value a property already has does nothing.
- A custom property with the **same name as a backend property replaces it** (and the backend
  property is then only polled if you set `poll: true`). Inside it, `driver.<name>` still reaches
  the backend property.

## Custom methods

Helper actions callable as `connector("psu").rampTo(12)`. Three equivalent forms:

```js
methods: {
  home: () => driver.home(),                                        // bare function
  park: [async () => { await driver.send("G0 Z5"); }, "Raise Z"],   // [fn, description]
  rampTo: { fn: (target, stepMs) => rampTo(target, stepMs),          // { fn, description } (or `call`)
            description: "Ramp voltage to target (V) — rampTo(target, stepMs = 100)" },
},
```

**How arguments arrive.** A script call `dev.rampTo(12, 50)` calls `fn(12, 50)`; one argument
arrives as that value; no arguments as `fn()`. A single array is spread: `dev.load([1, 2, 3])`
calls `fn(1, 2, 3)`. **Muxit's AI and MCP clients pass one object** — `{ "target": 12 }` arrives
as `fn({ target: 12 })` — because named arguments are not mapped onto parameters. Accept both:

```js
fn: (target, stepMs) => {
  if (typeof target === "object" && target !== null) ({ target, stepMs } = target);
  return rampTo(Number(target), Number(stepMs ?? 100));
},
```

**How the argument list is shown.** Muxit reads the parameter names from the function source to
show the arguments in the Connectors panel and to Muxit's AI — but only for `function (a, b)`,
`(a, b) =>` and `a =>`. An `async (a) =>` or `async function` shows *no* arguments, and the panel
then runs it with none. So keep the exposed function a plain arrow and put asynchronous work in a
module-level `async function`, as `rampTo` above does. Describe the expected arguments in the
`description` as well.

**Return** a plain value (or nothing). **Throw** `new Error("…")` to fail — the message reaches
the caller. Keep methods short — seconds, not minutes: each call holds the connector's engine,
so other custom calls and custom polls on the same connector wait for it. Long sequences belong in
a [script](https://docs.muxit.io/for-ai/scripts.md).

A method with the same name as a backend action replaces it.

## The `driver` object

Inside getters, setters and methods, `driver` is the backend.

| You write | What happens |
|---|---|
| `await driver.voltage` | Live read from the device (not the poll cache). Without `await` you get a Promise. |
| `driver.voltage = 5` | Starts the write and returns at once; you cannot wait for it, and an error in it is not reported to you. |
| `await driver.reset()` | Calls the action and waits for its result. |
| `driver.foo` (not declared by the backend) | Throws `ReferenceError`. |

- **When a later step depends on a write having happened**, use an action you can await
  instead. On `Scpi`: `await driver.send(\`VOLT ${v}\`)`.
- **Action arguments inside a connector are not mapped to names.** Pass driver actions an object
  with the declared argument names: `await driver.moveL({ pose: [x, y, z] })`. `Scpi`, `LineText`
  and `BinaryStream` also accept a bare value: `await driver.query("SYST:ERR?")`.
- **Calls made through `driver` skip Muxit's safety gate.** A method that writes
  `driver.voltage = 100` is not stopped by `safety.limits`. Check ranges in your own code.
- `driver` holds the backend's names only — never your own custom properties or methods. To
  reuse logic, write a module-level function and call it from both places.

## Globals inside a connector

| Global | Notes |
|---|---|
| `driver` | The backend, above. |
| `log.info(…)`, `log.warn(…)`, `log.error(…)`, `log.debug(…)`; `console.log` / `warn` / `error` | Server log, tagged with the connector name. |
| `await delay(ms)` | Async sleep, **capped at 30 000 ms**. It must be awaited, inside an `async` function. |
| `timestamp()` | ISO 8601 UTC string. |
| `connector(name)` | Another connector — only when listed in `allowedConnectors`. Returns Promises like `driver`. |
| `"$ENV{NAME}"` | A string that is *exactly* this is replaced with the environment variable `NAME` — for API keys and passwords. `"Bearer $ENV{TOKEN}"` is not replaced. |
| `createTcpTransport(host, port, opts)`, `createSerialTransport(path, opts)` | Raw transports, for drivers that take a pre-built `config._transport`. Not needed with `protocol:`. |
| `emit(event, data)` | Publishes `connector:<event>` internally; nothing a script or dashboard can receive yet. |

Plus standard JavaScript (`Math`, `JSON`, `Date`, `Map`, `RegExp`, `Promise`, …). **Not
available:** `setTimeout`, `setInterval`, `fetch`, `require`, `process`, `Buffer`, `eval`, and
the script-only globals `on`, `stream`, `ai`, `say`, `ask` and `script`.

**Top-level code runs at load time without these globals.** The file is evaluated once to read
its configuration before any device exists, so code outside functions must not call `driver`,
`connector`, `log`, `delay` or `timestamp`. Declare variables and helper functions at the top
level; call things only inside getters, setters and methods.

## Talking to other connectors

Connector files are denied access to other connectors unless they list them:

```js
export default {
  driver: "Virtual",
  allowedConnectors: ["psu", "dmm"],
  properties: {
    efficiency: {
      get: async () => {
        const pin = await connector("psu").power;
        const pout = await connector("dmm").power;
        return pin > 0 ? pout / pin : null;
      },
      description: "Output / input power",
    },
  },
};
```

Do not call `connector()` at the top level (other connectors may not be up yet), and do not call
your own connector's custom members through `connector("<self>")` — that waits on itself
forever. Scripts are not subject to `allowedConnectors`.

## Network hosts

`createTcpTransport` may only reach `localhost`, loopback and private addresses (`10.x`,
`172.16–31.x`, `192.168.x`, `169.254.x`). Anything else — a public address, or any other host
*name* — is refused unless:

- the user turns on `security.allowExternalTransports` in `workspace/config/server.json`
  (server-wide), or
- the transport is created inside one of this connector's getters, setters or methods and the
  host is listed in `allowedHosts: ["api.vendor.com"]`. A transport built at the top level, such as
  `config: { _transport: createTcpTransport(…) }`, is created while the file loads, before
  `allowedHosts` applies, so it needs the server-wide setting.

## Visibility: `hide` and `expose`

`hide: ["rawCmd", …]` removes backend or custom items from the Connectors panel, Muxit's AI and
MCP; `expose: [...]` keeps only the listed items. Use one or the other, never both (load error).
Hidden items are still callable from scripts and still polled.

## AI instructions

```js
ai: { instructions: "60 V / 2.5 A bench supply feeding a DUT rated 12 V. Never set more than 13 V. Ask before enabling the output." },
```

Muxit's own assistant sees this next to the device in every conversation. Put safety rules,
units, what the device is connected to, and how to use it there. Keep it to a few sentences.

## Safety

```js
safety: {
  limits:  { voltage: { min: 0, max: 13 }, current: { min: 0, max: 2.5 } },
  confirm: { output: "once", reset: "always" },
  rate:    { voltage: 10 },
},
```

| Key | Meaning |
|---|---|
| `limits` | `{ prop: { min, max, largeChangeFraction? } }`. Writes outside `min`–`max` are blocked (except at the Unrestricted safety level). A change bigger than `largeChangeFraction` (default 0.25) of the range asks for confirmation at the Assisted level. |
| `confirm` | `{ item: "once" \| "always" \| "never" \| "typed" \| "onLargeChange" }` per property or action. `always` / `typed` also mark an action as destructive. Any other value is a load error. |
| `rate` | `{ item: n }` — at most `n` operations per second (in practice rounded up: values below 1 allow one per second). |
| `overrideLevel` | Pin this connector to `"Observe"`, `"Assisted"`, `"Active"` or `"Unrestricted"` regardless of the global level. |

Know the limits of the block:

- **It is enforced only on Muxit's Lab tier.** On other tiers it is ignored (with a warning in the
  server log) and only the global safety level applies. Write it anyway — it documents the safe
  range and protects Lab users — but also check ranges in your own methods and throw.
- It applies to writes and actions coming *into* the connector (scripts, dashboards, AI). Calls
  your own code makes through `driver` are not checked.
- `interlock` and `safeState` are accepted but not enforced yet; do not rely on them.
- Drivers that opt out of the safety gate (Virtual, FileAccess, Webcam, Onvif, WebhookNotifier)
  skip it entirely, so a `safety` block on them does nothing.

## Loading and reloading

Muxit does not watch connector files. After the file is saved, the user clicks **Reload** in the
Connectors panel (or restarts the server). If their workspace has an explicit list of enabled
connectors, a new file starts disabled until they tick it in the Connectors panel. A file that
fails to load shows the error, with a line number, on its card.

## Multi-value replies

When one SCPI query returns several values (`U=12.00 I=0.103 P=1.236`), query once per poll cycle
into a module-level variable and parse it in cheap getters:

```js
let raw = "";
const field = (key) => {
  const m = raw.match(new RegExp(`${key}=([-+]?[\\d.]+(?:[eE][-+]?\\d+)?)`));
  return m ? Number(m[1]) : null;
};

export default {
  protocol: "Scpi",
  connection: { type: "serial", port: "COM3", baudRate: 9600 },
  config: { terminator: "\r\n" },
  properties: {
    reading: { get: async () => (raw = await driver.query("VAL?")), poll: true, description: "Raw VAL? reply" },
    voltage: { get: () => field("U"), poll: true, description: "Voltage (V), parsed from VAL?" },
    current: { get: () => field("I"), poll: true, description: "Current (A), parsed from VAL?" },
  },
};
```

## Complete examples

**SCPI bench supply over LAN**

```js
// workspace/connectors/psu.js
const MAX_V = 30, MAX_A = 3;

async function applySetpoint(volts, amps) {
  if (!(volts >= 0 && volts <= MAX_V)) throw new Error(`voltage must be 0–${MAX_V} V`);
  if (!(amps >= 0 && amps <= MAX_A)) throw new Error(`current must be 0–${MAX_A} A`);
  await driver.send(`APPL ${volts},${amps}`);
  return { volts, amps };
}

export default {
  protocol: "Scpi",
  connection: { type: "tcp", host: "192.168.1.50", port: 5025 },   // ← the user's IP
  config: {
    terminator: "\n",
    timeoutMs: 2000,
    autoConnect: true,
    schema: {
      properties: {
        voltage:          { cmd: "VOLT",       type: "float", unit: "V", description: "Programmed voltage" },
        current:          { cmd: "CURR",       type: "float", unit: "A", description: "Programmed current limit" },
        output:           { cmd: "OUTP",       type: "bool",             description: "Output enable" },
        measured_voltage: { cmd: "MEAS:VOLT?", type: "float", unit: "V", description: "Measured voltage" },
        measured_current: { cmd: "MEAS:CURR?", type: "float", unit: "A", description: "Measured current" },
      },
      methods: {
        save:   { cmd: "*SAV", arg: "int", description: "Save settings to memory slot N" },
        recall: { cmd: "*RCL", arg: "int", description: "Recall settings from memory slot N" },
      },
    },
  },
  properties: {
    power: {
      get: async () => {
        const v = await driver.measured_voltage;
        const i = await driver.measured_current;
        return Math.round(v * i * 1000) / 1000;
      },
      description: "Output power (W), computed",
      poll: true,
    },
  },
  methods: {
    apply: {
      fn: (volts, amps) => {
        if (typeof volts === "object" && volts !== null) ({ volts, amps } = volts);
        return applySetpoint(Number(volts), Number(amps));
      },
      description: "Set voltage (V) and current limit (A) in one step: apply(volts, amps)",
    },
    last_error: [() => driver.query("SYST:ERR?"), "Read the next entry of the error queue"],
  },
  safety: {
    limits:  { voltage: { min: 0, max: MAX_V }, current: { min: 0, max: MAX_A } },
    confirm: { output: "once", apply: "always" },
  },
  ai: { instructions: "Bench PSU, 0–30 V / 0–3 A. Ask before switching the output on or raising the voltage." },
};
```

**Arduino sketch printing text lines**

```js
// workspace/connectors/env_sensor.js — the sketch prints "TEMP: 23.4" and "HUM=41.0%" lines
export default {
  protocol: "LineText",
  connection: { type: "serial", port: "/dev/ttyACM0", baudRate: 115200 },   // ← the user's port
  config: {
    terminator: "\n",
    schema: {
      properties: {
        temperature: { prefix: "TEMP: ", type: "float", unit: "°C", description: "Last temperature line" },
        humidity:    { match: "^HUM=([-+]?\\d+(?:\\.\\d+)?)%?$", type: "float", unit: "%", description: "Last humidity line" },
      },
      methods: {
        set_led: { cmd: "LED", arg: "bool", description: "LED on/off — sends LED ON / LED OFF" },
      },
    },
  },
  ai: { instructions: "Arduino environment sensor. Values are the last line the sketch printed." },
};
```

**Modbus RTU sensor**

```js
// workspace/connectors/th_sensor.js — slave 1, holding registers 0 (temp ×10) and 1 (RH ×10)
export default {
  protocol: "BinaryStream",
  connection: { type: "serial", port: "/dev/ttyUSB0", baudRate: 9600 },
  config: {
    timeoutMs: 1000,
    schema: {
      framing: {
        header: "01 03",                  // slave address + function code of the reply
        lengthOffset: 2, lengthWidth: 1,  // byte count follows the header
        crc: "modbus",
        request: "01 03 00 00 00 02",     // read 2 registers from 0; CRC is appended
        maxStaleMs: 250,
      },
      properties: {
        temperature: { offset: 3, width: 2, type: "int",  endian: "big", scale: 0.1, unit: "°C", description: "Register 0" },
        humidity:    { offset: 5, width: 2, type: "uint", endian: "big", scale: 0.1, unit: "%",  description: "Register 1" },
      },
    },
  },
};
```

## Common mistakes

| Mistake | Instead |
|---|---|
| `const v = driver.voltage; return v * 2;` | `async` getter, `const v = await driver.voltage;` |
| `this.state.x`, `this.driver` | Module-level variables; the `driver` global. |
| `require(…)`, `import fs from "fs"`, `fetch(…)`, `setInterval(…)` | None exist. Polling replaces timers; drivers or connectors replace I/O. |
| The words `require(`, `eval(`, `Function(` in a comment | The loader rejects the file on a text match; reword the comment. |
| `module.exports = …`, `export const …` | One `export default { … }`. |
| Two schema properties with the same `cmd` | One query, parsed — [multi-value replies](#multi-value-replies). |
| A property for a command that has no query form (`*RST`, `OUTP:PROT:CLE`) | A method. |
| `min`, `max`, `scale`, `enum` on a SCPI schema property | `safety.limits`, or custom properties. |
| `scale: "0.1"` on a BinaryStream field | `scale: 0.1` |
| `header` with no `size` or length field | Add `size` or `lengthOffset` + `lengthWidth`. |
| Returning `{ value: 12.1, unit: "V" }` | `12.1`, with the unit in the description. |
| `poll: ["voltage"]` to make a schema property update | Already polled; `poll` is for custom properties only. |
| `driver.myCustomMethod()` | Call a module-level helper function. |
| `async (target) => …` as a method that takes arguments | `(target) => helper(target)` so the arguments are visible. |
| Calling `log`, `driver` or `connector` at the top level | Only inside getters, setters and methods. |
| Long loops inside a method | A script. |
| Relying on `safety` as the only range check | Also validate in your methods. |
| Invented SCPI commands or register maps | From the manual or the user; flag what is unverified. |

## Checklist

- [ ] File `workspace/connectors/<name>.js`, one `export default { … }`, no `import` / `require`,
      and none of `require(`, `import(`, `eval(`, `Function(` anywhere in the text.
- [ ] Exactly one of `protocol` / `driver` / `engine` (or none, for a Virtual store with only
      recognised top-level keys).
- [ ] Protocol connectors have a `connection` block with the right `type` and the user's port,
      host or USB ids — called out as values to check.
- [ ] Every command, line format, register offset and baud rate comes from the manual or the
      user; anything unverified is listed.
- [ ] SCPI schema: one `cmd` per property, `?` only on query-only commands, no unsupported
      fields; commands without a query form are methods.
- [ ] Every getter or method that reads `driver.*` is `async` and `await`s each read.
- [ ] Methods that take arguments are plain arrows (or `function`), accept positional arguments
      *and* a single object, describe their arguments, validate ranges and throw on bad input.
- [ ] No `this`, no timers, no Node or browser APIs, nothing but declarations at the top level.
- [ ] Only properties the user needs, since every readable backend property is polled.
- [ ] `safety.limits` for every setpoint with a known safe range, `confirm` on outputs and
      destructive actions, and `ai.instructions` with the device's safety rules.
- [ ] Other connectors used from this file are in `allowedConnectors`.
- [ ] Told the user to save the file, click **Reload** in the Connectors panel, and enable the
      connector if it shows as disabled.
