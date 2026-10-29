# The Brood of creatures replaces the old Brood (0.18.0, branch brood-replace)

The owner's call (2026-10-29): the experiment's Brood (the Brood Mother, the fathers, rooting; docs/brood_new.md) is now THE Brood. The old Brood is gone from the game. Pictures: docs/shots/brood_replace/.

## What a player sees

- Every faction list (the skirmish setup, the online lobby, the map editor's test match, the AI study tools) has three factions: the Crown, the Brood, the Clockwork. "The Brood" is the Brood of creatures. The "(new, experiment)" entry is gone.
- The faction card and the menu icon of the Brood show the Brood Mother (Defs.FACTIONS["brood"]["card"]).
- The help pages (BASICS, THE BROOD), the codex, the tooltips, the unit cards and the faction "about" text describe the Brood of creatures only (en, pt, es; the new strings are in tools/i18n/26_brood_replace.txt).
- The venom line wears new colours (below).
- README's Brood section is rewritten for the Brood of creatures.

## What was removed

- The old Brood's buildings: Burrow (hive), Warren and Broodmound (the hall levels), Clutch Mound, Feeding Pit, Gorge Pit, Brood Pen, Roost. Their Defs entries, art, icons, select and death sounds.
- The old-only units: the Spore Mother and the Bloater (with MIASMA, HOLD GAS, gas, deflating, bursts, spit blobs). The Stormcaller is a Clockwork unit and stays.
- The old swamp of buildings (swamp joined to Burrows, mound reach, plateau swamp, pit circles and pit spots), the capital, eggs held by halls, hall upgrades, building morphing by grubs, the old grub hauling to a Burrow, the old burrow animation.
- The old Brood computer (scripts/ai_brood.gd) and every old-Brood branch of scripts/ai.gd (warrens, pits, mounds, swarm, xrush, the horse logic for the Brood). The Brood is played by AIBroodNew (scripts/ai_brood_new.gd) for every plan.
- Game.nb_teams. BroodNew.on(g, t) is now just factions[t] == "brood".
- Defs constants used only by the old Brood (EGGS_MAX, EGG_TIME, HALL_LEVELS, BROOD_HALL_SPACING, CAPITAL_SWAMP_BONUS, BROOD_RESOURCE_MAX_D, BLOAT, DEFLATE, MIASMA, ROOT_SWITCH, ROOT_SWAMP, NB_ABOUT, NB_TIPS). The acid slow is now Defs.ACID_SLOW.
- The net snapshot lost the old fields (buildings: level, morph_t, eggs, upgrade_t, swamp_r; units: deflate, gas) and pit_spots. The replay reader maps fields by name, so older replays still line up.
- Tools: import_queen.py, import_brood_halls.py and 18 old-only tests and measures (measure_brood_ai, measure_brood_ground, measure_pit_room, shot_mound, shot_pit_ground, shot_spoils, test_ai_brood_army, test_ai_brood_horse, test_ai_brood_judgement, test_ai_swarm_freed, test_ai_xrush, test_brood_capital, test_brood_hall, test_brood_pit_ground, test_brood_plateau_swamp, test_burrow_close, test_mound_ramp, test_mound_swamp). tools/prune_old_brood_art.py runs last in tools/rebuild_art.sh, so a rebuild does not bring the old art back.
- Kept: the Clutch Mound's construction picture (the cocoon a grub makes as it turns into a Rootmaw, turtle or father) and the broodmound icon (the Mother's GROW button).

## Old saves and replays

- The old slot id "brood_new" (the experiment) still loads, as "brood" (Defs.base_faction). Saves and replays made with the experiment's Brood keep working.
- A save or replay with the OLD Brood in it (faction "brood" from before 0.18.0) is refused with a note instead of a crash: "It has the old Brood in it (before v0.18.0), which is no longer in the game." (Defs.OLD_BROOD_NOTE).
  - Saves now carry "brood": Defs.BROOD_FORMAT (2). SaveGame.old_brood(d) is true for a save without it whose slots have "brood". The main menu then shows the note instead of CONTINUE.
  - Replays: ReplayFile.FORMAT is now 2. A replay of format 1 with a "brood" slot is refused by ReplayPlayer.load_file (the replay list shows the note).
