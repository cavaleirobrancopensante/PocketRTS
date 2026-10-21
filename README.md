# Pocket RTS

**Play in your browser: https://cavaleirobrancopensante.github.io/PocketRTS/**

A StarCraft / Beyond All Reason style real-time strategy game for phones and the browser, made in Godot 4.7 with NES-style pixel art. Play a **skirmish** with up to four players: 1v1, 2v2, you against two or three computers, or a free-for-all. Each slot picks a player (you or an Easy, Normal, Hard or **Brutal** AI), a faction, a colour and a team. If nobody is "you", the computers play and you watch. The Brutal AI micro-manages every fight and cheats (+50% income). All three factions are playable: **the Crown**, **the Brood** and **the Clockwork**.

See [GAMEPLAN.md](GAMEPLAN.md) for the design, the three planned factions and all the art prompts.

## How to play

Destroy every enemy building to win.

There are **no resources on the map**: the map is about geography, chokes and town-hall spots. Each faction builds its own economy, and every Town Hall, Hive or Clocktower allows only so many economy structures, so you grow by taking and holding expansions. Each faction's economy works differently.

### The Crown: dig in
- You start with a **Town Hall, one Farm and 4 Labourers** (and 300 gold): more labourers first, then the second farm is the first big decision.
- **Labourers** work **Farms** (up to 8 each, every hand working at the same rate). A farm ripens into a **380-gold harvest** all at once, faster with more hands (about 40 s with a full crew of 8). A fully worked base (16 farmers + 6 millers) makes about **1,140 gold and 120 powder a minute**.
- **Soil fatigue:** each Town Hall's farmland holds **9,000 gold**, shared by its farms (a farm belongs to the nearest hall). Every harvest draws its gold from it; once it's spent, those farms pay **a third** (about minute 10 for a base worked hard from the start). The Town Hall and every Farm show the soil left ("Soil: 62%"), tired fields turn yellow-brown, and you're warned below 25% and when it's spent. A **new Town Hall comes with fresh soil** (one rebuilt where a hall fell takes over that tired land); new labourers go to fresh farms first. The Powder Mill never tires.
- The **Powder Mill** (100 gold, up to 6 labourers, 0.33 powder a second each) makes **black powder** for the bank: Musketeers cost 10, Balloons 30 (and their gunners burn 1 a shot), Powder Wagons 30, and the bank pays for every refill of soldiers' and wagons' powder.
- **Personal powder:** every **Musketeer** carries **12 shots** and every **Field Cannon 8** (round shot or canister, one each), shown as a little horn and amber bar under the health bar. A musketeer that runs dry **fixes bayonets by itself** and fights hand to hand until it has 4 shots again, then goes back to muskets; a dry cannon can't fire. They refill by themselves (2 shots a second) within **3 tiles** of your **Powder Mill, Barracks or Town Hall** (paid from the bank: 0.5 powder a musket shot, so a full musketeer costs 6, and 1.5 a cannon shot; with the bank empty the refill waits) or of a **Powder Wagon** with powder left (from its store). Short fights near home never notice; long pushes need a wagon.
- **Powder Wagon** (Foundry, 100 gold + 30 powder, supply 2, 220 hp, armour 1, cannon speed, no weapon): carries **120 shots** for the soldiers around it (it shows its unload pose while handing them out). Parked within 3 tiles of a Powder Mill, Barracks or Town Hall it fills 8 shots a second, paid from the bank at **1 powder per 2 shots** (a cannon shot takes 3 of its shots). **SUPPLY** (hotkey U, glows while on): while it has room for a keg, up to **2 labourers** fetch **30-shot kegs** from the nearest Powder Mill (15 powder each) and carry them to it, wherever it is. A labourer killed with a keg **blows up** (40 damage, 1.5 tiles). When the wagon is destroyed it **explodes**: up to 120 damage within 3 tiles (scaled by the powder aboard, at least 20), friends included, so keep it behind the line and guarded.
- Each **Town Hall** allows 2 Farms and 1 Powder Mill within 14 tiles. **Cottages** add supply (max 100).
- **Walls and gates** (10 and 25 gold a piece): lay them in a line (pick the start, then the end; your labourers build piece after piece). A gate opens for your side and your allies and stays shut to the enemy. Every main base sits on high ground with one ramp (two in four-player games), so a few pieces wall it off. Enemies that can't get through hack at the wall.
- **Tech step:** each faction's ranged unit needs its second economy building, which it doesn't start with: Musketeers need a **Powder Mill** (and cost 10 powder each), Spitters a **Brood Pen** (5 essence an egg), Bolt Automatons a **Boiler** (the Clockwork starts on the Clocktower's own power).
- **Observation Balloon** (Foundry): a snipers' nest in the sky. Two musketeers in the basket each pick their own target, on the ground or in the air. It sees 12 tiles, so your cannons can fire as far as it looks. Slow and fragile; shots burn powder from the bank.
  - **Dropship:** it carries up to **4 Musketeers, Pikemen or Labourers**. **LOAD** (L) with infantry selected along with it boards them all; otherwise press LOAD and tap the men (or right-click the balloon with them selected). They walk under it and climb in while it comes down and holds still, so it must hover over ground they can reach. Passengers stand in the basket, still count toward supply and can't be hit; carried **Musketeers fire from the basket** with their own range, damage and reload. **UNLOAD** (U) and tap a spot: it flies there and lets everyone off on the nearest open ground (over a cliff edge too); tap the balloon itself or **DROP HERE** (U again) to let them off where it is. If it's shot down, everyone falls out and loses half his health.
- **Barracks**: **Musketeers**, **Pikemen** and, once you have a Foundry, **Cuirassiers**: fast armoured horsemen, melee only. After about 2 s at the gallop the next sabre blow is a **charge**: double damage, and the enemy is thrown back and staggered. Pikes do double damage to them. **Foundry**: **Field Cannons**, **Observation Balloons** and **Powder Wagons**. **Church**: one **Missionary** per church.
- The **Missionary** walks to a wounded soldier and takes him off the field to bandage him (4 s). The soldier comes back at full health with a cross over his head and can't be bandaged again for 5 s. The Missionary can't be hurt unless he is within 8 tiles of an enemy building.

### The Brood: the swarm
- **Grubs** haul food from **Feeding Pits** (up to 5 each) to the nearest **Hive**. A load pays for its round trip, and the farther the pit is from its Hive the better each grub earns: about **60-70 biomass a minute** within 9 tiles of the Hive, rising to about **88** from 15 to 24 tiles out, then less beyond. A Hive with its 3 pits fully worked (15 grubs) makes about **1,000 biomass a minute** with its pits 9-10 tiles out, ~1,150 at 12 and ~1,300 from 15, so spreading swamp pays.
- **Hive ground:** the pits around a Hive (a pit belongs to the nearest Hive) share one reserve of **10,500 biomass**. Every load draws its value from it; once it's spent those pits yield **a third** (about minute 10 for a Hive worked hard from the start). The Hive and every pit show the ground left ("Ground: 62%"), spent pits dry out to a dead grey-brown, and you're warned below 25% and when it's spent. A **new Hive brings fresh ground** (one grown where a Hive fell takes over what was left there); new grubs go to pits on fresh ground first.
- Pits and every Brood structure except Hives must grow on your swamp. **Spore Vents** spread it far. Each Hive allows 3 Feeding Pits and 1 Brood Pen.
- A grub **turns into** a building and is used up.
- **Harvest the fallen:** select grubs and press **HARVEST**: they stay where they are and wrap every body nearby (friend or foe) in a cocoon, carrying it to a Hive as essence: 1 per supply of the dead unit plus 1 per kill it made. Bodies rot away after 2 minutes, and a grub carrying a cocoon can be caught on the way home.
- **Veterancy (all factions):** every kill gives a unit +1% damage (up to +50%). The selection panel shows it ("Veteran · 7 kills · +7% damage"), and a gold kill count sits in the corner of each portrait when several units are selected.
- **Over every unit's head:** its health bar, always shown, and under it a thin **reload bar** for every armed unit, friend or foe: it fills from the last shot to ready (gold when ready; blue while a cannon, Tesla Cart or Spore Mother is limbered/packed or setting up; red when out of powder). Your musketeers, cannons and wagons add a thin amber powder bar with a little horn.
- The **Brood Pen** (100 biomass) turns every body that falls within 12 tiles (friend or foe) into **essence**. **SACRIFICE** (K; a card button on the phone): the selected Brood creatures (not grubs) walk or fly to the nearest Pen and are offered up there, each for **12% of its biomass cost** as essence: a Raptor 3, a Spitter 5, a Bloater 6, a Skywing 12, a Brute 18, a Spore Mother 21. That's how spare biomass becomes essence for Spitters (5 an egg), Bloaters (25), Brutes (20), Skywings (40), Spore Mothers (40) and Miasma (30). There's no passive trickle any more.
- Every unit hatches from the **Hive's eggs** (each Clutch Mound makes the Hives lay 10% faster, up to +30%): **Raptors** (3 per egg), **Spitters** (2 per egg), **Brutes** (need a Gorge Pit) and **Skywings** (need a Roost).
- **Skywings** fly over everything and hunt **flyers only** (spine volleys, range 130); flying, only ranged anti-air can hit them. **LAND** (L, 1.2 s) turns one into a ground fighter: it walks (no cliffs or walls), bites ground units only, and anything can hit it. **TAKE OFF** (L) to fly again.
- **Bloaters** (need a Roost): floating gas sacs. They SPIT acid from range, every glob using up gas, or on **HOLD GAS** they keep it all and drift in to burst: damage and an acid cloud (armour down, slowed) that grow with the gas left. A Bloater that spits its gas away **deflates**: it can't spit or burst, it's slower, and it fills up again over about 25 s (twice as fast on swamp).
- **Spore Mothers** (need a Gorge Pit) are slow and can't attack while walking. **ROOT** her (2.5 s): she lobs big spit blobs that splash an area and spreads swamp around her. **MIASMA** (30 essence, 18 s to recover) lays a green cloud for 8 s; Brood inside heal up to 30% of their health. Clouds don't stack.
- Swamp heals the Brood and makes it faster. Army cap 160.

### The Clockwork: batteries
- Every energy building fills **batteries** by itself: the **Clocktower** (one every 2 s), **Boilers** (every second), **Charging Pylons** and **Spring Towers** (slower).
- **Winders** carry them to an **Ore Crusher**, where the charge becomes ore. A battery gains charge the longer it's on the road (yellow: 7 ore + 0.7 a second), so a crusher far from the source pays more per trip, but a battery that's carried too long (22 s) or whose Winder is hit **bursts**, hurting the Winder and anyone next to it. Hauling routes are worth raiding.
- The **Capacitor Works** (after an Assembly Works) turns every source **blue**: 10 ore + 1.1 a second, 30 s before overloading, and slightly faster assembly and bigger fields.
- Winders also repair constructs and buildings, which costs ore (0.2 per hit point).
- Each Clocktower allows 2 Boilers and 2 Ore Crushers nearby.
- Winders also start buildings, which then assemble themselves.
- Every construct carries a **battery on its back** (everyone can see it). Away from a field it drains (empty in about 2 minutes, slower with blue energy), making it a little slower and weaker; when it is empty the construct **shuts down** like a cold statue until a field reaches it (a tower, pylon or deployed Tesla Cart) or a Winder winds it up again.
- Constructs run down (slower and weaker) outside the field of a Clocktower, Spring Tower, Charging Pylon or deployed Tesla Cart.
- The **Charging Pylon** also mends constructs.
- **Assembly Works**: **Gearknights**, **Bolt Automatons** (pierce up to 3), **Steam Walkers** and **Tesla Carts**. A Tesla Cart rolls when packed; deploying or packing takes 3 s. Deployed, it powers constructs around it and fires chain lightning that can hit flyers.
- **Ornithopters** (need a Charging Pylon): fast flyers with a lightning gun, best against other flyers. They wind down away from a field like every construct.
  - **COURIER** (C, automatic, glows when on): an idle Ornithopter takes a charged battery from an energy building (you see it hanging underneath) and flies it to a construct that has run down, shut-down ones first, then the lowest charge, and winds it back to full; then it goes back for another.
  - **OVERLOAD** (O, then tap one of your constructs): it dumps its battery into that construct: for 12 s it glows and crackles, hits 50% harder, moves 30% faster and attacks 25% sooner, fully wound; then it burns out to 25% charge. Gearknights love it.
- **Stormcallers** (need a Charging Pylon) are fragile casters with a weak zap. **STORM** throws a 3-tile ring of lightning on a spot for 3 s: everything inside is **stunned** (your own units too) and enemies take damage. A storm costs 70 of the Stormcaller's 100 charge, and the charge only fills inside a Clockwork field.
- Army cap 80.

### Match log (for playtesting)
Every match keeps a plain-text log: who played (and at what AI level), what each side built, lost and cast, the first of each unit type, the walls laid, a snapshot of every player each minute (income, resources, supply, workers, halls, army and its value, kills and losses) and the final result with kills by unit type. **COPY LOG** on the end screen copies it to the clipboard; the last 20 logs are also saved in `user://logs`.

### Computer plans
In the skirmish lobby each computer player has a **PLAN**: Balanced, Rush (early, small, constant attacks; expands late), Economy (expands early and often, attacks late and big), Timing attack (techs up and holds everything back until about 6-7 minutes, then attacks wave after wave), Air rush (Brood only: a Roost early and masses of Skywings) or Random. Every plan spends its bank: more Barracks, Foundries and Assembly Works, deeper queues, and the Brood builds more Hives (its eggs come from Hives).

### Closing the game
The match is saved every 15 seconds (and whenever the app goes to the background): if you close it, **CONTINUE** on the main menu picks it up where it was (soldiers stand where they were, workers go back to work). **MATCH LOGS** on the main menu lists every match's log, including an unfinished one, each with a COPY button.

### Workers work by themselves
**WORK** is on by default (its button glows): a worker with nothing to do goes back to a free post on its own, after building, after walking to a rally point, after a STOP. Press WORK to switch it off for the selected workers (to scout, or keep a builder free) and again to switch it back on.

### Buildings
- Every building is on the **BUILD** card (more pages if they don't fit).
- **ABANDON** a building that isn't finished: 75% of its cost comes back. **DEMOLISH** (press twice) pulls down a finished one.
- Labourers repair buildings, Winders repair constructs and buildings; repairs cost gold/ore.
- Select several buildings of the same kind (or a control group of them): training goes to whichever is least busy, and a rally point applies to all.
- Enemies walled out with no gate break the wall down.

### Line move
Drag a line and your selected units spread out evenly along it (as in Beyond All Reason): good against splash, for firing lines and for holding a choke. Computer: hold the right button and drag (a short right click is still a normal command), or press MOVE / ATTACK and drag with the left button. Phone: tap MOVE or ATTACK, then drag the line. With ATTACK they attack-move to their spots.

### Area damage hits everyone
Canister, round shot, cannon splash, the Steam Walker's steam, the Spore Mother's spit blobs, the Stormcaller's storm and exploding Powder Wagons and kegs hurt your own units too, so where your men stand matters. Units only fire an area attack on their own when the enemies in it clearly outweigh the friends; an explicit ATTACK order fires anyway.

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
- **1–9** select a group, **Ctrl+1–9** save one, **Shift+1–9** add it; press twice to jump to it. **F1** idle worker, **F2** army, **F3** hall, **F4** every production building (MAKE: train from all of them at once), **Space** jumps to the selection.
- **Camera:** mouse wheel zooms; pan with the screen edges, the arrow keys or a middle-button drag.

### Mobile controls
- Tap a unit to select it; double-tap to select all of that type on screen.
- Drag on the map to box-select (soldiers are picked over workers). The **DRAG: BOX / PAN** switch (top right) makes a one-finger drag move the view instead.
- Tap the ground to move (soldiers fight anything on the way). Tap an enemy to attack, your own Farm, Mill, Pit or Boiler to put workers on it, your own unfinished building to help build it.
- Long-press the ground to move without stopping to fight.
- Two fingers pan and pinch to zoom; tap or drag the minimap to jump.
- **ARMY / IDLE / HALL / MAKE** select quickly. MAKE selects every building that trains an army: the card shows every unit they make, each goes to the least busy building, a long press sets it to train automatically everywhere, and RALLY sends them all to one spot. **Groups 1–4**: tap an empty one to save the selection, tap to select, hold to overwrite.
- With several units selected, tap a portrait in the selection panel to keep only that kind; tap again to keep just that one.
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
