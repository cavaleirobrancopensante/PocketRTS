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
		elif low.begins_with("not enough " + String(res[1]).to_lower()) or low.begins_with("out of powder") or low.begins_with("powder bank empty"):
			Sfx.announce(fac, "no_res2", 5.0)
		elif low.begins_with("need more supply"):
			Sfx.announce(fac, "no_supply", 5.0)


var _redraw_t := 0.0


## A match opens with a short countdown (3, 2, 1, GO): the world waits while you get ready.
var countdown := 0.0
var _count_shown := -1


func start_countdown(secs := 3.0) -> void:
	countdown = secs
	_count_shown = -1
	get_tree().paused = true


func _countdown(delta: float) -> void:
	if countdown <= 0.0 or paused:
		return
	get_tree().paused = true
	countdown -= delta
	var n := int(ceil(countdown))
	if n != _count_shown:
		_count_shown = n
		if n > 0:
			Sfx.play_any(["ui/click", "click"])
		else:
			Sfx.play_any(["ui/start_match", "ui/click"])
	if countdown <= 0.0:
		countdown = 0.0
		_go_t = 0.6
		get_tree().paused = false
	queue_redraw()


var _go_t := 0.0


func _draw_countdown() -> void:
	if countdown <= 0.0 and _go_t <= 0.0:
		return
	var vs := _vs()
	var c := vs * 0.5 - Vector2(0, 40)
	var font := UiStyle.bold_font()
	var txt := str(int(ceil(countdown))) if countdown > 0.0 else "GO!"
	var f: float = (countdown - floor(countdown)) if countdown > 0.0 else _go_t / 0.6
	var sz := int(96 + 40 * f)
	if countdown > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.25))
	var a := clampf(f * 1.6, 0.0, 1.0) if countdown > 0.0 else clampf(_go_t / 0.6, 0.0, 1.0)
	_text(font, c + Vector2(3, 3), txt, sz, Color(0, 0, 0, 0.6 * a), 1)
	_text(font, c, txt, sz, Color(1, 0.88, 0.45, a), 1)
	if countdown > 0.0:
		_text(font, c + Vector2(0, 60), "Get ready", 22, Color(1, 1, 1, 0.8), 1)


func _process(delta: float) -> void:
	_msg_t = maxf(_msg_t - delta, 0.0)
	_countdown(delta)
	if _go_t > 0.0:
		_go_t = maxf(_go_t - delta, 0.0)
		queue_redraw()
	if not _alt_press.is_empty() and not _alt_press["done"] and Time.get_ticks_msec() - int(_alt_press["t"]) > 450:
		_alt_press["done"] = true
		(_alt_press["b"]["alt"] as Callable).call()
		Sfx.play_any(["ui/click", "click"])
	# the HUD changes slowly: redraw 20 times a second (and at once after a touch or click)
	_redraw_t -= delta
	if game and game.spectator and game.spectator.fade > 0.0:
		_redraw_t = 0.0      # the cut's fade: every frame
	if _redraw_t > 0.0:
		return
	_redraw_t = 0.05
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


## Quick-select buttons above the minimap: ARMY, IDLE, HALL, MAKE on the bottom row,
## groups 1-4 above. Index: 0 ARMY, 1 IDLE, 2 HALL, 3-5 groups 1-3, 6 MAKE, 7 group 4.
const QUICK := 8


func group_rect(i: int) -> Rect2:
	var g: Rect2 = _layout()["groups"]
	var col := i % 3 if i < 6 else 3
	var row := 0 if (i >= 3 and i < 6) or i == 7 else 1
	return Rect2(g.position.x + col * 52, g.position.y + row * 48, 50, 42)


## The group number (0-based) a quick button stands for, or -1.
func _group_of(i: int) -> int:
	return i - 3 if i >= 3 and i < 6 else (3 if i == 7 else -1)


func menu_rect() -> Rect2:
	return Rect2(_vs().x - 96, 2, 90, 32)


func _hud_has(p: Vector2) -> bool:
	if game.over:
		return false        # the end screen takes the clicks
	if paused:
		return true
	if game.spectating() and (view_open or view_rect().has_point(p) or prod_rect().has_point(p)):
		return true         # (an open list takes the next press anywhere: it closes it)
	for r in [top_rect(), mini_rect(), panel_rect(), card_rect(), drag_rect()]:
		if (r as Rect2).has_point(p):
			return true
	for i in QUICK:
		if group_rect(i).has_point(p):
			return true
	return false


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if game == null or game.over:
		return
	_redraw_t = 0.0
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
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not paused:
				for b in _buttons:
					if (b["rect"] as Rect2).has_point(mb.position) and b.has("alt"):
						(b["alt"] as Callable).call()
						Sfx.play_any(["ui/click", "click"])
						break
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
	if game.spectating() and not view_open and prod_rect().has_point(p):
		prod_open = not prod_open
		Sfx.play_any(["ui/click", "click"])
		return
	if game.spectating() and (view_open or view_rect().has_point(p)):
		_view_press(p)
		return
	if mini_rect().has_point(p):
		_minimap_to(p)
		return
	if not Settings.pc() and drag_rect().has_point(p):
		Settings.drag_mode = "pan" if Settings.drag_mode == "box" else "box"
		Settings.save_all()
		toast("One-finger drag now %s." % ("moves the view" if Settings.drag_mode == "pan" else "box-selects"))
		return
	for i in QUICK:
		if group_rect(i).has_point(p):
			_hold_t[i] = Time.get_ticks_msec()
			return
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(p):
			if b.has("alt") and not Settings.pc():
				# phone: a tap trains, a long press switches automatic training (on release / in _process)
				_alt_press = {"b": b, "t": Time.get_ticks_msec(), "done": false}
				return
			if b["enabled"]:
				b["cb"].call()
				Sfx.play_any(["ui/click", "click"])
			elif b.has("why"):
				toast(b["why"])
			return


func _release(p: Vector2) -> void:
	if not _alt_press.is_empty():
		var b: Dictionary = _alt_press["b"]
		if not _alt_press["done"] and (b["rect"] as Rect2).has_point(p):
			if b["enabled"]:
				b["cb"].call()
				Sfx.play_any(["ui/click", "click"])
			elif b.has("why"):
				toast(b["why"])
		_alt_press = {}
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
	_jump(w)


## The camera jumps somewhere because you asked (minimap, a group, a hall...).
func _jump(p: Vector2) -> void:
	game.camera.position = p
	if game.spectator:
		game.spectator.user_moved()


# ------------------------------------------------------------------ spectator VIEW dropdown

var view_open := false
var prod_open := false


## Watching computers: the PRODUCTION button beside VIEW.
func prod_rect() -> Rect2:
	var v := view_rect()
	return Rect2(v.end.x + 8, v.position.y, 160, v.size.y)


## What each watched player is making: every unit and research in its queues (the one in
## progress with its bar), eggs morphing, and buildings going up.
func _draw_production(font: Font) -> void:
	var pr := prod_rect()
	UiStyle.draw_button(self, pr, pr.has_point(_mouse()) and Settings.pc(), prod_open)
	_text(UiStyle.bold_font(), pr.get_center() + Vector2(0, 6), "PRODUCTION" + ("  ▴" if prod_open else "  ▾"), 15, UiStyle.TEXT, 1)
	if not prod_open or view_open:
		return
	var teams: Array = []
	if game.view_team >= 0:
		teams = [game.view_team]
	else:
		for t in game.players.size():
			if not game.eliminated[t]:
				teams.append(t)
	const SZ := 34.0
	const PER := 9
	var w := PER * (SZ + 4) + 16
	var x0 := _vs().x - w - 8
	var y := pr.end.y + 8
	# work out the rows first, then draw the panel behind them
	var blocks: Array = []
	var h := 8.0
	for t in teams:
		var items: Array = []           # [icon, progress 0..1 or -1, colour]
		for b in game.buildings:
			if b.team != t or b.dead:
				continue
			if not b.built:
				items.append([b.kind, b.progress, Color(0.95, 0.75, 0.3)])
				continue
			var q: Array = b.queue
			for i in q.size():
				var res := Building.is_research(q[i])
				var f := -1.0
				if i == 0 or b.uses_eggs():
					f = (b.morph_t[i] if b.uses_eggs() and i < b.morph_t.size() else b.prod_t) / Building.entry_time(q[i])
				items.append([_research_icon(String(q[i]).substr(1)) if res else String(q[i]), f, Color(0.75, 0.55, 1.0) if res else Color(0.4, 0.75, 1.0)])
		var rows := maxi(1, int(ceil(items.size() / float(PER))))
		blocks.append([t, items])
		h += 22 + rows * (SZ + 10)
	UiStyle.draw_panel(self, Rect2(x0, y, w, h), UiStyle.accent(game.faction_of(maxi(game.view_team, 0))), 0.92)
	y += 8
	for bl in blocks:
		var t: int = bl[0]
		var items: Array = bl[1]
		draw_rect(Rect2(x0 + 10, y + 3, 10, 12), game.team_colour(t))
		_text(UiStyle.bold_font(), Vector2(x0 + 26, y + 14), "P%d %s" % [t + 1, Defs.FACTIONS[game.faction_of(t)]["name"]] + ("   (nothing in production)" if items.is_empty() else ""), 13, UiStyle.TEXT)
		y += 22
		for i in items.size():
			var it: Array = items[i]
			var r := Rect2(x0 + 10 + (i % PER) * (SZ + 4), y + (i / PER) * (SZ + 10), SZ, SZ)
			draw_rect(r, Color(0, 0, 0, 0.35))
			var ic := _icon(String(it[0]))
			if ic:
				draw_texture_rect(ic, r, false, Color.WHITE if float(it[1]) >= 0.0 else Color(1, 1, 1, 0.55))
			if float(it[1]) >= 0.0:
				draw_rect(Rect2(r.position.x, r.end.y + 2, SZ, 4), Color(0, 0, 0, 0.5))
				draw_rect(Rect2(r.position.x, r.end.y + 2, SZ * clampf(float(it[1]), 0.0, 1.0), 4), it[2])
		y += maxi(1, int(ceil(items.size() / float(PER)))) * (SZ + 10)


