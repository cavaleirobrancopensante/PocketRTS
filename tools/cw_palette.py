"""THE CLOCKWORK UNITS' PALETTE (owner, 2026-10-26): every Clockwork UNIT is BRASS + PLAYER COLOUR.

The rule (units only; the buildings keep their painted reds):
  - PLAYER COLOUR is the team shader's two key reds (shaders/team.gdshader: (255,0,0) -> the player's colour, (150,0,0) ->
    0.6 x it). The painted red parts stay player colour (with the orange-red seams and rim light ChatGPT paints into
    them, which would show as orange stripes on another colour), and every part painted BLUE becomes player colour too:
    ball joints, shoulders, knee gems, wing-root springs, eyes. No blue is left anywhere. Both are put on one pure red
    ramp by their value, so their painted shading lands on the light or the dark key. (No third, darker key: tried, the
    gain was slight at game size, and about 70,000 pixels of other units and buildings of all three factions lie within
    reach of a key at (80,0,0) and would turn team colour.)
  - BRASS stays brass, WHITE stays white (the clock faces), the dark OUTLINES, the STEEL and IRON greys stay as painted.
  - STEEL that is tinted blue (the Jack's coil spring, drill tips and inner arm segments, the Pendulum's blade) is metal,
    not paint: it keeps its own colour, only greyed toward steel when it is bluer than STEEL_SAT (a ChatGPT sheet that
    paints the steel saturated blue comes out like the older, greyer ones).
  - Per unit: the CLOCK SOLDIER's round body becomes BRASS (it was red) and its HEAD (the cap with the crown spike on top
    of the body) becomes player colour, so it reads apart from the JACK, which keeps its red (player colour) body.

For future art (what the importers expect): paint the team parts in one clean, saturated red ramp (a light, a mid and a
shadow red; highlights white rather than pink), the steel in neutral greys (a hint of blue at most, saturation under
~0.35), and no blue paint at all: anything painted saturated blue is turned into player colour by this step. Brass in
the warm ramp of BRASS below. The dark outlines may be any very dark colour (value under 0.2): they stay as they are.

Entry points (tools/import_clock_soldier.py, import_jack.py, import_cuckoo.py (Swift and Owl) and import_tier3.py
(Pendulum and Netter) call them; another unit's importer switches over by calling the same two):
  recolour(o, unit, ref=None, tilt=0.0, window=16.0, info=None, tipped=False) -> o
        one keyed frame (H x W x 4 uint8, the SHEET's own resolution, alpha 0 = background), BEFORE the shrink and AFTER
        the importer has taken its anchors (they look for the red body); returns a new frame, painted colours. `unit` is
        the art kind ('clock_soldier', 'jack', 'cuckoo', 'ticking_owl', 'pendulum', 'netter'; any other kind gets the
        general rule). The Clock Soldier also needs `ref`: its upright idle frame of the same direction (the cap is found
        on it by its place), or a ready template (template_from: a sheet's own upright first frame and the cap found on
        it, for the rest of that row); and, for a frame where the body tips over, `tilt` (degrees, screen clockwise: the
        guess of where the body's own up axis points), `window` (how far either side of it to look) and tipped=True.
  snap_team(img) -> img
        AFTER the shrink: the team reds to the shader's exact key reds (the light key from r 175 up, the dark key down to
        r 60, so no shaded red keeps its painted colour on another team), red highlights to a neutral light.
Check a sheet against the rule (an overlay per frame: what is player colour, steel, the Clock Soldier's head and body):
  python3 tools/cw_palette.py UNIT SHEET.png ROWS COLS OUT.png [ROW]
"""
import sys
import numpy as np
from scipy import ndimage as ndi

TEAM_LIGHT = (255, 0, 0)
TEAM_DARK = (150, 0, 0)
STEEL_SAT = 0.45          # the most a steel pixel's saturation keeps (the older Jack sheet's coil spring and drill tip)
PAINT_SAT = 0.42          # a blue region this saturated (its median) is paint, not steel (the units' blue-tinted steel: 0.38 at most)
JACK_HUE = 213.0          # the Jack's shoulders are this deep a blue or deeper (~218-222); its steel is cyan-er (~205-211)
# The Clock Soldier's own painted brass (measured on art/redraws/clock_soldier_idle.png: the median colour of its brass
# pixels by value), value -> colour; its body is repainted along it.
BRASS = [(0.15, (40, 23, 10)), (0.225, (58, 33, 13)), (0.325, (83, 46, 16)), (0.425, (108, 59, 17)),
         (0.525, (134, 75, 21)), (0.625, (159, 92, 25)), (0.725, (185, 113, 31)), (0.825, (210, 137, 42)),
         (0.925, (236, 170, 63)), (0.985, (249, 205, 98)), (1.0, (255, 226, 150))]


