"""PREVIEW ONLY (nothing installed): the Musketeer with the labourer's new walk legs and WHITE trousers. Walk: legs swapped
(experiment_crown_legs.swap). Every other pose (not death): only the trousers recoloured white. Writes /tmp/white_pants_walk.png
and /tmp/white_pants_other.png (top row of each pair = current art)."""
import os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import experiment_crown_legs as E
import import_labourer_redraw as R
U = os.path.join(ROOT, "assets/units/musketeer")
CW, CH, AX, AY = 90, 36, 45, 34
WHITE = [(236, 232, 224), (200, 196, 188), (150, 146, 140)]    # light, mid, shadow
CREAM = [(226, 212, 176), (198, 182, 144), (158, 140, 106), (112, 96, 72)]   # warm off-white, four tones (light .. deep shadow)
# the Musketeer's own breeches in his current south walk (sampled from the strip): a cool silvery grey
SILVER = [(214, 214, 210), (182, 182, 178), (152, 148, 146), (112, 108, 106)]
TONES = SILVER if "--silver" in sys.argv else (CREAM if "--cream" in sys.argv else WHITE)
PREFIX = "silver" if "--silver" in sys.argv else ("cream" if "--cream" in sys.argv else "white")


def whiten(fr, y0=None, tones=None):
    TONES_ = tones or TONES
    """grey trouser pixels (low colour spread, mid brightness) from row y0 down become white tones."""
    out = fr.copy()
    y0 = AY - 10 if y0 is None else y0
    seg = out[y0:AY + 1, 30:60]            # (only under the coat and between the boots: the muzzle smoke is grey too)
    r, g, b = [seg[..., i].astype(int) for i in range(3)]
    lum = (r + g + b) // 3
    spread = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    m = (seg[..., 3] > 0) & (spread < 22) & (lum >= 50) & (lum <= 175)
    if len(TONES_) == 4:
        tone = np.where(lum >= 118, 0, np.where(lum >= 95, 1, np.where(lum >= 72, 2, 3)))
    else:
        tone = np.where(lum >= 112, 0, np.where(lum >= 80, 1, 2))
    for t in range(len(TONES_)):
        sel = m & (tone == t)
        seg[sel, 0], seg[sel, 1], seg[sel, 2] = TONES_[t]
    return out


def sheet(path, rows, labels, Z=3):
    n = max(len(r) for r in rows)
    sh = Image.new("RGBA", (n * CW * Z + 40, len(rows) * CH * Z), (60, 90, 60, 255))
    from PIL import ImageDraw
    dr = ImageDraw.Draw(sh)
    for i, (fr, lb) in enumerate(zip(rows, labels)):
        dr.text((2, i * CH * Z + 4), lb, fill=(255, 255, 255, 255))
        for k, f in enumerate(fr):
            sh.alpha_composite(Image.fromarray(f).resize((CW * Z, CH * Z), Image.NEAREST), (40 + k * CW * Z, i * CH * Z))
    sh.save(path); print(path, sh.size)


def main():
    rows, labels = [], []
    for d in ["s", "se", "e", "ne", "n"]:
        old = E.frames(f"/tmp/oldm/walk_{d}.png", CW) if os.path.exists(f"/tmp/oldm/walk_{d}.png") else E.frames(f"{U}/walk_{d}.png", CW)
        lab = E.frames(os.path.join(ROOT, f"assets/units/labourer/walk_{d}.png"), 42)
        n = len(old)
        new = [whiten(E.swap(old[k], lab[int(round(k * 6.0 / n)) % 6], AX, AY)) for k in range(n)]
        rows += [old, new]; labels += [d + " now", d + " new"]
    sheet(f"/tmp/{PREFIX}_pants_walk.png", rows, labels)
    rows, labels = [], []
    anims = sorted({f.rsplit("_", 1)[0] for f in os.listdir(U) if f.endswith(".png")} - {"death", "walk"})
    for a in anims:
        for d in ["e", "s"]:
            p = f"{U}/{a}_{d}.png"
            if not os.path.exists(p):
                continue
            fr = E.frames(p, CW)
            rows += [fr, [whiten(f) for f in fr]]; labels += [f"{a} {d}", "white"]
    sheet(f"/tmp/{PREFIX}_pants_other.png", rows, labels, Z=2)


if __name__ == "__main__":
    main()
