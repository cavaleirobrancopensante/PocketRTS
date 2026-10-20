extends Control
## On-screen interface: resource bar, minimap, group buttons, selection panel,
## command card, messages and the pause menu. Drawn by hand; it takes touches
## that land on its panels before the map sees them.

signal quit_requested

const CARD_BTN := 70.0
const MINI_W := 210.0

var game: Game
var controls: Controls
var page := ""                       # command card page: "", build
var paused := false
var _buttons: Array = []             # {rect, cb, enabled}
var _hud_touches := {}               # touch index -> what it pressed
var _msg := ""
var _msg_t := 0.0
var _hold_t := {}                    # group index -> press time
var _attack_alarm_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func toast(t: String) -> void:
	_msg = t
	_msg_t = 2.2
	Sfx.play("error")


func _process(delta: float) -> void:
	_msg_t = maxf(_msg_t - delta, 0.0)
	queue_redraw()


# ------------------------------------------------------------------ layout

func _vs() -> Vector2:
	return size


func top_rect() -> Rect2:
	return Rect2(0, 0, _vs().x, 36)


func mini_rect() -> Rect2:
	var h := MINI_W * float(Game.H) / float(Game.W)
	return Rect2(8, _vs().y - h - 8, MINI_W, h)


func card_rect() -> Rect2:
	return Rect2(_vs().x - CARD_BTN * 3 - 12, _vs().y - CARD_BTN * 2 - 12, CARD_BTN * 3 + 4, CARD_BTN * 2 + 4)


func panel_rect() -> Rect2:
	var l := mini_rect().end.x + 8
	var r := card_rect().position.x - 8
	return Rect2(l, _vs().y - 96, r - l, 88)


## Quick-select buttons above the minimap: ARMY, IDLE, HALL / groups 1-3.
func group_rect(i: int) -> Rect2:
	var m := mini_rect()
	var row := 0 if i < 3 else 1
	return Rect2(m.position.x + (i % 3) * 70, m.position.y - 50 - row * 48, 66, 42)


func menu_rect() -> Rect2:
	return Rect2(_vs().x - 96, 2, 90, 32)


