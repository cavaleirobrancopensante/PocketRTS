# Clockwork animation audit (2026-10-27, branch anim-audit-clockwork, 0.14.55)

The owner asked: "Analyse every animation in detail for problems and ways to make them better." This is the Clockwork's
part. Two other machines did the Crown and the Brood.

What was looked at. Every strip of the seven gear-mode units (Winder, Clock Soldier with its west views, Jack, Swift,
Ticking Owl, Pendulum, Netter), the two coming units (Spring Catapult and Great Winder, their sheets in art/redraws), the
ten old units still in the files, and the eight gear-mode buildings.

How. A script measures every frame: tools/anim_audit/measure_clockwork.py. Its numbers are in
docs/shots/anim_audit_clockwork/measure.md and measure.json. It also draws one contact sheet per unit (sheet_<kind>.png:
every strip, 2x, the anchor line in cyan, the foot line in magenta) and per building (sheet_b_<kind>.png). GIFs at game
speed are in docs/shots/anim_audit_clockwork/gifs/: every animation at 1x (all views side by side, west views included),
a few at 3x. I then looked at every sheet by eye, and at the Clock Soldiers in the game (ingame_clock_soldiers_e.png).

Frame numbers below start at 1. "px" means game pixels.

## THE TEN MOST IMPORTANT FINDINGS

Ranked by how much fixing them would help the game, for the effort.

1. **The Jack changes its arm every time it moves.** Standing and shooting, it has two drill launchers. Hopping,
   jumping, dying and shooting up at a flyer, it still has the old claw on its left arm. So every step it takes swaps a
   launcher for a claw and back. It is the most seen Clockwork unit after the Clock Soldier. Needs four ChatGPT sheets
   (prompt A below). Picture: jack_walk_claw.png.
   PARTLY FIXED in 0.14.59: the hop and the jump are now built in code from the two-launcher idle
   (tools/jack_guide/hop_twin.py; fix_jack_hop_twin.gif, fix_jack_jump_twin.gif). A ChatGPT repaint of the hop was
   tried first: four facings were right, but four up-right frames faced down-right and the foot plate drifted up to
   9 px. Still to repaint: the death and the shot up at a flyer (prompt A, used on those two sheets).
2. **The Jack slid about on its spring. FIXED.** Its idle's foot plate wandered up to 7 px from frame to frame (N view)
   and 6 px (SE). The two-launcher strips also stood 3 to 6 px off the anchor, so going from standing to hopping jumped
   it sideways. The importer took the drill tips for the spring. Now every frame stands on the anchor
   (fix_jack_idle.gif, fix_jack_switch_s.gif, fix_jack_switch_n.gif).
3. **The Clock Soldier skates.** Its walk's feet move 1 to 3 px a step, but it covers 41 px per cycle (68 px/s, 6 frames
   at 10 fps). The feet slide about ten times further than they step. It is the main army unit, so this is seen all
   game. Needs a painted walk with real strides (prompt B).
4. **The Clock Soldier facing east carries its shield on its back,** and its overhead frame had no head. The shield
   problem is known (docs/clock_soldier_west.md, request 3). The missing cap on frame 3 of the east attack is new: no
   player colour showed just before the blow. FIXED as far as code can (the cap now peeks out behind the raised arm,
   fix_clock_soldier_attack_e.gif); the frame still needs a repaint (prompt C).
5. **The Clock Aviary boiled. FIXED.** Its four working frames were each painted anew. So the whole tower shimmered:
   2,400 to 3,900 px changed between frames, about a third of the picture. It also changed look when it started or
   stopped work. Now only the doors and the bird move (fix_aviary_work.gif).
6. **The Cog Press changes its wheel when it starts and stops.** Standing, its flywheel is ChatGPT's bright brass wheel
   with a red brake disc. Working, it is a darker wheel turned in code, without the disc
   (cog_press_built_vs_work.png). The Press is the Clockwork's money: it is on screen all game. Needs a painted turning
   wheel (prompt D).
