class_name Controls
extends Node
## Map input for touch and mouse.
## Touch:  tap = select / command,  drag = box select,  long-press = move only,
##         two fingers = pan and pinch-zoom,  double-tap a unit = all of that type.
## Mouse:  left click = select (click ground to deselect), left drag = box,
##         right click = command, wheel = zoom, middle drag = pan.
## Keys:   arrows pan, A attack, M move, S stop, H hold, B build,
##         1-3 select group, Ctrl+1-3 set group, Esc cancel.

const DRAG_START := 14.0
const LONG_PRESS := 0.45

var game: Game
var hud: Control
var mode := ""                  # "", move, attack, place, rally
var place_kind := ""
var ghost_cell := Vector2i(-1, -1)

var _touches := {}              # index -> position
var _press := {}                # index -> {pos, t, moved, mouse}
var _box_from := Vector2.INF
var _box_to := Vector2.ZERO
var _pinch_d := 0.0
var _pinch_zoom := 1.0
var _pan_c := Vector2.ZERO
var _last_tap_t := 0
var _last_tap_kind := ""
var _long_done := false
var _mid_pan := false


func to_world(screen: Vector2) -> Vector2:
	return game.get_viewport().get_canvas_transform().affine_inverse() * screen


func box_rect() -> Rect2:
	if _box_from == Vector2.INF:
		return Rect2()
	return Rect2(_box_from, Vector2.ZERO).expand(_box_to)


func cancel_mode() -> void:
	mode = ""
	place_kind = ""
	ghost_cell = Vector2i(-1, -1)


func begin_place(kind: String) -> void:
	mode = "place"
	place_kind = kind
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var center := game.camera.get_screen_center_position()
	ghost_cell = game.cell_of(center) - size / 2


func _unhandled_input(event: InputEvent) -> void:
	if game.over:
		return
	if event is InputEventScreenTouch:
		_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_mouse(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _mid_pan:
		game.camera.position -= (event as InputEventMouseMotion).relative / game.camera.zoom
	elif event is InputEventKey and event.pressed and not event.is_echo():
		_key(event as InputEventKey)


func _touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
		_press[e.index] = {"pos": e.position, "t": Time.get_ticks_msec(), "moved": false, "mouse": e.device == InputEvent.DEVICE_ID_EMULATION}
		_long_done = false
		if _touches.size() == 2:
			_box_from = Vector2.INF
			var pts: Array = _touches.values()
			_pinch_d = (pts[0] as Vector2).distance_to(pts[1])
			_pinch_zoom = game.camera.zoom.x
			_pan_c = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
		return
	var info: Dictionary = _press.get(e.index, {})
	var was_multi := _touches.size() >= 2
	_touches.erase(e.index)
	_press.erase(e.index)
	if was_multi or info.is_empty():
		_box_from = Vector2.INF
		return
	if _box_from != Vector2.INF:
		_finish_box()
		return
	if _long_done:
		return
	if not info["moved"]:
		_tap(e.position, info["mouse"])


func _drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	_touches[e.index] = e.position
	if _touches.size() >= 2:
		var pts: Array = _touches.values()
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		var dd := a.distance_to(b)
		if _pinch_d > 10.0:
			var z := clampf(_pinch_zoom * dd / _pinch_d, 0.55, 2.6)
			game.camera.zoom = Vector2(z, z)
		var c := (a + b) * 0.5
		game.camera.position -= (c - _pan_c) / game.camera.zoom
		_pan_c = c
		return
	var info: Dictionary = _press.get(e.index, {})
	if info.is_empty():
		return
	if not info["moved"] and e.position.distance_to(info["pos"]) > DRAG_START:
		info["moved"] = true
		if mode == "place":
			pass
		else:
			_box_from = info["pos"]
	if mode == "place" and info["moved"]:
		_move_ghost(e.position)
	if _box_from != Vector2.INF:
		_box_to = e.position


func _mouse(e: InputEventMouseButton) -> void:
	if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
		_zoom_at(e.position, 1.12)
	elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
		_zoom_at(e.position, 1.0 / 1.12)
	elif e.button_index == MOUSE_BUTTON_MIDDLE:
		_mid_pan = e.pressed
	elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
		if mode != "":
			cancel_mode()
			return
		var p := to_world(e.position)
		var b := game.selected_building()
		if b:
			game.set_rally(b, p)
		else:
			game.smart_command(game.selected_units(), p)


func _zoom_at(screen: Vector2, f: float) -> void:
	var before := to_world(screen)
	var z := clampf(game.camera.zoom.x * f, 0.55, 2.6)
	game.camera.zoom = Vector2(z, z)
	game.camera.force_update_scroll()
	game.camera.position += before - to_world(screen)


func _key(e: InputEventKey) -> void:
	var units := game.selected_units()
	match e.keycode:
		KEY_ESCAPE:
			if mode != "":
				cancel_mode()
			else:
				game.set_selection([])
		KEY_A:
			if not units.is_empty():
				mode = "attack"
		KEY_M:
			if not units.is_empty():
				mode = "move"
		KEY_S:
			game.command_all(units, "stop")
		KEY_H:
			game.command_all(units, "hold")
		KEY_B:
			if hud and units.any(func(u: Unit) -> bool: return u.kind == "labourer"):
				hud.page = "build"
		KEY_1, KEY_2, KEY_3:
			var g := int(e.keycode - KEY_1)
			if e.ctrl_pressed or e.meta_pressed:
				game.groups[g] = game.selection.duplicate()
			else:
				game.set_selection(game.groups[g])


func _process(delta: float) -> void:
	if game == null or game.over:
		return
	# Keyboard panning
	var k := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT): k.x -= 1
	if Input.is_key_pressed(KEY_RIGHT): k.x += 1
	if Input.is_key_pressed(KEY_UP): k.y -= 1
	if Input.is_key_pressed(KEY_DOWN): k.y += 1
	if k != Vector2.ZERO:
		game.camera.position += k.normalized() * 700.0 * delta / game.camera.zoom.x
	# Long press = move without attacking (touch only)
	if _touches.size() == 1 and not _long_done and _box_from == Vector2.INF and mode == "":
		var idx: int = _touches.keys()[0]
		var info: Dictionary = _press.get(idx, {})
		if not info.is_empty() and not info["moved"] and not info["mouse"]:
			if (Time.get_ticks_msec() - int(info["t"])) / 1000.0 > LONG_PRESS:
				var units := game.selected_units()
				if not units.is_empty():
					_long_done = true
					game.smart_command(units, to_world(info["pos"]), true)
					Sfx.play("click")
	_clamp_camera()


