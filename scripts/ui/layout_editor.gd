class_name LayoutEditor
extends Control
## Settings > Interface layout: pick a layout profile; in the CUSTOM slots drag the minimap,
## quick buttons, selection panel and command card where you want them, and set your own
## letter hotkeys for commands, units and buildings.

signal done

var profile := "STANDARD"
var tab := "layout"            # "layout" or "keys"
var _drag := ""
var _drag_off := Vector2.ZERO
var _waiting := ""             # hotkey id waiting for a key press
var _ui: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	UiLayout.load_all()
	profile = UiLayout.active
	_build()


func _scale() -> float:
	return Settings.ui_scale_now()


func _hud_size() -> Vector2:
	return size / _scale()


func _sizes() -> Dictionary:
	var b := 60.0 if Settings.pc() else 70.0
	var cols := 4 if Settings.pc() else 3
	var rows := 3 if Settings.pc() else 2
	return {"mini": Vector2(210, 210.0 * Game.H / Game.W), "hotbar": HotkeyBar.size_hint(),
		"card": Vector2(b * cols + 4, b * rows + 4), "panel": Vector2(0, 88)}


func _rects() -> Dictionary:
	return UiLayout.rects(_hud_size(), _sizes(), profile)


# ------------------------------------------------------------------ controls

func _build() -> void:
	if _ui:
		_ui.queue_free()
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	var top := HBoxContainer.new()
	top.position = Vector2(8, 6)
	top.add_theme_constant_override("separation", 5)
	_ui.add_child(top)
	top.add_child(_btn("BACK", 86, func() -> void: done.emit()))
	for p in UiLayout.BUILT_IN + UiLayout.CUSTOM:
		var pp: String = p
		var b := _btn(("» " if UiLayout.active == p else "") + p, 0, func() -> void:
			profile = pp
			_build())
		b.add_theme_font_size_override("font_size", 14)
		if p == profile:
			UiStyle.chosen(b)
		top.add_child(b)
	var row2 := HBoxContainer.new()
	row2.position = Vector2(8, 58)
	row2.add_theme_constant_override("separation", 5)
	_ui.add_child(row2)
	var use := _btn("USE THIS LAYOUT" if UiLayout.active != profile else "» IN USE", 180, func() -> void:
		UiLayout.active = profile
		UiLayout.save_all()
		_build())
	if UiLayout.active != profile:
		UiStyle.primary(use)
	row2.add_child(use)
	for t in [["layout", "POSITIONS"], ["keys", "HOTKEYS"]]:
		var tt: String = t[0]
		var b := _btn(t[1], 130, func() -> void:
			tab = tt
			_waiting = ""
			_build())
		if tab == tt:
			UiStyle.chosen(b)
		row2.add_child(b)
	if UiLayout.editable(profile):
		var d := UiLayout.data(profile)
		if tab == "layout":
			row2.add_child(_btn("START FROM: " + String(d.get("base", "STANDARD")), 280, func() -> void:
				d["base"] = "MINIMAP TOP RIGHT" if d.get("base", "STANDARD") == "STANDARD" else "STANDARD"
				d["pos"] = {}
				d.erase("panel_w")
				UiLayout.save_all()
				_build()))
			row2.add_child(_btn("SELECTION −", 130, func() -> void: _panel_w(-0.05)))
			row2.add_child(_btn("SELECTION +", 130, func() -> void: _panel_w(0.05)))
		row2.add_child(_btn("RESET", 90, func() -> void:
			if tab == "layout":
				d["pos"] = {}
				d.erase("panel_w")
			else:
				d["keys"] = {}
			UiLayout.save_all()
			_build()))
	if tab == "keys":
		_build_keys()
	queue_redraw()


func _btn(t: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, 44)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(func() -> void:
		Sfx.play_any(["ui/click", "click"])
		cb.call())
	return b


func _panel_w(df: float) -> void:
	var d := UiLayout.data(profile)
	var cur: float = (_rects()["panel"] as Rect2).size.x / _hud_size().x
	d["panel_w"] = clampf(cur + df, 0.2, 0.95)
	UiLayout.save_all()
	queue_redraw()


