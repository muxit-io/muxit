---
title: Concepts — Driver, Protocol, Engine
description: What the three catalog kinds mean and which one to pick when adding a device to Muxit.
---

# Driver, Protocol, Engine

Muxit's marketplace splits everything you can install into three kinds.
The split exists for one reason: **what you need to provide is different
for each.** Pick the one that matches your situation and the rest of the
setup follows.

| Kind | What it is | What *you* provide in the connector | Examples |
|---|---|---|---|
| **Driver** | A turnkey integration that owns its wire. Most installs. | Just the connection details (IP, port path, credentials). | Webcam, MqttBridge, Fairino robot SDK, Avantes spectrometer, EmailNotifier |
| **Protocol** | A reusable wire-format parser. Doesn't know about your specific device — you tell it what the bytes mean. | A `connection:` block (which transport) **plus** a `schema:` block (which commands / lines / frames to expect). | Scpi, LineText, BinaryStream |
| **Engine** | Compute that processes data from *other* connectors. No wire of its own. | A `source:` pointing at another connector. | Vision (processes camera frames) |

You see this in the marketplace as the **Devices** and **Engines** tabs.
Drivers and Protocols both produce device-shaped connectors and live
together in the Devices tab — Protocols carry a small `protocol` chip
so you can tell them apart at a glance. Engines get their own tab
because they're a different mental category: they don't connect to
hardware, they connect to other connectors.

## The full picture — five concepts

