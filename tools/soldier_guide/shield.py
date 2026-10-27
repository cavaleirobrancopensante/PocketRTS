"""Clock Soldier SHIELD FORWARD (docs/clock_soldier_shield.md): the stance's idle and walk strips, built in code from the
game's own painted strips (assets/units/clock_soldier/idle_<d>.png, walk_<d>.png) until ChatGPT paints them.

How: the painted shield is cut out of the W idle (the one view where it faces us whole), the shield on the soldier's arm
is wiped off each frame (an ellipse per view, filled from the body pixels next to it where it covered the body), and the
cut-out shield is put back in FRONT of the soldier: over the body when it faces the camera or sideways (S, SE, E, SW, W),
under the body when it faces away (N, NE, NW: only its rim shows round the shoulders). Side views squash it (seen edge
on). It follows the body's bob from frame to frame. The sword stays in the RIGHT hand: nothing is done to it.
Out: assets/units/clock_soldier/guard_<d>.png and guard_walk_<d>.png (same cell 78 x 66, same frame counts),
     art/redraws/clock_soldier_shield_guide.png (8 rows S SE E NE N NW W SW, the idle frames then the walk frames, on navy,
     x4), and the ChatGPT guides art/redraws/clock_soldier_shield_{idle,walk}_{east,west}_guide.png (laid out like the
     painted sheets: 1536 x 1024, navy, east rows S SE E NE N, west rows SW W NW).
  python3 tools/soldier_guide/shield.py"""
import numpy as np
from PIL import Image

D = 'assets/units/clock_soldier/'
CW, CH = 78, 66
DIRS = ['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw']
# the W idle's shield (cell px): ellipse centre and radii
SRC = (32.5, 42.0, 8.0, 9.6)
# per view: the shield on the arm to wipe (cx, cy, rx, ry), where the shield goes (cx, cy), its x squash, scale, and
# whether it is drawn over the body (facing the camera or sideways) or under it (facing away)
V = {
    's':  dict(old=(54.5, 40.0, 5.6, 9.6), new=(40.0, 37.0), sq=1.00, sc=1.00, over=True),
    'se': dict(old=(56.5, 39.5, 4.6, 8.6), new=(45.0, 37.0), sq=0.80, sc=1.00, over=True),
    'e':  dict(old=(28.2, 38.0, 4.4, 8.6), new=(46.5, 37.0), sq=0.45, sc=1.00, over=True),
    'ne': dict(old=(27.6, 37.2, 5.6, 9.8), new=(46.0, 28.0), sq=0.75, sc=1.10, over=False),
    'n':  dict(old=(23.5, 41.0, 6.4, 10.6), new=(39.0, 24.0), sq=1.00, sc=1.15, over=False),
    'nw': dict(old=(26.0, 40.0, 6.6, 9.8), new=(32.0, 28.0), sq=0.75, sc=1.10, over=False),
    'w':  dict(old=None, new=(29.0, 36.5), sq=0.70, sc=1.00, over=True),
    'sw': dict(old=(48.5, 42.5, 8.6, 10.0), new=(36.5, 37.0), sq=0.80, sc=1.00, over=True),
}


def load(name):
    return np.array(Image.open(D + name).convert('RGBA')).astype(np.float32)


def frames(a):
    n = a.shape[1] // CW
    return [a[:, i * CW:(i + 1) * CW].copy() for i in range(n)]


def top_y(f):
    ys = np.where(f[:, :, 3] > 40)[0]
    return int(ys.min()) if len(ys) else 0


def ell(cx, cy, rx, ry, shape=(CH, CW)):
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
    return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0


def cut_shield():
    f = frames(load('idle_w.png'))[0]
    cx, cy, rx, ry = SRC
    m = ell(cx, cy, rx, ry)
    x0, x1 = int(cx - rx) - 1, int(cx + rx) + 2
    y0, y1 = int(cy - ry) - 1, int(cy + ry) + 2
    s = f[y0:y1, x0:x1].copy()
    s[:, :, 3] *= m[y0:y1, x0:x1]
    # (never the player colour: the game's shader paints pure red as the team's)
    red = (s[:, :, 0] > 200) & (s[:, :, 1] < 40) & (s[:, :, 2] < 40)
    s[red, 0] = 180
    return s, (cx - x0, cy - y0)


