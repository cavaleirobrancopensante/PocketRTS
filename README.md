# Pocket RTS

**Play in your browser: https://cavaleirobrancopensante.github.io/PocketRTS/**

A StarCraft / Beyond All Reason style real-time strategy game for phones and the browser, made in Godot 4.7 with NES-style pixel art. Play a **skirmish** with up to four players: 1v1, 2v2, you against two or three computers, or a free-for-all. Each slot picks a player (you or an Easy, Normal, Hard or **Brutal** AI), a faction, a colour and a team. If nobody is "you", the computers play and you watch. The Brutal AI micro-manages every fight and cheats (+50% income). All three factions are playable: **the Crown**, **the Brood** and **the Clockwork**.

See [GAMEPLAN.md](GAMEPLAN.md) for the design, the three planned factions and all the art prompts.

## How to play

Destroy every enemy building to win.

There are **no resources on the map**: the map is about geography, chokes and town-hall spots. Each faction builds its own economy, and every Town Hall, Hive or Clocktower allows only so many economy structures, so you grow by taking and holding expansions. Each faction's economy works differently.

### The Crown: dig in
- **Labourers** work **Farms** (up to 3 each). A farm ripens into a **280-gold harvest** all at once, faster with more hands (about 40 s with a full crew).
- The **Powder Mill** (up to 2 labourers) makes **black powder**. Every musket shot burns 1 and every cannon shot 3: no powder, no fire.
- Each **Town Hall** allows 4 Farms and 1 Powder Mill within 14 tiles. **Cottages** add supply (max 100).
- **Walls and gates** (10 and 25 gold a piece): lay them in a line (pick the start, then the end; your labourers build piece after piece). A gate opens for your side and your allies and stays shut to the enemy. Every main base sits on high ground with one ramp (two in four-player games), so a few pieces wall it off. Enemies that can't get through hack at the wall.
- **Barracks**: **Musketeers**, **Pikemen** and, once you have a Foundry, **Cuirassiers**: fast armoured horsemen, melee only. After about 2 s at the gallop the next sabre blow is a **charge**: double damage, and the enemy is thrown back and staggered. Pikes do double damage to them. **Foundry**: **Field Cannons**. **Church**: one **Missionary** per church.
- The **Missionary** walks to a wounded soldier and takes him off the field to bandage him (4 s). The soldier comes back at full health with a cross over his head and can't be bandaged again for 5 s. The Missionary can't be hurt unless he is within 8 tiles of an enemy building.

### The Brood: the swarm
- **Grubs** haul food from **Feeding Pits** (up to 5 each) to the nearest **Hive**. The farther the pit is from the Hive, the richer each load (it grows with the square of the distance), so spreading swamp pays.
- Pits and every Brood structure except Hives must grow on your swamp. **Spore Vents** spread it far. Each Hive allows 3 Feeding Pits and 1 Bone Midden.
- A grub **turns into** a building and is used up.
- **Bone Middens** turn every body that falls nearby (friend or foe) into **essence**. Brutes and Skywings cost essence.
- Every unit hatches from the **Hive's eggs** (each Clutch Mound makes the Hives lay 10% faster, up to +30%): **Raptors** (3 per egg), **Spitters** (2 per egg), **Brutes** (need a Gorge Pit) and **Skywings** (need a Roost).
- **Skywings** fly over everything, and only ranged units can hit them.
- **Spore Mothers** (need a Gorge Pit) are slow and can't attack while walking. **ROOT** her (2.5 s): she lobs big spit blobs that splash an area and spreads swamp around her. **MIASMA** (30 essence, 18 s to recover) lays a green cloud for 8 s; Brood inside heal up to 30% of their health. Clouds don't stack.
- Swamp heals the Brood and makes it faster. Army cap 160.

### The Clockwork: wind and energy
- **Winders** crank **Boilers** (up to 3 each) for **energy**; each Clocktower adds a little.
- Tap a Boiler, Ore Crusher or Clocktower to split the energy between three uses:
  - **ORE**: **Ore Crushers** turn it into ore.
  - **ASSEMBLY**: faster production.
  - **WIND**: bigger wind fields, and constructs run down slower.
- Presets: ECONOMY, BALANCED, WAR, HOLD.
- Each Clocktower allows 2 Boilers and 2 Ore Crushers nearby.
- Winders also start buildings, which then assemble themselves, and repair.
- Constructs run down (slower and weaker) outside the field of a Clocktower, Spring Tower, Charging Pylon or deployed Tesla Cart.
- The **Charging Pylon** also mends constructs.
- **Assembly Works**: **Gearknights**, **Bolt Automatons** (pierce up to 3), **Steam Walkers** and **Tesla Carts**. A Tesla Cart rolls when packed; deploying or packing takes 3 s. Deployed, it powers constructs around it and fires chain lightning that can hit flyers.
- **Stormcallers** (need a Charging Pylon) are fragile casters with a weak zap. **STORM** throws a 3-tile ring of lightning on a spot for 3 s: everything inside is **stunned** (your own units too) and enemies take damage. A storm costs 70 of the Stormcaller's 100 charge, and the charge only fills inside a Clockwork field.
- Army cap 80.

