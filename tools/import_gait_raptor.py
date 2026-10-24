"""Raptor walk gait in the s, se, ne and n views (walk_e is kept: its gait is already a real run): legs rebuilt
per frame by tools/gait_lib.py, one foot after the other, each frame keeping its own body, head and tail.
Source snapshot: art/redraws/gait_src/raptor/ (taken from import_redraw_creatures.py's output).
Runs right after import_redraw_creatures.py. Usage: python3 tools/import_gait_raptor.py [--contact FILE]"""
import sys
sys.path.insert(0, __import__("os").path.dirname(__file__))
import gait_lib as g

P = {"*": {"legH": 8, "legw": 3, "boot_L": 4, "boot_h": 2, "amp": 4, "lift": 3, "knee": 2, "hip": 2, "spread": 2, "skip_bright": True}}
PASS = g.Pass("raptor", (58, 30), P, dirs=("s", "se", "ne", "n"))
if __name__ == "__main__":
    PASS.run()
    if "--contact" in sys.argv:
        g.contact("raptor", (58, 30), sys.argv[sys.argv.index("--contact") + 1])
