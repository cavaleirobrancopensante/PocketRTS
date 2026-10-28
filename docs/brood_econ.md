# Brood economy (branch brood-econ)

A proposal for the owner. It is on its own branch and not on main (version 0.15.9, merged with main 0.15.8). Balance changes wait for your word.

You decided on 28 October to redesign the Brood without buildings. This is about the Brood as it is now: it is cheap to take or to drop, and the measuring tool and the Feeding Pit numbers can serve the redesign too.

## The question

The balance study v2 (version 0.14.49) had the Crown beating the Brood in 93 games of 100, and the Clockwork beating it in 40 of 60. The Brood earned about half of what the others earned: at 5 minutes 342 biomass a minute against 760 gold and 788 cogs, at 10 minutes 456 against 1,140 and 1,234. You asked where the Brood's biomass comes from and where it goes, whether the gap is in the rules or in the computer, and for a small fix.

The short answer: both. The rules pay a grub about half of what a Labourer or a Winder earns. And the Brood computer has been wasting about a third of everything it earns, since version 0.14.42, because of one line it kept from the Crown.

## How it was measured

A new tool, tools/measure_brood_econ.gd, measures only; it changes nothing in the game.

- In a normal game it plays the Hard Brood computer against the Hard Crown or the Hard Clockwork computer, attacks on, and every 30 game seconds it writes down, for both sides: what was earned, the bank, the workers and what each one is doing, the army, supply, eggs, the Feeding Pits (how many, their crews, their ground, their distance from the capital, what a load is worth), what was spent on grubs, the army and each kind of building, grubs killed and grubs turned into buildings, and the seconds spent supply-blocked or egg-blocked.
- With peaceful=1 neither computer attacks, so the two economies can be compared cleanly.
- With perfect=1 the Brood is played by a script with no army at all: grubs from every egg, a Clutch Mound before the supply runs out, a new Feeding Pit as soon as the crews are full. That is the ceiling of the Brood's economy.
- With mode=sat it puts one economy building with its full crew next to its hall and measures the steady income: a Feeding Pit, a Crown Farm, a Clockwork Cog Press.

The maps were Frostmere, Greenhold, Ashford Crossing and Thornwood Maze, with the Brood on both sides of each map.

## One building with its full crew

Frostmere, after 40 seconds of warm-up, measured over 4 minutes. "Paid back" is the price of the building and its crew (and, for the Brood, the grub that turns into the pit), divided by its income.

| Building and crew | Income a minute | Per worker a minute | Paid back in |
|---|---|---|---|
| Crown Farm, 8 Labourers | 569 | 71 | 0.9 min |
| Clockwork Cog Press, 6 Winders | 479 | 80 | 0.9 min |
| Feeding Pit by the capital (5.5 tiles), 6 grubs | 187 | 31 | 2.3 min |
| Feeding Pit at 10 tiles, 7 grubs | 238 | 34 | 2.0 min |
| Feeding Pit at 14.5 tiles, 8 grubs | 350 | 44 | 1.5 min |
| Feeding Pit at 17.5 tiles, 8 grubs | 377 | 47 | 1.4 min |
| Feeding Pit at 21.5 tiles, 9 grubs | 423 | 47 | 1.4 min |

A grub costs what a Labourer or a Winder costs, 50, and takes the same supply. But inside a main base, where pits stand 5 to 12 tiles from the capital, a grub earns 31 to 38 a minute, less than half of a Labourer. Even at the best distance, out on the open swamp, it earns two thirds of one. A pit takes more than twice as long to pay for itself as a Farm. That is the rule FOOD_RATE, which was halved from 1.2 to 0.6 when the Brood's income was cut.

The Brood can make up for it only with numbers: its pits have no limit, and a far pit takes up to 12 grubs. The scripted perfect economy shows it. With no army at all it matched the Crown's income by 5 minutes, but with 34 to 36 grubs against the Crown's 15 or 16 workers. A real Brood that also has to build an army cannot afford twice the workers, twice the supply and twice the risk.

## What the Brood computer does with its biomass

In 8 peaceful games on main (no attacks), by 10 minutes the Brood computer had earned about 5,100 biomass. It spent about 2,200 on grubs, 2,250 on buildings and only 650 on its army. Of the buildings, 4 or 5 were extra Burrows at 350 each, and 1 to 3 were extra Brood Pens. With the grub each one eats, that is about 1,800 biomass, 32 to 43 percent of all it earned, on buildings it did not need.

