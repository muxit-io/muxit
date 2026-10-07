---
title: Driver SDK Reference
description: Build device drivers for Muxit — JavaScript modules or C# class libraries.
---

# Driver SDK Reference

::: tip Most devices don't need a custom driver — start here first
If your device speaks **SCPI**, prints **text lines** (`TEMP: 25.5`), or emits
**fixed binary frames** (Modbus etc.), you don't write a driver at all. You write
a short connector config that picks a built-in [Protocol](https://docs.muxit.io/reference/concepts.md)
(`Scpi` / `LineText` / `BinaryStream`) and declares a `schema:` block — and the
[AI assistant](https://docs.muxit.io/guides/protocol-authoring.md) can draft and test it against
your hardware in about a minute. See [Driver, Protocol, Engine](https://docs.muxit.io/reference/concepts.md)
to pick the right path.

**Reach for the Driver SDK only when a Protocol can't express your device** — a
vendor SDK or native library (spectrometers, robots), a Python-only instrument
stack (numpy / pyvisa / vendor wheels), or a device with quirky multi-step logic
that doesn't fit a generic wire parser. It's the escape hatch, not the front door.
:::

Build device drivers for Muxit as standalone .NET class libraries (Tier 3), Python modules (Tier 2), or JavaScript modules (Tier 1). C# drivers implement `IConnectorDriver` from the shared SDK. JS drivers export a default object with `meta`, `init`, `get`, `set`, `execute`, and `shutdown` methods. Python drivers subclass `muxit_driver.Driver` and call `run(...)`.

## Driver Tiers

| Tier | Type | Location | Status | Docs |
|------|------|----------|--------|------|
| 0 | Built-in (C#) | Compiled into MuxitServer | Always available | [Built-in Drivers](https://docs.muxit.io/reference/drivers/index.md) |
| 1 | JavaScript | `workspace/drivers/*.muxdriver` (or loose `*.driver.js`) | Active (sandboxed V8) | [JS Driver SDK](https://docs.muxit.io/reference/driver-sdk-js.md) |
| 2 | Python | `workspace/drivers/*.muxdriver` (or loose `*.driver.py`) | Active (subprocess + JSON-RPC) | [Python Driver SDK](https://docs.muxit.io/reference/driver-sdk-python.md) |
| 3 | DLL Extension (C#) | `workspace/drivers/*.muxdriver` | Active | [C# Driver SDK](https://docs.muxit.io/reference/driver-sdk-csharp.md) |

Choose your SDK based on what you're building:

- **[JS Driver SDK](https://docs.muxit.io/reference/driver-sdk-js.md)** — quick to write, sandboxed V8, good for serial/TCP instruments
- **[Python Driver SDK](https://docs.muxit.io/reference/driver-sdk-python.md)** — for Python-only ecosystems (numpy, torch, transformers, instrument SDKs); subprocess-isolated
- **[C# Driver SDK](https://docs.muxit.io/reference/driver-sdk-csharp.md)** — full .NET power, NuGet packages, good for complex hardware with native libraries

## Documenting properties and actions

Every property and action accepts two doc fields regardless of tier:

- `description` — one-line summary. Always visible (AI system prompt, IntelliSense, driver doc page).
- `details` — short markdown with parameter enums, side effects, failure modes, non-obvious invariants. Surfaced on-demand in the driver doc page (collapsible panel), in the script editor's hover popup, and in the full schema that the AI fetches via `get_connector_schema` / `get_driver_schema`. **Never** included in the upfront AI system prompt — use `details` freely for anything that would otherwise cost the user or an AI agent a round-trip of trial and error.

See the per-tier docs for syntax: [JS Driver SDK](https://docs.muxit.io/reference/driver-sdk-js.md#property-and-action-descriptions), [C# Driver SDK](https://docs.muxit.io/reference/driver-sdk-csharp.md#description-vs-details).

## Manifest & validation

Every driver ships a `manifest.json`. See:

- **[Driver Manifest Schema](https://docs.muxit.io/reference/driver-manifest.md)** — required and optional fields, premium integrity rules, complete examples
- **[Driver Tags](https://docs.muxit.io/reference/driver-tags.md)** — controlled tag vocabulary
- **[Driver Validation](https://docs.muxit.io/reference/driver-validation.md)** — rules enforced by `node drivers.js validate`, severities, JSON output

## Packaging & Distribution

Drivers can be packaged as `.muxdriver` files (ZIP archives with a `manifest.json`) for sharing through the [Driver Marketplace](https://docs.muxit.io/guides/driver-marketplace.md).

```bash
node drivers.js              # Interactive Driver Manager
node drivers.js create       # Scaffold a new driver
node drivers.js build        # Build + package every driver → dist/drivers/
node drivers.js package      # Package a single driver interactively
node drivers.js inspect      # View package contents
```

See the [Driver Marketplace guide](https://docs.muxit.io/guides/driver-marketplace.md) for the full packaging and publishing workflow.
