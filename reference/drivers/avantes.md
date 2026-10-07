---
title: Avantes Spectrometer Driver
description: Reference for the Avantes spectrometer driver — USB/Ethernet AvaSpec control with full colorimetry, horticulture photon-flux bins, CRI (Ra + R1-R14), peak and dominant wavelength, and auto integration time.
---

# Avantes

::: warning Not yet available
This driver is not published yet. It exists in the source tree for local use and is not on the
marketplace or in the Extensions panel; this page documents it ahead of release.
:::

**Driver for Avantes AvaSpec spectrometers over USB or Ethernet.** Talks to the device via the native Avantes SDK (`avaspecx64.dll`) using P/Invoke, takes calibrated irradiance measurements, and exposes a full lighting / horticulture / colorimetry report as cached properties.

Avantes is a premium tier-3 extension driver. It ships as a signed `.muxdriver` and installs into `workspace/drivers/`.

## Measurement flow

```js
// 1. Cover the entrance optic and capture a dark reference once per integration time.
await spec.measureDark();

// 2. (Optional) Let the driver pick a safe integration time for the current scene.
await spec.autoIntegrationTime({ targetFraction: 0.7 });

// 3. Take the measurement. measure() returns only status —
//    { isSaturated, peakCounts, integrationTime } — and refreshes all derived caches.
await spec.measure();

// 4. Read derived numbers as plain properties — no further device calls.
const cct      = await spec.cct;
const cri      = await spec.cri;           // Ra
const indices  = await spec.colorRendering; // [R1..R14], R9 at index 8
const lux      = await spec.illuminance;
const ppfd     = await spec.ppf;          // 400-700 nm
const blueFlux = await spec.photonFlux400_500;
```

`measure()` deliberately returns only minimal status so it stays cheap for the AI to call repeatedly; the full lighting / colour report is read from the cached properties afterwards. The AI can answer "measure CCT" by calling `measure()` and reading `cct` — it does not need to fetch the spectrum.

All numeric output (scalars and arrays) is rounded to the `significantDigits` config setting (default `4`).

## Derived metrics

All cached on every `measure()`. Properties return `NaN` (or `0` for non-negative fluxes) when a metric isn't meaningful for the current spectrum (e.g. `cct` on a pure laser line).

### Lighting

| Property | Unit | Description |
|---|---|---|
| `cct` | K | Correlated colour temperature (McCamy approximation). NaN when chromaticity is more than 0.05 Δuv from the Planckian locus. |
| `cieX`, `cieY` | — | CIE 1931 2° chromaticity coordinates. |
| `illuminance` | lx | Photopic V(λ)-weighted irradiance (683 lm/W × ∫ V(λ) E(λ) dλ). |
| `luminousFlux` | lm | Same integration as `illuminance`; differs only in the per-area interpretation of the input. |
| `cri` | — | CIE 13.3-1995 general colour rendering index (Ra, average of R1-R8). NaN when \|Duv\| > 0.0054. |
| `colorRendering` | — | Array of the 14 CIE 13.3 special indices `[R1…R14]`. R9 (deep red) is at index 8 (zero-based). Empty when CRI is undefined. |
| `peakWavelength` | nm | Wavelength of maximum spectral irradiance, parabolic-refined. |
| `dominantWavelength` | nm | Spectral colour the source matches; negative value means complementary (purples). |

### Horticulture photon-flux bins

| Property | Band (nm) | Use |
|---|---|---|
| `photonFlux300_400` | 300-400 | UV-A / UV-B |
| `photonFlux400_500` | 400-500 | Blue |
| `photonFlux500_600` | 500-600 | Green |
| `photonFlux600_700` | 600-700 | Red |
| `photonFlux700_800` | 700-800 | Far-red |
| `photonFlux800_1000` | 800-1000 | Near-IR |
| `ppf` | 400-700 | PAR / PPFD (already present) |
| `photonFlux400_800` | 400-800 | Extended PAR (already present) |

All fluxes in µmol/s (or µmol/(s·m²) if the calibration is per area). For arbitrary bands use the `getPhotonFlux` action.

## Properties

