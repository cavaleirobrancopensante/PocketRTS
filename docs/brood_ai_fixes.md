# Brood AI fixes (version 0.14.33)

The owner said the Brood computer was struggling a lot. His log from version 0.14.22 (Thornwood Maze, a Hard Brood on Rush against his Crown) showed five things. Its essence stayed at zero until minute 7, so it could only make Raptors. It was stuck at the supply limit, 28 of 28, around minute 5. Its army sat at 13 Raptors from minute 4 to minute 6. At minute 7 it attacked with 11 Raptors, worth 275, into 11 Musketeers and a Cannon worth 955, and lost 9 of them. And its rush had already failed by 2:25. The lower biomass income, about half the Crown's gold, is a deliberate nerf and was not touched. Only the computer's decisions changed, in its own file, scripts/ai_brood.gd, with small hooks in the Brood branches of scripts/ai.gd.

## What changed

Grubs. The old Brood stopped making Grubs at 9 for as long as its army was smaller than it wanted, and it wanted more than any enemy army it could see. Against a Crown that kept growing, that meant its income stood still while the enemy's grew. Now a floor rises by one Grub every 20 seconds after 2:30, a little slower on a Rush. Under the floor, Grubs come first. Above it, the old rule applies: the army first while it is behind. With the enemy in its base, or Horsemen hunting its Grubs, the floor drops back to 9, and the army comes first. Far above the floor the eggs go to the army anyway.

Supply. Clutch Mounds now go up ahead of need. The margin is worked out from what the eggs could fill while a mound is building. When the supply is really short, six or less, the mound's 75 biomass is put by first. The Brood is no longer blocked at its limit with biomass in hand.

Essence. The Brood Pen goes up after the economy, at about 14 Grubs with a couple of eggs of Raptors at home, which is around minute 5. With Horsemen about it comes at once. At the Pen the computer offers up a few spare Raptors for the essence of two eggs of Spitters, but never more than 5 percent of the biomass it has earned. An offered Raptor gives back only 12 percent of its cost, so this is a small budget, not a habit. Grubs harvest the bodies left on its side of the map after a fight. And once the essence is there, an egg waits for a Spitter's 90 biomass instead of always hatching Raptors at 75. Before, the essence could sit unused for minutes.

A second Burrow. When every egg is taken while biomass piles up, the eggs and not the income are the limit, so the computer lays out another Burrow.

Attacks. The computer remembers every enemy soldier it has seen, for four minutes, or until it sees it fall. No wave goes into an army clearly stronger than its own as far as it knows: it needs 1.25 times the known enemy value, or 0.8 times for a rush. Instead it defends and builds up. If it has seen nothing of the enemy army for a minute and a half, it first sends two Raptors to look. And a wave that is clearly losing its fight pulls back home: at once against two and a half times its worth, or after losing a quarter of its strength against one and a half times its worth. Two enemy Horsemen hunting the Grubs are answered by the Raptors as a pack.

## How it was measured

The tool is tools/measure_brood_ai.gd. It plays a Hard Brood against a Hard Crown computer on Balanced, headless, for ten game minutes, and prints essence, supply-blocked seconds, army value each minute, the Pen's time, and every attack with its outcome. The word "old" switches the new judgement off, which is exactly the Brood computer on main before this work. Each version played 12 games: Thornwood Maze and Ashford Crossing, the Rush and Balanced plans, three seeds each. Army value is the match log's value, the cost of every unit alive.

Seed 1 is a special case. On it the Crown computer opens with a Horseman rush, and both the old and the new Brood are wrecked by it on both maps, with almost no army or Grubs left by minute 7. Repeat games went either way for either version. That is a separate weakness, listed at the end. The averages below are the eight games on seeds 2 and 3.

| Average of 8 games | Old | New |
|---|---|---|
| Essence earned by 7:00 | 4 | 18 |
| Brood Pen up at | 5:54 | 5:33 |
| Seconds supply-blocked | 11 | 0 |
| Army value at 3:00 | 97 | 119 |
| Army value at 5:00 | 303 | 297 |
| Army value at 7:00 | 366 | 319 |
| Army value at 9:00 | 290 | 920 |
| Grubs at 7:00 | 26 | 22 |

In short: essence now comes in, the supply block is gone, the army is as big as before at 5 and 7 minutes, and by minute 9 it is about three times bigger, with Spitters in it. In most games the old Brood's army shrank between minute 7 and 9; the new one keeps growing, on more Grubs and with Spitters.

Attacks after the opening rush, in those eight games:

| | Old | New |
|---|---|---|
| Waves sent | 1 | 7 |
| Biomass value killed | 1,285 | 2,985 |
| Biomass value lost | 725 | 3,545 |

The old Brood mostly never attacked at all in ten minutes. The new one attacks once its army is big, at minute 8 or 9, into what it has seen. Those waves went in at between 0.7 and 1.15 times the real Crown army, never into a much stronger one, and one pulled back from a lost fight. They trade about evenly, which is what a fair fight should look like.

The opening rush is unchanged: six Raptors at about 1:52, which a Crown with a wall and Musketeers beats back, as the design wants. What changed is what comes after it. The rush keeps a slower Grub floor, and by minute 5 its army is worth 250 to 325 instead of the 75 to 125 of the in-between versions.

## Measuring each part

Each part can be switched off in the measuring tool alone, with off:reserve, off:pen, off:offer, off:wait or off:floor. Doing that showed that the first version of this work was worse than the old Brood at minute 5, with half the army. The cause was holding biomass back. It put biomass by for the Gorge Pit, the second Burrow, every Clutch Mound the wide margin called for, and a Pen at 3:30. That kept the eggs and the Grubs waiting. Those holds were removed or narrowed, and the Pen moved to after the economy. Every number in the tables above is from the final version.

## Tests

The Brood judgement test, tools/test_ai_brood_judgement.gd, passes. It covers holding a wave, pulling back from a lost fight, harvesting bodies, putting a mound by, and a game where the Pen stands by 5:30 and an essence creature hatches by 7:00. The other AI tests pass too: Brood army, Brood against Horsemen, extreme rush, rush, rush follow-up, wall against rush, all the scout tests, army response and air defence. Two tests fail the same way on main and do not touch the Brood: worker safety, which is Crown against Crown, and the Clockwork site case in the Brood fixes test. A small crash in the scout's threat check, a freed attacker, was fixed along the way.

## Still open

The Crown computer's Horseman rush, at about 2:20, still wrecks the Brood computer, old and new alike. Raptors do little against Horsemen, and the Brood's answer, Spitters and Brutes, needs the Pen and the Gorge Pit sooner than its income allows. That deserves its own job.
