# AI-assisted SCPI setup

Muxit's AI chat can add a new SCPI instrument (oscilloscope, multimeter,
power supply, signal generator, …) end-to-end — probe the device, look up its
command set online, write the connector config, and bring it online without a
restart. All three transports are supported: TCP/IP (LAN), Serial (RS-232 /
USB-to-serial), and USBTMC (direct USB-B). The AI uses the built-in
[`Scpi` protocol](https://docs.muxit.io/reference/drivers/scpi.md) — see also the
[Driver / Protocol / Engine concepts](https://docs.muxit.io/reference/concepts.md) page.

::: tip Subscription required
AI-assisted SCPI authoring uses Muxit's managed AI — **Maker tier or higher**.
On Free, you have two equally good paths:

- **Add SCPI instruments by hand** using the built-in [`Scpi` protocol](https://docs.muxit.io/reference/drivers/scpi.md) — the declarative `schema: { properties, methods }` block means most instruments are 20–40 lines of config. No code, no AI required.
- **Drive the same flow from your own AI client** by pointing Claude Desktop, Claude Code, or ChatGPT at Muxit's MCP server. The `probe_scpi_device`, `validate_connector_config`, and `write_connector_config` tools are exposed to MCP on all tiers, including Free — your AI client uses your own provider.

See [AI features by tier](https://docs.muxit.io/guides/ai.md#ai-features-by-tier) for the full breakdown.
:::

## Two ways to start

- **From the driver page.** Open the Add Connector dialog, select **Scpi**
  (in the Devices tab; the `protocol` chip identifies it), and click
  **Set up with AI**. The chat opens with a pre-filled prompt — edit the
  device details, hit enter, and follow along. (The legacy name
  **GenericScpi** still works in older connector files via an alias.)
- **From chat.** Say something like *"Add my Rigol DP832 at 192.168.1.50"*,
  *"Set up my Siglent SDG on COM5"*, or *"My Rigol DS1054Z is plugged in via
  USB"*. Any mention of SCPI, a common instrument class, a well-known vendor,
  or USBTMC routes the turn through the SCPI-authoring flow.

## What happens under the hood

When the AI detects SCPI-setup intent it activates the `scpi-authoring` tool
group and enables OpenRouter's web-search plugin for that turn. You'll see the
assistant use these tools in order:

1. `list_serial_ports` / `list_usbtmc_devices` — if you didn't specify a port
   or a USB VID/PID, the assistant suggests candidates. `list_usbtmc_devices`
   enumerates every USB device libusb can see; the assistant picks the one
   whose manufacturer/product matches your instrument.

   ::: tip Don't know which COM/tty port the instrument is on?
   Just say *"I don't know which port"* (or *"there are too many"* if you have
   several USB-serial gadgets plugged in). The assistant runs an **unplug-plug
   detection** flow: it snapshots the current ports, asks you to unplug the
   instrument, snapshots again, asks you to plug it back in, snapshots a third
   time, and the port that appeared on the last snapshot but wasn't there on
   the second is your device. Works on Linux, macOS, and Windows.
   :::
2. `list_manuals` — scans `workspace/manuals/` for any user-supplied
   programming guide matching the device. If one is there, the assistant
   prefers it over web search (see *Upload a programming manual* below).
3. `probe_scpi_device` — opens a one-shot TCP, serial, or USBTMC connection,
   sends `*IDN?`, and returns `{vendor, model, serial, firmware}`. Failures
   (timeout, refused, empty response, libusb permission) come back as
   `errors[]` so the assistant can tell you what went wrong instead of
   silently writing a broken config.
4. `search_manual` / `read_manual_pages` **or** web search — the assistant
   confirms exact command syntax against your uploaded manual (citing page
   numbers) or, if no manual is provided, looks up the programming manual on
   the web and cites URLs inline.
5. `validate_connector_config` — parses the drafted config through the same
   loader the server uses at startup. Catches syntax errors, disallowed
   globals, missing `driver` field, malformed `scpi` schema.
6. `write_connector_config` — saves the file to `workspace/connectors/`. If a
   file with the same name already exists, the assistant has to **summarize
   the change and ask for your confirmation** before the write goes through
   (chat gate, `kind: "connector"`). Every overwrite is automatically copied
   to `workspace/connectors/.backups/<name>.<timestamp>.js` (last 10 versions
   kept) so an accidental rewrite is one `restore_connector_backup` call away.
7. `reload_connectors` — tears down the connector registry and re-inits the
   catalog so the new device appears without a server restart.

## USBTMC (direct USB) instruments

Many benchtop instruments (Rigol DS1000Z, Keysight DSO-X, Siglent SDG/SSA, …)
plug in via USB-B and talk SCPI over the USB Test & Measurement Class
protocol. The AI handles these the same way as TCP / serial — tell it
*"my scope is plugged in via USB"* and it will:

1. Call `list_usbtmc_devices` to see every USB device libusb can enumerate.
2. Pick the entry whose `manufacturer`/`product` matches your instrument (or
   ask you to confirm if several look plausible).
3. Call `probe_scpi_device { transport: "usbtmc", vendorId, productId }`.

### Platform prerequisites

USBTMC needs libusb to be able to open the device. On Windows, install
[Zadig](https://zadig.akeo.ie), select your instrument from its list, and
switch its driver to **WinUSB**. This replaces whatever NI-VISA or Keysight IO
Libraries installed — if you want to use those tools again later, Zadig can
switch back.

If the probe fails the assistant surfaces the relevant fix inline.

## Upload a programming manual

For niche instruments, older models, or anything with a vendor manual behind a
login, dropping the PDF into `workspace/manuals/` gives the AI the exact source
of truth — more reliable and much cheaper than web search.

- **Where:** `workspace/manuals/` (create it if it doesn't exist — it's a
  standard workspace subdirectory). Per-device subfolders are optional but tidy
  for multi-instrument labs:

  ```
  workspace/manuals/
    rigol-ds1054z/DS1000Z_ProgrammingGuide.pdf
    siglent-sdg1032x/sdg_programming_manual.pdf
    notes.md
  ```
- **Formats:** text-based PDFs, plain `.txt`, and `.md` work. Scanned/image-only
  PDFs can't be read — the assistant will warn you and fall back to web search.
- **How the AI uses it:** `search_manual` runs a substring query and returns
  excerpts with page numbers (e.g. "p. 84: `:TIM:SCAL <scale_val>` — sets the
  horizontal time base scale"). `read_manual_pages` pulls a specific page range
  when the excerpt looked promising and the assistant wants more context.
- **Privacy:** manuals stay on your machine. Only the extracted excerpts the
  assistant decides to quote are sent to the LLM, same as any other tool result.
- **Cache:** the first `search_manual` call extracts the PDF to a sibling
  `<file>.extracted.txt` so subsequent queries are instant. Safe to delete —
  it'll be rebuilt on the next call.

## Tips

- **Tell the AI what the device is.** "My new Siglent SDG1032X on 192.168.1.42"
  is much more useful than "add a new device" — the assistant can jump straight
  to probing the right IP.
- **Probe results that don't match what you expected** mean either the IP/port
  is wrong, the instrument is in a non-SCPI mode, or the line terminator
  disagrees. The assistant will surface the raw IDN verbatim so you can see
  what the device actually reported.
- **Check cited URLs.** The LLM can misread a command table. If something
  doesn't look right, paste a relevant section of the manual back into chat and
  ask for a corrected draft.
- **Smoke test afterwards.** Ask *"read the output voltage"* or similar — the
  AI uses `read_property` against the new connector to prove the wiring works.

## Requires

- Maker tier license or higher (same gate as general AI chat).
- Web search is backed by OpenRouter's built-in `web` plugin (Exa), billed at
  roughly $4 per 1000 results against the account running the Muxit proxy. For
  a single instrument setup this is typically a few cents.

## Related

- [Connector configs](https://docs.muxit.io/guides/connectors.md) — declarative schema, custom methods,
  polling behavior.
- [Scpi protocol reference](https://docs.muxit.io/reference/drivers/scpi.md) — full
  `config.schema.{properties, methods}` schema.
- [AI chat](https://docs.muxit.io/guides/ai.md) — intent classification, memory, tools.
