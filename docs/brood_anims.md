# Brood animations: the cocoon, the moult, the portraits (0.21.1)

Three art jobs for the Brood (the owner, 2026-10-29). Pictures: `docs/shots/brood_anims/` (made by
`tools/shot_brood_anims.gd` and `tools/shot_brood_anims.py`).

## 1. The grub's cocoon (ChatGPT)

Sheet: `art/redraws/grub_cocoon_se_chatgpt.png` (12 frames, 2 rows of 6, navy, south-east only).
Importer: `tools/import_brood_cocoon.py` -> art key `brood_cocoon`, strip `open_se` (10 frames). Code:
`BroodRoot.cocoon_look` (scripts/brood_root.gd). Used for the Rootmaw and the Mound Turtle (the Sires use lures).

- Frames 1-2 (a larva curling and wrapping in slime) are NOT used: the owner, during the job: the Brood's grubs are
  small reptiles, not larvae. The grub walks onto the spot and its own south-east picture fades out (and squashes a
  little) while the small scaly case (sheet frame 3) fades in and grows from 55% (`MORPH_GRUB`, 0.8 s).
- Sheet frames 3-6: the case grows to full size, over the first 78% of the cocoon time (`COC_GROW`).
- Sheet frames 7-9: it glows, shakes (a code shake on top, harder as it goes) and cracks, to 92% (`COC_CRACK`).
- Sheet frames 10-11: it splits open; the shell is moved behind the creature, whose rooted picture fades in over it.
- Sheet frame 12: the empty broken shell stays on the ground 2.6 s and fades over its last 1.2 s (a picture only:
  its clock is on the node, nothing in the game state).
- Size: every frame lined up on the bottom middle of its earth, the full case's earth 96 px (3 tiles). The game scales
  it by the footprint's width times `Defs.NB["cocoon_scale"]` (Rootmaw 1.0, Mound Turtle 1.12: both footprints are 3
  wide; the turtle's is deeper and the creature bigger).
