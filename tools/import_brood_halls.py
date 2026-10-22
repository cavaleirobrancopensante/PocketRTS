"""Import the Brood hall's upgraded levels: the Warren and the Broodmound.

Reads art/brood/buildings/warren_hall.png and art/brood/buildings/broodmound.png (each
4 states left to right: built, construction, damaged, destroyed, on black or real alpha,
the same layout as hive.png) and writes assets/buildings/<name>_<state>.png (and the
icon), with import_art.py's own helpers. A sheet that isn't there is skipped silently:
the game then draws the Burrow 1.15x (Warren) or 1.3x (Broodmound) bigger
(Defs.HALL_LEVELS, Building.hall_art). import_art.py imports them too, when it runs.

Usage (from the repo root): python3 tools/import_brood_halls.py
Then open the project in Godot once (or run it headless) so the new PNGs get imported.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_art  # noqa: E402


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    data = {"buildings": {}}
    for name in import_art.BROOD_HALLS:
        if os.path.exists(f"art/brood/buildings/{name}.png"):
            import_art.import_brood_building(name, data)
    if not data["buildings"]:
        print("no Warren or Broodmound sheet yet: nothing to do")


if __name__ == "__main__":
    main()
