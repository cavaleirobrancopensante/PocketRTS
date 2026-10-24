# Crown Labourer animation audit

Tools: `python3 tools/labourer_contact.py [DIR]` writes one contact sheet per pose (every
direction, every frame, plus the west views mirrored the way `scripts/unit.gd` draws them, at
4x nearest, ground line marked) and prints each frame's bounding box and feet span.
`tools/test_labourer_anim.gd` (headless) covers what was fixed in code, `tools/test_build_still.gd`
the hammering. `python3 tools/import_labourer_redraw.py [--contact DIR]` rebuilds the redrawn strips
from `art/redraws/labourer_*.png` (see below).

How the game plays him: strips `assets/units/labourer/<pose>_<dir>.png`, 42x35 cells, anchor
(21, 33), dirs s, se, e, ne, n. West views are the SAME strips mirrored (`DIR_FLIP` in
`unit.gd`: sw = se, w = e, nw = ne flipped by `sprite.scale.x = -1`; the anchor is the cell
centre so no pixel moves). A mirrored picture swaps hands: the tool in his right hand faces
west in his left. That is a limit of mirroring, not a bug; separate west drawings would be
needed to change it.

## What was wrong in code (fixed)

| Problem | Fix |
| --- | --- |
| Feet slid on the ground. The walk played at a fixed 8 fps while he moves 74 px/s. | His walk, carry and keg-carry frames follow the distance covered (`LAB_STRIDE`, 22 px per full 6-frame strip in every view), so a planted foot stays planted at any speed, on roads, slopes and in a crowd. |
| Animation ticked only 15 times a second. | A walking or hammering labourer ticks at 30 Hz. |
| Walk <-> idle flicker around the 10 px/s line when crowds push him. | 0.18 s hold in the walk when his speed dips under the line. |
| The view flipped back and forth around a 22.5 degree line. | The view only changes once he has turned 7 degrees past the edge (`_lab_view`). |
| Hammering: no pause on the raise, no weight on the strike, the 2 s hammer clip never matched. | `BUILD_SWING`: raise 0.12 s, drop 0.06 s, strike 0.12 s (held), lift 0.10 s = 0.40 s a swing (5 swings = the 2.0 s clip), re-phased by `lab_build_lock` so the clip's first big blow lands on the strike frame (frame 2 in every view). |
| Keg idle breathed at a rate that depended on the frame count. | One breath per 1.3 s whatever the frame count. |
| A gold sack with him standing still was a code-drawn yellow dot. | `idle_carry` strips (2 frames, the sack on his back in each view); `_anim_name` picks `idle_carry` when he stands carrying, and the dot is only drawn for the old poses without a sack. |

## The redraw (art/redraws, imported by tools/import_labourer_redraw.py)

