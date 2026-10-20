# Pocket RTS

**Play in your browser: https://cavaleirobrancopensante.github.io/PocketRTS/**

A StarCraft / Beyond All Reason style real-time strategy game for phones and the browser, made in Godot 4.7 with NES-style pixel art. Play a 1v1 **skirmish** against the computer: choose your faction and colour, the enemy's, the difficulty and the map (or set Player 1 to the computer and watch). All three factions are playable: **the Crown**, **the Brood** and **the Clockwork**.

See [GAMEPLAN.md](GAMEPLAN.md) for the design, the three planned factions and all the art prompts.

## How to play

Destroy every enemy building to win.

There are **no resources on the map**: the map is about geography, chokes and town-hall spots. Each faction builds its own economy, and every Town Hall, Hive or Clocktower allows only so many economy structures, so you grow by taking and holding expansions. Each faction's economy works differently.

### The Crown: dig in
- **Labourers** work **Farms** (up to 3 each). A farm ripens into a **280-gold harvest** all at once, faster with more hands (about 40 s with a full crew).
- The **Powder Mill** (up to 2 labourers) makes **black powder**. Every musket shot burns 1 and every cannon shot 3: no powder, no fire.
- Each **Town Hall** allows 4 Farms and 1 Powder Mill within 14 tiles. **Cottages** add supply (max 100).
- **Barracks**: **Musketeers** and **Pikemen**. **Foundry**: **Field Cannons**. **Church**: one **Missionary** per church.
- The **Missionary** walks to a wounded soldier and takes him off the field to bandage him (4 s). The soldier comes back at full health with a cross over his head and can't be bandaged again for 5 s. The Missionary can't be hurt unless he is within 8 tiles of an enemy building.

### The Brood: the swarm
- **Grubs** haul food from **Feeding Pits** (up to 5 each) to the nearest **Hive**. The farther the pit is from the Hive, the richer each load (it grows with the square of the distance), so spreading swamp pays.
- Pits and every Brood structure except Hives must grow on your swamp. **Spore Vents** spread it far. Each Hive allows 3 Feeding Pits and 1 Bone Midden.
- A grub **turns into** a building and is used up.
- **Bone Middens** turn every body that falls nearby (friend or foe) into **essence**. Brutes and Skywings cost essence.
- Every unit hatches from the **Hive's eggs**: **Raptors** (3 per egg), **Spitters** (2 per egg), **Brutes** (need a Gorge Pit) and **Skywings** (need a Roost).
- **Skywings** fly over everything, and only ranged units can hit them.
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
- Army cap 80.

### Maps
Nine maps, chosen in Skirmish (or at random). Every map is mirrored, so both sides get the same ground. There are three layouts:

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

### Touch
- Tap a unit to select it; double-tap to select all of that type on screen.
- Drag on the map to box-select (soldiers are picked over labourers).
- Tap the ground to move; soldiers attack anything on the way. Tap an enemy to attack it, your own Farm, Mill, Pit or Boiler to put workers on it, your own unfinished building to help build it.
- Long-press the ground to move without stopping to fight.
- Two fingers to pan, pinch to zoom; tap or drag on the minimap to jump.
- **ARMY / IDLE / HALL** select quickly. **Groups 1–3**: tap an empty one to save the selection, tap to select, hold to overwrite.
- Command card (bottom right): Move, Attack, Stop, Hold, Build, Work (Deploy/Pack for Tesla Carts); buildings show what they train, Rally and Cancel.

### Mouse and keyboard
Left click selects (click ground to deselect), left drag box-selects, right click commands, wheel zooms, middle drag or arrow keys pan. Keys: **A** attack, **M** move, **S** stop, **H** hold, **B** build, **1–3** select group, **Ctrl+1–3** save group, **Esc** cancel.

## Music and sound

Everything is synthesised, with no samples. `tools/music/compose.py` holds the hand-written score, and `tools/make_sfx.py` makes the effects (numpy, scipy, ffmpeg). The instrument library is shared with TCG-RPG.

- **Menu**: *PocketRTS Overture*, with the Crown's call, then the Brood's swamp, the Clockwork's music box, and all three together.
- **The Crown**: *The King's Muster* (lute, recorder, shawm) and *Pike and Shot* (fife and drum, horns, timpani).
- **The Brood**: *The Warm Swamp* (drones, throat-choir, log drums) and *Hunger* (6/8 war drums, phrygian shawm).
- **The Clockwork**: *Winding the Spring* (music box, dulcimer, ticks; it slows down at the end as the spring runs out) and *Brass and Steam* (7/8 machinery, anvils, steam). It is played on a dead-straight grid, with no human timing.
- A victory sting per faction and a defeat sting.

In a match you hear your faction's calm piece. It cross-fades to the battle piece when fighting heats up near your units, and goes back after things are quiet. Music and sound can each be switched on or off on the menu and in the pause menu.

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
