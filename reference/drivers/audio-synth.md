---
title: AudioSynth Driver
description: Reference for the AudioSynth extension driver — a software synthesizer with ADSR envelopes and additive harmonics that plays tones, notes, and melodies. Streams audio to every connected dashboard by default; can also play locally on the host via NAudio.
---

# AudioSynth

**Software audio synthesizer** that plays short tones, musical notes, and melodies. Useful for lab-side audible notifications, robot/CNC feedback tones, and experiment-complete bell sounds — the kind of "done!" cue that lets you know an experiment is finished from across the room.

AudioSynth supports three output paths, picked via the `output` config field:

- **`browser`** *(default)* — streams PCM frames to every connected dashboard via the WebSocket. Cross-platform: works on Windows, Linux, and macOS hosts. All clients connected to the server hear the same audio simultaneously.
- **`server`** — plays locally on the host's default audio output via [NAudio](https://github.com/naudio/NAudio). Windows-only — useful when the lab machine itself has speakers attached and you want sound there even when no browser is open.
- **`both`** — runs both paths in parallel.

AudioSynth is a free tier-3 extension driver. It ships as a `.muxdriver` package and installs into `workspace/drivers/` alongside other extension drivers. In `server` mode, audio plays through whichever output device the OS has set as default; AudioSynth does not expose output-device selection.

Every note is shaped by an **ADSR envelope** (attack → decay → sustain → release) and optionally layered with **additive harmonic partials**, so you can get bell-like shimmer or pluck-like transients without leaving the 1980s-beep comfort zone if you don't want to.

