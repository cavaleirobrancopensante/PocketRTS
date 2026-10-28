# Playing the new Brood, round 2: testing the new levers

The owner asked for tests of the new rules ("make some tests"). These are coached, filmed games with tools/play_brood_new.gd, as in round 1 (docs/brood_new_play.md).

All results here are for the rules of 0.15.13:
- no rooted creature attacks;
- each SACRIFICE gives the Mother one egg;
- the Mother grows in stages with GROW;
- the Tyrannosaur near her makes her lay faster;
- only Mound Turtles on new ground, 15 tiles or more out, speed her laying.

Another helper is now reworking how the new Brood works (branch brood-structures). These results may not hold after that.

## How I tested

- Each test was compared with the same coach on 0.15.11's rules, played the same day, same map and seed. Those are the "before" numbers.
- The opponent was the normal computer on Hard.
- The coach now does what a player would: grows her on time (stage 2 from 4:30, stage 3 from 8:00), saves food for it, offers Raptors for stage 3's essence, roots the Tyrannosaur on his nest beside her, and calls him home if he is stuck away.
- New options in the tool: rex:home or rex:out, turtles:far2 or turtles:home, sac:late or sac:cycle, mdef:guard or mdef:uproot, nogrow:1, frush (a forced rush), greedy (no warriors early).
- "Eggs a minute" means eggs she actually laid in that minute.
- I fixed no game code this round. Only the tool changed.

## Test 1: the early defence, now that nothing rooted attacks

Plan: hold a 2 to 3 minute rush. The computer's own rushes are small and late, so I forced them. Its soldiers were sent at the Mother as soon as it had 6 to 10. I also made my side greedy: no warriors before 5:30.

What happened:
- Crown Musketeers: 6 were sent at 4:02 and 3 reached her at 4:59. She stayed rooted. The Tyrannosaur got up and killed them. She lost no health.
- Clockwork: 10 Clock Soldiers were sent at 3:13 and 4 reached her at 3:36. They were killed. Her lowest health was 2,392.
- On 0.15.11's rules the same rushes never hurt her either.