### Area damage hits everyone
Canister, round shot, cannon splash, the Steam Walker's steam, the Spore Mother's spit blobs and the Stormcaller's storm hurt your own units too, so where your men stand matters. Units only fire an area attack on their own when the enemies in it clearly outweigh the friends; an explicit ATTACK order fires anyway.

### Editor: sandbox and map editor
**EDITOR** on the main menu has two tools:

- **Sandbox**: set up any match in the usual lobby, then use the SANDBOX panel in the match. You can spawn any unit or building of any faction for any player, delete things, add resources, lift the fog, switch AIs off, speed up time (x2, x4), or take **control** of another player.
- **Map editor**: paint ground, high ground, ramps, water, fords, trees and rocks with brush sizes 1-5, and place start spots (2-4) and extra hall spots. Mirroring (2-way or 4-way) keeps maps fair. Pick the land and an optional second biome to mix. Maps are saved on the device and show up in the Skirmish map list; PLAY takes you straight there.

### Maps
Nine maps, chosen in Skirmish (or at random). Every map is mirrored, so both sides get the same ground. With three or four players it is mirrored both ways and everyone starts in a corner, with allies on the same side. There are three layouts:

- **Crossroads**: open ground with a hill in the middle.
- **Highlands**: each main base sits on high ground with a single ramp, so it's hard to rush.
- **Rivers**: a river splits the map, and three fords are the only crossings.

Six biomes: grass, autumn, desert, snow, marsh and volcanic (lava lakes). Two maps mix two biomes.

- **High ground:** units below can't see up a cliff unless one of their side is up there (or a flyer is overhead), and they can't shoot what they can't see.
- **Cliffs and ramps:** cliffs block walking and ramps don't. Flyers ignore both.

| Map | Layout | Biome |
| --- | --- | --- |
| Greenhold | Crossroads | Grass |
| Highmoor | Highlands | Autumn |
| Dune Sea | Crossroads | Desert |
| Frostfang | Highlands | Snow |
| Twin Fords | Rivers | Grass |
| Ashfall | Highlands | Volcanic |
| Mirewood | Rivers | Marsh |
| Border March | Rivers | Snow and grass |
| Red Coast | Highlands | Desert and marsh |

### Economy labels and the battle report
- Each economy structure shows its crew as **X/Y** (green when full). Farms also show a harvest bar.
- When a match ends, the **battle report** shows income and spending, units trained, killed and lost, structures built and razed, damage dealt, value destroyed, peak army and top killers, plus army, income and worker graphs over time.

### Interface layout and hotkeys
**Settings > Interface layout & hotkeys** has two fixed layouts, STANDARD and MINIMAP TOP RIGHT, and three CUSTOM slots. In a custom slot you drag the minimap, quick buttons, selection panel and command card anywhere, change the selection panel's width, and set your own letter for any command, unit or building (Backspace returns it to automatic). USE THIS LAYOUT picks the one used in matches. **Settings > In-game interface size** makes the HUD bigger or smaller; on phones it is 150% by default.

Workers' command cards have **BUILD** (halls, supply and economy) and **ADVANCED** (production and tech) instead of HOLD; soldiers keep HOLD, which stops them chasing enemies.

### Computer or mobile
On the first start the game asks where you are playing. The two control schemes are separate, and you can switch from the menu (PLAYING ON).

