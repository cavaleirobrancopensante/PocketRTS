"""THE SPRING BALLISTA (gear mode's Clockwork tier 2; the owner's unit, 2026-10-27; docs/ballista.md) and its CREW.

From the owner's ChatGPT sheets (navy background):
  art/redraws/ballista_dirs.png         5 rows S, SE, E, NE, N; LEFT loaded, RIGHT fired. The front view (S) has the crank
                                        on the picture's right like the back view (N): it is MIRRORED here, so the crank
                                        sits on one side of the machine in every view.
  art/redraws/concepts/ballista_v1.png  the concept: the screw bolt in flight (right third) is cut out as the bolt sprite.
  art/redraws/winder_crew_<v>_chatgpt.png  the crew Winder, v = e, se, s, ne, n: row 1 PUSH, row 2 CRANK, 4 frames each
                                        (the e sheet has a third row: its row 2 is the dropped PULL, row 3 the crank).
Writes:
  assets/units/ballista/idle_<v>.png    loaded (1 frame)
  assets/units/ballista/walk_<v>.png    loaded (1 frame: the machine itself is not animated, its crew is)
  assets/units/ballista/attack_<v>.png  fired (1 frame: shown while it reloads)
  assets/units/ballista/death_<v>.png   4 frames MADE IN CODE from the fired frame (it sinks, sags and goes dark: there
                                        is no painted death; docs/art_style_inconsistency.md)
  assets/effects/ballista_bolt.png      the screw bolt in flight, pointing right
  assets/units/winder/push_<v>.png, crank_<v>.png   the crew strips (4 frames each), counts added to the "winder" entry
                                        of scripts/art_data.gd (his cell and anchor)
  assets/icons/ballista.png             its card portrait (the loaded SE view in the steel portrait frame, like round 13's
                                        Clockwork portraits)
  assets/icons/clockwork/ab_crew.png    the BOARD / CREW button (a Winder at the crank, in the Clockwork's bronze frame)
and prints the scripts/cw_art.gd SHEETS line, the bow's mouth per view (Defs.BALLISTA "mouth"), the crank and push spots.

SIZE: GS game px per sheet px, as decided for the Spring Catapult (tools/catapult_guide/anim.py: 1.5x the Netter); the
ballista sheet is drawn at the catapult sheet's scale (its S row is 274 px wide, the catapult's 274).
ANCHOR (the unit's point): the ground under the machine: x the middle of its lowest band (the wheels), y its bottom.
Loaded and fired frames each get their own anchor by that rule (the wheels do not move between the two).
PALETTE: tools/cw_palette.py (brass + player colour: the red bands are the player's colour; the spring drum's steel coil
keeps its steel).
CREW: each view scaled so the Winder is as tall as in his walk strip (the crank frames, upright, give the height); the
four frames of a row placed so their stem (the top of the clock) is still and their feet on the anchor line on average.
  python3 tools/import_ballista.py [--preview FILE]"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageEnhance
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import cw_palette  # noqa: E402
import import_winder_v2 as W  # noqa: E402

SHEET = 'art/redraws/ballista_dirs.png'
CONCEPT = 'art/redraws/concepts/ballista_v1.png'
CREW = 'art/redraws/winder_crew_%s_chatgpt.png'
DST = 'assets/units/ballista/'
WDST = 'assets/units/winder/'
DIRS = ['s', 'se', 'e', 'ne', 'n']
GS = 0.357            # game px per sheet px (the Spring Catapult's: 1.5x the Netter)
TOL = 40
BOLT_BOX = (1130, 400, 1440, 560)    # the bolt in flight on the concept (x0, y0, x1, y1), its spark burst left out
BOLT_LEN = 58.0       # px: the bolt in flight, fins to tip (the one in the groove is ~68: a little smaller reads better)
DEATH = 4


def recolour(o):
    """tools/cw_palette.py's rule with one exception for this machine: it has no blue paint. Its spring coil, the bolt
    and the bow strings are painted blue steel: they stay steel (greyed to the steel saturation), not player colour."""
    h, sat, v = cw_palette.hsv(o)
    blue = (o[..., 3] > 0) & cw_palette.is_blue(h, sat, v)
    out = cw_palette.recolour(o, "ballista")
    st = cw_palette.steel(o, blue)
    out[blue, :3] = st[blue, :3]
    return out


def keyed(a):
    bd = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(bd, 0)
    return np.abs(a - bg).sum(2) >= TOL, bg


def cells(path):
    """[row][col] -> RGBA crop (sheet px) of the 10 machines: big pieces grouped (the bow strings are thin)."""
    a = np.array(Image.open(path).convert('RGB')).astype(int)
    fg, _ = keyed(a)
    lab, n = ndi.label(ndi.binary_dilation(fg, iterations=6))
    boxes = ndi.find_objects(lab)
    sizes = ndi.sum(fg, lab, range(1, n + 1))
    keep = [i for i in range(n) if sizes[i] > 3000]
    keep.sort(key=lambda i: (boxes[i][0].start + boxes[i][0].stop) / 2)
    rows = [sorted(keep[k:k + 2], key=lambda i: boxes[i][1].start) for k in range(0, 10, 2)]
    out = []
    for r in rows:
        line = []
        for i in r:
            sl = boxes[i]
            m = fg[sl] & (lab[sl] == i + 1)
            o = np.zeros(m.shape + (4,), np.uint8)
            o[..., :3] = a[sl]
            o[..., 3] = m * 255
            o[~m] = 0
            line.append(o)
        out.append(line)
    return out


def anchor_of(o):
    """(x, y) of the ground under the machine: the middle of its lowest 12% (the wheels), its bottom."""
    ys, xs = np.nonzero(o[..., 3])
    bot = ys.max()
    low = ys >= bot - (bot - ys.min()) * 0.12
    return (xs[low].min() + xs[low].max()) / 2.0, float(bot + 1)


def place(o, ax, ay, cw, ch, cax, cay, s):
    """o (sheet px) with its anchor (ax, ay) put on (cax, cay) of a cw x ch game cell, shrunk by s."""
    BW, BH = int(round(cw / s)), int(round(ch / s))
    big = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
    big.paste(Image.fromarray(o, 'RGBA'), (int(round(cax / s - ax)), int(round(cay / s - ay))))
    g = W.shrink(np.array(big), cw / BW)
    out = np.zeros((ch, cw, 4), np.uint8)
    h, w = min(ch, g.shape[0]), min(cw, g.shape[1])
    out[:h, :w] = g[:h, :w]
    return out


def machine():
    rows = cells(SHEET)
    frames = {}     # (view, 'loaded'|'fired') -> (rgba sheet px, ax, ay)
    for v, row in zip(DIRS, rows):
        for st, o in zip(('loaded', 'fired'), row):
            if v == 's':
                o = o[:, ::-1].copy()
            ax, ay = anchor_of(o)
            o = recolour(o)
            frames[(v, st)] = (o, ax, ay)
    # one cell for all: the farthest any frame reaches from its anchor
    L = R = U = 0.0
    for o, ax, ay in frames.values():
        ys, xs = np.nonzero(o[..., 3])
        L, R, U = max(L, ax - xs.min()), max(R, xs.max() + 1 - ax), max(U, ay - ys.min())
    half = int(np.ceil(max(L, R) * GS)) + 3
    cw, cax = 2 * half, half
    cay = int(np.ceil(U * GS)) + 3
    ch = cay + 4
    out = {}
    for (v, st), (o, ax, ay) in frames.items():
        out[(v, st)] = cw_palette.snap_team(place(o, ax, ay, cw, ch, cax, cay, GS))
    os.makedirs(DST, exist_ok=True)
    for v in DIRS:
        Image.fromarray(out[(v, 'loaded')], 'RGBA').save(DST + 'idle_%s.png' % v)
        Image.fromarray(out[(v, 'loaded')], 'RGBA').save(DST + 'walk_%s.png' % v)
        Image.fromarray(out[(v, 'fired')], 'RGBA').save(DST + 'attack_%s.png' % v)
        Image.fromarray(np.concatenate([death_frame(out[(v, 'fired')], k, cay) for k in range(DEATH)], 1), 'RGBA') \
            .save(DST + 'death_%s.png' % v)
    print('cw_art.gd SHEETS: "ballista": [%d, %d, %d, %d],' % (cw, ch, cax, cay))
    mouths(out, cw, cax, cay)
    return out, (cw, ch, cax, cay)


def death_frame(f, k, cay):
    """Made in code (no painted death): the fired machine sinks onto its axles, sags and goes dark, frame by frame."""
    if k == 0:
        return f.copy()
    t = k / float(DEATH - 1)
    im = Image.fromarray(f, 'RGBA')
    h = f.shape[0]
    sy = 1.0 - 0.28 * t
    top = int(round(cay * (1 - sy)))
    sq = im.crop((0, 0, f.shape[1], cay)).resize((f.shape[1], max(1, cay - top)), Image.NEAREST)
    cv = Image.new('RGBA', (f.shape[1], h), (0, 0, 0, 0))
    cv.paste(sq, (0, top))
    cv.paste(im.crop((0, cay, f.shape[1], h)), (0, cay))
    rgb = ImageEnhance.Brightness(cv.convert('RGB')).enhance(1.0 - 0.45 * t)
    o = np.array(rgb.convert('RGBA'))
    o[..., 3] = np.array(cv)[..., 3]
    o[o[..., 3] == 0] = 0
    return o


def mouths(out, cw, cax, cay):
    """The bow's mouth per view (game px from the anchor): the far tip of the loaded bolt, found as the steel pixels
    farthest along the view's forward direction."""
    fwd = {'s': (0, 1), 'se': (0.8, 0.6), 'e': (1, 0), 'ne': (0.8, -0.6), 'n': (0, -1)}
    res = {}
    for v in DIRS:
        f = out[(v, 'loaded')]
        ys, xs = np.nonzero(f[..., 3])
        dx, dy = fwd[v]
        sc = (xs - cax) * dx + (ys - cay) * dy
        k = np.argsort(-sc)[:6]
        res[v] = (int(round(np.mean(xs[k]) - cax)), int(round(np.mean(ys[k]) - cay)))
    print('Defs.BALLISTA "mouth": {%s}' % ', '.join('"%s": Vector2(%d, %d)' % (v, x, y) for v, (x, y) in res.items()))


