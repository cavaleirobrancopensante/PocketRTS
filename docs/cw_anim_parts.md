# Clockwork animations with ChatGPT's new parts (branch cw-anim-parts, 2026-10-26)

Art and tools only: nothing in scripts/ or assets/ changed, no version bump. Compare GIFs (old on top, new below, both
drawn on one anchor so the size change shows): art/redraws/catapult_parts_compare.gif and
art/redraws/great_winder_parts_compare.gif. Every code edit is logged in docs/art_style_inconsistency.md.

## Spring Catapult (tools/catapult_guide/anim.py, new tools/catapult_guide/cog.py)

What changed. Every wheel is now ChatGPT's painted cog (catapult_wheel_chatgpt.png). cog.py evens its 12 teeth and 8
bolts: each tooth and bolt is lined up on its measured middle and the median of them is laid round at even steps, so
the wheel can turn by whole teeth without a jump. The painting's big light is put back as a fixed light map, so the
highlight stays top-left while the cog turns, and the blue hub ball never turns. Each wheel is that cog turned in code
(3 teeth per 8-frame MOVE loop) and squashed into the wheel's own ellipse in every view. The far wheels in SE, E and NE
turn too: their rim and teeth come off the body and the cog turns behind it. Behind a near wheel's tooth gaps the body
now shows its own paint, reflected inward from just outside the teeth and put in shade, instead of the old flat brown.
N uses the cog's edge-on paint: its tooth bars are evened the same way and roll up the tread.

