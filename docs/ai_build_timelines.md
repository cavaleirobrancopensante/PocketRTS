# AI build timelines (the computer's opening, per faction and plan)

Anchor: the owner's hand-played Brood extreme rush (docs/design_principles.md section 5): Spawning
Den done 1:01, first Raptors 1:13, 8 Raptors (200 value) by about 2:00, first hit 2:00-2:30. Every plan is
calibrated against it under the current (halved) economy. Numbers below are measured, not hoped for.

## How the numbers were made

`tools/run_ai_timelines.sh [map] [seed]` runs `tools/measure_ai_timelines.gd` for every faction and plan
(Hard AI, Ashford Crossing, seed 4242) against a Hard Crown on Balanced that defends but never attacks
(`peaceful`), so each row is the plan's own build, not a fight it was dragged into. Columns: first
military production building done, first soldier, first attack leaving, then workers / army value
(cost of the armed units alive; Raptors count 25 each) at 2:00, 3:00, 4:00, 5:00. "never" means no
attack by 7:00 (a Timing Attack waits while the foe it has seen is stronger; Balanced pushes later).
Runs vary a little from game to game (random choices): read the numbers to +-20 s and +-1 unit.

| Faction | Plan | Production building | First soldier | First attack | 2:00 | 3:00 | 4:00 | 5:00 |
|---|---|---|---|---|---|---|---|---|
| Crown | Rush (Horsemen) | Barracks 1:19 | 2:06 | 3:52 | 8 / 0 | 7 / 115 | 11 / 345 | 13 / 115 |
| Crown | Balanced | Barracks 1:20 | 1:55 | never (6:00+) | 9 / 75 | 9 / 115 | 10 / 230 | 12 / 115 |
| Crown | Economy | Barracks 1:20 | 1:55 | never | 9 / 115 | 11 / 115 | 13 / 230 | 17 / 230 |
| Crown | Timing attack | Barracks 1:20 | 2:47 | never (waits for a weaker foe) | 10 / 0 | 12 / 115 | 13 / 115 | 16 / 345 |
| Clockwork | Rush | Assembly Works 2:17 | 2:30 | 2:44 | 9 / 0 | 12 / 225 | 15 / 525 | 15 / 730 |
| Clockwork | Balanced | Assembly Works 2:20 | 2:34 | 5:06 | 8 / 0 | 10 / 150 | 15 / 675 | 17 / 1655 |
| Clockwork | Economy | Assembly Works 2:16 | 2:30 | 5:11 | 8 / 0 | 11 / 225 | 16 / 700 | 20 / 1615 |
| Clockwork | Timing attack | Assembly Works 2:16 | 2:30 | 5:07 | 8 / 0 | 11 / 225 | 16 / 600 | 20 / 1525 |

(The Crown's and the Clockwork's own opening logic was only touched where noted below.)

## What each plan is for, and how it is built

### Brood (the Brood of creatures, 0.22.0: scripts/ai_brood_new.gd, docs/brood_ai.md)
The old Brood's rows (Spawning Den openings) are gone with it (0.18.0). Today's Brood has no buildings: its Tyrant Sire
on his nest is its barracks, made from a grub's lure (200 food, 35 s). Measured by `tools/test_ai_brood.gd -- profile:<p>`
(Hard Brood against a peaceful Hard Crown on Greenhold, seed 3; 0.22.0): the times each milestone came.

| Plan | Scout | Tyrant Sire | 8 Raptors | Stage 2 | Venom Sire | Storm Sire | Far turtle | First research | First attack |
|---|---|---|---|---|---|---|---|---|---|
| Extreme rush | 3:14 (after the rush) | 0:36 | 2:40 | - | - | - | - | - | 2:40 (at the ramp ~3:10) |
| Rush | 1:10 | 1:27 | 3:23 | - | - | - | - | - | 3:44 |
| Timing attack | 1:10 | 1:36 | 6:45 | 5:11 | - | - | 5:33 | - | 7:56 |
| Balanced | 1:10 | 1:47 | 7:23 | 6:02 | 4:59 | - | 6:12 | 9:25 (Pack Hunt) | not by 9:25 (the wall rule) |
| Economy | 1:10 | 2:23 | 6:24 | 7:22 | 5:24 | - | 4:56 | 7:36 | - |
| Air rush | 1:10 | 1:47 | 6:30 | 5:00 | - | 7:58 | 5:33 | 7:43 | 8:15 |

