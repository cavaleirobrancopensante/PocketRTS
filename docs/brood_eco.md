# The Brood's economy: the owner's build (branch brood-eco)

The owner (2026-10-30 07:15), after round 3 (docs/brood_new_play_3.md, docs/brood_ai.md) found the Brood earning
45 to 65% of a Hard Crown's or Clockwork's income: **exhaust better Brood economic play before any number changes.**
His build:

- the FIRST Mound Turtle on the NATURAL expansion spot;
- the THIRD Rootmaw at the FAR edge of the natural;
- GRUBS made NONSTOP;
- then the SECOND turtle takes the THIRD expansion, with a Rootmaw there;
- SPOILS from SACRIFICING Raptors (the Mother's stages, the Storm line, research);
- SCOUTING for a safe economy: against the Crown a grub PATROLS at the bottom of the enemy ramp; against the Clockwork
  a grub EXPLORES its main; seeing a rush or a timing attack coming, react: pull back, make warriors, root turtles in
  the way.

This branch puts that build into the coach (tools/play_brood_3.gd) and into the computer (scripts/ai_brood_new.gd,
plan setting `eco`, on in every profile but the two rushes), measures it, and tunes it.

Rules in force for every number below (main merged during the job): 0.22.2 the Tyrant Sire 150 food / 30 s, the
Venom Sire 200 / 35 s; 0.22.3 SACRIFICE gives eggs back by the egg (two Raptors of one egg = one egg); 0.22.4 a
Raptor offered up gives 15 spoils, a grub 10, the Venom Sire costs 25 spoils, harvested bodies pay double and feed the
Mother's veterancy. (Games before 0.22.3 were measured with the new sacrifice rule applied by the tool,
tools/brood_one_egg.gd; it is off now that the game has it.)

Pictures: docs/shots/brood_eco/.

Version: shipped as 0.22.9. The games were measured on the branch while it was 0.22.5 (main's 0.22.6 to 0.22.8 only
changed the Mother's egg line and the card's tooltips), so "0.22.5" below is that build.

## What the first games showed

The first coached games (the build as written, on the 0.22.0 computer) **earned no more than before**, and one lost
where the old computer drew. Three things held the build back, and none of them is a number:

1. **Food, not eggs, held the Brood back for the first eight minutes.** Her clutch sat FULL (10 eggs) until 8:00 in
   every game. Every 50 food spent elsewhere was a grub not laid, and a grub pays back its 50 food in under two
   minutes (about 30 food a minute; 40 from a far Rootmaw). The computer spent the opening on:
   - the Tyrant Sire's lure at 9 grubs, saving 200 food for a minute while the grubs stood at 8;
   - her stage 2 at 4:00 (300 food, and 45 s with no eggs at all), which only raises a laying rate nobody was using;
   - the Venom Sire at 4:00 (200 food).
2. **Her growth savings also blocked Rootmaws and grubs** (the old rule: no third Rootmaw and no grubs above 70% of
   the crew while saving for her stage). Grubs stuck at 15 to 18 from 5:00 to 11:00 in game e1.
3. **The watching grub was killed six times** standing 3 tiles from the Crown's ramp foot, and the third
   expansion was sent 32 tiles out, next to the enemy.

So the build was kept, and the computer was taught to play it as an economy: everything into grubs, Rootmaws and
turtles until eggs, not food, run short.

## The build as the computer plays it now (`eco`)

**Opening (Balanced, Hard; Greenhold seed 3 against the Crown):**

| Time | What |
| --- | --- |
| 0:00 | 5 grubs on the first Rootmaw; grubs laid with every 50 food |
| 0:21 | the second Rootmaw (beside the Mother, at the far edge of her swamp) |
| 0:32 | a grub walks to the NATURAL (the nearest turtle spot by walk that counts as new ground: 22 tiles out on Greenhold) |
| 1:07 | the first Mound Turtle roots on the natural: 12 supply, swamp for Rootmaws, the Mother lays 15% faster |
| 1:10 | a grub goes on WATCH (the Crown's ramp foot / the Clockwork's main) |
| 2:45 | the THIRD Rootmaw roots at the natural's FAR edge (about 27 tiles from the Mother) |
| 3:15 | the Tyrant Sire (13 grubs or 2:30; at once if a rush or an alarm is seen) |
| 5:00 to 5:30 | the second turtle on the THIRD expansion (28 tiles out at most) with a Rootmaw there |
| 6:00 | 30 grubs (the old computer: 13), 5 Rootmaws |
| 7:00 | 40 grubs (the cap in these games), 5 to 6 Rootmaws, 2 to 3 turtles on new ground |
| 8:30 to 9:10 | the Venom Sire (his time is 6:00; food and his 25 spoils come later) |
| 8:45 to 10:00 | her stage 2, once her clutch runs low |

