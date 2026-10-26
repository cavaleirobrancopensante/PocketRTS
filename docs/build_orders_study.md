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

CROWN_SECTION

BROOD_SECTION

CLOCKWORK_SECTION

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