7. **Animations jerk because of the 15 Hz animation tick.** Units animate at most 15 times a second. Strips that play at
   9, 10 or 14 frames a second then hold their frames unevenly: one frame for 66 ms, the next for 133 ms. Attacks (9
   fps), the Clock Soldier's walk (10), the Jack's hop (9), the Swift (10) and the Netter's trot (14) all stutter a
   little. The Winder does not: it already uses whole ticks (WINDER_BEAT). Not changed here, because it is shared code
   for all three factions. Suggestion: give still strips rates of 15, 7.5 or 5 fps, or tick visible units at 30 Hz as
   the Labourer already does.
8. **The coming units will not take the player's colour.** The Spring Catapult paints its red bands in 20 or more shades
   of red that are not the two team keys (up to 226 such px a frame in N). The Great Winder has about 100 a frame. In
   the game those stay red for every player. Their importer must snap them to the keys, as tools/cw_palette.py does for
   the others.
9. **The Netter stands dead still.** Its idle is one frame (the walk's first). Its recoil is also very small: the barrel
   moves 2 to 3 px. A breathing idle and a stronger kick would make it read (section "new animations").
10. **The Clock Soldier's west attack and death are rough.** Known (docs/clock_soldier_west.md, requests 1 and 2). The
    west deaths also end 20 to 30% bigger on the ground than the east ones, and nothing flies off.

Other technical fixes made: stray specks (1 to 3 px islands) taken out of the Clock Soldier's walk and SHIELD FORWARD
strips and the Pendulum's swings (fix_specks_clock_soldier.gif, fix_specks_pendulum.gif).

## What was changed in the game (0.14.55)

- tools/import_springer.py: after the shrink, every idle frame, and the first frame of each attack strip (the recoil kept),
  is moved sideways so its foot plate's middle sits on the anchor column (align_plate). The drill tips it prints move
  with it. scripts/defs.gd JACK_SHOT "tips" updated to the new numbers (S, SE, NE, N; E did not move). The importer was
  run: walk, jump, raised arm and death came out pixel for pixel the same; idle and the attacks changed.
- tools/import_clock_soldier.py: lend_cap. A frame with no team colour gets the cap of the frame before it, put behind
  it. Only the east attack's frame 3 needed it (11 px).
- tools/anim_audit/fix_clockwork.py (new, safe to run again): the speck clean-up, and the Clock Aviary's work frames
  rebuilt on the built picture (doors and bird kept from each frame). Run it again after tools/soldier_guide/shield.py or
  tools/import_tier3.py, which make the strips it cleans.
- Tests run and passing: test_unit_walk_audit, test_west_views, test_anim_viewer, test_building_anim, test_springer_arms,
  test_cw_air, test_cw_tier2, test_clock_soldier_shield.

Nothing about balance changed. Version 0.14.55, patch notes in English, Portuguese and Spanish.

## How the units play (for reference)

Unit.\_animate runs at 15 Hz. Walks play at WALK_FPS_ART times the speed ratio. Idle plays at 2 fps (flyers at 0.85 times
their flap). Attacks play at 9 fps and do not loop. Deaths play at 7 fps. The blow lands `aim` seconds after the attack
strip starts; then the strip keeps playing for the strike time (0.35 s, or the unit's own).

| Unit | Walk | Speed | Ground per walk cycle | Attack: blow lands on | Check |
| --- | --- | --- | --- | --- | --- |
| Winder | 4 frames on a beat (0.4 s) | 74 | 30 px; step 8 px | frame 3 (the thrust), 0.25 s | good |
| Clock Soldier | 6 at 10 fps | 68 | 41 px; step 1 to 3 px | frame 4 (the strike), 0.33 s | good timing, feet skate |
| Jack | 6 at 9 fps (hop) | 70 | 47 px in one hop | frame 2 (the kick), 0.11 s | good |
| Pendulum | 8 at 7.2 fps | 46 | 51 px; step 16 px | frame 4 (the sweep), 0.35 s | good, slide 1.6x |
| Netter | 8 at 14 fps | 54 | 31 px; step 8 px | frame 2 (net leaves), 0.11 s | slide 1.9x |
| Swift, Owl | the flap loop | fly | | frame 3 (peck, swoop) | good |

---

## Winder (worker)

Strips: idle 2, walk 4, wind 4, repair 4 (the same file as wind), attack 4, death 6. All five views, west mirrored.

Good. The clockwork beat (held frames that snap on, WINDER_BEAT) is the best idea in the faction: it reads as a
clockwork toy. The death runs down slower and slower and ends in a heap of gears. The team colour sits on the shoulder
lamps and the heart in every frame. No specks except the death's flying gears (meant).

Problems.
- Feet slide a little: about twice the step (30 px a cycle against two 8 px steps).
- The attack strip is 60 px tall in a 49 px cell. It works (the game keeps the feet put for taller strips), but the
  frames jump 6 to 12 px in height as the key is raised.
- N attack, frame 3: the key is thrust straight up out of the head. It reads as a spike, not a blow toward the enemy.
- Idle is two frames a second apart. The hands on his clock face tick, which is good, but nothing else moves.

Make it better.
- (c) An idle fidget: every few seconds he winds his own key one quarter turn (the wind strip's frames 1 and 2, held on
  the beat). Code only: play two wind frames in the idle now and then.

## Clock Soldier

Strips: idle 4, walk 6, attack 6, death 7, guard 4, guard_walk 6, in all eight views (its own west strips).

Good. The attack timing is right: lift, overhead, strike on frame 4 exactly when the blow lands (0.33 s), recover. The
east death (ChatGPT's clean-up) is the best death in the faction: shield, sword, a spring and gears fly off. The sword
stays in the right hand in every view since 0.14.47.

Problems.
- Walk: the feet move 1 to 3 px a step (in E the foot spread changes by 1 px). It covers 41 px a cycle. The feet skate.
  The legs look busy but go nowhere (clock_soldier_walk_3x.gif).
- E view: the shield shows only as a rim behind its back (ingame_clock_soldiers_e.png). Known.
- E attack, frame 3 (overhead): the painting dropped the head. Fixed in part (above). The body in that frame is also
  narrower, with a gap where the shield arm is (clock_soldier_attack_e_overhead.png).
- Switching idle and attack pops 4 px in height in S and N: the attack's first frame is a little smaller (38 against 42
  px tall). Small.
- West attack: the sword arm is a cut-out that does not bend. West death: falls stiff, nothing comes loose, and the body
  on the ground is bigger than the east one. Known.
- Death S and SE fall to the same side (left), so a squad dying facing down always falls the same way. Fine for now.

Make it better.
- (b) Prompt B (walk), prompt C (E attack frame 3); docs/clock_soldier_west.md requests 1 to 3.
- (c) A hit flinch (2 frames: the body knocked back 2 px, the shield up). It is the unit that takes most blows. It would
  need a "hit" strip and Unit to play it for 0.15 s on take_damage when it is not attacking.

## Jack

Strips: idle 4, walk (hop) 6, jump 8, attack_r 6, attack_l 6, attack_up 6, death 7. Five views, west mirrored.

Good. The two launchers fire in turn, each screw from its own drill tip. The hop is lively. The raised arm aims at
flyers.

Problems.
- The claw (finding 1). Idle and the two ground attacks have two launchers. Walk, jump, attack_up and death have one
  launcher and a claw.
- The foot plate wandered (finding 2). Fixed. Before: plate middle per idle frame S 57, 59, 59.5, 59; SE 54.5, 60.5,
  54.5, 54; N 59.5, 54.5, 53, 60 (the anchor is 53.5). After: all within 1 px of 53.5.
- Idle: the body squashes 8 px on frame 2 (S) every 2 seconds. On a spring that can be right, but it is a big jolt for
  a unit standing still. A softer bob (3 to 4 px) would read better.
- Idle height differs a lot by view (S 59 px, N 49 px). The N view is drawn smaller. Turning round shrinks it.
- The ground attacks end on the same frame they start (frame 6 = frame 1). Fine.

Make it better.
- (b) Prompt A (four sheets).
- (c) A landing squash after the jump is already there. An idle where the spring wobbles after it stops hopping would add
  a lot of life: play two hop frames (2 and 6) once when it comes to rest.

## Swift (cuckoo)

Strips: idle = walk (the same flap loop, 4 frames), attack 6, death 6.

Good. The flap reads at game size. The peck lands on the stab (frame 3). The death tumbles, scatters feathers and
lies flat with the wings spread.

Problems.
- The attack's first frame has the wings level; the flap loop starts with them up. Starting an attack snaps the wings.
  The body is steady (team colour centre within 1 px).
- The silhouette height changes 7 to 11 px through the flap. Normal for wings.

Make it better.
- Start the attack strip from the flap frame nearest its first frame (code: pick the attack's first frame by the flap
  phase). Small.

## Ticking Owl

Strips: idle = walk (flap, 4), attack (swoop) 6, bomb 6, death 6.

Good. The bomb hangs under it and falls on the drop. The death drops the bomb and lands flat.

Problems.
- Idle height by view: S 54, SE 50, E 48, NE 49, N 55 px. The side views are drawn smaller.
- The SE flap loop drifts down 3 px over its four frames, then snaps back up: a little hitch in the loop.
- Attack and bomb end on their first frame. Fine.

## Pendulum

Strips: idle 4 (a sway: frames 1, 2, 1, 4), walk 8, attack_r 6, attack_l 6, death 6. Five views, west mirrored.

Good. The long strides fit its speed best of the faction (slide 1.6x). The swings have a real wind-up and a low sweep,
and the blow lands on the sweep frame. The death crashes into a cloud of dust with parts flying. The team colour
covers the whole case (776 px in S), so it reads as the player's from far away.

Problems.
- A few 1 px specks in two swing frames. Fixed.
- E walk frames 3 and 7 are very thin (the legs pass): at 1x the unit flickers between wide and thin. It is a side view;
  it is fine, but a softer passing pose would help.

## Netter

Strips: idle 1, walk 8 (a trot), attack (recoil) 6, death 5.

Good. The trot is quick and busy, right for stubby legs. The death throws the cannon off.

Problems.
- Idle is one frame (finding 9).
- The recoil: the barrel moves 2 to 3 px. At 1x the shot hardly shows; the net itself carries it.
- The walk at 14 fps is above what a 15 Hz tick can show evenly (finding 7).

Make it better (c).
- An idle: the spring cannon breathing, 2 to 4 frames, the body 1 px up and down and the barrel's spring winding.
  It could be built in code like its walk (tools/netter_guide/).
- A stronger recoil: the whole body kicked back 3 to 4 px on frame 2 and the barrel 5 px.

## Spring Catapult (coming)

Sheets: art/redraws/catapult_throw.png (5 x 12, cell 158 x 141) and catapult_move.png (5 x 8).

Good. The throw has a clear wind-up, a fast release and a follow-through. The cogs turn.

Problems.
- Team colour: up to 226 off-key red px a frame (finding 8). Snap at import.
- The payload is about 8 px; at 1x it is a dot. The throw reads by the arm, not the soldier.

## Great Winder (coming)

Sheets: great_winder_walk.png (5 x 12, cell 182 x 103), wind (5 x 12), sweep (5 x 8).

Problems.
- Team colour as above (about 100 off-key red px a frame).
- WIND: frames 8, 9 and 10 are the same as 4, 5 and 6 (the key turns through the same pictures). Fine for a loop, but
  the loop could be 4 frames shorter.
- The legs at 1x move little (great_winder_walk_1x.gif): the brush housing on the ground hides them.

## Old roster (retired in gear mode)

gearknight, bolt, steam_walker, stormcaller, tesla_cart, ornithopter, arc_thrower, thresher, bulwark and windup_soldier
are not in the live game (Defs.CW_NEW_UNITS; Defs.retired). They stay for the shelved Line mode and some tests. Their
numbers are in measure.md. Two things to know if the Line ever comes back: the Tesla Cart's strips are 117 px cells while
art_data says 70 (its frame counts there are also wrong, 3 against 5), and the Stormcaller's cast has 14 to 23%
half-transparent fringe. Not worth fixing now.

## Buildings

The work loops play while a building works. Each frame replaces the built picture. So a work frame that differs from
the built one pops when it starts and stops.

| Building | Work loop | Verdict |
| --- | --- | --- |
| Clocktower | none | the hall never moves. Its clock hands could turn (new animation) |
| Cog Press | 8 frames, 0.11 s | the wheel changes look (finding 6); the slam frames 4 and 5 change the whole press (an impact flash), fine |
| Mainspring | 8, 0.11 s | cranks and spring turn well; frames 7 and 8 shake the WHOLE building, base too, so it slides on the ground. Shake only the top. A 3 px speck at the left crank is the crank, meant |
| Escapement | 24, 0.125 s | very good: a tick every 4 frames, and frame 23 is the built picture, so no pop |
| Movement Works | 8, 0.12 s | good: only the roof key and the little figure in the door move |
| Clock Aviary | 4, 0.15 s | boiled; FIXED |
| Regulator | 8, 0.15 s | very good: only the pendulum swings, frame 1 is the built picture |
| Ratchet Turret | head in 5 views | good; its head is drawn apart and turns in 45 degree steps |

Construction, damaged and destroyed pictures all stand on the same ground line as the built one (within 1 px). The
Clocktower's damaged picture and the others' smoke have small islands: smoke wisps and falling debris, meant.

The gear rings turn every frame, meshed exactly (scripts/gear.gd mesh_phase); nothing to fix.

---

## ChatGPT prompts (b)

Each prompt stands alone. Attach the listed images in order, then paste the text. Save the answer where it says.
Every answer: one PNG, 1536 x 1024, flat navy background RGB (0, 22, 48), rows top to bottom = facing down (S),
down-right (SE), right (E), up-right (NE), up (N), frames left to right, at least 3 px of navy between figures.

### Prompt A: the Jack's hop with two launchers

Attach: art/redraws/jack_hop.png (the hop to copy, clawed), art/redraws/jack_idle_twin_chatgpt.png (the two-launcher
Jack you painted).

```
I am attaching two pixel-art sheets of the same robot, the JACK: a red round body with a clock face, a brass top, arms
of brass segments, standing on a blue-steel coil spring over a round brass foot plate, on a flat navy background
(RGB 0, 22, 48).

Image 1 is its HOP animation: 5 rows x 6 frames. Row 1 faces down, row 2 down-right, row 3 right, row 4 up-right,
row 5 up. In every frame its RIGHT arm ends in a drill launcher but its LEFT arm ends in a claw.
Image 2 is the same robot standing, painted by you, with BOTH arms ending in drill launchers.

Please repaint Image 1 with the SAME layout (5 rows x 6 frames, the same sheet size, each figure in the same place in
its cell, the spring squashing and stretching and the body rising and falling exactly as in Image 1), but with BOTH
arms ending in drill launchers like Image 2: no claw anywhere. Keep the style, colours and size of Image 2.
The foot plate stays in the same spot in every frame of a row except where the hop lifts it.
No text, no shadows, no ground, nothing touching.
```

Save as art/redraws/jack_hop_twin_chatgpt.png. In tools/import_springer.py point SHEETS["walk"] at it (5 rows, 6 columns,
"foot" alignment, since a painted sheet is not on an exact grid), run python3 tools/import_springer.py and
python3 tools/anim_audit/measure_clockwork.py. Repeat the same prompt for jack_jump.png (5 x 8, name
jack_jump_twin_chatgpt.png), jack_death_final.png (5 x 7, the arms still come off as they do now) and
art/redraws/jack_attack_up_body.png (5 x 6: the raised arm stays a launcher, the other arm becomes a launcher too).

### Prompt B: the Clock Soldier's walk with real steps

Attach: art/redraws/clock_soldier_idle.png (its idle, the style), art/redraws/clock_soldier_walk_mix.png (the walk now),
art/redraws/clock_soldier_attack_final.png (for the style of the cleaned-up sheets).

```
I am attaching three pixel-art sheets of the same small clockwork soldier: a round red body with a clock face, a gold
cap with a spike, blue shoulder balls, short brass legs with round feet, a short golden sword in its RIGHT hand and a
round brass shield on its LEFT arm, on a flat navy background (RGB 0, 22, 48). Rows: 1 faces down, 2 down-right,
3 right, 4 up-right, 5 up.

Image 2 is its WALK, 5 rows x 6 frames. The problem: the feet hardly move (1 to 3 pixels at game size), so in the game
the soldier slides across the ground.

Please paint a new WALK, 5 rows x 6 frames, same sheet size, each figure in the same place in its cell and as big as in
Image 1. Make it a brisk march with REAL steps: in the side view (row 3) the front foot reaches about a third of the
body's width ahead and the back foot as far behind; frames 1 and 4 are the widest steps (left foot forward, then right
foot forward), frames 2-3 and 5-6 pass the legs. The body bobs one or two pixels up on the passing frames. In rows 1 and
5 the feet lift in turn. The sword stays in the RIGHT hand and the shield on the LEFT arm in every frame; the shield is
held in front of the body. Style and colours as Image 1 and Image 3.
No text, no motion lines, no shadows, nothing touching.
```

Save as art/redraws/clock_soldier_walk_chatgpt.png. In tools/import_clock_soldier.py set SHEETS["walk"] to it
(6 columns, False), run the importer, then python3 tools/anim_audit/fix_clockwork.py. Then lower the Clock Soldier's
WALK_FPS_ART (scripts/unit.gd) until the step matches the ground: 68 px/s over two steps of the new length.

### Prompt C: the Clock Soldier's overhead frame, facing right

Attach: art/redraws/clock_soldier_attack_final.png.

```
This is a pixel-art ATTACK sheet of a small clockwork soldier, 5 rows x 6 frames, on a flat navy background
(RGB 0, 22, 48). Row 3 faces right. In row 3, frame 3 (the sword raised overhead) the soldier has lost its head: the
gold cap with the spike is missing and the raised arm stands where the head should be.

Please repaint ONLY row 3, frame 3: the same pose (the sword raised straight up over the head, the same angle), but with
the gold cap and spike on top of the body exactly where they are in frames 2 and 4 of the same row, the raised arm in
front of the head, and the round body as full as in frame 2. Keep the whole sheet otherwise unchanged: same size, same
places, same colours. No text.
```

Save over art/redraws/clock_soldier_attack_final.png (keep a copy) and run python3 tools/import_clock_soldier.py.

### Prompt D: the Cog Press's turning flywheel

Attach: assets/buildings/cog_press_built.png (the press with ChatGPT's painted wheel), art/redraws/cog_press_work_v2.png
(the working loop built in code).

```
I am attaching two pictures of the same pixel-art steampunk building, the COG PRESS, on a transparent or navy
background. Image 1 is the building standing still: on its right side a big brass flywheel with spokes, with a red
brake disc behind it. Image 2 is a sheet of its working animation made in code: the wheel turns, but it was redrawn
darker and lost its red disc.

Please paint ONLY the flywheel of Image 1, alone, 8 times in one row on a flat navy background (RGB 0, 22, 48): the same
size, the same angle (seen from the side at the building's angle, an upright ellipse), the same bright brass and the red
brake disc behind it. Each copy turned one eighth of the way between two spokes further than the one before, so the 8
copies loop smoothly. Keep the light on the same side in every copy (top left). No building, no text, nothing touching.
```

Save as art/redraws/cog_press_wheel_turn_chatgpt.png. The wheel then goes into the work frames at the built picture's
wheel position (tools/press_anim/), so the built and working wheels are the same paint.

## New animations that would add the most life (c)

1. **Clocktower clock hands** (a work loop like the Regulator's): the minute hand moves one step every few seconds.
   The hall is the only Clockwork building that never moves. Needs: 8 frames of the clock face (code can turn painted
   hands, as the Regulator's pendulum), and Building to play them always (like the Regulator, regulator_dt).
2. **Netter idle**, 2 to 4 frames (see the Netter).
3. **Clock Soldier hit flinch**, 2 frames, all eight views (see the Clock Soldier).
4. **Winder idle fidget**: two wind frames now and then. Code only.
5. **Victory wind-up**: when a fight ends near them, Clockwork units wind their own key once (the Winder's wind strip
   exists; the Clock Soldier and Jack would need 4 frames each). A strong faction signature: a toy army winding itself.
6. **Jack settling after a hop**: two hop frames once when it stops. Code only.