func _clamp_camera() -> void:
	var cam := game.camera
	var half := game.get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	var lo := Vector2(cam.limit_left, cam.limit_top) + half
	var hi := Vector2(cam.limit_right, cam.limit_bottom) - half
	cam.position = Vector2(clampf(cam.position.x, lo.x, maxf(lo.x, hi.x)), clampf(cam.position.y, lo.y, maxf(lo.y, hi.y)))


func _move_ghost(screen: Vector2) -> void:
	var size: Vector2i = Defs.BUILDINGS[place_kind]["size"]
	var p := to_world(screen) - Vector2(size) * Defs.TILE * 0.5 + Vector2(Defs.TILE, Defs.TILE) * 0.5
	ghost_cell = game.cell_of(p)


func _tap(screen: Vector2, is_mouse: bool) -> void:
	var p := to_world(screen)
	var units := game.selected_units()
	match mode:
		"place":
			var before := ghost_cell
			_move_ghost(screen)
			if before == ghost_cell and hud:
				hud.confirm_place()
			return
		"move", "attack":
			if mode == "attack":
				var e := game.entity_at(p, false)
				if e and e.team >= 0 and e.team != game.human:
					for u in units:
						u.cmd_attack(e)
				else:
					game.group_move(units, p, true)
			else:
				game.group_move(units, p, false)
			cancel_mode()
			Sfx.play("click")
			return
		"rally":
			var b := game.selected_building()
			if b:
				game.set_rally(b, p)
			cancel_mode()
			return
	var e := game.entity_at(p)
	var own := e != null and e.team == game.human
	# Labourers tapping their own unfinished building / hall: help build / drop gold.
	if own and not units.is_empty() and e is Building and (not e.built or e.kind == "town_hall") \
			and units.any(func(u: Unit) -> bool: return u.kind == "labourer") and not is_mouse:
		game.smart_command(units, p)
		return
	if own:
		var now := Time.get_ticks_msec()
		if e is Unit and now - _last_tap_t < 350 and _last_tap_kind == e.kind:
			_select_type_on_screen(e.kind)
		else:
			game.set_selection([e])
		_last_tap_t = now
		_last_tap_kind = e.kind
		Sfx.play("click")
		return
	if is_mouse:
		# Desktop: left click on enemies/mines/ground just selects (or clears).
		game.set_selection([e] if e else [])
		return
	if not units.is_empty():
		game.smart_command(units, p)
		Sfx.play("click")
		return
	var b := game.selected_building()
	if b:
		game.set_rally(b, p)
		return
	game.set_selection([e] if e else [])


func _select_type_on_screen(kind: String) -> void:
	var view := Rect2(Vector2.ZERO, game.get_viewport().get_visible_rect().size)
	var xf := game.get_viewport().get_canvas_transform()
	var list: Array = []
	for u in game.units:
		if u.team == game.human and u.kind == kind and not u.dead and view.has_point(xf * u.position):
			list.append(u)
	game.set_selection(list)


func _finish_box() -> void:
	var r := box_rect()
	_box_from = Vector2.INF
	var xf := game.get_viewport().get_canvas_transform()
	var list: Array = []
	for u in game.units:
		if u.team == game.human and not u.dead and r.has_point(xf * (u.position + Vector2(0, -10))):
			list.append(u)
	# Army in the box? Leave the labourers out.
	if list.any(func(u: Unit) -> bool: return u.kind != "labourer"):
		list = list.filter(func(u: Unit) -> bool: return u.kind != "labourer")
	if not list.is_empty():
		game.set_selection(list)
		Sfx.play("click")
