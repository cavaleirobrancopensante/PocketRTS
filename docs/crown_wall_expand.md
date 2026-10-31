# Crown wall expand (0.25.20, branch crown-wall-expand)

The owner, 2026-10-31: "currently crown ai should attempt to expand making walls, not only palisade but all buildings
that are not in the main base like churches, barracks, foundries, cottages, buildings that have full sprite colliders,
should be a part of their wall, they can't expand in the open without walls".

Code: `scripts/ai_expand_wall.gd` (AIExpandWall, made by the AI as `xw`), hooks in `scripts/ai.gd`. Test:
`tools/test_ai_expand_wall.gd`. Pictures: `docs/shots/crown_wall_expand/`. Switch it off for a "before" number with
`-- xw:off` on the command line. Crown computer, Normal and Hard (not Easy).

## What the computer does

Every Town Hall of the Crown computer that is not its main gets a wall plan the moment it is laid.

1. **The ring.** For radii 8 to 16 tiles round the hall, the hall's area is the ground walked to from the hall without
   going that far (ramps and the cells beside them are left out: a wall goes at the top or foot of a ramp, never on
   it). The ring is the walkable ground just outside that area. Its **ways in** are the ring cells an enemy can walk to
   from its own base without crossing the area; cells reached only through our own walls and gates need nothing.
   The radius with the fewest ways-in cells wins, as long as the hall's two Farms and its Mill fit inside (packed when
   the plan is made, and kept free).
2. **A gate** (two cells where it can) on the ways-in cell nearest the main by land: workers and the army pass it.
3. **Building slots** over the rest of the ways in: 4x3 (Barracks, Foundry, Horse Breeder, Armoury), 3x3 (Church, only
   while it has none) and 2x2 (Cottage) footprints, each covering at least 2-3 ways-in cells, most cells first (up to 3
   + 1 + 4 slots). When the computer builds one of those kinds anyway (supply, more production, the Church), the slot is
   where it goes (`AI._find_spot` asks `xw.slot_for` first). Once the hall stands it also builds into empty slots
   itself while it has the gold: a Cottage while it needs supply, a Barracks (with 100 spare), the Church.
4. **Palisade** fills every ways-in cell no slot covers; it is laid as soon as the hall is placed (as the hall goes
   up), by a crew of 2-3 Labourers, gates first, then the cells nearest the enemy. 60 s after the hall stands, an empty
   slot is closed with palisade instead. Missing pieces are laid again (not during a fight at the hall).
5. **Gold.** The wall's next pieces (up to 100 gold) are kept from the army, research and horses (`AI._hide_kept`)
   and laid first thing each think; the first Farm of a hall on fresh land while the rest is dry comes before the wall
   (nothing else pays then: test_ai_expand).
6. **Guards.** While less than 85% of the ways-in cells are closed, two thirds of the army stay as the hall's guards
   (they used to drop to a third after a minute). A hall laid by another path than the hall plan gets guards too.
7. **Inside.** The hall's Farms and Mill go on the room packed for them inside the ring (`xw.inside_spot`), so the
   walk from the hall to them never leaves the wall. Other buildings never take the wall's cells or that room
   (`xw.hold`/`release` mark them as terrain while the computer looks for a spot).

The main base is untouched: its ramp Cottage wall and the 2:00 anti-rush opening are as before (the plans only start
with the second hall).

## What it builds where (test_ai_expand_wall, seed 7, Hard Balanced, Powder Mill opening, a Brood that stands still)

On all three maps the first expansion is the natural just below the main's ramp, against the map's west edge, so the
wall is one line: from the foot of the main's ramp (where the gate is, toward the main) down and round to the map's
edge, the side facing the rest of the map.

| Map | Hall stood | Ring | Ways-in cells | In the wall | Shut at +3:00 | Farms / Mill |
|---|---|---|---|---|---|---|
| Ashford Crossing | 8:14 | 11 tiles | 38 | Barracks, 2 Cottages + 28 palisade + 2-cell gate | 100% (sealed) | 2 Farms + Mill inside |
| Kestrel Rise | 8:03 | 12 tiles | 36 | Barracks, Cottage + 28 palisade + 2-cell gate | 100% (sealed) | 2 Farms + Mill inside |
| Cinder Steps | 8:27 | 13 tiles | 33 | Barracks, Cottage + 26 palisade + 1-cell gate | 100% (sealed) | 2 Farms + Mill inside |

Earlier runs (the games are not the same twice) had 2 Barracks + 2 Cottages (Ashford) or 2 Barracks + 3 Cottages
(Kestrel) in the wall. The first pieces go down with the hall; the hall's Farm comes, then the empty slots turn to
palisade at +1:00 and the wall is closed between +2:00 and +3:00 (the Crown's gold comes in harvest lumps at that
time of the game). The guards (two thirds of the army) stand there until 85% is closed.

Pictures: `docs/shots/crown_wall_expand/<map>.png` (the base as it stands) and `<map>_plan.png` (the plan drawn over
it: ways-in cells orange, gate cyan, building slots white, the room kept for the Farms and Mill green).

## Numbers checked

- `tools/test_ai_expand_wall.gd` (3 maps): see the table.
- `tools/test_ai_wall_vs_rush.gd`: the same as without the plan (`-- xw:off`): every check passes but the third
  Musketeer by 2:40 (170-171 s with and without; the known slip noted in CLAUDE.md, 2:49 at worst).
- `tools/test_ai_expand.gd`: the Crown lays its new hall within 90 s and earns again (380 in the last 60 s, as
  without the plan; the first try spent the Farm's gold on palisade on dry land: fixed). The Clockwork case fails the
  same way with `-- xw:off` (earns 0 in the last 60 s on seed 3): not this change.

## Open questions for the owner

- **Cost.** A ring on open ground has 30-40 ways-in cells; buildings cover 8-14 of them, palisade the rest (about
  500-650 gold of palisade and gates per expansion). The Crown's economy at 8-10 minutes runs a little behind the
  unwalled one while it pays for it. Smaller rings mean farms outside the wall.
- **Later expansions** on open ground (the third hall, 50-60 ways-in cells at radius 11-16) get the same treatment and
  cost more; they could be walled only toward the enemy's side.
- **Slots wait 60 s** for a building before palisade takes over; longer means more buildings in the wall, shorter means
  a wall sooner.
- The first Armoury and Foundry keep their spot on the main's plateau (round 6: tech behind the main wall); only later
  Foundries and the other kinds go into an expansion's wall.
