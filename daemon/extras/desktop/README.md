# OpenPods desktop entry

Install path:

```bash
mkdir -p ~/.local/share/applications
cp OpenPods.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications
```

`%h` expands to `$HOME`. The Exec line points at `~/.local/bin/librepods`
— a wrapper that prefers the fork build, falling back to the AUR system
binary. The wrapper script:

```sh
#!/bin/sh
FORK=$HOME/Projects/librepods/linux/build/librepods
if [ -x "$FORK" ]; then
    exec env -u QT_STYLE_OVERRIDE "$FORK" "$@"
fi
exec env -u QT_STYLE_OVERRIDE /usr/bin/librepods "$@"
```

`env -u QT_STYLE_OVERRIDE` is the kvantum-segfault workaround documented
in FORK.md.

If you keep the AUR `librepods` package installed alongside, walker /
rofi may show two entries (the AUR one ships
`me.kavishdevar.librepods.desktop`). Either:

- Remove the AUR system entry: `sudo rm /usr/share/applications/me.kavishdevar.librepods.desktop`, or
- Override locally: copy this `OpenPods.desktop` to
  `~/.local/share/applications/me.kavishdevar.librepods.desktop` (same
  desktop-id wins over `/usr/share/`).
