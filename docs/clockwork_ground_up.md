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
