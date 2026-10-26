"""Unwrap the painted gear rings (ChatGPT art) into polar strips the game can rebuild into a ring of ANY tooth
count: one TOOTH strip (one tooth period, the most typical tooth) and one BAND strip per ring kind (a quarter turn
of the band with its brass cross-plate). Run: python3 tools/gear_art/unwrap_rings.py
Out: art/clockwork/gear/{tooth,band_small,band_big,band_tower}.png and gear_strips.json (radii as fractions)."""
import json, math, os
import numpy as np
from PIL import Image
R = 'art/redraws/'
OUT = 'art/clockwork/gear/'
os.makedirs(OUT, exist_ok=True)
A = 2880  # angle samples round the ring

def navy(a): return (a[..., 2] > a[..., 0] + 25) & (a[..., 2] > a[..., 1] + 10)

def load(path, box):
    im = Image.open(path).convert('RGB').crop(box)
    a = np.array(im).astype(float); m = ~navy(a.astype(int))
    ys, xs = np.nonzero(m)
    cx = (xs.min() + xs.max()) / 2.0; cy = (ys.min() + ys.max()) / 2.0
    rt = (xs.max() - xs.min()) / 2.0
    return a, m, cx, cy, rt

def unwrap(a, m, cx, cy, r0, r1, rows):
    th = np.linspace(-math.pi / 2, 1.5 * math.pi, A, endpoint=False)  # start at the top, clockwise on screen
    rr = np.linspace(r1, r0, rows)  # row 0 = outer edge
    T, Rr = np.meshgrid(th, rr)
    x = np.clip((cx + Rr * np.cos(T)).round().astype(int), 0, a.shape[1] - 1)
    y = np.clip((cy + Rr * np.sin(T)).round().astype(int), 0, a.shape[0] - 1)
    return a[y, x], m[y, x]

def radial_profile(m, cx, cy, rt):
    prof = []
    for r in np.arange(0, rt + 2, 1.0):
        t = np.linspace(0, 2 * math.pi, 720, endpoint=False)
        x = np.clip((cx + r * np.cos(t)).round().astype(int), 0, m.shape[1] - 1)
        y = np.clip((cy + r * np.sin(t)).round().astype(int), 0, m.shape[0] - 1)
        prof.append(m[y, x].mean())
    return np.array(prof)

def rgba(col, msk):
    out = np.zeros(col.shape[:2] + (4,), np.uint8)
    out[..., :3] = col.clip(0, 255).astype(np.uint8); out[..., 3] = np.where(msk, 255, 0)
    return Image.fromarray(out, 'RGBA')

meta = {}
rings = {
    'tower': (R + 'cog_ring_clocktower_flat.png', (0, 0, 1254, 1254), 30),
    'small': (R + 'cog_rings_building_flat.png', (0, 0, 600, 1024), 22),
    'big': (R + 'cog_rings_building_flat.png', (600, 0, 1536, 1024), 32),
}
tooth_src = None
for kind, (path, box, n) in rings.items():
    a, m, cx, cy, rt = load(path, box)
    prof = radial_profile(m, cx, cy, rt)
    full = np.nonzero(prof > 0.97)[0]
    r_in, r_root = float(full.min()), float(full.max())  # solid band between the hole and the tooth roots
    rows = int(rt - r_in) + 1
    col, msk = unwrap(a, m, cx, cy, r_in, rt, rows)
    root_row = int(rt - r_root)
    # BAND: rows below the tooth roots, a quarter turn starting half a plate before the top plate
    q = A // 4
    band_c = np.roll(col[root_row:], q // 2, axis=1)[:, :q]
    band_m = np.roll(msk[root_row:], q // 2, axis=1)[:, :q]
    rgba(band_c, band_m).save(OUT + 'band_%s.png' % kind)
    meta[kind] = {'r_in': r_in / rt, 'r_root': r_root / rt, 'teeth_art': n, 'band_rows': int(band_c.shape[0])}
    if kind == 'small':  # the small ring's teeth are the cleanest: take the most typical one
        per = A / n
        teeth = []
        for k in range(n):
            # centre each period on a tooth: find the tooth phase from the mask at mid tooth height
            pass
        mid = max(1, root_row // 2)
        prof_a = msk[mid].astype(float)
        s = sum(prof_a[i] * math.sin(2 * math.pi * n * i / A) for i in range(A))
        c = sum(prof_a[i] * math.cos(2 * math.pi * n * i / A) for i in range(A))
        ph = math.atan2(s, c) / (2 * math.pi) * per  # column of a tooth centre
        w = int(round(per))
        cols = []
        for k in range(n):
            c0 = int(round(ph + k * per - per / 2))
            idx = [(c0 + j) % A for j in range(w)]
            cols.append((col[:root_row + 2][:, idx], msk[:root_row + 2][:, idx]))
        # skip periods covered by a cross plate (they are brighter and wider): pick the period closest to the median
        stack = np.stack([c for c, _ in cols]).astype(float)
        med = np.median(stack, axis=0)
        best = int(np.argmin([np.abs(c - med).mean() for c, _ in cols]))
        tc, tm = cols[best]
        rgba(tc, tm).save(OUT + 'tooth.png')
        meta['tooth'] = {'rows': int(tc.shape[0]), 'cols': int(tc.shape[1]), 'height_frac': (rt - r_root) / rt,
                         'from': 'small', 'ring_radius_px': rt, 'pitch_px': 2 * math.pi * rt / n}
json.dump(meta, open(OUT + 'gear_strips.json', 'w'), indent=1)
print(json.dumps(meta, indent=1))
