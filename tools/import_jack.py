"""Import the Jack's sheets (art/redraws/jack_*.png, navy background RGB 0,22,48, rows = directions S SE E NE N; the west
views are the east ones mirrored in the game) into the game's unit strips:
  assets/units/jack/{idle,walk,jump,attack,death}_{s,se,e,ne,n}.png (frames side by side, one canvas for all)
the card portrait assets/icons/jack.png, and prints the scripts/cw_art.gd SHEETS line and the drill tips for
Defs.JACK "tips".

  idle    jack_idle.png         ChatGPT, 6 rows (the 6th repeats the back view: unused) x 4; not on an exact grid, so the
                                figures are found as connected components (the thin dark shadow strips under them and
                                other dark specks are dropped)
  walk    jack_hop.png          the HOP (made in code: tools/jack_guide/hop.py), 5 x 6 on a 256 px grid with consistent
                                positions: every frame of a row keeps its place in the cell, so the foot plate stays put
                                except when it lifts with the hop
  jump    jack_jump.png         5 x 8 (192 px grid): crouch 1-3, launch 4, in the air 5-6, landing 7-8. Every frame is put
                                on its own foot plate: the sheet's lift (and its dark ground ellipse) is dropped, the game
                                flies the unit along its arc over its own ground shadow
  attack  jack_attack_body.png  5 x 6 (256 px grid): the recoil without the burst. The frames are the rest pose shifted
                                along the barrel; here the foot plate stays still and only the body above it kicks back
  attack_up jack_attack_up_body.png  5 x 6, laid out like the attack sheet (tools/jack_guide/attack_up.py): the launcher
                                arm RAISED at a flyer, the same recoil along the raised barrel; the drill tip on its fire
                                frame (the 2nd) comes from art/redraws/jack_attack_up_tips.json
  death   jack_death_final.png  5 x 7 (~219.4 px cells): every frame on its spring's foot (the base plate stays put while
                                the body is flung off); the last frame is the corpse

Per frame: key out the navy (tolerance 40), keep the figure (its big pieces and its bright small ones: the winding key,
gears and screws flying off), the Clockwork palette (tools/cw_palette.py), shrink to game size (the S idle as tall as the
Clock Soldier's S idle), snap the team reds to the shader's key reds.

PALETTE (owner, 2026-10-26; the rule for every Clockwork unit is in tools/cw_palette.py): BRASS + PLAYER COLOUR. The
Jack's red body stays player colour and its two blue ball SHOULDERS become player colour; its steel stays steel: the coil
spring, the inner arm segments and the drill tips (cw_palette.blue_parts, the Jack's rule: only the deep-blue balls fixed
to the red body are paint), greyed toward steel where a sheet paints them bluer than the older ones (the two-launcher
sheet's drill tips).
  python3 tools/import_jack.py"""
import json
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cw_palette

SRC = 'art/redraws/'
DST = 'assets/units/jack/'
DIRS = ['s', 'se', 'e', 'ne', 'n']
NAVY = np.array([0, 22, 48])
TOL = 40
SOLDIER_S_H = 59        # px: the Clock Soldier's S idle in game (assets/units/clock_soldier/idle_s.png)
# anim: (file, rows in the sheet, columns, how the frames are found, how they are aligned)
SHEETS = {
    'idle': ('jack_idle.png', 6, 4, 'foot'),
    'walk': ('jack_hop.png', 5, 6, 'row'),
    'jump': ('jack_jump.png', 5, 8, 'foot'),
    'attack': ('jack_attack_body.png', 5, 6, 'recoil'),
    'attack_up': ('jack_attack_up_body.png', 5, 6, 'recoil'),
    'death': ('jack_death_final.png', 5, 7, 'foot'),
}
UP_TIPS = 'art/redraws/jack_attack_up_tips.json'     # the raised drill tip on the fire frame, cell px (+ barrel direction)
# the drill tip on the painted idle frame (tools/jack_guide/attack.py: TIP in the BOX crop, the crop pasted in a 256 x 204
# cell at ((256 - w) // 2, 204 - h - 10))
IDLE_BOX = [(159, 23, 306, 181), (174, 216, 299, 360), (170, 387, 301, 537), (166, 571, 308, 713), (164, 743, 308, 873)]
TIP = [(5, 115), (4, 116), (131, 92), (140, 92), (141, 90)]
SHOT_FRAME = 1          # the attack frame the screw leaves on (the strongest kick)