The scripted defence test shows the real change (tools/test_brood_new_defence.gd, the Mother alone with her grubs):
- Rooted, she can't fight back. She lives through 9 Raptors (2,177 health left), 12 Clock Soldiers (1,552) and 2 Brutes with 6 Raptors (714). Against 3 Horsemen she is left with 247. Against 5 Musketeers she DIES in 121 seconds.
- Getting up to fight (the computer's way), she wins every one, with 863 to 2,156 health left.

The surprise: the computer's way of getting her up flip-flops. In the Clockwork game she uprooted and re-rooted five times between 4:28 and 5:47. Each time she took 4 seconds to get up and was down again at once. Each time her swamp vanished, so two Rootmaws went dry. Each time her GROW was cancelled. It happened again in the rematch at 8:57 to 10:31, and in the computer's own game at 13:02.

The cause, as far as I can see: an enemy targeting her from range wakes her. Her calm timer keeps counting while she uproots, so she is "calm" and roots again the moment she is up.

Verdict: a base still holds the computer's real rushes, but only because the Tyrannosaur and the Raptors fight. The Mother alone now loses to a Musketeer push unless she gets up. Getting up works, but the computer's routine for it flip-flops.

Pictures: t1_mother_uproots_to_fight.gif, t1_mother_uproots_to_fight_1003.png.

## Test 2: the ramp turtle without its bite

- Plan: a Mound Turtle rooted on the ramp at 0:36. Then a forced Clockwork rush.
- What happened: about 15 Clock Soldiers reached the turtle at 3:37. With no bite, it just soaked them. It fell at about 4:50, so it held for about 75 seconds. Three got through and reached the Mother at 4:52. My Raptors and the Tyrannosaur killed them. By 6:00 I had killed 15 for 3 lost.
- Round 1 (with its bite): 12 Raptors could not hurt it at all. Its bite was weak anyway (6 damage), so losing it changes little. Clock Soldiers simply hit harder than Raptor claws.
- Verdict: still a good wall that buys time. It is not a fortress against a real army.
- Pictures: t2_ramp_turtle_vs_clock_soldiers.gif, t2_ramp_turtle_falls_0447.png.

## Test 3: growing her on time

Plan: grow at 4:30 and 8:00. Against the Crown on Greenhold, seed 3, the Tyrannosaur at home.

What happened:
- Stage 2 started at 4:50 and was done at 5:36.
- Stage 3 started at 8:21 and was done at 9:22. Its 75 essence came from 20 Raptors offered to her.
- She could lay up to 20 eggs a minute (rate times 2.55 by 14:00). Food was now the limit.

| | 6:00 | 10:00 | 14:00 |
| --- | --- | --- | --- |
| Before (0.15.11), eggs a minute | 9 | 13 | 13 |
| Growing, eggs a minute | 13 | 17 | 14 |
| Before, food unspent | 352 | 1,482 | 2,108 |
| Growing, food unspent | 69 | 134 | 144 |
| Before, army supply | 21 | 41 | 54 |
| Growing, army supply | 12 | 48 | 61 |

- Income was the same both times: about 12,000 food by 15:00. Eggs laid in all: 139 before, 142 growing.
- My first try saved food AND waited for the essence before laying warriors. She laid 0 to 3 eggs a minute for three minutes, food piled to 3,800, and the Crown killed her at 13:29. Saving for stage 3 is a trap if the essence isn't coming.
- Verdict: growth works. It turns the 1,500 to 2,000 food that used to pile up into more army. It is a food sink, not a free boost. Stage 3's essence is the awkward part: without sacrifice it hardly comes, and with sacrifice it is trivial (see test 6).
- Picture: t3_mother_stage3_0922.png.

## Test 4: pheromones, the Tyrannosaur home or away

Plan: the same game, once with him at home, once leading every wave.

| | Home | Away (leads the waves) |
| --- | --- | --- |
| Her rate at 10:00 | x2.04 | x1.70 |
| Food unspent at 10:00 / 14:00 | 134 / 144 | 329 / 919 |
| Eggs laid in all | 142 | 136 |
| Minutes with no egg laid | 1 (stage 3) | 2 (stage 3, and the minute after 11:00) |

- While he is away, no warrior egg can be laid at all, and she lays 17% slower. When he came home she laid 21 eggs in a minute to catch up.
- Both games were draws.
- Verdict: the lever is clear and easy to feel. Sending him out costs warriors at once. It is the right trade-off.

## Test 5: expansions, two far turtles against all turtles at home

Plan: same game. Two turtles walk 16 tiles out (at 3:10 and 4:15), or all turtles stay within 12 tiles.

| | Two far turtles | All at home |
| --- | --- | --- |
| Her rate at 6:00 / 14:00 | x1.95 / x2.55 | x1.56 / x2.04 |
| Eggs a minute at 6 / 10 / 14 | 13 / 20 / 18 | 7 / 18 / 16 |
| Eggs laid in all | 151 | 139 |
| Food earned by 15:00 | 11,900 | 10,800 |

- The far turtles also spread swamp for more Rootmaws, so income rose a little as well.
- Verdict: about 10% more eggs and income. That is worth one slow walk, and it pushes you to spread out. It is a fair, modest lever.

## Test 6: SACRIFICE eggs

- Grubs can't be offered (Unit.can_sacrifice: they're the workforce). So the grub cycle can't be done. I tested a Raptor cycle instead: lay a Raptor egg (75 food, 3 Raptors), offer all three back, lay again.
- The cycle, 6:00 to 9:00: 141 creatures offered and 1,269 essence gained in three minutes. She made 15 to 20 eggs a minute instead of 10 to 12, and her clutch sat full. Food was the only limit. By 10:00 I held 1,184 essence. In round 1, essence never went above about 55.
- Each Raptor egg gives back three eggs and 27 essence. So her laying stops being a limit at all, as long as there is food.
- Late recycling (Raptors beyond 12 at home offered after 10:00, and for stage 3): 55 offered, 495 essence, 7 to 10 Brutes on the field. That was the first time the new Brood fielded Brutes in numbers. In the rematch against the Crown, Brutes cut my losses from 220 (round 1) to 78.
- Verdict: yes, it is a problem. One egg per offering, with Raptors coming three to an egg, is an egg and essence printer. It also makes stage 3's 75 essence trivial. The late use, Raptors into Brutes, is good and fun.
- Picture: t6_raptor_cycle_devour_0700.png. She devours an offered Raptor: plus 9 essence, plus one egg, clutch full.

