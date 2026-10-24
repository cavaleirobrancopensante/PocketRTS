"""Missionary walk gait (all five views): see tools/gait_lib.py. His robe hides the thighs, so the rebuilt
legs are robe-black wide trousers with the boots below the hem. Source snapshot: art/redraws/gait_src/missionary/.
Runs after import_bandage.py. Usage: python3 tools/import_gait_missionary.py [--contact FILE]"""
import sys
sys.path.insert(0, __import__("os").path.dirname(__file__))
import gait_lib as g

P = {"*": {"legH": 6, "legw": 4, "boot_L": 6, "boot_h": 3, "amp": 4, "lift": 2, "knee": 1, "hip": 2, "spread": 2}}
PASS = g.Pass("missionary", (48, 40), P)
if __name__ == "__main__":
    PASS.run()
    if "--contact" in sys.argv:
        g.contact("missionary", (48, 40), sys.argv[sys.argv.index("--contact") + 1])
