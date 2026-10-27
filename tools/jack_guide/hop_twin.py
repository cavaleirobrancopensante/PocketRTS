"""Jack HOP and JUMP with TWO launchers, built in code from ChatGPT's painted two-launcher idle (art/redraws/
jack_idle_twin_chatgpt.png, frame 1 of the rows S SE E NE N), exactly as tools/jack_guide/hop.py and jump.py built them from
the first, clawed idle: the coil spring between the body and the foot plate is squashed or stretched row by row, the body
and both arms ride on top, and in the air the whole unit lifts (the jump leaves a dark ground ellipse, which the importer
drops; the jump sheet is drawn on the ground: see main()). The same frame sequences as hop.py and jump.py, so the timing and the lift the game plays do not change; only the
arms do: no claw any more (docs/animation_audit_clockwork.md, finding 1).

Why in code and not a ChatGPT repaint: ChatGPT's repaint of the hop (2026-10-27) turned 4 of the 6 up-right frames to face
down-right and let the foot plate drift up to 9 px; the spring is the only thing that moves, and code moves it exactly.

Out: art/redraws/jack_hop_twin.png (5 rows x 6, the 256 x 204.8 grid of jack_hop.png) and jack_jump_twin.png (5 x 8, 192 x
204.8, like jack_jump.png), each with a .gif for review. tools/import_jack.py reads them.
  python3 tools/jack_guide/hop_twin.py"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
import attack_twin            # (its figures(): frame 1 of each facing in the two-launcher idle, RGBA, padded)
import import_jack            # (coil(): the spring's steel)

NAVY = np.array([0, 22, 48])
# per frame: the spring's height factor and the lift in sheet px (hop.py's and jump.py's SEQ)
HOP = [(1.0, 0), (0.72, 0), (1.25, 7), (1.12, 14), (1.0, 8), (0.78, 0)]
JUMP = [(1.0, 0), (0.7, 0), (0.45, 0), (1.35, 10), (1.2, 34), (1.05, 22), (0.55, 0), (0.85, 0)]
PAD = 120


def spring(o):
    """(st, bt, sx0, sx1): the spring's top row, the foot plate's top row and the spring's columns, in the crop."""
    cm = import_jack.coil(o)        # (the biggest patch of the spring's steel: the coil alone, not the drill tips)
    ys, xs = np.nonzero(cm)
    # all of its columns: the painted coil's bright highlights are not steel-coloured, so counting steel pixels per column
    # would keep only the middle of the spring and leave its sides riding on the body
    return int(ys.min()), int(ys.max()) + 1, int(xs.min()) - 1, int(xs.max()) + 2


def plate_mask(o, st, bt, sx0, sx1):
    """The foot plate: everything under the coil's lowest row, and beside the spring the plate's back rim, which rises
    above that row (the coil stands in the middle of the oval plate): in each column of the plate's width, the opaque run
    up from that column's lowest pixel. It stays on the ground (or lifts whole); it must not ride down with the body."""
    from scipy import ndimage as ndi
    M = o[..., 3] > 0
    plate = np.zeros_like(M)
    plate[bt:] = M[bt:]
    # beside the spring (rows from the coil's top down): the piece joined to the plate's bottom, gaps of a pixel or two
    # in the painting's outline bridged (the arms hang well clear of it)
    side = M.copy()
    side[:st] = False
    side[:, sx0:sx1] = False
    side[bt:] = M[bt:]
    lab, n = ndi.label(ndi.binary_dilation(side, iterations=2))
    ys = np.nonzero(M.any(1))[0]
    keep = set(int(v) for v in np.unique(lab[ys.max()][M[ys.max()]]) if v)
    if keep:
        plate |= side & np.isin(lab, list(keep))
    # behind the coil the rim runs on: its brass pixels in the spring's columns, below the rim's top beside the spring
    tops = [np.nonzero(plate[:, x])[0].min() for x in (sx0 - 1, sx1) if 0 <= x < M.shape[1] and plate[:, x].any()]
    if tops:
        rgb = o[..., :3].astype(int)
        brass = M & (rgb[..., 0] > 110) & (rgb[..., 0] > rgb[..., 2] + 40)
        y0 = min(tops)
        plate[y0:bt, sx0:sx1] |= brass[y0:bt, sx0:sx1]
    return plate


