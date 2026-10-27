#!/usr/bin/env python3
"""Round 13 icons (2026-10-27): the ChatGPT sheets for the TO DRAW list of
docs/command_icons_audit.md, in art/ui/icons3/ (names in reading order, row by row):

  portraits_clockwork_a.png  2x2, steel portrait frames: clock_soldier, jack, cuckoo (the Swift), ticking_owl
  portraits_clockwork_b.png  3+2: pendulum, netter, winder, spring_catapult, great_winder
  commands_crown.png         3x2, steel: ab_bombard, horse_team, more, ab_restock, ab_auto_refit, ab_mortar_deploy
  commands_clockwork.png     3x3, bronze: back, cancel, demolish, (hold: turned down, redrawn later),
                             patrol, rally, work, more, ab_bombard
  abilities_clockwork.png    3x3, bronze: ab_gear_small, ab_gear_big, ab_jump, ab_morph_owl,
                             research_high_leap, research_ticking_owl, ab_shield, research_shield,
                             tension (the top bar's Tension, frameless)
  commands_brood_a.png       3x2, bronze: back, cancel, demolish, (hold: turned down), patrol, rally
  commands_brood_b.png       3x2, bronze: work, more, ab_tongue, ab_take_off, ab_spit, ab_bombard

Steel sheets: cut and framed exactly like round 11's (the picture inside the frame's black
line, made square, box-shrunk to 52x52, set in the Crown icons' 6 px steel bevel) ->
assets/icons/<name>.png. Bronze sheets: the picture inside the frame (where the navy ground
starts), its ground shifted to the faction's, made square and set in the faction's own frame
(the per-pixel median of its six command icons, assets/icons/<faction>/{move,attack,...}.png,
like round 11's Brood abilities), so every Brood / Clockwork button has the very same frame ->
assets/icons/<faction>/<name>.png. Tension: the picture alone, its dark ground made
transparent (drawn small in the top bar's Tension pill) -> assets/icons/tension.png.

Usage (from the repo root): python3 tools/import_round13.py [--contact FILE]. Re-runnable;
run after import_round11.py / import_command_icons.py (tools/rebuild_art.sh). Then
godot --headless --import."""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
_argv = sys.argv[:]
import import_round11 as r  # noqa: E402

SRC = "art/ui/icons3"
STEEL = {
    "portraits_clockwork_a": ["clock_soldier", "jack", "cuckoo", "ticking_owl"],
    "portraits_clockwork_b": ["pendulum", "netter", "winder", "spring_catapult", "great_winder"],
    "commands_crown": ["ab_bombard", "horse_team", "more", "ab_restock", "ab_auto_refit", "ab_mortar_deploy"],
}
BRONZE = {
    "commands_clockwork": ("clockwork", ["back", "cancel", "demolish", None, "patrol", "rally", "work", "more",
                                         "ab_bombard"]),
    "abilities_clockwork": ("clockwork", ["ab_gear_small", "ab_gear_big", "ab_jump", "ab_morph_owl",
                                          "research_high_leap", "research_ticking_owl", "ab_shield",
                                          "research_shield", "tension"]),
    "commands_brood_a": ("brood", ["back", "cancel", "demolish", None, "patrol", "rally"]),
    "commands_brood_b": ("brood", ["work", "more", "ab_tongue", "ab_take_off", "ab_spit", "ab_bombard"]),
}
# the steel bevel: round 11 took it from three hand-painted icons (the pikeman's is gone); these
# three were framed with that very bevel (round 11 and import_command_icons.py)
r.RING_REFS = ("musketeer", "hold", "back")
FRAMELESS = {"tension"}          # top-bar pictures: no frame, transparent ground
CMDS = ["move", "attack", "stop", "build", "gather", "repair"]

# Portrait frames drawn taller than wide: (share of the excess cropped, where: 0 top .. 1 bottom);
# the rest is padded with the picture's own ground (round 11's FIT)
r.FIT.update({
    "clock_soldier": (0.6, 0.3), "jack": (0.6, 0.3), "cuckoo": (0.6, 0.5), "ticking_owl": (0.6, 0.4),
    "pendulum": (0.4, 0.4), "winder": (0.6, 0.4),
})


def faction_frame(fac):
    """The faction's frame as an overlay (round 11's brood_frame, for either faction): the
    per-pixel median of its six command icons where they agree and aren't the navy ground,
    within 11 px of the edge; the opening (y0, y1, x0, x1) inside it; the ground colour."""
    A = np.stack([np.array(Image.open(f"assets/icons/{fac}/{n}.png").convert("RGB")).astype(float) for n in CMDS])
    med = np.median(A, 0)
    cons = A.std(0).mean(-1) < 14
    N = r.ICON
    yy, xx = np.mgrid[0:N, 0:N]
    edge = np.minimum(np.minimum(yy, xx), np.minimum(N - 1 - yy, N - 1 - xx))
    mask = (cons & ~r.navyish(med) & (edge <= 11)) | (edge <= 4)
    mid = N // 2
    row, col = mask[mid], mask[:, mid]
    x0 = int(np.flatnonzero(~row[:mid]).min())
    x1 = mid + int(np.flatnonzero(~row[mid:]).max()) + 1
    y0 = int(np.flatnonzero(~col[:mid]).min())
    y1 = mid + int(np.flatnonzero(~col[mid:]).max()) + 1
    inside = np.zeros_like(mask)
    inside[y0:y1, x0:x1] = True
    bgc = np.median(med[inside & ~mask & r.navyish(med) & cons], 0)
    return med.round().astype(np.uint8), mask, (y0, y1, x0, x1), bgc


