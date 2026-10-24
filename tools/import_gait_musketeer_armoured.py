"""musketeer_armoured walk gait (all five views): legs rebuilt per frame by tools/gait_lib.py (contact, down, passing, then the
other foot); each frame keeps its own torso, head, arms and gear. Source snapshot: art/redraws/gait_src/musketeer_armoured/.
Run after the importers that write its walk strips (see tools/rebuild_art.sh).
Usage: python3 tools/import_gait_musketeer_armoured.py [--contact FILE]"""
import sys
sys.path.insert(0, __import__("os").path.dirname(__file__))
import gait_lib as g

P = {"*": {"legH": 9, "legw": 3, "boot_L": 6, "boot_h": 4, "amp": 4, "lift": 2, "knee": 2, "hip": 2, "spread": 2}}
PASS = g.Pass("musketeer_armoured", (90, 36), P)
if __name__ == "__main__":
    PASS.run()
    if "--contact" in sys.argv:
        g.contact("musketeer_armoured", (90, 36), sys.argv[sys.argv.index("--contact") + 1])
