"""Terrain tiles for the biome maps.
  art/world/terrain/tiles_a.png  12x12 loose tiles (grass, dirt, sand, snow, swamp, lava, ...)
  art/world/terrain/tiles_b.png  16 biome blocks: 4 flat tiles, 3 ramp tiles, 2 cliff blocks each
-> assets/terrain/<set>_<n>.png (32x32), cliff faces <biome>_face_<n>.png (32x24),
   and scripts/terrain_data.gd with the counts and average colours."""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "terrain")
T = 32

# Sheet A: (row, col) cells per set.
SETS_A = {
    "grass": [(0, 0), (0, 1), (0, 2), (0, 5), (0, 6), (0, 7), (0, 9), (0, 10), (0, 11)],
    "grass_dark": [(0, 3), (0, 8), (0, 4)],
    "dirt": [(1, 0), (1, 1), (1, 3), (1, 4), (1, 5), (1, 8), (1, 10), (1, 2)],
    "gravel": [(1, 6), (1, 7), (2, 0), (2, 1), (2, 3), (4, 3)],
    "boulders": [(2, 4), (2, 5)],
    "desert": [(2, 6), (2, 7), (9, 8)],
    "sand": [(2, 9), (2, 10), (2, 11), (3, 4), (3, 6), (3, 7), (3, 5), (4, 4), (3, 10), (3, 11)],
    "red": [(2, 8), (3, 1), (3, 2), (3, 3), (3, 8), (4, 2)],
    "red_rock": [(3, 0), (3, 9), (4, 0), (4, 1)],
    "snow": [(4, 5), (4, 6), (4, 7)],
    "snow_rock": [(4, 8), (4, 9), (5, 5), (5, 6)],
    "ice": [(4, 10), (4, 11), (11, 3)],
    "water": [(5, 0), (5, 1), (5, 3), (6, 0), (11, 0)],
    "shallow": [(5, 2), (6, 2), (6, 5), (6, 6)],
    "swamp": [(5, 8), (5, 9), (5, 10), (5, 11), (6, 7), (6, 9), (6, 10), (6, 11), (7, 9), (7, 10), (7, 11)],
    "mud": [(6, 8), (7, 8)],
    "moss": [(7, 0), (7, 1), (7, 3), (7, 5), (7, 6), (7, 7)],
    "cobble": [(7, 4)],
    "basalt": [(8, 0), (8, 4)],
    "lava_crack": [(8, 1), (8, 2), (8, 5), (8, 6)],
    "lava": [(8, 3), (8, 7)],
    "autumn": [(8, 9), (8, 10), (8, 11), (9, 0), (9, 1), (9, 2), (9, 3)],
    "forest": [(8, 8), (9, 5), (9, 7), (9, 4)],
    "savanna": [(9, 9), (9, 10), (9, 11), (10, 3), (10, 5)],
}
# Sheet B: biome block names, row by row, left then right.
BIOMES_B = ["grass", "dirt", "gravel", "sand", "red", "desert", "snow_rock", "ice",
            "beach", "swamp", "moss", "lava", "autumn", "forest", "coast", "snow_forest"]


def shrink(img, w, h):
    return np.array(Image.fromarray(img.astype(np.uint8)).resize((w, h), Image.BOX))


def save(a, name):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(a.astype(np.uint8)).convert("RGB").save(os.path.join(OUT, name + ".png"))