func _build_keys() -> void:
	var p := PanelContainer.new()
	p.position = Vector2(8, 112)
	p.size = Vector2(size.x - 16, size.y - 120)
	_ui.add_child(p)
	# the list and its note one above the other (the note was a second child of the panel, drawn over the list)
	var pv := VBoxContainer.new()
	p.add_child(pv)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var editable := UiLayout.editable(profile)
	var ids: Array = UiLayout.COMMANDS.duplicate()
	for f in ["crown", "brood", "clockwork"]:
		for k in Defs.UNITS:
			if Defs.UNITS[k]["faction"] == f:
				ids.append(k)
		for k in Defs.FACTIONS[f]["build"]:
			ids.append(k)
	var keys: Dictionary = UiLayout.data(profile).get("keys", {})
	for id in ids:
		var iid: String = id
		var name: String = iid
		var col := UiStyle.TEXT
		if Defs.UNITS.has(iid):
			name = Defs.UNITS[iid]["name"]
			col = UiStyle.accent(Defs.UNITS[iid]["faction"]).lightened(0.4)
		elif Defs.BUILDINGS.has(iid):
			name = Defs.BUILDINGS[iid]["name"]
			col = UiStyle.accent(Defs.BUILDINGS[iid]["faction"]).lightened(0.4)
		else:
			name = iid.capitalize()
		var l := UiStyle.text(name, 15, col, HORIZONTAL_ALIGNMENT_RIGHT)
		l.custom_minimum_size.x = 150
		grid.add_child(l)
		var k: String = keys.get(iid, "")
		var shown := k if k != "" else String(preload("res://scripts/ui/hud.gd").FIXED_KEYS.get(iid, "auto"))
		var b := Button.new()
		b.text = "press a key…" if _waiting == iid else shown
		b.custom_minimum_size = Vector2(110, 38)
		b.add_theme_font_size_override("font_size", 15)
		b.disabled = not editable
		if k != "":
			UiStyle.chosen(b)
		b.pressed.connect(func() -> void:
			_waiting = iid
			_build())
		grid.add_child(b)
	if not editable:
		var l := UiStyle.text("Built-in layouts can't be changed: pick a CUSTOM slot.", 15, UiStyle.MUTED)
		pv.add_child(l)


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _waiting != "" and event is InputEventKey and event.pressed:
		var kc := (event as InputEventKey).keycode
		if kc == KEY_ESCAPE:
			_waiting = ""
		elif kc == KEY_BACKSPACE or kc == KEY_DELETE:
			UiLayout.set_key(profile, _waiting, "")
			_waiting = ""
		else:
			var letter := OS.get_keycode_string(kc)
			if letter.length() == 1:
				UiLayout.set_key(profile, _waiting, letter.to_upper())
				_waiting = ""
		get_viewport().set_input_as_handled()
		_build()
		return
	if tab != "layout" or not UiLayout.editable(profile):
		return
	var p := Vector2.INF
	var pressed := false
	var moved := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		p = event.position
		pressed = event.pressed
	elif event is InputEventMouseMotion:
		p = event.position
		moved = true
	elif event is InputEventScreenTouch and not Settings.pc():
		p = event.position
		pressed = event.pressed
	elif event is InputEventScreenDrag and not Settings.pc():
		p = event.position
		moved = true
	if p == Vector2.INF:
		return
	var hp := p / _scale()
	if moved:
		if _drag != "":
			var r: Rect2 = _rects()[_drag]
			r.position = hp - _drag_off
			var d := UiLayout.data(profile)
			var pos: Dictionary = d.get("pos", {})
			pos[_drag] = UiLayout.fraction(r, _hud_size())
			d["pos"] = pos
			queue_redraw()
			get_viewport().set_input_as_handled()
		return
	if pressed:
		if p.y < 110:
			return       # the buttons up top
		var rs := _rects()
		for part in ["card", "panel", "hotbar", "mini"]:
			if (rs[part] as Rect2).has_point(hp):
				_drag = part
				_drag_off = hp - (rs[part] as Rect2).position
				get_viewport().set_input_as_handled()
				return
	elif _drag != "":
		_drag = ""
		UiLayout.save_all()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.22, 0.13))
	# a faint grid of "map"
	for x in range(0, int(size.x), 64):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.04))
	for y in range(0, int(size.y), 64):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.04))
	if tab != "layout":
		return
	var s := _scale()
	var rs := _rects()
	var editable := UiLayout.editable(profile)
	for part in UiLayout.PARTS:
		var r: Rect2 = rs[part]
		var sr := Rect2(r.position * s, r.size * s)
		UiStyle.draw_panel(self, sr, UiStyle.TRIM if _drag == part else Color(0, 0, 0, 0))
		var f := UiStyle.bold_font()
		var label: String = UiLayout.PART_NAMES[part]
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(f, sr.get_center() + Vector2(-w * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiStyle.TEXT)
	var hint := "Drag the boxes to move them. Saved as you go." if editable else "Built-in layout. Pick a CUSTOM slot to make your own."
	hint += "   (Enter: chat)"
	var f2 := UiStyle.bold_font()
	var w2 := f2.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_string(f2, Vector2(size.x * 0.5 - w2 * 0.5, size.y * 0.5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiStyle.MUTED)
