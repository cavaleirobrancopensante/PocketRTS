"""The Crown Labourer, second round of ChatGPT sheets (art/redraws/labourer_*.png, 1536x1024, flat navy
ground, NO labels, 5 rows s, se, e, ne, n; the west views are these mirrored by the game):

  INSTALLED (strips in assets/units/labourer/):
    labourer_death.png        death_<d>      3 frames (hit, falling with the hat flying off, lying, hat beside him)
    labourer_death_keg.png    death_keg_<d>  6 frames (keg man, hit, burning, explosion x2, smoke and rubble)
    labourer_bury.png         bury_<d>       6 frames (carry keg, dig, place keg, fill, mound, stand with shovel)
    labourer_idle_v2.png / _v2b.png   idle_<d>   2 frames, hoe at his side (best frame pair per view)
    labourer_walk_v2.png / _v2b.png   walk_<d>   6 frames (the better sheet per view; legs rebuilt where the
                                                 AI's did not alternate, see walk_frames())
  CANDIDATES (never installed; the owner decides): labourer_build_v2.png (hammering, 4 frames) and
    labourer_hoe_v2.png (hoe swing, 4 frames) are processed into /tmp/cand_build.png and /tmp/cand_hoe.png,
    4x contact sheets with the CURRENT strips above each candidate row.

What it does (docs/animation_audit_labourer.md has the per-frame verdicts):
  1. every sheet is a clean grid (5 row bands, N column runs): the frames are cut with the navy keyed out
     (no labels, so the old blob-size safeguards become count assertions; specks smaller than 10 px go);
  2. one scale per sheet makes the standing man as tall as the current labourer (TARGET_H), box filter with
     premultiplied alpha and hard alpha as import_labourer_redraw.py does; lying figures that would be wider
     than 40 px are shrunk further to fit the 42 px cell (never clipped), each frame is stood on the ground
     line (row 33, anchor x 21);
  3. the coat is snapped to the team key reds (not in the explosion / smoke frames: those would turn red
     for the team shader) and pink / blue glows are tidied, as the first importer does;
  4. flaws are repaired in code (REPAIRS below, listed in the audit doc).

Runs after tools/import_labourer_gait.py in tools/rebuild_art.sh (that script rewrites walk_e / se / ne from
its own snapshot, so this one must come last and uses its leg builder for the new walk).
Usage (repo root):  python3 tools/import_labourer_v2.py [--dry] [--contact] [--candidates]
Needs Pillow, NumPy, SciPy.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import import_labourer_redraw as R  # noqa: E402
import import_labourer_gait as G  # noqa: E402
from redraw_lib import runs  # noqa: E402

REDRAWS = os.path.join(ROOT, "art/redraws")
OUT = os.path.join(ROOT, "assets/units/labourer")
W, H, GROUND, CX = 42, 35, 33, 21
DIRS = ["s", "se", "e", "ne", "n"]
MAXW = 40                    # widest a frame may be (columns 0 and 41 stay empty: the ground-line test)

# the standing man's height in rows (hat to boots), as the current strips have it
TARGET_H = {"death": 31, "death_keg": 30, "bury": 31, "idle": 32, "walk": 31, "build": 31, "hoe": 31}


# ---------------------------------------------------------------- the sheets

def grid(name, ncols, nrows=5):
    """name -> rows (top to bottom) of ncols sprite dicts (sheet-size RGBA, tight crop). The sheets are
    plain grids on navy, so rows are bands of the foreground's row projection and columns its runs;
    anything else is an error (a label, a sheet with another layout)."""
    a = np.array(Image.open(os.path.join(REDRAWS, name)).convert("RGB")).astype(int)
    bg = a[2, 2]
    fg = np.abs(a - bg).sum(-1) > 45
    rows = runs(fg.any(1), gap=5, minw=20)
    assert len(rows) == nrows, (name, "rows", rows)
    out = []
    for (y0, y1) in rows:
        cols = runs(fg[y0:y1].any(0), gap=30, minw=8)
        assert len(cols) == ncols, (name, "columns", cols)
        row = []
        for (x0, x1) in cols:
            m = fg[y0:y1, x0:x1].copy()
            lab, n = ndimage.label(m, structure=np.ones((3, 3)))
            if n:
                sizes = ndimage.sum(m, lab, range(1, n + 1))
                m = (sizes >= 10)[lab - 1] & (lab > 0)
            ys, xs = np.nonzero(m)
            ya, yb, xa, xb = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            rgba = np.zeros((yb - ya, xb - xa, 4), np.uint8)
            rgba[..., :3] = a[y0 + ya:y0 + yb, x0 + xa:x0 + xb]
            rgba[..., 3] = m[ya:yb, xa:xb] * 255
            row.append({"rgba": rgba, "x": x0 + xa, "y": y0 + ya, "h": yb - ya, "w": xb - xa})
        out.append(row)
    return out


def bbox_x(rgba):
    xs = np.nonzero((rgba[..., 3] > 0).any(0))[0]
    return float((xs.min() + xs.max() + 1) / 2.0)


def fit_scale(sprite, scale):
    """Shrink further when the figure would not fit the cell (lying men, explosions, wide mounds)."""
    h, w = sprite["rgba"].shape[:2]
    return min(scale, MAXW / float(w), (GROUND + 1.0) / float(h) * 0.97)


def tidy_plain(img):
    """For fire, smoke, rubble and mounds: no team snapping (the key reds would turn team coloured),
    navy fringe and specks removed, exact key reds nudged off so the shader leaves them alone."""
    img = img.copy()
    rgb = img[..., :3].astype(int)
    a = img[..., 3] > 0
    navy = a & (rgb[..., 2] - rgb[..., 0] > 18) & (rgb[..., 2] > rgb[..., 1] + 4) & (rgb.sum(-1) < 150)
    edge = a & ~ndimage.binary_erosion(a, structure=np.ones((3, 3)))
    img[navy & edge] = 0
    img = R.clean(img, min_size=2, keep_near=1)
    from import_art import unteam
    return unteam(img)


def make(sprite, scale, ref="coat", team=True):
    rgba = sprite["rgba"]
    sc = fit_scale(sprite, scale)
    rx = R.coat_x(rgba) if ref == "coat" else (R.feet_x(rgba) if ref == "feet" else bbox_x(rgba))
    if ref == "coat":                  # a wide frame (hat flying off) centred on the coat would run out of the cell
        s_ = W / float(int(round(W / sc)))
        xs = np.nonzero((rgba[..., 3] > 0).any(0))[0]
        if CX - (rx - xs.min()) * s_ < 1.0 or CX + (xs.max() + 1 - rx) * s_ > MAXW + 0.5:
            rx = bbox_x(rgba)
    img = R.shrink_canvas(rgba, rx, R.bottom_y(rgba), sc)
    img = R.tidy(img) if team else tidy_plain(img)
    low = int(np.nonzero((img[..., 3] > 0).any(1))[0].max())
    if GROUND - 3 <= low < GROUND:     # the box filter dropped the last row of rubble: back on the ground line
        img = np.roll(img, GROUND - low, axis=0)
    return img


def calib(rows, key, col=0):
    """The scale that makes the median standing figure (frame `col` of every row) TARGET_H tall."""
    hs = [r[col]["h"] for r in rows]
    return TARGET_H[key] / float(np.median(hs))


def calib_all(rows, key):
    hs = [s["h"] for r in rows for s in r]
    return TARGET_H[key] / float(np.median(hs))


# ---------------------------------------------------------------- repairs

def crouch(f, k):
    """He drops k rows: k rows are cut out of the thighs just under the coat hem, so the coat, head and
    arms come down and the boots stay on row 33."""
    hem = R.hem_row(f) + 2
    out = np.zeros_like(f)
    body = np.concatenate([f[:hem], f[hem + k:]], 0)
    out[k:] = body
    return out


def graft_right(base, donor, x0, y0=0):
    """donor's pixels right of column x0 (and below row y0) pasted over base: a tool and soil."""
    out = base.copy()
    sub = donor.copy()
    sub[:, :x0 + 1] = 0
    sub[:y0] = 0
    m = sub[..., 3] > 0
    out[m] = sub[m]
    return out


