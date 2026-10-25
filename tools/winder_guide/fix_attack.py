#!/usr/bin/env python3
"""Composition fix of the ChatGPT Winder attack sheet: copy the good two-hole bow into the
claws that lack it and erase the back key where the key is in the hand. Usage: fix_attack.py in.png out.png"""
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
    bow = cut(im, (855, 100, 898, 129))             # the good two-hole bow (south row, frame 3)
    sheet = im.copy()
    def erase(box):
        sheet.paste(Image.new('RGB', (box[2] - box[0], box[3] - box[1]), tuple(NAVY)), (box[0], box[1]))
    def put(cx, cy, flip=False, scale=1.0):
        b = bow.transpose(Image.FLIP_LEFT_RIGHT) if flip else bow
        if scale != 1.0:
            b = b.resize((int(b.width * scale), int(b.height * scale)), Image.NEAREST)
        sheet.paste(b, (cx - b.width // 2, cy - b.height // 2), b)
    erase((864, 646, 893, 694))                       # NE, frame 3: no key on the back (it is in the hand)
    put(936, 488)                                     # E, frame 3: the bow in the claw
    put(884, 312)                                     # SE, frame 3
    put(951, 650)                                     # NE, frame 3
    put(926, 846)                                     # N, frame 3
    sheet.save(out)

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
