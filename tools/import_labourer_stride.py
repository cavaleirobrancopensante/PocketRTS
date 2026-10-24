"""The labourer's south and south-east walk had barely any gait (the ChatGPT sheets' feet swap by a pixel or two: a
shuffle). Code fix, placeholder until ChatGPT redraws them to match: the legs come from the east walk, whose stride is
strong, squeezed sideways (an east swing seen from 45 degrees / from the front is shorter on screen) and pasted under the
view's own body with import_labourer_redraw.compose. south-west is the south-east strips mirrored in game.
Sources: art/redraws/gait_src/labourer_walk_<d>_prestride.png (pristine strips saved the first run).
Runs right after import_labourer_v2.py (before the carry legs and Crown legs take the labourer's walk legs).
Usage: python3 tools/import_labourer_stride.py [--preview]"""
import os, shutil, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import import_labourer_redraw as R  # noqa: E402

U = os.path.join(ROOT, "assets/units/labourer")
SRC = os.path.join(ROOT, "art/redraws/gait_src")
SQUEEZE = {"se": 0.78, "s": 0.62}      # how much of the east swing shows on screen
LIFT = {"se": 0, "s": 0}               # south: the back foot rides up a row (depth), the front foot stays down


def frames(path, cw=42):
    im = np.array(Image.open(path).convert("RGBA")); return [im[:, i * cw:(i + 1) * cw].copy() for i in range(im.shape[1] // cw)]


def squeeze(img, s, lift=0):
    """Legs squeezed sideways about their hip centre; the foot behind the hip (left of it, the east walk faces right) rises `lift` rows."""
    cut = R.hem_row(img) + 1
    c = R.top_centre(img, cut)
    out = np.zeros_like(img)
    h, w = img.shape[:2]
    for x in range(w):
        nx = int(round(c + (x - c) * s))
        if 0 <= nx < w:
            col = img[:, x]
            if lift and x < c - 1:
                col = np.roll(col, -lift, axis=0); col[-lift:] = 0
            m = col[:, 3] > 0
            out[m, nx] = col[m]
    return out


def run():
    os.makedirs(SRC, exist_ok=True)
    lab_e = frames(f"{U}/walk_e.png")
    for d in ("se", "s"):
        cur = f"{U}/walk_{d}.png"; snap = f"{SRC}/labourer_walk_{d}_prestride.png"
        if not os.path.exists(snap):
            shutil.copy(cur, snap)
        body = frames(snap)
        out = [R.compose(body[k], squeeze(lab_e[k], SQUEEZE[d], LIFT[d])) for k in range(len(body))]
        Image.fromarray(np.concatenate(out, 1)).save(cur)
        print("stride:", d, len(out), "frames")


if __name__ == "__main__":
    run()
    if "--preview" in sys.argv:
        Z = 5
        sh = Image.new("RGBA", (6 * 42 * Z, 4 * 35 * Z), (60, 90, 60, 255))
        for i, d in enumerate(("se", "s")):
            for j, p in enumerate((f"{SRC}/labourer_walk_{d}_prestride.png", f"{U}/walk_{d}.png")):
                for k, f in enumerate(frames(p)):
                    sh.alpha_composite(Image.fromarray(f).resize((42 * Z, 35 * Z), Image.NEAREST), (k * 42 * Z, (i * 2 + j) * 35 * Z))
        sh.save("/tmp/stride_preview.png")
