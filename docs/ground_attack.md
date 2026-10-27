# Bodies that rot, and ATTACK GROUND for everyone (0.14.41)

Branch `ground-attack`. The owner's decisions (2026-10-27): bodies are objects with health that rots away, faster the
longer they lie; Ctrl+A + click attacks the ground, Ctrl+A + a held left-drag shares a line out among the selected units
like the right-drag formation; every unit that can attack can do it, workers too (slowly); they keep at it until another
order; beefy bodies take a little longer to harvest. Tests: `tools/test_ground_attack.gd` (new, 55 checks),
`tools/test_attack_ground.gd` (updated: a Musketeer may now attack the ground), a new check in `tools/test_online.gd`.
Screenshots: `tools/shot_ground_attack.gd` writes `docs/shots/ground-attack/` (the drag preview, the stretches, the
body bars).

## The rules

**A body's health** is the health its unit had in life (`Unit.body_size`: its max health; a rider's adds his horse's, who
lies with him; a seasoned horse's veterancy health counts).

**Rot** (`Defs.ROT`): every body loses health at one base speed, 0.2696 a second, and that speed doubles every minute
since death. I chose the smooth form (base x 2^(seconds / 60)) so the bar never jumps. Lost by time t:
`base x 60 / ln 2 x (2^(t/60) - 1)` (`Unit.rot_lost`), so how long a body lasts is a closed form too (`Unit.rot_life`).
Each body keeps one tween that fires when it rots out (`Unit.rot_end`), set again only when the body is hit
(`Unit._schedule_rot`): nothing is worked out per frame, the same cost as the old fixed timer. The rot is the same in
every match, with or without the Brood. The base speed is one constant, tuned so an untouched Musketeer lasts 2:00.

**Damage** (`Game.hit_body`) takes health off and brings the rot end closer; at 0 the body is torn up
(`Game.tear_body`, as before: off the harvest and raise lists, the puff of earth). A body that rots out just fades as
before. A hurt body keeps its whole essence value until it is gone (the value could shrink with its health instead:
see the end).

**The Missionary's window** (`Defs.REVIVE` window, 60 s) is unchanged and its own rule; every soldier he can raise lasts
2:00 or more untouched.

**The bar** over a body is its health (fresh: full; it shrinks slowly, then faster; a hit takes a bite). It is a little
longer over a beefy body (12 px for a Musketeer, up to 20 px) and sits a little higher over a big one; it is slightly
more opaque than before (it was nearly invisible on light ground). `docs/shots/ground-attack/body_bars.png`: a fresh
Musketeer, one lying 90 s (25 of 70 left), a Brute hit for 170 (69 of 240).

**Harvest time** (`Game.harvest_time`): `Defs.HARVEST` take 1.2 s x sqrt(health / 70), clamped 0.8-3 s, by the body's
size (not what is left of it). The anim viewer still reads HARVEST take.

| Body | Health | Lasts untouched | Harvest |
|---|---|---|---|
| Raptor | 36 | 1:20 | 0.86 s |
| Tin Militia | 45 | 1:33 | 0.96 s |
| Labourer, grub, Winder | 46 | 1:34 | 0.97 s |
| Wind-up Soldier | 55 | 1:44 | 1.06 s |
| Horse (green), Missionary, Rail Rifleman | 60 | 1:50 | 1.11 s |
| Musketeer, Spitter | 70 | 2:00 | 1.20 s |
| Skywing | 75 | 2:04 | 1.24 s |
| Dismounted horseman | 80 | 2:08 | 1.28 s |
| Clock Soldier, Jack, Stormcaller, Mist Toad | 90 | 2:16 | 1.36 s |
| Mortar | 120 | 2:37 | 1.57 s |
| Field Cannon | 140 | 2:48 | 1.70 s |
| Dragoon with his horse | 150 | 2:53 | 1.76 s |
| Horseman / Cuirassier with his horse | 200 | 3:15 | 2.03 s |
| Brute, Tesla Cart | 240 | 3:30 | 2.22 s |
| Spore Mother | 260 | 3:36 | 2.31 s |
| Thresher | 280 | 3:42 | 2.40 s |
| Pendulum, Bulwark | 340 | 3:58 | 2.64 s |
| Steam Walker | 380 | 4:06 | 2.80 s |
| Heavy Locomotive | 600 | 4:44 | 3.00 s (clamped) |

(Measured live in the test: a Raptor's body went at 80.7 s, a Musketeer's at 119.9 s, a Brute's at 209.8 s; a grub
wrapped a Raptor in 0.83 s.)

## Who can attack the ground

