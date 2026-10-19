extends Node
## Main menu, starting a match, and the victory/defeat screen.

var version: String = ProjectSettings.get_setting("application/config/version", "dev")
var sfx: Sfx
var game: Game
var ui_layer: CanvasLayer
var menu: Control
var _went_fullscreen := false

const HELP := """Destroy every enemy building to win.

ECONOMY  Labourers mine gold and carry it to the Town Hall. Train more labourers there. Build Cottages for supply.
ARMY  Barracks train Musketeers (ranged, slow reload) and Pikemen (tough, crush cannons). The Foundry casts Field Cannons (long-range splash, smash buildings).

TOUCH
- Tap a unit to select it; double-tap to select all of that type on screen.
- Drag on the map to box-select.
- Tap the ground to move (soldiers fight anything on the way). Tap an enemy to attack, a mine to gather.
- Long-press the ground to move without stopping to fight.
- Two fingers to pan and pinch to zoom. Tap the minimap to jump.
- ARMY / IDLE / HALL buttons select quickly. Groups 1-3: hold to save, tap to select.

MOUSE  Left click selects, drag to box, right click commands, wheel zooms, arrows pan."""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx = Sfx.new()
	add_child(sfx)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	show_menu()


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
	v.add_child(_label("The Crown  ·  prototype", 20, Color(1, 1, 1, 0.6)))
	v.add_child(_gap(10))
	for d in [["PLAY  ·  EASY", 0], ["PLAY  ·  NORMAL", 1], ["PLAY  ·  HARD", 2]]:
		var dd: int = d[1]
		v.add_child(_button(d[0], func() -> void: start(dd, false)))
	v.add_child(_button("WATCH AI vs AI", func() -> void: start(1, true)))
	v.add_child(_button("HOW TO PLAY", func() -> void: _show_help()))
	v.add_child(_gap(6))
	v.add_child(_label("v" + version, 14, Color(1, 1, 1, 0.35)))


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

func start(difficulty: int, demo: bool) -> void:
	_clear_ui()
	if game:
		game.queue_free()
	game = Game.new()
	game.difficulty = difficulty
	game.demo = demo
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


func _to_menu() -> void:
	get_tree().paused = false
	if game:
		game.queue_free()
		game = null
	show_menu()


func _on_end(winner: int) -> void:
	var won := winner == game.human
	Sfx.play("done" if won else "alarm")
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.theme = _theme()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.position = Vector2(-220, -160)
	v.custom_minimum_size = Vector2(440, 0)
	v.add_theme_constant_override("separation", 10)
	o.add_child(v)
	var title := ("%s WINS" % Defs.TEAM_NAMES[winner].to_upper()) if game.demo else ("VICTORY" if won else "DEFEAT")
	v.add_child(_label(title, 60, Color(1, 0.9, 0.5) if won or game.demo else Color(1, 0.5, 0.45)))
	var s: Dictionary = game.stats[game.human]
	var secs := int(game.clock)
	v.add_child(_label("Time %d:%02d   ·   Gold mined %d   ·   Kills %d   ·   Losses %d" % [secs / 60, secs % 60, s["gold"], s["killed"], s["lost"]], 18, Color(1, 1, 1, 0.8)))
	v.add_child(_gap(10))
	v.add_child(_button("PLAY AGAIN", func() -> void: start(game.difficulty, game.demo)))
	v.add_child(_button("MENU", func() -> void: _to_menu()))
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
