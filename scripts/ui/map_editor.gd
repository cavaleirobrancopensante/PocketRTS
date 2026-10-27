class_name MapEditor
extends Control
## The map editor: a map of any size (48 x 48 to 192 x 192); paint ground, high ground,
## ramps, water (lava in the volcanic lands), fords, trees and rocks with a round or square
## brush (1-8) or a fill; place decorations (single ones or whole groups: farm, camp,
## ruins...); place 2-8 start spots with their teams (1v1 to 4v4, or everyone alone) and
## more hall spots; mirror everything (turned 180 or 90 degrees, left-right, top-bottom or
## 4 ways) so the map stays fair; CHECK it with the same checks as the named maps
## (MapCheck); undo; save it (user://maps/, with a picture for the lobby) and play it.

signal back_requested
signal play_requested(map_id: String, starts: int)
## Start over on a map of another size (a new map, or one loaded from disk): the main scene
## builds a fresh world of data["size"] and hands it back to load_from(data).
signal reopen_requested(data: Dictionary)

const HALL := Vector2i(5, 4)
const TOOLS := [
	["low", "GROUND", "."], ["high", "HIGH", "h"], ["ramp", "RAMP", "r"], ["water", "WATER", "w"],
	["ford", "FORD", "f"], ["tree", "TREES", "t"], ["rock", "ROCKS", "k"], ["prop", "PROPS", ""],
	["start", "START", ""], ["hall", "HALL", ""], ["team", "TEAM", ""], ["erase", "REMOVE", ""],
]
const TOOL_COL := {"low": Color(0.45, 0.65, 0.3), "high": Color(0.85, 0.75, 0.45), "ramp": Color(0.75, 0.55, 0.3),
	"water": Color(0.2, 0.45, 0.85), "ford": Color(0.5, 0.75, 0.9), "tree": Color(0.1, 0.4, 0.15), "rock": Color(0.55, 0.55, 0.55),
	"prop": Color(0.8, 0.6, 0.35), "start": Color(0.95, 0.85, 0.4), "hall": Color(1, 0.85, 0.4), "team": Color(0.6, 0.75, 1.0),
	"erase": Color(0.9, 0.4, 0.3)}
const TOOL_TIPS := {
	"low": "Low ground (paints over anything: also the eraser for terrain and decorations)",
	"high": "High ground: plateaus get cliffs all round, except where a ramp leads down",
	"ramp": "Ramp: paint across the edge of high ground; it's squared into a clean rectangle",
	"water": "Water (lava in volcanic lands): impassable", "ford": "Ford: shallow water units can cross",
	"tree": "Trees: impassable (they keep the height they're painted on)", "rock": "Rocks: impassable",
	"prop": "Decorations: pick one (or a whole group) on the right, click to place",
	"start": "Start spot: where a player's Town Hall stands (2-8)", "hall": "Hall spot: a place to expand to",
	"team": "Click a start spot to change its team", "erase": "Remove start and hall spots"}
const MIRRORS := ["off", "rotate", "mirror_lr", "mirror_tb", "4-way", "turn90"]
const MIRROR_NAMES := {"off": "OFF", "rotate": "TURN 180", "mirror_lr": "LEFT | RIGHT", "mirror_tb": "TOP | BOTTOM",
	"4-way": "4-WAY", "turn90": "TURN 90"}
const MIXES := ["diag", "patch", "middle"]
const MIX_NAMES := {"diag": "DIAGONAL", "patch": "PATCHES", "middle": "MIDDLE"}
const BIOME_LIST := ["grass", "autumn", "desert", "snow", "marsh", "volcanic", "heath", "jungle", "canyon", "tundra",
	"ashland", "pinewood", "steppe", "coast", "oldkingdom", "bog", "glowwood", "fall", "badlands"]
const KIND_ORDER := ["trees", "rocks", "plants", "ruins", "buildings", "camp", "farm", "stores"]
## New map sizes: [w, h, what it suits]
const SIZES := [[48, 48, "tiny 1v1"], [64, 64, "small 1v1"], [84, 60, "classic"], [80, 80, "1v1"],
	[96, 96, "1v1"], [112, 84, "wide 1v1"], [64, 104, "tall 1v1"], [88, 120, "tall 1v1"],
	[120, 100, "2v2"], [128, 96, "2v2"], [120, 120, "2v2"], [112, 136, "tall 2v2"],
	[160, 128, "3v3"], [144, 168, "tall 3v3"], [192, 160, "4v4"], [192, 192, "huge"]]
const UNDO_DEPTH := 40
const LETTERS := "ABCDEFGH"
const HELP_TEXT := """MAP EDITOR

NEW picks the size (presets from 48x48 to 192x192, or your own width and height in steps of 4). LOAD opens one of your maps, SAVE keeps it (with a picture for the lobby), PLAY saves it and takes you to Skirmish with it.

TERRAIN: GROUND (also the eraser), HIGH ground, RAMP, WATER (lava in volcanic and ashland), FORD, TREES and ROCKS. Brush sizes 1-8, ROUND or SQUARE; FILL floods a whole area of the same terrain. Plateaus get their cliffs as in the game. Paint a ramp across the edge of high ground: it is squared into a clean rectangle; a ramp that doesn't join high ground to low ground shows red.

PROPS: the 168 decorations by kind, and whole groups (farm, camp, ruins...). Click to place; ERASE (or a right click on a computer) removes one. Big ones (tents, houses, arches) block like rocks, small ones are only for looks.

SPOTS: START places a start spot (2-8, each with a team: TEAM changes it; 2 even teams make a 1v1 to 4v4 map, everyone alone a free-for-all), HALL places expansions, REMOVE takes spots away.

MIRROR copies everything you do: TURN 180 (as the named maps), LEFT | RIGHT, TOP | BOTTOM, 4-WAY, or TURN 90 on square maps. LAND and MIX pick the biomes (and how two are blended).

CHECK lists what's wrong and outlines it on the map: every start and hall spot reachable, each main on high ground with a ramp narrow enough to wall, no decorations on ramps or hall land, room for every start's economy, a mirror twin for everything. A map with problems can still be saved; one that passes also joins the random map pools of its mode.

UNDO / REDO (Ctrl+Z / Ctrl+Y) go back up to 40 steps.
Computer: left click paints, right drag or WASD moves, the wheel zooms, 1-8 set the brush. Phone: one finger paints (or moves the map: DRAG at the top switches), two fingers move and zoom."""

var game: Game
var W := 84
var H := 60
var map_name := "My map"
var cells := ""                 # one letter per cell, see MapGen.CELL_CODES
var starts: Array = []          # Vector2i, hall top-left; up to 8
var teams: Array = []           # each start's team (0 = A, 1 = B...)
var halls: Array = []           # expansion spots
var props: Array = []           # [name, x, y, flip]
var biome_a := "grass"
var biome_b := "grass"
var mix := "diag"
var tool := "high"
var brush := 2
var shape := "round"            # "round", "square", "fill"
var mirror := "rotate"
var prop_pick := "kit:farm"     # a decoration's name, or "kit:<group>"
var prop_erase := false
var pan_mode := false
var problems: Array = []        # the last CHECK (MapCheck.run)
var show_problems := false
var problem_sel := -1
var _bad_ramps: Array = []
var _painting := false
var _dirty := {}                # cell index -> tool painted (until the ground is redrawn)
var _stroke := {}               # cells painted in this stroke
var _drag_from := Vector2.INF
var _drag_moved := 0.0
var _touches := {}
var _pinch := 0.0
var _status := ""
var _name_edit: LineEdit
var _ui: Control
var _undo: Array = []
var _redo: Array = []
var _last_touch := Vector2.INF
var _new_size := Vector2i(120, 100)
var _left_scroll := 0
var _drawn_xf := Transform2D()  # the view the overlay was last drawn for (phones redraw only on change)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiStyle.theme()
	_build_ui()


