# The Sire lures (0.19.0, branch sire-lure)

The owner's decision (2026-10-29 18:03-18:31, docs/idea_brood_mobile_buildings.md): a grub must NOT turn into a grown
Sire. It roots and swells into a LURE, a living pheromone gland (not a plant), one kind per Sire. When the lure is ripe
the Sire ARRIVES as part of its animation (in the lore from the wild pack; in the game no walk across the map), EATS it
and is yours, nesting where it was. Also: a Sire's eggs are drawn IN FRONT of his footprint, not inside his nest
picture, while he keeps his production animation.

## What changed

- **Grub to lure** (scripts/brood_root.gd "the Sire lures"). Picking a Sire on a grub's BUILD card works as before
  (the ghost on the grid, the grub walks there and pays), but what grows on the spot is his lure: the Tyrant Lure, the
  Venom Lure, the Storm Lure. The Rootmaw and the Mound Turtle keep their cocoon.
- **Game rules unchanged.** Underneath, a lure is the cocoon state of the Sire (the unit already exists, `nb["coc"]`
  counts up, his footprint is taken, his health grows from 15%). So:
  - the cost and the total time are the old morph's (Tyrant 200 food / 35 s, Venom 150 / 30 s, Storm 200 + 50 spoils
    / 40 s);
  - one of each: a lure counts as its Sire (`BroodNew.count_of`), and the Mother's stage unlocks stay;
  - a lure is rooted and attackable, does nothing (no fertilising, no pheromone bonus to the Mother) until he has come;
  - the computer player uses the same order (`AIBroodNew._nb_morphs`), so it makes its Sires through lures;
  - saves, replays and the online snapshot already carry `nb` (with `coc`) and the footprint: a lure is saved and
    continued as ripe as it was (tested).
- **Killed before he comes**: the lure is lost, no refund (as a cocoon, and as a building shot down while it goes
  up: the mistake was leaving it unguarded). Its ground is free and another lure may grow at once. It bursts in code
  (squashes and fades).
- **The card and the bar**: the name reads "Tyrant Lure" (etc.) until he arrives; the bar says LURE RIPENING, then THE
  SIRE ARRIVES; the cocoon line on the Brood's card reads "LURE Ns". When he arrives his roar plays (the cue); when he
  is rooted: "The Tyrant Sire came to the lure and ate it: he is yours, on his nest." All in en/pt/es.
