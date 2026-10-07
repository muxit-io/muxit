# Subscription & Plans

Muxit ships four tiers — **Free**, **Maker**, **Pro**, and **Lab**. Higher tiers
include everything in the lower tiers; each row below links from the **Plan
Comparison** table in **Settings → Subscription**, so you can jump straight from
a feature to what it actually does.

Tiers and their limits are defined in the server (`AppSettings.Features`) and
streamed to the UI, so the in-app comparison table is always an exact mirror of
what the server enforces — this page is the human-readable companion to it.

| Feature | Free | Maker | Pro | Lab |
| --- | :---: | :---: | :---: | :---: |
| [Connectors](#connectors) | 3 | 10 | ∞ | ∞ |
| [Concurrent script runs](#concurrent-script-runs) | 3 | ∞ | ∞ | ∞ |
| [Extension drivers](#extension-drivers) | 5 | ∞ | ∞ | ∞ |
| [Muxit AI chat](#muxit-ai-chat) | — | ✓ | ✓ | ✓ |
| [AI image analysis](#ai-image-analysis) | — | ✓ | ✓ | ✓ |
| [Local LLM](#local-llm) | ✓ | ✓ | ✓ | ✓ |
| [Remote access](#remote-access) | — | ✓ | ✓ | ✓ |
| [Label printing](#label-printing) | — | — | ✓ | ✓ |
| [MQTT broker](#mqtt-broker) | ✓ | ✓ | ✓ | ✓ |
| [Autonomous agents](#autonomous-agents) | — | — | soon | soon |
| [Safety policy engine](#safety-policy-engine) | — | — | — | ✓ |
| [Custom safety levels](#custom-safety-levels) | — | — | — | ✓ |
| [Audit log](#audit-log) | — | — | — | ✓ |

Prices live at [muxit.io/pricing](https://muxit.io/pricing) and checkout at
[muxit.io/buy](https://muxit.io/buy). After purchase, paste the license key from
your order e-mail under **Settings → Subscription → Activate License**. Premium
drivers offer a per-driver trial from the same panel.

## Connectors

**Free 3 · Maker 10 · Pro / Lab unlimited.** A connector is one configured
device (an instrument, robot, camera, or compute engine). The limit counts
connectors that are *loaded*, regardless of whether the underlying device is
online.

## Concurrent script runs

**Free 3 · Maker+ unlimited.** How many automation scripts may run at the same
time. The cap is on *simultaneously running* scripts, not on how many script
files you can keep in your workspace.

## Extension drivers

**Free 5 · Maker+ unlimited.** DLL / packaged extension drivers (`.muxdriver`)
installed into your workspace. Built-in drivers (Webcam, SCPI, TestDevice, …)
never count against this limit.

## Muxit AI chat

**Maker and above.** The built-in AI assistant and the script `ai()` global when
they run against the **Muxit-managed** cloud model. Pointing Muxit at a
[local LLM](#local-llm) instead works on every tier, including Free.

## AI image analysis

**Maker and above.** Lets the AI *see* a camera frame — the `take_snapshot`
tool in chat and MCP, and image input to the script global
`ai(prompt, snapshot)`. Free-tier calls that attach an image are blocked with an
`IMAGE_ANALYSIS_REQUIRES_PRO` reason; text-only inference is unaffected.

This covers general "look at this frame and describe it" vision. It is distinct
from the **Vision engine** — object detection, teach-by-example, calibration,
and visual servoing — which ships as a separate premium extension
(`Muxit.Driver.Vision`) that requires Pro plus its own license. In short: basic
image analysis is a Maker capability; the dedicated computer-vision engine is
where Pro pulls ahead.

## Local LLM

**Every tier, including Free.** Bring-your-own model over any OpenAI-compatible
endpoint — Ollama, LM Studio, vLLM, llama-server, and similar. Local inference
costs Muxit nothing per call, so chat and script `ai()` against your own model
are free on every tier, and the offline / air-gapped story works without a
subscription.

## Remote access

**Maker and above.** Reach your Muxit server from outside the local machine
(remote UI / tunnel access). See the [Remote Access guide](https://docs.muxit.io/guides/remote-access.md).

## Label printing

**Pro and above.** Printing labels to a real printer with the built-in
[LabelPrinter](https://docs.muxit.io/reference/drivers/label-printer.md) driver — `print()`,
`printBatch()`, `printImage()`, `printRaw()` and the Print buttons on the
**Tools → Label Printing** page. Listing printers, creating printer connectors,
editing templates, live previews (barcodes included: Code 128, Code 39/93, EAN,
UPC, ITF, Codabar, QR, Data Matrix, PDF417, Aztec) and dry runs on the `null`
backend are free on every tier, so a production line can be set up completely
before upgrading. See the [Label Printing guide](https://docs.muxit.io/guides/label-printing.md).

## MQTT broker

**Every tier, including Free.** The built-in MQTT bridge so homemade hardware
(ESP32, Arduino, and friends) can publish and subscribe without a paid plan. See
[MQTT & IoT](https://docs.muxit.io/guides/mqtt-iot.md).

## Autonomous agents

**Pro and above — coming soon.** Long-running AI agents that pursue a goal across
many tool calls. This feature is not yet generally available, so it appears as
"soon" rather than a checkmark and is hidden from the in-app comparison table
until it ships.

## Safety policy engine

**Lab only.** Enforcement of per-connector `safety:` blocks — limits, confirms,
rate caps, interlocks, safe states, and level overrides. On lower tiers the
[Safety Gate](https://docs.muxit.io/guides/safety.md) falls back to the global safety-level policy table.

## Custom safety levels

**Lab only.** Author your own named safety levels in addition to the built-in
Observe / Assisted / Active / Unrestricted set. See the [Safety guide](https://docs.muxit.io/guides/safety.md).

## Operator mode

**Pro and up.** Lock a station to a dashboard: the full interface, editor and
MCP are refused server-side, and only dashboard controls, scripts in the
`operator/` folder and an optional read-only AI chat remain. See the
[Operator mode guide](https://docs.muxit.io/guides/operator-mode.md). Kept working for 60 days after a
lapse, so a production station never unlocks overnight.

## User accounts

**Pro and up.** Admin, engineer and operator accounts with PIN sign-in, a
sign-in policy (optional or required), and the person's name on audit rows.
Global — useful for attribution on any install, not only a locked station.
See the [Accounts guide](https://docs.muxit.io/guides/accounts.md). Same 60-day grace as operator mode.

## Audit log

**Lab only.** An exportable, append-only audit trail of gated actions at
`workspace/logs/audit.jsonl`. Lower tiers fall back to per-event logger output.
