---
title: AI Tools — Device Onboarding
description: Reference for the AI tools that help you add new devices — port discovery, stimulus probing, binary frame analysis, and connector composition.
---

# AI Tools — Device Onboarding

The AI assistant exposes a chain of deterministic tools for adding a new device to Muxit: find the port, identify the protocol, capture the wire format, and write the connector. Each tool does one thing well and hands its output to the next. You typically don't call these directly — you describe the device to the AI in chat and it picks the right tools — but knowing what each one does makes the workflow easier to understand and debug.

The tools live in the **SCPI Authoring** group; they appear in chat requests the intent classifier flags as device setup ("add a thermometer", "set up the power supply on COM5", "this Arduino isn't responding", …).

## The typical chain

```
list_serial_ports        ← find which port the device is on (unplug/plug-in detection)
        ↓
discover_serial_device   ← sweep bauds/terminators/flow-control; identify SCPI vs LineText vs BinaryStream
        ↓
probe_stimulus           ← (silent devices only) find the byte that makes the device respond
        ↓
analyze_binary_frame     ← (binary devices only) reverse-engineer field offsets from display values
        ↓
compose_scpi_connector   ← (SCPI only) write the connector file from structured data
   OR  write_connector_config  ← (LineText / BinaryStream / custom JS) hand-author the file
        ↓
reload_connectors        ← bring the new device online
```

Not every device needs every tool. SCPI instruments typically only need `discover_serial_device` + `compose_scpi_connector`. Binary devices add `probe_stimulus` and `analyze_binary_frame` to figure out the wire format.

## Port discovery

### `list_serial_ports`

Enumerate every serial port the OS sees. Returns `{ ports: [{ path, description? }] }`. Used as part of the **unplug-plug detection** flow: call it three times — before the device is plugged, between unplugging and replugging, and after — and the port that appears in the third snapshot but not the second is the device.

### `list_usbtmc_devices`

