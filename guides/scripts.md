---
title: Script Guide
description: Sandboxed JavaScript automation scripts — available globals, lifecycle, and examples.
---

# Script Guide

Muxit scripts are sandboxed JavaScript automation programs that control your devices. They have access to connected devices but cannot use Node.js APIs — no `require`, `import`, or direct filesystem/network access. To read or write files from a script, use a [FileAccess connector](#working-with-files) instead.

> **Tip — no need to memorise names:** drag any property, action, or stream from the Hardware panel straight into the script editor and Muxit pastes the matching code. See [UI Tour → Drag-and-Drop](https://docs.muxit.io/getting-started/ui-tour.md#drag-and-drop) for the full table.

## Quick Reference

```javascript
const dev = connector("name");        // get a device
dev.voltage                           // read a property (no parens)
dev.voltage = 12                      // write a property (assignment)
dev.reset()                           // execute an action
dev.rampTo(24)                        // call a custom method

log.info("message")                   // logging (info/warn/error/debug)
emit("event-name", { data: 123 })     // send an event
on("event-name", (data) => { ... })   // listen for events
stream("connector", "stream", data)    // emit stream data

delay(1000)                           // wait 1 second (abortable)
script.name                           // this script's name
timestamp()                           // current ISO timestamp
say("message")                        // send text to chat panel (spoken when the status-strip speaker is on)
ai("prompt")                          // single-shot LLM call (returns string)
ai("prompt", imageData)               // LLM call with vision (image analysis)

ask.confirm("Proceed?", { timeout: 30000, default: false })
ask.choose("Which port?", ["COM1","COM2"], { default: "COM1" })
ask.text("Run label?", { timeout: 60000 })
```

**Not available:** `require`, `import`, `fs`, `process`, `net`, `eval`. The sandbox blocks direct Node.js APIs — for file I/O, use a [FileAccess connector](#working-with-files).

> **Note:** All connector, `delay()`, and `ai()` calls are synchronous — no `await` needed. If you prefer `await`, it still works (awaiting a non-Promise resolves immediately).

---

## Running Scripts

**From the GUI:** Open a script file and click **Run** in the editor toolbar.

**From WebSocket:**
```json
{ "type": "scripts.start", "name": "hello" }
{ "type": "scripts.stop", "name": "hello" }
```

---

## Startup Scripts

Place `.js` files in `workspace/startup/` to have them run automatically when the server starts. Startup scripts use the same sandbox and globals as regular scripts — they're just launched automatically instead of manually.

::: tip Maker and above
The launch-on-boot needs a Maker license or higher. On Free the files are still listed under `startup/` and can be started by hand from the file explorer or with `scripts.start`; they just don't run on their own, and the server log says so at startup (`Startup scripts not run: …`).
:::

**How it works:**
- All `.js` files in `workspace/startup/` are started after connectors initialize (so devices are available)
- Scripts run in alphabetical order — prefix with numbers for explicit ordering (`01-init.js`, `02-monitor.js`)
- Each script runs independently — one failure doesn't block others
- Named as `startup/<filename>` in logs and script lists (e.g., `startup/monitor`)
- The startup folder in the file explorer has the same controls as the scripts folder — play/stop buttons, "New Startup Script" context menu, and favorites support
- Can be stopped like any script: `{ "type": "scripts.stop", "name": "startup/monitor" }`
- Can be manually started from the UI or via WebSocket: `{ "type": "scripts.start", "name": "startup/monitor" }`
- Stopped automatically during server shutdown

**Example:** Create `workspace/startup/log-temps.js`:

```javascript
const sensor = connector("thermocouple");

while (true) {
  const temp = sensor.temperature;
  log.info(`Temperature: ${temp}°C`);
  delay(5000);
}
```

This script will start every time the server launches and log temperatures every 5 seconds until stopped.

> **Tip:** To temporarily disable a startup script without deleting it, rename it to a non-`.js` extension (e.g., `monitor.js.disabled`).

---

## Available Globals

### `connector(name)` / `device(name)`

Returns a proxy object for the named connector. Properties use direct access syntax. Actions and custom methods use function calls.

```javascript
const psu = connector("psu");

const voltage = psu.voltage;             // read property (no parens)
psu.voltage = 12;                        // write property (assignment)
psu.reset();                             // action (function call)
psu.rampTo(24);                          // custom method (function call)
```

The proxy convention:
- **No arguments** → reads the property (`driver.get(name)`)
- **One argument** → writes the property (`driver.set(name, value)`)
- **Known action** → executes the action (`driver.execute(name, args)`)

### `log`

Structured logging with four levels. Output appears in the bottom panel and server console.

```javascript
log.info("Voltage set to 12V");
log.warn("Temperature approaching limit");
log.error("Connection lost");
log.debug("Raw response: " + data);
```

### `emit(event, data)`

Publish an event on the EventBus. Other scripts and WebSocket clients can subscribe.

```javascript
emit("reading", { voltage: 12.3, current: 0.5 });
```

Events are namespaced as `script:<event>` on the bus.

### `on(event, handler)`

Subscribe to events from other scripts or the system. Returns a cleanup function.

```javascript
const cleanup = on("alert", (data) => {
  log.warn(`Alert: ${data.message}`);
});
```

Event listeners are automatically cleaned up when the script finishes.

### `stream(connector, streamName, data)`

Emit stream data on the EventBus. Used for continuous data like spectrometer readings or generated images.

```javascript
stream("spectrometer", "spectrum", { wavelengths: [...], intensities: [...] });
```

### `delay(ms)`

Pause execution. Abortable — if the script is stopped, `delay()` resolves immediately.

```javascript
delay(1000);  // wait 1 second
```

### `timestamp()`

Returns the current time as an ISO 8601 string.

### `say(text)`

Send a message to the Chat Panel. If the **script speech** toggle (🔊 button in the top status strip, next to STOP ALL) is on, the message is spoken aloud. Useful for scripts that report status audibly.

```javascript
while (true) {
  const temp = device('thermocouple').temperature;
  say(`Temperature is ${temp} degrees`);
  delay(60000);  // announce every minute
}
```

Messages appear in the Chat Panel with the script's name as the sender. The script-speech toggle is independent of the AI chat TTS toggle: you can mute AI replies while still hearing `say()`, or vice versa. The text is also spoken when the chat panel is closed.

### `ai(prompt, image?)`

Single-shot LLM call. Sends a prompt to the configured AI provider and returns the response text. Optionally pass an image for vision analysis.

```javascript
// Text-only AI query
const answer = ai("What is the capital of France?");

// Vision: analyze a camera image
const cam = connector('webcam');
const frame = cam.snapshot;
const description = ai("Describe what you see in this image", frame);
log.info(description);
```

The call blocks until the response is ready and returns a string. It uses the same AI provider and model configured in `server.json`. This is a single-shot call — it has no conversation memory and does not trigger the agentic tool loop.

### `ask.confirm / ask.choose / ask.text`

Pause the script and ask the operator a question. The script blocks until a
dashboard user answers, the optional timeout fires, or the script is stopped.

```javascript
// Yes/no, with a 30 s timeout that silently defaults to "no".
if (!ask.confirm('Home all axes before run?', { timeout: 30000, default: false })) {
    log.warn('User declined — skipping homing');
    return;
}

// Pick one of N choices. Clock pauses while no dashboard is subscribed.
const port = ask.choose('Select instrument port', ['COM1','COM2','COM3'], {
    requireObserver: true,
    timeout: 120000,
    default: 'COM1',
});

// Free-form text. No default — throws PROMPT_TIMEOUT if nobody answers in time.
const label = ask.text('Run label?', { timeout: 60000 });
```

**Options:**

- `timeout` — milliseconds (≥ 1000) to wait before falling back to `default` or throwing. Omit to wait forever.
- `default` — value returned on timeout. Omit it entirely to raise `PROMPT_TIMEOUT` instead.
- `requireObserver` — when `true`, the countdown pauses while no dashboard is subscribed. Prevents an unattended prompt from silently defaulting itself.

Return values are the raw answer (`boolean`, `string`) and are indistinguishable
from a human response. Consult the script logs if you need to know whether the
default was used.

### Video Recording

Camera connectors (Webcam, ONVIF) support video recording to `workspace/data/recordings/`:

```javascript
const cam = connector('webcam');

// Record for a fixed duration (blocks until done)
const file = cam.record({ seconds: 20 });
log.info(`Saved: ${file}`);

// Manual start/stop
cam.recordStart({ filename: "experiment-1" });
delay(30000);
const result = cam.recordStop();
log.info(`Saved: ${result}`);
```

If the camera stream isn't already active, recording auto-starts it (and stops it again when recording ends). Files are saved as MP4 (or AVI fallback) and accessible via the FileAccess driver.

### Working with Files

Scripts cannot call Node.js APIs like `require('fs')` — those are blocked by the sandbox. To read or write files, go through a **FileAccess connector**. A default workspace ships with one called `files` that's sandboxed to `workspace/data/`; if yours doesn't have one, add it from the Connectors panel (or drop `connectors/file-access.js` using the built-in `FileAccess` driver).

```javascript
const files = connector('files');

// Bind the path once with .openText() — the handle's methods don't repeat it
const log = files.openText('run.log');
log.write('started\n');               // overwrite (creates parent dirs)
log.append('reading=42.5\n');         // append a line
const text = log.read();              // full text
log.readLines();                      // string[]
log.exists;                           // bool
log.size;                             // bytes
log.info();                           // { name, size, created, modified, extension }
log.rename('archive/run.log');        // updates the handle in place
log.delete();                         // idempotent — returns false if missing

// Directory listing
const { files: items, dirs } = files.list('');
```

All paths are relative to the connector's sandbox root (`workspace/data/` by default). Parent directories are created automatically on write.

**Live editor refresh.** When a FileAccess write touches a file that's currently open in an editor tab, the tab reloads automatically — so a `.csv` log being appended to from a script updates its chart/table in real time without having to close and reopen the file. Unsaved edits in a dirty tab are preserved (the refresh is skipped for that tab).

**CSV logging pattern.** Pass an array to `append` and the handle joins it with the configured delimiter (default `,`), auto-quoting any cell that contains the delimiter, a double-quote, or a newline (RFC 4180). Numbers format with invariant culture, so a `nl-NL` host doesn't turn `2.5` into `"2,5"`.

```javascript
const files = connector('files');
const csv = files.openText(`runs/${timestamp().replace(/[:.]/g, '-')}.csv`);
csv.write('time,temp_c\n');           // header once

while (true) {
  csv.append([timestamp(), connector('sensor').temperature]);
  delay(1000);
}
```

Open the resulting `.csv` in an editor tab and watch the chart grow as the script runs. For binary payloads, use `files.openBinary(path)` — its `write(base64)` accepts the base64 string that `cam.snapshot()` and similar drivers produce. See the [FileAccess driver reference](https://docs.muxit.io/reference/drivers/file-access.md) for the full handle surface.

### `script`

Script information.

```javascript
script.name     // the script's name (e.g., "hello")
```

## Stopping a Script

A script ends when its last line has run, or when you press **Stop**. There is no flag to check: a script that should run until stopped is simply an endless loop.

```javascript
while (true) {
  // do work
  delay(100);
}
```

> **Stop is a hard-kill.** Pressing **Stop** cancels `delay()` and any pending device call, *and* interrupts the V8 engine, so the script ends wherever it is. Statements after the loop and `finally` blocks do **not** run. Put setup and safe-state writes *before* the loop, and keep the device in a safe state at every iteration — don't rely on trailing cleanup.

### `console.log(...args)`

Alias for `log.info()`.

### Standard JavaScript Globals

`Math`, `JSON`, `Date`, `parseInt`, `parseFloat`, `isNaN`, `isFinite`, `Number`, `String`, `Boolean`, `Array`, `Object`, `Map`, `Set`, `Promise`.

---

## What Is NOT Available

- `require()` and `import`
- `fs`, `path`, `net`, `http`, `child_process` and all Node.js modules
- `process`, `global`, `globalThis`
- `eval()` (beyond the sandbox context)
- `Proxy`, `Reflect`

---

## Return Values

Scripts can return values with a top-level `return` statement. When the script is run through the AI / MCP `run_script` or `run_code` tools, the return value is included in the response.

When the AI assistant calls `run_script` or `run_code`, the tool waits up to `wait_seconds` (default 15, max 120) for the script to finish. If it completes in time, the response is `{ status: "completed", result, ... }`. If it doesn't, the response is `{ status: "running", run_id, recent_output, next_seq, ... }` and the script keeps running — the AI can then call `get_script_status`, `get_script_output`, `wait_for_script`, or `stop_script` to manage it without blocking the chat. Pass `wait_seconds: 0` for known background scripts (monitors, watchers) to have the tool return immediately.

```javascript
const v = connector("psu").voltage;
const i = connector("psu").current;
return { voltage: v, current: i, power: v * i };
```

A script is plain top-level code — there is no `main()` convention. (Older versions auto-called a `main()` function; that is gone, so a script that only *defines* `main()` now does nothing. Move its body to the top level.)

---

## Script Lifecycle

1. **Start:** The script gets its own sandboxed V8 engine. Its code is wrapped in an async function and runs from top to bottom
2. **Running:** All APIs are available. Device calls are synchronous — no `await` needed
3. **Ends** in one of three ways: the last line runs (or a top-level `return`), an uncaught error is thrown, or you press **Stop**
4. **Stop:** `delay()` and pending device calls are cancelled **and** the V8 engine is interrupted — the JavaScript executing at that moment is terminated. Code after the loop and `finally` blocks do not run; design scripts to be safe to stop at any instruction
5. **Cleanup:** Event listeners registered with `on()` are automatically removed
6. **Finished:** `scripts:stopped` event is emitted on the EventBus

> **Warning:** Always include `delay()` in long-running loops. Loops without `delay()` will consume excessive CPU because each iteration runs as fast as the V8 engine allows. Use `delay(50)` or higher to yield the thread and keep CPU usage reasonable. Scripts without `delay()` can still be stopped via the Stop button, but they will burn CPU until stopped.

---

## Error Handling

Uncaught errors in scripts are caught and logged. They do not crash the server.

```javascript
try {
  psu.voltage = 100;  // might throw if out of range
} catch (err) {
  log.error(`Failed: ${err.message}`);
}
```

---

## Examples

### Read and Log in a Loop

```javascript
const psu = connector("psu");

while (true) {
  const v = psu.measured_voltage;
  const i = psu.measured_current;
  log.info(`V=${v}V, I=${i}A, P=${(v * i).toFixed(3)}W`);
  emit("reading", { voltage: v, current: i });
  delay(500);
}
```

### Ramp Voltage with Safety Check

```javascript
const psu = connector("psu");
const maxVoltage = 24;
const target = 12;

psu.output = true;

for (let v = 0; v <= target; v += 0.5) {
  if (v > maxVoltage) {
    log.error("Exceeded max voltage!");
    break;
  }
  psu.voltage = v;
  delay(100);
}

log.info(`Ramped to ${psu.voltage}V`);
```

### Cross-Script Communication

```javascript
// Script A: producer
while (true) {
  const temp = sensor.temperature;
  emit("temperature", { value: temp });
  delay(1000);
}

// Script B: consumer
on("temperature", (data) => {
  if (data.value > 80) {
    log.warn("Temperature too high!");
  }
});
```

### Standard Script Pattern

```javascript
const psu = connector("psu");

// Setup — pick a safe starting state that's also safe to be stopped in
psu.voltage = 5;
psu.output = true;

// Main loop — runs until Stop, which terminates mid-iteration, so nothing
// after this block runs. Keep the device in a safe state at every
// iteration rather than relying on trailing cleanup.
while (true) {
  const v = psu.measured_voltage;
  log.info(`V=${v}`);
  emit("reading", { voltage: v });
  delay(500);
}
```

For devices that must return to a specific state on exit (e.g. `output = false`), put that logic behind a natural-exit `break` inside the loop, or handle it in the connector config's idle/default behavior — not below the loop.
