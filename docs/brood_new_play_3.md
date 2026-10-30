# Playing the Brood, round 3: coached games for its computer player

The owner (2026-10-29 22:50): "This new Brood doesn't have an AI. Make a coaching like you did before." Rounds 1 and 2
(docs/brood_new_play.md, docs/brood_new_play_2.md) were played on 0.15.x. Since then the Brood has gained the Sire
lures, research, young and mature, the Storm line, two young to an egg, her stages and spoils. This round plays
today's Brood (0.21.2), finds what wins, and builds the computer player from it (docs/brood_ai.md).

Pictures: docs/shots/brood_play_3/.

## How I played

- The tool is tools/play_brood_3.gd (it extends round 1's tools/play_brood_new.gd, so the filming, the match log,
  coach.txt and events.txt are the same).
- Side 0 is the Brood. The old coach's hand-written economy could not play the lures, research, maturing or the three
  lines, so this round's coach steers the new computer's building blocks (scripts/ai_brood_new.gd). These are the same
  orders a player gives: lay, root, uproot, a grub's BUILD, research, MATURE, sacrifice, harvest, move and
  attack-move.
- Each game forces a PLAN (`coach:<plan>`): when the Sires come, the warrior mix, when she grows, the expansions, when
  it attacks and with what. Any setting can be changed with `set:key=value`. The coach adds its own hand orders on
  top: the ramp turtle, the Sire leading the wave, and the whole Mother rush.
- The other side is the normal computer on Hard.
- Every game was filmed: fights, the Mother every few minutes, each Sire as he comes, the first moult, every wave,
  the first wave as a GIF. minutes.txt has a line a minute: eggs laid, food and spoils unspent, supply, grubs,
  Rootmaws, turtles (far ones), army value of both sides, research done, young matured, kills and losses, income of
  both sides.
- 26 games of up to 15 minutes, in two rounds:
  - Round A: 15 games with the first draft of the computer.
  - Round B: 11 games after fixing what round A showed.
- The owner's four extra plans (23:31) are in both rounds: Tyrant Sire frontline, Venom Sire back line, the Brood
  Mother rush, and the air rush.

To play one again:

    xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_brood_3.gd -- \
        coach:venomback b:crown map:highmoor seed:5 out:/some/folder end:900
    python3 -I tools/play_brood_new_gif.py /some/folder

## The games

Results: W won, D draw (both alive at 15:00), L lost (the Mother fell). "Trade" is the enemy value killed against
the Brood value lost. "Income" is the Brood's food earned against the enemy's gold, at the end.

