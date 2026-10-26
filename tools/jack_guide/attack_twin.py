"""Jack ATTACK with two launchers, composed in code from the painted two-launcher idle sheet (ChatGPT,
art/redraws/jack_idle_twin_chatgpt.png, frame 1 of the rows S SE E NE N) and ChatGPT's muzzle burst (art/redraws/jack_screw_fx.png
row 2, as tools/jack_guide/attack.py uses it).

Two strips per facing, one per arm: the arm fires (its drill screw leaves the tip, the burst plays there, the body kicks back
away from that barrel and the spring flexes), then a new screw slides back out of the barrel. The game plays the strips in turn,
one shot from each arm, and launches the screw from that arm's tip on the fire frame.

The side view (E) shows the far arm hanging down and back in the painting: it is erased and the far launcher is drawn as a
darkened copy of the near forearm, a little higher and behind, so both barrels point at the target.

Out: art/redraws/jack_attack_twin_body.png (5 rows x 12: frames 0-5 the robot's RIGHT arm fires, 6-11 its LEFT; 256 x 204
cells, navy, no burst), art/redraws/jack_attack_twin.png and .gif (with the burst, for review), art/redraws/jack_attack_twin_tips.json
(per facing and arm: the tip on the fire frame in cell px and the barrel direction).
  python3 tools/jack_guide/attack_twin.py"""
import json, math
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SRC = 'art/redraws/jack_idle_twin_chatgpt.png'
NAVY = np.array([1, 27, 58])
FX = 'art/redraws/jack_screw_fx.png'
BURST = [(60, 360, 330, 600), (420, 360, 720, 600), (800, 360, 1120, 600), (1210, 400, 1460, 560)]
DIRS = ['s', 'se', 'e', 'ne', 'n']
PAD = 8
# per facing: the arms (robot's right 'r', robot's left 'l'): the drill tip's point, estimated in the crop (box - PAD), and the
# barrel's direction (screen, y down). E: 'l' is the far arm, rebuilt.
ARMS = {
    's':  {'r': ((16, 135), (-0.59, 0.80)), 'l': ((168, 133), (0.57, 0.82))},
    'se': {'r': ((16, 128), (-0.54, 0.84)), 'l': ((143, 125), (0.48, 0.88))},
    'e':  {'r': ((146, 123), (0.89, 0.46)), 'l': ((14, 133), (-0.53, 0.85))},
    'ne': {'r': ((152, 119), (0.67, 0.74)), 'l': ((15, 106), (-0.64, 0.77))},
    'n':  {'r': ((157, 113), (0.67, 0.74)), 'l': ((14, 111), (-0.67, 0.74))},
}
CONE = 22          # px along the barrel from the point: the drill screw
CONE_W = 10        # px either side of the barrel's axis
E_FAR_OFF = (-4, -16)         # the rebuilt far launcher: where it sits against the near one (above it, a little back)
E_FAR_DARK = 0.78
E_FOREARM = ((84, 104), 12)   # the near forearm's corridor: from this point out to the tip, this half width
E_ERASE = [(45, 58, 100), (50, 100, 141)]   # the painted far arm (and its shoulder): silhouette pixels left of x, y0 <= y < y1
KICK = [0, 5, 3.5, 2, 1, 0]   # px, per frame: the body kicks back from the firing barrel
TIP_OUT = [1, 0, 0, 0.35, 0.75, 1]   # the firing arm's screw: gone on the shot, then it slides back out
BF = [None, 0, 1, 2, 3, None]        # burst frame
CW, CH = 256, 204
RH = 250           # review sheet cell height


