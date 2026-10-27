# Performance pass, v0.14 (the late game)

## Summary

**What was measured.** One big computer-against-computer match, played the same way every
time: The Sundered Realm (the biggest map, 192 by 160 tiles), 2 against 2 (Crown and Brood
against Crown and Clockwork), Hard computers, seed 4242, 18 minutes, about 240 to 270 units
in the late game. The bench (tools/perf_bench.gd) times every frame and every part of the
game the match log's "busy with" lines know (the Prof zones), on the computer profile and on
the tablet profile. On top of that, Godot's own script profiler was attached (through its
remote debugger) to see which functions the time goes to.

**The top costs before**, in milliseconds of work per second of play, late in the match
(minutes 12 to 18, computer profile, native build; the browser is two to four times slower):
units 286, the game tick 93 (of which the fog 46), the HUD's drawing 89 (of which the
selection card 79), buildings 77, the computer players 70. A late minute took 40 to 47
seconds of processor time, and 280 to 365 frames a minute were slower than 33 ms.

**What changed** (every change leaves the game the same: the match's full state, written
every 5 game seconds, is byte for byte the same before and after, over all 18 minutes, on
both profiles):

- the selection card no longer measures its info line again letter by letter 20 times a
  second (that alone made 20 to 70 ms frames whenever a Town Hall or a soldier was selected);
