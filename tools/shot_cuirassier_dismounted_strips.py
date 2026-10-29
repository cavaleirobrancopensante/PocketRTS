#!/usr/bin/env python3
"""Pictures of the dismounted Cuirassier's strips (assets/units/dismounted_armoured, tools/import_cuirassier_dismounted.py),
old against new, into docs/shots/cuirassier_dismounted/:

  directions_old_new.png   the first idle frame in the eight directions (west = east mirrored), old row over new, x4,
                           on one ground line (the yellow line: the cell's ground row)
  compare_game_size.png    Musketeer | OLD | NEW | Cuirassier (idle, south-east) at x2, red team and blue team
  compare_4x.png           the same at x4
  strips_<dir>_old_new.png every strip of a direction, old over new, x3
  melee_death_old_new.png  each direction's sword attack and death, old (top) and new (bottom), x3
  melee_death.gif          the new sword attack (timed as the game plays it: Unit.MELEE_HIT) and death, five
                           directions side by side, x2

Usage (repo root): python3 tools/shot_cuirassier_dismounted_strips.py OLD_DIR
OLD_DIR holds the old strips (<anim>_<dir>.png), e.g. from
  git archive -o old.tar da421605^ assets/units/dismounted_armoured   (then tar -xf old.tar)."""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ART = "assets/units/dismounted_armoured/"
OUT = "docs/shots/cuirassier_dismounted/"
DIRS = ["s", "se", "e", "ne", "n"]
EIGHT = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
MIRROR = {"sw": "se", "w": "e", "nw": "ne"}
BG = (104, 132, 84, 255)
CW = 90
BLUE_LIGHT, BLUE_DARK = (60, 110, 230), (30, 55, 140)
AIM, STRIKE, HIT = 0.2, 0.35, 3          # Defs.BAYONET "aim", Unit._strike_time, Unit.MELEE_HIT


def frames(path):
    s = np.asarray(Image.open(path).convert("RGBA"))
    n = s.shape[1] // CW
    return [s[:, i * CW:(i + 1) * CW] for i in range(n)]


def frame_of(base, anim, d, i=0):
    src = MIRROR.get(d, d)
    f = frames(os.path.join(base, "%s_%s.png" % (anim, src)))[i]
    return f[:, ::-1] if d in MIRROR else f


def pad_to(f, h):
    """Extra rows on top (the feet stay on the bottom rows, as the game draws a taller strip)."""
    return np.pad(f, ((h - f.shape[0], 0), (0, 0), (0, 0))) if f.shape[0] < h else f


def blue(f):
    """Team reds (import_art.snap_team's test: the old art's reds are not the exact keys) to blue, by brightness."""
    f = f.copy()
    r, g, b = f[..., 0].astype(int), f[..., 1].astype(int), f[..., 2].astype(int)
    red = (f[..., 3] > 0) & (r >= 100) & (g <= r * 0.3) & (b <= r * 0.32)
    k = (r / 255.0)[..., None]
    f[red, :3] = (np.array(BLUE_LIGHT) * k[red]).clip(0, 255).astype(np.uint8)
    return f


def paste(sheet, f, x, y, z):
    im = Image.fromarray(np.ascontiguousarray(f))
    sheet.alpha_composite(im.resize((im.width * z, im.height * z), Image.NEAREST), (x, y))


