extends Node
## Main menu, the skirmish lobby, starting a match, and the end-of-match screen.

var version: String = ProjectSettings.get_setting("application/config/version", "dev")
var sfx: Sfx
var game: Game
var ui_layer: CanvasLayer
var menu: Control
var _went_fullscreen := false
var _backdrop: MenuBackdrop

## The skirmish setup, remembered between sessions. A first-time player gets everything
## random: faction, map, the computer's plan, and colours that fit the map.
var lobby := {
	"map": "random_1v1",
	"slots": [
		{"who": "you", "faction": "random", "colour": Defs.COLOUR_FITS_MAP, "side": 0},
		{"who": "hard", "faction": "random", "colour": Defs.COLOUR_FITS_MAP, "side": 1, "strategy": "random"},
	],
}

const WHO := ["you", "easy", "normal", "hard", "brutal"]
const MAX_SLOTS := 8          # players in a skirmish (the 4v4 maps)
const WHO_LABEL := {"you": "YOU", "easy": "EASY AI", "normal": "NORMAL AI", "hard": "HARD AI", "brutal": "BRUTAL AI"}
const FACS := ["crown", "brood", "clockwork", "random"]

const HELP := {
	"BASICS": """Destroy every enemy building to win.

Each faction builds its own economy. Every Town Hall, Burrow or Clocktower allows only so many economy structures nearby, and every faction's land runs out in time, so expanding to a new hall spot is how you grow, and the expansions are what you fight over.

Efficiency: over each of your economy buildings a small bar shows how well it's working right now, as a %: its workers against its full crew, times what's left of its base's reserve (soil, saltpetre, ore or Burrow ground: 100% fresh, down to what spent land still pays). Green is 80% or more, then yellow, then red. Select the building to see the breakdown.

Veterancy: every kill gives a unit +1% damage (up to +50%), and it shows on the unit. A Crown soldier's hat or helmet trim is black, turns silver at 25 kills and gold at 50; a Brood creature's skin turns amber at 25 kills and obsidian black at 50.

Area damage (canister, round shot, steam, spit blobs, storms, exploding powder) hurts your own units too: keep your men out of the blast.

Ghost sites: a placed building is a see-through ghost until it starts (Labourers begin, the grub morphs, the crate lands). Anyone walks through it, it can't be attacked, and the enemy can't see it. When it starts, your units on it step aside; enemy units standing there block it, and after about 5 s it fails with all of its cost back ("Can't build there: the spot is blocked.").

High ground: units below a cliff can't see up onto it, and ramps are the only way up. Rivers can only be crossed at the fords.

Skirmish: up to four players. Each computer player has a PLAN (Balanced, Rush, Economy, Timing attack, Air rush for the Brood, or Random). Give players the same TEAM number to make them allies. BRUTAL AI never stops, micro-manages every fight and cheats (+50% income).""",
	"CROWN": """THE CROWN: shot, shell and black powder.

Labourers work Farms (up to 8 each, each hoeing his own stretch of the crop rows): a farm ripens into a 380-gold harvest, about every 40 s with a full crew. The Powder Mill (up to 6 labourers) grinds saltpetre into black powder (musketeers, balloons and wagons cost some). Each Town Hall allows 2 Farms and 1 Powder Mill nearby. The Horse Breeder is no economy building: it trains horses (HORSE: 40 gold, 15 s, no supply; RALLY sends them on) and unlocks Horsemen; build as many as you like, anywhere.

Horses: bought at a Horse Breeder (40 gold each). Horsemen and Cuirassiers (Barracks), Field Cannons, Mortars and Powder Wagons (Foundry) each need a horse, and one click trains both: a horse standing at the building (within 2 tiles) walks in; else a free one at a breeder is reserved for him (the top bar shows "Horses: 3 (1 reserved)"); else the nearest breeder trains one for him (40 gold more; without the gold the button says so). A Horseman comes out on foot, walks to his horse (waiting at the breeder while it's trained), gets on and rides to the rally point; a gun's horse walks to the Foundry by itself and the gun comes out once it's there. Cancelling releases the reservation (a horse the breeder is training is kept, as a spare). Guns and wagons draw up to 4 horses: HARNESS adds one, each beyond the first +12% speed; RELEASE HORSE lets one go at a time; extra horses take a share of the blows and can be killed. Any man on foot (Labourers, Musketeers, Guardsmen, dismounted horsemen) can LEAD up to 3 horses by the reins (or right-click a horse with Labourers); RELEASE lets them go. MOUNT (or right-click a horse with soldiers): a Labourer becomes a Messenger (a fast unarmed scout), a Musketeer a Dragoon, a Guardsman an Armoured Dragoon, a Missionary a Mounted Missionary (he gets off to bandage, and back on after, and to raise the fallen), a dismounted horseman rides again. DISMOUNT anywhere: the horse stands beside him, and a Horseman on foot fights with carbine and sabre. Dragoons can't fight in the saddle: told to attack they dismount (0.8 s), fire (reloading a third slower than a Musketeer), and get back on by themselves to move; HOLD keeps them on foot; their reload waits while they ride. A gun's RELEASE HORSE frees its horse: then it can't move (a gun still fires, a wagon still supplies) until you HARNESS one again. A horse left alone (nobody of yours within 2 tiles or leading it) is stolen by any enemy man who walks up to it; the Brood can only kill them. Horses heal by themselves and are never raised (a fallen rider gets up on foot; his horse stays a carcass). A horse seasons with every 100 tiles it covers ridden or in harness: up to 3 ranks, each +15% health and a richer carcass for the Brood. Loose horses: a rider killed by a single shot (musket, carbine, acid glob, a single zap) leaves his horse alive 4 times in 10, by a single sabre, bayonet or Clockwork blow 1 time in 4; never by the Brood's jaws or anything with splash or area (round shot, canister, shells, blasts, chain lightning, clouds, spells), nor if the horse was nearly dead. It bolts 5 to 7 tiles away from the fight and grazes there, belonging to nobody (an undyed saddle cloth): any man who can lead horses, of any side, takes it by walking up (or with LEAD, MOUNT or HARNESS); the Brood can kill it. The rider's body is only the man then; raised, he walks back to his loose horse if it's still close. A gun shot or cut to pieces gives each horse of its team the same chance; a Powder Wagon blows up with its horses.

Soil: each Town Hall's farmland holds 9,000 gold that its farms draw out harvest by harvest (shown as "Soil: %" on the hall and its farms). Spent soil turns the fields yellow-brown and they pay only a third: expand, and a new Town Hall brings fresh land.

Saltpetre: each Town Hall's ground also holds 1,320 powder's worth of saltpetre for its Mill, about 11 minutes of a fully worked Mill (about 120 powder a minute; "saltpetre %" on the Mill and the hall); spent, the Mill grinds at a quarter. A new Town Hall brings fresh saltpetre: build a Mill there.

Powder: each Musketeer carries 10 shots (20 with the Shot Pouch), each Cannon 8 and each Mortar 6 (the amber bar). A dry musketeer fights with the bayonet until it refills; a dry gun can't fire ("Out of powder!" over them). They refill within 3 tiles of a Powder Mill, Barracks or Town Hall (paid from the powder bank: 5 for a full musketeer; an empty bank makes them wait), or of a Powder Wagon (Foundry): it carries 120 shots for the army, fills up near those buildings (1 powder per 2 shots), and on SUPPLY two labourers run 30-shot kegs to it from the Mill. A wagon that's destroyed explodes (friends too), and so does a labourer killed with a keg: guard them.

Walls and gates (they need a Cottage): lay them in a line across your ramp (every main base sits on high ground with one way up); gates open for your side only. Gates turn to match the palisade they're placed in; R turns one by hand.

Two openings: Powder Mill first for Musketeers, or Horse Breeder first for a Horseman rush. You start with no powder. A Cottage unlocks the Barracks and the palisade; Musketeers (10 powder each) need a Powder Mill, Horsemen a Horse Breeder (his horse comes in the same click). They shoot at range and stab with the bayonet by themselves when the enemy closes in (no button). Barracks: Musketeers and Horsemen, fast light cavalry with sabres; it only trains. Every soldier comes light or armoured: once the Armoury has researched Armour, the Barracks shows a second button for each, the Guardsman (an armoured Musketeer: +1 armour, +20 health) and the Cuirassier (an armoured Horseman: +1 armour, +30 health, a little slower), priced with the armour fee. Light soldiers take extra harm from what hits light men (canister), armoured ones from what hits armour (round shot).

Armoury (ADVANCED page, needs a Barracks): all the Crown's research. Armour (needs a Foundry); the locks one after another, Matchlock, Flintlock (needs a Foundry), Caplock (reload 10%, 20%, 30% faster); the Socket Bayonet (bayonet +6 damage, thrusts 15% faster); the Shot Pouch (20 shots instead of 10; recruits don't come with it); Prepared Charges (needs a Foundry: cannons and mortars reload 20% faster) and then the Gunner's Quadrant (they reach 1 tile further); the Cavalry Charge (without it no horseman charges; with it, after about 2 s at the gallop the next sabre blow hits double and throws the enemy back). Research goes into the production queue like a unit (CANCEL takes it back out, paid back); the next lock can be queued behind the one before. The guns' drills and the charge count for every unit at once. Armour, the locks and the bayonet only unlock an upgrade: each soldier is refitted one by one. Select soldiers and press ARMOUR, the best lock (they skip the ones between) or SOCKET BAYONET: each man who lacks it pays a small fee (Armour 12 gold + 4 powder a Musketeer, 30 gold a Horseman; Matchlock 8, Flintlock 12, Caplock 16 gold; Socket Bayonet 3, Shot Pouch 5) and walks to the nearest Barracks, Armoury or Powder Wagon to be fitted (2 s). Another order calls it off, paid back. AUTO REFIT on a Barracks, an Armoury or a Powder Wagon (glowing = on) refits idle soldiers within 3 tiles of it by itself. New Musketeers come out with the locks and the bayonet researched, the fees added to their price. A selected soldier's card lists his refits (Armour · Flintlock · Socket Bayonet).

Foundry: Field Cannons, Mortars, Powder Wagons and Observation Balloons: only a pilot aboard, they carry 4 Musketeers or Labourers. LOAD them (they walk under it and climb in; Musketeers shoot from the basket and refill from its 40-shot powder store), then UNLOAD anywhere, over cliffs too. Stopped within 2 tiles of a Powder Wagon, Mill, Barracks or Town Hall, the pilot hauls powder kegs up on a rope (RESTOCK flies it to one). Round shot flies over to where it's aimed, then ploughs through everyone in its line past that spot, your own men too: a selected cannon shows that stretch, red over your men (it holds fire on its own while they're there; canister never holds). The Mortar must DEPLOY to fire; it lobs shells over men and walls 5 to 11 tiles away that burst over a wide area (friends too).

Church: one Missionary, who bandages wounded soldiers back to full health and raises fallen Musketeers, Horsemen and dismounted horsemen from their bodies by himself (6 s): back at half health under the cross for 30 s; fall again under the cross and he's gone for good. He goes to bodies first, the most worthwhile (dearer soldiers and veterans) and soonest lost, nearer ones before far ones, skipping any he can't reach in time; then the worst-hurt wounded by their worth. Two Missionaries never go for the same one. The Missionary can't be hurt unless he wanders near enemy buildings.""",
	"BROOD": """THE BROOD: swarm, swamp and hunger.

Grubs haul food from Feeding Pits to a Burrow: a load pays for its trip, and a grub earns more the farther its pit is from the Burrow (about 30% more from 18-22 tiles out than right beside it). Pits must grow on your swamp; Spore Vents spread it far. Each Burrow allows 3 Feeding Pits and 1 Brood Pen.

The Burrow grows: upgrade it on its card to a Warren (150 biomass, 40 s: up to 10 eggs, 2000 health), then to a Broodmound (250 biomass + 50 essence, 60 s, needs a Gorge Pit: up to 15 eggs, 2600 health, armour 2). It keeps laying eggs, hatching and taking food while it grows; STOP UPGRADE pays it all back.

Ground: each Burrow's ground holds 10,500 biomass that its pits draw out load by load (shown as "Ground: %" on the Burrow and its pits). Spent ground turns the pits grey-brown and they yield only a third: grow a new Burrow on fresh ground.

Essence: the Brood Pen turns bodies that fall nearby into essence. SACRIFICE (K) sends the selected creatures (not grubs) to the nearest Pen to be offered up: 12% of each one's biomass cost as essence (3 a Raptor). Spitters, Bloaters, Brutes, Skywings, Spore Mothers, Mist Toads and Miasma cost essence.

Every unit hatches from the Burrow's eggs (a Burrow holds 5, a Warren 10, a Broodmound 15). The Spawning Den unlocks Raptors and Spitters. Swamp heals and speeds the Brood. Roost: Skywings, which hunt flyers in the air; LAND them (1.2 s) to bite ground units, but landed anything can hit them. Bloaters spit acid until their gas runs out, then deflate and slowly fill up again (faster on swamp). Gorge Pit: Brutes and Spore Mothers, who must ROOT to lob big spit blobs over an area (rooted, they spread swamp) and cast MIASMA, a cloud that heals the Brood. Also from the Gorge Pit: the Mist Toad, a slow, fragile caster whose energy (faster on swamp) pays for FOG (F: a fog bank for 12 s; shots fired from or into it miss half the time, and units inside see 2 tiles) and TONGUE (T: marks one enemy for 3 s, they see the crosshair, then drags it to the Toad's feet; heavy engines like the Steam Walker are only staggered). Army cap 160.""",
	"CLOCKWORK": """THE CLOCKWORK: gears, steam and lightning.

The Clocktower and its Boilers (2 per Clocktower) fill batteries by themselves; Winders carry them to Ore Crushers, where the charge becomes ore drawn from the nearest Clocktower's ore. A battery slowly loses charge on a long road (after 6 s), so keep crushers close; a Winder hit while carrying one gets it burst on its back. A Capacitor Works turns every battery blue (more charge, slower to fade). Winders also repair and wind (repairs cost ore), and wind themselves now and then: away from a field they stop for a few seconds to crank their own spring.

BUILDING: a Winder sent to build first fetches a crate from the nearest Clocktower and carries it to the site on his back (the site is a ghost until then). Set down, the crate unfolds into the frame and the building builds itself; its build time starts when the crate lands. If the Winder is killed or given another job on the way, he drops the crate: send any Winder onto it to carry it on (idle ones close by do it themselves). A crate on the ground can be smashed (40 hp), which cancels the building (all of its cost back). With no Clocktower, the Winder starts it by hand.

ENERGY: the batteries waiting at your Clocktowers and Boilers are your energy (top bar). Once you have an Engine Hall, Winders leave the last 6 for it. Steam Walkers (3), Tesla Carts (2), Stormcallers (2) and every STORM (2) spend it.

Ore and coal: each Clocktower's ground holds 11,400 ore, about 10 minutes of a saturated base (about 1,150-1,200 ore a minute; "ore %" on the crushers and the Clocktower); spent, its crushers pay a quarter. Each Clocktower's Boilers burn its coal ("Coal: %"); burnt out, they fill batteries at a third. A new Clocktower brings fresh ore and coal. Spring Towers and Charging Pylons don't fill batteries.

Assembly Works: Wind-up Soldiers (3 an order, cheap spears that run on a spring: about 50 s away from a field and they run down until a Winder cranks them up), Threshers (saws that SPIN UP over 3 s of cutting, up to 160% damage, biting the enemies round their target; they burn their battery fast), and with a Boiler Bulwarks (BRACE, E: the tower shield takes the shots aimed at your units behind it; braced it can't move) and Arc Throwers (lightning balls, hit flyers; each throw drains their battery). Engine Hall (needs an Assembly Works and a Boiler): Steam Walkers, and with a Charging Pylon Tesla Carts, Stormcallers and Ornithopters.

Constructs run down away from a Clocktower, Spring Tower, Charging Pylon or deployed Tesla Cart. One that stays about 10 s by a Boiler or in a Pylon's or deployed Tesla Cart's field is OVERCHARGED (+15% damage) while it stays. Tesla Carts must deploy (3 s) to fire. Stormcallers cast a STORM that stuns everything inside it (no damage), your own units too; their charge only fills inside a field. Tesla Carts are mainly mobile power: their lightning jumps to one more enemy at 40%. The Steam Walker is the Clockwork's swarm-killer. Ornithopters on COURIER carry batteries to constructs that ran down; OVERLOAD dumps one into a construct for 12 s of extra speed and damage (then it's left at 25% charge). Army cap 100.""",
	"CONTROLS": """COMPUTER
Left click selects (Shift adds, Ctrl-click or double-click picks every unit of that type on screen); left drag box-selects; right click commands (move, attack, work, rally). Mouse wheel zooms; screen edges, arrow keys or the middle button pan.
Line move: hold the right button and drag a line; your units spread out along it (with A first, they attack-move). On a phone: tap MOVE or ATTACK, then drag.
Shift-queued orders: hold Shift while giving an order (right click, MOVE, ATTACK, REPAIR, placing buildings or walls) and it goes after what the units are already doing, up to 16 orders. MOVE, ATTACK, REPAIR and placement stay open while Shift is held. Shift-placed buildings are built one after another in click order (each Brood site takes its own grub). A plain order clears the queue. Selected units show their queue as faint lines: green move, red attack, yellow build or work.
Every command button has a letter hotkey (hover for details): B build, A attack, M move, S stop, H hold, G work, E repair (right-click it: automatic repair, glowing). 1-9 select groups, Ctrl+number saves, Shift+number adds. F1 idle worker, F2 army, F3 hall (again: the next one), F4 all production buildings (MAKE), Space jumps to the selection, Esc cancels.
Tooltips: rest the mouse on a command button for its cost, time, supply, what's still missing (in red) and what it does; on a unit or building (yours or the enemy's), a resource or a quick button a little longer. Settings > TOOLTIPS switches them off.

MOBILE
Tap to select, double-tap for every unit of that type on screen. DRAG: BOX / PAN (top right) switches what a one-finger drag does. Tap the ground to move, an enemy to attack. Long-press to move without fighting. Two fingers pan, pinch zooms, tap the minimap to jump. ARMY / IDLE / HALL / MAKE select quickly (HALL again: the next hall; MAKE: every production building, to train from all of them). Hold REPAIR for automatic repair (it glows); groups 1-4: hold to save, tap to select. Tap a portrait in a group to keep only that kind.
The command card holds 12 buttons (a MORE button pages on when a big mixed selection needs more). Help: tap "?" (top right), then tap anything (a button, a unit or building, a resource) to see what it is instead of using it; the next touch puts the tooltip away. Settings > TOOLTIPS switches it off.

WATCHING COMPUTERS
With no "you" in the lobby the computers play and you watch. The VIEW button under the clock picks how: Free · all vision (you move the camera, no fog; the default), Free · a player's vision (you move the camera, under that player's fog of war), or Follow a player: the camera goes by itself to what that computer is doing (its fights first, staying with one until it's over, then its army on the attack, raiders at its base, a building it just placed, its army), under its fog, holding each sight a few seconds. Moving the camera yourself while following switches to Free with the same vision; pick Follow again to resume. On a computer, 0 is all vision and 1-4 follow that player. The view you pick stays for the next match you watch.""",
	"MAP EDITOR": MapEditor.HELP_TEXT,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiStyle.install()
	add_child(Music.new())
	sfx = Sfx.new()
	add_child(sfx)
	var cursors := Cursors.new()       # the mouse cursor (computer only)
	cursors.main = self
	add_child(cursors)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_make_rotate_overlay()
	Settings.load_all()
	_load_lobby()
	if OS.has_feature("web"):
		# F11 is the browser's: stop the engine swallowing it (it then did nothing in the game tab).
		JavaScriptBridge.eval("""
			['keydown', 'keyup'].forEach(function(t) {
				window.addEventListener(t, function(e) {
					if (e.key === 'F11' || e.keyCode === 122) e.stopImmediatePropagation();
				}, true);
			});
		""", true)
	var crash := _crash_report()
	_mark_running("menu")
	if Settings.device == "":
		show_device()
	elif crash != "":
		show_crash(crash)
	else:
		show_menu()


# ------------------------------------------------------------------ screens

## A fresh full-screen menu page over the animated backdrop.
func _page() -> Control:
	_clear_ui()
	_backdrop = MenuBackdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_backdrop)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("web") and Settings.pc():
		menu.offset_bottom = -30      # room under the buttons for the F11 line (_update_f11_hint)
	menu.theme = UiStyle.theme()
	ui_layer.add_child(menu)
	return menu


