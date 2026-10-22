# Performance pass, v0.11.10 → v0.11.16+ (HUD, fog, AI spikes, buildings, units)

Before: v0.11.10 (commit 4cc3796) with the new bench (425b705). After: the perf commits
(52436c6 HUD, e2e5232 game/AI/buildings/units, 8d2867c fog stamps and separation), measured
before the merge with main so that main's gameplay changes don't mix in.

## What the designer's browser games showed (v0.11.6 / v0.11.11, web build, 1v1)

| part | browser (ms per second of play) | cause found |
|---|---|---|
| hud draw | 80 at min 1 → 124-190 at min 4-10 (300 in a big fight), 39-89 draws/s at 2.6-3.4 ms | the whole HUD was redrawn on every mouse-move event (up to 60/s) and at 20/s otherwise; each draw ~40 rounded StyleBoxFlat panels/buttons, ~80 texts, ~200 minimap rects, `get_mouse_position()` asked dozens of times, `army()`/`labourers()`/`producers()` lambda filters, the command card rebuilt (closures) inside the draw |
| units | ~1.3 ms per unit per second | `separation()` built a temporary list per call (and `[]` defaults per hash bucket); `_clear_at` = 5 × `passable(cell_of())` calls per moving unit and tick; the overhead-bars key worked out for units off screen; constant arrays rebuilt per call (`DIR_FLIP`, gallop kinds); `Prof.add` itself (4 dictionary ops) for every unit tick |
| game/fog | ~4 calls/s at 2-3.5 ms | the LA8 fog picture rebuilt cell by cell (W×H GDScript loop) on every update |
| game (spikes) | worst frame 267 ms in minute 7 | the AI's whole think in one frame (find_spot for a new hall ~100 ms, building, army…); bursts of path requests |
| buildings | 7 → 30 ms/s | `_update_sprite()` every tick for every building (texture path formatted, `ResourceLoader.exists` for gates, farms searching their hall: O(buildings²)); crew list re-filtered with a lambda every tick; bars redrawn 6×/s off screen |
| overlay draw | 5-15 ms/s | economy labels (efficiency() per building) redrawn every tick, also off screen |

## Fixed-state measurements (most reliable: same state, min of repeats, before/after alternated)

`tools/_visbench`-style harness (scratch, not in the repo): a Sundered Realm match, 148 units placed
(musketeers and labourers, both sides), 26 buildings; each part timed on that state, before and
after alternated four times on the same (busy) machine. Native headless; the web build is ~2-4× slower.

| part | before | after | |
|---|---|---|---|
| `_update_vis` (fog, 148 units, 192×160) | 9.1-10.1 ms | 5.2-5.7 ms | −45% |
| one second of unit ticks (148 units) | 146-161 ms | 103-112 ms | −30% |
| one second of building ticks (26) | 9.2-10.3 ms | 2.4-2.6 ms | −75% |
| `find_spot` for a new hall (far_safe) | 24-51 ms | 2.0-2.4 ms | −95% |

HUD (perf_bench with an emulated player: the mouse moving every frame, the selection changing
every 6 s), native headless, minute 2: HUD tick+draw 1.05 ms → 0.21 ms per frame; rendered
(xvfb/llvmpipe) 3.1 ms → ~0.7 ms. Draw calls: ~60/s of the whole HUD → a few small layers a second.

## Whole games (perf_bench, 14 min, hard AI both sides, headless --fixed-fps 60)

Run side by side on a shared 2-core machine with other jobs running. The parts are each
minute's **median second** ("med" columns, ms per frame); fps and worst frames are wall-clock
and move with the machine's load. The two runs reach a given game minute at different
wall-clock times, so late minutes (10, 14) were measured under different outside load and
the AI games diverge (different fights): read the early minutes and the trend, and the
fixed-state table above for the true per-part cost.

before → after; "units on map" before / after. CSVs: `v0.11.10_before_*.csv`, `v0.11.10_after_*.csv` here.

#### sundered_realm, crown vs crown

| min | units on map | fps avg | 1% low fps | worst frame ms | frames >33 ms | units | buildings | game tick | of which fog | ai | HUD (tick+draw) | overlay |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 24 / 26 | 200 → 560 | 9 → 35 | 622 → 266 | 30 → 5 | 0.57 → 0.45 | 0.24 → 0.13 | 0.39 → 0.15 | 0.32 → 0.13 | 0.10 → 0.09 | 2.04 → 0.29 | 0.07 → 0.01 |
| 6 | 73 / 70 | 111 → 243 | 6 → 17 | 677 → 188 | 93 → 27 | 1.73 → 1.35 | 0.58 → 0.38 | 0.56 → 0.54 | 0.46 → 0.30 | 0.34 → 0.24 | 3.11 → 0.54 | 0.16 → 0.01 |
| 10 | 137 / 129 | 88 → 108 | 15 → 6 | 121 → 557 | 142 → 137 | 3.08 → 3.34 | 1.08 → 0.66 | 1.10 → 1.42 | 0.85 → 0.67 | 0.65 → 0.71 | 4.12 → 1.00 | 0.33 → 0.05 |
| 14 | 152 / 136 | 152 → 130 | 27 → 19 | 62 → 86 | 26 → 98 | 1.78 → 2.74 | 0.68 → 0.75 | 0.66 → 1.14 | 0.46 → 0.77 | 0.39 → 0.85 | 2.05 → 0.96 | 0.23 → 0.00 |

