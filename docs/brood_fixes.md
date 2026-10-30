# Brood fixes (0.22.1, branch brood-fixes)

The owner's answers of 2026-10-30 07:15 (docs/brood_ai.md), and his notes on the Mother's size (07:38, 07:43).

## 1. The Mother couldn't hit a gate on a ramp

In the coached Mother-rush games (tools/play_brood_3.gd, g12, g13 and g16 against the Crown's ramp wall; picture
docs/shots/brood_play_3/g13_mother_stuck_at_the_gate.png) the uprooted Brood Mother stood at the ramp's foot below the
gate and never struck it.

### What was wrong: two bugs

1. **She never chased anything (the main cause).** `Unit._engage` treats a set-up gun as something that does not
   chase: a target out of its reach is dropped (`target = null`). In 0.16.0 the Brood Mother was put under the same
   rule, so that the computer's Mother would stay on her leash at home (`BroodNew.mother_guard`). The rule applied to
   every Mother, though, including the player's on an ATTACK order. Sent to ATTACK the gate from 454 px away, she
   dropped the target at once and stood still (0 px walked in 40 s). On ATTACK-MOVE she walked to the wall, picked
   the Cottage behind it as her target (a wall or gate counts as 400 px farther, so the swarm goes for the base),
   found it out of her reach, dropped it, picked it again, and so on, pressed against the gate and never striking.
   The Tyrant Sire, the Venom Sire, the Mound Turtle, the Rootmaw, the Brute and the Tyrant Challenger had no such
   rule and all struck the gate.
2. **She stuck at the top or foot of a ramp (found on the way).** A ramp's side lane has its middle 16 px from the
   ramp's rail (the kerb), and paths often run along a side lane. The ground a unit walks with is 0.6 of its radius
   each side (`Game._clear_at`, `Game.rail_fix`): the Mother's 24 px (radius 40, 48 px across) could not stand on a
   side lane. Walking from her start down Greenhold's main ramp, she reached the ramp's top at (528, 640) and stood
   there for good, pushed back by the rail at every step. This was already true at stage 1, before any growth. The
   Tyrant Sire (radius 30, 18 px each side) was just over the limit too.

### The fix

- `BroodNew.mother_chases(q)`: the uprooted Mother chases what the player sends her at, on ATTACK (that target) and
  ATTACK-MOVE. On her own (idle, HOLD) she still stands her ground, and the computer's Mother never chases: the first
  call of `mother_guard` marks her (`nb["leash"]`), so the computer's play is unchanged.
