# Build orders: what each faction can open with

A study of Holdfast v0.14.31 and v0.14.32, 26 and 27 October 2026. The owner's question: what build orders does each faction have? He wants variety: at least three distinct openings that work for each faction, and four would be very healthy.

(The timings were first measured on v0.14.27. Between 0.14.27 and 0.14.31 only one rule that matters here changed: the Clockwork's old Assembly Works left the build card. Every price, time and economy number is the same, which the tools checked by reading the rules again, and the Crown's standard opening was timed again on 0.14.31 with the same result. Version 0.14.32 brought grey fog only: every side can now build anywhere, which is what makes the proxy openings below possible. All the timings and matches in this version of the study were played again on 0.14.32.)

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

What the ordinary computer does matters for every result below. On its Balanced plan it sends a worker to scout at about 0:18 and changes its plan on what it sees: an early army or a minimal economy with several production buildings means a rush, and it turns to a defensive game (army and walls first, then a counter-attack); an early expansion with little army means greed, and it prepares a timing attack against it. The Crown computer walls its ramp with a Cottage and a Gate by about 0:40, opens with the Powder Mill (Musketeers) seven games in ten and with the Horse Breeder (a Horseman rush) the other three. The Clockwork computer builds a Movement Works (done at about 1:25) and Clock Soldiers, more Works and a turret, and from 3:30 to 4:30 on Hard (sooner with money in the bank) a Mainspring, an Escapement, Jacks, and then Pendulums and Netters. The Brood computer is the weak one and is being rewritten.

Read the match results as indications, not proof. Both sides are played by the computer, which defends and fights the way it does; there is one game per pairing; and the machine was shared with several other jobs, so the list of matches was kept short. The timings, on the other hand, are solid: the calculator and the game agree on them (the last section shows by how much).

Two parts of the game were being changed in other branches while this was written, and both are marked as provisional where they matter:
- **The Brood's computer player** is being fixed (the wt-brood-ai branch: essence without corpses, supply on time, no attacks into a stronger army, a real rush). Every match against the Brood computer below was played with the old one, which is known to be weak.
- **The Clockwork's economy** is being rebuilt (the wt-econ branch, 0.14.28 to 0.14.32 there: Tension prices on buildings, an efficiency for every building, neighbour rules, and a Cog Press that needs twice the Winders for the same cogs; then a Mainspring that stores at most 200 Tension, anything that costs Tension made only where a Mainspring's ring meshes, Jacks included, and gear rings that mesh only on one ground level). The Clockwork openings below are timed both ways: on the game as it is, and with the calculator's econ28 preset for the rebuilt economy (its numbers; the placement rules are not in the calculator, and they can cost a Clockwork opening a second Works or a second Mainspring).

## The three economies

| | Crown | Brood | Clockwork |
|---|---|---|---|
| Start | 300 gold, 4 Labourers, a Farm already 60% grown, the Town Hall (10 supply) | 250 biomass, 5 grubs, a Feeding Pit, the Burrow (16 supply, 5 eggs) | 300 cogs, 4 Winders, a Cog Press, the Clocktower (10 supply) |
| How the money comes | A Farm ripens into a 380-gold harvest: every 40 seconds with 8 Labourers, every 70 with 4, every 267 with nobody. So it comes in lumps. A Mill hand grinds a third of a powder a second | Each grub earns about 0.58 biomass a second on the starting pit, about 0.62 on pits farther out | A Cog Press pays 1.2 cogs a second by itself and 2.3 more for each Winder on it, up to 3: 8 a second with a full crew. A Mainspring winds 0.3 Tension a second alone, 2 with 3 Winders |
| Per worker, roughly | 1 gold a second (60 a minute) | 0.6 biomass a second (35 a minute) | 2.3 cogs a second (136 a minute); with the wt-econ rebuild, 1.1 |
| The second resource | Powder, from the Powder Mill (up to 6 hands, 2 a second): steady from the first minute | Essence, only from bodies (3 a supply for a body that falls near a Brood Pen, 1.25 for one a grub carries home) or from SACRIFICE (12% of a creature's price, 3 for a Raptor). No building makes it | Tension, from Mainsprings (3 hands, 2 a second each, and there is no limit on Mainsprings): steady once one stands |
| Earned by 3:00 (measured, by opening) | 760 to 1,140 gold | 600 to 1,000 biomass | 1,400 to 2,500 cogs |
| Earned by 6:00 (measured, by opening) | 2,660 to 3,800 | 2,100 to 2,800 | 4,200 to 8,100 |
| Making the army | One unit at a time per Barracks or Foundry (a Musketeer takes 15 seconds) | Eggs: each Burrow lays one every 9 seconds (10% faster for each Clutch Mound, up to 3) and holds 5; every unit, grubs included, takes an egg, and the eggs hatch side by side | One unit at a time per Movement Works (a Clock Soldier takes 16 seconds) |
| The land runs out | 9,000 gold of soil per Town Hall; a new hall brings fresh soil | 10,500 biomass of ground at the capital, for the whole game: other Burrows have no ground | 11,400 brass per Clocktower; spent brass still pays a quarter, forever |

Three things in this table shape every opening.

First, the Clockwork's money. On the game as it is, a Winder on a Cog Press earns more than twice what a Labourer earns on a Farm, and a press is full with only three Winders. So the Clockwork has more to spend than the other two from the first minute, and most of its openings are limited by how fast its buildings can make units, not by money. Measured against a sleeping opponent, the Clockwork's fast expansion earned 8,066 cogs by 6:00 and had 31 Clock Soldiers; the Crown's fast expansion earned 3,800 gold and had 9 Musketeers. The wt-econ rebuild halves a Winder's share, which brings it to about a Labourer's; the calculator puts the same Clockwork expansion at about 5,300 cogs by 6:00 after the rebuild, still well ahead of the Crown. Everything said below about the Clockwork's strength must be read with that in mind.

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

Two things follow. First, a Raptor or a Horseman crosses any standard map in 20 to 35 seconds, so the Brood's and the Crown's fast rushes hit at about the same time everywhere; the map barely changes them. Second, the Clockwork's ground army arrives with about half its wind on the small maps and with less than a third on Hollowfen, Frostmere and Saltmarsh Isles: it has 20 to 40 seconds of fighting left there before it freezes. The Clockwork's attacks are short-range by design (a clock runs down), and on the big maps this decides its openings. Its flyers run down too (they are constructs like the rest), but they fly the straight line over cliffs, so they get there sooner.

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

| Unit | price | time | supply | needs |
|---|---|---|---|---|
| Winder | 50 | 12 s | 1 | Clocktower |
| Clock Soldier | 70 | 16 s | 1 | Movement Works |
| Jack | 100 + 25 Tension | 25 s | 2 | a working Escapement |
| Netter | 125 + 50 Tension | 28 s | 2 | a working Escapement |
| Pendulum | 200 + 75 Tension | 35 s | 4 | a working Escapement, a Works on its big gear |
| Swift | 75 + 15 Tension | 20 s | 2 | Clock Aviary |
| Ticking Owl | a Swift + 100 + 50 Tension | 20 s morph | 4 | TICKING OWL researched |

Provisional, all of it: the Clockwork is being rebuilt from the ground up (docs/clockwork_ground_up.md). In the wt-econ branch the Cog Press takes 6 Winders for its 8 cogs a second, every Mainspring stores at most 200 Tension, the Clock Aviary costs 150 cogs and 50 Tension and must mesh with a Mainspring, a Movement Works makes Jacks only beside a Mainspring, and every building works at 100% only when it meshes with the Clocktower or a Mainspring (10% less for each ring farther out, down to 70%). Planned next: the Spring Catapult (it throws its own melee units into the enemy) and the Great Winder (the caster: it winds the army in the field, sweeps up bodies so the Brood cannot harvest them nor a Missionary raise them, and is the field workshop that rebuilds one unit into another after a research). The owner has decided the Clockwork gets no zeppelin: its air is the Swift and the Ticking Owl.

Until 0.14.31 the old ASSEMBLY WORKS was still on the Clockwork's build card, so a player could open with Wind-up Soldiers (three for 75 cogs) or Threshers. 0.14.31 retired it with the rest of the prototype roster, so that leftover opening is gone (see the end of the Clockwork's openings).

