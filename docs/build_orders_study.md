# Build orders: what each faction can open with

A study of Holdfast v0.14.27, 26 October 2026. The owner's question: what build orders does each faction have? He wants variety: at least three distinct openings that work for each faction, and four would be very healthy.

This is a study only. It changes no gameplay or balance code; the tools it adds live in tools/study and do not change how the game plays.

SUMMARY_SECTION

## How this was measured

Three tools were written for this study. They live in tools/study.

- **A timing calculator** (tools/study/bo_calc.py). Give it a build order and it plays the opening out second by second: when each step is placed and finished, the army at minutes 3, 4, 5 and 6, and when the attack reaches the enemy's ramp and hall on each standard map. Its numbers are read from the game itself (tools/study/bo_dump.gd writes them out, tools/study/bo_data.py turns them into tools/study/bo_data.json), and a few walking and hand-over times were fitted to real matches. It also takes "what if" changes, for example `--set units.spitter.cost2=0`, which is how the recommendations below were sized, and `--preset econ28`, which plays the Clockwork's economy as it is being rebuilt in the wt-econ branch.
- **A scripted player** (tools/study/bo_ai.gd). It is the game's own Hard computer, but it follows a written build order step by step, then plays on as the ordinary computer. Its workers, its defence at home, its fighting and its micro are the computer's own; only the build and the first attack are scripted. The build orders are in tools/study/build_orders.json, the same file the calculator reads.
- **A match runner** (tools/study/bo_match.gd, bo_run.py and bo_report.py). One headless match at a time; each writes what happened when.

Every opening was played in three ways:
1. against a sleeping opponent, to time it (Ashford Crossing, a middle-sized map);
2. against the ordinary Hard computer, on its Balanced plan, of both other factions, on Kestrel Rise, the smallest standard map;
3. against other openings, where a direct answer was needed (a rush against a greedy build, and so on), and a few again on Frostmere, a big map, where the walk matters.

Read the match results as indications, not proof. Both sides are played by the computer, which defends and fights the way it does; there is one game per pairing; and the machine was shared with several other jobs, so the list of matches was kept short. The timings, on the other hand, are solid: the calculator and the game agree on them (the last section shows by how much).

Two parts of the game were being changed in other branches while this was written, and both are marked as provisional where they matter:
- **The Brood's computer player** is being fixed (the wt-brood-ai branch: essence without corpses, supply on time, no attacks into a stronger army, a real rush). Every match against the Brood computer below was played with the old one, which is known to be weak.
- **The Clockwork's economy** is being rebuilt (the wt-econ branch, its 0.14.28: Tension prices on buildings, an efficiency for every building, neighbour rules, and a Cog Press that needs twice the Winders for the same cogs). The Clockwork openings below are timed both ways: on the game as it is, and with the calculator's econ28 preset for the rebuilt economy.

## The three economies

