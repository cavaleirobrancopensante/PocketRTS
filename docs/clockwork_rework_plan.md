# Clockwork rework: the Line (steam main + rails)

Status: PHASES 1 AND 2 BUILT on branch wt-line (2026-10-25, v0.14.7+; see "What was built" at the end). The rest is still the plan. Follows docs/design_principles.md (exposed income, forced
expansion, meaningful base building, soft counters, telegraphed effects).

## The idea
The whole faction hangs on one visible structure, the **Line**: a big steam pipe laid across the map, with
rails running on top of it and pressure relays beside it. Where the Line goes, the Clockwork is strong. Away
from it, constructs run down. The Line is also the weak point: cut it and everything downstream starves.

## Core rules
1. **Pressure.** Boilers at the Clocktower make pressure. Pipe segments carry it. Pressure drops with distance
   and with how many consumers draw on the same stretch. A **Pressure Relay** (a beside-the-pipe building)
   boosts it back up. Buildings must touch the Line to work; their speed follows the pressure there.
2. **Rails and trains.** Rails run on top of the pipe. Ore trains haul ore from Drills to the Clocktower.
   Trains stay on rails, are slow to start and turn, and are an exposed, visible target. Throughput of the rail
   (trains per stretch) caps the income of a long Line.
3. **The field.** A construct near the Line (or a Spring Tower / Relay) stays wound. Away from it, it runs down
   (the existing wind-down mechanic), so the army wants to fight along the Line and expansion means extending it.
4. **Winders become Platelayers.** They lay and repair pipe and rail segment by segment, crank constructs,
   and are fragile (a raid target). They no longer carry batteries across the map.
5. **Cutting the Line.** A destroyed segment stops pressure and trains downstream. Repair is cheap and fast but
   needs Winders on the spot. Loops (two routes to one place) give redundancy at a cost.

## Why it fits the principles
- Economy first: placement matters because pressure, rail throughput and depletion make it matter.
- Forced expansion: ore under each Drill depletes; a new field means a new Line branch.
- Exposed income and anti-snowball: a long Line is fragile and its pressure thins; raiding is rewarded.
- Defender's advantage fades: the Line is easy to protect when short, hard when long.
- Soft counters: out-running the field (flyers, raids), cutting the Line, or killing relays and Winders.

## Decisions I recommend (the owner to confirm)
- Pipes and rails do NOT block movement (units cross them). They are targetable but low-HP segments.
- The player lays the Line by dragging between two points; the game routes it on free cells and shows the
  cost and pressure preview. Mobile: tap start, tap end.
- Units can ride trains along the Line (fast reinforcement and retreat) but not leave mid-track. Armies on
  trains are vulnerable: that is the trade-off.
- Batteries stay only on mobile units (Tesla Cart, Stormcaller, Ornithopter) as their own small charge.
- Cutting the Line slows (pressure falls to zero downstream) rather than destroying anything.

## Build phases
0. Lock the design: answer the open questions above; update docs/design_principles.md notes.
1. Prototype: pipe segments, a pressure solver (graph, recomputed every 0.5 s), Boilers as sources, buildings
   gated by pressure, a pressure overlay. No rails yet.
2. Rails and ore trains replace Winder battery hauling; Drills replace Ore Crushers; save/load and online
   snapshots carry the Line.
3. Field and roster: wind-down tied to distance from the Line; Relays; adjust the unit roster and costs.
4. AI: a Line planner (paths to expansion sites, repair, defending the Line) and the balance study harness
   (docs/ai_balance_study.md tooling) to tune against Crown and Brood.
5. Art and sound (ChatGPT prompts: pipe straight/corner/T/cross/endcap, relay, drill, ore train, platelayer),
   help texts, translations (pt-BR, es) and voice lines.
6. Polish, tutorial, playtest logs.

## Risks
- Pathing and rendering of a free-form network (keep it on the grid, overlay only, non-blocking).
- AI skill: laying and defending a Line is a new capability, the biggest effort after the core.
- Mobile readability: the pressure overlay and Line tool must work with taps.
- Online sync: pipe state must be part of the snapshots.


## What was built (phases 1 and 2, branch wt-line)

