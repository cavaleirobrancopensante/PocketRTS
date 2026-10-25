# Clockwork roster prototype (v0.14.9)

An experiment, not a commitment: ten ideas for the Clockwork roster, built quickly so the owner can play with them and cut
what is not fun. Everything new is data in `Defs` plus one behaviour file (`scripts/cw_units.gd`), hidden unless the roster is
switched on, and easy to remove (see the end).

## How to try it

- **EDITOR menu > CLOCKWORK LAB**: one tap starts a match, you as the Clockwork on Greenhold against a computer that never
  attacks, with 40,000 ore and 600 energy, a Line run from the Clocktower with an Assembly Works, Rail Yard, Engine Hall,
  Boiler and Charging Pylon beside it, the SANDBOX panel (CLOCK tab lists every unit, also the new ones) and a hint line.
- Or **Settings > CLOCKWORK LAB** (on): the roster is also available in ordinary matches (the computer ignores it). Do not use it online.
- Production: foot units (Tin Militia, Scrapper, Rail Rifleman) from the **Assembly Works**; rail vehicles from the new **Rail Yard**
  (220 ore, needs an Assembly Works, must touch the Line; vehicles appear on the Line beside it). Reasons: the Winder's own
  building stays the foot-soldier house, and a separate yard keeps the card short and makes a place to defend or deny.
  Heavy Locomotive needs a Boiler; Carrier Car, Tesla Locomotive and Storm Engine need a Charging Pylon (Storm Engine also a Boiler).
- Rail vehicles are ordinary units (selectable, groupable, ordered with the normal MOVE / ATTACK), whose paths run over the
  finished Line segments of their team and whose position snaps back to the track after every step. Speed follows the pressure under
  them like the trains (Defs.line_speed) and they never wind down on the Line. Rail vehicles of one side pass through each other.