## First start (or from the menu): computer or phone? They play differently.
func show_device() -> void:
	var root := _page()
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var p := PanelContainer.new()
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(UiStyle.heading("POCKET RTS", 54, UiStyle.TRIM))
	v.add_child(UiStyle.text("Where are you playing?", 26, UiStyle.TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	for opt in [["pc", "COMPUTER", "Mouse and keyboard.\nClick, drag to select, right-click\nto command, letter hotkeys."],
			["mobile", "MOBILE", "Touch.\nTap, drag, pinch to zoom.\nPlayed with the phone sideways."]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		var dev: String = opt[0]
		var b := _button(opt[1], func() -> void:
			Settings.set_device(dev)
			show_menu())
		b.custom_minimum_size = Vector2(250, 96)
		b.add_theme_font_override("font", UiStyle.title_font())
		b.add_theme_font_size_override("font_size", 28)
		if Settings.device == dev:
			UiStyle.chosen(b)
		col.add_child(b)
		col.add_child(UiStyle.text(opt[2], 16, UiStyle.MUTED))
		row.add_child(col)
	v.add_child(UiStyle.text("You can change this later in Settings.", 15, Color(1, 1, 1, 0.4)))


# ------------------------------------------------------------------ crash report
## While the game runs, user://running.txt says so (and what it was doing); it goes when the
## app is closed or sent to the background. If it's still there at start, the last session
## died (the phone killed the app, or the engine crashed): the report is the end of that
## session's engine log (Godot keeps the last few in user://logs), ready to copy.
const RUNNING := "user://running.txt"

func _mark_running(what: String) -> void:
	var f := FileAccess.open(RUNNING, FileAccess.WRITE)
	if f:
		f.store_string("v%s  %s  %s\n" % [version, Time.get_datetime_string_from_system(), what])
		f.close()
	print("[session] v%s %s" % [version, what])


func _crash_report() -> String:
	if not FileAccess.file_exists(RUNNING):
		return ""
	var what := FileAccess.get_file_as_string(RUNNING).strip_edges()
	DirAccess.remove_absolute(RUNNING)
	# the previous session's engine log: the newest of the rotated ones (this session's is godot.log)
	var logs := Array(DirAccess.get_files_at("user://logs")) if DirAccess.dir_exists_absolute("user://logs") else []
	logs = logs.filter(func(f: String) -> bool: return f.begins_with("godot") and f.ends_with(".log") and f != "godot.log")
	logs.sort()
	var tail := "(no engine log was kept)"
	if not logs.is_empty():
		var lines := FileAccess.get_file_as_string("user://logs/" + String(logs[-1])).strip_edges().split("\n")
		tail = "\n".join(lines.slice(maxi(0, lines.size() - 60)))
	return "PocketRTS crash report (v%s, %s)\nDevice: %s, %s\nThe last session was doing: %s\n--- end of its engine log ---\n%s" % [
		version, Time.get_datetime_string_from_system(), OS.get_name(), OS.get_model_name(), what, tail]


func show_crash(report: String) -> void:
	var root := _page()
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 40
	v.offset_right = -40
	v.offset_top = 20
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	v.add_child(UiStyle.heading("THE GAME CLOSED UNEXPECTEDLY", 34, UiStyle.TRIM))
	v.add_child(UiStyle.text("Last time the game didn't close normally (a crash, or the phone shut it). COPY the report and paste it to the developer. Your match was autosaved: CONTINUE is on the menu.", 17, UiStyle.MUTED))
	var box := TextEdit.new()
	box.text = report
	box.editable = false
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_font_size_override("font_size", 13)
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.add_child(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var copy := _button("COPY REPORT", func() -> void: pass)
	UiStyle.primary(copy)
	copy.custom_minimum_size = Vector2(260, 56)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(report)
		copy.text = "COPIED!")
	row.add_child(copy)
	var ok := _button("MENU", func() -> void: show_menu())
	ok.custom_minimum_size = Vector2(200, 56)
	row.add_child(ok)


func show_menu() -> void:
	sandbox_lobby = false        # (the main menu's SKIRMISH is never the sandbox)
	if Music.me:
		Music.me.menu()
	var root := _page()
	# the title on top, the buttons along the bottom: the landscapes stay in view
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_right = -24
	v.offset_top = 18
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	var title := UiStyle.heading("POCKET RTS", 72, UiStyle.TRIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.85))
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	v.add_child(title)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var save := SaveGame.peek()
	if not save.is_empty() and save.get("version", "") == version:
		var facs: Array = []
		for sl in save["cfg"]["slots"]:
			facs.append(String(sl["faction"]).capitalize())
		var secs := int(save["clock"])
		var cont := _button("CONTINUE  (%s, %d:%02d)" % [" vs ".join(facs), secs / 60, secs % 60], func() -> void:
			var cfg: Dictionary = save["cfg"].duplicate(true)
			cfg["resume"] = save
			start(cfg))
		UiStyle.primary(cont, Color("#2f6a8a"))
		cont.custom_minimum_size = Vector2(420, 54)
		var crow := HBoxContainer.new()
		crow.alignment = BoxContainer.ALIGNMENT_CENTER
		crow.add_child(cont)
		v.add_child(crow)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var items := [["EDITOR", func() -> void: show_editor_menu()], ["HOW TO PLAY", func() -> void: show_help()],
		["SKIRMISH", func() -> void: show_skirmish()], ["SETTINGS", func() -> void: show_settings()], ["MATCH LOGS", func() -> void: show_logs()]]
	for it in items:
		var b := _button(it[0], it[1])
		if it[0] == "SKIRMISH":
			UiStyle.primary(b)
			b.custom_minimum_size = Vector2(260, 64)
			b.add_theme_font_size_override("font_size", 28)
		else:
			b.custom_minimum_size = Vector2(196, 54)
		row.add_child(b)
	var ver := UiStyle.text("v%s  ·  playing on %s" % [version, "computer" if Settings.pc() else "mobile"], 14, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(ver)


## Match logs: every finished match (and the one still going) with a COPY button, to
## paste into a playtest report.
func show_logs() -> void:
	var root := _page()
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 40
	v.offset_right = -40
	v.offset_top = 20
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	v.add_child(UiStyle.heading("MATCH LOGS", 40, UiStyle.TRIM))
	v.add_child(UiStyle.text("COPY puts a match's log on the clipboard, ready to paste.", 17, UiStyle.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var files := Array(DirAccess.get_files_at("user://logs")) if DirAccess.dir_exists_absolute("user://logs") else []
	files = files.filter(func(f: String) -> bool: return f.begins_with("match_") or f == "unfinished.txt")   # (Godot keeps its own logs there too)
	files.sort()
	files.reverse()
	if files.has("unfinished.txt"):
		files.erase("unfinished.txt")
		files.push_front("unfinished.txt")
	if files.is_empty():
		list.add_child(UiStyle.text("No logs yet: play a match.", 20, UiStyle.MUTED))
	for fn in files:
		var path: String = "user://logs/" + fn
		var txt := FileAccess.get_file_as_string(path)
		var lines := txt.split("\n")
		var what: String = lines[1] if lines.size() > 1 else ""
		var result := ""
		for ln in lines:
			if ln.begins_with("RESULT"):
				result = ln
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		list.add_child(row)
		var name: String = "Unfinished or closed match" if fn == "unfinished.txt" else fn.trim_prefix("match_").trim_suffix(".txt").replace("_", "  ").replace("T", " ")
		var l := UiStyle.text("%s   ·   %s%s" % [name, what, ("   ·   " + result) if result != "" else ""], 17, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		var b := _button("COPY", func() -> void: pass)
		b.custom_minimum_size = Vector2(130, 46)
		b.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(txt)
			b.text = "COPIED!")
		row.add_child(b)
	var back := _button("BACK", func() -> void: show_menu())
	back.custom_minimum_size = Vector2(200, 54)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)


func _faction_card(f: String) -> Control:
	var p := PanelContainer.new()
	var sb := UiStyle.box(Color(0.08, 0.07, 0.055, 0.78), UiStyle.accent(f).darkened(0.1), 2, 12, 12.0)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(170, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var img := TextureRect.new()
	img.texture = load("res://assets/buildings/%s_built.png" % Defs.FACTIONS[f]["hall"])
	img.custom_minimum_size = Vector2(140, 130)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	v.add_child(img)
	v.add_child(UiStyle.heading(Defs.FACTIONS[f]["name"].to_upper(), 19, UiStyle.accent(f).lightened(0.35)))
	var tag := UiStyle.text(UiStyle.FACTION_TAG[f], 14, UiStyle.MUTED)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size.x = 140
	v.add_child(tag)
	return p


## Sandbox (a match where you can spawn anything) or the map editor.
func show_editor_menu() -> void:
	var root := _page()
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 620
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UiStyle.heading("EDITOR", 40, UiStyle.TRIM))
	for it in [["SANDBOX", "Set up any match, then spawn any unit or building for any player, hand out resources, lift the fog, take control of any side, switch AIs off and speed up time.", func() -> void:
				sandbox_lobby = true
				show_skirmish()],
			["MAP EDITOR", "Maps of any size, 1v1 to 4v4: paint high ground, ramps, water or lava, fords, trees and rocks in any biome, place decorations and start and hall spots with their teams, mirror it all for fairness, CHECK it, then save and play it in Skirmish.", func() -> void: show_map_editor()]]:
		var b := _button(it[0], it[2])
		b.custom_minimum_size.y = 64
		b.add_theme_font_override("font", UiStyle.title_font())
		b.add_theme_font_size_override("font_size", 26)
		v.add_child(b)
		var l := UiStyle.text(it[1], 16, UiStyle.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var back := _button("BACK", func() -> void: show_menu())
	v.add_child(back)


var sandbox_lobby := false
var _editor: MapEditor


## The map editor on one of your maps (by name), on a map's data (a new map of a chosen
## size, or one picked in the editor's LOAD), or on a blank classic-size map. The world is
## built at the map's size (Game.W x Game.H follow it).
func show_map_editor(name := "", data := {}) -> void:
	_clear_ui()
	if game:
		game.queue_free()
	if name != "":
		data = MapGen.load_custom(name)
	var sz := MapGen.custom_size(data)
	game = Game.new()
	game.edit_mode = true
	game.map_id = "blank:%dx%d" % [sz.x, sz.y]
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	_editor = MapEditor.new()
	_editor.game = game
	ui_layer.add_child(_editor)
	_editor.load_from(data)
	_editor.reopen_requested.connect(func(d: Dictionary) -> void: show_map_editor.call_deferred("", d))
	_editor.back_requested.connect(func() -> void:
		game.queue_free()
		game = null
		show_editor_menu())
	_editor.play_requested.connect(func(id: String, n: int) -> void:
		game.queue_free()
		game = null
		lobby["map"] = id
		while lobby["slots"].size() > n:
			lobby["slots"].pop_back()
		show_skirmish())


func show_settings() -> void:
	var root := _page()
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 520
	c.add_child(p)
	# the list scrolls when it's taller than the screen (a phone in a browser: FULL SCREEN too)
	var scr := ScrollContainer.new()
	scr.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scr)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scr.add_child(v)
	(func() -> void:
		if is_instance_valid(scr):
			scr.custom_minimum_size.y = minf(v.get_combined_minimum_size().y, get_viewport().get_visible_rect().size.y - 60.0)).call_deferred()
	v.add_child(UiStyle.heading("SETTINGS", 40, UiStyle.TRIM))
	v.add_child(_toggle_row("MUSIC", func() -> bool: return Music.me.music_on, func() -> void: Music.me.toggle_music()))
	v.add_child(_toggle_row("SOUND", func() -> bool: return Music.me.sound_on, func() -> void: Music.me.toggle_sound()))
	v.add_child(_toggle_row("AMBIENCE", func() -> bool: return Music.me.amb_on, func() -> void: Music.me.toggle_ambience()))
	v.add_child(_button("MUSIC PLAYER", func() -> void: show_music()))
	v.add_child(_button("INTERFACE LAYOUT & HOTKEYS", func() -> void: show_layout()))
	var dev := _button("PLAYING ON: %s" % ("COMPUTER" if Settings.pc() else "MOBILE"), func() -> void: show_device())
	var sizes := [0, 100, 125, 150, 175, 200]
	var sz_text := "AUTO (%d%%)" % int(Settings.ui_scale_now() * 100) if Settings.ui_size == 0 else "%d%%" % Settings.ui_size
	var sh := HBoxContainer.new()
	var sl := UiStyle.text("IN-GAME INTERFACE SIZE", 20, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sl)
	var szb := _button(sz_text, func() -> void:
		Settings.ui_size = sizes[(sizes.find(Settings.ui_size) + 1) % sizes.size()]
		Settings.save_all()
		show_settings())
	szb.custom_minimum_size = Vector2(190, 50)
	sh.add_child(szb)
	v.add_child(sh)
	v.add_child(dev)
	if OS.has_feature("web") and not Settings.pc():
		v.add_child(_toggle_row("FULL SCREEN", func() -> bool: return Settings.fullscreen, func() -> void:
			Settings.fullscreen = not Settings.fullscreen
			Settings.save_all()
			if Settings.fullscreen:
				_went_fullscreen = false
				_web_fullscreen()
			else:
				_web_leave_fullscreen(), "ON", "OFF"))
	if Settings.pc():
		v.add_child(_toggle_row("COMMAND KEYS", func() -> bool: return Settings.grid_keys, func() -> void:
			Settings.grid_keys = not Settings.grid_keys
			Settings.save_all(), "GRID (QWER/ASDF/ZXCV)", "BY NAME"))
	v.add_child(_toggle_row("TOOLTIPS", func() -> bool: return Settings.tooltips, func() -> void:
		Settings.tooltips = not Settings.tooltips
		Settings.save_all()))
	if not Settings.pc():
		v.add_child(_toggle_row("ONE-FINGER DRAG", func() -> bool: return Settings.drag_mode == "box", func() -> void:
			Settings.drag_mode = "pan" if Settings.drag_mode == "box" else "box"
			Settings.save_all(), "BOX-SELECTS", "MOVES THE VIEW"))
	v.add_child(_gap(4))
	var back := _button("BACK", func() -> void: show_menu())
	v.add_child(back)


## Interface layout profiles and hotkeys.
func show_layout() -> void:
	_clear_ui()
	var ed := LayoutEditor.new()
	ui_layer.add_child(ed)
	ed.done.connect(func() -> void: show_settings())


## The music player: how the match playlist is chosen, and every piece to listen to.
func show_music() -> void:
	var root := _page()
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 60)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	root.add_child(m)
	var p := PanelContainer.new()
	m.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var t := UiStyle.heading("MUSIC PLAYER", 32, UiStyle.TRIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UiStyle.text("IN A MATCH PLAY", 15, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, true))
	var mb := Button.new()
	mb.text = Music.MODE_NAMES[Music.me.mode]
	mb.custom_minimum_size = Vector2(390, 48)
	mb.add_theme_font_size_override("font_size", 16)
	mb.pressed.connect(func() -> void:
		var i := Music.MODES.find(Music.me.mode)
		Music.me.set_mode(Music.MODES[(i + 1) % Music.MODES.size()])
		Sfx.play_any(["ui/click", "click"])
		show_music())
	top.add_child(mb)
	var now := Music.me.now_playing()
	v.add_child(UiStyle.text(("Now playing: " + now) if now != "" else "Tap a piece to listen.", 16, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cols)
	var titles := Music.titles()
	for f in [["crown", "THE CROWN"], ["brood", "THE BROOD"], ["clock", "THE CLOCKWORK"]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		cols.add_child(col)
		var fac := "clockwork" if f[0] == "clock" else String(f[0])
		col.add_child(UiStyle.heading(f[1], 18, UiStyle.accent(fac).lightened(0.35)))
		for mood in ["peace", "battle"]:
			for stem in Music.pieces(f[0], mood):
				col.add_child(_track_row(stem, titles.get(stem, stem), mood))
	var ov := VBoxContainer.new()
	ov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov.add_theme_constant_override("separation", 6)
	cols.add_child(ov)
	ov.add_child(UiStyle.heading("OVERTURES", 18, UiStyle.TRIM))
	for stem in Music.menu_pieces():
		ov.add_child(_track_row(stem, titles.get(stem, stem), "menu"))
	var back := _button("BACK", func() -> void:
		Music.me.menu()
		show_settings())
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 220
	v.add_child(back)


func _track_row(stem: String, title: String, mood: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var play := Button.new()
	play.text = ("» " if Music.me._current == stem else "") + title
	play.alignment = HORIZONTAL_ALIGNMENT_LEFT
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.custom_minimum_size.y = 46
	play.clip_text = true
	play.add_theme_font_size_override("font_size", 16)
	play.tooltip_text = {"battle": "Battle", "menu": "Main menu"}.get(mood, "Calm")
	if mood == "battle":
		play.add_theme_color_override("font_color", Color(1, 0.75, 0.6))
	if Music.me._current == stem:
		UiStyle.chosen(play)
	play.pressed.connect(func() -> void:
		Music.me.preview(stem)
		show_music())
	h.add_child(play)
	if Music.me.mode == "picked" and mood != "menu":
		var tick := Button.new()
		var on := Music.me.is_enabled(stem)
		tick.text = "√" if on else ""
		tick.custom_minimum_size = Vector2(46, 46)
		if on:
			UiStyle.chosen(tick)
		tick.pressed.connect(func() -> void:
			Music.me.set_enabled(stem, not Music.me.is_enabled(stem))
			show_music())
		h.add_child(tick)
	return h


func _toggle_row(title: String, get_on: Callable, flip: Callable, on_text := "ON", off_text := "OFF") -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := UiStyle.text(title, 20, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 50)
	var refresh := func() -> void:
		var on: bool = get_on.call()
		b.text = on_text if on else off_text
		if on:
			UiStyle.chosen(b)
		else:
			for st in ["normal", "hover", "pressed"]:
				b.remove_theme_stylebox_override(st)
	refresh.call()
	b.pressed.connect(func() -> void:
		_web_fullscreen()
		flip.call()
		Sfx.play_any(["ui/toggle", "ui/click", "click"])
		refresh.call())
	h.add_child(b)
	return h


func show_help(section := "BASICS") -> void:
	var root := _page()
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 36 if side in ["left", "right"] else 22)
	root.add_child(m)
	var p := PanelContainer.new()
	m.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var t := UiStyle.heading("HOW TO PLAY", 34, UiStyle.TRIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	for k in HELP:
		var key: String = k
		var b := _button(key, func() -> void: show_help(key))
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 17)
		if key == section:
			UiStyle.chosen(b, UiStyle.accent(key.to_lower()) if UiStyle.ACCENT.has(key.to_lower()) else UiStyle.TRIM)
		top.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var l := UiStyle.text(HELP[section], 20, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(l)
	var back := _button("BACK", func() -> void: show_menu())
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 220
	v.add_child(back)


# ------------------------------------------------------------------ skirmish lobby

func show_skirmish() -> void:
	var root := _page()
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 30)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	root.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	# Title and quick set-ups
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var t := UiStyle.heading("SANDBOX" if sandbox_lobby else "SKIRMISH", 38, UiStyle.TRIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	for preset in ["1v1", "2v2", "3v3", "4v4", "1v2", "1v3", "FFA"]:
		var pr: String = preset
		var b := _button(pr, func() -> void:
			_preset(pr)
			_pool_for_preset(pr)
			_fit_map_to_slots()
			show_skirmish())
		b.custom_minimum_size = Vector2(64, 44)
		b.add_theme_font_size_override("font_size", 17)
		if _current_preset() == pr:
			UiStyle.chosen(b)
		top.add_child(b)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	# Players
	var pp := PanelContainer.new()
	pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(pp)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pp.add_child(pv)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	for col in [["PLAYER", 170], ["FACTION", 190], ["COLOUR", 110], ["PLAN", 150], ["TEAM", 80]]:
		var l := UiStyle.text(col[0], 14, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
		l.custom_minimum_size.x = col[1]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_stretch_ratio = col[1] / 100.0
		hdr.add_child(l)
	if lobby["slots"].size() > 2:
		var gap := Control.new()
		gap.custom_minimum_size.x = 46
		hdr.add_child(gap)
	pv.add_child(hdr)
	var slots: Array = lobby["slots"]
	# the rows scroll when there are more than fit (up to eight players)
	var rows_scroll := ScrollContainer.new()
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(rows_scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_scroll.add_child(rows)
	for i in slots.size():
		rows.add_child(_slot_row(i))
	if slots.size() < MAX_SLOTS:
		var add := _button("+  ADD PLAYER", func() -> void:
			_add_slot()
			_fit_map_to_slots()
			show_skirmish())
		add.custom_minimum_size = Vector2(0, 46)
		add.add_theme_font_size_override("font_size", 18)
		rows.add_child(add)
	var who_txt := "Same TEAM number = allies.  BRUTAL AI cheats (+50% income) and never lets up."
	if not slots.any(func(s: Dictionary) -> bool: return s["who"] == "you"):
		who_txt = "No YOU in the match: the computer plays every side and you watch."
	var note := UiStyle.text(who_txt, 15, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(note)
	# Map
	var mp := PanelContainer.new()
	mp.custom_minimum_size.x = 300
	body.add_child(mp)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	mp.add_child(mv)
	mv.add_child(UiStyle.text("MAP", 14, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	# the random pools, then every map by name (with its mode and size), then your own maps
	var ids: Array = []
	for p in MapGen.POOLS:
		ids.append(p[0])
	ids += MapGen.all_ids()
	var own := MapGen.custom_names()
	for n in own:
		ids.append("custom:" + n)
	if not ids.has(lobby["map"]):
		lobby["map"] = _preset_pool(_current_preset())
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 6)
	mv.add_child(mrow)
	var prev := _button("<", func() -> void:
		_pick_map(ids[(ids.find(lobby["map"]) - 1 + ids.size()) % ids.size()])
		show_skirmish())
	prev.custom_minimum_size = Vector2(46, 46)
	mrow.add_child(prev)
	var mid: String = lobby["map"]
	var mname := MapGen.label(mid) if MapGen.is_pool(mid) else (mid.substr(7) if mid.begins_with("custom:") else MapGen.display_name(mid))
	var map_opts: Array = []
	for mi in ids:
		if String(mi) == "custom:" + String(own[0] if not own.is_empty() else ""):
			map_opts.append(["- YOUR OWN MAPS -", "", true])
		map_opts.append([MapGen.label(mi), mi, false])
	var ml := _dropdown(mname.to_upper(), 160, map_opts, func(v) -> void: _pick_map(v), 470.0, MapGen.label(mid))
	ml.add_theme_font_size_override("font_size", 18)
	mrow.add_child(ml)
	var nxt := _button(">", func() -> void:
		_pick_map(ids[(ids.find(lobby["map"]) + 1) % ids.size()])
		show_skirmish())
	nxt.custom_minimum_size = Vector2(46, 46)
	mrow.add_child(nxt)
	var prv := MapPreview.new()
	prv.map_id = mid
	prv.slots = slots
	prv.custom_minimum_size = Vector2(270, 190)
	prv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_child(prv)
	var desc := ""
	if MapGen.is_pool(mid):
		var fit := MapGen.pool_maps(mid, slots.size())
		desc = "One of %d maps that hold %d players, picked when the match starts." % [fit.size(), slots.size()]
	elif mid.begins_with("custom:"):
		var cd := MapGen.load_custom(mid.substr(7))
		var cs := MapGen.custom_size(cd)
		desc = "Your map: %s, %dx%d, %d start spots.  %s.  %s" % [MapGen.custom_mode(cd), cs.x, cs.y,
			(cd.get("starts", []) as Array).size(), String(cd.get("biome", "grass")).replace("+", " & ").capitalize(),
			"Passed the editor's CHECK." if bool(cd.get("checked", false)) else "Not checked, or CHECK found problems."]
	elif MapData.NAMED.has(mid):
		var sz := MapGen.size_of(mid)
		desc = "%s, %dx%d, up to %d players. %s  %s." % [MapGen.mode_of(mid), sz.x, sz.y, MapGen.max_players(mid),
			String(MapData.NAMED[mid].get("about", "")), MapGen.biome_of(mid).replace("+", " & ").capitalize()]
	else:
		desc = {"crossroads": "Open ground around a central hill.", "highlands": "Main bases on high ground, one ramp down.",
			"rivers": "Rivers you can only cross at the fords."}[MapGen.MAPS[mid][1]]
		desc += "  84x60, up to 4 players.  " + String(MapGen.MAPS[mid][2]).replace("+", " & ").capitalize() + "."
	var dl := UiStyle.text(desc, 15, UiStyle.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mv.add_child(dl)
	# Bottom row
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var back := _button("BACK", func() -> void:
		_save_lobby()
		if sandbox_lobby:
			sandbox_lobby = false
			show_editor_menu()
		else:
			show_menu())
	back.custom_minimum_size = Vector2(200, 60)
	row.add_child(back)
	var problem := _lobby_problem()
	var watch := not slots.any(func(s: Dictionary) -> bool: return s["who"] == "you")
	var go := _button("WATCH" if watch else "START", func() -> void:
		_save_lobby()
		Sfx.play_any(["ui/start_match"])
		var cfg := lobby.duplicate(true)
		cfg["sandbox"] = sandbox_lobby
		start(cfg))
	go.custom_minimum_size = Vector2(300, 60)
	go.add_theme_font_size_override("font_size", 28)
	UiStyle.primary(go)
	go.disabled = problem != ""
	row.add_child(go)
	if problem != "":
		row.add_child(UiStyle.text(problem, 16, UiStyle.BAD))


func _slot_row(i: int) -> Control:
	var sl: Dictionary = lobby["slots"][i]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var colour: Color = Defs.colour_of(int(sl["colour"]))
	# who
	var who_opts: Array = []
	for w in WHO:
		var taken := false
		for j in lobby["slots"].size():
			if j != i and lobby["slots"][j]["who"] == "you":
				taken = true
		if w == "you" and taken:
			continue
		who_opts.append([WHO_LABEL[w], w, false])
	var who := _dropdown(WHO_LABEL[sl["who"]], 170, who_opts, func(v) -> void: sl["who"] = v)
	if sl["who"] == "brutal":
		who.add_theme_color_override("font_color", UiStyle.BAD)
	elif sl["who"] == "you":
		who.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	h.add_child(who)
	# faction
	var f: String = sl["faction"]
	var fac_opts: Array = []
	for ff in FACS:
		fac_opts.append(["RANDOM" if ff == "random" else String(Defs.FACTIONS[ff]["name"]).to_upper(), ff, false])
	var fb := _dropdown("RANDOM" if f == "random" else Defs.FACTIONS[f]["name"].to_upper(), 190, fac_opts, func(v) -> void: sl["faction"] = v)
	if f != "random":
		fb.icon = _faction_icon(f)
		fb.expand_icon = false
		fb.add_theme_constant_override("icon_max_width", 30)
		fb.add_theme_color_override("font_color", UiStyle.accent(f).lightened(0.4))
	h.add_child(fb)
	# colour
	var col_opts: Array = []
	for c in [Defs.COLOUR_FITS_MAP, Defs.COLOUR_RANDOM] + range(Defs.PALETTE.size()):
		col_opts.append([Defs.colour_name(int(c)).to_upper(), int(c), int(c) >= 0 and _colour_taken(int(c), i)])
	var cb := _dropdown(Defs.colour_name(int(sl["colour"])).to_upper(), 110, col_opts, func(v) -> void: sl["colour"] = v)
	for st in ["normal", "hover", "pressed"]:
		cb.add_theme_stylebox_override(st, UiStyle.box(colour.darkened(0.25 if st == "normal" else 0.1), Color(1, 1, 1, 0.5 if st == "normal" else 0.9), 2))
	cb.add_theme_color_override("font_color", Color(1, 1, 1))
	cb.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	h.add_child(cb)
	# strategy (computer players)
	if sl["who"] != "you":
		var st: String = String(sl.get("strategy", "balanced"))
		var opts: Array = ["random"] + AI.STRATEGIES.keys()
		var st_opts: Array = []
		for o in opts:
			st_opts.append(["RANDOM PLAN" if o == "random" else String(AI.STRATEGIES[o]["name"]).to_upper(), o, false])
		var sb := _dropdown("RANDOM PLAN" if st == "random" else String(AI.STRATEGIES[st]["name"]).to_upper(), 150, st_opts, func(v) -> void: sl["strategy"] = v)
		sb.tooltip_text = "How this computer player plays. Air rush is Brood only (others play Balanced)."
		h.add_child(sb)
	else:
		var sp := Control.new()
		sp.custom_minimum_size.x = 150
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.size_flags_stretch_ratio = 1.5
		h.add_child(sp)
	# team
	var team_opts: Array = []
	for k in MAX_SLOTS:
		team_opts.append(["TEAM %d" % (k + 1), k, false])
	var tb := _dropdown(str(int(sl["side"]) + 1), 80, team_opts, func(v) -> void: sl["side"] = v)
	tb.add_theme_font_size_override("font_size", 22)      # (the bold font: it has the arrow)
	h.add_child(tb)
	if lobby["slots"].size() > 2:
		var x := _button("×", func() -> void:
			lobby["slots"].remove_at(i)
			_fit_map_to_slots()
			show_skirmish())
		x.custom_minimum_size = Vector2(46, 58)
		h.add_child(x)
	return h


## A button that opens a list to pick from (big rows, easy to tap). items: [label, value, disabled].
func _dropdown(text: String, w: float, items: Array, pick: Callable, list_w := 240.0, current := "") -> Button:
	var b := Button.new()
	b.text = text + "  ▼"
	b.add_theme_font_override("font", UiStyle.bold_font())     # (it has the arrow; the title font doesn't)
	b.custom_minimum_size = Vector2(w, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = w / 100.0
	b.add_theme_font_size_override("font_size", 18)
	b.clip_text = true
	b.pressed.connect(func() -> void:
		_web_fullscreen()
		Sfx.play_any(["ui/click", "click"])
		_open_list(b, current if current != "" else text, items, pick, list_w)
	)
	return b


## The list a dropdown opens: big rows in the menu's own layer (not a separate popup
## window, which froze on some Android phones). A tap outside closes it.
func _open_list(b: Button, current: String, items: Array, pick: Callable, min_w := 240.0) -> void:
	var shade := Control.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.35)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(bg)
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			shade.queue_free())
	var panel := PanelContainer.new()
	panel.theme = UiStyle.theme()
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.08, 0.07, 0.055, 0.97), UiStyle.TRIM, 2, 8, 8.0))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var cur_row: Control = null
	for it in items:
		var row := Button.new()
		if String(it[0]).to_upper() == current.to_upper():
			cur_row = row
		row.text = ("√  " if String(it[0]).to_upper() == current.to_upper() else "     ") + String(it[0])
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 52)
		row.add_theme_font_size_override("font_size", 22)
		row.disabled = bool(it[2])
		var val = it[1]
		row.pressed.connect(func() -> void:
			shade.queue_free()
			pick.call(val)
			Sfx.play_any(["ui/click", "click"])
			show_skirmish())
		v.add_child(row)
	shade.add_child(panel)
	ui_layer.add_child(shade)
	# below the button if it fits, else above; never off the screen
	var vs := get_viewport().get_visible_rect().size
	var r := b.get_global_rect()
	var w := minf(maxf(r.size.x, min_w), vs.x - 20.0)
	var h := minf(items.size() * 56.0 + 20.0, vs.y - 20.0)
	var y := r.end.y + 4.0
	if y + h > vs.y - 10.0:
		y = maxf(10.0, r.position.y - h - 4.0) if r.position.y - h - 4.0 >= 10.0 else maxf(10.0, vs.y - 10.0 - h)
	panel.position = Vector2(clampf(r.position.x, 10.0, vs.x - w - 10.0), y)
	panel.size = Vector2(w, h)
	scroll.custom_minimum_size = Vector2(w - 20.0, h - 20.0)
	if cur_row:
		# a long list (the maps) opens with the current choice in view
		(func() -> void:
			await get_tree().process_frame
			if is_instance_valid(scroll) and is_instance_valid(cur_row):
				scroll.ensure_control_visible(cur_row)).call()


## A button that steps through options: click/tap = next; right click = previous.
func _cycle(text: String, w: float, step: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = w / 100.0
	b.add_theme_font_size_override("font_size", 18)
	b.clip_text = true
	b.pressed.connect(func() -> void:
		_web_fullscreen()
		step.call(1)
		Sfx.play_any(["ui/click", "click"])
		show_skirmish())
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			step.call(-1)
			Sfx.play_any(["ui/back", "ui/click", "click"])
			show_skirmish())
	return b


func _faction_icon(f: String) -> Texture2D:
	return load("res://assets/icons/%s.png" % Defs.FACTIONS[f]["hall"])


func _colour_taken(c: int, except: int) -> bool:
	for j in lobby["slots"].size():
		if j != except and int(lobby["slots"][j]["colour"]) == c:
			return true
	return false


func _add_slot() -> void:
	var slots: Array = lobby["slots"]
	var c := 0
	while _colour_taken(c, -1):
		c += 1
	var side := 1
	var used := {}
	for s in slots:
		used[int(s["side"])] = true
	if _current_preset() == "FFA" or used.size() == slots.size():
		side = 0
		while used.has(side):
			side += 1
	slots.append({"who": "normal", "faction": "random", "colour": c, "side": side})


func _preset(p: String) -> void:
	var slots: Array = lobby["slots"]
	var me: Dictionary = slots[0] if not slots.is_empty() else {"who": "you", "faction": "random", "colour": Defs.COLOUR_FITS_MAP, "side": 0}
	var n: int = {"1v1": 2, "2v2": 4, "3v3": 6, "4v4": 8, "1v2": 3, "1v3": 4, "FFA": 4}[p]
	var out: Array = [me]
	for i in range(1, n):
		var prev: Dictionary = slots[i] if i < slots.size() else {"who": "hard", "faction": "random", "colour": Defs.COLOUR_FITS_MAP, "strategy": "random"}
		out.append({"who": "hard" if prev["who"] == "you" else prev["who"], "faction": prev["faction"],
			"colour": int(prev.get("colour", Defs.COLOUR_FITS_MAP)), "side": 1, "strategy": prev.get("strategy", "random")})
	# keep chosen colours unique (fits-map and random ones are picked when the match starts)
	var used := {}
	for i in out.size():
		var c := int(out[i]["colour"])
		if c < 0:
			continue
		if used.has(c):
			out[i]["colour"] = Defs.COLOUR_FITS_MAP
		else:
			used[c] = true
	for i in out.size():
		match p:
			"2v2", "3v3", "4v4":
				out[i]["side"] = 0 if i < n / 2 else 1
			"FFA":
				out[i]["side"] = i
			_:
				out[i]["side"] = 0 if i == 0 else 1
	lobby["slots"] = out


## The random pool that goes with a preset: 1v1 -> random 1v1 maps, 2v2 -> 2v2 maps ... The
## uneven ones and the free-for-all (3 or 4 players) take the 2v2 maps (four starts each).
static func _preset_pool(p: String) -> String:
	return {"1v1": "random_1v1", "2v2": "random_2v2", "3v3": "random_3v3", "4v4": "random_4v4",
		"1v2": "random_2v2", "1v3": "random_2v2", "FFA": "random_2v2"}.get(p, "random_1v1")


## Clicking a preset picks its random pool, unless a map of that very mode is already chosen.
func _pool_for_preset(p: String) -> void:
	var mid: String = lobby["map"]
	if not MapGen.is_pool(mid) and MapGen.mode_of(mid) == p:
		return
	lobby["map"] = _preset_pool(p)


func _current_preset() -> String:
	var slots: Array = lobby["slots"]
	var sides: Array = slots.map(func(s: Dictionary) -> int: return int(s["side"]))
	var n := slots.size()
	var distinct := {}
	for s in sides:
		distinct[s] = true
	if n == 2 and distinct.size() == 2:
		return "1v1"
	if n == 4 and distinct.size() == 4:
		return "FFA"
	if n >= 4 and distinct.size() == 2 and sides.count(sides[0]) * 2 == n:
		return "%dv%d" % [n / 2, n / 2]
	if distinct.size() == 2 and sides.count(sides[0]) == 1:
		return "1v%d" % (n - 1)
	return ""


## A map picked in the lobby: the players are fitted to it. A named map sets up its own
## match (a 2v2 map: four players, two a side, keeping the first players' choices) unless
## the lobby already has its number of players; a classic map takes up to four, a map of
## your own as many as it has start spots. A random pool leaves the players as they are
## and picks, when the match starts, among its maps that hold them all.
func _pick_map(id: String) -> void:
	lobby["map"] = id
	var n: int = lobby["slots"].size()
	if MapGen.is_pool(id):
		return
	if id.begins_with("custom:"):
		# a map with two even teams sets up its match (a 2v2 map: four players, two a
		# side); otherwise the players are trimmed to its start spots
		var st := MapGen.max_players(id)
		var md := MapGen.mode_of(id)
		if n != st and md in ["1v1", "2v2", "3v3", "4v4"]:
			_preset(md)
		while lobby["slots"].size() > maxi(st, 2):
			lobby["slots"].pop_back()
		return
	if MapData.NAMED.has(id):
		if n != MapGen.max_players(id):
			_preset(MapGen.mode_of(id))
	elif n > MapGen.max_players(id):
		_preset("1v1")


## The players changed (a preset, a player added or taken away): a map that no longer
## holds them all gives way to the random pool for that many players.
func _fit_map_to_slots() -> void:
	var mid: String = lobby["map"]
	var n: int = lobby["slots"].size()
	if MapGen.is_pool(mid) or MapGen.max_players(mid) >= n:
		if not (MapGen.is_pool(mid) and MapGen.pool_maps(mid, n).is_empty()):
			return
	lobby["map"] = "random_1v1" if n <= 2 else ("random_2v2" if n <= 4 else ("random_3v3" if n <= 6 else "random_4v4"))


func _lobby_problem() -> String:
	var mid: String = lobby["map"]
	var np: int = lobby["slots"].size()
	if mid.begins_with("custom:"):
		var n := (MapGen.load_custom(mid.substr(7)).get("starts", []) as Array).size()
		if np > n:
			return "This map has %d start spots." % n
	elif MapGen.is_pool(mid):
		if MapGen.pool_maps(mid, np).is_empty():
			return "No map in this pool holds %d players." % np
	elif MapGen.max_players(mid) < np:
		return "%s holds %d players." % [MapGen.display_name(mid), MapGen.max_players(mid)]
	var distinct := {}
	for s in lobby["slots"]:
		distinct[int(s["side"])] = true
	if distinct.size() < 2:
		return "Everyone is on one team."
	return ""


func _load_lobby() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Settings.PATH) == OK and cfg.has_section_key("lobby", "setup"):
		var l: Variant = cfg.get_value("lobby", "setup")
		if l is Dictionary and l.has("slots") and (l["slots"] as Array).size() >= 2:
			lobby = l
			if String(lobby.get("map", "")) == "random":
				lobby["map"] = _preset_pool(_current_preset())    # (the old default: all maps)


func _save_lobby() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	cfg.set_value("lobby", "setup", lobby)
	cfg.save(Settings.PATH)


# ------------------------------------------------------------------ helpers

func _clear_ui() -> void:
	for c in ui_layer.get_children():
		c.queue_free()


func _theme() -> Theme:
	return UiStyle.theme()


func _label(t: String, sz: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return UiStyle.text(t, sz, col, align)


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(func() -> void:
		_web_fullscreen()
		Sfx.play_any(["ui/click", "click"])
		cb.call())
	if Settings.pc():
		b.mouse_entered.connect(func() -> void: Sfx.play_any(["ui/hover"], Vector2.INF, -8.0))
	return b


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


# ------------------------------------------------------------------ backdrop and map preview

## The menu background: a strip of countryside with each faction's hall and a slow
## procession of its soldiers, under a dark vignette.
class MenuBackdrop extends Control:
	## The three realms side by side, each slowly panning over its painting; every so often
	## one of them comes forward and fills the screen for a while.
	var t := 0.0
	var _art: Array = []
	const REALMS := ["crown", "clockwork", "brood"]
	const HOLD := 9.0          # seconds the triptych holds, then one realm takes the screen

	func _ready() -> void:
		for r in REALMS:
			var p := "res://assets/menu/%s.png" % r
			_art.append(load(p) if ResourceLoader.exists(p) else null)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	## Draw `tex` to cover `r`, panning top-to-bottom with phase `ph`.
	func _cover(tex: Texture2D, r: Rect2, ph: float, zoom := 1.0, alpha := 1.0) -> void:
		if tex == null:
			return
		var ts := tex.get_size()
		var sc := maxf(r.size.x / ts.x, r.size.y / ts.y) * zoom
		var src_size := r.size / sc
		var free := ts - src_size
		var pan := 0.5 - 0.5 * cos(ph)            # 0..1..0
		var src := Rect2(Vector2(free.x * 0.5, free.y * pan), src_size)
		draw_texture_rect_region(tex, r, src, Color(1, 1, 1, alpha))

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BG)
		var n := _art.size()
		if n == 0:
			return
		# cycle: triptych (HOLD s) -> realm 1 full (HOLD s) -> triptych -> realm 2 full ...
		var cyc := HOLD * 2.0
		var k := int(t / cyc)
		var in_cyc := fmod(t, cyc)
		var focus := k % n
		var f := smoothstep(HOLD - 1.5, HOLD + 0.5, in_cyc) * (1.0 - smoothstep(cyc - 2.0, cyc, in_cyc))
		var col_w := size.x / n
		for i in n:
			var r := Rect2(Vector2(i * col_w, 0), Vector2(col_w + 1, size.y))
			_cover(_art[i], r, t * 0.05 + i * 2.1, 1.08 + 0.04 * sin(t * 0.07 + i), 1.0 - f * 0.85)
			# the gold seams between the panels
			if i > 0:
				draw_rect(Rect2(i * col_w - 1, 0, 3, size.y), Color(0.79, 0.64, 0.29, 0.7 * (1.0 - f)))
		if f > 0.0:
			_cover(_art[focus], Rect2(Vector2.ZERO, size), t * 0.04, 1.0 + 0.06 * f, f)
		# a dark band behind the menu column, fading to the right
		var w := size.x * 0.6
		var dark := Color(0.04, 0.03, 0.02, 0.88)
		var clear := Color(0.04, 0.03, 0.02, 0.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, size.y), Vector2(0, size.y)]),
			PackedColorArray([dark, clear, clear, dark]))
		# vignette top and bottom
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, 90), Vector2(0, 90)]),
			PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		draw_polygon(PackedVector2Array([Vector2(0, size.y - 120), Vector2(size.x, size.y - 120), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6)]))
		draw_rect(Rect2(0, 0, size.x, 5), Color(0.79, 0.64, 0.29, 0.55))
		draw_rect(Rect2(0, size.y - 5, size.x, 5), Color(0.79, 0.64, 0.29, 0.55))


