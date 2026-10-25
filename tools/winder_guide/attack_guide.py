#!/usr/bin/env python3
"""Pose guide for the Winder attack: the new idle figures with the key drawn in code
(held by the BOW, thrust with the SHANK), laid out like the ChatGPT sheet (5 rows x 4 frames).
ChatGPT redraws it in the real art style. Usage: attack_guide.py out.png"""
import sys, math
from PIL import Image, ImageDraw
SRC = 'art/redraws/winder_idle_v2.png'
NAVY = (0, 22, 48)
BRASS = (222, 160, 48); BRASS_D = (150, 95, 25); OUT = (20, 14, 22); STEEL = (170, 175, 185); STEEL_D = (95, 100, 112)
# crop box of each direction's first idle figure on the idle sheet (found by connected components)
CELLS = {'s': (226, 59, 427, 291), 'se': (233, 359, 421, 578), 'e': (246, 637, 401, 861),
         'ne': (245, 921, 407, 1156), 'n': (225, 1232, 426, 1457)}
ORDER = ['s', 'se', 'e', 'ne', 'n']
# the back key of each figure: a box to erase (cell-local px) when the key is in the hand
KEYBOX = {'s': None, 'se': (0, 0, 70, 75), 'e': (0, 35, 55, 125), 'ne': (0, 30, 55, 135), 'n': None}
# the active (right) arm: shoulder and resting claw (cell-local px)
SHOULDER = {'s': (40, 105), 'se': (50, 98), 'e': (62, 108), 'ne': (60, 108), 'n': (45, 108)}
# thrust direction on screen (dx, dy) and how long the shank looks
FWD = {'s': (0.0, 1.0, 0.45), 'se': (0.75, 0.66, 0.8), 'e': (1.0, 0.0, 1.0), 'ne': (0.75, -0.66, 0.8), 'n': (0.0, -1.0, 0.45)}

def blob(d, p, r, fill, outline=OUT):
    d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=fill, outline=outline, width=3)

def line(d, a, b, w, fill):
    d.line([a, b], fill=OUT, width=w + 6)
    d.line([a, b], fill=fill, width=w)

def key(d, hand, dirv, shank_len, show_tip=True):
    """Bow (the loop) in the hand, shank (the slim stem with a notched tip) pointing along dirv."""
    dx, dy = dirv
    n = math.hypot(dx, dy) or 1
    dx, dy = dx / n, dy / n
    tip = (hand[0] + dx * shank_len, hand[1] + dy * shank_len)
    # shank first (steel), then the bow behind the hand (brass ring with two holes)
    line(d, hand, tip, 8, STEEL)
    px, py = -dy, dx
    nt = (tip[0] + dx * 3, tip[1] + dy * 3)
    d.polygon([(nt[0] + px * 8, nt[1] + py * 8), (nt[0] - px * 8, nt[1] - py * 8),
               (tip[0] - px * 5, tip[1] - py * 5), (tip[0] + px * 5, tip[1] + py * 5)], fill=STEEL_D, outline=OUT)
    bc = (hand[0] - dx * 18, hand[1] - dy * 18)
    blob(d, bc, 20, BRASS)
    for s in (-1, 1):
        blob(d, (bc[0] + px * 8 * s, bc[1] + py * 8 * s), 6, NAVY, OUT)
    return tip

def spark(d, p):
    for k in range(6):
        a = k * math.pi / 3
        d.line([(p[0] + math.cos(a) * 6, p[1] + math.sin(a) * 6), (p[0] + math.cos(a) * 15, p[1] + math.sin(a) * 15)], fill=(255, 230, 90), width=3)

def make_cell(base, dkey, frame):
    cell = base.crop(CELLS[dkey]).convert('RGB')
    w, h = cell.size
    d = ImageDraw.Draw(cell)
    fx, fy, fl = FWD[dkey]
    sh = SHOULDER[dkey]
    if frame in (2, 3) and dkey == 'n':     # the key is off the back: show the back of the clock head under it
        d.ellipse([52, 38, 150, 118], fill=(168, 110, 30), outline=OUT, width=3)
        d.ellipse([70, 54, 132, 100], fill=(190, 128, 36), outline=OUT, width=2)
        d.rectangle([90, 22, 112, 46], fill=(190, 128, 36), outline=OUT, width=2)
    if frame in (2, 3) and KEYBOX[dkey]:
        x0, y0, x1, y1 = KEYBOX[dkey]
        d.rectangle([x0, y0, x1, y1], fill=NAVY)         # the key is off the back
    if frame == 1:     # reaching back over the shoulder, the key still on the back
        hand = (sh[0] - 8 + (10 if dkey in ('e', 'ne', 'se') else 0), sh[1] - 62)
        line(d, sh, hand, 16, (190, 128, 36)); blob(d, hand, 11, STEEL_D)
    elif frame == 2:   # key high over the head, held by the bow, shank pointing forward and down
        hand = (sh[0] - 4, sh[1] - 80)
        line(d, sh, hand, 16, (190, 128, 36)); blob(d, hand, 11, STEEL_D)
        key(d, hand, (fx * 0.8 if (fx or fy) else 0.0, 0.7), 46 * max(fl, 0.6))
    elif frame == 3:   # thrust: arm out along the facing, the shank leading, a spark at its tip
        reach = 62 * fl
        hand = (sh[0] + fx * reach * 0.6, sh[1] - 4 + fy * 38 * (1 if abs(fy) > 0.5 and dkey in ('s',) else 0.3))
        if dkey == 'n':
            hand = (sh[0] + 4, sh[1] - 40)
        if dkey == 's':
            hand = (sh[0] + 40, sh[1] + 38)
        line(d, sh, hand, 16, (190, 128, 36)); blob(d, hand, 11, STEEL_D)
        tip = key(d, hand, (fx, fy if abs(fy) < 0.9 else fy), 54 * max(fl, 0.55))
        spark(d, tip)
    # frame 4: the key is back on the back and the arm down: the plain idle figure
    return cell

def main(out):
    base = Image.open(SRC).convert('RGB')
    W, H = 1536, 1024
    sheet = Image.new('RGB', (W, H), NAVY)
    colx = [250, 560, 850, 1150]
    rowy = [10, 205, 405, 605, 800]
    for r, dk in enumerate(ORDER):
        for f in range(1, 5):
            c = make_cell(base, dk, f)
            c = c.resize((int(c.width * 0.82), int(c.height * 0.82)), Image.LANCZOS)
            sheet.paste(c, (colx[f - 1], rowy[r]))
    sheet.save(out)

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '/tmp/attack_guide.png')
