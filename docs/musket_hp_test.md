# The Musketeer's health: a test (55 / 65)

The owner, 2026-10-30: the Crown is "at a distance we pound them to shreds with our gunpowder, but at close range we are in trouble"; the Musketeer may have too much health for that. Tested: the Musketeer at **55** (today 70, no armour) and the Guardsman (the Armour refit) at **65** (today 90 = 70 + 20, armour 1).

This is a test. **No game number was changed.** The variants are put on the men by a test-only override in the measuring tools (tools/musket_hp.gd, applied every frame; it keeps each man's share of his health and gives the Armour refit +10 instead of +20). Version 0.22.9 (+ this branch). The job was cut short on the owner's word: what was not run is listed at the end.

## The short answer

- **The cut does not make "pound at range" happen; it only makes "trouble up close" worse.** In the open, 8 Musketeers on HOLD get **one volley, at most one and a half** (8 to 13 shots) into anything that walks at them from 16 tiles, before it reaches them: 4 to 5 Raptors of 26 die, 0 to 1 Tyrant Challengers, no Brute. That is the same at 70 and at 55 (the shots before contact do not change). The "at range" part is decided by range against speed and reload, not by health.
- **Against the Brood in the open the line already loses at equal cost at 70** (Raptors 2 of 5, Tyrant Challengers, Brutes, Spitters 0 of 5). At 55 the trades fall further (Raptors 1.02 to 0.71, Spitters 0.40 to 0.21).
- **The early defence is not broken.** The walled Crown against the Extreme rush (tools/test_ai_wall_vs_rush.gd, 2 maps x 2 seeds) passes every check at 55, as at 70: 0 or 1 Musketeers lost, 1 labourer, no building, about 26-32 Raptors killed. The wall does the work; the men behind it are hardly hit. On the ramp the line holds against Raptors, Tyrant Challengers, Clock Soldiers, Springers and Horsemen at both healths (5 of 5).
- **The Guardsman at 65 is the real problem.** 90 to 65 is a 28% cut (the Musketeer's is 21%) and 1 armour does not make it up: the Armour research would buy +10 health and +1 armour. Guardsmen against Horsemen go from 5 of 5 wins to 0 of 5 (in the open); against Springers from 5 of 5 to 3 (at range) and 2 (close); on the ramp his trades fall by half to two thirds. In one computer game (Crown v Clockwork, Ashford Crossing) a 15-Guardsman army was wiped at 9-10 minutes (Crown lost 1,515, Clockwork 880) where at 90 the same game went 81 to 1,780.
- **Crown v Clockwork gets worse at 55/65:** Springers flip from a Crown edge to a Clockwork edge (Musketeers at range 6 of 10 to 0 of 5). Clock Soldiers are still beaten every time at range.
- **The Toad's TONGUE is not a sure kill at 55.** A pulled Musketeer who is ordered straight back loses about 7 health a Raptor waiting at the Toad's feet (3 Raptors: 22, 6: 40, 9: 58). At 70 he dies to 12 Raptors, at 55 to 9. So the threshold moves from about 11 Raptors to about 8; with a few Raptors he still walks home.

## Recommendation: keep 70 / 90, or a small cut to 65 / 85 (not 55 / 65)

1. **Do not take 55 / 65.** It does not add "pounding at range", it weakens the Crown in the matchups that were fair (Springers, Horsemen, the computer's Guardsman armies), and it guts the Armour research.
2. **If the owner wants a little more "trouble up close": Musketeer 65, Guardsman 85 (keep the +20).** The blows-to-kill table below shows why 65: it changes only what the fastest close-range units need (Raptors 12 bites to 11, a Horseman's pistol and sabre 4 blows to 3) and leaves Tyrant Challengers, Brutes, Spitters, Clock Soldiers and Springers exactly as today. In the fights 65/85 measured like today within the noise (5 seeds). 60 is the same as 55 against most enemies (the same blow counts), so 60 is not a real "in between".
3. **The lever for "pound them at range" is the volleys before contact, not health:** musket range (190) against approach speed (Raptors 96, Horsemen 112) and the 2.8 s reload give one volley. Ideas for another test: a first shot that is ready faster, a little more range, or slowing what walks through musket fire. Walls, high ground and cannons already give the Crown its "at a distance" fights.
4. A side finding: at equal cost Spitters beat a Musketeer line at range in the open 5 of 5 at 70 (their acid burns on after the hit). Worth a look on its own.

## Blows to kill (worked out from Defs: damage less armour; a Horseman opens with his 30 pistol)

| Attacker (damage) | Musketeer 70 | 65 | 60 | 55 | Guardsman 90 | 85 | 80 | 65 |
|---|---|---|---|---|---|---|---|---|
| Raptor (6) | 12 | 11 | 10 | 10 | 18 | 17 | 16 | 13 |
| Tyrant Challenger (15) | 5 | 5 | 4 | 4 | 7 | 7 | 6 | 5 |
| Brute (26) | 3 | 3 | 3 | 3 | 4 | 4 | 4 | 3 |
| Spitter (8, acid strips armour) | 9 | 9 | 8 | 7 | 12 | 11 | 10 | 9 |
| Clock Soldier (10, fully wound) | 7 | 7 | 6 | 6 | 10 | 10 | 9 | 8 |
| Springer (10) | 7 | 7 | 6 | 6 | 10 | 10 | 9 | 8 |
| Horseman (pistol 30, sabre 18) | 4 | 3 | 3 | 3 | 5 | 5 | 4 | 4 |

## 1. Small fights

tools/study_musket_hp.gd (runner tools/study_musket_hp.sh, table tools/study/musket_hp_table.py). 8 Musketeers (Matchlock + Socket Bayonet, 81 a man at face value) or 8 Guardsmen (the same + Armour, 97) on HOLD in two ranks, against one kind of enemy at equal cost: Raptors 25, Tyrant Challengers 110, Brutes 170, Spitters 47.5, Clock Soldiers 70, Springers 125, Horsemen 155 (with the horse). "range": the enemy attack-moves in from 16 tiles on the flat middle of Dune Sea; "close": it starts 70 px away; "ramp": the Crown's own Cottage wall and gate at Greenhold's main ramp, the line behind it. 5 seeds each (jittered positions). Cells: Crown wins / fights, the trade (value the enemy lost / value the Crown lost), men lost of 8. Second half: musket shots fired and enemies down before the first contact, when the first man fell and when half the line was down (s). 60/80 and 65/85 were run only for some rows ("-": not run). A "now" row with 10 fights merged two identical runs.

| Enemy (n) | Where | Line | now: wins, trade, men lost | 55/65: wins, trade, men lost | 60/80: wins, trade, men lost | 65/85: wins, trade, men lost | now: shots / foes down before contact, 1st man down, half down (s) | 55/65: shots / foes down before contact, 1st man down, half down (s) | 60/80: shots / foes down before contact, 1st man down, half down (s) | 65/85: shots / foes down before contact, 1st man down, half down (s) |
|---|---|---|---|---|---|---|---|---|---|---|
| Raptors (31) | range | Guardsmen | 2/5, 1.03, 6.8 | 0/5, 0.39, 8.0 | 1/5, 0.75, 7.4 | 4/5, 1.20, 6.2 | 11 / 3.8, 5.8, 9.4 | 12 / 4.2, 5.2, 7.2 | 11 / 4.0, 5.5, 8.4 | 11 / 3.6, 5.8, 8.9 |
| Raptors (26) | range | Musketeers | 2/5, 1.02, 6.8 | 1/5, 0.71, 7.6 | 1/5, 0.71, 7.6 | 2/5, 0.93, 7.0 | 11 / 4.6, 5.2, 8.1 | 11 / 4.6, 5.2, 7.3 | 11 / 4.6, 5.2, 7.3 | 11 / 4.8, 5.2, 7.7 |
| Raptors (31) | close | Guardsmen | 1/5, 0.74, 7.4 | 0/5, 0.40, 8.0 | 1/5, 0.62, 7.4 | 1/5, 0.77, 7.4 | 2 / 0.4, 2.6, 4.0 | 2 / 0.4, 2.1, 2.8 | 2 / 0.4, 2.5, 3.5 | 2 / 0.4, 2.5, 4.0 |
| Raptors (26) | close | Musketeers | 0/5, 0.39, 8.0 | 0/5, 0.37, 8.0 | 0/5, 0.37, 8.0 | 0/5, 0.39, 8.0 | 1 / 0.0, 2.3, 2.9 | 1 / 0.0, 1.4, 2.5 | 1 / 0.0, 1.4, 2.5 | 1 / 0.0, 1.9, 2.8 |
| Raptors (31) | ramp | Guardsmen | 5/5, 6.66, 1.2 | 5/5, 4.99, 1.6 | - | - | 31 / 12.6, 11.8, - | 32 / 13.0, 11.3, - | - | - |
| Raptors (26) | ramp | Musketeers | 5/5, 20.06, 0.4 | 5/5, 20.06, 0.4 | - | - | 42 / 17.4, 12.6, - | 44 / 16.8, 12.8, - | - | - |
| Tyrant Challengers (7) | range | Guardsmen | 0/5, 0.60, 8.0 | 0/5, 0.43, 8.0 | 0/5, 0.54, 8.0 | - | 10 / 0.2, 7.6, 16.3 | 10 / 0.4, 6.9, 11.5 | 10 / 0.4, 7.2, 13.4 | - |
| Tyrant Challengers (6) | range | Musketeers | 0/5, 0.41, 8.0 | 0/5, 0.37, 8.0 | 0/5, 0.37, 8.0 | - | 11 / 0.4, 7.2, 12.3 | 11 / 0.4, 6.7, 9.5 | 11 / 0.4, 6.7, 9.5 | - |
| Tyrant Challengers (7) | close | Guardsmen | 0/5, 0.28, 8.0 | 0/5, 0.23, 8.0 | 0/5, 0.28, 8.0 | - | 6 / 0.0, 3.7, 8.3 | 6 / 0.0, 2.9, 4.8 | 6 / 0.0, 2.9, 5.7 | - |
| Tyrant Challengers (6) | close | Musketeers | 0/5, 0.17, 8.0 | 0/5, 0.14, 8.0 | 0/5, 0.14, 8.0 | - | 6 / 0.0, 3.4, 5.7 | 6 / 0.0, 2.7, 3.5 | 6 / 0.0, 2.7, 3.5 | - |
| Tyrant Challengers (7) | ramp | Guardsmen | 5/5, 13.23, 0.6 | 4/5, 4.16, 1.8 | - | - | 34 / 1.0, 23.1, - | 35 / 1.2, 21.5, 35.0 | - | - |
| Tyrant Challengers (6) | ramp | Musketeers | 5/5, 40.74, 0.2 | 5/5, 40.74, 0.2 | - | - | 30 / 0.6, 17.8, - | 30 / 0.6, 15.8, - | - | - |
| Brutes (5) | range | Guardsmen | 0/5, 0.13, 8.0 | 0/5, 0.18, 8.0 | 0/5, 0.13, 8.0 | - | 8 / 0.0, 9.9, 15.3 | 8 / 0.0, 8.8, 12.9 | 8 / 0.0, 9.9, 15.3 | - |
| Brutes (4) | range | Musketeers | 0/5, 0.16, 8.0 | 0/5, 0.16, 8.0 | 0/5, 0.16, 8.0 | - | 8 / 0.0, 9.4, 14.4 | 8 / 0.0, 9.4, 14.4 | 8 / 0.0, 9.4, 14.4 | - |
| Brutes (5) | close | Guardsmen | 0/5, 0.00, 8.0 | 0/5, 0.00, 8.0 | 0/5, 0.00, 8.0 | - | 5 / 0.0, 3.3, 9.1 | 5 / 0.0, 3.1, 5.3 | 5 / 0.0, 3.3, 9.1 | - |
| Brutes (4) | close | Musketeers | 0/5, 0.00, 8.0 | 0/5, 0.00, 8.0 | 0/5, 0.00, 8.0 | - | 4 / 0.0, 3.6, 7.8 | 4 / 0.0, 3.6, 7.8 | 4 / 0.0, 3.6, 7.8 | - |
| Brutes (5) | ramp | Guardsmen | 0/5, 0.35, 8.0 | 0/5, 0.22, 8.0 | - | - | 19 / 0.4, 16.4, 22.6 | 19 / 0.2, 15.2, 19.9 | - | - |
| Brutes (4) | ramp | Musketeers | 2/5, 0.90, 7.0 | 2/5, 0.90, 7.0 | - | - | 25 / 0.6, 18.4, 28.4 | 25 / 0.6, 18.4, 28.4 | - | - |
| Spitters (16) | range | Guardsmen | 0/5, 0.31, 8.0 | 0/5, 0.20, 8.0 | 0/5, 0.24, 8.0 | - | - / 0.0, 7.1, 11.1 | - / 0.0, 5.9, 8.6 | - / 0.0, 6.5, 10.7 | - |
| Spitters (14) | range | Musketeers | 0/5, 0.40, 8.0 | 0/5, 0.21, 8.0 | 0/5, 0.25, 8.0 | - | - / 0.0, 6.5, 10.6 | - / 0.0, 5.5, 8.4 | - / 0.0, 5.8, 8.8 | - |
| Spitters (16) | close | Guardsmen | 0/5, 0.27, 8.0 | 0/5, 0.17, 8.0 | 0/5, 0.24, 8.0 | - | 0 / 0.0, 3.5, 6.0 | 0 / 0.0, 3.4, 4.2 | - / 0.0, 3.5, 5.2 | - |
| Spitters (14) | close | Musketeers | 0/5, 0.19, 8.0 | 0/5, 0.13, 8.0 | 0/5, 0.19, 8.0 | - | - / 0.0, 3.5, 4.2 | - / 0.0, 3.4, 4.0 | - / 0.0, 3.4, 4.2 | - |
| Spitters (16) | ramp | Guardsmen | 0/5, 0.49, 8.0 | 0/5, 0.31, 8.0 | - | - | - / 0.0, 7.7, 13.1 | - / 0.0, 7.0, 10.8 | - | - |
| Spitters (14) | ramp | Musketeers | 0/5, 0.56, 8.0 | 0/5, 0.41, 8.0 | - | - | - / 0.0, 7.2, 13.2 | - / 0.0, 6.6, 10.3 | - | - |
| Clock Soldiers (11) | range | Guardsmen | 5/5, 4.41, 1.8 | 5/5, 3.05, 2.6 | 5/5, 3.31, 2.4 | - | 13 / 2.0, 9.8, - | 13 / 2.0, 9.0, 13.8 | 13 / 1.8, 9.2, - | - |
| Clock Soldiers (9) | range | Musketeers | 5/5, 4.86, 1.6 | 5/5, 2.99, 2.6 | 5/5, 3.54, 2.2 | - | 13 / 1.8, 8.7, 15.2 | 12 / 1.6, 8.5, 14.9 | 12 / 1.4, 9.3, 13.5 | - |
| Clock Soldiers (11) | close | Guardsmen | 5/5, 2.33, 3.4 | 5/5, 1.53, 5.2 | 5/5, 1.89, 4.2 | - | 8 / 0.0, 5.5, 10.8 | 8 / 0.0, 3.7, 6.3 | 8 / 0.0, 5.0, 8.3 | - |
| Clock Soldiers (9) | close | Musketeers | 5/5, 2.78, 2.8 | 4/5, 1.23, 5.6 | 5/5, 2.43, 3.2 | - | 8 / 0.0, 4.3, 8.0 | 8 / 0.0, 3.1, 5.6 | 8 / 0.0, 4.3, 7.6 | - |
| Clock Soldiers (11) | ramp | Guardsmen | 5/5, 3850.00, 0.0 | 5/5, 3850.00, 0.0 | - | - | - / 0.0, -, - | - / 0.0, -, - | - | - |
| Clock Soldiers (9) | ramp | Musketeers | 5/5, 3150.00, 0.0 | 5/5, 3150.00, 0.0 | - | - | - / 0.0, -, - | - / 0.0, -, - | - | - |
| Springers (6) | range | Guardsmen | 5/5, 1.68, 4.6 | 3/5, 0.87, 6.8 | 4/5, 1.24, 5.2 | - | - / 0.0, 8.2, 17.8 | - / 0.0, 6.8, 11.9 | - / 0.0, 7.6, 15.5 | - |
| Springers (5) | range | Musketeers | 3/5, 1.10, 5.6 | 0/5, 0.46, 8.0 | 5/5, 1.38, 5.6 | - | - / 0.0, 6.8, 13.4 | - / 0.0, 6.0, 10.9 | - / 0.0, 6.5, 12.5 | - |
| Springers (6) | close | Guardsmen | 5/5, 2.58, 3.0 | 2/5, 0.76, 6.8 | 4/5, 1.56, 4.8 | - | 7 / 0.0, 6.1, 12.8 | - / 0.0, 4.1, 7.2 | - / 0.0, 4.7, 8.6 | - |
| Springers (5) | close | Musketeers | 5/5, 3.51, 2.2 | 3/5, 1.26, 5.4 | 5/5, 2.14, 3.6 | - | - / 0.0, 4.8, 8.6 | - / 0.0, 4.2, 6.2 | - / 0.0, 6.2, 9.4 | - |
| Springers (6) | ramp | Guardsmen | 5/5, 5.52, 1.4 | 5/5, 2.58, 3.0 | - | - | - / 0.0, 8.8, - | - / 0.0, 7.6, 15.7 | - | - |
| Springers (5) | ramp | Musketeers | 5/5, 4.29, 1.8 | 5/5, 2.76, 2.8 | - | - | - / 0.0, 7.6, - | - / 0.0, 7.3, 14.8 | - | - |
| Horsemen (5) | range | Guardsmen | 5/5, 1.91, 3.4 | 0/5, 0.18, 8.0 | 5/5, 1.37, 5.0 | 3/5, 1.07, 5.2 | 9 / 0.2, 4.0, 11.9 | 8 / 0.0, 3.8, 7.2 | 8 / 0.0, 3.9, 9.4 | 9 / 0.2, 4.3, 9.2 |
| Horsemen (4) | range | Musketeers | 4/5, 1.80, 3.6 | 3/5, 1.10, 5.2 | 3/5, 1.10, 5.2 | 3/5, 0.86, 6.4 | 10 / 0.2, 4.3, 7.5 | 10 / 0.2, 3.6, 8.2 | 10 / 0.2, 3.6, 8.2 | 8 / 0.0, 3.8, 7.9 |
| Horsemen (5) | close | Guardsmen | 5/5, 2.78, 2.4 | 2/5, 0.43, 6.6 | 5/5, 2.14, 3.2 | 5/5, 2.03, 3.2 | 1 / 0.0, 2.0, 7.0 | 1 / 0.0, 1.1, 5.5 | 1 / 0.0, 1.4, 5.6 | 1 / 0.0, 1.4, 6.8 |
| Horsemen (4) | close | Musketeers | 5/5, 2.61, 2.4 | 5/5, 2.70, 2.4 | 5/5, 2.70, 2.4 | 5/5, 1.79, 3.4 | 1 / 0.0, 1.5, 8.5 | 1 / 0.0, 2.0, 7.2 | 1 / 0.0, 2.0, 7.2 | 1 / 0.0, 0.9, 7.6 |
| Horsemen (5) | ramp | Guardsmen | 5/5, 31.70, 0.2 | 5/5, 9.74, 0.6 | - | - | - / 0.0, 14.5, - | 35 / 0.6, 9.5, - | - | - |
| Horsemen (4) | ramp | Musketeers | 5/5, 2700.00, 0.0 | 5/5, 8.09, 0.8 | - | - | - / 0.0, -, - | - / 0.0, 5.4, - | - | - |

| Line | Raptors at the Toad | Health | pulled | killed | escaped | survivors' health left (lowest) | death after landing (s) |
|---|---|---|---|---|---|---|---|
| Guardsman | 0 | now (90) | 5/5 | 0 | 5 | 87 (87) | - |
| Guardsman | 0 | 55/65 (65) | 5/5 | 0 | 5 | 62 (62) | - |
| Guardsman | 0 | 60/80 (80) | 5/5 | 0 | 5 | 77 (77) | - |
| Guardsman | 3 | now (90) | 5/5 | 0 | 5 | 72 (72) | - |
| Guardsman | 3 | 55/65 (65) | 5/5 | 0 | 5 | 47 (47) | - |
| Guardsman | 3 | 60/80 (80) | 5/5 | 0 | 5 | 62 (62) | - |
| Guardsman | 6 | now (90) | 5/5 | 0 | 5 | 57 (57) | - |
| Guardsman | 6 | 55/65 (65) | 5/5 | 0 | 5 | 32 (32) | - |
| Guardsman | 6 | 60/80 (80) | 5/5 | 0 | 5 | 47 (47) | - |
| Guardsman | 9 | now (90) | 2/2 | 0 | 2 | 42 (42) | - |
| Guardsman | 9 | 55/65 (65) | 2/2 | 0 | 2 | 17 (17) | - |
| Guardsman | 9 | 60/80 (80) | 2/2 | 0 | 2 | 32 (32) | - |
| Guardsman | 12 | now (90) | 2/2 | 0 | 2 | 32 (32) | - |
| Guardsman | 12 | 55/65 (65) | 2/2 | 0 | 2 | 7 (7) | - |
| Guardsman | 12 | 60/80 (80) | 2/2 | 0 | 2 | 22 (22) | - |
| Musketeer | 0 | now (70) | 5/5 | 0 | 5 | 66 (66) | - |
| Musketeer | 0 | 55/65 (55) | 5/5 | 0 | 5 | 51 (51) | - |
| Musketeer | 0 | 60/80 (60) | 5/5 | 0 | 5 | 56 (56) | - |
| Musketeer | 3 | now (70) | 5/5 | 0 | 5 | 48 (48) | - |
| Musketeer | 3 | 55/65 (55) | 5/5 | 0 | 5 | 33 (33) | - |
| Musketeer | 3 | 60/80 (60) | 5/5 | 0 | 5 | 38 (38) | - |
| Musketeer | 6 | now (70) | 5/5 | 0 | 5 | 30 (30) | - |
| Musketeer | 6 | 55/65 (55) | 5/5 | 0 | 5 | 15 (15) | - |
| Musketeer | 6 | 60/80 (60) | 5/5 | 0 | 5 | 20 (20) | - |
| Musketeer | 9 | now (70) | 2/2 | 0 | 2 | 12 (12) | - |
| Musketeer | 9 | 55/65 (55) | 2/2 | 2 | 0 | - (-) | 0.8 |
| Musketeer | 9 | 60/80 (60) | 2/2 | 0 | 2 | 2 (2) | - |
| Musketeer | 12 | now (70) | 2/2 | 2 | 0 | - (-) | 1.3 |
| Musketeer | 12 | 55/65 (55) | 2/2 | 2 | 0 | - (-) | 1.0 |
| Musketeer | 12 | 60/80 (60) | 2/2 | 2 | 0 | - (-) | 1.1 |

The last table is the Toad's TONGUE (group T): the Toad 200 px in front of the line with full energy and 0-12 Raptors at its feet; the rest of the line holds its fire (busy elsewhere); when the man lands the Raptors go for him and 0.5 s after he can move he is ordered back. The runs are deterministic (each seed gave the same result), so 9 and 12 Raptors ran 2 seeds.

## 2 and 3. The yardsticks and computer against computer

tools/study_musket_hp_rush.gd (tools/test_ai_wall_vs_rush.gd with the override: the walled Hard Crown against the scripted Brood Extreme rush, to 5:00) and tools/study_musket_hp_match.gd (Hard v Hard; runner tools/study_musket_hp_games.sh, table tools/study/musket_hp_games.py). "clockwork rush" is the Clockwork computer on its Rush plan to 7:00 (its early pushes). The others are Balanced v Balanced to 10:00 (cut from 15 to fit the time). Army value at face value (a Brood egg's share; the Brood's Mother, Rootmaws, Turtles and Sires not counted). One game each: these games swing a lot on one battle, so read them as "nothing broke" or "something broke", not as a rate.

| Game | Health | Crown army 3/5/7/10 min | Foe army 3/5/7/10 min | Crown lost | Foe lost | Musk+Guards at 10 | Winner |
|---|---|---|---|---|---|---|---|
| brood, ashford_crossing s1 | now | 280 / 490 / 627 / 1250 | 0 / 250 / 75 / 270 | 325 | 1125 | 10+0 | none (time) (600 s) |
| brood, ashford_crossing s1 | 55/65 | 280 / 490 / 878 / 1400 | 0 / 200 / 600 / 1020 | 530 | 525 | 15+0 | none (time) (600 s) |
| brood, greenhold s1 | now | 210 / 420 / 974 / 771 | 0 / 300 / 420 / 1015 | 942 | 1145 | 6+0 | none (time) (600 s) |
| brood, greenhold s1 | 55/65 | 210 / 490 / 833 / 2015 | 0 / 300 / 420 / 1525 | 140 | 570 | 20+0 | none (time) (600 s) |
| brood, greenhold s2 | now | 280 / 675 / 1000 / 1708 | 0 / 225 / 225 / 1620 | 70 | 725 | 13+0 | none (time) (600 s) |
| brood, greenhold s2 | 55/65 | 280 / 490 / 822 / 1244 | 0 / 200 / 325 / 1140 | 649 | 1370 | 9+0 | none (time) (600 s) |
| clockwork, ashford_crossing s1 | now | 210 / 436 / 838 / 2755 | 490 / 1015 / 1570 / 3590 | 81 | 1780 | 0+20 | none (time) (600 s) |
| clockwork, ashford_crossing s1 | 55/65 | 210 / 436 / 1006 / 1091 | 490 / 840 / 1620 / 4465 | 1515 | 880 | 0+2 | none (time) (600 s) |
| clockwork, greenhold s1 | now | 210 / 560 / 1099 / 2440 | 560 / 980 / 1630 / 2875 | 200 | 2040 | 21+0 | none (time) (600 s) |
| clockwork, greenhold s1 | 55/65 | 210 / 490 / 812 / 2704 | 560 / 980 / 2040 / 4090 | 212 | 755 | 0+19 | none (time) (600 s) |
| clockwork rush, ashford_crossing s3 | now | 210 / 490 / 1143 / - | 630 / 1190 / 1845 / - | 0 | 420 | 11+0 | none (time) (420 s) |
| clockwork rush, ashford_crossing s3 | 55/65 | 210 / 490 / 793 / - | 630 / 1050 / 1685 / - | 0 | 560 | 9+0 | none (time) (420 s) |
| clockwork rush, greenhold s3 | now | 210 / 675 / 1088 / - | 560 / 630 / 1280 / - | 0 | 490 | 11+0 | none (time) (420 s) |
| clockwork rush, greenhold s3 | 55/65 | 210 / 420 / 1101 / - | 560 / 630 / 1280 / - | 70 | 490 | 11+0 | none (time) (420 s) |
| clockwork rush, hollowfen s3 | now | 280 / 490 / 917 / - | 560 / 1190 / 1475 / - | 0 | 490 | 12+0 | none (time) (420 s) |
| clockwork rush, hollowfen s3 | 55/65 | 280 / 490 / 1077 / - | 560 / 910 / 1615 / - | 0 | 0 | 11+0 | none (time) (420 s) |

| Map, seed | Health | Musketeers made / lost | Labourers lost | Brood fighters made / killed | at 2:30: Musk alive, Brood alive, wall damage | Crown buildings lost |
|---|---|---|---|---|---|---|
| ashford_crossing 7 | now | 7 / 0 | 1 | 44 / 26 | 2, 9, 447 | 0 |
| ashford_crossing 7 | 55/65 | 7 / 1 | 1 | 52 / 32 | 2, 6, 402 | 0 |
| ashford_crossing 4242 | now | 6 / 0 | 1 | 32 / 26 | 2, 8, 417 | 0 |
| ashford_crossing 4242 | 55/65 | 7 / 0 | 1 | 30 / 26 | 2, 9, 409 | 0 |
| greenhold 7 | now | 7 / 1 | 1 | 42 / 29 | 2, 8, 549 | 0 |
| greenhold 7 | 55/65 | 8 / 1 | 1 | 42 / 31 | 2, 8, 523 | 0 |
| greenhold 4242 | now | 7 / 0 | 1 | 36 / 26 | 2, 6, 517 | 0 |
| greenhold 4242 | 55/65 | 6 / 1 | 1 | 40 / 28 | 2, 11, 633 | 0 |

- Every rush run passed all the test's checks at 55 as at 70 (wall by 43 s, 3 Musketeers by 2:40, at most 2 units lost).
- Against the Clockwork's Rush plan nothing broke by 7:00 at 55 (0 or 70 lost).
- Brood games (3): mixed, no direction (Greenhold seed 1 better for the Crown at 55, seed 2 worse, Ashford about even): noise. Clockwork: Ashford Crossing broke (the Guardsman army wiped, see above); Greenhold had no big battle by 10:00.

## What was not tested (cut short)

- The 15-minute games, Hollowfen in the Balanced games, more than one seed per game (Greenhold seed 2 against the Clockwork was stopped half way), and the computer's Crown on Rush.
- 60/80 and 65/85 on the ramp, against Tyrant Challengers / Brutes / Spitters with 65/85, and fights larger than 8 men or with a cannon (docs/toad_hp_study.md has those at 60 and 50 with the old Brood).
- The Dragoon (90, a Musketeer on a horse) was left as he is; a real change would decide whether he follows.
- Fights with 5 seeds each move by a win or two between runs (e.g. 65/85 Guardsmen v Raptors at range 4 of 5 against 2 of 5 at 90): trust the direction of big gaps only.

## The tools

- tools/musket_hp.gd: the test-only override (MH.apply(game, base, armour_bonus)).
- tools/study_musket_hp.gd + .sh: the small fights and the TONGUE (hpv:55/65,60/80 for several variants).
- tools/study_musket_hp_match.gd, tools/study_musket_hp_rush.gd, tools/study_musket_hp_games.sh: the games.
- tools/study/musket_hp_table.py, tools/study/musket_hp_games.py: the tables above.
