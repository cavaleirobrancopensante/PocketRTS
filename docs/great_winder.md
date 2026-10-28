# The Great Winder

The owner's unit, decided on 2026-10-26 and 2026-10-27. Built on branch `great-winder`; merged with main as version 0.14.83 (after the clockwork-ai computer, 0.14.81, and the Jack's rename to the Springer, 0.14.82).
The owner's scope: "the unit now, reassembly later". Changed on 2026-10-28: no reassembly. The sweep turns wrecks into cogs.
Code: `scripts/great_winder.gd`. Numbers: `Defs.GREAT_WINDER` and `Defs.UNITS["great_winder"]`.
Art: `tools/import_great_winder.py`, on top of `tools/great_winder_guide/anim.py`.
Test: `tools/test_great_winder.gd`. Pictures: `tools/shot_great_winder.gd`, written to `docs/shots/great_winder/`.
The sweep into cogs: `tools/shot_great_winder_sweep.gd`, written to `docs/shots/great_winder_sweep/`.

## What it does

The Great Winder is the Clockwork's big winding machine. It rolls on four cog wheels (since 2026-10-27, branch
gw-wheels: it walked on four painted legs before, and the owner found them silly in the game).
It is slow. It has no weapon.
It does the job the Winders do when they walk with the army. It does it as one machine, and better.

It has three jobs.

First, winding. Clockwork soldiers run down off the gear ground.
Every Clockwork soldier near the Great Winder is wound up a little, all the time.
Near it, an army does not run down. A run-down soldier near it wakes up again.

Second, mending. It mends hurt Clockwork units with its key arm. One at a time.
It is faster than a Winder. It costs cogs, like a repair.

Third, sweeping. It sweeps up Clockwork wrecks with its rollers, and turns them into cogs.
The cogs go to its side at once.

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
- Sweeping pays 30 percent of the unit's cog price, at once. Less as the wreck rots. At least 1.
  No Tension comes back. `Defs.GREAT_WINDER["share"]`, 0.30.
- It stops 10 pixels past its edge to sweep (`sweep_reach`). It was 34, which left the wreck lying beside it in the pictures.
- It leaves a wreck alone when an enemy soldier is within 300 pixels of it (`danger`).

Why the speed is 27.
It was set to 27 on legs, so the painted feet would not slide: the legs walked 16 pixels a loop of 12 frames.
On wheels that reason is gone. A wheel can roll at any speed: the game only turns it faster or slower.
So 27 is now a number for play, and it is kept, for the reason that was always behind it.
It is slow on purpose. A Ballista goes 34, a Pendulum 46, a Clock Soldier 68.
So it falls behind on a march, and catches up when the army stops. That is its cost:
an army that runs ahead leaves its winding ring (design principle 2: no safe global bonus).
A faster Great Winder would keep a whole marching army wound for free. A slower one would never catch up.
The playtest question in "What is left" still stands: if it is too far behind to matter, 30 to 34 is the next try.

