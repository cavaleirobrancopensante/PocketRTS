#!/bin/sh
# Rebuild every sprite from the source sheets in art/, in the right order:
# the general importer, then the passes that replace or repair its output.
set -e
cd "$(dirname "$0")/.."
python3 tools/import_art.py
python3 tools/import_cannon2.py          # the cannon from the new sheets (overwrites the old one)
python3 tools/import_round4.py           # Stormcaller, Cuirassier, Spore Mother, storm/miasma effects
python3 tools/import_cuirassier_gallop.py   # the Cuirassier's side-view gallop (replaces round 4's walk_e)
python3 tools/import_round5.py           # Ornithopter, Bloater (+ bloat cloud), Capacitor Works
python3 tools/import_round6.py           # Powder Wagon, labourer keg anims, keg mine, keg/cross/digits
python3 tools/fix_labourer_hoe.py        # labourer (after import_art + round 6's keg anims): pickaxe cut
                                         # to a hoe, leftover backdrop swept from every strip,
                                         # portrait with his felt hat and a hoe
python3 tools/import_build_still.py      # labourer hammering (build_*): one still body, only the arm and
                                         # tool move (after fix_labourer_hoe; safe to run twice)
python3 tools/import_labourer_redraw.py  # labourer redraws (art/redraws/labourer_*.png): walk, carry, keg,
                                         # idle_carry, mine, build (replaces the strips above; also edits art_data.gd)
python3 tools/import_labourer_hoe.py   # labourer farm swing: the redraw's pickaxe becomes a hoe (after import_labourer_redraw)
python3 tools/import_labourer_gait.py   # labourer side/diagonal gait (e, se, ne walk / carry / keg): legs rebuilt per frame (after the hoe)
python3 tools/import_labourer_v2.py     # labourer round 2 (death, keg death, bury, idle, walk): LAST of the labourer passes, the gait
                                         # pass above rewrites walk e/se/ne from its snapshot and this one rebuilds them on the new body
python3 tools/import_labourer_shovel.py   # labourer at the Powder Mill: shovel_<dir> strips (3 loads x 4 frames; after the hoe: same body)
python3 tools/import_round7.py           # Brood Pen, grub cocoon anims, Clockwork/Brood command icons
python3 tools/import_round8.py           # grounded Skywing anims, deflated Bloater anims
python3 tools/recolour_grub_cocoon.py     # cocoon grubs to the olive grub colour
python3 tools/import_round12.py          # Thresher, Bulwark, Wind-up Soldier, wider Assembly Works / Boiler
python3 tools/import_round10.py          # new musketeer (+ armoured), Mortar, Arc Thrower, their effects
                                         # and icons (replaces import_art's musketeer: before the fixes)
python3 tools/fix_cannon_crew.py         # the cannon's crew: two men in every view (before the reload)
python3 tools/import_reload.py           # cannon + mortar reload (built on their idle frames above)
python3 tools/fix_helmets.py             # gun crews' morions back to steel (the team snap reddened some)
python3 tools/fix_weapons.py             # straight pike and muskets (both musketeers), held properly
python3 tools/fix_pike.py                # full-length pike in the thrust frames
PYTHONPATH=tools python3 tools/make_aim_up.py   # both musketeers aiming up at flyers
python3 tools/import_balloon.py          # Observation Balloon (gunners cut from the musketeer above)
python3 tools/import_lightning.py        # lightning effects
python3 tools/import_palisade.py         # Crown palisade (auto-tiling pieces) and gates, from art/crown/palisade.png
python3 tools/import_palisade_gate_v.py  # the gate in a N-S palisade line, side-on (art/crown/palisade_gate_v.png)
python3 tools/import_round9.py           # Tesla Cart as a spider cart (all its strips + art_data entry)
python3 tools/make_packs.py              # Clockwork battery backpacks (after every unit sheet)
python3 tools/import_deposits.py         # saltpetre / ore deposits (4 states), chips, icons, sparkle
python3 tools/import_round11.py          # painted portraits, research + ability icons, Engine Hall,
                                         # musketeer bayonet strips (last: replaces earlier icons/melee)
python3 tools/import_command_icons.py     # command icons: hold fire / fire at will, hold, patrol, rally, demolish
python3 tools/import_armoury.py          # the Armoury research icons (the building and its icon now come
                                         # from import_buildings_v2.py below) and the Horseman /
                                         # Guardsman portraits (after round 11: replaces research_armour
                                         # and musketeer_armoured)
python3 tools/import_pouch_icon.py       # the Shot Pouch research icon (same steel bevel)
python3 tools/fix_mount_heads.py         # both Dragoons' front-view mount strips: frame 4 gets frame 5's head
python3 tools/import_crate.py            # the Winder's self-building crate: unfold strips, carried / ground crate
python3 tools/import_windmill.py         # the Farm's windmill (replaces import_art's farmhouse), sails,
                                         # scarecrows and Farm icon
python3 tools/make_farm_field.py         # the Farm's crop fields round the windmill
python3 tools/import_mist_toad.py       # Mist Toad (its own pass: black sheet, fog cloud keyed out),
                                         # its portrait and the FOG / TONGUE ability icons
