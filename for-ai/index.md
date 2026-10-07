---
title: Muxit for AI Assistants
description: Self-contained references that let an AI assistant outside Muxit — ChatGPT, Claude, Copilot, Cursor — write working connectors, scripts and drivers.
---

# Muxit for AI assistants

The pages in this section are written for an AI assistant, not for a person. Each one is
self-contained, states the rules the Muxit runtime actually enforces, shows complete files
instead of fragments, lists the mistakes assistants make most often, and ends with a checklist.
Hand them to whatever assistant you already use, and it can write Muxit code that loads first
time without having seen Muxit before.

| Page | Use it when you want the assistant to write… |
|---|---|
| [Writing Connectors](https://docs.muxit.io/for-ai/connectors.md) | a `workspace/connectors/<name>.js` file: wiring an instrument, Arduino, sensor or other device into Muxit, or an in-memory store for dashboards |
| [Writing Scripts](https://docs.muxit.io/for-ai/scripts.md) | a `workspace/scripts/<name>.js` automation: measurement runs, sweeps, monitoring loops, data logging, alarms |
| [Writing Drivers](https://docs.muxit.io/for-ai/drivers.md) | a JavaScript, Python or C# driver, for a device no built-in protocol can talk to |

Most devices need only a connector. The assistant can tell from the connector page whether yours
needs a driver.

## For people: how to use these pages

1. **Give the assistant the page.** Pick whichever fits your assistant:
   - **Paste it.** Every page on this site has **Copy page as Markdown** at the top. Paste the
     result into the chat before your request.
   - **Attach one file.** [`llms-full.txt`](https://docs.muxit.io/llms-full.txt) holds all the pages in this section.
     Attach it, or save it into your project as context for a coding agent (Claude Code, Cursor,
     Copilot).
   - **Give it the link.** An assistant that can browse can start from
     `https://docs.muxit.io/llms.txt`, an index of every page as raw markdown.
2. **Tell it about your setup.** The make and model, how it is connected (serial port and baud
   rate, IP address and port, USB), what you want to read, set or automate, and — for an
   instrument — the command table from its programming manual. The assistant should not guess
   device commands, and the pages tell it not to.
3. **Put the file where it belongs.** Connectors go in `workspace/connectors/`, scripts in
   `workspace/scripts/`, drivers in `workspace/drivers/`. The file name matters: `psu.js` becomes
   the connector `psu`.
4. **Load it and check it.** For a connector, click **Reload** in Muxit's **Connectors** panel
   (and tick the connector if it shows as disabled); for a driver, restart Muxit. A connector
   that fails to load shows the error and line number on its card — paste that back to the
   assistant. Scripts run from the editor's **Run** button.

A request that works well:

```text
I'm attaching the Muxit reference for AI assistants. Follow it exactly: use only the APIs it
documents, no Node.js APIs, and don't invent device commands.

Write a Muxit connector for my <make and model>.
Connection: <e.g. USB serial on COM4 at 9600 baud / TCP 192.168.1.50 port 5025>
I want to: <read voltage and current, switch the output on and off, ...>
Command reference from the manual:
<paste the relevant commands>

Give me the complete file with its file name, then go through the checklist at the end of the
reference and tell me anything you could not verify.
```

**Other ways to get there.** Muxit's own chat assistant can probe a connected instrument and write
the connector for you — see [AI-assisted SCPI setup](https://docs.muxit.io/guides/ai-scpi-authoring.md). And an
assistant that supports MCP (Claude Desktop, Claude Code) can connect to Muxit's
[MCP server](https://docs.muxit.io/guides/ai.md#_2-mcp-server) and read schemas, write connector and script files,
and run scripts itself; these pages still tell it how to write them.

---

## For AI assistants: start here

You are writing code for **Muxit**, a hardware orchestration platform. A Muxit server (C#) runs
on the user's machine and talks to lab hardware: power supplies, multimeters, oscilloscopes,
robots, CNC machines, cameras, Arduinos, sensors. Everything a user automates is a JavaScript file
in their *workspace* folder, executed by the server in a sandboxed V8 engine — not in Node.js and
not in a browser.

### What you can write

| You write | File | What it is | Reference |
|---|---|---|---|
| **Connector** | `workspace/connectors/<name>.js` | One per device. Says which backend talks to the device (a built-in protocol, a driver, or nothing for an in-memory store), how it is connected, and optionally adds computed properties, helper methods, polling, safety limits and AI instructions. The file name is the device name. | [Writing Connectors](https://docs.muxit.io/for-ai/connectors.md) |
| **Script** | `workspace/scripts/<name>.js` | Automation. Plain top-level JavaScript, run on demand from the UI, by the AI, or at server start (`workspace/startup/`). Reads and writes connector properties synchronously. | [Writing Scripts](https://docs.muxit.io/for-ai/scripts.md) |
| **Driver** | `workspace/drivers/…` | A backend for a device no built-in protocol can talk to: vendor SDK, native library, complex binary protocol. JavaScript, Python or C#. A driver on its own does nothing — a connector selects it. | [Writing Drivers](https://docs.muxit.io/for-ai/drivers.md) |

### Decide what to write

- The user wants to **use a device** in Muxit → a **connector**. Most instruments need no driver:
  the built-in `Scpi`, `LineText` and `BinaryStream` protocols cover SCPI instruments, anything
  that prints text lines, and fixed-layout binary frames (Modbus RTU included).
- The user wants to **do something with devices that already have connectors** → a **script**.
- The device speaks something none of the protocols can express — a vendor DLL or Python
  package, a stateful handshake, a multi-step binary protocol → a **driver**, plus a connector
  that uses it.

When in doubt, write a connector first. A driver is the last resort, not the default.

### Rules for everything you write

1. **Use only the APIs these pages document.** Connectors, scripts and JavaScript drivers run
   in a sandbox: there is no `require`, no `fs`, no `process`, no `fetch`, no Node.js and no npm
   packages, and each kind of file has its own short list of globals. If something the user asks
   for needs an API that is not on these pages, say so instead of inventing one — an invented
   global or method fails at load time or, worse, silently returns `undefined`.
2. **Never invent device commands.** SCPI commands, line formats, register offsets and baud rates
   come from the device's manual or from the user. If you have to guess, say which values are
   guesses so the user can check them before the code touches hardware.
3. **This is real hardware.** Ask for the safe ranges before writing anything that sets
   voltages, currents, temperatures, speeds or positions. Encode them as `safety.limits` in the
   connector *and* check them in your own code — the `safety` block is only enforced on Muxit's
   Lab tier. Do not switch outputs on, move axes or write to non-volatile memory as a side
   effect of reading something.
4. **Deliver whole files.** Give the complete file, its exact path and name, and nothing to fill
   in except values only the user knows (port, IP address), which you call out.
5. **Finish with the checklist** at the end of the page you used, and tell the user anything you
   could not check.

### Version note

These pages describe the Muxit release they were built with. If the user's Muxit is older and
something here fails to load, ask for the error message — it names the problem — rather than
reaching for an older or invented syntax.

### Further reading

Every page of the documentation is available as raw markdown; [`llms.txt`](https://docs.muxit.io/llms.txt) lists
them. The ones you are most likely to need next:

- [Concepts — Driver, Protocol, Engine](https://docs.muxit.io/reference/concepts.md)
- [Scpi protocol](https://docs.muxit.io/reference/drivers/scpi.md), [LineText](https://docs.muxit.io/reference/drivers/linetext.md),
  [BinaryStream](https://docs.muxit.io/reference/drivers/binary-stream.md), [Transport](https://docs.muxit.io/reference/drivers/transport.md)
- [Built-in drivers](https://docs.muxit.io/reference/drivers/index.md)
- [Script API](https://docs.muxit.io/reference/script-api.md) and the [Script guide](https://docs.muxit.io/guides/scripts.md)
- [Safety](https://docs.muxit.io/guides/safety.md)
- [Driver SDK](https://docs.muxit.io/reference/driver-sdk.md) and [Driver manifest](https://docs.muxit.io/reference/driver-manifest.md)
