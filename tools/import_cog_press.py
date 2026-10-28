"""The Clockwork COG PRESS from the owner's ChatGPT drawing art/redraws/cog_press_chatgpt.png (1536x1024, dark navy
background, three drawings in a row labelled PRESS DOWN, PRESS MIDDLE, PRESS UP: an open iron gantry press facing
south-east, a crate of cogs at the front right, a tray at the left). It replaces the old squat press (2026-10-28: it looked
too much like the Mainspring and faced south-west). The Mainspring stays as it is.

Steps (re-runnable, python3 -I tools/import_cog_press.py [--contact DIR]):
  1. Key out the navy: every pixel more than KEY from the background colour (sampled from the border) is the drawing; the
     three drawings are the three big pieces (specks within a few px of one go with it, the labels are dropped); pockets of
     the background smaller than HOLE px inside a drawing are its own dark shading and are filled back in; the dark-blue
     fringe left by the key is eaten back one px.
  2. Line the three up: each is moved so its frame (the top of the gantry, the feet, the crate) sits on the PRESS UP
     drawing's (best shift by least difference, a few px at the drawing's scale).
  3. The working loop (WORK frames): only the RAM moves inside a fixed frame, so the frames are made from the PRESS UP
     drawing, the clearest one: the ram (brass piston, grey guide bar and the stamping head) is cut out and drawn lower,
     the piston rod drawn out of its sleeve (a plain band of the rod repeated), down into the cog tray; the tray's front rim
     and the posts in front of it stay in front of the head. The down and middle drawings have an anvil where the up drawing
     has the tray, so they are kept only as the reference for how far the head comes down (the head stops on the cog in the
     tray). DROP: the drop of each frame (0 up .. 1 on the cog): an eased fall (fast at the end, a hit), a hold on the
     cog (STAMP_FRAME: the stamp sound, scripts/building.gd), a slower rise, a short rest at the top.
  4. The other pictures, made from the built picture (code-drawn: listed in docs/art_style_inconsistency.md):
       construction  the frame up to its middle, no crossbar or ram, timber scaffolding and a ladder, the crate there
       damaged       scorched, a corner post and a crossbar piece broken off, the head hanging askew, a smoke wisp,
                     fallen cogs and iron bits at its feet
       destroyed     a heap: the feet and the crate, the posts fallen across, the crossbar and the head in the wreck,
                     scattered cogs
  5. Shrink to the game (SCALE: the frame's footprint about as wide as the old press's), box filter with premultiplied
     alpha, hard alpha; the brightness brought to the other Clockwork buildings' (Mainspring, Escapement, Clocktower);
     the painted red bars snapped to the two key reds the team shader repaints (255,0,0 / 150,0,0), as on the
     Clocktower; any other near-key pixel nudged off the key.
Writes:
  art/clockwork/gear/cog_press_{built,construct,damaged,destroyed,work_N}.png  the pictures at the drawing's scale
  assets/buildings/cog_press_{built,construction,damaged,destroyed}.png, cog_press_work_0..WORK-1.png   one canvas,
      the base bottom-centre on the canvas's bottom-centre (Building.body_offset: bottom 6 px below the footprint)
  assets/icons/cog_press.png  the 64x64 card portrait (the upper body of the built picture)
  --contact DIR: DIR/cog_press_contact.png (every picture, 3x) and DIR/cog_press_work.gif (the loop at game speed).
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'art/redraws/cog_press_chatgpt.png')
CANVAS = os.path.join(ROOT, 'art/clockwork/gear/')
DST = os.path.join(ROOT, 'assets/buildings/')
ICON = os.path.join(ROOT, 'assets/icons/cog_press.png')

KEY = 18            # colour distance (sum of |dr|+|dg|+|db|) from the navy that counts as drawing
HOLE = 700          # background pockets smaller than this (drawing px) inside a drawing are filled back in
SCALE = 0.215       # drawing px -> game px (the frame with its tray ~108 px wide, like the old press's 108)
FRAME_DT = 0.09     # seconds a work frame (scripts/building.gd passes it to _gear_anim; the old loop: 8 x 0.11 s)
# drop of the ram per work frame, 0 (up, as drawn) .. 1 (the head on the cog): rest, eased fall, the hit and a hold, a slower rise
DROP = [0.0, 0.07, 0.26, 0.58, 1.0, 1.0, 0.9, 0.74, 0.56, 0.38, 0.21, 0.08]
WORK = len(DROP)
STAMP_FRAME = 4     # the frame the head hits the cog (scripts/building.gd plays work/cog_press_stamp on it)

# --- the ram in the PRESS UP drawing (its own crop's px) ---
RAM_BOX = (192, 250, 324, 352)    # x0, y0, x1, y1: the moving part (rod, guide bar below the collar, the head)
RAM_TOP = 250                      # rows above stay (the sleeve and the guide bar's collar under the crossbar)
BAND = (262, 263)                  # a plain row of the rod and the guide bar, repeated as the rod comes out of its sleeve
DROP_PX = 150                      # the head's drop onto the cog in the tray
# the tray's front rims (in front of the head when it is down): front-left (170,458)-(246,501), front-right (246,501)-(330,456)
RIM = [(160, 453), (246, 501), (334, 455)]
TEAM_LIGHT, TEAM_DARK = (255, 0, 0), (150, 0, 0)


# ------------------------------------------------------------------ cut out
def cut_drawings():
    a = np.array(Image.open(SRC).convert('RGB')).astype(int)
    border = np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)])
    bg = np.median(border, 0)
    d = np.abs(a - bg).sum(2)
    m = d > KEY
    lab, n = ndi.label(m)
    sz = ndi.sum(m, lab, range(1, n + 1))
    big = sorted([i + 1 for i, z in enumerate(sz) if z > 20000], key=lambda i: np.where(lab == i)[1].min())
    assert len(big) == 3, 'expected three drawings, found %d' % len(big)
    out = []
    for i in big:
        core = lab == i
        keep = m & ndi.binary_dilation(core, iterations=4)
        # the drawing's own dark shading keyed out as background: small pockets inside it filled back in
        holes = ndi.binary_fill_holes(keep) & ~keep
        hl, hn = ndi.label(holes)
        if hn:
            hs = ndi.sum(holes, hl, range(1, hn + 1))
            small = np.isin(hl, [k + 1 for k, z in enumerate(hs) if z < HOLE])
            keep |= small
        # fringe: the outermost px that are still dark and blue-ish (the navy blended into the outline)
        edge = keep & ~ndi.binary_erosion(keep, border_value=0)
        bluish = (a[..., 2] >= a[..., 0]) & (a.sum(2) < 120)
        keep &= ~(edge & bluish)
        ys, xs = np.where(keep)
        box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        o = np.zeros(a.shape[:2] + (4,), np.uint8)
        o[..., :3] = a
        o[..., 3] = keep * 255
        out.append(o[box[1]:box[3], box[0]:box[2]])
    return out    # DOWN, MIDDLE, UP


def align(ims):
    """Shift DOWN and MIDDLE so their frame sits on UP's: least mean difference over the top of the gantry, the left foot
    and the crate (the ram and the tray differ)."""
    up = ims[2].astype(float)
    regs = [(60, 0, 440, 160), (60, 560, 180, 720), (300, 600, 490, 750)]
    out = [None, None, ims[2]]
    for k in (0, 1):
        im = ims[k].astype(float)
        best = None
        for dy in range(-10, 11):
            for dx in range(-10, 11):
                e = 0.0
                for x0, y0, x1, y1 in regs:
                    if y0 + dy < 0 or x0 + dx < 0 or y1 + dy > im.shape[0] or x1 + dx > im.shape[1]:
                        e = 1e9
                        break
                    e += np.abs(im[y0 + dy:y1 + dy, x0 + dx:x1 + dx, :3] - up[y0:y1, x0:x1, :3]).mean()
                if best is None or e < best[0]:
                    best = (e, dx, dy)
        _, dx, dy = best
        P = 20
        src = ims[k]
        big = np.zeros((max(src.shape[0], up.shape[0]) + 2 * P, max(src.shape[1], up.shape[1]) + 2 * P, 4), np.uint8)
        big[P:P + src.shape[0], P:P + src.shape[1]] = src
        out[k] = big[P + dy:P + dy + up.shape[0], P + dx:P + dx + up.shape[1]].copy()
        print('aligned', ['down', 'middle'][k], 'by', (dx, dy))
    return out


# ------------------------------------------------------------------ the working loop
def ram_parts(up):
    """The PRESS UP picture without its moving ram, the ram (RGBA, the RAM_BOX crop) and its mask."""
    x0, y0, x1, y1 = RAM_BOX
    al = up[..., 3] > 0
    box = np.zeros(al.shape, bool)
    box[y0:y1, x0:x1] = True
    lab, n = ndi.label(al & box)
    # the ram: the piece(s) of the box touching its top row between the sleeve's and the bar's edges, and the head
    ids = set(lab[y0, 200:310][lab[y0, 200:310] > 0].tolist())
    ram = np.isin(lab, list(ids))
    base = up.copy()
    base[ram] = 0
    part = np.zeros_like(up)
    part[ram] = up[ram]
    return base, part, ram


def rim_mask(shape):
    """Drawing px below the tray's front rims (in front of a head that has come down into the tray)."""
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
    line = np.full(shape[1], 1e9)
    for (ax, ay), (bx, by) in zip(RIM, RIM[1:]):
        xs = np.arange(ax, bx + 1)
        line[xs] = ay + (by - ay) * (xs - ax) / float(bx - ax)
    return yy > line[None, :]


