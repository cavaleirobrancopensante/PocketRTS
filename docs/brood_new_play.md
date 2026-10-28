# Playing the new Brood: ten coached games

The owner asked, on 2026-10-28: "play a few games, just 10 exploratory games, coached and filmed, just to get the feeling of the new Brood. The game is different now that buildings can walk."

This is a feel report, not a balance study. I did not change any numbers. I fixed only bugs that broke a game. They are listed further down.

## How I played

- The tool is tools/play_brood_new.gd. It drives the new Brood with a written plan. It uses the same orders a player gives: lay an egg, root, uproot, haul, move, attack-move, harvest.
- The other side is the normal computer on Hard.
- The coach knows where the enemy started. Otherwise it reacts only to what its own creatures can see.
- It films fights, the Mother, the key moments of each plan, and short clips. The clips became GIFs with tools/play_brood_new_gif.py.
- Each game ran 15 minutes, or until a side lost.
- The first games taught me how to coach. Game 1 played like the computer does. Later games stopped trickling Raptors one by one into the enemy.
- Played on 0.15.9 with the fixes below. They are in 0.15.11.

To play one again:
xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/play_brood_new.gd -- plan:ninja b:brood map:dune_sea seed:7 out:/some/folder

Then: python3 -I tools/play_brood_new_gif.py /some/folder

## The ten games, in short

| Game | Plan | Against | Map | Result |
| --- | --- | --- | --- | --- |
| 1 | Plain game | Crown | Greenhold | Draw at 15:00. I lost 294 Raptors for 35 kills. |
| 2 | War camp: the Mother marches out | Clockwork | Highmoor | Lost. The Mother died at 10:38. |
| 3 | Ninja base: a far turtle with Rootmaws | old Brood | Dune Sea | Won at 9:04. |
| 4 | Grazing: hauling full Rootmaws outward | Crown | Mirewood | Draw at 15:00, the Crown nearly dead. |
| 5 | A turtle rooted on the ramp | old Brood (Rush) | Greenhold | Won at 11:24. |
| 6 | Turtles as tanks | Clockwork | Dune Sea | Draw at 15:00. Clockwork far richer. |
| 7 | War camp, then flee home | Clockwork | Greenhold | Lost. She fled home, then died at 14:54. |
| 8 | The Tyrannosaur fights | old Brood | Mirewood | Won at 8:11. |
| 9 | Best of what I learned | Crown | Highmoor | Draw at 15:00. |
| 10 | The computer plays the new Brood | Crown | Dune Sea | Draw at 15:00. |

Against the Crown: games 1, 4, 9 and 10. Against the Clockwork: 2, 6 and 7. Against the old Brood: 3, 5 and 8. Four maps: Greenhold, Highmoor, Dune Sea and Mirewood.

## Game 1: a plain game

- Plan: play it like the computer. Mother rooted at home. Rootmaws round her, turtles for supply, the Tyrannosaur kept beside her. Raptor waves at 24 supply.
- Against: Crown, Hard, on Greenhold.
- What happened: the Crown walled its ramp at 0:22. My economy matched the Crown: 2,400 food by 5:00 against its 1,900, and 7,500 by 10:00 against 6,800. The first wave of 24 Raptors went at 6:09. It hit the wall and the Musketeers behind it. New Raptors kept running after the wave one by one.
- From 8:00 the Mother laid as fast as she could. Eggs sat at zero and food piled up to 1,100. She was the limit, not the food.
- Result: a draw at 15:00. I lost 294 Raptors and killed 35.
- Feel: the start is calm and pleasant. Two Rootmaws, the grubs at work, the Mother laying. But a plain Raptor army into a walled Crown is a feeding line. The new Brood has nothing yet that breaks a wall early.
- Pictures: g01_home_base_1000.png, g01_raptors_at_the_wall_0637.png.

## Game 2: the war camp

