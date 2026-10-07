---
title: Script API Reference
description: Quick reference for all globals available in Muxit scripts.
---

# Script API Reference

All functions and objects available in the Muxit script sandbox. All calls are synchronous — no `await` needed (`await` still works if you prefer).

::: tip Drag-and-drop
Every primitive on this page is also draggable. Open the **Connectors** panel — the **Script API** section at the top lists `delay`, `ai`, `say`, `log.*`, `emit`, `on`, `stream`, `ask.*`, and the others. Drop one into a script editor to insert the call.
:::

## Device Access

| API | Description |
|-----|-------------|
| `connector(name)` | Get a device proxy by name |
| `device(name)` | Alias for `connector()` |

```javascript
const psu = connector("psu");
psu.voltage                  // read property (no parens)
psu.voltage = 12             // write property (assignment)
psu.reset()                  // execute action
psu.rampTo(24)               // call custom method
```

## Logging

| API | Description |
|-----|-------------|
| `log.info(msg)` | Info-level log |
| `log.warn(msg)` | Warning-level log |
| `log.error(msg)` | Error-level log |
| `log.debug(msg)` | Debug-level log |
| `console.log(msg)` | Alias for `log.info()` |

## Events

| API | Description |
|-----|-------------|
| `emit(event, data)` | Publish event (namespaced as `script:<event>`) |
| `on(event, handler)` | Subscribe to events (auto-cleaned on stop) |
| `stream(connector, stream, data)` | Emit stream data to dashboards |

## Timing

| API | Description |
|-----|-------------|
| `delay(ms)` | Sleep (abortable on stop). **Always use in loops** to avoid excessive CPU usage |
| `timestamp()` | Current ISO 8601 UTC string |

## AI