- tools/test_replay.gd checks all three cases (old_brood_refused, old_experiment_plays, old_brood_save).

## The venom line's colours

The owner's mock-up: docs/shots/venom_colours/swap_mockup.png. The Spitter, the Venom Challenger and the Venom Sire (art "dilophosaurus") wear their scales in the team colour and their spikes and frill in olive. (The Mist Toad did too in 0.18.0; since 0.18.1 it is out of the swap again, the owner's word: its own colours, its details in the team colour; docs/spitter_redo.md.) The venom's yellow-green glow (drool, acid, eyes) is kept. Every other Brood creature is unchanged (crests in the team colour).

- The strips are not repainted. tools/import_venom_colours.py writes one mask per strip (assets/units/venom_masks/<unit>/): R marks a scale pixel and G its tone, B marks a spike pixel (1 + its tone). shaders/team.gdshader recolours by the mask when venom_swap is on: scales on a team-colour ramp (dark outlines kept), spikes on an olive ramp. VetLook sets venom_swap and the mask (Defs.VENOM_SWAP, by art key).
- A veteran's scales mix half of the veterancy skin (amber-ochre at 25 kills, obsidian at 50) into the team colour, so the side still reads.
- `python3 tools/import_venom_colours.py --contact DIR` writes check sheets (as painted, red, blue).
- In game: venom_red_blue.png and venom_green_purple.png, each with a _close one (a Raptor, then the Spitter, the Venom Challenger, the Venom Sire, the Mist Toad, a 25-kill and a 50-kill Spitter; tools/shot_brood_replace.gd). The skirmish setup with the Brood and the help's BROOD page: menu_lobby.png, menu_help.png (the same tool with `menu`).

## Other changes

