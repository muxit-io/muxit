---
title: UI Tour
description: A visual tour of the Muxit web interface — panels, sidebars, editors, and where to find everything.
---

# UI Tour

Muxit's web interface looks like a code editor (similar to VS Code), but it's designed for hardware control. Here's what each part does.

## Layout Overview

```
┌──────────────────────────────────────────────────────────┐
│                      Title Bar                           │
├───┬──────────┬───────────────────────┬───────────────────┤
│   │          │                       │                   │
│ A │  Left    │     Editor Area       │    Right          │
│ c │  Sidebar │   (scripts, configs,  │    Sidebar        │
│ t │          │    dashboards)        │   (AI Chat)       │
│ i │ Explorer │                       │                   │
│ v │   or     │                       │                   │
│ i │ Hardware │                       │                   │
│ t │          │                       │                   │
│ y │          ├───────────────────────┤                   │
│   │          │    Bottom Panel       │                   │
│ B │          │   (Logs / Output)     │                   │
│ a │          │                       │                   │
│ r │          │                       │                   │
├───┴──────────┴───────────────────────┴───────────────────┤
│                      Status Bar                          │
└──────────────────────────────────────────────────────────┘
```

---

## Activity Bar (Left Edge)

The vertical strip of icons on the far left. Click an icon to open its corresponding sidebar panel.

| Icon | Panel | What It Does |
|------|-------|-------------|
| **Files** | Explorer | Browse and manage your workspace files |
| **Plug** | Hardware | View connected devices and their live state |
| **Chat** | AI Chat | Natural language control, agents, and memory |
| **Gear** (bottom) | Settings | Configure AI, voice, remote access, licensing |

You can drag icons to reorder them.

---

## Explorer Sidebar

The Explorer is your file manager for the workspace. It shows all your scripts, connectors, dashboards, and agents organized by type.

### File Tree

```
WORKSPACE
├── connectors/       ← Device configurations (.js)
│   ├── test-device.js
│   ├── webcam.js
│   └── ...
├── scripts/          ← Automation scripts (.js)
│   ├── hello.js
│   ├── webcam-snapshot.js
│   ├── examples/
│   └── ...
├── dashboards/       ← Dashboard layouts (.dashboard.json)
│   ├── demo.dashboard.json
│   └── ...
├── agents/           ← Agent configs (.agent.json)
│   └── temperature-monitor.agent.json
├── drivers/          ← Custom drivers (.driver.js)
│   └── ...
└── config/           ← Server configuration
    └── server.json
```

### Toolbar Actions

- **New Script** — Create a new `.js` file in `scripts/`
- **New Dashboard** — Create a new `.dashboard.json` file in `dashboards/`
- **Refresh** — Reload the file list from disk

### Special Sections

- **FAVORITES** — Files you've starred appear here for quick access
- **RUNNING** — Currently executing scripts appear here with a stop button

### Inline Actions

Each file in the Explorer shows context-appropriate actions:

- **Scripts:** Play/Stop buttons to run or stop the script
- **Dashboards:** Show button to open the live dashboard view
- **All files:** Star button to add to favorites

---

## Hardware Panel

Click the plug icon in the Activity Bar to open the Hardware panel. This is your device control center.

### What You See

For each enabled connector:
- **Name** and **driver** type
- **Live property values** — updated automatically via polling
- **Actions** — buttons to execute device actions
- **Streams** — available data streams (video, sensor data)

### Managing Connectors

- **Enable/Disable** — Check or uncheck connectors (within your license tier limit)
- **Add Connector** — Click the "+" button to create a new connector from a driver template
- **Reload** — Reload all connector configs from disk (useful after editing files)

### State Indicators

Properties with polling enabled show live values that update automatically. Values change in real-time as the hardware state changes (or as the TestDevice simulates changes).

---

## Editor Area

The center of the screen is the editor, where you write scripts, edit connector configs, and view dashboards.

### Tabs

Each open file gets a tab. You can:
- **Click** a tab to switch to it
- **Drag** tabs to reorder them
- **Close** tabs with the X button
- **Split** the editor into multiple groups (side-by-side editing)

### Script Editing

When editing a `.js` script file:
- **Run** button in the toolbar — execute the script
- **Stop** button — stop a running script
- **Autocomplete** — type `connector(` to see device names, `dev.` to see properties and actions, `log.` for logging methods

### Dashboard Editing

When you open a `.dashboard.json` file, you see the live dashboard with widgets. Toggle **edit mode** to:
- **Add widgets** from the widget palette
- **Drag** widgets to reposition them on the grid
- **Resize** widgets by dragging the corner handle
- **Configure** widgets by clicking them (set bindings, labels, colors, ranges)
- **Delete** widgets with the Delete key or remove button