## The Crown's openings

Eight openings were written down and played. The times below were measured in the game against a sleeping opponent on Ashford Crossing, the attack times included (in the last column); the arrival times on Kestrel Rise, the smallest map, given in the text come from the calculator. "Army" is the price of the armed units alive.

| Opening | first soldier | army at 3:00 | 4:00 | 5:00 | 6:00 | earned by 3:00 / 6:00 | attack leaves, and reaches the enemy's hall |
|---|---|---|---|---|---|---|---|
| Crown 1: Musketeer wall into the Cannon (the standard) | 2:06 | 180 | 240 | 530 | 770 | 760 / 3,040 | none |
| Crown 2: Horseman rush | 2:01 | 345 | 460 | (over) | (over) | 1,140 / (over) | 2:49, 3:13 |
| Crown 3: Musketeers and a Balloon drop | 1:55 | 180 | 425 | 605 | (over) | 1,140 / (over) | balloon 3:18, 4:41 |
| Crown 3b: Balloon raid (the Musketeers fire from the basket) | 1:53 | 180 | 425 | 605 | 845 | 1,140 / 2,660 | balloon 3:18, 4:37 |
| Crown 4: Wall and a second Town Hall | 3:26 | 0 | 120 | 300 | 540 | 1,140 / 4,180 | none |
| Crown 5: Dragoon raid (the wall and the Mill, then a Breeder and Dragoons) | 3:26 | 0 | 220 | 660 | (over) | 760 / (over) | 4:11, 4:35 |
| Crown 6: Cannon and Musketeer push (the standard, then a timing attack) | 2:06 | 180 | 240 | 470 | 920 | 760 / 2,660 | 5:44, 6:26 |
| Crown 7: Proxy Horseman rush | 2:15 | 270 | 460 | (over) | (over) | 1,140 / (over) | 3:05, 3:15 |

### Crown 1: the Musketeer wall into the Cannon (the standard)

**The build.** Nine Labourers. A Cottage goes down in the mouth of the ramp at once and a Gate beside it: the ramp is shut by about 0:35. At about 0:33 the Barracks and the Powder Mill go up together, with the second Farm. Three Musketeers come out at 2:06, 2:21 and 2:36. Then the Horse Breeder (done 2:33), more Labourers, the Foundry (placed 3:18, done 3:52) and the first Field Cannon at 4:25.

**What it is.** The owner's reading is right: this is an economic opening that hurries to the Cannon. Between about 2:40 and 4:25 it adds almost nothing to its army (three or four Musketeers, 180 to 240 worth), because the Breeder, the Foundry and the new Labourers take every coin. What keeps it alive in that window is the wall and the three Musketeers behind it; the Cannon at 4:25 is the answer to the first timing attacks, and from there the army grows fast (seven Musketeers and the Cannon at 5:00, ten at 6:00).

**How it did.** It is the safest opening in the game today. Against the Brood computer it ended ahead. It held the six-pool cleanly (all the Raptors died, one Labourer was lost), it held the Horseman rush (the Horsemen turned back without a kill), and it beat back the Spitter, Brute, Roost and forward-Burrow timings. Against the Clock Soldier rush the wall held too: the soldiers turned back having killed nothing. But against everything Clockwork it ends behind: the Jacks standard won outright at 7:55 (14 Labourers lost), and the Owls, the Pendulums and the fast Jacks finished even. Against the Clockwork computer it killed 660 worth for 170 and still ended behind, because the Clockwork's bigger economy builds a bigger army (see the results section).

**How to spot it.** A Cottage in the ramp's mouth by 0:25 and a Gate by 0:40; the Mill and the Barracks side by side at about 0:35; a second Farm; no Horse Breeder before 2:30 and no Foundry before 3:20.

### Crown 2: the Horseman rush

**The build.** Eight Labourers. The Horse Breeder and a Cottage at once (both done 0:25), the Barracks at 0:41 (done 1:22). No wall, no Powder Mill and no second Farm until the rush is out. The first Horseman walks out at 2:01 and mounts his horse at 2:23; three ride out together at 2:49 and reach the enemy's hall at 3:13 on Ashford Crossing (about 3:15 on any small map: cavalry barely feels the map). More Horsemen follow; the Farm and the Mill come after 2:49.

**What it is.** The Crown's only true rush: 345 worth of army at 3:00, the most of any Crown opening, all of it fast enough to choose its fight. Its target is workers: a Horseman's pistol shot and sabre kill a Labourer, a grub or a Winder in two or three blows.

**How it did.** The best opening in the study against the Brood. It beat the Brood computer at 5:44 on Kestrel Rise and at 5:49 on Frostmere (ten grubs killed both times: the walk barely matters to cavalry), and it beat the Brood's economy opening at 7:32 after killing 29 grubs. Against the Crown standard it does nothing: the wall and three Musketeers turn it back (even). Against the Clockwork it fails every time: the Clockwork computer, the Jacks standard and the turret expansion all turned it back, and the Crown ended behind with 11 to 13 Labourers lost later in the game.

**How to spot it.** A Horse Breeder at once and no wall; no Powder Mill; one Farm; horses grazing by the Breeder from about 1:50; seven or eight Labourers.

### Crown 3: Musketeers and a Balloon drop

