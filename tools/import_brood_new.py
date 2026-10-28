#!/usr/bin/env python3
"""Import the NEW BROOD's three creatures (docs/brood_new.md) from the owner's ChatGPT sheets in art/redraws/:
the BROOD MOTHER (the Queen, kind "brood_mother"), the ROOTMAW (the swamp lizard, kind "rootmaw") and the
TYRANNOSAUR (the father of the ground warriors, kind "tyrannosaur").

Every sheet is drawn on a flat dark navy background. Steps (re-runnable: python3 -I tools/import_brood_new.py
[--contact DIR] [--only KIND]):
  1. Key out the navy: the background colour is the median of the sheet's border; a pixel more than KEY from it
     (sum of |dr|+|dg|+|db|) is drawing, except the soft dark-navy drop shadow (dark, blue over red, close to the
     background); pockets of background smaller than HOLE inside a drawing are filled back in (its own dark shading).
  2. Split the frames: each sprite is a big connected piece plus the small bits near it (egg sparkles, spit, dirt
     crumbs: import_art.components); pieces are grouped into rows by their height on the sheet, left to right.
  3. Scale: each creature has a target width for its south-east walk (TARGET_W, game px: the Queen as wide as the
     Clocktower's gear ring, the Rootmaw a bit wider than a Cottage, the Tyrannosaur as wide as a Barracks); that gives
     the creature's height H. Every other sheet is scaled so its reference frame (REF: a standing or walking pose)
     is H tall (times a small per-sheet fudge), so sheets ChatGPT drew at different sizes come out the same size.
  4. Box-filter shrink with premultiplied alpha, hard alpha; the red spikes snapped to the two key reds the team
     shader repaints (import_art.snap_team), as on every Brood creature.
  5. Feet on the ground: one canvas per creature; every frame is placed with its lowest row on the anchor line and
     its body's centre of mass (columns) on the anchor column, so a walk does not slide sideways frame to frame.
     West views are the east ones mirrored by the game.
Writes assets/units/<kind>/<anim>_<dir>.png, the kinds' entries in scripts/art_data.gd (BASE_UNITS), the portraits
assets/icons/<kind>.png (from the painted portraits) and the placeholder command icons assets/icons/brood/ab_uproot.png,
ab_haul.png (drawn from the existing Brood icons until the owner's arrive; docs/art_style_inconsistency.md).
"""
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402

R = "art/redraws/"
KEY = 40
HOLE = 1500

# kind -> south-east walk width in game px (the anchor of the creature's size)
TARGET_W = {"brood_mother": 250, "rootmaw": 84, "tyrannosaur": 128}

