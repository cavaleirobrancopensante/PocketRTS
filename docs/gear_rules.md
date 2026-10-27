# The gear rules for base building (0.14.85)

The owner's decisions of 2026-10-27, built. The study behind them is docs/clockwork_gear_study.md. The decisions are at the end of docs/clockwork_ground_up.md.

The owner was away. Every guess below is Claude's. Each one says so.

## What changed for the player

### 1. The turret circle

Each Ratchet Turret claims a circle of ground. The circle is 4 tiles round the turret's middle. Two turrets' circles may not overlap. So turrets stand at least 8 tiles apart. No more turret clumps.

The lore. A turret's spring draws every bit of force from the gears under it. A second turret inside the circle would starve both, and both would jam.

While you place a turret, every turret's circle is drawn on the ground. The ghost's own circle is green when it is free. It is red where it would overlap, and the other turret's circle turns red too. The ghost says TOO NEAR A TURRET in red.

The rule counts your own turrets only, also the ones still planned or being built. An enemy turret does not count.

Old saves keep their turrets, even turrets side by side. The rule only stops new ones.

The radius, 4 tiles, is the owner's guess, kept. The Brood's Feeding Pits use 5.

### 2. The Heavy Works

A new building: the Heavy Works. In Portuguese, Oficina Pesada. In Spanish, Taller Pesado.

It makes the heavy machines: the Pendulum, the Spring Ballista and the Great Winder. The Great Winder landed on main while this job ran; it moved here from the Movement Works too.

It sits on its BIG gear only. It cannot swap to the small one. Its card says so: "Big gear only: slow and strong, the heavy torque."

Everything it makes costs Tension. So it is a Tension user, like the Escapement and the Clock Aviary. Its ring must mesh with a Mainspring's ring. Without one it stands idle and shows NEEDS MAINSPRING.

It needs a working Escapement before it can be placed. That is the Ballista's old requirement.

Claude's guesses for its numbers: 175 cogs, no Tension, 45 seconds to build, 1,100 health, armour 2. That is a little more than the Light Works. The footprint is 3 by 3. Its big ring has 30 teeth.

Its art is the owner's ChatGPT sheet, art/redraws/heavy_works_empty_chatgpt.png. Only the top row is used: built, under construction, damaged, destroyed. The winding key on the winch house is turned in code from the built frame, like the Movement Works' key. The script is tools/press_anim/heavy_works_key.py.

### 3. The machine in the bay

The owner asked to see the actual vehicles being assembled. So the bay is painted empty. While the Heavy Works trains, the game draws that unit's own sprite in the bay, under the crane.

It is the unit's first idle frame, seen from the south east, scaled down to fit the bay.

It is built up from the ground in six steps. Dark at first, it brightens to its true colours. A thin hot seam glows along the top of the part built so far.

The crane's chain and hook were cut off the painted frame. The game draws them. While a machine is assembled, the hook comes down onto the top of the work. When the bay is empty, the hook rests where it was painted.

It is drawn from the building's queue and training time. So an online guest and a replay show it too.

The code is scripts/heavy_works.gd.

### 4. The Light Works

The Movement Works is renamed the Light Works. In Portuguese, Oficina Leve. In Spanish, Taller Ligero.

Only the name the player sees changed. The internal id stays movement_works, so saves, replays, the computer and the tests did not need a rename.

It makes the light machines: the Clock Soldier, the Springer and the Netter. The Springer and the Netter still need a Mainspring beside it, for their Tension.

It no longer makes the Pendulum, the Ballista or the Great Winder.

### 5. Size sets the tempo

A small ring turns fast and works quick and light. A big ring turns slow and works heavy and strong.

The Light Works trains 15% faster on its small ring and 15% slower on its big one.

The Escapement researches 10% faster on its small ring, 10% slower on its big one. The Clock Aviary trains 10% faster or slower the same way.

These numbers multiply the drive, the efficiency from the gear train. The building's efficiency on its card does not count them.

The Ratchet Turret on its small ring fires quick light screws: 11 damage every 1.2 seconds. On its big ring it fires slow heavy screws: 21 damage every 2.2 seconds. Both rings give about the same damage a second, a little over 9. Armour takes the same off every hit, so the big screw is the answer to armour. Against armour 2, it does about 7.6 a second to the small screw's 7.2.

The reach did not change: 200 pixels on both rings. A Crown gun reaches 430, so the big ring does not out-range the Crown's guns. The old turret did 14 every 1.5 seconds.

Each card says its ring's trade in one line. For example: "Small gear: works 15% faster." The gear swap's tooltip says it too.

The Cog Press and the Mainspring already traded by crew. Their cards now say it in one line too.

