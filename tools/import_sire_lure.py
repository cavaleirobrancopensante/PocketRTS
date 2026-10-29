#!/usr/bin/env python3
"""Import THE SIRE LURES (the owner, 2026-10-29 18:03-18:31; docs/sire_lure.md): a grub no longer turns into a grown
Sire. It roots and swells into a LURE (a living pheromone gland, one kind per Sire); when it is ripe the Sire ARRIVES
in the lure's animation, eats it and stands on its spot (then he settles on his nest: his own rooting frames).

Re-runnable: python3 -I tools/import_sire_lure.py [--contact DIR] [--only KIND]. It uses tools/import_brood_new.py's
steps (the navy background keyed out, the feet of a frame found on the green body). Writes, for each Sire KIND
(tyrannosaur, dilophosaurus, pterodactyl), the art key "lure_<KIND>" (scripts/art_data.gd, assets/units/lure_<KIND>/):
  grow_se    4 frames: the concept's top row (the grub curling into the ground, swelling, the first scent holes, the
             haze), its yellow-green haze and glow TINTED toward the Sire's lure (Tyrant red, Venom as drawn, Storm storm-cloud white)
  ripe_se    1 frame: the ripe lure (frame 1 of his arrival sheet: exactly where the arrival starts); the game pulses it
             (scale and brightness breathing) and adds haze puffs in code (BroodRoot.lure_look)
  arrive_se  12 frames: his arrival sheet <KIND>_lure_arrive_se_chatgpt.png (2 rows of 6: the lure pulsing, the Sire
             comes in from the top left, eats the lure, stands on its spot)
All three strips share one cell and one ANCHOR: the Sire's feet in his last arrival frame, sized and placed as his own
in-game picture (REF) so his rooting frames take over where the arrival ends. The lure stays put on the map: the
first row's frames are lined up on the lure's mud (its bottom middle), the second row's on the Sire's feet, and the two
are tied by the last frame (his feet over the mud where the lure was).

SHEETS: art/redraws/sire_lure_concept_chatgpt.png (top row: 4 steps of the grub turning into a lure; bottom row: the 3
ripe lures, used as the prompt references only) and art/redraws/<KIND>_lure_arrive_se_chatgpt.png (1536x1024, frames on
a 256x512 grid; a piece that strays over a neighbour's slot goes to the slot nearest its middle).
WEAK FRAMES: the Tyrant's frame 2 is a strip of tail spikes over the haze: frame 1 is held instead (HOLD). His frames
7-12 face the viewer (south): the game cross-fades from his last frame to his south-east rooting frames.
TEAM COLOUR: the bright red spikes (the Sire's and the lure's) and their dark shading next to them snap to the team reds;
the darker red haze of the Tyrant's lure stays as drawn (its colour is the lure's, not the team's).
Prints, for Defs.NB "lure_at": the lure's ground point from the Sire's feet and its mud's width (game px).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art as ia  # noqa: E402
import import_brood_new as ibn  # noqa: E402

R = ibn.R
KINDS = ["tyrannosaur", "dilophosaurus", "pterodactyl"]
ARRIVE = "%s_lure_arrive_se_chatgpt.png"
CONCEPT = "sire_lure_concept_chatgpt.png"
SLOT_W, ROW_H, COLS = 256, 512, 6
HOLD = {"tyrannosaur": {1: 0}}           # arrival frame (from 0) -> the frame shown instead
# his in-game picture the last arrival frame is sized to (strip, frame): the Tyrant ends facing south; the Storm Sire
# ends landed, wings folded (his landing strip's first landed frame)
REF = {"tyrannosaur": ("idle_s", 0), "dilophosaurus": ("idle_se", 0), "pterodactyl": ("root_se", 2)}
# the growing lure's haze and glow tinted toward each Sire's lure (None: the concept's yellow-green, the Venom lure's)
TINT = {"tyrannosaur": (200, 42, 34), "dilophosaurus": None, "pterodactyl": (226, 230, 236)}
# THE STORM LURE'S HAZE IS STORM-CLOUD WHITE, NOT BLUE (the owner, 2026-10-29 20:09: blue clashes with a blue team colour):
# the arrival sheet's blue haze is turned grey-white at its own brightness (storm_white)
WHITE = {"pterodactyl"}


def slot_masks(px):
    """The sheet's 12 frames as masks: each keyed piece goes to the 256x512 slot nearest its middle."""
    fg = ibn.key_mask(px)
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=2))
    lab = np.where(fg, lab, 0)
    if n == 0:
        return []
    idx = np.arange(1, n + 1)
    sizes = ndimage.sum(fg, lab, idx)
    cms = ndimage.center_of_mass(fg, lab, idx)
    slot = np.full(n + 1, -1, int)
    for i, (sz, cm) in enumerate(zip(sizes, cms)):
        if sz < 12:
            continue
        cy, cx = cm
        row = int(cy >= ROW_H)
        col = int(np.argmin([abs(cx - (c * SLOT_W + SLOT_W / 2)) for c in range(COLS)]))
        slot[i + 1] = row * COLS + col
    fl = slot[lab]
    return [(fl == f) & fg for f in range(2 * COLS)]


