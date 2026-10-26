# Limbered guns and horses: fixes (0.14.36)

Branch `fix-guns-horses`: the unmerged branches `fix-limber-gate-wip` and `fix-horse-vanish-wip`
ported onto today's code (not merged as they were), plus the hauler pathfinding report.

## 1. Limbered guns clipping through walls and jamming at gates, wall ends and cliffs

**What was wrong.** A limbered Field Cannon, Mortar or Powder Wagon is one unit (the gun's body);
its horse team is only art drawn ahead of it along `facing`. Terrain was checked for the body
alone (with its full, wider-than-a-tile radius), plus one spot a fixed distance ahead. So the
horses could stand in a wall, a palisade or over a cliff, the wide body jammed in one-tile
gates, and the team could swing its nose into a wall end and stick there.

**What changed** (scripts/unit.gd, `_towed()` and the tow helpers after `_move`):
- `_tow_clear(p, f)`: the body (a narrow `_tow_body()`, at most 15 px, so it fits a one-tile
  gate) AND every horse spot from the barrel to the lead horse, 11 px apart (closer than a wall
  or cliff ring is thick), must be clear of terrain, walls and buildings.
- `_tow_resolve`: a move is taken as is, else sliding along x or y, else the gun stays (a gun
  already wedged is popped out by the normal terrain rule).
- `_tow_turn`: the team turns only as far as its spots stay on legal ground; when the arc is
  shut (a wall end beside the team) it swings at once to the nearest clear heading to the one
  it wants, so it never stays pointing into the wall.
- `_tow_gate_approach` (in `compute_path`): through a gate the team must go straight, so the path
  gets a waypoint 80 px before and after each gate it crosses, on the gate's axis (the middle of
  the opening when gates stand side by side). The way through is taken from the first path
  point past the gateway (or the goal), not the first leg: the pathfinder snaps a start inside a
  gate cell to the cell behind it, which sent a gun standing in a gateway back out (fixed in
  this port).

**Tests.** `tools/test_limber_gate.gd`: cannon, mortar and Powder Wagon, one horse and a team of
three, through a gate in a north-south and an east-west wall, round a wall end and a one-tile
cliff line from 36 angles, and starting in or just short of a gateway; every run gets through,
none backs out of a gateway, and the horse end is never on an illegal cell (checked every tick).

## 2. Horses vanishing into buildings

**What was wrong.** A horse taken for a Horseman, Cuirassier, Dragoon, Field Cannon, Mortar or
Powder Wagon walked into the Barracks or Foundry and was deleted (`consume_unit`); it was also
deleted unconditionally after 90 s even if it never got there (a wall, a crowd). The horse was
only "in" the queue entry's kit, so a horse stuck on the way just disappeared.

**What changed.** The horse walks to its own spot beside the building (`Game.hitch_spot`: round
the building's rim, on open ground it can reach, away from the rally side, a body's width from
the other hitched horses) and stands there HITCHED (`Unit.hitch_p`), visible and untouchable
(`untouchable()`), facing the building. The queue entry keeps the live horse's id (`kit.hid`,
`Game._kit_horse` / `entry_holds`); when the recruit is done (`Game.spawn_trained`) the rider
comes out on the horse's spot, on its coat, health and miles as they are then, and the horse is
consumed only then (a gun comes out drawn by it). Cancelling (`Game.refund`, `release_rid`) frees
the horse where it stands. Town Hall haulers and reserved horses walking from a breeder end the
same way (`_hitch` -> `walk_into` -> `hitch_horse`). Saves fold the hitched horse into the kit
(`SaveGame._kit_save` drops `hid`; a reserved horse still on its way is saved with its
reservation). The horse card says "Hitched at the Barracks till its rider or gun comes out".

**Tests.** `tools/test_horse_vanish.gd` (the horse stays after reaching the Barracks, hitched on
its own spot, visible and untouchable, and nobody else can take it; cancelling frees it; the
Horseman comes out on its coat by the hitch; four queued horses get a spot each; a delayed horse
is brought to the hitch, not deleted), the updated
`tools/test_horses.gd`, and `tools/audit_horses.gd` (AI against AI: every horse that leaves the
field is accounted for, plus LEAD STUCK and GUN STUCK counters): Greenhold, Hollowfen,
Glimmerdeep (9 min) and Greenhold vs the Brood, Amberfall (14 min): no suspect, no stuck lead,
no stuck gun.

## 3. A Labourer leading a horse from the Breeder gets stuck

**What was wrong.** Partly the same cause: the horse he hitched then had to walk into the
building (and could stick there). The hauler's own trouble was `Game.approach_point`: it picked
the nearest free cell on the building's rim, even one in a pocket shut in by a palisade or other
buildings (or across a wall), which he can't reach, so he walked at the palisade until the 16 s
fallback.

**What changed.** `approach_point` prefers rim cells in the walker's own region (the old choice
only when no rim cell is reachable). It is used by every unit walking to a building, so workers,
builders and the AI get the same benefit.

**Tests.** `tools/test_haul_pocket.gd` (now with the palisade wrapping round both corners, so the
nearest reachable ground to the pocket is out of reach of the Barracks): he hitches the horse
within 7 s without standing still for a second (before: 8.6 s, a 1.7 s standstill against the
palisade), on open ground, and the Horseman rides out. Also passing: test_haulers,
test_haul_fallback, test_horse_deliver, test_horse_leash, test_horse_gate, test_horse_care,
test_loose_horses, test_cliff_horse, test_gate_lock, test_ai_brood_horse.
