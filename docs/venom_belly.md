# The venom belly (0.18.2, branch venom-belly)

The owner (2026-10-29 18:05) on the venom line's colour swap of 0.18.0/0.18.1 (whole body in the team colour, spikes and
frill olive): "a good idea, it still is, but the whole body is too much". The new look for the Spitter, the Venom
Challenger and the Venom Sire (art "dilophosaurus"):

- the spikes on the back and the frill/hood: the team colour, as on every Brood creature (the key reds as painted take
  the normal path of shaders/team.gdshader; the olive spikes are gone);
- the body scales: olive-green as painted;
- the team colour on the BELLY (throat, chest, belly, the underside of the tail) and on a STRIPE of scales along the
  middle of each flank, both with their shading kept (the tone ramp of 0.18.0);
- the venom glow (glands, drool, glob), claws, teeth and eyes: as painted. The Mist Toad is not in this (0.18.1).

## How

`tools/import_venom_colours.py` (in tools/rebuild_art.sh after the skin masks) writes one mask per strip,
`assets/units/venom_masks/<unit>/<anim>_<dir>.png`: R = a belly or stripe pixel, G = its tone (its rank among all that
creature's marked pixels), B = 0. Only the olive-to-cream skin (tools/import_vet_skin.py's skin, hues 0.095 to 0.30, not
the venom's limes) is ever marked. Each frame is read on its own:

- **Side and three-quarter views (E, SE, NE; W, SW, NW are mirrored in game).** Per column, the back line (the first
  creature pixel under the spikes) and the belly line. The belly line is the lowest pixel of the creature's CORE (the
  creature opened with a disk 15% of its length across, its biggest piece: the shins and feet drop out, the torso, neck
  and head stay), and the body is never thicker than 1.1x its thickest standing (the idle frame of that view), so a
  leg straight under a rearing body is not belly. Both lines are smoothed along the body (median, then mean). The
  belly: the lowest 30% between them, from the tail's tip to under the jaw; NE is seen from behind, so there only the
  tail's underside. The stripe: centred half way down, 16% of the thickness (2 to 4 px), from behind the shoulder down
  the tail while the body is at least 5 px thick (constants BELLY, STRIPE_AT, STRIPE_W, TCAP at the top of the tool).
- **Front (S) and back (N).** Per row, from the spine (the key reds in the middle) out to each side's edge, the stripe
  half way on both flanks. The S view also gets the throat and chest: the skin just under the head in the middle. The
  N view shows only the spines and the two flank stripes.

`shaders/team.gdshader`: the olive ramp is gone; on a marked pixel the venom path puts the team ramp (outline darks
kept), and a veteran's marked pixels mix half of the veterancy skin in, as before. Every other pixel (the olive scales
included) takes the veterancy skin as on any Brood creature, so a 25-kill Spitter is amber with an amber-team belly and
stripe, a 50-kill one obsidian. Nothing in the game code changed (VetLook, Defs.VENOM_SWAP: comments only).

## Checks

- Contact sheets per unit and view, `docs/shots/venom_belly/contact/<unit>_<view>.png`: every strip of that view, as
  painted, then red, blue, green, purple (`python3 tools/import_venom_colours.py --contact DIR`).
- In game (`tools/shot_venom_belly.gd`): two allied Brood sides, Raptor, Spitter, Venom Challenger, Venom Sire, a
  25-kill and a 50-kill Spitter: `red_blue.png` (wide), `red_blue_{se,e,w,s,n}.png` (closer, each facing), and the
  same `green_purple*`.
- Tests: test_brood_new, test_unit_stats, test_files, test_i18n, test_replay.

## Weak spots

- The art has no clearly painted pale belly (the underside is a slightly lighter olive), so the belly is found by shape,
  not colour. In rearing spit frames the frill covers the chest, so less belly shows there; in some frames a bit of the
  upper foreleg or thigh where it overlaps the body's underside takes the colour.
- The S and N stripes are drawn as two lines either side of the spines; at the Spitter's size they sit close to them.
- Green on olive reads weaker than the other colours (the belly and stripe are lighter green, the spikes still clear).
