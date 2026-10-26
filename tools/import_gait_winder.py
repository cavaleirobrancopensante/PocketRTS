"""RETIRED (2026-10-26): the new Winder's walk is ChatGPT's own (tools/import_winder_v2.py); tools/rebuild_art.sh no
longer runs this, and running it now would rebuild the old Winder's legs from the snapshot over the new strips.

winder walk gait (all five views): legs rebuilt per frame by tools/gait_lib.py (contact, down, passing, then the
other foot); each frame keeps its own torso, head, arms and gear. Source snapshot: art/redraws/gait_src/winder/.
Run after the importers that write its walk strips (see tools/rebuild_art.sh).
Usage: python3 tools/import_gait_winder.py [--contact FILE]"""
import sys
sys.path.insert(0, __import__("os").path.dirname(__file__))
import gait_lib as g

P = {"*": {"legH": 9, "legw": 4, "boot_L": 6, "boot_h": 3, "amp": 4, "lift": 3, "knee": 2, "hip": 2, "spread": 2}}
PASS = g.Pass("winder", (48, 47), P)
if __name__ == "__main__":
    PASS.run()
    if "--contact" in sys.argv:
        g.contact("winder", (48, 47), sys.argv[sys.argv.index("--contact") + 1])