## A small schematic of a map: its biome colours, the hills, rivers and where everyone starts.
class MapPreview extends Control:
	var map_id := "random"
	var slots: Array = []
	var mw := 84.0               # the map's size in cells
	var mh := 60.0
	var _pic: Texture2D

	func _draw() -> void:
		var msz := Vector2(84, 60) if MapGen.is_pool(map_id) else Vector2(MapGen.size_of(map_id))
		mw = msz.x
		mh = msz.y
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var ratio := float(mw) / float(mh)
		if r.size.x / r.size.y > ratio:
			var w := r.size.y * ratio
			r = Rect2(r.position + Vector2((r.size.x - w) * 0.5, 0), Vector2(w, r.size.y))
		else:
			var hh := r.size.x / ratio
			r = Rect2(r.position + Vector2(0, (r.size.y - hh) * 0.5), Vector2(r.size.x, hh))
		var sb := UiStyle.box(Color(0, 0, 0, 0.5), UiStyle.TRIM_DIM, 2, 8, 0.0)
		sb.draw(get_canvas_item(), r.grow(4))
		if map_id.begins_with("custom:"):
			_custom(r)
			return
		if MapData.NAMED.has(map_id):
			_named(r)
			return
		if not MapGen.MAPS.has(map_id):
			draw_rect(r, Color(0.2, 0.18, 0.14))
			var f := ThemeDB.fallback_font
			draw_string(f, r.get_center() + Vector2(-12, 22), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, UiStyle.MUTED)
			if slots.size() <= 4:
				_starts(r)
			return
		var m: Array = MapGen.MAPS[map_id]
		var parts: PackedStringArray = String(m[2]).split("+")
		var ca := _biome_col(parts[0])
		var cb := _biome_col(parts[1] if parts.size() > 1 else parts[0])
		draw_rect(r, ca)
		if parts.size() > 1:
			var pts := PackedVector2Array([r.position + Vector2(0, r.size.y), r.position + Vector2(r.size.x, r.size.y), r.position + Vector2(0, 0)])
			pts = PackedVector2Array([r.position, r.position + Vector2(0, r.size.y), r.end])
			draw_colored_polygon(pts, cb)
		var k := r.size / Vector2(mw, mh)
		var four := slots.size() > 2
		var hill := ca.lightened(0.25)
		match m[1]:
			"crossroads":
				draw_circle(r.position + Vector2(42, 30) * k, 5.5 * k.x, hill)
			"highlands":
				for c in ([Vector2(9, 8), Vector2(mw - 9, 8), Vector2(9, mh - 8), Vector2(mw - 9, mh - 8)] if four else [Vector2(9, 8), Vector2(mw - 9, mh - 8)]):
					draw_circle(r.position + c * k, 12.0 * k.x, hill)
				draw_circle(r.position + Vector2(42, 30) * k, 4.0 * k.x, hill)
			"rivers":
				var water := Color(0.15, 0.4, 0.7)
				if four:
					draw_line(r.position + Vector2(r.size.x * 0.5, 0), r.position + Vector2(r.size.x * 0.5, r.size.y), water, 5.0)
					draw_line(r.position + Vector2(0, r.size.y * 0.5), r.position + Vector2(r.size.x, r.size.y * 0.5), water, 5.0)
				else:
					draw_line(r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), water, 7.0)
		_starts(r)

	## A named map: its picture (assets/maps, made by tools/make_map_previews.gd) and where
	## everyone starts, allies on the same side.
	func _named(r: Rect2) -> void:
		var path := "res://assets/maps/%s.png" % map_id
		if ResourceLoader.exists(path):
			_pic = load(path)       # (kept: a texture let go right after drawing shows up white)
			draw_texture_rect(_pic, r, false)
		else:
			draw_rect(r, _biome_col(MapGen.biome_of(map_id).split("+")[0]))
		var k := r.size / Vector2(mw, mh)
		var sides: Array = slots.map(func(s: Dictionary) -> int: return int(s["side"]))
		if sides.size() > MapGen.max_players(map_id):
			return
		var st := MapGen.named_starts(map_id, sides)
		var f := ThemeDB.fallback_font
		for i in st.size():
			var p: Vector2 = r.position + (Vector2(st[i]) + Vector2(2.5, 2)) * k
			draw_circle(p, 9.0, Color(0, 0, 0, 0.6))
			draw_circle(p, 7.0, Defs.colour_of(int(slots[i]["colour"])))
			draw_string(f, p + Vector2(-4, 5), str(int(slots[i]["side"]) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	## One of your maps: the picture the editor saved with it (or a sketch of its cells),
	## and where everyone starts, allies together as in the match.
	func _custom(r: Rect2) -> void:
		var nm := map_id.substr(7)
		var d := MapGen.load_custom(nm)
		if _pic == null or not has_meta("pic") or get_meta("pic") != nm:
			_pic = MapGen.custom_picture(nm)
			set_meta("pic", nm)
		var k := r.size / Vector2(mw, mh)
		if _pic:
			draw_texture_rect(_pic, r, false)
		else:
			var cells: String = d.get("cells", "")
			var parts: PackedStringArray = String(d.get("biome", "grass")).split("+")
			var low := _biome_col(parts[0])
			var cols := {".": low, "h": low.lightened(0.25), "r": low.lightened(0.12), "w": Color(0.15, 0.4, 0.7),
				"f": Color(0.4, 0.6, 0.75), "t": low.darkened(0.45), "T": low.darkened(0.3), "k": Color(0.5, 0.5, 0.5), "K": Color(0.6, 0.6, 0.6)}
			draw_rect(r, low)
			var cw := int(mw)
			for i in mini(cells.length(), int(mw * mh)):
				if cells[i] != ".":
					draw_rect(Rect2(r.position + Vector2(i % cw, i / cw) * k, k + Vector2(0.5, 0.5)), cols.get(cells[i], low))
		if slots.size() > (d.get("starts", []) as Array).size():
			return
		var sides: Array = slots.map(func(s: Dictionary) -> int: return int(s["side"]))
		var st := MapGen.custom_starts(d, sides)
		var f := ThemeDB.fallback_font
		for i in st.size():
			var p: Vector2 = r.position + (Vector2(st[i]) + Vector2(2.5, 2)) * k
			draw_circle(p, 9.0, Color(0, 0, 0, 0.6))
			draw_circle(p, 7.0, Defs.colour_of(int(slots[i]["colour"])))
			draw_string(f, p + Vector2(-4, 5), str(int(slots[i]["side"]) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	func _starts(r: Rect2) -> void:
		var k := r.size / Vector2(mw, mh)
		var corners: Array = [Vector2(8, 8), Vector2(mw - 8, mh - 8)]
		if slots.size() > 2:
			corners = [Vector2(8, 8), Vector2(8, mh - 8), Vector2(mw - 8, 8), Vector2(mw - 8, mh - 8)]
		# allies share a side, like the real placement
		var order: Array = range(slots.size())
		order.sort_custom(func(a: int, b: int) -> bool:
			return int(slots[a]["side"]) < int(slots[b]["side"]) or (slots[a]["side"] == slots[b]["side"] and a < b))
		var use: Array = [0, 1, 2, 3]
		if slots.size() == 3:
			var cnt := {}
			for s in slots:
				cnt[int(s["side"])] = int(cnt.get(int(s["side"]), 0)) + 1
			use = [0, 3, 2]
			if cnt.size() == 2:
				use = [0, 1, 3] if int(cnt[int(slots[order[0]]["side"])]) == 2 else [0, 2, 3]
		for i in order.size():
			var s: Dictionary = slots[order[i]]
			var p: Vector2 = r.position + corners[use[i]] * k
			draw_circle(p, 9.0, Color(0, 0, 0, 0.6))
			draw_circle(p, 7.0, Defs.colour_of(int(s["colour"])))
			var f := ThemeDB.fallback_font
			draw_string(f, p + Vector2(-4, 5), str(int(s["side"]) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	func _biome_col(b: String) -> Color:
		var low: Array = MapGen.BIOMES.get(b, MapGen.BIOMES["grass"])["low"]
		var c: Color = TerrainData.COLOURS.get(low[0], TerrainData2.COLOURS.get(low[0], Color(0.3, 0.45, 0.2)))
		return c.darkened(0.1)


# ------------------------------------------------------------------ rotate your phone

var _rotate: Control


func _make_rotate_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_rotate = Control.new()
	_rotate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate.visible = false
	layer.add_child(_rotate)
	var bg := ColorRect.new()
	bg.color = Color("#0d110e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate.add_child(bg)
	var icon := RotateIcon.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.position = Vector2(-120, -300)
	icon.custom_minimum_size = Vector2(240, 240)
	icon.scale = Vector2(2, 2)
	icon.position = Vector2(-240, -360)
	_rotate.add_child(icon)
	var l := _label("Turn your phone sideways", 72)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.position = Vector2(-300, 40)
	l.custom_minimum_size = Vector2(600, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotate.add_child(l)
	var l2 := _label("Pocket RTS plays in landscape.", 40, Color(1, 1, 1, 0.6))
	l2.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l2.position = Vector2(-300, 250)
	l2.custom_minimum_size = Vector2(600, 0)
	_rotate.add_child(l2)


var _rotate_paused := false


var _save_t := 0.0
var _f11_hint: PanelContainer
var _f11_t := 0.0


## Autosave the match every 15 s (and the log with it), so closing the game loses nothing.
func _autosave() -> void:
	if game == null or game.over or game.demo or game.edit_mode:
		return
	var pt := Time.get_ticks_usec()
	var cfg := last_cfg.duplicate(true)
	cfg.erase("resume")
	print("[save] %d:%02d  %d units, %d buildings  mem %d MB" % [int(game.clock) / 60, int(game.clock) % 60, game.units.size(), game.buildings.size(), int(OS.get_static_memory_usage() / 1048576)])
	SaveGame.save(game, cfg)
	if game.mlog:
		_write_log("user://logs/unfinished.txt", game.mlog.text())
	Prof.add("autosave", pt)
	print("[save] done")


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_autosave()
	# closed or sent to the background on purpose: not a crash (back in front: running again)
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		DirAccess.remove_absolute(RUNNING)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_mark_running("resumed" if game == null else "resumed a match")


func _process(delta: float) -> void:
	if game and not game.over and not get_tree().paused:
		_save_t += delta
		if _save_t >= 15.0:
			_save_t = 0.0
			_autosave()
	_f11_t -= delta
	if _f11_t <= 0.0:
		_f11_t = 0.5
		_update_f11_hint()
	if _rotate == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var portrait := Settings.device == "mobile" and vs.y > vs.x * 1.05
	if portrait != _rotate.visible:
		_rotate.visible = portrait
		# hold the match while the phone is upright
		if game and not game.over:
			if portrait and not get_tree().paused:
				get_tree().paused = true
				_rotate_paused = true
			elif not portrait and _rotate_paused:
				get_tree().paused = false
				_rotate_paused = false


## Browser on a computer: in the menus (never in a match) a line under the buttons says how
## full screen works: F11 in, F11 again out. (A page can't put the browser in a full screen
## that Esc won't undo, so it's the browser's own.)
func _update_f11_hint() -> void:
	var show := OS.has_feature("web") and Settings.pc() and game == null
	if not show:
		if _f11_hint:
			_f11_hint.visible = false
		return
	if _f11_hint == null:
		var layer := CanvasLayer.new()
		layer.layer = 30
		add_child(layer)
		_f11_hint = PanelContainer.new()
		_f11_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_f11_hint.add_theme_stylebox_override("panel", UiStyle.box(Color(0.105, 0.09, 0.07, 0.75), UiStyle.TRIM, 1, 8, 2.0))
		var l := UiStyle.text("Press F11 to go full screen, and F11 again to leave it", 16, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_f11_hint.add_child(l)
		_f11_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_f11_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_f11_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_f11_hint.offset_bottom = -3
		layer.add_child(_f11_hint)
	_f11_hint.visible = true


## A phone outline with a turning arrow.
class RotateIcon extends Control:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var a := -PI * 0.5 * clampf(fmod(t, 2.2) / 1.2, 0.0, 1.0)
		draw_set_transform(c, a, Vector2.ONE)
		draw_rect(Rect2(-24, -42, 48, 84), Color(1, 1, 1), false, 4.0)
		draw_circle(Vector2(0, 32), 3, Color(1, 1, 1))
		draw_set_transform(Vector2.ZERO)
		draw_arc(c, 58, -PI * 0.9, -PI * 0.55, 16, Color(1, 0.85, 0.4), 4.0)


# ------------------------------------------------------------------ match

const LEVELS := ["easy", "normal", "hard", "brutal"]
var last_cfg := {}


## Start a match. cfg = {"map": id, "slots": [{"who": "you"|"easy"|"normal"|"hard"|"brutal",
## "faction": name|"random", "colour": palette index, "side": n}, ...]} (2-4 slots).
## With no "you" slot the computer plays every side and you watch.
func start(cfg: Dictionary = {}) -> void:
	_clear_ui()
	if game:
		game.queue_free()
	if cfg.is_empty():
		cfg = last_cfg
	if not cfg.has("seed"):
		cfg["seed"] = randi()
	cfg = cfg.duplicate(true)
	# a random map is picked here (among the pool's maps that hold everyone), so colours can
	# be chosen to suit its ground
	var pool := String(cfg.get("map", "random"))
	if MapGen.is_pool(pool):
		var fit := MapGen.pool_maps(pool, (cfg["slots"] as Array).size())
		if fit.is_empty():
			fit = MapGen.pool_maps("random", (cfg["slots"] as Array).size())
		cfg["map"] = fit[randi() % fit.size()]
	_resolve_colours(cfg)
	last_cfg = cfg.duplicate(true)
	var slots: Array = cfg["slots"]
	var facs: Array = []
	var cols: Array = []
	var sides: Array = []
	var mult: Array = []
	var human := -1
	var top := 0
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var f: String = sl["faction"]
		facs.append(["crown", "brood", "clockwork"][randi() % 3] if f == "random" else f)
		last_cfg["slots"][i]["faction"] = facs[i]     # a continued match keeps the same factions
		cols.append(int(sl["colour"]))
		sides.append(int(sl["side"]))
		var lvl := LEVELS.find(sl["who"])
		mult.append(1.5 if lvl == 3 else 1.0)
		if sl["who"] == "you" and human < 0:
			human = i
		top = maxi(top, lvl)
	game = Game.new()
	game.demo = human < 0
	game.human = maxi(human, 0)
	game.difficulty = top
	game.factions = facs
	game.colours = cols
	game.sides = sides
	game.income_mult = mult
	game.map_id = cfg.get("map", "random")
	game.sandbox = cfg.get("sandbox", false)
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.rng.seed = int(cfg["seed"])
	_mark_running("match on %s: %s (seed %d)%s" % [game.map_id, " vs ".join(facs), int(cfg["seed"]), " (continued)" if cfg.has("resume") else ""])
	add_child(game)
	print("[match] map ready")
	sfx.camera = game.camera
	for t in slots.size():
		if t == human:
			continue
		var ai := AI.new()
		ai.game = game
		ai.team = t
		ai.difficulty = maxi(0, LEVELS.find(slots[t]["who"]))
		var strat: String = String(slots[t].get("strategy", "balanced"))
		var allowed := AI.strategies_for(facs[t])
		if strat == "random" or not allowed.has(strat):
			strat = "balanced" if strat != "random" else allowed[randi() % allowed.size()]
		ai.strategy = strat
		last_cfg["slots"][t]["strategy"] = strat
		game.add_child(ai)
		game.ais.append(ai)
	if game.mlog:
		var lv := {}
		for t in slots.size():
			if t != human:
				lv[t] = String(slots[t]["who"]).to_upper()
				for ai2 in game.ais:
					if ai2.team == t:
						lv[t] += ", " + String(AI.STRATEGIES[ai2.strategy]["name"]).to_upper()
		game.mlog.begin(lv)
		if game.sandbox:
			game.mlog.add("(sandbox match)")
	var c := Controls.new()
	c.game = game
	game.controls = c
	game.add_child(c)
	var hud := preload("res://scripts/ui/hud.gd").new()
	hud.game = game
	hud.controls = c
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	c.hud = hud
	game.hud = hud
	ui_layer.add_child(hud)
	hud.quit_requested.connect(func() -> void: _to_menu())
	if game.demo:
		# computers only: the VIEW dropdown (all vision, a player's vision, follow a player)
		var sp := Spectator.new()
		sp.game = game
		game.spectator = sp
		game.add_child(sp)
	if game.sandbox:
		var sbx := SandboxPanel.new()
		sbx.game = game
		ui_layer.add_child(sbx)
	game.ended.connect(_on_end)
	var foes: Array = []
	for t in game.n_players():
		if game.hostile(t, game.human):
			foes.append(game.faction_of(t))
	Music.me.match_started(game.faction_of(game.human), foes)
	var amb: String = game.mapgen.biome_a if game.mapgen else ""
	Music.me.ambience(String(MapGen.BIOMES.get(amb, {}).get("amb", amb)))
	if cfg.has("resume"):
		SaveGame.restore(game, cfg["resume"])
		last_cfg.erase("resume")
	_save_t = 0.0
	if not game.demo:
		hud.start_countdown(3.0)


func _to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if game:
		# a watched match left before its end still keeps its log (MATCH LOGS)
		if game.demo and not game.over and game.mlog:
			game.mlog.add("(stopped watching before the end)")
			game._sample_stats()
			game.mlog.finish(-1)
			_save_log(game.mlog.text())
		game.queue_free()
		game = null
	show_menu()


func _on_end(winner: int) -> void:
	var won := game.demo or (winner >= 0 and game.allied(winner, game.human))
	Music.me.match_ended(won, game.faction_of(maxi(winner, 0) if game.demo else game.human))
	if not game.demo:
		Sfx.announce(game.faction_of(game.human), "victory" if won else "defeat", 1.0)
	game._sample_stats()
	if game.mlog:
		game.mlog.finish(winner)
		_save_log(game.mlog.text())
	SaveGame.clear()
	await get_tree().create_timer(1.2, true, false, true).timeout
	if game == null:
		return
	var o := preload("res://scripts/ui/battle_report.gd").new()
	o.game = game
	o.winner = winner
	o.theme = _theme()
	o.process_mode = Node.PROCESS_MODE_ALWAYS
	o.play_again.connect(func() -> void: start())
	o.to_menu.connect(func() -> void: _to_menu())
	ui_layer.add_child(o)


## RANDOM / FITS MAP colours become real palette colours, all different.
func _resolve_colours(cfg: Dictionary) -> void:
	var slots: Array = cfg["slots"]
	var used := {}
	for sl in slots:
		if int(sl["colour"]) >= 0:
			used[int(sl["colour"])] = true
	var avoid: Array = []
	var mid: String = String(cfg.get("map", ""))
	if MapGen.MAPS.has(mid) or MapData.NAMED.has(mid):
		for biome in MapGen.biome_of(mid).split("+"):
			avoid += Defs.BIOME_AVOID.get(biome, [])
	for sl in slots:
		var c := int(sl["colour"])
		if c >= 0:
			continue
		var free: Array = range(Defs.PALETTE.size()).filter(func(k: int) -> bool: return not used.has(k))
		if c == Defs.COLOUR_FITS_MAP:
			var fit: Array = free.filter(func(k: int) -> bool: return not avoid.has(Defs.PALETTE[k][0]))
			if not fit.is_empty():
				free = fit
		var pick: int = free[randi() % free.size()] if not free.is_empty() else 0
		sl["colour"] = pick
		used[pick] = true


## Every match log is also kept in user://logs (the last 20).
func _save_log(t: String) -> void:
	var name := "user://logs/match_%s.txt" % Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	_write_log(name, t)
	if FileAccess.file_exists("user://logs/unfinished.txt"):
		DirAccess.remove_absolute("user://logs/unfinished.txt")


func _write_log(path: String, t: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(t)
		f.close()
	var files := Array(DirAccess.get_files_at("user://logs")).filter(func(f: String) -> bool: return f.begins_with("match_"))
	files.sort()
	while files.size() > 20:
		DirAccess.remove_absolute("user://logs/" + String(files.pop_front()))


## Web: go full screen on the first click or tap (browsers only allow it then), and on a
## computer ask the browser to give Esc to the game: Chrome and Edge then leave full screen
## only when Esc is HELD, so a quick Esc just closes a card. Settings > FULL SCREEN turns it off.
## (Phones only: on a computer the browser's own full screen (F11) is used, which Esc never
## leaves; the game's kind is left by Esc in some browsers, Brave among them.)
func _web_fullscreen() -> void:
	if _went_fullscreen or not OS.has_feature("web") or not Settings.fullscreen or Settings.pc():
		return
	_went_fullscreen = true
	JavaScriptBridge.eval("""
		(function(){
			var el = document.documentElement;
			if (document.fullscreenElement) return;
			var req = el.requestFullscreen || el.webkitRequestFullscreen;
			if (!req) return;
			var p = req.call(el, {navigationUI: 'hide'});
			if (p && p.then) p.then(function(){
				if (navigator.keyboard && navigator.keyboard.lock) navigator.keyboard.lock(['Escape']).catch(function(){});
				if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(function(){});
			}).catch(function(){});
		})();
	""", true)


func _web_leave_fullscreen() -> void:
	if not OS.has_feature("web"):
		return
	_went_fullscreen = false
	JavaScriptBridge.eval("""
		(function(){
			if (navigator.keyboard && navigator.keyboard.unlock) navigator.keyboard.unlock();
			if (document.fullscreenElement && document.exitFullscreen) document.exitFullscreen();
		})();
	""", true)


func _input(event: InputEvent) -> void:
	# APM: every click, tap and key press while you play (not while paused, watching or over)
	if game and not game.over and not game.demo and not game.edit_mode and not get_tree().paused:
		if (event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]) \
				or (event is InputEventKey and event.pressed and not event.echo) \
				or (event is InputEventScreenTouch and event.pressed):
			game.note_action()
	# a click or tap while not in full screen (the first one, or after leaving it): full screen
	# again, the kind where the game keeps Esc (if the setting is on)
	if _went_fullscreen and OS.has_feature("web") and Settings.fullscreen and not Settings.pc() \
			and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)) \
			and not bool(JavaScriptBridge.eval("!!(document.fullscreenElement || window.innerHeight >= screen.height - 2)", true)):
		_went_fullscreen = false
	if not _went_fullscreen and OS.has_feature("web") and Settings.fullscreen and not Settings.pc() \
			and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		_web_fullscreen()
