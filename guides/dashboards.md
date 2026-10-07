---
title: Dashboard Guide
description: Building real-time dashboards with drag-and-drop widgets bound to device properties.
---

# Dashboard Guide

Dashboards are drag-and-drop layouts with live widgets that display real-time data from your devices.

## AI Generation

The AI chat can create and edit dashboards on request. Ask something like:

> *Build me a dashboard for the robot and the webcam — include a position viewer, a speed slider, a reset button, and a live camera feed.*

The AI discovers available connectors via `list_connectors` + `get_connector_schema`, writes a `.dashboard.json` file with `write_dashboard`, and drops it into `workspace/dashboards/` ready to open. Follow-ups like "add a chart of voltage" round-trip through `read_dashboard` → `write_dashboard` so existing widgets are preserved. The same three tools (`list_dashboards`, `read_dashboard`, `write_dashboard`) are exposed over MCP for Claude Desktop / Claude Code sessions.

## Creating a Dashboard

Create a `.dashboard.json` file in `workspace/dashboards/`:

```json
{
  "name": "Lab Monitor",
  "widgets": [
    {
      "id": "voltage-gauge",
      "type": "gauge",
      "layout": { "x": 0, "y": 0, "w": 4, "h": 3 },
      "config": {
        "binding": "psu.voltage",
        "label": "Voltage",
        "min": 0, "max": 30, "unit": "V"
      }
    }
  ]
}
```

Open the dashboard file in the app to see the live widget layout.

---

## Widget Types

### Presentation Widgets (static content)

These carry no connector binding — they are the furniture a production screen
needs around its live data.

| Type | Description | Key Config |
|------|-------------|------------|
| **label** | Static text for titles and callouts. `text` may embed live values as `${connector.property}` | `text`, `fontSize`, `weight`, `align`, `color`, `background` |
| **image** | A logo, diagram or photo. `src` is a path under `workspace/assets/`; a `binding` may supply the path instead, so the picture follows process state | `src`, `binding`, `fit`, `alt` |
| **divider** | Horizontal or vertical rule | `orientation`, `thickness`, `color` |

::: warning The Panel widget is temporarily unavailable
A panel was meant to be a frame drawn *behind* a group of widgets, but it is
handed to the layout engine as an ordinary widget, so in every mode except Free
it blocks widgets from being placed on it and cannot be dragged across one. It
has been withdrawn from the widget palette until it is rendered outside the
grid. Dashboards that already contain a panel keep working.
:::

#### Live values inside a label

A label's `text` resolves `${connector.property}` against live device state:

```json
{ "type": "label", "config": { "text": "Line 3 — Fixture: ${fixtures.type}", "fontSize": "large" } }
```

Three rules keep this predictable rather than turning into a template language:
substitution is **single-pass** (a value that itself contains `${...}` is inserted
literally, so reference cycles are impossible); an **unresolved reference renders
verbatim**, so a typo stays visible instead of silently blanking; and `$${`
escapes a literal `${`.

#### Images and `workspace/assets/`

Drop images in `workspace/assets/` and reference them by name — `"src": "logo.png"`,
sub-folders included (`"src": "fixtures/fx-220.png"`). They are served read-only
at `/api/assets/`, a route that is **always available**: unlike the file editor's
`/api/editor/raw/`, it does not require `security.editorMode`, so a locked-down
production machine keeps its branding. Allowed types: png, jpg, jpeg, gif, svg,
webp, bmp, ico, avif, mp4, webm, mp3, wav, ogg, pdf.

### Status Widgets (process readouts)

Built for a screen someone watches from across a room while a process runs.

| Type | Description | Key Config |
|------|-------------|------------|
| **status-banner** | Fills its whole area with one colour and one word. Text scales with the widget, so a bigger banner is genuinely more legible | `binding`, `states` |
| **progress** | Determinate bar from a bound value, or a continuous sweep when `indeterminate` is set | `binding`, `min`, `max`, `showPercent`, `color`, `indeterminate` |
| **steps** | Checklist of process stages with pass/fail/running icons | `binding`, `steps` |

#### Status banner colours

With no `states` map the banner still works — common production words are
recognised and coloured (`PASS`/`OK`/`DONE` green, `FAIL`/`ERROR`/`NG` red,
`RUNNING`/`BUSY`/`WAITING` amber). For anything else, map the values yourself:

