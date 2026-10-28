# AI round 6: the Crown and Clockwork computers on the bigger maps

Branch `ai-round6`. Written to be read aloud: short sentences, one point at a time.
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

RESULTS_HERE

## Tests

TESTS_HERE
