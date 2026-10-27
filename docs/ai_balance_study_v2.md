# Holdfast balance study v2: the new economy, with build orders

Written by tools/study/report_v2.py on 2026-10-27 from 280 games on 4 machines (m1, m2, m3, m4), game version 0.14.49. Measurement only: nothing in the game was changed. How it was run: docs/study_v2.md.

**Cut at 11:00 on 2026-10-27, on the owner's word ("we can extrapolate from that").** By then machine 1 (Crown v Brood)
and machine 4 (the experiments) had finished their 100 games; machine 3 (Brood v Clockwork) had handed in 60 and machine 2
(Crown v Clockwork) 20, so the Crown v Clockwork numbers have a wide range. The games were played on 0.14.49: before the Clock
Soldier became quicker and lighter with its SHIELD FORWARD research (0.14.53); everything merged after that is art, sound,
music or online play, except the fair-start fix of 0.14.64.

Two flaws of the study's build-order runner (tools/study/bo_ai_v2.gd), to fix before the next study: a Tension user it
places (the Escapement, the Clock Aviary) goes anywhere with room, not where its gear ring meshes with a Mainspring, so the
Clockwork's "Fast Jacks" opening got no Tension and made no Jacks in 5 of its 12 games; and an "attack@N" step never times
out, so a script waiting for an army it cannot make sits idle to its 12-minute limit. Those games are listed as stalled below
and left out of the second table and of the experiments' scores.

In every match-up game each side opened with one of its faction's documented build orders (tools/study/build_orders.json), drawn so each opening got an equal share, and then the Hard computer played on. Games run to 30 minutes at most; a side the computer's own rule calls hopeless gives up (the cause is "gg"); at the 30-minute cap the side with 1.25 times the other's power counts as the winner ("timeout lead"), otherwise the game is even. A win rate counts an even game as half a win. The numbers in brackets are the 95% confidence range: with 100 games a true 50% can come out anywhere from about 40% to 60%.

## Who wins each match-up

| match-up | games | wins | losses | even | win rate (95% range) |
|---|---|---|---|---|---|
| Crown against Brood | 100 | 93 | 7 | 0 | 93% (86% to 97%) |
| Crown against Clockwork | 20 | 17 | 3 | 0 | 85% (64% to 95%) |
| Brood against Clockwork | 60 | 20 | 40 | 0 | 33% (23% to 46%) |

In short: the Crown beats the Brood (93% of the games); the Crown beats the Clockwork (85% of the games); the Clockwork beats the Brood (67% of the games).

**Stalled scripts.** In 6 games a side's script stalled: it waited on a step it could not do, so at 5, 7 or 10 minutes it had more than 1200 unspent and no army at all, and the computer took over only at the script's 12-minute limit. Those games measure the script, not the faction. By opening: cw_jack_rush 5 (waiting at attack@10); cw_owl_harass 1 (waiting at attack@12).

Without those games:

| match-up | games | wins | losses | even | win rate (95% range) |
|---|---|---|---|---|---|
| Crown against Brood | 100 | 93 | 7 | 0 | 93% (86% to 97%) |
| Crown against Clockwork | 19 | 16 | 3 | 0 | 84% (62% to 94%) |
| Brood against Clockwork | 55 | 15 | 40 | 0 | 27% (17% to 40%) |

### By map

Each map has only about eight games per match-up, so these are hints, not findings.

| map | Crown v Brood (W-L-even) | Crown v Clockwork (W-L-even) | Brood v Clockwork (W-L-even) |
|---|---|---|---|
| Amberfall Vale | 9-0-0 | 2-0-0 | 1-4-0 |
| Ashford Crossing | 9-0-0 | 2-0-0 | 2-3-0 |
| Cinder Steps | 8-0-0 | 0-1-0 | 1-4-0 |
| Frostmere | 9-0-0 | 1-1-0 | 1-4-0 |
| Glimmerdeep | 7-1-0 | 2-0-0 | 1-4-0 |
| Greenhold | 7-2-0 | 2-0-0 | 3-2-0 |
| Highmoor | 7-1-0 | 1-0-0 | 2-3-0 |
| Hollowfen | 8-0-0 | 1-1-0 | 1-4-0 |
| Kestrel Rise | 8-0-0 | 2-0-0 | 2-3-0 |
| Saltmarsh Isles | 6-2-0 | 1-0-0 | 3-2-0 |
| Thornwood Maze | 8-0-0 | 2-0-0 | 1-4-0 |
| Twin Fords | 7-1-0 | 1-0-0 | 2-3-0 |