def directions(old):
    z, lw, H = 4, 120, 48
    sheet = Image.new("RGBA", (lw + 8 * 60 * z, 2 * H * z + 16), BG)
    dr = ImageDraw.Draw(sheet)
    for r, (name, base) in enumerate((("OLD", old), ("NEW", ART))):
        y = r * (H * z + 16)
        dr.text((6, y + H * z // 2), "%s  %s" % (name, " ".join(EIGHT)), fill=(255, 255, 255, 255))
        for i, d in enumerate(EIGHT):
            f = pad_to(frame_of(base, "idle", d), H)[:, 15:75]
            paste(sheet, f, lw + i * 60 * z, y, z)
        gy = y + (H - 2) * z
        dr.line([(lw, gy), (sheet.width, gy)], fill=(255, 255, 0, 120))
    sheet.save(OUT + "directions_old_new.png")


def game_size(old, z=2, name="compare_game_size.png"):
    musk = frames("assets/units/musketeer/idle_se.png")[0]
    cui = frames_w("assets/units/cuirassier/idle_se.png", 98)[0]
    o = frame_of(old, "idle", "se")
    n = frame_of(ART, "idle", "se")
    # one ground line: every picture's ground row on the same screen row (the Cuirassier's cell: ground at 66 of 70)
    items = [(musk, 34), (o, 34), (n, 34), (cui, 66)]
    lw, H = 200, 72
    sheet = Image.new("RGBA", (lw + 4 * 60 * z, 2 * H * z + 8), BG)
    dr = ImageDraw.Draw(sheet)
    for r, label in enumerate(("Musketeer | OLD | NEW | Cuirassier", "the same, blue team")):
        y0 = r * (H * z + 8)
        dr.text((6, y0 + H * z // 2), label, fill=(255, 255, 255, 255))
        ground = y0 + (H - 4) * z
        for i, (f, g) in enumerate(items):
            f = f if r == 0 else blue(f)
            w = f.shape[1]
            crop = f[:, max(0, w // 2 - 30):w // 2 + 30]
            paste(sheet, crop, lw + i * 60 * z, ground - (g + 1) * z, z)
        dr.line([(lw, ground), (sheet.width, ground)], fill=(255, 255, 0, 90))
    sheet.save(OUT + name)


def strips(old):
    """strips_<dir>_old_new.png: every strip of a direction, old over new, x3."""
    z, H, lw = 3, 48, 80
    for d in DIRS:
        rows = []
        for anim in ("idle", "walk", "aim", "fire", "melee", "death"):
            for name, base in (("old " + anim, old), ("NEW " + anim, ART)):
                fs = [pad_to(f, H)[:, 10:80] for f in frames(os.path.join(base, "%s_%s.png" % (anim, d)))]
                rows.append((name, np.concatenate(fs, 1)))
        W = max(r.shape[1] for _n, r in rows)
        sheet = Image.new("RGBA", (lw + W * z, len(rows) * (H * z + 4)), BG)
        dr = ImageDraw.Draw(sheet)
        for i, (name, r) in enumerate(rows):
            y = i * (H * z + 4)
            dr.text((4, y + H * z // 2), name, fill=(255, 255, 255, 255))
            paste(sheet, r, lw, y, z)
            if i % 2 == 1:
                dr.line([(0, y + H * z + 2), (sheet.width, y + H * z + 2)], fill=(0, 0, 0, 120))
        sheet.save(OUT + "strips_%s_old_new.png" % d)


def frames_w(path, cw):
    s = np.asarray(Image.open(path).convert("RGBA"))
    return [s[:, i * cw:(i + 1) * cw] for i in range(s.shape[1] // cw)]


def melee_death(old):
    z, H, lw = 3, 48, 70
    rows = []
    for d in DIRS:
        for name, base in (("old " + d, old), ("NEW " + d, ART)):
            fs = [pad_to(f, H) for f in frames(os.path.join(base, "melee_%s.png" % d))]
            fs += [np.zeros((H, 20, 4), np.uint8)]
            fs += [pad_to(f, H) for f in frames(os.path.join(base, "death_%s.png" % d))]
            rows.append((name, np.concatenate([f[:, 10:80] if f.shape[1] == CW else f for f in fs], 1)))
    W = max(r.shape[1] for _n, r in rows)
    sheet = Image.new("RGBA", (lw + W * z, len(rows) * (H * z + 4)), BG)
    dr = ImageDraw.Draw(sheet)
    for i, (name, r) in enumerate(rows):
        y = i * (H * z + 4)
        dr.text((4, y + H * z // 2), name, fill=(255, 255, 255, 255))
        paste(sheet, r, lw, y, z)
        if i % 2 == 1:
            dr.line([(0, y + H * z + 2), (sheet.width, y + H * z + 2)], fill=(0, 0, 0, 120))
    sheet.save(OUT + "melee_death_old_new.png")


def gif():
    z, H = 2, 48
    melee = [frames(ART + "melee_%s.png" % d) for d in DIRS]
    death = [[pad_to(f, H) for f in frames(ART + "death_%s.png" % d)] for d in DIRS]
    n = len(melee[0])
    # (frame index, seconds): as Unit._animate plays a blow, then a rest on the guard; twice; then the death at 7 fps
    seq = [(i, AIM / HIT) for i in range(HIT)] + [(i, STRIKE / (n - HIT)) for i in range(HIT, n)] + [(n - 1, 0.4)]
    pics, durs = [], []

    def frame(cells):
        im = Image.new("RGBA", (len(DIRS) * 64 * z, H * z), BG)
        for k, c in enumerate(cells):
            paste(im, c[:, 13:77], k * 64 * z, 0, z)
        return im.convert("RGB").convert("P", palette=Image.ADAPTIVE, colors=64)

    for _rep in range(2):
        for i, t in seq:
            pics.append(frame([m[i] for m in melee]))
            durs.append(int(t * 1000))
    for i in range(len(death[0])):
        pics.append(frame([dd[i] for dd in death]))
        durs.append(int(1000 / 7.0) if i < len(death[0]) - 1 else 1500)
    pics[0].save(OUT + "melee_death.gif", save_all=True, append_images=pics[1:], duration=durs, loop=0, optimize=True)


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    old = os.path.abspath(sys.argv[1])
    os.makedirs(OUT, exist_ok=True)
    directions(old)
    game_size(old)
    game_size(old, 4, "compare_4x.png")
    strips(old)
    melee_death(old)
    gif()
    print("wrote", OUT)


if __name__ == "__main__":
    main()