Enumerate every USB device libusb can see. Returns `{ devices: [{ vendorId, productId, vendorHex, productHex, manufacturer?, product?, serial? }] }`. Pick the entry matching the instrument and pass its VID/PID to [`discover_serial_device`](#discover_serial_device) or directly to a `connection: { type: "usbtmc", ... }` block. On Windows, an empty list usually means WinUSB isn't bound to the device — see [Transport — USBTMC platform notes](https://docs.muxit.io/reference/drivers/transport.md#platform-notes).

## Device discovery

### `discover_serial_device`

One-shot sweep of a serial port — figures out *what kind of device is there and how to talk to it*. Tries the common baud rates (9600 → 19200 → 38400 → 115200 → 57600 → 4800 → 2400 → 1200) in priority order; at each baud first listens passively for spontaneous emission (Arduino sensors, Modbus slaves with poll, datalogger streams), then sends `*IDN?` with each terminator (`\n`, `\r\n`, `\r`) + flow-control (`none`, `xon-xoff`) combination. Stops on the first hit.

**Input:** `{ port: string, baudRates?: int[], maxTotalMs?: int }`.

**Output**, one of:

- `{ found: true, kind: "scpi", baudRate, flowControl, terminator, idn, vendor, model, serial, firmware, sessionId }` — SCPI gear. Drop the settings into a `protocol: "Scpi"` connector. The `sessionId` is a probe transport already open with the discovered settings; pass it directly to `send_to_transport` for command verification (don't re-open).
- `{ found: true, kind: "linetext", baudRate, terminator, sampleText, hints }` — device emits text lines on its own. Use [LineText](https://docs.muxit.io/reference/drivers/linetext.md).
- `{ found: true, kind: "binarystream", baudRate, sampleHex, hints }` — device emits binary frames. Use [BinaryStream](https://docs.muxit.io/reference/drivers/binary-stream.md).
- `{ found: false, attempts, hints, lastBytesHex }` — nothing worked (`attempts` is the count of combinations tried, not the full list — the per-combo detail goes to the server log). `hints` lists likely causes. The device probably isn't a `*IDN?` instrument — don't retry it as SCPI; switch to [`read_from_transport`](#read_from_transport) (devices that self-emit) or [`probe_stimulus`](#probe_stimulus) (devices that stay silent until poked) to learn its wire format.

Total worst-case ~10s; happy path (modern SCPI on 9600 baud) under 500 ms.

## Capability probing

### `probe_stimulus`

Brute-force-but-bounded "what makes this device talk?" probe. Walks a list of candidate stimulus bytes — sends each, listens for inter-byte silence after the first response byte, records what came back — and reports which stimulus produced a response. Use this when the device sits silent until poked but the poke byte is unknown (cheap thermometers, dataloggers, custom embedded gear where the vendor software handshake was figured out by sniffing the wire).

**Input:** `{ connection: { ... }, candidates?: [{ label?, text? OR hex? }], windowMs?: int, quietWindowMs?: int, stopOnFirst?: bool, maxTotalMs?: int }`.

Default candidate list covers: `*IDN?` with all three terminators, ENQ / STX / SOH / DC1 / CR / LF, every single uppercase + lowercase ASCII letter, every uppercase letter + CR, a canonical Modbus-RTU read-holding-registers frame with CRC, and `? NUL`. ~85 candidates. Override with `candidates: [{ text: "\xA5\x01" }, …]` for vendor-specific protocols. Hex is whitespace-tolerant; text accepts `\r` / `\n` / `\xHH` escapes.

**Output:** `{ found, bestLabel, best: { label, sentHex, sentAscii, receivedBytes, receivedHex, receivedAscii }, attemptsTotal, silentCount, attempts: [...], attemptsOmitted, elapsedMs, hints }`.

`attempts[]` is **token-frugal** — it lists only the candidates that actually drew bytes back or errored (the genuine leads, including 1–2 byte partial replies). The candidates that were sent and heard nothing are not echoed back one-by-one; they're collapsed into `silentCount`. `attemptsTotal` is the full number of candidates issued, so on the common "tried 85, nothing answered" case you get `{ found: false, attemptsTotal: 85, silentCount: 85, attempts: [] }` plus `hints` instead of an 85-entry wall of empty rows. `attemptsOmitted` is non-zero only when more than 20 candidates each drew a response (rare). To widen the search after a silent sweep, pass a custom `candidates:` list — see the `hints`.

**The reported byte count is the complete burst.** The sweep waits for inter-byte silence (`quietWindowMs`, default 80 ms) before reporting, so on devices that drip-feed responses over multiple serial chunks, `receivedBytes` is the **whole** response — drop it straight into `framing.size:` of a BinaryStream connector. If you set it smaller you'll lose data; larger you'll block waiting for bytes that never come.

### `analyze_binary_frame`

Reverse-engineer a binary frame against known display values. Given the captured frame as hex and one or more values the user can read off the device's display while the frame was captured, this brute-forces every plausible (offset × width × type × endian × scale) decoding — uint/int 1/2/4-byte little/big with the standard scale ladder (1, 0.1, 0.01, 0.001, …), float32 / float64 little/big, ASCII text substrings, and BCD packed nibbles — and reports the ones that decode to within tolerance (default 5 %) of each expected value.

**Input:** `{ frameHex: string, values: [{ name?, value, tolerance?, canBeNegative? }], tolerance?: number }` OR `{ samples: [{ frameHex, values }], tolerance? }`.

When multiple expected values are passed, the analyzer cross-correlates: any `(type, endian, scale, width)` format that explains EVERY value at distinct non-overlapping offsets is surfaced as a `SchemaSuggestion` with a paste-ready `schemaHint`. **Pass values in natural order** (`ch1, ch2, ch3, ch4` — not sorted), and **pass `canBeNegative: true|false` per value** when known (Celsius can; humidity can't); both help the analyzer pick the right type.

**Output (single-sample):** `{ ok, frameBytes, suggestions: [...], perValue: [...], ambiguities: [...], note }`.

**Output (multi-sample):** `{ ok, samplesAnalysed, combined: [...], perSample: [...], note }`.

#### Scoring rules (high-level)

- Match quality (lower error → higher score).
- Stride bonus: fields at a consistent offset interval suggest an array.
- Scale-simplicity penalty: `scale: 1.0` beats `0.001` beats `1e-4` (Occam's razor).
- **uint16-with-zero-high-bytes bonus** (`+10`): when current values fit in 8 bits but every "high byte" slot is `0x00`, uint16 LE is preferred over uint8 — uint8 would silently wrap above 255.
- **uint8-stride-2-with-zero-pad penalty** (`−8`): symmetric to the bonus; same byte content reads the same today but wraps tomorrow.
- Width-4 penalty for int types: uses more bytes than typically needed.

#### Ambiguity detection

When two top suggestions decode to identical values for the current frame but differ in width / type / endian (the classic uint8 vs uint16 LE case), the response includes `ambiguities[]` with a literal `disambiguateBy` instruction — e.g., "capture another frame where at least one value exceeds 25.5". Re-run with both frames in `samples` to deterministically pick the right type.

## Connector composition

### `compose_scpi_connector`

The default way to write a new SCPI connector. You provide structured data — `name`, `connection` block (from `discover_serial_device`), `schema` (arrays of `{ name, cmd, type, unit, description }` entries), optional `safety` / `poll` / `ai` — and the server templates the canonical connector file shape, parse-checks it, writes it, **auto-enables it** (appends to `connectors.enabled` when the user has an explicit list), and **reloads** so it's live.

Why this exists: hand-rolling the connector JS leaves room for shape errors (mis-nested `limits:`, invented field names like `get:`, `scpi:`, `actions:`). The composer guarantees the shape is correct; the AI only thinks about the content.

The response includes `enabled`, `reload.loaded`, and `nextStep`. When `reload.loaded` is true, the connector is live — skip straight to `read_property` to smoke-test.

### `write_connector_config`

The manual escape hatch — write any connector file by hand. Use this for:
- **LineText and BinaryStream connectors** (`compose_scpi_connector` only handles SCPI).
- **SCPI connectors with custom JS** — one command returning multiple parsed values (Hameg `VAL?` → voltage / current / power), multi-step methods, vendor-specific quirks the declarative schema can't capture.

Same overwrite-confirmation gate as `compose_scpi_connector`: the first call on an existing name returns `needs_user_confirmation` with a `confirmation_id`; summarise the change in plain text, then confirm with `confirm_action` (passing that id) — no need to re-send the config body.

## Transport probing (low level)

When the AI needs to verify a candidate command against the device before declaring it in a schema, it uses a session-based transport-probe surface:

- `open_transport({ connection })` → `{ sessionId }`. Opens a transport, keeps it alive across calls.
- `send_to_transport({ sessionId, command, expectResponse? })` → `{ response, error?, timedOut }`. Sends a text command (terminator auto-appended) and optionally waits for a line response.
- `read_from_transport({ sessionId, durationMs })` → `{ hex, byteCount, text?, lines? }`. Captures inbound bytes for `durationMs` ms — used to see what a device emits on its own.
- `close_transport({ sessionId })` → `{ ok }`. Release the transport.

Sessions auto-close after 60s idle / 5min total to avoid pinning the wire. **When `discover_serial_device` succeeds it returns a `sessionId` already open with the discovered settings** — use it directly for verification; don't call `open_transport` again or you'll lose `flowControl` / `terminator` in the transcription and the device will stop responding.

## See also

- [Concepts](https://docs.muxit.io/reference/concepts.md) — the 5-layer model.
- [Scpi](https://docs.muxit.io/reference/drivers/scpi.md), [LineText](https://docs.muxit.io/reference/drivers/linetext.md), [BinaryStream](https://docs.muxit.io/reference/drivers/binary-stream.md), [Transport](https://docs.muxit.io/reference/drivers/transport.md) — protocol and transport reference pages.
- [Protocol Authoring guide](https://docs.muxit.io/guides/protocol-authoring.md) — end-to-end walk-through for the AI-led onboarding flow.
- [AI-assisted SCPI authoring guide](https://docs.muxit.io/guides/ai-scpi-authoring.md) — SCPI-specific walk-through.
