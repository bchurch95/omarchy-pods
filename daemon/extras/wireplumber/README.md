# WirePlumber overlays for OpenPods

User-config overlays that tilt the audio stack toward AirPods on Linux.

## 51-bluez-codecs.conf

Enables AAC + mSBC + hardware volume. AirPods over Bluetooth get:

- **AAC ~256 kbps** speaker output (vs SBC ~328 kbps but lossier)
- **mSBC 16 kHz** mic input (wideband; CVSD is 8 kHz AM-radio)
- **Hardware volume** so the AirPods' physical controls follow stream level
- **Native HFP/HSP** instead of oFono (which most desktops don't run)

Install:

```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cp 51-bluez-codecs.conf ~/.config/wireplumber/wireplumber.conf.d/
systemctl --user restart wireplumber
```

Verify after reconnecting AirPods:

```bash
pactl list sinks | grep -iE 'codec|api.bluez5'
# expect: codec = "aac" or codec = "sbc_xq" — sbc plain means a downgrade
```

Mic check (when on a call / using HFP):

```bash
pactl list sources | grep -iE 'codec|sample'
# expect: rate = 16000 (mSBC) — 8000 means CVSD fallback
```

## Why a user-config overlay

System defaults in `/usr/share/wireplumber/` get overwritten on update.
`~/.config/wireplumber/wireplumber.conf.d/` overlays survive packaging
churn. WirePlumber merges files in `conf.d/` directories alphabetically,
so the `51-` prefix puts this after default fragments (`50-*`).
