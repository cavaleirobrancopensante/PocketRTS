# Clockwork economy study: Tension, efficiency, neighbours (2026-10-26)

## Summary (wt-econ, 0.14.33; read this first)

**The rules built (gear mode):**
- **Tension is a full resource.** Each Mainspring stores 200 (big gear 400); winding stops when the pool holds what the
  Mainsprings store together; nothing leaks or unwinds. Small spring 2.0/s at 3 Winders, big 2.6/s at 6. Buildings may
  carry a Tension price: the **Clock Aviary costs 150 cogs + 50 Tension** (HUD `150+50`, refunds on cancel, the computer
  pays). Units and research keep their prices (Jack 25, Swift 15, Netter 50, Pendulum 75, MORPH TO OWL 50, HIGH LEAP 100,
  TICKING OWL 150).
- **Efficiency %** = crew share x drive x brass. Drive: 100% meshing with the Clocktower or a Mainspring, -10% per ring
  farther out, at least 70%; idlers are free. It multiplies cogs, Tension, training and research (not supply, turrets,
  building). Shown on the map (crew, bar, %), on the card (`Efficiency 90%: 6/6 Winders · drive 90%: 2 rings from a
  Clocktower or Mainspring`) and on the placement ghost (`LINKS 90%`, `FEEDS 1`).
- **Neighbours (THE TENSION RULE):** anything that costs Tension is made only at a building whose ring meshes with a
  Mainspring's (one hop, an idler counts): the Escapement, the Clock Aviary, and a Movement Works' Jacks, Netters and
  Pendulums. Clock Soldiers need nothing.
- **THE LEVEL RULE:** rings and idlers mesh only on the same ground level (no link across a cliff or along a ramp), in
  solve(), idler_for, the ghost and its preview, and the computer's site choice (tools/test_gear_levels.gd).
- **The clock never punishes:** the tick is not part of efficiency (a chime may only ever add).
- **Balance beyond the request:** Cog Press crews doubled (small 6, big 12 Winders; full rates unchanged), so a Winder
  adds about what a Crown Labourer adds on a Farm.

**Numbers (Greenhold, 0.14.33, section 4 re-measured):** the five scripted layouts make their first Jack at 2:48-3:29
and their first Swift at 3:48-4:19 (big gears: none, no room for the Aviary), cogs at 10:00 within -5% / +17% of the
flower layout: no layout dominates. The Clockwork computer earns 1.9x / 1.4x / 1.3x the Crown computer at 3 / 6 / 10
minutes (Crown 1,140 / 4,180 / 10,640 gold; Clockwork 2,158 / 5,999 / 13,475 cogs).

**For the owner to decide or veto (section 5):** the doubled press crews; the Mainspring's store (200/400, no leak); the
Aviary as a Tension user; Jacks only from a Works beside a Mainspring; the drive numbers; the Aviary's price; whether
big gears may lose the air on a cramped plateau; the Clockwork computer's late tier 2 (AI work, not done here).

**Tests (all pass on 0.14.33):** test_gear_econ, test_gear_levels, test_gear_ai, test_gear_graph, test_gear_mesh,
test_gear_placement, test_gear_press, test_gear_save, test_gear_swap, test_gear_unlinked, test_gear_winddown,
test_cw_tier2, test_cw_tier3, test_cw_tier3_ai, test_cw_air, test_cw_air_ai, test_cw_lab, test_ratchet_turret,
test_i18n. Screenshots: docs/shots/wt-econ/ (labels_close, card_press, card_works, card_spring, card_far, ghost_drive,
ghost_spring, ghost_level, top_bar), made by tools/shot_gear_econ.gd.

The owner (2026-10-26): "make Tension work as a resource, and also the efficiency for buildings, and also the necessity of
certain buildings to be neighbouring others: this is actually a good puzzle and differentiates builds; a study might be
required." This is that study, the rule set it recommends, and what was built from it (0.14.32, gear mode). Read with
docs/design_principles.md (fairness, anti-snowball, meaningful base building), docs/clockwork_ground_up.md and
docs/clockwork_gear_prototype.md.

