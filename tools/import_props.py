"""Map decorations: art/world/props.png (loose objects on dark navy) cut into one picture per
prop by connected areas (small detached bits joined to their neighbour), scaled to the game
(a Musketeer is ~36 px tall) -> assets/props/<name>.png, and scripts/prop_data.gd.
   python3 tools/import_props.py [contact_sheet.png]

Each prop is picked by a point inside it on the sheet. solid: how many cells wide its foot
blocks (0 = purely decoration, walked through; solid ones are like rocks and trees)."""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "art", "world", "props.png")
OUT = os.path.join(ROOT, "assets", "props")

S, M, B, TR, BU, AN, BIG = 0.38, 0.45, 0.6, 0.6, 0.42, 0.4, 0.6
# name: (x, y on the sheet, scale, solid cells)
PROPS = {
    # stores
    "crate_a": (42, 45, S, 0), "crate_b": (102, 44, S, 0), "crate_c": (161, 44, S, 0), "crates_pair": (230, 45, S, 0),
    "crate_small": (295, 44, S, 0), "crate_d": (348, 46, S, 0), "barrel_a": (401, 43, S, 0), "barrel_b": (449, 44, S, 0),
    "barrel_c": (501, 44, S, 0), "barrel_d": (554, 44, S, 0), "urn": (611, 49, S, 0), "jar_lid": (669, 48, S, 0),
    "sacks_pile": (735, 50, S, 0), "sack_a": (798, 50, S, 0), "bucket": (849, 49, S, 0), "sack_b": (904, 49, S, 0),
    "sacks": (966, 51, S, 0), "crate_greens": (1040, 50, S, 0), "crate_grain": (1117, 44, S, 0), "crate_open": (1195, 48, S, 0),
    "barrel_e": (1266, 48, S, 0), "firewood": (1334, 42, S, 0), "crate_apples": (1415, 48, S, 0),
    "crate_e": (42, 101, S, 0), "crate_f": (107, 100, S, 0), "crate_long": (178, 103, S, 0), "crate_g": (248, 102, S, 0),
    "tub": (303, 101, S, 0), "tub_b": (353, 102, S, 0), "crate_hay": (403, 99, S, 0), "jar": (457, 110, S, 0),
    "jar_b": (495, 109, S, 0), "barrel_grain": (864, 118, S, 0), "cauldron": (1401, 115, S, 0),
    "baskets": (61, 160, S, 0), "basket_grain": (141, 160, S, 0), "planter": (215, 161, S, 0), "chest_fruit": (58, 233, S, 0),
    "chest": (869, 194, S, 0), "barrel_open": (1171, 201, S, 0), "barrel_tall": (1396, 195, S, 0), "cannonballs": (1318, 306, S, 0),
    "barrel_f": (322, 546, S, 0), "barrel_g": (373, 547, S, 0),
    # farm and camp things
    "campfire_pot": (1322, 117, M, 0), "wheelbarrow": (1479, 111, M, 0), "haybales": (386, 158, M, 0), "bench": (502, 168, M, 0),
    "cart_a": (636, 121, M, 0), "cart_b": (756, 127, M, 0), "well": (970, 140, M, 1), "wagon": (1093, 132, M, 2),
    "cart_c": (1220, 132, M, 0), "sheaf": (151, 233, 0.4, 0), "haystack": (261, 233, M, 1), "haystack_b": (354, 232, M, 1),
    "haystack_c": (452, 235, M, 1), "fence": (609, 195, 0.4, 0), "trough": (1088, 236, M, 0), "tripod": (1230, 225, M, 0),
    "oven": (1314, 221, M, 1), "drying_rack": (1479, 192, M, 0), "flag": (682, 281, M, 0), "signpost": (928, 281, M, 0),
    "banner_a": (998, 276, M, 0), "boat": (1460, 275, M, 0), "anchor": (1171, 309, 0.4, 0), "log": (1250, 306, 0.4, 0),
    "scarecrow": (1490, 451, M, 0), "fence_b": (1003, 459, 0.4, 0), "beehive": (60, 603, 0.4, 0), "campfire": (130, 883, 0.4, 0),
    "spit_roast": (228, 880, M, 0), "table": (343, 883, M, 0), "stall_small": (451, 882, M, 0), "forge": (534, 880, M, 0),
    "table_long": (656, 881, M, 0), "watch_frame": (1297, 738, 0.5, 0), "cross_wood": (1471, 764, M, 0),
    "banner_b": (1019, 713, M, 0), "banner_pole": (1383, 815, M, 0), "cross_stone": (1236, 839, 0.5, 0), "shrine": (50, 881, M, 0),
    # buildings and ruins (solid, like rocks)
    "tent_white": (75, 798, 0.55, 2), "tent_red": (177, 796, 0.55, 2), "tent_blue": (285, 796, 0.55, 2), "tent_round": (395, 799, 0.55, 2),
    "stall": (515, 804, 0.5, 2), "shed": (653, 806, 0.5, 2), "chapel_tower": (771, 829, BIG, 1), "windmill": (853, 833, BIG, 1),
    "cottage": (958, 834, BIG, 2), "chapel": (1054, 832, BIG, 2), "ruin_wall": (1161, 610, BIG, 2), "arch": (1253, 634, BIG, 2),
    "arch_big": (1461, 651, BIG, 2), "ruin_tower": (869, 704, BIG, 2), "ruin_pillar": (957, 717, BIG, 1), "ruin_keep": (1128, 682, BIG, 3),
    "arch_ruin": (1348, 660, BIG, 2), "column": (1234, 735, 0.55, 1), "vine_arch": (1154, 841, 0.5, 0), "flower_arch": (1314, 853, 0.5, 0),
    "boulder_moss": (1468, 358, 0.5, 1), "stone_block": (1425, 460, M, 1), "dead_trunk": (776, 714, 0.55, 1),
    "snow_rocks_a": (528, 610, 0.5, 2), "snow_rocks_b": (385, 704, 0.5, 3), "snow_rocks_c": (521, 703, 0.5, 3), "snow_rocks_d": (656, 703, 0.5, 3),
    # trees (art for the solid trees of some biomes)
    "oak": (59, 346, TR, 1), "pine": (146, 352, TR, 1), "birch": (224, 349, TR, 1), "dead_tree": (316, 351, TR, 1),
    "red_tree": (407, 356, TR, 1), "gold_tree": (499, 356, TR, 1), "blossom": (595, 371, TR, 1),
    # bushes, flowers, grass, stumps
    "bush_berry": (697, 376, BU, 0), "bush_flower": (790, 380, BU, 0), "bush_yellow": (882, 378, BU, 0), "bush_red": (984, 377, BU, 0),
    "brambles": (1082, 383, 0.4, 0), "reeds": (1154, 388, 0.4, 0), "thorns": (1223, 382, 0.4, 0), "stones": (1389, 384, 0.4, 0),
    "sapling": (50, 459, M, 0), "flowers": (130, 464, 0.4, 0), "shrub": (279, 460, 0.4, 0), "shrub_berry": (358, 460, 0.4, 0),
    "flowers_yellow": (447, 461, 0.4, 0), "flowers_mix": (540, 461, 0.4, 0), "flowers_pink": (642, 461, 0.4, 0), "shrub_dark": (745, 460, 0.4, 0),
    "stump": (834, 461, 0.4, 0), "grass_flowers": (913, 458, 0.4, 0), "grass_tall": (1104, 457, 0.4, 0), "flowers_wild": (1194, 460, 0.4, 0),
    "grass_reed": (1269, 458, 0.4, 0), "grass_c": (1349, 458, 0.4, 0), "nest": (58, 533, 0.35, 0), "stump_big": (502, 533, M, 0),
    "mushroom_red": (578, 533, 0.3, 0), "mushroom": (631, 536, 0.3, 0), "grass_a": (687, 536, 0.4, 0), "grass_b": (747, 533, 0.4, 0),
    "log_branch": (822, 527, 0.4, 0), "log_moss": (892, 524, 0.4, 0), "sticks": (965, 522, 0.4, 0), "shrub_b": (258, 543, 0.4, 0),
    "stump_moss": (431, 540, M, 0), "grass_d": (819, 593, 0.4, 0), "branches": (1159, 545, 0.4, 0), "antlers": (1254, 541, 0.4, 0),
    "stump_basket": (142, 608, 0.4, 0), "rocks_moss": (216, 622, BU, 0), "bush_lilac": (1482, 854, M, 0),
    # animals and birds
    "rooster": (203, 465, 0.3, 0), "rabbit": (1442, 539, 0.32, 0), "bird": (115, 554, 0.35, 0), "goat": (177, 542, AN, 0),
    "stag": (909, 596, AN, 0), "sheep": (994, 578, AN, 0), "cow": (1354, 542, AN, 0), "gull": (1494, 557, 0.32, 0),
    "goose": (297, 604, 0.35, 0), "heron": (435, 622, 0.35, 0), "gull_b": (829, 641, 0.32, 0), "crows": (994, 640, 0.35, 0),
}


