# The Great Winder on its painted legs (branch great-winder-legs, 2026-10-27)

Art and tools only: nothing in scripts/ or assets/ changed, no version bump. Every code edit is logged in
docs/art_style_inconsistency.md ("Great Winder legs pass"). Built by tools/great_winder_guide/anim.py.

## What changed

The stubby legs painted on the body sheet (blue ball, steel collar, brass dome) are cut off in every view, and the
machine now stands on ChatGPT's painted leg (art/redraws/great_winder_leg_chatgpt.png): side legs in E, three-quarter
legs in SE and NE, front legs in S and N. The leg is drawn at 0.46 of its painted size, so its hip ball is about the
size of the old balls and it is about 33 game px from hip to sole, against 15 to 19 before. The body is unchanged and
simply stands higher: the legs are long, clearly separate, and the far side's legs (the same paint, behind the body,
a little darker) show between them.

A planted foot stays flat and still on the ground while the body moves over it: the leg turns about the hip to reach
it, and the little difference in height is taken up by the leg sliding under the hip ball, never by stretching. A
stepping leg uses ChatGPT's painted step poses, foot lifted and leg back (column 2), then swung forward in the air
(column 3), each turned about the hip so the foot travels smoothly from behind to ahead and never dips through the
floor. Feet do not slide: on screen a planted foot moves back at exactly the body's speed, so the game should move the
unit 16 game px per walk loop with 4 legs (24 px with 6; the walk GIFs play at 130 and 110 ms a frame).

WIND and SWEEP stand on the same legs, planted, at the same body height; the new key and the new rollers are as they
were. All three strips share one new cell: 182x107, anchor (91, 104). The walk now has 12 frames (it had 8), so one
leg at a time gets three stepping frames.

## 4 legs or 6

- art/redraws/great_winder_walk_4legs.gif: the default. A slow, heavy creep, one leg at a time (left back, left front,
  right back, right front), the body dipping a pixel each time a foot lands. It reads as a big, deliberate machine,
  and four long legs stay clear of each other in every view.
- art/redraws/great_winder_walk_6legs.gif: a tripod gait, three legs up while three stand. It is quicker and more
  insect-like, but with these longer legs the side and three-quarter views get crowded: six near-and-far legs overlap
  under the body.

The strips (great_winder_walk.png/.gif) are the 4-leg walk. To switch to 6 legs, change `LEGS = 4` to `LEGS = 6` near
the top of the legs section in tools/great_winder_guide/anim.py and run it again. I still recommend 4.

Compare GIF (old on top, new below, on one anchor so the height change shows): art/redraws/great_winder_legs_compare.gif.

## Colour

The leg's red thigh plate is kept painted red, like the body's red bands. Whether the Great Winder's reds become
player colour has not been decided. Note also that the leg's hip and knee balls are painted blue, and the owner's
Clockwork rule says brass and player colour, no blue: whichever way the reds go, the importer's palette step
(tools/cw_palette.py) will need to recolour the leg balls together with the body's blue balls.

## What still looks rough

- The brush housing no longer touches the ground. With the body raised about 15 to 17 game px, the rollers sweep the
  air that far up. A sweeper should reach the floor: either the housing hangs lower (a repaint) or the
  legs get a little shorter (LEG_K in anim.py).
- The lift-off frame is column 2 turned back, which tips the foot up like a kicked boot. ChatGPT's painted lift is
  small (the foot rises about 2 game px), so the code adds a little clearance.
- In S and N the step is depth: the planted foot only slides up and down a few pixels, and the stepping poses are
  ChatGPT's front-view poses, whose feet lean sideways and show their soles, turned back under the hip. N uses the
  front view's paint, so the stepping legs there are seen from the front, not the back.
- The far legs stand only a little behind the near ones in the side views, so near and far legs sometimes read as one
  thick leg at 1x.
- In the 4-leg version the side views lose the painted middle legs, leaving the belly's arch empty where the big
  middle ball was (filled with body paint, but the side pipes that led to it now stop short).
- The legs of the hidden pairs (behind the body in S and N, behind the brush housing in the side views) are placed by
  hand, not painted there.

## ChatGPT requests that would fix the rest

1. A body without legs, brush down to the floor (attach art/redraws/great_winder_dirs.png and
   art/redraws/great_winder_leg_chatgpt.png):