| | Crown | Brood | Clockwork |
|---|---|---|---|
| Start | 300 gold, 4 Labourers, a Farm already 60% grown, the Town Hall (10 supply) | 250 biomass, 5 grubs, a Feeding Pit, the Burrow (16 supply, 5 eggs) | 300 cogs, 4 Winders, a Cog Press, the Clocktower (10 supply) |
| How the money comes | A Farm ripens into a 380-gold harvest: every 40 seconds with 8 Labourers, every 70 with 4, every 267 with nobody. So it comes in lumps. A Mill hand grinds a third of a powder a second | Each grub earns about 0.58 biomass a second on the starting pit, about 0.62 on pits farther out | A Cog Press pays 1.2 cogs a second by itself and 2.3 more for each Winder on it, up to 3: 8 a second with a full crew. A Mainspring winds 0.3 Tension a second alone, 2 with 3 Winders |
| Per worker, roughly | 1 gold a second (60 a minute) | 0.6 biomass a second (35 a minute) | 2.3 cogs a second (136 a minute); with the wt-econ rebuild, 1.1 |
| The second resource | Powder, from the Powder Mill (up to 6 hands, 2 a second): steady from the first minute | Essence, only from bodies (3 a supply for a body that falls near a Brood Pen, 1.25 for one a grub carries home) or from SACRIFICE (12% of a creature's price, 3 for a Raptor). No building makes it | Tension, from Mainsprings (3 hands, 2 a second each, and there is no limit on Mainsprings): steady once one stands |
| ECONOMY_ROWS
| Making the army | One unit at a time per Barracks or Foundry (a Musketeer takes 15 seconds) | Eggs: each Burrow lays one every 9 seconds (10% faster for each Clutch Mound, up to 3) and holds 5; every unit, grubs included, takes an egg, and the eggs hatch side by side | One unit at a time per Movement Works (a Clock Soldier takes 16 seconds) |
| The land runs out | 9,000 gold of soil per Town Hall; a new hall brings fresh soil | 10,500 biomass of ground at the capital, for the whole game: other Burrows have no ground | 11,400 brass per Clocktower; spent brass still pays a quarter, forever |

Three things in this table shape every opening.

First, the Clockwork's money. On the game as it is, a Winder on a Cog Press earns more than twice what a Labourer earns on a Farm, and a press is full with only three Winders. So the Clockwork has more to spend than the other two from the first minute, and most of its openings are limited by how fast its buildings can make units, not by money. The wt-econ rebuild halves a Winder's share, which brings it to about a Labourer's. Everything said below about the Clockwork's strength must be read with that in mind.

Second, the Brood's essence. The Crown's powder and the Clockwork's Tension each come from a building the player can put up in the first two minutes. The Brood has no such building: essence comes from the dead. Before the first fight, the only essence is offering up its own creatures at the Brood Pen, at 12% of their price. A Brute's 20 essence costs 7 Raptors offered up (175 biomass, more than the Brute's own price), a Bloater's 25 costs 9 (225 biomass, for a 50-biomass unit), a Skywing's 40 costs 14 (350 biomass). So every Brood opening that is not Raptors pays a heavy tax, and this is the main reason the Brood has few openings (see the gaps below).

Third, the Crown's lumps. A farm pays nothing for 40 to 70 seconds and then 380 at once. The Crown's openings are timed around the harvests: a step that misses a harvest waits for the next one.

### How long the walk is

The table gives the walking distance from a side's rally point to the enemy's Town Hall, Burrow or Clocktower on each standard map, and the time it takes. The distances were measured with the game's own pathfinder. A Clockwork soldier slows down as it walks away from its gear field (to three quarters of its speed when it is empty) and stops dead when its wind is gone, about 83 seconds after it leaves the field; the column shows how much wind a Clock Soldier still has when it arrives. (`python3 tools/study/bo_calc.py --travel` prints this table.)

| Map | walk (tiles) | Raptor | Horseman | Musketeer | Clock Soldier (wind left) | Field Cannon | Balloon (straight line) |
|---|---|---|---|---|---|---|---|
| Kestrel Rise | 73 | 22 s | 21 s | 38 s | 40 s (52%) | 61 s | 47 s (67 tiles) |
| Twin Fords | 74 | 22 s | 21 s | 38 s | 41 s (51%) | 63 s | 50 s (71 tiles) |
| Highmoor | 75 | 22 s | 21 s | 39 s | 41 s (51%) | 63 s | 50 s (71 tiles) |
| Greenhold | 75 | 22 s | 22 s | 39 s | 42 s (50%) | 64 s | 50 s (71 tiles) |
| Cinder Steps | 77 | 23 s | 22 s | 40 s | 43 s (49%) | 65 s | 45 s (64 tiles) |
| Redrock Canyon | 81 | 24 s | 23 s | 42 s | 45 s (46%) | 68 s | 61 s (88 tiles) |
| Glimmerdeep | 86 | 26 s | 25 s | 44 s | 48 s (43%) | 73 s | 60 s (87 tiles) |
| Amberfall Vale | 89 | 26 s | 26 s | 46 s | 50 s (40%) | 75 s | 72 s (104 tiles) |
| Ashford Crossing | 94 | 28 s | 27 s | 48 s | 53 s (37%) | 79 s | 72 s (104 tiles) |
| Thornwood Maze | 101 | 30 s | 29 s | 52 s | 57 s (32%) | 85 s | 67 s (97 tiles) |
| Hollowfen | 103 | 30 s | 29 s | 53 s | 58 s (30%) | 86 s | 76 s (110 tiles) |
| Frostmere | 103 | 31 s | 30 s | 53 s | 59 s (30%) | 87 s | 76 s (109 tiles) |
| Saltmarsh Isles | 119 | 35 s | 34 s | 61 s | 68 s (18%) | 100 s | 72 s (104 tiles) |

Two things follow. First, a Raptor or a Horseman crosses any standard map in 20 to 35 seconds, so the Brood's and the Crown's fast rushes hit at about the same time everywhere; the map barely changes them. Second, the Clockwork's ground army arrives with about half its wind on the small maps and with less than a third on Hollowfen, Frostmere and Saltmarsh Isles: it has 20 to 40 seconds of fighting left there before it freezes. The Clockwork's attacks are short-range by design (a clock runs down), and on the big maps this decides its openings. Its flyers have no such limit.

### What the early units are worth

| Unit | price each | supply | health and armour | reach | damage a second | speed |
|---|---|---|---|---|---|---|
| Musketeer | 60 gold + 10 powder | 1 | 70, armour 0 | 190 | 5.6 at range, 11.6 with the bayonet | 62 |
| Horseman | 155 with its horse | 3 | 140, armour 1 | 26 | 11.2, and one 30-damage pistol shot | 112 |
| Dragoon | 100 + 10 powder with its horse | 1 | 90 mounted | 190 on foot | a Musketeer's, after it gets off | 112 |
| Field Cannon | 210 with its horse | 4 | 140, armour 1 | 430 | 5.9, splash, 2.5 times against buildings | 38 |
| Raptor | 25 (75 for three) | 1 | 36 | 22 | 4.4 | 108 |
| Spitter | 45 + 2.5 essence (two for 90 + 5) | 1 | 70 | 150 | 3.0, its acid strips 2 armour | 68 |
| Brute | 150 + 20 essence | 3 | 240, armour 2 | 28 | 10.8, knocks back | 56 |
| Bloater | 50 + 25 essence | 1 | 60, flies | 160 | 2.3, or a big acid burst | 44 |
| Clock Soldier | 70 cogs | 1 | 90, armour 1 | 22 | 5.3 | 62 |
| Jack | 100 cogs + 25 Tension | 2 | 90, armour 1 | 170 | 7.1, and a 5-tile jump | 70 |
| Netter | 125 + 50 Tension | 2 | 120, armour 1 | 180 | a net every 15 s: the target cannot move or fight for 4 s | 54 |
| Pendulum | 200 + 75 Tension | 4 | 340, armour 2 | 62, an arc | 8.5 to every enemy in the arc in front of it | 46 |
| Swift | 75 + 15 Tension | 2 | 90, flies | 28 | 8.5, only at flyers | 118 |
| Ticking Owl | 175 + 65 Tension, as a Swift plus the morph | 4 | 220, armour 1, flies | 28 | 10 on units, 15 on buildings | 56 |
| Wind-up Soldier | 25 (75 for three) | 1 | 55, armour 1 | 24 | 4.4, freezes 50 s off the field | 66 |
| Thresher | 165 cogs | 3 | 280, armour 3 | 26 | up to about 13 as its saws spin up, and bites two more | 54 |

(Damage a second is the blow divided by the time between blows: about the cooldown plus the aim plus a third of a second.)

## The tech trees

What each building costs, how long it takes, what it gives or unlocks, and what it needs first. Times are in seconds of building after the worker arrives.

### The Crown

| Building | price | time | gives or unlocks | needs |
|---|---|---|---|---|
| Town Hall | 400 gold | 60 | +10 supply; Labourers (50 gold, 12 s); room for 2 Farms and 1 Powder Mill; 9,000 gold of soil and 1,320 powder of saltpetre | |
| Cottage | 100 | 20 | +8 supply; unlocks the Barracks, the Palisade (25 a tile, 8 s) and the Gate (50, 12 s) | |
| Farm | 100 | 25 | a 380-gold harvest every 40 s with its 8 Labourers | |
| Powder Mill | 100 | 30 | powder, a third a second for each of up to 6 Labourers; unlocks the Musketeer | |
| Horse Breeder | 100 | 25 | horses (40 gold, 15 s; as many breeders as you like); unlocks the Horseman and the Officer | |
| Barracks | 150 | 40 | Musketeer, Dragoon, Horseman, Officer | a Cottage |
| Foundry | 200 | 45 | Field Cannon, Mortar, Observation Balloon, Powder Wagon | a Barracks |
| Armoury | 150 | 40 | all the research: Armour, the three musket locks, the bayonet, the shot pouch, the two gun drills, the Cavalry Charge | a Barracks |
| Church | 150 | 35 | the Missionary (one a Church) | a Barracks |

| Unit | price | time | supply | from, and what it needs |
|---|---|---|---|---|
| Labourer | 50 | 12 s | 1 | Town Hall |
| Musketeer | 60 + 10 powder | 15 s | 1 | Barracks, with a Powder Mill |
| Dragoon | 60 + 10 powder + a horse | 15 s | 1 | Barracks, with a Mill and a Horse Breeder |
| Horseman | 115 + a horse | 22 s | 3 | Barracks, with a Horse Breeder |
| Officer | 75 | 18 s | 3 | Barracks, with a Horse Breeder |
| Field Cannon | 170 + a horse | 32 s | 4 | Foundry |
| Mortar | 145 + 20 powder + a horse | 30 s | 3 | Foundry |
| Observation Balloon | 125 + 20 powder | 25 s | 2 | Foundry |
| Powder Wagon | 70 + 30 powder + a horse | 25 s | 2 | Foundry |
| Missionary | 125 | 20 s | 1 | Church |

The Crown's tree has two doors out of the first minute: the Powder Mill (Musketeers) and the Horse Breeder (Horsemen). Both need the Cottage and the Barracks behind them. The Foundry is the third tier and holds four very different things: the Cannon, the Mortar, the Balloon and the Powder Wagon. That spread is why the Crown already has the most openings.

### The Brood

| Building | price | time | gives or unlocks | needs |
|---|---|---|---|---|
| Burrow | 350 biomass | 55 | +16 supply; lays an egg every 9 s and holds 5; every unit hatches from an egg. The first Burrow is the capital: the only place grubs unload, with 10,500 biomass of ground; the others only lay eggs and give supply | |
| Clutch Mound | 75 | 18 | +12 supply; spreads swamp 10 tiles; eggs 10% faster each (up to 3) | swamp |
| Feeding Pit | 75 | 18 | food for 5 grubs (more on pits farther out; the farther, the richer, up to 30% more) | swamp |
| Brood Pen | 100 | 22 | essence: 3 a supply for every body that falls within 12 tiles; SACRIFICE; one per Burrow | |
| Spawning Den | 150 | 35 | Raptors; Spitters once a Brood Pen stands | |
| Gorge Pit | 200 | 45 | Brute, Spore Mother, Mist Toad; the Broodmound | the Spawning Den |
| Roost | 175 | 35 | Skywing, Bloater | the Spawning Den |
| Warren (the Burrow's upgrade) | 150 | 40 | 10 eggs, more health | |
| Broodmound (its second) | 250 + 50 essence | 60 | 15 eggs, armour 2 | a Gorge Pit |

| Unit | price | time | supply | needs |
|---|---|---|---|---|
| Grub | 50 | 12 s | 1 | (it is used up when it becomes a building) |
| Raptors, three an egg | 75 | 11 s | 1 each | Spawning Den |
| Spitters, two an egg | 90 + 5 essence | 13 s | 1 each | Spawning Den and Brood Pen |
| Brute | 150 + 20 essence | 22 s | 3 | Gorge Pit |
| Spore Mother | 175 + 40 essence | 26 s | 4 | Gorge Pit |
| Mist Toad | 100 + 25 essence | 22 s | 3 | Gorge Pit |
| Bloater | 50 + 25 essence | 14 s | 1 | Roost |
| Skywing | 100 + 40 essence | 16 s | 2 | Roost |

The Brood's tree is short and wide: after the Spawning Den, the Gorge Pit and the Roost are side by side. Every unit but the Raptor costs essence, and essence comes from the dead. A grub becomes the building, so every building also costs a worker.

### The Clockwork (gear mode, as in the game today)

Every Clockwork building sits in a ring of ground gears that must mesh with the field that leads back to a Clocktower; an unlinked building stops. A building can swap its connecting gear between small and big (25 cogs, 4 s).

| Building | price | time | gives or unlocks | needs |
|---|---|---|---|---|
| Clocktower | 400 cogs | 60 | +10 supply; Winders (50, 12 s); room for 2 Cog Presses; 11,400 brass; starts a gear field of its own | |
| Regulator | 100 | 20 | +10 supply | |
| Cog Press | 140 | 35 | cogs: 1.2 a second alone, 8 with 3 Winders (on the big gear 10.5 with 6) | |
| Mainspring | 140 | 35 | Tension: 0.3 a second alone, 2 with 3 Winders; no limit on how many | |
| Movement Works | 150 | 40 | Clock Soldier; once an Escapement works: Jack, Netter, and on the big gear the Pendulum | |
| Ratchet Turret | 125 | 30 | static defence, shoots ground and air (14 every 1.5 s, reach 200) | a Movement Works |
| Escapement | 150 | 40 | unlocks the Jack, the Netter and the Pendulum; researches HIGH LEAP (150 + 100 Tension) | a Movement Works, and its ring must mesh with a Mainspring's |
| Clock Aviary | 175 | 45 | Swift; researches TICKING OWL (150 + 150 Tension), then each Swift can morph (100 + 50 Tension, 20 s) | a working Escapement |
| Assembly Works (left over from before gear mode) | 200 | 45 | Wind-up Soldiers (75 for three), Thresher (165) | |

| Unit | price | time | supply | needs |
|---|---|---|---|---|
| Winder | 50 | 12 s | 1 | Clocktower |
| Clock Soldier | 70 | 16 s | 1 | Movement Works |
| Jack | 100 + 25 Tension | 25 s | 2 | a working Escapement |
| Netter | 125 + 50 Tension | 28 s | 2 | a working Escapement |
| Pendulum | 200 + 75 Tension | 35 s | 4 | a working Escapement, a Works on its big gear |
| Swift | 75 + 15 Tension | 20 s | 2 | Clock Aviary |
| Ticking Owl | a Swift + 100 + 50 Tension | 20 s morph | 4 | TICKING OWL researched |
| Wind-up Soldiers, three an order | 75 | 13 s | 1 each | Assembly Works |
| Thresher | 165 | 21 s | 3 | Assembly Works |

Provisional, all of it: the Clockwork is being rebuilt from the ground up (docs/clockwork_ground_up.md). In the wt-econ branch the Cog Press takes 6 Winders for its 8 cogs a second, every Mainspring stores at most 200 Tension, the Clock Aviary costs 150 cogs and 50 Tension and must mesh with a Mainspring, a Movement Works makes Jacks only beside a Mainspring, and every building works at 100% only when it meshes with the Clocktower or a Mainspring (10% less for each ring farther out, down to 70%). Planned next: the Spring Catapult (it throws its own melee units into the enemy) and the Great Winder (the caster: it winds the army in the field, sweeps up bodies so the Brood cannot harvest them nor a Missionary raise them, and is the field workshop that rebuilds one unit into another after a research). The owner has decided the Clockwork gets no zeppelin: its air is the Swift and the Ticking Owl.

One leftover matters for openings today: the old ASSEMBLY WORKS is still on the Clockwork's build card in gear mode (Defs.build_list keeps it, and nothing that needs power is offered, but it needs none), so a player can still make Wind-up Soldiers and Threshers. The computer never does. It is studied below as a leftover, not as part of the new faction.

## The Crown's openings

Seven openings were written down and played. The times below were measured in the game against a sleeping opponent on Ashford Crossing; the arrival times on Kestrel Rise, the smallest map, come from the calculator. "Army" is the price of the armed units alive.

| Opening | first soldier | army at 3:00 | 4:00 | 5:00 | 6:00 | earned by 3:00 / 6:00 | attack leaves, and reaches the enemy's hall |
|---|---|---|---|---|---|---|---|
CROWN_TABLE

### Crown 1: the Musketeer wall into the Cannon (the standard)

**The build.** Nine Labourers. A Cottage goes down in the mouth of the ramp at once and a Gate beside it: the ramp is shut by about 0:35. At about 0:33 the Barracks and the Powder Mill go up together, with the second Farm. Three Musketeers come out at 2:06, 2:21 and 2:36. Then the Horse Breeder (done 2:33), more Labourers, the Foundry (placed 3:18, done 3:52) and the first Field Cannon at 4:25.

**What it is.** The owner's reading is right: this is an economic opening that hurries to the Cannon. Between about 2:40 and 4:25 it adds almost nothing to its army (three or four Musketeers, 180 to 240 worth), because the Breeder, the Foundry and the new Labourers take every coin. What keeps it alive in that window is the wall and the three Musketeers behind it; the Cannon at 4:25 is the answer to the first timing attacks, and from there the army grows fast (seven Musketeers and the Cannon at 5:00, ten at 6:00).

CROWN1_RESULTS

**How to spot it.** A Cottage in the ramp's mouth by 0:25 and a Gate by 0:40; the Mill and the Barracks side by side at about 0:35; a second Farm; no Horse Breeder before 2:30 and no Foundry before 3:20.

### Crown 2: the Horseman rush

**The build.** Eight Labourers. The Horse Breeder and a Cottage at once (both done 0:25), the Barracks at 0:41 (done 1:22). No wall, no Powder Mill and no second Farm until the rush is out. The first Horseman walks out at 2:01 and mounts his horse at 2:23; three ride out together at 2:49 and reach the enemy's hall at 3:13 on Ashford Crossing (about 3:15 on any small map: cavalry barely feels the map). More Horsemen follow; the Farm and the Mill come after 2:49.

**What it is.** The Crown's only true rush: 345 worth of army at 3:00, the most of any Crown opening, all of it fast enough to choose its fight. Its target is workers: a Horseman's pistol shot and sabre kill a Labourer, a grub or a Winder in two or three blows.

CROWN2_RESULTS

**How to spot it.** A Horse Breeder at once and no wall; no Powder Mill; one Farm; horses grazing by the Breeder from about 1:50; seven or eight Labourers.

### Crown 3: Musketeers and a Balloon drop

**The build.** As the standard to the Barracks (wall, Barracks and Mill at 0:33, four hands on the Mill), then the Foundry straight after the Barracks (placed 1:39, done 2:26), no Horse Breeder. Musketeers at 1:55, 2:10, 2:25 and 3:01; the Observation Balloon at 3:11. It takes four Musketeers aboard, flies over the cliffs to the enemy's economy and lets them off beside the workers (landed at 4:41 on Ashford Crossing, about 4:05 on Kestrel Rise: the Balloon is slow, 46). The second Farm waits until 3:40.

**What it is.** The owner's Terran-drop idea. It costs a Foundry and a Balloon (325 gold and 20 powder) instead of the Breeder, so it is a little greedier than the standard in army and a little riskier in defence (one fewer Musketeer at home while the four are away).

CROWN3_RESULTS

**How to spot it.** The standard's wall and Mill, but a Foundry going up by 1:40 and no Horse Breeder; four hands on the Mill; a balloon in the sky from about 3:15.

### Crown 3b: the Balloon raid (the men stay aboard)

**The build.** The same as Crown 3, but the Balloon does not land the men. It hovers over the enemy's economy and the four Musketeers fire from the basket, which they do by themselves: from up there they reach 35% further (256 pixels against a Musketeer's 190), and they refill from the Balloon's 40-shot store. It comes home when the powder is spent or the Balloon is badly hurt.

**Why it is listed apart.** 256 pixels is further than every ground weapon that can hit a flyer: a Musketeer (190), a Ratchet Turret (200), a Netter (180), a Jack (170), a Spitter (150). Only flyers (the Skywing, the Swift) can reach it without walking underneath it, and the Balloon (speed 46) is slower than any of the soldiers that would chase it. So a hovering raid is a different opening from a drop, with different answers.

CROWN3B_RESULTS

**How to spot it.** As Crown 3.

### Crown 4: the wall and a second Town Hall (the fast expansion)

**The build.** Ten Labourers and the ramp wall, then a second Town Hall at the natural expansion at 1:18 (done 2:34), the Barracks at the same time (done 2:02), the Mill at 2:09, the new hall's two Farms, and Labourers non-stop up to 26. The first Musketeer comes at 3:31.

**What it is.** The greediest Crown opening: no soldier before 3:31 (2 at 4:00, 5 at 5:00, 9 at 6:00), but 24 Labourers at 6:00 against the standard's 15, and 3,800 gold earned by 6:00 against 3,040 (the calculator expects more once the new hall's farms are fully crewed: about 5,300).

CROWN4_RESULTS

**How to spot it.** A second Town Hall going down at about 1:20; the Barracks only then; no soldier at all at 3:00.

### Crown 5: the Dragoon raid

**The build.** The standard's wall, Barracks and Mill, then a Horse Breeder at about 1:50 and, instead of Musketeers, Dragoons: a Musketeer on a horse, trained with his horse in one click (60 gold and 10 powder, and 40 for the horse). Four Dragoons ride out at about 4:00 (calculator) and reach the enemy at about 4:30; they get off to fire as Musketeers and ride on.

**What it is.** A faster, more mobile musket line: it can strike workers and leave before the defence arrives. It is expensive (100 gold a man against a Musketeer's 60) and slow to gather. (A first version that put the Mill, the Cottage and the Breeder down all at once starved itself: five Labourers and a single harvest by 3:00. It was rewritten.)

CROWN5_RESULTS

**How to spot it.** The standard's wall and Mill, with a Horse Breeder before 2:00 and no Foundry; Musketeers that come out and walk to the Breeder.

### Crown 6: the Cannon push (the standard, then a timing attack)

**The build.** The standard to the Foundry, then two Cannons (4:25 and 5:05) and Musketeers non-stop. At 16 supply it goes: it left at 5:43 with eight Musketeers and two Cannons and reached the enemy's hall at 6:25 on Ashford Crossing.

**What it is.** The standard opening turned into an attack: the Cannon (reach 430, two and a half times its damage against buildings) out-ranges a Ratchet Turret (200) and a palisade's defenders, so this is the Crown's tool against a turtle. It is slow (the Cannon walks at 38: a minute from base to base on the small maps, a minute and a half on the big ones).

CROWN6_RESULTS

**How to spot it.** Exactly the standard until about 5:00; then a second Cannon and Musketeers gathering at the front instead of a second hall.

CROWN_SUMMARY

## The Brood's openings

Six openings were written down and played (times measured against a sleeping opponent on Ashford Crossing; arrivals on Kestrel Rise from the calculator).

| Opening | first soldier | army at 3:00 | 4:00 | 5:00 | 6:00 | earned by 3:00 / 6:00 | attack leaves, and reaches the enemy's hall |
|---|---|---|---|---|---|---|---|
BROOD_TABLE

### Brood 1: the six-pool (extreme rush)

**The build.** The Spawning Den goes down at once with the starting 250 biomass (so it is really a five-pool: five grubs, one of them becomes the Den), done 0:38. Every egg after that is Raptors; the grubs grow only to eight. The first Raptors hatch at 0:50, six leave at 1:03 and reach the enemy's hall at 1:28 on Ashford Crossing (1:22 on Kestrel Rise), and the rest follow in twos and threes: twelve Raptors at 3:00.

**What it is.** The owner's extreme rush, played faster than his hand-played anchor (Den 1:01, first hit 2:00 to 2:30) because nothing is spent before the Den. It is all-in: eight grubs, no Pen, no second pit.

BROOD1_RESULTS

**How to spot it.** A Spawning Den at once, before any new grub; five or six grubs and one Feeding Pit; Raptors at the door before 1:30.

### Brood 2: pool first, one wave, then the economy

**The build.** The Spawning Den and a second Feeding Pit at once, grubs to eight, then two eggs of Raptors (six) that leave at about 2:46 and reach the enemy at about 3:10 on a small map. After the wave: grubs to 15, a Clutch Mound, the Brood Pen, and Raptors non-stop.

**What it is.** A one-wave harassment that buys time and information, then drones. The wave is small (150 worth) and arrives when a standard Crown has three Musketeers behind its wall, so its job is to kill workers caught outside, not to win.

BROOD2_RESULTS

**How to spot it.** A Den at once but a second pit too, and grubs still coming; six Raptors at about 3:00, not more.

### Brood 3: the economy opening (grubs first)

**The build.** Ten grubs, a second Feeding Pit, the Den, fourteen grubs, a third pit, the Brood Pen, a Clutch Mound, seventeen grubs, the Burrow's upgrade to a Warren (10 eggs), then Raptors from every egg; the wave goes at 30 supply (about 5:50) and reaches a small map's enemy hall at about 6:10.

**What it is.** The greediest Brood opening: no army at all until about 4:30, then the biggest Raptor wave of any opening (30 Raptors by 6:00). It earns 750 by 3:00 and about 2,400 by 6:00 in the calculator, the best Brood economy, but still well under the Crown's standard.

BROOD3_RESULTS

**How to spot it.** Pits and grubs only, the Den late (after about 0:40, with ten grubs), no Raptors at 3:00.

### Brood 4: the Spitter timing

**The build.** Ten grubs, the Den, a pit, the Brood Pen, thirteen grubs, four eggs of Raptors, ten of which are offered up at the Pen for the essence (30), a Clutch Mound, five eggs of Spitters (ten), and the wave at 24 supply or 6:00: ten Spitters and eight Raptors.

**What it is.** The Brood's only ranged and anti-air opening. The Spitter costs little essence (5 an egg of two), but even that has to be bought by offering up Raptors before the first fight, and the wave only goes at 6:00.

BROOD4_RESULTS

**How to spot it.** A Brood Pen early (before 3:00) with Raptors walking into it and vanishing; Spitters at about 5:00.

### Brood 5: the Brute timing

**The build.** As the Spitter timing, but a Gorge Pit (placed about 3:40) instead of Spitters; fourteen Raptors offered up for two Brutes' 40 essence; the wave goes at about 7:00 with two Brutes and nineteen Raptors.

**What it is.** On paper the Brood's armoured push (a Brute: 240 health, armour 2, knocks men back, 1.6 times against buildings). In practice the essence tax makes it the slowest opening of the study: the Gorge Pit is late on the Brood's thin income, and two Brutes cost the price of fourteen Raptors on top of their own.

BROOD5_RESULTS

**How to spot it.** A Gorge Pit; Raptors being offered up at the Pen; few soldiers before 6:00.

### Brood 6: the Roost (Bloaters)

**The build.** The Den, a pit, the Pen, then the Roost (placed about 3:20); seventeen Raptors offered up for two Bloaters' 50 essence; the wave goes at about 6:20 with two Bloaters and sixteen Raptors.

**What it is.** The owner's "maybe an air rush". The Bloater (50 biomass and 25 essence) floats over cliffs and spits acid from 160, or bursts as an acid bomb; the Skywing (100 and 40) hunts flyers. With essence only from offerings, two Bloaters cost seventeen Raptors, so this is not a rush: it is the slowest way to the slowest wave.

BROOD6_RESULTS

**How to spot it.** A Roost; Raptors being offered up; a Bloater in the sky at about 5:45.

BROOD_SUMMARY

## The Clockwork's openings (provisional: the faction is being rebuilt)

Six openings of the new Clockwork and one leftover were written down and played. Everything here is provisional twice over: the faction's roster is still growing (the Spring Catapult and the Great Winder are next), and its economy is being rebuilt in the wt-econ branch. So each opening is given twice: measured in the game as it is today, and from the calculator with the rebuilt economy (`--preset econ28`).

| Opening | first soldier | army at 3:00 | 4:00 | 5:00 | 6:00 | earned by 3:00 / 6:00 | attack leaves, and reaches the enemy's hall |
|---|---|---|---|---|---|---|---|
CLOCKWORK_TABLE

With the rebuilt economy (calculator, Kestrel Rise):

| Opening | army at 3:00 | 4:00 | 5:00 | 6:00 | earned by 3:00 / 6:00 | attack leaves, and arrives |
|---|---|---|---|---|---|---|
| Clockwork 1: Clock Soldier rush | 560 | 910 | 1,470 | 1,960 | 1,206 / 3,125 | 1:54, 2:34 |
| Clockwork 2: Jacks (the standard) | 280 | 882 | 1,345 | 1,935 | 1,673 / 3,690 | 4:24, 5:04 |
| Clockwork 3: Turret and a second Clocktower | 140 | 420 | 700 | 980 | 1,768 / 5,340 | none |
| Clockwork 4: Swifts into Ticking Owls | 140 | 222 | 585 | 1,335 | 1,656 / 4,063 | 5:27, 6:11 |
| Clockwork 5: fast Jacks | 225 | 675 | 900 | 1,238 | 1,110 / 2,377 | 3:38, 4:13 |
| Clockwork 6: Pendulum and Netter push | 140 | 378 | 1,045 | 1,632 | 1,689 / 3,721 | 5:59, 6:54 |
| Leftover: Wind-up Soldiers | 600 | 900 | 1,275 | 1,575 | 1,312 / 2,752 | 1:47, 2:26 |

The rebuild costs the slow, worker-heavy openings the most (the Jacks, the Pendulums, the second Clocktower: half a minute to a minute later and a quarter to a half less army at 3:00 and 4:00) and the cheap rushes the least (the Clock Soldier rush and the Wind-up Soldiers use few Winders, so a press that needs more of them barely touches them). Even rebuilt, the Clockwork earns the most of the three by 3:00. One reason is not in the price list at all: a Winder only carries the crate to the site (about 9 seconds) and goes back to his press while the building unfolds itself, whereas a Labourer stays on the site for the whole build (a Barracks takes one off the farm for about a minute) and a grub is used up. The Clockwork's builders cost it almost nothing (design_principles.md section 3: builders must have an opportunity cost).

### Clockwork 1: the Clock Soldier rush (two Works)

**The build.** Five Winders. A Movement Works and a Regulator at once, a second Works at 0:22, Clock Soldiers from both without a stop. Six leave at about 1:54 and reach the enemy's hall at about 2:34 on a small map; nine at 3:00, sixteen at 4:00. The second press and more Winders come after the wave.

**What it is.** The fastest strong army in the game: 630 worth at 3:00, twice the Crown's best and the Brood's best. The Movement Works needs nothing before it and costs 150, and the Clock Soldier (70 cogs: 90 health, armour 1, a Musketeer's damage up close) is cheap for what it is. Its limit is the wind: the soldiers arrive with half their wind on a small map (about 40 seconds of fighting left), a third on the big ones.

CW1_RESULTS

**How to spot it.** Two Movement Works and no second press; Clock Soldiers on the road before 2:00.

### Clockwork 2: Jacks (the standard)

**The build.** Seven Winders, a second Cog Press and a Movement Works at once, the Mainspring (with three Winders) at about 0:50, the Escapement meshed with it at about 1:35 (working at about 2:20), two Clock Soldiers, then Jacks from the first Works, a second Works with Clock Soldiers and a Ratchet Turret. The first wave goes at 16 supply, at about 3:55, and reaches a small map's enemy hall at about 4:35.

**What it is.** The Clockwork's balanced opening, the counterpart of the Crown's standard: a little army early, tech by 2:20, a turret at home. The Jack (ranged, hits flyers, jumps 5 tiles) is the first Tension unit. Today it floats money (800 to 1,500 cogs in the bank at 4:00 to 6:00 in the calculator): the economy is bigger than two Works can spend.

CW2_RESULTS

**How to spot it.** A Mainspring and an Escapement side by side by 1:40; Jacks hopping at the front at about 2:30.

### Clockwork 3: the Ratchet Turret and a second Clocktower (the fast expansion)

**The build.** Seven Winders, the second press and a Movement Works, a second Clocktower at about 1:05 (done about 2:15), a Ratchet Turret, Clock Soldiers from the one Works, Winders to 14 and the new tower's two presses. Then the computer's Economy plan takes over.

**What it is.** The Clockwork's greedy opening: by far the most cogs of any opening in the study (about 8,000 by 6:00 today). The turret covers the home base; the new tower starts its own gear field, so it also stretches the ground on which the Clockwork's army stays wound.

CW3_RESULTS

**How to spot it.** A second Clocktower going down at about 1:05; a Ratchet Turret; few soldiers.

### Clockwork 4: Swifts into Ticking Owls (air)

**The build.** The standard to the Escapement, then the Clock Aviary (working at about 3:15), a second Mainspring for the Tension, two Swifts, the TICKING OWL research (150 cogs and 150 Tension, a minute), a Ratchet Turret, two more Swifts, and three of them morphed into Owls (100 cogs and 50 Tension each, 20 seconds). The Owls go at about 5:15 and reach a small map's enemy base at about 6:00.

**What it is.** The Clockwork's air opening: Owls swoop on units and drop bombs on buildings (45 to every building around the impact), and they have no wind to lose. Tension is the bottleneck: three Owls with their research cost 345 Tension, nearly three minutes of a full Mainspring, hence the second one.

CW4_RESULTS

**How to spot it.** A Clock Aviary (a tall narrow clock tower) by about 2:30; two Mainsprings; Swifts in the air from about 3:30.

### Clockwork 5: fast Jacks (the Escapement first)

**The build.** Seven Winders, a Movement Works and a Mainspring at once, the Escapement as soon as the Works stands (working at about 1:42), Jacks from the first Works and a second Works for more. Four or five Jacks go at about 3:00 and reach a small map's enemy hall at about 3:35.

**What it is.** A ranged rush: Jacks out-range Raptors, Clock Soldiers and Horsemen and can jump away from them, and they shoot flyers. It skips the second press, so its economy is the thinnest of the Clockwork's (1,400 cogs by 3:00), and Tension (25 a Jack, 2 a second from one Mainspring) caps it at about one Jack every 12 seconds.

CW5_RESULTS

**How to spot it.** A Mainspring and an Escapement before 1:00, one press; Jacks on the road at about 3:00.

### Clockwork 6: the Pendulum and Netter push (tier 3)

**The build.** The standard to the Escapement, a second Works, the first Works swapped to its big gear (25 cogs, 4 seconds: the Pendulum is made only there), two Pendulums, a Netter, Clock Soldiers from the second Works and a third Pendulum. The push goes at 24 supply, at about 5:00, and reaches a small map's enemy hall at about 6:00.

**What it is.** The new tier 3 as an opening. A Pendulum cuts every enemy in the arc in front of it (22 a swing to each), the natural answer to a swarm of Raptors or a tight musket line; the Netter holds the most dangerous enemy in place for 4 seconds. The Pendulum is slow (46), and that meets the wind: on Kestrel Rise it arrives with about a third of its wind, on Frostmere with almost none (2%). Today this opening only works on small maps.

CW6_RESULTS

**How to spot it.** The standard's Escapement, then a Movement Works with a big gear ring; tall Pendulums in the army from about 3:30.

### Leftover: the Assembly Works and Wind-up Soldiers

**The build.** Six Winders, the Assembly Works and a Regulator at once, Wind-up Soldiers (three for 75 cogs) without a stop; twelve go at about 1:47.

**What it is.** Not part of the new Clockwork. The old Assembly Works is still on the build card in gear mode, and nothing it makes needs power, so a player can still open with it; the computer never does. Wind-up Soldiers run on a spring, not on wind: 50 seconds off the gear field and they freeze. Twelve of them reach a small map's enemy hall with a fifth of their spring left (about 11 seconds of fighting) and a big map's with none. The Assembly Works also makes the Thresher (165 cogs, 280 health, armour 3, saws that spin up), which this study did not script.

CW7_RESULTS

**How to spot it.** A big Assembly Works instead of a Movement Works.

CLOCKWORK_SUMMARY

RESULTS_SECTION

GAPS_SECTION

RECOMMENDATIONS_SECTION

## The calculator against the game

CALIBRATION_SECTION

## How to run the tools

All from the worktree root, one Godot process at a time (export PATH=$PATH:/home/claude/godot first):

- The rule numbers (only after a balance change): `godot --headless --fixed-fps 30 --script res://tools/study/bo_dump.gd -- defs out:/tmp/bo/defs.json`; the map distances (only after a map change): the same with `map:<id> seed:1 out:/tmp/bo/maps/<id>_1.json` for each map; then `python3 tools/study/bo_data.py --defs /tmp/bo/defs.json --maps /tmp/bo/maps`.
- The calculator: `python3 tools/study/bo_calc.py crown_horse_rush` for one build, `--map kestrel_rise` for one map, `--all` for a summary of every build, `--travel` for the walking table, `--vs crown_horse_rush brood_economy` for a rough fight estimate when an attack lands, `--steps "workers:8,horse_breeder,cottage,barracks,horseman*3,attack" --faction crown` for a build of your own, `--set PATH=VALUE` to try a change, and `--preset econ28` for the provisional Clockwork economy.
- One match: `godot --headless --fixed-fps 30 --script res://tools/study/bo_match.gd -- sa:crown_horse_rush sb:ai:balanced b:brood map:kestrel_rise seed:1 end:480 out:/tmp/bo/m.json`. A side is a build name, `ai:<plan>` (the ordinary computer) or `idle` (a sleeping opponent).
- Many matches: `python3 tools/study/bo_run.py calib --out /tmp/bo/calib --end 420` and `python3 tools/study/bo_run.py matrix --out /tmp/bo/runs --end 480` (resumable: finished matches are skipped; touch STOP in the folder to stop after the current one), then `python3 tools/study/bo_report.py --runs /tmp/bo/runs` for the tables and `--calib` for the timing table.
- The step grammar of a build order is described at the top of tools/study/bo_ai.gd.
