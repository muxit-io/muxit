# Driver Marketplace

The Driver Marketplace lets you browse, install, and share drivers through a VS Code-style Extensions panel. Community drivers can be distributed as `.muxdriver` packages — self-contained ZIP files with metadata, documentation, and the driver itself.

::: tip Before you build a driver
Most custom hardware doesn't need a packaged driver at all. If your device speaks
SCPI, prints text lines, or emits binary frames, use a built-in
[Protocol](https://docs.muxit.io/reference/concepts.md) (`Scpi` / `LineText` / `BinaryStream`) and a
short connector config — see [Protocol authoring](https://docs.muxit.io/guides/protocol-authoring.md). Build
and publish a driver only when a Protocol can't express your device (vendor SDKs,
native libraries, Python-only stacks). See the
[Driver SDK](https://docs.muxit.io/reference/driver-sdk.md) for when each path applies.
:::

## Overview

Packaged drivers in Muxit come in three distributable tiers (built-in drivers are compiled into the server and aren't installed):

| Type | Tier | Sandbox | Distribution |
|------|------|---------|-------------|
| **JavaScript** | 1 | V8 sandbox | `.driver.js` in a `.muxdriver` |
| **Python** | 2 | Subprocess (own venv) | `.driver.py` in a `.muxdriver` |
| **C# Extension** | 3 | None (in-process .NET) | `.dll` in a `.muxdriver` |

All three are packaged and shared as `.muxdriver` files. JavaScript drivers are recommended for community distribution because they run in a secure V8 sandbox with no file system, network, or process access. Python drivers run subprocess-isolated in their own virtual environment; C# extension drivers run in-process with full .NET permissions (see [Security Model](#security-model)).

## Installing Drivers

### From the Extensions Panel

1. Click the **Extensions** icon (puzzle piece) in the Activity Bar
2. Switch to the **Available** tab
3. Search for a driver by name, description, or tag
4. Click **Install**

The driver downloads, extracts, and registers automatically — no server restart needed.

### From a `.muxdriver` File

If you have a `.muxdriver` package file (received from a colleague, downloaded manually, etc.):

```bash
node drivers.js install
```

Or place the `.muxdriver` file in `workspace/drivers/packages/` and the server will detect it on next startup.

### DLL Driver Warnings

When installing a DLL community driver (Tier 3), the system runs a capability audit and shows what system access the driver requests (file system, network, process, etc.). You must explicitly approve before the driver loads. JS drivers skip this step because they run in a sandbox.

## Creating Drivers

::: info First-party vs. third-party scaffolding
The `node drivers.js` workflow below scaffolds drivers **inside a Muxit source
checkout** (the `drivers/` tree) — it's how the Muxit team and contributors build
the bundled drivers. If you're an **external author** building a driver for your
own hardware, start from the standalone templates in the public
[`muxit-io/muxit`](https://github.com/muxit-io/muxit/tree/main/templates) repo
(`templates/javascript`, `templates/python`, `templates/csharp`) — they don't
require a full Muxit checkout. Either way the resulting `.muxdriver` and
`manifest.json` are identical.
:::

Use the **Driver Manager** tool to scaffold new drivers:

```bash
node drivers.js
```

This opens an interactive menu. Select **Create new JS driver** or **Create new C# driver**.

### Creating a JavaScript Driver

```bash
node drivers.js create
# Select: JS driver
# Enter: name, description, group, author
```

This creates two files in `workspace/drivers/`:
- `{name}.driver.js` — the driver implementation
- `{name}.manifest.json` — package metadata

**JS driver structure:**

```javascript
export default {
  meta: {
    name: "MyDriver",
    version: "1.0.0",
    group: "instruments",        // instruments, motion, communication, utilities
    description: "What it does",
    properties: {
      voltage: { type: "number", access: "r", unit: "V", description: "Measured voltage" },
    },
    actions: {
      reset: { description: "Reset the device" },
    },
    streams: [],
  },

  async init(config) { /* setup */ },
  async get(property) { /* read */ },
  async set(property, value) { /* write */ },
  async execute(action, args) { /* run action */ },
  async shutdown() { /* cleanup */ },
};
```

See [JS Driver SDK](https://docs.muxit.io/reference/driver-sdk-js.md) for the complete API.

### Creating a C# Driver

```bash
node drivers.js create
# Select: C# driver
# Enter: name (PascalCase), description, group, author
```

This creates a project in `drivers/Muxit.Driver.{Name}/` with:
- `.csproj` referencing the SDK
- `{Name}Driver.cs` implementing `IConnectorDriver`
- `manifest.json` for packaging

Build with:
```bash
dotnet publish drivers/Muxit.Driver.{Name} -c Release
```

See [C# Driver SDK](https://docs.muxit.io/reference/driver-sdk-csharp.md) for the complete API.

## The `.muxdriver` Package Format

A `.muxdriver` file is a ZIP archive with this structure:

```
manifest.json              ← required
README.md                  ← optional, shown in detail page
CHANGELOG.md               ← optional
icon.png                   ← optional, 128x128
my-driver.driver.js        ← JS driver entry point
  OR
MyDriver.dll               ← DLL driver entry point
MyDriver.dll.sig           ← optional RSA signature
deps/                      ← native dependencies (DLL drivers only)
```

### manifest.json

```json
{
  "formatVersion": 1,
  "id": "yourname/driver-name",
  "name": "My Driver",
  "version": "1.0.0",
  "description": "What this driver does",
  "author": {
    "name": "Your Name",
    "github": "yourgithub"
  },
  "group": "instruments",
  "tier": 1,
  "license": "MIT",
  "repository": "https://github.com/you/your-driver",
  "minimumServerVersion": "0.30.0",
  "entryPoint": "my-driver.driver.js",
  "tags": ["serial", "sensor"]
}
```

The table below is a quick reference; the [Driver Manifest Schema](https://docs.muxit.io/reference/driver-manifest.md) is the canonical, validator-backed spec.

| Field | Required | Description |
|-------|----------|-------------|
| `formatVersion` | Yes | Always `1` |
| `id` | Yes | Unique identifier: `publisher/name` format |
| `name` | Yes | Human-readable display name |
| `version` | Yes | Semantic version (e.g., `1.0.0`) |
| `entryPoint` | Yes | Filename of the driver (`.driver.js`, `.driver.py`, or `.dll`) |
| `category` | Yes | `"free"` or `"premium"` (premium is C#-only) |
| `tier` | Yes | `1` (JS), `2` (Python), or `3` (C# DLL) |
| `description` | No | Short description |
| `author` | No | `{ name, github }` |
| `group` | No | `instruments`, `motion`, `communication`, or `utilities` |
| `license` | No | License identifier (e.g., `MIT`) |
| `repository` | No | Source code URL |
| `minimumServerVersion` | No | Minimum required Muxit version |
| `tags` | No | Search/discovery tags |

## Packaging with `drivers.js`

```bash
node drivers.js package
```

The tool will:
1. List all available drivers (JS and C# projects)
2. Let you select one to package
3. For C# drivers: build with `dotnet publish`, collect DLLs and native dependencies
4. Read or create `manifest.json` (prompts for missing fields)
5. Include `README.md` and `CHANGELOG.md` if present
6. Create a `.muxdriver` ZIP file in `publish/drivers/`
7. Print the SHA256 hash (needed for the registry)

### CHANGELOG.md

Drivers may ship a top-level `CHANGELOG.md` alongside `manifest.json`.
It is optional, but recommended: the publish flow (both `node drivers.js
registry` and the Dev Console publish wizard) reads it, scopes it to the
version being published, and writes it into the `changelog` field of the
generated registry entry. The driver-registry site renders that field as
the **Changelog** section on the driver's detail page.

The publisher recognises the common [Keep a Changelog](https://keepachangelog.com/)
heading styles for version scoping:

```markdown
## 1.2.0
## [1.2.0]
## v1.2.0
## 1.2.0 - 2026-04-18
## 1.2.0 — 2026-04-18
```

The section is read from the first matching `##` heading up to the next
`##` heading. If no heading matches the manifest version the whole file
is used as a conservative fallback. The Dev Console's publish wizard
shows the scoped text in an editable textarea before the driver-registry
PR is opened, so you can always tweak the published notes without
re-packaging.

### Validating Before Packaging

```bash
node drivers.js validate
```

Checks your driver project for common issues:
- Missing or invalid `manifest.json`
- Missing entry point file
- Path traversal in file names
- Missing SDK reference (C# drivers)
- Missing `meta` section (JS drivers)

### Inspecting a Package

```bash
node drivers.js inspect
```

Opens a `.muxdriver` file and shows:
- Manifest contents (name, version, author, etc.)
- File listing with sizes
- SHA256 hash of the package

## Publishing

### Step 1: Create a GitHub Release

1. Push your driver source code to a GitHub repository
2. Create a release and upload the `.muxdriver` file as a release asset
3. Copy the download URL of the `.muxdriver` asset

### Step 2: Generate Registry Entry

```bash
node drivers.js          # select "Prepare registry entry"
```

This generates a JSON file with all the metadata needed for the registry, including the download URL and SHA256 hash.

### Step 3: Submit to Registry

1. Fork the [driver-registry](https://github.com/muxit-io/driver-registry) repository
2. Add your registry entry JSON to the `drivers/` directory
3. Submit a pull request
4. Once merged, your driver appears in the Available tab of the Extensions panel

## Security Model

### JavaScript Drivers (Recommended for Community)

JS drivers run in a V8 sandbox with strict isolation:
- **No** file system access
- **No** network access (except via transport APIs)
- **No** process spawning
- **No** `require()` or `import()`

This makes JS drivers safe to install from unknown authors.

### DLL Drivers

C# DLL drivers run with full .NET runtime access. Before installation, the system audits the DLL for capabilities:

- **File System** — can read/write files
- **Network** — can make network connections
- **Process** — can spawn processes
- **Reflection** — can inspect/modify code at runtime
- **Registry** — can access the Windows registry

A warning dialog shows these capabilities and requires explicit approval.

## Offline Use

The marketplace works in offline environments:

- **Registry cache**: The driver index is cached locally for 24 hours. If the network is unavailable, stale cache is used.
- **Manual install**: Place `.muxdriver` files in `workspace/drivers/packages/` or use `node drivers.js install` to install from a local file.
- **No phone-home**: Installed drivers work without any network connection.

## Driver Manager Reference

```bash
node drivers.js              # Interactive menu
node drivers.js create       # Create new driver
node drivers.js package      # Package driver into .muxdriver
node drivers.js validate     # Validate driver project
node drivers.js inspect      # Inspect .muxdriver package
node drivers.js install      # Install .muxdriver locally
node drivers.js list         # List all drivers
```

Also available from the command center: `node muxit.js 20`
