class_name MapEditor
extends Control
## The map editor: paint ground, high ground, ramps, water, fords, trees and rocks, place
## start spots and expansion hall spots and the deposits (saltpetre and ore outcrops) along
## the back of each, then save the map (user://maps/) and play it. A new start or hall spot
## gets a line of deposits laid out behind it; LINES lays them out again for every spot.
## Painting can be mirrored 2 ways (for 1v1) or 4 ways (for four corners) so maps stay fair.

signal back_requested
signal play_requested(map_id: String, starts: int)

const W := Game.W
const H := Game.H
const HALL := Vector2i(5, 4)
const TOOLS := [
	["low", "GROUND", "."], ["high", "HIGH GROUND", "h"], ["ramp", "RAMP", "r"], ["water", "WATER", "w"],
	["ford", "FORD", "f"], ["tree", "TREES", "t"], ["rock", "ROCKS", "k"],
	["start", "START SPOT", ""], ["hall", "HALL SPOT", ""], ["saltpetre", "SALTPETRE", ""], ["ore", "ORE", ""],
	["erase", "REMOVE", ""],
]
const MARKERS := ["start", "hall", "erase", "saltpetre", "ore"]
const DEP := Vector2i(2, 2)
const TOOL_COL := {"low": Color(0.45, 0.65, 0.3), "high": Color(0.85, 0.75, 0.45), "ramp": Color(0.75, 0.55, 0.3),
	"water": Color(0.2, 0.45, 0.85), "ford": Color(0.5, 0.75, 0.9), "tree": Color(0.1, 0.4, 0.15), "rock": Color(0.55, 0.55, 0.55),
	"saltpetre": Color(0.9, 0.9, 0.82), "ore": Color(0.85, 0.45, 0.15)}
const MIRRORS := ["off", "2-way", "4-way"]
const BIOME_LIST := ["grass", "autumn", "desert", "snow", "marsh", "volcanic"]

var game: Game
var map_name := "My map"
var cells := ""                 # one letter per cell, see MapGen.CELL_CODES
var starts: Array = []          # Vector2i, hall top-left; up to 4
var halls: Array = []           # expansion spots
var deposits: Array = []        # [Vector2i top-left, "saltpetre" / "ore"]: 2x2 outcrops
var biome_a := "grass"
var biome_b := "grass"
var tool := "high"
var brush := 2
var mirror := "2-way"
var pan_mode := false
var _painting := false
var _dirty := {}                # cell index -> tool painted (until the ground is redrawn)
var _drag_from := Vector2.INF
var _touches := {}
var _pinch := 0.0
var _status := ""
var _name_edit: LineEdit
var _ui: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiStyle.theme()
	_build_ui()


## Fill the editor from the game's freshly made map (blank or a saved one).
func load_from(data: Dictionary) -> void:
	if data.is_empty():
		cells = ".".repeat(W * H)
		starts = []
		halls = []
		deposits = []
		map_name = _free_name()
	else:
		map_name = String(data.get("name", "My map"))
		cells = String(data.get("cells", ".".repeat(W * H)))
		if cells.length() < W * H:
			cells += ".".repeat(W * H - cells.length())
		starts = (data.get("starts", []) as Array).map(func(s: Array) -> Vector2i: return Vector2i(int(s[0]), int(s[1])))
		halls = (data.get("halls", []) as Array).map(func(s: Array) -> Vector2i: return Vector2i(int(s[0]), int(s[1])))
		var parts: PackedStringArray = String(data.get("biome", "grass")).split("+")
		biome_a = parts[0]
		biome_b = parts[1] if parts.size() > 1 else parts[0]
		mirror = String(data.get("mirror", "2-way"))
		# (a map saved before deposits existed: the game laid lines out behind its spots)
		deposits = game.deposit_list() if not data.has("deposits") else (data["deposits"] as Array).map(
			func(dp: Array) -> Array: return [Vector2i(int(dp[0]), int(dp[1])), String(dp[2])])
	_rebuild()
	_build_ui()


func _free_name() -> String:
	var names := MapGen.custom_names()
	var i := 1
	while names.has("My map %d" % i):
		i += 1
	return "My map %d" % i