What changed in the computer (scripts/ai_brood_new.gd):

- **The natural first** (`_nb_eco_sites`): the turtle spots on new ground in WALK order (ExpansionSpots' candidates,
  free and fresh as nb_pick has them). The first far turtle is wanted at 0:00 (`far` [[0, 1], ...]), so the first
  turtle the supply needs goes there. The third expansion only within 28 tiles once the natural is held.
- **Rootmaws at the far edge** (`_nb_find_spot`): on new ground first, and on any ground the spot FARTHEST from the
  Mother. A load from farther pays more (Game.food_at: +30% from 18 tiles) and a far Rootmaw takes more grubs
  (BroodNew.crew_max); its draw (4 food a second) is the same, so it needs fewer grubs, and so fewer eggs and less
  food, for the same income.
- **Grubs nonstop**: more grubs a minute on the curve (`drone` 6 to 8), a higher cap (Balanced 54, Economy 58,
  Timing 46, Air 44, and 44 at most against the Clockwork; it was 30 to 34), and the Tyrant Sire's lure later (13 grubs or 2:30 for Balanced) so the first
  200 food is not saved while grubs wait.
- **Her growth when eggs hold the Brood back** (`_nb_grow_time`): she grows only once her clutch has run down to 2
  eggs in the last 45 s, or 4 minutes after the plan's time at the latest (the Air rush keeps its times: the Storm
  line needs her stages). In the games she grew at 8:30 to 10:00 instead of 4:00.
- **Food is saved for a structure only when FOOD is what is short**: a Sire whose spoils were short (the Venom Sire's
  25 spoils since 0.22.4) no longer freezes 200 food and every egg meanwhile. His spoils are wanted 45 s before his time.
- **The watching grub** (`_nb_watch_scout`): from 1:10 a grub stays out all game. Against the Crown it walks to and
  fro across the foot of its ramp, 5 tiles out; against the Clockwork it walks round its main. Soldiers within 6.5
  tiles (that it can see) or 30% of its health lost: it runs home and back to work, and another goes out 60 s later
  (4 in a game at most).
- **The alarm** (`_nb_observe`, `_nb_alarm`): an enemy army of 200 or more seen OUT of its main (past its ramp foot),
  and 40% of the Brood's army or more, at any time. For 75 s:
  - warriors come before grubs;
  - the army holds at home, gathered in front of the natural (no wave leaves);
  - the grubs of any Rootmaw the enemy comes near (not those by the Mother) run to her and go back after;
  - a Mound Turtle from home (with 12 supply to spare) walks out and roots in front of the natural, toward the
    enemy: a tank in its way, very hard to hurt. Not ON the ramp: a rooted turtle closes it, and the natural's grubs
    walk up it.
  - the Tyrant Sire comes at once if he has not yet.
- **The brake** (`_under_armed`): grubs nonstop, but never with an army far smaller than the enemy army its creatures
  saw lately: warriors first (with 16 grubs or more) while its army is under 70% of what it saw against the Clockwork,
  30% against the others. Without it the Brood had 40 grubs and no army at 7:00 and a Clockwork army of 2,000 took its
  Tyrant Sire and a third of its grubs (games e2, e3).
- **Spoils from Raptors** (`_nb_feed_raptors`, `spoils_bank`): the Air rush keeps 120 spoils wanted; while they are
  short and too few spare Raptors stand at home, a Raptor egg comes before the grub curve, and the Raptors are offered
  up as they hatch. Grubs HARVEST with up to 5 (2 + one for every 4 bodies) now that bodies pay double.

