"""The Spring Catapult's cog wheel, rebuilt from ChatGPT's painted wheel (art/redraws/catapult_wheel_chatgpt.png: the
wheel face-on on the left, edge-on on the right) so it can turn in code.

ChatGPT's 12 teeth are nearly even (a few degrees off) and its 8 bolts are up to 5 degrees off. As the Escapement's
wheel was rebuilt from one painted tooth (tools/press_anim/escapement_work.py), the ring here is rebuilt so that every
tooth and every bolt is the same: in polar coordinates each tooth sector (and each bolt sector) is lined up on its
measured middle and the MEDIAN of all of them is laid round the wheel at even steps (30 deg for the teeth and the rim,
45 deg for the bolts). The painted hub ball in the middle is kept as painted and never turns (a sphere).

The median lays the same light on every tooth, so the painting's big light and shade is put back with a fixed light map
(the ratio of the painting's blurred brightness to the rebuilt wheel's): the wheel turns under the light, the highlight
stays top-left. Edge-on: the tooth bars are unrolled to angle (y = -R cos a), lined up the same way, and rolled on.

  render_face(deg, w, h)  -> RGBA uint8 (h x w), the wheel turned deg (screen clockwise), squashed into w x h
  render_edge(deg, w, h, hub_right=True) -> RGBA uint8, the wheel edge-on, turned deg (its front going up)"""
import math
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SRC = np.array(Image.open('art/redraws/catapult_wheel_chatgpt.png').convert('RGB')).astype(float)
NAVY = SRC[5, 5].copy()
CX, CY = 559.46, 479.11           # the face's middle (fitted to the tooth roots)
R_TIP = 228.0                      # the teeth's tips
R_HUB = 52.0                       # the hub ball (kept, never turns)
R_FACE = 141.0                     # the face plate with the bolts reaches here; past it the rim and the teeth
TEETH, BOLTS = 12, 8
B = int(R_TIP + 6)                 # half the square worked in


def _mask(a):
    m = np.abs(a - NAVY).sum(-1) > 45
    return ndi.binary_fill_holes(m)


def _centres(prof, n, period, near):
    """the measured middles of n features (teeth / bolts) near the even angles `near`"""
    return near


def _polar(img, alpha, r0, r1, na=1440):
    """img sampled on a polar grid: [r, a] for r in r0..r1 (1 px), a in 0..360 (na steps), bilinear"""
    rs = np.arange(r0, r1 + 1, 1.0)
    an = np.radians(np.arange(na) * 360.0 / na)
    X = CX + rs[:, None] * np.cos(an)[None]
    Y = CY + rs[:, None] * np.sin(an)[None]
    out = np.stack([ndi.map_coordinates(img[..., c], [Y, X], order=1) for c in range(3)], -1)
    al = ndi.map_coordinates(alpha.astype(float), [Y, X], order=1)
    return rs, out, al