- Plan: at 5:30, with 14 supply of army, the Mother uproots and walks toward the enemy. The army and the Tyrannosaur go round her. She roots about 34 tiles short of the enemy's start. Eggs on the march are grubs and turtles only, because the father can't breathe on eggs while walking.
- Against: Clockwork, Hard, on Highmoor.
- What happened: she set off at 5:30. The march was 81 tiles and took two minutes. Her swamp vanished as she left. Two Rootmaws at home went dry at once. She rooted at 7:29, 24 tiles from the Clockwork start. The Clockwork hit the camp every 30 seconds. The Tyrannosaur kept fighting, so 22 warrior eggs were never fertilised. They hatched as grubs.
- By 10:00 the Clockwork had earned 11,000 cogs. I had 5,700 food. Springers and Pendulums killed the Mother at 10:38.
- Result: lost.
- Feel: watching her walk and drop eggs behind her is the best moment of the new Brood. It looks alive. But a war camp is very costly. She is slow. Home Rootmaws on her swamp stop. Warriors stop while the father walks or fights. At the front she is a target the enemy can always reach.
- Pictures: g02_warcamp_march.gif, g02_laying_while_walking.gif, g02_warcamp_at_the_front_0730.png.

## Game 3: the ninja base

- Plan: at about 3:00 a lone Mound Turtle walks to a far, quiet corner. Two Rootmaws follow. Grubs are sent on the long trips.
- Against: the old Brood, Hard, on Dune Sea.
- What happened: the turtle set off at 3:17 and rooted at 3:53, 27 tiles from the Mother. The first far Rootmaw rooted at 4:28. Each trip from it paid 13.5 food. A trip from a Rootmaw beside the Mother paid 3.9. Nobody ever found the far base.
- Result: won at 9:04. Two waves of 24 and 44 Raptors razed the old Brood. It had earned only 3,000 to my 6,900.
- Feel: this is the most satisfying idea. One slow turtle walks off, and a new base grows where it stops. The pay rule makes it worth the risk. Three to four times more per trip.
- Pictures: g03_ninja_base.gif, g03_ninja_base_0431.png.

## Game 4: grazing, HAUL against UPROOT

- Plan: more Rootmaws. From 6:00, take the full Rootmaw nearest the Mother and HAUL it to fresh ground 15 to 22 tiles out. Turtles root at the swamp's edge to make room.
- Against: Crown, Hard, on Mirewood.
- What happened: at 6:30 a full Rootmaw was hauled. It kept all 299 food. It rooted again 17 seconds later, 22 tiles out. A trip from it went from 2.1 food to 13.4, and its crew from 6 grubs to 10. The second haul, at 7:30, went from 2.3 to 9.6.
- The ground hardly ran out. Each circle holds 3,000. The first Rootmaw ran dry only at 13:49. Rootmaws sat full most of the time. The grubs were the limit, not the ground.
- Result: a draw at 15:00. By then the Crown had no workers left and a single hall. I had 118 Raptors.
- Feel: HAUL is clearly the right button whenever a Rootmaw holds food. UPROOT only makes sense for an empty one. Grazing for fresh ground is a late game thing. In 15 minutes it barely happens. Moving full Rootmaws outward for bigger trips is the real early use of HAUL, and it feels clever.
- Pictures: g04_haul.gif, g04_haul_0630.png.

## Game 5: a turtle on the ramp

- Plan: the first egg is a Mound Turtle. It roots in the middle of the home ramp. At 5:00 it can come back to supply duty.
- Against: the old Brood, Hard. First on Extreme Rush, then on Rush. Greenhold.
- What happened: the turtle hatched at 0:25 and rooted on the ramp at 0:43. The Extreme Rush computer never rushed. It expanded at 1:28 and built no army. So I played again against Rush. Its first attack came at 5:03 with 12 Raptors. They reached the ramp at 5:28 and stopped at the shell. Its health bar stayed full. The computer said its rush failed and went home. My own creatures walked over the shell as they should, after a fix.
- Result: won at 11:24.
- Feel: the ramp turtle is a lovely, readable wall. A big shell in the gap. Raptor claws do almost nothing to it. I could not test it against the owner's two-minute rush, because the computer's rushes came late or never.
- Pictures: g05_ramp_turtle_holds.gif, g05_ramp_turtle_holds_0528.png.