The cause is one rule the Brood shares with the Crown. When a hall's land runs low, the Crown saves every coin for a new Town Hall on fresh land, and builds nothing else meanwhile. Since version 0.14.42 the Burrows have no ground: every Feeding Pit has its own. So to the computer every Burrow looked spent, all the time. It saved everything for the next Burrow: no new pits, no Spawning Den, no army, until the Burrow was paid for. Then, as soon as that Burrow stood, it looked spent too, and it started saving again. It built its first extra Burrow at about 3:50, with no army, and up to six in twelve minutes, each with a Brood Pen. The same rule also broke the Extreme rush: on main its Spawning Den goes down at 3:02 to 3:41 and it never attacks. The documented six-pool has its Den at 0:36 and attacks at 1:41.

Two smaller things made it worse. Against the Crown, once the scout had seen a single Horseman, the computer stayed on "Horsemen alert" for the whole game. Under that alert it kept its grubs at 9 and its army at home, so its income stood still to the end. And with so little army, the Crown's first attack, at about 4 minutes, killed most of its grubs: in the real games on main it lost 16 grubs in the median by 10 minutes.

In the real games on main, the Brood computer had no army at all at 5 minutes in most games (0 or 75 in value, against 560 to 1,250 for the opponent), and it lost every game against the Clockwork and most against the Crown before 12 minutes.

## The cause, in one line

The rules pay a grub half of a Labourer, and the computer threw a third of its income into Burrows it did not need. Fixing only the computer is not enough: with the old rate, a Brood that builds its Spawning Den and its army on time cannot keep enough grubs, and it died sooner than before. Fixing only the rate is not enough either: the computer would still save everything for Burrows.

## The proposed changes

One number, and six small fixes to the Brood computer. Everything else stays: the swarm, the eggs, essence from every body, the pit ground and the circles.

| What | Old | New | Why |
|---|---|---|---|
| FOOD_RATE (Defs), biomass a grub earns per second of its round trip | 0.6 | 0.9 | A grub in a main base now earns 47 to 51 a minute, far out 66 to 71: about two thirds to all of a Labourer (71) or a Winder (80), instead of under half. A pit pays for itself in 1.0 to 1.5 minutes instead of 1.4 to 2.3. |
| The Brood computer saving for a new Burrow when its "land" runs out (AI._hall_first) | always on, since a Burrow has no ground | off for the Brood | This was the big waste. A Burrow now comes only when every egg has been taken for 20 seconds with biomass in hand (AIBrood.hall_due, already there). |
| Burrows on a timer and with 700 in the bank (AI._build_up) | on | off for the Brood | Same reason: they were copied from the Crown, where a new hall means new land. |
| A Brood Pen for every Burrow | yes | one Pen | More Pens give no more essence. |
| Horsemen alert after the scout saw a Horseman | the whole game | until 150 seconds after the last Horseman seen, as for a Horseman seen with its own eyes | One Horseman at 2:00 kept the Brood on 9 grubs to the end. |
| Grub floor while Horsemen are about | stays at 9 | still rises, at half the pace (AIBrood.HORSE_FLOOR_K 0.5) | The army still comes first more often, but the economy grows. |
| Picking a builder | any grub, harvesters too | a grub out harvesting bodies is picked last | The harvester was called away to build and the bodies were left. Found by the judgement test once the computer built on time again. |

The switches AIBrood.BURROW_ON_TIMER, BURROW_ON_BANK, PEN_PER_HALL and HORSE_ALERT_FOREVER bring back the old behaviour for a "before" number.

Why 0.9 and not more or less. I tried four rates, each with the computer fixes: 0.6 (the computer fixes alone), 0.8, 0.9 and 1.0. The computer fixes alone made things worse: the computer now built its Spawning Den and its army on time, but at the old rate it could not keep enough grubs, and it died sooner, against the Crown by 6 to 9 minutes. At 1.0 the Brood won or led seven of eight short games against the Crown. At 0.8 the incomes in peaceful games came out level, but it still lost most short games against the Crown's Horseman opening. 0.9 sits between them. The short games were 12 minutes, one seed, 8 games against each opponent, scored as below:

| Short games, Brood score | against the Crown | against the Clockwork |
|---|---|---|
| computer fixes alone (rate 0.6) | 0% | 0% |
| rate 0.8 | 6% | not played |
| rate 1.0 | 94% | 25% | Following the design principles, fairness first: income parity is the target, and the computer games are the check.

## Results

### Income in peaceful games

