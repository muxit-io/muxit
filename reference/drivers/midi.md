---
title: Midi Driver
description: Reference for the Midi extension driver — live MIDI I/O, SMF playback and recording, internal clock, panic, learn, and channel filtering.
---

# Midi

**Advanced MIDI driver for any USB or virtual MIDI device.** Live input and output, per-channel filtering, pass-through, internal 24-PPQN clock with transport, Standard MIDI File (SMF) playback and recording, panic/all-notes-off, and a `learn` helper for mapping unknown controls. Every incoming message is streamed as JSON for scripts and dashboards.

Installation: download `muxit-midi-v0.1.3.muxdriver` from the Extensions panel, or drop it into `workspace/drivers/` and restart.

## Properties

### Device & connection

| Property | Type | Access | Description |
|---|---|---|---|
| `inputs` | string[] | R | Available MIDI input device names |
| `outputs` | string[] | R | Available MIDI output device names |
| `inputDevice` | string | R | Currently open input (empty if none) |
| `outputDevice` | string | R | Currently open output (empty if none) |
| `inputOpen` | bool | R | Whether an input port is open |
| `outputOpen` | bool | R | Whether an output port is open |

### Traffic & state

| Property | Type | Access | Unit | Description |
|---|---|---|---|---|
| `lastMessage` | object | R | | Most recent accepted incoming message (same shape as the `events` stream) |
| `messageCount` | int | R | | Incoming messages since the input was opened |
| `activeNotes` | object | R | | Held note numbers per channel — `{ "1":[60,64,67], "10":[36] }` |
| `tempo` | double | R/W | bpm | Drives the internal clock and SMF playback |
| `channelFilter` | int[] | R/W | | Accept-list of incoming channels (1–16). Empty = accept all |
| `passThrough` | bool | R/W | | Forward accepted input → output as received |

### Transport

| Property | Type | Access | Unit | Description |
|---|---|---|---|---|
| `clockRunning` | bool | R | | Internal MIDI clock is active |
| `playbackState` | string | R | | `"stopped"` \| `"playing"` \| `"paused"` |
| `playbackPosition` | double | R | s | SMF playhead |
| `playbackDuration` | double | R | s | Length of the loaded SMF |
| `recording` | bool | R | | Input is being recorded to `.mid` |
| `loadedFile` | string | R | | Absolute path of the last-loaded SMF |

## Actions

### Device management

| Action | Args | Description |
|---|---|---|
| `refreshDevices` | — | Re-enumerate system MIDI devices. Returns `{ inputs, outputs }` |
| `openInput` | `{ name: string }` | Open a MIDI input by name |
| `openOutput` | `{ name: string }` | Open a MIDI output by name |
| `close` | — | Close both ports, stop clock / playback / recording |

### Live messages

| Action | Args | Description |
|---|---|---|
| `noteOn` | `{ channel, note, velocity }` | Send a Note On (channel 1–16, note/velocity 0–127) |
| `noteOff` | `{ channel, note, velocity? }` | Send a Note Off |
| `playNote` | `{ channel, note, velocity, durationMs }` | Note On + scheduled Note Off |
| `controlChange` | `{ channel, cc, value }` | Send a Control Change (CC) |
| `programChange` | `{ channel, program }` | Send a Program Change |
| `pitchBend` | `{ channel, value }` | Send Pitch Bend (`value` is −1.0…1.0) |
| `aftertouch` | `{ channel, pressure }` | Channel Aftertouch (pressure 0–127) |
| `sendSysex` | `{ bytes: int[] }` | Send a SysEx payload (F0/F7 are added automatically) |
| `panic` | — | All Notes Off + All Sound Off + Reset All Controllers on all 16 channels; also clears `activeNotes` |

### Transport / clock

| Action | Args | Description |
|---|---|---|
| `startClock` | — | Start internal 24-PPQN MIDI clock to the open output |
| `stopClock` | — | Stop the internal clock |
| `sendTransport` | `{ command: "start" \| "stop" \| "continue" }` | Send a MIDI transport message |

### SMF files

Files are resolved under the `midiFilesDir` config option (default: `midi/` under the workspace root).

| Action | Args | Description |
|---|---|---|
| `loadFile` | `{ path: string }` | Load a `.mid` / `.midi` file (path relative to the midi dir) |
| `play` | — | Start or resume playback through the open output |
| `pause` | — | Pause playback (keeps the playhead) |
| `stop` | — | Stop playback and rewind to the beginning |
| `seek` | `{ seconds: double }` | Seek the playhead |
| `listFiles` | — | List `.mid` / `.midi` files under the midi dir |
| `startRecording` | — | Record incoming MIDI to memory (requires an open input) |
| `stopRecording` | `{ savePath: string }` | Stop recording and save to a `.mid` file (path relative to the midi dir) |

