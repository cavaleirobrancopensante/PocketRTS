class_name Controls
extends Node
## Map input. Two schemes, picked on the first start (Settings.device):
## COMPUTER: left click selects (Shift adds or drops, Ctrl or double-click = all of that type on
##   screen, Ctrl+Shift drops that type (map_click); a worker label selects its workers), left drag = box, right click = command, wheel = zoom, middle drag or the
##   screen edges or arrow keys = pan, letter hotkeys for everything on the command card,
##   1-9 and 0 groups (Ctrl+number sets, Ctrl+Shift+number adds the selection, Shift+number adds the group to the selection), F1 idle workers, F2 army, F3 make, F4-F10 camera views (Shift+F saves), Space = jump to
##   the selection, Esc = cancel. Shift with a command (right click, MOVE, ATTACK, REPAIR,
##   placing buildings and walls) queues it after the units' current orders. Watching computers: 0 all vision, 1-4 follow that player.
##   Ctrl+A = ATTACK GROUND (as in Total Annihilation; Defs.BOMBARD, Defs.GROUND): the next click is a spot on the ground
##   every selected unit that can attack keeps attacking (a held left-drag: a line shared out among them, each its own
##   stretch, as the right-drag formation does).
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
var cast_spell := ""            # "cast" mode: storm, miasma, fog (a spot) or tongue (an enemy unit)
var line_from := Vector2i(-1, -1)  # laying a wall: where it starts
var ghost_cell := Vector2i(-1, -1)
var line_tool: LineTool = null     # "lay_line" mode: the Clockwork Line tool (scripts/line_tool.gd)

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
# Line move (as in Beyond All Reason): drag a line and the selected units spread out
# evenly along it. Computer: right-drag (or left-drag after MOVE / ATTACK); phone: drag
# after MOVE / ATTACK.
var line := PackedVector2Array()   # world points of the line being drawn
var line_attack := false
var line_ground := false           # the line is an ATTACK GROUND line (Ctrl+A, then a held left-drag): Game.ground_order
var _line_btn := ""                # which button/touch is drawing: "right", "left", "touch"
var _lmb_from := Vector2.ZERO
var _mouse_inside := true
var _exit_dir := Vector2.ZERO    # the edge the mouse left the window by (it keeps panning that way)
var _last_click_t := 0
var _last_click_kind := ""
# Shift-queued orders (computer only): MOVE / ATTACK / REPAIR and building placement stay
# open while Shift is held, and close when it's let go (as in StarCraft)
var _shift_kept := false


func to_world(screen: Vector2) -> Vector2:
	return game.get_viewport().get_canvas_transform().affine_inverse() * screen


func box_rect() -> Rect2:
	if _box_from == Vector2.INF:
		return Rect2()
	return Rect2(_box_from, Vector2.ZERO).expand(_box_to)


func _line_add(screen: Vector2) -> void:
	# (the mouse can be outside the window while the button is held: its position is far off the
	# screen, and the camera may be scrolling: the line follows the edge of the screen instead)
	screen = screen.clamp(Vector2.ZERO, game.get_viewport().get_visible_rect().size)
	var w := game.on_map(to_world(screen))
	if line.is_empty() or line[line.size() - 1].distance_to(w) > 6.0:
		line.append(w)


func _line_len() -> float:
	var l := 0.0
	for i in range(1, line.size()):
		l += line[i - 1].distance_to(line[i])
	return l


## Finish a line drag: true if it was long enough to be a line (units sent along it).
func _line_end(queued := false) -> bool:
	var ok := line.size() >= 2 and _line_len() > 40.0
	if ok and line_ground:
		game.ground_order(game.selected_units(), line, queued)
		Sfx.play_any(["ui/click", "click"])
	elif ok:
		game.line_move(game.selected_units(), line, line_attack, queued)
		Sfx.play_any(["ui/click", "click"])
	line = PackedVector2Array()
	_line_btn = ""
	line_ground = false
	return ok


## Shift held on a computer: the order goes after the ones the units already have.
static func _queued(shift: bool) -> bool:
	return shift and Settings.pc()


## A Shift-queued order was given in a mode: keep the mode open while Shift is held.
func _keep_for_shift() -> void:
	_shift_kept = true