The coach (tools/play_brood_3.gd) plays it as `coach:eco` (Balanced), `coach:ecox` (Economy) and `coach:ecoair` (the
Air rush on this economy), films the natural turtle, the third Rootmaw, the watching grub and each alarm, and writes
the income of both sides each minute in minutes.txt. tools/measure_brood_ai.gd now records the income of both sides
each minute, grubs and rooted Rootmaws each minute, when the natural was taken, the third Rootmaw, the watching grub,
spoils earned and Raptors offered up, and the alarms.

## Income: before and after

Computer against computer, Hard against Hard, 15 minutes (tools/measure_brood_ai.gd), Balanced against Balanced.
"Before" is the 0.22.0 computer (the main branch's scripts/ai_brood_new.gd) on the same rules (0.22.4).
Income is food earned against the enemy's gold; "by 6:00" and "by 10:00" are what each had earned by then.

| Game | Result | By 6:00 | By 10:00 | At 15:00 | Share |
| --- | --- | --- | --- | --- | --- |
| Crown, Greenhold 3, before | draw | 1,915 / 2,660 | 5,423 / 7,220 | 9,599 / 16,600 | 58% |
| **Crown, Greenhold 3, after** | draw | **2,546** / 2,660 | **6,300** / 7,220 | 10,688 / 17,740 | 60% |
| Crown, Highmoor 5, after | draw | 2,627 / 2,660 | 6,339 / 6,460 | 12,428 / 12,800 | **97%** |
| Crown, Dune Sea 7, after | draw | 2,561 / 2,660 | 7,128 / 7,220 | 11,829 / 16,980 | 70% |
| Clockwork, Greenhold 3, before | draw | 1,912 / 4,838 | 5,046 / 11,439 | 9,180 / 20,997 | 44% |
| **Clockwork, Greenhold 3, after** | draw | **2,284** / 4,793 | **5,709** / 10,715 | 11,127 / 19,732 | 56% |
| Clockwork, Highmoor 5, after | lost 14:28 | 2,249 / 4,867 | 5,686 / 11,213 | 8,602 / 19,000 | 45% |
| Clockwork, Dune Sea 7, after | lost 13:35 | 2,404 / 4,914 | 4,811 / 11,018 | 6,649 / 17,536 | 38% |

(Round 3's 0.22.0 table, on the old prices and the old sacrifice rule, docs/brood_ai.md: the Brood earned 7,785 to
9,403 by 15:00 against 14,700 to 20,520, and lost 3 of the same 6 games.)

Charts: income_vs_crown_greenhold3.png (the final code, below), income_vs_clockwork_greenhold3.png (this table).
These six games ran with the grub cap at 40; the final code (cap 54, 44 against the Clockwork) is in "The final code".

**What it shows.**

- **Against the Crown the gap is closed for the first ten minutes.** By 6:00 the Brood has earned 96 to 99% of what
  the Hard Crown has (before: 72%), and by 10:00 87 to 99% (before: 75%). From 4:00 to 9:00 it earns as much as the
  Crown each minute, some minutes more.
- **After 10:00 the Crown pulls away again** with the 40-grub cap of these games (1,500 to 2,500 a minute against the
  Brood's 900 to 1,250): the Brood's income flattens at about 1,000 to 1,100 a minute with 40 grubs and 10 Rootmaws.
  The cap is now 54 against the Crown, which keeps it growing: "Late game" below (74% at 15:00 instead of 60%).
- **Against the Clockwork the early gap is not an economy the Brood can play its way out of.** The Hard Clockwork
  earns 930 a minute from its third minute (the Brood: 340, the Crown: 380), and 4,800 by 6:00 against the Brood's
  2,300. The build raises the Brood's share from 44% to 56% where it held (Greenhold, a draw that traded 6,685 for
  4,325), but on Highmoor and Dune Sea the Clockwork's 1,000-value army at 5:00 and 2,000 at 7:00 broke the natural
  and the Brood lost, as the old computer did on Dune Sea in round 3.

## Late game: the grub cap

With 40 grubs the Brood's income stalls at about 1,000 to 1,100 a minute from 8:00: the grubs, not the Rootmaws,
are the limit (10 Rootmaws draw up to 2,400 a minute). So the cap was raised (Balanced 40 to 54, the other eco
profiles likewise) and measured again on Greenhold seed 3:

| Game | Grubs at most | Result | Income at 9 / 12 min | By 10:00 | At 15:00 | Share |
| --- | --- | --- | --- | --- | --- | --- |
| Crown, cap 40 | 42 | draw | 1,090 / 990 | 6,300 / 7,220 | 10,688 / 17,740 | 60% |
| **Crown, cap 54** | 56 | draw | **1,269 / 1,666** | 6,742 / 6,840 | **13,160** / 17,740 | **74%** |
| Clockwork, cap 40 | 42 | draw | 916 / 1,344 | 5,709 / 10,715 | 11,127 / 19,732 | 56% |
| Clockwork, cap 54 | 51 | lost 12:21 | 896 / 394 | 5,295 / 11,125 | 6,178 / 15,309 | 40% |
| Clockwork, cap 44 | 45 | draw | 737 / 1,198 | 5,165 / 11,225 | 8,046 / 19,763 | 40% |

- Against the Crown the higher cap keeps the income growing after 10:00 (1,666 a minute at 12:00 against the Crown's
  1,900) and the Brood ends at 74% of the Crown's income instead of 60%. A coached, filmed game of the same build
  (coach:eco, 0.22.5) earned 7,675 by 10:00 against the Crown's 6,460: **more than the Crown**, with 55 grubs and 9
  Rootmaws.
- Against the Clockwork the extra grubs were an army it did not have: its 2,000-value army came at 10:00 to 12:00 and
  the Brood lost (one game). The cap stays at 44 against the Clockwork; three games there spread 40 to 56% and one
  game each is not enough to tell them apart (the Clockwork game is the noisiest of all).

## The final code (0.22.5): two checks

After the cap and one more fix (a second grub may turn into a turtle or a Rootmaw when 400 food are spare, and with
500 food in hand the turtles come sooner: test_ai_brood found 900+ food sitting at the supply cap), two last games:

| Game | Result | By 6:00 | By 10:00 | At 15:00 | Share | Trade (killed / lost) |
| --- | --- | --- | --- | --- | --- | --- |
| Crown, Greenhold 3 | draw | 2,568 / 2,660 | **7,695 / 7,220** | **15,226 / 15,840** | **96%** | 1,890 / 3,810 |
| Clockwork, Highmoor 5 | draw (it lost this one at cap 40) | 2,188 / 4,825 | 5,896 / 11,006 | 12,256 / 19,705 | 62% | 5,420 / 3,765 |

Against the Crown the Brood out-earned it to 10:00 and ended at 96% of its income (the chart
income_vs_crown_greenhold3.png is this game against the 0.22.0 computer). Against the Clockwork on Highmoor it held a
draw and traded 1.4 for 1 where the cap-40 version lost.

## The Air rush with Raptor sacrifices

The Air rush profile now banks spoils from offered-up Raptors (`spoils_bank` 120, Raptors laid for it while short)
on top of the owner's economy. Two computer games (0.22.4: a Raptor gives 15 spoils, a pair of Raptors gives one
egg back):

