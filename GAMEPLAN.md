# Pocket RTS — game plan

A StarCraft 2 / Beyond All Reason style RTS for phones and the browser, made in Godot 4.7.

## Decisions so far

- **Three factions, asymmetric in every respect**: economy, building, production, army size, strengths and weaknesses.
- **Engine feel like Beyond All Reason and StarCraft 2**: units act individually, with no formations. Box-select, attack-move, control groups, fast responsive micro, and a macro economy.
- **Prototype (v0.1)**: the Crown only, 4 units (labourer, musketeer, pikeman, field cannon) and 4 buildings, 1v1 vs AI on one mirrored map.
- **Art**: low-res, NES-style pixel art made in ChatGPT; 3/4 top-down view; 5 facing directions (the left-facing ones are mirrored in-game).
- **Team colour**: every unit's team-coloured parts are pure red (`#FF0000` + one dark shade `#960000`); the game recolours them per player.
- **Order of work**: all Crown sprites first, then the other factions, then the game.

## Factions

Each faction has 4 units and 4 structures in the first version, and nothing works the same way across them.

| | The Crown | The Brood | The Clockwork |
| --- | --- | --- | --- |
| Theme | 17th-century musketeers and pikemen | Lizard-beast swarm | Primitive, steampunk-ish clockwork constructs |
| Worker | Labourer walks to the mine and carries gold home | Grub burrows into a mine and feeds on it in place (no trips); it is used up to grow a building | Winder never mines; it winds up buildings and repairs constructs |
| Income | Many workers, trips to the hall | Few grubs, steady trickle; more grubs per mine = more income | Drill Rig built on top of a mine extracts by itself |
| Building | Labourer builds; can be helped | Grub turns into the building (worker is spent) | Winder places a frame; the building assembles itself while wound |
| Supply | Cottages | Clutch Mounds; the Hive gives a lot | Spring Towers, which also make a wind-up field |
| Production | Several buildings, each trains its own units | Every unit hatches from eggs at the Hive; other structures only unlock types | One Assembly Works builds every combat unit |
| Special rule | Long-range firepower, cannons | Swamp spreads from Brood structures: Brood units heal and run faster on it | Constructs outside a Spring Tower field slowly run down (slower, weaker) |
| Army | Mid-sized, ranged-heavy | Many cheap, fast melee units | Few, expensive, very tough units |
| Strong at | Holding ground, sieges | Swarming, out-expanding, harassment | Pushing slowly with an unbreakable line |
| Weak at | Slow, cannons die to flanks | Fragile, weak off the swamp | Slow to build, weak far from its towers |

## The Crown — units

| # | Unit | Role | Sprite |
| --- | --- | --- | --- |
| 1 | Labourer | Worker: mines gold, builds | ✅ `art/crown/labourer.png` |
| 2 | Musketeer | Ranged line infantry | ✅ `art/crown/musketeer.png` |
| 3 | Pikeman | Anti-cavalry, anti-charge, screens shooters | ✅ `art/crown/pikeman.png` |
| 4 | Grenadier | Splash damage against swarms | ⬜ |
| 5 | Dragoon | Mounted raider, carbine and sabre | ⬜ |
| 6 | Field cannon | Siege, long range, slow | ✅ `art/crown/cannon.png` (1 frame per row) |
| 7 | Chaplain | Healer / support | ⬜ |
| 8 | Captain | Hero with a banner, buffs nearby units | ⬜ |

Buildings come after the units (their prompt is different: one image per building, plus construction and damaged states).

## Sprite prompts

Attach the musketeer sheet every time (and one or two other finished sheets as extra style references).

**Shared part (paste first):**

> Sprite sheet for the same top-down 2D RTS as the attached musketeer sheet. Match its style, pixel size, proportions, outline and colours exactly: low-res NES-style pixel art, 3/4 overhead view, transparent background, no ground shadows, no text, no labels, no grid lines.
> Team colour: the unit's team-coloured parts must be pure red (#FF0000) with only one darker shade (#960000); everything else in natural colours. No other reds anywhere (fire and muzzle flashes orange/yellow).
> Directions as 5 separate panels: facing down, down-right, right, up-right, up. Same feet baseline in every frame.

**4. Grenadier** (cells 64×64)
> Character: tall mitre cap with a red front (team colour), red coat, grenade pouch, short sword.
> Rows: 1 idle (2), 2 walk (6), 3 lighting the fuse (2), 4 throwing a black round grenade with a lit fuse (4), 5 sword strike (3), 6 death (4).

**5. Dragoon** (cells 96×96)
> Character: mounted soldier on a brown horse, morion helmet, red coat and red saddle cloth (team colour), short carbine and sabre.
> Rows: 1 idle (2), 2 trot (6), 3 gallop charge (4), 4 firing the carbine from the saddle with a flash (3), 5 sabre slash (3), 6 death, horse and rider falling (4).