| Game | Plan | Against | Map, seed | Result | Trade | Income |
| --- | --- | --- | --- | --- | --- | --- |
| A g01 | Extreme rush | Crown | Greenhold 3 | L 14:42 | 1,820 / 3,975 | 7,565 / 14,440 |
| A g02 | Rush (10 Raptors) | Clockwork | Highmoor 5 | L 14:10 | 4,165 / 4,650 | 6,899 / 18,399 |
| A g03 | Tyrant timing | Crown | Greenhold 11 | D | 1,530 / 3,425 | 9,746 / 15,460 |
| A g04 | Tyrant timing | Clockwork | Dune Sea 7 | L 13:22 | 3,090 / 4,100 | 7,207 / 16,733 |
| A g05 | Venom line | Crown | Highmoor 5 | D | 3,175 / 5,400 | 9,702 / 18,240 |
| A g06 | Storm line | Clockwork | Greenhold 3 | L 14:11 | 3,675 / 5,775 | 8,318 / 18,740 |
| A g07 | Fast expand | Crown | Dune Sea 7 | D | 3,460 / 4,070 | 10,386 / 17,860 |
| A g08 | Fast expand | Clockwork | Twin Fords 9 | L 13:17 | 3,135 / 4,450 | 7,299 / 17,275 |
| A g09 | Ramp turtle, army home | Clockwork (Rush) | Greenhold 3 | L 14:17 | 3,165 / 3,625 | 5,658 / 17,535 |
| A g10 | Tyrant Sire frontline | Crown | Highmoor 5 | L 14:53 | 2,525 / 4,595 | 8,614 / 15,200 |
| A g11 | Venom Sire back line | Clockwork | Greenhold 3 | L 12:52 | 2,620 / 3,050 | 5,862 / 14,650 |
| A g12 | Mother rush (scouted) | Crown | Greenhold 3 | L 5:17 | 60 / 325 | 0 / 2,280 |
| A g13 | Mother rush (no scout) | Crown | Greenhold 3 | L 5:50 | 60 / 0 | 0 / 2,660 |
| A g14 | Air rush | Clockwork | Dune Sea 7 | D | 4,760 / 5,730 | 9,255 / 20,701 |
| A g15 | Mother rush | Clockwork | Highmoor 5 | L 7:39 | 2,330 / 575 | 0 / 3,747 |
| B g16 | Mother rush (scouted) | Crown | Greenhold 3 | L 6:08 | 120 / 275 | 0 / 3,420 |
| B g17 | Mother rush (no scout) | Crown | Greenhold 3 | L 5:20 | 60 / 125 | 0 / 2,660 |
| B g18 | Tyrant timing | Crown | Greenhold 11 | D | 2,535 / 4,825 | 9,624 / 16,340 |
| B g19 | Venom line | Crown | Highmoor 5 | D | 2,070 / 5,440 | 8,797 / 17,480 |
| B g20 | Air rush | Clockwork | Dune Sea 7 | D | **11,020 / 4,345** | 10,857 / 20,242 |
| B g21 | The computer, Balanced | Crown | Greenhold 3 | D | 1,875 / 6,340 | 10,075 / 15,840 |
| B g22 | The computer, Balanced | Clockwork | Greenhold 3 | L 13:55 | 3,595 / 4,970 | 7,474 / 17,139 |
| B g23 | Mother rush | Clockwork | Highmoor 5 | L 8:41 | 2,220 / 500 | 0 / 2,256 |
| B g24 | Tyrant Sire frontline | Clockwork | Greenhold 3 | D | 3,660 / 5,975 | 9,635 / 19,721 |
| B g25 | Venom Sire back line | Crown | Highmoor 5 | D | 3,945 / 4,240 | 9,607 / 17,360 |
| B g26 | Fast expand | Crown | Dune Sea 7 | D | 3,065 / 4,085 | 10,577 / 17,100 |

- Round A: no win, 4 draws, 11 losses.
- Round B: no win, 8 draws, 3 losses. All three losses were Mother rushes, plus g22.
- The old computer, for comparison (the same maps and seeds, docs/brood_ai.md): 1 win (Highmoor, against the
  Crown), 2 draws, 3 losses.

## What round A showed (the bugs, fixed for round B)

1. **Saving food for her stage 3 while its spoils never came.** She needs 500 food and 75 spoils for stage 3. The
   computer kept the food back from 8:00 on, but the spoils came slowly. No warrior egg was laid for minutes, while
   500 to 2,800 food sat unspent. This was round 2's trap again (docs/brood_new_play_2.md, test 3).
   - Fix: food is kept for a stage only once its spoils are 60% there.
   - Fix: grubs are never held back for it while the workforce is far short.
2. **The stage-3 spoils reserve blocked everything else.** It blocked Bigger Clutch, Pack Hunt, Spitters and
   maturing. In the Tyrant and Venom plans the computer researched nothing at all, and its "venom" army had no
   Spitters.
   - Fix: the army's own research never waits for her stage.
   - Fix: her spoils are kept only once her food is nearly there.
   - Fix: grubs that are off harvesting no longer count as spoils already in hand.
3. **A far turtle sent to its death 20 times.** The best turtle spot on Highmoor was 32 tiles out, near the enemy.
   Each grub sent to it was killed on the way, and the next was sent a few seconds later.
   - Fix: a spot is not tried again for 3 minutes.
   - Fix: at most one far turtle every 45 seconds.
   - Fix: no far turtle beyond 30 tiles.
4. **Rootmaws with nobody to crew them, and too few grubs.** The rush plans held 6 to 9 grubs, then built 4
   Rootmaws. The warriors took every egg after that, so the workforce stuck at 8.
   - Fix: grubs follow a curve per plan ("drone": 3 to 6 a minute), so they come before warriors.
   - Fix: no Rootmaw without 5 grubs for it.
