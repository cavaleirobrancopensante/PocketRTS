# Ramp funnel

The owner's report, 28 October 2026: a Great Winder stood just beside the top of a ramp, drawn over the cliff wall, so it looked as if it floated. He wanted the ramp to be a funnel, the only way between the high ground and the low ground.

His final word, after seeing 0.15.2: "It is an invisible block, but the ramp itself is drawn with more visual clarity. No extra tiles." That is 0.15.3.

## Cause

Every ramp is cut into a notch in the plateau's edge. The map maker (MapGen._ramp) makes the edge five cells wide. The three middle cells become the ramp's planks. The two outer cells are left as plain low ground beside the planks, right under the drawn cliff wall, or against its end. A unit could walk or stand there. Its picture then covered the wall, and it seemed to hover beside the ramp.

## What 0.15.2 did, and why it was dropped

0.15.2 raised the ground beside the ramp's top two rows into the plateau. The cliff wall then stepped down beside the planks. The owner didn't want extra tiles, so 0.15.3 takes that back. The map is drawn exactly as in 0.15.1 again: the same heights, cliffs, walls, ramps, trees and decorations.

## The fix in 0.15.3

1. An invisible block. MapGen.block_ramp_sides runs when the walk grid is built (Game._setup_astar), so it covers built-in, generated and custom maps and the map editor. Beside each ramp's top two rows, the low-ground cell under or against the drawn wall can't be walked on or built on. It is still drawn as grass, as before. High ground touching a ramp's side can't be walked on either. Only the walk and build grid changes. The ramp keeps its normal width of three lanes, and units on it go straight up and down the planks.
2. The ramp drawn more clearly, on its own cells only (Game._paint_ramps). The planks are a little darker and their steps more marked. A stone kerb runs down both sides the whole way: a dark outer line, a lit strip of stone, and a dark inner line. The walls' shadow falls on the planks beside the kerbs, deepest at the top. A shadow line runs across the top, where the planks leave the high ground. So the eye sees a narrow ramp with walls on both sides. This is code drawing, logged in docs/art_style_inconsistency.md.

The computer's ramp wall is back to its 0.15.1 rule. The blocked cells don't count as free ground, so the wall still covers the three cells past the ramp's top, and the gate still lets its army out.

A unit that an old save or replay had standing on a blocked cell is pushed to the nearest free cell (Game.resolve_terrain) as soon as it moves.

The Amberfall Vale fix of 0.15.2 opened a third lane at the top of two ramps by raising ground, so it added tiles, and it is gone. It isn't needed any more: on the bigger maps of 0.15.0, every top lane of every ramp opens onto the high ground, Amberfall Vale's too. The test would note it if one didn't.

## Pictures

docs/shots/ramp_funnel/ holds ramp_south.jpg (the owner's case), ramp_north.jpg, ramp_east.jpg and ramp_west.jpg, all on Greenhold. Each picture has three columns: 0.15.1, then 0.15.2, then the new 0.15.3. The top row is the game as it looks. The bottom row shades in red the cells that can't be walked on: cliffs, and in 0.15.3 the blocked cells beside the ramp's top. Clockwork units were ordered onto the cells beside the ramp's top: a Great Winder and Clock Soldiers from the low ground, and Clock Soldiers from the high ground. In 0.15.1 the Winder stands on the cell under the wall. In 0.15.3 nothing stands there, the walls are as they were, and the ramp has its kerbs. A big machine like the Winder is wider in its picture than on the ground, so standing at the foot of a blocked cell, it can still overlap that cell's grass.

The pictures are made with tools/shot_ramp_funnel.gd. Add "before=1" for no blocked cells, and "grid=1" for the red cells.

## Tests

- tools/test_ramp_funnel.gd checks every ramp of every built-in map, with 2 players and with the most each map holds:
  - the cells under the wall beside the top two rows can't be walked on or built on;
  - no high ground beside any ramp can be walked on;
  - the top opens onto the high ground and the foot onto the low ground;
  - there's a walk from the top to the foot;
  - with 2 players, the map is drawn exactly as without the block. Only the blocked cells differ.
- Without the block ("before"), Greenhold alone fails 28 times. With it, every map passes.
- test_terrain_same was recorded again, because the walk grid changed. The lobby map pictures, made again, are byte for byte those of 0.15.1.