## Fill the editor from a map's data (empty: a blank map the size of the game's world).
func load_from(data: Dictionary) -> void:
	W = Game.W
	H = Game.H
	if String(data.get("cells", "")) == "":
		cells = ".".repeat(W * H)
		starts = []
		teams = []
		halls = []
		props = []
		map_name = String(data.get("name", _free_name()))
	else:
		map_name = String(data.get("name", "My map"))
		cells = String(data.get("cells", ""))
		if cells.length() < W * H:
			cells += ".".repeat(W * H - cells.length())
		elif cells.length() > W * H:
			cells = cells.substr(0, W * H)
		starts = (data.get("starts", []) as Array).map(func(s: Array) -> Vector2i: return Vector2i(int(s[0]), int(s[1])))
		teams = MapGen.custom_teams(data)
		halls = (data.get("halls", []) as Array).map(func(s: Array) -> Vector2i: return Vector2i(int(s[0]), int(s[1])))
		props = (data.get("props", []) as Array).duplicate(true)
	if data.has("biome"):
		var parts: PackedStringArray = String(data.get("biome", "grass")).split("+")
		biome_a = parts[0] if MapGen.BIOMES.has(parts[0]) else "grass"
		biome_b = parts[1] if parts.size() > 1 and MapGen.BIOMES.has(parts[1]) else biome_a
	mix = String(data.get("mix", mix))
	mirror = String(data.get("mirror", mirror))
	if mirror == "2-way":
		mirror = "rotate"        # (older maps: the 2-way mirror was a turn through the middle)
	if not MIRRORS.has(mirror) or (mirror == "turn90" and W != H):
		mirror = "rotate"
	problems = []
	show_problems = false
	_undo.clear()
	_redo.clear()
	_fit_camera()
	_rebuild()
	_build_ui()


func _free_name() -> String:
	var names := MapGen.custom_names()
	var i := 1
	while names.has("My map %d" % i):
		i += 1
	return "My map %d" % i


func mode() -> String:
	return MapGen.mode_from_teams(teams)


func to_data() -> Dictionary:
	return {
		"name": map_name, "size": [W, H], "cells": cells, "mirror": mirror, "mix": mix,
		"biome": biome_a if biome_a == biome_b else "%s+%s" % [biome_a, biome_b],
		"starts": starts.map(func(s: Vector2i) -> Array: return [s.x, s.y]),
		"teams": teams.duplicate(), "mode": mode(),
		"halls": halls.map(func(s: Vector2i) -> Array: return [s.x, s.y]),
		"props": props.duplicate(true),
	}


## Redraw the world from the editor's map: ramps squared off (the cells follow), then
## cliffs, decorations, pathing and the ground as a match builds them. `ground`: false when
## only decorations changed (the ground picture stays).
func _rebuild(ground := true) -> void:
	var mg := game.mapgen
	mg.biome_a = biome_a
	mg.biome_b = biome_b
	mg.mix = mix
	if ground:
		# a painted ramp becomes a clean rectangle (MapGen._square_ramps); the cells it
		# drops take the high or low ground of their end
		mg.read_cells(cells)
		mg._square_ramps()
		for i in W * H:
			if cells[i] == "r" and mg.ramp[i] == 0:
				cells[i] = "h" if mg.height[i] == 1 else "."
	game.starts = starts.duplicate()
	game.base_sites = starts + halls
	if ground:
		game.rebuild_map(cells, props)
	else:
		game.refresh_props(props)
	# decorations that couldn't stand where they are (painted over) are gone
	props = mg.props.map(func(pr: Dictionary) -> Array:
		return [pr["name"], (pr["at"] as Vector2i).x, (pr["at"] as Vector2i).y, bool(pr["flip"])])
	_bad_ramps = MapCheck.bad_ramps(game)
	_dirty.clear()
	if show_problems:
		_run_check()
	queue_redraw()


func _fit_camera() -> void:
	var cam := game.camera
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var z := minf((vp.x - 480.0) / (W * Game.T), (vp.y - 120.0) / (H * Game.T))
	z = clampf(z, _min_zoom(), 1.2)
	cam.zoom = Vector2(z, z)
	cam.position = Vector2(W, H) * Game.T * 0.5 + Vector2(0, 10) / z


func _min_zoom() -> float:
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	return minf(0.3, minf(vp.x / (W * Game.T), vp.y / (H * Game.T)) * 0.7)


# ------------------------------------------------------------------ undo

func _snapshot() -> Dictionary:
	return {"cells": cells, "starts": starts.duplicate(), "teams": teams.duplicate(), "halls": halls.duplicate(),
		"props": props.duplicate(true), "biome_a": biome_a, "biome_b": biome_b, "mix": mix}


## Keep the map as it is now, before a change.
func _push_undo() -> void:
	_undo.append(_snapshot())
	if _undo.size() > UNDO_DEPTH:
		_undo.pop_front()
	_redo.clear()


func _restore(s: Dictionary) -> void:
	cells = s["cells"]
	starts = s["starts"]
	teams = s["teams"]
	halls = s["halls"]
	props = s["props"]
	biome_a = s["biome_a"]
	biome_b = s["biome_b"]
	mix = s["mix"]
	_rebuild()
	_build_ui()


func undo() -> void:
	if _undo.is_empty():
		_say("Nothing to undo.")
		return
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	_say("Undone (%d more)." % _undo.size())


func redo() -> void:
	if _redo.is_empty():
		_say("Nothing to redo.")
		return
	_undo.append(_snapshot())
	_restore(_redo.pop_back())
	_say("Redone.")


# ------------------------------------------------------------------ UI

func _phone() -> bool:
	return not Settings.pc()


