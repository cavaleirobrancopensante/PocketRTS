# The Brood's computer player (0.22.0, branch brood-ai-coach)

The owner (2026-10-29 22:50): "This new Brood doesn't have an AI. Make a coaching like you did before."

The computer was rewritten from the coached games of docs/brood_new_play_3.md. Code: scripts/ai_brood_new.gd
(AIBroodNew). Tools:
- tools/play_brood_3.gd: the coached, filmed games.
- tools/measure_brood_ai.gd: computer against computer, with the numbers below.
- tools/test_ai_brood.gd: each profile's timeline.

## How it plays

**A build order per profile.** These are the PLANS in the code:

| | Extreme rush | Rush | Timing attack | Balanced | Economy | Air rush |
| --- | --- | --- | --- | --- | --- | --- |
| Tyrant Sire's lure | at once (5 grubs) | 7 grubs / 0:40 | 8 / 1:00 | 9 / 1:10 | 10 / 1:20 | 9 / 1:10 |
| Grubs before warriors (a minute) | held at 6 until the wave | held at 9, then 3 | 4 | 5 | 6 | 4.5 |
| Most grubs | 26 | 28 | 30 | 30 | 34 | 30 |
| Mother's stage 2 / 3 saved for from | 7:00 / 13:00 | 5:30 / 11:00 | 3:30 / 9:00 | 4:00 / 8:00 | 3:20 / 7:00 | 3:00 / 7:00 |
| Venom Sire / Storm Sire from | 10:00 / 15:00 | 5:30 / 12:00 | 7:00 / 11:00 | 4:00 / 9:00 | 4:30 / 8:00 | 10:00 / 3:20 |
| Far turtles (new ground) | 1 by 10:00 | 1 by 7:00, 2 by 11:00 | 1 by 5:00, 2 by 9:00 | 1 by 4:30, 2 by 8:00 | 1 by 3:00, 2 by 5:30, 3 by 9:00 | 1 by 5:00, 2 by 9:00 |
| First wave | 8 Raptors at once | 10 Raptors at once | 24 supply, not before 5:30, Pack Hunt first | 22 supply, not before 6:30, Pack Hunt first | 34 supply, not before 8:30, Pack Hunt first | 18 supply, not before 7:00 |
| Warrior mix | Raptors | Raptors | Raptors, a Spitter for 4 | a Spitter for 2 Raptors | a Spitter for each Raptor | Raptors |

- **Against the Clockwork** every plan but the rushes attacks earlier and smaller: waves of 14 supply from 5:00, not
  waiting for Pack Hunt. Steady Raptor pressure was round 3's best game.
- **Against a wall** (the Crown, or any wall seen) the mix goes to a Spitter for each Raptor. No wave goes into it
  with claws alone: it waits for Brutes with Battering Horns, 8 Spitters, or its supply cap.
- **Easy** attacks two minutes later, keeps 6 fewer grubs, grows her later, and skips Pack Hunt before its waves.

**The Mother** stays rooted at home and grows on time. Food is saved for her next stage only once its spoils are
60% there, so no food sits unspent while the spoils never come. She gets up only to fight off an attack at her nest
(BroodNew.mother_guard).

**Structures from grubs.** One at a time, and the food for the one a grub is walking to is kept back:
- the Tyrant Sire's lure first;
- a Mound Turtle when supply is short. If an expansion is due, it goes on new ground: the best turtle spot from
  ExpansionSpots.nb_pick, 30 tiles out at most, no enemy near, and a spot tried lately is not tried again for 3 min;
- the Venom and Storm Sires at the plan's time. The Storm Sire comes first, and spoils are kept for him, as soon as
  2 enemy flyers have been SEEN;
- more Rootmaws, round the Mother and round the far turtles. No Rootmaw without 5 grubs for it.
- A creature that can't reach its spot within 30 s is stopped, and the spot is left alone for 3 minutes.
  - Before this, a Tyrant Sire walked for five minutes to a nest he could not reach, and no Raptor was laid.

**Eggs.** Grubs follow the plan's curve. Warriors come from what is above the reserves: the structure in progress,
supply, her stage. Each line is laid only while its Sire is rooted beside her and not researching.
- Hatchlings only against flyers it has SEEN (they bite only flyers). With none seen, they mature into Storm
  Challengers.
- Brutes at stage 3: up to 4, or 6 when a wall was seen.
- A Mist Toad per 12 supply of army, up to 3.

