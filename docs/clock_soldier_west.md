# Clock Soldier: its own west views (0.14.45)

The owner's report: facing the camera the Clock Soldier held its sword in its right hand, but turned diagonally to the left it swapped the sword to the left hand, and sideways it hid the shield on its back. The cause was that the game drew the three west views (SW, W, NW) as the east ones (SE, E, NE) mirrored, and a mirror moves the sword to the other hand. The rule now: the sword is always in the soldier's RIGHT hand and the shield on its LEFT arm.

## What changed in the game

- A unit that has its own west strip (`assets/units/<kind>/<anim>_<sw|w|nw>.png`) draws it unflipped when it faces SW, W or NW; a unit without one mirrors the east strip as before. This is general: any unit gets its west views by dropping the files in. `Unit._set_anim` picks the strip (`Unit.WEST_OF`, `own_west`), `CwArt.units()` reads the west files when they exist, and the animation viewer shows them unflipped (no `*` on the button).
- Then `anim_dir` is `sw`, `w` or `nw` and `anim_flip` is false. Tables keyed by the five east views (the Tesla coil top, the Winder's crate, the balloon's hand and basket, the bridle, the horse team, the battery pack, the flyers' tilt) read the east twin and mirror it (`view_dir`, `view_entry`, `view_mirror`, `view_mirrored`), so nothing that hangs off a sprite breaks when a unit gets west strips. A table can also carry its own `sw` / `w` / `nw` entry; it is then used as is. Online guests draw through the same code.
- Only the Clock Soldier has west strips today. Its shared canvas grew from 74 x 60 to 78 x 66 (anchor 39, 56) to fit the west wind-up.
- Test: `tools/test_west_views.gd` (the soldier draws its own strip unflipped in all four animations and eight directions; the Jack and a Musketeer still mirror; the table helpers; the viewer). The Clockwork tests, the walk audit, the animation viewer test and the i18n test pass.

## How each west strip was made

- IDLE: ChatGPT's painting, `art/redraws/clock_soldier_idle_west_chatgpt.png` (rows SW, W, NW, four frames). `tools/import_clock_soldier.py` now imports a second, three-row set of sheets. The west sheet was painted 10 to 18% bigger than the east one, so each west row is shrunk until its idle is as tall as its east twin's (SW as SE, W as E, NW as NE; scales 0.234, 0.217 and 0.237 against the east sheet's 0.255). Feet and body are aligned the same way, the same palette is used (all brass but the head cap, which is player colour; the cap is found on every frame), and everything goes on the same cell and anchor.
- WALK, ATTACK, DEATH: built in code from the west idle by `tools/soldier_guide/west.py` (sheets `art/redraws/clock_soldier_{walk,attack,death}_west.png` with GIFs), with the same frame counts and timings as the east strips: walk 6, attack 6 with the hit on the 4th frame, death 7.
  - Walk: the painted legs are cut at the hip and sheared along the forward vector, mirrored from the east row's (like `walk_code.py`). The far leg is darker and goes behind the near one. The body, arms, sword and shield stay as painted, with a 1 to 2 px bob.
  - Attack: in the west views the sword arm is the FAR arm. It is cut out, swung about its shoulder and drawn BEHIND the body, so only what clears the body shows. The hole it leaves is filled from nearby body paint, and the arm is drawn a shade darker. The motion is the matching east row's mirrored: lift, overhead, strike, recover. In W the painting shows only the blade beyond the shield (the arm is hidden), so the arm is the east E idle's sword arm, mirrored and scaled, and the painted blade is taken off the body. The shield stays toward us in W. The overhead pose is tipped back a little in W so the sword does not reach higher than the east ones.
  - Death: the painted figure tips over about its feet to the mirrored side (SW to the right, W and NW to the left), slides back under its spot and lies a little toward the camera, as ChatGPT's east deaths lie. It bounces, and the last two frames are darkened.
- GIFs of all eight directions (S SE E NE N NW W SW) from the game's own strips: `art/redraws/clock_soldier_8dir_{idle,walk,attack,death}.gif` (`tools/clock_soldier_8dir_gif.py`, the cap shown in blue). In-game shots of eight soldiers facing the eight ways, at 1x and 3x, idle, on the strike frame and on a walk frame: `docs/shots/clock-soldier-west/` (`tools/shot_west_views.gd`).

## What still looks rough

- West attack: the swung arm is a cut-out, so the elbow does not bend and the sword keeps its painted angle to the arm. In W the arm is the east painting's, a little different in style from the west painting. In SW and NW the body where the arm was is filled with smeared paint (only a few game pixels).
- West death: nothing comes loose. In the east final (ChatGPT's clean-up) the shield, sword and gears fly off; in the west the whole figure just tips over as one piece. It also falls stiff, without the east final's crumple.
- West walk: the steps are small at game scale (2 to 3 px), as in the code-built east rows.
- E view: the shield is on the far arm and only its rim shows, behind the soldier's back. At game scale it reads as a shield carried on its back, which is what the owner disliked. A repaint is requested below.

Meanwhile the game uses the code-built strips. The sword is in the right hand in every frame.

## ChatGPT requests

Each one stands alone: attach the listed images and paste the prompt.

### 1. West attack clean-up

Attach: `art/redraws/clock_soldier_attack_west.png` (the code-built guide), `art/redraws/clock_soldier_idle_west_chatgpt.png` (your west idle) and `art/redraws/clock_soldier_attack_final.png` (the east attack you cleaned up before).

```
I am attaching three images of the same pixel-art character, a brass clockwork soldier with a round red body, a gold cap with a spike, blue shoulder balls, a short golden sword and a round brass shield, on a flat navy background (RGB 0, 22, 48).

Image 1 is a rough ATTACK animation sheet built in code: 3 rows x 6 frames. Row 1 faces down-left (SW), row 2 faces left (W), row 3 faces up-left (NW). The frames are: 1 rest, 2 lifting the sword, 3 sword overhead, 4 the strike (the hit), 5 and 6 recovering to rest.
Image 2 is the same soldier's idle in those three directions, painted by you. Use it for the style, colours and proportions.
Image 3 is the soldier's attack in the other five directions, cleaned up by you earlier. Match its quality and finish.

Please repaint Image 1 as a clean pixel-art sheet with the SAME layout: 3 rows x 6 frames, the same sheet size, the same navy background, each figure in the same place in its cell, the feet on the same line in every frame of a row, and the same pose in each frame (keep the sword's angle in every frame).

Rules:
- The sword is ALWAYS in the soldier's RIGHT hand and the shield on its LEFT arm. In these three views the sword arm is the FAR arm, so it is partly hidden behind the body. Do not move the sword to the near arm.
- SW: the shield is on the near arm, on the right of the picture; the sword is in the far hand, on the left.
- W: the left side faces us; the shield stays in front, toward us, in every frame; the sword arm swings behind the body and the blade shows beyond it.
- NW: the shield is on the left of the picture, the sword on the right.
- Give the sword arm a real elbow that bends as it lifts and strikes, and paint over the smudged spots on the body where the arm was cut out.
- No motion lines, no text, no extra objects, no shadows on the background.
```

### 2. West death clean-up

Attach: `art/redraws/clock_soldier_death_west.png` (the code-built guide), `art/redraws/clock_soldier_idle_west_chatgpt.png` and `art/redraws/clock_soldier_death_final.png` (the east death you cleaned up before).

```
I am attaching three images of the same pixel-art character, a brass clockwork soldier with a round red body, a gold cap with a spike, blue shoulder balls, a short golden sword and a round brass shield, on a flat navy background (RGB 0, 22, 48).

Image 1 is a rough DEATH animation sheet built in code: 3 rows x 7 frames. Row 1 faces down-left (SW) and falls to the right; row 2 faces left (W) and falls to the left; row 3 faces up-left (NW) and falls to the left. The frames are: 1 standing, 2 a jolt, 3 and 4 tipping over, 5 hitting the ground, 6 a small bounce, 7 lying still.
Image 2 is the same soldier's idle in those three directions, painted by you. Use it for the style, colours and proportions.
Image 3 is the soldier's death in the other five directions, cleaned up by you earlier. Match it: there the shield, the sword, a spring and a few small gears come loose when it hits the ground.

Please repaint Image 1 as a clean pixel-art sheet with the SAME layout: 3 rows x 7 frames, the same sheet size, the same navy background, each figure in the same place in its cell, falling the same way with the same tilt in each frame.

Rules:
- The sword is in the soldier's RIGHT hand and the shield on its LEFT arm until they come loose: SW shield on the right of the picture and sword on the left; W shield in front, toward us; NW shield on the left and sword on the right.
- From frame 5 on, let the shield and the sword come loose and land beside the body, with a spring and two or three small gears, as in Image 3. Let the body crumple a little as it lands instead of falling stiff.
- No motion lines, no text, no shadows on the background.
```

### 3. E idle repaint: the shield must not read as "on its back"

Attach: `art/redraws/clock_soldier_idle.png` (the east idle sheet; row 3 is E) and `art/redraws/clock_soldier_idle_west_chatgpt.png` (row 2 is W, the mirror case done right).

```
I am attaching two sheets of the same pixel-art character, a brass clockwork soldier with a round red body, a gold cap with a spike, blue shoulder balls, a short golden sword and a round brass shield, on a flat navy background (RGB 0, 22, 48).

In Image 1, row 3 shows the soldier facing RIGHT (east): 4 idle frames. Its right side faces us, so the sword is in front, which is correct. But the shield (on its LEFT arm, the far arm) only shows as a rim behind its back, on the left of the picture, so it looks like the shield is carried on its back.
Image 2, row 2, shows the soldier facing LEFT with the shield in front: use it for the style.

Please repaint ONLY row 3 of Image 1 (4 frames, the same cell size and positions, the feet on the same line, the same navy background). Keep the sword in its RIGHT hand, in front, exactly as now. Move the shield: the far (left) arm holds it forward, guarding the front of the body, so its rim and part of its face show in front of the chest, on the RIGHT side of the body (the side it faces), partly hidden by the body and the sword arm. Nothing on its back. Keep the idle's small breathing motion between the 4 frames. No text and no shadows on the background.
```

Once a clean-up comes back, save it as `art/redraws/clock_soldier_{attack,death}_west_final.png` (or the new E idle sheet), point `WEST_SHEETS` (or `SHEETS`) in `tools/import_clock_soldier.py` at it, and rerun `python3 tools/import_clock_soldier.py`. The attack and death are aligned by each row's first frame, so keep the figures where the guide had them.
