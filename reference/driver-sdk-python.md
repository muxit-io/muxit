---
title: Python Driver SDK
description: Build Python device drivers for Muxit — subprocess-isolated, JSON-RPC bridge.
---

# Python Driver SDK (Tier 2)

Python drivers are `.driver.py` files. They run as a separate subprocess per active connector, communicating with MuxitServer over line-delimited JSON-RPC on stdin/stdout. Use this tier when you need the Python ecosystem (numpy, torch, transformers, instrument SDKs) — anything else is faster as a [JS driver](https://docs.muxit.io/reference/driver-sdk-js.md).

## Requirements

- Python **3.10 or newer** on the host machine. Muxit probes `MUXIT_PYTHON` (env var with full path) → `python3` on PATH → `python` on PATH, in that order. The first interpreter that reports a usable version wins.
- If no Python is found, Python drivers are silently skipped at scan time (with a one-line warning per `.driver.py`). The rest of Muxit keeps working.

Install Python from [python.org](https://www.python.org/downloads/) or your system package manager. No further setup is needed for drivers without third-party dependencies.

## Two ways to use Python

There are two paths, in order of how much Python you want to write:

1. **The generic `Python` driver** — point a connector at any `.py` file in `workspace/python/` and call its top-level functions. No `Driver` class, no SDK boilerplate. **Start here** if you mostly want to glue an existing Python library to a connector. See [Generic `Python` driver](#generic-python-driver) below.
2. **A bespoke `.driver.py`** — subclass `Driver`, declare a typed `META` block, ship as a packaged `.muxdriver`. Use this when you're building a polished driver for distribution: typed property/action schema, opt-out of safety gates, custom packaging. See [Structure](#structure) below.

Both paths run on the same Tier 2 host (subprocess + JSON-RPC), share the same `requirements.txt` auto-install behaviour, and can be debugged the same way.

## Generic `Python` driver

The `muxit/python` driver (built and shipped from `drivers/py/python-runner/`) is a generic dispatcher: it loads any `.py` file you point it at and exposes that file's top-level functions as actions / properties.

A new workspace ships with four working examples in `workspace/python/` and matching connectors in `workspace/connectors/`:

- **`hello.py`** + `python-hello.js` — single function, no dependencies.
- **`counter.py`** + `python-counter.js` — adds state, demonstrates `get_<x>()` / `set_<x>(value)` properties.
- **`http-probe.py`** + `python-http-probe.js` — uses `requests`, demonstrates the per-script venv (sibling `http-probe.requirements.txt`).
- **`chatterbox.py`** + `python-chatterbox.js` — text-to-speech via the [chatterbox-tts](https://github.com/resemble-ai/chatterbox) library. Heavy-deps demo: first activation pulls torch + transformers + chatterbox into the venv (a couple of GB, several minutes); each `speak()` writes a WAV under `workspace/data/chatterbox/` and returns the path.

Open `workspace/python/README.md` for the full conventions list.

### Layout

```text
workspace/
  python/
    chatterbox.py                  # your script — plain functions, no class
    chatterbox.requirements.txt    # optional, sibling, one package per line
    .venvs/
      chatterbox/                  # auto-created on first activation
```

### Your script

```python
# workspace/python/chatterbox.py
from chatterbox import TTS
_tts = None

def init(config):
    """Optional. Called once when the connector activates. Load models here."""
    global _tts
    _tts = TTS()

def speak(text):
    return _tts.synthesize(text)

# Properties: get_<name>() / set_<name>(value)
def get_status():
    return "ready" if _tts is not None else "idle"

def shutdown():
    """Optional. Called when the connector disables / server stops."""
    pass
```

That's the whole contract — no imports of `muxit_driver`, no class, no JSON. Function signatures define what the connector can call.

### Connector

```js
// workspace/connectors/chatterbox.js
export default {
  driver: "Python",
  config: {
    script: "chatterbox",   // → workspace/python/chatterbox.py
  },
  methods: {
    speak: [(text) => connector().speak({ text }), "speak text out loud"],
  },
  properties: {
    status: () => connector().status,
  },
};
```

### Lifecycle

1. **First activation**: if `chatterbox.requirements.txt` exists, Muxit creates `workspace/python/.venvs/chatterbox/`, runs `pip install -r` against it, stamps a hash of the requirements file. Output streams to the server console line-by-line.
2. The driver subprocess imports `chatterbox.py` with the venv's `site-packages` prepended to `sys.path`, so `from chatterbox import TTS` resolves to the venv-installed package.
3. **Subsequent activations**: if the requirements hash matches, pip is skipped (~150ms warm start). Otherwise the install runs again (pip handles incremental updates).
4. RPC calls from the connector dispatch to the matching function: `connector().speak({text})` → `module.speak(text=...)`. `connector().counter` (read) → `module.get_counter()`. `connector().counter = 5` → `module.set_counter(5)`.
5. **Disable / shutdown**: optional `module.shutdown()` is called, then the subprocess exits.

### Limitations vs. a bespoke `Driver` subclass

- Property and action types are not declared in the script — the connector's `methods` and `properties` blocks are the source of truth for what's exposed and how it's typed. Auto-generated schema (used by the AI prompt and the script editor's IntelliSense) is therefore looser; for a polished public driver, use the typed `Driver` subclass route.
- No `self.emit()` for streams from a generic-driver script — streaming use cases need the `Driver` subclass route.
- One subprocess per connector (same as the typed route).

If you outgrow the generic driver, the migration is mechanical: copy your functions into a `Driver` subclass, add a `META` block with typed properties / actions, package as a `.muxdriver`.

## Where `muxit_driver` comes from

Every driver starts with `from muxit_driver import Driver, run`. You never install that package to run a driver **inside Muxit** — the host makes it importable for you, from one of three places:

| How the driver got there | Where the SDK comes from |
|---|---|
| Installed `.muxdriver` package | A copy of `muxit_driver/` vendored into the package by `node drivers.js build`, sitting next to your `.driver.py`. |
| Loose `.driver.py` in `workspace/drivers/` | `python-sdk/muxit_driver/`, shipped alongside the `muxit` binary. The host puts it on the subprocess' `PYTHONPATH`. |
| Source checkout (`node start.js server`) | The `drivers/py/` dev tree, found by walking up from the binary. |

Running a driver **by hand**, outside the server, is the one case where nothing sets that up for you:

```
ModuleNotFoundError: No module named 'muxit_driver'
```

Fix it once, either way:

```bash
# One-off: point PYTHONPATH at the SDK's parent directory
PYTHONPATH=drivers/py python3 mydriver.driver.py --scan

# Or install it into your interpreter (editable, so edits to the SDK apply)
pip install -e drivers/py
```

The same applies to a virtualenv you made yourself for a driver's dependencies — install the SDK into it too, or keep `PYTHONPATH` set.

## Structure

```python
from muxit_driver import Driver, run

class MyDriver(Driver):
    META = {
        "name": "MyDriver",
        "version": "1.0.0",
        "description": "Short description of what this driver does.",
        "group": "instruments",  # "instruments" | "motion" | "communication" | "utilities"
        "requiresSafetyGates": True,  # always True — Python drivers cannot opt out of safety gates
        "properties": {
            "voltage": {"type": "double", "access": "R/W", "unit": "V",
                        "description": "Output voltage"},
        },
        "actions": {
            "reset": {"description": "Reset device"},
            "set_curve": {
                "description": "Upload a setpoint curve",
                "args": {"points": {"type": "double[]", "description": "Setpoints in V"}},
            },
        },
        "streams": ["measurements"],
    }

    def init(self, config):
        # Heavy imports (torch, numpy, ...) belong HERE, not at module level.
        # Module-level code runs at scan time too, where deps may be missing.
        from somelib import Device
        self._dev = Device(config["serial"])

    def get(self, property):
        if property == "voltage":
            return self._dev.read_voltage()
        raise KeyError(property)

    def set(self, property, value):
        if property == "voltage":
            self._dev.write_voltage(float(value))
            return
        raise KeyError(property)

    def execute(self, action, args):
        if action == "reset":
            self._dev.reset()
            return
        if action == "set_curve":
            return self._dev.upload(args["points"])
        raise KeyError(action)

    def shutdown(self):
        self._dev.close()


if __name__ == "__main__":
    run(MyDriver)
```

Sync and `async def` methods are both supported — return a coroutine and the dispatcher will await it.

## Connector starter template

Ship a `template.js` next to your `.driver.py`. It's the connector starter content users see when creating a connector for your driver. The packager copies it into the `.muxdriver` at the package root. **Required** — `node drivers.js build` refuses to package a driver without it.

```text
drivers/py/mydriver/
├── mydriver.driver.py
├── manifest.json
├── template.js          ← starter connector (required)
└── requirements.txt     ← optional runtime deps
```

## Manifest

```json
{
  "formatVersion": 1,
  "id": "you/mydriver",
  "name": "MyDriver",
  "version": "1.0.0",
  "description": "...",
  "tier": 2,
  "category": "free",
  "group": "instruments",
  "entryPoint": "mydriver.driver.py",
  "author": { "name": "Your Name" },
  "tags": ["other"]
}
```

`tier` must be `2`. `entryPoint` must end with `.driver.py`. `category` must be `"free"` — premium signing for Python drivers is not yet implemented.

## Runtime dependencies

Place a `requirements.txt` next to your `.driver.py`. The packager bundles it into the `.muxdriver`. The first time a connector built on the driver is activated, Muxit:

1. Creates a per-driver virtual environment under the package's cache dir (`workspace/drivers/.cache/<id>@<version>/.venv/`).
2. Runs `pip install -r requirements.txt` against that venv, streaming output to the server console and emitting `driver.python.install` events on the EventBus so the UI can show progress.
3. Stamps a SHA-256 hash of `requirements.txt` in `.venv/.muxit-req-hash`. Subsequent activations check the hash; same hash → skip pip; different hash → re-run pip (incremental, pip handles delta).
4. Launches the driver subprocess with the venv's `python` so `import torch` (or whatever the driver imports inside `init()`) resolves to the venv-installed package.

The venv is per-driver — different drivers can pin conflicting versions of the same package without colliding. The venv lives in the package cache dir, so when the user upgrades or uninstalls the driver, the venv goes with it (no orphaned installs littering the system).

If `requirements.txt` is absent the venv step is skipped entirely and Muxit launches the driver directly with the system interpreter (faster startup, zero disk footprint).

**Caveats**

- Native wheels (torch, opencv) sometimes need system-level build tools or libraries. If pip fails, the error surfaces as the driver's init error with the full pip transcript above it.
- On Debian/Ubuntu the system Python may not include the `venv` module by default — `apt install python3-venv` once if you see `python -m venv` failing.
- Loose `.driver.py` files dropped into `workspace/drivers/` (dev workflow, no `.muxdriver` packaging) do **not** get a managed venv — there's no cache dir for the venv to live in. Use packaged drivers when you want auto-install.

## Logging and streams

Inside your driver class:

```python
self.log("opened device", level="info")     # forwarded to the Muxit console
self.emit("measurements", {"v": 12.3})       # emits on stream "measurements"
self.emit_progress("download", "got 1024/2048 bytes")  # long-install progress
```

Anything written to `stderr` is forwarded to the console verbatim (useful for tracebacks, library warnings). Anything `print()`-ed to `stdout` is logged with a "non-json stdout" hint — use `self.log()` instead.

Every line from any of these channels (plus stderr) lands in the **connector console tab** in the bottom panel — a per-connector 🐍 tab appears as soon as the connector activates, showing live output and preserving the last 500 lines. `emit_progress(stage, line)` is special: each line also updates the connector status badge, so the user sees pip / model-download progress in real time during long installs without having to open the tab.

## The connector console (REPL)

Each running Python connector gets a console tab in the bottom panel with an input line at the bottom. Whatever you type is sent to the driver subprocess as a `_eval` RPC and evaluated against the driver's globals; for the generic `Python` driver, that means the *user script's* module namespace.

```
🐍 python-chatterbox
[pip] Successfully installed torch-2.5.1 chatterbox-tts-0.1.2 …
info: Loading chatterbox model on cpu …
info: Chatterbox ready (sample rate 24000 Hz)
> model.sr
24000
> print(_state.keys())
dict_keys(['model', 'sr', 'out_dir', 'device'])
```

Use it to inspect the loaded model, check what config the driver received, or sanity-check that a library imported the way you expected — without restarting the connector. Override `Driver._eval_globals()` in your own driver if you want to expose extra names to the REPL.

## Debugging

Three paths from "my driver does something weird" to "fixed it", in order of how invasive they are.

### 1. Read the error response

When your driver raises an exception, the user-facing error message now includes the location:

```
KeyError: 'unknown property: voltage'
  at get() in mydriver.driver.py:62
  at _coerce() in mydriver.driver.py:91
```

The first line is the exception, the rest is up to 3 frames of *your* code (SDK frames are filtered out). The full Python traceback also goes to the server console via stderr — that's the place to look when you need to see the entire chain.

### 2. Run the driver standalone

You don't need to start MuxitServer to reproduce a problem. Two single-line commands are enough (with the SDK importable — see [Where `muxit_driver` comes from](#where-muxit-driver-comes-from) if the first line of your driver raises `ModuleNotFoundError`):

```bash
# Verify your META block is valid
python3 mydriver.driver.py --scan

# Drive the dispatch loop manually — paste JSON-RPC requests, see responses
python3 -u mydriver.driver.py --instance dev
> {"id": 1, "method": "init", "params": {}}
{"event": "log", "level": "info", "message": "Hello"}
{"id": 1, "result": null}
> {"id": 2, "method": "execute", "params": {"action": "greet", "args": {"name": "alice"}}}
{"id": 2, "result": "hello alice"}
```

The `--scan` mode prints `{"meta": {...}}` and exits — useful for catching typos in your `META` dict before they show up at server start. The `--instance` mode is the same JSON-RPC loop the server drives, just with you typing the requests instead.

### 3. Attach a debugger (debugpy + VS Code)

For step-through debugging, set `MUXIT_PYTHON_DEBUG=<port>` in the connector's environment (e.g. `5678`). The driver will pause at startup and wait for a debugger to attach to `127.0.0.1:<port>` before it runs `init`.

```bash
# Add debugpy to your driver's deps:
echo "debugpy" >> requirements.txt

# Then in VS Code: "Run and Debug" → "Python: Attach" on port 5678.
```

Use cases: pausing inside `init` to inspect what the device returned the first time you connect, walking through a complicated `execute()` line by line, or just dropping a `breakpoint()` somewhere and seeing it fire when the dashboard pokes the connector. `pdb.set_trace()` does **not** work — the subprocess' stdin is busy with JSON-RPC, so pdb's interactive prompt has nowhere to read from.

If `MUXIT_PYTHON_DEBUG` is set but `debugpy` isn't installed, the driver prints a one-line hint to stderr and continues without debugging — you'll see it in the server console.

### Common pitfalls

- **`ModuleNotFoundError: No module named 'muxit_driver'`** — you're running the driver outside Muxit (or from a venv the host didn't launch). Set `PYTHONPATH=drivers/py`, or `pip install -e drivers/py`. Inside Muxit this should never happen; if it does, the server log prints the SDK path it expected.
- **`(non-json stdout)` in the server log** — you used `print()` somewhere instead of `self.log()`. stdout is the JSON-RPC channel; tame it with `self.log()` or send debug output to `print(..., file=sys.stderr)` instead.
- **`MissingMethodException` / `ImportError` at init** — your heavy imports are at module level. Move them inside `init()` so scan time stays clean and the venv install runs before the import fires.
- **Driver hangs on first init** — pip is probably still working on a big native wheel. Watch the server console; the `[pip]`-prefixed lines tell you what's happening.
- **`python -m venv` failed** on Debian/Ubuntu — `apt install python3-venv` once.

## Why heavy imports go inside `init`

Scan time runs the module with `--scan` to extract `META`. If you `import torch` at the top of the file, every server start has to import torch (and the deps must be installed even on machines that don't run that driver). Putting the import inside `init` keeps scans fast and keeps the catalog usable on machines that haven't installed your driver's deps yet.

## Wire protocol (reference)

One JSON object per line on stdin/stdout:

| Direction | Shape | Meaning |
|---|---|---|
| host → driver | `{"id": N, "method": "init"\|"get"\|"set"\|"execute"\|"shutdown", "params": ...}` | RPC request |
| driver → host | `{"id": N, "result": ...}` | success |
| driver → host | `{"id": N, "error": "..."}` | failure |
| driver → host | `{"event": "log", "level": ..., "message": ...}` | structured log (async) |
| driver → host | `{"event": "stream", "name": ..., "data": ...}` | stream emit (async) |

The SDK's `run()` handles all of this for you — you only see the `init` / `get` / `set` / `execute` / `shutdown` Python methods.

## Limitations vs. C# (Tier 3)

- No premium signing — Python drivers are free-only.
- One subprocess per active connector — modest memory overhead vs in-process JS/DLL drivers.
- Subprocess startup adds ~100–500ms to connector init (plus a one-off `pip install` on the very first activation if the driver ships a `requirements.txt`). Subsequent activations reuse the cached venv and start in ~150ms.
- No transport factories: open serial / TCP from the driver's own Python code (`pyserial`, `socket`, ...). The host doesn't proxy transports the way it does for JS drivers.
