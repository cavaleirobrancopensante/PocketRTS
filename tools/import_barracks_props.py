"""The Barracks yard's props and the men who train on them (Building DRILL_ART, scripts/building_life.gd).

Props, from the designer's two ChatGPT sheets on a navy background (art/crown/barracks_props/):
  dummy.png       two straw dummies on one sheet: intact (left) and ripped by sabre cuts (right). They
                  stand where the painted straw target was (tools/import_buildings_v2.py erases it
                  from the built and damaged Barracks).
  horse_prop.png  a wooden vaulting horse on a frame with a leather saddle, head to the left: drawn
                  mirrored here (head to the right, like the units' east-facing horses).
  The navy is keyed out (tools/import_horse_units.py's test, then the navy-tinted fringe), the
  props are cut, scaled to the building (same scale as the drill men: MAN_SCALE) and saved
  team-neutral (no key reds snapped: the game draws them with the plain material, so the dummy's
  rings and the saddle stay as painted): assets/buildings/barracks_props/{dummy_intact,
  dummy_damaged,horse_prop}.png

Men (assets/units/<art>/<anim>_e.png, east-facing, shrunk by MAN_SCALE, team-coloured like the
Musketeer drill's; the game draws them with the Barracks' team material):
  drill_musketeer_armoured, drill_dismounted, drill_dismounted_armoured: aim_e, fire_e, idle_e
      (+ reload_e for the Guardsman). The Officers shoot their pistol with their own aim / fire.
  drill_horseman, drill_cuirassier, drill_dragoon, drill_dragoon_armoured: the man alone, the
      horse taken out of the mount strip with the coat mask (assets/units/horse_masks), so he
      climbs on the wooden prop instead: mount_e (6 / 7 frames, played backwards to get off),
      and for the Horseman and Cuirassier idle_e (seated) and attack_e (the mounted sabre swing).
      Each set is scaled so its horse (the mask's length at the seated frame) is the same size
      (the Dragoons' strips are drawn bigger) and every frame is placed on one cell
      (MOUNT_CELL) with the horse's hooves' middle on MOUNT_FLOOR: the game puts the prop's floor
      middle there.
  The dismounted Horseman and Cuirassier use the Officers' sabre (melee_e) when there is no
  Horse Breeder (no prop to mount): drill_dismounted/melee_e.png, drill_dismounted_armoured/melee_e.png.

Run after tools/import_buildings_v2.py (python3 tools/import_barracks_props.py). Prints the numbers the
game needs.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import snap_team  # noqa: E402
from import_cannon2 import defringe  # noqa: E402
from import_horse_units import load, shrink  # noqa: E402

MAN_SCALE = 0.72           # same as the Musketeer drill (tools/import_buildings_v2.py)
DUMMY_H = 27               # game px: the dummy's height (a man is about 20, with his hat)
PROP_LEN = 1.0            # the prop's height, in horses' heights at the building's scale (cell px 41 tall)
HORSE_H = 41.0             # the riderless horse's height in the mount strips' cells (the mask)
MOUNT_CELL = (84, 62)      # game px: the mounted men's strips' cell
MOUNT_FLOOR = (42, 56)     # where the horse's hooves' middle (the prop's floor middle) is in it
FOOT_CELL = (90, 36)
MEN = {
    "musketeer_armoured": ["aim_e", "fire_e", "reload_e", "idle_e"],
    "dismounted": ["aim_e", "fire_e", "idle_e", "melee_e"],
    "dismounted_armoured": ["aim_e", "fire_e", "idle_e", "melee_e"],
}
# mounted sets: strips with the horse taken out
RIDERS = {
    "horseman": ["mount_e", "idle_e", "attack_e"],
    "cuirassier": ["mount_e", "idle_e", "attack_e"],
    "dragoon": ["mount_e"],
    "dragoon_armoured": ["mount_e"],
}
OUT = "assets/buildings"


def strip_frames(path, cw):
    s = np.asarray(Image.open(path).convert("RGBA")).copy()
    return [s[:, i * cw:(i + 1) * cw] for i in range(s.shape[1] // cw)]


def join(frames):
    h = max(f.shape[0] for f in frames)
    w = max(f.shape[1] for f in frames)
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:f.shape[0], i * w:i * w + f.shape[1]] = f
    return out


def cut_prop(name):
    """The sheet's figures: [(RGBA crop, bbox)], keyed out, left to right."""
    px, fg, bg = load("barracks_props/" + name)
    lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=12))
    out = []
    for i in range(1, n + 1):
        ys, xs = np.where((lab == i) & fg)
        if len(xs) < 5000:
            continue
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        img = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        m = fg[y0:y1, x0:x1]
        img[..., :3] = px[y0:y1, x0:x1]
        img[..., 3] = np.where(m, 255, 0)
        img = defringe(img, bg)
        out.append((x0, img))
    out.sort(key=lambda t: t[0])
    return [im for _, im in out]


