# The Brood Mother's laying: stages, fathers and expansions (the math)

The owner, 17:39 and 17:55, 2026-10-28: "build that and do the math". The Mother is the new Brood's only producer. The other factions grow their output by building more production buildings. She grows hers through three levers, and they stack.

## What she has now

- Her laying: one egg every 6 seconds. That is 10 eggs a minute.
- Her levers, multiplied together like this: her stage's rate, times one plus the levers.
- Lever 1, her growth STAGE: times 1, 1.3 or 1.7.
- Lever 2, FATHERS near her: plus 20% for each father within his reach of her (7 tiles). Today that is only the Tyrannosaur. Away from her, or dead, he gives nothing.
- Lever 3, EXPANSIONS: plus 15% for each Mound Turtle rooted on new ground, up to 3. New ground means 15 tiles or more from her, and from every other turtle that already counts. Turtles at home give supply and swamp, but no eggs.
- Her card shows the levers, for example "Laying +76%: stage 2, Tyrannosaur near, 1 expansion" (1.3 times 1.35). The help text has the lore. Pheromones: as in some real lizards, the males' presence speeds the female's eggs. Turtles: their chimneys pump scent into the swamp water, and she tastes new territory.

| Stage | Eggs held | Laying | Size | Walk | Swamp | To grow |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 10 | x1 (10 a minute) | x1 | 24 | 12 tiles | (the start) |
| 2 | 15 | x1.3 | x1.15 | 22 | 13.5 tiles | 300 food, 45 s |
| 3 | 20 | x1.7 | x1.3 | 20 | 15 tiles | 500 food and 75 essence, 60 s |

- GROW is on her card. She must be rooted. She lays no eggs while she grows, as a Town Hall's upgrade. Uprooting stops it and pays it all back. She never shrinks.
- Being bigger costs her: a bigger body and target, a slower walk. Her swamp grows wider.
- Stage 2 would unlock the second father, and stage 3 the third. They do not exist yet, so her card says so.
- Her sprite is scaled up for now, as the old Warren and Broodmound were (x1.15 and x1.3). tools/check_mother_fit.gd checks every start on every map. At stage 3 her body fits everywhere. At most 8% of her nest's ground hangs over other ground. The picture is docs/shots/brood_new/mother_stages.png.

## 1. The old Brood's egg output

- One Burrow lays an egg every 9 seconds. That is 6.7 eggs a minute.
- Each Clutch Mound makes every Burrow lay 10% faster, up to three. A Burrow with three mounds lays 8.7 a minute.
- The hall levels hold more eggs: a Burrow 5, a Warren 10, a Broodmound 15. They do not lay faster.
- The Warren costs 150 biomass and 40 seconds. The Broodmound costs 250 and 50 essence, and 60 seconds.
- In the study of 0.14.49 (docs/study_v2, 2,000 games), the typical old Brood had one Burrow at 4, 8 and 12 minutes. The better quarter had one Burrow until 8 minutes and two by 12.
- So a typical old Brood laid about 7 eggs a minute at 4 minutes, and about 9 at 8 and 12. A healthy one laid about 17 at 12 minutes, with two Burrows and three mounds. Three Burrows would lay 26.
- For that capacity a healthy old Brood paid a second Burrow (350) and its upgrades (150, then 250 and 50 essence each). That is about 750 to 1,150 biomass and 50 to 100 essence by 12 minutes.

## 2. The Crown and the Clockwork

- One Barracks trains a Musketeer every 15 seconds: 4 a minute. One Clockwork works makes a Clock Soldier every 16 seconds: about 3.75 a minute. One trained unit is worth about one egg (a Raptor egg is three Raptors for 75).
- Their production buildings in the study, the typical game and the better quarter: the Crown 1 and 2 at 4 minutes, 3 and 4 at 8, 5 and 6 at 12. The Clockwork 2 and 2, 2 and 3, 5 and 6.
- Their income a minute in the study: the Crown about 380, 760 and 1,780 at 4, 8 and 12 minutes. The Clockwork about 700, 950 and 1,750. The old Brood only about 340, 390 and 520.
- The play job's games (docs/brood_new_play.md): the Clockwork out-earned the new Brood about 11,000 to 6,000 by 10:00.

