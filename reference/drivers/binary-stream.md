---
title: BinaryStream Protocol
description: Reference for the built-in BinaryStream protocol — parse fixed-format binary frames (Modbus-RTU, custom embedded, datalogger output) into typed fields.
---

# BinaryStream

**Built-in [Protocol](https://docs.muxit.io/reference/concepts.md) for fixed-format binary frame devices** — Modbus-RTU slaves, custom embedded sensors, cheap thermometers and dataloggers with a one-byte trigger protocol, any device whose wire format is "bytes with offsets" rather than text. Rides on any streaming [Transport](https://docs.muxit.io/reference/drivers/transport.md) (Serial, TCP). Each inbound frame is sliced according to the declared `framing` and typed fields are read out by byte offset.

Pick `BinaryStream` when the device speaks bytes. Pick [LineText](https://docs.muxit.io/reference/drivers/linetext.md) for newline-delimited ASCII output. Pick [Scpi](https://docs.muxit.io/reference/drivers/scpi.md) for SCPI-compliant lab instruments.

## Quickstart

A Modbus-RTU temperature/humidity sensor with a 2-byte CRC:

```js
// workspace/connectors/sensor.js
export default {
  protocol: "BinaryStream",
  connection: { type: "serial", port: "/dev/ttyUSB0", baudRate: 9600 },
  config: {
    timeoutMs: 1000,
    schema: {
      framing: {
        crc: "modbus",       // CRC16/MODBUS over header+payload, appended on TX and validated on RX
      },
      properties: {
        temperature: { offset: 3, width: 2, type: "int", endian: "big", scale: 0.1, unit: "C" },
        humidity:    { offset: 5, width: 2, type: "int", endian: "big", scale: 0.1, unit: "%" },
      },
      methods: {
        // Read holding registers 0 and 1 from slave address 1
        readSensors: { command: "01 03 00 00 00 02" },
      },
    },
  },
};
```

A silent-until-poked 4-channel thermometer that responds to `A` with 16 fixed bytes:

```js
// workspace/connectors/thermometer.js
export default {
  protocol: "BinaryStream",
  connection: { type: "serial", port: "COM5", baudRate: 9600 },
  config: {
    timeoutMs: 5000,
    schema: {
      framing: {
        size: 16,            // fixed-size frame; no header, no length field
        request: "41",       // protocol auto-sends "A" (0x41) before each poll
      },
      properties: {
        ch1_temp: { offset: 8,  width: 2, type: "uint", endian: "little", scale: 0.1, unit: "C" },
        ch2_temp: { offset: 10, width: 2, type: "uint", endian: "little", scale: 0.1, unit: "C" },
        ch3_temp: { offset: 12, width: 2, type: "uint", endian: "little", scale: 0.1, unit: "C" },
        ch4_temp: { offset: 14, width: 2, type: "uint", endian: "little", scale: 0.1, unit: "C" },
      },
    },
  },
  poll: ["ch1_temp", "ch2_temp", "ch3_temp", "ch4_temp"],
};
```

## Properties

| Property | Type | Access | Description |
|---|---|---|---|
| `connected` | bool | R | Whether the underlying transport is open |
| `lastFrame` | string | R | Most recent received frame as hex |
| *(your `schema.properties.*`)* | typed | R | Last value parsed for each declared field |

Schema-declared properties are **read-only at the protocol level** — they reflect the most recent frame's contents. Polled reads pull from the cache; if `framing.request` is set, polled reads also auto-trigger a fresh frame when the cache is older than `maxStaleMs`.

## Actions

| Action | Args | Description |
|---|---|---|
| `sendHex` | `{ hex: string }` | Send a raw hex-encoded frame. Whitespace is stripped. CRC is appended automatically when `framing.crc` is set. |
| `queryHex` | `{ hex: string }` | Send a frame and return the next received frame as hex. Subject to `timeoutMs`. |
| *(your `schema.methods.*`)* | optional `{ value }` | Each declared method becomes an action that sends a templated frame — see [Methods](#methods). |

## Connection

BinaryStream runs on any streaming transport. See [Transport](https://docs.muxit.io/reference/drivers/transport.md) for the full `connection:` reference.

```js
// Serial — Modbus-RTU, RS-232 sensors, hobby devices
connection: { type: "serial", port: "/dev/ttyUSB0", baudRate: 9600 }

// TCP — Modbus-TCP, network-attached binary protocols
connection: { type: "tcp", host: "192.168.1.50", port: 502 }
```

## Config Options

| Option | Type | Default | Description |
|---|---|---|---|
| `timeoutMs` | int | `5000` | Per-query timeout in ms for `queryHex` and `request`-triggered polled reads. Alias: `timeout`. |
| `schema` | object | — | [Declarative schema](#declarative-schema) — framing rules, field offsets, method templates. |

## Declarative schema

The `schema:` block has three sub-sections: `framing` (how to slice the byte stream into frames), `properties` (how to extract typed fields from each frame), and `methods` (how to assemble frames to send).

### Framing

Framing tells the protocol where each frame starts and ends. **Pick the right knob** — it controls when `queryHex` resolves and how polled reads stay in sync:

| Device shape | Use |
|---|---|
| Vendor docs / wire capture confirm the response is always N bytes | `framing.size: N` |
| Frame includes an explicit length byte at a known offset (Modbus etc.) | `framing.lengthOffset` + `framing.lengthWidth` |
| Cheap meter / thermometer / datalogger that bursts the reply then goes quiet | Omit framing entirely — falls back to inter-frame-gap timing (`quietMs`, default 50 ms) |
| Sync-bytes-then-payload with no length and no fixed size | `framing.header: "AA55"` + `framing.size: N` |
| Device is silent until polled | Add `framing.request: "<hex>"` to any of the above |

```js
config.schema.framing: {
  header:       "AA55",        // optional sync bytes (hex)
  size:         13,            // optional total frame size in bytes
  lengthOffset: 2,             // byte offset of length field
  lengthWidth:  1,             // 1, 2, or 4
  lengthEndian: "little",      // or "big"
  crc:          "modbus",      // "none" | "modbus" — CRC16/MODBUS over header+payload
  quietMs:      50,            // inter-frame-gap fallback (default 50, used only when no header/size/lengthOffset)
  request:      "41",          // hex frame to auto-send before stale reads (turns polled reads into request/response)
  maxStaleMs:   100,           // cache TTL when `request` is set (default 100)
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `header` | hex string | — | Sync magic at the start of each frame. The protocol scans forward to find this before slicing. Whitespace OK (`"AA 55"`). |
| `size` | int | `0` (unset) | Total bytes per frame, including header and CRC. Use when the device emits fixed-size frames with no length field. Takes priority over `lengthOffset`. |
| `lengthOffset` | int | `-1` (unset) | Byte offset where the length field lives. The length value plus this offset (and the optional CRC) determines frame size. |
| `lengthWidth` | int | `0` | Width of the length field in bytes: `1`, `2`, or `4`. |
| `lengthEndian` | enum | `"little"` | `"little"` or `"big"`. |
| `crc` | enum | `"none"` | `"none"` or `"modbus"` (CRC16/MODBUS over header+payload). When set, the protocol appends the CRC on TX and silently drops bad-CRC frames on RX. |
| `quietMs` | int | `50` | Inter-frame-gap fallback in ms. Used **only** when no `header`, `size`, or `lengthOffset` is declared — wait this many ms of silence after the last byte, then deliver the accumulated burst as a single frame. |
| `request` | hex string | — | Hex frame the protocol auto-sends before reads whose cache is older than `maxStaleMs`. Essential for silent-until-poked devices. Coalesces concurrent reads onto a single round-trip. |
| `maxStaleMs` | int | `100` | Cache TTL in ms when `request` is set. Reads older than this trigger a fresh `request` send. |

### Properties

A property reads a typed field from each received frame.

```js
config.schema.properties: {
  temperature: { offset: 4, width: 2, type: "int",   endian: "little", scale: 0.1, unit: "C" },
  state:       { offset: 6, width: 1, type: "uint" },
  voltage:     { offset: 8, width: 4, type: "float", endian: "big",    unit: "V" },
  ready:       { offset: 7, width: 1, type: "bool" },
}
```

| Field | Type | Description |
|---|---|---|
| `offset` | int | Zero-based byte offset from the start of the frame (including header). |
| `width` | int | Field width in bytes. `1`, `2`, or `4` for int/uint; `4` for `float32`; `8` for `float64`; `1` for `bool`. |
| `type` | enum | `"uint"`, `"int"`, `"float"`, or `"bool"`. |
| `endian` | enum | `"little"` or `"big"`. Default `"little"`. Ignored for `width: 1`. |
| `scale` | number | Multiplier applied after raw extraction (`scale: 0.1` turns raw `212` into `21.2`). Default `1`. |
| `unit` | string | Display unit. Never coerces the value. |
| `description` | string | One-line description for IntelliSense and AI prompts. |
| `details` | string | Optional long-form markdown. |

### Methods

A method packs a single argument into a frame template and sends it.

```js
config.schema.methods: {
  setBrightness: { command: "AA55 03 04 01 00", argOffset: 4, argWidth: 1, argType: "uint" },
  reset:         { command: "AA55 02 03 FF" },                                                // no arg
}
```

| Field | Type | Description |
|---|---|---|
| `command` | hex string | Frame template. Whitespace OK. CRC is appended automatically when `framing.crc` is set — do NOT include it in the template. |
| `argOffset` | int | Where in the frame to pack the argument. Omit for no-arg methods. |
| `argWidth` | int | Argument width in bytes. |
| `argType` | enum | `"uint"`, `"int"`, `"float"`, or `"bool"`. |
| `argEndian` | enum | `"little"` or `"big"`. Default `"little"`. |
| `description` | string | One-line description. |
| `details` | string | Optional long-form markdown. |

## Diagnostics

For unknown binary protocols, three AI tools work in sequence — see [AI Tools](https://docs.muxit.io/reference/ai-tools.md):

1. **`probe_stimulus`** — find which byte(s) the device responds to, and how many bytes come back. Returns `bestLabel`, `sentHex`, `receivedBytes`, `receivedHex`. Drop the result straight into `framing.request:` and `framing.size:`.
2. **`analyze_binary_frame`** — given a captured frame and 1-3 values from the device's display, exhaustively tries every (offset, width, type, endian, scale) decoding and returns paste-ready `schemaHint` snippets ranked by fit. Handles ambiguity detection (uint8 vs uint16 LE when high bytes are 0x00) and multi-sample disambiguation.
3. **`open_transport` / `queryHex` / `read_from_transport`** — manual capture when you want to inspect the bytes yourself.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `queryHex` returns fewer bytes than expected | No `header` / `size` / `lengthOffset` set, and the device drip-feeds the response over multiple chunks | Set `framing.size: N` if you know the response length, or rely on `framing.quietMs` (default 50 ms) for inter-frame-gap detection. |
| Polled properties stay null | Device is silent until poked, and no `framing.request` is set | Add `framing.request: "<hex>"` so the protocol auto-triggers on stale reads. |
| Values readable but wrap at 25.5 (or another power of 10) | Decoded as `uint8 × 0.1` when device actually uses `uint16 little × 0.1` (current values fit in 8 bits, high bytes are `0x00`) | Change `width: 1` to `width: 2` and `endian: "little"` on the affected properties. The `analyze_binary_frame` tool auto-prefers uint16 in this pattern. |
| Frame validates intermittently with `crc: "modbus"` | A spurious noise byte at the start of the buffer is causing the CRC check to fail; the protocol re-syncs one byte at a time | This is normal — bad-CRC frames are dropped and the next valid frame is delivered. No action needed unless ALL frames fail, in which case the framing or CRC variant is wrong. |

See also the [Protocol Authoring guide](https://docs.muxit.io/guides/protocol-authoring.md) for the end-to-end onboarding flow.
