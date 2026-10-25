# Clockwork rework: the Line (steam main + rails)

Status: PLAN (2026-10-25), nothing built. Follows docs/design_principles.md (exposed income, forced
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
