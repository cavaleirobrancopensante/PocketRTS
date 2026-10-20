extends Node
## Main menu, starting a match, and the victory/defeat screen.

var version: String = ProjectSettings.get_setting("application/config/version", "dev")
var sfx: Sfx
var game: Game
var ui_layer: CanvasLayer
var menu: Control
var _went_fullscreen := false
var pick := {"me": "crown", "enemy": "brood", "difficulty": 1, "blue": "you", "c1": 0, "c2": 1, "map": "random"}

const HELP := """Destroy every enemy building to win. There are no resources on the map: each faction builds its own economy, and every Town Hall, Hive or Clocktower allows only so many economy structures, so expanding is how you grow.

THE CROWN  Labourers work Farms (up to 3 each): a farm ripens into a 280-gold harvest, faster with more hands. The Powder Mill makes black powder; muskets and cannons can't fire without it. Each Town Hall allows 4 Farms and 1 Powder Mill nearby. Barracks: Musketeers and Pikemen. Foundry: Field Cannons. Church: one Missionary, who bandages wounded soldiers back to full health and can't be hurt unless he wanders near enemy buildings.

THE BROOD  Grubs haul food from Feeding Pits to a Hive: the farther the pit from the Hive, the richer each load. Pits must grow on your swamp; Spore Vents spread it far. Bone Middens turn the dead into essence (Brutes and Skywings cost some). Every unit hatches from the Hive's eggs. Swamp heals and speeds the Brood. Roost: Skywings, flyers only ranged units can hit. Army cap 160.

THE CLOCKWORK  Winders crank Boilers for energy. Split the energy (tap a Boiler or Clocktower) between ORE (Ore Crushers turn it into ore), ASSEMBLY (faster production) and WIND (bigger fields; constructs run down slower). Winders also start buildings and repair. Constructs run down away from a Clocktower, Spring Tower, Charging Pylon or deployed Tesla Cart. Tesla Carts must deploy (3 s) to fire. Army cap 80.

MOBILE
- DRAG: BOX / PAN (top right) switches what a one-finger drag does.
- Tap a unit to select it; double-tap to select all of that type on screen.
- Drag on the map to box-select.
- Tap the ground to move (soldiers fight anything on the way). Tap an enemy to attack, a mine to gather.
- Long-press the ground to move without stopping to fight.
- Two fingers to pan and pinch to zoom. Tap the minimap to jump.
- ARMY / IDLE / HALL buttons select quickly. Groups 1-3: hold to save, tap to select.

COMPUTER  Left click selects (Shift adds, Ctrl-click or double-click picks every unit of that type on screen), left drag box-selects, right click commands (move, attack, work, rally). Mouse wheel zooms; move the mouse to a screen edge, use the arrow keys or drag with the middle button to pan. Every button on the command card has a letter hotkey (shown in its corner; hover for details): B builds, A attack, M move, S stop, H hold, G work. 1-9 select groups, Ctrl+number saves one, Shift+number adds it. F1 idle worker, F2 whole army, F3 hall, Space jumps to the selection, Esc cancels."""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(Music.new())
	sfx = Sfx.new()
	add_child(sfx)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_make_rotate_overlay()
	Settings.load_all()
	if Settings.device == "":
		show_device()
	else:
		show_menu()


