class_name PatchNotes
extends RefCounted
## What each version changed, newest first (the PATCH NOTES page in Settings shows the entry of
## the running version first). Add an entry for every pushed version (see CLAUDE.md).

const NOTES := [
	{"v": "0.15.1", "items": [
		"GREAT WINDER IN A CROWD: when soldiers stand round a wreck so the big machine cannot roll right over it, it now sweeps it from the edge of the crowd after a second, instead of pushing at them for good (the computer's Great Winder sometimes never swept a soldier that fell in the middle of its army). If it cannot get near at all for 6 seconds, it leaves that wreck for 10 seconds and sweeps another.",
	]},
	{"v": "0.15.0", "items": [
		"BIGGER MAPS: every built-in map is larger, about 1.3 times on each side (1.75 times the ground). The classic maps (Greenhold, Highmoor, Dune Sea, Frostfang, Twin Fords, Ashfall, Mirewood, Border March, Red Coast) go from 84 x 60 to 110 x 80: the walk from main to main is about 110 tiles, close to a minute for a Musketeer. The team maps grow by the same factor; the 1v1 maps that already had a long walk grow a little less (Saltmarsh Isles, Frostmere, Hollowfen, Thornwood Maze, Ashford Crossing, Amberfall Vale). Ramps, rivers and tree walls keep their width; the main plateaus are a little bigger.",
		"MORE BASES: every map has more base sites, the same for every player (the maps are still turned through their middle). Each side's natural sits close to its main, in front of its ramp; then 3 or 4 more sites per side in corners, beside ponds and lakes and in pockets. On Greenhold (the owner's drawing): the natural moved up to the foot of the main's ramp, a new site in the bottom-left corner and one just right of the bottom-left pond, plus one along the top and one on the open ground below it. With 4 players the classic maps have two sites per corner. Each site has a hall's full reserves, for the Crown and the Clockwork.",
		"Replays and a saved match of a built-in map from before 0.15.0 can't be shown or resumed (they were played on the old, smaller map). Your own maps keep their size; a new map in the editor starts at 110 x 80, and the editor's sizes go up to 256 x 256.",
	]},
	{"v": "0.14.104", "items": [
		"TURNING GEARS (an EXPERIMENT, the owner's idea, on by default for now): only the outer toothed band of a Clockwork building's gear ring turns; the plate in the middle stays still. Any ground unit standing on a turning band is carried round with the teeth, about a tile a second, and meshed rings turn opposite ways. A unit that stays on the band keeps going round: idle units and units on HOLD ride until you move them off. A unit walking across drifts sideways for the time it is on the band and still gets where it was sent.",
		"Workers at work (Winders going to a press, a building site, a repair) walk straight in across the band and are never carried. Flyers, limbered guns and the big machines (Field Cannon, Spring Ballista, Great Winder) are not carried either. The computer walks its own idle and HOLD units off a band after a second. A carried unit kicks up a little dust; point at a band, or open the GEAR VIEW, to see gold chevrons running the way it turns.",
		"To switch it off: Settings > TURNING GEARS (experiment) > OFF. It applies from the next match: a match keeps the rule it started with, and an online game and a replay follow the host's.",
	]},
	{"v": "0.14.103", "items": [
		"GREAT WINDER SWEEPS WRECKS INTO COGS (the owner's rule: each side gets something different from bodies; the Brood essence, the Crown raises its own, the Clockwork regains cogs). Standing idle, it rolls to a Clockwork wreck near it (yours, and the enemy's in a Clockwork mirror match), sweeps it up with its rollers and gives you 30% of that unit's cog price at once (\"+21 cogs\" for a Clock Soldier; no Tension back), then rolls back to where it stood, so it stays with the army. It leaves a wreck alone while an enemy soldier is near it. No more parts: the hopper, the 100 cap and the planned reassembly are gone. Its winding ring and MEND are unchanged, and the computer's Great Winder sweeps the same way. Old saves still load.",
	]},
	{"v": "0.14.102", "items": [
		"The game is now called Working Title for RTS for the time being (the old name belongs to another game). Your settings, saves, replays and hotkeys carry over; the web address and the Android app file keep their old names for now, and the app installs over the old one.",
	]},
	{"v": "0.14.101", "items": [
		"NEW COG PRESS ART (the owner's drawing): the Cog Press is now an open iron gantry press facing south-east, a stamping ram inside the frame and a crate of fresh cogs at its feet, so it no longer looks like the Mainspring. Its red bars take your side's colour. While Winders wind it, the ram falls fast onto the cog in its tray, holds for the stamp and climbs back slowly (a 12-frame loop). New pictures for the press being built (on scaffolding), damaged and destroyed, and a new portrait.",
		"COG PRESS STAMP: a quiet, heavy stamp sounds as the ram hits the cog (cut from the owner's two stamp recordings, pitched down with a little iron under it). Only presses you can see are heard, on every other stroke, and a row of presses never drums: at most one stamp in 0.7 s.",
	]},
	{"v": "0.14.100", "items": [
		"CLOCKWORK COMPUTER against Horsemen: the Winders near a raided Cog Press, Mainspring or Clocktower band together and all hit the same rider instead of scattering (riders are faster than them: running only fed them one by one), the nearest Clock Soldiers come as one group to the Winders instead of chasing a rider, and once it has seen riders and has 10 or more Clock Soldiers at home, 3 or 4 of them stand on HOLD at the top of its ramp. Against Balloons, and armies they cannot fight, the Winders still run.",
	]},
	{"v": "0.14.99", "items": [
		"BLACK POWDER SMOKE: every powder shot now leaves its smoke on the field. A Musketeer's or Guardsman's musket (a Dragoon's too, once off his horse), a Horseman's pistol, a Field Cannon (round shot and canister), a Mortar and its bursting shell, a keg or a Powder Wagon going up: each leaves grey-white puffs that drift slowly on a light wind, grow, thin and fade over 10 to 24 seconds (a cannon's last longest). A long firefight builds a haze over the firing lines that clears slowly afterwards. It is only for the look: it hides nothing and changes nothing in the fight, the units stay visible in it, and their health bars, rings and orders are drawn over it. You see it only where your side sees the ground. The Clockwork and the Brood fire no powder.",
		"POWDER SMOKE in Settings: OFF, LIGHT, FULL or THICK (experiment). LIGHT has fewer puffs with shorter lives. It applies from the next match.",
		"THICK (an EXPERIMENT, the owner's, and the default for now on every platform): the smoke is drawn OVER everything on the field, the units, their health bars, the selection rings and the order lines (still under the interface, the minimap and the menus), a third denser and lasting a quarter longer than FULL. It is meant to be a bit annoying, as a real powder battle was. It is still only for the look: it hides nothing from your side's sight and changes nothing in the fight. To go back: Settings > POWDER SMOKE > FULL (a choice you made before is kept).",
	]},
	{"v": "0.14.98", "items": [
		"TAKING THE REINS has its own moment now: a man told to LEAD a horse stops at its head for half a second and reaches for the bridle, the horse stops and turns its head to him, the rein appears, and then they walk off together (a pause at each horse when he fetches several). The rein is easier to see: tan leather with a dark edge. Mounting is unchanged: a soldier right-clicked on a horse still gets on it; LEAD (Q) is how a soldier leads one. Labourers lead on a right-click.",
	]},
	{"v": "0.14.97", "items": [
		"CLOCKWORK GEAR RULES (the owner's, from the gear study): each RATCHET TURRET now claims a circle of ground 4 tiles round it, and two turrets' circles may not overlap: a turret's spring draws all the force from the gears under it, so turrets stand at least 8 tiles apart. While you place one, the circles are drawn and the ghost says TOO NEAR A TURRET. Old saves keep the turrets they have.",
		"NEW CLOCKWORK BUILDING, the HEAVY WORKS (175 cogs, 45 s, needs a working Escapement): a gantry crane yard where the PENDULUM, the SPRING BALLISTA and the GREAT WINDER are now made, and you can watch each machine rise in its bay as it trains. It sits on its BIG gear only and uses Tension, so its ring must mesh with a Mainspring's (else NEEDS MAINSPRING).",
		"The LIGHT WORKS now makes only the light machines: the Clock Soldier, the Springer and the Netter (no more Pendulums, Ballistas or Great Winders).",
		"SIZE SETS THE TEMPO: a small gear works fast and light, a big gear slow and strong. The Light Works trains 15% faster on its small gear, 15% slower on its big one; the Escapement and the Clock Aviary work 10% faster or slower. A Ratchet Turret on its small gear fires 11 damage every 1.2 s; on its big gear 21 every 2.2 s, better against armour, with the same reach. Each card says its gear's trade in one line.",
		"READABILITY: the Mainspring, the Escapement, the Heavy Works and the Clock Aviary stand on a polished brass floor plate; a small spring mark shows a building fed by a Mainspring; the placing ghost lights its meshing teeth green and its clashes red and gives its reason in one red line; the GEAR VIEW (the ` key, or GEAR VIEW on a Clockwork building's card) shows the whole network: the drivers gold, every ring green to red by how well it works, each Mainspring's reach and the turret circles.",
		"CLOCKWORK COMPUTER: it lays a Heavy Works by a Mainspring as soon as its Escapement works (its first Spring Ballista, then its Pendulums), keeps room for it by its first Mainspring, and spaces its turrets by the new rule.",
	]},
	{"v": "0.14.96", "items": [
		"HORSEMEN AND CUIRASSIERS ATTACK ON THE MOVE, like the Cyclone: on any order (move, attack-move, attack, patrol) they strike an enemy in sabre reach as they ride past, on their normal reload and at full damage, without slowing or stopping. A plain move still goes where you sent them, cutting down what they pass.",
		"Told to attack a unit or a building, a rider rides AT it, strikes in passing, rides on a little and swings round its far end for the next pass, instead of standing beside it. A man on the run is ridden down. His one pistol shot is fired from the gallop too (on an attack or attack-move).",
		"HOLD POSITION, or stopped on guard, a rider stands and fights as before. Walls and gates are still hacked at standing. The Cavalry Charge doubles only the first blow after a gallop (no blow for 5 s, then 2 s at the gallop), not every pass. The Dragoon is unchanged.",
	]},
	{"v": "0.14.95", "items": [
		"EXPANSION SPOTS: the best places to expand are now marked on every map, as a few ground tiles in warm gold where a new Town Hall or Clocktower fits. Each side gets its best spot (a little brighter) and the next one, picked for the room to build round it, few ways in, a short walk from home and distance from the enemy. Both sides of a map get the same. They show for the Crown and the Clockwork (not for the Brood, which rarely moves its capital) and when watching, as small gold squares on the minimap too, and a touch brighter while you place a hall. A spot hides once a building you know of stands on it. Settings: SHOW EXPANSION SPOTS turns them off.",
		"FIX: on the classic river maps (Twin Fords, Mirewood, Border March) the fords were a few cells wider on one side than the other. Now both sides match.",
	]},
	{"v": "0.14.94", "items": [
		"Officers, Horsemen and Cuirassiers wear white coats and team-colour breeches, with a team-colour saddle cloth: easy to tell from Musketeers.",
	]},
	{"v": "0.14.93", "items": [
		"Getting on a horse and leading it now sound different: the horse whinnies when a man gets on it, and only snorts softly when a man takes it by the reins. The message from 0.14.92 is gone (it got old fast).",
	]},
	{"v": "0.14.92", "items": [
		"A soldier right-clicking a horse gets on it (Musketeer to Dragoon, Officer to Horseman...). Now a message says so and how to lead it by the reins instead: press LEAD (Q). Labourers still lead a horse on a right-click.",
	]},
	{"v": "0.14.91", "items": [
		"The Great Winder rolls on cog wheels instead of legs. Four brass cogs, the Clockwork's own wheel (as on the Spring Catapult and the Spring Ballista), turn as it moves, at just the speed it goes, and stand still while it mends or sweeps. When it is destroyed its wheels come off. Its speed is unchanged (27): it is still slow on purpose.",
	]},
	{"v": "0.14.90", "items": [
		"FIX: a Gate laid over part of a planned palisade now replaces only that piece (its price comes back); the rest of the wall stays planned and its Labourers carry on with it. Before, the whole planned wall, and the gate, could vanish. Over a wall being built or a built wall, the gate still takes just that one piece.",
		"FIX: a drag let go over the buttons or the minimap now ends there. The right-drag line no longer keeps following the mouse after its button is up (and the same for the box select, the middle-button map drag and a finger lifted over a button).",
		"CLOCKWORK COMPUTER: it no longer sends a Clocktower into your base. A new Clocktower goes only on its own side of the map, never nearer your halls, your main or your natural expansion than its own main; and where it lost a Clocktower or its crate, it does not try that ground again for four minutes.",
	]},
	{"v": "0.14.89", "items": [
		"FIX: a man getting on or off his horse, and a gun limbering or unlimbering, stays selected and in its control groups, and you can click or box-select it all the while (a click on him getting on picked the hidden horse). An order you give meanwhile waits: he finishes getting on (or off), then carries it out, and Shift-queued orders follow it.",
		"FIX: Shift + PATROL now queues the patrol: a unit on the move finishes the move, then patrols between where it ended and the point you clicked (it used to drop the move). The PATROL mode stays on while Shift is held, and the planned patrol shows from the end of its orders.",
	]},
	{"v": "0.14.88", "items": [
		"The Clockwork's Movement Works is now called the LIGHT WORKS (it makes the light machines; the Heavy Works for the big ones is coming). Its build key is L.",
	]},
	{"v": "0.14.87", "items": [
		"Clockwork build keys: the Clocktower is now T and the Cog Press C (the Cog Press's G looked like a C, and C built a Clocktower you could not afford).",
	]},
	{"v": "0.14.86", "items": [
		"The Crown's buildings have terracotta roofs.",
	]},
	{"v": "0.14.85", "items": [
		"FIX: Clockwork buildings go up out of their crate again. Only the Clocktower showed the crate: the Cog Press, Mainspring, Regulator, Movement Works, Ratchet Turret, Escapement and Clock Aviary jumped straight to their scaffold. Now every one shows the crate the Winder set down opening up and unfolding into its frame, for you and the computer alike.",
		"Clockwork buildings now BUILD UP: after the crate unfolds, the scaffold rises out of its plates from the bottom as the building goes up (all of it by half way), then the finished building stands.",
	]},
	{"v": "0.14.84", "items": [
		"The match log now records every building or button the game refused you, with the reason and the resources you had at that moment, so a refused build can be traced afterwards.",
	]},
	{"v": "0.14.83", "items": [
		"NEW CLOCKWORK UNIT, the GREAT WINDER (Movement Works, once an Escapement works; 175 cogs and 75 Tension): the Clockwork's big, slow, walking winding machine, with no weapon. It does the job the Winders walking with the army did, as one machine.",
		"WINDING: every Clockwork soldier near the Great Winder (the ring on the ground when it is selected) slowly winds up, so an army off the gear ground no longer runs down beside it, and run-down soldiers there wake up again. It never runs down itself.",
		"MEND (automatic, press to switch off): standing about, it mends the most hurt Clockwork unit near it with its key arm, one at a time and half again as fast as a Winder (it costs cogs, like a repair). Right-click a hurt unit to send it there.",
		"SWEEP (automatic, press to switch off): with nothing to mend, it sweeps up the wrecks of your own Clockwork units with its rollers and keeps them as PARTS (up to 100, shown on its card). Parts do nothing yet: they are for rebuilding machines in the field, later. It never sweeps Crown or Brood bodies.",
		"The Clockwork computer builds one Great Winder once it can and sends it behind its army; fewer of its Winders go with the army while it does.",
	]},
	{"v": "0.14.82", "items": [
		"Internal: the Springer's files and ids renamed from Jack; old saves and replays still load.",
	]},
	{"v": "0.14.81", "items": [
		"CLOCKWORK COMPUTER: its tech now comes on time. On Hard the Mainspring and the Escapement stand by about 4:00, so its first Springers, Netters and SHIELD WALL are out for the first big fight. It makes sure a Movement Works can make Springers (a Mainspring beside it, or a Works beside a Mainspring), keeps its cogs for the tech under a raid it can beat, and spends its Tension instead of leaving it at the cap. Its army is about one Springer for every one and a half Clock Soldiers, with a few Netters and Pendulums.",
		"CLOCKWORK COMPUTER SIEGES: its Springers and Netters shoot and net the workers mending a wall or gate first, then the shooters on the edge, while the Clock Soldiers hit the gate, and its reckoning of a siege counts that. Against a walled enemy its first attack waits for four Springers (two on Normal). With HIGH LEAP its Springers jump up onto the high ground when the enemies by the landing are worth less than they are. A siege going worse than it reckoned, or a wave that keeps losing far more than it kills, is called off, all the way back to the rally.",
		"CLOCKWORK COMPUTER TARGETS: it goes first for what it can reach without breaking a wall: an expansion, farms, outlying buildings (not a spot right under a walled plateau's guns). On Hard its Netters net fighters rather than workers, its Pendulums walk into knots of enemy soldiers, and badly hurt Clock Soldiers step back to a Winder to be mended.",
		"FIX: a unit given a new order while its blow was landing skipped its reload. A Netter given an order every second fired a net every second (its reload is 14 s). Now the reload always follows the blow, for every unit and every player.",
	]},
	{"v": "0.14.80", "items": [
		"NEW CLOCKWORK UNIT, the SPRING BALLISTA (Movement Works, once an Escapement works; 150 cogs and 50 Tension): a bolt thrower on cog wheels whose giant screw flies in a straight line THROUGH its target into one or two enemies behind it. Hard on armoured units and buildings (a wall or gate stops the bolt), weak up close and against swarms. No set-up: it fires as soon as it stops, and on the move at what is ahead, but its spring is wound again only while it stands.",
		"The Spring Ballista has a Winder built in. Up to 4 more Winders can BOARD it (LOAD CREW on the Ballista, BOARD on the Winders, or right-click it): each makes it reload and move 10% faster. They push it and crank it beside it, and they can be shot. UNLOAD CREW sets them down. The computer builds a couple and crews them with its escort Winders.",
		"When a Spring Ballista is destroyed, its bow snaps, a wheel comes off and the spring bursts out of its drum (the owner's painted wreck).",
	]},
	{"v": "0.14.79", "items": [
		"Brood: a new DEMOLISH button (a talon striking down on a split mound), so it can no longer be mistaken for BUILD; the Bloater's SPIT button now has its own picture, the Bloater spitting acid.",
	]},
	{"v": "0.14.78", "items": [
		"WINDERS have new art for carrying a building's crate: they walk with it held out in both hands, stand with it, and bend down to set it on the ground before it unfolds into the building, in every direction.",
	]},
	{"v": "0.14.77", "items": [
		"A Winder walking away from you with a building's crate now shows it over his head (it is in his hands in front of him), instead of hiding it behind his back.",
	]},
	{"v": "0.14.76", "items": [
		"WINDERS carry a building's crate out in front of them in their hands (it was on their backs), and at the site they lower it to the ground in front of them before it unfolds into the building.",
	]},
	{"v": "0.14.75", "items": [
		"The Clockwork's jumping screw-shooter is now called the SPRINGER (it was the Jack): the name says what it does, a soldier on a spring.",
	]},
	{"v": "0.14.74", "items": [
		"PATHFINDING, THE HIGH GROUND: a click on the edge of a plateau now means the top. Before, a click on the rim often counted as the low ground under the cliff, and the whole group walked down the ramp and round to stand in a heap at the foot of it. A line drawn along a cliff edge puts everybody on top too, each man on his own spot.",
		"PATHFINDING, GROUPS AT AN EDGE: a group sent near a cliff, a wall or a building spreads out on the side you clicked. Before, every man whose place in the group fell over the edge was sent to the exact spot you clicked, and they piled up there against the cliff.",
		"PATHFINDING, NO WAY THERE: a unit sent where it can't go (up a cliff with no way round, into a walled base) walks to the nearest place it can reach and stops. Before, it walked on from there straight into the cliff or wall and pushed at it for good; computer scouts did this for minutes under the enemy base.",
		"MELEE AND THE HIGH GROUND: Raptors, Brutes and other fighters no longer run to the foot of a cliff under an enemy they can't get at. With a wall or gate in the way they go and break it; with no way at all they leave him and look for another fight. A Raptor or Brute circling its prey no longer picks a spot below the cliff edge either.",
		"CORNERS: a unit that walks into a corner (a step in a cliff, the corner of a building) slips round it instead of stopping dead, and big units (Horsemen, Brutes, Pendulums, guns and wagons) plan their paths a little further from corners. Details and numbers: docs/pathfinding_audit.md.",
	]},
	{"v": "0.14.73", "items": [
		"CROWN COMPUTER, coached over 32 games against the Clockwork and the Brood computers: after a Horseman opening it no longer holds its Labourers at eight for ten minutes (its Horsemen now count as defenders); an ordinary Clockwork Movement Works is no longer taken for a rush (two of them early still are); it expands in time (a fresh Town Hall for every 16 Labourers, three at most) instead of waiting until its main is barren; it does not lay a new Town Hall again and again on a spot its builders were just chased from; and when powder piles up while gold runs out, Labourers go back from the Powder Mills to the farms.",
	]},
	{"v": "0.14.72", "items": [
		"Behind the scenes: a test switch that lets a computer's siege play out to the end, used to check when the computer should call an attack off. Nothing changes in play.",
	]},
	{"v": "0.14.71", "items": [
		"CLOCKWORK COMPUTER: its Winders now go with the army, at the rally point and on the attack, about one for every five soldiers. Out there they wind the soldiers up (the run-down ones first, then the lowest), and mend them second, and fetch soldiers left run down on the way. The Winders that go are extra hands: the presses keep theirs. Before, two Winders followed an attack and never wound a Clock Soldier, so a long march left half the army standing still.",
		"COMPUTER SIEGES: an army breaking in at a gate now gathers and queues on the side it can walk up to (down the ramp below a ramp gate), not at the foot of the cliff beside it, under the muskets on the high ground.",
	]},
	{"v": "0.14.70", "items": [
		"FIXES from a long test run of every map and mode: a Brood computer no longer places a Clutch Mound and drops it again every second while raiders stand near its grubs (it waits a little before trying again); a Brood swarm no longer calls its whole wave off when one of its Raptors is eaten or otherwise gone; a soldier raised by a Missionary who had been on his way to a horse no longer breaks his next order; a building whose rally point followed a unit that turned into something else (a grub that became a building, a man who mounted) lets go of it cleanly; and the dismounted Cuirassier walking east no longer asks for a picture that is not there.",
	]},
	{"v": "0.14.69", "items": [
		"GUARDSMAN: facing down the screen, he now aims and fires at you, the muzzle toward you and the flash in front of his chest, and thrusts the bayonet at you. Now every way the Musketeer and the Guardsman face, they fire that way.",
	]},
	{"v": "0.14.68", "items": [
		"GUARDSMAN: facing up-right, he now aims, fires and thrusts the bayonet that way, his back to you. His south view comes next.",
	]},
	{"v": "0.14.67", "items": [
		"GUARDSMAN: facing down-right, he now aims, fires and thrusts the bayonet that way, like the Musketeer. His up-right and down views come next.",
	]},
	{"v": "0.14.66", "items": [
		"WEB: closing the tab, reloading the page or swiping the browser away no longer shows THE GAME CLOSED UNEXPECTEDLY the next time you open the game. A real crash is still reported.",
		"MAP EDITOR: BACK, SAVE, LOAD, HELP and the other buttons work again after you paint with a mouse, and BACK works with a tap on a phone (the editor ate the button's click).",
		"SCREENS THAT RAN OFF THE EDGE: PATCH NOTES wraps its lines and fits a phone; MATCH LOGS and the crash report sit on a panel and wrap; the in-game MENU fits a phone held sideways and its volume bars no longer run through their words; the INTERFACE LAYOUT hotkey list no longer has its note drawn over it; long dropdown labels (RANDOM 2V2 MAP) shrink to fit instead of being cut; IDLE / ARMY / MAKE shrink further on a phone (PRODUCIR, EJÉRCITO).",
		"REPLAYS in Portuguese and Spanish: the players' names show in your language (they said \"P1 Crown (you)\", \"(easy AI)\" in English).",
	]},
	{"v": "0.14.65", "items": [
		"MUSKETEER: facing down the screen, he now aims and fires at you: the musket points toward the viewer, the flash bursts in front of his chest and the smoke rolls toward you, and his bayonet thrusts toward you. With the down-right and up-right views of the last version, every way he can face now fires the way he faces (the left-hand views are mirrors).",
	]},
	{"v": "0.14.64", "items": [
		"FAIR STARTS: on Jade Wilds with four Clockwork players, the two corner bases got their first Cog Press 9 tiles from the Clocktower and the two middle bases 7.5. A starting building one lane in from the edge of the main now counts as hugging it, so every base gets the same 7.5. Starting Farms, Feeding Pits and Cog Presses may sit a little closer to the main building on other maps too; every map was checked and is fair.",
	]},
	{"v": "0.14.63", "items": [
		"MUSKETEER: facing down-right or up-right, he now aims, fires and thrusts the bayonet that way. Before, every view pointed its musket to the right, so a line firing down the screen shot sideways. The new frames were painted one direction at a time over guides made from his own frames. The south and the Guardsman come next.",
	]},
	{"v": "0.14.62", "items": [
		"ONLINE, EVERY ORDER ANSWERS AT ONCE for the friend who joins: not only moves now. Units told to attack turn to the target and start walking into range; stop and hold stand them still at once; a building site appears where you placed it, faint and outlined until the host confirms it, and the worker heads for it; the cost and the supply show as spent; a trained unit, a research or a hall upgrade goes into the queue (drawn faint until confirmed) with its progress bar running; cancelling takes it out with the refund shown; the rally flag, hold fire, auto-train, deploying or packing a gun, cancelling a site or pulling a building down all show on the click. The host still decides everything: a moment later its game takes over, without a jump, and an order the host refuses (not enough gold, a blocked spot) is taken back at once with the reason.",
		"ONLINE, THE HOST'S OWN ORDERS (with \"Same delay for both players\"): they still wait half the ping, but the queue, the resources and supply and a building site show at once, and the units turn at once, as on the friend's screen.",
	]},
	{"v": "0.14.61", "items": [
		"BROOD ANIMATIONS: Raptors and Grubs no longer hop when they turn up or down the screen or stop (those walks stood 2 px above the ground). The Raptor's run plays faster (12 frames a second, was 8), so its feet skate less. A hovering Skywing beats its wings at a real pace (was 2 frames a second), and its east attack no longer shows a frame with only a wing.",
		"BROOD ANIMATIONS: the Mist Toad's death plays to the end: its body now lies flat instead of freezing half fallen. A Grub's wrapping takes as long as the wrap itself: the cocoon closes just as it picks it up, for small and big bodies alike.",
		"TEAM COLOUR: the Brood Queen's crest and the Clutch Mound's frills are now in your colour (they were red for every player), and the thin red rims on Brood crests and frills follow the team colour too. Veteran Raptors walking up or down the screen now show their veteran skin on their legs.",
	]},
	{"v": "0.14.60", "items": [
		"BROOD MUSIC: ten new pieces, so the Brood has twenty like the Crown, each with its own moment. Two open a match while the swamp wakes, tense under the calm: The Brood Wakes and The Hive Gathers. Three play in a lighter fight, a hunt held back from the kill: Something in the Water, The Scent of Blood and Circling. Three are the full battle, the swarm at full cry with big drums, the throat choir, brass and strings: The Swarm at Full Cry, The Queen's War-Song and Ten Thousand Mouths. Two are calm and slow: The Queen's Lullaby and Night over the Drowned Wood. The Queen Stirs may now open a match too.",
		"THE HIVE CALL: the new Brood pieces share a short theme of six notes (a low note, a leap up, then a sigh down to the start). A flute sings it plainly in the lullaby, the skirmishes chase it in broken pieces, and in the battles the whole choir roars it in long notes.",
	]},
	{"v": "0.14.59", "items": [
		"JACK: it keeps both drill launchers when it hops and jumps. Before, its left launcher turned back into the old claw every time it moved. The hop and the jump are now made from the same painting as its standing and shooting, so nothing changes shape between them. (Its death and its shot up at a flyer still show the claw until they are repainted.)",
	]},
	{"v": "0.14.58", "items": [
		"CLOCKWORK MUSIC: ten new pieces, so the Clockwork has twenty, like the Crown. They share one short theme, the Clockwork's motif: a tick and a tock, then a note left hanging. A music box plays it plainly in the calm pieces, the machine repeats it and shifts it in the skirmishes, and the whole orchestra hammers it in the battles. Their percussion is made of real clocks, an old clock bell, metal clangs, a typewriter, a crank and a spring.",
		"OPENING pieces (the first minutes of a match): The Great Escapement and Calibration. SKIRMISH pieces (a small fight): Tick, Tock, Alarm; The Watchful Gear; Pressure Rising. FULL BATTLE pieces (when the fight grows): Cathedral of Gears; Anvil Chorus of a Thousand Hands; The Grand Calculation. CALM pieces: The Clockmaker's Lament and Canon of Perfect Order. The calm Winding the Spring may now also open a Clockwork match. All of them are in the music player.",
	]},
	{"v": "0.14.57", "items": [
		"JACK: it no longer slides about on its spring while it stands. Its foot plate now stays on the spot in every frame and every direction, so switching between standing, shooting and hopping no longer makes it jump sideways (up to 6 pixels before). The screws still leave from the drill tips.",
		"CLOCK SOLDIER: facing right, the frame just before its sword comes down no longer loses its head cap, so its player colour shows all through the swing. A few stray dark pixels near its feet are gone.",
		"CLOCK AVIARY: while it works, only its doors and the little brass bird move. Before, every frame was painted anew, so the whole tower shimmered and it changed look when it started or stopped.",
	]},
	{"v": "0.14.56", "items": [
		"CROWN ANIMATIONS, small fixes from an audit of every Crown animation (docs/animation_audit_crown.md): the Officer and the Armoured Officer no longer hop as they walk (their walking feet now stay on the ground, as when they stand), and the Armoured Officer no longer floats a little when he aims and fires. The Horseman's horse no longer bobs up when it stops facing down and to the right. The Messenger galloping right no longer shows two or three riders in two of its frames. The Mortar's crew no longer jumps from side to side while the gun waits. The Mounted Missionary gallops at a gallop's pace (its horse slid along in slow motion). A stray dash under the Musketeer's muzzle is gone.",
	]},
	{"v": "0.14.55", "items": [
		"CHECKED: every automated test of the game was run (118), the files were checked against each other (every unit animation strip, building picture, icon, sound and requirement: a new test of 1,026 checks), and the README brought up to date (each Feeding Pit's own ground, replays). Two old tests that did not know the newer rules were updated; the game was right.",
		"FIX: every match tried to load a picture that no longer exists (an old walking frame of the Armoured Officer) and logged an error for it; that leftover is gone. The Android app no longer packs the retired units' art.",
	]},
	{"v": "0.14.54", "items": [
		"CLOCKWORK SOUNDS from the owner's recordings of real clocks and machines (a typewriter, an alarm clock, an old clock bell, a crank, a spring, metal clangs). The Clock Soldier, Jack, Swift, Ticking Owl, Pendulum and Netter now answer in their own machine voices when picked or ordered: typewriter keys for the Clock Soldier, a spring's boing for the Jack, quick high ticks and a little bell for the Swift, slow low ticks for the Owl, the old clock bell and a heavy crank for the Pendulum, a crank cocking the spring cannon for the Netter.",
		"CLOCKWORK FIGHTING: bright clangs for the Clock Soldier's sword, heavy low clangs for the Pendulum's blows, a ratchet spin for each screw the Jack and the Ratchet Turret shoot, a typewriter key for the Swift's peck, a clang for the Owl's talons. The Jack's spring presses, boings and clanks as it jumps and lands; the Netter's spring lets go when it fires and the chain net rattles where it lands; the Owl's weight lets go with a wobble and lands with a heavy clang. Every Clockwork unit (the Winder too) dies with a crash of metal, pieces rattling down and a spring letting go.",
		"CLOCKWORK BUILDINGS each have their own sound when picked: the Clocktower's old bell, a crank turning for the Cog Press, a spring for the Mainspring, ticking for the Escapement and (slower, with a soft bell) the Regulator, clangs for the Movement Works, a ratchet for the Ratchet Turret, high ticks and a ding for the Clock Aviary. A Winder working a Cog Press is heard cranking it; building and repairing is a click and a clang; the crate is a real ratchet.",
		"CLOCKWORK ALARM: when your Clockwork units are attacked an alarm clock rings (and rings again, after a tick, when your buildings are attacked), instead of the bell and drums the other factions keep. Research done rings the old clock bell once; a building finished slides the typewriter's carriage back and rings its bell; a unit ready turns a ratchet and rings the bell. MORPH TO OWL turns a crank, and the old bell rings when the Owl is ready.",
	]},
	{"v": "0.14.53", "items": [
		"CLOCK SOLDIER: a little quicker (speed 68, was 62) and lighter (75 health, was 90). These numbers are a first guess.",
		"SHIELD WALL, a new research at the Movement Works (100 cogs + 50 Tension, 45 s; it costs Tension, so only at a Works whose ring meshes with a Mainspring's): every Clock Soldier gets SHIELD FORWARD (key F). The soldier raises its shield in front of it (half a second, standing still): it walks 40% slower and swings a little slower, but has 1 more armour, takes half the damage from shots coming from the front and a fifth less from blows from the front. Nothing against blows from the side or behind, nor against splash. Press it again to lower the shields. With the shields up a squad wins a stand-up fight against shooters it used to lose, but it can no longer catch a Musketeer who walks off, and running away it takes far more. Raised shields show: the shield is carried in front of the body. Works online and in saved games.",
		"CLOCKWORK COMPUTER: it researches SHIELD WALL once it has met an army of shooters, raises its Clock Soldiers' shields as they walk into ranged fire, and lowers them to chase a shooter that walks off or to fall back.",
	]},
	{"v": "0.14.52", "items": [
		"AREA MARKS: area attacks now show where they strike, the way the canister's cone and the round shot's line show before a cannon fires. At the moment of the blow a see-through mark of its real shape lies on the ground for about half a second, under the units: the Pendulum's wedge in front of it, a canister's cone, a round shot's line, the ring of a Mortar shell, a keg or Powder Wagon going up, an Owl's bomb, a Bloater's burst, the oval of a Spore Mother's spit. Shells and spit that land later (a Mortar shell, a Spore Mother's spit, the Ticking Owl's bomb) first show a blinking warning where they will land, filling in as they come down, so you can see it coming and step out. Clouds that stay a while (a Bloater's gas, Miasma, a Mist Toad's fog, storms) keep a faint edge for as long as they last. You see a mark only where your side sees the ground (or your own side's). AREA MARKS in Settings turns them off.",
		"PENDULUM: its blade leaves a cold steel smear along its low sweep, from the side it swung from across its front, that lingers about a third of a second after each blow, so it reads as a sweep at any zoom. The hit timing and damage are the same.",
		"CLOCKWORK INCOME YOU CAN SEE: a working Cog Press shows a \"+N\" over itself every 4 seconds with the cogs it pressed, and a Mainspring a \"+N tension\" every 6 seconds while it winds, like the Farm's harvest and the grub's drop at the capital. Only the owner sees them. Online, a friend now sees the numbers over their own Farms, grubs, Cog Presses, Mainsprings and Ore Trains too.",
	]},
	{"v": "0.14.51", "items": [
		"REPLAYS: every match is recorded, a skirmish, a match between computers you watch and online, and the REPLAYS button on the main menu lists them, newest first, with the date, map, players (name, faction, colour, team), your result, length, game version and size. A replay is not a video: it keeps what was on the map five times a second, so while it plays you move the camera anywhere, select units and buildings to read their health, orders and queues, look through any player's fog or see everything, follow the camera of a player who recorded it, and watch at half speed up to 8x, with pause and a timeline to jump to any moment. The chat comes at its times, and the top bar shows every player's resources, supply, income per minute, army value and workers. On a computer: Space pauses, + and - change the speed, Home goes back to the start.",
		"REPLAYS ONLINE: the host's game records every side; when the match ends the host sends the whole replay to each friend (\"Sending it to your friend: 40%\" on the end screen), never before, so nothing hidden by the fog travels during the match. Until it arrives, or if you leave early, a friend keeps a replay of what it saw itself, marked YOUR VIEW ONLY.",
		"REPLAYS are kept on the device: the newest 30 that you have not marked KEEP stay (Settings > REPLAYS KEPT), DELETE removes one, EXPORT saves a file (in the browser, a download) and IMPORT plays a file a friend sent you. The end screen says \"Replay saved\" and has WATCH REPLAY. A replay from another version of the game still plays, with a note that some things may look different; a unit that no longer exists is shown greyed. A match closed in the middle keeps its replay up to its last few seconds.",
		"MAIN MENU in two rows (one row got crowded with REPLAYS): ONLINE, SKIRMISH and REPLAYS on top; HOW TO PLAY, EDITOR, MATCH LOGS and SETTINGS below.",
	]},
	{"v": "0.14.50", "items": [
		"HOLD has its own picture for the Clockwork (a brass shield with a blue steel arrow pointing down) and the Brood (a shield of hide and bone with a yellow arrow pointing down), the same idea as the Crown's shield, so HOLD reads the same in every faction.",
	]},
	{"v": "0.14.49", "items": [
		"NEW ICONS, painted: buttons and portraits that borrowed the Crown's pictures or were cut from the sprites. The CLOCKWORK: portraits of the Clock Soldier, Jack, Swift, Ticking Owl, Pendulum, Netter and Winder; its own BACK, CANCEL, DEMOLISH (a gear in pieces), PATROL (a swinging pendulum), RALLY, WORK, MORE and ATTACK GROUND (a clock hand striking the ground); SMALL GEAR and BIG GEAR, JUMP, MORPH TO OWL, and the HIGH LEAP and TICKING OWL research; and a wound mainspring for TENSION in the top bar. The BROOD: its own BACK, CANCEL, DEMOLISH, PATROL (claw prints), RALLY (a skull totem), WORK, MORE, TONGUE, TAKE OFF and ATTACK GROUND (a Spore Mother's lob). The CROWN: ATTACK GROUND (a cannonball landing in a red ring), TEAM (two harness horses), MORE (a page turning), RESTOCK, AUTO REFIT and the Mortar's DEPLOY. HOLD keeps the Crown's shield for now: the Brood's and the Clockwork's are being drawn.",
		"HORSE BREEDER: picking it plays hooves trotting with a horse neighing over them (three takes), instead of the Crown's usual building sound.",
	]},
	{"v": "0.14.48", "items": [
		"THE NEW PENDULUM: the Clockwork's tall clock tower now has two arms instead of a blade hanging between its legs, each a brass rod ending in a heavy weight with a crescent blade. It attacks forward and its arms cut in turn, right then left: each blow is a LOW SWEEP, like a scythe mowing at ankle height: the arm swings back behind its hip, then sweeps forward and across just above the ground in front of its feet, the blade's edge first, through every enemy on the ground in the wide arc in front of it (Raptors, Labourers and the like stand right in its path), and follows through low past them. New look in every view (standing, walking, attacking, dying) and a new card portrait.",
		"PENDULUM BALANCE: lighter, quicker blows (12 damage every 1.4 s, one arm at a time, instead of 22 every 2.6 s: about the same damage a second), and light units (Musketeers, Labourers, Raptors and the like) take half as much again from each blow. These numbers are a first guess.",
	]},
	{"v": "0.14.47", "items": [
		"CLOCK SOLDIER: its sword is now in its right hand and its shield on its left arm whichever way it faces. Turned toward the lower left, left or upper left it no longer swaps them (those views were the right-facing ones mirrored): it has its own west-facing drawings, so facing left you see the shield in front with the sword's blade beyond it, and facing right the sword. Its walk, attack and death in those three views are made from the new drawings: the sword arm, now on the far side, swings partly behind the body.",
	]},
	{"v": "0.14.46", "items": [
		"BODIES HAVE HEALTH AND ROT: a body has the health its unit had in life (a rider's adds his horse's, who lies with him) and loses it at one speed for everyone, twice as fast with every minute it lies: a Raptor's lasts about 1:20, a Labourer's or a grub's 1:35, a Musketeer's 2:00, a Horseman's with his horse 3:15, a Brute's 3:30, a Pendulum's 4:00. This replaces the fixed times (2 minutes with the Brood in the match, 30 seconds without), so it is the same in every match. The thin bar over a body is its health. Hitting a body takes health off and makes it go sooner; a body brought to 0 is torn up: the Brood can't harvest it and a Missionary can't raise it (who still raises a fallen soldier within 60 s, as before).",
		"ATTACK GROUND (Ctrl+A, the button was BOMBARD): now for every unit that can attack, not only cannons, mortars and Spore Mothers: shooters, melee units and workers (Labourers, grubs, Winders) too. Click a spot and everyone attacks it (melee units and workers take the bodies within a tile and a half of it); hold the left button and drag a line, as with the right-drag formation, and the line is shared out among them, each its own stretch, with a preview while you drag. A short drag is a click; Shift queues it. Shooters fire along their stretch, at the bodies on it while there are any: a shot lands where it is aimed and hits an enemy standing there, else the nearest body, else the ground, and spends powder as usual. Melee units and workers walk up and strike the bodies on their stretch, new ones too, and wait when there are none; workers hit softly and take longer. They keep at it until you give another order: hold a lane of fire if you like. A Mortar shell, round shot, canister or spit blob fired at the ground hurts every body in its blast (10 times its damage: it still tears up most bodies at once; a Pendulum's needs two). Ordinary fire at enemies still leaves the bodies alone. Works online and in saved games.",
		"HARVEST: a grub wraps a small body quickly and a beefy one a little longer: about 0.9 s for a Raptor, 1.2 s for a Musketeer, 2 s for a Horseman with his horse, 2.2 s for a Brute, never more than 3 s.",
	]},
	{"v": "0.14.45", "items": [
		"BROOD COMPUTER plays better. It keeps adding Grubs while it builds its army (it stopped at 9 whenever the enemy army it saw was bigger, so its income stood still), and keeps its eggs for the army once it has enough. It is no longer stuck at the supply limit with biomass in hand: Clutch Mounds go up ahead of need. Its Brood Pen goes up at about minute 5 (it often came at minute 6 or 7, or never), it offers up a few spare Raptors there and harvests the bodies after a fight, so Spitters join the Raptors, and an egg waits for a Spitter's biomass instead of always hatching Raptors. A second Burrow goes up when its eggs, not its biomass, hold the army back.",
		"BROOD COMPUTER attacks with judgement. It remembers the enemy soldiers it has seen and does not attack into an army clearly stronger than its own (it defends and builds up instead); when it has seen nothing of the enemy for a while it first sends two Raptors to look; and an attack that is clearly losing pulls back home instead of fighting to the last Raptor. Two enemy Horsemen hunting its Grubs are answered by the Raptors as a pack.",
	]},
	{"v": "0.14.44", "items": [
		"FIX (online): with the Jack's two launchers (0.14.35) a friend's game read every unit's values one place off after the new value, and stopped updating its units; it reads the Jack's launcher now, and the online test checks that the lists match.",
		"ONLINE: the automatic online test now plays every kind of order a friend gives (move, attack-move, a line, hold, stop, hold fire, bombard, rally, train and cancel, auto-train, gather, a hall upgrade the host refuses with its reason, demolish), the chat both ways, a pause and its resume, and a surrender from either player, in a 1 vs 1 with each faction and in co-op (where a friend who surrenders is out and the match goes on for the host).",
		"ONLINE: the ping counter keeps its place left of the clock (under it when a phone's top bar has no room for it), and the zoom gauge steps aside instead of covering the clock.",
		"ONLINE ROOM: a refused colour's words stay for a moment, then the room's line comes back.",
		"ONLINE MENU AND PAUSE are two things now: MENU (top right) opens the menu over the running match, with PAUSE, the volume sliders, the music player, SURRENDER and QUIT TO MENU (both asked twice online) and BACK TO THE MATCH. PAUSE stops the match; online either player can pause it for both (3 pauses each, at most 2 minutes each, then a 3, 2, 1), and both screens say who paused. The same in a skirmish.",
		"MUSIC PLAYER in the in-game MENU: the piece playing and how far into it, NEXT, and a list of every song to pick from (your faction's first). A picked song plays to its end, then the music follows the match again. Only on your own screen.",
		"ONLINE, SAME DELAY FOR BOTH PLAYERS (a switch in the room, on by default): the host's own orders wait as long as the friend's take to reach the host's game (half the ping, at most 250 ms), so neither side reacts faster. The click is answered at once on both sides (the ring, the voice). The match log says how long they wait.",
		"ONLINE, THE FRIEND'S UNITS ANSWER AT ONCE: on the friend's screen, units told to move or attack-move start walking at the click instead of a round trip later, then blend into where the host's game has them, without a jump.",
		"ONLINE, SMOOTHER: the host sends a picture every two game ticks (15 a second), fewer in a big battle or on a slow uplink (only what changed is sent), and the friend's screen shows the units a little behind the newest picture, from a buffer sized to how unevenly the pictures arrive, so they walk at an even speed.",
		"ONLINE, PING: a counter left of the clock (green, yellow, red) shows the round trip to the other player; \"Waiting for the host...\" shows when no picture has come for a second; a host whose browser tab or app goes to the background pauses the match for both. The match log has an online line every minute (ping average and highest, this device's leg to the relay, pictures, orders sent, run and refused, stalls) and notes stalls and hidden windows.",
		"ONLINE: the chat reaches the other player both ways; the ring where you click shows only on your own screen (the friend's at once); an order the host refuses tells the friend why.",
		"ONLINE ROOM: a friend who joins says hello again every 2 seconds until the room arrives (a room that sat empty on \"Waiting for the host...\"), the host sends the room again, the room shows the ping, and after 8 seconds with no answer it says so (and keeps trying).",
	]},
	{"v": "0.14.43", "items": [
		"SMOOTHER LATE GAME: big matches run faster, and play exactly the same (a computer-vs-computer match with the same seed plays out move for move as before). Measured on The Sundered Realm, 2 against 2, at 18 minutes with about 250 units: the game does about a quarter less work per second of play, and stutters (frames slower than 33 ms) are about five times fewer. The biggest savings: the selection card (a selected Town Hall or soldier fitted its info line letter by letter 20 times a second: frames of up to 70 ms), the fog of war (half the work), the computer players and the buildings (a quarter less), and the search for nearby units.",
	]},
	{"v": "0.14.42", "items": [
		"BROOD GROUND, A CIRCLE PER PIT: every Feeding Pit now has its own ground, 3,000 biomass in a circle 5 tiles round it; its grubs draw on it load by load, and a spent pit yields nothing. The Burrows (the capital too) have no ground any more: the capital is still the only drop-off and the Queen's seat. Your pits' circles may not overlap (their centres stay 10 tiles apart: about 4 or 5 pits fit on a main plateau). While you place a pit you see the circle of every pit of yours, the ghost's own circle (green where it fits, red where it would overlap, with the pit it clashes with in red) and what ground it would get; a refused spot says why (\"Too close to another Feeding Pit: their grounds would overlap.\"). A selected pit shows its circle and \"Ground: %\" on the map and on its card, and each pit warns for itself when it runs low. The ground belongs to the land: a pit that dies leaves its circle as dim old ground with what was left, and a new pit over old ground takes over the smallest amount left there, so rebuilding beside a spent pit can't refresh it. One more grub per pit: the base crew is 6 (was 5), still +1 for every 4 tiles beyond 6 from the capital, up to 12. The computer keeps to the circles, prefers fresh ground and replaces spent pits farther out on its swamp.",
	]},
	{"v": "0.14.41", "items": [
		"ESSENCE: the +1 essence a harvested body gives for each kill it made now stops at 50, the same 50 kills veterancy counts (it had no cap).",
	]},
	{"v": "0.14.40", "items": [
		"BROOD ESSENCE: SACRIFICE pays much better: a creature offered up at a Brood Pen gives 35% of its biomass cost as essence (9 a Raptor, was 3; 53 a Brute). The Brood Pen no longer turns bodies that fall near it into essence by itself; the fallen, friend or foe, are harvested by grubs, and a harvested body is worth more: 2 essence for each point of its supply (was 1.25), plus 1 for each kill it made (a Musketeer 2, a Horseman with his horse 8).",
	]},
	{"v": "0.14.39", "items": [
		"WEB VERSION LOADS FASTER: the first visit downloads about 60 MB instead of about 145 MB, and after an update usually only about 2 MB. The game is split into a small code pack and an art pack that only downloads again when the art changes; the browser keeps both (and the engine) for the next visit. The music no longer comes in the first download: each piece downloads when it is first played (the menu and match music start a moment later the first time) and is kept too. A new loading screen in the game's colours shows how far it is. The Android app is unchanged (everything inside it) and a little smaller.",
	]},
	{"v": "0.14.38", "items": [
		"CLOCKWORK ECONOMY (gear mode; the study: docs/clockwork_economy_study.md). TENSION is a full resource now: every Mainspring STORES 200 Tension (400 on its big gear, which takes up to 6 Winders and winds 2.6 a second); winding stops when you hold what your Mainsprings store (the top bar reads held / stored), and nothing unwinds. Buildings can cost Tension: the CLOCK AVIARY is 150 cogs + 50 Tension (a cancelled site gives it back; the computer pays it too).",
		"EFFICIENCY: every working Clockwork building shows its % over it and on its card: its crew share times its DRIVE. The Clocktower and every Mainspring drive the gear field: a building meshing with one works at 100%, each ring farther out 10% less (at least 70%); an idler costs nothing. Drive sets a Cog Press's cogs, a Mainspring's winding and the speed of training and research (not supply, the Ratchet Turret or building). The placement ghost shows the % before you place (LINKS 90%), and a Mainspring's ghost how many buildings it would feed (FEEDS 2).",
		"THE TENSION RULE grows: anything that costs Tension is made only at a building whose gear ring meshes with a Mainspring's. The Clock Aviary now stands idle without one (NEEDS MAINSPRING), like the Escapement, and a Movement Works makes Jacks, Netters and Pendulums only with a Mainspring meshing with it (its Clock Soldiers need none; the Pendulum still needs the big gear too).",
		"GEARS MESH ONLY ON THE SAME GROUND LEVEL: a ring on the high ground no longer links with one below the cliff, nor one at the top of a ramp with one at its foot, and no idler is put across a cliff. The placement ghost says NO LINK: OTHER LEVEL.",
		"BALANCE: the Clockwork earned about twice what the Crown did per worker, so a Cog Press now takes 6 Winders (big gear 12) for the same top rate: a Winder adds about what a Labourer adds on a Farm.",
		"The Clockwork computer puts its presses and Works on the Clocktower's ring, keeps room for a Mainspring beside its first Works, builds a Works by its Mainspring for Jacks and its Aviary by a Mainspring, and puts a Works that meshes with a Mainspring on its big gear for Pendulums. In the CLOCKWORK LAB the big-gear Works has a second Mainspring beside it, which also feeds the Aviary, and the Mainsprings start wound full.",
	]},
	{"v": "0.14.37", "items": [
		"LIMBERED GUNS no longer clip through walls or jam: a Field Cannon, Mortar or Powder Wagon on the move (its horse team drawn ahead of it) now keeps the whole team, not just the gun, off walls, palisades, buildings and cliffs. The gun itself is narrow enough for a one-tile gate; it lines up on the gate before it goes through and drives straight out the far side (one that stopped in a gateway carries on through instead of backing out), and at a wall end or a block of rock the team swings round it instead of pointing into it and sticking.",
		"HORSES NO LONGER VANISH INTO BUILDINGS: a horse taken for a Horseman, Cuirassier, Dragoon, Field Cannon, Mortar or Powder Wagon (standing at the building, kept at a breeder or led over by a Town Hall hauler) walks to its own spot beside the Barracks or Foundry and waits there HITCHED, in sight, where it can't be hurt or taken, until the recruit comes out: the rider mounts it there (on its coat and health as they are then) and the gun comes out drawn by it. Cancelling the recruit frees the horse where it stands. Before, it walked into the building and was gone (after 90 s even if it never got there).",
		"HAULERS: a Labourer leading a horse to a recruit whose building has a side shut in by a palisade or other buildings now goes round to a side he can reach, instead of walking at the palisade and standing stuck.",
	]},
	{"v": "0.14.36", "items": [
		"POWDER MILL WORK YARD: the mill's crew no longer stands stuck. The mill's front row is now its work yard, walkable like a Farm's fields (nothing can be built on it): the labourers dig at the three heaps, carry the loaded shovel along the front and tip it into the hopper, all inside the mill's own ground, so Cottages, walls or a cliff edge right against the mill no longer block them (with every open side of the yard built up, they go in through the shed). The six spread over the heaps and the hopper and keep a step apart instead of bunching at one side, always shovelling or walking (no frozen poses), and they are drawn in front of the shed, heaps and hopper they work at.",
	]},
	{"v": "0.14.35", "items": [
		"CLOCKWORK COLOURS: every Clockwork unit is now brass and your colour, with no blue left. The Jack's body and shoulders are in your colour; the Clock Soldier is all brass except its head (the cap with the crown spike), which is in your colour, so the two are easy to tell apart. On the others the blue ball joints and wing springs are now in your colour. Steel stays steel (the Jack's drill tips are a plain steel grey now, not icy blue) and the clock faces stay white. The red parts no longer show orange streaks on other colours, and the Clock Soldier seen from behind no longer has the top of its head cut off.",
		"THE JACK now has two drill launchers and fires them in turn, a screw from each arm, each from its own tip. Its hop, jump and death still show the old claw arm until their new drawings arrive.",
		"THE SWIFT's peck is painted now: it brakes with its wings up, stabs its beak forward and down, and pulls away; the blow lands on the stab.",
		"THE PENDULUM's death seen from behind and from the back three-quarter view is painted now (it was a rough sketch).",
		"THE CLOCK SOLDIER is drawn about 30% smaller (about a Musketeer's size, well under the Jack), and its body is smaller to match (radius 14 down to 10, a Musketeer's): it takes less room in a crowd and is easier to tell from the Jack.",
	]},
	{"v": "0.14.34", "items": [
		"NEW WINDER: the Clockwork's worker is the new clock-faced Winder in every view (standing, walking, winding, attacking, dying), in brass and the player's colour (his blue joints and red heart now show the team colour). He moves on a clockwork beat: ticking steps; his work goes hammer, hammer, pause with a small crank turning in his hands (at a Cog Press, repairing, and on the crate he sets down on a site, which he gives a few turns as it unfolds); the hands on his clock face tick once a second; and when he dies he runs down. New card portrait.",
	]},
	{"v": "0.14.33", "items": [
		"ART: the ESCAPEMENT's working loop redone. Its anchor now rocks on its pivot like a pendulum and, each time it swings through the middle, the escape wheel jumps forward half a tooth and stops: tick... tock..., a beat every half second (24 frames instead of 8). The wheel turns cleanly in its own plane (no more smeared, jagged spokes and teeth) and is evened out from its own painted pieces (12 teeth, 8 spokes); what it and the anchor uncover is the drum's own paint, not a flat dark fill, and the drum no longer has see-through holes. The idle building and its card picture show the evened wheel too, and its red panels no longer show specks of the player's colour.",
	]},
	{"v": "0.14.32", "items": [
		"FOG OF WAR: one grey only, as in StarCraft 2. The black fog over ground nobody had looked at is gone: the whole map's ground (cliffs, ramps, water, trees, rocks, the places to build a base) shows from the start under the grey fog, on the minimap too, and what your side sees is clear. The enemy still shows only once seen: its units while in sight, its buildings once spotted (then remembered under the grey as you last saw them), its swamp only where you have looked; smoke, shots and blasts on ground you have never looked at stay hidden. The same when you watch the computers through one player's eyes, and online.",
		"BUILD ANYWHERE: a building can be placed anywhere on the map, seen or not (no more \"Unexplored.\"). The worker walks there; if an enemy building you had not seen stands in the way when he arrives, the site fails as usual (\"Can't build there: the spot is blocked.\") and its cost comes back. Enemy buildings you have seen still block the ghost; ones you haven't do not show on it, nor on the build grid.",
	]},
	{"v": "0.14.31", "items": [
		"CLOCKWORK: only the rebuilt army in the live game. The old Assembly Works and its prototype units (Wind-up Soldiers, Thresher, Bulwark, Arc Thrower, Tin Militia, Scrapper, Rail Rifleman) can no longer be built or trained, and the SANDBOX's CLOCK tab lists only the new units and buildings: Winder, Clock Soldier, Jack, Pendulum, Netter, Swift and Ticking Owl.",
	]},
	{"v": "0.14.30", "items": [
		"ONLINE MATCH LOGS are kept: an online match left before its end (QUIT, a lost connection) now saves its log in MATCH LOGS, and the running log is kept as UNFINISHED OR CLOSED MATCH while you play, as in a skirmish.",
	]},
	{"v": "0.14.29", "items": [
		"CROWN BUILDINGS IN YOUR COLOUR: every flag, banner, pennant, awning and red cloth on the Crown's buildings now wears the player's colour: the Town Hall's striped market awning, the Horse Breeder's saddles and blankets, the Foundry's wall hangings and its workmen, the Armoury inventor's shirt, and the red edges of the banners (some of it was painted in a red that stayed red for every player). The Farm's windmill roof is terracotta now, no longer the player's colour. Bricks, fire, powder kegs, food and the Barracks' target stay as painted (the Foundry's forge fire and some of its bricks used to show the player's colour).",
		"The building you are placing shows your colour on its flags, like the building will.",
	]},
	{"v": "0.14.28", "items": [
		"ONLINE: the MENU opens again during an online match, so you can SURRENDER or QUIT. The match keeps running behind it (online nothing pauses); its first button is BACK.",
		"ONLINE: turning a phone upright no longer holds the match when you play online (a held host stopped the game for the other player too).",
	]},
	{"v": "0.14.27", "items": [
		"FIX: the gear rings under Clockwork buildings now stand drawn through the 3, 2, 1 countdown (in the Clockwork Lab, a skirmish or online) instead of popping in at GO.",
	]},
	{"v": "0.14.26", "items": [
		"FIRE AT A SPOT (BOMBARD): Ctrl+A (A is still attack-move) or the new BOMBARD button on their card, then a spot on the ground: the Field Cannons, Mortars and the Brood's Spore Mothers in the selection walk into range, set up and keep firing at it, into the fog too, until you give another order, as long as their shot lasts (a Powder Wagon nearby keeps them going). A Cannon fires what it is loaded with, round shot or canister. Shift queues it; with orders queued behind it, each fires 3 shots at the spot and goes on. While they are selected their spot shows on the map; the order is kept in a saved game and works online. Its icons are placeholders until the painted ones come.",
		"AREA SHOTS DESTROY BODIES: a Mortar shell, round shot or canister fired at a spot (BOMBARD) tears up the bodies lying in its blast: the Brood can no longer harvest them and a Missionary can no longer raise them (the Crown's own dead too: the price of blasting). The men the shot itself kills still fall as bodies. Ordinary fire at enemies leaves the bodies alone: measured, a gun line holding against Brood waves would otherwise have torn up 9 bodies in 10 by accident; clearing a field is a choice that costs powder and keeps the guns busy. To make up for it, a harvested body now gives 1.25 essence for each point of supply instead of 1 (a Musketeer or a Raptor 1.25, a Brute 3.75, a Horseman with his horse 5, plus 1 for each kill); SACRIFICE and the Brood Pen are unchanged.",
		"The Crown computer, facing the Brood with nothing attacking its base, has an idle Cannon or Mortar fire a few shots at a pile of bodies the Brood could harvest; never in a battle (it stops as soon as an armed enemy shows up).",
	]},
	{"v": "0.14.25", "items": [
		"FIX ONLINE: on a phone the ROOM CODE box (and the relay address boxes) could not be tapped. A tap now selects it and opens the keyboard; in a phone's browser it opens the browser's own text box.",
		"ONLINE: the 3, 2, 1, GO countdown is back, and it waits until every player's match has loaded, so a slower phone no longer starts behind the host.",
	]},
	{"v": "0.14.24", "items": [
		"WORKERS take the primary resource's jobs first, in every faction: a new Labourer goes to a Farm before any Powder Mill and hauls at the Town Hall only when both are full (Grubs: Feeding Pits; Winders: Cog Presses before Mainsprings). Nearest first within each.",
		"CAMERA: it now scrolls only 7 tiles past the map's edge (it was 25).",
	]},
	{"v": "0.14.23", "items": [
		"CLOCKWORK TIER 3 (gear mode): two new units from the MOVEMENT WORKS once an Escapement works, both paid in cogs and Tension. The PENDULUM (200 cogs + 75 Tension, 4 supply, 340 hp, 2 armour, slow), a tall clock tower on long legs, swings its pendulum blade through EVERY enemy on the ground in the wide arc in front of it (22 damage to each, a swing about every 2.6 s); it never hits its own side and cannot reach flyers. It is made only while the Works runs on its BIG gear (swap the gear on the Works' card): on the small gear its button says why, and a Works making a Pendulum cannot go back to the small gear until it is done or cancelled. The NETTER (125 cogs + 50 Tension, 2 supply, 120 hp, weak) fires a weighted chain NET from its spring cannon at ONE enemy up to 180 away: the net flies where you can see it, and the enemy it catches cannot move or fight for 4 s; a flyer it catches comes down to the ground for that time, where anything can hit it. One net about every 15 s; by itself it nets the most dangerous enemy in reach that is not caught already (right-click one to choose). The CLOCKWORK LAB starts with its Movement Works on the big gear, two Pendulums and two Netters; the SANDBOX's CLOCK tab spawns them. The Clockwork computer puts one Works on its big gear once it has an Escapement and adds a few Pendulums and Netters to its army.",
		"CLOCKWORK AIR, smoothed: a Swift or a Ticking Owl that is shot down no longer drifts sideways while it spins; the Swift's peck now dips its beak into the blow, nose down, and holds it there a moment (re-timed from its flight frames). ONLINE: the guest now sees the Owl's bomb fall, not only burst, and the progress bar of a Swift's MORPH TO OWL.",
	]},
	{"v": "0.14.22", "items": [
		"FIX: the Crown Mortar's DEPLOY / PACK button showed the Clockwork's tesla tripod; it now shows the Mortar with the Crown's red limber arrow.",
	]},
	{"v": "0.14.21", "items": [
		"CLOCKWORK AIR (gear mode): the CLOCK AVIARY, a tall clock tower on its gear ring (2x2, 175 cogs, 900 hp), makes the Clockwork's flyers; it can only be built while an Escapement works (meshed with a Mainspring). While it trains, its little doors open and a brass bird flies off. The SWIFT (75 cogs + 15 Tension, 2 supply, 90 hp, fast) hunts flyers only: it darts in and pecks (10 damage about every 1.3 s) and cannot touch the ground. Research TICKING OWL at the Aviary (150 cogs + 150 Tension, 60 s), then MORPH TO OWL rebuilds each Swift on its own into a TICKING OWL (100 cogs + 50 Tension, 20 s; it hovers in place meanwhile while a clock hand sweeps round it; CANCEL MORPH pays it back): a heavy, slow flyer (220 hp, 1 armour, 4 supply) that swoops down on units with its talons (20 damage every 2 s) and lets its pendulum weight fall on buildings as a bomb that bursts where it lands (45 damage to the buildings round it, every 3 s). It cannot hit flyers: Ratchet Turrets, Musketeers, Spitters, Skywings, Jacks and Swifts shoot it down. Shot-down flyers fall to the ground. The JACK now raises its arm to shoot at flyers. The CLOCKWORK LAB starts with an Aviary, three Swifts and a Ticking Owl; the Clockwork computer builds an Aviary when it sees enemy flyers (or late), answers them with Swifts and morphs an Owl now and then late in the game.",
	]},
	{"v": "0.14.20", "items": [
		"CLOCKWORK TIER 2 (gear mode): the ESCAPEMENT, the Clockwork's tech building (3x3, 150 cogs, needs a Movement Works), unlocks the JACK and researches HIGH LEAP. It uses Tension, so its gear ring must mesh with a Mainspring's ring (right beside it; an idler cog between them counts): otherwise it stands idle and shows NEEDS MAINSPRING, and its placement ghost says so; if its Mainspring is destroyed it waits until one meshes again. The JACK, the first unit that costs Tension (100 cogs + 25 Tension, 2 supply), is a jack-in-the-box on a coil spring: it hops about and shoots spinning screws at ground and air (10 damage about every 1.4 s, a little short of a Musketeer's reach). JUMP (E, then a spot): a short crouch, then a leap of up to 5 tiles along an arc over its shadow; it cannot shoot in the air and its spring takes 10 s to wind back; flat ground or down a cliff any time, UP a cliff only after HIGH LEAP (150 cogs + 100 Tension) and only where you can see. Tension prices show on the cards (100+25) and in the tooltips. The CLOCKWORK LAB starts with an Escapement meshing with the Mainspring and three Jacks; the Clockwork computer builds a Mainspring and an Escapement, mixes Jacks into its army and jumps them out of a melee when they are hurt.",
	]},
	{"v": "0.14.19", "items": [
		"CROWN WORKERS take real jobs first and HAUL only when every job is taken: a new Labourer (or one whose Farm is full) goes to the nearest Farm or Powder Mill with room, and only when all of them are full does he become a hauler at the Town Hall (if it has a free hauler slot). FIX: until now a Town Hall's hauler slots counted as the nearest job, so every Crown game started with all four Labourers hauling and the starting Farm unworked. A rally on the ground still sends new workers to that spot.",
	]},
	{"v": "0.14.18", "items": [
		"CLOCKWORK, no more power (gear mode): steam and electricity are only looks now. The Boiler, the Charging Pylon (the tesla tower), the Engine Hall and the Capacitor Works are gone from the Clockwork's build list, and nothing that needs them or costs energy is trained; the Clocktower fills no batteries and no longer zaps flyers. The top bar shows cogs, TENSION and supply (no energy pill). The RATCHET TURRET is the Clockwork's new static defence (2x2, 125 cogs, 450 hp, needs a Movement Works): its head turns to the nearest enemy and fires big spinning screws at ground and air alike (14 damage every 1.5 s, range a little over a Musketeer's). Like every gear building it must stay linked to the gear field or it does not fire. The CLOCKWORK LAB starts with one (and no Pylon); the Clockwork computer builds one or two.",
	]},
	{"v": "0.14.17", "items": [
		"FIX: workers sent to a Feeding Pit, Farm or Powder Mill whose ground is spent no longer stand idle under a \"0/5\" with the wrong message \"fully crewed\": they go to the nearest site on fresh land, or, when there is none, you are told the ground is spent; a barren site's label now reads \"spent\". The CAMERA can now scroll 25 tiles past every edge of the map, so a base by the edge can be viewed centred (orders, rallies and buildings still stay on the map).",
	]},
	{"v": "0.14.16", "items": [
		"CLOCKWORK ARMY, first look (gear mode): the MOVEMENT WORKS, the Clockwork's barracks (4x3, 150 cogs), trains the CLOCK SOLDIER, a plain melee front-line soldier with a clock-hand sword and a pocket-watch shield (70 cogs, 90 hp, 1 armour, 10 damage). Its hanging line runs while it trains. The REGULATOR, a squat pendulum clock (2x2, 100 cogs, +10 supply), replaces the Spring Tower; its pendulum swings while it is linked. Every Clockwork building's ring now has a bolted iron FLOOR PLATE in its middle that the ring turns round. The CLOCKWORK LAB starts with a Movement Works, a Regulator and four Clock Soldiers too; the Clockwork computer builds Movement Works and Regulators and trains Clock Soldiers on the gear field.",
	]},
	{"v": "0.14.15", "items": [
		"CLOCKWORK GEAR FIELD, painted: the ground gear rings are now the painted brass-and-iron rings, with big chunky teeth (the same size on every ring) and a thick edge, lying on the ground at the camera's angle. Meshing rings turn with their teeth exactly in each other's gaps. Where two linked rings do not quite touch, a small IDLER cog sits between them and meshes both. The placement ghost shows its ring already turning meshed, with the idler it would get; a clash is washed red. Rings may overlap only about half a tooth now and link across a gap of up to 2 tiles. The Cog Press has its own painted art (built, building, damaged, wreck) and a working loop while Winders crank it. New Clockwork building: the MAINSPRING (3x3, up to 3 Winders), which winds TENSION, a second resource shown in the top bar (nothing spends it yet). The CLOCKWORK LAB now opens on the gear field: the Clocktower with two Cog Presses and a Mainspring meshing round it, Winders at work.",
	]},
	{"v": "0.14.14", "items": [
		"CLOCKWORK GEAR PROTOTYPE: the Clockwork's economy is now a field of turning GEARS instead of the Line. Every Clockwork building sits in a ring of toothed ground gears (small or big; the Clocktower has the biggest); meshing rings turn against each other. A building works only while its ring touches a ring that links back to a Clocktower: unlinked buildings stop and show UNLINKED, new buildings must be placed touching the field (the ghost shows its ring and LINKS / NO LINK), and constructs wind down off the gear ground. The Cog Press replaces the Ore Crusher: it pays COGS (the new resource, start 300) by itself and more for every Winder crewing it (small gear: faster, 3 Winders; big gear: 6 Winders, better only when full); 2 presses per Clocktower, each Clocktower holds a finite reserve of brass. GEAR SWAP (25 cogs, 4 s) changes a building's gear size. The AI places presses and links its buildings. Saves and online games carry gear sizes. The Line, trains and pressure are shelved behind Defs.line_mode (off). Art is placeholder. See docs/clockwork_gear_prototype.md.",
	]},
	{"v": "0.14.13", "items": [
		"CLOCKWORK TRAINS (Clockwork Lab): rail vehicles can be COUPLED into one train. Select two or more of the Work Car, Plate Wagon, Heavy Locomotive, Carrier Car, Tesla Locomotive and Storm Engine and press COUPLE (C): the one with a Heavy Locomotive (else another locomotive) leads and waits, the others drive to its last car and hook on, and driving a vehicle into an idle one hooks it on too. The train is one unit to command: tapping any car selects the whole train, it moves as one at the speed of its slowest car, holds its couplings round bends, loops and lanes, queues behind a slower train going the same way, and turns round by swapping ends so no wagon sticks out. Every car keeps its job: crews still build and mend, the Plate Wagon still blocks the track, Tesla Locomotives and Heavy Locomotives still fire, the Carrier Car still lands flyers. A Heavy Locomotive shields the other cars (15% less damage). UNCOUPLE (U) splits the train in front of the car you tapped; a car that dies breaks the train there and both parts carry on. Saves and online snapshots carry the trains. The Ore Train and Troop Train of the economy are separate and cannot be coupled to.",
		"FIX: a rail vehicle in its lane no longer gets pulled into a side branch it is only passing at a junction.",
	]},
	{"v": "0.14.12", "items": [
		"CLOCKWORK LINE, bigger and clearer: pipes and rails are drawn 1.5 times larger, trains and wagons too, and the wagons are coupled close behind the locomotive with a visible hook. The Line now has TWO tracks, one for each direction (drive on the right): trains going opposite ways pass each other, and a train only waits behind one going the same way. A Line that ends at a Drill or the Clocktower gets a LOOP of rail round (or beside) the building so trains turn round without backing up; the LINE preview shows it in amber with its cost. Where a loop does not fit, a train backs out of the dead end after a short pause and changes lane. Sidings now let a slow rail vehicle step aside so a faster one can pass.",
	]},
	{"v": "0.14.11", "items": [
		"FIX: with several Clockwork Winders selected, a shift-queue of buildings is shared out: each Winder takes a different building instead of only the first one working while the rest stood still.",
	]},
	{"v": "0.14.10", "items": [
		"FIX: VIEW MAP on the battle report works again: after the match you can pan, zoom, select and use the minimap while the report is hidden.",
	]},
	{"v": "0.14.9", "items": [
		"CLOCKWORK LAB (EDITOR menu, or the same switch in Settings): an experimental batch of Clockwork units to try and cut. Production: Tin Militia, Scrapper and Rail Rifleman at the Assembly Works; Work Car, Plate Wagon, Heavy Locomotive, Carrier Car, Tesla Locomotive and Storm Engine at the new Rail Yard. SIDINGS let rail vehicles pass each other on one track. The computer ignores all of it. Numbers are rough: see docs/clockwork_units_prototype.md.",
	]},
	{"v": "0.14.8", "items": [
		"CLOCKWORK: rails and ore trains. Every Line segment carries a rail. The Ore Drill replaces the Ore Crusher: it digs your Clocktower's ore, and Ore Trains (buy them at the Clocktower) carry it along the Line to the Clocktower. A train follows the pressure, keeps its distance from the train ahead (one rail carries at most about 24 ore a second), stops where the Line is cut or has no pressure, and enemies can shoot it. Troop Trains (RIDE) carry up to 8 soldiers along the Line. Winders no longer haul batteries. Sprites for pipes, relay, drill, locomotive and wagons are imported from the ChatGPT sheets.",
	]},
	{"v": "0.14.7", "items": [
		"CLOCKWORK: the LINE. Winders lay pipe segments (LINE button, then LAY) from a Clocktower or Boiler; Assembly Works, Engine Hall, Capacitor Works, Ore Crusher and Pylon must stand beside the Line and run at the speed the pressure allows. Pressure falls along the pipe; a Pressure Relay boosts it again. PRESSURE (or the ` key) shows the overlay; a building with no Line beside it says NO LINE. Enemies can shoot pipes, Winders repair them.",
	]},
	{"v": "0.14.6", "items": [
		"New home for the game: holdfastrts.github.io/Holdfast/ (the Android app is Holdfast.apk in the same place). The older addresses stop working after a while.",
	]},
	{"v": "0.14.5", "items": [
		"ONLINE room now looks and works like the SKIRMISH screen: the same player rows (PLAYER, FACTION, COLOUR, PLAN, TEAM), the 1v1 and CO-OP buttons on top, and the same map panel with the picker, preview and random pools. Everyone picks their own faction and colour (a colour another player has is refused); the host also sets the computer's level and plan, the teams and the map. A guest sees the same screen with the host's controls greyed out.",
	]},
	{"v": "0.14.4", "items": [
		"The game is now called HOLDFAST. New web address (cavaleirobrancopensante.github.io/Holdfast/) and the Android app file is Holdfast.apk. Your settings, saves and hotkeys on a computer or phone carry over; on the web build they start fresh because the address changed.",
	]},
	{"v": "0.14.3", "items": [
		"ONLINE: a COPY button next to the room code, so the host can paste it to a friend.",
	]},
	{"v": "0.14.2", "items": [
		"ONLINE now knows the relay address by itself: nobody has to paste anything, just press ONLINE, then host or join with the room code.",
	]},
	{"v": "0.14.1", "items": [
		"The game speaks three languages: English, Brazilian Portuguese and Spanish. Click a flag (US, Brazil, Spain) at the top right of the main menu, or pick LANGUAGE in Settings; it changes at once and is remembered. Menus, the match screen, unit and building names and descriptions, tips, the help pages and these patch notes are translated; the spoken unit, announcer and taunt voices have Portuguese and Spanish recordings too (the creature sounds and the music are the same in every language).",
		"Map names, music titles and the match log stay in English. How to add a language: docs/localisation.md.",
	]},
	{"v": "0.14.0", "items": [
		"ONLINE (first playable): one of you opens ONLINE, presses HOST A GAME and tells a friend the 4-letter room code; the friend presses JOIN. Web and Android play together. Modes: 1 vs 1, or you both against a computer (co-op). The host's device runs the match; the guest sees and plays it with about 0.1 to 0.2 s of delay.",
		"The relay that connects you is a free Cloudflare Worker (tools/relay/README.md has the steps). Paste its address under ONLINE or in SETTINGS.",
		"Not yet in an online match: sounds of fights from the friend's side, cannon and mortar shells in flight, pausing, reconnecting. A friend who leaves is replaced by a computer.",
	]},
	{"v": "0.13.7", "items": [
		"MINIMAP SOLIDITY slider in Settings and in the pause menu: from nearly see-through to fully solid (starts at 60%).",
	]},
	{"v": "0.13.6", "items": [
		"The minimap is see-through now (about 60% opaque), so you can see the battlefield behind it.",
	]},
	{"v": "0.13.5", "items": [
		"Brood computer: when the Crown has walled its ramp and the scouts are shut out, one Grub keeps watch at the foot of the ramp (it backs away from any armed unit and comes back when they have gone), so the Brood is no longer blind to a Crown rush.",
		"Brood computer: when it sees Horsemen it keeps its Raptors at home (no attack wave until its army, Raptors counting a third, is worth 1.2 times what it saw; a Raptor found far from the capital walks back), saves for the Brood Pen and Gorge Pit and hatches Spitters and Brutes. A Rush plan that sees Horsemen turns into a normal game.",
		"Crown computer: when more than 950 gold has sat unspent for 15 s it puts up a second Cottage if supply-blocked, researches whatever is missing and takes a Town Hall on fresh soil if the best land is under 60%.",
	]},
	{"v": "0.13.4", "items": [
		"The Brood capital's swamp reaches 5 tiles farther than other Burrows', so a normal main base is swamp from edge to edge (a very big main would not be fully covered).",
	]},
	{"v": "0.13.3", "items": [
		"The Crown computer now builds its first Cottage at the foot of its ramp as part of a wall: one Gate beside it (and a palisade piece only where a gap is left) seals the mouth, so the wall stands earlier and costs less. The Gate still lets its own army, workers and horses out.",
		"A labourer mends a damaged ramp wall, Gate or ramp Cottage while it is safe where he stands, and stops at once when enemies come near.",
		"A Brood wave that finds the ramp sealed breaks the Gate or palisade instead of milling about at the foot.",
	]},
	{"v": "0.13.2", "items": [
		"The computer's early rush (Horseman rush, Raptor rush, the Rush plan) now judges how it went: enemy value killed, riders left, defenders and workers seen. If it failed, the survivors ride home, new cavalry stay home as defence and it builds up before it attacks again; if it worked, a few Horsemen may finish the last workers, otherwise a bigger mop-up force goes out as one group.",
		"The computer no longer sends single soldiers into your base: units trained after an attack left wait at home and join only in groups, and a raiding party cut down to one rider is called back.",
	]},
	{"v": "0.13.1", "items": [
		"The Brood and the Clockwork have their own mouse cursors (pointer, attack, attack on an enemy, move, select, build, rally, forbidden, patrol), shown in a match of that faction; the menus keep the Crown's.",
		"Hover feedback: what the mouse is over is marked so you can see what an order will hit: a pulsing ring and a bobbing arrow on a unit (red for an enemy, green for yours or an ally's, yellow for a loose horse), corner brackets on a building.",
	]},
	{"v": "0.13.0", "items": [
		"The attack alarm is now a bell struck three times, a short gap, three more, over low war drums. The faction's voice says what was hit once it has rung.",
	]},
	{"v": "0.12.99", "items": [
		"Brood Burrows no longer need to stand 8 tiles apart: with deliveries going to the capital they own no ground, so you may build one right beside another (only the usual footprint and gap rules apply).",
	]},
	{"v": "0.12.98", "items": [
		"The attack alarm is now a low war horn calling twice over deep war drums, warmer and rounder than the sharp klaxon of 0.12.97.",
	]},
	{"v": "0.12.97", "items": [
		"One attack alarm for all three factions: a rising three-blast klaxon plays whenever your forces, workers, base or an ally are hit (not while you are looking at the fight), and the faction's voice says which about a second later.",
	]},
	{"v": "0.12.96", "items": [
		"Workers at war: a Grub or Labourer given the ATTACK command (a click on an enemy or an attack-move) now has the fight before its automatic WORK and REPAIR. It goes on from enemy to enemy until none is left in sight, and only then goes back to work. Any other order ends it.",
		"SURRENDER (and any defeat): the battle report has a VIEW MAP button. The report steps aside, the fog is lifted and you can roam the map to see what the enemy did; a small bar at the top brings the report back or leaves for the menu.",
	]},
	{"v": "0.12.95", "items": [
		"New Brood sounds from the designer's insect clips. The Grub no longer squeaks: sent off it skitters on insect feet, and selecting it gives a short, soft chitter. Spitters, Brutes, Spore Mothers, Bloaters and Mist Toads get the same insect feet when sent off; Brutes and Spore Mothers also roar from the monster clips (Spore Mother, Bloater and Mist Toad had no voice before).",
		"Brood deaths: a small insect cry for Grubs, Spitters, Bloaters, Mist Toads and Skywings, a deep long one for Brutes and Spore Mothers. Raptors keep their lizard voice.",
	]},
	{"v": "0.12.94", "items": [
		"Grubs told to ATTACK now fight: an attack-move makes them go and engage what they meet, like Raptors. (Idle grubs still never pick fights, and Labourers still just walk.)",
	]},
	{"v": "0.12.93", "items": [
		"Patrol now shows its path: a dashed light-blue line between the two ends with an arrowhead at each and a ring on the end the unit is walking to, for every selected unit that is patrolling. While you are choosing the patrol point, the walk there and back follows your mouse.",
	]},
	{"v": "0.12.92", "items": [
		"Camera views are F4-F10 now (seven tabs), so they no longer clash with the browser's full screen (F11) and developer tools (F12).",
	]},
	{"v": "0.12.91", "items": [
		"Group keys work as in StarCraft 2, with Ctrl and Shift only: Ctrl+number sets the group, Ctrl+Shift+number adds the selection to it, Shift+number adds the group to your selection. To drop a unit: select the group, Shift+click the unit off, Ctrl+number again. Alt is not used.",
	]},
	{"v": "0.12.90", "items": [
		"Group keys were briefly Shift adds, Ctrl sets, Ctrl+Shift removes (replaced in 0.12.91).",
	]},
	{"v": "0.12.89", "items": [
		"New hotkey bar above the selection card: IDLE (F1), ARMY (F2), MAKE (F3) and groups 1 2 3 4 5 6 7 8 9 0 in one row. The old quick buttons (and HALL) are gone from the bottom left; the room is given back.",
		"Groups: Shift+number adds the selection to the group, Ctrl+number removes the selected units from it, Alt+number sets it (it was Ctrl+number). The same with Shift/Ctrl/Alt+click on the bar. Ten groups now.",
		"F1 selects every idle worker, F3 (MAKE) every building that makes something, the Town Hall too.",
		"Camera views: nine tabs F4-F12 peek out above the bar. F4-F12 jump to a saved view, Shift+F4-F12 saves one; on a phone tap a tab to jump (an empty one saves), hold to save.",
		"Fixed: groups and camera views were lost when you left a match and came back; they are now kept in the autosave and when you leave to the menu.",
		"Hotkey bar buttons and command card buttons now look pressed for a moment when you use their key.",
		"Fixed: a selection of different buildings (4 Barracks and an Armoury) left the command card blank. It now shows everything they can do on one card (a unit goes to the least busy building that makes it, a research to the building that offers it); MORE or Tab flips to the next page when it does not fit.",
	]},
	{"v": "0.12.88", "items": [
		"Brood computer: its first Clutch Mound goes on the plateau by the top of the ramp, and the next ones on the low ground at the edge of its swamp nearest the enemy, so the swamp walks forward toward them.",
		"Swamp that loses its building (a destroyed Clutch Mound) now retreats gradually, one ring of tiles every half second from the outside in, instead of vanishing at once.",
	]},
	{"v": "0.12.87", "items": [
		"Brood: the Spore Vent and SEED VENT are gone. The Clutch Mound (the supply building) now spreads swamp itself (10 tiles, grows over a few seconds), so supply is something to plant forward and defend.",
		"Clutch Mound: must be built (by a grub, as before) on swamp joined to a Burrow's swamp. If a mound falls, the swamp only it held shrinks back (buildings left standing on it stay, but no longer count as joined, so nothing new can be placed there).",
		"Clutch Mound has new art with the Spore Vent's chimneys and a spore plume (built: ChatGPT drawing; under construction, damaged and destroyed are made from it in code, until ChatGPT redraws them).",
		"Brood computer: puts its Clutch Mounds out at the swamp's edge when its Feeding Pits have no room; its build timing is unchanged.",
	]},
	{"v": "0.12.86", "items": [
		"The swamp shimmer now takes its owner's colour (blue, red, yellow...), so swamp stands out from the ground on every map and you can tell whose swamp it is at a glance.",
	]},
	{"v": "0.12.85", "items": [
		"Brood swamp now shimmers slowly: soft waves of light and a little teal drift over it (one small shader on the whole layer, almost no cost), so it reads as alive instead of a flat dark patch.",
	]},
	{"v": "0.12.84", "items": [
		"Supply cap is 200 for every faction (was 100; 160 for the Brood). Bigger armies are possible, but each side still needs the supply buildings to get there.",
	]},
	{"v": "0.12.83", "items": [
		"Settings on a phone: the BACK button is pinned under the heading, so it is always on screen (the list below it scrolls).",
	]},
	{"v": "0.12.82", "items": [
		"Main menu: the version line at the bottom is bigger, bright and outlined, so it is easy to read.",
	]},
	{"v": "0.12.81", "items": [
		"Powder Mill: labourers now work a real round: dig a shovelful at a heap, walk with the loaded shovel along the front of the shed to the hopper, tip it in and walk back to the next heap. The six are staggered so they do not bunch. Powder output is unchanged.",
		"Powder Mill: the dirt track and grass edge are now drawn on the ground, under the labourers, instead of over their legs. They are still hidden behind the shed roof. (New loaded-shovel walk is a code-made placeholder, until ChatGPT redraws it.)",
	]},
	{"v": "0.12.80", "items": [
		"Brood: Spore Vents are no longer built by a grub. The capital and every finished Spore Vent have SEED VENT (E): pick a spot on joined swamp up to 10 tiles away and a new vent grows there (90 biomass, 16 s, no grub used). Each source grows one at a time; vents chain to spread the swamp far. ABANDON on the growing vent pays it all back. The Brood computer seeds its vents the same way.",
	]},
	{"v": "0.12.79", "items": [
		"Labourer walking south and south-east (and so south-west, with a sack or keg, and the Musketeers' legs): a real stride instead of a shuffle. Code placeholder: the east walk's stride squeezed under the body, until ChatGPT redraws it.",
	]},
	{"v": "0.12.78", "items": [
		"Supply tooltip now shows Workers, Army and In production supply. Computer: hover the supply number. Phone: tap the supply number.",
	]},
	{"v": "0.12.77", "items": [
		"Armoured Musketeer walking away from the camera now shows a steel back plate (taken from the dismounted Cuirassier).",
	]},
	{"v": "0.12.76", "items": [
		"Armoured Musketeer: fixed the steel armour being recoloured with the breeches; only the legs are silver-grey now.",
	]},
	{"v": "0.12.75", "items": [
		"Armoured Musketeer walk with the new legs in silver-grey breeches too, all directions; armour, helmet and musket unchanged.",
	]},
	{"v": "0.12.74", "items": [
		"Musketeer walk with the new legs (a proper alternating step) in his silver-grey breeches, all directions; tricorne and musket unchanged.",
	]},
	{"v": "0.12.73", "items": [
		"Art work files only: silver trousers option in the Musketeer preview tool (nothing changed in game).",
	]},
	{"v": "0.12.72", "items": [
		"Art work files only: cream trousers option in the Musketeer preview tool (nothing changed in game).",
	]},
	{"v": "0.12.71", "items": [
		"Art work files only: a preview tool for white trousers on the Musketeer (nothing changed in game).",
	]},
	{"v": "0.12.70", "items": [
		"Labourers carrying a sack or keg bob up and down as they walk again (the body rises at the passing steps).",
	]},
	{"v": "0.12.69", "items": [
		"Labourers walk at a calmer pace (12 frames a second at full speed, was about 20): the new legs no longer look like running, with or without a sack or keg.",
	]},
	{"v": "0.12.68", "items": [
		"Musketeer walk restored to the earlier art (tricorne with gold trim, musket in his hands); the plumed red-hat redraw is no longer used. The Armoured Musketeer keeps the musket in his hands with the new legs.",
		"Animation viewer: pinch with two fingers (or the mouse wheel) to zoom; tapping the note box now opens the keyboard.",
	]},
	{"v": "0.12.67", "items": [
		"Animation viewer on a phone: drag a list to scroll it, drag the picture to move it, CENTER puts it back; the right column scrolls too. COPY NAME copies 'unit / pose / direction / frame' to the clipboard so you can tell me which animation bothers you.",
	]},
	{"v": "0.12.66", "items": [
		"Brood AI builds a real army: it saves for the Spawning Den first and keeps its grubs down to a working minimum while the army is behind. New Extreme Rush strategy (Brood): Den at about 0:40, first Raptors about 1:20, attack about 1:40.",
		"Timing Attack now starts at 4:30; Rush and Extreme Rush send their first Raptors at the workers. Build timelines for every strategy are in docs/ai_build_timelines.md.",
	]},
	{"v": "0.12.65", "items": [
		"Animation viewer: switch pose and direction with buttons or the arrow keys (Left/Right = direction, Up/Down = pose, Q/E or Page Up/Down = unit, Space = pause, comma/period = frame). Units that still need art are marked with ! and can be filtered, with the reason shown.",
	]},
	{"v": "0.12.64", "items": [
		"Crown AI scouts for a rush, walls its ramp in time (about 2:00) and trains Musketeers behind it; against a Brood extreme rush it now holds with almost no workers lost.",
		"The AI scout knows the Brood's Raptors are a rush: foot-soldier proof is only used against the Crown.",
	]},
	{"v": "0.12.63", "items": [
		"Armoured Musketeers (all directions) and Musketeers (front and back) now walk with the new labourer legs: a proper alternating step.",
		"The Pikeman's files moved to a folder of obsolete units (he is not in the game).",
	]},
	{"v": "0.12.62", "items": [
		"Art work files only: an experiment tool that previews the labourer's new legs on other Crown units (nothing changed in game).",
	]},
	{"v": "0.12.61", "items": [
		"Labourers carrying a sack or a keg walk with the same new legs as the empty-handed walk, in all directions.",
	]},
	{"v": "0.12.60", "items": [
		"New labourer walk in all five directions, redrawn in the body's own style: his legs now alternate properly.",
	]},
	{"v": "0.12.59", "items": [
		"Art work files only: reference image for the labourer north walk prompt.",
	]},
	{"v": "0.12.58", "items": [
		"Art work files only: labourer south-east and north-east walk sheets saved for the coming walk redraw.",
	]},
	{"v": "0.12.57", "items": [
		"Art work files only: new labourer south walk sheet saved for the coming walk redraw.",
	]},
	{"v": "0.12.56", "items": [
		"AI worker safety: workers no longer all rush a small raid and die. They fight only when clearly stronger, otherwise they flee to a hall or open ground and go back to work once it is safe.",
	]},
	{"v": "0.12.55", "items": [
		"In-game chat: Enter on a computer, a speech-bubble quick-chat button on a phone.",
		"The AI says gg when its position is hopeless; reply gg and it resigns. The match log records chat and whether you were ahead or behind when you surrendered.",
	]},
	{"v": "0.12.54", "items": [
		"Walk cycles rebuilt with a real stride for the Missionary, Windup Soldier, Winder and Armoured Musketeer; Raptor improved.",
	]},
	{"v": "0.12.53", "items": [
		"Powder mill redrawn: a lean-to roof over the three ingredient piles and a wooden hopper by the millstone.",
	]},
	{"v": "0.12.52", "items": [
		"New labourer art: death, keg explosion death, bury, idle and walk redrawn in the new outfit; the side-view walk has a real stride.",
	]},
	{"v": "0.12.51", "items": [
		"Settings has an ANIMATION VIEWER: play any unit's animation in any direction, step frames, zoom, and flag frames to copy and send.",
	]},
	{"v": "0.12.50", "items": [
		"Powder mill: a roofed shed over three ingredient piles (saltpetre, sulphur, charcoal) and a hopper; labourers shovel each pile into the hopper in turn.",
	]},
	{"v": "0.12.49", "items": [
		"AI defence sizes its force to the enemy it sees: a lone horseman or scout draws at most a few fast units, never the whole army, and they are recalled after a short chase.",
		"The AI avoids sending units into ground covered by enemy artillery away from its own base, and reinforces when a real attack is winning.",
	]},
	{"v": "0.12.48", "items": [
		"Crown wall building: a sweep no longer deletes the rest of a wall right after a piece is finished.",
	]},
	{"v": "0.12.47", "items": [
		"AI scout now really attacks a gate or wall that blocks it.",
		"AI scout steps out of musketeer range and watches the ramp from a safe spot; it goes home if it keeps being shot, and remembers that the enemy has foot soldiers.",
	]},
	{"v": "0.12.46", "items": [
		"Led horses no longer get stuck in a gateway: they follow behind the leader or path around the wall.",
		"Horse delivery from the Breeder has stuck recovery (repath, then place the horse beside the recruit).",
	]},
	{"v": "0.12.45", "items": [
		"Labourer side and diagonal walk, carry and keg-carry: legs now step one foot after the other.",
	]},
	{"v": "0.12.44", "items": [
		"Build mode shows a tile grid around the ghost: blocked tiles tinted, narrow paths in amber, and a warning if the building would cut off or narrow a route. BUILD GRID on/off in Settings.",
	]},
	{"v": "0.12.43", "items": [
		"A ranged unit on high ground that fires at the low ground is revealed for about 2 seconds as a small spot of fog.",
	]},
	{"v": "0.12.42", "items": [
		"Gate lock symbol is half its size.",
	]},
	{"v": "0.12.41", "items": [
		"Cliff walls: the same soft shade on the low ground beside a wall's end.",
	]},
	{"v": "0.12.40", "items": [
		"Cliff walls: where walls step diagonally, the high ground beside the wall's end gets a soft shade, so the step is less abrupt.",
	]},
	{"v": "0.12.39", "items": [
		"Settings has a PATCH NOTES button (this page).",
		"Cliff walls: the ends where a wall steps are shaded softly instead of ending in a hard edge.",
		"Farm work uses the new hoe animation; the pickaxe is gone.",
	]},
	{"v": "0.12.38", "items": [
		"New work sounds: shovel and digging bites for farmers, hammering bites for builders.",
	]},
	{"v": "0.12.37", "items": [
		"Crown bugle and fife command calls from real recordings, softer; stop and hold calls.",
		"Sound priority system: fewer sounds at once, important ones duck the rest.",
		"Music, sound and ambience volume sliders in Settings and the pause menu.",
		"Horses are neutral: select them to hear them, move them only by leash or mount.",
		"Gate lock symbol above the gate: red closed lock, yellow open lock.",
		"AI answers a lone scout with at most two workers; the scout attacks a wall that blocks it.",
	]},
]


static func current() -> Dictionary:
	var ver: String = ProjectSettings.get_setting("application/config/version", "dev")
	for n in NOTES:
		if n["v"] == ver:
			return n
	return NOTES[0]


## The items of one entry in the chosen language (the English item where there is no translation:
## translations live in scripts/lang/patch_<code>.gd, built by tools/i18n_patch_build.py).
static func items(entry: Dictionary) -> Array:
	var en: Array = entry["items"]
	var tr: Dictionary = {}
	match Loc.lang:
		"pt":
			tr = PatchPt.N
		"es":
			tr = PatchEs.N
	if not tr.has(entry["v"]):
		return en
	var out: Array = []
	var t: Array = tr[entry["v"]]
	for i in en.size():
		out.append(t[i] if i < t.size() and t[i] != "" else en[i])
	return out