# kind -> list of sheets: (file, [row specs], ref (row, frame), fudge)
# a row spec: (anim, dir) or None (row skipped); frames: all of the row, or (anim, dir, [indices])
SHEETS = {
    "brood_mother": [
        ("brood_mother_se_walk_stride_chatgpt.png", [("walk", "se")], (0, 0), 1.0),
        ("brood_mother_s_walk_stride_chatgpt.png", [("walk", "s")], (0, 0), 1.0),
        ("brood_mother_e_walk_stride_chatgpt.png", [("walk", "e")], (0, 0), 1.0),
        ("brood_mother_ne_walk_stride_chatgpt.png", [("walk", "ne")], (0, 0), 1.0),
        ("brood_mother_n_walk_chatgpt.png", [("walk", "n")], (0, 0), 1.0),
        ("brood_mother_se_rooting_chatgpt.png", [("root", "se"), ("rooted", "se"), ("uproot", "se")], (0, 0), 1.0),
        ("brood_mother_se_walk_lay_death_chatgpt.png", [None, None, ("death", "se")], (0, 0), 1.0),
        ("brood_mother_se_attack_fixed.png", [("attack", "se")], (0, 0), 1.0),
        ("brood_mother_s_attack_chatgpt.png", [("attack", "s")], (0, 0), 1.0),
        ("brood_mother_e_attack_chatgpt.png", [("attack", "e")], (0, 0), 1.0),
        ("brood_mother_ne_attack_chatgpt.png", [("attack", "ne")], (0, 0), 1.0),
        ("brood_mother_n_attack_fixed.png", [("attack", "n")], (0, 0), 1.0),
    ],
    "rootmaw": [
        ("rootmaw_lizard_se_chatgpt.png", [("walk", "se"), ("root", "se"), ("fill", "se"), ("uproot", "se"), ("death_full", "se")], (0, 0), 1.0),
        ("rootmaw_lizard_s_walk_chatgpt.png", [("walk", "s")], (0, 0), 1.0),
        ("rootmaw_lizard_e_walk_chatgpt.png", [("walk", "e")], (0, 0), 1.0),
        ("rootmaw_lizard_ne_walk_chatgpt.png", [("walk", "ne")], (0, 0), 1.0),
        ("rootmaw_lizard_n_walk_chatgpt.png", [("walk", "n")], (0, 0), 1.0),
        ("rootmaw_lizard_thin_death_chatgpt.png", [("death", "se")], (0, 0), 1.0),
        ("rootmaw_lizard_se_attack_chatgpt.png", [("attack", "se")], (0, 0), 1.0),
        ("rootmaw_lizard_s_attack_chatgpt.png", [("attack", "s")], (0, 0), 1.0),
        ("rootmaw_lizard_e_attack_chatgpt.png", [("attack", "e")], (0, 0), 1.0),
        ("rootmaw_lizard_ne_attack_chatgpt.png", [("attack", "ne")], (0, 0), 1.0),
        ("rootmaw_lizard_n_attack_chatgpt.png", [("attack", "n")], (0, 0), 1.0),
    ],
    "tyrannosaur": [
        ("tyrannosaur_se_walk_bite_chatgpt.png", [("walk", "se"), ("attack", "se")], (0, 0), 1.0),
        ("tyrannosaur_se_breath_death_chatgpt.png", [("breath", "se"), ("death", "se")], (0, 0), 1.0),
        ("tyrannosaur_s_walk_chatgpt.png", [("walk", "s")], (0, 0), 1.0),
        ("tyrannosaur_e_walk_chatgpt.png", [("walk", "e")], (0, 0), 1.0),
        ("tyrannosaur_ne_walk_chatgpt.png", [("walk", "ne")], (0, 0), 1.0),
        ("tyrannosaur_n_walk_chatgpt.png", [("walk", "n")], (0, 0), 1.0),
        ("tyrannosaur_s_bite_chatgpt.png", [("attack", "s")], (0, 0), 1.0),
        ("tyrannosaur_e_bite_chatgpt.png", [("attack", "e")], (0, 0), 1.0),
        ("tyrannosaur_ne_bite_chatgpt.png", [("attack", "ne")], (0, 0), 1.0),
        ("tyrannosaur_n_bite_chatgpt.png", [("attack", "n")], (0, 0), 1.0),
    ],
}
PORTRAIT = {"brood_mother": "brood_mother_portrait_chatgpt.png", "rootmaw": "rootmaw_lizard_portrait_chatgpt.png",
            "tyrannosaur": "tyrannosaur_portrait_chatgpt.png"}
# HAUL (the Rootmaw walking full; its swollen body stands about HAUL_UP times as tall as the thin walk)
HAUL_UP = 1.3
OPTIONAL = {"rootmaw": [("rootmaw_lizard_haul_%s_chatgpt.png" % d, [("haul", d)], (0, 0), HAUL_UP)
                        for d in ["se", "s", "e", "ne", "n"]]}
ICONS = "icons_brood_root_uproot_haul_chatgpt.png"
GRUB_SHEET = "grub_harvest_chatgpt.png"         # rows S, SE, E, (a second E: not used), N
GRUB_SHEET_NE = "grub_harvest_ne_chatgpt.png"   # one row: NE


