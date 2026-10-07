---
title: JavaScript Client Library
description: Connect your own JavaScript applications to Muxit via WebSocket.
---

# JavaScript Client Library

The `muxit-client` library lets you connect any JavaScript application — browser or Node.js — to MuxitServer via WebSocket. It mirrors the [script sandbox API](https://docs.muxit.io/guides/scripts.md), so the same patterns you use in Muxit scripts work from your own code.

Zero dependencies. Single ES module. Drop it in and go.

## Installation

Copy `lib/muxit-client/muxit-client.js` from the Muxit repository into your project.

```javascript
// Browser
import { Muxit } from './muxit-client.js'

// Node.js 22+
import { Muxit } from './muxit-client.js'

// Node.js < 22
import WebSocket from 'ws'        // npm install ws
globalThis.WebSocket = WebSocket
import { Muxit } from './muxit-client.js'
```

## Connect

```javascript
import { Muxit } from './muxit-client.js'

const muxit = new Muxit()
await muxit.connect('ws://127.0.0.1:8765/ws')
```

For remote connections, pass an auth token:

```javascript
await muxit.connect('ws://server:8765/ws', { token: 'your-auth-token' })
```

The library auto-reconnects on disconnect with exponential backoff. Disable with `{ reconnect: false }`.

## Control Devices

The `connector()` method returns a proxy that works exactly like the script sandbox — every property access returns an async function:

```javascript
const psu = muxit.connector('psu')

// Read a property
const voltage = await psu.voltage()

// Set a property
await psu.voltage(12)

// Call an action
await psu.output(true)

// Multi-arg actions
const robot = muxit.connector('robot')
await robot.moveAbsolute([100, 200, 50])
```

## Reactive State Updates

MuxitServer pushes device state changes every 50ms. Subscribe with events:

```javascript
// All connectors
muxit.on('state', (updates) => {
  // { "psu": { "voltage": 12.1 }, "robot": { "position": [100, 200, 50] } }
})

// Single connector
muxit.on('state:psu', (props) => {
  document.getElementById('voltage').textContent = props.voltage
})
```

## Image Streams

Subscribe to camera feeds and other data streams. Image data arrives as `StreamFrame` objects that are ready for Canvas 2D or WebGL:

```javascript
muxit.subscribeStream('camera', 'feed')

muxit.on('stream:camera:feed', async (frame) => {
  // Option 1: Display in an <img> tag
  document.getElementById('preview').src = frame.dataUrl

  // Option 2: Draw on Canvas 2D
  const bmp = await frame.imageBitmap()
  ctx.drawImage(bmp, 0, 0)

  // Option 3: Use as WebGL texture
  const bmp = await frame.imageBitmap()
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, bmp)

  // Option 4: Raw bytes for custom processing
  const buf = await frame.arrayBuffer()
})

// Unsubscribe when done
muxit.unsubscribeStream('camera', 'feed')
```

### StreamFrame Properties

| Property / Method | Returns | Environment |
|-------------------|---------|-------------|
| `frame.base64` | `string` | Universal |
| `frame.dataUrl` | `string` | Universal |
| `frame.arrayBuffer()` | `Promise<ArrayBuffer>` | Universal |
| `frame.blob()` | `Promise<Blob>` | Browser only |
| `frame.imageBitmap()` | `Promise<ImageBitmap>` | Browser only |

## AI Integration

Call the AI assistant with a one-shot prompt:

```javascript
const answer = await muxit.ai('What is the current voltage on the PSU?')
console.log(answer)

// With an image
const description = await muxit.ai('Describe what the camera sees', base64Image)
```

## Script Management

Start and stop server-side scripts:

```javascript
await muxit.scripts.start('monitor.js')

const running = await muxit.scripts.list()
console.log(running)

await muxit.scripts.stop('monitor.js')
```

## Server Info

Query the server for available connectors, schemas, and drivers:

```javascript
const names = await muxit.connectors()       // ['psu', 'robot', 'camera']
const schema = await muxit.schema('psu')     // properties, actions, streams
const drivers = await muxit.drivers()         // all available drivers
```

## Events

The library emits events for all server broadcasts:

```javascript
muxit.on('connect', () => console.log('Connected'))
muxit.on('disconnect', ({ code, reason }) => console.log('Lost connection'))
muxit.on('server:log', (entry) => console.log('[server]', entry.message))
muxit.on('script:say', (msg) => console.log('[script]', msg.text))
muxit.on('error', (err) => console.error(err.code, err.message))
```

Every `on()` call returns an unsubscribe function:

```javascript
const unsub = muxit.on('state:psu', handler)
// Later...
unsub()
```

## Logging

Local logging helpers that emit `'log'` events:

```javascript
muxit.on('log', ({ level, message, timestamp }) => {
  console.log(`[${level}] ${message}`)
})

muxit.log.info('System ready')
muxit.log.warn('Voltage dropping')
muxit.log.error('Connection lost to instrument')
```

## Utilities

```javascript
await muxit.delay(2000)         // sleep 2 seconds
console.log(muxit.timestamp())  // "2024-01-15T10:30:00.000Z"
```

## Low-Level Access

For message types not covered by the high-level API, use `request()` directly:

```javascript
// Any WebSocket message type
const config = await muxit.request({ type: 'config.get' })
const logs = await muxit.request({ type: 'server.logs.history' })

// Fire-and-forget
muxit.send({ type: 'some.message', data: 'value' })
```

See the [WebSocket API Reference](https://docs.muxit.io/reference/websocket-api.md) for all available message types.

## Full Example: Live Dashboard

Here's a complete example that reads a power supply, displays a camera feed, and updates a dashboard:

```html
<!DOCTYPE html>
<html>
<head>
  <title>Muxit Dashboard</title>
  <style>
    body { font-family: sans-serif; background: #1a1a1a; color: #eee; }
    #stats { display: flex; gap: 2rem; margin: 1rem; }
    .stat { font-size: 2rem; }
    .label { font-size: 0.8rem; color: #888; }
    canvas { border: 1px solid #333; margin: 1rem; }
  </style>
</head>
<body>
  <div id="stats">
    <div>
      <div class="label">Voltage</div>
      <div class="stat" id="voltage">--</div>
    </div>
    <div>
      <div class="label">Current</div>
      <div class="stat" id="current">--</div>
    </div>
  </div>
  <canvas id="camera" width="640" height="480"></canvas>

  <script type="module">
    import { Muxit } from './muxit-client.js'

    const muxit = new Muxit()
    await muxit.connect('ws://127.0.0.1:8765/ws')

    // Update stats from reactive state
    muxit.on('state:psu', (props) => {
      if (props.voltage !== undefined)
        document.getElementById('voltage').textContent = props.voltage.toFixed(2) + ' V'
      if (props.current !== undefined)
        document.getElementById('current').textContent = props.current.toFixed(3) + ' A'
    })

    // Draw camera feed on canvas
    const ctx = document.getElementById('camera').getContext('2d')
    muxit.subscribeStream('camera', 'feed')
    muxit.on('stream:camera:feed', async (frame) => {
      const bmp = await frame.imageBitmap()
      ctx.drawImage(bmp, 0, 0, 640, 480)
      bmp.close()
    })

    // Set PSU to 5V on startup
    const psu = muxit.connector('psu')
    await psu.voltage(5)
    await psu.output(true)
  </script>
</body>
</html>
```

## Comparison with Script Sandbox

If you've used Muxit scripts, the client library will feel familiar:

| Script Sandbox | muxit-client | Notes |
|---------------|-------------|-------|
| `connector('psu').voltage()` | `muxit.connector('psu').voltage()` | Same proxy pattern |
| `log.info(msg)` | `muxit.log.info(msg)` | Local events only |
| `emit(event, data)` | `muxit.emit(event, data)` | Client-side only |
| `on(event, fn)` | `muxit.on(event, fn)` | Receives server broadcasts |
| `delay(ms)` | `muxit.delay(ms)` | Same |
| `timestamp()` | `muxit.timestamp()` | Same |
| `ai(prompt, img)` | `muxit.ai(prompt, img)` | Same |
| `say(text)` | `muxit.say(text)` | Same |
| `stream(c, s, d)` | `muxit.subscribeStream(c, s)` | Subscribe to receive, not emit |

The main difference: scripts run **inside** the server with direct driver access, while the client library communicates over WebSocket. Both use the same underlying protocol.