def props():
    os.makedirs(OUT + "/barracks_props", exist_ok=True)
    dummies = cut_prop("dummy")
    assert len(dummies) == 2, len(dummies)
    for name, img in zip(("dummy_intact", "dummy_damaged"), dummies):
        s = DUMMY_H / float(img.shape[0])
        small = shrink(img, s, 0.45)
        Image.fromarray(small).save("%s/barracks_props/%s.png" % (OUT, name))
        print("%s: %d x %d (scale %.4f)" % (name, small.shape[1], small.shape[0], s))
    horse = cut_prop("horse_prop")[0][:, ::-1].copy()       # head to the right
    s = PROP_LEN * HORSE_H * MAN_SCALE / float(horse.shape[0])
    small = shrink(horse, s, 0.45)
    Image.fromarray(small).save(OUT + "/barracks_props/horse_prop.png")
    print("horse_prop: %d x %d (scale %.4f)" % (small.shape[1], small.shape[0], s))
    return small


def men():
    """The Officers' and the Guardsman's drill strips (like import_buildings_v2.drill)."""
    for art, anims in MEN.items():
        d = "%s/drill_%s" % (OUT, art)
        os.makedirs(d, exist_ok=True)
        for a in anims:
            frames = [snap_team(shrink(f, MAN_SCALE, 0.4)) for f in strip_frames("assets/units/%s/%s.png" % (art, a), FOOT_CELL[0])]
            Image.fromarray(join(frames)).save("%s/%s.png" % (d, a))
        print("drill_%s: %s" % (art, ", ".join(anims)))
    # where the muzzle flash is in the Officers' fire strip: the rightmost bright orange pixel of the flash frame (the
    # old Officer's frame 2; the Armoured Officer's ChatGPT strip fires on frame 1)
    for art in ("dismounted", "dismounted_armoured"):
        f = strip_frames("assets/units/%s/fire_e.png" % art, FOOT_CELL[0])[0 if art == "dismounted_armoured" else 1]
        r, g, b = f[..., 0].astype(int), f[..., 1].astype(int), f[..., 2].astype(int)
        m = (f[..., 3] > 0) & (r > 220) & (g > 110) & (g < 210) & (b < 110)
        ys, xs = np.where(m)
        if len(xs):
            x = xs.max()
            y = int(np.median(ys[xs >= x - 2]))
            print("%s pistol flash at cell (%d, %d): from his feet (%.1f, %.1f)" % (
                art, x, y, (x - 45) * MAN_SCALE, (y - 34) * MAN_SCALE))


def horse_box(art, anim, i, cw=98):
    m = np.asarray(Image.open("assets/units/horse_masks/%s/%s.png" % (art, anim)).convert("RGB"))
    f = m[:, i * cw:(i + 1) * cw, 0] > 127
    ys, xs = np.where(f)
    return xs.min(), xs.max() + 1, ys.min(), ys.max() + 1


def riders():
    """The mounted men without their horse, every set's horse the same size and in the same place."""
    cw = 98
    for art, anims in RIDERS.items():
        n = len(strip_frames("assets/units/%s/mount_e.png" % art, cw))
        x0, x1, y0, y1 = horse_box(art, "mount_e", n - 1)
        k = MAN_SCALE * HORSE_H / float(y1 - y0)      # (the horse's height: the Dragoons' strips are bigger)
        hx = (x0 + x1) / 2.0                          # the hooves' middle, in the strip's cell
        d = "%s/drill_%s" % (OUT, art)
        os.makedirs(d, exist_ok=True)
        for a in anims:
            frames = strip_frames("assets/units/%s/%s.png" % (art, a), cw)
            mask = np.asarray(Image.open("assets/units/horse_masks/%s/%s.png" % (art, a)).convert("RGB"))
            outs = []
            for i, f in enumerate(frames):
                f = f.copy()
                hm = mask[:, i * cw:(i + 1) * cw, 0] > 127
                hm = ndimage.binary_dilation(hm, iterations=1)     # (its outline goes with it)
                f[hm] = 0
                # specks left of the horse's outline
                lab, cnt = ndimage.label(f[..., 3] > 0, structure=np.ones((3, 3)))
                if cnt:
                    sizes = ndimage.sum(f[..., 3] > 0, lab, range(1, cnt + 1))
                    f[(sizes < 10)[lab - 1] & (lab > 0)] = 0
                # the horse's middle on a fixed spot of a big cell, then everything shrunk by k
                big = np.zeros((140, 200, 4), np.uint8)
                ox, oy = 100 - int(round(hx)), 120 - int(y1)
                big[oy:oy + f.shape[0], ox:ox + f.shape[1]] = f
                sm = snap_team(shrink(big, k, 0.4))
                cx, cy = 100 * k, 120 * k
                px_, py_ = int(round(MOUNT_FLOOR[0] - cx)), int(round(MOUNT_FLOOR[1] - cy))
                cell = np.zeros((MOUNT_CELL[1], MOUNT_CELL[0], 4), np.uint8)
                sy0, sx0 = max(0, -py_), max(0, -px_)
                h = min(sm.shape[0] - sy0, MOUNT_CELL[1] - max(py_, 0))
                w = min(sm.shape[1] - sx0, MOUNT_CELL[0] - max(px_, 0))
                cell[max(py_, 0):max(py_, 0) + h, max(px_, 0):max(px_, 0) + w] = sm[sy0:sy0 + h, sx0:sx0 + w]
                outs.append(cell)
            Image.fromarray(join(outs)).save("%s/%s.png" % (d, a))
        print("drill_%s: %s (%d mount frames, scale %.3f)" % (art, ", ".join(anims), n, k))


def main():
    props()
    men()
    riders()
    print("mounted men's cell %d x %d, the prop's floor middle at (%d, %d)" % (MOUNT_CELL + MOUNT_FLOOR))


if __name__ == "__main__":
    main()