How the numbers were made: `tools/gear_econ_study.gd` (headless, `--fixed-fps 30`), Greenhold seed 1, one match at a time.
`ai fac=<faction>` runs the Hard computer (Balanced, peaceful: it builds its economy and army but never attacks) against an
idle opponent and records what it EARNED (not its bank) every minute. `bo layout=<name>` plays a scripted Clockwork build
order on one base layout (below). Runs vary a few seconds from one to the next; read the times to about +-5 s.

## 1. The economy before (0.14.22, measured)

**Rules.** A Cog Press pays 15% of its full rate alone and an equal share per Winder winding it: small gear 8 cogs/s at 3
Winders, big gear 10.5/s at 6 (the big one wins from 5 Winders); 2 presses per Clocktower; a Clocktower holds 11,400 raw
brass (spent: a quarter). A Mainspring winds Tension the same way: 2.0/s at 3 Winders (0.3/s alone), with no limit to what
is stored. Tension is spent by the Jack (100 cogs + 25), the Swift (75 + 15), MORPH TO OWL (100 + 50), HIGH LEAP (150 + 100)
and TICKING OWL (150 + 150). No building cost Tension (the Clock Aviary's intended 50 was folded into its 175 cogs). The
Escapement (the only Tension user) worked only while its ring meshed with a Mainspring's.

**Per worker.** A Winder on a small press added 2.27 cogs/s (+ the trickle), a Crown Labourer on a Farm 1.19 gold/s (a 380
harvest every 40 s at 8 labourers; 0.33 powder/s at the Mill). Two presses were full with 6 Winders, two farms need 16.
A base's two economy buildings, fresh land, the workers shared evenly (income a second):

| Workers | 4 | 6 | 8 | 12 | 16 |
|---|---|---|---|---|---|
| Crown, two Farms (gold) | 6.9 | 8.9 | 10.9 | 15.0 | 19.0 |
| Clockwork, two small presses, crew 3 (before) | 11.5 | 16.0 | 16.0 | 16.0 | 16.0 |
| Clockwork, two small presses, crew 6 (0.14.23) | 6.9 | 9.2 | 11.5 | 16.0 | 16.0 (21.0 on big gears at 24) |

**The computers' economies** (Hard, peaceful, Greenhold; earned so far):

| | 3:00 | 6:00 | 10:00 | workers at 3 / 6 / 10 |
|---|---|---|---|---|
| Crown: gold (powder) | 1,140 (0) | 3,420 (72) | 8,740 (590) | 10 / 20 / 38 |
| Brood: biomass (essence) | 657 (0) | 1,908 (0) | 5,837 (63) | 9 / 20 / 39 |
| Clockwork: cogs (Tension) | 2,428 (0) | 6,462 (53) | 13,948 (533) | 9 / 18 / 18 |

The Clockwork earned about **twice the Crown** at 3 and 6 minutes (2.1x, 1.9x) and 1.6x at 10, with half the workers. The
Brood's biomass buys cheaper units (a Raptor is 25), so its column is not comparable one to one. The AI-against-AI balance
study running at the same time (wt-study, 154 games per pairing by 18:45) agrees: the Clockwork beat the Crown 113-41 and
the Brood 154-0, earning 1.77x the Crown's money in the same games.

The Clockwork computer's tier 2 never came on Greenhold: its Mainspring went up at 5:24 and it found no room round it for
the Escapement in 10 minutes (the plateau is about 22 x 18 tiles and every ring needs space). The Tension it wound (533)
was never spent.

**The scripted builds** (old rules; no Clock Soldiers: the fastest tier 2 each layout allows):

| Layout | Escapement working | First Jack | First Swift | Cogs at 3 / 6 / 10 | Tension at 3 / 6 / 10 |
|---|---|---|---|---|---|
| flower | 1:47 | 2:13 | 3:07 | 2,462 / 5,336 / 9,150 | 176 / 536 / 1,016 |
| split | 1:45 | 2:11 | 2:57 | 2,514 / 5,343 / 9,128 | 181 / 535 / 999 |
| big gears | 2:20 | 2:45 | 3:28 | 2,788 / 6,548 / 11,439 | 145 / 492 / 927 |
| twin springs | 1:44 | 2:09 | 2:56 | 2,503 / 5,382 / 9,178 | 304 / 998 / 1,870 |
| chain | (no room for the Escapement) | - | - | 2,507 / 5,386 / 9,226 | 171 / 531 / 1,011 |

Under the old rules the layout hardly mattered: anything linked worked at full speed, so only the walk to the crate and
the room on the plateau told layouts apart, and the twin layout banked 1,230 Tension it never needed.

## 2. The options

### (a) Tension as a full resource

- **Storage.** Options: no limit (as before: Tension piles up, a late bank is a win button, design principle 2); one global
  cap; a store per Mainspring; a slow leak (unwinding). Chosen: **each Mainspring stores 200 Tension (big gear 400); winding
  stops when the pool holds what the Mainsprings store together; nothing leaks.** A store per spring makes a second spring
  worth something besides its rate (more room in the bank for an Owl research and a few morphs), it is visible (the top
  bar reads `120/200 tension`, a full spring stands still and its card says FULL), and it never punishes: a refund may go
  over the store, losing a spring loses no Tension already wound. A leak was rejected: it punishes saving up for the
  expensive research (150) and the owner's rule is that the clock must never punish.
- **Gear size.** The Mainspring follows the press: small gear 2.0/s with 3 Winders, big gear 2.6/s with 6 (the big one
  wins from 5) and the bigger store (400). Its ring is bigger too, so more buildings can mesh with it.
- **Prices.** Units (Jack 25, Swift 15, MORPH TO OWL 50) and research (HIGH LEAP 100, TICKING OWL 150) as before.
  Buildings may now cost Tension (a `tension` key in Defs.BUILDINGS): the HUD shows `150+50` on the build button and
  `150 cogs + 50 tension` in the tooltip, the build card says "Not enough Tension", placing pays it, cancelling a site
  gives all of it back and a begun building three quarters (like cogs), the computer pays it. **The Clock Aviary is back
  to 150 cogs + 50 Tension.** The Escapement stays cogs only (150): it already needs a Mainspring beside it to work, so a
  Tension price would gate tier 2 twice; the Mainspring, the Works, the Regulator and the Ratchet Turret stay cogs only
  (a turret that needed Tension would leave the Clockwork without a defence against an early rush).

### (b) Building efficiency as a %

What could change it, and the verdict:

| Candidate | Verdict | Why |
|---|---|---|
| Gear size against crew | **kept** (press, Mainspring) | It is the owner's rule; the crew share is the press's and spring's efficiency |
| Rings (hops) from the Clocktower | **kept, as DRIVE** | Gives the Clocktower's ring a value, makes long chains a real trade-off |
| Idlers | rejected | Exact ring contact is fiddly with a finger; an idler is part of the mesh, not a loss |
| Hops from a Mainspring | kept as the one-hop *rule* | A Tension spender meshes with a spring or not: easy to read |
| A helper building (a Regulator's beat) | rejected | Pure adjacency maths (principle 3): a Regulator beside every Works, always, no choice |
| A Mainspring as a driver | **kept** | One sentence; makes the spring a hub as well as a bank; lets a far district work at 100% |
| Crowding | rejected | The rings already limit how many buildings fit round one ring; a number on top is maths |
| The tick (working on the Clocktower's beat) | rejected for the % | The owner's rule: the rhythm may give benefits but must never punish; a % that dips when a beat is missed would punish. A later chime bonus may only add on top |

**DRIVE.** The Clocktower and every Mainspring drive the field. A building whose ring meshes with one of them works at
100%; each ring farther from the nearest driver loses 10% (90%, 80%, 70% from the 4th ring on). An idler is free. A
Mainspring counts the other drivers only.

**What it multiplies.** A Cog Press's cogs and a Mainspring's Tension (on top of their crew share), training speed (the
Movement Works, the Clock Aviary) and research speed. Not: supply (the Regulator), the Ratchet Turret's fire, building or
repairing (a Regulator loses nothing itself, so a Regulator chain is the cheap way to reach far; what hangs beyond it pays).

**Efficiency %** = crew share x drive x brass (a press on spent brass: a quarter); 0 while it stands idle (unlinked,
swapping, needing a Mainspring). The player reads it:
- **on the map**: over every working Clockwork building the label that farms and pits already have: crew (`3/6`), a bar and
  the %. Supply, the turret and the Clocktower show none;
- **on its card**: `Efficiency 80%: 6/6 Winders · drive 80%: 3 rings from a Clocktower or Mainspring` (plus `brass spent`,
  `Tension full`, `idle`);
- **before it is placed**: the placement ghost's verdict carries the % it would have there (`LINKS 90%`, `MESHES MAINSPRING
  100%`), and a Mainspring's ghost says how many buildings that spend Tension it would feed (`FEEDS 2`).

### (c) Neighbours: which buildings must mesh with which

- **THE TENSION RULE, extended: anything that costs Tension is made only at a building whose ring meshes with a Mainspring's**
  (one hop; an idler between them counts). The Escapement (as before) and now the **Clock Aviary** stand idle without one
  (NEEDS MAINSPRING: everything the Aviary makes costs Tension). A **Movement Works makes Jacks only so**; its Clock
  Soldiers need nothing. This is the necessity the owner asked for: one sentence, three buildings, and it decides layouts:
  a Mainspring's ring has room for four or five neighbours on a cramped plateau, and the Works, the Escapement and the
  Aviary all want one.
- **Kept:** the Clock Aviary can be placed only while an Escapement works.
- **Considered and rejected:** the Aviary must mesh with the Escapement (too tight with the spring rule: a triangle that
  rarely fits); a Cog Press must mesh with the Clocktower (drive already rewards it, a rule would remove a choice); a Works
  must mesh with a Regulator (supply is global; the beat would be a free bonus).
- **The good-neighbour bonus** is the Mainspring as a driver: a building beside a spring works at 100% wherever the spring
  is.
- **Tier 3 follows the same rule** (the Pendulum and the Netter came in from main while this was built): both cost Tension
  (75 and 50), so a Works makes them only while a Mainspring meshes with it, like the Jack; the Pendulum also needs the
  Works on its big gear. A big ring reaches farther, so the big-gear Works finds a Mainspring more easily: the same
  puzzle, one size up.
- **THE LEVEL RULE (owner, 2026-10-26, a bug report: "currently you can link a gear down from the high ground to low
  ground, this should not be possible").** Gear rings mesh only on the same ground level. A building's level is its
  footprint's height (a ramp is low ground, and no building stands on a ramp or a cliff, so a footprint is on one level);
  two rings of buildings on different levels never link, however close: not across a cliff, and not along a ramp (its top
  and its foot are two levels: a flat gear cannot follow a slope). Where two rings on one level meet, the ground is on that
  level too: the contact point of a direct mesh, or the idler between a gap (of its two possible spots the one on the level
  is taken), so no idler ever sits across a cliff, even between two plateaus. It belongs with the neighbour rules: a
  plateau's field ends at its cliff, the low ground below is another place that needs its own Clocktower, and the plateau's
  room becomes the scarce thing it should be (the econ test's own chain had hung its Mainspring on the low ground below
  the cliff; in the computer's air test on Ashford Crossing the Aviary found no room by the test's hand-placed Mainspring
  any more, until that Mainspring was placed as the computer places its own, keeping room round it).

## 3. The recommendation (built in 0.14.32)

1. Tension: each Mainspring stores 200 (big 400), winding stops at the store; small spring 2.0/s at 3 Winders, big 2.6/s at
   6; the Clock Aviary costs 150 cogs + 50 Tension; buildings may carry a Tension price (HUD, refunds, computer).
2. Efficiency: crew x drive x brass, one % per building, on the map, the card and the ghost. Drive: 100% meshing with a
   Clocktower or Mainspring, -10% per ring farther out, at least 70%.
3. Neighbours: anything that costs Tension is made only where a Mainspring meshes (Escapement, Clock Aviary, a Works' Jacks,
   Netters and Pendulums), and gear rings mesh only on the same ground level (no link and no idler across a cliff or a ramp).
4. Balance: the Cog Press's crews doubled (small gear 6 Winders, big gear 12; full rates unchanged), so a Winder adds 1.13
   cogs/s on a small press (0.74 on a big one), about what a Labourer adds on a Farm (1.19 gold/s). A base's top income is
   unchanged (16 cogs/s from two small presses, 21 from two big ones); reaching it takes 12 Winders instead of 6.

## 4. Simulation with the new rules

The same scripted build order (Winders all the time up to the crews plus a builder; a second press, a Movement Works, a
Mainspring, an Escapement, a Clock Aviary; Regulators when supply runs short; then Jacks and Swifts as fast as cogs and
Tension allow; no Clock Soldiers) on five layouts, Greenhold seed 1. Under the new rules the bot obeys the Tension rule like
a player: when its Works may not make Jacks it builds a second Works beside a Mainspring (or, with no room there, a
Mainspring beside the Works), and when no Mainspring has room for the Aviary it builds a second Mainspring first.

| Layout | Escapement working | First Jack | First Swift | What the rules added | Cogs at 3 / 6 / 10 | Tension at 3 / 6 / 10 | Winders at 10 | Jacks / Swifts at 10 | Plateau full |
|---|---|---|---|---|---|---|---|---|---|
| flower | 2:09 | 2:41 | 4:02 | - | 2,127 / 4,985 / 8,804 | 105 / 465 / 945 | 16 | 17 / 18 | not by 10:00 |
| twin springs | 2:08 | 2:39 | 3:50 | (a second Mainspring, planned) | 2,087 / 4,956 / 8,775 | 145 / 793 / 1,035 | 19 | 15 / 14 | 8:16 |
| chain | 2:14 | 2:40 | 3:56 | a second Mainspring for the Aviary | 2,007 / 4,737 / 8,369 | 105 / 738 / 1,025 | 19 | 14 / 15 | 8:29 |
| split | 2:05 | 3:14 | 3:41 | a second Works by the Mainspring (2:49), a second Mainspring for the Aviary | 2,133 / 5,012 / 8,852 | 108 / 789 / 855 | 19 | 12 / 7 | 5:40 |
| big gears | 2:49 | 3:56 | 3:59 | a Mainspring by the Works (3:31) | 1,693 / 4,437 / 9,430 | 69 / 745 / 905 | 34 | 6 / 7 | 6:11 |

("Plateau full": the first time the bot found no room for a Regulator; from then on its army stops at the supply cap.
A player would take an expansion then, so the army counts at 10 minutes mostly measure room.)

**No layout dominates.** Each one wins something and pays for it:
- **flower** (everything round the Clocktower, one Mainspring for everything): the biggest army by 10:00 (35 units) and
  the only one with room left, but the latest Swift (4:02): its one Mainspring winds for the Jacks and the Aviary, and its
  store (200) is spent as fast as it fills.
- **twin springs**: the fastest planned Swift (3:50) and the most Tension, for 3 more Winders and a building's room; full
  at 8:16.
- **chain** (strung outward): the one layout that pays drive (its second press and its first Mainspring work at 90%): 5%
  fewer cogs by 10:00 than the flower, for reach: the Mainspring drives its own district at 100% wherever it stands, so
  the Escapement and the Aviary lose nothing three and four rings from the Clocktower.
- **split** (the Works in front, the Mainspring behind, not meshing: a base built without the rule in mind): the Tension
  rule asks for a second Works (150 cogs) before the first Jack (3:14, 33 s after the flower) and a second Mainspring for
  the Aviary; it is full first (5:40) and has the smallest small-gear army at 10:00 (19 units). Under the old rules it was
  as fast as the flower: now planning pays.
- **big gears**: the most cogs by 10:00 (9,430, +7% on the flower) but the slowest tier 2 (Escapement 2:49, first Jack
  3:56), and its 34 Winders eat the supply an army would use (13 units at 10:00). Under the old rules big gears gave +25%
  cogs at 10 minutes for 30 s of tier 2, the one dominant choice; with twelve-Winder crews the big press is economy
  before army.

The spread: cogs at 10:00 within -5% / +7% of the flower, the first Jack from 2:39 to 3:56, the first Swift from 3:41 to
4:02. Against the old rules every layout's tier 2 comes 25-30 s later (the doubled crews take more Winders, at 50 cogs
each, before the presses pay in full; the Aviary costs 50 Tension) and the cogs earned are 14% lower at 3 minutes
(2,127 against 2,462 for the flower) and 4% lower at 10.

### Re-measured on 0.14.33 (the level rule, main 0.14.31-0.14.33 merged)

The table above was made before THE LEVEL RULE: rings then still reached across the plateau's cliff, so there was more
room. Measured again on 0.14.33 (same seed, same order). The scripted bot learned three things a player does: a Regulator
goes on the far side of the Clocktower from the Works while the Works still waits for its Mainspring and Aviary (the old
bot put one where the Mainspring had to go); an Escapement or an Aviary with no room by its layout's Mainspring goes by
any Mainspring with room (`GearEcon.room_spot`, as the computer looks), else a spare Mainspring is built for it; while a
building has no spot the Works keeps making Jacks (the old bot waited, and the split and big runs stood still).

| Layout | Escapement working | First Jack | First Swift | What the rules added | Cogs at 3 / 6 / 10 | Tension at 3 / 6 / 10 | Winders at 10 | Jacks / Swifts at 10 | Plateau full |
|---|---|---|---|---|---|---|---|---|---|
| flower | 2:06 | 2:50 | 4:04 | - | 2,170 / 5,044 / 8,861 | 86 / 443 / 886 | 16 | 17 / 17 | not by 10:00 |
| twin springs | 2:04 | 2:48 | 3:59 | (a second Mainspring, planned) | 2,164 / 5,038 / 8,831 | 108 / 772 / 1,035 | 19 | 15 / 14 | 8:26 |
| chain | 2:15 | 2:50 | 4:19 | a second Mainspring for the Aviary (3:34) | 2,060 / 4,796 / 8,426 | 84 / 686 / 1,155 | 19 | 17 / 16 | not by 10:00 |
| split | 2:07 | 3:15 | 3:48 | a Mainspring by the first Works (2:48; no room for a second Works by the first Mainspring) | 2,158 / 5,026 / 8,813 | 103 / 765 / 1,120 | 19 | 16 / 18 | 9:35 |
| big gears | 2:28 | 3:29 | **none** | - (no room left for the Aviary nor a spare Mainspring at 4:50) | 1,795 / 5,344 / 10,384 | 24 / 217 / 746 | 34 | 13 / 0 | (no Aviary room at 4:50) |

Still no dominant layout: cogs at 10:00 from -5% (chain) to +17% (big gears) of the flower; the first Jack from 2:48 to
3:29, the first Swift from 3:48 to 4:19. **Big gears now pay for their cogs with the air:** on Greenhold's main plateau their
big rings leave no room for a Clock Aviary by a Mainspring, so a big-gear base flies only from an expansion. The split
base is no longer last to fly: its fix (a Mainspring by the Works) leaves the first Mainspring free for the Aviary.

**The computers on 0.14.33** (main changed the Crown's opening since: it earns more now):

| | 3:00 | 6:00 | 10:00 | workers at 3 / 6 / 10 | army value at 3 / 6 / 10 |
|---|---|---|---|---|---|
| Crown: gold (powder) | 1,140 (0) | 4,180 (70) | 10,640 (440) | 13 / 24 / 40 | 115 / 520 / 2,285 |
| Brood: biomass (essence) | 658 (0) | 1,917 (0) | 5,848 (57) | 9 / 20 / 40 | 75 / 300 / 600 |
| Clockwork: cogs (Tension) | 2,158 (0) | 5,999 (0) | 13,475 (468) | 14 / 30 / 30 | 350 / 2,100 / 6,620 |

The Clockwork computer earns 1.9x / 1.4x / 1.3x the Crown computer (it was 1.9x / 1.8x / 1.55x on 0.14.23): the gap is
mostly its opening now. Its tier 2 is late: Mainspring 5:58, Escapement 7:02, a Pendulum at 8:03, but **no Jack and no
Clock Aviary by 10:00** (it keeps its Tension for Pendulums, and its plateau has no room by a Mainspring for the
Aviary). That is the computer's planning, not the rules (the scripted bot makes its first Jack before 3:30 on every
layout); see point 10 below.

### The computers with the new rules

The Clockwork computer now gets its tier 2 on Greenhold (it never did before: no room by its Mainspring): Mainspring
5:47, Escapement 6:33, first Jack 7:15. It places a Mainspring where a Works (or a hall) with room for the Escapement and
the Aviary meshes, a Works for Jacks beside a Mainspring, the Aviary beside a Mainspring or else a spare one
(`GearEcon.room_spot`, `AI._spring_spot`, `AI._drive_spot`). Its first Mainspring still comes at its expansion: by 5:47
its main plateau is full of Works and Regulators.

| | 3:00 | 6:00 | 10:00 | workers at 3 / 6 / 10 | army value at 3 / 6 / 10 |
|---|---|---|---|---|---|
| Crown: gold (powder) | 1,140 (0) | 3,420 (72) | 8,740 (590) | 10 / 20 / 38 | 230 / 520 / 1,895 |
| Brood: biomass (essence) | 657 (0) | 1,908 (0) | 5,837 (63) | 9 / 20 / 39 | 75 / 300 / 565 |
| Clockwork 0.14.22: cogs (Tension) | 2,428 (0) | 6,462 (53) | 13,948 (533) | 9 / 18 / 18 | 630 / 2,730 / 7,560 |
| **Clockwork 0.14.23**: cogs (Tension) | 2,158 (0) | 6,030 (11) | 13,551 (450) | 14 / 30 / 30 | 350 / 2,030 / 6,510 |

The Clockwork computer's income is 11% lower at 3 minutes and 3% lower at 10 and its army a quarter smaller at 6, but it
**still earns 1.9x / 1.8x / 1.55x what the Crown computer earns**. Per worker the two factions now match; what is left
is the openings: the Clockwork computer runs two presses at 13-16 cogs/s from about 2:00, while the Crown computer lives
on one Farm (a 380-gold harvest a minute, 6.3 gold/s) until 3:00 with 10 workers. Whether that still wins games is for
the AI-against-AI study to measure on 0.14.23 (see point 9 below).

## 5. For the owner to decide (or veto)

1. **The press crews doubled** (small 3 -> 6, big 6 -> 12, full rates kept). It is a balance change beyond the request,
   made because the study found the Clockwork earning about twice the Crown per worker. One line in `Defs.GEAR.press`
   puts it back. A softer option: 5 and 10.
2. **The Mainspring's store** (200 small, 400 big; winding stops there; nothing unwinds). Alternatives: no limit, one
   global cap, or a slow leak above the store.
3. **The Clock Aviary as a Tension user** (it stands idle unless a Mainspring meshes with it). On a cramped plateau the
   Aviary often wants a second Mainspring (140 cogs, 3 Winders). Alternative: the Aviary needs no Mainspring and only its
   Tension prices remain.
4. **A Movement Works makes Jacks only beside a Mainspring.** The strongest new constraint: a Works placed early without
   room for a spring beside it cannot make Jacks; a second Works by the spring (150 cogs) is the way out. Alternative:
   Tension is spendable anywhere and only the Escapement and the Aviary need the mesh.
5. **Drive numbers**: -10% a ring, at least 70%, the Mainspring as a second driver, idlers free. Alternatives: -5% a ring,
   or no Mainspring driver (then a far district always loses).
6. **The Clock Aviary's price** (150 cogs + 50 Tension; it was 175 cogs) and **the Escapement without a Tension price**
   (it could cost 50 Tension, which would make the first Mainspring's first job clear).
7. **Gear size for buildings without a crew** (the Works, the Escapement, the Aviary): only the ring changes (a bigger ring
   reaches farther and has room for more neighbours). Not built: "big gear = 85% work speed" (the owner's "big turns
   slow"), because the Pendulum's rule (the Works on its big gear) is being built in parallel and the two should be
   decided together.
8. **Tier 3** (the Pendulum, the Netter): if they cost Tension they follow the Tension rule by themselves (made only at a
   Works meshing with a Mainspring). Decide whether they should.
9. **The computers' gap.** Per worker the Clockwork and the Crown now match, but the Clockwork computer still earns 1.9x
   / 1.8x / 1.55x the Crown computer at 3 / 6 / 10 minutes (section 4), mostly because the Crown computer opens on one
   Farm. Not changed here. If the AI-against-AI study on 0.14.23 still has the Clockwork winning too often, the levers
   are an earlier second Farm for the Crown computer, or on the Clockwork side the small press's full rate (8 -> 7
   cogs/s) or the Winder's price (50).
10. **The Clockwork computer's tier 2** comes late and makes no Jack or Swift by 10:00 on Greenhold (0.14.33). Not
    changed here (AI planning, not economy): its first Mainspring waits for the expansion; an earlier Mainspring by its
    first Works (as `AI._spring_spot` already picks) and a Jack before saving for Pendulums would fix it.
11. **Big gears and the air.** With the level rule a big-gear base on Greenhold's plateau has no room for the Aviary by a
    Mainspring (section 4, re-measured). A trade-off, or too harsh? A softer option: the Aviary's Tension rule reaches two
    rings (a Mainspring meshing with a building meshing with the Aviary).
