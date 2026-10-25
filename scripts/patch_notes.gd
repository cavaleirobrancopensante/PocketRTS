class_name PatchNotes
extends RefCounted
## What each version changed, newest first (the PATCH NOTES page in Settings shows the entry of
## the running version first). Add an entry for every pushed version (see CLAUDE.md).

const NOTES := [
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