func _hud_has(p: Vector2) -> bool:
	if paused or game.over:
		return true
	for r in [top_rect(), mini_rect(), panel_rect(), card_rect()]:
		if (r as Rect2).has_point(p):
			return true
	for i in 6:
		if group_rect(i).has_point(p):
			return true
	return false


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if game == null:
		return
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
	for i in 6:
		if group_rect(i).has_point(p):
			_hold_t[i] = Time.get_ticks_msec()
			return
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(p):
			if b["enabled"]:
				b["cb"].call()
				Sfx.play("click")
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
		if page == "build" and has_lab:
			for k in Defs.FACTIONS[game.faction_of(game.human)]["build"]:
				var d: Dictionary = Defs.BUILDINGS[k]
				var why := ""
				if not game.requirement_met(game.human, k):
					why = "Needs a %s first." % Defs.BUILDINGS[d["requires"]]["name"]
				elif game.players[game.human]["gold"] < int(d["cost"]):
					why = "Not enough gold."
				var kk: String = k
				list.append([k, d["name"].to_upper(), func() -> void:
					page = ""
					controls.begin_place(kk), why == "", why, str(d["cost"])])
			list.append(["stop", "BACK", func() -> void: page = "", true, "", ""])
			return list
		list.append(["move", "MOVE", func() -> void: controls.mode = "move", true, "", ""])
		list.append(["attack", "ATTACK", func() -> void: controls.mode = "attack", true, "", ""])
		list.append(["stop", "STOP", func() -> void: game.command_all(game.selected_units(), "stop"), true, "", ""])
		list.append(["repair", "HOLD", func() -> void: game.command_all(game.selected_units(), "hold"), true, "", ""])
		if has_lab:
			list.append(["build", "BUILD", func() -> void: page = "build", true, "", ""])
			if units.any(func(u: Unit) -> bool: return u.can_gather()):
				list.append(["gather", "GATHER", func() -> void:
					for u in game.selected_units():
						if u.can_gather():
							var m := game.nearest_mine(u.position, u.team)
							if m:
								u.cmd_gather(m), true, "", ""])
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
			list.append(["gather", "GRUBS", func() -> void: controls.mode = "rally_worker", true, "", ""])
		elif not b.d["trains"].is_empty():
			list.append(["move", "RALLY", func() -> void: controls.mode = "rally", true, "", ""])
		if not b.queue.is_empty():
			list.append(["stop", "CANCEL", func() -> void: game.cancel_train(b), true, "", ""])
	return list


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
		Sfx.play("click")
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
		list[i]["rect"] = Rect2(vs.x * 0.5 - 160, vs.y * 0.24 + i * 76, 320, 62)
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
	# Top bar
	draw_rect(top_rect(), Color(0.05, 0.05, 0.06, 0.75))
	draw_circle(Vector2(20, 18), 8, Color(0.98, 0.8, 0.2))
	_text(font, Vector2(34, 25), "%d" % pl["gold"], 20, Color(1, 0.9, 0.5))
	var used := game.supply_used(game.human)
	var cap: int = pl["cap"]
	draw_rect(Rect2(124, 10, 14, 16), Color(0.75, 0.55, 0.3))
	_text(font, Vector2(144, 25), "%d / %d" % [used, cap], 20, Color(1, 0.5, 0.45) if used >= cap else Color.WHITE)
	var secs := int(game.clock)
	_text(font, Vector2(vs.x * 0.5, 25), "%d:%02d" % [secs / 60, secs % 60], 18, Color(1, 1, 1, 0.8), 1)
	var mr := menu_rect()
	draw_rect(mr, Color(0.2, 0.25, 0.22, 0.9))
	_text(font, mr.get_center() + Vector2(0, 6), "MENU", 16, Color.WHITE, 1)
	if game.demo:
		_text(font, Vector2(vs.x * 0.5, 60), "AI vs AI", 18, Color(1, 1, 1, 0.6), 1)
	_draw_minimap()
	_draw_groups(font)
	_draw_panel(font)
	_draw_card(font)
	# Selection box
	var br := controls.box_rect()
	if br.size != Vector2.ZERO:
		draw_rect(br, Color(0.4, 1, 0.4, 0.12))
		draw_rect(br, Color(0.4, 1, 0.4, 0.8), false, 1.5)
	if controls.mode in ["move", "attack", "rally", "rally_army", "rally_worker"]:
		var t: String = {"move": "Tap where to move", "attack": "Tap a target or place to attack-move", "rally": "Tap the rally point",
			"rally_army": "Tap where new soldiers gather", "rally_worker": "Tap a mine (or a spot) for new grubs"}[controls.mode]
		_text(font, Vector2(vs.x * 0.5, 66), t, 20, Color(1, 1, 0.7), 1)
	elif controls.mode == "place":
		_text(font, Vector2(vs.x * 0.5, 66), "Drag to position, tap again or PLACE to build", 20, Color(1, 1, 0.7), 1)
	if _msg_t > 0.0:
		_text(font, Vector2(vs.x * 0.5, card_rect().position.y - 14), _msg, 22, Color(1, 0.75, 0.6, minf(_msg_t, 1.0)), 1)
	if paused:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
		_text(font, Vector2(vs.x * 0.5, vs.y * 0.27), "PAUSED", 48, Color.WHITE, 1)
		for b in _pause_buttons():
			var r: Rect2 = b["rect"]
			draw_rect(r, Color(0.2, 0.45, 0.25, 0.95))
			_text(font, r.get_center() + Vector2(0, 8), b["label"], 24, Color.WHITE, 1)


func _draw_minimap() -> void:
	var m := mini_rect()
	draw_rect(m.grow(3), Color(0, 0, 0, 0.8))
	if _mini_tex == null:
		_mini_tex = ImageTexture.create_from_image(game.minimap_img)
	draw_texture_rect(_mini_tex, m, false)
	var k := m.size / (Vector2(Game.W, Game.H) * Game.T)
	if not game.demo:
		draw_texture_rect(game.fog_tex, m, false, Color(1, 1, 1, 0.95))
	for b in game.buildings:
		if b.visible or b.team == game.human:
			var r: Rect2 = b.rect()
			draw_rect(Rect2(m.position + r.position * k, r.size * k), Defs.TEAM_COLOURS[b.team].lightened(0.2))
	for u in game.units:
		if u.visible and not u.dead:
			draw_rect(Rect2(m.position + u.position * k - Vector2(1.5, 1.5), Vector2(3, 3)), Defs.TEAM_COLOURS[u.team].lightened(0.35))
	# Camera view
	var vp := get_viewport().get_visible_rect().size / game.camera.zoom
	var c := game.camera.get_screen_center_position()
	draw_rect(Rect2(m.position + (c - vp * 0.5) * k, vp * k), Color(1, 1, 1, 0.9), false, 1.0)


var _mini_tex: ImageTexture


