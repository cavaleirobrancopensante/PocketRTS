# The Brute and the Spitter (the owner's decisions of 2026-10-29)

For the Brood units shared by the old Brood and the new one (Defs.UNITS "brute" and "spitter").

## 1. The Brute is drawn 20% bigger

- `art_scale` 1.2 on the Brute (Defs.UNITS["brute"]): every strip (idle, walk, attack, charge, death, every view)
  is drawn 1.2x at run time, scaled about its feet (the anchor), so the feet stay on the ground point. The health bar
  (Unit.bar_top), the veterancy trim and skin mask (shaders on the same sprite), the stun mark and the animation
  viewer all follow `art_scale` already. No frame of the 120x67 cells touches the cell's edge (checked), so nothing is
  clipped.
- Body radius 20 -> 24 (selection ring, collision, separation). Its ground footprint (Game._clear_at: 0.6 of the
  radius) is 28.8 px wide, so it still fits a 1-tile (32 px) gap: the hole a fallen Gate leaves, a 1-tile lane between
  buildings. Its path margin is unchanged (capped at 14). Ramps (2-3 tiles) are no problem.
  tools/test_brute_siege.gd checks it: after breaking the Greenhold ramp Gate a Brute walks up the ramp and through the
  gate's hole to the high ground (3.0 s alone, 9.1 s from the back of four Brutes).
- The turning gears (scripts/gear_turn.gd) don't carry units of radius 22 or more (machines); the Brute is a creature
  and is still carried (an exception by kind).
- Melee reach counts from its edge, so it reaches 4 px further: a bigger body, a longer reach.

Picture: docs/shots/brute_spitter/size_old_vs_new.png (a Raptor, a Musketeer, the Brute, a palisade with a Gate; old
size left, new size right). Made with tools/shot_brute_size.gd (scale:1.0 shows the old size).

## 2. The Brute breaks walls: building_bonus 1.6 -> 2.5

The Brute already had the unit "building_bonus" (x damage to any building: Unit._strike). It goes from 1.6 to **2.5**,
the Field Cannon's own value: one number for "a siege weapon" across the factions (few, intuitive damage modifiers,
design principles 1). Each blow on a Gate or palisade (300 health, armour 2) does 26 x 2.5 - 2 = 63: five blows.
The owner dropped a separate Gorehorn unit; the Brute is the Brood's wall-breaker.

Timings, tools/test_brute_siege.gd (Greenhold, the Crown computer's Cottage wall at its main ramp: Cottage, Gate,
palisade; nobody defends or repairs; the attackers start at the ramp's foot and are ordered to ATTACK the Gate;
"order to fall" includes the walk up, "hitting" runs from the first blow). A Palisade piece has the same health and
armour as a Gate, so the same times hold for it.

| Attackers (cost) | x1.6 (old) | x2.0 | **x2.5 (new)** | x3.0 |
|---|---|---|---|---|
| 1 Brute (150 + 20 essence) | 22.2 s (hitting 17.0) | 17.3 (12.2) | **14.9 (9.7)** | 12.5 (7.3) |
| 4 Brutes (600 + 80) | 8.8 s (4.0) | 7.7 (3.0) | **7.2 (2.4)** | 6.2 (1.5) |

| Others, for comparison | order to fall | hitting |
|---|---|---|
| 6 Raptors (150, a Brute's price) | 20.4 s | 17.4 s (only a few fit at the Gate's face) |
| 24 Raptors (600) | 7.6 s | 4.5 s |
| 2 Clock Soldiers (140) | 43.1 s | 38.0 s |
| 9 Clock Soldiers (630) | 12.7 s | 7.9 s |
| 1 Field Cannon (210, set up at the ramp's foot, 350 px off, a spotter at the Gate) | 6.8 s | 2 shots |
| 3 Field Cannons (630) | 1.3 s | one volley |

Why 2.5 and not more:
- At 1.6 a Brute was a worse wall-breaker than its price in Raptors (22.2 s against 20.4 s): no reason to bring one.
  At 2.5 one Brute breaks the Gate a quarter faster than 6 Raptors (14.9 s against 20.4 s), and 4 Brutes at least
  as fast as 24 Raptors, with far fewer bodies in the ramp's choke and 240 health each under the musket fire.
- It stays well under the Field Cannon, which breaks the same Gate from 350 px in two shots: the Brute must walk up
  to the wall and stand under its defenders' fire to do it.
- Fairness (design principles 1 and 2): the defender's advantage (walls, gates, high ground) should fade mid-game so a
  winner can finish. The Brute is the new Brood's stage-3 unit (and the old Brood's Gorge Pit unit), so a walled Crown
  still holds the early game; the answers stay: Musketeers focus the slow Brute (56 speed, telegraphed charge),
  labourers repair, the Horseman's charge, canister. x3.0 would make 4 Brutes break a Gate in 1.5 s of hitting, less
  than a repairer can answer.
- Against the other buildings the same x2.5 counts (a Cottage, a Barracks), as before with 1.6.

Run: `godot --headless --fixed-fps 30 --script res://tools/test_brute_siege.gd -- check` (the Brood rows and the
checks), `-- faction:clockwork`, `-- faction:crown`, `-- bb:3.0` to try another value. Pictures:
docs/shots/brute_spitter/gate_brutes_hitting.png, gate_brutes_hitting2.png (4 Brutes at the Gate),
gate_broken_brutes_through.png (the Gate gone, the Brutes on the high ground, the Cottage burning).

## 3. The Spitter's range 150 -> 170

Both Broods. The acid glob is an instant hit with a drawn shot (Game.acid_shot), so its reach is the range; the
Brutal computer's kiting and the unit card read Defs.UNITS["spitter"]["range"]; its sight (8 tiles, 256 px) is
still more than its range. Against the Musketeer's 190 it is still outranged, by 20 px instead of 40
(docs/raptor_spitter_study.md had found it "walks into the line's fire before it can shoot back"). The Viper, to
come, will be shorter (about 120).

The about texts (en, pt, es) of the Brute say it batters down walls and gates.
