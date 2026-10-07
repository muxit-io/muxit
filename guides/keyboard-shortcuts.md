---
title: Keyboard Shortcuts
description: Editor and layout keyboard shortcuts for the Muxit web UI.
---

# Keyboard Shortcuts

## Editor

| Shortcut | Action |
|----------|--------|
| `Ctrl+S` | Save current file |
| `Ctrl+Z` | Undo |
| `Ctrl+Shift+Z` | Redo |
| `Ctrl+/` | Toggle line comment |
| `Ctrl+D` | Select next occurrence |
| `Ctrl+F` | Find |
| `Ctrl+H` | Find and replace |
| `Ctrl+G` | Go to line |
| `Ctrl+Shift+K` | Delete line |
| `Alt+Up/Down` | Move line up/down |
| `Ctrl+Shift+Up/Down` | Copy line up/down |
| `Tab` | Indent / accept autocomplete |
| `Shift+Tab` | Outdent |

## Layout

| Shortcut | Action |
|----------|--------|
| `Ctrl+B` | Toggle primary sidebar |
| `Ctrl+Shift+B` | Toggle secondary sidebar |
| `Ctrl+J` | Toggle output panel |
| `Alt+Z` | Toggle editor word wrap |
| `Ctrl+,` | Open settings |
| `Ctrl+N` | New file |
| `Ctrl+1`..`Ctrl+9` | Focus editor group by index |

## Script Execution

| Shortcut | Action |
|----------|--------|
| Run button | Execute current script |
| Stop button | Abort running script |

## IntelliSense

The editor provides context-aware IntelliSense for the Muxit API:

### Autocomplete

- Type `connector("` or `device("` to see available connector names
- Type `connector("name").` to see properties and actions for a device
- Type `log.` to see logging methods (`info`, `warn`, `error`, `debug`)
- Type `script.` to see lifecycle properties (`running`, `name`)
- Type `on("` or `emit("` to see known event name patterns
- Type `stream("` to see connector names for streaming
- All sandbox globals (`connector`, `delay`, `emit`, `ai`, `say`, `timestamp`, etc.) appear as top-level suggestions

### Hover Documentation

Hover over any sandbox global (`connector`, `delay`, `ai`, `log`, etc.) to see its signature and description. Hovering over a connector property or action (after `connector("name").`) shows its type, access level, and documentation.

### Signature Help

Type `(` after a function name to see parameter hints. Press `,` to cycle through parameters. Works for all sandbox globals and connector actions with their argument types.

### Context Awareness

IntelliSense adapts based on file location:

- **Script files** (`scripts/*.js`): Full script sandbox API including `ai()`, `say()`, `on()`, `stream()`, `script.*`
- **Connector configs** (`connectors/*.js`): Connector sandbox API including `createTcpTransport()`, `createSerialTransport()`
- **Other `.js` files**: All globals from both contexts
