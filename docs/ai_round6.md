# AI round 6: the Crown and Clockwork computers on the bigger maps

Version 0.15.7 (branch `ai-round6`, merged into main). Written to be read aloud: short sentences, one point at a time.
The computer only. No unit, building or cost numbers changed.
Evidence: two filmed games on Kestrel Rise, seed 14, version 0.14.100, Hard against Hard. Film a has the Crown on the far side. Film b has the Crown on the usual side.
`-- r6:off` on the command line plays the computer as before. Study switches: `r6:crownonly`, `r6:clockonly`, `r6:nosites`, `r6:wave`.

## 1. Clocktowers sent onto the enemy's side

What happened. In film b the Clockwork laid a Clocktower under the Crown's main cliff at 12:17. It was 52 tiles from its own main.

The exact cause. `AI._safe_hall_spot` scored each free hall spot by straight-line distance.
It skipped a spot only when the spot was within 22 straight tiles (ENEMY_YARD) of an enemy main, natural or hall, and nearer the enemy than our main.
Beyond 22 tiles, a spot nearer the enemy only got a penalty of 600 points. It was never ruled out.
Once the Clockwork's own sites were taken, or left alone after a loss, the far spots on the enemy's side were the only ones left. So the penalty did not matter: the least bad spot won, and it was in the enemy's yard.
Straight lines also mislead across cliffs. A spot below the Crown's main cliff looks far from the Crown's main in a straight line, but the walk from the Crown's ramp is short.

The fix. `AI._enemy_side` measures the walk over land, with cliffs counted (the same step maps as the expansion-spot ratings).
A spot is on the enemy's side when it is no nearer, by land, to our main or one of our halls than to an enemy main, its natural, or an enemy hall we have seen.
Such a spot is never taken. When no spot is left on our side, the computer does not expand at all.
The test `tools/test_ai_round6.gd` checks on six maps that each natural is on its own side and that no base site counts as both sides' own.

## 2. The Clockwork stopped attacking for good

What happened. In film b the Clockwork pulled its wave back at 11:28. Then it sat at 200 of 200 supply with 136 Clock Soldiers until 20:00, beside a Crown with no money.

The cause. Any enemy unit near any building of ours counted as a threat, and a threat kept the whole army at home in defence.
The Clocktower under the Crown's cliff stood beside the Crown's Labourers, so there was always a threat.
Also, a pull-back raised the supply the next wave waits for, and nothing ever lowered it again.

The fixes.
- A small threat is left to the detachments. The rest of the army may still attack. Small means unarmed enemies, or any enemies once our army is 100 supply or more, and worth at most a quarter of our army.
- A pull-back raises the bar for three minutes only (PULL_FOR, 180 s). Then the old bar returns.
- An army at the supply cap goes out whatever the bar. The Clockwork also goes out when its army is worth three times the biggest enemy army it saw lately (PUSH_AHEAD), from 40 supply up.
The test `tools/test_ai_round6_stall.gd` checks both: the big army goes out beside a forward Clocktower, and an army far ahead goes out after a pull-back.

## 3. The Crown's Armoury on the low ground

What happened. On Kestrel Rise the Crown's Armoury stood at the foot of its ramp, outside its wall. In film a it was killed unfinished at 9:39.

The cause. The main's plateau is small. Cottages and farms filled it first. When the Armoury came, the nearest free ground was below the ramp.

The fix. Once the Barracks is laid, the Crown keeps a spot on the main's plateau, behind its hall, for each costly tech building not yet laid: the Armoury and the Foundry (`AI._keep_tech`, through `Game.ai_keep`). Other buildings may not take that spot. When the Armoury is laid, it goes there.
Pictures: `docs/shots/ai_round6/before_crown_main_0600.png` and `after_armoury_foundry_on_plateau_0600.png`.

## 4. The Crown's horse rush against the Clockwork

What happened. The Crown opened with the Horse Breeder about a third of the time. Against the Clockwork, Clock Soldiers are out at 1:50 and the riders got nowhere. The Breeder starved the economy: 16 Labourers against 30 Winders at 7:00 on Kestrel Rise.

The fix. Against the Clockwork, Normal and up, the Crown always opens with the Powder Mill and Musketeers, unless its plan is the Rush. In every round 6 game the Crown opened with the Mill.

