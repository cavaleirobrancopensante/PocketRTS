#!/bin/sh
# Rebuild every sprite from the source sheets in art/, in the right order:
# the general importer, then the passes that replace or repair its output.
set -e
cd "$(dirname "$0")/.."
python3 tools/import_art.py
python3 tools/import_cannon2.py          # the cannon from the new sheets (overwrites the old one)
python3 tools/import_round4.py           # Stormcaller, Cuirassier, Spore Mother, storm/miasma effects
python3 tools/import_round5.py           # Ornithopter, Bloater (+ bloat cloud), Capacitor Works
python3 tools/import_round6.py           # Powder Wagon, labourer keg anims, keg mine, keg/cross/digits
python3 tools/import_round7.py           # Brood Pen, grub cocoon anims, Clockwork/Brood command icons
python3 tools/import_round8.py           # grounded Skywing anims, deflated Bloater anims
python3 tools/recolour_grub_cocoon.py     # cocoon grubs to the olive grub colour
python3 tools/import_round12.py          # Thresher, Bulwark, Wind-up Soldier, wider Assembly Works / Boiler
python3 tools/import_round10.py          # new musketeer (+ armoured), Mortar, Arc Thrower, their effects
                                         # and icons (replaces import_art's musketeer: before the fixes)
python3 tools/fix_weapons.py             # straight pike and muskets (both musketeers), held properly
python3 tools/fix_pike.py                # full-length pike in the thrust frames
PYTHONPATH=tools python3 tools/make_aim_up.py   # both musketeers aiming up at flyers
python3 tools/import_balloon.py          # Observation Balloon (gunners cut from the musketeer above)
python3 tools/import_lightning.py        # lightning effects
python3 tools/make_walls.py              # Crown walls and gates (drawn in code)
python3 tools/import_round9.py           # Tesla Cart as a spider cart (all its strips + art_data entry)
python3 tools/make_packs.py              # Clockwork battery backpacks (after every unit sheet)
python3 tools/import_deposits.py         # saltpetre / ore deposits (4 states), chips, icons, sparkle
python3 tools/import_round11.py          # painted portraits, research + ability icons, Engine Hall,
                                         # musketeer bayonet strips (last: replaces earlier icons/melee)
python3 tools/import_crate.py            # the Winder's self-building crate: unfold strips, carried / ground crate
echo "Now run: godot --headless --import"
