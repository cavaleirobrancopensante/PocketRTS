"""The Winder CARRYING a building's crate (owner, 2026-10-27: "carry it forward in his hands and drop it on the ground so
the building starts"), from the owner's ChatGPT sheets in art/redraws/winder_carry_<view>_chatgpt.png (navy background,
ONE row of five drawings: four steps of a walk with the crate held in front in both claws, then the set-down).
Writes into assets/units/winder/:
  carry_<view>.png       the four walking frames (played on the walk's clockwork beat, Unit.WINDER_BEAT)
  idle_carry_<view>.png  one frame: the first step, held while he stands with the crate
  setdown_<view>.png     one frame: bent over, the crate on the ground in front of him (Unit work "crate_drop")
and adds their frame counts to the "winder" entry of scripts/art_data.gd (same cell and anchor as his other strips; a strip
whose crate rises above the cell gets extra rows on top, which the game allows: Unit._set_anim keeps the feet).

Uses tools/import_winder_v2.py's keying, figure finding, Clockwork palette and shrink. Size: each view is scaled so the
Winder is as tall as in his walk strip of that view (feet to the top of his head); the back view (N), where the crate's
top and light rise over his head, is scaled by width instead (as wide as his N walk).
Placement: like his walk, the head (stem) still across the four steps and the feet on the anchor on average; the
set-down frame on its own feet.

  python3 tools/import_winder_carry.py [--preview FILE]"""
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_winder_v2 as W  # noqa: E402

SRC = 'art/redraws/winder_carry_%s_chatgpt.png'
DST = 'assets/units/winder/'
DIRS = ['s', 'se', 'e', 'ne', 'n']
N_OVER = 1


def game_walk(view):
    """(height, width) of the Winder's first walk frame in the game (opaque box)."""
    st = np.array(Image.open(DST + 'walk_%s.png' % view).convert('RGBA'))
    cw = 76
    f = st[:, :cw, 3] > 0
    ys, xs = np.nonzero(f)
    return float(ys.max() - ys.min() + 1), float(xs.max() - xs.min() + 1)


def cell():
    src = open(W.ART_DATA).read()
    m = re.search(r'"winder": \{"cell": Vector2i\((\d+), (\d+)\), "anchor": Vector2\((\d+), (\d+)\)', src)
    return (int(m.group(1)), int(m.group(2))), (int(m.group(3)), int(m.group(4)))


def palette(o):
    """The Clockwork palette (tools/import_winder_v2.py) for a carry frame: his blue joints become the player's colour,
    but the crate's red corner plates (and his heart, mostly hidden behind the crate) stay painted, as on the crate the
    game shows on the ground (assets/effects/crate_ground.png has no team colour): their reds are warmed a little first,
    so neither the palette nor the shrink's snap takes them for the team key."""
    o = o.copy()
    r, g, b = (o[..., k].astype(int) for k in range(3))
    red = (o[..., 3] > 0) & (r >= 90) & (g <= r * 0.36) & (b <= r * 0.36)
    o[red, 1] = np.clip(r[red] * 0.37, 0, 255).astype(np.uint8)
    o[red, 2] = np.minimum(b[red], (r[red] * 0.3).astype(int)).astype(np.uint8)
    return W.clockwork_palette(o)


def main():
    preview = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None
    (cw, ch), (ax0, ay0) = cell()
    counts = {}
    shown = []
    for v in DIRS:
        a = np.array(Image.open(SRC % v).convert('RGB')).astype(int)
        fg, _ = W.keyed(a)
        row = W.figures(fg, 1, 5)[0]
        gh, gw = game_walk(v)
        bodies = [b for b, _ in row[:4]]
        if v == 'n':
            # (the crate's top and light rise over his head, about N_OVER px at game size)
            s = (gh + N_OVER) / float(np.median([W.height(b) for b in bodies]))
        else:
            s = gh / float(np.median([W.height(b) for b in bodies]))
        # placement: the walk's rule (head still, feet on the anchor on average); the set-down on its own feet
        st = [W.stem_x(b, v) for b in bodies]
        off = float(np.mean([W.feet(b)[0] - x for b, x in zip(bodies, st)]))
        places = [(x + off, W.feet(b)[1]) for b, x in zip(bodies, st)] + [W.feet(row[4][0])]
        frames = []
        for (body, bits), (px, py) in zip(row, places):
            m = body | bits
            ys, xs = np.nonzero(m)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            o = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
            o[..., :3] = a[y0:y1, x0:x1]
            o[..., 3] = m[y0:y1, x0:x1] * 255
            o = palette(o)
            frames.append((o, px - x0, py - y0))
        # room on top: the highest any frame reaches above the anchor
        up = ay0
        for o, fx, fy in frames:
            ys = np.nonzero(o[..., 3].any(1))[0]
            up = max(up, int(np.ceil((fy - ys.min()) * s)) + 1)
        H = up + (ch - ay0)
        out = []
        for o, fx, fy in frames:
            BW, BH = int(round(cw / s)), int(round(H / s))
            big = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
            big.paste(Image.fromarray(o, 'RGBA'), (int(round(ax0 / s - fx)), int(round(up / s - fy))))
            g = W.snap_team(W.shrink(np.array(big), cw / BW))[:H, :cw]
            canvas = np.zeros((H, cw, 4), np.uint8)
            canvas[:g.shape[0], :g.shape[1]] = g
            out.append(canvas)
        for name, fl in (('carry', out[:4]), ('idle_carry', out[:1]), ('setdown', out[4:5])):
            strip = np.concatenate(fl, 1)
            Image.fromarray(strip, 'RGBA').save(DST + '%s_%s.png' % (name, v))
            counts['%s_%s' % (name, v)] = len(fl)
        shown.append((v, out, up))
        print('%s: scale %.3f, %d px over the cell' % (v, s, up - ay0))
    add_counts(counts)
    if preview:
        write_preview(preview, shown, cw, ch, ay0)


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


def write_preview(path, shown, cw, ch, ay0):
    """Each view: its walk frame 0, the four carry steps and the set-down, 4x, on grass."""
    Z = 4
    rows = []
    for v, out, up in shown:
        walk = np.array(Image.open(DST + 'walk_%s.png' % v).convert('RGBA'))[:, :cw]
        H = max(up, ay0) + (ch - ay0)
        row = Image.new('RGBA', (cw * 6, H), (74, 110, 52, 255))
        w = Image.new('RGBA', (cw, H), (0, 0, 0, 0))
        w.paste(Image.fromarray(walk), (0, H - walk.shape[0]))
        row.alpha_composite(w, (0, 0))
        for k, f in enumerate(out):
            fi = Image.new('RGBA', (cw, H), (0, 0, 0, 0))
            fi.paste(Image.fromarray(f), (0, H - f.shape[0]))
            row.alpha_composite(fi, (cw * (k + 1), 0))
        rows.append(row)
    Wd = max(r.width for r in rows)
    Ht = sum(r.height for r in rows)
    sheet = Image.new('RGBA', (Wd, Ht), (74, 110, 52, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height
    sheet.resize((Wd * Z, Ht * Z), Image.NEAREST).save(path)


if __name__ == '__main__':
    main()
