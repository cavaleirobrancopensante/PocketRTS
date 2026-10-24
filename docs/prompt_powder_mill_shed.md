# ChatGPT prompt 29: Powder Mill with a roofed shed over the ingredient piles

Stands alone. Attach exactly 2 images, in this order:
1. `ref1_edit_this_mill.png`: the CURRENT powder mill (8x enlarged pixel art). This is the picture to edit.
2. `ref2_style_barracks.png`: another Crown building from the same game (6x enlarged), only to show the roof slate, timber and stone style and the camera angle.

Save the answer as `art/redraws/powder_mill_shed.png`.

## Prompt

I am attaching two pixel-art images from my 2D isometric RTS game. Image 1 is the Crown faction's Powder Mill. Image 2 is another building of the same faction, only for style.

Edit image 1 and give me the SAME building, same camera angle, same pixel size, same palette and the same lighting (light from the upper left), with exactly two additions. Change nothing else: the main slate roof, the timber frame, the red banner, the barrels, the stone millstone ring on the right, the ground and its grass fringe must stay pixel-for-pixel the same as far as possible.

1. A small LEAN-TO ROOF over the three ingredient piles at the front left (the white saltpetre pile, the yellow sulphur pile and the black charcoal pile in image 1). It must follow the game's isometric camera exactly (the same 2:1 diamond projection as the main roof; the roof slopes in the same two directions as the main building's roof planes, its ridge or high edge runs along the building's left-front edge, and it is seen from above and from the front-right like the rest of the building, NOT a flat front-on slab). Use the same dark blue-grey slate tiles as the main roof, the same brown timber posts and beams (two or three posts, slightly thick, with a visible roof thickness and a lit upper edge and a darker underside), and let the roof overhang the piles a little. It must be low enough not to cover the main building's front corner post, and small enough to stay inside the current footprint of the ground patch. Under the roof you can see the three piles clearly, each kept distinct: pale crystalline white-grey saltpetre, yellow sulphur, black charcoal, each a simple rounded heap with 2-3 shades. Keep a little shadow on the ground beneath the roof.
2. A small wooden HOPPER (a square wooden funnel on four short legs, with iron bands) standing at the edge of the stone millstone ring, on the side facing the piles, with a short wooden chute leading from the hopper to the millstone. Same wood palette and outline weight as the building. A labourer will shovel the piles into this hopper.

Style rules: crisp pixel art, hard pixel edges, NO anti-aliasing, NO blur, NO smooth gradients or noise texture on the stone or slate, a limited flat palette matching image 1, a single dark outline weight like the buildings in the images, exactly the same size and position of the building inside the canvas as image 1 (so I can overlay them). Do not add any characters, text, labels, watermarks, frames or UI. Background: one flat solid navy colour, RGB (0, 22, 48), nothing else, with at least 20 pixels of margin around the building.

Output: ONE image, square or landscape, with the building centered, large (it should fill about 85% of the image height). Do not add a second view or a before/after.

## Import checklist (for me, not for ChatGPT)

- [ ] Save as `art/redraws/powder_mill_shed.png`; look at it: building unchanged except the lean-to and the hopper, roof in the right perspective, navy background.
- [ ] Importer: needs a small script (like tools/import_mill_shed.py, which currently draws the shed in code over art/crown/mill_base/powder_mill_built.png): crop to the building, box-filter down by 8 to the 124x113 sprite, key out the navy, snap to the existing palette, keep the anchor from scripts/art_data.gd (powder_mill 124x113), derive the damaged sprite by painting the same damage pass as the current damaged art (125x113).
- [ ] The labourer shovel strips (shovel_*) and the pile/hopper stand positions are in unit.gd (powder mill station): re-check where the piles and hopper land after the new art.
