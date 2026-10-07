---
title: Label Templates
description: Schema reference for workspace/labels/*.label.json — page size, elements (text, barcode, image, rect, line), placeholders and formatters used by the LabelPrinter driver.
---

# Label Templates

<!-- v-pre: this page is full of literal {{placeholders}} that Vue would otherwise try to interpolate. -->
:::: v-pre

A label template is a JSON file in `workspace/labels/` named `<name>.label.json`. The [LabelPrinter](https://docs.muxit.io/reference/drivers/label-printer.md) driver renders it with the `data` you pass to `print()` and sends the result to the printer. Scripts can also pass the same object inline (`print({ template: { size, elements }, data })`) for fully dynamic layouts. Templates reload automatically when the file changes. You do not have to write this by hand: **Tools → Label Printing → Templates → Design** opens a template in the visual designer, which reads and writes exactly this schema (see the [guide](https://docs.muxit.io/guides/label-printing.md#_2-design-the-label)).

```json
{
  "name": "shipping",
  "size": { "width": 62, "height": 100, "unit": "mm" },
  "dpi": 300,
  "font": "Arial",
  "fields": {
    "product": { "required": true },
    "serial":  { "required": true },
    "qty":     { "default": "1" }
  },
  "elements": [
    { "type": "text",    "x": 4, "y": 4,  "w": 54, "h": 12, "text": "{{product}}", "size": 16, "bold": true, "shrink": true },
    { "type": "text",    "x": 4, "y": 17, "w": 54, "h": 8,  "text": "Qty {{qty}} · {{date|yyyy-MM-dd}} · #{{sequence|pad:6}}", "size": 8 },
    { "type": "barcode", "x": 4, "y": 33, "w": 54, "h": 20, "symbology": "code128", "value": "{{serial}}", "showText": true },
    { "type": "barcode", "x": 4, "y": 57, "w": 30, "h": 30, "symbology": "qr", "value": "https://example.com/t/{{serial}}" },
    { "type": "image",   "x": 36, "y": 57, "w": 22, "h": 22, "src": "logo.png", "fit": "contain" },
    { "type": "rect",    "x": 1, "y": 1,  "w": 60, "h": 98, "strokeWidth": 0.3, "radius": 2 },
    { "type": "line",    "x1": 4, "y1": 30, "x2": 58, "y2": 30 }
  ]
}
```

## Page

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `name` | string | file stem | Shown in `listTemplates()` and the `{{template}}` placeholder |
| `size.width`, `size.height` | number | required | Label size in `size.unit` |
| `size.unit` | string | `"mm"` | `mm` \| `cm` \| `in` \| `pt` \| `px` — also the unit for every element coordinate |
| `dpi` | int | 300 | Design resolution: used for `px` units and as the render resolution when the printer's is unknown (previews, PDF) |
| `orientation` | string | `"portrait"` | `landscape` rotates the finished page 90° for stock that feeds the other way (tape printers) |
| `background` | string | `"#FFFFFF"` | Page colour (`#RGB`, `#RRGGBB`, `#RRGGBBAA` or a CSS name) |
| `font` | string | `"Arial"` | Default font family for text and barcode captions |
| `fontSize` | number | 10 | Default text size in points |
| `fields` | object | — | Declared data fields (see below) |
| `elements` | array | — | Drawn in order; later elements paint over earlier ones |

Coordinates are measured from the top-left corner; `x`, `y`, `w`, `h` are in `size.unit`. Every element also accepts:

| Key | Description |
|-----|-------------|
| `id` | Name used in error messages (defaults to `#index`) |
| `rotate` | Clockwise rotation in degrees around the element's centre |
| `when` | Placeholder expression; the element is skipped when it expands to empty, `false`, `0`, `no` or `null` |

## Fields

`fields` declares what `data` the template expects. Undeclared placeholders still resolve from `data`; declaring them gives validation and defaults.

```json
"fields": {
  "serial":      { "required": true },
  "destination": { "default": "" },
  "lot":         "L0"
}
```

A required field that is missing from `data` fails `print()` with `VALIDATION_INVALID_VALUE` listing every missing name. A field with a `default` uses it when absent. `validateTemplate()` warns about placeholders that are not declared and fields that are never used.

## Elements

### `text`

| Key | Default | Description |
|-----|---------|-------------|
| `text` | — | The text; supports placeholders and `\n` |
| `font`, `size` | template defaults | Family and size in points |
| `bold`, `italic` | false | Weight / slant |
| `color` | `#000000` | Text colour |
| `align` | `left` | `left` \| `center` \| `right` |
| `valign` | `top` | `top` \| `middle` \| `bottom` |
| `wrap` | true | Word-wrap inside the box (long words break by character) |
| `shrink` | false | Reduce the size (down to 4 pt) until the text fits the box |
| `lineHeight` | 1.2 | Line spacing as a multiple of the font size |

Text is clipped to its box. Fonts come from the server's operating system; a family that is not installed falls back to the default sans-serif.

### `barcode`

| Key | Default | Description |
|-----|---------|-------------|
| `symbology` | `code128` | See the table below (`type: "qr"` is shorthand for `symbology: "qr"`) |
| `value` | — | Encoded content; supports placeholders |
| `showText` | false | Print the human-readable value under 1D codes |
| `textSize`, `font` | 7 pt, template font | Caption styling |
| `color` | `#000000` | Bar colour |
| `errorCorrection` | per symbology | QR `L` \| `M` \| `Q` \| `H`; PDF417 `0`–`8`; Aztec percentage |
| `margin` | standard quiet zone | Quiet zone in modules per side reserved inside the box (`0` uses the whole box) |

| Symbology | Kind | Value rules |
|-----------|------|-------------|
| `code128` | 1D | ASCII 0–127 |
| `code39` | 1D | A–Z, 0–9, space, `- . $ / + %` (lower case is upper-cased) |
| `code93` | 1D | Same set as Code 39 |
| `ean13` | 1D | 12 digits (13 with a valid check digit) |
| `ean8` | 1D | 7 digits (8 with check digit) |
| `upca` | 1D | 11 digits (12 with check digit) |
| `upce` | 1D | 7 digits (8 with check digit), starting with 0 or 1 |
| `itf` | 1D | Digits, even count (a leading 0 is added to odd lengths) |
| `codabar` | 1D | Digits and `- $ : / . +`; start/stop A–D added automatically |
| `qr` | 2D | Any text (UTF-8) |
| `datamatrix` | 2D | Any text |
| `pdf417` | 2D (stacked) | Any text |
| `aztec` | 2D | Any text |

Modules are scaled by a whole number of device pixels and drawn without anti-aliasing so they scan reliably at 203–360 dpi. The code is centred in its box; 1D codes stretch to the box height (minus the caption). If the box is too small for one pixel per module, `print()` fails with a message that says how large the box needs to be at the printer's dpi. Standard quiet zones are reserved by default — 10 modules for 1D codes, 4 for QR, 2 for Data Matrix / PDF417, 1 for Aztec — because scanners reject symbols without them (UPC/EAN end guards in particular).

::: tip
Barcodes render in previews on every tier. Printing them (like any label) to a real printer needs the **Label Printing** feature (Pro).
:::

### `image`

| Key | Default | Description |
|-----|---------|-------------|
| `src` | — | File name relative to `workspace/labels/` (PNG, JPEG, BMP, WebP …), a `data:image/…;base64,` URL, or a placeholder whose data value is base64 (a `snapshot()` from a camera) |
| `fit` | `contain` | `contain` (keep aspect, fit inside) \| `cover` (keep aspect, fill and crop) \| `stretch` |

File images must live inside the templates directory; paths that escape it are rejected.

### `rect`

| Key | Default | Description |
|-----|---------|-------------|
| `fill` | none | Fill colour |
| `stroke` | `#000000` | Outline colour (`null`/`"none"` for no outline) |
| `strokeWidth` | 0.3 | Outline width in template units, drawn inside the box |
| `radius` | 0 | Corner radius in template units |

### `line`

`x1`, `y1`, `x2`, `y2` in template units, plus `stroke` (`#000000`) and `strokeWidth` (0.3).

## Placeholders

`{{name}}` anywhere in `text`, `value`, `src` or `when` is replaced at print time. Look-up order: `data` (exact, then case-insensitive), dotted paths into nested objects (`{{order.id}}`), built-ins, then the field's `default`.

| Built-in | Value |
|----------|-------|
| `{{sequence}}` | The connector's running counter; increments per printed label (not for previews) and persists across restarts. Set it with the `sequence` property |
| `{{date}}`, `{{time}}`, `{{now}}` | Render time — combine with a format: `{{now|yyyy-MM-dd HH:mm}}` |
| `{{copy}}` | Copy number (1-based) |
| `{{page}}`, `{{pages}}` | Position within a `printBatch()` |
| `{{template}}`, `{{printer}}` | Template name and resolved printer name |

Formatters chain with `|`:

| Formatter | Example | Result |
|-----------|---------|--------|
| `pad:N` | `{{sequence|pad:6}}` | `000042` |
| `padright:N` | `{{name|padright:10}}` | left-aligned, space-padded |
| `upper`, `lower`, `trim` | `{{name|trim|upper}}` | `WIDGET` |
| `substr:start,len` | `{{serial|substr:0,4}}` | first four characters |
| `default:value` | `{{lot|default:n/a}}` | `n/a` when missing or empty |
| `date:format` | `{{expires|date:dd.MM.yyyy}}` | parses the value as a date |
| any .NET format string | `{{qty|000}}`, `{{now|HH:mm}}` | applied to numbers and dates |

Numbers print without trailing zeros; arrays and objects print as JSON.

## Limits

Bounds that fail at validation (or refuse a single element) rather than at allocation:

| What | Limit |
|---|---|
| Page `width` / `height` | 2000 mm each |
| `fontSize` and a text element's `size` | 500 pt |
| Image (inline `data:` URL, bare base64 or file) | 8 MB encoded, 16 megapixels decoded — checked from the header before decoding |
| `pad:N` / `padright:N` | N is capped at 256 |
| Placeholder parsing | 250 ms; an unterminated `{{ … ` with a very long formatter chain is reported as a template error |
| `labels.preview` over WebSocket | 5 per second per connection (`security.rateLimit.previewsPerSec`, minimum 1) |

## Sizing tips

- Design at the printer's real resolution: Brother P-touch 360 dpi, Epson TM-C3500 360 dpi, most Zebra 203 or 300 dpi. The driver renders at that dpi automatically; `dpi` in the template only matters for `px` units and previews.
- Keep 1–2 mm of margin: printer drivers have an unprintable border and tape printers cut a little off each end.
- A 1D code needs roughly `modules × 2` device pixels of width to be scannable at arm's length; when in doubt make the box wider rather than taller.
- Use `preview()` (or the dashboard canvas bound to the `preview` stream) while iterating — it does not consume media or the sequence counter.
- `validateTemplate()` reports errors and warnings without rendering; `listTemplates()` shows files that failed to parse.

::::
