# ChatGPT prompts, set 2: redraws for the problem frames still open after set 1

Written 2026-10-24 from docs/animation_audit_labourer.md, docs/animation_audit_units.md and docs/animation_packs.md
(the sets of 'Replaced / Repaired / Kept' and 'Still needs redrawing' lists). The first set is docs/animation_redraw_prompts.md.

## How to use

- **Every prompt stands alone** (full style, full sheet layout, no reference to another prompt) so it can be pasted into ANY ChatGPT account. Each has at most 3 reference images, listed as files in `docs/redraw_refs/<prompt id>/` (also zipped in `redraw_references.zip`, one folder per prompt). Attach exactly those files, in that order, then paste the text after "Prompt:".
- The reference images are the CURRENT game strips enlarged 3 to 8 times with nearest neighbour (hard pixels), on the same navy as the answer sheet, each frame labelled (for example `e3` = east, frame 3) in the margin, a red tick marking the game's ground line. The labels, the lighter cell boxes and the ticks are for reading only: every prompt tells ChatGPT not to copy them.
- **What the importers expect** (tools/redraw_lib.py): ONE PNG per prompt, normally 1536x1024, landscape, a flat navy background `(0, 22, 48)` (anything within 24 levels of it is keyed out), figures cut out by gaps in rows and columns (so: rows = directions s, se, e, ne, n from the top, columns = frames from the left, at least 3 px of navy between figures, nothing touching, nothing cut off). Titles and row labels are tolerated (the importers look only at the area right of the labels) but the prompts ask for none. Figures should be about 4 sheet pixels per game pixel; the importer box-filters them down to the game cell, snaps the team reds, hard-alphas the edges and stands the feet on the anchor row.
- Save the answer as `art/redraws/<sheet name>.png` (the sheet name is given per prompt), check it by eye (rows in the right order, same size everywhere), then follow the import checklist of the prompt. If the first answer is wrong, regenerate; ChatGPT often draws the wrong direction order or invents extra frames.
- West is always the mirrored east: a sabre or tool in the right hand ends up in the left hand going west. Nothing here changes that.

## Index

| id | what | frames x directions | sheet name |
| --- | --- | --- | --- |
| 01_labourer_death | Labourer death (new outfit) | 3 x 5 | art/redraws/labourer_death.png |
| 02_labourer_death_keg | Labourer keg explosion death (new outfit) | 6 x 5 | art/redraws/labourer_death_keg.png |
| 03_labourer_bury | Labourer burying (new outfit) | 6 x 5 | art/redraws/labourer_bury.png |
| 04_labourer_build_headroom | Labourer hammering: head size and headroom | 4 x 5 | art/redraws/labourer_build_v2.png |
| 05_labourer_hoe | Labourer farm hoe swing | 4 x 5 | art/redraws/labourer_hoe_v2.png |
| 06_labourer_idle | Labourer idle: hoe at his side, same style | 2 x 5 | art/redraws/labourer_idle_v2.png |
| 07_labourer_walk_gait | Labourer walk with a real foot push | 6 x 5 | art/redraws/labourer_walk_v2.png |
| 08_labourer_carry_gait | Labourer walking with a gold sack, even gait | 6 x 5 | art/redraws/labourer_carry_v2.png |
| 09_labourer_keg_walk | Labourer walking with a powder keg, even gait | 6 x 5 | art/redraws/labourer_keg_walk_v2.png |
| 10_officer_idle_aim_fire | Officer idle, aim and fire (new man) | 5 x 5 | art/redraws/officer_idle_aim_fire.png |
| 11_officer_death | Officer death (new man) | 5 x 5 | art/redraws/officer_death.png |
| 12_armoured_officer_idle_aim_fire | Armoured Officer idle, aim and fire (new man) | 5 x 5 | art/redraws/armoured_officer_idle_aim_fire.png |
| 13_armoured_officer_death | Armoured Officer death (new man) | 5 x 5 | art/redraws/armoured_officer_death.png |
| 14_officer_walk_stride | Officer walk with a longer stride | 8 x 5 | art/redraws/officer_walk_v2.png |
| 15_armoured_officer_walk_stride | Armoured Officer walk with a longer stride | 8 x 5 | art/redraws/armoured_officer_walk_v2.png |
| 16_guardsman_walk | Guardsman (armoured Musketeer) walk, 6 frames | 6 x 5 | art/redraws/guardsman_walk.png |
| 17_pikeman_walk | Pikeman walk, 6 frames, all directions | 6 x 5 | art/redraws/pikeman_walk.png |
| 18_raptor_walk | Raptor walk, all five views, clear leg motion | 6 x 5 | art/redraws/raptor_walk_v2.png |
| 19_grub_walk | Grub worker walk, all five views, clear motion | 6 x 5 | art/redraws/grub_walk_v2.png |
| 20_armoured_dragoon_walk | Armoured Dragoon gallop, all five views | 6 x 5 | art/redraws/armoured_dragoon_walk.png |
| 21_dragoon_walk_south | Dragoon gallop toward the viewer (south) | 6 x 1 (s) | art/redraws/dragoon_walk_south.png |
| 22_horseman_walk | Horseman gallop, all five views | 8 x 5 | art/redraws/horseman_walk.png |
| 23_cuirassier_walk | Cuirassier gallop, all five views (dark horse) | 8 x 5 | art/redraws/cuirassier_walk.png |
| 24_messenger_walk | Messenger gallop, all five views | 8 x 5 | art/redraws/messenger_walk.png |
| 25_horse_riderless_walk | Riderless horse walk, all five views | 8 x 5 | art/redraws/horse_walk.png |
| 26_skywing_walk | Skywing flight loop, all views | 6 x 5 | art/redraws/skywing_walk_v2.png |
| 27_ornithopter_walk | Ornithopter flight loop, all views | 6 x 5 | art/redraws/ornithopter_walk_v2.png |
| 28_bloater_walk | Bloater float loop, all views | 6 x 5 | art/redraws/bloater_walk_v2.png |

## Not drawn on purpose

- Cannon, Mortar, Horse team, Brute, Steam Walker, Spore Mother, Spitter, Bolt walks: the audit could not judge them by the numbers ("look at them in game"), so there is no known flaw to redraw yet. Open the game first and add a prompt in this style only if one looks wrong.
- Tesla Cart walk: the 117 px cell versus the 70 px metadata is a code/metadata issue, not art.
- Separate west drawings (to stop sabre/musket swapping hands): not requested.
- Officer melee, Armoured Officer melee, Officer walk, Musketeer walk, Dragoon E/SE/NE/N, Raptor and Grub new directions: already redrawn in set 1 (only the follow-up flaws are in this set: 14, 15, 18, 19, 21).
- Remaining small flaws handled in code or by the importer, not by a redraw: the grey pixels on a Musketeer barrel tip (one frame), trim masks that found nothing on Armoured Officer walk_e and Musketeer walk_n.

## 1. Labourer death (new outfit)

Prompt id: `01_labourer_death`. Save the answer as `art/redraws/labourer_death.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/01_labourer_death/`:**

