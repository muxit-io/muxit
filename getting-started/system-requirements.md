---
title: System Requirements
description: What you need to run Muxit — supported platforms, hardware, and network requirements.
---

# System Requirements

Muxit ships as a self-contained binary for **Windows (x64)**, **Linux (x64 and ARM64)**, and **macOS (Apple Silicon and Intel)**. iOS support is on the roadmap but not yet available.

## Supported Platforms

| Platform | Status |
|----------|--------|
| **Windows 10 or later (x64)** | Supported today |
| **macOS 12+ (Apple Silicon / Intel)** | Supported today — see [macOS notes](#macos-notes) |
| Linux (x64 and ARM64, incl. Raspberry Pi) | Supported today |
| iOS / iPadOS | Planned |

## macOS notes

macOS builds run the same self-contained server as every other platform. Cameras and AI vision work; a few OpenCV-only features don't, because there is no OpenCV native runtime for macOS (no build matches Muxit's OpenCV version, and none exists for Apple Silicon at all). Specifics:

- **Cameras work.** The TestDevice video stream, USB webcams, and Onvif/RTSP IP cameras all stream and snapshot on macOS — the webcam and Onvif paths capture through the system `ffmpeg` binary and do image work with SkiaSharp instead of OpenCV. Install ffmpeg with `brew install ffmpeg`, and grant camera access under **System Settings → Privacy & Security → Camera** for USB capture.
- **Not available on macOS:** **video recording** (the recorder uses OpenCV's VideoWriter) and the optional **Vision detection driver** (OpenCV image-analysis algorithms). Everything else — SCPI/serial/USB instruments, scripts, the AI layer (including vision/object-detection over camera frames), dashboards, MQTT, Python drivers — works normally.
- **Builds are not yet code-signed or notarized.** macOS Gatekeeper quarantines downloaded binaries. The install script clears the quarantine attribute for you. If you download a release archive by hand instead, run `xattr -dr com.apple.quarantine <install-dir>` once before launching.

## Hardware

| Requirement | Recommended |
|-------------|-------------|
| **Disk space** | ~150 MB for the Muxit binary; workspace files grow with your own scripts and data |
| **Memory** | 4 GB RAM or more |
| **CPU** | Any modern x64 or ARM64 processor (including Raspberry Pi 4 / 5) |

## Network

- **Outbound internet** is required for AI features (chat, agents, object detection) and for license activation.
- **Local network** access is required for remote access, mDNS discovery, and any networked instruments (ONVIF cameras, TCP/IP SCPI instruments, MQTT brokers).
- Muxit runs fully offline for local-only workflows once a license has been activated.

## Runtime

Muxit ships as a single self-contained package — **no prerequisites to install**. The .NET 9.0 runtime, V8 sandbox, and every built-in driver are bundled inside the release archive.

### Optional: Python 3.10+

Python drivers and the generic `Python` driver (used to wrap a `.py` file as a connector) need a Python 3.10+ interpreter on the host. Muxit probes the `MUXIT_PYTHON` environment variable, then `python3` on PATH, then `python` on PATH — the first usable interpreter wins. If none is found, Python drivers are silently skipped at scan time and the rest of Muxit keeps working. Install Python from [python.org](https://www.python.org/downloads/) or your package manager when you want to use this tier. See the [Python Driver SDK](https://docs.muxit.io/reference/driver-sdk-python.md) for details.

## Roadmap

iOS / iPadOS support is planned but not yet shipped — it would run as a client to a remote Muxit server rather than hosting one on-device. No dates have been set; the [Revision History](https://docs.muxit.io/reference/revision-history.md) is the canonical place for release announcements.