## Watching computers: the VIEW button under the clock; its list opens below it.
func view_rect() -> Rect2:
	return Rect2(_vs().x * 0.5 - 170, 40, 340, 34)


func _view_row(i: int) -> Rect2:
	var r := view_rect()
	# big rows, a little tighter when four players' worth must fit a short screen
	var n: int = 1 + 2 * game.n_players()
	var step := clampf((_vs().y - r.end.y - 14.0) / n, 34.0, 46.0)
	return Rect2(r.position.x, r.end.y + 6 + i * step, r.size.x, step - 4.0)


func _view_press(p: Vector2) -> void:
	if not view_open:
		view_open = true
		Sfx.play_any(["ui/click", "click"])
		return
	view_open = false
	var opts: Array = game.spectator.options()
	for i in opts.size():
		if _view_row(i).has_point(p) and opts[i][3]:
			game.spectator.set_mode(opts[i][1], opts[i][2])
			Sfx.play_any(["ui/click", "click"])
			return


func _draw_view(font: Font) -> void:
	var sp: Spectator = game.spectator
	var r := view_rect()
	var hv := _mouse() if Settings.pc() else Vector2(-1, -1)
	UiStyle.draw_button(self, r, r.has_point(hv), view_open)
	if sp.mode != "all":
		draw_rect(Rect2(r.position + Vector2(10, 10), Vector2(14, 14)), game.team_colour(sp.team))
	_text(UiStyle.bold_font(), r.get_center() + Vector2(6, 6), "VIEW: " + sp.label() + ("  ▴" if view_open else "  ▾"), 16, UiStyle.TEXT, 1)
	if not view_open:
		return
	var opts: Array = sp.options()
	var last := _view_row(opts.size() - 1)
	UiStyle.draw_panel(self, Rect2(r.position.x - 6, r.end.y + 1, r.size.x + 12, last.end.y - r.end.y + 6), UiStyle.accent(game.faction_of(game.human)), 0.96)
	for i in opts.size():
		var o: Array = opts[i]
		var rr := _view_row(i)
		var cur: bool = o[1] == sp.mode and (o[1] == "all" or int(o[2]) == sp.team)
		UiStyle.draw_button(self, rr, rr.has_point(hv) and o[3], cur, o[3])
		if o[1] != "all":
			draw_rect(Rect2(rr.position + Vector2(14, rr.size.y * 0.5 - 8), Vector2(16, 16)), game.team_colour(int(o[2])) if o[3] else Color(0.4, 0.4, 0.4))
		if cur:
			draw_circle(Vector2(rr.end.x - 20, rr.get_center().y), 6.0, Color(1, 0.85, 0.45))
		var key := ""
		if Settings.pc() and o[1] == "all":
			key = "[0] "
		elif Settings.pc() and o[1] == "follow" and int(o[2]) < 4:
			key = "[%d] " % (int(o[2]) + 1)
		_text(UiStyle.bold_font(), Vector2(rr.position.x + 42, rr.get_center().y + 7), key + String(o[0]) + ("  (out)" if not o[3] else ""), 19,
			(Color(1, 0.9, 0.55) if cur else UiStyle.TEXT) if o[3] else Color(1, 1, 1, 0.4))


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
				_jump(idle[0].position)
		2:   # town hall: each tap goes on to the next one (the main hall, then expansions)
			var halls: Array = game.halls_of(game.human, false)
			if halls.is_empty():
				var h := game._own_hall(game.human)
				if h:
					game.set_selection([h])
					_jump(h.global_position)
				return
			var cur: int = halls.find(game.selection[0]) if game.selection.size() == 1 else -1
			var nh: Building = halls[(cur + 1) % halls.size()]
			game.set_selection([nh])
			_jump(nh.center())
		6:   # every production building: train from all of them at once
			var pb := game.producers(game.human)
			if pb.is_empty():
				toast("No buildings that train an army yet.")
			else:
				game.set_selection(pb)
		_:
			var g := _group_of(i)
			if held > 0.45 or game.groups[g].is_empty():
				if not game.selection.is_empty():
					game.groups[g] = game.selection.duplicate()
					toast("Group %d set." % (g + 1))
			else:
				var alive: Array = game.groups[g].filter(func(e: Entity) -> bool: return is_instance_valid(e) and not e.dead)
				game.groups[g] = alive
				game.set_selection(alive)
				if held < 0.3 and not alive.is_empty() and Time.get_ticks_msec() - _last_group_tap < 350 and _last_group == g:
					_jump(alive[0].position)
				_last_group = g
				_last_group_tap = Time.get_ticks_msec()


var _last_group := -1
var _last_group_tap := 0


# ------------------------------------------------------------------ command card

var _demolish_ms := 0
var _alt_for := {}             # card label -> its right-click / long-press action (auto-train)
var _alt_press := {}           # the card button being held on a phone: {b, t, done}


