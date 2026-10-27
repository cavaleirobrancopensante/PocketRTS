# The Spring Ballista

The owner's unit, decided on 2026-10-27. Built on branch `ballista`, version 0.14.80.
Code: `scripts/ballista.gd`. Numbers: `Defs.BALLISTA` and `Defs.UNITS["ballista"]`.
Art: `tools/import_ballista.py`. Tests: `tools/test_ballista.gd` and `tools/test_ballista_ai.gd`.
Pictures: `tools/shot_ballista.gd`, written to `docs/shots/ballista/`.

## What it does

The Spring Ballista is a Clockwork bolt thrower on cog wheels.
It is tier 2. It replaces the Spring Catapult, which was only ever art.
The catapult's files stay where they are: `art/redraws/catapult_*` and `tools/catapult_guide/`.

It fires a giant screw in a straight line.
The bolt goes through its target and on into the enemies behind it.
The first enemy takes the whole shot. The second takes half. The third takes 30 percent.
It never hits its own side. It never hits flyers.
An armoured unit takes 1.75 times the shot. A building takes twice the shot.
A building stops the bolt. It sticks in it.

It has no set-up. It fires as soon as it stops.
On a move order it also fires on the move, at an enemy in range ahead of it.
Then it must reload. Its spring is wound again only while it stands still.
While it moves, the winding waits.

It cannot shoot anything closer than 2 tiles. Up close it is weak.
Against a swarm of light units it is weak too: one slow bolt at a time.

It picks its own targets. It likes armoured units best.
Then it likes a line of enemies behind the target.
A gate or a wall comes before a lone light soldier.
Other buildings come last.

Attack ground works too. The bolt flies through the spot and on.

## The crew

One Winder is built in. He is part of the picture, not a unit.
So the Ballista always has its own crewman. It can move and shoot alone, slowly.

Up to four more Winders can board it.
Select the Ballista and press LOAD CREW, then tap Winders.
Or select Winders and press BOARD: they crew your nearest Ballista with room.
Or right-click your Ballista with Winders selected.
UNLOAD CREW sets them down where they stand.
A crewman given any other order steps off and does it.
If the Ballista is destroyed, its crew step off alive.

Each extra Winder makes it reload 10 percent faster and move 10 percent faster.
With four, it reloads and moves 40 percent faster.

The crew stay on the field, beside the machine.
While it moves they push it from behind, in a line across its back.
While it reloads they crank it, in a file along its right side, where the crank is.
Otherwise they stand by it.

The crew can be hit. That is the counter: shoot the crew.
Each crewman shot down takes his 10 percent with him.

Clicking a crewman selects the Ballista. The crew are not workers while they crew:
the economy and the computer's work orders leave them alone.

## Its numbers, and why

These are guesses, as design principle 1 says. They are written down to be tuned.

- Cost: 150 cogs and 50 Tension. Supply 3. Build time 30 seconds.
- Made at the Movement Works, once an Escapement works, like the Netter.
- Health 210, armour 1, tagged armoured. It is iron and brass.
- Speed 34. With four crew, 47.6.
- Reach 300. Nothing closer than 64.
- Damage 45 a bolt. Reload 7 seconds of winding. Aim 0.3 seconds.

One shot every 7.65 seconds alone. With four crew, every 5.65 seconds.
That is 5.9 damage a second alone, and 8.0 with four crew.
On armour it is 10.3 a second alone, and 13.9 with four crew.
On buildings it is 11.8 a second alone, and 15.9 with four crew.
A line of three enemies adds 80 percent to that.

What it takes to kill things, alone:

- A Brute, 240 health and 2 armour: 4 bolts, about 23 seconds.
- A Spore Mother, 260 health and 1 armour: 4 bolts.
- A Crown Cannon, 140 health and 1 armour: 2 bolts.
- A Crown gate, 300 health and 2 armour: 4 bolts.
- A Musketeer, 70 health: 2 bolts. Not a good use of it.
- An egg of three Raptors: 2 bolts each. A swarm runs under its least reach.

## Compared with the others

| unit | cost | reach | set-up | damage a second, plain | on armour | on buildings | area |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Crown Field Cannon | 170 gold, a horse, 4 supply | 430 | 2.5 s | 5.9 | 10.3 | 14.7 | line of round shot, small splash |
| Crown Mortar | 145 gold, 20 powder, 3 supply | 160 to 352 | 3 s | 5.0 | 5.0 | 7.6 | wide splash, friends too |
| Brood Spore Mother | 175 biomass, 40 essence, 4 supply | 70 to 300 | 2.5 s | 5.3 | 5.3 | 5.3 | wide splash |
| Clockwork Pendulum | 200 cogs, 75 Tension, 4 supply | melee | none | 8.6 each in the arc | 7.1 | 10.7 | arc in front |
| Clockwork Spring Ballista | 150 cogs, 50 Tension, 3 supply | 64 to 300 | none | 5.9 (8.0 crewed) | 10.3 (13.9) | 11.8 (15.9) | line of 3 |

Why these numbers:

- The Cannon is the Crown's long gun. The Ballista is shorter: 300, not 430.
  So the Cannon wins a duel at range, but it must set up and it needs spotters.