def hsv(rgb):
    """Hue (degrees), saturation and value (0..1) of an RGB array."""
    a = rgb[..., :3].astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(-1), a.min(-1)
    d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6.0, np.where(mx == g, (b - r) / d + 2.0, (r - g) / d + 4.0)) * 60.0
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    return h % 360.0, s, mx / 255.0


def is_red(h, s, v):
    """The team red family, its dark shading included (not the near-black outline)."""
    return ((h <= 14) | (h >= 346)) & (s >= 0.45) & (v >= 0.12)


def red_parts(o, min_size=150):
    """The team red parts: the blobs of the red family of min_size px or more (a body, a leg, a band: not the darkest rim
    pixels of a brass part, which read as red too), and the orange-red (hue up to 22 degrees) that ChatGPT paints inside
    them as seams, rim light and edges, where it lies in them (closed over 2 px) or on their edge. On another team's
    colour that orange would show as stripes; brass (hue 25 and up) is not taken."""
    al = o[..., 3] > 0
    h, s, v = hsv(o)
    red = al & is_red(h, s, v)
    lab, n = ndi.label(red, structure=np.ones((3, 3)))
    if n == 0:
        return red
    sz = ndi.sum(red, lab, range(1, n + 1))
    big = np.isin(lab, [i + 1 for i in range(n) if sz[i] >= min_size])
    near = ndi.binary_closing(big, iterations=2) | ndi.binary_dilation(big, iterations=1)
    return big | (near & al & (h > 14) & (h <= 22) & (s >= 0.45) & (v >= 0.12))


def is_blue(h, s, v):
    return (h >= 188) & (h <= 258) & (s >= 0.18) & (v >= 0.16)


def is_brass(h, s, v):
    return (h >= 18) & (h <= 62) & (s >= 0.25) & (v >= 0.2)


# ------------------------------------------------------------------ the blue parts: paint or steel

def blue_parts(o, unit):
    """(paint, steel) masks of the frame's blue-hued pixels.
    General rule: each connected blue region is judged as a whole (the dark shading and the light highlight of a ball
    joint go with it): paint when its median saturation is PAINT_SAT or more, else steel.
    The JACK (the owner): only its two ball SHOULDERS are paint. Its coil spring, inner arm segments and drill tips are
    steel however blue a sheet paints them (the two-launcher sheet paints them as saturated as the shoulders, and they
    touch, so a region test cannot tell them apart). The shoulders are the deep blue (hue JACK_HUE and up, saturated)
    blobs fixed to the red body; the steel is a greener, cyan blue. Each blob grows to its whole ball (its highlight and
    dark rim)."""
    al = o[..., 3] > 0
    h, s, v = hsv(o)
    blue = al & is_blue(h, s, v)
    paint = np.zeros_like(blue)
    if not blue.any():
        return paint, blue
    if unit == 'jack':
        core = ndi.binary_opening(blue & (h >= JACK_HUE) & (s >= 0.55), iterations=1)
        red = ndi.binary_dilation(body_mask(o), iterations=6)        # (its red BODY: not the brass plate's dark rim)
        lab, n = ndi.label(core, structure=np.ones((3, 3)))
        for i, sl in enumerate(ndi.find_objects(lab)):
            m = lab[sl] == i + 1
            if m.sum() < 40 or not (m & red[sl]).any():
                continue
            ball = np.zeros_like(blue)
            ball[sl] = ndi.binary_fill_holes(m)
            paint |= ndi.binary_dilation(ball, iterations=3) & blue
        return paint, blue & ~paint
    lab, n = ndi.label(blue, structure=np.ones((3, 3)))
    for i, sl in enumerate(ndi.find_objects(lab)):
        m = lab[sl] == i + 1
        if np.median(s[sl][m]) >= PAINT_SAT:
            paint[sl] |= m
    return paint, blue & ~paint


