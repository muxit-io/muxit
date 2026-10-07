---
title: MQTT & IoT
description: Connect IoT devices to Muxit via MQTT — ESP32, Arduino, Home Assistant, Node-RED, and Tasmota.
---

# MQTT & IoT Guide

Muxit's built-in **MqttBridge** driver lets you connect IoT devices that communicate over MQTT — ESP32, Arduino, Tasmota smart plugs, Home Assistant, Node-RED, and anything else that speaks MQTT.

## What Is MQTT?

MQTT is a lightweight messaging protocol used by IoT devices. Devices **publish** messages to **topics** (like `sensors/temperature`), and other devices **subscribe** to those topics to receive the messages. A central **broker** (like Mosquitto) routes messages between publishers and subscribers.

```
ESP32 sensor  ──publish──►  MQTT Broker  ◄──subscribe──  Muxit
  (temperature)                │                          (reads values)
                               │
Smart plug    ◄──subscribe──   │  ──publish──►  Muxit
  (turns on/off)                                (sends commands)
```

Muxit acts as both a subscriber (reading sensor data) and a publisher (sending commands to devices).

---

## Quick Start — Built-in Broker (Zero Setup)

The fastest way to get started — Muxit includes an embedded MQTT broker so you don't need to install anything.

### 1. Enable the Built-in Broker

**Option A — Settings page (recommended):** Open **Settings → MQTT Broker** in the GUI. Toggle **Enable MQTT Broker** on, set the port (default 1883), and optionally configure authentication and max clients. The status section shows whether the broker is running and lists connected clients.

**Option B — server.json:** Add this to your `workspace/config/server.json`:

```json
{
  "mqttBroker": {
    "enabled": true,
    "port": 1883
  }
}
```

Restart the server. You'll see `MQTT broker started on port 1883` in the server log.

### 2. Create a Connector

Create `workspace/connectors/mqtt.js`:

```javascript
export default {
  driver: "MqttBridge",
  config: {
    host: "builtin",          // Connects to Muxit's built-in broker
    autoConnect: true,        // Connect automatically on startup
    topics: ["lab/#"],        // Auto-subscribe on connect
    topicMap: {
      "lab/sensors/temperature": "temperature",
      "lab/sensors/humidity": "humidity",
    },
  },
  poll: ["connected", "messageCount", "temperature", "humidity"],

  ai: {
    instructions: "MQTT bridge for IoT sensors. Reading is safe. Confirm before publishing.",
  },
};
```

That's it — no boilerplate methods needed. The `topicMap` creates named properties (`temperature`, `humidity`) that are available in scripts, dashboards, and AI. The `autoConnect` option connects to the broker automatically when the connector starts.

### 3. Try It

Enable the connector in the Hardware panel, then run this script:

```javascript
const mqtt = connector("mqtt");
log.info(`Connected: ${mqtt.connected()}`);

// Publish and read back
mqtt.publish({ topic: "lab/sensors/temperature", payload: "22.5" });
delay(500);
const temp = mqtt.temperature();
log.info(`Temperature: ${temp}`);
```

### 4. Connect External Devices

Point your ESP32, Tasmota, or Node-RED at `<muxit-ip>:1883` — they'll connect to the built-in broker.

```cpp
// Arduino/ESP32 example
client.setServer("192.168.1.50", 1883);  // Muxit's IP and broker port
```

### When to Use an External Broker

The built-in broker is great for lab setups. For production environments or Home Assistant integration, you may prefer a dedicated broker like Mosquitto — the MqttBridge driver works with any broker.

---

## Quick Start — External Broker

If you prefer using an existing broker (Mosquitto, Home Assistant, etc.):

### 1. Set Up a Broker

You need an MQTT broker running on your network. If you don't have one, download [Mosquitto](https://mosquitto.org/download/) and run the Windows installer.

**Already have Home Assistant?** It includes an MQTT broker — enable it in Settings > Add-ons > Mosquitto broker.

### 2. Create the MQTT Connector

Create `workspace/connectors/mqtt.js`:

```javascript
export default {
  driver: "MqttBridge",
  config: {
    host: "192.168.1.50",     // Your broker's IP address
    port: 1883,
    autoConnect: true,
    topics: ["sensors/#"],    // Subscribe to all sensor topics on connect
    topicMap: {
      "sensors/temperature": "temperature",
      "sensors/humidity": "humidity",
    },
  },
  poll: ["connected", "messageCount", "temperature", "humidity"],
};
```

### 3. Enable and Verify

1. Restart the Muxit server (or reload connectors in the Hardware panel)
2. Enable the `mqtt` connector in the Hardware panel
3. With `autoConnect: true`, it connects automatically — no manual step needed

After connecting, the Hardware panel shows:
- `connected: true`
- `messageCount` incrementing as messages arrive
- `temperature` and `humidity` updating from your sensors

