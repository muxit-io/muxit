---
title: Writing Scripts — Reference for AI Assistants
description: Everything an AI assistant needs to write a working Muxit automation script — the synchronous sandbox, device access, timing, files, operator prompts, safety, patterns and the mistakes to avoid.
---

# Writing Muxit scripts

*A reference for AI assistants. It is self-contained: you can write a correct script from this
page alone. Read [How a script runs](#how-a-script-runs) first and finish with the
[checklist](#checklist).*

A **script** is automation: a measurement run, a sweep, a monitoring loop, a data logger, an
alarm. It uses devices that already have connectors, by name — `connector("psu")` is the
connector defined in `workspace/connectors/psu.js`. If a device has no connector yet, write that
first ([Writing Connectors](https://docs.muxit.io/for-ai/connectors.md)).

## The deliverable

- **One file**, `workspace/scripts/<name>.js`. Sub-folders are fine
  (`workspace/scripts/tests/iv-curve.js`).
- **Plain top-level JavaScript.** No `export`, no `import`, no `main()` — the file body is the
  program. A top-level `return value;` ends the script and hands `value` back to whoever ran it.
- Scripts in `workspace/startup/` (top level only, alphabetical order) start automatically when
  the server starts, after connectors are up. Auto-start needs a Maker licence or higher.
- There are **no script parameters**. Put settings in constants at the top of the file, read
  them from a connector (a [Virtual](https://docs.muxit.io/for-ai/connectors.md#virtual-no-hardware) store a dashboard can
  edit), or ask the operator with [`ask.*`](#operator-interaction).

## You need the connector names and their properties

A script can only use names the connector actually has; anything else throws
`ReferenceError: Connector 'psu' has no property or method 'voltag'`. Do not guess names. Ask the
user for the connector file, or for the property and action list shown when the connector is
expanded in Muxit's **Connectors** panel. If you are connected to Muxit over MCP, call
`list_connectors` / `get_connector_schema`.

Know which names are **properties** (read with `dev.x`, write with `dev.x = v`) and which are
**actions** (call with `dev.x(…)`). Reading an action without parentheses gives you a function,
not a value — a camera's `snapshot`, for example, is an action: `cam.snapshot()`.

## How a script runs

```js
const psu = connector("psu");

psu.voltage = 5;                 // write: blocks until the device has it
psu.output = true;
delay(500);                      // let it settle
const v = psu.measured_voltage;  // read: a plain value, no await
log.info(`Measured ${v} V`);
return { v };                    // optional result
```

1. **Everything is synchronous.** Property reads, writes, action calls, `delay`, `ai` and `ask`
   block the script until they finish and return plain values. Do not write `await`; it is
   unnecessary (it does no harm on a value, but `await dev.x = 5` is a syntax error).
2. **Loops must call `delay(ms)`.** A loop without one spins a CPU core until stopped. `delay`
   caps at 300 000 ms (5 minutes) per call.
3. **There are no timers.** `setTimeout`, `setInterval` and `requestAnimationFrame` do not exist.
   Use a `while` loop with `delay`.
4. **Stop is a hard kill.** When the user presses Stop, the engine is interrupted wherever it
   is: code after the loop does not run and **`finally` blocks do not run**. Put setup before the
   loop, leave the hardware in a safe state at every iteration, and never rely on cleanup code at
   the end. A script that should run until stopped is simply `while (true) { …; delay(ms); }` —
   there is no `script.running` flag.
5. **An uncaught error ends the script**, logged with its line number. Wrap device calls you
   expect to fail in `try` / `catch`.
6. Different scripts run concurrently; the same script cannot be started twice. The Free tier
   allows three running scripts at once.

## Device access

```js
const dev = connector("name");     // device("name") is an alias
```

`connector()` throws if the connector does not exist or is disabled.

**Reading** `dev.prop` returns the latest polled value. Muxit polls every readable property the
device backend declares every 200 ms, so a read costs no I/O and can be up to about 200 ms old.
Properties the connector computes itself are recalculated on every read.

**Writing** `dev.prop = value` sends the value to the device and waits for the write to complete.
The value you read back immediately afterwards is still the *previous polled* value; to confirm a
setting, `delay(300)` and read again (or read a measured property after the device has settled).
Assigning `null`, `undefined`, `NaN` or `[]` does nothing. A property the *connector file* defines
with its own setter is the exception: the write is queued (at most one per 100 ms) and an error in
it only reaches the server log.

**Actions** are called with positional arguments in the documented order:

```js
dev.reset();                        // no arguments
psu.save(3);                        // one argument
wh.notify("Run done", "12 points", "success");   // several
dev.moveTo({ x: 10, y: 20 });       // or one object with named arguments
```

For a driver action, positional arguments are matched to the declared argument names, and an
object is passed through as named arguments. **Do not pass a lone array** — `dev.load([1, 2, 3])`
is treated exactly like `dev.load(1, 2, 3)`. Wrap it: `dev.load({ values: [1, 2, 3] })`.

What comes back is converted to plain JavaScript: numbers, strings, booleans, `null`, arrays and
objects.

## Globals

| Global | What it does |
|---|---|
| `connector(name)`, `device(name)` | Device proxy, as above. |
| `log.info(…)`, `log.warn(…)`, `log.error(…)`, `log.debug(…)` | Log to the script output panel. Any number of arguments, joined with spaces; plain objects are JSON-formatted, arrays are not — `JSON.stringify` them yourself. |
| `console.log`, `console.warn`, `console.error` | Aliases of `log.info` / `log.warn` / `log.error`. There is no `console.info` or `console.debug`. |
| `delay(ms)` | Sleep, up to 300 000 ms. Cut short when the script is stopped. |
| `timestamp()` | Current time as an ISO 8601 UTC string. |
| `stream(connectorName, streamName, data)` | Push data to dashboard widgets subscribed to that stream (a terminal, a chart, a canvas). |
| `say(text, opts?)` | Show `text` in the chat panel, spoken aloud when the user has script speech on. `opts.emotion`: `"excited"`, `"serious"`, `"whisper"`, … |
| `ask.confirm(msg, opts?)`, `ask.choose(msg, choices, opts?)`, `ask.text(msg, opts?)` | Ask the operator and wait for the answer. See [Operator interaction](#operator-interaction). |
| `ai(prompt, image?, options?)` | One LLM call, returns the answer as a string. See [AI](#ai). |
| `script.name` | This script's name: its path under `scripts/` without `.js` (`tests/iv-curve`), or `startup/<name>`. |

Standard JavaScript is available: `Math`, `JSON`, `Date`, `Number`, `String`, `Array`, `Object`,
`Map`, `Set`, `RegExp`, `Promise`, `Proxy`, `Reflect`, `globalThis`, template strings,
destructuring, classes and helper functions.

**Not available:** `require`, `import`, `fetch`, `XMLHttpRequest`, `WebSocket`, `fs`, `process`,
`Buffer`, `atob` / `btoa`, `TextEncoder`, `setTimeout`, `setInterval`, `eval`, `new Function`,
and every Node.js or browser API. Files go through a FileAccess connector; HTTP goes through a
WebhookNotifier connector; scheduling is a loop with `delay`.

**Do not use `emit()` or `on()`.** They exist, but nothing delivers events to script handlers
yet: an `on()` handler never runs, and `emit()` reaches nothing a script or dashboard can see.
To coordinate scripts, write and read a value on a shared Virtual connector instead.

## Files

The sandbox has no file system. Files go through a connector using the built-in **FileAccess**
driver, sandboxed to a folder of the workspace (by default `workspace/data/`). A new workspace
ships one named **`fileaccess`** — confirm the name with the user; if they have none, they add a
connector `{ driver: "FileAccess", config: { basePath: "data" } }` first.

```js
const fa = connector("fileaccess");
const f = fa.openText("runs/iv-curve.csv");   // path relative to workspace/data/

f.write("time,voltage_v,current_a\n");          // overwrite (creates folders)
f.append([timestamp(), 5.0, 0.103]);           // array → one CSV row, quoted as needed
f.append("a plain line\n");                    // strings are written as-is
const text = f.read();                         // whole file as a string
const lines = text.split("\n");
f.exists;                                       // property: true / false
f.size;                                         // property: bytes
f.rename("archive/iv-curve.csv");              // moves the file; the handle follows
f.delete();                                     // false if it was already gone

const tsv = fa.openText("out.tsv", "\t");      // another delimiter for array rows
const { files, dirs } = fa.list("runs");       // one folder, not recursive
fa.mkdir("runs/2026");

const img = fa.openBinary("snapshots/part.jpg");
img.write(connector("webcam").snapshot());     // binary handles read and write base64
```

Paths are always relative to the sandbox folder: `..` that escapes it is refused, and a leading
`/` is not an absolute path (`"/tmp/x.csv"` lands in `data/tmp/x.csv`). Files are limited to 10 MB
by default. Prefer `read().split("\n")` over `readLines()`, and avoid `info()`: both return .NET
objects rather than plain JavaScript ones.

## Operator interaction

```js
if (!ask.confirm("Output will switch on at 12 V. Continue?", { timeout: 60000, default: false })) {
  return "cancelled";
}
const port  = ask.choose("Which fixture?", ["A", "B", "C"], { default: "A", timeout: 120000 });
const label = ask.text("Batch label?", { timeout: 300000 });
```

- The script waits until a dashboard user answers.
- `timeout` is in milliseconds and at least 1000. Without it the script waits indefinitely.
- On timeout the script gets `default`; with no `default` it throws `PROMPT_TIMEOUT`.
- `requireObserver: true` pauses the countdown while no dashboard is open.

## AI

```js
const verdict = ai("Reply PASS or FAIL only: is 85 °C acceptable for a motor rated 90 °C?");
const seen = ai("Is the part seated in the fixture? Answer yes or no.", connector("webcam").snapshot());
```

`ai()` returns a string (up to about 1024 tokens) and has no memory between calls and no tools.
The second argument is a base64 JPEG, or an array of up to 8 images (strings or
`{ image, label }`). It uses the AI provider configured in Muxit: text works on every tier with a
local model and needs Maker on the Muxit-managed service; any call with an image needs Maker.
When the tier does not allow it, `ai()` throws — wrap it in `try` / `catch` if the script must
keep going.

## Safety

Writes and actions a script makes go through Muxit's safety gate, using the safety level the
user has chosen and — on the Lab tier — the connector's `safety` block. (Connectors on drivers
with no hardware to protect — Virtual, FileAccess, Webcam, Onvif, WebhookNotifier — skip the gate.)

- A blocked operation — out of range, or over a rate limit — throws an error with code
  `SAFETY_BLOCKED` and a message such as `limit.outOfRange`; the hardware never sees it.
- An operation that needs confirmation **pauses the script** until someone approves it in a
  dashboard. A denial, or no answer within 30 seconds of a dashboard being open, throws
  (`user.denied`); with no dashboard open the script waits.
- At the **Observe** level, ordinary writes are simulated without error and ordinary actions
  return `null`.

So do not catch and ignore safety errors in a loop; let the script stop, or stop it yourself.

## Patterns

**Sweep with CSV logging**

```js
// workspace/scripts/iv-curve.js — step the PSU, log V and I.
const psu = connector("psu");
const csv = connector("fileaccess").openText(`iv/${timestamp().replace(/[:.]/g, "-")}.csv`);

const START_V = 0, STOP_V = 5, STEP_V = 0.25, SETTLE_MS = 400;

csv.write("set_v,measured_v,measured_a\n");
psu.voltage = START_V;
psu.output = true;

for (let set = START_V; set <= STOP_V + 1e-9; set += STEP_V) {
  psu.voltage = Number(set.toFixed(3));
  delay(SETTLE_MS);                                   // settle + at least one poll cycle
  csv.append([set.toFixed(3), psu.measured_voltage, psu.measured_current]);
}

psu.output = false;                                   // a natural end; Stop would skip this
psu.voltage = 0;
return "done";
```

**Monitor with an alarm and hysteresis**

```js
const sensor = connector("thermocouple");
const alarm  = connector("webhook");          // a WebhookNotifier connector
const LIMIT = 80, HYSTERESIS = 5;
let armed = true;

while (true) {
  const t = sensor.temperature;
  if (t === null || t === undefined) { log.warn("no reading"); delay(1000); continue; }
  if (armed && t > LIMIT) {
    alarm.notify("Over temperature", `${t.toFixed(1)} °C`, "error");
    armed = false;
  } else if (!armed && t < LIMIT - HYSTERESIS) {
    armed = true;
  }
  delay(1000);
}
```

**Wait for a condition, with a timeout**

```js
function waitFor(check, timeoutMs, pollMs = 250) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    if (check()) return true;
    delay(pollMs);
  }
  return false;
}

const robot = connector("robot");
robot.moveTo({ x: 100, y: 50, z: 20 });
if (!waitFor(() => robot.idle, 30000)) throw new Error("move did not finish in 30 s");
```

**Hand values to a dashboard**: write them to a Virtual connector's properties
(`connector("store").status = "Running step 3/10"`); widgets bound to `store.status` update at
once.

## Common mistakes

| Mistake | Instead |
|---|---|
| `await dev.voltage`, `async function main()`, `main()` | Plain top-level code; reads return values directly. |
| `setTimeout` / `setInterval` | `while (true) { …; delay(ms); }` |
| `require("fs")`, `fetch(…)` | A FileAccess connector; a WebhookNotifier connector. |
| `on("event", …)` to react to something | Poll the value in a loop. |
| Cleanup after the loop or in `finally` | Safe state at every iteration; stop naturally with `break` when cleanup matters. |
| Loop without `delay` | Always `delay(ms)` inside loops. |
| Reading a value right after writing it and expecting the new value | `delay(300)` first, or read a measured property. |
| `dev.snapshot` for an action | `dev.snapshot()` — know which names are actions. |
| `connector("files")` | Use the user's FileAccess connector name (`fileaccess` in a new workspace). |
| Passing an array as the only argument | Wrap it in an object with the argument name. |
| Invented property or connector names | Ask for the connector's schema. |
| `read_property(…)`, `call_action(…)` inside a script | Those are AI tools, not script functions. Use the proxy. |

## Checklist

- [ ] The file goes in `workspace/scripts/` (or `workspace/startup/` to auto-start) and is plain
      top-level code: no `import`, `export`, `require` or `main()`.
- [ ] Every connector, property and action name came from the user or a schema, and actions are
      called with `()`.
- [ ] No `await`, no `setTimeout` / `setInterval`, no `on()` / `emit()`, no Node or browser APIs.
- [ ] Every loop calls `delay(ms)`.
- [ ] Nothing important happens after the loop or in a `finally` block; the hardware is safe at
      every point the script could be stopped.
- [ ] Setpoints are within limits the user confirmed; outputs are not switched on, and axes not
      moved, without the user asking for it.
- [ ] Reads that must reflect a just-written value wait at least one poll cycle.
- [ ] File access goes through the user's FileAccess connector with paths relative to its folder.
- [ ] Anything you could not verify (connector names, units, safe ranges) is listed for the user.
