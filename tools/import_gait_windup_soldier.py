"""windup_soldier walk gait (all five views): legs rebuilt per frame by tools/gait_lib.py (contact, down, passing, then the
other foot); each frame keeps its own torso, head, arms and gear. Source snapshot: art/redraws/gait_src/windup_soldier/.
Run after the importers that write its walk strips (see tools/rebuild_art.sh).
Usage: python3 tools/import_gait_windup_soldier.py [--contact FILE]"""
import sys
sys.path.insert(0, __import__("os").path.dirname(__file__))
import gait_lib as g

P = {"*": {"legH": 8, "legw": 3, "boot_L": 4, "boot_h": 2, "amp": 4, "lift": 3, "knee": 1, "hip": 1, "spread": 2}}
PASS = g.Pass("windup_soldier", (36, 30), P)
if __name__ == "__main__":
    PASS.run()
    if "--contact" in sys.argv:
        g.contact("windup_soldier", (36, 30), sys.argv[sys.argv.index("--contact") + 1])