### Computer controls
- **Left click** selects; **Shift**-click adds or removes; **Ctrl**-click or double-click selects every unit of that type on screen. **Left drag** box-selects (Shift adds).
- **Right click** commands: move or attack, put workers on a Farm, Mill, Pit or Boiler, help build, or set a building's rally point. Right-click on the minimap sends units there.
- **Building:** the ghost follows the mouse. Click to place, **Shift**-click to place another, right click or **Esc** cancels.
- **Hotkeys:** every command-card button shows its letter. Hover for cost and details. **B** build menu (then the building's letter, e.g. **F** Farm), **A** attack, **M** move, **S** stop, **H** hold, **G** work, **D** deploy or pack, **R** rally, **X** back or cancel, **N** more.
- **1–9** select a group, **Ctrl+1–9** save one, **Shift+1–9** add it; press twice to jump to it. **F1** idle worker, **F2** army, **F3** hall, **Space** jumps to the selection.
- **Camera:** mouse wheel zooms; pan with the screen edges, the arrow keys or a middle-button drag.

### Mobile controls
- Tap a unit to select it; double-tap to select all of that type on screen.
- Drag on the map to box-select (soldiers are picked over workers). The **DRAG: BOX / PAN** switch (top right) makes a one-finger drag move the view instead.
- Tap the ground to move (soldiers fight anything on the way). Tap an enemy to attack, your own Farm, Mill, Pit or Boiler to put workers on it, your own unfinished building to help build it.
- Long-press the ground to move without stopping to fight.
- Two fingers pan and pinch to zoom; tap or drag the minimap to jump.
- **ARMY / IDLE / HALL** select quickly. **Groups 1–3**: tap an empty one to save the selection, tap to select, hold to overwrite.
- Play it held sideways: in portrait the game pauses and asks you to turn the phone.

## Music and sound

Everything is synthesised, with no samples. `tools/music/compose.py` holds the hand-written score, and `tools/make_sfx.py` makes the effects (numpy, scipy, ffmpeg). The instrument library is shared with TCG-RPG.

- **Menu**: *PocketRTS Overture*, with the Crown's call, then the Brood's swamp, the Clockwork's music box, and all three together.
- **The Crown**: *The King's Muster* (lute, recorder, shawm) and *Pike and Shot* (fife and drum, horns, timpani).
- **The Brood**: *The Warm Swamp* (drones, throat-choir, log drums) and *Hunger* (6/8 war drums, phrygian shawm).
- **The Clockwork**: *Winding the Spring* (music box, dulcimer, ticks; it slows down at the end as the spring runs out) and *Brass and Steam* (7/8 machinery, anvils, steam). It is played on a dead-straight grid, with no human timing.
- Each faction also has three more calm pieces and two more battle pieces (21 match pieces in all). Crown: *The Orchard Minuet*, *Ballad of the Lost Regiment*, *Raising the Bastion*, *Volley Fire*, *Sabres at the Ford*. Brood: *Spawning Pools*, *Moonlit Mudflats*, *The Queen Stirs*, *Teeth in the Reeds*, *The Swarm Rises*. Clockwork: *The Orrery*, *Rust and Rain*, *The Assembly Line*, *Overclock*, *Gearstorm*.
- A victory sting per faction and a defeat sting.

In a match a shuffled playlist of your faction's calm pieces plays, with an enemy faction's piece now and then. It cross-fades to battle music when fighting heats up near your units, and goes back after things are quiet. **Settings > Music player** lets you listen to every piece and choose the playlist: your faction plus a little of the enemy's (default), your faction only, everything, or only the pieces you tick.

Sound effects and voices live in `assets/audio/` and `assets/voice/`. [AUDIO_PROMPTS.md](AUDIO_PROMPTS.md) lists every file the game looks for, so a better recording can replace any sound just by taking its name. Variants `_1`, `_2`, `_3` are picked at random.

## Art pipeline

The source sheets from ChatGPT live in `art/`. `python3 tools/import_art.py` turns them into game sprites in `assets/`:

- removes the painted checkerboard (or uses real transparency),
- finds every sprite, groups them into rows (animations) and the 5 direction panels, splits frames drawn touching,
- shrinks them to the true NES pixel size,
- snaps the red team-colour parts to two exact key reds, which `shaders/team.gdshader` swaps for each player's colour,
- aligns every frame at the feet and writes `scripts/art_data.gd`.

To add a unit: put its sheet in `art/crown/`, add it to `UNITS` in the script with its row names, and run it.

`tools/rebuild_art.sh` runs the whole pipeline in order. After the general importer come passes that replace or repair parts of its output:

- `python3 tools/import_cannon2.py` builds the field cannon (horse-towed, unlimbered, firing, reloading, limbering, wreck) from the three new cannon sheets, picking the good frames and fixing the rest.
- `python3 tools/import_lightning.py` cuts the lightning effects.
- `python3 tools/make_walls.py` draws the Crown's stone wall and gate pixel by pixel (no source sheet).

Repair passes fix mistakes in the generated art, pixel by pixel:

- `python3 tools/fix_weapons.py` finds the pikeman's pike and the musketeer's musket (the thin parts sticking out of the body) and repaints them straight and the same length in every walk and idle frame.
- `python3 tools/fix_pike.py` keeps the pike full length in the thrust frames.
- `PYTHONPATH=tools python3 tools/make_aim_up.py` makes the musketeer's aim-up and fire-up frames (the soldier leans back from the hips, musket raised) used against flyers.

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
