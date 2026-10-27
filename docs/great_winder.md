# The Great Winder

The owner's unit, decided on 2026-10-26 and 2026-10-27. Built on branch `great-winder`, version 0.14.81.
The owner's scope: "the unit now, reassembly later".
Code: `scripts/great_winder.gd`. Numbers: `Defs.GREAT_WINDER` and `Defs.UNITS["great_winder"]`.
Art: `tools/import_great_winder.py`, on top of `tools/great_winder_guide/anim.py`.
Test: `tools/test_great_winder.gd`. Pictures: `tools/shot_great_winder.gd`, written to `docs/shots/great_winder/`.

## What it does

The Great Winder is the Clockwork's big winding machine. It walks on four legs.
It is slow. It has no weapon.
It does the job the Winders do when they walk with the army. It does it as one machine, and better.

It has three jobs.

First, winding. Clockwork soldiers run down off the gear ground.
Every Clockwork soldier near the Great Winder is wound up a little, all the time.
Near it, an army does not run down. A run-down soldier near it wakes up again.

Second, mending. It mends hurt Clockwork units with its key arm. One at a time.
It is faster than a Winder. It costs cogs, like a repair.

Third, sweeping. It sweeps up the wrecks of its own side's Clockwork units with its rollers.
It keeps them as parts. Parts do nothing yet. They are for reassembly, a later job.

It never runs down itself. It is the winding machine.

## Where it is made

At the Movement Works, once an Escapement works. Like the Netter and the Spring Ballista.
It costs Tension, so the Works must mesh with a Mainspring, as for every Tension unit.
It is a tier 2 machine of the Escapement family.

## Its numbers, and why

These are guesses, as design principle 1 says. They are written down to be tuned.

- Cost: 175 cogs and 75 Tension. Supply 4. Build time 35 seconds.
- Health 420, armour 3. Tagged armoured and massive. A Mist Toad's tongue cannot pull it.
- Speed 27.
- No weapon.
- Winding area: 200 game pixels round it, about 6 tiles. It winds 0.06 a second.
- Mending: one unit at a time, from 30 pixels off its edge. 1.5 times a Winder's repair speed.
  It also winds the mended unit 0.3 a second.
- Mending looks 7 tiles round it. Sweeping looks 8 tiles round it.
- Sweeping a wreck takes 2 seconds.
- Parts: a wreck's price divided by 10, less as the wreck rots. At least 1. Up to 100 in the hopper.

Why the speed is 27.
The painted walk moves the machine 16 pixels a loop of 12 frames. That is in `docs/great_winder_legs.md`.
At 27 pixels a second the loop plays at 20 frames a second, and the feet do not slide.
The game plays its walk on a 30 Hz tick, as it does for the Labourer, so all 20 frames show.
A faster machine would need a faster walk loop, and it would scuttle. A slower one would never keep up.
It is still slow. A Ballista goes 34, a Pendulum 46, a Clock Soldier 68.
So it falls behind on a march, and catches up when the army stops. That is its cost.

Why the winding rate is 0.06.
Off the gear ground a soldier runs down at 0.012 a second. That is about 80 seconds from full.
At 0.06, five times that, a soldier inside the ring gains 0.048 a second.
A run-down statue there is awake at once, and full in about 20 seconds.
The gear field itself winds at 0.3 a second. The Great Winder is a fifth of that: a field you carry, but a weak one.

Why the area is 200 pixels.
The escort Winders work in about 420 pixels round the army's middle, walking to each soldier.
The Great Winder's ring covers an army that stands close behind or round it, without walking.
An army spread wide, or one that runs ahead, leaves the ring. That is the counter: draw the army away from it.

Why mending is 1.5 times a Winder.
A Winder mends at 20 health a second, or faster on units that are quick to build.
The Great Winder mends 30 a second on one unit. Three escort Winders mend 60, on three units.
So it mends less in all than the three Winders it replaces. But it does not die to a stray shot,
and it winds a whole ring at once. The owner decided the Clockwork's repair is not to be nerfed.
It keeps the same price as a Winder's repair: a quarter of the unit's price for a full mend.

Why 420 health and 3 armour.
It is a heavy iron machine with no gun, worth killing. It must survive a few stray shots.
A Pendulum has 340 and 2. A Powder Wagon has 220 and 1.
A Musketeer does 20 a shot, less 3 armour. Ten Musketeers firing at it kill it in three volleys, about 8 seconds.
A Brute does 26 a blow, less 3. Two Brutes kill it in about 18 seconds.
So it is safe from a skirmish but not from a focused attack. That is design principle 2: no safe global bonus.

