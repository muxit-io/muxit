# AI-assisted Protocol authoring (LineText, BinaryStream)

Muxit's AI chat can add devices that don't speak SCPI — Arduino sketches, cheap
hobby meters, dataloggers, Modbus-RTU sensors, custom embedded hardware. The
flow mirrors the [AI-assisted SCPI flow](https://docs.muxit.io/guides/ai-scpi-authoring.md) but uses the
[LineText](https://docs.muxit.io/reference/drivers/linetext.md) or
[BinaryStream](https://docs.muxit.io/reference/drivers/binary-stream.md) protocols depending on
what the device emits.

::: tip Subscription required
Same as SCPI authoring — **Maker tier or higher** for Muxit's managed AI, or
point your own Claude Desktop / Claude Code / ChatGPT at Muxit's MCP server
for Free-tier access. See [AI features by tier](https://docs.muxit.io/guides/ai.md#ai-features-by-tier).
:::

## Decide which protocol

The AI usually picks for you after one `discover_serial_device` call. The
decision tree:

| Device | Protocol |
|---|---|
| Arduino sketch, hobby PSU, custom embedded that prints lines (`TEMP: 25.5\n`) | [LineText](https://docs.muxit.io/reference/drivers/linetext.md) |
| Modbus-RTU sensor, datalogger with fixed-byte frames, cheap thermometer with binary response | [BinaryStream](https://docs.muxit.io/reference/drivers/binary-stream.md) |
| Oscilloscope, multimeter, power supply, function generator — anything that says it speaks SCPI | [Scpi](https://docs.muxit.io/reference/drivers/scpi.md) — use the [SCPI authoring guide](https://docs.muxit.io/guides/ai-scpi-authoring.md) instead |

When in doubt, say *"I don't know what protocol this device uses"* — the AI
calls `discover_serial_device` and the `kind` field of the result picks the
protocol for you.

## How to start

- **From chat.** Describe the device in natural language:
  - *"Add my Arduino on /dev/ttyUSB0 — it prints temperature lines"*
  - *"Set up the Modbus sensor at slave address 1 on COM3"*
  - *"This 4-channel thermometer on COM5 needs me to send 'A' to make it respond"*
- **From the Devices tab.** Open Add Connector, pick **LineText** or
  **BinaryStream**, click *Set up with AI*. The chat opens with a pre-filled
  prompt.

## What happens under the hood

### LineText (devices that print text lines)

1. `discover_serial_device` — the AI tries common baud rates and listens for
   spontaneous emission. When it sees printable lines, `kind: "linetext"` is
   returned with `baudRate`, `terminator`, and a `sampleText` snippet.
2. `read_from_transport` — capture another 3-5 seconds of inbound lines to
   nail down the format. The AI proposes a `schema.properties:` block where
   each line shape becomes a typed property using `prefix:` (for `TEMP: 25.5`-
   style lines) or `match:` regex (for `TEMP=25.5` or other no-delimiter
   formats).
3. `write_connector_config` — the AI writes the connector file by hand
   (there's no `compose_linetext_connector`; LineText configs are short
   enough not to need a composer).
4. `reload_connectors` + `read_property` — smoke-test one polled property.

### BinaryStream (devices that emit binary frames)

1. `discover_serial_device` — sweeps for spontaneous binary emission. When
   the bytes are non-printable, `kind: "binarystream"` is returned with
   `baudRate` and a `sampleHex` snippet.

   **If the device is silent** (no spontaneous emission), the AI moves on to
   step 2.

2. `probe_stimulus` — for silent-until-poked devices. The AI tries a default
   candidate list (common SCPI probes, single ASCII letters, control bytes,
   Modbus read, …) and reports which stimulus produced a response, plus the
   exact byte count of the response.

   **The reported byte count is the complete burst**, not a truncated chunk.
   It's safe to drop into `framing.size:` directly.

3. `analyze_binary_frame` — the AI asks you to **read 1-3 values off the
   device's display** ("the display says 21.4 °C, 50.5 %RH"), passes those
   + the captured frame hex to the analyzer, and gets back a paste-ready
   `schemaHint` snippet showing the right `(offset, width, type, endian,
   scale)` for each field.

   The AI will also ask **"can any of these readings ever go negative?"**.
   Answer yes (Celsius can dip below zero, signed offsets, bidirectional
   voltages) or no (humidity, pressure, RPM, lux) — the analyzer drops half
   the candidate space accordingly and avoids the uint8 vs int8 ambiguity
   that single-positive-reading data physically can't resolve.

4. **Handle ambiguities.** Sometimes the analyzer returns an
   `ambiguities[]` block with a literal `disambiguateBy` instruction —
   e.g. *"capture another frame where at least one value exceeds 25.5"*.
   This happens when the current values fit in 8 bits and the high bytes
   are `0x00`, so uint8 and uint16-LE decode to the same values today but
   will diverge once readings exceed 25.5 (or whichever boundary).

   The AI reads the instruction to you literally. Heat a probe, recapture,
   and the AI re-runs `analyze_binary_frame` with both captures in the
   `samples` array. The combined cross-correlation deterministically picks
   the right type because at least one sample will inevitably have a value
   the smaller type can't represent.

5. `write_connector_config` — write the BinaryStream connector. The AI
   sets `framing.size:` and `framing.request:` from the `probe_stimulus`
   result, and pastes the `schemaHint` properties from `analyze_binary_frame`.

6. `reload_connectors` + `read_property` — smoke-test.

## Worked example — silent 4-channel thermometer

A device on COM5 that does nothing until you send `A`, at which point it
returns 16 bytes encoding four channel temperatures.

**Chat:** *"Set up the 4-channel thermometer on COM5. I think it needs me to
send 'A' to make it respond."*

**Step 1.** AI calls `probe_stimulus({ port: "COM5", baudRate: 9600 })`. The
sweep tries the default candidate list and lands on `"A"` (`0x41`), reporting
`receivedBytes: 16` and a `bestSentHex: "41"`.

**Step 2.** AI calls `queryHex({ hex: "41" })` once more to capture a fresh
frame; gets something like `0280800101010100D600 E200 E300 0101`.

**Step 3.** AI asks: *"Can you read the four channel temperatures off the
display? Also, can any of these readings ever go below 0 °C?"*

**You:** *"21.4, 22.6, 22.7, 25.7. Yes, the device can read down to -20 °C."*

**Step 4.** AI calls `analyze_binary_frame({ frameHex: "...", values: [
{name:"ch1", value:21.4, canBeNegative:true},
{name:"ch2", value:22.6, canBeNegative:true},
{name:"ch3", value:22.7, canBeNegative:true},
{name:"ch4", value:25.7, canBeNegative:true} ] })`. Because one value (25.7)
is above 25.5, the uint8 candidate is automatically filtered out — only
`int16` LE with `scale: 0.1` at offsets 8, 10, 12, 14 fits all four values.
The `schemaHint` comes back paste-ready.

**Step 5.** AI calls `write_connector_config` with the BinaryStream connector,
setting `framing.size: 16`, `framing.request: "41"`, and the four channel
properties. `reload_connectors` brings it online. `read_property` confirms
each channel reads its current display value.

Total elapsed: about 30 seconds of AI time, plus however long it takes you to
read the display and answer two questions.

## Worked example — Arduino temperature sketch

Sketch on `/dev/ttyUSB0` prints `TEMP: 23.4\n` every second and accepts
`LED ON\n` / `LED OFF\n` to control an LED.

**Chat:** *"Add my Arduino on /dev/ttyUSB0 — it prints temperature lines and
I can toggle an LED."*

**Step 1.** `discover_serial_device({ port: "/dev/ttyUSB0" })` returns
`{ kind: "linetext", baudRate: 115200, terminator: "\n", sampleText: "TEMP: 23.4\n..." }`.

**Step 2.** AI captures more lines via `read_from_transport`, confirms the
format is consistent.

**Step 3.** AI writes a LineText connector with `temperature: { prefix:
"TEMP: ", type: "float", unit: "C" }` and a `setLed` method.

**Step 4.** `reload_connectors`. Polled `temperature` updates as soon as the
next line arrives; `arduino.setLed(true)` sends `LED ON\n`.

## Common pitfalls

### "queryHex returns fewer bytes than I expected"

Almost always means `framing.size:` was set too small (or not at all) and the
protocol extracted whatever was in the buffer at the moment the first chunk
arrived. Two fixes:
- If you know the response size, set `framing.size: N`.
- If you don't, omit framing entirely — the fallback (`framing.quietMs`,
  default 50 ms) waits for inter-byte silence and delivers the accumulated
  burst as one frame.

### "Polled properties stay null on a silent device"

Add `framing.request: "<hex>"`. Without it, BinaryStream's polled reads just
return cached values, and the cache never updates because the device never
sends anything unsolicited. With it, polled reads auto-trigger a fresh frame
when the cache is older than `maxStaleMs` (default 100 ms). Concurrent reads
coalesce — polling four properties triggers ONE send.

### "Values readable but wrap at 25.5"

You're decoding as `uint8 × 0.1` when the device actually uses `uint16
little-endian × 0.1`. Current values fit in 8 bits and the high bytes are
`0x00`, so today both interpretations read the same value — but uint8
saturates at 25.5 °C. Change `width: 1` to `width: 2` and `endian: "little"`
on the affected properties.

The `analyze_binary_frame` tool auto-prefers uint16 in this pattern via the
high-bytes-zero heuristic and will flag the ambiguity when both fit.

### "The AI's schema is decoding the wrong channel for each property"

When two adjacent channels have very close readings (say, 22.6 and 22.7),
display noise can shuffle them so the analyzer's lowest-error pick swaps
them. The analyzer prefers natural-order assignment when feasible — pass
values to the analyzer in the order they appear on the device (ch1, ch2,
ch3, ch4) and the heuristic will pick the matching offset order.

## See also

- [LineText reference](https://docs.muxit.io/reference/drivers/linetext.md)
- [BinaryStream reference](https://docs.muxit.io/reference/drivers/binary-stream.md)
- [Transport reference](https://docs.muxit.io/reference/drivers/transport.md)
- [AI Tools reference](https://docs.muxit.io/reference/ai-tools.md)
- [Concepts](https://docs.muxit.io/reference/concepts.md) — the 5-layer model.