func _build_ui() -> void:
	if _ui:
		var old_scroll := _ui.find_child("ToolScroll", true, false) as ScrollContainer
		if old_scroll:
			_left_scroll = old_scroll.scroll_vertical
		_ui.queue_free()
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	var vp := get_viewport_rect().size
	# dark backing under the top bar and the tools, so they stay readable over a zoomed-in
	# map (and nothing is painted by a click that just misses a button)
	for r in [Rect2(0, 0, vp.x, 50), Rect2(0, 50, 236, vp.y - 50)]:
		var bk := ColorRect.new()
		bk.color = Color(0.06, 0.05, 0.04, 0.82)
		bk.position = r.position
		bk.size = r.size
		bk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(bk)
	# top bar
	var top := HBoxContainer.new()
	top.position = Vector2(8, 6)
	top.add_theme_constant_override("separation", 5)
	_ui.add_child(top)
	top.add_child(_btn("BACK", 74, func() -> void: back_requested.emit()))
	_name_edit = LineEdit.new()
	_name_edit.text = map_name
	_name_edit.custom_minimum_size = Vector2(170, 44)
	_name_edit.max_length = 24
	_name_edit.tooltip_text = "The map's name"
	_name_edit.add_theme_stylebox_override("normal", UiStyle.box(Color(0.08, 0.07, 0.05, 0.95), UiStyle.TRIM_DIM, 2, 7, 10.0))
	_name_edit.text_changed.connect(func(t: String) -> void: map_name = t.strip_edges())
	UiStyle.touch_text(_name_edit, "The map's name")
	top.add_child(_name_edit)
	var info := UiStyle.text(("%dx%d" % [W, H]) if mode() == "-" else ("%s  %dx%d" % [mode(), W, H]), 17, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_CENTER, true)
	info.custom_minimum_size = Vector2(104, 44)
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.tooltip_text = "Mode (from the start spots' teams) and size in cells"
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(info)
	top.add_child(_btn("NEW", 62, func() -> void: _show_new(), "A new map: pick its size"))
	top.add_child(_btn("LOAD" if Loc.lang == "en" else Loc.t("LOAD MAP"), 66, func() -> void: _show_load(), "Open one of your maps"))
	top.add_child(_btn("SAVE", 66, func() -> void: _save(), "Save the map (it shows up in Skirmish)"))
	var chk := _btn("CHECK", 76, func() -> void:
		_run_check()
		show_problems = true
		problem_sel = -1
		_build_ui(), "Check the map for problems and outline them")
	if show_problems:
		UiStyle.chosen(chk, UiStyle.BAD if _faults() > 0 else UiStyle.GOOD)
	top.add_child(chk)
	var ub := _btn("UNDO", 70, func() -> void: undo(), "Undo (Ctrl+Z)")
	ub.disabled = _undo.is_empty()
	top.add_child(ub)
	var rb := _btn("REDO", 70, func() -> void: redo(), "Redo (Ctrl+Y)")
	rb.disabled = _redo.is_empty()
	top.add_child(rb)
	top.add_child(_btn("HELP", 66, func() -> void: _show_help()))
	var play := _btn("PLAY" if Loc.lang == "en" else Loc.t("PLAY MAP"), 80, func() -> void: _play(), "Save and play it in Skirmish")
	UiStyle.primary(play)
	top.add_child(play)
	if _phone():
		# what one finger does: paint, or move the map (kept up here, never scrolled away)
		var pb := _btn("DRAG: " + ("PAN" if pan_mode else "PAINT"), 128, func() -> void:
			pan_mode = not pan_mode
			_build_ui(), "One finger paints, or moves the map")
		if pan_mode:
			UiStyle.chosen(pb)
		top.add_child(pb)
	# tools (scrolls when the screen is short)
	var scroll := ScrollContainer.new()
	scroll.name = "ToolScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(8, 58)
	scroll.size = Vector2(222, vp.y - 58 - 52)
	_ui.add_child(scroll)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	scroll.add_child(side)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	side.add_child(grid)
	for t in TOOLS:
		var id: String = t[0]
		var label: String = t[1]
		if id == "water" and _lava():
			label = "LAVA"
		if id == "start" and Loc.lang != "en":
			label = Loc.t("START SPOT")      # (the lobby's START button is another word)
		var b := _btn(label, 98, func() -> void:
			tool = id
			_build_ui(), TOOL_TIPS.get(id, ""))
		b.custom_minimum_size.y = 40
		if id == tool:
			UiStyle.chosen(b, TOOL_COL.get(id, UiStyle.TRIM))
		else:
			b.add_theme_color_override("font_color", Color(TOOL_COL.get(id, UiStyle.TEXT)).lerp(UiStyle.TEXT, 0.55))
		grid.add_child(b)
	side.add_child(_small_label("BRUSH"))
	var bg := GridContainer.new()
	bg.columns = 4
	bg.add_theme_constant_override("h_separation", 4)
	bg.add_theme_constant_override("v_separation", 4)
	side.add_child(bg)
	for n in range(1, 9):
		var nn: int = n
		var b := _btn(str(n), 47, func() -> void:
			brush = nn
			if shape == "fill":
				shape = "round"
			_build_ui(), "Brush size %d (%d cells across)" % [n, n * 2 - 1])
		b.custom_minimum_size = Vector2(47, 36)
		if brush == n and shape != "fill":
			UiStyle.chosen(b)
		bg.add_child(b)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 4)
	side.add_child(sh)
	for s in [["round", "ROUND"], ["square", "SQUARE"], ["fill", "FILL"]]:
		var sid: String = s[0]
		var b := _btn(s[1], 64, func() -> void:
			shape = sid
			_build_ui(), {"round": "Round brush", "square": "Square brush", "fill": "Fill: floods the area of the same terrain you click"}[sid])
		b.custom_minimum_size = Vector2(64, 36)
		b.add_theme_font_size_override("font_size", 13)
		if shape == sid:
			UiStyle.chosen(b)
		sh.add_child(b)
	side.add_child(_small_label("MIRROR"))
	var mb := _btn(MIRROR_NAMES[mirror], 200, func() -> void:
		var i := MIRRORS.find(mirror)
		for k in MIRRORS.size():
			i = (i + 1) % MIRRORS.size()
			if MIRRORS[i] != "turn90" or W == H:
				break
		mirror = MIRRORS[i]
		_build_ui(), "What you paint and place is copied for the other players")
	mb.custom_minimum_size.y = 38
	side.add_child(mb)
	side.add_child(_small_label("LAND" if Loc.lang == "en" else Loc.t("BIOME LAND")))
	var lb := _btn(MapEditor.biome_title(biome_a), 200, func() -> void: _show_biomes(false), "The map's biome")
	lb.icon = _swatch(biome_a)
	lb.expand_icon = false
	lb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	lb.custom_minimum_size.y = 40
	side.add_child(lb)
	var xb := _btn("MIX: " + ("NONE" if biome_b == biome_a else MapEditor.biome_title(biome_b)), 200,
		func() -> void: _show_biomes(true), "A second biome blended in")
	if biome_b != biome_a:
		xb.icon = _swatch(biome_b)
	xb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	xb.custom_minimum_size.y = 40
	side.add_child(xb)
	if biome_b != biome_a:
		var bl := _btn("BLEND: " + MIX_NAMES.get(mix, "DIAGONAL"), 200, func() -> void:
			_push_undo()
			mix = MIXES[(MIXES.find(mix) + 1) % MIXES.size()]
			_rebuild()
			_build_ui(), "How the two biomes share the map")
		bl.custom_minimum_size.y = 38
		side.add_child(bl)
	(func() -> void:
		if is_instance_valid(scroll):
			scroll.scroll_vertical = _left_scroll).call_deferred()
	# the right side: CHECK's list, or the decorations
	if show_problems:
		_build_problems(vp)
	elif tool == "prop":
		_build_palette(vp)


