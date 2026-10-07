---
title: Driver Validation
description: Rules enforced by the driver validator — CLI and server.
---

# Driver Validation

The Muxit driver validator checks every driver source project against the canonical [manifest schema](https://docs.muxit.io/reference/driver-manifest.md). It runs as:

- **CLI** — `node drivers.js validate` (interactive) or `node drivers.js validate --all` (headless)
- **Server** — (Phase 3) `DllDriverValidator.cs` runs at driver scan and surfaces diagnostics in the Extensions panel
- **Release preflight** — `--strict` mode blocks a release if any rule fails

Rule definitions live in `lib/driver-manager/schema.js`. Each rule has an `id`, `severity`, and message template.

## CLI usage

```bash
node drivers.js validate              # interactive — pick one driver
node drivers.js validate --all        # validate every driver in drivers/ + drivers/js/
node drivers.js validate --all --json # structured output for tooling
node drivers.js validate --all --strict  # soft warnings become blocking
```

Exit codes: `0` when no hard errors (soft warnings allowed unless `--strict`), `1` otherwise.

## Severity

- **hard** — validator exits non-zero; the driver is unfit to ship. The server (Phase 3) refuses to register the driver and surfaces an error badge in the Extensions panel.
- **soft** — validator warns but exits zero. `--strict` elevates soft warnings to failures. Useful for marketplace hygiene (missing description, unknown tag, etc.).

## Rules

### Manifest basics

| Rule ID | Severity | Fires when |
|---------|----------|------------|
| `MANIFEST_MISSING` | hard | `manifest.json` does not exist next to the driver source |
| `ID_MISSING` / `ID_INVALID` | hard | `id` missing or does not match the id regex |
| `NAME_MISSING` | hard | `name` missing |
| `VERSION_MISSING` / `VERSION_INVALID` | hard | `version` missing or not semver `x.y.z` |
| `ENTRYPOINT_MISSING` / `ENTRYPOINT_UNSAFE` | hard | `entryPoint` missing, or contains `/` or `..` |
| `FORMAT_VERSION_INVALID` | hard | `formatVersion` != 1 |
| `CATEGORY_MISSING` / `CATEGORY_INVALID` | hard | `category` missing (C#) or not `free`/`premium` |
| `TIER_INVALID` | hard | `tier` not 1 or 3 |
| `JS_PREMIUM_FORBIDDEN` | hard | JS driver declares `category: "premium"` — not supported |

### Premium integrity

| Rule ID | Severity | Fires when |
|---------|----------|------------|
| `PREMIUM_NO_DRIVER_ID` | hard | Premium manifest but no `[assembly: DriverId(...)]` in source |
| `PREMIUM_DRIVER_ID_MISMATCH` | hard | `[DriverId]` first arg disagrees with short id from manifest |
| `PREMIUM_DRIVER_ID_HASH_MISMATCH` | hard | Attribute hash or `driverIdSha256` disagrees with expected `SHA256("muxit.io:driverId:{shortId}")` |
| `PREMIUM_MANIFEST_HASH_MISSING` | hard | Premium manifest is missing `driverIdSha256` |
| `FREE_HAS_DRIVER_ID` | soft at build, **hard at load on a signed DLL** | `category: "free"` but the source declares `[assembly: DriverId(...)]` |

`FREE_HAS_DRIVER_ID` is worth a note, because it is the one rule whose severity depends on
where it fires. The server does not take `manifest.category` as the answer to "is this
driver licensed?" — the manifest is plain text inside the package, while the DLL and its
signature are not. What the server uses instead is the pair a repackager cannot forge: an
official muxit signature over the DLL, **and** an `[assembly: DriverId]` whose hash checks
out. A package carrying both is licensed as premium whatever its manifest says.

So at build time a `free` manifest over a `[DriverId]` source is advice — the DLL is not
signed yet and nothing is being bypassed. Once that package is signed and installed, the
manifest is contradicting the package about something the server has already decided, and
the runtime validator raises it as a hard error. Set `category` to `premium`.

### C# source

| Rule ID | Severity | Fires when |
|---------|----------|------------|
| `CSPROJ_MISSING` | hard | No `.csproj` file in the driver project |
| `CSPROJ_SDK_MISSING` | hard | `.csproj` does not reference `Muxit.Driver.Sdk` |
| `DRIVER_CS_MISSING` | soft | No `*Driver.cs` file found |
| `DRIVER_GROUP_MISSING` | soft | No `[assembly: DriverGroup(...)]` — UI falls back to `Instruments` |

### JS source

| Rule ID | Severity | Fires when |
|---------|----------|------------|
| `JS_DEFAULT_EXPORT_MISSING` | hard | Driver file has no `export default` |
| `JS_META_MISSING` | hard | Default export has no `meta` section |

### Marketplace hygiene

| Rule ID | Severity | Fires when |
|---------|----------|------------|
| `DESCRIPTION_MISSING` / `DESCRIPTION_SHORT` | soft | `description` missing or under 40 characters |
| `TAGS_MISSING` / `TAGS_TOO_MANY` / `TAGS_UNKNOWN` | soft | Tags missing, more than 8, or not in the [tag vocabulary](https://docs.muxit.io/reference/driver-tags.md) |
| `AUTHOR_MISSING` | soft | `author.name` missing |
| `GROUP_MISSING` / `GROUP_INVALID` | soft | Manifest `group` missing or not in `instruments`/`motion`/`communication`/`utilities` |

### Revision history

Every driver keeps its own `CHANGELOG.md` — that is the driver's revision
history, kept separate from the core `revision-history.md`. Driver changes go
here, never in a core revision fragment.

| Rule ID | Severity | Fires when |
|---------|----------|------------|
| `CHANGELOG_MISSING` | soft | No `CHANGELOG.md` alongside the driver source |
| `CHANGELOG_VERSION_MISSING` | soft | The current `manifest.version` has no matching `## <version>` section in `CHANGELOG.md` |

The published version's section is rendered on the driver's registry detail
page. `tools/check-revision-scope.js` (run in CI) additionally fails a
driver-only change that adds a core revision fragment.

### Runtime capability audit (server only)

| Rule ID | Severity | Fires when |
|---------|----------|------------|
| `FREE_DRIVER_CAPABILITIES` | soft | Free DLL driver references sensitive .NET APIs (FileSystem, Network, Process, Reflection, Registry) — shown as an advisory in the Extensions panel |
| `FREE_DRIVER_CAPABILITY_SCAN_FAILED` | soft | Free DLL driver could not be statically analyzed (typically because an out-of-band dependency like `System.IO.Ports` isn't resolvable from the runtime dir). No capability claim is made; still advises caution |

## JSON output

```bash
node drivers.js validate --all --json
```

```json
{
  "results": [
    {
      "driver": { "name": "Avantes", "type": "csharp", "dir": "/.../Muxit.Driver.Avantes" },
      "errors": [],
      "warnings": []
    }
  ],
  "summary": { "errors": 0, "warnings": 0, "strict": false }
}
```

Downstream tools (release preflight, Development web GUI) consume this format directly.
