"""Cut the lightning effects out of art/world/lightning.png into assets/effects/zap_*.png.

The source is a generated sheet of glowing lightning drawn on a flat dark-navy
background. Every pixel is "un-blended" from that background (colour-to-alpha):
alpha is the smallest value that explains the pixel as glow laid over the navy,
and the colour is solved from pixel = bg*(1-a) + colour*a. That leaves a
transparent background, a semi-transparent glow and no navy fringe.

Each output frame is made with an affine map from output pixels back into the
sheet (scale / rotate / stretch, chosen per effect so that e.g. bolt endpoints
land on the frame edges), sampled 4x supersampled on premultiplied colour and
box-averaged down, then faint pixels are cut and stray specks removed.

Every output is a horizontal strip of equal-size RGBA frames.

Usage (from the repo root): python3 tools/import_lightning.py
Needs Pillow, NumPy and SciPy.
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "art/world/lightning.png"
OUT = "assets/effects"
SS = 4             # supersampling per output pixel
ALPHA_CUT = 0.10   # alpha below this becomes fully transparent
SPECK_MAX = 0.30   # isolated blobs whose strongest pixel is fainter than this are removed

# Source cells, (x0, x1, y0, y1) in sheet pixels; found by projecting the
# non-background mask of each row (see the report in the docstring above).
R1, R2, R4, R5, R8, R9 = (42, 118), (138, 193), (337, 453), (456, 538), (766, 866), (868, 924)
CELLS = {
    # row 1: small sparks growing then fading
    "spark_b": [(186, 238, *R1), (254, 297, *R1), (311, 366, *R1), (380, 438, *R1), (545, 602, *R1)],
    "spark_y": [(825, 877, *R1), (888, 943, *R1), (955, 1016, *R1), (617, 677, *R1), (691, 752, *R1)],
    # row 4: star bursts, smallest -> biggest
    "burst_b": [(44, 90, *R4), (100, 160, *R4), (170, 248, *R4), (253, 360, *R4)],
    "burst_y": [(757, 806, *R4), (822, 880, *R4), (906, 991, *R4), (1015, 1130, *R4)],
    # row 2: horizontal bolts between two stars
    "bolt_b": [(38, 185, *R2), (198, 335, *R2), (346, 520, *R2)],
    "bolt_y": [(530, 760, *R2), (776, 980, *R2)],
    # row 5: arcs (the first blue cell holds two arcs touching at x~126)
    "arc_b": [(40, 126, *R5), (127, 232, *R5), (238, 366, *R5)],
    # row 8: diagonal strikes pointing up-right (cell 124-270 holds two strikes)
    "strike_b": [(41, 110, *R8), (118, 190, *R8), (190, 274, *R8), (274, 352, *R8)],
    # row 9: tiny crackles
    "crackle_b": [(40, 80, *R9), (100, 150, *R9), (166, 196, *R9), (216, 266, *R9)],
}


def load():
    rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
    # Background = median of the 6-px border (the sheet's flat navy).
    border = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3),
                             rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    # Colour-to-alpha for an additive glow: only channels brighter than the
    # background count, so dark noise never turns into a dark fringe.
    a = np.clip((rgb - bg) / (255.0 - bg), 0, None).max(axis=2)
    a = np.clip(a, 0, 1)
    safe = np.maximum(a, 1e-6)[..., None]
    col = np.clip((rgb - bg * (1 - a[..., None])) / safe, 0, 255)
    premult = np.dstack([col * a[..., None], a * 255.0])  # premultiplied RGBA, 0..255
    return premult, bg


def crop(pm, cell):
    x0, x1, y0, y1 = cell
    return pm[y0:y1, x0:x1].copy()


def warp(c, w, h, fn):
    """Render a w*h frame. fn maps output pixel coords (u, v) (float arrays,
    pixel units, 0..w / 0..h) to source coords (x, y) inside crop c."""
    us = (np.arange(w * SS) + 0.5) / SS
    vs = (np.arange(h * SS) + 0.5) / SS
    U, V = np.meshgrid(us, vs)
    X, Y = fn(U, V)
    out = np.zeros((h * SS, w * SS, 4))
    for k in range(4):
        out[..., k] = ndimage.map_coordinates(c[..., k], [Y - 0.5, X - 0.5], order=1, mode="constant", cval=0)
    return out.reshape(h, SS, w, SS, 4).mean(axis=(1, 3))


def finish(f):
    """Premultiplied float frame -> straight RGBA uint8 with cleanup."""
    a = f[..., 3] / 255.0
    a[a < ALPHA_CUT] = 0
    lab, n = ndimage.label(a > 0, structure=np.ones((3, 3)))
    for i in range(1, n + 1):
        m = lab == i
        if a[m].max() < SPECK_MAX:
            a[m] = 0
    safe = np.maximum(a, 1e-6)[..., None]
    col = np.clip(f[..., :3] / 255.0 / safe * 255.0, 0, 255)
    col[a == 0] = 0
    return np.dstack([col, a * 255]).round().astype(np.uint8)


def bright(c, thr=0.55):
    return c[..., 3] / 255.0 > thr


def centre_of(c, mode):
    a = c[..., 3] / 255.0
    if mode == "core":  # centroid of the hottest pixels (burst cores)
        lum = c[..., :3].sum(axis=2)
        m = lum >= np.percentile(lum, 99.3)
        ys, xs = np.nonzero(m)
        return xs.mean() + 0.5, ys.mean() + 0.5
    ys, xs = np.nonzero(a > 0.3)
    return (xs.min() + xs.max() + 1) / 2.0, (ys.min() + ys.max() + 1) / 2.0


def centred(c, w, h, scale, mode="bbox"):
    cx, cy = centre_of(c, mode)
    return warp(c, w, h, lambda U, V: (cx + (U - w / 2) / scale, cy + (V - h / 2) / scale))


def end_points(c):
    """Centres of the left and right endpoint flares (bolts / arcs)."""
    m = bright(c, 0.75)
    ys, xs = np.nonzero(m)
    left, right = xs.min(), xs.max()
    lm = xs <= left + 6
    rm = xs >= right - 6
    return (xs[lm].mean() + 0.5, ys[lm].mean() + 0.5), (xs[rm].mean() + 0.5, ys[rm].mean() + 0.5)


def between(c, w, h, mid_y, sy):
    """Map the two endpoint flares to (0, mid_y) and (w, mid_y); sy = output px per
    source px perpendicular to the line."""
    (lx, ly), (rx, ry) = end_points(c)
    dx, dy = rx - lx, ry - ly
    L = np.hypot(dx, dy)
    ex, ey = dx / L, dy / L          # along the line
    nx, ny = -ey, ex                 # perpendicular (points "down" for a level line)
    def fn(U, V):
        t = U / w * L
        n = (V - mid_y) / sy
        return lx + ex * t + nx * n, ly + ey * t + ny * n
    return warp(c, w, h, fn)


def arc_frame(c, w, h, mid_y, apex):
    (lx, ly), (rx, ry) = end_points(c)
    ys, xs = np.nonzero(bright(c, 0.5))
    top = ys.min() + 0.5
    sy = apex / (((ly + ry) / 2) - top)
    return between(c, w, h, mid_y, sy)


def strike_frame(c, w, h, scale):
    """Diagonal strike pointing up-right -> vertical strike pointing up,
    origin (bottom-left end) at the bottom middle of the frame."""
    ys, xs = np.nonzero(bright(c, 0.6))
    i0 = np.argmax(ys - xs)          # bottom-left end = origin
    i1 = np.argmax(xs - ys)          # top-right end = tip
    ox, oy = xs[i0] + 0.5, ys[i0] + 0.5
    tx, ty = xs[i1] + 0.5, ys[i1] + 0.5
    dx, dy = tx - ox, ty - oy
    L = np.hypot(dx, dy)
    ex, ey = dx / L, dy / L          # "up" in output
    px, py = -ey, ex                 # output "right" (up rotated 90 deg clockwise on screen)
    bottom = h - 3.0                 # leave room for the origin flare's glow
    def fn(U, V):
        up = (bottom - V) / scale
        side = (U - w / 2) / scale
        return ox + ex * up + px * side, oy + ey * up + py * side
    return warp(c, w, h, fn)


def fade(f, k):
    return f * k


def dissolve(f, keep, k):
    """Last breath of a burst: only the strongest rays/sparks remain, dimmed."""
    out = f * k
    out[f[..., 3] / 255.0 < keep] = 0
    return out


def flipv(c):
    return c[::-1].copy()


def recolour_white(f):
    """Blue frame (premultiplied) -> white-blue: pull the hue toward pale ice."""
    a = f[..., 3:4] / 255.0
    safe = np.maximum(a, 1e-6)
    col = f[..., :3] / safe
    ice = np.array([215.0, 235.0, 255.0])
    t = 0.75 * np.sqrt(a)            # cores turn ice-white, the faint glow stays blue
    col = col * (1 - t) + ice * t
    return np.dstack([np.clip(col, 0, 255) * a, f[..., 3]])


def save(name, frames):
    frames = [finish(f) for f in frames]
    h, w = frames[0].shape[:2]
    strip = np.concatenate(frames, axis=1)
    Image.fromarray(strip, "RGBA").save(os.path.join(OUT, name + ".png"))
    return name, len(frames), w, h


def main():
    pm, bg = load()
    print("background", bg)
    cells = {k: [crop(pm, c) for c in v] for k, v in CELLS.items()}
    made = []

    # zap_spark: looping crackle on a tower top, 22x22.
    sp = [centred(c, 22, 22, 0.40) for c in cells["spark_b"]]
    made.append(save("zap_spark", sp))
    made.append(save("zap_spark_w", [recolour_white(f) for f in sp]))
    made.append(save("zap_spark_y", [centred(c, 22, 22, 0.40) for c in cells["spark_y"]]))

    # zap_burst: grows (4 source frames) then fades (last frame dimmed twice), 30x30.
    for suffix, key in (("", "burst_b"), ("_y", "burst_y")):
        fr = [centred(c, 30, 30, 0.28, "core") for c in cells[key]]
        fr += [fade(fr[-1], 0.65), dissolve(fr[-1], 0.55, 0.45)]
        made.append(save("zap_burst" + suffix, fr))

    # zap_bolt: endpoints on the vertical middle of the left/right edges, 64x16.
    for suffix, key in (("", "bolt_b"), ("_y", "bolt_y")):
        src = cells[key]
        src = src + [flipv(c) for c in src]
        src = src[:4]
        made.append(save("zap_bolt" + suffix, [between(c, 64, 16, 8, 0.5) for c in src]))

    # zap_arc: arc jump, endpoints on the vertical middle of the edges, 64x24.
    a = cells["arc_b"]
    src = [a[0], a[1], a[2], a[1][:, ::-1].copy()]
    made.append(save("zap_arc", [arc_frame(c, 64, 24, 12, 9.5) for c in src]))

    # zap_strike: vertical strike pointing UP from the bottom middle, 24x72.
    made.append(save("zap_strike", [strike_frame(c, 24, 72, 0.62) for c in cells["strike_b"]]))

    # zap_crackle: tiny looping crackle, 16x16.
    made.append(save("zap_crackle", [centred(c, 16, 16, 0.36) for c in cells["crackle_b"]]))

    for name, n, w, h in made:
        print('\t"%s": {"frames": %d, "size": Vector2i(%d, %d)},' % (name, n, w, h))


if __name__ == "__main__":
    main()