**6. Field cannon** (cells 96×96)
> Character: bronze field cannon on a wooden carriage with two crewmen in red coats (team colour) and morion helmets.
> Rows: 1 idle (1), 2 crew pushing the cannon (4), 3 firing with recoil, flash and smoke (4), 4 crew ramming the barrel (4), 5 destroyed, broken wheel, crew down (3).

**7. Chaplain** (cells 64×64)
> Character: priest in a black cassock with a red stole (team colour), holding a wooden cross; no weapon.
> Rows: 1 idle (2), 2 walk (6), 3 blessing, cross raised with a soft white-gold glow (4), 4 praying, kneeling (2), 5 death (4).

**8. Captain** (cells 64×64; the banner may reach the top of the cell)
> Character: officer with a polished morion helmet and steel breastplate, red sash (team colour), sword in one hand, a tall banner pole with a red flag (team colour) in the other.
> Rows: 1 idle, banner waving (2), 2 walk (6), 3 rally, banner raised high (4), 4 sword strike (3), 5 death, banner falling (4).

## Notes on the finished sheets

- The checkerboard in ChatGPT's images is painted in, not real transparency; the import script cuts sprites out by their dark outline.
- Reds are snapped to the two key shades on import, so near-reds are fine.
- Frame counts may differ a little from the prompt; the importer reads whatever each row has.
- Sprites will be shrunk to their true pixel size (about 32 px tall for infantry) and scaled up crisply, for a consistent NES look.

## Structures and objects

What the prototype needs (Crown vs Crown, four units): **Town Hall, Cottage, Barracks, Foundry, gold mine, trees and rocks, ground tiles, effects, icons.** Later: Stables, Chapel, Redoubt (defence tower), Palisade walls.

**Shared part for buildings (paste first, attach the musketeer and cannon sheets):**

