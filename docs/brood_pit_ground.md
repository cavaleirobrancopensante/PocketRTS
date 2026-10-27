# Brood pit ground: a circle of ground for every Feeding Pit

Version 0.14.41, branch brood-pit-ground. This is the owner's decision of 27 October 2026, built as decided.

## The rule

Every Feeding Pit now has its own ground: 3,000 biomass. Each load a grub hauls from the pit is taken out of that pit's ground, and when it is spent the pit yields nothing. The grubs then leave it and look for a pit that still has ground.

The Burrows have no ground any more, the capital included. The capital is still the only place grubs unload, and the Queen's seat. When the capital falls, the next oldest Burrow takes over as before, but there is no ground to pass on: each pit keeps its own.

Each pit claims a circle of ground 5 tiles round its centre. Two of your living pits' circles may not overlap, so their centres stay at least 10 tiles apart. A planned pit that a grub has not reached yet already counts. Only your own pits count: an enemy Brood's pits do not block you.

The ground belongs to the land. When a pit dies, its circle stays behind as a dim "old ground" spot holding whatever was left. A new pit whose circle overlaps old spots takes over the smallest amount left among them, and those spots merge into its claim. So rebuilding next to a spent pit gives you a spent pit, and the only way to fresh ground is fresh land.

One more grub per pit: the base crew is 6, up from 5. A pit still takes one more grub for every 4 tiles beyond 6 from the capital, up to 12.

## The numbers

| What | Value | Where in the code |
|---|---|---|
| Ground in each pit | 3,000 biomass | Defs.PIT_GROUND |
| Radius of a pit's circle | 5 tiles (centres 10 apart) | Defs.PIT_CLAIM |
| Base crew of a pit | 6 grubs | feeding_pit "crew" in Defs.BUILDINGS |
| Crew growth | +1 per 4 tiles beyond 6, up to 12 | Defs.PIT_CREW_STEP, PIT_CREW_MAX |
| Low ground warning | under 25%, per pit | Defs.SOIL_LOW |

A pit with a full crew of six draws roughly 200 to 260 biomass a minute, so a well worked pit lasts about 12 to 15 minutes.

## What the player sees

While placing a Feeding Pit, the map shows the circle of every pit of yours, in a soft green that turns grey-brown as its ground runs out, with its ground in percent on the circle's top edge. Old ground spots show as dashed, dimmer circles, labelled "Old ground" with what is left, or "spent". The ghost has its own circle: green where it fits, red where it would overlap, and the pit it clashes with turns red too. Under the ghost's circle a label says what the pit would get: fresh ground, old ground with so much left, or spent old ground. A refused spot says why on the PLACE button: "Too close to another Feeding Pit: their grounds would overlap."

A selected pit shows its circle and "Ground: %" on the map, and its card reads "Ground: 71% (2134 biomass) · each load is worth 3.1". The Burrow's card no longer has a ground line. Each pit warns by itself when its ground runs low and when it is spent.

Enemy old ground only shows where you have looked. Rings are thin and the fill is faint, drawn flat on the ground under the buildings.

Screenshots are in docs/shots/brood-pit-ground: place_free.png (a free spot, green), place_refused.png (an overlapping spot, red) and selected.png (a selected pit and its card).

## How many pits fit in a main base

Measured on every 1v1 map with tools/measure_pit_room.gd: the starting pit stays where it is, and pits are packed on the capital's plateau, farthest first, under the circle rule.

| Map | Pits on the main plateau |
|---|---|
| Ashford Crossing, Thornwood Maze, Redrock Canyon, Saltmarsh Isles, Glimmerdeep, Frostmere, Cinder Steps, Hollowfen, Amberfall Vale | 4 |
| Kestrel Rise | 3 |
| The nine classic maps (Greenhold, Highmoor, Dune Sea, Frostfang, Twin Fords, Ashfall, Mirewood, Border March, Red Coast) | 5 |

So a main holds 4 or 5 pits, as intended, except Kestrel Rise, where it holds 3. Before the change about 20 fitted. The farthest pit on a main plateau stands 10 to 12 tiles from the capital, so the richest distance, 18 to 22 tiles, is always off the plateau, out on the swamp.

## Before and after

Headless games with tools/measure_brood_ground.gd: a Hard Balanced Brood computer against a Hard Balanced Crown or Clockwork computer, on Greenhold and Ashford Crossing, 20 minutes, both computers peaceful (they build their full economy and army but never attack), so the economies can be compared to the end.

Total biomass earned by the Brood:

| Game | Before, 10 / 15 / 20 min | After, 10 / 15 / 20 min |
|---|---|---|
| Greenhold vs Crown | 5,048 / 10,468 / 10,502 | 4,961 / 10,013 / 15,291 |
| Greenhold vs Clockwork | 4,925 / 9,632 / 10,500 | 5,144 / 10,352 / 16,441 |
| Ashford vs Crown | 5,798 / 10,500 / 10,500 | 6,169 / 11,353 / 17,953 |
| Ashford vs Clockwork | 5,679 / 10,501 / 10,501 | 5,748 / 11,968 / 18,598 |

Biomass income per minute, averaged over the 20 minutes, and the rate in the last minute:

