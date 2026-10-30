# The gear rules for base building (0.14.97)

The owner's decisions of 2026-10-27, built. The study behind them is docs/clockwork_gear_study.md. The decisions are at the end of docs/clockwork_ground_up.md.

The owner was away. Every guess below is Claude's. Each one says so.

## 0.24.12: pick the gear when you build (owner, 2026-10-30)

The owner's words: "Choose the gear size when building and only then."

While you place a Clockwork building, the card has a SMALL GEAR / BIG GEAR button. The key is G. The button shows the size the ghost is on now; pressing it switches. The ghost draws its ring at that size, and a small tag under its verdict says SMALL GEAR or BIG GEAR.

The ghost's check uses the ring you picked. A big ring that would cut into another ring is refused, with CLASH, like any other ring. So a big ring needs room.

Once placed, the size is fixed. There is no swap.

Each kind remembers your last pick for the rest of the match (Game.gear_pick, kept in the save). The first pick of each kind is SMALL, the size every building had since 0.24.4.

Which kinds can pick (GearNet.pickable): every Clockwork building that could swap before 0.24.4. The Cog Press, the Mainspring, the Light Works, the Ratchet Turret, the Escapement, the Clock Aviary and the Regulator. Not the Clocktower, which has its own ring. Not the Heavy Works, which is always big.

### The price of the big ring

The old swap cost 25 cogs and took 4 seconds. Claude used the same numbers (Defs.GEAR "big_pick"): a big ring costs 25 cogs more and takes 4 seconds more to build. A site cancelled before it began pays back all of it, the extra too. One begun pays back three quarters, the extra too.

| kind | small | big |
|---|---|---|
| Cog Press | up to 5 Winders, 7.2 cogs a second | up to 8 Winders, 10 cogs a second; +25 cogs, +4 s |
| Mainspring | up to 3 Winders, 2 Tension a second, stores 200 | up to 6 Winders, 2.6 a second, stores 400; +25 cogs, +4 s |
| Ratchet Turret | 11 damage every 1.2 s | 21 damage every 2.2 s, better against armour; +25 cogs, +4 s |
| Light Works | trains 15% faster | trains 15% slower; +25 cogs, +4 s |
| Escapement, Clock Aviary | work 10% faster | work 10% slower; +25 cogs, +4 s |
| Regulator | | only a wider ring that reaches farther; +25 cogs, +4 s |

The tooltip of the button shows both prices and both trades. So does a building's tooltip on the BUILD page.

A big Light Works, Escapement or Clock Aviary is slower and dearer. It only buys a wider ring, which may bridge a gap. Few will want it. It is offered because the owner asked for the choice on every building that had both sizes.

### The computer

It picks before it looks for a spot, so its spot search and its placement check use the same ring (AI._construct). The rule is simple, on purpose: a BIG Cog Press when the Winders to fill it already stand spare (8 or more beyond every post of its presses and Mainsprings, the builder and the army's escort), and a spot has room for the big ring. Otherwise small. Every other kind is small. A big press raises its Winder cap by 3 (AI._big_press_room).

In practice the computer builds big presses late: at an expansion, after its first presses ran dry and freed their Winders.

### Online, replays, saves

The size goes with the build order: Game.place_building has a 6th argument, `big` (1 or 0). The host sets that side's pick from it, then checks, charges and places at that size. NetPredict shows the right price at once. The site's ring travels in the snapshot (Building.gear_big), so the guest and the replay see it. Saves keep each building's ring ("gb") and each side's last picks ("gpick").

### Pictures

docs/shots/gear_pick/, filmed by tools/shot_gear_pick.gd on Hollowfen: a Light Works ghost on its small ring and on its big ring at the same spot, and a big ring refused where the small one fits.

## 0.24.4: no more gear swap (owner, 2026-10-30)

The owner played the Clockwork: "I dont understand the swap between big gear and small gear, it makes no sense because it clips with other gears and makes the sprites behave in an overlap way, I think we have to remove this feature".

So the SMALL GEAR / BIG GEAR button is gone, with Game.swap_gear, the online command, the SWAPPING badge and the swap's cost and time (Defs.GEAR "swap_cost", "swap_time"). Each building keeps the gear it is built with: the Heavy Works on its BIG gear (Defs.GEAR "big_only"), every other building on its SMALL one. Old saves still load: a swap under way in them ("gs", "gst") is ignored.

What needed the swap: only the Pendulum's big gear (Defs.UNITS "big_gear"), and the Pendulum is made at the Heavy Works, which is always big. Size still sets the tempo (GearNet.tempo): the Light Works, Escapement and Clock Aviary get their small ring's speed; the Heavy Works its big ring's. The big-ring numbers of the Cog Press (8 Winders, 10 cogs a second), the Mainspring (6 Winders, 400 Tension stored) and the Ratchet Turret's heavy screw stay in Defs but no player building reaches them now. If the owner wants them back, the clean way is a choice when the building is PLACED (its ring is then checked like any other), not a swap afterwards.

The spring mark (section 7) now shows only on buildings that use or spend Tension, and explains itself on hover (or a long press on a phone): GearEcon.spring_tip.

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

It sits on its BIG gear only. Its card says so: "Big gear only: slow and strong, the heavy torque."

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

The Movement Works is renamed the Light Works. In Portuguese, Oficina Leve. In Spanish, Taller Ligero. Main made the same rename in 0.14.88, with build keys L for the Light Works and H for the Heavy Works, while this job ran. The names agree.

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

Each card says its ring's trade in one line. For example: "Small gear: works 15% faster." (The gear swap's tooltip said it too, until the swap was removed in 0.24.4.)

