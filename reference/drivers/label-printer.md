---
title: LabelPrinter Driver
description: Reference for the LabelPrinter built-in driver — renders JSON label templates with text, barcodes, and images, and prints them through any installed printer.
---

# LabelPrinter

<!-- v-pre: literal {{placeholders}} below must not be interpolated by Vue. -->
:::: v-pre

Built-in **label printing** driver. A connector renders a [label template](https://docs.muxit.io/reference/label-templates.md) with the data you pass in and hands the pages to the operating system's print spooler, so every printer with an installed driver works: Brother P-touch (PT-9700PC and friends), Epson TM-C3500, Zebra / TSC with their Windows drivers, "Microsoft Print to PDF", any CUPS queue on Linux or macOS. Raw printer-language data (ZPL, TSPL, ESC/P) can be sent straight to the port as well.

The **Tools → Label Printing** page in the UI manages printers, connectors and templates without writing any code; the connector surface below is what scripts, dashboards, the AI and that page all use. For the production-line setup — printer preferences, triggers, monitoring, runaway protection — see the [Label Printing guide](https://docs.muxit.io/guides/label-printing.md).

::: tip Printing is a Pro feature
Spooling a label to a real printer — `print()`, `printBatch()`, `printImage()`, `printRaw()` and the Print buttons in the UI — needs the **Label Printing** feature (Pro); otherwise the call fails with `LICENSE_LIMIT`. Listing printers, editing templates and `preview()` (barcodes included) work on every tier, and connectors on the `null` dry-run backend are never gated, so the whole pipeline can be evaluated before upgrading.
:::

::: warning Safety gate
`RequiresSafetyGates` is on (printing consumes media). At the **Observe** safety level every action, including `preview()` and `listPrinters()`, is simulated and returns `null`. The driver's own caps (`maxCopies`, `maxBatch`, `maxQueue`, `minIntervalMs`) apply on every tier; a per-connector `safety:` block is additionally enforced on Lab.
:::

## Properties

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `printers` | string[] | R | Installed printer names as seen by the backend |
| `printer` | string | R/W | Resolved printer; write a name or substring to switch |
| `backend` | string | R | `windows` \| `cups` \| `null` \| `tcp` |
| `status` | string | R | `ready` \| `printing` \| `paper-out` \| `offline` \| `paused` \| `error` \| `unknown` |
| `statusDetail` | string | R | Human-readable detail from the spooler (e.g. `paper out, door open`) |
| `queueLength` | int | R | Jobs waiting in the driver queue plus jobs still in the spooler |
| `jobsPrinted` | int | R | Jobs that left the spooler queue normally since start |
| `jobsFailed` | int | R | Jobs the spooler refused or that were cancelled |
| `lastJob` | object | R | `{ jobId, kind, template, copies, pages, printer, state, nativeId, error, queuedAt, spooledAt }` |
| `lastError` | string | R | Most recent failure message (empty if none) |
| `templates` | string[] | R | Template names found in the templates directory |
| `template` | string | R/W | Current template — used by `print()` / `printBatch()` / `preview()` when only data is given; validated against the templates directory |
| `lastPreview` | string | R | Base64 PNG of the most recently rendered label — see note below |
| `sequence` | int | R/W | Next value of `{{sequence}}`; increments per printed label, persists across restarts |
| `dpi` | int | R/W | Render resolution (0 = printer resolution, else template dpi) |
| `printingLicensed` | bool | R | Whether this connector may spool real jobs (Label Printing feature, or the `null` backend) |

`listPrinters()`, `printers` and setting `printer` ask the OS at most once at a time, cached for 30 s, and wait at most 20 s for it; a slower enumeration (offline network printers on CUPS) returns the last known list and finishes in the background. `status` is polled from the spooler every `statusIntervalMs`. Put it (and `statusDetail`, `queueLength`, `jobsPrinted`, `jobsFailed`, `lastError`) in the connector's `poll:` list so dashboards and scripts see changes.

`lastPreview` is a large string and, like every driver property, is cached by the connector until polled. Prefer the `preview` **stream** (a `data:image/png;base64,…` URL pushed on every render) for a dashboard canvas widget in `mode: "image"`.

## Actions

| Action | Args | Returns | Description |
|--------|------|---------|-------------|
| `print` | `{ template?, data?, copies?, printer?, media? }` or a bare template name | `{ jobId, nativeId, pages, copies, printer, template, spooled }` | Render a template with data and spool it |
| `printBatch` | `{ template?, items: [data…], copies? }` | job object | One label per item as a single multi-page spooler job |
| `preview` | `{ template?, data?, dpi? }` | base64 PNG | Render without printing (default `previewDpi`, 150) |
| `printImage` | `{ image, media?, copies?, printer? }` | job object | Print a base64 PNG/JPEG fitted onto the label stock |
| `printRaw` | `{ data, encoding?, printer? }` | job object | Send ZPL / TSPL / EPL / ESC-P bytes straight to the printer |
| `listPrinters` | — | `[{ name, isDefault, status, papers[], resolutions[], port, driver }]` | Installed printers with capabilities |
| `listTemplates` | — | `[{ name, width, height, unit, dpi, orientation, elements, barcodes, fields, error? }]` | Templates on disk (broken files carry `error`) |
| `validateTemplate` | `{ template }` | `{ valid, errors[], warnings[], name, barcodes, printingLicensed }` | Check a template name or inline layout |
| `reloadTemplates` | — | int | Re-read the templates directory (also automatic on file changes) |
| `refreshStatus` | — | `{ status, statusDetail, queueLength }` | Poll the spooler now |
| `cancelAll` | — | int | Cancel queued jobs in the driver queue and the spooler |

### Calling `print()`

The idiomatic script flow is one connector per printer, a template set once, and data-first calls:

```javascript
const printer = connector("label-printer");
printer.template = "shipping";                              // or template: "shipping" in the connector config
printer.print({ product: "Widget", serial: "SN-000123" });  // the object IS the data
```

Every shape the driver accepts (the same rules apply to `printBatch()` with `items` and to `preview()`):

| Call | Meaning |
|------|---------|
| `print({ serial: 3, qty: 4 })` | **Data form** — no `template` / `data` / `items` key, so the whole object is the data; the `template` property is used; 1 copy |
| `print()` | Data form with empty data |
| `print("shipping")` | Template name, no data |
| `print("shipping", { serial: 3, copies: 2 })` | Template name, then fields; keys that are options (`copies`, `printer`, `media`) are taken as options, the rest is data |
| `print({ template: "shipping", data: {…}, copies: 2, printer, media })` | **Options form** — the object has `template`, `data` or `items`; `template` may be a name or an inline layout `{ size, elements }` |
| `printBatch({ items: [{…}, {…}] })`, `printBatch("shipping", items)` | One label per item; a bare array argument only works over WebSocket/MCP (scripts must use `{ items }`) |

In the data form a field that happens to be called `copies` is data, not an option. A dashboard button bound to `label-printer.print` with no argument prints the current `template`.

`data` values are stringified for `{{placeholders}}`; nested objects are reachable as `{{order.id}}`. Missing **required** fields (declared under the template's `fields`) fail with `VALIDATION_INVALID_VALUE` before anything is spooled.

`copies` is capped by `maxCopies`, `items` by `maxBatch`; a call that would exceed `maxQueue` waiting jobs, or arrives within `minIntervalMs` of the previous one, is rejected with `CONN_CALL_FAILED`.

`printRaw` `encoding` is `text` (default, Latin-1 so control bytes 0x80–0xFF survive), `utf8`, `base64` or `hex`.

Every action returns as soon as the job is **accepted by the spooler**, not when the label is physically out — follow the `jobs` stream for that.

## Streams

| Stream | Description |
|--------|-------------|
| `jobs` | Job life cycle: `{ event, jobId, kind, template, copies, pages, printer, nativeId, error, timestamp }` |
| `preview` | `data:image/png;base64,…` of the first page after every render (`previewDpi`) |

`event` is `queued` → `printing` → `printed` (left the spooler queue normally). Other outcomes: `failed` (the backend refused the job — `error` says why), `stalled` (the spooler reports paper-out / offline / error for this job; emitted once, followed by `printing` when it resumes), `cancelled` (`cancelAll()` or removed from the spooler).

```javascript
on("stream:label-printer:jobs", (evt) => {
  if (evt.event === "failed" || evt.event === "stalled")
    connector("webhook").notify("Label job " + evt.event, evt.jobId + ": " + evt.error, "error");
});
```

## Config Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `printer` | string | `""` | Printer name or case-insensitive substring; empty = OS default printer |
| `backend` | string | `"auto"` | `auto` (Windows spooler / CUPS) \| `windows` \| `cups` \| `null` (dry run) \| `tcp` (raw 9100) |
| `dryRun` | bool | `false` | Force the `null` backend — jobs are recorded, nothing is printed |
| `media` | object | — | Physical stock `{ width, height, unit }`; overrides the paper size handed to the spooler and sizes `printImage()` pages |
| `paper` | string | `""` | Windows paper name to select instead of a custom size (exact, then substring match) |
| `orientation` | string | `"auto"` | `auto` (template decides) \| `portrait` \| `landscape` — landscape rotates the page 90° |
| `dpi` | int | `0` | Render dpi; 0 = the printer's resolution, else the template's `dpi` |
| `templatesDir` | string | `"labels"` | Template directory inside the workspace (relative to it); a folder outside the workspace is refused |
| `template` | string | `""` | Initial value of the `template` property (alias: `defaultTemplate`) |
| `maxCopies` | int | 50 | Per-call copy cap |
| `maxBatch` | int | 500 | Items per `printBatch()` |
| `maxQueue` | int | 20 | Jobs allowed to wait for the spooler |
| `minIntervalMs` | int | 0 | Minimum gap between print calls (0 = off) |
| `spoolTimeoutMs` | int | 30000 | How long `print()` waits for the spooler to accept the job |
| `trackedJobMaxAgeMs` | int | 600000 | A spooled job still reported as printing after this long is assumed printed and released (min 30000) |
| `previewDpi` | int | 150 | Resolution of `preview()` and the `preview` stream |
| `statusIntervalMs` | int | 3000 (CUPS 5000) | Spooler status polling interval |
| `host` / `port` / `timeoutMs` | string / int / int | — / 9100 / 5000 | For `backend: "tcp"` |
| `nullStatus` | string | — | Simulated state for `backend: "null"` (`ready`, `paper-out`, `offline`, …) — used by tests |

### Backends

| Backend | Platform | Raster labels | `printRaw` | Status / job tracking |
|---------|----------|---------------|------------|-----------------------|
| `windows` | Windows | GDI through the installed driver (custom paper size or a named `paper`) | winspool RAW datatype | `PRINTER_STATUS` flags (paper out, door open, offline, paused), spooler job list |
| `cups` | Linux / macOS | PDF with a physical page size via `lp -o media=Custom.WxHmm` | `lp -o raw` | `lpstat` reasons (`media-empty`, `offline`, `disabled`), queue length — best effort |
| `null` | any | recorded, not printed | recorded | simulated |
| `tcp` | any | not supported yet (needs a ZPL/TSPL encoder) | TCP to port 9100 | port reachability only |

## Example Connector

```javascript
// workspace/connectors/label-printer.js
export default {
  driver: "LabelPrinter",
  config: {
    printer: "Brother",                 // substring of "Brother PT-9700PC"
    media: { width: 24, height: 90, unit: "mm" },
    paper: "24mm",                      // a size defined in the Brother driver
    template: "asset-tag",
    maxCopies: 20,
    maxBatch: 200,
  },
  poll: ["status", "statusDetail", "queueLength", "jobsPrinted", "jobsFailed", "lastError", "sequence"],
  ai: {
    instructions: "Label printer. print() consumes media — only print on request; prefer preview().",
  },
  safety: {
    rate: { print: 2, printBatch: 0.2 },
    confirm: { printBatch: "always", printRaw: "always" },
  },
};
```

A ready-to-copy version lives in `workspace/connectors/_examples/label-printer.js`, with matching templates in `workspace/labels/` and a dashboard in `workspace/dashboards/label-printer.dashboard.json`.

## Example Script

```javascript
const printer = connector("label-printer");

// Which printers are installed, and what paper sizes do they offer?
for (const p of printer.listPrinters())
  log.info(`${p.name}${p.isDefault ? " (default)" : ""}: ${p.status}, papers: ${p.papers.join(", ")}`);

// Pick the template once, then print with data only
printer.template = "shipping";
const png = printer.preview({ product: "Widget", serial: "SN-000123" });   // check the layout first
log.info(`preview ${png.length} chars of base64 PNG`);

const job = printer.print({ product: "Widget", serial: "SN-000123", qty: 4 });
log.info(`spooled ${job.jobId} on ${job.printer}`);

// Or name the template per call
printer.print("asset-tag", { name: "Oscilloscope" });

printer.printBatch({
  template: "asset-tag",
  items: [{ name: "Oscilloscope" }, { name: "Power supply" }, { name: "Signal generator" }],
});

// Zebra / TSC printers understand their own language — no template needed
printer.printRaw({ data: "^XA^FO50,50^BCN,80,Y,N,N^FDSN-000123^FS^XZ" });

// Watch the printer
if (printer.status !== "ready") log.warn(`printer ${printer.status}: ${printer.statusDetail}`);
```

::::