```
Attached: a pixel-art steampunk sweeper machine (the Great Winder) in 5 directions (rows S, SE, E, NE, N; column 1 the
machine, column 2 with its winding arm out) on a navy background, and a sheet of a single long leg for it. Please paint
the machine again, same style, same size, same navy background (0, 22, 48), same 5 rows and 2 columns, but WITHOUT
its short legs: where each leg was, paint only a round blue hip socket on the body's underside, so long legs can be
attached there in code. The body stands about 30 percent of its height higher than before, and the brush housing at
the front hangs lower so its brush rollers would still touch the floor when the long legs stand. Nothing else
changes: same hopper, clock, key, red bands and brass details. No legs, no text, nothing touching.
```

2. The leg's step seen from the front and from behind (attach art/redraws/great_winder_leg_chatgpt.png):

```
Attached: a pixel-art steampunk leg (blue hip ball, brass thigh with a red plate, blue knee ball, brass dome foot) in 3
views (rows: side, three-quarter, front) and 4 poses of one step (columns). Please paint the same leg, same style,
same size, same navy background (0, 22, 48), in 2 rows of 4 poses: row 1 seen from the FRONT, row 2 seen from BEHIND.
The poses: (1) standing, foot flat; (2) foot just lifted off the ground behind, toes still low; (3) foot high in the
air under the hip, knee bent toward the viewer in row 1 and away from the viewer in row 2; (4) foot down again a
little ahead. The foot moves straight toward the viewer (row 1) or straight away (row 2), never to the side, and the
hip ball stays at exactly the same spot in every cell. No text, nothing touching.
```

3. A clearer lift-off in the side view (attach art/redraws/great_winder_leg_chatgpt.png):

```
Attached: a pixel-art steampunk leg in 3 views and 4 poses of one step. Please paint the same leg, same style, same
size, same navy background (0, 22, 48), in the SIDE view only (facing right, like the top row), in 4 poses that fill
the gaps of the step: (1) the leg leaning back, foot flat on the ground behind; (2) the heel just lifted, the foot
tipping forward on its front edge; (3) the knee bent forward, foot lifted clear of the ground under the hip, about a
quarter of the leg's length up; (4) the leg reaching forward, foot level, just above the ground ahead. The hip ball
stays at exactly the same spot in every cell. No text, nothing touching.
```

## Pass 2: back on the ground (branch great-winder-legs-2, 2026-10-27)

The owner's report on the pass above: the legs were too tall and the brushes floated above the ground. Fixed in
tools/great_winder_guide/anim.py (art only, no version bump):

- The ground is back where ChatGPT painted it: each view stands at the height of the stubby legs on the body sheet
  (the mean of its near painted soles), which is where the painting's brush housing touches the ground. The brush
  housing and its rollers now sit on the ground line in every view and frame of WALK, WIND and SWEEP; while sweeping
  the bristles turn at the ground. The body is about 15 to 25 game px lower than in the last pass.
- The leg is drawn smaller (LEG_K 0.46 -> 0.25: about 19 game px from hip to sole when straight) AND crouched: the
  standing leg is cut into hip ball, thigh, shin (knee ball and ankle collar) and foot, and laid on a two-bone IK with
  the knee bent out from the body (S / N: to the side; side and 3/4 views: front legs forward, back legs back; the
  front legs behind the brush housing kneel back so they show behind it). The shin stands about upright over a flat
  foot, so each leg still reads as a jointed leg (thigh, knee, shin, foot), not a stub. In S the hips are set 10
  sheet px (3 game px) lower on the body's underside (N: 2 px), because the painted S view stands taller than these
  legs reach.
- Feet still plant: a planted foot stays still on the ground and the IK takes the body over it (no more sliding the
  leg under the hip ball). Stride and gait are unchanged, so the ground speed is the same (16 game px a loop with 4
  legs, 24 with 6).
- The stepping leg no longer uses ChatGPT's painted step poses (columns 2 and 3 are a tall, straight leg and did not
  fit the crouch): it is the same painted pieces on the IK, the foot lifted 9 sheet px (about 3 game px) and kept level.
- 4 legs stays the default (LEGS in anim.py); 6 still works. The key and the new rollers are unchanged.
- One cell for all three strips: 182x103, anchor (91, 89).

Compare GIF (the last pass on top, the new one below; walk, then sweep): art/redraws/great_winder_legs2_compare.gif.

Still rough: at 1x the legs are small and the far legs can merge with the near ones in the 3/4 views; the swing is
code movement of the standing paint (no painted lift-off). A ChatGPT sheet of the leg crouched (thigh out, knee bent,
shin upright) in the three views would let the stance be painted instead of turned.
