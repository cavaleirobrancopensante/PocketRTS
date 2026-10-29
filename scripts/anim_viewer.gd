class_name AnimViewer
extends Control
## ANIMATION VIEWER (Settings): every strip of ArtData.UNITS, looped at the game's frame rate,
## for reviewing art without playing a match. Reads ArtData/Defs/Unit directly so it cannot drift.
## Strips are "<anim>_<dir>" with dirs s/se/e/ne/n; sw/w/nw are the mirrored views the game draws, or the art's own
## sw/w/nw strips when it has them (drawn unflipped, as the game does: Unit.WEST_OF).

signal back_pressed

const SHOW_DIRS := ["s", "se", "e", "ne", "n", "sw", "w", "nw"]
const MIRROR := {"sw": "se", "w": "e", "nw": "ne"}
const ZOOMS := [1, 4, 8]
const FACTION_ORDER := ["crown", "clockwork", "brood", "other"]

## Strips that still need ChatGPT art, and why (docs/art_style_inconsistency.md has the detail).
const NEEDS_ART := {
	"labourer": "carry and keg-carry have pasted legs (prompts 08, 09); build, hoe, death, bury redraws",
	"musketeer": "front and back walks barely step",
	"musketeer_armoured": "pasted legs, mixed style (prompt 16)",
	"dismounted": "officer idle / aim / fire / death poses are code-made (prompts 10-13)",
	"missionary": "cassock hides the legs: whole-figure walk redraw",
	"windup_soldier": "walk legs are code-built, tiny sprite",
	"winder": "wind / repair: the crank turning in his hands is code-drawn",
	"raptor": "front and back stride is small (prompt 18)",
	"horse": "riderless horse walk (prompts 20-25)",
	"horseman": "horse legs painted into the strip",
	"cuirassier": "horse legs painted into the strip",
	"dragoon": "horse legs painted into the strip",
	"dragoon_armoured": "horse legs painted into the strip",
	"messenger": "horse legs painted into the strip",
	"missionary_mounted": "horse legs painted into the strip",
	"horse_team": "harness horse barely lifts a hoof front/back",
	"mortar": "harness horse legs",
	"cannon": "harness horse legs",
	"powder_wagon": "harness horse legs",
}

var art := ""
var anim := ""
var dir := "e"
var zoom_i := 1
var zoom_f := 4.0                # continuous: pinch with two fingers, wheel, or the ZOOM button (presets)
var _pinch := {}                 # touch index -> position, while fingers are down
var _pinch_prev := 0.0
var grid_mode := false
var paused := false
var frame := 0
var flagged: Array[String] = []

var _t := 0.0
var _last_shown := -1
var _groups := {}               # faction -> Array of art names
var _faction := "crown"
var _art_kind := {}
var _unit_box: VBoxContainer
var _anim_box: VBoxContainer
var _dir_row: HFlowContainer
var _preview: Control
var _info: Label
var _frame_lbl: Label
var _note: LineEdit
var _flag_lbl: Label
var _pause_btn: Button
var _grid_btn: Button
var _zoom_btn: Button
var _faction_btns := {}
var needs_only := false
var pan := Vector2.ZERO          # the preview's offset: drag it to centre the unit
var _scrolls: Array[ScrollContainer] = []
var _touch_id := -1
var _touch_target: Object = null  # a ScrollContainer or the preview
var _touch_start := Vector2.ZERO
var _touch_drag := false
var _block_until := 0
var _copied_lbl: Label
var _needs_btn: Button


## Animation names of an art with the directions each has: {"walk": ["s","se",...]}.
static func anims_of(a: String) -> Dictionary:
	var out := {}
	var frames: Dictionary = ArtData.UNITS[a]["frames"]
	for key in frames:
		for d in ArtData.DIRS:
			if String(key).ends_with("_" + d):
				var nm := String(key).substr(0, String(key).length() - d.length() - 1)
				if not out.has(nm):
					out[nm] = []
				out[nm].append(d)
				break
	return out


