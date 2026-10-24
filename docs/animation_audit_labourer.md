# Crown Labourer animation audit

Tools: `python3 tools/labourer_contact.py [DIR]` writes one contact sheet per pose (every
direction, every frame, plus the west views mirrored the way `scripts/unit.gd` draws them, at
4x nearest, ground line marked) and prints each frame's bounding box and feet span.
`tools/test_labourer_anim.gd` (headless) covers what was fixed in code.

How the game plays him: strips `assets/units/labourer/<pose>_<dir>.png`, 42x35 cells, anchor
(21, 33), dirs s, se, e, ne, n. West views are the SAME strips mirrored (`DIR_FLIP` in
`unit.gd`: sw = se, w = e, nw = ne flipped by `sprite.scale.x = -1`; the anchor is the cell
centre so no pixel moves). A mirrored picture swaps hands: the tool in his right hand faces
west in his left. That is a limit of mirroring, not a bug; separate west drawings would be
needed to change it.

## What was wrong in code (fixed)

| Problem | Fix |
| --- | --- |
| Feet slid on the ground. The walk played at a fixed 8 fps (about 1.6 strides a second) while he moves 74 px/s: 46 px of ground per stride against a drawn step of about 13 px. | His walk, carry and keg-carry frames now follow the distance covered (`LAB_STRIDE`: 26 / 24 / 24 px per full strip), so a planted foot stays planted at any speed, on roads, slopes and when he slows in a crowd. |
| Animation ticked only 15 times a second, so frames lasted an uneven 1 or 2 ticks and a 5-frame cycle judders. | A walking or hammering labourer ticks at 30 Hz. |
| Walk <-> idle flicker around the 10 px/s line when crowds push him, each switch resetting the pose to frame 0. | 0.18 s hold in the walk when his speed dips under the line. |
| The view (s / se / e ...) flipped back and forth while his path wobbled around a 22.5 degree line, swapping between two drawings that never line up. | The view only changes once he has turned 7 degrees past the edge (`_lab_view`). |
| Hammering ran 4 equal frames at 6 fps (0.67 s a swing): no pause on the raise, no weight on the strike, and the 2 s hammer clip (blows at 0.46, 0.87 and 1.30 s) never matched. | `BUILD_SWING`: a held raised hammer, a quick drop, a held strike, a slower recovery, 0.40 s a swing (5 swings = the 2.0 s clip). Each time the clip starts, the swing is re-phased so its first big blow lands on a strike (`lab_build_lock`). Frame order is the drawn loop re-started at the raised hammer (s: 2,3,0,1; se: 2,3,0,1; e: 1,2,3,0; ne: 0,1,2,1; n: 2,3,0,1). Repairing, loading and non-farm manning share it. |
| Keg idle: the N view has 2 frames, the others 4, both at 3 fps, so N breathed twice as fast. | One breath per 1.3 s whatever the frame count. |

Checked and fine: every pose has all five views, frame sizes match `art_data.gd`, the feet row is
y 32-33 in every frame (no anchor drift; frame to frame x drift of the body is at most 3 px
and is the drawn stride), no frame is empty or out of its cell, frame order of walk/carry/mine
/bury/death reads as one loop (checked by frame-to-frame pixel distance), the west mirror
sits on the same ground point.

## What the drawing itself gets wrong (needs redrawing; code cannot fix it)

1. **Hammering, `build_s`, `build_se`, `build_e`, `build_n` (frames 0-3 each).** The arm and
   hammer move 2-3 px between frames (measured on the metal pixels: s 14.8..16.9, se 11.2..15.2,
   e 13.3..14.9, n 10.0..12.7 rows), the hammer is a few pixels beside the stake and hidden by
   the fist. There is no raised hammer at all. This is the real reason the hammering "is not
   good": redraw 4 frames per view with the hammer clearly overhead in frame 0 (raise), halfway in
   frame 1, on the stake in frame 2 (strike, the code holds this one and lands the sound on it),
   and lifting in frame 3. Keep the body still (the importer `tools/import_build_still.py`
   already pins it). Keep the frame order raise, drop, strike, recover and the cell and anchor;
   then update `BUILD_SWING` and `STRIKE_FRAME` in the test if the strike frame moves.
2. **`build_ne` (3 frames) is a different man in a different pose**: he stands upright with the
   hammer overhead and there is no stake, while s / se / e / n crouch beside a stake. Facing
   north-east he stands up, facing east he crouches. Redraw crouching at the stake with a
   4-frame swing like the others (the raised-hammer drawing here is the best of the set and can
   be the model for frame 0).
3. **Keg man is a different man** (`carry_keg_*`, `idle_keg_*`, `bury_*`, `death_keg_*`, all
   dirs). Source `art/crown/labourer_keg.png`: red cap, brown shirt and trousers, red sash; the
   labourer is a felt-hat man in a red coat and grey trousers. When he picks up a keg his
   clothes change. Redraw in the labourer's outfit (felt hat, red coat), same poses.
4. **`carry_keg_*` walk: almost no leg movement** (feet span 17-24 px in every frame, the keg
   hides the legs). With the distance-driven stride he still shuffles. Frames 4-5 of `carry_keg_e`
   also jump 2 px to the left of 0-3 (body x centre 21.1 against 23.3): redraw those two, or the
   cycle visibly hitches at the loop point.
5. **`idle_keg_n` has only 2 frames** (the source sheet's back-view idle was two small figures
   at another scale): redraw 4 frames like the other views.
6. **`idle_ne`, both frames: a different stance.** He holds the hoe raised across his body (it
   reaches x 38-39, 6 px past every other idle), where the other views hold it low at his side.
   Selecting him facing NE shows a different pose. Redraw with the hoe low.
7. **5-frame walk and carry cycles are lopsided** (`walk_*`, `carry_*`): an odd number of frames
   gives the left foot 2 frames and the right foot 3, so the gait limps slightly. Redraw as 6 or
   8 frames (the import and `LAB_STRIDE` code take any count).
8. **`mine_*` frame 2 (the strike) is a squat with debris, far lower than frames 0-1** (top row
   12-14 against 2-5), and the swing has no recovery frame: the pick teleports from the ground to
   overhead. One in-between frame per view would fix it.
9. **`bury_*`** is the same keg man (point 3): redraw with the rest. Frame 5 (he rises from
   the earth) is 4 px taller than frame 4 in a single step, which reads as a hop.
10. Gold sack (`carry_*`) is drawn on his back in every view, but when he stops with gold
    (`idle`), the game draws a small code-made yellow dot at a fixed spot. It never matches the
    view: an `idle_carry` set (idle with the sack) would fix it.