## First start (or from the menu): computer or phone? They play differently.
func show_device() -> void:
	_clear_ui()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.theme = _theme()
	ui_layer.add_child(menu)
	var dark := ColorRect.new()
	dark.color = Color("#121612")
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dark)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.custom_minimum_size = Vector2(560, 0)
	v.position = Vector2(-280, -190)
	v.add_theme_constant_override("separation", 16)
	menu.add_child(v)
	v.add_child(_label("POCKET RTS", 56))
	v.add_child(_label("Where are you playing?", 26, Color(1, 1, 1, 0.8)))
	v.add_child(_gap(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	for opt in [["pc", "COMPUTER", "Mouse and keyboard: click, drag to select,\nright-click to command, letter hotkeys."],
			["mobile", "MOBILE", "Touch: tap, drag, pinch to zoom.\nPlay it held sideways."]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 8)
		var dev: String = opt[0]
		var b := _button(opt[1], func() -> void:
			Settings.set_device(dev)
			show_menu())
		b.custom_minimum_size = Vector2(0, 110)
		b.add_theme_font_size_override("font_size", 30)
		if Settings.device == dev:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("#447a4c")
			sb.set_corner_radius_all(8)
			sb.border_color = Color(1, 0.9, 0.5)
			sb.set_border_width_all(2)
			b.add_theme_stylebox_override("normal", sb)
		col.add_child(b)
		var l := _label(opt[2], 15, Color(1, 1, 1, 0.55))
		col.add_child(l)
		row.add_child(col)
	v.add_child(_gap(6))
	v.add_child(_label("You can change this later from the menu.", 14, Color(1, 1, 1, 0.4)))


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


func _process(_delta: float) -> void:
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


func _clear_ui() -> void:
	for c in ui_layer.get_children():
		c.queue_free()


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("#2b3a2e"), "hover": Color("#35503a"), "pressed": Color("#447a4c")}[st]
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		t.set_stylebox(st, "Button", sb)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return t


func show_menu() -> void:
	_clear_ui()
	if Music.me:
		Music.me.menu()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.theme = _theme()
	ui_layer.add_child(menu)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/buildings/town_hall_built.png")
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.modulate = Color(1, 1, 1, 0.12)
	var dark := ColorRect.new()
	dark.color = Color("#121612")
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dark)
	menu.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(440, 0)
	v.position = Vector2(-220, -250)
	menu.add_child(v)
	v.add_child(_label("POCKET RTS", 64))
	v.add_child(_label("The Crown  ·  The Brood  ·  The Clockwork", 20, Color(1, 1, 1, 0.6)))
	v.add_child(_gap(10))
	v.add_child(_button("SKIRMISH", func() -> void: show_skirmish()))
	v.add_child(_button("HOW TO PLAY", func() -> void: _show_help()))
	var audio := HBoxContainer.new()
	audio.add_theme_constant_override("separation", 12)
	for which in ["music", "sound"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(214, 48)
		b.add_theme_font_size_override("font_size", 18)
		var refresh := func() -> void:
			var on: bool = Music.me.music_on if which == "music" else Music.me.sound_on
			b.text = "%s: %s" % [which.to_upper(), "ON" if on else "OFF"]
		refresh.call()
		b.pressed.connect(func() -> void:
			_web_fullscreen()
			if which == "music":
				Music.me.toggle_music()
			else:
				Music.me.toggle_sound()
			refresh.call())
		audio.add_child(b)
	v.add_child(audio)
	var dev_b := _button("PLAYING ON: %s" % ("COMPUTER" if Settings.pc() else "MOBILE"), func() -> void: show_device())
	dev_b.custom_minimum_size = Vector2(0, 44)
	dev_b.add_theme_font_size_override("font_size", 16)
	v.add_child(dev_b)
	v.add_child(_gap(6))
	v.add_child(_label("v" + version, 14, Color(1, 1, 1, 0.35)))


func show_skirmish() -> void:
	_clear_ui()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.theme = _theme()
	ui_layer.add_child(menu)
	var dark := ColorRect.new()
	dark.color = Color("#121612")
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dark)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 60
	v.offset_right = -60
	v.offset_top = 20
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 10)
	menu.add_child(v)
	v.add_child(_label("SKIRMISH", 44))
	var watch: bool = pick["blue"] == "ai"
	var facs := [["crown", "THE CROWN"], ["brood", "THE BROOD"], ["clockwork", "THE CLOCKWORK"], ["random", "RANDOM"]]
	v.add_child(_choice_row("PLAYER 1", "blue", [["you", "YOU"], ["ai", "COMPUTER (WATCH)"]]))
	v.add_child(_choice_row("P1 FACTION" if watch else "YOUR FACTION", "me", facs))
	v.add_child(_colour_row("P1 COLOUR" if watch else "YOUR COLOUR", "c1", "c2"))
	var about := _label(Defs.FACTIONS[pick["me"]]["about"] if Defs.FACTIONS.has(pick["me"]) else "A faction picked at random.", 16, Color(1, 1, 1, 0.6))
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(about)
	v.add_child(_choice_row("P2 FACTION" if watch else "ENEMY", "enemy", facs))
	v.add_child(_colour_row("P2 COLOUR" if watch else "ENEMY COLOUR", "c2", "c1"))
	v.add_child(_choice_row("AI LEVEL" if watch else "DIFFICULTY", "difficulty", [[0, "EASY"], [1, "NORMAL"], [2, "HARD"]]))
	var maps: Array = [["random", "RANDOM"]]
	for id in MapGen.MAPS:
		maps.append([id, MapGen.MAPS[id][0].to_upper()])
	v.add_child(_choice_row("MAP", "map", maps.slice(0, 5)))
	v.add_child(_choice_row("", "map", maps.slice(5)))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_button("BACK", func() -> void: show_menu()))
	var go := _button("WATCH" if watch else "START", func() -> void:
		var fs := []
		for k in ["me", "enemy"]:
			var f: String = pick[k]
			fs.append(["crown", "brood", "clockwork"][randi() % 3] if f == "random" else f)
		start(pick["difficulty"], pick["blue"] == "ai", fs))
	go.custom_minimum_size = Vector2(260, 60)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#3f8a4c")
	sb.set_corner_radius_all(8)
	go.add_theme_stylebox_override("normal", sb)
	row.add_child(go)
	v.add_child(row)


