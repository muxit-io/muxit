---
title: Digilent Analog Discovery Driver
description: Reference for the Digilent Analog Discovery 2 / 3 driver — oscilloscope, AWG, programmable supplies, and digital I/O over USB.
---

# Digilent Analog Discovery

**Driver for the Digilent Analog Discovery 2 and Analog Discovery 3.** A
single connector exposes the device's oscilloscope, arbitrary waveform
generator, power supplies, and 16-line digital I/O. Talks to the device
through Digilent's WaveForms SDK (`libdwf`) via the `pydwf` Python wrapper.

Tier-2 free driver — distributed as a `.muxdriver` Python package.

## Prerequisites

Install Digilent **WaveForms** on the host machine. It ships the native
`libdwf` library that `pydwf` loads at runtime — without it the driver
fails to initialise with a link to the download.

- Download: <https://digilent.com/shop/software/digilent-waveforms/>
- Supported devices: Analog Discovery 2, Analog Discovery 3

The `pydwf` Python package itself is installed automatically into the
driver's per-driver venv on first activation; you do not need to `pip
install` anything yourself.

## Connector config

```javascript
export default {
  driver: "Digilent Analog Discovery",
  config: {
    device_index: 0,           // Optional. Default 0 (first connected device).
    // device_serial: "210321ABCDEF",  // Optional. Open a specific device by serial.
  },
  methods: {
    acquire: { fn: () => driver.acquire() },
    gen_apply: { fn: (channel = 1) => driver.gen_apply({ channel }) },
  },
};
```

If both `device_serial` and `device_index` are set, `device_serial` wins.

## Quick examples

### Capture a waveform

```javascript
const frame = await connector("scope").acquire();
// frame = { time: [...], ch1: [...], ch2: [...], sample_rate, samples, ts }
plot(frame.time, frame.ch1);
```

### Generate a sine wave on W1, capture it on Ch1

```javascript
const ad = connector("ad");

// Stage AWG settings, then push them.
ad.gen_ch1_function = "sine";
ad.gen_ch1_frequency = 1000;
ad.gen_ch1_amplitude = 1.0;
ad.gen_ch1_enabled = true;
await ad.gen_apply(1);

