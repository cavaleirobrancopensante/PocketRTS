#!/usr/bin/env python3
"""Round 14 icons (2026-10-29): the owner's ChatGPT sheets for the Brood's research and the Sire lures, in
art/ui/icons4/ (bronze frames with rivets on the navy ground, like round 13's Brood sheets; names left to right):

  brood_research_tyrant_chatgpt.png        nbr_clutch_raptor (BIGGER CLUTCH, Raptors), nbr_pack_hunt,
                                           nbr_battering_horns, nbr_quick_roots
  brood_research_venom_chatgpt.png         nbr_clutch_spitter (BIGGER CLUTCH, Spitters), nbr_slither, nbr_long_spit,
                                           nbr_swamp_mending
  brood_research_storm_lures_chatgpt.png   nbr_clutch_hatchlings (BIGGER CLUTCH, Hatchlings), nbr_updraft,
                                           brood/lure_tyrant, brood/lure_venom, brood/lure_storm

Cut and framed exactly like round 13's bronze sheets (tools/import_round13.py: the picture inside the bronze frame,
its ground shifted to the Brood's, made square and set in the Brood's own frame, the per-pixel median of its six
command icons), so every Brood button has the very same frame, 64x64.
  research -> assets/icons/nbr_<name>.png (Defs.RESEARCH "icon"; they replace the code-drawn placeholders of
              0.20.0, tools/make_brood_research_icons.py, retired)
  lures    -> assets/icons/brood/lure_<sire>.png (the grub's BUILD card, scripts/ui/hud.gd _nb_build_page: the
              Sire's lure button; the Sire's own portrait stays on his card and in the army bar)

Usage (from the repo root): python3 tools/import_round14.py [--contact FILE]. Re-runnable; run after
import_round13.py (tools/rebuild_art.sh). Then godot --headless --import."""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
_argv = sys.argv[:]
sys.argv = sys.argv[:1]               # (round 11 reads its own flags at import)
import import_round11 as r  # noqa: E402
import import_round13 as r13  # noqa: E402
sys.argv = _argv

SRC = "art/ui/icons4"
# sheet: [(file under assets/icons/, without .png)], left to right
SHEETS = {
    "brood_research_tyrant_chatgpt": ["nbr_clutch_raptor", "nbr_pack_hunt", "nbr_battering_horns", "nbr_quick_roots"],
    "brood_research_venom_chatgpt": ["nbr_clutch_spitter", "nbr_slither", "nbr_long_spit", "nbr_swamp_mending"],
    "brood_research_storm_lures_chatgpt": ["nbr_clutch_hatchlings", "nbr_updraft",
                                           "brood/lure_tyrant", "brood/lure_venom", "brood/lure_storm"],
}
# The frames are drawn a little taller than wide: (share of the excess cropped, where: 0 top .. 1 bottom), the
# rest padded with the picture's own ground (round 11's FIT). The eggs, lures and stakes stand on mud at the
# bottom: crop more of the empty top.
r.FIT.update({
    "nbr_clutch_raptor": (0.8, 0.5), "nbr_clutch_spitter": (0.8, 0.5), "nbr_battering_horns": (0.8, 0.5),
    "nbr_quick_roots": (0.8, 0.5), "nbr_swamp_mending": (0.8, 0.4),
    "brood/lure_tyrant": (0.8, 0.4), "brood/lure_venom": (0.8, 0.4), "brood/lure_storm": (0.8, 0.4),
})


def build():
    frame = r13.faction_frame("brood")
    made = []
    for sheet, names in SHEETS.items():
        px = r.load(f"{SRC}/{sheet}.png")
        bg, _ = r.bg_mask(px)
        for name, sl in zip(names, r.frame_boxes(px, bg, len(names))):
            crop = r.brass_crop(px, bg, sl)
            r.save_icon(r13.bronze_icon(crop, name, frame), name)
            made.append(name)
            print(f"icons/{name}.png: from {crop.shape[1]}x{crop.shape[0]} at ({sl[1].start}, {sl[0].start})")
    return made


def main():
    made = build()
    if "--contact" in _argv:
        old = ["brood/" + c for c in r13.CMDS[:3]]
        r13.contact(_argv[_argv.index("--contact") + 1], old + made, cols=8)


if __name__ == "__main__":
    main()