## Game 6: turtles as tanks

- Plan: three Mound Turtles walk with the army. When two enemies come within 6 tiles, a turtle roots there. When the fight moves on, it uproots.
- Against: Clockwork, Hard, on Dune Sea.
- What happened: the turtles joined at 4:24, 4:58 and 5:24. They walk at 26. The Raptors run at 108. Every wave reached the fight long before the turtles did. They rooted late, often alone, by the Clockwork's ramp. All three were dead by 13:29.
- Result: a draw at 15:00. The Clockwork had earned 19,100 to my 11,600.
- Feel: as a tank the turtle does not work with a Raptor army. It is a wall and a supply creature. It is not a front line.
- Picture: g06_tank_turtle_rooted_0920.png.

## Game 7: running the base away

- Plan: the war camp of game 2. When the camp's fight is lost (Mother under 70% health, more enemies than friends near her), she uproots and runs home. The Rootmaws by her haul their food home too.
- First try: against the Crown on Highmoor, with the refuge as a far turtle. The Crown never came near her, and I won at 12:47. No flight happened. So I played it again against the Clockwork.
- Against: Clockwork, Hard, on Greenhold.
- What happened: she marched at 5:30 and rooted at 7:25. The front was harassed all the time. 55 warrior eggs became grubs. At 11:14 she was at 1,665 health with 6 enemies near her and none of mine. She uprooted under fire and ran 79 tiles home. That took two minutes. She rooted at home at 13:17 with 1,442 health. The Clockwork army followed her and killed her at 14:54.
- Result: lost.
- Feel: fleeing works, and it is dramatic. But a lost fight is not just lost ground. The enemy simply follows her. She is too slow to get away unless something holds them back.
- One surprise: an uprooted Mother standing idle roots again by herself when an enemy comes in reach. My first try used UPROOT and then a move order. In that short idle moment she rooted again on the spot. A single move order works: it uproots her and walks on at once.
- Pictures: g07_mother_flees.gif, g07_mother_flees_1114.png.

## Game 8: the Tyrannosaur as a fighter

- Plan: the Tyrannosaur leads every wave.
- Against: the old Brood, Hard, on Mirewood.
- What happened: the first wave went at 5:55, 24 Raptors with the Tyrannosaur in front. He razed a Feeding Pit, a Burrow and a Brood Pen himself. While he was away, no warrior egg could be laid. Eggs sat at ten. Food piled up to 1,900.
- Result: won at 8:11.
- Feel: the trade is clear and easy to read. He is a great fighter. While he fights, the Brood makes no warriors. Against a weak enemy that is fine. Against the Clockwork in games 2 and 7 it cost the game.
- Picture: g08_tyrannosaur_leads_0555.png.

## Game 9: the best of what I learned

- Plan: a ramp turtle early, released at 5:00. A ninja turtle with two far Rootmaws. Full Rootmaws hauled outward. The Tyrannosaur at home. No trickling.
- Against: Crown, Hard, on Highmoor.
- What happened: the ramp turtle rooted at 0:43. The far turtle rooted at 3:13. Far trips paid 13.5 and 16.6 against 3.9 at home. The first haul went from 2.1 to 8.1 a trip. Waves went out from 6:59. They kept losing to Musketeers behind the wall. From 13:30 the Crown pushed up my ramp.
- My first try of this game showed a jam. A Rootmaw rooted at the foot of my ramp, with a turtle on it. The Tyrannosaur stood stuck at the top for five minutes, so no warriors were made. I lost that try at 13:32. I then kept Rootmaws 4 tiles away from ramps.
- Result: a draw at 15:00. Food 11,800 against the Crown's 12,800 gold.
- Feel: the economy side is fun and full of choices. The army side is thin. It is all Raptors.
- Picture: g09_crown_at_the_ramp_1447.png.

