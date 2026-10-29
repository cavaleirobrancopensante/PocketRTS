#!/usr/bin/env python3
"""THE OLD BROOD IS GONE (0.18.0, docs/brood_replace.md): its buildings (the Burrow and its Warren / Broodmound
levels, the Clutch Mound, Spawning Den, Gorge Pit, Feeding Pit, Brood Pen, Roost, the old Bone Midden), the Queen on
the capital, the Spore Mother and the Bloater, and the grub's old "burrow" strip at a pit. The older importers in
tools/rebuild_art.sh (import_art.py's Brood building sheets, import_round4 / 5 / 7 / 8 / 11, import_mound_chatgpt)
still write those files from their art/ sources (kept: they are the owner's drawings); this runs LAST in the rebuild
and takes them out of the game again: the runtime files under assets/, their art_data.gd entries and their gain
entries in scripts/sound_mix.gd.

Kept on purpose: assets/buildings/clutch_mound_construction.png (the Brood's cocoon while a grub morphs:
BroodRoot.COC_TEX), assets/icons/broodmound.png (the Mother's GROW button), the grub's "morph" strip (the cocoon's
first part) and the bloat_cloud / miasma_* effect art (the Mist Toad's FOG is drawn with them).

Usage (from the repo root): python3 tools/prune_old_brood_art.py
"""
import glob, os, re, shutil

BUILDINGS = ["hive", "clutch_mound", "warren", "warren_hall", "gorge_pit", "feeding_pit", "brood_pen", "roost",
             "broodmound", "bone_midden"]
ICONS = BUILDINGS + ["spore_mother", "bloater", "ab_miasma", "ab_hold_gas", "ab_root"]
ICONS.remove("broodmound")
UNITS = ["spore_mother", "bloater"]
removed = []


def rm(p):
    for q in (p, p + ".import"):
        if os.path.isfile(q):
            os.remove(q)
            removed.append(q)


def rmdir(d):
    if os.path.isdir(d):
        shutil.rmtree(d)
        removed.append(d + "/")


for k in BUILDINGS:
    for s in ("built", "construction", "damaged", "destroyed"):
        if not (k == "clutch_mound" and s == "construction"):
            rm("assets/buildings/%s_%s.png" % (k, s))
rm("assets/buildings/brood_queen.png")
for k in ICONS:
    rm("assets/icons/%s.png" % k)
rm("assets/icons/brood/ab_spit.png")
for k in BUILDINGS:
    rm("assets/audio/select/%s.wav" % k)
for f in glob.glob("assets/audio/combat/bloater_*.wav") + glob.glob("assets/audio/combat/spore_mother_*.wav"):
    rm(f)
for v in ("voice", "voice_pt", "voice_es"):
    for k in UNITS:
        rmdir("assets/%s/%s" % (v, k))
for k in UNITS:
    rmdir("assets/units/%s" % k)
for f in glob.glob("assets/units/grub/burrow_*.png"):
    rm(f)

# art_data.gd: the two units' entries, the grub's burrow strip, the old buildings' sizes
p = "scripts/art_data.gd"
L = open(p, encoding="utf-8").read().split("\n")
out = []
i = 0
while i < len(L):
    if re.match(r'^\t"(%s)": \{"cell"' % "|".join(UNITS), L[i]):
        while L[i] != "\t}},":
            i += 1
        i += 1
        continue
    if re.match(r'^\t\t"burrow_(e|n|ne|s|se)": \d+,$', L[i]):
        i += 1
        continue
    if re.match(r'^\t"(%s)": Vector2i\(' % "|".join(BUILDINGS), L[i]):
        i += 1
        continue
    out.append(L[i])
    i += 1
open(p, "w", encoding="utf-8").write("\n".join(out))

# sound_mix.gd: the gains of the files gone
p = "scripts/sound_mix.gd"
pat = re.compile(r"assets/(audio/combat/(bloater|spore_mother)_|audio/select/(%s)\.wav|voice(_pt|_es)?/(bloater|spore_mother)/)" % "|".join(BUILDINGS))
L = open(p, encoding="utf-8").read().split("\n")
open(p, "w", encoding="utf-8").write("\n".join(l for l in L if not pat.search(l)))
print("pruned %d old Brood files" % len(removed))
