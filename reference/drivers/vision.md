---
title: Vision Driver
description: Reference for the Vision built-in driver — real-time computer vision with OpenCV for object detection and tracking.
---

# Vision

**Real-time computer vision** using OpenCV. Processes camera frames locally for color and contour detection at 30+ fps. Designed for vision-guided robot control.

The Vision driver subscribes to a camera connector's video stream via EventBus, runs detection pipelines per-frame, and exposes results as properties. It is a self-contained **engine** — it also carries the AI-vision intelligence (object identification, spatial calibration, taught-object persistence) as its own actions, calling the model through the host's AI capability. There are no separate "vision tools" in the core server anymore: the AI reaches everything below through the generic device-control tools (`call_action` / `read_property`) against your Vision connector, plus the generic `take_snapshot` for looking at any camera.

::: tip License Required
The Vision driver requires the `vision` entitlement.
:::

## Properties

| Property | Type | Access | Unit | Description |
|----------|------|--------|------|-------------|
| `trackers` | string | R | | JSON array of active tracker configs |
| `detections` | string | R | | JSON object of latest detection results keyed by tracker name |
| `frameWidth` | int | R | px | Width of processed frames |
| `frameHeight` | int | R | px | Height of processed frames |
| `processing` | bool | R | | Whether vision pipeline is running |
| `fps` | double | R | | Actual processing framerate |
| `source` | string | R | | Camera connector name |

## Actions

| Action | Args | Description |
|--------|------|-------------|
| `start` | — | Start processing frames from source camera |
| `stop` | — | Stop processing frames |
| `addTracker` | `name`, `type`, `params` | Add a detection tracker |
| `removeTracker` | `name` | Remove a tracker by name |
| `clearTrackers` | — | Remove all trackers |
| `snapshot` | — | Capture annotated frame with detection overlays as base64 JPEG |
| `calibrateColor` | `x`, `y`, `radius?` | Sample a pixel region and return suggested HSV range |

### AI-vision actions

These call the model through the host (image input requires the `image-analysis` feature — Maker and above). The camera is always this engine's own `source` — none of them take a camera argument.

| Action | Args | Description |
|--------|------|-------------|
| `identifyObjects` | `query?` | Detect objects in the current frame; returns a JSON array of names + pixel centers + sizes + confidence. Omit `query` to list everything. |
| `locateObject` | `object_name` | Find one object; returns its pixel position, plus world X/Y/Z when the camera is calibrated (otherwise normalized coords + quadrant). |
| `teachObject` | `name`, `pixel_x`, `pixel_y`, `width?`, `height?`, `description?`, `tracker_type?` | Sample the colour at a pixel, persist a profile, and create a real-time tracker (restored on restart). No LLM needed. |
| `forgetObject` | `name` | Delete a learned profile and its tracker. |
| `listObjects` | — | List learned profiles. |
| `calibrate` | `action` (`start`/`point`/`finish`/`status`), `pixel_x?`, `pixel_y?`, `world_x?`, `world_y?`, `world_z?` | Teach a pixel→world affine transform (≥3 points), persisted per camera. |
| `approach` | `object_name`, `step_size?` | Visual-servoing guidance: normalized error from frame center + a suggested dx/dy move. Uses the fast tracker when available, else AI detection. |

State (learned profiles + calibrations) persists under the connector instance's host state directory (`workspace/config/drivers/<instance>/`).

## Streams

| Stream | Description |
|--------|-------------|
| `annotated` | Base64 JPEG frames with detection overlays (bounding boxes, centroids, labels) |

## Config Options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `source` | string | Yes | Camera connector name to process frames from (e.g. `"webcam"`) |

## Tracker Types

### Color Tracker (HSV)

Filters pixels by hue/saturation/value range, finds the largest matching region. Best for tracking brightly colored objects (red ball, green LED, blue cap).

**Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `hLow` | int | 0 | Minimum hue (0-179) |
| `sLow` | int | 100 | Minimum saturation (0-255) |
| `vLow` | int | 100 | Minimum value/brightness (0-255) |
| `hHigh` | int | 179 | Maximum hue (0-179) |
| `sHigh` | int | 255 | Maximum saturation (0-255) |
| `vHigh` | int | 255 | Maximum value/brightness (0-255) |
| `minArea` | int | 100 | Minimum contour area in pixels |

**Example:**

```javascript
vision.addTracker({
  name: "red-ball",
  type: "color",
  params: { hLow: 0, sLow: 120, vLow: 100, hHigh: 10, sHigh: 255, vHigh: 255 }
});
```

### Contour Tracker

Edge detection + contour finding. Returns the largest contour matching area and aspect ratio constraints. Best for tracking shapes regardless of color (parts, tools, containers).

**Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `minArea` | int | 500 | Minimum contour area in pixels |
| `maxArea` | int | unlimited | Maximum contour area |
| `minAspect` | double | 0 | Minimum width/height ratio |
| `maxAspect` | double | unlimited | Maximum width/height ratio |

**Example:**

```javascript
vision.addTracker({
  name: "large-part",
  type: "contour",
  params: { minArea: 1000, maxArea: 50000, minAspect: 0.5, maxAspect: 2.0 }
});
```

## Detection Result Format