Changes are saved automatically to the JSON file.

### CSV Charts

Opening a `.csv` or `.tsv` file (for example, one written by a measurement script via `connector('files').openText('runs/log.csv').append([...])`) renders it as an interactive line chart. Use the control strip above the chart to:

- **Chart / Text toggle** — switch between the chart and the raw Monaco text view. The text view keeps the usual undo/redo/save controls so small edits are still possible.
- **X-axis dropdown** — pick any column as the X-axis, or fall back to the row index. Timestamp columns are auto-detected and switch the X-axis to a time scale.
- **Series checkboxes** — toggle which numeric columns are plotted.

The parser auto-detects the delimiter (`,`, `;`, or tab) and whether the first row is a header. Files larger than 100 000 rows are rendered with only the first 100 000 for responsiveness (a banner shows the full row count).

---

## Bottom Panel (Output / Logs)

Toggle with `Ctrl+J`. Shows two types of output:

### Script Output

When a script runs, its `log.info()`, `log.warn()`, `log.error()`, and `log.debug()` messages appear here with timestamps. Each script's output is labeled with its name.

### Server Logs

System-level messages from the Muxit server — driver initialization, connection events, errors. Useful for diagnosing issues.

You can clear logs with the trash icon.

---

## AI Chat Sidebar

Click the chat icon in the Activity Bar to open the right sidebar. It has multiple tabs:

### Chat Tab

Type natural language commands to control your devices:
- *"Set the voltage to 12V"*
- *"Read the temperature"*
- *"Write a script that monitors current"*

The AI calls device tools to fulfill your request. In **confirm** mode, you approve each tool call before it executes.

### Agents Tab

View and manage autonomous AI agents. Start agents from saved configs or create them on the fly. Monitor their plan-act-observe loop in real-time.

### Memory Tab

View facts the AI has remembered across sessions. Categories: preferences, device info, procedures, notes. You can edit or delete memories manually.

### Voice Controls

In the chat header:
- **Mic button** — Push to talk, or toggle hands-free listening
- **Speaker icon** — Toggle text-to-speech for AI responses
- **Mic dropdown** — Voice settings (wake word, sensitivity)

In the chat itself:
- **Live "You" bubble** — Your in-progress voice transcription, shown at the bottom of the chat while the mic is open
- **Speaking… [Stop]** — Appears under the latest AI reply while TTS is playing; click Stop to interrupt long replies

---

## Settings

Click the gear icon at the bottom of the Activity Bar to open the Settings panel.

| Section | What You Configure |
|---------|-------------------|
| **AI Services** | Model selection, safety mode, model favorites |
| **AI Instructions** | Custom system prompt for the AI assistant |
| **Voice** | Speech-to-text, text-to-speech, wake word |
| **Remote Access** | Password, HTTPS, bind address |
| **License** | Activation, tier info, trial status |

Settings are saved to `workspace/config/server.json`.

---

## Status Bar

The thin bar at the bottom of the screen shows:

- **Connection status** — Whether the WebSocket connection to the server is active
- **Running scripts** — Count of currently executing scripts

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+B` | Toggle left sidebar |
| `Ctrl+Shift+B` | Toggle right sidebar |
| `Ctrl+J` | Toggle bottom panel |
| `Ctrl+,` | Open settings |
| `Ctrl+S` | Save current file |
| `Ctrl+N` | New file |

See the full [Keyboard Shortcuts](https://docs.muxit.io/guides/keyboard-shortcuts.md) reference for editor shortcuts.

---

## Drag-and-Drop

Muxit supports cross-panel drag-and-drop for quick setup. The Hardware panel itself shows a "Tip:" banner when you expand a connector, reminding you that everything below it is draggable.

| Drag From | Drop On | Result |
|-----------|---------|--------|
| Hardware **property** | Script editor | Inserts `connector("name").prop` |
| Hardware **action** | Script editor | Inserts `connector("name").doThing(arg1, arg2)` |
| Hardware **stream** | Script editor | Inserts `stream("name", "streamName", data)` |
| Hardware property | Dashboard widget | Sets the widget's data binding |
| Hardware stream | Dashboard widget | Sets the stream binding |
| Script (from Explorer) | Dashboard grid | Creates a script-control widget |

---

## Next Steps

Now that you know the interface:

- [Your First Script](https://docs.muxit.io/examples/first-script.md) — Write and run your first automation script
- [Your First Dashboard](https://docs.muxit.io/examples/first-dashboard.md) — Build a live dashboard with widgets
- [Your First Connector](https://docs.muxit.io/examples/first-connector.md) — Create a device connector configuration