## How each opening did

Each documented opening against everything it met (both other factions together), then against each faction. With about 100 games a faction split over its openings, each opening has some 15 to 30 games, so only large differences are real.

### The Crown

| opening | games | win rate (95% range) | v Brood (W-L-even) | v Clockwork (W-L-even) | median length |
|---|---|---|---|---|---|
| Crown 3: Musketeers and a Balloon drop (crown_balloon_drop) | 16 | 100% (81% to 100%) | 13-0-0 | 3-0-0 | 7:29 |
| Crown 2: Horseman rush (crown_horse_rush) | 16 | 100% (81% to 100%) | 13-0-0 | 3-0-0 | 6:02 |
| Crown 3b: Balloon raid (the Musketeers fire from the basket) (crown_balloon_raid) | 15 | 93% (70% to 99%) | 13-0-0 | 1-1-0 | 13:07 |
| Crown 6: Cannon and Musketeer push (the standard, then a timing attack) (crown_cannon_push) | 15 | 87% (62% to 96%) | 12-1-0 | 1-1-0 | 9:18 |
| Crown 1: Musketeer wall into the Cannon (the standard) (crown_musket_wall) | 15 | 87% (62% to 96%) | 11-1-0 | 2-1-0 | 15:02 |
| Crown 7: Proxy Horseman rush (crown_proxy_horse) | 15 | 87% (62% to 96%) | 10-2-0 | 3-0-0 | 8:02 |
| Crown 5: Dragoon raid (the wall and the Mill, then a Breeder and Dragoons) (crown_dragoon_raid) | 14 | 79% (52% to 92%) | 9-3-0 | 2-0-0 | 8:35 |
| Crown 4: Wall and a second Town Hall (crown_fast_expand) | 14 | 100% (78% to 100%) | 12-0-0 | 2-0-0 | 10:58 |

### The Brood

| opening | games | win rate (95% range) | v Crown (W-L-even) | v Clockwork (W-L-even) | median length |
|---|---|---|---|---|---|
| Brood 6: Roost (Bloaters and Skywings) (brood_air) | 24 | 12% (4% to 31%) | 1-14-0 | 2-7-0 | 13:05 |
| Brood 5: Brute timing (Gorge Pit) (brood_brute_timing) | 23 | 17% (7% to 37%) | 0-14-0 | 4-5-0 | 11:28 |
| Brood 2: Pool first, one wave, then economy (brood_pool_eco) | 23 | 9% (2% to 27%) | 0-15-0 | 2-6-0 | 10:57 |
| Brood 7: Forward Burrow (Raptors at their door) (brood_proxy_burrow) | 23 | 4% (1% to 21%) | 0-14-0 | 1-8-0 | 10:41 |
| Brood 4: Spitter timing (brood_spitter_timing) | 23 | 35% (19% to 55%) | 1-13-0 | 7-2-0 | 11:01 |
| Brood 3: Economy (grubs first, two pits, Warren, then a big Raptor wave) (brood_economy) | 22 | 23% (10% to 43%) | 1-13-0 | 4-4-0 | 11:45 |
| Brood 1: Six-pool (extreme rush) (brood_xrush) | 22 | 18% (7% to 39%) | 4-10-0 | 0-8-0 | 11:04 |

### The Clockwork