def square_rgba(pic, name):
    return r.square(pic, name)


def bronze_icon(crop, name, frame):
    med, mask, (y0, y1, x0, x1), bgc = frame
    pic = r.rebackdrop(r.brass_inner(crop), bgc)
    pic = square_rgba(pic, name)
    h, w = y1 - y0, x1 - x0
    im = Image.fromarray(pic[..., :3].astype(np.uint8), "RGB").resize((w, h), Image.BOX)
    im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    icon = np.zeros((r.ICON, r.ICON, 4), np.uint8)
    icon[..., 3] = 255
    icon[..., :3] = bgc.round().astype(np.uint8)
    icon[y0:y1, x0:x1, :3] = np.array(im)
    icon[mask, :3] = med[mask]
    return icon


def frameless_icon(crop, name):
    """The picture inside the frame on a transparent ground: pixels near the dark ground
    fade out (the darker and the nearer its hue, the more), the rest stays."""
    pic = square_rgba(r.brass_inner(crop), name)
    im = Image.fromarray(pic[..., :3].astype(np.uint8), "RGB").resize((r.ICON, r.ICON), Image.BOX)
    im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    rgb = np.array(im).astype(float)
    ground = r.backdrop(pic)[:3].astype(float)
    dist = np.abs(rgb - ground).max(-1)
    alpha = np.clip((dist - 10.0) / 40.0, 0, 1)
    icon = np.zeros((r.ICON, r.ICON, 4), np.uint8)
    icon[..., :3] = rgb.round().astype(np.uint8)
    icon[..., 3] = (alpha * 255).round().astype(np.uint8)
    return icon


def build():
    made = []
    for sheet, names in STEEL.items():
        px = r.load(f"{SRC}/{sheet}.png")
        bg, _ = r.bg_mask(px)
        for name, sl in zip(names, r.frame_boxes(px, bg, len(names))):
            oy0, oy1, ox0, ox1 = r.outer_edges(bg, sl)
            iy0, iy1, ix0, ix1 = r.inner_box(px, oy0, oy1, ox0, ox1)
            pic = px[iy0:iy1, ix0:ix1].copy()
            r.save_icon(r.framed(r.shrink(r.square(pic, name), r.INNER)), name)
            made.append(name)
            print(f"icons/{name}.png: frame {ox1 - ox0}x{oy1 - oy0} at ({ox0}, {oy0}), picture {ix1 - ix0}x{iy1 - iy0}")
    frames = {}
    for sheet, (fac, names) in BRONZE.items():
        if fac not in frames:
            frames[fac] = faction_frame(fac)
        px = r.load(f"{SRC}/{sheet}.png")
        bg, _ = r.bg_mask(px)
        for name, sl in zip(names, r.frame_boxes(px, bg, len(names))):
            if name is None:
                continue
            crop = r.brass_crop(px, bg, sl)
            if name in FRAMELESS:
                icon = frameless_icon(crop, name)
                Image.fromarray(icon, "RGBA").save(f"assets/icons/{name}.png")
                made.append(name)
                print(f"icons/{name}.png: frameless, from {crop.shape[1]}x{crop.shape[0]}")
                continue
            r.save_icon(bronze_icon(crop, name, frames[fac]), f"{fac}/{name}")
            made.append(f"{fac}/{name}")
            print(f"icons/{fac}/{name}.png: from {crop.shape[1]}x{crop.shape[0]} at ({sl[1].start}, {sl[0].start})")
    return made


def contact(path, names, k=2, cols=9):
    cw, ch = r.ICON * k + 12, r.ICON * k + 24
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cw * cols + 8, ch * rows + 8), (24, 32, 48))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        im = Image.open(f"assets/icons/{n}.png").convert("RGBA").resize((r.ICON * k, r.ICON * k), Image.NEAREST)
        x, y = 8 + (i % cols) * cw, 8 + (i // cols) * ch
        sheet.paste(im, (x, y), im)
        d.text((x, y + r.ICON * k + 4), n, fill=(255, 255, 255))
    sheet.save(path)


def main():
    made = build()
    if "--contact" in _argv:
        old = ["clockwork/" + c for c in CMDS[:3]] + ["brood/" + c for c in CMDS[:3]] + ["attack", "hold", "musketeer"]
        contact(_argv[_argv.index("--contact") + 1], old + made)


if __name__ == "__main__":
    main()