```json
{
  "type": "status-banner",
  "config": {
    "binding": "fixture-line.status",
    "states": {
      "PASS": { "text": "PASS", "color": "var(--success)" },
      "FAIL": { "text": "FAIL", "color": "var(--error)", "blink": true }
    }
  }
}
```

#### Steps

Bind to an array of `{ name, status }` — status is `pending`, `running`,
`pass`, `fail` or `skip` — and have your script rewrite the array as it
advances. A plain array of names also works (all shown pending), as does a
static `steps: "Connect, Program, Test"` when there is nothing to bind yet.

### Display Widgets (read-only)

| Type | Description | Key Config |
|------|-------------|------------|
| **gauge** | Semi-circular gauge with needle and color zones | `min`, `max`, `unit`, `zones` |
| **text** | Formatted value display with label and unit | `label`, `unit` |
| **chart** | Line chart (uPlot). Scalar bindings auto-scroll as a time-series; array-valued bindings plot as XY curves (e.g. a spectrum) against `xBinding` | `bindings[]`, `xBinding`, `duration`, `yMin`, `yMax` |
| **scope** | Oscilloscope with built-in V/div, T/div knobs, Y-position, Run/Stop, Auto | `ch1`, `ch2`, `ch3`, `mode`, `persistence`, `lineWidth`, `gridLines` |
| **indicator** | LED-style on/off status indicator (red/green/amber) | `label` |
| **object-viewer** | Collapsible JSON tree view of complex data | `fontSize`, `decimals` |

### Interactive Widgets (read + write)

| Type | Description | Key Config |
|------|-------------|------------|
| **select** | Pick one value and write it to a property. `dropdown`, `segmented` or `radio` — the latter two are sized for gloved fingers on a touch panel | `binding`, `options`, `mode`, `placeholder` |
| **input** | Type or scan a value into a property. Commits on Enter and selects-all on focus, so barcode scanners work as-is | `binding`, `inputType`, `placeholder`, `commitOn`, `clearAfterCommit` |
| **slider** | Horizontal slider to set a numeric property | `min`, `max`, `step` |
| **knob** | Rotary dial with arc indicator, drag to change | `min`, `max` |
| **button** | Trigger an action on a connector (text auto-derived from binding) | `label`, `text`, `mode`, `activeColor`, action binding |
| **toggle** | On/off switch with LED-style indicator | boolean property binding |
| **script-control** | Start/stop button for a named script | `scriptName`, `text`, `activeColor` |

### Streaming Widgets

| Type | Description | Key Config |
|------|-------------|------------|
| **canvas** | Displays video/image streams; supports interactive vision annotation | `mode` ("image"), `stream`, `visionConnector` (optional) |
| **terminal** | Scrolling log with severity colouring, filter, scroll lock, copy and save. Lines starting `[ERROR]`, `[WARN]`, `[OK]` or `DEBUG` are coloured | `stream`, `maxLines`, `fontSize`, `sendAction`, `severity`, `showToolbar` |

---

## Widget Layout

Widgets are positioned on a 12-column grid via a nested `layout` object:

- `layout.x`, `layout.y` — grid position (columns, rows)
- `layout.w`, `layout.h` — size in grid units (width, height)

Drag widgets to reposition them. Resize by dragging the corner handle.

### Layout mode

How the grid reacts when a dragged widget meets an occupied cell, set per
dashboard via the top-level `compact` key (or **Layout** in the config panel):

| `compact` | Behaviour |
|-----------|-----------|
| `"vertical"` (default) | **Auto-stack.** Widgets are pushed aside and everything re-flows upward to close gaps. Quick to build with, but dragging across the board rearranges it. |
| `"none"` | **Fixed grid.** Nothing auto-stacks and nothing is pushed; a drag is simply refused over an occupied cell. |
| `"free"` | **Free.** Widgets may overlap and nothing is ever moved except the one you are dragging. Choose this if you want to place things exactly, or drag a widget *across* others to reach empty space. |

Free is also the mode to pick when widgets need to overlap deliberately — for
instance sitting on top of one another to build a composite readout.

### Selecting overlapping widgets

In Free layout widgets can sit on top of each other, and a plain click only ever
reaches the topmost one. **Alt-click** (option-click on a Mac) cycles downward
through everything under the pointer.