::: tip Manual Connect
If you omit `autoConnect` (or set it to `false`), you need to call `connect` manually from a script or AI chat:
```javascript
const mqtt = connector("mqtt");
mqtt.connect();
```
:::

---

## Subscribing to Topics

### In the Connector Config

Use the `topics` config option to auto-subscribe when connecting:

```javascript
config: {
  host: "192.168.1.50",
  topics: ["sensors/#", "home/+/state"],
},
```

### From a Script

```javascript
const mqtt = connector("mqtt");
mqtt.connect();

// Subscribe to specific topics — string shorthand works
mqtt.subscribe("sensors/temperature");
mqtt.subscribe("sensors/humidity");

// Wildcards work too
mqtt.subscribe("home/#");          // all topics under home/
mqtt.subscribe("sensors/+/value"); // single-level wildcard
```

### Unsubscribing

```javascript
const mqtt = connector("mqtt");
mqtt.unsubscribe("sensors/temperature");
mqtt.unsubscribe("home/#");
```

### MQTT Wildcards

| Wildcard | Matches | Example |
|----------|---------|---------|
| `#` | All subtopics (multi-level) | `sensors/#` matches `sensors/temp`, `sensors/room1/temp` |
| `+` | One level | `sensors/+/value` matches `sensors/temp/value` but not `sensors/room1/temp/value` |

---

## Reading Sensor Data

### Topic Map Properties (Recommended)

The simplest way — use `topicMap` in your config to create named properties:

```javascript
config: {
  topicMap: {
    "sensors/temperature": "temperature",
    "sensors/humidity": "humidity",
  },
},
poll: ["temperature", "humidity"],
```

Then in scripts:
```javascript
const mqtt = connector("mqtt");
const temp = mqtt.temperature();
const hum = mqtt.humidity();
log.info(`Temp: ${temp}°C, Humidity: ${hum}%`);
```

Values are automatically parsed: numeric payloads return as numbers, `true`/`false` as booleans, everything else as strings. If a topic hasn't received any messages, `null` is returned.

### Get Any Topic Value

Read any topic on-demand using `get` with a string shorthand:

```javascript
const mqtt = connector("mqtt");
const temp = mqtt.get("sensors/temperature");
log.info(`Temperature: ${temp}`);  // temp is a number if the payload was numeric
```

### Computed Properties (Advanced)

For more control, you can still define computed properties in the connector:

```javascript
properties: {
  temperature: {
    get: () => driver.get({ topic: "sensors/temperature" }),
    description: "Temperature from MQTT sensor",
    poll: true,
  },
},
```

### Monitor in Real-Time

```javascript
const mqtt = connector("mqtt");

while (true) {
  const temp = mqtt.temperature();
  const humidity = mqtt.humidity();

  log.info(`Temp: ${temp}°C, Humidity: ${humidity}%`);

  if (temp > 30) {
    log.warn("Temperature too high!");
    mqtt.publish({
      topic: "alerts/temperature",
      payload: JSON.stringify({ temp, timestamp: timestamp() }),
    });
  }

  delay(5000);
}
```

---

## Publishing Messages

Send commands to MQTT devices:

```javascript
const mqtt = connector("mqtt");

// Simple payload
mqtt.publish({ topic: "home/light/set", payload: "ON" });

// JSON payload
mqtt.publish({
  topic: "home/thermostat/set",
  payload: JSON.stringify({ temperature: 22, mode: "heat" }),
});

// With QoS and retain flag
mqtt.publish({
  topic: "config/device1",
  payload: "reset",
  qos: 1,
  retain: true,
});
```

---

## Displaying MQTT Data on Dashboards

### Bind Topic Map Properties to Widgets

If your connector uses `topicMap`, bind the mapped properties to dashboard widgets:

```json
{
  "type": "gauge",
  "config": {
    "label": "Temperature",
    "connector": "mqtt",
    "property": "temperature",
    "min": -10,
    "max": 50,
    "unit": "°C"
  }
}
```

### Monitor the Message Stream

Use a terminal widget to see all MQTT messages in real-time:

```json
{
  "type": "terminal",
  "config": {
    "label": "MQTT Messages",
    "stream": "mqtt:message",
    "maxLines": 200,
    "fontSize": "small"
  }
}
```

### Build a Complete Sensor Dashboard

Combine gauges, charts, and indicators:

