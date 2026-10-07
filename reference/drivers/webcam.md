---
title: Webcam Driver
description: Reference for the Webcam built-in driver — USB webcam/video capture using OpenCV.
---

# Webcam

**USB webcam/video capture** using OpenCV. Streams base64-encoded JPEG frames at a configurable framerate.

::: tip Safety gate
This driver ships with `requiresSafetyGates: false` — webcam writes and actions bypass the [safety gate](https://docs.muxit.io/guides/safety.md) entirely, and no audit rows are written. See [Per-driver opt-out](https://docs.muxit.io/guides/safety.md#per-driver-opt-out).
:::

## Properties

| Property | Type | Access | Unit | Description |
|----------|------|--------|------|-------------|
| `width` | int | R/W | px | Frame width |
| `height` | int | R/W | px | Frame height |
| `fps` | int | R/W | | Target framerate |
| `quality` | int | R/W | | JPEG quality (1–100) |
| `brightness` | int | R/W | | Brightness (0–100) |
| `contrast` | int | R/W | | Contrast (0–100) |
| `flipH` | bool | R/W | | Horizontal flip (mirror) |
| `flipV` | bool | R/W | | Vertical flip |
| `device` | int | R | | Camera device index |
| `streaming` | bool | R | | Whether capture is active |
| `resolution` | string | R | | Current resolution string (e.g., "640x480") |

## Actions

| Action | Args | Description |
|--------|------|-------------|
| `start` | — | Start video capture and streaming |
| `stop` | — | Stop video capture and streaming |
| `snapshot` | — | Capture a single frame, return as base64 JPEG |

## Streams

| Stream | Description |
|--------|-------------|
| `video` | Base64 JPEG frames at the configured FPS |

## Config Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `device` | int | 0 | Camera device index (0 = first camera) |
| `width` | int | 640 | Capture width in pixels |
| `height` | int | 480 | Capture height in pixels |
| `fps` | int | 15 | Target framerate |
| `quality` | int | 75 | JPEG quality (1–100) |
| `brightness` | int | 50 | Brightness (0–100) |
| `contrast` | int | 50 | Contrast (0–100) |

## Video Recording

The Webcam driver supports video recording to `workspace/data/recordings/`. A `filename` is a plain name inside that folder: one that would land elsewhere (`../x`, an absolute path) fails with `PATH_OUTSIDE_WORKSPACE`. See also [ONVIF](https://docs.muxit.io/reference/drivers/onvif.md) which shares the same recording interface.

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
- Filename is auto-generated (`Webcam_{timestamp}.mp4`) if not specified

## Example Connector

```javascript
// workspace/connectors/webcam.js
export default {
  driver: "Webcam",
  config: {
    device: 0,
    width: 1280,
    height: 720,
    fps: 15,
    quality: 80,
  },
  poll: ["streaming", "resolution"],
};
```

## Dashboard Integration

Display the webcam feed with a canvas widget:

```json
{
  "type": "canvas",
  "config": {
    "label": "Webcam",
    "mode": "image",
    "stream": "webcam:video"
  }
}
```

Take a snapshot from a script:

```javascript
const cam = connector("webcam");
cam.start();
const frame = cam.snapshot;  // base64 JPEG string
log.info(`Captured frame: ${frame.length} chars`);
```

> **Note:** Requires OpenCV native libraries, which ship bundled with the Windows build.