Why 175 cogs, 75 Tension and 4 supply.
It stands in for three or four escort Winders: 150 to 200 cogs and 3 or 4 supply.
The Tension is the price of an Escapement machine. A Pendulum costs 75 Tension too.
It replaces Winders that would be free to work the presses at home. That is the trade.

Why no weapon.
It is a support machine, like the Crown's Powder Wagon. It is a target to protect, not a fighter.
A weak attack would only make it walk into fights. Without one, it stays where it is sent.

## Compared with the others

| unit | cost | supply | health | what it does |
| --- | --- | --- | --- | --- |
| Crown Powder Wagon | 70 gold, 30 powder, a horse | 2 | 220, armour 1 | carries powder for the Musketeers; no weapon; blows up when killed |
| Crown Missionary | 125 gold | 1 | 60 | bandages one man to full in 4 seconds; raises the fallen |
| Brood Spore Mother | 175 biomass, 40 essence | 4 | 260, armour 1 | lobs spit; MIASMA heals the Brood in a cloud |
| Brood Mist Toad | 100 biomass, 25 essence | 3 | 90 | fog and tongue |
| Clockwork escort Winder | 50 cogs | 1 | 46, armour 1 | winds one soldier at a time, mends at 20 a second |
| Clockwork Great Winder | 175 cogs, 75 Tension | 4 | 420, armour 3 | winds everything in 6 tiles; mends one at 30 a second; sweeps wrecks into parts |

The Missionary heals men fast, but they are men: they only need bandages.
The Clockwork's soldiers need winding all the time off their ground. That is the Great Winder's real job.
The Spore Mother heals the Brood in a cloud, on a cooldown. The Great Winder winds, always, in a ring.

## How winding works

Every half second it looks at every unit within 200 pixels.
A Clockwork unit of its side, or an ally's, is wound by 0.06 a second.
Not the Winders. They wind themselves. Not itself. It is always full.
On the gear ground this changes nothing: the field winds faster anyway.
Off it, the army round the Great Winder stays wound.

While it is selected, a brass ring with clock ticks shows the area on the ground.

## How mending works

MEND is an autocast. It is on from the start. Press it to switch it off or on.
Standing about, every 0.6 seconds, it looks round for the most hurt Clockwork unit within 7 tiles.
A run-down statue counts as more hurt.
It walks up to it and mends it with its key arm. You see the key turn.
It goes on to the next one until none is left.
Right-click a hurt unit to send it there.
It stops if your cogs run out.
It mends units only, not buildings. Buildings stay the Winders' job at home.
The Great Winder is the field workshop.

## How sweeping works

SWEEP is an autocast too, on from the start.
With nothing to mend, it looks for the nearest wreck within 8 tiles.
A wreck is the body of a Clockwork unit of its own side, or an ally's, lying at rest.
It walks up to it, rollers first, and sweeps it for 2 seconds. You see the rollers turn.
Then the wreck is gone, with a puff of dust, and the parts go in its hopper.
A Clock Soldier's wreck gives 7 parts. A Pendulum's gives 20. A Winder's gives 5.
A wreck that has rotted half away gives half.

It never sweeps a Crown or a Brood body. The owner decided that on 2026-10-27.
Denying the other sides their bodies is done another way: area shots fired at the ground.

When the hopper is full, at 100 parts, it stops sweeping, and you are told once.

The parts are on its card. Its card says: "Parts 37/100 · winds everything within 6 tiles."

## Saves, replays and online

- A save keeps its parts, and both autocast switches.
- Online and in replays, the snapshot carries `parts` and `auto_sweep`. MEND is the unit's `auto_repair`, already sent.
  Its order and work (mend, sweep) are sent too, so a guest sees the key arm and the rollers.
- A swept wreck leaves online and in replays the way a torn-up body does: the same effect line.
- Older replays read the new fields by name, as before.
- The MEND and SWEEP buttons go through the command funnel's property list (`auto_repair`, `auto_sweep`).
- The Great Winder's own code uses no clock and no random numbers.

## How the computer uses it

The computer is the clockwork-ai job's to rewrite. These hooks are small and in their own functions.

