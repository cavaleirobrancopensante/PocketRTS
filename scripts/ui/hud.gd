extends Control
## On-screen interface: resource bar, minimap, group buttons, selection panel,
## command card, messages and the pause menu. Drawn by hand; it takes touches
## that land on its panels before the map sees them.

signal quit_requested

const CARD_BTN := 70.0           # mobile: 3 x 2 big buttons
const CARD_BTN_PC := 60.0        # computer: 4 x 3 with letter hotkeys
const MINI_W := 210.0

var game: Game
var controls: Controls
var page := ""                       # command card page: "", build
var build_page := 0
var paused := false
var _buttons: Array = []             # {rect, cb, enabled}
var _hud_touches := {}               # touch index -> what it pressed
var _msg := ""
var _msg_t := 0.0
var _hold_t := {}                    # group index -> press time
var _attack_alarm_t := 0.0
var _mouse_hud := false
var _card_items: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()


## The HUD is drawn at Settings.ui_scale (bigger on phones): it works in its own smaller
## coordinate space and is scaled up to fill the screen.
var ui_scale := 1.0


func _fit() -> void:
	ui_scale = Settings.ui_scale_now()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	scale = Vector2(ui_scale, ui_scale)
	size = get_viewport_rect().size / ui_scale


func _mouse() -> Vector2:
	return get_viewport().get_mouse_position() / ui_scale


## For callers working in screen pixels.
func hud_has_screen(p: Vector2) -> bool:
	return _hud_has(p / ui_scale)


func toast(t: String, sound := true) -> void:
	_msg = t
	_msg_t = 2.2
	if sound:
		Sfx.play_any(["ui/error", "error"])
	if game and not game.demo:
		var fac := game.faction_of(game.human)
		var res: Array = Defs.FACTIONS[fac]["res"]
		var low := t.to_lower()
		if low.begins_with("not enough " + String(res[0]).to_lower()):
			Sfx.announce(fac, "no_gold", 5.0)
		elif low.begins_with("not enough " + String(res[1]).to_lower()) or low.begins_with("out of powder"):
			Sfx.announce(fac, "no_res2", 5.0)
		elif low.begins_with("need more supply"):
			Sfx.announce(fac, "no_supply", 5.0)


func _process(delta: float) -> void:
	_msg_t = maxf(_msg_t - delta, 0.0)
	if not size.is_equal_approx(get_viewport_rect().size / ui_scale) or ui_scale != Settings.ui_scale_now():
		_fit()
	queue_redraw()


# ------------------------------------------------------------------ layout

func _vs() -> Vector2:
	return size


func top_rect() -> Rect2:
	return Rect2(0, 0, _vs().x, 36)


## Where everything sits comes from the chosen layout profile (Settings > Interface layout).
var _rects := {}
var _rects_frame := -1


func _layout() -> Dictionary:
	var f := Engine.get_process_frames()
	if f != _rects_frame:
		_rects_frame = f
		var b := _btn()
		_rects = UiLayout.rects(_vs(), {
			"mini": Vector2(MINI_W, MINI_W * float(Game.H) / float(Game.W)),
			"groups": Vector2(206, 90),
			"card": Vector2(b * _cols() + 4, b * _rows() + 4),
			"panel": Vector2(0, 88)})
	return _rects


func mini_rect() -> Rect2:
	return _layout()["mini"]


func _cols() -> int:
	return 4 if Settings.pc() else 3


func _rows() -> int:
	return 3 if Settings.pc() else 2


func _btn() -> float:
	return CARD_BTN_PC if Settings.pc() else CARD_BTN


func card_rect() -> Rect2:
	return _layout()["card"]


func drag_rect() -> Rect2:
	return Rect2(_vs().x - 96 - 128, 2, 122, 32)


func panel_rect() -> Rect2:
	return _layout()["panel"]


## Quick-select buttons above the minimap: ARMY, IDLE, HALL / groups 1-3.
func group_rect(i: int) -> Rect2:
	var g: Rect2 = _layout()["groups"]
	var row := 1 if i < 3 else 0      # ARMY / IDLE / HALL on the bottom row, groups above
	return Rect2(g.position.x + (i % 3) * 70, g.position.y + row * 48, 66, 42)


func menu_rect() -> Rect2:
	return Rect2(_vs().x - 96, 2, 90, 32)


