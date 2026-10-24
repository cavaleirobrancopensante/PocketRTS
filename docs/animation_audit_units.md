# Unit animation audit (2026-10-24)

Method: every walk strip (and the Officers' melee, idle) of every folder in `assets/units/` rendered
per direction at 3-5x nearest, plus per-frame measurements (height, pixel count, foot line, step
spread, loop-point jump). The west views are the east/south-east/north-east strips mirrored in
`unit.gd` (`DIR_FLIP`), so everything below applies to them too. Labourer was left to the other audit.

Tests: `godot --headless --fixed-fps 30 --script res://tools/test_unit_walk_audit.gd` (ALL PASS).

## Fixed

- **Officer sabre too small** (both `dismounted` and `dismounted_armoured`, melee, all 5 views).
  The designer's blades were 8-10 px slivers; the Armoured Officer's were drawn at sheet size and
  shrank to a broken 1 px line with a detached arc, and frames 1-2 were cut off by the cell's top.
  `tools/import_horse_units.py` now takes the old blade off (Officer) and draws one at the unit's
  own pixel size: 22 px, slightly curved, bright back + shaded edge + dark outline, gold guard,
  same on every frame and view. Officer 3 frames (raised, ready, cut with a swing trail); Armoured
  Officer 4 frames, all on the sheet's one pose that faces the attack (cocked, forward, cut, follow-through;
  the sheet's "sabre over the head" pose is dropped: it does not fit the 36 px cell). Drill strips
  for the Barracks (`drill_dismounted*/melee_e.png`) and the trim masks of the melee strips regenerated.
- **Officer walk popped once a stride**: the sheet's first walk frame is drawn ~10% bigger (head, coat,
  boots) in every view. Dropped: `walk_*` is 8 frames (`art_data.gd`), trim masks regenerated.
- **Foot-soldier cadence**: at `WALK_FPS` 8 the feet slid 2-4 steps' length per stride (Officer 3.6x,
  Armoured Officer 2.5x, Musketeer 1.7x, Guardsman 1.9x, Winder 2.5x, Wind-up Soldier 4x, measured as
  `speed * frames / fps` against twice the drawn step). `unit.gd` `WALK_FPS_ART` gives them 12 fps
  (Arc Thrower, Thresher 10). The strips cannot be fully fixed in code: even at 12 fps the Officer slides ~2.4x.
- `unit.gd`: the Spore Mother's 6 fps attack cadence was overwritten by the 9 fps line below it.

## Drawing-level problems (for redrawing)

Frame numbers are 1-based, left to right.

| Unit / pose | Problem |
| --- | --- |
| Officer `dismounted` melee | the sheet has only two usable raised/ready poses; frame 3 (cut) is the ready pose with a code-drawn blade: a drawn cut pose with the arm swung down would read better |
| Armoured Officer `dismounted_armoured` melee | one body for all 4 frames (the arm never moves); redraw frames 1-4 with a real raise / cut / follow-through, and give the cell headroom (the man is 35 of 36 px tall) |
| Armoured Officer walk_e | frame 1 is 2 px taller and bulkier than 2-7 |
| Officer + Armoured Officer walk, all views | a step is only 10-14 px at 62-66 px/s: legs are too small for the ground speed (skating). Longer strides / a jog cycle needed |
| Officer walk_ne frame 5, walk_se frame 4 | boots/hat 2-3 px off the other frames |
| Musketeer / Guardsman walk_s | 3 frames only (se 4, ne 5, e 6, n 7): the front view is a shuffle; frame counts differ by view so turning mid-stride jumps phase |
| Musketeer walk_e frames 3 and 6, walk_s frame 3 | hat has a green plume/cockade, the rest red/black |
| Musketeer walk_ne frame 4, walk_se frame 4 | 3 px shorter than the others (hat) |
| Pikeman walk_s, walk_se | 2 frames only |
| Pikeman walk_ne frame 2 | two pike shafts drawn (doubled line) |
| Pikeman walk_n | 4 frames, legs nearly identical: the feet do not move |
| Pikeman walk_e frame 4, walk_ne frame 2 | 4-5 px taller (pike tip) than the rest |
| Raptor, Grub | walk (and most poses) exist in the E view only: going up or down the screen they slide sideways-on |
| Dragoon and Armoured Dragoon walk | frame 1 is a different, larger pose in every view (2 px taller, foot line 3-5 px lower in n and s); NE is a copy of E (no NE row in the sheet) |
| Horseman / Cuirassier walk_ne | identical to walk_n (back view reused); walk_s/se frame 1-2 bigger than 3-8 |
| Messenger walk_e | frames 4-5 have twice the pixel count of 1-3 (a second figure / coat flap in the frame) |
| Horse (riderless) walk_e | 4 frames, stiff; walk_s frame 6 and walk_se differ by 3 px in foot line |
| Skywing walk (flying) | 3 frames, walk_s frame 1 has 60% more pixels than 2-3 (wings out) |
| Ornithopter walk_s / walk_se frame 1 | wings frame 40% bigger than the rest, then 2 px shorter |
| Bloater walk_n / walk_se | frames 2-3 jump 4-5 px in foot line (belly bob) |
| Cannon, Mortar, Horse team, Brute, Steam Walker, Spore Mother walk_e | step "spread" measures the wheels/body, so the ground speed match could not be judged by the numbers: look at them in game (Steam Walker body drifts 17 px between frames, Spitter 11 px, Bolt 10 px) |
| Tesla Cart walk | strips are 117 px cells in `art_data` for 70 px cell metadata (width 585 / 5 frames): works, but the metadata is inconsistent |
| All west views | the art is mirrored, so the musket/sabre is in the left hand when walking west, and every asymmetric detail (belt pouch, plume, sabre hip) swaps sides |

