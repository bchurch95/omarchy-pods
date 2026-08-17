# Quickshell consumer for OpenPods

`AirPods.qml` is a Quickshell `Singleton` that subscribes to the
`status` IPC command of a running OpenPods daemon. Drop it into your
Quickshell config and reference `AirPods.connected`, `AirPods.leftLevel`,
etc. from anywhere.

## Install

```bash
cp AirPods.qml ~/.config/quickshell/<your-shell>/
```

Then add a `qmldir` entry if your shell uses one:

```
singleton AirPods 1.0 AirPods.qml
```

(Or just `import "."` in the file that uses it — the singleton is
auto-discovered.)

## Use

```qml
import Quickshell

Rectangle {
    visible: AirPods.connected
    color: Theme.colSurface
    radius: Theme.tileRadius

    Row {
        spacing: 6
        Text {
            text: AirPods.leftLevel >= 0 ? AirPods.leftLevel + "%" : "—"
            color: Theme.colFg
            font.features: { "tnum": 1 }
        }
        Text {
            text: AirPods.rightLevel >= 0 ? AirPods.rightLevel + "%" : "—"
            color: Theme.colFg
            font.features: { "tnum": 1 }
        }
        Text {
            visible: AirPods.caseLevel >= 0
            text: AirPods.caseLevel + "%"
            color: Theme.colDim
        }
    }
}
```

## Contract

Source of truth: `linux/main.cpp` — the `status` IPC handler. Returned
JSON is one line. `schema_version` gates compatibility:

- 1 — current. Fields: `connected`, `device_name`, `noise_mode`,
  `left/right/case` objects (available/level/charging/in_ear),
  `reconnect_attempts_total`, `reconnect_failures_total`.
- Future bumps mean additive breakage. This consumer surfaces the
  raw schema_version when newer than known, so the bar can warn.

## Poll cadence

Default 5s. Bind `AirPods.pollInterval = 1000` (in ms) while a popover
is open if you want sub-second refresh, then restore. Polling is cheap
(unix-socket round-trip + JSON parse).