## Properties

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `volume` | double | R/W | Output volume, 0.0 to 1.0. Applies to the next playback. |
| `waveform` | string | R/W | Oscillator waveform: `sine`, `square`, `triangle`, or `sawtooth`. |
| `preset` | string | R/W | Timbre preset — sets ADSR + harmonics in one go. See [Presets](#presets). |
| `attack` | int (ms) | R/W | ADSR attack time. Linear ramp from 0 to full amplitude. |
| `decay` | int (ms) | R/W | ADSR decay time. Exponential fall from full amplitude to `sustain`. |
| `sustain` | double | R/W | ADSR sustain level, 0.0 to 1.0. |
| `release` | int (ms) | R/W | ADSR release time. Exponential fall from `sustain` to 0. |
| `harmonics` | array | R/W | Additive partials as `[[multiplier, amplitude], ...]`. |
| `playing` | bool | R | Whether a tone or melody is currently rendering. |

## Actions

| Action | Args | Description |
|--------|------|-------------|
| `playTone` | `frequency`, `duration`, `overlap?` | Play a single tone at `frequency` Hz for `duration` ms. |
| `playNote` | `note`, `duration`, `overlap?` | Play a scientific-pitch note (`A4`, `C#5`, `Bb3`) for `duration` ms. |
| `playMelody` | `notes`, `overlap?` | Play a sequence — shorthand string or array of `{note, duration}` objects. |
| `beep` | `overlap?` | 880 Hz, 120 ms confirmation tone at the current volume, waveform, and envelope. |
| `stop` | — | Cancel everything — in-flight playback and all polyphonic voices. Idempotent. |

Every `play*` action accepts an optional `overlap: true` flag that
controls whether the call layers on top of (or replaces) anything
already playing. See [Playback Semantics](#playback-semantics).

## Config Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `output` | string | `browser` | Output path — `browser`, `server`, or `both`. See [Output Modes](#output-modes). |
| `volume` | double | `0.5` | Initial volume, 0.0 to 1.0. |
| `waveform` | string | `sine` | Initial waveform. |
| `preset` | string | `beep` | Initial preset — applied before any explicit ADSR/harmonics overrides. |
| `attack` | int | — | Override the preset's attack time (ms). |
| `decay` | int | — | Override the preset's decay time (ms). |
| `sustain` | double | — | Override the preset's sustain level (0..1). |
| `release` | int | — | Override the preset's release time (ms). |
| `harmonics` | array | — | Override the preset's partials. |

## Output Modes

`output` decides where the synthesised audio actually plays.

### `browser` *(default)*

Each note is rendered server-side at 48 kHz mono, chunked into 20 ms Opus packets (32 kbit/s VBR), base64-encoded, and emitted on the driver's `audio` stream. Every browser dashboard subscribed to that stream decodes the chunks via the WebCodecs `AudioDecoder` and plays them through the Web Audio API. **All connected clients hear the same audio simultaneously** — useful for lab notifications that should be audible regardless of which machine someone is sitting at.

Requires a user gesture once per session (browser policy): the first click/keydown/touch unlocks audio. Until then, chunks are dropped silently. There is no special UI for this — clicking anywhere in the dashboard primes it.

### `server`

Original v1.2 behaviour: NAudio's `WaveOutEvent` plays each note on the host machine's default audio device. Windows-only; on Linux/Mac the call throws at first playback. Use this mode when the host machine has speakers attached and you want sound there even when no browser is open. No subscriber needed.

### `both`

Runs `server` and `browser` in parallel. NAudio plays locally; Opus packets are also streamed to dashboards. On non-Windows hosts the local-output half fails silently and the streaming half still works.

## Presets

Each preset bundles an ADSR envelope and a partial set into a single name. Setting `preset` overwrites the five ADSR/harmonics properties at once — you can still tweak individual fields afterwards for fine control.

| Preset | A | D | S | R | Partials | Feel |
|--------|---|---|---|---|----------|------|
| `beep` | 5 ms | 0 | 1.0 | 10 ms | fundamental | Legacy 1980s confirmation beep. |
| `bell` | 5 ms | 1500 ms | 0 | 200 ms | 1, 2.76, 5.4, 8.93, 13.34 | Tubular-bell shimmer — long exponential decay. |
| `pluck` | 2 ms | 400 ms | 0 | 50 ms | 1, 2, 3, 4 | Short plucked transient. |
| `pad` | 300 ms | 100 ms | 0.8 | 500 ms | 1, 2, 3 | Slow mellow swell for non-urgent cues. |
| `marimba` | 3 ms | 500 ms | 0 | 100 ms | 1, 4, 9.2 | Stiff-bar strike, wooden feel. |

Setting an unknown preset throws `ArgumentException`.

## ADSR Envelope

The envelope fits inside the note's total `duration`:

```
  1.0 ┤   ╱╲
      │  ╱  ╲___________
      │ ╱      sustain  ╲__
  0.0 ┤╱                    ╲___
      └─a─┼─d─┼────hold────┼─r──┘
      0                    duration
```

- **Attack** — linear ramp from 0 to full amplitude.
- **Decay** — exponential fall from full amplitude to `sustain` level.
- **Sustain hold** — flat at `sustain` until release starts.
- **Release** — exponential fall from `sustain` to 0.

**Tails ring out past gate-off.** The decay and release phases render at their natural lengths even when `duration` is shorter — a 200 ms note on the `bell` preset still decays for its full ~1.5 s tail instead of being squashed into 200 ms. The attack is capped at the gate-on duration so an absurdly long attack on a short note can't outlast the gate. With `overlap: false` (default) the action call blocks until the tail finishes; with `overlap: true` it returns at gate-off and the tail keeps ringing in the background while the next call layers on top.

## Additive Harmonics

Each entry in `harmonics` is a `[multiplier, amplitude]` pair. The generator sums the base waveform at every partial frequency, weighted by its amplitude. Amplitudes are normalised so their sum is 1.0, which prevents clipping regardless of how many partials you stack.

```javascript
// Bell-like partials — mostly inharmonic, which is what makes a real bell
// sound like a bell instead of a sawtooth.
audio.harmonics = [[1, 1], [2.76, 0.6], [5.4, 0.3], [8.93, 0.2], [13.34, 0.1]];

// Object form also accepted
audio.harmonics = [{ mult: 1, amp: 1 }, { mult: 2, amp: 0.5 }];
```

## Playback Semantics

Every `play*` action has two modes, picked per call via `overlap`:

### `overlap: false` *(default)* — replace-not-queue

The call cancels everything already playing (including any polyphonic
voices layered on by prior `overlap: true` calls), plays this note, and
blocks until it finishes — **including the release tail** past the
requested duration. You do not need to call `stop()` between calls.

This is the behaviour every previous version of AudioSynth had, so
existing scripts and connectors that don't pass `overlap` keep working
the way they always did, except for one improvement: long-decay
presets (`bell`, `marimba`) now ring out for their natural tail
instead of being cut off at the gate.

### `overlap: true` — polyphonic layer

The call renders the note as a self-contained voice (full attack +
decay + sustain hold + release tail), adds it to the active mixer on
top of whatever's already ringing, and returns at the *gate-off* —
i.e. after the requested `duration`, while the release tail is still
ringing in the background. The next call can start before the tail
finishes, producing a chord-like overlap.

```javascript
const audio = connector("audio");
audio.preset = "bell";

// Three bells ringing together as a chord. Each call returns after
// 200 ms (the gate-on time) so the next call can layer on top; the
// long bell decay keeps the prior notes audible while the new one
// strikes.
audio.playNote({ note: "C4", duration: 200, overlap: true });
audio.playNote({ note: "E4", duration: 200, overlap: true });
await audio.playNote({ note: "G4", duration: 1500, overlap: true });
```

A `playMelody({ ..., overlap: true })` plays its notes as a legato
sequence: each next note starts at the previous note's gate-off, so
the tails overlap.

### Other

- **`stop()` is cooperative.** Cancellation happens at sample-chunk boundaries, so there is no click. `stop()` tears down both monophonic playback and every polyphonic voice.
- **`volume`, `waveform`, `preset`, and ADSR/harmonics apply to the next playback.** Changing them mid-note does not affect notes already rendered.

## Note Names

Notes use scientific-pitch notation: a letter `A`–`G`, an optional accidental `#` or `b`, and an octave number. `A4` is standard concert pitch (440 Hz). Supported range is `C-1` through `B9`.

| Example | Frequency |
|---------|-----------|
| `A4` | 440.00 Hz |
| `C4` | 261.63 Hz (middle C) |
| `C#5` | 554.37 Hz |
| `Bb3` | 233.08 Hz |

## Melody Shorthand

```javascript
// Shorthand — "NOTE:DURATION_MS, NOTE:DURATION_MS, ..."
audio.playMelody({ notes: "C4:200,E4:200,G4:400" });

// Array form
audio.playMelody({ notes: [
  { note: "C4", duration: 200 },
  { note: "E4", duration: 200 },
  { note: "G4", duration: 400 },
]});
```

## Example Connector

```javascript
// workspace/connectors/audio.js
export default {
    driver: "AudioSynth",

    ai: {
        instructions: "Use beep() for quick cues and playMelody() for distinct alerts. Change `preset` for different timbres — 'bell' for chimes, 'pluck' for pings.",
    },

    volume: 0.5,
    waveform: "sine",
    preset: "bell",

    methods: {
        chime: {
            fn: async () => {
                driver.preset = "bell";
                await driver.playMelody({ notes: "C5:400,E5:400,G5:1500" });
            },
            description: "Three-note bell chime — useful for 'done' cues",
        },
        alert: {
            fn: async () => {
                driver.preset = "pluck";
                await driver.playMelody({ notes: "A5:120,A5:120,A5:120" });
            },
            description: "Triple-pluck alert — useful for warnings",
        },
    },
};
```

## Example Script

```javascript
const audio = connector("audio");

// Quick feedback
audio.beep();

// A nice bell instead of a 1980s beep
audio.preset = "bell";
await audio.playNote({ note: "C5", duration: 2000 });

// Fully custom envelope
audio.attack = 10;
audio.decay = 300;
audio.sustain = 0.4;
audio.release = 800;
audio.harmonics = [[1, 1], [2, 0.4], [3, 0.2]];
await audio.playNote({ note: "A4", duration: 1500 });

// Cancel a long-running tone
audio.playTone({ frequency: 440, duration: 5000 });
await delay(1000);
audio.stop();

// Polyphonic — a sustained bell chord
audio.preset = "bell";
audio.playNote({ note: "C4", duration: 200, overlap: true });
audio.playNote({ note: "E4", duration: 200, overlap: true });
await audio.playNote({ note: "G4", duration: 1500, overlap: true });
```

## Out of Scope

AudioSynth deliberately keeps the surface small. The following are **not** supported:

- WAV/MP3/OGG file playback
- Microphone input or recording
- MIDI input / output
- Output-device selection or routing (uses the OS default in `server` mode)
- Effects (reverb, delay, EQ)
- Visualisation data (the `audio` stream carries encoded playback audio, not a waveform/FFT view for widgets)

If you need any of those, a different driver is the right place for them.

## Platform Support

- **`browser` mode** *(default)* — works on Windows, Linux, and macOS. Audio plays through every connected dashboard's Web Audio API; no native audio dependency on the host.
- **`server` mode** — uses [NAudio](https://github.com/naudio/NAudio), which targets Windows (WASAPI / WaveOut). On Linux/Mac the first playback throws — switch to `browser` or `both`.
- **`both` mode** — `server` half fails silently on non-Windows hosts; `browser` half always works. Useful on Windows when you want both host-speaker and dashboard playback at the same time.

The `audio` stream uses 48 kHz mono Opus (32 kbit/s VBR, 20 ms frames), base64-encoded inside a JSON wrapper. See [WebSocket API → audio streams](https://docs.muxit.io/reference/websocket-api.md#audio-streams) for the wire format.