- The Ballista has no set-up. The price for that is the slow reload, wound only while it stands.
- Its armour bonus is the Cannon's round shot bonus, 1.75. The two are each side's answer to heavy units.
- On buildings it is a little weaker than the Cannon. With a full crew it is a little stronger.
  Crew cost Winders: they are not winding presses meanwhile. That is the trade.
- Its reach matches the Spore Mother's. She has a splash. It has a line.
- The Pendulum is the Clockwork's answer to swarms. The Ballista is its answer to armour and walls.
  Together they cover each other.
- 3 supply, against the Cannon's 4: no horse, and it is weaker alone.

## How the computer uses it

The computer is the clockwork-ai job's to rewrite. These hooks are small and in their own functions.

- `AI._ballista_want`: once its Escapement works, it wants one Ballista.
  Two when it has seen two armoured enemies, or an enemy wall or gate. Three after six armoured.
- `AI._produce`: the Movement Works makes them, once the army has three other soldiers.
- `AI._ballista_crew`: its escort Winders crew each Ballista, two each, the nearest first.
  The escort is two bigger for each Ballista (`AI._escort_want`).
- `AI._micro` leaves Ballistas to their own pick: armour, gates, lines.

## Saves, replays and online

- A save keeps the crew (each crewman's Ballista) and the reload under way.
- Online and in replays, the snapshot carries `loaded` and each crewman's `crew_of`.
  So a guest draws the machine loaded or fired, and the crew pushing or cranking.
- Older replays read the new fields by name, as before.
- The orders go through the Balloon's commands: `load_order` and `unload_order`.

## Sounds

All cut from the owner's Clockwork recordings, in `tools/audio/make_clockwork_sounds.py`:

- `combat/ballista_attack`: the bow's spring twang, low, with a heavy clang.
- `combat/ballista_hit`: the bolt's thunk where it strikes.
- `combat/ballista_crank`: a ratchet crank, now and then while the crew wind it.
- `combat/ballista_wound`: the spring wound home.
- `combat/ballista_death`, and its voice lines in `voice/ballista/`.

## Pictures

- `views_loaded_top_fired_bottom.png`: the five views, loaded on top, fired below.
- `boarding.png`, `crewed_selected.png`: four Winders boarding it.
- `crew_push_e.png`, `crew_push_s.png`, `crew_push_ne.png`: the crew pushing.
- `crew_crank.png`: the crew cranking while it winds.
- `bolt_through_the_line.png`, `bolt_through_the_line_2.png`: a bolt through Crown Cannons and Musketeers.
- `bolt_into_gate.png`: a bolt into a Crown gate.
- `crewman_shot.png`, `card_after.png`: a crewman shot down, and the card after.
- `reload_and_shot.gif`: the crew cranking the reload, then the next shot.

## The art

- The machine: `art/redraws/ballista_dirs.png`, cut by `tools/import_ballista.py`.
  The front view is mirrored, so the crank is on the machine's right in every view.
  Its size is the Spring Catapult's: 1.5 times the Netter.
- The bolt in flight: cut from `art/redraws/concepts/ballista_v1.png`.
- The crew: `art/redraws/winder_crew_<view>_chatgpt.png`, push and crank strips on the Winder.
- The portrait is the owner's painted one, `art/ui/icons3/portrait_ballista.png`. The CREW button is made from the crew art.
- What is drawn in code is listed in `docs/art_style_inconsistency.md`: the death, the push bob, the crew's placing.

## What is left

- The death is the owner's painted wreck: the bow snaps, a wheel comes off, it lies broken and smoking, then still.
  It is one view, used in every direction. A wreck per direction only if one looks wrong.
- A push sheet with a real stride in the e, se and ne views. A one pixel bob stands in.
- The crew's spots are placed by eye. Check them in a real game and nudge `Ballista.BACK`, `SIDE` and `REAR`.
- The numbers need a playtest. Watch three things.
  First, whether four crew is too strong for the Winders it costs.
  Second, whether 300 reach lets it shell gates from outside Musketeer reach for too long.
  Third, whether it dies too fast to Raptors under its least reach.
- The computer only crews two per Ballista and does not pull them back out of a fight.
- The Jack is to be renamed Springer in the code after the clockwork-ai merge. This code uses the current names.
- The Clockwork Lab does not start with a Ballista. Spawn one from the SANDBOX panel, tab CLOCK.
- A whole match is still not the same twice on one seed (tools/test_determinism.gd, also on main: the path budget,
  docs/pathfinding_audit.md). The Ballista's own code uses no clock and no random numbers.
  `test_determinism.gd` now takes `f0:` and `f1:` for the two factions, so a Clockwork match can be checked.

## Tests run on this branch

- `test_ballista.gd` and `test_ballista_ai.gd`: all pass.
- `test_clockwork_sounds.gd` now hears the Ballista too: all pass.
- `test_cw_tier3`, `test_cw_tier3_ai`, `test_cw_air`, `test_gear_ai`, `test_gear_save`, `test_attack_ground`,
  `test_west_views`, `test_anim_viewer`, `test_files`, `test_i18n`, `test_replay`: all pass.
- `tools/test_online.sh`, plain and with a Clockwork host: host and guest all OK.
