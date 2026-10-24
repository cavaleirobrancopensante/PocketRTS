# Old units, obsolete for now

Files of units that are no longer in the game, kept in case they come back. Godot ignores this folder (.gdignore).

- pikeman/ : art strips (units/), voice lines (voice/), icon. The Pikeman was removed (the Musketeer's bayonet does his job); a saved Pikeman loads as a Musketeer. Its sprite entry was removed from scripts/art_data.gd. NOTE: tools/import_art.py, import_round10.py and fix_weapons.py still know the pikeman and would write assets/units/pikeman again and re-add the art_data entry if tools/rebuild_art.sh is run in full; delete those pikeman lines first, or move the folder again afterwards. The combat sound combat/pikeman_attack stays in assets/audio (the bayonet uses it).
