# Clock Soldier: quicker, lighter, and SHIELD FORWARD (0.14.49)

The owner asked for this: "I think we should increase a bit the Clock Soldier's movement, reduce its health, and give it an upgrade that allows them to put the shield forward, so they lose movement speed but gain a defensive buff, maybe some armor."

All the numbers below are first guesses, measured in headless fights but not yet played by a person. Expect to change them after a playtest.

## The new numbers

The Clock Soldier itself:

| | before | now |
|---|---|---|
| Health | 90 | 75 |
| Speed | 62 | 68 |
| Armour, damage, price | 1, 10 every 1.2 s, 70 cogs | unchanged |

The research, SHIELD WALL. It sits at the Movement Works, because that is the building that makes Clock Soldiers and the player is already looking there; the Escapement is the Jacks' tech building and the Clock Soldier needs nothing else in the tree. It costs 100 cogs and 50 Tension and takes 45 seconds. Because it costs Tension, the game's Tension rule applies: it can only be researched at a Movement Works whose gear ring meshes with a Mainspring's. That also keeps it out of the early Clock Soldier rush, which has no Mainspring.

The stance, SHIELD FORWARD. Once SHIELD WALL is researched, selected Clock Soldiers get a toggle button, SHIELD FORWARD, on the key F (free on a Clockwork army's card: the Jack's JUMP is E). Pressing it again lowers the shields.

| While the shield is forward | |
|---|---|
| Switching up or down | half a second, standing still, no new blow |
| Walking speed | 60% of normal (68 becomes about 41) |
| Armour | plus 1 (1 becomes 2) |
| Shots from the front | half the damage |
| Blows from the front | a fifth less damage |
| Shots or blows from the side or behind | no reduction, only the extra armour |
| Splash (shells, blasts, gas clouds) | no reduction, only the extra armour |
| Its own blows | 15% slower (one every 1.38 s instead of 1.2) |

The front is a cone of about 70 degrees on each side of where the soldier faces. The soldier still fights with the shield forward. I made it swing a little slower because holding a shield out in front should cost something in the fight itself, not only on the march; the measurements below show it still wins the fights it should.

Why the front cut is bigger for shots than for blows: the first try used the same 35% cut for both, plus 2 armour. Against Raptors that turned a hopeless fight into a clean win (six soldiers beat eighteen Raptors five times out of six), because Raptor claws do only 6 damage and the armour ate almost all of it. The shield is meant against shooters, so the melee cut was lowered to a fifth and the armour bonus to 1, and the cut against shots was raised to half.

## The measured fights

Tool: `tools/measure_clock_soldier.gd`. Both groups start 340 pixels apart on open ground and attack-move into each other. The Clockwork's wind is kept full so only the fight is measured. Each line is six fights. "Old" is the soldier at 90 health and speed 62, "new" at 75 and 68, "shield" is new with the shield forward from the start.

| Fight | old: wins, left | new: wins, left | shield: wins, left |
|---|---|---|---|
| 6 soldiers vs 6 Musketeers (equal price) | 0 of 6; Musketeers keep 4.2 | 0 of 6; they keep 5.0 | 0 of 6; they keep 3.7 |
| 6 vs 5 Musketeers | 0 of 6; they keep 2.2 | 0 of 6; they keep 3.2 | 2 of 6; they keep 1.2 |
| 8 vs 6 Musketeers | 5 of 6, 3.3 soldiers left | 1 of 6, 0.5 left | 6 of 6, 4.7 left |
| 6 vs 5 Spitters | 6 of 6, 4.7 left | 6 of 6, 3.7 left | 6 of 6, 5.0 left |
| 6 vs 7 Spitters | 6 of 6, 2.5 left | 0 of 6; Spitters keep 1.8 | 6 of 6, 3.7 left |
| 6 vs 4 Jacks | 6 of 6, 3.5 left | 6 of 6, 2.0 left | 6 of 6, 5.7 left |
| 6 vs 6 Jacks | 0 of 6; Jacks keep 4.0 | 0 of 6; they keep 5.2 | 6 of 6, 3.8 left |
| 6 vs 18 Raptors (6 eggs) | 0 of 6; Raptors keep 14 | 0 of 6; they keep 15 | 0 of 6; they keep 10 |
| 6 vs 8 Labourers | 6 of 6, 4.8 left | 6 of 6, 4.3 left | 6 of 6, 5.7 left |
| 3 vs 8 Labourers | 0 of 6; 6.2 Labourers left | 0 of 6; 6.5 left | 0 of 6; 5.0 left |
| 6 vs 4 Brutes | 0 of 6 | 0 of 6 | 0 of 6 |