| Game | Storm Sire | Stage 2 / 3 | Spoils earned | Storm Challengers | Result, income |
| --- | --- | --- | --- | --- | --- |
| Crown, Greenhold 3 | 8:20 | 5:17 / never (her growth at 8:57 was cut short when the Crown came at her at 10:00) | 479 (12 Raptors offered) | none (4 Hatchlings at 12:00, lost) | draw, 7,634 / 16,220 |
| Clockwork, Dune Sea 7 | 9:10 | 5:17 / 12:22 | 286 (12 offered) | none (its Netters caught the Storm Sire six times) | draw, 8,259 / 19,084 |

And one coached, filmed game pushed harder (`coach:ecoair`: her stages from 2:30 and 6:00, the Storm Sire from 2:30,
150 spoils kept wanted, 12 Hatchlings to mature), against the Hard Crown on Highmoor seed 5, 0.22.5:

| Minute | Her stage | Spoils earned (Raptors offered) | Army | What |
| --- | --- | --- | --- | --- |
| 4:45 | 2 | 0 | 0 | she grows (300 food) |
| 6:00 | 2 | 45 (3) | 9 Raptors | the first Raptors offered up |
| 8:25 | 2 | 165 (11) | 5 Raptors | the Storm Sire arrives (ecoair_storm_sire_0825.png) |
| 9:46 | 2 to 3 | 266 (11) | 0 | she grows to stage 3 (500 food, 75 spoils; a Crown attack at 9:00 took the army) |
| 13:00 | 3 | 433 (15) | 24 Raptors, 4 Hatchlings | Hatchlings laid |
| 14:31 | 3 | 530 (16) | 39 Raptors, 6 Hatchlings | **the first Storm Challenger** (ecoair_first_storm_challenger_1431.png) |
| 15:00 | 3 | 560 (18) | 4 Storm Challengers, 14 Hatchlings, 13 Raptors, 4 Spitters | a draw; income 10,630 against the Crown's 13,560 (78%) |