- The red spikes take the team colour (a looser snap than the lures': the sheet shades them deep red).
- GIFs: `cocoon_rootmaw.gif`, `cocoon_mound_turtle.gif` (+ `_strip.png`); the strip at 3x: `brood_cocoon.png`.

## 2. The moult (MATURE)

Code: `scripts/moult_look.gd` (called from `BroodMature.look`, `.draw` keeps only the bar, `.tick` calls
`MoultLook.finish`, `Unit._animate` calls `MoultLook.after`). Importer: `tools/import_brood_moult.py` -> art keys
`moult_venom`, `moult_tyrant`, `moult_storm` (strips `shell_se` 4, `split_se` 2, `open_se` 1, `skin_se` 1 for Venom and
Tyrant). `BroodMature.start` now turns the unit south-east (the moult is one view). Pictures only otherwise: the
moult's time and result are unchanged (9 s).

The story in game (share of the 9 s):

| when | what | made of |
|---|---|---|
| 0-12% | the young unit hunches and greys | its own first idle frame, squashed a little; the team shader's grey wash |
| 8-24% | the shell closes round it, the young one fades out inside | the shell (closed) growing from 62% x 0.75 to 62% of its size, fading in |
| 24-74% | the shell breathes and swells | the closed shell to full size, a breathing scale, its glow pulsing |
| 74-88% | it glows, shakes and cracks | the shell's 3 crack frames, a code shake |
| 88-100% | it splits, the Challenger comes out grey | the 2 split frames; the Challenger's own first idle frame fading in, grey |
| after | the Challenger regains its colour (1.2 s); the empty shell and the shed skin stay where the moult was, then fade (1.6 s + 1.4 s) | the empty shell; the shed skin (Venom, Tyrant) |

A Hatchling comes down to the ground first (its flying height eased to 0); its Storm Challenger rises from the shell to
the flying height in the last 6%, so the hand-over to the flying unit has no jump.

Shell sizes (game px, the closed shell's body): Venom 54 (Spitter 40 -> Challenger 86 wide), Tyrant 34 (Raptor 15-21
-> 48), Storm 38 (Hatchling 27 -> 74). Shed skin: 42 and 30 px long.

### What was used from the Gemini sheets, what was dropped (honest verdict)

The owner warned that Gemini's frames differ from ChatGPT's. Checked frame by frame at game size next to the Raptor,
Spitter, Hatchling, the Challengers and a cocoon frame (`moult_gemini_pieces_3x.png`, `moult_pieces_3x.png`):

- DROPPED: every Gemini frame with a creature in it (the young curling, greying, the Challenger stepping out, the
  Tyrant's red-glowing creature, the Storm flying frames). The game's own sprites do those parts.
- DROPPED: the Gemini SHELLS (closed and cracking, all three lines). Tried with the full cleaning (the navy keyed on a
  median, specks dropped, colours median-denoised, histogram-matched to the cocoon's olive, the green cracks and the
  red inside turned to the cocoon's yellow-green glow, shrunk straight to game size, unsharp, outline darkened). They
  still read as smooth, airbrushed balls ("cabbages") beside the scaly, crisply shaded ChatGPT art, their cracks are
  2-3 sheet px and vanish at game size (the crack frames hardly differ), and the Storm sheet's shells are tiny and
  blurry. Not the same quality: not used (the import keeps the attempt: `--gemini` with `--contact`).
- DROPPED: the Storm sheet's empty broken halves (tried as the open shell for all three lines: flat as the shells).
- USED INSTEAD (the owner's fallback): the COCOON sheet's case (ChatGPT, the same style as the Brood), its earth mound
  cut away (by hue: the earth is orange-brown, the case olive) with a rounded bottom, greyed 55% toward a warm stone
  grey (the Gemini concept's stone shell, kept as an idea): closed, glow/shake/crack, split, empty.
- USED from Gemini: only the SHED SKIN (the Venom sheet's; the Tyrant sheet has the same drawing), cleaned the same
  way and half-greyed olive. At 30-42 px it holds up: a small grey lizard-shaped husk.

Verdict: in game the moult now matches the rest of the art (all of it is ChatGPT-made or the game's sprites, except
the small shed skin). What it lacks: the three lines share one shell (they differ by who goes in and comes out); the
Challenger appears by a cross-fade, not drawn climbing out; the young one's "hunch" is a squash of one frame; there is
no Hatchling skin. A per-line ChatGPT moult strip (the creature curling, its own shell, the Challenger climbing out)
would be the real fix. GIFs: `moult_venom.gif`, `moult_tyrant.gif`, `moult_storm.gif` (+ `_strip.png`).

## 3. Portraits (ChatGPT)

`spitter_portrait_chatgpt.png`, `venom_challenger_portrait_chatgpt.png`, `tyrant_challenger_portrait_chatgpt.png`,
`brood_mother_stage2_portrait_chatgpt.png`, `brood_mother_stage3_portrait_chatgpt.png` -> `assets/icons/spitter.png`,
`venom_challenger.png`, `tyrant_challenger.png`, `brood_mother_2.png`, `brood_mother_3.png`, cut as the other Brood
portraits (`tools/import_brood_new.py` `portrait`: 60 px on the card's grey). That cut now finds the steel frame and
crops round it so the frame is 0.85 of the icon on every sheet: the Spitter's sheet drew its frame narrower (0.81) and
lower; the others are unchanged. Re-run: `python3 -I tools/import_spitter_redo.py --portraits`,
`python3 -I tools/import_brood_mature.py --portraits` (both also run in their full imports).

THE MOTHER'S CARD: the HUD's portrait is the icon of the unit's art key when there is one (`Hud._unit_icon`), and
`BroodNew.apply_stage` switches her art to `brood_mother_2` / `brood_mother_3`; so the two new icons named after those
keys show her current stage with no code change (stage 1 keeps `brood_mother.png`). `cards.png`: the Mother at stages
1, 2, 3, then the Spitter, Tyrant and Venom Challenger cards; `portrait_icons.png`: the six icons at 3x.

## Tests

test_brood_new, test_files, test_i18n, test_replay, test_brood_sounds: all pass. test_brood_new's "a Hatchling egg
(80 food)" check measured the payment by the food left, and the Rootmaws' food coming in during its 0.1 s wait made it
74-75 (failed twice): it now counts what was spent (`stats.spent`).
