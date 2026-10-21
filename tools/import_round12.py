"""Round 12 art: the Clockwork rework - Thresher, Bulwark, Wind-up Soldier and the Engine
Hall, plus the bigger Clockwork footprints (Assembly Works 5x4, Boiler 4x4).

Sources (generated sheets on a flat dark slate background, header and row labels blanked):
  art/clockwork/thresher.png        1536x1024, rows s, se, e, ne, n; groups WALK 6 / IDLE 3 /
        SPIN-UP 3 / ATTACK 4 / DRAINED 2 / DEATH 5. The bottom strip (saw spin, debris) is
        not used.
  art/clockwork/bulwark.png         1536x1024, rows s..n; groups WALK 6 / IDLE 3 / BRACE 4 /
        BRACED HIT 4 / ATTACK 3 / DEATH 5. The "back view (no battery)" strip is not used.
  art/clockwork/windup_soldier.png  1536x1024, rows s..n; groups WALK 6 / IDLE 3 / ATTACK 5 /
        RUN-DOWN 3 / WIND-UP 3 / DEATH 5. The key close-ups and death details are not used.
  art/clockwork/engine_hall.png     1774x887, one row: built, construction, damaged,
        destroyed.

Cutting: each sheet's group brackets (the light lines under the header) give the groups'
x ranges, split halfway between brackets. Inside a group the n frames are found from the
"thick" column runs (the bodies); frames drawn touching (a spear, a saw or a shield edge
reaching the next figure) are cut at the emptiest column between two bodies, ties to the
right, so a weapon stays with the figure that holds it; every connected piece that lies
mostly (80%) in one frame goes whole to it (round 4's rule). When the bodies can't be told
apart (debris, smoke in the death frames) the round 4 column cuts are used.

Frames go through round 4's to_game (slate mask, box-filter shrink, team reds snapped to
#FF0000 / #960000, slate fringe and specks removed); death smoke is un-blended from the
slate as light (grey, low chroma). One scale per sheet: the idle frames' median figure
height is the target (Thresher and Bulwark: the Gearknight / Arc Thrower size, Wind-up
Soldier about two thirds of a musketeer). Feet on one anchor per kind (round 4 steady).

Output:
  assets/units/{thresher,bulwark,windup_soldier}/<anim>_<dir>.png
      thresher: walk, idle, spinup, attack, drained, death
      bulwark: walk, idle, brace, braced_hit, attack, death
      windup_soldier: walk, idle, attack, rundown, windup, death
  assets/buildings/engine_hall_{built,construction,damaged,destroyed}.png
  assets/buildings/{assembly_works,boiler}_*.png re-cut at the bigger footprint's width
  their UNITS / BUILDING_SIZE entries in scripts/art_data.gd (added or replaced in place).
  Icons are not made here (assets/icons/{thresher,bulwark,windup_soldier,engine_hall}.png
  are drawn separately).

Order (tools/rebuild_art.sh): after import_art.py and import_round10.py, before
make_packs.py (none of these three carries a separate pack: their cells are drawn on).

Usage (from the repo root): python3 tools/import_round12.py [--contact DIR] [--only KINDS]
Needs Pillow, NumPy and SciPy. Re-runnable.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv, sys.argv = sys.argv, sys.argv[:1]          # round 4 / 10 read their own flags
import import_round4 as r4  # noqa: E402
import import_round10 as r10  # noqa: E402
sys.argv = _argv
import import_art as ia  # noqa: E402
from import_cannon2 import bg_mask, clean  # noqa: E402
from import_round4 import F, steady  # noqa: E402

DIRS = ["s", "se", "e", "ne", "n"]
CONTACT = _argv[_argv.index("--contact") + 1] if "--contact" in _argv else None
ONLY = _argv[_argv.index("--only") + 1] if "--only" in _argv else ""

# kind: source, label boxes to blank, groups (name, frames) in sheet order, figure height
# in game px (idle frames, top of the head to the soles), how each group is steadied.
SHEETS = {
    "thresher": dict(
        path="art/clockwork/thresher.png", blank=[(0, 0, 1536, 92), (0, 0, 62, 850), (0, 840, 1536, 1024)],
        groups=[("walk", 6), ("idle", 3), ("spinup", 3), ("attack", 4), ("drained", 2), ("death", 5)],
        height=46),
    "bulwark": dict(
        path="art/clockwork/bulwark.png", blank=[(0, 0, 1536, 92), (0, 0, 64, 850), (0, 845, 1536, 1024)],
        groups=[("walk", 6), ("idle", 3), ("brace", 4), ("braced_hit", 4), ("attack", 3), ("death", 5)],
        height=48),
    "windup_soldier": dict(
        path="art/clockwork/windup_soldier.png", blank=[(0, 0, 1536, 92), (0, 0, 64, 850), (0, 845, 1536, 1024)],
        groups=[("walk", 6), ("idle", 3), ("attack", 5), ("rundown", 3), ("windup", 3), ("death", 5)],
        height=22),
}


def smoke_kind(rgb, kind):
    """Round 4's painted-light test, plus grey smoke (low chroma, lighter than the slate)."""
    if kind == "smoke":
        mx, mn = rgb.max(-1), rgb.min(-1)
        return (mx - mn <= 26) & (rgb.mean(-1) >= 70) & (rgb.mean(-1) <= 210)
    return _glow4(rgb, kind)