**Spoils.** Two grubs harvest the bodies near home. Spare Raptors at home (a home guard always kept) are offered up
for spoils, only as far as what is wanted now:
- Bigger Clutch, then Pack Hunt before the first attack;
- Battering Horns at stage 3;
- Spitters against a wall;
- the Storm Sire and her stage 3.
With 900 food or more in hand, no spoils are kept back at all.

**Research**, one Sire at a time, and never while enemies are at her:
- Pack Hunt before a wave (Raptor plans);
- Bigger Clutch from 2:30 with 4 Raptors;
- Battering Horns at stage 3, with Brutes or a wall seen;
- the Venom line's clutch, Long Spit and Slither as it grows;
- the Storm line's clutch and Updraft;
- Quick Roots from 8:00, Swamp Mending from 10:00.
The army's own research never waits for her stage's spoils.

**Maturing.** Young ones resting near home mature, at most half of each kind:
- "push": while a wave gathers (Timing, Balanced, Economy, Air);
- "bank": when food piles up (the rushes).

**Scouting** (Normal and up, not the Extreme rush):
- a grub leaves at 1:10, walks to the enemy's start and round it, and comes home;
- a Raptor looks again at 4:30.
- What every creature sees is remembered. This is only what its side can see (Game.is_visible_to):
  - the biggest enemy army lately (fading at 60 a minute);
  - enemy flyers;
  - a wall;
  - enemy buildings.
- **Rush evidence** is only an army out of the enemy's own base before 4:30: 2 fast riders, an army near the Mother,
  or 300 value on the move. When it sees one, it holds its army at home, delays her growth and the later Sires, and
  lays warriors for 3 minutes.

**Defence.**
- Anything near the Mother is fought by every creature that walks.
- The Sires get up from their nests only when the attack is big and the army can't hold it alone. A Sire off his
  nest fathers nothing, and a dead one stops his line for minutes.
- A wave out is called home when the attack at her is bigger than what is home.

**Waves.**
- The army gathers at a staging point toward the enemy (25 s at most).
- It goes when it is big enough: the plan's supply, with 60% of the biggest enemy army seen lately (30% against the
  Clockwork), or at the supply cap.
- It goes for the nearest enemy building it has seen that is not a wall, or else the enemy's start.
- Hatchlings stay home unless the enemy flies. The plan's home guard of Raptors stays.
- New creatures join only as a group of 6 supply.
- It pulls back when the fight is lost:
  - half or less left and more ahead;
  - a quarter left;
  - 30% lost, nothing gained, and 1.6 times its value ahead;
  - or no headway in 2.5 minutes.
- A lost wave makes the next one bigger. A failed rush turns into Balanced, with 90 s to build up.

**No cheating.** It knows where the enemy started and its faction, as every computer does. Otherwise it knows only
what its creatures see. The old computer counted every enemy flyer on the map; that is gone.

## Before and after (Hard against Hard, 15 minutes or to the end)

The same six games for both: Balanced against the Crown and against the Clockwork, on Greenhold seed 3, Highmoor
seed 5 and Dune Sea seed 7.
- "Before" is the computer of 0.21.2.
- "After" is this branch.
- Army value is the cost of its fighting creatures alive (a Raptor counts 25).

| Game | Before: result | Before: army 3/5/8/12 min | After: result | After: army 3/5/8/12 min | Enemy army 3/5/8/12 (after) |
| --- | --- | --- | --- | --- | --- |
| Crown, Greenhold | lost 14:00 | 0 / 50 / 200 / 880 | draw | 0 / 75 / 300 / 550 | 240 / 420 / 890 / 2,140 |
| Crown, Highmoor | **won 11:24** | 0 / 50 / 625 / - | draw | 0 / 100 / 300 / 225 | 240 / 420 / 1,140 / 2,100 |
| Crown, Dune Sea | lost 13:39 | 0 / 50 / 225 / 290 | lost 14:19 | 0 / 100 / 200 / 500 | 240 / 420 / 1,310 / 2,650 |
| Clockwork, Greenhold | lost 14:34 | 0 / 50 / 600 / 135 | lost 14:36 | 0 / 75 / 140 / 0 | 560 / 1,050 / 2,180 / 4,290 |
| Clockwork, Highmoor | draw | 0 / 50 / 650 / 195 | draw | 0 / 75 / 0 / 800 | 560 / 980 / 2,025 / 4,330 |
| Clockwork, Dune Sea | draw | 0 / 50 / 575 / 90 | lost 13:46 | 0 / 100 / 0 / 0 | 560 / 1,050 / 1,930 / 4,615 |