func cancel_mode() -> void:
	_shift_kept = false
	if line_ground and _line_btn != "":
		line = PackedVector2Array()        # (an ATTACK GROUND line being dragged goes with the mode)
		_line_btn = ""
	line_ground = false
	if line_tool != null:
		line_tool.stop()
		line_tool = null
	mode = ""
	place_kind = ""
	line_from = Vector2i(-1, -1)
	ghost_cell = Vector2i(-1, -1)


## ATTACK GROUND (Ctrl+A or the card's button): the next click or tap is a spot on the ground, or a held drag a line. Only
## when a unit in the selection can attack the ground (Unit.can_ground_attack); false (and a note) if none can.
func begin_bombard() -> bool:
	if not game.selected_units().any(func(u: Unit) -> bool: return u.can_ground_attack()):
		game.notify("None of them can attack the ground.")
		return false
	cancel_mode()
	mode = "bombard"
	return true


func begin_line() -> void:
	cancel_mode()
	mode = "lay_line"
	line_tool = LineTool.new(self)
	game.notify("LINE: tap the start, then the end of the run.", true)


## THE BROOD: ROOT works like BUILD (scripts/brood_root.gd). mode "nb_root": the ghost of `kind`'s rooted footprint
## follows the pointer; PLACE (or a second tap on the same spot) sends a creature there. morph: a grub turns into it
## there (the grub card), else a selected creature that is up walks there and roots (its ROOT button).
var nb_morph := false
var nb_sc := 1.0                   # (the Mother's stage: her footprint's scale)


func begin_nb_root(kind: String, morph: bool) -> void:
	cancel_mode()
	mode = "nb_root"
	place_kind = kind
	nb_morph = morph
	var a := nb_actor()
	nb_sc = BroodRoot.scale_of(a) if a != null and not morph else 1.0
	var p := game.camera.get_screen_center_position()
	if a != null and not morph:
		p = a.position
	ghost_cell = BroodRoot.cell_for(kind, p, nb_sc)


## Who would go: the selected grub (morph) or creature of that kind that is up, nearest the ghost; null if none.
func nb_actor() -> Unit:
	var at := BroodRoot.feet_at(place_kind, ghost_cell, nb_sc) if ghost_cell.x >= 0 else game.camera.get_screen_center_position()
	var best: Unit = null
	for u in game.selected_units():
		if u.team != game.human or u.dead:
			continue
		var ok: bool = (u.kind == "grub" and u.order != "nb_morph") if nb_morph else (u.kind == place_kind and u.tesla_mode == "packed" and u.order != "nb_root")
		if ok and (best == null or u.position.distance_squared_to(at) < best.position.distance_squared_to(at)):
			best = u
	if best == null:
		# (Shift-queued: every one has a plan already: the nearest of them takes another)
		for u in game.selected_units():
			var ok2: bool = u.kind == "grub" if nb_morph else (u.kind == place_kind and u.tesla_mode == "packed")
			if ok2 and u.team == game.human and (best == null or u.position.distance_squared_to(at) < best.position.distance_squared_to(at)):
				best = u
	return best


func begin_place(kind: String) -> void:
	mode = "place"
	place_kind = kind
	line_from = Vector2i(-1, -1)
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var center := game.camera.get_screen_center_position()
	ghost_cell = game.cell_of(center) - size / 2


func _unhandled_input(event: InputEvent) -> void:
	game.input_cmd = true          # (the orders given here are the player's own: online, with the same delay for both, they wait)
	_on_input(event)
	game.input_cmd = false


## A drag ends when its button or finger is let go, wherever that happened. A release over the HUD or another
## Control is taken by the UI and never reaches _unhandled_input: the drag never ended and kept following the mouse
## (a right-drag line "running out of control", playtest 0.14.82). Touch: a finger lifted is seen here first and, if
## _unhandled_input didn't get it (_touches still has it once the event is through), ended by _touch_lost. The mouse
## buttons are checked every frame (_end_lost_drags).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed and _touches.has((event as InputEventScreenTouch).index):
		_touch_lost.call_deferred((event as InputEventScreenTouch).index)