_glow4 = r4.glow_kind


# ---------------------------------------------------------------- cutting

def brackets(px):
    """The group brackets: the brightest line under the header, its long light runs."""
    bright = px[..., :3].astype(int).mean(-1) > 110
    y = max(range(50, 92), key=lambda yy: bright[yy].sum())
    xs = np.flatnonzero(bright[y])
    runs, s, p = [], xs[0], xs[0]
    for x in xs[1:]:
        if x > p + 2:
            runs.append((s, p + 1))
            s = x
        p = x
    runs.append((s, p + 1))
    return [(int(a), int(b)) for a, b in runs if b - a > 20]


def row_runs(fg):
    rows = fg.sum(1)
    ys = np.flatnonzero(rows > 0)
    runs, s, p = [], ys[0], ys[0]
    for y in ys[1:]:
        if y > p + 3:
            runs.append((s, p + 1))
            s = y
        p = y
    runs.append((s, p + 1))
    return [(int(a), int(b)) for a, b in runs if b - a > 30]


def bodies(cols, a, b, thick):
    """Column runs inside a..b where the figure is thick (bodies, not weapons)."""
    on = cols[a:b] >= thick
    runs, x = [], 0
    while x < len(on):
        if on[x]:
            s = x
            while x < len(on) and on[x]:
                x += 1
            runs.append([a + s, a + x])
        else:
            x += 1
    # merge runs split by a narrow notch (between the legs)
    out = []
    for r in runs:
        if out and r[0] - out[-1][1] <= 4:
            out[-1][1] = r[1]
        else:
            out.append(r)
    return [r for r in out if r[1] - r[0] >= 6]


def group_cuts(m, a, b, n):
    """n frames in columns a..b of mask m: cut between the bodies at the emptiest column,
    ties to the right (a weapon stays with its holder)."""
    cols = m[:, a:b].sum(0).astype(float)
    full = np.zeros(m.shape[1])
    full[a:b] = cols
    h = np.flatnonzero(m[:, a:b].any(1))
    thick = max(8, int((h.max() - h.min()) * 0.3)) if len(h) else 8
    runs = bodies(full, a, b, thick)
    if len(runs) != n:
        return r4.column_cuts(m, a, b, n)
    cuts = [a]
    for k in range(n - 1):
        lo, hi = runs[k][1], runs[k + 1][0]
        if hi <= lo:
            cuts.append(lo)
            continue
        seg = full[lo:hi]
        best = np.flatnonzero(seg <= seg.min() + 0.5)
        cuts.append(lo + int(best[-1]))
    cuts.append(b)
    return cuts


