# Clockwork, built from the ground up (design in progress, started 2026-10-25)

Owner's decision: restart the faction design from zero; every building and unit must be justified. Nothing here is built yet. Everything built so far (Line, trains, Lab units) is prototype material to keep or cut by these rules.

## Lore
A brilliant Crown scientist built the best clock machine. It went rogue, lost control and began to replicate. The Clockwork is that ever-growing clock machine spreading across the land. It is mindless: no want, no thought, no hatred of the Crown in particular. It just spreads, ticks and clocks. The Clocktower is the blueprint of the original machine, the thing that replicates.

## Rules from the lore
1. Spreading is the game: strength grows with the ground it covers; everything extends from the Clocktower.
2. Mindless means copies: cheap, similar units from the same parts, made in rhythm; no heroes, no morale.
3. A clock runs down: constructs need winding (wind-down away from the machine is the natural weakness).
4. It eats the land: ore and metal from the ground are what it copies itself from (resource: ore, which runs out).
5. Every building and unit must answer: why does a spreading clock machine have this?
Self-unfolding buildings (a crate unfolds and builds itself) fit the lore.

## Decided
- Clocktower: makes the copy-workers (Winders); takes in the ore; holds the blueprint (unlocks the other buildings; a new Clocktower extends the spread, it unlocks nothing new). Not decided: supply, more than one Clocktower, defence (suggested: tough, does not shoot).
- Worker: ONE kind only, the Winder (builds by carrying a crate that unfolds; works the Drill for income per worker; winds and repairs). It CAN fight (owner). All factions' workers share one speed (the Labourer's 74) for balance. Numbers match the Crown Labourer for now (cost 50, 46 hp, 12 s); worker counts of 40-70 in a late game are a later balance pass.
- Winder look (art + animation, owner picked): clock-face head with turning hands, winding key on the back, ticking steps (small jerky one-second beats like a second hand), working on the beat (hammer, hammer, pause), squat pocket-watch body. Art request to ChatGPT is written once the faction look is settled.
- Winder's one job is WINDING (owner, 2026-10-25). Every Clockwork building has its own winding key that keeps it going; the Winder winds it: building (winding a construct until it assembles), repairing, working a Drill or any resource building are all the same action, winding. Its attack is winding too: it takes the key off its back and tries to wind the enemy (flavour for a melee hit). Animations needed: idle (done), walk (done), WIND (one animation for all work), attack (key off the back, wind the enemy), death. The earlier mallet "work" idea is dropped.
- Winder art status: idle (art/redraws/winder_idle_v2.png), walk (winder_walk_v2.png), wind (the ChatGPT sheet; arms stiff, a code-drawn crank overlay is planned), attack (winder_attack_v3.png, owner accepted as the best we will get), death still to do. Importing into the game happens once all sheets are in.
- Winder death sheet received (art/redraws/winder_death_v2.png, 6 frames x 5 directions). All Winder sheets are in; import into the game is the next code job.