## Game 10: the computer plays the new Brood

- Against: Crown, Hard, on Dune Sea. Both sides were computers.
- What happened: it kept 13 grubs for the first six minutes. One Rootmaw stood unrooted from 0:30 to 6:30, because there was no free swamp for it. Its waves went at 4:07, 5:47, 8:12, 10:16 and 12:15. They lost 174 creatures for 20 kills. Still, the 12:15 wave razed a Crown Town Hall at 12:38.
- Result: a draw at 15:00. It earned 8,500. My coached games earned about 12,000 in the same time.
- Feel: it plays the basics. It does not move the Mother, haul, make far bases or close its ramp.
- Picture: g10_computer_raptors_raze_hall_1244.png.

## Bugs I fixed (game code, each in its own commit)

1. Her own eggs pushed the rooted Mother. Over ten minutes of laying she slid about nine tiles, her swamp with her, and the first Rootmaw went dry. A rooted new-Brood creature is no longer shoved.
2. When the rooted Mother swiped at a scout, the idle leash sent her back to where she was made. She uprooted and walked off. The leash no longer applies to a rooted creature.
3. The computer chose spots past the edge of the map. Creatures walked to the edge and stood there forever. Spots must now lie inside the map.
4. Eggs and food piles shoved everything and could not be shoved. A turtle hatching among them was caged. Eggs and piles now shove nobody.
5. A grub whose Rootmaw or food pile was gone froze with a script error. Two commits; the first missed that a freed object compares equal to null.
6. Your own rooted Mound Turtle pushed your own creatures away, though they should climb over it. It penned the walking Mother on her ramp for a minute.
7. Paths run straight through the rooted Mother, because she is not in the path grid. Creatures stood pressed to her side. A creature stuck against her, or against the Tyrannosaur at her eggs, now steps round them.
8. A walking Mound Turtle weighed as little as a grub. The grubs streaming to the Mother washed it back. New turtles stood stuck and supply stayed capped. A walking turtle is now as heavy as the Tyrannosaur.

Note for the other helper: scripts/brood_new.gd sets a just-uprooted turtle back to weight 1 when its mode changes. scripts/unit.gd sets it to 8 again the next tick. It would be tidier in one place.

tools/test_brood_new.gd passes after the fixes.

## Overall impressions

### What is fun

- The Mother walking and dropping eggs behind her. It looks alive and nothing like the other factions.
- The far turtle that turns into a hidden base. One slow walker, and a swamp grows where it stops.
- Hauling a full Rootmaw outward. You watch the trip pay jump from 2 to 13.
- The ramp turtle. A big shell in the gap, and Raptors bounce off it.
- The father trade. Keep him home and you get warriors. Send him out and he wins fights, but the eggs stop.
- Fat, full Rootmaws tell you at a glance that you need more grubs.

### What is awkward or confusing

- The swamp is small. The Mother's swamp holds only two to four Rootmaws, because their circles must be 10 tiles apart. You need turtles at its edge. The computer got stuck on this.
- When the Mother walks, every Rootmaw on her swamp goes dry at once. Nothing warns you.
- Eggs laid on the march are wasted, because the father fertilises only standing still.
- An idle walking Mother roots again by herself near an enemy.
- UPROOT spills a full Rootmaw's food. HAUL keeps it. You almost always want HAUL.
- Traffic: everything hatches at the Mother and all grubs unload there. Big walkers and grubs jam there and on ramps. The fixes help a lot.
- Turtles are too slow to keep up with an army.

### What feels too strong

- The ramp turtle against Raptors. Claws barely scratch it. It is fair against Musketeers and machines, which break it.
- Far bases against the computer. No computer ever looked for them.
- The rooted Mother at home. No computer threatened her in any game where she stayed home.

### What feels too weak