**The build.** As the standard to the Barracks (wall, Barracks and Mill at 0:33, four hands on the Mill), then the Foundry straight after the Barracks (placed 1:39, done 2:26), no Horse Breeder. Musketeers at 1:55, 2:10, 2:25 and 3:01; the Observation Balloon at 3:11. It takes four Musketeers aboard, flies over the cliffs to the enemy's economy and lets them off beside the workers (landed at 4:41 on Ashford Crossing, about 4:05 on Kestrel Rise: the Balloon is slow, 46). The second Farm waits until 3:40.

**What it is.** The owner's Terran-drop idea. It costs a Foundry and a Balloon (325 gold and 20 powder) instead of the Breeder, so it is a little greedier than the standard in army and a little riskier in defence (one fewer Musketeer at home while the four are away).

**How it did.** A strong punish of a greedy opponent: against the Brood's economy opening the four men killed 26 grubs and the Crown ended far ahead. Against the Brood computer it was even (the drop killed little). Against the Clockwork it lands into Jacks and a turret, which shoot flyers and soldiers alike: against the Jacks standard the drop traded 420 for 425, and against the Clockwork computer the men landed and pulled back. On Frostmere the same drop killed 1,060 worth, because the Clockwork had spread out more; the Crown still ended behind.

**How to spot it.** The standard's wall and Mill, but a Foundry going up by 1:40 and no Horse Breeder; four hands on the Mill; a balloon in the sky from about 3:15.

### Crown 3b: the Balloon raid (the men stay aboard)

**The build.** The same as Crown 3, but the Balloon does not land the men. It hovers over the enemy's economy and the four Musketeers fire from the basket, which they do by themselves: from up there they reach 35% further (256 pixels against a Musketeer's 190), and they refill from the Balloon's 40-shot store. It comes home when the powder is spent or the Balloon is badly hurt.

**Why it is listed apart.** 256 pixels is further than every ground weapon that can hit a flyer: a Musketeer (190), a Ratchet Turret (200), a Netter (180), a Jack (170), a Spitter (150). Only flyers (the Skywing, the Swift) can reach it without walking underneath it, and the Balloon (speed 46) is slower than any of the soldiers that would chase it. So a hovering raid is a different opening from a drop, with different answers.

**How it did.** The most damaging raid in the study for its price. Over the Brood computer the basket killed 500 worth (9 grubs) and the Crown ended ahead; over the Brood's economy opening it killed 800 worth (16 grubs). Over the Clockwork computer it killed 1,450 worth (13 Winders) before the powder ran out, and the Crown still ended behind on economy. Only the Jacks standard stopped it: Jacks reach flyers and the Balloon turned back hurt after 200 worth.

**How to spot it.** As Crown 3.

### Crown 4: the wall and a second Town Hall (the fast expansion)

**The build.** Ten Labourers and the ramp wall, then a second Town Hall at the natural expansion at 1:18 (done 2:34), the Barracks at the same time (done 2:02), the Mill at 2:09, the new hall's two Farms, and Labourers non-stop up to 26. The first Musketeer comes at 3:31.

**What it is.** The greediest Crown opening: no soldier before 3:31 (2 at 4:00, 5 at 5:00, 9 at 6:00), but 24 Labourers at 6:00 against the standard's 15, and 3,800 gold earned by 6:00 against 3,040 (the calculator expects more once the new hall's farms are fully crewed: about 5,300).

**How it did.** It survives every rush that came at it, but it pays for it in workers. Against the six-pool it lost 8 Labourers (the Raptors killed 400 worth before the Musketeers came) and still ended ahead; against the one-wave Brood opening it lost 4. Against the Clock Soldier rush it held (even: it killed 2,010 worth for 880). Against the Brood computer it was ahead; against the Clockwork computer behind (8 Labourers lost).

**How to spot it.** A second Town Hall going down at about 1:20; the Barracks only then; no soldier at all at 3:00.

### Crown 5: the Dragoon raid

**The build.** The standard's wall, Barracks and Mill, then a Horse Breeder at about 1:50 and, instead of Musketeers, Dragoons: a Musketeer on a horse, trained with his horse in one click (60 gold and 10 powder, and 40 for the horse). Four Dragoons ride out at about 4:00 (calculator) and reach the enemy at about 4:30; they get off to fire as Musketeers and ride on.

