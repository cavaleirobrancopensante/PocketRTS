# Spitter redo (0.18.1, branch spitter-redo)

The owner's jobs of 2026-10-29: the Mist Toad back in its own colours, the new Spitter art from his ChatGPT sheets,
and (sent while the job ran) the Venom Challenger's own sheets.

## 1. The Mist Toad's colours

The Mist Toad is out of the venom line colour swap again: its own colours, its details in the team colour, as before
0.18.0. Taken out of `Defs.VENOM_SWAP` (scripts/defs.gd), `tools/import_venom_colours.py` UNITS, and its masks
(`assets/units/venom_masks/mist_toad/`) deleted; docs/brood_replace.md says so. The Spitter, the Venom Challenger and
the Venom Sire keep the swap. The 0.18.0 patch note is left as it was (it is what 0.18.0 did); the 0.18.1 note says
the Toad is back. Checked in game in red and blue: `lineup.png` (the Toad at the right of each row).

## 2. The new Spitter

`tools/import_spitter_redo.py` (in tools/rebuild_art.sh after `anim_audit/fix_brood.py`, before the masks) cuts the
five sheets `art/redraws/spitter_{se,s,e,ne,n}_chatgpt.png`:

- strips `walk_<d>` (6), `attack_<d>` (the spit, 6), `death_<d>` (5) and `idle_<d>` (the walk's first frame) in all five
  views; the game mirrors the west ones. Before, the Spitter had only east strips (plus one-frame idles).
- the old `flare` strip is gone: the game never played it (`flare_e` was only listed in art_data).
- the navy background keyed out with `import_brood_new.py`'s steps, feet on one line (the body's lowest row, the venom
  left out), the red spikes snapped to the team reds. The death rows are cut without the wide-frame split (the lying
  frames are twice as wide as the standing ones; the S sheet's last frame was being cut in two).
- ONE SCALE for every view (the five sheets are drawn at one size: the first walk frames cover 11.9k to 14.6k sheet px):
  the east walk is `SPITTER_LEN` = 44 game px tail to snout, about a third of the Venom Sire (125), a little over the
  Raptor (33). It was 58 before. The cell is 74x65.
- THE GLOB. The game draws its own missile when a Spitter spits (Game.acid_shot / ground_shot_fx / fog_miss), so the glob,
  its stream and its drops are taken out of spit frame 4 in every view (the pieces out of reach of the creature's core
  that are mostly venom, and loose sparkles); a little drool stays at the mouth. The shot comes on that frame (aim 0.35 s
  at 9 frames a second is the 4th frame).
- THE EAST GLOB STRAIGHTENED (the owner's ask): the east sheet's glob is cut out, turned along its own long axis (it was
  24 degrees off level) so it points straight right, and is now the Spitter's missile:
  `assets/effects/spitter_glob.png` (16x8; ArtData.EFFECTS "spitter_glob"). The Shot turns it along its flight, so it
  flies straight at its target from any view. `Game.venom_glob(u)` picks `<kind>_glob` when there is one, else the old
  small `acid_ball` (the Venom Sire keeps that).
- the veterancy skin masks (`import_vet_skin.py --only spitter`) and the venom swap masks (`import_venom_colours.py
  --only spitter`) were made again for the new strips (the old `flare` masks went with them).
- the card's portrait is kept (the painted round 11/13 head: already a young Spitter's head without a ruff). A crop of
  the growth concept was tried and looked worse.

### Weak frames (Spitter)

- E walk: the legs move little from frame to frame (a shuffle more than a stride); NE walk the same.
- S, SE and E death frame 1: the creature rears up FACING THE VIEWER (a front view in the middle of a side-view death);
  the owner knew of the S one. In the S death the turn from that front view to the lying side view is abrupt.
- N death frames 4-5 are drawn smaller than the other views' lying frames (their bodies cover about 60% as much).
- NE and N deaths end facing right/east (accepted by the owner).
- Spit frame 4 in S and N: with the glob gone (it flew down / up), the pose is the same as frame 3 with the ruff open;
  reads fine in game.

## 3. The Venom Challenger's own sheets

All five `art/redraws/venom_challenger_{se,s,e,ne,n}_chatgpt.png` are in (main 5198368a). `tools/import_brood_mature.py`
now cuts them exactly as the Spitter's (`import_spitter_redo.build`) when all five exist: one scale, the east walk
`VENOM_LEN` = 88 game px ("about twice a Spitter", 0.7 of the Venom Sire, the concept's middle size), the glob out of
spit frame 4, the east glob (13 degrees off level) straightened into `assets/effects/venom_challenger_glob.png` (22x8).
Walk, spit, death and idle in every view (before: the Venom Sire's frames at 80%, death only south-east). The Venom Sire
stand-in and its line in docs/art_style_inconsistency.md are gone; its venom swap masks were made again (20 strips).
Its portrait is still the concept crop.

Weak frames (Venom Challenger): the NE walk is stiff (little leg movement), as the owner said; every death ends side-on
facing east (accepted); SE spit frame 4 lunges forward a little more than the frames round it.

## Sizes now (east walk, tail to snout, game px)

Raptor 33, Spitter 44, Tyrant Challenger 61, Venom Challenger 88, Venom Sire 125: small < medium < big.

## Pictures (docs/shots/spitter_redo/, tools/shot_spitter_redo.gd)

Two allied Brood sides (red and blue), a row each: Raptor, two Spitters, Venom Challenger, Venom Sire, Mist Toad.

- `lineup.png`, `lineup_close.png`: standing, facing south-east.
- `walk.png`, `walk_west.png`: walking east, then west (the mirrored views).
- `spit_06.png` .. `spit_09.png`: the Spitters and Challengers spitting at Crown labourers (the straight globs in flight);
  `spit_close.png`: the four, cropped.
- `death_0.png` .. `death_2.png`: dying.

## Tests

test_brood_new (0 failures), test_unit_stats, test_files (1224 checks, 0 failures), test_i18n, test_replay (ALL OK),
test_stun_mark (0 failures), test_anim_viewer: all pass.

## Questions for the owner

1. The Spitter's size: 44 px long (a third of the Sire, as asked) is smaller than before (58). The concept drew the young
   about half the Sire's length; `SPITTER_LEN` in tools/import_spitter_redo.py changes it in one place.
2. The Venom Challenger at 88 px is near the Sire (125) on screen; `VENOM_LEN` in import_brood_mature.py if it should
   be smaller.
3. Should the Venom Sire get the same straight comet glob (from his own east spit frame) instead of the small acid ball?
4. Redraws worth asking for: the Spitter's E and NE walks (more stride), and its S/SE/E first death frame (a side-view
   rear-up instead of the front-facing one).
