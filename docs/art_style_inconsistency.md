# Code-edited art that must be redrawn by ChatGPT for a uniform style (owner decision 2026-10-24)

The legs and tools below were rebuilt IN CODE (hard pixels, the unit's own palette) to give a real gait
or a different tool. They work, but their drawing style differs a little from the ChatGPT-drawn bodies
above them (leg shape and shading, boot shape, outline weight). When the art rework resumes, each entry
gets a ChatGPT redraw of the WHOLE strip (a full body, not just legs), then the code pass is retired
(the importer entry in tools/rebuild_art.sh is removed and the source sheet installed instead).
Source snapshots of the pristine strips are in `art/redraws/gait_src/`.

## A. Legs rebuilt in code (the gait passes)

| unit | strips / views | script (tools/) | notes |
| --- | --- | --- | --- |
| Labourer | carry (gold sack), carry_keg: now the NEW walk legs pasted under the carry bodies (import_labourer_carry_legs.py); the old e/se/ne code legs are superseded: e, se, ne (west mirrored), 6 frames each | import_labourer_gait.py | stride built from contact / down / passing, near leg light, far leg dark |
| Labourer walk, all five views | DONE 2026-10-24: ChatGPT sheets (prompts 30-34: labourer_walk_east_test, _s_v3, _se_v3, _ne_v3, _n_v3), no code legs left | import_labourer_v2.py (walk_frames_v3) | the old walk_frames() code legs are unused; carry and carry_keg still have code legs (prompts 08, 09 next, same technique) |
| Missionary | walk, all five views | import_gait_missionary.py | robe-black wide trousers + boots under the hem |
| Windup Soldier (Clockwork) | walk, all five views | import_gait_windup_soldier.py | |
| Winder (Clockwork) | walk, all five views | import_gait_winder.py | |
| Armoured Musketeer (Guardsman) | walk, all five views | import_gait_musketeer_armoured.py | prompt 16 (guardsman_walk) also covers a redraw |
| Labourer (walk s, se; so also sw, carry, keg-carry, Musketeers) | 2026-10-24: the ChatGPT s / se walk sheets barely moved the feet, so the legs are the east walk's stride squeezed sideways under the body (import_labourer_stride.py): a code placeholder; ask ChatGPT for a stronger s / se stride to match | import_labourer_stride.py | the legs in these views are east-walk legs squeezed, not drawn for the view |
| Armoured Musketeer, Musketeer | 2026-10-24: legs replaced by the labourer's ChatGPT walk legs (both Musketeers' are recoloured silver-grey; his ChatGPT walk with the red plumed hat was dropped) by the labourer's ChatGPT-drawn walk legs (import_crown_legs.py, runs after the code gait pass, which is now superseded; the musket's stock and hands are kept; the north walk also gets the dismounted Cuirassier's steel back plate pasted on) | import_crown_legs.py | the armoured musketeer's code legs are gone; mixed boot style until a ChatGPT redraw |
| Raptor (Brood) | walk: s, se, ne, n (walk_e kept: a real run already) | import_gait_raptor.py | stride is small in front/back views; prompt 18 |

Shared code: tools/gait_lib.py. Audit and ranking: docs/animation_gait_audit.md (tools/audit_walk_gait.py).

## B. Tools and poses drawn or composed in code (not legs)

| what | where | script | notes |
| --- | --- | --- | --- |
| Labourer farm hoe (the pickaxe replaced by a hoe, soil debris, weight shift) | mine_s/se/e/ne/n, 4 frames | import_labourer_hoe.py | the owner liked it; ChatGPT candidate labourer_hoe_v2.png exists (not installed) |
| Labourer shovel at the Powder Mill (3 loads x 4 frames) | shovel_s/se/e/ne/n | import_labourer_shovel.py | shovel and loads drawn on the hoe bodies |
| Labourer walking with a loaded shovel at the Powder Mill (3 loads x 6 frames): the shovel strip's lift body on the new walk's legs (import_labourer_redraw.compose) | walk_shovel_s/se/e/ne/n | import_labourer_shovel_walk.py | code composite, no ChatGPT source: ask for a hand-drawn loaded-shovel walk when the labourer is redrawn |
| Labourer bury, north row (repaired in code: the sheet repeated the standing back view) | bury_n | import_labourer_v2.py (REPAIRS) | crouch + soil pile, no shovel |
| Labourer walk/idle/death repairs listed in docs/animation_audit_labourer.md | various | import_labourer_redraw.py / import_labourer_v2.py | |
| Officer and Armoured Officer idle / aim / fire / death (rotated standing body, pistol drawn in code) | branch wt-officer-pose, NOT merged yet | import_officer_poses.py | owner has not approved; prompts 10-13 exist |

