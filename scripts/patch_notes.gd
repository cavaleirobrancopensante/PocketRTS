class_name PatchNotes
extends RefCounted
## What each version changed, newest first (the PATCH NOTES page in Settings shows the entry of
## the running version first). Add an entry for every pushed version (see CLAUDE.md).

const NOTES := [
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