func _build_card() -> Array:
	_alt_for = {}
	var list: Array = []   # [icon, label, cb, enabled, why, cost]
	var units := game.selected_units()
	var b := game.selected_building()
	if controls.mode == "place":
		var k := controls.place_kind
		var why := game.placement_problem(game.human, k, controls.ghost_cell)
		var lab := "PLACE"
		if Defs.BUILDINGS[k].get("line", false):
			lab = "START" if controls.line_from.x < 0 else "END"
			if controls.line_from.x >= 0:
				why = ""
		list.append(["build", lab, func() -> void: confirm_place(), why == "", why, ""])
		list.append(["stop", "CANCEL", func() -> void: controls.cancel_mode(), true, "", ""])
		return list
	if controls.mode != "":
		if controls.mode == "unload":
			# let them off right below the balloon, wherever it is
			list.append(["ab_unload", "DROP HERE", func() -> void:
				game.unload_order(game.selected_units(), Vector2.ZERO, true)
				controls.cancel_mode(), true, "", ""])
		list.append(["stop", "CANCEL", func() -> void: controls.cancel_mode(), true, "", ""])
		return list
	if not units.is_empty():
		var has_lab := units.any(func(u: Unit) -> bool: return u.is_worker())
		if page in ["build", "advanced"] and has_lab:
			# every building on one card (more pages if they don't fit)
			var all: Array = Defs.FACTIONS[game.faction_of(game.human)]["build"].duplicate()
			var slots := _cols() * _rows()
			var per := slots - 1 if all.size() <= slots - 1 else slots - 2
			var pages := int(ceil(all.size() / float(per)))
			build_page = clampi(build_page, 0, pages - 1)
			for k in all.slice(build_page * per, build_page * per + per):
				var d: Dictionary = Defs.BUILDINGS[k]
				var why := ""
				if not game.requirement_met(game.human, k):
					why = game.requirement_text(game.human, k)
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
			_balloon_buttons(list, units)     # labourers can ride too
			var fixers := units.filter(func(u: Unit) -> bool: return u.d.get("repairs", false) or u.kind == "labourer")
			if not fixers.is_empty():
				# a tap: pick what to repair; right-click / long press: automatic repair (glows)
				var auto_fix: bool = fixers.all(func(u: Unit) -> bool: return u.auto_repair)
				_alt_for["REPAIR"] = func() -> void:
					for u in game.selected_units():
						if u.d.get("repairs", false) or u.kind == "labourer":
							u.auto_repair = not auto_fix
					toast("Automatic repair on: idle workers fix damaged buildings nearby by themselves, before going back to work." if not auto_fix else "Automatic repair off.")
				list.append(["repair", ("~ " if auto_fix else "") + "REPAIR", func() -> void:
					controls.mode = "repair"
					toast("Tap a damaged building (or wall) to repair it."), true, "", ""])

		else:
			_ability_buttons(list, units)
			list.append(["repair", "HOLD", func() -> void: game.command_all(game.selected_units(), "hold"), true, "", ""])
		if has_lab:
			var gatherers := units.filter(func(u: Unit) -> bool: return u.can_gather())
			if not gatherers.is_empty():
				# WORK is automatic: idle workers go back to work on their own. Press it to
				# switch that off (to scout or to keep a builder free), and again to switch it on.
				var auto: bool = gatherers.all(func(u: Unit) -> bool: return u.auto_work)
				list.append(["gather", ("~ " if auto else "") + "WORK", func() -> void:
					for u in game.selected_units():
						if u.can_gather():
							u.auto_work = not auto
							if u.auto_work and u.order == "idle":
								var m := game.free_site(u.team, u.position)
								if m:
									u.cmd_gather(m)
					toast("Workers go back to work on their own." if not auto else "Automatic work off: these workers wait for orders."), true, "", ""])
			if units.any(func(u: Unit) -> bool: return u.kind == "grub"):
				list.append(["ab_harvest", "HARVEST", func() -> void:
					for u in game.selected_units():
						if u.kind == "grub":
							u.cmd_harvest()
					toast("Harvesting: these grubs gather the fallen around here and carry them home as essence."), true, "", ""])
		# Brood: offer the selected creatures up at the nearest Brood Pen for essence
		var offer := units.filter(func(u: Unit) -> bool: return u.can_sacrifice())
		if not offer.is_empty():
			var has_pen := game.nearest_of(offer[0].position, game.human, "brood_pen") != null
			var ess := 0
			for u in offer:
				ess += Game.sacrifice_value(u.kind)
			list.append(["ab_sacrifice", "SACRIFICE", func() -> void:
				var n := 0
				for u in game.selected_units():
					if u.can_sacrifice():
						u.cmd_sacrifice()
						n += 1
				toast("%d offered up: they go to the nearest Brood Pen (+%d essence)." % [n, ess]), has_pen, "Needs a Brood Pen.", "+%d" % ess])
		for dk in ["cannon", "mortar", "tesla_cart", "spore_mother"]:
			var kk: String = dk
			if units.any(func(u: Unit) -> bool: return u.kind == kk):
				var packed := units.any(func(u: Unit) -> bool: return u.kind == kk and u.tesla_mode == "packed")
				var lab: String = {"cannon": "UNLIMBER" if packed else "LIMBER", "spore_mother": "ROOT" if packed else "UPROOT"}.get(kk, "DEPLOY" if packed else "PACK")
				list.insert(3, [{"cannon": "ab_limber", "spore_mother": "ab_root"}.get(kk, "ab_deploy"), lab, func() -> void:
					for u in game.selected_units():
						if u.kind == kk:
							if packed:
								u.cmd_deploy()
							else:
								u.cmd_pack(), true, "", ""])
		return list
	if b == null:
		var pbs := game.selected_producers()
		if not pbs.is_empty():
			return _production_card(pbs)
	if b and not b.built:
		list.append(["stop", "ABANDON", func() -> void:
			for sb in game.selected_buildings():
				game.abandon(sb), true, "", ""])
		return list
	if b and b.built and b.kind == "gate":
		list.append(["ab_rotate", "ROTATE", func() -> void:
			var v := not b.vertical
			for sb in game.selected_buildings():
				sb.dir_locked = true
				sb.set_vertical(v)
			toast("Gate turned. It now stays this way."), true, "", ""])
	if b and b.built and b.kind != game.faction_hall(game.human):
		list.append(["stop", "DEMOLISH", func() -> void:
			if Time.get_ticks_msec() - _demolish_ms > 2500:
				_demolish_ms = Time.get_ticks_msec()
				toast("Press DEMOLISH again to pull it down.")
				return
			for sb in game.selected_buildings():
				game.demolish(sb), true, "", ""])
	if b and b.built:
		for rk in Defs.RESEARCH:
			var rkk: String = rk
			var info: Dictionary = Defs.RESEARCH[rk]
			# done, or already in a queue (it shows there, with its progress): no button
			if info["at"] != b.kind or game.has_tech(game.human, rk) or game.researching(game.human, rk):
				continue
			# a chain (the musket locks): only the next one shows, once the one before is
			# done or queued
			var rreq: String = info.get("requires", "")
			if rreq != "" and not game.has_tech(game.human, rreq) and not game.researching(game.human, rreq):
				continue
			var rwhy := game.research_problem(b, rk)
			var lab: String = info["name"].to_upper()
			list.append([_research_icon(rk), lab, func() -> void:
				var w := game.start_research(b, rkk)
				if w != "":
					toast(w), rwhy == "", rwhy, str(info["cost"])])
		for k in b.d["trains"]:
			var kk: String = k
			var why := game.can_train(b, k)
			for sb in game.selected_buildings():
				if game.can_train(sb, k) == "":
					why = ""
			var ulab: String = Defs.UNITS[k]["name"].to_upper()
			# right-click (computer) or a long press (phone): keep training it automatically
			_alt_for[ulab] = func() -> void:
				var on := b.auto_train != kk
				for sb in game.selected_buildings():
					sb.auto_train = kk if on else ""
				toast(("Training %s automatically." % Defs.UNITS[kk]["name"]) if on else "Automatic training off.")
			if b.auto_train == k:
				ulab = "~ " + ulab
			list.append([k, ulab, func() -> void:
				var w := game.train_any(game.selected_buildings(), kk)
				if w != "":
					toast(w), why == "", why, str(Defs.UNITS[k]["cost"])])
		if b.dual_rally():
			list.append(["move", "RALLY", func() -> void: controls.mode = "rally_army", true, "", ""])
			list.append(["feeding_pit", "GRUBS", func() -> void: controls.mode = "rally_worker", true, "", ""])
		elif not b.d["trains"].is_empty():
			list.append(["move", "RALLY", func() -> void: controls.mode = "rally", true, "", ""])
		if not b.queue.is_empty():
			list.append(["stop", "CANCEL", func() -> void:
				var last: String = b.queue.back() if not b.queue.is_empty() else ""
				game.cancel_train(b)
				if Building.is_research(last):
					toast("%s research cancelled: paid back." % Defs.RESEARCH[last.substr(1)]["name"]), true, "", ""])
	return list


## A research's icon (assets/icons/<icon>.png); without one, the unit it's for.
func _research_icon(key: String) -> String:
	var info: Dictionary = Defs.RESEARCH[key]
	var ric: String = info.get("icon", info.get("unlocks", "musketeer"))
	if _icon(ric) == null:
		ric = info.get("unlocks", "musketeer")
	return ric


## Observation Balloon: LOAD men into the basket (the infantry selected with it climb in
## at once; otherwise tap the men to take), UNLOAD them somewhere. The corner shows how
## many are aboard.
func _balloon_buttons(list: Array, units: Array) -> void:
	var balloons := units.filter(func(u: Unit) -> bool: return u.kind == "balloon")
	if balloons.is_empty():
		return
	var aboard := 0
	var cap := 0
	for b in balloons:
		aboard += b.passengers.size()
		cap += int(Defs.DROPSHIP["capacity"])
	var count := "%d/%d" % [aboard, cap]
	var room: bool = balloons.any(func(u: Unit) -> bool: return u.room() > 0)
	list.append(["ab_load", "LOAD", func() -> void:
		var sel := game.selected_units()
		var bs := sel.filter(func(u: Unit) -> bool: return u.kind == "balloon")
		var men := sel.filter(func(u: Unit) -> bool: return bs.any(func(b: Unit) -> bool: return u.can_board(b)))
		if not men.is_empty():
			game.load_order(men, bs)     # the men selected with it climb in
			toast("Climbing in: the balloon comes down and holds still until they're aboard.")
		else:
			controls.mode = "load"
			toast("Tap the Musketeers or Labourers to take aboard."), room, "The basket is full.", count])
	list.append(["ab_unload", "UNLOAD", func() -> void:
		controls.mode = "unload"
		toast("Tap where to let them off (or DROP HERE)."), aboard > 0, "Nobody aboard.", count])


## Crown abilities for the selected soldiers. Each button switches all of that kind.
func _ability_buttons(list: Array, units: Array) -> void:
	_balloon_buttons(list, units)
	# (Musketeers pick musket or bayonet by themselves: no button)
	# spells: pick the spot on the map; the nearest caster that can goes and does it
	var callers := units.filter(func(u: Unit) -> bool: return u.kind == "stormcaller")
	if not callers.is_empty():
		var ready: bool = callers.any(func(u: Unit) -> bool: return u.charge >= float(Defs.STORM["cost"]))
		list.append(["ab_storm", "STORM", func() -> void:
			controls.mode = "cast"
			controls.cast_spell = "storm", ready, "" if ready else "Not enough charge: recharge inside a Clockwork field.", ""])
	var mothers := units.filter(func(u: Unit) -> bool: return u.kind == "spore_mother")
	if not mothers.is_empty():
		var ok: bool = mothers.any(func(u: Unit) -> bool: return u.spell_cd <= 0.0)
		var why := "" if ok else "Miasma isn't ready yet."
		if float(game.players[game.human]["res2"]) < float(Defs.MIASMA["cost2"]):
			ok = false
			why = "Not enough essence."
		list.append(["ab_miasma", "MIASMA", func() -> void:
			controls.mode = "cast"
			controls.cast_spell = "miasma", ok, why, ""])
	# Mist Toad: FOG (a spot) and TONGUE (an enemy unit), both paid from its energy
	var toads := units.filter(func(u: Unit) -> bool: return u.kind == "mist_toad")
	if not toads.is_empty():
		var top := 0.0
		for u in toads:
			top = maxf(top, u.charge)
		var fog_ok := top >= float(Defs.FOG["cost"])
		list.append(["ab_fog", "FOG", func() -> void:
			controls.mode = "cast"
			controls.cast_spell = "fog", fog_ok, "" if fog_ok else "Not enough energy: FOG needs %d." % int(Defs.FOG["cost"]), str(int(Defs.FOG["cost"]))])
		var tongue_ok: bool = toads.any(func(u: Unit) -> bool: return u.charge >= float(Defs.TONGUE["cost"]) and u.tongue_stage == "")
		list.append(["ab_tongue", "TONGUE", func() -> void:
			controls.mode = "cast"
			controls.cast_spell = "tongue", tongue_ok, "" if tongue_ok else "Not enough energy: TONGUE needs %d." % int(Defs.TONGUE["cost"]), str(int(Defs.TONGUE["cost"]))])
	var sacs := units.filter(func(u: Unit) -> bool: return u.kind == "bloater")
	if not sacs.is_empty():
		var hold: bool = sacs.any(func(u: Unit) -> bool: return u.mode != "hold")
		list.append(["ab_hold_gas", "HOLD GAS" if hold else "SPIT", func() -> void:
			for u in game.selected_units():
				if u.kind == "bloater":
					u.set_hold_gas(hold), true, "", ""])
	# Ornithopter: COURIER (automatic) and OVERLOAD
	var topters := units.filter(func(u: Unit) -> bool: return u.kind == "ornithopter")
	if not topters.is_empty():
		var cour: bool = topters.all(func(u: Unit) -> bool: return u.courier)
		list.append(["ab_courier", ("~ " if cour else "") + "COURIER", func() -> void:
			for u in game.selected_units():
				if u.kind == "ornithopter":
					u.courier = not cour
					u._courier_t = 0.0
					if cour and u.order == "courier":
						u.cmd_stop()
			toast("Courier: idle Ornithopters fetch batteries and wind up constructs that ran down." if not cour else "Courier off."), true, "", ""])
		var has_bat: bool = topters.any(func(u: Unit) -> bool: return u.topter_bat != "")
		list.append(["ab_overload", "OVERLOAD", func() -> void: controls.mode = "overload", has_bat, "No battery: an Ornithopter on COURIER fetches one from an energy building.", ""])
	# Bulwark: BRACE plants the tower shield (it can't move; shots at the men behind hit it)
	var shields := units.filter(func(u: Unit) -> bool: return u.kind == "bulwark")
	if not shields.is_empty():
		var up: bool = shields.any(func(u: Unit) -> bool: return not u.braced)
		list.append(["ab_brace", "BRACE" if up else "~ BRACE", func() -> void:
			for u in game.selected_units():
				if u.kind == "bulwark":
					u.set_brace(up), true, "", ""])
	# Skywing: LAND (ground fighter) / TAKE OFF (hunts flyers)
	var wings := units.filter(func(u: Unit) -> bool: return u.kind == "skywing")
	if not wings.is_empty():
		var flying: bool = wings.any(func(u: Unit) -> bool: return u.sky == "air" or u.sky == "to_land")
		list.append(["ab_land", "LAND" if flying else "TAKE OFF", func() -> void:
			for u in game.selected_units():
				if u.kind == "skywing":
					if flying:
						u.cmd_land()
					else:
						u.cmd_take_off(), true, "", ""])
	var wagons := units.filter(func(u: Unit) -> bool: return u.kind == "powder_wagon")
	if not wagons.is_empty():
		var sup: bool = wagons.all(func(u: Unit) -> bool: return u.supplying)
		list.append(["ab_supply", ("~ " if sup else "") + "SUPPLY", func() -> void:
			for u in game.selected_units():
				if u.kind == "powder_wagon":
					u.set_supply(not sup)
			toast("Labourers bring kegs from the Powder Mill while the wagon has room." if not sup else "Supply off: no more keg runs."), true, "", ""])
	var guns := units.filter(func(u: Unit) -> bool: return u.kind == "cannon")
	if not guns.is_empty():
		var can: bool = guns.any(func(u: Unit) -> bool: return u.mode != "canister")
		list.append(["ab_canister" if can else "ab_round_shot", "CANISTER" if can else "ROUND SHOT", func() -> void:
			for u in game.selected_units():
				if u.kind == "cannon":
					u.set_canister(can), true, "", ""])