| opening | games | win rate (95% range) | v Crown (W-L-even) | v Brood (W-L-even) | median length |
|---|---|---|---|---|---|
| Clockwork 5: Fast Jacks (Escapement first) (cw_jack_rush) | 12 | 8% (1% to 35%) | 0-3-0 | 1-8-0 | 11:26 |
| Clockwork 2: Jacks (Mainspring and Escapement), the standard (cw_jack_tech) | 12 | 58% (32% to 81%) | 0-3-0 | 7-2-0 | 12:42 |
| Clockwork 6: Pendulum and Netter push (tier 3) (cw_pendulum_push) | 12 | 75% (47% to 91%) | 0-3-0 | 9-0-0 | 15:21 |
| Clockwork 3: Turret and a second Clocktower (cw_turret_expand) | 12 | 75% (47% to 91%) | 1-2-0 | 8-1-0 | 11:00 |
| Clockwork 7: Forward Clocktower (Clock Soldiers at their door) (cw_proxy_tower) | 11 | 18% (5% to 48%) | 0-3-0 | 2-6-0 | 10:58 |
| Clockwork 1: Clock Soldier rush (two Works) (cw_soldier_rush) | 11 | 64% (35% to 85%) | 0-3-0 | 7-1-0 | 15:13 |
| Clockwork 4: Swifts into Ticking Owls (cw_owl_harass) | 10 | 80% (49% to 94%) | 2-0-0 | 6-2-0 | 15:33 |

### Opening against opening

Only pairs with at least 5 games are shown; the win rate is the first opening's.

| opening | against | games | W-L-even | win rate (95% range) |
|---|---|---|---|---|
| crown_cannon_push | brood_air | 5 | 5-0-0 | 100% (57% to 100%) |
| brood_proxy_burrow | cw_turret_expand | 5 | 0-5-0 | 0% (0% to 43%) |

### Did the scripts run as written

| opening | games | script finished | steps timed out (all games) | stalled (idle, full bank) | median hand-over |
|---|---|---|---|---|---|
| brood_air | 24 | 17 of 24 | 9 | 0 | 5:39 |
| brood_brute_timing | 23 | 11 of 23 | 12 | 0 | 6:51 |
| brood_economy | 22 | 16 of 22 | 1 | 0 | 6:08 |
| brood_pool_eco | 23 | 20 of 23 | 0 | 0 | 4:07 |
| brood_proxy_burrow | 23 | 11 of 23 | 11 | 0 | 5:30 |
| brood_spitter_timing | 23 | 16 of 23 | 8 | 0 | 5:55 |
| brood_xrush | 22 | 22 of 22 | 0 | 0 | 5:00 |
| crown_balloon_drop | 16 | 11 of 16 | 0 | 0 | 7:00 |
| crown_balloon_raid | 15 | 14 of 15 | 0 | 0 | 7:00 |
| crown_cannon_push | 15 | 15 of 15 | 0 | 0 | 5:44 |
| crown_dragoon_raid | 14 | 12 of 14 | 2 | 0 | 6:00 |
| crown_fast_expand | 14 | 13 of 14 | 1 | 0 | 6:00 |
| crown_horse_rush | 16 | 14 of 16 | 0 | 0 | 5:30 |
| crown_musket_wall | 15 | 15 of 15 | 0 | 0 | 6:00 |
| crown_proxy_horse | 15 | 12 of 15 | 3 | 0 | 5:30 |
| cw_jack_rush | 12 | 6 of 12 | 0 | 5 | 4:22 |
| cw_jack_tech | 12 | 12 of 12 | 0 | 0 | 4:24 |
| cw_owl_harass | 10 | 8 of 10 | 2 | 1 | 5:57 |
| cw_pendulum_push | 12 | 6 of 12 | 4 | 0 | 6:25 |
| cw_proxy_tower | 11 | 11 of 11 | 0 | 0 | 4:00 |
| cw_soldier_rush | 11 | 11 of 11 | 0 | 0 | 2:42 |
| cw_turret_expand | 12 | 12 of 12 | 0 | 0 | 2:52 |

## The economy by faction

Medians over every side still playing at that minute (games that ended earlier drop out, so later rows lean on the closer games). Income is the main resource (gold, biomass or cogs) earned in the minute before; the bank is what is unspent; the army is its value. The earlier study (docs/study_data, version 0.14.1, plain Hard computers, mirrors left out here) is in brackets. Careful with the Clockwork's brackets: that study played the old ore-and-energy Clockwork, which has since been rebuilt twice (gear mode, then the Tension economy of 0.14.38), and its Brood had neither the essence nor the pit ground rules of 0.14.40 to 0.14.42.

### The Crown