func _touch_lost(index: int) -> void:
	if game == null or not _touches.has(index):
		return                      # (_unhandled_input had it: done as usual)
	var was_multi := _touches.size() >= 2
	_touches.erase(index)
	_press.erase(index)
	game.input_cmd = true
	if _line_btn == "touch" and not was_multi:
		if _line_end():
			cancel_mode()
	else:
		line = PackedVector2Array()
		_line_btn = ""
		if _box_from != Vector2.INF and not was_multi:
			_finish_box()
	_box_from = Vector2.INF
	game.input_cmd = false


## The mouse side of the above: a drag whose button is no longer held ends where the mouse is now (a line long
## enough is carried out; never a click on what lies under the UI).
func _end_lost_drags() -> void:
	if _mid_pan and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_mid_pan = false
	if not Settings.pc():
		return
	var mp := game.get_viewport().get_mouse_position()
	var shift := Input.is_key_pressed(KEY_SHIFT)
	game.input_cmd = true
	if _line_btn == "right" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_line_add(mp)
		_line_end(_queued(shift))
	elif _line_btn == "left" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_line_add(mp)
		if _line_end(shift) and not shift:
			cancel_mode()
	if _lmb_down and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_lmb_down = false
		if _box_from != Vector2.INF:
			_box_to = mp
			_finish_box(shift)
	game.input_cmd = false


func _on_input(event: InputEvent) -> void:
	if game.over and not game.map_view:
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
			_user_cam()
		elif Settings.pc():
			if _line_btn != "":
				_line_add(mm.position)
			if mode == "place" or mode == "nb_root":
				_move_ghost(mm.position)
			if mode == "lay_line" and line_tool != null:
				line_tool.hover(mm.position)
			if _lmb_down and _box_from == Vector2.INF and mm.position.distance_to(_lmb_from) > 6.0:
				_box_from = _lmb_from
			if _box_from != Vector2.INF:
				_box_to = mm.position
	elif event is InputEventKey and event.pressed and not event.is_echo():
		_key(event as InputEventKey)
	elif event is InputEventKey and event.pressed and event.is_echo() and Settings.pc() and hud \
			and not (event as InputEventKey).ctrl_pressed:
		# a train key held down repeats (as in StarCraft 2): one more in the queue each repeat
		hud.hotkey((event as InputEventKey).keycode, true)
	elif event is InputEventKey and not event.pressed and (event as InputEventKey).keycode == KEY_SHIFT:
		# Shift let go: a mode kept open for queueing closes (the next click would replace the queue)
		if _shift_kept and mode in ["move", "attack", "repair", "place", "bombard", "patrol", "nb_root"]:
			cancel_mode()
		_shift_kept = false


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
		line = PackedVector2Array()
		_line_btn = ""
		return
	if _line_btn == "touch":
		if _line_end():
			cancel_mode()
		else:
			_tap(e.position, info["mouse"])
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
		if c.distance_to(_pan_c) > 1.0:
			_user_cam()
		_pan_c = c
		return
	var info: Dictionary = _press.get(e.index, {})
	if info.is_empty():
		return
	if not info["moved"] and e.position.distance_to(info["pos"]) > DRAG_START:
		info["moved"] = true
		if mode == "move" or mode == "attack" or mode == "bombard":
			line = PackedVector2Array()
			line_attack = mode == "attack"
			line_ground = mode == "bombard"
			_line_btn = "touch"
			_line_add(info["pos"])
		elif mode == "place" or mode == "nb_root" or mode == "lay_line" or Settings.drag_mode == "pan":
			pass
		else:
			_box_from = info["pos"]
	if _line_btn == "touch":
		_line_add(e.position)
		return
	if Settings.drag_mode == "pan" and mode != "place" and mode != "nb_root" and info["moved"]:
		game.camera.position -= e.relative / game.camera.zoom
		_user_cam()
		return
	if (mode == "place" or mode == "nb_root") and info["moved"]:
		_move_ghost(e.position)
	if _box_from != Vector2.INF:
		_box_to = e.position


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside = false
		# left past an edge (to the browser's tabs, the taskbar...): keep scrolling that way
		# until the mouse comes back in
		_exit_dir = Vector2.ZERO
		if game and game.is_inside_tree():
			var mp := game.get_viewport().get_mouse_position()
			var vs := game.get_viewport().get_visible_rect().size
			const M := 60.0
			if mp.x < M: _exit_dir.x -= 1
			if mp.x > vs.x - M: _exit_dir.x += 1
			if mp.y < M: _exit_dir.y -= 1
			if mp.y > vs.y - M: _exit_dir.y += 1
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_inside = true
		_exit_dir = Vector2.ZERO


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
	elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed and mode == "" and Settings.pc() \
			and not game.selected_units().is_empty():
		line = PackedVector2Array()
		line_attack = false
		line_ground = false
		_line_btn = "right"
		_line_add(e.position)
	elif e.button_index == MOUSE_BUTTON_RIGHT and not e.pressed and _line_btn == "right":
		_line_add(e.position)
		if not _line_end(_queued(e.shift_pressed)):
			_right_click(e.position, _queued(e.shift_pressed))
	elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
		if mode != "":
			cancel_mode()
			return
		_right_click(e.position, _queued(e.shift_pressed))