## Letter hotkeys for the command card (computer). Common commands keep fixed letters,
## everything else takes the first free letter of its name.
const FIXED_KEYS := {"MOVE": "V", "ATTACK": "A", "STOP": "S", "HOLD": "H", "BUILD": "B", "ADVANCED": "V", "WORK": "G",
	"DEPLOY": "D", "PACK": "D", "RALLY": "R", "REPAIR": "R", "ROTATE": "R", "GRUBS": "F", "CANCEL": "X", "BACK": "X", "ABANDON": "X", "DEMOLISH": "Z", "MORE": "T", "PLACE": "F",
	"CANISTER": "C", "ROUND SHOT": "C",
	"UNLIMBER": "D", "LIMBER": "D", "ROOT": "D", "UPROOT": "D", "STORM": "T", "MIASMA": "Q", "FOG": "F", "TONGUE": "T", "HOLD GAS": "F", "SPIT": "F", "HARVEST": "Q", "SACRIFICE": "C", "START": "F", "END": "F",
	"LOAD": "F", "UNLOAD": "G", "DROP HERE": "G", "COURIER": "C", "OVERLOAD": "V", "BRACE": "E", "LAND": "D", "TAKE OFF": "D", "SUPPLY": "G"}
## Keys the left hand reaches without leaving the group numbers: names only take letters
## from here (H for HOLD is the one fixed key outside it).
const NEAR_KEYS := "QWERTASDFGZXCVB"
## Command keys that never move: everything else gives way to them.
const MUST_KEYS := ["ATTACK", "STOP", "HOLD", "BUILD", "REPAIR", "CANCEL", "BACK", "ABANDON"]


## The id a card item is known by for hotkeys: a command name or a unit/building kind.
var prod_page := 0


## Several kinds of production building selected (MAKE): every unit any of them trains,
## each going to the least busy building that can train it. Long press / right-click
## switches automatic training on all of them that can.
func _production_card(pbs: Array) -> Array:
	var list: Array = []
	var kinds: Array = []
	for sb in pbs:
		for k in sb.d["trains"]:
			if not kinds.has(k) and not Defs.UNITS[k].get("worker", false):
				kinds.append(k)
	var slots := _cols() * _rows()
	var per := slots - 1 if kinds.size() <= slots - 1 else slots - 2     # room for RALLY (and MORE)
	var pages := maxi(1, int(ceil(kinds.size() / float(per))))
	prod_page = clampi(prod_page, 0, pages - 1)
	for k in kinds.slice(prod_page * per, prod_page * per + per):
		var kk: String = k
		var why := "Can't train that here."
		var able: Array = []
		for sb in pbs:
			if (sb.d["trains"] as Array).has(kk):
				able.append(sb)
				var w := game.can_train(sb, kk)
				if w == "":
					why = ""
				elif why != "":
					why = w
		var ulab: String = Defs.UNITS[kk]["name"].to_upper()
		var auto_all := able.all(func(x: Building) -> bool: return x.auto_train == kk)
		_alt_for[ulab] = func() -> void:
			for sb in able:
				if is_instance_valid(sb):
					sb.auto_train = "" if auto_all else kk
			toast(("Training %s automatically in every %s." % [Defs.UNITS[kk]["name"], "building that can"]) if not auto_all else "Automatic training off.")
		if able.any(func(x: Building) -> bool: return x.auto_train == kk):
			ulab = "~ " + ulab
		list.append([kk, ulab, func() -> void:
			var w := game.train_any(able, kk)
			if w != "":
				toast(w), why == "", why, str(Defs.UNITS[kk]["cost"])])
	if pages > 1:
		list.append(["build", "MORE", func() -> void: prod_page = (prod_page + 1) % pages, true, "", ""])
	list.append(["move", "RALLY", func() -> void: controls.mode = "rally", true, "", ""])
	return list


static func key_id(it: Array) -> String:
	var lab: String = String(it[1]).trim_prefix("> ").trim_prefix("~ ")
	if FIXED_KEYS.has(lab):
		return lab
	if Defs.UNITS.has(it[0]) or Defs.BUILDINGS.has(it[0]):
		return it[0]
	return lab


const GRID_KEYS := ["Q", "W", "E", "R", "A", "S", "D", "F", "Z", "X", "C", "V"]

func _with_keys(items: Array) -> Array:
	# computer, grid keys: the key is the button's place on the 4 x 3 card, under the left hand
	if Settings.pc() and Settings.grid_keys:
		for i in items.size():
			items[i].append(GRID_KEYS[i] if i < GRID_KEYS.size() else "")
		return items
	var used := {}
	var chosen := {}
	var lab_of := func(it: Array) -> String: return String(it[1]).trim_prefix("> ").trim_prefix("~ ")
	var named := func(it: Array) -> bool: return Defs.UNITS.has(it[0]) or Defs.BUILDINGS.has(it[0])
	# 1. the player's own keys and the must-have command keys (A attack, S stop, H hold, ...)
	for i in items.size():
		var own := UiLayout.key_for(key_id(items[i]))
		var lab: String = lab_of.call(items[i])
		var k: String = own if own != "" else (String(FIXED_KEYS[lab]) if MUST_KEYS.has(lab) else "")
		if k != "" and not used.has(k):
			used[k] = true
			chosen[i] = k
	# 2. units and buildings: a letter of their name; 3. the other commands' usual keys;
	# 4. whatever is left: a letter of its label
	for pass_i in 3:
		for i in items.size():
			if chosen.has(i):
				continue
			var it: Array = items[i]
			var key := ""
			if pass_i == 1:
				var fk: String = String(FIXED_KEYS.get(lab_of.call(it), ""))
				if fk != "" and not used.has(fk):
					key = fk
			elif (pass_i == 0) == bool(named.call(it)):
				var name: String = lab_of.call(it)
				if Defs.UNITS.has(it[0]):
					name = Defs.UNITS[it[0]]["name"].to_upper()
				elif Defs.BUILDINGS.has(it[0]):
					name = Defs.BUILDINGS[it[0]]["name"].to_upper()
				# the first letter of the name within reach, then the next ones
				for ch in name:
					if NEAR_KEYS.contains(ch) and not used.has(ch):
						key = ch
						break
				if key == "":
					for ch in NEAR_KEYS:
						if not used.has(ch):
							key = ch
							break
			if key != "":
				used[key] = true
				chosen[i] = key
	for i in items.size():
		items[i].append(chosen.get(i, ""))
	return items


## A key pressed on the keyboard: run the card button with that letter. True if used.
func hotkey(code: int) -> bool:
	if paused or game.over:
		return false
	if code == KEY_ESCAPE and view_open:
		view_open = false
		return true
	if (code == KEY_ESCAPE or code == KEY_BACKSPACE) and controls.mode == "" and page != "":
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
	if Defs.BUILDINGS.has(k) and Defs.BUILDINGS[k].get("line", false):
		_confirm_line(k)
		return
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