| minute | sides | income a minute | second resource a minute | bank | workers | army value |
|---|---|---|---|---|---|---|
| 5:00 | 120 | 760 (760) | 59 (22) | 175 (20) | 12 (12) | 515 (535) |
| 10:00 | 62 | 1,140 (1,140) | 64 (119) | 15 (14) | 27 (26) | 1,478 (1,142) |
| 15:00 | 22 | 1,140 (760) | 237 (222) | 26 (14) | 38 (39) | 2,000 (1,520) |
| 20:00 | 9 | 1,140 (0) | 119 (0) | 7 (13) | 31 (38) | 1,820 (865) |

### The Brood

| minute | sides | income a minute | second resource a minute | bank | workers | army value |
|---|---|---|---|---|---|---|
| 5:00 | 160 | 342 (341) | 0 (0) | 42 (32) | 12 (12) | 150 (75) |
| 10:00 | 96 | 456 (992) | 6 (9) | 42 (203) | 18 (34) | 150 (300) |
| 15:00 | 35 | 455 (42) | 0 (30) | 22 (28) | 17 (10) | 75 (0) |
| 20:00 | 7 | 870 (0) | 15 (68) | 70 (32) | 32 (5) | 1,085 (0) |

### The Clockwork

| minute | sides | income a minute | second resource a minute | bank | workers | army value |
|---|---|---|---|---|---|---|
| 5:00 | 80 | 788 (1,175) | 0 (0) | 344 (62) | 13 (18) | 630 (1,440) |
| 10:00 | 64 | 1,234 (1,978) | 0 (0) | 246 (120) | 28 (32) | 1,432 (3,835) |
| 15:00 | 33 | 1,158 (448) | 0 (0) | 111 (70) | 31 (32) | 2,240 (3,550) |
| 20:00 | 10 | 1,231 (407) | 0 (0) | 127 (74) | 32 (32) | 2,040 (2,525) |

## How long the games lasted and how they ended

| match-up | games | quarter of games over by | median | three quarters by | destroyed | gave up (gg) | 30:00 with a lead | 30:00 even |
|---|---|---|---|---|---|---|---|---|
| Crown v Brood | 100 | 7:23 | 9:31 | 13:13 | 90 | 10 | 0 | 0 |
| Crown v Clockwork | 20 | 10:33 | 15:14 | 22:05 | 11 | 8 | 1 | 0 |
| Brood v Clockwork | 60 | 10:44 | 13:17 | 16:09 | 43 | 16 | 1 | 0 |

| faction | wins | won before 10:00 | by destroying | by gg | by a lead at 30:00 |
|---|---|---|---|---|---|
| Crown | 110 | 54 | 96 | 13 | 1 |
| Brood | 27 | 9 | 17 | 10 | 0 |
| Clockwork | 43 | 6 | 31 | 11 | 1 |

## The exploratory games: looking for outlier openings

100 games tried 74 candidate openings (21 Crown, 30 Brood, 23 Clockwork). Each candidate played an opening of another faction (its standard, another documented one, or the plain computer) on a random map. A candidate's score is 1 for a win, 0 for a loss, 0.75 or 0.25 for a lead at 30:00, 0.5 for even; its fitness is (score + 0.5) / (games + 1), so a candidate needs more than one game to rise far. Winners were mutated more often, and the best were played again to confirm them.

