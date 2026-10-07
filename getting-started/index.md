---
title: Getting Started
description: Get up and running with Muxit — what it is, what's included, and your first steps.
---

# Getting Started with Muxit

Welcome to Muxit — a hardware orchestration platform for controlling instruments, robots, and sensors through a unified interface with automation scripts, real-time dashboards, and AI.

## What Is Muxit?

Muxit gives you a single interface to control all your lab and workshop hardware. Instead of juggling vendor-specific software for each device, you connect everything to Muxit and control it all from one place.

**What you can do:**

- **Control a power supply** from your browser — set voltage, read current, ramp parameters
- **Build a live dashboard** for your CNC machine — position, feed rate, status, all updating in real-time
- **Write automation scripts** — ramp a temperature in steps, monitor a threshold, log measurements to a file
- **Use AI to control devices** — tell Claude "set the voltage to 12V and monitor the current" and it happens
- **Stream a webcam** to a dashboard widget alongside your instrument readings
- **Connect IoT sensors** via MQTT — ESP32, Arduino, Home Assistant, Node-RED
- **Set up autonomous agents** — an AI that watches temperature and adjusts power automatically

Muxit runs as a local server on your computer and serves a web-based GUI to your browser. No cloud account required — everything stays on your machine.

## Key Concepts

| Concept | What It Is | Example |
|---------|-----------|---------|
| **Driver** | Low-level hardware interface that talks to a physical device. JavaScript, Python, or compiled C# DLL | USB webcam driver, MQTT bridge, serial instrument driver, Python script wrapping a vendor SDK |
| **Connector** | Wraps a driver with a friendly name, custom methods, and config | `psu.js` — configures a PSU driver with serial port, adds `rampTo()` method |
| **Script** | Sandboxed JavaScript automation program | Read temperature every second, log it, alert if too high |
| **Dashboard** | Drag-and-drop layout of live widgets bound to device data | Gauges, charts, sliders, buttons, video streams |
| **Agent** | Autonomous AI that plans and executes multi-step goals | Monitor temperature sensor, reduce power if overheating |