def bolt():
    a = np.array(Image.open(CONCEPT).convert('RGB')).astype(int)
    x0, y0, x1, y1 = BOLT_BOX
    sub = a[y0:y1, x0:x1]
    fg, _ = keyed(sub)
    # the speed lines are thin and faint: the bolt is the biggest piece (fins, collar, screw)
    lab, n = ndi.label(ndi.binary_dilation(fg, iterations=1))
    sizes = ndi.sum(fg, lab, range(1, n + 1))
    big = int(np.argmax(sizes)) + 1
    m = fg & (lab == big)
    ys, xs = np.nonzero(m)
    sl = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
    o = np.zeros(m[sl].shape + (4,), np.uint8)
    o[..., :3] = sub[sl]
    o[..., 3] = m[sl] * 255
    o = recolour(o)
    s = BOLT_LEN / o.shape[1]
    g = cw_palette.snap_team(W.shrink(o, s))
    Image.fromarray(g, 'RGBA').save('assets/effects/ballista_bolt.png')
    print('ArtData.EFFECTS: "ballista_bolt": {"frames": 1, "size": Vector2i(%d, %d)},' % (g.shape[1], g.shape[0]))


# ------------------------------------------------------------------ the crew

def winder_cell():
    src = open(W.ART_DATA).read()
    m = re.search(r'"winder": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\((\d+), (\d+)\)', src)
    return (int(m.group(1)), int(m.group(2))), (int(m.group(3)), int(m.group(4)))


