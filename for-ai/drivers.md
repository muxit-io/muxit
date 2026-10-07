---
title: Writing Drivers — Reference for AI Assistants
description: Everything an AI assistant needs to write a working Muxit driver in JavaScript, Python or C# — the shared contract, each language's file shape, installing it, packaging it, and the mistakes to avoid.
---

# Writing Muxit drivers

*A reference for AI assistants. It is self-contained: you can write a correct driver from this
page alone. Read [Before you write a driver](#before-you-write-a-driver) and
[The contract every driver follows](#the-contract-every-driver-follows) first, then the section
for your language, and finish with the [checklist](#checklist).*

A **driver** is a backend that talks to one kind of device. On its own it does nothing: a
[connector](https://docs.muxit.io/for-ai/connectors.md) selects it with `driver: "<Name>"`, passes it configuration, and
gives the device a name. Scripts, dashboards and Muxit's AI then use the properties and actions
the driver declares.

## Before you write a driver

Most devices do not need one. A connector using a built-in protocol covers SCPI instruments
(`Scpi`), anything that prints text lines (`LineText`) and fixed-layout binary frames such as
Modbus RTU (`BinaryStream`) — see [Writing Connectors](https://docs.muxit.io/for-ai/connectors.md). If the user only wants to
call some Python functions, the generic `Python` driver may be enough (see
[Python connectors](https://docs.muxit.io/guides/python-connectors.md)).

Write a driver when the device needs a vendor SDK or native library, a Python-only stack
(numpy, pyvisa, a vendor wheel), a stateful handshake or session, or a protocol the three
built-in ones cannot express.

| Language | Choose it when | Runs as |
|---|---|---|
| **JavaScript** (`.driver.js`) | Serial or TCP devices with a text or simple binary protocol. Quickest to write; nothing to install. | Sandboxed V8 inside the Muxit server. |
| **Python** (`.driver.py`) | The device has a Python SDK, or you need numpy / pyserial / pyvisa / sockets. | A separate Python 3.10+ process per connector. Needs Python on the user's machine. |
| **C#** (`.dll` in a `.muxdriver`) | A .NET or native vendor SDK, high throughput, or full .NET. | Loaded into the server. Needs the Muxit driver SDK assembly to build. |

## The contract every driver follows

Every driver, in every language, has the same shape:

- **A name** (`MyDevice`) — what connectors write in `driver: "MyDevice"`. It may not equal a
  built-in name (`Scpi`, `Webcam`, `TestDevice`, `Virtual`, …); comparison ignores case.
- **A group**: `instruments`, `motion`, `communication` or `utilities`.
- **Properties**, each `{ name, type, access, unit?, description, details? }`.
- **Actions**, each `{ name, description, args?, details? }`.
- **Streams** (optional): names of continuous outputs (lines, frames, spectra) that dashboard
  widgets subscribe to.
- **Lifecycle**: `init(config)` once when the connector starts (open the connection here, never
  at load time); `get(property)`, `set(property, value)`, `execute(action, args)` while running;
  `shutdown()` when it stops.

**`access`** is exactly `"R"`, `"W"` or `"R/W"` — uppercase, with the slash. **Every `"R"` and
`"R/W"` property is read every 200 ms** for as long as the connector runs, so `get` must be cheap:
return a cached value, or do one short query. Spellings such as `"r"` or `"rw"` are never polled,
so their values never reach dashboards on their own.

**`type`** is free text used for display and for Muxit's AI; use one of `"string"`, `"int"`,
`"double"`, `"bool"`, `"double[]"`, `"int[]"`, `"string[]"`, `"object"`.

**`description`** is one line and is always shown — in the UI, in IntelliSense, and in Muxit's AI
prompt. **`details`** is optional markdown fetched only on demand: put argument enums, units,
side effects, timeouts and failure modes there, not in the description.

**`config`** is the connector's configuration: the connector's `config: { … }` plus any other
non-reserved top-level keys. Read every option with a default and validate required ones in
`init`, throwing a clear error (`'MyDevice needs config.port, e.g. "COM3"'`).

**`args`** arrive as an object keyed by the declared argument names. A script call
`dev.move(10, 20)` arrives as `{ x: 10, y: 20 }` when the action declares `x` then `y`; a call
with one object passes that object. Declare arguments in the order a caller would naturally pass
them.

**Errors**: throw (or raise) with a message a user can act on; it reaches the script, dashboard
or AI that made the call.

**Safety**: the user's safety gate checks every write and action made on a connector that uses
your driver. Third-party drivers cannot opt out — `requiresSafetyGates: false` is ignored for
JavaScript and Python drivers and for unsigned C# drivers.

## JavaScript drivers

One file, `<name>.driver.js`, with a single `export default` object.

```js
// workspace/drivers/mydevice.driver.js
// Helpers may be declared at the top level, but never *call* host globals (log,
// createSerialTransport, setTimeout) there: the file is also evaluated at scan time without them.
function openSerial(config) {
  if (!config.port) throw new Error('MyDevice needs config.port, e.g. "COM3" or "/dev/ttyUSB0"');
  return createSerialTransport(config.port, {
    baudRate: config.baudRate ?? 115200,
    delimiter: config.delimiter ?? "\n",
    timeout: config.timeout ?? 5000,
  });
}

export default {
  meta: {
    name: "MyDevice",
    version: "1.0.0",
    group: "instruments",
    description: "Line-based serial instrument with a setpoint, a measurement and a line stream.",
    properties: {
      connected:   { type: "bool",   access: "R",   description: "Serial port is open" },
      setpoint:    { type: "double", access: "R/W", unit: "V", description: "Output setpoint",
                     details: "Writing sends `SETP <v>` and waits up to 2 s for the reply." },
      measurement: { type: "double", access: "R",   unit: "V", description: "Last measured value" },
    },
    actions: {
      measure: { description: "Take a fresh measurement and return it" },
      send:    { description: "Send a raw line and return the reply", args: { text: "string" },
                 details: "Appends `\\n`. Fails after 2 s without a reply line." },
    },
    streams: ["output"],
  },

  // State lives on the object; the lifecycle methods are called with `this` bound to it.
  _transport: null,
  _pending: [],
  _setpoint: 0,
  _measurement: null,

  async init(config) {
    this._pending = [];
    this._transport = openSerial(config);
    this._transport.onData = (line) => {           // set before connect()
      const waiter = this._pending.shift();
      if (waiter) waiter.resolve(line);
      __emitStream("output", line);                // stream data must be a string
    };
    if (!this._transport.connected) await this._transport.connect();
  },

  async get(property) {                            // polled every 200 ms: cached values only
    switch (property) {
      case "connected":   return this._transport?.connected ?? false;
      case "setpoint":    return this._setpoint;
      case "measurement": return this._measurement;
      default: throw new Error(`Unknown property: ${property}`);
    }
  },

  async set(property, value) {
    if (property !== "setpoint") throw new Error(`Property '${property}' is read-only`);
    const v = Number(value);
    if (!Number.isFinite(v)) throw new Error(`setpoint must be a number, got ${value}`);
    await this._request(`SETP ${v}`);
    this._setpoint = v;
  },

  async execute(action, args) {
    switch (action) {
      case "measure": {
        this._measurement = Number(await this._request("MEAS?"));
        return this._measurement;
      }
      case "send": return this._request(String(args?.text ?? ""));
      default: throw new Error(`Unknown action: ${action}`);
    }
  },

  async shutdown() {
    for (const waiter of this._pending) waiter.reject(new Error("Driver shut down"));
    this._pending = [];
    if (this._transport) { this._transport.onData = null; this._transport.close(); }
    this._transport = null;
  },

  // One request, one reply line. Replies are matched through onData, not transport.query().
  _request(text, timeoutMs = 2000) {
    if (!this._transport?.connected) return Promise.reject(new Error("Not connected"));
    return new Promise((resolve, reject) => {
      const waiter = {};
      const timer = setTimeout(() => {
        this._pending = this._pending.filter((w) => w !== waiter);
        reject(new Error(`No reply to '${text}' within ${timeoutMs} ms`));
      }, timeoutMs);
      waiter.resolve = (line) => { clearTimeout(timer); resolve(line); };
      waiter.reject = (err) => { clearTimeout(timer); reject(err); };
      this._pending.push(waiter);
      this._transport.write(text + "\n");
    });
  },
};
```

**Rules for JavaScript drivers**

- The file contains `export default` and a `meta` object. No other `export`, no `import`
  (stripped), and the strings `require(` and `import(` may not appear anywhere, comments
  included. `eval` and `new Function` throw.
- Write the lifecycle functions as methods (`async init(config) { … }`), not arrow functions —
  they need `this`.
- `meta` fields read: `name`, `version`, `description`, `group`, `properties`, `actions`,
  `streams`. In `actions`, `args` maps each name to a **type string** (`{ x: "double" }`);
  arguments have no descriptions, so explain them in the action's `details`.
- Calls to one connector's driver run one at a time: a slow `execute` delays the `get` polls
  behind it.
- Returning `undefined` or `""` reaches the caller as `null`.

**Globals in a JavaScript driver:** `log.info/warn/error/debug`, `console.log/warn/error` (server
console only), `timestamp()`, `setTimeout`, `clearTimeout`, `setInterval`, `clearInterval`,
`createSerialTransport(path, { baudRate, delimiter, timeout })`,
`createTcpTransport(host, port, { delimiter, timeout })`, and `__emitStream(name, string)`. There
is no `delay` (use `new Promise((r) => setTimeout(r, ms))`), no `emit`, no `Buffer`, no `fetch`,
no `require`, no Node or browser API.

**Transports.** `createSerialTransport` honours only `baudRate`, `delimiter` and `timeout`
(8 data bits, no parity, 1 stop bit). `createTcpTransport` may only reach `localhost`, loopback
and private network addresses; anything else needs the user to turn on
`security.allowExternalTransports` in `workspace/config/server.json` (a connector's `allowedHosts`
does not reach drivers). The transport object has `connect()`, `write(string)`, `close()`,
`connected` and `onData = (line) => …` (one call per received line, split on `delimiter`); serial
transports also have `setRawMode(true)` with `onRawData` for byte-level protocols. **`connect()`, `write()` and `query()` return
.NET tasks that `await` does not unwrap**: `await transport.query(cmd)` does not give you the
reply, so match replies to requests through `onData`, as `_request` does above. A serial
`connect()` has opened the port when it returns (or thrown); a TCP `connect()` returns before the
connection is up, so wait until `transport.connected` is true, with a timeout.

## Python drivers

One file, `<name>.driver.py`, defining a subclass of `muxit_driver.Driver`. Muxit provides the
`muxit_driver` package; do not install or vendor it yourself for a loose driver file.

```python
# workspace/drivers/mydevice.driver.py
from __future__ import annotations

from typing import Any

from muxit_driver import Driver, run


class MyDevice(Driver):
    META = {
        "name": "MyDevice",
        "version": "1.0.0",
        "description": "Serial instrument via pyserial: setpoint, measurement and a reading stream.",
        "group": "instruments",
        "properties": {
            "connected":   {"type": "bool",   "access": "R",   "description": "Serial port is open"},
            "setpoint":    {"type": "double", "access": "R/W", "unit": "V", "description": "Output setpoint"},
            "measurement": {"type": "double", "access": "R",   "unit": "V", "description": "Last measured value"},
        },
        "actions": {
            "measure": {
                "description": "Take N readings and return them",
                "args": {"count": {"type": "int", "description": "Number of readings (default 1)"}},
                "details": "Each reading is also emitted on the `readings` stream.",
            },
        },
        "streams": ["readings"],
    }

    def __init__(self) -> None:
        self._ser = None
        self._setpoint = 0.0
        self._measurement: float | None = None

    def init(self, config: dict[str, Any] | None) -> None:
        config = config or {}
        import serial  # third-party imports go here, never at module level

        port = config.get("port")
        if not port:
            raise ValueError('MyDevice needs config.port, e.g. "COM3" or "/dev/ttyUSB0"')
        self._ser = serial.Serial(str(port), int(config.get("baudRate", 115200)), timeout=2)
        self.log(f"opened {port}")

    def _query(self, command: str) -> str:
        self._ser.write((command + "\n").encode())
        reply = self._ser.readline().decode(errors="replace").strip()
        if not reply:
            raise TimeoutError(f"no reply to {command!r}")
        return reply

    def get(self, property: str) -> Any:  # polled every 200 ms: cached values only
        if property == "connected":
            return bool(self._ser is not None and self._ser.is_open)
        if property == "setpoint":
            return self._setpoint
        if property == "measurement":
            return self._measurement
        raise KeyError(f"unknown property: {property}")

    def set(self, property: str, value: Any) -> None:
        if property != "setpoint":
            raise KeyError(f"property '{property}' is read-only")
        self._query(f"SETP {float(value)}")
        self._setpoint = float(value)

    def execute(self, action: str, args: dict[str, Any] | None) -> Any:
        args = args or {}
        if action == "measure":
            values = []
            for _ in range(int(args.get("count", 1))):
                self._measurement = float(self._query("MEAS?"))
                values.append(self._measurement)
                self.emit("readings", {"v": self._measurement})
            return values
        raise KeyError(f"unknown action: {action}")

    def shutdown(self) -> None:
        if self._ser is not None:
            self._ser.close()


if __name__ == "__main__":
    run(MyDevice)
```

**Rules for Python drivers**

- The file imports `Driver` and `run` from `muxit_driver`, defines `META`, and ends with
  `if __name__ == "__main__": run(YourClass)`.
- **Action arguments in `META` are dicts**: `{"count": {"type": "int", "description": "…"}}`.
  A bare string (`{"count": "int"}`) breaks the driver scan and the driver does not appear.
- **Import third-party packages inside `init`.** Muxit runs the module with `--scan` to read
  `META` on every start-up, where heavy or missing packages would slow or break the scan.
- **Never `print()`**: stdout is the channel to Muxit. Use `self.log(message, level="info")`,
  `self.emit(stream, data)` (any JSON-serialisable data), `self.emit_progress(stage, line)`, or
  write to stderr.
- Methods may be plain or `async def`. Requests are handled one at a time; `get`, `set` and
  `execute` time out after 30 seconds, `init` after 30 minutes (for first-run installs).
- Return JSON-serialisable values; numpy arrays are converted with `.tolist()`.
- Dependencies go in a `requirements.txt` next to the `.driver.py`. Muxit creates a virtual
  environment beside it and installs them on first use. There is no SDK transport helper — use
  `pyserial`, `socket`, `pyvisa` or the vendor package directly.
- Test without Muxit: `python3 mydevice.driver.py --scan` prints the parsed `META`;
  `python3 -u mydevice.driver.py --instance dev` reads JSON-RPC lines such as
  `{"id": 1, "method": "init", "params": {"port": "COM3"}}` from stdin. Outside Muxit,
  `muxit_driver` must be importable (`PYTHONPATH` pointing at a copy of it).

## C# drivers

A .NET class library implementing `Muxit.Driver.Sdk.IConnectorDriver`, shipped in a `.muxdriver`
package. Build it against the **Muxit.Driver.Sdk** assembly, which is not on NuGet: it ships with
Muxit (as a file in the Linux and macOS install folders) and is the `drivers/Muxit.Driver.Sdk`
project in Muxit's source. Reference it without copying it into your output, and never put it in
the package — the server always supplies its own copy.

```xml
<!-- MyDevice.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>MyDevice</AssemblyName>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="Muxit.Driver.Sdk">
      <HintPath>path/to/Muxit.Driver.Sdk.dll</HintPath>
      <Private>false</Private>
    </Reference>
  </ItemGroup>
</Project>
```

```csharp
// MyDeviceDriver.cs
using Muxit.Driver.Sdk;
using static Muxit.Driver.Sdk.DriverConfig;

[assembly: DriverGroup(DriverGroup.Instruments)]   // assembly-level, before the namespace

namespace MyCompany.MyDevice;

public sealed class MyDeviceDriver : IConnectorDriver
{
    public string Name => "MyDevice";
    public string? Version => "1.0.0";
    public string? Description => "Example instrument with a setpoint and a measurement.";
    public Action<string, string>? StreamEmitter { get; set; }   // required, even without streams

    private readonly object _lock = new();
    private string _host = "";
    private double _setpoint;

    public MyDeviceDriver() { }   // public, parameterless, no I/O: also constructed at scan time

    public Task InitAsync(Dictionary<string, object?>? config)
    {
        _host = GetString(config, "host", "");
        if (_host == "") throw new ArgumentException("MyDevice needs config.host, e.g. \"192.168.1.50\"");
        // open the connection here
        return Task.CompletedTask;
    }

    public Task ShutdownAsync()   // also called on an instance that was never initialised
    {
        // close the connection if it is open
        return Task.CompletedTask;
    }

    public IEnumerable<PropertyDescriptor> GetProperties() =>
    [
        new PropertyDescriptor("setpoint", "double", "R/W", "V", "Output setpoint", Details: "Range 0–30 V."),
        new PropertyDescriptor("host", "string", "R", Description: "Device address"),
    ];

    public IEnumerable<ActionDescriptor> GetActions() =>
    [
        new ActionDescriptor("reset", "Reset to defaults"),
        new ActionDescriptor("ramp", "Ramp the setpoint to a target",
            [new ArgDescriptor("target", "double", "Target in V"), new ArgDescriptor("rate", "double", "V per second")]),
    ];

    public Task<object?> GetAsync(string property) => Task.FromResult<object?>(property switch
    {
        "setpoint" => _setpoint,
        "host" => _host,
        _ => throw new ArgumentException($"Unknown property: {property}"),
    });

    public Task SetAsync(string property, object? value)
    {
        if (property != "setpoint") throw new ArgumentException($"Property '{property}' is read-only");
        var v = ToDouble(value);
        if (v is < 0 or > 30) throw new ArgumentOutOfRangeException(nameof(value), "setpoint must be 0–30 V");
        lock (_lock) _setpoint = v;
        return Task.CompletedTask;
    }

    public Task<object?> ExecuteAsync(string action, object? args)
    {
        switch (action)
        {
            case "reset":
                lock (_lock) _setpoint = 0;
                return Task.FromResult<object?>("OK");
            case "ramp":
                var target = ArgDouble(args, "target", _setpoint);
                // ... ramp at ArgDouble(args, "rate", 1.0) V/s ...
                lock (_lock) _setpoint = target;
                return Task.FromResult<object?>(target);
            default:
                throw new ArgumentException($"Unknown action: {action}");
        }
    }
}
```

**Rules for C# drivers**

- Implement `IConnectorDriver` (there is no base class). Required members: `Name`, `InitAsync`,
  `ShutdownAsync`, `GetProperties`, `GetActions`, `GetAsync`, `SetAsync`, `ExecuteAsync`, and
  the `StreamEmitter` property. Optional: `Version`, `Description`, `SupportsStreaming`,
  `GetStreams`.
- Descriptors are records: `PropertyDescriptor(Name, Type, Access, Unit = "", Description = "",
  Details = "")`, `ActionDescriptor(Name, Description = "", Args = null, Details = "")`,
  `ArgDescriptor(Name, Type, Description = "")`. Named arguments use the capitalised parameter
  names (`Description:`, `Details:`).
- `[assembly: DriverGroup(...)]` is an **assembly** attribute: put it above the `namespace`
  line, not on the class.
- Read configuration and arguments with the `DriverConfig` helpers (`GetString`, `GetInt`,
  `GetDouble`, `GetBool`; `ArgString`, `ArgInt`, `ArgDouble`, `ArgBool`, `ArgDoubleArray`;
  `ToDouble`, `ToInt`, `ToBool`).
- **Calls are not serialised.** Polling, scripts and the UI call into the driver concurrently —
  guard shared state and the connection.
- Streams: return `true` from `SupportsStreaming`, list names in `GetStreams()`, and call
  `StreamEmitter?.Invoke("data", json)` with a JSON string. The emitter is only set when
  `SupportsStreaming` is true.
- Native libraries the vendor SDK needs go next to your DLL in the package root.

## Installing a driver

**Loose file (JavaScript and Python).** Put `mydevice.driver.js` or `mydevice.driver.py` directly
in `workspace/drivers/` — the top level, not a sub-folder. No manifest is needed. Muxit reads
drivers **only when the server starts**, so the user restarts Muxit, then creates a connector:

```js
// workspace/connectors/bench_device.js
export default {
  driver: "MyDevice",
  config: { port: "/dev/ttyUSB0", baudRate: 115200 },
};
```

**Package (`.muxdriver`, required for C#).** A ZIP file with these files at its root — no
folder inside:

| Type | Package contents |
|---|---|
| JavaScript | `manifest.json`, `<name>.driver.js`, `template.js`, optional `README.md`, `CHANGELOG.md` |
| Python | `manifest.json`, `<name>.driver.py`, `template.js`, other `.py` files it imports, `requirements.txt` |
| C# | `manifest.json`, `template.js`, `<AssemblyName>.dll`, its dependency DLLs and native libraries — **not** `Muxit.Driver.Sdk.dll` |

Name it after the id and version (`yourname-mydevice-v1.0.0.muxdriver`) and put it directly in
`workspace/drivers/`
(C# and JavaScript packages can also be installed from Muxit's Extensions panel; Python packages
only by copying the file). Restart the server.

**`manifest.json`**

```json
{
  "formatVersion": 1,
  "id": "yourname/mydevice",
  "name": "MyDevice",
  "version": "1.0.0",
  "description": "Line-based serial instrument driver with setpoint control and a line stream.",
  "author": { "name": "Your Name" },
  "tier": 1,
  "category": "free",
  "group": "instruments",
  "entryPoint": "mydevice.driver.js",
  "tags": ["serial"],
  "license": "MIT"
}
```

| Field | Rule |
|---|---|
| `formatVersion` | `1`. |
| `id` | `publisher/name` (the `publisher/` part is optional): lowercase letters, digits and `-`, starting with a letter or digit; publisher 2–40 characters, name 3–40. |
| `name` | The driver name connectors use; must match the code's name. |
| `version` | `x.y.z`, no suffix. Match the code's version. |
| `tier` | `1` JavaScript, `2` Python, `3` C#. |
| `category` | `"free"`. (Premium drivers are signed by Muxit.) |
| `entryPoint` | The file name only: `mydevice.driver.js`, `mydevice.driver.py`, or `<AssemblyName>.dll`. |
| `group` | `instruments`, `motion`, `communication` or `utilities`. |
| `description` | At least 40 characters. |
| `author` | If present, must have `name`. |
| `tags` | 1–8 of: `spectroscopy`, `motion`, `camera`, `robotics`, `power`, `daq`, `io`, `serial`, `networking`, `cnc`, `plotter`, `laser`, `monitor`, `terminal`, `arduino`, `esp32`, `gcode`, `grbl`, `drawing`, `canvas`, `pen`, `axidraw`, `audio`, `synth`, `notification`, `midi`, `printer`, `label`, `barcode`, `other`. |

**`template.js`** is the starter connector Muxit offers when the user adds a connector for your
driver — required in a package. It is an ordinary connector file:

```js
// template.js
export default {
  driver: "MyDevice",
  config: {
    port: "/dev/ttyUSB0",   // "COM3" on Windows
    baudRate: 115200,
  },
  ai: { instructions: "MyDevice bench instrument. Setpoint range 0–30 V." },
};
```

Add a `CHANGELOG.md` with a `## 1.0.0` heading per version if the driver will be shared.

## Common mistakes

| Mistake | Instead |
|---|---|
| `access: "rw"` or `"r"` | `"R/W"`, `"R"`, `"W"` exactly. |
| Slow I/O in `get` | Cache values; update them in `execute`, from `onData`, or a background loop. `get` runs every 200 ms per readable property. |
| Opening the port in the constructor or at module level | In `init(config)`. |
| JavaScript: arrow functions for `init` / `get` / … | Methods, so `this` works. |
| JavaScript: `await transport.query(cmd)` | Match replies through `onData`. |
| JavaScript: `delay(ms)`, `Buffer.from`, `require("serialport")` | `new Promise((r) => setTimeout(r, ms))`, strings, the built-in transports. |
| JavaScript: `__emitStream("data", { v: 1 })` | `__emitStream("data", JSON.stringify({ v: 1 }))` |
| Python: `print(...)` | `self.log(...)` or stderr. |
| Python: `"args": {"count": "int"}` | `"args": {"count": {"type": "int", "description": "…"}}` |
| Python: `import numpy` at the top of the file | Inside `init`. |
| C#: `[DriverGroup(...)]` on the class | `[assembly: DriverGroup(...)]` above the namespace. |
| C#: no `StreamEmitter` property | Declare it even without streams. |
| C#: shipping `Muxit.Driver.Sdk.dll` | Reference it with `<Private>false</Private>`; leave it out. |
| `requiresSafetyGates: false` | Not available to third-party drivers; leave it out. |
| A driver for a device a protocol already handles | A connector with `Scpi`, `LineText` or `BinaryStream`. |
| Expecting the server to pick up a new driver file | Restart Muxit. |

## Checklist

- [ ] A built-in protocol really cannot do this, and the language fits the device's SDK.
- [ ] The driver name is unique, not a built-in name, and identical in code, manifest and
      `template.js`.
- [ ] Every property has `type`, `access` (`"R"`, `"W"` or `"R/W"`) and a one-line
      `description`; actions describe their arguments; enums, units and side effects are in
      `details`.
- [ ] `get` returns quickly from cached state; the connection opens in `init`, closes in
      `shutdown`, and `shutdown` is safe when `init` never ran.
- [ ] `init` validates required configuration and throws a message that names the option.
- [ ] Errors are thrown with actionable messages; nothing fails silently.
- [ ] Every device command comes from the manual or the user; unverified ones are listed.
- [ ] JavaScript: `export default` with `meta`, methods not arrows, replies via `onData`, no
      `require(` / `import(` text, stream data as strings.
- [ ] Python: `META` action args are dicts, third-party imports inside `init`, no `print`,
      `run(...)` at the bottom, `requirements.txt` for dependencies.
- [ ] C#: implements `IConnectorDriver` with `StreamEmitter`, assembly-level `DriverGroup`,
      thread-safe, SDK referenced but not shipped.
- [ ] Told the user where the file goes, to restart Muxit, and gave them a connector that uses
      the driver.