How the wheels match the ground speed.
Each wheel turns 90 degrees, three of its twelve teeth, in a walk loop of 12 frames.
Its tips touch the ground, so it rolls on about 12.9 game pixels of radius (44.3 sheet pixels at the game scale 0.30, the
middle a hair lower than the tips: 0.97 of them).
A quarter turn of that is 20.25 game pixels. That is `Defs.GREAT_WINDER["stride"]`.
At 27 pixels a second the loop plays at 27 x 12 / 20.25 = exactly 16 frames a second (`Unit.WALK_FPS_ART`), so the teeth do
not slide on the ground. The wheel size was picked to look right first (about the Spring Catapult's), then nudged from 44 to
44.3 sheet pixels so the rate comes out even. The game still plays its walk on a 30 Hz tick, so all 16 frames show.
If the speed is ever changed, only `WALK_FPS_ART["great_winder"]` changes with it: speed x 12 / 20.25.
`tools/test_great_winder.gd` checks the two agree.

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
| Clockwork Great Winder | 175 cogs, 75 Tension | 4 | 420, armour 3 | winds everything in 6 tiles; mends one at 30 a second; sweeps Clockwork wrecks into cogs |

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

The owner decided this on 2026-10-28:
"The Great Winder turns Clockwork bodies into cogs. It doesn't reassemble anything.
It gets a portion of the cost of that unit."
Each side gets something different from bodies.
The Brood gets essence, from any body.
The Crown raises its own dead.
The Clockwork gets cogs back, from Clockwork wrecks.

SWEEP is an autocast too, on from the start.
It works when the Great Winder stands idle, with nothing to mend.
Then it looks for the nearest Clockwork wreck within 8 tiles. That is its winding ring, and a bit more.
Any side's wreck counts. In the Clockwork mirror match it sweeps the enemy's wrecks too.
The cogs always go to its own side.
It rolls up to the wreck and sweeps it for 2 seconds. You see the rollers turn.
Then the wreck is gone, with a puff of dust.
Its side gets the cogs at once. A gold line rises over it: "+21 cogs".
Then it looks for the next wreck, round the spot where it stood.
When none is left, it rolls back to that spot. So it stays with the army.

In a crowd (0.15.1). Soldiers standing round a wreck can stop the big machine short of it.
If it gets no closer for a second, and it is within 40 pixels of its edge, it sweeps from there.
If it gets no closer for 6 seconds anywhere, it leaves that wreck for 10 seconds, and sweeps another.
Before this, the computer's Great Winder could push at its own army for good, and never sweep a soldier who fell in the middle of it.

It keeps out of fights. It has no weapon.
It skips a wreck with an enemy soldier within 300 pixels of it. Workers do not count.
If an enemy comes near the wreck while it is on its way, it gives the wreck up and rolls back.
It sweeps it later, once the enemy is gone.

It never sweeps a Crown or a Brood body. The owner decided that on 2026-10-27.
Denying the other sides their bodies is done another way: area shots fired at the ground.

What a wreck pays, fresh:

| wreck | its cog price | cogs back |
| --- | --- | --- |
| Winder | 50 | 15 |
| Clock Soldier | 70 | 21 |
| Pendulum | 200 | 60 |
| Great Winder | 175 | 53 (its Tension is not paid back) |

A wreck that has rotted half away pays half.

Its card says: "Winds everything within 6 tiles." While it sweeps: "sweeping a wreck into cogs."

### Why 30 percent

The owner asked for about 25 to 35 percent. 30 is the middle. Here is why it fits.

The Brood gets essence from bodies in two ways.
The Brood Pen's SACRIFICE eats a living creature of its own, and pays 35 percent of its price.
But that creature was alive. The Brood gives up a unit to get it.
Its grubs also harvest bodies on the field: 2 essence for each supply of the dead unit.
A Clock Soldier's body would give the Brood 2 essence. Essence is rare, so that is worth more than 2 biomass.
And the grubs harvest every body, of every side.

The Crown's Missionary raises a whole soldier, at half health.
It takes 6 seconds a body, one Missionary a Church, Musketeers and riders only, within 60 seconds of the fall.
That is worth more than any refund, but it is slow and narrow.

The Great Winder only takes Clockwork wrecks. It needs a 175 cog and 75 Tension machine on the spot.
It takes 2 seconds a wreck, and it will not go near enemies.
So it pays back less than a sacrifice: 30 percent, not 35, and no Tension.
But the cogs go straight back into the economy, with no unit given up.

This is mostly a refund of losses. The side that lost the fight gets a little back.
That is design principle 2, anti-snowball: the brake works quietly.
In the mirror match it can sweep the enemy's wrecks too. Then it pays the winner of a fight.
That is the owner's choice, and it needs the winner to hold the field, with a Great Winder on it.

If it is too strong, 25 percent is the next step. If it is too weak, 35.

## Saves, replays and online

- A save keeps both autocast switches. The save's "gw" list still has three slots. The first held its parts until 0.14.103.
  It is written as 0 now, and read as nothing. So old saves still load. Their parts are simply dropped.
- Online and in replays, the snapshot carries `auto_sweep`. MEND is the unit's `auto_repair`, already sent.
  `parts` is gone from the snapshot. Older replays still play: their rows are read by name, and the old field is skipped.
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
  When it stands idle by the army, it sweeps the wrecks near it into cogs, the same as the player's, and rolls back.
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

- The body, the winding arm and the rollers are the owner's art, made by `tools/great_winder_guide/anim.py`. They are
  not redrawn. The wheels are the Spring Catapult's painted cog, turned in code (see "On cog wheels" below).
- The importer builds the frames from anim.py's own layers at the sheet's size, puts on the Clockwork palette,
  then shrinks them once. Game cell 182 by 103, the ground at 91, 89. The west views mirror the east ones.
- The palette rule turns its red bands and every blue part into player colour: the wheels' hub balls and the brush bristles too.
- WALK has 12 frames, the 4 wheels turning. WIND is the key turning, 8 frames. SWEEP is the rollers turning, 8 frames.
  In WIND and SWEEP the wheels stand still.
- IDLE and DEATH are made in code from its standing frame. They are listed in `docs/art_style_inconsistency.md`.
- The portrait is round 13's, `assets/icons/great_winder.png`.
- The MEND and SWEEP buttons are cut from the painted key and roller sheet.

What to draw, if the owner wants it:

- A painted wreck: a wheel off, the hopper spilled, the key snapped off. It would replace the code-made death.
- The whole machine painted on its cog wheels: the prompt is under "On cog wheels" below.
- A MEND button: the key turning in a gear. A SWEEP button: the rollers with a cog flying into a hopper.
- The arm sliding out and back in is in anim.py, but the game shows only the turning key.
  An "arm out" and "arm in" use could come back if the mending start and end need to read.

## Reassembly: dropped

The first plan was to keep parts, and rebuild machines from them later.
The owner dropped it on 2026-10-28. The Great Winder turns wrecks into cogs, and reassembles nothing.
The parts, their cap of 100, the hopper-full message and the parts on its card are gone.

## What is left

- The 30 percent needs a playtest, above all in the Clockwork mirror match.
- The numbers need a playtest. Watch three things.
  First, whether the ring makes the gear ground too easy to leave.
  Second, whether 27 speed leaves it too far behind the army to matter.
  Third, whether its mending in a fight is too strong next to the Winders' (the owner wants repair kept strong).
- The computer makes only one, and walks it behind the army. It does not pull it back from a losing fight.
- Death and idle are made in code. A painted wreck would look better.
- The wheels are code (the Catapult's cog, scaled, squashed and turned). A painted sheet would look better: see below.
- The Clockwork Lab does not start with a Great Winder. Spawn one from the SANDBOX panel, tab CLOCK.
- The Springer is `springer` in the code since 0.14.82. The merge turned this branch's jack names into Springer ones
  (`Defs.SPRINGER`, `Springer.lift`, "springer" in the Movement Works' list and the sounds test); no new code uses jack.
- On main the Great Winder hooks sit on top of the clockwork-ai computer: `_produce` asks `_great_winder_due` after the
  Netters and before the Springers. Other new clockwork-ai army code (sieges, rush pools) uses `game.army` directly and
  has not been checked for the Great Winder one by one.

## On cog wheels (branch gw-wheels, 2026-10-27)

The owner, after playing: "The Great Winder's legs look silly in game. Maybe we should make it on cogwheels."
So the legs are cut off and it rolls on the Clockwork's own wheel: the painted cog of the Spring Catapult and the Spring
Ballista (`art/redraws/catapult_wheel_chatgpt.png`, rebuilt with even teeth by `tools/catapult_guide/cog.py`).

What was decided, by looking:

- Four wheels, not six. Six had to be smaller (34 sheet pixels against 44.3) to fit three a side. Their teeth crowded each
  other and read as a busy track. Four big wheels read as one heavy cart. Both walks are in
  `art/redraws/great_winder_walk_4wheels.gif` and `great_winder_walk_6wheels.gif`; `LEGS = 6` in anim.py switches.
- The body stays at the height it had (the second legs pass), where the brush housing sits on the ground: a sweeper must
  reach the floor. The wheels hang on the body's sides, the axles low on it, like a heavy cart's.
  In the side view the near wheels cover the belly's empty arch where the legs were.
- Where: at the body's corners, where the legs' hips were. E and the 3/4 views: the rear corner and the front of the body,
  just behind the brush housing. S and N: one at each side, seen edge-on, a far pair behind them.
- How they look per view, as on the Catapult: E face-on and round; SE and NE the same cog squashed to 0.72 of its height;
  S and N the cog's edge-on paint, its hub ball outward. S's tread rolls down toward us, N's up and away.
  The far side's wheels are the same cogs behind the body, darker.
- Turning: 90 degrees a 12-frame loop, screen clockwise when going east; the west views mirror, so they turn the other way.
  The speed match is under "Why the speed is 27". The body judders one game pixel as each tooth comes down.
- Still in WIND and SWEEP (the rollers rumble the body, not the wheels), and in IDLE (the body breathes on its axles).
- Death: the axles give. The body sags and tips, the near wheels come off and fall over (flat toward us, or over to the
  side in S and N), and it goes dark.
- The cell (182 x 103, ground at 91, 89) did not change: the arm's reach sets it. No change to `scripts/cw_art.gd`.

Code: `MOUNT = 'wheels'` and the "cog wheels" section of `tools/great_winder_guide/anim.py` (`WHEEL_AT`, `WHEEL_R`,
`wheel_stride`); the death in `tools/import_great_winder.py` (`death_groups`). The legs code is kept behind
`MOUNT = 'legs'`. Every code-drawn part is listed in `docs/art_style_inconsistency.md`
("The Great Winder on cog wheels").

Pictures, in `docs/shots/great_winder_wheels/`:

- `walk_before_after.gif`: the walk, legs on top, wheels below, the five views. `idle_before_after.gif`,
  `death_before_after.gif` the same for the idle and the death.
- `walk_e_rolling.gif`: the E view rolling over ground marks at the game's own speed (20.25 px a loop at 16 fps):
  the teeth do not slide.
- `in_game_views.png` (the eight directions; the west ones mirrored), `in_game_walking.png` (with an army, selected:
  its ring), `in_game_sweeping.png`, `in_game_walk.gif` (rolling in the game, close up).

### ChatGPT request: the Great Winder painted on cog wheels

The code wheels are the Catapult's cog, scaled and squashed. A painted sheet would make them part of the machine.
Attach these three images (repository paths), and paste the text below as one request:

1. `art/redraws/great_winder_dirs.png` (the Great Winder on its stubby legs, 5 directions, 2 columns)
2. `art/redraws/ballista_dirs.png` (the Spring Ballista on cog wheels, 5 directions)
3. `art/redraws/catapult_wheel_chatgpt.png` (the cog wheel, face-on and edge-on)

```
Attached are three images in the same pixel-art style, on the same navy background (0, 22, 48).
Image 1: a steampunk sweeper machine, the Great Winder, in 5 directions. The rows from top to bottom are: facing the
viewer (south), facing down-right (south-east), facing right (east), facing up-right (north-east), facing away (north).
Column 1 shows the machine with its winding arm stowed, column 2 with its winding arm reaching out, a big key at its tip.
It stands on short stubby legs (blue balls, steel collars, brass dome feet).
Image 2: a different machine, a ballista, standing on brass cog wheels, in the same 5 directions. It shows how the wheels
look in each direction: round and face-on from the side, squashed ovals at the three-quarter angles, seen edge-on (a
tall narrow toothed band) from the front and from behind.
Image 3: the cog wheel itself, face-on (12 even teeth, 8 bolts, a blue hub ball) and edge-on.

Please paint the Great Winder from Image 1 again, same style, same size, same 5 rows and same 2 columns, same navy
background, but REPLACE ITS LEGS WITH FOUR COG WHEELS like the wheel in Image 3: no legs, no feet at all.
- Keep the body exactly as it is: the hopper, the clock face, the red bands, the big key on top, the brass pipes, the
  winding arm and its key in column 2, and the brush housing with its blue brush rollers at the front.
- The body stays at the same height: the brush housing at the front still touches the ground.
- The wheels hang on the sides of the body like the wheels of a heavy cart: two on each side, one at the rear corner and
  one at the front corner just behind the brush housing. Each wheel is about one third as tall as the whole machine,
  its axle low on the body's side, the tips of its teeth touching the ground.
- Draw the wheels in each direction the way Image 2 draws them: round and face-on in the side view (row 3), squashed
  ovals in rows 2 and 4, edge-on narrow toothed bands at the body's two sides in rows 1 and 5. The wheels on the far
  side show only a little, behind the body, a bit darker.
- Brass wheels with a blue hub ball, 12 even teeth, as in Image 3.
No text, no labels, no shadows on the ground, nothing touching between the cells.
```

## Tests run on this branch

Run on the merge with main (0.14.83, 2026-10-27), `godot --headless --fixed-fps 30 --script res://tools/<test>.gd`.
All pass:

- `test_great_winder`: every check ok (winding in and outside the ring, MEND and its cost, SWEEP and parts, the cap,
  saves, online, replays; the computer trains one at 116 s on Ashford Crossing, one only, a smaller escort, follows).
- `test_gear_ai`, `test_ballista`, `test_ballista_ai`, `test_cw_tier3`: all pass.
- `test_springer_compat`, `test_gear_save`, `test_replay`, `test_files` (1055 checks), `test_i18n` (2469 entries,
  nothing untranslated), `test_anim_viewer` (56 units, 2061 strips), `test_west_views`: all pass.
- `test_clockwork_sounds`: 0 failures (it hears the Great Winder mend and sweep).
- `test_ai_rush`, `test_ai_wall_vs_rush`: all pass.

Several of these print their pass line and then end with "Aborted" (exit 134) while Godot shuts down; the checks
themselves all passed. `test_determinism` was not run (its hash varies run to run on main too).
