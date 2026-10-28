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
- A LABEL on each spot (the owner, 22:09, 0.15.15: the spots must read as such): "OPTIMAL EXPANSION SPOT" on the best, "EXPANSION SPOT" on the second (pt PONTO DE EXPANSÃO IDEAL / PONTO DE EXPANSÃO, es PUNTO DE EXPANSIÓN ÓPTIMO / PUNTO DE EXPANSIÓN), small gold words on a dark pill at the spot's bottom edge. Shown while the camera is at a normal zoom or nearer (0.85 and up) and always while you place a hall or a Mound Turtle; zoomed out it gives way (the gold tiles and minimap squares speak for themselves and the words would clutter). Its size follows the zoom (about 15 px on screen). It is drawn on the game's overlay, as the workers' counts, so it reads on dark maps (ExpansionSpots.draw_labels, from Game._draw_mine_labels). No tooltips.
- Shown to a Crown or a Clockwork player, and when watching (spectator, replay). Not shown to an old-Brood player (it rarely moves its capital).
- THE NEW BROOD (0.15.15; the owner, 21:28 and 22:09) sees its best MOUND TURTLE spots instead (ExpansionSpots.nb_pick): its side's free base sites rated as above, each with the turtle's 3x3 footprint placed in it on level open ground and scored up for the Rootmaw circles that fit round it inside the turtle's swamp (at least 2). Shown: the two best that are fresh ground (no Rootmaw drew half of it out), 15+ tiles from the Mother and from every turtle that already counts as an expansion, with no building or rooted turtle of the side on them. The tint is the turtle's footprint; while placing a Mound Turtle the spots are brighter, each with a faint gold ring for the swamp it would spread, and labelled.
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

Since 0.15.0 every map is bigger and has more base sites (docs/map_sizes.md). The two marked spots of each side:

Classic maps (made anew each match, 2 corners; 4 free sites per side, natural included):
- Greenhold, Dune Sea: the natural below the ramp (22 steps, 2 ways, 81%); then the open ground right of the main (38 steps, 1 way, 99%). The owner's drawing (2026-10-28): the natural moved up to the foot of the ramp, a site in the bottom-left corner and one just right of the bottom-left pond. Those two score lower (the corner is cramped by the pond and the edge, the pond site is far), so they are not marked.
- Highmoor, Frostfang, Ashfall, Red Coast: the natural (23 steps, 2 ways, 83%); then the open ground right of the main (38 steps, 1 way, 91%).
- Twin Fords, Mirewood, Border March: the open ground in front of the main (33 steps, 1 way, 99%); then the natural (22 steps, 2 ways, 81%).
- With 4 players every classic map marks the corner's two sites: the natural by its east ramp (23 steps, 2 ways, 78%) and the open ground below it (35 steps, 1 way, about 95%).

Named maps (best, then second):
- Ashford Crossing: the natural (27 steps, 2 ways, 77%); then the third along the top (54 steps, 1 way, 98%).
- Kestrel Rise: the natural (17 steps, 2 ways, 67%); then the new site in front of the main (38 steps, 2 ways, 95%).
- Thornwood Maze: the natural (20 steps, 3 ways, 74%); then the new site between the pine walls (43 steps, 6 ways, 96%).
- Redrock Canyon: the new natural in front of the ramp (24 steps, 1 way, 97%); then the old natural on the left (36 steps, 1 way, 99%).
- Saltmarsh Isles: the natural (17 steps, 1 way, 63%); then the third on the home island (49 steps, 2 ways, 89%).
- Glimmerdeep: the inner third (44 steps, 2 ways, 98%); then the natural (18 steps, 4 ways, 73%).
- Frostmere: the new site right of the main (45 steps, 1 way, 98%); then the natural (19 steps, 4 ways, 75%).
- Cinder Steps: the new site in front of the main (37 steps, 1 way, 93%); then the natural (17 steps, 2 ways, 65%).
- Hollowfen: the new site along the top (41 steps, 1 way, 99%); then the natural (18 steps, 3 ways, 72%).
- Amberfall Vale: the new natural in front of the ramp (24 steps, 1 way, 96%); then the new site in the top-left (48 steps, 1 way, 99%).
- Twin Crowns: the new site along the top (46 steps, 1 way, 99%); then the natural (19 steps, 2 ways, 70%).
- Jade Wilds: the new site below the natural (43 steps, 2 ways, 98%); then the natural (19 steps, 4 ways, 74%).
- Shattered Coast: the natural (19 steps, 2 ways, 82%); then the third along the top (52 steps, 1 way, 80%).
- Ember Reach: the natural (19 steps, 3 ways, 81%); then the new site below it (49 steps, 1 way, 99%).
- Whitecap Pass: the natural (19 steps, 2 ways, 70%); then the new site along the top (54 steps, 1 way, 99%).
- Kingsfield: the natural (19 steps, 2 ways, 76%); then the new site along the top (47 steps, 1 way, 99%).
- Pinewall Marches: the natural (19 steps, 5 ways, 80%); then the new site below it (47 steps, 4 ways, 97%).
- The Sundered Realm: the new site along the top (43 steps, 1 way, 99%); then the natural (19 steps, 2 ways, 69%).

In team games each player gets his own two spots, from the sites nearest his main.

## Unfair or weak sites found

- FIXED: on the classic river maps (Twin Fords, Mirewood, Border March) with 2 players, the fords were not the same on both sides. The river's wiggle is not its own twin, and a ford laid over river already drawn stayed water. One side's natural had 4 more cells of open front and 1% more room. Now every ford cell and its twin are open ford on both sides (`MapGen._rivers`). This makes those fords a little wider.
- Thornwood Maze: the natural has 6 ways in, and the second spot is far (61 steps) and close to the enemy (78 steps). Expanding there is weak. Not changed.
- Redrock Canyon: the third has 6 ways in. Not changed.
- Classic maps with 4 players: the corner natural was cramped (about 63% room). On the bigger maps (0.15.0) it has 78%.
- Hollowfen and Kingsfield: the natural and a third score almost the same. Both are marked.

## Pictures

`docs/shots/expansion_spots/`:
- `<map>.jpg`: every built-in map, fog lifted, a Crown player against a Clockwork computer (re-made for the bigger maps of 0.15.0; the old ones are in docs/shots/map_sizes/, side by side with the new).
- `close_crown_<map>.jpg`, `close_clockwork_<map>.jpg`: in game, with the HUD and minimap, for Ashford Crossing, Frostmere and Greenhold.
- `place_crown_<map>.jpg`, `place_clockwork_<map>.jpg`: the same while placing a hall (the spots a touch brighter).
- The labels (0.15.15): `docs/shots/brood_fixes_2/spots_crown_label.png`, `spots_crown_placing.png`, `spots_crown_far.png` (zoomed out: no words), `spots_clockwork_label.png`, and the new Brood's `spots_new_brood.png`, `spots_new_brood_placing.png`, `spots_new_brood_far.png` (tools/shot_expansion_spots.gd now also writes `label_<faction>_<map>.png`; the new Brood's from tools/shot_brood_structures.gd fixes2).

Made by `tools/shot_expansion_spots.gd`. Tested by `tools/test_expansion_spots.gd`.
