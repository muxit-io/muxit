---
title: Built-in Drivers
description: Reference for all built-in drivers that ship with Muxit — TestDevice, Webcam, ONVIF, FileAccess, Virtual, and MqttBridge.
---

# Built-in & Bundled Drivers

Muxit ships with a core set of built-in drivers plus a few bundled extensions — most are always available with no manual installation. The **Vision** engine is the exception: it's a premium extension, installed from the marketplace and licensed separately on Pro and above. Together these cover testing, cameras, vision, file storage, IoT, notifications, label printing, audio, MIDI, SCPI instruments, and serial protocol work.

| Driver | Description | Guide |
|--------|-------------|-------|
| [TestDevice](https://docs.muxit.io/reference/drivers/test-device.md) | Simulated instrument for learning and testing | — |
| [Webcam](https://docs.muxit.io/reference/drivers/webcam.md) | USB webcam/video capture via OpenCV | — |
| [ONVIF](https://docs.muxit.io/reference/drivers/onvif.md) | IP camera streaming, snapshots, and PTZ control | — |
| [Vision](https://docs.muxit.io/reference/drivers/vision.md) | Real-time computer vision (color/contour detection) — **premium, requires the `vision` license** | [AI Guide — Vision](https://docs.muxit.io/guides/ai.md#vision-guided-robot-control) |
| [FileAccess](https://docs.muxit.io/reference/drivers/file-access.md) | Sandboxed file I/O for scripts and AI | — |
| [Virtual](https://docs.muxit.io/reference/drivers/virtual.md) | In-memory store with no hardware — share values between scripts and dashboards | [Dashboards Guide](https://docs.muxit.io/guides/dashboards.md#virtual-store-pattern) |
| [MqttBridge](https://docs.muxit.io/reference/drivers/mqtt-bridge.md) | MQTT broker bridge for IoT devices | [MQTT & IoT Guide](https://docs.muxit.io/guides/mqtt-iot.md) |
| [EmailNotifier](https://docs.muxit.io/reference/drivers/email-notifier.md) | Outbound SMTP e-mail (text, HTML, attachments) | [Notifications Guide](https://docs.muxit.io/guides/notifications.md) |
| [WebhookNotifier](https://docs.muxit.io/reference/drivers/webhook-notifier.md) | HTTP webhook with ntfy / Discord / Slack flavors | [Notifications Guide](https://docs.muxit.io/guides/notifications.md) |
| [LabelPrinter](https://docs.muxit.io/reference/drivers/label-printer.md) | Label printing from JSON templates through any installed printer (templates, barcodes and previews on every tier; printing to a real printer on Pro) | [Label Printing Guide](https://docs.muxit.io/guides/label-printing.md) |
| [AudioSynth](https://docs.muxit.io/reference/drivers/audio-synth.md) | Software synth for audible notifications on the server host | — |
| [Midi](https://docs.muxit.io/reference/drivers/midi.md) | Live MIDI I/O, SMF playback/recording, clock, panic, learn | — |
| [Scpi](https://docs.muxit.io/reference/drivers/scpi.md) | Built-in SCPI protocol — declarative, rides on TCP / serial / USB-TMC | — |