func _right_click(screen: Vector2, queued := false) -> void:
	var p := to_world(screen)
	var rb := game.rally_buildings()
	if not rb.is_empty():
		for sb in rb:
			game.set_rally(sb, p)
	else:
		game.smart_command(game.selected_units(), p, false, queued)


## Computer: left button.
func _left_pc(e: InputEventMouseButton) -> void:
	if e.pressed and _line_btn == "right":
		# a left click in the middle of a right-button line drag calls the drag off: the line
		# must go too (it used to stay drawn and keep growing with the mouse)
		line = PackedVector2Array()
		_line_btn = ""
		return
	if e.pressed:
		match mode:
			"place":
				_move_ghost(e.position)
				var kind := place_kind
				if hud:
					hud.confirm_place(e.shift_pressed)   # Shift: queued on the builders
				if e.shift_pressed and kind != "" and mode == "":
					begin_place(kind)        # Shift keeps placing
					_move_ghost(e.position)
					_keep_for_shift()
				return
			"lay_line":
				if line_tool != null:
					line_tool.press(e.position, e.shift_pressed)
				return
			"nb_root":
				# (the Brood's ROOT ghost: Shift keeps placing, for the next grub or creature)
				_move_ghost(e.position)
				if hud:
					hud.confirm_nb_root(e.shift_pressed)
				if e.shift_pressed and mode == "nb_root":
					_keep_for_shift()
				return
			"nb_rally":
				_tap(e.position, false, e.shift_pressed)
				return
			"move", "attack", "bombard":
				# (ATTACK GROUND: a held drag is a line shared out among them; a short one is a click: _tap)
				line = PackedVector2Array()
				line_attack = mode == "attack"
				line_ground = mode == "bombard"
				_line_btn = "left"
				_line_add(e.position)
				return
			"rally", "rally_army", "rally_worker", "cast", "load", "unload", "overload", "repair", "patrol", "ride", "cwsiding", "cwsetup", "cwcast", "cwdrop":
				_tap(e.position, false, e.shift_pressed)
				return
		_lmb_down = true
		_lmb_from = e.position
		_box_from = Vector2.INF
		return
	if mode == "lay_line":
		if line_tool != null:
			line_tool.release(e.position, e.shift_pressed)
		return
	if _line_btn == "left":
		if _line_end(e.shift_pressed):
			if e.shift_pressed:
				_keep_for_shift()
			else:
				cancel_mode()
		else:
			_tap(e.position, false, e.shift_pressed)
		return
	if not _lmb_down:
		return
	_lmb_down = false
	if _box_from != Vector2.INF:
		_box_to = e.position
		_finish_box(e.shift_pressed)
		return
	var p := to_world(e.position)
	if not (e.ctrl_pressed or e.meta_pressed) and WorkerLabels.select_workers(game, WorkerLabels.at(game, p), e.shift_pressed):
		return          # a click on a worker label ("FARMERS 3/8"): its workers (Shift: added)
	var ent := game.entity_at(p)
	var now := Time.get_ticks_msec()
	if ent and ent.team == game.human:
		var double: bool = now - _last_click_t < 350 and _last_click_kind == ent.kind
		map_click(ent, e.ctrl_pressed or e.meta_pressed, e.shift_pressed, double)
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
	# watching computers: 0 all vision, 1-8 follow that player
	if game.spectating() and not e.ctrl_pressed and not e.shift_pressed and not e.meta_pressed \
			and e.keycode >= KEY_0 and e.keycode <= KEY_8 and game.spectator.hotkey(int(e.keycode - KEY_0)):
		return
	# the hotkey bar: 1-9 and 0 groups (Ctrl sets, Ctrl+Shift adds, Shift joins the group to the selection), F1 idle, F2 army,
	# F3 make, F4-F10 camera views (Shift+F saves)
	if Settings.pc() and hud and hud.bar.key(e):
		return
	if Settings.pc() and hud and not e.ctrl_pressed and hud.hotkey(e.keycode):
		return
	if Settings.pc() and hud and (e.ctrl_pressed or e.meta_pressed) and not e.shift_pressed and e.keycode != KEY_A and hud.ctrl_hotkey(e.keycode):
		return          # (Ctrl+a refit's or MORPH TO OWL's key: all that can, not one)
	if Settings.pc():
		match e.keycode:
			KEY_SPACE:
				var sel: Array = game.selection.filter(func(x: Entity) -> bool: return is_instance_valid(x) and not x.dead)
				if not sel.is_empty():
					var c := Vector2.ZERO
					for x in sel:
						c += x.global_position
					game.camera.position = c / sel.size()
					_user_cam()
				return
	if e.keycode == KEY_A and (e.ctrl_pressed or e.meta_pressed) and not e.shift_pressed:
		# Ctrl+A: ATTACK GROUND, a spot or a dragged line (A stays attack-move)
		if not units.is_empty() and begin_bombard() and hud:
			hud.flash_card("ATTACK GROUND")
		return
	match e.keycode:
		KEY_ESCAPE, KEY_BACKSPACE:
			if mode != "":
				cancel_mode()
			else:
				game.set_selection([])
		KEY_A:
			if units.any(func(u: Unit) -> bool: return not BroodRoot.fixed(u)):
				mode = "attack"      # (a rooted Brood creature is a building: no move, attack, stop or hold)
		KEY_M:
			if units.any(func(u: Unit) -> bool: return not BroodRoot.fixed(u)):
				mode = "move"
		KEY_P:
			if units.any(func(u: Unit) -> bool: return not BroodRoot.fixed(u)):
				mode = "patrol"
		KEY_S:
			game.command_all(units.filter(func(u: Unit) -> bool: return not BroodRoot.fixed(u)), "stop")
		KEY_H:
			game.command_all(units.filter(func(u: Unit) -> bool: return not BroodRoot.fixed(u)), "hold")
		KEY_QUOTELEFT:
			if Defs.gear_mode:
				game.toggle_gear_view()       # (THE GEAR VIEW: the whole gear network, scripts/gear.gd)
			else:
				game.line_net.overlay_on = not game.line_net.overlay_on
				game.line_net.redraw()
		KEY_B:
			if hud and units.any(func(u: Unit) -> bool: return u.is_worker()):
				hud.page = "build"