**Can a Storm Challenger push happen now? Yes, but at about 15:00, not as a rush.** Offering Raptors up pays: 18
Raptors gave 270 of its 560 spoils (bodies the rest), and the economy under it stayed at 78% of the Crown's. What
holds it back is no longer the spoils but the FOOD and the ENEMY: her two stages (800 food), the Hatchlings and the
moults come out of an income that is busy with grubs until 8:00, and the Hard Crown attacks at 9:00, which cost the
army and pushed her stage 3 to 10:46. The computer's own Air rush (two games above) never got a Storm Challenger by
15:00: the Crown came at her during her growth (it stops), and the Clockwork's Netters caught the Storm Sire again and
again.

**What it costs.** Six Storm Challengers want her stage 2 (300 food), the Storm Sire (50 spoils), her stage 3 (500
food, 75 spoils), three Hatchling eggs (240 food, 30 spoils) and six moults (660 food, 150 spoils): about 1,700 food
and 305 spoils, the spoils from about 20 Raptors offered up (500 food, eggs back by the egg). About 2,200 food in all,
three to four minutes of the Brood's whole mid-game income, spent while it has almost no army. Against a Hard
computer that attacks at 7:00 to 10:00 with 1,000 to 2,000 of army that is not survivable: the Storm push is a
late-game plan (from about 12:00) or a plan against an opponent who does not press.

## Scouting and the alarm in the games

- The watching grub went out at 1:10 in every game. Against the Crown it stands at the ramp foot until soldiers come
  near; it was chased home 1 to 3 times a game and lost at most twice (the first version lost six).
- The alarm fired in every game, 6:26 to 9:35, the first time an enemy army left its main (210 to 955 of army), and
  each time a turtle rooted in front of the natural within 10 to 25 s. Against the Crown the alarm's army at home
  held the natural in all three games. Against the Clockwork it held on Greenhold but not on Highmoor or Dune Sea:
  its Netters catch the turtle and the Tyrant Sire, and its army was four times the Brood's.
- What the alarm cannot do: it sees the army only once it is out. The Clockwork army gathers in its main, where
  the exploring grub sees part of it at best (it saw 45 to 70 of a 560 to 1,050 army at 3:00 to 4:00), so the brake
  (warriors first) starts late against the Clockwork.

## The remaining gap, honestly

- **Against the Crown: even up to 10:00, and 74 to 96% of the Crown's income by 15:00 with the final code** (60 to
  97% with the 40-grub cap; before: 52 to 58%). The economy was a play problem, and better play closed most of it.