def game_walk_h(view, cw):
    st = np.array(Image.open(WDST + 'walk_%s.png' % view).convert('RGBA'))
    ys = np.nonzero(st[:, :cw, 3].any(1))[0]
    return float(ys.max() - ys.min() + 1)


def crew():
    (cw, ch), (ax0, ay0) = winder_cell()
    counts = {}
    shown = {}
    for v in ['e', 'se', 's', 'ne', 'n']:
        a = np.array(Image.open(CREW % v).convert('RGB')).astype(int)
        fg, _ = W.keyed(a)
        nrows = 3 if v == 'e' else 2
        grid = W.figures(fg, nrows, 4)
        rows = {'push': grid[0], 'crank': grid[2 if v == 'e' else 1]}
        s = game_walk_h(v, cw) / float(np.median([W.height(b) for b, _ in rows['crank']]))
        for name, row in rows.items():
            bodies = [b for b, _ in row]
            # the middle of the figure across (its box), held still across the row: the stem's place plus the row's
            # mean offset from it (a push leans: centring on the box keeps the claws and the back foot in the cell)
            st = [W.stem_x(b, v) for b in bodies]
            mids = [(np.nonzero(b.any(0))[0].min() + np.nonzero(b.any(0))[0].max()) / 2.0 for b in bodies]
            off = float(np.mean([m - x for m, x in zip(mids, st)]))
            feet_y = [W.feet(b)[1] for b in bodies]
            fy = float(np.mean(feet_y))
            up = ay0
            frames = []
            for (body, bits), x in zip(row, st):
                m = body | bits
                ys, xs = np.nonzero(m)
                y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
                o = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
                o[..., :3] = a[y0:y1, x0:x1]
                o[..., 3] = m[y0:y1, x0:x1] * 255
                o = W.clockwork_palette(o)
                frames.append((o, x + off - x0, fy - y0))
                up = max(up, int(np.ceil((fy - y0) * s)) + 1)
            H = up + (ch - ay0)
            out = []
            for o, fx, fyy in frames:
                g = W.snap_team(place(o, fx, fyy, cw, H, ax0, up, s))
                wide = np.nonzero(o[..., 3].any(0))[0]
                if (wide.max() - wide.min()) * s > cw - 2:
                    print('  (crew %s %s: %.0f px wide, the cell is %d)' % (name, v, (wide.max() - wide.min()) * s, cw))
                out.append(g)
            Image.fromarray(np.concatenate(out, 1), 'RGBA').save(WDST + '%s_%s.png' % (name, v))
            counts['%s_%s' % (name, v)] = 4
            shown[(name, v)] = (out, up)
        print('crew %s: scale %.3f' % (v, s))
    add_counts(counts)
    return shown, (cw, ch, ax0, ay0)