def to_team(rgb, mask):
    """Painted pixels -> the team red ramp by their value (so their shading lands on the light or the dark key after
    the shrink); a near-white highlight on the part becomes the light red (no pinks after the shrink); the darkest edge
    pixels (value under 0.16) stay as they are."""
    h, s, v = hsv(rgb)
    out = rgb.copy()
    m = mask & (v >= 0.16)
    r = np.clip(v * 255.0, 0, 255)
    out[..., 0] = np.where(m, r, out[..., 0])
    out[..., 1] = np.where(m, r * 0.04, out[..., 1])
    out[..., 2] = np.where(m, r * 0.04, out[..., 2])
    return out


def steel(rgb, mask):
    """Steel tinted bluer than STEEL_SAT -> greyed toward steel (its value kept, the saturation down to STEEL_SAT)."""
    h, s, v = hsv(rgb)
    m = mask & (s > STEEL_SAT)
    if not m.any():
        return rgb
    a = rgb[..., :3].astype(np.float32)
    mx = a.max(-1, keepdims=True)
    k = np.where(s > 0, STEEL_SAT / np.maximum(s, 1e-6), 1.0)[..., None]
    grey = mx - (mx - a) * k               # each channel's distance below the max scaled: saturation x k, value kept
    out = rgb.copy()
    out[..., :3] = np.where(m[..., None], grey.clip(0, 255), a).astype(np.uint8)
    return out


# ------------------------------------------------------------------ the Clock Soldier: brass body, player-colour head

def brass_of(v):
    """The Clock Soldier's brass at value v (0..1)."""
    xs = [p[0] for p in BRASS]
    return np.stack([np.interp(v, xs, [p[1][c] for p in BRASS]) for c in range(3)], -1)


def body_mask(o):
    """The round body: the biggest blob of team red, the clock face or back plate inside it filled in."""
    al = o[..., 3] > 0
    h, s, v = hsv(o)
    red = al & is_red(h, s, v)
    m = ndi.binary_fill_holes(ndi.binary_closing(red, iterations=2)) & al
    lab, n = ndi.label(m)
    if n == 0:
        return m
    sz = ndi.sum(m, lab, range(1, n + 1))
    return lab == int(np.argmax(sz)) + 1


def body_centre(o):
    """The middle of the round body, the same however it lies: the deepest point of its red and its clock face
    together (closed across the brass bezel between them: seen from the front the face splits the red, and a body
    lying on its side shows the red as a broken ring). None without a body."""
    al = o[..., 3] > 0
    h, s, v = hsv(o)
    red = al & is_red(h, s, v)
    face = al & (s < 0.3) & (v >= 0.72)
    lab, n = ndi.label(face)
    if n:
        sz = ndi.sum(face, lab, range(1, n + 1))
        face = np.isin(lab, [i + 1 for i in range(n) if sz[i] >= 150])      # (the face: not a shine on the brass)
    m = ndi.binary_fill_holes(ndi.binary_closing(red | face, iterations=3)) & al
    lab, n = ndi.label(m)
    if n == 0:
        return None
    sz = ndi.sum(m, lab, range(1, n + 1))
    big = lab == int(np.argmax(sz)) + 1
    if big.sum() < 100:
        return None
    dt = ndi.distance_transform_edt(big)
    ys, xs = np.nonzero(dt >= dt.max() * 0.9)
    return np.array([xs.mean(), ys.mean()])


def classes(o):
    """Per pixel, for matching the cap: 0 background, 1 brass, 2 dark, 3 red, 4 blue, 5 light neutral, 6 grey."""
    al = o[..., 3] > 0
    h, s, v = hsv(o)
    c = np.full(al.shape, 6, np.int8)
    c[(s < 0.25) & (v >= 0.6)] = 5
    c[is_brass(h, s, v)] = 1
    c[is_blue(h, s, v)] = 4
    c[is_red(h, s, v)] = 3
    c[v < 0.2] = 2
    c[~al] = 0
    return c


def luma(o):
    a = o[..., :3].astype(np.float32)
    return 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]


def template_from(o, cap):
    """A cap template from frame o and its cap mask: the cap's pixels as offsets from the body's middle (N x 2, x y), their
    classes and brightness, the body's middle. None without a body or a cap."""
    c0 = body_centre(o)
    if c0 is None or cap.sum() < 30:
        return None
    py, px = np.nonzero(cap)
    pts = np.stack([px - c0[0], py - c0[1]], 1).astype(np.float32)
    return pts, classes(o)[py, px], luma(o)[py, px], c0


