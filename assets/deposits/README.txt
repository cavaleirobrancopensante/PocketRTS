Deposit sprites (made by tools/import_deposits.py from art/map/deposits.png).

saltpetre_0..3.png, ore_0..3.png
  0 = full, 1 = half mined, 2 = nearly spent, 3 = exhausted.
  canvas: 72x63 px, the same for all 8 (states swap in place)
  anchor: (36, 60) px from the top-left = the ground point: middle of the outcrop's
          base, on the ground line. Draw with centered = false and
          offset = Vector2(-36, -60), position = the footprint's bottom-centre
          (pixels below the anchor are front rubble spilling over the edge).
  footprint: 2x2 tiles (64x64 px at TILE = 32);
          the picture is 72 px wide, a little wider than the footprint.
  meant to stand in a line at the back of a base site, saltpetre and ore alternating.

saltpetre_chip.png (19x17), ore_chip.png (17x15)
  small loads a worker carries; no anchor (centre them over the carrier).

../effects/deposit_sparkle.png
  horizontal strip, 4 frames of 34x34 px, star centred in each cell; soft alpha.

../icons/saltpetre.png, ../icons/ore.png
  64x64 resource icons.