## Frames in the strip, or 0 when it does not exist.
static func strip_frames(a: String, an: String, d: String) -> int:
	var fr: Dictionary = ArtData.UNITS[a]["frames"]
	return int(fr.get(an + "_" + d, fr.get(an + "_" + MIRROR.get(d, d), 0)))


## Is view d of strip `an` the east one mirrored (not the art's own west strip)?
static func mirrored(a: String, an: String, d: String) -> bool:
	return MIRROR.has(d) and not ArtData.UNITS[a]["frames"].has(an + "_" + d)


## Frames a second the game plays animation `an` of art `a` at (mirrors Unit._animate).
static func fps_for(a: String, an: String, n: int) -> float:
	var kind: String = _kind_of(a)
	var fps := Unit.walk_fps_for(a)
	if an == "walk" and Unit.GALLOPERS.has(a):
		fps *= Unit.CUIRASSIER_GALLOP_FPS / Unit.WALK_FPS * n / 8.0
	if an == "walk" and Unit.WALK_CYCLE_ART.has(a):
		fps *= float(n) / float(Unit.WALK_CYCLE_ART[a])
	match an:
		"idle", "idle_carry", "gidle", "idle_cocoon", "graze":
			fps = 2.0 if an != "gidle" and an != "idle_cocoon" else 3.0
			if kind == "skywing" and an == "idle":
				fps = Unit.SKYWING_HOVER_FPS
		"death", "death_cocoon", "gdeath", "death_keg":
			fps = 7.0
		"gattack":
			fps = 9.0
		"land":
			fps = float(n) / Defs.SKYWING_SWITCH
		"idle_keg":
			fps = 0.75 * float(n)
		"wrap":
			fps = 5.0 / float(Defs.HARVEST["take"])
		"pistol":
			fps = float(n) / (float(Defs.PISTOL["aim"]) + 0.35)
		"aim", "fire", "aimup", "fireup", "thrust", "attack", "melee":
			fps = 9.0
		"burrow", "dig":
			fps = 7.0
		"morph":
			fps = 3.2
		"leap", "charge", "spinup", "windup", "braced_hit":
			fps = 10.0
		"crank":
			fps = 6.0
		"repair", "wind", "vent":
			fps = 5.0
		"block":
			fps = 12.0
		"mine", "build":
			fps = 6.0
		"reload":
			var cd := float(Defs.UNITS.get(kind, {}).get("cooldown", 2.0))
			fps = float(n) / maxf(cd * 0.8, 0.5)
		"deploy":
			fps = float(n) / maxf(float(Defs.UNITS.get(kind, {}).get("switch", 1.5)), 0.3)
		"brace":
			fps = float(n) / float(Defs.BRACE["switch"])
		"deployed":
			fps = 6.0
		"cast", "fog":
			fps = 8.0
		"tongue":
			fps = 14.0
		"bandage":
			fps = 4.0
		"mount":
			fps = float(n) / 1.0
	return maxf(fps, 0.5)


## Is strip `an` of art `a` a melee timed to the blow (Unit.MELEE_HIT: the hit frame shows as the blow lands)?
static func timed_melee(a: String, an: String) -> bool:
	return an == "melee" and Unit.MELEE_HIT.has(a)


## The frame of a blow-timed melee at `t` s into a loop of: the aim (Defs.BAYONET "aim"), the strike (0.35 s,
## Unit._strike_time) and a short rest on the guard.
static func melee_frame_at(a: String, n: int, t: float) -> int:
	var aim := float(Defs.BAYONET["aim"])
	var strike := 0.35
	t = fmod(t, aim + strike + 0.3)
	if t < aim:
		return Unit.melee_frame(a, n, false, t / aim)
	if t < aim + strike:
		return Unit.melee_frame(a, n, true, (t - aim) / strike)
	return n - 1


