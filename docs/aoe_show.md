# Area attacks you can see, and the Clockwork's "+N" (0.14.49, branch `aoe-show`)

The owner asked for two things. First: "I wish the effect of the cut would be a bit longer, so it shows that it is a
sweeping attack. And maybe we could see on the ground the area of effect as well, just like we can see the cone of the
canister or the line of the round shot. I think most area of effect should show, it's just fair." Second: "When the
Clockwork's resources are mined, show on top of the building a plus and the number of the resource got."

## The Pendulum's sweep, longer

Each blow now leaves a SMEAR in game space, drawn over the units at the Pendulum's feet (Game.swipe_marks,
GroundMarks._smear): a cold steel-blue crescent along the blade's low path, squashed flat like the ground, from the side
the arm swung from (the right arm from its right, the left from its left) across the front to past the middle. Its head
runs on a little through the follow-through in the first 0.14 s, its tail draws in as it fades, and it lingers 0.38 s
after the hit. It is thick at the head (16 px) and thin at the tail, with a bright outer edge over a thin dark line, so it
reads on grass and over a target flashing white. It sits on top of the sprite's own smear (the one in the attack
frames), which is still there. The hit timing and damage are unchanged; the hit frame is not held longer (the blow's
timing is tested and the smear already carries the sweep). GIF: art/redraws/pendulum_sweep_ingame.gif (three blows
against Raptors in the Clockwork Lab, zoom 2.5, 30 frames a second).

## Area marks on the ground

Every area attack lays the real shape of its blast on the ground at the moment it strikes: the same geometry the damage
uses (a plain circle where the code measures a plain distance, the squashed oval where it uses Game.in_ellipse). The
mark is a see-through fill and an edge in the effect's colour over a thin dark line, under every unit and building (z
-16: over the gears and fields), and it fades out in 0.45 s. Things that land later first lay a WARNING where they will
land, for as long as they are in the air: a blinking outline with a fill that grows as the shot comes down (the
fairness the owner means: you see it coming and can step out). Clouds and storms that stay a while keep a faint edge
for as long as they last, after a short flash when they appear.

Rules:

- Who sees a mark (Game.mark_seen): the side that made it, always (it aimed there; a Mortar's BOMBARD ring already
  shows that), and anyone whose side sees that ground now (the fog of war, not just ground seen once). A shell landing
  in the fog on the enemy's ground shows the defender nothing until their side sees it. With no fog drawn (FOG: OFF,
  watching with all vision) every mark shows.
- Online: the host sends each mark with the snapshot's effects (NetSession.note_mark, an `"g"` entry: shape, place,
  direction, sizes, colour key, time, flags, team) and the guest lays it by its own fog (play_fx calls Game.area_mark,
  which never sends again from a puppet). A lasting cloud's edge survives the guest's snapshot merging (NetSnapshot.merge
  keeps `"g"` entries with the zone flag, and `"f"`). That is the whole net change: two entry kinds and one line in
  merge.
- Cost: the two GroundMarks nodes process and redraw only while they hold marks (set_process off when empty); a mark is
  a few polygons. Nothing happens per frame when nothing is striking.
- Settings > AREA MARKS (on by default, saved in settings.cfg) turns them all off, the smear too. A mark is still sent to
  online guests when the host has them off (the guest's own setting decides).

| Area effect | Faction | Mark | Colour | Timing |
| --- | --- | --- | --- | --- |
| Pendulum blow | Clockwork | wedge from its feet, 62 px, 60 deg either side (Pendulum.in_arc) + the smear | steel blue-white | 0.45 s (smear 0.38 s) |
| Ticking Owl's bomb | Clockwork | WARNING ring (32 px, its building radius) while it falls, then the ring | brass | the fall (0.3-0.6 s), then 0.45 s |
| Thresher's cleave (old roster) | Clockwork | ring round its target (THRESHER reach) | steel | 0.45 s |
| Steam Walker's jet (old roster) | Clockwork | wedge (its range, the 0.72 cone) | steam white | 0.45 s |
| Stormcaller's storm (old roster) | Clockwork | oval edge (STORM radius) | storm blue | the storm's time |
| Storm Engine's storm (prototype roster) | Clockwork | oval edge | storm blue | the storm's time |
| Heavy Loco's shell (prototype roster) | Clockwork | ring (its splash, through Game.explode) | brass | 0.45 s |
| A battery carrier's battery bursting (old economy) | Clockwork | ring, 34 px | storm blue | 0.45 s |
| Canister | Crown | wedge from the muzzle (CANISTER range + 30, its cone) | powder orange | 0.45 s |
| Round shot | Crown | band along the line it ploughs (30 px short of the spot to ROUND_SHOT line past it) + the small splash ring | powder orange | 0.45 s |
| Mortar shell | Crown | WARNING ring (its splash) while in the air, then the ring | powder orange | the flight (0.8-1.8 s), then 0.45 s |
| Keg / Powder Wagon going up | Crown | ring (KEG / WAGON radius) | powder orange | 0.45 s |
| A cannonball's plain splash (Projectile fallback) | any | ring (Game.explode) | orange (brass for the Clockwork) | 0.45 s |
| Spore Mother's spit | Brood | WARNING oval (its splash, squashed as the damage) while in the air, then the oval | acid green | the flight (0.5-1.2 s), then 0.45 s |
| Bloater's burst | Brood | ring (the burst), then the gas cloud's oval edge | acid green | 0.45 s; the cloud's time |
| Miasma | Brood | oval edge | violet | the spell's time |
| Mist Toad's Fog | Brood | oval edge | fog grey | the fog's time |

Not marked, on purpose: single-target attacks that only look like area ones. The Netter's net catches one unit (the net
in flight already shows where it goes); the Tesla's and the towers' chain lightning jump from target to target (the
bolts show each jump); a Brute's blow hits one enemy and shoves it; the Spitter's acid and the Mist Toad's tongue are
single shots. The Spring Catapult is not in the game yet (only tools/catapult_guide): when its shot is added, its
launch should call `area_mark(..., life = flight, warn = true)` and its landing a plain `area_mark`, one line each, like
the Mortar.