- The Crown's and the Clockwork's scouting (scripts/ai_scout.gd) reads the Brood of creatures: a seen Brood Mother counts as its hall, rooted Rootmaws as its economy (BROOD_ECON_CAP 3), the fathers as its tech, and a Mound Turtle rooted far from the Mother as an expansion. Rooted creatures, the Mother, eggs and food piles do not count in its army value. The early-production table has the Tyrannosaur.
- Expansion spots: a Brood player sees its own best Mound Turtle spots (ExpansionSpots is on for every faction).
- The match log's Brood line says the Mother's stage instead of the old hall level.
- AI study and stress tools (tools/study/*, measure_ai_timelines, econ_bench, qa_soak_game) play the Brood of creatures. bo_ai's `_wave_worth` became `_army_worth` (it clashed with a parent function's signature).
- Ported tests: test_brood_fixes (Clockwork and Raptor parts), test_ai_abandoned_site (a Crown Cottage), test_barren_gather (Crown), test_ai_rush_followup, test_ai_wall_vs_rush (the rush is now AIBroodNew on xrush), test_ai_rush, test_attack_ground, test_fog_grey (its old swamp checks dropped), test_ride_by, test_brood_voices, test_aoe_show, test_ground_attack, test_worker_labels, test_online, test_ai_placement, test_stun_mark, test_expansion_spots, test_brood_new, test_i18n.

## Tests and matches run

Godot 4.7 headless, on this branch. The "exit 134" Godot prints after quitting is the known one, not a failure.

- Pass:
  - Brood: test_brood_new, test_sire_reach, test_brood_voices, test_brood_fixes, and test_brood_new_defence with mode:uproot (the computer's way; for rooted, see below).
  - Data, texts and replays: test_unit_stats, test_i18n (0 untranslated in pt and es), test_files, test_replay (with the three new old-Brood checks), test_save_job.
  - Map and fog: test_stun_mark, test_expansion_spots, test_start_layout (every map), test_fog_grey.
  - Combat and units: test_ride_by, test_attack_ground, test_ground_attack, test_aoe_show, test_grub_attack, test_haulers.
  - Interface and watching: test_worker_labels, test_supply_tip, test_qa_sandbox_lab, test_qa_watch.
  - Economy: test_barren_gather.
  - Every test_ai_*: abandoned_site, placement, scout, scout_defence, scout_sentry, scout_threat, wall_vs_rush, rush, rush_followup, air_defence, army_response, crown_bank, cw_horse_raid, gg_rule, r5_hold_spots, round6, round6_stall, worker_safety.
- test_ai_worker_safety failed once, on "two brutes... 9 -> lowest 4". That is a Crown v Crown case this branch did not touch. It passed on the rerun, so it is a borderline, random case.
- test_brood_new_defence with mode rooted (the Mother left in her nest, which is not what the computer does): against 5 Musketeers she now dies at 94 s. Before, she had 38 health left at 120 s. None of her numbers changed; the case was already on the edge (docs/brood_new.md says she would fall soon after). With mode:uproot she wins.
- Tests changed to fit, each keeping its point:
  - test_start_layout: the Brood has no starting buildings, so for it only the reach to the ground beside its Mother is checked.
  - test_fog_grey: the enemy base is a Clockwork one, and the swamp checks are dropped.
  - test_ride_by: it needs 22 x 16 open tiles; Hollowfen has no 30 x 22.
  - test_ai_scout_defence and test_ai_scout_sentry: the computer is a Clockwork one, because the Brood's computer has no scout.
  - test_ai_wall_vs_rush: 3 Musketeers by 2:40 or before the first Brood fighter reaches the farms, whichever is later. The Brood's fastest rush now arrives at about 3:10.
  - test_ai_rush: a Farm of a natural expansion's hall no longer counts as off the main's ground.
  - test_ai_rush_followup: the Brood's base is its Mother, and the mop-up case keeps one rider of the party.
  - test_save_job: the Raptors are put down by the Mother.

Full computer matches (tools/sim_brood_new.gd, Hard v Hard, 12 minutes each; no script errors after the fixes below):

- Brood v Crown (Hollowfen, seed 4242):
  - The Brood grew to 5-7 Rootmaws, 6 Mound Turtles, all three fathers, and 20-27 Raptors from 7:00.
  - It attacked at 6:53 and kept fighting; its army traded down to 2 Raptors by 12:00.
  - The Crown's scout called the Raptors a rush at 3:30 and the Crown built up behind its wall.
  - No winner at 12:00.
- Brood v Clockwork (Greenhold, seed 77), run twice:
  - The Clockwork's scout called a rush at 3:26. Its first attack, at 5:36, was beaten back by the Brood ("lost 380 for 75").
  - The Brood attacked at 7:07 and had 45 Raptors by 10:00 in the second run.
  - In the first run the Tyrant Sire chased an enemy 62 tiles from the Mother, and 1,600 food piled up while her warrior eggs waited for him. This is fixed (below); the second run spent its food.

Fixed on the way (game code):

- AI._foe_ground read the hall size of every enemy. Against the Brood, which has no hall, it threw an error on every think of the Crown and Clockwork computers. It now uses the Mother's rooted footprint.
- Spectator (watching computers): following a player read AI._swarm_phase, which went with the old Brood, so the camera stood still. Fixed.
- AIBroodNew: a father off his nest, uprooted to fight, is called back once he is 14 tiles from the Mother (a leash), so her eggs never wait long for him.
- tools/econ_bench.gd: its dead old-Brood rows are removed.

## Open questions for the owner

1. Veteran venom colours: half veterancy skin, half team colour on the scales. Keep, or show veterancy only on the spikes?
2. The bellies of the venom line stay as painted (pale); the mock-up was not clear about them.
3. The card portraits and icons of the venom line are pictures, not shaded sprites: they keep the old colours. Redraw them in the new scheme?
4. The Air rush plan is still offered for the Brood, but the Brood's computer only uses its wave sizes (no flyer opening). Give it a Storm Sire-first opening, or drop the plan for the Brood?
5. The sandbox's Brood building tab is empty (the Brood has no buildings). Hide it, or fill it with the rooting creatures?
6. The old importers for the Brood's creature art (tools/import_brood_new.py) keep the "new" name; renaming files (brood_new.gd, ai_brood_new.gd, BroodNew) was left alone to keep the diff small. Rename later?
7. The online lobby now offers the Brood of creatures; it has not been played online on two devices yet.
8. The Brood's computer is still the experiment's plain one: it has no scout (the tests of the Crown and Clockwork scouts and sentries now use a Clockwork computer), its waves start small (14-15 supply at about 7:00) and it keeps 25-33 grubs. Worth its own job.
9. Generic worker-rally code (dual_rally, worker_rally) written for the old Brood's grubs was kept, since the Crown and Clockwork use it too.