Four AI-drawn sheets (navy ground, titles, numbers, labels) are cut into blobs, keyed out of the
navy, shrunk with a box filter to the 42x35 cell (hard alpha, no blur, team reds snapped to the
shader's key reds) and stood on the ground row 33. Every frame was inspected at 4x per direction.
New frame counts: walk 6, carry 6, carry_keg 6, mine 4, build 4 (was 3 in NE), idle_keg 4 (N was
2), idle_carry 2 (new); `ArtData`, `BUILD_SWING`, `STRIKE_FRAME` and `LAB_STRIDE` follow.

**Replaced with the new art as drawn (cleaned only):** the torsos, heads and arms of walk, carry,
carry_keg, idle_keg and idle_carry in all views; the build hammer frames (reordered raise, drop,
strike, lift; in E the sheet's order was 3,1,2,0); `mine` s / se / ne frames; `idle_ne` (hoe low
now, as the other views).

**Repaired (the AI got it wrong, frankensteined from its own other frames):**
- Walk, carry and keg-carry legs: the AI drew legs that do not alternate (feet at constant
  separation, sometimes both on the ground at the same angle). Per view the best-drawn legs are
  chosen, mirrored / lifted / shifted so the sequence is contact, passing, contact with the other
  foot, and pasted under each frame's own torso below the coat hem; the thighs are stretched so the
  boots stay on row 33 and the bob stays consistent. Seams smoothed.
- Idle keg and idle sack: feet taken from frame 0 so only the breathing moves.
- Build: everything below row 24 (legs, boots, stake) is copied from the strike frame into all four,
  so the body stays still and only the head, arm and hammer move (the hammer must read: 0 high,
  1 mid, 2 strike with spark, 3 lifting). The raised-hammer frames (s 0, n 0, n 3) were taller than
  the cell and have their handle shortened to fit the 34 rows.
- Mine: superseded by the hoe pass below (E and N are no longer special-cased).
- Walk carry SE frame 1 had a reddish glow (removed); carry SE frame 0 had a smudged hem (hem row
  forced); a lone red pixel in the face of keg SE frame 5 and pink / blue / maroon strays are
  recoloured.

**Kept from the old art:** nothing of the redrawn poses. `idle_s / se / e / n`, `bury_*`,
`death_*` and `death_keg_*` are untouched.

## The farm swing is a hoe (tools/import_labourer_hoe.py)

The game has no mining, only farms and the powder mill, and `mine_*` is what he plays hoeing a
farm (`_anim_name`: work "manning" on a farm), so the image-AI's pickaxe had to go. The script
runs after `import_labourer_redraw.py` and rewrites `mine_<s|se|e|ne|n>.png` (4 frames: raise,
mid, strike with soil, recover; strike = frame 2 as before, so `ArtData` and the tests are
unchanged) from `art/redraws/new_mine/` (the redraw's strips, pristine; refresh with `--snapshot`)
and keeps the original 3-frame art in `art/redraws/old_mine/` (git 37bb869) for reference.

Evaluation, every frame at 6x, old (3 frames, slimmer man, smaller head) against new (4 frames):

| | old | new |
| --- | --- | --- |
| Man | hunched in every frame, head about 10 % smaller, scaled up 1.09 it still differs in hat and shading from the walk / idle strips | bulkier, the walk / idle man |
| Raise | tool half hidden behind the head, body already stooped, so no real raise | tool up over the shoulder, clear in s, se, ne, n; E frame 0 has no raised arm and N 0 / 3 only a stub of tool |
| Mid | S, SE, NE hold the tool high behind the head (big arc); NE a long tool forward; N turned 3/4, not a back view | tool low and small (E, NE, S, SE), none at all in N |
| Strike | deep crouch (hat 6-12 rows lower than the raise: real weight), but the tool is lost in grey debris and the face is hidden | readable tool and face, soil chips, but nearly upright in E, NE and N |
| Recover | none | repeats the raise (S, SE, NE, N); E repeats the mid |

Verdict: the NEW bodies are the only ones that match the rest of the labourer set (head, coat,
trousers, line weight), and a mixed strip showed the old head and hat as a visible change of man
(the old N mid is even a different view), so no old pixel is used. What the old art did better is
reproduced instead: the **weight** (strike frames: two rows are cut out of the thighs so the body
drops with the boots staying on row 33, plus a 1 px lean in the E-facing views) and the **arc**
(redrawn tool: apex about 45 degrees up on the raise, handle sloping down with the blade leading on
the mid, long handle into the soil on the strike, rising again on the recover). The tool is erased
from each frame (hand-set boxes, coat / face / hands untouched) and redrawn.

The hoe: a 2 px wooden handle (labourer wood colours, light top, dark underside), a 1 px dark iron
neck and a flat plate about 5 px wide and 3 deep set at 80 degrees to the handle, pointing down
on the raise / mid and biting the soil on the strike (hard pixels, iron grey, a bright cutting edge,
dark outline on the outer side). The strike throws brown soil clods (the old grey stone chips are
gone). Nothing touches row 33 or column 41 (the ground-line test). The farm hoe sound
(`work/hoe`, every 2.2-3.2 s from `_work_sound`) is on a timer, not tied to a frame, so it does not
depend on the strike frame.

Not perfect: the plate is a flat shape at game scale, not seen edge-on; in the west views the
mirror puts the hoe in the left hand; E frame 0 and 3 keep the AI's hanging near arm, so the tool
comes out of one hand low at the hip; the coat hem makes a small flap at the back on the crouched
strike frames in SE, E and NE; mid and strike are similar in pose (the blade is higher in the mid).

## Still needs redrawing (code cannot fix it)

1. **No true foot slide in the art.** The AI's feet keep a constant separation, so the planted foot
   is stationary on the ground only through `LAB_STRIDE`; a real redraw would show one foot pushing
   back while the other swings.
2. **Raised-hammer frames (build s 0, n 0, n 3) and mine s 0** reach the top row of the cell
   (their handles were shortened); the hammer is smaller than the drawn proportion. The crouching
   head is about 20 % smaller than the walking head.
3. ~~`mine_n` swing frame shows no pick; `mine` is a pickaxe~~ Fixed: see "The farm swing is a hoe"
   below (the idle poses `idle_s / se / e / n` still hold the old hoe, a slightly different drawing).
4. **`bury_*` and `death_keg_*`** still use the old keg man (red cap, brown shirt and trousers, red
   sash) against the felt-hat man in a red coat everywhere else. Frame 5 of bury is also a 4 px hop.
   Redraw them in the labourer's outfit.
5. **`idle_s / se / e / n`** (hoe at his side) are the old art; they have not been redrawn with the
   new pickaxe or sack style, so the idle and carry-idle differ slightly in line weight.
6. Mirroring swaps hands in the west views (see the top).