func _hud_has(p: Vector2) -> bool:
	if game.over:
		return false        # the end screen takes the clicks
	if paused:
		return true
	for r in [top_rect(), mini_rect(), panel_rect(), card_rect(), drag_rect()]:
		if (r as Rect2).has_point(p):
			return true
	for i in 6:
		if group_rect(i).has_point(p):
			return true
	return false


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if game == null or game.over:
		return
	if ui_scale != 1.0 and (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouse):
		event = event.xformed_by(Transform2D().scaled(Vector2.ONE / ui_scale))
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if _hud_has(e.position):
				_hud_touches[e.index] = true
				_press(e.position)
				get_viewport().set_input_as_handled()
		elif _hud_touches.has(e.index):
			_hud_touches.erase(e.index)
			_release(e.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and Settings.pc():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _hud_has(mb.position):
				_mouse_hud = true
				_press(mb.position)
				get_viewport().set_input_as_handled()
			elif not mb.pressed and _mouse_hud:
				_mouse_hud = false
				_release(mb.position)
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and mini_rect().has_point(mb.position) and not paused:
			var m := mini_rect()
			var w := ((mb.position - m.position) / m.size).clamp(Vector2.ZERO, Vector2.ONE) * Vector2(Game.W, Game.H) * Game.T
			game.smart_command(game.selected_units(), w)
			get_viewport().set_input_as_handled()
		elif _hud_has(mb.position) and mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Settings.pc() and _mouse_hud:
		var mm := event as InputEventMouseMotion
		if mini_rect().has_point(mm.position) and not paused:
			_minimap_to(mm.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _hud_touches.has(e.index):
			if mini_rect().has_point(e.position) and not paused:
				_minimap_to(e.position)
			get_viewport().set_input_as_handled()


func _press(p: Vector2) -> void:
	if paused:
		for b in _pause_buttons():
			if (b["rect"] as Rect2).has_point(p):
				b["cb"].call()
		return
	if game.over:
		return
	if mini_rect().has_point(p):
		_minimap_to(p)
		return
	if not Settings.pc() and drag_rect().has_point(p):
		Settings.drag_mode = "pan" if Settings.drag_mode == "box" else "box"
		Settings.save_all()
		toast("One-finger drag now %s." % ("moves the view" if Settings.drag_mode == "pan" else "box-selects"))
		return
	for i in 6:
		if group_rect(i).has_point(p):
			_hold_t[i] = Time.get_ticks_msec()
			return
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(p):
			if b["enabled"]:
				b["cb"].call()
				Sfx.play_any(["ui/click", "click"])
			elif b.has("why"):
				toast(b["why"])
			return


func _release(p: Vector2) -> void:
	for i in _hold_t.keys():
		var held := (Time.get_ticks_msec() - int(_hold_t[i])) / 1000.0
		_hold_t.erase(i)
		if group_rect(i).has_point(p):
			_group_pressed(i, held)


func _minimap_to(p: Vector2) -> void:
	var m := mini_rect()
	var f := ((p - m.position) / m.size).clamp(Vector2.ZERO, Vector2.ONE)
	var w := f * Vector2(Game.W, Game.H) * Game.T
	if controls.mode in ["move", "attack"]:
		game.group_move(game.selected_units(), w, controls.mode == "attack")
		controls.cancel_mode()
		return
	game.camera.position = w


func _group_pressed(i: int, held: float) -> void:
	match i:
		0:   # whole army
			game.set_selection(game.army(game.human))
		1:   # idle labourers
			var idle := game.labourers(game.human).filter(func(u: Unit) -> bool: return u.order == "idle")
			if idle.is_empty():
				toast("No idle workers.")
			else:
				game.set_selection([idle[0]])
				game.camera.position = idle[0].position
		2:   # town hall
			var h := game._own_hall(game.human)
			if h:
				game.set_selection([h])
				game.camera.position = h.global_position
		_:
			var g := i - 3
			if held > 0.45 or game.groups[g].is_empty():
				if not game.selection.is_empty():
					game.groups[g] = game.selection.duplicate()
					toast("Group %d set." % (g + 1))
			else:
				var alive: Array = game.groups[g].filter(func(e: Entity) -> bool: return is_instance_valid(e) and not e.dead)
				game.groups[g] = alive
				game.set_selection(alive)
				if held < 0.3 and not alive.is_empty() and Time.get_ticks_msec() - _last_group_tap < 350 and _last_group == g:
					game.camera.position = alive[0].position
				_last_group = g
				_last_group_tap = Time.get_ticks_msec()


var _last_group := -1
var _last_group_tap := 0


# ------------------------------------------------------------------ command card

func _build_card() -> Array:
	var list: Array = []   # [icon, label, cb, enabled, why, cost]
	var units := game.selected_units()
	var b := game.selected_building()
	if controls.mode == "place":
		var k := controls.place_kind
		var why := game.placement_problem(game.human, k, controls.ghost_cell)
		list.append(["build", "PLACE", func() -> void: confirm_place(), why == "", why, ""])
		list.append(["stop", "CANCEL", func() -> void: controls.cancel_mode(), true, "", ""])
		return list
	if controls.mode != "":
		list.append(["stop", "CANCEL", func() -> void: controls.cancel_mode(), true, "", ""])
		return list
	if not units.is_empty():
		var has_lab := units.any(func(u: Unit) -> bool: return u.is_worker())
		if page in ["build", "advanced"] and has_lab:
			var all: Array = Defs.FACTIONS[game.faction_of(game.human)]["build"].filter(func(k: String) -> bool:
				return Defs.is_basic(k) == (page == "build"))
			var slots := _cols() * _rows()
			var per := slots - 1 if all.size() <= slots - 1 else slots - 2
			var pages := int(ceil(all.size() / float(per)))
			build_page = clampi(build_page, 0, pages - 1)
			for k in all.slice(build_page * per, build_page * per + per):
				var d: Dictionary = Defs.BUILDINGS[k]
				var why := ""
				if not game.requirement_met(game.human, k):
					why = "Needs a %s first." % Defs.BUILDINGS[d["requires"]]["name"]
				elif game.players[game.human]["gold"] < int(d["cost"]):
					why = "Not enough %s." % _res()[0].to_lower()
				elif Defs.is_econ(k) and game.econ_count(game.human, k) >= game.econ_limit(game.human, k):
					why = "Limit reached: expand with another %s." % Defs.BUILDINGS[game.faction_hall(game.human)]["name"]
				var kk: String = k
				var label: String = d["name"].to_upper()
				if Defs.is_econ(k):
					label = "%s %d/%d" % [label.split(" ")[0], game.econ_count(game.human, k), game.econ_limit(game.human, k)]
				list.append([k, label, func() -> void:
					page = ""
					controls.begin_place(kk), why == "", why, str(d["cost"])])
			if pages > 1:
				list.append(["build", "MORE", func() -> void: build_page = (build_page + 1) % pages, true, "", ""])
			list.append(["stop", "BACK", func() -> void:
				page = ""
				build_page = 0, true, "", ""])
			return list
		list.append(["move", "MOVE", func() -> void: controls.mode = "move", true, "", ""])
		list.append(["attack", "ATTACK", func() -> void: controls.mode = "attack", true, "", ""])
		list.append(["stop", "STOP", func() -> void: game.command_all(game.selected_units(), "stop"), true, "", ""])
		if has_lab:
			# workers don't need HOLD: two build pages instead, basic and advanced
			list.append(["build", "BUILD", func() -> void:
				page = "build"
				build_page = 0, true, "", ""])
			list.append(["repair", "ADVANCED", func() -> void:
				page = "advanced"
				build_page = 0, true, "", ""])
		else:
			list.append(["repair", "HOLD", func() -> void: game.command_all(game.selected_units(), "hold"), true, "", ""])
		if has_lab:
			if units.any(func(u: Unit) -> bool: return u.can_gather()):
				list.append(["gather", "WORK", func() -> void:
					for u in game.selected_units():
						if u.can_gather():
							var m := game.free_site(u.team, u.position)
							if m:
								u.cmd_gather(m)
							else:
								toast("Every post is taken: build more."), true, "", ""])
		if units.any(func(u: Unit) -> bool: return u.kind == "tesla_cart"):
			var packed := units.any(func(u: Unit) -> bool: return u.kind == "tesla_cart" and u.tesla_mode == "packed")
			list.insert(3, ["tesla_cart", "DEPLOY" if packed else "PACK", func() -> void:
				for u in game.selected_units():
					if u.kind == "tesla_cart":
						if packed:
							u.cmd_deploy()
						else:
							u.cmd_pack(), true, "", ""])
		return list
	if b and b.built and game.faction_of(game.human) == "clockwork" and b.kind in ["clocktower", "boiler", "ore_crusher"]:
		for name in Defs.SPLITS:
			var nm: String = name
			var on: bool = game.players[game.human]["split_name"] == nm
			list.append(["boiler", ("> " if on else "") + nm, func() -> void: game.set_split(game.human, nm), true, "", ""])
		if b.kind != "clocktower":
			return list
	if b and b.built:
		for k in b.d["trains"]:
			var kk: String = k
			var why := game.can_train(b, k)
			list.append([k, Defs.UNITS[k]["name"].to_upper(), func() -> void:
				var w := game.train(b, kk)
				if w != "":
					toast(w), why == "", why, str(Defs.UNITS[k]["cost"])])
		if b.dual_rally():
			list.append(["move", "RALLY", func() -> void: controls.mode = "rally_army", true, "", ""])
			list.append(["feeding_pit", "GRUBS", func() -> void: controls.mode = "rally_worker", true, "", ""])
		elif not b.d["trains"].is_empty():
			list.append(["move", "RALLY", func() -> void: controls.mode = "rally", true, "", ""])
		if not b.queue.is_empty():
			list.append(["stop", "CANCEL", func() -> void: game.cancel_train(b), true, "", ""])
	return list


## Letter hotkeys for the command card (computer). Common commands keep fixed letters,
## everything else takes the first free letter of its name.
const FIXED_KEYS := {"MOVE": "M", "ATTACK": "A", "STOP": "S", "HOLD": "H", "BUILD": "B", "ADVANCED": "V", "WORK": "G",
	"DEPLOY": "D", "PACK": "D", "RALLY": "R", "GRUBS": "Y", "CANCEL": "X", "BACK": "X", "MORE": "N", "PLACE": "P"}


## The id a card item is known by for hotkeys: a command name or a unit/building kind.
static func key_id(it: Array) -> String:
	var lab: String = String(it[1]).trim_prefix("> ")
	if FIXED_KEYS.has(lab):
		return lab
	if Defs.UNITS.has(it[0]) or Defs.BUILDINGS.has(it[0]):
		return it[0]
	return lab


func _with_keys(items: Array) -> Array:
	var used := {}
	var chosen := {}
	# the player's own keys and the fixed command keys first
	for i in items.size():
		var it: Array = items[i]
		var own := UiLayout.key_for(key_id(it))
		var lab: String = String(it[1]).trim_prefix("> ")
		var k: String = own if own != "" else String(FIXED_KEYS.get(lab, ""))
		if k != "" and not used.has(k):
			used[k] = true
			chosen[i] = k
	# everything else takes the first free letter of its name
	for i in items.size():
		var it: Array = items[i]
		var key: String = chosen.get(i, "")
		if key == "":
			var name: String = String(it[1]).trim_prefix("> ")
			if Defs.UNITS.has(it[0]):
				name = Defs.UNITS[it[0]]["name"].to_upper()
			elif Defs.BUILDINGS.has(it[0]):
				name = Defs.BUILDINGS[it[0]]["name"].to_upper()
			for ch in name:
				if ch >= "A" and ch <= "Z" and not used.has(ch):
					key = ch
					break
			if key == "":
				for ch in "QWERTYUIOPLKJFZCV":
					if not used.has(ch):
						key = ch
						break
			used[key] = true
		it.append(key)
	return items


## A key pressed on the keyboard: run the card button with that letter. True if used.
func hotkey(code: int) -> bool:
	if paused or game.over:
		return false
	if code == KEY_ESCAPE and controls.mode == "" and page != "":
		page = ""
		return true
	var letter := OS.get_keycode_string(code)
	if letter.length() != 1:
		return false
	for it in _card_items:
		if it.size() > 6 and it[6] == letter:
			if it[3]:
				it[2].call()
				Sfx.play_any(["ui/click", "click"])
			elif it[4] != "":
				toast(it[4])
			return true
	return false


func confirm_place() -> void:
	var k := controls.place_kind
	var why := game.placement_problem(game.human, k, controls.ghost_cell)
	if why != "":
		toast(why)
		return
	if game.players[game.human]["gold"] < int(Defs.BUILDINGS[k]["cost"]):
		toast("Not enough gold.")
		return
	var builders := game.selected_units().filter(func(u: Unit) -> bool: return u.is_worker())
	# One builder unless several are selected on purpose.
	if builders.size() > 3 or game.faction_of(game.human) == "brood":
		builders.sort_custom(func(a: Unit, c: Unit) -> bool:
			var g := Vector2(controls.ghost_cell) * Defs.TILE
			return a.position.distance_to(g) < c.position.distance_to(g))
		builders = builders.slice(0, 1)
	var b := game.place_building(game.human, k, controls.ghost_cell, builders)
	if b:
		Sfx.play_any(["ui/click", "click"])
	controls.cancel_mode()


# ------------------------------------------------------------------ pause

func _pause_buttons() -> Array:
	var vs := _vs()
	var list := [
		{"label": "RESUME", "cb": func() -> void: set_paused(false)},
		{"label": "MUSIC: " + ("ON" if Music.me.music_on else "OFF"), "cb": func() -> void: Music.me.toggle_music()},
		{"label": "SOUND: " + ("ON" if Music.me.sound_on else "OFF"), "cb": func() -> void: Music.me.toggle_sound()},
		{"label": "SURRENDER", "cb": func() -> void:
			set_paused(false)
			for b in game.buildings.duplicate():
				if b.team == game.human:
					b.take_damage(99999, null)},
		{"label": "QUIT TO MENU", "cb": func() -> void:
			set_paused(false)
			quit_requested.emit()},
	]
	for i in list.size():
		list[i]["rect"] = Rect2(vs.x * 0.5 - 160, vs.y * 0.5 - list.size() * 34 + 40 + i * 68, 320, 58)
	return list


func set_paused(v: bool) -> void:
	paused = v
	get_tree().paused = v


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if game == null:
		return
	var font := ThemeDB.fallback_font
	var vs := _vs()
	var pl: Dictionary = game.players[game.human]
	# Top bar: resource pills, supply, clock and the menu button.
	var fac := game.faction_of(game.human)
	var acc := UiStyle.accent(fac)
	var cols: Array = {"crown": [Color(0.98, 0.8, 0.2), Color(0.35, 0.33, 0.36)], "brood": [Color(0.55, 0.85, 0.3), Color(0.75, 0.45, 1.0)],
		"clockwork": [Color(0.7, 0.72, 0.78), Color(0.45, 0.75, 1.0)]}[fac]
	var res := _res()
	var x := 8.0
	x = _pill(font, x, cols[0], "%d" % pl["gold"], Color(1, 0.9, 0.55))
	var r2 := "%d" % int(pl["res2"])
	if fac == "clockwork":
		var sp: Array = pl["split"]
		r2 = "%d/s   ore %d · asm %d · wind %d" % [int(game.energy[game.human]), int(sp[0] * 100), int(sp[1] * 100), int(sp[2] * 100)]
	x = _pill(font, x, cols[1], r2, Color(0.85, 0.9, 1.0))
	var used := game.supply_used(game.human)
	var cap: int = pl["cap"]
	x = _pill(font, x, Color(0.75, 0.55, 0.3), "%d / %d" % [used, cap], UiStyle.BAD if used >= cap else UiStyle.TEXT, true)
	var secs := int(game.clock)
	var clock_r := Rect2(maxf(vs.x * 0.5 - 44, x), 4, 88, 30)
	UiStyle.draw_panel(self, clock_r, acc, 0.8)
	_text(UiStyle.title_font(), Vector2(clock_r.get_center().x, 26), "%d:%02d" % [secs / 60, secs % 60], 18, UiStyle.TEXT, 1)
	if not Settings.pc():
		var dr := drag_rect()
		UiStyle.draw_button(self, dr, false, Settings.drag_mode == "pan")
		_text(font, dr.get_center() + Vector2(0, 6), "DRAG: " + ("BOX" if Settings.drag_mode == "box" else "PAN"), 15, UiStyle.TEXT, 1)
	var mr := menu_rect()
	UiStyle.draw_button(self, mr, mr.has_point(_mouse()) and Settings.pc())
	_text(UiStyle.bold_font(), mr.get_center() + Vector2(0, 6), "MENU", 16, UiStyle.TEXT, 1)
	if game.demo:
		_text(font, Vector2(vs.x * 0.5, 60), "AI vs AI", 18, Color(1, 1, 1, 0.6), 1)
	_draw_minimap()
	_draw_groups(font)
	_draw_panel(font)
	_draw_card(font)
	# Selection box
	var br := controls.box_rect()
	br = Rect2(br.position / ui_scale, br.size / ui_scale)
	if br.size != Vector2.ZERO:
		draw_rect(br, Color(0.4, 1, 0.4, 0.12))
		draw_rect(br, Color(0.4, 1, 0.4, 0.8), false, 1.5)
	if controls.mode in ["move", "attack", "rally", "rally_army", "rally_worker"]:
		var t: String = {"move": "Tap where to move", "attack": "Tap a target or place to attack-move", "rally": "Tap the rally point",
			"rally_army": "Tap where new soldiers gather", "rally_worker": "Tap a Feeding Pit (or a spot) for new grubs"}[controls.mode]
		if Settings.pc():
			t = t.replace("Tap", "Click") + "  (right-click or Esc cancels)"
		_text(font, Vector2(vs.x * 0.5, 66), t, 20, Color(1, 1, 0.7), 1)
	elif controls.mode == "place":
		_text(font, Vector2(vs.x * 0.5, 66), "Click to build (Shift-click for more), right-click or Esc cancels" if Settings.pc() else "Drag to position, tap again or PLACE to build", 20, Color(1, 1, 0.7), 1)
	if _msg_t > 0.0:
		var a := minf(_msg_t, 1.0)
		var mw := font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 36
		var mrr := Rect2(vs.x * 0.5 - mw * 0.5, top_rect().end.y + 46, mw, 36)
		var sb := UiStyle.box(Color(0.1, 0.08, 0.06, 0.88 * a), Color(0.79, 0.64, 0.29, 0.6 * a), 2, 18, 0.0)
		sb.draw(get_canvas_item(), mrr)
		_text(UiStyle.bold_font(), Vector2(vs.x * 0.5, mrr.position.y + 25), _msg, 21, Color(1, 0.85, 0.65, a), 1)
	if paused:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
		var pbs := _pause_buttons()
		var top_y: float = (pbs[0]["rect"] as Rect2).position.y
		var last: Rect2 = pbs[pbs.size() - 1]["rect"]
		UiStyle.draw_panel(self, Rect2(vs.x * 0.5 - 200, top_y - 96, 400, last.end.y - top_y + 120), UiStyle.accent(game.faction_of(game.human)), 0.96)
		_text(UiStyle.title_font(), Vector2(vs.x * 0.5, top_y - 34), "PAUSED", 44, UiStyle.TRIM, 1)
		var hv := _mouse() if Settings.pc() else Vector2(-1, -1)
		for b in pbs:
			var r: Rect2 = b["rect"]
			UiStyle.draw_button(self, r, r.has_point(hv))
			_text(UiStyle.bold_font(), r.get_center() + Vector2(0, 8), b["label"], 22, UiStyle.BAD if b["label"] == "SURRENDER" else UiStyle.TEXT, 1)


func _draw_minimap() -> void:
	var m := mini_rect()
	UiStyle.draw_panel(self, m.grow(5), UiStyle.accent(game.faction_of(game.human)), 0.95)
	if _mini_tex == null:
		_mini_tex = ImageTexture.create_from_image(game.minimap_img)
	draw_texture_rect(_mini_tex, m, false)
	if game.swamp_tex:
		draw_texture_rect(game.swamp_tex, m, false)
	var k := m.size / (Vector2(Game.W, Game.H) * Game.T)
	if not game.demo:
		draw_texture_rect(game.fog_tex, m, false, Color(1, 1, 1, 0.95))
	for b in game.buildings:
		if b.visible or b.team == game.human:
			var r: Rect2 = b.rect()
			draw_rect(Rect2(m.position + r.position * k, r.size * k), game.team_colour(b.team).lightened(0.2))
	for u in game.units:
		if u.visible and not u.dead:
			draw_rect(Rect2(m.position + u.position * k - Vector2(1.5, 1.5), Vector2(3, 3)), game.team_colour(u.team).lightened(0.35))
	# Camera view
	var vp := get_viewport().get_visible_rect().size / game.camera.zoom
	var c := game.camera.get_screen_center_position()
	draw_rect(Rect2(m.position + (c - vp * 0.5) * k, vp * k), Color(1, 1, 1, 0.9), false, 1.0)
	# where you're being hit
	if game.alert_t > 0.0 and game.alert_at != Vector2.INF:
		var ap: Vector2 = m.position + game.alert_at * k
		var ph := fmod(game.alert_t * 2.0, 1.0)
		draw_arc(ap, 4.0 + ph * 14.0, 0, TAU, 20, Color(1, 0.25, 0.2, 1.0 - ph), 2.0)
		draw_circle(ap, 3.0, Color(1, 0.3, 0.2))


var _mini_tex: ImageTexture


func _draw_groups(font: Font) -> void:
	var labels := ["ARMY", "IDLE", "HALL", "1", "2", "3"]
	for i in 6:
		var r := group_rect(i)
		UiStyle.draw_button(self, r, Settings.pc() and r.has_point(_mouse()), _hold_t.has(i))
		var sub := ""
		match i:
			0:
				sub = str(game.army(game.human).size())
			1:
				sub = str(game.labourers(game.human).filter(func(u: Unit) -> bool: return u.order == "idle").size())
			_:
				if i >= 3:
					sub = str(game.groups[i - 3].filter(func(e: Entity) -> bool: return is_instance_valid(e) and not e.dead).size())
		_text(UiStyle.bold_font(), r.position + Vector2(r.size.x * 0.5, 18), labels[i], 14, UiStyle.TEXT, 1)
		if sub != "":
			_text(font, r.position + Vector2(r.size.x * 0.5, 36), sub, 13, Color(1, 1, 1, 0.6), 1)


func _draw_panel(font: Font) -> void:
	var r := panel_rect()
	if game.selection.is_empty():
		return
	UiStyle.draw_panel(self, r, UiStyle.accent(game.faction_of(game.human)))
	var sel: Array = game.selection.filter(func(e: Entity) -> bool: return is_instance_valid(e) and not e.dead)
	if sel.size() == 1:
		var e: Entity = sel[0]
		var icon := _icon(e.kind)
		var pr := Rect2(r.position + Vector2(10, 10), Vector2(68, 68))
		UiStyle.draw_button(self, pr.grow(2), false, false)
		if icon:
			draw_texture_rect(icon, pr, false)
		var name := ""
		var info := ""
		if e is Unit:
			name = (e as Unit).d["name"]
			info = (e as Unit).d["about"]
			var uu := e as Unit
			if uu.order == "gather" and uu.home_mine is Building:
				info = "Working at the %s." % (uu.home_mine as Building).d["name"]
			if uu.kind == "grub" and uu.carrying > 0:
				info = "Hauling food worth %d to the Hive." % uu.carrying
			elif uu.work == "feeding":
				info = "Feeding at the pit: takes half damage."
			elif uu.work == "bandaging":
				info = "Bandaging a soldier."
			elif uu.kind == "tesla_cart":
				info = {"packed": "Packed: rolls, can't fire. DEPLOY to fight.", "deploying": "Deploying...",
					"deployed": "Deployed: powers constructs nearby and zaps enemies.", "packing": "Packing up..."}[uu.tesla_mode]
			elif uu.kind == "missionary":
				info = "In danger near enemy buildings!" if not uu.untouchable() else "Can't be hurt here. Bandages wounded soldiers."
			elif (e as Unit).d["faction"] == "clockwork" and (e as Unit).wind < 0.99:
				info = "Winding down (%d%%): go back near a Spring Tower." % int((e as Unit).wind * 100)
		elif e is Building:
			name = (e as Building).d["name"]
			info = (e as Building).d["about"]
			var bb := e as Building
			if not bb.seeded:
				info = "Waiting for a %s." % ("Winder to start it" if bb.d["faction"] == "clockwork" else "grub to turn into it")
			elif not bb.built:
				info = "%s: %d%%" % ["Growing" if bb.d["faction"] == "brood" else "Under construction", int(bb.progress * 100)]
			elif bb.kind == "farm":
				info = "Harvest in %ds · %d/3 working · +%d gold" % [int(ceil((1.0 - bb.growth) * Defs.FARM_GROW / maxf(Defs.FARM_BASE + (1.0 - Defs.FARM_BASE) * mini(bb.working_crew(), 3) / 3.0, 0.01))), bb.working_crew(), Defs.FARM_YIELD]
			elif bb.kind == "powder_mill":
				info = "%d/2 grinding · +%.1f powder/s" % [bb.working_crew(), Defs.MILL_RATE * bb.working_crew()]
			elif bb.kind == "feeding_pit":
				info = "%d/5 grubs · each load is worth %d" % [bb.crew.size(), game.food_value(bb)]
			elif bb.kind == "boiler":
				info = "%d/3 Winders cranking · +%d energy/s" % [bb.working_crew(), int(Defs.ENERGY_PER_WINDER * bb.working_crew())]
			elif bb.kind == "ore_crusher" or (bb.kind == "clocktower" and e.team == game.human):
				info = "Energy %d/s → ore %.1f/s · assembly x%.1f" % [int(game.energy[e.team]), game.ore_rate[e.team], game.asm_mult[e.team]]
			elif bb.kind == "bone_midden":
				info = "Bodies falling within %d tiles give essence." % Defs.MIDDEN_RANGE
			elif bb.uses_eggs() and e.team == game.human:
				var nxt := "" if bb.eggs + bb.queue.size() >= Defs.EGGS_MAX else "  (next in %ds)" % int(ceil(Defs.EGG_TIME - bb.egg_t))
				info = "Eggs: %d / %d%s" % [bb.eggs, Defs.EGGS_MAX, nxt]
		elif e is GoldMine:
			info = "%d gold left." % (e as GoldMine).gold
		if e.team >= 0 and e.team != game.human:
			name += "  (enemy)"
		_text(UiStyle.title_font(), r.position + Vector2(90, 28), name, 19, UiStyle.TEXT)
		var hf := clampf(e.hp / maxf(e.max_hp, 1.0), 0.0, 1.0)
		var hb := Rect2(r.position + Vector2(90, 38), Vector2(170, 12))
		draw_rect(hb, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * hf, hb.size.y)), UiStyle.GOOD if hf > 0.5 else (Color(0.95, 0.75, 0.25) if hf > 0.25 else UiStyle.BAD))
		draw_rect(hb, UiStyle.TRIM_DIM, false, 1.0)
		_text(font, hb.position + Vector2(hb.size.x + 8, 11), "%d / %d" % [int(ceil(e.hp)), int(e.max_hp)], 15, Color(0.75, 1, 0.7))
		_text(font, r.position + Vector2(90, 72), info, 15, UiStyle.MUTED)
		if e is Building and e.team == game.human and not (e as Building).queue.is_empty():
			var q: Array = (e as Building).queue
			for i in q.size():
				var ic := _icon(q[i])
				var qr := Rect2(r.end.x - 44 - (q.size() - 1 - i) * 40, r.position.y + 8, 36, 36)
				if ic:
					draw_texture_rect(ic, qr, false)
				var eb := e as Building
				if i == 0 or eb.uses_eggs():
					var f: float = (eb.morph_t[i] if eb.uses_eggs() else eb.prod_t) / float(Defs.UNITS[q[i]]["time"])
					draw_rect(Rect2(qr.position.x, qr.end.y + 2, qr.size.x * f, 4), Color(0.4, 0.75, 1))
	else:
		var n := mini(sel.size(), 24)
		var per_row := int((r.size.x - 20) / 38)
		for i in n:
			var e: Entity = sel[i]
			var ir := Rect2(r.position + Vector2(10 + (i % per_row) * 38, 8 + (i / per_row) * 40), Vector2(34, 34))
			var ic := _icon(e.kind)
			if ic:
				draw_texture_rect(ic, ir, false)
			var f := e.hp / e.max_hp
			draw_rect(Rect2(ir.position.x, ir.end.y, ir.size.x * f, 3), Color(0.3, 0.9, 0.3) if f > 0.5 else Color(0.95, 0.4, 0.2))
		if sel.size() > n:
			_text(font, r.end - Vector2(40, 10), "+%d" % (sel.size() - n), 16, Color.WHITE)
	# Deselect button
	var x := Rect2(r.end.x - 30, r.position.y + 2, 28, 28)
	if sel.size() != 1 or not (sel[0] is Building and sel[0].team == game.human and not (sel[0] as Building).queue.is_empty()):
		UiStyle.draw_button(self, x, Settings.pc() and x.has_point(_mouse()))
		_text(UiStyle.bold_font(), x.get_center() + Vector2(0, 6), "✕", 16, UiStyle.TEXT, 1)
		_buttons_extra = [{"rect": x, "cb": func() -> void: game.set_selection([]), "enabled": true}]
	else:
		_buttons_extra = []