def coat_right(f):
    m = R.is_red(f)
    return int(np.nonzero(m.any(0))[0].max())


def bury_frames():
    """bury_<d>: carry keg, dig, place keg, fill, mound, stand with the shovel. The sheet's north row is
    wrong (ChatGPT repeated the standing back view in frames 1-3: no digging, no keg): those three get
    a crouch from behind (dig 3 rows, place 5, fill 4) and the standing frame's shovel and soil pile
    (the soil only in the keg frame), so the back view still digs."""
    g = grid("labourer_bury.png", 6)
    sc = calib(g, "bury", 5)
    fr = {d: [make(s, sc, "coat") for s in row] for d, row in zip(DIRS, g)}
    n = fr["n"]
    x0 = coat_right(n[5]) + 1
    n[1] = graft_right(crouch(n[1], 3), n[5], x0)
    n[2] = graft_right(crouch(n[2], 5), n[5], x0, 30)
    n[3] = graft_right(crouch(n[3], 4), n[5], x0)
    return fr


def death_frames():
    g = grid("labourer_death.png", 3)
    sc = calib(g, "death")
    return {d: [make(s, sc, "coat" if k < 2 else "box") for k, s in enumerate(row)] for d, row in zip(DIRS, g)}


def keg_frames():
    g = grid("labourer_death_keg.png", 6)
    sc = calib(g, "death_keg")
    return {d: [make(s, sc, "coat", team=k < 3) for k, s in enumerate(row)] for d, row in zip(DIRS, g)}