## 3. The new Mother's ceiling before this

- 10 eggs a minute, 13 with three turtles anywhere.
- In the play job's games it bound from about 8:00. Her eggs sat at zero and food piled up to 1,100 or 1,900.

## 4. The numbers chosen, and why

Eggs a minute at the stated times, the most that could be used:

| | 4 min | 8 min | 12 min |
| --- | --- | --- | --- |
| Old Brood, typical | 7 | 9 | 9 |
| Old Brood, healthy | 7 | 9 | 17 (26 with three Burrows) |
| Crown, typical and better quarter | 4 to 8 | 12 to 16 | 20 to 24 |
| Clockwork, typical and better quarter | 7.5 | 7.5 to 11 | 19 to 22 |
| New Brood before (stage 1, three turtles anywhere) | 10 to 13 | 13 | 13 |
| New Brood now: Tyrannosaur home, 1 then 2 expansions, growing on time | 12 | 17.6 (stage 2, 1 expansion) | 25.5 (stage 3, 2 expansions) |

- The full stack at 12 minutes, 25.5 eggs a minute, lands where a healthy old Brood with three Burrows would be, and where the Crown's and the Clockwork's better quarter train. It does not beat them.
- At 8 minutes, 17.6 is about the Crown's better quarter (16). At 4 minutes the cap does not matter: income is the limit (about 400 food a minute pays for about 5 eggs).
- No lever is worthless, and none is a must. At 12 minutes, stage 3 alone gives 17 a minute. The Tyrannosaur adds 20% to that, two expansions 30%. Without growing at all, the Tyrannosaur and two expansions give 15. Growing is the biggest lever, as the halls were for the old Brood, but a Brood that never grows still lays more than a typical old one.
- The growing cost, 800 food and 75 essence in all, matches what a healthy old Brood paid for its second hall and upgrades (750 to 1,150 and 50 to 100 essence). The real price is also the eggs not laid while she grows: about 10 at stage 2 and 16 at stage 3.
- The grow times, 45 and 60 seconds, match the Warren's 40 and the Broodmound's 60. Started when the food is there (the computer and the coached player grow at 300 or 500 plus a reserve, from 4:30 and from 8:00), stage 2 lands at about 5 to 6 minutes, stage 3 at about 9 to 10, when food piles up.
- Fairness and anti-snowball (docs/design_principles.md): she must be rooted, so she grows only at home and only when calm. Uprooting stops it. She becomes a bigger, slower target. The levers raise the ceiling, not the income: a Brood whose food runs short gains little.

## 5. The play check

Three coached games with tools/play_brood_new.gd (0.15.13, the Crown on Hard, Greenhold, seed 3; the old 0.15.11 coach could no longer root the Tyrannosaur, so "before" is the same coach with nogrow:1). Eggs laid in the minute before, and food unspent:

| Game | 6:00 | 10:00 | 14:00 |
| --- | --- | --- | --- |
| Before: no growing, Tyrannosaur home | 13 eggs, 36 food | 15 eggs, 348 food | (game ended at 13:00) |
| Growing, Tyrannosaur home | 13 eggs, 40 food | 12 eggs, 376 food (stage 2 at 10:09) | 4 eggs, 1,669 food |
| Growing, Tyrannosaur fights away | 13 eggs, 40 food | 13 eggs, 741 food (stage 2 at 6:24) | 17 eggs, 1,769 food |

- Honest reading: in these games the coached economy earned about 1,150 food a minute and spent nearly all of it until 10:00. Food, not the Mother, was the limit. So growing changed little here. Stage 2 came late in the home game (10:09), because the food for it was never there earlier.
- Stage 3 never came in these games: they gathered no essence (it stayed at 0), and stage 3 needs 75.
- With the Tyrannosaur fighting away, the warrior eggs stopped and food piled up (726 at 8:00). The coach grew her early (6:24). When he came home, she laid 25 eggs in the minute to 12:00, more than stage 1 can.
- At 14:00 both games were at the supply cap (147 and 134 of 148): her eggs sat full (15 and 14) and food piled up (1,669 and 1,769). From there supply, not her laying, is the limit.
- The pay-off of the levers shows where the play job saw food pile up (its games 1 and 8). A longer test with expansions (the ninja plan) is still to run.
