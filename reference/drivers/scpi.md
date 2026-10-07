---
title: Scpi Protocol
description: Reference for the built-in Scpi protocol — query/send any SCPI-compliant instrument over USBTMC, Serial, or TCP/IP, with framing, pacing, and the declarative `schema` block.
---

# Scpi

**Built-in [Protocol](https://docs.muxit.io/reference/concepts.md) for SCPI-compliant instruments** — oscilloscopes, multimeters, function generators, power supplies, spectrum analyzers. Rides on USBTMC (direct USB-B), Serial (RS-232 / USB-to-serial), or TCP/IP (LXI, raw socket port 5025), and exposes raw query/send plus a handful of convenience actions (`*IDN?`, `*RST`, `MEAS?`, error-queue drain, …). Device-specific properties and methods belong in the connector's `schema` block — Scpi handles the wire, not the instrument.

The canonical name in catalog and connector files is `Scpi`. The legacy name `GenericScpi` (used by older connectors when SCPI shipped as a separate DLL extension) is recognised as an alias — existing connector files keep loading unchanged.

## Quickstart

```js
// workspace/connectors/dut.js
export default {
  protocol: "Scpi",
  connection: { type: "tcp", host: "192.168.1.50", port: 5025 },
  config: {
    autoConnect: true,
    schema: {
      properties: {
        voltage:          { cmd: "VOLT",       type: "float", unit: "V" },
        measured_voltage: { cmd: "MEAS:VOLT?", type: "float", unit: "V" },
      },
      methods: {
        beep: { cmd: "SYST:BEEP" },
      },
    },
  },
};
```

Swap the `connection:` block for whichever transport your instrument uses — see [Connection](#connection) below.

## Properties

| Property | Type | Access | Description |
|---|---|---|---|
| `connected` | bool | R | Whether the transport is currently open |
| `identity` | string | R | Most recent `*IDN?` response |
| `transport` | string | R | `"tcp"`, `"serial"`, or `"usbtmc"` |
| `lastCommand` | string | R | Last command sent (helpful for debugging) |
| `lastResponse` | string | R | Last response received |
| `queryCount` | int | R | Total queries executed since init |
| `errors` | string[] | R | Error-queue snapshot (populated by `readErrors`) |

## Actions

| Action | Args | Description |
|---|---|---|
| `connect` | — | Open the transport and query `*IDN?` |
| `disconnect` | — | Close the transport |
| `identify` | — | Query `*IDN?` again (refreshes `identity`) |
| `reset` | — | Send `*RST` |
| `clear` | — | Send `*CLS` (clear status) |
| `query` | `{ command: string }` | Send a SCPI query and return the trimmed line response |
| `send` | `{ command: string }` | Send a SCPI command (no response expected) |
| `readErrors` | — | Drain `SYST:ERR?` into the `errors` queue (max 20) |
| `opc` | — | Query `*OPC?` |
| `stb` | — | Query `*STB?` (parsed as int when possible) |
| `measure` | `{ function: string }` | Shorthand for `MEAS:<function>?` — parses numeric responses |

## Streams

| Stream | Format | Rate | Description |
|---|---|---|---|
| `scpi` | text | per-transaction | Timestamped TX/RX log, only emitted when `debug: true` |

## Connection

The `connection:` block (top-level, sibling to `config:`) tells Scpi which Transport to use and how to reach the device. Pick one of three:

| `type` | Required fields | Optional |
|---|---|---|
| `"tcp"` | `host`, `port` (default `5025`) | — |
| `"serial"` | `port` (path: `"COM5"`, `"/dev/ttyUSB0"`, …), `baudRate` (default `9600`) | `dataBits`, `stopBits`, `parity`, `flowControl` |
| `"usbtmc"` | `vendorId`, `productId` (both `0xNNNN` literals or decimal ints) | `serial` (SN filter), `interfaceNumber`, `endpointNumber` |

```js
// TCP / LXI
connection: { type: "tcp",    host: "192.168.1.50",   port: 5025 }

// Serial (RS-232, USB-to-serial)
connection: { type: "serial", port: "/dev/ttyUSB0",   baudRate: 9600 }

// Serial with XON/XOFF software flow control (Hameg HM8115, older R&S/Tek)
connection: { type: "serial", port: "/dev/ttyUSB0",   baudRate: 9600, flowControl: "xon-xoff" }

// USBTMC (direct USB-B port — Rigol DS1000Z, Keysight DSO-X, etc.)
connection: { type: "usbtmc", vendorId: 0x1AB1, productId: 0x04CE }
```

## Config Options

| Option | Type | Default | Description |
|---|---|---|---|
| `terminator` | string | `"\n"` | Line terminator for both TX and RX |
| `timeoutMs` | int | `5000` | Query timeout in milliseconds (alias: `timeout`) |
| `autoConnect` | bool | `false` | Connect during init and query `*IDN?` |
| `commandIntervalMs` | int | `0` | Minimum ms between consecutive SCPI operations. Set this for slow serial instruments that can't keep up with back-to-back commands. Default 0 = no pacing. |
| `unreachableRetryMs` | int | `5000` | How often to re-probe an instrument that has stopped responding. See [Unresponsive instruments](#unresponsive-instruments). |
| `schema` | object | — | [Declarative schema](#declarative-schema): auto-synthesizes properties and methods from a `{ cmd, type, … }` map so the connector stays short. Legacy connectors can use `scpi:` instead — the protocol accepts both keys. |

### Legacy config compatibility

Older connectors with `driver: "GenericScpi"` and the flat
`config.transport` / `config.host` / `config.serialPort` / `config.vendorId`
shape **still load**: the connector loader translates the legacy fields into a
`connection:` block at parse time, and `GenericScpi` resolves to the built-in
`Scpi` protocol via a catalog alias.

| Legacy field | Now goes into |
|---|---|
| `config.transport` | `connection.type` |
| `config.host`, `config.port` | `connection.host`, `connection.port` |
| `config.serialPort`, `config.baudRate` | `connection.port`, `connection.baudRate` |
| `config.vendorId`, `config.productId`, `config.serial` | `connection.vendorId`, `connection.productId`, `connection.serial` |
| `config.commandDelay` / `config.settleMs` | `config.commandIntervalMs` (max of the two) |
| `config.initCommands`, `config.debug` | dropped with a stderr warning — file an issue if you need them back |

New connectors should use the `protocol: "Scpi"` + `connection:` shape directly. The legacy shape is supported indefinitely for back-compat but isn't recommended for new code.

## Declarative Schema

Most SCPI connectors repeat the same pattern: `cmd: "VOLT"` for set, `cmd: "VOLT?"` for read, `parseFloat` on the response, `Number(value)` on the way out. The `config.schema` block collapses all of that into a single declaration — the protocol synthesizes the get/set/dispatch at init time and exposes them through the normal property/action pipeline.

```javascript
{
    protocol: "Scpi",
    connection: { type: "tcp", host: "192.168.1.50", port: 5025 },
    config: {
        autoConnect: true,

        schema: {
            properties: {
                voltage:          { cmd: "VOLT",       type: "float", unit: "V", description: "Programmed voltage" },
                current:          { cmd: "CURR",       type: "float", unit: "A" },
                output:           { cmd: "OUTP",       type: "bool" },
                measured_voltage: { cmd: "MEAS:VOLT?", type: "float", unit: "V" }, // read-only
            },
            methods: {
                local: { cmd: "SYST:LOC",  description: "Return to local control" },
                beep:  { cmd: "SYST:BEEP" },
                save:  { cmd: "*SAV", arg: "int", description: "Save to memory slot (c.save(N) → *SAV N)" },
            },
        },
    },
}
```

(Connectors written before the protocol rework use `scpi:` instead of `schema:` — both are accepted.)

### Property entries

Each `schema.properties.<name>` entry accepts:

| Field | Type | Description |
|---|---|---|
| `cmd` | string | Base SCPI command, e.g. `"VOLT"`. Trailing `?` marks the property read-only (`"MEAS:VOLT?"` → only a query is issued). |
| `type` | `"float"` \| `"int"` \| `"bool"` \| `"string"` | Response parser and write-formatter. Bool normalises `"1"`/`"ON"`/`"TRUE"` on read and sends `ON`/`OFF` on write. |
| `unit` | string | Optional unit label surfaced in the schema and UI. |
| `description` | string | Optional human-readable description. |
| `readonly` | bool | Explicitly mark read-only (same effect as a `?` suffix on `cmd`). |

On write, the driver sends `{cmd} {value}` (e.g. `c.voltage = 5` → `VOLT 5`). On read, it sends `{cmd}?` and parses the response per `type`. Numeric parsers throw on NaN/Infinity so the transport's one-retry path kicks in — no garbled values leak into the state store.

### Method entries

Each `schema.methods.<name>` entry accepts:

| Field | Type | Description |
|---|---|---|
| `cmd` | string | SCPI command to send when the method is invoked. |
| `arg` | `"int"` \| `"float"` \| `"bool"` \| `"string"` \| `{ name, type }` | Optional argument appended to `cmd` as `{cmd} {value}`. Omit for a no-arg method. |
| `description` | string | Optional description. |

A declared method sends its command fire-and-forget (no response). If you need a query-and-parse method, write it by hand in the top-level `methods` block using `c.query({ command })`.

### Precedence & overrides

Top-level `properties.<name>` and `methods.<name>` in the connector config **override** any declared entry with the same name. Use this to keep the declarative form for the regular cases and hand-write the quirks:

```javascript
config: {
    schema: {
        properties: {
            voltage: { cmd: "VOLT", type: "float", unit: "V" },
        },
    },
},
properties: {
    // Override: this instrument prefixes the value with "V:"
    voltage: {
        get: async () => parseFloat((await driver.query({ command: "VOLT?" })).replace(/^V:/, "")),
        set: (v) => driver.send({ command: `VOLT ${Number(v)}` }),
    },
},
```

Declared properties are polled at the same default rate as any other driver property. If you need an un-polled property, declare it in the top-level `properties` block instead (where `poll: false` is the default).

## Framing & Recovery

SCPI over raw sockets (and serial) has no built-in request/response pairing — a late reply from a timed-out query can shift every subsequent answer by one and the driver ends up returning "object [0]" / NaN for every read. This driver defends against that in three places:

1. **Drain-before-write.** Every transaction discards any inbound bytes currently buffered before sending the command. Prevents a stale push or status prompt from being consumed as the response.
2. **Auto-resync on failure.** If a query times out, fails to parse, or returns an empty line, the transport flips a `_needsResync` flag. The next transaction performs an aggressive drain before sending, so the late reply is swallowed instead of mis-attributed.
3. **One-shot retry.** `query` catches `TimeoutException` / `InvalidOperationException` once and re-issues the command with the now-clean RX buffer. Retries are not silent for arbitrary errors — only for the two recoverable ones.

## Unresponsive Instruments

Queries are serialized on one I/O lock so replies can't interleave. That means
a powered-off or unplugged instrument used to cost the *sum* of its properties'
timeouts every poll cycle — a 5-property PSU at the default 5 s timeout tied up
the wire for 25 s at a time, long enough that reloading or disabling the
connector looked like a hang.

A breaker now short-circuits that. Once an instrument has missed **two replies
in a row** it is marked unreachable, with one line in the log:

```
SCPI device on serial COM5@9600 stopped responding — pausing queries, probing every 5000ms
```

While the breaker is open, queries fail immediately with a
`Device not responding on …` error instead of waiting out a timeout, so polls,
scripts, and connector reload all stay responsive. Every `unreachableRetryMs`
exactly one query is let through as a probe; the first successful reply closes
the breaker and normal polling resumes:

```
SCPI device on serial COM5@9600 responded — resuming normal queries
```

Notes:

- It takes two consecutive misses, not one. A single late reply — a slow
  instrument, a connection still settling — is a normal event and doesn't mute
  the connector. A device that is genuinely gone misses every reply, so it still
  trips on the second one.
- The `*IDN?` sent by `autoConnect` and by the `connect` action never counts
  toward that. It races the transport handshake, so a miss there says nothing
  about the instrument.
- Only queries are gated. Fire-and-forget writes (`psu.voltage = 12`, `c.send(…)`)
  don't wait for a reply and are never short-circuited.
- Explicit `connect` / `disconnect` reset the breaker, so reconnecting always
  gets a clean attempt rather than waiting out the retry window.
- Set `unreachableRetryMs: 0` to probe on every query — useful for an instrument
  that drops off the bus briefly and you'd rather pay the timeouts than miss a
  sample.

## Write Coalescing

Declared-schema property writes (`psu.voltage = 12`) funnel through a per-property "latest pending value" map drained by a single background pump. Rapid repeat writes to the same property — typical of a dashboard knob drag from 0 V to 20 V — collapse to one wire-level command per pump cycle: only the *latest* value reaches the instrument. Distinct properties stay in FIFO order, so `output = true; voltage = 20` always sends `OUTP ON` before `VOLT 20`.

The crucial detail: the pump samples the property's latest value **after** the transport has acquired its lock and waited out `commandIntervalMs`. So `commandIntervalMs` doubles as the coalescing window — bigger window, more aggressive coalescing. With `commandIntervalMs: 1000`, dragging a knob from 0 V to 20 V sends `VOLT 0` immediately (first command, no wait), then exactly one `VOLT 20` a second later regardless of how many intermediate moves the knob produced. With `commandIntervalMs: 50` you'll see a few intermediate steps; with `0` (the default) the pump runs flat-out and only coalesces what the wire physically can't keep up with.

Latest-wins is safe for transient toggles: if you set `output = true` then immediately `output = false`, only `OUTP OFF` is sent — which matches what the user asked for. Direct `c.send({ command })` calls and declared methods (`c.beep()`, `c.save(3)`) bypass coalescing entirely and execute in the order they were called.

## USBTMC

USBTMC (USB Test &amp; Measurement Class) is the USB-native protocol that most modern bench instruments use for their front-panel USB-B port — Rigol DS1000Z/MSO5000, Keysight DSO-X, Siglent SDG/SSA/SDS, Owon, most R&amp;S. It's not a virtual COM port; the instrument exposes bulk USB endpoints and a small class-specific control channel, and the driver wraps every SCPI line in a USBTMC message header before sending.

```javascript
{
    protocol: "Scpi",
    connection: {
        type: "usbtmc",
        vendorId:  0x1AB1,   // Rigol — find yours with the commands below
        productId: 0x04CE,
        // serial: "DS1ZA1234567890",   // optional, only if you have multiple of the same model
    },
    config: {
        autoConnect: true,
        terminator: "\n",
    },
}
```

### Finding VID/PID

Open **Device Manager → your instrument → Properties → Details tab → Hardware Ids**, formatted as `USB\VID_vvvv&PID_pppp`. The AI chat's `list_usbtmc_devices` tool also enumerates attached USBTMC endpoints with their VID/PID.

### Platform setup

USBTMC instruments on Windows typically ship with a vendor driver (NI-VISA, Keysight IO Libraries Suite, Rigol's USB driver). Those drivers bind exclusively and block libusb. You have two options:

1. **Replace the driver with WinUSB** using [Zadig](https://zadig.akeo.ie/). Select your instrument, pick **WinUSB**, click *Replace Driver*. This is a one-time operation but it will break the vendor's own software. Reversible via Device Manager → Uninstall → rescan.
2. **Stick with TCP** if the instrument has a LAN port. Most Keysight, Rigol, and Siglent gear supports raw socket on :5025 over Ethernet with no driver drama.

### What's implemented

The driver speaks the base USBTMC protocol defined in USB-IF USBTMC rev 1.00 — enough for SCPI read/write against every mainstream instrument:

- `DEV_DEP_MSG_OUT` framing (Bulk-OUT) for writes, with 4-byte payload alignment and `EOM = 1`.
- `REQUEST_DEV_DEP_MSG_IN` + `DEV_DEP_MSG_IN` framing (Bulk-OUT request, Bulk-IN response) for reads, with multi-transfer accumulation until the terminator appears or `EOM` is set.
- `INITIATE_CLEAR` / `CHECK_CLEAR_STATUS` control transfers on connect to put the device in a known state.
- `INITIATE_ABORT_BULK_IN` control transfer during drain-before-write recovery.

USB488 extensions (SRQ on the interrupt endpoint, REN/GTL control requests, serial-poll status byte via the INTR-IN pipe) are **not** implemented yet — `*STB?` still works because it's a regular SCPI query that rides the normal Bulk-IN path.

## Example Connector

```javascript
// workspace/connectors/psu.js — BK Precision 9115 over serial
export default {
    protocol: "Scpi",
    connection: { type: "serial", port: "COM5", baudRate: 9600 },

    ai: {
        instructions: "Benchtop PSU — confirm before changing output state or voltage above 30 V.",
    },
    config: {
        terminator: "\n",
        timeoutMs: 2000,
        commandIntervalMs: 40,   // this PSU is slow — pace between commands
        autoConnect: true,

        // Declarative schema — protocol synthesizes voltage/current/output
        // properties and the small "send a fixed command" methods.
        schema: {
            properties: {
                voltage:          { cmd: "VOLT",       type: "float", unit: "V" },
                current:          { cmd: "CURR",       type: "float", unit: "A" },
                output:           { cmd: "OUTP",       type: "bool" },
                measured_voltage: { cmd: "MEAS:VOLT?", type: "float", unit: "V" },
                measured_current: { cmd: "MEAS:CURR?", type: "float", unit: "A" },
            },
            methods: {
                local: { cmd: "SYST:LOC" },
                beep:  { cmd: "SYST:BEEP" },
                save:  { cmd: "*SAV", arg: "int" },
            },
        },
    },

    poll: ["voltage", "current", "output", "measured_voltage", "measured_current"],

    methods: {
        on:  [() => { driver.output = true;  }, "Enable output"],
        off: [() => { driver.output = false; }, "Disable output"],
    },

    properties: {
        // Computed power — pure JS on top of declared props
        power: {
            get: async () => Math.round((await driver.measured_voltage) * (await driver.measured_current) * 1000) / 1000,
            description: "Calculated output power (W)",
        },
    },
};
```

The more generic starter lives in the driver's `template.js` and picks up whichever transport you configure.

## Example Script

```javascript
const psu = connector("psu");

psu.on();
psu.voltage = 12.0;
psu.current = 0.5;

await delay(500);
log.info(`Output: ${psu.measured_voltage.toFixed(3)} V @ ${psu.measured_current.toFixed(3)} A`);

psu.off();
```

## Troubleshooting

- **`Empty SCPI response for query: …`** — the instrument isn't replying to this verb. Check it's SCPI-compliant, and that the terminator matches the device (some use `\r\n`, a few use `\r` alone). You can also watch the raw traffic by setting `debug: true` and opening the **scpi** stream in a Terminal widget.
- **Every reading "by one" off** — almost always a stale reply from a previous timed-out query. The auto-resync should catch this on the next transaction; if not, raise `commandIntervalMs` (20–50 ms) to slow the transaction rate, or increase `timeout` so the original query has time to finish cleanly.
- **Set-then-query returns the old value** — raise `commandIntervalMs` (10 ms or more). The driver enforces that gap between any two consecutive transactions, so the instrument has time to apply the setpoint before the next query goes out.
- **USBTMC: "No USB device matched vendorId=… productId=…"** — the instrument isn't visible to libusb. The vendor driver is probably still bound — use Zadig to switch to WinUSB.
- **USBTMC: "Failed to open the USB device"** — another process (vendor utility, NI-VISA, a stale Muxit session) is holding the device. Close any other SCPI tools and try again.
- **`Device not responding on serial … — '…' skipped`** — the breaker is open: the instrument stopped answering and Muxit is probing rather than waiting out a timeout per property. Check power and cabling; polling resumes on its own once the device replies. See [Unresponsive instruments](#unresponsive-instruments).
- **`Not connected`** — `autoConnect: false` is the default. Either flip it on, or call `connect` from the UI / a startup script.