def key_mask(px):
    rgb = px[..., :3].astype(int)
    border = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3), rgb[:, :4].reshape(-1, 3), rgb[:, -4:].reshape(-1, 3)])
    bg = np.median(border, 0)
    d = np.abs(rgb - bg).sum(-1)
    fg = d > KEY
    # the soft navy drop shadow under the feet: dark, bluish, not far from the background
    v = rgb.max(-1)
    shadow = (v < 70) & (rgb[..., 2] >= rgb[..., 0]) & (d < KEY * 2.2)
    fg &= ~shadow
    fg = ndimage.binary_opening(fg, iterations=1)
    # pockets of background inside a drawing (its dark shading) go back in
    holes = ndimage.binary_fill_holes(fg) & ~fg
    lab, n = ndimage.label(holes)
    if n:
        sz = ndimage.sum(holes, lab, range(1, n + 1))
        small = np.zeros(n + 1, bool)
        small[1:] = sz < HOLE
        fg |= small[lab] & (lab > 0)
    return fg


def sheet_rows(path):
    px = ia.load(R + path)
    fg = key_mask(px)
    big = max(2500, int(fg.sum() * 0.012))
    sprites = ia.components(fg, 4, min_big=big, attach_dist=40)
    if not sprites:
        return px, []
    # a piece much smaller than the frames (a food blob held out, a splash): it goes with the nearest frame
    top = max(s["area"] for s in sprites)
    big_ones = [s for s in sprites if s["area"] >= top * 0.3]
    for s in sprites:
        if s["area"] >= top * 0.3:
            continue
        def gap(o):
            dy = max(o["y0"] - s["y1"], 0, s["y0"] - o["y1"])
            dx = max(o["x0"] - s["x1"], 0, s["x0"] - o["x1"])
            return dx * dx + dy * dy
        i = min(range(len(big_ones)), key=lambda j: gap(big_ones[j]))
        big_ones[i] = _piece(big_ones[i]["mask"] | s["mask"])
    sprites = big_ones
    groups = ia.cluster_1d(np.array([s["y1"] for s in sprites]), 80)
    rows = [sorted([sprites[i] for i in g], key=lambda s: s["cx"]) for g in groups]
    rows = [split_wide(r) for r in rows]
    rows.sort(key=lambda r: np.mean([s["cy"] for s in r]))
    return px, rows


def _piece(mask):
    ys, xs = np.nonzero(mask)
    return {"mask": mask, "y0": ys.min(), "y1": ys.max() + 1, "x0": xs.min(), "x1": xs.max() + 1,
            "cy": (ys.min() + ys.max()) / 2, "cx": (xs.min() + xs.max()) / 2, "area": len(ys)}


def split_wide(row):
    """Two frames joined by a spray or a claw (one piece about twice as wide as the others): cut where the columns are
    emptiest round its middle."""
    if len(row) < 3:
        return row
    med = float(np.median([s["x1"] - s["x0"] for s in row]))
    out = []
    for s in row:
        w = s["x1"] - s["x0"]
        if w > med * 1.6:
            n = int(round(w / med))
            col = s["mask"][:, s["x0"]:s["x1"]].sum(0).astype(float)
            cuts = []
            for k in range(1, n):
                g = int(w * k / n)
                lo, hi = max(1, g - int(med * 0.3)), min(w - 1, g + int(med * 0.3))
                cuts.append(s["x0"] + lo + int(np.argmin(col[lo:hi])))
            edges = [s["x0"]] + cuts + [s["x1"]]
            for a, b in zip(edges[:-1], edges[1:]):
                m = s["mask"].copy()
                m[:, :a] = False
                m[:, b:] = False
                if m.any():
                    out.append(_piece(m))
        else:
            out.append(s)
    return sorted(out, key=lambda s: s["cx"])


def anchor_of(im):
    a = im[..., 3] > 0
    ys, xs = np.nonzero(a)
    return float(xs.mean()), float(ys.max())


def load_kind(kind, sheets, required=True):
    out = {}
    for spec in sheets:
        f, rowspec, ref, fudge = spec
        if not os.path.exists(R + f):
            if required:
                sys.exit(f"missing sheet {R + f}")
            continue
        px, rows = sheet_rows(f)
        print(f"  {f}: rows {[len(r) for r in rows]}")
        if len(rows) < len([r for r in rowspec if r is not None]):
            print(f"  ! {f}: found {len(rows)} rows, expected {len(rowspec)}")
        cut = [[ia.cutout(px, s) for s in r] for r in rows]
        out[f] = (cut, rowspec, ref, fudge)
    return out