func _process(delta: float) -> void:
	if game == null or (game.over and not game.map_view):
		return
	_end_lost_drags()
	# Keyboard panning
	var k := Vector2.ZERO
	if not (hud and hud.chat_typing):          # (typing in the chat box: the arrow keys are not for panning)
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
	elif Settings.pc() and not _mouse_inside and DisplayServer.window_is_focused() and not _lmb_down and game.hud and not game.hud.paused:
		k += _exit_dir
	if k != Vector2.ZERO:
		game.camera.position += k.normalized() * 700.0 * delta / game.camera.zoom.x
		_user_cam()
		if _line_btn != "" and Settings.pc():
			_line_add(game.get_viewport().get_mouse_position())      # (a line drawn while the view scrolls follows it)
	# Long press = move without attacking (touch only)
	if _touches.size() == 1 and not _long_done and _box_from == Vector2.INF and mode == "":
		var idx: int = _touches.keys()[0]
		var info: Dictionary = _press.get(idx, {})
		if not info.is_empty() and not info["moved"] and not info["mouse"]:
			if (Time.get_ticks_msec() - int(info["t"])) / 1000.0 > LONG_PRESS:
				# a long press on a worker label ("FARMERS 3/8") explains it instead (WorkerLabels; the HUD's tooltip)
				var le := WorkerLabels.at(game, to_world(info["pos"]))
				if le != null and game.hud and game.hud.has_method("show_label_tip") \
						and game.hud.show_label_tip(le, (info["pos"] as Vector2) / float(game.hud.ui_scale)):
					_long_done = true
					return
				var units := game.selected_units()
				if not units.is_empty():
					_long_done = true
					game.input_cmd = true
					game.smart_command(units, to_world(info["pos"]), true)
					game.input_cmd = false
					Sfx.play_any(["ui/click", "click"])
	_clamp_camera()