func to_data() -> Dictionary:
	return {
		"name": map_name, "cells": cells, "mirror": mirror,
		"biome": biome_a if biome_a == biome_b else "%s+%s" % [biome_a, biome_b],
		"starts": starts.map(func(s: Vector2i) -> Array: return [s.x, s.y]),
		"halls": halls.map(func(s: Vector2i) -> Array: return [s.x, s.y]),
		"deposits": deposits.map(func(dp: Array) -> Array: return [dp[0].x, dp[0].y, dp[1]]),
	}


func _rebuild() -> void:
	game.mapgen.biome_a = biome_a
	game.mapgen.biome_b = biome_b
	game.starts = starts.duplicate()
	game.rebuild_map(cells, deposits)
	deposits = game.deposit_list()       # (outcrops painted over with water, cliffs or ramps are gone)
	_dirty.clear()
	queue_redraw()


## Put the outcrops down again (after placing or removing some): the ground stays as it is.
func _respawn_deposits() -> void:
	game.spawn_deposits(deposits)
	deposits = game.deposit_list()
	queue_redraw()


## Lay a line of deposits behind each of these spots (and their mirror copies), as the
## built-in maps have; `fresh`: drop every other outcrop first.
func _lay_lines(spots: Array, fresh := false) -> void:
	if fresh:
		deposits = []
		_respawn_deposits()
	var sites: Array = []
	for sp in starts + halls:
		if not sites.has(sp):
			sites.append(sp)
	var todo: Array = []
	for sp in spots:
		for m in _mirrored(sp, HALL):
			if sites.has(m) and not todo.has(m):
				todo.append(m)
	for line in game.mapgen.plan_deposits(todo, mirror):
		if not deposits.any(func(dp: Array) -> bool: return Rect2i(dp[0], DEP).intersects(Rect2i(line[0], DEP))):
			deposits.append(line)
	_respawn_deposits()


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	if _ui:
		_ui.queue_free()
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	# top bar
	var top := HBoxContainer.new()
	top.position = Vector2(8, 6)
	top.add_theme_constant_override("separation", 6)
	_ui.add_child(top)
	top.add_child(_btn("BACK", 90, func() -> void: back_requested.emit()))
	_name_edit = LineEdit.new()
	_name_edit.text = map_name
	_name_edit.custom_minimum_size = Vector2(190, 44)
	_name_edit.max_length = 24
	_name_edit.add_theme_stylebox_override("normal", UiStyle.box(Color(0.08, 0.07, 0.05, 0.95), UiStyle.TRIM_DIM, 2, 7, 10.0))
	_name_edit.text_changed.connect(func(t: String) -> void: map_name = t.strip_edges())
	top.add_child(_name_edit)
	top.add_child(_btn("LAND: " + biome_a.to_upper(), 150, func() -> void:
		biome_a = BIOME_LIST[(BIOME_LIST.find(biome_a) + 1) % BIOME_LIST.size()]
		_rebuild()
		_build_ui()))
	top.add_child(_btn("MIX: " + ("-" if biome_b == biome_a else biome_b.to_upper()), 140, func() -> void:
		biome_b = BIOME_LIST[(BIOME_LIST.find(biome_b) + 1) % BIOME_LIST.size()]
		_rebuild()
		_build_ui()))
	top.add_child(_btn("MIRROR: " + mirror.to_upper(), 150, func() -> void:
		mirror = MIRRORS[(MIRRORS.find(mirror) + 1) % MIRRORS.size()]
		_build_ui()))
	top.add_child(_btn("NEW", 70, func() -> void:
		load_from({})))
	top.add_child(_btn("LINES", 80, func() -> void:
		_lay_lines(starts + halls, true)
		_say("Deposit lines laid out behind %d spots." % (starts.size() + halls.size()))))
	top.add_child(_btn("LOAD", 76, func() -> void: _show_load()))
	top.add_child(_btn("SAVE", 76, func() -> void: _save()))
	var play := _btn("PLAY", 90, func() -> void:
		if _save():
			play_requested.emit("custom:" + map_name, starts.size()))
	UiStyle.primary(play)
	top.add_child(play)
	# tools
	var side := VBoxContainer.new()
	side.position = Vector2(8, 60)
	side.add_theme_constant_override("separation", 4)
	_ui.add_child(side)
	for t in TOOLS:
		var id: String = t[0]
		var b := _btn(t[1], 150, func() -> void:
			tool = id
			_build_ui())
		b.custom_minimum_size.y = 40
		if id == tool:
			UiStyle.chosen(b, TOOL_COL.get(id, UiStyle.TRIM))
		side.add_child(b)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 4)
	side.add_child(br)
	for n in [1, 2, 3, 5]:
		var nn: int = n
		var b := _btn(str(n), 34, func() -> void:
			brush = nn
			_build_ui())
		b.custom_minimum_size = Vector2(34, 36)
		if brush == n:
			UiStyle.chosen(b)
		br.add_child(b)
	if not Settings.pc():
		var pb := _btn("DRAG: " + ("PAN" if pan_mode else "PAINT"), 150, func() -> void:
			pan_mode = not pan_mode
			_build_ui())
		side.add_child(pb)


