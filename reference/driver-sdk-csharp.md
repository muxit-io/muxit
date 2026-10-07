---
title: C# Driver SDK
description: Build C# device drivers for Muxit — .NET class libraries implementing IConnectorDriver.
---

# C# Driver SDK (Tier 3)

C# drivers are standalone .NET class libraries that implement the `IConnectorDriver` interface from the shared SDK. They ship as `.muxdriver` packages that sit directly under `workspace/drivers/`; the server extracts each package into a hidden `workspace/drivers/.cache/<id>@<version>/` on first load.

::: info Which starting point?
The paths below (`drivers/Muxit.Driver.*`) assume you're working **inside a Muxit
source checkout** — the workflow the Muxit team uses for bundled drivers.
**External authors** building a driver for their own hardware should instead copy
the standalone [`templates/csharp`](https://github.com/muxit-io/muxit/tree/main/templates/csharp)
project from the public `muxit-io/muxit` repo and add a `<PackageReference>` (or
`<ProjectReference>`) to `Muxit.Driver.Sdk`. The interface, descriptors, and
packaging are identical.
:::

## Quick Start

1. Copy `drivers/Muxit.Driver.Template/` to `drivers/Muxit.Driver.YourDevice/`
2. Rename in `.csproj`: `<AssemblyName>YourDevice</AssemblyName>`
3. Implement your driver logic
4. Edit `template.js` at the project root — starter connector content users get from the catalog (required)
5. Build: `dotnet build drivers/Muxit.Driver.YourDevice -c Release`
6. Package: `node drivers.js build YourDevice` → produces `dist/drivers/<id>-vX.Y.Z.muxdriver`
7. Install: drop the `.muxdriver` into `workspace/drivers/`, or use the Extensions panel
8. Test: `node start.js cli`, then `scan` and `init YourDevice`

## Connector starter template

Every C# driver project must contain a `template.js` file at its root. The packager copies it into the `.muxdriver` at the package root (alongside `manifest.json` and the DLL). The server reads it at driver scan time to populate the "Create connector" starter content for your driver. `node drivers.js build` refuses to produce a package without it.

```text
drivers/Muxit.Driver.YourDevice/
├── Muxit.Driver.YourDevice.csproj
├── YourDeviceDriver.cs
├── manifest.json
└── template.js          ← starter connector content (required)
```

Built-in drivers that ship as part of `MuxitServer.dll` use embedded-resource templates under `MuxitServer/Drivers/BuiltIn/Templates/<DriverName>.js` instead, loaded at runtime via `BuiltInTemplateLoader.Load(name)`.

## IConnectorDriver Interface

```csharp
public interface IConnectorDriver
{
    string Name { get; }
    string? Version => null;
    string? Description => null;   // Human-readable driver description

    Task InitAsync(Dictionary<string, object?>? config);
    Task ShutdownAsync();

    IEnumerable<PropertyDescriptor> GetProperties();
    IEnumerable<ActionDescriptor> GetActions();

    Task<object?> GetAsync(string property);
    Task SetAsync(string property, object? value);
    Task<object?> ExecuteAsync(string action, object? args);

    bool SupportsStreaming => false;
    IEnumerable<string> GetStreams() => [];
    Action<string, string>? StreamEmitter { get; set; }
}
```

## DriverGroup Enum

Every driver should declare a group for UI categorization using the `[DriverGroup]` attribute.
It is an **assembly** attribute, so it goes above the `namespace` line, not on the class:

```csharp
using Muxit.Driver.Sdk;

[assembly: DriverGroup(DriverGroup.Instruments)]

namespace Muxit.Driver.YourDevice;

public sealed class MyDriver : IConnectorDriver { ... }
```

| Value | Description |
|-------|-------------|
| `DriverGroup.Instruments` | Measurement devices (oscilloscopes, multimeters, spectrometers) |
| `DriverGroup.Motion` | Robots, CNC, stages, actuators |
| `DriverGroup.Communication` | Serial monitors, MQTT bridges, protocol adapters |
| `DriverGroup.Utilities` | Test devices, file access, vision, general-purpose |

For JS drivers, set `meta.group` to the lowercase enum name (e.g., `"instruments"`, `"motion"`).

## Opting out of the safety gate

Drivers with no path to physical hardware and no destructive actions can opt out of the safety gate entirely — no limit checks, no confirmations, no audit rows.

Declare at the assembly level:

```csharp
using Muxit.Driver.Sdk;

[assembly: RequiresSafetyGates(false)]
```

The assembly attribute wins over the interface default. If you don't declare the attribute, the driver is gated (`RequiresSafetyGates => true` is the interface default). See [Safety & access levels](https://docs.muxit.io/guides/safety.md#per-driver-opt-out) for guidance on when to use this.

## Lifecycle

1. **Constructor** — must be parameterless and public. Do NOT open connections here.
2. **InitAsync(config)** — open connections, start background tasks
3. **GetAsync / SetAsync / ExecuteAsync** — normal operation
4. **ShutdownAsync** — release all resources

## Property Types

| Type string | C# type (Get) | C# type (Set) |
|-------------|---------------|----------------|
| `"string"` | `string` | `string` |
| `"int"` | `int` | `int` |
| `"double"` | `double` | `double` |
| `"bool"` | `bool` | `bool` |
| `"double[]"` | `double[]` | `object?[]` |
| `"object"` | `Dictionary<string, object?>` | `Dictionary<string, object?>` |

**Automatic type conversion:** All driver return values are automatically converted to native JavaScript types when accessed from connector configs or scripts. C# `double[]` becomes a JS array you can `.map()`, `.filter()`, or spread (`...`). C# `Dictionary<string, object?>` becomes a plain JS object. No manual conversion is needed in connector or script code.

## Access Modes

| Access | Meaning |
|--------|---------|
| `"R"` | Read-only |
| `"R/W"` | Read-write |
| `"W"` | Write-only |

## Config Helpers

```csharp
using static Muxit.Driver.Sdk.DriverConfig;

public Task InitAsync(Dictionary<string, object?>? config)
{
    var host = GetString(config, "ip", "192.168.1.100");
    var port = GetInt(config, "port", 5000);
    var timeout = GetDouble(config, "timeout", 30.0);
    var verbose = GetBool(config, "verbose", false);
}
```

## Actions & Arguments

Actions are declared with `ActionDescriptor`. Each argument is described with `ArgDescriptor(name, type, description)`:

```csharp
public IEnumerable<ActionDescriptor> GetActions() => new[]
{
    new ActionDescriptor("reset", "Reset to factory defaults"),
    new ActionDescriptor("moveTo", "Move to position", [
        new ArgDescriptor("x", "double", "X coordinate in mm"),
        new ArgDescriptor("y", "double", "Y coordinate in mm"),
        new ArgDescriptor("z", "double", "Z coordinate in mm"),
    ]),
};
```

**Descriptors:**

```csharp
// Property: name, type, access, unit, description, details
public record PropertyDescriptor(string Name, string Type, string Access,
    string Unit = "", string Description = "", string Details = "");

// Action argument: name, type, description
public record ArgDescriptor(string Name, string Type, string Description = "");

// Action: name, description, args, details
public record ActionDescriptor(string Name, string Description = "",
    List<ArgDescriptor>? Args = null, string Details = "");
```

### `Description` vs `Details`

Every property and action supports two doc fields:

| Field | When it shows | Use it for |
|---|---|---|
| `Description` | Always — AI system prompt summary, IntelliSense hover, driver doc page | One-line summary. Keep it tight. |
| `Details` | On-demand — driver doc page ("Show details" toggle), IntelliSense hover, fetched via `get_connector_schema` / `get_driver_schema` | Short markdown: parameter enums, side effects, failure modes, truncation caps, non-obvious invariants. |

`Details` is **never** included in the upfront AI system prompt — the LLM only pays for it when it explicitly fetches the full schema. Treat `Details` as the place for everything that would take a user (or AI agent) two round trips of trial and error to discover from the one-liner. Markdown support: paragraphs, `-` bullet lists, fenced code blocks, inline **bold**, *italic*, and `` `code` ``.

```csharp
new ActionDescriptor(
    "scanBaud",
    "Close port, probe candidate baud rates, reopen at a chosen baud",
    [ new ArgDescriptor("reopenAt", "string", "one of: original | recommended | <baud>") ],
    Details: """
    `reopenAt` accepts `"original"` (default), `"recommended"`, or a numeric baud.

    Results are ranked by printable-ratio descending, with total bytes as the tiebreaker.
    If every candidate errors, `recommended` falls back to the original baud.
    """)
```

## Streaming

```csharp
public bool SupportsStreaming => true;
public IEnumerable<string> GetStreams() => new[] { "data", "video" };
public Action<string, string>? StreamEmitter { get; set; }

// Emit from background thread:
StreamEmitter?.Invoke("data", jsonString);
```

### Audio streams

Drivers that emit audio should prefer the dedicated `AudioStreamEmitter`
over the string emitter. Hand the host a pre-rendered float PCM buffer
(interleaved if stereo, normalised to ±1.0); the host handles Opus
encoding, JSON framing, real-time pacing, EventBus emission on the
connector's `"audio"` stream, and the `{ "op": "stop" }` frame on
cancellation. Returning the awaited `Task` lets cancellation propagate
through the existing `RunPlaybackAsync` pattern unchanged.

```csharp
public bool SupportsStreaming => true;
public IEnumerable<string> GetStreams() => new[] { "audio" };
public Action<string, string>? StreamEmitter { get; set; }
public Func<float[], AudioFrameInfo, CancellationToken, Task>? AudioStreamEmitter { get; set; }

// Render PCM, then hand it to the host. The await blocks for the
// real-time playback duration; cancel via the token to interrupt mid-stream.
var floatBuf = RenderUtterance(...); // 48 kHz mono floats, ±1.0
if (AudioStreamEmitter != null)
{
    await AudioStreamEmitter(floatBuf, AudioFrameInfo.Mono48k, ct);
}
```

The host accepts any standard Opus input rate (8 / 12 / 16 / 24 / 48
kHz); `AudioFrameInfo.Mono48k` is the preferred shape and avoids
resampling on the encode path. Codec deps (Concentus) live in
`MuxitServer` — driver assemblies don't ship a copy and don't need to
think about wire format.

## Subscribing to another driver's streams (`IDriverHost`)

A driver can subscribe to *other* drivers' streams through `IDriverHost`,
an adapter the server hands in after construction and before `InitAsync`.
This is how the Vision driver consumes camera frames from the Webcam or
ONVIF drivers without taking a dependency on MuxitServer internals.

```csharp
public IDriverHost? DriverHost { get; set; }

private IDisposable? _sub;

public Task InitAsync(Dictionary<string, object?>? config)
{
    var source = GetString(config, "source", "");           // e.g. "webcam1"
    _sub = DriverHost?.Subscribe(
        $"stream:{source}:video",
        frame => ProcessFrame((byte[])frame!));
    return Task.CompletedTask;
}

public Task ShutdownAsync()
{
    _sub?.Dispose();
    return Task.CompletedTask;
}
```

Channel scoping: only `stream:*` channels are permitted. Internal server
events (`server.log`, `driver.diagnostics`, `license.*`, ...) are not
exposed through `IDriverHost`. Attempting to subscribe to a non-stream
channel throws `ArgumentException`.

## Minimal Driver Example

```csharp
using Muxit.Driver.Sdk;
using static Muxit.Driver.Sdk.DriverConfig;

namespace Muxit.Driver.YourDevice;

public sealed class YourDeviceDriver : IConnectorDriver
{
    public string Name => "YourDevice";
    public string? Version => "1.0.0";
    public string? Description => "Your device description for documentation and AI.";
    public Action<string, string>? StreamEmitter { get; set; }

    public Task InitAsync(Dictionary<string, object?>? config)
    {
        var host = GetString(config, "host", "localhost");
        return Task.CompletedTask;
    }

    public Task ShutdownAsync() => Task.CompletedTask;

    public IEnumerable<PropertyDescriptor> GetProperties() => new[]
    {
        new PropertyDescriptor("value", "double", "R", "", "Current reading"),
    };

    public IEnumerable<ActionDescriptor> GetActions() => Array.Empty<ActionDescriptor>();

    public Task<object?> GetAsync(string property) => property switch
    {
        "value" => Task.FromResult<object?>(42.0),
        _ => throw new ArgumentException($"Unknown property: {property}"),
    };

    public Task SetAsync(string property, object? value) =>
        throw new ArgumentException($"Property '{property}' is read-only");

    public Task<object?> ExecuteAsync(string action, object? args) =>
        throw new ArgumentException($"Unknown action: {action}");
}
```

## Building & Testing

```bash
# Build all drivers
node build.js drivers

# Build specific driver
dotnet build drivers/Muxit.Driver.YourDevice -c Release

# Test with CLI
node start.js cli
# Then: scan, init, get, set, exec, meta, shutdown
```

## Project Structure

```
drivers/
├── Muxit.Driver.Sdk/           # Shared SDK
├── Muxit.Driver.Template/      # Reference implementation
├── Muxit.Driver.Fairino/       # Robot driver
├── Muxit.Driver.Avantes/       # Spectrometer driver
└── Muxit.Driver.YourDevice/
    ├── Muxit.Driver.YourDevice.csproj
    └── YourDeviceDriver.cs
```

## Free vs Premium Drivers

| Type | Signed? | License? | Who builds? |
|------|---------|----------|-------------|
| Official (free) | Yes | No | Muxit team |
| Official (premium) | Yes | Yes | Muxit team |
| Third-party (free) | No | Never | Anyone |

**Free drivers are always free.** Set `category: "free"` in `manifest.json`, build the package (`node drivers.js build`), drop the resulting `.muxdriver` in `workspace/drivers/`, done.
