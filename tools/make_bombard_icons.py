#!/usr/bin/env python3
"""Placeholder BOMBARD (fire at a spot) command icons, composited in code until ChatGPT paints the real ones
(docs/command_icons_audit.md, TO DRAW; logged in docs/art_style_inconsistency.md):

  assets/icons/ab_bombard.png            the Crown's ATTACK icon (crossed swords, steel frame) with a red target ring
  assets/icons/brood/ab_bombard.png      the Brood's ATTACK icon (spitting raptor, brass frame) with an acid-green ring
  assets/icons/clockwork/ab_bombard.png  the Clockwork's ATTACK icon (firing soldier, brass frame) with a brass ring

The ring (with four ticks, like the target marker drawn on the map for a BOMBARD spot) sits in the lower right of the
picture, inside the frame, with a dark outline so it reads on any background. Usage: python3 tools/make_bombard_icons.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ICONS = os.path.join(ROOT, "assets", "icons")

# faction folder ("" = the Crown's, assets/icons) -> the ring's colour
RINGS = {"": (226, 52, 38), "brood": (150, 222, 60), "clockwork": (236, 196, 92)}
CENTRE = (43, 43)
R = 11          # the ring's radius (px)


def ring(img, col):
    d = ImageDraw.Draw(img)
    cx, cy = CENTRE
    dark = (12, 10, 8, 255)
    # dark outline, then the coloured ring and its four ticks on top
    for w, c, grow in ((4, dark, 1), (2, col + (255,), 0)):
        r = R + grow
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=c, width=w)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a = (cx + dx * (R - 5 - grow), cy + dy * (R - 5 - grow))
            b = (cx + dx * (R + 5 + grow), cy + dy * (R + 5 + grow))
            d.line([a, b], fill=c, width=w + (0 if grow == 0 else 1))
    d.ellipse([cx - 1, cy - 1, cx + 1, cy + 1], fill=col + (255,))       # the aim point


def main():
    for fac, col in RINGS.items():
        src = os.path.join(ICONS, fac, "attack.png")
        img = Image.open(src).convert("RGBA")
        ring(img, col)
        out = os.path.join(ICONS, fac, "ab_bombard.png")
        img.save(out)
        print("wrote", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    main()