Files: scripts/line.gd (LineNetwork: segments, A* routing, the pressure solver, drawing, save/online rows),
line_seg.gd (PipeSeg), line_tool.gd (the Line tool), line_work.gd (the Winder's lay order), line_ai.gd (the
computer's planner), line_art.gd (sprite loader with code fallbacks), rails.gd (trains of a match, routing,
buying, save/online), train.gd (a train), ore_drill.gd (the Drill's digging and working loop). Tests:
tools/test_line_pressure.gd, test_line_build.gd, test_line_save.gd, test_line_rails.gd, test_line_ai.gd (a
7-minute Hard Clockwork run), tools/line_art_test/make_sheets.py (importer test on synthetic sheets);
screenshots: tools/shot_line.gd. Art: tools/import_line_art.py cuts art/redraws/line_*.png by connected
components and writes the game files; every picture falls back to code art when its file is missing.

### Decisions taken (numbers live in Defs.LINE, Defs.RAIL, Defs.TRAINS)
- One Line segment = a pipe with its rail on top (laid together, one cost). 8 ore, 2.5 s to lay, 140 hp,
  armour 1. Winders lay it; Winders repair it (the normal repair, ore at a quarter of the price). Units walk
  over it; buildings cannot be placed on it. Trains and pipes are targets of last resort (trains first).
- Pressure (solved every 0.5 s per team, label-correcting): Clocktower 40 and Boiler 30 supply, head 1.0 at a
  touching pipe, falling 0.025 a segment (40 segments to zero). Pressure Relay (75 ore, 2x2): with at least 0.25
  coming in it pushes out min(0.9, in + 0.5) on every pipe it touches. Consumers draw (Drill 12, Crusher 12,
  Assembly 16, Engine Hall 20, Capacitor 10, Pylon 8, Relay 4); when a connected Line's draw passes its supply
  all pressures scale by supply / draw. A building works at 0 below pressure 0.1, then from 25% speed rising
  linearly to 100% at 0.8; no touching pipe = "NO LINE".
- Ore Drill (140 ore, 35 s, 3x3) replaces the Ore Crusher (Defs.rail_econ, default true; false puts the old
  Winder battery hauling back untouched). It digs its Clocktower's lode (so ore still depletes per Clocktower)
  at 7 ore/s x pressure speed into a 160 ore stock; the Crusher's quarter-rate on spent ore is kept.
- Ore Train (110 ore): loco + 2 cars, 80 ore, 2.4 cells/s x pressure speed, 420 hp, armour 2. It shuttles
  Drill -> Clocktower by itself (picks the fullest Drill nobody is heading for), waits up to 7 s for a fuller
  load, pays on arrival. Troop Train (150 ore): 8 soldiers, 3.0 cells/s; sent by the RIDE order (the soldiers
  walk to the nearest Line cell, ride to the cell nearest the tapped spot; lost train = riders out, 30% hurt).
- Throughput: a train keeps 8 cells behind the train in front (same direction; 2 cells from a standing one),
  so one rail carries at most 80 x 2.4 / 8 = 24 ore/s at full pressure. Trains going opposite ways pass (double
  track is assumed). A cut Line strands the trains beyond it ("stranded", they retry every second and re-route
  over a loop if there is one); pressure under 0.1 stops a train too.
- Start: one Drill and one Ore Train, a finished main from the Clocktower to the Drill. Up to 10 trains a team.
- Computer: Hard Clockwork lays one main at a time to every building without Line, buys 1.5 Ore Trains per
  Drill, builds Drills instead of Crushers. It does not use Troop Trains, relays, or loops (phase 4).
- Online: segments in snapshot key "ln" (when the fingerprint changes), trains in "tr" every snapshot; the guest
  only draws. Commands: lay_line, buy_train, ride_order. Saves: "line", "trains" (with riders), drill stock.

### Rough edges and for the owner
- Boilers still fill batteries, but Winders no longer haul them (no Crusher to take them to): Energy is whatever
  waits in the sources (cap about 22 a Clocktower with 2 Boilers). Winders at the sources look idle.
- Deposits are the Clocktower's lode, not map outcrops: a Drill does not have to sit on ore (placement is by
  pressure and the Line only). Tying Drills to the map's ore patches is the natural next step (forced expansion).
- Trains are not selectable and take no orders except RIDE. No timetable, no switches, one hall per train.
- Double track assumed; a train standing on a starved cell cannot leave it (a Line too long for its pressure
  is dead at the far end: relays fix it).
- Guests (online) can buy trains and RIDE, but cannot give pipe repair orders to host Winders directly.

### Recommendations for phase 3
Make the field follow the Line (wind-down by distance from any powered segment/Relay), give the Drill the
map's ore patches, add train selection with a RECALL/RIDE-from-station button, and let the AI use relays,
loops and Troop Trains. Then run the balance study (rail cap 24 ore/s and drill rate 7 are the dials).


## Update 0.14.11 (branch wt-rail2): two tracks, loops, couplings, size
- Drawn size: pipes, rails and trains are 1.5x (Defs.LINE.scale), the grid cell is still 32 px (tiles overlap their neighbours, drawn top row first).
- TWO TRACKS: every Line segment has one lane per direction, right-hand drive (`Train.lane_of`, Defs.RAIL.lane px off the centre). A train queues only behind a train going the SAME way (a standing train blocks only the lane it faces); head-on trains pass. Rail vehicles (Units, scripts/cw_rail.gd) snap to their lane, follow a slower vehicle ahead in the same lane, and a slow or standing one steps into a SIDING when a faster one comes up behind it (or queues behind it); a queue gives up after 6 s with no siding near.
- LOOPS: `LineNetwork.plan` adds a loop to a run that begins or ends at a Drill or the Clocktower (Defs.RAIL.loop_kinds): the full ring round the footprint when it fits, else the smallest rectangle of rail (4..9 a side) that touches the building and the run (`find_loop`). It is part of the plan's cells (cost, ghost in amber, AI and start Line get it through connect_building). Trains route over (cell, heading) states: no U-turn except at a dead end (a pause, then they back out and swap lanes; the wagons swing in), and a building that has a loop is served on the loop cells.
- COUPLING: wagons are strung along the locomotive's trail at a fixed straight-line distance (`Train.layout`, `coupling`), per view (side / end on), a drawn hook in side views.
- Not done: loops for the Rail Yard and Boiler (trains do not stop there); a loop is skipped when no free rectangle exists (the dead-end reversal then applies); trains still ignore rail Units in their lane.