| API | Description | Tier |
|-----|-------------|------|
| `ai(prompt)` | Single-shot LLM call, returns string response | Free (with local LLM) / Maker (with Muxit-managed) |
| `ai(prompt, image)` | LLM call with base64 JPEG image — the model sees the picture and answers in text | Maker ([AI image analysis](https://docs.muxit.io/reference/subscription-plans.md#ai-image-analysis)) |
| `ai(prompt, images[])` | LLM call with **several images** for comparison — array of base64 strings or `{ image, label }` objects | Maker ([AI image analysis](https://docs.muxit.io/reference/subscription-plans.md#ai-image-analysis)) |
| `say(text, opts?)` | Send message to Chat Panel; spoken aloud when the speaker toggle in the top status strip is on. `opts.emotion` hints at delivery style. | Free |

`ai()` routes through the active LLM provider configured in **Settings → AI Services**. **Text-only** calls work on every tier including **Free** when pointed at a **local LLM** (Ollama, LM Studio, any OpenAI-compatible endpoint) — bring-your-own model, no Muxit credits consumed; against the **Muxit-managed cloud proxy** they require a **Maker** subscription (Free-tier users get a clean `AI_REQUIRES_PRO` error — legacy error name, the actual gating tier is Maker). **Attaching an image** is a separate capability — [AI image analysis](https://docs.muxit.io/reference/subscription-plans.md#ai-image-analysis) — that requires **Maker** on *every* provider (including local LLMs): a Free-tier `ai(prompt, image)` call is blocked with an `IMAGE_ANALYSIS_REQUIRES_PRO` reason. This is the same gate the Chat Panel and MCP `take_snapshot` use. Basic image analysis is a Maker capability; the **Vision engine**'s AI actions (`identifyObjects`, `locateObject`, spatial calibration) are where **Pro** pulls ahead — a separately-licensed premium extension reached via `call_action`/`read_property` on a Vision connector. `say()` uses browser text-to-speech and is available on all tiers.

**`say()` details:**

`say(text, opts?)` queues `text` for the dashboard's text-to-speech engine and shows it as a script bubble in the chat panel. Calls from any script land in a single FIFO queue on the dashboard so they can never overlap or replay as a burst — utterances finish in the order they were emitted.

`opts.emotion` is a hint string (`"excited"`, `"sad"`, `"whisper"`, `"serious"`, …). The browser TTS engine approximates emotions with rate/pitch tweaks; server-side TTS providers (added in a later release) honour them natively.

```js
say("Reading complete.")
say("Calibration done!", { emotion: "excited" })
say("Limit switch triggered.", { emotion: "serious" })
```

> **On Free?** You have two ways to use `ai()` without paying for Muxit-managed credits: (1) point Muxit's chat / `ai()` at a **local LLM** (Ollama, LM Studio, any OpenAI-compatible endpoint) in **Settings → AI Services** — it runs on every tier; or (2) use Muxit's **MCP server** with your own AI client (Claude Desktop, Claude Code, ChatGPT) — that exposes the same connectors and scripts but drives them from outside the Muxit window. See the [AI guide](https://docs.muxit.io/guides/ai.md#ai-features-by-tier).

**`ai()` details:**
- Returns a text string (non-streaming, ~1024 max tokens)
- Uses the **Scripts & tools** model configured in **Settings → AI Services** — set it to point scripts and image recognition at a different (e.g. local, image-optimized) model than the chat assistant. Leave it blank to fall back to the chat model
- No tool calling — for quick inference only (classify, extract, describe)
- No conversation history — each call is independent
- `image` parameter: base64-encoded JPEG (e.g., from `connector('webcam').snapshot`)
- **Multiple images:** pass an **array** as the second argument to attach several frames in one call — useful for *"what changed?"* (before/after) or *"is this like A or B?"* (reference matching). Items are either bare base64 strings or `{ image, label?, detail? }` objects; a `label` is sent as a short text block right before its image so the model can refer to it by name. Up to **8 images** per call (extras are dropped with a script-log warning).

**Where do the images come from?** Any source that yields base64 JPEG:
- **Live camera** — `connector('webcam').snapshot` (or the Onvif driver).
- **Reference image from disk** — the [FileAccess driver](https://docs.muxit.io/reference/drivers/file-access.md): `connector('fileaccess').openBinary('refs/good.jpg').read()` returns plain base64, ready to pass straight to `ai()`. Prefer JPEG reference files; PNG/WebP also work (the MIME type is detected automatically).

```js
// Text inference
const result = ai("Is 85°C too hot for this motor?");

// Vision analysis (single image)
const snap = connector('webcam').snapshot;
const analysis = ai("Is the part in the correct position?", snap);

// Has anything changed vs the previous snapshot?
const before = connector('webcam').snapshot;
delay(2000);
const after = connector('webcam').snapshot;
const diff = ai("Did anything move or change between these two photos?", [before, after]);

// Is the workpiece like reference A or B? (labelled comparison)
const fa = connector('fileaccess');
const verdict = ai("Does the current part match A (good) or B (rejected)?", [
  { image: fa.openBinary('refs/good.jpg').read(),     label: "A: good" },
  { image: fa.openBinary('refs/rejected.jpg').read(), label: "B: rejected" },
  { image: connector('webcam').snapshot,              label: "Current" },
]);
```

## User Interaction

Block the script until a dashboard user answers, or the timeout fires.

| API | Description |
|-----|-------------|
| `ask.confirm(message, opts?)` | Yes/No prompt — returns `true` / `false` |
| `ask.choose(message, choices, opts?)` | Pick one of the strings in `choices` |
| `ask.text(message, opts?)` | Free-form text — returns the user's string |

**Options (`opts`):**

| Field | Description |
|-------|-------------|
| `timeout` | Milliseconds (≥ 1000) to wait before falling back to `default` / throwing |
| `default` | Value returned if the timeout expires. **Omit** to throw `PROMPT_TIMEOUT` |
| `requireObserver` | When `true`, the timeout clock only ticks while ≥ 1 dashboard is subscribed |

- Return values are indistinguishable from human answers — consult script logs if you need to know whether a default was used.
- An omitted `timeout` waits indefinitely (until the script is stopped).
- `timeout < 1000` is rejected at call time as a likely typo (seconds vs milliseconds).

```js
// Yes/no with a 30 second timeout, defaulting to "no".
if (!ask.confirm('Home all axes before run?', { timeout: 30000, default: false })) {
    log.warn('User declined — skipping homing');
}

// Force operator attendance: clock pauses if all dashboards disconnect.
const port = ask.choose('Select instrument port', ['COM1','COM2','COM3'], {
    requireObserver: true,
    timeout: 120000,
    default: 'COM1',
});

// No default → throws PROMPT_TIMEOUT if nobody answers.
const label = ask.text('Run label?', { timeout: 60000 });
```

## File I/O

The sandbox has no `fs`, `require`, or `import` — for file access, use a **FileAccess connector** (the default workspace ships one named `files`, sandboxed to `workspace/data/`).

Bind the path once with `.openText(path)` (or `.openBinary(path)` for base64 I/O) and call methods on the returned handle — the rest of the script doesn't repeat the path:

| API | Description |
|-----|-------------|
| `connector('files').openText(path, delimiter?)` | Returns a [TextFileHandle](https://docs.muxit.io/reference/drivers/file-access.md#textfilehandle) |
| `connector('files').openBinary(path)` | Returns a [BinaryFileHandle](https://docs.muxit.io/reference/drivers/file-access.md#binaryfilehandle) (base64 I/O) |
| `f.write(content)` | Overwrite. String or array (joined as a CSV row) |
| `f.append(content)` | Append. String or array. `null` / `undefined` is a no-op |
| `f.read()` / `f.readLines()` | Read as UTF-8 text or split into lines |
| `f.exists` / `f.size` / `f.info()` | Metadata |
| `f.rename(newPath)` / `f.delete()` | Mutations (delete is idempotent; rename updates the handle in place) |
| `connector('files').list(path?)` | Returns `{ files, dirs }` for a directory |

```js
const files = connector('files');
const csv = files.openText('temps.csv');
csv.write('time,temp_c\n');
while (true) {
  csv.append([timestamp(), connector('sensor').temperature]);  // array → CSV row, auto-quoted
  delay(1000);
}
```

Open `temps.csv` in a tab — the chart/table refreshes automatically each time the script appends a row. Full action list in the [FileAccess driver reference](https://docs.muxit.io/reference/drivers/file-access.md).

## Script Lifecycle

| API | Description |
|-----|-------------|
| `script.name` | This script's filename (without `.js`) |

Pressing **Stop** interrupts the V8 engine synchronously — statements after the loop, and `finally` blocks, do not run. There is no `script.running` flag — a script that should run until stopped is just `while (true) { …; delay(ms); }`, and scripts are plain top-level code with no `main()` wrapper. Put setup and safe-state writes *before* the loop and design each iteration to be safe to abort.

## Standard Globals

`Math`, `JSON`, `Date`, `parseInt`, `parseFloat`, `isNaN`, `isFinite`, `Number`, `String`, `Boolean`, `Array`, `Object`, `Map`, `Set`, `Promise`

## Not Available

`require`, `import`, `fs`, `process`, `net`, `http`, `child_process`, `eval`, `Function` (constructor), `global`.

For filesystem access, use a [FileAccess connector](#file-i-o) instead of `require('fs')`.

---

For detailed explanations and examples, see the [Script Guide](https://docs.muxit.io/guides/scripts.md).