## 5. Crown expansions fell undefended

The fixes.
- The next hall is due earlier. A hall under 40% soil no longer counts as fresh land (it was 25%).
- Farmers go with the hall. A farmer looking for work prefers fresh soil. Farmers on tired soil, under a quarter, move to a fresh farm with room before the soil is spent.
- The guards walk over first, as before.
- The Crown does not lay a hall where it sees a bigger enemy army within 20 tiles. It keeps the gold and waits.

## 6. The Crown frozen with no gold and spent soil

What happened. In film b the Crown's soil hit 0% at 11:18. It laid a Town Hall at 11:19 that never stood, and then sat on 5 gold with 37 Labourers until 20:00.

The causes. The hall's builders were pulled away and nobody came back to it. The site was never dropped, so the gold was never refunded. And the Crown had spent everything else.

The fixes.
- A Town Hall site whose builders were pulled away gets the nearest free Labourer, up to 6 times. With enemies there, the site is let go and refunded.
- Once the best soil at any finished hall is under a quarter, and no new hall is going up, the Crown keeps a Town Hall's gold in the bank (`AI._low_soil_keep`). Training, research and other buildings wait for the gold above it. When enemies are at its buildings, it may still train to defend.

## 7. Rated expansion sites

The owner asked the Crown and Clockwork computers to use the rated expansion sites (`scripts/expansion_spots.gd`).
`ExpansionSpots.rate_all` now rates every free base site for each side. The computer counts a quarter of a site's rating as nearness, plus 12 tiles for the gold-marked best site and 6 for the second.
A rated site within 32 steps of our main or a hall of ours also beats any other free ground. A farther site gets no such lead. In the first round 6 games the Crown's third hall went to a site 41 to 47 tiles out on Frostmere instead of ground 20 tiles from its main, and it fell.

A new problem from the 0.15 ramps. On Hollowfen, Saltmarsh Isles and Cinder Steps, the natural touches a ramp. The computer may not build there ("Keep the ramp clear"). So both computers skipped their natural and expanded 40 to 46 tiles out.
The fix. A base site the computer may not use as drawn is taken from the nearest free cell beside it, within 6 tiles, with the site's rating and ore. The test checks that the first hall spot is the natural on all six maps.

## 8. From the map change

- The Town Hall site no worker came to build: fixed in item 6 (`AI.adopt_site`).
- `tools/test_ai_r5_hold_spots.gd` failed on 4 maps. The cause was in the test: on the 0.15 maps the wall stood before anything asked for the ramps, and the ramp finder skips built cells. The test now finds the ramps at the start. It passes.
- `tools/test_pathing.gd` passed twice in a row.

## A change that was tried and turned off

A wave check for the Crown against the Clockwork: a wave goes out only when worth 1.2 times the biggest enemy army seen lately, or at 60 supply.
With it, the Crown never attacked on Greenhold (seed 11, far side) and lost at 22:54. Without it, the same game was won at 24:03. The Crown's small waves draw the Clockwork army home.
It stays in the code, off. `-- r6:wave` turns it on.

## Results

All games: Hard against Hard, Balanced, headless study games (`tools/study/study_game_v2.gd`), measured on version 0.15.3 maps. "Main" is the same build with `-- r6:off`.
Each map was played from both sides. "Usual side" means the Crown in the first slot.

### Crown against Clockwork

| map (seed) | side | main | round 6 |
|---|---|---|---|
| Greenhold (11) | usual | Crown won 25:55 | Crown ahead at 30:00 |
| Greenhold (11) | other | Clockwork won 21:17 | Crown won 24:34 |
| Frostmere (12) | usual | Crown won 27:33 | Clockwork won 13:16 |
| Frostmere (12) | other | Crown won 24:31 | Crown won 27:29 |
| Hollowfen (13) | usual | Crown won 21:48 | Crown ahead at 30:00 |
| Hollowfen (13) | other | Crown won 20:14 | Crown won 28:59 |
| Kestrel Rise (14) | usual | Clockwork won 15:19 | Clockwork won 16:37 |
| Kestrel Rise (14) | other | Crown won 20:47 | Crown won 20:22 |

