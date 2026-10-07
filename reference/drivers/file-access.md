---
title: FileAccess Driver
description: Reference for the FileAccess built-in driver — sandboxed file I/O for scripts and AI.
---

# FileAccess

**Sandboxed file I/O** restricted to a single directory (typically `workspace/data/`). Allows scripts and AI to read and write files without exposing the full filesystem.

The driver exposes a small action surface — `openText`, `openBinary`, `list`, `mkdir` — that returns path-bound **handles** for the actual read/write/append/delete work. Binding the path once and calling methods on the handle keeps script bodies short and reduces the AI system prompt.

::: tip Safety gate
This driver ships with `requiresSafetyGates: false` — FileAccess operations bypass the [safety gate](https://docs.muxit.io/guides/safety.md) entirely and no audit rows are written. Workspace-state write-locking (Sandbox mode / EULA) still applies. See [Per-driver opt-out](https://docs.muxit.io/guides/safety.md#per-driver-opt-out).
:::

## Properties

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `basePath` | string | R | Resolved absolute base path |
| `exists` | bool | R | Whether the base directory exists |

## Actions

| Action | Args | Description |
|--------|------|-------------|
| `openText` | `path, delimiter?` | Returns a [TextFileHandle](#textfilehandle) for read/write/append (string or array) |
| `openBinary` | `path` | Returns a [BinaryFileHandle](#binaryfilehandle) for base64 I/O |
| `list` | `path?` | Returns `{ files, dirs }` for a directory (default: root) |
| `mkdir` | `path` | Create a directory (recursive, idempotent) |

`delimiter` for `openText` defaults to `","`. Pass `"\t"` for TSV or any other delimiter you need. The `openText(path, { delimiter: ";" })` object form is also accepted — the trailing-dict positional merge folds it into the args.

## Config Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `basePath` | string | — | **Required.** Root directory for all file operations, inside the workspace: a relative path (`"data"`) resolves against the workspace; an absolute path outside it is refused |
| `maxFileSizeMB` | int | 10 | Maximum file size in MB for read/write |
| `createIfMissing` | bool | true | Create base directory if it doesn't exist |

## TextFileHandle

Returned by `openText(path, delimiter?)`. Binds a single path so subsequent calls don't repeat it:

```javascript
const fa = connector("fileaccess");
const log = fa.openText("runs/temps.csv");

log.write("t,T\n");                 // overwrite (creates parent dirs)
for (let t = 0; t < 10; t++) {
  log.append([t, dut.temperature]); // → 0,21.4\n  (array → CSV row)
  await delay(1000);
}

log.size;                           // bytes (0 if missing)
log.exists;                         // bool
log.info();                         // { name, size, created, modified, extension }
log.read();                         // full text
log.readLines();                    // string[]
log.rename("runs/done.csv");        // updates the handle in place
log.delete();                       // idempotent — returns false if missing
```

| Member | Kind | Description |
|--------|------|-------------|
| `path` | property | The sandbox-relative path (forward-slashed) |
| `exists` | property | `true` if the file exists |
| `size` | property | File size in bytes (0 if missing) |
| `read()` | method | Read as UTF-8 text |
| `readLines()` | method | Read as UTF-8 and split into lines |
| `write(content)` | method | Overwrite. String or array (joined as a CSV row + `\n`) |
| `append(content)` | method | Append. String or array. `null` / `undefined` is a no-op |
| `delete()` | method | Remove the file. Idempotent — returns `false` if missing |
| `rename(newPath)` | method | Rename / move within the sandbox; updates the handle |
| `info()` | method | `{ name, size, created, modified, extension }` |

### Array → CSV row

Passing a JS array to `write` or `append` joins the cells with the handle's delimiter and appends `\n`. Cells containing the delimiter, a double-quote, CR, or LF are wrapped in `"…"` and internal `"` are doubled (RFC 4180). Numbers format with invariant culture, so a host running under `nl-NL` doesn't turn `2.5` into `"2,5"` and collide with the comma delimiter.

```javascript
const f = fa.openText("data.csv");
f.append([1, 2.5, "plain"]);          // → 1,2.5,plain
f.append([3, 4, "has, comma"]);       // → 3,4,"has, comma"
f.append([5, 6, 'has "quote"']);      // → 5,6,"has ""quote"""
```

For TSV:

```javascript
const t = fa.openText("data.tsv", "\t");
t.append([1, 2, "tab\tseparated"]);   // tab cells are quoted because they contain the delimiter
```

## BinaryFileHandle

Returned by `openBinary(path)`. Read/write are base64-string based, matching what `cam.snapshot()` and similar drivers produce.

```javascript
const img = fa.openBinary("snapshots/frame.jpg");
img.write(cam.snapshot());            // accepts a base64 string
const b64 = img.read();
img.size;                             // bytes on disk (not base64 length)
img.delete();
```

| Member | Kind | Description |
|--------|------|-------------|
| `path`, `exists`, `size` | properties | Same shape as TextFileHandle |
| `read()` | method | Returns base64-encoded bytes |
| `write(base64)` | method | Overwrite. Accepts a base64 string |
| `delete()` | method | Idempotent — returns `false` if missing |
| `rename(newPath)` | method | Rename / move within the sandbox |
| `info()` | method | `{ name, size, created, modified, extension }` |

Handles obey the same sandbox boundary, size limits (`maxFileSizeMB`), and `workspace.file.changed` notifications as the action layer. Methods are synchronous — no `await` needed.

## Security

The base folder always lies inside the workspace: a `basePath` outside it fails to load with `PATH_OUTSIDE_WORKSPACE`. Every path an action or handle uses is then confined to that base folder — `..`, absolute paths and symbolic links that lead out are refused — so a File Access connector can never read or write files elsewhere on the computer. See [Workspaces → Files outside the workspace](https://docs.muxit.io/guides/workspaces.md#files-outside-the-workspace).

## Example: CSV measurement log

```javascript
const fa  = connector("fileaccess");
const psu = connector("psu");

const f = fa.openText(`runs/${timestamp().replace(/[:.]/g, "-")}.csv`);
f.write("I_set_mA,V_measured\n");

for (let i = 0; i <= 350; i += 10) {
  psu.current_set = i / 1000;
  await delay(100);
  f.append([i, psu.measured_voltage]);
}
log.info(`Saved ${f.path} (${f.size} bytes)`);
```

::: tip CSV output is chart-viewable
Files written with a `.csv` or `.tsv` extension open as an interactive line chart when clicked in the File Explorer. See the [CSV Charts](https://docs.muxit.io/getting-started/ui-tour.md#csv-charts) section of the UI tour.
:::

::: tip Open tabs refresh automatically
Any FileAccess write you do touches a `workspace.file.changed` notification. Tabs viewing that file reload on their own — a `.csv` chart grows row-by-row while a script appends to it, no close-and-reopen needed. Tabs with unsaved edits are skipped so in-progress work isn't clobbered.
:::

## Example: list a directory

```javascript
const fa = connector("fileaccess");
const { files, dirs } = fa.list("runs");
log.info(`${files.length} files, ${dirs.length} subdirs`);
```
