---
title: Glossary
description: Definitions of Muxit-specific terms and concepts.
---

# Glossary

Key terms and concepts used throughout Muxit.

## A

### Action
A command you can execute on a device through its driver. Actions perform operations like `reset`, `start`, `stop`, `snapshot`, or `home`. Called from scripts with `dev.reset()` or from dashboards with button widgets.

### Activity Bar
The vertical strip of icons on the far left of the Muxit UI. Click an icon to switch between the Explorer, Hardware panel, and AI Chat sidebar. The gear icon at the bottom opens Settings.

### Agent
An autonomous AI instance that pursues multi-step goals. Agents follow a plan-act-observe-re-plan loop, can react to device events via triggers, and operate within configurable safety boundaries. Configured with `.agent.json` files in `workspace/agents/`.

## C

### Connector
A configuration file that wraps a [Driver](#driver), [Protocol](#protocol), or [Engine](#engine) with friendly settings, custom methods, and computed properties. Connectors live in `workspace/connectors/` as `.js` ES module files. The filename becomes the connector name — `psu.js` creates `connector("psu")`. The leading keyword in the file (`driver:`, `protocol:`, or `engine:`) tells the loader which kind it's targeting. Omit the keyword (with only standard connector keys present) and the connector becomes a [Virtual](https://docs.muxit.io/reference/drivers/virtual.md) in-memory store with no hardware behind it.

### Connector Browser
The Hardware panel in the left sidebar. Shows all configured connectors with their live property values, actions, and streams. Used to enable/disable connectors and add new ones.

## D

### Dashboard
A drag-and-drop layout of live widgets that display real-time data from your devices. Dashboards are stored as `.dashboard.json` files in `workspace/dashboards/`. Widgets include gauges, charts, sliders, buttons, toggles, video streams, and more.

### Driver
A turnkey integration that owns its own communication path to a single device or class of devices. Drivers can be built-in (TestDevice, Webcam, MqttBridge), JavaScript (`.driver.js`), Python (`.driver.py`), or C# DLLs. Drivers expose properties (values you can read/write), actions (commands you can execute), and streams (continuous data). Compare with [Protocol](#protocol) (generic wire-format parser, you supply the schema) and [Engine](#engine) (compute on other connectors). See [Concepts — Driver, Protocol, Engine](https://docs.muxit.io/reference/concepts.md) for which to pick.

### Driver Proxy
The `c` object passed to connector methods and properties. It provides natural property syntax: `c.voltage` reads a property, `c.voltage = 12` writes it, `c.reset()` executes an action. The proxy translates these calls to the underlying driver — or to a [Protocol](#protocol) instance when the connector uses `protocol:` instead of `driver:`.

## E

### Engine
A catalog kind for connectors that **compute on data from other connectors** instead of talking to physical hardware. Vision is the first Engine: it subscribes to a camera connector's video stream and emits detected-object events. Engines are declared with `engine: "<Name>"` and a `source:` field that names another connector. See [Concepts — Driver, Protocol, Engine](https://docs.muxit.io/reference/concepts.md).

### EventBus
Muxit's internal pub/sub messaging system. Components communicate through events rather than direct references. Scripts publish events with `emit()`, subscribe with `on()`, and the system uses events for state updates, stream data, and log broadcasting.

### Explorer
The file browser sidebar in the Muxit UI. Shows your workspace files organized by type — connectors, scripts, dashboards, agents, drivers, and config. Supports favorites, inline run/stop buttons, and drag-and-drop.

## M

### MCP (Model Context Protocol)
A standard protocol for AI tools to interact with external systems. Muxit's MCP server exposes device control, script execution, and file management as tools that Claude Code, Claude Desktop, and other MCP-compatible AI tools can use.

### MQTT
A lightweight messaging protocol used by IoT devices. Devices publish messages to topics and subscribe to receive messages. Muxit's built-in MqttBridge driver connects to MQTT brokers to read IoT sensor data and send commands.

## P

### Protocol
A catalog kind that packages a **reusable wire-format parser** (SCPI, line-text, binary frames) without baking in any specific device. A Protocol-based connector supplies its own `connection:` block (which Transport to use) plus a `schema:` block (which commands, lines, or frame fields to expect). Three built-in Protocols ship with Muxit: `Scpi`, `LineText`, `BinaryStream`. Compare with [Driver](#driver) (turnkey integration) and [Engine](#engine). See [Concepts — Driver, Protocol, Engine](https://docs.muxit.io/reference/concepts.md).

### Polling
The automatic, periodic reading of connector properties. When a property has `poll: true` (or is listed in the connector's `poll` array), Muxit reads it at a fixed interval (default 200ms) and broadcasts changes to dashboards and WebSocket clients.

### Property
A named value on a device that you can read and/or write. Properties have a type (string, int, double, bool, array, object), an access mode (R = read-only, R/W = read-write, W = write-only), and optionally a unit and description.

## S

### Sandbox
The restricted execution environment for scripts and connector configs. Code runs in an isolated V8 JavaScript engine with access only to Muxit globals (`connector()`, `log`, `delay()`, etc.) and standard JS built-ins. Filesystem, network, and Node.js APIs are blocked.

### Script
A sandboxed JavaScript automation program. Scripts control devices, emit events, push data to dashboards, and can make AI calls. Each runs in its own V8 engine as plain top-level code; pressing Stop ends it immediately. Stored as `.js` files in `workspace/scripts/`.

### State
The current values of all polled properties across all connectors. State is broadcast to WebSocket clients in batched updates every 50ms. Dashboard widgets bind to state values for real-time display.

### Stream
Continuous data emitted by a driver or script. Streams carry high-frequency data like video frames, serial output, or sensor readings. Dashboard canvas and terminal widgets subscribe to streams for real-time display. Scripts emit stream data with `stream(connector, name, data)`.

## T

### Transport
A communication layer that moves bytes between Muxit and a device. Three built-in transports cover almost every wire: **TCP** for network devices (LXI instruments, MQTT brokers, ONVIF cameras), **Serial** for RS-232 / USB-to-serial, and **USBTMC** for instruments with a direct USB-B port. Protocol-based connectors pick a Transport via the `connection: { type: "tcp" | "serial" | "usbtmc", ... }` block; turnkey Drivers own their Transport internally. See [Concepts — Driver, Protocol, Engine](https://docs.muxit.io/reference/concepts.md) for how Transports sit under Protocols and Drivers.

## W

### Widget
A visual component on a dashboard. Each widget has a type (gauge, chart, slider, button, toggle, etc.), a position on the grid, and a configuration that binds it to connector properties, actions, or streams. Widgets update in real-time.

### Workspace
The `workspace/` directory that contains all your user files — connectors, scripts, dashboards, agents, drivers, and configuration. This is Muxit's runtime root. Everything you create and configure lives here, and it's preserved during updates.
