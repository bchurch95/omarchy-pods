---
type: reference
title: Which librepods a user needs, and why the packaged one will not do
description: Upstream and the AUR carry no status verb and do not recognise AirPods Pro 3, measured rather than assumed
tags: [librepods, packaging, aur]
status: stable
verified:
  - by: grep over upstream linux/main.cpp and linux/enums.h, and yay -Ss against the AUR
    at: 2026-08-16
---

# The measurement

Upstream `kavishdevar/librepods` `linux/main.cpp` is 1138 lines and contains no
`schema_version`, no `"status"` branch, and none of the `adaptive:`, `onebud:`
or `ca:` verbs. Its `linux/enums.h` has no AirPods Pro 3 entry at all: no
`AirPodsPro3`, no `A306x`, no `A333x`.

The AUR carries `librepods 1.0.0rc1`, `librepods-git`, `librepods-rust-git` and
`librepods-rust-bin`, all built from upstream. So an AirPods Pro 3 owner
installing the packaged daemon gets a device the daemon reports as `Unknown`,
an empty `model_name`, `is_pro_series` false, and no JSON to read in the first
place.

# What that means for the plugin

The panel needs a librepods build that carries the `status` verb, the control
verbs and the Pro 3 model map. That is a fork, not a package. The README states
the daemon as a requirement and names it, rather than pretending any librepods
will do.

# Build inputs on Arch

`g++`, `qmake6`, `pkg-config` and `libpulse` are usually already present on an
Omarchy box. The daemon additionally needs `cmake`, `ninja`, `qt6-connectivity`,
`qt6-tools` and `qt6-quickcontrols2`, all in `extra`.

The daemon target links Qt Quick, QuickControls2, Widgets and LinguistTools
even when it runs with `--hide`, because the IPC dispatch routes every verb
through the tray application object and the tray itself is a `QSystemTrayIcon`.
A headless daemon target would be a real refactor of `main.cpp`, not a CMake
flag.