## A row of colour swatches; the other player's colour can't be taken.
func _colour_row(title: String, key: String, other: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := _label(title, 18, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size.x = 170
	h.add_child(l)
	for i in Defs.PALETTE.size():
		var col: Color = Defs.PALETTE[i][1]
		var taken: bool = pick[other] == i
		var b := _button("" if taken else Defs.PALETTE[i][0].to_upper(), func() -> void:
			pick[key] = i
			show_skirmish())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 48
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
		b.add_theme_color_override("font_hover_color", Color(0.08, 0.08, 0.08))
		b.disabled = taken
		for st in ["normal", "hover", "pressed", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col if not taken else col.darkened(0.7)
			sb.set_corner_radius_all(8)
			if pick[key] == i:
				sb.border_color = Color(1, 1, 1)
				sb.set_border_width_all(4)
			b.add_theme_stylebox_override(st, sb)
		h.add_child(b)
	return h


func _choice_row(title: String, key: String, options: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := _label(title, 18, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size.x = 170
	h.add_child(l)
	for o in options:
		var val: Variant = o[0]
		var b := _button(o[1], func() -> void:
			pick[key] = val
			show_skirmish())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		var ready: bool = not (val is String and Defs.FACTIONS.has(val)) or Defs.FACTIONS[val]["ready"]
		b.disabled = not ready
		if pick[key] == val:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("#447a4c")
			sb.set_corner_radius_all(8)
			sb.border_color = Color(1, 0.9, 0.5)
			sb.set_border_width_all(2)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
		h.add_child(b)
	return h


func _show_help() -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.08, 0.97)
	sb.set_content_margin_all(24)
	sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 60
	p.offset_right = -60
	p.offset_top = 30
	p.offset_bottom = -30
	var v := VBoxContainer.new()
	p.add_child(v)
	var l := _label(HELP, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(l)
	var b := _button("BACK", func() -> void: p.queue_free())
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	menu.add_child(p)


func _label(t: String, sz: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(func() -> void:
		_web_fullscreen()
		cb.call())
	return b


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


# ------------------------------------------------------------------ match

var last_factions: Array = ["crown", "brood"]


func start(difficulty: int, demo: bool, factions: Array = []) -> void:
	_clear_ui()
	if game:
		game.queue_free()
	if factions.is_empty():
		factions = last_factions
	last_factions = factions
	game = Game.new()
	game.difficulty = difficulty
	game.demo = demo
	game.factions = factions.duplicate()
	game.colours = [pick["c1"], pick["c2"]]
	game.map_id = pick["map"]
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	sfx.camera = game.camera
	for t in ([0, 1] if demo else [1]):
		var ai := AI.new()
		ai.game = game
		ai.team = t
		ai.difficulty = difficulty
		game.add_child(ai)
		game.ais.append(ai)
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
	game.ended.connect(_on_end)
	Music.me.match_started(game.faction_of(0 if demo else game.human))


func _to_menu() -> void:
	get_tree().paused = false
	if game:
		game.queue_free()
		game = null
	show_menu()


func _on_end(winner: int) -> void:
	var won := winner == game.human or game.demo
	Music.me.match_ended(won, game.faction_of(winner if game.demo else game.human))
	game._sample_stats()
	await get_tree().create_timer(1.2, true, false, true).timeout
	if game == null:
		return
	var o := preload("res://scripts/ui/battle_report.gd").new()
	o.game = game
	o.winner = winner
	o.theme = _theme()
	o.process_mode = Node.PROCESS_MODE_ALWAYS
	o.play_again.connect(func() -> void: start(game.difficulty, game.demo))
	o.to_menu.connect(func() -> void: _to_menu())
	ui_layer.add_child(o)


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