STEP_ROW_Y = 360        # (the concept's top row: pieces whose middle is above this; 4 slots across)


def concept_steps():
    """The concept's top row: the 4 steps of the grub turning into a lure, left to right."""
    px = ia.load(R + CONCEPT)
    fg = ibn.key_mask(px)
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=2))
    lab = np.where(fg, lab, 0)
    idx = np.arange(1, n + 1)
    sizes = ndimage.sum(fg, lab, idx)
    cms = ndimage.center_of_mass(fg, lab, idx)
    slot = np.full(n + 1, -1, int)
    sw = px.shape[1] / 4.0
    for i, (sz, cm) in enumerate(zip(sizes, cms)):
        if sz >= 12 and cm[0] < STEP_ROW_Y:
            slot[i + 1] = int(min(3, cm[1] // sw))
    fl = slot[lab]
    return [crop(px, (fl == k) & fg)[0] for k in range(4)]


def crop(px, m):
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    img = px[y0:y1, x0:x1].copy()
    img[..., 3] = np.where(m[y0:y1, x0:x1], 255, 0)
    return img, np.array([x0, y0], float)


def brown(im):
    rgb = im[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (im[..., 3] > 0) & (r >= 55) & (r <= 190) & (g >= r * 0.45) & (g <= r * 0.85) & (b <= r * 0.7)


def mud(im):
    """The ground point of a frame: the bottom middle of its mud (the lowest band of brown)."""
    m = brown(im)
    ys, xs = np.nonzero(m)
    if len(ys) < 100:
        return ibn.anchor_of(im), 0.0
    bot = float(np.percentile(ys, 99))
    low = ys > bot - 25
    return (float(xs[low].mean()), bot), float(np.percentile(xs, 98) - np.percentile(xs, 2))


def top_of(im):
    return float(np.nonzero((im[..., 3] > 0).any(1))[0].min())


def strip_frame(kind, strip, i):
    info = open("scripts/art_data.gd").read()
    im = np.array(Image.open(f"{ia.OUT}/units/{kind}/{strip}.png").convert("RGBA")).astype(np.int32)
    # (the frame count: the strip's width over the cell's)
    import re
    m = re.search(r'\t"' + kind + r'": \{"cell": Vector2i\((\d+), (\d+)\)', info)
    w = int(m.group(1))
    return im[:, i * w:(i + 1) * w]


def tint(im, col):
    """The concept's yellow-green haze and glowing scent holes turned toward col (kept as bright as drawn)."""
    if col is None:
        return im
    out = im.copy()
    rgb = im[..., :3].astype(float)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    glow = (im[..., 3] > 0) & (g > 110) & (g >= r * 0.95) & (b < g * 0.75) & (g - b > 50)
    lum = (0.3 * r + 0.59 * g + 0.11 * b) / 160.0
    c = np.array(col, float)
    for k in range(3):
        ch = out[..., k].astype(float)
        ch[glow] = np.clip(c[k] * lum[glow] * 1.05, 0, 255)
        out[..., k] = ch.astype(out.dtype)
    return out


def storm_white(im):
    """The sheet's blue haze turned storm-cloud white: each blue pixel a cool light grey at about its brightness."""
    out = im.copy()
    rgb = im[..., :3].astype(float)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    blue = (im[..., 3] > 0) & (b > r + 20) & (b >= g) & (b > 60)
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    v = np.clip(lum * 1.08 + 28, 0, 255)
    for k, m in enumerate((0.95, 0.97, 1.0)):
        ch = out[..., k].astype(float)
        ch[blue] = np.clip(v[blue] * m, 0, 255)
        out[..., k] = ch.astype(out.dtype)
    return out


def snap(im):
    """Team colour on the bright red spikes and the dark red right beside them; the darker red haze stays as drawn."""
    r, g, b = im[..., 0].astype(int), im[..., 1].astype(int), im[..., 2].astype(int)
    red = (im[..., 3] > 0) & (r >= 100) & (g <= r * 0.3) & (b <= r * 0.32)
    light = red & (r >= 175)
    near = ndimage.binary_dilation(light, iterations=2)
    dark = red & ~light & near
    im[light, :3] = ia.TEAM_LIGHT
    im[dark, :3] = ia.TEAM_DARK
    return _unteam_rest(im, light | dark)


def _unteam_rest(im, team):
    """Exact key reds that are not team colour (none expected) nudged off the keys."""
    rest = ~team
    m = rest & (im[..., 0] == 255) & (im[..., 1] == 0) & (im[..., 2] == 0)
    im[m, 1] = 18
    m = rest & (im[..., 0] == 150) & (im[..., 1] == 0) & (im[..., 2] == 0)
    im[m, 1] = 12
    return im


def do_kind(kind):
    px = ia.load(R + ARRIVE % kind)
    masks = slot_masks(px)
    crops = [crop(px, m) for m in masks]
    # his last frame: his feet, the mud under them (where the lure was), his height
    im12, o12 = crops[11]
    f12 = np.array(ibn.claw_feet(im12)) + o12
    m12 = np.array(mud(im12)[0]) + o12
    D = m12 - f12
    h12 = f12[1] - (top_of(im12) + o12[1])
    ref = strip_frame(kind, *REF[kind])
    rf = ibn.claw_feet(ref)
    s = (rf[1] - top_of(ref)) / h12
    print(f"  {kind}: scale {s:.3f} (his last frame {h12:.0f} px tall, his {REF[kind][0]} {rf[1] - top_of(ref):.0f})")
    placed = {}           # name -> [(image, top-left from the feet)]
    arrive = []
    for i in range(2 * COLS):
        j = HOLD.get(kind, {}).get(i, i)
        im, o = crops[j]
        if j < COLS:
            gp, _ = mud(im)
            ref_pt = np.array(gp) + o - D          # (the lure's mud where the last frame's mud is)
        else:
            ref_pt = np.array(ibn.claw_feet(im)) + o
        small = snap(ia.shrink(im, s))
        if kind in WHITE:
            small = storm_white(small)
        arrive.append((small, (o - ref_pt) * s))
    placed["arrive"] = arrive
    placed["ripe"] = [arrive[0]]
    # the growing lure: the concept's 4 steps, as wide (mud) as the ripe lure, on its mud
    _, w1 = mud(crops[0][0])
    steps = concept_steps()
    gp4, w4 = mud(steps[3])
    sc = s * w1 / max(w4, 1.0)
    grow = []
    for st in steps:
        gp, _ = mud(st)
        small = snap(ia.shrink(tint(st, TINT[kind]), sc))
        grow.append((small, (-np.array(gp)) * sc + D * s))
    placed["grow"] = grow
    print(f"  {kind}: Defs.NB \"lure_at\": [{D[0] * s:.0f}, {D[1] * s:.0f}, {w1 * s:.0f}]   (the lure's ground point from his feet; its mud's width)")
    return placed


def assemble(kind, placed, data):
    L = R_ = U = Dn = 0.0
    for lst in placed.values():
        for im, (x, y) in lst:
            L = max(L, -x); R_ = max(R_, x + im.shape[1]); U = max(U, -y); Dn = max(Dn, y + im.shape[0])
    half = int(np.ceil(max(L, R_))) + 1
    W, top = 2 * half, int(np.ceil(U)) + 1
    H = top + int(np.ceil(Dn)) + 1
    name = f"lure_{kind}"
    os.makedirs(f"{ia.OUT}/units/{name}", exist_ok=True)
    counts = {}
    for anim, lst in placed.items():
        strip = np.zeros((H, W * len(lst), 4), np.uint8)
        for k, (im, (x, y)) in enumerate(lst):
            ox, oy = int(round(half + x)), int(round(top + y))
            h, w = im.shape[:2]
            m = im[..., 3] > 0
            cell = strip[:, k * W:(k + 1) * W]
            cell[oy:oy + h, ox:ox + w][m] = im[m]
        ia.save(strip, f"{ia.OUT}/units/{name}/{anim}_se.png")
        counts[f"{anim}_se"] = len(lst)
    data[name] = {"cell": (W, H), "anchor": (half, top), "frames": counts}
    print(f"  {name}: cell {W}x{H}, " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))


def contact(d, kind, data):
    """A look: every strip on grass, the anchor marked; and the hand-over: the last arrival frame beside his first
    rooting frame on the same feet."""
    os.makedirs(d, exist_ok=True)
    name = f"lure_{kind}"
    e = data[name]
    W, H = e["cell"]
    ax, ay = e["anchor"]
    rows = []
    for anim in ("grow", "ripe", "arrive"):
        im = Image.open(f"{ia.OUT}/units/{name}/{anim}_se.png").convert("RGBA")
        rows.append(im)
    # his rooting frame 0 on the same feet
    info = ibn.__dict__
    ri = Image.open(f"{ia.OUT}/units/{kind}/root_se.png").convert("RGBA")
    import re
    src = open("scripts/art_data.gd").read()
    m = re.search(r'\t"' + kind + r'": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\(([\d.]+), ([\d.]+)\)', src)
    cw, chh, kax, kay = int(m.group(1)), int(m.group(2)), float(m.group(3)), float(m.group(4))
    root0 = ri.crop((0, 0, cw, chh))
    last = rows[2].crop((11 * W, 0, 12 * W, H))
    pair = Image.new("RGBA", (W * 2, H), (70, 100, 60, 255))
    pair.alpha_composite(last, (0, 0))
    pair.alpha_composite(root0, (int(W + ax - kax), int(ay - kay)))
    rows.append(pair)
    tw = max(r.width for r in rows)
    out = Image.new("RGBA", (tw, sum(r.height for r in rows)), (70, 100, 60, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        for k in range(r.width // W):
            for dx in range(-3, 4):
                out.putpixel((min(tw - 1, k * W + ax + dx), y + ay), (255, 255, 255, 255))
        y += r.height
    out.save(f"{d}/{name}.png")


def main():
    contact_dir = sys.argv[sys.argv.index("--contact") + 1] if "--contact" in sys.argv else ""
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
    data = {}
    for kind in KINDS:
        if only and kind != only:
            continue
        print(kind)
        placed = do_kind(kind)
        assemble(kind, placed, data)
        ibn.write_entry(f"lure_{kind}", data[f"lure_{kind}"])
        if contact_dir:
            contact(contact_dir, kind, data)


if __name__ == "__main__":
    main()
