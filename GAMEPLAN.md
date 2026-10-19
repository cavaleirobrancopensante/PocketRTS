# Pocket RTS — game plan

A StarCraft 2 / Beyond All Reason style RTS for phones and the browser, made in Godot 4.7.

## Decisions so far

- **Three factions, asymmetric in every respect**: economy, building, production, army size, strengths and weaknesses.
- **Engine feel like Beyond All Reason and StarCraft 2**: units act individually, with no formations. Box-select, attack-move, control groups, fast responsive micro, and a macro economy.
- **Art**: low-res, NES-style pixel art made in ChatGPT; 3/4 top-down view; 5 facing directions (the left-facing ones are mirrored in-game).
- **Team colour**: every unit's team-coloured parts are pure red (`#FF0000` + one dark shade `#960000`); the game recolours them per player.
- **Order of work**: all Crown sprites first, then the other factions, then the game.

## Factions

| | The Crown | The Brood | The Clockwork |
| --- | --- | --- | --- |
| Theme | 17th-century musketeers and pikemen | Beasts / lizard swarm *(to design)* | Primitive, steampunk-ish clockwork constructs *(to design)* |
| Economy | Labourers mine gold and carry it home | *(to design)* | *(to design)* |
| Building | Labourers construct buildings | *(to design)* | *(to design)* |
| Army | Fewer, expensive, ranged-heavy units | *(to design)* | *(to design)* |

## The Crown — units

| # | Unit | Role | Sprite |
| --- | --- | --- | --- |
| 1 | Labourer | Worker: mines gold, builds | ✅ `art/crown/labourer.png` |
| 2 | Musketeer | Ranged line infantry | ✅ `art/crown/musketeer.png` |
| 3 | Pikeman | Anti-cavalry, anti-charge, screens shooters | ✅ `art/crown/pikeman.png` |
| 4 | Grenadier | Splash damage against swarms | ⬜ |
| 5 | Dragoon | Mounted raider, carbine and sabre | ⬜ |
| 6 | Field cannon | Siege, long range, slow | ⬜ |
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