> Sprite sheet for a building in the same top-down 2D RTS as the attached unit sheets. Match their style, pixel size, outline and colours exactly: low-res NES-style pixel art, 3/4 overhead view seen from the same angle, transparent background, no ground shadow, no text, no labels, no grid lines.
> Scale: the musketeer from the attached sheet must be about one quarter of the building's height.
> Team colour: flags, banners and painted trim only, in pure red (#FF0000) with one darker shade (#960000). No other reds anywhere (use brown, grey, slate or thatch for roofs).
> One row, 4 frames left to right, each in its own equal cell: 1 finished, 2 under construction (wooden scaffolding, half-built walls), 3 damaged (cracks, broken roof, small orange fire), 4 destroyed (rubble and charred beams).

**Town Hall** (cells 192×192)
> Building: fortified stone manor with a tiled slate roof, a central tower with a red flag (team colour), a big wooden gate where workers drop off gold, a small gold store beside it.

**Cottage** (cells 96×96)
> Building: small timber-framed cottage with a thatched roof and a chimney, a red pennant on the door (team colour). Supply building.

**Barracks** (cells 160×160)
> Building: long stone-and-timber barracks with a slate roof, weapon racks with muskets and pikes outside, a red banner over the door (team colour).

**Foundry** (cells 160×160)
> Building: brick gun foundry with a tall smoking chimney, an open forge glowing orange, a finished cannon barrel on blocks outside, red cloth awning (team colour).

**Gold mine** (no team colour; cells 128×128)
> Sprite sheet in the same style and scale as the attached unit sheets: low-res NES-style pixel art, 3/4 overhead view, transparent background, no text. One row, 3 frames: 1 rocky hillside mine entrance with wooden supports and glittering gold veins, 2 half-depleted (fewer veins), 3 depleted (collapsed entrance, no gold).

**Nature** (no team colour; cells 64×64)
> Sprite sheet in the same style and scale as the attached unit sheets: low-res NES-style pixel art, 3/4 overhead view, transparent background, no text. Two rows: 1 six different trees (oak, pine, birch, dead tree, two bushes), 2 six rocks and boulders of different sizes.

**Ground tiles** (cells 32×32)
> Seamless top-down ground tiles in low-res NES-style pixel art matching the attached sheets, viewed straight down, no outlines, no text. 4×4 grid of 32×32 tiles: row 1 four grass variations, row 2 four dirt variations, row 3 grass-to-dirt edges (top, bottom, left, right), row 4 shallow water, water edge, mud, flowers on grass. Every tile must tile seamlessly with its neighbours.

**Effects** (cells 48×48)
> Sprite sheet of effects in low-res NES-style pixel art matching the attached sheets, transparent background, no text. Rows: 1 musket muzzle smoke puff (4 frames), 2 cannonball in flight (1 frame) and its impact explosion with dirt (5 frames), 3 building fire flames (4 frames, looping), 4 dust cloud from collapsing building (4 frames), 5 small blood/hit spark (3 frames). Fire and explosions orange and yellow, never pure red.

**Icons** (cells 48×48)
> Set of square button icons in low-res NES-style pixel art matching the attached sheets, each in its own 48×48 cell with a dark frame, no text. One row each: units (labourer, musketeer, pikeman, field cannon) as head-and-shoulders portraits in red coats; buildings (town hall, cottage, barracks, foundry); commands (move, attack, stop, build, gather, repair).


## The Brood — units and structures

| # | Name | What it does |
| --- | --- | --- |
| U1 | Grub | Worker. Burrows into a gold mine and feeds; turns into structures |
| U2 | Raptor | Fast, cheap melee; hatches two per egg |
| U3 | Spitter | Ranged acid; damage over time that melts armour |
| U4 | Brute | Huge tank; charges and knocks enemies back |
| S1 | Hive | Main structure; makes eggs, grubs hatch here; big supply |
| S2 | Clutch Mound | Supply; spreads swamp |
| S3 | Warren | Unlocks Raptors and Spitters |
| S4 | Gorge Pit | Unlocks Brutes |

**Shared part for Brood units (attach the Crown musketeer sheet as the style reference):**

> Sprite sheet for the same top-down 2D RTS as the attached sheet. Match its style, pixel size, outline and level of detail exactly: low-res NES-style pixel art, 3/4 overhead view, transparent background, no ground shadows, no text, no labels, no grid lines. This is a different faction: reptilian lizard-beasts.
> Team colour: the head frill, crest and back spines must be pure red (#FF0000) with only one darker shade (#960000). Skin olive and moss green, belly pale yellow, claws bone white. No other reds anywhere: blood and acid are yellow-green.
> Directions as 5 separate panels: facing down, down-right, right, up-right, up. Same feet baseline in every frame.

**U1 Grub** (cells 48×48)
> Character: small fat grub-lizard on four stubby legs, big jaws, red frill.
> Rows: 1 idle (2), 2 crawl (6), 3 burrowing into the ground and feeding, only the back visible (4), 4 bite (3), 5 swelling up and splitting open as it turns into a building (4), 6 death (4).

**U2 Raptor** (cells 64×64)
> Character: lean bipedal raptor-lizard, long tail, sickle claws on the feet, red crest.
> Rows: 1 idle (2), 2 run (6), 3 leap attack (4), 4 claw slash (3), 5 death (4).

**U3 Spitter** (cells 64×64)
> Character: hunched lizard with a swollen throat sac and a red frill that flares open.
> Rows: 1 idle (2), 2 walk (6), 3 frill flaring and throat swelling (2), 4 spitting a yellow-green acid glob (3), 5 death (4).

**U4 Brute** (cells 96×96)
> Character: huge armoured lizard beast on four legs, horned head like a triceratops, red spines along the back.
> Rows: 1 idle (2), 2 walk (6), 3 charge, head lowered (4), 4 head-butt / gore (3), 5 death, collapsing on its side (4).

**Shared part for Brood structures (attach the Crown musketeer and Town Hall sheets):**

> Sprite sheet for a structure in the same top-down 2D RTS as the attached sheets. Match their style, pixel size, outline and colours exactly: low-res NES-style pixel art, 3/4 overhead view from the same angle, transparent background, no ground shadow, no text, no labels, no grid lines.
> This faction's buildings are living organic mounds of hide, bone and mud on dark green swamp ground, with ribbed membranes and glowing yellow-green pores.
> Team colour: only the fleshy frills and crest spikes on the structure, pure red (#FF0000) with one darker shade (#960000). No other reds anywhere.
> One row, 4 frames left to right, each in its own equal cell: 1 finished, 2 growing (a smaller translucent egg-sac version, half-formed), 3 damaged (torn membranes, oozing yellow-green), 4 destroyed (collapsed husk and bones).

**S1 Hive** (cells 192×192)
> Structure: huge domed nest of hide and bone with a ring of eggs around its base, a large red-frilled crest on top, swamp pooling around it.

**S2 Clutch Mound** (cells 96×96)
> Structure: small mud mound covered in leathery eggs, with a little red frill on top.

**S3 Warren** (cells 160×160)
> Structure: low sprawling burrow of ribbed tunnels and claw-marked earth, several dark tunnel mouths, red frill spikes along the ridge.

**S4 Gorge Pit** (cells 160×160)
> Structure: deep pit ringed by giant bones and tusks, steaming swamp inside, a huge horned skull at the front with red frill spikes.

## The Clockwork — units and structures

| # | Name | What it does |
| --- | --- | --- |
| U1 | Winder | Builder and repairer; never mines |
| U2 | Gearknight | Heavily armoured melee; repairs itself slowly |
| U3 | Bolt Automaton | Crossbow construct; bolts pierce through a line of enemies |
| U4 | Steam Walker | Big two-legged walker; scalding steam cone, strong against swarms and buildings |
| S1 | Clocktower | Main structure; builds Winders; Spring Tower field |
| S2 | Drill Rig | Built on a gold mine; extracts gold by itself |
| S3 | Spring Tower | Supply; wind-up field that keeps constructs at full strength |
| S4 | Assembly Works | Builds every combat construct |

**Shared part for Clockwork units (attach the Crown musketeer sheet as the style reference):**

> Sprite sheet for the same top-down 2D RTS as the attached sheet. Match its style, pixel size, outline and level of detail exactly: low-res NES-style pixel art, 3/4 overhead view, transparent background, no ground shadows, no text, no labels, no grid lines. This is a different faction: primitive steampunk clockwork constructs made of brass, copper, iron rivets and dark wood, with visible gears and a wind-up key on the back.
> Team colour: the painted armour plates and pennants must be pure red (#FF0000) with only one darker shade (#960000). Everything else natural metal and wood. No other reds anywhere: glows and sparks are orange or yellow, steam is white.
> Directions as 5 separate panels: facing down, down-right, right, up-right, up. Same feet baseline in every frame.

**U1 Winder** (cells 48×48)
> Character: small round brass construct on two short legs, a giant wind-up key on its back, two thin arms holding a big wrench, red painted chest plate.
> Rows: 1 idle, key slowly turning (2), 2 walk (6), 3 winding / repairing with the wrench, sparks (4), 4 wrench strike (3), 5 death, falling apart into gears (4).

**U2 Gearknight** (cells 64×64)
> Character: tall knight-shaped iron construct with a bucket helm, round shield with a red painted face, a heavy mace, exposed gears at the joints.
> Rows: 1 idle (2), 2 walk, heavy and stiff (6), 3 mace strike (4), 4 shield raised, blocking (2), 5 death, toppling over with springs flying out (4).

**U3 Bolt Automaton** (cells 64×64)
> Character: wooden and brass torso on a tripod of legs, a big crossbow built into its chest, red painted shoulder plates, a crank on the side.
> Rows: 1 idle (2), 2 walk (6), 3 cranking the crossbow back (3), 4 firing a bolt (2), 5 death, collapsing (4).

**U4 Steam Walker** (cells 96×96)
> Character: large two-legged walking boiler with a smokestack, a funnel-shaped steam nozzle at the front, rivets, red painted boiler plates.
> Rows: 1 idle, puffing smoke (2), 2 walk (6), 3 spraying a white steam cone from the nozzle (4), 4 venting steam, cooling down (2), 5 death, boiler bursting (4).

**Shared part for Clockwork structures (attach the Crown musketeer and Town Hall sheets):**

> Sprite sheet for a structure in the same top-down 2D RTS as the attached sheets. Match their style, pixel size, outline and colours exactly: low-res NES-style pixel art, 3/4 overhead view from the same angle, transparent background, no ground shadow, no text, no labels, no grid lines.
> This faction's buildings are made of brass, copper, iron girders and dark timber, with big visible gears, chimneys and steam pipes.
> Team colour: only painted plates and pennants, pure red (#FF0000) with one darker shade (#960000). No other reds anywhere: glows orange, steam white.
> One row, 4 frames left to right, each in its own equal cell: 1 finished, 2 assembling (iron frame half-built, gears lying around, no scaffolding with people), 3 damaged (broken gears, sparks, steam leaks, small orange fire), 4 destroyed (pile of scrap metal and timber).

**S1 Clocktower** (cells 192×192)
> Structure: tall brass clock tower on a stone and iron base, a huge clock face, gears turning on the sides, a red pennant on the spire, a hatch at the bottom.

**S2 Drill Rig** (cells 128×128)
> Structure: iron drilling rig built over a rocky gold seam, a turning drill shaft, a small boiler and chimney, a conveyor pouring gold nuggets into a hopper, red painted plates.

**S3 Spring Tower** (cells 96×96)
> Structure: slim iron tower holding a giant coiled brass spring, with a slowly turning key on top and a red pennant.

**S4 Assembly Works** (cells 160×160)
> Structure: wide workshop with sawtooth roof, a big open door with a half-assembled construct on a gantry crane inside, chimneys, steam pipes, red painted plates.

---

## Economy (v0.6, built)

The map holds no resources: it's about geography, chokes and town-hall spots. Each faction makes its own resources from structures, and each hall allows a fixed number of them, so expansions are what players fight over.

| | Crown | Brood | Clockwork |
| --- | --- | --- | --- |
| Main resource | **Gold**: Farms ripen into a 380-gold harvest (~40 s with a full crew); up to 8 labourers make them grow faster. Soil fatigue: each Town Hall's farmland holds 9,000 gold; once its farms have drawn it out they pay a third, so the Crown must expand | **Biomass**: grubs haul food from Feeding Pits to a Hive; a load pays for its round trip (2 s + 0.8 s a tile of open ground) at 1.2 biomass a grub-second, +30% from 6 to 18 tiles out, flat to 22, slowly less beyond: ~1,000 a minute for a fully worked Hive (15 grubs) with pits 9-10 tiles out, ~1,150 at 12, ~1,300 from 15. Hive ground: each Hive's pits share a 10,500 reserve; spent, they yield a third, so the Brood must expand | **Ore**: energy buildings fill batteries; Winders carry them to Ore Crushers (every point of charge pays 0.7 ore: yellow 7 + 0.7 a second on the road; interim pace, ~1,000-1,100 a minute for a saturated base, until the Clockwork rework) |
| Second resource | **Powder** (Powder Mill, 6 labourers, ~120 a minute): pays for musketeers, balloons and Powder Wagons; musketeers (12 shots) and cannons (8) carry their own and refill (paid from the bank) near a Mill, Barracks, Town Hall or Powder Wagon | **Essence**: bodies falling near a Brood Pen, and creatures SACRIFICEd there (12% of their biomass cost; a Raptor gives 3). Spitters, Bloaters, Brutes, Skywings, Spore Mothers and Miasma cost some | **Energy** itself: split between ore, assembly speed and wind (field size, slower run-down) |
| Per hall | 2 Farms, 1 Powder Mill (start: Town Hall, 1 Farm, 4 Labourers) | 3 Feeding Pits, 1 Brood Pen | 2 Boilers, 2 Ore Crushers |
| New units | Missionary (Church; 1 per church; bandages wounded soldiers; invulnerable away from enemy buildings) | Skywing (Roost; flyer, only ranged units can hit it) | Tesla Cart (Assembly Works, needs a Charging Pylon; deploys in 3 s; powers constructs; chain lightning) |
| Other new structures | Church | Spore Vent (spreads swamp far), Roost | Charging Pylon (field + mends constructs) |

Still to come: maps with biomes, high ground and ramps; the Clockwork "husk" idea (constructs that run out of wind entirely); more units per tier.

---

## Earlier proposal (kept for reference): resources and tech trees

Design idea: this is a single-player game, so each faction can run its **own economy** with 2 resources, and a structure-dependent one like SC2's refinery. No faction plays like another:

- **The Crown** plays like Terran mech: it takes ground slowly, digs in and holds it.
- **The Brood** is the Zerg swarm: it breaks positions by throwing waves at them, and losses feed the next wave.
- **The Clockwork** is Protoss-like but not Protoss: few expensive constructs, power fields, sustain instead of shields.

### Map resources

Every base spot has a **gold mine** and an **ember vent** (a new hot fissure in the ground, like an SC2 geyser). Each faction takes something different from them:

| | Main resource | Second resource (structure-dependent) | Supply |
| --- | --- | --- | --- |
| **Crown** | **Gold**. Labourers mine and carry it, as now. | **Powder**. A Powder Mill on an ember vent; 3 labourers carry saltpetre from it (gas-style). | Cottages |
| **Brood** | **Biomass**. The Brood ignores gold. Grubs root *anywhere on its own swamp* and feed on it; each Hive's swamp feeds up to N grubs. The swamp is the economy, so spreading it is expanding. | **Essence**. Every body that falls (theirs or ours) on or near swamp is absorbed. War pays for the elite strains. | Clutch Mounds |
| **Clockwork** | **Ore**. A Drill Rig on a gold mine, with no workers, as now. | **Steam**. A Boiler on an ember vent, with no workers. Steam is spent on units *and* on **Overwind** (see below). | Spring Towers (field) |

So the Crown competes for both nodes. The Brood needs neither and wants *map area* and *fights*. The Clockwork wants nodes but no workers, so it is hurt most when rigs and boilers die.

### Faction mechanics (what makes the playstyles)

- **Crown: dig in.**
  - Infantry that stands still for 4 s **entrenches** (+2 armour, +15% range).
  - Cannons and mortars must **unlimber** (stop and set up) to fire, like siege tanks.
  - **Palisades** and **forward Outposts** (cheap; they extend supply and heal) let it creep across the map.
- **Brood: the swarm.**
  - **Frenzy**: kills nearby give stacking speed and attack for a few seconds.
  - Eggs hatch in parallel, and units are cheap and short-lived.
  - **Bursters** blow up walls.
  - Raptors can **burrow** on swamp for ambushes.
- **Clockwork: wind.**
  - The wind field (power) is kept, and Winders repair: sustain instead of shields.
  - **Overwind** spends steam to overclock units in an area for 10 s (+40% speed and damage), but afterwards they are unwound to the minimum.

### Tech trees (3 tiers; 7 units and 8 buildings each)

**Crown**

| Tier | Buildings | Units |
| --- | --- | --- |
| 1 | Town Hall, Cottage, Powder Mill, Barracks, Palisade | Labourer, Musketeer, Pikeman |
| 2 | Foundry (needs powder), Watchtower (musket tower), Bastion (cannon fort) | Grenadier (powder grenades, splash against swarms), Field Cannon (unlimbers) |
| 3 | Arsenal | Mortar (huge range, minimum range, unlimbers), War Wagon (a mobile fort that deploys into a wall-and-cannon block) |

**Brood**

| Tier | Buildings | Units |
| --- | --- | --- |
| 1 | Hive (eggs), Clutch Mound, Warren | Grub, Raptor (×3), Spitter (×2) |
| 2 | Gorge Pit, Brood Pool (upgrades) | Brute, Burster (×2; rolling acid sac that bursts on walls and buildings) |
| 3 | Bone Spire (essence) | Swarm Mother (lays raptor eggs as she walks), Behemoth (essence; siege beast that tramples walls) |

The Brood has no static defence; instead, **Spine Mounds** grow on the swamp from a grub.

**Clockwork**

| Tier | Buildings | Units |
| --- | --- | --- |
| 1 | Clocktower, Spring Tower, Drill Rig, Boiler, Assembly Works | Winder, Gearknight, Bolt Automaton |
| 2 | Steamworks, Spring Gun (turret) | Steam Walker (steam), Tick (cheap spider scout that marks targets) |
| 3 | Grand Orrery | Juggernaut (huge walking engine, steam), Orrery Seer (area rewind: heals and re-winds constructs; sees hidden units) |

Upgrades (Crown drill and volleys, Brood carapace and claws, Clockwork springs and plating) come from the tier buildings.

### Suggested order

1. **Resources**: ember vents on the map; Powder Mill, Boiler, Brood swamp biomass and essence; two-resource costs and HUD.
2. **Mechanics**: entrench and unlimber, frenzy and burrow, Overwind.
3. **New units and buildings, tier by tier.** Each needs sprites (prompts to follow in the same style as the others).

### Open questions

- Is Crown powder a **cost** (like SC2 gas) or **ammo** (cannons and mortars use powder per shot)? Recommended: a cost, with mortars also using it per shot.
- Should the Brood's biomass come from rooting anywhere on swamp, or from special **Feeding Pits** grown on the swamp?
- Do we keep one map, or add 2–3 maps with different vent and mine layouts?

---

## Animation prompts (round 2)

The game currently fakes some of these in code (breathing idles, a looping gnaw for grubs). These sheets would replace the fakes with real frames.

**Shared part (paste first, attach two finished sheets as style reference):**
> Sprite sheet for the same top-down 2D RTS as the attached sheets. Match their style, pixel size, outline and colours exactly: low-res NES-style pixel art, 3/4 overhead view, flat dark slate background (#3f4a5a), no ground shadows, no text, no labels, no grid lines. Team-coloured parts pure red (#FF0000) with one darker shade (#960000); no other reds anywhere. **Leave a wide empty gap between every frame; figures must never touch or overlap.** One figure per frame.

**Grub (Brood worker): harvesting and hauling**
> Character: the same pale segmented grub as the attached Brood sheet, with red (team colour) back plates. Row 1: idle facing down, down-right, right, up-right and up, wriggling (3 frames each). All other rows side view facing right: 2 crawl (6), 3 gnawing at the rim of a fleshy feeding pit, head bobbing down and up (4, loops), 4 crawling while carrying a glowing green lump of food in its jaws (6), 5 bite (3), 6 death (4).

**Raptor, Spitter and Brute: idles** (one image each)
> Character: the same [Raptor / Spitter / Brute] as the attached sheet. Row 1: idle facing down (4 frames: breathing, tail swaying, head turning). Row 2: idle facing right (4). Row 3: idle facing up (4).

**Missionary: bandaging (clean)**
> Character: the same priest in a black cassock with a red stole as the attached sheet, and a soldier in a red coat and morion helmet sitting on the ground. Each frame shows the priest kneeling beside the seated soldier and wrapping a white bandage round his arm. Row 1 facing down, row 2 facing right, row 3 facing up (4 frames each). Keep the pair together in every frame, and far apart from the next pair.

**Pikeman: brace and thrust (clean)**
> Character: the same pikeman as the attached sheet. Five direction panels (facing down, down-right, right, up-right, up). Row 1: brace, crouched with the pike levelled forward (2 frames). Row 2: thrust, the pike lunging forward and back (4). Pikes must not cross into the neighbouring frame.

**Field cannon: front and back views** (the side view is done)
> Same cannon and crew as the attached cannon sheet. Row 1: facing down, crew pushing it toward the viewer, wheels turning (6). Row 2: facing up, pushed away from the viewer (6). Row 3: firing facing down (4). Row 4: firing facing up, the barrel pointing up the screen (4).

## Multiplayer (to do)

Online play between friends first (1v1, 2v2, co-op against the AI); ranked play would need server-side checks.

- **Command queue.** Every player action (select-and-command, build, train, rally, split) becomes a small command message with a game tick. Local play, the AI and network play all go through it. This also gives replays.
- **Determinism (lockstep).** One seeded RNG per match (no bare `randf()` in the simulation), fixed timestep, simulation separate from visuals. Run two sims from one command log and compare a checksum every few seconds to catch desyncs.
- **Connection.** WebRTC peer-to-peer (works in the browser) with a tiny signalling/lobby server on a free tier. Room codes: "host → share code → friend joins". No secrets in the repo; server keys live in the server's settings.
- **Lobby.** The skirmish lobby with remote slots (OPEN / player name), ready checks, host picks the map.
- **In-game text chat.** Enter (PC) or a chat button (mobile) opens a line; all / allies toggle; messages fade in the corner; quick-chat buttons on mobile ("Attack!", "Help!", "gg").
- **Save replay.** A SAVE REPLAY button on the end screen writes the command log + seed + lobby setup (a few KB) to user://replays/. A REPLAYS screen plays them back at 1x/2x/4x with fog off and player switching.
- **Cheating.** Lockstep clients know the whole map, so a modded client could remove the fog. That's acceptable between friends.

## Animation prompts (round 3): fixing the Crown infantry and the cannon crew

All three sheets use the same rules as before:
- 16-bit SNES/NES-style pixel art in the current style.
- Coat pieces in pure team red (#FF0000, shaded with #960000) so the team colour can be swapped in.
- A flat single-colour background (slate #34404F), with no gradient, shadows or text.
- Each row is one animation in one direction; frames sit in a grid with equal spacing and the figure the same size in every frame.
- Directions as rows: south, south-east, east, north-east, north. The game mirrors the west-facing ones.

**1. Pikeman (fixes the crooked pike and the shrinking pike).** "Pixel-art sprite sheet of a 17th-century pikeman, steel morion helmet and breastplate, red coat, brown boots, carrying an 18-foot pike. The pike is ONE perfectly straight line and keeps EXACTLY the same length in every frame. Rows:
- walk: 6 frames, pike sloped over the right shoulder, tip up and back, the butt held low in the right hand, legs clearly stepping.
- idle: 2 frames, pike upright, butt on the ground.
- brace: 1 frame, pike levelled forward at chest height, butt against the right foot.
- thrust: 3 frames: draw back (pike pulled back but still full length), lunge forward, recover.
- death: 3 frames.
Each in the five directions."

**2. Musketeer (fixes the musket that shrinks).** "Pixel-art sprite sheet of a 17th-century musketeer, steel morion helmet, red coat, bandolier, brown boots, with a long matchlock musket. The musket is the SAME length in every frame, as long as in the firing pose (about the soldier's height). Rows:
- walk: 6 frames, musket on the left shoulder, barrel pointing up and back, legs clearly stepping.
- idle: 2 frames, musket butt on the ground beside him.
- aim: 3 frames, raising the musket to the shoulder.
- fire: 3 frames, flash and smoke from the muzzle.
- reload: 8 frames, ramrod down the barrel.
- melee: 3 frames, bayonet fixed on the muzzle, a lunge forward.
- death: 3 frames.
Each in the five directions."

**3. Field cannon crew pushing (so the gun walks instead of bobbing).** "Pixel-art sprite sheet of a bronze field cannon on a wooden carriage pushed by two red-coated gunners. Rows:
- move: 6 frames, the gunners leaning into the wheels with their legs stepping, the wheels turned a little further in each frame.
In the five directions, with the same scale and camera angle as the existing cannon sprite."

## Next units (round 4): ideas and prompts

**Built (Oct 2026), with the user's changes:** the Stormcaller as below; the Cuirassier is
melee only and fast (no pistols); the Spore Mother does not spawn broodlings or attack
through the ground: walking she can't attack, rooted she lobs big area-damage spit blobs
(and spreads swamp), and she casts the healing miasma.

The factions so far:
- **Crown** has modes (bayonets, limbered/unlimbered cannon, canister/round shot).
- **Clockwork** has modes and fields (Tesla Cart, tower lightning).
- **Brood** has only bodies. Its next unit should give it modes and spells, in the Brood way: living things that change shape.

### Clockwork: Stormcaller (the storm spell)
A walking lightning engine.
- **Attack:** weak, a short zap.
- **Storm spell:** throws a STATIC STORM on a spot: a 3-tile circle of lightning for 3 s. It does a little damage and STUNS everything inside for as long as it stands there (friends too, so aim it).
- **Cost:** each Stormcaller carries its own charge. The charge fills only inside a Clockwork field (a tower, pylon or deployed Tesla Cart). The storm empties most of it, so you have to bring the casters home, or a cart forward, to recharge.
- **Counters:** fast units that reach it before it casts, and anything outranging it. It is fragile.

Prompt: "Pixel-art sprite sheet, 16-bit SNES style, of a clockwork 'Stormcaller' automaton: tall thin brass-and-iron figure with a copper Tesla coil rising from its back like a crown, glass capacitor jars on its chest glowing blue, long jointed arms ending in iron forks, red cloth panels (pure #FF0000) on its shoulders and waist. Rows: walk (6 frames), idle (4 frames, capacitors flickering), attack (4 frames, small zap from the forks), cast (6 frames: arms raised, coil blazing, a bolt shooting upward), death (4 frames, sparks and collapse). Five directions as rows: south, south-east, east, north-east, north. Flat solid slate background #34404F, no shadows, no text, every frame the same size and scale, figure about 1.3x the height of a musketeer."

Storm effect prompt: "Pixel-art spell effect sheet, 16-bit style: a circular lightning storm seen from above at a 3/4 angle, about 96 px wide. Rows:
- appear: 4 frames, sparks gathering into a ring;
- storm: 6 looping frames, crackling bolts inside a glowing blue ring, small bolts striking the ground;
- fade: 4 frames.
Electric blue and white, flat solid slate background #34404F."

### Crown: Cuirassier (cavalry)
Fast, armoured horseman with sabre and pistols: scouting, harassing workers, running down cannons.
- **Mode, carbine / sabre:** at the gallop he charges with the sabre (bonus damage on the first hit after a run). Stopped, he fires pistols at short range.
- **Charge (automatic):** after running 3+ seconds his next hit knocks the target back, like the pike push.
- **Counters:** pikes (bonus vs cavalry), and spitter acid.

Prompt: "Pixel-art sprite sheet, 16-bit SNES style, of a 17th-century cuirassier: armoured horseman with a steel lobster-pot helmet and breastplate, red coat sleeves and saddle cloth (pure #FF0000), dark grey horse, sabre and two wheel-lock pistols. Rows:
- walk: 4 frames;
- gallop: 6 frames, a clear gallop cycle;
- idle: 4 frames, the horse shifting;
- sabre: 4 frames, a slash from horseback;
- pistol: 4 frames, aim and fire with flash and smoke;
- death: 5 frames, the horse falling and the rider thrown.
Five directions as rows: south, south-east, east, north-east, north. Flat solid slate background #34404F, no shadows, no text, all frames the same size and scale, the rider's head at the same height as a standing musketeer's plus the horse."

### Brood: options for its caster (pick one or mix)
1. **Spore Mother (heal cloud, recommended).** A bloated, slow creature with gas sacs.
   - **Mending Miasma (spell, costs essence):** a green cloud 3 tiles wide for 8 s. Brood inside regain health over time, up to a cap (e.g. 30% of their max per cloud, clouds don't stack). It blunts cannon and steam-walker splash without cancelling it.
   - **Mode, rooted / walking:** rooted she can't move, spreads swamp around her and slowly heals everything on it. Walking she follows the swarm.
2. **Burrower (a mode, like a lurker).** Burrowed it is hidden and can't move, but sends a line of spines through the ground (great against massed infantry). Unburrowed it is a fast, weak crawler. Detection: Clockwork towers and Crown missionaries reveal burrowed units nearby.
3. **Hive Warden (shares pain).** Links up to 8 nearby Brood; damage taken by any linked unit is spread over all of them. That is great against single big hits and splash, and useless if the link is broken by killing the Warden.
4. **Bloater (gas bomb).** A floating sac that drifts to the enemy and bursts: an acid cloud that lowers armour (enemy units take more damage) and slows. Flyer, cheap, one use.
5. **Brood Queen spell, Spawn Broodlings:** on a dying Brood unit near her, 2 broodlings burst out (a swarm that refills itself).

Prompt for the Spore Mother: "Pixel-art sprite sheet, 16-bit SNES style, of a 'Spore Mother': a large, bloated swamp creature on six stubby legs, translucent green gas sacs on its back, bony plates, small red crest spines (pure #FF0000), dripping glowing green spores. Rows:
- walk: 6 frames, slow and heavy;
- idle: 4 frames, sacs pulsing;
- cast: 6 frames, sacs swelling then venting a green gas cloud upward;
- root: 5 frames, legs digging into the ground, roots spreading (the game plays it backwards to uproot);
- rooted idle: 4 frames;
- death: 5 frames, the sacs bursting.
Five directions as rows: south, south-east, east, north-east, north. Flat solid slate background #34404F, no shadows, no text, all frames the same size and scale, about the size of a Brute."

Heal-cloud effect prompt: "Pixel-art spell effect sheet, 16-bit style: a soft green healing gas cloud seen from above at a 3/4 angle, about 96 px wide, with drifting spores and tiny glowing motes. Rows:
- appear: 4 frames;
- cloud: 6 looping frames, slowly churning;
- fade: 4 frames.
Flat solid slate background #34404F."
