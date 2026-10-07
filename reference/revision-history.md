# Revision History

All notable changes to Muxit are documented here, grouped by version.

## v0.43.0 — October 7, 2026

### Features

- **The AI output budget is now editable in Settings → AI Services.** "Max response tokens" writes `ai.maxTokens`, which previously existed only as a hand-edited key in `server.json` — including for the truncated-tool-call error, which told you to raise it in a panel that had no such field. Raise it when the AI writes scripts, connector configs or dashboards; the default of 2048 stays tuned for ordinary chat replies. The field accepts 256–32768 as a guard against a mistyped budget, and `server.json` still takes any value.
- **Five new widgets for operator-facing process dashboards — Select, Input, Status Banner,
  Progress and Steps — plus a rebuilt Terminal.** Together these cover running a job from a dashboard rather
  than watching one: **Select** writes a chosen value to a connector property (dropdown, or
  segmented/radio presentations sized for gloved fingers on a touch panel); **Input** types or scans
  a value into a property, committing on Enter and selecting-all on focus so barcode scanners work
  unchanged; **Status Banner** fills its area with one colour and one word, scaling the text with
  the widget so a result stays readable across a workshop; **Progress** shows a determinate bar or a
  continuous sweep; **Steps** tracks a multi-stage sequence with pass/fail/running icons.

  **The Terminal widget is now a production log.** Lines are coloured by detected severity
  (`[ERROR]`, `[WARN]`, `[OK]`, `DEBUG`), and a toolbar adds a filter, a scroll lock for reading
  while output continues, copy-to-clipboard, save-to-file and clear. String payloads emitted from a
  script no longer arrive wrapped in JSON quotes.

  **A worked example ships in new workspaces.** The **Production Line** dashboard, the
  `fixture-line` Virtual connector and `scripts/examples/fixture-test.js` together demonstrate the
  whole pattern — the connector holds process state, the script advances it, and ten widgets bind to
  it — as a starting point for programming and testing fixtures on a line.
- **The dashboard editor has undo and redo, and Delete Widget asks first.** Ctrl+Z (Cmd+Z) undoes the last move, resize, configuration edit, added or deleted widget; Ctrl+Shift+Z or Ctrl+Y redoes it. A drag or a run of typing is one step. Deleting a widget — previously a single unconfirmed click with no way back short of not saving — now confirms and names the shortcut that reverses it.
- **Three new presentation widgets — Label, Image and Divider — with a widget style cascade and
  three layout modes.** Dashboards can now carry the furniture a production screen needs around its
  live data: a screen title, a company logo, a separating rule. None of them needs a connector
  binding. A **Label**'s text can embed live values as `${connector.property}`, so a heading can read
  "Line 3 — Fixture: FX-220" and track the device; an unresolved reference renders verbatim rather
  than blanking, so a typo stays visible. An **Image** shows a file from the new `workspace/assets/`
  folder, or takes a binding so the picture follows process state. A grouping **Panel** frame was
  built alongside them but is held back from the palette until it can be drawn outside the grid;
  a dashboard that already contains one keeps rendering it.

  **Images are served by a new always-on `/api/assets/` route.** Unlike the file editor's
  `/api/editor/raw/`, it does not require `security.editorMode`, so dashboards keep their branding on
  a locked-down production machine. It is read-only, confined to `workspace/assets/`, and restricted
  to image, video, audio and PDF file types.

  **The widget palette is grouped into sections** — Presentation, Display, Input, Status, Data,
  Streaming — instead of one flat list of every widget.

  **Dashboards can drop the box around every widget.** Every widget used to be drawn on a background
  with a border, which suits a gauge and looks wrong around a divider or a screen title — a divider
  was a line inside a box. Widget style is now a cascade: set **Widget style** per dashboard
  (`card`, `flat` or `none`), override it on any individual widget, and note that Label, Image and
  Divider are unstyled by default because furniture never looks better in a box. Switching a
  dashboard to `card` therefore boxes up the gauges without putting a box back around the divider.

  **Dragging a widget no longer shoves everything it passes over.** The Layout setting now offers
  three behaviours instead of two: **Auto-stack** (the previous default — widgets push each other and
  re-flow), **Fixed grid** (nothing is pushed; a drag is refused over an occupied cell) and **Free**
  (widgets may overlap and nothing moves but the one you are dragging). The old "Free placement"
  option was misnamed: it stopped widgets auto-stacking but still pushed them aside. Where widgets
  overlap in Free layout, **alt-click** (option-click on a Mac) cycles down through everything under
  the pointer to reach the one underneath.
- **`MUXIT_DATA_DIR` moves Muxit's per-user data directory.** The workspace catalog, instance
  locks, logs and license cache live under `~/.muxit` (macOS / Linux) or `%LOCALAPPDATA%\Muxit`
  (Windows). Set the environment variable to a folder and all of it lives there instead — for a
  portable install on a USB stick, a shared bench account that wants separate catalogs per person,
  or anything that needs Muxit to leave the home directory alone.
- **The docs have a section written for AI assistants.** *For AI Assistants* gives ChatGPT, Claude, Copilot or any other assistant a self-contained reference for writing connectors, scripts and drivers: the rules the runtime enforces, complete examples, the mistakes assistants make most often, and a checklist. Every docs page now has **Copy page as Markdown** and **View as Markdown**, and the docs serve `llms.txt` (an index of every page as markdown) and `llms-full.txt` (the whole AI section in one file) — on docs.muxit.io and from your own Muxit server under `/docs/`.
- **Label printing: a Tools → Label Printing page and a built-in LabelPrinter driver.** The new page lists the printers installed on the computer with their status, creates a connector for a printer in one click (Brother P-touch, Epson TM-C3500, Zebra with its driver, Print to PDF, CUPS queues …), and shows every template in `workspace/labels/` with a field form, a live preview and a Print button. Templates are JSON (`*.label.json`) combining text, images, shapes and barcodes / 2D codes (Code 128, Code 39/93, EAN/UPC, ITF, Codabar, QR, Data Matrix, PDF417, Aztec) with data placeholders, formatters and a persistent `sequence` counter.

  Scripts use one connector per printer: `printer.template = "shipping"; printer.print({ serial: "SN-1" })`, plus `printBatch()`, `preview()`, `printImage()` and `printRaw()` for ZPL/TSPL/ESC-P pass-through; the driver reports spooler status (`paper-out`, `offline`, …), a `jobs` stream and enforces runaway caps. Printing to a real printer is a new Pro-tier feature, **Label Printing**; listing printers, templates, previews and `null` dry runs are free.

  New WebSocket messages `labels.*` and `/api/labels` endpoints back the page. Built-in drivers now also receive a per-instance state directory like DLL extensions. New guide: *Label Printing*; new reference pages: *LabelPrinter* and *Label Templates*. The Templates tab opens a **visual label designer** (drag, resize, snap-to-grid, properties panel, sample data, server-rendered live preview, undo/redo, Design / Edit JSON toggle on the same tab) — it writes the same JSON. The **Tools → Label Printing…** menu item shows a PRO badge while printing is not licensed; the page itself stays available.
- **Startup scripts and video recording now require a Maker license, as the pricing page has said all along.** Both were listed as Maker features but nothing enforced it, so Free installations had them. On Free, scripts in `workspace/startup/` are still listed and can be started by hand, but they no longer launch on their own at boot — the server log says `Startup scripts not run` with the reason, and each file gets a `script.done` carrying it. `record` and `recordStart` on Webcam and ONVIF connectors fail with `VIDEO_RECORDING_REQUIRES_MAKER`; live streaming and snapshots are unaffected. Maker, Pro and Lab see no change.
- **Operator mode — boot straight into a dashboard, enforced by the server.** Put dashboards and
  scripts in the `operator/` sub-folders of `workspace/dashboards/` and `workspace/scripts/`, then
  set **Settings › Accounts › Anonymous visitors** to *Dashboards only* (`"anonymous": "dashboard"`
  in `config/accounts.json`). There is no separate switch: operator mode is what anonymous visitors
  get under that policy, it takes effect without a restart, and a file with no accounts listed is
  an anonymous kiosk. The operator shell shows the dashboard with connection state, Stop All, and
  `ask.*` prompts as modals — no editor, explorer or settings. A single device can opt in without
  changing anything by loading `?view=operator`; that is presentation only and enforces nothing.

  Under that policy, the server holds every anonymous client to a write gate: editing
  scripts, connectors, dashboards or config, the immediate window, marketplace and driver installs,
  updates, licensing, agents, AI chat and safety-level changes all return
  `OPERATOR_MODE_RESTRICTED`, and the safety level is pinned. Reads pass, as do the writes a
  dashboard is made of: `connector.call`, answering `ask.*` prompts, stopping any script, and
  starting scripts from the `operator/` folder. The editor API and the immediate window are refused
  per request rather than switched off, so a signed-in engineer or admin still reaches them and can
  change the policy back from Settings; `/mcp` is refused the same way for anyone without an
  author's account token.

  **Read-only AI chat in operator mode, per dashboard.** Tick **Operator chat** in a dashboard's
  settings (`"chat": true` in the file) and that dashboard gains an **Ask** panel in the operator
  shell; a wall display on the same station stays clean. The assistant can read device state,
  scripts and their output, dashboards, docs and instrument manuals and explain them — it cannot
  write a property, call an action, start or stop a script, or author anything. Write tools are
  never advertised to the model and are refused at dispatch if called anyway. Off by default, only
  dashboards under `operator/` count, and enabling it widens nothing else in the gate.

  **Operator mode requires a Pro license.** The locked station, its capability gate and the
  read-only chat are gated on a new `operator-mode` feature at Pro tier and above. A station whose
  license does not cover it starts as an ordinary Muxit install — the mode does not engage, and both
  the startup banner and the server log say so plainly, because the consequence of a lapsed license
  is that a locked station comes back *unlocked*. The audit trail naming which operator did what
  remains a Lab feature. Settings › Server shows gated features through a shared tier-gate
  component: visible and explained, with the controls disabled and a link to pricing.

  **Operator mode and the safety audit log survive a license lapse for 60 days.** The subscription
  tier is confirmed by a signed proof valid for 24 hours, so the usual cause of a station dropping to
  Free is a network outage rather than an unpaid invoice — and losing operator mode in that moment
  would silently put the full interface in front of whoever is standing at the station, mid-shift.
  A machine that has held the required tier keeps both features for 60 days after its license last
  checked out, warning every day on the startup banner, across the top of the operator shell with a
  countdown, on the sign-in screen, and in Settings. Each warning says which of the two problems it
  is — Muxit cannot reach the license service (check the connection), or the subscription ended
  (renew it) — because the fixes are completely different. A cancelled or revoked subscription,
  where the service answers and refuses, gets no grace; neither does a machine that never held the
  license. The grace is anchored on the signed proof itself, so signature and machine-fingerprint
  checks still apply and it cannot be forged by editing local files or copying a proof from a
  licensed machine.
- **Scripts drop `script.running` and the automatic `main()` call.** Pressing Stop has always ended a script immediately, wherever it is, so `while (script.running)` was really `while (true)`, and code after the loop never ran. The flag suggested otherwise, so it is gone: write `while (true) { …; delay(ms); }`. A script is now plain top-level code. A `function main()` is no longer called for you, so a script that only *defines* `main()` does nothing; move its body to the top level. A top-level `return value` still sets the script's result. All bundled example scripts, tutorials, the new-script template and the docs have been rewritten to this style. **If you have your own scripts**, replace `script.running` in loop conditions (`while (true)`, or drop the `&& script.running` term) and unwrap any `main()` function.
- **User accounts: admin, engineer and operator sign-in with PINs, on any install.** A new **Settings › Accounts** tab creates the first admin from the app itself — on the machine, or from a browser signed in with the remote-access password — and then manages people, the sign-in policy and the idle timeout, effective immediately with no restart. Three roles: an **operator** gets only the operator dashboards and their controls, on every install; an **engineer** gets the full interface; an **admin** is an engineer who also manages accounts. A chip in the status bar shows who is signed in and offers sign in, switch user and sign out; switching keeps your open editor tabs, because the server swaps the identity behind the live connection instead of the page reloading. The operator shell gets the same **Switch**, and a session that idles out mid-edit now raises the sign-in panel over the IDE instead of silently refusing every save. One policy decides what a connection that has not signed in gets — **everything** (anyone may work; signing in adds a name), **dashboards only** (the operator shell, held to the operator gate: this is how operator mode is switched on) or a **sign-in screen** (anonymous connections may read but not act, and the full interface asks who you are first) — stored as `anonymous` in `config/accounts.json` where only an admin can change it, effective immediately. Signed-in people are named on safety confirmations and, on Lab, in the audit log. Accounts are a **Pro** feature with the same 60-day downgrade grace as operator mode. Without any accounts nothing changes.

  Remote access and accounts are two separate credentials sent together (`X-Auth-Token` + `X-Muxit-Account`; `auth-…` + `account-…` WebSocket subprotocols): a PIN is never accepted in place of the remote-access password. The last admin cannot be removed or demoted; recovery is deleting `config/accounts.json`.
- **New `Virtual` built-in driver for hardware-free, in-memory connectors.** `driver: "Virtual"` — or no `driver:` / `protocol:` / `engine:` keyword at all — gives a connector that only holds the values, computed properties and methods you define in the file, so dashboards and scripts can share state without a device. Values live in memory and are not persisted across restarts. A keyword-less file resolves to Virtual only when every top-level key is a standard connector key; a file with an unrecognised key (a typo like `drivr:`) still fails to load, now naming the offending key. Ships with a `virtual-store.js` example in new workspaces and an **Add Connector** template.

### Bug Fixes

- **Two people managing accounts at the same moment can no longer corrupt the account list or
  lock everyone out.** The account store is what every sign-in reads and every Accounts tab
  writes, and two browser tabs acting together means two requests running at once — but the list
  had no synchronisation. A read of the sign-in screen's account list while another request saved
  could throw outright, an edit could act on a stale position in the list, and the "is this the
  last admin?" guard was checked outside the write that depended on it, so two admins each
  demoting the other could both be told they were fine and leave the station with no admin at
  all. The same applied to requiring sign-in while the last engineer was being removed.

  Creating the very first admin is also one decision again. Before any admin exists the window is
  open to whoever is at the machine or holds the remote-access credential, and two such callers
  could both pass that check and both create a first admin. The window is now re-checked at the
  moment of the write, so the second is told an admin already exists.
- **A PIN session token is no longer accepted in the URL.** `?account=<token>` was honoured as a fallback on HTTP requests and WebSocket upgrades, which put a live sign-in credential into proxy, server and browser-history logs. Nothing shipped ever sent it that way — the UI uses the `X-Muxit-Account` header and sockets the `account-<token>` subprotocol — so the fallback is removed. `?token=` for the transport token is unchanged, and remains the only way to load an asset URL into an `<img>`.
- **AI chat no longer claims to be in operator mode when you are signed in as an admin or engineer.** The operator tool gate was asked about the station rather than the person, so on a station running operator mode a signed-in author lost every write tool — the assistant reported it could not edit connectors "because it is in operator mode" — while a signed-in operator on an ordinary station kept the full set. Chat now resolves who is asking on each turn: admin and engineer keep the whole toolset, an operator is read-only wherever they sign in, and the refusal the model sees names the right surface.
- **An AI reply that ran past the output cap no longer dies with a raw JSON parse error.** When the model reached `ai.maxTokens` partway through writing a tool call, the provider cut the arguments off mid-value and the chat surfaced the resulting `System.Text.Json` message verbatim — `Expected end of string, but instead reached end of data. LineNumber: 0 | BytePositionInLine: 6373.` Nothing read the response's stop reason, so the truncation was invisible and a half-written payload was treated as a finished tool call. The stop reason is now checked on both the Anthropic (`max_tokens`) and OpenAI-format (`length`) streams: a truncated turn carrying tool calls is refused with `AI_OUTPUT_TRUNCATED` and a message naming the limit it hit and the setting to raise, rather than executing a tool with partial arguments. Truncated prose is unaffected beyond a server-log warning. Malformed tool arguments from any other cause now degrade to an empty object instead of throwing.
- **Dashboards with a chart, scope or multi-binding widget no longer re-render ten times a second when nothing has changed.** Those widgets' values were rebuilt as new objects on every poll tick, so the change check always fired; values are now compared one level deep and unchanged widgets keep their previous value, which lets the whole dashboard skip the render.
- **Dashboard drag-and-drop now does what the dashboards guide describes.** A stream dropped onto a new Canvas/Video widget plays straight away: new canvases start in *Image Stream* mode, the mode their settings already showed (before, an empty web frame swallowed the drop). A property dropped onto a chart is added to its plotted values instead of being ignored. And scripts in the Scripts panel can be dragged onto a dashboard in edit mode to create a Script Control widget.
- **The dashboard editor fits the dashboard beside its side panels.** In edit mode the grid used to keep its full live-mode width and run underneath the widget palette and the properties panel, so you were always scrolling sideways to reach widgets. It now fills the space left between the two panels. Widgets are a little narrower while you edit and return to full width when you leave edit mode.
- **Script Control widgets now work on mobile dashboards.** The mobile dashboard screen routed
  every widget action through a binding lookup, so a Script Control button — which uses
  `scriptName` rather than a `binding` — did nothing when tapped. Action routing is now shared
  with the desktop dashboard, so the two can't drift apart again. Mobile widgets also receive the
  `sendAction` and `server` handles they were missing, which restores the Terminal widget's input
  bar and the Canvas widget's stream access on phones and tablets.

  **Corrected the dashboard documentation.** The Dashboard Guide and the *Your First Dashboard*
  example both showed widget positions as top-level `x`/`y`/`w`/`h` and bindings as separate
  `connector` and `property` config keys. Neither form has ever been read by the dashboard
  renderer: positions live in a nested `layout` object and bindings in a single `binding` string
  (`"psu.voltage"`). Copying the old examples produced a dashboard with every widget stacked in
  the corner showing no data.
- **Workspaces whose folder was deleted no longer clutter the workspace list.** They used to stay in the startup picker, the title-bar **Switch to** menu and the **Open Workspace…** dialog forever — dimmed and unclickable, but there, sometimes by the hundred — and any two of them made the picker appear on every launch. Muxit now forgets an entry whose folder is gone while the folder it lived in is still there, at startup and whenever a list is shown. A workspace on a USB drive, network share or drive letter that is simply not connected is kept, marked "missing", and works again when the drive is back. And when a single workspace is left in the list, Muxit opens it at startup instead of creating a second **Default** workspace beside it.
- **Development-only overrides are now compiled out of release builds.** Muxit has a handful of
  environment variables that exist purely so the project's own test suite can simulate a license tier,
  lift the concurrent-instance cap and point the licensing client at a staging server. They were meant
  to be inert outside development, and several comments said so, but nothing actually made that true —
  the check happened at run time, so the variables were still live in a shipped copy.

  They are now removed at compile time. A released build contains no code that reads them, so setting
  them does nothing at all. Licensing behaviour on a genuine install is unchanged: the tier still comes
  only from the signed proof, exactly as before.

  Nothing to do on your side. If you are working on Muxit itself, `node muxit.js t` and the test suite
  are unaffected — both run development builds, where the overrides still apply.
- **Two labels printed at the same moment no longer come out with the same serial number.**
  `{{sequence}}` was read when a job started rendering but only moved on once that job had
  finished spooling, so a script and a dashboard button pressing print at the same moment both
  rendered from the same value and two physical labels claimed to be the same thing. A job now
  claims its range of serials when it is queued, so concurrent callers always get different
  ones. The counter could also move *backwards* — a batch of three finishing after a single
  label had already pushed it forward reset it below values that were already on labels — which
  is fixed by the same change.

  One deliberate consequence: a job that is rejected (queue full, `minIntervalMs`) or fails to
  spool keeps the serials it claimed, so the printed sequence can have gaps. A gap is a question
  the job log can answer; a duplicate is not.
- **The PSU and G-code example connectors and the TestDevice starter's `rampTemp` work with real values.** They combined driver reads without `await`, so the PSU's `power` read `NaN`, `rampTo` and `setOutput` worked on unresolved values, and the G-code `xy` string read `X:undefined Y:undefined`. Existing workspaces keep their own copies: add `async` to those getters and methods and `await` each `driver.` read, as the updated examples do.
- **Example connectors show real values again.** The webcam example's `resolution` showed `[object Promise]`, and the same mistake (combining driver reads without `await`) was in the TestDevice starter template's `summary` and `getInfo`, the ONVIF example's `isLive`, the label printer example's `ready` and a troubleshooting snippet. The Connectors guide now explains when a getter needs `async`/`await`.
- **Connectors can no longer reach files outside the workspace.** A File Access connector with an absolute `basePath` could read and write any folder on the computer, and e-mail attachments and webhook images accepted any file path. Every built-in driver that takes a path now only accepts paths inside the workspace — `..`, absolute paths and symbolic links that lead out are refused with `PATH_OUTSIDE_WORKSPACE`. A File Access connector whose `basePath` points outside the workspace now fails to load: move that folder into the workspace (for example under `data/`) and use a relative `basePath`. Python and C# drivers still run with full user rights. See [Workspaces → Files outside the workspace](https://docs.muxit.io/guides/workspaces.md#files-outside-the-workspace).
- **Muxit no longer accepts writes from another website, and the file editor can no longer be talked
  into reaching `config/`.** Three ways into the HTTP write surface are closed.

  **Cross-origin writes are refused.** Any page you visited in the same browser could send requests to
  `127.0.0.1:8765`, and they arrived looking like local traffic. Because the write endpoints read the
  request body directly, a page could use a content type that browsers do not pre-check, which meant
  `POST /api/startup-scripts` could plant a script that ran at the next start — from any site, with no
  credentials. Writes now have to come from Muxit's own pages. Tools that are not browsers — the CLI,
  MCP clients, Python — are unaffected, and reading is unchanged, so dashboards, images and the docs
  carry on as before. If you drive Muxit from your own web page on a different origin, those writes
  will now be refused; use the WebSocket API or the auth token instead.

  **The workspace routes needed no credentials at all.** `/api/workspaces` sat on an exemption list
  checked before both the local-only rule and the remote password, so with remote access on, anyone who
  could reach the port could list directories anywhere on the machine and create, switch, rename or
  remove workspaces. They are now behind the same authentication as the rest of the API. First-run
  setup is unchanged, since the workspace picker only ever runs locally. Operator stations are covered
  too: an operator can no longer switch the station's workspace out from under the dashboard it exists
  to show.

  **The file editor's `config/` and `drivers/` block can no longer be side-stepped.** The check ran
  against the path as typed, and the path was tidied up afterwards, so `scripts/../config/server.json`
  or `./config/server.json` slipped past it — enough to read the AI keys out of `server.json`, or to
  leave an `accounts.json` that granted admin at the next restart. Paths are now resolved first and
  checked afterwards, so every spelling of the same location is treated alike. Two actions that had no
  check at all — *Reveal in Explorer* and *Open with default app* — now have one, a folder next to the
  workspace can no longer be reached, and refusals return a proper "forbidden" instead of a server
  error. Starting a script by name is fixed the same way: a startup script can no longer name a file
  outside the `startup/` folder, and an operator-folder script can no longer point outside
  `operator/`.
