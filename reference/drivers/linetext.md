---
title: LineText Protocol
description: Reference for the built-in LineText protocol — parse text-line streams (Arduino sketches, hobby PSUs, custom embedded devices) into typed properties.
---

# LineText

**Built-in [Protocol](https://docs.muxit.io/reference/concepts.md) for newline-delimited text streams** — Arduino sketches, hobby PSUs, datalogger output, any device that prints lines you could read in a serial terminal. Rides on any streaming [Transport](https://docs.muxit.io/reference/drivers/transport.md) (Serial, TCP). Each inbound line is matched by `prefix` or `match` (regex) against your declared properties and parsed into a typed value; methods send formatted text commands.

Pick `LineText` when the device emits output like `TEMP: 25.5\n` or `STATE READY\n` or any other one-line-per-event format. Pick [BinaryStream](https://docs.muxit.io/reference/drivers/binary-stream.md) instead when the wire format is fixed-width binary frames; pick [Scpi](https://docs.muxit.io/reference/drivers/scpi.md) for instruments that speak the SCPI standard.

## Quickstart

```js
// workspace/connectors/arduino-sensors.js
export default {
  protocol: "LineText",
  connection: { type: "serial", port: "/dev/ttyUSB0", baudRate: 115200 },
  config: {
    terminator: "\n",
    schema: {
      properties: {
        temperature: { prefix: "TEMP: ",                  type: "float", unit: "C" },
        pressure:    { match:  "^PRES (\\d+(?:\\.\\d+)?)", type: "float", unit: "kPa", group: 1 },
        state:       { prefix: "STATE: ",                 type: "string" },
      },
      methods: {
        setLed: { cmd: "LED",    arg: "bool" },   // setLed(true)  → "LED ON\n"
        reset:  { cmd: "RST" },                   // reset()       → "RST\n"
      },
    },
  },
};
```

## Properties

| Property | Type | Access | Description |
|---|---|---|---|
| `lastLine` | string | R | Most recent line received (unparsed, terminator stripped) |
| `connected` | bool | R | Whether the underlying transport is open |
| *(your `schema.properties.*`)* | typed | R | Last value parsed for each declared line shape |

Schema-declared properties are **read-only at the protocol level** — they always reflect the most recent line that matched their `prefix` or `match`. If you need to *query* a device that only responds when polled, declare the property without a prefix and use the `query` action from a custom getter in the connector's top-level `properties:` block.

## Actions

| Action | Args | Description |
|---|---|---|
| `send` | `{ command: string }` | Send a raw command with the configured terminator appended |
| `query` | `{ command: string }` | Send a command and return the next inbound line as the response (subject to `timeoutMs`) |
| *(your `schema.methods.*`)* | per-method | Each declared method becomes an action — see [Methods](#methods) below |

## Connection

LineText runs on any streaming transport. See [Transport](https://docs.muxit.io/reference/drivers/transport.md) for the full `connection:` block reference.

```js
// Serial
connection: { type: "serial", port: "/dev/ttyUSB0", baudRate: 115200 }

// TCP (network-attached embedded devices, ESP32 over Wi-Fi, …)
connection: { type: "tcp", host: "192.168.1.42", port: 23 }
```

## Config Options

| Option | Type | Default | Description |
|---|---|---|---|
| `terminator` | string | `"\n"` | Line terminator for both inbound parsing and outbound sends. Common alternatives: `"\r\n"` (Windows-style), `"\r"` (older firmware). |
| `timeoutMs` | int | `5000` | Timeout for the `query` action and any awaited response. Alias: `timeout`. |
| `schema` | object | — | [Declarative schema](#declarative-schema) — property line-shapes and method command templates. |

## Declarative schema

The `schema:` block under `config:` declares which line shapes the protocol should recognise as properties and which text commands it should expose as methods. No JS in the connector body needed — the protocol synthesises everything from the data.

### Properties

A property tells the protocol how to recognise an incoming line and where to find the value inside it.

```js
config.schema.properties: {
  temperature: { prefix: "TEMP: ",                  type: "float", unit: "C" },
  pressure:    { match:  "^PRES (\\d+(?:\\.\\d+)?)", type: "float", unit: "kPa", group: 1 },
  state:       { prefix: "STATE: ",                 type: "string" },
}
```

| Field | Type | Description |
|---|---|---|
| `prefix` | string | Case-sensitive starts-with match. The remaining text after the prefix is parsed as `type`. Pick this when lines have a fixed leading label (`TEMP: 25.5`). |
| `match` | string (regex) | Regex applied to the whole line. The capture group named by `group` (default `1`) is parsed as `type`. Pick this for no-delimiter formats (`TEMP=25.5`) or anything that needs structured extraction. |
| `group` | int | Which regex capture group to extract when using `match`. Default `1`. |
| `type` | enum | `"float"`, `"int"`, `"bool"`, or `"string"`. Coerces the extracted text into the typed value. |
| `unit` | string | Display unit, e.g. `"C"`, `"kPa"`, `"V"`. Surfaces in dashboards and tooltips; never coerces the value. |
| `description` | string | One-line description shown in IntelliSense and AI prompts. |
| `details` | string | Optional long-form markdown shown on demand (parameter enums, side effects, etc.). |

Exactly one of `prefix` or `match` must be set per property. Lines that don't match any declared shape are stored in `lastLine` and ignored otherwise.

### Methods

A method is a one-shot text command. The protocol appends `terminator` and writes to the wire — no response handling; for command-then-response use the built-in `query` action instead.

```js
config.schema.methods: {
  setLed: { cmd: "LED",    arg: "bool" },   // setLed(true)  → "LED ON\n"
  reset:  { cmd: "RST" },                   // reset()       → "RST\n"
  bright: { cmd: "BRIGHT", arg: "int"  },   // bright(80)    → "BRIGHT 80\n"
}
```

| Field | Type | Description |
|---|---|---|
| `cmd` | string | Command text. The protocol appends the formatted argument (when `arg` is set) and the configured terminator. |
| `arg` | enum | `"int"`, `"float"`, `"bool"`, `"string"` — or omit for a no-arg command. Booleans render as `ON`/`OFF`. |
| `description` | string | One-line action description. |
| `details` | string | Optional long-form markdown. |

## Pacing and request/response

LineText does not maintain a request queue or response cache between calls. Two patterns:

- **Continuous emission.** The device prints lines on its own; declared properties update as soon as a matching line arrives. No polling needed — just consume the values.
- **Polled request/response.** Call `c.query({ command: "TEMP?" })` to send a command and block until the next inbound line, subject to `timeoutMs`. The response is returned to your script verbatim (terminator stripped).

If you need a polled property that fires a query on every read, declare the polled raw response as a schema property and add a custom JS getter in the connector's top-level `properties:` block — see the [Connector authoring guide](https://docs.muxit.io/guides/connectors.md) for the pattern.

## Diagnostics

When the AI is helping you draft a LineText connector, two tools see the most use:

- `read_from_transport` — capture a few seconds of inbound bytes and check whether the device emits text lines on its own or only after a poke. The captured `text` and `lines` fields reveal the line shapes you should declare as properties.
- `probe_stimulus` — for silent-until-poked devices, find the trigger byte / sequence that makes the device respond. See [AI Tools](https://docs.muxit.io/reference/ai-tools.md).

See also the [Protocol Authoring guide](https://docs.muxit.io/guides/protocol-authoring.md) for the end-to-end onboarding flow.