def figures():
    im = np.asarray(Image.open(SRC).convert('RGB')).astype(int)
    m = np.abs(im - NAVY).sum(2) > 40
    lab, n = ndi.label(ndi.binary_dilation(m, iterations=6))
    boxes = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        if (lab[sl] == i + 1).sum() > 1500:
            boxes.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))
    boxes.sort(key=lambda b: ((b[1] + b[3]) // 2) // 120 * 10000 + b[0])
    rows = []
    for b in boxes:
        if not rows or abs((b[1] + b[3]) / 2 - (rows[-1][0][1] + rows[-1][0][3]) / 2) > 60:
            rows.append([])
        rows[-1].append(b)
    out = []
    for r in range(5):
        x0, y0, x1, y1 = sorted(rows[r])[0]
        c = im[y0 - PAD:y1 + PAD, x0 - PAD:x1 + PAD]
        a = np.zeros(c.shape[:2] + (4,), np.uint8)
        a[..., :3] = c.clip(0, 255)
        a[..., 3] = (np.abs(c - NAVY).sum(2) > 40) * 255
        out.append(a)
    return out


def refine(sil, apex, u):
    """The silhouette's farthest pixel along u near the estimate."""
    ys, xs = np.nonzero(sil)
    p = np.stack([xs, ys], 1).astype(float)
    near = np.hypot(p[:, 0] - apex[0], p[:, 1] - apex[1]) < 12
    p = p[near]
    return p[np.argmax(p @ np.array(u))]


def cone_mask(sil, apex, u, length=CONE, half=CONE_W):
    h, w = sil.shape
    yy, xx = np.mgrid[0:h, 0:w]
    rx, ry = xx - apex[0], yy - apex[1]
    along = rx * u[0] + ry * u[1]
    perp = np.abs(-rx * u[1] + ry * u[0])
    m = sil & (along >= -length) & (perp <= half)
    return ndi.binary_dilation(m, iterations=1) & sil


def shift(a, dx, dy):
    o = np.zeros_like(a)
    h, w = a.shape[:2]
    dx, dy = int(round(dx)), int(round(dy))
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    o[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = a[ys0:ys1, xs0:xs1]
    return o


def over(dst, src):
    """src over dst, both RGBA uint8 (straight alpha, binary here)."""
    m = src[..., 3] > 0
    dst[m] = src[m]
    return dst


def layer(a, mask):
    o = np.zeros_like(a)
    o[mask] = a[mask]
    return o


def kick(a, base_top, spring_top, kx, ky):
    """Kick the figure by (kx, ky) above the spring; the base plate stays put and the spring flexes between."""
    o = np.zeros_like(a)
    h = a.shape[0]
    for y in range(h):
        if y >= base_top:
            f = 0.0
        elif y <= spring_top:
            f = 1.0
        else:
            f = (base_top - y) / float(base_top - spring_top)
        row = shift(a[y:y + 1], kx * f, 0)
        yy = int(round(y + ky * f))
        if 0 <= yy < h:
            m = row[0, :, 3] > 0
            o[yy, m] = row[0, m]
    return o


def base_lines(sil):
    """The base plate's top and the spring's top (rows), from the silhouette's width row by row."""
    h = sil.shape[0]
    widths = sil.sum(1)
    ys = np.nonzero(widths)[0]
    bottom = ys[-1]
    bw = widths[bottom - 8:bottom + 1].max()
    y = bottom
    while y > 0 and widths[y] > bw * 0.62:
        y -= 1
    base_top = y + 1
    # the spring: the narrow part above the plate, up to where the body/arms widen again
    sw = widths[base_top - 6:base_top].min()
    y = base_top - 6
    while y > 0 and widths[y] < max(sw * 1.35, sw + 12):
        y -= 1
    return base_top, y + 1


def build():
    figs = figures()
    fx = np.asarray(Image.open(FX).convert('RGB')).astype(int)
    bursts = []
    for b in BURST:
        c = fx[b[1]:b[3], b[0]:b[2]]
        a = np.zeros(c.shape[:2] + (4,), np.uint8)
        a[..., :3] = c.clip(0, 255)
        a[..., 3] = (np.abs(c - np.array([0, 22, 48])).sum(2) > 40) * 255
        bursts.append(Image.fromarray(a, 'RGBA'))
    body = Image.new('RGB', (12 * CW, 5 * CH), tuple(int(v) for v in NAVY))
    full = Image.new('RGB', (12 * CW, 5 * RH), tuple(int(v) for v in NAVY))
    tips = {}
    for r, d in enumerate(DIRS):
        a = figs[r]
        sil = a[..., 3] > 0
        arms = {}
        for k in ('r', 'l'):
            apex, u = ARMS[d][k]
            u = np.array(u) / np.hypot(*u)
            arms[k] = [refine(sil, apex, u), u]
        main = a.copy()
        far = None
        if d == 'e':
            # erase the painted far arm (it hangs down and back) and build the far launcher from the near forearm
            h, w = sil.shape
            yy, xx = np.mgrid[0:h, 0:w]
            for x_lim, y0, y1 in E_ERASE:
                main[sil & (xx < x_lim) & (yy >= y0) & (yy < y1)] = 0
            ap, u = arms['r']
            start, half = E_FOREARM
            st = np.array(start, float)
            ax = ap - st
            ln = np.hypot(*ax)
            ax /= ln
            rx, ry = xx - st[0], yy - st[1]
            along = rx * ax[0] + ry * ax[1]
            perp = np.abs(-rx * ax[1] + ry * ax[0])
            fore = sil & (along >= 0) & (along <= ln + 2) & (perp <= half)
            fl = layer(a, fore)
            fl[..., :3] = (fl[..., :3] * E_FAR_DARK).astype(np.uint8)
            far = shift(fl, *E_FAR_OFF)
            arms['l'] = [ap + np.array(E_FAR_OFF, float), u]
        cones = {}
        for k in ('r', 'l'):
            ap, u = arms[k]
            if d == 'e' and k == 'l':
                fs = far[..., 3] > 0
                cm = cone_mask(fs, ap, u)
                cones[k] = (layer(far, cm), u)
                far = far.copy()
                far[cm] = 0
            else:
                cm = cone_mask(sil, ap, u)
                cones[k] = (layer(a, cm), u)
                main[cm] = 0
        base_top, spring_top = base_lines(sil)
        tips[d] = {}
        for side, k in enumerate(('r', 'l')):
            ap, u = arms[k]
            ang = math.degrees(math.atan2(u[1], u[0]))
            for f in range(6):
                fig = np.zeros_like(a)
                # bottom to top: the far launcher's screw and barrel (E), the screws, the figure
                for kk in (('l', 'r') if d == 'e' else ('r', 'l')):
                    cl, cu = cones[kk]
                    t = TIP_OUT[f] if kk == k else 1.0
                    back = (1.0 - t) * CONE
                    if t > 0.0:
                        over(fig, shift(cl, -cu[0] * back, -cu[1] * back))
                    if d == 'e' and kk == 'l':
                        over(fig, far)
                over(fig, main)
                kx, ky = -u[0] * KICK[f], -u[1] * KICK[f] * 0.5
                fig = kick(fig, base_top, spring_top, kx, ky)
                h, w = fig.shape[:2]
                ox, oy = (CW - w) // 2, CH - h - 6
                cell = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
                cell.alpha_composite(Image.fromarray(fig, 'RGBA'), (ox, oy))
                bgc = Image.new('RGB', (CW, CH), tuple(int(v) for v in NAVY))
                bgc.paste(cell, (0, 0), cell)
                col = side * 6 + f
                body.paste(bgc, (col * CW, r * CH))
                tip_now = (ox + ap[0] + kx, oy + ap[1] + ky)
                if f == 1:
                    tips[d][k] = {'tip': [round(float(tip_now[0]), 1), round(float(tip_now[1]), 1)],
                                  'dir': [round(float(u[0]), 3), round(float(u[1]), 3)]}
                rc = Image.new('RGBA', (CW, RH), (0, 0, 0, 0))     # (review: a taller cell, so a downward burst shows)
                rc.alpha_composite(cell, (0, 0))
                if BF[f] is not None:
                    bimg = bursts[BF[f]]
                    sc = 0.32
                    bimg = bimg.resize((int(bimg.width * sc), int(bimg.height * sc)), Image.LANCZOS)
                    reach = bimg.width * 0.42          # (the burst's centre, along the barrel, before it's turned)
                    bimg = bimg.rotate(-ang, resample=Image.BICUBIC, expand=True)
                    tx = tip_now[0] + u[0] * reach
                    ty = tip_now[1] + u[1] * reach
                    rc.alpha_composite(bimg, (int(tx - bimg.width / 2), int(ty - bimg.height / 2)))
                rbg = Image.new('RGB', (CW, RH), tuple(int(v) for v in NAVY))
                rbg.paste(rc, (0, 0), rc)
                full.paste(rbg, (col * CW, r * RH))
    body.save('art/redraws/jack_attack_twin_body.png')
    full.save('art/redraws/jack_attack_twin.png')
    with open('art/redraws/jack_attack_twin_tips.json', 'w') as fh:
        json.dump(tips, fh, indent=1)
    # review GIF: every facing side by side, right arm then left arm, twice
    frames, dur = [], []
    ms = [240, 70, 80, 90, 110, 160]
    for rep in range(2):
        for col in range(12):
            o = Image.new('RGB', (5 * CW, RH))
            for r in range(5):
                o.paste(full.crop((col * CW, r * RH, (col + 1) * CW, (r + 1) * RH)), (r * CW, 0))
            frames.append(o.resize((o.width * 3 // 2, o.height * 3 // 2), Image.NEAREST))
            dur.append(ms[col % 6])
    frames[0].save('art/redraws/jack_attack_twin.gif', save_all=True, append_images=frames[1:], duration=dur, loop=0)
    print('ok', json.dumps(tips))


if __name__ == '__main__':
    build()
