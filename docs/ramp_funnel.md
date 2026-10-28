# Ramp funnel

The owner's report, 28 October 2026: a Great Winder stood just beside the top of a ramp, drawn over the cliff wall, so it looked as if it floated. He wanted the first rows beside a ramp to be a funnel, so that the only way between the high ground and the low ground is the ramp itself.

## Cause

Every ramp is cut into a notch in the plateau's edge. The map maker (MapGen._ramp) makes the edge five cells wide: the three middle cells become the ramp's planks, and the two outer cells are left as plain low ground, all the way down beside the ramp.

The wall art is drawn on the plateau's last row. So on the ramp's top rows, the low ground beside the planks sits right under the drawn wall. A unit could walk there, from the low ground or by stepping sideways off the planks. Its picture then covered the wall and it seemed to hover beside the ramp. A ramp in effect had a mouth five cells wide at the top, not three.

The new check found this beside every ramp on all 27 built-in maps, on ramps going down to the south, north, east and west.

## Fix

The fix is in the terrain rules, in MapGen._ramp_funnels, which runs at the start of MapGen._cliffs. So it holds on every built-in map, every generated map, custom maps and the map editor. No map layout was edited by hand.

1. Beside each ramp's top two rows (MapGen.FUNNEL), the ground on both sides is raised into the plateau and becomes cliff: solid, never walked, never built on. The cliff wall now steps down beside the planks and stops two rows down the slope. Units on the low ground stop at its foot.
2. Any high ground left touching the side of a ramp lower down is cliff too, so nobody can step onto a ramp sideways from the plateau.
3. The landing: the high-ground cell past each lane of the ramp's top is open ground. On Amberfall Vale, a slanted plateau edge had turned one of these into a cliff, so two ramps were only two lanes wide at the top. That low ground is now raised, and both ramps are three lanes wide all the way up.

So a ramp's walkable width is now exactly its drawn planks, from the top row to the foot.

The computer's ramp wall (AI._wall_off and AI._ramp_bands) now covers only the high cells that touch the ramp side by side. A cell that touches it only at a corner can't step onto it, because the cells in between are wall or cliff. So the wall still costs three pieces, as before.

A unit that an old save or replay had standing on one of the new cliff cells is pushed out to the nearest free cell (Game.resolve_terrain) as soon as it moves.

## Pictures

docs/shots/ramp_funnel/: one picture for each direction of ramp on Greenhold. The brown patches near the north ramp are the Brood's swamp. Each picture has four panels: before on the left, after on the right, and on the bottom row the same scene with the cells that can't be walked on shaded red. Clockwork units were ordered onto the cells beside the ramp's top: a Great Winder and Clock Soldiers from the low ground, and Clock Soldiers from the high ground.

- ramp_south.jpg: the owner's case. Before, the Great Winder stands on the cell under the wall, right of the planks. After, the wall steps down beside the ramp and the Winder stops on the planks.
- ramp_north.jpg, ramp_east.jpg, ramp_west.jpg: the same at the other three kinds of ramp.

The pictures are made with tools/shot_ramp_funnel.gd. Add "before=1" for the old open sides and "grid=1" for the red cells.

## Tests

- tools/test_ramp_funnel.gd checks every ramp of every built-in map, with 2 players and with the most players the map holds. Nothing beside a funnel row can be walked on, no high ground beside any ramp row can be walked on, the top opens onto high ground as wide as the planks, the foot opens onto low ground, and there's a walk from the top to the foot. Before the fix it failed 954 times. Now it passes. Counting each map's 2-player and full layouts, it checks 62 ramps going south, 62 going north, 57 going east and 57 going west.
- These still pass, on the bigger maps of 0.15.0: test_start_layout, test_expansion_spots, test_pathing, test_ai_placement, test_ai_wall_vs_rush (the wall is built with a gate), test_ai_army_response, test_gear_rules, test_cliff_horse, test_replay and test_files.
- test_pathing_match, a six-minute Crown against Clockwork game on Greenhold: units were stuck for 1.6% of their moving time, none of it at a cliff, and no unit was stuck for 10 seconds or more.
- test_terrain_same pins each map's ground. Its hashes were recorded again, because the ground beside the ramps changed on purpose.
- The lobby's map pictures (assets/maps) were made again.

## Left as it is

A big machine is wider in its picture than on the ground. A Great Winder standing on the edge of a ramp's planks still hangs a little over the wall beside it. Its feet stay on the planks.