### 6. Brass floor plates

The buildings that use Tension stand on a polished brass floor plate: the Mainspring, the Escapement, the Heavy Works and the Clock Aviary. The others keep the dark iron plate.

The brass plate is made in code from the iron one, by tools/gear_art/make_brass_plate.py.

### 7. Readability

The placing ghost now lights the teeth where its ring would mesh, in green. Where it would clash, the teeth light red. Both rings light up, where they meet.

The ghost says the percent it would work at. That is its drive times its ring's tempo. A small Light Works next to the Clocktower says 115%.

When a building can't go there, or would stand idle, the ghost gives one red line: NO LINK, NO LINK: OTHER LEVEL, CLASH, TOO NEAR A TURRET, or NEEDS MAINSPRING.

A small brass spring mark sits over every building fed by a Mainspring.

THE GEAR VIEW shows the whole network at once. The key is the backquote, `. On a phone, every Clockwork building's card has a GEAR VIEW button. In the gear view, the drivers glow white gold: the Clocktowers and the Mainsprings. Every other ring is tinted by how well it works: green at full speed, yellow green at 90%, orange at 80%, red at 70% or idle. Each Mainspring's reach is outlined, dashed. The turret circles are drawn. The ground dims a little so the rings read.

The backquote used to switch the Line's pressure overlay. The Line is shelved in gear mode, so in gear mode the key is the gear view's.

### 8. Not done

No extra early defence for the Clockwork. The owner said no.

No clutch, flywheel or worm gates. Maybe later.

## The pictures

All in docs/shots/gear_rules/, filmed by tools/shot_gear_rules.gd in the Clockwork Lab.

- turret_too_near.png: a turret ghost too near another. Both circles red, TOO NEAR A TURRET.
- turret_far_enough.png: a turret ghost far enough. Its circle green.
- ghost_meshing_teeth.png and ghost_clash_teeth.png: a Regulator's ghost meshing, its teeth green; and clashing, red.
- heavy_works_idle.png: the empty bay, the hook up.
- heavy_ballista_12.png to heavy_ballista_93.png: a Spring Ballista rising in the bay.
- heavy_pendulum_30.png to heavy_pendulum_93.png: a Pendulum rising.
- heavy_great_winder_50.png and heavy_great_winder_93.png: a Great Winder rising.
- card_heavy_works.png, card_light_works.png, card_turret.png: the cards, with the ring's trade.
- gear_view.png and gear_view_close.png: the gear view.
- base_plates.png: a base with brass and iron floor plates.

## The computer

It places through the same placement check as a player. So it obeys the turret circle by itself. Its spot search, Game.find_spot, never gives a turret spot inside another's circle.

It lays one Heavy Works as soon as its Escapement works. Its cogs are held back for it, like the tech's. It goes where its big ring meshes with a Mainspring's.

The big ring needs room. In most test games the plateau had no room left by any Mainspring. So the computer does two things.

First, when it places its first Mainspring, it looks for a spot with room for both the Escapement and the Heavy Works. If it finds one, it keeps the Heavy Works' spot free. Its own Regulators, presses and turrets are not put there. This is Game.ai_keep.

Second, with no room by any Mainspring, it builds a new Mainspring where the big ring will fit beside it, and keeps that spot.

From the Heavy Works it makes its first Spring Ballista, then a few Pendulums, then more Ballistas, and its one Great Winder. Tension is kept from the Springers for a wanted heavy machine.

Its Light Works stay on their small gear. They no longer go onto the big gear for Pendulums.

The other ring choices did not change.

STUDY_RESULTS

## The tests

- tools/test_gear_rules.gd, new: the turret circle refuses a turret too close and accepts one far enough, also through the computer's spot search; the Heavy Works trains the Pendulum and the Ballista only beside a Mainspring, and the Light Works does not; the ring size changes the training speed and the turret's fire as set; the machine in the bay is drawn and grows; saves keep it all, and an old save's turrets side by side load and stay.
- Updated for the new rules: test_cw_tier3, test_cw_tier3_ai, test_ballista, test_ballista_ai, test_great_winder, test_gear_econ, test_clockwork_sounds.

TEST_RESULTS

## What is left

- The machine in the bay is the unit's own sprite, darkened and cut. A painted "being assembled" frame per machine would look better.
- The brass plate, the spring mark and the gear view's colours are code-drawn. They are listed in docs/art_style_inconsistency.md.
- The Heavy Works' big ring is large. On a crowded plateau the computer can lay it late. Watch for it in games.
- The tempo numbers are guesses: 15% for the Light Works, 10% for the Escapement and the Aviary, and the turret's two screws.