The S and N throws no longer stretch the beam. Away from the loaded pose the arm is ChatGPT's painted arm: column 2
(straight up) for the swing over the top, and column 4 row 1 (the cup's mouth toward us) for the S follow-through. The
N follow-through uses column 2's cup with the inside of the bowl covered by the bowl's outside paint, so its back is to
us. The beam is column 2's beam tiled one rivet period at a time, so it keeps its own rivets at any length. Columns 3 and
4 rows 2-4 and the bottom cells were not used, as asked. SE, E and NE keep the swing in the picture plane.

Sizes. The game scale is 0.357, 1.5x the Netter's 0.238 (it was 0.26). The new cell is 154x141, anchor (77, 139);
catapult_cup.json was regenerated with it. Measured in pixels the E view is now about 125 px wide (72 tall) against the Netter's
67, so if it reads too big in the game, GS at the top of anim.py is the one number to change. The curled soldier is 8
game px across (the old 11.3 px times 42/59, the new soldier's height). It is coloured like the new Clock Soldier: the
round red case (which reads as the head in the curl) is the team key, pure 255,0,0 lit and 150,0,0 shaded, and its
blue joints and gunmetal are brass taken from the soldier's own brass. Its reds are snapped back to the two key colours
after every shrink, so the team shader finds them in the game-size frames.

What still looks rough.
- The loaded pose (the first and last frames) is still the stretched sheet arm in S and N, and the N loaded pose is
  still built in code (ChatGPT drew that arm nearly upright).
- SE, E and NE still stretch the beam when it stands up; the straight-up paint was not blended in there.
- The far wheels' dark middles are still the old paint and do not turn (only their rim and teeth do); the seam between
  them is soft but visible at 3x.
- In N the edge-on cog is widened about 1.5x to cover the old wheels and has no hub; the tread scroll reads but the
  teeth look a little blocky at 3x.
- The evened bolts are slightly softer than ChatGPT's (the median smooths them).
- The payload is small (8 px); which part of the curl is the head is a guess, and the white clock face was kept.

## Great Winder (tools/great_winder_guide/anim.py)

What changed. WIND: the key at the arm's tip is ChatGPT's painted key head (top of
great_winder_key_rollers_chatgpt.png, row 1: the bow and its neck), rotated so its shaft lies along the arm in every
view, with a 62 px bow (about 19 game px) so it reads at 1x. It turns in 8 painted steps of 45 degrees: face-on, 45,
edge-on, 45 from the other side (column 2 mirrored and re-lit), back face, and again. The arm now comes out in 2 frames,
turns for 8 (frames 2-9 loop while it winds) and goes back in 2. The N arm keeps its hand placement.

SWEEP: the rollers in S and the 3/4 views are painted with ChatGPT's new roller band (the side view's blue band), laid
once across each roller blade and scrolled up its front, 2 stripes a loop, lit by the old painting's light. In E the
roller's painted end cap (the end-on view) turns over the middle of the end-on roller, with the old bristles turning
round it at their painted size.

What still looks rough.
- The new stripes are not coarser than the old ones in pixels: they are 5.5 sheet px apart, as the old were 5. At their
  painted size they blur to a flat blue at 1x, so they are shown 3x (TEX_ZOOM); the scroll reads, but the stripes are
  low contrast (blue on blue).
- The E end cap is small (about 7 game px) and its turn is subtle at 1x.
- The cell grew from 194x95 to 204x107 (anchor 102, 89) because the bigger key reaches further, lower in S. WALK was
  not regenerated (it waits for the leg sheet) and still has the old cell; the next WALK run will put all three on the
  new cell.
- great_winder_dirs_v2_chatgpt.png was not used.

## ChatGPT requests that would fix the rest

1. Coarser, brighter brush bristles (attach art/redraws/great_winder_dirs.png and
   art/redraws/great_winder_key_rollers_chatgpt.png):

```
Attached: a pixel-art steampunk sweeper machine (the Great Winder) on a navy background, and a sheet of its parts where
the bottom rows show its brush roller. Please paint the brush roller again, same style, same navy background
(0, 22, 48), same size as in the parts sheet, but with MUCH COARSER bristles: only 3 or 4 big bristle tufts across the
roller's visible front, each tuft a thick diagonal band about 15 px wide, with light blue or white tips and a dark blue
root, so the stripes are high in contrast. Show the roller from the side (its axis horizontal) in 4 copies in one row,
each turned a quarter of a tuft further than the one before, so the tufts can be seen to roll. No other parts, no text,
nothing touching.
```

2. The N follow-through and the loaded arm seen from behind (attach art/redraws/catapult_dirs.png and
   art/redraws/catapult_arm_poses_chatgpt.png):

```
Attached: a pixel-art steampunk catapult on cog wheels in 5 directions (rows S, SE, E, NE, N) and a sheet of its arm.
Please paint ONLY the catapult's arm (the riveted beam, the blue joint ball and the cup), same style, same scale as the
arm in the attached sheets, on the same navy background (0, 22, 48), in 3 poses side by side, all seen from BEHIND the
machine (the N view, camera above and behind):
1. the arm lying back toward the camera, the cup near us with its open mouth facing up (the loaded pose);
2. the arm straight up;
3. the arm leaning AWAY from the camera after the throw: the cup far away at the top, its mouth facing away, so we see
   the rounded outside (the back) of the bowl and only the far edge of its rim.
The hinge knuckle at the bottom of the beam stays in the same place in all three. No machine, no text, nothing touching.
```

3. The cog wheel at the N view's angle (attach art/redraws/catapult_wheel_chatgpt.png and art/redraws/catapult_dirs.png):

```
Attached: a pixel-art brass cog wheel (face-on and edge-on) and a steampunk catapult on four such wheels in 5
directions. In the bottom row (seen from behind) the wheels are seen almost edge-on but a little from the side, about
one third as wide as they are tall. Please paint the same cog wheel, same style, same 12 even teeth, same navy
background (0, 22, 48), at that angle: as tall as the face-on wheel, about one third as wide, its outer face (with the
blue hub ball) turned slightly toward the camera so a thin sliver of the face and the hub shows on one side and the
tooth tops show down the tread. One wheel only, no text.
```

## Facing fixes (branch catapult-facing, 2026-10-27)

The owner's two reports on the Spring Catapult. Compare GIF (old on top, new below, THROW then MOVE twice):
art/redraws/catapult_facing_compare.gif. tools/catapult_guide/anim.py; outputs catapult_throw.png/.gif (5x12),
catapult_move.png/.gif (5x8) and catapult_cup.json regenerated. The cell grew from 154x141 to 158x141 (anchor 79, 139).

What changed.
- S (front): the wheels are now EDGE-ON. ChatGPT's face-on wheels, and the rear wheels' face-on teeth peeking out
  behind them, are erased off the body; where they covered the ends of the riveted base, the base is filled from its
  own plate further in (the right end mirrors the left). The new wheels are the cog's edge-on paint, evened like N's,
  in N's layout: the front pair at the sides, the rear pair at the base's ends, higher and behind it. The body keeps
  its painted width; the unit's anchor was kept where the old wheels put it. In MOVE the tread rolls down, toward us.
- SE: the near wheels (and the far one) are ellipses 0.72 as wide as tall, not round. The strips of the old round
  wheels left beside them are filled with the body's paint where they lay over the body, and empty where they stood
  out against the navy.
- N (back): from the arm straight up through the follow-through, the cup is ChatGPT's cup seen from below (column 2
  row 3): the rim a thin line at the top, the riveted outside of the bowl toward us, no mouth and no inside. It
  replaces the old trick (the straight-up cup with its mouth painted over). The follow-through now keeps the cup at
  least as high on screen as at vertical (it used to sink back toward the machine, which read as tipping toward us).
  While the arm leans back toward us (loading and winding back) the mouth still faces us, and the loaded pose is
  unchanged.