func _small_label(t: String) -> Label:
	var l := UiStyle.text(t, 13, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
	l.custom_minimum_size.y = 18
	return l


func _lava() -> bool:
	return MapGen.BIOMES[biome_a]["water"] == "lava"


static func biome_title(b: String) -> String:
	return "OLD KINGDOM" if b == "oldkingdom" else b.to_upper()


## A biome's look: a small tile of its ground.
func _swatch(b: String) -> Texture2D:
	var low: Array = MapGen.BIOMES[b]["low"]
	var set_name: String = low[0]
	var good: Array = TerrainData.GOOD.get(set_name, TerrainData2.GOOD.get(set_name, [0]))
	var path := "res://assets/terrain/%s_%d.png" % [set_name, good[0]]
	if not ResourceLoader.exists(path):
		return null
	var img: Image = Game.tex(path).get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(28, 28, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)


func _btn(t: String, w: float, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, 44)
	b.add_theme_font_size_override("font_size", 15)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Sfx.play_any(["ui/click", "click"])
		cb.call())
	return b


func _panel(w: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.box(Color(0.08, 0.07, 0.055, 0.96), UiStyle.TRIM, 2, 9, 12.0))
	p.custom_minimum_size = Vector2(w, 0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


## A dialog in the middle of the screen (it closes the others).
func _dialog(w: float) -> Array:
	for c in _ui.get_children():
		if c.has_meta("dialog"):
			c.queue_free()
	var vp := get_viewport_rect().size
	var p := _panel(w)
	p.set_meta("dialog", true)
	_ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	(func() -> void:
		if is_instance_valid(p):
			p.size = p.get_combined_minimum_size()
			p.position = ((vp - p.size) * 0.5).floor()).call_deferred()
	return [p, v]


func _show_help() -> void:
	var d := _dialog(720)
	var v: VBoxContainer = d[1]
	var vp := get_viewport_rect().size
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, minf(470, vp.y - 160))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var l := UiStyle.text(Loc.paras(HELP_TEXT), 16, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 680
	scroll.add_child(l)
	v.add_child(_btn("CLOSE", 140, func() -> void: (d[0] as Control).queue_free()))


## NEW: pick the new map's size.
func _show_new() -> void:
	var d := _dialog(640)
	var p: Control = d[0]
	var v: VBoxContainer = d[1]
	v.add_child(UiStyle.heading("NEW MAP", 28, UiStyle.TRIM))
	v.add_child(UiStyle.text("Pick a size (cells across x down), or set your own below.", 15, UiStyle.MUTED))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for s in SIZES:
		var sz := Vector2i(s[0], s[1])
		var b := _btn("%dx%d\n%s" % [s[0], s[1], s[2]], 148, func() -> void:
			_new_size = sz
			_show_new())
		b.custom_minimum_size = Vector2(148, 52)
		b.add_theme_font_size_override("font_size", 14)
		if sz == _new_size:
			UiStyle.chosen(b)
		grid.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for axis in 2:
		var ax: int = axis
		row.add_child(UiStyle.text("WIDTH" if ax == 0 else "   HEIGHT", 16, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, true))
		row.add_child(_step_btn("-", func() -> void:
			_new_size[ax] = clampi(_new_size[ax] - 4, 32, MapGen.MAX_SIZE[ax])
			_show_new()))
		var val := UiStyle.text(str(_new_size[ax]), 22, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
		val.custom_minimum_size.x = 56
		row.add_child(val)
		row.add_child(_step_btn("+", func() -> void:
			_new_size[ax] = clampi(_new_size[ax] + 4, 32, MapGen.MAX_SIZE[ax])
			_show_new()))
	v.add_child(UiStyle.text("About 64-112 across suits 1v1, 112-136 2v2, 144-168 3v3, 192x160 4v4.", 14, UiStyle.MUTED))
	var bot := HBoxContainer.new()
	bot.alignment = BoxContainer.ALIGNMENT_CENTER
	bot.add_theme_constant_override("separation", 12)
	v.add_child(bot)
	bot.add_child(_btn("CANCEL", 140, func() -> void: p.queue_free()))
	var mk := _btn("CREATE %dx%d" % [_new_size.x, _new_size.y], 220, func() -> void:
		p.queue_free()
		reopen_requested.emit({"name": _free_name(), "size": [_new_size.x, _new_size.y],
			"biome": biome_a if biome_a == biome_b else "%s+%s" % [biome_a, biome_b], "mix": mix,
			"mirror": mirror if mirror != "turn90" or _new_size.x == _new_size.y else "rotate"}))
	UiStyle.primary(mk)
	bot.add_child(mk)


func _step_btn(t: String, cb: Callable) -> Button:
	var b := _btn(t, 46, cb)
	b.custom_minimum_size = Vector2(46, 44)
	b.add_theme_font_size_override("font_size", 22)
	return b


func _show_load() -> void:
	var names := MapGen.custom_names()
	var d := _dialog(520)
	var p: Control = d[0]
	var v: VBoxContainer = d[1]
	v.add_child(UiStyle.heading("YOUR MAPS", 26, UiStyle.TRIM))
	if names.is_empty():
		v.add_child(UiStyle.text("No saved maps yet.", 17, UiStyle.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, mini(names.size(), 7) * 50)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for n in names:
		var nm: String = n
		var md := MapGen.load_custom(nm)
		var cs := MapGen.custom_size(md)
		var row := HBoxContainer.new()
		var b := _btn("%s   (%s, %dx%d)" % [nm, MapGen.custom_mode(md), cs.x, cs.y], 400, func() -> void:
			p.queue_free()
			reopen_requested.emit(MapGen.load_custom(nm)))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(b)
		row.add_child(_btn("×", 44, func() -> void:
			MapGen.delete_custom(nm)
			_show_load(), "Delete this map"))
		list.add_child(row)
	v.add_child(_btn("CLOSE", 120, func() -> void: p.queue_free()))


## LAND / MIX: every biome with a tile of its ground.
func _show_biomes(second: bool) -> void:
	var d := _dialog(660)
	var p: Control = d[0]
	var v: VBoxContainer = d[1]
	v.add_child(UiStyle.heading("MIX WITH" if second else ("LAND" if Loc.lang == "en" else Loc.t("BIOME LAND")), 26, UiStyle.TRIM))
	var vp := get_viewport_rect().size
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, minf(420, vp.y - 170))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var list: Array = BIOME_LIST.duplicate()
	if second:
		list.push_front("")
	for bn in list:
		var b_name: String = bn
		var cur := (biome_b if second else biome_a)
		var chosen := (b_name == cur) or (second and b_name == "" and biome_b == biome_a)
		var b := _btn("NONE" if b_name == "" else MapEditor.biome_title(b_name), 205, func() -> void:
			p.queue_free()
			_push_undo()
			if second:
				biome_b = biome_a if b_name == "" else b_name
			else:
				if biome_b == biome_a:
					biome_b = b_name
				biome_a = b_name
			_rebuild()
			_build_ui())
		b.custom_minimum_size = Vector2(205, 46)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if b_name != "":
			b.icon = _swatch(b_name)
			if MapGen.BIOMES[b_name]["water"] == "lava":
				b.tooltip_text = "Its water is lava"
		if chosen:
			UiStyle.chosen(b)
		grid.add_child(b)
	v.add_child(_btn("CLOSE", 120, func() -> void: p.queue_free()))


## The decorations palette: whole groups first, then every decoration by kind.
func _build_palette(vp: Vector2) -> void:
	var w := 262.0
	var p := _panel(w)
	p.position = Vector2(vp.x - w - 8, 58)
	p.size = Vector2(w, vp.y - 58 - 52)
	_ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	v.add_child(hr)
	var place := _btn("PLACE", 112, func() -> void:
		prop_erase = false
		_build_ui(), "Click the map to place the picked decoration")
	place.custom_minimum_size.y = 38
	var era := _btn("ERASE", 112, func() -> void:
		prop_erase = true
		_build_ui(), "Click a decoration to remove it (a right click does it too)")
	era.custom_minimum_size.y = 38
	UiStyle.chosen(era if prop_erase else place, TOOL_COL["erase"] if prop_erase else TOOL_COL["prop"])
	hr.add_child(place)
	hr.add_child(era)
	var pick_txt := ""
	if prop_pick.begins_with("kit:"):
		pick_txt = "Group: %s (%d pieces)" % [prop_pick.substr(4), (MapGen.KITS[prop_pick.substr(4)] as Array).size()]
	else:
		pick_txt = "%s: %s" % [prop_pick.replace("_", " "), "blocks like a rock" if int(PropData.PROPS[prop_pick][2]) > 0 else "walked through"]
	var pl := UiStyle.text(pick_txt, 14, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pl.custom_minimum_size = Vector2(w - 28, 36)
	v.add_child(pl)
	v.add_child(_small_label("Red frame: blocks like a rock. Plain: looks only."))
	var scroll := ScrollContainer.new()
	scroll.name = "PropScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	list.add_child(_small_label("GROUPS"))
	var kg := GridContainer.new()
	kg.columns = 2
	kg.add_theme_constant_override("h_separation", 4)
	kg.add_theme_constant_override("v_separation", 4)
	list.add_child(kg)
	for k in MapGen.KITS:
		var kid := "kit:" + String(k)
		var b := _btn(String(k).to_upper(), 112, func() -> void:
			prop_pick = kid
			prop_erase = false
			_build_ui(), "Place the whole group (as the named maps do)")
		b.custom_minimum_size = Vector2(112, 34)
		b.add_theme_font_size_override("font_size", 13)
		if prop_pick == kid:
			UiStyle.chosen(b, TOOL_COL["prop"])
		kg.add_child(b)
	for kind in KIND_ORDER:
		list.add_child(_small_label(String(kind).to_upper()))
		var g := GridContainer.new()
		g.columns = 4
		g.add_theme_constant_override("h_separation", 4)
		g.add_theme_constant_override("v_separation", 4)
		list.add_child(g)
		for nm in PropData.PROPS:
			if PropData.KIND.get(nm, "stores") != kind:
				continue
			var pn: String = nm
			var b := Button.new()
			b.custom_minimum_size = Vector2(52, 52)
			b.icon = Game.tex("res://assets/props/%s.png" % pn)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = "%s (%s)" % [pn.replace("_", " "), "blocks" if int(PropData.PROPS[pn][2]) > 0 else "walk-through"]
			b.add_theme_constant_override("icon_max_width", 44)
			if pn == prop_pick:
				UiStyle.chosen(b, TOOL_COL["prop"])
			elif int(PropData.PROPS[pn][2]) > 0:
				# blocking ones get a darker frame
				b.add_theme_stylebox_override("normal", UiStyle.box(Color(0.2, 0.12, 0.08, 0.95), Color(0.6, 0.35, 0.25), 2, 7, 4.0))
			b.pressed.connect(func() -> void:
				Sfx.play_any(["ui/click", "click"])
				prop_pick = pn
				prop_erase = false
				var sc := _ui.find_child("PropScroll", true, false) as ScrollContainer
				var keep := sc.scroll_vertical if sc else 0
				_build_ui()
				(func() -> void:
					var sc2 := _ui.find_child("PropScroll", true, false) as ScrollContainer
					if sc2:
						sc2.scroll_vertical = keep).call_deferred())
			g.add_child(b)


## CHECK's findings: each one outlined on the map; a click shows it.
func _build_problems(vp: Vector2) -> void:
	var w := 262.0
	var p := _panel(w)
	p.position = Vector2(vp.x - w - 8, 58)
	p.size = Vector2(w, vp.y - 58 - 52)
	_ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var faults := _faults()
	var warns := problems.size() - faults
	# (two lines when there are both: one doesn't fit the panel)
	var plural := func(n: int, what: String) -> String: return "%d %s%s" % [n, what, "" if n == 1 else "S"]
	var head: String = "ALL GOOD" if problems.is_empty() else (plural.call(faults, "PROBLEM") if faults > 0 else plural.call(warns, "WARNING"))
	v.add_child(UiStyle.heading(head, 20, UiStyle.BAD if faults > 0 else (UiStyle.TRIM if warns > 0 else UiStyle.GOOD)))
	if faults > 0 and warns > 0:
		v.add_child(UiStyle.heading("and " + String(plural.call(warns, "warning")).to_lower(), 15, UiStyle.TRIM))
	if problems.is_empty():
		var ok := UiStyle.text("Every start can reach the others, each main has a ramp to wall, no decorations in the way, room for every economy.", 15, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		ok.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ok.custom_minimum_size.x = w - 28
		v.add_child(ok)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for i in problems.size():
		var k: int = i
		var pr: Dictionary = problems[i]
		var b := Button.new()
		b.text = ("! " if not pr["warn"] else "") + Loc.t(String(pr["text"]))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(w - 34, 44)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", Color(1, 0.6, 0.5) if not pr["warn"] else Color(1, 0.85, 0.5))
		if k == problem_sel:
			UiStyle.chosen(b, UiStyle.BAD if not pr["warn"] else UiStyle.TRIM)
		b.pressed.connect(func() -> void:
			Sfx.play_any(["ui/click", "click"])
			problem_sel = k
			var cs: Array = problems[k]["cells"]
			if not cs.is_empty():
				var r := Rect2(Vector2(cs[0]), Vector2.ONE)
				for c in cs:
					r = r.expand(Vector2(c)).expand(Vector2(c) + Vector2.ONE)
				game.camera.position = r.get_center() * Game.T
			_build_ui())
		list.add_child(b)
	v.add_child(_btn("CLOSE", 120, func() -> void:
		show_problems = false
		_build_ui()))


func _faults() -> int:
	return problems.filter(func(p: Dictionary) -> bool: return not p["warn"]).size()


func _run_check() -> void:
	problems = MapCheck.run(game, starts, halls, cells, mirror)


func _save() -> bool:
	map_name = map_name.strip_edges().replace("/", "-").replace("\\", "-").replace(":", "-")
	if map_name == "":
		_say("Give the map a name first.")
		return false
	_run_check()
	var data := to_data()
	data["checked"] = _faults() == 0 and starts.size() >= 2
	if not MapGen.save_custom(data):
		_say("Couldn't save the map.")
		return false
	_save_picture()
	if _faults() > 0:
		show_problems = true
		problem_sel = -1
		_build_ui()
		_say("Saved \"%s\", but CHECK found %d problem%s (listed on the right)." % [map_name, _faults(), "" if _faults() == 1 else "s"])
	else:
		_say("Saved \"%s\" (%s, %dx%d)." % [map_name, mode(), W, H])
	return true


## The lobby's picture of the map (as tools/make_map_previews.gd draws the named ones).
func _save_picture() -> void:
	var img: Image = game.minimap_img.duplicate()
	for y in H:
		for x in W:
			var i := y * W + x
			var col := img.get_pixel(x, y)
			if game.cliff[i] == 1:
				col = col.darkened(0.6)
			elif game.ramp[i] == 1:
				col = col.lightened(0.35)
			elif game.height[i] == 1:
				col = col.lightened(0.18)
			img.set_pixel(x, y, col)
	img.resize(W * 2, H * 2, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [MapGen.MAP_DIR, map_name])


func _play() -> void:
	if starts.size() < 2:
		_say("Place at least two START spots to play.")
		return
	if not _save():
		return
	for p in problems:
		if String(p["text"]).contains("can't be reached") and String(p["text"]).begins_with("Start"):
			_say("Every start must be reachable from start 1 before you can play it.")
			return
	play_requested.emit("custom:" + map_name, starts.size())


func _say(t: String) -> void:
	_status = t
	queue_redraw()
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if _status == t:
			_status = ""
			queue_redraw())


func _on_ui(p: Vector2) -> bool:
	for c in _ui.get_children():
		if c is Control and (c as Control).visible and (c as Control).get_global_rect().has_point(p):
			if c is HBoxContainer:
				# the top bar: only its buttons
				for b in c.get_children():
					if b is Control and (b as Control).get_global_rect().has_point(p):
						return true
				continue
			if c is ScrollContainer:
				var inner: Control = (c as ScrollContainer).get_child(0) if c.get_child_count() > 0 else null
				if inner and inner.get_global_rect().intersection((c as Control).get_global_rect()).has_point(p):
					return true
				continue
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
		# a press on the panel or the top bar is the button's; so is its release (unless it ends
		# a stroke that started on the map): eating the release left BACK, SAVE, HELP... dead
		if _on_ui(mb.position) and (mb.pressed or (not _painting and _drag_from == Vector2.INF)):
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
				if mb.pressed:
					_drag_from = mb.position
					_drag_moved = 0.0
				else:
					# a short right click on a decoration removes it
					if mb.button_index == MOUSE_BUTTON_RIGHT and _drag_moved < 6.0 and tool == "prop":
						_erase_prop(_cell_at(mb.position))
					_drag_from = Vector2.INF
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom(1.12, mb.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom(1 / 1.12, mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _painting:
			_paint(mm.position, false)
		elif _drag_from != Vector2.INF:
			_drag_moved += mm.relative.length()
			_pan(-mm.relative / game.camera.zoom.x)
		queue_redraw()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _on_ui(st.position):
				return
			_touches[st.index] = st.position
			_last_touch = st.position
			if _touches.size() == 1 and not pan_mode:
				_painting = true
				_paint(st.position, true)
			elif _touches.size() == 2:
				_end_stroke()
				var ps: Array = _touches.values()
				_pinch = (ps[0] as Vector2).distance_to(ps[1])
		else:
			if not _touches.has(st.index):
				return          # a tap that began on a button: its release is the button's (BACK did nothing on a phone)
			_touches.erase(st.index)
			if _touches.is_empty():
				_end_stroke()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _touches.has(sd.index):
			return
		_touches[sd.index] = sd.position
		_last_touch = sd.position
		if _touches.size() >= 2:
			var ps: Array = _touches.values()
			var d: float = (ps[0] as Vector2).distance_to(ps[1])
			if _pinch > 0.0:
				_zoom(d / _pinch, ((ps[0] as Vector2) + (ps[1] as Vector2)) * 0.5)
			_pinch = d
			_pan(-sd.relative * 0.5 / game.camera.zoom.x)
		elif pan_mode:
			_pan(-sd.relative / game.camera.zoom.x)
		elif _painting:
			_paint(sd.position, false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not _name_edit.has_focus():
		var ke := event as InputEventKey
		var k := ke.keycode
		if ke.ctrl_pressed or ke.meta_pressed:
			if k == KEY_Z and not ke.shift_pressed:
				undo()
			elif k == KEY_Y or (k == KEY_Z and ke.shift_pressed):
				redo()
			get_viewport().set_input_as_handled()
			return
		if k >= KEY_1 and k <= KEY_8:
			brush = k - KEY_0
			if shape == "fill":
				shape = "round"
			_build_ui()
			return
		var pan := {KEY_LEFT: Vector2(-1, 0), KEY_RIGHT: Vector2(1, 0), KEY_UP: Vector2(0, -1), KEY_DOWN: Vector2(0, 1),
			KEY_A: Vector2(-1, 0), KEY_D: Vector2(1, 0), KEY_W: Vector2(0, -1), KEY_S: Vector2(0, 1)}
		if pan.has(k):
			_pan(pan[k] * 160.0 / game.camera.zoom.x)


func _pan(d: Vector2) -> void:
	var cam := game.camera
	cam.position = (cam.position + d).clamp(Vector2(-200, -200), Vector2(W, H) * Game.T + Vector2(200, 200))
	queue_redraw()


## Zoom about a point on the screen (it stays under the cursor / fingers).
func _zoom(f: float, at := Vector2.INF) -> void:
	var cam := game.camera
	var before := Vector2.ZERO
	if at != Vector2.INF:
		before = game.get_viewport().get_canvas_transform().affine_inverse() * at
	var z := clampf(cam.zoom.x * f, _min_zoom(), 2.5)
	cam.zoom = Vector2(z, z)
	if at != Vector2.INF:
		cam.force_update_scroll()
		var after: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * at
		_pan(before - after)
	queue_redraw()


func _in(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func _code() -> String:
	for t in TOOLS:
		if t[0] == tool:
			return t[2]
	return ""


## Put a terrain letter on a cell (trees and rocks keep the height they're painted on).
func _set_cell(i: int, code: String) -> void:
	var put := code
	if code in ["t", "k"] and cells[i] in ["h", "T", "K"]:
		put = code.to_upper()
	if cells[i] != put:
		cells[i] = put
		_dirty[i] = tool
	_stroke[i] = true


func _paint(screen: Vector2, first: bool) -> void:
	var c := _cell_at(screen)
	if tool in ["start", "hall", "erase", "team"]:
		if first:
			_place_marker(c)
		return
	if tool == "prop":
		if first:
			if prop_erase:
				_erase_prop(c)
			else:
				_place_prop(c)
		return
	if first:
		_push_undo()
		_stroke.clear()
	var code := _code()
	if shape == "fill":
		if first:
			for m in MapCheck.mirror_cells(c, mirror, W, H):
				_fill(m, code)
		queue_redraw()
		return
	var r := brush - 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if shape == "round" and float(dx * dx + dy * dy) > (r + 0.5) * (r + 0.5):
				continue
			for m in MapCheck.mirror_cells(c + Vector2i(dx, dy), mirror, W, H):
				var mc: Vector2i = m
				if _in(mc):
					_set_cell(mc.y * W + mc.x, code)
	queue_redraw()


## Flood a region of the same terrain with `code`.
func _fill(c: Vector2i, code: String) -> void:
	if not _in(c):
		return
	var from := cells[c.y * W + c.x]
	var seen := PackedByteArray()
	seen.resize(W * H)
	var q: Array = [c]
	seen[c.y * W + c.x] = 1
	while not q.is_empty():
		var p: Vector2i = q.pop_back()
		_set_cell(p.y * W + p.x, code)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if _in(n) and seen[n.y * W + n.x] == 0 and cells[n.y * W + n.x] == from:
				seen[n.y * W + n.x] = 1
				q.append(n)


func _end_stroke() -> void:
	if _painting and not _stroke.is_empty():
		# decorations painted over are gone
		props = props.filter(func(pr: Array) -> bool:
			var at := Vector2i(int(pr[1]), int(pr[2]))
			for fc in [at] + MapGen.prop_foot(String(pr[0]), at):
				var f: Vector2i = fc
				if _in(f) and _stroke.has(f.y * W + f.x):
					return false
			return true)
		_stroke.clear()
		_rebuild()
		_build_ui()
	_painting = false


func _place_prop(c: Vector2i) -> void:
	if not _in(c):
		return
	var items: Array = []
	if prop_pick.begins_with("kit:"):
		for it in MapGen.KITS.get(prop_pick.substr(4), []):
			items.append([String(it[0]), c + Vector2i(int(it[1]), int(it[2]))])
	else:
		items.append([prop_pick, c])
	_push_undo()
	var n0 := props.size()
	var flip0 := randf() < 0.5
	for it in items:
		var nm: String = it[0]
		if not PropData.PROPS.has(nm):
			continue
		for m in MapCheck.mirror_points(Vector2(it[1]) + Vector2(0.5, 0.5), mirror, W, H):
			var p: Vector2 = m[0]
			var mc := Vector2i(floori(p.x), floori(p.y))
			if not _in(mc):
				continue
			var dup := false
			for pr in props:
				if int(pr[1]) == mc.x and int(pr[2]) == mc.y:
					dup = true
			if not dup:
				props.append([nm, mc.x, mc.y, flip0 != bool(m[1])])
	_rebuild(false)
	var placed := props.size() - (n0)
	if placed <= 0:
		_undo.pop_back()
		_say("No room there (not on water, cliffs, ramps, trees or other solid things).")
	_build_ui()


## Remove the decoration nearest this cell (and its mirror copies).
func _erase_prop(c: Vector2i) -> void:
	var best := -1
	var bd := 2.3
	for i in props.size():
		var pr: Array = props[i]
		var at := Vector2i(int(pr[1]), int(pr[2]))
		var d := Vector2(at).distance_to(Vector2(c))
		for fc in MapGen.prop_foot(String(pr[0]), at):
			d = minf(d, Vector2(fc).distance_to(Vector2(c)))
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return
	_push_undo()
	var gone: Array = props[best]
	var at0 := Vector2i(int(gone[1]), int(gone[2]))
	var twins := MapCheck.mirror_cells(at0, mirror, W, H)
	props = props.filter(func(pr: Array) -> bool:
		return not (String(pr[0]) == String(gone[0]) and twins.has(Vector2i(int(pr[1]), int(pr[2])))))
	_rebuild(false)
	_build_ui()


## Which team a new start spot joins: the side of the map it's on (left / right, or top /
## bottom on a tall map). TEAM changes it.
func _auto_team(at: Vector2i) -> int:
	var cx := at.x + HALL.x * 0.5
	var cy := at.y + HALL.y * 0.5
	if W >= H:
		return 0 if cx < W * 0.5 else 1
	return 0 if cy < H * 0.5 else 1


func _spot_at(list: Array, c: Vector2i) -> int:
	for i in list.size():
		if Rect2i(list[i], HALL).grow(1).has_point(c):
			return i
	return -1


func _place_marker(c: Vector2i) -> void:
	var at := c - Vector2i(2, 2)
	at.x = clampi(at.x, 1, W - HALL.x - 1)
	at.y = clampi(at.y, 1, H - HALL.y - 1)
	match tool:
		"start", "hall":
			var copies := MapCheck.mirror_rects(at, HALL, mirror, W, H)
			var fresh: Array = []
			for m in copies:
				var mc: Vector2i = m
				mc.x = clampi(mc.x, 1, W - HALL.x - 1)
				mc.y = clampi(mc.y, 1, H - HALL.y - 1)
				var clash := false
				for s in starts + halls + fresh:
					if Rect2i(s, HALL).grow(1).intersects(Rect2i(mc, HALL)):
						clash = true
				if not clash:
					fresh.append(mc)
			if fresh.is_empty():
				_say("There's a spot there already.")
				return
			if tool == "start" and starts.size() + fresh.size() > 8:
				_say("At most 8 start spots.")
				return
			_push_undo()
			for mc in fresh:
				if tool == "start":
					starts.append(mc)
					teams.append(_auto_team(mc))
				else:
					halls.append(mc)
			if tool == "start":
				_say("%d start spots: %s." % [starts.size(), mode()])
		"team":
			var k := _spot_at(starts, c)
			if k < 0:
				_say("Click a start spot to change its team.")
				return
			_push_undo()
			teams[k] = (int(teams[k]) + 1) % clampi(starts.size(), 2, 8)
			_say("Start %d: team %s. The map is %s." % [k + 1, LETTERS[teams[k]], mode()])
		"erase":
			var hit := false
			for list in [starts, halls]:
				var k := _spot_at(list, c)
				if k < 0:
					continue
				if not hit:
					_push_undo()
				hit = true
				var twins := MapCheck.mirror_rects(list[k], HALL, mirror, W, H)
				for i in range(list.size() - 1, -1, -1):
					for tw in twins:
						if (Vector2(list[i]) - Vector2(tw)).length() <= 1.5:
							list.remove_at(i)
							if is_same(list, starts):
								teams.remove_at(i)
							break
			if not hit:
				return
	game.starts = starts.duplicate()
	game.base_sites = starts + halls
	if show_problems:
		_run_check()
	_build_ui()
	queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if game == null:
		return
	var xf := game.get_viewport().get_canvas_transform()
	var t := float(Game.T)
	var sc := xf.get_scale()
	var cell_rect := func(c: Vector2i) -> Rect2:
		return Rect2(xf * (Vector2(c) * t), Vector2(t, t) * sc)
	# freshly painted cells, until the ground is redrawn
	for i in _dirty:
		draw_rect(cell_rect.call(Vector2i(i % W, i / W)), Color(TOOL_COL.get(_dirty[i], Color.WHITE), 0.75))
	# ramps that join nothing
	for c in _bad_ramps:
		var r: Rect2 = cell_rect.call(c)
		draw_rect(r, Color(1, 0.15, 0.1, 0.35))
		draw_rect(r, Color(1, 0.2, 0.15, 0.9), false, 1.5)
	# CHECK's findings
	if show_problems:
		for i in problems.size():
			var pr: Dictionary = problems[i]
			var col := Color(1, 0.25, 0.2) if not pr["warn"] else Color(1, 0.8, 0.3)
			var sel := i == problem_sel
			for c in pr["cells"]:
				var r: Rect2 = cell_rect.call(c)
				draw_rect(r, Color(col, 0.45 if sel else 0.2))
				draw_rect(r, Color(col, 1.0 if sel else 0.6), false, 2.0 if sel else 1.0)
	# mirror lines
	var mid := xf * (Vector2(W, H) * t * 0.5)
	var tl := xf * Vector2.ZERO
	var br := xf * (Vector2(W, H) * t)
	var lc := Color(1, 1, 1, 0.16)
	if mirror in ["mirror_lr", "4-way"]:
		draw_line(Vector2(mid.x, tl.y), Vector2(mid.x, br.y), lc, 2.0)
	if mirror in ["mirror_tb", "4-way"]:
		draw_line(Vector2(tl.x, mid.y), Vector2(br.x, mid.y), lc, 2.0)
	if mirror in ["rotate", "turn90"]:
		draw_circle(mid, 6.0, lc)
	# start and hall spots
	for i in starts.size():
		var r := Rect2(xf * (Vector2(starts[i]) * t), Vector2(HALL) * t * sc)
		var team := int(teams[i]) if i < teams.size() else 0
		var col: Color = Defs.PALETTE[team % Defs.PALETTE.size()][1]
		draw_rect(r, Color(col, 0.35))
		draw_rect(r, col, false, 3.0)
		_text(r.get_center() + Vector2(0, 4), str(i + 1), clampi(int(30 * sc.x * 1.6), 14, 34), Color.WHITE)
		_text(r.get_center() + Vector2(0, r.size.y * 0.5 - 4), "TEAM " + LETTERS[team % 8], clampi(int(14 * sc.x * 1.6), 10, 16), Color(1, 1, 1, 0.9))
	for s in halls:
		var r := Rect2(xf * (Vector2(s) * t), Vector2(HALL) * t * sc)
		draw_rect(r, Color(1, 0.85, 0.4, 0.15))
		draw_rect(r, Color(1, 0.85, 0.4, 0.8), false, 2.0)
		_text(r.get_center() + Vector2(0, 6), "HALL", clampi(int(16 * sc.x * 1.6), 10, 18), Color(1, 0.9, 0.6))
	# the picked CHECK finding gets a frame round it, over the spots (many findings are
	# about a spot), so it shows even zoomed far out
	if show_problems and problem_sel >= 0 and problem_sel < problems.size():
		var pr: Dictionary = problems[problem_sel]
		var col := Color(1, 0.25, 0.2) if not pr["warn"] else Color(1, 0.8, 0.3)
		var box := Rect2()
		for c in pr["cells"]:
			var r: Rect2 = cell_rect.call(c)
			box = r if box.size == Vector2.ZERO else box.merge(r)
		if box.size != Vector2.ZERO:
			draw_rect(box.grow(8.0), Color(0, 0, 0, 0.6), false, 5.0)
			draw_rect(box.grow(8.0), col, false, 3.0)
	# map edge
	draw_rect(Rect2(tl, br - tl), UiStyle.TRIM, false, 2.0)
	# the brush (under the mouse, or where the finger last was)
	var mp := get_viewport().get_mouse_position() if Settings.pc() else _last_touch
	var tip := ""
	if mp != Vector2.INF and not _on_ui(mp):
		var c := _cell_at(mp)
		if Settings.pc() and _bad_ramps.has(c):
			tip = "This ramp doesn't join high ground to low ground: paint it across a plateau's edge."
		var oc := Color(1, 1, 1, 0.75)
		if tool in ["start", "hall", "erase", "team"]:
			var at := c - Vector2i(2, 2)
			for m in (MapCheck.mirror_rects(at, HALL, mirror, W, H) if tool in ["start", "hall"] else [at]):
				draw_rect(Rect2(xf * (Vector2(m) * t), Vector2(HALL) * t * sc), oc, false, 1.5)
		elif tool == "prop":
			if prop_erase:
				draw_rect(cell_rect.call(c), Color(1, 0.3, 0.2, 0.8), false, 2.0)
			else:
				var items: Array = []
				if prop_pick.begins_with("kit:"):
					for it in MapGen.KITS.get(prop_pick.substr(4), []):
						items.append([String(it[0]), c + Vector2i(int(it[1]), int(it[2]))])
				else:
					items.append([prop_pick, c])
				for it in items:
					for m in MapCheck.mirror_points(Vector2(it[1]) + Vector2(0.5, 0.5), mirror, W, H):
						var p: Vector2 = m[0]
						var mc := Vector2i(floori(p.x), floori(p.y))
						var tx: Texture2D = Game.tex("res://assets/props/%s.png" % it[0])
						var foot := Vector2(mc.x + 0.5, mc.y + 1.0) * t + Vector2(0, -5)
						var sz := tx.get_size() * sc
						var pos := xf * foot - Vector2(sz.x * 0.5, sz.y - 3 * sc.y)
						draw_texture_rect(tx, Rect2(pos, sz), false, Color(1, 1, 1, 0.55))
						draw_rect(cell_rect.call(mc), Color(1, 1, 1, 0.5), false, 1.0)
		elif shape == "fill":
			for m in MapCheck.mirror_cells(c, mirror, W, H):
				var r: Rect2 = cell_rect.call(m)
				draw_rect(r, oc, false, 2.0)
				draw_line(r.position, r.end, oc, 1.5)
				draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), oc, 1.5)
		else:
			var rr := brush - 1
			for m in MapCheck.mirror_cells(c, mirror, W, H):
				var ctr := xf * ((Vector2(m) + Vector2(0.5, 0.5)) * t)
				if shape == "round" and brush > 1:
					draw_arc(ctr, (rr + 0.5) * t * sc.x, 0, TAU, 48, oc, 1.5)
				else:
					var half := (rr + 0.5) * t * sc.x
					draw_rect(Rect2(ctr - Vector2(half, half), Vector2(half, half) * 2.0), oc, false, 1.5)
	# help and status
	var hint := "Left click paints · right drag or WASD moves · wheel zooms · 1-8 brush · Ctrl+Z undo" if Settings.pc() else "Drag to paint · two fingers move and zoom"
	if tool == "prop":
		hint = ("Click a decoration to remove it" if prop_erase else "Click to place · right click removes") if Settings.pc() else ("Tap a decoration to remove it" if prop_erase else "Tap to place")
	var line := _status if _status != "" else (tip if tip != "" else hint)
	var font := UiStyle.bold_font()
	var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 30
	var sr := Rect2(size.x * 0.5 - w * 0.5, size.y - 46, w, 36)
	UiStyle.box(Color(0.1, 0.08, 0.06, 0.9), UiStyle.TRIM_DIM, 2, 18, 0.0).draw(get_canvas_item(), sr)
	_text(sr.get_center() + Vector2(0, 6), line, 17, Color(1, 0.9, 0.65) if _status != "" else (Color(1, 0.6, 0.5) if tip != "" else UiStyle.TEXT))


func _text(p: Vector2, text: String, sz: int, col: Color) -> void:
	var s := Loc.t(text)
	var f := UiStyle.bold_font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string_outline(f, p - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, 0.8))
	draw_string(f, p - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _process(_d: float) -> void:
	if Settings.pc():
		queue_redraw()
	elif game:
		# a phone has no mouse to follow, but the spots, outlines and brush must follow the
		# view when it moves (two-finger pan and zoom, a jump to a CHECK finding, NEW, LOAD)
		var xf := game.get_viewport().get_canvas_transform()
		if xf != _drawn_xf:
			_drawn_xf = xf
			queue_redraw()