def components(a):
    bg = np.median(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]), 0)
    fg = np.abs(a - bg).sum(-1) > 36
    fg = ndimage.binary_opening(fg, iterations=1)
    lab, n = ndimage.label(ndimage.binary_closing(fg, iterations=3))
    objs = ndimage.find_objects(lab)
    sz = ndimage.sum(fg, lab, range(1, n + 1))
    # small detached bits (a feather, a spark) join the neighbour they nearly touch
    boxes = {}
    for k, (o, z) in enumerate(zip(objs, sz)):
        if z >= 25:
            boxes[k + 1] = [o[0].start, o[0].stop, o[1].start, o[1].stop, int(z)]
    changed = True
    while changed:
        changed = False
        for i in list(boxes):
            A = boxes.get(i)
            if A is None or A[4] >= 400:
                continue
            for j, Bx in boxes.items():
                if j == i or Bx[4] < A[4]:
                    continue
                gy = max(0, max(A[0], Bx[0]) - min(A[1], Bx[1]))
                gx = max(0, max(A[2], Bx[2]) - min(A[3], Bx[3]))
                if gx <= 6 and gy <= 6:
                    boxes[j] = [min(A[0], Bx[0]), max(A[1], Bx[1]), min(A[2], Bx[2]), max(A[3], Bx[3]), A[4] + Bx[4]]
                    lab[lab == i] = j
                    del boxes[i]
                    changed = True
                    break
    return fg, lab, boxes