16 games are left out of the scores below: a side's script stalled (it asked for something it could not make, such as Cannons with no Powder Mill, or an attack waiting for an army that never came, and sat idle until the script's 12-minute limit), so the game says nothing about the opening. x_008 (hollowfen: the candidate x_cw_008 stalled at attack@6|240, 1536 unspent at 5:00); x_011 (amberfall vale: the candidate x_cw_011 stalled at attack@6|240, 2736 unspent at 5:00); x_030 (hollowfen: the candidate x_cr_030 stalled at attack@6|240, 2010 unspent at 5:00); x_042 (saltmarsh isles: the candidate x_cr_042 stalled at attack@4|420, 1930 unspent at 5:00); x_048 (hollowfen: the candidate x_cr_048 stalled at attack@24|420, 2440 unspent at 7:00); x_054 (highmoor: the candidate x_cr_054 stalled at attack@18|420, 1650 unspent at 5:00); x_062 (cinder steps: the candidate x_cw_053 stalled at ?, 1277 unspent at 7:00); x_065 (ashford crossing: the candidate x_cw_065 stalled at attack@6|240, 2322 unspent at 5:00); x_069 (kestrel rise: the candidate x_cr_069 stalled at attack@8|480, 1760 unspent at 5:00); x_071 (twin fords: the candidate x_cw_071 stalled at ?, 1570 unspent at 5:00); x_084 (saltmarsh isles: the candidate x_cr_084 stalled at ?, 1230 unspent at 5:00); x_087 (hollowfen: the candidate x_cr_087 stalled at ?, 1610 unspent at 5:00); x_090 (amberfall vale: the candidate x_cr_090 stalled at attack@10|480, 1230 unspent at 5:00); x_092 (greenhold: the candidate x_cw_092 stalled at ?, 2002 unspent at 10:00); x_095 (frostmere: the candidate x_cw_095 stalled at attack@10|300, 1347 unspent at 5:00); x_099 (greenhold: the candidate x_cr_099 stalled at attack@4|150, 1640 unspent at 7:00).

### The Crown's best candidates

| candidate | games | wins | fitness | grown from | met |
|---|---|---|---|---|---|
| x_cr_081 | 2 | 2 | 0.83 | crown_fast_expand | brood ai, brood brood_pool_eco |
| x_cr_003 | 4 | 3 | 0.75 | crown_balloon_drop | brood ai, clockwork ai, clockwork cw_jack_tech |
| x_cr_000 | 1 | 1 | 0.75 | crown_fast_expand | brood brood_economy |
| x_cr_006 | 1 | 1 | 0.75 | crown_cannon_push | brood ai |
| x_cr_012 | 1 | 1 | 0.75 | crown_cannon_push | brood ai |
| x_cr_021 | 1 | 1 | 0.75 | crown_fast_expand | brood brood_air |
| x_cr_033 | 1 | 1 | 0.75 | crown_balloon_drop | clockwork cw_soldier_rush |
| x_cr_036 | 1 | 1 | 0.75 | crown_fast_expand | brood brood_spitter_timing |

### The Brood's best candidates

| candidate | games | wins | fitness | grown from | met |
|---|---|---|---|---|---|
| x_br_031 | 4 | 2 | 0.50 | brood_economy | clockwork ai, clockwork cw_jack_rush, clockwork cw_proxy_tower, crown ai |
| x_br_001 | 1 | 0 | 0.25 | brood_brute_timing | clockwork ai |
| x_br_004 | 1 | 0 | 0.25 | brood_spitter_timing | clockwork cw_turret_expand |
| x_br_007 | 1 | 0 | 0.25 | brood_air | crown ai |
| x_br_010 | 1 | 0 | 0.25 | grammar | clockwork cw_jack_tech |
| x_br_013 | 1 | 0 | 0.25 | brood_brute_timing | crown crown_musket_wall |
| x_br_016 | 1 | 0 | 0.25 | brood_proxy_burrow | crown ai |
| x_br_019 | 1 | 0 | 0.25 | brood_brute_timing | clockwork ai |

### The Clockwork's best candidates

| candidate | games | wins | fitness | grown from | met |
|---|---|---|---|---|---|
| x_cw_035 | 2 | 2 | 0.75 | grammar | brood ai, brood brood_spitter_timing |
| x_cw_002 | 1 | 1 | 0.75 | cw_proxy_tower | brood ai |
| x_cw_032 | 1 | 1 | 0.75 | cw_jack_tech | brood brood_xrush |
| x_cw_053 | 1 | 1 | 0.75 | cw_proxy_tower | brood brood_proxy_burrow |
| x_cw_056 | 1 | 1 | 0.75 | grammar | brood brood_proxy_burrow |
| x_cw_083 | 1 | 1 | 0.75 | grammar | brood brood_economy |
| x_cw_089 | 1 | 1 | 0.75 | cw_owl_harass | brood ai |
| x_cw_014 | 3 | 2 | 0.62 | grammar | brood brood_economy, crown ai |

### The outliers in detail

**x_cr_081** (Crown, fitness 0.83 over 2 games; grown from crown_fast_expand, by add attack@10|240, add cannon*1, early tech: mortar at step 2).