- `Unit.ground_r()`: the big Brood creatures that root (the Mother, the Sires, the Mound Turtle) walk the ground with
  a body of at most `BroodNew.GROUND_R` = 24 (14.4 px each side, 29 px across), which fits any lane of the narrowest
  ramp. It is used wherever a unit is kept on walkable ground (`resolve_terrain`, `_clear_at`, the ramp rails, a push,
  a knock-back, the Brood's walk-out through its own rooted creatures, the turning gear rings). Units still keep
  apart by their radius (separation), so the Mother still shoves her grubs aside as before.

## 2. Her size at each stage

Her picture grows with her stage (Defs.NB "stages" scale 1.0 / 1.15 / 1.3). Before, her radius grew with it
(40 / 46 / 52), so her ground footprint would have been 48 / 55 / 62 px across. Now:

| Stage | Drawn radius (`BroodNew.drawn_r`) | Body radius (`Unit.radius`, at most `BODY_R` = 40) | Ground footprint (`ground_r`) |
|---|---|---|---|
| 1 | 40 | 40 | 24: 29 px across |
| 2 | 46 | 40 | 24: 29 px across |
| 3 | 52 | 40 | 24: 29 px across |

The narrowest ramp is 2 tiles (64 px; a few middle hills: Greenhold, Dune Sea, Kestrel Rise, Twin Crowns,
Kingsfield); the others are 3 tiles (96 px). A side lane's middle is 16 px from the rail; her 14.4 px leaves 1.6 px,
and on a 3-wide ramp's middle lane 33.6 px each side.

Her bigger picture keeps its size where it is seen and felt:
- **Reach:** she strikes from her drawn edge (`Unit._range` adds drawn_r - radius: 0 / 6 / 12 px to her 50).
- **Being reached:** her `rect()` (what others measure their reach to) is her drawn size.
- **Clicking:** a click anywhere on her picture picks her (`BroodRoot.body_hit`, unchanged: it never used the radius).
- **Looks:** her shadow, selection ring, status bar and the spot her eggs drop go by her drawn size (`BroodNew.look_r`).

## 3. The sacrifice egg exploit

Each creature offered up at the Mother gave her one egg. The young hatch two to an egg (three with Bigger Clutch), so
sacrificing both young of one egg gave two eggs back for one laid.

Now the eggs it gives back are **by the egg**. Each creature gives its share of an egg:
- 1/n, where n is how many hatched from its egg. `BroodNew._hatch` marks each young (`Unit.clutch_n`, saved as "yo").
- So: a Raptor or Spitter of a plain egg gives 1/2, of a Bigger Clutch egg 1/3, and a Hatchling the same.
- A creature that hatches alone (a Brute, a Mist Toad) gives a whole egg.
- A matured Challenger keeps the share of the young it was.
- A creature with no mark (an older save, a test) goes by its kind's Defs "spawn".

The shares are kept on the Mother as whole parts of 12 (`nb["eggp"]`, `BroodNew.EGG_PARTS`, `egg_share`):
deterministic, saved, and replay-safe. She gets the egg at once when they make 12. With her clutch full that egg is
lost, as before. Spoils are unchanged: each creature pays `Game.sacrifice_value` (35% of its share of the egg's price).

The SACRIFICE tooltip, the codex's spoils line, docs/brood_new.md and the patch notes say so (en, pt, es).

### For the brood-eco job (scripts/ai_brood_new.gd was not edited)

What the computer assumes, and whether it still holds:
- `_nb_essence` offers up spare home Raptors only to get SPOILS (while spoils are short of what it wants now,
  one every 4 s, keeping a home guard). It never counted on the egg back: unchanged, it still works. The egg back is now
  half as big per Raptor (one egg per two Raptors), so its laying gets a little less from sacrifices than before.
- `_nb_lay` reads `q.nb["eggs"]`: still the whole eggs she holds. The parts (`nb["eggp"]`) are separate.
- `mother_guard` now marks its Mother `nb["leash"] = 1`, so she never chases. If the computer ever sends its Mother on
  a rush (ATTACK, ATTACK-MOVE), clear that mark first, or she will drop targets out of her reach as before.
- Line 1113 places a spot at `q.radius + 110` below her: her radius stays 40 at every stage now (was 46 / 52), so
  that spot is 6 / 12 px nearer her at stages 2 and 3. Use `BroodNew.drawn_r(q)` if her drawn size matters there.

## Tests

- tools/test_sire_reach.gd: the uprooted Mother at stages 1, 2 and 3 ATTACKs and ATTACK-MOVEs past the Crown
  computer's ramp gate on Greenhold and strikes it. Before: stage 1 failed both (ATTACK: 0 px walked; ATTACK-MOVE:
  pressed into the gate, no target). The Sires, the Turtle, the Rootmaw, the Brute and the Challenger still pass.
  `-- shots <dir>` under xvfb-run saves the pictures below.
- tools/test_mother_ramps.gd (new): on all 27 built-in maps, at stages 1, 2 and 3, a Mother at every ramp at once
  (2 and 3 wide) walks up and down it, never crossing a rail. Then at stage 3 she walks from one start to the other,
  crossing the chokes, fords and bridges between: all arrive (Greenhold's 3,721 px in 184 s; Sundered Realm's
  9,956 px in 493 s). Before the ground fix she stuck at the top of Greenhold's main ramp.
- tools/test_brood_new.gd, part 11: two Raptors of one egg give one egg and twice the spoils (half an egg kept after the
  first); three of a Bigger Clutch give one egg, after the third; an egg of three hatches three young marked as such; a
  Brute gives a whole egg; with her clutch full the egg is lost and the spoils are paid.

## Pictures (docs/shots/brood_fixes/)

- mother_stage<N>_attack_gate.png: the Mother at stage N striking the Crown's ramp gate on her ATTACK order.
- mother_stage<N>_attack_move_gate.png: the same on ATTACK-MOVE past the gate (she goes for the gate or the wall piece
  beside it).