- Hotkeys follow the card pattern (`FIXED_KEYS` in hud.gd): SIDING N, CREW OUT O, CREW IN I, PLATES E, SET UP D (PACK D), BOARD G,
  THUNDER T, DOCK Q, CARRY F, DROP (auto). Training keys: Tin Militia A, Scrapper D, Rail Rifleman F, Work Car S, Plate Wagon A,
  Heavy Locomotive D, Carrier Car F, Tesla Locomotive G, Storm Engine B (each on its own building's card).

## The ten mechanics

1. **Siding** (SIDING button on a Winder or Work Car, 12 ore): tap a straight finished piece of the Line to give it a side arm (a
   second tap removes it); at least 4 tiles between two. A rail vehicle that meets another of its side head-on within 3 cells pulls
   into a free siding within 4 cells, waits at least 1.2 s (at most 9 s) until the track is clear, and rejoins; a unit gives way to a
   train; two units: the lower id waits. No siding near: it passes through (the track counts as double, so nobody deadlocks or blocks).
   Sidings are saved with the Line. `CwRail.steer`.
2. **Work Car** (260 ore, supply 2 + its 3 Winders): crew of 3 Winders aboard (stowed: untouchable, wound). BUILD with the car selected
   sends the car along the Line until the site is within 6 tiles, a Winder climbs out carrying the crate (no Clocktower trip),
   starts and builds it; LINE / LAY with the car sends the whole crew out to lay. Idle crew mend damaged buildings in range
   (auto-repair), walk back aboard after 2.5 s idle; CREW OUT / CREW IN force it; the car waits up to 6 s for its crew before leaving
   without them. If the car dies the crew stand on the ground at half speed (the old Winder behaviour then). The old Winder is untouched.
3. **Tin Militia** (90 ore for a batch of 4, 1 supply each): melee, can only be and fight within 7 tiles of any finished Line segment or
   Clocktower. Orders are clamped to the nearest allowed ground, ATTACK on something beyond is refused, one pushed out walks back, and
   near the Line they never wind down. They are the crew for the Heavy Locomotive and Storm Engine (BOARD).
4. **Scrapper** (110 ore): when anything dies within 260 px (friend, foe, any team) it gains a stack: +10% damage, +4% speed, a little
   healing; up to 5, one lost every 4 s; at most one gain per 0.4 s (a splash kill counts once). A Tin Militia body counts double.
5. **Plate Wagon** (180 ore): its body is a gate across the track (46 px each side of its middle, 64 with plates up) that enemy ground
   units cannot cross (they are pushed back and slide along it; they will go round it on open ground; flyers ignore it; own units pass).
   PLATES: 6 s of side plates (14 s cooldown): ranged hits on your units within 150 px do 40% damage. Siege (cannon, mortar: building
   bonus >= 1.5 or splash >= 30) does double damage to the wagon.
6. **Heavy Locomotive** (340 ore): slow, armoured cannon turret with splash; full damage on the rails. SET UP (any spot up to 6 tiles
   from the Line) drives it off the rails; set up it needs Tin Militia aboard: power 60% x (0.4 + 0.6 x crew/3) of damage and rate, no
   crew = cannot fire. BOARD sends the selected militia; aboard they are off the field (safe) and wound. CREW OUT lets them off. PACK drives
   it back to the rails. If it dies the crew climb out with 30% damage.
7. **Rail Rifleman** (95 ore): lightning rifle; within 2 tiles of the Line +30% range and +30% damage (the card shows ACTIVE). Can RIDE a
   Troop Train (the normal RIDE button) and fires from the carriage at 0.8x the rate with the bonus.
8. **Carrier Car** (240 ore, one per side): deck for 2 Ornithopters. DOCK sends selected Ornithopters to land on it; landed they heal 14 hp/s,
   wind up 0.5/s and get a yellow battery after 3 s, and ride along when the car moves. CARRY takes one small unit (supply 1, not mounted,
   not a gun) standing within 110 px into the flyer; DROP flies it to a spot and sets it down (shot down: it falls hurt). Any move order
   makes the flyer take off. The car's death frees the flyers.
9. **Tesla Locomotive** (300 ore): fires a bolt at ground or air that jumps to 2 more enemies (55% falloff) and runs along the pipe to up to 2
   enemies standing at nearby Line cells; damage scales with the pressure under it (60% at low pressure, +60% bonus above 50%); Clockwork
   non-worker units within 70 px are overcharged at once. The old Tesla Cart stays.
10. **Storm Engine** (340 ore, no weapon): THUNDER at a spot within 330 px (it runs along the Line toward the spot first): after 1.2 s a
    storm (radius 110 px, 9 s, 9 damage/s and the acid slow to every enemy unit inside; buildings are not hurt), 20 s recharge. SET UP off the
    rails with Tin Militia aboard: storms at 60% damage and 70% size, and nothing without crew. Storms outlast their engine.

## Trains: coupling rail vehicles (v0.14.13)

Rail vehicles hook together into ONE train (a "consist", `scripts/cw_consist.gd`, numbers in `Defs.CW["couple"]`). Roster rail vehicles
only: the Work Car, Plate Wagon, Heavy Locomotive, Carrier Car, Tesla Locomotive and Storm Engine. The Ore Train and Troop Train are a
different thing (the `Train` entity of the economy: not selectable, no orders) and stay as they are; players cannot couple wagons to
them. Turning them into ready-made consists would mean making them units first.

- **COUPLE** (command card, hotkey C) with two or more vehicles or trains selected: the one with a Heavy Locomotive (else another
  locomotive-type: Tesla Locomotive, Storm Engine; else the biggest group) is the main train and waits; the others drive along the Line
  to its last car and hook on within 78 px (they give up after 45 s if the Line is cut). **Driving into an idle vehicle** that is straight
  ahead in the same lane (40 px) hooks on too: the moving one goes behind, and the whole train carries on to where the mover was
  going. New vehicles (4 s) and the parts of a train just uncoupled (5 s) are left alone by this. A train holds 6 cars.
- **One train.** The front car is the DRIVER: it plans the path, is steered by `CwRail` (lanes, queueing behind a slower vehicle or
  train going the same way, the loops are just track), and takes the orders. The other cars do not move on their own: each tick every
  one is put on the driver's trail at the tight coupling distance (half of each length less the hook overlap: 64 px side on, 27 px end on)
  as a rigid chord, so the train holds together round bends, loops and lane changes. A car dragged out of place (a new joiner, a bump)
  slides in at 260 px/s. The steel link is drawn between side-on cars (`CwConsist.draw_links`, code art).
- **Selecting any car selects the whole train** (`Game.set_selection`); an order given to a car goes to the driver. The train goes
  at the speed of its slowest car (`CwConsist.min_speed`, times the pressure under the driver). A Work Car's crew are called aboard
  before a moving train leaves (the usual 6 s wait).
- **Each car keeps its job:** crews build and mend near their car (a Work Car in a train that is driving takes no new jobs), the Plate
  Wagon's gate and cover stay where the wagon is, Tesla Locomotives and Heavy Locomotives (on the rails) fire from the train, Storm
  Engines cast (THUNDER drives the whole train toward the spot first), the Carrier Car's deck carries its flyers along. SET UP takes a
  car out of its train.
- **Heavy Locomotive bonus:** while one is coupled the other cars take `guard` = 85% of the damage (15% less). It applies to every other
  car of the train, wherever the locomotive stands in it. The locomotive's speed (38) is the lowest of the roster, so a speed bonus
  would have been moot.
- **Turning round.** A train cannot U-turn, and wagons must not stick out: told to go back, it stands 1 s and then SWAPS ENDS
  (push-pull): the last car becomes the driver, the trail is reversed, and the order is carried over. So the Heavy Locomotive may end
  up pushing. A train at a dead end does the same.
- **UNCOUPLE** (hotkey U): splits the train in front of the car the player tapped (tap one car, then the button; the front car alone if
  the first car was tapped; the last car if the whole train was box-selected). The rear part is a train of its own, standing.
- **A car dying** (or leaving the rails) splits the train there: the cars in front keep their order, the cars behind become a train
  of their own and carry on to the same place. A train of one is just a vehicle. HP stays per car.
- **Save, load, online:** a unit's save row carries `cpl: [train id, place]` and `CwConsist.restore` rebuilds the trains (the trail is
  re-walked along the Line behind the driver). The host's snapshot carries the trains as lists of net ids (`cpl`); a guest keeps drawn and
  selectable copies (the host moves the cars). COUPLE/UNCOUPLE are not forwarded from a guest (the Lab is not for online play).
