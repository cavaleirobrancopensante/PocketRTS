# The owner's corrections for the gear-turn job (2026-10-28 06:18), after it started

- Drift: units walking across a turning band drift by the CORRECT amount for the time they spend on it (the full tangential carry of the band, the same physics as a unit standing there), not "only a little". No special damping for walkers.
- Idle units: idle units STAY where they are and keep getting carried round. They do NOT step off by themselves. If the player wants them off a band, he must move them off with an order. (The same for the computer's units: its AI may move them off deliberately, but no automatic step-off for idle units.)
- Kept as agreed: only the outer toothed band turns, at the gear's own speed, meshed gears turn opposite ways; workers going to/from the building walk straight in without circling; units on hold get carried.
- Fold this into docs/gear_turn.md and delete this file.
