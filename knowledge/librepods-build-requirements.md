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
`AirPodsPro3` and no `A306x`, and nothing at all for the 2026 AirPods Max 2.

The AUR carries `librepods 1.0.0rc1`, `librepods-git`, `librepods-rust-git` and
`librepods-rust-bin`, all built from upstream. So an AirPods Pro 3 owner
installing the packaged daemon gets a device the daemon reports as `Unknown`,
an empty `model_name`, `is_pro_series` false, and no JSON to read in the first
place.

# What that means for the plugin

The panel needs a librepods build that carries the state file, the `status`
verb, the control verbs and the Pro 3 model map. That is a fork, not a package,
so the fork ships in this repository under `daemon/` rather than being named as
something the user has to go and find. `daemon/UPSTREAM.md` records where it
came from, that it is GPL-3.0, and what was changed.

# Build inputs on Arch

`g++`, `qmake6`, `pkg-config` and `libpulse` are usually already present on an
Omarchy box. The daemon additionally needs `cmake`, `ninja`, `qt6-connectivity`,
`qt6-tools` and `qt6-quickcontrols2`, all in `extra`.

The daemon target links Qt Quick, QuickControls2, Widgets and LinguistTools
even when it runs with `--hide`, because the IPC dispatch routes every verb
through the tray application object and the tray itself is a `QSystemTrayIcon`.
Measured on the box: 86.1 MB resident, of which 23.5 MB is the Qt Gui, Widgets,
Qml and Quick libraries it never draws with. A headless target would be a real
refactor of `main.cpp` rather than a CMake flag, because the same class also
carries the `Q_PROPERTY` set, `loadMainModule`, the open handlers and a
`topLevelWindows()` call, and nine GUI-only includes leave the target include
path the moment `Qt6::Quick` is unlinked.