def keyed(rgb):
    return np.abs(rgb - NAVY).sum(2) >= TOL


def figures(path, rows, cols):
    """{(row, col): (rgba crop, (x0, y0) of the crop in the sheet, (cx0, cy0) of its cell)}: every piece of the keyed mask
    goes to the cell its centre falls in. Kept: pieces of 200 px or more, and smaller ones that are bright (the winding key,
    gears, screws), not the dark specks and shadow strips."""
    rgb = np.array(Image.open(path).convert('RGB')).astype(int)
    H, W = rgb.shape[:2]
    m = keyed(rgb)
    lab, n = ndi.label(m)
    sizes = ndi.sum(m, lab, range(1, n + 1))
    cells = {}
    for i, sl in enumerate(ndi.find_objects(lab)):
        part = lab[sl] == i + 1
        sz = int(sizes[i])
        if sz < 200:
            bright = rgb[sl][part].sum(1).mean()
            if sz < 20 or bright < 90:
                continue
        ys, xs = np.nonzero(part)
        cy, cx = ys.mean() + sl[0].start, xs.mean() + sl[1].start
        r = min(rows - 1, int(cy / (H / rows)))
        c = min(cols - 1, int(cx / (W / cols)))
        cells.setdefault((r, c), []).append((sl, part))
    out = {}
    for (r, c), parts in cells.items():
        y0 = min(sl[0].start for sl, p in parts)
        y1 = max(sl[0].stop for sl, p in parts)
        x0 = min(sl[1].start for sl, p in parts)
        x1 = max(sl[1].stop for sl, p in parts)
        mm = np.zeros((y1 - y0, x1 - x0), bool)
        for sl, p in parts:
            mm[sl[0].start - y0:sl[0].stop - y0, sl[1].start - x0:sl[1].stop - x0] |= p
        sub = rgb[y0:y1, x0:x1]
        # holes inside the figure that are not the navy itself stay solid (dark glass, shadowed coils)
        mm = (ndi.binary_fill_holes(mm) & (np.abs(sub - NAVY).sum(2) >= 12)) | mm
        o = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        o[..., :3] = sub
        o[..., 3] = mm * 255
        out[(r, c)] = (o, (x0, y0), (c * W / cols, r * H / rows))
    return out


def coil(o):
    """The coil spring: the biggest patch of its blue-grey steel. Returns its mask (or None)."""
    r, g, b, a = [o[..., i].astype(int) for i in range(4)]
    m = (a > 0) & (b > r + 25) & (b > 110) & (g > 90) & (np.abs(r - g) < 45)
    if m.sum() < 20:
        return None
    lab, n = ndi.label(ndi.binary_dilation(m, iterations=2))
    sz = ndi.sum(m, lab, range(1, n + 1))
    return (lab == int(np.argmax(sz)) + 1) & m


def foot(o):
    """The anchor of a frame in its crop: x = the middle of the coil's lowest rows (the spring stands in the middle of the
    foot plate), y = the bottom of the foot plate (the lowest opaque pixel within 20 px of that x, the plate's rim)."""
    al = o[..., 3] > 0
    cm = coil(o)
    if cm is None:
        ys, xs = np.nonzero(al)
        return (xs.min() + xs.max() + 1) * 0.5, float(ys.max() + 1)
    ys, xs = np.nonzero(cm)
    fx = float(xs[ys >= ys.max() - 6].mean())
    band = al[:, max(0, int(fx) - 20):int(fx) + 21]
    rows = np.nonzero(band.any(1))[0]
    rows = rows[rows >= ys.max() - 4]          # (below the coil's bottom: the plate)
    fy = float(rows.max() + 1) if len(rows) else float(ys.max() + 1)
    return fx + 0.5, fy


def plate_top(o, fy):
    """The row where the foot plate begins: just under the coil's lowest row."""
    cm = coil(o)
    if cm is None:
        return int(fy) - 8
    return int(np.nonzero(cm.any(1))[0].max()) + 1