What this says.

The base change on its own makes the Clock Soldier a little weaker in a stand-up fight: it loses about a sixth of its health and gains nothing for it while both sides stand and fight. It hurts most where the fight was close: eight soldiers against six Musketeers went from five wins in six to one, and six against seven Spitters from six wins to none. Against Raptors and Labourers the change is small: Raptors already beat Clock Soldiers for the same price, and six soldiers still clear eight Labourers.

The shield, against shooters, is the clear win the owner asked for. Six soldiers against six Jacks went from no wins to six; against seven Spitters from none to six; eight against six Musketeers from one to six. Against Musketeers at an equal price the shield still loses, because a Musketeer is also a strong melee soldier: his bayonet does 18 a second up close, and the shield only cuts a fifth of a blow. It still takes the Musketeers from 5 survivors down to 3.7, and with one Musketeer fewer it starts to win.

Against melee the shield helps only a little (Raptors keep 10 instead of 15, Labourers 5 instead of 6.5), and against Brutes not at all. That is on purpose.

The race, measured on one soldier:

| | old | new | shield |
|---|---|---|---|
| Chasing a Musketeer who walks off (speed 62): first blow | after 19.7 s (barely) | after 4.2 s | never: 413 px behind after 20 s |
| Walking 420 px away from 4 Musketeers firing at it | 89 damage | 70 damage | 174 damage |
| Walking up to 4 Musketeers until it reaches them | 73 damage | 66 damage | 23 damage |

So the stance wins the advance into a firing line (a third of the damage), but loses the chase completely and costs two and a half times the damage when running away, because the slow walk gives the shooters more volleys and the shield does nothing for its back. Lowering the shield before chasing or retreating is the player's skill, and the computer does it too.

## What it does to the Clock Soldier rush

The rush walks at the new speed: about 9% faster everywhere. Using the build-order calculator's walking times:

| Map | walk to the enemy hall, before | now (about) | wind left on arrival, before | now (about) |
|---|---|---|---|---|
| Kestrel Rise | 40 s | 36 s | 52% | 56% |
| Greenhold | 42 s | 38 s | 50% | 54% |
| Ashford Crossing | 53 s | 48 s | 37% | 43% |
| Frostmere | 59 s | 54 s | 30% | 36% |
| Saltmarsh Isles | 68 s | 62 s | 18% | 25% |

Headless matches, the scripted Clock Soldier rush (`cw_soldier_rush`, Kestrel Rise, three seeds each, seven minutes), before and after:

| Against | before | after |
|---|---|---|
| Crown with a wall and Musketeers (`crown_musket_wall`) | the wave turns back, kills nothing; 1 ahead, 2 even | the wave turns back, kills nothing; 1 even, 2 behind |
| Crown computer | the wave turns back; 3 even | the wave turns back; 1 ahead, 1 even, 1 behind |
| Brood economy opening | Clockwork ahead 3 of 3; 8, 9 and 12 grubs killed | ahead 3 of 3; 16, 16 and 4 grubs killed |
| Brood computer | ahead 3 of 3; 5, 1 and 1 grubs killed | ahead 3 of 3; 7, 4 and 2 grubs killed |

Three seeds is a small sample, so read this only as a direction. The rush arrives a few seconds sooner and with more wind, which helps against an undefended Brood (more grubs killed). Against a wall it still turns back having killed nothing, and with less health per soldier the Clockwork comes out of those games a little worse than before. Design principle 5 (a rush must beat a player who did nothing and lose to a proper defence) still holds.

## The computer

The Clockwork computer (on Normal and Hard) does three things, all in the Clockwork code paths:

- It researches SHIELD WALL at a Movement Works once it has seen at least three enemy shooters (Musketeers, Spitters, Jacks and the like) in the last minute and a half, has four or more Clock Soldiers, and has the cogs and the Tension to spare. Like the Jacks, this needs a Mainspring meshing with the Works.
- It raises a soldier's shield when two or more enemy shooters are within about nine tiles and the soldier is neither chasing nor falling back. It keeps the shield up while at least one shooter is near.
- It lowers the shield when the soldier chases a shooter that is walking away out of its reach, when the soldier is ordered back away from the enemy, or when no shooter is near. One soldier switches at most every two and a half seconds, so the shields do not flicker.

