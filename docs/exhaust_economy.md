# Exhausted means exhausted (0.24.0, branch exhaust-economy)

The owner's decisions (2026-10-30 14:13, 14:44, 14:47; docs/idea_bucket.md; numbers from docs/cw_economy_study.md section 0).
Design rule followed: docs/design_principles.md section 2, "Economy forces expansion and is depletable ... no permanent safe
global bonuses". The job was cut short by the owner (14:49): the rules are in with the starting numbers, ONE quick
before/after measurement was run, the tuning is left as open questions below.

## The rules

| | Before | Now |
|---|---|---|
| A Farm / Cog Press / Mainspring with nobody on it | 15% of full (the TRICKLE) | **nothing** (`FARM_BASE`, `GEAR.press.base`, `GEAR.mainspring.base` 0) |
| Spent soil (Farm), spent brass (Cog Press), a Rootmaw's spent ground | soil 0, brass **a quarter forever**, ground 0 | **0** (`GEAR.spent` 0; a press on spent brass is barren: its crew is let go) |
| Powder (a Mill on its Town Hall's 1,320 saltpetre) | 0 once spent | falls with the reserve from 100% to the **POWDER FLOOR 15%** and stays there while worked (`Defs.POWDER_FLOOR`, `Defs.second_share`); an empty Mill gives nothing |
| Tension (a Mainspring) | wound forever | draws its Clocktower's **SPRING LIFE** (1,320, `Defs.TENSION_RESERVE`, kept in the Clocktower's `soil`, the field the retired coal used); falls with it to the **TENSION FLOOR 5%** (`Defs.TENSION_FLOOR`); spent, the Mainspring is **FATIGUED** ("the spring has taken a set") |
| A FATIGUED Mainspring | | still winds at 5% while crewed, still DRIVES its rings, stores Tension and counts as a Mainspring for the Tension rule (Escapement, Heavy Works, Light Works' Springers, Aviary) |
| Limits per Clocktower | 2 Cog Presses, Mainsprings unlimited | **2 Cog Presses, 1 Mainspring** (`FACTIONS.clockwork.econ`; a Mainspring must stand within 14 tiles of a Clocktower like any economy building). Old saves keep the Mainsprings they have; they keep working |
| Cog Press | small 8.0/s with 6, big 10.5/s with 12 | **small 7.2/s with 5, big 10/s with 8** (a Winder adds 1.44 / 1.25 a second) |
| Winder | 50 | **60** (pays back in about 42 s, like a Labourer) |
| Brass a Clocktower | 11,400 | **9,000** (the Crown's soil) |

Shown to the player: the Mainspring's card ("Spring life 840 / 1,320", "FATIGUED" on its efficiency line and a FATIGUED
line saying it winds at 5%), a "Spring life %" chip on its card, the Clocktower's card (brass and spring life left), the
toasts and match-log lines when spring life runs low or out, the tooltips, the help pages (CROWN: soil, saltpetre;
CLOCKWORK: a new "COGS AND TENSION" and "Brass and spring life" paragraph in place of the old battery and coal ones), all
in en/pt/es (tools/i18n/27_exhaust_economy.txt).

The other "pays forever" rules checked: the Brood has none (a Rootmaw drinks only its ground; piles rot; spoils come from
bodies and offerings); the Great Winder's sweep pays from wrecks only; the shelved Line's coal and ore pay 0 (`COAL_SPENT`,
`LODE_SPENT`). The Brood computer needed no change (scripts/ai_brood_new.gd untouched).

## The computers

- **Crown**: in the first 5 minutes the Mill gets no hands until a Farm has its full crew of 8 (`AI._mill_cap`), unless a rush
  is feared (`_army_first`: the Musketeers' powder first, the wall-and-Musketeers answer to the extreme rush is unchanged).
- **Clockwork**: every place that plans a Mainspring asks `AI._spring_ok()` (1 per Clocktower: the tier-2 pair, the
  Escapement's and Heavy Works' springs, the Springer Works, the Aviary); `AI._fresh_spring()` builds a Mainspring by a
  Clocktower with fresh spring life once every spring it has is fatigued or nearly; `_land` counts spring life as well as
  brass when it decides to expand; it keeps 13 Winders a tower (was 16) and asks for a new tower every 13 Winders (was 15);
  `_recycle_spent` also pulls down a press on spent brass when the limit leaves no room by a fresh tower.

## Fixes (the study's bugs)

- The Clockwork's "cogs earned" statistic: repairs took their cost from the income's fraction (`gold_f`), so the presses'
  cogs paid the repair before they were counted. Repairs keep their own fraction now (`players.repair_f`, Unit and Great Winder).
- The Powder Mill's card said "saltpetre spent: a quarter": it says "it grinds at 15%" now (and the Town Hall's card).
- Retired leftovers: the Clocktower's coal reserve is its spring life in gear mode (`Building.reserve`; the Line keeps coal),
  "boiler" is out of `CREW_TIER`, the Boilers, Ore Crushers and Ore Drills moved to `FACTIONS.clockwork.econ_line`, used only
  with the gear mode off (`Defs.econ_of`), so the shelved Line tests still run.
- Saves: a Clocktower's spring life is saved with a marker ("tsn"); a save from before 0.24.0 gets a fresh spring life.

## Measured (one quick run)

One map (Greenhold, seed 1), the Hard computer (Balanced, PEACEFUL: it builds and trains but never attacks) against an idle
dummy, 15 minutes, tools/measure_economy.gd. BEFORE = the study's game on 0.22.8 (docs/cw_economy/results.jsonl, the same
map, seed and settings); AFTER = 0.24.0. No fights were run (the owner cut the job short).