- `AI._great_winder_due`: once its Escapement works and the army has 4 soldiers, it makes ONE Great Winder.
- `AI._great_winder_follow`: the Great Winder walks to a spot just behind the army, toward home.
  It goes wherever the army goes: the rally, the attack. There its autocasts mend and sweep.
- `AI._great_winder_escort`: the owner's point. The Great Winder takes the workers' place on the battlefield.
  While one is out, the escort of ordinary Winders is 3 smaller for each, down to one Winder.
  That one Winder fetches soldiers left run down outside the ring. The Ballistas' crew are extra, as before.
- The army's own orders leave the Great Winder out. It never leads an attack.

## Sounds

All cut from the owner's Clockwork recordings, in `tools/audio/make_clockwork_sounds.py`:

- `combat/great_winder_step`: a slow, heavy ratchet step. Once a walk loop.
- `combat/great_winder_wind`: the winding crank, while it mends.
- `combat/great_winder_sweep`: the brush sweep, the crank's grind low, with scraps rattling into the hopper.
- `combat/great_winder_death`: a crash, its spring letting go, its parts spilling out.
- Its voice lines in `voice/great_winder/`: the deepest ratchet in the faction, with the old bell's hum.

## The art

- The body, the legs, the walk, the winding arm and the rollers are the owner's art, made by
  `tools/great_winder_guide/anim.py`. They are not redrawn.
- The importer builds the frames from anim.py's own layers at the sheet's size, puts on the Clockwork palette,
  then shrinks them once. Game cell 182 by 103, the feet at 91, 89. The west views mirror the east ones.
- The palette rule turns its red bands and every blue part into player colour: the leg balls and the brush bristles too.
- WALK has 12 frames, 4 legs. WIND is the key turning, 8 frames. SWEEP is the rollers turning, 8 frames.
- IDLE and DEATH are made in code from its standing frame. They are listed in `docs/art_style_inconsistency.md`.
- The portrait is round 13's, `assets/icons/great_winder.png`.
- The MEND and SWEEP buttons are cut from the painted key and roller sheet.

What to draw, if the owner wants it:

- A painted wreck: the legs folded, the hopper spilled, the key snapped off. It would replace the code-made death.
- A MEND button: the key turning in a gear. A SWEEP button: the rollers with a cog flying into a hopper.
- The arm sliding out and back in is in anim.py, but the game shows only the turning key.
  An "arm out" and "arm in" use could come back if the mending start and end need to read.

## Reassembly, later

This is for a later job. Nothing here is in the code.

The idea, from the owner: the Great Winder is the field workshop. It rebuilds a machine in the field from parts,
after a research.

How the parts could be spent:

- A research at the Escapement, perhaps called REASSEMBLY, unlocks a REBUILD order on the Great Winder.
- REBUILD picks a unit kind the side can make. It costs parts instead of most of the cogs.
  A guess: the unit's price divided by 10 in parts, plus a quarter of its cogs, and all of its Tension.
  So a Clock Soldier would be 7 parts and 18 cogs. A Pendulum would be 20 parts, 50 cogs and 75 Tension.
- The machine stands still and plays its WIND strip while it builds. It takes the unit's build time, or a bit more.
  The new unit steps out in front of it, run down, and the ring winds it up.
- The supply cap still counts. A rebuild is a unit like any other.
- Parts come only from its own wrecks. So it pays back losses, not wins. That is design principle 2:
  the side that lost the fight gets some of it back, the brake works quietly.
- The other sides' bodies are never parts. Reverse-engineering enemy machines could be a later idea.
- The hopper's cap, 100, is about five Clock Soldiers or one Pendulum and a half. A full hopper should feel worth a rebuild.
- When the Great Winder dies, its parts could spill as a wreck of their own, for another Great Winder to sweep.
  Today they are simply lost.

## What is left

- Reassembly, above.
- The numbers need a playtest. Watch three things.
  First, whether the ring makes the gear ground too easy to leave.
  Second, whether 27 speed leaves it too far behind the army to matter.
  Third, whether its mending in a fight is too strong next to the Winders' (the owner wants repair kept strong).
- The computer makes only one, and walks it behind the army. It does not pull it back from a losing fight.
- Death and idle are made in code. A painted wreck would look better.
- The Clockwork Lab does not start with a Great Winder. Spawn one from the SANDBOX panel, tab CLOCK.
- The Springer is still `jack` in the code. This code uses the current names.

## Tests run on this branch

The list is filled in at the end of the job.