def extract(kind):
    cfg = SHEETS[kind]
    px = ia.load(cfg["path"])
    bg, bgc = bg_mask(px)
    fg = ~bg
    for x0, y0, x1, y1 in cfg["blank"]:
        fg[y0:y1, x0:x1] = False
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    if n:
        size = ndimage.sum(fg, lab, np.arange(1, n + 1))
        fg &= ~((size < 4)[lab - 1] & (lab > 0))
    br = brackets(px)
    assert len(br) == len(cfg["groups"]), (kind, br)
    # group x ranges: from halfway between brackets
    edges = [0] + [(br[i][1] + br[i + 1][0]) // 2 for i in range(len(br) - 1)] + [px.shape[1]]
    rows = row_runs(fg)
    assert len(rows) == 5, (kind, rows)
    out = {}
    for r, (y0, y1) in enumerate(rows):
        y0, y1 = max(0, y0 - 2), min(px.shape[0], y1 + 2)
        m = np.zeros_like(fg)
        m[y0:y1] = fg[y0:y1]
        # between two groups: the emptiest column between the brackets (nearest the middle)
        cols = m.sum(0)
        redges = [0]
        for i in range(len(br) - 1):
            lo, hi = br[i][1] - 12, br[i + 1][0] + 12
            seg = cols[lo:hi]
            best = np.flatnonzero(seg <= seg.min())
            redges.append(lo + int(best[np.argmin(np.abs(best + lo - edges[i + 1]))]))
        redges.append(px.shape[1])
        cuts = []
        for g, (name, cnt) in enumerate(cfg["groups"]):
            a, b = redges[g], redges[g + 1]
            xs = np.flatnonzero(m[:, a:b].any(0))
            a, b = a + int(xs.min()), a + int(xs.max()) + 1
            cuts += group_cuts(m, a, b, cnt)[:-1]
            if g == len(cfg["groups"]) - 1:
                cuts.append(b)
        cuts = np.array(cuts)
        slot_of_col = np.clip(np.searchsorted(cuts, np.arange(px.shape[1]), side="right") - 1, 0, len(cuts) - 2)
        lab, n = ndimage.label(m, structure=np.ones((3, 3)))
        ys, xs = np.nonzero(m)
        ls = lab[ys, xs]
        cs = slot_of_col[xs]
        nslot = len(cuts) - 1
        mass = np.zeros((n + 1, nslot))
        np.add.at(mass, (ls, cs), 1)
        whole = mass.max(1) >= 0.8 * mass.sum(1)
        own = mass.argmax(1)
        slots = np.full(m.shape, -1, int)
        slots[ys, xs] = np.where(whole[ls], own[ls], cs)
        if len(np.unique(slots[ys, xs])) < nslot:
            # a frame lost everything to a neighbour (one piece spanning both): plain cuts
            slots[ys, xs] = cs
        k = 0
        for name, cnt in cfg["groups"]:
            for i in range(cnt):
                fm = slots == k
                k += 1
                yy, xx = np.nonzero(fm)
                fy0, fy1, fx0, fx1 = yy.min(), yy.max() + 1, xx.min(), xx.max() + 1
                img = px[fy0:fy1, fx0:fx1].copy()
                img[..., 3] = np.where(fm[fy0:fy1, fx0:fx1], 255, 0)
                img[~fm[fy0:fy1, fx0:fx1]] = 0
                out.setdefault((r, name), []).append(img.astype(np.uint8))
    return out, bgc


def to_frame(img, scale, bgc, glow=None):
    small, gl = r4.to_game(img, scale, bgc, glow, 0.3)
    # seams: crumbs of a neighbour's weapon left at the frame's edge (small pieces well
    # away from the figure) go; debris in the death frames is bigger and stays
    a = (small[..., 3] > 0) & ~gl
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n > 1:
        size = ndimage.sum(a, lab, np.arange(1, n + 1))
        main = lab == int(np.argmax(size)) + 1
        near = ndimage.binary_dilation(main, iterations=3)
        for k in range(1, n + 1):
            comp = lab == k
            if size[k - 1] < 10 and not (comp & near).any():
                small[comp] = 0
                gl &= ~comp
    return F(small, gl)


def build_unit(kind):
    cfg = SHEETS[kind]
    src, bgc = extract(kind)
    hs = [im.shape[0] for im in src[(0, "idle")]]
    scale = cfg["height"] / float(np.median(hs))
    print(f"{kind}: scale {scale:.4f}")
    out = {}
    r4.glow_kind = smoke_kind
    try:
        for r, d in enumerate(DIRS):
            for name, _ in cfg["groups"]:
                fr = [to_frame(im, scale, bgc, "smoke" if name == "death" else None) for im in src[(r, name)]]
                part = "high" if name == "walk" else "low"
                out[name, d] = steady(fr, part, chain=(name == "death"))
    finally:
        r4.glow_kind = _glow4
    return {kind: r10.write_kind(kind, out)}


# ---------------------------------------------------------------- buildings

ENGINE_HALL = dict(path="art/clockwork/engine_hall.png", kind="engine_hall",
                   states=["built", "construction", "damaged", "destroyed"], width=136)


def build_engine_hall():
    px = ia.load(ENGINE_HALL["path"])
    bg, bgc = bg_mask(px)
    fg = ~bg
    lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
    size = ndimage.sum(fg, lab, np.arange(1, n + 1))
    fg &= ~((size < 6)[lab - 1] & (lab > 0))
    # the four pictures: split at the widest empty column runs
    cols = fg.sum(0)
    xs = np.flatnonzero(cols > 0)
    gaps = []
    for a, b in zip(xs[:-1], xs[1:]):
        if b - a > 8:
            gaps.append((b - a, (a + b) // 2))
    cutsx = sorted(c for _, c in sorted(gaps, reverse=True)[:3])
    panels = [0] + cutsx + [px.shape[1]]
    pics = []
    for a, b in zip(panels[:-1], panels[1:]):
        m = fg.copy()
        m[:, :a] = False
        m[:, b:] = False
        ys, xs2 = np.nonzero(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs2.min(), xs2.max() + 1
        img = px[y0:y1, x0:x1].copy()
        img[~m[y0:y1, x0:x1]] = 0
        img[..., 3] = np.where(m[y0:y1, x0:x1], 255, 0)
        # the footing's middle: the median column of the lowest fifth of the picture
        low = m[y0:y1, x0:x1].copy()
        low[: int((y1 - y0) * 0.8)] = False
        cx = float(np.median(np.nonzero(low)[1])) + 0.5
        pics.append((img.astype(np.uint8), cx))
    # one scale for all four: the built picture's base is the footprint's width
    scale = ENGINE_HALL["width"] / pics[0][0].shape[1]
    r4.glow_kind = smoke_kind
    try:
        for state, (img, cx) in zip(ENGINE_HALL["states"], pics):
            small, _ = r4.to_game(img, scale, bgc, "smoke")
            ys, xs3 = np.nonzero(small[..., 3] > 0)
            small = small[:ys.max() + 1]
            c = cx * scale
            half = int(np.ceil(max(c - xs3.min(), xs3.max() + 1 - c)))
            W = 2 * half
            canvas = np.zeros((ys.max() + 1 - ys.min(), W, 4), np.uint8)
            ox = int(round(half - c))
            part = small[ys.min():]
            canvas[:, max(0, ox):ox + part.shape[1]] = part[:, max(0, -ox):W - ox][:, :W - max(0, ox)]
            canvas = clean(canvas, min_size=3, keep_near=1)
            Image.fromarray(canvas, "RGBA").save(f"assets/buildings/engine_hall_{state}.png")
            print(f"engine_hall_{state}: {canvas.shape[1]}x{canvas.shape[0]}")
            if state == "built":
                write_building_size("engine_hall", (canvas.shape[1], canvas.shape[0]))
    finally:
        r4.glow_kind = _glow4


# The bigger Clockwork footprints: the same source pictures re-cut wider (tile widths:
# Assembly Works 5 tiles, Boiler 4). import_art.py carries the same widths, so a full
# rebuild agrees; here only these two are redone (and no icons).
WIDER = {"assembly_works": 168, "boiler": 126}


def build_wider():
    ia.CLOCKWORK_WIDTH.update({k: v for k, v in WIDER.items() if k in ia.CLOCKWORK_WIDTH})
    for cfg in ia.STRUCTURES2.values():
        cfg["width"].update({k: v for k, v in WIDER.items() if k in cfg["width"]})
    keep_icon, ia.make_icon = ia.make_icon, (lambda img, name: None)
    keep_save = ia.save
    keep_s2 = dict(ia.STRUCTURES2)

    def only_wider(img, path):
        name = os.path.basename(path).rsplit("_", 1)[0]
        if name in WIDER:
            keep_save(img, path)
    ia.save = only_wider
    try:
        data = {"buildings": {}}
        ia.STRUCTURES2.clear()
        ia.STRUCTURES2["art/clockwork/structures2.png"] = keep_s2["art/clockwork/structures2.png"]
        ia.import_structures2(data)
        ia.import_clockwork_structures(data)
    finally:
        ia.save = keep_save
        ia.make_icon = keep_icon
        ia.STRUCTURES2.clear()
        ia.STRUCTURES2.update(keep_s2)
    for k in WIDER:
        write_building_size(k, tuple(data["buildings"][k]))


def write_building_size(kind, size):
    path = "scripts/art_data.gd"
    src = open(path).read()
    line = f'\t"{kind}": Vector2i({size[0]}, {size[1]}),\n'
    start = src.index("const BUILDING_SIZE := {")
    end = src.index("\n}\n", start) + 1
    block = src[start:end]
    import re
    pat = re.compile(r'\t"' + kind + r'": Vector2i\(.*\n')
    if pat.search(block):
        block = pat.sub(lambda m: line, block, count=1)
    else:
        block = block + line
    open(path, "w").write(src[:start] + block + src[end:])


# ---------------------------------------------------------------- contact sheets

def contact(entries):
    os.makedirs(CONTACT, exist_ok=True)
    for kind, entry in entries.items():
        r10.CONTACT = CONTACT
        r10.unit_contact(kind, entry)
    r10.LINEUP[:] = [("musketeer", "idle_s"), ("gearknight", "idle_s"), ("arc_thrower", "idle_s")] + \
        [(k, "idle_s") for k in entries]
    r10.lineup(os.path.join(CONTACT, "lineup_round12.png"))


def main():
    entries = {}
    for kind in SHEETS:
        if not ONLY or kind in ONLY:
            entries.update(build_unit(kind))
    r4.write_units_data(entries)
    if not ONLY or "engine" in ONLY:
        build_engine_hall()
    if not ONLY or "wider" in ONLY:
        build_wider()
    if CONTACT and entries:
        contact(entries)


if __name__ == "__main__":
    main()
