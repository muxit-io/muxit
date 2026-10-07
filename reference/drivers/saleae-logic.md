---
title: Saleae Logic Driver
description: Reference for the Saleae Logic driver — timed, manual and triggered captures, protocol analyzers, and CSV/binary/.sal exports through the Logic 2 automation API.
---

# Saleae Logic

**Driver for Saleae Logic analysers** — Logic 4, Logic 8, Logic Pro 8 and
Logic Pro 16. A single connector arms captures, attaches protocol analyzers,
and writes the decoded results to disk.

Muxit does not talk to the USB device directly. Saleae's supported automation
surface is a gRPC API served by the **Logic 2 desktop application**, and this
driver is a client of it via the official `logic2-automation` package. Logic 2
therefore has to be running on the same machine as MuxitServer.

Tier-2 free driver — distributed as a `.muxdriver` Python package.

## Prerequisites

1. Install [Saleae Logic 2](https://www.saleae.com/pages/downloads) on the
   machine running MuxitServer.
2. In Logic 2, turn on **Preferences → Automation → Enable automation
   server**. The default port is `10430`.
3. Leave Logic 2 running — or set `config.launch = true` and the driver starts
   it for you.

The `logic2-automation` Python package installs itself into the driver's
per-driver venv on first activation; you do not need to `pip install`
anything yourself.

## Connector config

```javascript
export default {
  driver: "Saleae Logic",
  config: {
    // Connection
    address: "127.0.0.1",   // Optional. Logic 2 host. Default 127.0.0.1.
    port: 10430,            // Optional. Automation server port.
    connect_timeout_seconds: 20,
    launch: false,          // Optional. Start Logic 2 instead of connecting to it.
    // application_path: "C:/Program Files/Logic/Logic.exe",  // with launch: true

    // Device
    device_id: "",          // Optional. Blank = let Logic 2 pick the device.

    // Where relative export paths land
    output_directory: "captures",

    // Staged capture settings (all writable at runtime as properties too)
    digital_channels: [0, 1],
    analog_channels: [],
    digital_sample_rate: 12000000,
    duration_seconds: 1.0,
  },
  methods: {
    capture: { fn: (s = 1.0) => driver.capture({ duration_seconds: s }) },
  },
};
```

Every key in the [staged capture configuration](#staged-capture-configuration)
may be seeded from `config` and changed later as a property, so a connector can
ship a ready-to-run setup without a script.

## Capture lifecycle

`start_capture()` arms the device and **returns immediately**. A background
thread inside the driver does the blocking wait, so a ten-minute capture is
just a connector sitting in `capture_state == "running"` rather than an RPC
that times out. Watch `capture_state`, or subscribe to the [`capture`
stream](#streams).

```
idle ──start_capture()──▶ running ──▶ complete ──close_capture()──▶ idle
                             │
                             └──▶ error        (read capture_error)

load_capture() ──▶ loaded ──close_capture()──▶ idle
```

Three capture modes, selected with the `capture_mode` property or the `mode`
argument to `start_capture()`:

| Mode | Ends when | Notes |
|------|-----------|-------|
| `timed` | `duration_seconds` elapses | The default. |
| `manual` | you call `stop_capture()` | Runs indefinitely until stopped. |
| `digital_trigger` | the trigger fires and `after_trigger_seconds` elapses | Uses `trigger_channel`, `trigger_type` and the pulse-width bounds. |

Saleae's API forbids mixing `stop()` and `wait()` on one capture, so
`stop_capture()` only works on a `manual` capture — timed and triggered
captures end on their own, and calling `stop_capture()` on them raises.

Analyzers and exports only work once `capture_state` is `complete` or
`loaded`; calling them on a running capture raises with that reason. Always
`close_capture()` when you're done — an open capture stays as a tab in Logic 2
and keeps its samples in memory.

## Quick examples

### Record two seconds and decode UART

```javascript
const logic = connector("logic");

await logic.capture({ duration_seconds: 2.0 });   // start + wait
await logic.add_analyzer({
  name: "Async Serial",
  label: "uart",
  settings: { "Input Channel": 0, "Bit Rate (Bits/s)": 115200 },
});
const { path } = await logic.export_data_table({ path: "uart.csv" });
log.info(`decoded frames written to ${path}`);
await logic.close_capture();
```

Analyzer names and settings keys must match the Logic 2 UI **exactly** — the
application rejects anything else.

### A long capture, without blocking

`capture()` blocks, and the connector RPC timeout is 30 seconds. For anything
longer, start it and poll:

```javascript
const logic = connector("logic");

logic.duration_seconds = 300;                     // five minutes
await logic.start_capture();

while (logic.capture_state === "running") {
  await delay(1000);
}
if (logic.capture_state === "error") throw new Error(logic.capture_error);

await logic.export_raw_csv({ directory: "long-run" });
await logic.close_capture();
```

### Trigger on a falling edge

```javascript
const logic = connector("logic");

logic.digital_channels = [0, 1, 2];
logic.capture_mode = "digital_trigger";
logic.trigger_channel = 2;
logic.trigger_type = "falling";
logic.after_trigger_seconds = 0.5;

await logic.start_capture();
// ... make the event happen ...
await logic.save_capture({ path: "glitch.sal" });
```

The trigger channel has to be one of the recorded `digital_channels`; the
driver rejects the capture up front if it isn't.

### Stop a manual capture from a dashboard button

```javascript
await connector("logic").start_capture({ mode: "manual" });
// later, from another script or a button:
await connector("logic").stop_capture();
```

## Properties

### Connection and identity (read-only)

| Property | Type | Description |
|----------|------|-------------|
| `connected` | bool | True while the gRPC connection to Logic 2 is up |
| `app_version` | string | Logic 2 application version |
| `api_version` | string | Automation API version reported by Logic 2 |
| `device_type` | string | Model of the selected device, e.g. `LOGIC_PRO_16` |
| `device_count` | int | Number of Saleae devices Logic 2 currently sees |

`device_id` (string, R/W) selects the device captures run on. Blank lets Logic
2 choose. Writing an unattached serial raises and lists what *is* attached.

### Capture lifecycle (read-only)

| Property | Type | Description |
|----------|------|-------------|
| `capture_state` | string | `idle`, `running`, `stopping`, `complete`, `loaded` or `error` |
| `capture_error` | string | Failure reason when `capture_state` is `error`, blank otherwise |
| `capture_open` | bool | True while a capture tab is open and can be exported |

### Staged capture configuration

All read/write. They are read when `start_capture()` runs; changing them
afterwards does not affect a capture already in flight.

| Property | Type | Unit | Description |
|----------|------|------|-------------|
| `digital_channels` | int[] | — | Digital channel indices to record |
| `analog_channels` | int[] | — | Analog channel indices to record |
| `digital_sample_rate` | int | Hz | Digital sample rate; `0` lets Logic 2 pick |
| `analog_sample_rate` | int | Hz | Analog sample rate; `0` lets Logic 2 pick |
| `digital_threshold_volts` | double | V | Logic threshold (Logic Pro only); `0` uses the device default |
| `buffer_size_megabytes` | int | MB | Capture buffer size; `0` uses the Logic 2 setting |
| `capture_mode` | string | — | `timed`, `manual` or `digital_trigger` |
| `duration_seconds` | double | s | Recording length for `timed` |
| `trim_data_seconds` | double | s | Keep only the last N seconds; `0` keeps everything |
| `trigger_channel` | int | — | Digital channel the trigger watches |
| `trigger_type` | string | — | `rising`, `falling`, `pulse_high` or `pulse_low` |
| `after_trigger_seconds` | double | s | Recording length after the trigger fires; `0` uses the Logic 2 default |
| `min_pulse_width_seconds` | double | s | Lower bound for pulse triggers; `0` disables it |
| `max_pulse_width_seconds` | double | s | Upper bound for pulse triggers; `0` disables it |

`0` is the "leave it to Logic 2" sentinel throughout: those fields are omitted
from the request rather than sent as a zero, and read back as `0`.

At least one of `digital_channels` / `analog_channels` must be non-empty —
starting a capture with neither raises.

### Results

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `analyzers` | string[] | R | Labels of the analyzers currently on the capture |
| `output_directory` | string | R/W | Directory relative export paths resolve against |
| `last_export_path` | string | R | Path written by the most recent export |
| `last_capture_path` | string | R | Path of the most recently saved or loaded `.sal` |

## Actions

### Discovery

| Action | Arguments | Returns |
|--------|-----------|---------|
| `list_devices` | `include_simulation_devices` | `[{ device_id, device_type, is_simulation }]` |
| `app_info` | — | `{ app_version, api_version, app_pid }` |
| `reconnect` | — | `{ connected, app_version, api_version }` |

### Capture

| Action | Arguments | Returns |
|--------|-----------|---------|
| `start_capture` | `mode`, `duration_seconds`, `device_id` | `{ state, mode, device_id, duration_seconds }` |
| `capture` | `duration_seconds` | `{ state, duration_seconds, timed_out }` |
| `wait_capture` | `timeout_seconds` (default 25) | `{ state, timed_out, error }` |
| `stop_capture` | — | `{ state }` |
| `close_capture` | — | `{ state, closed }` |
| `save_capture` | `path` | `{ path }` |
| `load_capture` | `path` | `{ path, state }` |

`wait_capture` timing out is not an error: the capture keeps running and
`timed_out: true` says so. Relative paths resolve against `output_directory`,
and missing parent directories are created.

### Analyzers

| Action | Arguments | Returns |
|--------|-----------|---------|
| `add_analyzer` | `name`, `label`, `settings` | `{ label, name }` |
| `add_high_level_analyzer` | `extension_directory`, `name`, `input_label`, `label`, `settings` | `{ label, name, input_label }` |
| `remove_analyzer` | `label` | `{ label, removed }` |

`label` defaults to the analyzer name and is how every later call refers to it.
Setting values must be strings, numbers or booleans. Analyzers already present
in a capture loaded from a `.sal` file are not visible to the automation API —
that is a Logic 2 limitation, not a driver one.

### Exports

| Action | Arguments | Returns |
|--------|-----------|---------|
| `export_raw_csv` | `directory`, `analog_channels`, `digital_channels`, `analog_downsample_ratio`, `iso8601_timestamp` | `{ directory }` |
| `export_raw_binary` | `directory`, `analog_channels`, `digital_channels`, `analog_downsample_ratio` | `{ directory }` |
| `export_data_table` | `path`, `labels`, `radix`, `columns`, `iso8601_timestamp` | `{ path, analyzers }` |
| `export_analyzer` | `path`, `label`, `radix` | `{ path, label }` |

Omitting `analog_channels` / `digital_channels` exports whatever was captured;
passing an empty array exports nothing. `radix` is one of `hexadecimal`
(default), `decimal`, `binary` or `ascii`. `export_data_table` defaults to
every analyzer added.

### Glitch filters

`set_glitch_filters({ filters })` takes a list of
`{ channel_index, pulse_width_seconds }` and applies it to the **next**
capture. Pass an empty list to clear them. They can also be seeded from
`config.glitch_filters`.

## Streams

`capture` — one event per lifecycle transition:

```json
{ "event": "started",  "state": "running",  "mode": "timed", "duration_seconds": 2.0 }
{ "event": "complete", "state": "complete", "mode": "timed" }
{ "event": "error",    "state": "error",    "mode": "timed", "error": "..." }
{ "event": "loaded",   "state": "loaded",   "mode": "",      "path": "..." }
{ "event": "closed",   "state": "idle",     "mode": "" }
```

Use it in a script with `on("logic:capture", frame => ...)` when you'd rather
react than poll.

## Limitations

- Logic 2 must run on the same machine as MuxitServer. The automation API is
  loopback-only in practice, and `launch` starts a local process.
- One capture at a time per connector. Add a second connector (pointing at a
  second `device_id`) to drive two analysers in parallel.
- The connector RPC timeout is 30 seconds, so `capture()` and `wait_capture()`
  cap their wait at 25. Longer captures work fine — start them non-blocking and
  poll `capture_state`.
- Sample data is exported to files rather than returned inline: a multi-second
  capture is far too large to move through a connector call.
- Analyzers inside a loaded `.sal` file can't be read back through the API.
