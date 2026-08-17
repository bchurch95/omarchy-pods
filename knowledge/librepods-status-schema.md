---
type: reference
title: The librepods status file, key by key
description: The exact wire format the panel parses, where the daemon publishes it, and the keys that vanish entirely rather than going false
tags: [librepods, ipc, schema]
status: stable
verified:
  - by: read from a running daemon against a connected AirPods Pro 3, then read back against the publish and quit paths in linux/main.cpp
    at: 2026-08-16
---

# Where it comes from

The daemon writes the whole status object, one line of compact JSON, to
`$XDG_STATE_HOME/librepods/status.json` through a `QSaveFile`, so a reader
never sees a half-written file. Three properties of that path are load-bearing
for the panel:

- **It writes only on change.** The publish path compares the rendered line
  against the last one and returns early when they match, so a control verb the
  pods ignored produces no write at all.
- **It removes the file on quit**, from `aboutToQuit`, and the daemon's own
  comment says so: "An absent state file is how a watcher learns the daemon
  stopped." Measured: `systemctl --user stop librepods` removes it.
- **It is created late.** The shell can start before the daemon; a `FileView`
  with `watchChanges: true` picks the file up when it appears, measured at
  under 6s, which is why the panel needs no startup ramp.

`librepods-ctl status` prints the same object over the control socket. The panel
does not use it, and runs `librepods-ctl` only for the control verbs below.

# The keys the panel reads

| Key | Type | Meaning |
|---|---|---|
| `schema_version` | int | currently 1, gates incompatible bumps |
| `connected` | bool | the L2CAP audio link, not whether the daemon is up |
| `device_name` | string | the BlueZ alias |
| `noise_mode` | int | 0 Off, 1 Noise Cancellation, 2 Transparency, 3 Adaptive, -1 unknown |
| `left`, `right` | object | `{available, level, charging, in_ear}` |
| `case` | object | `{available, level, charging}`, no `in_ear` |
| `conversational_awareness` | bool | Pro only |
| `adaptive_noise_level` | int | 0-100, only meaningful while `noise_mode` is 3 |
| `one_bud_anc_mode` | bool | Pro only |
| `model_name` | string | marketing name, empty until the device is identified |
| `is_pro_series` | bool | gates Conversation Awareness, One-Bud ANC, Adaptive |
| `ear_detection_behavior` | int | 0 pause when one is out, 1 when both are out, 2 never |
| `lid_state` | int | 0 open, 1 closed, 2 unknown |

The line arrives with **keys sorted alphabetically**, not in the daemon's insert
order, because `QJsonObject` sorts. Anything reading the line positionally, or a
sample-input comment written from the insert calls, will be wrong.

Thirteen `*_total` counters also appear, along with `model_int` and
`model_number`. They are daemon telemetry and identity, not panel data, and
nothing in the plugin reads them.

# Two shapes that bite

**`left`, `right` and `case` are absent entirely** until a battery packet has
arrived, rather than present with `available: false`. A parser that assumes the
keys exist reads `undefined` on a fresh daemon. `Model.parseStatus` returns a
complete default shape on every path for this reason.

**`connected` false does not mean nothing is known.** Battery keeps arriving
over the BLE advertisement while the audio link is down, which is exactly the
in-case state where the user wants to see it. The panel therefore gates the
battery section on any known level and the control sections on `connected`.

# Control verbs

`noise:off`, `noise:anc`, `noise:transparency`, `noise:adaptive`,
`ear:one`, `ear:both`, `ear:off`, `ca:on`, `ca:off`, `onebud:on`,
`onebud:off`, `adaptive:N` for N in 0-100.

The daemon also offers `connect`, `disconnect` and `forget`, which shell out to
`bluetoothctl`. The panel does not use them: `omarchy bluetooth device` and the
stock Bluetooth panel already own that job.