## The Clockwork's "+N"

A Cog Press presses cogs and a Mainspring winds Tension a little every tick: a "+N" every tick would be a stream of
"+0" and "+1". So each building sums what came in and shows one "+N" over itself every few seconds
(Building.pop_income, Defs.GEAR "pop"): a Cog Press every 4 s ("+32" with a full small-gear crew: 8 cogs a second), a
Mainspring every 6 s ("+12 tension" with a full small crew: 2 a second), in brass and spring blue, in the float_text
style of the Farm's "+N harvest" and the grub's "+N" at the capital. Nothing shows while nothing comes in (an empty
press, a Mainspring whose Tension is full). The Ore Train's "+N" per delivery (rail economy) was already there.

Only the owner sees them (Game.own_float: your own buildings, never a computer's or an enemy's, never while watching a
demo), as for the Farm. Online the host's game was the only one to show these numbers: a friend never saw the harvest,
the grub's drop or the train's "+N" over their own buildings. Game.own_float now sends a guest's own numbers to that guest
(NetSession.note_float, an `"f"` entry), so the Farm, the grub, the Ore Train, the Cog Press and the Mainspring all show
for whoever owns them, host or guest.

## Tests

- tools/test_aoe_show.gd (new): a Pendulum blow lays its wedge (62 px, 60 degrees, toward its foe) and the smear (0.3-0.4
  s, still there 0.2 s later); the marks fade and the nodes stop processing once empty; an enemy Mortar shell on our
  ground lays a warning, then the ring of its splash where it lands; a shell into the fog on the enemy's ground lays
  nothing for us, in the air or when it lands; a canister lays its cone; a Spore Mother's spit a warning oval and an oval
  where it lands; AREA MARKS off lays nothing; a working Cog Press shows "+N" every few seconds, not every tick; an
  enemy's press shows us nothing; our Mainspring shows one "+12 tension" in 8 seconds of 2 a second. ALL PASS.
- Still passing: test_pendulum_v2, test_cw_tier3, test_cw_tier3_ai, test_gear_ai, test_gear_econ, test_gear_graph,
  test_gear_levels, test_gear_mesh, test_gear_placement, test_gear_press, test_gear_save, test_gear_swap,
  test_gear_unlinked, test_gear_winddown, test_attack_ground, test_ground_attack, test_i18n, test_hotkeys, and
  tools/test_online.sh with a Crown, a Brood and a Clockwork guest (HOST ALL OK, GUEST ALL OK each).
- test_determinism runs to the end. Its HASH lines differ between two runs of the same build, but they differ the same
  way on origin/main (two runs of main diverged at 30 s; this branch's second run matched main's first line at 10 s):
  that unevenness is older than this branch. The marks use no random numbers and change nothing the hash reads.

## Pictures

tools/shot_aoe_show.gd (in the Clockwork Lab, xvfb) writes docs/shots/aoe-show/:
pendulum_wedge.png (the wedge and the smear just after a blow among Raptors), mortar_warning.png (an enemy shell in the
air: the warning ring over a Musketeer squad), mortar_land.png (the ring where it burst), spore_spit_warning.png and
spore_spit_land.png, cog_press_plus.png (a Cog Press's "+32"); and the GIF's frames.

## What may need a second look

- The wedge is the Pendulum's real hit area, a plain circle sector 62 px out, so on the ground it looks taller than the
  low, flat smear; the smear is the picture of the blade, the wedge the picture of the danger.
- The smear is code-drawn (logged in docs/art_style_inconsistency.md); a painted sweep strip could replace it.
- Mark colours and alphas are first guesses: watch them on snow, sand and the Brood's swamp.
