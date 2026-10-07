---
title: Transport Configuration
description: Reference for the `connection:` block — selects which Transport (serial, tcp, usbtmc) a Protocol or Driver uses, and how to reach the device.
---

# Transport

A **[Transport](https://docs.muxit.io/reference/concepts.md)** moves bytes over a single channel — a serial port, a TCP socket, a USB endpoint. Every [Protocol](https://docs.muxit.io/reference/concepts.md) (Scpi, LineText, BinaryStream) rides on a Transport via the connector's `connection:` block. Most [Drivers](https://docs.muxit.io/reference/concepts.md) own their connection internally and don't need this block.

This page is the catalogue of every option the `connection:` block accepts.

## Quickstart

```js
// Pick one — sibling to `protocol:` and `config:` in the connector file.

// Serial (RS-232, USB-to-serial)
connection: { type: "serial", port: "/dev/ttyUSB0", baudRate: 9600 }

// TCP/IP (LXI lab instruments, network embedded devices)
connection: { type: "tcp", host: "192.168.1.50", port: 5025 }

// USBTMC (direct USB-B port on lab instruments — Rigol DS1000Z, Keysight DSO-X)
connection: { type: "usbtmc", vendorId: 0x1AB1, productId: 0x04CE }
```

The `type` field selects which Transport implementation to use; the remaining fields are transport-specific.

## Serial

For RS-232 ports, USB-to-serial adapters, and embedded devices speaking serial.

```js
connection: {
  type: "serial",
  port: "/dev/ttyUSB0",   // "COM5" on Windows, "/dev/tty.usbserial-XXXX" on macOS
  baudRate: 9600,
  // optional:
  dataBits: 8,
  stopBits: "one",
  parity: "none",
  flowControl: "none",
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `type` | `"serial"` | required | Selects the serial transport. |
| `port` | string | required | OS-level port path. Windows: `"COM4"`. Linux: `"/dev/ttyUSB0"`, `"/dev/ttyACM0"`. macOS: `"/dev/tty.usbserial-XXXX"` (find with `ls /dev/tty.*` after plugging in). |
| `baudRate` | int | `9600` | Bits per second. Common values: `1200`, `2400`, `4800`, `9600`, `19200`, `38400`, `57600`, `115200`. |
| `dataBits` | int | `8` | Bits per character: `5`, `6`, `7`, or `8`. |
| `stopBits` | enum | `"one"` | `"one"`, `"onePointFive"`, or `"two"`. |
| `parity` | enum | `"none"` | `"none"`, `"odd"`, `"even"`, `"mark"`, or `"space"`. |
| `flowControl` | enum | `"none"` | `"none"`, `"xon-xoff"` (software, XON/XOFF — Hameg HM81xx, older R&S / Tek), `"rts-cts"` (hardware), or `"both"`. |

### Finding the port

Don't know which port the device is on? The AI's [unplug-plug detection flow](https://docs.muxit.io/reference/ai-tools.md#discover_serial_device) — three calls to `list_serial_ports` before / during / after re-plugging the device — identifies the port automatically. The AI's [discover_serial_device](https://docs.muxit.io/reference/ai-tools.md#discover_serial_device) then sweeps common baud rates + terminators to find the right settings.

## TCP

For network-attached devices: LXI lab instruments (port 5025), Modbus-TCP slaves (502), telnet-style protocols (23), or any custom binary/text-over-TCP service.

```js
connection: {
  type: "tcp",
  host: "192.168.1.50",
  port: 5025,
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `type` | `"tcp"` | required | Selects the TCP transport. |
| `host` | string | required | IPv4 / IPv6 address or hostname. |
| `port` | int | `5025` for SCPI | TCP port. Common values: `5025` (SCPI / LXI raw socket), `502` (Modbus-TCP), `23` (telnet-style). |

## USBTMC

For lab instruments with a USB-B port that speak the USB Test & Measurement Class protocol — Rigol DS1000Z, Keysight DSO-X, Siglent SDS, Tektronix MSO/MDO, and many others. Higher throughput and lower latency than TCP or serial.

```js
connection: {
  type: "usbtmc",
  vendorId: 0x1AB1,         // Rigol
  productId: 0x04CE,        // DS1054Z
  // optional:
  serial: "DS1ZA231901234", // pick a specific device by USB serial number
  interfaceNumber: 0,
  endpointNumber: 0,
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `type` | `"usbtmc"` | required | Selects the USBTMC transport. |
| `vendorId` | int | required | USB Vendor ID. Hex literals (`0x1AB1`) or decimal ints both work. |
| `productId` | int | required | USB Product ID. |
| `serial` | string | — | Optional USB serial-number filter. Empty/omitted = first match. Use when multiple identical instruments are plugged in. |
| `interfaceNumber` | int | auto | USB interface index for the USBTMC class. Auto-detected; override only if libusb finds the wrong one. |
| `endpointNumber` | int | auto | USB endpoint index. Same auto-detection. |

### Finding VID/PID

Call the AI's [list_usbtmc_devices](https://docs.muxit.io/reference/ai-tools.md#list_usbtmc_devices) tool, or use a system tool: `lsusb` on Linux, System Information → USB on macOS, Device Manager → USB devices on Windows.

### Platform notes

- **Windows.** WinUSB driver must be bound to the device. The Windows USBTMC driver and Keysight IO / NI-VISA drivers will claim the device by default — install [Zadig](https://zadig.akeo.ie) → select the instrument → install WinUSB. Until you do, the transport will fail with "driver claimed by another process".
- **Linux.** Needs a udev rule for non-root access. Example for Rigol VID `0x1AB1`:
  ```
  # /etc/udev/rules.d/99-muxit-usbtmc.rules
  SUBSYSTEM=="usb", ATTRS{idVendor}=="1ab1", MODE="0666"
  ```
  Then `sudo udevadm control --reload-rules && sudo udevadm trigger`. Without this you'll get permission errors from libusb.
- **macOS.** Works out of the box — no setup needed.

## Which protocols ride which transports?

| Protocol | Serial | TCP | USBTMC |
|---|---|---|---|
| [Scpi](https://docs.muxit.io/reference/drivers/scpi.md) | ✓ | ✓ | ✓ |
| [LineText](https://docs.muxit.io/reference/drivers/linetext.md) | ✓ | ✓ | — |
| [BinaryStream](https://docs.muxit.io/reference/drivers/binary-stream.md) | ✓ | ✓ | — |

USBTMC is request-response (no spontaneous data), so LineText's prefix-matched line capture and BinaryStream's inter-frame-gap framing don't apply.

## See also

- [Concepts](https://docs.muxit.io/reference/concepts.md) — the 5-layer model (Transport / Protocol / Driver / Engine / Connector).
- [Scpi](https://docs.muxit.io/reference/drivers/scpi.md), [LineText](https://docs.muxit.io/reference/drivers/linetext.md), [BinaryStream](https://docs.muxit.io/reference/drivers/binary-stream.md) — protocol reference pages.
- [AI Tools](https://docs.muxit.io/reference/ai-tools.md) — discovery and probing for unknown devices.
- [Configuration](https://docs.muxit.io/reference/configuration.md) — server-level config (not transport-related).