- **The AI** ignores all this (it never trains or couples these units).

Rough edges: sidings are for single vehicles (a train is too long for a side arm, so a faster vehicle behind a train queues, then
passes through after the 6 s fallback); a vehicle sent to couple from the far side of a train drives through it; the order of cars is
the order they joined (only the choice of the main train prefers a locomotive, there is no re-sorting afterwards); the lengths of
the cars are the placeholder art's (68 px side on, `Defs.CW["couple"]["len"]`: change them when the real sheets arrive); a loop
at the Clocktower is only used by trains of the economy, a coupled train turns by swapping ends instead.
A Heavy Locomotive (radius 22) can snag at a corner with a cliff or building close beside it (the units' terrain collision, not coupling; found while testing, not fixed: a solo one stops there too).
Test: `tools/test_cw_couple.gd`; screenshots: `tools/shot_cw_couple.gd`.

## The tuning block

All numbers are in `Defs.CW` (one dictionary, with a comment per entry) plus each unit's own line in `Defs.UNITS` between the
`CLOCKWORK ROSTER PROTOTYPE: begin / end` markers (cost, hp, speed, range, damage). Current values:

| key | values |
| --- | --- |
| lab | ore 40000, res2 600, buildings assembly_works, rail_yard, engine_hall, boiler, charging_pylon |
| siding | cost 12, gap 4, reach 4, meet 3, hold 1.2 to 9 s, offset 11 px |
| work_car | crew 3 (max 4), radius 6 tiles, idle_back 2.5 s, depart_wait 6 s, stranded speed 0.5, board 42 px |
| militia | leash 7 tiles, fuel 2 (a Scrapper stack share) |
| scrapper | reach 260 px, max 5, decay 4 s, +10% damage, +4% speed, gain_cd 0.4 s, heal 6 per stack |
| plate | half 46 (64 up) px, radius 150, time 6 s, cooldown 14 s, cover 0.4, siege x2, deploy 1.2 s |
| heavy | crew 3, power 0.6, reach 6 tiles, deploy 2.5 s, splash 34 px at 50% damage, off_speed 0.6 |
| rifle | near 2 tiles, range x1.3, damage x1.3, train rate x0.8 |
| carrier | deck 2, heal 14/s, wind 0.5/s, pick 110 px, one per team |
| tesla | jumps 2, falloff 0.55, pipe reach 96 px, min_p 0.6, pass 70 px, pressure_bonus 0.6 |
| couple | reach 78, bump 40, max 6 cars, reverse 1 s, guard 0.85, close 260 px/s, len 68/28 px, hook 4/1 px, give_up 45 s |
| storm | range 330, radius 110, time 9 s, dps 9, cooldown 20 s, cast 1.2 s, reach 6, crew 3, off_dps 0.6, off_radius 0.7 |

Design notes (docs/design_principles.md): the Scrapper's stacks are capped and decay in seconds (anti-snowball, a quiet brake, not
a scaling engine); the Plate Wagon and Storm Engine telegraph (plates animate, the storm gathers 1.2 s and shows its ellipse) and have
soft counters (siege, killing the engine; storms do not touch buildings); the builders stay fragile (the Work Car is one target for
the whole crew, and losing it strands them); off-rail machines trade power for placement and are helpless without their crew.