def add_counts(counts):
    src = open(W.ART_DATA).read()
    i = src.index('"winder": {"cell"')
    j = src.index('"frames": {', i) + len('"frames": {')
    head, tail = src[:j], src[j:]
    end = tail.index('}')
    body = tail[:end]
    for k in counts:
        body = re.sub(r'\n\t\t"%s": \d+,' % re.escape(k), '', body)
    add = ''.join('\n\t\t"%s": %d,' % (k, n) for k, n in sorted(counts.items()))
    open(W.ART_DATA, 'w').write(head + add + body + tail[end:])


# ------------------------------------------------------------------ icons

def icons(rows_src):
    _argv = sys.argv[:]
    import import_round11 as r  # noqa: E402  (it reads its own flags at import)
    import import_round13 as r13  # noqa: E402
    sys.argv = _argv
    navy = np.array([0, 22, 48])
    # the portrait: the loaded SE machine, recoloured like the game's (red bands in the Crown icons' red: unteam keeps it)
    rows = cells(SHEET)
    o = recolour(rows[1][0])
    pad = 14
    h, w = o.shape[:2]
    pic = np.zeros((h + 2 * pad, w + 2 * pad, 4), np.uint8)
    pic[..., :3] = navy + 14
    pic[..., 3] = 255
    al = o[..., 3:4] / 255.0
    pic[pad:pad + h, pad:pad + w, :3] = (o[..., :3] * al + pic[pad:pad + h, pad:pad + w, :3] * (1 - al)).astype(np.uint8)
    r.FIT['ballista'] = (0.6, 0.5)
    r.save_icon(r.framed(r.shrink(r.square(pic[..., :3], 'ballista'), r.INNER)), 'ballista')
    # the CREW button: a Winder at the crank (the e sheet, its crank row's first frame) in the bronze frame
    a = np.array(Image.open(CREW % 'e').convert('RGB')).astype(int)
    fg, _ = W.keyed(a)
    body, bits = W.figures(fg, 3, 4)[2][1]
    m = body | bits
    ys, xs = np.nonzero(m)
    p = 18
    sl = (slice(max(0, ys.min() - p), ys.max() + p), slice(max(0, xs.min() - p), xs.max() + p))
    pic2 = a[sl].astype(np.uint8)
    frame = r13.faction_frame('clockwork')
    r.save_icon(r13.bronze_icon(None, 'ab_crew', frame, pic2), 'clockwork/ab_crew')
    print('icons: ballista.png, clockwork/ab_crew.png')


def preview(path, out, cell, shown, wcell):
    cw, ch, cax, cay = cell
    Z = 2
    rowh = ch
    sheet = Image.new('RGBA', (cw * 3 + 8 * 76, rowh * 5), (74, 110, 52, 255))
    for i, v in enumerate(DIRS):
        for j, st in enumerate(('loaded', 'fired')):
            sheet.alpha_composite(Image.fromarray(out[(v, st)]), (j * cw, i * rowh))
        dth = np.array(Image.open(DST + 'death_%s.png' % v))
        sheet.alpha_composite(Image.fromarray(dth[:, (DEATH - 1) * cw:]), (2 * cw, i * rowh))
        vv = v
        for k, name in enumerate(('push', 'crank')):
            fr, up = shown[(name, vv)]
            for q, f in enumerate(fr):
                sheet.alpha_composite(Image.fromarray(f), (3 * cw + (k * 4 + q) * 76, i * rowh + rowh - f.shape[0]))
    sheet.resize((sheet.width * Z, sheet.height * Z), Image.NEAREST).save(path)


def main():
    out, cell = machine()
    bolt()
    shown, wcell = crew()
    icons(None)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], out, cell, shown, wcell)


if __name__ == '__main__':
    main()