```json
{
  "name": "IoT Sensors",
  "widgets": [
    {
      "id": "w1", "type": "gauge",
      "layout": { "x": 0, "y": 0, "w": 4, "h": 4 },
      "config": {
        "label": "Temperature",
        "connector": "mqtt",
        "property": "temperature",
        "min": -10, "max": 50, "unit": "°C"
      }
    },
    {
      "id": "w2", "type": "gauge",
      "layout": { "x": 4, "y": 0, "w": 4, "h": 4 },
      "config": {
        "label": "Humidity",
        "connector": "mqtt",
        "property": "humidity",
        "min": 0, "max": 100, "unit": "%"
      }
    },
    {
      "id": "w3", "type": "indicator",
      "layout": { "x": 8, "y": 0, "w": 4, "h": 2 },
      "config": {
        "label": "Broker Connected",
        "connector": "mqtt",
        "property": "connected"
      }
    },
    {
      "id": "w4", "type": "chart",
      "layout": { "x": 0, "y": 4, "w": 12, "h": 4 },
      "config": {
        "label": "Sensor History",
        "bindings": ["mqtt.temperature", "mqtt.humidity"],
        "duration": 60, "yMin": 0, "yMax": 100
      }
    }
  ]
}
```

---

## Examples

### ESP32 Temperature Sensor

A typical ESP32 running Arduino or ESPHome publishes sensor readings like:

```
Topic: sensors/temperature    Payload: 23.5
Topic: sensors/humidity       Payload: 67
```

**Connector config:**

```javascript
export default {
  driver: "MqttBridge",
  config: {
    host: "192.168.1.50",
    autoConnect: true,
    topics: ["sensors/#"],
    topicMap: {
      "sensors/temperature": "temperature",
      "sensors/humidity": "humidity",
    },
  },
  poll: ["connected", "messageCount", "temperature", "humidity"],
};
```

**Script to monitor:**

```javascript
const mqtt = connector("mqtt");
log.info("MQTT connected — listening for sensor data");

while (true) {
  const temp = mqtt.temperature();
  const hum = mqtt.humidity();
  if (temp !== null) log.info(`Temp: ${temp}°C, Humidity: ${hum}%`);
  delay(5000);
}
```

### Tasmota Smart Plug

Tasmota devices use topics like `cmnd/plug/POWER` and `stat/plug/POWER`:

```javascript
const mqtt = connector("mqtt");

// Turn ON
mqtt.publish({ topic: "cmnd/plug/POWER", payload: "ON" });

// Turn OFF
mqtt.publish({ topic: "cmnd/plug/POWER", payload: "OFF" });

// Read current state
mqtt.subscribe("stat/plug/POWER");
delay(1000);
const state = mqtt.get("stat/plug/POWER");
log.info(`Plug is: ${state}`);
```

### Home Assistant Integration

If Home Assistant is running with the Mosquitto add-on:

1. Set `host` to your Home Assistant IP
2. Use the username/password from the Mosquitto add-on config
3. Subscribe to Home Assistant topics like `homeassistant/sensor/+/state`

```javascript
export default {
  driver: "MqttBridge",
  config: {
    host: "192.168.1.100",
    port: 1883,
    username: "mqtt_user",
    password: "mqtt_password",
    autoConnect: true,
    topics: ["homeassistant/#"],
  },
  poll: ["connected"],
};
```

### Node-RED Integration

Node-RED can publish data to topics that Muxit subscribes to, and subscribe to topics that Muxit publishes to. Use the same broker for both.

**Node-RED flow:** Sensor node → MQTT out (`sensors/data`) → Muxit reads it

**Muxit → Node-RED:** Muxit publishes to `muxit/commands` → MQTT in → Node-RED processes it

---

## Broker Authentication

If your broker requires authentication:

```javascript
config: {
  host: "192.168.1.50",
  port: 1883,
  username: "muxit",
  password: "your-password",
},
```

For cloud MQTT brokers (HiveMQ, CloudMQTT, etc.), use the provided hostname, port, and credentials.

For the built-in broker, configure authentication in **Settings → MQTT Broker** (username and password fields) or in `server.json`:

```json
{
  "mqttBroker": {
    "enabled": true,
    "username": "muxit",
    "password": "your-password"
  }
}
```

---

## Troubleshooting

**"Not connected" error** — Either set `autoConnect: true` in the config, or call the `connect` action manually. The driver does not auto-connect by default.

**No messages arriving** — Check that:
1. Your broker is running (check **Settings → MQTT Broker** status, or the `mosquitto` process)
2. The `host` IP is correct (try `ping <ip>`)
3. You've subscribed to the right topics (check wildcards)
4. Your IoT device is publishing (test with `mosquitto_sub -t "sensors/#"`)

**Connection refused** — The broker may require authentication. Add `username` and `password` to the config.

**Messages arrive but properties show null** — Make sure your `topicMap` keys (or computed property topics) use the exact topic string that messages are published to. Topic matching is case-sensitive.

**High latency** — Reduce the polling interval or adjust QoS. QoS 0 is fastest (no acknowledgment), QoS 1 guarantees delivery at least once.

---

## Full Driver Reference

See the [MqttBridge driver reference](https://docs.muxit.io/reference/drivers/mqtt-bridge.md) for the complete list of properties, actions, streams, and config options.