func _draw_groups(font: Font) -> void:
	var labels := ["ARMY", "IDLE", "HALL", "1", "2", "3"]
	for i in 6:
		var r := group_rect(i)
		draw_rect(r, Color(0.12, 0.16, 0.14, 0.85))
		draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)
		var sub := ""
		match i:
			0:
				sub = str(game.army(game.human).size())
			1:
				sub = str(game.labourers(game.human).filter(func(u: Unit) -> bool: return u.order == "idle").size())
			_:
				if i >= 3:
					sub = str(game.groups[i - 3].filter(func(e: Entity) -> bool: return is_instance_valid(e) and not e.dead).size())
		_text(font, r.position + Vector2(r.size.x * 0.5, 18), labels[i], 14, Color.WHITE, 1)
		if sub != "":
			_text(font, r.position + Vector2(r.size.x * 0.5, 36), sub, 13, Color(1, 1, 1, 0.6), 1)


func _draw_panel(font: Font) -> void:
	var r := panel_rect()
	if game.selection.is_empty():
		return
	draw_rect(r, Color(0.06, 0.07, 0.07, 0.8))
	var sel: Array = game.selection.filter(func(e: Entity) -> bool: return is_instance_valid(e) and not e.dead)
	if sel.size() == 1:
		var e: Entity = sel[0]
		var icon := _icon(e.kind)
		if icon:
			draw_texture_rect(icon, Rect2(r.position + Vector2(10, 10), Vector2(68, 68)), false)
		var name := "Gold mine"
		var info := ""
		if e is Unit:
			name = (e as Unit).d["name"]
			info = (e as Unit).d["about"]
			if e.kind == "labourer" and (e as Unit).carrying > 0:
				info = "Carrying %d gold." % (e as Unit).carrying
			elif (e as Unit).work == "feeding":
				info = "Burrowed and feeding: takes half damage."
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
			elif bb.rig_mine and is_instance_valid(bb.rig_mine):
				info = "Drilling %d gold/s. %d left in the mine." % [int(Defs.RIG_RATE), bb.rig_mine.gold]
			elif bb.uses_eggs() and e.team == game.human:
				var nxt := "" if bb.eggs + bb.queue.size() >= Defs.EGGS_MAX else "  (next in %ds)" % int(ceil(Defs.EGG_TIME - bb.egg_t))
				info = "Eggs: %d / %d%s" % [bb.eggs, Defs.EGGS_MAX, nxt]
		elif e is GoldMine:
			info = "%d gold left." % (e as GoldMine).gold
		if e.team >= 0 and e.team != game.human:
			name += "  (enemy)"
		_text(font, r.position + Vector2(90, 28), name, 20, Color.WHITE)
		if not (e is GoldMine):
			_text(font, r.position + Vector2(90, 50), "%d / %d" % [int(ceil(e.hp)), int(e.max_hp)], 16, Color(0.6, 1, 0.6))
		_text(font, r.position + Vector2(90, 72), info, 14, Color(1, 1, 1, 0.65))
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
		draw_rect(x, Color(0.4, 0.15, 0.15, 0.9))
		_text(font, x.get_center() + Vector2(0, 6), "X", 16, Color.WHITE, 1)
		_buttons_extra = [{"rect": x, "cb": func() -> void: game.set_selection([]), "enabled": true}]
	else:
		_buttons_extra = []


var _buttons_extra: Array = []


func _draw_card(font: Font) -> void:
	var items := _build_card()
	_buttons = _buttons_extra.duplicate()
	_buttons.append({"rect": menu_rect(), "cb": func() -> void: set_paused(true), "enabled": true})
	if items.is_empty():
		return
	var cr := card_rect()
	draw_rect(cr, Color(0.06, 0.07, 0.07, 0.8))
	for i in mini(items.size(), 6):
		var it: Array = items[i]
		var br := Rect2(cr.position + Vector2(2 + (i % 3) * CARD_BTN, 2 + (i / 3) * CARD_BTN), Vector2(CARD_BTN - 4, CARD_BTN - 4))
		var enabled: bool = it[3]
		var ic := _icon(it[0])
		if ic:
			draw_texture_rect(ic, br, false, Color.WHITE if enabled else Color(0.45, 0.45, 0.45))
		else:
			draw_rect(br, Color(0.2, 0.25, 0.22))
		draw_rect(Rect2(br.position.x, br.end.y - 16, br.size.x, 16), Color(0, 0, 0, 0.6))
		_text(font, Vector2(br.get_center().x, br.end.y - 3), it[1], 11, Color.WHITE if enabled else Color(1, 1, 1, 0.5), 1)
		if it[5] != "":
			draw_rect(Rect2(br.end.x - 30, br.position.y, 30, 15), Color(0, 0, 0, 0.65))
			_text(font, Vector2(br.end.x - 15, br.position.y + 12), it[5], 11, Color(1, 0.88, 0.4), 1)
		_buttons.append({"rect": br, "cb": it[2], "enabled": enabled, "why": it[4]})


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