Each tracker produces a detection result:

```json
{
  "found": true,
  "x": 150,
  "y": 200,
  "width": 80,
  "height": 60,
  "cx": 190.5,
  "cy": 230.2,
  "area": 3200,
  "angle": 15.3
}
```

| Field | Description |
|-------|-------------|
| `found` | Whether the object was detected |
| `x`, `y` | Bounding box top-left corner (pixels) |
| `width`, `height` | Bounding box size (pixels) |
| `cx`, `cy` | Centroid coordinates (pixels) |
| `area` | Contour area (pixels) |
| `angle` | Rotation angle from minimum-area rectangle |

## Color Calibration

Use `calibrateColor` to sample a pixel region and get suggested HSV ranges for a color tracker. This is the easiest way to set up color tracking — point at the object and sample it.

```javascript
const vision = connector("vision");

// Sample a 10px radius around pixel (320, 240)
const hsv = JSON.parse(vision.calibrateColor({ x: 320, y: 240, radius: 10 }));
// Returns: { hLow: 5, sLow: 110, vLow: 80, hHigh: 25, sHigh: 255, vHigh: 255 }

// Use the result to create a tracker
vision.addTracker({
  name: "sampled-object",
  type: "color",
  params: hsv
});
```

## Teaching Objects

Objects can be taught to the vision system in two ways:

1. **AI-guided teaching** — Tell the AI to teach the object. It identifies and locates it, then calls `teachObject` on the vision connector to sample color and create a tracker. Best when the object is hard to manually point at.

2. **Direct annotation** — Draw a bounding box directly on the camera feed in the dashboard. Set `visionConnector` on a canvas widget, then use the Draw tool to box objects. Faster and free (no API cost). The `vision.teach` / `vision.forget` / `vision.list` WebSocket messages delegate to the engine's `teachObject` / `forgetObject` / `listObjects` actions.

Both methods produce the same result: a persistent object profile under the connector instance's state directory (`workspace/config/drivers/<instance>/objects.json`) with HSV bounds, area, and aspect ratio. Trackers are automatically restored on server restart.

## Example Connector

```javascript
// workspace/connectors/vision.js
export default {
  driver: "Vision",
  source: "webcam",

  ai: {
    instructions: "Computer vision processor. Use sampleColor to calibrate HSV ranges before adding color trackers. Safe to query detections freely.",
  },

  methods: {
    trackColor: {
      fn: (name, hLow, sLow, vLow, hHigh, sHigh, vHigh) =>
        driver.addTracker({ name, type: "color", params: { hLow, sLow, vLow, hHigh, sHigh, vHigh } }),
      description: "Add a color tracker by HSV range",
    },
    trackContour: {
      fn: (name, minArea, maxArea) =>
        driver.addTracker({ name, type: "contour", params: { minArea, maxArea: maxArea || 999999 } }),
      description: "Add a contour tracker by area range",
    },
    find: {
      fn: (name) => {
        const all = JSON.parse(driver.detections);
        return all[name] || { found: false };
      },
      description: "Get detection result for a named tracker",
    },
    sampleColor: {
      fn: (x, y, radius) => driver.calibrateColor({ x, y, radius: radius || 10 }),
      description: "Sample HSV color range at a pixel coordinate",
    },
  },

  properties: {
    objects: {
      get: () => driver.detections,
      description: "All detected objects (JSON)",
      poll: true,
    },
  },

  poll: ["fps", "processing"],
};
```

## Dashboard Integration

Display the annotated vision feed (camera + detection overlays):

```json
{
  "type": "canvas",
  "config": {
    "label": "Vision",
    "mode": "image",
    "stream": "vision:annotated",
    "visionConnector": "vision"
  }
}
```

Adding `visionConnector` enables the annotation overlay — users can draw bounding boxes directly on the feed to teach objects without AI.

### Pre-Built Dashboards

- **`vision.dashboard.json`** — Basic vision feed with status and controls
- **`vision-annotation.dashboard.json`** — Comprehensive annotation workbench with raw vs. annotated side-by-side feeds, FPS chart, live detections, and script controls for the multi-tracker and contour detection demos

### Demo Scripts

| Script | Description |
|--------|-------------|
| `demo/09-vision-tracking.js` | Color tracking basics — sample, track, poll |
| `demo/10-ai-vision.js` | AI-powered object identification |
| `demo/11-teach-and-track.js` | AI identifies objects, then track with fast CV |
| `demo/13-multi-tracker.js` | Multiple simultaneous color trackers across frame regions |
| `demo/14-contour-detection.js` | Contour (shape/edge) detection with size filtering |

## AI Vision Tools

The Vision driver works alongside AI-powered vision tools for a two-speed approach:

| Layer | Tool | Speed | Use For |
|-------|------|-------|---------|
| **Fast CV** | `call_action(vision, addTracker)` + `read_property(vision, detections)` | ~30 fps | Real-time tracking during motion |
| **AI Vision** | `call_action(vision, identifyObjects)` / `call_action(vision, locateObject)` | ~2-5s | Scene understanding, finding named objects |

See the [AI Guide](https://docs.muxit.io/guides/ai.md#vision-guided-robot-control) for the full vision workflow.