# idle: the pair of frames per view with the most visible breath (alpha + colour change), by measurement
def frame_change(a, b):
    return int((np.abs(a.astype(int) - b.astype(int)).sum(-1) > 40).sum())


def idle_frames():
    cand = {}
    for name in ("labourer_idle_v2.png", "labourer_idle_v2b.png"):
        g = grid(name, 2)
        sc = calib_all(g, "idle")
        cand[name] = {d: [make(s, sc, "coat") for s in row] for d, row in zip(DIRS, g)}
    out, pick = {}, {}
    for d in DIRS:
        best = max(cand, key=lambda n: frame_change(*cand[n][d]))
        out[d] = cand[best][d]
        pick[d] = best
    return out, pick


# ---------------------------------------------------------------- walk

def front_legs(raw, view):
    """The legs for the six frames of a front (s) or back (n) view. The sheet's own legs are chunky and
    good, but not always different: s keeps the first three frames' legs and mirrors them for the second half
    (so the lifted foot alternates); n has hardly any leg motion at all (frames 0..5 differ by 0 to 19 px),
    so a flat stance (frame 3's right leg mirrored) is lifted under the left foot (2..4 rows) for the first half and under
    the right foot for the second (FRONT_LIFT)."""
    f = raw[view]
    if view == "s":
        return [f[0], f[1], f[2], R.mirror(f[0]), R.mirror(f[1]), R.mirror(f[2])]
    # the sheet's back view always has the left boot up (31) and the right planted: a flat stance is
    # the planted right half mirrored over the left
    base = f[3].copy()
    m = R.shift(R.mirror(f[3]), -1, 0)
    base[:, :20] = m[:, :20]
    return [base if lf == 0 and rf == 0 else
            R.lift_foot(base, "r" if rf else "l", rf or lf) for (lf, rf) in FRONT_LIFT]


FRONT_LIFT = [(0, 3), (0, 4), (0, 2), (3, 0), (4, 0), (2, 0)]    # (left, right) rows the boot is raised