func _btn(t: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, 44)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(func() -> void:
		Sfx.play_any(["ui/click", "click"])
		cb.call())
	return b


func _show_load() -> void:
	var names := MapGen.custom_names()
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(420, 0)
	p.position = Vector2(-210, -220)
	_ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UiStyle.heading("YOUR MAPS", 26, UiStyle.TRIM))
	if names.is_empty():
		v.add_child(UiStyle.text("No saved maps yet.", 17, UiStyle.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, mini(names.size(), 6) * 50)
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for n in names:
		var nm: String = n
		var row := HBoxContainer.new()
		var b := _btn(nm, 300, func() -> void:
			p.queue_free()
			load_from(MapGen.load_custom(nm)))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		row.add_child(_btn("✕", 44, func() -> void:
			MapGen.delete_custom(nm)
			p.queue_free()
			_show_load()))
		list.add_child(row)
	v.add_child(_btn("CLOSE", 120, func() -> void: p.queue_free()))


func _save() -> bool:
	map_name = map_name.strip_edges().replace("/", "-").replace("\\", "-").replace(":", "-")
	if map_name == "":
		_say("Give the map a name first.")
		return false
	if starts.size() < 2:
		_say("Place at least two START SPOTS.")
		return false
	game.starts = starts.duplicate()
	for i in range(1, starts.size()):
		if not game._connected(starts[0], starts[i]):
			_say("Start %d can't be reached from start 1 by land." % (i + 1))
			return false
	if not MapGen.save_custom(to_data()):
		_say("Couldn't save the map.")
		return false
	_say("Saved \"%s\" (%d start spots, %d deposits)." % [map_name, starts.size(), deposits.size()])
	return true


func _say(t: String) -> void:
	_status = t
	queue_redraw()
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		if _status == t:
			_status = ""
			queue_redraw())


func _on_ui(p: Vector2) -> bool:
	for c in _ui.get_children():
		if c is Control and (c as Control).get_global_rect().has_point(p):
			return true
	return false


# ------------------------------------------------------------------ input

func _cell_at(screen: Vector2) -> Vector2i:
	var w: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * screen
	return Vector2i(floori(w.x / Game.T), floori(w.y / Game.T))


