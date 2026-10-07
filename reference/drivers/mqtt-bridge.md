---
title: MqttBridge Driver
description: Reference for the MqttBridge built-in driver — MQTT broker bridge for IoT devices.
---

# MqttBridge

**MQTT broker bridge** for IoT devices. Connects to any MQTT broker and bridges messages into Muxit as pollable properties and streams. Ideal for ESP32, Arduino, Home Assistant, Node-RED, and Tasmota devices.

For a complete setup guide, see [MQTT & IoT Guide](https://docs.muxit.io/guides/mqtt-iot.md).

## Properties

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `connected` | bool | R | Whether connected to the broker |
| `host` | string | R | Broker hostname |
| `port` | int | R | Broker port |
| `clientId` | string | R | MQTT client ID |
| `messageCount` | int | R | Total messages received |
| `subscriptions` | string[] | R | Active topic subscriptions |
| `topics` | object | R | Map of topic → last received value |
| `lastTopic` | string | R | Last topic that received a message |
| `lastPayload` | string | R | Last payload received |

Additional properties are created automatically from the [`topicMap`](#topic-mapping) config.

## Actions

| Action | Args | Description |
|--------|------|-------------|
| `connect` | — | Connect to the MQTT broker |
| `disconnect` | — | Disconnect from the broker |
| `subscribe` | `topic` or `{ topic, qos? }` | Subscribe to a topic (supports wildcards: `+`, `#`) |
| `unsubscribe` | `topic` or `{ topic }` | Unsubscribe from a topic |
| `publish` | `{ topic, payload, qos?, retain? }` | Publish a message to a topic |
| `get` | `topic` or `{ topic }` | Get the last value received on a topic (auto-parses JSON: numbers return as doubles, booleans as bools, everything else as strings) |

`subscribe`, `unsubscribe`, and `get` accept a plain string (the topic) as a shorthand, so both `c.get("sensors/temp")` and `c.get({ topic: "sensors/temp" })` work.

## Streams

| Stream | Description |
|--------|-------------|
| `message` | Every received MQTT message: `{ topic, payload, qos, retain, timestamp }` |

## Config Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `host` | string | "127.0.0.1" | Broker hostname or IP. Use `"builtin"` to connect to Muxit's embedded MQTT broker |
| `port` | int | 1883 | Broker port |
| `username` | string | — | Authentication username |
| `password` | string | — | Authentication password |
| `clientId` | string | "muxit-{guid}" | MQTT client ID |
| `topics` | string[] | [] | Topics to auto-subscribe on connect |
| `qos` | int | 0 | Default QoS level (0, 1, or 2) |
| `keepAlive` | int | 60 | Keep-alive interval in seconds |
| `autoConnect` | bool | false | Connect to broker automatically when the connector starts |
| `topicMap` | object | — | Map of MQTT topic → property name (see [Topic Mapping](#topic-mapping)) |

## Auto-Connect

Set `autoConnect: true` in the config to connect to the broker automatically when the connector is enabled. No need to call `connect` manually or write a startup script:

```javascript
config: {
  host: "builtin",
  autoConnect: true,
  topics: ["sensors/#"],
},
```

## Topic Mapping

Use `topicMap` to automatically create named properties from MQTT topics. These properties are pollable, bindable to dashboard widgets, and accessible from scripts and AI:

```javascript
config: {
  host: "builtin",
  autoConnect: true,
  topics: ["sensors/#"],
  topicMap: {
    "sensors/temperature": "temperature",
    "sensors/humidity": "humidity",
  },
},
poll: ["connected", "temperature", "humidity"],
```

Now `mqtt.temperature()` returns the last value published to `sensors/temperature`, and you can bind it to a gauge widget with `connector: "mqtt", property: "temperature"`.

Values are auto-parsed: numeric payloads return as numbers, `true`/`false` as booleans, everything else as strings. If no message has been received on a topic yet, `null` is returned.

## Built-in Broker

Muxit includes an embedded MQTT broker. Enable it in `server.json` or via **Settings → MQTT Broker** in the GUI:

```json
{
  "mqttBroker": {
    "enabled": true,
    "port": 1883,
    "username": "",
    "password": "",
    "maxClients": 100
  }
}
```

Then set `host: "builtin"` in your connector config to auto-connect to it.

## Example Connector

### Minimal (recommended)

```javascript
// workspace/connectors/mqtt.js
export default {
  driver: "MqttBridge",
  config: {
    host: "builtin",
    autoConnect: true,
    topics: ["sensors/#"],
    topicMap: {
      "sensors/temperature": "temperature",
      "sensors/humidity": "humidity",
    },
  },
  poll: ["connected", "messageCount", "temperature", "humidity"],

  ai: {
    instructions: "MQTT bridge for IoT sensors. Reading is safe. Confirm before publishing.",
  },
};
```

### With Custom Methods

For advanced use cases (e.g. JSON payload serialization, custom shortcuts):

```javascript
// workspace/connectors/mqtt.js
export default {
  driver: "MqttBridge",
  config: {
    host: "192.168.1.50",
    port: 1883,
    topics: ["sensors/#", "home/#"],
    qos: 0,
  },
  poll: ["connected", "messageCount", "lastTopic", "lastPayload"],

  methods: {
    connect:    [() => driver.connect(), "Connect to the MQTT broker"],
    disconnect: [() => driver.disconnect(), "Disconnect from the broker"],

    publish: {
      fn: (args) => driver.publish({
        topic: args.topic,
        payload: typeof args.payload === "object"
          ? JSON.stringify(args.payload)
          : String(args.payload ?? ""),
        qos: args.qos ?? 0,
        retain: args.retain ?? false,
      }),
      description: "Publish a message to a topic",
    },

    getValue: {
      fn: (args) => driver.get(typeof args === "string" ? args : args.topic),
      description: "Get the last received value from a topic",
    },
  },

  properties: {
    temperature: {
      get: () => driver.get({ topic: "sensors/temperature" }),
      description: "Temperature from MQTT sensor",
      poll: true,
    },
  },
};
```
