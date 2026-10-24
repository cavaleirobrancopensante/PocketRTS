"""A tiny leg rig for the image-AI walk sheets (used by tools/import_redraw_*.py).

The AI draws every walk frame as the same wide contact pose, so there is no gait. This takes the
legs of a contact figure apart (at the crotch, into a front leg and a rear leg, each cut at the
knee and the ankle into thigh, shin and foot) and poses them again at sheet resolution, any
angle, which the importer then shrinks. Everything is plain NumPy on RGBA arrays (0 or 255 alpha):

  Legs(fig)                      take a contact figure apart
  Legs.pose(side, thigh, shin)   one leg ("F" front or "R" rear source) with its thigh turned to
                                 `thigh` degrees from vertical (+ = forward = right) and its shin to
                                 `shin` (thigh = shin: straight; shin < thigh: knee bent, foot back)
  stack(layers)                  alpha-composite same-size layers, first at the bottom
  join(torso, legs, hip)         a torso (a figure cut at its crotch) over legs hung from `hip`
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from redraw_lib import runs  # noqa: E402

BROWN = lambda rgb: (rgb[..., 0] > 80) & (rgb[..., 0] - rgb[..., 2] > 50) & (rgb[..., 1] < rgb[..., 0] - 20) & (rgb[..., 0] < 200)


def nruns(row):
    d = np.diff(np.concatenate([[0], row.astype(int), [0]]))
    return int((d == 1).sum())


def rotate(img, center, deg):
    """img rotated `deg` degrees counter-clockwise (on screen) about center (x, y), bicubic on
    premultiplied colour, alpha thresholded back to 0 / 255."""
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    im = Image.fromarray(pre, "RGBA").rotate(deg, resample=Image.BICUBIC, center=(float(center[0]), float(center[1])))
    s = np.asarray(im).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.02, s[..., :3] / np.maximum(al, 0.02), 0)
    out = np.zeros(img.shape, np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.5, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def rot_pt(p, c, deg):
    """point p (x, y) turned `deg` counter-clockwise on screen about c"""
    t = np.radians(deg)
    dx, dy = p[0] - c[0], p[1] - c[1]
    # screen y points down: counter-clockwise on screen
    return (c[0] + dx * np.cos(t) + dy * np.sin(t), c[1] - dx * np.sin(t) + dy * np.cos(t))


def stack(layers):
    out = np.zeros_like(layers[0])
    for l in layers:
        m = l[..., 3] > 0
        out[m] = l[m]
    return out


def fill_gaps(img, iters=2):
    """close hairline holes of the alpha (a joint that opened) with the nearest colour"""
    a = img[..., 3] > 0
    closed = ndimage.binary_closing(a, structure=np.ones((3, 3)), iterations=iters)
    new = closed & ~a
    if new.any():
        idx = ndimage.distance_transform_edt(~a, return_distances=False, return_indices=True)
        out = img.copy()
        out[new] = img[idx[0][new], idx[1][new]]
        out[new, 3] = 255
        return out
    return img


class Leg:
    def __init__(self, mask, fig, hip, y_knee, y_ankle):
        self.hip = hip
        h, w = mask.shape
        ys, xs = np.nonzero(mask)
        self.mask = mask
        top = ys.min()
        ext = np.zeros_like(mask)
        # the thigh continues up into the hip (hidden by the torso): the top row repeated
        for y in range(max(0, top - 6), top):
            ext[y] = mask[top]
        full = mask | ext
        self.rgba = fig.copy()
        for y in range(max(0, top - 6), top):
            self.rgba[y] = np.where(mask[top][:, None], fig[top], 0)
        self.rgba[..., 3] = np.where(full, 255, 0)
        self.rgba[~full] = 0
        rows = np.arange(h)[:, None]
        self.y_knee, self.y_ankle = y_knee, y_ankle
        self.thigh = np.where((full & (rows < y_knee + 3))[..., None], self.rgba, 0).astype(np.uint8)
        self.shin = np.where((full & (rows >= y_knee - 3) & (rows < y_ankle + 2))[..., None], self.rgba, 0).astype(np.uint8)
        self.foot = np.where((full & (rows >= y_ankle - 1))[..., None], self.rgba, 0).astype(np.uint8)
        t = np.nonzero(self.thigh[..., 3] > 0)
        s = np.nonzero(self.shin[..., 3] > 0)
        f = np.nonzero(self.foot[..., 3] > 0)
        cen = lambda q: (q[1].mean(), q[0].mean())
        # the knee: where the leg crosses y_knee; the ankle likewise
        self.knee = (xs[ys == y_knee].mean() if (ys == y_knee).any() else cen(s)[0], float(y_knee))
        self.ankle = (xs[ys == y_ankle].mean() if (ys == y_ankle).any() else cen(f)[0], float(y_ankle))
        ang = lambda a, b: np.degrees(np.arctan2(b[0] - a[0], b[1] - a[1]))
        self.lam0 = ang(hip, self.ankle)         # hip -> ankle, + = forward
        self.foot0 = ang(self.ankle, cen(f))

    def pose(self, lam, bend=0.0, foot_keep=1.0, foot_turn=0.0, lift=0):
        """the leg as if the line hip -> ankle were at `lam` degrees from vertical (+ = forward =
        right); `bend` degrees of knee bend (the shin turned back about the knee, so the foot
        lifts); the foot follows the shin's position but undoes `foot_keep` of the shin's turn
        (1: it keeps the tilt it was drawn with) and turns `foot_turn` more (ccw)"""
        dth = lam - self.lam0
        dsh = dth - bend
        hip = self.hip
        th = rotate(self.thigh, hip, dth)
        knee2 = rot_pt(self.knee, hip, dth)
        sh = rotate(self.shin, hip, dth)
        sh = rotate(sh, knee2, dsh - dth)
        ank = rot_pt(rot_pt(self.ankle, hip, dth), knee2, dsh - dth)
        ft = rotate(self.foot, hip, dth)
        ft = rotate(ft, knee2, dsh - dth)
        undo = -dsh * foot_keep + foot_turn
        if abs(undo) > 0.01:
            ft = rotate(ft, ank, undo)
        out = fill_gaps(stack([th, sh, ft]), 2)
        if lift:
            out = np.roll(out, -int(lift), 0)
            ank = (ank[0], ank[1] - lift)
        return out, ank


class Legs:
    """The legs of a contact figure: Legs(fig).F (front, right in the image) and .R (rear)."""

    def __init__(self, fig):
        a = fig[..., 3] > 0
        ys = np.nonzero(a.any(1))[0]
        top, bot = ys.min(), ys.max()
        h = bot - top + 1
        # the crotch: going up from the boots, the last row (allowing a few single-run rows: soles
        # that touch, a thin bridge) that still has two separate legs
        y, miss, last2, low2 = bot, 0, None, None
        while y > top + 0.4 * h:
            if nruns(a[y]) >= 2:
                last2, miss = y, 0
                if low2 is None:
                    low2 = y
            elif last2 is not None:
                miss += 1
                if miss > 3:
                    break
            y -= 1
        y = (last2 if last2 is not None else bot) - 1
        self.y_c = y
        xs = np.nonzero(a[y])[0]
        self.x_c = float(xs.mean())
        low = a.copy()
        low[:y + 1] = False
        core = low.copy()
        core[(low2 if low2 is not None else bot - 3) + 1:] = False
        lab, n = ndimage.label(core)
        if n < 2:
            raise ValueError("legs do not separate")
        sizes = ndimage.sum(core, lab, range(1, n + 1))
        order = np.argsort(sizes)[::-1][:2]
        core_lab = np.zeros_like(lab)
        for j, i in enumerate(order):
            core_lab[lab == (i + 1)] = j + 1
        idx = ndimage.distance_transform_edt(core_lab == 0, return_distances=False, return_indices=True)
        full_lab = core_lab[idx[0], idx[1]]
        comps = [low & (full_lab == 1), low & (full_lab == 2)]
        comps.sort(key=lambda m: np.nonzero(m)[1].mean())
        rear, front = comps
        self.hip = (self.x_c, float(y - 2))
        self.torso = fig.copy()
        self.torso[low] = 0
        legs = []
        for m in (front, rear):
            yy, xx = np.nonzero(m)
            L = yy.max() - yy.min()
            rgb = fig[..., :3].astype(int)
            br = m & BROWN(rgb)
            yk = yy.min() + int(0.42 * L)
            if br.any():
                yb = np.nonzero(br)[0].min()
                yk = int(np.clip(yb, yy.min() + 0.3 * L, yy.min() + 0.55 * L))
            ya = yy.min() + int(0.82 * L)
            legs.append(Leg(m, fig, self.hip, yk, ya))
        self.F, self.R = legs
        self.bot = bot


def join(torso, leg_layers, shift=(0, 0)):
    """leg layers (bottom first) shifted by `shift` under the torso"""
    dx, dy = shift
    out = []
    for l in leg_layers:
        l2 = np.roll(np.roll(l, dy, 0), dx, 1)
        out.append(l2)
    return stack(out + [torso])


# ---------------------------------------------------------------- whole walk cycles

CANVAS = (260, 210)         # sheet-size canvas the posed figures are put on, hip at HIP
HIP = (130, 120)


def to_canvas(img, pt, hip=HIP):
    """img on the canvas with its point pt (x, y) at the hip"""
    out = np.zeros((CANVAS[1], CANVAS[0], 4), np.uint8)
    dx, dy = int(round(hip[0] - pt[0])), int(round(hip[1] - pt[1]))
    h, w = img.shape[:2]
    x0, y0 = max(0, dx), max(0, dy)
    sx0, sy0 = max(0, -dx), max(0, -dy)
    ww, hh = min(w - sx0, CANVAS[0] - x0), min(h - sy0, CANVAS[1] - y0)
    out[y0:y0 + hh, x0:x0 + ww] = img[sy0:sy0 + hh, sx0:sx0 + ww]
    return out


# Gait tables, per frames in the cycle. Leg A: thigh line angle (x alpha, + = forward) at each
# frame: heel strike, loading, mid-stance, push-off (the stance, half the cycle), then the swing:
# knee bent (degrees), foot lifted (sheet px), reaching. Leg B is half a cycle behind.
SIDE_TH = {8: [1.0, 0.55, 0.0, -0.55, -1.0, -0.55, 0.2, 0.8], 6: [1.0, 0.0, -1.0, -0.55, 0.3, 0.85]}
SIDE_BEND = {8: [0, 0, 0, 0, 0, 24, 34, 12], 6: [0, 0, 0, 24, 34, 10]}
SIDE_LIFT = {8: [0, 0, 0, 0, 0, 5, 9, 3], 6: [0, 0, 0, 5, 9, 3]}


def torso_of(fig, y_c):
    """(the figure above the crotch row y_c, its hip point): the band of rows above y_c gives x"""
    a = fig[..., 3] > 0
    band = np.nonzero(a[max(0, y_c - 8):y_c + 1].any(0))[0]
    t = fig.copy()
    t[y_c + 1:] = 0
    return t, (float(band.mean()), float(y_c - 2))


def torsos_of(figs, slack=3):
    """[(torso, hip)] for every figure: cut at its own crotch, unless that is more than `slack` px
    off the others' (relative to the top of the figure): then at the median"""
    info = []
    for f in figs:
        top = np.nonzero((f[..., 3] > 0).any(1))[0].min()
        try:
            info.append((top, Legs(f).y_c - top))
        except ValueError:
            info.append((top, None))
    rel = sorted(r for _, r in info if r is not None)
    med = rel[len(rel) // 2]
    out = []
    for f, (top, r) in zip(figs, info):
        if r is None or abs(r - med) > slack:
            r = med
        out.append(torso_of(f, top + r))
    return out


def side_cycle(figs, ref, alpha=None, stride=1.0, frames=8, order=None, rise=0.4):
    """The 8-frame side-on walk of `figs` (sheet-size RGBA figures; their torsos are used frame by
    frame, `order` = which figure's torso for each frame): legs from the contact figure figs[ref],
    posed to the gait tables (the sheet's contact stride times `stride`). The body rises as the
    stance leg straightens, by `rise` of that (the knee would give): the rest sinks the sole below
    the ground row. Returns canvas-size frames and GROUND, the row of the contact frames' soles;
    the hip is on HIP."""
    L = Legs(figs[ref])
    if alpha is None:
        alpha = 0.5 * (L.F.lam0 - L.R.lam0)
    alpha *= stride
    tors = torsos_of(figs)
    ground = HIP[1] + (L.bot - L.hip[1])
    posed = []
    for p in range(frames):
        layers = []
        stance = None
        for who, ph in (("A", p), ("B", (p + frames // 2) % frames)):
            t = SIDE_TH[frames][ph] * alpha
            src = L.F if t > 0.15 * alpha else L.R
            bd = SIDE_BEND[frames][ph]
            lay, _ = src.pose(t, bd, foot_keep=1.0 if bd == 0 else 0.5, lift=SIDE_LIFT[frames][ph])
            lay = to_canvas(lay, L.hip)
            layers.append(lay)
            if (who == "A") == (p < frames // 2):
                stance = lay
        sole = np.nonzero((stance[..., 3] > 0).any(1))[0].max()
        posed.append((layers, sole))
    sole0 = posed[0][1]
    out = []
    for p in range(frames):
        layers, sole = posed[p]
        k = order[p] if order else p % len(figs)
        torso, hip = tors[k]
        shift = int(round(ground - sole0 - rise * (sole - sole0)))
        legs = stack([np.roll(l, shift, 0) for l in layers])
        t_c = np.roll(to_canvas(torso, hip), shift, 0)
        out.append(stack([legs, t_c]))
    return out, ground


# ---------------------------------------------------------------- front and back views

# vertical offset (sheet px, + = down the screen) of the boots of leg A at phases 0..7: the foot
# that is forward is lower on the screen, the rear one higher, the swinging one lifted; leg B is 4
# frames behind. BOB: the whole figure's rise at the passing frames.
FRONT_DY = {8: [4, 2, 0, -2, -4, -6, -6, -2], 6: [4, 0, -4, -6, -6, -1]}
FRONT_BOB = {8: [0, -1, -3, -1, 0, -1, -3, -1], 6: [0, -3, -1, 0, -3, -1]}


class FrontLegs:
    """The legs of a figure seen from the front or back (they touch, so they are split down the
    middle): boots (below the knee line) can be moved up and down the screen separately."""

    def __init__(self, fig, y_hip=None, y_knee=None, x_mid=None):
        a = fig[..., 3] > 0
        ys = np.nonzero(a.any(1))[0]
        top, bot = ys.min(), ys.max()
        h = bot - top + 1
        self.bot = bot
        self.y_hip = y_hip if y_hip is not None else int(top + 0.60 * h)
        self.y_knee = y_knee if y_knee is not None else int(top + 0.78 * h)
        low = a.copy()
        low[:self.y_hip + 1] = False
        if x_mid is None:
            # the seam between the legs: the emptiest column (below the knee) near the middle
            occ = a[self.y_knee:bot + 1].sum(0).astype(float)
            xs_ = np.nonzero(a[self.y_knee:bot + 1].any(0))[0]
            c = 0.5 * (xs_.min() + xs_.max())
            lo, hi = int(c - 0.25 * (xs_.max() - xs_.min())), int(c + 0.25 * (xs_.max() - xs_.min()))
            occ = np.convolve(occ, np.ones(3) / 3.0, "same")
            seg = occ[lo:hi + 1] + 0.02 * np.abs(np.arange(lo, hi + 1) - c)
            x_mid = lo + int(np.argmin(seg)) + 0.5
        self.x_mid = x_mid
        xs = np.arange(a.shape[1])[None, :]
        self.legs = []
        for m in (low & (xs < x_mid), low & (xs >= x_mid)):
            self.legs.append(self._split(m, fig))
        self.torso = fig.copy()
        self.torso[low] = 0
        self.hip = (float(x_mid), float(self.y_hip))

    def _split(self, m, fig):
        rows = np.arange(m.shape[0])[:, None]
        upper = np.where((m & (rows < self.y_knee + 3))[..., None], fig, 0).astype(np.uint8)
        boot = np.where((m & (rows >= self.y_knee))[..., None], fig, 0).astype(np.uint8)
        return upper, boot

    def pose(self, side, dy):
        """leg `side` (0 left in the image, 1 right) with its boot moved dy px down the screen"""
        upper, boot = self.legs[side]
        dy = int(round(dy))
        b = np.roll(boot, dy, 0)
        if dy > 0:
            b[:self.y_knee + dy] = 0
            # the leg stretches: the boot's first row repeated up into the gap
            top = np.nonzero((boot[..., 3] > 0).any(1))[0].min()
            for y in range(self.y_knee, self.y_knee + dy + 1):
                b[y] = np.where((boot[top][:, 3:4] > 0), boot[top], 0)
        out = stack([upper, b])
        return fill_gaps(out, 1)


def resized(fig, k):
    """fig scaled by k (bicubic on premultiplied colour, hard alpha)"""
    h, w = fig.shape[:2]
    a = fig[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([fig[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    im = Image.fromarray(pre, "RGBA").resize((int(round(w * k)), int(round(h * k))), Image.BICUBIC)
    s_ = np.asarray(im).astype(np.float32)
    al = s_[..., 3:4] / 255.0
    out = np.zeros(s_.shape, np.uint8)
    out[..., :3] = np.where(al > 0.02, s_[..., :3] / np.maximum(al, 0.02), 0).clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.5, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def figure_h(f):
    ys = np.nonzero((f[..., 3] > 0).any(1))[0]
    return ys.max() - ys.min() + 1


def front_cycle(figs, ref, frames=8, order=None, legs_fig=None, **kw):
    """The 8-frame walk of a man seen from the front or back: figs' torsos frame by frame, and the
    legs of `legs_fig` (default figs[ref]; from another sheet it is scaled to match) with the boots
    moved up and down the screen. Returns canvas frames and GROUND."""
    lf = figs[ref] if legs_fig is None else resized(legs_fig, figure_h(figs[ref]) / float(figure_h(legs_fig)))
    F = FrontLegs(lf, **kw)
    ftop = np.nonzero((lf[..., 3] > 0).any(1))[0].min()
    rel = F.y_hip - ftop
    tors = []
    for f in figs:
        a = f[..., 3] > 0
        top = np.nonzero(a.any(1))[0].min()
        y = top + rel
        t = f.copy()
        t[y + 1:] = 0
        band = np.nonzero(a[max(0, y - 8):y + 1].any(0))[0]
        tors.append((t, (float(band.mean()), float(y))))
    ground = HIP[1] + (F.bot - F.hip[1])
    out = []
    for p in range(frames):
        k = order[p] if order else p % len(figs)
        lay = []
        for side, ph in ((0, p), (1, (p + frames // 2) % frames)):
            lay.append(to_canvas(F.pose(side, FRONT_DY[frames][ph]), F.hip))
        t = to_canvas(tors[k][0], tors[k][1])
        frame = stack(lay + [t])
        frame = np.roll(frame, int(FRONT_BOB[frames][p]), 0)
        out.append(frame)
    return out, ground
