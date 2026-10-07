# Workspaces

A **workspace** is a self-contained folder that holds everything Muxit needs to run your lab: device connectors, automation scripts, dashboards, drivers, and configuration.

## What's Inside a Workspace

```
my-workspace/
  config/         Server settings (server.json, ai-memory.json)
  connectors/     Device configurations (.js files)
  scripts/        Automation scripts (.js files)
  dashboards/     Dashboard layouts (.dashboard.json)
  agents/         AI agent configs (.agent.json)
  drivers/
    community/    Free extension drivers (.dll)
    premium/      Licensed drivers (.dll)
  data/           Sandboxed file storage
```

## Files outside the workspace

Muxit keeps to the workspace. Nothing you write in Muxit can read or write a file elsewhere on the computer:

- **Scripts and connector files** run in a sandbox with no file access at all — no `fs`, no `require`.
- **The editor, the Explorer and the AI** (chat and MCP file tools) only see the workspace.
- **Built-in drivers that take a path** only accept paths inside the workspace: the
  [File Access](https://docs.muxit.io/reference/drivers/file-access.md) base folder, [e-mail](https://docs.muxit.io/reference/drivers/email-notifier.md) attachments,
  [webhook](https://docs.muxit.io/reference/drivers/webhook-notifier.md) images, camera recording names and
  [label](https://docs.muxit.io/reference/drivers/label-printer.md) templates. A relative path resolves against the workspace; a path that
  leads out of it — absolute, through `..`, or through a symbolic link — is refused with `PATH_OUTSIDE_WORKSPACE`.

The exception is drivers written in **Python or C#**. They run with your own user rights, like any program you
install, so they can reach the whole computer. Install only drivers you trust.

Muxit itself also keeps a few files outside the workspace for its own use: the workspace list, logs and the license
cache, in `~/.muxit` (`%LOCALAPPDATA%\Muxit` on Windows). The **New Workspace** and **Open Workspace** dialogs can
browse your folders, because that is where you pick a workspace's location.

## First-Run Setup

On a fresh install Muxit creates a workspace for you and opens straight into it —
no setup screen. It is called **Default**, comes seeded with the example
connectors, scripts and dashboards, and lives in a `workspace/` folder next to
the Muxit binary (`%LOCALAPPDATA%\Muxit\workspace` for the standard Windows
install). If that location isn't writable, Muxit falls back to
`%LOCALAPPDATA%\Muxit\workspace` on Windows or `~/.muxit/workspace` on
macOS/Linux. The path is printed in the startup log and named by the title-bar
**`Workspace: <name>`** menu.

If you'd rather start somewhere else, use **New Workspace…** or
**Open Workspace…** from that menu — nothing is locked in.

Everything Muxit keeps *about* workspaces rather than *in* them — the catalog
of known workspaces (`workspaces.json`), instance locks, logs and the license
cache — lives in a per-user data directory: `~/.muxit` on macOS and Linux,
`%LOCALAPPDATA%\Muxit` on Windows. Set the `MUXIT_DATA_DIR` environment
variable to move all of it somewhere else, for a portable install or a bench
machine where each person wants their own catalog.

### Self-repair

Muxit checks the workspace layout on **every** start and puts back anything
missing: absent folders are recreated, and a workspace with no `config/server.json`
gets one written with sensible defaults. So an interrupted first run, or a folder
deleted by hand, fixes itself on the next launch instead of leaving a workspace
that looks fine but can't be edited. What it does *not* do is bring back files
you deleted on purpose: example content is seeded once, recorded in
`.muxit/seeded.json`, and never copied again. Self-repair also never touches the
workspace's display name — a workspace that is already in the catalog keeps the
name you gave it; only a workspace seen for the first time is registered as
**Default**.

## The Workspace Menu

The titlebar shows a **`Workspace: <name>`** menu (replacing what used to live under File). Every workspace operation hangs off this one menu:

- **Rename Workspace…** --- change the display name of the current workspace. The folder on disk is untouched and no restart is needed.
- **Switch to** *(inline list)* --- one click switches to any other workspace in your catalog. No dialog.
- **Open Workspace…** --- open the picker dialog to browse to a workspace that isn't in the catalog yet.
- **New Workspace…** --- create a new workspace folder + register it.

## Creating a New Workspace

From the **Workspace** menu in the titlebar, select **New Workspace…**. This opens a dialog where you can specify:

- **Location** --- The filesystem path where the workspace will be created (e.g., `/home/user/my-lab` or `C:\Users\me\Documents\my-lab`).
- **Name** (optional) --- A friendly name for the workspace. Defaults to the folder name.
- **Include example content** --- on by default. Copies the example connectors,
  scripts and dashboards in as a starting point. Untick it for an empty
  workspace; the choice is remembered, so the examples aren't added later.

Muxit creates the standard directory structure and a minimal `server.json` configuration file.

The location must be a new or empty folder (or an existing workspace) — Muxit
won't scatter its folders into a directory that already holds something else.

## Opening an Existing Workspace

From the **Workspace** menu, select **Open Workspace…**. The dialog shows:

- A list of all previously opened workspaces, sorted by last-opened time
- The currently active workspace (highlighted with a "current" badge)
- An option to create a new workspace

Click any workspace in the list to switch to it. Muxit will restart automatically with the selected workspace.

## Renaming a Workspace

The default name of a workspace is the folder name — so if your workspace lives in `~/workspace/` you'd see "Workspace: workspace" in the titlebar, which isn't very informative. From the **Workspace** menu, select **Rename Workspace…** to give it a clearer label (e.g. "Optics Lab", "Robot Cell 3"). The rename only touches the catalog (`workspaces.json`); your folder on disk keeps its original name.

## Switching Workspaces

When you switch workspaces, the server performs a graceful restart:

1. All running scripts and agents are stopped
2. All connector connections are closed
3. The server shuts down
4. The launcher (or the server itself, when it was started directly) restarts
   the server with the new workspace path

This process takes a few seconds — longer on a first start when drivers are
scanned. The page shows *Waiting for the server to restart…* and polls until
the new server answers **for the target workspace**, then reloads in place —
the restarted server never opens a second browser tab. A server that is up but
still booting is not good enough: the page keeps polling rather than reloading
onto a half-started server. If the new
workspace is configured for a different port or HTTPS setting the page waits
for that origin instead and then redirects to it. Should the restart take more
than two minutes the page reloads anyway; if the server has still not come
back at that point, check the startup log (**Restart Server…** / the console)
for the reason.

## Managing the Workspace List

- Workspaces are automatically added to the list when you create or open them
- Click the **X** button on any workspace entry to remove it from the list (this does **not** delete the workspace folder)
- A workspace whose folder has been **deleted** is removed from the list automatically, at startup and whenever a
  list is shown (the startup picker, **Switch to** and **Open Workspace…**). Muxit treats a folder as deleted when the
  folder it lived in is still there but the workspace folder is not
- A workspace on something that is **not connected** right now — a USB drive, a network share, a drive letter that is
  not mapped — stays in the list, dimmed with a "missing" badge, and works again once the drive is back. Remove it
  with **X** if it is gone for good

When only one workspace is left in the list, Muxit opens it at startup without asking; the picker appears when there
are two or more.

## EULA Acknowledgement & Sandbox Mode

Every Muxit workspace must have an accepted workspace acknowledgement before
the server will let any driver perform a hardware **write** (setting a
property, calling an action, or running a script). Until the acknowledgement
is accepted the workspace loads in **Sandbox mode**: reads and polling
continue, but every write is refused with error code `EULA_NOT_ACCEPTED`.

### What gets stored

Acceptance produces two files inside the workspace:

```
my-workspace/
  .muxit/
    EULA-ACCEPTED.md     # Human-readable acknowledgement + signed footer
    eula-history.jsonl   # Append-only audit trail of accept events
    workspace.json       # Stable workspace ID used in the footer
```

The accepted file is a full copy of the current canonical EULA followed by a
footer that identifies *who* accepted *which* version, *when*, for *which*
workspace, and the SHA256 hash of the canonical body text.

### Accepting via the UI

When the server reports Sandbox mode the web UI replaces the main view with a
blocking modal that shows the EULA text, asks for an identifier (name or
email), and requires a checkbox before the **Accept** button is enabled. On
accept the server writes `.muxit/EULA-ACCEPTED.md` atomically, appends a
history entry, and unlocks the workspace.

### Accepting from the command line

Headless installs (`--cli` / `--mcp` modes, CI pipelines) accept the EULA one
of two ways:

```bash
# Explicit subcommand — writes the acceptance file and exits
muxit eula accept --user "Jane Doe" --workspace /path/to/workspace
muxit eula status --workspace /path/to/workspace
muxit eula show                # prints the canonical text

# Or set environment variables before launching the server
MUXIT_EULA_ACCEPT=1 MUXIT_EULA_USER="ci-bot" muxit --workspace /path/to/workspace
```

The env-var flow is logged with `action: "accepted_ci"` in the history file
so CI-initiated acceptances are distinguishable from human ones.

### When re-acceptance is required

The server treats EULA versions as semver (`1.0.0`, `1.1.0`, `2.0.0`):

- **Patch bump** (`1.0.0` → `1.0.1`) — formatting / typo fix only, prior
  acceptance remains valid.
- **Minor / major bump** — requires re-acceptance; the modal shows the new
  version and notes the previous accepted version in the history.

Re-acceptance is also required if the accepted file is edited outside Muxit
(hash mismatch → `EulaTampered`) or if only the footer is present
(`EulaCorrupt`).

### Shared workspaces (Git)

The `.muxit/` folder commits with the workspace, so a team-shared Git
repository carries the accepted EULA with it. The hash check still runs per
user so any tampering is detected.

## Workspace Catalog

Muxit stores the list of known workspaces in a catalog file outside any workspace: `workspaces.json` in the per-user data directory — `%LOCALAPPDATA%\Muxit\` on Windows, `~/.muxit/` on macOS and Linux, or wherever `MUXIT_DATA_DIR` points. This file persists across workspace switches and server restarts; entries for deleted folders are dropped from it as described under [Managing the Workspace List](#managing-the-workspace-list).

## Command-Line Usage

You can also specify a workspace directly when starting the server:

```bash
node start.js server --workspace=/path/to/my-workspace
```

Or with the compiled binary:

```bash
muxit --workspace=/path/to/my-workspace
```

The specified workspace is automatically registered in the catalog.