def frame(o, k, lift, shadow):
    """One frame on a navy canvas PAD larger all round: the spring band resampled to k times its height, the body on it."""
    F = o[..., :3].astype(int)
    M = o[..., 3] > 0
    st, bt, sx0, sx1 = spring(o)
    P = plate_mask(o, st, bt, sx0, sx1)
    h, w = M.shape
    L = bt - st
    nL = max(3, int(round(L * k)))
    out = np.zeros((h + 2 * PAD, w + 2 * PAD, 3), int)
    out[:] = NAVY
    if lift > 0 and shadow:
        sh = Image.new('L', (out.shape[1], out.shape[0]), 0)
        d = ImageDraw.Draw(sh)
        cx = PAD + (sx0 + sx1) / 2
        cy = PAD + h - 6
        rx = (sx1 - sx0) * 0.7 * (1 - lift / 120)
        ry = rx * 0.35
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
        s = np.array(sh) > 0
        out[s] = (out[s] * 0.35 + np.array([0, 8, 20]) * 0.65).astype(int)
    up = -lift
    for t in range(nL):                         # the spring band, resampled to nL rows ending on the plate
        sy = st + int(t * L / nL)
        ty = PAD + bt - nL + t + up
        row = M[sy, sx0:sx1] & ~P[sy, sx0:sx1]
        out[ty, PAD + sx0:PAD + sx1][row] = F[sy, sx0:sx1][row]
    shift = -(nL - L) + up                      # the body (and the band's pixels beside the spring) rides on top
    for y in range(0, bt):
        row = M[y] & ~P[y]
        if y >= st:
            row[sx0:sx1] = False
        ty = PAD + y + shift
        if 0 <= ty < out.shape[0]:
            out[ty, PAD:PAD + w][row] = F[y][row]
    for y in range(h):                          # the foot plate last (in front of the coil's foot): lifted in the air
        row = P[y]
        if row.any():
            out[PAD + y + up, PAD:PAD + w][row] = F[y][row]
    return out


def sheet(figs, seq, name, durations, shadow):
    cols = len(seq)
    CW, CH = 1536 / cols, 1024 / 5
    sh = Image.new('RGB', (1536, 1024), tuple(NAVY))
    for r, o in enumerate(figs):
        st, bt, sx0, sx1 = spring(o)
        h, w = o.shape[:2]
        cx = PAD + (sx0 + sx1) // 2             # the spring's middle on the cell's middle
        gy = PAD + h                            # the crop's bottom (the plate's rim) 8 px above the cell's bottom
        for c, (k, lift) in enumerate(seq):
            f = Image.fromarray(frame(o, k, lift, shadow).astype(np.uint8))
            x0 = int(round(c * CW))
            y0 = int(round(r * CH))
            cw, ch = int(round((c + 1) * CW)) - x0, int(round((r + 1) * CH)) - y0
            cell = f.crop((cx - cw // 2, gy - ch + 8, cx - cw // 2 + cw, gy + 8))
            sh.paste(cell, (x0, y0))
    sh.save('art/redraws/%s.png' % name)
    g = []
    for c in range(cols):
        o = Image.new('RGB', (int(5 * CW), int(CH)))
        for r in range(5):
            o.paste(sh.crop((int(c * CW), int(r * CH), int((c + 1) * CW), int((r + 1) * CH))), (int(r * CW), 0))
        g.append(o)
    g[0].save('art/redraws/%s.gif' % name, save_all=True, append_images=g[1:], duration=durations, loop=0)
    print('wrote art/redraws/%s.png' % name)


def main():
    figs = attack_twin.figures()
    sheet(figs, HOP, 'jack_hop_twin', [90, 80, 70, 80, 80, 90], False)
    # the jump's lift is left out of the sheet: tools/import_jack.py puts every jump frame on its own foot plate (the game
    # flies the unit along its arc over its own ground shadow), and the two-launcher Jack is too tall to lift 34 px in a cell
    sheet(figs, [(k, 0) for k, lift in JUMP], 'jack_jump_twin', [200, 90, 140, 60, 90, 90, 70, 140], False)


if __name__ == '__main__':
    main()