The script: `workers:10, wall, barracks, foundry, mortar*1, town_hall, powder_mill, mill:3, musketeer*, attack@10|240, workers:20, farm, farm, workers:26, wait:360, cannon*1, end`, then the computer plays on with the economy plan.

| game | map | against | result | its army 5:00 | theirs 5:00 | first scripted attack | scripted attacks killed | own workers lost | script ended |
|---|---|---|---|---|---|---|---|---|---|
| x_081 | amberfall vale | brood brood_pool_eco | win (victory, 16:34) | 0 | 150 | 5:27 | 0 | 11 | 10:08 |
| x_096 | cinder steps | brood ai | win (victory, 16:05) | 0 | 150 | 5:25 | 0 | 8 | 9:00 |

Why it may work: it has less army at 5:00 than the documented Crown openings (0 against their median of 515); its scripted attack goes out at 5:26; its wins come at a median of 16:19; it trains up to 26 workers in the script. With so few games each, treat it as a lead to test, not a result.

**x_cr_003** (Crown, fitness 0.75 over 4 games; grown from crown_balloon_drop, by add attack@10|240).

The script: `workers:9, wall, barracks, powder_mill, mill:4, foundry, musketeer*4, workers:12, balloon*1, drop, musketeer*, attack@10|240, farm, wait:420, end`, then the computer plays on with the balanced plan.

| game | map | against | result | its army 5:00 | theirs 5:00 | first scripted attack | scripted attacks killed | own workers lost | script ended |
|---|---|---|---|---|---|---|---|---|---|
| x_003 | frostmere | brood ai | win (victory, 6:27) | 605 | 0 | 4:00 | 0 | 0 | - |
| x_027 | twin fords | clockwork ai | win (victory, 20:58) | 485 | 1,400 | 4:00 | 170 | 9 | 7:00 |
| x_057 | hollowfen | clockwork cw_jack_tech | win (victory, 17:56) | 365 | 970 | 4:00 | 0 | 1 | 7:00 |
| x_072 | hollowfen | clockwork ai | behind at the time cap (timeout_lead, 30:00) | 365 | 1,120 | 4:00 | 520 | 29 | 7:00 |

Why it may work: it has about as much army at 5:00 as the documented Crown openings (425 against their median of 515); its scripted attack goes out at 4:00 and kills 85 worth on the way; its wins come at a median of 17:56; it trains up to 12 workers in the script. With so few games each, treat it as a lead to test, not a result.

**x_cw_035** (Clockwork, fitness 0.75 over 2 games; grown from grammar).

The script: `workers:8, movement_works, escapement, mainspring, crew:mainspring:3, netter*, cog_press, workers:17, attack@6|360, end`, then the computer plays on with the economy plan.

| game | map | against | result | its army 5:00 | theirs 5:00 | first scripted attack | scripted attacks killed | own workers lost | script ended |
|---|---|---|---|---|---|---|---|---|---|
| x_035 | frostmere | brood brood_spitter_timing | win (victory, 17:42) | 420 | 420 | 3:45 | 0 | 5 | 3:45 |
| x_068 | amberfall vale | brood ai | ahead at the time cap (timeout_lead, 30:00) | 475 | 225 | 3:51 | 0 | 1 | 3:51 |

Why it may work: it has less army at 5:00 than the documented Clockwork openings (448 against their median of 630); its scripted attack goes out at 3:48; its wins come at a median of 17:42; it trains up to 17 workers in the script. With so few games each, treat it as a lead to test, not a result.

### What kind of change paid

The mean game score of candidates by the last change made to them (1 is always winning, 0.5 even).

| change | games | mean score |
|---|---|---|
| fresh build | 22 | 0.34 |
| step added | 16 | 0.38 |
| early tech | 15 | 0.27 |
| worker count | 14 | 0.36 |
| attack added | 10 | 0.55 |
| unit mix | 10 | 0.20 |
| steps swapped | 10 | 0.42 |
| plan after the script | 9 | 0.11 |
| attack timing | 7 | 0.29 |
| step dropped | 6 | 0.17 |
| fast expansion | 5 | 0.20 |
| proxy | 3 | 0.33 |
| attack dropped | 2 | 0.50 |
| no wall | 2 | 0.50 |