func _input(event: InputEvent) -> void:
	if game == null or not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if _on_ui(mb.position) and mb.pressed:
			return
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if Settings.pc() or not pan_mode:
					if mb.pressed:
						_painting = true
						_paint(mb.position, true)
					else:
						_end_stroke()
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_drag_from = mb.position if mb.pressed else Vector2.INF
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(1.12)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1 / 1.12)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _painting:
			_paint(mm.position, false)
		elif _drag_from != Vector2.INF:
			game.camera.position -= mm.relative / game.camera.zoom.x
		queue_redraw()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _on_ui(st.position):
				return
			_touches[st.index] = st.position
			if _touches.size() == 1 and not pan_mode:
				_painting = true
				_paint(st.position, true)
			elif _touches.size() == 2:
				_end_stroke()
				var ps: Array = _touches.values()
				_pinch = (ps[0] as Vector2).distance_to(ps[1])
		else:
			_touches.erase(st.index)
			if _touches.is_empty():
				_end_stroke()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _touches.has(sd.index):
			return
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var ps: Array = _touches.values()
			var d: float = (ps[0] as Vector2).distance_to(ps[1])
			if _pinch > 0.0:
				_zoom(d / _pinch)
			_pinch = d
			game.camera.position -= sd.relative * 0.5 / game.camera.zoom.x
		elif pan_mode:
			game.camera.position -= sd.relative / game.camera.zoom.x
		elif _painting:
			_paint(sd.position, false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not _name_edit.has_focus():
		var k := (event as InputEventKey).keycode
		var pan := {KEY_LEFT: Vector2(-1, 0), KEY_RIGHT: Vector2(1, 0), KEY_UP: Vector2(0, -1), KEY_DOWN: Vector2(0, 1),
			KEY_A: Vector2(-1, 0), KEY_D: Vector2(1, 0), KEY_W: Vector2(0, -1), KEY_S: Vector2(0, 1)}
		if pan.has(k):
			game.camera.position += pan[k] * 120.0 / game.camera.zoom.x
			queue_redraw()


func _zoom(f: float) -> void:
	var z := clampf(game.camera.zoom.x * f, 0.3, 2.5)
	game.camera.zoom = Vector2(z, z)
	queue_redraw()


## The cells a stroke at `c` touches, with the mirror copies.
func _mirrored(c: Vector2i, size := Vector2i.ONE) -> Array:
	var out: Array = [c]
	if mirror != "off":
		out.append(Vector2i(W - c.x - size.x, H - c.y - size.y))
	if mirror == "4-way":
		out.append(Vector2i(W - c.x - size.x, c.y))
		out.append(Vector2i(c.x, H - c.y - size.y))
	return out


func _paint(screen: Vector2, first: bool) -> void:
	var c := _cell_at(screen)
	if tool in MARKERS:
		if first:
			_place_marker(c, _dep_cell_at(screen))
		return
	var code: String = TOOLS[TOOLS.map(func(t: Array) -> String: return t[0]).find(tool)][2]
	var r := brush - 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if brush > 2 and dx * dx + dy * dy > r * r + 1:
				continue
			for m in _mirrored(c + Vector2i(dx, dy)):
				var mc: Vector2i = m
				if mc.x < 0 or mc.y < 0 or mc.x >= W or mc.y >= H:
					continue
				var i := mc.y * W + mc.x
				var put := code
				# trees and rocks keep the height they're painted on
				if code in ["t", "k"] and cells[i] in ["h", "T", "K"]:
					put = code.to_upper()
				if cells[i] != put:
					cells[i] = put
					_dirty[i] = tool
	queue_redraw()


func _end_stroke() -> void:
	if _painting and not _dirty.is_empty():
		_rebuild()
	_painting = false


## The top-left cell of the 2x2 outcrop centred nearest the pointer.
func _dep_cell_at(screen: Vector2) -> Vector2i:
	var w: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * screen
	return Vector2i(floori(w.x / Game.T - 0.5), floori(w.y / Game.T - 0.5))


func _place_marker(c: Vector2i, dc := Vector2i.ZERO) -> void:
	var at := c - Vector2i(2, 2)
	at.x = clampi(at.x, 1, W - HALL.x - 1)
	at.y = clampi(at.y, 1, H - HALL.y - 1)
	var added: Array = []
	match tool:
		"start":
			var copies := _mirrored(at, HALL)
			if mirror == "off":
				if starts.size() >= 4:
					starts.pop_front()
				starts.append(at)
			else:
				starts = copies.slice(0, 4)
			_say("%d start spots." % starts.size())
			added = [at]
		"hall":
			for m in _mirrored(at, HALL):
				if not halls.has(m):
					halls.append(m)
			added = [at]
		"saltpetre", "ore":
			var copies := _mirrored(dc, DEP)
			for m in copies:
				var r := Rect2i(m, DEP)
				if (starts + halls).any(func(sp: Vector2i) -> bool: return Rect2i(sp, HALL).intersects(r)):
					_say("Deposits can't go on a start or hall spot.")
					return
			deposits = deposits.filter(func(dp: Array) -> bool:
				return not copies.any(func(m: Vector2i) -> bool: return Rect2i(dp[0], DEP).intersects(Rect2i(m, DEP))))
			for m in copies:
				deposits.append([m, tool])
			var before := deposits.size()
			_respawn_deposits()
			if deposits.size() < before:
				_say("Deposits need open, flat, dry ground (no ramps, cliffs, water or trees).")
			return
		"erase":
			var hit := false
			for list in [starts, halls]:
				for s in list.duplicate():
					if Rect2i(s, HALL).grow(1).has_point(c):
						list.erase(s)
						hit = true
			if not hit:
				# an outcrop under the pointer goes, with its mirror copies
				for dp in deposits.duplicate():
					if Rect2i(dp[0], DEP).has_point(c):
						for m in _mirrored(dp[0], DEP):
							deposits = deposits.filter(func(o: Array) -> bool: return o[0] != m)
						_respawn_deposits()
						break
	game.starts = starts.duplicate()
	if not added.is_empty():
		# a new spot gets its line of deposits (unless it has outcrops near it already)
		var hc := Vector2(added[0]) + Vector2(HALL) * 0.5
		if not deposits.any(func(dp: Array) -> bool: return (Vector2(dp[0]) + Vector2.ONE).distance_to(hc) < 11.0):
			_lay_lines(added)
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if game == null:
		return
	var xf := game.get_viewport().get_canvas_transform()
	var t := float(Game.T)
	# freshly painted cells, until the ground is redrawn
	for i in _dirty:
		var c := Vector2i(i % W, i / W)
		var r := Rect2(xf * (Vector2(c) * t), Vector2(t, t) * xf.get_scale())
		draw_rect(r, Color(TOOL_COL.get(_dirty[i], Color.WHITE), 0.75))
	# start and hall spots
	for i in starts.size():
		var r := Rect2(xf * (Vector2(starts[i]) * t), Vector2(HALL) * t * xf.get_scale())
		var col: Color = Defs.PALETTE[i % Defs.PALETTE.size()][1]
		draw_rect(r, Color(col, 0.35))
		draw_rect(r, col, false, 3.0)
		_text(r.get_center() + Vector2(0, 10), str(i + 1), 30, Color.WHITE)
	for s in halls:
		var r := Rect2(xf * (Vector2(s) * t), Vector2(HALL) * t * xf.get_scale())
		draw_rect(r, Color(1, 0.85, 0.4, 0.15))
		draw_rect(r, Color(1, 0.85, 0.4, 0.8), false, 2.0)
		_text(r.get_center() + Vector2(0, 8), "HALL", 16, Color(1, 0.9, 0.6))
	# map edge
	draw_rect(Rect2(xf * Vector2.ZERO, Vector2(W, H) * t * xf.get_scale()), UiStyle.TRIM, false, 2.0)
	# brush outline under the mouse
	if Settings.pc():
		var mp := get_viewport().get_mouse_position()
		if not _on_ui(mp):
			var c := _cell_at(mp)
			if tool in ["saltpetre", "ore"]:
				for dm in _mirrored(_dep_cell_at(mp), DEP):
					var dr := Rect2(xf * (Vector2(dm) * t), Vector2(DEP) * t * xf.get_scale())
					draw_rect(dr, Color(TOOL_COL[tool], 0.35))
					draw_rect(dr, Color(1, 1, 1, 0.7), false, 1.5)
			else:
				for m in _mirrored(c):
					var r := Rect2(xf * (Vector2(m - Vector2i(brush - 1, brush - 1)) * t), Vector2(brush * 2 - 1, brush * 2 - 1) * t * xf.get_scale())
					if tool in ["start", "hall", "erase"]:
						r = Rect2(xf * (Vector2(m - Vector2i(2, 2)) * t), Vector2(HALL) * t * xf.get_scale())
					draw_rect(r, Color(1, 1, 1, 0.6), false, 1.5)
	# help and status
	var hint := "Left click paints · right drag or WASD moves · wheel zooms" if Settings.pc() else "Drag to paint · two fingers move and zoom"
	var line := _status if _status != "" else hint
	var font := UiStyle.bold_font()
	var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 30
	var sr := Rect2(size.x * 0.5 - w * 0.5, size.y - 46, w, 36)
	UiStyle.box(Color(0.1, 0.08, 0.06, 0.9), UiStyle.TRIM_DIM, 2, 18, 0.0).draw(get_canvas_item(), sr)
	_text(sr.get_center() + Vector2(0, 6), line, 17, Color(1, 0.9, 0.65) if _status != "" else UiStyle.TEXT)


func _text(p: Vector2, s: String, sz: int, col: Color) -> void:
	var f := UiStyle.bold_font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string_outline(f, p - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, 0.8))
	draw_string(f, p - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _process(_d: float) -> void:
	if Settings.pc():
		queue_redraw()
