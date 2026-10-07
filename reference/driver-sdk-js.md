---
title: JS Driver SDK
description: Build JavaScript device drivers for Muxit — sandboxed V8 modules with transport APIs.
---

# JS Driver SDK (Tier 1)

JavaScript drivers are `.driver.js` files in `workspace/drivers/`. They run in a sandboxed V8 engine with access to transport APIs for communicating with hardware.

## Structure

```javascript
export default {
  meta: {
    name: "MyDriver",
    version: "1.0.0",
    description: "Short description of what this driver does.",
    group: "instruments",  // DriverGroup: "instruments", "motion", "communication", "utilities"
    // Note: JS drivers always run behind the safety gate — a
    // requiresSafetyGates: false declaration is ignored (gates forced on).
    // access is exactly "R", "W" or "R/W" — only "R" and "R/W" properties are polled.
    properties: { voltage: { type: "number", access: "R/W", unit: "V", description: "Output voltage" } },
    actions: { reset: { description: "Reset device" } },
    streams: ["output"],
  },
  async init(config) { /* set up transport, initialize device */ },
  async get(property) { /* return property value */ },
  async set(property, value) { /* set property value */ },
  async execute(action, args) { /* execute action, return result */ },
  async shutdown() { /* clean up */ },
};
```

## Connector starter template

Ship a `template.js` file next to your `.driver.js`. It is the starter connector content users see when creating a connector for your driver. The packager copies it into the `.muxdriver` at the package root; the server reads it at scan time. This file is **required** — `node drivers.js build` refuses to package a driver without it.

```text
drivers/js/mydriver/
├── mydriver.driver.js
├── manifest.json
└── template.js          ← starter connector content (required)
```

## Property and action descriptions

Every property and action entry supports two doc fields:

| Field | When it shows | Use it for |
|---|---|---|
| `description` | Always — AI system prompt summary, IntelliSense hover, driver doc page | One-line summary. Keep it tight. |
| `details` | On-demand — driver doc page ("Show details" toggle), IntelliSense hover, fetched via `get_connector_schema` / `get_driver_schema` | Short markdown: parameter enums, side effects, failure modes, truncation caps, non-obvious invariants. |

`details` is **never** included in the upfront AI system prompt — the LLM only pays for it when it explicitly fetches the full schema. Treat `details` as the place for everything that would take a user (or an AI agent) two round trips of trial and error to discover from the one-liner.

```javascript
actions: {
  scanBaud: {
    description: "Close port, probe candidate baud rates, reopen at a chosen baud",
    args: { portPath: "string?", candidates: "array?", durationMs: "number?", reopenAt: "string?" },
    details: `\`reopenAt\` accepts \`"original"\` (default), \`"recommended"\`, or a numeric baud.

Results are ranked by printable-ratio descending, \`bytes\` as the tiebreaker.
If every candidate errors, \`recommended\` falls back to the original baud.`
  },
},
```

Markdown support: paragraphs, `-` bullet lists, fenced code blocks, inline **bold**, *italic*, and `` `code` ``.

## Safety gate

JS drivers cannot opt out of the safety gate. Declaring `meta.requiresSafetyGates: false` has no effect — the loader logs a security warning and forces gates back on. Only built-in drivers and officially-signed C# DLL drivers can opt out. See [Safety & access levels](https://docs.muxit.io/guides/safety.md#per-driver-opt-out).

## Available APIs

| API | Description |
|-----|-------------|
| `createTcpTransport(host, port, opts)` | Create TCP transport (`{ delimiter, timeout }`) |
| `createSerialTransport(path, opts)` | Create serial transport (`{ baudRate, delimiter, timeout }`) |
| `__emitStream(stream, data)` | Emit streaming data |
| `log.debug/info/warn/error(...)` | Logging |
| `timestamp()` | ISO timestamp string |

## Security Sandbox

JS drivers run in an isolated ClearScript V8 engine with these restrictions:
- `require()`, `import()` — blocked
- `process`, `global` — deleted from `globalThis`
- No access to `fs`, `net`, `child_process`, or any Node.js APIs
- Path traversal — `.driver.js` files must reside within `workspace/drivers/`
- Name collision — JS drivers cannot shadow built-in (Tier 0) driver names
