---
type: reference
title: What this panel owns, and what it deliberately leaves to Omarchy
description: The split against the stock audio and Bluetooth panels, the poll cadence, and the behaviours that belong to the shared panel chrome rather than to this plugin
tags: [omarchy, quickshell, design]
status: stable
verified:
  - by: measured against the stock panels on the box, and by timing the plugin's own polls through a logging stub
    at: 2026-08-16
---

# The split

macOS merges audio routing with device control in one Sound menu. Omarchy
separates them, and that separation is the design rather than a compromise.

| Control | Owner |
|---|---|
| Volume, output device list, per-app mixer | stock `omarchy.audio` |
| Connect, disconnect, forget, pairing | stock `omarchy.bluetooth`, `omarchy bluetooth device` |
| Per-pod and case battery | this plugin |
| Listening mode, adaptive level, Conversation Awareness, One-Bud ANC | this plugin |
| Ear detection, case lid | this plugin |
| Spatial Audio | nobody: no renderer on Linux, so no row |
| Mic mode, input mute, input device | stock `omarchy.audio`: not an AirPods control at all |

Panels sit side by side and `Tab` walks between them, so the honest answer to
"I want one menu like macOS" is that the audio panel is one keystroke away.
Reimplementing the sink list here would duplicate something that already
survives `omarchy update`.

# Why there is no mic section

macOS shows Standard and Voice Isolation under a Mic Mode heading whenever an
app holds the microphone. That is macOS DSP applied to the input stream for any
source, not an AirPods capability: `grep -i 'mic|voice|isolation'` over
`airpods_packets.h`, `main.cpp` and `enums.h` finds nothing, and `ipcverb.hpp`
names `mic:N` only as a hypothetical future verb. There is no packet to send.

Two real Linux options were considered and rejected. A PipeWire `rnnoise`
filter chain is honest noise suppression but applies to every microphone, so it
belongs to audio configuration rather than to an AirPods panel. A card-profile
row switching A2DP against HFP would be genuinely AirPods-specific, but
PipeWire already switches profiles when an application opens the source, so it
would be a knob nobody turns.

# Poll cadence, measured

`refreshIntervalSec` is a manifest setting clamped to 2-3600 on every read, so
a hand-edited `shell.json` cannot poison the timer. While the panel is open the
cadence drops to a fixed 1s.

Timed through a stub that logs every invocation, because sampling with `pgrep`
counts nothing when the subject exits in milliseconds:

```
CLOSED 15s: 3 polls
OPEN   10s: 10 polls
```

# Optimistic state

A click writes the new value locally and records the field as pending, so the
control moves at once. Incoming polls cannot overwrite that field until the
daemon reports the same value, which stops a poll already in flight from
snapping the control back. The hold is bounded at six settle ticks, so a daemon
that never agrees unfreezes the control instead of pinning it forever.

# Behaviours that are not this plugin's

The cursor ring appears on a row as soon as the panel opens, before any
keypress. That comes from the shared `PanelKeyCatcher`, not from here: the
stock Bluetooth panel does the same thing when opened by IPC with the pointer
parked off-panel. `onOpenedChanged` does reset `cursorActive` and `cursorIndex`;
the catcher then re-establishes a cursor on its own.

Keyboard behaviour cannot be driven headlessly at all. `wtype` does not reach a
layer-shell surface and `ydotool` is not installed, so the key map is verified
by reading it and at the keyboard, and the automated checks drive the plugin's
own IPC verbs instead.

# The mark

The bar icon is drawn from primitives rather than shipped as an SVG, because a
two-stem earbud silhouette loses its stems to rasterisation at bar size. The
selected listening mode is likewise marked with a drawn dot rather than a check
glyph, so the mark cannot depend on which Nerd Font the active theme ships.