## Not changed, by design

Gallopers (Horseman, Cuirassier, Messenger, Dragoons) keep their frame-count-scaled gallop fps; the E
view matches ground speed (0.5-1.0x). Labourer untouched.

## Image-AI redraw sheets imported (art/redraws/)

Importers (documented in their headers, run from tools/rebuild_art.sh after import_horse_units and
before the coat / trim / skin masks): tools/redraw_lib.py (cutting, shrinking, placing),
tools/redraw_rig.py (leg rig: the sheets' contact poses are all one wide stride, so torsos are
used frame by frame and the legs are posed again as a real gait), import_redraw_officers.py,
import_redraw_musketeer.py, import_redraw_creatures.py, import_redraw_mounted.py.

Replaced
- Officer and Armoured Officer melee: 4 frames in every direction (wind-up, swing, cut with the
  bright arc, follow-through), strips 90x48; the sabre is cut from the sheet and redrawn at game
  scale (2 px blade with outline) so it is long and clean. (Officer melee was 3 frames.)
- Officer and Armoured Officer walk: 8 frames (contact, down, passing, contact other foot),
  composed from sheets A and B: torsos per frame from A, front/back leg poses from B, side
  views with the rig. The Armoured walk was 7 frames.
- Musketeer walk: 6 frames in all five directions (front set for s/se/e, back set for ne/n), red
  coat, black hat; the south row's grey-green plume is repainted red.
- Raptor and Grub walk_s / se / ne / n (new, 6 frames; the game only had E and flipped it).
  Palette matched to the old E strip, same height as the old E.
- Dragoon walk_ne / se / e / n (attempt C, 6 frames, a true side-view E and a real NE; the old NE
  was a copy of E and the old E was a three-quarter view).

Kept
- Raptor and Grub walk_e: the sheet's E rows barely move; the old gait is better.
- Cuirassier walk_*: the sheets draw a brown horse trotting nearly in place; all other Cuirassier
  strips have the dark horse and the old gallop is a real one.
- Dragoon walk_s (no S row on the sheets); Armoured Dragoon walk_* (the sheets have no armoured
  Dragoon; its NE is still a copy of E); Horseman.

Still needs redrawing / known flaws
- Officer idle / aim / fire / death still show the old man (white plume, narrower); the new walk
  and melee man is broader. The Musketeer's S plume repaint leaves a few grey pixels on the
  barrel tip in one frame. Officer walk stride is about 10 px a step at 12 fps (feet still slide).
- Raptor / Grub new directions have only subtle leg motion (the sheets' frames differ little).
- Trim masks (vet lace / helmet) found nothing on Armoured Officer walk_e and Musketeer walk_n,
  so a veteran shows no trim in those two strips.
- Raptor E tail / head contact on the sheet means the E row was not used; if it is redrawn,
  import_redraw_creatures.py splits touching figures at the column with the fewest pixels.
