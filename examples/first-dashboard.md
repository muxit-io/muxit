---
title: "Your First Dashboard"
description: Step-by-step walkthrough of building a real-time dashboard with live widgets.
---

# Your First Dashboard

This walkthrough guides you through building a real-time dashboard with gauges, charts, sliders, and buttons — all bound to live device data.

## Prerequisites

- Muxit server running (`node start.js server `)
- The built-in **TestDevice** connector is available (it's always on)

## Step 1: Create a New Dashboard

In the Explorer sidebar, click **New Dashboard** in the toolbar (or right-click in `dashboards/` and choose **New Dashboard**). Name it `my-dashboard`.

This creates `workspace/dashboards/my-dashboard.dashboard.json` and opens the dashboard editor.

Alternatively, create the file manually:

```json
{
  "name": "My Dashboard",
  "widgets": []
}
```

Open the file and you'll see an empty dashboard grid.

## Step 2: Add a Gauge Widget

Click the **edit** button (pencil icon) to enter edit mode, then click the **add** button (+ icon) to open the widget palette. Select **gauge**.

A gauge widget appears on the grid. Click it to open its configuration panel and set:

| Setting | Value |
|---------|-------|
| **Label** | Temperature |
| **Connector** | test-device |
| **Property** | temperature |
| **Min** | 0 |
| **Max** | 100 |
| **Unit** | °C |

The gauge immediately shows the test device's current temperature value, updating in real-time.

**Optional:** Add color zones to highlight ranges:
- 0–30: green (normal)
- 30–60: yellow (warm)
- 60–100: red (hot)

## Step 3: Add a Text Widget

Add a **text** widget and configure it:

| Setting | Value |
|---------|-------|
| **Label** | Device Label |
| **Connector** | test-device |
| **Property** | label |

This displays the test device's label as text. Since `label` is read/write, you can also set it from scripts.

## Step 4: Add a Slider Widget

Add a **slider** widget — this is interactive! Configure it:

| Setting | Value |
|---------|-------|
| **Label** | Threshold |
| **Connector** | test-device |
| **Property** | threshold |
| **Min** | 0 |
| **Max** | 100 |
| **Step** | 1 |

Drag the slider and the test device's `threshold` property changes in real-time. Other scripts and widgets that read `threshold` see the new value immediately.

## Step 5: Add a Chart Widget

Add a **chart** widget for time-series data:

| Setting | Value |
|---------|-------|
| **Label** | Temperature History |
| **Bindings** | test-device.temperature |
| **Duration** | 30 (seconds of history to show) |
| **Y Min** | 0 |
| **Y Max** | 100 |
| **Unit** | °C |

The chart plots temperature values over time, auto-scrolling as new data arrives. You can add multiple bindings to plot several properties on the same chart.

## Step 6: Add a Button Widget

Add a **button** widget to trigger device actions:

| Setting | Value |
|---------|-------|
| **Label** | Reset Device |
| **Connector** | test-device |
| **Action** | reset |
| **Color** | (pick a color, e.g. red) |

Click the button on the dashboard and the test device resets to defaults — temperature goes back to 22.5°C, counter resets to 0, label resets to "Test Device".

## Step 7: Add a Toggle Widget

Add a **toggle** widget for boolean properties:

| Setting | Value |
|---------|-------|
| **Label** | Enabled |
| **Connector** | test-device |
| **Property** | enabled |

The toggle shows a switch that reflects the device's `enabled` state. Click it to toggle on/off.

## Step 8: Arrange the Layout

In edit mode:
- **Drag** widgets to reposition them on the 12-column grid
- **Resize** by dragging the bottom-right corner handle
- **Delete** a widget by selecting it and pressing Delete

A suggested layout:

```
┌──────────┬──────────┬──────────┐
│  Gauge   │  Text    │  Toggle  │
│  (temp)  │  (label) │ (enabled)│
├──────────┴──────────┴──────────┤
│        Chart (temperature)     │
├──────────┬─────────────────────┤
│  Slider  │      Button         │
│(threshold)│     (reset)        │
└──────────┴─────────────────────┘
```

Click the edit button again to exit edit mode and use your dashboard.

## Step 9: Run a Script

Open `scripts/examples/sinewave.js` in the editor and click **Run**. This script writes sine-derived values to the **test-device** connector, so any widget bound to `test-device.temperature` or `test-device.threshold` animates live.

For a direct test, create a quick script `scripts/dashboard-test.js`:

```javascript
const dev = connector("test-device");

while (true) {
  // Slowly ramp temperature up and down
  for (let t = 20; t <= 80; t += 2) {
    dev.temperature = t;
    delay(200);
  }
  for (let t = 80; t >= 20; t -= 2) {
    dev.temperature = t;
    delay(200);
  }
}
```

Run this script and watch your dashboard come alive — the gauge sweeps, the chart draws a wave, and the temperature value updates continuously.

## Complete Dashboard JSON

Here's the full dashboard combining all the widgets above:

```json
{
  "name": "My Dashboard",
  "version": 1,
  "gridCols": 12,
  "rowHeight": 40,
  "widgets": [
    {
      "id": "w1",
      "type": "gauge",
      "layout": { "x": 0, "y": 0, "w": 4, "h": 4 },
      "config": {
        "label": "Temperature",
        "binding": "test-device.temperature",
        "min": 0,
        "max": 100,
        "unit": "°C",
        "zones": [
          { "min": 0, "max": 30, "color": "var(--success)" },
          { "min": 30, "max": 60, "color": "var(--warning)" },
          { "min": 60, "max": 100, "color": "var(--error)" }
        ]
      }
    },
    {
      "id": "w2",
      "type": "text",
      "layout": { "x": 4, "y": 0, "w": 4, "h": 2 },
      "config": {
        "label": "Device Label",
        "binding": "test-device.label"
      }
    },
    {
      "id": "w3",
      "type": "toggle",
      "layout": { "x": 8, "y": 0, "w": 4, "h": 2 },
      "config": {
        "label": "Enabled",
        "binding": "test-device.enabled"
      }
    },
    {
      "id": "w4",
      "type": "chart",
      "layout": { "x": 0, "y": 4, "w": 12, "h": 4 },
      "config": {
        "label": "Temperature History",
        "bindings": ["test-device.temperature"],
        "duration": 30,
        "yMin": 0,
        "yMax": 100,
        "unit": "°C"
      }
    },
    {
      "id": "w5",
      "type": "slider",
      "layout": { "x": 0, "y": 8, "w": 6, "h": 2 },
      "config": {
        "label": "Threshold",
        "binding": "test-device.threshold",
        "min": 0,
        "max": 100,
        "step": 1
      }
    },
    {
      "id": "w6",
      "type": "button",
      "layout": { "x": 6, "y": 8, "w": 3, "h": 2 },
      "config": {
        "label": "Reset Device",
        "binding": "test-device.reset",
        "activeColor": "#f44336"
      }
    },
    {
      "id": "w7",
      "type": "indicator",
      "layout": { "x": 4, "y": 2, "w": 4, "h": 2 },
      "config": {
        "label": "Streaming",
        "binding": "test-device.streaming"
      }
    }
  ]
}
```

## Adding More Widget Types

Beyond what we used above, Muxit offers these additional widgets:

| Widget | Use Case | Example |
|--------|----------|---------|
| **knob** | Rotary dial for numeric values | Fine-tuning a voltage setpoint |
| **indicator** | LED-style status light | Show whether a device is connected |
| **canvas** | Video/image stream display | Webcam feed, generated visualizations |
| **terminal** | Scrolling text with input field | Serial monitor, G-code console |
| **object-viewer** | JSON tree view | Inspect complex device state |
| **script-control** | Start/stop button for a script | One-click automation |
| **label** | Static text, may embed `${connector.property}` | Screen title, "Fixture: FX-220" |
| **image** | Logo or photo from `workspace/assets/` | Company branding, a fixture reference photo |
| **divider** | Horizontal or vertical rule | Separating regions of a dashboard |
| **select** | Pick a value and write it to a property | Choosing a fixture type on a production line |
| **input** | Type or scan a value into a property | Serial number entry with a barcode scanner |
| **status-banner** | Huge colour-filled PASS/FAIL block | Test result readable across a workshop |
| **progress** | Determinate or indeterminate progress bar | How far through a programming cycle |
| **steps** | Checklist of process stages with live status | Multi-stage test sequence |

## Next Steps

- See the full [Dashboard Guide](https://docs.muxit.io/guides/dashboards.md) for all widget types and configuration options
- Learn about the [Virtual Store Pattern](https://docs.muxit.io/guides/dashboards.md#virtual-store-pattern) for bridging scripts to dashboards
- Try [cross-panel drag-and-drop](https://docs.muxit.io/guides/dashboards.md#cross-panel-drag-and-drop) for quick widget setup
- Build a [connector](https://docs.muxit.io/examples/first-connector.md) for real hardware and display it on your dashboard