`Unit.can_ground_attack`: everything with a weapon. In: Labourer, grub, Winder (workers), Musketeer, dismounted
horseman, Horseman/Cuirassier, Field Cannon, Mortar, Raptor, Spitter, Brute, Spore Mother, Mist Toad, Skywing (landed),
Clock Soldier, Wind-up Soldier, Tin Militia, Scrapper, Rail Rifleman, Jack, Pendulum, Thresher, Bulwark, Arc Thrower,
Steam Walker, Stormcaller, Tesla Cart, Ornithopter, Ticking Owl. Out: units with no attack (Missionaries, Powder Wagons,
horses, balloons, the Messenger, the mounted Dragoon, the Clockwork's cars and trains on their rails, including the armed
Heavy and Tesla Locomotives, which cannot leave the track to reach a spot), flyers that only hit flyers (Cuckoo, Skywing
in the air), the Netter (its net is for the living) and the Bloater (its close attack is bursting itself).

How each kind works the order (`Unit._bombard` for area weapons, `Unit._ground` for the rest):

- **Area weapons** (Field Cannon, Mortar, Spore Mother) as before: into range, set up, fire. A click: at the spot. A
  stretch: at the bodies in a lane half a tile each side of it while there are any, else at points spread along it.
  A blast hurts every body in it by its damage x 10 (`Defs.BODY_BLAST` body): a Mortar shell 300, round shot 320,
  canister 180, a spit blob 260. One shell still tears up most bodies at once (in the test: 4 of 5, all but a Pendulum,
  which is left with 38 of 340). Ordinary fire at enemies still leaves the bodies alone (combat share 0: nothing broke).
- **Shooters** (range 60 px and more) walk into range and fire: a click at the spot, a stretch along it, at its bodies
  first. A shot lands where it is aimed: an enemy standing there takes it as a normal hit (`Unit._strike`), otherwise the
  nearest body within half a tile, otherwise the ground (a puff of dust). Every shot spends a shot of powder. The look
  and sound are the unit's own (a musket ball, a glob of acid, a zap, a screw, a gust of steam). A Musketeer who runs dry
  fixes bayonets and goes on as a melee unit.
- **Melee units and workers** walk up to a body and strike it: on a click, the bodies within 1.5 tiles of the spot; on
  a stretch, those in a lane half a tile each side of it (1 tile wide). With none they wait at their spot and strike the
  next one that falls there.

They never stop by themselves (no bodies left, out of powder: they wait); any other order ends it. With orders
Shift-queued behind it, a unit gives the ground 3 blows or shots (`Defs.BOMBARD` queued) and goes on; a melee unit with
nothing to strike goes on at once.

Time for one unit to tear up a body untouched by rot, standing at it (blows needed x its cycle, first blow after its
aim; damage without veterancy, a Clockwork unit fully wound):

| Attacker | Kind | Damage a blow | Cycle | Musketeer body (70) | Brute body (240) |
|---|---|---|---|---|---|
| Field Cannon / Mortar / Spore Mother | area x10 | 320 / 300 / 260 | 5-6 s | 1 shot | 1 shot |
| Dismounted horseman | ranged | 30 | 1.8 s | 4 s | 13 s |
| Horseman/Cuirassier | melee | 18 | 1.6 s | 5 s | 21 s |
| Brute | melee | 26 | 2.4 s | 5 s | 22 s |
| Ticking Owl | melee | 20 | 2.0 s | 7 s | 23 s |
| Arc Thrower | ranged | 28 | 3.4 s | 8 s | 28 s |
| Pendulum | melee | 22 | 2.6 s | 9 s | 27 s |
| Jack / Tesla Cart / Steam Walker | ranged | 10-15 | 1.4-2.3 s | 9-10 s | 33-37 s |
| Musketeer | ranged | 20 | 3.6 s | 11 s | 40 s (more than his 10 shots) |
| Clock Soldier / Scrapper / Rail Rifleman | melee/ranged | 10-12 | 1.7-2.2 s | 11-12 s | 35-44 s |
| Thresher (saws not spun up) | melee | 8 | 1.6 s | 13 s | 46 s |
| Raptor / Wind-up Soldier / Tin Militia | melee | 6-7 | 1.4-1.6 s | 15-17 s | 53-59 s |
| **Labourer** | worker | 7 | 1.6 s | 15 s | 55 s |
| **Grub, Winder** | worker | 6 | 1.6 s | 18 s | 61-63 s |
| Spitter / Stormcaller | ranged | 7-8 | 1.9-2.7 s | 18-22 s | 65-79 s |
| Mist Toad | melee | 4 | 2.3 s | 39 s | 133 s |

In the test, 8 Musketeers dragged along a row of 8 Musketeer bodies tore them all in 21 s and spent 48 shots between
them; a Brute cleared two bodies in 14 s, a Labourer the same two in 31 s.

## The controls

- **Ctrl+A** (or the card button, renamed **ATTACK GROUND**; was BOMBARD) opens the mode when anything selected can attack
  the ground ("None of them can attack the ground." otherwise).
