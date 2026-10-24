# ChatGPT prompt 30 (test): Labourer walk, EAST view only, with a real gait

A one-direction test: if ChatGPT gets the legs right on one row, the other four directions follow.
Stands alone. Attach exactly 3 images, in this order (all in `docs/redraw_refs/30_labourer_walk_east_test/`):

1. `1_current_east_walk_legs_timing.png`: the game's CURRENT east walk, 6 frames (e1 to e6). The legs here were drawn in code and show the TIMING I want (which foot is ahead, where the lifted foot is in each frame), but their drawing style does not match the body. Copy the leg timing, NOT the leg drawing style.
2. `2_style_first_chatgpt_east_row.png`: an earlier drawing of the same man by you: this is the STYLE I want (body, hat, face, red coat, boots, outline weight). Its problem: the legs barely change from frame to frame, so there is no walking.
3. `3_man_idle_east.png`: the same man standing, east view, for proportions and clothes.

Save the answer as `art/redraws/labourer_walk_east_test.png`.

## Prompt

```
Draw a 6-frame walk cycle of this labourer (the man in the attached images: wide brown hat, red coat with a dark belt, grey trousers, brown boots) seen from the EAST side (he walks toward the right edge of the picture, side view, with the slight top-down three-quarter camera of a classic RTS). EMPTY hands, no tools.

The ONLY thing that must change from frame to frame is the walk, and it must be clearly visible in the LEGS. Give every frame different legs, drawn in the SAME pixel style as the body and the first reference (same outline weight, same two or three tones of grey on the trousers, same brown boots with a dark outline, not thinner, not simpler than the torso):
 frame 1 CONTACT: the right leg is stretched forward with the heel just touching the ground, the left leg is stretched back with only the toe on the ground; the legs are as far apart as they get (a wide "A" stance, the feet about 14 pixels apart in game pixels).
 frame 2 DOWN: the body is at its lowest, the front foot is flat under him, the back leg is bent and lifting, the back boot is off the ground with the knee pointing forward.
 frame 3 PASSING: the planted leg is straight under the body (body highest), the other leg swings forward, knee bent and the boot clearly lifted off the ground, passing next to the planted leg.
 frame 4 CONTACT with the OTHER foot: now the left leg is stretched forward with the heel down and the right leg is back on its toe (the mirror of frame 1).
 frame 5 DOWN, mirror of frame 2.
 frame 6 PASSING, mirror of frame 3, and frame 6 flows back into frame 1 so the loop is smooth.
The arms swing a little opposite to the legs (the near arm goes back when the near leg goes forward). The head, hat and face stay the same size and the same drawing in every frame (the head bobs 1 pixel up and down with the body). The planted boot must stay on the same ground line in the contact and down frames.

WHAT MUST NOT CHANGE: the man (hat, face, red coat, belt, grey trousers, brown boots), the figure size, the style of the body (match reference 2 exactly). AVOID: legs that look almost the same in every frame, a limp (one foot getting more frames than the other), a third leg or an extra boot, legs of different length, trousers in a different colour, any tool, sack or keg, extra or missing limbs, a different outfit, the thinner or simpler leg drawing of the code-made first reference (copy only its timing), any text. Do not copy the enlargement, the labels (e1 to e6), the lighter cell boxes or small ground ticks of the references into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around the figure; each game pixel drawn as a clean square block of about 6 by 6 sheet pixels (so the same pixel look as reference 2, only bigger).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground, no cast shadow, no frame borders. Layout: ONE row of 6 figures, left to right = frames 1 to 6, all on the same invisible ground line near the middle of the image, same size. The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box about 230 px wide and 300 px high, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

## Import checklist (for me)

- [ ] Save as `art/redraws/labourer_walk_east_test.png`; look at it: 6 figures, same man, legs alternating, same size.
- [ ] If it works: ask for the other four directions with the same text (s, se, ne, n, one row each, or one 5-row sheet), and replace the code-made legs: remove tools/import_labourer_gait.py and the walk repair in tools/import_labourer_v2.py from tools/rebuild_art.sh (docs/art_style_inconsistency.md tracks it).