---

### Undo, redo and delete

While editing, **Ctrl+Z** (Cmd+Z on a Mac) undoes the last change — a move, a resize, a
configuration edit, an added or deleted widget — and **Ctrl+Shift+Z** or **Ctrl+Y** redoes it.
A drag counts as one step, as does typing into a field. **Delete Widget** asks first and reminds
you of the shortcut. History lives in the editor session: saving keeps the dashboard as it is,
and leaving edit mode or opening another dashboard starts fresh.

## Widget Style

Every widget is drawn on a background with a border — a "card". That suits a
gauge and looks wrong around a divider or a title, so the style is a cascade,
set at three levels:

1. the widget's own `config.chrome`
2. the widget **type's** default — `label`, `image` and `divider` ship as
   `none`, because furniture never looks better in a box
3. the dashboard's `style.chrome`, else `card`

```json
{
  "name": "Line 3",
  "style": { "chrome": "flat" },
  "widgets": [
    { "type": "gauge", "config": { "chrome": "card" } }
  ]
}
```

| Mode | Appearance |
|------|------------|
| `card` | Background and border (the default) |
| `flat` | Background only, no border |
| `none` | Fully transparent |

A widget type's default deliberately outranks the dashboard setting: switching a
dashboard to `card` boxes up the gauges without putting a box back around the
divider. Set `config.chrome` on the widget to override anything.

---

## Data Binding

Widgets bind to connector properties via the `config` object:

- `binding` — the property path, `"connector.property"` (e.g., `"psu.voltage"`). Array elements
  use an index suffix: `"robot.position[0]"`.
- `bindings` — an array of such paths, for widgets that plot more than one series (chart, scope).

Properties with `poll: true` in the connector config update the widget automatically.

### Chart XY (array) mode