**What it is.** A faster, more mobile musket line: it can strike workers and leave before the defence arrives. It is expensive (100 gold a man against a Musketeer's 60) and slow to gather. (A first version that put the Mill, the Cottage and the Breeder down all at once starved itself: five Labourers and a single harvest by 3:00. It was rewritten.)

**How it did.** Good against a greedy Brood (against the economy opening it killed 1,775 worth, 13 grubs, for 840), even against the Brood computer (the raid met Raptors at home and turned back), and behind against the Clockwork computer. Its first soldier comes at 3:26, more than a minute after the standard's, which is what makes it weak at home in the meantime.

**How to spot it.** The standard's wall and Mill, with a Horse Breeder before 2:00 and no Foundry; Musketeers that come out and walk to the Breeder.

### Crown 6: the Cannon push (the standard, then a timing attack)

**The build.** The standard to the Foundry, then two Cannons (4:25 and 5:05) and Musketeers non-stop. At 16 supply it goes: it left at 5:43 with eight Musketeers and two Cannons and reached the enemy's hall at 6:25 on Ashford Crossing.

**What it is.** The standard opening turned into an attack: the Cannon (reach 430, two and a half times its damage against buildings) out-ranges a Ratchet Turret (200) and a palisade's defenders, so this is the Crown's tool against a turtle. It is slow (the Cannon walks at 38: a minute from base to base on the small maps, a minute and a half on the big ones).

**How it did.** Ahead against the Brood computer and against the Brood's economy (11 grubs killed). Against the Clockwork it trades well and still loses the game: against the Clockwork computer it killed 1,960 worth for 715 and ended behind, and against the turret expansion it arrived at 6:12 into a base that had already out-built it.

**How to spot it.** Exactly the standard until about 5:00; then a second Cannon and Musketeers gathering at the front instead of a second hall.

### Crown 7: the proxy Horseman rush

**The build.** Eight Labourers and a Cottage at home; one Labourer walks about three quarters of the way to the enemy and puts down the Horse Breeder (done 0:56) and the Barracks (done 1:26) out of their sight. Since 0.14.32 (grey fog only) any side can build anywhere. Three Horsemen ride out at 3:05 and reach the hall at 3:15 on Ashford Crossing.

**What it is.** The idea is the rush with no walk. In practice it gains nothing: the builder's walk there and back costs the economy more than the Horsemen save on the road, because cavalry crosses any map in 20 to 35 seconds anyway. It arrives at the same time as the ordinary Horseman rush with fewer Labourers at home.

**How it did.** The same as the Horseman rush: it beat the Brood computer at 6:13 and wrecked the Brood's economy opening (18 grubs), and it lost to the Clockwork computer (6:35) and the Jacks standard (6:57). Proxies matter for slow armies, not for cavalry.

**How to spot it.** No Horse Breeder and no Barracks at home at 1:30; one Labourer missing. A worker scout that walks the approach finds them.

### Crown openings not played here

- **The Mortar push.** The Mortar (reach 352, lobs over walls, 30 damage over a wide area) is the Foundry's siege tool against a walled or turreted base. It is a mid-game tool more than an opening.
- **An Armour timing.** The Armoury's Armour (it needs the Foundry) turns Musketeers into Guardsmen and Horsemen into Cuirassiers; a push at 6 to 7 minutes.

### The Crown, in short

| Opening | type | beats | loses to | verdict |
|---|---|---|---|---|
| 1. Musketeer wall into the Cannon | safe standard | every rush; the slow Brood timings | the Clockwork's Jacks (economy) | viable, the default |
| 2. Horseman rush | rush | every greedy Brood opening, the Brood computer | the wall; anything Clockwork | viable |
| 3. Balloon drop | harass | greedy openings | Jacks, turrets | viable against Brood |
| 3b. Balloon raid (hover) | harass | anything without flyers or Jacks | Jacks, Swifts, Skywings | viable, possibly too strong against the Brood |
| 4. Fast expansion | greedy | out-earns the other Crown openings | early Raptors kill its Labourers | viable |
| 5. Dragoon raid | raid | a greedy Brood | anything that holds home early | marginal (late first soldier) |
| 6. Cannon push | timing | a Brood that teched slowly | the Clockwork's bigger army | viable |
| 7. Proxy Horseman rush | rush | the Brood | the wall; the Clockwork | adds nothing over opening 2 |

The Crown already has what the owner asked for: four distinct openings that work (the standard, the Horseman rush, the Balloon drop or raid, the fast expansion), plus the Cannon push as the standard's follow-up. Its problem is not variety; it is that every opening ends behind the Clockwork, which is the Clockwork's economy (see the gaps).

## The Brood's openings

Seven openings were written down and played (the table: measured against a sleeping opponent on Ashford Crossing; arrivals on Kestrel Rise in the text: from the calculator; "(over)" means the sleeping opponent was already beaten).

| Opening | first soldier | army at 3:00 | 4:00 | 5:00 | 6:00 | earned by 3:00 / 6:00 | attack leaves, and reaches the enemy's hall |
|---|---|---|---|---|---|---|---|
| Brood 1: Six-pool (extreme rush) | 0:50 | 300 | (over) | (over) | (over) | 598 / (over) | 1:03, 1:28 |
| Brood 2: Pool first, one wave, then economy | 1:59 | 150 | 150 | 300 | (over) | 658 / (over) | 2:41, 3:05 |
| Brood 3: Economy (grubs first, two pits, Warren, then a big Raptor wave) | 4:06 | 0 | 0 | 450 | 775 | 976 / 2,650 | 5:33, 5:55 |
| Brood 4: Spitter timing | 2:55 | 75 | 50 | 410 | 800 | 939 / 2,192 | 5:51, 6:14 |
| Brood 5: Brute timing (Gorge Pit) | 3:33 | 0 | 225 | 25 | 325 | 939 / 2,070 | 6:58, - |
| Brood 6: Roost (Bloaters and Skywings) | 3:36 | 0 | 225 | 25 | 500 | 905 / 2,144 | 5:55, 6:18 |
| Brood 7: Forward Burrow (Raptors at their door) | 3:41 | 0 | 75 | 225 | 375 | 598 / 1,227 | 3:41, 4:05 |

### Brood 1: the six-pool (extreme rush)

**The build.** The Spawning Den goes down at once with the starting 250 biomass (so it is really a five-pool: five grubs, one of them becomes the Den), done 0:38. Every egg after that is Raptors; the grubs grow only to eight. The first Raptors hatch at 0:50, six leave at 1:03 and reach the enemy's hall at 1:28 on Ashford Crossing (1:22 on Kestrel Rise), and the rest follow in twos and threes: twelve Raptors at 3:00.

**What it is.** The owner's extreme rush, played faster than his hand-played anchor (Den 1:01, first hit 2:00 to 2:30) because nothing is spent before the Den. It is all-in: eight grubs, no Pen, no second pit.

**How it did.** It does what the owner's anchor asks of a rush and no more: it loses to a wall and wins nothing against a prepared opponent. Against the Crown computer (which walls by 0:40) and the Crown standard, every Raptor died and the Crown lost one Labourer, on Kestrel Rise and on Frostmere alike. It hurts the openings that have no wall: it killed 8 Labourers of the Crown fast expansion, 7 Winders of the Clockwork computer and 4 of the turret expansion, but it ended behind every time, and it lost to the Brood's own economy opening (7:47) and to the Clockwork's Jacks (7:00).

**How to spot it.** A Spawning Den at once, before any new grub; five or six grubs and one Feeding Pit; Raptors at the door before 1:30.

### Brood 2: pool first, one wave, then the economy

**The build.** The Spawning Den and a second Feeding Pit at once, grubs to eight, then two eggs of Raptors (six) that leave at about 2:46 and reach the enemy at about 3:10 on a small map. After the wave: grubs to 15, a Clutch Mound, the Brood Pen, and Raptors non-stop.

**What it is.** A one-wave harassment that buys time and information, then drones. The wave is small (150 worth) and arrives when a standard Crown has three Musketeers behind its wall, so its job is to kill workers caught outside, not to win.

**How it did.** Weak everywhere. Six Raptors at 3:00 meet three Musketeers behind a wall, or Clock Soldiers, and turn back: behind against the Crown computer, lost at 7:36 against the Clockwork computer, behind on Frostmere. Against the Crown fast expansion it killed 4 Labourers and still ended behind; against the Clockwork's Jacks it lost at 5:49.

**How to spot it.** A Den at once but a second pit too, and grubs still coming; six Raptors at about 3:00, not more.

### Brood 3: the economy opening (grubs first)

**The build.** Ten grubs, a second Feeding Pit, the Den, fourteen grubs, a third pit, the Brood Pen, a Clutch Mound, seventeen grubs, the Burrow's upgrade to a Warren (10 eggs), then Raptors from every egg; the wave goes at 30 supply (about 5:50) and reaches a small map's enemy hall at about 6:10.

**What it is.** The greediest Brood opening: no army at all until about 4:30, then the biggest Raptor wave of any opening (30 Raptors by 6:00). It earns 750 by 3:00 and about 2,400 by 6:00 in the calculator, the best Brood economy, but still well under the Crown's standard.

**How it did.** The only Brood opening that holds a rush: it beat the six-pool, and it beat the Clockwork's forward Clocktower outright (it killed 4,510 worth for 675). But its army comes so late that every harassment finds an empty base: the Horseman rush killed 29 grubs, the Balloon drop 26, the Clock Soldier rush 16, the Dragoons 13, the Cannon push 11. It ended behind the Crown computer (its 6:05 wave lost 500 and turned back) and lost to the Clockwork computer at 7:50.

**How to spot it.** Pits and grubs only, the Den late (after about 0:40, with ten grubs), no Raptors at 3:00.

### Brood 4: the Spitter timing

**The build.** Ten grubs, the Den, a pit, the Brood Pen, thirteen grubs, four eggs of Raptors, ten of which are offered up at the Pen for the essence (30), a Clutch Mound, five eggs of Spitters (ten), and the wave at 24 supply or 6:00: ten Spitters and eight Raptors.

**What it is.** The Brood's only ranged and anti-air opening. The Spitter costs little essence (5 an egg of two), but even that has to be bought by offering up Raptors before the first fight, and the wave only goes at 6:00.

**How it did.** The best-fighting Brood timing (its wave killed 480 worth for 395 against the Crown computer), but at 6:00 it is too late to matter: behind against the Crown computer and the Crown standard, lost at 7:00 to the Clockwork computer and at 5:57 to the Jacks standard, which attacked at 3:47 before a single Spitter was out.

**How to spot it.** A Brood Pen early (before 3:00) with Raptors walking into it and vanishing; Spitters at about 5:00.

### Brood 5: the Brute timing

**The build.** As the Spitter timing, but a Gorge Pit (placed about 3:40) instead of Spitters; fourteen Raptors offered up for two Brutes' 40 essence; the wave goes at about 7:00 with two Brutes and nineteen Raptors.

**What it is.** On paper the Brood's armoured push (a Brute: 240 health, armour 2, knocks men back, 1.6 times against buildings). In practice the essence tax makes it the slowest opening of the study: the Gorge Pit is late on the Brood's thin income, and two Brutes cost the price of fourteen Raptors on top of their own.

**How it did.** Not viable today. The two Brutes come after 6:30 and the wave at 7:00 met the Crown's army and turned back without a kill (behind against the Crown computer and the Crown standard); the Clockwork computer won at 7:53 before it ever left. (Its first in-game timing had a Gorge Pit refunded on a blocked site and never placed again; the scripted player now places it again, as a player would.)

**How to spot it.** A Gorge Pit; Raptors being offered up at the Pen; few soldiers before 6:00.

### Brood 6: the Roost (Bloaters)

**The build.** The Den, a pit, the Pen, then the Roost (placed about 3:20); seventeen Raptors offered up for two Bloaters' 50 essence; the wave goes at about 6:20 with two Bloaters and sixteen Raptors.

**What it is.** The owner's "maybe an air rush". The Bloater (50 biomass and 25 essence) floats over cliffs and spits acid from 160, or bursts as an acid bomb; the Skywing (100 and 40) hunts flyers. With essence only from offerings, two Bloaters cost seventeen Raptors, so this is not a rush: it is the slowest way to the slowest wave.

**How it did.** Not viable today. Two Bloaters at about 6:00 killed 150 worth for 325 against the Crown computer and nothing against the Crown standard; the Clockwork computer won at 6:59.

**How to spot it.** A Roost; Raptors being offered up; a Bloater in the sky at about 5:45.

### Brood 7: the forward Burrow

**The build.** Eight grubs, the Spawning Den, then a second Burrow put down two thirds of the way to the enemy (a Burrow needs no swamp; grey fog lets it go anywhere), Raptors from both Burrows. The Burrow costs 350 biomass on the Brood's thin income, so it is placed at about 2:17 and stands at 3:41; the first Raptors leave at 3:41 and reach the hall at 4:05.

**What it is.** The Brood's counterpart of a proxy Barracks: eggs and supply at the enemy's door. It is far too expensive for an opening: the six-pool has twelve Raptors at 3:00, this has none.

**How it did.** Not viable. Behind against the Crown computer and the Crown standard (its wave turned back without a kill), lost at 5:42 to the Clockwork computer. A forward Burrow is a mid-game move (a second front, swamp for Clutch Mounds), not an opening.

**How to spot it.** A Spawning Den, no second pit, and a Burrow growing somewhere on the approach.

### Brood openings not played here

- **Mist Toads or Spore Mothers.** Both come from the Gorge Pit and cost essence (25 and 40), so they are even later than the Brutes.
- **Skywings first.** The Skywing (100 and 40 essence) is the Brood's only answer that reaches a hovering Balloon or a Swift; it is a reaction to an air opening, not an opening.

### The Brood, in short

| Opening | type | beats | loses to | verdict |
|---|---|---|---|---|
| 1. Six-pool | all-in rush | an opponent with no wall | a wall; the Clockwork | viable as a gamble |
| 2. Pool, one wave, economy | harass | nothing measured | everything | weak |
| 3. Economy (grubs first) | greedy | the six-pool, the forward Clocktower | every harassment (Horsemen, Balloon) | viable but fragile |
| 4. Spitter timing | timing | (best Brood fight) | everything, it comes at 6:00 | too late |
| 5. Brute timing | timing | nothing | everything | not viable |
| 6. Roost (Bloaters) | air | nothing | everything | not viable |
| 7. Forward Burrow | proxy | nothing | everything | not viable |

The owner's feeling is right: the Brood has two openings that work (the six-pool as a gamble and the grubs-first economy), and only the economy holds a rush. Everything past the Spawning Den costs essence, and before the first fight essence only comes from offering up Raptors at 12% of their price. That tax makes every tech opening a minute or more late (see the gaps and the recommendations).

## The Clockwork's openings (provisional: the faction is being rebuilt)

Seven openings of the new Clockwork were written down and played. Everything here is provisional twice over: the faction's roster is still growing (the Spring Catapult and the Great Winder are next), and its economy is being rebuilt in the wt-econ branch. So each opening is given twice: measured in the game as it is today, and from the calculator with the rebuilt economy (`--preset econ28`).

| Opening | first soldier | army at 3:00 | 4:00 | 5:00 | 6:00 | earned by 3:00 / 6:00 | attack leaves, and reaches the enemy's hall |
|---|---|---|---|---|---|---|---|
| Clockwork 1: Clock Soldier rush (two Works) | 1:02 | 630 | 1,120 | 1,540 | 1,960 | 1,409 / 4,194 | 1:50, 2:36 |
| Clockwork 2: Jacks (Mainspring and Escapement), the standard | 1:43 | 480 | 980 | 1,530 | (over) | 2,487 / (over) | 3:45, 4:27 |
| Clockwork 3: Turret and a second Clocktower | 1:50 | 350 | 630 | 1,190 | 2,170 | 2,461 / 8,062 | none |
| Clockwork 4: Swifts into Ticking Owls | 1:43 | 140 | 500 | 1,055 | 1,745 | 2,469 / 5,348 | 4:59, 5:44 |
| Clockwork 5: Fast Jacks (Escapement first) | 2:00 | 400 | 700 | 1,120 | 1,595 | 1,407 / 3,750 | 3:04, 3:46 |
| Clockwork 6: Pendulum and Netter push (tier 3) | 1:47 | 340 | 875 | 1,425 | 1,860 | 2,487 / 5,270 | 4:54, 5:40 |
| Clockwork 7: Forward Clocktower (Clock Soldiers at their door) | 3:22 | 0 | 280 | 840 | 1,710 | 2,408 / 5,387 | 4:00, 4:16 |

With the rebuilt economy (calculator, Kestrel Rise):

| Opening | army at 3:00 | 4:00 | 5:00 | 6:00 | earned by 3:00 / 6:00 | attack leaves, and arrives |
|---|---|---|---|---|---|---|
| Clockwork 1: Clock Soldier rush | 560 | 910 | 1,470 | 1,960 | 1,206 / 3,125 | 1:54, 2:34 |
| Clockwork 2: Jacks (the standard) | 280 | 882 | 1,345 | 1,935 | 1,673 / 3,690 | 4:24, 5:04 |
| Clockwork 3: Turret and a second Clocktower | 140 | 420 | 700 | 980 | 1,768 / 5,340 | none |
| Clockwork 4: Swifts into Ticking Owls | 140 | 222 | 585 | 1,335 | 1,656 / 4,063 | 5:27, 6:11 |
| Clockwork 5: fast Jacks | 225 | 675 | 900 | 1,238 | 1,110 / 2,377 | 3:38, 4:13 |
| Clockwork 6: Pendulum and Netter push | 140 | 378 | 1,045 | 1,632 | 1,689 / 3,721 | 5:59, 6:54 |
| Clockwork 7: Forward Clocktower | 0 | 280 | 840 | 1,400 | 1,432 / 3,602 | 4:00, 4:13 |

The rebuild costs the slow, worker-heavy openings the most (the Jacks, the Pendulums, the second Clocktower: half a minute to a minute later and a quarter to a half less army at 3:00 and 4:00) and the cheap rush the least (the Clock Soldier rush uses few Winders, so a press that needs more of them barely touches it). Even rebuilt, the Clockwork earns the most of the three by 3:00. One reason is not in the price list at all: a Winder only carries the crate to the site (about 9 seconds) and goes back to his press while the building unfolds itself, whereas a Labourer stays on the site for the whole build (a Barracks takes one off the farm for about a minute) and a grub is used up. The Clockwork's builders cost it almost nothing (design_principles.md section 3: builders must have an opportunity cost).

### Clockwork 1: the Clock Soldier rush (two Works)

**The build.** Five Winders. A Movement Works and a Regulator at once, a second Works at 0:22, Clock Soldiers from both without a stop. Six leave at about 1:54 and reach the enemy's hall at about 2:34 on a small map; nine at 3:00, sixteen at 4:00. The second press and more Winders come after the wave.

**What it is.** The fastest strong army in the game: 630 worth at 3:00, twice the Crown's best and the Brood's best. The Movement Works needs nothing before it and costs 150, and the Clock Soldier (70 cogs: 90 health, armour 1, a Musketeer's damage up close) is cheap for what it is. Its limit is the wind: the soldiers arrive with half their wind on a small map (about 40 seconds of fighting left), a third on the big ones.

**How it did.** Strong, but not in the way a rush should be: at the walls it fails, and it wins on the economy behind it. Against the Crown standard and the Crown computer the soldiers turned back without a kill (350 to 420 lost) and the Clockwork still ended ahead, on both map sizes. Without a wall to stop it, it hurts: 8 grubs of the Brood computer, 16 of the Brood's economy opening. Against the Crown fast expansion it was even, and against its own faction's Jacks standard it lost the trade (380 killed for 1,170) and ended behind.

**How to spot it.** Two Movement Works and no second press; Clock Soldiers on the road before 2:00.

### Clockwork 2: Jacks (the standard)

**The build.** Seven Winders, a second Cog Press and a Movement Works at once, the Mainspring (with three Winders) at about 0:50, the Escapement meshed with it at about 1:35 (working at about 2:20), two Clock Soldiers, then Jacks from the first Works, a second Works with Clock Soldiers and a Ratchet Turret. The first wave goes at 16 supply, at about 3:55, and reaches a small map's enemy hall at about 4:35.

**What it is.** The Clockwork's balanced opening, the counterpart of the Crown's standard: a little army early, tech by 2:20, a turret at home. The Jack (ranged, hits flyers, jumps 5 tiles) is the first Tension unit. Today it floats money (800 to 1,500 cogs in the bank at 4:00 to 6:00 in the calculator): the economy is bigger than two Works can spend.

**How it did.** The strongest opening in the study. It won against the Brood computer at 6:11 and against the Crown standard at 7:55; it ended ahead of the Crown computer (13 Labourers killed) and even on Frostmere; it beat the six-pool, the one-wave Brood, the Spitter timing, the Horseman rush (both kinds), the Balloon drop and raid (Jacks shoot flyers), and its own Clock Soldier rush. Nothing in the study beat it.

**How to spot it.** A Mainspring and an Escapement side by side by 1:40; Jacks hopping at the front at about 2:30.

### Clockwork 3: the Ratchet Turret and a second Clocktower (the fast expansion)

**The build.** Seven Winders, the second press and a Movement Works, a second Clocktower at about 1:05 (done about 2:15), a Ratchet Turret, Clock Soldiers from the one Works, Winders to 14 and the new tower's two presses. Then the computer's Economy plan takes over.

**What it is.** The Clockwork's greedy opening: by far the most cogs of any opening in the study (about 8,000 by 6:00 today). The turret covers the home base; the new tower starts its own gear field, so it also stretches the ground on which the Clockwork's army stays wound.

**How it did.** Ahead of everything it met: the Crown computer, the Brood computer (23 grubs killed), the six-pool (it lost 4 Winders and still ended ahead), the Horseman rush (it lost nothing that mattered) and the Crown's Cannon push. The Ratchet Turret and the economy carry it; a greedy opening should be punishable, and today nothing in the study punished this one.

**How to spot it.** A second Clocktower going down at about 1:05; a Ratchet Turret; few soldiers.

### Clockwork 4: Swifts into Ticking Owls (air)

**The build.** The standard to the Escapement, then the Clock Aviary (working at about 3:15), a second Mainspring for the Tension, two Swifts, the TICKING OWL research (150 cogs and 150 Tension, a minute), a Ratchet Turret, two more Swifts, and three of them morphed into Owls (100 cogs and 50 Tension each, 20 seconds). The Owls go at about 5:15 and reach a small map's enemy base at about 6:00.

**What it is.** The Clockwork's air opening: Owls swoop on units and drop bombs on buildings (45 to every building around the impact). They wind down off the gear field like every construct, but they fly the straight line over cliffs. Tension is the bottleneck: three Owls with their research cost 345 Tension, nearly three minutes of a full Mainspring, hence the second one.

**How it did.** Ahead against the Crown computer, the Brood computer (on Kestrel Rise and on Frostmere: the Owls fly the straight line, so the big map hurts them least) and the Brood's economy; even against the Crown standard, whose Musketeers shoot flyers.

**How to spot it.** A Clock Aviary (a tall narrow clock tower) by about 2:30; two Mainsprings; Swifts in the air from about 3:30.

### Clockwork 5: fast Jacks (the Escapement first)

**The build.** Seven Winders, a Movement Works and a Mainspring at once, the Escapement as soon as the Works stands (working at about 1:42), Jacks from the first Works and a second Works for more. Four or five Jacks go at about 3:00 and reach a small map's enemy hall at about 3:35.

**What it is.** A ranged rush: Jacks out-range Raptors, Clock Soldiers and Horsemen and can jump away from them, and they shoot flyers. It skips the second press, so its economy is the thinnest of the Clockwork's (1,400 cogs by 3:00), and Tension (25 a Jack, 2 a second from one Mainspring) caps it at about one Jack every 12 seconds.

**How it did.** The one Clockwork opening that lost a fight it picked: the Jacks walked into the Crown computer's wall and Musketeers and lost 600 worth for 120 (behind). Even against the Crown standard; ahead against the Brood computer (11 grubs). Its thin economy (one press) is what the Crown punishes.

**How to spot it.** A Mainspring and an Escapement before 1:00, one press; Jacks on the road at about 3:00.

### Clockwork 6: the Pendulum and Netter push (tier 3)

**The build.** The standard to the Escapement, a second Works, the first Works swapped to its big gear (25 cogs, 4 seconds: the Pendulum is made only there), two Pendulums, a Netter, Clock Soldiers from the second Works and a third Pendulum. The push goes at 24 supply, at about 5:00, and reaches a small map's enemy hall at about 6:00.

**What it is.** The new tier 3 as an opening. A Pendulum cuts every enemy in the arc in front of it (22 a swing to each), the natural answer to a swarm of Raptors or a tight musket line; the Netter holds the most dangerous enemy in place for 4 seconds. The Pendulum is slow (46), and that meets the wind: on Kestrel Rise it arrives with about a third of its wind, on Frostmere with almost none (2%). Today this opening only works on small maps.

**How it did.** Even against the Crown computer on both maps and against the Crown standard: Musketeers outrange the slow Pendulums and pick them off on the walk, so the push trades about even. Ahead against the Brood computer and the Brood's economy (the Pendulum's arc is made for a Raptor swarm).

**How to spot it.** The standard's Escapement, then a Movement Works with a big gear ring; tall Pendulums in the army from about 3:30.

### Retired: the Assembly Works and Wind-up Soldiers

Until 0.14.31 a Clockwork player could still put down the old Assembly Works and open with Wind-up Soldiers (three for 75 cogs): twelve of them left at 1:47 on 0.14.27 against a sleeping opponent. They run on a spring, not on wind, and freeze 50 seconds off the gear field, so twelve reached a small map's enemy hall with a fifth of their spring left and a big map's with none. 0.14.31 retired the Assembly Works, so this opening no longer exists and was dropped from the study.

### Clockwork 7: the forward Clocktower

**The build.** Seven Winders, the second press, then a Clocktower put down two thirds of the way to the enemy (placed 0:54, standing 2:22); it starts its own gear field, and a Regulator and two Movement Works mesh with it there. Clock Soldiers come out at the enemy's door: the attack leaves at 4:00 and arrives 16 seconds later with almost all its wind (the calculator: 84% on Kestrel Rise, the same on any map).

**What it is.** The Clockwork's answer to its own wind: soldiers made where they fight do not run down on the walk, so it plays the same on Frostmere as on Kestrel Rise. It is late for a rush (first soldier 3:22), but the forward field also winds every later soldier.

**How it did.** Ahead against the Crown computer on both maps and against the Crown standard; ahead against the Brood computer. Its first wave turned back every time; it won on the economy and the reinforcements. It lost to the Brood's economy opening, whose Raptor wave found the forward base and killed 4,510 worth: a forward Clocktower is exposed.

**How to spot it.** One press short, no Movement Works at home at 2:00, a Winder missing; gears turning on the approach.

### Clockwork openings not played here

- **Big-gear presses.** A press swapped to its big gear takes six Winders and pays 10.5 cogs a second: an economy choice for a second hall, not an opening of its own.

### The Clockwork, in short

| Opening | type | beats | loses to | verdict |
|---|---|---|---|---|
| 1. Clock Soldier rush | rush | anything without a wall | a wall (but wins later on economy); its own Jacks | viable |
| 2. Jacks | standard | everything in the study | nothing in the study | dominant |
| 3. Turret and a second Clocktower | greedy | everything it met | nothing in the study | viable, too safe |
| 4. Swifts into Owls | air | the Brood | (even with the Crown standard) | viable |
| 5. Fast Jacks | ranged rush | the Brood | a walled Crown | viable against the Brood |
| 6. Pendulum and Netter push | tier 3 | the Brood | (even with the Crown) | viable on small maps |
| 7. Forward Clocktower | proxy | the Crown | the Brood's economy | viable, the answer to big maps |

The Clockwork has the most openings, six or seven that work, and that is the problem in reverse: they all work because the economy behind them is twice the others'. The Jacks standard is dominant, and a greedy turret expansion is never punished. All of this is provisional: the economy rebuild (wt-econ) is measured below.

RESULTS_SECTION

GAPS_SECTION

RECOMMENDATIONS_SECTION

## The calculator against the game

Each opening was timed twice: by the calculator and by the scripted player in a real headless match against a sleeping opponent on Ashford Crossing. The table shows how far apart the two put each step of the script (when a building is finished, or when a step is started), and the army and the gold earned at 3:00 and 6:00. "(over)" means the match had already been won by then.

| Opening | steps compared | apart on average | at most | army at 3:00, game / calculator | at 6:00 | earned by 3:00, game / calculator | by 6:00 |
|---|---|---|---|---|---|---|---|
| Crown 1: Musketeer wall into the Cannon (the standard) | 9 | 4 s | 9 s | 180 / 195 | 770 / 820 | 760 / 1,140 | 3,040 / 3,040 |
| Crown 2: Horseman rush | 8 | 2 s | 6 s | 345 / 345 | (over) / 920 | 1,140 / 1,140 | (over) / 2,660 |
| Crown 3: Musketeers and a Balloon drop | 9 | 3 s | 5 s | 180 / 260 | (over) / 915 | 1,140 / 1,140 | (over) / 2,280 |
| Crown 3b: Balloon raid (the Musketeers fire from the basket) | 9 | 3 s | 4 s | 180 / 260 | 845 / 915 | 1,140 / 1,140 | 2,660 / 2,280 |
| Crown 4: Wall and a second Town Hall | 7 | 10 s | 32 s | 0 / 0 | 540 / 715 | 1,140 / 1,520 | 4,180 / 5,320 |
| Crown 5: Dragoon raid (the wall and the Mill, then a Breeder and Dragoons) | 8 | 5 s | 10 s | 0 / 0 | (over) / 715 | 760 / 1,140 | (over) / 3,040 |
| Crown 6: Cannon and Musketeer push (the standard, then a timing attack) | 10 | 6 s | 27 s | 180 / 195 | 920 / 860 | 760 / 1,140 | 2,660 / 3,040 |
| Brood 1: Six-pool (extreme rush) | 3 | 1 s | 4 s | 300 / 300 | (over) / 675 | 598 / 608 | (over) / 1,234 |
| Brood 2: Pool first, one wave, then economy | 7 | 5 s | 9 s | 150 / 150 | (over) / 675 | 658 / 618 | (over) / 1,933 |
| Brood 3: Economy (grubs first, two pits, Warren, then a big Raptor wave) | 8 | 7 s | 18 s | 0 / 0 | 775 / 1,050 | 976 / 1,024 | 2,650 / 2,781 |
| Brood 4: Spitter timing | 9 | 8 s | 18 s | 75 / 75 | 800 / 975 | 939 / 964 | 2,192 / 2,347 |
| Brood 5: Brute timing (Gorge Pit) | 10 | 17 s | 41 s | 0 / 0 | 325 / 645 | 939 / 963 | 2,070 / 2,335 |
| Brood 6: Roost (Bloaters and Skywings) | 9 | 4 s | 14 s | 0 / 0 | 500 / 600 | 905 / 909 | 2,144 / 2,264 |
| Clockwork 1: Clock Soldier rush (two Works) | 6 | 5 s | 11 s | 630 / 630 | 1,960 / 2,170 | 1,409 / 1,409 | 4,194 / 4,274 |
| Clockwork 2: Jacks (Mainspring and Escapement), the standard | 11 | 7 s | 14 s | 480 / 462 | (over) / 2,108 | 2,487 / 2,412 | (over) / 5,292 |
| Clockwork 3: Turret and a second Clocktower | 7 | 3 s | 6 s | 350 / 350 | 2,170 / 1,120 | 2,461 / 2,446 | 8,062 / 8,181 |
| Clockwork 4: Swifts into Ticking Owls | 16 | 13 s | 20 s | 140 / 140 | 1,745 / 1,545 | 2,469 / 2,444 | 5,348 / 5,324 |
| Clockwork 5: Fast Jacks (Escapement first) | 8 | 5 s | 8 s | 400 / 562 | 1,595 / 1,800 | 1,407 / 1,402 | 3,750 / 3,166 |
| Clockwork 6: Pendulum and Netter push (tier 3) | 11 | 7 s | 14 s | 340 / 378 | 1,860 / 2,052 | 2,487 / 2,444 | 5,270 / 5,324 |
| Crown 7: Proxy Horseman rush | 6 | 3 s | 6 s | 270 / 230 | (over) / 920 | 1,140 / 1,140 | (over) / 2,660 |
| Brood 7: Forward Burrow (Raptors at their door) | 3 | 8 s | 21 s | 0 / 0 | 375 / 450 | 598 / 608 | 1,227 / 1,234 |
| Clockwork 7: Forward Clocktower (Clock Soldiers at their door) | 4 | 13 s | 26 s | 0 / 0 | 1,710 / 1,400 | 2,408 / 2,185 | 5,387 / 5,040 |

(all openings: 178 steps, 7 s apart on average, half of them within 4 s, 9 in 10 within 18 s)

The fitted constants are at the top of tools/study/bo_calc.py (CAL): a Labourer walks about 7 seconds to a site and 7 back and stays for the whole build; a grub reaches its site in about 2 seconds and morphs in 1.6; a Winder fetches the crate in about 9 seconds and is back at his press 5 seconds after it lands; a grub earns 0.58 biomass a second on the starting pit and 0.62 on the others. The gold earned differs most for the Crown at 3:00 (the calculator's third harvest falls just before 3:00, the game's just after: one lump of 380) and for the fast expansion at 6:00 (the calculator crews the new hall's farms faster than the game does). The calculator does not fight, and after the script's last step it only keeps the last background training going while the real computer switches to its own plan, so the two are compared up to the end of the script.

## How to run the tools

All from the worktree root (export PATH=$PATH:/home/claude/godot first). The folders below are examples; any folder will do.

- The rule numbers (only after a balance change): `godot --headless --fixed-fps 30 --script res://tools/study/bo_dump.gd -- defs out:/tmp/bo/defs.json`; the map distances (only after a map change): the same with `map:<id> seed:1 out:/tmp/bo/maps/<id>_1.json` for each map; then `python3 tools/study/bo_data.py --defs /tmp/bo/defs.json --maps /tmp/bo/maps`.
- The calculator: `python3 tools/study/bo_calc.py crown_horse_rush` for one build, `--map kestrel_rise` for one map, `--all` for a summary of every build, `--travel` for the walking table, `--vs crown_horse_rush brood_economy` for a rough fight estimate when an attack lands, `--steps "workers:8,horse_breeder,cottage,barracks,horseman*3,attack" --faction crown` for a build of your own, `--set PATH=VALUE` to try a change (for example `--set factions.brood.start_res2=40`), and `--preset econ28` for the provisional Clockwork economy.
- One match: `godot --headless --fixed-fps 30 --script res://tools/study/bo_match.gd -- sa:crown_horse_rush sb:ai:balanced b:brood map:kestrel_rise seed:1 end:480 out:/tmp/bo/m.json`. A side is a build name, `ai:<plan>` (the ordinary computer) or `idle` (a sleeping opponent).
- Many matches: `python3 tools/study/bo_run.py calib --out /tmp/bo/calib --end 420` and `python3 tools/study/bo_run.py matrix --out /tmp/bo/runs --end 480`, with `--part key,vs_ai` for parts of the list (key, vs_ai, duels, big, vs_brood_ai, base), `--jobs 2` for two matches side by side and `--max-procs 2` to keep at most two of them running whoever started them (a shared machine runs out of memory with too many Godot processes, and the kernel then kills one: its match leaves no result and is played again on the next run). It is resumable: finished matches are skipped, and several runners can share a folder (a match being played has a .lock file); touch STOP in the folder to stop after the current matches. Then `python3 tools/study/bo_report.py --runs /tmp/bo/runs` for the tables, `--notes` for one line per match, `--calib` for the timing table and `--compare` for the calculator against the game.
- The step grammar of a build order is described at the top of tools/study/bo_ai.gd.
