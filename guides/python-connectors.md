---
title: Python Connectors
description: Wrap a Python script as a Muxit connector — vendor SDKs, ML models, anything from the Python ecosystem.
---

# Python Connectors

A lot of useful instrument code already exists in Python: vendor SDKs, lab toolkits, control libraries from a paper, ML models from huggingface. The generic `Python` driver lets you wrap any of it as a Muxit connector — same API to scripts, dashboards, and the AI as anything else.

This guide is the practical "I have a `.py` file, now what" path. For the full SDK reference (typed schemas, packaging as a `.muxdriver`, debugpy), see the [Python Driver SDK](https://docs.muxit.io/reference/driver-sdk-python.md).

## When to use this

Reach for Python when:

- A vendor ships a Python SDK and you'd rather not rewrite it as a JavaScript driver.
- You want numpy / scipy / pandas in the request path (signal processing, curve fitting).
- You want a model from huggingface or a local LLM as a "device".
- You already have an analysis script and you want to call it from automation scripts and dashboards.

Reach for a [JavaScript driver](https://docs.muxit.io/reference/driver-sdk-js.md) instead when the device just speaks SCPI, Modbus, or a simple serial / TCP protocol — the JS path has lower per-call overhead and no subprocess.

## Requirements

Python **3.10 or newer** on the host. Muxit probes `MUXIT_PYTHON` (env var with full path) → `python3` → `python`. If no interpreter is found, Python connectors are silently skipped at scan time and the rest of Muxit keeps working — see [System Requirements](https://docs.muxit.io/getting-started/system-requirements.md#optional-python-310).

## Five-minute walkthrough

### 1. Drop a `.py` file into `workspace/python/`

```python
# workspace/python/hello.py
def greet(name="world"):
    return f"hello {name}"
```

That's the whole script. No imports of `muxit_driver`, no class.

### 2. Add a connector pointing at it

```js
// workspace/connectors/python-hello.js
export default {
  driver: "Python",
  config: {
    script: "hello",   // → workspace/python/hello.py
  },
  methods: {
    greet: {
      fn: (name = "world") => driver.greet({ name }),
      description: "Greet a name and return the message",
    },
  },
};
```

### 3. Use it

From a script, dashboard widget, MCP client, or AI chat:

```js
const h = connector("python-hello");
log.info(h.greet("world"));   // "hello world"
```

The first activation spawns the Python subprocess (~150 ms warm). Subsequent calls round-trip over JSON-RPC on stdin/stdout — fast enough for most lab workflows, but not for tight inner loops.

## Properties: `get_<name>()` / `set_<name>(value)`

Properties are read/written by name from the connector. The driver maps them to `get_<name>()` and `set_<name>(value)` functions in your Python module.

```python
# workspace/python/counter.py
_state = {"count": 0}

def get_count():
    return _state["count"]

def set_count(value):
    _state["count"] = int(value)
```

```js
// workspace/connectors/python-counter.js
export default {
  driver: "Python",
  config: { script: "counter" },
  properties: {
    count: {
      fn: () => driver.count,         // → calls get_count()
      description: "Current counter value (read/write)",
    },
  },
};
```

A property is read-only if you only define `get_<name>`. If both exist, the connector exposes it as read/write — `c.count = 5` from a script calls `set_count(5)`.

## Lifecycle: `init` and `shutdown`

```python
def init(config):
    """Called once when the connector activates. config is the connector's `config:` block."""
    ...

def shutdown():
    """Called when the connector is disabled or the server stops."""
    ...
```

Both are optional. **Heavy imports go inside `init`**, not at module level — module top runs at scan time too, so a top-level `import torch` slows every server start and breaks scans on machines that haven't installed the deps.

## Dependencies: per-script virtual environments

List packages in a sibling `<script>.requirements.txt`:

```text
# workspace/python/http-probe.requirements.txt
requests>=2.31
```

On first activation Muxit creates `workspace/python/.venvs/<script>/`, runs `pip install -r` against it, and stamps a SHA-256 of the requirements file. Subsequent activations reuse the venv unless the hash changes. Pip output streams to the server console line by line so you can watch big installs (torch, transformers) finish.

The venv is **per script** — different scripts can pin conflicting versions of the same package without colliding.

If `<script>.requirements.txt` is absent, Muxit launches the script with the system interpreter directly: ~150 ms start, zero disk footprint.

## What's in scope inside the connector

The connector's `methods` and `properties` blocks are plain JavaScript — see the [Connector Guide](https://docs.muxit.io/guides/connectors.md). Inside their handlers:

- `driver.<name>` — read a Python property (calls `get_<name>()`).
- `driver.<name> = value` — write a Python property (calls `set_<name>(value)`).
- `driver.<fn>({ ...kwargs })` — call a Python function. Arguments are passed as keyword arguments.

The `methods` and `properties` blocks are also where you add descriptions for the AI prompt and the script editor's IntelliSense — without them, the connector still works, but the AI has no idea what your functions do.

## Examples that ship with Muxit

A new workspace ships with four working examples in `workspace/python/`:

| Script | Connector | Demonstrates |
|---|---|---|
| `hello.py` | `python-hello.js` | The minimum viable Python connector. |
| `counter.py` | `python-counter.js` | State + read/write properties. |
| `http-probe.py` | `python-http-probe.js` | A `requirements.txt` (pulls in `requests`). |
| `chatterbox.py` | `python-chatterbox.js` | Heavy ML deps (torch + transformers + chatterbox). First activation pulls a couple of GB; each `speak()` writes a WAV to `workspace/data/chatterbox/`. |

Open `workspace/python/README.md` for the conventions list.

## When the generic driver isn't enough

The generic `Python` driver is great for gluing existing code. You'll outgrow it when:

- You need typed property/action schemas (so the AI prompt and IntelliSense are richer).
- You need `self.emit()` to push streaming data (waveforms, sensor frames).
- You're shipping the driver to other people as a packaged `.muxdriver`.

The migration is mechanical — copy your top-level functions into a `Driver` subclass, add a `META` block. See [Python Driver SDK — Structure](https://docs.muxit.io/reference/driver-sdk-python.md#structure).

## Common pitfalls

- **`(non-json stdout)` in the server log** — you used `print()`. stdout is the JSON-RPC channel; use `print(..., file=sys.stderr)` for ad-hoc debug output instead, or wire up `self.log()` from the typed `Driver` subclass route.
- **`ImportError` at init** — your heavy import is at module top level. Move it inside `init()` so the venv install runs before the import fires.
- **First activation hangs** — pip is probably still working on a big native wheel (torch, opencv). The `[pip]`-prefixed lines on the server console tell you what's happening.
- **`python -m venv` failed** on Debian/Ubuntu — `apt install python3-venv` once.

## See also

- [Python Driver SDK reference](https://docs.muxit.io/reference/driver-sdk-python.md) — full SDK, packaging, debugging with debugpy.
- [Connector Guide](https://docs.muxit.io/guides/connectors.md) — the connector config format (driver-agnostic).
- [Driver SDK overview](https://docs.muxit.io/reference/driver-sdk.md) — JS, Python, and C# tiers compared.