## The player moved the view: a spectator following a computer lets go (free, same vision).
func _user_cam() -> void:
	if game.spectator:
		game.spectator.user_moved()


func _clamp_camera() -> void:
	var cam := game.camera
	var half := game.get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	var lo := Vector2(cam.limit_left, cam.limit_top) + half
	var hi := Vector2(cam.limit_right, cam.limit_bottom) - half
	cam.position = Vector2(clampf(cam.position.x, lo.x, maxf(lo.x, hi.x)), clampf(cam.position.y, lo.y, maxf(lo.y, hi.y)))


func _move_ghost(screen: Vector2) -> void:
	if mode == "nb_root":
		ghost_cell = BroodRoot.cell_centred(place_kind, to_world(screen), nb_sc)
		return
	var size: Vector2i = Defs.BUILDINGS[place_kind]["size"]
	var p := to_world(screen) - Vector2(size) * Defs.TILE * 0.5 + Vector2(Defs.TILE, Defs.TILE) * 0.5
	ghost_cell = game.cell_of(p)


## shift: a computer's Shift-click (MOVE, ATTACK, PATROL, REPAIR and ATTACK GROUND queue the order); taps never.
func _tap(screen: Vector2, is_mouse: bool, shift := false) -> void:
	var raw := to_world(screen)
	var p := game.on_map(raw)       # (the view may reach past the map edge: orders stay on it)
	var units := game.selected_units()
	if mode == "move" or mode == "attack" or mode == "patrol":
		units = units.filter(func(u: Unit) -> bool: return not BroodRoot.fixed(u))     # (rooted = a building: it stays)
	var queued := _queued(shift) and (mode == "move" or mode == "attack" or mode == "repair" or mode == "bombard" or mode == "patrol")
	match mode:
		"lay_line":
			if line_tool != null:
				line_tool.tap(screen)
			return
		"place":
			var before := ghost_cell
			_move_ghost(screen)
			if before == ghost_cell and hud:
				hud.confirm_place()
			return
		"nb_root":
			# (the Brood's ROOT ghost: a click places it; a tap moves it, a second tap on the same spot places it)
			var before2 := ghost_cell
			_move_ghost(screen)
			if (is_mouse and Settings.pc()) or before2 == ghost_cell:
				if hud:
					hud.confirm_nb_root(shift)
			return
		"nb_rally":
			# a rooted creature's (or an egg's) RALLY point
			for u in units:
				if BroodRoot.fixed(u):
					u.cmd_nb_rally(p)
			game._ping(p, Color(0.4, 1.0, 0.4))
			cancel_mode()
			return
		"move", "attack":
			if mode == "attack":
				var e := game.entity_at(p, false)
				if e and game.prey(game.human, e):
					for u in units:
						if u.kind != "horse":
							u.give({"o": "attack", "e": e}, queued)
				else:
					game.group_move(units, p, true, queued)
			else:
				game.group_move(units, p, false, queued)
			if queued:
				_keep_for_shift()
			else:
				cancel_mode()
			Sfx.play_any(["ui/click", "click"])
			return
		"patrol":
			# each patrols from where he stands to his own spot of the bunch at the point
			units = units.filter(func(u) -> bool: return u.kind != "horse")
			if units.is_empty():
				cancel_mode()
				return
			var ps := game.group_points(units, p, queued)
			for u in units:
				u.give({"o": "patrol", "p": ps[u]}, queued)
			if not units.is_empty() and units[0].team == game.human:
				game.command_sound(units, "attack", "patrol")
			game._ping(p, Color(1, 0.75, 0.3))
			if queued:
				_keep_for_shift()
			else:
				cancel_mode()
			Sfx.play_any(["ui/click", "click"])
			return
		"bombard":
			# the spot to attack (anywhere on the map, in the fog too); Shift: after their orders, and the mode stays on
			game.bombard_order(units, p, queued)
			if queued:
				_keep_for_shift()
			else:
				cancel_mode()
			Sfx.play_any(["ui/click", "click"])
			return
		"repair":
			var fixers := units.filter(func(u: Unit) -> bool: return u.d.get("repairs", false) or u.kind == "labourer")
			var target := game.repair_target_near(p, game.human)
			if target == null:
				game.notify("Nothing damaged there to repair.")
			else:
				for u in fixers:
					if u.can_repair(target):
						u.give({"o": "repair", "e": target}, queued)
				Sfx.play_any(["ui/click", "click"])
			if queued:
				_keep_for_shift()
			else:
				cancel_mode()
			return
		"cast":
			if cast_spell == "tongue":
				game.tongue_order(units, game.entity_at(p, false))     # (Mist Toad) tap the enemy
			else:
				game.cast_order(units, cast_spell, p)
			cancel_mode()
			Sfx.play_any(["ui/click", "click"])
			return
		"cwsiding", "cwsetup", "cwcast", "cwdrop":
			CwUnits.tap(self, game, mode, units, p)
			return
		"ride":
			var why := game.ride_order(units, p)
			if why != "":
				game.notify(why)
			else:
				game._ping(p, Color(0.5, 0.8, 1.0))
				Sfx.play_any(["ui/click", "click"])
			cancel_mode()
			return
		"load":
			# pick men to climb into the selected balloons (it stays on until they're full)
			var balloons := units.filter(func(u: Unit) -> bool: return Unit.carrier(u.kind))     # (or Spring Ballistas: Winders crew them)
			var e := game.entity_at(p, false)
			if e is Unit and e.team == game.human and balloons.any(func(b: Unit) -> bool: return (e as Unit).can_board(b)):
				game.load_order([e], balloons)
				Sfx.play_any(["ui/click", "click"])
				if balloons.all(func(b: Unit) -> bool: return b.room() <= 0):
					cancel_mode()
			else:
				if e is Unit and e.team == game.human:
					game.notify("Only Winders crew a Spring Ballista." if balloons.any(func(b: Unit) -> bool: return b.kind == Defs.BALLISTA_KIND) else "Only Musketeers and Labourers fit in the basket.")
				cancel_mode()
			return
		"unload":
			# tapping the balloon itself (or right under it) lets them off where it is
			var here := units.any(func(u: Unit) -> bool: return u.kind == "balloon" and u.position.distance_to(p) < 40.0)
			game.unload_order(units, p, here)
			cancel_mode()
			Sfx.play_any(["ui/click", "click"])
			return
		"overload":
			game.overload_order(units, game.entity_at(p, false))
			cancel_mode()
			Sfx.play_any(["ui/click", "click"])
			return
		"rally", "rally_army", "rally_worker":
			for sb in game.rally_buildings():
				game.set_rally(sb, p, {"rally": "auto", "rally_army": "army", "rally_worker": "worker"}[mode])
			cancel_mode()
			return
	var e := game.entity_at(raw)       # (a tap past the edge picks nothing)
	var own := e != null and e.team == game.human
	# Labourers tapping their own unfinished building: help build. (A finished one, a new
	# Town Hall too, is selected like anything else: a long press sends them to it.)
	if own and not units.is_empty() and e is Building and not e.built \
			and units.any(func(u: Unit) -> bool: return u.is_worker()) and not is_mouse:
		game.smart_command(units, p)
		return
	if own and WorkerLabels.at(game, raw) == e and WorkerLabels.select_workers(game, e):
		return          # a tap on a worker label: its workers
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
	var rb := game.rally_buildings()
	if not rb.is_empty():
		for sb in rb:
			game.set_rally(sb, p)
		return
	game.set_selection([e] if e else [])