**Earned (cumulative; Clockwork cogs, Crown gold, Brood food)**

| | 3:00 | 6:00 | 8:00 | 10:00 | 12:00 | 15:00 |
|---|---|---|---|---|---|---|
| Crown before | 1,140 | 3,800 | 6,080 | 10,640 | 14,440 | 21,160 |
| Crown after | 1,140 | 3,800 | 5,700 | 9,880 | 13,300 | 19,380 |
| Clockwork before | 2,102 | 5,246 | 8,583 | 12,088 | 15,579 | 21,251 |
| Clockwork after | 1,892 | 4,555 | 7,544 | 10,831 | 13,077 | 17,110 |
| **Clockwork / Crown before** | 1.84 | 1.38 | 1.41 | 1.14 | 1.08 | 1.00 |
| **Clockwork / Crown after** | **1.66** | **1.20** | **1.32** | **1.10** | **0.98** | **0.88** |
| Brood after (no before run) | 791 | 2,784 | 5,167 | 7,802 | 10,929 | 15,722 |

**Army value (peaceful)**: Crown before 140 / 490 / 1,220 / 2,540 / 3,955 / 6,360 at 3 / 6 / 8 / 10 / 12 / 15 min, after
0 / 730 / 985 / 2,010 / 3,345 / 5,890; Clockwork before 420 / 1,070 / 3,305 / 6,205 / 9,240 / 11,080, after
350 / 980 / 2,020 / 4,285 / 6,095 / 9,655; Brood after 475 / 1,175 / 2,100 / 2,970 / 3,970 / 3,970.

**Second resources**: Crown powder wound by 15:00 960 (before 1,283), its bank near 0 all game in both (the computer spends
powder as it comes); 5 Mills on 5 halls, 5,639 saltpetre still in the ground at 15:00 (the floor was not reached in 15
peaceful minutes). Clockwork Tension wound 1,444 (before 2,062), 4 Mainsprings on 4 Clocktowers (1 each: the limit holds),
the main's spring had drawn 587 of its 1,320 by 15:00 (none FATIGUED yet), Tension bank 20 to 70 from 10:00 (before 75 to
210): Tension is now the brake on the Clockwork's tech, as decided.

**What it says**
- The Clockwork's lead shrank at every point (3:00 1.84 -> 1.66, 6:00 1.38 -> 1.20, 8:00 1.41 -> 1.32) and it now trails
  late (0.88 at 15:00). The target "within about 1.2x at every point" is met from 6:00 on except 8:00 (1.32); the first
  three minutes (1.66) are the Crown computer's opening (one Farm, its hands building the wall and Barracks), which no rule
  number closes alone (study section 0).
- The Crown lost 5 to 8% from 8:00 (its empty Farms' trickle), as the model said.
- The Clockwork late game: it keeps 32 Winders but only 15 to 16 on its 6 to 7 presses from 10:00 (the rest escort, repair
  or wait); with no trickle that leaves income on the table (about 1,330 cogs a minute late, the Crown 1,900 to 2,660).
- Resources running out: in 15 peaceful minutes neither side spent a base's main resource (the computers expand early,
  for slots); the Crown's main had about 6,300 soil drawn at 5:00 and expanded at about 5:30. Fights would spend faster.
