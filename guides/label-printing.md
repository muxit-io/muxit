---
title: Label Printing
description: Print labels on a production line with Muxit — set up Brother P-touch, Epson TM-C3500 or any installed printer, design templates, trigger prints from scanners or MES systems, and monitor the printer.
---

# Label Printing

<!-- v-pre: literal {{placeholders}} below must not be interpolated by Vue. -->
:::: v-pre

Muxit prints labels through the printer driver that is already installed on the computer, so the same connector works for a Brother P-touch tape printer, an Epson TM-C3500 colour label printer, a Zebra with its Windows driver, a PDF printer for testing, or a CUPS queue on Linux. Labels are JSON templates with `{{placeholders}}`; scripts, dashboards, MCP clients and the AI fill them in.

This guide walks through a production-line setup. Reference pages: [LabelPrinter driver](https://docs.muxit.io/reference/drivers/label-printer.md) and [Label Templates](https://docs.muxit.io/reference/label-templates.md).

::: tip Pro feature
Printing to a real printer needs the **Label Printing** feature (Pro). Everything else — listing printers, creating connectors, editing templates, live previews, and dry runs on the `null` backend — works on every tier, so you can set the line up completely before upgrading.
:::

## 1. Open Tools → Label Printing

Install the manufacturer's driver and print a test page from the operating system first — Muxit uses that driver as-is. Then open **Tools → Label Printing** in the title bar. The page has two tabs:

- **Printers** lists every printer the operating system knows, with its status (ready, paper-out, offline, …), resolutions, the paper sizes its driver defines, and the connector(s) already attached to it. Click **Create connector…** on a printer: pick a connector name, the template it should print by default, optionally one of the driver's paper sizes (Brother and Epson prefer their own) and the label stock size. Muxit writes `workspace/connectors/<name>.js`, enables it and reloads — the connector appears below as a card with its live status, a template dropdown, a **Test print** button and **Open file** for the generated config.
- **Templates** shows the label templates in `workspace/labels/`. Select one, fill in sample values for its fields and watch the preview update; **Print** sends it to any printer connector. **New template…** creates a starter file and opens it in the editor; **Open in editor** edits the JSON, and the list and preview follow your saves.

Everything the page does is also available to scripts through the connector it created:

```javascript
const printer = connector("brother");          // the name you chose in the dialog
printer.template = "asset-tag";                // change the default template at runtime
printer.print({ name: "Oscilloscope" });       // data only — the template property is used
printer.status;                                // "ready" | "paper-out" | "offline" | …
printer.listPrinters();                        // same list as the Printers tab
```

Prefer the file? The starter `workspace/connectors/_examples/label-printer.js` is the same thing the dialog writes; set `printer:` to a substring of the printer name, `template:` to the default template, and on Windows `paper:` to one of the driver's sizes.

::: tip Test without hardware
Set `backend: "null"` (or `printer: "PDF"` with Microsoft Print to PDF) while designing templates. The null backend records jobs and reports `ready`, so scripts, dashboards and the `jobs` stream behave exactly as with a real printer — nothing is printed.
:::

### Brother P-touch (PT-9700PC and similar)

- The **tape width** is the paper width; the label **length** is the paper height. In *Printing Preferences* the driver lists sizes such as `24mm` (continuous) or fixed lengths, and lets you define your own (Paper Size Setup). Match the template: a 24 mm tape with 90 mm labels is `size: { width: 24, height: 90 }` — or `width: 90, height: 24` with `"orientation": "landscape"` if you design the label along the tape.
- Set `paper:` to the driver's size name (`"24mm"`) rather than relying on a custom size; Brother drivers ignore custom sizes they have not defined.
- The printable width is narrower than the tape (roughly 32 mm on a 36 mm tape). Keep 1–2 mm of side margin.
- Auto-cut, half-cut and "print then cut at end" are driver preferences; Muxit does not control the cutter.
- Resolution is 360 dpi; leave `dpi: 0` so the driver renders at that.

### Epson TM-C3500

- Define your media once in the driver's *Media Settings* (die-cut / continuous / black mark, width, length, gap) and save it as a user-defined size. Refer to it with `paper: "<that name>"`. A mismatch between the defined media and the loaded roll produces a media-form error **on the printer**, not in Windows.
- The printer is 360 dpi (720 × 360 for high quality — pick it through the driver's defaults if you want it). Colour is fully supported: `"color": "#c00000"` on text, coloured `fill` on rectangles, colour images.
- Media presence and cover state show up in `status` / `statusDetail` (`paper-out`, `door open`).

### Zebra, TSC and other ZPL/TSPL printers

With the manufacturer's Windows driver installed they behave like any other printer. Alternatively send the printer's own language with `printRaw()` — the driver then does not render anything, so the printer's own barcode commands do the work. `printRaw()` is still a print call: it needs the Label Printing feature (Pro) like `print()` does, and it is exempt only on the `null` dry-run backend:

```javascript
connector("label-printer").printRaw({ data: "^XA^FO50,50^BCN,80,Y,N,N^FD{{serial}}^FS^XZ".replace("{{serial}}", serial) });
```

A raw network backend (`backend: "tcp"`, `host`, `port: 9100`) exists for `printRaw()`; rendered labels over TCP need a label-language encoder and are not supported yet.

### Linux / macOS (CUPS)

The `cups` backend uses `lp` and `lpstat`. Add the printer with the system's printer settings or `lpadmin`, check `lpstat -p`, and Muxit picks it up. Status detection is heuristic (`media-empty`, `offline`, `disabled` reasons) and job tracking is by queue membership — good enough for alerts, less detailed than Windows.

## 2. Design the label

Templates are `workspace/labels/<name>.label.json` files. Two examples are seeded: `asset-tag` (text only) and `shipping` (Code 128 + QR). On the Templates tab, **New template…** writes a starter and opens it in the **visual designer**; **Design** opens an existing template the same way and **Edit JSON** opens the raw file in the editor. Both are tabs on the same file — the **Design / Edit JSON** buttons in the tab's toolbar switch between them, and edits carry over.

The designer is a page-sized canvas with the label rendered by the server underneath (the same renderer that prints, so what you see is what the printer gets):

- **Add** elements by clicking or dragging them from the palette on the left: text, barcode, QR code, image, rectangle, line. Drop an image file from the Explorer to add it — images must live in `workspace/labels/`.
- **Move / resize** on the canvas (handles on the selected element; line endpoints drag individually). Positions snap to 0.5 mm — hold **Alt** to place freely, toggle **Grid**, **Snap** and **Outlines** in the toolbar. Rotated elements can be moved and edited in the panel but not resized on the canvas.
- **Properties** on the right: coordinates, text and font, symbology, colours, `when` conditions … With nothing selected the panel shows the label itself (size, unit, dpi, background, default font) and the **fields** table (name, required, default).
- **Sample data** below the properties fills the placeholders for the preview; values are remembered per template and shared with the Templates tab.
- **Problems** appear in the strip at the bottom (missing required fields, a barcode box too small, an unknown image …); click one to select the offending element.
- **Keyboard:** arrows nudge 0.1 mm (Shift: 1 mm), **Delete** removes, **Ctrl+D** duplicates, **Ctrl+Z / Ctrl+Y** undo / redo, **Esc** deselects, **Ctrl+S** saves.

Saving writes the same JSON described in [Label Templates](https://docs.muxit.io/reference/label-templates.md) — the designer normalises aliases and drops default values, so the first save of a hand-written file may reorder keys. Files with comments or in sub-folders open as plain JSON. From a script, `preview({ product: "Widget", serial: "SN-000123" })` returns the same PNG, and `validateTemplate("shipping")` lists errors and warnings without rendering.

The optional **Label Printer** dashboard (`workspace/dashboards/label-printer.dashboard.json`) shows the last rendered label and printer status on a dashboard; it is an example, not a requirement.

## 3. Trigger prints from the line

Everything that can call a connector action can print a label:

| Trigger | How |
|---------|-----|
| Barcode scanner on a serial port | A `LineText` connector for the scanner; a script subscribes to its `output` stream and calls `print()` |
| PLC / MES over MQTT | MqttBridge connector; a script subscribes to `stream:mqtt:message` on your topic |
| Another application | WebSocket `connector.call` (see the [WebSocket API](https://docs.muxit.io/reference/websocket-api.md)) or the [JavaScript library](https://docs.muxit.io/guides/js-library.md) |
| Claude / MCP clients | The `call_action` MCP tool — the AI sees the template fields via `listTemplates()` |
| Operator | The Templates tab, a dashboard button bound to `label-printer.print` (prints the current `template`), or a connector method with fixed data |

`workspace/scripts/examples/label-on-scan.js` combines the first two with alerting:

```javascript
const printer = connector("label-printer");
printer.template = "shipping";

on("stream:scanner:output", (line) => {
  printer.print({ product: "Widget", serial: String(line).trim() });
});

on("stream:label-printer:jobs", (evt) => {
  if (evt.event === "failed" || evt.event === "stalled")
    connector("webhook").notify("Label job " + evt.event, `${evt.jobId}: ${evt.error}`, "error");
});

while (true) {
  if (printer.status === "paper-out") connector("webhook").notify("Labels empty", printer.statusDetail, "warn");
  delay(5000);
}
```

Serial numbers: `{{sequence}}` increments once per printed label and survives restarts (stored under `workspace/config/drivers/<connector>/`). Set the starting value with `printer.sequence = 1000`. Prefer values from your MES when you have them — the sequence is for stand-alone lines.

Each `print()` or `printBatch()` claims its range of values when the job is queued, so two
callers printing at the same moment — a script and a dashboard button, say — always get
different serials. A job that is then rejected (queue full, `minIntervalMs`) or fails to
spool keeps the range it claimed, so the printed serials can have gaps. That is deliberate:
a gap is a question the job log answers, whereas two labels carrying the same serial is the
thing a serial number exists to prevent.

Batches: `printBatch({ template, items: [...] })` spools one multi-page job, which is much faster on the TM-C3500 than many single jobs and keeps the order intact.

## 4. Monitor and protect the line

**Status.** `status` is one of `ready`, `printing`, `paper-out`, `offline`, `paused`, `error`, `unknown`, refreshed every few seconds from the spooler; `statusDetail` carries the driver's words (`paper out, door open`). Bind an indicator widget or poll it from a script.

**Job outcomes.** The `jobs` stream reports `queued` → `printing` → `printed` for each job, `failed` when the spooler refused it, `stalled` when the spooler is waiting on the printer (paper out, offline — once per job, followed by `printing` when it resumes) and `cancelled`. `jobsPrinted` / `jobsFailed` / `lastJob` / `lastError` summarise the same information for dashboards.

**Runaway protection.** A script bug that loops over `print()` can empty a roll in minutes. The driver enforces its own caps on every tier:

| Config | Default | Effect |
|--------|---------|--------|
| `maxCopies` | 50 | Copies per call |
| `maxBatch` | 500 | Items per `printBatch()` |
| `maxQueue` | 20 | Jobs allowed to wait — further calls fail instead of piling up |
| `minIntervalMs` | 0 | Minimum time between calls |

Set them to what one shift can plausibly need (the example connector uses 20 / 200 / 20). On the Lab tier the per-connector `safety:` block adds rate limits and confirmations (`confirm: { printBatch: "always" }`); at the global **Observe** safety level all printing is simulated. `cancelAll()` clears both the driver queue and the spooler.

**AI.** The starter connector's `ai.instructions` tell the assistant that printing consumes media and to prefer `preview()`. Keep that in place if operators talk to the line through chat.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| `status` is `offline` right after enabling | `statusDetail` lists the installed printers — fix `printer:` to match one of them |
| Label prints tiny in a corner / wrong orientation (Brother) | Use `paper: "<driver size>"` and set the tape width in Printing Preferences; try `"orientation": "landscape"` |
| Media-form error on the TM-C3500 | The driver's defined media does not match the loaded roll |
| Barcode does not scan | Enlarge the box (the error message says the minimum), keep the default quiet zone, render at the printer's dpi (`dpi: 0`), avoid `shrink`-style scaling |
| `LICENSE_LIMIT` on print | Printing to a real printer is a Pro feature (Label Printing); previews and `backend: "null"` dry runs stay available |
| The Printers tab shows "enumeration is taking longer than 20 s" | An offline network printer is stalling the Windows spooler; the last known list is shown as stale — remove or bring back the queue, then Refresh |
| `print()` times out with "not accepted by the spooler" | The spooler is blocked (offline printer, paused queue); the job stays queued — look at `statusDetail`, then `cancelAll()` |
| Nothing prints on Linux | `lpstat -p` must list the printer; install `cups-client` if `lp` is missing |

::::
