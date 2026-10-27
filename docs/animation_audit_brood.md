# Animation audit: the Brood (2026-10-27)

Every Brood creature in every animation, the Queen, and every Brood building.
Measured by `tools/anim_audit/measure_brood.py`, looked at frame by frame on contact sheets, and checked in the game's animation viewer.
Pictures are in `docs/shots/anim_audit_brood/`.
Written to be read aloud: short sentences, one point each.

Branch `anim-audit-brood`, version 0.14.54.

## THE TEN MOST IMPORTANT FINDINGS

Ranked by how much fixing them would improve the game, for the effort.

1. **The cocoon grub is a different animal.** FIXED: no. REDRAW: prompts B1 and B2.
   The grub walks as a low, dark olive crawler with a full blue crest.
   When it wraps a body it turns into an upright, lime-green, frog-like creature with a tiny crest.
   It stays that creature while it carries the cocoon home, and it dies as that creature.
   The grub is the Brood unit seen most often, so this pop happens all game long.
   Picture: `problem_grub_two_creatures.png`.
2. **The Brute, the Spitter and the Mist Toad only walk sideways.** REDRAW: prompts B3, B5, B6.
   Their walk, attack and death exist in the east view only.
   Walking up or down the screen they slide along side-on.
   When they stop, they snap round to a front or back idle, and snap sideways again when they move.
3. **Raptors and grubs hopped 2 px when they turned.** FIXED.
   Their up and down walks stood 2 px above the ground line; everything else stands on it.
   Every turn from sideways to up or down, and every stop, was a small hop.
   Picture: `fix_raptor_turn_feet.gif`, `fix_grub_turn_feet.gif`.
4. **The Raptor's feet skated.** FIXED.
   It runs at 108 px a second on a 6-frame cycle that played at 8 frames a second.
   A planted foot slid about 10 px every frame. Now it plays at 12, and slides about 6.
   Picture: `fix_raptor_walk_fps.gif`.
5. **Team colour leaked on the Queen and the Clutch Mound.** FIXED.
   The Queen's crest and the Clutch Mound's frills were painted in ordinary reds.
   A blue player's Queen and mounds had red crests.
   The Queen's sprite also had no team shader, so even her few key reds showed red.
   About 166 more fringe pixels on unit crests stayed red for every team; they are snapped to the key now.
   Picture: `fix_queen_clutch_team.png`, `fix_brute_charge_keyreds.png`.
6. **The Mist Toad's death never finished.** FIXED.
   It has 13 frames at 7 frames a second: 1.9 seconds.
   A body stops animating 1.5 seconds after death, so it froze on frame 11, half fallen.
   It now plays to the last frame, flat on the ground. Picture: `fix_mist_toad_death.gif`.
7. **The Skywing's attack east had a broken frame, and its hover flapped in slow motion.** FIXED (and REDRAW B8).
   Frame 1 of `attack_e` was only a wing and a tail; the body was missing. It now reuses frame 3.
   Hovering, it beat its wings at 2 frames a second, so it jumped between very different poses. Now 6.
   Picture: `fix_skywing_attack_e.png`, `fix_skywing_hover_fps.gif`.
8. **The Brute's idle and attack fight the cell.** REDRAW: prompt B4.
   Its three idle frames are three different bodies. The feet slide 20 px and the body jumps 7 px every half second.
   Attack frame 5 leaps 25 px forward and its head is cut off by the cell's edge.
   Picture: `problem_brute_attack_cell.png`, `brute_idle_e_x3.gif`.
9. **Deaths that end in mid-air.** REDRAW: prompts B7 and B12.
   The Bloater's deflate strip starts already flat, so a full yellow sac pops to a brown rag.
   The Bloater's burst ends on a cloud of acid, and that cloud lies on the field as its body for almost 2 minutes.
   The Spore Mother's last frame has her spores hanging frozen in the air.
10. **Brood buildings do not move.** NEW ART: prompts B10 and B11.
    Every Brood building is a still picture with a puff of green smoke.
    The Queen is a still sprite. Eggs are only a number, "3/5"; nothing hatches.
    The Brood is the living faction, and its base is the stillest in the game.

## What was fixed on this branch

All fixes are technical. No art was redrawn. No balance changed.

| Fix | Where | Before / after |
| --- | --- | --- |
| Raptor and grub `walk_s`, `walk_se`, `walk_ne`, `walk_n` moved down 2 px, soles on the anchor row | `tools/anim_audit/fix_brood.py` step 1 | `fix_raptor_turn_feet.gif`, `fix_grub_turn_feet.gif` |
| Skywing `attack_e` frame 1 (a wing and a tail) replaced by frame 3 | fix_brood.py step 2 | `fix_skywing_attack_e.png` |
| Queen crest and Clutch Mound frills (built, damaged, destroyed) painted in the team keys | fix_brood.py step 3 | `fix_queen_clutch_team.png` |
| The Queen's sprite gets the team shader | `scripts/building_life.gd` | same picture |
| 166 near-key fringe pixels on about 50 unit strips snapped to the key | fix_brood.py step 4 | `fix_brute_charge_keyreds.png` |
| Raptor walk plays at 12 fps (was 8) | `Unit.WALK_FPS_ART` | `fix_raptor_walk_fps.gif` |
| Skywing hover (air idle) plays at 6 fps (was 2) | `Unit.SKYWING_HOVER_FPS`, `AnimViewer.fps_for` | `fix_skywing_hover_fps.gif` |
| A death strip longer than 1.5 s plays out after the body comes to rest (the Mist Toad) | `Unit._finish_death_strip` | `fix_mist_toad_death.gif` |
| The grub's wrap plays over the real wrapping time, 0.8 to 3 s by body size (was always 1.2 s) | `Unit._animate` "wrap" | `fix_grub_wrap_timing.png` |
| Raptor skin masks rebuilt (veterancy) | `tools/import_vet_skin.py` rerun | see below |

Notes on the fixes.