- **Click**: everyone attacks that spot (`Game.bombard_order` -> `Game.ground_order` with one point).
- **Hold the left button and drag**: the line is shared out like the right-drag formation (`Game.line_stretches`: equal
  lengths along the drawn line, units matched in order along it so their paths don't cross); each unit gets its stretch
  (`Unit.gnd_a` / `gnd_b`, the middle as its `order_point`). While dragging, the preview shows the line and each unit's
  stretch as a lane, alternating shades, with a tick between stretches and a dot at each middle
  (`docs/shots/ground-attack/drag_preview.png`); a selected unit on the order shows its lane and the target ring
  (`stretches.png`). A drag under 40 px is a click. Shift queues (and keeps the mode open while held), for a click or a
  line. Phone: a drag after the button does the same.
- The order is kept in a saved game (with its stretch) and works online.

## Online

`ground_order` is in `NetCommands.GAME` (own units only, like `bombard_order`, which now calls it). The guest works out
the rot itself (its copy of each body dies with the host's snapshot and rots from then); the host sends a body's health
only when a hit changes it (fx `"h"`: position and health left; `Game.body_health_at`), and a torn body as before (fx
`"c"`). Checked in `tools/test_online.gd` over a local relay: the guest orders its worker onto a body, the host runs it,
and the guest's copy of the body shows the hit (`guest_ground_attack_hits_body OK`); entity counts still match. The change
to the net code is three lines in the same pattern as BOMBARD's.

## The costs

Measured with `tools/measure_body_rot.gd` (it only reads `Game.bodies`, so it runs on 0.14.40 too), Hard computer
against Hard computer with no Brood in the match, one run each build per map (the matches differ, so the counts are a
spread, not a pair). "Mean" is over minute 5 to the end; ms are real milliseconds per simulated frame headless, with
four runs sharing the machine, so only the comparison means anything.

| Match | Build | Minutes | Bodies lying, mean | Most at once | Living units, mean | ms a frame, mean |
|---|---|---|---|---|---|---|
| Ashford Crossing, Crown v Clockwork | 0.14.40 (30 s) | 14 | 7.7 | 35 | 101 | 20.3 |
| | 0.14.41 (rot) | 16 | 34.3 | 89 | 104 | 20.7 |
| Frostmere, Clockwork v Crown | 0.14.40 | 21 | 10.3 | 39 | 106 | 22.6 |
| | 0.14.41 | 25 | 36.4 | 66 | 130 | 21.4 |
| Kingsfield, Clockwork v Crown | 0.14.40 | 18 | 10.9 | 32 | 115 | 25.2 |
| | 0.14.41 | 19 | 41.9 | 73 | 101 | 23.1 |

So without the Brood about four times as many bodies lie at once (35-40 on average, 65-90 at the peak of a big fight,
against 8-11 and 32-39). The frame time follows the living units, not the bodies: a lying body is a still picture that
stops processing (as before) plus one tween, and the bar is two rectangles for the bodies in view.

A lab to isolate them (`measure_body_rot.gd lab n:300`, 300 bodies in the camera's view at once, far more than any
match above): headless, the simulation cost of 300 bodies is within noise (1.06 ms a frame with them, 0.95 without on
0.14.41; 1.01 and 1.11 on 0.14.40). Drawn (xvfb, software OpenGL, so the absolute numbers are slow and noisy), 300
bodies in view add about 10-25 ms a frame in both builds alike (three runs each: 0.14.41 +8, +22, +16; 0.14.40 +23,
+13, +31): the cost is the body sprites themselves, the same per body as before; the new bar and the rot add nothing
measurable. 100 bodies in view were within the noise. The extra cost of the longer lie is therefore only the extra
bodies on screen during and after a big fight, a few tens of sprites. No faster rot for bodies nobody can use is needed
on these numbers; if a slow device shows it, the fallback is one line in `Unit.rot_end` (for example x2 the base speed
when `Game.brood_in_match()` is false and the body is not a raisable soldier).

The order itself: a melee unit or shooter on ATTACK GROUND looks for a body every 0.5 s (a pass over the lying bodies,
tens of distance checks); nothing per frame per body.

## For the owner to decide

1. **Spit blobs at the ground now hurt bodies** (x10, like shells), because denying bodies works the same for every
   faction. Before, the Spore Mother's spit was the one area shot that left bodies alone. Easy to put back.
2. **A hurt body keeps its whole essence value** until it is gone. It could shrink with its health instead (a half-eaten
   body worth half), which would make partial damage matter for the Brood's economy too.
3. **Shots at bodies always hit** (the musket's 85% applies only to enemies). A shot at an enemy standing on the line is
   a normal shot, with its usual miss.
4. **Bodies now lie about four times as long in matches without the Brood** (2:00 instead of 0:30 for a Musketeer). See
   the costs above; a faster rot for bodies nobody can use would be the fallback, one line in `Unit.rot_end`.
5. **Who is left out**: the armed trains (they can't leave the rails), the Netter, the Bloater, the mounted Dragoon. Any
   of them can be let in.
6. **The x10 against bodies** leaves a Pendulum's, Bulwark's, Steam Walker's and the trains' bodies needing a second
   blast. x12 would tear a Pendulum in one Mortar shell.
7. The computer still shells piles of bodies with idle Mortars only (`AI._shell_bodies`); it does not use the new line
   order yet.
