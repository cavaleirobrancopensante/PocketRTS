# The two-armed Pendulum in the game (0.14.36)

Branch `pendulum-v2-game`. The redesigned Pendulum (two arms, nothing hanging between the legs) replaces the old
one-armed art and gets its forward, alternating, cutting attack.

## What changed

**The attack is a cut now.** The first guide swung each arm forward like a punch: the weight led and the blade trailed
under it, flat face first. The new attack (tools/pendulum_v2_guide/cut.py, art/redraws/pendulum_v2_attack.png and .gif)
turns each arm in 3D on a windmill: it winds back and up over its shoulder, comes over the top and chops forward and
down through the space in front, follows through low past the target and settles. The blade is turned on its weight so
the crescent's convex edge always points the way the weight is travelling: forward and up at the top of the wind-up
(at the enemy), down and forward through the chop. Seen from the side it is an overhead-to-low arc in the picture
plane; from the front a diagonal from high on its own side to low across the body; the 3/4 views fall in between. A
faint steel-white smear trails the edge on the slash frames so the cut reads at game size.

The guide sheet keeps two blows, right arm then left. **The hits moved from frames 4 and 8 to frames 4 and 10**: each
blow is now a strip of its own in the game (frames 1-6 and 7-12), starting and ending at rest, so the two no longer
overlap.

**The death** comes from ChatGPT's two sheets. They kept no grid, so the importer finds each row as a band of content,
takes the biggest piece in each column as that frame's figure and gives every other piece (a flying arm, a cog, dust)
to the nearest figure. The pink puff in the SE row's 4th frame is greyed like the dust round it. Each row is scaled so
its standing first frame matches the idle (x1.08 to x1.22), on the same feet line, the case over the anchor. The side
view's roll onto its clock face and every view falling to the right are kept as painted. GIF:
art/redraws/pendulum_v2_death.gif.

**Into the game** (tools/import_tier3.py runs the guide itself and imports its RGBA frames): idle 4, walk 8, attack_r 6,
attack_l 6, death 6 frames in five directions, recoloured by tools/cw_palette.py (blue joints become the player
colour, the blades stay steel, the brass stays), the S idle 82 px tall as before; cell 130 x 110 (the raised arms need
the room); a new card portrait. The old one-strip "attack" files are gone.

**Gameplay.** It attacks forward and its arms cut in turn (Unit.arm = blows so far mod 2, the field the Jack already
streams to online guests, so a guest plays the same arm's strip). Each blow still cuts every enemy on the ground in the
arc in front of it (62 px, 60 degrees either side), never its own side, and a building it swings at.

- Damage: **12 a blow every 1.40 s** (aim 0.35, the chop on the 4th frame at 9 fps; strike 0.29; cooldown 0.76), so 8.6
  a second per enemy caught against the old 22 every 2.59 s (8.5).
- **Light bonus: x1.5** on units tagged "light" (Defs.PENDULUM_SWING "vs_light"; the Crown canister uses the same 1.5).
  That is 18 a blow, 12.9 a second, on Musketeers, Labourers, Raptors and the like. This is a guess to be tested in
  play. The lighter blows lose a little more to armour (7.1 a second against 2 armour, was 7.7), which fits its new
  job as the answer to massed light infantry.
- The "about" text says so, in English, Portuguese and Spanish.

**Tests.** New tools/test_pendulum_v2.gd: strips per arm, arms in turn (right, left, right) with their strips, the chop
on the 4th frame, a blow every ~1.4 s at about the old damage a second, the light unit in front takes the bonus, the
armoured one the plain blow, nothing behind is hit, the arm is in the online snapshot. test_cw_tier3 updated (the arm
strips, the 4th frame); the Pendulum added to the walk audit (it passes the normal floors, no special one needed).
Passing: test_pendulum_v2, test_cw_tier3, test_cw_tier3_ai, test_cw_army, test_cw_lab, test_anim_viewer, test_i18n,
test_unit_walk_audit, test_jack_arms. Screenshots: docs/shots/pendulum-v2/ (tools/shot_pendulum_v2.gd).

## What still looks rough

- The blade is a flat painted crescent turned in code: when the swing plane faces the camera (the hit frames from the
  front) it is squashed and its painted light no longer matches the way it faces. A ChatGPT pass on the wound-up and
  chopping poses, with the blade painted side-on, would fix it.
- Seen from the front, the arm points at the camera as it passes forward: the weight sits big on the shoulder for a
  frame. The chop is run a little further on in the front and back views to hide this, but it still reads more as
  "comes at you" than as a sweep.
- From behind, a cut across the front of the body would be hidden by the case, so the back views slash down past the
  robot's own hip instead. Each view reads, but the back and front blows are not quite the same 3D motion.
- The smear is code-drawn (a plain see-through streak); at game size it is faint.
- The legs are still the old Pendulum's walk machinery turned in code (the shin and foot seam, the turned knee balls).
- In the death, rows are scaled by different amounts (x1.08 to x1.22) so each standing first frame matches its idle;
  the wreck on the ground ends up a little bigger in some directions than others.
- The 1.5 light bonus and the 1.4 s rhythm are first guesses: watch Pendulums against Musketeer lines and Raptor floods.