## Tests (tools/test_cw_*.gd, each a few seconds)

siding, couple, work_car, militia, scrapper, plate, heavy, rifleman, carrier, tesla, storm, lab (production of every unit and the lab's
setup) and ai (3 minutes of a Hard Clockwork AI with the roster on: no crash, none of the new units trained). Run:
`godot --headless --fixed-fps 30 --script res://tools/test_cw_<name>.gd`. Helpers: `tools/cw_test_util.gd`.
Screenshots: `xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_cw_units.gd -- /tmp/shots_units`.

## Known gaps and rough edges

- Not wired for online play (the new orders go through `Controls` and `CwUnits` directly, not `net_forward`) and not saved: a saved Lab
  game loses crews, stowed units, stacks and the Carrier's deck (sidings are saved with the Line). Treat the Lab as a sandbox.
- The AI knows nothing of the new units or the Rail Yard (it never trains or builds them; it is passive in the Lab). It still fights them.
- Rail vehicles pathfind only along finished Line; an order off the Line takes them to the nearest reachable segment. A Line cut strands them.
  They block nothing for their own side, and nothing blocks them but the Plate Wagon's gate (enemy only) and sidings.
- The Plate Wagon's gate is a segment that deflects; on open ground enemies walk round it (only on a Line through a ravine or between
  buildings is it a real wall). The raised plates are not drawn, only felt (wider gate, cover).
- Tesla "chain along the pipe" is approximated: up to 2 enemies near Line cells within 5 cells of the loco. Overcharge is instant for units
  within 70 px and only for Clockwork non-workers.