| Property | Type | Access | Unit | Description |
|---|---|---|---|---|
| `connected` | bool | R | — | Device connection status |
| `serial` | string | R | — | Connected device serial |
| `nrPixels` | int | R | — | Sensor pixel count |
| `integrationTime` | double | R/W | ms | Integration time (a.k.a. exposure) |
| `averages` | int | R/W | — | Hardware averages per measurement |
| `wavelengths` | double[] | R | nm | Wavelength axis (raw or interpolated grid) |
| `spectrum` | double[] | R | counts | Raw counts from last measurement |
| `dark` | double[] | R | counts | Dark reference data |
| `irradiance` | double[] | R | µW/nm | Calibrated irradiance |
| `isSaturated` | bool | R | — | Saturation detected in last measurement |
| `peakCounts` | double | R | counts | Maximum counts in last measurement |
| `darkCorrected` | bool | R | — | Whether a dark reference is loaded |
| `calibrationInfo` | string | R | — | Description of loaded calibration |
| `radiantPower` | double | R | W | Total radiant power 350-850 nm |
| `temperature` | double | R | °C | Detector temperature |
| `streaming` | bool | R/W | — | Continuous streaming enabled |
| `firmwareVersion`, `fpgaVersion` | string | R | — | Device firmware / FPGA versions |

…plus all derived metrics in the section above.

## Actions

| Action | Args | Description |
|---|---|---|
| `measure` | — | Take a single measurement; updates the full derived report |
| `measureDark` | — | Capture a dark reference at the current integration time |
| `clearDark` | — | Discard the dark reference |
| `autoIntegrationTime` | `{ targetFraction?, maxIterations?, minMs?, maxMs? }` | Iteratively adjust `integrationTime` so peak counts hit `targetFraction` of full scale (default 0.7) |
| `loadCalibration` | `{ source }` | `"eeprom"` or path to a calibration text file |
| `getRadiantPower` | `{ min, max }` | Radiant power (W) over an arbitrary band |
| `getPhotonFlux` | `{ min, max }` | Photon flux (µmol/s) over an arbitrary band |
| `discover` | — | List available Avantes devices on USB and Ethernet |
| `connect` | `{ serial? }` | Connect to a specific device, or the first available |
| `disconnect` | — | Disconnect |
| `startStream`, `stopStream` | — | Continuous measurement streaming |
| `getVersionInfo` | — | Firmware / FPGA / DLL versions |

## Config options

| Option | Type | Default | Description |
|---|---|---|---|
| `connectionType` | string | `"usb"` | `"usb"` or `"eth"` |
| `serial` | string | `""` | Target device serial — empty = first available |
| `integrationTime` | double | `100` | Integration time in ms |
| `averages` | int | `1` | Hardware averages per measurement |
| `useHighResAdc` | bool | `true` | Enable 16-bit ADC mode (when supported) |
| `calibrationSource` | string | `"eeprom"` | `"eeprom"` or path to a calibration file |
| `interpolate` | bool | `true` | Resample to a uniform wavelength grid |
| `interpolateMin/Max/Step` | double | `350`/`850`/`1` | Interpolation grid (nm) |
| `strayLightCorrection` | bool | `false` | Use `AVS_SuppressStrayLight` if available |
| `strayLightFactor` | double | `1.0` | Stray-light multiplier |
| `streamIntervalMs` | int | `1000` | Streaming interval |
| `autoIntegration` | bool | `false` | When `true`, every `measure()` runs `autoIntegrationTime` first (skipped while a dark reference is loaded) |
| `significantDigits` | int | `4` | Significant figures applied to all numeric output (scalars and arrays, including the wavelength axis). Set `0` to disable rounding |

## Notes on accuracy

- **CCT / CRI / dominant wavelength** are only meaningful for broadband white-ish sources. For monochromatic sources (lasers, narrow-band LEDs) these will return NaN or be reported as off-locus.
- **Dark reference is per-integration-time.** Retake the dark whenever you change `integrationTime` — `autoIntegrationTime` is therefore skipped while a dark is loaded.
- The McCamy CCT approximation is accurate to ±2 K for 2856-6500 K and degrades gracefully outside that range. For laboratory-grade accuracy, post-process the raw `irradiance` array.
- CRI uses the CIE 13.3-1995 procedure (14 TCS samples, Planckian < 5000 K / D-illuminant ≥ 5000 K reference, von-Kries chromatic adaptation, CIE 1964 U\*V\*W\* differences). It computes `[Ra, R1…R14]` internally; `cri` exposes Ra and `colorRendering` exposes the special indices `[R1…R14]` (R9 at index 8).