5. **The Tyrant Sire's lure failed nine times in a row.** A grub walked to grow it, and the eggs laid meanwhile spent
   the 200 food. When it arrived, the food was gone. Then the computer froze: the Sire needed more supply, and the
   supply turtle came after the Sire in its list.
   - Fix: the price of the structure a grub is walking to is kept back.
   - Fix: a Sire short of supply asks for a turtle first.
6. **Rush evidence that was not a rush.** A scout that saw the Crown's own army at home took it for a rush.
   - Fix: only an army seen out of its base, near the Mother, or riders on the move count.

## What each plan taught

### Extreme rush (g01): the yardstick is out of reach for today's Brood

- Timeline: Tyrant Sire's lure at 0:00, he arrives 0:36, first Raptors 0:58, 8 Raptors by about 2:30.
- The wave leaves at 2:40 and reaches the Crown's ramp at about 3:10.
- The Crown had walled its ramp at 0:38 (it does in every game, scouted or not). Its scout saw the Raptors at 1:08.
  Two Musketeers stood behind the wall.
- The wave lost 6 of its 8 Raptors and killed nothing. The computer then played Balanced.
- The yardstick (docs/design_principles.md 5) is 8 Raptors by 2:00, hitting at 2:00 to 2:30. Today's Brood cannot
  reach it. It starts with 250 food and earns about 320 by 2:00. The Sire (200), a supply turtle (100) and 4
  Raptor eggs (200) cost more than that.
- The fastest rush lands at about 3:10. docs/brood_replace.md found the same.
- It is a gamble that loses to a proper defence, as it should. Whether it beats an unprepared opponent could not be
  tested: every Hard Crown walls its ramp in its first minute.

### Rush, 10 Raptors (g02)

- The wave left at 3:58 and reached the Clockwork. Its Clock Soldiers were already out at about 2:00.
- It killed 350 and lost 150 of its 250, then pulled back.
- Holding 9 grubs for the rush cost the economy a whole minute that it never caught up.

### Tyrant line timing (g03, g04, g18)

- Round B, with research: Bigger Clutch and Pack Hunt were done by about 8:00.
- Two waves of 35 to 38 supply, almost all Raptors, went into the Crown.
- They lost 4,825 and killed 2,535: Raptors die at the musket wall. The draw came because the Crown never pushed in.
- Picture: g18_raptors_at_the_crown_hall_0933.png (Raptors at a Crown hall outside the wall), g18_tyrant_sire_comes_0136.png.

### Venom line (g05, g19)

- The Venom line is spoils-hungry: a Spitter egg costs 5 spoils and her stage 3 wants 75.
- Even after the fixes it had only 2 to 8 Spitters, and the waves were again mostly Raptors. Two draws.

### Storm line and the AIR RUSH (g06, g14, g20): not viable today

- The owner's air rush: Storm Challengers as fast as possible.
- **No Storm Challenger was ever made.** Even with her stages forced early, the Storm Sire came at 7:22 in g14 and
  never in g20.
- The reason is spoils:
  - the Storm Sire: 50
  - her stage 3: 75
  - each Hatchling egg: 10
  - each Challenger's moult: 25
  - in all, about 400 spoils for six Storm Challengers.
- The Brood's spoils income is 10 to 20 a minute from bodies and sacrifice. The Storm line needs a spoils economy
  the Brood does not have.
- **Balance finding:** the air rush cannot be played as a plan. Cheaper Storm-line spoils, or a steadier spoils
  income, would open it.
- **What g20 did instead was the best game of the round.** It played as a Raptor mass with Bigger Clutch and Pack
  Hunt, with waves of 12, 19 and then 55 Raptors.
  - It killed 11,020 and lost 4,345 against the Hard Clockwork.
  - The Raptors burned its expansion halls and kept its army busy (g20_raptors_burn_a_clockwork_hall_1036.png).
  - Fast Raptors with Pack Hunt beat Clock Soldiers that wind down off their gear ground.
  - It still earned only half as much and could not finish.