- the fog of war stamps each unit's sight in a quarter of the work;
- the unit grid behind "who is near here" is a flat list instead of a dictionary;
- a dozen look-ups that ran hundreds of thousands of times a second are worked out once
  (a unit's kind, the nearest hall, who is an enemy, the hall lists, the Tesla search);
- path smoothing finds a blocked line sooner; the Brood swamp no longer loops over the
  whole map for every player.

**After**, the same match, same minutes: units 239 (17% less), the game tick 63 (a third
less; the fog 21, less than half), the HUD's drawing 14 (85% less; the selection card 4),
buildings 56 (28% less), the computer players 52 (26% less). A late minute now takes 28 to
34 seconds of processor time (about 28% less), only 32 to 72 frames a minute are slower than
33 ms (five to nine times fewer), and the slowest 1% of frames run at 21 to 27 frames a
second instead of 13 to 16. The tablet profile gains the same (its selection card was even
dearer: 93 ms a second).

## How it was measured

- **The bench**: `godot --headless --fixed-fps 60 --script res://tools/perf_bench.gd --
  sundered_realm crown brood crown clockwork 2v2 minutes:18 [mobile] trace:FILE`. Player 1
  is set up as you (fog, HUD, autosave as in a real match) but played by a Hard computer;
  the mouse wanders over the screen and the selection changes every 6 seconds (the army,
  a hall, a few workers, a production building, nothing), as a player's would.
- **The same match every time**: the previous commit on this branch made matches
  reproducible (a match serial number instead of the engine's instance ids; the path
  queue's 6 ms limit lifted for the bench; sounds silent). Each run writes the whole state
  every 5 game seconds; every change below was checked by comparing that file with the one
  from before the changes (2.1 MB, identical, over all 18 minutes). The tablet profile plays
  the very same match.
- **Godot's script profiler**: `tools/gd_script_profiler.py`, a small stand-in for the
  editor's debugger, takes the game's remote debugger connection, switches the profiler on
  for two late minutes and writes every function's own time, total time and call count
  (how to run it is at the top of the file). It slows the game, so its
  numbers are only for finding where the time goes; all the numbers in the tables are from
  plain runs without it.
- The numbers are "ms per second of play": the ms per frame the bench prints, times 60. All
  runs were native, headless, on a 2-core cloud machine, one run at a time. Rendering is not
  measured headless (the draw calls are, not the graphics card's work).
- The before and after runs are on the same code base (0.14.32, the base of this branch),
  so the changes main has had since don't mix in. CSVs: `v0.14_before_*` and
  `v0.14_after_*` in this folder (`after1` is the first stage alone).

## Where the time went before

| part (ms of work per second of play) | minute 6 | minute 10 | minutes 12-18 |
|---|---|---|---|
| units | 130 | 259 | 286 |
| buildings | 32 | 63 | 77 |
| computer players | 32 | 61 | 70 |
| game tick | 51 | 77 | 93 |
| of which the fog | 21 | 39 | 46 |
| HUD drawing | 77 | 83 | 89 |
| of which the selection card | 73 | 77 | 79 |

What the script profiler found inside them (two late minutes):

- **The selection card** spent 6 ms per drawing in its own code: the info line under the
  name is cut to fit the card by measuring it, cutting a character, and measuring again, and
  that ran every time the card was drawn, 20 times a second while anything was selected.
  A long Town Hall line meant dozens of text measurements per drawing. Its icons were also
  looked up on disk (ResourceLoader.exists) two or three times each, for every portrait.
- **Units**: about 37 microseconds per unit per tick, spread over a hundred small checks.
  The biggest named parts: moving (including keeping apart from neighbours, `separation`),
  the search for targets (`find_target`, 45 microseconds a search), "who is near here"
  (`units_near`, 18 microseconds and 1,200 times a second), workers' work, the animation.
  `is_worker` alone was called 1.7 million times in two minutes, each a dictionary look-up.
- **The fog**: every 0.25 s each unit's sight disk (about 300 cells) was stamped cell by
  cell with bounds and cliff tests on each: 9 to 11 ms per update, up to 19 ms.
- **Buildings**: every Farm, Mill and Cog Press looks up its hall every tick
  (`nearest_hall`, which went through every building and asked for the faction's hall kind
  for each one: 2.4 million calls in two minutes).
- **Computer players**: building lists through filters with a function per item
  (`army`, `_mine`, `workers`), and the Tesla field searches over every unit for every
  Clockwork unit.
- **Spikes** (single slow frames): the selection card (20 to 70 ms), a burst of paths
  (the bench lifts the 6 ms path limit, so its path spikes are bigger than in a real game;
  path smoothing was more than half of each), the fog (10 to 20 ms), the autosave
  (20 to 34 ms), a computer's think (20 to 60 ms: its siege plan floods the whole map,
  its build search).

## What changed

| where | before | after | how |
|---|---|---|---|
| Selection card (hud.gd `_draw_panel`) | the info line fitted letter by letter at every drawing; icons looked up on disk | fitted once per text and card width, kept; icons looked up once per name | `_fit_memo`, `_icon_memo` |
| Fog (game.gd `_stamp`) | each disk cell: x, y, bounds, cliff test | a disk inside the map: flat offsets, cliff test only where it matters; at the map edge: one run of cells per row | `_stamp_inside`, `_disk_rows` |
| Unit grid (game.gd `_rebuild_hash`, `units_near`, `separation`) | a dictionary keyed by Vector2i, every cell looked up | a flat list over the map (a dictionary only for units off it); cells past the edge skipped | `_grid`, `_hash_cell` |
| Separation | a neighbour list built, then walked | one pass; what the unit asks of itself worked out once | |
| Unit kind flags (unit.gd) | `is_worker`, `is_mounted`, `deploys`, `horse_working`, the faction: dictionary look-ups every call | worked out when the kind is set (setup, morph) | `_kind_flags` |
| Halls (game.gd `nearest_hall`, `halls_of`) | every building, the hall kind asked for each | a per-team list of the faction's halls, kept until a building is added or removed | `_hall_kind_of` |
| Tesla search (game.gd `in_field`, `in_overcharge`) | every unit, for every Clockwork unit, a few times a second | skipped until a Tesla Cart or Locomotive has been made (the rebuilt Clockwork has none) | `tesla_made` |
| Lists (`army`, `workers`, `horses_of`, AI `_mine`) | a filter with a function per item | a plain loop, same order | |
| Targets (`find_target`, `can_hit`) | `hostile()` for every unit and building | a small table of enemies by team; the target's `is_air()` asked once | `_foe_table` |
| Mouse hover (`entity_at`, every frame the mouse moves) | every unit measured | units more than 26 px away passed over first | |
| Path smoothing (`line_clear`) | samples in order | every 4th sample first, then the rest: a blocked line is found sooner, the same answer | |
| Brood swamp | a whole-map loop for every player every half second; the swamp layers and minimap picture looped over the whole map | skipped where nothing changed; only the swamp's own cells visited (`PackedByteArray.find`) | |
| Gear buildings' frames | the texture path put together every tick | kept by kind and number | `_work_tex` |

Tried and dropped: a scanline flood fill for the computer's siege plan (`AI._flood_from`): the
same cells, but only about 10% faster on map-like grids, not worth the change.

## Before and after, per system (computer profile)

ms of work per second of play; "late" is the average of minutes 12 to 18.

| part | before, min 6 | after, min 6 | before, min 10 | after, min 10 | before, late | after, late | change (late) |
|---|---|---|---|---|---|---|---|
| units | 130 | 114 | 259 | 226 | 286 | 239 | -17% |
| buildings | 32 | 28 | 63 | 53 | 77 | 56 | -28% |
| computer players | 32 | 25 | 61 | 48 | 70 | 52 | -26% |
| game tick | 51 | 35 | 77 | 54 | 93 | 63 | -33% |
| of which the fog | 21 | 10 | 39 | 20 | 46 | 21 | -55% |
| of which paths | 11 | 9 | 11 | 10 | 15 | 13 | -13% |
| HUD look | 13 | 13 | 19 | 18 | 21 | 20 | -7% |
| HUD drawing | 77 | 8 | 83 | 10 | 89 | 14 | -85% |
| of which the selection card | 73 | 4 | 77 | 4 | 79 | 4 | -95% |
| of which the command card | 1 | 0 | 1 | 1 | 1 | 1 | same |
| command card build | 1 | 1 | 2 | 2 | 2 | 2 | same |
| overlay drawing | 1 | 1 | 2 | 2 | 5 | 3 | -31% |

The whole match, minute by minute (computer profile):

| min | units | fps before | fps after | 1% low before | 1% low after | frames over 33 ms before | after | worst frame ms before | after | processor s before | after |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 40 | 431 | 593 | 28 | 77 | 20 | 3 | 55 | 50 | 8.3 | 6.0 |
| 4 | 80 | 237 | 338 | 26 | 58 | 31 | 1 | 60 | 35 | 15.2 | 10.5 |
| 6 | 125 | 157 | 228 | 22 | 39 | 96 | 5 | 63 | 44 | 22.9 | 15.8 |
| 8 | 164 | 136 | 180 | 19 | 35 | 143 | 5 | 68 | 82 | 26.4 | 19.9 |
| 10 | 234 | 96 | 127 | 15 | 24 | 266 | 31 | 124 | 84 | 37.2 | 28.0 |
| 12 | 207 | 86 | 113 | 14 | 21 | 296 | 41 | 185 | 174 | 41.3 | 31.6 |
| 14 | 240 | 86 | 119 | 14 | 22 | 282 | 40 | 133 | 87 | 41.4 | 30.3 |
| 16 | 239 | 85 | 123 | 15 | 27 | 296 | 34 | 85 | 52 | 41.9 | 29.3 |
| 18 | 272 | 76 | 104 | 13 | 24 | 365 | 72 | 100 | 58 | 47.2 | 34.3 |

("fps" here is how fast the bench ran with nothing holding it back, so it is higher than on a
phone; what matters is the change. "Processor s" is the processor time one game minute took.)

## The tablet profile

The same match on the phone and tablet profile (bigger interface, no mouse hover). It
plays out exactly the same (the same state file). Its selection card was dearer than on the
computer (93 ms a second before), and its HUD drawing was 106 ms a second late in the match.

| part (ms per second of play) | before, min 6 | after, min 6 | before, min 10 | after, min 10 | before, late | after, late | change (late) |
|---|---|---|---|---|---|---|---|
| units | 138 | 113 | 263 | 221 | 289 | 243 | -16% |
| buildings | 35 | 28 | 65 | 51 | 79 | 57 | -28% |
| computer players | 35 | 25 | 61 | 46 | 71 | 53 | -25% |
| game tick | 55 | 35 | 79 | 53 | 95 | 66 | -31% |
| of which the fog | 22 | 10 | 40 | 19 | 46 | 22 | -53% |
| HUD look | 12 | 11 | 16 | 14 | 17 | 17 | same |
| HUD drawing | 98 | 8 | 100 | 10 | 106 | 15 | -86% |
| of which the selection card | 93 | 4 | 93 | 4 | 95 | 5 | -95% |
| command card build | 2 | 1 | 2 | 2 | 3 | 2 | -16% |

| min | units | 1% low fps before | after | frames over 33 ms before | after | processor s before | after |
|---|---|---|---|---|---|---|---|
| 4 | 80 | 18 | 66 | 112 | 1 | 18.5 | 9.0 |
| 6 | 125 | 18 | 40 | 191 | 4 | 24.6 | 14.8 |
| 8 | 164 | 16 | 40 | 204 | 5 | 28.5 | 17.5 |
| 10 | 234 | 14 | 28 | 254 | 14 | 37.8 | 26.2 |
| 12 | 207 | 12 | 22 | 336 | 42 | 44.0 | 30.1 |
| 14 | 240 | 12 | 22 | 286 | 36 | 42.0 | 28.7 |
| 16 | 239 | 14 | 25 | 287 | 48 | 40.6 | 29.2 |
| 18 | 272 | 12 | 21 | 394 | 81 | 48.8 | 34.4 |

The owner's tablet numbers (hud/selection 45 to 110 ms a second, HUD drawing about 120)
match the "before" column: that was the selection card. The command card was already
rebuilt only 4 times a second (and at once after a touch) since an earlier pass, not 18;
building it costs 2 ms a second.

## On the current main (0.14.39)

After main was merged in (0.14.33 to 0.14.39 change how a match plays: the Clockwork
economy, the Powder Mill's yard, the guns and horses fixes), the check was done again on the
new game: main with this branch's reproducibility commit, against this branch merged with
main. The two play the same 18 minutes, state for state (2.4 MB, identical). Run side by side
at the same time on the same machine (so the two are comparable with each other, not with the
tables above), late in the match (minutes 12 to 18):

| part (ms per second of play) | main | main + this pass | change |
|---|---|---|---|
| units | 309 | 275 | -11% |
| buildings | 81 | 61 | -24% |
| computer players | 85 | 66 | -22% |
| game tick | 92 | 64 | -30% |
| of which the fog | 45 | 23 | -49% |
| HUD drawing | 86 | 15 | -83% |
| of which the selection card | 76 | 5 | -93% |
| processor seconds per game minute | 46.0 | 35.0 | -24% |
| frames over 33 ms per minute | 359 | 76 | five times fewer |
| slowest 1% of frames, fps | 14.7 | 21.5 | |

## The worst frames

Each minute's slowest frame, and what it spent its time on (computer profile, late minutes):

| min | before | after |
|---|---|---|
| 13 | 109 ms: the selection card 44, the autosave 34 | 70 ms: the autosave 36 |
| 14 | 133 ms: the selection card 70, the autosave 22, the fog 16 | 87 ms: a burst of paths 62 |
| 15 | 105 ms: the selection card 36, a computer's workers 20, the fog 21 | 63 ms: a computer's economy think 33 |
| 16 | 85 ms: the selection card 39, a computer's production 14 | 52 ms: a computer's economy think 33 |
| 17 | 84 ms: the selection card 24, the autosave 24, the fog 12 | 57 ms: paths 18, units 13 |
| 18 | 100 ms: the selection card 39, paths 31 | 58 ms: the autosave 21, units 15 |

The selection card and the fog no longer show up among the slowest frames. What is left at
the top: path bursts (in the bench up to 24 paths a tick, as its 6 ms path limit is lifted;
in a real game the limit cuts them short), a computer player's big think (30 to 90 ms once
in a while: its build-spot search or its siege plan), and the autosave (20 to 35 ms each
time it writes). The match's slowest frame overall went from 188 ms (minute 9) to 174 ms
(minute 12), both bursts of paths; minute 9's slowest frame went from 188 to 91 ms, the path
smoothing's share of it from 83 to 29 ms.

## What is left

- **Units are now about 60% of the work.** What remains is spread over a hundred small
  checks per unit per tick (about 33 microseconds a unit each tick in the native build, from 37), with no
  single big part left: moving and keeping apart, looking for targets, workers' work. Cutting
  it much further means restructuring how a unit's tick is organised (for example skipping
  whole groups of checks by unit kind), which is a bigger, riskier job than this pass.
- **The computer players' big thinks** (a siege plan that floods the whole map twice, a
  search for a building spot on a full plateau) still make single 30 to 60 ms frames a few
  times a minute.
- **The autosave** makes a 20 to 35 ms frame every time it writes.
- **Path bursts**: in a real game the 6 ms path limit keeps them shorter than in the bench;
  smoothing is now cheaper.
- **The 12 s frame** seen once in a long match was not reproduced in the bench (its worst
  frame is 174 ms, a burst of 24 paths with the bench's path limit lifted).
- Rendering (the graphics card's side, and the browser's) is not measured here: headless
  runs only see the drawing code.
