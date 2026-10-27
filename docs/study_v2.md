# Balance study v2: how to run it

The owner asked for 400 games on today's game: 300 to test the new economy (100 for each match-up, every side opening with one of its faction's documented build orders, then the Hard computer playing on) and 100 exploratory games that look for outlier openings nobody wrote down. Four machines play 100 games each. This page is the runbook for those machines, what the tools do, and the check of every build order on today's rules.

Nothing in the game changes: the tools live in tools/study and only read the game and drive the computer players the way a player would. The game version the tools were built and checked on is 0.14.47 (main with the Brood AI fixes, ground attack with rotting bodies and the Clock Soldier's west views merged). The branch does not bump the game version: it changes no game file, and the version in every game's record says which game was measured.

## The four machines

| machine | plays | folder for its data |
|---|---|---|
| m1 | Crown against Brood, 100 games | docs/study_v2/data/m1/ |
| m2 | Crown against Clockwork, 100 games | docs/study_v2/data/m2/ |
| m3 | Brood against Clockwork, 100 games | docs/study_v2/data/m3/ |
| m4 | 100 exploratory games (the outlier search) | docs/study_v2/data/m4/ |

### Setup (each machine)

1. Clone the repo and check out the branch: `git clone https://github.com/holdfastrts/Holdfast && cd Holdfast && git checkout study-v2`.
2. Get Godot 4.7 stable for Linux (Godot_v4.7-stable_linux.x86_64, from the godotengine/godot-builds releases, file Godot_v4.7-stable_linux.x86_64.zip), unzip it and point `GODOT` at it: `export GODOT=/path/to/Godot_v4.7-stable_linux.x86_64` (or put it on the PATH as `godot`).
3. Import the project once (a few minutes): `$GODOT --headless --path . --import 2>&1 | head -c 20000000 | tail -3`.
4. Python 3 is enough: the runner and the report tools use the standard library only.

### Run

One command per machine does its whole share and then aggregates it:

```
tools/study/machine_v2.sh m1        # Crown v Brood        (m2: Crown v Clockwork, m3: Brood v Clockwork, m4: explore)
```

It keeps its working files in `~/study_v2_runs/<machine>` (a second argument picks another folder). Under it, the commands are:

```
python3 tools/study/run_study_v2.py --mode openings --pair crown,brood --games 100 --out ~/study_v2_runs/m1
python3 tools/study/run_study_v2.py --mode openings --pair crown,clockwork --games 100 --out ~/study_v2_runs/m2
python3 tools/study/run_study_v2.py --mode openings --pair brood,clockwork --games 100 --out ~/study_v2_runs/m3
python3 tools/study/run_study_v2.py --mode explore --games 100 --out ~/study_v2_runs/m4
```

- At most two games run at once (`--workers 2`, the default): the machines have about two cores.
- Run it under `nohup` (or in tmux) so it survives a closed terminal: `nohup tools/study/machine_v2.sh m1 > ~/m1.out 2>&1 &`.
- It is resumable: a game is done once its `games/<id>.json` exists. Run the same command again after a crash or a reboot and it carries on. To stop cleanly, `touch ~/study_v2_runs/m1/STOP`: the games under way finish, no new one starts (delete STOP before starting again).
- A game whose process dies or runs past an hour of real time is written to `failures.jsonl` and played once more; after two failures it is skipped. The explorer plays a game it had already drawn exactly as drawn.
- Every Godot run's output goes through `head -c 20000000` into `proc/<id>.txt`, which is deleted when the game is fine, so a looping script error cannot fill the disk.
- Progress is in `run.log` (one line a game). `ls ~/study_v2_runs/m1/games | wc -l` counts the finished games.

### Aggregate and hand in the data

`machine_v2.sh` aggregates when its games are done; to do it by hand (for example part way through):

```
python3 tools/study/report_v2.py aggregate --runs ~/study_v2_runs/m1 --machine m1
```

That fills `docs/study_v2/data/m1/` with:
- `games/*.json` (one per game: setup, result, cause, per side the opening and the scripted player's step record, totals, waves) and `ts/*.csv` (each side every 30 game seconds), copied as they are;
- `logs.tar.gz`: the match logs, compressed into one file;
- on m4 also `explore.tar.gz` (the explorer's working folder), `candidates.json` (every candidate's full script, parent, origin and mutations) and `explore_specs.json` (each game's draw);
- `csv/`: tools/study/aggregate.py's tables (games, sides, timeseries, waves, events) with the openings added, plus `openings.csv` (one row per scripted side: steps done, timed out, skipped or lost, when the script handed over and why, the scripted attacks), `steps.csv` (one row per step) and `snaps.csv` (army, workers, bank and income at 3, 5, 7, 10, 15 and 20 minutes);
- `run.log` and `failures.jsonl`.

Commit that folder on the branch (docs is .gdignored, so Godot never imports the CSVs) and push it, or copy it to the coordinating machine: `git add docs/study_v2/data/m1 && git commit -m "Study v2 data: m1" && git push`. A full machine's folder should be some 25 to 40 MB (the games and time series are small; the logs are compressed).

### The report

Once the four folders are in docs/study_v2/data/, one command writes the report, docs/ai_balance_study_v2.md:

```
python3 tools/study/report_v2.py combine
```

It is plain prose with small tables, for reading aloud: win rates per match-up with 95% ranges (and a hint by map); win rates per opening, against each faction, and per pair of openings where a pair has five games or more; whether the scripts ran as written; the economy by faction at 5, 10, 15 and 20 minutes (income, bank, workers, army) beside the first study's numbers (docs/study_data); game lengths and how games ended; and, from m4, each faction's best candidates, the outliers in detail (their scripts, every game they played, the army at 5:00 against the documented openings', their attacks) and which kinds of mutation paid. It runs on any subset of the folders, so it can be run while machines are still playing.

## Time per game

MEASURED_TIMES

## What the tools are

- **tools/study/study_game_v2.gd**: one headless game. It is tools/study/study_game.gd (the first study's game, with its full recording: games/<id>.json, ts/<id>.csv every 30 s, logs/<id>.log, the computer's own gg rule, the 30-minute cap, the 1.25x power rule at the cap), plus `oa:<build>` and `ob:<build>`: that side opens with the build and then the Hard computer plays on with the build's "then" plan. A side without a build is the plain Hard computer on `pa:` / `pb:`; `idle` is a sleeping opponent (for timing only). `builds:<file>` adds builds from another file (the explorer's candidates). Per side it records the opening's name, each step's first try, issue time, the time a building it placed stood, and its status (done, skipped, timed out, lost and placed again, or still pending at the end), when the script ended and why, the scripted attacks and drops, and the army, workers and bank at 3, 5, 7, 10, 15 and 20 minutes.
- **tools/study/bo_ai_v2.gd**: the scripted player (tools/study/bo_ai.gd, a subclass of the game's computer) with the fuller record and two time limits: a step that waits three minutes is given up and the next goes on (a "wait:" step and an attack with its own deadline never are), and the script hands over at 12:00 at the latest. Two of its placement rules follow today's Clockwork rules (see the build check below).
- **tools/study/run_study_v2.py**: the batch runner, modes `openings`, `explore` and `check`. In `openings`, game n of a pair is on map n of the first study's twelve (Greenhold, Frostmere, Ashford Crossing, Amberfall Vale, Kestrel Rise, Glimmerdeep, Hollowfen, Highmoor, Thornwood Maze, Saltmarsh Isles, Twin Fords, Cinder Steps) in rotation, sides swapped half the time, a fixed seed; each side's opening is the next card of a seeded, shuffled deck of its faction's working builds, so every opening gets an equal share in a random order: in one match-up each of the Crown's eight openings gets 12 or 13 games and each of the Brood's or the Clockwork's seven 14 or 15; over a faction's two match-ups that is 25 and about 29. The draw is recorded in every game.
- **tools/study/explore_v2.py**: the outlier search for m4 (its header has the details). Game k's candidate is of faction k mod 3. The first three games of each faction mutate its documented builds; after that a game is a retest of the faction's best candidate so far (15%), a fresh build from the step grammar (20%), mutations of a documented build (25%) or mutations of a pool winner picked by a tournament of three (40%). Mutations: worker count up or down, two steps swapped, a step dropped or added, an earlier or later attack (or one added or dropped), a proxy, a fast expansion, no wall, an early tech switch, another unit mix, another plan after the script; missing prerequisites are put in by themselves. The opponent is another faction's standard opening (40%), another of its documented openings (30%) or the plain Hard computer (30%), on a random map of the twelve. Score: 1 a win, 0 a loss, 0.75 / 0.25 for a lead at the cap, 0.5 even; fitness = (score + 0.5) / (games + 1).
- **tools/study/report_v2.py**: `aggregate` (one machine), `combine` (the report) and `check` (the build check table).
- **tools/study/machine_v2.sh**: one machine's share, start to finish.

The build checks and the smoke test were run on this machine (two cores, the same Linux build of Godot 4.7).

## The build check on today's rules

Every documented build was played once for 8 minutes against the plain Hard computer of the next faction (Crown against the Brood, Brood against the Clockwork, Clockwork against the Crown) on Ashford Crossing, with the gg rule off: `python3 tools/study/run_study_v2.py --mode check --out <dir>`, then `python3 tools/study/report_v2.py check --runs <dir>`. "Army" is supply and value. A step "pending" at 8:00 had not come up yet.

CHECK_TABLE

What broke under the new rules, and the smallest fix for each:

- **The Brood's sacrifices** (Spitter timing, Brute timing, Roost). A Raptor offered up now gives 9 essence (35% of its biomass, 0.14.40) instead of 3, so the old counts asked for far more Raptors than the build makes: the Roost opening waited for 17 Raptors with 6, timed out and its Bloaters came at 7:30. The counts were scaled to the same essence: Roost 17 to 6, Brute 14 to 5, Spitter 10 to 4. All three now get through every step.
- **The Pendulum push** (Clockwork 6). Two things. First, the scripted player put the Mainspring anywhere with room near the Clocktower (bo_ai.gd was written before the Tension rule), so the Works its Pendulum needs often did not mesh with it, and anything that costs Tension is made only where a Mainspring meshes (0.14.38); and its gear swap took the newest finished Works, which could be one no Mainspring feeds. bo_ai_v2.gd now puts the Mainspring where the computer's own rule does (its ring meshing with a Movement Works', AI._spring_spot) and swaps the gear of a Works a Mainspring feeds (as the computer's own _tier3 picks it). This applies to every Clockwork build that uses Tension, not only this one. Second, Tension comes in at about 20 a minute from one crewed Mainspring in this opening, so two Pendulums (75 each) by 5:00 cannot happen: the first Pendulum step was cut from 2 to 1. The later "pendulum*1" still times out three minutes after it comes up (the second Pendulum comes at about 7:30 against a sleeping opponent), and the attack goes at its 8:00 deadline. It is kept: it still opens the way it is written, only slower.
- **The Brood's two-pit openings under the pit circles** (0.14.42) needed nothing: the second Feeding Pit goes where the computer's own placement puts it, outside the first pit's circle, at about 2:50 in the economy opening.
- **The Clockwork's other openings under Tension and meshing** (Clock Soldier rush, Jacks, turret expansion, Owls, fast Jacks, forward Clocktower) get through every step with the Mainspring fix.
- A tool fix outside the scripts: tools/study/bo_dump.gd read Defs.GROUND_RESERVE, which the pit ground rework removed; it now reads Defs.PIT_GROUND.

No build had to be retired: all 22 get through their steps (the Pendulum push all but its late second Pendulum). A build that is retired later gets `"retired": "<why>"` in build_orders.json and drops out of the draws.

Two things the check shows that are findings, not tool faults, and that the 300 games will measure properly: against the plain Clockwork computer every Brood opening ended 8 minutes behind with almost no army left (its Raptors die as they hatch), and the Clockwork turret expansion had the biggest army at 7:00 of any opening (31 supply).

## The smoke test

Two 8-minute games of each mode (`--games 2 --end 480`: m1, m2, m3 and two explore games) were played, aggregated with `report_v2.py aggregate` into a scratch data folder and combined with `report_v2.py combine`: every step worked. The explorer's game drawing and pool logic were also run 60 times with made-up results (no Godot) to check the draws: documented mutations first, then pool mutations, fresh builds and retests in about the planned shares.
