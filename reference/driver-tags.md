---
title: Driver Tags
description: Controlled tag vocabulary for driver manifests.
---

# Driver Tags

Drivers declare `tags: string[]` in their [manifest](https://docs.muxit.io/reference/driver-manifest.md) to help users discover them in the Extensions panel and marketplace. Tags are drawn from a small controlled vocabulary so search is predictable.

Tags are validated by `node drivers.js validate` — unknown tags produce a warning.

## Vocabulary

| Tag | For |
|-----|-----|
| `spectroscopy` | Spectrometers, monochromators, optical analyzers |
| `motion` | Robots, CNC, stages, actuators, kinematic motion |
| `camera` | Cameras (webcam, IP, ONVIF, machine vision) |
| `robotics` | Industrial / collaborative robots specifically |
| `power` | Power supplies, batteries, electronic loads |
| `daq` | Data acquisition, digitizers, oscilloscopes, multimeters |
| `io` | General-purpose digital / analog I/O |
| `serial` | Serial-line protocols (UART, RS-232, RS-485) |
| `networking` | TCP/UDP, LXI, MQTT, HTTP transports |
| `cnc` | CNC-specific (g-code, GRBL) |
| `plotter` | Pen plotters |
| `laser` | Laser cutters/engravers |
| `monitor` | Raw monitoring / terminal tools |
| `terminal` | Interactive terminal-like tools |
| `arduino` | Arduino-family MCUs |
| `esp32` | ESP32-family MCUs |
| `gcode` | G-code-speaking devices |
| `grbl` | GRBL firmware |
| `drawing` | Drawing / vector output |
| `canvas` | Canvas-style 2D drawing APIs |
| `pen` | Pen-holding devices |
| `axidraw` | AxiDraw-specific |
| `audio` | Audio output, sound I/O |
| `synth` | Software or hardware synthesizers |
| `notification` | Alerting / user-feedback helpers (beeps, chimes) |
| `midi` | MIDI instruments, controllers, or file playback |
| `printer` | Printers and print spoolers (label, receipt, document) |
| `label` | Label design / label printing |
| `barcode` | Barcode and 2D-code generation or scanning |
| `other` | Fallback when no tag fits — rare |

Use 1–8 tags per driver. If you need a new tag that isn't in this list, request it through the driver registry or support — the controlled vocabulary is maintained centrally.
