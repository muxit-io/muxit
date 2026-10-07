---
title: "Your First Script"
description: Step-by-step walkthrough of writing your first Muxit automation script.
---

# Your First Script

This walkthrough guides you through writing a simple automation script that reads a device, logs data, and reacts to changes.

## Prerequisites

- Muxit server running (`node start.js server`)
- At least one connector configured (the built-in **TestDevice** works perfectly)

## Step 1: Create the Script File

In the Explorer sidebar, click **New Script** or create `workspace/scripts/hello.js` manually.

```javascript
log.info("Hello from Muxit!");
```

Click **Run** in the editor toolbar. You should see the message in the Output panel.

## Step 2: Read a Device Property

The TestDevice connector is always available. Let's read from it:

```javascript
const test = connector("test-device");

const voltage = test.voltage;
log.info(`Voltage: ${voltage}V`);
```

`connector("name")` returns a proxy object. Access properties directly (no parentheses). Use function calls for actions.

## Step 3: Write to a Device

Use assignment syntax to set a property:

```javascript
const test = connector("test-device");

test.voltage = 12;
log.info(`Set voltage to 12V`);

const readback = test.voltage;
log.info(`Readback: ${readback}V`);
```

## Step 4: Add a Loop

Most useful scripts run continuously. Write an endless loop — pressing **Stop** ends the script wherever it is:

```javascript
const test = connector("test-device");

while (true) {
  const v = test.voltage;
  const i = test.current;
  log.info(`V=${v}V, I=${i}A, P=${(v * i).toFixed(3)}W`);
  delay(1000);
}
```

Click **Stop** in the editor toolbar to end the loop. Stop is a hard-kill — it interrupts V8 mid-instruction, so any code you write *after* the loop (including `finally` blocks) is not guaranteed to run. Put setup above the loop and keep each iteration safe to abort.

## Step 5: Emit Events

Other scripts and dashboard widgets can react to events you emit:

```javascript
const test = connector("test-device");

while (true) {
  const v = test.voltage;
  const i = test.current;

  emit("reading", { voltage: v, current: i, power: v * i });
  log.info(`Emitted reading: V=${v}, I=${i}`);

  delay(1000);
}
```

## Step 6: Push Data to a Dashboard

Create a [Virtual](https://docs.muxit.io/reference/drivers/virtual.md) store connector — an in-memory connector with no hardware — to bridge your script to dashboard widgets. First, create `workspace/connectors/my-store.js` (no `driver:` line needed):

```javascript
let power = 0;
let status = "Idle";

export default {
  properties: {
    power:  { get: () => power,  set: (v) => { power = Number(v); },  description: "Power (W)", poll: true },
    status: { get: () => status, set: (v) => { status = String(v); }, description: "Status text", poll: true },
  },
};
```

Then update your script to write to the store:

```javascript
const test = connector("test-device");
const store = connector("my-store");

store.status = "Running";

while (true) {
  const v = test.voltage;
  const i = test.current;
  store.power = v * i;
  delay(1000);
}
```

(Don't try to set `store.status = "Stopped"` after the loop — Stop is a hard-kill and that line won't run. If you need an idle indicator, reset it when a script starts.)

Create a dashboard with a gauge widget bound to `my-store.power` to see it update live.

## Step 7: Add Error Handling

Wrap device calls in try/catch for robustness:

```javascript
const test = connector("test-device");

while (true) {
  try {
    const v = test.voltage;
    log.info(`Voltage: ${v}V`);
  } catch (err) {
    log.error(`Failed to read: ${err.message}`);
  }
  delay(1000);
}
```

## Complete Example

Here's a polished version combining everything:

```javascript
const test = connector("test-device");

// Setup — put the device in a safe state up front, since Stop won't let
// you clean up after the loop.
log.info("Starting voltage monitor");
test.voltage = 5;

// Main loop — Stop terminates mid-iteration.
while (true) {
  try {
    const v = test.measured_voltage;
    const i = test.measured_current;
    const power = v * i;

    log.info(`V=${v.toFixed(2)}V  I=${i.toFixed(3)}A  P=${power.toFixed(3)}W`);
    emit("reading", { voltage: v, current: i, power });

    if (power > 50) {
      log.warn("Power exceeding 50W!");
    }
  } catch (err) {
    log.error(`Read error: ${err.message}`);
  }

  delay(500);
}
```

## Next Steps

- See the full [Script API Reference](https://docs.muxit.io/reference/script-api.md) for all available globals
- Learn about [cross-script communication](https://docs.muxit.io/guides/scripts.md#cross-script-communication) with `emit()` and `on()`
- Build a [dashboard](https://docs.muxit.io/guides/dashboards.md) to visualize your script's output