The test checks each of these. In two full computer-against-computer games on Kestrel Rise (Clockwork against Crown, thirteen minutes) it never got to SHIELD WALL: in one the Clockwork computer built its first Mainspring only at about 12 minutes, in the other it fell behind and never built one. The research comes as late as that computer's Tension comes.

## Online and saved games

The stance and its switch are two new synced unit values (`shield_up`, `shield_t`, added to `NetSnapshot.UNIT_PROPS` and the direct readers together), so a friend sees the shields go up, the guard picture and the switch. A friend's SHIELD FORWARD order is sent to the host like the Bulwark's BRACE. Saved games keep raised shields.

## The look

With the shield forward the soldier carries its round shield in front of its body: over the clock-face chest when it faces us, held out ahead edge-on from the side, and with its top showing over the shoulders from behind. At game scale a squad with shields forward reads as a row of round brass shields, a squad without shows its white clock faces. Screenshots in `docs/shots/clock-soldier-shield/`: two rows of eight soldiers facing the eight ways (top row shields forward) standing and walking, at 1x and 3x, and two squads of six side by side (left with shields forward).

These pictures are made in code from the painted strips, by `tools/soldier_guide/shield.py`: the painted shield is cut out of the west-facing idle (the one view where it faces us whole) and pasted in front of the soldier; the shield on its arm is wiped off and the hole filled from the body beside it. It is logged in `docs/art_style_inconsistency.md`.

## What still looks rough

- The shield arm is never redrawn: the shield floats in front without an arm reaching to it.
- Where the old shield was wiped off, the body is filled by smearing nearby pixels; in the down-left view a smeared stub of the arm sticks out on the right.
- From behind (up, up-left, up-right) only the top of the shield shows over the shoulders, so those views read as only slightly different from the plain soldier.
- While it strikes, the soldier plays its normal attack, with the shield back on its arm for the swing.
- The walking legs are the code-built walk's, as before.
- The two command icons are placeholders drawn in code. The owner's `assets/icons/clockwork/ab_shield.png` (the button) and `assets/icons/clockwork/research_shield.png` (the research) will be used as soon as the files are there, with no code change.

## ChatGPT requests

Each request stands alone: attach the listed images and paste the prompt. The guide sheets are made by `tools/soldier_guide/shield.py` in the same layout as the painted sheets (1536 by 1024 pixels, navy background), so a repaint can be imported the way the painted idle and walk were. Save the results as `art/redraws/clock_soldier_shield_{idle,walk}_{east,west}_chatgpt.png`.

### 1. Shield forward, standing, the five east views