- **The ROOT ghost** of a grub's BUILD shows his ripe lure on the footprint, not the Sire.
- **His eggs in front** (scripts/brood_new.gd "THE SIRE'S EGGS IN FRONT"): the eggs of his line now lie in a row just
  in front (south) of his footprint (`nest_point`: the footprint's middle, 22 px past its front edge (an egg is about 20 px tall: drawn whole below his nest picture); up to 5 a row,
  14 px apart, further rows further south), seen at once and drawn on the top layer like the Mother's (`EGG_Z`). They
  redden as he breathes on them and hatch there. Before, they lay hidden on the nest drawn in his rooted frame and only
  showed to hatch. Egg colours unchanged (the owner hasn't decided).

## The timing (Defs.NB "lure_arrive", "lure_settle")

| Sire | total | lure grows | of which swelling (4 steps) | ripe, pulsing | arrival (12 frames) | settles (his rooting frames) |
|---|---|---|---|---|---|---|
| Tyrant | 35 s | 31.2 s | 22.5 s | 8.7 s | 2.6 s | 1.2 s (from frame 1) |
| Venom | 30 s | 26.2 s | 18.9 s | 7.3 s | 2.6 s | 1.2 s (from frame 1) |
| Storm | 40 s | 36.2 s | 26.1 s | 10.1 s | 2.6 s | 1.2 s (from his first landed frame, 3) |

The swelling share is `BroodRoot.RIPE_AT` (0.72). The settle starts with a 0.36 s cross-fade from his last arrival
frame into his rooting frames.

## The art (tools/import_sire_lure.py; art keys lure_tyrannosaur, lure_dilophosaurus, lure_pterodactyl)

- `grow_se` (4): the concept's top row (art/redraws/sire_lure_concept_chatgpt.png), its yellow-green haze and scent
  holes tinted toward each Sire (red, as drawn, blue), sized so the 4th step is as wide as his ripe lure and stood on
  its mud. The game scales the steps up from about a grub's size (0.45) to full.
- `ripe_se` (1): frame 1 of his arrival sheet (exactly where the arrival starts). The game breathes it (scale x/y
  about its ground, brightness) and adds haze puffs in code in the lure's colour (Defs.NB "lure_col").
- `arrive_se` (12): the arrival sheets (art/redraws/<kind>_lure_arrive_se_chatgpt.png, 1536x1024, frames on a 256x512
  grid; a piece straying over a neighbour's slot goes to the slot nearest its middle). Row 1 is lined up on the lure's
  mud (the lure stays put), row 2 on his feet (he stands still), tied by the last frame (his feet over the mud).
- **Size**: each sheet is scaled so his last frame is as tall as his own in-game picture: the Tyrant's idle S (he ends
  facing south), the Venom's idle SE, the Storm's first landed rooting frame. Scales 0.49, 0.28, 0.38.
- **Place**: the importer prints where the lure's ground lies from his feet (Defs.NB "lure_at": Tyrant [11, 42],
  Venom [2, 16], Storm [8, 12], and the mud's width 85, 48, 52 px). In the game the lure's ground is put in the
  footprint's middle, 6 px inside its front edge (the arrival art moved with it), and eased back onto his own feet over
  the second row (his feet as drawn rooted), so his rooting frames take over where the arrival ends. The pictures hang
  in the building layer with his own (BroodRoot.layer).
- **Team colour**: the bright red spikes (his and the lure's) and the dark red right beside them are the team reds;
  the Tyrant lure's darker red haze stays red for every side (it is the lure's colour).
- Contact sheets: `python3 -I tools/import_sire_lure.py --contact DIR` (every strip on grass, and his last arrival
  frame beside his first rooting frame on the same feet).

## Weak frames and stand-ins (also in docs/art_style_inconsistency.md)

- TYRANT frame 2 (a strip of tail spikes over the haze): skipped, frame 1 held (HOLD in the importer).
- TYRANT frames 7-12 face south; his rooting frames face south-east: cross-faded (0.36 s).
- VENOM frame 9: the hole sits below his feet (as the owner said: fine); frames 7 and 10 have no mud ring.
- STORM frame 9: his hop with wings out over the hole sits a little lower; fine in motion.
- The growing lure is ONE generic concept row tinted per Sire (the Tyrant's red tint is the weakest: the concept's
  haze shapes, red). A drawn growing strip per Sire would be better.
- The ripe pulse and the haze puffs are code; the lure is small against the Tyrant's 4x3 footprint (85 px of 128): as
  drawn beside him in the sheet.
- His rooted frames still draw the nest's red eggs (that is his production loop); the game's eggs now lie in front.
  If the owner wants the nest empty, the rooted strips need a redraw (or a paint-out of the eggs).

## Open questions for the owner

1. Refund for a lure killed early: none now (as a cocoon). A part refund (say half) would soften a lost Sire; the
   design rules say a punishment should match the mistake, and the lure is a big, telegraphed target for 30-40 s.
2. Should the lure be weaker than the Sire's health curve (it starts at 15% of HIS health: 150 of 1000 for the
   Tyrant, rising)? A gland might rather have a fixed, low health.
3. Should the enemy see the lure's haze through fog as a tell (it is a pheromone plume)? Not done.
4. The eggs in front: the egg colours per Sire (Tyrant red, Venom yellow-green, Storm blue-white) are still undecided;
   unchanged for now.
5. The Storm Sire's arrival ends landed (his landing frames take over from the first landed one); fine?

## Tests

tools/test_brood_new.gd part 20 (a grub becomes a lure, the lure ripens, the Sire arrives on its spot and roots, his
eggs in front of his footprint and fertilised there, a lure killed early, one Sire at a time counts the lure, save and
load mid-lure, the computer's Sire through a lure) and the older parts' nest checks moved to the row in front.
Pictures: docs/shots/sire_lure/ (tools/shot_sire_lure.gd).
