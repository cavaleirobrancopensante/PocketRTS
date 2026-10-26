"""The Crown buildings' reds, after their importers: tools/rebuild_art.sh runs this right after the
last Crown building pass (tools/import_armoury_anims.py). Re-runnable: a second run changes nothing.

The owner (2026-10-26): the players' flags on the buildings and the details that are red should be
in the player's colour; the Farm's windmill roof is terracotta, not the player's colour. The team
shader (shaders/team.gdshader) repaints only the two key reds, (255, 0, 0) as the player's colour
and (150, 0, 0) as 0.6 of it (any pixel within 0.08 of them, RGB 0..1); every other red stays red
for every player. So, sprite by sprite:

- CLOTH (flags, banners, pennants, awnings, hangings, saddles and blankets, the inventor's shirt):
  its reds become the key reds, the lit parts the light key and the shaded parts the dark one; its
  darkest crimson edge, and the pale pinks where a white charge (the Church's cross) meets the red,
  go neutral (they would stay red or pink on every team). The gold (the fleur-de-lis, the borders),
  the white stripes of an awning and the outlines are left alone;
- TILES: red roof tiles are terracotta, shaded as painted and never near a key red (terracotta();
  the Farm's windmill cap, tools/import_windmill.py; slate roofs and thatch were never red);
- everything else keeps its colours: bricks (the Foundry), fire and embers, wood, thatch, food,
  powder kegs, the Barracks' painted target. Any key red left there (the importers' broad snap
  catches some brick and fire pixels, and import_art.unteam's nudge stays inside the shader's
  0.08) is put back to a plain painted red off the keys (OFF_LIGHT / OFF_DARK), the same for everyone.

Colour alone can't tell a red banner's shading from the brick wall it hangs on, so SPEC says where
each sprite's cloth is, in boxes (game px of the sprite: x0, y0, x1, y1, the ends excluded):
  "cloth"   the cloth's reds become the keys (and a key red already there stays);
  "stripes" a striped awning: as "cloth", and the pale blends between its red and white stripes
            become the white stripe's colour (they would stay pink on every team);
  "keep"    key reds already there stay (the importer snapped them right), nothing is added: for
            hangings on the Foundry's red bricks, whose shades are brick colour;
  "shirt"   (the Armoury inventor's strips: he moves) the shirt is grown from its strongest reds
            (and the key reds the importer snapped) over every cloth red touching them; the boxes
            in "material" (a red bucket, the target's edge, apples) are left out.
Outside them every key red goes (above). Sprites not in SPEC are left as they are.

Usage (repo root): python3 tools/recolour_crown_buildings.py [--check]
  --check: change nothing, print what would change (exit 1 if anything would).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/buildings")

KEY_LIGHT = (255, 0, 0)
KEY_DARK = (150, 0, 0)
KEY_NEAR = 0.08         # the shader's match distance (RGB 0..1)
OFF_LIGHT = (219, 19, 2)    # a material key red's own red again: 0.16 off the light key,
OFF_DARK = (128, 22, 8)     # 0.13 off the dark one
LIGHT_R = 175           # a cloth red this bright (red channel) takes the light key, else the dark
HUE_MAX = 14.0          # degrees: a cloth red is no more orange than this ("stripes": STRIPE_HUE)
STRIPE_HUE = 22.0       # (the market awning's lit stripes are orange-red)
RED_D = 0.4             # a cloth red's red stands this far over its other channels ((r - max(g, b)) / r)
RED_R = 75              # below this the cloth's crimson is its dark edge: a neutral dark instead
EDGE_R = 35
EDGE_D = 0.5            # (a crimson edge; dark wood round a flag is browner)
SHIRT_HUE = 12.0        # "shirt": the cloth's reds that grow it are no more orange than this (his skin
                        # and reddish hair are)

# Terracotta (the owner's roof tiles), shaded as painted: a pixel's tone (TONE weights of R, G, B,
# 0..1) along the ramp; the painted red's lit tiles land near the light stop, the joints and the
# underside on the darker ones. Every stop's green is over 0.38 of its red, far off the keys and
# off the importers' team snap (green at most 0.32 of red).
TONE = (0.62, 0.30, 0.08)
TERRACOTTA = [
    (0.10, (62, 28, 18)),       # the darkest crimson round the tiles
    (0.24, (112, 44, 26)),      # dark (the joints)
    (0.38, (148, 62, 36)),
    (0.50, (178, 84, 48)),      # mid
    (0.61, (206, 112, 68)),     # light (the painted red's lit tiles)
    (0.82, (232, 156, 106)),    # glints
]

# SPEC: the cloth of each sprite (assets/buildings/<name>.png), see the docstring.
_GATE = {"cloth": [(7, 0, 17, 10), (39, 0, 48, 10)]}          # the pennants on the two posts
_GATE_V = {"cloth": [(23, 0, 34, 9), (23, 33, 34, 43)]}
_SHIRT = {"shirt": True}
SPEC = {
    # Town Hall: the tower's banner, the one by the door, the market stall's striped awning
    "town_hall_built": {"cloth": [(82, 57, 96, 95), (65, 130, 75, 156)], "stripes": [(116, 125, 150, 148)]},
    "town_hall_construction": {"cloth": [(79, 54, 91, 89), (92, 125, 101, 146)]},
    "town_hall_damaged": {"cloth": [(80, 57, 92, 94), (63, 125, 73, 148)]},
    "town_hall_destroyed": {"cloth": [(64, 56, 76, 88)]},
    # Cottage: the banner by the door (the damaged roof's fire stays fire)
    "cottage_built": {"cloth": [(47, 57, 52, 68)]},
    "cottage_construction": {"cloth": [(46, 43, 53, 55)]},
    "cottage_damaged": {"cloth": [(46, 44, 52, 55)]},
    # Barracks: the banner over the door (fallen in the ruin); the painted target stays
    "barracks_built": {"cloth": [(73, 59, 85, 82)]},
    "barracks_construction": {"cloth": [(73, 60, 84, 83)]},
    "barracks_damaged": {"cloth": [(72, 57, 83, 80)]},
    "barracks_destroyed": {"cloth": [(57, 55, 77, 74)]},
    # Church: the tower's banner
    "church_built": {"cloth": [(16, 40, 25, 65)]},
    "church_construction": {"cloth": [(15, 41, 23, 65)]},
    "church_damaged": {"cloth": [(16, 41, 25, 66)]},
    # Armoury: the turret's flag and the banners by the door
    "armoury_built": {"cloth": [(18, 5, 33, 28), (115, 77, 125, 106), (58, 95, 68, 120)]},
    "armoury_construction": {"cloth": [(14, 5, 31, 26), (105, 75, 116, 102)]},
    "armoury_damaged": {"cloth": [(15, 7, 32, 27), (110, 77, 123, 107), (58, 96, 68, 117)]},
    "armoury_destroyed": {"cloth": [(96, 70, 121, 94)]},
    # Powder Mill: the banner (and the cloth by it on the scaffold); the red powder kegs stay
    "powder_mill_built": {"cloth": [(88, 36, 97, 57)]},
    "powder_mill_construction": {"cloth": [(75, 35, 87, 55)]},
    "powder_mill_damaged": {"cloth": [(88, 36, 97, 57)]},
    "powder_mill_destroyed": {"cloth": [(50, 37, 65, 52)]},
    # Horse Breeder: the flag, the blanket on the stable door, the blankets and rosettes in the
    # stalls, the cloth on the barrel and the saddles on the fence
    "horse_breeder_built": {"cloth": [(20, 16, 33, 52), (67, 65, 77, 76), (81, 66, 85, 71), (101, 57, 106, 63),
                                      (28, 75, 34, 82), (42, 80, 46, 86), (12, 92, 27, 105), (48, 109, 70, 129)]},
    "horse_breeder_construction": {"cloth": [(22, 17, 34, 46), (70, 72, 76, 81), (48, 83, 52, 88), (23, 98, 31, 109)]},
    "horse_breeder_damaged": {"cloth": [(20, 9, 32, 38), (68, 56, 77, 68), (79, 57, 84, 62), (96, 51, 101, 57),
                                        (33, 68, 37, 73), (44, 71, 49, 76), (23, 84, 28, 91)]},
    "horse_breeder_destroyed": {"cloth": [(74, 43, 98, 61)]},
    # Foundry: the banner, the awning, the hangings on its walls and pillars and the workmen's coats;
    # its bricks, the forge's fire and the basket by the door stay as painted. The hangings on the
    # red brick walls keep what the importer snapped ("keep": their shades are brick colour).
    "foundry_built": {"cloth": [(77, 83, 91, 112), (85, 102, 117, 128), (97, 91, 103, 103), (43, 139, 54, 149),
                                (86, 151, 96, 161)],
                      "keep": [(4, 97, 8, 124), (34, 114, 40, 142), (60, 111, 64, 120), (66, 112, 70, 121)]},
    "foundry_construction": {"cloth": [(76, 58, 89, 85), (83, 75, 114, 101), (54, 24, 65, 33), (16, 51, 29, 61),
                                       (13, 113, 21, 122), (43, 116, 52, 126)],
                             "keep": [(7, 68, 13, 86), (45, 83, 50, 99), (65, 81, 75, 93)]},
    "foundry_damaged": {"cloth": [(86, 73, 100, 101), (81, 92, 118, 120), (106, 83, 112, 95), (45, 135, 56, 144)],
                        "keep": [(4, 93, 11, 118), (35, 111, 42, 137), (72, 101, 80, 131)]},
    "foundry_destroyed": {"cloth": [(76, 92, 94, 117)]},
    # Gates: the pennants
    "gate_built": _GATE, "gate_half": _GATE, "gate_open": _GATE, "gate_construction": _GATE,
    "gate_damaged": _GATE, "gate_open_damaged": _GATE, "gate_destroyed": {"cloth": [(7, 0, 17, 10)]},
    "gate_v_built": _GATE_V, "gate_v_half": _GATE_V, "gate_v_open": _GATE_V, "gate_v_damaged": _GATE_V,
    "gate_v_open_damaged": _GATE_V, "gate_v_construction": {}, "gate_v_destroyed": {},
    # the Farm's windmill: its cap is terracotta at import (tools/import_windmill.py); a stray key red goes
    "farm_built": {}, "farm_construction": {}, "farm_damaged": {}, "farm_destroyed": {},
    # the Armoury's inventor on its roof: his red shirt (BuildingLife: drawn with the team material)
    "armoury_inventor": _SHIRT,
    "armoury_anim_armour": _SHIRT, "armoury_anim_matchlock": _SHIRT, "armoury_anim_flintlock": _SHIRT,
    "armoury_anim_caplock": _SHIRT, "armoury_anim_pouch": _SHIRT, "armoury_anim_charges": _SHIRT,
    # (the target pumpkin's edge, a red bucket, the straw dummy's red head and the apples stay)
    "armoury_anim_bayonet": {"shirt": True, "material": [(338, 0, 358, 14)]},
    "armoury_anim_quadrant": {"shirt": True, "material": [(37, 50, 51, 64)]},
    "armoury_anim_charge": {"shirt": True, "material": [(177, 15, 192, 28), (239, 5, 253, 19), (361, 31, 376, 44)]},
}


# ---------------------------------------------------------------- colour tests

def near_key(img):
    """Pixels the shader repaints (within KEY_NEAR of a key red), and which of them are the light key."""
    c = img[..., :3].astype(np.float32) / 255.0
    a = img[..., 3] > 0
    d1 = np.sqrt(((c - np.array(KEY_LIGHT) / 255.0) ** 2).sum(-1))
    d2 = np.sqrt(((c - np.array(KEY_DARK) / 255.0) ** 2).sum(-1))
    return a & ((d1 < KEY_NEAR) | (d2 < KEY_NEAR)), d1 <= d2


def hue_red(img):
    """(hue in degrees round red, 999 where red isn't the strongest channel; how far red stands
    over the other two, 0..1; red channel)"""
    c = img[..., :3].astype(np.float32)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    mx, mn = c.max(-1), c.min(-1)
    hue = np.where((r >= mx) & (mx > mn), (g - b) / np.maximum(mx - mn, 1e-6) * 60.0, 999.0)
    d = (r - np.maximum(g, b)) / np.maximum(r, 1.0)
    return hue, d, r


def cloth_reds(img, hue_max=HUE_MAX):
    """(the cloth's reds, its dark crimson edge): by colour only (where SPEC says there's cloth)."""
    a = img[..., 3] > 0
    hue, d, r = hue_red(img)
    red = a & (hue >= -40.0) & (hue <= hue_max) & (d >= RED_D)
    return red & (r >= RED_R), red & (d >= EDGE_D) & (r >= EDGE_R) & (r < RED_R)


def pale_pinks(img):
    """Pale pinks: a white charge (the Church's cross) blended with the red round it; on another
    colour they would stay pink, so they go white (to_neutral). Not the gold (more orange)."""
    hue, d, r = hue_red(img)
    return (img[..., 3] > 0) & (hue >= -40.0) & (hue <= 15.0) & (d >= 0.08) & (d < RED_D) & (lum(img) >= 90)


def lum(img):
    c = img[..., :3].astype(np.float32)
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


# ---------------------------------------------------------------- the treatments

def to_key(img, m):
    """Cloth reds -> the key reds (lit: light key, shaded: dark key)."""
    light = img[..., 0] >= LIGHT_R
    img[m & light, :3] = KEY_LIGHT
    img[m & ~light, :3] = KEY_DARK


def to_neutral(img, m):
    """A crimson edge -> a warm neutral dark of the same brightness."""
    v = lum(img)
    img[m, 0] = np.clip(v[m] + 4, 0, 255)
    img[m, 1] = np.clip(v[m], 0, 255)
    img[m, 2] = np.clip(v[m] - 2, 0, 255)


def unkey(img, m):
    """Key reds that aren't cloth (a brick, a flame, a keg) -> the painted red they were snapped
    from, near enough (the Foundry's snapped reds average (219, 19, 2) and (134, 15, 3)), off the keys."""
    _, lightk = near_key(img)
    img[m & lightk, :3] = OFF_LIGHT
    img[m & ~lightk, :3] = OFF_DARK


def terracotta(img, m):
    """Roof tiles -> terracotta along TERRACOTTA by each pixel's tone (shaded as painted)."""
    c = img[..., :3].astype(np.float32) / 255.0
    t = (c * np.array(TONE, np.float32)).sum(-1)
    xs = np.array([s[0] for s in TERRACOTTA], np.float32)
    cols = np.array([s[1] for s in TERRACOTTA], np.float32)
    out = np.stack([np.interp(t, xs, cols[:, i]) for i in range(3)], -1)
    img[m, :3] = np.clip(np.round(out[m]), 0, 255).astype(np.uint8)


# ---------------------------------------------------------------- per sprite

def box_mask(shape, boxes):
    m = np.zeros(shape[:2], bool)
    for x0, y0, x1, y1 in boxes:
        m[max(y0, 0):y1, max(x0, 0):x1] = True
    return m


def stripes(img, area):
    """The awning's pale blends between red and white stripes -> the white stripe's colour."""
    hue, d, r = hue_red(img)
    a = img[..., 3] > 0
    mx = img[..., :3].max(-1)
    v = lum(img)
    white = area & a & (d < 0.08) & (v >= 170)
    if not white.any():
        return
    ref = np.median(img[white][:, :3].astype(np.float32), 0)
    ref_v = float(ref @ np.array([0.299, 0.587, 0.114], np.float32))
    blend = area & a & (hue >= -40.0) & (hue <= 30.0) & (d >= 0.08) & (d < RED_D) & (mx >= 150)
    img[blend, :3] = np.clip(np.round(ref[None, :] * (v[blend] / ref_v)[:, None]), 0, 255).astype(np.uint8)


def recolour(img, spec):
    """One sprite (RGBA uint8, changed in place) by its SPEC entry."""
    a = img[..., 3] > 0
    nk, lightk = near_key(img)
    cloth = np.zeros(nk.shape, bool)
    # snap what is cloth already to the exact keys
    keep = box_mask(img.shape, spec.get("keep", []) + spec.get("cloth", []) + spec.get("stripes", []))
    for boxes, hue_max in ((spec.get("cloth", []), HUE_MAX), (spec.get("stripes", []), STRIPE_HUE)):
        if not boxes:
            continue
        area = box_mask(img.shape, boxes)
        red, edge = cloth_reds(img, hue_max)
        cloth |= area & (red | nk)
        to_neutral(img, area & (edge | pale_pinks(img)) & ~nk & ~red)
    if spec.get("stripes"):
        stripes(img, box_mask(img.shape, spec["stripes"]))
    if spec.get("shirt"):
        mat = box_mask(img.shape, spec.get("material", []))
        red, edge = cloth_reds(img, SHIRT_HUE)
        grow = (red | edge | nk) & ~mat
        hue, d, r = hue_red(img)
        strong = a & (hue >= -30.0) & (hue <= 10.0) & (d >= 0.6) & (r >= 120)
        shirt = (nk | strong) & ~mat
        # all of the cloth's reds that touch it (grown to the end, so a second run finds no more)
        shirt = ndimage.binary_propagation(shirt, structure=np.ones((3, 3), bool), mask=grow | shirt)
        keep |= shirt
        cloth |= shirt & (red | nk)
        to_neutral(img, shirt & edge & ~nk)
    keep_keys = keep & nk & ~cloth
    img[keep_keys & lightk, :3] = KEY_LIGHT
    img[keep_keys & ~lightk, :3] = KEY_DARK
    # the cloth: exact keys (a key already there keeps its tone)
    was_key = cloth & nk
    img[was_key & lightk, :3] = KEY_LIGHT
    img[was_key & ~lightk, :3] = KEY_DARK
    to_key(img, cloth & ~nk)
    # every other key red: as painted, off the keys
    unkey(img, a & nk & ~keep)


def main():
    check = "--check" in sys.argv
    changed = 0
    for name, spec in SPEC.items():
        path = os.path.join(OUT, name + ".png")
        if not os.path.exists(path):
            print("missing:", path)
            continue
        img = np.asarray(Image.open(path).convert("RGBA")).copy()
        before = img.copy()
        recolour(img, spec)
        n = int((img != before).any(-1).sum())
        if n:
            changed += 1
            nk0, _ = near_key(before)
            nk1, _ = near_key(img)
            print("%-28s %4d px changed; key reds %4d -> %4d" % (name, n, nk0.sum(), nk1.sum()))
            if not check:
                Image.fromarray(img).save(path)
    if check and changed:
        sys.exit(1)


if __name__ == "__main__":
    main()