def cap_template(ref):
    """The cap on an UPRIGHT frame (the idle): what is not body, red or blue above the body's top edge, the pieces that
    sit on the middle of that edge (the shoulders and arms are at its sides). A template (template_from) or None."""
    al = ref[..., 3] > 0
    B = body_mask(ref)
    if B.sum() < 100:
        return None
    ys, xs = np.nonzero(B)
    x0, x1 = xs.min(), xs.max()
    w = x1 - x0 + 1
    cx = (x0 + x1) / 2.0
    band = (xs >= cx - 0.2 * w) & (xs <= cx + 0.2 * w)
    top = int(np.percentile(ys[band], 2))
    h, s, v = hsv(ref)
    cand = al & ~B & ~is_red(h, s, v) & ~is_blue(h, s, v)
    cand[top + 3:] = False
    lab, n = ndi.label(cand, structure=np.ones((3, 3)))
    keep = np.zeros_like(cand)
    for i, sl in enumerate(ndi.find_objects(lab)):
        m = lab[sl] == i + 1
        yy, xx = np.nonzero(m)
        yy, xx = yy + sl[0].start, xx + sl[1].start
        # it sits on the middle of the body's top: low pixels near the edge, in the middle band
        foot = (yy >= top - 6) & (np.abs(xx - cx) <= 0.2 * w)
        if foot.sum() >= 4 and m.sum() >= 30:
            keep[sl] |= m
    return template_from(ref, keep)


_LAST_POSE = {}       # the pose the last find_cap chose (for checks)
CAP_MATCH = 0.5       # the least share of the cap's pixels that must match (by class) ...
CAP_NCC = 0.6         # ... and the least correlation of their shading with the template's: below either, no cap. An
CAP_NCC_TIPPED = 0.4  # upright frame's cap correlates 0.65 or more (a brass fist raised past the head: 0.51); a body
                      # tipping over is drawn more loosely by ChatGPT (its cap 0.46 and up)