def shrink(img, scale):
    """Box-filter downscale with premultiplied alpha, then hard alpha (tools/import_clock_soldier.py)."""
    h, w = img.shape[:2]
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    a = img[..., 3:4].astype(np.float32) / 255.0
    pre = np.concatenate([img[..., :3] * a, a * 255.0], -1).clip(0, 255).astype(np.uint8)
    s = np.array(Image.fromarray(pre).resize((nw, nh), Image.BOX)).astype(np.float32)
    al = s[..., 3:4] / 255.0
    rgb = np.where(al > 0.01, s[..., :3] / np.maximum(al, 0.01), 0)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = rgb.clip(0, 255)
    out[..., 3] = np.where(al[..., 0] >= 0.45, 255, 0)
    out[out[..., 3] == 0] = 0
    return out


def main():
    frames = {}       # (anim, dir) -> [(rgba, ax, ay)]
    recoil = {}       # (anim, dir) -> (dx, dy) sheet px of the body kick on the shot frame
    attack0 = {}      # (anim, dir) -> (foot in sheet coords) of the first attack frame
    shot_foot = {}    # (anim, dir) -> the shot frame's own foot in sheet coords (before the plate is put back)
    for anim, (f, rows, cols, how) in SHEETS.items():
        figs = figures(SRC + f, rows, cols)
        for row, d in enumerate(DIRS):
            row_figs = [figs[(row, c)] for c in range(cols) if (row, c) in figs]
            out = []
            first = None
            for i, (o, (x0, y0), (cx0, cy0)) in enumerate(row_figs):
                fx, fy = foot(o)
                if how == 'row':
                    # one anchor for the row: the first frame's foot, in cell coordinates (the hop lifts the plate)
                    if first is None:
                        first = (x0 - cx0 + fx, y0 - cy0 + fy)
                    fx, fy = first[0] - (x0 - cx0), first[1] - (y0 - cy0)
                elif how == 'recoil':
                    # the plate stays on the anchor; the rows above it keep their kick against the first frame
                    sx, sy = x0 - cx0 + fx, y0 - cy0 + fy
                    if first is None:
                        first = (sx, sy, x0 - cx0, y0 - cy0)
                        attack0[(anim, d)] = (x0 + fx, y0 + fy)
                    if i == SHOT_FRAME:
                        shot_foot[(anim, d)] = (x0 + fx, y0 + fy)
                    kx, ky = int(round((x0 - cx0) - first[2])), int(round((y0 - cy0) - first[3]))
                    if kx or ky:
                        pt = plate_top(o, fy)
                        body = o.copy()
                        body[pt:] = 0
                        base = o.copy()
                        base[:pt] = 0
                        # the plate back where the first frame had it (it was shifted with the whole sprite)
                        pad = 6
                        big = np.zeros((o.shape[0] + 2 * pad, o.shape[1] + 2 * pad, 4), np.uint8)
                        bm = base[..., 3] > 0
                        big[pad - ky:pad - ky + o.shape[0], pad - kx:pad - kx + o.shape[1]][bm] = base[bm]
                        m = body[..., 3] > 0
                        big[pad:pad + o.shape[0], pad:pad + o.shape[1]][m] = body[m]
                        o = big
                        fx, fy = fx - kx + pad, fy - ky + pad
                        if i == SHOT_FRAME:
                            recoil[(anim, d)] = (kx, ky)
                out.append((o, fx, fy))
            if anim == 'idle':
                out = out[:4]
            frames[(anim, d)] = out
    # the scale: the S idle as tall as the Clock Soldier's
    hs = []
    for o, ax, ay in frames[('idle', 's')]:
        ys = np.nonzero((o[..., 3] > 0).any(1))[0]
        hs.append(ys.max() - ys.min() + 1)
    scale = SOLDIER_S_H / float(np.median(hs))
    # one canvas: the farthest any frame reaches from its anchor
    L = R = U = D = 0.0
    for fl in frames.values():
        for o, ax, ay in fl:
            ys, xs = np.nonzero(o[..., 3] > 0)
            L = max(L, ax - xs.min())
            R = max(R, xs.max() + 1 - ax)
            U = max(U, ay - ys.min())
            D = max(D, ys.max() + 1 - ay)
    half = int(np.ceil(max(L, R) * scale)) + 1
    cw = half * 2
    up = int(np.ceil(U * scale)) + 1
    down = int(np.ceil(D * scale)) + 1
    ch = up + down
    os.makedirs(DST, exist_ok=True)
    BW, BH = int(round(cw / scale)), int(round(ch / scale))
    for (anim, d), fl in frames.items():
        strip = np.zeros((ch, cw * len(fl), 4), np.uint8)
        for i, (o, ax, ay) in enumerate(fl):
            # the source on a canvas cw/scale x ch/scale with its anchor at (half, up)/scale, then shrunk to cw x ch
            o = cw_palette.recolour(o, 'jack')      # (after the anchors: they look for the coil spring)
            big = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
            big.paste(Image.fromarray(o, 'RGBA'), (int(round(half / scale - ax)), int(round(up / scale - ay))))
            s = shrink(np.array(big), cw / BW)[:ch, :cw]
            s = cw_palette.snap_team(s)
            strip[:s.shape[0], i * cw:i * cw + s.shape[1]] = s
        Image.fromarray(strip, 'RGBA').save(DST + '%s_%s.png' % (anim, d))
    print('jack: scale %.3f, cell %dx%d, anchor (%d, %d)' % (scale, cw, ch, half, up))
    print('SHEETS line: "jack": [%d, %d, %d, %d],' % (cw, ch, half, up))
    print('frames:', {a: len(frames[(a, 's')]) for a in SHEETS})
    # the drill tip per drawn direction on the shot frame, game px from the anchor (the feet)
    tips = {}
    for row, d in enumerate(DIRS):
        bx0, by0, bx1, by1 = IDLE_BOX[row]
        w, h = bx1 - bx0, by1 - by0
        tx = 0 * 256 + (256 - w) // 2 + TIP[row][0]
        ty = row * 204 + 204 - h - 10 + TIP[row][1]
        fx, fy = attack0[('attack', d)]
        kx, ky = recoil.get(('attack', d), (0, 0))
        tips[d] = (round((tx - fx + kx) * scale), round((ty - fy + ky) * scale))
    print('tips: {' + ', '.join('"%s": Vector2(%d, %d)' % (d, t[0], t[1]) for d, t in tips.items()) + '}')
    # the RAISED drill tip (shooting at a flyer): the JSON gives it on the fire frame in that frame's cell (the sheet's rows
    # are 204 px apart); in the strip that frame's body keeps its kick over the first frame's foot plate, so the tip is
    # (the tip - the fire frame's own foot) + its kick, from the anchor
    up = json.load(open(UP_TIPS))
    cwu, chu = up['cell']
    tips_up = {}
    for row, d in enumerate(DIRS):
        tx, ty, bx, by = up['tips'][d.upper()]
        tx += SHOT_FRAME * cwu
        ty += row * chu
        fx, fy = shot_foot[('attack_up', d)]
        kx, ky = recoil.get(('attack_up', d), (0, 0))
        tips_up[d] = (round((tx - fx + kx) * scale), round((ty - fy + ky) * scale), bx, by)
    print('tips_up: {' + ', '.join('"%s": Vector2(%d, %d)' % (d, t[0], t[1]) for d, t in tips_up.items()) + '}')
    print('barrel_up: {' + ', '.join('"%s": Vector2(%.3f, %.3f)' % (d, t[2], t[3]) for d, t in tips_up.items()) + '}')
    # the card portrait (64 x 64): the S idle frame's upper body
    s0 = np.array(Image.open(DST + 'idle_s.png'))[:, :cw]
    ys, xs = np.nonzero(s0[..., 3] > 0)
    side = max(xs.max() - xs.min(), int((ys.max() - ys.min()) * 0.8)) + 2
    cx = (xs.min() + xs.max()) // 2
    crop = Image.fromarray(s0).crop((cx - side // 2, ys.min() - 1, cx - side // 2 + side, ys.min() - 1 + side))
    crop.resize((64, 64), Image.NEAREST).save('assets/icons/jack.png')
    # the JUMP button (the E view in the air, spring stretched) and the HIGH LEAP research (the S view at the launch):
    # whole frames, square, 64 x 64
    for name, (anim, d, f) in {'ab_jump': ('jump', 'e', 4), 'research_high_leap': ('jump', 's', 3)}.items():
        s = np.array(Image.open(DST + '%s_%s.png' % (anim, d)))[:, f * cw:(f + 1) * cw]
        ys, xs = np.nonzero(s[..., 3] > 0)
        side = max(xs.max() - xs.min(), ys.max() - ys.min()) + 4
        cx, cy = (xs.min() + xs.max()) // 2, (ys.min() + ys.max()) // 2
        sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
        sq.paste(Image.fromarray(s).crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)), (0, 0))
        sq.resize((64, 64), Image.NEAREST).save('assets/icons/%s.png' % name)


if __name__ == '__main__':
    main()