def work_frame(up, base, part, drop):
    d = int(round(drop * DROP_PX))
    f = base.copy()
    if d == 0:
        return up.copy()
    lay = np.zeros_like(up)
    # the rod drawn out of its sleeve: BAND repeated over the gap, then the lower ram shifted down
    band = part[BAND[0]:BAND[1]]
    for y in range(RAM_TOP, RAM_TOP + d):
        lay[y] = band[(y - RAM_TOP) % band.shape[0]]
    lay[RAM_TOP + d:] = part[RAM_TOP:part.shape[0] - d]
    on = lay[..., 3] > 0
    front = rim_mask(up.shape[:2]) & (base[..., 3] > 0)
    put = on & ~front
    f[put] = lay[put]
    return f


# ------------------------------------------------------------------ the other pictures
WOOD = [(58, 36, 20), (96, 62, 32), (138, 94, 52), (176, 128, 74)]
IRON = [(30, 30, 34), (62, 62, 68), (98, 98, 106), (140, 140, 148)]


def beam(dr, p, q, w, cols):
    """A shaded timber/iron beam from p to q, w px wide (drawing scale): dark outline, body, a light edge."""
    dr.line([p, q], fill=(14, 10, 8, 255), width=w + 6)
    dr.line([p, q], fill=cols[1] + (255,), width=w)
    dx, dy = q[0] - p[0], q[1] - p[1]
    n = max(1.0, (dx * dx + dy * dy) ** 0.5)
    ox, oy = -dy / n * w * 0.28, dx / n * w * 0.28
    dr.line([(p[0] - ox, p[1] - oy), (q[0] - ox, q[1] - oy)], fill=cols[2] + (255,), width=max(2, w // 3))
    dr.line([(p[0] + ox, p[1] + oy), (q[0] + ox, q[1] + oy)], fill=cols[0] + (255,), width=max(2, w // 4))


def paste(dst, src, x, y):
    """Alpha-over src (RGBA array) onto dst at (x, y), clipped."""
    h, w = src.shape[:2]
    X0, Y0 = max(0, x), max(0, y)
    X1, Y1 = min(dst.shape[1], x + w), min(dst.shape[0], y + h)
    if X1 <= X0 or Y1 <= Y0:
        return
    s = src[Y0 - y:Y1 - y, X0 - x:X1 - x]
    m = s[..., 3] > 0
    dst[Y0:Y1, X0:X1][m] = s[m]


def crop_part(im, box, mask_fn=None):
    x0, y0, x1, y1 = box
    c = im[y0:y1, x0:x1].copy()
    if mask_fn is not None:
        c[~mask_fn(c)] = 0
    return c


def rotate(c, deg):
    return np.array(Image.fromarray(c, 'RGBA').rotate(deg, resample=Image.NEAREST, expand=True))


def scorch(im, seed, amount=0.55, n=9):
    rng = np.random.RandomState(seed)
    h, w = im.shape[:2]
    blot = np.zeros((h, w), np.float32)
    for _ in range(n):
        cx, cy = rng.randint(60, w - 60), rng.randint(80, h - 60)
        r = rng.randint(28, 70)
        yy, xx = np.ogrid[0:h, 0:w]
        blot = np.maximum(blot, np.clip(1.0 - np.hypot((xx - cx) / r, (yy - cy) / (r * 0.8)), 0, 1))
    noise = ndi.gaussian_filter(rng.rand(h, w).astype(np.float32), 3)
    k = np.clip(blot * (0.6 + noise), 0, 1) * amount
    out = im.copy()
    out[..., :3] = (im[..., :3] * (1.0 - k[..., None]) + np.array([20, 14, 10]) * k[..., None]).clip(0, 255)
    return out


def smoke(dr, x, y, seed, n=5):
    """A wisp of grey puffs rising from (x, y), drifting right."""
    rng = np.random.RandomState(seed)
    for k in range(n):
        r = 9 + k * 4
        g = 128 - k * 10
        cx, cy = x + k * 7 + rng.randint(-3, 4), y - k * 24
        dr.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(g, g, g + 6, 255))
        dr.ellipse((cx - r * 0.7, cy - r * 0.9, cx + r * 0.2, cy - r * 0.1), fill=(g + 28, g + 28, g + 32, 255))


def loose_cogs(up, n, area, seed, dst):
    """n cogs copied from the crate (the brightest brass round pieces) scattered in area (x0, y0, x1, y1), lying flat."""
    rng = np.random.RandomState(seed)
    cog = crop_part(up, (330, 600, 390, 652), lambda c: (c[..., 0].astype(int) > 120) & (c[..., 0].astype(int) > c[..., 2].astype(int) + 50))
    for _ in range(n):
        c = rotate(cog, rng.randint(0, 360))
        s = rng.uniform(0.7, 1.0)
        c = np.array(Image.fromarray(c, 'RGBA').resize((max(1, int(c.shape[1] * s)), max(1, int(c.shape[0] * s * 0.6))), Image.NEAREST))
        paste(dst, c, rng.randint(area[0], area[2]), rng.randint(area[1], area[3]))


def construction(up, base):
    """The frame up to about its middle (cut ragged), no crossbar, no ram, no tray; the crate at its feet; timber
    scaffolding round it with a plank deck at the cut, a ladder up the left side, a beam hanging from a rope."""
    h, w = up.shape[:2]
    f = base.copy()
    yy = np.arange(h)[:, None]
    rag = 330 + (np.sin(np.arange(w) * 0.21) * 6).astype(int)[None, :]
    f[yy < rag] = 0
    f[:430, :100] = 0          # the tray and its lever: not fitted yet
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    # behind the frame: two back poles and a plank between them
    for x, y0, y1 in [(160, 160, 600), (395, 130, 560)]:
        beam(dr, (x, y0), (x, y1), 16, WOOD)
    beam(dr, (150, 250), (405, 215), 14, WOOD)
    out = np.array(im)
    paste(out, f, 0, 0)
    im = Image.fromarray(out, 'RGBA')
    dr = ImageDraw.Draw(im)
    # in front: two poles at the outer corners (clear of the crate), the deck at the cut, braces, a top rail with a rope
    for x, y0, y1 in [(78, 200, 700), (478, 190, 640)]:
        beam(dr, (x, y0), (x, y1), 18, WOOD)
    beam(dr, (66, 336), (490, 318), 16, WOOD)
    beam(dr, (66, 214), (490, 196), 14, WOOD)
    beam(dr, (78, 470), (160, 340), 10, WOOD)
    beam(dr, (478, 450), (400, 330), 10, WOOD)
    # the ladder up the left
    for x in (14, 52):
        beam(dr, (x, 360), (x + 30, 720), 8, WOOD)
    for k in range(10):
        y = 384 + k * 34
        o = (y - 360) * 30 // 360
        beam(dr, (14 + o, y), (52 + o, y), 6, WOOD)
    # a beam of the crossbar on its rope, waiting to go up
    dr.line([(300, 205), (300, 262)], fill=(44, 32, 20, 255), width=5)
    beam(dr, (240, 270), (360, 262), 18, IRON)
    return np.array(im)


PAD = 120    # rows of room above a picture (the damaged press's smoke)


def damaged(up, part):
    """Scorched; the front-right top corner broken off (its cap and the crossbar's end lie at the left foot); the tray torn off
    and lying on the ground; the head hanging askew; a smoke wisp from the break; iron bits and cogs at its feet."""
    h, w = up.shape[:2]
    f = scorch(up, 3, 0.5, 8)
    yy, xx = np.mgrid[0:h, 0:w]
    # the top right corner: the cap and the crossbar ends round it, cut along a jagged line
    gone = (xx > 352) & (yy < 150 + (xx - 352) * 0.15 + np.sin(xx * 0.9) * 6) & (yy > 40)
    gone &= (yy < 128 + np.sin(xx * 0.7) * 7) | (xx > 380)
    gone &= yy < 165
    cap = crop_part(up, (352, 40, 440, 170))
    cap[~gone[40:170, 352:440]] = 0
    f[gone] = 0
    # the tray torn off (left of the frame, above its lever)
    tray = crop_part(up, (0, 300, 92, 420))
    f[300:420, 0:92] = 0
    # the head askew: the moving ram tilted a little about its top
    ram = part[RAM_TOP:352, 180:340].copy()
    f[RAM_TOP:352, 180:340][ram[..., 3] > 0] = 0
    tilt = np.array(Image.fromarray(ram, 'RGBA').rotate(-7, resample=Image.NEAREST, center=(78, 0)))
    out = np.zeros((h + PAD, w, 4), np.uint8)
    paste(out, f, 0, PAD)
    paste(out, tilt, 180, PAD + RAM_TOP)
    paste(out, rotate(tray, 18), 0, PAD + 640)
    paste(out, rotate(cap, 64), 120, PAD + 660)
    im = Image.fromarray(out, 'RGBA')
    dr = ImageDraw.Draw(im)
    for p, q in [((20, 742), (70, 752)), ((420, 752), (470, 742))]:
        beam(dr, (p[0], p[1] + PAD), (q[0], q[1] + PAD), 7, IRON)
    out = np.array(im)
    loose_cogs(up, 4, (40, PAD + 700, 300, PAD + 745), 9, out)
    sm = Image.new('RGBA', (w, h + PAD), (0, 0, 0, 0))
    smoke(ImageDraw.Draw(sm), 386, PAD + 120, 4)
    sm = np.array(sm)
    m = sm[..., 3] > 0
    m[PAD + 150:] = False
    out[m] = sm[m]
    return out


def destroyed(up):
    """A heap where the press stood: the feet and the crate, ragged; the gantry top fallen on them with its gear; broken
    posts across; the head in the wreck; scattered cogs and iron; scorched."""
    h, w = up.shape[:2]
    f = np.zeros_like(up)
    keep = up.copy()
    yy, xx = np.mgrid[0:h, 0:w]
    rag = 610 + (np.sin(xx * 0.13) * 18 + np.sin(xx * 0.41) * 8).astype(int)
    keep[yy < rag] = 0
    keep[:, :60] = 0
    top = crop_part(up, (96, 0, 436, 190))
    post_a = crop_part(up, (100, 200, 160, 400))
    post_b = crop_part(up, (380, 220, 440, 360))
    head = crop_part(up, (192, 270, 324, 352))
    # behind: a post leaning, the fallen top
    paste(f, rotate(post_b, -66), 270, 545)
    t = rotate(top, -9)
    t = np.array(Image.fromarray(t, 'RGBA').resize((int(t.shape[1] * 0.92), int(t.shape[0] * 0.7)), Image.NEAREST))
    paste(f, t, 70, 520)
    paste(f, keep, 0, 0)
    paste(f, rotate(post_a, 74), 40, 615)
    paste(f, rotate(head, 16), 170, 590)
    loose_cogs(up, 8, (70, 690, 330, 745), 13, f)
    im = Image.fromarray(f, 'RGBA')
    dr = ImageDraw.Draw(im)
    for p, q in [((70, 748), (140, 738)), ((300, 754), (360, 744))]:
        beam(dr, p, q, 8, IRON)
    return scorch(np.array(im), 21, 0.6, 10)


# ------------------------------------------------------------------ to the game
def shrink(img, scale):
    """Box-filter downscale with premultiplied alpha, then hard alpha (as tools/import_art.py)."""
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((nw, nh), Image.BOX)).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.5, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def tone(img, gain):
    out = img.copy()
    out[..., :3] = (img[..., :3].astype(np.float32) * gain).clip(0, 255)
    return out


def team(img):
    """The painted red bars -> the two key reds (light / shade); any other near-key pixel nudged off the key."""
    r, g, b = [img[..., i].astype(int) for i in range(3)]
    on = img[..., 3] > 0
    red = on & (r >= 105) & (g <= r * 0.32) & (b <= r * 0.34)
    light = red & (r >= 178)
    img[light, :3] = TEAM_LIGHT
    img[red & ~light, :3] = TEAM_DARK
    rgb = img[..., :3].astype(np.float32) / 255.0
    near = on & ~red & ((np.sqrt(((rgb - [1, 0, 0]) ** 2).sum(2)) < 0.1) | (np.sqrt(((rgb - [150 / 255.0, 0, 0]) ** 2).sum(2)) < 0.1))
    img[near, 1] = np.maximum(img[near, 1], 30)
    img[near, 2] = np.maximum(img[near, 2], 18)
    return img


def mean_lum(paths):
    vals = []
    for p in paths:
        a = np.array(Image.open(p).convert('RGBA')).astype(float)
        on = a[..., 3] > 0
        vals.append(a[..., :3][on].mean())
    return float(np.mean(vals))


def main():
    contact = None
    if '--contact' in sys.argv:
        contact = sys.argv[sys.argv.index('--contact') + 1]
    down, middle, up = align(cut_drawings())
    base, part, _ = ram_parts(up)
    pics = {'built': up}
    for i, dp in enumerate(DROP):
        pics['work_%d' % i] = work_frame(up, base, part, dp)
    pics['construct'] = construction(up, base)
    pics['damaged'] = damaged(up, part)
    pics['destroyed'] = destroyed(up)
    # one canvas for all: the union of their boxes, symmetric about the drawing's frame centre, down to the bottom
    H = max(p.shape[0] for p in pics.values())
    W = up.shape[1]
    os.makedirs(CANVAS, exist_ok=True)
    for f in os.listdir(CANVAS):
        if f.startswith('cog_press_work_') and f.endswith('.png'):
            os.remove(os.path.join(CANVAS, f))
    for n, p in pics.items():
        c = np.zeros((H, W, 4), np.uint8)
        c[H - p.shape[0]:, :p.shape[1]] = p[:, :W]
        pics[n] = c
        Image.fromarray(c, 'RGBA').save(CANVAS + 'cog_press_%s.png' % n)
    # the brightness of the other Clockwork buildings
    ref = mean_lum([DST + '%s_built.png' % k for k in ('mainspring', 'escapement', 'clocktower', 'heavy_works')])
    small = {n: shrink(p, SCALE) for n, p in pics.items()}
    gain = ref / max(1.0, small['built'][..., :3][small['built'][..., 3] > 0].mean())
    gain = float(np.clip(gain, 0.85, 1.15))
    print('brightness: reference %.1f, gain %.3f' % (ref, gain))
    boxes = [s[..., 3].nonzero() for s in small.values()]
    sh, sw = small['built'].shape[:2]
    left = min(int(b[1].min()) for b in boxes)
    right = max(int(b[1].max()) + 1 for b in boxes)
    top = min(int(b[0].min()) for b in boxes)
    half = max(sw / 2.0 - left, right - sw / 2.0)
    x0 = int(np.floor(sw / 2.0 - half))
    x1 = int(np.ceil(sw / 2.0 + half))
    # the canvas: centred on the drawing's frame (its feet), the bottom row the drawing's bottom
    for f in os.listdir(DST):
        if f.startswith('cog_press_work_') and f.endswith('.png') and int(f[15:-4]) >= WORK:
            os.remove(os.path.join(DST, f))
            if os.path.exists(os.path.join(DST, f + '.import')):
                os.remove(os.path.join(DST, f + '.import'))
    out = {}
    for n, s in small.items():
        pad = np.zeros((sh - top, x1 - x0, 4), np.uint8)
        xa, xb = max(0, x0), min(sw, x1)
        pad[:, xa - x0:xb - x0] = s[top:, xa:xb]
        img = team(tone(pad, gain))
        out[n] = img
        name = {'construct': 'construction'}.get(n, n)
        Image.fromarray(img, 'RGBA').save(DST + 'cog_press_%s.png' % name)
    print('sprites', out['built'].shape[1], 'x', out['built'].shape[0], '(%d work frames)' % WORK)
    # the portrait: the upper body, square
    b = out['built']
    ys, xs = b[..., 3].nonzero()
    side = int(xs.max() + 1 - xs.min())
    y0 = int(ys.min()) + 4
    crop = Image.fromarray(b, 'RGBA').crop((int(xs.min()), y0, int(xs.min()) + side, y0 + side))
    crop.resize((64, 64), Image.LANCZOS).save(ICON)
    if contact:
        os.makedirs(contact, exist_ok=True)
        names = ['built', 'construct', 'damaged', 'destroyed'] + ['work_%d' % i for i in range(WORK)]
        cw, chh = out['built'].shape[1], out['built'].shape[0]
        sheet = Image.new('RGBA', ((cw + 6) * 8 * 3, (chh + 6) * 2 * 3), (52, 74, 48, 255))
        for i, n in enumerate(names):
            im = Image.fromarray(out[n], 'RGBA').resize((cw * 3, chh * 3), Image.NEAREST)
            sheet.alpha_composite(im, ((i % 8) * (cw + 6) * 3, (i // 8) * (chh + 6) * 3))
        sheet.save(os.path.join(contact, 'cog_press_contact.png'))
        fr = []
        for i in range(WORK):
            bgi = Image.new('RGBA', (cw * 3, chh * 3), (52, 74, 48, 255))
            bgi.alpha_composite(Image.fromarray(out['work_%d' % i], 'RGBA').resize((cw * 3, chh * 3), Image.NEAREST))
            fr.append(bgi.convert('RGB'))
        fr[0].save(os.path.join(contact, 'cog_press_work.gif'), save_all=True, append_images=fr[1:], duration=int(FRAME_DT * 1000), loop=0)
        print('contact sheet and GIF in', contact)


if __name__ == '__main__':
    main()