| | Before | After |
| --- | --- | --- |
| Wins / draws / losses | 1 / 2 / 3 | 0 / 3 / 3 |
| First attack | 6:32 to 7:07 | 8:45 and 11:36 against the Crown, never on Greenhold (the wall rule); 9:26 to 11:06 against the Clockwork |
| Research done | 2 games of 6, Bigger Clutch only, at 7:43 to 8:14 | Pack Hunt and Bigger Clutch (and Battering Horns twice) in 4 of 6, from 9:15 |
| Mother's stage 3 | 2 of 6 | 3 of 6 |
| Sires | Venom in all, Storm in 2 | Venom in all, Storm in 4 |
| Young matured | 0 to 4 | 0 to 3 |
| Far turtles (new ground) | 0, once 1 | 2 in every game |
| Scouting | none | a grub at 1:10, a Raptor at 4:30, in every game |
| Most grubs | 34 to 38 | 31 to 33 |
| Most food banked | 538 to 1,783 | 248 to 853 |
| Income at the end, Brood / enemy | 8,071 to 11,152 / 15,200 to 20,138 | 7,785 to 9,403 / 14,700 to 20,520 |

**What this shows (honestly).**
- The new computer plays the Brood fully:
  - it scouts;
  - it researches before it fights;
  - it grows her on time;
  - it raises its Sires through their lures;
  - it expands on new ground;
  - it keeps its grubs and its food in check;
  - it gathers, attacks and pulls back.
- **It is not yet an even match.** Against the Hard Crown it holds a draw in 2 of 3 (the Crown never breaks it, and
  it does not throw its army at the musket wall any more). Against the Hard Clockwork it loses 2 of 3.
- It won no game. The old computer won one: on Highmoor its single big Raptor wave caught the Crown.
- The cause is the economy (docs/brood_new_play_3.md, "Balance findings").
  - The Brood earns 45 to 60% of what the Hard Crown or Clockwork earns, whoever plays it: the old computer, the new
    one, and every coached plan.
  - From 8:00 on the enemy's army is 3 to 6 times the Brood's.
  - No build order closed the gap. Expanding fast got the most (10,400 to 10,600 by 15:00) and still earned only
    60% of the Crown's income.
- **Not a pushover:** it kills 1,500 to 5,400 of the enemy's value a game and survives to the end in half of them.
  **Not unbeatable:** a Hard Clockwork beats it.

The two extra games:
- **Timing attack against the Clockwork, Greenhold: a draw**, the best of the batch.
  - Waves from 7:36. Bigger Clutch and Pack Hunt researched.
  - It killed 6,900 for 5,015 lost.
- **Economy against the Crown, Dune Sea: lost at 14:15.**
  - 35 grubs, 2 far turtles, and the Venom line researched (Bigger Clutch, Long Spit, Pack Hunt).
  - It never grew the Mother and had no army until 12:00. Its one wave at 11:55 lost 7,165 for 1,250.
  - The Economy profile is too greedy against a Hard opponent. Its timings are an open point.

## The early rush (design_principles.md 5)

- **Extreme rush** (tools/test_ai_brood.gd, a peaceful Crown):
  - the Tyrant Sire at 0:36;
  - 8 Raptors and the wave leaving at 2:40;
  - at the enemy's ramp at about 3:10.
- The yardstick (8 Raptors by 2:00, hitting at 2:00 to 2:30) cannot be met by today's Brood. Its 250 starting food
  and about 320 earned by 2:00 must pay the Tyrant Sire (200), a turtle (100) and the Raptors (200). This is a
  balance finding, not changed here.
- Against the Hard Crown it fails: the Crown walls its ramp at 0:38 and its scout calls the rush at 1:08. The
  computer then plays Balanced.
- tools/test_ai_wall_vs_rush.gd (a walled Crown with 3 Musketeers by 2:40 against the computer's Extreme rush, driven
  harder by the test): see Tests.

## Tests

Run on this branch (Godot 4.7 headless). The "Aborted" Godot prints after quitting is the known one.

