"""THE GREAT WINDER (gear mode's Clockwork tier 2; the owner's unit, 2026-10-26/27; docs/great_winder.md).

Its art is made by tools/great_winder_guide/anim.py (docs/great_winder_legs.md, docs/cw_anim_parts.md "Great Winder"):
the body and its parts cut from art/redraws/great_winder_dirs.png, standing on ChatGPT's painted leg, in three strips
(WALK 12 frames with 4 legs, WIND 12, SWEEP 8) on one cell. anim.py writes them at game size on navy for the owner to look
at; this importer builds the same frames from anim.py's own layers at SHEET size, so the Clockwork palette
(tools/cw_palette.py: brass + player colour, no blue) is applied before the shrink, as for every other Clockwork unit.

Writes (the five views s se e ne n; the west views mirror the east ones in the game):
  assets/units/great_winder/walk_<v>.png    12 frames, 4 legs (anim.py's LEGS)
  assets/units/great_winder/wind_<v>.png    8 frames: anim.py's WIND frames 2-9, the key out and turning (they loop
                                            while it mends; the arm sliding out and back in is left out)
  assets/units/great_winder/sweep_<v>.png   8 frames: the rollers turning
  assets/units/great_winder/idle_<v>.png    2 frames, MADE HERE: the machine standing, then its body dipped 1 game px
                                            on its planted legs (a slow breath; docs/art_style_inconsistency.md)
  assets/units/great_winder/death_<v>.png   5 frames, MADE HERE from the standing frame: it sags onto its legs, tips a
                                            little and goes dark (docs/art_style_inconsistency.md)
  assets/icons/clockwork/ab_mend.png        the MEND button: ChatGPT's painted key (great_winder_key_rollers_chatgpt.png)
  assets/icons/clockwork/ab_sweep.png       the SWEEP button: ChatGPT's painted brush roller (the same sheet)
and prints the scripts/cw_art.gd SHEETS line. The portrait (assets/icons/great_winder.png) is round 13's: not touched.
  python3 tools/import_great_winder.py"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'great_winder_guide'))
os.chdir(os.path.join(HERE, '..'))
import cw_palette  # noqa: E402
import anim as A  # noqa: E402  (tools/great_winder_guide/anim.py: builds its parts on import)

DST = 'assets/units/great_winder/'
KEYS = 'art/redraws/great_winder_key_rollers_chatgpt.png'
WIND_LOOP = range(2, 10)      # anim.py's WIND: out in frames 0-1, the key turning in 2-9, back in 10-11
DEATH = 5


def cell():
    """the cell anim.py's main() puts all three strips on (both walks counted, so it is the same cell)"""
    frames = {(name, r): A.anim_frames(name, r) for name in ('walk', 'wind', 'sweep') for r in range(5)}
    keep = A.LEGS
    A.LEGS = 6 if keep == 4 else 4
    frames.update({('walk2', r): A.anim_frames('walk', r) for r in range(5)})
    A.LEGS = keep
    L, Rr, U, D = A.extents(frames)
    half = int(math.ceil(max(L, Rr) * A.GS)) + 1
    up, down = int(math.ceil(U * A.GS)) + 1, int(math.ceil(D * A.GS)) + 1
    return (2 * half, up + down, half, up)


def compose(r, groups, cl):
    """anim.py's to_cell, but the layers are laid together at sheet size first, recoloured, then shrunk once"""
    CW, CH, AX, AY = cl
    ax, ay = A.anchor(r)
    ox, oy = int(round(ax - AX / A.GS)), int(round(ay - AY / A.GS))
    w, h = int(round(CW / A.GS)), int(round(CH / A.GS))
    crop = np.zeros((h, w, 4), np.uint8)
    for img, gx, gy, _rides in groups:
        lay = np.zeros((h, w, 4), np.uint8)
        A._paste(lay, img, gx - ox, gy - oy)
        A.over(crop, lay)
    out = cw_palette.recolour(crop, 'great_winder')
    return cw_palette.snap_team(A.shrink(out, CW, CH))


