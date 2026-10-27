"""Before/after GIFs of the Clockwork animation audit's fixes (docs/animation_audit_clockwork.md): the old picture comes
from git (BASE, default the audit's starting commit), the new one from the working tree. Top row before, bottom after,
at game speed, 3x (the Aviary 2x). Out: docs/shots/anim_audit_clockwork/fix_*.gif
  python3 tools/anim_audit/before_after.py [BASE]
"""
import io
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs/shots/anim_audit_clockwork")
BASE = sys.argv[1] if len(sys.argv) > 1 else "a9d1dac"
NAVY = (0, 22, 48)


def old(path):
    data = subprocess.run(["git", "-C", ROOT, "show", "%s:%s" % (BASE, path)], capture_output=True).stdout
    return np.array(Image.open(io.BytesIO(data)).convert("RGBA"))


def new(path):
    return np.array(Image.open(os.path.join(ROOT, path)).convert("RGBA"))


def cells(im, cw):
    return [im[:, i * cw:(i + 1) * cw] for i in range(im.shape[1] // cw)]


def gif(rows_before, rows_after, ms, name, scale=3, label=("before", "after"), plate=False):
    """rows_*: one frame list per view, side by side; ms: ms a frame. plate: draw the anchor column (a cyan tick)."""
    n = max(len(r) for r in rows_before)
    cw = rows_before[0][0].shape[1]
    ch = rows_before[0][0].shape[0]
    W = cw * len(rows_before) * scale
    H = (ch * scale + 14) * 2
    frames = []
    for t in range(n):
        im = Image.new("RGB", (W, H), NAVY)
        d = ImageDraw.Draw(im)
        for r, rows in enumerate((rows_before, rows_after)):
            y = r * (ch * scale + 14)
            d.text((4, y + 1), label[r], fill=(255, 255, 255))
            for v, fr in enumerate(rows):
                f = fr[t % len(fr)]
                p = Image.fromarray(f).resize((cw * scale, ch * scale), Image.NEAREST)
                im.paste(p, (v * cw * scale, y + 14), p)
                if plate:
                    x = v * cw * scale + plate * scale
                    d.line((x, y + 14 + (ch - 3) * scale, x, y + 14 + ch * scale - 1), fill=(0, 220, 255))
        frames.append(im)
    frames[0].save(os.path.join(OUT, name), save_all=True, append_images=frames[1:], duration=ms, loop=0, optimize=True)
    print(name)


def strips(kind, anims, dirs, cw):
    b, a = [], []
    for an in anims:
        for d in dirs:
            p = "assets/units/%s/%s_%s.png" % (kind, an, d)
            b.append(cells(old(p), cw))
            a.append(cells(new(p), cw))
    return b, a


def main():
    # the Jack: its idle wandered sideways on its foot plate, its two-launcher strips stood off the anchor
    b, a = strips("jack", ["idle"], ["s", "se", "e", "ne", "n"], 108)
    gif(b, a, 500, "fix_jack_idle.gif", 3, plate=54)
    # idle -> attack_r -> walk, the S and N views, to show the switch no longer jumps
    for d in ("s", "n"):
        seq_b = cells(old("assets/units/jack/idle_%s.png" % d), 108)[:2] + cells(old("assets/units/jack/attack_r_%s.png" % d), 108) + \
            cells(old("assets/units/jack/walk_%s.png" % d), 108)
        seq_a = cells(new("assets/units/jack/idle_%s.png" % d), 108)[:2] + cells(new("assets/units/jack/attack_r_%s.png" % d), 108) + \
            cells(new("assets/units/jack/walk_%s.png" % d), 108)
        gif([seq_b], [seq_a], 160, "fix_jack_switch_%s.gif" % d, 3, plate=54)
    # the Clock Soldier's E attack: the overhead frame had no cap (no player colour)
    b, a = strips("clock_soldier", ["attack"], ["e"], 78)
    gif(b, a, 111, "fix_clock_soldier_attack_e.gif", 4)
    # specks
    b, a = strips("clock_soldier", ["walk", "guard_walk", "guard"], ["ne", "s", "e"], 78)
    gif(b, a, 100, "fix_specks_clock_soldier.gif", 3)
    b, a = strips("pendulum", ["attack_l", "attack_r"], ["n", "se"], 130)
    gif(b, a, 111, "fix_specks_pendulum.gif", 2)
    # the Clock Aviary's working loop
    pb = [old("assets/buildings/cuckoo_house_work_%d.png" % i) for i in range(4)]
    pa = [new("assets/buildings/cuckoo_house_work_%d.png" % i) for i in range(4)]
    built = new("assets/buildings/cuckoo_house_built.png")
    gif([[built] + pb + [built]], [[built] + pa + [built]], 150, "fix_aviary_work.gif", 2, label=("before (built, work 0-3, built)", "after"))


if __name__ == "__main__":
    main()