## Test 7: the rematches, with all the new levers

All three used: growing on time, two far turtles, the Mother getting up to fight, late recycling.

- The war camp against the Clockwork (Highmoor, seed 5):
  - Round 1: she died at 10:38.
  - Now, with the computer's guard: died at 11:04.
  - With my own uproot rule: died at 9:35.
  - Grown to stage 2 she walks slower. The 81-tile march took 2 minutes 32. The Clockwork earned 10,900 to 13,500 against my 4,600 to 6,900.
- The flee game against the Clockwork (Greenhold, seed 19):
  - Round 1: she fled home and died at 14:54.
  - Now the march never started: saving for growth, and Clockwork pressure, kept the army under 14 supply.
  - She died at home: at 11:19 with the guard flip-flopping, and at 11:42 getting up to fight (she killed 15 herself).
  - The Clockwork earned 13,500 to 14,300 against my 7,300 to 7,900.
- The best plan against the Crown (Highmoor, seed 29):
  - A draw again.
  - 10 Brutes on the field. Losses 78, against 220 in round 1. Food 11,450 against the Crown's 15,100 gold.
- Verdict: against the Crown it is better, thanks to Brutes and not banking food. Against the Clockwork it is no better, even a little worse. The Clockwork still earns twice as much. A bigger Mother is a slower war camp.
- Pictures: t7_stage2_warcamp_march.gif, t7_brutes_hold_the_crown_1403.png.

## Test 8: the computer plays the new Brood

- Against the Crown, Dune Sea, seed 31.
- It never grew: stage 1 all game. Only Raptors, with waves at 3:35, 5:21 and 8:28. It lost 244 creatures for 36 kills.
- The Mother's guard flip-flopped at 13:02 to 13:24. She fell at 14:20.
- Round 1 ended in a draw. The Crown earned 15,800 to its 7,900.
- Verdict: the computer doesn't use the new levers yet, and its guard routine hurts it.

## What to tune, most important first

1. The Mother's guard routine (BroodNew.mother_guard, used by the computer): she flip-flops up and down every few seconds when an enemy targets her from range. Each time her swamp vanishes, her Rootmaws go dry and her GROW is cancelled. Count her calm time only once she is up. Wake her only for enemies really at her. Keep her up for a few seconds at least.
2. SACRIFICE eggs: one egg per offering turns each Raptor egg into three eggs and 27 essence. It removes the egg limit and floods essence (1,269 in three minutes). Give an egg per supply offered, or per whole egg's worth (three Raptors), or none for creatures that came three to an egg.
3. The rooted Mother alone dies to 5 Musketeers and nearly to 3 Horsemen. Decide if that is meant (the Brood must defend with its creatures and get her up), or if she should keep a short defensive swipe at whatever is at her nest.
4. Stage 3's 75 essence: without sacrifice it hardly comes; with sacrifice it is trivial. Tie it to something steadier, or lower it.
5. Against the Clockwork the new Brood still earns about half as much and loses. The levers raise her ceiling, but food is the limit.
6. Growing makes her slower (22 at stage 2). That makes the war camp even weaker. Maybe keep her walk speed and make only her size grow.
7. Teach the computer to grow her, to place far turtles, and to recycle late Raptors into Brutes.
8. The pheromone and new-ground levers feel right and modest. Keep them.

## Pictures

In docs/shots/brood_new_play_2/:
- t1_mother_uproots_to_fight.gif and t1_mother_uproots_to_fight_1003.png: the Mother gets up to fight Clock Soldiers at her nest; her swamp shrinks.
- t2_ramp_turtle_vs_clock_soldiers.gif and t2_ramp_turtle_falls_0447.png: the biteless ramp turtle under 15 Clock Soldiers.
- t3_mother_stage3_0922.png: the Mother at stage 3.
- t6_raptor_cycle_devour_0700.png: the Raptor cycle.
- t7_stage2_warcamp_march.gif: a stage-2 Mother marching.
- t7_brutes_hold_the_crown_1403.png: Brutes from late recycling holding the Crown.