def place(shield, centre, sq, sc):
    """The shield resized (squash on x), as an RGBA layer of a cell, centred on `centre`."""
    img = Image.fromarray(shield.clip(0, 255).astype(np.uint8))
    w = max(3, int(round(img.width * sq * sc)))
    h = max(3, int(round(img.height * sc)))
    img = img.resize((w, h), Image.NEAREST)
    layer = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    layer.alpha_composite(img, (int(round(centre[0] - w / 2.0)), int(round(centre[1] - h / 2.0))))
    a = np.array(layer).astype(np.float32)
    # the rim: one darker ring so it reads against the body
    al = a[:, :, 3] > 40
    edge = al & ~(np.roll(al, 1, 0) & np.roll(al, -1, 0) & np.roll(al, 1, 1) & np.roll(al, -1, 1))
    a[edge, :3] *= 0.55
    return a


def wipe(f, old):
    """Take the shield off the arm: its pixels go; where the body was behind it, the body's nearest row fills in."""
    cx, cy, rx, ry = old
    m = ell(cx, cy, rx, ry)
    out = f.copy()
    out[m, 3] = 0
    # fill the holes inside the body's outline (between body pixels on the same row) from the nearest body pixel
    body = (out[:, :, 3] > 40)
    for y in range(CH):
        xs = np.where(m[y])[0]
        if len(xs) == 0:
            continue
        row = np.where(body[y])[0]
        if len(row) == 0:
            continue
        lo, hi = row.min(), row.max()
        for x in xs:
            if lo < x < hi:
                k = row[np.argmin(np.abs(row - x))]
                out[y, x] = out[y, k]
                out[y, x, :3] *= 0.85
    return out


def compose(f, layer, over):
    a = Image.fromarray(f.clip(0, 255).astype(np.uint8))
    b = Image.fromarray(layer.clip(0, 255).astype(np.uint8))
    if over:
        a.alpha_composite(b)
        return a
    b.alpha_composite(a)
    return b


def main():
    shield, _ = cut_shield()
    guide_rows = []
    for d in DIRS:
        v = V[d]
        idle = frames(load('idle_%s.png' % d))
        t0 = top_y(idle[0])
        row = []
        for anim, fr in (('guard', idle), ('guard_walk', frames(load('walk_%s.png' % d)))):
            outs = []
            for f in fr:
                dy = top_y(f) - t0      # (the body's bob: the shield rides with it)
                f2 = f
                if v['old'] is not None:      # (W: the painted shield is already toward us; the new one goes over it, raised)
                    f2 = wipe(f, (v['old'][0], v['old'][1] + dy, v['old'][2], v['old'][3]))
                layer = place(shield, (v['new'][0], v['new'][1] + dy), v['sq'], v['sc'])
                outs.append(compose(f2, layer, v['over']))
            sheet = Image.new('RGBA', (CW * len(outs), CH), (0, 0, 0, 0))
            for i, o in enumerate(outs):
                sheet.alpha_composite(o, (i * CW, 0))
            sheet.save(D + '%s_%s.png' % (anim, d))
            row += outs
        guide_rows.append(row)
    n = max(len(r) for r in guide_rows)
    g = Image.new('RGBA', (CW * n, CH * len(guide_rows)), (0, 22, 48, 255))
    for j, r in enumerate(guide_rows):
        for i, o in enumerate(r):
            g.alpha_composite(o, (i * CW, j * CH))
    g = g.resize((g.width * 4, g.height * 4), Image.NEAREST)
    g.save('art/redraws/clock_soldier_shield_guide.png')
    # the ChatGPT guides, laid out like the painted sheets they go with (1536 x 1024, navy; east 5 rows S SE E NE N,
    # west 3 rows SW W NW; idle 4 frames, walk 6): each figure x3, NEAREST, centred in its cell, feet on one line
    for side, rows in (('east', ['s', 'se', 'e', 'ne', 'n']), ('west', ['sw', 'w', 'nw'])):
        for anim, k0, cols in (('idle', 0, 4), ('walk', 4, 6)):
            sheet = Image.new('RGBA', (1536, 1024), (0, 22, 48, 255))
            cw, ch = 1536 / cols, 1024 / len(rows)
            for r, d in enumerate(rows):
                row = guide_rows[DIRS.index(d)]
                for c in range(cols):
                    f = row[k0 + c].resize((CW * 3, CH * 3), Image.NEAREST)
                    x = int(c * cw + (cw - f.width) / 2)
                    y = int(r * ch + ch - 12 - f.height)
                    sheet.alpha_composite(f, (x, y))
            sheet.convert('RGB').save('art/redraws/clock_soldier_shield_%s_%s_guide.png' % (anim, side))
    print('wrote guard / guard_walk strips for', ', '.join(DIRS))


if __name__ == '__main__':
    main()