def _even(rs, P, A, measured, n, na=1440):
    """the polar strip rebuilt: each of the n sectors lined up on its measured middle, the median laid at even steps"""
    step = na // n
    meas = np.rint(np.array(measured) * na / 360.0).astype(int)
    c0 = int(round(np.mean([(m - k * step) for k, m in enumerate(meas)])))
    stackP, stackA = [], []
    for m in meas:
        idx = (m + np.arange(-step // 2, step - step // 2)) % na
        stackP.append(P[:, idx])
        stackA.append(A[:, idx])
    medP = np.median(np.array(stackP), 0)
    medA = np.median(np.array(stackA), 0)
    outP = np.zeros_like(P)
    outA = np.zeros_like(A)
    for k in range(n):
        idx = (c0 + k * step + np.arange(-step // 2, step - step // 2)) % na
        outP[:, idx] = medP
        outA[:, idx] = medA
    return outP, outA


def _measure(prof_r, n, guess_step):
    """middles of the bright features round a ring (deg): one peak per even sector"""
    pass


def _tooth_centres(alpha):
    out = []
    an = np.arange(0, 360, 0.25)
    rr = 0.5 * (185 + R_TIP)
    v = np.array([alpha[int(round(CY + rr * math.sin(math.radians(t)))), int(round(CX + rr * math.cos(math.radians(t))))]
                  for t in an], float)
    # a tooth = a run of 1s; take each run's middle (the run over 0 deg is joined)
    sh = int(np.argmin(v))
    v2 = np.roll(v, -sh)
    lab, k = ndi.label(v2 > 0.5)
    for i in range(1, k + 1):
        ix = np.nonzero(lab == i)[0]
        if len(ix) > 20:
            out.append((an[ix].mean() + sh * 0.25) % 360)
    return sorted(out)


def _bolt_centres(lum):
    an = np.arange(0, 360, 0.5)
    prof = np.array([max(lum[int(CY + r * math.sin(math.radians(t))), int(CX + r * math.cos(math.radians(t)))]
                         for r in range(105, 131)) for t in an])
    prof = ndi.gaussian_filter1d(prof, 4, mode='wrap')
    out = []
    for k in range(BOLTS):
        lo = (k * 45 - 22) % 360
        idx = (np.arange(int(lo * 2), int(lo * 2) + 90)) % 720
        out.append(an[idx[int(np.argmax(prof[idx]))]])
    return out


def _build():
    alpha = _mask(SRC)
    lum = SRC @ np.array([0.3, 0.59, 0.11])
    teeth = _tooth_centres(alpha)
    bolts = _bolt_centres(lum)
    assert len(teeth) == TEETH, teeth
    na = 1440
    rs1, P1, A1 = _polar(SRC, alpha, R_FACE, R_TIP + 4, na)
    P1e, A1e = _even(rs1, P1, A1, teeth, TEETH, na)
    rs2, P2, A2 = _polar(SRC, alpha, R_HUB - 2, R_FACE - 1, na)
    P2e, A2e = _even(rs2, P2, A2, bolts, BOLTS, na)
    # back to a square image (2B+1), inverse polar, bilinear
    yy, xx = np.mgrid[-B:B + 1, -B:B + 1].astype(float)
    rr = np.hypot(xx, yy)
    aa = (np.degrees(np.arctan2(yy, xx)) % 360) * na / 360.0
    img = np.zeros(rr.shape + (3,))
    al = np.zeros(rr.shape)
    for rs, P, A in ((rs1, P1e, A1e), (rs2, P2e, A2e)):
        sel = (rr >= rs[0]) & (rr <= rs[-1])
        ri = rr[sel] - rs[0]
        Pa = np.concatenate([P, P[:, :1]], 1)
        Aa = np.concatenate([A, A[:, :1]], 1)
        for c in range(3):
            img[..., c][sel] = ndi.map_coordinates(Pa[..., c], [ri, aa[sel]], order=1)
        al[sel] = ndi.map_coordinates(Aa, [ri, aa[sel]], order=1)
    # the hub (as painted) inside R_HUB
    hub = rr < R_HUB
    sy, sx = np.rint(CY + yy).astype(int), np.rint(CX + xx).astype(int)
    orig = SRC[sy, sx]
    orig_a = alpha[sy, sx].astype(float)
    img[hub] = orig[hub]
    al[hub] = 1.0
    # the light map: the painting's big light and shade over the rebuilt (evenly lit) wheel
    sig = 0.16 * R_TIP
    m0 = orig_a > 0.5
    m1 = al > 0.5
    L0 = ndi.gaussian_filter(lum[sy, sx] * m0, sig) / np.maximum(ndi.gaussian_filter(m0.astype(float), sig), 1e-3)
    L1 = ndi.gaussian_filter((img @ np.array([0.3, 0.59, 0.11])) * m1, sig) / \
        np.maximum(ndi.gaussian_filter(m1.astype(float), sig), 1e-3)
    light = np.clip(L0 / np.maximum(L1, 1.0), 0.55, 1.7)
    light[hub] = 1.0
    hub_img = np.zeros(rr.shape + (4,))
    hub_img[..., :3] = orig
    hub_img[..., 3] = hub & (orig_a > 0.5)
    return img, al, light, hub_img, teeth, bolts


FACE_IMG, FACE_A, LIGHT, HUB_IMG, TEETH_AT, BOLTS_AT = _build()


def face_big(deg):
    """the rebuilt face turned by deg (clockwise on screen), lit, with the still hub: RGBA float (2B+1 square)"""
    n = FACE_IMG.shape[0]
    yy, xx = np.mgrid[0:n, 0:n].astype(float) - B
    a = math.radians(-deg)
    c, s = math.cos(a), math.sin(a)
    sx, sy = c * xx - s * yy + B, s * xx + c * yy + B
    rgb = np.stack([ndi.map_coordinates(FACE_IMG[..., k], [sy, sx], order=1) for k in range(3)], -1)
    al = ndi.map_coordinates(FACE_A, [sy, sx], order=1)
    rgb *= LIGHT[..., None]
    out = np.zeros((n, n, 4))
    out[..., :3] = rgb
    out[..., 3] = al
    h = HUB_IMG[..., 3] > 0.5
    out[h] = HUB_IMG[h]
    return out


def _down(big, w, h):
    """premultiplied LANCZOS shrink to w x h, hard alpha"""
    a = np.clip(big[..., 3:4], 0, 1)
    pre = np.concatenate([np.clip(big[..., :3], 0, 255) * a, a * 255], -1).astype(np.float32)
    ch = [np.array(Image.fromarray(pre[..., k], 'F').resize((w, h), Image.LANCZOS)) for k in range(4)]
    s = np.stack(ch, -1)
    al = np.clip(s[..., 3] / 255.0, 0, 1)
    rgb = np.where(al[..., None] > 0.02, s[..., :3] / np.maximum(al[..., None], 0.02), 0)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255)
    out[..., 3] = np.where(al >= 0.5, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def render_face(deg, w, h):
    """the wheel turned deg (clockwise on screen) squashed into w x h px (tips to tips)"""
    big = face_big(deg)
    n = big.shape[0]
    k0 = B - R_TIP
    big = big[int(k0):n - int(k0), int(k0):n - int(k0)]
    return _down(big, w, h)


# ------------------------------------------------------------------ edge-on

def _edge_build():
    x0, x1, y0, y1 = 990, 1175, 250, 715
    E = SRC[y0:y1, x0:x1]
    m = _mask(E)
    ys, xs = np.nonzero(m)
    E, m = E[ys.min():ys.max() + 1, xs.min():xs.max() + 1], m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    H, W = m.shape
    # the hub ball on the right never turns: columns right of the tread
    r_, g_, b_ = E[..., 0], E[..., 1], E[..., 2]
    blue = m & (b_ > r_ + 40) & (b_ > 90)
    # the tread: the columns the tooth stack fills (the hub's collar and ball on its right never turn)
    cov = m.mean(0)
    hx = int(np.nonzero(cov > 0.6)[0].max()) + 1
    return E, m, hx


EDGE, EDGE_M, EDGE_HX = _edge_build()


def _edge_strip():
    """the tread unrolled to angle round the rim (0.25 deg steps over the half we see) and evened: the bar sectors
    (30 deg) lined up on the brightest phase, the median of the middle ones (the ends are squeezed) kept"""
    E, m, hx = EDGE, EDGE_M, EDGE_HX
    H, W = m.shape
    R, c = H / 2.0, (H - 1) / 2.0
    an = np.arange(0, 180, 0.25)
    ys = c - R * np.cos(np.radians(an))
    T = np.stack([ndi.map_coordinates(E[:, :hx, k], [np.repeat(ys[:, None], hx, 1),
                                                     np.repeat(np.arange(hx)[None], len(an), 0)], order=1)
                  for k in range(3)], -1)
    TA = ndi.map_coordinates(m[:, :hx].astype(float), [np.repeat(ys[:, None], hx, 1),
                                                      np.repeat(np.arange(hx)[None], len(an), 0)], order=1)
    lum = (T @ np.array([0.3, 0.59, 0.11])).mean(1)
    best = (-1, 0)
    for c0 in np.arange(0, 30, 0.25):
        idx = [int((c0 + 30 * k) * 4) for k in range(1, 5)]
        v = lum[idx].sum()
        if v > best[0]:
            best = (v, c0)
    c0 = best[1]
    st = []
    sa = []
    for k in range(1, 5):                  # sectors centred at c0 + 30, 60, 90, 120 (and 150 when inside)
        mid = c0 + 30 * k
        if mid - 15 < 8 or mid + 15 > 172:
            continue
        idx = (np.rint((mid + np.arange(-15, 15, 0.25)) * 4)).astype(int)
        st.append(T[idx])
        sa.append(TA[idx])
    return np.median(np.array(st), 0), np.median(np.array(sa), 0), c0


EDGE_STRIP, EDGE_STRIP_A, EDGE_C0 = _edge_strip()


def edge_big(deg):
    """the edge-on wheel with its tread turned deg: each row y is the angle a = acos(-(y - c) / R) round the rim and
    shows the evened bar strip at a - deg; the painting's light down the tread is kept (fixed per row); the hub ball's
    columns (on the right) never turn"""
    E, m, hx = EDGE, EDGE_M, EDGE_HX
    H, W = m.shape
    R, c = H / 2.0, (H - 1) / 2.0
    out = np.zeros((H, W, 4))
    out[..., :3] = E
    out[..., 3] = m
    lum = E[:, :hx] @ np.array([0.3, 0.59, 0.11])
    mm = m[:, :hx]
    sig = 10.0
    L0 = ndi.gaussian_filter1d((lum * mm).sum(1), sig) / np.maximum(ndi.gaussian_filter1d(mm.sum(1).astype(float), sig), 1)
    rows = np.zeros((H, hx, 3))
    ra = np.zeros((H, hx))
    for y in range(H):
        a = math.degrees(math.acos(np.clip(-(y - c) / R, -1, 1)))
        ph = ((a - deg - EDGE_C0 + 15.0) % 30.0)
        i = min(int(round(ph * 4)), EDGE_STRIP.shape[0] - 1)
        rows[y] = EDGE_STRIP[i]
        ra[y] = EDGE_STRIP_A[i]
    L1 = ndi.gaussian_filter1d((rows @ np.array([0.3, 0.59, 0.11]) * (ra > 0.5)).sum(1), sig) / \
        np.maximum(ndi.gaussian_filter1d((ra > 0.5).sum(1).astype(float), sig), 1)
    k = np.clip(L0 / np.maximum(L1, 1.0), 0.6, 1.6)
    out[:, :hx, :3] = rows * k[:, None, None]
    out[:, :hx, 3] = ra
    return out


def render_edge(deg, w, h, hub_right=True, hub=True):
    big = edge_big(deg)
    if not hub:
        big = big[:, :EDGE_HX]
    if not hub_right:
        big = big[:, ::-1]
    return _down(big, w, h)


if __name__ == '__main__':
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else '/tmp/cog.png'
    print('teeth', np.round(TEETH_AT, 1), 'bolts', BOLTS_AT)
    tiles = [render_face(d, 160, 160) for d in (0, 7.5, 15, 22.5)] + [render_face(0, 100, 150)]
    tiles += [render_edge(d, 40, 120) for d in (0, 10, 20)]
    W = sum(t.shape[1] + 8 for t in tiles)
    sh = Image.new('RGB', (W, 170), (0, 22, 48))
    x = 0
    for t in tiles:
        im = Image.fromarray(t, 'RGBA')
        sh.paste(im, (x, 0), im)
        x += t.shape[1] + 8
    sh = sh.resize((sh.width * 2, sh.height * 2), Image.NEAREST)
    sh.save(out)