## Does art `a` play strip `an` on the Winder's clockwork beat (Unit.WINDER_BEAT) rather than at a frame rate?
static func on_beat(a: String, an: String) -> bool:
	return a == "winder" and Unit.beat_of(an) != ""


static var _kind_cache := {}


## The unit kind an art belongs to (for its faction and scale): exact art match, else longest prefix.
static func _kind_of(a: String) -> String:
	if _kind_cache.has(a):
		return _kind_cache[a]
	var best := ""
	for k in Defs.UNITS:
		if Defs.art_for(k, false) == a or Defs.art_for(k, true) == a:
			best = k
			break
	if best == "":
		for k in Defs.UNITS:
			if a.begins_with(k) and k.length() > best.length():
				best = k
	_kind_cache[a] = best
	return best


static func faction_of(a: String) -> String:
	var k := _kind_of(a)
	return String(Defs.UNITS[k].get("faction", "other")) if k != "" else "other"


static func art_scale(a: String) -> float:
	var k := _kind_of(a)
	return float(Defs.UNITS[k].get("art_scale", 1.0)) if k != "" else 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for a in ArtData.UNITS:
		var f := faction_of(a)
		if not _groups.has(f):
			_groups[f] = []
		_groups[f].append(a)
	for f in _groups:
		_groups[f].sort()
	_build()
	var first := ""
	for f in FACTION_ORDER:
		if _groups.has(f) and first == "":
			first = _groups[f][0]
			_faction = f
	select_art(first)


func _btn(t: String, cb: Callable, h := 44.0) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(func() -> void:
		if Time.get_ticks_msec() < _block_until:
			return                  # the finger lifted at the end of a drag, not a tap
		Sfx.play_any(["ui/click", "click"])
		cb.call())
	return b


func _scroll(box: VBoxContainer, w: float) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.custom_minimum_size.x = w
	s.scroll_deadzone = 100000       # touch dragging is handled by _input below (works over buttons too)
	_scrolls.append(s)
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(box)
	return s


