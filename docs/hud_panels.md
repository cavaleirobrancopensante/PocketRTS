# HUD frames: the unit panel and command card (0.24.6)

The owner (2026-10-30): with nothing selected only the minimap and the hotkey bar were up, which
looked odd. Now the unit panel (`Hud.panel_rect`) and the command card frame (`card_rect().grow(4)`)
are always drawn, empty when nothing is selected, with the faction's name faint in the empty panel.

- Faction: yours; watching computers or a replay, the player you look through (VIEW), or a neutral
  frame with all vision (`PanelArt.faction_for`, from `Game.fog_team`).
- Not drawn on the end screen (unless MAP VIEW).
- Clicks: `_hud_has` already owned both rects selected or not, so a click, right click or a drag
  starting on the empty panels never reaches the map (tools/test_hud_frames.gd checks it).

## Faction panel art

`scripts/ui/panel_art.gd` (class PanelArt) draws `assets/ui/panels/<faction>_panel.png` (the wide
unit panel) and `<faction>_card.png` (the command card) when they exist, else the old flat panel
(`UiStyle.draw_panel`). Factions: `crown`, `clockwork`, `brood`. They are under `assets/` so the web
build puts them in the art pack (docs/web_load.md).

Drawing: a 9-slice `StyleBoxTexture` (cached per faction and kind), scaled from the art's height
(one scale for both axes): the corners keep their shape and the long panel stretches its
middle to any screen width. The art is drawn first, behind the icons and text.

**Margins** (`PanelArt.MARGINS`, in the art's own pixels: left, top, right, bottom): the part of each
edge that must not stretch, wide enough to hold the corner ornaments. The edges and middle repeat
(TILE_FIT) rather than smear, so the ropes, rivets and planks keep their look on a wide screen.

| faction | panel art | panel margins | card art | card margins | corners |
|---|---|---|---|---|---|
| crown | 2380x220 | 95 75 95 75 | 832x400 | 95 all | crowns (panel), fleurs-de-lis (card) |
| clockwork | 1977x220 | 85 80 85 80 | 684x400 | 80 all | cogs (panel), springs (card) |
| brood | 1435x220 | 80 110 80 75 | 633x400 | 80 120 80 85 | claws and eggs (the biggest) |

In game the art is scaled to 0.7 of the rect's height fit (`PanelArt.THIN`, about 0.35: thinner borders, so the stats row and the card's buttons stay off the corner ornaments), so a margin of 90 is ~32 screen pixels. The
card frames came out about 2:1 from ChatGPT, not 4:3: the 9-slice squeezes their middle to the
card's ~252x192.

## Importing the owner's ChatGPT sheet

1. Ask ChatGPT for ONE image per faction with TWO empty frames on a transparent or flat plain
   background, well apart: a long thin frame on top (about 7:1, the unit panel) and a squarer one
   below (about 4:3, the command card). Dark plain middles; the decoration on the borders and corners.
2. Save it as `art/redraws/ui_panels_<faction>_chatgpt.png`.
3. `python3 tools/import_panel_art.py <faction>`: finds the two frames (alpha, or the distance from
   the corner colour for a flat background, which becomes transparent), trims them, scales them to
   220 px tall (panel) and 400 px tall (card), keeping their shape, and writes
   `assets/ui/panels/<faction>_panel.png` and `_card.png`. `--sheet FILE` and `--out DIR` to try it
   elsewhere. Clean-up: alpha at or under 200 counts as background (the Brood sheet's soft glow
   halo is cut off), and each frame's box is its well-filled rows and columns only (`CORE`, a share
   of the fullest one: 0.5, the Brood 0.2 to keep its claws), which leaves out the faint smudges under
   the Crown panel and along the Clockwork panel's bottom edge. `--core` overrides it.
4. `godot --headless --import`, tune `PanelArt.MARGINS`, and look:
   `xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --script res://tools/test_hud_frames.gd`
   (screenshots in docs/shots/hud_frames/; `-- art=DIR` previews un-imported art from DIR).

The owner's three sheets (2026-10-30, art/redraws/ui_panels_<faction>_chatgpt.png) are imported and
in game; the importer was also tried on synthetic sheets (flat and transparent background).
Pictures in docs/shots/hud_frames/: `<faction>_empty.jpg` (nothing selected), `<faction>_unit.jpg`
(one unit) and `<faction>_group.jpg` (all your units); the test writes PNGs, kept here as JPGs to save room.