var _buttons_extra: Array = []


func _draw_card(font: Font) -> void:
	var items := _with_keys(_build_card())
	_card_items = items
	_buttons = _buttons_extra.duplicate()
	_buttons.append({"rect": menu_rect(), "cb": func() -> void: set_paused(true), "enabled": true})
	if items.is_empty():
		return
	var cr := card_rect()
	UiStyle.draw_panel(self, cr.grow(4), UiStyle.accent(game.faction_of(game.human)))
	var bsz := _btn()
	var hover := _mouse() if Settings.pc() else Vector2(-1, -1)
	for i in mini(items.size(), _cols() * _rows()):
		var it: Array = items[i]
		var br := Rect2(cr.position + Vector2(2 + (i % _cols()) * bsz, 2 + (i / _cols()) * bsz), Vector2(bsz - 4, bsz - 4))
		var enabled: bool = it[3]
		var ic := _icon(it[0])
		var hov := br.has_point(hover)
		var on := String(it[1]).begins_with("> ")
		UiStyle.draw_button(self, br, hov, on, enabled)
		if ic:
			draw_texture_rect(ic, br.grow(-3), false, Color.WHITE if enabled else Color(0.4, 0.4, 0.4, 0.8))
		draw_rect(Rect2(br.position.x + 2, br.end.y - 17, br.size.x - 4, 15), Color(0, 0, 0, 0.62))
		_text(UiStyle.bold_font(), Vector2(br.get_center().x, br.end.y - 5), String(it[1]).trim_prefix("> "), 11, (Color(1, 0.9, 0.55) if on else UiStyle.TEXT) if enabled else Color(1, 1, 1, 0.45), 1)
		if it[5] != "":
			var cw := font.get_string_size(it[5], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8
			var cbr := Rect2(br.end.x - cw - 2, br.position.y + 2, cw, 15)
			draw_rect(cbr, Color(0, 0, 0, 0.7))
			_text(UiStyle.bold_font(), Vector2(cbr.get_center().x, cbr.end.y - 3), it[5], 12, Color(1, 0.86, 0.4) if enabled else Color(1, 0.86, 0.4, 0.5), 1)
		if Settings.pc() and it.size() > 6 and it[6] != "":
			var kr := Rect2(br.position + Vector2(2, 2), Vector2(16, 16))
			draw_rect(kr, Color(0.1, 0.08, 0.05, 0.85))
			draw_rect(kr, UiStyle.TRIM_DIM, false, 1.0)
			_text(UiStyle.bold_font(), kr.position + Vector2(8, 13), it[6], 12, Color(1, 0.92, 0.6), 1)
		if hov:
			_tooltip(font, it, cr)
		_buttons.append({"rect": br, "cb": it[2], "enabled": enabled, "why": it[4]})


## A resource readout in the top bar; returns where the next one starts.
func _pill(font: Font, x: float, dot: Color, value: String, col: Color, box := false) -> float:
	var vw := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var w := 36.0 + vw + 14.0
	var r := Rect2(x, 4, w, 30)
	UiStyle.draw_panel(self, r, Color(0, 0, 0, 0), 0.8)
	if box:
		draw_rect(Rect2(x + 10, 11, 14, 16), dot)
		draw_rect(Rect2(x + 10, 11, 14, 16), Color(0, 0, 0, 0.5), false, 1.0)
	else:
		draw_circle(Vector2(x + 18, 19), 8, dot)
		draw_arc(Vector2(x + 18, 19), 8, 0, TAU, 18, Color(1, 1, 1, 0.45), 1.5)
	_text(font, Vector2(x + 34, 26), value, 20, col)
	return x + w + 8


func _res() -> Array:
	return Defs.FACTIONS[game.faction_of(game.human)]["res"]


func _tooltip(font: Font, it: Array, cr: Rect2) -> void:
	var title: String = String(it[1]).trim_prefix("> ")
	var body := ""
	var k: String = it[0]
	if Defs.UNITS.has(k) and title == Defs.UNITS[k]["name"].to_upper():
		var u: Dictionary = Defs.UNITS[k]
		title = u["name"]
		body = u["about"]
		var cost := "%d %s" % [u["cost"], _res()[0].to_lower()]
		if u.has("cost2"):
			cost += " + %d %s" % [u["cost2"], _res()[1].to_lower()]
		title += "   (%s, supply %d)" % [cost, int(u["supply"]) * int(u.get("spawn", 1))]
	elif Defs.BUILDINGS.has(k) and page in ["build", "advanced"]:
		var bd: Dictionary = Defs.BUILDINGS[k]
		title = "%s   (%d %s)" % [bd["name"], bd["cost"], _res()[0].to_lower()]
		body = bd["about"]
	if not it[3] and it[4] != "":
		body = it[4]
	if it.size() > 6 and it[6] != "":
		title = "[%s] %s" % [it[6], title]
	var w := maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, font.get_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 16
	w = minf(w, 520.0)
	var r := Rect2(cr.end.x - w, cr.position.y - 58, w, 48)
	UiStyle.draw_panel(self, r, Color(0, 0, 0, 0), 0.96)
	_text(UiStyle.bold_font(), r.position + Vector2(8, 19), title, 15, Color(1, 0.9, 0.6))
	_text(font, r.position + Vector2(8, 38), body, 14, UiStyle.TEXT)


func _icon(name: String) -> Texture2D:
	var path := "res://assets/icons/%s.png" % name
	if ResourceLoader.exists(path):
		return Game.tex(path)
	return null


func _text(font: Font, p: Vector2, s: String, sz: int, col: Color, align := 0) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var x := p.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	draw_string_outline(font, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, col.a * 0.8))
	draw_string(font, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
