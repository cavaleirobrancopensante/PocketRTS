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
