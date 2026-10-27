# Brood AI fixes (version 0.14.45)

The owner said the Brood computer was struggling a lot. His log from version 0.14.22 (Thornwood Maze, a Hard Brood on Rush against his Crown) showed five things. Its essence stayed at zero until minute 7, so it could only make Raptors. It was stuck at the supply limit, 28 of 28, around minute 5. Its army sat at 13 Raptors from minute 4 to minute 6. At minute 7 it attacked with 11 Raptors, worth 275, into 11 Musketeers and a Cannon worth 955, and lost 9 of them. And its rush had already failed by 2:25. The lower biomass income, about half the Crown's gold, is a deliberate nerf and was not touched. Only the computer's decisions changed, in its own file, scripts/ai_brood.gd, with small hooks in the Brood branches of scripts/ai.gd.

## What changed

Grubs. The old Brood stopped making Grubs at 9 for as long as its army was smaller than it wanted, and it wanted more than any enemy army it could see. Against a Crown that kept growing, that meant its income stood still while the enemy's grew. Now a floor rises by one Grub every 20 seconds after 2:30, a little slower on a Rush. Under the floor, Grubs come first. Above it, the old rule applies: the army first while it is behind. With the enemy in its base, or Horsemen hunting its Grubs, the floor drops back to 9, and the army comes first. Far above the floor the eggs go to the army anyway.

Supply. Clutch Mounds now go up ahead of need. The margin is worked out from what the eggs could fill while a mound is building. When the supply is really short, six or less, the mound's 75 biomass is put by first. The Brood is no longer blocked at its limit with biomass in hand.

Essence. The Brood Pen goes up after the economy, at about 14 Grubs with a couple of eggs of Raptors at home, which is around minute 5. With Horsemen about it comes at once. At the Pen the computer offers up a few spare Raptors for the essence of two eggs of Spitters, but never more than 5 percent of the biomass it has earned. An offered Raptor gives back only about a third of its cost as essence (9 essence a Raptor since version 0.14.40), so this is a small budget, not a habit. Grubs harvest the bodies left on its side of the map after a fight. And once the essence is there, an egg waits for a Spitter's 90 biomass instead of always hatching Raptors at 75. Before, the essence could sit unused for minutes.

A second Burrow. When every egg is taken while biomass piles up, the eggs and not the income are the limit, so the computer lays out another Burrow.

Attacks. The computer remembers every enemy soldier it has seen, for eight minutes, or until it sees it fall. No wave goes into an army clearly stronger than its own as far as it knows: it needs one and a half times the known enemy value, or 0.8 times for a rush. Defenders have walls, guns and the first volley, so a wave needs the edge. Instead it defends and builds up. If it has seen nothing of the enemy army for a minute and a half, it first sends two Raptors to look. And a wave that is clearly losing its fight pulls back home: at once against two and a half times its worth, or after losing a quarter of its strength against one and a half times its worth. Two enemy Horsemen hunting the Grubs are answered by the Raptors as a pack.

## How it was measured

The tool is tools/measure_brood_ai.gd. It plays a Hard Brood against a Hard Crown computer on Balanced, headless, for ten game minutes, and prints essence, supply-blocked seconds, army value each minute, the Pen's time, and every attack with its outcome. The word "old" switches the new judgement off, which is exactly the Brood computer on main before this work. Each version played 12 games on the build merged with main's version 0.14.44, which already has the new essence rules (a Raptor offered up gives 9 essence, a body harvested 2 a supply) and every Feeding Pit's own ground. The games were on Thornwood Maze and Ashford Crossing, with the Rush and Balanced plans, three seeds each. Army value is the match log's value, the cost of every unit alive.

Seed 1 is a special case. On it the Crown computer opens with a Horseman rush. On Thornwood Maze it wrecked the new Brood in both games, at 6:01 and 7:52, and the old one in one of two, at 8:58. On Ashford Crossing both versions lived, and the new one had the bigger army at minute 9, 660 and 875 against 475 and 415. In earlier runs the counts went the other way as often, so this is noise around a real weakness, listed at the end. The averages below are the eight games on seeds 2 and 3.

| Average of 8 games | Old | New |
|---|---|---|
| Essence earned by 7:00 | 16 | 29 |
| Brood Pen up at | 5:38 | 5:20 |
| Seconds supply-blocked | 24 | 0 |
| Army value at 3:00 | 134 | 134 |
| Army value at 5:00 | 312 | 275 |
| Army value at 7:00 | 372 | 414 |
| Army value at 9:00 | 481 | 1,144 |
| Grubs at 7:00 | 28 | 25 |

In short: essence comes in about twice as fast, the supply block is gone, the army is about as big as before at 5 and 7 minutes, and by minute 9 it is more than twice as big, with Spitters in it. The old Brood's army mostly stood still between minute 7 and 9; the new one keeps growing.

Attacks after the opening rush, in those eight games:

| | Old | New |
|---|---|---|
| Waves sent | 0 | 10 |
| Biomass value killed | 0 | 5,770 |
| Biomass value lost | 0 | 7,490 |
| Pulled back from a lost fight | none | 4 |

The old Brood never attacked in these games. The new one attacks once its army is big, at minute 8 or 9, into what it has seen. Those waves went in at between 0.9 and 1.35 times the real Crown army, never into a much stronger one, and four were pulled back home when the fight turned. They kill about three quarters of what they lose: attacking a walled base with guns costs the attacker more than the defender. In an earlier run, with a memory of four minutes and a ratio of 1.25, the waves went into Crown armies up to one and a half times their worth and killed only 0.57 of what they lost, which is why the memory went to eight minutes and the ratio to one and a half.

In the owner's own game, the minute 7 attack of 11 Raptors, worth 275, into an army of 955 that it had seen, would now be held: it needs 1.5 times what it knows, and the judgement test checks that it holds with 800 against 720 seen.

The opening rush is unchanged: six Raptors at about 1:52, which a Crown with a wall and Musketeers beats back, as the design wants. What comes after it is close to the old size at minute 5, 225 to 325 in army, because the rush keeps a slower Grub floor; by minute 9 it is between 2 and 4 times bigger than the old rush's.

## Measuring each part

Each part can be switched off in the measuring tool alone, with off:reserve, off:pen, off:offer, off:wait or off:floor. Doing that showed that the first version of this work was worse than the old Brood at minute 5, with half the army. The cause was holding biomass back. It put biomass by for the Gorge Pit, the second Burrow, every Clutch Mound the wide margin called for, and a Pen at 3:30. That kept the eggs and the Grubs waiting. Those holds were removed or narrowed, and the Pen moved to after the economy. Every number in the tables above is from the final version, on the merged build.

## Tests

The Brood judgement test, tools/test_ai_brood_judgement.gd, passes. It covers holding a wave, pulling back from a lost fight, harvesting bodies, putting a mound by, and a game where the Pen stands by 5:30 and an essence creature hatches by 7:00. The other AI tests pass too: Brood army, Brood against Horsemen, extreme rush, rush, rush follow-up, wall against rush, all the scout tests, army response and air defence. Some tests fail in parts that run no Brood computer code: worker safety, which is Crown against Crown, the Clockwork site case in the Brood fixes test, and, now and then, the Crown Horseman mop-up case of the rush follow-up test, which fails the same way on main. A small crash in the scout's threat check, a freed attacker, was fixed along the way.

## Still open

The Crown computer's Horseman rush, at about 2:20, still wrecks the Brood computer, old and new alike. Raptors do little against Horsemen, and the Brood's answer, Spitters and Brutes, needs the Pen and the Gorge Pit sooner than its income allows. That deserves its own job.
