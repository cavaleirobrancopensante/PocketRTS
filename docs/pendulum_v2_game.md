# The two-armed Pendulum in the game (0.14.36)

Branch `pendulum-v2-game`. The redesigned Pendulum (two arms, nothing hanging between the legs) replaces the old
one-armed art and gets its forward, alternating, cutting attack.

## What changed

**The attack is a low sweep** (branch `pendulum-sweep`, the owner's report on the first cut: "the pendulum attack is
overhead, but it shouldn't be, because it is a ground unit that mostly kills Raptors, so it should be sweeping the
ground"). The first guide swung each arm forward like a punch (the blade trailing flat face first); the second was a
windmill chop over the shoulder. Now (tools/pendulum_v2_guide/cut.py, art/redraws/pendulum_v2_attack.png and .gif)
each blow is a SCYTHE stroke at ankle height. The arm turns on a cone round its shoulder (cut.cone_dir: the weight
swung out of the hang by c degrees, at azimuth phi round the shoulder: -90 back, 0 its own side, 90 forward, 150 across
the front), so it moves round at one height instead of up and over: it swings BACK behind its hip (frames 1-2), sweeps
forward past its own side and on in front of its feet (3), lands in front of the feet at the hit (4), follows through
low across the front past the target (5) and settles (6). The knees give (the body dips up to 30 sheet px, 8-9 game
px) and it leans into the blow, so the swung-out weight (a cone lifts it a little) and the blade run just above the
ground, through where Raptors and Labourers stand. The blade turns on its weight so the crescent's convex edge points
along the travel bent forward and down (cut.LEAD_FWD, LEAD_DOWN): it leads the sweep, faces the target at the hit and
dips under the weight towards the ground.

- Side view (E): a low forward arc, the blade near the ground line in front of the feet.
- Front: across the front of the body at the feet's height (in front of the legs, never behind them).
- Back views: the sweep is CUT SHORT beside its own leg (anim.CROSS: NE 80, N 75 degrees) so the weight never shows
  in the gap between the legs from behind (the old pendulum's look); it reads as a swing out, back and forward-away.
- 3/4 views: in between.

The guide sheet keeps two blows, right arm then left; **the hits stay on frames 4 and 10** (each blow a strip of its own
in the game, attack_r = frames 1-6, attack_l = frames 7-12, starting and ending at rest), so the aim and strike timings
in defs.gd are unchanged. The sweep no longer raises anything over the head, so the unit's cell is lower: 130 x 91
(was 130 x 110), anchor (65, 84) (scripts/cw_art.gd SHEETS). Screenshots of the sweep through Raptors, close and at 1x:
docs/shots/pendulum-v2/sweep_*.png (tools/shot_pendulum_sweep.gd; the old chop's shots were removed).

**The death** comes from ChatGPT's two sheets. They kept no grid, so the importer finds each row as a band of content,
takes the biggest piece in each column as that frame's figure and gives every other piece (a flying arm, a cog, dust)
to the nearest figure. The pink puff in the SE row's 4th frame is greyed like the dust round it. Each row is scaled so
its standing first frame matches the idle (x1.08 to x1.22), on the same feet line, the case over the anchor. The side
view's roll onto its clock face and every view falling to the right are kept as painted. GIF:
art/redraws/pendulum_v2_death.gif.

**Into the game** (tools/import_tier3.py runs the guide itself and imports its RGBA frames): idle 4, walk 8, attack_r 6,
attack_l 6, death 6 frames in five directions, recoloured by tools/cw_palette.py (blue joints become the player
colour, the blades stay steel, the brass stays), the S idle 82 px tall as before; cell 130 x 91 (130 x 110 while the
chop raised its arms overhead); a new card portrait. The old one-strip "attack" files are gone.

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

- The blade is a flat painted crescent turned in code: through the sweep it is seen at a slant, squashed (never under
  0.6 of its width) and its painted light no longer matches the way it faces. A ChatGPT pass on the swung-back and
  sweeping poses (blade painted at those angles, low over the ground) would fix it.
- The arm is rigid and hangs from the shoulder, so the weight only reaches the ground because the knees give and the
  body leans: the weight runs at shin height and the blade at the ankles. A longer reach would need longer arms.
- From behind the sweep is cut short beside its own leg (it must never show between the legs); the back views read as
  a swing out and forward-away rather than the full sweep across.
- The smear is code-drawn (a plain see-through streak); at game size it is faint.
- The legs are still the old Pendulum's walk machinery turned in code (the shin and foot seam, the turned knee balls).
- In the death, rows are scaled by different amounts (x1.08 to x1.22) so each standing first frame matches its idle;
  the wreck on the ground ends up a little bigger in some directions than others.
- The 1.5 light bonus and the 1.4 s rhythm are first guesses: watch Pendulums against Musketeer lines and Raptor floods.