### Learn

| Action | Args | Description |
|---|---|---|
| `learn` | `{ timeoutMs?: int }` | Wait for the next incoming MIDI message and return it as a dict. Throws on timeout (default 5000 ms) |

## Streams

| Stream | Format | Rate | Description |
|---|---|---|---|
| `events` | JSON | per-event | Every accepted incoming message (channel-filtered, excludes clock ticks unless `emitClockStream: true`) |
| `note` | JSON | per-event | Only `noteOn` / `noteOff` messages — cheaper for drum-trigger UIs |
| `clock` | JSON | 24 × BPM / 60 per second | TimingClock ticks. Off by default — enable with `emitClockStream: true` |

### Normalized message shape

Every incoming message (and `lastMessage`) has this dictionary form:

```json
{ "type": "noteOn",        "channel": 1, "note": 60, "velocity": 100, "tsMs": 1713312321043 }
{ "type": "noteOff",       "channel": 1, "note": 60, "velocity": 0,   "tsMs": 1713312321498 }
{ "type": "controlChange", "channel": 1, "controller": 7, "value": 96, "tsMs": 1713312321981 }
{ "type": "programChange", "channel": 1, "program": 42, "tsMs": 1713312322004 }
{ "type": "pitchBend",     "channel": 1, "raw": 12288, "value": 0.5, "tsMs": 1713312322010 }
{ "type": "aftertouch",    "channel": 1, "pressure": 72, "tsMs": 1713312322011 }
{ "type": "sysex",         "bytes": [67, 0, 9, 1, 16], "tsMs": 1713312322012 }
{ "type": "start" }  { "type": "stop" }  { "type": "continue" }  { "type": "clock" }
```

Channel is always 1–16, notes and velocities 0–127. `tsMs` is a Unix millisecond timestamp captured when the driver received the message.

## Config Options

| Option | Type | Default | Description |
|---|---|---|---|
| `inputName` | string | — | Open this input on init (optional) |
| `outputName` | string | — | Open this output on init (optional) |
| `tempo` | double | 120 | Default BPM for the internal clock and SMF playback |
| `channelFilter` | int[] | `[]` | Accept-list for incoming channels (1–16). Empty = accept all |
| `passThrough` | bool | false | Forward accepted input to output |
| `emitClockStream` | bool | false | Emit TimingClock ticks on the `clock` stream (high-rate — off by default) |
| `midiFilesDir` | string | `"midi"` | Directory for `loadFile` / `stopRecording`, relative to the workspace root |

## Example connector

```js
// workspace/connectors/midi-controller.js
export default {
  driver: "Midi",
  inputName: "loopMIDI Port",
  outputName: "loopMIDI Port",
  tempo: 120,

  poll: ["activeNotes", "playbackState", "playbackPosition", "inputOpen", "outputOpen"],

  ai: {
    instructions:
      "This is a MIDI controller. playChord takes (root, 'major'|'minor'). " +
      "Always call panic() if the user asks to stop all notes.",
  },

  methods: {
    playChord: {
      fn: (root, quality = "major", velocity = 100, durationMs = 500) => {
        const intervals = quality === "minor" ? [0, 3, 7] : [0, 4, 7];
        for (const i of intervals) driver.playNote({ channel: 1, note: root + i, velocity, durationMs });
      },
      description: "Play a triad on channel 1",
    },
    allOff: [() => driver.panic(), "Stop every note on every channel"],
  },

  properties: {
    heldNoteCount: {
      get: () => Object.values(driver.activeNotes || {}).reduce((a, b) => a + b.length, 0),
      poll: true,
    },
  },
};
```

## Troubleshooting

- **Device not listed.** Some operating systems cache the MIDI device list. Call `refreshDevices` after plugging/unplugging hardware or creating a virtual port.
- **"No MIDI output open" error.** Call `openOutput` (or set `outputName` in the connector config) before any send action or `play`.
- **No hardware?** Install [loopMIDI](https://www.tobias-erichsen.de/software/loopmidi.html) to create a free virtual port for testing. Open it in both `inputName` and `outputName` plus `passThrough: true` to echo messages back through yourself.
- **High CPU from clock stream.** Leave `emitClockStream: false` (the default). The internal clock still runs and transmits — the stream only surfaces the 24-PPQN ticks to the WebSocket for debugging.