- The army. It is all Raptors in practice. Brutes need essence. Essence came only from harvesting bodies, slowly: never more than about 55 at a time. Raptors into walled Musketeers trade very badly.
- The late game. One Mother lays one egg every 6 seconds, or every 4.6 with three turtles. That is about 13 eggs a minute at most. From 8:00 on she was the limit, and food piled up.
- The economy against the Clockwork. By 10:00 the Clockwork had earned 11,000 to 12,000. I had 5,700 to 7,400.
- The war camp. Slow to set up, it stops warriors, and the enemy can always reach her.

### The owner's ideas in play

- Work well: only the Mother lays eggs, walking or rooted. The Rootmaw that drinks its ground and fattens. HAUL and UPROOT. The farther, the more a trip pays. The Mound Turtle as the expansion and the wall. Kill the Mother and you win. The father near the Mother.
- Work less well: the Mound Turtle as a tank in a fight. The Mother as a moving war camp, as it is now. The father walking with a marching Mother.
- Not tested well: the turtle wall against an early rush. The computer's rushes came at 5:00 or never.

### What the opponents can do against it

- Hunt the Mother when she walks. She is slow, and she has no rooted armour then.
- Kill the Tyrannosaur, or pull him into a fight. Warrior eggs stop at once.
- Kill a far turtle. Its swamp shrinks, and its Rootmaws go dry.
- Keep a wall with Musketeers. Raptors break on it.
- Out-grow it. The Clockwork did, and the new Brood's late game is capped by one Mother.
- The computer opponents did none of the first three on purpose.

## Suggestions for the owner to decide (most important first)

1. The Mother's egg rate is the new Brood's late-game ceiling: about 13 eggs a minute. Decide what should lift it. For example the Mother's stages (your idea of 14:18), more turtles counting, or eggs that hatch more than one creature.
2. Let the father fertilise while walking beside the Mother, or let eggs laid on the march wait longer. Then a war camp can still make warriors.
3. Give the new Brood something that breaks walls, or more essence. Brutes are rare now. The Spitter father or the Pterodactyl would help. So would SACRIFICE paying more.
4. Make the swamp room easier to see. Show where a Rootmaw may root while placing it. Warn which Rootmaws will go dry before the Mother walks.
5. Decide if an idle walking Mother should root again by herself when an enemy comes near.
6. Decide the Mound Turtle's role. A faster walk would make it a tank. Otherwise accept it as a wall and supply only.
7. Teach the computer the new tricks: haul full Rootmaws outward, far turtles, turtles at the swamp's edge, keep the father home.
8. Look at the old Brood computer's rushes. Extreme Rush expanded at 1:28 and never attacked. Rush came at 5:03. Then the ramp turtle can be tested against the two-minute rush.

## Pictures

All in docs/shots/brood_new_play/, named by game and moment.
- g01_home_base_1000.png: the rooted Mother, Rootmaws, turtles and grubs at 10:00.
- g01_raptors_at_the_wall_0637.png: the first wave at the Crown's wall.
- g02_warcamp_march.gif: the Mother marching with her army.
- g02_laying_while_walking.gif: eggs dropping behind her as she walks.
- g02_warcamp_at_the_front_0730.png: the war camp rooted by the Clockwork base.
- g03_ninja_base.gif and g03_ninja_base_0431.png: the far turtle and its Rootmaws.
- g04_haul.gif and g04_haul_0630.png: a full Rootmaw hauled outward.
- g05_ramp_turtle_holds.gif and g05_ramp_turtle_holds_0528.png: Raptors stopped by the shell on the ramp.
- g06_tank_turtle_rooted_0920.png: a tank turtle rooted alone by the Clockwork ramp.
- g07_mother_flees.gif and g07_mother_flees_1114.png: the Mother uprooting under fire and running home.
- g08_tyrannosaur_leads_0555.png: the Tyrannosaur leading the wave.
- g09_crown_at_the_ramp_1447.png: the Crown pushing up the ramp in game 9.
- g10_computer_raptors_raze_hall_1244.png: the computer's Raptors razing a Crown Town Hall.
