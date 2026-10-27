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
