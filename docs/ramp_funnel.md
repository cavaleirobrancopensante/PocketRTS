# Ramp funnel

The owner's report, 28 October 2026: a Great Winder stood just beside the top of a ramp, drawn over the cliff wall, so it looked as if it floated. He wanted the ramp to be the only way between the high ground and the low ground.

It took four versions:
- 0.15.2 raised the ground beside the ramp's top rows into cliff. He didn't want extra tiles.
- 0.15.3 put the map back as in 0.15.1, blocked the cells beside the ramp's top with an invisible block, and drew the ramp more clearly.
- About the 0.15.3 pictures he said: "Why are you still advancing a tile or retreating a tile? Make it the normal tile." And: "The block shouldn't be invisible; it should be clear that you can't walk onto that tile from the side, just straight on."
- He then approved a drawn spec: docs/shots/ramp_funnel/owner_spec.png. That is 0.15.4.

## The owner's spec

1. The cliff edge runs straight at its normal row, right up to both sides of the ramp. No tile sticks out, no tile is pulled back, no extra tiles anywhere.
2. The ramp is exactly as wide as its planks. Its planks, length and place don't change.
3. Units get onto the ramp only straight on, at its top end or its bottom end. They may also step onto its bottom tile from the left or the right.
4. Every other ramp tile is closed from the sides, from the low ground and from the high ground.
5. The closed sides are visible: a low wall runs along both sides of the ramp, from the cliff down to the bottom tile. The bottom tile has no wall.

## Cause

The map maker cut every ramp into a notch in the plateau's edge (MapGen._ramp). It made the edge five cells wide and straight. The three middle cells became the planks. The two outer cells were forced to low ground, whatever the plateau did on either side.

Where the plateau beside the ramp reached as far down as the ramp's top, that left a pulled-back tile: the cliff stepped back up beside the planks, and a low cell sat in a pocket under the wall. That's where the Great Winder seemed to float.

## The fix in 0.15.4

1. **A straight edge.** MapGen._ramp now cuts out exactly the planks' width. Beside each row of the ramp, the cell next to the planks takes the height of the cell past it. So the plateau's edge runs on at its own row, right up to both sides of the ramp. On Greenhold's south ramp, the owner's case, the wall now runs straight along the ramp's top row, as in his drawing.
   - Each ramp keeps exactly the same cells: the same planks, the same length, the same place.
   - The two rows of high ground above the ramp, where its lanes arrive, stay as before.
   - This holds on every built-in and generated map, in all four directions. A map made in the editor keeps the ground its maker painted.
2. **Rails.** A low stone kerb runs down both sides of every ramp, from its top row to the row above its bottom one (MapGen.ramp_rails, drawn by scripts/ramp_rails.gd). No unit can cross it. The bottom row has no rail, so a unit can step onto it from either side.
   - The rail is an edge between two cells, not a blocked cell. The ground beside the ramp stays normal ground: it is just the foot of the cliff. Units can walk and stand there, and build there.
   - The pathfinder keeps to it. The cells across a rail from the ramp are shut in its grids (Game.rail_side). A path that starts or ends on one of them starts or ends at the nearest open cell, and walks the last step (Game.path_cell).
   - Movement keeps to it. Every step a unit takes goes through Game.rail_fix: a unit can't cross a rail, and its middle keeps at least its own half-width from it. That covers walking, separation, pushing, knockback, gear rides and limbered guns. Diagonal steps can't cut round a rail's end.
   - The path smoothing keeps to it (line_clear). A straight stretch of path keeps a few pixels more from a rail than the unit itself does, so a unit never presses on a rail. Without that, a unit at the bottom row could slide up the inside of a rail and stay there: test_pathing caught it.
   - The group walk fills keep to it too (Game._walk_fill, Game.rail_cut).
   - A unit that an old save or replay has standing on a rail is pushed off, on the side its middle is on, as soon as it moves.
   - This works on every map: built-in, generated, custom and the map editor. The rails are worked out whenever the walk grid is built (Game._setup_astar).
3. **The invisible block of 0.15.3 is gone.** Nothing beside a ramp is blocked any more.
4. **The ramp art.** The 0.15.3 plank contrast and the shadow line across the top stay. The painted kerb on the planks is left off the bottom row, so it looks open. The rails are code drawing, logged in docs/art_style_inconsistency.md.

The computer's ramp wall keeps its rule: three pieces and a gate past the ramp's top. test_ai_wall_vs_rush shows it still closes the ramp.

## Two-wide ramps

The ramps up the middle hills of some maps are two planks wide, not three. That's two ramps each on Greenhold, Dune Sea, Kestrel Rise, Twin Crowns and Kingsfield, and, with four players, on Highmoor, Frostfang, Ashfall and Red Coast. The spec says three, but also that the planks don't change. They were left as they were, and the test notes them. Ask the owner if he wants them widened.

## Pictures

docs/shots/ramp_funnel/ holds ramp_south.jpg (the owner's case), ramp_north.jpg, ramp_east.jpg and ramp_west.jpg. Each puts four pictures side by side:
- the owner's spec,
- the game in 0.15.3,
- the game now,
- the game now with the cells that can't be walked on in red, the rails in yellow, and the units' paths in green.

In each, Clockwork units are on the move:
- one walks up from below the foot, straight on at the bottom end;
- one comes from beside the bottom row, steps onto it from the side, and walks up;
- two Clock Soldiers and a Great Winder stand beside the closed rows. Their way was forced straight at the ramp beside them. The rails stop them.

The old 0.15.3 sheets are kept as ramp_<direction>_0153.jpg.

The pictures are made with tools/shot_ramp_funnel.gd, then put together with tools/ramp_funnel_sheet.py. Add "before=1" for the old notch with no rails, and "grid=1" for the red cells and yellow rails.

## Tests

tools/test_ramp_funnel.gd checks every ramp of every built-in map, with 2 players and with the most each map holds:
- the edge is straight beside every row: the cell next to the planks is as high as the one past it;
- the map differs from the old notch only in those cells, and the ramps are the same cells;
- every top lane opens onto the high ground, and the foot opens onto the low ground;
- a path runs from the landing to the foot in every lane, both ways, over the planks;
- a rail lies between every ramp cell and its side neighbour, but not beside the bottom row;
- from beside the bottom row, a path steps straight onto it;
- from beside every other row, paths onto the ramp and off it go round an end and never cross a rail;
- the walk fill doesn't step across a rail, a step at a rail stops on its own side, and a unit standing on a rail is pushed off;
- on Greenhold, units really walk: Clock Soldiers from beside a closed row to the ramp, from beside the bottom row onto it, and a Great Winder. None crosses a rail or stands on one, and each gets there in time.

With the old notch and no rails ("before"), Greenhold alone fails 342 times. Now every map passes.

test_terrain_same was recorded again, because the heights beside the ramps changed.