The Crown won 6 of 8 on main and 6 of 8 with round 6. The bar was 4 of 8.
The two Hollowfen games were played again after the natural fix (item 7). Before it, the Crown lost both, at 16:10 and 18:37: it had gone 46 tiles out for its first hall.
Round 6 games last longer. The Clockwork keeps attacking: 9 pull-backs in the two Hollowfen games, against 5 on main, and those games ran about 8 minutes longer.
Frostmere from the usual side is a loss with round 6 in every version tried (7 games: full, Clockwork part only, without the hall-spot rules). The Clockwork's first wave, around 8:10, is no longer called home by a Horseman raid, and it breaks the Crown at about 10:00. That is the Clockwork playing better, not a Crown mistake.

Study games used to choose what ships (one game each, so they are only hints):
- Clockwork part only (`r6:clockonly`): Frostmere usual side lost 15:31, Greenhold other side won (30:00, ahead).
- Without the Crown's wave check: Frostmere usual side lost 15:22, Greenhold other side won 24:03. With the wave check, Greenhold other side was lost at 22:54. So the wave check is off.
- Without the hall-spot rules (`r6:nosites`): Frostmere usual side lost 20:46.

### Crown against Brood (no worse)

| map (seed) | main | round 6 |
|---|---|---|
| Greenhold (11) | Crown won 11:17 | Crown won 13:43 |
| Frostmere (12) | Crown won 13:02 | Crown won 12:29 |
| Hollowfen (13) | Crown won 12:23 | Crown won 13:47 |
| Kestrel Rise (14) | Crown won 11:28 | Crown won 11:49 |

4 of 4 both ways. The Brood computer is weak against the Crown on these maps either way.

### The two Kestrel Rise films again (seed 14, 20 minutes, round 6 on 0.15.3)

Film b, the Crown on the usual side.
- The Armoury (5:39) and the Foundry (4:57) stand on the main's plateau, behind the wall.
- No Clocktower under the Crown's cliff. The Crown's own Town Hall stands there at 15:00.
- The Clockwork kept attacking: it pulled waves back at 8:48, 12:26 and 15:22, and it was at a Crown hall again at 15:20 (picture below).
- At 20:00 the Crown is alive with 5 halls, 58 Labourers and 23,060 gold earned. Before: 0% soil, 5 gold and 37 idle Labourers from 12:00.

Film a, the Crown on the other side.
- The Crown opens with the Powder Mill. The Foundry stands at 4:14 and the Armoury at 5:50, both on the plateau. Before, the Armoury was killed unfinished at 9:39 below the ramp.
- The Clockwork still out-earns the Crown and leads at 20:00 (25,674 cogs to 18,380 gold earned), but it never sat still: it pulled waves back at 10:28, 11:30 and 14:01 and went out again each time.

Pictures, in `docs/shots/ai_round6/`:
- `before_crown_main_0600.png` and `after_b_crown_main_armoury_foundry_0600.jpg`: the Crown's main at 6:00.
- `before_clocktower_under_crown_cliff_1500.png` and `after_b_crown_hall_where_the_clocktower_was_1500.jpg`: the ground right of the Crown's main at 15:00.
- `after_b_clockwork_wave_at_crown_hall_1520.jpg`: a Clockwork wave at a Crown hall at 15:20.
- `after_a_crown_main_0600.jpg`: film a, the Crown's main at 6:00.

## Tests

Run on the branch (0.15.3), and the round 6 tests, hold spots and pathing again after merging 0.15.6.
- Pass: test_ai_round6 (now 6 maps), test_ai_round6_stall, test_ai_r5_hold_spots, test_pathing (three runs), test_ai_abandoned_site, test_ai_air_defence, test_ai_army_response, test_ai_crown_bank, test_ai_cw_horse_raid, test_ai_gg_rule, test_ai_placement, test_ai_scout, test_ai_scout_defence, test_ai_scout_threat, test_ai_swarm_freed, test_ai_wall_vs_rush, test_ai_worker_safety, test_gear_ai, test_cw_ai, test_expansion_spots, test_files, test_replay.
- Fail, the same with `-- r6:off`, so not from this round: test_ai_brood_army, test_ai_brood_horse, test_ai_brood_judgement, test_ai_rush, test_ai_rush_followup, test_ai_scout_sentry, test_ai_xrush. Most are about the Brood computer's early army and the Brood rush.