The marketplace shows three kinds because that's what you *pick*. Under
the hood there are two more, which you'll see in connector files and
in the [reference docs](https://docs.muxit.io/reference/drivers/transport.md):

| Concept | Role | Where it shows up |
|---|---|---|
| **[Transport](https://docs.muxit.io/reference/drivers/transport.md)** | Moves bytes over one channel (serial / TCP / USBTMC). Has no opinion about what the bytes mean. | The `connection: { type, ... }` block in every connector that uses a Protocol. Always C# — Transports are part of the server. |
| **Protocol** | Wire-language parser. Rides on a Transport. | The `protocol: "..."` keyword in the connector. Examples: [Scpi](https://docs.muxit.io/reference/drivers/scpi.md), [LineText](https://docs.muxit.io/reference/drivers/linetext.md), [BinaryStream](https://docs.muxit.io/reference/drivers/binary-stream.md). |
| **Driver** | Self-contained backend that owns its connection (vendor SDK, OS handle, embedded TCP). | The `driver: "..."` keyword. Examples: Webcam, MqttBridge, Fairino. |
| **Engine** | Compute over data from other connectors. | The `engine: "..."` keyword. Examples: Vision. |
| **Connector** | The runtime instance — your `workspace/connectors/<name>.js` file. Picks exactly one of `protocol:` / `driver:` / `engine:` — or none, for an in-memory [Virtual](https://docs.muxit.io/reference/drivers/virtual.md) connector. | Every file under `workspace/connectors/`. |

Exactly one of `protocol:` / `driver:` / `engine:` per connector — that's
the choice the marketplace tabs help you make. The Transport is part of
the connector's `connection:` block when you pick a Protocol; Drivers
and Engines own their connection internally.

There is one deliberate exception: a connector that talks to **nothing
at all**. Leave the keyword out and, as long as every top-level key is a
standard connector key, the file resolves to the built-in
[Virtual](https://docs.muxit.io/reference/drivers/virtual.md) driver — an in-memory store for values,
computed properties and methods that dashboards and scripts share.

## Which one do you want?

### "I have a benchtop instrument that speaks SCPI"

Use the **Scpi protocol**. It rides on TCP (LXI), USB (USBTMC), or
serial — pick the right transport in `connection:` and declare the
specific SCPI commands your instrument uses in `schema:`.

```js
export default {
  protocol: "Scpi",
  connection: { type: "tcp", host: "192.168.1.50", port: 5025 },
  config: {
    schema: {
      properties: {
        voltage: { cmd: "VOLT", type: "float", unit: "V" },
      },
    },
  },
};
```

### "I have an Arduino sketch that prints `TEMP: 25.5` every second"

Use the **LineText protocol**. Declare the prefix or regex that catches
your lines and the type to parse them as.

```js
export default {
  protocol: "LineText",
  connection: { type: "serial", port: "/dev/ttyUSB0", baudRate: 115200 },
  config: {
    schema: {
      properties: { temperature: { prefix: "TEMP: ", type: "float", unit: "C" } },
    },
  },
};
```

### "I have a Modbus-RTU energy meter / a custom binary sensor"

Use the **BinaryStream protocol**. Declare the frame layout (header
magic, length field, CRC) and the byte offsets where your fields live.

```js
export default {
  protocol: "BinaryStream",
  connection: { type: "serial", port: "/dev/ttyUSB0", baudRate: 9600 },
  config: {
    schema: {
      framing: { header: "AA55", lengthOffset: 2, lengthWidth: 1, crc: "modbus" },
      properties: {
        temperature: { offset: 4, width: 2, type: "int", scale: 0.1, unit: "C" },
      },
    },
  },
};
```

### "I have a vendor-specific SDK / I see a turnkey driver for my exact model"

Use a **Driver**. Browse the Devices tab, install the one that matches,
and configure with that driver's specific options:

```js
export default {
  driver: "Fairino",
  config: { ip: "192.168.58.2" },
};
```

### "I just want a place to store values"

No hardware, no wire — just shared state for dashboards and scripts.
Use a **Virtual** connector. The keyword is optional: a file with only
standard connector keys (`config`, `properties`, `methods`, `poll`,
`ai`, `hide`, `expose`, `safety`, `allowedConnectors`, `allowedHosts`) is Virtual
automatically. State lives in the file's own variables and is lost on
restart.

```js
let setpoint = 20;
export default {
  properties: {
    setpoint: { get: () => setpoint, set: (v) => { setpoint = Number(v); }, poll: true },
  },
};
```

A misspelt keyword (`drivr: "Webcam"`) is an *unknown* top-level key, so
the file still fails to load instead of silently becoming an empty store.
See the [Virtual driver reference](https://docs.muxit.io/reference/drivers/virtual.md).

### "I want to detect objects in a camera feed"

Use the **Vision engine** (or any future engine). Engines connect to
the *output of another connector*, not to hardware:

```js
export default {
  engine: "Vision",
  source: "webcam",  // name of an existing connector that produces frames
};
```

## How they fit together

Underneath every connector is a fixed stack:

```
┌─────────────────────────────────────────────┐
│ Connector  (workspace/connectors/*.js)      │   What you write
├─────────────────────────────────────────────┤
│ Driver  /  Protocol+Schema  /  Engine       │   What you pick
├─────────────────────────────────────────────┤
│ Transport  (serial / tcp / usbtmc)          │   How the bytes move
└─────────────────────────────────────────────┘
```

- The **transport** is just bytes-in / bytes-out. Three built-in
  transports cover almost everything: `serial`, `tcp`, `usbtmc`.
- A **protocol** rides on a transport and turns bytes into named
  properties + methods. Picks up framing, parsing, formatting.
- A **driver** is the alternative: it owns a transport internally and
  exposes a specific device's API directly. Drivers exist when the
  vendor has a quirky protocol that doesn't fit a generic mould
  (Fairino, Onvif, MqttBridge), or when there's a higher-level abstraction
  worth packaging (Webcam, FileAccess).
- An **engine** sits *above* the transport layer entirely. It reads from
  other connectors and emits derived data.

You almost never need to think about this stack — you pick a Driver,
Protocol, or Engine from the marketplace, fill in a small config, and
the rest is handled. The split matters only when something doesn't fit
the kind you picked: if a "turnkey driver for my device" exists, use
it; if not, fall back to a Protocol; if no Protocol fits, the device
probably needs a custom driver published to the marketplace.

## When in doubt

Ask the AI assistant. Tell it what you're connecting and how
(USB cable, network cable, what the box prints on its display), and
it'll pick the right kind, draft the connector, and test it against
your device.
