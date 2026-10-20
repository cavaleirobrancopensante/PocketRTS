class_name Controls
extends Node
## Map input. Two schemes, picked on the first start (Settings.device):
## COMPUTER: left click selects (Shift adds, Ctrl or double-click = all of that type on
##   screen), left drag = box, right click = command, wheel = zoom, middle drag or the
##   screen edges or arrow keys = pan, letter hotkeys for everything on the command card,
##   1-9 groups (Ctrl+number saves), F1 idle worker, F2 army, F3 hall, Space = jump to
##   the selection, Esc = cancel.
## MOBILE:
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
var cast_spell := ""            # "cast" mode: storm or miasma
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
var _lmb_down := false
var _lmb_from := Vector2.ZERO
var _mouse_inside := true
var _last_click_t := 0
var _last_click_kind := ""


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
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _mid_pan:
			game.camera.position -= mm.relative / game.camera.zoom
		elif Settings.pc():
			if mode == "place":
				_move_ghost(mm.position)
			if _lmb_down and _box_from == Vector2.INF and mm.position.distance_to(_lmb_from) > 6.0:
				_box_from = _lmb_from
			if _box_from != Vector2.INF:
				_box_to = mm.position
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
		if mode == "place" or Settings.drag_mode == "pan":
			pass
		else:
			_box_from = info["pos"]
	if Settings.drag_mode == "pan" and mode != "place" and info["moved"]:
		game.camera.position -= e.relative / game.camera.zoom
		return
	if mode == "place" and info["moved"]:
		_move_ghost(e.position)
	if _box_from != Vector2.INF:
		_box_to = e.position


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_inside = true


func _mouse(e: InputEventMouseButton) -> void:
	if Settings.pc() and e.button_index == MOUSE_BUTTON_LEFT:
		_left_pc(e)
		return
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


## Computer: left button.
func _left_pc(e: InputEventMouseButton) -> void:
	if e.pressed:
		match mode:
			"place":
				_move_ghost(e.position)
				var kind := place_kind
				if hud:
					hud.confirm_place()
				if e.shift_pressed and kind != "":
					begin_place(kind)        # Shift keeps placing
					_move_ghost(e.position)
				return
			"move", "attack", "rally", "rally_army", "rally_worker", "cast":
				_tap(e.position, false)
				return
		_lmb_down = true
		_lmb_from = e.position
		_box_from = Vector2.INF
		return
	if not _lmb_down:
		return
	_lmb_down = false
	if _box_from != Vector2.INF:
		_box_to = e.position
		_finish_box(e.shift_pressed)
		return
	var p := to_world(e.position)
	var ent := game.entity_at(p)
	var now := Time.get_ticks_msec()
	if ent and ent.team == game.human:
		var double: bool = ent is Unit and now - _last_click_t < 350 and _last_click_kind == ent.kind
		if ent is Unit and (e.ctrl_pressed or double):
			_select_type_on_screen(ent.kind, e.shift_pressed)
		elif e.shift_pressed:
			var sel: Array = game.selection.duplicate()
			if sel.has(ent):
				sel.erase(ent)
			else:
				sel.append(ent)
			game.set_selection(sel)
		else:
			game.set_selection([ent])
		_last_click_t = now
		_last_click_kind = ent.kind
		Sfx.play_any(["ui/click", "click"])
	elif ent:
		if not e.shift_pressed:
			game.set_selection([ent])
	elif not e.shift_pressed:
		game.set_selection([])


func _zoom_at(screen: Vector2, f: float) -> void:
	var before := to_world(screen)
	var z := clampf(game.camera.zoom.x * f, 0.55, 2.6)
	game.camera.zoom = Vector2(z, z)
	game.camera.force_update_scroll()
	game.camera.position += before - to_world(screen)