def import_kind(kind, data, contact_dir):
    sheets = SHEETS[kind] + OPTIONAL.get(kind, [])
    raw = load_kind(kind, SHEETS[kind])
    raw.update(load_kind(kind, OPTIONAL.get(kind, []), required=False))
    # the creature's height from the south-east walk
    se_cut = raw[SHEETS[kind][0][0]][0]
    w0 = se_cut[0][0].shape[1]
    h0 = se_cut[0][0].shape[0]
    base = TARGET_W[kind] / w0
    H = h0 * base
    small = {}
    for f, rowspec, ref, fudge in sheets:
        if f not in raw:
            continue
        cut = raw[f][0]
        r0, i0 = ref
        refimg = cut[r0][i0]
        scale = H * fudge / refimg.shape[0] if f != SHEETS[kind][0][0] else base
        for ri, spec in enumerate(rowspec):
            if spec is None or ri >= len(cut):
                continue
            anim, d = spec[0], spec[1]
            imgs = cut[ri]
            if len(spec) > 2:
                imgs = [imgs[i] for i in spec[2] if i < len(imgs)]
            small[(anim, d)] = [ia.snap_team(ia.shrink(im, scale)) for im in imgs]
    # standing: the first walk frame in each direction (the rooted Queen and Rootmaw have their own strips)
    for d in ["s", "se", "e", "ne", "n"]:
        if ("walk", d) in small:
            small[("idle", d)] = small[("walk", d)][:1]
    assemble(kind, small, data)
    if contact_dir:
        contact(contact_dir, kind, small)


def assemble(name, small, data):
    feet = {}
    L = R_ = U = D = 0
    for key, lst in small.items():
        for k, im in enumerate(lst):
            ax, ay = anchor_of(im)
            feet[(key, k)] = (ax, ay)
            L = max(L, ax); R_ = max(R_, im.shape[1] - ax); U = max(U, ay); D = max(D, im.shape[0] - ay)
    half = int(np.ceil(max(L, R_))) + 1
    W, top = 2 * half, int(np.ceil(U)) + 1
    Hh = top + int(np.ceil(D)) + 1
    counts = {}
    os.makedirs(f"{ia.OUT}/units/{name}", exist_ok=True)
    keep = {f"{a}_{d}.png" for (a, d) in small}
    for f in os.listdir(f"{ia.OUT}/units/{name}"):
        base = f[:-len(".import")] if f.endswith(".png.import") else f
        if base.endswith(".png") and base not in keep:
            os.remove(f"{ia.OUT}/units/{name}/{f}")      # (a strip no longer made; the others keep their .import)
    for (anim, d), lst in small.items():
        strip = np.zeros((Hh, W * len(lst), 4), np.uint8)
        for k, im in enumerate(lst):
            ax, ay = feet[((anim, d), k)]
            ox, oy = int(round(half - ax)), int(round(top - ay))
            h, w = im.shape[:2]
            ys0, xs0 = max(0, oy), max(0, ox)
            ys1, xs1 = min(Hh, oy + h), min(W, ox + w)
            src = im[ys0 - oy:ys1 - oy, xs0 - ox:xs1 - ox]
            m = src[..., 3] > 0
            cell = strip[:, k * W:(k + 1) * W]
            cell[ys0:ys1, xs0:xs1][m] = src[m]
        ia.save(strip, f"{ia.OUT}/units/{name}/{anim}_{d}.png")
        counts[f"{anim}_{d}"] = len(lst)
    data[name] = {"cell": (W, Hh), "anchor": (half, top), "frames": counts}
    print(f"  {name}: cell {W}x{Hh}, " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))


