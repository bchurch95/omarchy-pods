# This directory is a modified copy of librepods

`daemon/` is the AirPods daemon the bar widget needs. It is **not** original
work: it is a modified copy of [librepods](https://github.com/kavishdevar/librepods)
by **Kavish Devar**, who reverse-engineered Apple AAP over L2CAP and the BLE
advertisement path that carries battery, in-ear and case lid state. That is the
hard part of this project, and it is his.

| | |
|---|---|
| Upstream | https://github.com/kavishdevar/librepods |
| Forked at | `29a914c`, 2026-05-19 |
| Licence | GNU General Public License v3.0, see `LICENSE` in this directory |
| Modified by | GM, through 2026-08-16 |

The copy here is the `linux/` subtree only, because that is all the widget
needs. Upstream also ships an Android app and a root module, which are not
reproduced here; get them from upstream.

## What was modified

130 commits of Linux daemon work sit on top of the fork point. The changes that
matter to this widget:

- **A published state file.** The daemon writes its whole status as one line of
  JSON to `$XDG_STATE_HOME/librepods/status.json` when the state changes, and
  removes it on quit. This is what lets the panel watch a file and run no
  processes at all while idle.
- **A `status` verb and control verbs** on the local socket: `ca:`, `onebud:`,
  `adaptive:N`, `ear:`, alongside the upstream noise verbs.
- **AirPods Pro 3 support**, including the `A3064` model map and a
  `supports_noise_off` flag, because the Pro 3 has no Off listening mode and
  silently ignores the packet.
- **Case lid state** reported from the BLE advertisement.
- **The control socket moved off `/tmp`** to `$XDG_RUNTIME_DIR/librepods.sock`,
  which is mode 0700, and both binaries refuse to fall back.
- **A systemd user unit**, bound to `graphical-session.target`.
- **Notifications through the host desktop** rather than a Qt tray toast.
- **Memory and reliability work**: the QML engine load is deferred under
  `--hide`, and the daemon no longer grabs the pods on every local playback.

## Building it

```bash
cd daemon
cmake -B build -G Ninja
cmake --build build
```

Needs `cmake`, `ninja`, `qt6-connectivity`, `qt6-tools`, `qt6-quickcontrols2`,
`pkg-config` and `libpulse`, all in the Arch `extra` repository.

## Licence

This directory is GPL-3.0, inherited from upstream, and stays GPL-3.0. The bar
widget in the repository root is a separate program that talks to this daemon
over a state file and a command line, and is MIT. See the repository README.