python3 tools/import_mortar_walk.py      # the Mortar's towed walk (replaces round 10's walk; its side-on
                                         # horse is the Field Cannon's limber horse)
python3 tools/fix_mortar_crew.py         # the Mortar's crew: two men in every view, and no pennant
python3 tools/fix_mortar_smoke.py         # no smoke puff over the right-hand gunner's helmet when it fires
                                         # (after the reload, helmets and towed walk above)
python3 tools/import_horseman.py         # the unarmoured Horseman's strips (cut like the Cuirassier's,
                                         # on his cell) and his art_data entry
python3 tools/import_pistol.py           # the Horseman / Cuirassier firing the pistol from the saddle
                                         # (pistol_<dir> strips, on the Horseman's cell and anchor)
python3 tools/import_horse_units.py      # the horse system's units: riderless horse, Messenger, Dragoons
                                         # (light and armoured), dismounted Horseman (slash fixed)
python3 tools/import_bandage.py           # the Missionary bandaging a dismounted Horseman / Cuirassier
                                         # (their own art keys, a wider cell; after import_art's missionary)
# (tools/import_horse_breeder.py, the old Horse Breeder sheet, is no longer run: import_buildings_v2.py)
python3 tools/import_horse_icons.py         # the horse units' portraits and the horse command icons
python3 tools/import_mount.py            # the riders' mounting strips (mount_s / se / e / n) from
                                         # art/crown/mount/ (after the riders' own sheets: it lines
                                         # its last frame up with their idle; before the coat masks)
python3 tools/import_horse_team.py      # a gun's / wagon's team horse in harness (art/crown/horse_team.png:
                                         # the S row's stray traces erased; before the coat masks)
# The owner's image-AI redraw sheets (art/redraws/, docs/animation_audit_units.md): each replaces
# strips written by the importers above, so they run after them and before the masks / drill strips
python3 tools/import_redraw_officers.py   # Officer + Armoured Officer: 4-frame sabre melee, 8-frame walk
python3 tools/import_redraw_musketeer.py  # Musketeer: 6-frame walk in all 5 directions
python3 tools/import_redraw_creatures.py  # Raptor + Grub: walk_s / se / ne / n (E kept)
python3 tools/import_redraw_mounted.py    # Dragoon: walk_ne / se / e / n (Cuirassier kept)
python3 tools/import_horse_coats.py     # horse coat masks for every strip with a horse (Cuirassier,
                                         # Field Cannon, Mortar, Powder Wagon): after all their sheets
python3 tools/import_powder_mill.py      # the Crown Powder Mill as a horse mill (art/crown/powder_mill_horse.png:
                                         # replaces structures2's water mill, which import_art skips), its
                                         # millstone overlays, icon and the bay mill horse cut from the team
                                         # horse's strips (after import_horse_team and the coat masks)
python3 tools/import_mill_shed.py       # the mill's lean-to over the three heaps and its hopper (from art/crown/mill_base, after import_powder_mill)
python3 tools/import_buildings_v2.py     # the new Town Hall (+ its bell), Barracks (+ the drilling Musketeer),
                                         # Horse Breeder (+ its paddock horses), Armoury (+ the rooftop
                                         # inventor, emblem repainted) and Church (+ lit windows) from
                                         # art/crown/buildings_v2/ (replaces import_art's, import_armoury's
                                         # and import_horse_breeder's; after the musketeer fixes, the horse
                                         # coat masks and import_armoury)
python3 tools/import_barracks_props.py   # the Barracks yard's wooden horse prop and straw dummy (art/crown/barracks_props/)
                                         # and the Officers' / Guardsman's / mounted men's drill strips (after the
                                         # buildings above: it uses the unit strips and horse masks)
python3 tools/import_armoury_anims.py    # the Armoury's nine research experiments (the inventor's 6-frame
                                         # strips, assets/buildings/armoury_anim_<research>.png) from
                                         # art/crown/armoury_anim/ (after import_buildings_v2: same roof patch)
python3 tools/import_queen.py           # the Brood Queen at the capital Burrow (art/brood/queen.png: still, backdrop keyed out)
# Gait passes (tools/gait_lib.py, docs/animation_gait_audit.md): legs rebuilt per frame, one foot after the other;
# each strip's torso / head / gear kept, pristine sources snapshotted in art/redraws/gait_src/<unit>/ (idempotent)
python3 tools/import_gait_missionary.py
python3 tools/import_gait_windup_soldier.py
python3 tools/import_gait_winder.py
python3 tools/import_gait_musketeer_armoured.py
python3 tools/import_gait_raptor.py
python3 tools/import_vet_trim.py         # veterancy trim masks (hat lace / band, helmet comb and brim)
                                         # for the Crown's soldiers: after every strip they read,
                                         # mount strips included
python3 tools/import_vet_skin.py         # veterancy skin masks for the Brood's fighting creatures
python3 tools/import_cursors.py          # the mouse cursors (art/ui/cursors.png) and their hotspots
echo "Now run: godot --headless --import"
python3 tools/make_calm_grass.py
