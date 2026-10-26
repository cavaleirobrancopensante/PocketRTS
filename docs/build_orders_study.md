# Build orders: what each faction can open with

A study of Holdfast v0.14.22, 26 October 2026. The question (the owner's): what build orders does each faction have? He wants variety: at least three distinct openings that work for each faction, and four would be very healthy.

RESULTS_SUMMARY

## How this was measured

Three tools were written for this study. They live in tools/study, and none of them changes the game.

- **A timing calculator** (tools/study/bo_calc.py). Give it a build order and it plays the opening out second by second: when each step is placed and finished, the army at minutes 3, 4, 5 and 6, and when the attack reaches the enemy's ramp and hall on each standard map. Its numbers are read from the game itself (tools/study/bo_dump.gd writes them to tools/study/bo_data.json), and a few walking and hand-over times were fitted to real matches. Checked against the game, its step times are off by about 2 to 10 seconds on average, a little more for builds where workers are pulled off the farm many times. It also takes "what if" changes, for example `--set units.spitter.cost2=0`, which is how the recommendations below were sized.
- **A scripted player** (tools/study/bo_ai.gd). It is the game's own Hard computer, but it follows a written build order step by step, then plays on as the ordinary computer. Its workers, its defence at home, its fighting and its micro are the computer's own; only the build and the first attack are scripted. The build orders are in tools/study/build_orders.json, the same file the calculator reads.
- **A match runner** (tools/study/bo_match.gd, bo_run.py and bo_report.py). One headless match at a time; each writes what happened when.

Every opening was played four ways:
1. against a sleeping opponent, to time it (Ashford Crossing);
2. against the ordinary Hard computer (the Balanced plan) of both other factions, on Kestrel Rise, the smallest standard map;
3. against other openings, where a direct answer was needed (rush against greed, and so on);
4. some again on Frostmere, a big map, where the walk matters.

Read the match results as indications, not proof. Both sides are played by the computer, which defends and fights the way it does; there is one game per pairing (two for some); and the machine was shared with three other jobs, so the list of matches was kept short. The timings, on the other hand, are solid: the calculator and the game agree on them.

## The three starts and economies

| | Crown | Brood | Clockwork |
|---|---|---|---|
| Start | 300 gold, 4 Labourers, a Farm already 60% grown, the Town Hall (10 supply) | 250 biomass, 5 grubs, a Feeding Pit, the Burrow (16 supply, 5 eggs) | 300 cogs, 4 Winders, a Cog Press, the Clocktower (10 supply) |
| How the money comes | A Farm ripens into a 380-gold harvest: every 40 seconds with 8 Labourers, every 70 with 4, every 267 with nobody. So it comes in lumps. A Mill hand grinds a third of a powder a second | Each grub earns about 0.58 biomass a second on the starting pit, about 0.62 on pits farther out | A Cog Press pays 1.2 cogs a second by itself and 2.3 more for each Winder on it, up to 3: 8 a second with a full crew. A Mainspring winds 0.3 Tension a second alone, 2 with 3 Winders |
| Per worker, roughly | 1 gold a second (60 a minute) | 0.6 biomass a second (35 a minute) | 2.3 cogs a second (136 a minute) |
| Earned by 3:00 (measured) | 760 to 1,140 gold | 600 to 750 biomass | 1,400 to 2,500 cogs |
| Earned by 6:00 (measured) | 1,500 to 4,200 gold | 1,850 to 2,350 biomass | 2,850 to 8,100 cogs |
| Making the army | One unit at a time per Barracks (a Musketeer takes 15 seconds) | Eggs: each Burrow lays one every 9 seconds (a little faster with Clutch Mounds) and holds 5; every unit, grubs included, takes an egg, and all eggs hatch at the same time | One unit at a time per Movement Works (a Clock Soldier takes 16 seconds) |
| The land runs out | 9,000 gold of soil per Town Hall; a new hall brings fresh soil | 10,500 biomass of ground at the capital, for the whole game: other Burrows have no ground | 11,400 brass per Clocktower; spent brass still pays a quarter, forever |

The measured ranges come from the openings below, played against a sleeping opponent. The Clockwork's lowest figure is its Clock Soldier rush, which keeps only one press.

### How long the walk is

The table gives the walking distance from a side's rally point to the enemy's Town Hall, Burrow or Clocktower, and the time it takes. The distances were measured with the game's own pathfinder on each standard map. A Clockwork soldier slows down as it runs down away from its gear field, and stops when its wind is gone (about 83 seconds after it leaves the field); the column shows how much wind a Clock Soldier still has when it arrives.

TRAVEL_TABLE

Two things follow. First, a Raptor or a Horseman crosses any standard map in 20 to 35 seconds, so the Brood's and the Crown's fast rushes hit about the same time everywhere. Second, the Clockwork's ground army arrives with half its wind on the small maps and with less than a third on Frostmere, Hollowfen and Saltmarsh Isles: it has 20 to 25 seconds of fighting left there before it freezes. The Clockwork's attacks are short-range by design (a clock runs down), and on big maps this decides its openings.

### What the early units are worth

| Unit | price each | supply | health and armour | reach | damage a second | speed |
|---|---|---|---|---|---|---|
| Musketeer | 60 gold + 10 powder | 1 | 70, armour 0 | 190 | 5.6 at range, 11.6 with the bayonet | 62 |
| Horseman | 155 with its horse | 3 | 140, armour 1 | 26 | 11.2, and one 30-damage pistol shot | 112 |
| Dragoon | 100 + 10 powder with its horse | 1 | 90 mounted | 190 on foot | a Musketeer's, after it gets off | 112 |
| Field Cannon | 210 with its horse | 4 | 140, armour 1 | 430 | 5.9, splash, more against buildings | 38 |
| Raptor | 25 (75 for three) | 1 | 36 | 22 | 4.4 | 108 |
| Spitter | 45 + 2.5 essence (two for 90 + 5) | 1 | 70 | 150 | 3.0, its acid strips 2 armour | 68 |
| Brute | 150 + 20 essence | 3 | 240, armour 2 | 28 | 10.8, knocks back | 56 |
| Bloater | 50 + 25 essence | 1 | 60, flies | 160 | 2.3, or a big acid burst | 44 |
| Clock Soldier | 70 cogs | 1 | 90, armour 1 | 22 | 5.3 | 62 |
| Jack | 100 cogs + 25 Tension | 2 | 90, armour 1 | 170 | 7.1, and a 5-tile jump | 70 |
| Swift | 75 + 15 Tension | 2 | 90, flies | 28 | 8.5, only at flyers | 118 |
| Ticking Owl | 175 + 65 Tension, as a Swift plus the morph | 4 | 220, armour 1, flies | 28 | 10 on units, 15 on buildings | 56 |
| Wind-up Soldier | 25 (75 for three) | 1 | 55, armour 1 | 24 | 4.4, freezes 50 seconds off the field | 66 |

(Damage a second is the blow divided by the time between blows, about the cooldown plus the aim plus a third of a second.)

CROWN_SECTION

BROOD_SECTION

CLOCKWORK_SECTION

RESULTS_SECTION

GAPS_SECTION

RECOMMENDATIONS_SECTION

## The calculator against the game

Each opening was timed twice: by the calculator and by the scripted player in a real (headless) match against a sleeping opponent on Ashford Crossing. The table shows how far apart the two are, on average and at worst, for the steps taken before the script hands over to the ordinary computer, and the money earned by 3:00 and 6:00 in each.

CALIBRATION_TABLE

The fitted constants are at the top of bo_calc.py (CAL): a Labourer walks about 7 seconds to a site and 7 back; a grub reaches its site in about 2 seconds and morphs in 1.6; a Winder fetches the crate in about 9 seconds; a grub earns 0.58 a second on the starting pit and 0.62 on the others. The calculator does not model fighting, and it keeps the last background training going after the script ends, while the real computer switches to its own plan, so compare the two only up to the end of the script.

## How to run the tools

All from the worktree root, one Godot process at a time (export PATH=$PATH:/home/claude/godot first):

- The rule numbers and map distances (only after a balance change): `godot --headless --fixed-fps 30 --script res://tools/study/bo_dump.gd -- defs out:/tmp/bo/defs.json`, then the same with `map:<id> seed:1 out:/tmp/bo/maps/<id>_1.json` for each map, then `python3 tools/study/bo_data.py --defs /tmp/bo/defs.json --maps /tmp/bo/maps`.
- The calculator: `python3 tools/study/bo_calc.py crown_horse_rush`, `--map kestrel_rise`, `--all` for a summary of every build, `--vs crown_horse_rush brood_economy` for a rough fight estimate when an attack lands, `--steps "workers:8,horse_breeder,cottage,barracks,horseman*3,attack"` with `--faction crown` for a build of your own, and `--set PATH=VALUE` to try a change.
- One match: `godot --headless --fixed-fps 30 --script res://tools/study/bo_match.gd -- sa:crown_horse_rush sb:ai:balanced b:brood map:kestrel_rise seed:1 end:480 out:/tmp/bo/m.json`. A side is a build name, `ai:<plan>` (the ordinary computer) or `idle` (a sleeping opponent).
- Many matches: `python3 tools/study/bo_run.py calib --out /tmp/bo/calib` and `python3 tools/study/bo_run.py matrix --out /tmp/bo/runs`, then `python3 tools/study/bo_report.py --runs /tmp/bo/runs` for the tables (`--calib` for the timing table).
- The step grammar of a build order is described at the top of tools/study/bo_ai.gd.