def find_cap(o, tpl, tilt=0.0, window=16.0, shift=27, min_ncc=CAP_NCC):
    """The cap on frame o: the template laid on the frame around the body's middle, turned by the body's tilt (searched
    `window` degrees either side of `tilt`), scaled 0.88-1.12 and shifted up to `shift` px; the pose that matches best
    wins: the share of its pixels whose class (brass, dark, light, ...) the frame has there, plus half the correlation of
    their shading with the template's (the drum's rivet band, the dome, the spike: a brass arm raised past the head has
    the colours, not the pattern). Returns (mask, score, angle); the mask is empty when no pose matches well enough (a
    frame where the cap is hidden). `tilt` is screen clockwise: the body's up axis points along (sin, -cos)."""
    pts, cls, lum, _ = tpl
    al = o[..., 3] > 0
    B = body_mask(o)
    c = body_centre(o)
    empty = np.zeros(al.shape, bool)
    if c is None:
        return empty, 0.0, tilt
    fc = classes(o)
    H, W = al.shape
    wts = np.where(cls != 2, 1.0, 0.5)      # (the dark rivet holes match loosely: they weigh less)
    wsum = float(wts.sum())
    fcp = np.pad(fc, 1)                     # (a border of background: points off the frame read 0)
    flp = np.pad(luma(o) * al, 1)
    tl = lum - lum.mean()
    tn = float(np.sqrt((tl * tl).sum())) + 1e-6

    def scores(th, sc, offs, k=1):
        """(class match, shading correlation) of the template turned by th, scaled by sc, at every shift in offs (every
        k-th template pixel: the coarse pass)."""
        p, cl, w, tlk = pts[::k], cls[::k], wts[::k], lum[::k] - lum[::k].mean()
        t = np.radians(th)
        ct, st = np.cos(t), np.sin(t)
        rx = sc * (p[:, 0] * ct - p[:, 1] * st)
        ry = sc * (p[:, 0] * st + p[:, 1] * ct)
        ix = np.clip(np.round(c[0] + rx[None, :] + offs[:, :1]).astype(int) + 1, 0, W + 1)
        iy = np.clip(np.round(c[1] + ry[None, :] + offs[:, 1:]).astype(int) + 1, 0, H + 1)
        f = fcp[iy, ix]
        hit = (f == cl) | ((cl == 1) & (f == 5)) | ((cl == 5) & (f == 1)) | ((cl == 2) & (f == 1)) | ((cl == 1) & (f == 2))
        bad = (f == 0) | (f == 3) | (f == 4)
        cm = ((w * hit).sum(1) - 0.5 * (w * bad).sum(1)) / float(w.sum())
        fl = flp[iy, ix]
        fl = fl - fl.mean(1, keepdims=True)
        ncc = (fl * tlk[None, :]).sum(1) / (np.sqrt((fl * fl).sum(1)) * (np.sqrt((tlk * tlk).sum()) + 1e-6) + 1e-6)
        return cm, ncc

    def grid(x0, y0, r, step):
        g = np.arange(-r, r + 1, step)
        return np.array([(x0 + dx, y0 + dy) for dy in g for dx in g], np.float32)

    best = (-9.0, tilt, 1.0, 0.0, 0.0, 0.0, 0.0)
    # coarse: every 4 degrees, 3 px, three scales; then fine around the best
    coarse = grid(0, 0, shift, 3)
    for th in np.arange(tilt - window, tilt + window + 0.1, 4.0):
        for sc in (0.88, 1.0, 1.12):
            cm, ncc = scores(th, sc, coarse, 3)
            tot = cm + 0.5 * ncc
            k = int(np.argmax(tot))
            if tot[k] > best[0]:
                best = (float(tot[k]), th, sc, float(coarse[k, 0]), float(coarse[k, 1]), float(cm[k]), float(ncc[k]))
    th0, sc0, dx0, dy0 = best[1:5]
    best = (-9.0,) + best[1:]               # (the fine pass scores every pixel: comparable with each other only)
    fine = grid(dx0, dy0, 2, 1)
    for th in np.arange(th0 - 3, th0 + 3.1, 1.0):
        for sc in (sc0 - 0.06, sc0 - 0.03, sc0, sc0 + 0.03, sc0 + 0.06):
            cm, ncc = scores(th, sc, fine)
            tot = cm + 0.5 * ncc
            k = int(np.argmax(tot))
            if tot[k] > best[0]:
                best = (float(tot[k]), th, sc, float(fine[k, 0]), float(fine[k, 1]), float(cm[k]), float(ncc[k]))
    _, th, sc, dx, dy, cm, ncc = best
    _LAST_POSE.clear()
    _LAST_POSE.update(c=c, th=th, sc=sc, dx=dx, dy=dy, match=cm, ncc=ncc)
    if cm < CAP_MATCH or ncc < min_ncc:
        return empty, cm, th
    # the template's pixels painted at the pose (each splatted 2x2 so a turned cap has no holes), then the frame's own
    # cap pixels near it: not the body, not red or blue
    t = np.radians(th)
    ct, st = np.cos(t), np.sin(t)
    qx = c[0] + dx + sc * (pts[:, 0] * ct - pts[:, 1] * st)
    qy = c[1] + dy + sc * (pts[:, 0] * st + pts[:, 1] * ct)
    m = np.zeros(al.shape, bool)
    for ox in (0, 1):
        for oy in (0, 1):
            ix, iy = np.floor(qx).astype(int) + ox, np.floor(qy).astype(int) + oy
            ok = (ix >= 0) & (ix < W) & (iy >= 0) & (iy < H)
            m[iy[ok], ix[ok]] = True
    m = ndi.binary_closing(m, iterations=1)
    h, s, v = hsv(o)
    cap = ndi.binary_dilation(m, iterations=2) & al & ~B & ~is_red(h, s, v) & ~is_blue(h, s, v)
    return cap, cm, th


# ------------------------------------------------------------------ the step

_TEMPLATES = {}       # the Clock Soldier's cap template per reference frame