- **The Label Printing page and the label designer no longer re-request printers, connectors, templates, fonts and images on every traced script line.** Both pages watched the whole server-state object, which changes on each line a running script executes, so a script under trace made them refetch several times a second — including the printer enumeration, which can be slow on CUPS. They now refresh on connect and on the broadcasts that actually mean something changed.
- **Label printer jobs no longer stay "in the spooler" forever on Windows with *Keep printed documents* on.** The driver only counted a job as finished when the spooler removed it, so a retained job kept `queueLength` inflated and its rendered pages in memory until the connector restarted. A job the spooler reports as printed now completes at the next status poll, and a job that neither finishes nor disappears is assumed printed after `trackedJobMaxAgeMs` (default 10 minutes) with the reason recorded on `lastJob`.
- **A label printer connector can no longer take the server down from its status poll, or leak a file watcher when it fails to load.** The spooler status poll runs on a timer; an error while it was reconciling tracked jobs (a job completing while the spooler was mid-update, a printer disappearing between two calls) escaped the timer callback, which terminates the process. It is now logged as `status poll failed` and the next poll carries on. Separately, a connector whose backend or printer configuration was rejected at load time left the template directory's file watcher running, one per failed load; it is released together with the backend now.
- **Label rendering can no longer be made to eat the server's memory or CPU from a template.** Five inputs had no bound: an inline image was decoded whatever its size (a few-KB PNG can expand to gigabytes), `pad:N` allocated N characters (`pad:1000000000` was a 2 GB string), a font size had no ceiling and the shrink-to-fit loop stepped down 0.5 pt at a time from it, the placeholder pattern could backtrack for minutes on an unterminated <code v-pre>{{a||||…</code>, and `labels.preview` shared the 50-per-second budget although each call is a full render. Images are now probed from their header and refused over 16 megapixels or 8 MB; `pad` caps at 256; font sizes above 500 pt and pages over 2000 mm fail validation; placeholder parsing has a timeout and a pattern that cannot backtrack; and previews get their own budget of 5 per second per connection (`security.rateLimit.previewsPerSec`).
- **A station whose license no longer covers its safety level now says that hardware control is off, and gets its level back by itself.** When the subscription ended, Muxit could not confirm the license, or the workspace moved to a lower tier, the safety level dropped to Observe — every write and action simulated, nothing reaching the hardware — while the chip showed a reassuring green "Observe" and nothing said why. Now a **Hardware control is off** banner appears under the status strip in the IDE, the operator view and the mobile view, with the reason and the next step (renew under Settings → License, check the internet connection, or ask an administrator); the chip turns amber and reads **Observe · license**; and the startup banner and server log carry the same warning. The level you chose stays saved and comes back on its own as soon as the license covers it again — which also fixes a paid station that had been switched off for more than a day, whose license is re-confirmed just after start, staying at Observe for the whole session. A license that is refused or deactivated while Muxit runs now drops the level straight away instead of at the next restart. `safety.get` and `safety.changed` carry the details as `licenseClamp`.
- **A hand-edited premium-driver license in the local license cache is no longer trusted
  indefinitely.** Muxit now checks these licenses when it starts: one that has never been
  validated, or claims to have been validated in the future, is discarded rather than kept
  until the license service can be reached. A genuine license always carries a real validation
  date, so this affects only edited files — or a machine whose clock is more than a year
  behind; if a premium driver license disappears there, correct the clock and enter the key
  again. (#577)
- **A damaged license cache no longer stops Muxit from starting.** An impossible date in the `.license` file's last-seen stamp (such as `0001-01-01`) made the license check throw before the server came up. It is now handled like any other date.
- **Deactivating a license now works while the license server is down.** Clicking Deactivate first asks the license server to free the activation slot. If that request timed out, or something in front of the server sent back an error page (a `502 Bad Gateway`, for example) instead of a license reply, Deactivate failed with an error and the license stayed on the machine. Now the license is removed from the machine either way, for the base subscription and for a standalone driver or feature license alike. If the server could not be reached, the slot on the server may still count as in use; you can free it from the customer portal.
- **Operator mode and user accounts now switch off when the license says so, not at the next restart.** Both gates were evaluated once at boot, so a station that stayed up past its 60-day downgrade grace kept operator mode and named sign-ins running while *Settings → Subscription* reported them blocked. The gates are now re-evaluated whenever the license state changes or is revalidated: on a tier that no longer covers them, sign-ins are ended and the server log says why; on a renewal they come back without a restart. Remote access and the audit log's grace warning are still decided at start-up.
- **The licensee's name and email no longer reach anonymous visitors or operators.** `license.get`, which the operator station and the sign-in screen call to show tier and grace state, returned the customer's name and email to every caller — including an anonymous browser on a locked station. Those two fields now appear only for callers the gate opens for: an ordinary install, or a signed-in admin or engineer. The tier, feature matrix and grace fields are unchanged.
- **License messages now show up in the server log.** Muxit logged why your tier is what it is, including when a license ran out, when it is running on downgrade grace and until when operator mode keeps working, and when the system clock is behind, but none of it reached the log viewer or `startup.log`. It now appears there under the `License` source; `--cli` and `--mcp` print it to stderr.
- **A license server that times out or answers with an error page no longer shuts Muxit down.** On a machine with a license key or a driver license, Muxit re-checks the license a minute after it starts and once a day after that. If the license server timed out, or something in front of it sent back an error page (a `502 Bad Gateway`, for example) instead of a license reply, the check failed with an error nothing caught, and the Muxit server exited. Now Muxit treats that the same as being offline: it could not confirm the license and tries again later. Your tier and driver licenses stay as they were, the other licenses are still checked, and the next check runs on schedule. A license is removed only when the license server answers that it is no longer valid.
- **Four ways of getting paid features for free are closed.** All four worked by editing
  something Muxit was trusting more than it should have been — the local `.license` file, the
  system clock, or a driver package's `manifest.json` — and none of them needed any
  cryptography to be broken.

  License expiry, downgrade grace, trials and the offline entitlement window are all now
  measured against a clock that cannot move backwards. Muxit keeps a high-water mark of the
  latest time it has ever seen on the machine and uses whichever is later, that or the system
  clock, so setting the clock back no longer restores something that had already run out. The
  old detector noticed the rollback but then overwrote the very mark it had compared against,
  so it worked exactly once. The mark now also advances on every start and every license
  re-check, which matters on a machine sitting offline in its 60-day grace period: nothing
  else would have moved it forward there. A clock more than a year behind the mark is treated
  as a broken real-time clock rather than a rollback, so a dead CMOS battery or a container
  with no RTC can't lock an install out of its own license. Detection no longer clears trials
  or validation stamps either — that bought nothing the comparison doesn't already cover, and
  on a machine whose clock was merely wrong it was wiping a paying customer's trials on boot.

  A trial's start date is now checked at both ends. A date in the future is tampering rather
  than clock skew, so `"2099-01-01"` in `.license` is no longer a trial that never ends;
  starting a trial re-confirms a future-dated entry against the trial ledger instead of
  trusting it, and discards it rather than handing out a fresh 14 days if the ledger can't be
  reached. Every trial is re-confirmed on the 24-hour license re-check, so an edited date
  lasts at most one cycle.

  Whether a driver is premium is now decided by its signature rather than by its manifest. A
  `.muxdriver` is a zip, and `manifest.json` inside it is plain text while the driver DLL and
  its signature are not — so relabelling a signed premium driver `"free"` used to skip the
  license check entirely while keeping everything the signature grants it. Muxit now derives
  that from the official signature plus the driver's verified ID, and a package whose manifest
  disagrees is reported as an error instead of quietly getting its way.
- **A paid tier now comes only from Muxit's signed license, never from the activation reply.** Activating a key used to unlock its tier straight from the license service's reply, which is not signed, so anything answering in its place could unlock any tier until the next restart. The tier now waits for the signed license Muxit fetches right after the key is accepted. If that fetch fails, activation says so, the key is kept, and Muxit stays on Free until a retry in the background or at the next start gets it.
- **A hand-edited license cache can no longer claim a paid tier.** Muxit is meant to take your tier only from the server-signed license proof, but when the local `.license` file held no license key it believed whatever tier the file named, and the daily license check (which needs a key) never corrected it. Without a valid signed proof the tier is now Free, whatever the file says. Activated installs are unaffected.
- **The status bar no longer says "Loading devices..." forever.** A browser tab opened or reloaded after Muxit finished starting never heard the one-time "server ready" signal, so the status bar stayed on "Loading devices..." even though everything was running. The server now tells every newly connected tab that it is ready.
- **The `login` visitor policy now covers the MCP endpoint.** Under `anonymous: "login"` an MCP client on the same machine could still write scripts and connector configs without signing in, because `/mcp` only refused callers on a locked station. It now admits only a caller who may author: an anonymous client gets `403 OPERATOR_SIGN_IN_REQUIRED` and must send an engineer's or admin's account token as `X-Muxit-Account`; a signed-in operator gets `403 OPERATOR_MODE_RESTRICTED`, as on a locked station. Under the default `full` policy nothing changes. The stdio MCP server (`--mcp`) is unaffected.
- **The mobile view can sign in, switch user and sign out.** The phone layout had no account controls at all: under the *Sign-in screen* policy a phone got the sign-in page and then no way to switch or sign out, and under *Everything* it could never sign in. The **More** tab now has an *Account* card with the same three actions as the desktop status-bar chip.
- **"New template…" on the Label Printing page no longer silently replaces an existing template of the same name.** It now asks before overwriting; and a preview that comes back empty is reported as such instead of as a script error.
- **Operator stations show their dashboard again instead of an empty screen.** Every station came up
  on a blank canvas titled "New Dashboard", with the message "No widgets — switch to Edit mode" — which
  an operator cannot do, because a locked station has no edit mode. Picking a different dashboard from
  the header changed the name but not the screen. The dashboard file itself was never touched, so
  turning operator mode off showed it intact.

  The shell was rendering the dashboard view before the file had finished loading, and that view reads
  its contents once when it first appears. It now waits for the file, and starts again from scratch
  when you switch dashboards.

  Two smaller things went with it. The editable dashboard-name box no longer appears on a locked
  station — it renames the file, which is not an operator's job, and it was showing "New Dashboard"
  while the header showed the real name. And a dashboard that genuinely has no widgets now says so
  plainly rather than offering advice that only applies inside the editor.
- **PIN sign-in now locks an account after repeated failures, from every address at once.** The only brake was five attempts a minute per source address — which a second address sidestepped, and which a successful sign-in reset, so anyone holding one valid PIN could guess at every other account indefinitely. After five wrong PINs an account (or an unknown id — probing them costs the same) locks for 30 seconds, doubling with each further failure up to 15 minutes; attempts during a lock are refused without extending it. The sign-in response reports `retryAfter` in seconds for either limit. The per-address limit stays and is no longer reset by a successful sign-in.
- **A slow printer enumeration no longer freezes a label connector or the script that touches it.** On CUPS, listing printers runs several `lpstat`/`lpoptions` processes per printer with a five-second timeout each, and the driver ran that synchronously with no cap — from connector start-up and from a script setting `printer` — so an offline network printer could stall both for a minute or more, while the Tools page built its backend under a lock everything else waited on. The driver now enumerates once at a time, caches for 30 seconds, and waits at most 20 seconds before answering with the last known list while the enumeration finishes in the background; the Tools page builds its backend outside the lock.
- **Remote-access login no longer hands out the server's startup token, and an ended session now disconnects.** `POST /api/auth/login` used to return `{ token, sessionToken }`, where `token` was the startup token — valid until the server restarted, so neither a password change nor a logout could lock out a browser that had signed in once. It now returns only `{ sessionToken }`, which works everywhere the old token did (`X-Auth-Token` on HTTP, the `auth-<token>` WebSocket subprotocol) and ends on logout, on a password change and after 24 hours. A WebSocket opened with it is then closed with code `4401`, and the web UI goes straight back to the login page. **If you wrote a remote client** that read `token` from the login response, read `sessionToken` instead.
- **An unplugged or powered-off SCPI instrument no longer stalls the whole server.** Queries are serialized per instrument, so a silent device used to cost the sum of its properties' timeouts on every poll cycle — a 5-property supply at the default 5 s timeout blocked the wire for 25 s at a time, and reloading or disabling the connector appeared to hang behind it. A device that misses two replies in a row is now marked unreachable and later queries fail instantly until a probe (every `unreachableRetryMs`, default 5 s) gets an answer and normal polling resumes. A single late reply still doesn't mute the connector. Shutting a connector down also no longer waits out an in-flight read that can't be cancelled, so disabling or reloading a dead device is immediate.
- **Account PINs, the access password and the license cache are no longer world-readable on Linux and macOS.** `workspace/config/accounts.json` (PIN hashes and salts), `workspace/config/security.json` (the remote-access password hash) and the license cache and proof files were written with the default file mode, so on a shared machine any local user could read them; only the `.auth-token` file was owner-only. All of them are now created with mode `0600`, and a file left behind by an earlier version is tightened the next time it is written. Nothing changes on Windows, where the workspace directory's ACLs apply.
- **Settings is regrouped and quieter.** Every tab now reads the same way: each topic is one
  bordered panel, and its sub-topics sit inside it — access password and how-to-connect under
  Remote Access, status under Network Discovery, authentication under MQTT Broker, usage and plan
  comparison under Current Plan, the three client set-ups under MCP's Connect a client, idle
  timeout under Accounts. Previously a topic and its own sub-topics were separated by the same
  faint rule, so nothing read as belonging to anything. Network diagnostics no longer audits the
  firewall and interfaces every time the Server page opens: nothing is collected or shown until you
  press **Run diagnostics**. Long dropdowns and text fields no longer spill past the edge of the
  group that holds them, and the plan comparison scrolls instead of hiding its last column in a
  narrow window. The Operator Station group is gone from Server; the start-dashboard choice lives
  under **Settings › Accounts › Operator dashboards**, next to the policy that turns a station into
  an operator station, and the AI chat switch became the per-dashboard **Operator chat** setting. (#556)
- **Changing a PIN or the remote-access password now signs out whoever was using the old one, and a sign-in expires after 12 hours however busy it is.** Giving an account a new PIN used to leave its existing sessions running under the new name; changing the remote-access password kept every remote session alive (removing it already ended them). A renamed or re-roled account keeps its sessions, as before. Sessions also had no ceiling — a busy socket could hold one open indefinitely past the idle timeout — so they now end 12 hours after sign-in regardless.
- **What anonymous visitors get is now stated where it matters, and asked about once.** Creating
  accounts leaves the anonymous-visitor policy on its default, *everything* — anyone at the machine
  keeps full access whether or not they sign in, and signing in only adds a name. That is
  documented, but nothing said so at the two moments it counts: right after the first admin is
  created, and next to the Sign out button. So it was easy to set up accounts to keep people out,
  press Sign out, and find nothing had changed.

  After you create and sign in as the first admin, Settings › Accounts now asks once what someone
  who is not signed in should get — everything, the dashboards only, or a sign-in screen — with the
  consequence of each answer spelled out. The Anonymous visitors group states the current effect in
  one line above the dropdown, and the account chip's popover says next to Sign out what signing out
  will do under the current policy. The default has not changed.
- **A setting that could not be saved no longer reports itself as saved.** Every write to
  `config/server.json` caught its own failure and carried on — the in-memory copy had already
  changed, so the UI got the new value back and showed the change as applied while the file on
  disk was untouched, and the setting reverted at the next restart. A full disk, a read-only
  workspace or a permissions problem all looked like success. Failed writes are now reported to
  whoever asked for the change.

  The clearest case was creating a printer connector from the Label Printing page: it reported
  "connector created" and then showed no printer, because the step that adds the connector to
  `connectors.enabled` reported a failed write the same way it reports "there is no enabled list,
  so nothing needs adding". Those two are now told apart, and the page says the file was written
  but could not be enabled.

  Two places deliberately still carry on after a failed write, and now say what is lost: the
  safety gate keeps a level change active for the session and warns that it will revert at
  restart, and renaming a connector completes the rename and warns that the new name is
  disabled until the enabled list is fixed.
- **A rebuilt UI now actually appears instead of the browser re-loading the previous build.** Muxit
  served `index.html` with no `Cache-Control` header, so browsers applied heuristic caching — roughly
  10% of the file's age — and reused a stale copy for hours without revalidating. Because
  `index.html` is what names the content-hashed JavaScript bundles, a cached copy kept requesting the
  *old* bundle: you would update or rebuild, reload the page, and quietly get the previous version
  with nothing to indicate why. `index.html` is now served `no-cache` so it revalidates on every load
  (cheap — its ETag turns that into a 304), while everything under `/assets/` carries a content hash
  in its filename and is cached for a year as immutable.
- **The example test-device connector shows real values again.** In new workspaces its `summary` property read `[object Promise]: [object Promise]°C` and `isHot`, `tempDelta`, `arrayLengths`, `getInfo` and `rampTemp` worked on unresolved values. Reading a driver property inside a connector returns a Promise, and the example now `await`s it. Existing workspaces keep their own copy of `connectors/test-device.js`; create a new workspace, or add `async`/`await` to those getters, to get the fix.
- **Connector JS can no longer switch off the rule that stops it reaching the internet.** A
  connector or JS driver gets `createTcpTransport()` from a sandbox, and that transport is
  meant to be limited to the local network — loopback plus the private address ranges — unless
  you say otherwise. The object enforcing that limit was handed to the sandbox with the limit
  itself as a writable field on it, so a connector could turn it off in one line and then open
  a socket to any host on the internet. It is now fixed when the sandbox is built and not
  reachable from script at all.

  **The two ways to allow an external host now exist.** The error from a blocked connection has
  always told you to add the host to a connector's `allowedHosts` or set
  `security.allowExternalTransports` — and neither was read by anything, so following the advice
  did nothing. Both work now. `allowedHosts` is a top-level array in a connector file and applies
  to that connector alone, adding named hosts without lifting the private-network restriction;
  `security.allowExternalTransports` in `config/server.json` allows every host server-wide and
  logs a line at startup saying so. A hostname is never treated as private however local it
  looks — Muxit does not resolve names to decide, so `nas.local` needs to be listed.
- **Settings → Accounts now asks before switching anonymous visitors to *Dashboards only* or *Sign-in screen*.** Both change what every browser on the server sees, immediately and without a restart, and the select applied them on the spot. It now spells out the consequence and asks; and when *Dashboards only* is chosen on a station with no dashboards under `dashboards/operator/` yet, it says so next to the setting rather than only in the panel below.
- **`muxit.exe` now carries the Muxit icon on Windows instead of the generic blank one.** The executable had no Win32 icon resource, so Explorer, the taskbar, Alt-Tab, the window title bar and the Start Menu shortcut all fell back to the default .NET placeholder. The logo is now embedded at every size the shell asks for (16 through 256), so it stays sharp from the Explorer list view up to the Start Menu tile and at any display scaling. The exe's **Properties → Details** tab, Task Manager and UAC prompts now read `Muxit` rather than a bare lowercase `muxit`, and the installer pins the shortcut's icon explicitly so an upgrade over an older install doesn't keep serving the stale cached one.

## v0.42.3 — September 10, 2026

### Bug Fixes

- **Switching workspaces, restarting or updating no longer opens a second browser tab.** The server respawned after a switch/restart/update auto-opened the browser again as if it were a fresh launch, while the original tab was still waiting and reloading itself. The relaunched process now knows it is a relaunch and stays quiet. The waiting page also no longer reloads onto a server that is up but still booting (which showed the first-run "open/new workspace" screen), and a tab that lands on an unreachable server shows *Could not connect* and retries by itself instead of the first-run setup.
- **In-app update now replaces the whole install, not just the launcher.** On Linux and macOS the `muxit` binary is only an apphost — the version and all code live in `muxit.dll` and its sibling assemblies — so *Help → Check for Updates…* downloaded and "installed" the new release but restarted onto the old one (still reporting the previous version). Every file the release ships (binary, runtime assemblies, `wwwroot/`, `workspace-template/`) is now copied over the install directory with a full rollback on failure; the user's `workspace/` is never touched. The previous version is parked in `.muxit-update-backup/` and cleaned up on the next start.

## v0.42.2 — September 10, 2026

### Bug Fixes

- **Creating and opening workspaces from the UI actually switches to them.** Every HTTP `POST` endpoint used by the workspace dialogs (create, open, switch, rename, remove, new folder) — and the same-shaped `POST /api/scripts`, `/api/startup-scripts`, `/api/connectors` and `/api/eula/accept` — answered "200 OK" with an empty body regardless of outcome, because the handlers' results were discarded by the way they were registered. The work itself (files written, catalog updated) happened, but the client never received the reply: **Create & Open** in the workspace dialog got no `path` back, sent a switch request for an empty path, was told "OK" again, and reloaded into the *old* workspace — which is why a new workspace appeared to be created but never opened. Validation errors were likewise hidden as success. All ten endpoints now return their real result and status code.
- **Workspace names no longer reset to "Default" on restart.** Since v0.42.0 the boot-time workspace self-repair re-registered the active workspace in the catalog under the placeholder name "Default", so a name chosen in **New Workspace…** or **Rename Workspace…** was overwritten the moment the server restarted into it — and a switch to a freshly created workspace looked as if it had failed because the title bar still read "Default". Boot-time setup now only adds a workspace to the catalog when it is missing and never renames an existing entry.
- **Switching workspaces waits for the server to come back before reloading.** The workspace dialog, first-run setup, workspace picker and the title-bar **Switch to** list all reloaded the page on a fixed two-second timer. When the restart took longer (driver scans, license checks, antivirus) the browser landed on its own "connection refused" page and the switch appeared to have failed. The page now polls until the new server answers for the target workspace (or the new origin accepts connections when the port changes) and only then navigates, showing progress in the meantime. The self-relaunching server also releases its instance-slot and workspace locks before starting its successor, so a single-slot tier can't refuse the new process while the old one is still exiting.

## v0.42.1 — September 9, 2026

### Bug Fixes

- **No more microphone permission prompt at startup.** The chat panel used to request mic access on load just to label the input-device dropdown, so every fresh install was greeted by the browser's microphone dialog. Mic access is now requested on the first voice interaction (mic press, voice dropdown, or wake word) and never if you don't use voice. Declining no longer leaves a permanent "Microphone access denied" error in the chat header.

## v0.42.0 — September 5, 2026

### Features

- **Update checks now go through api.muxit.io, and show release notes.** The daily
  check asks the Muxit proxy instead of GitHub, so it no longer competes for
  GitHub's 60 request/hour per-IP limit — which could silently stall update
  discovery for anyone behind a shared corporate NAT. The answer carries the
  release notes, surfaced on `update.status` as `releaseNotes`. If the proxy is
  unreachable the check falls back to GitHub exactly as before, so an outage can
  never hide a security fix.
- **Editor mode is now on by default.** A fresh install can create and edit connectors, scripts and dashboards — and use the immediate window — without hand-editing `server.json` first. Set `security.editorMode` to `false` for a read-only workspace.

### Bug Fixes

- **Dev runs seed example content like a real install.** `workspace-template/` was only looked for next to the binary, so a workspace created by `node start.js server` from a checkout came up empty. It now also resolves the repo-root copy.
- **Say where `server.json` actually is when editor mode is off.** The file explorer notice now prints the full path to the workspace's `config/server.json` and points at the new **Settings › Server › Editor Mode** toggle; the immediate window replies with that same guidance instead of the meaningless "Not implemented yet: scripts.execute".
- **The "Include example content" checkbox is visible again.** In the new-workspace dialog and the first-run setup screen the checkbox could shrink to nothing beside its label, and native controls were being drawn in light mode on the dark dialogs. Both dialogs now declare a dark color scheme and give the checkbox a fixed size.
- **The tray icon is found in single-file builds.** Its path was resolved from `Assembly.Location`, which is an empty string for a single-file publish, so the icon was looked up relative to the current working directory and the tray was skipped outright when Muxit was launched from anywhere else.
- **The Linux tray dependency check named the wrong library.** The tray's native library links against `libappindicator3.so.1`, but the startup probe and `install.sh` looked for (and installed) `libayatana-appindicator3-1`, which does not provide that soname — so the check reported the tray as fine while it stayed broken, and following the suggested fix changed nothing. Both now use the soname the loader actually asks for.
- **"System tray not available: Native support not found for platform" now says what is actually wrong.** The message came from NotificationIcon.NET, which wraps *any* failure to load its native library in that one line — so a library that is present but can't load, because a dependency of *it* is missing, reported the same thing as an unsupported platform. On Windows that dependency is `VCRUNTIME140.dll` from the Visual C++ Redistributable, which a clean Windows image (Windows Sandbox especially) does not have. Muxit now distinguishes "missing from this build" from "present but unloadable", names the path it tried, passes on the loader's own reason, and — on Windows — links the redistributable. `install.ps1` installs the runtime, so a fresh install gets a working tray.
- **A half-built workspace now repairs itself instead of staying broken forever.** Muxit only seeded a new workspace when it looked entirely absent, and any `config/` folder — including the one the server writes its own product-config cache into — made it look complete. A fresh install whose first run was interrupted was left with no connectors, no scripts and no `server.json` (which is what silently disabled editor mode), and every later start skipped the setup again. The layout is now checked on every start: missing folders are recreated and a missing `config/server.json` is written. Example content is still copied at most once, recorded in `.muxit/seeded.json`, so files you delete stay deleted and declining "Include example content" is remembered.

## v0.41.5 — September 4, 2026

### Bug Fixes

- **Loose Python drivers can now import `muxit_driver` on a released build.** A
  hand-written `.driver.py` dropped straight into `workspace/drivers/` failed to
  load with `ModuleNotFoundError: No module named 'muxit_driver'` — the SDK was
  only reachable from a source checkout or vendored inside a packaged
  `.muxdriver`. The SDK now ships alongside the server as `python-sdk/` and is
  put on every driver subprocess' `PYTHONPATH`, so a loose driver file works the
  same as a packaged one. When the import does fail, the server log now names the
  path it expected instead of just relaying the Python traceback.

  Running a driver by hand outside Muxit is covered too: `pip install -e
  drivers/py` (or `PYTHONPATH=drivers/py`) makes `python3 mydriver.driver.py
  --scan` work from any directory.

## v0.41.4 — September 3, 2026

### Bug Fixes

- **The Activate License panel now points at muxit.io/buy.** It no longer promises trial keys from a "Muxit store" that does not exist; it names the Polar order e-mail as the source of the key.
- **Closed an offline tier-escalation hole in the unsigned `.license` cache.** Hand-editing `BaseTrialStarted` / `TrialDays` into the local license file used to switch on a phantom "base trial" that reported Pro and bypassed the tier gate entirely (including Lab-only features). The base-trial concept is removed: tier now comes only from the RSA-signed `.license-proof`, and trial length is a compile-time constant that the file cannot inflate. Per-feature driver trials are unaffected. The `license.get` payload no longer carries `isBaseTrialActive` / `baseTrialDaysRemaining`, and the CLI's `license trial` now requires a feature id.

## v0.41.3 — August 20, 2026

### Bug Fixes

- **Dummy test fragment.** Placeholder entry for exercising the revision consolidation pipeline.

## v0.41.2 — August 19, 2026

### Bug Fixes

- **Routine maintenance release.** No user-facing changes beyond internal fixes and dependency upkeep.

## v0.41.1 — August 19, 2026

### Bug Fixes

- **Routine maintenance release.** No user-facing changes beyond internal fixes and dependency upkeep.

## v0.41.0 — August 17, 2026

### Features

- **AI image analysis is now a Maker feature (was Pro).** Makers can attach a camera frame to the script global `ai(prompt, snapshot)`, and the Chat Panel / MCP `take_snapshot` tool now works on Maker and above. Pro still leads on vision through the premium Vision engine (object detection, teach-by-example, calibration, servoing), plus unlimited connectors and the advanced Safety levels. Free-tier `ai(prompt, image)` calls are now correctly blocked — previously the script path skipped the image-analysis gate entirely. The Settings → Subscription plan-comparison rows now link to a new [Subscription & Plans](https://docs.muxit.io/reference/subscription-plans.md) reference page.

### Bug Fixes

- **The chat model picker now refreshes immediately when you switch AI providers in Settings.** Changing the provider (e.g. Muxit AI → Ollama) in **Settings → AI Services** used to leave the Chat panel's model dropdown showing the previous provider's models until a reload; it now updates live in the same browser.
- **The download page now stacks the platform installers vertically and reads better on mobile.** Windows, macOS, and Linux are laid out one above the other (no more cramped three-column row), each install one-liner is introduced with a "copy this line and paste it into PowerShell / Terminal" hint, and long install commands wrap instead of overflowing on narrow screens.
- **Offline devices no longer stall startup and connector reloads.** Connectors initialize sequentially, and each one used to wait up to 5 seconds for its first poll before the next began — so a connector whose device was powered off (or unresponsive) added ~5 s of dead time to server startup and to every connector reload, multiplying with the number of offline devices. Init now waits only a brief grace window for initial values: healthy devices still populate immediately, while offline ones return right away and stream their values in later as they respond. Steady-state polling, backoff, and error suppression are unchanged.
- **Windows no longer opens a console window on launch.** The Windows build is now a GUI-subsystem app, so starting Muxit from the Start Menu shortcut or by double-clicking `muxit.exe` runs quietly behind the tray icon — there's no terminal window to accidentally close (which used to kill the server). Logs remain available in the browser at `/logs.html` and via the tray's **View Logs**. Running `muxit` from a terminal still prints output there, and `muxit --version` / `muxit eula` / `muxit --cli` work as before.
- **The AI Services settings panel is reorganized into two clearer sections.** **Chat model** and **Scripts & tools model** now each read as a matching *provider → model* pair instead of a standalone provider picker followed by a model-only field. The model favorites list is renamed **Chat model favorites** and only offers Muxit AI (cloud) models — local providers (Ollama, LM Studio) already list their loaded models automatically, so favorites don't apply to them.

## v0.40.0 — July 16, 2026

### Breaking Changes

- **Avantes spectrometer: output precision setting, leaner `measure()`, and a full colour-rendering array.** A new `significantDigits` config option (default 4) rounds all numeric output. `measure()` now returns only `{ isSaturated, peakCounts, integrationTime }` — read derived metrics (`cct`, `cri`, `illuminance`, `ppf`, …) as properties on demand. The standalone `r9` property is removed; the special indices R1–R14 are now exposed together as the `colorRendering` array (R9 at index 8).
- **The standalone SerialProbe driver has been retired — the AI now probes serial devices itself.** Reverse-engineering an unknown serial device no longer means adding a `SerialProbe` connector. The built-in device-setup flow ("+ Add device" in the Connectors panel) drives the probe directly through the AI's transport tools — it opens the port, pokes silent devices, classifies the framing, and drafts a declarative `LineText` / `BinaryStream` connector for you to confirm. Existing `SerialProbe` connectors will no longer load; recreate them through the device-setup flow, which produces a normal protocol connector instead.

### Features

- **New `/prompt` command shows the AI system prompt and its size.** Type `/prompt` (optionally with a message, e.g. `/prompt turn the power supply off`) in the chat panel to inspect the exact system prompt the next turn would send — without calling the model. The inspector card breaks the prompt down by section and by connector, lists the active tool groups and tools, and warns in red when the prompt exceeds the provider's 32 000-character `system`-field cap (which otherwise fails the request upstream with a `validation_error` before it's billed, leaving no ai-tokens log line). Use it to find which connector or fragment is driving the prompt over budget. Backed by the read-only `ai.debugPrompt` WebSocket message.
- **The Avantes spectrometer exposes an `idle` property.** It reads `true` when the device is idle and `false` while a measurement (measure, dark reference, auto integration time, or streaming scan) is in progress — useful for busy indicators and for gating automation steps until acquisition finishes.
- **Chart widgets can now plot array-valued bindings as XY curves.** When a chart's bindings resolve to arrays (e.g. a spectrometer's `spectrum` or `irradiance`), the widget draws each array as a full curve instead of a rolling time-series, using the new optional `xBinding` field as the X axis (falling back to the sample index when omitted). Scalar bindings keep the existing auto-scrolling time-series behaviour, so existing dashboards are unaffected.
- **The desktop Hardware panel can now edit writable properties and run actions inline.** Expand a connector and click a property value to set it (booleans get a true/false dropdown), or hit the ▶ run button on any action — parameterless actions fire on click, and ones that take arguments pop a small inline form. This brings the regular view to parity with the mobile UI, and drag-to-script still works on every row.
- **Device setup is now a dedicated, explicit AI flow — and normal chat got much cheaper.** Adding a new device is started from the Connectors panel ("+ Add device"), which opens the chat in a focused device-setup mode — the probe/compose/config tools plus the core device tools, so it can probe the device, write the connector, hot-reload it, and test it end to end (read values back, set a value, run reset/self-test) — without the script/agent/dashboard tooling that bloats normal chat. Normal chat no longer infers device-authoring from keywords — saying "turn the power supply off" operates your existing supply instead of loading ~18 KB of onboarding guides (and getting stuck loading them for several turns). The per-turn system prompt also shrank: the tool-confirmation rules were condensed (~6.6 KB → ~2.5 KB), the script list is now shown only when scripts are relevant and capped, and the decision-tree guidance was trimmed. The AI is also clearer that a FileAccess connector is required to write data files. Use `/prompt` to see the savings.
- **Muxit now runs on macOS (Apple Silicon and Intel).** Self-contained
  `osx-arm64` and `osx-x64` builds, in-app self-update, and an installer that
  handles the Gatekeeper quarantine for you. Cameras work: the TestDevice video
  stream, USB webcams, and Onvif/RTSP cameras all stream and snapshot (capture
  goes through the system `ffmpeg`; image work uses SkiaSharp), and the AI vision
  layer works over those frames. Not available on macOS yet: video recording and
  the optional Vision detection driver (both depend on OpenCV, which has no macOS
  runtime), and builds aren't notarized. Everything else — SCPI/serial/USB
  instruments, scripts, AI, dashboards, MQTT, Python drivers — works the same as
  on Windows and Linux.
- **Updates now install themselves from the Help menu.** *Check for Updates…*
  downloads the new release, installs it in place with a live progress bar, and
  restarts onto the new version automatically — the page reconnects on its own.
  Your workspace is preserved. Works on Windows x64 and Linux x64/arm64; other
  platforms still get a download link.
- **Homepage now leads with the real app and drives the free download.** Reframed the landing page around trying Muxit Free now: added a real screenshot of the running app, removed redundant sections, and made "Download Free" the primary call to action.
- **Payments and billing now run through Polar (polar.sh).** Polar Software, Inc. is
  Muxit's Merchant of Record for all subscriptions and AI-credit purchases; the Terms &
  License Agreement and Privacy Policy have been updated to name Polar as the seller and
  payment sub-processor. Paid-plan users (Maker, Pro, Lab) also get a **Top up AI credits**
  link in Settings → Subscription → AI Service that opens the Polar checkout.
- **Vision is now a fully self-contained engine.** All vision intelligence — AI object identification, location, teach-by-example, pixel→world calibration, and visual servoing — has moved out of the core server and into the Vision engine driver, which carries its own LLM-vision logic and persists learned objects + calibrations under its own state directory. The AI reaches these through the generic device-control tools (e.g. `call_action(vision, identifyObjects)`, `read_property(vision, detections)`); the only dedicated core tool that remains is the camera-agnostic `take_snapshot`. Taught objects now correctly restore their trackers on restart. Driver authors gain a new host AI capability (`IDriverHost.AiAsync`) and a per-instance state directory (`IDriverHost.StateDirectory`).

### Bug Fixes

- **Avantes: corrected the UV photon-flux helper and made the Planckian-locus distance (Duv) accurate.** The `SpectralMath.PFx4()` convenience helper integrated 400–500 nm — identical to `PF45()` — instead of the sub-400 nm UV band; it now integrates 300–400 nm to match its name (the driver's cached UV metric already used the correct range, so reported measurements are unchanged). The `Duv` used to gate CCT and CRI validity is now the true perpendicular distance to the Planckian locus (densely sampled, refined by segment projection) rather than a coarse nearest-of-51-samples estimate, so valid near-locus sources are no longer wrongly rejected near low colour temperatures.
- **Avantes spectrometer now connects on USB-only hosts and `connect()` works without a prior `discover()`.** The driver previously always initialised the SDK with both USB and Ethernet back-ends; on machines where the Ethernet back-end errors (`ERR_COMMUNICATION`), this failure was silently swallowed and `discover()` returned an empty list. The driver now initialises the back-end matching the configured `connectionType` (USB-only by default), falls back across ports, and logs init failures instead of hiding them. `connect()` also refreshes the device list internally and attaches to the first available unit when no serial is given.
- **Clearer device-connection model across the site and docs.** Protocols (Scpi, LineText, BinaryStream), Drivers, and Transports are now consistently distinguished: a Protocol rides on a Transport and is configured declaratively in a `schema:` block; a Driver is a turnkey backend that owns its own connection. The marketing "How it works" and compatibility pages were rebuilt around this model, the stale "generic SCPI driver" framing is gone (SCPI is the built-in `Scpi` protocol), and the declarative protocols (SCPI, text-line, and binary) are now presented as one AI-draftable tier.
- **Vision is a premium extension, not a bundled Pro feature.** Pricing, docs, and the in-app plan comparison now keep two things distinct: **AI image analysis** (the AI seeing a camera frame — `take_snapshot` and `ai(prompt, image)` against Muxit-managed) is the core Pro-tier capability, while the **Vision engine** (real-time object detection, teach-by-example, calibration, and visual servoing) is a separately-licensed premium extension installed from the marketplace on Pro and above. The Settings → Subscription comparison row formerly labeled "Vision AI" is now "AI image analysis".

## v0.39.0 — June 2, 2026

### Features

- **AI chat now shows a clickable link to files it creates.** When the assistant
  writes or updates a connector, script, startup script, or dashboard, a 📄 file
  link appears under the reply — click it to open the file in the editor pane
  (dashboards open in the visual editor). The link is derived from the tool result,
  so it shows up for any file the AI actually saved.

### Bug Fixes

- **Driver docs realigned with the Protocol/Transport/Engine model.** The Driver SDK and Marketplace pages now point you to built-in Protocols (`Scpi` / `LineText` / `BinaryStream`) + AI authoring as the default path for custom hardware, and reserve the SDK for vendor-SDK / native / Python-only cases. Fixed stale manifest fields (Python `tier: 2`, required `category`, `minimumServerVersion`) and clarified first-party vs. third-party driver scaffolding.
- **Confirming an AI-written script no longer re-sends the whole script.** When AI confirmation is on, the assistant used to generate a script's full source twice — once to propose it and again, with identical arguments, to confirm it — which roughly doubled the token cost of authoring a script. The assistant now approves the parked action by reference with a tiny `confirm_action` call, so the source travels through the model only once. The user-facing flow is unchanged: the assistant still summarizes what the script will do and waits for your "yes" before anything runs.
- **The AI assistant now stays on track when setting up serial devices that aren't SCPI instruments.** Multi-turn onboarding flows (unplug-plug port detection, baud discovery, manual probing) no longer lose the device-setup tools partway through, so the assistant stops inventing nonexistent tools like `probe_serial`. When `discover_serial_device` can't identify a device it now falls back to observing and poking the wire (`read_from_transport`, `probe_stimulus`, `analyze_binary_frame`) instead of forcing a SCPI guess. Temperature loggers, thermocouples, thermistors and RTDs also reliably trigger the device-setup flow now.
- **Dashboard and CSV chart labels now follow the active theme.** Axis,
  tick, grid and legend colors were drawn onto uPlot's canvas with CSS
  variables (which canvas ignores) or a hardcoded white, leaving labels
  nearly invisible — black-on-dark for live charts, white-on-white on light
  themes. Charts are now fed theme-resolved colors that re-render on theme
  switch, so labels stay legible across every light and dark palette.
- **Live terminal output now works for the G-code, plotter, and serial-monitor connectors.** These JS drivers emitted their `output` stream through an unassigned `this._streamEmitter`, so the stream silently did nothing; they now use the host's `__emitStream` global like the serial-probe driver. Terminal widgets bound to these connectors show incoming lines again.
- **ONVIF PTZ moves are now locale-safe and range-guarded.** Coordinates
  were serialized with the host's current culture, so on a comma-decimal
  locale (e.g. `nl-NL`) a value like `0.5` rendered as `0,5000` and the
  camera rejected the move with a `BadRequest` SOAP fault. Coordinates now
  always serialize with an invariant `.` separator. In addition, `ptzMove`
  and `ptzMoveAbsolute` now clamp each axis to `[-1, 1]` (with a warning)
  and reject non-finite values (`NaN`/`Infinity`) before the request is
  sent, so a stray pixel/degree coordinate or a divide-by-zero in caller
  math no longer faults the camera.
- **Serial-device probing now logs its progress and returns far leaner results to the AI chat.** The baud/terminator sweep (`discover_serial_device`) and the stimulus sweep (`probe_stimulus`) both emit live progress to the server log — per-baud milestones and per-stimulus heartbeats — so a long-running probe no longer looks frozen. The stimulus sweep's chat result is also much smaller: instead of echoing every one of ~85 tried candidates (most of them "sent X, heard nothing"), it now reports only the candidates that actually drew a response or errored, and collapses the silent ones into a count. The common "tried everything, found nothing" case drops from dozens of empty rows to a couple of fields.

## v0.38.0 — June 1, 2026

### Features

- **`ai()` can now compare several images in one call.** Pass an array as the second argument — bare base64 JPEGs or `{ image, label }` objects (up to 8) — to ask the model *"what changed?"* (before/after) or *"is this like reference A or B?"*. Labels are sent as text right before each image so the model can refer to them by name. Reference images can be loaded straight off disk with the FileAccess driver's `openBinary(path).read()`. The single-image form is unchanged.
- **Help menu now has a "Check for Updates…" item.** Queries the existing update endpoint and tells you whether Muxit is current; if a newer release is on GitHub, it offers to open the download page.

### Bug Fixes

- **Public docs corrected and de-leaked.** Getting-started now installs the binary
  release instead of building from source, references to the internal repository
  were removed, and stale platform / .NET-version notes, broken example-file
  references, and a dashboard example were fixed.

## v0.37.0 — May 30, 2026

### Features

- **The AI chat panel now honors per-connector `safety.confirm` overrides.** Mark a property or action `never` (e.g. a camera's `pan`/`tilt`) to stop the assistant prompting before it, or `always`/`typed` to force a prompt even for a no-argument action — a single `safety.confirm` entry now governs both the connector-layer gate and the AI chat-gate.
- **AI: lower token cost per chat turn.** Conversation history is now capped at 12 user turns (configurable via `ai.historyMaxTurns`) so long chats no longer grow without bound, the device-onboarding tool descriptions ship a one-line summary with the full I/O shape on demand via `read_doc('reference/ai-tools.md')` (-31% on the prompt's tool-description block), and every LLM call is now recorded to `workspace/logs/ai-tokens-YYYYMMDD.jsonl` with input/output/cache token counts so further savings can be measured. Device schemas in the system prompt now default to a one-line summary per connector — the AI calls `get_connector_schema` on demand — and switches to full inline schemas when the user's turn looks like a device interaction; force one mode with `ai.deviceSchemas` = `"full"` / `"minimal"`. Default `ai.maxTokens` drops from 4096 to 2048 (raise it in config for code-heavy flows). New `ai.cacheBreakpoints` (default off) attaches Anthropic `cache_control` markers to the system prompt for the cloud proxy — flip on once your proxy is confirmed to forward them.
- **Added a driver for the Digilent Analog Discovery 2 and 3.** Tier-2 Python driver covering oscilloscope (single-shot + continuous streaming), arbitrary waveform generator, ±5 V power supplies (programmable voltage on AD3), and 16-line static digital I/O. Requires Digilent WaveForms installed on the host; `pydwf` is fetched into the driver's venv automatically on first activation. See `docs-site/reference/drivers/digilent-analog-discovery.md`.
- **Python connectors now have their own console tab in the bottom panel.** As soon as you activate a Python connector, a 🐍 tab appears showing live output from the subprocess — pip install lines, stderr, `driver.log()` calls, and exceptions, with full transcript preserved (last 500 lines per connector). The tab's input line is a REPL against the running driver: type `_state` or `model.sr` and Enter to evaluate it inside the subprocess and see the result inline. The connector status badge now mirrors pip / model-download progress instead of freezing on "Initialising driver...", and the init RPC tolerates multi-minute installs (timeout bumped to 30 minutes) so the chatterbox-tts example no longer trips when torch is downloading.
- **The titlebar now has a dedicated `Workspace: <name>` menu.** Replaces the static workspace label that just said "workspace" when your workspace folder was called `workspace/`. The menu shows the active workspace name as its label and contains a rename action, an inline list of other workspaces in your catalog (one-click switch, no dialog), and entries for opening or creating workspaces. The old File → New/Open Workspace items have been moved here so all workspace operations live in one place. Renaming updates the catalog only — your folder on disk is not touched and no server restart is needed.

### Bug Fixes

- **AI token log: record `cache_creation_input_tokens` on the OpenRouter path.** The per-request JSONL line at `workspace/logs/ai-tokens-YYYYMMDD.jsonl` previously always reported `cacheCreationInputTokens: null` because the OpenAI-compat usage parser only looked at `prompt_tokens_details.cached_tokens` (cache reads). OpenRouter passes Anthropic's native `cache_creation_input_tokens` through verbatim on its OpenAI-compat response, so we now pluck it on the same code path as the read counter. No behavior change for the Anthropic-native path or for providers without prompt caching.
- **Editor toolbar icons no longer disappear on light themes, and the immediate window survives runtime errors.** The script/dashboard toolbar's default icon colour was hard-coded white, leaving undo/redo/save invisible against light backgrounds — it now follows the theme. The immediate window was crashing the bottom panel when a command threw, because it tried to render the structured `script.done` error payload directly; it now formats the error (with line/column where available) and prints it like any other output line. Collapse chevrons across the Scripts, Dashboards, Hardware, Script API and Object Viewer panels switched to a larger glyph (▶/▼) so they're actually visible.

## v0.36.0 — May 26, 2026

### Features

- **AI can detect which COM port your instrument is on, by itself.** When you tell the AI you don't know which serial port your device is on, it now runs an **unplug-plug detection** flow: snapshot the current ports, ask you to unplug the device, snapshot again, ask you to plug it back in, snapshot a third time, and the new port that only appeared on the third snapshot is your device. Works on Linux, macOS, and Windows. The `list_serial_ports` tool now returns objects with a `friendlyName` field (populated from `/dev/serial/by-id/` on Linux/macOS) so the AI can also recognise the right device when several USB-serial gadgets are plugged in at once.
- **The AI can now poke a real device before committing to a schema.** Four new AI tools — `open_transport`, `send_to_transport`, `read_from_transport`, `close_transport` — let the AI keep a transport open across calls, send each candidate SCPI query to the live instrument, and only declare properties / methods that actually work. For LineText / BinaryStream devices the AI uses `read_from_transport` to capture what the device emits on its own (a few seconds of inbound bytes plus a best-effort UTF-8 decode), which lets it propose schemas grounded in actual wire data rather than guesses. Sessions auto-close after 60 s idle / 5 min total lifetime so abandoned sessions don't pin a wire. The prompts now teach this verify-each-entry flow with explicit guidance to never send destructive commands (`*RST`, anything that writes to non-volatile memory, anything that arms an output) without user go-ahead. Result: dramatically fewer "the AI generated a connector with three properties the device doesn't actually support" rounds.
- **`analyze_binary_frame` — find values in a hex blob.** New AI tool for binary-protocol discovery: pass the captured frame as hex plus one or more values the user can read off the device's display, and it brute-forces every plausible (offset × width × type × endian × scale) decoding — uint/int 1/2/4-byte little/big × the standard scale ladder (1, 0.1, 0.01, 0.001, …), float32 / float64 little/big, ASCII text substrings, and BCD packed nibbles — reporting every fit within tolerance (default 2 %). When multiple expected values are passed, it cross-correlates: any (type, endian, scale, width) format that explains every value at distinct non-overlapping offsets gets surfaced as a `SchemaSuggestion` with a paste-ready `schemaHint` string. Suggestions are scored on average match quality, stride-bonus when fields land at consistent intervals, and a scale-simplicity penalty (1.0 beats 0.001 beats 1e-4). Replaces the previous "AI tries 40 decodings by hand and reports confidence" loop with a single deterministic call that covers ~5000 candidate decodings per frame. The `protocol-authoring.md` prompt now points the AI here in step 3 (draft schema) whenever the wire format isn't documented.
- **`analyze_binary_frame` now identifies ambiguity and supports multi-sample disambiguation.** Three additions for cases where one frame isn't enough to nail down the schema:

  1. **Ambiguity detection.** When two top suggestions decode to identical values on the current frame but differ in width / type / endian (classic uint8 vs uint16-LE when current values fit in 8 bits and the high bytes are 0x00), the response now includes `ambiguities: [{ preferred, alternative, alternativeMax, disambiguateBy }]`. The `disambiguateBy` field is a literal next-step instruction the AI can read to the user verbatim — e.g. "Capture another frame where at least one value exceeds 25.5".

  2. **Multi-sample input.** Pass `samples: [{frameHex, values}, ...]` (any number) in place of single `frameHex` + `values`. A combined suggestion must explain EVERY sample at consistent field offsets — deterministically resolves single-sample ambiguities because at least one sample will inevitably have a value the smaller candidate type can't represent.

  3. **Signedness hint per value.** Pass `canBeNegative: true|false` on each expected value. The analyzer drops int candidates when false (humidity, pressure, RPM, lux) and uint candidates when true (Celsius, signed offsets, bidirectional voltages), halving the search space and eliminating the uint8 vs int8 ambiguity that single-positive-reading data physically can't resolve. The protocol-authoring prompt now tells the AI to ask the user "can any of these readings ever go negative?" before calling.
- **AudioSynth gained polyphony and proper release tails.** Every `play*` action now accepts `overlap: true` so notes layer on top of whatever's already playing and the call returns at gate-off instead of blocking through the tail — useful for chords and arpeggios. Long-decay presets like `bell` and `marimba` also ring out for their full natural decay past the requested duration in both modes, so a 200 ms bell isn't suddenly cut off at 200 ms anymore. Existing scripts that don't pass `overlap` keep their replace-not-queue behaviour. Browser-side polyphony goes through a new live encoder session on the host so overlapping voices share one Opus stream without glitching the decoder.
- **Editor tabs and the file tree now auto-reload when any workspace file changes.** A workspace-wide file watcher emits `workspace.file.changed` for every create / modify / delete, so AI tool writes (e.g. `write_connector_config`), external editor saves (VSCode, vim), and script writes all refresh the UI without a manual reload. Clean tabs swap in the new content silently. Tabs with unsaved edits surface a banner offering **Reload from disk** or **Keep mine** instead of clobbering your work. The file explorer tree refreshes too, so newly created or deleted files appear without clicking Refresh.
- **Avantes spectrometer: lighting, horticulture and colorimetry properties.** Every `measure()` now also caches CIE 1931 chromaticity (`cieX`, `cieY`), correlated colour temperature (`cct`, McCamy), illuminance (`illuminance`, lux), full CIE 13.3-1995 colour rendering index (`cri` = Ra, `r9` = deep-red special index), peak and dominant wavelength, and 100-nm horticulture photon-flux bins from 300 to 1000 nm (`photonFlux300_400` … `photonFlux800_1000`). A new `autoIntegrationTime` action iteratively picks an integration time so peak counts sit around 70 % of full scale; set `autoIntegration: true` in the connector config to run it before every measurement. The AI can answer "measure the CCT" by calling `measure()` and reading `cct` — no spectrum analysis required.
- **BinaryStream auto-trigger on poll.** New `config.schema.framing.request` field on the BinaryStream protocol: a hex frame the protocol auto-sends before reads when the cached value is older than `maxStaleMs` (default 100 ms). Solves the "I poll, but nothing updates" problem for request-response devices that stay silent until they're poked — cheap thermometers, dataloggers, button-driven meters. Concurrent reads (the poll loop hitting `ch1_temp`, `ch2_temp`, `ch3_temp`, `ch4_temp` in sequence) coalesce onto a single round-trip so polling four properties triggers ONE send + receives ONE frame, not four. Without `request:` the protocol behaves as before — passive cache, updates only when something else sends a frame via `queryHex` or a declared `methods:` action. The `methods:` block stays the right place for user-invoked one-shots like reset / calibrate; `framing.request` is specifically for the implicit poll-trigger. `protocol-authoring.md` now points the AI here for any device that needs poking to talk.
- **Built-in script primitives are now drag-and-droppable.** The Connectors
  panel grew a **Script API** section at the top listing `delay`, `ai`,
  `say`, `log.*`, `emit`, `on`, `stream`, `ask.*`, `timestamp`, and the
  other globals. Drag any of them into a script editor to insert a working
  call — same UX as connector properties and actions.
- **Catalog entries now declare `kind`: Driver, Protocol, or Engine.** Every driver entry surfaces its user-facing classification via the `drivers.list` WebSocket message, so the marketplace UI can split the catalog into tabs. `Scpi`, `LineText`, `BinaryStream` come through as Protocols; `Vision` is an Engine; everything else stays a Driver. DLL extension packages opt in via a new `manifest.json` `kind` field. The included SCPI example connectors (`psu.js`, `power-meter.js` under `workspace-template/connectors/_examples/`) and the SCPI / LineText / BinaryStream / Vision starter templates now use `protocol:` and `engine:` keywords to match.
- **The AI no longer hand-writes SCPI connector files — `compose_scpi_connector` does.** New AI tool that takes structured data (name, connection block straight from `discover_serial_device`, schema as arrays of `{name, cmd, type, unit, description}` entries, optional safety / poll / ai blocks) and templates the canonical connector file shape, parse-checks it, and writes it. The AI's job shrinks to "decide what commands to expose" — the shape (`protocol: "Scpi"`, nested `config.schema.properties:`, `cmd:` field name, `safety: { limits: {...} }` nesting) is mechanical and controlled by code. Result: no more Frankenstein configs with hoisted `limits:` blocks or invented field names like `get:`, `scpi:`, `actions:`. Token cost on the write step drops roughly in half because the AI emits data not JS source. The anti-pattern paragraphs in the SCPI authoring prompt are gone — they're no longer reachable. `write_connector_config` stays available as the escape hatch for custom-JS cases: one command returning multiple parsed values (Hameg's `VAL?` → voltage / current / power), multi-step methods, vendor-specific quirks.
- **`discover_serial_device` — one tool call instead of an AI guessing game.** A deterministic C# sweep that tries every common baud rate / terminator / flow-control combo against a serial port in one shot. Replaces what used to be a slow, token-expensive iterate-by-trial-and-error loop where the AI called `probe_scpi_device` repeatedly with different parameters. The sweep takes ~500 ms on the happy path (modern SCPI at 9600 baud) and at most ~10 s on a fully silent port. At each baud rate it first listens passively for spontaneous emission — so an Arduino sensor that prints lines on its own, or a Modbus slave with poll, gets identified instantly without any send. Returns a complete description: `kind: "scpi" | "linetext" | "binarystream" | not found`, plus the exact baud / terminator / flow-control / IDN / vendor / model the AI should drop into the connector. When nothing's found, returns actionable hints ("instrument off, USB-serial cable issue, or wrong COM port — try unplug-plug detection") rather than a bare timeout.
- **FileAccess driver replaced with a smaller, handle-first API.** Twelve actions (`readText`, `writeText`, `appendText`, `readBinary`, `writeBinary`, `listFiles`, `listDirs`, `deleteFile`, `deleteDir`, `rename`, `fileInfo`, `file`) are gone. Four remain: `openText(path, delimiter?)`, `openBinary(path)`, `list(path?)`, `mkdir(path)`. `openText` and `openBinary` return path-bound handles whose `write` / `append` accept either a string or an array; arrays are joined with the configured delimiter (default `,`) and RFC 4180-quoted on cells containing the delimiter, double-quote, CR, or LF — so `f.append([1, 2.5, 'has, comma'])` writes `1,2.5,"has, comma"\n` and locale-safe (numbers format under invariant culture, so a `nl-NL` host doesn't turn `2.5` into `"2,5"` and collide with the comma delimiter).

  ```js
  const f = connector('fileaccess').openText('runs/log.csv');
  f.write('time,temp_c\n');
  f.append([timestamp(), 21.5]);
  ```

  Other behavioural changes:

  - **`delete()` is now idempotent.** It returns `false` if the file didn't exist instead of throwing `FileNotFoundException`. Defensive `f.delete()` cleanups no longer need a try/catch.
  - **`append(null)` / `append(undefined)` is a silent no-op.** `f.append(maybeRow)` won't blow up when `maybeRow` is missing.
  - **Polled properties `fileCount` and `totalSizeBytes` are gone.** Both ran a recursive `Directory.GetFiles(..., AllDirectories)` on every 1 s poll; sandboxes with thousands of files paid the cost continuously. Drop `poll: ["fileCount"]` from any custom FileAccess connector config.
  - **AI prompt footprint shrinks substantially.** The system-prompt device list emits one line per action description, so going from 12 to 4 actions cuts the FileAccess block roughly in half — helps clear the Anthropic API's 32 KB system-prompt cap on workspaces with many connectors.

  Scripts and connector configs that called the old actions need updating. The default workspace `connectors/fileaccess.js` and the example scripts (`psu-iv-curve.js`, `webcam-snapshot.js`) have already been migrated; pattern is `fa.file(p).write(x)` → `fa.openText(p).write(x)` and `fa.file(p).writeBinary(b64)` → `fa.openBinary(p).write(b64)`. Workspace custom `writeArray` wrappers are obsolete — `fa.openText(p).append(rowArray)` does it natively with proper quoting. Reference: `docs-site/reference/drivers/file-access.md`.
- **Documentation refresh for the foundation branch.** The new architecture, JS protocols, AI device-onboarding tools, and BinaryStream framing knobs now have first-class documentation across every surface:

  - **User docs** — five new pages under `docs-site/`: full schema references for [LineText](https://docs.muxit.io/reference/drivers/linetext.md), [BinaryStream](https://docs.muxit.io/reference/drivers/binary-stream.md) (covering `header` / `size` / `lengthOffset` / `quietMs` / `request` / `maxStaleMs` / `crc`), and [Transport](https://docs.muxit.io/reference/drivers/transport.md) (the `connection: { ... }` block for serial / TCP / USBTMC with platform notes); a single-page [AI Tools](https://docs.muxit.io/reference/ai-tools.md) reference for `discover_serial_device` / `probe_stimulus` / `analyze_binary_frame` / `compose_scpi_connector` plus the transport-probe surface; and a [Protocol Authoring guide](https://docs.muxit.io/guides/protocol-authoring.md) parallel to the SCPI authoring guide, with end-to-end walk-throughs for Arduino LineText and a silent-until-poked thermometer. [Concepts](https://docs.muxit.io/reference/concepts.md) gets a 5-row table mapping Transport / Protocol / Driver / Engine / Connector. VitePress sidebar renamed "Built-in Drivers & Protocols" with the three new reference pages, plus Concepts and AI Tools at the top of Reference.
  - **Marketing website** — `/device-compatibility` and `/how-it-works` updated from `driver: "GenericScpi"` + flat config to the new `protocol: "Scpi"` + `connection:` shape. `/marketplace` restructured to mirror the in-app **Devices** / **Engines** tabs: a new "Built-in protocols" section (Scpi / LineText / BinaryStream) inside the Devices tab, Vision moved into its own Engines tab. The "AI drafts the driver" section now walks the deterministic discover → probe → analyse → compose chain.
  - **Internal dev docs** — `docs/architecture/overview.md` rewritten around the 4-concept layering with a new "Driver / Protocol hosting" table and an AI-led onboarding section. New `docs/architecture/protocols.md` covers `JsProtocolHost` and `JsProtocolAdapter`. New `docs/reference/ai-authoring.md` walks the algorithms behind every AI authoring tool. `docs/development/clearscript-quirks.md` extended for the `setTimeout` patterns the JS protocols rely on.
  - **Examples** — two new seed connectors under `workspace-template/connectors/_examples/`: `arduino-sensor.js` (LineText, prefix-matched) and `binary-thermometer.js` (BinaryStream, silent-until-poked with `framing.request: "41"` + `framing.size: 16` + uint16 LE channels). README table updated.

  Defers a curated connector library (~15 instruments) to its own task.
- **`driver: "GenericScpi"` is now an alias for the built-in `Scpi` driver.** Existing connector configs that use `driver: "GenericScpi"` and the legacy `transport: "tcp" | "serial" | "usbtmc"` + flat `host`/`port`/`baudRate`/`vendorId` fields keep loading unchanged — the server translates the shape into the new `connection: { type, ... }` block at load time. The legacy DLL extension package is deprecated and will stop shipping in a future release. New connectors should use `protocol: "Scpi"` with an explicit `connection:` block.
- **JS Protocols arrive — LineText and BinaryStream join the catalog.** Two new built-in protocols ship as declarative `*.protocol.js` files running in the V8 sandbox: `LineText` parses text-line streams over Serial/TCP (Arduino-style devices, hobby instruments, anything that emits newline-framed values), and `BinaryStream` parses fixed-format binary frames (Modbus-RTU with CRC, custom embedded wire formats). Both ride on top of any `ITransport` — Serial, TCP, USBTMC — declared via `connection:` in the connector config. A new `JsProtocolHost` lets community contributors drop their own `*.protocol.js` files into `workspace/protocols/<name>/` for hot-load on next server start. The connector config validator picks up each protocol's `meta.schemaFields` allowlist so unknown fields in a connector's schema get rejected at write time, same way SCPI configs are already linted.
- **Marketplace splits into Devices and Engines.** The Extensions panel now has a primary tab row above the Installed / Available / Updates lifecycle tabs: **Devices** (anything that talks to a physical or virtual device — drivers and protocols, mixed alphabetically) and **Engines** (compute on data from other connectors — Vision today, future AI / signal-processing engines). Protocol entries (Scpi, LineText, BinaryStream) get a small `protocol` hint chip with a hover tooltip so it's clear they need a `schema` block; engines get a corresponding `engine` chip. Drivers without explicit kind metadata default to Devices so nothing disappears for older marketplace listings.
- **Scripts and image recognition can now use a different AI model than the chat assistant.** A new **Scripts & tools model** card in **Settings → AI Services** lets you pick a separate provider + model id for the `ai()` script global and the image-recognition tool — for example chat on Muxit Cloud and scripts on a local Ollama vision model. Leave it blank to inherit the chat model (existing setups keep working unchanged).
- **`probe_stimulus` — find what makes a silent device talk.** New AI tool for protocol-authoring on devices that won't say a word until you send the right byte (cheap thermometers, dataloggers, vendor-specific embedded gear). Sweeps a default candidate list — `*IDN?` with all three line endings, ENQ / STX / SOH / DC1 / CR / LF, every uppercase + lowercase ASCII letter, every uppercase + CR, a canonical Modbus-RTU read with CRC, `? NUL` — sending each, listening 500 ms, recording what came back. Returns the winning stimulus as both hex and ASCII so the AI can drop it straight into a `BinaryStream` method's `command` template or a `LineText` poll. Default `stopOnFirst: true` short-circuits the moment a candidate gets ≥3 bytes back, so the typical case ends in 1–5 seconds. Override the candidate list with `candidates: [{ label?, text? | hex? }, …]` (escape sequences `\r` / `\n` / `\xHH` decoded) when the protocol is vendor-specific. The `protocol-authoring.md` prompt now points the AI here whenever step 2's passive listen returns empty — replaces the previous "send_to_transport something benign and read again" guesswork loop.
- **The AI now teaches the new protocol shape, and the docs explain why.** The SCPI authoring prompt that runs when the AI sets up a benchtop instrument has been rewritten to produce `protocol: "Scpi"` + `connection: { type, ... }` connectors with a `schema:` block; the AI will no longer generate the legacy `driver: "GenericScpi"` + flat `transport:` shape for new files. A new generic protocol-authoring guide covers the LineText and BinaryStream protocols so the AI can author connectors for hobby serial devices and binary-frame hardware too. A new user-facing [Concepts page](https://docs.muxit.io/reference/concepts.md) explains the Driver / Protocol / Engine split in plain language, with worked examples for each kind; the glossary, the SCPI driver reference, and the connectors / first-connector tutorials are all updated to use the new shape. Existing connector files with the legacy shape still load unchanged.
- **Connectors can now be renamed from the Connectors panel.** Right-click any connector card and pick "Rename…" — the name turns into an inline input, Enter commits, Escape cancels. The server renames the underlying `.js`/`.json` file (preserving its folder and extension), updates the enabled list in `server.json`, and hot-reloads just that one connector so it stays online under the new name without a full restart. A reminder banner appears at the top of the panel after each rename: scripts and dashboards still reference the old name and need to be updated by hand. A new `connector.rename` WebSocket message powers the feature.
- **The Safety level dialog now explains itself.** Every capability row (Write in/out of range, Large change, Action, Destructive action, AI confirmation) shows an inline plain-language description with an example, the outcome values (Allow / Simulate / Ask once / …) have hover tooltips and a built-in legend, and switching to **Unrestricted** opens a prominent red risk panel listing exactly what will execute without prompts before the `I UNDERSTAND` input appears. No more guessing what a row means or what you’re agreeing to.
- **`commandIntervalMs` is back for the new Scpi protocol.** Slow SCPI instruments — especially RS-232 hardware — couldn't keep up with back-to-back commands at the new Scpi protocol's full rate; the legacy `GenericScpi` driver had a `commandIntervalMs` field to throttle them, but phase 7 dropped the field as "unsupported" in the translator. `ScpiProtocol` now reads `config.commandIntervalMs` (in milliseconds) and enforces it as a minimum gap between any two I/O operations inside the protocol's I/O lock. Legacy `commandDelay` / `settleMs` connector fields fold automatically into `commandIntervalMs` (max of the two) when present, with a one-line deprecation note on stderr. Default 0 = no pacing.
- **SCPI on Serial and TCP, not just USBTMC.** The new `protocol: "Scpi"` built-in now accepts `connection: { type: "serial", port, baudRate }` and `connection: { type: "tcp", host, port }` alongside `usbtmc`. Networked LXI instruments and serial/RS-232 SCPI hardware can be controlled through the new connector pipeline without needing the legacy `GenericScpi` driver.
- **Added a Community page and nav link on muxit.io.** Surfaces GitHub Discussions for questions and conversation, and GitHub Issues for bugs and feature requests, so visitors can find the project's community surfaces without hunting through GitHub.

### Bug Fixes

- **The AI stops writing Frankenstein SCPI connectors.** Real-world trace surfaced three connected issues. (1) The AI wrote `driver: "GenericScpi"` instead of `protocol: "Scpi"`, then hoisted `properties:` and `actions:` blocks out of `config.schema:` and into the top level with invented field names (`get:` / `scpi:` instead of `cmd:`) — a connector that loads but does nothing. (2) `open_transport` only accepted nested `{ connection: { ... } }` args while `probe_scpi_device` accepts flat args, so the AI's pattern-matched flat calls failed with "connection block is missing". (3) The validator never flagged the misplaced blocks. Three fixes: the SCPI authoring prompt now leads with a clearly-labelled anti-pattern block followed by the canonical Hameg-style shape; `open_transport` accepts either flat or nested args (build a connection dict server-side); the validator now warns on top-level `properties:` / `methods:` blocks when the connector targets a Protocol and on the unrecognised `actions:` key (the AI's frequent rename of `methods:`).
- **`analyze_binary_frame` now respects the natural order of supplied values when feasible.** Greedy "lowest-error per value" assignment could silently swap adjacent channels when display noise made two readings cross by tenths — a thermometer showing `[21.4, 22.6, 22.7, 25.7]` could end up with ch2 and ch3 mapped to swapped offsets because the swap shaved 0.4 % off total error. Field assignment now tries the natural-order alternative (sort the picked offsets ascending, bind sortedOffsets[i] to value[i]); when every value still has a valid match at its sorted offset, that assignment wins. Falls back to greedy when natural-order can't be satisfied. The AI prompt now explicitly tells the AI to pass values in their natural order — ch1, ch2, ch3, ch4 — not sorted, not arbitrary, so this heuristic can do its job.
- **`analyze_binary_frame` now prefers uint16 over uint8 when the byte pattern is `value 00 value 00 …`.** The 4-channel-thermometer reverse-engineering trace surfaced two related issues: (1) the default tolerance (2 %) was too tight — sensor drift, display smoothing, and reading-while-the-value-is-still-changing routinely push real-world per-frame error to 3-5 %, so one out of four values would fall just outside and break the cross-correlation; default is now 5 %. (2) when uint8 *did* win cross-correlation it would silently pick a stride=2 layout with `00` padding bytes between fields — byte-identical to the uint16 little-endian interpretation but liable to wrap when any value exceeds 25.5 °C (or 25.5 anything). Two new heuristics push uint16 to the top: **+10 score** when every field's high-byte slot is `0x00` (signals 16-bit storage with low current values), and **−8 score** on the symmetric uint8-stride-2-with-zero-pad pattern. Same byte content reads the same value today and stays correct tomorrow when temperatures rise.
- **BinaryStream `queryHex` no longer truncates responses to the first chunk that arrives.** Previously, when a connector had no `framing.header` and no `framing.lengthOffset`, the protocol returned `buf.length` bytes as a "complete frame" the moment any data appeared — so on a device that bursts a 13-byte reply over serial (cheap thermometers, dataloggers), `queryHex` resolved with the first 1–3 bytes and dropped the rest. Two new framing knobs fix it: `framing.size` for explicit fixed-size frames, and `framing.quietMs` (default 50 ms) for inter-frame-gap detection used when no `header` / `size` / `lengthOffset` is set. The protocol-authoring AI prompt now points the AI at the right knob during step 3 (draft schema) and warns that "queryHex returned fewer bytes than expected" is the diagnostic signature of missing framing config.
- **Eight code-review bugs swept.** Code review of the foundation branch surfaced a handful of real bugs that didn't bite the happy path but would have under specific load / lifecycle conditions. All fixed in one pass: `JsProtocolHost` now properly shuts down on server teardown (was leaking every live LineText/BinaryStream instance + its V8 engine + its open transport handle), `InitAsync` takes the per-instance lock around the V8 engine init (was racing fast polls), descriptors are cached at init time instead of running V8 + a sync `.Wait()` on every UI catalog read (no more potential deadlock + faster), the JS transport adapter detaches its data-received callback before the V8 engine is disposed (no more use-after-free on disposed engines), `JsProtocolHost.NormalizeResult` now unwraps V8 ScriptObjects before they cross engine boundaries (matches JsDriverHost), `TransportProbeService` no longer disposes the per-session semaphore in the close path (the idle reaper was racing in-flight sends), `SerialTransport` and `TcpTransport` `ReadAsync` queue chunks that arrive before a waiter registers when no `DataReceived` subscribers exist (closes a TOCTOU that ate bytes for pure pull-style protocols), and `BinaryStream`'s CRC check now drops one byte and resyncs on bad-CRC instead of swallowing the whole `frameLen` window (one bit-flip on a Modbus-RTU CRC no longer takes out the next valid frame). Plus two small prompt-drift fixes: `safety-confirmation.md` now mentions `compose_scpi_connector` under the connector-config gate, and `probe_scpi_device`'s tool description no longer leads with a self-contradicting "default `\n`" sentence.
- **License falls back to Free silently after a fresh install — fixed.** When a license key is present on disk but the paired signed proof fails to verify (most often after an OS reinstall changes the machine fingerprint that the proof was bound to), the server demoted the tier to Free as expected — but the background revalidation timer that should have recovered it within 60 s was defined and never started, so the demotion stuck until the user manually re-entered their key. Two things now happen: the 24 h revalidation timer actually starts on every boot, and the server fires a one-shot revalidation immediately at boot whenever a license key is present but the tier resolved to Free. So a "yes the license is there, no the proof doesn't match this install" situation now self-heals during startup.
- **MCP setup snippets now connect to the running Muxit server instead of launching a duplicate.** The Claude Desktop and Claude Code configs on **Settings → MCP** previously spawned a second `dotnet --mcp` stdio process that raced the live server's workspace lock and broke whenever MSBuild banner output landed on stdout. They now point at the already-running HTTP endpoint — Claude Desktop uses `npx mcp-remote` as a stdio↔HTTP bridge; Claude Code connects natively via `type: "http"` and the live `httpUrl` (so the port always matches whatever `websocket.port` resolves to). The repo-root `.mcp.json` is updated to match.
- **`probe_scpi_device` accepts XON/XOFF directly + libusb finalizer crash fixed.** Two probe-flow improvements after testing against a Hameg HM8115-2 power meter:

  1. The AI tool `probe_scpi_device` now takes a `flowControl` argument on the serial path (`"none"` / `"xon-xoff"` / `"rts-cts"` / `"both"`). When the first probe returns a garbled IDN, the AI can re-probe in one step instead of dropping back to manual `open_transport` calls.
  2. Fixed an occasional native `0xC0000005` crash inside `LibUsbDotNet.UnrefDevice` when calling `list_usbtmc_devices` — the libusb device collection was being left for the GC to finalize *after* its parent `UsbContext` had already been disposed. Disposing the collection first (in the right order) eliminates the dangling-pointer race.
- **`probe_stimulus` no longer truncates drip-feed responses.** Previous behaviour exited the per-candidate listen window the moment ≥3 bytes had arrived in the buffer — so on devices that deliver their response over several serial chunks (UART thresholds, per-byte device processing), the first chunk got reported as the whole response. The AI then set `framing.size` to a truncated length, the BinaryStream protocol started concatenating leftover bytes onto the next request's response, and downstream field offsets shifted around frame-to-frame. Sweep now waits for **inter-byte silence** (`quietWindowMs`, default 80 ms — configurable via tool args) after the first byte arrives before reporting. Per-candidate `windowMs` default bumped from 500 to 1000, max from 5000 to 10000, to give slow devices headroom. Result hints now spell out the exact `framing.request:` + `framing.size:` pair to drop into a BinaryStream connector — the reported byte count is the complete burst.
- **Three follow-ups to the AI-led SCPI authoring flow** surfaced by a live Hameg HM8115-2 onboarding trace:

  1. **`discover_serial_device` now hands back a `sessionId`** — a transport already open with the discovered baud / flow-control / terminator. The AI uses it directly for `send_to_transport` command verification, instead of re-opening and silently dropping a setting (the recurring failure mode where `*IDN?` worked during discovery and then timed out on the very next call).

  2. **`compose_scpi_connector` auto-enables + reloads.** Before, the file landed on disk in disabled state; the AI then wasted 4-6 turns on `get_device_state`, `read_connector_config`, `get_server_config` trying to "fix" it. Now the composer appends to `connectors.enabled` (when the user has an explicit list) and hot-reloads, and the response says `enabled: true, reload.loaded: true, nextStep: "...read_property..."` so the AI skips straight to smoke-testing.

  3. **The composer rejects two properties sharing the same SCPI query.** Hameg's `VAL?` returns `U=… I=… Watt=…` — three quantities from one round-trip. The declarative schema can't express that, so the composer now blocks it with a hint pointing at the two valid escape routes (single `string` property + script-side parsing, or `write_connector_config` with custom JS). The SCPI authoring prompt also teaches the AI to spot multi-value responses during step-3 verification and tell the user up-front.
- **Serial flow control for older SCPI gear.** Hameg HM8115-2 and several older Rohde&Schwarz / Tektronix instruments use XON/XOFF software flow control — without it the 0x11 / 0x13 bytes leak into the read buffer and corrupt SCPI response parsing, so `*IDN?` queries come back garbled or empty. SerialTransport now accepts a `flowControl` option in the `connection:` block (`"none"` (default), `"xon-xoff"`, `"rts-cts"`, or `"both"`); the OS driver then transparently strips the flow-control bytes before they reach the Scpi protocol. The AI's SCPI authoring flow learned to recognise `\x11` / `\x13` in captured hex as the XON/XOFF symptom and now suggests adding `flowControl: "xon-xoff"` automatically. The bundled `power-meter.js` example (Hameg HM8115-2) ships with the right setting.

## v0.35.1 — May 15, 2026

### Bug Fixes

- **`muxit update` now installs the correct architecture on ARM64 Linux.**
  The self-updater always downloaded the `linux-x64` asset on Linux,
  including on 64-bit Raspberry Pi OS where the resulting binary would
  fail to run or be transparently emulated. It now picks the matching
  release asset based on `RuntimeInformation.OSArchitecture` — `linux-x64`
  on Intel/AMD hosts, `linux-arm64` on aarch64 hosts (Pi 4/5 and similar
  arm64 SBCs). Hosts without a matching release asset (e.g. 32-bit ARM,
  ARM Windows) now print a clear "no release asset for `<os>` `<arch>`"
  message instead of pulling the wrong build.

## v0.35.0 — May 15, 2026

### Features

- **`ai()` and the built-in Chat Panel now work on the Free tier when pointed at a local LLM.** The `"ai"` license feature still gates Muxit-managed cloud chat / voice / `ai()` (Maker+), but the `"local-llm"` feature is free on every tier — so a Free user who configures Ollama, LM Studio, or any OpenAI-compatible endpoint in **Settings → AI Services** can chat from the browser and call `ai(prompt)` / `ai(prompt, image)` from scripts without an upgrade. The script-side surface already routed through the active provider; this change wires the Chat Panel UI to gate on the same per-provider feature, so the input placeholder no longer says "AI chat requires Pro — upgrade to enable" once a local provider is selected. Docs (`docs-site/guides/ai.md`, `docs-site/reference/script-api.md`) and the in-app upgrade CTA copy now match pricing v2: managed cloud = Maker, MCP + Local LLM = Free, Vision AI tools + Autonomous Agents = Pro.
- **Stop-speaking button and a live "You" transcript bubble live in the chat now, not the header.** While Muxit is talking, a "Speaking…" row with a Stop button appears below the latest reply so a long answer can be interrupted without hunting in the header. While you're speaking, the in-progress transcription shows up as a live "You" bubble at the bottom of the chat — where the eye is already focused on the most recent reply — instead of in the slim status bar at the top.
- **The AI assistant can no longer overwrite a connector config without confirming first, and every overwrite is automatically backed up.** `write_connector_config` and the new `restore_connector_backup` both now go through the chat-confirmation gate (`kind: "connector"`) — the LLM is required to read the existing file, summarize what's changing (driver, methods/properties added/removed/modified), and explicitly call out that an existing connector is being replaced before the write executes. Brand-new connectors only need a short summary; reads remain ungated. Every write also copies the previous file to `workspace/connectors/.backups/<name>.<timestamp>.js` and keeps the last 10 versions per connector. Two new AI tools, `list_connector_backups` and `restore_connector_backup`, expose the backups for one-tool-call rollback — the current version is itself backed up before a restore, so it stays reversible. The connector loader already skips dot-prefixed folders, so backups never get picked up as live connectors.

### Bug Fixes

- **The AI chat input stays focused after sending a message.** Sending disables the textarea while the AI is responding, which moved focus away; once the reply completes the input is now re-focused automatically so the next prompt can be typed without clicking back into the box.
- **`node start.js server` no longer 404s on the UI.** Dev builds left `bin/<cfg>/net9.0/wwwroot/` empty, so the static-files provider — which was pinned to the binary's directory to fix the Windows single-file installer case — found nothing there. `MuxitServer.csproj` now mirrors `wwwroot/` into the build output after every `dotnet build` (hardlinked where supported), matching the layout `dotnet publish` already produces. Dev and published now share one on-disk shape, and `Program.cs` resolves the static root through the same `InstallPaths.InstallDir + "wwwroot"` path in every mode.
- **Oscilloscope V/div and Time/div knobs now reach their lowest settings.** The mini-knob's angle wrap-around was a no-op, so dragging toward the lower-left side of the arc clamped to the maximum instead of stepping down through small values — the same wrap fix already in the main dashboard knob is now applied here.
- **SCPI connector setup with the AI assistant no longer loses its tools mid-conversation.** Intent classification (`AiService.ClassifyIntentByKeywords`) was looking only at the latest user turn, so once a SCPI-authoring flow moved past the opening question — e.g. "help me create a connector for a BK Precision 9122A" followed by "9600 baud" or "COM3" — the SCPI keywords disappeared, the `scpi-authoring` and `config` tool groups dropped out, and the SCPI-authoring system-prompt fragment was no longer attached. The model then invented plausible-sounding names like `probe_serial`, `write_connector`, and `create_connector` (all "Unknown tool"). Classification now folds the last few user turns into the keyword scan, so any multi-turn flow keeps the toolset (and system-prompt guidance) that was activated by the opening message. Same fix applies to vision, scripts, agents, dashboards, and any other intent-routed group.
- **SCPI knob drags no longer walk the instrument through every intermediate value.** Rotating a dashboard knob from 0 V to 20 V used to emit one WebSocket frame per pixel of pointer movement; the driver then sent every intermediate `VOLT N` to the device in order, so the voltmeter visibly stepped 0 → 1 → 2 → … → 20 over hundreds of milliseconds. Three things had to change for the device to jump straight to the final value: (1) `connector.call` messages now dispatch concurrently at the WebSocket layer — they used to await each other on the read loop, so the SCPI driver never saw two writes in flight at once; (2) the SCPI driver coalesces per-property writes through a background pump that samples the latest pending value **inside** the transport lock, after `commandIntervalMs` has elapsed — rapid same-property sets collapse to one wire-level command per pump cycle, with `commandIntervalMs` doubling as the coalescing window; (3) the dashboard knob widget throttles its outbound dispatches to ~30 ms during a drag and always flushes the final value on `pointerup`. Distinct properties keep their FIFO order, so `output = true; voltage = 20` still sends `OUTP ON` before `VOLT 20`. Direct `send`/`query` calls and declared methods (`c.beep()`, `c.save(3)`) bypass the pump and execute in call order. The three legacy SCPI timing knobs collapsed: `commandIntervalMs` replaces `settleMs` + `commandDelay` with a single "minimum ms between consecutive transport operations" knob; the old fields still work for one revision with a deprecation hint logged on startup. A side benefit of the WebSocket dispatch change: a per-WebSocket send lock now serialises frame writes (raw `WebSocket.SendAsync` is not thread-safe), closing a latent race that could corrupt frames when the broadcaster and a direct response landed in the same microsecond.
- **TTS now speaks AI replies reliably, including when the user only ever talks (no clicks).** Several latent issues compounded: hands-free continuous mode kept the mic open so the chat panel deliberately suppressed TTS to avoid feedback; the auto-speak cursor coordination between `useTts` and `ChatPanel` got out of sync between turns; and most importantly, the TTS controller waited until its very first speak request to attach the click/keydown/touch listener that browsers require before `speechSynthesis.speak()` will fire — so a voice-only user, whose earlier mic-button click was the only interaction they'd had, got no listener for that click and stalled forever on "Replying…". The voice hook now pauses STT for each utterance in continuous mode and resumes when speech ends; the auto-speak path was simplified to fire once per message (keyed on id); and the gesture listener is armed eagerly at controller construction so any interaction at any time during the session primes TTS. A hidden `/?voicetest=1` page exposes each slice of the pipeline for isolated repro.

## v0.33.2 — May 11, 2026

### Bug Fixes

- **Windows installer launches no longer 404 on the web UI.** The server now anchors `wwwroot/`, `workspace/`, and `workspace-template/` to the actual `muxit.exe` directory via a new `InstallPaths` helper. Previously the single-file-publish build relied on `AppContext.BaseDirectory`, which on Windows points at the .NET bundle extract dir under `%TEMP%\.net\muxit\<hash>\` rather than `%LOCALAPPDATA%\Muxit\` — so the static-files provider, workspace resolver, and self-updater all looked in the wrong place when launched from the Start Menu shortcut. The picker server's existing fix is now shared with the main server, the workspace-create API, and the self-updater. A leftover `%LOCALAPPDATA%\muxit.io\` directory from older builds is also migrated and removed on first launch.

## v0.33.0 — May 10, 2026

### Features

- **Workspace template trimmed and reorganised for first-time users.** New
  workspaces now ship with three active connectors at the root (`webcam`,
  `test-device`, `fileaccess`) and a `_examples/` folder of starter templates
  for power supplies, ONVIF cameras, vision, GRBL CNC, MQTT, e-mail, webhooks,
  and Python drivers — copy a file up one level to enable it. Robot- and
  spectrometer-specific connectors, dashboards, agents, and process docs were
  removed (they auto-install via the matching driver template when needed).
  The `scripts/demo/` folder was renamed to `scripts/tutorials/`, and a new
  `scripts/examples/` folder collects copy-and-adapt patterns including
  `psu-voltage-ramp.js`, `psu-iv-curve.js`, `threshold-alert.js`, and
  `notify-on-completion.js`. Three new beginner scripts (`hello.js`,
  `webcam-snapshot.js`, `webcam-describe.js`) sit at the script root for the
  first-run experience.

### Bug Fixes

- **Fixed the Avantes and Fairino driver connector templates.** Their
  `properties` blocks declared getters with `fn:` instead of `get:` — the
  ConnectorLoader only registers the latter, so any custom property defined
  that way was silently ignored at runtime. The starter connectors now use
  the correct `get:` form, matching every other driver template.

## v0.32.2 — May 10, 2026

### Bug Fixes

- **Crash and startup logs now live next to the rest of muxit's data
  directory.** Previously `LogPaths` followed XDG / `Application Support`
  conventions and wrote to `~/.local/share/Muxit/logs/` on Linux and
  `~/Library/Application Support/Muxit/logs/` on macOS, while every other
  component (workspace catalog, locks, restart markers) lived under
  `~/.muxit/`. Logs now share the same root: `~/.muxit/logs/<workspace-hash>/`
  on Linux and macOS (Windows is unchanged at
  `%LOCALAPPDATA%\Muxit\logs\<workspace-hash>\`). Existing installs can
  delete the old directory by hand — there's no auto-migration.
- **Switching the server port from the GUI no longer crashes the server and
  orphans the workspace lock.** When the relaunched process found the new
  port already in use, `Console.ReadLine` could throw `IOException` because
  the inherited stdin was no longer a usable TTY — that crash skipped the
  lock cleanup, and every subsequent `muxit` run reported "Workspace
  'Default' is already open in PID …". The interactive prompt now treats an
  unreadable stdin as "no answer" and exits cleanly, and the Unix-domain
  socket stale-detection now correctly recognises `ECONNREFUSED` even when
  `Task.Wait` wraps it in an `AggregateException`, so a leftover socket
  file from a dead holder is reclaimed on the next launch.
- **Selecting a privileged port (1-1023) in the GUI no longer leaves you
  unable to launch muxit on Linux/macOS.** Previously, configuring port 80
  as a non-root user would fail to bind, then the auto-bump search walked
  ports 81-180 (also privileged, also EACCES), then the kill prompt asked
  to terminate the holder — but `lsof` can't see processes owned by other
  users, so muxit aborted and every subsequent launch repeated the loop
  because `server.json` still pointed at port 80. The startup path now
  checks effective UID and `CAP_NET_BIND_SERVICE` up front: when the
  configured port is privileged and we can't bind there, we fall back to
  the first free port at 1024 or above for this run only and print the
  exact `setcap` command to grant the capability permanently. Explicit
  `--port=<n>` overrides still hard-fail with the same remediation
  instead of silently bumping. The "could not identify the process"
  message in the kill prompt now also points at `sudo lsof -i :<port>`.

## v0.32.1 — May 10, 2026

### Bug Fixes

- **Onvif streaming now works on Raspberry Pi (linux-arm64).** When no per-frame transformation is requested (no `flipH`, `flipV`, `digitalZoom`, or recording), the driver passes ffmpeg's MJPEG output straight through to the dashboard without going via OpenCV. This avoids the missing `OpenCvSharpExtern` native dependency on arm64, where shimat does not publish a runtime bundle, and removes the per-frame `[Onvif] Frame error: TypeInitializationException` log spam. Per-frame transforms still require the OpenCV native bundle (so they remain unavailable on arm64); the driver now logs a single descriptive warning instead of a stack trace per frame, and rate-limits frame errors to one per minute. See [Platform notes](https://docs.muxit.io/reference/drivers/onvif.md#platform-notes).

## v0.32.0 — May 9, 2026

### Features

- **Releases now include a `linux-arm64` archive.** `muxit-linux-arm64-vX.Y.Z.tar.gz` runs on Raspberry Pi 4/5 (64-bit Pi OS) and other arm64 Linux boards. The publish matrix builds it cross-arch on `ubuntu-latest`, so tag pushes produce all three artefacts (`win-x64`, `linux-x64`, `linux-arm64`) in one go. `node build.js publish` picks it up automatically; override via `MUXIT_PUBLISH_RID=linux-arm64` for a single-RID build. Vendor driver DLLs that ship x64-only natives (e.g. some Tier-3 extension drivers, OpenCvSharp4-backed video drivers) may not load on arm64 — the server itself, JS/Python drivers, and built-in non-video drivers run fine.

## v0.31.1 — May 9, 2026

### Bug Fixes

- **Linux installer no longer downloads a stale tarball or leaves the user without a runnable command.** The `install.sh` asset selector now anchors on the exact release tag, so a stray `muxit-linux-x64-v0.31.0.tar.gz` left over on a `v0.31.2` release can't get picked over the right one. The "Launch Muxit:" hint at the end of the install also falls back to the absolute path (`~/.local/share/muxit/muxit`) when `~/.local/bin` isn't on `$PATH`, instead of telling the user to run a `muxit` command that their current shell can't resolve.
- **`muxit update` no longer corrupts a Linux install by overwriting it with the Windows binary.** The self-updater was hardcoded to download `muxit-win-x64-*.zip` and copy `muxit.exe` over the running binary regardless of platform; on Linux that left a Windows PE at `~/.local/share/muxit/muxit` (and stripped the executable bit on the way), so the next `muxit` invocation died with `ERROR_BAD_EXE_FORMAT` (0x800700C1). The updater now picks the right asset for the OS (`muxit-linux-x64-<tag>.tar.gz` on Linux, `muxit-win-x64-<tag>.zip` on Windows), anchors the asset name on the actual release tag so a stale build can't be picked, extracts via `System.Formats.Tar` to preserve Unix mode, and explicitly sets `0755` on the new binary as a final safety net. If the expected binary isn't found in the archive, the previous binary is rolled back from `.bak` instead of being lost.
- **The UI no longer 404s when `muxit` is launched from a directory other than its install dir.** ASP.NET Core's `WebApplication.CreateBuilder()` defaults the content root to the current working directory, so the static-files provider was looking for `wwwroot/` next to wherever the user invoked `muxit` from — typically `$HOME` via the Linux installer's `~/.local/bin/muxit` symlink. We now pin `ContentRootPath` to `AppContext.BaseDirectory`, so the UI loads regardless of CWD.

## v0.31.0 — May 8, 2026

### Features

- **`node build.js publish` now produces both linux-x64 and win-x64 archives by default on either host OS.** Archive creation moved from platform-specific shell-outs (`tar` / `Compress-Archive` / `zip`) to a single `archiver`-based helper that explicitly sets the `+x` bit on `muxit`, `createdump`, and `*.so*` files in the linux tarball — so cross-host builds (e.g. linux-x64 from a Windows dev box) now ship the executable bit correctly. Override with `MUXIT_PUBLISH_RID` if you only want one platform.

### Bug Fixes

- **Dev console can now save manifests for Python drivers.** Saving a Python driver's manifest from the Drivers tab returned `unknown driver: python/<name>` because the dev console's driver resolver only listed C# and JS sources; Python drivers are now included so save / build / registry-entry / publish endpoints all resolve them.
- **Dev console Release tab: Build release archive no longer makes the log box vanish.** The release panel was repainting 500ms after the build started, which destroyed the log element while the build was still streaming — looking like the operation crashed silently. The refresh now waits for the build's exit event. Help text clarified to reflect that the local build targets the host OS only (cross-platform matrix runs on tag push).

## v0.30.0 — May 8, 2026

### Features

- **Linux now has a one-line installer and a runtime dependency check.**

  End-users on Ubuntu / Debian can install with:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/muxit-io/muxit/main/install.sh | bash
  ```

  The installer (`installer/install.sh`):

  - Detects the distro, runs `sudo apt install ffmpeg
    libayatana-appindicator3-1 xdg-utils` with confirmation.
  - Adds the user to the `dialout` group if needed (serial-port access).
  - Downloads the latest `muxit-linux-x64-v*.tar.gz` from GitHub Releases
    and verifies the SHA-256 against `checksums.txt`.
  - Extracts into `~/.local/share/muxit/` (per-user, no sudo for the
    install itself; `workspace/` is preserved across reinstalls).
  - Symlinks `~/.local/bin/muxit` so plain `muxit` works on `$PATH`.

  Re-running the same command upgrades to the latest release in place.

  Independently, the server itself now probes its runtime dependencies
  at startup on Linux and prints a non-fatal **System dependencies**
  section in the boot banner:

  ```
  ── System dependencies ─────────────────
    ✓ ffmpeg (Onvif IP-camera RTSP streaming)
    ⚠ libayatana-appindicator3-1 missing — system tray icon unavailable.
      Fix: sudo apt install libayatana-appindicator3-1
    ✓ xdg-open (auto-open browser at startup)
    ⚠ user 'matthijs' is NOT in 'dialout' group — serial drivers will
      fail with EACCES on /dev/ttyUSB*.
      Fix: sudo usermod -aG dialout matthijs && newgrp dialout
  ```

  So users who skip the installer (manual tarball + extract) still get
  told exactly what's missing and how to fix it.

  New install guide at `/docs/guides/install-linux` covers the
  one-liner, manual install, all four supported package managers
  (apt / dnf / pacman / zypper), and uninstall. macOS, dnf-native
  support, .desktop launcher, udev rules and systemd-user service are
  deliberately scoped out for v1 — see `docs/proposals/linux-packaging.md`
  in the dev repo for the punch list.
- **Linux x64 release archives are now published alongside the Windows build.**
  The release tag (`v*`) workflow now runs on a matrix (`windows-latest` +
  `ubuntu-latest`) and uploads two assets per release:
  `muxit-win-x64-v<version>.zip` and `muxit-linux-x64-v<version>.tar.gz`. The
  Linux tarball preserves the executable bit on the `muxit` binary because it
  is created on the Linux runner.

  `build.js publish` now defaults to the host platform's RID and accepts an
  `MUXIT_PUBLISH_RID` env override so a single dev machine still produces a
  relevant archive. Packaging is `.tar.gz` for `linux-*` / `osx-*` RIDs and
  `.zip` for `win-*`.

  ### Linux runtime requirements

  shimat's manylinux build of `libOpenCvSharpExtern.so` ships a static
  FFmpeg without network protocols (no `rtsp://`, no `http://`) and a
  GStreamer backend that registers but is non-functional. Both
  `VideoCapture(rtspUri, FFMPEG)` and `VideoCapture(pipeline, GSTREAMER)`
  return `IsOpened()=false` on Linux for any RTSP URL. Verified with the
  diagnostic at `tools/rtsp-probe/run.sh` — five different in-process
  approaches all fail.

  The Onvif driver therefore delegates RTSP capture on Linux/macOS to
  the **system `ffmpeg` binary**: spawn `ffmpeg -i rtsp://… -f mjpeg
  pipe:1`, parse JPEGs from stdout, decode each one with `Cv2.ImDecode`
  (which works fine in the same wrapper). On Windows the in-process
  `VideoCapture(rtspUri, FFMPEG)` path is unchanged — there shimat's
  runtime ships a full FFmpeg with RTSP support.

  For Onvif on Linux you therefore need ffmpeg on `$PATH`:

  ```bash
  sudo apt install -y ffmpeg
  ```

  That's the whole story — no GStreamer packages required. TestDevice's
  synthetic video stream and any future Webcam / Vision driver work
  without ffmpeg (they use the in-process OpenCV pipeline directly,
  which is fine because they don't open network streams).

  Optional:

  - `xdg-utils` — lets the server auto-open the browser on startup.
    Without it, the server prints the URL and you open it yourself.
  - `libayatana-appindicator3-1` — system-tray icon. Without it, the
    server starts normally but with no tray.

  The server itself (web UI, scripts, non-video drivers) runs without
  any of the above.

  Vendor-SDK drivers (Avantes, Fairino) remain Windows-only and are not
  exercised on the Linux build leg of CI.

## v0.29.0 — May 8, 2026

### Features

- **Welcome screen now shows system info instead of a tier comparison table.** The Free vs Pro feature table is gone — the home page still shows your current license tier badge, plus a new System panel with the server port, hostname (e.g. `muxit.local`), Bonjour/mDNS state, remote-access state, the active AI provider, and (for Muxit AI) credit usage.

## v0.28.0 — May 8, 2026

### Features

- **System tray now has a "View Logs" entry that opens a live log viewer.** The
  viewer is served at `/logs.html` and streams entries from the in-memory
  ringbuffer over Server-Sent Events with level + substring filters, pause and
  download. `Console.WriteLine` / `Console.Error.WriteLine` calls are now teed
  into `ServerLogger`, so startup banners are visible too. Each instance has
  its own port, so multiple muxit instances on the same machine each surface
  their own logs without cross-talk.

  Two on-disk files are kept per workspace under
  `%LOCALAPPDATA%\Muxit\logs\<hash>\` (Windows), `~/Library/Application Support/Muxit/logs/<hash>/`
  (macOS), or `~/.local/share/Muxit/logs/<hash>/` (Linux):

  - `startup.log` — overwritten on every clean exit, so a screenshot is
    always available even if the HTTP server is down.
  - `last-crash.log` — written from the unhandled-exception handler. When
    present, the tray gains a one-shot "Open Last Crash Log" entry that
    opens it in the OS default text editor.

  Nothing is ever appended — exactly two files per workspace, both
  overwritten in place.

## v0.27.2 — May 7, 2026

### Bug Fixes

- **Restart Server and Switch Workspace now work in the published muxit executable.** Previously these actions wrote a marker file and stopped the server, relying on the dev-mode Node launcher (`start.js`) to respawn the process — which left users running `muxit.exe` with a stopped server and no automatic restart. The server now respawns itself when no parent launcher is present.

## v0.27.1 — May 7, 2026

### Bug Fixes

- **AI assistant no longer asks for confirmation twice on numeric writes.** The system prompt now tells the model to call the tool first and let the safety gate prompt the user, instead of pre-confirming in chat and then triggering the gate's prompt on top.

## v0.27.0 — May 7, 2026

### Features

- **Windows release archives are now versioned (`muxit-win-x64-v<version>.zip`).** The release zip includes the version in its filename so downloads from the GitHub Releases page are self-identifying. The auto-updater (`SelfUpdater`/`UpdateChecker`) and the PowerShell installer match the asset by `muxit-win-x64*.zip` prefix, so existing installs continue to find the latest release without changes.

## v0.26.0 — May 7, 2026

### Features

- **Imprint, Privacy Policy, and Terms & License Agreement are now published at muxit.io/legal/imprint, /legal/privacy, and /legal/terms.** The site footer carries persistent links to all three. The in-app workspace acknowledgement bumps to v1.1.0 (forces re-acceptance) and now references the full Terms and Privacy Policy directly. The privacy policy describes the license machine-fingerprint precisely (machine name, OS user name, up-to-three sorted MAC addresses, and an OS-installation identifier — all hashed locally before transmission), clarifies that MCP-with-your-own-AI-key is available on every tier including Free, and removes the analytics paragraph: muxit.io currently runs no website analytics at all. The references to the EU Online Dispute Resolution platform have been removed from both the imprint and the terms because the European Commission discontinued the platform on 20 July 2025.
- **Multi-instance support: one running muxit per workspace, with a tier cap.** The same workspace can no longer be opened twice — the second instance exits with the holder's PID — so concurrent muxit processes always own distinct workspaces. The new `concurrent-instances` license feature caps how many workspaces a user can run at once on the same machine (Free 1, Maker 2, Pro 5, Lab/Enterprise unlimited); the cap is enforced via a per-process lock file on Windows (`%LOCALAPPDATA%\Muxit\locks\Instance-N.lock`) and a Unix-domain socket on Linux/macOS, both of which the OS releases on process death regardless of which thread originally acquired them. Licenses are now stored per-machine (under `~/.muxit/` or `%LOCALAPPDATA%\Muxit\`), so a single activation covers every workspace on the same computer; on first launch the migration scans every catalogued workspace for a `.license` that actually contains a key (paired with its signed `.license-proof`) and copies that one up. Launching `muxit` without `--workspace` when more than one workspace is registered opens a browser-based workspace picker. If the cap is already reached, the picker shows a tier-aware banner up front (`Multi-instance limit reached. Your <Tier> tier allows up to N concurrent muxit instances…`) and disables every workspace button instead of redirecting to a dead origin. Port collisions auto-bump to the next free port for the current run only — the workspace's `server.json` is no longer rewritten, so a solo relaunch returns to the configured port. Deactivating a license now sticks across restarts: the server-signed proof is deleted alongside the local `.license`, and the `Deactivate` button is visible whenever any non-free tier is active even if the cached key is missing. The active workspace name is shown in the tray menu (`Muxit — <name> (port N)`) and next to the wordmark in the GUI titlebar.
- **Python connector support is now front-and-centre in the docs and on the website.** The marketing site's "How it works" page lists Python as a fourth driver format alongside SCPI / JS / DLL, and the makers and professionals pages pitch the "drop a `.py` file in `workspace/python/` and a connector calls its functions" path. In the docs, getting-started gains a new "I already have a Python script that talks to my device" path, system-requirements documents the optional Python 3.10+ dependency, and a new [Python Connectors guide](https://docs.muxit.io/guides/python-connectors.md) covers the generic `Python` driver — properties, `init` / `shutdown`, per-script venvs, common pitfalls — without making readers pick through the full SDK reference.
- **AI-assisted SCPI connector authoring is now its own license feature.** Added `scpi-authoring` (defaults to Maker tier, matching prior behavior) so the authoring workflow — `probe_scpi_device`, `validate_connector_config`, `search_manual`, `read_manual_pages`, and the rest of the SCPI authoring tool set — can be moved between tiers in `AppSettings.cs` without touching the rest of the chat surface. The intent classifier now skips the SCPI authoring group entirely when the feature is blocked, so blocked tiers no longer pay for the SCPI system-prompt fragment or the OpenRouter web-search plugin on irrelevant turns.
- **Window title now shows the active workspace.** The browser/Electron tab title and the server's console window (Windows taskbar tooltip) both read `muxit-io [WorkspaceName]`, making it easy to tell multiple muxit.io instances apart at a glance.

### Bug Fixes

- **Pricing tiers now match what's actually shipped.** Pro-tier `concurrent-instances` was capped at 5 in `AppSettings`, but the pricing page promises unlimited — bumped Pro to `-1` so the cap matches the marketing. Autonomous agents are now flagged *(in development)* on the pricing card and comparison table since the `agents` feature is still `Disabled = true` in code. Added Startup scripts and Video recording rows to the pricing card and comparison table so the silent Maker-tier gates on those features are visible to users.
- **Pricing and AI docs no longer falsely claim `ai(prompt, image)` requires Pro.** The script-side `ai()` global only checks the `"ai"` license feature (Maker tier), so passing a base64 JPEG to it from a script works on Maker — that was already true in the code, but the docs and pricing card said otherwise. The Pro-tier "Vision AI" benefit is reframed around what's actually gated: the agentic vision **tools** in the Chat Panel and MCP (`take_snapshot`, `identify_objects`, `locate_object`, OpenCV trackers, spatial mapping). Maker = explicit `ai(prompt, image)` calls from your scripts; Pro = the AI assistant decides when to look.
- **Security: close N1–N4 from the 2026-05-07 follow-up audit.** License-proof verification now binds the signed envelope to the local machine fingerprint — copying a paid user's `.license-proof` to another machine no longer elevates that machine's tier (audit N1). JS and Python drivers can no longer opt out of safety gates: `meta.requiresSafetyGates: false` (JS) and `META["requiresSafetyGates"] = False` (Python) are ignored with a stderr warning, since neither tier has a per-driver signing path that would prevent a hand-dropped driver from bypassing every limit, confirm and audit row (audit N2). The `MUXIT_PROXY_BASE_URL` and `MUXIT_DISABLE_INSTANCE_LIMIT` environment-variable bypasses are now gated on `MUXIT_DEV=1`, so production binaries silently ignore them — without that gate, an end user could redirect license-flow calls to a dead URL (defeating the B2 trial ledger) or bypass the per-tier concurrent-instances cap by setting one variable (audits N3, N4). Built-in drivers that opt out via the C# class override (Webcam, FileAccess, Onvif, MqttBridge) and DLL drivers that opt out via a signed assembly attribute are unaffected — those paths continue to honour declared opt-outs.

## v0.25.47 — May 5, 2026

### Cleanup — drop legacy HMAC license-cache reader

The one-release migration helper from v0.25.46 has done its job. Removed `MuxitServer/Licensing/LegacyHmacReader.cs` and the legacy-format detection branch in `LicenseManager.Cache.cs:LoadFromDisk` — the cache loader is now a plain JSON read. Anyone still on a build older than v0.25.46 who upgrades through this version will see "license invalidated, please re-activate" on first launch and need to paste their key once. Acceptable since the public release happens after this version.

## v0.25.46 — May 5, 2026

### Security — server-signed license cache (audit B1 + B2)

The local `.license` cache used to be HMAC-signed with a key derived from a hidden salt file plus `MachineName`/`UserName` — every input the user could read, so anyone with workspace access could forge `TierId="lab"` with full entitlements (audit B1). Trials lived in the same file, so deleting it granted a fresh trial (audit B2).

- **Tier is now gated by a server-signed proof.** A new `.license-proof` file stores an RSA-SHA256 envelope returned by `POST https://api.muxit.io/v1/license/sign`. On startup the proof is verified against an embedded RSA-4096 public key (`MuxitServer/Licensing/LicensePubKey.cs`) and, if its `valid_until` is still in the future, its `tier` overrides the local `.license`. Missing / tampered / expired → user is demoted to `free` until the next online re-validation.
- **`.license` is now plaintext JSON.** It still holds local bookkeeping (`StartupCount`, `LastSeen`, `FingerprintComponents`, customer info, `BaseLicenseKey` and `BaseInstanceId` for re-validation), but editing it can no longer escalate tier — the proof is the source of truth.
- **Trials moved to a server-side ledger.** `LicenseManager.StartTrial` now calls `POST /v1/license/trial-start` with the machine fingerprint; the proxy holds an idempotent `(fingerprint, feature_id)` record. Deleting the workspace no longer grants a fresh trial. `StartTrial` is async now (`Task<bool>`).
- **Soft cutover for existing installs.** A read-only `LegacyHmacReader` still loads the old HMAC cache once on startup so cohort-1 customers don't see a "license invalidated" prompt; the next online re-validation upgrades them to the new format and deletes the legacy `.license-salt` file. Lifespan: one release.
- **New keypair, separate from driver signing.** Generated by `tools/generate-license-signing-key.csx` (PKCS#8 PEM, not .NET XML — Web Crypto in the worker imports PEM natively). Private half lives only in the Cloudflare Worker secret store; same key is never used to sign DLLs.
- **`MUXIT_PROXY_BASE_URL` env-var override** added to `SignedLicenseClient` and `TrialClient` for staging / local-wrangler-dev testing without touching source.
- Companion changes ship in **MUXITPROXY** (signing endpoint, trial-start endpoint, `trial_starts` D1 table, `LICENSE_SIGNING_PRIVATE_KEY` worker secret).
- Crypto roundtrip can be verified offline via `dotnet script tools/verify-license-signing.csx`.

## v0.25.45 — May 4, 2026

### Connector configs: `c` parameter replaced by `driver` closure variable

Custom methods, getters, and setters in connector configs no longer receive
the driver proxy as a leading argument. Instead, the driver is in scope as
the closure variable `driver`. Function signatures now match the script-side
call exactly:

```js
methods: {
  start:  { fn: () => driver.startPolling() },
  rampTo: { fn: (target) => { driver.voltage = target; } },
}
properties: {
  voltage: {
    get: () => driver.voltage,
    set: (v) => { driver.voltage = v; }
  },
  power: () => driver.voltage * driver.current,
}
```

This removes the asymmetry between how a script calls a connector
(`psu.rampTo(5)`) and how the connector declared the method
(`(c, target) => …`), and gets rid of the cryptic `c` parameter.

**Breaking change.** Configs still using the old `(c) => c.…` shape will
fail at runtime — V8 throws because `c` is no longer bound. All bundled
connectors, driver template stubs, and docs have been updated to the new
form. Update any pre-release config in `workspace/connectors/`.

## v0.25.44 — May 4, 2026

### Python connector init runs in the background — UI shows live status

A multi-minute pip-install + model-load on connector activate was blocking the synchronous `InitAsync` path. Even with last commit's 30-minute timeout, the user got a frozen UI while torch downloaded — and a single bad driver could hang the whole connectors panel for everyone else trying to enable theirs. Replaced with a fire-and-forget background init + live status broadcast.

**Server side** (`MuxitServer/Drivers/PythonDriverHost.cs`)
- `InitAsync` now returns immediately after the synchronous catalog / interpreter pre-checks. The actual venv setup, pip install, subprocess launch, and init RPC run on a `Task.Run` worker (`RunInitInBackgroundAsync`) with a per-instance `CancellationTokenSource`.
- New `PythonInstanceState` enum: `Loading | Ready | Error | Cancelled`, plus a `PythonInstanceStatus` record stored in `_instanceStatus`. Updated at every phase boundary (`Preparing virtual environment...` → `Installing requirements...` → `Starting subprocess...` → `Initialising driver...` → `Ready`). Latest pip / venv output line is mirrored into the message field too, so the UI gets a flowing progress string.
- New `EnsureReady(instanceId, verb)` helper. `GetPropertyAsync`, `SetPropertyAsync`, `ExecuteActionAsync` call it before dispatching — calls against a still-loading connector throw a clear `"Python connector 'foo' is not ready (loading): Installing requirements... Cannot execute action 'speak' until initialisation completes."` instead of either silently waiting or timing out arbitrarily.
- `ShutdownAsync` now cancels the in-flight init token before tearing down. Disabling the connector mid-install kills the running pip subprocess (via `proc.Kill(entireProcessTree: true)` in `PythonVenvManager.RunStreamingAsync`'s new `OperationCanceledException` branch) instead of leaving torch's wheel-builder children running. `ShutdownAllAsync` includes loading instances too.
- The init RPC's own timeout is back to a sane 5 minutes — pip install (which has no timeout) is now in the background, so the RPC only covers the model-load step inside the user's `init()`.

**Wire layer** (`MuxitServer/WebSocket/EventBridge.cs`)
- New `connector.status` rebroadcast from the EventBus to all WS clients: `{ connector, driver, state, message }`. The existing `driver.python.install` event continues to carry per-line pip output for the server log; `connector.status` is the higher-level state machine the UI binds to.

**UI** (`web-ui/src/hooks/useServer.js`, `web-ui/src/components/ConnectorBrowser.jsx`)
- `useServer` adds a `connectorStatus` state map keyed by connector name; subscribes to `connector.status` messages and updates the entry on every transition.
- `ConnectorCard` reads its entry from `server.connectorStatus[name]` and renders a one-line status badge below the header when state ≠ `ready`: a spinning gear + the latest message for `loading`, a red ✗ + error message for `error`, a muted ⊘ + reason for `cancelled`. Disappears once the connector is ready, leaving the normal card layout.

**User-visible effect**
- Activating `python-chatterbox` now returns instantly. The connector card immediately shows `⚙ Installing: Creating venv at python/.venvs/chatterbox`, then a flow of `[pip] Collecting torch ...` lines, then `Loading chatterbox model on cpu (first run downloads ~2GB; subsequent runs are cached)...`, then disappears when the connector is ready. Other connectors can be enabled / used in parallel; nothing blocks on chatterbox's install.
- Disabling the connector mid-install kills pip and the model download cleanly. Re-enabling starts fresh.

## v0.25.43 — May 4, 2026

### Three fixes that turned the chatterbox first-run from "broken" to "working but slow"

A user activating the `python-chatterbox` example connector hit:

  `Failed to init connector 'python-chatterbox': Python driver did not respond to 'init' within 60000ms`

…after seeing only `Installing requirements from chatterbox.requirements.txt (first run can take a while)` and then no further log output for a minute. Three independent issues were combining:

- **Init RPC timeout was 60s.** Way too short for any ML driver — chatterbox's `ChatterboxTTS.from_pretrained()` downloads several GB of model weights from HuggingFace and warms them into RAM, easily 5–15 minutes on a fresh machine. Bumped to 30 minutes in `PythonDriverHost.InitAsync`. Pip install (which precedes init) already had no timeout, so this just brings init in line. Genuinely runaway processes still get caught; users who want to interrupt earlier can disable the connector.
- **Pip's progress bar was invisible.** `pip install` writes its download progress with `\r` (no newline), and .NET's `Process.OutputDataReceived` only fires on `\n`. So between download-step lines (which can be several minutes apart for a 2 GB wheel), the user saw absolute silence and assumed pip had hung. Added `--progress-bar off` to the pip invocation in `PythonVenvManager.PipInstallAsync` so each download step prints as a flushed line.
- **The chatterbox example script was silent during `init()`.** Even with pip output flowing, the first `from chatterbox.tts import ChatterboxTTS` plus the model load can take another minute or two. The example now prints stderr heartbeats (`Loading chatterbox library...`, `Loading chatterbox model on cpu (first run downloads ~2GB; subsequent runs are cached)...`, `Chatterbox ready (sample rate 24000 Hz, ...)`) via a small `_say()` helper that goes through `sys.stderr` so it can't collide with the JSON-RPC channel. The host's stderr pump forwards them verbatim with the `[connector-name] stderr:` prefix.

Net effect for a user activating the chatterbox connector for the first time: continuous progress output throughout the multi-minute first install + model load, instead of the previous "log line, silence, timeout error" experience.

## v0.25.42 — May 4, 2026

### Chatterbox TTS example for the generic Python driver

Adds a fourth example to the workspace template demonstrating the
heavy-dependency case for the Tier 2 generic Python driver:

- `workspace/python/chatterbox.py` + `chatterbox.requirements.txt` — TTS via [chatterbox-tts](https://github.com/resemble-ai/chatterbox).
- `workspace/connectors/python-chatterbox.js` — connector exposing `speak()`, `speakWithVoice()`, `speakAs()`, plus `sampleRate` / `device` / `outDir` properties.

The flow is the same as the existing `http-probe` example, just with a much larger first-install cost: activating the connector for the first time creates `workspace/python/.venvs/chatterbox/`, pip-installs torch + transformers + chatterbox into it (a couple of GB, several minutes — output streams to the server log so you can watch progress), then loads the model. Subsequent activations skip pip and start in a few seconds; the loaded model stays in memory across `speak()` calls.

Each call writes a WAV file under `workspace/data/chatterbox/` and returns the absolute path. Pipe that path into a player, an `<audio>` element, or any downstream connector that handles audio playback. The companion docstrings populate the API Reference tab so users see usage hints (`device` config, voice cloning via `voice` parameter, output filename overrides) without leaving the driver page.

This commit is not smoke-tested in CI — installing torch from the chatterbox dependency tree takes too long for the test runner. The plumbing it relies on (per-script venv + Python tier dispatch) is covered by the existing `http-probe` and counter / hello tests.

## v0.25.41 — May 4, 2026

### Driver detail page surfaces the manifest details + Python tier label

Two follow-ups to the driver page after testing the Python driver in-app:

- **Tier badge for Python drivers no longer shows "Unknown".** The two driver-detail components in the web UI (`DriverDetailPage.jsx` for the standalone Drivers panel, `DriverDocViewer.jsx` for the in-editor doc viewer) had their tier label maps hard-coded for tiers 0/1/3 only. Both now include `2: 'Python'`. The "trust badge" ladder on `DriverDetailPage` similarly gains a `Community (Python)` arm.
- **API Reference tab now renders manifest `details` as a "Documentation" section.** The earlier change wired `details` through `driver.schema` for the in-editor viewer, but the user-facing Drivers panel uses `marketplace.detail` which wasn't including the field. Added `details = localEntry?.Details` to that handler's response, then rendered it as a top-of-tab Documentation section using the existing `DetailsMarkdown` component (now exported from `DriverDocViewer`). Imports the existing `driver-doc.css` so the markdown styling (paragraphs, lists, code blocks) applies in the standalone page too.

Effect for the Python driver: clicking it in the Drivers panel now shows the badge `Community (Python)` instead of `Unknown`, and the API Reference tab leads with the ~4 KB markdown documenting layout, the `requirements.txt` lifecycle, examples, and conventions — instead of just the Connector Template snippet. Same plumbing benefits any driver (DLL / JS / built-in) whose manifest declares a `details` field.

## v0.25.40 — May 4, 2026

### Driver doc viewer surfaces long-form `details`

The driver detail page in the Drivers panel previously had room only for a one-line description and the property/action tables. Drivers like the new generic `Python` one needed more — how `requirements.txt` works, where scripts live, what conventions to follow — and there was nowhere to put it without bloating the always-visible description (which feeds into the AI system prompt).

Three coordinated changes:

- **`manifest.json` gains an optional `details` field.** Markdown, rendered as a collapsible "Show details" section in `DriverDocViewer.jsx` directly under the description. Threaded through all three tiers: `DriverManifest` → `DriverEntry.Details` → the `driver.schema` WebSocket response.
- **Per-action and per-property `details`** are now sent in the schema response (the descriptor records always carried the field; the WS handler just wasn't including it). The existing `DetailsDisclosure` component already rendered them when present, so the change immediately unlocks more useful entries on every driver.
- **The generic Python driver's introspection now splits docstrings into description + details.** The first line of a function's docstring becomes its action's `description` (always-on, in the AI prompt); the rest becomes `details` (markdown, surfaced on demand). Same split for properties via the `get_<x>` docstring. So writing a normal Python docstring on `def head(url):` automatically populates both fields in the UI.

Concrete payoff: the `Python` driver's manifest now ships a ~4 KB markdown details block covering layout, the `requirements.txt` lifecycle, examples, and limitations — visible by clicking "Show details" on the driver page. The shipped example scripts (`hello.py`, `counter.py`, `http-probe.py`) gain richer docstrings so each action / property has both a one-liner and a paragraph of context.

The `details` field is optional; existing drivers (built-ins, JS, DLL packages) keep rendering exactly as before until their manifests add the field.

## v0.25.39 — May 4, 2026

### Fix: connector calls on the generic `Python` driver were rejected

`connector("python-hello").greet("world")` was throwing `Driver has no property or action 'greet'` because the connector proxy authorises calls against the driver's catalog-time META, and the generic `Python` driver's META is intentionally empty (its actions are dynamic — they come from whichever user script the connector points at).

Fixed by mirroring the per-instance schema mechanism the DLL tier already had for `GenericScpi`: after `init()` returns, the host now sends a new `schema` RPC to the Python driver subprocess. The generic driver responds by introspecting the loaded user module:

- top-level callables (excluding `init`, `shutdown`, and underscore-prefixed names) → actions, with the function's first docstring line as the description
- paired `get_<x>` / `set_<x>` → R/W property `<x>`
- unpaired `get_<x>` → read-only, unpaired `set_<x>` → write-only

Typed `Driver` subclasses get a sensible default — `schema()` falls back to the values declared in `META` — so existing typed drivers don't change.

`PythonDriverHost.GetDriverMetaForInstance(instanceId)` exposes the per-instance schema; `DriverRegistry.GetDriverMeta` consults it first for Python instances and falls back to the catalog-level meta for instances that haven't completed init yet. The schema is cleaned out on `ShutdownAsync` so a re-activate gets a fresh introspection.

After this, `c.greet({ name })` from a connector method body lands on the driver's `execute("greet", {...})` and dispatches through to `module.greet(name="...")` as intended.

## v0.25.38 — May 3, 2026

### Python tier — examples by connector, one driver to install

The two scaffolding-style Python drivers introduced alongside the tier (`drivers/py/example/` and `drivers/py/example-with-deps/`) are removed. They duplicated what the generic `muxit/python` driver now does, and shipping three Python `.muxdriver` packages where one will do made the marketplace listing confusing.

In their place, `workspace-template/python/` now ships three working user scripts and `workspace-template/connectors/` ships matching connectors so a freshly seeded workspace boots with usable Python examples:

- **`hello.py`** + `python-hello.js` — minimal, no dependencies. Single `greet(name)` action.
- **`counter.py`** + `python-counter.js` — adds state; demonstrates `get_<x>()` / `set_<x>(value)` properties and `init(config)`.
- **`http-probe.py`** + `python-http-probe.js` — adds `requests` as a runtime dependency; the sibling `http-probe.requirements.txt` triggers the per-script venv flow on first activation.

`workspace-template/python/README.md` documents the conventions (one file per script, optional `init` / `shutdown`, `get_<x>` / `set_<x>` properties, `<stem>.requirements.txt` for deps).

`lib/muxit-menu/index.js` updated so `python/` is part of the workspace seed (option 17), the empty-workspace dir creation list (option 16), and the workspace status report (option 20).

The driver-side regression test (`drivers/py/python-runner/`) and the muxit_driver SDK are unchanged — the deleted drivers were only example payloads, not part of the platform.

## v0.25.37 — May 3, 2026

### Generic `Python` driver — write functions, skip the boilerplate

A new built-and-shipped Python driver (`drivers/py/python-runner/`, manifest id `muxit/python`) lets a connector point at any `.py` file in `workspace/python/` and exposes that file's top-level functions as RPC actions / properties. Users who want to glue an existing Python library to a Muxit connector no longer have to subclass `Driver` or wire up a JSON-RPC dispatch — they drop a script with bare functions, optionally a sibling `<name>.requirements.txt`, and reference it from the connector's `config.script`.

```python
# workspace/python/chatterbox.py
def init(config): ...
def speak(text): ...      # ← connector().speak({ text }) lands here
def get_status(): ...     # ← connector().status read
```

```js
{ driver: "Python", config: { script: "chatterbox" }, methods: { ... } }
```

Per-script venvs at `workspace/python/.venvs/<stem>/` give clean dependency isolation between scripts (one with torch, one with pyserial, no collisions). First activation creates the venv and pip-installs the requirements with line-by-line output streaming to the server console. Subsequent activations check the SHA-256 of the requirements file against a stamp and skip pip when nothing changed (~150ms warm start). Migration to a typed `Driver` subclass is mechanical when a script outgrows the generic dispatch.

Plumbed through end-to-end: `DriverRegistry.CreateInstanceAsync` injects `_workspacePath` into the config dict for Tier 2 drivers (mirroring the built-in driver path), so the generic driver can resolve `workspace/python/<script>.py` reliably regardless of what the user wrote in the connector config.

New "Two ways to use Python" + "Generic `Python` driver" sections in `docs-site/reference/driver-sdk-python.md`.

## v0.25.36 — May 3, 2026

### Python driver debugging helpers

Two small, no-overhead additions to the Python driver SDK so a problem in a Tier 2 driver is a few minutes to track down instead of "stare at stderr and guess."

- **Tracebacks in error responses.** When a driver method raises, the JSON-RPC error sent to the host (and on to the script / dashboard / AI) now includes a compact location excerpt — first line is the exception, then up to 3 frames of the user's own code (SDK frames are filtered out). Looks like `KeyError: 'unknown property: nope'\n  at get() in mydriver.driver.py:62`. The full traceback still goes to stderr / server console as before.
- **Optional debugger attach via `MUXIT_PYTHON_DEBUG`.** Setting the env var to a port number on the driver's process makes the SDK call `debugpy.listen(("127.0.0.1", port))` at startup and wait for a client before `init`. Attach VS Code's "Python: Attach" launcher and step through your driver. No-op when the env var isn't set; degrades to a one-line stderr hint if `debugpy` isn't installed (add it to `requirements.txt` to use). `pdb.set_trace()` continues to **not** work — the subprocess' stdin is busy with JSON-RPC.

New "Debugging" section in `docs-site/reference/driver-sdk-python.md` covers the three escalation paths: read the error response, run the driver standalone with `--scan` / `--instance`, attach `debugpy`. Plus a "Common pitfalls" subsection (`(non-json stdout)`, module-level heavy imports, hangs during pip install, missing `python3-venv` on Debian).

## v0.25.35 — May 3, 2026

### Features

- **Python drivers auto-install their dependencies.** A driver that ships a `requirements.txt` next to its `.driver.py` now gets a per-driver virtual environment (`.venv/`) created in its package cache dir on the first connector activation. Pip runs against that venv and the driver subprocess is launched with the venv's `python`, so `import torch` (or anything else inside `init()`) resolves to a clean per-driver install. New `MuxitServer/Drivers/PythonVenvManager.cs` handles the lifecycle: hashes `requirements.txt` into `.venv/.muxit-req-hash` so subsequent activations skip the install when nothing changed; streams pip's stdout/stderr line-by-line to the server console and to a new `driver.python.install` EventBus event so the UI can show progress while the user waits. Different drivers can pin conflicting versions of the same package without interfering — each lives in its own venv. Cached venv start time is ~150ms; first install runs as fast as pip + the network can manage (~2s for `requests`, several minutes for torch).
- **Example driver with deps.** `drivers/py/example-with-deps/` (PyHttpProbe) demonstrates the flow with a small `requests` dependency. Validates + builds + runs end-to-end via the new venv plumbing.

### Known limitations

- Native wheels (torch, opencv) sometimes need system-level build tools or libraries; pip failures surface in the driver's init error with the full transcript above. Adding a "diagnose missing system deps" pass is on the roadmap.
- On Debian/Ubuntu the system Python may not include the `venv` module by default (`apt install python3-venv` once if you see `python -m venv` failing).
- Loose `.driver.py` files dropped into `workspace/drivers/` (no `.muxdriver` packaging) don't get a managed venv — they use the system interpreter directly. This is the dev workflow; packaged drivers are the user-facing path.

## v0.25.34 — May 3, 2026

### Features

- **Python driver tier (Tier 2).** Drivers can now be authored in Python — a new `.driver.py` extension alongside the existing `.driver.js` and `.dll` tiers. Each active connector spawns its own Python subprocess; MuxitServer talks to it over line-delimited JSON-RPC on stdin/stdout (`init` / `get` / `set` / `execute` / `shutdown`). Drivers subclass `muxit_driver.Driver` and call `run(YourDriverClass)`. Wired through end-to-end: `DriverTier.Python = 2` (`MuxitServer/Drivers/DriverTypes.cs`), `PythonDriverHost` + `PythonDriverInstance` for subprocess + IPC, `PythonRuntimeManager` to detect a usable interpreter (`MUXIT_PYTHON` env var → `python3` → `python`, requires ≥ 3.10), `DriverPackageStore` recognises `*.driver.py` packages, manifest schema accepts `tier: 2`, `node drivers.js build` packages Python drivers (auto-vendoring the `muxit_driver` SDK into every `.muxdriver` so installed drivers don't need anything on `PYTHONPATH`). Use it for Python-only ecosystems (numpy, torch, instrument SDKs); JS remains the right choice for serial/TCP instruments.
- **Python interpreter detection is optional.** If no usable Python is found at startup, the server keeps booting; Python drivers (if any are installed) surface a warning at scan time instead of failing the run. Set `MUXIT_PYTHON` to a full interpreter path to override probing. See `docs-site/reference/driver-sdk-python.md` for the SDK reference, manifest, and wire protocol.
- **Example Python driver.** `drivers/py/example/` ships a deps-free counter+greeter driver as a starting point and as the regression target for the JSON-RPC bridge.

### Known limitations

- Python drivers are free-only — premium signing isn't implemented for the Python tier yet (`PYTHON_PREMIUM_FORBIDDEN` validator rule).
- Runtime dependencies declared in a driver's `requirements.txt` are bundled into the `.muxdriver`. Auto-installation into a per-driver venv landed in v0.25.35.

## v0.25.33 — May 4, 2026

### CSP: allow `'wasm-unsafe-eval'` for the opus-decoder polyfill

The dashboard's strict Content-Security-Policy was blocking
`WebAssembly.compile()` (`script-src 'self' blob:` doesn't permit WASM
compilation), so the `opus-decoder` polyfill threw on load and the
dashboard went silent on insecure-context connections.

Both the docs CSP and the SPA CSP now include `'wasm-unsafe-eval'` in
their `script-src` directive. This is a much narrower permission than
`'unsafe-eval'` — it allows `WebAssembly.compile/instantiate` only,
not arbitrary `eval()` or string-to-code conversion. No other directive
changed.

## v0.25.32 — May 4, 2026

### Audio renderer: pass channel count into the WASM Opus decoder

Fix for "no sound when accessing the dashboard remotely (e.g.
`http://192.168.x.x:8765`)": the `opus-decoder` constructor defaults to
**2 channels**, but the encoder produces mono. A mono Opus packet
decoded by a 2-channel decoder fails silently and returns
`samplesDecoded: 0`, which the renderer was discarding without any log
output — so the dashboard just went quiet.

- **WASM polyfill now gets `{ sampleRate, channels }`** from the wire
  payload. WebCodecs already configured channels correctly; the WASM
  path was missing it.
- **Better diagnostics.** When the decoder returns 0 samples, log the
  configured channels / sampleRate and any decoder errors once per
  stream so a future regression is visible in DevTools.
- The reason this only manifested on remote connections: WebCodecs is
  gated to **secure contexts** (HTTPS or `localhost`). Connecting from
  another machine uses `http://<lan-ip>` which is not a secure context,
  so `window.AudioDecoder` is undefined and the renderer fell through
  to the WASM polyfill path. Local browsers loading via `localhost`
  never hit it.

## v0.25.31 — May 4, 2026

### Audio renderer: jitter buffer + mobile fallback

Two fixes for the browser-side audio path.

- **Cracking on desktop, fixed.** `ServerAudioRenderer` now schedules
  buffers ~100 ms ahead of `ctx.currentTime` (the jitter buffer)
  instead of letting decode latency push `nextStartTime` into the past.
  The previous behaviour was the classic Web Audio streaming bug —
  async decode let `currentTime` overtake the cursor, the
  `Math.max(now, …)` clamp left a silent gap at every buffer boundary,
  and you'd hear a click ~50 times a second. Underruns are now detected
  and recovered by resetting the cursor with a fresh 100 ms lookahead.
- **48 kHz `AudioContext`.** Created with `{ sampleRate: 48000 }` so
  decoded 48 kHz buffers don't get implicitly resampled to the device's
  native rate (typically 44.1 kHz on macOS/iOS). Falls back to the
  default-rate constructor on browsers that throw on the options arg.
- **Opus on mobile / older browsers.** The renderer now lazily imports
  the [`opus-decoder`](https://github.com/eshaz/wasm-audio-decoders)
  WASM polyfill when `AudioDecoder` (WebCodecs) is missing. Covers iOS
  Safari < 16.4, in-app WebViews, and other browsers where WebCodecs
  isn't shipped or doesn't support raw Opus. The polyfill bundle is
  only fetched on browsers that need it; WebCodecs hosts pay nothing
  extra.
- The PCM16 fallback path goes through the same shared scheduler, so it
  benefits from the jitter buffer too.

## v0.25.30 — May 4, 2026

### Audio encoding moves into the host

The Opus encoder (Concentus) moved out of the AudioSynth driver and into
a single shared `MuxitServer.Audio.AudioStreamEncoder`. Drivers that emit
audio now hand the host raw float PCM through a new SDK property and the
host owns codec, framing, pacing, EventBus emission, and the stop-frame.
This is the right shape for the upcoming TTS connectors (chatterbox,
cosyvoice, OpenAI TTS, ElevenLabs) — they can plug in without bundling
their own copy of Concentus, and a future swap to binary WS frames stays
a single-place change.

- **SDK addition.** `IConnectorDriver` gains
  `Func<float[], AudioFrameInfo, CancellationToken, Task>? AudioStreamEmitter`,
  alongside the existing string `StreamEmitter`. New value type
  `Muxit.Driver.Sdk.AudioFrameInfo(int SampleRate, int Channels)` with
  a convenience `AudioFrameInfo.Mono48k`.
- **Host addition.** New `MuxitServer.Audio.AudioStreamEncoder` wrapping
  Concentus. `DriverRegistry.InitBuiltInAsync` and
  `DllDriverHost.InitAsync` wire `driver.AudioStreamEmitter` to it
  alongside the existing string `StreamEmitter` wiring.
- **`drivers/Muxit.Driver.AudioSynth`** bumped to **1.4.1**. Removed the
  Concentus PackageReference and the in-driver Opus encoding code;
  `StreamSamplesAsync` now just `await`s the host emitter.
- **Wire format unchanged.** Browser still sees the same JSON envelope
  (`{ op, data, sampleRate, channels, format: "opus", frameSize }`) and
  `ServerAudioRenderer` is untouched.
- JS drivers (Tier 1) still go through the legacy string emitter — the
  audio emitter is C#-only for now.

## v0.25.29 — May 4, 2026

### Audio streams are now Opus-encoded by default

The `audio` stream wire format switches from base64 PCM16 to base64 Opus
packets (32 kbit/s VBR, 20 ms frames at 48 kHz mono). The driver-side
encoder is [Concentus](https://github.com/lostromb/concentus) — pure
managed C# with no native deps, so the self-contained
`muxit-win-x64.zip` release stays single-binary clean. On the wire,
sustained audio drops from ~1 Mbit/s (base64 PCM16) to ~100–200 kbit/s.

- **AudioSynth driver** bumped to **1.4.0**. New stream chunk shape:
  `{ "op": "chunk", "data": "<base64 opus packet>", "sampleRate": 48000,
  "channels": 1, "format": "opus", "frameSize": 960 }`. Internal
  `ToneGenerator` now renders at 48 kHz so the encoder gets samples at
  one of Opus's native input rates without resampling. Server-side
  NAudio playback (`output: "server" | "both"`) is unchanged.
- **`web-ui/src/audio/ServerAudioRenderer.js`** decodes Opus packets via
  the browser-native WebCodecs `AudioDecoder` (Chrome 94+, Safari 16.4+,
  Firefox 130+ — universal in 2026). Decoded `AudioData` is copied into
  a Web Audio `AudioBuffer` and scheduled on the same per-connector
  `nextStartTime` cursor as before, so the rest of the pipeline is
  unchanged. The legacy PCM16 path (`format: "pcm16"`, `pcm` field)
  remains as a fallback for any emitter that can't link Concentus.
- **`docs/reference/audio-streaming.md`** updated: the remaining migration step is
  now binary WS frames (when JSON+base64 envelope overhead becomes the
  bottleneck or when video / file-transfer streams want the same binary
  pipeline). Until then, JSON-wrapped Opus stays as the simpler thing
  that works.
## v0.25.28 — May 4, 2026

### Fixes

- **Remote browser tabs hung on "disconnected" after a server restart.** A remote client stores its login token in `sessionStorage`, but the server's session table is in-memory — restarting the server invalidates every previously-issued token. The browser can't read the 401 returned by a failed WebSocket upgrade, so `useServer` would happily keep retrying with the dead token forever and the user had to do a hard refresh to recover. The fix is two-sided: `/api/auth/status` now reports `sessionValid` when the caller presents an `X-Auth-Token`, and both `App.jsx` (on mount) and `useServer.connect()` (before each WebSocket attempt) verify a stored token via that endpoint. When the server says the token is dead, the client clears `sessionStorage`, drops the cached token in `api-shim.js`, and dispatches `muxit-login-required` so the login page shows up automatically. `__muxitSetAuthToken(null)` now also removes the sessionStorage entry, so the api-shim cache and storage stay in sync.

## v0.25.27 — May 3, 2026

### Audio is now a first-class driver stream

Server-side drivers can now stream audio to every connected dashboard, alongside video and other stream kinds. AudioSynth gains a multi-mode `output` config (`server` | `browser` | `both`, default **`browser`**) that picks where the synthesised audio actually plays. **Cross-platform fix as a side effect:** AudioSynth used to be Windows-only via NAudio; in `browser` mode it now works on Linux and macOS hosts because the audio is rendered server-side and decoded in the browser via the Web Audio API. This is also the unifying primitive for upcoming server-side TTS connectors (chatterbox, cosyvoice, OpenAI TTS, ElevenLabs) — they will plug into the same path with no new infrastructure on the client side.

- **AudioSynth `output` config.** New connector field with three values:
  - `browser` *(default)* — every connected dashboard plays the audio. Multi-client by construction (broadcast through the existing per-client stream subscription model). Cross-platform.
  - `server` — original v1.2 NAudio path, unchanged. Still Windows-only.
  - `both` — runs the two paths in parallel; the local-output half fails silently on non-Windows hosts so the streaming half always works.
- **Wire format.** Per-chunk JSON in the `data` field of `stream.data`: `{ "op": "chunk", "pcm": "<base64-pcm16>", "sampleRate": 44100, "channels": 1, "format": "pcm16" }`. A `{ "op": "stop" }` frame is emitted on cancellation so dashboards drop their queued audio. Real-time pacing (~50 ms chunks) so a client can schedule chunks back-to-back without running its jitter buffer dry.
- **`web-ui/src/audio/ServerAudioRenderer.js`** — singleton on the dashboard side. Lazily creates an `AudioContext`, primes it on the first user gesture, decodes incoming PCM16 frames to `AudioBuffer`s, and schedules them per-connector with a `nextStartTime` cursor so chunks for the same source play seamlessly. Different connectors play independently and may overlap. **Not** TTS-specific; any future driver that emits an `audio` stream goes through this single playback path.
- **`web-ui/src/hooks/useServerAudio.js`** — auto-subscribes to every connector that declares an `audio` stream (via `schema.streams`). Mounted in `Shell.jsx` and `MobileShell.jsx`.
- **`web-ui/src/hooks/useServer.js`** — emits a per-chunk `muxit-stream-data` window event in addition to the React-state path. Audio chunks need every frame; the existing `requestAnimationFrame` coalescing on `streamData` is right for video (only the latest matters) but wrong for continuous audio.
- **`script.say()` is unchanged** — still routes through the browser's Web Speech API via the FIFO `TtsController`. For server-side voices the canonical pattern is explicit: `connector('chatterbox').speak("...")`. No implicit re-routing of `say()`, no global config field that would change its behaviour invisibly.
- **TODO documented:** raw PCM16-in-base64 trades bandwidth for simplicity (~700 kbit/s per active stream). Migration plan to Opus + binary WS frames + MSE lives in `docs/reference/audio-streaming.md`. The JSON wrapper keeps `format` as a discriminator so adding `format: "opus"` later is forward-compatible.

## v0.25.26 — May 3, 2026

### Text-to-speech rewrite

The dashboard's TTS pipeline was rewritten around a single shared controller (`web-ui/src/tts/TtsController.js`) with a strict FIFO queue and a pluggable provider abstraction. Previous symptoms — "TTS sometimes works, sometimes doesn't, and clicking the speaker button releases a buffer of accumulated speech" — came from `useTTS` (chat) and `useScriptSpeech` (script `say()`) writing directly to `window.speechSynthesis` without coordination, plus a gesture gate that accumulated arbitrary callbacks until any user click drained them all at once. The new controller serialises every utterance through one worker, primes the speech engine on the first user gesture once and never queues callbacks outside the job FIFO, so a late click can never release a backlog.

- **`web-ui/src/tts/TtsController.js`** — singleton with FIFO queue, single async worker, gesture priming, per-source filtered `stop()` (`stop({ source: 'chat' })` cancels chat without stopping a script `say()`), and provider switching at runtime.
- **`web-ui/src/tts/providers/BrowserProvider.js`** — Web Speech API wrapper conforming to a small `speak(job) → Promise / cancel() / getVoices()` contract. Future providers (chatterbox, cosyvoice, OpenAI, ElevenLabs) plug in without touching consumers.
- **`web-ui/src/hooks/useTts.js`** replaces `useTTS.js`; `useScriptSpeech.js` now routes through the controller. `ttsGesture.js` is deleted — the gate logic lives inside the controller and no longer queues callbacks.
- **`SettingsEditor/VoiceSection.jsx` "Test"** button now plays through the controller too, so it shares the same priming and queue with the rest of the system.

### Emotion hint on `say()`

Scripts can now pass an emotion hint: `say("Calibration done!", { emotion: "excited" })`. The hint flows through `script.say` WebSocket events (new `emotion` field, `null` when omitted) and is applied by the active TTS provider. The browser provider approximates with rate/pitch tweaks for a small built-in vocabulary (`excited`, `happy`, `sad`, `whisper`, `serious`); server-side providers added in a later release will honour the field natively.

## v0.25.25 — May 2, 2026

### Features

- **ONVIF driver gains software digital zoom.** New writable properties `digitalZoom` (1.0–16.0), `zoomX` and `zoomY` (each `-1..1`) crop a `1/zoom × 1/zoom` window of the live frame and rescale it back to the camera's native resolution with bilinear interpolation, so the live `video` stream and any active recording keep their nominal `resolution` while showing the cropped region. Implemented as `OnvifDriver.ApplyDigitalZoom`, called per frame after `ApplyFlips` and before the recorder + JPEG encode — both the continuous capture loop and the `snapshot()` paths (live + cold-open) pick it up. The `(zoomX, zoomY)` offset is normalized against the *available* pan range at the current zoom level (`±1` puts the crop edge flush with the image edge), so the zoomed window can never extend outside the source frame regardless of zoom level — no clamping logic needed downstream. Coordinates apply on the *displayed* image, after `flipH` / `flipV`, so they always match what dashboards and AI vision pipelines see. Useful for AI tasks where you want to inspect a region without driving optical PTZ — software zoom takes effect on the next frame, not after a multi-second move-and-settle. Stored as `volatile float` so reads/writes from the capture thread and ws-handler thread don't need a lock. The starter template gains `zoomReset` / `zoomCenter2x` example methods to demonstrate the property syntax.

## v0.25.24 — May 2, 2026

### Startup log cleanup

Boot output was a wall of unrelated lines (built-in driver names, half-related warnings, network diagnostics that ran before Kestrel had bound). Same content, now grouped under `── Built-in drivers ──`, `── Security ──`, `── Network ──`, `── Extension drivers ──`, `── Services ──` (and `── Licensing ──` when there's something to report). Built-in drivers collapsed to one line listing their names. The "Driver registry: N drivers" tail is now `N extension driver(s) loaded · N total in registry`, printed under the extension scan. Auth-token / editor-mode / HTTPS / scan results route through a single `StartupBanner` helper (`MuxitServer/Logging/StartupBanner.cs`) for consistent ✓ / ⚠ / ✗ prefixes.

### Fixes

- **MailKit security advisory (NU1902 / GHSA-9j88-vvj5-vhgr).** Bumped `MailKit` from 4.7.1.1 to 4.8.0 in `MuxitServer.csproj`. The warning was also being re-printed at *every* `node start.js server` because `start.js` ran an explicit `dotnet build` and then `dotnet run`, which does its own implicit incremental build and re-prints the same NuGet warnings. `start.js` now passes `--no-build` to `dotnet run` whenever the explicit build succeeded.
- **Capability scan never worked for any free driver.** `DllDriverLoader.AuditCapabilitiesDetailed` built its `MetadataLoadContext` resolver from the .NET runtime dir + the driver's own dir, but `Muxit.Driver.Sdk.dll` lives in the host's `AppContext.BaseDirectory` — so every scan failed with `Could not find assembly 'Muxit.Driver.Sdk'` and the audit reported "scan failed" instead of capabilities. Added `AppContext.BaseDirectory` to the resolver paths; AudioSynth / Midi / GenericScpi now report their actual capability set (FileSystem / Network / Process / …).
- **Auth token "denied" then "written" contradiction.** On Windows, `File.WriteAllText` fails with `Access denied` when overwriting an existing file that has the Hidden attribute set — which is the attribute *we* set on the previous run. The catch printed a Warning, then we unconditionally printed `Auth token written to: …`, so every restart claimed both. `Program.cs` now clears the Hidden flag before writing and only prints the success line when the write actually succeeded.
- **False "No TCP listener detected on port N" warning.** `NetworkDiagnostics.GetBannerSummary()` was called inline before `app.RunAsync()`, so the listener probe ran before Kestrel had bound — every boot reported a phantom "Kestrel may have failed to bind" hint. Moved the diagnostics + the `Listening:` / `WebSocket:` lines into `lifetime.ApplicationStarted.Register` so they print after the bind has actually happened. Same callback also kicks off Phase 2 (extension scan), so `── Network ──` appears before `── Extension drivers ──`.
- **Cryptic "Method not found" for SDK-drift drivers.** A driver compiled against an older `Muxit.Driver.Sdk` (e.g. before the `Details` parameter was added to `PropertyDescriptor`) failed loading with the raw `MissingMethodException: Void Muxit.Driver.Sdk.PropertyDescriptor..ctor(System.String, System.String, System.String, System.String, System.String)`. `DllDriverHost.ScanAsync` now catches that case explicitly and prints `✗ <file>.dll — incompatible Muxit SDK (rebuild and repackage with the current SDK)`.

## v0.25.23 — May 2, 2026

### Features

- **ONVIF driver pushes a `snapshot` stream per `snapshot()` call.** The driver now declares a second stream channel, `snapshot`, and emits the same base64 JPEG on it that `snapshot()` returns to the caller — both code paths (live RTSP grab and cold-open temp connection). Bind a Canvas widget to `<connector>:snapshot` (mode `image`) and you see exactly what the AI/vision pipeline received, with no polling overhead and no extra hardware traffic. Solves the most common "the AI's description doesn't match what's on screen" debugging problem: the snapshot can lag the live view by 0.5–1.5 s due to the camera's H.264 GOP / B-frame settings, and the widget now makes that lag visible. Returning the value through `StreamEmitter` was preferred over a `lastSnapshot` property because polling a 200–500 KB string at the default 1-second cadence would burn ~500 KB/s of WS traffic for no gain — streams only push when the value is actually produced.

## v0.25.22 — May 2, 2026

### Features

- **ONVIF driver gains absolute PTZ + status read.** Added `ptzMoveAbsolute({ pan, tilt, zoom })` for driving the camera to a specific position (vs. `ptzMove`'s relative nudge), and `ptzStatus` for reading the current `{ pan, tilt, zoom, panTiltState, zoomState }` — the move-state fields are useful for waiting until an absolute move has settled before issuing the next one. Implementation lives in `OnvifClient.AbsoluteMoveAsync` / `GetStatusAsync`; both go to the existing `_ptzUrl` SOAP endpoint and reuse the same WS-Security envelope as the rest of the PTZ surface. Cameras that don't implement absolute PTZ (some lower-end Profile S devices) return a SOAP fault — script accordingly with `gotoPreset` or relative moves as fallback. Coordinate space is camera-specific; most ONVIF cameras normalize each axis to `[-1, 1]`, but a handful use degrees or raw step counts — a quick `ptzStatus` call after a known position discloses what your camera returns. The misleading "continuous-move velocities" wording on `ptzMove` is also corrected — `RelativeMove` is a one-shot delta, the camera stops on its own, no `ptzStop` needed.

### Dashboards

- **Text Display widget supports multiline values and per-widget alignment.** Strings containing `\n` now render across multiple lines (was: collapsed to a single line by the default `white-space: normal`). The widget config panel gains an `align` toggle (Left / Center / Right) so multiline values can be left-aligned for log-style output without affecting other Text Display widgets on the same dashboard. Mobile view picks up the same fix — root cause was that `dashboard.css` was only imported by the desktop entry, so the new `white-space: pre-wrap` rule was missing on mobile; `MobileShell` now imports `dashboard.css` too.

- **Dashboard editor stops squishing widgets.** Switching into edit mode used to shrink the grid canvas by ~420 px (palette + config panel widths), changing every widget's aspect ratio. The grid now keeps its live-mode width while editing — the center pane scrolls horizontally if the panels would otherwise overlap the canvas. Single change in `DashboardEditor.jsx`; the existing `overflow: auto` on the center pane handles the scrollbar.

## v0.25.21 — May 1, 2026

### Fixes

- **AI tool flow restored after upstream strict-mode change.** The Muxit cloud proxy / OpenRouter started rejecting the follow-up turn after every tool call with `validation_error: Invalid request: Invalid input` — every chat that needed a tool went unrecoverable on the second LLM call. Diagnosed via a new `MUXIT_AI_DEBUG=1`-gated dump of the full upstream error body (#411): the OpenRouter generation log showed the first call (returning `tool_calls`) succeeded with status 200, and the follow-up call was rejected by the validator before reaching generation. The only structural difference between the two calls was the assistant message we appended carrying `content: null` together with `tool_calls`. OpenAI's public spec still allows that combination, but a strict-mode rollout late April 2026 along the proxy → OpenRouter → upstream path no longer accepts it. Fix in `AiSession.AddAssistantMessage` (`MuxitServer/AI/AiSession.cs`): emit `content: ""` instead of `content: null` whenever `tool_calls` is present. Empty string is universally accepted, including by the local-LLM chat-template bridges (LM Studio Gemma, llama.cpp) the original `null` was already working around. (#412)

### Diagnostics

- **`AiService.Streaming` logs the full upstream error body** when `MUXIT_AI_DEBUG=1`. One `_logger.Info` line, runs before the structured-error parsing so the full body is captured even when extraction succeeds. Zero production-log noise; saved hours on the next upstream API change. (#411)

## v0.25.20 — May 1, 2026

### Security

Second hardening pass against the 2026-04-30 audit. Closes the three remaining sprint-sized items that round out the "if anything goes wrong, it doesn't stay quiet" theme.

- **Logger and EventBridge redaction.** `ServerLogger.Log` already ran `SecretRedactor.RedactMessage` on its input, but `script.output`, `agent.log`, `script.say`, and `connector.error` events emitted straight onto the bus and bypassed it. A user script that did `log.error(\`Bearer leaked-token-…\`)` or a connector load failure that quoted raw `apiKey: "…"` landed in the browser console verbatim. `EventBridge` now wraps each leak-prone field through the redactor at broadcast time. `AuditLog` runs `SecretRedactor.RedactJson` on the `details` tree before serializing, so both `workspace/logs/audit.jsonl` and the `audit.log` WS event lose secret-named cleartext (knowing *"user X wrote field 'apiKey'"* suffices for forensics). (audit U16, #406)

- **Tamper alarm on `safety.audit.enabled` flip.** A single config flag silently disabled the entire audit trail; nothing in the existing flow recorded the disable event itself. `AuditLog` now subscribes to `config.changed`, compares to a thread-safe `_lastKnownEnabled`, and on every flip writes a stderr WARNING + a structured line to a separate **`workspace/logs/audit-meta.jsonl`** that ignores the enabled flag. Startup with audit off produces an immediate `audit-disabled-at-startup` entry; runtime flips produce `audit-disabled` / `audit-enabled` entries plus an `audit.tamper` event for any future UI banner. Gated on `IsLicensed` so free-tier servers (which never had audit) stay silent. (audit U9, #407)

- **Per-WS rate limit on hardware/AI/marketplace calls.** A leaked auth token (or runaway dashboard) could fire thousands of `connector.call` / `scripts.start` / `ai.chat` / `marketplace.install` per second. `MessageRouter` now enforces a sliding 1-second window per WebSocket on the gated set; over-budget returns `WS_RATE_LIMITED` with a slow-down message. Read-only / metadata calls (`state.subscribe`, `connector.list`, `connector.schema`, `safety.get`, `license.get`, …) are intentionally **not** gated — legit dashboards burst through them on connect. Default 50/sec per client, override via `security.rateLimit.callsPerSec` in `server.json` (clamped to ≥ 5 so a misconfiguration can't brick the server). (audit A9, #408)

### Reverts

- **U5 — AI confirmation user-turn gate (#402) reverted (#410).** Reverted while diagnosing a chat-breaking `validation_error: Invalid input` after every tool call. **Subsequent investigation traced the actual cause to an unrelated upstream OpenAI/OpenRouter strict-mode rollout** that rejected `content: null` on assistant messages with `tool_calls` — fixed in v0.25.21 (#412). U5's logic itself was never proven faulty, only untested against the AI flow. Re-attempt tracked in the audit follow-up — needs a stub-LLM provider in the test harness before re-merging so a real regression can be told apart from another upstream coincidence.

The remaining audit items (`B1`/`B2` server-side license signing, `U1` secret vault, `U11`/`U12`/`U13`/`U14`/`U15`, `A2`–`A8`, plus U5 re-attempt) are tracked in `docs/audits/2026-04-30-followup.md`.

## v0.25.19 — May 1, 2026

### Security

Hardening pass following the 2026-04-30 internal security audit (`docs/audits/2026-04-30-security-audit.md`). Seven coupled fixes that close the immediate "trust boundaries cross the DLL layer" and "browser-side cross-origin / secret leakage" classes.

- **Premium driver signature is now mandatory at load time.** `DllDriverHost.ScanAsync` performs the `DriverSignature.IsOfficialDriver` check **before** `DllDriverLoader.Load` runs `Activator.CreateInstance`, so an unsigned DLL in a `premium`-category package never gets to execute its constructor in the host process. Skipped DLLs surface via the `driver.diagnostics` event (`PREMIUM_NOT_SIGNED`, hard severity) so the Extensions panel still shows the rejection. `lib/driver-manager/build.js` now fails the build instead of silently shipping unsigned premium packages — set `MUXIT_ALLOW_UNSIGNED_PREMIUM=1` only for local dev builds. (audit B3/B4, #399)

- **`RequiresSafetyGates=false` only honoured on signed drivers.** `DllDriverLoader.Load` previously read `[assembly: RequiresSafetyGates(false)]` from any DLL and propagated it straight through `ConnectorInstance` so the safety gate became a no-op. Now the opt-out is gated on `DriverSignature.IsOfficialDriver`; an unsigned DLL that requests it gets the flag forced back to `true` plus a stderr warning. Closes the "any DLL bypasses every limit/confirm/audit row" path. (audit B5/U8, #398)

- **`connector.schema` no longer echoes secret-named `driverConfig` values.** Fields whose key matches the existing `SecretRedactor.SecretKeyPattern` (`apiKey`, `password`, `token`, `bearer`, `credential`, `auth_key`, `private_key`, `secret`) come back as `{ value: null, secret: true, hasValue: bool }`. Editing still works through the per-key `connector.driverConfig.set` endpoint, which only takes the single key being changed. UI work to render the new shape as "Set / Replace" is a follow-up. (audit U3, #396)

- **WebSocket upgrade rejects cross-origin requests.** Browsers will happily open a WS from any page to `ws://127.0.0.1:8765` as long as the auth token is present. `WebSocketHandler.HandleAsync` now compares `Origin` against `http(s)://<Request.Host.Value>`; non-browser clients (CLI, MCP, Python) don't send Origin and stay gated by the auth-token check alone. Closes the realistic DNS-rebinding / token-exfil-via-XSS attack vectors. (audit U6, #397)

- **Editor `open-with` extension whitelist.** `/api/editor/open-with` previously called `Process.Start` with `UseShellExecute=true` on Windows and no extension check, so a workspace script that dropped a `.bat`/`.cmd`/`.vbs`/`.lnk` could trigger arbitrary code execution as the server user once the user clicked "open". The handler now whitelists document / image / video / audio / plain-text extensions only; everything else returns 415. macOS / Linux paths switch from string interpolation to `ProcessStartInfo.ArgumentList` (defence in depth). `RevealInExplorer` got the same `ArgumentList` treatment. Editor mode remains opt-in (`security.editorMode=true`). (audit U7, #400)

- **`AiDebugDump` output is redacted.** `MUXIT_AI_DEBUG=1` writes the assembled chat-request body (including connector instructions, `Authorization: Bearer …` headers in the messages array, and any `sk-…` tokens the LLM reflected back) to `workspace/logs/ai-last-request.json` — exactly the file users grab when reporting bugs. The dump now deep-clones via parse, runs a new `SecretRedactor.RedactJson` walker on the clone, and stamps `"redacted": true` so it's obvious the file has been sanitised. `RedactJson` is reusable for the upcoming logger / event-bridge pass (audit U16). (audit U2, #401)

- **AI confirmation key requires a fresh user turn.** ⚠ **Reverted in #410** during a chat-breaking outage. Subsequently traced (v0.25.21) to an upstream strict-mode rollout, **not to U5 itself**; U5's logic was never proven faulty, just never tested end-to-end. Original intent was to tag each pending entry with `_userMessageCount` at record time so AI can't auto-confirm its own retries within a single turn. Re-attempt blocked on stub-LLM test harness. (audit U5, #402)

- **Default-deny cross-connector access for connector configs.** A connector config running in V8 could call `connector("any-name")` and reach into any other loaded connector — read state, invoke methods, exfiltrate via `emit()`. Pre-deploy this is fine because the user installs every connector themselves; once a marketplace exists it becomes a supply-chain vector. The opt-in is now explicit:

  ```js
  export default {
    driver: "...",
    allowedConnectors: ["mqtt", "psu"],
    ...
  }
  ```

  Self-reference is always allowed (composite/wrapper convention). Scripts under `workspace/scripts/` go through `ScriptHost` / `ConnectorBridge` directly and are unaffected — every demo / template script that calls `connector("test-device")` keeps working without any opt-in. Workspace-template connector configs don't cross-call today, so no migration. (audit U4, #403)

The remaining audit items (`B1`/`B2` server-side license signing, `U1` secret vault, `U16` logger redaction, `A4` driver process isolation, et al.) are tracked in `docs/audits/2026-04-30-followup.md`.

## v0.25.18 — April 30, 2026

### Features

- **WebhookNotifier `notify()` now attaches images.** Pass `image` as either a base64 string (with or without a `data:` prefix) or an absolute file path — the camera drivers' `snapshot()` output (base64 JPEG) flows through unchanged. For ntfy.sh the driver switches to PUT-binary mode (image bytes as the request body, message text moves to the `Message` header) so the push notification renders the snapshot inline. For Discord the driver sends `multipart/form-data` with `payload_json` + `files[0]` and the embed references the file via `attachment://<filename>` so it shows inside the embed. Generic flavor base64-encodes the image into the JSON body. Slack incoming webhooks can't upload files — the driver drops the image and emits a warn `delivery` event. Pattern (`MuxitServer/Drivers/BuiltIn/WebhookNotifierDriver.cs:144-200`):
  ```javascript
  connector("webhook-ntfy").notify("Robot status", "Voor inspectie", "info", {
      image: connector("webcam").snapshot(),   // base64 JPEG
  });
  ```

- **Three more `notify()` args:** `click` (URL — ntfy/Discord make the notification clickable), `tags` (ntfy emoji shortcodes like `"warning,robot"`), and a new config-level `markdown: true` flag for ntfy that adds the `Markdown: yes` header so the body renders as markdown in the ntfy app. The flag is ignored when an image is attached because ntfy doesn't render markdown alongside attachments.
- **WebhookNotifier and EmailNotifier surfaced on the public marketplace page** (`website/src/pages/marketplace.astro`) under built-ins. One-liner each, naming the concrete destinations (ntfy / Discord / Slack for the webhook; Gmail App Password / Resend / M365 / local relay for e-mail) so the marketing surface matches what ships out of the box.

### Documentation

- **E-mail without typing your password.** The "raw password in config" footgun was the most-cited friction point on the EmailNotifier — users (rightly) push back on dropping their Google password into a workspace file. The connector template (`workspace-template/connectors/email.js`) is now a four-path pick-list with all blocks commented except Gmail App Password: alongside Gmail it shows Microsoft 365, Resend (API key as `password`), and a no-auth local relay. Header and `ai.instructions` make explicit that `password` is never the user's real e-mail password — it's an App Password, an API key, or no credential at all. The Notifications guide ([guides/notifications.md](https://docs.muxit.io/guides/notifications.md)) gains a "E-mail without typing your password" table covering Gmail / M365 / Resend / SendGrid / Mailgun / Postmark / Brevo / SES / local relay, and explains why a transactional API service is usually the right call for any lab sending more than a handful of mails a day.
- **ntfy "raw JSON" pitfall** documented in both the [WebhookNotifier reference](https://docs.muxit.io/reference/drivers/webhook-notifier.md#ntfy) and the Notifications guide. The fix is almost always one of three things: calling `post()` instead of `notify()` (post bypasses flavor reshaping), `flavor: "generic"` against an ntfy URL, or expecting markdown without the `markdown: true` config flag. The webhook-ntfy connector template gains a header note steering users at `notify()` and an example block that shows tags, click URL, and image attachment in their idiomatic forms.

## v0.25.17 — April 30, 2026

### Features

- **Two new built-in drivers ship outbound notifications.** Long-running scripts and threshold breaches can now reach the user out-of-band — the existing real-time WebSocket plumbing only helps when the browser tab is open. Both drivers live in the `Communication` group alongside `MqttBridge` and follow the same registration shape (`MuxitServer/Core/MuxitHost.cs:69-70`).
  - **`EmailNotifier`** (`MuxitServer/Drivers/BuiltIn/EmailNotifierDriver.cs`) sends SMTP via [MailKit](https://github.com/jstedfast/MailKit) — handles STARTTLS, implicit-SSL, plain transports, and SASL auth out of the box, so Gmail App Passwords, Microsoft 365, and local relays all work without per-provider plumbing. The `send` action takes `{ to, subject, body, html?, cc?, bcc?, from?, attachments? }`; when both `body` and `html` are supplied the message goes out as `multipart/alternative` with the plain version as fallback. Connection is opened, used, and closed per send — fine for the typical "few mails per run" rate. `RequiresSafetyGates = true`, so the first send to a new recipient triggers a confirmation prompt; subsequent sends to the same address pass through.
  - **`WebhookNotifier`** (`MuxitServer/Drivers/BuiltIn/WebhookNotifierDriver.cs`) POSTs to a fixed URL. A `flavor` config key reshapes the body for popular targets so scripts call a uniform `notify(title, body, level)` regardless of where the message lands: `ntfy` sends `text/plain` + `Title`/`Priority` headers (level → `default`/`low`/`high`/`urgent`); `discord` builds a webhook embed with color per level (info=blue, warn=orange, error=red, success=green); `slack` builds a `text` + colored attachment; `generic` posts JSON `{ title, body, level, timestamp }` for n8n / Zapier / Make / custom backends. `post(payload)` bypasses flavor reshaping for full control. `RequiresSafetyGates = false` because the URL is fixed at config time — there's no runtime target choice to gate.
- **Four workspace-template connector starters** ship with the new drivers (`workspace-template/connectors/email.js`, `webhook.js`, `webhook-ntfy.js`, `webhook-discord.js`), each preloaded with the right `flavor` and a placeholder URL or credential block. Drop in your value and the connector is live on next workspace reload.
- **Two demo scripts** (`workspace-template/scripts/demo/15-notifications.js`, `16-threshold-alert.js`) show the canonical patterns: the first runs a fake long operation, sends a short webhook push, then mails an AI-generated summary; the second polls a property with hysteresis-based debounce so a sustained high reading produces one alert, not one per sample (re-arms after the value drops 5 units below the threshold).
- **New documentation:** [Notifications & Alerts guide](https://docs.muxit.io/guides/notifications.md) walks through channel selection, the three core use cases (run finished, threshold breach, hardware fault), severity-level mapping per flavor, and safety-gate behavior. Per-driver references at [drivers/email-notifier.md](https://docs.muxit.io/reference/drivers/email-notifier.md) and [drivers/webhook-notifier.md](https://docs.muxit.io/reference/drivers/webhook-notifier.md) cover properties, actions, streams, and config options. Sidebar entries added under Guides and Built-in Drivers (`docs-site/.vitepress/config.mts`).

## v0.25.16 — April 30, 2026

### Fixes

- **Editor running-line highlight now actually moves with the script.** The Phase-2 execution-line tracer was effectively dead end-to-end — three independent bugs lined up to make it never produce a visible highlight: **(1)** `__traceCallSite()` in `SandboxScript.cs` walked `new Error().stack` looking for `<anonymous>:LINE:COL` and picked the first frame whose adjusted line was ≥ 1, but `SandboxScript.InitCode` is loaded via a *separate* `engine.Execute(...)` call so its frames also rendered as `<anonymous>` — the regex matched the helper's own `new Error()` line (~line 31 of InitCode) before ever reaching the user frame. Fix: evaluate the wrapped user script with `DocumentInfo("muxit:user")` (`MuxitServer/Scripts/ScriptEngine.cs`) so user frames render as `muxit:user:LINE:COL`, and key `__traceCallSite` and `StackLineRegex` / `AdjustStackLines` off that source name. The regex tolerates a ` [temp-N]` suffix that ClearScript appends for transient docs in some versions. **(2)** Both effects in `EditorGroup.jsx` (the Monaco decoration and the `subscribeTrace` opt-in) gated on a strict `^scripts/.+\.js$` regex, but the workspace explorer hands the editor paths like `workspace/scripts/foo.js`. Neither effect fired, so the trace subscriber count on the server stayed at zero, `__host.TraceEnabled` returned false, and `__traceCallSite` short-circuited before reporting a single line. Both effects now use `isScript()` (the project's own predicate, accepting any `*/scripts/*.js`), and the highlight key derives from `activeFile.name` to match the name the Run button passes to `server.runScript`. **(3)** `subscribeTrace()` in `useServer.js` was a no-op when issued before the WebSocket finished opening (`wsRef.current` was still null), and it never re-sent on reconnect. `ws.onopen` now resends the subscribe whenever `traceSubRef.current > 0`. `docs/development/clearscript-quirks.md` quirk #9 updated to record the InitCode-vs-user-script frame disambiguation gotcha.

### Documentation

- **MCP setup instructions corrected for end users.** The previous AI guide ([guides/ai.md](https://docs.muxit.io/guides/ai.md)) and the in-app **Settings → MCP** panel (`web-ui/src/components/SettingsEditor/McpSection.jsx`) shipped three misleading snippets: (1) the **Claude Code** block claimed to be "already configured in `.claude/.mcp.json`" — wrong path (the actual project file is `.mcp.json` at the repo root) and wrong scope (it only applies when Claude Code is launched from inside this source checkout, not from a user's lab workspace); (2) the **Claude Desktop** snippet used `dotnet run --project /path/to/MuxitServer` which is a from-source invocation an end user with the published `muxit` binary can't run; (3) the **ChatGPT** block told users to paste `http://127.0.0.1:8765/mcp` directly into the connector dialog, but ChatGPT's connector UI rejects loopback / private-IP addresses as *"unsafe url"* and requires a publicly reachable HTTPS endpoint with a valid TLS cert — pasting the local URL just produces an `Error creating connector. unsafe url` toast every time. All three blocks now distinguish *installed Muxit* from *source checkout*: Claude Code shows a `claude mcp add muxit -- /path/to/muxit --mcp --workspace …` command for installed builds and keeps the existing `dotnet run` snippet as the source-tree variant; Claude Desktop's snippet now points at the absolute path of the installed `muxit` binary; ChatGPT documents the public-HTTPS-tunnel workaround (Cloudflare Tunnel one-liner) and labels it as a constraint of ChatGPT, not Muxit. Both the docs page and the Settings UI panel were updated to stay in sync.

- **ChatGPT-via-tunnel security warning.** Because Muxit's HTTP middleware (`MuxitServer/Program.cs:786-865`) treats every loopback request as authenticated and a tunnel daemon (cloudflared / ngrok) running on the same host reaches Muxit *over loopback*, naively exposing the local `/mcp` endpoint over a public tunnel publishes the full hardware surface — read sensors, write properties, run scripts — with no credentials. The optional `security.remoteAccess` password gate is bypassed for loopback callers and uses a custom `X-Auth-Token` header that ChatGPT's connector can't send anyway, so it doesn't close the gap. Both the AI guide's ChatGPT section and the Settings UI's ChatGPT panel now lead with a stark warning and recommend acceptable mitigations: **Tailscale Funnel** restricted to your tailnet, **Cloudflare Access** in front of cloudflared, or short-lived per-session tunnels — and steer users with no tunnel infrastructure toward Claude Desktop / Claude Code, which connect locally over stdio with no exposure.

- **AI features tier table footnote.** The capability matrix at the top of [guides/ai.md](https://docs.muxit.io/guides/ai.md) advertised "Claude Desktop / Claude Code / ChatGPT" as the three supported MCP clients with no caveat; the ChatGPT-only public-HTTPS limitation is now flagged with an asterisk and a small footnote pointing at the new MCP Server section, and the *What you get on Free* paragraph now reads "ChatGPT (with a tunnel — see below)" so the marketing copy doesn't oversell the out-of-the-box ChatGPT experience.

## v0.25.15 — April 29, 2026

### Features

- **ONVIF driver gains `flipH` / `flipV` orientation toggles.** Both are new config options *and* live R/W properties on the driver, so cameras mounted upside-down or facing a mirror can be corrected without re-opening the RTSP stream. Flips are applied in `ApplyFlips()` (`MuxitServer/Drivers/BuiltIn/OnvifDriver.cs`) immediately after decode and *before* recorder feed + JPEG encode, so both the live `video` stream and any active `.mp4` recording reflect the flip. Implementation uses OpenCvSharp's `Cv2.Flip` with `FlipMode.Y` (horizontal mirror), `FlipMode.X` (vertical), or `FlipMode.XY` (180° rotation when both are set). No restart needed when toggling at runtime — the capture loop reads the volatile flags each iteration. Documented in `docs-site/reference/drivers/onvif.md`.

### Changes

- **ONVIF capture pipeline tightened for lower latency.** Two driver-side changes for the cameras whose 1–2 s end-to-end delay was bottlenecking the dashboard view: (1) `OPENCV_FFMPEG_CAPTURE_OPTIONS` now also sets `max_delay=0` and `reorder_queue_size=0`, disabling FFmpeg's frame-reordering and demuxer-delay buffers (the rest — `nobuffer`, `low_delay`, `framedrop=1`, `analyzeduration=0`, `probesize=32768` — was already there). (2) After opening `VideoCapture`, the driver now calls `_capture.Set(VideoCaptureProperties.BufferSize, 1)` to ask the FFmpeg backend for a single-frame internal buffer; backends that don't honor the request silently ignore it. The remaining 0.5–1.5 s of glass-to-screen delay is dominated by the camera's own H.264 encoder (GOP length, B-frames) and the browser's MJPEG decode pipeline — the [ONVIF driver reference](https://docs.muxit.io/reference/drivers/onvif.md#latency) now has a "Latency" section documenting the camera-side knobs (substream profile, shorter GOP, disable B-frames, wired LAN) that move the needle further.

## v0.25.14 — April 29, 2026

### Features

- **Dashboard knob widget now handles fractional values and direct entry.** Previously the knob always rounded display to one decimal (`current.toFixed(1)`) and used a step-rounding pass that left float noise (`Math.round(0.15 / 0.05) * 0.05` = `0.15000000000000002`), so a knob configured `min:0, max:2.6, step:0.05` looked broken. The widget now derives display precision from `step` (e.g. `step:0.05` → 2 decimals, `step:1` → 0 decimals), strips post-rounding float noise via `toFixed(decimals)`, and renders the value as an editable input — click it to type a specific value and press Enter (or click out) to commit; Escape cancels. Out-of-range or off-step entries are clamped/quantized on commit. Implemented in `web-ui/src/components/dashboard/widgets/KnobWidget.jsx` with new `decimalsFromStep()` and `quantize()` helpers and matching styles in `web-ui/src/styles/dashboard.css`.

- **Numeric config fields (`min`, `max`, `step`, `duration`, `yMin`, `yMax`, `sendValue`, `lineWidth`, `maxLines`) now accept decimal entry.** The widget config panel previously parsed every keystroke through `Number(val)`, which meant typing `0.05` was eaten alive: after `0.` the parser collapsed it to `0` and re-rendered the input, swallowing the in-progress decimal point. A new `NumericField` component (`web-ui/src/components/dashboard/WidgetConfigPanel.jsx`) keeps the in-progress text in local state and only commits a parsed number on blur or Enter. Escape reverts; invalid input falls back to the last good value. The fix unblocks fractional knob configuration end-to-end (the widget supports it; the config panel was the bottleneck).

- **Dashboard editor exposes grid columns, row height, and layout-compaction mode in the right panel.** A new "Dashboard" section (`web-ui/src/components/dashboard/WidgetConfigPanel.jsx` `DashboardSection`) sits at the top of the right-side editor panel and is visible whether or not a widget is selected. **Columns** is a 1–24 slider (default 12), **Row height** is a number input (px), and **Layout** toggles between *Auto-stack (compact)* (default — items pull up to fill whitespace, the previous behavior) and *Free placement* (preserves whitespace above widgets so users can leave intentional gaps). Free-placement mode swaps in `noCompactor` from react-grid-layout; new widgets dropped while in this mode get placed at the bottom of the existing layout (otherwise `y:Infinity` wouldn't resolve under noCompactor). All three settings persist in the dashboard JSON.

- **Subtle gridlines while the dashboard is in edit mode.** A new `.dashboard-grid.show-gridlines` style (`web-ui/src/styles/dashboard.css`) paints faint 1px lines at every column and row boundary using two `repeating-linear-gradient` backgrounds. The `--grid-col-step` and `--grid-row-step` CSS variables are computed in JS from the current `containerWidth`, `gridCols`, `rowHeight`, and the grid's actual margin/padding, so the lines align with cell boundaries exactly and shift live as the columns slider changes or the editor pane resizes. Lines are off in live (non-edit) mode.

## v0.25.13 — April 29, 2026

### Features

- **Editor word wrap is now toggleable from the View menu.** Previously the Monaco editor was hard-coded to `wordWrap: 'off'`, so long lines (CSV rows, log dumps, single-line connector configs) ran off-screen and required horizontal scrolling. The View menu now has a **Word Wrap** entry (also bound to `Alt+Z`) that flips the editor between `'on'` and `'off'`. The setting persists in the `muxit-layout-state` localStorage key alongside the other layout preferences, applies live across all editor groups, and is reflected with a checkmark in the View dropdown. Documented in [guides/keyboard-shortcuts.md](https://docs.muxit.io/guides/keyboard-shortcuts.md).

### Changes

- **The free tier is now limited to one active SCPI (`GenericScpi`) connector.** The overall connector budget is unchanged (free=5, maker=10, pro+=unlimited), but a new `scpi-connectors` feature in the license registry sub-limits how many of those slots may be SCPI instruments — free=1, maker and above unlimited. Enforced in three places in `MuxitServer/Connectors/ConnectorManager.cs`: `ResolveEnabledSet` skips additional SCPI configs at startup (the first SCPI connector wins; the rest land in the disabled list with a `Not enabled (SCPI limit: 1 on Free tier)` reason), `AddConnector` rejects programmatic creation past the limit with `CONN_LIMIT_REACHED`, and `SetEnabledConnectorsAsync` validates the count when the user changes the enabled set from the UI. Match is by driver name (`GenericScpi`, case-insensitive) — connectors built on the JS `serial-monitor` driver or any TCP/serial transport that happens to send SCPI bytes are not affected, by design (the limit is on the convenience driver, not on raw byte traffic). Existing paid tiers are unchanged.

### Documentation

- **Free vs Maker AI capabilities are now spelled out.** The AI guide ([guides/ai.md](https://docs.muxit.io/guides/ai.md)) leads with a new **AI features by tier** section: a side-by-side comparison table covering MCP, Chat Panel, voice, `ai()`, AI-assisted SCPI authoring, Vision AI, Local LLM, and Autonomous Agents, followed by three short narrative blocks — *What you get on Free* (MCP plus your own AI client is a complete workflow for a one-person lab), *What Maker unlocks* (the things that live inside the Muxit window — chat, voice, `ai()` in scripts, AI-assisted SCPI, 500 credits/month), and *Beyond Maker* (Vision, Local LLM, Agents at Pro). The Script API reference ([reference/script-api.md](https://docs.muxit.io/reference/script-api.md)) had `ai()` mis-listed as Pro-tier — corrected to Maker, with a vision caveat for the `ai(prompt, image)` form (still Pro) and a pointer to MCP for Free users. The AI-assisted SCPI guide ([guides/ai-scpi-authoring.md](https://docs.muxit.io/guides/ai-scpi-authoring.md)) now opens with a tier note that points Free users to two equally good paths: hand-authoring with the declarative `GenericScpi` schema, or driving the same `probe_scpi_device` / `validate_connector_config` / `write_connector_config` tools from their own AI client over MCP. Marketing-side, the maker page restructures *AI you actually use* into a clear Free → Maker progression and reframes Local LLM as a Pro-tier feature, and the pricing page (`website/src/pages/pricing.astro`) now sells MCP on the Free card as a real workflow — *"point Claude Desktop, Claude Code, or ChatGPT at Muxit and your AI client drives your hardware, runs scripts, and drafts connectors. Your provider, no Muxit credits."* The Maker card emphasises that built-in chat and voice live *in the Muxit window* (no external client to juggle), and the *AI credits — how they work* info block was rewritten as **AI on Free vs paid plans**, presenting MCP and Muxit AI as two first-class paths instead of burying MCP as a footer afterthought.

## v0.25.11 — April 28, 2026

### Documentation

- **Script API docs and examples now lead with the `.file(path)` handle pattern.** The Script Guide ([guides/scripts.md](https://docs.muxit.io/guides/scripts.md)), Script API Reference ([reference/script-api.md](https://docs.muxit.io/reference/script-api.md)), the FileAccess driver reference's "Example Connector" / "Example Script" sections ([reference/drivers/file-access.md](https://docs.muxit.io/reference/drivers/file-access.md)), the UI tour's CSV-charts blurb ([getting-started/ui-tour.md](https://docs.muxit.io/getting-started/ui-tour.md)), and the AI script-authoring system prompt (`MuxitServer/AI/Prompts/script-api.md`) were all written before v0.25.10 added handles, so every example still showed the path-on-every-call form (`files.writeText({ path: 'temps.csv', content: ... })`, `files.appendText({ path: 'temps.csv', content: ... })`). They now demonstrate the handle pattern as the recommended path: `const csv = files.file('temps.csv'); csv.write(header); csv.append(row);`. Standalone actions are still documented in the FileAccess action table (and still work — positional args, object-arg, both unchanged) but the worked examples no longer teach the noisier form. The default workspace connector's `writeArray` helper (`workspace-template/connectors/fileaccess.js`) was also rewritten on the handle (`c.file(args.path).write(...)`) so the example custom method matches the docs.

## v0.25.10 — April 27, 2026

### Features

- **FileAccess driver gains a path-bound `file(path)` handle for compact write/read syntax.** Repeating the path on every call (`fa.writeText({ path: "runs/log.csv", content: line })`) was the most-cited papercut in the script API, especially in append loops. The new `file(path)` action returns a `FileHandle` host object whose methods bind the path once: `const f = fa.file("runs/log.csv"); f.write(header); f.append(row); f.read(); f.exists; f.size; f.info(); f.delete(); f.rename("runs/done.csv")`. The handle is a CLR object surfaced via ClearScript `[ScriptMember]` attributes, so the path-binding closures live on the .NET side and survive the script ↔ connector V8 boundary cleanly — pure-JS handles would have been stripped by `V8Interop.NormalizeJsValue`'s function-discarding traversal. All operations delegate to the parent driver's existing path-resolution, size-limit, and `workspace.file.changed` plumbing, so handle calls obey the same sandbox rules as the standalone actions. Methods are synchronous (`f.write(...)` returns `"OK"`, no `await`) to match the rest of the connector proxy. The handle's `rename` updates itself in-place so subsequent calls operate on the moved file. Default connector config (`workspace-template/connectors/fileaccess.js`) and the FileAccess template advertise the new pattern in `ai.instructions` so the AI prefers it. Standalone actions (`writeText`, `readText`, `appendText`, …) are unchanged and still accept positional args via `MergePositionalArgs`. Reference: `docs-site/reference/drivers/file-access.md` "File Handles" section.



### Features

- **System prompts now have a `minimal` profile for local LLMs with 4–8K context windows.** A new `ai.promptProfile` config key (`"standard"` default, `"minimal"` opt-in) controls how much of the platform context ships in the system message and tool-definition list. In `minimal` mode:
  - **Connected Devices** collapses to one line per connector (`- name (driver) — instructions`) plus a single hint to call `get_connector_schema(name)` when properties/actions are needed.
  - **Decision-tree fragment** (`decision-tree.md` / `decision-simple.md`, ~1.5 KB) is skipped — short tool-description summaries already steer tool choice for the small models that need this profile.
  - **Safety-confirmation fragment** swaps from the 3.3 KB worked-examples version to a 0.6 KB rule sheet (`safety-confirmation-minimal.md`). The chat gate still parks numeric writes and script-authoring; the model just learns the protocol from the short version. Skipped entirely when the active safety mode is `off`.
  - **Tool descriptions** in the OpenAI function-calling list collapse to the first sentence of each tool's entry in `tool-descriptions.md`. `PromptRegistry.GetSectionShort` cuts at the first `.`/`!`/`?` that's followed by either end-of-string or whitespace + an uppercase letter, so decimals (`1.5`) and abbreviations (`e.g.`) don't trip it. `ToolRegistry.GetDefinitions(groups, minimal: true)` flips the lookup; `AiService` reads the profile from config and passes the flag through. Saves several KB across the ~50 registered tools — for the worst offenders (`run_script`, `run_code`, `probe_scpi_device`, `write_dashboard`, `read_manual_pages`) the first sentence is what the model needs to call them; recovery / argument detail is something it can rediscover from failures or the JSON schema.

  On a typical 5-connector lab the system message drops from ~13 KB to ~1.5 KB and the tool-definitions list drops from ~14 KB to ~3 KB. The model trades occasional tool round-trips for ~7× total shrink — right tradeoff for Ollama / LM Studio backends, wrong tradeoff for cloud models, hence opt-in. Documented in `docs-site/reference/configuration.md` and `docs-site/guides/ai.md`.

### Changes

- **MCP tool-result JSON keeps non-ASCII characters literal.** `MuxitServer/Mcp/McpJsonOptions.{Default,Indented}` now set `Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping`, so em-dashes (`—`), units (`°`, `µ`, `Ω`), `+`, `<`, and similar safe punctuation appear as one literal byte instead of expanding to a six-byte `\uXXXX` escape. Affects every MCP tool result the AI sees (notably `list_connectors`, `get_connector_schema`, `read_property` results that quote device strings) and the device-schema JSON the agent-mode prompt embeds via `SystemPromptBuilder.BuildForAgent`. The "unsafe" name refers to embedding JSON in HTML/JS, which we never do for tool results — only the LLM consumes them. Saves a few percent on text-heavy results and several KB on schemas with many `—` separators.

## v0.25.8 — April 25, 2026

### Bug Fixes

- **Hitting the model's context window now shows a friendly chat message with a "Start new chat" button instead of a raw HTTP error.** The streaming SSE error parser in `AiService.Streaming.cs` now classifies upstream errors against a marker list (`context_length_exceeded`, `prompt_too_long`, `request too large`, `context window`, `exceeds the context`, …) and throws a `MuxitException` with the new `AI_CONTEXT_LENGTH_EXCEEDED` error code. The web client's `useChat` reads `err.code` (set by `muxit-client` from the server error envelope) and tags the message with `errorCode: 'AI_CONTEXT_LENGTH_EXCEEDED'`; `ChatPanel` renders an inline **Start new chat** button next to the error so the user can clear the bloated session in one click. Detection covers OpenAI's `error.code = "context_length_exceeded"`, Anthropic's prose `message`, OpenRouter's `upstream_status` body, plus the plain-text 4xx that older Ollama builds return without a JSON envelope. Previously this surfaced as `Error: AI service error (invalid_request_error) (upstream 400): ...` and broke TTS, scrolling, and the loading indicator in confusing ways.
- **Muxit AI test connection no longer 502s with "anthropic/claude-haiku-4 is not a valid model ID".** OpenRouter retired the bare 4.0 Anthropic slugs in favour of the dated 4.5 IDs, so the proxy was rejecting every request that used the shipped default. `AiService.DefaultModelId`, the `FALLBACK_MODELS` / `DEFAULT_FAVORITE_MODELS` / `DEFAULT_MODEL` constants in the web UI, the `AI_PROVIDERS[muxit].defaultModel`, the `ModelCache` fallback list, and the doc references all move to `anthropic/claude-haiku-4-5` and `anthropic/claude-sonnet-4-5`. Test config in `tests/fixtures/test-server.json` updated to match.
- **Switching AI providers now refreshes the model list and picker.** `useModels` was only fetching once per mount, so flipping `ai.provider` from Muxit to Ollama / LM Studio left the chat header dropdown showing OpenRouter cloud slugs that the local backend rejects. The hook now takes a `providerKey` (the active provider id) and re-fetches whenever it changes; `SettingsEditor` and `ChatPanel` pass `config.ai.provider` through. The chat-header `ModelDropdown` also receives `activeProviderId`: on a local provider it lists everything from `/models` whose `provider` matches (Ollama / LM Studio / openai-compatible), so the picker only ever offers models the active backend can actually serve. Stale cloud favourites still live in `ai.favoriteModels` for when the user swings back to Muxit, but they no longer surface against a local endpoint.
- **Local LLMs that emit tool calls as JSON in `content` now actually trigger the tool.** Qwen3, Hermes-3, and gemma chat-template bridges sometimes ignore the OpenAI `tool_calls` field and return the call as JSON in the assistant message body — `{"tool": "read_property", "arguments": {...}}` (or wrapped in `<tool_call>...</tool_call>`, or fenced in a ``` ```json `` block). Previously this rendered as raw JSON in the chat and the user saw nothing happen. `AiService.Streaming.ExtractEmbeddedToolCalls` is a post-stream fallback (only runs when no structured tool call landed) that recognises all three shapes, accepts `name`/`tool` and `arguments`/`parameters`/`input` field aliases, and promotes the payload to a real tool-call entry the loop executes. Streaming text deltas whose first non-whitespace char is `{` or `<tool_call>` are also held server-side until the extractor decides — if it isn't a tool call after all, the buffer flushes through `ai.delta` so prose still streams; if it is, the JSON never reaches the chat.

## v0.25.7 — April 25, 2026

### Bug Fixes

- **Multi-positional args from scripts no longer create empty files named `Microsoft.ClearScript.V8.V8ScriptItem+V8Array`.** A script call like `connector("fileaccess").writeText(path, content)` was forwarded across the V8 bridge as a single ClearScript `ScriptObject` (a V8 array, not a CLR `object?[]`) — `ConnectorManager.MergePositionalArgs` only checks for `object?[]`, so it fell through to the scalar-wrap branch and produced `{path: <V8Array>}`. The driver's `ArgString(args, "path", "")` then `.ToString()`'d the V8Array, yielding the type-name string, and `WriteText` happily wrote an empty file at that bogus path. The single-arg object form `writeText({ path, content })` worked because of a downstream normalization, but the same fragility was waiting on every multi-positional call — `rename(from, to)`, `appendText(path, content)`, `writeBinary(path, content)`, and any extension driver action with two or more `ArgDescriptor` entries. The v0.25.2 positional-args fix only covered the WebSocket path (where JSON deserialization already produces CLR types); the V8 path was still broken. Three layered fixes: (1) `ConnectorBridge.CallAsync` now runs `V8Interop.NormalizeJsValue` on the incoming args, recursively converting V8 arrays → `object?[]` and V8 objects → `Dictionary<string, object?>` before they reach `MergePositionalArgs`. (2) `MergePositionalArgs` throws `VALIDATION_INVALID_VALUE` when more positional arguments are passed than the action declares, naming the action's expected signature instead of silently dropping the extras. (3) `Muxit.Driver.Sdk.DriverConfig.ArgString`/`ArgInt`/`ArgDouble`/`ArgBool` reject dictionary, collection, and ClearScript `ScriptObject` values up-front with `"Argument 'X' expected Y, got Z"`, so even if marshalling regresses the driver fails loudly instead of writing files named after CLR class names. Numeric-to-string coercion (`writeText({ path: 42, ... })` → `"42"`) is preserved.

## v0.25.6 — April 25, 2026

### Features

- **Script and connector errors now point at the right line.** `script.done` carries a structured `error` object — `{ message, line, column, stack, details }` — instead of a flat string. Line numbers refer to the user's source: the wrapper preamble that `ScriptEngine.cs` injects to make top-level `await` and main()-style scripts both work prepended 3 lines, and every `<anonymous>:N:M` reference is now adjusted by `ScriptEngine.WrapperPreambleLines` before it leaves the server (`ScriptEngine.AdjustStackLines`). `ConnectorLoader.TransformImports` keeps line counts stable too — stripped import statements are replaced with newline-equal padding instead of being collapsed, so V8's reported lines line up with the user's `.js`. Connector load failures broadcast a new `connector.error` message with the same `line`/`column` shape.
- **The web UI marks the offending row.** `EditorGroup.jsx` calls `monaco.editor.setModelMarkers` against the active script or connector file when its name appears in `useServer`'s new `scriptErrors` / `connectorErrors` maps. The squiggly carries the V8 stack as the hover message; markers clear automatically on the next run start. `BottomPanel` renders an `Lnn` chip next to error log lines that have line info — clicking it opens the file (`muxit-open-file` event → `Shell.handleFileOpen`) and reveals the line via `editor.revealLineInCenter` / `editor.setPosition`.
- **The editor highlights what a running script is parked on.** A new `script.line` broadcast (with paired `script.line.subscribe` / `script.line.unsubscribe` ref-counted on the server) reports the current user-line whenever a script blocks on `delay`, `await connector.x`, `ai`, `ask.*`, `say`, or `stream`. The trace is gated by `ScriptHost.TraceEnabled` so the in-script `__traceCallSite()` helper short-circuits when no dashboard is watching; throttled to one event per 50ms per script and de-duplicated on the prior line. EditorGroup paints a Monaco line decoration (soft-amber background plus a ▶ glyph) for the active file's running line. Useful for lab automation where a script can sit on `await delay(30000)` or a slow `await psu.voltage = 12` for a long time.

## v0.25.5 — April 25, 2026

### Features

- **Muxit AI can now talk to a local LLM instead of the Muxit cloud proxy.** A new `ai.provider` config selects between `muxit` (the existing managed proxy, default), `ollama` (local Ollama daemon, default `http://localhost:11434/v1`), `lmstudio` (LM Studio's local server, default `http://localhost:1234/v1`), and `openai-compatible` (any other server exposing `/chat/completions` — vLLM, llama-server, …). Per-provider settings live under `ai.providers.<id>.{baseUrl,apiKey,model}` so switching back doesn't lose the previous endpoint. **Settings → AI Services** now shows a provider picker with a per-provider Test connection button (powered by a new `config.test_provider` WebSocket message) that probes the endpoint, validates auth, and reports how many models the server has loaded. The chat UI, the `ai()` script global, the agent inference loop, and the AI vision object detector all transparently route through the active provider, so the same dashboards / scripts / agents work whether you're on the cloud or fully offline. Vision uses the OpenAI `image_url` content block, which works against multimodal Ollama models (llava, qwen2-vl, llama3.2-vision) without changes. Local providers gate behind a new **Local LLM** Pro feature (`local-llm` in the registry); the Muxit cloud path still rides on the existing `ai` feature, so Free/Maker tiers behave exactly as before.

### Architecture

- **AI/LLM call sites consolidated behind `ILlmProvider`.** `MuxitServer/AI/AiService.cs`, `MuxitServer/AI/AiService.Streaming.cs`, `MuxitServer/Scripts/ScriptHost.Ai.cs`, `MuxitServer/Agents/AgentInstance.cs`, and `MuxitServer/AI/ObjectDetector.cs` previously each built their own `HttpRequestMessage` against the hardcoded Muxit proxy URL with the license key as bearer. They now all go through `MuxitServer/AI/Providers/LlmProviderFactory`, which returns a cached `MuxitProvider` (cloud) or `OpenAiCompatibleProvider` (Ollama / LM Studio / openai-compatible) based on `ai.provider`. The streaming SSE parser, tool executor, safety gate, session store, and WebSocket message shapes are unchanged — adding a new provider only requires implementing `ILlmProvider`. License gates moved into the providers themselves: `MuxitProvider` enforces the `ai` feature, `OpenAiCompatibleProvider` enforces `local-llm`. `ModelCache` now merges the active local provider's `/models` response with the OpenRouter cloud list so the model picker shows what's actually loaded on Ollama / LM Studio.

## v0.25.4 — April 24, 2026

### Features

- **The AI always confirms numeric and scripted actions before running them.** A new `AI confirmation` column was added to the safety matrix (`SafetyPolicy.LevelBehavior.AiConfirm`, the SafetyChip dialog, and the `safety.custom.aiConfirm` field in `server.json`). Every built-in level — Observe, Assisted, Active, Unrestricted — ships with `Ask every time`; only a **Custom** row may set it to `Allow`. While on, the AI is blocked from executing two classes of tool call without the user first approving them in plain text: `write_property` / `call_action` whose arguments contain any number (the AI restates each value with its unit — "setting voltage to 15 V, current limit to 0.35 A — confirm?"), and `write_script` / `run_code` (the AI summarizes the script's plan — connectors, ranges, step sizes, expected duration — before authoring or executing). Numbers the user just spoke are still echoed back, because voice input drops units and "15" on its own is ambiguous. Simple parameterless or boolean-only calls like `power_on` or `reset` continue to execute immediately — the gate only catches writes that carry numbers and script-authoring tools. The legacy per-level `confirm_unknown_values` / `confirm_all` / `off` mapping is gone; the column now drives every AI tool-call prompt. See the [Safety Guide](https://docs.muxit.io/guides/safety.md#ai-confirmation) for the new flow.

### Changes

- **The AI stops walking loops in chat.** The `decision-tree`, `decision-simple`, and `safety-confirmation` prompt fragments now carry a mandatory "never walk a loop in chat" rule: anything that implies three or more device writes of the same property (a sweep, a range, "for each", "every N ms", "measure at X values", "log every step") must be authored with `write_script` or `run_code` and executed — not stepped through with repeated `write_property` calls. Before this, a 35-step current sweep produced 35 per-step confirmation round-trips; now the same request produces one `kind: "script"` plan confirmation and the script runs with per-step writes going through the hardware safety gate directly. The `ClassifyIntentByKeywords` classifier and `MentionsScriptAuthoring` gate were both extended so sweep/step/range phrasing activates the Scripts toolgroup and loads the `script-api` fragment even when the user doesn't say "script" or "loop" outright.
- **Identical tool-call retries no longer re-arm the confirmation gate.** `BuildConfirmationKey` now canonicalizes the args JSON before hashing — object keys are sorted and numeric leaves are round-trip-formatted, so `{"value":0}` and `{"value":0.0}` collide to the same pending-confirmation marker. The old raw-string comparison let the LLM trip the gate a second time just by re-emitting the same call with different number formatting, producing "Setting current_set to 0 A (repeat) — confirm?" loops.

## v0.25.3 — April 24, 2026

### Bug Fixes

- **Typos in connector/driver property names now throw instead of silently returning a function stub.** Previously, a script line like `log.info(psu.voltage)` — where the real property is `measured_voltage` — evaluated to a ghost function (the Proxy's generic dispatch closure) and string-interpolated into logs as a garbage function body, hiding the typo. The V8 `Proxy` `get` traps for (a) the script-sandbox `connector()`, (b) cross-connector access inside connector configs, and (c) the per-config `__driverProxy` used as `c` in custom methods, now branch three ways: known property → read value, known action → callable function, unknown → `throw new ReferenceError("Connector 'X' has no property or method 'Y'")` (or `"Driver has no property or action 'Y'"` for the driver proxy). The script-sandbox Proxy now also pulls `bridge.ActionNames` alongside `PropertyNames` to tell valid actions apart from typos; the other two already tracked both sets. `set` traps are unchanged — writes to unknown names already throw via `ConnectorManager.CallAsync`'s `ConnMethodNotFound` path.

## v0.25.2 — April 24, 2026

### Bug Fixes

- **Positional args now work when calling driver actions from scripts.** Previously a script like `connector('fileaccess').writeText('data.csv', 'hello')` failed with `Error: Path cannot be empty` — the script-bridge proxy forwards the call as `{method: 'writeText', args: ['data.csv', 'hello']}`, and `ConnectorManager.MergePositionalArgs` only converted an array to a named-arg dict when its last element was already a trailing options dict. Pure positional calls (and single non-dict scalars like `readText('data.csv')`) fell through unchanged, so `FileAccessDriver.WriteText` read `ArgString(args, "path", "")` off a bare array/string and got the empty default. `MergePositionalArgs` now also handles the pure-positional and single-scalar cases by mapping them onto the action's declared `ArgDescriptor` names, so `writeText(path, content)` → `{path, content}` and `readText("x.csv")` → `{path: "x.csv"}`. The object-literal form (`writeText({ path, content })`) keeps working exactly as before.

## v0.25.1 — April 24, 2026

### Bug Fixes

- **TTS no longer replays the last reply on page refresh, and survives the browser's autoplay block.** Browsers reject `speechSynthesis.speak()` with `error: "not-allowed"` until the tab receives a user gesture (autoplay policy) — previously this silently tore the speech chain down, stranded queued progressive chunks, and on a subsequent gesture suddenly flushed the whole backlog, which looked like "TTS was buffering and now it's firing everything at once." Both AI chat TTS (`useTTS`) and script-`say()` TTS (`useScriptSpeech`) now route every `synth.speak()` through a shared priming gate (`ttsGesture.whenReady`) that defers the call until the next `click`/`keydown`/`touchstart`; a `not-allowed` error re-arms the gate and retries the same chunk on the next gesture instead of terminating the chain. On page refresh, the chat auto-speak cursor is seeded from restored history so the last assistant reply isn't re-narrated — toggling TTS off then on still replays it explicitly, switching sessions via the chats panel resets the cursor, and new sessions / cleared chats drop it back so the next reply speaks. Two extra footguns were closed along the way: `finish()` now also drops the progressive backlog (so a hard error can't leave chunks that a later call would drain), and `speakNext`/`speak`/`speakProgressive` read voice/rate/pitch from refs so their `useCallback` identities are stable — otherwise the async `voiceschanged` event was re-identifying them, which re-fired the ChatPanel auto-speak effect and occasionally kicked a duplicate speak.

## v0.25.0 — April 23, 2026

### Features

- **Drivers can opt out of the safety gate.** Drivers with no path to physical hardware and no destructive actions now declare `requiresSafetyGates: false` — connectors of that driver bypass the [safety gate](https://docs.muxit.io/guides/safety.md) entirely (no limit checks, no confirmations, no rate caps, **no audit rows**). C# DLLs declare it at the assembly level via `[assembly: RequiresSafetyGates(false)]`; JS drivers set `meta.requiresSafetyGates: false`; built-ins override `bool RequiresSafetyGates => false;` on the driver class. Default is `true`, so every existing driver keeps its current behaviour — this is a pure opt-out. Built-in **Webcam**, **FileAccess**, and **Onvif** ship opted out. **TestDevice** keeps the flag on so it can serve as the canonical example for exploring the safety system (limits, confirms, simulate, audit) against a no-hardware target. The flag is surfaced in `drivers.list` and `driver.schema` WebSocket responses as `requiresSafetyGates`. Orthogonal to per-connector `safety.overrideLevel` — `overrideLevel` pins a gated connector to a specific level; `requiresSafetyGates: false` turns the gate off for the whole driver.

## v0.24.5 — April 23, 2026

### Changes

- **Serial connectors are three lines shorter.** The built-in serial JS drivers (`Gcode`, `SerialMonitor`, `Plotter`, `SerialProbe`) now accept plain `port` and `baudRate` fields in their connector config and build the serial transport themselves. The old pattern — a bogus `import { createSerialTransport } from "../../shell/src/transports/serial.js"` (the path never existed; the loader stripped it with a regex), a pair of top-level `const port = …; const baudRate = …;` lines, and a hand-rolled `_transport: createSerialTransport(port, { baudRate })` entry — is replaced by a two-field config block (`{ port: "COM3", baudRate: 115200 }`). Optional serial knobs (`delimiter`, `timeout`, `dataBits`, `parity`, `stopBits`) sit alongside. SerialProbe's `exportConnector` emits the new shape. The `config._transport` field still works as an undocumented escape hatch for non-serial transports (e.g. redirecting the Plotter driver at a TCP simulator via `createTcpTransport`) and for back-compat with existing workspaces — no C# host changes were needed; the cleanup is entirely in the four driver JS files, their templates, and the in-tree workspace-template connectors.

## v0.24.4 — April 23, 2026

### Changes

- **The legacy per-service AI safety mode is gone.** Settings → AI Services no longer shows a *Safety Mode* radio (Confirm / Trust), and `ai.safetyMode` has been removed from the `server.json` schema and docs. The setting was already dead code — `AiService.GetSafetyMode()` derived tool-call prompt behaviour from the global `SafetyGate.CurrentLevel` (see v0.23.0), so the per-service config was accepted and silently ignored. Unknown config keys are preserved on disk, so any `ai.safetyMode` still in an existing `server.json` is harmless; removing it keeps the file tidy. Tool-call approvals are now controlled exclusively by the safety level picker in the StatusStrip SafetyChip — see the [Safety Guide](https://docs.muxit.io/guides/safety.md#ai-user-value-confirmation) for the level-to-behaviour mapping.

## v0.24.3 — April 23, 2026

### Changes

- **The `"auto"` AI model is gone.** It was confusing — users assumed it triaged simple requests to a cheap model and escalated only when needed. In reality the proxy did a static tier-based pick (Haiku for Free, Sonnet for Pro), which silently raised cost on Pro accounts. `ai.model` now defaults to `anthropic/claude-haiku-4-5` (a single concrete ID for every tier) and the model picker in the Chat header and Settings → AI no longer offers an *Auto* option. Existing configs with `"model": "auto"` keep working: `AiService.NormalizeModelId` maps the legacy sentinel to the new default, and the UI's `currentModel` fallback now mirrors `AiService.DefaultModelId` so the picker always shows the model the server will actually call. Pin a different model by setting `ai.model` to any OpenRouter ID (e.g. `anthropic/claude-sonnet-4-5`).

## v0.24.2 — April 23, 2026

### Features

- **Restart Server is reachable without digging into Settings.** The system-tray icon menu gained a *Restart Server* entry between *Open GUI* and *Quit*, and the Titlebar's *File* menu now has a *Restart Server...* item below *Settings*. Both use the same mechanism as the existing Settings → Server button (`/api/server/restart` for the UI, `WorkspaceManager.WriteRestartFile()` + `IHostApplicationLifetime.StopApplication()` for the tray), so the launcher's restart marker auto-relaunches the process. The File-menu action asks for confirmation before firing since menu items are easier to misclick than the Settings button.

### Bug Fixes

- **Restart now takes ~2s instead of 20–30s.** The generic host's `ShutdownTimeout` was defaulting to 30s, so every restart path (tray, Settings, `/api/server/restart`) had to wait for Kestrel to drain idle WebSocket subscribers before the launcher's restart marker could fire. `HostOptions.ShutdownTimeout` is now capped at 2s — long enough for in-flight HTTP requests to finish, short enough that stale WS connections don't hold up a relaunch. Clients reconnect on their own once the new process is listening.

## v0.24.1 — April 23, 2026

### Bug Fixes

- **Settings → Server tab no longer crashes on open.** The Remote Access subsection referenced a closure variable (`licenseHook`) that wasn't in its scope, so every attempt to open the tab threw a `ReferenceError` at render time and was silently swallowed by React's ErrorBoundary, leaving the tab non-functional. The `license` prop now threads through `SettingsEditor` → `ServerSection` → `RemoteAccessSubSection`, and the remote-access tier gate renders correctly.

## v0.24.0 — April 22, 2026

### Features

- **Five-tier licensing lands in the server.** The compile-time tier table in `AppSettings.cs` now matches the published pricing: Free → Maker → Pro → Lab → Enterprise, with ranks 0–4 and Lemon Squeezy product IDs wired for the four paid tiers. Count limits are raised in line with the marketing page (Free now gets 5 connectors / 3 scripts / 5 extension drivers; Maker gets 10 connectors and unlimited scripts and drivers; Pro gets unlimited connectors). AI, MQTT broker, remote access, startup scripts, and video recording move from Pro down to **Maker**; Vision AI and autonomous agents stay at **Pro**; `SafetyLevel.Custom` and the new **Safety Policy Engine** live on **Lab**. Dashboards are unlimited on every tier. The Settings → Subscription *Plan Comparison* table now renders all five tiers dynamically from the server's feature registry (boolean features show a tick from each feature's `requiredTierId` upward; count-limited features inherit through the tier rank), and the "Pro" badge / upgrade copy across the UI is driven by the blocked feature's `blockedReason` rather than hard-coded strings, so future tier moves don't need a UI patch.
- **Safety Policy Engine is a Lab-tier feature.** The per-connector `safety: { limits, confirm, rate, interlock, safeState, overrideLevel }` block is now gated by the new `safety.policy-engine` license feature. `SafetyGate` keeps every connector's block parsed as before, but wraps lookups in a tier check: on Maker/Pro the block is ignored (with a one-time console warning per connector) and the global `SafetyLevel` policy table applies unchanged, so downgrades never silently remove safety — they fall back to a coarser but still-enforced policy. On Lab and Enterprise the block is fully honoured.

## v0.23.0 — April 22, 2026

### Features

- **Graduated safety levels with an audit trail.** Every write and action across the server now flows through a new `SafetyGate` that resolves to a single **safety level** — **Observe** (simulate every write/action so nothing reaches hardware), **Assisted** (real writes; ask once on large changes, ask every destructive action), **Active** (real writes; only destructive actions ask once), **Unrestricted** (everything passes; typed phrase to enable), plus a **Custom** row where the user picks an outcome per column. The level picker lives in the StatusStrip `SafetyChip`; applying a change is a single click in the dialog (no second confirmation — the dialog itself is the confirmation surface), with **Unrestricted** additionally requiring typing `I UNDERSTAND` inside the dialog. Once granted, a level stays active until the user picks a different one. Connector configs can add an optional `safety: { limits, confirm, rate, interlock, overrideLevel }` block — `limits.min/max` hard-block out-of-range writes at every level except Unrestricted, `largeChangeFraction` (default 25% of range) catches fat-finger deltas, `confirm: { reset: "always" | "typed" }` flags an action destructive so the level's destructive-action column applies, and `overrideLevel` pins a single connector to a specific level independent of the global. Blocked, simulated, and confirmed operations are appended to `workspace/logs/audit.jsonl` as flat `{ts, event, caller, details}` records — the record shape is deliberately extensible so a future phase can log every write without schema migration. Every origin (`script:<name>`, `ai:<sessionId>`, `dashboard:<clientId>`, `agent:<name>`, `mcp:<id>`, `system:<subsystem>`) is stamped onto the audit line. **License gating is per-level:** each level is a separate license feature (`safety.level.observe`, `safety.level.assisted`, `safety.level.active`, `safety.level.unrestricted`, `safety.level.custom`), and the audit trail is its own feature (`safety.audit`). Default ship config gives the two low-risk levels (Observe, Unrestricted) to `free` and the three lab-safety levels (Assisted, Active, Custom) plus the audit trail to `pro`, but every tier's allow-list is config-driven — future tiers (Maker, Lab, Enterprise, …) can mix and match any subset by bumping `RequiredTierId` on the relevant features in `AppSettings.cs`, no code changes in the SafetyGate. The chip and dialog are visible on every tier; locked levels appear in the dialog with a badge and disabled radio. A workspace moved to a tier that doesn't expose the persisted level is clamped to the lowest-risk allowed level on startup (falling back to Unrestricted only if the tier exposes no levels at all — a pathological config that keeps writes working until the config is fixed). The AI user-value confirmation is **not** gated by any of this: `ai.safetyMode` gains a third level — `confirm_unknown_values` (the new default) — which only prompts when a tool-call argument carries a numeric value the user did not actually say; existing `confirm` configs migrate to `confirm_all` automatically so no one loses existing prompts. The Chat Panel's pending-approval card now labels each argument as user-spoken (green) or AI-chosen (orange) so it is obvious why the confirmation is being asked.

## v0.22.1 — April 21, 2026

### Features

- **AI asks before it acts on complex requests** — the default chat behavior no longer rushes to call tools on the first sentence of a multi-step request. For script authoring, agent setup, and other automation that touches real hardware, the AI now runs a short clarification exchange first (which device, what range, what step size, what timing, where to save data, what safety limits), offers sensible options inline, restates the plan in one sentence, then acts. Simple reads, setting changes, and questions still resolve directly without a round-trip. The change lives in `MuxitServer/AI/Prompts/identity-fallback.md` and a new "Before authoring" section in `script-api.md`, and the matching guidance was mirrored into the seeded `workspace-template/config/instructions.md` so fresh workspaces get the new defaults too.

## v0.22.0 — April 21, 2026

### Features

- **Workspace EULA acknowledgement + Sandbox mode** — every workspace must now have an accepted EULA on file before Muxit will let any driver perform a hardware write. On startup the server checks `{workspace}/.muxit/EULA-ACCEPTED.md` against the canonical EULA bundled with the server (SHA256 of the body above the footer separator, LF line endings, UTF-8 no BOM). If the file is missing, corrupt, tampered, or outdated the workspace enters **Sandbox mode**: reads and polling keep working, but every property write and action call is refused at `DriverRegistry` with error code `EULA_NOT_ACCEPTED`, and `script.run()` refuses to launch. The web UI shows a blocking acceptance modal that renders the full EULA, asks for an identifier (name or email), and requires an explicit checkbox; accepting writes the acceptance file atomically and appends an entry to `.muxit/eula-history.jsonl` for the audit trail. Headless installs (`--cli`, `--mcp`, CI) accept via the new `muxit eula accept --user <id>` subcommand or the `MUXIT_EULA_ACCEPT=1` / `MUXIT_EULA_USER=…` env-var pair. Minor/major EULA bumps require re-acceptance; patch bumps do not. See `docs-site/guides/workspaces.md` for the full flow.

## v0.21.0 — April 21, 2026

### Features

- **AI can now generate and edit dashboards.** Three new tools — `list_dashboards`, `read_dashboard`, `write_dashboard` — let the Chat Panel AI (and any MCP client such as Claude Desktop / Claude Code) create `.dashboard.json` files directly in the active workspace. Ask "build me a dashboard for the PSU and the robot" and the AI calls `list_connectors` + `get_connector_schema` to discover valid bindings, then writes a complete JSON layout with gauges, sliders, charts, and action buttons wired to real device properties. Follow-ups like "add a chart of `voltage`" round-trip through `read_dashboard` → `write_dashboard` so the existing layout is preserved. Nested sub-folders (e.g. `robots/arm-1.dashboard.json`) work for AI and MCP just like the HTTP API. File operations share the same validation rules as the HTTP dashboard API (filename must end with `.dashboard.json`, content must parse as JSON, no path traversal, sub-folders must already exist), so hand-edited and AI-edited dashboards stay interchangeable. Intent routing picks up the keywords `dashboard`, `widget`, `gauge`, `panel`, `layout` so the group only loads when relevant.

## v0.20.0 — April 20, 2026

### Features

- **SCPI driver speaks USBTMC** — the `GenericScpi` driver now supports a third transport alongside TCP/LXI and Serial: USBTMC (USB Test &amp; Measurement Class), the USB-native protocol used by modern bench instruments with a front-panel USB-B port (Rigol DS1000Z/MSO5000, Keysight DSO-X, Siglent SDG/SSA/SDS, Owon, most R&amp;S gear). Set `transport: "usbtmc"` in the connector config and provide `vendorId` / `productId` (hex or decimal) — an optional `serial` filter disambiguates multiple of the same model. The driver wraps every SCPI line in a USBTMC `DEV_DEP_MSG_OUT` BBB header, implements the two-step `REQUEST_DEV_DEP_MSG_IN` + multi-transfer reassembly for reads, issues `INITIATE_CLEAR` on connect and `INITIATE_ABORT_BULK_IN` on drain recovery — enough of the spec for reliable SCPI round-trips against every mainstream instrument. Uses `libusb-1.0` via `LibUsbDotNet` (native binaries auto-bundled into the `.muxdriver` package for Windows). Requires WinUSB bound to the device via [Zadig](https://zadig.akeo.ie/). See `docs-site/reference/drivers/scpi.md` for setup details.

## v0.19.0 — April 20, 2026

### Features

- **Built-in AI is now a Pro feature.** The Chat Panel, the script `ai()` global, vision AI (`identify_objects` / `locate_object`), `ai.credits`, and the "test AI" button in Settings all now require a Pro subscription (or active Pro trial). Free-tier users who try these get a clean `AI_REQUIRES_PRO` error instead of consuming credits against the Muxit AI proxy. The Chat Panel renders an upgrade CTA in place of the input box when AI is blocked. **What stays free:** MCP (bring your own AI client — Claude Desktop, Claude Code, ChatGPT), `say()` (browser TTS), `ask.*` dashboard prompts, and every non-AI feature. Agents were already Pro-gated; this just closes the remaining entry points to Muxit-hosted AI.

## v0.18.1 — April 19, 2026

### Bug Fixes

- **Default script template and docs no longer show trailing cleanup after `while (script.running)` loops.** Pressing **Stop** cancels `delay()` *and* calls V8 `Interrupt()`, which terminates execution synchronously — so statements after the main loop (and `finally` blocks) were never reliably running, despite examples like `log.info("script finished")` suggesting otherwise. The built-in "new script" template, the sinewave demo, the scripts guide, the first-script walkthrough, the script API reference, and the AI script-writing prompt have all been updated to drop the misleading trailing cleanup and to spell out that Stop is a hard-kill. The stop behavior itself is unchanged — this is a pure docs/template alignment so scripts are written to be safe-to-abort at every iteration rather than depending on cleanup code that never runs.

## v0.15.1 — April 19, 2026

### Bug Fixes

- **Network diagnostics no longer leak LAN topology to remote callers** — `GET /api/diagnostics/network` now returns the full report (interface IPs, Windows Firewall rule list, PowerShell fix commands, elevation flag) only to loopback callers. Authenticated remote clients — including a client using a leaked session token — get a redacted summary: interface counts, firewall profile booleans, and mDNS counters, but no addresses or rule names. The Settings → Server → Network Diagnostics panel now loads via HTTP (instead of WebSocket) so the loopback check governs the UI too; the WebSocket `diagnostics.network` handler always returns the redacted view because WebSocket handlers don't currently see peer IP. The startup console banner likewise drops the LAN-address list and Administrator flag, keeping only counts and firewall findings — safer when server logs are collected to shared files.
## v0.18.0 — April 18, 2026

### Features

- **Smaller drivers fill in the on-demand `details` layer** — the `Gcode`, `Plotter`, `AudioSynth`, and `SerialMonitor` drivers now populate `Details` on the props/actions whose one-liners were hiding non-obvious behavior. Highlights: `Gcode` documents the GRBL status enum values, the `send` / `home` / `reset` / `hold` distinction around buffer flushing and step loss, and `streamFile`'s line-count-based progress (which doesn't wait for motion completion); `Plotter` documents the canvas-API angle convention (0 = +x, CCW), `lineTo` chaining polylines until `penUp` breaks them, and the `draw` batch's non-atomic error behavior; `AudioSynth` documents `volume`/`waveform` applying to the *next* playback (not in-progress), the `playMelody` shorthand grammar with number-as-rest, and that overlapping playback calls replace rather than layer; `SerialMonitor` documents that `port`/`baudRate` are transport-owned sentinel values and that fast bursts need the `output` stream rather than `lastLine` polling. This completes the first pass of the `details` rollout — every shipped driver (except the intentionally minimal `Template` and the not-yet-stable `Avantes`) now carries extended markdown on its subtle props and actions.

## v0.17.0 — April 18, 2026

### Features

- **Extension drivers fill in the on-demand `details` layer** — the premium `Midi`, `Scpi`, `Vision`, and `Fairino` extension drivers now populate `Details` on their most semantically dense props/actions. Highlights: `Midi` documents channel 1-16 vs wire-level 0-15, velocity-0 = Note Off, `sendSysex` auto-framing of F0/F7, and `learn` timeout behavior; `GenericScpi` documents query retry-once + `timeout` scope, `settleMs` applied to writes only, and `readErrors` iterating until the SCPI `"No error"` sentinel; `Vision` documents the `color`/`contour` tracker param schemas and `calibrateColor` HSV margins (±10 hue, ±40 sat/val); `Fairino` documents the 6-element joint/TCP layout with mixed mm/deg, null-vs-zero semantics, `moveJ` arc vs `moveL` straight-line paths, blending with `blendT` / `blendR`, singularity risk, `stop` flushing the queue vs `pause` preserving it, and `disable` letting the robot fall under gravity. As before, `Details` only flows through on-demand surfaces (doc disclosure, editor hover, `get_*_schema`) so the upfront AI prompt cost is unchanged.

## v0.16.0 — April 18, 2026

### Features

- **Built-in drivers fill in the on-demand `details` layer** — the new `Details` field added in v0.15.0 is now populated across every built-in driver: `Webcam`, `Onvif`, `MqttBridge`, `FileAccess`, and `TestDevice`. The one-line descriptions stay the same (and the AI system prompt summary stays the same size), but opening a driver's doc page or hovering a method in the script editor now surfaces parameter enums, clamp ranges, side effects, and failure modes that the one-liners hid — e.g. Onvif's PTZ speed sign convention, FileAccess's write-size enforcement timing, MqttBridge's QoS levels and retain-flag semantics, Webcam's silent backend-dependent brightness/contrast normalization. The extra markdown only travels through on-demand surfaces (driver doc disclosure, editor hover popup, `get_connector_schema` / `get_driver_schema`) so the upfront token cost is unchanged.

## v0.15.0 — April 18, 2026

### Features

- **Driver descriptors gain an on-demand `details` layer** — `PropertyDescriptor` and `ActionDescriptor` now carry an optional markdown `Details` field alongside the existing one-line `Description`. The short description stays in the upfront AI system prompt and IntelliSense summary line (so per-request token cost is unchanged); the extended markdown travels only through on-demand surfaces: the driver doc page's new "Show details" disclosure, the script editor's hover/autocomplete popup, and the full-schema payloads of `get_connector_schema` / `get_driver_schema`. Authors put parameter enums, side effects, truncation caps, and failure modes in `Details` — everything a user or AI agent would otherwise have to discover through trial and error. The `SerialProbe` driver now demonstrates the pattern with extended docs on its five subtle actions (`scanBaud`, `hypothesize`, `analyzeFrames`, `stimulus`, `exportConnector`); other drivers fill in `Details` opportunistically.
- **Network diagnostics panel for "my device can't connect" triage** — Settings → Server → Network Diagnostics now renders a live report: bind address/port, Kestrel listener state, network interfaces with per-interface mDNS advertise/skip reasons, mDNS query/answer counters, a UDP 5353 conflict probe (warns when Apple Bonjour / Windows mDNSResponder / Avahi is already bound), and — on Windows — the active Windows Firewall profile, whether any enabled rule covers the listening port, and any stale `muxit` Block rules overriding an Allow. The same report prints as a startup console banner and is exposed over HTTP (`GET /api/diagnostics/network`) and WebSocket (`diagnostics.network`), so a phone or laptop that *can't* reach the server can still curl it. The UI shows copy-paste PowerShell fix commands (add allow rule, remove stale block rules, set profile to Private); the diagnostics layer is strictly read-only and never touches firewall state. Backed by `MuxitServer/Core/NetworkDiagnostics.cs`, `Http/DiagnosticsApi.cs`, and `WebSocket/Handlers/DiagnosticsHandler.cs`.
- **SerialProbe port / baud configurable at runtime** — the driver now configures its serial port and link-layer settings at session time via actions (`listPorts`, `openPort`, `closePort`, `setBaudRate`, `setPort`), so the AI can try different configurations without editing the connector config. `scanBaud` accepts an explicit `portPath` + `reopenAt` policy, `exportConnector` refuses to run without an active port (so the generated config captures the confirmed `portPath` + `baudRate`), and the starter template + example connector no longer pin a port — the AI picks one via `listPorts` / `openPort` at session start. The driver now also exposes five terminal-friendly streams — `traffic` (unified RX/TX with arrow prefix), `rxHex`, `rxText`, `txHex`, `txText` — alongside the existing `frames` / `events`; raw-hex output previously went through an un-wired emitter and never reached terminal dashboards. The legacy preconfigured `config._transport` path still works for backward compat.
- **Dev Console: driver registry publication status** — the Dev Console Drivers tab now shows, per driver, whether the latest built `.muxdriver` matches what's published to the public `muxit-drivers` registry, with a direct action to publish or re-publish from the button row. Release routing in `lib/driver-manager/publish.js` targets the public `muxit-io/muxit-drivers` repo instead of the development repo.

### Changes

- **Verbose AI request/response logging is now opt-in** — the AI service no longer floods the server log with full proxy request bodies, SSE event dumps, or tool-call summaries by default. Set `MUXIT_AI_DEBUG=1` before starting the server to re-enable the full firehose while diagnosing prompt or tool-format issues.

## v0.14.0 — April 18, 2026

### Features

- **Declarative SCPI schema keeps connector configs light** — the GenericScpi driver now reads an optional `config.scpi: { properties: {...}, methods: {...} }` block and auto-synthesizes the SCPI boilerplate. An entry like `voltage: { cmd: "VOLT", type: "float", unit: "V" }` becomes a full read/write property (get sends `VOLT?`, set sends `VOLT 5`), and `save: { cmd: "*SAV", arg: "int" }` becomes `c.save(3)` → sends `*SAV 3`. A trailing `?` on the command marks the property read-only. Top-level `properties`/`methods` with the same name still win, so vendor quirks can stay hand-written while the regular 80% shrinks to a single-line declaration. The `bk-psu.js` template loses ~40 lines of repeated `parseFloat`/`${Number(v)}`/`.trim()` boilerplate. Under the hood, `DllDriverHost.GetDriverMetaForInstance` now returns live per-instance schema to `ConnectorInstance` so declared properties reach the connector pipeline (DLL drivers that want per-config schema in the future get this for free). The SCPI driver is bumped to v1.2.0.

## v0.13.0 — April 17, 2026

### Features

- **Open file tabs refresh automatically on FileAccess writes** — a `.csv` log being appended to from a running script now updates its chart (or text) view live, no close-and-reopen needed. `FileAccess` actions (`writeText`, `appendText`, `writeBinary`, `deleteFile`, `rename`) emit a new `workspace.file.changed` WebSocket event with the workspace-relative path; the editor debounces rapid events (~150 ms) and reloads any open tab pointing at that path. Tabs with unsaved edits are skipped so in-progress work isn't clobbered.
- **Script API prompt and docs steer the AI away from `require('fs')`** — the AI script-sandbox prompt, the Script Guide, and the Script API Reference now include a dedicated "Working with Files" section that shows the FileAccess connector pattern (`connector('files').writeText({ path, content })`, `appendText`, `readText`, …) and explicitly calls out that `require`, `import`, and Node.js filesystem APIs are not available. Cuts down on AI-generated scripts that try `require('fs')` and fail at runtime.

## v0.12.1 — April 17, 2026

### Bug Fixes

- **AI chat TTS no longer gets stuck behind script speech** — after the v0.12.0 split, the chat's progressive TTS only kick-started when the global `speechSynthesis` queue was idle, so any in-flight (or just-finished) script `say()` utterance left the chat chunks queued forever and the toggle felt broken. The chain now starts whenever its own iterator isn't running, regardless of what `useScriptSpeech` is doing on the shared queue — the browser still plays the utterances in order. Re-enabling the chat speaker after a response has already arrived now also speaks that last response, instead of silently waiting for the next one.

## v0.12.0 — April 17, 2026

### Features

- **Independent script speech toggle** — script `say()` output now has its own speaker button (🔊) in the top status strip, decoupled from the AI chat TTS toggle. Mute the AI without silencing your scripts (or vice versa). The new toggle also makes `say()` audible while the chat panel is closed — previously the auto-speak only ran when the chat sidebar was the active panel. Persisted as `voice.tts.scriptEnabled` (default on).

## v0.11.0 — April 17, 2026

### Features

- **CSV files open as charts** — opening a `.csv` or `.tsv` file from the File Explorer now renders it as an interactive line chart (powered by the existing uPlot dependency). The parser auto-detects the delimiter (`,`, `;`, or tab), whether the first row is a header, and each column's type (timestamp, number, or text). By default the first timestamp column becomes the X-axis and every numeric column becomes a Y-series; both can be changed from the controls bar. A toggle in the tab's control strip switches between chart view and the raw Monaco text view, so the files produced by `FileAccess.appendText(...)` in measurement scripts are now immediately inspectable without wiring up a dashboard widget. Files over 100 000 rows are capped on render (with a banner) to keep the chart responsive. No new dependencies.

## v0.10.0 — April 17, 2026

### Features

- **AI no longer hangs on long-running scripts** — `run_script` and `run_code` now accept `wait_seconds` (default 15, max 120) and return `status: "running"` with a `run_id`, recent output, and a `next_seq` cursor if the script doesn't finish within the window. The script keeps running; the assistant stays responsive. Three new tools — `get_script_status`, `get_script_output` (with `since_seq` cursor), and `wait_for_script` — let the AI poll progress, fetch incremental log output, or block again with a bounded wait. Pass `wait_seconds: 0` for known background scripts (monitors, watchers) to kick off and return immediately. Per-script output is retained for about 5 minutes after completion so polls that arrive just after the script exits still see the final result and log tail.

## v0.9.1 — April 17, 2026

### Bug Fixes

- **Midi driver release-ready** — shipped with its own first-class `template.js` (the old `MidiDriver.Template.cs` C# string has been removed), registered in the documentation sidebar and the Built-in Drivers index, and given accurate manifest tags (`["midi", "audio"]` — a new `midi` tag was added to the controlled vocabulary so it's discoverable in the Extensions panel). The driver source and behaviour are unchanged.

### Features

- **Generic SCPI driver 1.1.1** — consolidates the earlier 1.1.0/1.1.2 pair into a single coherent release:
  - **Stale-response framing** — every transaction drains inbound bytes before sending, auto-resyncs on query timeouts or empty responses, and retries once with a known-clean RX buffer. Fixes the "values off by one" / `NaN` flicker on slow instruments.
  - **`settleMs` option** — optional post-write pause held inside the transport lock, so a set-then-query sequence reads back the freshly applied setpoint on instruments that need a few ms to commit.
  - **`debug` TX/RX stream** — when `debug: true`, every transaction's command and response is emitted on the `scpi` stream (for Terminal-widget live tails) and written to server stdout.
  - **Cleaner defaults & internals** — TCP host default is now the RFC 5737 placeholder `192.0.2.100`, the unused `IScpiTransport` interface was removed in favour of the existing abstract base, and the `*IDN?` fallback now only swallows `TimeoutException` / `InvalidOperationException` instead of every `Exception`.
  - **New reference page** — [Scpi Driver](https://docs.muxit.io/reference/drivers/scpi.md) documents every property, action, config option, the framing/recovery model, and a BK Precision example connector.

## v0.9.0 — April 16, 2026

### Features

- **Guided tour via the AI chat** — new **Help → Guided Tour** menu in the title bar with one-click starter prompts ("Install a Driver", "Create a Connector", "Drag Properties into a Script", "Build a Dashboard", plus a general overview). Each entry pins the AI chat open and sends a pre-written question so the assistant walks you through the task. Starter prompts are not a gate — you can ask for a tour in your own words and get the same behaviour.
- **AI docs-reading tools** — three new tools (`list_docs`, `read_doc`, `search_docs`) give the AI direct access to every page of this documentation site. Pages are embedded into the server binary at build time so they're available offline and always match the running version. The chat picks them up automatically when your question includes phrases like *how do I*, *walk me through*, *tour*, *tutorial*, *getting started*, or *what is* — expect the assistant to quote the relevant guide back instead of guessing. Dev-mode reload is available via `MUXIT_DOCS_DEV=1`, mirroring the prompt fragment hot-reload. Backed by a new `DocsRegistry` and `DocsToolHandlers`.

## v0.8.0 — April 16, 2026

### Features

- **New driver: SerialProbe** — AI-assisted serial protocol reverse-engineering. A Tier 1 bundled JavaScript driver that captures raw bytes in labelled windows, auto-detects framing (`lines-lf` / `lines-crlf` / `stx-etx` / `fixed:N`), runs local CRC-16/Modbus and XOR-trailing checks, correlates stimulus/response pairs, and exports a working connector config when a hypothesis is confirmed. The AI never sees raw traffic — only summaries returned by local analysis — so a full session stays cheap. *(Retired in a later release — superseded by the built-in transport-probe tools in the device-authoring flow.)*
- **Raw-byte streaming on SerialTransport** — `setRawMode(true)` + `onRawData(hex, timestampMs)` bypass line buffering and deliver per-chunk hex with timestamps. `portPath` and `baudRate` are now accessible from JS, enabling drivers like SerialProbe to spawn temporary transports for baud-rate scans.

## v0.7.0 — April 16, 2026

### Features

- **New MIDI extension driver** — live input/output for any USB or virtual MIDI device, per-channel accept-lists, input→output pass-through, internal 24-PPQN clock with `start`/`stop`/`continue` transport, Standard MIDI File playback and recording (sandboxed to `workspace/midi/`), `panic` (All Notes Off + All Sound Off + Reset All Controllers on every channel, with local `activeNotes` bookkeeping cleared), and a `learn` action that resolves the next incoming message for binding physical knobs/pads. Incoming messages are normalized to `{ type, channel, note?/controller?/…, tsMs }` and published on three streams: `events` (everything), `note` (just Note On/Off), and `clock` (24-PPQN ticks, opt-in via `emitClockStream: true`). Built on [DryWetMIDI](https://github.com/melanchall/drywetmidi) and ships as `muxit-midi-v0.1.0.muxdriver` — install via the Extensions panel. Full reference: [Midi Driver](https://docs.muxit.io/reference/drivers/midi.md).
- **AudioSynth extension driver** — new free tier-3 driver that plays tones, musical notes, and short melodies on the server host's default audio output via NAudio. Four waveforms (sine / square / triangle / sawtooth), volume control, click-free attack/release envelopes, and replace-not-queue playback semantics so a new sound always cleanly replaces the previous one. Actions: `playTone(frequency, duration)`, `playNote(note, duration)`, `playMelody(notes)` (shorthand `"C4:200,E4:200"` or `[{note,duration}, …]`), `beep()`, `stop()`. Properties: `volume`, `waveform`, `playing`. Ships with a `workspace-template/connectors/audio.js` example wiring up `chime()`, `alert()`, and `fanfare()` helpers. See [AudioSynth reference](https://docs.muxit.io/reference/drivers/audio-synth.md) — useful for lab-side "experiment complete" cues, CNC/robot feedback tones, and safety alerts.
- **New driver tags** — `audio`, `synth`, and `notification` added to the [controlled tag vocabulary](https://docs.muxit.io/reference/driver-tags.md) (and `lib/driver-manager/schema.js`) so audio-class drivers are discoverable in the Extensions panel.

## v0.6.0 — April 16, 2026

### Features

- **Centralised AI instructions and tool registry** — every AI-facing prompt fragment (script API guide, decision tree, agent identity, per-autonomy blurbs, TTS rules, tool descriptions) now lives as markdown under `MuxitServer/AI/Prompts/` and is loaded at runtime by a new `PromptRegistry`. A new `ToolRegistry` owns the authoritative tool list and dispatch; per-group handler classes under `MuxitServer/AI/ToolHandlers/` replace the 1,040-line monolithic `AiToolExecutor`. Chat and agent system prompts are composed by a shared `SystemPromptBuilder` from these fragments, eliminating the parallel implementations in `AiService.BuildSystemPrompt` and `AgentInstance.BuildAgentSystemPrompt`.
- **Dev-mode prompt hot-reload** — setting `MUXIT_PROMPT_DEV=1` makes `PromptRegistry` read fragments from the source tree on every lookup, so prompt edits are visible without rebuilding the server.

### Bug Fixes

- **Consistent script-writing guidance** — resolved contradictions between `write_script`/`run_code` tool descriptions (which showed `await dev.prop()`) and the Script API guide (which said "Do NOT use await"). Canonical text now lives once in `Prompts/script-api.md` and is referenced from everywhere else.
- **Robot-specific rules scoped to the robot section** — the `workspace-template/config/instructions.md` rule "do not add delays in the script" previously appeared to apply to all scripts; it is now inside the `### robot` device subsection where it belongs, and the generic Script API guide keeps `delay()` as the recommended loop pacing tool for non-robot devices.
- **Edit connector visibility from the Connectors panel** — expanded connector cards have a pencil (✎) icon that enters an edit mode. In that mode every property, action, and stream gets an eye-icon toggle and each section header gets **hide all** / **show all** shortcuts; hidden items appear greyed-out so they can be toggled back on. Both driver-sourced items and custom methods / properties defined in the connector's own `methods` / `properties` blocks can be hidden or exposed (previously only driver items). Changes are written back to the connector's `.js` source (the top-level `hide: […]` array, clearing any `expose:` whitelist to keep the file consistent) and the connector is hot-reloaded — the AI picks up the new surface on the next turn, no server restart required.
- **Edit primitive driver-config from the Connectors panel** — edit mode also reveals a **Config** section that lists each driver-config key with an inline editor (text / number / checkbox). Committing a value surgically rewrites the matching literal in the `.js` source (either at the top level or inside the nested `config: { … }` block, whichever already holds the key) and hot-reloads only that connector. Non-primitive entries (expressions, transports, objects) are shown read-only with a tooltip explaining that the file must be edited directly. Framework-injected internals (anything whose key starts with `_`, e.g. `_workspacePath`) are never exposed.
- **Auto-open Config on load error** — when a connector fails to initialize (wrong serial port, unreachable host, ...) the card automatically expands into edit mode with the Config section visible, so the problem can be fixed without opening the file. A failed reload keeps the connector in the enabled list with its `InitError` set, so the Config panel stays reachable for the retry.
- **Compact pill switch for enable/disable** — the per-connector checkbox is replaced with a small toggle-pill to avoid the visual collision with the pencil/checkmark icons elsewhere in the header. Property rows show the `R/W` access label inline again (previously only in the tooltip).
- **New WebSocket endpoints** — [`connector.visibility.set`](https://docs.muxit.io/reference/websocket-api.md#connector-visibility-set) and [`connector.driverConfig.set`](https://docs.muxit.io/reference/websocket-api.md#connector-driverconfig-set) drive the new UI. [`connector.schema`](https://docs.muxit.io/reference/websocket-api.md#connector-schema) gains an optional `includeHidden: true` flag and its response now includes `driverConfig`, `hiddenItems`, and `visibilityMode`; streams are now returned as `[{name, hidden}]` objects (the UI already handled both forms).

## v0.5.1 — April 15, 2026

### Features

- **License status on the premium driver detail page** — when a premium driver (e.g. Fairino) is installed, the driver detail page now shows a clear license banner: "License active", "Trial — N day(s) left", or "License required" with an actionable message. `marketplace.detail` carries new `licensed`, `licenseStatus`, `licenseMessage`, and `trialDaysRemaining` fields for locally-loaded premium drivers.

## v0.5.0 — April 15, 2026

### Features

- **Premium driver management in the Dev Console** — new **Premium** tab provides a single source of truth for premium drivers (currently Fairino, Vision, Avantes). Each row joins the driver's `manifest.json` with its build / sign / package state and its Lemon Squeezy product binding. Inline editor for the `commerce` block writes back to `drivers/<name>/manifest.json` so the binding ships inside the signed `.muxdriver`. Optional **Push to LS** mirrors manifest storefront copy to the Lemon Squeezy product via the v1 REST API (requires `LEMON_SQUEEZY_API_KEY` env var on the dev console).
- **Manifest `commerce` block** — driver manifests now carry an optional `commerce` block (`lemonSqueezyProductId`, `lemonSqueezyVariantId`, `price`, `storefront.{tagline,longDescription,images}`) for premium drivers. At server boot, `DllDriverHost` reads the product ID and feeds it into `LicenseManager.RegisterDynamicFeature(...)` so a customer's Lemon Squeezy activation can be matched back to this driver. Validator emits new rules (`COMMERCE_MISSING_FOR_PREMIUM`, `COMMERCE_LS_PRODUCT_MISSING`, `COMMERCE_LS_PRODUCT_FORMAT`, `COMMERCE_PRICE_INVALID`, `COMMERCE_FREE_FORBIDDEN`).
- **`node drivers.js premium-status` CLI** — new headless command reports the build / sign / commerce readiness of every premium driver. `--strict` exits non-zero on any outstanding issue, suitable as a release gate.

## v0.4.2 — April 15, 2026

### Bug Fixes

- **Installed drivers appear immediately after install** — the server now broadcasts `drivers.changed` over WebSocket after a marketplace install or uninstall, so the Extensions panel's Installed tab refreshes without needing a reconnect.
- **Premium badge in Available tab** — the `marketplace.search` response now includes the `category` field, and the Extensions panel renders a Premium tag next to premium drivers on the Available tab (not just the Installed tab).

### Features

- **Version selector for drivers with multiple registry entries** — when the registry exposes several versions of the same driver id, the Available tab now renders a single card with a version dropdown instead of one card per version. `marketplace.install` accepts an optional `version` field so clients can pin a specific version; omitted, the server installs the highest-versioned entry.

## v0.4.1 — April 14, 2026

### Bug Fixes

- **Wake word changes apply instantly** — updating the wake word phrase in Settings → Voice now restarts the background listener immediately instead of requiring a page refresh.
- **Microphone selection applies instantly** — picking a different input device while hands-free listening is active now reopens the capture stream with the new device, no refresh needed.

### Features

- **"Saved — applied immediately" indicator in Settings** — every change to Voice, AI Services, and AI Behavior settings now shows a transient confirmation badge so users can see the change took effect without refreshing the page.

## v0.4.0 — April 14, 2026

### Breaking Changes

- **Removed DEBUG-only license bypass** — `AppSettings.DevMode`, the surrounding `#if DEBUG` compile-time switch, and the `license.dev_simulate` WebSocket endpoint have all been deleted. License enforcement now applies uniformly to every build configuration, closing the risk that a mis-shipped Debug binary would silently disable tier / count / entitlement gates and expose a backdoor that could forge any subscription tier. Side effect: 8 of the 9 build warnings emitted by `dotnet build MuxitServer -c Release` (all `CS0162 Unreachable code detected`) are gone, plus a related `CS8602` nullable-reference warning in `Program.cs`.

## v0.3.2 — April 14, 2026

### Bug Fixes

- Fix AI script prompt to teach canonical property syntax (db55b4e)
- Fix Hardware pane polling pile-up on state updates (303b1a1)
- Fix Hardware pane writing to devices on mount (49b3e2e)
- Fix SCPI driver stale-response framing + add settleMs / resync (31e2b14)
- Fix GUI page flickering on driver info / marketplace panes (7919baa)
- Fix Scpi manifest entryPoint drift + add validator rule to catch class (52c31bc)
- Fix marketplace install on Windows + route premium drivers correctly (7e23aa8)
- Fix dev console crash on boot — stale MUXIT_SERVER_URL reference (faf845e)
- Fix Overview/Diagnostics tabs not refreshing when MuxitServer comes up (804ae1a)
- Fix dashboard Knob widget first-quarter unresponsiveness (f28d33d)
- Fix outdated await/function-call patterns in docs and examples (25b3589)
- Fix DeepEquals numeric type coercion causing phantom serial writes (ae33d8d)
- Fix serial overload from knob and improve SCPI log accuracy (b48f460)
- Fix BK-PSU serial overload, property types, and store updates (cf39a4f)
- Fix PSU polling timeout blocking other connectors (d0e67b6)
- Fix dashboard Knob widget first-quarter unresponsiveness (93709bb)
- Fix outdated await/function-call patterns in docs and examples (90ae0de)
- Fix DeepEquals numeric type coercion causing phantom serial writes (63b11f5)
- Fix serial overload from knob and improve SCPI log accuracy (de753ac)
- Fix BK-PSU serial overload, property types, and store updates (9db1d0f)
- Fix PSU polling timeout blocking other connectors (776a8c2)
- Fix docs site CSP errors by using path-conditional security policy (0cfe29e)
- Fix ai() script command returning empty response (6eabb38)
- Fix log copy formatting: use tab-separated fields instead of line breaks (e3b0403)
- fix: preserve InitializeAsync wrapper for MCP stdio mode (5addd16)

### Features

- Self-pace Hardware pane polling with setTimeout chain (c67fd82)
- SCPI driver 1.1.2: also write TX/RX to stdout when debug=true (1cdfb28)
- Rename sidebar tabs, add create shortcuts, fix Connectors show-all crash (e3baab9)
- Bump SCPI driver to 1.1.1 for version verification (5d8c590)
- debugging SCPI (8cd8894)
- Flatten workspace/drivers and keep .muxdriver packages intact (95aa67c)
- fixed docs build error; fix PSU connector (2765ef1)
- Extract Vision into a premium extension; drop muxit-vision static feature (8c7fc96)
- Expose EventBus to drivers via an SDK-level IDriverHost (67cbc84)
- Dev console: rename pass + clickable sources + promote/extract refactor (7178573)
- Dev console UI cleanup: collapsible driver cards + Overview clarity (1618e7f)
- Phase 6c: deployment simulation — local mocks for GitHub + driver registry (5718ad5)
- Phase 6b: driver authoring — per-driver manifest editor in dev console (270a629)
- Phase 6a: expanded per-tab docs + new Release pipeline tab (2b2ce8a)
- Proxy MuxitServer HTTP + WS through dev console to bypass CORS (8da35cf)
- Auto-discover MuxitServer host:port instead of hard-coding 127.0.0.1:8765 (ed73a02)
- Add Driver/Feature Overview tab + DEBUG tier simulator to Dev Console (0ff217f)
- Replace in-server Dev Tools panel with a standalone Dev Console (Phase 4) (eada670)
- Revert "Add Dev Tools panel skeleton with Workspace + Diagnostics tabs (Phase 4)" (bb3aeb3)
- Add Dev Tools panel skeleton with Workspace + Diagnostics tabs (Phase 4) (c36710a)
- Add server-side driver validator and surface diagnostics in UI (Phase 3) (5a6b1bd)
- Reorganize muxit.js menu and split driver build out of build.js (Phase 2) (985ec91)
- Codify driver manifest schema and structured validator (Phase 1) (f06fd90)
- Gate SCPI TX/RX stream behind debug config option (7adf534)
- Throttle property writes to prevent knob/slider flooding serial devices (cdc6b0a)
- Add SCPI command/response stream to PSU dashboard for debugging (395d24a)
- updated manifests (7ddea2a)
- added manifests for avantes, fairino, scpi drivers (dd9b3a7)
- Gate SCPI TX/RX stream behind debug config option (5fae791)
- Decouple workspace from git — use extensions for driver development (b760d92)
- Throttle property writes to prevent knob/slider flooding serial devices (0b131e2)
- Add SCPI command/response stream to PSU dashboard for debugging (b634499)
- Add clean URL rewriting for docs so help tab links work (b814c86)
- Add AI Chat toggle to View menu, sort sidebar tabs to match icon order (a873bc5)
- Add mobile/desktop view switcher, pin AI chat to secondary sidebar (9af64d2)
- fixed robot enable state (befc1f8)
- robot dashboard (016547a)
- test script (e354dd2)

### Other

- refactor: split startup into core + background phases for instant GUI loading (cae93d6)
## v0.3.2 — April 14, 2026

### Bug Fixes

- **Hardware pane no longer writes to the device on mount** — the desktop Hardware pane (`ConnectorBrowser`) polled writable properties by sending `args: []` in its `connector.call` WebSocket message. An empty array is not `null`, so the server routed the call as a SET with an empty-array payload, which JS coerces to `0` for numbers and `true` for booleans — silently reprogramming instruments the moment you expanded a connector card (e.g. writing `VOLT 0 / CURR 0 / OUTP ON` to a power supply). Fixed on both sides: the UI now omits the `args` field for reads, and `ConnectorManager.CallAsync` normalises an empty args array to `null` so no future caller can hit this trap.

## v0.3.1 — April 14, 2026

### Bug Fixes

- **SCPI driver: stale-response framing fix** — `GenericScpi` over TCP and Serial no longer mis-attributes a late reply from a prior (timed-out) transaction to the next query. The transport now drains inbound bytes at the top of every transaction, owns its own line buffer on TCP (removing the hidden `StreamReader` buffer), and enters a self-healing "resync" state on timeout / empty-response so the cascade that made voltage reads collapse to `0` after a few iterations is closed out. The connector-level `parseFloat` hazard that rendered `NaN` / `object [0]` in the Hardware pane is addressed by a new `num()` guard in `bk-psu.js` and by the driver rejecting empty SCPI responses outright.
- **SCPI driver: echo stripping** — instruments with local-echo enabled are handled automatically (the driver peels one echo layer before returning the response).

### Features

- **SCPI driver `settleMs` option** — hold the transport lock for N ms after every non-query write, so a `VOLT 5` / `VOLT?` round-trip reads back the freshly applied setpoint without needing `delay()` in the connector.
- **SCPI driver: shared transport base** — TCP and Serial transports now share `ScpiTransportBase`, collapsing ~130 lines of duplicated locking / pacing / framing into one place.

## v0.3.0 — April 14, 2026

### Features

- **Flat `workspace/drivers/` layout** — the `free/` and `premium/` subdirectories are gone. Installed drivers now sit as single `.muxdriver` package files directly under `workspace/drivers/`; the server extracts each package transparently into a hidden `workspace/drivers/.cache/<id>@<version>/` on load. The `category` in each package's `manifest.json` is the sole source of truth for premium enforcement — a DLL's location on disk no longer matters.
- **Package-native install/uninstall** — installing a driver now copies the `.muxdriver` file into `workspace/drivers/` untouched; uninstalling deletes it. Stale cache entries are garbage-collected automatically on the next scan.

### Breaking Changes

- Any existing `workspace/drivers/free/` or `workspace/drivers/premium/` contents are no longer scanned. Reinstall drivers via the Extensions panel.
- Editor API now blocks all writes under `drivers/` (previously only blocked `drivers/free/` and `drivers/premium/`). Installs must go through the Extensions panel.
- `node drivers.js sign` now signs each premium driver's `bin/publish/` DLL (pre-package). Re-run `node drivers.js build` afterwards to repackage.

## v0.2.0 — April 6, 2026

- **Add revision history page** accessible from Help menu and documentation sidebar
- **Bump version** from 0.1.0 to 0.2.0

## v0.1.0 — April 2, 2026

Initial development release.

### Bug Fixes

- **Fix V8 OOM crash** from sinewave script tight loop (#188)
- **Fix AI Service section hidden** when credits fetch fails (#187)
- **Fix Muxit AI proxy integration** — system prompt format, tools format, and error messages (#183)
- **Fix `await delay()` in connector configs** resolving instantly (#182)
- **Fix scripts stuck in `_running` after stop**, blocking new script starts (#179)

### Features

- **Align docs styling** with muxit.io and fix MQTT docs (#186)
- **Improve license key masking** to show first 8 + last 4 chars (#185)
- **Add oscilloscope widget** with phosphor glow and persistence effects (#184)
- **Add AI service card** to license UI with keys, credits, and test button (#181)
- **Add smart tool filtering** to reduce AI costs and improve cheap model reliability (#180)
- **Redesign license plan comparison** to dynamic column grid (#178)
