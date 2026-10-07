---
title: "Your First Connector"
description: Step-by-step walkthrough of creating a connector config for a hardware device.
---

# Your First Connector

This walkthrough guides you through creating a connector configuration that wraps a hardware driver with custom methods and computed properties.

## Prerequisites

- Muxit server running (`node start.js server`)
- A driver available (we'll use the built-in **TestDevice** driver, no hardware needed)

## Step 1: Create the Config File

Create `workspace/connectors/my-device.js`:

```javascript
export default {
  driver: "TestDevice",
  config: {},
};
```

That's a valid connector. Restart the server (or use hot-reload) and you'll see "my-device" in the Connector Browser.

The filename (`my-device.js`) becomes the connector name — use it with `connector("my-device")` in scripts.

## Step 2: Add Configuration

Pass settings to the driver via `config`:

```javascript
export default {
  driver: "TestDevice",
  config: {
    defaultVoltage: 5,
    defaultCurrent: 1.0,
  },
};
```

What goes in `config` depends on the driver. Check the driver documentation for supported keys.

## Step 3: Add Custom Methods

Custom methods compose multiple driver calls into higher-level operations. Inside each method, the driver is in scope as the closure variable `driver`. Function signatures mirror the script-side call exactly — `dev.rampTo(5)` ↔ `(target) => …`:

```javascript
export default {
  driver: "TestDevice",
  config: {
    defaultVoltage: 5,
    defaultCurrent: 1.0,
  },

  methods: {
    // Shorthand: bare function
    on: () => { driver.output = true; },

    // Shorthand: [function, description] tuple
    off: [() => { driver.output = false; }, "Turn output OFF"],

    // Full form: object with fn and description
    rampTo: {
      fn: async (target) => {
        const current = driver.voltage;
        const step = (target - current) / 10;
        for (let i = 1; i <= 10; i++) {
          driver.voltage = current + step * i;
          await delay(50);
        }
        return driver.voltage;
      },
      description: "Ramp voltage to target in 10 steps",
    },
  },
};
```

The `driver` closure variable is a Proxy:
- `driver.voltage` → reads the "voltage" property
- `driver.voltage = 12` → writes the "voltage" property
- `driver.reset()` → executes the "reset" action

## Step 4: Add Computed Properties

Computed properties derive values from driver properties:

```javascript
export default {
  driver: "TestDevice",
  config: { defaultVoltage: 5, defaultCurrent: 1.0 },

  methods: {
    on: () => { driver.output = true; },
    off: [() => { driver.output = false; }, "Turn output OFF"],
    rampTo: {
      fn: async (target) => {
        const current = driver.voltage;
        const step = (target - current) / 10;
        for (let i = 1; i <= 10; i++) {
          driver.voltage = current + step * i;
          await delay(50);
        }
        return driver.voltage;
      },
      description: "Ramp voltage to target in 10 steps",
    },
  },

  properties: {
    power: {
      get: () => {
        const v = driver.measured_voltage;
        const i = driver.measured_current;
        return Math.round(v * i * 1000) / 1000;
      },
      description: "Calculated power (W)",
    },
  },
};
```

## Step 5: Enable Polling

Make properties update automatically by adding `poll`:

```javascript
export default {
  driver: "TestDevice",
  config: { defaultVoltage: 5, defaultCurrent: 1.0 },
  poll: ["power", "measured_voltage", "measured_current"],

  methods: {
    on: () => { driver.output = true; },
    off: [() => { driver.output = false; }, "Turn output OFF"],
    rampTo: {
      fn: async (target) => {
        const current = driver.voltage;
        const step = (target - current) / 10;
        for (let i = 1; i <= 10; i++) {
          driver.voltage = current + step * i;
          await delay(50);
        }
        return driver.voltage;
      },
      description: "Ramp voltage to target in 10 steps",
    },
  },

  properties: {
    power: {
      get: () => {
        const v = driver.measured_voltage;
        const i = driver.measured_current;
        return Math.round(v * i * 1000) / 1000;
      },
      description: "Calculated power (W)",
    },
  },
};
```

The `poll` array lists property names that should be read automatically (default every 200ms). Changed values are pushed to dashboard widgets via WebSocket.

## Step 6: Use It in a Script

```javascript
const dev = connector("my-device");

dev.on();
dev.rampTo(12);

const power = dev.power;
log.info(`Power: ${power}W`);

dev.off();
```

## Step 7: Connect Real Hardware

For real devices, use the built-in [`Scpi` protocol](https://docs.muxit.io/reference/drivers/scpi.md) with a declarative schema — each instrument property/method is described once, and the protocol handles the `{cmd: "VOLT?"} → parseFloat` and `VOLT {value}` boilerplate. Here's a serial PSU example:

```javascript
export default {
  protocol: "Scpi",
  connection: { type: "serial", port: "COM3", baudRate: 9600 },
  config: {
    terminator: "\n",
    timeoutMs: 3000,
    autoConnect: true,

    // Declarative schema — the Scpi protocol synthesizes get/set/dispatch for
    // each entry. Trailing "?" on cmd marks the entry as read-only.
    schema: {
      properties: {
        voltage:          { cmd: "VOLT",       type: "float", unit: "V" },
        current:          { cmd: "CURR",       type: "float", unit: "A" },
        output:           { cmd: "OUTP",       type: "bool" },
        measured_voltage: { cmd: "MEAS:VOLT?", type: "float", unit: "V" },
        measured_current: { cmd: "MEAS:CURR?", type: "float", unit: "A" },
      },
    },
  },
  poll: ["measured_voltage", "measured_current"],

  methods: {
    on:  [() => { driver.output = true;  }, "Turn output ON"],
    off: [() => { driver.output = false; }, "Turn output OFF"],
  },

  properties: {
    // Computed property — pure JS on top of declared measurements.
    power: {
      get: () => {
        const v = driver.measured_voltage;
        const i = driver.measured_current;
        return Math.round(v * i * 1000) / 1000;
      },
      description: "Calculated power (W)",
    },
  },
};
```

Common commands like `*RST`, `*IDN?`, and `SYST:ERR?` are already exposed as driver actions (`driver.reset()`, `driver.identify()`, `driver.readErrors()`) — no need to redeclare them. For instruments with vendor-specific quirks (odd response formats, multi-step commands), hand-write just those entries in the top-level `properties`/`methods` blocks; they override the declared schema of the same name. See the [Scpi protocol reference](https://docs.muxit.io/reference/drivers/scpi.md#declarative-schema) for the full list of declarative fields.

## Connector Config Cheat Sheet

```javascript
export default {
  driver: "DriverName",         // Required — which driver to use
  config: { /* ... */ },        // Optional — passed to driver.init()
  poll: ["prop1", "prop2"],     // Optional — auto-poll these properties

  methods: {
    name: fn,                   // Bare function
    name: [fn, "description"],  // Tuple
    name: { fn, description },  // Full form
  },

  properties: {
    name: fn,                                    // Bare getter
    name: [fn, "description", { poll: true }],   // Tuple with options
    name: { get: fn, set: fn, poll, description }, // Full form
  },
};
```

Inside every `fn`, `get`, and `set`, the driver is available as the closure variable `driver`. Function signatures match the script-side call exactly — no leading proxy parameter.

## Next Steps

- See the full [Connector Guide](https://docs.muxit.io/guides/connectors.md) for transports, virtual stores, and real hardware examples
- Learn about [dashboard widgets](https://docs.muxit.io/guides/dashboards.md) that bind to connector properties
- Build a custom [driver](https://docs.muxit.io/reference/driver-sdk.md) for your specific hardware
