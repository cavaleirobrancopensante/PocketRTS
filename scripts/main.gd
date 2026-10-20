extends Node
## Main menu, the skirmish lobby, starting a match, and the end-of-match screen.

var version: String = ProjectSettings.get_setting("application/config/version", "dev")
var sfx: Sfx
var game: Game
var ui_layer: CanvasLayer
var menu: Control
var _went_fullscreen := false
var _backdrop: MenuBackdrop

## The skirmish setup, remembered between sessions.
var lobby := {
	"map": "random",
	"slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "normal", "faction": "brood", "colour": 1, "side": 1},
	],
}

const WHO := ["you", "easy", "normal", "hard", "brutal"]
const WHO_LABEL := {"you": "YOU", "easy": "EASY AI", "normal": "NORMAL AI", "hard": "HARD AI", "brutal": "BRUTAL AI"}
const FACS := ["crown", "brood", "clockwork", "random"]

const HELP := {
	"BASICS": """Destroy every enemy building to win.

There are no resources on the map: each faction builds its own economy. Every Town Hall, Hive or Clocktower allows only so many economy structures nearby, so expanding to a new hall spot is how you grow, and the expansions are what you fight over.

Area damage (canister, round shot, steam, spit blobs, storms) hurts your own units too: keep your men out of the blast.

High ground: units below a cliff can't see up onto it, and ramps are the only way up. Rivers can only be crossed at the fords.

Skirmish: up to four players. Each computer player has a PLAN (Balanced, Rush, Economy, Timing attack, Air rush for the Brood, or Random). Give players the same TEAM number to make them allies. BRUTAL AI never stops, micro-manages every fight and cheats (+50% income).""",
	"CROWN": """THE CROWN: pike, shot and black powder.

Labourers work Farms (up to 3 each): a farm ripens into a 350-gold harvest, faster with more hands. The Powder Mill makes black powder; muskets and cannons can't fire without it. Each Town Hall allows 4 Farms and 1 Powder Mill nearby.

Walls and gates: lay them in a line across your ramp (every main base sits on high ground with one way up); gates open for your side only.

Musketeers need a Powder Mill (you don't start with one) and cost 10 powder. Barracks: Musketeers, Pikemen and (once you have a Foundry) Cuirassiers, fast horsemen whose sabre charge after a gallop hits double and throws the enemy back. Foundry: Field Cannons. Church: one Missionary, who bandages wounded soldiers back to full health and can't be hurt unless he wanders near enemy buildings.""",
	"BROOD": """THE BROOD: swarm, swamp and hunger.

Grubs haul food from Feeding Pits to a Hive: the farther the pit from the Hive, the richer each load. Pits must grow on your swamp; Spore Vents spread it far. Bone Middens turn the dead into essence (Brutes and Skywings cost some).

Every unit hatches from the Hive's eggs. Swamp heals and speeds the Brood. Roost: Skywings, flyers only ranged units can hit. Gorge Pit: Brutes and Spore Mothers, who must ROOT to lob big spit blobs over an area (rooted, they spread swamp) and cast MIASMA, a cloud that heals the Brood. Army cap 160.""",
	"CLOCKWORK": """THE CLOCKWORK: gears, steam and lightning.

Every energy building (Clocktower, Boilers, Pylons, Spring Towers) fills batteries by itself; Winders carry them to Ore Crushers, where the charge becomes ore. The longer a battery travels the more it holds, but carried too long, or hit, it bursts. A Capacitor Works turns every battery blue (more charge). Winders also repair, which costs ore.

Constructs run down away from a Clocktower, Spring Tower, Charging Pylon or deployed Tesla Cart. Tesla Carts must deploy (3 s) to fire. Stormcallers cast a STORM that stuns everything inside it, your own units too; their charge only fills inside a field. Army cap 80.""",
	"CONTROLS": """COMPUTER
Left click selects (Shift adds, Ctrl-click or double-click picks every unit of that type on screen); left drag box-selects; right click commands (move, attack, work, rally). Mouse wheel zooms; screen edges, arrow keys or the middle button pan.
Line move: hold the right button and drag a line; your units spread out along it (with A first, they attack-move). On a phone: tap MOVE or ATTACK, then drag.
Every command button has a letter hotkey (hover for details): B build, A attack, M move, S stop, H hold, G work. 1-9 select groups, Ctrl+number saves, Shift+number adds. F1 idle worker, F2 army, F3 hall, Space jumps to the selection, Esc cancels.

MOBILE
Tap to select, double-tap for every unit of that type on screen. DRAG: BOX / PAN (top right) switches what a one-finger drag does. Tap the ground to move, an enemy to attack. Long-press to move without fighting. Two fingers pan, pinch zooms, tap the minimap to jump. ARMY / IDLE / HALL select quickly; groups 1-3: hold to save, tap to select.""",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiStyle.install()
	add_child(Music.new())
	sfx = Sfx.new()
	add_child(sfx)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_make_rotate_overlay()
	Settings.load_all()
	_load_lobby()
	if Settings.device == "":
		show_device()
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


func show_menu() -> void:
	if Music.me:
		Music.me.menu()
	var root := _page()
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 56)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 28)
	root.add_child(m)
	var h := HBoxContainer.new()
	m.add_child(h)
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size.x = 400
	h.add_child(left)
	var title := UiStyle.heading("POCKET\nRTS", 84, UiStyle.TRIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_constant_override("line_spacing", -18)
	left.add_child(title)
	var sub := UiStyle.text("The Crown  ·  The Brood  ·  The Clockwork", 20, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	left.add_child(sub)
	left.add_child(_gap(14))
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
		cont.custom_minimum_size = Vector2(360, 58)
		left.add_child(cont)
	var play := _button("SKIRMISH", func() -> void: show_skirmish())
	UiStyle.primary(play)
	play.custom_minimum_size = Vector2(360, 68)
	play.add_theme_font_size_override("font_size", 30)
	left.add_child(play)
	for it in [["EDITOR", func() -> void: show_editor_menu()], ["HOW TO PLAY", func() -> void: show_help()], ["SETTINGS", func() -> void: show_settings()], ["MATCH LOGS", func() -> void: show_logs()]]:
		var b := _button(it[0], it[1])
		b.custom_minimum_size = Vector2(360, 54)
		left.add_child(b)
	left.add_child(_gap(8))
	left.add_child(UiStyle.text("v%s  ·  playing on %s" % [version, "computer" if Settings.pc() else "mobile"], 15, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_LEFT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	# The three factions, each with its hall.
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_END
	cards.add_theme_constant_override("separation", 14)
	cards.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(cards)
	for f in ["crown", "brood", "clockwork"]:
		cards.add_child(_faction_card(f))


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
			["MAP EDITOR", "Paint ground, high ground, ramps, water, fords, trees and rocks; place start and hall spots; mirror it for fairness; save and play your maps in Skirmish.", func() -> void: show_map_editor()]]:
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


func show_map_editor(name := "") -> void:
	_clear_ui()
	if game:
		game.queue_free()
	game = Game.new()
	game.edit_mode = true
	game.map_id = ("custom:" + name) if name != "" else "blank"
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	_editor = MapEditor.new()
	_editor.game = game
	ui_layer.add_child(_editor)
	_editor.load_from(MapGen.load_custom(name) if name != "" else {})
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UiStyle.heading("SETTINGS", 40, UiStyle.TRIM))
	v.add_child(_toggle_row("MUSIC", func() -> bool: return Music.me.music_on, func() -> void: Music.me.toggle_music()))
	v.add_child(_toggle_row("SOUND", func() -> bool: return Music.me.sound_on, func() -> void: Music.me.toggle_sound()))
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
	play.text = ("♪  " if Music.me._current == stem else "") + title
	play.alignment = HORIZONTAL_ALIGNMENT_LEFT
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.custom_minimum_size.y = 46
	play.clip_text = true
	play.add_theme_font_size_override("font_size", 16)
	play.tooltip_text = "Battle" if mood == "battle" else "Calm"
	if mood == "battle":
		play.add_theme_color_override("font_color", Color(1, 0.75, 0.6))
	if Music.me._current == stem:
		UiStyle.chosen(play)
	play.pressed.connect(func() -> void:
		Music.me.preview(stem)
		show_music())
	h.add_child(play)
	if Music.me.mode == "picked":
		var tick := Button.new()
		var on := Music.me.is_enabled(stem)
		tick.text = "✓" if on else ""
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
	for preset in ["1v1", "2v2", "1v2", "1v3", "FFA"]:
		var pr: String = preset
		var b := _button(pr, func() -> void:
			_preset(pr)
			show_skirmish())
		b.custom_minimum_size = Vector2(76, 44)
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
	for i in slots.size():
		pv.add_child(_slot_row(i))
	if slots.size() < 4:
		var add := _button("+  ADD PLAYER", func() -> void:
			_add_slot()
			show_skirmish())
		add.custom_minimum_size = Vector2(0, 46)
		add.add_theme_font_size_override("font_size", 18)
		pv.add_child(add)
	var spc := Control.new()
	spc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(spc)
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
	var ids: Array = ["random"] + MapGen.MAPS.keys()
	for n in MapGen.custom_names():
		ids.append("custom:" + n)
	if not ids.has(lobby["map"]):
		lobby["map"] = "random"
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 6)
	mv.add_child(mrow)
	var prev := _button("<", func() -> void:
		lobby["map"] = ids[(ids.find(lobby["map"]) - 1 + ids.size()) % ids.size()]
		show_skirmish())
	prev.custom_minimum_size = Vector2(46, 46)
	mrow.add_child(prev)
	var mid: String = lobby["map"]
	var mname := "RANDOM MAP" if mid == "random" else (mid.substr(7).to_upper() if mid.begins_with("custom:") else String(MapGen.MAPS[mid][0]).to_upper())
	var ml := UiStyle.heading(mname, 22, UiStyle.TEXT)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(ml)
	var nxt := _button(">", func() -> void:
		lobby["map"] = ids[(ids.find(lobby["map"]) + 1) % ids.size()]
		show_skirmish())
	nxt.custom_minimum_size = Vector2(46, 46)
	mrow.add_child(nxt)
	var prv := MapPreview.new()
	prv.map_id = mid
	prv.slots = slots
	prv.custom_minimum_size = Vector2(270, 190)
	prv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_child(prv)
	var desc := "Any map, picked when the match starts."
	if mid.begins_with("custom:"):
		desc = "Your map, %d start spots." % (MapGen.load_custom(mid.substr(7)).get("starts", []) as Array).size()
	elif mid != "random":
		desc = {"crossroads": "Open ground around a central hill.", "highlands": "Main bases on high ground, one ramp down.",
			"rivers": "Rivers you can only cross at the fords."}[MapGen.MAPS[mid][1]]
		desc += "  " + String(MapGen.MAPS[mid][2]).replace("+", " & ").capitalize() + "."
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
	var who := _cycle(WHO_LABEL[sl["who"]], 170, func(dir: int) -> void:
		var list := WHO.duplicate()
		var taken := false
		for j in lobby["slots"].size():
			if j != i and lobby["slots"][j]["who"] == "you":
				taken = true
		if taken:
			list.erase("you")
		sl["who"] = list[(list.find(sl["who"]) + dir + list.size()) % list.size()])
	if sl["who"] == "brutal":
		who.add_theme_color_override("font_color", UiStyle.BAD)
	elif sl["who"] == "you":
		who.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	h.add_child(who)
	# faction
	var f: String = sl["faction"]
	var fb := _cycle("RANDOM" if f == "random" else Defs.FACTIONS[f]["name"].to_upper(), 190, func(dir: int) -> void:
		sl["faction"] = FACS[(FACS.find(sl["faction"]) + dir + FACS.size()) % FACS.size()])
	if f != "random":
		fb.icon = _faction_icon(f)
		fb.expand_icon = false
		fb.add_theme_constant_override("icon_max_width", 30)
		fb.add_theme_color_override("font_color", UiStyle.accent(f).lightened(0.4))
	h.add_child(fb)
	# colour
	var cb := _cycle(Defs.colour_name(int(sl["colour"])).to_upper(), 110, func(dir: int) -> void:
		# the palette, then RANDOM and FITS MAP (any colour / one that stands out on the map)
		var opts: Array = [Defs.COLOUR_FITS_MAP, Defs.COLOUR_RANDOM] + range(Defs.PALETTE.size())
		var k := opts.find(int(sl["colour"]))
		for step in opts.size():
			k = (k + dir + opts.size()) % opts.size()
			if int(opts[k]) < 0 or not _colour_taken(int(opts[k]), i):
				break
		sl["colour"] = opts[k])
	for st in ["normal", "hover", "pressed"]:
		cb.add_theme_stylebox_override(st, UiStyle.box(colour.darkened(0.25 if st == "normal" else 0.1), Color(1, 1, 1, 0.5 if st == "normal" else 0.9), 2))
	cb.add_theme_color_override("font_color", Color(1, 1, 1))
	cb.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	h.add_child(cb)
	# strategy (computer players)
	if sl["who"] != "you":
		var st: String = String(sl.get("strategy", "balanced"))
		var opts: Array = ["random"] + AI.STRATEGIES.keys()
		var sb := _cycle("RANDOM PLAN" if st == "random" else String(AI.STRATEGIES[st]["name"]).to_upper(), 150, func(dir: int) -> void:
			sl["strategy"] = opts[(opts.find(String(sl.get("strategy", "balanced"))) + dir + opts.size()) % opts.size()])
		sb.tooltip_text = "How this computer player plays. Air rush is Brood only (others play Balanced)."
		h.add_child(sb)
	else:
		var sp := Control.new()
		sp.custom_minimum_size.x = 150
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.size_flags_stretch_ratio = 1.5
		h.add_child(sp)
	# team
	var tb := _cycle(str(int(sl["side"]) + 1), 80, func(dir: int) -> void:
		sl["side"] = (int(sl["side"]) + dir + 4) % 4)
	tb.add_theme_font_override("font", UiStyle.title_font())
	tb.add_theme_font_size_override("font_size", 24)
	h.add_child(tb)
	if lobby["slots"].size() > 2:
		var x := _button("✕", func() -> void:
			lobby["slots"].remove_at(i)
			show_skirmish())
		x.custom_minimum_size = Vector2(46, 58)
		h.add_child(x)
	return h


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
	var me: Dictionary = slots[0] if not slots.is_empty() else {"who": "you", "faction": "crown", "colour": 0, "side": 0}
	var n: int = {"1v1": 2, "2v2": 4, "1v2": 3, "1v3": 4, "FFA": 4}[p]
	var out: Array = [me]
	for i in range(1, n):
		var prev: Dictionary = slots[i] if i < slots.size() else {"who": "normal", "faction": "random"}
		out.append({"who": "normal" if prev["who"] == "you" else prev["who"], "faction": prev["faction"], "colour": 0, "side": 1})
	for i in out.size():
		out[i]["colour"] = i if i != 0 else int(me["colour"])
	# keep colours unique
	var used := {int(me["colour"]): true}
	for i in range(1, out.size()):
		var c := 0
		while used.has(c):
			c += 1
		out[i]["colour"] = c
		used[c] = true
	for i in out.size():
		match p:
			"2v2":
				out[i]["side"] = 0 if i < 2 else 1
			"FFA":
				out[i]["side"] = i
			_:
				out[i]["side"] = 0 if i == 0 else 1
	lobby["slots"] = out


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
	if n == 4 and distinct.size() == 2 and sides.count(sides[0]) == 2:
		return "2v2"
	if distinct.size() == 2 and sides.count(sides[0]) == 1:
		return "1v%d" % (n - 1)
	return ""


func _lobby_problem() -> String:
	var mid: String = lobby["map"]
	if mid.begins_with("custom:"):
		var n := (MapGen.load_custom(mid.substr(7)).get("starts", []) as Array).size()
		if lobby["slots"].size() > n:
			return "This map has %d start spots." % n
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

	func _draw() -> void:
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var ratio := float(Game.W) / float(Game.H)
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
		if map_id == "random" or not MapGen.MAPS.has(map_id):
			draw_rect(r, Color(0.2, 0.18, 0.14))
			var f := ThemeDB.fallback_font
			draw_string(f, r.get_center() + Vector2(-12, 22), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, UiStyle.MUTED)
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
		var k := r.size / Vector2(Game.W, Game.H)
		var four := slots.size() > 2
		var hill := ca.lightened(0.25)
		match m[1]:
			"crossroads":
				draw_circle(r.position + Vector2(42, 30) * k, 5.5 * k.x, hill)
			"highlands":
				for c in ([Vector2(9, 8), Vector2(Game.W - 9, 8), Vector2(9, Game.H - 8), Vector2(Game.W - 9, Game.H - 8)] if four else [Vector2(9, 8), Vector2(Game.W - 9, Game.H - 8)]):
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

	func _custom(r: Rect2) -> void:
		var d := MapGen.load_custom(map_id.substr(7))
		var cells: String = d.get("cells", "")
		var parts: PackedStringArray = String(d.get("biome", "grass")).split("+")
		var low := _biome_col(parts[0])
		var cols := {".": low, "h": low.lightened(0.25), "r": low.lightened(0.12), "w": Color(0.15, 0.4, 0.7),
			"f": Color(0.4, 0.6, 0.75), "t": low.darkened(0.45), "T": low.darkened(0.3), "k": Color(0.5, 0.5, 0.5), "K": Color(0.6, 0.6, 0.6)}
		var k := r.size / Vector2(Game.W, Game.H)
		draw_rect(r, low)
		for i in mini(cells.length(), Game.W * Game.H):
			if cells[i] != ".":
				draw_rect(Rect2(r.position + Vector2(i % Game.W, i / Game.W) * k, k + Vector2(0.5, 0.5)), cols.get(cells[i], low))
		var st: Array = d.get("starts", [])
		for i in mini(st.size(), slots.size()):
			var p: Vector2 = r.position + (Vector2(st[i][0], st[i][1]) + Vector2(2.5, 2)) * k
			draw_circle(p, 9.0, Color(0, 0, 0, 0.6))
			draw_circle(p, 7.0, Defs.colour_of(int(slots[i]["colour"])))

	func _starts(r: Rect2) -> void:
		var k := r.size / Vector2(Game.W, Game.H)
		var corners: Array = [Vector2(8, 8), Vector2(Game.W - 8, Game.H - 8)]
		if slots.size() > 2:
			corners = [Vector2(8, 8), Vector2(8, Game.H - 8), Vector2(Game.W - 8, 8), Vector2(Game.W - 8, Game.H - 8)]
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
		var c: Color = TerrainData.COLOURS.get(low[0], Color(0.3, 0.45, 0.2))
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


## Autosave the match every 15 s (and the log with it), so closing the game loses nothing.
func _autosave() -> void:
	if game == null or game.over or game.demo or game.edit_mode:
		return
	var cfg := last_cfg.duplicate(true)
	cfg.erase("resume")
	SaveGame.save(game, cfg)
	if game.mlog:
		_write_log("user://logs/unfinished.txt", game.mlog.text())


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_autosave()


func _process(delta: float) -> void:
	if game and not game.over and not get_tree().paused:
		_save_t += delta
		if _save_t >= 15.0:
			_save_t = 0.0
			_autosave()
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
	# a random built-in map is picked here, so colours can be chosen to suit its ground
	if String(cfg.get("map", "random")) == "random":
		cfg["map"] = MapGen.MAPS.keys()[randi() % MapGen.MAPS.size()]
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
	add_child(game)
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
	Music.me.ambience(game.mapgen.biome_a if game.mapgen else "")
	if cfg.has("resume"):
		SaveGame.restore(game, cfg["resume"])
		last_cfg.erase("resume")
	_save_t = 0.0


func _to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if game:
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
	if MapGen.MAPS.has(mid):
		for biome in String(MapGen.MAPS[mid][2]).split("+"):
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


func _web_fullscreen() -> void:
	if _went_fullscreen or not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		return
	_went_fullscreen = true
	JavaScriptBridge.eval("""
		(function(){
			var el = document.documentElement;
			var req = el.requestFullscreen || el.webkitRequestFullscreen;
			if (!req) return;
			var p = req.call(el);
			if (p && p.then) p.then(function(){
				if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(function(){});
			}).catch(function(){});
		})();
	""", true)