### Fast expand (g07, g08, g26)

- Three Mound Turtles on new ground by 6:00 to 7:00, 36 grubs and 9 Rootmaws: the Brood's best income.
- That was 10,400 to 10,600 by 15:00, but still only 58 to 62% of the Crown's.
- Against the Clockwork it was 42% (g08, lost). Expanding does not close the gap.
- **Balance finding:** in every game the Brood earns 45 to 65% of what the Hard Crown or Clockwork earns.
  - Per worker the income is about the same: about 30 food a grub a minute against about 35 gold a labourer.
  - The Brood simply cannot grow as many workers. One Mother lays every egg, grubs and warriors alike, and Rootmaw
    room is limited.
  - Rounds 1 and 2 found the same gap.

### Turtle on the ramp, army home (g09)

- The first Mound Turtle got up at 2:18 and rooted on the ramp below the Mother at 2:31 (g09_ramp_turtle_0231.png).
- The Clockwork's Rush still came in. The army stayed home and reached 30 Raptors by 7:00, then went out at 8:22
  and was lost.
- The turtle buys time, but holding everything home only gives the richer side more time.

### Tyrant Sire frontline (the owner's idea 1; g10, g24)

- **The worst trade of the round.** The Sire led the wave at 8:31 (g10) and was killed in the fight. The wave killed
  nothing.
- While he walks, no egg of his line is laid, so the Raptors stopped. A new lure took until 12:26.
- Against the Clockwork (g24) the army never got big enough to follow him: a draw at 3,660 for 5,975.
- **Verdict:** his 1,000 health does not make up for losing the barracks. Keep him home (as round 2 found).

### Venom Sire back line (the owner's idea 2; g11, g25)

- **The best trade against the Crown:** 3,945 for 4,240 (g25), where the Raptor-only waves traded 1 for 2 or worse.
  - The Venom Sire walks behind the Raptors. His acid (range 140) reaches the Musketeers, and he shoots flyers.
  - His own line (Spitters) stops while he is away, but the Raptor line goes on.
- Against the Clockwork (g11, round A, before the fixes) it lost.
- **Verdict:** a good idea against a walled shooter line. The computer can use it ("sire_leads": "dilophosaurus").
  It is not on by default; see the open questions in docs/brood_ai.md.

### The Brood Mother rush (the owner's idea 3, "insane all-in"; g12, g13, g15, g16, g17, g23)

- Played as the owner corrected it at 23:34: from second one she uproots and walks on the enemy. Every grub and the
  Rootmaw go with her. Every egg she has becomes a grub, which fights too.