def main():
    counts, colours = {}, {}
    a = np.array(Image.open("art/world/terrain/tiles_a.png").convert("RGB")).astype(int)
    s = a.shape[1] / 12.0
    for name, cells in SETS_A.items():
        for n, (r, c) in enumerate(cells):
            y0, x0 = int(r * s + s * 0.1), int(c * s + s * 0.1)
            tile = shrink(a[y0:y0 + int(s * 0.8), x0:x0 + int(s * 0.8)], T, T)
            save(tile, f"{name}_{n}")
            colours.setdefault(name, []).append(tile.reshape(-1, 3).mean(0))
        counts[name] = len(cells)
    b = np.array(Image.open("art/world/terrain/tiles_b.png").convert("RGB")).astype(int)
    bg = np.median(np.concatenate([b[0], b[-1], b[:, 0], b[:, -1]]), 0)
    fg = np.abs(b - bg).sum(-1) > 40
    lab, n = ndimage.label(ndimage.binary_closing(fg, iterations=2))
    sz = ndimage.sum(fg, lab, range(1, n + 1))
    boxes = [(o[0].start, o[0].stop, o[1].start, o[1].stop) for o, z in zip(ndimage.find_objects(lab), sz) if z > 2000]
    boxes.sort(key=lambda q: (q[0] // 100, q[2]))
    assert len(boxes) == 64, len(boxes)
    for k in range(16):
        row, side = divmod(k, 2)
        flat, ramp, c1, c2 = boxes[row * 8 + side * 4: row * 8 + side * 4 + 4]
        name = BIOMES_B[k]
        for part, box, cnt in (("flat", flat, 4), ("ramp", ramp, 3)):
            y0, y1, x0, x1 = box
            w = (x1 - x0) / cnt
            for i in range(cnt):
                xa = int(x0 + i * w + 3)
                xb = int(x0 + (i + 1) * w - 3)
                side_len = xb - xa
                yc = (y0 + y1) // 2
                tile = shrink(b[yc - side_len // 2: yc + side_len // 2, xa:xb], T, T)
                save(tile, f"{name}_{part}_{i}")
            counts[f"{name}_{part}"] = cnt
        for i, box in enumerate((c1, c2)):
            y0, y1, x0, x1 = box
            h = y1 - y0
            face = b[y0 + int(h * 0.5): y1 - 3, x0 + 4: x1 - 4]
            save(shrink(face, T, 24), f"{name}_face_{i}")
            top = b[y0 + int(h * 0.12): y0 + int(h * 0.42), x0 + int((x1 - x0) * 0.2): x1 - int((x1 - x0) * 0.2)]
            save(shrink(top, T, T), f"{name}_top_{i}")
        counts[f"{name}_face"] = 2
        counts[f"{name}_top"] = 2
    # The tiles that join best: typical colour for their set and edges that match
    # (left vs right, top vs bottom), so a field of them doesn't look like a patchwork.
    good = {}
    for name, cnt in counts.items():
        tiles = [np.array(Image.open(os.path.join(OUT, f"{name}_{i}.png")).convert("RGB")).astype(float) for i in range(cnt)]
        means = np.array([t.reshape(-1, 3).mean(0) for t in tiles])
        med = np.median(means, 0)
        scores = []
        for i, t in enumerate(tiles):
            seam = np.abs(t[:, 0] - t[:, -1]).mean() + np.abs(t[0] - t[-1]).mean()
            scores.append(np.abs(means[i] - med).sum() * 1.5 + seam)
        good[name] = [int(i) for i in np.argsort(scores)[:2]]
    with open(os.path.join(ROOT, "scripts", "terrain_data.gd"), "w") as f:
        f.write("class_name TerrainData\n## Generated by tools/import_terrain.py\n\nconst COUNTS := {\n")
        for k, v in counts.items():
            f.write(f'\t"{k}": {v},\n')
        f.write("}\n\n## The variants that tile best, best first.\nconst GOOD := {\n")
        for k, v in good.items():
            f.write(f'\t"{k}": {v},\n')
        f.write("}\n\n## Average colour of each loose tile set (minimap).\nconst COLOURS := {\n")
        for k, v in colours.items():
            m = np.mean(v, 0) / 255.0
            f.write(f'\t"{k}": Color({m[0]:.3f}, {m[1]:.3f}, {m[2]:.3f}),\n')
        f.write("}\n")
    print(len(counts), "sets")


if __name__ == "__main__":
    os.chdir(ROOT)
    main()