For more definitions, see the [Glossary](https://docs.muxit.io/reference/glossary.md).

## What's Included

Muxit ships with a complete demo environment — **no hardware needed** to start exploring:

- **TestDevice** — a simulated instrument with temperature, voltage, counters, and more. Always available, doesn't count against connector limits
- **Example scripts** — `hello.js` (basic logging), `examples/sinewave.js` (animated dashboard data), `examples/psu-voltage-ramp.js` and `examples/threshold-alert.js` (instrument control & alerting), plus a numbered `tutorials/` series (`01-hello-world.js` … `10-ai-vision.js`)
- **Example dashboards** — `demo.dashboard.json` (interactive gauges, sliders, charts), `test-device.dashboard.json` (full device control panel)
- **Built-in drivers** — Webcam, ONVIF IP camera, FileAccess (sandboxed file I/O), MqttBridge (IoT integration), WebhookNotifier, EmailNotifier
- **Example agents** — temperature-monitor (auto-reduce power), pick-and-place (robot coordination)

---

## 5-Minute Quickstart

### 1. Install and Start

Install the latest release — no prerequisites, the binary is self-contained.

**Windows** (PowerShell):

```powershell
irm https://raw.githubusercontent.com/muxit-io/muxit/main/install.ps1 | iex
```

**macOS / Linux** (bash) — the same script detects your OS and CPU architecture:

```bash
curl -fsSL https://raw.githubusercontent.com/muxit-io/muxit/main/install.sh | bash
```

Then start Muxit:

```bash
muxit
```

Your browser opens to **http://127.0.0.1:8765**. See the [Installation Guide](https://docs.muxit.io/getting-started/installation.md) for detailed setup.

### 2. Explore the Hardware Panel

Click the **plug icon** in the left Activity Bar to open the Hardware panel. You'll see the **test-device** connector with live properties:

- **temperature** — a simulated temperature value
- **label** — a text label you can change
- **enabled** — a boolean toggle
- **threshold** — a numeric threshold
- **count** — an incrementing counter

These values update in real-time through polling.

### 3. Open a Dashboard

In the Explorer sidebar (files icon), expand `dashboards/` and click **demo.dashboard.json**. You'll see a live dashboard with:

- Gauge widgets showing sine/cosine waves
- Sliders you can drag to change values
- A chart plotting data over time
- An indicator light showing running state

### 4. Run a Script

In the Explorer sidebar, expand `scripts/examples/` and click **sinewave.js**. Click the **Run** button in the editor toolbar. Watch the dashboard come alive — the script drives the gauge and chart values with animated sine waves.

Click **Stop** to end the script.

### 5. Try the AI Chat (Optional)

Click the **chat icon** in the Activity Bar to open the AI Chat sidebar. With an active Muxit license, try:

- *"What devices are connected?"*
- *"Read the test device temperature"*
- *"Set the threshold to 75"*

---

## Choose Your Path

### "I have lab instruments"
You have SCPI-compatible instruments (oscilloscopes, power supplies, multimeters) connected via USB/serial or TCP/IP.

**Start here:**
1. [Your First Connector](https://docs.muxit.io/examples/first-connector.md) — learn the connector config format
2. [Connector Guide](https://docs.muxit.io/guides/connectors.md) — transports, serial/TCP setup, real hardware examples
3. [Driver SDK](https://docs.muxit.io/reference/driver-sdk.md) — build a custom driver for your instrument

### "I already have a Python script that talks to my device"
A vendor SDK, an existing analysis script, a model from huggingface — anything you'd rather not rewrite in JavaScript.

**Start here:**
1. [Python Driver SDK — Generic `Python` driver](https://docs.muxit.io/reference/driver-sdk-python.md#generic-python-driver) — drop a `.py` into `workspace/python/`, point a connector at it, done. No `Driver` class, no JSON-RPC.
2. [Python Driver SDK — Structure](https://docs.muxit.io/reference/driver-sdk-python.md#structure) — for when you outgrow the generic driver and want a typed, packaged `.muxdriver`.
3. [Connector Guide](https://docs.muxit.io/guides/connectors.md) — wire your Python functions up as properties and methods.

### "I have a CNC, 3D printer, or robot"
You have motion-control hardware that communicates over serial (G-code/GRBL) or TCP.

**Start here:**
1. [Connector Guide](https://docs.muxit.io/guides/connectors.md) — see the G-code/GRBL CNC example
2. [Dashboard Guide](https://docs.muxit.io/guides/dashboards.md) — build a control panel with position display, buttons, terminal
3. [Your First Script](https://docs.muxit.io/examples/first-script.md) — automate motion sequences

### "I have IoT sensors"
You have ESP32, Arduino, Tasmota, or Home Assistant devices communicating via MQTT.

**Start here:**
1. [MQTT & IoT Guide](https://docs.muxit.io/guides/mqtt-iot.md) — connect to an MQTT broker, subscribe to topics, display data
2. [Dashboard Guide](https://docs.muxit.io/guides/dashboards.md) — build a sensor dashboard
3. [Your First Script](https://docs.muxit.io/examples/first-script.md) — automate based on sensor readings

### "I want to use AI to control hardware"
You want Claude, GPT-4, or another LLM to control your devices.

**Start here:**
1. [AI & Voice Guide](https://docs.muxit.io/guides/ai.md) — set up the Chat Panel or MCP server
2. [AI & Voice Guide — Agents](https://docs.muxit.io/guides/ai.md#agent-mode) — autonomous AI with safety boundaries

### "I just want to explore"
No hardware yet — you want to learn what Muxit can do.

**Start here:**
1. [UI Tour](https://docs.muxit.io/getting-started/ui-tour.md) — understand the interface
2. [Your First Script](https://docs.muxit.io/examples/first-script.md) — write a script using the TestDevice
3. [Your First Dashboard](https://docs.muxit.io/examples/first-dashboard.md) — build a dashboard with live widgets
4. [Your First Connector](https://docs.muxit.io/examples/first-connector.md) — create a connector config

---

## Running Muxit

```bash
muxit                # Start the server and open the browser
muxit --nogui        # Start without opening the browser
muxit --no-tray      # Start without the system tray icon
muxit --port=9000    # Use a custom port
muxit --cli          # CLI mode (driver testing REPL)
muxit --mcp          # MCP server (for Claude Code / Desktop)
```

Then open **http://127.0.0.1:8765** in your browser.

## File Structure

```
workspace/
├── connectors/    ← device configurations (.js)
├── scripts/       ← automation scripts (.js)
├── drivers/       ← driver files (.driver.js, .driver.py, .muxdriver)
├── python/        ← Python scripts that connectors expose as devices (.py + optional .requirements.txt)
├── dashboards/    ← dashboard layouts (.dashboard.json)
├── agents/        ← agent config files (.agent.json)
├── data/          ← sandboxed file storage (FileAccess driver)
└── config/        ← server settings (server.json)
```

The filename of each connector, script, or dashboard becomes its name in Muxit. For example, `connectors/psu.js` creates a connector called "psu" that you access with `connector("psu")` in scripts.

## Next Steps

- [System Requirements](https://docs.muxit.io/getting-started/system-requirements.md) — supported platforms, hardware, network
- [Installation](https://docs.muxit.io/getting-started/installation.md) — detailed setup for Windows, macOS, and Linux
- [UI Tour](https://docs.muxit.io/getting-started/ui-tour.md) — learn the interface
- [Your First Script](https://docs.muxit.io/examples/first-script.md) — write and run a script
- [Your First Dashboard](https://docs.muxit.io/examples/first-dashboard.md) — build a live dashboard
- [Your First Connector](https://docs.muxit.io/examples/first-connector.md) — configure a device
- [Script Guide](https://docs.muxit.io/guides/scripts.md) — all script API functions
- [Connector Guide](https://docs.muxit.io/guides/connectors.md) — connector config format
- [Dashboard Guide](https://docs.muxit.io/guides/dashboards.md) — widgets and data binding
- [AI Guide](https://docs.muxit.io/guides/ai.md) — AI chat, voice, MCP, agents
- [Python Connectors Guide](https://docs.muxit.io/guides/python-connectors.md) — wrap a Python script as a Muxit connector
- [Driver SDK](https://docs.muxit.io/reference/driver-sdk.md) — write a custom driver in JavaScript, Python, or C#
- [Troubleshooting](https://docs.muxit.io/guides/troubleshooting.md) — common issues and solutions