def recolour(o, unit, ref=None, tilt=0.0, window=16.0, info=None, tipped=False):
    """One keyed frame (sheet resolution, before the shrink) -> the palette rule applied (painted colours; snap_team
    makes the key reds after the shrink). The Clock Soldier's `ref`: an upright frame of the same direction (its idle:
    the cap is found on it by its place) or a ready template (template_from: a sheet's own upright first frame with the
    cap found on it, for the rest of that row). `info`: a dict, filled with what was found (masks; the cap's match,
    shading correlation and angle)."""
    o = o.copy()
    al = o[..., 3] > 0
    paint, steel_m = blue_parts(o, unit)
    rgb = o[..., :3]
    if unit == 'clock_soldier':
        h, s, v = hsv(o)
        B = body_mask(o)
        cap = np.zeros(al.shape, bool)
        tpl = ref
        if isinstance(ref, np.ndarray):
            key = (ref.shape, hash(ref.tobytes()))
            if key not in _TEMPLATES:
                _TEMPLATES[key] = cap_template(ref)
            tpl = _TEMPLATES[key]
        if tpl is not None:
            cap, sc, th = find_cap(o, tpl, tilt, window, min_ncc=CAP_NCC_TIPPED if tipped else CAP_NCC)
            if info is not None:
                info.update(cap_score=sc, cap_angle=th, cap_ncc=_LAST_POSE.get('ncc', 0.0))
        # the body's reds (its orange seams and pink highlights too) along the brass ramp, by value; red specks off the
        # body go brass as well (the body is its only red part)
        bm = red_parts(o) | (al & is_red(h, s, v)) | (al & B & ((h <= 16) | (h >= 340)) & (s >= 0.15) & (v >= 0.6))
        if bm.any():
            br = brass_of(v)
            # a pink highlight (low saturation, bright) -> the brass highlight
            hl = bm & (s < 0.5) & (v >= 0.8)
            br[hl] = brass_of(np.ones(hl.sum()))
            rgb[bm] = br[bm].clip(0, 255).astype(np.uint8)
        rgb[:] = to_team(rgb, cap)
        if info is not None:
            info.update(body=bm, cap=cap)
    else:
        rgb[:] = to_team(rgb, red_parts(o))      # (the red parts on one pure red ramp: no orange seams on another team)
    rgb[:] = to_team(rgb, paint)
    rgb[:] = steel(rgb, steel_m)
    if info is not None:
        info.update(paint=paint, steel=steel_m)
    o[..., :3] = rgb
    return o


def snap_team(img):
    """After the shrink: the team reds -> the exact key reds the shader recolours: the light key from r 175, the dark
    key down to r 60 (its dark shading too, so no shaded red keeps its painted colour on another team). A red's pale
    highlight (a pink: too light to be the red, too red to be white) -> a neutral light of its brightness."""
    r, g, b = img[..., 0].astype(int), img[..., 1].astype(int), img[..., 2].astype(int)
    al = img[..., 3] > 0
    red = al & (r >= 60) & (g <= r * 0.3) & (b <= r * 0.35)
    light = red & (r >= 175)
    img[light, :3] = TEAM_LIGHT
    img[red & ~light, :3] = TEAM_DARK
    pink = al & ~red & (r >= 175) & (g <= r * 0.8) & (np.abs(g - b) <= r * 0.12) & (r - g >= 40)
    if pink.any():
        lum = (0.5 * r + 0.3 * g + 0.2 * b)[pink]
        img[pink, :3] = np.stack([lum, lum * 0.97, lum * 0.95], -1).clip(0, 255).astype(np.uint8)
    return img


# ------------------------------------------------------------------ a check of a sheet

def check(unit, path, rows, cols, out, only_row=None, navy=(0, 22, 48), tol=40):
    """Each cell: the frame, the overlay (magenta: blue paint -> player colour; cyan: steel; yellow: the Clock Soldier's
    head; orange: its body -> brass) and the result (painted colours before the snap)."""
    from PIL import Image
    a = np.array(Image.open(path).convert('RGB')).astype(int)
    H, W = a.shape[:2]
    tiles = []
    refs = {}
    for r in range(rows):
        if only_row is not None and r != only_row:
            continue
        line = []
        for c in range(cols):
            y0, y1, x0, x1 = int(r * H / rows), int((r + 1) * H / rows), int(c * W / cols), int((c + 1) * W / cols)
            sub = a[y0:y1, x0:x1]
            m = np.abs(sub - np.array(navy)).sum(2) >= tol
            o = np.zeros(sub.shape[:2] + (4,), np.uint8)
            o[..., :3] = sub
            o[..., 3] = m * 255
            if r not in refs:
                refs[r] = o
            info = {}
            res = recolour(o, unit, ref=refs[r], info=info)
            ov = sub.copy()
            ov[info['paint']] = [255, 0, 255]
            ov[info['steel']] = [0, 255, 255]
            if 'cap' in info:
                ov[info['body']] = [255, 140, 0]
                ov[info['cap']] = [255, 255, 0]
            line.append(np.concatenate([sub, ov, res[..., :3]], 1))
        tiles.append(np.concatenate(line, 1))
    Image.fromarray(np.concatenate(tiles, 0).astype(np.uint8)).save(out)


if __name__ == '__main__':
    if len(sys.argv) < 6:
        print(__doc__)
        sys.exit(1)
    check(sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5],
          int(sys.argv[6]) if len(sys.argv) > 6 else None)
