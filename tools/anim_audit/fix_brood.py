"""Technical fixes to the Brood's unit strips found by the animation audit (docs/animation_audit_brood.md).
Idempotent: every step checks the state first, so running it twice changes nothing. Runs in tools/rebuild_art.sh
after the gait passes (import_gait_raptor.py) and before import_vet_skin.py (the skin masks are made from these
strips, so run import_vet_skin.py after it).

1. Feet on the ground: the Raptor's and the Grub's walk_s / se / ne / n (the 2026-10-24 redraw, placed one row above
   the anchor and then shortened by the gait pass) stood 2 px above the anchor, while every other strip of theirs
   (walk_e, idle, attack, death) stands on it: the creature hopped 2 px up whenever it turned up or down the screen
   and dropped again when it stopped. The strip is moved down so its median sole row is the anchor's row.
2. The Skywing's attack_e frame 1 was a broken cut (only one wing and the tail, no body): the frame is replaced by
   frame 3 (wing raised), so the volley plays raised, strike, raised.
3. The Queen's crest and the Clutch Mound's frills were painted in plain reds (only 6 and 44 pixels were the key
   reds), so they stayed red on a blue team: every red patch that touches a key red, or is 6 px or more, becomes the
   key (255,0,0 where it is bright, 150,0,0 where it is dark). (The Queen's sprite also gets the team material in
   scripts/building_life.gd: before, even her key reds were drawn plain red.)
4. Team colour fringes: pixels that are almost a key red (within 0.2 of (255,0,0) or (150,0,0), red-dominant) and touch
   a key red are snapped to the nearest key. Before, they stayed red on a blue team (a pinkish rim on crests and frills).

Usage (repo root): python3 tools/anim_audit/fix_brood.py [--dry]
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KINDS = ["grub", "raptor", "spitter", "brute", "skywing", "spore_mother", "bloater", "mist_toad"]
GROUND_FIX = {"raptor": ["walk_s", "walk_se", "walk_ne", "walk_n"], "grub": ["walk_s", "walk_se", "walk_ne", "walk_n"]}
DRY = "--dry" in sys.argv


def unit(kind):
    src = open(os.path.join(ROOT, "scripts/art_data.gd")).read()
    m = re.search(r'\t"%s": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\), "frames": \{(.*?)\n\t\}' % kind, src, re.S)
    return {"cell": (int(m[1]), int(m[2])), "anchor": (float(m[3]), float(m[4])),
            "frames": {k: int(v) for k, v in re.findall(r'"(\w+)": (\d+)', m[5])}}


def path(kind, key):
    return os.path.join(ROOT, "assets/units", kind, key + ".png")


def load(p):
    return np.array(Image.open(p).convert("RGBA"))


def save(p, a, what):
    print("  fixed", os.path.relpath(p, ROOT), what)
    if not DRY:
        Image.fromarray(a).save(p)


def ground(kind, key, u):
    a = load(path(kind, key))
    n = u["frames"][key]
    w = a.shape[1] // n
    bots = []
    for i in range(n):
        rows = np.nonzero((a[:, i * w:(i + 1) * w, 3] > 0).any(1))[0]
        bots.append(int(rows[-1]))
    target = int(u["anchor"][1]) + (a.shape[0] - u["cell"][1])
    dy = target - int(np.median(bots))
    if dy <= 0:
        return
    if max(bots) + dy > a.shape[0] - 1:
        dy = a.shape[0] - 1 - max(bots)
    if dy <= 0:
        return
    out = np.zeros_like(a)
    out[dy:] = a[:-dy]
    save(path(kind, key), out, "moved down %d px (soles on the anchor row)" % dy)


def skywing_attack():
    p = path("skywing", "attack_e")
    a = load(p)
    w = a.shape[1] // 3
    f1 = a[:, :w]
    # the broken frame has well under half the body of the others
    if (f1[..., 3] > 40).sum() > 0.6 * (a[:, 2 * w:, 3] > 40).sum():
        return
    a = a.copy()
    a[:, :w] = a[:, 2 * w:3 * w]
    save(p, a, "frame 1 (a wing and the tail only) replaced by frame 3")


def snap_keys(p):
    a = load(p)
    rgb = a[..., :3].astype(float) / 255.0
    op = a[..., 3] > 0
    d1 = np.sqrt(((rgb - [1.0, 0.0, 0.0]) ** 2).sum(-1))
    d2 = np.sqrt(((rgb - [150 / 255.0, 0.0, 0.0]) ** 2).sum(-1))
    key = op & ((d1 < 0.08) | (d2 < 0.08))
    reddish = (rgb[..., 0] > rgb[..., 1] * 2.2) & (rgb[..., 0] > rgb[..., 2] * 2.2) & (rgb[..., 0] > 0.35)
    near = op & ~key & reddish & ((d1 < 0.2) | (d2 < 0.2)) & ndimage.binary_dilation(key, np.ones((3, 3), bool))
    if not near.any():
        return
    a = a.copy()
    hi = near & (d1 <= d2)
    lo = near & (d1 > d2)
    a[hi, :3] = [255, 0, 0]
    a[lo, :3] = [150, 0, 0]
    save(p, a, "%d near-key reds snapped to the key" % int(near.sum()))


TEAM_PAINT = ["assets/buildings/brood_queen.png", "assets/buildings/clutch_mound_built.png",
              "assets/buildings/clutch_mound_damaged.png", "assets/buildings/clutch_mound_destroyed.png"]


def team_paint(rel):
    p = os.path.join(ROOT, rel)
    a = load(p)
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    rgb = a[..., :3].astype(float) / 255.0
    d1 = np.sqrt(((rgb - [1.0, 0.0, 0.0]) ** 2).sum(-1))
    d2 = np.sqrt(((rgb - [150 / 255.0, 0.0, 0.0]) ** 2).sum(-1))
    key = (a[..., 3] > 0) & ((d1 < 0.08) | (d2 < 0.08))
    red = (a[..., 3] > 0) & (r > 70) & (r > 2.5 * g) & (r > 2.5 * b)
    lab, n = ndimage.label(red | key, np.ones((3, 3), bool))
    out = a.copy()
    cnt = 0
    for i in range(1, n + 1):
        c = lab == i
        if (c & key).any() or c.sum() >= 6:
            sel = c & ~key
            out[sel & (r >= 200), :3] = [255, 0, 0]
            out[sel & (r < 200), :3] = [150, 0, 0]
            cnt += int(sel.sum())
    if cnt:
        save(p, out, "%d painted reds made the team key" % cnt)


def main():
    for kind, keys in GROUND_FIX.items():
        u = unit(kind)
        for key in keys:
            ground(kind, key, u)
    skywing_attack()
    for rel in TEAM_PAINT:
        team_paint(rel)
    for kind in KINDS:
        for key in sorted(unit(kind)["frames"]):
            if os.path.exists(path(kind, key)):
                snap_keys(path(kind, key))


if __name__ == "__main__":
    main()