func _build() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	add_child(m)
	var p := PanelContainer.new()
	m.add_child(p)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	p.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var t := UiStyle.heading("ANIMATION VIEWER", 28, UiStyle.TRIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var bk := _btn("BACK", func() -> void: back_pressed.emit())
	bk.custom_minimum_size.x = 140
	top.add_child(bk)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	# left: units by faction
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 190
	cols.add_child(left)
	var fr := HFlowContainer.new()
	left.add_child(fr)
	for f in FACTION_ORDER:
		if not _groups.has(f):
			continue
		var b := _btn(f.to_upper(), func() -> void:
			_faction = f
			_fill_units()
			select_art(_groups[f][0]), 38.0)
		b.add_theme_font_size_override("font_size", 13)
		fr.add_child(b)
		_faction_btns[f] = b
	_needs_btn = _btn("", func() -> void:
		needs_only = not needs_only
		_fill_units()
		_refresh(), 38.0)
	_needs_btn.add_theme_font_size_override("font_size", 13)
	left.add_child(_needs_btn)
	var uc := HBoxContainer.new()
	left.add_child(uc)
	for pair in [["< UNIT", -1], ["UNIT >", 1]]:
		var ub := _btn(pair[0], func() -> void: cycle_art(pair[1]), 38.0)
		ub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ub.add_theme_font_size_override("font_size", 13)
		uc.add_child(ub)
	_unit_box = VBoxContainer.new()
	left.add_child(_scroll(_unit_box, 190))
	# centre: preview and controls
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 6)
	cols.add_child(mid)
	_info = UiStyle.text("", 16, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	mid.add_child(_info)
	_preview = Preview.new()
	_preview.viewer = self
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(240, 200)
	_preview.clip_contents = true
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mid.add_child(_preview)
	var ctl := HFlowContainer.new()
	mid.add_child(ctl)
	_pause_btn = _btn("PAUSE", func() -> void: set_paused(not paused))
	ctl.add_child(_pause_btn)
	ctl.add_child(_btn("< FRAME", func() -> void: step(-1)))
	_frame_lbl = UiStyle.text("", 18, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_CENTER, true)
	_frame_lbl.custom_minimum_size.x = 120
	ctl.add_child(_frame_lbl)
	ctl.add_child(_btn("FRAME >", func() -> void: step(1)))
	_zoom_btn = _btn("", func() -> void:
		var nxt := 0.0
		for z in ZOOMS:
			if float(z) > zoom_f + 0.01:
				nxt = float(z)
				break
		zoom_f = nxt if nxt > 0.0 else float(ZOOMS[0])
		_refresh())
	ctl.add_child(_zoom_btn)
	_grid_btn = _btn("", func() -> void:
		grid_mode = not grid_mode
		_refresh())
	ctl.add_child(_grid_btn)
	ctl.add_child(_btn("CENTER", func() -> void:
		pan = Vector2.ZERO
		_preview.queue_redraw()))
	ctl.add_child(_btn("COPY NAME", copy_name))
	_copied_lbl = UiStyle.text("", 14, UiStyle.TRIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	mid.add_child(_copied_lbl)
	# right: animations, directions, flags
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 250
	right.add_theme_constant_override("separation", 6)
	cols.add_child(_scroll(right, 262))      # the whole column scrolls on a short phone screen
	right.add_child(UiStyle.text("POSE  (keys: Up / Down)", 14, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	right.add_child(_pair_row("< POSE", "POSE >", func(d: int) -> void: cycle_anim(d)))
	_anim_box = VBoxContainer.new()
	var asc := _scroll(_anim_box, 250)
	asc.custom_minimum_size.y = 200
	right.add_child(asc)
	right.add_child(UiStyle.text("DIRECTION  (keys: Left / Right)", 14, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	right.add_child(_pair_row("< DIR", "DIR >", func(d: int) -> void: cycle_dir(d)))
	_dir_row = HFlowContainer.new()
	right.add_child(_dir_row)
	_note = LineEdit.new()
	_note.placeholder_text = "note for the flagged frame"
	_note.custom_minimum_size.y = 44
	_note.focus_mode = Control.FOCUS_ALL
	_note.mouse_filter = Control.MOUSE_FILTER_STOP
	_note.virtual_keyboard_enabled = true
	_note.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed):
			_note.grab_focus()
			if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
				DisplayServer.virtual_keyboard_show(_note.text, Rect2(_note.get_global_rect()), DisplayServer.KEYBOARD_TYPE_DEFAULT))
	right.add_child(_note)
	var fl := HBoxContainer.new()
	right.add_child(fl)
	var fb := _btn("FLAG FRAME", flag_frame)
	fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.primary(fb)
	fl.add_child(fb)
	var cp := _btn("COPY", func() -> void: DisplayServer.clipboard_set("\n".join(flagged)))
	fl.add_child(cp)
	var cl := _btn("CLEAR", func() -> void:
		flagged.clear()
		_refresh())
	fl.add_child(cl)
	var fv := VBoxContainer.new()
	_flag_lbl = UiStyle.text("", 13, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	_flag_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_flag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fv.add_child(_flag_lbl)
	var fs := _scroll(fv, 250)
	fs.custom_minimum_size.y = 60
	right.add_child(fs)
	_fill_units()


func _pair_row(l: String, r: String, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	for pair in [[l, -1], [r, 1]]:
		var b := _btn(pair[0], func() -> void: cb.call(pair[1]), 40.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


## Every art in list order (factions in FACTION_ORDER), honouring the needs-art filter.
func _art_order() -> Array:
	var out := []
	for f in FACTION_ORDER:
		for a in _groups.get(f, []):
			if not needs_only or NEEDS_ART.has(a):
				out.append(a)
	return out


func cycle_art(delta: int) -> void:
	var order := _art_order()
	if order.is_empty():
		return
	var i := order.find(art)
	select_art(order[posmod(i + delta, order.size())] if i >= 0 else order[0])


## Next / previous pose of the current unit (walk first, as in the list); keeps the direction when it exists.
func cycle_anim(delta: int) -> void:
	var names := _anim_names(art)
	if names.is_empty():
		return
	var i := names.find(anim)
	select_anim(names[posmod(i + delta, names.size())])


## Next / previous direction that exists for the current pose, around the compass.
func cycle_dir(delta: int) -> void:
	var i := SHOW_DIRS.find(dir)
	for k in range(1, SHOW_DIRS.size() + 1):
		var d: String = SHOW_DIRS[posmod(i + delta * k, SHOW_DIRS.size())]
		if strip_frames(art, anim, d) > 0:
			select_dir(d)
			return


## Dragging a finger (or the mouse) over a list scrolls it; over the picture it moves the picture.
func _touch(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_pinch[e.index] = e.position
			if _pinch.size() == 2:
				_pinch_prev = _pinch_dist()
				_touch_target = null
				_touch_id = -1
				return
		else:
			_pinch.erase(e.index)
			_pinch_prev = 0.0
		if e.pressed:
			_touch_id = e.index
			_touch_start = e.position
			_touch_drag = false
			_touch_target = _target_at(e.position)
		elif e.index == _touch_id:
			if _touch_drag:
				_block_until = Time.get_ticks_msec() + 250
			_touch_id = -1
			_touch_target = null
			_touch_drag = false
		return
	_pinch[e.index] = e.position
	if _pinch.size() == 2 and _pinch_prev > 0.0:
		var d := _pinch_dist()
		if _preview != null and _preview.get_global_rect().has_point(_pinch.values()[0]):
			zoom_f = clampf(zoom_f * d / _pinch_prev, 1.0, 16.0)
			_refresh()
		_pinch_prev = d
		_block_until = Time.get_ticks_msec() + 250
		return
	if e.index != _touch_id or _touch_target == null:
		return
	if not _touch_drag and e.position.distance_to(_touch_start) < 12.0:
		return
	_touch_drag = true
	if _touch_target is ScrollContainer:
		_touch_target.scroll_vertical -= int(e.relative.y)
	elif _touch_target == _preview:
		pan += e.relative
		_preview.queue_redraw()


func _pinch_dist() -> float:
	var v: Array = _pinch.values()
	return maxf((v[0] as Vector2).distance_to(v[1] as Vector2), 1.0)


func _target_at(p: Vector2) -> Object:
	if _preview != null and _preview.get_global_rect().has_point(p):
		return _preview
	for i in range(_scrolls.size() - 1, -1, -1):        # the inner lists were added after their columns
		var sc := _scrolls[i]
		if is_instance_valid(sc) and sc.is_visible_in_tree() and sc.get_global_rect().has_point(p):
			return sc
	return null


func _anim_names(a: String) -> Array:
	var names: Array = anims_of(a).keys()
	names.sort()
	if names.has("walk"):
		names.erase("walk")
		names.push_front("walk")
	return names


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		_touch(e)
		return
	if e is InputEventMouseButton and e.pressed and is_visible_in_tree() and _preview != null \
			and _preview.get_global_rect().has_point(e.position) and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		zoom_f = clampf(zoom_f * (1.15 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 1.0, 16.0)
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if not (e is InputEventKey) or not e.pressed or e.echo or not is_visible_in_tree():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return          # typing a note
	match e.keycode:
		KEY_LEFT:
			cycle_dir(-1)
		KEY_RIGHT:
			cycle_dir(1)
		KEY_UP:
			cycle_anim(-1)
		KEY_DOWN:
			cycle_anim(1)
		KEY_PAGEUP, KEY_Q:
			cycle_art(-1)
		KEY_PAGEDOWN, KEY_E:
			cycle_art(1)
		KEY_SPACE:
			set_paused(not paused)
		KEY_COMMA:
			step(-1)
		KEY_PERIOD:
			step(1)
		_:
			return
	get_viewport().set_input_as_handled()


func _fill_units() -> void:
	for c in _unit_box.get_children():
		c.queue_free()
	for f in _faction_btns:
		if f == _faction:
			UiStyle.chosen(_faction_btns[f], UiStyle.ACCENT.get(f, UiStyle.TRIM))
		else:
			_faction_btns[f].remove_theme_stylebox_override("normal")
	for a in _groups.get(_faction, []):
		if needs_only and not NEEDS_ART.has(a):
			continue
		var b := _btn(a + (" !" if NEEDS_ART.has(a) else ""), func() -> void: select_art(a), 38.0)
		if NEEDS_ART.has(a):
			b.tooltip_text = String(NEEDS_ART[a])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		_unit_box.add_child(b)


func select_art(a: String) -> void:
	art = a
	_faction = faction_of(a)
	_fill_units()
	for c in _anim_box.get_children():
		c.queue_free()
	var an := anims_of(a)
	var names := _anim_names(a)
	for nm in names:
		var b := _btn("%s  (%d)" % [nm, strip_frames(a, nm, an[nm][0])], func() -> void: select_anim(nm), 38.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		_anim_box.add_child(b)
	select_anim(names[0] if not names.is_empty() else "")


func select_anim(nm: String) -> void:
	anim = nm
	var an := anims_of(art)
	var have: Array = an.get(nm, [])
	if not _dir_ok(dir):
		dir = "e" if have.has("e") else (have[0] if not have.is_empty() else "e")
	frame = 0
	_t = 0.0
	_last_shown = -1
	for c in _dir_row.get_children():
		c.queue_free()
	for d in SHOW_DIRS:
		var b := _btn(d.to_upper() + (" *" if mirrored(art, nm, d) else ""), func() -> void: select_dir(d), 40.0)
		b.custom_minimum_size.x = 56
		b.disabled = strip_frames(art, nm, d) == 0
		_dir_row.add_child(b)
	_refresh()


func select_dir(d: String) -> void:
	dir = d
	_refresh()


func _dir_ok(d: String) -> bool:
	return strip_frames(art, anim, d) > 0


func frame_count() -> int:
	return strip_frames(art, anim, dir)


func set_paused(p: bool) -> void:
	paused = p
	_refresh()


func step(delta: int) -> void:
	var n := frame_count()
	if n == 0:
		return
	paused = true
	frame = posmod(frame + delta, n)
	_refresh()


## "unit / pose / direction / frame n of m" to the clipboard, to tell Claude later which animation bothers you.
func copy_name() -> void:
	var line := "%s / %s / %s / frame %d of %d" % [art, anim, dir, frame + 1, frame_count()]
	DisplayServer.clipboard_set(line)
	_copied_lbl.text = "Copied: " + line
	var stamp := Time.get_ticks_msec()
	_copied_lbl.set_meta("stamp", stamp)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if is_instance_valid(_copied_lbl) and int(_copied_lbl.get_meta("stamp", 0)) == stamp:
			_copied_lbl.text = "")


func flag_frame() -> void:
	flagged.append("%s / %s / %s / frame %d of %d%s" % [art, anim, dir, frame + 1, frame_count(),
			(" - " + _note.text.strip_edges()) if _note.text.strip_edges() != "" else ""])
	_note.text = ""
	_refresh()


func _refresh() -> void:
	if _info == null:
		return
	var n := frame_count()
	var fps := fps_for(art, anim, n)
	var pace := "at %.1f fps" % fps
	if on_beat(art, anim):
		var held: PackedStringArray = []
		for s in Unit.WINDER_BEAT[Unit.beat_of(anim)].slice(0, n):
			held.append("%.2f" % float(s))
		pace = "on the beat (held %s s)" % " ".join(held)
	elif timed_melee(art, anim):
		pace = "timed to the blow: aim %.2f s, the hit on frame %d, strike 0.35 s" % [float(Defs.BAYONET["aim"]), int(Unit.MELEE_HIT[art]) + 1]
	_info.text = "%s  /  %s  /  %s   ·   %d frames %s   ·   scale %.2f" % [art, anim, dir, n, pace, art_scale(art)]
	if NEEDS_ART.has(art):
		_info.text += "\nNEEDS ART: " + String(NEEDS_ART[art])
	if _needs_btn != null:
		_needs_btn.text = "ALL UNITS" if needs_only else "NEEDS ART ONLY (!)"
	_frame_lbl.text = "%d / %d" % [mini(frame + 1, maxi(n, 1)), n]
	_pause_btn.text = "PLAY" if paused else "PAUSE"
	_zoom_btn.text = "ZOOM %.1fx" % zoom_f
	_grid_btn.text = "ONE VIEW" if grid_mode else "ALL DIRECTIONS"
	_flag_lbl.text = "\n".join(flagged) if not flagged.is_empty() else "No frames flagged yet."
	_preview.queue_redraw()


func _process(delta: float) -> void:
	var n := frame_count()
	if n == 0 or paused:
		return
	if on_beat(art, anim):
		_t += delta                      # (seconds: the Winder's held frames, Unit.WINDER_BEAT, looped here)
		frame = Unit.beat_frame(anim, _t, n, true)
	elif timed_melee(art, anim):
		_t += delta                      # (seconds: the aim, the blow and the strike, as Unit._animate times them)
		frame = melee_frame_at(art, n, _t)
	else:
		_t += delta * fps_for(art, anim, n)
		frame = int(_t) % n
	if frame != _last_shown:
		_last_shown = frame
		_frame_lbl.text = "%d / %d" % [frame + 1, n]
		_preview.queue_redraw()


## Draws the current frame (or all directions) straight from the strip: a region of the texture.
class Preview extends Control:
	var viewer: AnimViewer

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.26, 0.17))
		if viewer == null or viewer.art == "":
			return
		if viewer.grid_mode:
			var cols := 4
			var cw := size.x / cols
			var ch := size.y / 2.0
			for i in AnimViewer.SHOW_DIRS.size():
				var d: String = AnimViewer.SHOW_DIRS[i]
				var r := Rect2(Vector2(i % cols * cw, i / cols * ch) + viewer.pan, Vector2(cw, ch))
				_cell(d, r, true)
				draw_rect(r, Color(1, 1, 1, 0.12), false)
		else:
			_cell(viewer.dir, Rect2(viewer.pan, size), false)

	func _cell(d: String, r: Rect2, label: bool) -> void:
		var n := AnimViewer.strip_frames(viewer.art, viewer.anim, d)
		if label:
			draw_string(ThemeDB.fallback_font, r.position + Vector2(6, 16), d.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))
		if n == 0:
			return
		var mir := AnimViewer.mirrored(viewer.art, viewer.anim, d)
		var src: String = AnimViewer.MIRROR.get(d, d) if mir else d
		var tex := Game.tex("res://assets/units/%s/%s_%s.png" % [viewer.art, viewer.anim, src]) as Texture2D
		if tex == null:
			return
		var fw := tex.get_width() / n
		var fh := tex.get_height()
		var sc := viewer.zoom_f * AnimViewer.art_scale(viewer.art)
		var dw := fw * sc
		var dh := fh * sc
		# feet (the anchor) near the bottom centre of the cell
		var anchor := Vector2(ArtData.UNITS[viewer.art]["anchor"])
		var cell := Vector2i(ArtData.UNITS[viewer.art]["cell"])
		var base := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.82)
		var x0 := base.x - anchor.x * sc
		if mir:
			x0 = base.x - (fw - anchor.x) * sc
		var y0 := base.y - (anchor.y + (fh - cell.y)) * sc
		var f := mini(viewer.frame, n - 1)
		var dst := Rect2(x0, y0, dw, dh)
		var srcr := Rect2(f * fw, 0, fw, fh)
		if mir:
			dst = Rect2(x0 + dw, y0, -dw, dh)
		draw_texture_rect_region(tex, dst, srcr)