## A left click on one of your own on the map, the SC2 way (the same rules as the selection panel's icons,
## Hud.sel_icon_click): plain = only it; Ctrl (or a double click) = every one of its kind on screen (Shift with a
## double click adds them); Shift = it in or out; Ctrl+Shift = its kind out of the selection, or, if none of its
## kind is selected, every one of its kind on screen added.
func map_click(ent: Entity, ctrl: bool, shift: bool, double := false) -> void:
	if ctrl and shift:
		var sel: Array = game.selection.filter(func(x: Entity) -> bool: return is_instance_valid(x) and not x.dead)
		var rest: Array = sel.filter(func(x: Entity) -> bool: return x.kind != ent.kind)
		if rest.size() < sel.size():
			game.set_selection(rest)
		else:
			_select_type_on_screen(ent.kind, true)
	elif ctrl or double:
		_select_type_on_screen(ent.kind, shift)
	elif shift:
		var sel: Array = game.selection.duplicate()
		if sel.has(ent):
			sel.erase(ent)
		else:
			sel.append(ent)
		game.set_selection(sel)
	else:
		game.set_selection([ent])


func _select_type_on_screen(kind: String, add := false) -> void:
	var view := Rect2(Vector2.ZERO, game.get_viewport().get_visible_rect().size)
	var xf := game.get_viewport().get_canvas_transform()
	var list: Array = []
	for u in game.units:
		if u.team == game.human and u.kind == kind and not u.dead and not u.off_field and view.has_point(xf * u.position):
			list.append(u)
	for b in game.buildings:
		if b.team == game.human and b.kind == kind and not b.dead and view.intersects(Rect2(xf * b.rect().position, b.rect().size * xf.get_scale())):
			list.append(b)
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
		if u.team == game.human and not u.dead and not u.off_field and r.has_point(xf * (u.position + Vector2(0, -10))):
			var rider := Unit.mounting_onto(u)      # (a horse a man is getting on: the strip drawn there is him)
			var who: Unit = u if rider == null else rider
			if who.team == game.human and not who.dead and not list.has(who):
				list.append(who)
	# no units in the box: your buildings in it (walls and gates only if that's all there is)
	if list.is_empty():
		var main: Array = []
		var lines: Array = []
		for bb in game.buildings:
			if bb.team != game.human or bb.dead:
				continue
			var br: Rect2 = bb.rect()
			if r.intersects(Rect2(xf * br.position, br.size * xf.get_scale())):
				(lines if Defs.BUILDINGS[bb.kind].get("line", false) else main).append(bb)
		list = main if not main.is_empty() else lines
	# Army in the box? Leave out the workers busy at the economy (farming, hauling, building);
	# ones out with the army (repairing, winding, idle) come along.
	if list.any(func(u: Unit) -> bool: return not u.is_worker()):
		list = list.filter(func(u: Unit) -> bool: return not u.is_worker() or u.work == "")
	# horses only when that's all there is (or with the men leading them: those come along anyway)
	if list.any(func(u) -> bool: return u is Unit and u.kind != "horse"):
		list = list.filter(func(u) -> bool: return not (u is Unit and u.kind == "horse"))
	if add:
		for x in game.selection:
			if is_instance_valid(x) and not list.has(x):
				list.append(x)
	if list.is_empty() and not add:
		# nothing of yours in the box (as in StarCraft 2): one enemy (or loose) unit in it,
		# the one nearest its middle, else one of their buildings, to look at, never to order
		var mid := r.get_center()
		var best: Entity = null
		var bd := INF
		for u in game.units:
			if u.team == game.human or u.dead or u.off_field or not u.visible:
				continue
			var sp: Vector2 = xf * (u.position + Vector2(0, -10))
			if r.has_point(sp) and sp.distance_to(mid) < bd:
				bd = sp.distance_to(mid)
				best = u
		if best == null:
			for bb in game.buildings:
				if bb.team == game.human or bb.dead or not bb.visible or game.hidden_ghost(bb, game.controlled_team()):
					continue
				var br2: Rect2 = bb.rect()
				if r.intersects(Rect2(xf * br2.position, br2.size * xf.get_scale())):
					best = bb
					break
		if best:
			list = [best]
	if not list.is_empty():
		game.set_selection(list)
		Sfx.play_any(["ui/click", "click"])
	elif Settings.pc() and not add:
		game.set_selection([])
