# Spacing between units (0.25.2)

The owner, 2026-10-31: "it's hard to micro units in combat. They bunch up too much. Maybe we need to expand the
colliders a little bit to make them bunch up less, a little bit less." And then: "I don't want formations. I think
that just by having a little bit of a bigger collider, we're gonna be okay."

## What changed

- Units of one side push each other apart from a bit farther: (both radii) x 1.10 instead of x 0.85, about 29% more
  room. This is the "collider" that keeps them apart (Game.separation, Defs.SPACING). It works standing and walking.
- The body itself is not bigger. Clicks, hits, attack reach, paths, ramps and gates use the same radius as before.
- Enemies still use the old 0.85 (Defs.SPACING_FOE). A Raptor gets as close to a Musketeer as before, so melee reaches
  its prey as before.
- Workers keep the old 0.85 among themselves, so mines, farms, drop-offs and yards are as crowded as before. The
  economy is not touched.
- A unit that is trying to walk and getting nowhere for 0.3 s (Unit.squeezed) is spaced at the old 0.85 by its
  friends. A crowd in a one-cell gap, a gate or a ramp closes up and goes through, then spreads again.
- No formations. Group moves (Game.group_points) are exactly as before: each man heads for about the same place and
  they push apart. (A first try that opened the group's spots out to the new spacing was taken back on the owner's
  word.)
- separation looks 24 px past a unit's radius instead of 18, so two big friends (Horsemen, Brutes) feel each other over
  the whole of their wider spacing.

## The numbers

tools/test_spacing.gd, on Dune Sea, the computers off. "nn" is the average distance from each unit to its nearest
friend, in pixels. The groups start as a loose clump (a few px off a grid, the same every run). The fights are
measured once a second from 4 s in; the targets there cannot die and hold their fire, so the fight stays put.

| case | before | after | change |
|---|---|---|---|
| 30 Musketeers, made shoulder to shoulder, sent 640 px | 16.0 | 19.3 | +21% |
| 30 Musketeers, made spread out, sent 640 px | 16.9 | 21.9 | +30% |
| 30 Raptors, sent 640 px | 12.7 | 15.4 | +21% |
| 30 Raptors in a melee with 20 Musketeers | 11.6 | 15.3 | +32% |
| 16 Raptors and 4 Brutes round one Musketeer | 13.6 | 16.1 | +18% |

Melee still reaches:

| case | in reach before | after | striking before | after |
|---|---|---|---|---|
| 30 Raptors v 20 Musketeers | 14.5 / 30 | 13.6 / 30 | 5.9 | 5.3 |
| 20 round one Musketeer | 11.3 / 20 | 10.7 / 20 | 7.1 | 6.6 |

Round a single man, about one Raptor fewer fits in the ring: they stand a little apart.

## Ramps, gates and gaps

tools/test_pathing.gd on five maps (138 cases): 4 failures before, 3 after. They are the same old cases (a rim click
from the low ground with Brutes, one man short), not the change. Every gap, crowd-of-40, ramp and gate case passes.

Without the "squeezed" rule, the one-cell gap between two Cottages failed: Brutes and Pendulums jammed in it. With it,
they pass as before.

Fixed in the test bed: it took away the Brood Mother with the other side's starting units. Since 0.18.0 the Brood's
base is its Mother, so the match ended at once and the path queue stopped. Units then walked straight at their goals,
and 83 cases failed on the old code too. Now she stays, and the test is useful again.

Stuck time in real games (tools/test_pathing_match.gd, hard against hard, 10 minutes, seed 7). A game is not the same
twice, so read the total.

| game | stuck unit-s a minute before | after |
|---|---|---|
| Greenhold, Crown v Brood | 1.1 | 1.8 |
| Hollowfen, Clockwork v Crown | 8.3 | 4.0 |
| Frostmere, Crown v Clockwork | 4.3 | 4.2 |
| Thornwood Maze, Brood v Crown | 2.1 | 3.2 |
| Kestrel Rise, Brood v Clockwork | 9.2 | 4.7 |
| all five | 5.0 | 3.6 |

Units stuck 10 s or more: 1 before, 0 after.

## Speed

tools/stress_swarm.gd (fixed in the tool too: it looked for a Brood building, and the Brood has none since 0.18.0, so
its armies were never made). 200 Raptors a side, 20 s each, before and after run turn about, twice. The machine was
shared with other jobs, so the frame times jumped about. The processor time of the whole run is the steadier number.

| scenario | processor s before (two runs) | after (two runs) | Raptors left after 20 s, before | after |
|---|---|---|---|---|
| idle: 200 a side standing | 8.9, 9.1 | 8.7, 9.3 | 400 | 400 |
| walk: through each other | 13.0, 11.8 | 13.2, 12.3 | 400 | 400 |
| melee: 200 v 200 | 9.1, 8.8 | 10.6, 9.1 | 27 | 67 |
| grubs: 200 Grubs + 100 Raptors a side | 20.7, 21.2 | 21.7, 19.9 | 173 | 146 |

- Standing and walking cost the same. The melee and grubs runs are the same within the noise.
- The swarms fight a little differently: in the 400-Raptor melee, more were left alive after 20 s (67 against 27).
  With more room between them, fewer Raptors are in the front line at once, so the blobs grind each other down more
  slowly.
- A worker keeps the old reach and spacing in the search itself, so 400 Grubs cost no more than before.

## Pictures

docs/shots/spacing/before/ and after/: musket_move, musket_spread, raptor_move, melee, surround (taken by
tools/test_spacing.gd with shots=DIR under xvfb; the fog is lifted for the pictures only). In melee and surround, the
Musketeers are the test's targets, made standing in rows and told to HOLD.

## How to run it

- godot --headless --fixed-fps 30 --script res://tools/test_spacing.gd
- xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/test_spacing.gd -- shots=DIR
- The knobs: Defs.SPACING (friends), Defs.SPACING_FOE (enemies, workers, squeezed), Unit.SQUEEZE_T.