def write_entry(name, e):
    path = "scripts/art_data.gd"
    src = open(path).read()
    lines = [f'\t"{name}": {{"cell": Vector2i({e["cell"][0]}, {e["cell"][1]}), "anchor": Vector2({e["anchor"][0]}, {e["anchor"][1]}), "frames": {{\n']
    for k in sorted(e["frames"]):
        lines.append(f'\t\t"{k}": {e["frames"][k]},\n')
    lines.append("\t}},\n")
    entry = "".join(lines)
    pat = re.compile(r'\t"' + name + r'": \{.*?\n\t\}\},\n', re.S)
    if pat.search(src):
        src = pat.sub(lambda m: entry, src, count=1)
    else:
        start = src.index("const BASE_UNITS := {")
        end = src.index("\n}\n", start) + 1
        src = src[:end] + entry + src[end:]
    open(path, "w").write(src)


def portrait(kind):
    px = ia.load(R + PORTRAIT[kind])
    h, w = px.shape[:2]
    s = min(h, w)
    crop = px[(h - s) // 2:(h - s) // 2 + s, (w - s) // 2:(w - s) // 2 + s].astype(np.uint8)
    img = Image.fromarray(crop).convert("RGB").resize((60, 60), Image.LANCZOS)
    icon = np.zeros((64, 64, 4), np.uint8)
    icon[..., :3] = (70, 74, 72)
    icon[..., 3] = 255
    icon[2:62, 2:62, :3] = np.array(img)
    ia.save(ia.unteam(icon), f"{ia.OUT}/icons/{kind}.png")


def command_icons():
    """ROOT, UPROOT and HAUL: the owner's three framed icons (ICONS, left to right), cut on their frames and shrunk to
    the 64 px button. Named ab_nb_root / ab_uproot / ab_haul so the old Brood's Spore Mother keeps its own ROOT icon."""
    px = ia.load(R + ICONS)
    fg = key_mask(px)
    sprites = ia.components(fg, 3, min_big=20000, attach_dist=0)
    sprites = sorted([s for s in sprites if s["area"] > 20000], key=lambda s: s["cx"])[:3]
    for s, name in zip(sprites, ["ab_nb_root", "ab_uproot", "ab_haul"]):
        crop = px[s["y0"]:s["y1"], s["x0"]:s["x1"]].astype(np.uint8)
        img = Image.fromarray(crop).convert("RGB").resize((64, 64), Image.BOX)
        out = np.zeros((64, 64, 4), np.uint8)
        out[..., :3] = np.array(img)
        out[..., 3] = 255
        ia.save(ia.unteam(out), f"{ia.OUT}/icons/brood/{name}.png")
    print(f"  icons: {len(sprites)} cut (ab_nb_root, ab_uproot, ab_haul)")


def _grub_frames(px, row, scale):
    return [ia.snap_team(ia.shrink(ia.cutout(px, s), scale)) for s in row]


def grub_harvest():
    """The grub taking food from a Rootmaw's flank (GRUB_SHEET: rows S, SE, E, a second E not used, N; GRUB_SHEET_NE:
    NE; 5 frames: mouth open, at the flank, the food coming out, held, held). Each row is scaled so its first frame is as
    tall as the grub's own idle in that view (the NE grub stands up a little: its row is scaled by its body's width
    instead), set on the grub's cell with the feet on its anchor, and written as harvest_<dir> strips (west mirrored by
    the game); the grub's entry in art_data gets the strips."""
    px, rows = sheet_rows(GRUB_SHEET)
    pxn, rows_ne = sheet_rows(GRUB_SHEET_NE)
    print(f"  {GRUB_SHEET}: rows {[len(r) for r in rows]}, {GRUB_SHEET_NE}: rows {[len(r) for r in rows_ne]}")
    if len(rows) < 5 or not rows_ne:
        print("  ! grub harvest: rows missing")
        return
    src = open("scripts/art_data.gd").read()
    m = re.search(r'\t"grub": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)', src)
    cw, ch, axx, ayy = int(m.group(1)), int(m.group(2)), float(m.group(3)), float(m.group(4))

    def size_of(strip):
        im = np.array(Image.open(f"{ia.OUT}/units/grub/{strip}.png").convert("RGBA"))
        n = im.shape[1] // cw
        ws = []
        hs = []
        for k in range(n):
            ys, xs = np.nonzero(im[:, k * cw:(k + 1) * cw, 3] > 0)
            hs.append(ys.max() - ys.min() + 1)
            ws.append(xs.max() - xs.min() + 1)
        return float(np.median(hs)), float(np.median(ws))

    # one scale for the whole five-row sheet (from its front view against the grub's idle_s); the NE sheet by the
    # width of the grub's own north-east walk
    s_ref = ia.cutout(px, rows[0][0])
    main_scale = size_of("idle_s")[0] / s_ref.shape[0]
    ne_ref = ia.cutout(pxn, rows_ne[0][0])
    ne_scale = size_of("walk_ne")[1] / ne_ref.shape[1]
    sets = {"s": (px, rows[0]), "se": (px, rows[1]), "e": (px, rows[2]), "n": (px, rows[4]), "ne": (pxn, rows_ne[0])}
    counts = {}
    for d, (p, row) in sets.items():
        scale = ne_scale if d == "ne" else main_scale
        frames = _grub_frames(p, row, scale)
        strip = np.zeros((ch, cw * len(frames), 4), np.uint8)
        for k, im in enumerate(frames):
            yy, xx = np.nonzero(im[..., 3] > 0)
            low = yy >= yy.max() - 3
            ax = float(np.median(xx[low])) if low.any() else float(xx.mean())
            ox, oy = int(round(axx - ax)), int(round(ayy - yy.max()))
            h, w = im.shape[:2]
            ys0, xs0 = max(0, oy), max(0, ox)
            ys1, xs1 = min(ch, oy + h), min(cw, ox + w)
            sub = im[ys0 - oy:ys1 - oy, xs0 - ox:xs1 - ox]
            mm = sub[..., 3] > 0
            cell = strip[:, k * cw:(k + 1) * cw]
            cell[ys0:ys1, xs0:xs1][mm] = sub[mm]
        ia.save(strip, f"{ia.OUT}/units/grub/harvest_{d}.png")
        counts[f"harvest_{d}"] = len(frames)
    a = src.index('\t"grub": {')
    b = src.index("\n\t}},\n", a)
    body = re.sub(r'\n\t\t"harvest_\w+": \d+,', "", src[a:b])
    for k in sorted(counts):
        body += f'\n\t\t"{k}": {counts[k]},'
    open("scripts/art_data.gd", "w").write(src[:a] + body + src[b:])
    print("  grub: " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))