1. `1_current_death_pose_guide.png`: The CURRENT death animation (he already wears a felt hat and red coat but in the older, smaller, rougher drawing). Use it only as the POSE and TIMING guide: frame 1 staggers upright, frame 2 falls back, frame 3 lies on the ground.
2. `2_new_outfit_idle.png`: The NEW labourer, the man to draw (felt hat, red coat, grey trousers). Copy his proportions, head size, face and outline exactly.
3. `3_new_outfit_walk.png`: The same NEW man walking, frames 1, 3 and 5, for his clothes from the side, front and back.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the death animation of the labourer, 3 frames. Frame 1: hit, he jerks upright with his head thrown back and one arm flung out, boots still planted. Frame 2: falling backwards or sideways, knees buckling, hat tilting off, feet leaving the ground line. Frame 3: lying flat on the ground (about 14 px tall, 30 px long in game pixels), hat beside his head, arms loose, body in the same direction as it fell. The fall is toward the side that faces away from the camera for each view (so in the south view he falls backwards toward the viewer's left or right, in the north view face-down). No blood pools, a few dark red pixels at most.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the NEW man exactly (felt hat, red coat with the brown belt, grey trousers, brown boots), the same head size and outline as the walk and idle references, the same pixel scale. AVOID: the old keg man, blood splashes, a pickaxe or hoe in his hand, a gold sack, any keg or barrel.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 3 columns, left to right = frames 1 to 3. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 436 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

Note: Frame 3 is the corpse that stays on the map: make it a clean, readable shape.

**Import checklist**

- [ ] Save as `art/redraws/labourer_death.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 3 columns, every figure the same size.
- [ ] Importer: tools/import_labourer_redraw.py (add a 'death' sheet entry; frames 3, strips death_<dir>.png, cell 42x35, anchor (21,33)).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 2. Labourer keg explosion death (new outfit)

Prompt id: `02_labourer_death_keg`. Save the answer as `art/redraws/labourer_death_keg.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/02_labourer_death_keg/`:**

1. `1_current_death_keg.png`: The CURRENT animation (old keg man in a red cap and brown clothes, WRONG outfit): he carries a powder keg, the keg ignites and blows up in a fireball, then only a smoking scorch of debris is left. Keep this sequence, timing and the fireball style; only the man changes.
2. `2_new_outfit_keg_idle.png`: The NEW labourer carrying the keg: felt hat, red coat, grey trousers. This is the man to draw in frames 1 and 2 (and the keg in his arms, the same keg).
3. `3_new_outfit_walk.png`: The NEW man's clothes from every side.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the keg-explosion death of the labourer, 6 frames. Frame 1: the new labourer stands carrying the powder keg in front of his chest. Frame 2: the keg flashes, sparks and a yellow-white glow on it, his hat lifts and his arms fly open. Frame 3: the keg bursts into an orange fireball, the man hidden inside it, first grey smoke. Frame 4: biggest fireball, bright yellow-white core, large grey smoke puffs above, flying debris. Frame 5: the fireball shrinks and darkens, smoke rises. Frame 6: only a smoking scorch mark with a few splinters, grey smoke wisp, no man left. All frames are centred on the same spot.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the keg exactly as in reference 2; the fireball colours and size of reference 1 (frames 3-6 can look the same as the current ones). AVOID: the old keg man's red cap and brown shirt, a corpse left behind (the man vanishes in the blast), a bigger fireball than the cell (about 40 px wide, 34 px tall in game pixels at most).  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/labourer_death_keg.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: tools/import_labourer_redraw.py (new 'death_keg' sheet entry; 6 frames, strips death_keg_<dir>.png, cell 42x35, anchor (21,33); the fire and smoke frames 3 to 6 may be kept from the old strips if only frames 1-2 are redrawn).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 3. Labourer burying (new outfit)

Prompt id: `03_labourer_bury`. Save the answer as `art/redraws/labourer_bury.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/03_labourer_bury/`:**

1. `1_current_bury.png`: The CURRENT bury animation (WRONG man: red cap, brown shirt and trousers). The crouching pose and the sequence are right: 1 crouched holding the keg-sized bundle, 2 digging with a small spade, 3 setting the bundle into the hole, 4 shovelling soil over it, 5 a finished mound with only his back and hat showing, 6 straightening and patting the mound with the spade. Keep this sequence.
2. `2_new_outfit_build.png`: The NEW labourer crouching (hammering the stake): felt hat, red coat, grey trousers. This is the man and the crouch to draw.
3. `3_new_outfit_idle.png`: The NEW labourer standing, for the face and clothes in every direction.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the burial animation of the labourer, 6 frames, redrawn with the new man in the same sequence as reference 1: (1) crouched, holding a small barrel against his chest; (2) crouched, a small spade in his hands, a shallow hole in front; (3) lowering the barrel into the hole; (4) shovelling brown soil over it, soil mound growing; (5) the mound is finished, brown earth about 22 px wide in game pixels, he is bent forward behind it, only hat and back visible; (6) he straightens up beside the mound, resting the spade, a patch of loose soil under his boots. The soil mound is the same shape and size in every frame in which it appears, the ground line is the same. The man stays in the same spot (his boots do not hop between frames 5 and 6).  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the NEW outfit and face; a small spade (short wooden handle, grey iron blade) and a small barrel with two iron hoops; brown soil colours. AVOID: the old red cap, a pickaxe, a coffin, a body, a cross or grave marker, floating spade, the spade doubled.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/labourer_bury.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: tools/import_labourer_redraw.py (new 'bury' sheet entry; 6 frames, bury_<dir>.png, cell 42x35, anchor (21,33)); also fix the 4 px hop of frame 5 (the old frame 6 was displaced).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 4. Labourer hammering: head size and headroom

Prompt id: `04_labourer_build_headroom`. Save the answer as `art/redraws/labourer_build_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/04_labourer_build_headroom/`:**

1. `1_current_build.png`: The CURRENT hammering (4 frames per direction: hammer high, mid, strike with a spark, lifting). The crouch, the stake beside him and the sequence are right. Problems: the hammer is shortened where it reaches the top of the cell, and his head is about 20 percent smaller than his walking head.
2. `2_new_outfit_walk.png`: The walking labourer: look at the HEAD and HAT size here, the crouching head must be as big.
3. `3_new_outfit_idle.png`: The standing labourer, same man, for clothes and proportions.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the hammering animation again, 4 frames: the labourer crouches beside a wooden stake and drives it in with a big dark iron-headed hammer. Frame 1: hammer raised high above his head, full handle length visible (draw the whole man a little smaller in the cell if needed so the hammer fits, but KEEP his head and hat at the same size as in the walking reference). Frame 2: hammer coming down, halfway. Frame 3: the hammer head on top of the stake, a small yellow spark and a chip. Frame 4: hammer lifting again, halfway up. The body, crouch, boots and stake are IDENTICAL in all four frames (only head tilt, arm and hammer move). In the north view we see his back, in the north-east view he must also be crouched with the stake beside him.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the crouch and the position of the stake from reference 1; the NEW outfit; the hammer: dark grey head, brown handle, large enough to read at tiny size. AVOID: a hammer floating away from his hand, two hammers, a standing pose, a stake that changes height between frames, a head smaller than the walking head.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 4 columns, left to right = frames 1 to 4. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 320 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/labourer_build_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 4 columns, every figure the same size.
- [ ] Importer: tools/import_labourer_redraw.py (a new sheet name for 'build'; frames 4, build_<dir>.png; `BUILD_SWING`/`STRIKE_FRAME` stay the same: frame 1 raise, 2 drop, 3 strike with spark, 4 lift; the importer currently copies legs and stake from the strike frame, a clean redraw should not need it).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 5. Labourer farm hoe swing

Prompt id: `05_labourer_hoe`. Save the answer as `art/redraws/labourer_hoe_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/05_labourer_hoe/`:**

1. `1_current_hoe.png`: The CURRENT hoeing (code-drawn hoe pasted on the AI bodies; weak arms: in the east view frames 1 and 4 have no raised arm and the other tool-less hand hangs; mid and strike look alike).
2. `2_new_outfit_idle.png`: The standing labourer with the hoe at his side: the hoe to copy (2 px wooden handle, small iron plate), and the man.
3. `3_new_outfit_walk.png`: The same man walking, for proportions and clothes.

**Prompt:**

```
Draw a labourer working a field with a long-handled hoe, 4 frames: (1) raise: both hands on the handle, hoe lifted up over his shoulder, blade pointing back and up; (2) mid: the hoe swinging down in front, blade leading, body bending; (3) strike: the blade bites into the soil, knees bent, a spray of brown soil clods; (4) recover: pulling the hoe back, blade dripping soil, body straightening a little. BOTH hands always hold the handle, the arms clearly move from frame to frame, the weight (head lower on frame 3, higher on frame 1) shows. Boots on the same ground line in all frames.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the NEW outfit; a plain farm hoe (long brown wooden handle, a flat grey iron blade set at right angles, not a pickaxe, not a spade). AVOID: a pickaxe, a rake, a tool without a hand holding it, one arm missing, grey stone chips (soil is brown), a tool longer than his height plus 4 px.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 4 columns, left to right = frames 1 to 4. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 320 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/labourer_hoe_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 4 columns, every figure the same size.
- [ ] Importer: tools/import_labourer_hoe.py reads art/redraws/new_mine/; either drop the new strips into that folder (run it with --snapshot disabled) or add a new sheet and skip the code-drawn hoe step; frames 4: raise, mid, strike (soil), recover; STRIKE_FRAME = 2.
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 6. Labourer idle: hoe at his side, same style

Prompt id: `06_labourer_idle`. Save the answer as `art/redraws/labourer_idle_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/06_labourer_idle/`:**

1. `1_current_idle.png`: The CURRENT idle (older drawing, a different line weight from the redrawn poses): he stands with a hoe held low at his side, breathing slowly in 2 frames.
2. `2_new_style_idle_carry.png`: The NEW drawing style (idle with a gold sack): this is the line weight, shading and head size to match.
3. `3_new_style_walk.png`: The NEW walking labourer, for the clothes and proportions.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the labourer standing still, 2 frames of slow breathing (frame 2: the shoulders and hat 1 pixel higher, the hands unchanged), holding a long hoe low at his side with the blade resting on the ground behind his boots. Redraw in the new style: same line weight, shading and head size as references 2 and 3.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: pose and tool of reference 1; the NEW style and outfit. AVOID: the hoe raised across the body, a sack on his back, a shovel, different boots between the two frames, a changed face.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 2 columns, left to right = frames 1 to 2. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 670 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/labourer_idle_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 2 columns, every figure the same size.
- [ ] Importer: tools/import_labourer_redraw.py (new 'idle' sheet entry; frames 2, idle_<dir>.png, cell 42x35, anchor (21,33); ne is already done and can be skipped).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 7. Labourer walk with a real foot push

Prompt id: `07_labourer_walk_gait`. Save the answer as `art/redraws/labourer_walk_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/07_labourer_walk_gait/`:**

1. `1_current_walk.png`: The CURRENT walk (6 frames). The torso is good but the feet keep a constant gap, so no foot ever pushes back while the other swings.
2. `2_new_outfit_idle.png`: The same man standing, for clothes and proportions.
3. `3_new_outfit_carry.png`: The same man walking with a gold sack (do not draw the sack).

**Prompt:**

```
Draw an even 6-frame walk cycle of the labourer with EMPTY hands: frame 1 contact (front foot heel down, back foot toe down, legs far apart); frame 2 down (body at its lowest, both legs bent); frame 3 passing (the back foot swings past the planted leg, planted leg straight, body at its highest); frame 4 contact with the OTHER foot in front; frame 5 down; frame 6 passing. The planted foot clearly slides backwards under him from contact to passing (its position shifts about 5 px per frame in game pixels), the other foot lifts, swings and lands. The hands swing a little opposite to the legs. Frame 6 flows back into frame 1.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: torso, hat, face and coat of the NEW man; boots on the same ground line in the contact frames; the same head size and size of figure in every frame. AVOID: legs of different lengths, a limp (one foot getting more frames), a third leg, a sack or any tool, the feet at constant separation.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/labourer_walk_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: tools/import_labourer_redraw.py (new sheet for 'walk'; legs can be used as drawn: delete the leg-rebuild step; 6 frames, LAB_STRIDE stays 22 px per strip).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 8. Labourer walking with a gold sack, even gait

Prompt id: `08_labourer_carry_gait`. Save the answer as `art/redraws/labourer_carry_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/08_labourer_carry_gait/`:**

1. `1_current_carry.png`: The CURRENT walk carrying a gold sack on his back (legs do not alternate properly).
2. `2_new_outfit_idle_carry.png`: The same man standing with the sack: the sack to copy.
3. `3_new_outfit_walk.png`: The same man walking without the sack.

**Prompt:**

```
Draw a 6-frame walk cycle of the labourer carrying a small gold-coin sack on his back, the legs stepping like a real gait: contact, down, passing, contact (other foot in front), down, passing. The planted foot slides back under him, the other foot lifts and swings. He leans very slightly forward, the sack bobs with the body. The same sack (tan cloth, tied neck, a few gold coin dots) in the same place on his back in all frames.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the NEW outfit, the sack of reference 2, same head size, boots on the same ground line in the contact frames. AVOID: the sack hiding his legs, a floating sack, a sack in his hands, legs that do not alternate, any other tool.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/labourer_carry_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: tools/import_labourer_redraw.py (new sheet for 'carry'; 6 frames; replaces the rebuilt legs).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 9. Labourer walking with a powder keg, even gait

Prompt id: `09_labourer_keg_walk`. Save the answer as `art/redraws/labourer_keg_walk_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/09_labourer_keg_walk/`:**

1. `1_current_carry_keg.png`: The CURRENT walk carrying a powder keg (the legs barely alternate).
2. `2_new_outfit_idle_keg.png`: The same man standing with the keg: the keg and carry position to copy.
3. `3_new_outfit_walk.png`: The same man walking with empty hands.

**Prompt:**

```
Draw a 6-frame walk of the labourer carrying a small powder keg in his arms in front of his chest, below his chin, so the legs stay fully visible: contact, down, passing, contact (other foot), down, passing; the planted foot slides back under him while the other swings, the keg bobs slightly with the body.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the NEW outfit, the keg of reference 2 (brown staves, two grey iron hoops), the same head size, boots on the same ground line in the contact frames. AVOID: a keg on the head, the keg hiding the legs, a keg in different sizes in different frames, the old red cap.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/labourer_keg_walk_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: tools/import_labourer_redraw.py (new sheet for 'carry_keg'; 6 frames).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 10. Officer idle, aim and fire (new man)

Prompt id: `10_officer_idle_aim_fire`. Save the answer as `art/redraws/officer_idle_aim_fire.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/10_officer_idle_aim_fire/`:**

1. `1_current_idle_aim_fire.png`: The CURRENT idle (2 frames), aim (1 frame) and fire (2 frames), left to right, per direction. This is the OLD, narrower man: use it ONLY for the poses and what each frame shows (idle: standing at ease with the pistol lowered; aim: pistol raised and levelled at arm's length; fire: muzzle flash and smoke, then recoil).
2. `2_new_man_walk.png`: The NEW man to draw: he is BROADER and sturdier than the old man (walk frames 1 to 4, all directions).
3. `3_new_man_melee.png`: The same NEW man in melee (frames 2 and 3), for the coat, hat, face and sabre on his hip/hand.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the Officer standing and shooting, 5 frames per direction in ONE row: columns 1-2 IDLE (standing at ease, pistol held low in the right hand, sabre on the left hip, frame 2: shoulders and plume 1 px higher, a slow breath), column 3 AIM (feet apart, right arm straight out holding the pistol levelled at the target, the left hand on the hip), columns 4-5 FIRE (column 4: the pistol flashes, a bright yellow-white muzzle flash and a puff of grey smoke at the end of the barrel, the arm kicked up a little; column 5: the arm settling back, a thin wisp of smoke, the body leaning back one pixel). Draw the pistol as in reference 1: a long dark flintlock with a brown stock and a metal barrel, about 10 px long in game pixels, held in his right hand. Aim and fire are toward the direction of the row: south = toward the viewer, east = to the right, north = away. The same man, hat, coat and boots in all five frames; the feet stay put.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the NEW man: an 18th-century Crown army officer on foot: a brown tricorn hat with a plume (copy the plume's colour and shape from the walk reference), a bright red long coat with gold buttons and cuffs, white-grey breeches, brown boots, a leather belt, a pistol and a sabre; the same size and proportions as the walk and melee references (broader than the old idle), his head and hat the same size as in the walk. AVOID: the old narrow man, a plume that changes colour between frames, a sabre drawn in the hand (it stays sheathed), a second pistol, floating pistol, a muzzle flash and smoke puff larger than 20 px, text.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 5 columns, left to right = frames 1 to 5. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 250 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

Note: The pistol must NOT overlap the neighbouring figure.

**Import checklist**

- [ ] Save as `art/redraws/officer_idle_aim_fire.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 5 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_officers.py (extend: a new sheet cut as 5 columns -> idle 2, aim 1, fire 2 frames per direction; write idle_/aim_/fire_<dir>.png into assets/units/dismounted, cell 90x36, anchor (45,34); counts via write_counts; the importer's feet() / TARGET_H scaling from the melee step can be reused; re-run import_vet_trim.py after).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 11. Officer death (new man)

Prompt id: `11_officer_death`. Save the answer as `art/redraws/officer_death.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/11_officer_death/`:**

1. `1_current_death.png`: The CURRENT death (5 frames; old narrow man): shows the intended sequence, he is hit, staggers, falls to his knees and lies flat.
2. `2_new_man_walk.png`: The NEW man to draw, broader and sturdier than the old one.
3. `3_new_man_melee.png`: The same NEW man in melee, for his coat, hat and face.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the death of the Officer, 5 frames per direction: (1) hit, he jerks upright, head back, the pistol flying from his hand, hat tipping; (2) staggering back one step, a hand clutching his chest; (3) dropping to his knees, head bowed, the hat falling; (4) toppling over, arms out, boots leaving the ground line; (5) lying flat on the ground (about 12 px tall, 34 px long in game pixels), the hat beside his head, the sabre lying next to him. In the south view he falls backwards toward the viewer, in the north view face-down, in the east views along the ground toward the right. No big blood pool, a few dark red pixels at most.   Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the NEW man: an 18th-century Crown army officer on foot: a brown tricorn hat with a plume (copy the plume's colour and shape from the walk reference), a bright red long coat with gold buttons and cuffs, white-grey breeches, brown boots, a leather belt, a pistol and a sabre; same size and proportions as the walk and melee references. AVOID: the old narrow man, a changed plume, blood splashes, extra limbs, a corpse longer than the cell, a missing sabre in frame 5.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 5 columns, left to right = frames 1 to 5. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 250 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

Note: Frame 5 is the corpse that stays on the map: a clean, readable shape.

**Import checklist**

- [ ] Save as `art/redraws/officer_death.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 5 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_officers.py (extend: 5 columns -> death frames; write death_<dir>.png into assets/units/dismounted, cell 90x36, anchor (45,34); update the death_* counts (Armoured Officer goes from 2 to 5: ArtData via write_counts; check scripts/unit.gd death timing uses the frame count).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 12. Armoured Officer idle, aim and fire (new man)

Prompt id: `12_armoured_officer_idle_aim_fire`. Save the answer as `art/redraws/armoured_officer_idle_aim_fire.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/12_armoured_officer_idle_aim_fire/`:**

1. `1_current_idle_aim_fire.png`: The CURRENT idle (2 frames), aim (1 frame) and fire (2 frames), left to right, per direction. This is the OLD, narrower man: use it ONLY for the poses and what each frame shows (idle: standing at ease with the pistol lowered; aim: pistol raised and levelled at arm's length; fire: muzzle flash and smoke, then recoil).
2. `2_new_man_walk.png`: The NEW man to draw: he is BROADER and sturdier than the old man (walk frames 1 to 4, all directions).
3. `3_new_man_melee.png`: The same NEW man in melee (frames 2 and 3), for the coat, hat, face and sabre on his hip/hand.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the Armoured Officer standing and shooting, 5 frames per direction in ONE row: columns 1-2 IDLE (standing at ease, pistol held low in the right hand, sabre on the left hip, frame 2: shoulders and plume 1 px higher, a slow breath), column 3 AIM (feet apart, right arm straight out holding the pistol levelled at the target, the left hand on the hip), columns 4-5 FIRE (column 4: the pistol flashes, a bright yellow-white muzzle flash and a puff of grey smoke at the end of the barrel, the arm kicked up a little; column 5: the arm settling back, a thin wisp of smoke, the body leaning back one pixel). Draw the pistol as in reference 1: a long dark flintlock with a brown stock and a metal barrel, about 10 px long in game pixels, held in his right hand. Aim and fire are toward the direction of the row: south = toward the viewer, east = to the right, north = away. The same man, hat, coat and boots in all five frames; the feet stay put.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the NEW man: an 18th-century Crown army officer on foot: a brown tricorn hat with a plume (copy the plume's colour and shape from the walk reference), a bright red long coat with gold buttons and cuffs, white-grey breeches, brown boots, a leather belt, a pistol and a sabre, plus a steel breastplate with a gold edge and an iron helmet-hat (a steel cap under the tricorn, steel gorget at the neck); the same size and proportions as the walk and melee references (broader than the old idle), his head and hat the same size as in the walk. AVOID: the old narrow man, a plume that changes colour between frames, a sabre drawn in the hand (it stays sheathed), a second pistol, floating pistol, a muzzle flash and smoke puff larger than 20 px, text.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 5 columns, left to right = frames 1 to 5. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 250 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

Note: The pistol must NOT overlap the neighbouring figure.

**Import checklist**

- [ ] Save as `art/redraws/armoured_officer_idle_aim_fire.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 5 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_officers.py (extend: a new sheet cut as 5 columns -> idle 2, aim 1, fire 2 frames per direction; write idle_/aim_/fire_<dir>.png into assets/units/dismounted_armoured, cell 90x36, anchor (45,34); counts via write_counts; the importer's feet() / TARGET_H scaling from the melee step can be reused; re-run import_vet_trim.py after).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 13. Armoured Officer death (new man)

Prompt id: `13_armoured_officer_death`. Save the answer as `art/redraws/armoured_officer_death.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/13_armoured_officer_death/`:**

1. `1_current_death.png`: The CURRENT death (2 frames; old narrow man): shows the intended sequence, he is hit, staggers, falls to his knees and lies flat.
2. `2_new_man_walk.png`: The NEW man to draw, broader and sturdier than the old one.
3. `3_new_man_melee.png`: The same NEW man in melee, for his coat, hat and face.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the death of the Armoured Officer, 5 frames per direction: (1) hit, he jerks upright, head back, the pistol flying from his hand, hat tipping; (2) staggering back one step, a hand clutching his chest; (3) dropping to his knees, head bowed, the hat falling; (4) toppling over, arms out, boots leaving the ground line; (5) lying flat on the ground (about 12 px tall, 34 px long in game pixels), the hat beside his head, the sabre lying next to him. In the south view he falls backwards toward the viewer, in the north view face-down, in the east views along the ground toward the right. No big blood pool, a few dark red pixels at most. The breastplate stays on him and gleams on the ground.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the NEW man: an 18th-century Crown army officer on foot: a brown tricorn hat with a plume (copy the plume's colour and shape from the walk reference), a bright red long coat with gold buttons and cuffs, white-grey breeches, brown boots, a leather belt, a pistol and a sabre, plus a steel breastplate with a gold edge and an iron helmet-hat (a steel cap under the tricorn, steel gorget at the neck); same size and proportions as the walk and melee references. AVOID: the old narrow man, a changed plume, blood splashes, extra limbs, a corpse longer than the cell, a missing sabre in frame 5.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 5 columns, left to right = frames 1 to 5. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 250 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

Note: Frame 5 is the corpse that stays on the map: a clean, readable shape.

**Import checklist**

- [ ] Save as `art/redraws/armoured_officer_death.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 5 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_officers.py (extend: 5 columns -> death frames; write death_<dir>.png into assets/units/dismounted_armoured, cell 90x36, anchor (45,34); update the death_* counts (Armoured Officer goes from 2 to 5: ArtData via write_counts; check scripts/unit.gd death timing uses the frame count).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 14. Officer walk with a longer stride

Prompt id: `14_officer_walk_stride`. Save the answer as `art/redraws/officer_walk_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/14_officer_walk_stride/`:**

1. `1_current_walk.png`: The CURRENT 8-frame walk. The steps are only 10-14 px at 62-66 px/s, so he skates; frames ne5 and se4 are 2-3 px off (hat and boots).
2. `2_idle.png`: The same man standing, for his clothes and proportions.
3. `3_melee.png`: The same man in melee (frame 2).

**Prompt:**

```
Draw a brisk military march of the Officer, 8 frames: contact (feet far apart, front heel down), down, passing, up (frames 1-4 right foot forward), then contact with the left foot forward, down, passing, up (frames 5-8). The stride is CLEARLY longer than the current one: at contact the feet are about 1.5 times further apart than in reference 1; slight body bob (1 px), the arms swing opposite to the legs, the pistol and sabre stay on his belt. Every frame the SAME height (hat to boots), same body width, boots on the same ground line at contact, a seamless loop (frame 8 flows into frame 1).  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the man of the references: an 18th-century Crown army officer on foot: a brown tricorn hat with a plume (copy the plume's colour and shape from the walk reference), a bright red long coat with gold buttons and cuffs, white-grey breeches, brown boots, a leather belt, a pistol and a sabre; the same size in all 8 frames of a row. AVOID: one frame bigger than the others, a hat or plume that changes, feet at constant separation, a sabre in hand, a pistol drawn, extra limbs.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 8 columns, left to right = frames 1 to 8. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 145 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

Note: Cell width 90 is generous: he is about 28 px wide when striding.

**Import checklist**

- [ ] Save as `art/redraws/officer_walk_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 8 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_officers.py (new sheet in the 'walk' step, replaces officer_walk_A/B; 8 frames, walk_<dir>.png, cell 90x36, anchor (45,34); also fixes walk_ne frame 5 and walk_se frame 4 (2-3 px off)).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 15. Armoured Officer walk with a longer stride

Prompt id: `15_armoured_officer_walk_stride`. Save the answer as `art/redraws/armoured_officer_walk_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/15_armoured_officer_walk_stride/`:**

1. `1_current_walk.png`: The CURRENT 8-frame walk. The steps are only 10-14 px at 62-66 px/s, so he skates; frame e1 is 2 px taller and bulkier than e2 to e8.
2. `2_idle.png`: The same man standing, for his clothes and proportions.
3. `3_melee.png`: The same man in melee (frame 2).

**Prompt:**

```
Draw a brisk military march of the Armoured Officer, 8 frames: contact (feet far apart, front heel down), down, passing, up (frames 1-4 right foot forward), then contact with the left foot forward, down, passing, up (frames 5-8). The stride is CLEARLY longer than the current one: at contact the feet are about 1.5 times further apart than in reference 1; slight body bob (1 px), the arms swing opposite to the legs, the pistol and sabre stay on his belt. Every frame the SAME height (hat to boots), same body width, boots on the same ground line at contact, a seamless loop (frame 8 flows into frame 1).  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the man of the references: an 18th-century Crown army officer on foot: a brown tricorn hat with a plume (copy the plume's colour and shape from the walk reference), a bright red long coat with gold buttons and cuffs, white-grey breeches, brown boots, a leather belt, a pistol and a sabre, plus a steel breastplate with a gold edge and an iron helmet-hat; the same size in all 8 frames of a row. AVOID: one frame bigger than the others, a hat or plume that changes, feet at constant separation, a sabre in hand, a pistol drawn, extra limbs.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 8 columns, left to right = frames 1 to 8. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 145 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

Note: Cell width 90 is generous: he is about 28 px wide when striding.

**Import checklist**

- [ ] Save as `art/redraws/armoured_officer_walk_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 8 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_officers.py (new sheet in the 'walk' step, replaces officer_walk_A/B; 8 frames, walk_<dir>.png, cell 90x36, anchor (45,34); also fixes walk_e frame 1 (2 px taller and bulkier)).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 16. Guardsman (armoured Musketeer) walk, 6 frames

Prompt id: `16_guardsman_walk`. Save the answer as `art/redraws/guardsman_walk.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/16_guardsman_walk/`:**

1. `1_current_guardsman_walk.png`: The CURRENT Guardsman walk: south 3 frames, south-east 4, east 6, north-east 5, north 7, so the cycles do not match when he turns.
2. `2_musketeer_walk_new.png`: The light Musketeer's NEW 6-frame walk: the model for the phases and the stride (same pose in each column in every direction).
3. `3_guardsman_idle.png`: The Guardsman standing: his armour, hat and musket to keep.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the Guardsman (a Musketeer in armour) walking with the musket carried on his shoulder, 6 frames in every direction, the phases matching the Musketeer's walk in reference 2 (contact, down, passing, contact other foot, down, passing). Same steel breastplate and helmet, red coat, black hat with a red plume (NO green plume anywhere), grey trousers, brown boots as in reference 3.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the armour and outfit of reference 3; the musket on the same shoulder in every frame; same height in every frame; boots on the same ground line at contact. AVOID: a green plume or cockade, a grey pixel cloud on the barrel tip, a musket that grows or shrinks between frames, frames of different heights, a lone figure walking toward the camera that looks different from the side one.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/guardsman_walk.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_musketeer.py (copy its musketeer_walk step for art 'musketeer_armoured': front set for s/se/e, back set for ne/n; 6 frames, walk_<dir>.png, cell 90x36, anchor (45,34); counts 3/4/6/5/7 become 6 each; re-run import_vet_trim.py).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 17. Pikeman walk, 6 frames, all directions

Prompt id: `17_pikeman_walk`. Save the answer as `art/redraws/pikeman_walk.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/17_pikeman_walk/`:**

1. `1_current_pike_walk.png`: The CURRENT walk: south and south-east only 2 frames, north 4 frames where the legs hardly move, north-east frame 2 draws two pike shafts, east frame 4 and north-east frame 2 are 4-5 px taller (pike tip).
2. `2_pike_idle.png`: The standing pikeman (2 frames): the man, the outfit and the pike to keep, with the pike upright.
3. `3_pike_thrust.png`: The thrust (2 frames): the same man, the same pike, for the pike's head and shaft.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the pikeman marching with the long pike carried upright over his shoulder, 6 frames in every direction: contact, down, passing, contact (other foot), down, passing; the legs clearly stepping with the planted foot sliding back, a seamless loop. ONE single pike shaft only, held in the same place and angle in every frame, its steel head and the tip of the shaft inside the cell, never making the man taller in some frames.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the man, helmet, coat and pike from references 2-3; same height and width in all frames; boots on one ground line. AVOID: two shafts, a pike that moves up and down, the pike tip cut off, legs that do not move, a different pike head per frame.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

Note: The pike makes this figure tall: tell the sheet to use all the height (about 175 px per row).

**Import checklist**

- [ ] Save as `art/redraws/pikeman_walk.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: new tools/import_redraw_pikeman.py (copy import_redraw_musketeer.py; cell 68x66, anchor (34,64); keep the pike tip inside the cell; counts 2/2/4/4/4 become 6 each; walk_<dir>.png in assets/units/pikeman).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 18. Raptor walk, all five views, clear leg motion

Prompt id: `18_raptor_walk`. Save the answer as `art/redraws/raptor_walk_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/18_raptor_walk/`:**

1. `1_current_raptor_walk.png`: The CURRENT raptor walk (6 frames in 5 views; the new directions move their legs only subtly, the E view is the old gait).
2. `2_raptor_idle.png`: The raptor standing: the creature to keep.
3. `3_raptor_attack_e.png`: The raptor attacking in the east view, for its jaws and claws.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the raptor (a small fast two-legged reptile with a long tail and a crest of pink spines) running, 6 frames in each of 5 views: south = running toward the viewer, south-east, east (side view), north-east, north = running away. A clear run cycle: contact (one leg stretched forward, the other back), down, passing (one leg lifted under the body), contact other leg, down, passing. The legs MUST visibly alternate (the planted foot slides back, the other leg swings forward), the tail sways opposite to the head, the head bobs 1 px. Same size and colours in every view, feet on the same ground line, the loop seamless.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: colours, spines, head and tail of the references; the same body size in every frame (about 24 px long in the east view in game pixels). AVOID: legs that stay in the same position, a different colour or spine colour, a tail touching the head in the east view, extra legs, a flat sideways view in the south or north rows.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/raptor_walk_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_creatures.py (extend the 'raptor' part with a new sheet name; walk_s/se/e/ne/n, 6 frames; cell 58x30, anchor (29,28); E may replace the old strip this time; the importer splits touching figures at the column with the fewest pixels).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 19. Grub worker walk, all five views, clear motion

Prompt id: `19_grub_walk`. Save the answer as `art/redraws/grub_walk_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/19_grub_walk/`:**

1. `1_current_grub_walk.png`: The CURRENT grub walk (6 frames in 5 views; very subtle motion in the new views).
2. `2_grub_idle.png`: The grub standing: the creature to keep.
3. `3_grub_carry_cocoon.png`: The grub carrying a cocoon (for its body segments and legs; do NOT draw the cocoon).

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the grub (a fat segmented larva worker with small legs and a round head) crawling, 6 frames in each of 5 views: south = toward the viewer, south-east, east, north-east, north = away. A clear inching crawl: the body stretches long (frames 1-2), bunches up (frames 3-4) and stretches again, with the front legs reaching and the rear ones pushing, a seamless loop. Same size and colours in every view, body on the same ground line.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: colours, head and segment style of the references, the size (about 20 px long in the east view in game pixels). AVOID: a cocoon on its back, wings, a different colour, motion that is only a colour shift, the body changing size between frames beyond the stretch.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/grub_walk_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_creatures.py (extend the 'grub' part with a new sheet name; walk_s/se/e/ne/n, 6 frames; cell 42x29, anchor (21,27)).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 20. Armoured Dragoon gallop, all five views

Prompt id: `20_armoured_dragoon_walk`. Save the answer as `art/redraws/armoured_dragoon_walk.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/20_armoured_dragoon_walk/`:**

1. `1_current_armoured_dragoon_walk.png`: The CURRENT Armoured Dragoon walk (10 frames; north-east is a copy of east; frame 1 is bigger than the rest).
2. `2_dragoon_walk_new.png`: The light Dragoon's NEW gallop (6 frames, a true side view for east, a real north-east): the model for the gait, size and horse. (The south row is the old 10-frame one and is not a model.)
3. `3_armoured_dragoon_idle.png`: The Armoured Dragoon standing: the rider, the armour and the horse's coat to keep.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the Armoured Dragoon (a mounted soldier in a breastplate and steel helmet with a carbine) galloping, 6 frames in each of 5 views, same gait as reference 2: south = toward the viewer, south-east, east (pure side view), north-east (seen from behind and to the right, a real drawing, not a copy of the north), north (from behind). Gallop cycle: gathered, stretching, flying, landing, gathering, stretching; the rider bobs in the saddle.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: rider and horse exactly as in reference 3 (armour, helmet, horse coat and tack); the same size in every frame, the hoof line steady. AVOID: frame 1 bigger than the others, a north-east that is a copy of the east or north, a rider without armour, a different horse colour, extra legs, a floating carbine.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/armoured_dragoon_walk.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_mounted.py (a new sheet like mounted_walk_C, art 'dragoon_armoured'; strips walk_<dir>.png, 6 frames, cell 98x70, anchor (49,66); counts 10 become 6; re-run the vet trim / skin masks).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 21. Dragoon gallop toward the viewer (south)

Prompt id: `21_dragoon_walk_south`. Save the answer as `art/redraws/dragoon_walk_south.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/21_dragoon_walk_south/`:**

1. `1_current_dragoon_walk.png`: The Dragoon's walk, 6 frames in each view. The east, south-east, north-east and north rows are the NEW gallop: the model. The SOUTH row is the old 10-frame one, with a bigger first frame and a foot line 3-5 px lower: the sheet has no S row, and it is the one to redraw.
2. `2_dragoon_idle.png`: The Dragoon standing: the rider, uniform and horse coat to keep.
3. `3_dragoon_attack_s.png`: The Dragoon facing the viewer (death frames 1-2, only to see the horse and rider from the FRONT).

**Prompt:**

```
Make oNE row only: the Dragoon (mounted musketeer) galloping straight toward the viewer, 6 frames, same horse, rider and gait as the other rows of reference 1: the horse's chest and head toward us, forelegs reaching, hind legs pushing, the rider hunched with his carbine across his back, the horse's mane flying. Every frame the same size, the hoof line steady, a seamless loop.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the rider and horse of reference 2; the same size and colours as the south-east row of reference 1. AVOID: a bigger first frame, a front view that is cut by the cell's top, a different horse coat, a rider without his hat, extra legs.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: ONE single row (the south view only: facing the viewer), 6 frames left to right, on an image of 1536 by 640 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 190 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/dragoon_walk_south.png` (1536x1024, 640 high) and look at it: one row of 6 frames, all the same size.
- [ ] Importer: tools/import_redraw_mounted.py (new sheet; only walk_s, 6 frames, for art 'dragoon'; the other directions stay).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 22. Horseman gallop, all five views

Prompt id: `22_horseman_walk`. Save the answer as `art/redraws/horseman_walk.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/22_horseman_walk/`:**

1. `1_current_horseman_walk.png`: The CURRENT Horseman walk (10/8/7/7/8 frames; north-east is the same as north; south and south-east frames 1-2 are bigger than 3-8).
2. `2_cuirassier_walk.png`: The Cuirassier (the armoured version) galloping: the same horse and gait family; the Horseman has NO armour. A model for the gallop and size.
3. `3_horseman_idle.png`: The Horseman standing: the rider, uniform and horse coat to keep.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the Horseman (a light cavalryman in a red coat and tricorn, with a sabre) galloping, 8 frames in each of 5 views: south = toward the viewer, south-east, east (pure side view), north-east (from behind and to the right: a real drawing, not the north view), north (from behind). Gallop: gather, push, extended flight, landing, again twice. Same size in every frame, hoof line steady, the sabre sheathed on his hip.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: rider, uniform and horse coat from reference 3; the same size and proportions as in reference 2. AVOID: frames of different sizes, a north-east that is a copy of the north, armour, a drawn sabre, a different horse colour, extra legs.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 8 columns, left to right = frames 1 to 8. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 145 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/horseman_walk.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 8 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_mounted.py (new sheet, art 'horseman'; walk_<dir>.png, 8 frames; counts 10/8/7/7/8 become 8; cell 98x70, anchor (49,66)).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 23. Cuirassier gallop, all five views (dark horse)

Prompt id: `23_cuirassier_walk`. Save the answer as `art/redraws/cuirassier_walk.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/23_cuirassier_walk/`:**

1. `1_current_cuirassier_walk.png`: The CURRENT Cuirassier walk (8 frames; north-east is the same as north).
2. `2_cuirassier_idle.png`: The Cuirassier standing: rider, armour and the DARK horse to keep.
3. `3_cuirassier_attack.png`: The Cuirassier attacking (frames 1-2): the dark horse and the armour from all sides.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the Cuirassier (a heavy cavalryman in a steel breastplate and helmet, on a DARK horse) galloping, 8 frames in each of 5 views: south, south-east, east (pure side), north-east (a real three-quarter back view), north. A true gallop with a clear flight phase, not a trot in place. Same size in every frame, hoof line steady.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the rider, armour and DARK horse coat of reference 2; the same size and proportions as the references. AVOID: a brown or tan horse (the earlier attempts had one), a trot in place, a north-east copy of the north, frames of different sizes, extra legs.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 8 columns, left to right = frames 1 to 8. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 145 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/cuirassier_walk.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 8 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_mounted.py (new sheet, art 'cuirassier'; walk_<dir>.png, 8 frames; cell 98x70, anchor (49,66); the old gallop strips stay as a fallback).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 24. Messenger gallop, all five views

Prompt id: `24_messenger_walk`. Save the answer as `art/redraws/messenger_walk.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/24_messenger_walk/`:**

1. `1_current_messenger_walk.png`: The CURRENT Messenger walk (9/9/5/8/8 frames; east frames 4-5 have twice the pixels: a second figure or coat flap).
2. `2_messenger_idle.png`: The Messenger standing: the rider, his bag and the horse coat to keep.
3. `3_horseman_walk.png`: A Horseman galloping (frames 1 and 4): a model for the gallop pose and size.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the Messenger (a light courier on a fast horse, a satchel on his back) galloping, 8 frames in each of 5 views: south, south-east, east, north-east, north. Same size in every frame, the coat tails and satchel in the same place and size in every frame (no second figure), the hoof line steady.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: rider, satchel and horse coat from reference 2. AVOID: doubled riders, a coat flap that doubles the pixels, a different horse, frames of different sizes, extra legs.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 8 columns, left to right = frames 1 to 8. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 145 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/messenger_walk.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 8 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_mounted.py (new sheet, art 'messenger'; walk_<dir>.png, 8 frames; counts 9/9/5/8/8 become 8).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 25. Riderless horse walk, all five views

Prompt id: `25_horse_riderless_walk`. Save the answer as `art/redraws/horse_walk.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/25_horse_riderless_walk/`:**

1. `1_current_horse_walk.png`: The CURRENT riderless horse walk (6/5/4/5/5 frames; stiff; south frame 6 and south-east differ by 3 px in foot line).
2. `2_horse_idle.png`: The riderless horse standing: the horse, coat and tack to keep.
3. `3_horse_graze.png`: The horse grazing: for the head and neck.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the riderless horse walking (a four-beat walk, left hind, left fore, right hind, right fore), 8 frames in each of 5 views: south = toward the viewer, south-east, east, north-east, north = away. The head nods gently, the tail swings, the legs clearly alternate, a seamless loop. Same coat, saddle blanket and size in every frame, hoof line steady.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the horse, its coat and tack from references 2-3. AVOID: a rider, a different coat, a stiff pose, legs that do not move, frames of different sizes, extra legs.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 8 columns, left to right = frames 1 to 8. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 145 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/horse_walk.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 8 columns, every figure the same size.
- [ ] Importer: tools/import_redraw_mounted.py (new sheet, art 'horse'; walk_<dir>.png, 8 frames; counts 6/5/4/5/5 become 8; the horse coat masks of import_horse_coats.py need re-running).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 26. Skywing flight loop, all views

Prompt id: `26_skywing_walk`. Save the answer as `art/redraws/skywing_walk_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/26_skywing_walk/`:**

1. `1_current_skywing_walk.png`: The CURRENT Skywing walk (flying) 3 frames (2 in the north-east); south frame 1 has 60 percent more pixels than frames 2-3 (wings fully out).
2. `2_skywing_idle.png`: The Skywing hovering: the creature to keep (black body, red membrane wings, long tail).
3. `3_skywing_attack.png`: The Skywing attacking: its claws and head.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the Skywing (a small black-bodied dragon with red-membrane wings) flying forward with a steady wingbeat, 6 frames in each of 5 views: wings raised high, wings sweeping down fully extended, wings at the bottom, wings coming up, folded half, raised again. The body bobs 1-2 px, the tail trails. The wingspan changes with the flap but the BODY is the same size and the same position in every frame. south = flying toward the viewer, north = away.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: colours, body, head, red wings of the references; the body at the same place of the cell in all frames; every frame inside the cell. AVOID: wings that suddenly have 60 percent more pixels in one frame, a different creature, a rider, a shadow, the wings cut by the edge.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/skywing_walk_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: new tools/import_redraw_flyers.py (copy import_redraw_creatures.py); art 'skywing', strips walk_<dir>.png, 6 frames, cell 56x45, anchor (28,43); counts 3/3/3/2/3 become 6.
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 27. Ornithopter flight loop, all views

Prompt id: `27_ornithopter_walk`. Save the answer as `art/redraws/ornithopter_walk_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/27_ornithopter_walk/`:**

1. `1_current_ornithopter_walk.png`: The CURRENT Ornithopter walk (south and south-east frame 1 has wings about 40 percent bigger than the rest, then 2 px shorter).
2. `2_ornithopter_idle.png`: The Ornithopter hovering: the machine to keep (brass body, tan-and-red wings, blue thruster flame).
3. `3_ornithopter_attack.png`: The Ornithopter attacking: for its gun or sling.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the Ornithopter (a brass clockwork flying machine with tan-and-red flapping wings and a blue flame at the back) flying with a flapping wing cycle, 6 frames in each of 5 views: wings up, sweeping, wings down, wings up again, with the body bobbing 1 px. The body, the blue flame and the tail are the same size and place in every frame; only the wings change.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: the brass machine and colours of the references; every frame inside the cell. AVOID: one frame with much bigger wings, a pilot, smoke trails, a different machine, a change in body size.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/ornithopter_walk_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: new tools/import_redraw_flyers.py; art 'ornithopter', strips walk_<dir>.png, 6 frames, cell 48x50, anchor (24,35); counts 7/7/6/6/6 become 6.
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

## 28. Bloater float loop, all views

Prompt id: `28_bloater_walk`. Save the answer as `art/redraws/bloater_walk_v2.png`.

**Attach (3 images, in this order), from `docs/redraw_refs/28_bloater_walk/`:**

1. `1_current_bloater_walk.png`: The CURRENT Bloater walk (6/6/5/5/5 frames; in north and south-east frames 2-3 the body jumps 4-5 px: the belly bob is too violent).
2. `2_bloater_idle.png`: The Bloater floating still: the creature to keep (a green-yellow gas-filled bladder with tan fins, a red crest and hanging tendrils).
3. `3_bloater_attack.png`: The Bloater attacking.

**Prompt:**

```
The attached images are reference sprites of the figure (numbered as listed above); do not copy their labels. Draw the Bloater (a floating gas-bladder creature with a red crest, small tan fins and a bunch of hanging tendrils) drifting forward, 6 frames in each of 5 views: the fins flutter, the tendrils sway left and right, and the whole body bobs up and down by only 2 px (smoothly: a sine over the 6 frames); the bladder keeps the same size and shape. south = toward the viewer, north = away.  Direction rows: figures face the direction of their row, the game draws west by mirroring east. WHAT MUST NOT CHANGE: colours and shape of the references; the same body size in every frame; every frame inside the cell. AVOID: a body that jumps 4-5 px between frames, a deflated bladder, extra eyes or mouths, a changed crest, a shadow.  extra or missing limbs, a different outfit or colour scheme from the references, floating or detached tools and weapons, two copies of a tool, a different pixel scale, any text. Use the reference images only to understand the pose, the figure and the style: do not copy their enlargement, their labels (such as 'idle', 'e3'), their lighter cell boxes or the small red ground ticks into the answer.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south (facing the viewer), south-east, east, north-east, north (back to the viewer); 6 columns, left to right = frames 1 to 6. Do NOT draw a west row (the game mirrors east) and no extra rows. The image is landscape, 1536 by 1024 pixels. Each figure (with its weapon, tool or wings) must fit in a box of about 203 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching, overlapping or cut by the image edge.
```

**Import checklist**

- [ ] Save as `art/redraws/bloater_walk_v2.png` (1536x1024) and look at it: 5 rows in the order s, se, e, ne, n and 6 columns, every figure the same size.
- [ ] Importer: new tools/import_redraw_flyers.py; art 'bloater', strips walk_<dir>.png, 6 frames, cell 56x61, anchor (28,36); counts 6/6/5/5/5 become 6 (frames jumped 4-5 px in the foot line: the belly bob must stay within 2 px).
- [ ] Contact-sheet every direction at 4x (`--contact DIR`), check the first and last frame loop, then rebuild with `tools/rebuild_art.sh` order intact; run the matching tests (`tools/test_unit_walk_audit.gd` / `test_labourer_anim.gd`), bump the version and add a patch note (CLAUDE.md).

