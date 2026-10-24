"""The labourer's new walk legs (ChatGPT sheets of 2026-10-24, import_labourer_v2.py) under the walk strips of
other Crown foot units whose own legs were code-built or barely lift in some views:

  musketeer_armoured : all five views (its legs were rebuilt in code by import_gait_musketeer_armoured.py)
  musketeer          : walk, all five views, with his silver-grey breeches (owner approved 2026-10-24); his other poses already
                       have silver breeches and are left alone. His own walk (tricorne, musket in his hands) is the body.

Not touched: the officers (dismounted, dismounted_armoured: the owner likes their gait), the Missionary (his
long cassock hides legs: the trousers would poke out under it), mounted units, the Brood and Clockwork.
Each frame: the unit's coat, arms and weapon from the strip, legs from labourer walk frame round(k*6/n)
(strips have 2-7 frames), pasted with import_labourer_redraw.compose on a 42x35 window round the unit's
anchor. Sources: art/redraws/gait_src/crown_<unit>_walk_<d>.png (pristine strips, saved the first run).
Runs after import_labourer_v2.py and import_gait_musketeer_armoured.py (see tools/rebuild_art.sh), before
the veterancy trim masks. Preview of any unit: tools/experiment_crown_legs.py.
Usage: python3 tools/import_crown_legs.py
"""
import os, shutil, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import experiment_crown_legs as E  # noqa: E402  (its main() only runs as a script)
import experiment_white_pants as W  # noqa: E402

U = os.path.join(ROOT, "assets/units")
SRC = os.path.join(ROOT, "art/redraws/gait_src")
TARGETS = {"musketeer_armoured": ["s", "se", "e", "ne", "n"], "musketeer": ["s", "se", "e", "ne", "n"]}
SILVER_LEGS = {"musketeer", "musketeer_armoured"}      # (the Musketeer's breeches are silver-grey: the labourer's grey legs are recoloured to his ramp)


def run():
    os.makedirs(SRC, exist_ok=True)
    for u, dirs in TARGETS.items():
        cw, ch, ax, ay, _ = E.UNITS[u]
        for d in dirs:
            cur = f"{U}/{u}/walk_{d}.png"
            snap = f"{SRC}/crown_{u}_walk_{d}.png"
            if not os.path.exists(snap):
                shutil.copy(cur, snap)
            fr = E.frames(snap, cw)
            lab = E.frames(f"{U}/labourer/walk_{d}.png", 42)
            n = len(fr)
            out = [E.swap(fr[k], lab[int(round(k * 6.0 / n)) % 6], ax, ay) for k in range(n)]
            if u in SILVER_LEGS:
                out = [W.whiten(f, tones=W.SILVER) for f in out]
            Image.fromarray(np.concatenate(out, 1)).save(cur)
            print("legs:", u, d, n, "frames")


if __name__ == "__main__":
    run()