A **chart** widget normally plots scalar bindings as a rolling time-series. If a binding instead
resolves to an **array** (for example a spectrometer's `spectrum` or `irradiance`), the chart switches
to XY-curve mode and plots each array as a full curve. Use the optional `xBinding` field to supply the
X-axis array (e.g. `avantes.wavelengths`); if it is omitted, the sample index `0…N-1` is used. Multiple
array bindings share the single `xBinding` and render as separate curves.

```json
{
  "type": "chart",
  "config": {
    "label": "Spectrum",
    "bindings": ["avantes.irradiance"],
    "xBinding": "avantes.wavelengths",
    "yMin": 0,
    "unit": "uW/nm"
  }
}
```

### Stream Binding

For canvas and terminal widgets, use a `stream` config to subscribe to real-time data:

```json
{
  "type": "canvas",
  "config": {
    "label": "Webcam",
    "mode": "image",
    "stream": "webcam:frames"
  }
}
```

### Terminal Send Input

Terminal widgets are bidirectional — the scrolling display shows a stream and, when a `sendAction` binding is set, an input bar appears below it. Pressing Enter invokes the bound connector action with the typed text.

```json
{
  "type": "terminal",
  "config": {
    "label": "Serial Monitor",
    "stream": "serial-monitor:output",
    "sendAction": "serial-monitor.sendLine"
  }
}
```

Drag a connector action (e.g. `serial-monitor.sendLine` or `gcode.send`) onto the `sendAction` field to wire it up. The input bar is hidden when `sendAction` is empty — so existing read-only terminals stay unchanged.

### Vision Annotation

To enable direct object teaching on a canvas widget, add `visionConnector` to the config:

```json
{
  "type": "canvas",
  "config": {
    "label": "Vision Trainer",
    "mode": "image",
    "stream": "vision:annotated",
    "visionConnector": "vision"
  }
}
```

When `visionConnector` is set, an annotation toolbar appears on the canvas. Users can draw bounding boxes to teach objects, click labels to select, and delete tracked objects — all without AI. See the [AI guide](https://docs.muxit.io/guides/ai.md#direct-vision-annotation) for the full workflow.

A pre-built **Vision Annotation** dashboard (`vision-annotation.dashboard.json`) demonstrates the full annotation workflow with side-by-side raw and annotated feeds, FPS monitoring, live detection data, and script controls for the multi-tracker and contour detection demos.

### Script Control Binding

Script control widgets bind to a script by name:

```json
{
  "type": "script-control",
  "config": {
    "scriptName": "monitor",
    "text": "Monitor",
    "activeColor": "#4caf50"
  }
}
```

---

## Operator Chat

A dashboard shown on an [operator station](https://docs.muxit.io/guides/operator-mode.md) can carry an
**Ask** panel — a read-only AI assistant that explains readings, scripts and
instrument manuals but cannot change anything. It is opt-in **per dashboard**:
tick **Operator chat** in the config panel's Dashboard section, which writes a
top-level `"chat": true` into the file.

```json
{
  "name": "Repair bench",
  "chat": true,
  "widgets": [ ]
}
```

Only dashboards under `dashboards/operator/` show the button, and the server
accepts operator chat only while at least one of them carries the flag. A wall
display on the same station simply leaves it off.

---

## Dashboard JSON Format

Full example with multiple widget types:

```json
{
  "name": "Robot Control Panel",
  "version": 1,
  "gridCols": 12,
  "rowHeight": 40,
  "widgets": [
    {
      "id": "w1",
      "type": "gauge",
      "layout": { "x": 0, "y": 0, "w": 3, "h": 4 },
      "config": {
        "label": "Joint 1 Angle",
        "binding": "robot.joints[0]",
        "min": -180, "max": 180, "unit": "°",
        "zones": [
          { "min": -180, "max": -90, "color": "var(--error)" },
          { "min": -90, "max": 90, "color": "var(--success)" },
          { "min": 90, "max": 180, "color": "var(--error)" }
        ]
      }
    },
    {
      "id": "w2",
      "type": "chart",
      "layout": { "x": 3, "y": 0, "w": 6, "h": 4 },
      "config": {
        "label": "Position History",
        "bindings": ["robot.position[0]", "robot.position[1]", "robot.position[2]"],
        "duration": 30,
        "yMin": -500, "yMax": 500, "unit": "mm"
      }
    },
    {
      "id": "w-scope",
      "type": "scope",
      "layout": { "x": 3, "y": 4, "w": 8, "h": 7 },
      "config": {
        "label": "Waveform",
        "ch1": "sensor.voltage",
        "ch2": "sensor.current",
        "mode": "scroll",
        "persistence": 0.4,
        "lineWidth": 1.5,
        "gridLines": true
      }
    },
    {
      "id": "w3",
      "type": "terminal",
      "layout": { "x": 0, "y": 4, "w": 6, "h": 4 },
      "config": {
        "stream": "serial-monitor:output",
        "maxLines": 500,
        "fontSize": "medium",
        "showTimestamps": true,
        "sendAction": "serial-monitor.sendLine"
      }
    }
  ]
}
```

---

## Editing

- **Edit mode**: Click the edit button to toggle layout editing
- **Add widgets**: Click the add button and select a widget type
- **Configure**: Click a widget to edit its config (connector, property, appearance)
- **Delete**: Select a widget and press Delete or use the remove button
- **Save**: Changes are saved to the `.dashboard.json` file automatically

---

## Virtual Store Pattern

Use a [Virtual](https://docs.muxit.io/reference/drivers/virtual.md) connector — an in-memory store with no hardware — to bridge scripts and dashboards. No `driver:` keyword is needed:

```javascript
// workspace/connectors/store.js
let value1 = 0;
let input = 50;

export default {
  properties: {
    value1: { get: () => value1, set: (v) => { value1 = Number(v); }, poll: true },
    input:  { get: () => input,  set: (v) => { input = Number(v); },  poll: true },
  },
};
```

Bind a gauge to `store.value1` and a slider to `store.input`. Scripts write: `store.value1 = 42` → the gauge updates immediately. Values live in memory only and reset when the server restarts.

---

## Cross-Panel Drag-and-Drop

| Drag Source | Drop Target | Result |
|---|---|---|
| Hardware property (from Connector Browser) | Widget on dashboard canvas | Sets widget binding automatically (on a chart: adds it to `bindings`) |
| Hardware stream | Canvas/Video widget on dashboard canvas | Sets stream + switches to image mode |
| Hardware property (from Connector Browser) | Binding field in config panel | Sets widget binding |
| Hardware stream | Stream field in config panel | Sets stream binding |
| Script (from Scripts panel) | Dashboard grid, in edit mode | Creates script-control widget |
| Hardware property | Script editor | Inserts `connector("x").prop` code |