- Storm Engine storms do not hurt buildings and flyers inside take damage and slow like the rest. No friendly-fire.
- The Carrier's CARRY takes only supply-1 foot units; the carried unit is not shown on the Ornithopter.
- Heavy Locomotive splash uses `Game.explode` (check friendly fire when tuning); its off-rail speed multiplier is applied while moving to a spot.
- The Work Car's sites queue is per car; a Winder and a car given the same site both start it (harmless: the second lands no crate).
- Selecting a car or loco and pressing BUILD uses the usual build pages; the car is not shown in the group number icons specially.
- Placeholder art only (see below); hit flashes, death and the storm use the existing effects.

## Art sheets wanted

All as the existing unit strips: frames side by side, cell size below, feet at the anchor, five views (s, se, e, ne, n; west mirrored),
team colour in pure red (255,0,0) and dark red (150,0,0), file `assets/units/<kind>/<anim>_<dir>.png`; the loader reads the
frame count from the file width, so any count works.

| unit | cell (w x h) | anchor | animations |
| --- | --- | --- | --- |
| tin_militia | 36 x 40 | 18, 36 | idle 1-2, walk 6, attack 4 (spear thrust), death 4 |
| scrapper | 48 x 50 | 24, 45 | idle 2, walk 6, attack 4 (cutting arm), death 4; ideally stack looks (extra scrap on the body at 2 and 4 stacks) |
| rail_rifleman | 36 x 42 | 18, 38 | idle 1-2, walk 6, attack 4 (rifle arc), death 4; a seated pose for the train carriage |
| work_car | 84 x 56 | 42, 48 | idle 1, move 2-4 (wheel turn, e / n only needed), death 4; hatch open variant while the crew are out |
| plate_wagon | 88 x 58 | 44, 50 | idle (plates down) 1, move 2-4, plates raise 4 + plates up 2 + lower 4, death 4 |
| heavy_loco | 96 x 66 | 48, 56 | idle, move 2-4, attack 4 (turret recoil, turret turns: 8 views ideal), set-up / pack 6 (off the rails on the ground), crewed variant with chimney smoke, death 6 |
| carrier_car | 92 x 58 | 46, 50 | idle, move, death; the deck should leave two landing pads (flyers are drawn over it); empty and occupied variants optional |
| tesla_loco | 88 x 66 | 44, 56 | idle, move, attack 4 (coil flash), death 4 |
| storm_engine | 92 x 70 | 46, 58 | idle, move, cast 6 (mast raised, cloud forming), set-up / pack 6, death 6 |

Also: 64 x 64 command-card icons for the nine units and for SIDING, CREW OUT, CREW IN, PLATES, SET UP, BOARD, THUNDER, DOCK, CARRY, DROP; a
Rail Yard building (4 x 3 tiles, built / construction / damaged / destroyed, like the other Clockwork buildings); the siding tile
(a 32 x 32 overlay with the side arm and buffer in the four directions); a storm cloud effect (about 220 x 150, 8 frames, loopable) and a
lightning ground strike.

## Removing it

Delete the block between the `CLOCKWORK ROSTER PROTOTYPE` markers in `Defs.UNITS`, the `rail_yard` building and its `LINE` / `TEMP_ART` /
`ADVANCED` / `train_keys` / `build` entries, `Defs.CW*`, `scripts/cw_*.gd`, then the one-line hooks (`grep -n "CwUnits\|CwRail\|CwLab\|CwArt\|cw_roster\|cw_gates\|cw_storms"
scripts`): unit.gd (pre_tick, steer, post_move, order_point, target_ok, strike, can_hit, range, cooldown, incoming, on_death, plan_path),
game.gd (_add_unit, tick, train limits, separation, in_overcharge, sweep_ghosts, place_building, siding_order), hud.gd (card, info, hotkeys,
icons), controls.gd (taps), line.gd (sidings), line_tool.gd, train.gd, main.gd (Lab entry, settings row), settings.gd (cw_lab), game.gd `tex`,
`ArtData.UNITS` (back to the plain const), and `tools/test_cw_*.gd`, `tools/shot_cw_units.gd`, `tools/cw_test_util.gd`.