def walk_frames():
    """walk_<d>, 6 frames, from labourer_walk_v2b.png (legs measured better than v2's: see the audit doc).
    Torso, head and arms are the sheet's; the legs are rebuilt in every frame (the AI's feet stayed at
    one spread in e, se and n), side and diagonal views with import_labourer_gait's contact / down /
    passing legs (so they match carry and carry_keg), s and n with alternating lifted feet."""
    g = grid("labourer_walk_v2b.png", 6)
    sc = calib_all(g, "walk")
    raw = {d: [make(s, sc, "coat") for s in row] for d, row in zip(DIRS, g)}
    for d in ("e", "se", "ne"):
        # the sheet's torsos sit lowest at the passing frames (the wrong way round for a walk): all on one
        # height first, the rebuilt legs then lift the body 1 row at the passing frames
        tops = [int(np.nonzero((f[..., 3] > 0).any(1))[0].min()) for f in raw[d]]
        t = int(np.median(tops))
        raw[d] = [R.shift(f, 0, t - tp) for f, tp in zip(raw[d], tops)]
    out = {}
    for d in DIRS:
        if d in ("e", "se", "ne"):
            out[d] = [G.rebuild(f, k, d) for k, f in enumerate(raw[d])]
        else:
            lg = front_legs(raw, d)
            out[d] = [R.compose(f, lg[k]) for k, f in enumerate(raw[d])]
        out[d] = [R.drop_bright(f) for f in out[d]]
    return raw, out


V3 = {"s": "labourer_walk_s_v3.png", "se": "labourer_walk_se_v3.png", "e": "labourer_walk_east_test.png",
      "ne": "labourer_walk_ne_v3.png", "n": "labourer_walk_n_v3.png"}


def walk_frames_v3():
    """walk_<d> from the owner's ChatGPT sheets of 2026-10-24 (one row of 6 per view, prompts 30-34): the
    legs are drawn in the body's own style, so nothing is rebuilt in code. One scale for all five sheets
    (the median figure height over every frame makes the man TARGET_H rows tall)."""
    g = {d: grid(n, 6, 1)[0] for d, n in V3.items()}
    hs = [s["h"] for row in g.values() for s in row]
    sc = TARGET_H["walk"] / float(np.median(hs))
    return {d: [R.drop_bright(make(s, sc, "coat")) for s in row] for d, row in g.items()}


# ---------------------------------------------------------------- candidates (never installed)

def cand_frames(name, key):
    """labourer_build_v2.png / labourer_hoe_v2.png as 4-frame strips. The scale is the walk sheets' (the same
    man: hat and coat match), raised tools taller than the cell have their handle shortened as the first
    importer does, frames stand on their boots (feet reference) so the body stays put like the stake."""
    g = grid(name, 4)
    sc = 0.1845
    out = {}
    for d, row in zip(DIRS, g):
        fr = []
        for s in row:
            rgba = R.shorten_handle(s["rgba"], sc)
            sp = dict(s, rgba=rgba, h=rgba.shape[0], w=rgba.shape[1])
            fr.append(make(sp, sc, "feet"))
        out[d] = fr
    return out