The Cog Press and the Mainspring already traded by crew. Their cards now say it in one line too.

### 6. Brass floor plates

The buildings that use Tension stand on a polished brass floor plate: the Mainspring, the Escapement, the Heavy Works and the Clock Aviary. The others keep the dark iron plate.

The brass plate is made in code from the iron one, by tools/gear_art/make_brass_plate.py.

### 7. Readability

The placing ghost now lights the teeth where its ring would mesh, in green. Where it would clash, the teeth light red. Both rings light up, where they meet.

The ghost says the percent it would work at. That is its drive times its ring's tempo. A small Light Works next to the Clocktower says 115%.

When a building can't go there, or would stand idle, the ghost gives one red line: NO LINK, NO LINK: OTHER LEVEL, CLASH, TOO NEAR A TURRET, or NEEDS MAINSPRING.

A small brass spring mark sits over every building fed by a Mainspring. (Since 0.24.4: only over the buildings that use or spend Tension, and hovering it explains it.)

THE GEAR VIEW shows the whole network at once. The key is the backquote, `. On a phone, every Clockwork building's card has a GEAR VIEW button. In the gear view, the drivers glow white gold: the Clocktowers and the Mainsprings. Every other ring is tinted by how well it works: green at full speed, yellow green at 90%, orange at 80%, red at 70% or idle. Each Mainspring's reach is outlined, dashed. The turret circles are drawn. The ground dims a little so the rings read.

The backquote used to switch the Line's pressure overlay. The Line is shelved in gear mode, so in gear mode the key is the gear view's.

### 8. Not done

No extra early defence for the Clockwork. The owner said no.

No clutch, flywheel or worm gates. Maybe later.

## The pictures

All in docs/shots/gear_rules/, filmed by tools/shot_gear_rules.gd in the Clockwork Lab. They are JPEGs, 1200 by 675, to keep the repo small.

- turret_too_near.jpg: a turret ghost too near another. Both circles red, TOO NEAR A TURRET.
- turret_far_enough.jpg: a turret ghost far enough. Its circle green, and its teeth meshing in green.
- ghost_clash_teeth.jpg: a Regulator's ghost cutting into a ring. The clashing teeth light red. (The Lab's plateau is full, so there is no picture of a Regulator meshing; the turret picture shows green teeth.)
- heavy_works_idle.jpg: the empty bay, the hook up.
- heavy_ballista_12.jpg to heavy_ballista_93.jpg: a Spring Ballista rising in the bay.
- heavy_pendulum_30.jpg to heavy_pendulum_93.jpg: a Pendulum rising.
- heavy_great_winder_50.jpg and heavy_great_winder_93.jpg: a Great Winder rising.
- card_heavy_works.jpg, card_light_works.jpg, card_turret.jpg: the cards, with the ring's trade.
- gear_view.jpg and gear_view_close.jpg: the gear view.
- base_plates.jpg: a base with brass and iron floor plates.

## The computer

It places through the same placement check as a player. So it obeys the turret circle by itself. Its spot search, Game.find_spot, never gives a turret spot inside another's circle.

It lays one Heavy Works as soon as its Escapement works. Its cogs are held back for it, like the tech's. It goes where its big ring meshes with a Mainspring's.

The big ring needs room. In most test games the plateau had no room left by any Mainspring. So the computer does two things.

First, when it places its first Mainspring, it looks for a spot with room for both the Escapement and the Heavy Works. If it finds one, it keeps the Heavy Works' spot free. Its own Regulators, presses and turrets are not put there. This is Game.ai_keep.

Second, with no room by any Mainspring, it builds a new Mainspring where the big ring will fit beside it, and keeps that spot.

From the Heavy Works it makes its first Spring Ballista, then its one Great Winder, then a few Pendulums, then more Ballistas. Tension is kept from the Springers for the heavy machine it wants next.

Its Light Works stay on their small gear. They no longer go onto the big gear for Pendulums.

The other ring choices did not change.

Two more things the computer does now.

It keeps the Escapement's spot too, beside the Mainspring. Before, a Regulator sometimes took it, and the tech came late.

It does not build its first turret in the minute it lays the Mainspring and the Escapement, unless it is under attack. The turret's cogs went to the pair before.

## Crown against Clockwork: four games, twice each

Hard Crown against Hard Clockwork, 15 minutes at most. The four games: Greenhold seed 11, Frostmere seed 12 swapped, Hollowfen seed 13, Kestrel Rise seed 14 swapped. Each played twice on main (0.14.84) and twice on this branch (before merging main's 0.14.85 to 0.14.91: crates, terracotta roofs, build keys, wall fixes, the computer's Clocktowers kept on its own side, the Great Winder on wheels). The script is tools/study/study_game_v2.gd. Times are game clock.

| run | game | Mainspring | Escapement | Heavy Works | 1st Ballista | 1st Pendulum | 1st Great Winder | result |
|---|---|---|---|---|---|---|---|---|
| main 1 | Greenhold | 3:01 | 3:45 | - | 5:06 | 9:16 | 7:42 | no winner by 15:00 |
| main 1 | Frostmere | 3:37 | 3:43 | - | 5:46 | 10:00 | 8:57 | no winner |
| main 1 | Hollowfen | 3:43 | 3:49 | - | 9:10 | 12:50 | 12:43 | no winner |
| main 1 | Kestrel Rise | 3:30 | 3:34 | - | 6:07 | - | 10:03 | Clockwork wins 11:24 |
| main 2 | Greenhold | 3:01 | 3:08 | - | 5:19 | 9:14 | 7:14 | Clockwork wins |
| main 2 | Frostmere | 3:45 | 3:51 | - | 6:14 | 14:50 | 8:35 | no winner |
| main 2 | Hollowfen | 3:32 | 3:37 | - | 5:52 | 9:41 | 7:37 | no winner |
| main 2 | Kestrel Rise | 3:29 | 3:36 | - | 6:11 | - | - | Clockwork wins |
| branch 1 | Greenhold | 3:48 | 3:55 | 6:47 | 7:26 | 8:42 | - | Clockwork wins 14:29 |
| branch 1 | Frostmere | 3:51 | 3:56 | 7:40 | 8:10 | 8:55 | - | no winner |
| branch 1 | Hollowfen | 3:50 | 3:56 | 7:12 | 7:42 | 8:17 | - | no winner |
| branch 1 | Kestrel Rise | 3:47 | 3:52 | 8:58 | 9:29 | 10:04 | - | Clockwork wins 11:18 |
| branch 2 | Greenhold | 3:40 | 3:47 | 6:56 | 7:26 | 8:43 | 8:01 | Clockwork wins |
| branch 2 | Frostmere | 3:52 | 3:58 | 7:22 | 7:55 | 12:03 | 8:31 | no winner |
| branch 2 | Hollowfen | 4:36 | 7:10 | 9:06 | 9:37 | 12:43 | 10:12 | no winner |
| branch 2 | Kestrel Rise | 3:41 | 3:47 | 8:19 | 8:52 | 10:36 | 9:37 | Clockwork wins |

What it says.

The results did not move. Both builds: the Clockwork wins two of four, the other two are still open at 15 minutes.

The Mainspring comes about 20 seconds later on the branch. It waits for a spot with room for the Escapement and the Heavy Works.

The first Ballista comes about 2 minutes later. The Heavy Works must be built first, 45 seconds, and it waits for its spot.

The first Pendulum comes earlier, often by a minute or more. On main the Movement Works had to swap to its big gear for it, and seldom did.

Round 1 on the branch had no Great Winder. It was queued after the Pendulums and never got its Tension. Now it comes right after the first Ballista, and Tension is kept for it. Round 2 is with that fix: the Great Winder came at 8 to 10 minutes, as on main.

Branch round 2, Hollowfen: the Mainspring came at 4:36 and the Escapement at 7:10. The first Mainspring found no spot with room for both. So the Escapement waited until 6:22, then went with a second Mainspring beside it. One game in eight, not a pattern. Worth a look if it shows again.

### One more round after merging main 0.14.91

Main moved on while this ran (its computer now keeps new Clocktowers on its own side). So both builds played the four games once more: main at 0.14.91, the branch with main 0.14.91 merged.

| run | game | Mainspring | Escapement | Heavy Works | 1st Ballista | 1st Pendulum | 1st Great Winder | result |
|---|---|---|---|---|---|---|---|---|
| main 0.14.91 | Greenhold | 3:01 | 3:07 | - | 5:00 | 14:32 | 8:11 | no winner |
| main 0.14.91 | Frostmere | 3:48 | 3:54 | - | 6:04 | 9:59 | 8:14 | no winner |
| main 0.14.91 | Hollowfen | 3:43 | 3:49 | - | 10:15 | 12:22 | 10:48 | no winner |
| main 0.14.91 | Kestrel Rise | 3:55 | 7:42 | - | 10:54 | - | 11:29 | Clockwork wins |
| branch + main 0.14.91 | Greenhold | 3:41 | 3:47 | 7:06 | 7:36 | 8:47 | 8:11 | no winner |
| branch + main 0.14.91 | Frostmere | 3:52 | 3:58 | 7:26 | 7:57 | 10:01 | 8:32 | no winner |
| branch + main 0.14.91 | Hollowfen | 3:50 | 3:56 | 7:01 | 7:41 | 8:55 | 8:16 | no winner |
| branch + main 0.14.91 | Kestrel Rise | 3:48 | 3:56 | 7:29 | 8:06 | 9:14 | - | Clockwork wins |

The same picture. Same results. On the branch the heavy machines come steadily, all between 7 and 10 minutes, in every game. On main they swing from 5 to 14 minutes. Kestrel Rise on the branch won before its Great Winder was due.

## The Brood's extreme rush

A quick check, not a test: Hard Clockwork on Balanced against a Hard Brood on Extreme rush, to 6:00, on Greenhold seed 7 and Ashford Crossing seed 4242. Same on main and the branch: the Clocktower stands, the Clockwork loses one or two units, one turret by 4:30.

But the Brood computer was odd in both builds. It made one wave of raptors, then sat on about 1,000 gold with five grubs and built nothing more. That is not from this branch. It is worth its own look.


## The tests

- tools/test_gear_rules.gd, new: the turret circle refuses a turret too close and accepts one far enough, also through the computer's spot search; the Heavy Works trains the Pendulum and the Ballista only beside a Mainspring, and the Light Works does not; the ring size changes the training speed and the turret's fire as set; the machine in the bay is drawn and grows; saves keep it all, and an old save's turrets side by side load and stay.
- Updated for the new rules: test_cw_tier3, test_cw_tier3_ai, test_ballista, test_ballista_ai, test_great_winder, test_gear_econ, test_clockwork_sounds.

All run on the branch after merging main at 0.14.91. Main's 0.14.92 and 0.14.93 (horse messages and sounds) were merged at the very end; test_gear_rules, test_i18n, test_files and test_replay were run again then. The gear rules are 0.14.94.

- Pass: test_gear_rules (new), test_cw_tier3, test_cw_tier3_ai, test_ballista, test_ballista_ai, test_great_winder, test_gear_econ, test_gear_save, test_gear_ai, test_cw_tier2, test_cw_air_ai, test_springer_compat, test_ratchet_turret, test_gear_swap, test_clockwork_sounds, test_cw_lab, test_ai_wall_vs_rush, test_files, test_i18n, test_replay.
- tools/test_online.sh: GUEST ALL OK.
- test_determinism: runs to the end on both builds. The hashes differ from main from the 30 second mark, as they should: the computer's choices changed. Not chased, as asked.
- Godot ends some test runs with exit 134 after ALL PASS. That is the engine aborting at shutdown, on main too.

## What is left

- The machine in the bay is the unit's own sprite, darkened and cut. A painted "being assembled" frame per machine would look better.
- The brass plate, the spring mark and the gear view's colours are code-drawn. They are listed in docs/art_style_inconsistency.md.
- The Heavy Works' big ring is large. On a crowded plateau the computer can lay it late. Watch for it in games.
- The tempo numbers are guesses: 15% for the Light Works, 10% for the Escapement and the Aviary, and the turret's two screws.