Attach: `art/redraws/clock_soldier_shield_idle_east_guide.png` (the code-built guide), `art/redraws/clock_soldier_idle.png` (the soldier's painted idle, same five rows) and `art/redraws/clock_soldier_idle_west_chatgpt.png` (its painted west idle: row 2 shows the round shield facing us whole).

```
I am attaching three images of the same pixel-art character, a brass clockwork soldier with a round red body, a gold cap with a spike, blue shoulder balls, a short golden sword and a round brass shield, on a flat navy background (RGB 0, 22, 48).

Image 1 is a rough IDLE animation sheet built in code: 5 rows x 4 frames. Row 1 faces down (S), row 2 down-right (SE), row 3 right (E), row 4 up-right (NE), row 5 up, away from us (N). In it the soldier holds its shield FORWARD, raised in front of its body as a guard, but the shield was pasted in and floats without an arm.
Image 2 is the same soldier's normal idle in those five directions, painted by you. Use it for the style, colours, proportions and the gentle breathing motion.
Image 3 is the same soldier facing the other way, painted by you; its middle row shows the round shield facing us whole: use it for the shield's look.

Please paint a clean pixel-art sheet with the SAME layout as Image 1: 5 rows x 4 frames, the same sheet size, the same navy background, each figure in the same place in its cell, the feet on the same line in every frame of a row, and the same size as Image 2's figures.

The pose: SHIELD FORWARD, a defensive guard. The sword is ALWAYS in the soldier's RIGHT hand and the shield on its LEFT arm. The left arm is raised and bent so the shield is held in front of the body at chest height, facing where the soldier faces; the sword is held low and ready beside the right hip.
- S (row 1): the shield covers the middle of the chest and most of the clock face; the sword is on the left of the picture, held low.
- SE (row 2): the shield is in front, toward the lower right, covering the front of the body; the sword is on the left of the picture.
- E (row 3): the soldier faces right; the shield is held out ahead of it on the right of the picture, seen from its edge, a narrow oval, gripped by the far arm reaching forward; the sword in the near hand.
- NE (row 4): we see the soldier's back; the shield is held ahead toward the upper right, mostly hidden by the body, its rim showing beyond the right shoulder.
- N (row 5): we see the soldier's back; the shield is held ahead of it, so only its top rim shows above and between the shoulders; the sword is on the right of the picture.
- Keep the gentle 4-frame breathing of Image 2; the shield moves with the body.
- No motion lines, no text, no extra objects, no shadows on the background.
```

### 2. Shield forward, standing, the three west views

Attach: `art/redraws/clock_soldier_shield_idle_west_guide.png` (the code-built guide), `art/redraws/clock_soldier_idle_west_chatgpt.png` (the painted west idle, same three rows) and `art/redraws/clock_soldier_idle.png` (the painted east idle, for the style).

```
I am attaching three images of the same pixel-art character, a brass clockwork soldier with a round red body, a gold cap with a spike, blue shoulder balls, a short golden sword and a round brass shield, on a flat navy background (RGB 0, 22, 48).

Image 1 is a rough IDLE animation sheet built in code: 3 rows x 4 frames. Row 1 faces down-left (SW), row 2 left (W), row 3 up-left (NW). In it the soldier holds its shield FORWARD, raised in front of its body as a guard, but the shield was pasted in and floats without an arm.
Image 2 is the same soldier's normal idle in those three directions, painted by you. Use it for the style, colours, proportions, the shield's look and the gentle breathing motion.
Image 3 is the same soldier's idle in the other five directions, painted by you, for reference.

Please paint a clean pixel-art sheet with the SAME layout as Image 1: 3 rows x 4 frames, the same sheet size, the same navy background, each figure in the same place in its cell, the feet on the same line in every frame of a row, and the same size as Image 2's figures.

The pose: SHIELD FORWARD, a defensive guard. The sword is ALWAYS in the soldier's RIGHT hand and the shield on its LEFT arm. In these three views the shield arm is the NEAR arm and the sword arm the FAR arm. The near arm is raised and bent so the shield is held in front of the body at chest height, facing where the soldier faces; the sword is held low and ready, partly hidden behind the body.
- SW (row 1): the shield is held in front, toward the lower left, covering the middle of the body and most of the clock face; the sword shows on the left of the picture, low.
- W (row 2): the soldier faces left; the shield faces us and is raised forward, a little ahead of the body on the left of the picture, at chest height; the blade shows low beyond it.
- NW (row 3): we see the soldier's back; the shield is held ahead toward the upper left, its rim showing beyond the left shoulder; the sword is on the right of the picture.
- Keep the gentle 4-frame breathing of Image 2; the shield moves with the body.
- Do not move the sword to the near arm. No motion lines, no text, no extra objects, no shadows on the background.
```

### 3. Shield forward, walking, the five east views

Attach: `art/redraws/clock_soldier_shield_walk_east_guide.png` (the code-built guide), `art/redraws/clock_soldier_walk.png` (the soldier's normal walk, same five rows) and `art/redraws/clock_soldier_shield_idle_east_chatgpt.png` (the shield-forward idle from request 1; if it is not painted yet, attach `art/redraws/clock_soldier_idle.png` instead).

```
I am attaching three images of the same pixel-art character, a brass clockwork soldier with a round red body, a gold cap with a spike, blue shoulder balls, a short golden sword and a round brass shield, on a flat navy background (RGB 0, 22, 48).

Image 1 is a rough WALK animation sheet built in code: 5 rows x 6 frames. Row 1 faces down (S), row 2 down-right (SE), row 3 right (E), row 4 up-right (NE), row 5 up, away from us (N). In it the soldier walks with its shield FORWARD, raised in front of its body as a guard, but the shield was pasted in and floats without an arm.
Image 2 is the same soldier's normal walk in those five directions. Use it for the steps: the same 6-frame cycle, the same leg positions in each frame.
Image 3 is the same soldier standing with its shield forward, painted by you. Use it for how the shield and both arms are held.

Please paint a clean pixel-art sheet with the SAME layout as Image 1: 5 rows x 6 frames, the same sheet size, the same navy background, each figure in the same place in its cell, the feet on the same line in every frame of a row, and the same size as the figures in Image 2.

The pose: a slow, careful advance behind the shield. The sword is ALWAYS in the soldier's RIGHT hand and the shield on its LEFT arm, raised in front of the body at chest height as in Image 3, steady while the legs step; the body leans a little forward into the shield and bobs only slightly; the sword is held low and ready.
- S: the shield covers the middle of the chest; the sword on the left of the picture.
- SE: the shield in front toward the lower right; the sword on the left of the picture.
- E: the shield held out ahead on the right of the picture, seen from its edge, gripped by the far arm; the sword in the near hand.
- NE: we see the back; the shield's rim shows beyond the right shoulder.
- N: we see the back; only the shield's top rim shows above the shoulders; the sword on the right of the picture.
- No motion lines, no text, no extra objects, no shadows on the background.
```

### 4. Shield forward, walking, the three west views

Attach: `art/redraws/clock_soldier_shield_walk_west_guide.png` (the code-built guide), `art/redraws/clock_soldier_walk_west.png` (the soldier's normal west walk, same three rows) and `art/redraws/clock_soldier_shield_idle_west_chatgpt.png` (the shield-forward west idle from request 2; if it is not painted yet, attach `art/redraws/clock_soldier_idle_west_chatgpt.png` instead).

```
I am attaching three images of the same pixel-art character, a brass clockwork soldier with a round red body, a gold cap with a spike, blue shoulder balls, a short golden sword and a round brass shield, on a flat navy background (RGB 0, 22, 48).

Image 1 is a rough WALK animation sheet built in code: 3 rows x 6 frames. Row 1 faces down-left (SW), row 2 left (W), row 3 up-left (NW). In it the soldier walks with its shield FORWARD, raised in front of its body as a guard, but the shield was pasted in and floats without an arm.
Image 2 is the same soldier's normal walk in those three directions. Use it for the steps: the same 6-frame cycle, the same leg positions in each frame.
Image 3 is the same soldier standing with its shield forward in those three directions, painted by you. Use it for how the shield and both arms are held.

Please paint a clean pixel-art sheet with the SAME layout as Image 1: 3 rows x 6 frames, the same sheet size, the same navy background, each figure in the same place in its cell, the feet on the same line in every frame of a row, and the same size as the figures in Image 2.

The pose: a slow, careful advance behind the shield. The sword is ALWAYS in the soldier's RIGHT hand and the shield on its LEFT arm. In these views the shield arm is the NEAR arm, raised in front of the body at chest height as in Image 3 and steady while the legs step; the sword arm is the FAR arm, the sword held low and partly hidden behind the body; the body leans a little forward into the shield and bobs only slightly.
- SW: the shield in front toward the lower left, covering the middle of the body; the sword low on the left of the picture.
- W: the shield faces us, raised forward a little ahead of the body on the left of the picture; the blade shows low beyond it.
- NW: we see the back; the shield's rim shows beyond the left shoulder; the sword on the right of the picture.
- Do not move the sword to the near arm. No motion lines, no text, no extra objects, no shadows on the background.
```

## Files

- `scripts/shield_wall.gd`: the stance, its switch, the front damage, the pictures, and the computer's use.
- `scripts/defs.gd`: the Clock Soldier's numbers, `Defs.SHIELD_WALL`, the SHIELD WALL research.
- `scripts/unit.gd`, `scripts/ui/hud.gd`, `scripts/ai.gd`, `scripts/net/net_snapshot.gd`, `scripts/net/net_commands.gd`, `scripts/save_game.gd`, `scripts/cw_art.gd`: the hooks.
- `tools/test_clock_soldier_shield.gd`: the test (base stats, the research, the button, the stance's speed, armour, front and back damage, the switch, online, the computer).
- `tools/measure_clock_soldier.gd`: the fights above. `tools/shot_clock_soldier_shield.gd`: the screenshots.
- `tools/soldier_guide/shield.py`: the code-built pictures and the ChatGPT guides.
