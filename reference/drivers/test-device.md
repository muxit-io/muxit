---
title: TestDevice Driver
description: Reference for the TestDevice built-in driver — a simulated instrument for learning and testing.
---

# TestDevice

**A simulated instrument for learning and testing.** No hardware required — all values are stored in memory. Always available, doesn't count against your connector limit. Includes a synthetic video stream and exercises every supported data type.

::: tip Safety gate
This driver keeps `requiresSafetyGates: true` on purpose, so it's the canonical sandbox for exploring the [safety gate](https://docs.muxit.io/guides/safety.md) — try out limits, confirmations, simulate/block at each level, and audit log entries against it without risking real hardware.
:::

## Properties

### Scalars

| Property | Type | Access | Unit | Description |
|----------|------|--------|------|-------------|
| `label` | string | R/W | | Device label (default: "Test Device") |
| `count` | int | R/W | | Event counter (increments with each stream tick) |
| `temperature` | double | R/W | °C | Simulated temperature (default: 22.5) |
| `enabled` | bool | R/W | | Whether the device is active |
| `streaming` | bool | R/W | | Enable/disable stream output |
| `threshold` | double | R/W | | Alert threshold value (default: 50.0) |
| `uptime` | double | R | s | Seconds since initialization (computed) |

### Arrays

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `spectrum` | double[] | R | Sample spectrum data (10 sine-wave points) |
| `histogram` | int[] | R | Sample histogram (8 random bins, 0–100) |
| `tags` | string[] | R/W | User-defined string tags (default: `["test", "dev"]`) |

### Complex

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `logs` | string[] | R | Recent log messages (last 20 entries) |
| `status` | object | R | Composite status: `{ label, enabled, temperature, count, uptime }` |
| `config` | object | R/W | Arbitrary key-value config dictionary (default: `{ mode: "normal", verbose: false }`) |
| `snapshot` | string | R | Current video frame as base64-encoded JPEG |

## Actions

| Action | Args | Returns | Description |
|--------|------|---------|-------------|
| `reset` | — | `"OK"` | Reset all values to defaults |
| `setThreshold` | `{ value: double }` | `"OK"` | Set the alert threshold |
| `calculate` | `{ a: double, b: double }` | `double` | Add two numbers and return the result |
| `configure` | `{ key: string, value: string }` | `string` | Set a named config value |
| `loadProfile` | `{ values: double[] }` | `int` | Load a numeric profile array, returns its length |
| `filterTags` | `{ tags: string[], prefix: string }` | `string[]` | Filter tags by prefix and return matches |
| `echo` | `{ data: object }` | `object` | Return the input object unchanged (object I/O test) |
| `setBatch` | `{ values: object }` | `int` | Set multiple properties at once, returns count updated |

## Streams

| Stream | Format | Rate | Description |
|--------|--------|------|-------------|
| `data` | JSON | 500ms | `{ timestamp, temperature, count, enabled }` |
| `video` | base64 JPEG | ~10 FPS | Synthetic animated frames — gradient background, bouncing dot, temperature bar, and overlaid text |

## Config Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `dashboardPort` | int | 9999 | Port for the built-in HTTP test dashboard |
| `label` | string | "Test Device" | Initial label value |
| `temperature` | double | 22.5 | Initial temperature value |
| `videoFps` | int | 10 | Synthetic video frame rate |
| `videoWidth` | int | 320 | Video frame width in pixels |
| `videoHeight` | int | 240 | Video frame height in pixels |

## Built-in Dashboard

The driver runs a self-contained HTTP dashboard at `http://localhost:<dashboardPort>/` (default 9999). It provides:

- Live scalar and complex property display with type badges
- Video stream viewer (refreshes at ~5 FPS)
- Interactive controls for all writable properties (including tags and config)
- Action execution with argument inputs for every action type
- Result display for action return values
- Log viewer
- CLI reference guide

## Example Connector

```javascript
// workspace/connectors/test-device.js
//
// Driver dashboard GUI: http://localhost:9999/
export default {
  driver: "TestDevice",
  config: {
    label: "My Test",
    temperature: 25.0,
  },
  poll: ["temperature", "count", "enabled", "threshold", "tags"],
};
```

## Example Script

```javascript
const dev = connector("test-device");

// Scalars — property write (assignment) and read (no parens)
dev.temperature = 50;
log.info(`Temperature: ${dev.temperature}°C`);

// Actions with different arg types
const sum = dev.calculate({ a: 3, b: 4 });
log.info(`3 + 4 = ${sum}`);

// Array I/O — property write/read + action
dev.tags = ["sensor", "lab", "test"];
const filtered = dev.filterTags({ tags: dev.tags, prefix: "se" });
log.info(`Filtered: ${JSON.stringify(filtered)}`);

// Object I/O
const echoed = dev.echo({ data: { x: 1, nested: [2, 3] } });
log.info(`Echo: ${JSON.stringify(echoed)}`);

// Batch update
dev.setBatch({ values: { label: "Batch", temperature: 42, enabled: true } });

dev.reset();
```
