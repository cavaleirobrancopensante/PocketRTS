# Expansion spots (0.14.95)

The owner asked, on 2026-10-27: "Make the most optimal expansion spots clear in the maps, so people can easily expand to an area that is interesting for base building." Then: "Just make the map positions clear, focusing on Crown and Clockwork for now. Maybe a few tiles in a different colour in each map showing the best expansion places." Not for the Brood: "for Brood it rarely makes sense to change the capital."

## What is shown

- The best free hall spots are tinted on the ground. A spot is the hall's footprint, 5 by 4 cells. That is where a Town Hall or a Clocktower goes.
- Each cell is a warm gold tile over a light brown wash, with a thin dark and gold border round the spot. It reads on grass, heath, sand and snow.
- Each side gets two spots. Its best spot is a little brighter, with a thicker border. The second is fainter.
- The tiles lie on the ground, under units and buildings. The fog covers them like the rest of the ground.
- A spot hides once a building you know of stands on it: yours, an ally's, or an enemy's you have seen. It shows again if that building is gone. A spot hides too when a fallen hall drew its lode out.
- While you place a Town Hall or a Clocktower, the spots are a touch brighter.
- The minimap shows a small gold square on each spot.
- There are no messages and no tooltips.
- Shown to a Crown or a Clockwork player, and when watching (spectator, replay). Not shown to a Brood player.
- Settings: SHOW EXPANSION SPOTS, on by default. Portuguese: MOSTRAR LOCAIS DE EXPANSÃO. Spanish: MOSTRAR LUGARES DE EXPANSIÓN.
- Cost: the spots are rated once, when the map is made. The tiles are drawn once. They are redrawn only when a spot is taken or freed, or when you start or stop placing a hall. A look for taken spots runs twice a second over a handful of spots.

## How spots are picked

Code: `scripts/expansion_spots.gd`, `ExpansionSpots.rate`. It runs on the bare map, before any building stands.

1. The candidates are the map's base sites (`Game.base_sites`) that are nobody's start. On a named map an empty main counts too.
2. Each candidate belongs to the side whose main is the fewest steps away by land. A tie between enemies belongs to nobody.
3. Each candidate gets a score:
   - Room: the open, buildable cells joined to the spot on its own ground level, within a hall's economy reach (14 tiles). This is the room for the Crown's Farms and Mill, and for the Clockwork's gear field, which meshes only on one level. Worth up to 100 points.
   - Walk: minus one point per step from its own main.
   - Safety: plus half a point per step it is farther from the enemy's main than from its own (capped).
   - Ways in: minus 6 points for each way in after the first. A way in is a gap in the open land 12 tiles round the spot. Minus a little more for a very wide open front.
4. The two best of each side are marked.

Resources: every hall's land holds the same fresh reserve on a new map. So resources do not change the pick at the start. A spot whose lode a fallen hall drew out is hidden.

The maps are turned through their middle, so twin spots get the same score. The test checks this on every map.

## Each map's spots (2 players; walk in steps, ways in)

Classic maps (made anew each match, 2 corners): only the natural is free.
- Greenhold, Dune Sea: the natural, 25 steps, 1 way in, 89% room.
- Highmoor, Frostfang, Ashfall, Red Coast: the natural, 28 steps, 1 way in, 92% room.
- Twin Fords, Mirewood, Border March: the natural, 25 steps, 3 ways in, 82% room.
- With 4 players every classic map marks the corner natural: 16 steps, 2 to 3 ways in, about 63% room.

Named maps (best, then second):
- Ashford Crossing: the natural (28 steps, 2 ways, 91%); then the third along the top (46 steps, 1 way, 95%).
- Kestrel Rise: the natural (17 steps, 3 ways, 68%); then the third at the top (42 steps, 1 way, 70%).
- Thornwood Maze: the natural (20 steps, 6 ways, 73%); then the far third (61 steps, 1 way, 75%).
- Redrock Canyon: the natural (34 steps, 2 ways, 87%); then the third (38 steps, 6 ways, 90%).
- Saltmarsh Isles: the natural (17 steps, 2 ways, 63%); then the third below it (39 steps, 2 ways, 80%).
- Glimmerdeep: the inner third (29 steps, 3 ways, 92%); then the natural (18 steps, 4 ways, 73%).
- Frostmere: the natural (19 steps, 3 ways, 77%); then the third across the field (49 steps, 1 way, 99%).
- Cinder Steps: the natural (17 steps, 3 ways, 63%); then the third (38 steps, 4 ways, 90%).
- Hollowfen: the west third (52 steps, 2 ways, 92%); then the natural (18 steps, 5 ways, 73%). Almost a tie.
- Amberfall Vale: the natural (27 steps, 2 ways, 93%); then the east third (39 steps, 2 ways, 98%).
- Twin Crowns: the natural (19 steps, 3 ways, 72%); then the third along the top (45 steps, 1 way, 83%).
- Jade Wilds: the natural (19 steps, 3 ways, 77%); then the third (51 steps, 1 way, 80%).
- Shattered Coast: the natural (19 steps, 3 ways, 85%); then the third (45 steps, 1 way, 84%).
- Ember Reach: the natural (19 steps, 3 ways, 83%); then the third below it (44 steps, 1 way, 86%).
- Whitecap Pass: the third in its pocket (39 steps, 1 way, 99%); then the natural (19 steps, 3 ways, 72%).
- Kingsfield: the third (44 steps, 1 way, 95%); then the natural (19 steps, 3 ways, 79%). Almost a tie.
- Pinewall Marches: the natural (19 steps, 3 ways, 84%); then the third (46 steps, 1 way, 98%).
- The Sundered Realm: the natural (19 steps, 3 ways, 72%); then the third (46 steps, 3 ways, 95%).

In team games each player gets his own two spots, from the sites nearest his main.

## Unfair or weak sites found

- FIXED: on the classic river maps (Twin Fords, Mirewood, Border March) with 2 players, the fords were not the same on both sides. The river's wiggle is not its own twin, and a ford laid over river already drawn stayed water. One side's natural had 4 more cells of open front and 1% more room. Now every ford cell and its twin are open ford on both sides (`MapGen._rivers`). This makes those fords a little wider.
- Thornwood Maze: the natural has 6 ways in, and the second spot is far (61 steps) and close to the enemy (78 steps). Expanding there is weak. Not changed.
- Redrock Canyon: the third has 6 ways in. Not changed.
- Classic maps with 4 players: the corner natural is cramped (about 63% room) and lies between two corner mains. Not changed.
- Hollowfen and Kingsfield: the natural and a third score almost the same. Both are marked.

## Pictures

`docs/shots/expansion_spots/`:
- `<map>.jpg`: every built-in map, fog lifted, a Crown player against a Clockwork computer.
- `close_crown_<map>.jpg`, `close_clockwork_<map>.jpg`: in game, with the HUD and minimap, for Ashford Crossing, Frostmere and Greenhold.
- `place_crown_<map>.jpg`, `place_clockwork_<map>.jpg`: the same while placing a hall (the spots a touch brighter).

Made by `tools/shot_expansion_spots.gd`. Tested by `tools/test_expansion_spots.gd`.
