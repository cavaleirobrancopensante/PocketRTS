# Clockwork Line: art contract (sprite sheets)

Owner-approved (2026-10-25). The prompts that produce these sheets are in docs/clockwork_line_art_prompts.md.
The game must LOAD these sprites when present and FALL BACK to code-drawn art when a file is missing.
Importer: tools/import_line_art.py (to be written with the loader) reads `art/redraws/<sheet>.png`,
keys out the navy background (0, 22, 48, tolerance 24), cuts the cells by the layout below, trims, and writes
the game files. One game tile = 32 x 32 game pixels; the buildings use the same scale (a 2x2 building is about
64 px wide, taller because of the 3/4 view).

View: a 3/4 view from above-front, square world grid (NOT an isometric diamond), like the existing Clockwork
buildings and units. Light from the top left. Hard pixels, no anti-aliasing.

## Sheets (all 1536 x 1024, flat navy background, at least 24 px of pure navy between cells)

| sheet (art/redraws/) | layout | sheet scale | meaning |
| --- | --- | --- | --- |
| line_tiles.png | 5 columns x 3 rows, cells 256 x 256 | 8x (1 game px = 8 sheet px) | 15 pipe+rail tiles, left to right, top to bottom: 1 EW, 2 NS, 3 NE, 4 ES, 5 SW, 6 WN, 7 T(N,E,S), 8 T(E,S,W), 9 T(S,W,N), 10 T(W,N,E), 11 cross, 12 cap(N), 13 cap(E), 14 cap(S), 15 cap(W) |
| line_damage.png | 4 columns x 2 rows, cells 256 x 256 | 8x | row 1: EW damaged, EW destroyed, NS damaged, NS destroyed; row 2: steam puff frames 1-4 (loop, drawn over a segment) |
| line_relay.png | 2 columns x 2 rows, cells about 760 x 500 | 4x | Pressure Relay (2x2 tiles): built, construction / damaged, destroyed |
| line_drill.png | 4 columns x 2 rows, cells 360 x 340 | 3x | Ore Drill (3x3 tiles): row 1 built, construction, damaged, destroyed; row 2 working loop, 4 frames |
| line_loco.png | 4 columns x 3 rows, cells 360 x 320 | 6x | Ore locomotive; rows: east view, south view (toward the viewer), north view (away); 4 columns = 4 animation frames. West is the mirrored east |
| line_cars.png | 3 columns x 3 rows, cells 480 x 320 | 6x | Wagons; columns: empty ore car, loaded ore car, troop car; rows: east, south, north views (static) |

Connection rule for the tiles: the pipe meets the cell edge at the exact middle of that edge, at the same height
and thickness (about 16 of 32 game px) in every tile, so neighbours join seamlessly. The rails follow the same
shape as the pipe (curves on corners, switch plates on T and cross).