- The Brood works without any trickle (none existed): it earned 15,722 food by 15:00. In this peaceful game it stopped at
  124/124 supply from 12:00 with 7,600 food banked (no more Mound Turtles): a Brood computer quirk to look at, not caused
  here (scripts/ai_brood_new.gd untouched).

**The floors (the owner's 15% / 5%; worked out, not yet seen in a game)**
- POWDER at 15%: a spent Mill with its 6 hands grinds 0.30 powder a second, 18 a minute (full: 119). The peaceful Crown used
  about 80 powder a minute late (960 in 15 minutes, most of it after 7:00) on 4 to 5 Mills. A late Crown on, say, 3 spent
  halls and 2 fresh ones would have 2 x 119 + 3 x 18 = 292 a minute; all five spent, 90 a minute: still more than the
  peaceful army's 80, but a Musketeer refill is 10 powder and a fighting army of 60 Musketeers firing every few seconds
  burns far more. Verdict: 15% keeps a few guns firing; it does not supply a big army alone, so a fresh hall stays clearly
  worth taking (100% is 6.7 times the floor).
- TENSION at 5%: a fatigued small Mainspring with 3 Winders winds 0.1 a second, 6 a minute. A Pendulum costs 75 Tension
  (12.5 minutes of one fatigued spring), a Springer 25 (4 minutes). The Heavy Works keeps working (a fatigued spring still
  counts for the Tension rule) but makes heavy machines only from fresh springs or the bank. Verdict: 5% is nearly nothing
  for production; it is a "you can still finish a unit" floor.

**Tests**: tools/test_exhaust.gd (new), test_gear_press, test_gear_econ, test_gear_save (passes alone; it shares the save
file with other jobs' tests), test_gear_rules (now lifts the limit with the test-only hook to lay its second Mainspring),
test_gear_winddown, test_gear_swap, test_gear_ai, test_farm_square, test_mill_flow (expects the falling share), test_files,
test_replay, test_brood_new, test_ai_crown_bank, test_i18n all pass. Two do not:
- **test_ai_wall_vs_rush**: the Crown's 3rd Musketeer comes at 2:49, the test wants 2:40 (the old Farm trickle paid for the
  first one sooner: the Crown sat on 5 gold from 1:20 to 2:00 while its hands built the wall). The farm-first rule is not
  the cause (the same 2:49 without it). See open question 1.
- **test_line_ai** (the shelved Line, gear mode off): its Clockwork is eliminated before 7 minutes; not looked into (the Line
  is shelved; its economy keeps the old numbers through `econ_line`, but the Winder's new price applies to it).

## Open questions (for the owner)

1. **The Crown's answer to the extreme rush got 9 s slower** (3 Musketeers by 2:49, design principle 5 asks about 2:30 to
   2:40). Options: the Crown's start Farm starts part-grown (a one-time start, not a trickle), the Crown computer keeps more
   hands on the Farm while it walls, or accept 2:49 and move the test's line. The owner's call.
2. **The floors** (15% powder, 5% Tension) are the owner's starting values and were not seen in a game: a fighting
   15-to-20-minute game should check a late Crown army's refills and whether the Clockwork can still finish Heavy Works
   machines. If 5% proves useless, 10% would still leave a fresh tower 10 times better.
3. **Is the floor linear?** The yield falls with the reserve (100% fresh, the floor spent, straight between): half the
   reserve left pays 57% (powder) and 52% (Tension). A step (full until spent, then the floor) is the alternative.
4. **The Clockwork trails late (0.88x at 15:00)** because the computer keeps half its Winders off the presses; with no
   trickle the computer should staff its presses before escorts (AI._workers), or the Winder cap rise from 32. Not tuned.
5. **The opening gap (1.66x at 3:00)** is the Crown computer's opening, as the study said.
6. **FATIGUED Mainsprings stay**: the computer never pulls them down (they still drive the tech round them); a player
   might want to, to place a fresh one by the same tower: it would draw the same spent spring life, so there is no gain.

## How to run it again

- `tools/test_exhaust.gd`: no trickle anywhere, spent pays 0 (soil, brass, ground), the floors (saltpetre, spring life),
  fatigue, the limits, an old save's extra Mainspring, the statistic.
- `tools/measure_economy.gd` (now also counts the Brood: Rootmaws, grubs, ground left):
  `godot --headless --fixed-fps 30 --script res://tools/measure_economy.gd -- map:greenhold seed:1 a:crown b:clockwork wa:hard wb:idle secs:900`.
  The "before" numbers are the study's games (0.22.8, docs/cw_economy/results.jsonl); the "after" logs are in docs/exhaust_economy/.
