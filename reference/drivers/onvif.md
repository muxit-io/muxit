---
title: ONVIF Camera Driver
description: Reference for the ONVIF built-in driver — IP camera streaming, snapshots, and PTZ control.
---

# ONVIF (IP Camera)

**ONVIF-compatible IP camera driver** with live video streaming, snapshots, and PTZ (pan/tilt/zoom) control. Uses ONVIF SOAP for device control and OpenCV for RTSP stream capture.

::: tip Safety gate
This driver ships with `requiresSafetyGates: false` — PTZ moves, snapshots, and other operations bypass the [safety gate](https://docs.muxit.io/guides/safety.md) entirely and no audit rows are written. See [Per-driver opt-out](https://docs.muxit.io/guides/safety.md#per-driver-opt-out).
:::

## Properties

| Property | Type | Access | Unit | Description |
|----------|------|--------|------|-------------|
| `ip` | string | R | | Camera IP address |
| `port` | int | R | | ONVIF service port |
| `fps` | int | R/W | | Target capture framerate |
| `quality` | int | R/W | | JPEG encoding quality (1–100) |
| `flipH` | bool | R/W | | Mirror frames horizontally (left ↔ right) |
| `flipV` | bool | R/W | | Flip frames vertically (top ↔ bottom) |
| `digitalZoom` | double | R/W | x | Software zoom factor (1.0 = off, 2.0 = 2x, … up to 16) |
| `zoomX` | double | R/W | | Digital-zoom horizontal pan (-1 = left, 0 = center, 1 = right) |
| `zoomY` | double | R/W | | Digital-zoom vertical pan (-1 = top, 0 = center, 1 = bottom) |
| `streaming` | bool | R | | Whether RTSP capture is active |
| `connected` | bool | R | | Whether camera is reachable |
| `resolution` | string | R | | Stream resolution (e.g., "1920x1080") |
| `profiles` | string[] | R | | Available media profile names |

## Actions

| Action | Args | Description |
|--------|------|-------------|
| `start` | — | Connect to RTSP stream and start video capture |
| `stop` | — | Stop RTSP capture and streaming |
| `snapshot` | — | Capture a single frame, return as base64 JPEG |
| `discover` | — | Find ONVIF devices on the local network |
| `getProfiles` | — | Fetch available media profiles from the camera |
| `ptzMove` | `{ pan, tilt, zoom }` | PTZ **relative** move — nudge by a delta (values -1.0 to 1.0) |
| `ptzMoveAbsolute` | `{ pan, tilt, zoom }` | PTZ **absolute** move — go to a specific position (values -1.0 to 1.0) |
| `ptzStop` | — | Stop PTZ movement |
| `ptzStatus` | — | Read current PTZ position and movement state, or `null` if unsupported |
| `gotoPreset` | `{ preset: string }` | Go to a PTZ preset position |

## PTZ control

ONVIF cameras support three styles of motion. All three coexist on the same driver:

- **`ptzMove` (relative)** — a one-shot nudge from the current position. Cameras move once and stop on their own. Use for tweaking aim during live operation.
- **`ptzMoveAbsolute` (absolute)** — drives to a specific position in the camera's coordinate space (typically each axis normalized to `[-1, 1]`). Use when you have known coordinates to revisit, or to script reproducible scans. Some lower-end ONVIF Profile S cameras don't implement absolute PTZ and will return a SOAP fault — fall back to `gotoPreset` or relative moves.
- **`gotoPreset`** — navigate to a position previously saved on the camera as a numbered preset. Works on the widest set of cameras, but you can only target positions the camera (or its UI) has saved.

::: tip Coordinates are normalized to `[-1, 1]`
Both `ptzMove` and `ptzMoveAbsolute` expect each axis in `[-1, 1]`. The driver clamps out-of-range values to that range (logging a warning) and rejects non-finite values (`NaN`/`Infinity`) before the SOAP call. If you're aiming the camera from detector output — pixel coordinates or degrees — **map into `[-1, 1]` yourself first**; feeding raw pixels makes the camera reject the move with a `BadRequest` SOAP fault. A typical pixel→normalized map: `pan = (px / frameWidth) * 2 - 1`.
:::

`ptzStatus` returns the current `{ pan, tilt, zoom, panTiltState, zoomState }`. `panTiltState` / `zoomState` are `"IDLE"`, `"MOVING"`, or `"UNKNOWN"` — useful to wait for an absolute move to settle before issuing the next one. Each call is a SOAP round-trip; don't poll faster than ~500 ms.

```javascript
// Drive to a known position, wait for it to settle, then take a snapshot
const cam = connector('camera');
cam.ptzMoveAbsolute({ pan: 0.4, tilt: -0.2, zoom: 0.5 });
while (true) {
  const s = cam.ptzStatus();
  if (!s || (s.panTiltState !== 'MOVING' && s.zoomState !== 'MOVING')) break;
  delay(200);
}
const jpeg = cam.snapshot();
```

## Digital zoom

Three writable properties — `digitalZoom`, `zoomX`, `zoomY` — give you a software crop-and-rescale on top of any PTZ. Useful when:

- The camera has no optical zoom (or only a coarse one), but you need to inspect a region for an AI / vision pipeline.
- You want to look at several regions of the same frame in parallel without moving the camera (e.g. `snapshot()`, change crop, `snapshot()` again).
- You want zoom that takes effect *now* — PTZ moves take seconds to settle, digital zoom is on the next frame.

| Property | Range | Meaning |
|----------|-------|---------|
| `digitalZoom` | `1.0` – `16.0` | Crop a `1/zoom × 1/zoom` window and scale back up to the original frame size. `1.0` = off |
| `zoomX` | `-1` – `1` | Horizontal pan: `-1` = left edge, `0` = center, `1` = right edge |
| `zoomY` | `-1` – `1` | Vertical pan: `-1` = top, `0` = center, `1` = bottom |

The pan offsets are normalized against the *available* pan range at the current zoom — `zoomX = 1` puts the crop's right edge flush with the image's right edge, so the zoomed region never extends past the source frame regardless of zoom level.

The output frame stays at the original `resolution`, so widgets, recordings, and downstream consumers don't see the size change. There's no actual detail gained — pure software crop. Combine with optical PTZ `zoom` (via `ptzMove`) when you need real reach.

```javascript
const cam = connector('camera');

// Zoom 4x onto the top-right quadrant of the frame
cam.digitalZoom = 4;
cam.zoomX = 1;
cam.zoomY = -1;

// AI inspects the zoomed region
const desc = ai("What's the reading on this gauge?", cam.snapshot());

// Reset
cam.digitalZoom = 1;
cam.zoomX = 0;
cam.zoomY = 0;
```

Coordinates apply to the *displayed* image — i.e. after any `flipH` / `flipV` — so `(zoomX, zoomY)` always points to the same spot on the dashboard widget regardless of how the camera is mounted.

## Streams

| Stream | Description |
|--------|-------------|
| `video` | Base64 JPEG frames from RTSP stream at configured FPS |
| `snapshot` | Base64 JPEG emitted once per `snapshot()` call — exactly the frame that was returned to the caller |

### Debugging AI-vision with the `snapshot` stream

The `snapshot` stream pushes one frame per `snapshot()` call. Bind a Canvas widget to `<connector>:snapshot` (config field `stream: "camera:snapshot"`, mode `image`) to see exactly the frame your AI/vision pipeline received — useful when an AI's description doesn't match what's currently on screen. The lag is usually in the camera's H.264 GOP / B-frame settings, not the driver: the snapshot you see in the widget *is* the snapshot the AI got, so any stale-looking frames are real and the AI isn't hallucinating.

## Config Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `ip` | string | "" | Camera IP address (required) |
| `port` | int | 80 | ONVIF service port |
| `username` | string | "" | Authentication username |
| `password` | string | "" | Authentication password |
| `profile` | int | 0 | Media profile index (0 = main stream) |
| `fps` | int | 10 | Target capture framerate (1–30) |
| `quality` | int | 75 | JPEG encoding quality (1–100) |
| `flipH` | bool | false | Mirror frames horizontally |
| `flipV` | bool | false | Flip frames vertically |
| `digitalZoom` | double | 1.0 | Initial software zoom factor (1.0–16.0) |
| `zoomX` | double | 0 | Initial horizontal pan of the zoom crop (-1..1) |
| `zoomY` | double | 0 | Initial vertical pan of the zoom crop (-1..1) |

## Latency

The driver is configured for low-latency RTSP capture: FFmpeg runs with `nobuffer | low_delay | framedrop=1 | analyzeduration=0 | probesize=32768 | max_delay=0 | reorder_queue_size=0` and OpenCV's internal buffer is requested at size 1. The capture loop drains decoder output as fast as frames arrive and only encodes one out of every (rate ÷ `fps`) frames — so increasing `fps` does **not** increase latency, it just emits more of the frames the decoder is already producing.

Most remaining glass-to-screen delay (typically 0.5–1.5 s) comes from the camera's H.264 encoder GOP / B-frame settings and the browser's MJPEG decode pipeline, not from this driver. To reduce it further:

- Use the **substream** profile (`profile: 1` if available) — usually 480p with a shorter GOP, often half the latency of the main stream.
- In the camera's own UI, set GOP to ≤ 1× framerate, disable B-frames, and prefer CBR over VBR.
- Keep the camera on a wired LAN segment; Wi-Fi adds 50–200 ms of jitter buffer at the camera or router.

## Video Recording

The ONVIF driver supports video recording to `workspace/data/recordings/`. A `filename` is a plain name inside that folder: one that would land elsewhere (`../x`, an absolute path) fails with `PATH_OUTSIDE_WORKSPACE`. See also [Webcam](https://docs.muxit.io/reference/drivers/webcam.md) which shares the same recording interface.

Recording needs a **Maker license or higher**. On Free, `record` and `recordStart` fail with `VIDEO_RECORDING_REQUIRES_MAKER`; streaming and snapshots are unaffected.

**Recording Actions:**

| Action | Args | Returns | Description |
|--------|------|---------|-------------|
| `record` | `seconds`, `filename?` | filename | Record for N seconds (blocks until done) |
| `recordStart` | `filename?` | filename | Start recording (manual stop) |
| `recordStop` | — | filename | Stop recording, finalize file |

**Recording Property:**

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `recording` | `bool` | R | Whether recording is active |

- Output format: MP4 (MP4V codec), falls back to AVI (MJPEG) if codec unavailable
- Auto-starts the camera stream if not already streaming
- Filename is auto-generated (`Onvif_{timestamp}.mp4`) if not specified

```javascript
// From a script
const cam = connector('camera');
const file = cam.record({ seconds: 20 });           // duration-based
cam.recordStart({ filename: "experiment-1" });       // manual start
const result = cam.recordStop();                     // manual stop
```

## Example Connector

```javascript
// workspace/connectors/camera.js
export default {
  driver: "Onvif",
  config: {
    ip: "192.168.1.100",
    port: 80,
    username: "admin",
    password: "password",
    profile: 0,
    fps: 10,
  },
  poll: ["connected", "streaming", "resolution"],

  methods: {
    lookLeft:  { fn: () => driver.ptzMove({ pan: -0.5, tilt: 0, zoom: 0 }), description: "Pan left" },
    lookRight: { fn: () => driver.ptzMove({ pan: 0.5, tilt: 0, zoom: 0 }),  description: "Pan right" },
    zoomIn:    { fn: () => driver.ptzMove({ pan: 0, tilt: 0, zoom: 0.5 }),  description: "Zoom in" },
    zoomOut:   { fn: () => driver.ptzMove({ pan: 0, tilt: 0, zoom: -0.5 }), description: "Zoom out" },
    stopMove:  { fn: () => driver.ptzStop(), description: "Stop PTZ movement" },
  },
};
```

> **Note:** OpenCV native libraries ship with the Windows and linux-x64 builds. If no IP is configured, use the `discover` action to find cameras on your network.

## Platform notes

| Platform | RTSP capture | Streaming | flipH / flipV / digitalZoom | Recording | Snapshot while not streaming |
|----------|--------------|-----------|------------------------------|-----------|-------------------------------|
| Windows  | OpenCV (bundled FFmpeg) | ✅ | ✅ | ✅ | ✅ |
| linux-x64 | system `ffmpeg` + OpenCV | ✅ | ✅ | ✅ | ❌ — start streaming first |
| linux-arm64 (Raspberry Pi) | system `ffmpeg` only | ✅ (passthrough) | ❌ | ❌ | ❌ |
| macOS | system `ffmpeg` only (no OpenCV runtime yet) | ✅ (passthrough) | ❌ | ❌ | ❌ |

On Linux/macOS the driver delegates RTSP capture to the system `ffmpeg` binary (`sudo apt install ffmpeg`), which produces an MJPEG stream. When no per-frame transformation is requested (no flips, no `digitalZoom`, not recording), the driver streams those JPEGs straight through to the dashboard — no OpenCV decode/re-encode round-trip and no native dependency. This is what makes plain RTSP streaming work on Raspberry Pi (linux-arm64), where shimat does not publish a native `OpenCvSharp4` runtime.

If you enable `flipH`, `flipV`, `digitalZoom`, or start a recording on a platform without the OpenCV native bundle, the driver logs a one-time warning and the affected feature is unavailable until you disable it again. The `quality` property is honored only on the OpenCV path; in passthrough mode JPEG quality is fixed at ffmpeg's `-q:v 5` (≈70%). In practice plain streaming on a Raspberry Pi just works — install `ffmpeg`, point the driver at your camera, and the live feed appears in the dashboard.
