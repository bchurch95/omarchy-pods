---
type: reference
title: fontconfig claims glyphs the shipped Nerd Font cannot draw
description: nf-md-earbuds is reported in the charset and renders as fallback junk, which is why the bar mark is drawn rather than typed
tags: [omarchy, fonts, icons]
status: stable
verified:
  - by: rendered each candidate in the live bar and panel on the box, then screenshotted
    at: 2026-08-16
---

# What was tested

The theme font is `JetBrainsMono Nerd Font`
(`/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf`). Three candidates
for this plugin, all of which fontconfig reports as covered:

```
$ fc-match -f "%{family}\n" ":charset=F1085"
JetBrainsMono Nerd Font,JetBrainsMono NF
```

| Glyph | Codepoint | Rendered |
|---|---|---|
| nf-md-check | U+F012C | correct check mark |
| nf-md-earbuds | U+F1085 | fallback junk, `LOG` in the bar and `JG` in the hero |
| nf-md-earbuds_off | U+F1086 | same |

# The lesson

**A fontconfig charset hit is not proof the glyph draws.** `fc-match
:charset=<cp>` answers from the font's cmap, and a cmap entry can point at a
glyph the family does not actually carry at that size, or one the fallback
chain resolves elsewhere. The only test that counts is rendering it in the real
bar and looking.

Both earbuds codepoints are in the Material Design Icons block, well above the
range this build of the font draws, while `nf-md-check` in the same block is
fine. So "it is an MDI glyph" says nothing either.

# What the plugin does

The selected listening mode is marked with `nf-md-check`, which was measured
working. The bar and hero mark is drawn from primitives in `AirPodsIcon.qml`,
the same choice the stock Tailscale plugin makes for its dot grid, and for the
same reason: a mark that cannot depend on what the active theme's font happens
to carry.