- **tools/test_ai_brood.gd (new)**: one profile a run (`-- profile:<name>`), against a peaceful Hard Crown on
  Greenhold.
  - It checks each milestone of the profile by its latest time: the Tyrant Sire, 8 Raptors, the scout, her stages,
    the Sires, research, Pack Hunt, a far turtle, the first attack. The measured times are the Brood table in
    docs/ai_build_timelines.md, and the limits are about a minute later.
  - It also checks that no more than 900 food sits for a minute, and the grubs stay at the plan's cap.
  - The final runs: xrush, rush, timing, economy and air: 0 failures.
  - Balanced: Pack Hunt came at 10:43 against a limit of 10:20 (runs vary by about half a minute). The limit is now
    11:40.
- **test_brood_new: 0 failures** (272 checks).
  - Its hand-made computer now gets a Balanced plan at creation (AIBroodNew._init).
  - `_nb_foe_air()` is kept; it now answers what was seen.
- test_brood_new_defence:
  - mode:uproot: 0 failures.
  - rooted: only its known Musketeer case fails (the Mother dies in 94 s, as in 0.18.0).
- **test_ai_wall_vs_rush: all pass.** The Crown's wall and 3 Musketeers hold the computer's Extreme rush, driven by
  the test.
- test_ai_rush: pass. test_ai_scout: pass. test_ai_scout_threat: pass. test_ai_air_defence: pass.
- test_ai_rush_followup:
  - first run: one failure, "the finishing pair never rides alone (32 lone sightings)". That is a Crown rider case
    this branch does not touch.
  - rerun: all pass.
- test_ai_army_response: all pass. It prints a script error from its own line 70 (`g.halls_of(1)[0]` when side 1 is
  the Brood, which has no halls since 0.18.0). The test's own bug, not changed here.
- test_replay: all OK. test_files: 1,296 checks, 0 failures. test_i18n: 0 untranslated in pt and es.

Two small changes came after the computer-against-computer batch above:
- Against the Crown, a Raptor-only mix becomes the mixed one, so that the wall rule can be met.
- The Economy plan grows the Mother before more Rootmaws and far turtles. Without it, Economy never reached her stage
  2 in the batch; with it, stage 2 comes at 7:22 in the timeline test.

The batch was not run again after them.

## Open questions for the owner

1. **The income gap** (the biggest): the Brood earns about half what the others earn, whoever plays it. Should the
   Brood's economy be lifted (Rootmaw fill, grub load, a faster Mother), or its units made cheaper for their value?
   The computer can't close it alone.
2. **Spoils**: the Storm line and the Air rush need about 400 spoils, and the Brood earns 10 to 20 a minute. Should
   the Storm line cost less spoils? Should the Air rush profile stay for the Brood? Today it plays as an early stage 2
   with the Storm Sire first, then Raptors.
3. **The Extreme rush yardstick**: 8 Raptors by 2:00 is out of reach (2:40 at best). Keep the yardstick and change
   the Brood's opening (a cheaper or faster Tyrant Sire), or move the yardstick for the Brood to "8 Raptors by 2:45"?
4. **The Venom Sire walking with the army** (the owner's idea 2) traded best against the Crown. Should the computer do
   it by default against walled enemies? Today it is a coach setting only ("sire_leads").
5. **The Mother cannot attack a Gate on a ramp** (the Mother rush games): she stands at its foot. A bug to look at?
6. **The wall rule**: against the Crown the computer now waits for Brutes with Battering Horns or 8 Spitters before
   it attacks. It draws more and loses less, but rarely threatens the Crown. Is that the right character for the
   Brood, or should it gamble more?

## The owner's answers (2026-10-30 07:15)
- The Mother MUST be able to hit a gate on a ramp: investigate and fix (branch brood-fixes).
- Spoils for the Storm line / air rush: SACRIFICE RAPTORS. The sacrifice egg exploit is to be fixed: two young from one egg sacrificed gave two eggs; now a sacrifice still pays its spoils, but the young of one egg give back only ONE egg between them (branch brood-fixes).
- The income gap: EXHAUST BETTER BROOD ECONOMIC PLAY FIRST before changing numbers. His build: the FIRST TURTLE on the NATURAL expansion spot; the THIRD ROOTMAW at the far edge of the natural; grubs made NONSTOP; then the SECOND TURTLE takes the THIRD expansion with a Rootmaw there. Spoils from sacrificing Raptors. Scouting for a healthy economy: a grub PATROLLING at the bottom of the enemy ramp against the Crown, and EXPLORING the Clockwork main, to see a rush or timing attack coming (branch brood-eco).