// Now capture and plot.
const { time, ch1 } = await ad.acquire();
```

### Drive the power supplies

```javascript
const ad = connector("ad");
ad.psu_pos_enabled = true;
ad.psu_neg_enabled = true;
ad.psu_pos_voltage = 3.3;       // AD3 only; no-op on AD2 with a warning
ad.psu_master_enabled = true;   // gates both rails
```

### Stream live scope frames

```javascript
const ad = connector("ad");
on("waveform", (frame) => plot(frame.time, frame.ch1));
await ad.acquire_continuous();
// ...
await ad.stop_continuous();
```

## Properties

### Identity (read-only)

| Property | Type | Description |
|---|---|---|
| `device_name` | string | e.g. `"Analog Discovery 2"` or `"Analog Discovery 3"` |
| `serial_number` | string | Device serial |
| `device_revision` | string | Hardware revision (currently the device name) |

### Oscilloscope (`osc_*`)

| Property | Type | Access | Unit | Description |
|---|---|---|---|---|
| `osc_sample_rate` | double | R/W | Hz | Sample rate |
| `osc_buffer_size` | int | R/W | samples | Samples per channel per acquisition |
| `osc_ch1_enabled`, `osc_ch2_enabled` | bool | R/W | — | Per-channel enable |
| `osc_ch1_range`, `osc_ch2_range` | double | R/W | Vpp | Input range (peak-to-peak) |
| `osc_ch1_offset`, `osc_ch2_offset` | double | R/W | V | Input offset |
| `osc_trigger_source` | string | R/W | — | `none`, `ch1`, `ch2`, `ext1`, `ext2` |
| `osc_trigger_level` | double | R/W | V | Trigger level |
| `osc_trigger_edge` | string | R/W | — | `rising` or `falling` |
| `osc_ch1_waveform`, `osc_ch2_waveform` | double[] | R | V | Last captured samples |

Scope settings are staged in software and pushed to the device at the
start of every `acquire()`, so the order of property writes doesn't
matter.

### Function generator (`gen_chN_*`)

Repeat for `gen_ch1_*` and `gen_ch2_*`:

| Property | Type | Access | Unit | Description |
|---|---|---|---|---|
| `gen_ch1_enabled` | bool | R/W | — | Output enable (staged) |
| `gen_ch1_function` | string | R/W | — | One of `dc`, `sine`, `square`, `triangle`, `rampup`, `rampdown`, `noise`, `pulse` |
| `gen_ch1_frequency` | double | R/W | Hz | Output frequency |
| `gen_ch1_amplitude` | double | R/W | V | Peak amplitude |
| `gen_ch1_offset` | double | R/W | V | DC offset |
| `gen_ch1_phase` | double | R/W | deg | Phase |
| `gen_ch1_symmetry` | double | R/W | % | Duty / symmetry (0-100) |

Generator settings are staged; call `gen_apply({ channel })` to push them
to the hardware and start (or stop) the output.

### Power supplies (`psu_*`)

| Property | Type | Access | Unit | Description |
|---|---|---|---|---|
| `psu_master_enabled` | bool | R/W | — | Master enable for both rails |
| `psu_pos_enabled` | bool | R/W | — | V+ rail enable |
| `psu_pos_voltage` | double | R/W | V | V+ rail voltage (programmable on AD3 only) |
| `psu_neg_enabled` | bool | R/W | — | V- rail enable |
| `psu_neg_voltage` | double | R/W | V | V- rail voltage (programmable on AD3 only) |

::: tip AD2 vs AD3
The AD2 supplies are fixed at ±5 V — writing `psu_pos_voltage` or
`psu_neg_voltage` on an AD2 logs a warning and is a no-op so the same
connector config works on both devices. On an AD3 the writes take effect.
:::

### Digital I/O (`dio_*`)

| Property | Type | Access | Description |
|---|---|---|---|
| `dio_output_enable_mask` | int | R/W | 16-bit mask: bit set = pin is an output |
| `dio_output_value` | int | R/W | 16-bit mask: value driven on output pins |
| `dio_input_value` | int | R | 16-bit mask: value read from all pins |

Static digital I/O only. Timed capture (logic analyzer) and timed output
(pattern generator) are not yet exposed.

## Actions

| Action | Args | Description |
|---|---|---|
| `acquire()` | — | Single-shot capture of both channels. Returns `{ time, ch1, ch2, sample_rate, samples, ts }`. Also emits the same payload on the `waveform` stream and updates `osc_chN_waveform`. |
| `acquire_continuous()` | — | Start a background loop that captures repeatedly and emits each frame on `waveform`. Idempotent — calling it again while running is a no-op. |
| `stop_continuous()` | — | Stop the continuous acquisition loop. |
| `gen_apply({ channel })` | `channel`: 1 or 2 | Push the staged generator settings for one channel to the hardware. Starts the output if `gen_chN_enabled` is true, stops it otherwise. |
| `reset()` | — | Reset every subsystem and restore default scope / generator / supplies / DIO state. |

## Streams

| Stream | Payload |
|---|---|
| `waveform` | `{ time, ch1, ch2, sample_rate, samples, ts }` — emitted by every `acquire()` (single-shot or continuous). |

## Limitations

- **Logic analyzer / pattern generator not exposed.** Static DIO only.
- **Spectrum analyzer / voltmeter modes** are not exposed as first-class
  properties. Acquire raw samples and post-process them in your script.
- **Single device per connector.** Multiple AD2/AD3s connected at once
  require one connector per device (use `device_serial` to pin them).
- **External trigger sources (`ext1`, `ext2`)** require the corresponding
  trigger I/O to be wired up; refer to the WaveForms documentation.
