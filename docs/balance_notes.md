# Balance notes

Observations from playtests to come back to. The numbers themselves live in
`scripts/defs.gd` (and the overview sheet `docs/Holdfast_balance.xlsx`).

## To check later

- **Crown palisade walls (v0.11.18 playtest, Kestrel Rise):** Crown palisade walls are very
  strong against rushes (they basically stop them); the cost is gold not spent on economy or
  tech. Give and take, but check later whether walls need a cost/hp/build-time adjustment.
  (Now: Palisade 25 gold, 300 hp, armour 2, 8 s; Gate 50 gold, 300 hp, armour 2, 12 s.)
- **Bodies torn up by BOMBARD (v0.14.23):** only shots fired at a spot tear bodies (Defs.BODY_BLAST
  combat 0). Measured with tools/measure_body_blast.gd: in Hard Crown AI matches against the Brood ordinary
  splash would have torn 0 of 95 and 0 of 187 bodies, but in a gun line holding against Brood waves (4
  Cannons, 2 Mortars, 6 waves) 80 of 86 (whole blast), 78 of 87 (half radius), 61 of 87 (0.3 radius).
  Harvested bodies went from 1 to 1.25 essence a supply to make up for it. In AI matches the Brood computer
  harvests almost nothing (1 body in 187: its grubs only follow a striking swarm); check with human play
  whether 1.25 is enough once players shell the piles, and whether the Brood computer should harvest more.