EGG_SHEET = "brood_egg_chatgpt.png"      # row 1: 5 pulse frames (waiting), row 2: 5 hatching frames (ending on the open shell)
PILE_SHEET = "food_pile_chatgpt.png"    # 4 frames: fresh to almost gone (rotted)
EGG_H = 22                              # game px: the egg with its dirt about one grub tall
PILE_W = 72                             # game px: the fresh pile about a Rootmaw wide


def _drop_loose(im, keep_below=0.55):
    """Small loose bits above the egg's middle (the yellow motion arcs drawn at the top right of the 4th pulse frame) go;
    the egg and the dirt crumbs at its foot stay."""
    a = im[..., 3] > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n <= 1:
        return im
    sizes = ndimage.sum(a, lab, range(1, n + 1))
    big = int(np.argmax(sizes)) + 1
    h = im.shape[0]
    out = im.copy()
    for i in range(1, n + 1):
        if i == big:
            continue
        ys = np.nonzero(lab == i)[0]
        if ys.mean() < h * keep_below:
            out[lab == i] = 0
    return out


def still_art():
    """The egg and the food pile from the owner's sheets (EGG_SHEET, PILE_SHEET). The egg: idle_s the waiting pulse,
    hatch_s the hatching (the game puts the creature on the open shell and tints a fertilised egg red), death_s the
    broken shell (the hatch's last three frames) when one is killed. The pile: idle_s, four frames from fresh to
    rotted (the game picks the one that matches what is left and what has rotted)."""
    data = {}
    px, rows = sheet_rows(EGG_SHEET)
    if len(rows) < 2:
        sys.exit("brood egg sheet: expected 2 rows")
    ref = ia.cutout(px, rows[0][0])
    scale = EGG_H / ref.shape[0]
    pulse = [ia.unteam(ia.shrink(_drop_loose(ia.cutout(px, sp)), scale)) for sp in rows[0]]
    hatch = [ia.unteam(ia.shrink(ia.cutout(px, sp), scale)) for sp in rows[1]]
    small = {("idle", "s"): pulse, ("hatch", "s"): hatch, ("death", "s"): hatch[2:]}
    _place("brood_egg", small, data)
    pp, prow = sheet_rows(PILE_SHEET)
    piles = [ia.cutout(pp, sp) for sp in prow[0]]
    pscale = PILE_W / piles[0].shape[1]
    small = {("idle", "s"): [ia.unteam(ia.shrink(im, pscale)) for im in piles]}
    small[("death", "s")] = small[("idle", "s")][-1:]
    _place("food_pile", small, data)
    for k, v in data.items():
        write_entry(k, v)
    print("  brood_egg, food_pile from the owner's sheets")