- **Extreme rush**: the Tyrant Sire's lure at once, 6 grubs, one Rootmaw, a supply turtle right after him, every egg
  Raptors; the 8 go together. The owner's yardstick (8 Raptors by 2:00, hitting 2:00-2:30) is out of reach for
  today's Brood (the Sire's 200 food comes first): its fastest rush lands at about 3:10. Against the Hard Crown it
  fails (the ramp wall stands at 0:38, its scout sees the Raptors at about 1:08) and the computer plays Balanced.
- **Rush**: 9 grubs held until 10 Raptors leave (about 3:45), then Balanced's economy.
- **Timing attack / Balanced / Economy / Air rush**: grubs first on a curve (4 to 6 a minute), the Sires, her stages
  and expansions on the plan's clock, Pack Hunt before the first wave (except against the Clockwork, which gets smaller
  waves from 5:00). Against the Crown no wave goes into its wall with claws alone (Spitters or Brutes with Battering
  Horns first, or the supply cap), so its first attack against a walled Crown comes late or at the cap.
- Its scouting decides: an army on the move early means hold and lay warriors; enemy flyers mean the Storm Sire first.

### Crown
- Rush = Horse Breeder opening, 3 Horsemen out by ~3:30 (the owner's earlier log). Counter-play: the wall
  and a few Musketeers by ~2:00 (the wall agent's tests, wt-ai-wall).
- Balanced / Economy / Timing open with the Barracks at ~1:20, as before this change.

### Clockwork
- The first Assembly Works used to wait for `clock / tech factor`, so Rush (factor 2.0) was the slowest to
  open. It now goes down by the clock for every plan (Hard 1:00 with 7 Winders) and the Winders wait for
  its 200 gold. Rush attacks at ~2:44 with the first wind-ups, a counterpart of the Brood rush with much
  weaker punch (wind-ups are slow). Counter-play sketch: a Crown wall + 3 Musketeers or Brood Raptors in
  the swamp both beat early wind-ups; not yet covered by a dedicated test.

## Tests that keep this honest
- `tools/test_ai_brood.gd [profile:xrush|rush|timing|balanced|economy|air]`: the Brood table above, each milestone by
  its latest time (about a minute's margin), no food bank over 900 for a minute, grubs at the plan's cap.
- `tools/test_ai_wall_vs_rush.gd`: the Crown's wall and 3 Musketeers against the Brood computer's Extreme rush.
- `tools/measure_ai_timelines.gd` / `run_ai_timelines.sh`: the table above.

## Known limits
- Brood Rush against a Crown Rush is a gamble: Raptors (36 hp, 6 damage) do little against Cuirassiers,
  and a lost wave can leave the Brood wiped out by 4:30 on some seeds. That is the intended risk of a
  rush, but the Brood could keep its Raptors home when it sees Horsemen. Open.
- The Crown AI banks 1-2k gold by 4:30 in these runs (not touched here).

## After the first rush resolves (patch 0.13.2, tools/test_ai_rush_followup.gd)
The Horseman rush (Crown, Horse Breeder opening, as a raiding party or as the Rush plan's first wave),
the Brood Raptor rushes and the Rush plan of any faction are judged from facts (`AI._rush_verdict`):
riders alive, enemy value killed against the rush's worth, armed defenders seen, enemy workers seen,
time since it began. ONGOING changes nothing.
- FAILED (riders dead or beaten back, defenders alive, no headway): the riders ride home, new cavalry
  stay home as defence, no raiding party re-forms for 150-240 s, the plan becomes a normal build and
  the next attack waits for a proper force (usual army-size rules, regroup time).
- SUCCEEDED, few workers (3 or fewer seen) and no defenders ("finish"): fresh cavalry may ride out,
  but only as a group of 2+.
- SUCCEEDED otherwise ("mop"): the riders regroup at the rally point, the economy goes on (normal
  Musketeer and cavalry mix), and ONE force of at least 12 supply (more for bigger defences) goes out.
- Always: units trained after a wave left wait at home and join only as a group (2+ units, and 6+
  supply in an ordinary wave); a party cut down to one rider sends him home. Scouts are the only
  units that go alone.