- NE (also from behind): once the arm is up or past vertical, the same cup-from-below, turned along the beam.
- S was checked: the follow-through still shows the cup's mouth toward us.

What still looks rough.
- The S base's two ends are a repeat of a 7 px strip of plate: at 3x they read as vertical ribs.
- The S crank now stands over the navy (its wheel is gone from under it); it still joins the body through its blue
  balls.
- SE: the fills beside the squashed wheels are soft (a blur of the body's paint), and a few 1-2 px scraps of the old
  wheels' teeth remain at their edges. The squash is one number (SQUASH_34); the cog's light was painted for a face-on
  wheel.
- NE's wheels are still round face-on cogs (not asked; at that angle they should be squashed like SE's: set
  squash=SQUASH_34 on the NE row to try it).
- The cup-from-below is scaled up about 1.4x from a smaller painting, so it is a little softer than the other cups,
  and in NE its rivets turn with it (the light on it turns too).
- The N/NE cup jumps from mouth-toward-us to back-toward-us between two frames (at 100 deg); there is no painted
  in-between.

ChatGPT request that would fix the last two (attach art/redraws/catapult_dirs.png and
art/redraws/catapult_arm_poses_chatgpt.png):

```
Attached: a pixel-art steampunk catapult on cog wheels in 5 directions (rows S, SE, E, NE, N) and a sheet of its arm
(the riveted beam, the blue joint ball and the cup). Please paint ONLY the CUP with its blue joint ball, same style,
same size as the cup in the top row of the arm sheet, on the same navy background (0, 22, 48), seen from BEHIND the
machine (camera above and behind, as in the N row), in 4 poses side by side, the joint ball always at the bottom:
1. the arm straight up: the cup's mouth faces up, we look slightly down into it (a thin crescent of the inside);
2. tipped 20 degrees away from the camera: we see the far rim's top edge and mostly the rounded outside of the bowl;
3. tipped 45 degrees away: no inside at all, the riveted outside of the bowl toward us, the rim a thin line at the top;
4. tipped 70 degrees away: the bowl's underside toward us, a round dome with its rivets in rings, the rim hidden.
Light from the top left, as in the attached sheets. No beam, no machine, no text, nothing touching.
```

### Second pass (branch catapult-facing-2, 2026-10-27)

The owner on the first pass: the S wheels are right, but in NE and N the first frames still showed the cup's open
mouth (the hole), so the arm read as facing us instead of the enemy. Compare GIF (last pass on top, new below, THROW
then MOVE twice): art/redraws/catapult_facing2_compare.gif.

- N and NE now show the BACK of the cup (ChatGPT's cup from below: the riveted outside of the bowl, the rim a thin
  line at the top) in EVERY frame of THROW and MOVE: the loaded pose (frames 0, 1 and 11), the rising frame (2), and
  MOVE's loaded arm. The inside of the cup is never shown there.
- While the arm is cocked back toward us, the cup keeps the tilt it has at N_BACK_T (100 deg) on its joint instead
  of following the beam back: its mouth stays toward the enemy. The arm's positions and timing are unchanged.
- Loaded: the curled soldier sits behind the cup's back, its top half (PEEK 0.5 of its height) showing over the far
  rim, so the cup reads as loaded; in frame 11 it drops in from above behind the rim.
- Release: the flying soldier is drawn BEHIND the back cup while the cup is on screen, so it leaves over the far rim
  (the mouth side, away from us), not in front of the bowl. catapult_cup.json: the N/NE cup middles of the loaded
  and wind-back frames moved (the back cup's middle), the rest are the same; n_fly / ne_fly moved 1-4 px.
- S, SE and E are pixel for pixel as before (checked); so are N/NE frames 5-8. The cell is held at 158x141, anchor
  (79, 139) (KEEP_CELL: a different cell would resample every row).

Still rough: the peeking soldier is small at game scale (about 4 px of it shows); the loaded N cup sits over the
drum's top, as the painted loaded cup did. The cup-from-below is the one painted pose for every angle, so between
the loaded tilt and vertical it does not turn in depth (the ChatGPT request above would give in-between poses).
