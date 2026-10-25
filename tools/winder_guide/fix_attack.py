#!/usr/bin/env python3
"""Composition fix of the ChatGPT Winder attack sheet: the chunky two-hole key bow of the back key
(frames 1 and 4) is copied into every place the key is in the hand (frames 2 and 3), turned square
to the shank; the back key is erased where it is in the hand. Usage: fix_attack.py in.png out.png"""
import sys
from PIL import Image
import numpy as np
NAVY = np.array([0, 22, 48])

def cut(im, box):
    c = im.crop(box).convert('RGBA'); a = np.array(c).astype(int)
    alpha = (np.abs(a[:, :, :3] - NAVY).sum(axis=2) > 70).astype(np.uint8) * 255
    c.putalpha(Image.fromarray(alpha)); return c

def main(src, out):
    im = Image.open(src).convert('RGB')
    bow = cut(im, (1164, 448, 1196, 505))           # the chunky bow of the back key (east row, frame 4)
    sheet = im.copy()
    def erase(box):
        sheet.paste(Image.new('RGB', (box[2] - box[0], box[3] - box[1]), tuple(NAVY)), (box[0], box[1]))
    def put(cx, cy, angle, scale=0.9):
        b = bow.resize((int(bow.width * scale), int(bow.height * scale)), Image.NEAREST)
        b = b.rotate(angle, resample=Image.NEAREST, expand=True)
        sheet.paste(b, (cx - b.width // 2, cy - b.height // 2), b)
    erase((864, 646, 893, 694))                       # NE, frame 3: no key on the back (it is in the hand)
    erase((856, 99, 899, 130))                        # S, frame 3: the thin bow
    # frame 2: the key held high, the shank pointing down: the bow lies across it
    for cx, cy in ((571, 28), (585, 234), (583, 410), (593, 594), (590, 785)):
        put(cx, cy, 90)
    # frame 3: the shank leads, the bow is square to it
    put(876, 114, -45)      # S: shank toward the viewer, down and right
    put(884, 312, -45)      # SE
    put(936, 488, 0)        # E
    put(951, 650, 45)       # NE
    put(926, 846, 90)       # N
    sheet.save(out)

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