- **Against the Clockwork: 38 to 62%** (before: 43 to 45%). The Clockwork's income is 2.5 times the Brood's (and the Crown's) from its
  third minute; no Brood opening reaches 930 food a minute by 3:00 from 5 grubs and 250 food (grubs double at best
  every 90 s). This is a number gap, not play.

## What number change I would suggest to the owner (none made here)

1. **The Clockwork's early income** is the outlier, not the Brood's: 930 a minute at 3:00 against the Crown's 380
   and the Brood's 340. That is worth a look first (docs/clockwork_ai.md, its Winders and batteries).
2. **No Brood economy number needs to change for the Crown match-up.** With the higher grub cap the Brood keeps
   pace to 10:00 and ends at 74 to 96%. If the owner wants it even at 15:00 too, the place to look is the late game:
   a Rootmaw's ground (3,000 food) runs out at about 12 minutes, so more ground per Rootmaw would help there without
   touching the opening.
3. **The Storm line's spoils** stay the obstacle to the Air rush (about 300 spoils for six Storm Challengers). With
   Raptors at 15 spoils that is 20 Raptors; the Storm line is reachable but late. Cheaper moults (25 spoils each is
   half the bill) would bring the push forward by a minute or two.

## Tests

Run on this branch (0.22.5, Godot 4.7 headless; the "Aborted" after the results is the known one).

- **tools/test_ai_brood.gd**: new milestones for the eco profiles: `natural` (the first Mound Turtle on new ground is
  the natural, the nearest turtle spot by walk), `maw3` (the third Rootmaw rooted), `watch` (the grub on watch sent),
  `income6` (food earned by 6:00: at least 2,000 for Timing, Balanced and Economy, 1,600 for the Air rush). The
  Tyrant Sire, her stage 2, the Venom Sire and the Air rush's attack moved later on purpose; their limits moved with
  them (docs/ai_build_timelines.md has the measured times). balanced, economy, timing, air, rush, xrush: 0 failures.
  - A run on the way found a stall: against a peaceful Crown the Balanced Brood sat on 900 to 1,100 food for 4 minutes
    at its supply cap (one grub at a time turned into a turtle while the food came in at 1,300 a minute). Fixed: a
    second grub may turn into something when 400 food are spare, and with 500 food in hand the turtles come 12 supply
    sooner. Then 0 failures.
- test_brood_new: 0 failures. test_ai_wall_vs_rush: ALL PASS (the Crown's wall at 0:43, 3 Musketeers by 2:40, the
  computer's Extreme rush held). test_replay: ALL OK. test_files: 1,296 checks, 0 failures. test_i18n: 0 untranslated
  in pt and es (the 0.22.5 patch notes in tools/i18n/patch/notes.txt).

## Tools

- tools/measure_brood_ai.gd: income of both sides a minute, grubs and rooted Rootmaws a minute, natural / third
  Rootmaw / watching grub times, spoils earned, Raptors offered, the alarms; `peaceful:1` (the enemy never attacks);
  the AI's seen army, the brake and the alarm in its minute lines.
- tools/play_brood_3.gd: coach plans `eco`, `ecox`, `ecoair`; pictures of the natural turtle, the third Rootmaw, the
  watching grub, each alarm and the first Storm Challenger; the income of both sides in minutes.txt.
- tools/brood_one_egg.gd: the new sacrifice rule for measuring a build older than 0.22.3 (`onegg:1`), off by default.

To play one again:

    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_brood_3.gd -- \
        coach:eco b:crown map:greenhold seed:3 out:/some/folder end:600
    godot --headless --fixed-fps 30 --script res://tools/measure_brood_ai.gd -- map:greenhold seed:3 foe:clockwork

## Pictures (docs/shots/brood_eco/)

- income_vs_crown_greenhold3.png, income_vs_clockwork_greenhold3.png: income a minute, before and after, both sides.
- eco_natural_turtle_0107.png: the first Mound Turtle rooted on the natural at 1:07, its swamp round it.
- eco_third_rootmaw_far_edge_0245.png: the third Rootmaw at the far edge of the natural's swamp (GRUBS 0/11: a far
  Rootmaw takes 11 grubs; the natural's turtle above).
- eco_watching_grub_crown_ramp_foot_0150.png: the grub on watch below the Crown's ramp (the blue grub in the middle).
- eco_alarm_crown_riders_0852.png: the alarm: Crown riders seen out of their main at 8:52.
- ecoair_storm_sire_0825.png: the Storm Sire arriving at 8:25 in the coached Air rush.
- ecoair_first_storm_challenger_1431.png: the first Storm Challenger moulting at 14:31, by the stage-3 Mother.