## Walls and gates go down in a line: the first PLACE marks the start, the second the end.
func _confirm_line(k: String) -> void:
	if controls.line_from.x < 0:
		var why := game.placement_problem(game.human, k, controls.ghost_cell)
		if why != "":
			toast(why)
			return
		controls.line_from = controls.ghost_cell
		toast("Now pick where it ends (the same spot for a single piece).")
		return
	var builders := game.selected_units().filter(func(u: Unit) -> bool: return u.is_worker())
	var n := game.place_line(game.human, k, controls.line_from, controls.ghost_cell, builders)
	if n > 0:
		Sfx.play_any(["ui/click", "click"])
	else:
		toast("Nothing could be placed there.")
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
			if game.mlog:
				game.mlog.add("%s surrendered" % game.mlog.who(game.human))
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

## One player's resources as top-bar pills; returns where the next pill goes.
func _res_pills(font: Font, t: int, x: float) -> float:
	var pl: Dictionary = game.players[t]
	var fac := game.faction_of(t)
	var cols: Array = {"crown": [Color(0.98, 0.8, 0.2), Color(0.35, 0.33, 0.36)], "brood": [Color(0.55, 0.85, 0.3), Color(0.75, 0.45, 1.0)],
		"clockwork": [Color(0.7, 0.72, 0.78), Color(0.45, 0.75, 1.0)]}[fac]
	x = _pill(font, x, cols[0], "%d" % pl["gold"], Color(1, 0.9, 0.55))
	var r2 := "%d" % int(pl["res2"])
	if fac == "clockwork":
		r2 = "%d energy (%s batteries stored)" % [int(game.energy[t]), "blue" if game.blue_energy(t) else "yellow"]
	x = _pill(font, x, cols[1], r2, Color(0.85, 0.9, 1.0))
	var used := game.supply_used(t)
	var cap: int = pl["cap"]
	return _pill(font, x, Color(0.75, 0.55, 0.3), "%d / %d" % [used, cap], UiStyle.BAD if used >= cap else UiStyle.TEXT, true)


## One player's resources in a short line (watching with all vision).
func _res_line(t: int) -> String:
	var pl: Dictionary = game.players[t]
	var fac := game.faction_of(t)
	var names: Array = {"crown": ["gold", "powder"], "brood": ["biomass", "essence"], "clockwork": ["ore", "energy"]}[fac]
	var r2: int = int(game.energy[t]) if fac == "clockwork" else int(pl["res2"])
	return "P%d %s   %d %s · %d %s · %d/%d supply" % [t + 1, String(Defs.FACTIONS[fac]["name"]), int(pl["gold"]), names[0], r2, names[1], game.supply_used(t), int(pl["cap"])]