- Against the Crown, scouted (g12, g16) and not scouted (g13, g17, the Crown's scout switched off):
  - She arrives at 2:15 to 2:19 with full health (2,400).
  - The Crown's ramp wall (a Cottage and a Gate) is up at 0:38 in every game, scouted or not.
  - **She cannot get at the gate.** She stands below it at the ramp's foot, even when ordered to attack it.
  - The Musketeers on the high ground shoot her down. She falls at 5:17 to 6:08, having killed 60 to 120.
  - Scouting makes no difference: the wall is the Crown's standard opening.
  - Picture: g13_mother_stuck_at_the_gate.png. GIF: g16_mother_rush_march.gif.
- Against the Clockwork (g15, g23), which has no wall:
  - She fights in its base for 5 to 6 minutes.
  - She killed 2,220 to 2,330 (about 35 units) for 500 to 575, but fell at 7:39 and 8:41.
  - GIF: g23_mother_rush_vs_clockwork.gif.
- What it costs her: no food comes in at all (0 earned: no Rootmaw is rooted). Her eggs become grubs only out of
  the 250 she started with. Her death is the game.
- **Verdict:** not too strong, and not an exploit by design_principles. It is a gamble that loses to a Hard opponent.
  - Against the Clockwork she is a fearsome fighter for a few minutes: 2,400 health, healing, and a big swipe.
  - Against a walled Crown she never gets in.
  - Whether she beats an opponent who does nothing at all could not be shown: the Hard computers wall or fight back
    by default.
- **Possible bug for the owner:** the Mother cannot attack a Gate on a ramp. An attack order leaves her standing at
  its foot. Her big body may not reach it. Not changed here.
- Kept out of the computer, as the owner asked.

### The computer's own Balanced (g21, g22)

- Against the Crown: a draw, trading badly (1,875 for 6,340). The Raptor waves went into the wall. This led to the
  wall rule below.
- Against the Clockwork: lost at 13:55.

## What a good Brood player does, minute by minute (as learned)

- **0:00 to 1:10:** grubs to 8 and a second Rootmaw. The Tyrant Sire's lure at about 1:10, when 200 food is there.
  A grub goes to scout at 1:10.
- **1:45 to 2:30:** the Tyrant Sire is on his nest. The first Mound Turtle (supply) by about 2:30. Grubs keep coming,
  about 5 a minute, and a few Raptors hold the base.
- **3:00 to 5:00:** grubs to about 20, Rootmaws 4. Grow her to stage 2 (300 food) at about 4:00 to 5:00. Bigger
  Clutch as soon as 15 spoils are in hand (sacrifice a few spare Raptors for them).
- **5:00 to 7:00:** the Venom Sire. The first far Mound Turtle with Rootmaws round it. Pack Hunt before the first
  attack.
- **7:00 to 9:00:** about 30 grubs, 7 to 8 Rootmaws, 2 far turtles. 35 to 50 supply of army.
  - Against the Clockwork: Raptors in numbers, with Bigger Clutch and Pack Hunt, raiding its expansions and its army
    off its gear ground.
  - Against the Crown: do not throw claws at the musket wall. Build Spitters (spoils!), walk the Venom Sire with the
    Raptors, and wait for Brutes with Battering Horns at stage 3, or for the supply cap.
- **Always:** keep the Tyrant Sire home (he is the barracks). Fight at home on the swamp, where her creatures are
  faster and the Mother can get up. Pull a wave back as soon as it is losing; the Brood cannot afford a lost army.
- **The hard truth:** with about half the income, the Brood only draws a Hard computer that defends well. It wins
  only by trading far better. Raptors against the Clockwork's winding army can do that; claws against Musketeers
  behind a wall cannot.

## Balance findings for the owner (not changed here)

1. **Income gap:** the Brood earns 45 to 65% of a Hard Crown's or Clockwork's income, in every plan, even expanding
   fast. Worker for worker it is equal. The limits are one Mother laying every egg and the room for Rootmaws.
2. **Spoils:** almost everything beyond Raptors costs spoils (Sires, stage 3, research, Spitters, Hatchlings,
   moults), and the income is 10 to 20 a minute. The Storm line (about 400 spoils for six Storm Challengers) and the
   air rush are out of reach.
3. **The extreme-rush yardstick** (8 Raptors by 2:00) cannot be met by today's Brood: the Tyrant Sire's 200 food comes
   first. Its fastest rush lands at about 3:10.
4. **The Mother rush** is not an exploit: it loses to both Hard computers. The Mother not reaching a ramp gate may
   be a bug.
5. **The Tyrant Sire as a frontline fighter** is a trap (his line stops, he dies). **The Venom Sire as long-range
   support** is a fair, good tactic.

## Pictures (docs/shots/brood_play_3/)

- g01_extreme_rush_first_wave.gif: the Extreme rush's 8 Raptors leaving at 2:40.
- g09_ramp_turtle_0231.png: the Mound Turtle rooted on the ramp below the Mother.
- g13_mother_stuck_at_the_gate.png: the Mother rush at the Crown's ramp gate, unable to get at it.
- g16_mother_rush_march.gif: the Mother marching on the Crown with her grubs.
- g18_tyrant_sire_comes_0136.png: the Tyrant Sire on his nest beside her.
- g18_first_moult_1416.png: the first young one moulting into a Tyrant Challenger.
- g18_raptors_at_the_crown_hall_0933.png: a Pack Hunt Raptor wave at a Crown hall.
- g20_raptors_burn_a_clockwork_hall_1036.png: Raptors burning a Clockwork expansion hall (the best game).
- g23_mother_rush_vs_clockwork.gif: the Mother rush fighting inside the Clockwork's base.
