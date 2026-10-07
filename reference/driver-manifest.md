---
title: Driver Manifest Schema
description: Canonical manifest.json schema shared by JS and C# drivers.
---

# Driver Manifest Schema

Every Muxit driver ships a `manifest.json` alongside its source. The manifest is the single source of truth for identity, versioning, packaging, and marketplace metadata. This page is the canonical reference.

The schema is enforced by:

- **CLI** — `node drivers.js validate --all` (see [Driver Validation](https://docs.muxit.io/reference/driver-validation.md))
- **Server** — (Phase 3) `DllDriverValidator.cs` runs at driver scan
- **Build** — `node build.js drivers` uses the manifest for `.muxdriver` packaging

Rules for each field live in `lib/driver-manager/schema.js`.

## Required fields

| Field | Type | Rule |
|------|------|------|
| `formatVersion` | integer | Must be `1`. Bumped only when the schema changes incompatibly. |
| `id` | string | `[org/]short-id`, lowercase kebab (`^[a-z0-9][a-z0-9-]{2,39}$`). Example: `"muxit/fairino"`. |
| `name` | string | Human display name (3–60 chars). |
| `version` | string | Semver `x.y.z`. |
| `entryPoint` | string | Bare filename of the driver entry. C#: `Foo.dll`. JS: `foo.driver.js`. Must not contain `/` or `..`. |
| `category` | string | `"free"` or `"premium"`. Required for every driver — a missing `category` is a hard error (`CATEGORY_MISSING`). JS and Python drivers must be `"free"`; only C# DLLs may be `"premium"`. |
| `tier` | integer | `1` (JS), `2` (Python), or `3` (C# DLL). |

## Recommended fields (soft rules — validator warns)

| Field | Type | Recommendation |
|-------|------|----------------|
| `description` | string | ≥ 40 chars. Shown in the Extensions panel and marketplace. |
| `tags` | string[] | 1–8 entries from the controlled [Driver Tags vocabulary](https://docs.muxit.io/reference/driver-tags.md). |
| `author` | `{ name, url?, github? }` | Helps users find support. |
| `group` | string | One of `instruments`, `motion`, `communication`, `utilities`. C# drivers may also declare this as `[assembly: DriverGroup(...)]`; the attribute is authoritative at runtime. |

## Premium-only fields

Premium C# drivers must declare both an assembly-level `[DriverId]` attribute and a matching `driverIdSha256` in the manifest so tampering is detectable:

```json
{
  "id": "muxit/fairino",
  "category": "premium",
  "driverIdSha256": "94c8e159563db496ac94ee4a1d21d0376e167603a603a4ec4cbc4a75196f3b25"
}
```

```csharp
// FairinoDriver.cs
[assembly: DriverId("fairino", "94c8e159563db496ac94ee4a1d21d0376e167603a603a4ec4cbc4a75196f3b25")]
```

The hash is `SHA256("muxit.io:driverId:{shortId}")` in lowercase hex, where `shortId` is the id without an org prefix. Compute it with:

```js
require('./lib/driver-manager/schema').computeDriverIdHash('fairino')
// → '94c8e159563db496ac94ee4a1d21d0376e167603a603a4ec4cbc4a75196f3b25'
```

JS and Python drivers cannot be premium (neither the V8 sandbox nor the Python subprocess host supports licensed entitlements). Setting `category: "premium"` on a JS driver (`JS_PREMIUM_FORBIDDEN`) or a Python driver (`PYTHON_PREMIUM_FORBIDDEN`) is a hard validation error.

::: warning `category` describes the package — it does not decide licensing
`manifest.json` is plain text inside the `.muxdriver` zip; the DLL and its detached
signature are not. So the server does not ask the manifest whether a driver is licensed. It
derives that from the two things a repackager cannot forge together: an official muxit
signature over the DLL, **and** an `[assembly: DriverId]` whose hash verifies. A package
carrying both is gated as premium — tier plus entitlement — no matter what `category` says,
and `FREE_HAS_DRIVER_ID` becomes a hard error at load to say the manifest is wrong.

The manifest still matters in the other direction: `category: "premium"` over an *unsigned*
DLL is refused outright, before the assembly is loaded.

Keep `category` accurate anyway. It is what the Extensions panel, the marketplace listing
and `drivers.js` read, and a package that describes itself wrongly fails validation.
:::

### Commerce block (premium drivers)

Premium drivers carry an optional `commerce` block that binds the driver to its storefront product and ships marketplace copy. The Dev Console's **Premium** tab is the canonical editor (`node muxit.js d` → Premium); saves write straight back to `manifest.json` so the binding ends up inside the signed `.muxdriver`.

> **Note on field names.** The `lemonSqueezy*` field names (and the Dev Console's "Push to LS" product mirror) are retained from the original Lemon Squeezy integration for backward-compatibility — existing signed `.muxdriver` packages keep working. Customer-facing purchases now go through **Polar** (Merchant of Record); the proxy maps a Polar purchase back to the product ID stored in this block.

At server boot, `MuxitServer/Drivers/DllDriverHost.cs` reads `commerce.lemonSqueezyProductId` and feeds it into `LicenseManager.RegisterDynamicFeature(...)` so a customer's Polar activation can be matched back to this driver. Without a product ID, activations for this driver will not resolve.

| Field | Type | Notes |
|-------|------|-------|
| `commerce.lemonSqueezyProductId` | string | Numeric LS product ID (e.g. `"903706"`). Required for production premium drivers. |
| `commerce.lemonSqueezyVariantId` | string | Numeric variant ID. Optional — only needed when the LS product has multiple variants. |
| `commerce.price.amount` | integer | Price in minor units (USD cents, etc.). Mirror of LS for display. |
| `commerce.price.currency` | string | ISO 4217 3-letter code, e.g. `"USD"`. |
| `commerce.storefront.tagline` | string | One-line marketing summary shown in the marketplace. |
| `commerce.storefront.longDescription` | string | Markdown description; pushed to LS as the product description by the Dev Console's "Push to LS" action. |
| `commerce.storefront.images` | string[] | Optional screenshot paths, relative to the manifest. |

Validation rules:

- `COMMERCE_MISSING_FOR_PREMIUM` (warning) — premium driver has no `commerce` block.
- `COMMERCE_LS_PRODUCT_MISSING` (warning) — `commerce.lemonSqueezyProductId` is unset.
- `COMMERCE_LS_PRODUCT_FORMAT` / `COMMERCE_LS_VARIANT_FORMAT` (hard error) — IDs must be numeric strings.
- `COMMERCE_PRICE_INVALID` (hard error) — `price.amount` must be a non-negative integer; `currency` must be 3 uppercase letters.
- `COMMERCE_FREE_FORBIDDEN` (warning) — `commerce` is set on a free driver; remove it.

CI gate: `node drivers.js premium-status --strict --json` exits non-zero when any premium driver has outstanding readiness issues. Add this to your release checklist before cutting a tag.

## Optional fields

| Field | Type | Notes |
|-------|------|------|
| `homepage` | string (URL) | |
| `repository` | string (URL) | |
| `license` | string | SPDX id, e.g. `"MIT"`. |
| `icon` | string | Filename relative to the manifest. |
| `minimumServerVersion` | string (semver) | Refuse to install on older servers. |
| `capabilities` | string[] | Declared capabilities (future use). |
| `permissions` | string[] | Declared permissions (future use). |

## Connector starter template (`template.js`)

Every driver must ship a real `template.js` file at the root of its project (alongside `manifest.json`). The packager copies it into the `.muxdriver` at the package root, and the server reads it at driver scan time to populate the "Create connector" starter content.

- C# extension drivers: `drivers/Muxit.Driver.<Name>/template.js`
- JS drivers: `drivers/js/<name>/template.js` (next to `<name>.driver.js`)
- Built-in drivers: `MuxitServer/Drivers/BuiltIn/Templates/<DriverName>.js` (embedded resource; loaded via `BuiltInTemplateLoader`)

No manifest field is needed — the filename is fixed by convention. The validator raises `TEMPLATE_FILE_MISSING` (hard error) if it is absent, and `node drivers.js build` refuses to produce a package without it.

## Complete example (premium C# driver)

```json
{
  "formatVersion": 1,
  "id": "muxit/fairino",
  "name": "Fairino",
  "version": "1.0.0",
  "description": "Fairino collaborative robot driver (FR3/FR5/FR10/FR20) — XML-RPC, MoveJ/MoveL, kinematics, I/O, force sensing.",
  "author": { "name": "muxit" },
  "tier": 3,
  "category": "premium",
  "group": "motion",
  "tags": ["robotics", "motion"],
  "driverIdSha256": "94c8e159563db496ac94ee4a1d21d0376e167603a603a4ec4cbc4a75196f3b25",
  "entryPoint": "Fairino.dll",
  "commerce": {
    "lemonSqueezyProductId": "987654",
    "price": { "amount": 4900, "currency": "USD" },
    "storefront": {
      "tagline": "Native XML-RPC driver for Fairino collaborative robots.",
      "longDescription": "Connect Muxit to any Fairino cobot..."
    }
  }
}
```

## Complete example (free JS driver)

```json
{
  "formatVersion": 1,
  "id": "muxit/gcode",
  "name": "Gcode",
  "version": "1.1.0",
  "description": "G-code/GRBL driver for CNC machines, pen plotters, and laser cutters. Serial-sender with status polling.",
  "author": { "name": "Muxit", "github": "muxit-io" },
  "tier": 1,
  "group": "motion",
  "entryPoint": "gcode.driver.js",
  "tags": ["gcode", "grbl", "cnc", "plotter", "laser"],
  "license": "MIT",
  "repository": "https://github.com/yourname/your-driver"
}
```