def _place(name, small, data):
    """One canvas, each frame's bottom on the anchor line and its middle (columns) on the anchor column."""
    L = R_ = U = D = 0
    feet = {}
    for key, lst in small.items():
        for k, im in enumerate(lst):
            ys, xs = np.nonzero(im[..., 3] > 0)
            ax, ay = (xs.min() + xs.max()) / 2.0, float(ys.max())
            feet[(key, k)] = (ax, ay)
            L = max(L, ax); R_ = max(R_, im.shape[1] - ax); U = max(U, ay); D = max(D, im.shape[0] - ay)
    half = int(np.ceil(max(L, R_))) + 1
    W, top = 2 * half, int(np.ceil(U)) + 1
    Hh = top + int(np.ceil(D)) + 1
    os.makedirs(f"{ia.OUT}/units/{name}", exist_ok=True)
    keep = {f"{a}_{d}.png" for (a, d) in small}
    for f in os.listdir(f"{ia.OUT}/units/{name}"):
        base = f[:-len(".import")] if f.endswith(".png.import") else f
        if base.endswith(".png") and base not in keep:
            os.remove(f"{ia.OUT}/units/{name}/{f}")      # (a strip no longer made; the others keep their .import)
    counts = {}
    for (anim, d), lst in small.items():
        strip = np.zeros((Hh, W * len(lst), 4), np.uint8)
        for k, im in enumerate(lst):
            ax, ay = feet[((anim, d), k)]
            ox, oy = int(round(half - ax)), int(round(top - ay))
            h, w = im.shape[:2]
            m = im[..., 3] > 0
            strip[oy:oy + h, k * W + ox:k * W + ox + w][m] = im[m]
        ia.save(strip, f"{ia.OUT}/units/{name}/{anim}_{d}.png")
        counts[f"{anim}_{d}"] = len(lst)
    data[name] = {"cell": (W, Hh), "anchor": (half, top), "frames": counts}


def contact(out_dir, kind, small):
    os.makedirs(out_dir, exist_ok=True)
    rows = []
    for key in sorted(small):
        lst = small[key]
        h = max(im.shape[0] for im in lst)
        w = sum(im.shape[1] + 4 for im in lst)
        row = np.zeros((h + 4, w + 4, 4), np.uint8)
        row[..., :3] = (96, 120, 70)
        row[..., 3] = 255
        x = 2
        for im in lst:
            m = im[..., 3] > 0
            row[2:2 + im.shape[0], x:x + im.shape[1]][m] = im[m]
            x += im.shape[1] + 4
        rows.append(row)
    Wd = max(r.shape[1] for r in rows)
    Ht = sum(r.shape[0] for r in rows)
    sheet = np.zeros((Ht, Wd, 4), np.uint8)
    sheet[..., 3] = 255
    y = 0
    for r in rows:
        sheet[y:y + r.shape[0], :r.shape[1]] = r
        y += r.shape[0]
    Image.fromarray(sheet).save(f"{out_dir}/{kind}_contact.png")


def main():
    contact_dir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else ""
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    data = {}
    for kind in SHEETS:
        if only and kind != only:
            continue
        print(kind)
        import_kind(kind, data, contact_dir)
        write_entry(kind, data[kind])
        portrait(kind)
    if not only:
        command_icons()
        grub_harvest()
        still_art()


if __name__ == "__main__":
    main()
