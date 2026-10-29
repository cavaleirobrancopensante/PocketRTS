#!/usr/bin/env python3
"""The Mist Toad's hop (its walk in every view) from the owner's ChatGPT sheets.

Sources: art/redraws/mist_toad_hop_<dir>_chatgpt.png, dir = s, se, e, ne, n (west is the east
views mirrored in code). One row of 6 frames on a flat navy background:
    1 crouched   2 pushing off   3 stretched in the air   4 top of the hop
    5 coming down (arms reaching for the ground)   6 landed, with a small splash

What this does
  - cuts each frame off the background (a flood from the border through the navy, as
    import_art.flat_flood_mask); stray specks far from a toad are dropped, the splash
    drops near frame 6 stay with it
  - the GROUND: a line through the feet of frames 1 and 6 (the lowest row of the body
    without the splash, under its centre). ChatGPT drew some rows on a slope (the SE
    row lands 42 sheet px lower than it took off), so each frame's own ground point is
    the line under its body centre: frames 1 and 6 stand on the anchor and the hop
    rises and lands on the same spot
  - each frame keeps the height ChatGPT drew it at over that line, scaled per view so
    the top of the hop (frame 4) is TOP_LIFT px over the ground at game size in every
    view (the sheets drew it 25 to 39 px up at game size, the back views highest; 20 px
    is under half the toad's height: a heavy toad's hop)
  - side to side, every frame is centred on its body's centre of mass
  - scaled per view so the crouched toad covers as many pixels as its idle in that view
    (the current game size: idle_e/s/se/n; NE takes the mean of SE and N, same sheet size)
  - team colour: import_art.snap_team (the red spines become the two key reds, as for
    every Brood import), then the spines' shaded and highlit reds touching them too
    (team_spines; tools/anim_audit/fix_brood.py then snaps the last fringes)

Writes assets/units/mist_toad/walk_<dir>.png (6 frames each; replaces the 14-frame
side-on walk_e) and grows the toad's shared cell when the hop needs more room above
(the other strips are re-padded around the same anchor, so nothing else moves); the
"mist_toad" entry of scripts/art_data.gd is updated in place. The game plays the
frames by the distance walked (scripts/toad_hop.gd), not by time.

Run after tools/import_mist_toad.py (which writes the cell this pads), then
tools/anim_audit/fix_brood.py and tools/import_vet_skin.py --only mist_toad.
Usage (repo root): python3 tools/import_toad_hop.py [--contact DIR]
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402

NAME = "mist_toad"
DIRS = ["s", "se", "e", "ne", "n"]
SHEET = "art/redraws/mist_toad_hop_%s_chatgpt.png"
UNIT_DIR = "assets/units/" + NAME
TOP_LIFT = 20.0         # game px: the feet at the top of the hop (frame 4) over the ground
# the idle strip each view's crouch is sized against (frame 0's pixel count)
SIZE_REF = {"s": "idle_s", "se": "idle_se", "e": "idle_e", "n": "idle_n"}


def entry():
    src = open("scripts/art_data.gd").read()
    m = re.search(r'\t"%s": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\), "frames": \{(.*?)\n\t\}\},\n' % NAME, src, re.S)
    return {"cell": (int(m[1]), int(m[2])), "anchor": (int(float(m[3])), int(float(m[4]))),
            "frames": {k: int(v) for k, v in re.findall(r'"(\w+)": (\d+)', m[5])}}


def write_entry(cell, anchor, frames):
    path = "scripts/art_data.gd"
    src = open(path).read()
    lines = [f'\t"{NAME}": {{"cell": Vector2i({cell[0]}, {cell[1]}), "anchor": Vector2({anchor[0]}, {anchor[1]}), "frames": {{\n']
    for k in sorted(frames):
        lines.append(f'\t\t"{k}": {frames[k]},\n')
    lines.append("\t}},\n")
    pat = re.compile(r'\t"' + NAME + r'": \{.*?\n\t\}\},\n', re.S)
    src = pat.sub(lambda m: "".join(lines), src, count=1)
    open(path, "w").write(src)


def strip_frames(key, n):
    a = np.array(Image.open(f"{UNIT_DIR}/{key}.png").convert("RGBA"))
    w = a.shape[1] // n
    return [a[:, i * w:(i + 1) * w] for i in range(n)]


def area_of(img):
    return int((img[..., 3] > 0).sum())


def team_spines(img):
    """import_art.snap_team, then the spines' shaded and highlit reds next to the key reds (snap_team leaves the dark
    and pinkish ones: they showed as red specks on a blue team's spines) become the keys too. Reddish skin spots away
    from the spines stay as painted."""
    img = ia.snap_team(img)
    r, g, b = (img[..., i].astype(int) for i in range(3))
    on = img[..., 3] > 0
    key = on & (g == 0) & (b == 0) & ((r == 255) | (r == 150))
    reddish = on & ~key & (r > 80) & (r > g * 1.6) & (r > b * 1.6)
    grow = key.copy()
    for _ in range(3):
        grow |= ndimage.binary_dilation(grow) & reddish
    add = grow & ~key
    light = add & (r >= 175)
    img[light, :3] = ia.TEAM_LIGHT
    img[add & ~light, :3] = ia.TEAM_DARK
    return img


def body_of(mask):
    """The toad without the splash or loose drops: opened, the biggest piece, grown back inside the mask."""
    core = ndimage.binary_opening(mask, iterations=6)
    lab, n = ndimage.label(core)
    if n == 0:
        return mask
    sizes = ndimage.sum(core, lab, range(1, n + 1))
    big = lab == (int(np.argmax(sizes)) + 1)
    return ndimage.binary_dilation(big, iterations=7) & mask


def cut_sheet(d):
    px = ia.load(SHEET % d)
    fg = ia.flat_flood_mask(px)
    # (components: pieces under 25 px are dropped, bigger ones join a toad within 30 px or go)
    sprites = ia.components(fg, 3, min_big=3000, attach_dist=30)
    sprites.sort(key=lambda s: s["cx"])
    if len(sprites) != 6:
        sys.exit(f"{SHEET % d}: {len(sprites)} frames, expected 6")
    out = []
    for s in sprites:
        img = ia.cutout(px, s)
        m = img[..., 3] > 0
        body = body_of(m)
        ys, xs = np.nonzero(body)
        cx = float(xs.mean())
        # the feet: the lowest body rows near the centre (claws stuck out to a side don't count)
        near = np.abs(xs - cx) <= (xs.max() - xs.min()) * 0.4
        bot = float(ys[near].max())
        # splash and drops (frame 6) stay; anything else not touching the body (a stray speck) goes
        if len(out) < 5:
            img[~body] = 0
        out.append({"img": img, "x0": s["x0"], "y0": s["y0"], "cx": s["x0"] + cx, "bot": s["y0"] + bot,
                    "area": int(body.sum())})
    return out


def main():
    u = entry()
    W0, H0 = u["cell"]
    ax0, ay0 = u["anchor"]
    frames = dict(u["frames"])
    # the current strips, every one but the walks this replaces
    keep = {k: strip_frames(k, n) for k, n in frames.items() if not k.startswith("walk_")}
    ref = {d: area_of(keep[k][0]) for d, k in SIZE_REF.items() if k in keep}
    hop = {}
    scales = {}
    for d in DIRS:
        fr = cut_sheet(d)
        g1, g6 = fr[0], fr[5]
        slope = (g6["bot"] - g1["bot"]) / max(1.0, g6["cx"] - g1["cx"])

        def ground(x, g1=g1, slope=slope):
            return g1["bot"] + (x - g1["cx"]) * slope
        if d in ref:
            scales[d] = (ref[d] / fr[0]["area"]) ** 0.5
        else:
            scales[d] = None
        hop[d] = (fr, ground)
    for d in DIRS:
        if scales[d] is None:
            got = [scales[k] for k in ("se", "n") if scales.get(k)]
            scales[d] = float(np.mean(got))
    small = {}
    for d in DIRS:
        fr, ground = hop[d]
        s = scales[d]
        lst = []
        drawn = [ground(f["cx"]) - f["bot"] for f in fr]      # sheet px over the ground line
        k = TOP_LIFT / (max(drawn) * s)                       # every view tops out at TOP_LIFT
        lifts = []
        for f, up in zip(fr, drawn):
            ay = f["bot"] + k * up                            # the ground point under this frame
            im = team_spines(ia.shrink(f["img"], s))
            lst.append((im, (f["cx"] - f["x0"]) * s, (ay - f["y0"]) * s))
            lifts.append(k * up * s)
        small[d] = lst
        print(f"  {d}: scale {s:.3f}, ground slope {(fr[5]['bot'] - fr[0]['bot']):+.0f} sheet px, "
              f"lift " + " ".join(f"{v:.0f}" for v in lifts) + " px")
    # the cell: as before, grown to fit every hop frame round the anchor
    L, R, U, D = ax0, W0 - ax0, ay0, H0 - ay0
    for lst in small.values():
        for im, fx, fy in lst:
            L = max(L, int(np.ceil(fx)) + 1)
            R = max(R, int(np.ceil(im.shape[1] - fx)) + 1)
            U = max(U, int(np.ceil(fy)) + 1)
            D = max(D, int(np.ceil(im.shape[0] - fy)) + 1)
    half = max(L, R)
    W, H, ax, ay = 2 * half, U + D, half, U
    dx, dy = ax - ax0, ay - ay0
    for k, lst in keep.items():
        strip = np.zeros((H, W * len(lst), 4), np.uint8)
        for i, im in enumerate(lst):
            strip[dy:dy + H0, i * W + dx:i * W + dx + W0] = im
        if (W, H) != (W0, H0):
            ia.save(strip, f"{UNIT_DIR}/{k}.png")
    for k in [k for k in frames if k.startswith("walk_")]:
        del frames[k]
    for d, lst in small.items():
        strip = np.zeros((H, W * len(lst), 4), np.uint8)
        for i, (im, fx, fy) in enumerate(lst):
            ox, oy = int(round(ax - fx)), int(round(ay - fy))
            h, w = im.shape[:2]
            m = im[..., 3] > 0
            strip[oy:oy + h, i * W + ox:i * W + ox + w][m] = im[m]
        ia.save(strip, f"{UNIT_DIR}/walk_{d}.png")
        frames[f"walk_{d}"] = len(lst)
    write_entry((W, H), (ax, ay), frames)
    print(f"  {NAME}: cell {W0}x{H0} -> {W}x{H}, anchor ({ax0}, {ay0}) -> ({ax}, {ay}); walk_s/se/e/ne/n 6 frames")
    if "--contact" in sys.argv:
        contact(sys.argv[sys.argv.index("--contact") + 1], W, H, ay)


def contact(out_dir, W, H, ay):
    """Five rows (s, se, e, ne, n) of the hop at game size, the ground line in each cell (and x3)."""
    os.makedirs(out_dir, exist_ok=True)
    rows = []
    for d in DIRS:
        a = np.array(Image.open(f"{UNIT_DIR}/walk_{d}.png").convert("RGBA"))
        n = a.shape[1] // W
        row = np.zeros((H, n * (W + 2), 4), np.uint8)
        row[..., :3] = (96, 112, 72)
        row[..., 3] = 255
        for i in range(n):
            cell = row[:, i * (W + 2):i * (W + 2) + W]
            cell[ay, :, :3] = (70, 84, 52)
            f = a[:, i * W:(i + 1) * W]
            m = f[..., 3] > 0
            cell[m] = f[m]
        rows.append(row)
    sheet = np.concatenate(rows, 0)
    Image.fromarray(sheet).save(f"{out_dir}/hop_contact.png")
    Image.fromarray(sheet).resize((sheet.shape[1] * 3, sheet.shape[0] * 3), Image.NEAREST).save(f"{out_dir}/hop_contact_x3.png")
    print(f"  contact sheets: {out_dir}/hop_contact.png (game size), hop_contact_x3.png")


if __name__ == "__main__":
    main()
