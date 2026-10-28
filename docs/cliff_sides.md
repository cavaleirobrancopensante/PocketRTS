# East and west cliff walls (0.15.5)

The owner, 2026-10-28, after clean pictures of Greenhold's sideways ramps: cliff walls were drawn only on edges that face south. An edge of high ground facing east or west was only a thin dark line, so a sideways ramp seemed to lead onto flat ground. He said yes to giving east and west edges a visible side wall.

## What it looks like now

Every east or west edge of high ground now has a narrow side wall, 10 pixels wide, about a third of a tile. It is cut from the same rock as the south walls of that biome, the same picture turned on its side: the high ground's light lip on its inner side, then the rock, then a dark foot line where it meets the low ground.

The light comes from the upper left. A west-facing wall is a little lit. An east-facing wall is in shadow, and it casts a slightly deeper, wider shadow on the low ground to its east (13 pixels instead of 9).

Corners:
- Where a side wall comes down onto a south wall, the side wall carries on over the south wall's top lip, so the corner of the plateau reads as one block of rock.
- Where a side wall meets a north edge, the north edge's dark line and lip close its top.
- Beside a sideways ramp, the side wall runs down to the ramp's stone rail and stops there. A side that opens onto the ramp itself gets no wall, as before.

North edges keep their thin dark line and lit lip, which already looked right: the camera can't see a north face.

## Units at the foot

The side wall is drawn inside the cliff's ring cell, which is solid: no unit ever stands there. A unit at the foot of an east or west edge stands on the next cell, right against the foot line, in the wall's shadow. In the pictures it reads as standing on the ground, not floating, so the width stayed at 10 pixels.

## Purely visual

Nothing else changed: heights, the walk grid, what can be built, the tiles and the map layouts are the same (test_terrain_same passes without re-recording). The wall is baked into the ground pictures once, when a map is drawn, like the south walls: no cost while playing. Painting the cliffs takes the same few milliseconds as before (Greenhold 3 ms, The Sundered Realm about 24 ms against 22).

It works on every map and biome and in the map editor, which draws its ground the same way.

## The 2-wide ramps

The owner, on the 2-wide ramps of the middle hills: "I don't know, it depends on the map." They are left as they are. These maps have them (tools/test_ramp_funnel.gd prints them):
- Greenhold and Dune Sea, 2 and 4 players: the middle hill's east and west ramps.
- Highmoor, Frostfang, Ashfall and Red Coast, 4 players only: the middle hill's north and south ramps.
- Kestrel Rise: the middle hill's east and west ramps.
- Twin Crowns, 2 and 4 players: the middle's east and west ramps.
- Kingsfield, 2 and 6 players: the middle's east and west ramps.

## Pictures

In docs/shots/cliff_sides/. Each one is before on the left, after on the right.
- Sideways ramps, empty, zoom 1.5: greenhold_ramp_east, greenhold_ramp_west, dune_sea_ramp_east (desert), hollowfen_ramp_west (bog).
- Close-ups at zoom 3, after only: greenhold_ramp_east_zoom3, greenhold_ramp_west_zoom3.
- Whole plateaus, all four edges: greenhold (grass), frostfang (snow), ashfall (volcanic), highmoor (autumn), glimmerdeep (glowwood).
- Two Musketeers at the foot, zoom 3: greenhold_foot_east, greenhold_foot_west, frostfang_foot_east, dune_sea_foot_west.
- The map editor: map_editor.

To take them again: tools/shot_cliff_sides.gd (tag=before or after, maps=, units=1 for the foot pictures, rz= for the ramps' zoom).

## Code

scripts/cliff_art.gd: _side_wall makes the pieces (6 of each side per biome), paint draws them. Logged in docs/art_style_inconsistency.md.