- Clutch Mound (0.12.84, tools/import_mound_chatgpt.py): BUILT is the owner's ChatGPT drawing (art/redraws/clutch_mound_vent_chatgpt.png: dome with two vent chimneys, crystals, spore plume), cut off the navy and box-scaled to 74 px wide. The other three states are derived from it IN CODE and need their own ChatGPT redraw: construction (chimneys, crystals and plume cut off, washed pale and grey, 90% size), damaged (small chimney and plume knocked off, drawn dark cracks, three dark burst-sac patches, a thin green ooze), destroyed (dome squashed to about half height, darkened and browned, the big chimney lying toppled, burst sacs, bone shards). The plain mound sheets and the old Spore Vent art are archived in `old units obsolete for now/`.

- Language flags (0.13.8, scripts/ui/flags.gd, class FlagIcon): the United States, Brazil and Spain flags on the main menu and in Settings are drawn in code with simple shapes (stripes, a star field, the Brazilian rhombus and globe, Spain's bands with a simplified shield). They are flat vector shapes, not pixel art like the rest of the menu; ask for hand-drawn flag icons in the game's style when the menu art is redone.

- Clockwork Line (0.14.7, scripts/line.gd, scripts/train.gd, scripts/line_art.gd): everything is loaded from sprites when the file exists (tools/import_line_art.py writes assets/world/line/tile_*.png, dmg_*, steam_*, assets/buildings/pressure_relay_* and ore_drill_*, assets/units/ore_locomotive|ore_car|troop_car/*) and DRAWN IN CODE when it does not: the pipe pieces with their rails (straight, corners, T, cross, caps, flanges), damaged / destroyed pipe, the steam puffs, the Line tool's ghost path and cost text, the pressure overlay tint and gauge badges (NO LINE / NO PRESSURE / percent), the Pressure Relay's gauge on the Charging Pylon stand-in, and the locomotive and wagons as coloured boxes. With the ChatGPT sheets imported none of these is used except the badges, the overlay and the tool ghost (UI, not art). Tiles are warped to 32x32 by the importer, so their pixel density is a little different from the buildings'.

## C. Still to prompt (new ids when the art rework resumes)

- Missionary walk (new prompt), Windup Soldier walk, Winder walk (new prompts; Armoured Musketeer = 16, Raptor = 18, Labourer walk/carry/keg = 07, 08, 09).
- For each, attach the CURRENT strip (the code-legged one) as the only 'what to keep: body, outfit, proportions' reference, and say: draw the whole figure including legs in one consistent style, with a real alternating gait.

- Clockwork roster prototype (scripts/cw_art.gd, docs/clockwork_units_prototype.md): the nine new units (Tin Militia, Scrapper, Rail Rifleman, Work Car, Plate Wagon, Heavy Locomotive, Carrier Car, Tesla Locomotive, Storm Engine) are drawn IN CODE as placeholders (small painted `Image`s with a dark outline: tin or steel bodies, brass trim, the team colour as pure red so the shader recolours it; idle / walk (2 frames) / death, five views, west mirrored), as are their command-card icons (64 x 64) and the card icons of SIDING, CREW OUT, CREW IN, PLATES, SET UP, BOARD, THUNDER, DOCK, CARRY and DROP. Real sheets dropped into `assets/units/<kind>/<anim>_<dir>.png` replace them with no code change (the frame count is read from the file width). Also in code: the siding's side arm and buffer (`CwRail.draw_siding`), the Storm Engine's storm (dark ellipse, swirling cloud discs and a ring, plus the existing zap strike effect), the Rail Yard (borrows the Engine Hall's sprites via `Defs.TEMP_ART`), the Plate Wagon's raised plates and the Carrier Car's landed flyers (the flyers are the real Ornithopter sprite parked on the deck; the plates are not drawn at all yet, only the wider gate and the cover are real). Sheet sizes wanted are in docs/clockwork_units_prototype.md.

- Clockwork Line, two tracks, loops and couplings (0.14.11, scripts/line.gd `draw_lanes`, scripts/train.gd `_draw_link`): the Line's pictures are now drawn 1.5 times larger than the 32 px cell (Defs.LINE.scale), and in CODE on top of every tile: a plain deck (it hides the single rail the tile sprite has) with TWO tracks, one per direction (parallel on straights, inner and outer on bends, a U at a dead end, stubs and a hub at T and cross), plus the amber ghost of a loop in the Line tool. The couplings between locomotive and wagons are a small steel bar with a brass pin ring drawn in code over the sprites (side views only). The code-drawn locomotive and wagon stand-ins were enlarged to match. Ask ChatGPT for a double-track tile set (15 tiles, two tracks on the deck, a loop-corner look) and for locomotive and wagon sprites with a visible hook at both ends.

- Clockwork trains, coupling (0.14.13, scripts/cw_consist.gd `draw_links`, scripts/cw_art.gd icons): the steel link between two coupled rail vehicles is drawn IN CODE (a bar with a pin ring and two buffer ticks at buffer height, side on only; end on it is hidden behind the car in front), over the vehicles' placeholder sprites. The COUPLE and UNCOUPLE command-card icons (`ab_cw_couple`, `ab_cw_uncouple`) are code-drawn too. Wanted from ChatGPT later: a coupler/link piece in the Line's style, two buffer details on each vehicle sheet, and the two icons. The coupling distances (`Defs.CW["couple"]["len"]`) follow the placeholder sheets (68 px side on) and need re-measuring when real sheets land.
- Code-drawn: tools/winder_guide/attack_guide.py makes a rough pose guide of the Winder attack (key held by the bow, thrust with the shank); ChatGPT redraws it in the real art style. Replace with the final art when it is imported.

- Clockwork gear field (gear prototype, scripts/gear.gd): the ground gear rings (`GearNet.draw_gear`: brass toothed discs with a rim, hub and spokes; dull red when unlinked), the placement ghost ring and its LINKS / NO LINK / CLASH / NEW FIELD label, the UNLINKED and SWAPPING badges, and the COGS resource icon in the top bar (the same gear drawn small) are all CODE-DRAWN. The Cog Press borrows the Ore Drill building art and the Ore Crusher portrait; the GEAR SWAP button reuses the build icon. Wanted from ChatGPT: a toothed gear tile set (small and big, a few rotations), a Clocktower ring, a Cog Press building and portrait, a cogs icon, and a gear swap icon.

## Cog Press working animation (code-drawn, 2026-10-26)
- tools/press_anim/press_work.py draws 8 working frames from the ChatGPT built cell (art/redraws/cog_press.png): six flywheel spokes and dark shafts redrawn in code (7.5 degrees per frame), the stamping piston moved down and up, a small cog dropping into the tray, a steam puff of plain grey circles. Result in art/redraws/cog_press_work_code.png/.gif. The owner wants ChatGPT to do an art pass over it for one uniform style.

## Mainspring working animation (code-drawn, 2026-10-26)
- tools/press_anim/mainspring_work.py: 8 frames from the ChatGPT built cell (art/redraws/mainspring.png): both hand cranks erased and redrawn turning (mirrored, 45 degrees per frame), gauge needle redrawn swinging, a bright glint sweeping across the steel spring, a steam puff of grey circles. Result in art/redraws/mainspring_work_code.png/.gif. Pose guide for a ChatGPT art pass.

Update 2026-10-26: the Cog Press flywheel is no longer code-drawn. ChatGPT painted one flat wheel face (art/redraws/cog_wheel_face_chatgpt.png); tools/press_anim/wheel_turn.py rotates that single painted image by exact angles and squashes it inside the painted rim of ChatGPT's wheel (art/redraws/cog_wheel_chatgpt_try2.png). Result: art/redraws/cog_press_work_v2.png/.gif. Only the piston motion, the small falling cog and the steam puff are still code-drawn. (Scripts expect their input files next to them; copy the PNGs beside the script to rerun.)

Update 2026-10-26: the Mainspring working animation (art/redraws/mainspring_work_v4.png/.gif, tools/press_anim/mainspring_work_v4.py) now uses ChatGPT's painted crank (mainspring_crank_chatgpt.png, swung in code, the two cranks half a turn apart) and ChatGPT's painted flat spring (mainspring_spring_chatgpt.png, shrunk, turned and twisted in code to coil in, then a blurred release and an overshoot). Still code-drawn: the gauge needle and the grey steam puff.
Update 2026-10-26 (v5): the Mainspring porthole now shows a cone spring built from ChatGPT's six painted rings (mainspring_cone_rings_chatgpt.png), stacked in code: the cone presses flat into a spiral, then shoots up (a three-step blur) and overshoots. tools/press_anim/mainspring_work_v5.py, art/redraws/mainspring_work_v5.png/.gif.
