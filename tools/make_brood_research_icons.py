#!/usr/bin/env python3
"""THE BROOD'S RESEARCH ICONS: code-drawn PLACEHOLDERS until the owner's ChatGPT drawings come
(docs/command_icons_audit.md "TO DRAW", docs/art_style_inconsistency.md).

Each is the creature's own 64x64 portrait (assets/icons/<unit>.png) with a round badge in the lower right
corner showing what the research does: three eggs (BIGGER CLUTCH), speed chevrons (PACK HUNT, SLITHER),
a cracked palisade (BATTERING HORNS), a range arc with a glob (LONG SPIT), rising arrows (UPDRAFT), a root
with a turning arrow (QUICK ROOTS), a green cross on a swamp drop (SWAMP MENDING).

    python3 -I tools/make_brood_research_icons.py      (writes assets/icons/nbr_<name>.png)
"""
import math
import os

from PIL import Image, ImageDraw, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "icons")
S = 4                      # supersampling
SIZE = 64

# name: (portrait, badge)
ICON_LIST = {
    "nbr_clutch_raptor": ("raptor", "eggs"),
    "nbr_pack_hunt": ("raptor", "fast"),
    "nbr_battering_horns": ("brute", "wall"),
    "nbr_clutch_spitter": ("spitter", "eggs"),
    "nbr_slither": ("spitter", "fast"),
    "nbr_long_spit": ("venom_challenger", "range"),
    "nbr_clutch_hatchlings": ("pterodactyl", "eggs"),
    "nbr_updraft": ("skywing", "up"),
    "nbr_quick_roots": ("brood_mother", "roots"),
    "nbr_swamp_mending": ("brood_mother", "mend"),
}

GOLD = (236, 196, 92, 255)
DARK = (14, 18, 30, 235)
RIM = (150, 108, 52, 255)
EGG = (214, 226, 120, 255)
EGG_D = (96, 110, 40, 255)
GREEN = (120, 220, 90, 255)
WHITE = (240, 240, 230, 255)
BROWN = (128, 86, 48, 255)


def badge(kind):
    """The badge on a transparent 64x64 canvas (supersampled)."""
    im = Image.new("RGBA", (SIZE * S, SIZE * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = 15 * S
    cx, cy = (SIZE - 17) * S, (SIZE - 17) * S
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=DARK, outline=RIM, width=3 * S)

    def P(x, y):
        return (cx + x * S, cy + y * S)

    if kind == "eggs":
        for (x, y) in [(-6, 3), (6, 3), (0, -5)]:
            d.ellipse([P(x - 4, y - 5), P(x + 4, y + 5)], fill=EGG, outline=EGG_D, width=S)
    elif kind == "fast":
        for dx in (-6, 2):
            d.line([P(dx - 3, -8), P(dx + 5, 0), P(dx - 3, 8)], fill=GOLD, width=3 * S, joint="curve")
    elif kind == "wall":
        for x in (-8, -2, 4):
            d.rectangle([P(x, -6), P(x + 5, 9)], fill=BROWN, outline=(60, 38, 20, 255), width=S)
            d.polygon([P(x, -6), P(x + 2.5, -10), P(x + 5, -6)], fill=BROWN)
        d.line([P(-1, -9), P(2, -2), P(-2, 2), P(1, 9)], fill=GOLD, width=2 * S)
    elif kind == "range":
        d.arc([P(-11, -11), P(11, 11)], start=200, end=340, fill=GOLD, width=2 * S)
        for i in range(4):
            a = math.radians(205 + i * 40)
            x, y = 11 * math.cos(a), 11 * math.sin(a)
            d.ellipse([P(x - 1.2, y - 1.2), P(x + 1.2, y + 1.2)], fill=WHITE)
        d.line([P(-9, 7), P(7, 7)], fill=GOLD, width=2 * S)
        d.polygon([P(9, 7), P(4, 3), P(4, 11)], fill=GOLD)
        d.ellipse([P(-11, 4), P(-5, 10)], fill=GREEN)
    elif kind == "up":
        for dx in (-5, 5):
            d.line([P(dx, 9), P(dx, -6)], fill=WHITE, width=2 * S)
            d.polygon([P(dx, -10), P(dx - 4, -4), P(dx + 4, -4)], fill=WHITE)
        d.arc([P(-12, 0), P(0, 12)], start=180, end=360, fill=(150, 190, 255, 255), width=S)
    elif kind == "roots":
        # a root pulled down quickly: the root, and fast chevrons beside it
        rc = (170, 120, 70, 255)
        d.ellipse([P(-10, -11), P(0, -4)], fill=(110, 160, 60, 255))           # (a little green crown on top)
        d.line([P(-5, -5), P(-5, 0)], fill=rc, width=3 * S)
        d.line([P(-5, 0), P(-9, 3), P(-12, 4)], fill=rc, width=2 * S, joint="curve")
        d.line([P(-5, 0), P(-7, 6), P(-6, 10)], fill=rc, width=2 * S, joint="curve")
        d.line([P(-5, 0), P(-2, 5), P(0, 7)], fill=rc, width=S, joint="curve")
        for dy in (-6, 2):
            d.line([P(3, dy - 3), P(7, dy + 1), P(11, dy - 3)], fill=GOLD, width=2 * S)
    elif kind == "mend":
        d.ellipse([P(-11, -3), P(11, 11)], fill=(60, 110, 60, 255))
        d.rectangle([P(-2.5, -10), P(2.5, 6)], fill=GREEN)
        d.rectangle([P(-8, -4.5), P(8, 0.5)], fill=GREEN)
    return im.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    for name, (portrait, kind) in ICON_LIST.items():
        base = Image.open(os.path.join(ICONS, portrait + ".png")).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
        base = ImageEnhance.Brightness(base).enhance(0.8)      # (the badge reads over it)
        out = Image.alpha_composite(base, badge(kind))
        out.save(os.path.join(ICONS, name + ".png"))
        print("wrote", name)


if __name__ == "__main__":
    main()
