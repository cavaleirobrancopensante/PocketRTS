"""The Clock Soldier in all eight directions side by side (S SE E NE N NW W SW), from the game's own strips
(assets/units/clock_soldier/<anim>_<dir>.png; the west views are its own sw/w/nw strips, not the east ones mirrored),
one GIF per animation, 3x, on the navy of the source sheets:
  art/redraws/clock_soldier_8dir_{idle,walk,attack,death}.gif
  python3 tools/clock_soldier_8dir_gif.py"""
import os
import numpy as np
from PIL import Image, ImageDraw

SRC = 'assets/units/clock_soldier/'
DIRS = ['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw']
ANIMS = {'idle': [500, 500, 500, 500], 'walk': [140] * 6, 'attack': [110, 110, 160, 90, 110, 140],
         'death': [150, 100, 90, 80, 120, 120, 900]}
CELL_W = 78           # scripts/cw_art.gd SHEETS["clock_soldier"][0]
K = 3
NAVY = (0, 22, 48)
TEAM = (60, 110, 230)  # the key reds shown in a team colour (blue), as the game's shader would


def strip(anim, d):
    a = np.array(Image.open(SRC + '%s_%s.png' % (anim, d)).convert('RGBA'))
    # the shader's key reds (light r >= 175, dark) -> a blue team, so the cap reads as the team colour
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    key = (a[..., 3] > 0) & (g < 30) & (b < 30) & (r >= 60)
    f = (r[key] / 255.0)[:, None]
    a[key, :3] = (np.array(TEAM)[None, :] * f * 1.2).clip(0, 255).astype(np.uint8)
    n = a.shape[1] // CELL_W
    return [Image.fromarray(a[:, i * CELL_W:(i + 1) * CELL_W]) for i in range(n)]


def main():
    for anim, dur in ANIMS.items():
        rows = {d: strip(anim, d) for d in DIRS}
        n = max(len(v) for v in rows.values())
        ch = rows['s'][0].height
        frames = []
        for i in range(n):
            o = Image.new('RGB', (CELL_W * K * len(DIRS), ch * K + 14), NAVY)
            dr = ImageDraw.Draw(o)
            for j, d in enumerate(DIRS):
                fr = rows[d][min(i, len(rows[d]) - 1)].resize((CELL_W * K, ch * K), Image.NEAREST)
                o.paste(fr, (j * CELL_W * K, 0), fr)
                dr.text((j * CELL_W * K + CELL_W * K // 2 - 6, ch * K + 1), d.upper(), fill=(230, 230, 230))
            frames.append(o)
        out = 'art/redraws/clock_soldier_8dir_%s.gif' % anim
        frames[0].save(out, save_all=True, append_images=frames[1:], duration=dur[:n], loop=0)
        frames[min(2, n - 1)].save('/tmp/clock_soldier_8dir_%s.png' % anim) if os.environ.get('PNG') else None
        print('saved', out)


if __name__ == '__main__':
    main()