func _key(e: InputEventKey) -> void:
	var units := game.selected_units()
	if Settings.pc() and hud and not e.ctrl_pressed and hud.hotkey(e.keycode):
		return
	if Settings.pc():
		match e.keycode:
			KEY_F1:
				hud._group_pressed(1, 0.0)
				return
			KEY_F2:
				hud._group_pressed(0, 0.0)
				return
			KEY_F3:
				hud._group_pressed(2, 0.0)
				return
			KEY_SPACE:
				var sel: Array = game.selection.filter(func(x: Entity) -> bool: return is_instance_valid(x) and not x.dead)
				if not sel.is_empty():
					var c := Vector2.ZERO
					for x in sel:
						c += x.global_position
					game.camera.position = c / sel.size()
				return
		if e.keycode >= KEY_1 and e.keycode <= KEY_9:
			var gi := int(e.keycode - KEY_1)
			if e.ctrl_pressed or e.meta_pressed:
				game.groups[gi] = game.selection.duplicate()
				hud.toast("Group %d set." % (gi + 1))
			elif e.shift_pressed:
				var add: Array = game.selection.duplicate()
				for x in game.groups[gi]:
					if is_instance_valid(x) and not x.dead and not add.has(x):
						add.append(x)
				game.set_selection(add)
			else:
				var alive: Array = game.groups[gi].filter(func(x: Entity) -> bool: return is_instance_valid(x) and not x.dead)
				if not alive.is_empty() and game.selection == alive and Time.get_ticks_msec() - _last_click_t < 400:
					game.camera.position = alive[0].global_position
				game.set_selection(alive)
				_last_click_t = Time.get_ticks_msec()
			return
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
			if hud and units.any(func(u: Unit) -> bool: return u.is_worker()):
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
	if Settings.pc() and _mouse_inside and DisplayServer.window_is_focused() and not _lmb_down and mode != "place_drag":
		var mp := game.get_viewport().get_mouse_position()
		var vs := game.get_viewport().get_visible_rect().size
		var edge := 6.0
		if mp.x >= 0 and mp.y >= 0 and mp.x <= vs.x and mp.y <= vs.y:
			if mp.x < edge: k.x -= 1
			if mp.x > vs.x - edge: k.x += 1
			if mp.y < edge: k.y -= 1
			if mp.y > vs.y - edge: k.y += 1
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
					Sfx.play_any(["ui/click", "click"])
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
				if e and game.hostile(e.team, game.human):
					for u in units:
						u.cmd_attack(e)
				else:
					game.group_move(units, p, true)
			else:
				game.group_move(units, p, false)
			cancel_mode()
			Sfx.play_any(["ui/click", "click"])
			return
		"cast":
			game.cast_order(units, cast_spell, p)
			cancel_mode()
			Sfx.play_any(["ui/click", "click"])
			return
		"rally", "rally_army", "rally_worker":
			var b := game.selected_building()
			if b:
				game.set_rally(b, p, {"rally": "auto", "rally_army": "army", "rally_worker": "worker"}[mode])
			cancel_mode()
			return
	var e := game.entity_at(p)
	var own := e != null and e.team == game.human
	# Labourers tapping their own unfinished building / hall: help build / drop gold.
	if own and not units.is_empty() and e is Building and (not e.built or e.kind == "town_hall") \
			and units.any(func(u: Unit) -> bool: return u.is_worker()) and not is_mouse:
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
		Sfx.play_any(["ui/click", "click"])
		return
	if is_mouse:
		# Desktop: left click on enemies/mines/ground just selects (or clears).
		game.set_selection([e] if e else [])
		return
	if not units.is_empty():
		game.smart_command(units, p)
		Sfx.play_any(["ui/click", "click"])
		return
	var b := game.selected_building()
	if b:
		game.set_rally(b, p)
		return
	game.set_selection([e] if e else [])


func _select_type_on_screen(kind: String, add := false) -> void:
	var view := Rect2(Vector2.ZERO, game.get_viewport().get_visible_rect().size)
	var xf := game.get_viewport().get_canvas_transform()
	var list: Array = []
	for u in game.units:
		if u.team == game.human and u.kind == kind and not u.dead and view.has_point(xf * u.position):
			list.append(u)
	if add:
		for x in game.selection:
			if not list.has(x):
				list.append(x)
	game.set_selection(list)


func _finish_box(add := false) -> void:
	var r := box_rect()
	_box_from = Vector2.INF
	var xf := game.get_viewport().get_canvas_transform()
	var list: Array = []
	for u in game.units:
		if u.team == game.human and not u.dead and r.has_point(xf * (u.position + Vector2(0, -10))):
			list.append(u)
	# Army in the box? Leave the labourers out.
	if list.any(func(u: Unit) -> bool: return not u.is_worker()):
		list = list.filter(func(u: Unit) -> bool: return not u.is_worker())
	if add:
		for x in game.selection:
			if is_instance_valid(x) and not list.has(x):
				list.append(x)
	if not list.is_empty():
		game.set_selection(list)
		Sfx.play_any(["ui/click", "click"])
	elif Settings.pc() and not add:
		game.set_selection([])
