# Clockwork gear prototype

The Clockwork's economy as a field of turning gears (`Defs.gear_mode`, default on). The old Line (rails, trains, pressure) is shelved behind `Defs.line_mode` (default off) and still works when switched on; the Line tests set `line_mode` true and `gear_mode` false (`tools/line_test_util.gd`).

## What it does

- **Gear field** (`scripts/gear.gd`, class `GearNet`): every Clockwork building has a ring of toothed ground gears, small or big; the Clocktower has the biggest. Teeth are a constant size (`pitch` 25 px: a 3x3 small ring has 21 teeth, big 30, the Clocktower 38), so rings mesh exactly: neighbours counter-rotate and the smaller gear spins faster. Replaces the blue field drawing.
- **Painted rings** (`scripts/gear_art.gd`, class `GearArt`): the ChatGPT rings rebuilt for any tooth count from strips (`assets/gear/`; reference `tools/gear_art/rebuild_ring.py`), baked once per (kind, teeth) into a texture (about 40-110 ms each on the dev box) and drawn flat on the ground: rotated, then squashed to `FIELD_Y`, with a thick edge (the silhouette 6 px deep). GearNet draws all edges, then all faces, then the placement ghost, on one node under the buildings.
- **Mesh rule** (`GearNet.mesh_phase`): tooth centres at phase + TAU*k/n; a child ring's phase is set every frame from its parent's so that at the contact a tooth faces a gap (u + v = 0.5). `mesh_error` measures it (tests).
- **Idlers** (`GearNet.idler_for`): rings snap to the tile grid, so a linked pair rarely touches. Within `mesh_tol` px they mesh directly; a wider gap (up to `slack`) gets a free idler cog of at least `idler_min` teeth whose pitch circle touches both, beside the line of centres on the side with more room. The ring then turns the same way as its parent. The ghost shows the idler it would get and turns already meshed.
- **Mainspring** (showcase): 3x3, crew 3 Winders (the press crew logic), winds TENSION (`players[t]["tension"]`, shown in the top bar for the Clockwork only, nothing spends it); `Defs.GEAR.mainspring`. Painted frames (`assets/buildings/mainspring_*`), working loop while linked and crewed.
- **Clockwork Lab** (`scripts/cw_lab.gd`): starts on the gear field with two Cog Presses and a Mainspring meshing round the Clocktower, Winders on them, the camera on it. Screenshots: `tools/shot_gear_lab.gd` (+ `tools/gear_art/frames_to_gif.py`).
- **Connection**: a BFS from finished Clocktowers over finished, living Clockwork buildings of the same team; rings link when the gap is within `slack`. Recomputed every 0.5 s (at once when the set of buildings changes). Unlinked buildings stop (`speed_mult` 0, production, repair and mends included) and show UNLINKED.
- **Placement**: a new building's ring must touch the connected field (a Clocktower may go anywhere); overlap deeper than `overlap` tiles is refused (CLASH). The ghost shows its ring and LINKS / NO LINK / CLASH / NEW FIELD.
- **Constructs** wind down off connected gear ground (`Game.in_field`), as they did off the blue field.
- **Winder**: the only worker (speed 74, cost 50, 46 hp, 12 s); builds through the crate, repairs, winds.
- **Cog Press** (placeholder name, `Defs.GEAR_PRESS`): 3x3, replaces the Ore Crusher. Pays cogs a second: a 15% trickle alone, plus an equal share per Winder up to the crew cap. Small gear: higher rate, crew 3. Big gear: crew 6, better only at 5-6 Winders. Max 2 per Clocktower; each Clocktower holds a finite brass reserve (spent: a quarter). Crew assigned by the Crown farm crew logic.
- **Gear swap**: 25 cogs, 4 s, the building idles and the ring visibly grows or shrinks (`Game.swap_gear`, net command `swap_gear`).
- **Cogs**: the resource is renamed in the UI with a code-drawn gear icon, start 300. The battery/energy side of Boilers and Pylons is unchanged.
- **AI**: places presses, assigns Winders, and places buildings so they link; never builds unlinked ones.
- **Saves and online**: gear size and swap state are saved ("gb", "gs", "gst") and in `BLD_PROPS`; the guest recomputes the graph from synced buildings.

- **New-style army (0.14.16)**: the MOVEMENT WORKS (`Defs.CW_WORKS`, 4x3, 150 cogs, the barracks; painted frames, working loop while it trains and is linked, `GEAR.works_dt`) trains the CLOCK SOLDIER (70 cogs, 90 hp, 1 armour, 10 damage / 1.2 s, the blow on frame 4 of the swing: aim 0.33 s; sheets by `tools/import_clock_soldier.py`). The REGULATOR (`Defs.CW_SUPPLY`, 2x2, 100 cogs, +10 supply) replaces the Spring Tower in gear mode (`Defs.supply_kind`); its pendulum swings whenever it is built and linked (`GEAR.regulator_dt`). Art imported by `tools/gear_art/import_buildings.py` (Regulator swing: `tools/gear_art/regulator_swing.py`). The AI in gear mode builds Works and Regulators and trains only Clock Soldiers. Test: `tools/test_cw_army.gd`; screenshots `tools/shot_cw_army.gd`.
- **Floor plate**: every ring's hole holds the bolted iron deck (`GearArt.plate`, resized once per diameter and cached; `GearNet.draw_plate`, under the ring edges, never turned).

## Tuning: `Defs.GEAR`

One commented block: `pitch` (tooth size, px), `pad` (ring padding per small / big / tower), `slack`, `overlap`, `solve` (graph period), `teeth_rate`, `swap_cost`, `swap_time`, `start_cogs`, `press` (`base` trickle; `small` and `big` each with `full` rate and `crew` cap), `spent` (reserve-spent share), `col` (colours).

## Tests

`tools/test_gear_graph`, `_mesh` (mesh rule, idlers), `_press`, `_swap`, `_unlinked`, `_placement`, `_winddown`, `_save`, and `_ai` (args `vs:passive|crown|brood`, `map:`, `seed:`, `minutes:`). Screenshots: `tools/shot_gear.gd` (to /tmp/shots_gear).

## Known gaps

- The Clockwork help text in the main menu (`scripts/main.gd`) still describes ore, crushers and rail vehicles.
- The AI never swaps gears and only uses small gears.
- The Regulator's (and the Spring Tower's) supply is not cut when it is unlinked.
- The plateau is small, so placement is tight; tune `overlap` (0.25 tiles now, about half a tooth) and `slack` (2 tiles).
- Only the parent link of each ring is meshed; two rings that touch without being parent and child can show teeth on teeth.
- The cogs icon, the swap button icon, the idler hub and the ring edge are code-drawn (see `docs/art_style_inconsistency.md`).
- Old saves with ore buildings are not migrated.
- The Winder's win and attack animations and death sheet are not imported.
