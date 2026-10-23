# Animation packs: Armoury, Barracks, Horse Breeder

**Status (2026-10-23): in progress. Goal: finish the Barracks, Horse Breeder and Armoury animation packs.**
Other agents: read this before touching building art or `building.gd` animation, and update the
status lines below as work lands (one line per pack, newest state wins).

| Pack | Art | Import script | In game |
| --- | --- | --- | --- |
| Armoury research experiments (9) | **delivered**, 6 sheets in `art/crown/armoury_anim/` | not written | not started |
| Barracks | not specified yet (the user will add the list) | not written | not started |
| Horse Breeder | not specified yet (the user will add the list) | not written | not started |

Buildings today only have four still states (`assets/buildings/<kind>_{built,construction,damaged,destroyed}.png`)
plus code-drawn effects (`Building.IDLE_FX`, in use only). None of these packs exists in the game yet.

## Armoury: one comic experiment per research

The inventor (wild brown hair, red shirt, brown leather apron, goggles) on his patch of mossy
stone roof, with his workbench and a steel bucket, is the Armoury's research animation.
Each research gets one short **6-frame** experiment, same man, bench, bucket and ground in
every frame, his feet in the same spot, on a flat dark navy background (keyed out on import, like
`tools/import_armoury.py` does with `bg_mask`). Style reference: `art/crown/armoury.png` (the
building) and the existing sheets in `art/crown/`.

Sheets in `art/crown/armoury_anim/` (research ids from `Defs.RESEARCH`; every row is 6 frames, left to right):

| File | Rows | Research id(s) |
| --- | --- | --- |
| `armour.png` | 1 | `armour` |
| `matchlock.png` | 1 | `matchlock` |
| `flintlock_caplock.png` | 2: top flintlock, bottom caplock | `flintlock`, `caplock` |
| `bayonet_pouch.png` | 2: top bayonet, bottom pouch | `bayonet`, `pouch` |
| `charges_quadrant.png` | 2: top charges, bottom quadrant | `charges`, `quadrant` |
| `charge.png` | 1 (a wooden vaulting horse on a ramp) | `charge` |

(`charges_quadrant.png` is 1536x1024, the others 2172x724: cut by empty columns and rows like the
other importers do, do not assume a fixed grid.)

The six frames of each experiment:

1. **armour**: hammers a steel breastplate on a stand / steps back, holds up a pistol / fires, puff of smoke / smoke clears, a neat round hole in the breastplate / peeks through the hole with one eye / straightens up and scratches his head, the hole still there.
2. **matchlock**: coils a smouldering slow-match cord / clamps a matchlock musket in a vise / lowers the glowing match to the pan / small flash and puff in the pan only, the gun does not fire / leans in and blows on the pan, face smudged with soot / looks at the match, shrugs, scratches his head.
3. **flintlock**: sharpens a flint on a whetstone / fixes the flint in the cock of a flintlock in the vise / pulls the trigger, shower of sparks / the gun fires, flash at the muzzle, the vise jolts / an ember on his sleeve, he pats it out / satisfied nod, arms folded.
4. **caplock**: with tweezers places a copper cap on the nipple / raises a small mallet / taps it, a pop of light at the cap / the gun fires with a big flash, jolting out of the clamp / both hands over his ears / grins, thumbs up.
5. **bayonet**: sharpens a socket bayonet on a whetstone / fits it to the muzzle, holds it like a spear / thrusts at a pumpkin on a stand / the bayonet goes in, juice splashes / braces a foot on the stand and heaves, pumpkin stuck / the pumpkin flies off, he sits down hard holding the musket.
6. **pouch**: pours lead balls from a mould into a leather pouch / weighs it on a balance scale, pouch side low / keeps stuffing in balls, worried frown / the seam bursts, balls spray out / slips on the rolling balls, arms flailing / sits on the floor holding up one ball with a shrug.
7. **charges** (Prepared Charges): rolls paper cartridges round a dowel / ties a powder bag, stacks it on a pile / sets a lit candle beside the pile / the pile goes up in a round white puff, bags flying / stands covered in soot, hair on end / shakes himself, a cloud of soot falls off.
8. **quadrant** (Gunner's Quadrant): fixes a brass quadrant with a plumb line on a small model mortar / squints along it / lights the fuse / it fires, a small ball flies up near the top of the frame / the ball drops into the bucket with a splash / pumps his fist.
9. **charge** (Cavalry Charge): climbs onto a wooden vaulting horse at the top of a small ramp, holding a toy sabre / a spring launches the horse down the ramp / the horse charges, wobbling violently / hits a straw dummy, which bursts into straw / he loses his grip and tumbles off, flat on the ground / groans and rubs his back while the toy horse rolls to a stop.

### Image prompt (for new or redrawn sheets)

Prompt 1 (armour) is the model; the others reuse its opening paragraph and change only the experiment.

> Pixel art in the exact style, scale and palette of the attached images. Reference 1 is a row of six small isometric dioramas of an inventor on a castle rooftop: a man with wild brown hair, red shirt and brown leather apron at a wooden workbench on a patch of mossy stone roof, with a bucket. Keep this exact man, bench, bucket and ground patch. Reference 2 is the building whose roof it is, for colours and detail only. Make one single row of 6 equal square frames on a flat solid dark navy background, each frame a separate small diorama on the same patch of ground, the man's feet in the same spot in every frame, no text, numbers, borders or labels, and no other characters. The six frames tell one short comic experiment, left to right: ...

For the Cavalry Charge, add: "Reference 3 is a wooden vaulting horse on a frame, which the scientist will ride."

### Plan (proposed: confirm with the user before building the in-game part)

1. `tools/import_armoury_anims.py` (re-runnable, like `import_armoury.py`): cut each sheet into its rows and 6 frames, key out the navy, one scale for every frame, the man's feet at the same anchor, snap team reds with `snap_team`. Output `assets/buildings/armoury_anim_<research id>_<1..6>.png`.
2. `building.gd`: while the Armoury has a research at the head of its production queue (and `in_use()`), draw that research's 6 frames over the research time (frame = progress x 6); idle or empty queue shows the plain built Armoury. Frames are not saved; they follow the queue's progress.
3. A test in the style of the existing ones (`test_brood_hall`), then bump the version (`tools/bump_version.sh`) and update the README's Armoury paragraph.

## Barracks and Horse Breeder

Not specified yet. When the user gives the lists, add them here in the same form (file, frames,
what each frame shows, which building state or order plays it) and fill in the table at the top.

## Conventions for this work

- Art sheets live in `art/`, importers in `tools/import_*.py`, imported pictures in `assets/`.
  Commit the Godot `.import` and `.uid` files with the art (see the "Import files for ..." commits).
- Art-only and notes-only commits do not bump the version; any commit that changes the game does
  (`tools/bump_version.sh`, see `CLAUDE.md`).