def current(pose):
    out = {}
    for d in DIRS:
        im = np.array(Image.open(os.path.join(OUT, f"{pose}_{d}.png")).convert("RGBA"))
        out[d] = [im[:, i * W:(i + 1) * W].copy() for i in range(im.shape[1] // W)]
    return out


def contact_sheet(path, rows, labels=None, zoom=4):
    """rows: list of lists of 42x35 frames (any length); one row per list at 4x on game green."""
    n = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (n * W * zoom + 4 * (n - 1), len(rows) * (H * zoom + 4)), (90, 110, 90, 255))
    from PIL import ImageDraw
    dr = ImageDraw.Draw(sheet)
    for r, fr in enumerate(rows):
        y = r * (H * zoom + 4)
        for k, f in enumerate(fr):
            x = k * (W * zoom + 4)
            sheet.alpha_composite(Image.fromarray(f).resize((W * zoom, H * zoom), Image.NEAREST), (x, y))
            dr.line([(x, y + (GROUND + 1) * zoom), (x + W * zoom, y + (GROUND + 1) * zoom)], fill=(255, 255, 0, 110))
            dr.text((x + 2, y + 2), (labels[r] + " " if labels else "") + str(k), fill=(255, 255, 255, 255))
    sheet.save(path)


def candidates():
    for name, key, cur, path in (("labourer_build_v2.png", "build", "build", "/tmp/cand_build.png"),
                                 ("labourer_hoe_v2.png", "hoe", "mine", "/tmp/cand_hoe.png")):
        cand = cand_frames(name, key)
        old = current(cur)
        rows, labels = [], []
        for d in DIRS:
            rows += [old[d], cand[d]]
            labels += ["cur " + d, "new " + d]
        contact_sheet(path, rows, labels)
        print("candidate sheet", path)


# ---------------------------------------------------------------- build everything

def check(fr):
    """Warnings: frames touching the cell's side edges or off the ground line; strips with identical frames."""
    bad = 0
    for (pose, d), frames in sorted(fr.items()):
        for k, f in enumerate(frames):
            ys, xs = np.nonzero(f[..., 3] > 0)
            if ys.max() != GROUND:
                print(f"  warn {pose}_{d}[{k}] lowest row {ys.max()}")
                bad += 1
            if xs.min() == 0 or xs.max() == W - 1 or ys.min() == 0:
                print(f"  warn {pose}_{d}[{k}] touches the cell edge x {xs.min()}-{xs.max()} y {ys.min()}")
                bad += 1
        for i in range(len(frames)):
            for j in range(i + 1, len(frames)):
                if (frames[i] == frames[j]).all() and not (pose == "bury" and d == "n"):
                    print(f"  warn {pose}_{d} frames {i} and {j} are identical")
                    bad += 1
    return bad


def all_frames():
    fr = {}
    for d, v in death_frames().items():
        fr[("death", d)] = v
    for d, v in keg_frames().items():
        fr[("death_keg", d)] = v
    for d, v in bury_frames().items():
        fr[("bury", d)] = v
    idle, pick = idle_frames()
    for d, v in idle.items():
        fr[("idle", d)] = v
    walk = walk_frames_v3()
    for d, v in walk.items():
        fr[("walk", d)] = v
    return fr, pick


def main():
    args = sys.argv[1:]
    fr, pick = all_frames()
    bad = check(fr)
    print("idle sheet per view:", {d: p[len("labourer_"):-4] for d, p in pick.items()})
    if "--contact" in args or "--dry" not in args:
        contact_sheet("/tmp/lab_v2_death.png", [fr[("death", d)] for d in DIRS], ["death " + d for d in DIRS])
        contact_sheet("/tmp/lab_v2_keg.png", [fr[("death_keg", d)] for d in DIRS], ["keg " + d for d in DIRS])
        contact_sheet("/tmp/lab_v2_bury.png", [fr[("bury", d)] for d in DIRS], ["bury " + d for d in DIRS])
        car = current("carry")
        rows, labels = [], []
        for d in DIRS:
            rows.append(fr[("idle", d)] + fr[("walk", d)] + car[d])
            labels.append(d)
        contact_sheet("/tmp/lab_v2_idle_walk.png", rows, labels)
    if "--candidates" in args or "--dry" not in args:
        candidates()
    if "--dry" in args:
        print("dry run: nothing written;", bad, "warnings")
        return
    for (pose, d), frames in sorted(fr.items()):
        Image.fromarray(np.concatenate(frames, 1), "RGBA").save(os.path.join(OUT, f"{pose}_{d}.png"))
    print(f"wrote {len(fr)} strips to {OUT}; {bad} warnings")


if __name__ == "__main__":
    main()