def idle_groups(r, bob):
    """standing on all its legs, arm stowed, the body dipped `bob` game px (the legs take it, as in SWEEP)"""
    b = A.bob_px(bob)
    L = A.legs_layers(r, 0.0, b, stand=True)
    g = [(x, False) for x in L['far'] + L['back']] + [(A.body_layer(A.PARTS[r]['body'], b), False)] + \
        [(x, False) for x in L['near']]
    return A.cropped(g)


def death_frame(f, k, cay):
    """made here: the standing machine sags onto its folding legs (squashed toward the ground), tips a little forward
    and goes dark, frame by frame; the last is the still wreck the sweepers of its own side will come for"""
    if k == 0:
        return f.copy()
    t = k / float(DEATH - 1)
    im = Image.fromarray(f, 'RGBA')
    W, H = im.size
    sy = 1.0 - 0.34 * t
    top = int(round(cay * (1 - sy)))
    sq = im.crop((0, 0, W, cay)).resize((W, max(1, cay - top)), Image.NEAREST)
    cv = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cv.paste(sq, (0, top))
    cv = cv.rotate(-4.0 * t, resample=Image.NEAREST, center=(W / 2.0, cay))
    rgb = ImageEnhance.Brightness(cv.convert('RGB')).enhance(1.0 - 0.5 * t)
    o = np.array(rgb.convert('RGBA'))
    o[..., 3] = np.array(cv)[..., 3]
    o[o[..., 3] == 0] = 0
    return o


def strips():
    cl = cell()
    CW, CH, AX, AY = cl
    os.makedirs(DST, exist_ok=True)
    for r, v in enumerate(A.DIRS):
        walk = [compose(r, g, cl) for g, _b in A.anim_frames('walk', r)]
        wind_all = A.anim_frames('wind', r)
        wind = [compose(r, wind_all[i][0], cl) for i in WIND_LOOP]
        sweep = [compose(r, g, cl) for g, _b in A.anim_frames('sweep', r)]
        idle = [compose(r, idle_groups(r, 0), cl), compose(r, idle_groups(r, 1), cl)]
        death = [death_frame(idle[0], k, AY) for k in range(DEATH)]
        for name, fr in (('walk', walk), ('wind', wind), ('sweep', sweep), ('idle', idle), ('death', death)):
            Image.fromarray(np.concatenate(fr, 1), 'RGBA').save(DST + '%s_%s.png' % (name, v))
        print(v, 'walk %d wind %d sweep %d idle %d death %d' % (len(walk), len(wind), len(sweep), len(idle), len(death)))
    print('cw_art.gd SHEETS: "great_winder": [%d, %d, %d, %d],' % cl)
    return cl


def buttons():
    """MEND (the key) and SWEEP (a brush roller), cut from ChatGPT's painted parts, in the Clockwork's bronze frame"""
    _argv = sys.argv[:]
    sys.argv = sys.argv[:1]
    import import_round11 as r  # noqa: E402  (it reads its own flags at import)
    import import_round13 as r13  # noqa: E402
    sys.argv = _argv
    a = np.array(Image.open(KEYS).convert('RGB'))
    frame = r13.faction_frame('clockwork')
    # (sheet px of the 1024 x 1536 sheet: the first key, face-on; the first roller, side-on)
    for name, (x0, y0, x1, y1) in (('ab_mend', (110, 10, 250, 190)), ('ab_sweep', (60, 890, 270, 1000))):
        pic = a[y0:y1, x0:x1].copy()
        h, w = pic.shape[:2]
        s = max(h, w)
        sq = np.zeros((s, s, 3), np.uint8)
        sq[:] = pic[2, 2]
        sq[(s - h) // 2:(s - h) // 2 + h, (s - w) // 2:(s - w) // 2 + w] = pic
        r.save_icon(r13.bronze_icon(None, name, frame, sq), 'clockwork/' + name)
        print('icons: clockwork/%s.png' % name)


if __name__ == '__main__':
    strips()
    buttons()