#### sundered_realm, crown vs brood

| min | units on map | fps avg | 1% low fps | worst frame ms | frames >33 ms | units | buildings | game tick | of which fog | ai | HUD (tick+draw) | overlay |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 29 / 30 | 543 → 1279 | 95 → 142 | 16 → 17 | 0 → 0 | 0.32 → 0.25 | 0.12 → 0.06 | 0.18 → 0.07 | 0.15 → 0.05 | 0.03 → 0.03 | 0.67 → 0.11 | 0.05 → 0.01 |
| 6 | 104 / 109 | 133 → 486 | 26 → 80 | 61 → 22 | 25 → 0 | 2.35 → 0.94 | 0.69 → 0.17 | 0.59 → 0.22 | 0.46 → 0.15 | 0.24 → 0.10 | 3.07 → 0.27 | 0.12 → 0.01 |
| 10 | 179 / 166 | 99 → 103 | 10 → 18 | 432 → 94 | 149 → 146 | 3.33 → 5.42 | 0.52 → 0.55 | 0.54 → 1.01 | 0.37 → 0.58 | 0.28 → 0.53 | 2.37 → 0.76 | 0.14 → 0.03 |
| 14 | 69 / 206 | 140 → 129 | 14 → 14 | 182 → 215 | 51 → 106 | 1.54 → 3.45 | 0.46 → 0.27 | 0.71 → 0.98 | 0.26 → 0.39 | 0.19 → 0.35 | 2.20 → 0.54 | 0.12 → 0.01 |

#### ashford_crossing, crown vs crown

| min | units on map | fps avg | 1% low fps | worst frame ms | frames >33 ms | units | buildings | game tick | of which fog | ai | HUD (tick+draw) | overlay |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 24 / 24 | 368 → 1234 | 62 → 135 | 31 → 21 | 0 → 0 | 0.31 → 0.22 | 0.15 → 0.05 | 0.14 → 0.07 | 0.12 → 0.06 | 0.08 → 0.05 | 1.39 → 0.16 | 0.03 → 0.00 |
| 6 | 48 / 42 | 289 → 843 | 41 → 144 | 74 → 11 | 3 → 0 | 0.59 → 0.38 | 0.26 → 0.11 | 0.21 → 0.15 | 0.14 → 0.10 | 0.16 → 0.10 | 1.40 → 0.23 | 0.07 → 0.00 |
| 10 | 95 / 92 | 120 → 296 | 19 → 41 | 97 → 38 | 46 → 2 | 1.74 → 1.29 | 0.65 → 0.26 | 0.50 → 0.39 | 0.39 → 0.32 | 0.42 → 0.23 | 3.35 → 0.41 | 0.24 → 0.01 |
| 14 | 113 / 107 | 133 → 118 | 25 → 20 | 64 → 78 | 26 → 105 | 2.06 → 3.36 | 0.66 → 0.69 | 0.49 → 1.10 | 0.39 → 0.88 | 0.39 → 0.60 | 2.52 → 1.35 | 0.24 → 0.01 |

#### ashford_crossing, crown vs brood

| min | units on map | fps avg | 1% low fps | worst frame ms | frames >33 ms | units | buildings | game tick | of which fog | ai | HUD (tick+draw) | overlay |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 27 / 27 | 165 → 392 | 33 → 58 | 88 → 21 | 6 → 0 | 1.13 → 0.88 | 0.28 → 0.18 | 0.37 → 0.22 | 0.24 → 0.18 | 0.19 → 0.16 | 2.78 → 0.40 | 0.05 → 0.00 |
| 6 | 77 / 57 | 94 → 177 | 17 → 26 | 86 → 68 | 125 → 31 | 3.11 → 2.92 | 0.85 → 0.33 | 0.45 → 0.42 | 0.31 → 0.28 | 0.34 → 0.29 | 4.24 → 0.69 | 0.15 → 0.01 |

## Spikes

10-minute Sundered Realm bench, worst frames per minute: before 100-650 ms (ai/build 170 ms:
`_safe_hall_spot` → find_spot; ai/army + ai/econ in the same frame; path bursts); after ≤ 50 ms
on a quiet machine. The AI now thinks in 5 parts on consecutive ticks; find_spot scores every
open cell and places best-first; the path queue stops after 6 paths a tick once it has used 6 ms.

## Not fixed / left

- Fog stamping itself (each distinct unit spot writes a disk of ~250 cells into 3-4 grids):
  ~4-5 ms per update with 150 units. A native approach (Image.fill_rect per disk row, masks for
  the low-ground rule) would cut it a lot, but the team/side grids are read cell by cell
  elsewhere; not done.
- The AI's army stage still takes 20-45 ms on a busy late game (many cmd_move/path requests
  and wave bookkeeping), once per think; it's now alone in its tick.
- A single very long path (path smoothing over a 192-wide map) can take 20-50 ms by itself.
- Unit ticks are now mostly plain GDScript work spread over many small checks (target scans,
  orders, _move); the remaining cost scales with units.