| Game | Before: average, minute 20 | After: average, minute 20 |
|---|---|---|
| Greenhold vs Crown | 525, 0 | 764, 1,085 |
| Greenhold vs Clockwork | 525, 0 | 822, 1,343 |
| Ashford vs Crown | 525, 0 | 897, 1,433 |
| Ashford vs Clockwork | 525, 0 | 929, 1,436 |

The first ten minutes barely change: the main's pits are fresh either way, so the early game and the rush timings stay where they were. The big change comes after that. Before, the capital's 10,500 was the whole match's ground: it ran dry at about 14 to 15 minutes and the Brood earned nothing more, ever. Now the Brood keeps earning by planting new pits on fresh swamp, about 1,100 to 1,400 a minute at 20 minutes.

Pits, how long they lasted and how far out they stood:

| Game | Before: pits, median life, median / farthest distance | After: pits (spent by 20 min), median life, median / farthest distance |
|---|---|---|
| Greenhold vs Crown | 6, 742 s, 13.8 / 21.5 tiles | 8 (3), 906 s, 16.7 / 34.0 tiles |
| Greenhold vs Clockwork | 5, 787 s, 12.5 / 21.5 tiles | 8 (3), 928 s, 16.7 / 23.3 tiles |
| Ashford vs Crown | 5, 580 s, 16.0 / 21.9 tiles | 9 (4), 833 s, 16.0 / 33.7 tiles |
| Ashford vs Clockwork | 5, 593 s, 16.0 / 21.9 tiles | 9 (4), 837 s, 16.0 / 32.0 tiles |

"Life" is from the pit being finished to its ground being spent. Before, every pit died with the capital's ground at the same moment; now each pit runs out on its own, after about 14 to 15 minutes. The computer keeps 2 or 3 pits on its main plateau and puts the rest out on the swamp, up to 34 tiles from the capital, which also leaves them more exposed.

The opponents, for comparison (their totals at 10 / 15 / 20 minutes, after the change): the Crown 4,560 / 10,900 / 17,740 on Greenhold and 3,800 / 9,500 / 16,220 on Ashford; the Clockwork 9,835 / 17,741 / 22,703 on Greenhold and 9,719 / 17,971 / 25,754 on Ashford. Before the change they were in the same range (the Crown 18,880 and 18,760 by 20 minutes, the Clockwork 23,304 and 27,612), so the Brood now ends close to the Crown and below the Clockwork, where before it stopped at 10,500.

Two real games (attacks on, Greenhold) were also run. Before the change the Brood computer lost both, at 6 and 9 minutes. After it lost to the Clockwork at 10 minutes and was still alive against the Crown at 20 minutes, with 12,913 biomass against the Crown's 13,560. That is too few games to say much: the Brood computer's early defence is the other session's job, on branch wt-brood-ai.

## The computer

Inside the Brood pit placement only: its pit spots obey the circles, never take spent old ground, rank tired old ground lower than fresh ground, and once the richest stretch out to 22 tiles is taken it plants pits farther, as far as its swamp reaches. A pit whose ground is spent no longer counts as room, so the computer builds a new one to replace it, and its grubs move off spent pits to fresh ones.

## Online and saves

Each pit's ground travels in the building sync as the soil did, and the old ground spots go in the snapshot whenever they change. Saves keep each pit's ground and the old spots. A save from before this version gives its pits fresh ground.

## Tests

- tools/test_brood_pit_ground.gd, new: two pits draw separately, real grubs draw a pit's own ground, a spent pit pays nothing, overlapping circles are refused with the message (with pt and es), exactly 10 tiles apart is allowed, a planned pit counts, a cancelled plan leaves no old ground, a pit rebuilt over old ground takes over what was left, over two spots it takes the smaller, the spots merge, a spent spot can't be refreshed, save and load keep it all, and the computer's spots obey the circles and avoid spent ground. All pass.
- tools/test_brood_capital.gd, updated for the new rule (crew 6, no ground in the Burrows, nothing passes on when the capital falls). Its Clutch Mound step failed on main already (it looked for a mound spot in too narrow a ring); it now tries the outermost swamp cells first and passes.
- test_brood_hall, test_brood_plateau_swamp, test_brood_voices, test_ai_brood_army, test_ai_brood_horse and test_i18n pass. test_brood_fixes was skipped: it already fails on main because it places a retired spring_tower.

## What you may want to tune

- How long a pit lasts: PIT_GROUND. 3,000 gives 14 to 15 minutes per pit; 2,000 would make the Brood move out after about 9 or 10.
- How many pits a main holds: PIT_CLAIM. At 5 tiles it is 4 or 5, and 3 on Kestrel Rise. At 4.5 tiles (centres 9 apart) most mains would hold 5 or 6.
- The late game: the Brood now earns 1,100 to 1,400 a minute at 20 minutes in a peaceful game, close to the Crown, but only by spreading far out on swamp that an enemy can raid. If that feels too strong, a smaller PIT_GROUND for pits beyond 22 tiles, or fewer grubs on far pits, would be a quiet brake.
- The crew of 6 adds about a fifth to every pit's rate, so the main's pits also run dry a little sooner than before.
