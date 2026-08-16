---
type: log
title: Knowledge bundle changelog
description: What was added or corrected in this bundle, and when
tags: [omapods]
---

## 2026-08-16

Bundle created alongside the first working panel.

- `bluez-has-no-airpods-battery` — measured with `busctl introspect` against a
  connected AirPods Pro 3. Closed the question of whether a stock mechanism
  could supply battery.
- `airpods-pro-3-identity` — `bluetoothctl info` and `pactl list short sinks`
  taken while the pods were connected.
- `librepods-status-schema` — read out of the daemon's `status` branch. The
  absent-keys behaviour and the BLE-versus-L2CAP split were found by reading
  the insert calls rather than by observing a live daemon, which is noted here
  because the daemon had not been built when the bundle was written.
- `librepods-build-requirements` — upstream and AUR checked directly rather
  than assumed.
- `ipc-socket-location` — written with the change that moved the socket.
- `librepods-status-schema` — corrected once the daemon was actually built and
  polled: the wire order is alphabetical, not the insert order the file had been
  written from. The first version of that fact was read out of source and was
  wrong about it.
- `plugin-design-decisions` — later the same day, recorded why there is no mic
  section and no Spatial Audio row, both asked for against the macOS Sound menu
  and both rejected on measured grounds rather than taste.
- `airpods-pro-3-has-no-off-mode` — found by driving the write path with the
  pods in ear, which also cleared up the earlier appearance that control was
  broken entirely (the pods had been in the case).
- `nerd-font-glyph-coverage` — added after trying to replace the drawn mark with
  nf-md-earbuds. fontconfig reported the codepoint as covered and it rendered as
  junk in the live bar, so the drawn mark stayed and nf-md-check replaced the
  drawn selection dot.
- `plugin-design-decisions` — poll cadence timed through a logging stub; the
  cursor-ring behaviour attributed to the shared panel chrome after
  reproducing it on the stock Bluetooth panel.
