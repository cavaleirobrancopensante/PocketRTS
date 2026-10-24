# ChatGPT prompts 31-34: Labourer walk, the other four directions (s, se, ne, n)

The east test (prompt 30) worked: art/redraws/labourer_walk_east_test.png has a clear alternating gait in the style of the body.
Each request below stands alone and uses 3 references (in `docs/redraw_refs/<id>/`, also in `labourer_walk_directions_refs.zip`):
1. `1_new_east_walk_style_and_leg_timing.png`: the NEW east walk (the style and the leg timing to follow).
2. `2_current_<dir>_walk_for_view_and_timing.png`: the game's CURRENT strip of THIS view (6 frames, labelled): it shows how the body looks from this direction. Its legs (drawn in code) show the timing but their drawing style is thinner; copy the timing, not the leg drawing.
3. `3_man_idle_<dir>.png`: the same man standing in this view (ignore the hoe in his hand: the walk has EMPTY hands).
Save each answer as `art/redraws/labourer_walk_<dir>_v3.png`.

Four prompts, same text, only the DIRECTION block differs. Paste the common text first, then the one direction block, then the layout text.

## Common text (all four)

```
Draw a 6-frame walk cycle of this labourer (the man in the attached images: wide brown hat, red coat with a dark belt, grey trousers, brown boots), EMPTY hands, no tools, no hoe. The first reference is the same man walking in the EAST view, drawn exactly as I want: copy its quality, its style and its leg timing (frame 1 contact, frame 2 down, frame 3 passing, frame 4 contact with the other foot, frame 5 down, frame 6 passing, flowing back into frame 1), but in the view named below. The second reference shows how his body looks in this view (hat, coat, belt, straps, proportions) and the third shows him standing in this view.

Every frame must have visibly different legs, drawn in the SAME pixel style as the body and the first reference (same outline weight, two or three tones of grey on the trousers, brown boots with a dark outline, not thinner or simpler than the torso). Arms swing a little opposite to the legs. The head, hat and face keep the same size and drawing in every frame (the body bobs one pixel up and down: lowest in the 'down' frames, highest in the 'passing' frames). Planted boots stay on the same ground line in the contact and down frames. Frame 6 flows back into frame 1.

WHAT MUST NOT CHANGE: the man (hat, face or back of the head, red coat, belt, straps, grey trousers, brown boots), his size, the style of the body. AVOID: legs that look almost the same in every frame, a limp (one foot getting more frames), a third leg or extra boot, legs of different length, a different outfit or colour, any tool, hoe, sack or keg, extra or missing limbs, any text. Do not copy the enlargement, the labels (such as s1 or e1), the lighter cell boxes or small ground ticks of the references.

Pixel art for a 16th to 18th century European gunpowder RTS. Hard square pixels, NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted shading in two or three tones per colour; a dark near-black outline of one game pixel around the figure; each game pixel drawn as a clean square block of about 6 by 6 sheet pixels.

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground, no cast shadow, no borders. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line near the middle of the image, same size. Landscape image, 1536 by 1024 pixels. Each figure must fit in a box about 230 px wide and 300 px high, at least 20 px of empty navy between neighbouring figures, none touching, overlapping or cut by the image edge.
```

## Direction block, 31: SOUTH (walking toward the viewer, we see his front)

```
VIEW: SOUTH, he walks straight toward the viewer, we see his face, the front of the red coat and both legs from the front, with the slight top-down camera. Legs from the front: in the CONTACT frames one boot is placed forward (lower on the picture, toward us) and the other back (higher on the picture, behind), the feet about 4 to 5 game pixels apart vertically and a few pixels apart sideways; in the DOWN frames the body is lowest and the back leg bends; in the PASSING frames the lifted boot swings past the planted leg and is clearly raised off the ground (its sole visible, the boot higher than the planted one); frames 4 to 6 repeat with the OTHER foot in front/lifted, so the left and right boots swap roles. The shoulders sway a little.
```

## Direction block, 32: SOUTH-EAST (three-quarter front view, he walks toward the lower right)

```
VIEW: SOUTH-EAST, three-quarter view from the front-right, he walks toward the lower-right of the picture: we see his face turned right and down, the front and his left side of the coat, both legs. The first reference (east) is the side view of the same walk: in this view the same leg timing happens with the legs foreshortened: in the contact frames the front boot is placed forward toward the lower right and the back boot behind toward the upper left, clearly apart; in the passing frames one boot is lifted off the ground with the knee forward; frames 4 to 6 swap the feet.
```

## Direction block, 33: NORTH-EAST (three-quarter back view, he walks toward the upper right)

```
VIEW: NORTH-EAST, three-quarter view from the back-right, he walks toward the upper-right of the picture: we see the back of his head and hat, the back and right side of the coat with its crossing straps, both legs from behind. Same leg timing as the first reference, legs foreshortened: in the contact frames the front boot is forward toward the upper right and the back boot behind toward the lower left, clearly apart; in the passing frames one boot is lifted with the heel up; frames 4 to 6 swap the feet.
```

## Direction block, 34: NORTH (walking away, we see his back)

```
VIEW: NORTH, he walks straight away from the viewer, we see the back of his hat and head, the back of the red coat with its crossing straps and both legs from behind. Legs from behind: in the CONTACT frames one boot is placed forward (higher on the picture, away from us) and the other back (lower, nearer to us), a few game pixels apart vertically and sideways; the boot nearer to us shows its sole when it pushes off; in the PASSING frames one boot is clearly lifted with its heel up while the other leg is straight; frames 4 to 6 swap the feet. The shoulders sway a little. Do NOT draw both boots flat side by side in every frame, that is the mistake to avoid.
```

## Import checklist (for me)

- [ ] Save each as `art/redraws/labourer_walk_<dir>_v3.png` (and the east as labourer_walk_east_test.png is already in).
- [ ] New importer tools/import_labourer_walk_v3.py: cut the 6 figures per sheet (1 row), one scale for all five sheets (man as tall as the current labourer), snap the coat reds, feet on row 33, anchor x 21, write walk_<dir>.png (e, se, ne, s, n); then REMOVE tools/import_labourer_gait.py's walk step and the walk_frames rebuild in tools/import_labourer_v2.py from rebuild_art.sh (keep carry and carry_keg until their prompts 08, 09 are run in the same way: same technique, one row per view). Update docs/art_style_inconsistency.md.
