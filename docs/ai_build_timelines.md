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
| Brood | Extreme rush | Spawning Den 0:36 | 1:18 | 1:41 | 4 / 150 | 5 / 200 | 5 / 425 | 6 / 425 |
| Brood | Rush | Spawning Den 0:51 | 1:25 | 1:47 | 6 / 150 | 9 / 150 | 10 / 300 | 14 / 300 |
| Brood | Air rush | Spawning Den 1:18 | 2:08 | 3:56 | 9 / 0 | 10 / 150 | 14 / 300 | 18 / 225 |
| Brood | Balanced | Spawning Den 1:19 | 2:04 | never (6:00+) | 9 / 0 | 9 / 225 | 12 / 300 | 16 / 300 |
| Brood | Economy | Spawning Den 1:19 | 2:59 | never | 9 / 0 | 10 / 75 | 12 / 225 | 18 / 375 |
| Brood | Timing attack | Spawning Den 1:19 | 2:04 | never (waits for a weaker foe) | 9 / 0 | 9 / 225 | 14 / 300 | 17 / 300 |
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

### Brood
- **Extreme rush** (new, "six-pool"; Brood only): the Spawning Den goes down as soon as 4 grubs and 150 biomass
  are there (the Feeding Pit takes one grub), at most 8 grubs (held at 5 while the army is under its curve),
  at most 2 Feeding Pits, no Brood Pen / Spore Vent / upgrades, every egg hatches Raptors. The first
  6 Raptors leave at once and go for the workers (an attack-move into armed defenders, a plain run at
  workers otherwise); new Raptors follow. It pulls back when the defenders in sight are worth over 1.15x
  the wave (and 100+) or after 75 s without headway, then plays Balanced (workers, Pen, tech, a bigger
  army before the next push). The scout is switched off for this plan.
- **Rush**: the same opening (Den ~0:50, 6 hands held until the first wave leaves, 10 after), but it keeps
  an economy: first wave of 6 Raptors at ~1:50, then a Brood Pen, workers and the normal curve. It falls
  back to Balanced the same way.
- **Air rush / Balanced / Economy / Timing attack**: the Den as soon as 6-8 hands are up (the grubs wait for
  its 150 biomass), then the army follows an army-value curve (`ARMY_CURVE` in ai.gd, per plan: start
  second, full second, value) and any enemy army the Brood can SEE (x1.2). Under the curve workers stop
  at 9-10 until the eggs have caught up, the Brood Pen and Spore Vent wait (the Spore Vent is seeded by the capital or another vent, no grub: Game.seed_vent). Balanced and Timing want 225+
  by 3:00 to meet a Crown Horseman rush at ~3:30; Economy is a little later but still reacts to what it
  sees. Timing attack starts at 4:30 (was 6:40) and only goes when the foe it scouted is not clearly
  stronger.

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
- `tools/test_ai_xrush.gd [plan:xrush|rush] [defence:0|1]`: Brood Rush / Extreme rush timelines (Den by 1:05
  for Rush, Raptors by 1:30, 6+ by 2:05, first attack by 2:50) against a sleeping Crown, and a Crown that
  defends properly (palisade, three Musketeers by 1:50) holds, keeps its Town Hall and most labourers,
  and the rush falls back to a normal game and is not idle.
- `tools/test_ai_brood_army.gd [map:.. seed:.. brood:.. crown:..]`: Brood Rush vs Crown Rush (run it on
  glimmerdeep/4242, kestrel_rise/7): the army reaches 150 by 3:00 and the Burrow survives to 4:30.
- `tools/measure_ai_timelines.gd` / `run_ai_timelines.sh`: the table above.

## Known limits
- Brood Rush against a Crown Rush is a gamble: Raptors (36 hp, 6 damage) do little against Cuirassiers,
  and a lost wave can leave the Brood wiped out by 4:30 on some seeds. That is the intended risk of a
  rush, but the Brood could keep its Raptors home when it sees Horsemen. Open.
- The Crown AI banks 1-2k gold by 4:30 in these runs (not touched here).
