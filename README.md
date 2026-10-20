# Pocket RTS

**Play in your browser: https://cavaleirobrancopensante.github.io/PocketRTS/**

A StarCraft / Beyond All Reason style real-time strategy game for phones and the browser, made in Godot 4.7 with NES-style pixel art. Play a 1v1 **skirmish** against the computer: choose your faction, the enemy's and the difficulty (or watch AI vs AI). Two factions are playable: **the Crown** and **the Brood**; the Clockwork is coming.

See [GAMEPLAN.md](GAMEPLAN.md) for the design, the three planned factions and all the art prompts.

## How to play

Destroy every enemy building to win.

### The Crown

- **Labourers** mine gold and carry it to the **Town Hall**. Train more there.
- **Cottages** add supply (8 each, max 100).
- **Barracks** train **Musketeers** (ranged, long reload) and **Pikemen** (tough melee, deal heavy damage to cannons).
- The **Foundry** (needs a Barracks) casts **Field Cannons**: long range, splash damage, smash buildings, can't fire at point-blank.

### The Brood
- **Grubs** burrow into a gold mine on your swamp and feed where they sit (up to 8 per mine, no trips, half damage while burrowed).
- A grub **turns into** a building and is used up. Brood structures (except Hives) must grow on your swamp.
- Every unit hatches from the **Hive's eggs** (up to 5, one every 6 s), several to an egg: **Raptors** (3 per egg, fast, flimsy), **Spitters** (2 per egg, acid strips armour), **Brutes** (charge and knock back; need a Gorge Pit).
- **Swamp** spreads from Brood structures: Brood units run faster and heal on it. Brood structures regrow damage.
- The swarm's army cap is **160** (the Crown's is 100).

### Touch
- Tap a unit to select it; double-tap to select all of that type on screen.
- Drag on the map to box-select (soldiers are picked over labourers).
- Tap the ground to move; soldiers attack anything on the way. Tap an enemy to attack it, a gold mine to gather, your own unfinished building to help build it.
- Long-press the ground to move without stopping to fight.
- Two fingers to pan, pinch to zoom; tap or drag on the minimap to jump.
- **ARMY / IDLE / HALL** select quickly. **Groups 1–3**: tap an empty one to save the selection, tap to select, hold to overwrite.
- Command card (bottom right): Move, Attack, Stop, Hold, Build, Gather; buildings show what they train, Rally and Cancel.

### Mouse and keyboard
Left click selects (click ground to deselect), left drag box-selects, right click commands, wheel zooms, middle drag or arrow keys pan. Keys: **A** attack, **M** move, **S** stop, **H** hold, **B** build, **1–3** select group, **Ctrl+1–3** save group, **Esc** cancel.

## Art pipeline

The source sheets from ChatGPT live in `art/`. `python3 tools/import_art.py` turns them into game sprites in `assets/`:

- removes the painted checkerboard (or uses real transparency),
- finds every sprite, groups them into rows (animations) and the 5 direction panels, splits frames drawn touching,
- shrinks them to the true NES pixel size,
- snaps the red team-colour parts to two exact key reds, which `shaders/team.gdshader` swaps for each player's colour,
- aligns every frame at the feet and writes `scripts/art_data.gd`.

To add a unit: put its sheet in `art/crown/`, add it to `UNITS` in the script with its row names, and run it.

## Project layout

| Path | What |
| --- | --- |
| `scripts/game.gd` | The match: map, A* pathfinding, separation, combat helpers, economy, fog of war, selection and commands |
| `scripts/unit.gd` | Units: orders (move, attack-move, attack, hold, gather, build), combat by type, animation |
| `scripts/building.gd`, `scripts/mine.gd` | Buildings (construction, production queue, damage states) and gold mines |
| `scripts/ai.gd` | Computer opponent (Easy / Normal / Hard) |
| `scripts/controls.gd`, `scripts/ui/hud.gd` | Touch and mouse input; resource bar, minimap, selection panel, command card |
| `scripts/defs.gd` | Unit and building stats: tweak balance here |
| `tools/simulate.gd` | AI-vs-AI test: `godot --headless --fixed-fps 30 --script res://tools/simulate.gd` |

## Browser version

Every push to `main` builds the game and publishes it to GitHub Pages (`.github/workflows/web.yml`). One-time setup: repo **Settings → Pages → Source → GitHub Actions**.