## Decided (2026-10-26)
- Resource: COGS. Winders wind a cog-making building (name to pick: Cog Press / Gear Mill / Cog Forge / Ratchet Loom); farms-make-gold logic: it produces cogs, not ore. Numbers later.
- Rails and trains are SHELVED for now (owner asked what the faction can be built on, based on clocks).
- GEAR FIELD replaces the blue (Protoss-like) energy field: real gears in the ground that turn and mesh with each other, so the whole base becomes one visible machine. Very unique; owner loves it.
- Ticks and chimes: a rhythm, with benefits for following it, but NEVER punishing (missing the timing must not lose the game).
- Winding and running down: possibly a massive winder, like the Crown's powder wagon, a logistics unit that keeps the army fighting longer (still to decide).
- Time effects: slow fields yes; NO haste (Stim Pack danger); a specialised unit that stops ONE unit (like the Ghost's Lockdown in StarCraft 1).
- Winders are needed because a mindless machine can't tune itself: a cog press turns and pays a small trickle by itself (like a farm with nobody on it), and each Winder who keeps the mesh tight adds the same amount, up to a limit. Income is per second, not a bar that fills.
- Cog sizing: ONE connecting gear per building, small or big. Small = turns fast, works faster, fewer Winders. Big = turns slow, more torque, more Winders and more at full crew. Visible on the ground (small gears visibly spin faster). The player may swap a building's gear later for a small cost.
- Units: aim at the Protoss roster as a scaffold (not to copy everything, only something to aim for). Clock Soldier (Zealot-like basic melee): sword is a clock hand, shield is a pocket-watch cover. Cuckoo is a flying unit.

## Second resource: Tension (owner, 2026-10-26)

- Power is dropped as a resource: the gear field already is the power. Steam and electricity are looks only (a puff of steam from a press is fine), never resources. The theme is clockwork, springs, weights, pendulums.
- Main resource: cogs (cog presses, Winders in the crew). Second resource: TENSION, the wound spring that Winders store. A Mainspring building takes a Winder crew and fills a reserve.
- Tension is spent on the strong things (top-tier units, slow field, the stopper unit).
- Buildings that use Tension must be placed ADJACENT to a Mainspring (owner idea): this makes building interlocking a core mechanic. Suggested: adjacency is through meshing gear rings, so it joins the Cosmoteer-style placement puzzle (one system, not two). Open: ports per Mainspring, chains or one hop only, what happens when the Mainspring dies.

## Production buildings (owner, 2026-10-26)

- Barracks = the MOVEMENT WORKS (concept art/redraws/concepts/barracks_movement_works.png): a workshop that assembles clockwork soldiers on a hanging line. Open: the giant winding key on the roof (who winds it? the owner finds it too big for Winders).
- The CUCKOO HOUSE (concept art/redraws/concepts/barracks_cuckoo_house.png) makes the FLYING units (the Cuckoo).
- The Glockenspiel turntable concept (art/redraws/concepts/barracks_glockenspiel.png) is not chosen for the barracks; the "building turns with its ring" idea stays open for other buildings.
- The soldiers in the concepts give a first Clock Soldier look: clock-face chest, small crown spike, blue joints, pocket-watch-cover shield, clock-hand sword.

## Clock Soldier (owner, 2026-10-26)

- Tier 1, kept simple for now: a plain melee front-line unit from the Movement Works, cogs only, no special trait yet (closing shield, wound charge or ticking strikes stay ideas for later upgrades).
- Look: squat pocket-watch body, clock face on the chest, small crown spike, blue joints, clock-hand sword, pocket-watch-cover shield; heavier than the Winder.

## Supply: the Regulator (owner, 2026-10-26)
- Supply building = the REGULATOR: a squat 2x2 regulator clock with a pendulum behind glass (art/redraws/regulator.png). Lore: every unit runs in step with a regulator's beat; each keeps only so many in time. Kept SQUAT on purpose so it never reads like the tall Cuckoo House.
- Floor plate under every building (art/clockwork/gear/floor_plate_src.png): the ring turns around a fixed bolted deck.

## Tier 2 built (0.14.19): the Escapement and the Jack
- ESCAPEMENT: the tech building (3x3, 150 cogs, needs a Movement Works), unlocks the Jack, researches HIGH LEAP. Tension rule (owner): a building that uses Tension must have its ring mesh DIRECTLY with a Mainspring's ring (one hop; an idler between the two counts), else it stands idle (NEEDS MAINSPRING); if its Mainspring dies it goes idle until one meshes again. This answers the open questions above: one hop, any number of users per Mainspring, idle (not lost) when the Mainspring dies.
- JACK (the spring jumper below): 100 cogs + 25 Tension, 2 supply, ranged screws at ground and air, hops, JUMP (crouch, arc up to 5 tiles, 10 s); up a cliff after HIGH LEAP (150 cogs + 100 Tension) and only where you can see. Numbers are guesses (docs/clockwork_gear_prototype.md).

## Spring jumper unit idea (owner, 2026-10-26)
- Jumps on flat ground (no upgrade); jumping UP onto high ground needs an upgrade (owner, 2026-10-26).
- A unit standing on a coiled spring (like the Mainspring's cone spring) that JUMPS: onto enemy units and up onto high ground when it has vision there (the Stalker's Blink role).
- Suggested by Claude, not decided: name Jack (jack-in-the-box) or Springer; tier 2 (needs the Escapement), costs cogs and Tension; the jump coils the spring (visible crouch) before the leap so it can be read and answered; cooldown; RANGED (owner, 2026-10-26): its right arm is a drill-like launcher that SHOOTS SCREWS (the screw tip is the bolt).
- Art: the cone spring rings already painted for the Mainspring can be the unit's leg (pressed flat when crouching, stretched in the air).

## Defence: the Ratchet Turret (owner, 2026-10-26)
- Static defence: a squat 2x2 base on its gear ring with a separate head that turns to aim and fires big screws (the Jack's screw art). Hits BOTH air and ground (owner: the Clockwork needs it).
- Built (0.14.17, numbers are guesses): 125 cogs, 450 hp, 1 armour, needs the Movement Works; 14 damage every 1.5 s (about 9 a second, a Musketeer's 7 and a bit), range 200 px (a Musketeer's 190; cannons and mortars out-range it), ground and air; linked only. Power (Boiler, Charging Pylon, batteries, energy) is gone from gear mode.

## Air: Cuckoo and Ticking Owl (owner, 2026-10-26)
- CUCKOO (from the Cuckoo House): AIR-TO-AIR flyer.
- It can be UPGRADED into the TICKING OWL: a nasty flying GROUND attacker (like a morph). Owl attack (owner): SWOOPS DOWN with its talons against units, DROPS its pendulum-weight BOMBS on buildings. Upgrade (owner): research it once, then each Cuckoo is morphed into an Owl individually (cost and time per unit).
- Display names (owner, 2026-10-26): the flyer is the SWIFT and its building the CLOCK AVIARY in English (Portuguese and Spanish keep the cuckoo: Cuco, Casa do Cuco / Casa del Cuco); the ids stay cuckoo and cuckoo_house.
- Built (0.14.21; numbers are guesses, docs/clockwork_gear_prototype.md "The air"): the Clock Aviary (2x2, 175 cogs, needs a WORKING Escapement to be placed), the Swift (75 cogs + 15 Tension, 2 supply, air-to-air peck), TICKING OWL (150 cogs + 150 Tension) then MORPH TO OWL per Swift (100 cogs + 50 Tension, 20 s), the Owl (220 hp, 4 supply, talon swoop on units, a falling bomb on buildings, no hits on flyers).

## Tier 3, next (2026-10-26, not decided)
- NO MAGIC in the setting (owner, 2026-10-26): every effect must be mechanical and physical (no time-freezing, no glowing spells). The earlier "time effects" (stop one enemy, slow field) must be built from machinery: nets, clamps, chains, harpoons, caltrops, grease.
- The STOPPER (the owner's "unit that stops one enemy, like Lockdown"), three grounded concepts sent: the NETTER (a spring cannon firing a weighted chain net: the target cannot move or fight for a few seconds; nets can bring a flyer down), the CLAMPER (lobs a spring-loaded iron clamp that snaps shut on the target's legs: it cannot move but can still fight; not vs flyers), the WINCH HARPOONER (a barbed hook on a chain and a locking winch: holds the target on a leash and can drag it in).
- The owner likes the NETTER (2026-10-26): the Stopper is a spring cannon firing a weighted chain net.
- AREA DAMAGE (the old Steam Walker / Storm Engine role, now without steam or electricity), three concepts sent: the PENDULUM (a heavy walker swinging a giant pendulum blade in a wide arc: melee cleave), the COG MORTAR (lobs a canister that bursts over an area in spinning cogs and screws: ranged splash), the MAINSPRING BOMB (a wind-up crawler that runs into the enemy and its spring bursts out: suicide splash).
- Still open: the slow field (mechanical: spiked caltrop cogs, grease), the heavy Grandfather, the Great Winder.

## Readability rule (owner, 2026-10-26)
- Problem (owner): every Clockwork unit so far is a red round body with a clock in the middle: hard to tell apart.
- Rule (proposed): every unit has its OWN SILHOUETTE (size class and outline: round, tall and thin, wide and low, drum, tower, flyer) and its OWN BODY MATERIAL by role (melee = red case; ranged = polished brass; control/support = dark iron; heavy = tall tower); the team red becomes an ACCENT (bands, plates, a sash) on most units instead of the whole body; the big white clock face on the chest is the CLOCK SOLDIER's alone (other units show time another way: a small gauge, a dial on the head, a pendulum, a gear); each unit's weapon is big and readable.
- First concept of the Netter (art/redraws/concepts/netter_v1.png) broke the rule (red ball body with a chest clock). The NETTER v2 (art/redraws/concepts/netter_v2.png) is chosen (owner): a wide, low dark-iron drum on four short legs, red only as two bands, a small gauge on the end cap, the spring cannon on a turning collar on top.
- The JACK stays as it is (owner): its hopping makes it distinctive enough.

## The Pendulum (owner, 2026-10-26)
- Chosen as the Clockwork's MELEE AREA DAMAGE unit (concept art/redraws/concepts/pendulum_v1.png): a tall clock-tower body on two long legs, a big clock face at the top, a pendulum with a heavy bob and a crescent scythe blade that swings in a wide arc and hits everything in front of it. Its tower silhouette on long legs sets it apart from the Clock Soldier even though it keeps a red case and a clock (a tower clock, the heavy role).
- Open: tier and producing building, cost (cogs + Tension?), numbers (slow, tough, cleave arc).
- Art plan: a 5-direction sheet with the pendulum drawn separately; the swing and the idle sway are done in code by rotating the painted pendulum about its pivot (like the flywheel); the walk later.

## Names (owner, 2026-10-26)
- The air-to-air flyer is the SWIFT and its building the CLOCK AVIARY (English). "Cuckoo" read comic in English (crazy; the cuckold bird). Portuguese keeps the cuckoo ("Cuco", "Casa do Cuco"), the owner finds it fine there; Spanish does the same ("Cuco", "Casa del Cuco"). Internal ids and art files keep "cuckoo".

## Under discussion (owner, 2026-10-26)
- NO ZEPPELIN: the Swift and the Ticking Owl are the Clockwork's two air units (the Brood has two; the Crown's Balloon is strong enough alone).
- Next units: the SPRING CATAPULT (throws its own melee units, Clock Soldiers and Pendulums, into the enemy: area damage where it lands, the thrown unit is hurt too; concept prompt sent) and a CASTER (no magic). Caster options sent: Great Winder (Rewind repairs an ally; Overwind: hit harder now, run down after), Tinker (caltrops, grease, spring trap), Surveyor (flare, mark).
- After those two, the new Clockwork goes into the real game (it replaces the prototype roster).
- REASSEMBLY (owner idea): machines can be taken apart and rebuilt as another unit in the field, after a research, while Winders nearby work on them; a hotkey on the unit. Pairs suggested: Clock Soldier <-> Jack, Swift <-> Ticking Owl, Netter <-> Catapult.
- SWEEPER (owner idea): one unit that is both a big winder (a winding area for the army) and a sweeper that collects every body around it, Crown, Brood and Clockwork alike. It denies the Brood's harvest and the Missionary's resurrection. What the bodies give back is open; it must not be resurrection (that is the Crown's).