func _draw() -> void:
	if game == null:
		return
	var font := ThemeDB.fallback_font
	var vs := _vs()
	if game.spectator and game.spectator.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, game.spectator.fade))     # the follow camera's cut
	# Top bar: resource pills, supply, clock and the menu button. Watching computers play:
	# the pills are the player whose eyes you're using; with all vision, a line per player.
	var shown := game.human
	if game.spectating():
		shown = game.view_team
	var fac := game.faction_of(maxi(shown, 0))
	var acc := UiStyle.accent(fac)
	var x := 8.0
	if shown >= 0:
		x = _res_pills(font, shown, x)
	else:
		var lines: Array = []
		for t in game.players.size():
			if not game.eliminated[t]:
				lines.append(t)
		var wmax := 0.0
		for t in lines:
			wmax = maxf(wmax, UiStyle.bold_font().get_string_size(_res_line(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
		UiStyle.draw_panel(self, Rect2(4, 4, wmax + 34, lines.size() * 20 + 10), acc, 0.85)
		for n in lines.size():
			var t: int = lines[n]
			draw_rect(Rect2(12, 11 + n * 20, 10, 12), game.team_colour(t))
			_text(UiStyle.bold_font(), Vector2(28, 22 + n * 20), _res_line(t), 13, UiStyle.TEXT)
		x = 8.0
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
	if game.demo and game.spectator == null:
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
	if controls.mode in ["move", "attack", "rally", "rally_army", "rally_worker", "cast"]:
		var t: String = {"move": "Tap where to move", "attack": "Tap a target or place to attack-move", "rally": "Tap the rally point",
			"cast": "Tap the enemy to lash with the tongue" if controls.cast_spell == "tongue" else "Tap where to cast the %s" % {"storm": "storm (it stuns your own units too)",
				"fog": "fog (shots from or into it miss half the time, yours too)"}.get(controls.cast_spell, "healing miasma"),
			"rally_army": "Tap where new soldiers gather", "rally_worker": "Tap a Feeding Pit (or a spot) for new grubs"}[controls.mode]
		if Settings.pc():
			t = t.replace("Tap", "Click") + "  (right-click or Esc cancels)"
		_text(font, Vector2(vs.x * 0.5, 66), t, 20, Color(1, 1, 0.7), 1)
	elif controls.mode == "place":
		var line_k: bool = Defs.BUILDINGS.has(controls.place_kind) and Defs.BUILDINGS[controls.place_kind].get("line", false)
		var hint: String = "Click to build (Shift-click for more), right-click or Esc cancels" if Settings.pc() else "Drag to position, tap again or PLACE to build"
		if line_k:
			hint = ("Click where the wall starts" if controls.line_from.x < 0 else "Click where it ends") if Settings.pc() else ("Drag to where the wall starts, then START" if controls.line_from.x < 0 else "Drag to where it ends, then END")
		_text(font, Vector2(vs.x * 0.5, 66), hint, 20, Color(1, 1, 0.7), 1)
	if _msg_t > 0.0:
		var a := minf(_msg_t, 1.0)
		var mw := font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 36
		var mrr := Rect2(vs.x * 0.5 - mw * 0.5, top_rect().end.y + 46, mw, 36)
		var sb := UiStyle.box(Color(0.1, 0.08, 0.06, 0.88 * a), Color(0.79, 0.64, 0.29, 0.6 * a), 2, 18, 0.0)
		sb.draw(get_canvas_item(), mrr)
		_text(UiStyle.bold_font(), Vector2(vs.x * 0.5, mrr.position.y + 25), _msg, 21, Color(1, 0.85, 0.65, a), 1)
	if game.spectating():
		_draw_view(font)
		_draw_production(font)
	if not paused:
		_draw_countdown()
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
	if not game.sees_all():
		draw_texture_rect(game.fog_tex, m, false, Color(1, 1, 1, 0.95))
	for b in game.buildings:
		if b.visible or (b.team == game.human and not game.demo):
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
	_draw_zoom(m)


var _mini_tex: ImageTexture
var _zoom_seen := 0.0
var _zoom_t := 0.0          # time since the zoom last changed (the gauge lights up for a moment)
const ZOOM_MIN := 0.55      # the camera's zoom limits (controls.gd)
const ZOOM_MAX := 2.6


## Zoom gauge in the minimap's bottom corner: a slim bar from widest view to closest,
## with the zoom as a factor. It brightens for a couple of seconds after the zoom changes.
func _draw_zoom(m: Rect2) -> void:
	var z: float = game.camera.zoom.x
	if absf(z - _zoom_seen) > 0.001:
		_zoom_seen = z
		_zoom_t = 0.0
	else:
		_zoom_t += get_process_delta_time()
	var a := 1.0 if _zoom_t < 1.5 else lerpf(1.0, 0.55, clampf((_zoom_t - 1.5) / 0.8, 0.0, 1.0))
	var box := Rect2(m.end - Vector2(96, 22), Vector2(92, 18))
	draw_rect(box, Color(0, 0, 0, 0.55 * a))
	var bar := Rect2(box.position + Vector2(40, 7), Vector2(46, 4))
	draw_rect(bar, Color(1, 1, 1, 0.25 * a))
	var f := clampf((z - ZOOM_MIN) / (ZOOM_MAX - ZOOM_MIN), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), Color(1, 0.86, 0.5, 0.9 * a))
	draw_rect(Rect2(bar.position + Vector2(bar.size.x * f - 1.5, -3), Vector2(3, bar.size.y + 6)), Color(1, 1, 1, a))
	_text(UiStyle.bold_font(), box.position + Vector2(5, 13), "x%.1f" % z, 12, Color(1, 1, 1, a))


func _draw_groups(font: Font) -> void:
	var labels := ["ARMY", "IDLE", "HALL", "1", "2", "3", "MAKE", "4"]
	for i in QUICK:
		var r := group_rect(i)
		UiStyle.draw_button(self, r, Settings.pc() and r.has_point(_mouse()), _hold_t.has(i))
		var sub := ""
		match i:
			0:
				sub = str(game.army(game.human).size())
			1:
				sub = str(game.labourers(game.human).filter(func(u: Unit) -> bool: return u.order == "idle").size())
			6:
				var busy := 0
				for pb in game.producers(game.human):
					busy += (pb as Building).queue.size()
				sub = str(busy) if busy > 0 else ""
			_:
				if _group_of(i) >= 0:
					sub = str(game.groups[_group_of(i)].filter(func(e: Entity) -> bool: return is_instance_valid(e) and not e.dead).size())
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
		if e is Unit and (e as Unit).art != e.kind and _icon((e as Unit).art):
			icon = _icon((e as Unit).art)      # (an armoured Musketeer)
		var pr := Rect2(r.position + Vector2(10, 10), Vector2(68, 68))
		UiStyle.draw_button(self, pr.grow(2), false, false)
		if icon:
			draw_texture_rect(icon, pr, false)
		var name := ""
		var info := ""
		var eff_txt := ""                # economy buildings: "Efficiency 62%: 5/8 workers · soil 78%" (in its colour)
		var eff_col := UiStyle.MUTED
		if e is Unit:
			name = (e as Unit).d["name"]
			var tags: Array = (e as Unit).d.get("tags", [])
			if not tags.is_empty():
				name += "  ·  " + " ".join(tags.map(func(x: String) -> String: return x.capitalize()))
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
			elif uu.order == "revive":
				info = "Raising a fallen soldier..." if uu.work == "reviving" else "Going to raise a fallen soldier."
			elif uu.cross_t > 0.0 and uu.d["faction"] == "crown":
				info = "Under the cross for %d s: no bandage or raising meanwhile, and if he falls now he's gone for good." % int(ceil(uu.cross_t))
			elif uu.kind == "mortar":
				info = {"packed": "Packed: it rolls, can't fire. DEPLOY to fire.", "deploying": "Deploying...",
					"deployed": "Set up: lobs shells 5 to 11 tiles (over walls) at anything your side can see.",
					"packing": "Packing up..."}[uu.tesla_mode]
				info += "  Shells %d/%d%s" % [int(uu.powder), int(uu._pmax), " (OUT: refill at a Mill, Barracks, Hall or Wagon)" if uu.powder < 1.0 else ""]
			elif uu.kind == "cannon":
				info = {"packed": "Limbered: the horse tows it. UNLIMBER to fire.", "deploying": "Unlimbering...",
					"deployed": "Set up: %s loaded. Fires at anything your side can see." % ("canister" if uu.mode == "canister" else "round shot"),
					"packing": "Limbering up..."}[uu.tesla_mode]
				info += "  Powder %d/%d%s" % [int(uu.powder), int(uu._pmax), " (OUT: refill at a Mill, Barracks, Hall or Wagon)" if uu.powder < 1.0 else ""]
			elif uu.kind == "musketeer":
				if uu.powder < 1.0:
					info = "OUT OF POWDER: fights with the bayonet. Refills at a Mill, Barracks, Hall or Wagon."
				else:
					info = "Powder %d/%d%s · refills at a Mill, Barracks, Hall or Wagon" % [int(uu.powder), int(uu._pmax), "  (bayonet: the enemy is on him)" if uu.mode == "bayonet" else ""]
			elif uu.kind == "powder_wagon":
				var runs := game.units.filter(func(x: Unit) -> bool: return x.order == "keg" and x.order_target == uu).size()
				info = "Powder %d/%d shots · SUPPLY %s%s · blows up when destroyed" % [int(uu.powder), int(uu._pmax), "on" if uu.supplying else "off",
					(" (%d running kegs)" % runs) if uu.supplying and runs > 0 else ""]
			elif uu.kind == "labourer" and uu.order == "keg":
				info = "Carrying a powder keg to the wagon: it blows up if he's killed!" if uu.keg else "Fetching a powder keg from the Powder Mill."
			elif uu.kind == "spore_mother":
				info = {"packed": "Walking: can't attack. ROOT her to lob spit blobs.", "deploying": "Rooting...",
					"deployed": "Rooted: lobs spit blobs and spreads swamp.", "packing": "Uprooting..."}[uu.tesla_mode]
				if uu.spell_cd > 0.0:
					info += "  Miasma ready in %ds." % int(ceil(uu.spell_cd))
			elif uu.kind == "mist_toad":
				info = "Energy %d / %d (FOG %d, TONGUE %d) · fills %s" % [int(uu.charge), int(Defs.TOAD["max"]), int(Defs.FOG["cost"]), int(Defs.TONGUE["cost"]),
					"twice as fast on swamp (now)" if game.on_swamp(uu.team, uu.position) else "faster on swamp"]
				if uu.tongue_stage == "windup":
					info = "Aiming its tongue: %.1f s (don't move it!)" % uu.tongue_t
			elif uu.kind == "stormcaller":
				info = "Charge %d / %d (a storm costs %d). %s" % [int(uu.charge), int(Defs.STORM["max"]), int(Defs.STORM["cost"]),
					"Recharging in the field." if uu._in_field and uu.charge < float(Defs.STORM["max"]) else ("Full." if uu.charge >= float(Defs.STORM["max"]) else "Bring it into a Clockwork field to recharge.")]
			elif uu.kind == "cuirassier":
				info = "Charge ready: the next blow hits double and throws the enemy back." if uu.run_t >= float(Defs.CHARGE["run"]) else uu.d["about"]
			elif uu.kind == "tesla_cart":
				info = {"packed": "Packed: rolls, can't fire. DEPLOY to fight.", "deploying": "Deploying...",
					"deployed": "Deployed: powers constructs nearby and zaps enemies.", "packing": "Packing up..."}[uu.tesla_mode]
			elif uu.kind == "balloon":
				info = ("%d / %d aboard. UNLOAD to let them off." % [uu.passengers.size(), int(Defs.DROPSHIP["capacity"])]) if not uu.passengers.is_empty() else uu.d["about"]
				if not uu.incoming.is_empty():
					info = "Coming down: %d climbing in." % uu.incoming.size()
			elif uu.kind == "skywing":
				info = {"air": "Flying: hunts flyers with spines. LAND to fight on the ground.", "to_land": "Looking for open ground to land on...",
					"landing": "Landing...", "ground": "Landed: walks and bites ground units; anything can hit it. TAKE OFF to fly.", "lifting": "Taking off..."}.get(uu.sky, uu.d["about"])
			elif uu.kind == "bloater" and uu.deflate != "":
				info = "Out of gas: deflated, slower and harmless. Gas %d / 100 (fills faster on swamp)." % int(uu.gas)
			elif uu.kind == "ornithopter" and (uu.topter_bat != "" or uu.courier):
				info = ("Carrying a %s battery: OVERLOAD a construct with it, or it winds one up on COURIER." % uu.topter_bat) if uu.topter_bat != "" else "Courier: fetching batteries for constructs that run down."
			elif uu.kind == "windup_soldier" and uu.powered_down():
				info = "RUN DOWN: frozen until a Winder cranks it up again (or a field reaches it)."
			elif uu.kind == "windup_soldier":
				info = "Spring %d%%%s: about 50 s away from a field and it runs down." % [int(uu.wind * 100), " (being cranked)" if uu.cranked_t > 0.0 else ""]
			elif uu.kind == "bulwark" and uu.braced:
				info = "BRACED: can't move; armour 7; shots at your units behind the shield hit it instead. Charge %d%%." % int(uu.wind * 100)
			elif uu.kind == "thresher" and uu.spin > 0.05 and uu.overclock_t <= 0.0:
				info = "Saws %d%% spun up (x%.1f damage) · Charge %d%%: spinning drains it fast." % [int(uu.spin * 100), lerpf(float(Defs.THRESHER["low"]), float(Defs.THRESHER["high"]), uu.spin), int(uu.wind * 100)]
			elif uu.kind == "winder" and uu.self_wind_t > 0.0:
				info = "Winding its own spring (%d s)." % int(ceil(uu.self_wind_t))
			elif uu.overcharged() and uu.overclock_t <= 0.0:
				info = "OVERCHARGED: +15%% damage while it stays here. Charge %d%%." % int(uu.wind * 100)
			elif uu.overclock_t > 0.0:
				info = "OVERLOADED for %d s: +50%% damage, +30%% speed. Burns out to 25%% charge." % int(ceil(uu.overclock_t))
			elif uu.kind == "missionary":
				info = "In danger near enemy buildings!" if not uu.untouchable() else "Can't be hurt here. Bandages wounded soldiers."
			elif (e as Unit).powered_down():
				info = "OUT OF CHARGE: shut down. A field (tower, pylon, deployed Tesla Cart) or a Winder brings it back."
			elif (e as Unit).d["faction"] == "clockwork" and not (e as Unit).is_worker() and (e as Unit).wind < 0.99:
				info = "Charge %d%%: it runs down away from a field and shuts down when empty." % int((e as Unit).wind * 100)
		elif e is Building:
			name = (e as Building).d["name"]
			info = (e as Building).d["about"]
			var bb := e as Building
			if not bb.seeded and bb.crate != "":
				info = {"tower": "Waiting for its crate: a Winder fetches it from a Clocktower.",
					"carried": "Its crate is on the way, on a Winder's back.",
					"ground": "Its crate was dropped on the way: send a Winder onto it (destroyed, the building is cancelled)."}.get(bb.crate, "")
			elif not bb.seeded:
				info = "Waiting for a %s." % ("Winder to start it" if bb.d["faction"] == "clockwork" else "grub to turn into it")
			elif not bb.built:
				info = "%s: %d%%" % ["Growing" if bb.d["faction"] == "brood" else "Under construction", int(bb.progress * 100)]
			elif bb.kind == "farm":
				var soil := bb.soil_left()
				info = "Harvest in %ds · +%d gold%s" % [int(ceil((1.0 - bb.growth) * Defs.FARM_GROW / maxf(bb.farm_speed(), 0.01))),
					game.harvest_value(bb), " · tired soil: expand" if soil <= 0.0 else ""]
			elif bb.kind == "town_hall" and (e.team == game.human or game.demo):
				var soil := bb.soil_left()
				var salt := bb.lode_left()
				info = "Soil: %d%% (%d gold)%s · Saltpetre: %d%% (%d powder)%s · allows 2 Farms and 1 Powder Mill nearby" % [int(round(soil * 100)), int(bb.soil),
					" spent: farms pay a third" if soil <= 0.0 else (" running low" if soil < Defs.SOIL_LOW else ""),
					int(round(salt * 100)), int(bb.lode), " spent: the Mill grinds at a quarter" if salt <= 0.0 else (" running low" if salt < Defs.SOIL_LOW else "")]
			elif bb.kind == "clocktower" and (e.team == game.human or game.demo):
				var coal := bb.soil_left()
				info = "%d/%d batteries ready (one every %.1f s) · Ore: %d left%s · Coal: %d%%%s · allows 2 Boilers and 2 Ore Crushers nearby" % [
					bb.batteries, int(bb.d["battery"][1]), float(bb.d["battery"][0]), int(bb.lode),
					" (spent: its crushers pay a quarter; expand)" if bb.lode <= 0.0 else (" (running low)" if bb.lode_left() < Defs.SOIL_LOW else ""),
					int(round(coal * 100)), " (spent: its Boilers fill at a third)" if coal <= 0.0 else (" (running low)" if coal < Defs.SOIL_LOW else "")]
			elif bb.kind == "powder_mill":
				var sl := bb.lode_left()
				info = "+%.1f powder/s%s" % [game.lode_pay(bb, Defs.MILL_RATE * bb.working_crew()), " · saltpetre spent: a quarter; expand to a new Town Hall" if sl <= 0.0 else (" · saltpetre running low" if sl < Defs.SOIL_LOW else "")]
			elif bb.kind == "feeding_pit":
				var gl := bb.soil_left()
				info = "Each load is worth %.1f%s" % [game.load_value(bb), " · spent ground: a third; grow a Hive on fresh ground" if gl <= 0.0 else ""]
			elif bb.d.has("battery") and e.team == game.human:
				var bat: Array = bb.d["battery"]
				var coal2 := bb.soil_left()
				info = "%d/%d batteries ready (one every %.1f s)%s" % [bb.batteries, int(bat[1]),
					float(bat[0]) / (1.0 if coal2 > 0.0 else Defs.COAL_SPENT), " · coal spent: a third as fast" if coal2 <= 0.0 else (" · coal running low" if coal2 < Defs.SOIL_LOW else "")]
			elif bb.kind == "ore_crusher":
				var blue := game.blue_energy(e.team)
				var bi: Dictionary = Defs.BATTERY["blue" if blue else "yellow"]
				var ol := bb.lode_left()
				var q := 1.0 if ol > 0.0 else Defs.LODE_SPENT
				info = "%s batteries: %d ore; after %d s on the road they lose %d%% a second%s" % ["Blue" if blue else "Yellow",
					int(round(Defs.battery_charge(blue, 0.0) * float(Defs.BATTERY["ore"]) * q)), int(Defs.BATTERY["fresh"]), int(round(float(bi["decay"]) * 100)),
					" · ore spent: a quarter" if ol <= 0.0 else (" · ore running low" if ol < Defs.SOIL_LOW else "")]
			elif bb.kind == "brood_pen":
				info = "Bodies falling within %d tiles give essence. SACRIFICE Brood creatures here: 12%% of their biomass as essence (a Raptor: 3)." % Defs.PEN_RANGE
			elif bb.uses_eggs() and (e.team == game.human or game.demo):
				var nxt := "" if bb.eggs + bb.queue.size() >= Defs.EGGS_MAX else "  (next in %ds)" % int(ceil(Defs.EGG_TIME - bb.egg_t))
				var gl := bb.soil_left()
				info = "Eggs: %d / %d%s · Ground: %d%% (%d biomass)%s" % [bb.eggs, Defs.EGGS_MAX, nxt, int(round(gl * 100)), int(bb.soil),
					" spent: pits yield a third, grow a Hive on fresh ground" if gl <= 0.0 else (" running low" if gl < Defs.SOIL_LOW else "")]
			if bb.built and (e.team == game.human or game.demo):
				var ef: Array = bb.efficiency()
				if not ef.is_empty():
					var who := "base Winders" if bb.kind == "ore_crusher" else ("grubs" if bb.kind == "feeding_pit" else ("Winders" if bb.d["faction"] == "clockwork" else "workers"))
					eff_txt = "Efficiency %d%%: %d/%d %s · %s %d%%" % [int(round(float(ef[0]) * 100)), int(ef[1]), int(ef[2]), who, ef[4], int(round(float(ef[3]) * 100))]
					eff_col = game.eff_colour(float(ef[0]))
		if e.team >= 0 and e.team != game.human:
			name += "  (enemy)"
		_text(UiStyle.title_font(), r.position + Vector2(90, 28), name, 19, UiStyle.TEXT)
		var hf := clampf(e.hp / maxf(e.max_hp, 1.0), 0.0, 1.0)
		var hb := Rect2(r.position + Vector2(90, 38), Vector2(170, 12))
		draw_rect(hb, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * hf, hb.size.y)), UiStyle.GOOD if hf > 0.5 else (Color(0.95, 0.75, 0.25) if hf > 0.25 else UiStyle.BAD))
		draw_rect(hb, UiStyle.TRIM_DIM, false, 1.0)
		var hpt := "%d / %d" % [int(ceil(e.hp)), int(e.max_hp)]
		_text(font, hb.position + Vector2(hb.size.x + 8, 11), hpt, 15, Color(0.75, 1, 0.7))
		if e is Unit and (e as Unit).kills > 0:
			# veterancy: kills and the damage they've earned
			var ku := e as Unit
			var bonus := minf(ku.kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"]))
			var vt := "%s%d kill%s · +%d%% damage" % ["Veteran · " if not ku.is_worker() else "", ku.kills, "" if ku.kills == 1 else "s", int(round(bonus * 100.0))]
			var vx := hb.position.x + hb.size.x + 22 + font.get_string_size(hpt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var room := r.end.x - 36 - vx
			if UiStyle.bold_font().get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > room:
				vt = "%d kills +%d%%" % [ku.kills, int(round(bonus * 100.0))]
			if UiStyle.bold_font().get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= room:
				_text(UiStyle.bold_font(), Vector2(vx, hb.position.y + 11), vt, 14, Color(1, 0.82, 0.3))
			else:
				info = vt + " · " + info
		if eff_txt != "":
			# the efficiency breakdown first, in its bar's colour, then the rest
			_text(font, r.position + Vector2(90, 72), eff_txt, 15, eff_col)
			var ew := font.get_string_size(eff_txt + "  ·  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			_text(font, r.position + Vector2(90 + ew, 72), info, 15, UiStyle.MUTED)
		else:
			_text(font, r.position + Vector2(90, 72), info, 15, UiStyle.MUTED)
		if e is Unit and (e as Unit).kind == "balloon" and e.team == game.human:
			# who's in the basket
			var ps: Array = (e as Unit).passengers
			for i in ps.size():
				if not is_instance_valid(ps[i]):
					continue
				var pic := _icon(ps[i].kind)
				var pqr := Rect2(r.end.x - 72 - (ps.size() - 1 - i) * 38, r.position.y + 8, 34, 34)
				UiStyle.draw_button(self, pqr.grow(1), false, false)
				if pic:
					draw_texture_rect(pic, pqr, false)
				var pf: float = ps[i].hp / maxf(ps[i].max_hp, 1.0)
				draw_rect(Rect2(pqr.position.x, pqr.end.y + 1, pqr.size.x * pf, 3), Color(0.3, 0.9, 0.3) if pf > 0.5 else Color(0.95, 0.4, 0.2))
		if e is Building and (e.team == game.human or game.spectating()) and not (e as Building).queue.is_empty():
			var q: Array = (e as Building).queue
			for i in q.size():
				var ic := _icon(_research_icon(String(q[i]).substr(1)) if Building.is_research(q[i]) else q[i])
				var qr := Rect2(r.end.x - 44 - (q.size() - 1 - i) * 40, r.position.y + 8, 36, 36)
				if ic:
					draw_texture_rect(ic, qr, false)
				var eb := e as Building
				if i == 0 or eb.uses_eggs():
					var f: float = (eb.morph_t[i] if eb.uses_eggs() else eb.prod_t) / Building.entry_time(q[i])
					draw_rect(Rect2(qr.position.x, qr.end.y + 2, qr.size.x * f, 4), Color(0.75, 0.55, 1.0) if Building.is_research(q[i]) else Color(0.4, 0.75, 1))
				if Building.is_research(q[i]):
					draw_rect(qr, Color(0.75, 0.55, 1.0, 0.9), false, 1.5)     # research: a violet frame
	else:
		var n := mini(sel.size(), 24)
		var per_row := int((r.size.x - 20) / 38)
		_portraits = []
		for i in n:
			var e: Entity = sel[i]
			var ir := Rect2(r.position + Vector2(10 + (i % per_row) * 38, 8 + (i / per_row) * 40), Vector2(34, 34))
			_portraits.append({"rect": ir, "e": e})
			if Settings.pc() and ir.has_point(_mouse()):
				draw_rect(ir.grow(2), UiStyle.TRIM_DIM, false, 1.0)
			var ic := _icon(e.kind)
			if ic:
				draw_texture_rect(ic, ir, false)
			var f := e.hp / e.max_hp
			draw_rect(Rect2(ir.position.x, ir.end.y, ir.size.x * f, 3), Color(0.3, 0.9, 0.3) if f > 0.5 else Color(0.95, 0.4, 0.2))
			if e is Unit and (e as Unit).kills > 0:
				_text(UiStyle.bold_font(), Vector2(ir.end.x - 1, ir.position.y + 11), str((e as Unit).kills), 12, Color(1, 0.82, 0.3), 2)
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
	if sel.size() > 1:
		for pt in _portraits:
			var pe: Entity = pt["e"]
			_buttons_extra.append({"rect": pt["rect"], "enabled": true, "cb": func() -> void: _portrait_pressed(pe)})


var _portraits: Array = []


## A portrait in a multiple selection: the first tap keeps only that kind, a tap when
## they're all one kind keeps only that one (and a second tap on it centres the view).
func _portrait_pressed(e: Entity) -> void:
	if not is_instance_valid(e) or e.dead:
		return
	var sel: Array = game.selection.filter(func(x: Entity) -> bool: return is_instance_valid(x) and not x.dead)
	var same: Array = sel.filter(func(x: Entity) -> bool: return x.kind == e.kind)
	if same.size() < sel.size():
		game.set_selection(same)
	else:
		game.set_selection([e])
		_jump(e.global_position)


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
		var auto_on := String(it[1]).begins_with("~ ")
		if ic:
			draw_texture_rect(ic, br.grow(-3), false, Color.WHITE if enabled else Color(0.4, 0.4, 0.4, 0.8))
		draw_rect(Rect2(br.position.x + 2, br.end.y - 17, br.size.x - 4, 15), Color(0, 0, 0, 0.62))
		_text(UiStyle.bold_font(), Vector2(br.get_center().x, br.end.y - 5), String(it[1]).trim_prefix("> ").trim_prefix("~ "), 11, (Color(1, 0.9, 0.55) if on else UiStyle.TEXT) if enabled else Color(1, 1, 1, 0.45), 1)
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
		if auto_on:
			_autocast_glow(br)
		if hov:
			_tooltip(font, it, cr)
		var bt := {"rect": br, "cb": it[2], "enabled": enabled, "why": it[4]}
		var plain := String(it[1]).trim_prefix("> ").trim_prefix("~ ")
		if _alt_for.has(plain):
			bt["alt"] = _alt_for[plain]
		_buttons.append(bt)


## Autocast (WORK, PUSH): a golden outline that breathes, with sparks running round it.
func _autocast_glow(br: Rect2) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var a := 0.55 + 0.35 * sin(t * 4.0)
	draw_rect(br.grow(1), Color(1.0, 0.82, 0.3, a), false, 2.0)
	var per := 2.0 * (br.size.x + br.size.y)
	for k in 2:
		var d := fmod(t * 90.0 + k * per * 0.5, per)
		var p := br.position
		if d < br.size.x:
			p += Vector2(d, 0)
		elif d < br.size.x + br.size.y:
			p += Vector2(br.size.x, d - br.size.x)
		elif d < 2.0 * br.size.x + br.size.y:
			p += Vector2(br.size.x - (d - br.size.x - br.size.y), br.size.y)
		else:
			p += Vector2(0, br.size.y - (d - 2.0 * br.size.x - br.size.y))
		draw_circle(p, 3.5, Color(1, 0.95, 0.6, 0.95))
		draw_circle(p, 6.0, Color(1, 0.8, 0.3, 0.3))


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
	var title: String = String(it[1]).trim_prefix("> ").trim_prefix("~ ")
	var body := ""
	var k: String = it[0]
	const ABOUT := {
		"SUPPLY": "Keg runs (glowing = on): while the wagon has room, up to 2 labourers carry 30-shot kegs to it from the nearest Powder Mill (15 powder a keg). A labourer killed with a keg blows up.",
		"UNLIMBER": "Unlimber (2.5 s): set the gun up to fire. It can't move until it limbers again.",
		"LIMBER": "Limber up (2.5 s): hitch the gun to the horse to move it. It can't fire while limbered.",
		"CANISTER": "Load canister: short range, a cone of musket balls; big damage, +50% against Light units, and it hits flyers. One of the gun's 8 shots.",
		"STORM": "Static storm: a ring of lightning (2.5-tile radius) on a spot for 2.5 s. Everything inside is stunned, your own units too; it does no damage: hit them while they stand. Costs 70 charge and 2 stored batteries; the Stormcaller recharges only inside a Clockwork field.",
		"HARVEST": "Harvest the fallen: the grubs stay here and wrap every body nearby (friend or foe) in a cocoon, carrying it to a Hive as essence. Veterans hold more. Bodies rot away after 2 minutes.",
		"SACRIFICE": "Sacrifice: the selected Brood creatures (not grubs) go to the nearest Brood Pen and are offered up there, each for 12% of its biomass cost as essence (a Raptor 3, a Spitter 5, a Brute 18). Turn spare biomass into essence for Skywings, Bloaters, Brutes and Spore Mothers.",
		"HOLD GAS": "Hold gas: stop spitting and keep the sac full; the Bloater drifts in and bursts as a huge acid bomb (damage and cloud grow with the gas left).",
		"SPIT": "Spit: lob acid from range (160). Every glob uses up gas, so the final burst gets smaller.",
		"FOG": "Swamp fog (50 energy): a fog bank, 3 tiles across each way, on a spot within 7 tiles for 12 s. Ranged attacks fired from inside it or into it miss half the time (yours too), and units inside see only 2 tiles. Black powder's own smoke, turned on the Crown.",
		"TONGUE": "Tongue (75 energy): tap an enemy unit on the ground within 7 tiles. A crosshair marks it for 3 s (its owner sees it), then the tongue lashes out and drags it to the Toad's feet. The windup breaks if the Toad is stunned, killed or moved, or the target gets 1.5x the range away (the energy is lost). Steam Walkers and other heavy engines are only staggered (1 s). Not buildings or flyers.",
		"MIASMA": "Mending miasma: a green cloud for 8 s. Brood inside heal up to 30% of their health. Clouds don't stack. 30 essence, then 18 s to recover.",
		"ROOT": "Root (2.5 s): she digs in, lobs big spit blobs that splash an area, and spreads swamp. She can't move until she uproots.",
		"UPROOT": "Uproot (2.5 s) to walk again. Walking, she can't attack.",
		"LOAD": "Load the balloon: then tap Musketeers or Labourers (or right-click the balloon with them selected). They walk under it and climb in, 4 at most; it must hover over ground they can reach. Carried Musketeers shoot from the basket.",
		"UNLOAD": "Unload: tap where to drop them. The balloon flies there and lets everyone off on the nearest open ground (over a cliff edge too). Tap the balloon, or DROP HERE, to let them off where it is.",
		"DROP HERE": "Let everyone off right below the balloon.",
		"COURIER": "Courier (automatic, glowing = on): idle Ornithopters fetch a charged battery from an energy building and wind up constructs that ran down (shut-down ones first). Click to switch on or off.",
		"BRACE": "Brace (glowing = braced): the Bulwark plants its tower shield. It can't move (a move order lifts it), its armour goes up to 7, and musket balls, spit, arc balls and spines aimed at your units behind it hit the shield instead. Its lance still pokes at anything in reach.",
		"OVERLOAD": "Overload: tap one of your constructs. The Ornithopter dumps its battery into it: +50% damage, +30% speed and faster attacks for 12 s, then it's left with 25% charge.",
		"LAND": "Land (1.2 s): fight on the ground with a bite. Landed it walks, can't cross cliffs and anything can hit it; it can't attack flyers.",
		"TAKE OFF": "Take off (1.2 s): fly again and hunt flyers with spines (it can't attack the ground while flying).",
		"ROUND SHOT": "Load round shot: the longest range in the game; the ball ploughs through a line of men, YOUR OWN TOO (+75% against Armored), small splash, smashes buildings. Can't hit flyers. One of the gun's 8 shots.",
	}
	for rk in Defs.RESEARCH:
		if title == String(Defs.RESEARCH[rk]["name"]).to_upper():
			var ri: Dictionary = Defs.RESEARCH[rk]
			var rc := "%d %s" % [int(ri["cost"]), _res()[0].to_lower()]
			if int(ri.get("cost2", 0)) > 0:
				rc += " + %d %s" % [int(ri["cost2"]), _res()[1].to_lower()]
			title = "%s   (%s, %d s)" % [ri["name"], rc, int(ri["time"])]
			body = ri["about"] + "  Queued like a unit; CANCEL takes the last thing in the queue back out (paid back)." 
	if title == "WORK":
		body = "Automatic work: idle workers go back to their posts on their own (glowing = on). Press to switch it off for the selected workers, to scout or keep a builder free."
	if title == "REPAIR":
		body = "Click, then click a damaged building or wall: they fix it (costs a quarter of its price for a full repair). Right-click: automatic repair (glowing = on): idle workers fix damaged buildings nearby by themselves, before going back to work." if Settings.pc() \
			else "Tap, then tap a damaged building or wall to fix it. Hold: automatic repair (glowing = on): idle workers fix damaged buildings nearby by themselves, before going back to work."
	if ABOUT.has(title):
		body = ABOUT[title]
	elif Defs.UNITS.has(k) and title == Defs.UNITS[k]["name"].to_upper():
		var u: Dictionary = Defs.UNITS[k]
		title = u["name"]
		body = u["about"]
		var cost := "%d %s" % [u["cost"], _res()[0].to_lower()]
		if u.has("cost2"):
			cost += " + %d %s" % [u["cost2"], _res()[1].to_lower()]
		title += "   (%s, supply %d)" % [cost, int(u["supply"]) * int(u.get("spawn", 1))]
		body += "  Right-click: train it automatically (glows while on)."
		var tg: Array = u.get("tags", [])
		if not tg.is_empty():
			body = "[%s] " % " ".join(tg.map(func(x: String) -> String: return x.capitalize())) + body
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
	# the Clockwork and the Brood have their own command icons
	var fac := game.faction_of(game.human) if game else ""
	if fac != "crown" and fac != "":
		var fp := "res://assets/icons/%s/%s.png" % [fac, name]
		if ResourceLoader.exists(fp):
			return Game.tex(fp)
	var path := "res://assets/icons/%s.png" % name
	if ResourceLoader.exists(path):
		return Game.tex(path)
	return null


func _text(font: Font, p: Vector2, s: String, sz: int, col: Color, align := 0) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var x := p.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	draw_string_outline(font, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, col.a * 0.8))
	draw_string(font, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