def main():
    os.makedirs(OUT, exist_ok=True)
    a = np.array(Image.open(SRC).convert("RGB")).astype(int)
    fg, lab, boxes = components(a)
    data = {}
    sheet = []
    for name, (x, y, sc, solid) in PROPS.items():
        # the component under the point, or the nearest box
        k = lab[y, x]
        if k not in boxes:
            best = min(boxes, key=lambda b: (max(0, boxes[b][2] - x, x - boxes[b][3]) ** 2 + max(0, boxes[b][0] - y, y - boxes[b][1]) ** 2))
            k = best
        y0, y1, x0, x1, _ = boxes[k]
        mask = (lab[y0:y1, x0:x1] == k) & fg[y0:y1, x0:x1]
        mask = ndimage.binary_closing(mask, iterations=1) | mask
        rgb = a[y0:y1, x0:x1].astype(float)
        w, h = max(1, round((x1 - x0) * sc)), max(1, round((y1 - y0) * sc))
        # premultiplied, so the navy around the edges doesn't bleed into the shrunk picture
        al = mask.astype(float)
        pm = np.dstack([rgb * al[..., None], al * 255])
        small = np.array(Image.fromarray(pm.astype(np.uint8), "RGBA").resize((w, h), Image.BOX)).astype(float)
        alpha = small[..., 3] / 255.0
        col = np.where(alpha[..., None] > 0, small[..., :3] / np.maximum(alpha[..., None], 1e-6), 0)
        out = np.dstack([np.clip(col, 0, 255), np.where(alpha > 0.45, 255, 0)]).astype(np.uint8)
        Image.fromarray(out, "RGBA").save(os.path.join(OUT, name + ".png"))
        data[name] = (w, h, solid)
        sheet.append((name, out))
    with open(os.path.join(ROOT, "scripts", "prop_data.gd"), "w") as f:
        f.write("class_name PropData\n## Generated by tools/import_props.py: every map decoration, its size in px and how\n")
        f.write("## many cells wide its foot blocks (0 = walked through).\n\nconst PROPS := {\n")
        for name, (w, h, solid) in data.items():
            f.write(f'\t"{name}": [{w}, {h}, {solid}],\n')
        f.write("}\n")
    print(len(data), "props")
    return sheet


if __name__ == "__main__":
    sheet = main()
    if len(sys.argv) > 1:
        from PIL import ImageDraw
        cols, cw, ch = 12, 130, 130
        img = Image.new("RGB", (cols * cw, ((len(sheet) + cols - 1) // cols) * ch), (60, 90, 50))
        dr = ImageDraw.Draw(img)
        for i, (name, px) in enumerate(sheet):
            p = Image.fromarray(px, "RGBA")
            p = p.resize((p.width * 2, p.height * 2), Image.NEAREST)
            ox, oy = (i % cols) * cw, (i // cols) * ch
            img.paste(p, (ox + (cw - p.width) // 2, oy + ch - 14 - p.height), p)
            # a Musketeer-sized bar for scale: 36 px tall (x2)
            dr.rectangle([ox + 2, oy + ch - 14 - 72, ox + 5, oy + ch - 14], fill=(255, 0, 0))
            dr.text((ox + 4, oy + ch - 12), name, fill=(255, 255, 255))
        img.save(sys.argv[1])