- `fix_brood.py` runs in `tools/rebuild_art.sh` right after the gait passes and before the skin masks. It is idempotent: a second run changes nothing.
- The Raptor's veterancy masks were stale. The 2026-10-24 gait pass redrew its up and down legs, but the masks were not rebuilt. A veteran Raptor walking up or down showed its old green on the new legs. Rerunning `import_vet_skin.py` fixed it. The other creatures' masks only changed where fringe pixels became team colour (they were wrongly counted as skin, so a veteran's crest rim turned amber).
- The death fix only changes the picture. The body comes to rest, joins the corpse list and starts to rot at the same moment as before.
- The wrap fix only changes the picture. Online, a guest without the corpse falls back to the old 1.2 s.

Tests run: `test_unit_walk_audit`, `test_west_views`, `test_anim_viewer`, `test_building_anim`, `test_brood_capital`, `test_ground_attack`, `test_brood_fixes` (see the end).

## How it was measured

`python3 tools/anim_audit/measure_brood.py` prints, per strip:
the frame count and play speed, the height, the foot line against the anchor, how far the feet slide, how far the body's centre moves, the biggest size pop between frames, and the key-red count per frame.
It flags empty and duplicate frames, specks, half-transparent pixels, near-key reds, team colour that comes and goes, strips the game never plays, and height or foot-line jumps between animations and between views.
`--sheets` writes the contact sheets (`sheet_<unit>.png`: every strip, every frame, 3x, blue team, anchor cross and ground line) and the GIFs the doc points at (game speed, 3x; walks also at 1x).
`tools/anim_audit/shots_brood.py` writes the before/after pictures and the redraw reference images (`refs/`).

Numbers you will see below:

- **slide** is the earlier audit's measure: the ground the unit covers in one cycle, against twice the drawn step. 1 is perfect. Above 2, the feet skate.
- **foot vs anchor** is how far the soles stand from the point the game puts on the ground. Negative is floating.
- **cx vs anchor** is how far the body's centre sits from the anchor, sideways. The west views are the east ones mirrored about the anchor, so a body off it by d px jumps 2d when it turns from east to west.

## The Grub

Sheet: `sheet_grub.png`. Speed 68. Cell 42 x 29.

Good.
- `walk_e` is a real crawl: the body undulates, the legs move, the crest bobs.
- `burrow_e` (feeding at a pit) reads well: it digs in and the dirt closes over it.
- `morph_e` (turning into a building) is the best Brood animation. The grub swells, splits and becomes a little mound.
- `death_cocoon` bursts in a purple splash: satisfying.

Problems.
- **Two creatures** (finding 1). `walk`, `idle`, `attack`, `burrow`, `morph`, `death` are the dark olive crawler, 13 to 19 px tall, with a 60 to 80 pixel blue crest. `wrap`, `carry_cocoon`, `idle_cocoon`, `death_cocoon` are a lime biped, 24 to 25 px tall, with a 10 to 30 pixel crest. It changes shape twice per haul.
- **Up and down walks barely move.** `walk_se` and `walk_ne` feet spread changes by 0 to 1 px over the cycle (slide 25x to 51x). Already on the books as prompt 19 (`docs/animation_redraw_prompts_2.md`).
- **Foot line** of the up and down walks: 2 px high. Fixed.
- **Wrap timing**: fixed, see above.
- The wrap's feet slide 3.5 to 5.5 px while it stands. It shuffles as it works the silk. Minor.
- `idle_*` is one frame in every view: a grub at rest is a statue.
- `death_cocoon` frames 3 to 5 have 194 to 267 half-transparent pixels (the purple mist). That is a soft effect inside pixel art. It reads, but it is the only soft edge on a grub.

Make it better.
- (b) Redraw the cocoon set on the real grub: prompts B1 and B2.
- (c) A two-frame idle: the crest rises and falls, or the head turns. Cheap and alive.
- (c) A "drop off" moment at the Burrow: the grub shrugs the cocoon into the hall. Today the cocoon just vanishes.

## The Raptor

Sheet: `sheet_raptor.png`. Speed 108. Cell 58 x 30.

Good.
- `walk_e` is a real run with a swinging tail. `leap_e` (the pounce when close) is fast and readable.
- `attack_e` lands the slash on frame 2, right at the hit (aim 0.1 s).
- `death_e` crumples onto its side and lies flat: a clean body.

Problems.
- **Feet skate** at 8 fps (finding 4). Fixed to 12 fps. At 12 the slide is still about 6 px a frame: the drawn stride is short for its speed.
- **Up and down walks 2 px high.** Fixed.
- **Up and down walks barely stride.** Front and back feet move 1 to 2 px. Already prompt 18.
- `attack`, `death` and `leap` exist in the east view only. A Raptor attacking something above it turns sideways to bite. It is small and fast, so this reads acceptably.
- `idle_e` stands 4 px taller than `walk_e` (24 against 20). Stopping makes it pop up a little.
- `idle_e` body sits 4 px right of the anchor: turning east to west it jumps 8 px.

Make it better.
- (b) Prompt 18 (existing) for the up and down run.
- (c) A head-cock idle: two frames, the head tilts. Raptors in groups of three standing still look like decals.

## The Spitter

Sheet: `sheet_spitter.png`. Speed 68. Cell 110 x 48.

Good.
- `attack_e` is clear: the frill flares, the jaw opens, the acid stream comes out.
- `flare_e` (the frill display) is a strong silhouette.
- `death_e` is a good heavy collapse onto the belly.

Problems.
- **East only** (finding 2). Walk, attack and death have no up or down views.
- **The body drifts 12 px** through the walk cycle (cx range 11.7). Frame 6 sits forward of frame 1, so the loop snaps back. The feet slide 4.2x.
- The attack's feet shuffle 6 px while it stands to spit.
- Idle is 45 px tall, the walk 34: stopping it rears up by 11 px. The idle pose is upright, the walk is crouched. They are two poses with no in-between.

Make it better.
- (b) Prompt B5: walk in all five views, with the body steady.
- (c) The flare used as an idle fidget: every few seconds a resting Spitter flares its frill.

## The Brute

Sheet: `sheet_brute.png`. Speed 56. Cell 120 x 67.

Good.
- The charge is the best motion in the faction: dust kicks up, the head lowers, the body leans in.
- `walk_e` matches its ground speed (slide 1.2).
- The death is heavy and the body lies right.

Problems.
- **East only** (finding 2). Walk, charge, attack and death.
- **The idle is three different drawings** (finding 8). Feet slide 20 px, the body jumps 7 px. At 2 frames a second it twitches.
- **Attack frame 5 leaves the cell.** The body jumps 25 px forward and the snout is cut by the right edge. Since the attack does not loop, the Brute holds that frame, then snaps back to idle. Picture: `problem_brute_attack_cell.png`.
- The attack shows a green spray from the mouth. It reads as spit, not as a horn blow, which is what it does.
- `charge_e` frame 1 has a rust-brown patch on the thigh that the other frames do not have.
- About 1 px of light, broken outline (white specks) runs round the body in many frames: halo from the import.

Make it better.
- (b) Prompt B3 (walk, all views) and B4 (idle and attack, east).
- (c) A snort idle: head down, a puff of breath. It is the tank; it should look impatient.

## The Skywing

Sheet: `sheet_skywing.png`. Speed 118. Cell 56 x 45.

Good.
- It has all five views of everything, in the air and on the ground. The most complete Brood unit.
- Landing reads well, and take-off is landing played backwards: a good economy.
- The ground walk (`gwalk`) is a believable wing-assisted scuttle.

Problems.
- **`attack_e` frame 1 broken.** Fixed by reusing frame 3.
- **Hover at 2 fps.** Fixed to 6.
- `idle_s` frame 2 is a tiny folded shape: 3.1x fewer pixels than frames 1 and 3. At 6 fps it is a wing flick; still the weakest frame.
- `walk_ne` has 2 frames, every other flight view 3.
- `death_n` has 1 frame: dying while flying up the screen, it just appears on the ground.
- `idle_e` body sits 9 px right of the anchor: a hovering Skywing that turns east to west jumps 18 px.
- `attack` height changes a lot between views (32 to 42 px).

Make it better.
- (b) Prompt B8: a clean attack east and a steady hover loop.
- (c) A real `death_n` (a few frames of falling).

## The Spore Mother

Sheet: `sheet_spore_mother.png`. Speed 40. Cell 68 x 100.

Good.
- ROOT (`deploy`) reads very well. She sinks, roots spread out from under her and she faces the battle.
- `fire` throws a big glowing blob from her back: clear.
- She is the only Brood beast with a real idle loop in every view.

Problems.
- **The north-east view is a copy of the east view** in all six animations (walk, idle, deploy, deployed, fire, death). Walking up and to the right she walks flat sideways.
- Rooted, she always faces the camera, in every view. It is a choice that reads, but she turns her back on a target to the north.
- 70 to 850 half-transparent pixels per strip, including the walk and idle: a soft edge round a pixel art body.
- `deploy` feet slide 5 to 14 px and the foot line moves 3 px: she settles. It reads as rooting.
- `deployed` changes only 5% of its pixels a frame: the rooted loop is nearly still.
- **Death**: only 3 frames, and the last frame has her spores frozen in the air above her body. That is what lies on the field for 3.5 minutes.

Make it better.
- (b) Prompt B9: real north-east views. Prompt B12: a clean last death frame.
- (c) The rooted loop could pulse: the sacs on her back swell and shrink.

## The Bloater

Sheet: `sheet_bloater.png`. Speed 44. Cell 56 x 61.

Good.
- The float is a soft bob with tendrils swaying. It reads as a gas bag.
- The burst death is a strong, satisfying pop of acid.
- It has deflated walk, idle and death: a full second state.

Problems.
- **Deflate starts flat** (finding 9). Frame 1 is already the empty brown sac. Switching from the full yellow idle is a pop, not a deflation.
- **The burst is the corpse.** The last frame is a cloud; the body lies as that cloud for almost 2 minutes.
- The north-east views are copies of the east ones. The sac is round, so this hardly shows.
- Its anchor is in the middle of the sac (y 36 of 61). That is deliberate: it floats over its shadow.
- 275 to 685 half-transparent pixels in the deaths: the acid mist.

Make it better.
- (b) Prompt B7: deflate from full to flat, 5 frames. Prompt B12: a burst skin on the ground as the last death frame.
- (c) The refill could swell in visible steps with a glow.

## The Mist Toad

Sheet: `sheet_mist_toad.png`. Speed 42. Cell 100 x 56.

Good.
- 14-frame walk and 13-frame tongue and death: the smoothest strips in the faction.
- The tongue only opens the mouth; the game draws the tongue itself. Clean.
- The fog spell's puff-up reads as casting.

Problems.
- **East only** (finding 2) for walk, tongue, fog and death.
- **Death froze at frame 11.** Fixed.
- `idle_e` and `idle_se` are one frame each, while `idle_s` and `idle_n` breathe (5 and 6 frames). A toad resting sideways is a statue.
- `fog_e` and `tongue_e` feet slide 6.5 to 7.5 px: the body slides a little while it casts.
- The body sits 5 px right of the anchor: it jumps 10 px when it turns.

Make it better.
- (b) Prompt B6: walk in four more views.
- (c) A throat-pouch idle for the side views (the breathing it already does from the front).

## The Queen

Picture: `refs/B10_queen_idle/1_queen.png`. A still sprite, 64 x 49, at the capital Burrow's front corner.

Good: she is a big, clear silhouette with a team crest.

Problems.
- **Team colour** (finding 5). Fixed.
- **She never moves.** Already on the owner's backlog ("Queen animation").
- She is small next to a level 3 Broodmound (the hall grows, she is scaled with it, but she reads as a pet beside a mountain).

Make it better.
- (c) Prompt B10: a 6-frame breathing idle with a crest flick.
- (c) Later: a laying animation when an egg is laid.

## Brood buildings

Sheet: `sheet_buildings.png`. Burrow (`hive`), Warren hall, Broodmound, Feeding Pit, Clutch Mound, Warren, Gorge Pit, Roost, Brood Pen.

Good.
- Every state reads. Construction is a smaller, paler shell. Damaged shows broken ribs and leaking green light. Destroyed is a collapsed ring of bones.
- The three hall levels grow believably from Burrow to Warren to Broodmound.
- No specks, no half-transparent pixels, the team spikes are keyed (except the Clutch Mound, fixed).
- The Feeding Pit greys out as its ground is used up (a tint in code): a good, cheap signal.

Problems.
- **No animation at all** (finding 10). The only motion is a green smoke puff (`Building.AMBIENT`), and the Feeding Pit's acid splash.
- **Eggs are not drawn.** The Burrow is painted with a ring of eggs that never changes. Eggs ready show only as the number "3/5". A unit hatching just appears.
- Clutch Mound team colour: fixed.
- The Feeding Pit's pool is team blue. It reads as water in the player's colour. A choice, not a bug.
- The swamp is a tiled texture with a team-coloured ripple shader. It spreads tile by tile with no creeping edge.

Make it better.
- (c) Prompt B11: an egg-hatch effect, played at the Burrow's door when a unit hatches.
- (c) Eggs on the Burrow that match the count: the importer could cut each painted egg as its own sprite, shown or hidden by `eggs`. Code only, no new drawing.
- (c) A slow "breathing" scale on the halls (1% in and out, every 3 s). Code only.

## Bodies as they rot

A Brood body lies on its last death frame, unchanged, until the rot has eaten its health.
That is about 80 s for a Raptor, 95 s for a grub, 2 minutes for a Spitter, 3.5 minutes for a Brute or a Spore Mother.
Then it fades out in 3 seconds.
Nothing shows the rot in between, and grubs harvest by how much is left.

Make it better.
- (c) Code only: darken and desaturate the body as `body_left()` falls (one tint per second, from `rot_end()`), so a fresh body and an old one look different. A player can then see which bodies are worth harvesting.
- (c) Art: two rot frames per creature (flesh sunk, then bones), shown at 50% and 20% left. That is 2 frames x 8 creatures, one sheet.

## Mirroring (the west views)

The west views are the east ones mirrored.
For the Brood this is mostly harmless: creatures have no weapon hand.
- The light comes from the upper left in the art. Facing west it comes from the upper right. On creatures this is hard to notice.
- The real cost is the turn jump: bodies drawn off their anchor jump sideways by twice the gap when they turn (Skywing 18 px, Mist Toad 10, Spitter attack 10, Raptor idle 8). A per-strip offset table in `unit.gd` could correct it; I did not add one (it would be a new mechanism, not a fix).

## Redraw prompts for ChatGPT (b)

Every prompt is standalone. Attach the images listed, in order (at most three, all in this repo).
The layout matches the sheets the importers already read: a flat navy background, rows top to bottom in the order south, south-east, east, north-east, north, frames left to right (see `tools/import_redraw_creatures.py` and `docs/animation_redraw_prompts_2.md`).
The style paragraph and background paragraph are the same in every prompt; they are written out in full in each one.
Raptor and grub up and down walks already have prompts 18 and 19 in `docs/animation_redraw_prompts_2.md`.

### B1. Grub carrying a cocoon, all five views

Save as `art/redraws/grub_carry_cocoon_v2.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B1_grub_carry/1_grub_walk_idle.png`: the grub to draw (its walk east, south, north and its idle).
2. `docs/shots/anim_audit_brood/refs/B1_grub_carry/2_current_carry_cocoon.png`: the current carry, for the cocoon and the timing only.
3. `docs/shots/anim_audit_brood/refs/B1_grub_carry/3_cocoon_and_wrap.png`: the cocoon's colours.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw the grub from reference 1 (a low, fat, dark olive crawling larva with stubby legs and a crest of spines in pure red RGB 255,0,0 with darker red RGB 150,0,0 shading along its back) carrying a silk cocoon on its back, 5 frames in each of 5 views. The grub keeps exactly the body, size, colours and crawling posture of reference 1: it stays low, it does NOT stand up, it is NOT bright lime green. The cocoon (pale lilac silk with purple shading, as in references 2 and 3) lies along its back behind the head, held by the crest spines, about as long as the grub's body. A crawling cycle: the body stretches and bunches, the legs reach and push, the cocoon bobs 1 px with the body. The crest stays visible in front of and beside the cocoon in every view. Same size in every frame, feet on the same ground line, the loop seamless. Rows: south = toward the viewer, south-east, east (side view, facing right), north-east, north = away. WHAT MUST NOT CHANGE: the grub of reference 1 (its olive colour, low body, red crest), the pixel scale. AVOID: an upright or two-legged grub, lime or yellow-green skin, a frog shape, a cocoon bigger than the grub, extra legs, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south, south-east, east, north-east, north; 5 columns, left to right = frames 1 to 5. Do NOT draw a west row. The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box of about 250 px wide and 175 px high of the sheet; in a row every figure the same size, standing on the same invisible ground line, at least 20 px of empty navy between neighbouring figures, no figure touching or cut by the image edge.
```

Import: a new `tools/import_redraw_grub_cocoon.py` on the pattern of `tools/import_redraw_creatures.py` (cut by empty columns, one scale for the sheet set from the grub's `walk_e` length, soles on the anchor row). Writes `carry_cocoon_*` (5 frames) and `idle_cocoon_*` (frames 1, 3, 1 of each row). Cell 42 x 34 like today. Then `tools/anim_audit/fix_brood.py`, `tools/import_vet_skin.py` is not needed (the grub has no veterancy).

### B2. Grub wrapping a body, all five views

Save as `art/redraws/grub_wrap_v2.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B2_grub_wrap/1_grub_walk_idle.png`: the grub to draw.
2. `docs/shots/anim_audit_brood/refs/B2_grub_wrap/2_current_wrap.png`: the current wrap, for the timing and the cocoon only.
3. `docs/shots/anim_audit_brood/refs/B2_grub_wrap/3_grub_death_cocoon.png`: the cocoon's colours.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw the grub from reference 1 (a low, fat, dark olive crawling larva with stubby legs and a crest of spines in pure red RGB 255,0,0 with darker red RGB 150,0,0 shading) wrapping a dead body in silk, 5 frames in each of 5 views. Frame 1: the grub crouches over a small shapeless dark heap on the ground in front of it. Frame 2: it spits a thin pale silk thread over the heap. Frame 3: the heap is half covered in pale lilac silk, the grub's head weaves. Frame 4: the heap is a whole lilac cocoon, the grub pushes it with its head. Frame 5: the grub has rolled the cocoon onto its back, ready to crawl (the same pose as frame 1 of a crawling grub with a cocoon on its back). The grub keeps exactly the body, size, colours and low posture of reference 1 in every frame; its feet stay on the same spot. Rows: south = toward the viewer, south-east, east (side view, facing right), north-east, north = away. WHAT MUST NOT CHANGE: the grub of reference 1, the pixel scale. AVOID: an upright or two-legged grub, lime green skin, a frog shape, blood, a recognisable dead soldier, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south, south-east, east, north-east, north; 5 columns, left to right = frames 1 to 5. Do NOT draw a west row. The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box of about 250 px wide and 175 px high of the sheet; in a row every figure the same size, on the same invisible ground line, at least 20 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: same importer as B1, writing `wrap_*` (5 frames). A matching `death_cocoon` can be built in code from the new carry frame plus the existing purple burst frames 4 and 5.

### B3. Brute walk, all five views

Save as `art/redraws/brute_walk_v2.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B3_brute_walk/1_brute_walk_e.png`: the current east walk (keep its gait).
2. `docs/shots/anim_audit_brood/refs/B3_brute_walk/2_brute_idle_views.png`: the Brute from the front, front three-quarter and back.
3. `docs/shots/anim_audit_brood/refs/B3_brute_walk/3_brute_charge_e.png`: its head and horns in motion.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw the Brute (a huge horned four-legged reptile tank: olive green skin, a domed brown shell on its back, a bony frill and a row of spikes in pure red RGB 255,0,0 with darker red RGB 150,0,0, three pale horns) walking, 5 frames in each of 5 views. A heavy walk: diagonal legs move together, the shell rocks 1 px, the head nods, the tail sways. Rows: south = walking toward the viewer (reference 2 left), south-east (reference 2 middle), east (side view facing right, like reference 1), north-east, north = walking away (reference 2 right). The body stays in the same place in its box in every frame: only the legs, head and tail move. Same size and colours in every view, feet on the same ground line, the loop seamless. WHAT MUST NOT CHANGE: the Brute's colours, shell, spikes and horns, the pixel scale, the east view's size (about 60 px long in game pixels). AVOID: a flat side view in the south or north rows, the body sliding forward across the frames, dust clouds, extra legs, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south, south-east, east, north-east, north; 5 columns, left to right = frames 1 to 5. Do NOT draw a west row. The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box of about 260 px wide and 175 px high of the sheet; in a row every figure the same size, on the same invisible ground line, at least 20 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: a new importer on the pattern of `tools/import_redraw_creatures.py`, cell 120 x 67, anchor (60, 65), writing `walk_s/se/ne/n` (keep `walk_e` unless the new one is better). Then `tools/anim_audit/fix_brood.py` and `tools/import_vet_skin.py --only brute`.

### B4. Brute idle and attack, east view

Save as `art/redraws/brute_idle_attack_e.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B4_brute_idle_attack/1_brute_idle_now.png`: the current idle (three different bodies: do not copy that).
2. `docs/shots/anim_audit_brood/refs/B4_brute_idle_attack/2_brute_attack_now.png`: the current attack (frame 5 leaves its box).
3. `docs/shots/anim_audit_brood/refs/B4_brute_idle_attack/3_brute_walk_e.png`: the Brute to keep.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw the Brute of reference 3 (a huge horned four-legged reptile tank, olive skin, a brown domed shell, red spikes in pure red RGB 255,0,0 and RGB 150,0,0, three pale horns), side view facing right, in two rows. Row 1, IDLE, 4 frames: the SAME standing body in every frame, its four feet planted on the same pixels; only small motion: the flanks swell with a breath (frames 1 to 3) and the head lowers 2 px and snorts a tiny puff (frame 4). Row 2, ATTACK (a horn blow), 5 frames: 1 the head pulls back and down, weight on the hind legs; 2 the head drives forward and up, horns leading; 3 the blow, horns at their furthest, a small white impact flash at the tips; 4 follow-through, the head swings up; 5 back to the standing pose of row 1. In the attack the feet stay planted: the body leans, it does not jump forward. No spit or acid from the mouth. Every frame of both rows fits inside the same box with room to spare in front of the horns. WHAT MUST NOT CHANGE: the Brute of reference 3, its size, the pixel scale. AVOID: different body shapes between frames, the body moving across the box, green spray, dust clouds, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: TWO rows (row 1 idle, 4 frames; row 2 attack, 5 frames), left to right = frames. The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box of about 290 px wide and 175 px high of the sheet; every figure the same size, on the same invisible ground line, at least 20 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: cell 120 x 67, anchor (60, 65), `idle_e` 4 frames, `attack_e` 5 frames (the hit lands at Brute aim 0.25 s = frame 3 at 9 fps).

### B5. Spitter walk, all five views

Save as `art/redraws/spitter_walk_v2.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B5_spitter_walk/1_spitter_walk_e.png`: the current east walk.
2. `docs/shots/anim_audit_brood/refs/B5_spitter_walk/2_spitter_idle_views.png`: the Spitter from the front, front three-quarter and back.
3. `docs/shots/anim_audit_brood/refs/B5_spitter_walk/3_spitter_attack_e.png`: its head, frill and throat sac.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw the Spitter (a stocky four-legged reptile, olive green with a pale yellow throat sac, a frill and back spines in pure red RGB 255,0,0 with darker red RGB 150,0,0) walking, 6 frames in each of 5 views. A low prowl: diagonal legs move together, the head stays level, the tail sways. The body stays in the same place in its box in every frame: only the legs, head and tail move (the current east walk slides the body forward 12 px across the cycle: do not do that). Rows: south = toward the viewer (reference 2 left), south-east (reference 2 middle), east (side view facing right, like reference 1), north-east, north = away (reference 2 right). Frill folded flat while walking. Same size and colours in every view, feet on the same ground line, the loop seamless. WHAT MUST NOT CHANGE: colours, frill, spines, throat sac, the pixel scale, the east view's size. AVOID: the frill raised, acid, a flat side view in the south or north rows, extra legs, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south, south-east, east, north-east, north; 6 columns, left to right = frames 1 to 6. Do NOT draw a west row. The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box of about 210 px wide and 175 px high of the sheet; in a row every figure the same size, on the same invisible ground line, at least 20 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: cell 110 x 48, anchor (55, 46), `walk_*` 6 frames. Then `fix_brood.py` and `import_vet_skin.py --only spitter`.

### B6. Mist Toad walk, four more views

Save as `art/redraws/mist_toad_walk_v2.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B6_mist_toad_walk/1_toad_walk_e.png`: the current east walk (keep it).
2. `docs/shots/anim_audit_brood/refs/B6_mist_toad_walk/2_toad_idle_views.png`: the toad from the front, front three-quarter and back.
3. `docs/shots/anim_audit_brood/refs/B6_mist_toad_walk/3_toad_idle_e.png`: the toad side-on at rest.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw the Mist Toad (a huge warty toad, dark mossy green-grey with yellow speckles, a pale yellow throat and belly, a ridge of spines in pure red RGB 255,0,0 with darker red RGB 150,0,0) walking, 8 frames in each of 4 views: south (toward the viewer, like reference 2 left), south-east (reference 2 middle), north-east, north (away, reference 2 right). A heavy waddle: the front legs step, the body rocks and settles, then the back legs push; the belly sags 1 px on each step. The body stays in the same place in its box in every frame. Same size and colours in every view, feet on the same ground line, the loop seamless. WHAT MUST NOT CHANGE: the toad's colours, warts, spines and size, the pixel scale. AVOID: a hop or jump, the tongue out, fog, a flat side view, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FOUR rows, top to bottom: south, south-east, north-east, north; 8 columns, left to right = frames 1 to 8. Do NOT draw an east or west row. The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box of about 170 px wide and 220 px high of the sheet; in a row every figure the same size, on the same invisible ground line, at least 15 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: cell 100 x 56, anchor (50, 54); look at `tools/import_mist_toad.py` (it keys a black sheet; this one is navy). Writes `walk_s/se/ne/n`, 8 frames. Then `import_vet_skin.py --only mist_toad`.

### B7. Bloater deflating, from full to flat

Save as `art/redraws/bloater_deflate_v2.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B7_bloater_deflate/1_bloater_idle.png`: the full Bloater (the first frame).
2. `docs/shots/anim_audit_brood/refs/B7_bloater_deflate/2_bloater_deflate_now.png`: the flat Bloater (the last frame) and its flat float.
3. `docs/shots/anim_audit_brood/refs/B7_bloater_deflate/3_bloater_death.png`: its colours as the acid leaves it.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw the Bloater (a floating gas sac creature: a glowing yellow-green bladder in a frame of brown ribs, dangling tendrils below, a small crest in pure red RGB 255,0,0 and RGB 150,0,0 on top) deflating, 5 frames in each of 5 views. Frame 1: exactly the full Bloater of reference 1. Frame 2: the bladder shrinks a third, wrinkles appear, a thin puff of green gas leaves a vent. Frame 3: half empty, the glow dims, the ribs show. Frame 4: almost empty, the sac sags between the ribs. Frame 5: exactly the flat brown Bloater of reference 2. The crest stays at the same height and place in every frame; the tendrils hang the same. Rows: south, south-east, east (facing right), north-east, north. WHAT MUST NOT CHANGE: the full and flat Bloaters of references 1 and 2, the pixel scale. AVOID: an explosion, acid drops, the creature falling, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: FIVE rows, top to bottom: south, south-east, east, north-east, north; 5 columns, left to right = frames 1 to 5. Do NOT draw a west row. The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box of about 250 px wide and 175 px high of the sheet; in a row every figure the same size, the crest at the same height, at least 20 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: cell 56 x 61, anchor (28, 36), `deflate_*` 5 frames; `refill_*` can be the same frames played backwards (code: one line in `Unit._animate`).

### B8. Skywing hover and attack

Save as `art/redraws/skywing_hover_attack.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B8_skywing_hover_attack/1_skywing_flight.png`: the Skywing flying (east, south) and hovering (south).
2. `docs/shots/anim_audit_brood/refs/B8_skywing_hover_attack/2_skywing_attack.png`: the current attack, east and south-east.
3. `docs/shots/anim_audit_brood/refs/B8_skywing_hover_attack/3_skywing_land.png`: the Skywing's body clearly, side-on.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw the Skywing (a lean charcoal-grey flying reptile with bat-like wings whose membranes are pure red RGB 255,0,0 with darker red RGB 150,0,0 edges, a long whip tail, pale claws) in two animations, in 5 views each. Rows 1 to 5, HOVER, 4 frames: it hangs in the air in one place, wings beating: 1 wings fully up, 2 wings level and spread, 3 wings fully down, 4 wings level again; the body and tail stay in the same place and the same size in every frame. Rows 6 to 10, SPINE VOLLEY, 3 frames: 1 the wings sweep up and back, the body rears; 2 the wings snap forward and a fan of 3 to 5 thin pale spines leaves them toward the target; 3 the wings recover to level. The whole body is in every frame. Rows in each set: south (toward the viewer), south-east, east (facing right), north-east, north (away). WHAT MUST NOT CHANGE: the Skywing of the references, its colours and size, the pixel scale. AVOID: a frame with only a wing, a tiny folded shape, the body changing size, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: TEN rows: rows 1 to 5 hover (south, south-east, east, north-east, north), 4 frames each; rows 6 to 10 spine volley (same order), 3 frames each. The image is portrait, 1024 by 1536 pixels. Each figure must fit in a box of about 200 px wide and 135 px high of the sheet; in a row every figure the same size, at least 15 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: cell 56 x 45, anchor (28, 43); `idle_*` 4 frames, `attack_*` 3 frames. Then `fix_brood.py` (its step 2 skips a healthy frame 1) and `import_vet_skin.py --only skywing`.

### B9. Spore Mother, the north-east view

Save as `art/redraws/spore_mother_ne.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B9_spore_mother_ne/1_spore_mother_e.png`: walking and standing, east.
2. `docs/shots/anim_audit_brood/refs/B9_spore_mother_ne/2_spore_mother_n.png`: walking and standing, north (back view).
3. `docs/shots/anim_audit_brood/refs/B9_spore_mother_ne/3_spore_mother_se.png`: walking south-east (the three-quarter view to mirror in spirit).

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw the Spore Mother (a huge slow four-legged beast, grey-brown hide, a back covered in glowing lime-green spore sacs held in a net of brown roots, a few spines in pure red RGB 255,0,0 and RGB 150,0,0) in the NORTH-EAST view only: walking away from the viewer and to the right, three-quarter back view (halfway between reference 1, side view facing right, and reference 2, back view). Row 1, WALK, 4 frames: a slow heavy walk, diagonal legs together, the sacs bounce 1 px. Row 2, IDLE, 3 frames: standing, the sacs swell and shrink gently. The body stays in the same place in its box in every frame. WHAT MUST NOT CHANGE: her colours, sacs, roots, spines and size (the same as references 1 to 3), the pixel scale. AVOID: a pure side view (that is reference 1), spores in the air, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: TWO rows (row 1 walk, 4 frames; row 2 idle, 3 frames). The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box of about 300 px wide and 400 px high of the sheet; every figure the same size, on the same invisible ground line, at least 20 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: cell 68 x 100, anchor (34, 97); `walk_ne` 4 frames, `idle_ne` 3. (Deploy, fire and death north-east can keep the east copies until they are drawn.)

### B10. The Queen breathing (new animation)

Save as `art/redraws/queen_idle.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B10_queen_idle/1_queen.png`: the Queen to animate.
2. `docs/shots/anim_audit_brood/refs/B10_queen_idle/2_burrow_built.png`: the Burrow she sits at, for scale and light.
3. `docs/shots/anim_audit_brood/refs/B10_queen_idle/3_grub_idle.png`: a grub, for the faction's style.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Animate the Brood Queen of reference 1 (a huge squat insect-reptile matriarch: olive and moss-green armoured back with pale spikes, a swollen glowing amber egg sac, a fanged head with a crest in pure red RGB 255,0,0 and darker red RGB 150,0,0), lying in the same pose and the same place in every frame, 6 frames, one row, a seamless loop: 1 at rest; 2 the egg sac swells slightly and glows brighter; 3 the sac at its fullest, the crest rises a little; 4 the head turns 2 px toward the viewer, jaws part; 5 the jaws close, the crest settles, the sac shrinks; 6 almost back to frame 1. Only the sac, the crest, the head and the breath move; the legs and body outline stay on the same pixels. WHAT MUST NOT CHANGE: the Queen of reference 1 exactly (shape, size, colours, outline), the pixel scale. AVOID: moving legs, the body sliding, eggs on the ground, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: ONE row of 6 frames. The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box of about 240 px wide and 190 px high of the sheet; every figure the same size, on the same invisible ground line, at least 15 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: extend `tools/import_queen.py` to write a 6-frame strip `assets/buildings/brood_queen_idle.png` (64 x 49 cells); `building_life.gd` plays it at 3 fps (the Queen sprite has `hframes`, like the Armoury's inventor).

### B11. An egg hatching (new effect)

Save as `art/redraws/brood_hatch.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B11_hatch/1_burrow_built.png`: the Burrow and its painted eggs (match these eggs).
2. `docs/shots/anim_audit_brood/refs/B11_hatch/2_raptor_grub.png`: Brood creatures for the style.
3. `docs/shots/anim_audit_brood/refs/B11_hatch/3_grub_cocoon_death.png`: a Brood splash, for the colours of the slime.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw a single Brood egg hatching, 6 frames, one row: 1 an upright yellow-green leathery egg with darker veins (exactly like the eggs round the Burrow in reference 1) standing on the ground; 2 the egg bulges and wobbles; 3 a crack opens at the top with a little green light inside; 4 the shell splits into three petals, a splash of pale green slime; 5 the petals fall open, slime drips, a small puff of green mist; 6 the empty broken shell lying open on a small slime puddle. No creature is drawn (the game draws the unit that walks out). The egg stands in the same place in every frame. WHAT MUST NOT CHANGE: the egg's look from reference 1, the pixel scale. AVOID: a creature, blood, red colours, text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: ONE row of 6 frames. The image is landscape, 1536 by 1024 pixels. Each frame's egg must fit in a box of about 220 px wide and 220 px high of the sheet; at least 20 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: an effect strip `assets/effects/brood_hatch.png` (6 frames, about 20 x 20 game px) in `ArtData.EFFECTS`, played where a hatched unit appears.

### B12. Bodies that lie right (last death frames)

Save as `art/redraws/brood_remains.png`.

Attach:
1. `docs/shots/anim_audit_brood/refs/B12_remains/1_deaths_now.png`: the Bloater's burst (its last frame is a cloud).
2. `docs/shots/anim_audit_brood/refs/B12_remains/2_spore_mother_death.png`: the Spore Mother's death (spores frozen in the air).
3. `docs/shots/anim_audit_brood/refs/B12_remains/3_spitter_death.png`: a good Brood body on the ground, the model to follow.

```
The attached images are reference sprites (numbered as listed); do not copy their labels or enlargement. Draw two dead Brood creatures lying on the ground, one frame each, side view facing right, in the style of the Spitter's last death frame (reference 3: the body flat, still, clean outline, nothing in the air). Row 1: the Bloater after it burst: its torn empty sac and ribs collapsed in a heap on a small dried acid stain, tendrils limp, its small crest in pure red RGB 255,0,0 and RGB 150,0,0 still on top (colours from reference 1). Row 2: the Spore Mother dead: her body slumped flat, the sacs on her back burst and grey, roots limp, no spores in the air (colours from reference 2). Then a second frame of each, ROTTED: the same body sunk and darker, bones and ribs showing. WHAT MUST NOT CHANGE: the creatures' colours and size from references 1 and 2, the pixel scale. AVOID: clouds, mist, floating spores, blood pools, any text.

Pixel art for a 16th to 18th century European gunpowder RTS, three-quarter top-down view like a classic RTS. Hard square pixels with NO anti-aliasing, no blur, no gradients, no glow, no dithering noise; a flat limited palette with painted soft shading in two or three tones per colour; a dark near-black outline of the same weight (one game pixel) around every figure; the same pixel scale and palette as the references (each game pixel drawn as a clean square block of about 4 by 4 sheet pixels).

Background: one flat solid dark navy colour, exactly #001630 (RGB 0, 22, 48), everywhere, with NOTHING else on it: no title, no labels, no numbers, no grid or cell lines, no ground tile, no cast shadow, no frame borders. Layout: TWO rows of 2 frames (dead, rotted): row 1 Bloater, row 2 Spore Mother. The image is landscape, 1536 by 1024 pixels. Each figure must fit in a box of about 600 px wide and 400 px high of the sheet; at least 30 px of empty navy between neighbours, nothing touching or cut by the image edge.
```

Import: the dead frame is appended to `death_*` and `ddeath_*` (all views can share it at first; the strip's frame count goes up by one in `art_data.gd`). The rotted frame is for the rot idea above.

## New animations that would add the most life (c)

In order of value for the work.

1. **Eggs and hatching at the Burrow.** The Burrow's eggs shown one by one (code, cutting the painted eggs), and B11 played when a unit hatches. It makes the Brood's production visible, like the Barracks drill does for the Crown.
2. **Queen idle** (B10). She is the faction's face and sits at the capital all game.
3. **Rot you can see.** A tint by `body_left()` (code only). It tells the Brood player which bodies are still worth a grub's trip.
4. **Idle fidgets** for the creatures that stand as statues: grub (crest), Raptor (head cock), Spitter (frill flare, already drawn), Brute (snort, B4), toad side views (throat). Each is 2 to 4 frames in one view, played now and then, not in a loop.
5. **A grub drop-off** at the Burrow: the cocoon rolls into the hall. Two or three frames.
6. **Hit reactions.** No Brood creature flinches when hit. A one-frame flinch (the body squashed 1 px and flashed) can be done in code for all of them, like the white flash the shader already has.
7. **A victory roar** for the Brute and the Spitter (the flare), played when a fight around them ends.

## Numbers (the full printout)

Run `python3 tools/anim_audit/measure_brood.py`. The main numbers per unit:

| Unit | Views drawn | Walk slide (E) | Biggest problems in numbers |
| --- | --- | --- | --- |
| Grub | all five for walk, idle, cocoon set; E only for attack, burrow, morph, death | 3.2x (8 fps) | cocoon set 25 px tall vs walk 17; walk_se/ne step 0 to 1 px |
| Raptor | all five for walk and idle; E only for attack, leap, death | 2.7x at 8 fps, about 1.8x at 12 | up/down walks were 2 px high (fixed) |
| Spitter | E for everything; idle also S, SE, N | 4.2x | body drifts 11.7 px through the walk; idle 45 px tall vs walk 34 |
| Brute | E for everything; idle also S, SE, N | 1.2x | idle feet slide 20 px; attack frame 5 cut by the cell |
| Skywing | all five for everything | (flies) | attack_e frame 1 broken (fixed); idle_s frame 2 has 3.1x fewer pixels |
| Spore Mother | all five, but NE = E copies | 0.4x (legs and roots: unreliable) | 70 to 850 half-transparent px per strip; death ends with spores in the air |
| Bloater | all five, NE = E copies | (floats) | deflate frame 1 already flat; burst cloud is the body |
| Mist Toad | E for walk, tongue, fog, death; idle all four views | 1.2x | death stopped at frame 11 of 13 (fixed); idle E and SE 1 frame |

## Decisions I made (the owner was away)

- I fixed only what is technical and safe. No art was redrawn, no stats changed.
- The pixel fixes live in one idempotent script in my folder (`tools/anim_audit/fix_brood.py`), run by `tools/rebuild_art.sh`, so a full art rebuild keeps them.
- I did not slow or speed the Spitter, Brute, toad or grub walks. Their slide numbers are rough for four-legged creatures, and frame rates alone barely change them. Only the Raptor's slide was clearly bad.
- I did not add a per-strip anchor offset for the mirror jump. It would be a new mechanism, and the creatures' bodies are long and asymmetric by nature.
- I did not commit a GIF of every strip (186 files). The doc's GIFs and every contact sheet are committed; `measure_brood.py --sheets --all-gifs` makes the rest.
- I treated the Queen's crest and the Clutch Mound's red frills as team colour, like every other Brood crest. If the owner wanted the mound's frills always red, revert step 3 for it in `fix_brood.py`.

## Tests

- `test_unit_walk_audit`: ALL PASS.
- `test_west_views`: ALL PASS.
- `test_anim_viewer`: PASS.
- `test_building_anim`: ALL PASS.
- `test_brood_capital`: ALL PASS.
- `test_ground_attack`: PASS.
- `test_brood_fixes`: its Clockwork case (g) fails, and the same case fails on main without these changes (main also failed (a) and (c) in one run: flaky). The test then runs on past its end; it was stopped by its time limit in both runs. Nothing in it touches animation.