Neither computer attacks. Twelve minutes, four maps, the Hard computers on Balanced. Income is the biomass, gold or cogs earned a minute, averaged over the two minutes around the time (the Crown's harvests come in lumps of 380). Medians of four games each.

| | Brood at 5:00 | opponent at 5:00 | Brood at 10:00 | opponent at 10:00 |
|---|---|---|---|---|
| main, against the Crown | 486 | 760 | 972 | 1,935 |
| main, against the Clockwork | 460 | 1,052 | 1,096 | 1,726 |
| rate 0.8, against the Crown | 879 | 570 | 1,408 | 1,520 |
| rate 0.8, against the Clockwork | 743 | 824 | 1,653 | 1,660 |
| proposal (0.9), against the Crown | 1,038 | 570 | 1,611 | 1,805 |
| proposal (0.9), against the Clockwork | 954 | 806 | 1,730 | 1,662 |

On main the Brood earned about half. With the proposal it earns 89 to 104 percent of the others at 10 minutes. At 5 minutes it is ahead. Against the Clockwork by 18 percent. Against the Crown by more, but that is the Crown computer's choice: when it sees Raptors early it holds back its Labourers, so it had 11 at 5:00 instead of 16, and earned 570 instead of 760. Against an unworried Crown, about 950 at 5:00 in the real games on main, the Brood's 840 to 1,040 is within about 10 percent.

### Real games

Sixteen minutes, attacks on, four maps, the Brood on both sides of each map, two seeds: 16 games against each opponent, on main and on the branch. A game still open at 16:00 counts for the side with 1.25 times the other's army value plus 50 a worker. Income, workers and army are medians of the sides still playing.

| | main, v Crown | proposal, v Crown | main, v Clockwork | proposal, v Clockwork |
|---|---|---|---|---|
| Brood wins (and ahead at 16:00) | 0 (0) | 8 (5) | 0 (0) | 1 (2) |
| Brood losses (and behind at 16:00) | 16 (0) | 1 (2) | 16 (0) | 10 (3) |
| Brood score | 0% | 81% | 0% | 19% |
| Brood income at 5:00, against theirs | 423 v 950 | 841 v 570 | 466 v 1,073 | 626 v 798 |
| Brood income at 10:00, against theirs | 268 v 2,030 | 1,139 v 1,140 | 188 v 1,819 | 1,304 v 1,620 |
| grubs against workers at 5:00 | 14 v 18 | 19 v 11 | 16 v 24 | 20 v 17 |
| grubs against workers at 10:00 | 9 v 40 | 26 v 26 | 10 v 32 | 25 v 32 |
| army at 5:00 | 0 v 492 | 348 v 578 | 0 v 895 | 105 v 1,085 |
| army at 10:00 | 75 v 2,180 | 1,772 v 695 | 0 v 4,252 | 175 v 2,210 |

Where the Brood's biomass went by 10:00, all 32 real games together:

| | main | proposal |
|---|---|---|
| biomass earned | 112,011 | 213,315 |
| spent on buildings | 64,425 (58%) | 57,050 (27%) |
| spent on the army | 22,065 (20%) | 96,090 (45%) |
| extra Burrows built | 117 (3.7 a game) | 38 (1.2 a game, when the eggs ran out) |
| Brood Pens built | 50 | 35 |
| grubs killed | 395 | 182 |

The timelines of the Brood computer's openings (tools/measure_ai_timelines.gd, Ashford Crossing and Frostmere, against a Crown that defends): on main the Extreme rush is broken (Spawning Den at 3:02 and 3:41, it never attacks), the Rush has its Den at 3:14 to 3:34 and attacks at 4:59 to 5:25, and Balanced has its Den at 4:06 to 4:28. With the proposal: Extreme rush Den 0:36, first Raptors 1:02 to 1:06, attack 1:19 to 1:25 (docs/ai_build_timelines.md says 0:36, 1:18, 1:41); Rush Den 0:51, Raptors 1:14, attack 1:27 to 1:33 (written: 0:51, 1:25, 1:47); Balanced Den 1:30, first unit 1:53.

The tests. On main, five of the Brood computer tests fail, 13 checks in all: test_ai_xrush (no Raptors by 1:30), test_ai_brood_army (no army by 3:00), test_ai_brood_horse (the Horsemen not seen, no answer), test_ai_brood_judgement (no Pen by 5:30, no essence creature by 7:00) and test_ai_rush_followup. On the branch all eleven Brood and rush tests pass: the judgement, army, Horsemen, capital, pit ground, hall, extreme rush, rush, wall against rush, plateau swamp and rush follow-up tests. After merging main 0.15.8 the same tests were run again: all pass except two checks of test_ai_rush_followup, the Crown's Horseman mop-up ("even two fresh Horsemen wait for the group", "the mop-up force goes out as one group"), which fail the same way on main 0.15.8: they are about the Crown computer. One run of test_ai_rush failed once on a Crown Farm placed off its main and passed when run again. Two checks were changed to fit the new behaviour. The Horsemen test looks at how close a stray Raptor came home while the alert lasted, not at the end of the run, because the alert now ends; and it puts the stray past the leash from the nearest Brood building (the computer now plants more pits and mounds forward, so a Raptor moved 450 pixels out was often still inside the leash, where the rule rightly leaves it alone). The harvest check counts the essence earned, not the essence in the bank, because a Brood with a Pen now spends it at once.

### After merging main 0.15.8

Main moved on while this ran (the Crown and Clockwork computers of AI round 6, faster big battles). After merging it, 8 more games on each side of the change, a third seed, the Brood on the first side of each map, 16 minutes:

| | main 0.15.8 | branch 0.15.9 |
|---|---|---|
| against the Crown: Brood wins (ahead at 16:00), losses | 0 (1), 3 | 2 (2), 0 |
| against the Crown: income at 5:00 and 10:00 | 455 and 664 v 855 and 1,615 | 854 and 1,202 v 570 and 950 |
| against the Clockwork: Brood wins (ahead), losses (behind) | 0 (0), 4 (0) | 0 (0), 2 (2) |
| against the Clockwork: income at 5:00 and 10:00 | 467 and 407 v 1,039 and 1,870 | 763 and 1,579 v 864 and 1,760 |

The same picture as before the merge.

### Crown against Clockwork

Nothing here touches them. The rate is used only for Feeding Pit loads, and every computer change is inside a Brood branch (the builder change only looks at grubs harvesting). Two Crown against Clockwork games on Frostmere, seeds 3 and 5, to 10:00, on main and on the branch: the Crown earned 9,880 and 7,600 on both. The Clockwork earned 10,886 and 10,766 on main, 11,462 and 10,128 on the branch. A game does not replay move for move from one run to the next (the pathfinding runs on threads), so small differences like these appear on the same build too.


## Risks

- Against the Crown the Brood computer now wins most games. Part of it is the Crown computer: when it sees early Raptors it holds back its Labourers and stays on 11 workers until about 5 minutes. That is the Crown computer's job to fix, not the Brood's numbers. If you would rather lower the Brood, 0.8 is the gentler step: equal incomes in peaceful games, but more losses to the Crown's Horseman opening.
- Against the Clockwork the Brood still loses most games, 19 percent. The incomes are now close, but the Clockwork's first three minutes are not: a Cog Press pays a Winder 80 a minute from the start, and the Brood's first pits, next to its capital, pay a grub about 47. By 4:00 the Clockwork has earned about 2,700 against the Brood's 1,650, and it comes at about 5:00 with an army of about 1,100 against the Brood's 300. That is the next thing to look at: the near pits (the distance bonus, FOOD_BONUS), or the Brood computer's defence at 5 minutes.
- The rushes come sooner. The Extreme rush attacks about 20 seconds earlier than its written timeline, the Rush about 15. The wall against rush test still passes: a Crown with a wall and Musketeers beats it back. But a Crown that does nothing loses sooner.
- The Brood is now often egg-blocked: about 2 minutes by 10:00, every egg taken with biomass in hand. The computer then builds a second Burrow, which is what the rule is for, but it waits 20 seconds of starving each time.
- A pit in a main base runs dry in about 9 to 11 minutes instead of 12 to 15. Far pits, out on the swamp, in about 5. So the Brood has to move out sooner, which is what the pit ground was for, but it is more exposed.
- These are computer games. A human Brood player had the full benefit of the rate change and none of the computer's waste before; for a person the change is only the rate.
- 16 games a side for each match-up is a small sample. The range on 13 of 16 is roughly 55 to 93 percent.

## Open questions

- Do you want the rate at 0.9, or the gentler 0.8?
- Should the near pits pay more (a smaller FOOD_BONUS with a higher FOOD_RATE), so the Brood's opening keeps up with the Cog Press? It would make the main base richer and the far swamp less tempting.
- The Crown computer holding back its Labourers when it sees early Raptors: should it?
- Should the Brood computer start a second Burrow sooner when its eggs run out? Or grow its capital to a Warren sooner?

## Files

- tools/measure_brood_econ.gd: the measuring tool (a game, peaceful, perfect, or one building with its crew).
- scripts/defs.gd: FOOD_RATE.
- scripts/ai.gd and scripts/ai_brood.gd: the Brood computer fixes.
- tools/test_ai_brood_horse.gd and tools/test_ai_brood_judgement.gd: the two checks changed.
- The raw game files were not committed (about 70 megabytes); the tables above are their medians.
