extends Control
## On-screen interface: resource bar, minimap, group buttons, selection panel,
## command card, messages and the pause menu. Drawn by hand; it takes touches
## that land on its panels before the map sees them.

signal quit_requested

const CARD_BTN := 52.0           # mobile: 4 x 3 (x1.5 interface scale: 78 px, still a thumb's width)
const CARD_BTN_PC := 60.0        # computer: 4 x 3 with letter hotkeys
const MINI_W := 210.0

var game: Game
var controls: Controls
var page := ""                       # command card page: "", build
var build_page := 0
var paused := false
var _card_buttons: Array = []        # the command card's: {rect, cb, enabled, why, item, alt}
var _hud_touches := {}               # touch index -> what it pressed
var _msg := ""
var _msg_t := 0.0
var bar: HotkeyBar                   # the bottom hotkey bar (scripts/ui/hotkey_bar.gd)
var _attack_alarm_t := 0.0
var _mouse_hud := false
var _card_items: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar = HotkeyBar.new(self)
	_fit()
	for n in LAYERS:
		var l := HudLayer.new()
		l.hud = self
		l.fn = n
		_layer[n] = l
		add_child(l)


## The HUD is drawn at Settings.ui_scale (bigger on phones): it works in its own smaller
## coordinate space and is scaled up to fill the screen.
var ui_scale := 1.0


func _fit() -> void:
	ui_scale = Settings.ui_scale_now()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	scale = Vector2(ui_scale, ui_scale)
	size = get_viewport_rect().size / ui_scale
	_sig.clear()          # (everything is drawn again)


## (asked once a frame: on some platforms the system is asked where the pointer is)
func _mouse() -> Vector2:
	var f := Engine.get_process_frames()
	if f != _mouse_frame:
		_mouse_frame = f
		_mouse_at = get_viewport().get_mouse_position()
	return _mouse_at / ui_scale


var _mouse_frame := -1
var _mouse_at := Vector2.ZERO


## For callers working in screen pixels.
func hud_has_screen(p: Vector2) -> bool:
	return _hud_has(p / ui_scale)


func toast(t: String, sound := true) -> void:
	_msg = Loc.t(t)
	_msg_t = 2.2
	if sound:
		Sfx.play_any(["ui/error", "error"])
	if game and not game.demo:
		var fac := game.faction_of(game.human)
		var res: Array = Defs.res_names(fac)
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
## Online: the countdown waits (frozen at its start) until every player's match has loaded; the host's
## NetSession releases it on both sides at once ("ready" / "go", net/net_session.gd).
var count_hold := false


func start_countdown(secs := 3.0) -> void:
	countdown = secs
	_count_shown = -1
	get_tree().paused = true


func _countdown(delta: float) -> void:
	if countdown <= 0.0 or paused:
		return
	get_tree().paused = true
	if game:
		game.update_view_rect()         # (the game's tick keeps it current; it hasn't ticked yet)
		if game.gear_net:
			game.gear_net.held()        # (the ground gears stand drawn through the countdown, not popping in at GO)
	if count_hold:
		return
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


var _go_t := 0.0


func _draw_countdown() -> void:
	if countdown <= 0.0 and _go_t <= 0.0:
		return
	var vs := _vs()
	var c := vs * 0.5 - Vector2(0, 40)
	var font := UiStyle.bold_font()
	if count_hold and countdown > 0.0:
		_ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.25))
		_text(font, c, Loc.t("Waiting for the other player..."), 30, Color(1, 0.88, 0.45, 0.9), 1)
		return
	var txt := str(int(ceil(countdown))) if countdown > 0.0 else "GO!"
	var f: float = (countdown - floor(countdown)) if countdown > 0.0 else _go_t / 0.6
	var sz := int(96 + 40 * f)
	if countdown > 0.0:
		_ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.25))
	var a := clampf(f * 1.6, 0.0, 1.0) if countdown > 0.0 else clampf(_go_t / 0.6, 0.0, 1.0)
	_text(font, c + Vector2(3, 3), txt, sz, Color(0, 0, 0, 0.6 * a), 1)
	_text(font, c, txt, sz, Color(1, 0.88, 0.45, a), 1)
	if countdown > 0.0:
		_text(font, c + Vector2(0, 60), "Get ready", 22, Color(1, 1, 1, 0.8), 1)


func _process(delta: float) -> void:
	var _p0 := Time.get_ticks_usec()
	_tick_hud(delta)
	Prof.add("hud", _p0)


func _tick_hud(delta: float) -> void:
	_msg_t = maxf(_msg_t - delta, 0.0)
	_countdown(delta)
	if _go_t > 0.0:
		_go_t = maxf(_go_t - delta, 0.0)
	if not _alt_press.is_empty() and not _alt_press["done"] and Time.get_ticks_msec() - int(_alt_press["t"]) > 450:
		_alt_press["done"] = true
		if game:
			game.input_cmd = true
		(_alt_press["b"]["alt"] as Callable).call()
		if game:
			game.input_cmd = false
		Sfx.play_any(["ui/click", "click"])
	if game == null:
		return
	var fade: float = game.spectator.fade if game.spectator else 0.0
	if fade != _fade_drawn:
		_fade_drawn = fade
		queue_redraw()       # the follow camera's cut (the HUD itself, under the layers)
	# the minimap's picture: five times a second
	_mini_t -= delta
	if _mini_t <= 0.0:
		_mini_t = 0.2
		(_layer["minimap"] as CanvasItem).queue_redraw()
	# what the HUD shows changes slowly: look 20 times a second (and at once after a touch,
	# a click or a key) and redraw the layers whose signature changed; a moving mouse only
	# moves the highlights (and the tooltip)
	_redraw_t -= delta
	_full_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 0.05
		_moved = false
		if not size.is_equal_approx(get_viewport_rect().size / ui_scale) or ui_scale != Settings.ui_scale_now():
			_fit()
		if _full_t <= 0.0:
			_full_t = 1.0
			_sig.clear()      # once a second everything is drawn again, whatever it shows
			(_layer["minimap"] as CanvasItem).queue_redraw()
		_tick_n += 1
		var q := Time.get_ticks_usec()
		_card_wait -= 1
		if _card_fresh or _card_wait <= 0:
			# (the command card is rebuilt at once after a click, a key or a touch and otherwise
			# four times a second: it was 20 times, and each build asks the game a lot)
			_card_fresh = false
			_card_wait = 5
			_refresh_card()
		_refresh_counts()
		var q2 := Time.get_ticks_usec()
		_update_tip()
		Prof.add("hud/tip check", q2)
		_check(LAYERS)
		Prof.add("hud/look", q)
	elif _moved:
		_moved = false
		var q := Time.get_ticks_usec()
		if not _tip.is_empty() and Settings.pc():
			_tip_at = _mouse()      # (it follows the mouse; what's under it is looked at 20 times a second)
		_moved_check = true
		_check(["top", "map view", "groups", "selection", "command card", "rest", "chat", "tooltip", "pause"])
		_moved_check = false
		Prof.add("hud/hover", q)
	else:
		_check(["map view", "rest"])


# ------------------------------------------------------------------ drawing in layers
## The HUD is drawn on several canvas items, the layers below in drawing order. A canvas item
## keeps what it drew until it's drawn again, so each layer is redrawn only when what it
## shows has changed (its signature, _layer_sig): a HUD that sits still costs nothing.

class HudLayer extends Node2D:
	var hud: Control
	var fn := ""

	func _draw() -> void:
		hud._draw_layer(self)


const LAYERS := ["top", "minimap", "map view", "groups", "selection", "command card", "glow", "rest", "chat", "tooltip", "pause"]
var _layer := {}                 # name -> HudLayer
var _sig := {}                   # name -> its signature when it was last drawn
var _ci: CanvasItem = self       # the canvas item being drawn on (a layer)
var _moved := false              # the mouse moved since the last look
var _full_t := 0.0
var _mini_t := 0.0
var _tick_n := 0                 # looks so far (layers that change all the time use it)
var _fade_drawn := 0.0
var _top_vals: Array = []        # the top bar's numbers at the last look
var _moved_check := false        # checking only for the mouse's sake


func _check(names: Array) -> void:
	for n in names:
		var s: Array = _layer_sig(n)
		if not _sig.has(n) or _sig[n] != s:
			_sig[n] = s
			(_layer[n] as CanvasItem).queue_redraw()


func _draw_layer(l: HudLayer) -> void:
	if game == null:
		return
	var p0 := Time.get_ticks_usec()
	_ci = l
	var font := ThemeDB.fallback_font
	match l.fn:
		"top":
			_draw_top(font)
		"minimap":
			_draw_minimap()
		"map view":
			_draw_map_view()
		"groups":
			_draw_groups(font)
		"selection":
			_draw_panel(font)
		"command card":
			_draw_card(font)
		"glow":
			for b in _card_buttons:
				if String(b["item"][1]).begins_with("~ "):
					_autocast_glow(b["rect"])
		"rest":
			_draw_rest(font)
		"chat":
			_draw_chat()
		"tooltip":
			if not paused and not menu_open:
				_draw_tip()
		"pause":
			if paused or menu_open:
				_draw_pause()
	_ci = self
	Prof.add("hud/" + l.fn, p0)
	Prof.add("hud draw", p0)


## What a layer shows, in short: when it changes, the layer is redrawn.
func _layer_sig(n: String) -> Array:
	var pc := Settings.pc()
	var m := _mouse() if pc else Vector2(-1, -1)
	match n:
		"top":
			if _moved_check and not _top_vals.is_empty():
				return _top_vals + [menu_rect().has_point(m)]
			var shown := game.view_team if game.spectating() else game.human
			var vals: Array = [shown, _vs(), int(game.clock), game.demo, pc, Settings.drag_mode, _help_on(), help_mode, game.spectator == null]
			if shown >= 0:
				var pl: Dictionary = game.players[shown]
				vals.append_array([int(pl["gold"]), int(pl["res2"]), int(pl["cap"]), game.supply_used(shown)])
				if game.faction_of(shown) == "clockwork":
					vals.append_array([int(game.energy[shown]), game.blue_energy(shown), int(float(pl.get("tension", 0.0))), int(GearEcon.tension_cap(game, shown))])
				if game.faction_of(shown) == "crown":
					vals.append(game.horses_text(shown))
			else:
				for t in game.players.size():
					if not game.eliminated[t]:
						vals.append(_res_line(t))
			if not game.demo:
				vals.append(game.apm())
			if _online():
				var pm := game.net.ping_shown()
				vals.append_array([pm / 5 if pm < 1000 else pm / 100, game.net.ping_grade(), game.net.waiting])
			_top_vals = vals
			return vals + [menu_rect().has_point(m)]
		"map view":
			var mr := mini_rect()
			var k := mr.size / (Vector2(Game.W, Game.H) * Game.T)
			var vp := get_viewport().get_visible_rect().size / game.camera.zoom
			var c := game.camera.get_screen_center_position()
			var al := []
			if game.alert_t > 0.0 and game.alert_at != Vector2.INF:
				al = [game.alert_at, int(game.alert_t * 40.0)]
			return [mr, zoom_rect(), Vector2i(((c - vp * 0.5) * k * 4.0).round()), Vector2i((vp * k * 4.0).round()), al, snappedf(game.camera.zoom.x, 0.01), int(_zoom_alpha() * 40.0)]
		"groups":
			return [_vs(), _counts, bar.hit(m) if pc else -1, bar.sig()]
		"selection":
			if game.selection.is_empty():
				return [_vs(), 0]
			# (drawn again at every look while something is selected: its bars and lines move)
			var hv := -1
			if pc:
				for i in _portraits.size():
					if (_portraits[i]["rect"] as Rect2).has_point(m):
						hv = i
				for i in _queue_rects.size():
					if (_queue_rects[i]["rect"] as Rect2).has_point(m):
						hv = 100 + i
				var x := panel_rect()
				if Rect2(x.end.x - 30, x.position.y + 2, 28, 28).has_point(m):
					hv = 200
			return [_vs(), _tick_n, hv]
		"command card":
			var hv := -1
			if pc:
				for i in _card_buttons.size():
					if (_card_buttons[i]["rect"] as Rect2).has_point(m):
						hv = i
			return [_vs(), _card_look, hv, _card_flash_phase()]
		"glow":
			for b in _card_buttons:
				if String(b["item"][1]).begins_with("~ "):
					return [_tick_n]       # it breathes: every look
			return [_card_look]
		"rest":
			var br := controls.box_rect()
			var vals: Array = [_vs(), br, controls.mode, controls.cast_spell, controls.place_kind, controls.line_from, help_mode, paused, menu_open, game.demo and game.spectator == null,
				game.line_net.overlay_on, controls.line_tool.end if controls.line_tool != null else null, controls.line_tool.start if controls.line_tool != null else null]
			if _msg_t > 0.0:
				vals.append_array([_msg, int(minf(_msg_t, 1.0) * 60.0)])
			if game.spectating():
				vals.append_array([_tick_n, m, view_open, prod_open])
			if countdown > 0.0 or _go_t > 0.0:
				vals.append_array([countdown, _go_t])
			return vals
		"chat":
			if game.chat == null or (game.demo and game.replay == null):
				return []
			var now := Time.get_ticks_msec()
			var vl: Array = game.chat.visible(now)
			var ban := 0
			if now < _banner_until:
				ban = 1 + int(clampf(float(_banner_until - now) / 2000.0, 0.0, 1.0) * 10.0)
			return [_vs(), chat_typing, chat_buf, (now / 500) % 2 if chat_typing else 0, quick_open, ban, _banner,
				vl.map(func(x: Array) -> Array: return [x[0]["text"], int(float(x[1]) * 10.0)]), chat_log_rect(), paused]
		"tooltip":
			if _tip.is_empty() or paused or menu_open:
				return []
			return [_vs(), _tip.hash(), _tip_at]
		"pause":
			if not paused and not menu_open:
				return []
			var hv := -1
			var pbs := _menu_buttons() if menu_open else _paused_buttons()
			for i in pbs.size():
				if (pbs[i]["rect"] as Rect2).has_point(m):
					hv = i
			var ms: Array = []
			if menu_open and _music_shown():
				ms = music.sig()
				ms.append(music.rect.has_point(m) and m.x >= 0.0)
				ms.append(Vector2i(m / 4.0) if music.rect.has_point(m) else Vector2i.ZERO)
			var net_s: Array = [_pause_who(), int(game.net.pause_t), game.net.my_pauses()] if game.net else []
			return [_vs(), menu_open, paused, _confirm, countdown > 0.0, hv, pbs.map(func(b: Dictionary) -> String: return b["label"]), ms, net_s]
	return []


# ------------------------------------------------------------------ layout

func _vs() -> Vector2:
	return size


func top_rect() -> Rect2:
	return Rect2(0, 0, _vs().x, 36)


## Where everything sits comes from the chosen layout profile (Settings > Interface layout).
var _rects := {}
var _rects_frame := -1
var _rects_vs := Vector2.ZERO


func _layout() -> Dictionary:
	# (worked out again when the HUD's size changes, and twice a second for a changed setting)
	var f := Engine.get_process_frames()
	if f - _rects_frame > 30 or f < _rects_frame or _rects.is_empty() or _rects_vs != _vs():
		_rects_frame = f
		_rects_vs = _vs()
		var b := _btn()
		_rects = UiLayout.rects(_vs(), {
			"mini": mini_size(),
			"hotbar": HotkeyBar.size_hint(),
			"card": Vector2(b * _cols() + 4, b * _rows() + 4),
			"panel": Vector2(0, 88)})
	return _rects


## The minimap's size: MINI_W wide for a wide map; a square or tall map is at most
## MINI_H tall and narrower.
const MINI_H := 170.0


static func mini_size() -> Vector2:
	var h := MINI_W * float(Game.H) / float(Game.W)
	if h <= MINI_H:
		return Vector2(MINI_W, h)
	return Vector2(MINI_H * float(Game.W) / float(Game.H), MINI_H)


func mini_rect() -> Rect2:
	return _layout()["mini"]


## The command card is 4 x 3 everywhere (a phone used to have 3 x 2, and lost buttons).
func _cols() -> int:
	return 4


func _rows() -> int:
	return 3


func _btn() -> float:
	return CARD_BTN_PC if Settings.pc() else CARD_BTN


func card_rect() -> Rect2:
	return _layout()["card"]


func drag_rect() -> Rect2:
	return Rect2(_vs().x - 96 - 128, 2, 122, 32)


func panel_rect() -> Rect2:
	return _layout()["panel"]


func menu_rect() -> Rect2:
	return Rect2(_vs().x - 96, 2, 90, 32)


func _over_sandbox() -> bool:
	var hov := get_viewport().gui_get_hovered_control()
	while hov:
		if hov is SandboxPanel:
			return true
		hov = hov.get_parent() as Control
	return false


func _hud_has(p: Vector2) -> bool:
	if game.over and not game.map_view:
		return false        # the end screen takes the clicks
	if paused or menu_open or quick_open:
		return true
	if game.spectating() and (view_open or view_rect().has_point(p) or prod_rect().has_point(p)):
		return true         # (an open list takes the next press anywhere: it closes it)
	if _help_on() and help_rect().has_point(p):
		return true
	for r in [top_rect(), mini_rect(), panel_rect(), card_rect(), drag_rect()]:
		if (r as Rect2).has_point(p):
			return true
	return bar.rect().has_point(p)


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if game == null:
		return
	game.input_cmd = true          # (the player's own orders: online, with the same delay for both, they wait)
	_on_input(event)
	if is_instance_valid(game):
		game.input_cmd = false


func _on_input(event: InputEvent) -> void:
	if game == null or (game.over and not game.map_view):
		return
	if event is InputEventKey and _chat_input(event as InputEventKey):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE and menu_open:
		if _confirm != "":
			_confirm = ""
			_sig.erase("pause")
		else:
			toggle_menu(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_moved = true            # (the highlights follow the mouse; the rest waits for its look)
	else:
		_redraw_t = 0.0          # a click, a key or a touch: look at once
		_card_fresh = true
	# the sandbox panel lies over the HUD (the minimap, the top bar): its buttons take their
	# clicks first
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and _over_sandbox():
		return
	if ui_scale != 1.0 and (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouse):
		event = event.xformed_by(Transform2D().scaled(Vector2.ONE / ui_scale))
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if not Settings.pc() and not _tip.is_empty() and not help_mode:
				_tip = {}             # the next touch puts a tapped tooltip away (and does its job)
			if help_mode and _help_on() and not paused and not help_rect().has_point(e.position):
				_hud_touches[e.index] = true
				_help_tap(e.position)
				get_viewport().set_input_as_handled()
				return
			if not Settings.pc() and Settings.tooltips and not paused and not game.spectating():
				for pr in _pill_rects:          # phone: a tap on the supply pill shows the workers / army split
					if int(pr[1]) == 2 and (pr[0] as Rect2).has_point(e.position):
						_help_tap(e.position)
						get_viewport().set_input_as_handled()
						return
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
			game.smart_command(game.selected_units(), w, false, mb.shift_pressed)
			get_viewport().set_input_as_handled()
		elif _hud_has(mb.position) and mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not paused:
				for b in _all_buttons():
					if (b["rect"] as Rect2).has_point(mb.position) and b.has("alt"):
						(b["alt"] as Callable).call()
						Sfx.play_any(["ui/click", "click"])
						break
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Settings.pc() and _mouse_hud:
		var mm := event as InputEventMouseMotion
		if menu_open:
			_slide_drag(mm.position)
		elif mini_rect().has_point(mm.position):
			_minimap_to(mm.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _hud_touches.has(e.index):
			if menu_open:
				_slide_drag(e.position)
			elif mini_rect().has_point(e.position):
				_minimap_to(e.position)
			get_viewport().set_input_as_handled()


func _press(p: Vector2) -> void:
	if menu_open:
		_menu_press(p)
		return
	if game.over and not game.map_view:
		return
	if quick_open:
		_quick_press(p)
		return
	if paused:
		# paused, the menu closed: RESUME, and the top bar's MENU and chat buttons; the rest waits
		for b in _paused_buttons() + [{"rect": menu_rect(), "cb": func() -> void: toggle_menu(true), "enabled": true},
				{"rect": chat_btn_rect() if _chat_button_on() else Rect2(), "cb": func() -> void: quick_open = true, "enabled": true}]:
			if (b["rect"] as Rect2).has_point(p):
				if b.get("enabled", true):
					b["cb"].call()
					Sfx.play_any(["ui/click", "click"])
				elif b.has("why"):
					toast(b["why"])
				return
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
	if _help_on() and help_rect().has_point(p):
		help_mode = not help_mode
		_tip = {}
		Sfx.play_any(["ui/click", "click"])
		return
	if not Settings.pc() and drag_rect().has_point(p):
		Settings.drag_mode = "pan" if Settings.drag_mode == "box" else "box"
		Settings.save_all()
		toast("One-finger drag now %s." % ("moves the view" if Settings.drag_mode == "pan" else "box-selects"))
		return
	var hid := bar.hit(p)
	if hid >= 0:
		bar.press(hid)
		return
	for b in _all_buttons():
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
				if game and game.mlog and not game.demo:
					var pl: Dictionary = game.players[game.human]
					game.mlog.add("%s pressed %s: refused, %s (had %d %s, %d tension)" % [game.mlog.who(game.human), (String(b["item"][1]) if b.has("item") and (b["item"] as Array).size() > 1 else "a button"), String(b["why"]), int(pl["gold"]), _res()[0].to_lower(), int(float(pl.get("tension", 0.0)))])
			return


## A press while the menu is up: its buttons and sliders, the music player; anywhere off the panel closes it.
func _menu_press(p: Vector2) -> void:
	for b in _menu_buttons():
		if (b["rect"] as Rect2).has_point(p):
			if b.has("slider"):
				_slide(b, p)
			elif b.get("enabled", true):
				b["cb"].call()
				Sfx.play_any(["ui/click", "click"])
			elif b.has("why"):
				toast(b["why"])
			_sig.erase("pause")
			return
	if _music_shown():
		music.layout(_music_panel_rect())
		if music.press(p):
			_sig.erase("pause")
			return
	if not menu_panel_rect().has_point(p):
		toggle_menu(false)
		Sfx.play_any(["ui/back", "click"])


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
	bar.release(p)


func _minimap_to(p: Vector2) -> void:
	var m := mini_rect()
	var f := ((p - m.position) / m.size).clamp(Vector2.ZERO, Vector2.ONE)
	var w := f * Vector2(Game.W, Game.H) * Game.T
	if controls.mode in ["move", "attack"]:
		var q := Settings.pc() and Input.is_key_pressed(KEY_SHIFT)
		game.group_move(game.selected_units(), w, controls.mode == "attack", q)
		controls.cancel_mode()     # (closed even with Shift: a drag on the minimap would queue a flood)
		return
	if controls.mode == "bombard":
		game.bombard_order(game.selected_units(), w, Settings.pc() and Input.is_key_pressed(KEY_SHIFT))
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
	UiStyle.draw_button(_ci, pr, pr.has_point(_mouse()) and Settings.pc(), prod_open)
	_text(UiStyle.bold_font(), pr.get_center() + Vector2(0, 6), "PRODUCTION" + ("  ▲" if prod_open else "  ▼"), 15, UiStyle.TEXT, 1)
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
			var shq := NetPredict.shown_queue(game, b)
			var q: Array = shq[0]
			for i in q.size():
				var res := Building.is_research(q[i])
				var f := -1.0
				if i == 0 or b.uses_eggs():
					f = (float(b.morph_t[i]) if b.uses_eggs() and i < b.morph_t.size() else float(shq[2])) / Building.entry_time(q[i])
				items.append([_research_icon(String(q[i]).substr(1)) if res else (_queue_icon(b, i) if i < b.queue.size() else String(q[i])), f, Color(0.75, 0.55, 1.0) if res else Color(0.4, 0.75, 1.0)])
		var rows := maxi(1, int(ceil(items.size() / float(PER))))
		blocks.append([t, items])
		h += 22 + rows * (SZ + 10)
	UiStyle.draw_panel(_ci, Rect2(x0, y, w, h), UiStyle.accent(game.faction_of(maxi(game.view_team, 0))), 0.92)
	y += 8
	for bl in blocks:
		var t: int = bl[0]
		var items: Array = bl[1]
		_ci.draw_rect(Rect2(x0 + 10, y + 3, 10, 12), game.team_colour(t))
		_text(UiStyle.bold_font(), Vector2(x0 + 26, y + 14), "P%d %s" % [t + 1, Defs.FACTIONS[game.faction_of(t)]["name"]] + ("   (nothing in production)" if items.is_empty() else ""), 13, UiStyle.TEXT)
		y += 22
		for i in items.size():
			var it: Array = items[i]
			var r := Rect2(x0 + 10 + (i % PER) * (SZ + 4), y + (i / PER) * (SZ + 10), SZ, SZ)
			_ci.draw_rect(r, Color(0, 0, 0, 0.35))
			var ic := _icon(String(it[0]))
			if ic:
				_ci.draw_texture_rect(ic, r, false, Color.WHITE if float(it[1]) >= 0.0 else Color(1, 1, 1, 0.55))
			if float(it[1]) >= 0.0:
				_ci.draw_rect(Rect2(r.position.x, r.end.y + 2, SZ, 4), Color(0, 0, 0, 0.5))
				_ci.draw_rect(Rect2(r.position.x, r.end.y + 2, SZ * clampf(float(it[1]), 0.0, 1.0), 4), it[2])
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
	UiStyle.draw_button(_ci, r, r.has_point(hv), view_open)
	if sp.mode != "all":
		_ci.draw_rect(Rect2(r.position + Vector2(10, 10), Vector2(14, 14)), game.team_colour(sp.team))
	_text(UiStyle.bold_font(), r.get_center() + Vector2(6, 6), "VIEW: " + sp.label() + ("  ▲" if view_open else "  ▼"), 16, UiStyle.TEXT, 1)
	if not view_open:
		return
	var opts: Array = sp.options()
	var last := _view_row(opts.size() - 1)
	UiStyle.draw_panel(_ci, Rect2(r.position.x - 6, r.end.y + 1, r.size.x + 12, last.end.y - r.end.y + 6), UiStyle.accent(game.faction_of(game.human)), 0.96)
	for i in opts.size():
		var o: Array = opts[i]
		var rr := _view_row(i)
		var cur: bool = o[1] == sp.mode and (o[1] == "all" or int(o[2]) == sp.team)
		UiStyle.draw_button(_ci, rr, rr.has_point(hv) and o[3], cur, o[3])
		if o[1] != "all":
			_ci.draw_rect(Rect2(rr.position + Vector2(14, rr.size.y * 0.5 - 8), Vector2(16, 16)), game.team_colour(int(o[2])) if o[3] else Color(0.4, 0.4, 0.4))
		if cur:
			_ci.draw_circle(Vector2(rr.end.x - 20, rr.get_center().y), 6.0, Color(1, 0.85, 0.45))
		var key := ""
		if Settings.pc() and o[1] == "all":
			key = "[0] "
		elif Settings.pc() and o[1] == "follow" and int(o[2]) < 8:
			key = "[%d] " % (int(o[2]) + 1)
		_text(UiStyle.bold_font(), Vector2(rr.position.x + 42, rr.get_center().y + 7), key + String(o[0]) + ("  (out)" if not o[3] else ""), 19,
			(Color(1, 0.9, 0.55) if cur else UiStyle.TEXT) if o[3] else Color(1, 1, 1, 0.4))


# ------------------------------------------------------------------ command card

var _demolish_ms := 0
var _alt_for := {}             # card label -> its right-click / long-press action (auto-train)
var _alt_press := {}           # the card button being held on a phone: {b, t, done}
var _tip_for := {}             # card label -> [title, body] for its tooltip (refits)


func _build_card() -> Array:
	_alt_for = {}
	_tip_for = {}
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
		if Defs.BUILDINGS[k].get("gate", false):
			# gates turn to match the palisade they're laid in; this is the way they face
			# where it doesn't say (no line beside them, or lines both ways): remembered
			list.append(["ab_rotate", "ROTATE", func() -> void:
				game.gate_pref_vertical = not game.gate_pref_vertical
				var way := "north-south" if game.gate_pref_vertical else "east-west"
				if game.gate_facing(game.human, controls.ghost_cell, {}, game.gate_pref_vertical) == game.gate_pref_vertical:
					toast("Gates now face %s." % way)
				else:
					toast("Gates face %s off the palisade; this one follows its line." % way), true, "", ""])
		list.append(["cancel", "CANCEL", func() -> void: controls.cancel_mode(), true, "", ""])
		return list
	if controls.mode == "lay_line" and controls.line_tool != null:
		var lt := controls.line_tool
		list.append(["build", "LAY", func() -> void: lt.confirm(), lt.can_confirm(), lt.why_not(), lt.cost_text()])
		list.append(["cancel", "CANCEL", func() -> void: controls.cancel_mode(), true, "", ""])
		return list
	if controls.mode != "":
		if controls.mode == "unload":
			# let them off right below the balloon, wherever it is
			list.append(["ab_unload", "DROP HERE", func() -> void:
				game.unload_order(game.selected_units(), Vector2.ZERO, true)
				controls.cancel_mode(), true, "", ""])
		list.append(["cancel", "CANCEL", func() -> void: controls.cancel_mode(), true, "", ""])
		return list
	if not units.is_empty():
		var has_lab := units.any(func(u: Unit) -> bool: return u.is_worker() or u.kind == "work_car")
		if page in ["build", "advanced"] and has_lab:
			# every building on one card (more pages if they don't fit)
			var all: Array = Defs.build_list(game.faction_of(game.human))
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
				elif game.tension_problem(game.human, Defs.tension_cost(d)) != "":
					why = game.tension_problem(game.human, Defs.tension_cost(d))      # (a Tension price: the Clock Aviary)
				elif Defs.is_econ(k) and game.econ_count(game.human, k) >= game.econ_limit(game.human, k):
					why = "Limit reached: one Brood Pen per Burrow; raise another Burrow." if game.faction_of(game.human) == "brood" else "Limit reached: expand with another %s." % Defs.BUILDINGS[game.faction_hall(game.human)]["name"]
				var kk: String = k
				var label: String = d["name"].to_upper()
				if Defs.is_econ(k):
					if k == "feeding_pit" and game.faction_of(game.human) == "brood":
						label = "%s %d" % [label.split(" ")[0], game.econ_count(game.human, k)]      # (no count cap: the swamp's reach limits it)
					else:
						label = "%s %d/%d" % [label.split(" ")[0], game.econ_count(game.human, k), game.econ_limit(game.human, k)]
				list.append([k, label, func() -> void:
					page = ""
					controls.begin_place(kk), why == "", why, _price_chip([int(d["cost"]), Defs.tension_cost(d)], Defs.tension_cost(d) > 0)])
			if pages > 1:
				list.append(["more", "MORE", func() -> void: build_page = (build_page + 1) % pages, true, "", ""])
			list.append(["back", "BACK", func() -> void:
				page = ""
				build_page = 0, true, "", ""])
			return list
		if units.all(func(u: Unit) -> bool: return u.kind == "horse"):
			return list          # (a horse takes no orders: a leash or a rider moves it)
		list.append(["move", "MOVE", func() -> void: controls.mode = "move", true, "", ""])
		list.append(["attack", "ATTACK", func() -> void: controls.mode = "attack", true, "", ""])
		list.append(["stop", "STOP", func() -> void: game.command_all(game.selected_units(), "stop"), true, "", ""])
		if not units.all(func(u: Unit) -> bool: return u.is_worker() or u.kind == "horse"):
			list.append(["patrol", "PATROL", func() -> void: controls.mode = "patrol", true, "", ""])
		if units.any(func(u: Unit) -> bool: return u.can_ground_attack()):
			# ATTACK GROUND (Ctrl+A): attack a spot, or a dragged line, until another order (Defs.BOMBARD, Defs.GROUND)
			_tip_for["ATTACK GROUND"] = ["Attack ground", CMD_TIPS["ATTACK GROUND"]]
			list.append(["ab_bombard", "ATTACK GROUND", func() -> void: controls.begin_bombard(), true, "", ""])
		if has_lab and not BroodNew.on(game, game.human):      # (the new Brood builds nothing)
			# workers don't need HOLD: two build pages instead, basic and advanced
			list.append(["build", "BUILD", func() -> void:
				page = "build"
				build_page = 0, true, "", ""])
			_balloon_buttons(list, units)     # labourers can ride too
			_ballista_buttons(list, units)    # Winders BOARD a Spring Ballista as its crew
			if Defs.line_mode and units.any(func(u: Unit) -> bool: return u.kind == "winder" or u.kind == "work_car"):
				list.append(["build", "LINE", func() -> void: controls.begin_line(), true, "", str(int(Defs.LINE["pipe"]["cost"])) + "/seg"])
				list.append(["gauge", ("~ " if game.line_net.overlay_on else "") + "PRESSURE", func() -> void:
					game.line_net.overlay_on = not game.line_net.overlay_on
					game.line_net.redraw(), true, "", ""])
			var fixers := units.filter(func(u: Unit) -> bool: return u.d.get("repairs", false) or u.kind == "labourer")
			if not fixers.is_empty():
				# a tap: pick what to repair; right-click / long press: automatic repair (glows)
				var auto_fix: bool = fixers.all(func(u: Unit) -> bool: return u.auto_repair)
				_alt_for["REPAIR"] = func() -> void:
					for u in game.selected_units():
						if u.d.get("repairs", false) or u.kind == "labourer":
							game.net_set(u, "auto_repair", not auto_fix)
					toast("Automatic repair on: idle workers fix damaged buildings nearby by themselves, before going back to work." if not auto_fix else "Automatic repair off.")
				list.append(["repair", ("~ " if auto_fix else "") + "REPAIR", func() -> void:
					controls.mode = "repair"
					toast("Tap a damaged building (or wall) to repair it."), true, "", ""])

		else:
			_ability_buttons(list, units)
			if Defs.line_mode and Defs.rail_econ and game.faction_of(game.human) == "clockwork" and game.line_net.rails.count(game.human, "troop") > 0 \
					and units.any(func(u: Unit) -> bool: return not u.is_air() and u.kind != "horse"):
				list.append(["build", "RIDE", func() -> void:
					controls.mode = "ride"
					toast("Tap a spot beside the Line: a Troop Train picks them up and takes them there."), true, "", ""])
			list.append(["hold", "HOLD", func() -> void: game.command_all(game.selected_units(), "hold"), true, "", ""])
			_refit_buttons(list, units)
		if Defs.cw_roster:
			CwUnits.card(self, list, units)       # the experimental Clockwork roster's buttons
		_horse_buttons(list, units)
		if has_lab:
			var gatherers := units.filter(func(u: Unit) -> bool: return u.can_gather())
			if not gatherers.is_empty():
				# WORK is automatic: idle workers go back to work on their own. Press it to
				# switch that off (to scout or to keep a builder free), and again to switch it on.
				var auto: bool = gatherers.all(func(u: Unit) -> bool: return u.auto_work)
				list.append(["work", ("~ " if auto else "") + "WORK", func() -> void:
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
			var has_pen := game.offer_place(offer[0].position, game.human) != null
			var ess := 0
			for u in offer:
				ess += Game.sacrifice_value(u.kind)
			list.append(["ab_sacrifice", "SACRIFICE", func() -> void:
				var n := 0
				for u in game.selected_units():
					if u.can_sacrifice():
						u.cmd_sacrifice()
						n += 1
				toast("%d offered up: they go to the nearest Brood Pen (+%d essence)." % [n, ess]), has_pen, "Needs a Brood Pen." if not BroodNew.on(game, game.human) else "Needs the Brood Mother.", "+%d" % ess])
		_nb_buttons(list, units)          # (the new Brood: the Mother's eggs, ROOT / UPROOT / HAUL)
		for dk in ["cannon", "mortar", "tesla_cart", "spore_mother"]:
			var kk: String = dk
			if units.any(func(u: Unit) -> bool: return u.kind == kk):
				var packed := units.any(func(u: Unit) -> bool: return u.kind == kk and u.tesla_mode == "packed")
				var lab: String = {"cannon": "UNLIMBER" if packed else "LIMBER", "spore_mother": "ROOT" if packed else "UPROOT"}.get(kk, "DEPLOY" if packed else "PACK")
				list.insert(3, [{"cannon": "ab_limber", "spore_mother": "ab_root", "mortar": "ab_mortar_deploy"}.get(kk, "ab_deploy"), lab, func() -> void:
					for u in game.selected_units():
						if u.kind == kk:
							if packed:
								u.cmd_deploy()
							else:
								u.cmd_pack(), true, "", ""])
		_shift_queueable(list)
		return list
	if b == null:
		var mixed := game.selected_mixed()
		if not mixed.is_empty():
			return _mixed_card(mixed)
	if b and b.built and b.kind == "gate":
		var was_locked: bool = b.locked
		list.append(["unlock" if was_locked else "lock", "UNLOCK" if was_locked else "LOCK", func() -> void:
			var why := ""
			for sb in game.selected_buildings():
				if sb.kind == "gate" and sb.built and not sb.dead:
					var w: String = game.set_gate_locked(sb, not was_locked)
					if w != "":
						why = w
			if why != "":
				toast(why)
			else:
				toast("Gate unlocked: your units pass again." if was_locked else "Gate locked: nobody can pass, yours included, until you unlock it."), true, "", ""])
	if b and not b.built:
		# a gate can be turned only while it is not built yet (a ghost or a site); once built it stays
		if b.kind == "gate":
			list.append(["ab_rotate", "ROTATE", func() -> void:
				var v := not b.vertical
				for sb in game.selected_buildings():
					if sb.kind == "gate" and not sb.built and not sb.dead:
						sb.dir_locked = true
						sb.set_vertical(v)
				toast("Gate turned. It stays this way."), true, "", ""])
		list.append(["stop", "ABANDON", func() -> void:
			for sb in game.selected_buildings():
				game.abandon(sb), true, "", ""])
		return list
	if b and b.built and not b.dead and Defs.gear_mode and b.d["faction"] == "clockwork" and b.kind != "clocktower" and b.team == game.human \
			and not GearNet.big_only(b.kind):
		# GEAR SWAP: the button offers the other size of connecting gear (a small cost in cogs, a few seconds)
		var to_big: bool = not (b.gear_swap_to if b.gear_swap_t >= 0.0 else b.gear_big)
		var glab := "BIG GEAR" if to_big else "SMALL GEAR"
		var gwhy := game.gear_swap_problem(b)
		var trade := GearEcon.trade_line(b.kind, to_big)      # (SIZE SETS THE TEMPO: what this kind trades)
		_tip_for[glab] = [("Swap to the BIG gear" if to_big else "Swap to the SMALL gear"),
			Loc.t("Big gear: turns slow and works heavy and strong; a bigger ring that reaches farther." if to_big
				else "Small gear: turns fast and works quick and light; a smaller ring.") + (" " + trade if trade != "" else ""),
			"%d cogs  ·  %d s" % [int(Defs.GEAR["swap_cost"]), int(Defs.GEAR["swap_time"])]]
		list.append(["ab_gear_big" if to_big else "ab_gear_small", glab, func() -> void:
			var w := ""
			for sb in game.selected_buildings():
				if sb.team == game.human and game.gear_swap_problem(sb) == "":
					w = game.swap_gear(sb)
					if w != "":
						break
			if w != "":
				toast(w)
			else:
				toast("Swapping the gear: the building idles for a few seconds."), gwhy == "", gwhy, str(int(Defs.GEAR["swap_cost"]))])
	if b and Defs.gear_mode and b.d["faction"] == "clockwork" and not b.dead and (b.team == game.human or game.demo or game.spectating()):
		# THE GEAR VIEW (also the ` key): the whole network at a glance (scripts/gear.gd); phone-friendly
		_tip_for["GEAR VIEW"] = ["Gear view", "Shows the whole gear network: the drivers glow gold, every ring is tinted by how well it works (green full speed, yellow 90%, orange 80%, red 70% or idle), each Mainspring's reach is outlined and the turrets' circles are drawn. Key: `"]
		list.append(["ab_gear_view", ("~ " if game.gear_net.view else "") + "GEAR VIEW", func() -> void: game.toggle_gear_view(), true, "", ""])
	if b and b.built and b.kind != game.faction_hall(game.human):
		list.append(["demolish", "DEMOLISH", func() -> void:
			if Time.get_ticks_msec() - _demolish_ms > 2500:
				_demolish_ms = Time.get_ticks_msec()
				toast("Press DEMOLISH again to pull it down.")
				return
			for sb in game.selected_buildings():
				game.demolish(sb), true, "", ""])
	if b and b.built and b.is_leveled() and not b.next_level().is_empty():
		# the Brood's hall grows: Burrow -> Warren -> Broodmound (it keeps working meanwhile)
		var nl := b.next_level()
		if b.upgrade_t >= 0.0:
			_tip_for["STOP UPGRADE"] = ["Stop growing into a %s" % nl["name"], "Stop the upgrade: all of its price is paid back."]
			list.append(["cancel", "STOP UPGRADE", func() -> void:
				game.cancel_hall_upgrade(b)
				toast("Upgrade to %s cancelled: paid back." % nl["name"]), true, "", ""])
		else:
			var uwhy := game.hall_upgrade_problem(b)
			var ulab := String(nl["label"])
			_tip_for[ulab] = ["Upgrade to %s" % nl["name"], String(nl["about"]),
				"%s  ·  %d s" % [_cost_text(int(nl["cost"]), int(nl.get("cost2", 0))), int(nl["time"])]]
			list.append([String(nl["art"]) if _icon(String(nl["art"])) != null else "hive", ulab, func() -> void:
				var w := game.start_hall_upgrade(b)
				toast(w if w != "" else "Your %s is growing into a %s." % [b.d["name"], nl["name"]]), uwhy == "", uwhy, str(nl["cost"])])
	if b and b.built:
		_research_buttons(list, b)
		if Defs.line_mode and b.kind == game.faction_hall(game.human) and Defs.rail_econ and game.faction_of(game.human) == "clockwork":
			for tk in ["ore", "troop"]:
				var tkk: String = tk
				var twhy: String = game.line_net.rails.buy_problem(game.human, tkk, b)
				_tip_for[String(Defs.TRAINS[tk]["name"]).to_upper()] = [String(Defs.TRAINS[tk]["name"]), "Runs on the Line's rails: " + ("carries ore from the Drills to the Clocktower; it follows the pressure and is a target for the enemy." if tk == "ore" else "RIDE soldiers along the Line, fast; it is a target, and they climb out hurt if it is lost."), "%d  ·  %d/%d" % [int(Defs.TRAINS[tk]["cost"]), game.line_net.rails.count(game.human, tkk), game.line_net.rails.count(game.human)]]
				list.append(["build", String(Defs.TRAINS[tk]["name"]).to_upper(), func() -> void:
					var w: String = game.buy_train(game.human, tkk)
					if w != "":
						toast(w), twhy == "", twhy, str(Defs.TRAINS[tk]["cost"])])
		# (a soldier with a light and an armoured version: two buttons once Armour is researched)
		for k in Defs.train_keys(b.d["trains"], game.has_tech(game.human, "armour")):
			var kk: String = k
			var why := game.can_train(b, k)
			for sb in game.selected_buildings():
				if game.can_train(sb, k) == "":
					why = ""
			var ulab: String = Defs.train_name(k).to_upper()
			# right-click (computer) or a long press (phone): keep training it automatically
			_alt_for[ulab] = func() -> void:
				var on := b.auto_train != kk
				for sb in game.selected_buildings():
					game.net_set(sb, "auto_train", kk if on else "")
				toast(("Training %s automatically." % Defs.train_name(kk)) if on else "Automatic training off.")
			if b.auto_train == k:
				ulab = "~ " + ulab
			list.append([k, ulab, func() -> void:
				var w := game.train_any(game.selected_buildings(), kk)
				if w != "":
					toast(w), why == "", why, _price_chip(game.unit_price(game.human, k), Defs.tension_cost(Defs.UNITS[Defs.train_kind(k)]) > 0)])
		if b.dual_rally():
			list.append(["rally", "RALLY", func() -> void: controls.mode = "rally_army", true, "", ""])
			list.append(["feeding_pit", "GRUBS", func() -> void: controls.mode = "rally_worker", true, "", ""])
		elif not b.d["trains"].is_empty():
			list.append(["rally", "RALLY", func() -> void: controls.mode = "rally", true, "", ""])
		if not b.queue.is_empty():
			list.append(["cancel", "CANCEL", func() -> void:
				var last: String = b.queue.back() if not b.queue.is_empty() else ""
				game.cancel_train(b)
				if Building.is_research(last):
					toast("%s research cancelled: paid back." % Defs.RESEARCH[last.substr(1)]["name"]), true, "", ""])
		if Defs.REFIT_AT.has(b.kind) and game.has_refits(game.human):
			# (once there's something to refit with)
			_auto_refit_button(list, game.selected_buildings().filter(func(x: Building) -> bool: return Defs.REFIT_AT.has(x.kind) and x.built))
	return list


## The research buttons of a finished building (what it can still research).
func _research_buttons(list: Array, b: Building, group: Array = []) -> void:
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
		# (several of the same kind selected: it goes to the one that can start it with the shortest queue)
		var at: Building = b
		var rwhy := game.research_problem(b, rk)
		for gb in group:
			if is_instance_valid(gb) and not gb.dead and gb.built and gb.kind == b.kind:
				var w2 := game.research_problem(gb, rk)
				if w2 == "" and (rwhy != "" or gb.queue.size() < at.queue.size()):
					at = gb
					rwhy = ""
		var lab: String = Defs.research_label(rk)
		var target: Building = at
		list.append([_research_icon(rk), lab, func() -> void:
			var w := game.start_research(target, rkk)
			if w != "":
				toast(w), rwhy == "", rwhy, _price_chip([int(info["cost"]), Defs.tension_cost(info)], Defs.tension_cost(info) > 0)])


## The icon of a queued unit: a soldier's light or armoured picture, by what he was paid for.
func _queue_icon(b: Building, i: int) -> String:
	var k := String(b.queue[i])
	return Defs.train_key(k, bool(b.kit_at(i).get("armour", false)))


## A research's icon (assets/icons/<icon>.png); without one, the unit it's for.
func _research_icon(key: String) -> String:
	var info: Dictionary = Defs.RESEARCH[key]
	var ric: String = info.get("icon", info.get("unlocks", "musketeer"))
	if _icon(ric) == null:
		ric = info.get("unlocks", "musketeer")
	return ric


## Soldiers selected (Musketeers, Horsemen): a REFIT button for each upgrade researched that
## some of them still lack (ARMOUR; for Musketeers the best lock researched, which skips the
## ones between, and the SOCKET BAYONET). Each man who needs it pays its fee and walks to the
## nearest Barracks, Armoury or Powder Wagon to get it.
## Powder Wagons selected: their AUTO REFIT toggle.
func _refit_buttons(list: Array, units: Array) -> void:
	var men := units.filter(func(u: Unit) -> bool: return Defs.ARMOURED.has(u.kind))
	var whats: Array = []
	if game.has_tech(game.human, "armour"):
		whats.append("armour")
	if game.best_lock(game.human) != "":
		whats.append(game.best_lock(game.human))
	if game.has_tech(game.human, "bayonet"):
		whats.append("bayonet")
	if game.has_tech(game.human, "pouch"):
		whats.append("pouch")
	for w in whats:
		var ww: String = w
		var need := men.filter(func(u: Unit) -> bool: return game.refit_options(u).has(ww))
		if need.is_empty():
			continue          # they all have it (or are on their way for it)
		var fee := Game.refit_fee(ww, need[0].kind)
		var res := _res()
		var why := ""
		if int(game.players[game.human]["gold"]) < fee[0]:
			why = "Not enough %s." % String(res[0]).to_lower()
		elif float(game.players[game.human]["res2"]) < fee[1]:
			why = "Not enough %s." % String(res[1]).to_lower()
		elif game.refit_place(game.human, need[0].position) == null:
			why = "Needs a Barracks, an Armoury or a Powder Wagon to refit at."
		var info: Dictionary = Defs.RESEARCH[ww]
		var lab := Defs.research_label(ww)
		var price := "%d %s" % [fee[0], String(res[0]).to_lower()] + (" + %d %s" % [fee[1], String(res[1]).to_lower()] if fee[1] > 0 else "")
		var what := "reload %d%% faster than a plain musket" % int(round((1.0 - float(info.get("reload", 1.0))) * 100.0))
		if ww == "armour":
			var kinds := {}
			for u in need:
				kinds[u.kind] = true
			var parts: Array = []
			for kd in kinds:
				var ai: Dictionary = Defs.ARMOURED[kd]
				var f := Game.refit_fee("armour", kd)
				parts.append("%s: +%d armour, +%d health (%s)" % [ai["name"], int(ai["armor"]), int(ai["hp"]), _cost_text(f[0], f[1])])
			what = "armour (" + "; ".join(parts) + ")"
			if kinds.size() > 1:
				price = "by kind"
		elif ww == "bayonet":
			what = "the socket bayonet (+%d bayonet damage, thrusts %d%% faster)" % [int(info["damage"]), int(round((1.0 - float(info["cooldown"])) * 100.0))]
		elif ww == "pouch":
			what = "the shot pouch (%d shots instead of %d; he fills it at any powder source)" % [int(Defs.POWDER["pouch"]), int(Defs.POWDER["musketeer"])]
		_tip_for[lab] = ["Refit: %s   (%s a man)" % [info["name"], price],
			"%d of them lack it: each pays, walks to the nearest Barracks, Armoury or Powder Wagon and gets %s there (%d s). Another order calls it off, paid back." % [need.size(), what, int(Defs.REFIT["time"])]]
		list.append([_research_icon(ww), lab, func() -> void:
			if Settings.pc() and Input.is_key_pressed(KEY_SHIFT):
				# Shift: each man goes for it after the orders he has now (the fee is paid then)
				for m in game.selected_units():
					if Defs.ARMOURED.has(m.kind):
						m.give({"o": "act", "fn": func(u: Unit) -> void: game.refit_order([u], ww, true)}, true)
				toast("Queued: they get refitted after their current orders (%s)." % info["name"])
				return
			var r := game.refit_order(game.selected_units(), ww)
			if int(r[0]) > 0:
				toast("%d soldier%s off to be refitted: %s." % [r[0], "" if r[0] == 1 else "s", info["name"]] + ("  " + String(r[1]) if r[1] != "" else ""))
			elif r[1] != "":
				toast(r[1]), why == "", why, str(fee[0]) + ("+%d" % fee[1] if fee[1] > 0 else "")])
	var wagons := units.filter(func(u: Unit) -> bool: return u.kind == "powder_wagon")
	if not wagons.is_empty() and not whats.is_empty():
		_auto_refit_button(list, wagons)     # (once there's something to refit with)


## AUTO REFIT on Barracks, Armouries or Powder Wagons (glowing = on): idle soldiers within a
## few tiles of one get the upgrades researched that they lack, paying the fees if they can.
func _auto_refit_button(list: Array, places: Array) -> void:
	if places.is_empty():
		return
	var on: bool = places.all(func(p) -> bool: return p.auto_refit)
	_tip_for["AUTO REFIT"] = ["Auto refit (glowing = on)", "Idle soldiers within %d tiles of it get the upgrades researched that they lack, each paying the fee (if you can afford it)." % int(Defs.REFIT["auto"])]
	list.append(["ab_auto_refit", ("~ " if on else "") + "AUTO REFIT", func() -> void:
		for p in places:
			if is_instance_valid(p) and not p.dead:
				game.net_set(p, "auto_refit", not on)
		toast("Auto refit on: idle soldiers nearby get their upgrades here, paying the fees." if not on else "Auto refit off."), true, "", ""])


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
	var low: bool = balloons.any(func(u: Unit) -> bool: return u.powder < u._pmax)
	list.append(["ab_restock", "RESTOCK", func() -> void:
		var sent := 0
		for u in game.selected_units():
			if u.kind == "balloon" and u.powder < u._pmax and u.cmd_restock():
				sent += 1
		toast("Flying to the nearest powder: the pilot hauls kegs up on a rope until the store is full." if sent > 0 else "No Powder Wagon, Mill, Barracks or Town Hall to restock from."), low, "The powder store is full.", ""])


## The Spring Ballista's crew (scripts/ballista.gd): with Ballistas selected, LOAD CREW (the Winders selected with them climb
## on at once; otherwise tap the Winders to take) and UNLOAD CREW (they step off where they stand); with Winders selected,
## BOARD (they crew the nearest of your Ballistas with room). The corner shows the crew (the built-in man not counted).
func _ballista_buttons(list: Array, units: Array) -> void:
	var bals := units.filter(func(u: Unit) -> bool: return u.kind == Defs.BALLISTA_KIND)
	if not bals.is_empty():
		var n := 0
		var cap := 0
		for b in bals:
			n += Ballista.crew_of(b).size()
			cap += int(Defs.BALLISTA["crew"])
		var count := "%d/%d" % [n, cap]
		var room: bool = bals.any(func(u: Unit) -> bool: return u.room() > 0)
		list.append(["ab_crew", "LOAD CREW", func() -> void:
			var sel := game.selected_units()
			var bs := sel.filter(func(u: Unit) -> bool: return u.kind == Defs.BALLISTA_KIND)
			var men := sel.filter(func(u: Unit) -> bool: return bs.any(func(b: Unit) -> bool: return u.can_board(b)))
			if not men.is_empty():
				game.load_order(men, bs)
				toast("The Winders walk over and take their places: each pushes and cranks.")
			else:
				controls.mode = "load"
				toast("Tap the Winders to take on as crew."), room, "The crew is full.", count])
		list.append(["ab_unload", "UNLOAD CREW", func() -> void:
			game.unload_order(game.selected_units(), Vector2.ZERO, true), n > 0, "No crew aboard (only its own man).", count])
		return
	var winders := units.filter(func(u: Unit) -> bool: return u.kind == "winder")
	if winders.is_empty():
		return
	var mine: Array = game.units.filter(func(u: Unit) -> bool: return u.kind == Defs.BALLISTA_KIND and u.team == game.human and not u.dead)
	if mine.is_empty():
		return
	var free: bool = mine.any(func(b: Unit) -> bool: return b.room() > 0)
	list.append(["ab_crew", "BOARD", func() -> void:
		var ws := game.selected_units().filter(func(u: Unit) -> bool: return u.kind == "winder")
		if ws.is_empty():
			return
		var c := Vector2.ZERO
		for w in ws:
			c += w.position
		c /= ws.size()
		var bs: Array = game.units.filter(func(u: Unit) -> bool: return u.kind == Defs.BALLISTA_KIND and u.team == game.human and not u.dead and u.room() > 0)
		bs.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(c) < b.position.distance_squared_to(c))
		game.load_order(ws, bs)
		toast("They crew your nearest Spring Ballista."), free, "Every Ballista's crew is full.", ""])


## Left edge of the i-th of n passenger icons on a balloon's card (top right, clear of the
## close button).
func _pass_icon_x(r: Rect2, n: int, i: int) -> float:
	return r.end.x - 36.0 - (n - i) * 25.0


## Crown abilities for the selected soldiers. Each button switches all of that kind.
## THE NEW BROOD (scripts/brood_new.gd): the Mother lays an egg for each creature (the warriors need the father near
## her); she and the Rootmaws ROOT and UPROOT; a Rootmaw HAULs its food.
func _nb_buttons(list: Array, units: Array) -> void:
	var q: Unit = null
	for u in units:
		if u.kind == BroodNew.QUEEN and u.team == game.human:
			q = u
	if q != null:
		for k in BroodNew.hatch_list():
			var kk: String = k
			var why := BroodNew.lay_problem(game, q, kk)
			list.append([kk, Defs.train_name(kk).to_upper(), func() -> void:
				var w := ""
				for u in game.selected_units():
					if u.kind == BroodNew.QUEEN and u.team == game.human:
						w = u.cmd_lay(kk)
				if w != "":
					toast(w), why == "", why, _price_chip(game.unit_price(game.human, kk), false)])
		# GROW (her next stage) and what raises her laying (the levers: her stage, fathers near her, expansions)
		var st := BroodNew.stage(q)
		var stages: Array = Defs.NB["stages"]
		if st < stages.size() - 1:
			var nx: Dictionary = stages[st + 1]
			var gwhy := BroodNew.grow_problem(game, q)
			_tip_for["GROW"] = ["Grow (stage %d)" % (st + 2), "She grows bigger: up to %d eggs, laying %d%% faster (stage x%.1f), but a bigger, slower target with a wider swamp. Rooted only; %d s, and she lays no eggs meanwhile (uprooting stops it and pays it back). %s" % [
				int(nx["eggs"]), int(round((float(nx["rate"]) / float(stages[st]["rate"]) - 1.0) * 100.0)), float(nx["rate"]), int(nx["time"]),
				"Unlocks the second father, when one exists: nothing yet." if st == 0 else "Unlocks the third father, when one exists: nothing yet."]]
			list.append(["broodmound", "GROW", func() -> void:
				for u in game.selected_units():
					if u.kind == BroodNew.QUEEN and u.team == game.human:
						var w2: String = u.cmd_grow()
						if w2 != "":
							toast(w2), gwhy == "", gwhy, _price_chip([int(nx["cost"]), int(nx["cost2"])], int(nx["cost2"]) > 0)])
		var lev := BroodNew.levers_text(game, q)
		_tip_for[lev.to_upper()] = ["Her laying", "%s. Three things make the Brood Mother lay faster, and they add up: her growth STAGE; every FATHER near her (as in some real lizards, the males' presence speeds the female's eggs: +%d%% each); every Mound Turtle rooted on NEW GROUND, %d tiles or more from her and from the other counted ones (their chimneys pump scent into the swamp water: she tastes new territory and lays more: +%d%% each, up to %d). Turtles at home give supply and swamp only." % [
			lev, int(float(Defs.NB["father_rate"]) * 100.0), int(Defs.NB["expansion_tiles"]), int(float(Defs.NB["expansion_rate"]) * 100.0), int(Defs.NB["expansion_max"])]]
		list.append(["brood_mother", lev.to_upper(), func() -> void: pass, false, lev, ""])
	var rooters := units.filter(func(u: Unit) -> bool: return BroodNew.ROOTERS.has(u.kind) and u.team == game.human)
	if rooters.is_empty():
		return
	var packed := rooters.any(func(u: Unit) -> bool: return u.tesla_mode == "packed")
	if packed:
		_tip_for["ROOT"] = ["Root", "Dig in here: armour and a quarter less damage, swamp around it. A Rootmaw drinks its ground (5-tile circle, may not overlap another's); a Mound Turtle sinks into the mud and gives 12 supply and faster eggs; the Tyrannosaur settles on his nest (near the Mother, her warrior eggs are fertilised and hatch in it). They always root facing south-east. The Brood Mother cannot attack while rooted."]
		list.insert(3, ["ab_nb_root", "ROOT", func() -> void:
			for u in game.selected_units():
				if BroodNew.ROOTERS.has(u.kind) and u.tesla_mode == "packed":
					u.cmd_deploy(), true, "", ""])
	else:
		_tip_for["UPROOT"] = ["Uproot", "Pull up the roots and walk. A Rootmaw spills its food as a pile on the ground (grubs still collect it; it rots slowly) and walks off thin and quick."]
		list.insert(3, ["ab_uproot", "UPROOT", func() -> void:
			for u in game.selected_units():
				if BroodNew.ROOTERS.has(u.kind) and u.tesla_mode == "deployed":
					u.cmd_uproot(true), true, "", ""])
		if rooters.any(func(u: Unit) -> bool: return u.kind == BroodNew.MAW and u.tesla_mode == "deployed"):
			_tip_for["HAUL"] = ["Haul", "Uproot the Rootmaw full: it walks at half speed carrying its food and keeps it when it roots again. Killed while hauling, all of it bursts out as a pile."]
			list.insert(4, ["ab_haul", "HAUL", func() -> void:
				for u in game.selected_units():
					if u.kind == BroodNew.MAW and u.tesla_mode == "deployed":
						u.cmd_uproot(false), true, "", ""])


func _ability_buttons(list: Array, units: Array) -> void:
	_balloon_buttons(list, units)
	_ballista_buttons(list, units)
	GreatWinder.card(self, list, units)     # a Great Winder's MEND and SWEEP autocasts (scripts/great_winder.gd)
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
	# Springer: JUMP (a spot): every selected Springer that can leaps there (Springer.jump_order); the corner shows the spring's wind-back
	var springers := units.filter(func(u: Unit) -> bool: return u.kind == Defs.SPRINGER)
	if not springers.is_empty():
		var ready_n: int = springers.filter(func(u: Unit) -> bool: return Springer.ready_problem(u) == "").size()
		var jwhy := "" if ready_n > 0 else Springer.ready_problem(springers[0])
		var cdl := INF
		for u in springers:
			if ready_n == 0 and u.jump.is_empty():
				cdl = minf(cdl, u.jump_cd)          # (none ready: the soonest one's wind-back)
		if cdl == INF:
			cdl = 0.0
		var up := game.has_tech(game.human, "high_leap")
		_tip_for["JUMP"] = ["Jump", "Tap where: after a short crouch the Springer leaps up to %d tiles along an arc (each Springer selected, to its own spot of the group). Flat ground and down a cliff any time; %s Not onto water, cliffs or buildings. It cannot shoot in the air; the spring winds back in %d s." % [
			int(round(float(Defs.SPRINGER_JUMP["range"]) / Defs.TILE)),
			"UP onto high ground too, where you can see (HIGH LEAP)." if up else "UP onto high ground once HIGH LEAP is researched at the Escapement (and only where you can see).",
			int(Defs.SPRINGER_JUMP["cooldown"])]]
		list.append(["ab_jump", "JUMP", func() -> void:
			controls.mode = "cast"
			controls.cast_spell = "jump", ready_n > 0, jwhy, ("%ds" % int(ceil(cdl))) if ready_n == 0 and cdl > 0.0 else ""])
	# Swift: MORPH TO OWL (each selected Swift that can, paying for itself: CwAir.morph_order) and, while any of them is
	# turning into an Owl, CANCEL MORPH (paid back)
	var swifts := units.filter(func(u: Unit) -> bool: return u.kind == Defs.CUCKOO)
	if not swifts.is_empty():
		var idle: Array = swifts.filter(func(u: Unit) -> bool: return u.owl_t < 0.0)
		if not idle.is_empty():
			var mwhy := ""
			for u in idle:
				mwhy = CwAir.morph_problem(u)
				if mwhy == "":
					break
			var m: Dictionary = Defs.OWL_MORPH
			_tip_for["MORPH TO OWL"] = ["Morph to Owl", "Each Swift selected is rebuilt into a Ticking Owl: a heavy, slow flyer that swoops on units with its talons and bombs buildings (it cannot hit flyers). It hovers in place and cannot fight while it morphs; CANCEL MORPH pays it back." if game.has_tech(game.human, "owl_morph")
				else "Each Swift selected is rebuilt into a Ticking Owl: a heavy, slow flyer that swoops on units with its talons and bombs buildings (it cannot hit flyers). It hovers in place and cannot fight while it morphs. Needs TICKING OWL, researched at a Clock Aviary.",
				"%d cogs + %d tension  ·  %d s  ·  +%d supply" % [int(m["cost"]), int(m["tension"]), int(m["time"]), int(Defs.UNITS[Defs.OWL]["supply"]) - int(Defs.UNITS[Defs.CUCKOO]["supply"])]]
			list.append(["ab_morph_owl", "MORPH TO OWL", func() -> void:
				var w := game.morph_order(game.selected_units())
				if w != "":
					toast(w), mwhy == "", mwhy, "%d+%d" % [int(m["cost"]), int(m["tension"])]])
		if swifts.any(func(u: Unit) -> bool: return u.owl_t >= 0.0):
			_tip_for["CANCEL MORPH"] = ["Cancel the morph", "The Swifts turning into Ticking Owls stop and stay Swifts: everything paid comes back."]
			list.append(["cancel", "CANCEL MORPH", func() -> void: game.cancel_morph(game.selected_units()), true, "", ""])
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
	# HOLD FIRE for every Crown firearm (muskets, pistols, guns, the balloon's basket): glowing
	# = on: they never open fire by themselves, only on what you order them to ATTACK (the
	# cavalry keep their pistol shot even then); bayonets and sabres still fight. One button
	# for the whole selection.
	var firearms := units.filter(func(u: Unit) -> bool: return u.team == game.human and u.has_gun())
	if not firearms.is_empty():
		var held: bool = firearms.all(func(u: Unit) -> bool: return u.hold_fire)
		var only_pistols: bool = firearms.all(func(u: Unit) -> bool: return u.has_pistol())
		list.append(["hold_fire" if held else "fire_at_will", ("~ " if held else "") + "HOLD FIRE", func() -> void:
			for u in game.selected_units():
				u.set_hold_fire(not held)
			if only_pistols:
				toast("Hold fire: they keep their pistols loaded." if not held else "Pistols free: they fire by themselves.")
			else:
				toast("Hold fire: they shoot only at what you order them to attack." if not held else "Fire at will: they shoot by themselves."), true, "", ""])
	var sacs := units.filter(func(u: Unit) -> bool: return u.kind == "bloater")
	if not sacs.is_empty():
		var hold: bool = sacs.any(func(u: Unit) -> bool: return u.mode != "hold")
		list.append(["ab_hold_gas" if hold else "ab_spit", "HOLD GAS" if hold else "SPIT", func() -> void:     # (SPIT: its own picture)
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
					game.net_set(u, "courier", not cour)
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
	# Clock Soldier: SHIELD FORWARD, once SHIELD WALL is researched at a Light Works (scripts/shield_wall.gd)
	var csold := units.filter(func(u: Unit) -> bool: return u.kind == ShieldWall.KIND)
	if not csold.is_empty() and game.has_tech(game.human, ShieldWall.TECH):
		var raise: bool = csold.any(func(u: Unit) -> bool: return not u.shield_up)
		var sw: Dictionary = Defs.SHIELD_WALL
		_tip_for["SHIELD FORWARD"] = ["Shield forward", "The Clock Soldiers raise their shields in front (%.1f s to switch, standing still): %d%% slower, +%d armour, %d%% less from shots and %d%% less from blows coming from the front; they still fight, a little slower. Nothing against blows from the side or behind, nor against splash. Press again to lower the shields." % [
			float(sw["switch"]), int(round((1.0 - float(sw["speed"])) * 100.0)), int(sw["armor"]), int(round(float(sw["front"]) * 100.0)), int(round(float(sw["front_melee"]) * 100.0))]]
		list.append(["ab_shield", "SHIELD FORWARD" if raise else "~ SHIELD FORWARD", func() -> void:
			for u in game.selected_units():
				if u.kind == ShieldWall.KIND:
					u.set_shield(raise), true, "", ""])
	# Skywing: LAND (ground fighter) / TAKE OFF (hunts flyers)
	var wings := units.filter(func(u: Unit) -> bool: return u.kind == "skywing")
	if not wings.is_empty():
		var flying: bool = wings.any(func(u: Unit) -> bool: return u.sky == "air" or u.sky == "to_land")
		list.append(["ab_land" if flying else "ab_take_off", "LAND" if flying else "TAKE OFF", func() -> void:
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
			toast("The Town Hall's haulers bring kegs from the Powder Mill while the wagon has room." if not sup else "Supply off: no more keg runs."), true, "", ""])
	# TEAM: how many horses a gun or wagon keeps (0 to 4; haulers bring the spares), one press more
	var teamed := units.filter(func(u: Unit) -> bool: return Defs.HARNESSED.has(u.kind))
	if not teamed.is_empty():
		var nxt: int = (int(teamed[0].team_want) + 1) % (int(Defs.HORSES["team_max"]) + 1)
		list.append(["horse_team", "TEAM", func() -> void:
			for u in game.selected_units():
				if Defs.HARNESSED.has(u.kind):
					u.team_want = nxt
			toast("Keeps %d horse%s: the Town Hall's haulers bring spares." % [nxt, "" if nxt == 1 else "s"] if nxt > 0 else "Keeps no spare horses."), true, "", ""])
	var guns := units.filter(func(u: Unit) -> bool: return u.kind == "cannon")
	if not guns.is_empty():
		var can: bool = guns.any(func(u: Unit) -> bool: return u.mode != "canister")
		list.append(["ab_canister" if can else "ab_round_shot", "CANISTER" if can else "ROUND SHOT", func() -> void:
			for u in game.selected_units():
				if u.kind == "cannon":
					u.set_canister(can), true, "", ""])


## Letter hotkeys for the command card (computer). Common commands keep fixed letters,
## everything else takes the first free letter of its name.
const FIXED_KEYS := {"MOVE": "V", "ATTACK": "A", "STOP": "S", "HOLD": "H", "PATROL": "P", "BUILD": "B", "ADVANCED": "V", "WORK": "G",
	"DEPLOY": "D", "PACK": "D", "RALLY": "R", "REPAIR": "R", "ROTATE": "R", "GRUBS": "F", "CANCEL": "X", "BACK": "X", "ABANDON": "X", "DEMOLISH": "Z", "MORE": "T", "PLACE": "F",
	"CANISTER": "C", "ROUND SHOT": "C",
	"UNLIMBER": "D", "LIMBER": "D", "ROOT": "D", "UPROOT": "D", "STORM": "T", "MIASMA": "Q", "FOG": "F", "TONGUE": "T", "HOLD GAS": "F", "SPIT": "F", "HARVEST": "Q", "SACRIFICE": "C", "START": "F", "END": "F",
	"JUMP": "E", "HIGH LEAP": "E", "MORPH TO OWL": "E", "CANCEL MORPH": "X", "TICKING OWL": "E",
	"LOAD": "F", "UNLOAD": "G", "DROP HERE": "G", "RESTOCK": "E", "COURIER": "C", "OVERLOAD": "V", "BRACE": "E", "SHIELD FORWARD": "F", "LAND": "D", "TAKE OFF": "D", "SUPPLY": "G",
	"ARMOUR": "E", "MATCHLOCK": "F", "FLINTLOCK": "F", "CAPLOCK": "F", "BAYONET": "W", "AUTO REFIT": "Q", "POUCH": "T",
	"LEAD": "Q", "RELEASE": "W", "MOUNT": "T", "DISMOUNT": "T", "RELEASE HORSE": "W", "HARNESS": "Q",
	"HOLD FIRE": "F",
	"SIDING": "N", "COUPLE": "C", "UNCOUPLE": "U", "CREW OUT": "O", "CREW IN": "I", "PLATES": "E", "SET UP": "D", "BOARD": "G", "THUNDER": "T", "DOCK": "Q", "CARRY": "F"}
## Keys the left hand reaches without leaving the group numbers: names only take letters
## from here (H for HOLD is the one fixed key outside it).
const NEAR_KEYS := "QWERTASDFGZXCVB"
## Command keys that never move: everything else gives way to them.
## Standard keys for some units on their building's card (workers S, Musketeers A; at the
## Barracks the light and armoured pairs: Musketeer A, Guardsman S, Horseman D, Cuirassier C,
## Dragoon F, Armoured Dragoon V, Officer G, Armoured Officer B).
const UNIT_KEYS := {"labourer": "S", "grub": "S", "winder": "S", "musketeer": "A", "guardsman": "S",
	"horseman": "D", "cuirassier": "C", "dragoon": "F", "armoured_dragoon": "V",
	"dismounted": "G", "dismounted_cuirassier": "B",
	"clocktower": "T", "cog_press": "C", "movement_works": "L", "heavy_works": "H",     # (Light Works L, Heavy Works H)     # (owner, 2026-10-27: the Cog Press's G looked like a C in the font, and C built a Clocktower)
	"tin_militia": "A", "scrapper": "D", "rail_rifleman": "F", "work_car": "S", "plate_wagon": "A", "heavy_loco": "D", "carrier_car": "F", "tesla_loco": "G", "storm_engine": "B"}
const MUST_KEYS := ["ATTACK", "STOP", "HOLD", "BUILD", "REPAIR", "CANCEL", "BACK", "ABANDON"]
## Commands on a Ctrl key (computer): the hint shows it, and they take no letter (A stays ATTACK).
const CTRL_KEYS := {"ATTACK GROUND": "^A"}


## The id a card item is known by for hotkeys: a command name or a unit/building kind.


## Several kinds of production building selected (MAKE): every unit any of them trains,
## each going to the least busy building that can train it. Long press / right-click
## switches automatic training on all of them that can.
## Buildings of different kinds selected together (4 Barracks and an Armoury, a Hall and a
## Barracks...): everything they can do on one card. Each unit goes to the selected building
## that can train it and has the shortest queue (so four Barracks show a Musketeer once),
## each research to the Armoury (or whichever) that offers it; RALLY goes to all that train,
## CANCEL takes the last order of the busiest one. If it doesn't fit, _paged adds MORE (Tab).
func _mixed_card(bs: Array) -> Array:
	var list: Array = []
	var built := bs.filter(func(x: Building) -> bool: return x.built)
	var kinds: Array = []
	for sb in built:
		for k in Defs.train_keys(sb.d["trains"], game.has_tech(game.human, "armour")):
			if not kinds.has(k):
				kinds.append(k)
	for k in kinds:
		var kk: String = k
		var why := "Can't train that here."
		var able: Array = []
		for sb in built:
			if (sb.d["trains"] as Array).has(Defs.train_kind(kk)):
				able.append(sb)
				var w := game.can_train(sb, kk)
				if w == "":
					why = ""
				elif why != "":
					why = w
		var ulab: String = Defs.train_name(kk).to_upper()
		var auto_all := able.all(func(x: Building) -> bool: return x.auto_train == kk)
		_alt_for[ulab] = func() -> void:
			for sb in able:
				if is_instance_valid(sb):
					game.net_set(sb, "auto_train", "" if auto_all else kk)
			toast(("Training %s automatically in every building that can." % Defs.train_name(kk)) if not auto_all else "Automatic training off.")
		if able.any(func(x: Building) -> bool: return x.auto_train == kk):
			ulab = "~ " + ulab
		list.append([kk, ulab, func() -> void:
			var w := game.train_any(able, kk)
			if w != "":
				toast(w), why == "", why, _price_chip(game.unit_price(game.human, kk), Defs.tension_cost(Defs.UNITS[Defs.train_kind(kk)]) > 0)])
	var seen := {}
	for sb in built:
		if not seen.has(sb.kind):
			seen[sb.kind] = true
			_research_buttons(list, sb, built)
	if built.any(func(x: Building) -> bool: return not (x.d["trains"] as Array).is_empty()):
		list.append(["rally", "RALLY", func() -> void: controls.mode = "rally", true, "", ""])
	var busy := built.filter(func(x: Building) -> bool: return not x.queue.is_empty())
	if not busy.is_empty():
		list.append(["cancel", "CANCEL", func() -> void:
			var best: Building = null
			for x in game.selected_mixed():
				if is_instance_valid(x) and not x.dead and not x.queue.is_empty() and (best == null or x.queue.size() > best.queue.size()):
					best = x
			if best:
				game.cancel_train(best), true, "", ""])
	var refitters := built.filter(func(x: Building) -> bool: return Defs.REFIT_AT.has(x.kind))
	if not refitters.is_empty() and game.has_refits(game.human):
		_auto_refit_button(list, refitters)
	if bs.any(func(x: Building) -> bool: return not x.built):
		list.append(["stop", "ABANDON", func() -> void:
			for sb in game.selected_mixed():
				if not sb.built:
					game.abandon(sb), true, "", ""])
	if bs.any(func(x: Building) -> bool: return x.built and x.kind != game.faction_hall(game.human)):
		list.append(["demolish", "DEMOLISH", func() -> void:
			if Time.get_ticks_msec() - _demolish_ms > 2500:
				_demolish_ms = Time.get_ticks_msec()
				toast("Press DEMOLISH again to pull it down.")
				return
			for sb in game.selected_mixed():
				if sb.built and sb.kind != game.faction_hall(game.human):
					game.demolish(sb), true, "", ""])
	return list


static func key_id(it: Array) -> String:
	var lab: String = String(it[1]).trim_prefix("> ").trim_prefix("~ ")
	if FIXED_KEYS.has(lab):
		return lab
	if Defs.UNITS.has(it[0]) or Defs.BUILDINGS.has(it[0]) or Defs.TRAIN_AS.has(it[0]):
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
	var named := func(it: Array) -> bool: return Defs.UNITS.has(it[0]) or Defs.BUILDINGS.has(it[0]) or Defs.TRAIN_AS.has(it[0])
	# 1. the player's own keys and the must-have command keys (A attack, S stop, H hold, ...)
	for i in items.size():
		var own := UiLayout.key_for(key_id(items[i]))
		var lab: String = lab_of.call(items[i])
		if own == "" and CTRL_KEYS.has(lab):
			chosen[i] = String(CTRL_KEYS[lab])
			continue
		var k: String = own if own != "" else (String(FIXED_KEYS[lab]) if MUST_KEYS.has(lab) else String(UNIT_KEYS.get(String(items[i][0]), "")))
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
				if Defs.TRAIN_AS.has(it[0]):
					name = Defs.train_name(it[0]).to_upper()
				elif Defs.UNITS.has(it[0]):
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
func hotkey(code: int, repeat := false) -> bool:
	if paused or menu_open or game.over:
		return false
	if code == KEY_ESCAPE and view_open:
		view_open = false
		return true
	if (code == KEY_ESCAPE or code == KEY_BACKSPACE) and controls.mode == "" and page != "":
		page = ""
		return true
	if code == KEY_TAB:
		# Tab flips the command card's pages (the same as its MORE button)
		for it in _card_items:
			if String(it[1]) == "MORE" and it[3]:
				it[2].call()
				_card_fresh = true
				flash_card("MORE")
				Sfx.play_any(["ui/click", "click"])
				return true
		return false
	var letter := OS.get_keycode_string(code)
	if letter.length() != 1:
		return false
	for it in _card_items:
		if it.size() > 6 and it[6] == letter:
			flash_card(String(it[1]).trim_prefix("> ").trim_prefix("~ "))
			if repeat and not Defs.UNITS.has(String(it[0])):
				return false          # (only training repeats while a key is held)
			if it[3]:
				it[2].call()
				Sfx.play_any(["ui/click", "click"])
			elif it[4] != "":
				toast(it[4])
			return true
	return false


## A command card button reacts to its hotkey like a pressed button (drawn pushed in for a moment).
var _card_flash := ""
var _card_flash_ms := 0


func flash_card(label: String) -> void:
	_card_flash = label
	_card_flash_ms = Time.get_ticks_msec()
	_card_fresh = true


## 0 when no card button is pushed in; else a number that changes every 45 ms while it is.
func _card_flash_phase() -> int:
	if _card_flash == "":
		return 0
	var age := Time.get_ticks_msec() - _card_flash_ms
	if age >= 140:
		_card_flash = ""
		return 0
	return 1 + age / 45


## A building the player tried to place and was refused, in the match log with what he had then (owner's playtest
## 2026-10-27, 0.14.82: "I had enough cogs but I couldn't build": the log said nothing about it).
func _log_refused(k: String, why: String) -> void:
	if game.mlog == null:
		return
	var pl: Dictionary = game.players[game.human]
	var line := "%s could not place a %s: %s (had %d %s" % [game.mlog.who(game.human), String(Defs.BUILDINGS[k]["name"]), why, int(pl["gold"]), _res()[0].to_lower()]
	if Defs.tension_cost(Defs.BUILDINGS[k]) > 0 or (game.faction_of(game.human) == "clockwork" and Defs.gear_mode):
		line += ", %d tension" % int(float(pl.get("tension", 0.0)))
	game.mlog.add(line + ")")


## queued (Shift on a computer): the site goes in the builders' order queue, after what
## they already have to do (several Shift-placed buildings are built one after another).
func confirm_place(queued := false) -> void:
	queued = queued and Settings.pc()
	var k := controls.place_kind
	if Defs.BUILDINGS.has(k) and Defs.BUILDINGS[k].get("line", false):
		_confirm_line(k, queued)
		return
	var why := game.placement_problem(game.human, k, controls.ghost_cell)
	if why != "":
		toast(why)
		_log_refused(k, why)
		Sfx.announce(game.faction_of(game.human), "bad_place", 4.0)
		return
	if game.players[game.human]["gold"] < int(Defs.BUILDINGS[k]["cost"]):
		toast("Not enough %s." % _res()[0].to_lower())
		_log_refused(k, "not enough %s: it costs %d" % [_res()[0].to_lower(), int(Defs.BUILDINGS[k]["cost"])])
		return
	if game.tension_problem(game.human, Defs.tension_cost(Defs.BUILDINGS[k])) != "":
		toast(game.tension_problem(game.human, Defs.tension_cost(Defs.BUILDINGS[k])))
		_log_refused(k, game.tension_problem(game.human, Defs.tension_cost(Defs.BUILDINGS[k])))
		return
	var builders := game.selected_units().filter(func(u: Unit) -> bool: return u.is_worker() or u.kind == "work_car")
	var brood := game.faction_of(game.human) == "brood"
	if queued and brood:
		# a grub becomes its building, so each queued site takes a grub that has none yet
		builders = builders.filter(func(u: Unit) -> bool: return not u.build_pending())
		if builders.is_empty() and not game.selected_units().is_empty():
			toast("Each grub becomes one building: every selected grub already has one.")
			return
	# Crown: every selected labourer builds it together; a grub becomes the building, so
	# one (and a Clockwork site takes one Winder: Game.place_building)
	if brood:
		builders.sort_custom(func(a: Unit, c: Unit) -> bool:
			var g := Vector2(controls.ghost_cell) * Defs.TILE
			var pa: Vector2 = a.plan_end() if queued else a.position
			var pc: Vector2 = c.plan_end() if queued else c.position
			return pa.distance_to(g) < pc.distance_to(g))
		builders = builders.slice(0, 1)
	var b := game.place_building(game.human, k, controls.ghost_cell, builders, queued)
	if b:
		Sfx.play_any(["ui/click", "click"])
	controls.cancel_mode()


## Walls and gates go down in a line: the first PLACE marks the start, the second the end.
func _confirm_line(k: String, queued := false) -> void:
	if controls.line_from.x < 0:
		var why := game.placement_problem(game.human, k, controls.ghost_cell)
		if why != "":
			toast(why)
			return
		controls.line_from = controls.ghost_cell
		toast("Now pick where it ends (the same spot for a single piece).")
		return
	var builders := game.selected_units().filter(func(u: Unit) -> bool: return u.is_worker())
	var n := game.place_line(game.human, k, controls.line_from, controls.ghost_cell, builders, queued)
	if n > 0:
		Sfx.play_any(["ui/click", "click"])
	else:
		toast("Nothing could be placed there.")
	controls.cancel_mode()


# ------------------------------------------------------------------ menu and pause
## MENU (top right) opens the menu over the match, which runs on behind it: PAUSE / RESUME, the volume sliders, the
## music player (MenuMusic: NEXT and every piece to pick), SURRENDER and QUIT TO MENU (online both asked twice),
## BACK. PAUSE stops the match; online either player can pause, for both (NetSession: PAUSES each, PAUSE_MAX seconds
## at most, then a 3-2-1). While paused, with the menu closed, a small panel says so (online: who) with RESUME.

var menu_open := false
var _confirm := ""                  # the menu asks first: "surrender" or "quit"
var music := MenuMusic.new()
const MENU_W := 320.0
const MUSIC_W := 300.0


func toggle_menu(open: bool) -> void:
	menu_open = open
	_confirm = ""
	if open:
		close_chat()
		quick_open = false
		help_mode = false
	_sig.erase("pause")
	_redraw_t = 0.0


## The music player has a column of its own beside the buttons when the screen is wide enough.
func _music_shown() -> bool:
	return _vs().x >= MENU_W + MUSIC_W + 100.0 and _confirm == ""


func _menu_list() -> Array:
	if _confirm != "":
		var yes := "YES, SURRENDER" if _confirm == "surrender" else "YES, LEAVE"
		return [
			{"label": yes, "bad": true, "cb": func() -> void:
				var what := _confirm
				toggle_menu(false)
				if what == "surrender":
					game.player_surrender()
				else:
					set_paused(false)
					quit_requested.emit()},
			{"label": "NO", "cb": func() -> void:
				_confirm = ""
				_sig.erase("pause")},
		]
	var list: Array = [_pause_item(),
		{"label": "MUSIC", "slider": "music", "cb": func() -> void: pass},
		{"label": "SOUND", "slider": "sound", "cb": func() -> void: pass},
		{"label": "AMBIENCE", "slider": "ambience", "cb": func() -> void: pass},
		{"label": "MINIMAP", "slider": "minimap", "cb": func() -> void: pass},
		{"label": "SURRENDER", "bad": true, "cb": func() -> void:
			_confirm = "surrender"
			_sig.erase("pause")},
		{"label": "QUIT TO MENU", "cb": func() -> void:
			if _online() and not game.over:
				_confirm = "quit"          # (online: leaving ends it for the friend too, or hands your side to a computer)
				_sig.erase("pause")
				return
			toggle_menu(false)
			set_paused(false)
			quit_requested.emit()},
		{"label": "BACK TO THE MATCH", "cb": func() -> void: toggle_menu(false)},
	]
	if game.demo or game.over:
		list = list.filter(func(b: Dictionary) -> bool: return b["label"] != "SURRENDER")    # watching computers: nobody of yours to surrender
	if game.replay:
		list = list.filter(func(b: Dictionary) -> bool: return not String(b["label"]).begins_with("PAUSE"))    # (a replay: its own bar pauses)
	return list


## An online match (not a replay, whose session stands in for the host's: game.replay).
func _online() -> bool:
	return game != null and game.net != null and game.replay == null


## PAUSE (RESUME when paused). Online: how many pauses are left, and nothing to resume while the host is away.
func _pause_item() -> Dictionary:
	var net: NetSession = game.net if _online() else null
	if paused:
		var it := {"label": "RESUME", "cb": func() -> void: set_paused(false)}
		if net and net.away:
			it["enabled"] = false
			it["why"] = "The host's game is in the background: the match goes on when it is back."
		return it
	var label := "PAUSE"
	var it2 := {"label": label, "cb": func() -> void: set_paused(true)}
	if net:
		it2["label"] = "PAUSE  (%d LEFT)" % net.my_pauses()
		if net.my_pauses() <= 0:
			it2["enabled"] = false
			it2["why"] = "No pauses left."
	return it2


func _menu_pitch(n: int) -> float:
	# (the panel is 92 + n * pitch + 10 tall: on a phone held sideways the old 150 / 46 left
	# BACK TO THE MATCH under the bottom edge)
	return clampf((_vs().y - 116.0) / float(maxi(n, 1)), 40.0, 66.0)


## The whole menu panel (the music column too, when there is room).
func menu_panel_rect() -> Rect2:
	var vs := _vs()
	var n := _menu_list().size()
	var h := 92.0 + n * _menu_pitch(n) + 10.0
	if _confirm != "":
		h += 60.0
	var w := MENU_W + 40.0 + (MUSIC_W + 16.0 if _music_shown() else 0.0)
	return Rect2(vs.x * 0.5 - w * 0.5, maxf(6.0, vs.y * 0.5 - h * 0.5), w, h)


## The menu's buttons, with their rects (the left column).
func _menu_buttons() -> Array:
	var list := _menu_list()
	var pr := menu_panel_rect()
	var pitch := _menu_pitch(list.size())
	var y0 := pr.position.y + 92.0 + (60.0 if _confirm != "" else 0.0)
	for b in list:
		if b.has("slider"):
			b["label"] = "%s  %d%%" % [String(b["label"]).split("  ")[0], int(round(_slider_value(b["slider"]) * 100.0))]
	for i in list.size():
		list[i]["rect"] = Rect2(pr.position.x + 20.0, y0 + i * pitch, MENU_W, pitch - 8.0)
	return list


func _music_panel_rect() -> Rect2:
	var pr := menu_panel_rect()
	return Rect2(pr.position.x + 20.0 + MENU_W + 16.0, pr.position.y + 84.0, MUSIC_W, pr.size.y - 84.0 - 12.0)


## The panel while paused with the menu closed: who paused, RESUME.
func _paused_rect() -> Rect2:
	var vs := _vs()
	return Rect2(vs.x * 0.5 - 210.0, maxf(top_rect().end.y + 70.0, vs.y * 0.2), 420.0, 178.0)


func _paused_buttons() -> Array:
	var r := _paused_rect()
	var it := _pause_item()
	it["rect"] = Rect2(r.get_center().x - 120.0, r.end.y - 66.0, 240.0, 52.0)
	return [it]


## Who paused, for the panels ("Paused by Pink"); "" in a match on this machine.
func _pause_who() -> String:
	return game.net.pause_text() if game.net else ""


func _slider_value(which: String) -> float:
	return Settings.mini_alpha if which == "minimap" else Music.me.get_volume(which)


func _slider_set(which: String, v: float) -> void:
	if which == "minimap":
		Settings.mini_alpha = clampf(v, 0.2, 1.0)
		Settings.save_all()
	else:
		Music.me.set_volume(which, v)


## A pause-menu volume bar: where you press along it is the level (drag to slide).
func _slide(b: Dictionary, p: Vector2) -> void:
	var r: Rect2 = b["rect"]
	_slider_set(b["slider"], snappedf((p.x - r.position.x - 14.0) / (r.size.x - 28.0), 0.05))
	_redraw_t = 0.0


func _slide_drag(p: Vector2) -> void:
	if not menu_open:
		return
	for b in _menu_buttons():
		if b.has("slider") and (b["rect"] as Rect2).grow_individual(0, 6, 0, 6).has_point(p):
			_slide(b, p)


# ------------------------------------------------------------------ chat

var chat_typing := false         # computer: the one-line box is open (every key goes to it)
var chat_buf := ""
var quick_open := false          # phone: the quick-chat panel
var _banner := ""
var _banner_until := 0


const BANNER_SECS := 15.0


## A small banner under the top bar ("P1 Crown says gg: reply gg to end the match").
func chat_banner(text: String) -> void:
	_banner = text
	_banner_until = Time.get_ticks_msec() + int(BANNER_SECS * 1000.0)


func _chat_button_on() -> bool:
	return not Settings.pc() and not game.demo and not game.spectating()


## The speech-bubble button of the phone, left of the DRAG / ? buttons (next to the menu).
func chat_btn_rect() -> Rect2:
	var x := help_rect().position.x if _help_on() else drag_rect().position.x
	return Rect2(x - 46, 2, 40, 32)


func _draw_bubble(c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-12, -9), c + Vector2(12, -9), c + Vector2(12, 5), c + Vector2(2, 5), c + Vector2(-6, 11), c + Vector2(-5, 5), c + Vector2(-12, 5)])
	_ci.draw_colored_polygon(pts, col)
	for i in 3:
		_ci.draw_circle(c + Vector2(-6 + i * 6, -2), 1.8, Color(0.1, 0.08, 0.06))


func chat_row_h() -> float:
	return 20.0 if Settings.pc() else 24.0


func chat_font_size() -> int:
	return 15 if Settings.pc() else 17


## Where the log sits: at the bottom left of the screen if that is free, else just above the
## parts of the HUD that stand there (the minimap, the quick buttons ...), else under the top
## bar; it never covers the HUD's own parts (the owner's layout decides where those are).
## The last row is the typing box.
func chat_log_rect() -> Rect2:
	var w := 340.0 if Settings.pc() else 380.0
	var h := chat_row_h() * Chat.VISIBLE_LINES + chat_row_h() + 10.0
	var vs := _vs()
	var l := _layout()
	var parts: Array = []
	for k in ["mini", "hotbar", "panel", "card"]:
		parts.append((l[k] as Rect2).grow(4))
	var m := UiLayout.M
	var cands: Array = [Rect2(m, vs.y - m - h, w, h)]
	var top := vs.y - m
	for r in parts:
		if (r as Rect2).position.x < m + w and (r as Rect2).end.x > m:
			top = minf(top, (r as Rect2).position.y)
	cands.append(Rect2(m, top - 4 - h, w, h))
	cands.append(Rect2(m, UiLayout.TOP, w, h))
	for c in cands:
		var r: Rect2 = c
		if r.position.y < UiLayout.TOP - 0.5:
			continue
		if parts.any(func(p: Rect2) -> bool: return p.intersects(r)):
			continue
		return r
	return cands[1]


func _open_chat() -> void:
	chat_typing = true
	chat_buf = ""
	game.chat.reveal()
	_redraw_t = 0.0


func close_chat() -> void:
	chat_typing = false
	chat_buf = ""
	_redraw_t = 0.0


## A key while the HUD may be typing. True if it was used (a typing box swallows every key, so
## no hotkey fires and the letters do not select anything).
func _chat_input(ke: InputEventKey) -> bool:
	if not Settings.pc() or game.demo or game.chat == null:
		return false
	if not chat_typing:
		if ke.pressed and not ke.echo and (ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER) \
				and not ke.alt_pressed and not ke.ctrl_pressed and not ke.meta_pressed \
				and not menu_open and (countdown <= 0.0 or paused or game.net != null) and not game.spectating():
			_open_chat()           # (online, paused or counting down: a word to the other player still goes)
			return true
		return false
	if not ke.pressed:
		return true
	if menu_open:
		close_chat()
		return false
	match ke.keycode:
		KEY_ESCAPE:
			close_chat()
		KEY_ENTER, KEY_KP_ENTER:
			var text := chat_buf
			close_chat()
			if text.strip_edges() != "":
				game.chat.player_say(text)
			game.chat.reveal()
		KEY_BACKSPACE:
			chat_buf = chat_buf.substr(0, chat_buf.length() - 1)
		_:
			if (ke.ctrl_pressed or ke.meta_pressed) and ke.keycode == KEY_V:
				chat_buf = (chat_buf + DisplayServer.clipboard_get().split("\n")[0]).substr(0, Chat.MAX_LEN)
			elif ke.unicode >= 32 and ke.unicode != 127 and not ke.ctrl_pressed and not ke.meta_pressed and chat_buf.length() < Chat.MAX_LEN:
				chat_buf += String.chr(ke.unicode)
	_redraw_t = 0.0
	return true


## The phone's quick-chat panel: 3 x 2 big buttons in the middle of the screen.
func quick_rects() -> Array:
	var bw := 128.0
	var bh := 62.0
	var gap := 8.0
	var vs := _vs()
	var origin := Vector2(vs.x * 0.5 - (bw * 3 + gap * 2) * 0.5, vs.y * 0.5 - (bh * 2 + gap) * 0.5 + 6)
	var out: Array = []
	for i in Chat.QUICK.size():
		out.append(Rect2(origin + Vector2((i % 3) * (bw + gap), (i / 3) * (bh + gap)), Vector2(bw, bh)))
	return out


func quick_panel_rect() -> Rect2:
	var rs := quick_rects()
	return (rs[0] as Rect2).merge(rs[rs.size() - 1]).grow_individual(14, 44, 14, 14)


func _quick_press(p: Vector2) -> void:
	var rs := quick_rects()
	for i in rs.size():
		if (rs[i] as Rect2).has_point(p):
			quick_open = false
			game.chat.player_say(String(Chat.QUICK[i][1]))
			game.chat.reveal()
			Sfx.play_any(["ui/click", "click"])
			return
	if not quick_panel_rect().has_point(p) or chat_btn_rect().has_point(p):
		quick_open = false
		Sfx.play_any(["ui/back", "click"])


func _draw_chat() -> void:
	if game.chat == null or (game.demo and game.replay == null):
		return
	var font := UiStyle.bold_font()
	var now := Time.get_ticks_msec()
	var fs := chat_font_size()
	var rh := chat_row_h()
	var box := chat_log_rect()
	# the log: the newest line at the bottom, just above the typing row
	var vl: Array = game.chat.visible(now)
	var bottom := box.end.y - rh - 6.0
	if not vl.is_empty():
		var top := bottom - rh * vl.size() - 2.0
		var wmax := 0.0
		for e in vl:
			var l: Dictionary = e[0]
			wmax = maxf(wmax, font.get_string_size("%s: %s" % [l["name"], l["text"]], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var panel := Rect2(box.position.x, top, minf(box.size.x, wmax + 20.0), bottom - top + 4.0)
		var amax := 0.0
		for e in vl:
			amax = maxf(amax, float(e[1]))
		_ci.draw_rect(panel, Color(0.04, 0.035, 0.03, 0.55 * amax))
		for i in vl.size():
			var l: Dictionary = vl[i][0]
			var a: float = vl[i][1]
			var y := top + rh * (i + 1) - 4.0
			var nm := "%s: " % l["name"]
			var col: Color = game.team_colour(int(l["team"])).lightened(0.25)
			col.a = a
			_text(font, Vector2(panel.position.x + 10 + 1, y + 1), nm, fs, Color(0, 0, 0, 0.7 * a))
			_text(font, Vector2(panel.position.x + 10, y), nm, fs, col)
			var nw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_text(font, Vector2(panel.position.x + 10 + nw + 1, y + 1), l["text"], fs, Color(0, 0, 0, 0.7 * a))
			_text(font, Vector2(panel.position.x + 10 + nw, y), l["text"], fs, Color(1, 0.97, 0.9, a))
	# the typing box (computer)
	if chat_typing:
		var r := Rect2(box.position.x, box.end.y - rh - 2.0, box.size.x, rh + 2.0)
		var sb := UiStyle.box(Color(0.09, 0.075, 0.06, 0.92), UiStyle.TRIM, 2, 6, 0.0)
		sb.draw(_ci.get_canvas_item(), r)
		var mine: Color = game.team_colour(game.human).lightened(0.25)
		_text(font, r.position + Vector2(8, rh - 4), "YOU:", fs, mine)
		var pre := font.get_string_size("YOU: ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if chat_buf == "":
			_text(font, r.position + Vector2(8 + pre, rh - 4), "type, Enter sends, Esc cancels", fs - 2, Color(1, 1, 1, 0.4))
		else:
			_text(font, r.position + Vector2(8 + pre, rh - 4), chat_buf, fs, Color(1, 0.97, 0.9))
		if (now / 500) % 2 == 0:
			var cw := font.get_string_size(chat_buf, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_ci.draw_rect(Rect2(r.position.x + 8 + pre + cw + 1, r.position.y + 4, 2, rh - 6), Color(1, 0.97, 0.9))
	# the banner for a computer's gg
	if now < _banner_until:
		var a := clampf(float(_banner_until - now) / 2000.0, 0.0, 1.0)
		var vs := _vs()
		var bw := font.get_string_size(_banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28
		var br := Rect2(vs.x * 0.5 - bw * 0.5, 124.0, bw, 28.0)
		var bsb := UiStyle.box(Color(0.1, 0.08, 0.06, 0.8 * a), Color(0.79, 0.64, 0.29, 0.5 * a), 1, 14, 0.0)
		bsb.draw(_ci.get_canvas_item(), br)
		_text(font, Vector2(vs.x * 0.5, br.position.y + 19), _banner, 16, Color(1, 0.88, 0.6, a), 1)
	# the phone's quick-chat panel
	if quick_open:
		var vs := _vs()
		_ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.25))
		var pr := quick_panel_rect()
		UiStyle.draw_panel(_ci, pr, UiStyle.accent(game.faction_of(game.human)), 0.95)
		_text(UiStyle.title_font(), Vector2(pr.get_center().x, pr.position.y + 30), "QUICK CHAT", 22, UiStyle.TRIM, 1)
		var rs := quick_rects()
		for i in rs.size():
			UiStyle.draw_button(_ci, rs[i], false)
			_text(UiStyle.bold_font(), (rs[i] as Rect2).get_center() + Vector2(0, 8), String(Chat.QUICK[i][0]), 23, UiStyle.TEXT, 1)


## PAUSE / RESUME. Online the host decides (NetSession.request_pause): its game stops for everyone, and both screens
## hear it back through net_paused.
func set_paused(v: bool) -> void:
	if game and game.replay:
		game.replay.set_playing(not v)      # (a replay: play and pause, never the tree)
		_sig.erase("pause")
		return
	if game and _online():
		if v != paused and not game.over:
			game.net.request_pause(v)
		return
	if v != paused and game and not game.demo:
		Sfx.announce(game.faction_of(game.human), "paused" if v else "resumed", 1.0)
	paused = v
	get_tree().paused = v
	_sig.erase("pause")


## Online: the match was paused (by a player, or the host is away) or goes on again, after a 3, 2, 1.
func net_paused(on: bool) -> void:
	_sig.erase("pause")
	_sig.erase("top")
	if on == paused:
		return
	paused = on
	if game and not game.demo:
		Sfx.announce(game.faction_of(game.human), "paused" if on else "resumed", 1.0)
	if on:
		get_tree().paused = true
	else:
		start_countdown(NetSession.RESUME_COUNT)


# ------------------------------------------------------------------ drawing

## One player's resources as top-bar pills; returns where the next pill goes.
func _res_pills(font: Font, t: int, x: float) -> float:
	var pl: Dictionary = NetPredict.shown_player(game, t)      # (online: an order just given shows spent at once)
	var fac := game.faction_of(t)
	var cols: Array = {"crown": [Color(0.98, 0.8, 0.2), Color(0.35, 0.33, 0.36)], "brood": [Color(0.55, 0.85, 0.3), Color(0.75, 0.45, 1.0)],
		"clockwork": [Color(0.7, 0.72, 0.78), Color(0.45, 0.75, 1.0)]}[fac]
	var x0 := x
	x = _pill(font, x, cols[0], "%d" % pl["gold"], Color(1, 0.9, 0.55), false, fac == "clockwork" and Defs.gear_mode)
	var r2 := "%d" % int(pl["res2"])
	if fac == "clockwork":
		r2 = "%d energy (%s batteries stored)" % [int(game.energy[t]), "blue" if game.blue_energy(t) else "yellow"]
		if Defs.gear_mode:
			r2 = "%d/%d tension" % [int(float(pl.get("tension", 0.0))), int(GearEcon.tension_cap(game, t))]       # (gear mode: TENSION, held / what the Mainsprings store)
	var x1 := x
	x = _pill(font, x, cols[1], r2, Color(0.85, 0.9, 1.0), false, false,
		_icon("tension") if fac == "clockwork" and Defs.gear_mode else null)
	var used := NetPredict.shown_supply(game, t)
	var cap: int = pl["cap"]
	var x2 := x
	x = _pill(font, x, Color(0.75, 0.55, 0.3), "%d / %d" % [used, cap], UiStyle.BAD if used >= cap else UiStyle.TEXT, true)
	var x3 := x
	if fac == "crown":
		x = _pill(font, x, Color(0.55, 0.42, 0.3), game.horses_text(t), UiStyle.TEXT)
	if t == game.human and not game.spectating():
		# (for their tooltips)
		_pill_rects = [[Rect2(x0, 4, x1 - 8 - x0, 30), 0], [Rect2(x1, 4, x2 - 8 - x1, 30), 1], [Rect2(x2, 4, x3 - 8 - x2, 30), 2]]
		if x > x3:
			_pill_rects.append([Rect2(x3, 4, x - 8 - x3, 30), 3])
	return x


## One player's resources in a short line (watching with all vision).
func _res_line(t: int) -> String:
	var pl: Dictionary = game.players[t]
	var fac := game.faction_of(t)
	var names: Array = {"crown": ["gold", "powder"], "brood": ["biomass", "essence"], "clockwork": ["cogs", "tension"] if Defs.gear_mode else ["ore", "energy"]}[fac]
	var r2: int = int(game.energy[t]) if fac == "clockwork" else int(pl["res2"])
	if fac == "clockwork" and Defs.gear_mode:
		r2 = int(float(pl.get("tension", 0.0)))
	var line := "P%d %s   %d %s · %d %s · %d/%d supply" % [t + 1, String(Defs.FACTIONS[fac]["name"]), int(pl["gold"]), names[0], r2, names[1], game.supply_used(t), int(pl["cap"])]
	if game.replay:
		line += "   ·   " + game.replay.obs_line(t)      # (a replay: income, army and workers, as an observer sees them)
	return line


## The HUD's own canvas item: only the follow camera's cut (a black fade under the layers).
func _draw() -> void:
	if game and game.spectator and game.spectator.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _vs()), Color(0, 0, 0, game.spectator.fade))


func _draw_top(font: Font) -> void:
	var vs := _vs()
	_pill_rects = []
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
		UiStyle.draw_panel(_ci, Rect2(4, 4, wmax + 34, lines.size() * 20 + 10), acc, 0.85)
		for n in lines.size():
			var t: int = lines[n]
			_ci.draw_rect(Rect2(12, 11 + n * 20, 10, 12), game.team_colour(t))
			_text(UiStyle.bold_font(), Vector2(28, 22 + n * 20), _res_line(t), 13, UiStyle.TEXT)
		x = 8.0
	var secs := int(game.clock)
	var clock_x := maxf(vs.x * 0.5 - 44, x)
	var right_btns := vs.x
	if not Settings.pc():
		right_btns = help_rect().position.x if _help_on() else drag_rect().position.x
		if _chat_button_on():
			right_btns = minf(right_btns, chat_btn_rect().position.x)
	if _online() and maxf(vs.x * 0.5 - 44, x + _ping_w() + 10.0) + 88.0 < right_btns - 4.0:
		clock_x = maxf(vs.x * 0.5 - 44, x + _ping_w() + 10.0)     # (online: room left of the clock for the ping; else under it)
	var clock_r := Rect2(clock_x, 4, 88, 30)
	_clock_end = clock_r.end.x
	UiStyle.draw_panel(_ci, clock_r, acc, 0.8)
	_text(UiStyle.title_font(), Vector2(clock_r.get_center().x, 26), "%d:%02d" % [secs / 60, secs % 60], 18, UiStyle.TEXT, 1)
	if _online():
		_draw_ping(clock_r, x)
	if not game.demo:
		var apm_t := "APM %d" % game.apm()
		var apm_w := UiStyle.bold_font().get_string_size(apm_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var left_btn := vs.x
		if not Settings.pc():
			left_btn = help_rect().position.x if _help_on() else drag_rect().position.x
			if _chat_button_on():
				left_btn = minf(left_btn, chat_btn_rect().position.x)
		if clock_r.end.x + 8 + apm_w < left_btn - 4:      # (a phone's buttons may need the room)
			_text(UiStyle.bold_font(), Vector2(clock_r.end.x + 8, 25), apm_t, 14, Color(1, 1, 1, 0.65))
	if not Settings.pc():
		var dr := drag_rect()
		UiStyle.draw_button(_ci, dr, false, Settings.drag_mode == "pan")
		_text(font, dr.get_center() + Vector2(0, 6), "DRAG: " + ("BOX" if Settings.drag_mode == "box" else "PAN"), 15, UiStyle.TEXT, 1)
	if _help_on():
		# "?": the next tap explains instead of acting (lit while armed)
		var hr := help_rect()
		UiStyle.draw_button(_ci, hr, false, help_mode)
		_text(UiStyle.bold_font(), hr.get_center() + Vector2(0, 7), "?", 20, Color(1, 0.9, 0.55) if help_mode else UiStyle.TEXT, 1)
	if _chat_button_on():
		var cr := chat_btn_rect()
		UiStyle.draw_button(_ci, cr, false, quick_open)
		_draw_bubble(cr.get_center(), UiStyle.TEXT)
	var mr := menu_rect()
	UiStyle.draw_button(_ci, mr, mr.has_point(_mouse()) and Settings.pc())
	_text(UiStyle.bold_font(), mr.get_center() + Vector2(0, 6), "MENU", 16, UiStyle.TEXT, 1)
	if game.demo and game.spectator == null:
		_text(font, Vector2(vs.x * 0.5, 60), "AI vs AI", 18, Color(1, 1, 1, 0.6), 1)


const PING_COLS := [Color(0.45, 0.95, 0.45), Color(1.0, 0.85, 0.3), Color(1.0, 0.35, 0.3)]


## Online: the round trip to the other player left of the clock, green / yellow / red (NetSession.ping_grade; red and
## climbing while an answer is late), and under the top bar "Waiting for the host..." while no picture comes.
func _ping_txt() -> String:
	var ms := game.net.ping_shown()
	return "-- ms" if ms < 0 else ("%d ms" % ms if ms < 10000 else "%d s" % (ms / 1000))


## The ping box's width (as wide as "999 ms", so the clock beside it doesn't move as the number changes).
func _ping_w() -> float:
	return UiStyle.bold_font().get_string_size("999 ms", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0


func _draw_ping(clock_r: Rect2, left: float) -> void:
	var net := game.net
	var txt := _ping_txt()
	var col: Color = PING_COLS[net.ping_grade()]
	var font := UiStyle.bold_font()
	var w := maxf(_ping_w(), font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0)
	var r := Rect2(clock_r.position.x - 6.0 - w, 8, w, 22)
	if r.position.x < left + 2.0:
		r = Rect2(clock_r.get_center().x - w * 0.5, clock_r.end.y + 3.0, w, 22)     # (no room beside it: under the clock)
	UiStyle.draw_panel(_ci, r, Color(0, 0, 0, 0), 0.7)
	_ci.draw_circle(r.position + Vector2(11, 11), 4.5, Color(0, 0, 0, 0.6))
	_ci.draw_circle(r.position + Vector2(11, 11), 3.5, col)
	_ci.draw_string(font, Vector2(r.position.x + 20, r.position.y + 16), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
	if not net.is_host and net.waiting and not game.over:
		var wt := Loc.t("Waiting for the host...")
		var ww := font.get_string_size(wt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 36.0
		var br := Rect2(_vs().x * 0.5 - ww * 0.5, top_rect().end.y + 8.0, ww, 32)
		UiStyle.box(Color(0.12, 0.05, 0.04, 0.88), Color(1.0, 0.35, 0.3, 0.8), 2, 14, 0.0).draw(_ci.get_canvas_item(), br)
		_text(font, Vector2(br.get_center().x, br.position.y + 22), wt, 18, Color(1.0, 0.75, 0.65), 1)


## Over the panels: the selection box, what a chosen command waits for, the message, the
## spectator's lists and the countdown.
func _draw_rest(font: Font) -> void:
	var vs := _vs()
	# Selection box
	var br := controls.box_rect()
	br = Rect2(br.position / ui_scale, br.size / ui_scale)
	if br.size != Vector2.ZERO:
		_ci.draw_rect(br, Color(0.4, 1, 0.4, 0.12))
		_ci.draw_rect(br, Color(0.4, 1, 0.4, 0.8), false, 1.5)
	if controls.mode in ["move", "attack", "rally", "rally_army", "rally_worker", "cast", "bombard"]:
		var t: String = {"move": "Tap where to move", "attack": "Tap a target or place to attack-move", "rally": "Tap the rally point",
			"bombard": "Tap the spot to attack, or drag a line to share out: they keep at it until another order",
			"cast": "Tap the enemy to lash with the tongue" if controls.cast_spell == "tongue" else ("Tap where to JUMP (up to 5 tiles; up a cliff only with HIGH LEAP, where you can see)" if controls.cast_spell == "jump" else "Tap where to cast the %s" % {"storm": "storm (it stuns your own units too)",
				"fog": "fog (shots from or into it miss half the time, yours too)"}.get(controls.cast_spell, "healing miasma")),
			"rally_army": "Tap where new soldiers gather", "rally_worker": "Tap a Feeding Pit (or a spot) for new grubs"}[controls.mode]
		if Settings.pc():
			t = t.replace("Tap", "Click") + "  (right-click or Esc cancels)"
		_text(font, Vector2(vs.x * 0.5, 66), t, 20, Color(1, 1, 0.7), 1)
	elif controls.mode == "place":
		var line_k: bool = Defs.BUILDINGS.has(controls.place_kind) and Defs.BUILDINGS[controls.place_kind].get("line", false)
		var hint: String = "Click to build (Shift-click: queue more), right-click or Esc cancels" if Settings.pc() else "Drag to position, tap again or PLACE to build"
		if line_k:
			hint = ("Click where the wall starts" if controls.line_from.x < 0 else "Click where it ends") if Settings.pc() else ("Drag to where the wall starts, then START" if controls.line_from.x < 0 else "Drag to where it ends, then END")
		_text(font, Vector2(vs.x * 0.5, 66), hint, 20, Color(1, 1, 0.7), 1)
	elif help_mode:
		_text(font, Vector2(vs.x * 0.5, 66), "Tap anything to see what it is  (? again: cancel)", 20, Color(1, 1, 0.7), 1)
	if _msg_t > 0.0:
		var a := minf(_msg_t, 1.0)
		var mw := font.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 36
		var mrr := Rect2(vs.x * 0.5 - mw * 0.5, top_rect().end.y + 46, mw, 36)
		var sb := UiStyle.box(Color(0.1, 0.08, 0.06, 0.88 * a), Color(0.79, 0.64, 0.29, 0.6 * a), 2, 18, 0.0)
		sb.draw(_ci.get_canvas_item(), mrr)
		_text(UiStyle.bold_font(), Vector2(vs.x * 0.5, mrr.position.y + 25), _msg, 21, Color(1, 0.85, 0.65, a), 1)
	if game.spectating():
		_draw_view(font)
		_draw_production(font)
	if not paused:
		_draw_countdown()


func _draw_pause() -> void:
	var vs := _vs()
	var hv := _mouse() if Settings.pc() else Vector2(-1, -1)
	if menu_open:
		# see-through: the match stays visible behind (for screenshots and a look at the field)
		_ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.12 if not paused else 0.2))
		var pr := menu_panel_rect()
		UiStyle.draw_panel(_ci, pr, UiStyle.accent(game.faction_of(game.human)), 0.45)
		var cx := pr.position.x + 20.0 + MENU_W * 0.5
		var title := "PAUSED" if paused else "MENU"
		_text(UiStyle.title_font(), Vector2(cx, pr.position.y + 50), title, 40, UiStyle.TRIM, 1)
		var sub := _pause_who() if paused else ""
		if sub != "":
			_text(UiStyle.bold_font(), Vector2(cx, pr.position.y + 76), sub, 16, UiStyle.TEXT, 1)
		if _confirm != "":
			var q := "Give up this match? Your buildings fall." if _confirm == "surrender" else (
				"Leave the match? It ends for your friend too." if game.net and game.net.is_host else "Leave the match? A computer plays your side.")
			_text(UiStyle.bold_font(), Vector2(cx, pr.position.y + 120), q, 17, UiStyle.TEXT, 1)
		for b in _menu_buttons():
			var r: Rect2 = b["rect"]
			var on: bool = b.get("enabled", true)
			UiStyle.draw_button(_ci, r, r.has_point(hv) and on, false, on, 0.45)
			if b.has("slider"):
				var vv: float = _slider_value(b["slider"])
				_ci.draw_rect(Rect2(r.position.x + 14, r.end.y - 11, (r.size.x - 28) * vv, 4), UiStyle.TRIM)
				_ci.draw_rect(Rect2(r.position.x + 14 + (r.size.x - 28) * vv - 2, r.end.y - 14, 4, 10), UiStyle.TEXT)
			var col: Color = UiStyle.BAD if b.get("bad", false) else UiStyle.TEXT
			if not on:
				col = Color(col, 0.45)
			var ty := r.get_center().y + 8.0
			if b.has("slider"):
				ty = minf(ty, r.end.y - 15.0)     # above its bar on a short button (the bar ran through the words)
			_text(UiStyle.bold_font(), Vector2(r.get_center().x, ty), b["label"], 21, col, 1)
		if _music_shown():
			music.layout(_music_panel_rect())
			music.draw(self, _ci, hv)
		return
	if paused and countdown <= 0.0:
		var r2 := _paused_rect()
		UiStyle.draw_panel(_ci, r2, UiStyle.accent(game.faction_of(game.human)), 0.75)
		_text(UiStyle.title_font(), Vector2(r2.get_center().x, r2.position.y + 46), "PAUSED", 38, UiStyle.TRIM, 1)
		var who := _pause_who()
		if game.net and game.net.pause_by >= 0 and not game.net.away:
			who += "  ·  %d s" % int(game.net.pause_t)
		if who != "":
			_text(UiStyle.bold_font(), Vector2(r2.get_center().x, r2.position.y + 78), who, 17, UiStyle.TEXT, 1)
		for b in _paused_buttons():
			var r: Rect2 = b["rect"]
			var on: bool = b.get("enabled", true)
			UiStyle.draw_button(_ci, r, r.has_point(hv) and on, false, on, 0.6)
			_text(UiStyle.bold_font(), r.get_center() + Vector2(0, 8), b["label"], 21, UiStyle.TEXT if on else Color(UiStyle.TEXT, 0.45), 1)


func _draw_minimap() -> void:
	var m := mini_rect()
	UiStyle.draw_panel(_ci, m.grow(5), UiStyle.accent(game.faction_of(game.human)), clampf(Settings.mini_alpha * 0.85, 0.15, 0.9))
	if _mini_tex == null:
		_mini_tex = ImageTexture.create_from_image(game.minimap_img)
	var wash := Color(1, 1, 1, Settings.mini_alpha)
	_ci.draw_texture_rect(_mini_tex, m, false, wash)
	if game.swamp_tex:
		_ci.draw_texture_rect(game.swamp_tex, m, false, wash)
	var k := m.size / (Vector2(Game.W, Game.H) * Game.T)
	if not game.sees_all():
		_ci.draw_texture_rect(game.fog_tex, m, false, Color(1, 1, 1, 0.95 * Settings.mini_alpha))
	if game.exp_spots:
		game.exp_spots.draw_on_minimap(_ci, m)      # (the best expansion spots: small gold squares)
	for b in game.buildings:
		if b.visible or (b.team == game.human and not game.demo):
			var r: Rect2 = b.rect()
			_ci.draw_rect(Rect2(m.position + r.position * k, r.size * k), game.team_colour(b.team).lightened(0.2))
	for u in game.units:
		if u.visible and not u.dead:
			_ci.draw_rect(Rect2(m.position + u.position * k - Vector2(1.5, 1.5), Vector2(3, 3)), u.cloth_colour().lightened(0.35))     # (a loose horse: nobody's brown)


## Over the minimap (its own layer, redrawn as the camera moves): the camera's view, where
## you're being hit, and the zoom gauge (top bar).
func _draw_map_view() -> void:
	var m := mini_rect()
	var k := m.size / (Vector2(Game.W, Game.H) * Game.T)
	# Camera view
	var vp := get_viewport().get_visible_rect().size / game.camera.zoom
	var c := game.camera.get_screen_center_position()
	# (the camera may look past the map edge, Defs.CAMERA_MARGIN_TILES: the box stays on the minimap)
	var vr := Rect2(m.position + (c - vp * 0.5) * k, vp * k).intersection(m)
	if vr.size.x > 0.0 and vr.size.y > 0.0:
		_ci.draw_rect(vr, Color(1, 1, 1, 0.9), false, 1.0)
	# where you're being hit
	if game.alert_t > 0.0 and game.alert_at != Vector2.INF:
		var ap: Vector2 = m.position + game.alert_at * k
		var ph := fmod(game.alert_t * 2.0, 1.0)
		_ci.draw_arc(ap, 4.0 + ph * 14.0, 0, TAU, 20, Color(1, 0.25, 0.2, 1.0 - ph), 2.0)
		_ci.draw_circle(ap, 3.0, Color(1, 0.3, 0.2))
	_draw_zoom()


var _mini_tex: ImageTexture
var _zoom_seen := 0.0
var _zoom_ms := 0           # when the zoom last changed (the gauge lights up for a moment)
const ZOOM_MIN := 0.55      # the camera's zoom limits (controls.gd)
const ZOOM_MAX := 2.6


func _zoom_alpha() -> float:
	var z: float = game.camera.zoom.x
	if absf(z - _zoom_seen) > 0.001:
		_zoom_seen = z
		_zoom_ms = Time.get_ticks_msec()
	var zt := (Time.get_ticks_msec() - _zoom_ms) / 1000.0
	return 1.0 if zt < 1.5 else lerpf(1.0, 0.55, clampf((zt - 1.5) / 0.8, 0.0, 1.0))


## The small zoom gauge, in the top bar left of the menu buttons (not on the minimap).
var _clock_end := 0.0        # the top bar's clock's right edge (the zoom gauge keeps clear of it)


func zoom_rect() -> Rect2:
	var x := _vs().x - 96 - 128
	if _chat_button_on():
		x = chat_btn_rect().position.x + 2       # (left of the phone's chat button, which is left of ? and DRAG)
	return Rect2(x - 100, 9, 92, 18)


## Zoom gauge: a slim bar from widest view to closest, with the zoom as a factor. It
## brightens for a couple of seconds after the zoom changes.
func _draw_zoom() -> void:
	var z: float = game.camera.zoom.x
	var a := _zoom_alpha()
	var box := zoom_rect()
	if box.position.x < _clock_end + 4.0:
		return          # (a crowded top bar, online on a phone: the clock and the ping keep their room, the gauge goes)
	_ci.draw_rect(box, Color(0, 0, 0, 0.55 * a))
	var bar := Rect2(box.position + Vector2(40, 7), Vector2(46, 4))
	_ci.draw_rect(bar, Color(1, 1, 1, 0.25 * a))
	var f := clampf((z - ZOOM_MIN) / (ZOOM_MAX - ZOOM_MIN), 0.0, 1.0)
	_ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), Color(1, 0.86, 0.5, 0.9 * a))
	_ci.draw_rect(Rect2(bar.position + Vector2(bar.size.x * f - 1.5, -3), Vector2(3, bar.size.y + 6)), Color(1, 1, 1, a))
	_text(UiStyle.bold_font(), box.position + Vector2(5, 13), "x%.1f" % z, 12, Color(1, 1, 1, a))


## The quick buttons' numbers (army, idle workers, units in production, groups), counted at
## each look in one pass over the units.
var _counts: Array = []


func _refresh_counts() -> void:
	var army := 0
	var idle := 0
	var me := game.human
	for u in game.units:
		if u.team != me or u.dead or u.aboard != null:
			continue
		if u.is_worker():
			if u.order == "idle":
				idle += 1
		elif u.kind != "horse" and u.kind != "messenger":
			army += 1
	var busy := 0
	for pb in game.producers(me):
		busy += (pb as Building).queue.size()
	var c: Array = [army, idle, busy]
	for g in game.groups.size():
		var n := 0
		for e in game.groups[g]:
			if is_instance_valid(e) and not e.dead:
				n += 1
		c.append(n)
	_counts = c


func _draw_groups(font: Font) -> void:
	if _counts.is_empty():
		_refresh_counts()
	bar.draw(font, _counts)


func _draw_panel(font: Font) -> void:
	_queue_rects = []
	var r := panel_rect()
	if game.selection.is_empty():
		return
	UiStyle.draw_panel(_ci, r, UiStyle.accent(game.faction_of(game.human)))
	var sel: Array = game.selection.filter(func(e: Entity) -> bool: return is_instance_valid(e) and not e.dead)
	if sel.size() == 1:
		var e: Entity = sel[0]
		var icon := _unit_icon(e)
		var pr := Rect2(r.position + Vector2(10, 10), Vector2(68, 68))
		UiStyle.draw_button(_ci, pr.grow(2), false, false)
		if icon:
			_ci.draw_texture_rect(icon, pr, false)
		var name := ""
		var info := ""
		var eff_txt := ""                # economy buildings: "Efficiency 62%: 5/8 workers · soil 78%" (in its colour)
		var eff_col := UiStyle.MUTED
		if e is Unit:
			name = (e as Unit).d["name"]
			if Game.loose_horse(e):
				name += " (loose)"
			var tags: Array = (e as Unit).d.get("tags", [])
			if not tags.is_empty():
				name += "  ·  " + " ".join(tags.map(func(x: String) -> String: return x.capitalize()))
			info = (e as Unit).d["about"]
			var uu := e as Unit
			if Defs.HARNESSED.has(uu.kind) and uu.harnessed:
				# its team of horses (and what the extra ones add)
				name += "  ·  %d/%d horse%s%s" % [uu.horse_count(), int(Defs.HORSES["team_max"]), "s" if uu.horse_count() > 1 else "",
					(" +%d%% speed" % int(round(float(Defs.HORSES["team_speed"]) * uu.team_horses.size() * 100.0))) if uu.team_horses.size() > 0 else ""]
			# a seasoned horse (its own, a rider's or a gun's): rank, and how far to the next
			if uu.kind == "horse" or uu.horse_working():
				var hr := Unit.horse_rank(uu.horse_miles)
				if hr > 0:
					name += "  ·  Seasoned horse (rank %d)" % hr
			if uu.order == "gather" and uu.home_mine is Building:
				info = "Working at the %s." % (uu.home_mine as Building).d["name"]
			if uu.kind == "grub" and uu.carrying > 0:
				var home := game.nearest_hall(uu.position, uu.team)
				info = "Hauling food worth %d to the %s." % [uu.carrying, home.d["name"] if home else "Burrow"]
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
			elif uu.kind == "horse":
				if uu.team < 0:
					info = "Loose: nobody's horse. A man who can lead horses takes it by walking up; the Brood can kill it." \
						+ (" A %s is coming for it." % uu.claimed.d["name"] if uu.claimed and is_instance_valid(uu.claimed) and uu.claimed.order_target == uu else "")
				elif uu.leader and is_instance_valid(uu.leader):
					info = "Led by a %s." % uu.leader.d["name"]
				elif is_instance_valid(uu.into) and uu.into is Building and uu.hitch_p != Vector2.INF:
					info = "Hitched at the %s till its rider or gun comes out: it can't be hurt or taken." % uu.into.d["name"]
				elif is_instance_valid(uu.into) and uu.into is Building:
					info = "Going to the %s, to be hitched there." % uu.into.d["name"]
				elif is_instance_valid(uu.into) and uu.into is Unit:
					info = "Going to be harnessed to the %s." % uu.into.d["name"]
				elif uu.claimed and is_instance_valid(uu.claimed) and uu.claimed.order_target == uu:
					info = "A %s is coming for it." % uu.claimed.d["name"]
				else:
					info = "Grazing, unattended: keep a man by it, or an enemy man can steal it."
				var hr2 := Unit.horse_rank(uu.horse_miles)
				if hr2 < int(Defs.HORSE_VET["max"]):
					info += "  Seasoning %d/%d tiles. Heals by itself." % [int(uu.horse_miles) % int(Defs.HORSE_VET["tiles"]), int(Defs.HORSE_VET["tiles"])]
				else:
					info += "  Fully seasoned. Heals by itself."
			elif Defs.HARNESSED.has(uu.kind) and not uu.harnessed:
				info = "NO HORSE: it can't move (HARNESS one). " + ("Fires from where it stands." if uu.kind != "powder_wagon" else "It still supplies.")
			elif uu.kind == "dragoon":
				info = "Rides fast; dismounts to fire. Powder %d/%d · reload %s (waits while he rides)" % [int(uu.powder), int(uu._pmax),
					"ready" if uu.cooldown <= 0.0 else "%.1f s left" % uu.cooldown]
			elif uu.kind == "messenger":
				info = "Unarmed scout: very fast, sees far."
			elif Defs.MUSKETS.has(uu.kind):
				# "Powder 9/10 · Reload 3.0 s"; while he reloads "Reload 1.2/3.0 s", counting up
				# (and the thin bar under the powder bar fills with it)
				var rl := uu.musket_cooldown()
				var rtxt := "Reload %.1f s" % rl
				if uu.reload_frac() < 1.0 and uu.cooldown > 0.0:
					rtxt = "Reload %.1f/%.1f s" % [clampf(rl - uu.cooldown, 0.0, rl), rl]
				if uu.powder < 1.0:
					info = "Powder 0/%d OUT: bayonet only · %s" % [int(uu._pmax), rtxt]
				else:
					info = "Powder %d/%d · %s" % [int(uu.powder), int(uu._pmax), rtxt]
			elif uu.kind == "powder_wagon":
				var runs := game.units.filter(func(x: Unit) -> bool: return String(x.haul_job.get("k", "")) == "keg" and x.haul_job.get("wagon") == uu).size()
				info = "Powder %d/%d shots · SUPPLY %s%s · blows up when destroyed" % [int(uu.powder), int(uu._pmax), "on" if uu.supplying else "off",
					(" (%d kegs on the way)" % runs) if uu.supplying and runs > 0 else ""]
			elif uu.kind == "labourer" and uu.is_hauler():
				info = uu.hauler_text()
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
				if not game.has_tech(uu.team, "charge"):
					info = "No charge yet: the Armoury drills the Cavalry Charge."
				else:
					info = "Charge ready: the next blow hits double and throws the enemy back." if uu.run_t >= float(Defs.CHARGE["run"]) else "Gallop about 2 s and the next blow is a charge."
				info = pistol_text(uu) + " · " + info
			elif uu.kind == "dismounted":
				info = pistol_text(uu) + " · Sabre up close. MOUNT a horse to ride."
			elif uu.kind == Defs.CUCKOO:
				if uu.owl_t >= 0.0:
					info = "Turning into a Ticking Owl: %d s left (it cannot move or fight; CANCEL MORPH pays it back)." % int(ceil(float(Defs.OWL_MORPH["time"]) - uu.owl_t))
				elif game.has_tech(uu.team, "owl_morph"):
					info = "Hunts flyers: it pecks them up close; it cannot touch the ground. MORPH TO OWL rebuilds it into a Ticking Owl."
				else:
					info = "Hunts flyers: it pecks them up close; it cannot touch the ground. Research TICKING OWL at a Clock Aviary to rebuild it into a Ticking Owl."
			elif uu.kind == Defs.OWL:
				info = "Swoops on units with its talons; drops its weight as a bomb on buildings. It cannot hit flyers."
			elif uu.kind == Defs.SPRINGER:
				var jn := "In the air." if not uu.jump.is_empty() else ("JUMP ready" if uu.jump_cd <= 0.0 else "JUMP in %d s" % int(ceil(uu.jump_cd)))
				info = jn + (" · HIGH LEAP: it can jump up onto high ground it can see." if game.has_tech(uu.team, "high_leap") else " · Flat and down only (HIGH LEAP at the Escapement: up too).")
			elif uu.kind == Defs.NETTER:
				info = Netter.card_line(uu)
			elif uu.kind == Defs.BALLISTA_KIND:
				info = Ballista.card_line(uu)
			elif uu.kind == Defs.GREAT_WINDER_KIND:
				info = GreatWinder.card_line(uu)
			elif uu.kind == Defs.PENDULUM:
				info = "Its blade cuts every enemy in the arc in front of it (never your own units). It cannot reach flyers."
			elif uu.kind == "tesla_cart":
				info = {"packed": "Packed: rolls, can't fire. DEPLOY to fight.", "deploying": "Deploying...",
					"deployed": "Deployed: powers constructs nearby and zaps enemies.", "packing": "Packing up..."}[uu.tesla_mode]
			elif uu.kind == "balloon":
				# its powder store, then the one thing worth knowing about it right now
				info = "Powder store %d/%d" % [int(uu.powder), int(uu._pmax)]
				var aboard := uu.passengers.size()
				if not uu.incoming.is_empty():
					info += " · coming down: %d climbing in" % uu.incoming.size()
				elif uu.haul_t >= 0.0:
					info += " · hauling a keg up (%.1f s)" % maxf(float(Defs.BALLOON["haul"]) - uu.haul_t, 0.0)
				elif uu.order == "restock":
					info += " · off to restock"
				elif aboard == 0:
					info += " · pilot only: LOAD Musketeers to fight"
				elif uu.powder < uu._pmax * 0.5:
					info += " · low: RESTOCK at a Wagon, Mill, Barracks or Hall"
				else:
					info += " · %d/%d aboard" % [aboard, int(Defs.DROPSHIP["capacity"])]
			elif uu.kind == "skywing":
				info = {"air": "Flying: hunts flyers with spines. LAND to fight on the ground.", "to_land": "Looking for open ground to land on...",
					"landing": "Landing...", "ground": "Landed: walks and bites ground units; anything can hit it. TAKE OFF to fly.", "lifting": "Taking off..."}.get(uu.sky, uu.d["about"])
			elif uu.kind == "bloater" and uu.deflate != "":
				info = "Out of gas: deflated, slower and harmless. Gas %d / 100 (fills faster on swamp)." % int(uu.gas)
			elif uu.kind == "bloater":
				# its gas: what a burst would do now (Game.bloat_burst) and the spits left
				var full := clampf(uu.gas / 100.0, 0.15, 1.0)
				var burst := "%d + %d s cloud" % [int(round(float(Defs.BLOAT["burst"]) * full)), int(round(float(Defs.BLOAT["time"]) * (0.4 + 0.6 * full)))]
				if uu.mode == "hold":
					info = "Gas %d/100 · HOLD GAS: bursts for %s" % [int(uu.gas), burst]
				else:
					var spits := int(floor(uu.gas / float(Defs.BLOAT["spit_cost"])))
					info = "Gas %d/100 · burst %s · %d spit%s left" % [int(uu.gas), burst, spits, "" if spits == 1 else "s"]
			elif uu.kind == "ornithopter" and (uu.topter_bat != "" or uu.courier):
				info = ("Carrying a %s battery: OVERLOAD a construct with it, or it winds one up on COURIER." % uu.topter_bat) if uu.topter_bat != "" else "Courier: fetching batteries for constructs that run down."
			elif uu.kind == "windup_soldier" and uu.powered_down():
				info = "RUN DOWN: frozen until a Winder cranks it up again (or a field reaches it)."
			elif uu.kind == "windup_soldier":
				info = "Spring %d%%%s: about 50 s away from a field and it runs down." % [int(uu.wind * 100), " (being cranked)" if uu.cranked_t > 0.0 else ""]
			elif uu.kind == ShieldWall.KIND and uu.shield_up:
				info = ("SHIELD FORWARD: raising the shield..." if uu.shield_t > 0.0 else "SHIELD FORWARD: %d%% slower, armour %d, %d%% less from shots in front.") % ([] if uu.shield_t > 0.0 else [
					int(round((1.0 - float(Defs.SHIELD_WALL["speed"])) * 100.0)), int(uu.d["armor"]) + int(Defs.SHIELD_WALL["armor"]), int(round(float(Defs.SHIELD_WALL["front"]) * 100.0))])
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
			elif uu.kind == "missionary" or uu.kind == "mounted_missionary":
				info = "In danger near enemy buildings!" if not uu.untouchable() else "Can't be hurt here. Bandages wounded soldiers."
			elif (e as Unit).powered_down():
				info = "OUT OF CHARGE: shut down. A field (tower, pylon, deployed Tesla Cart) or a Winder brings it back."
			elif (e as Unit).d["faction"] == "clockwork" and not (e as Unit).is_worker() and (e as Unit).wind < 0.99:
				info = "Charge %d%%: it runs down away from a field and shuts down when empty." % int((e as Unit).wind * 100)
			if uu.net_t > 0.0:
				info = "CAUGHT IN A NET: %d s (it cannot move or fight)" % int(ceil(uu.net_t))      # (a Netter's: scripts/netter.gd)
			if uu.hold_fire and not uu.has_pistol():
				info = "HOLD FIRE · " + info      # (the pistol's own line says it)
			if not uu.led.is_empty():
				info = "Leading %d horse%s · " % [uu.led.size(), "" if uu.led.size() == 1 else "s"] + info
			if uu.auto_mount and uu.kind == "musketeer" and uu.steed and is_instance_valid(uu.steed):
				info = "Dragoon on foot (remounts to move) · " + info
			if Defs.ARMOURED.has(uu.kind) and e.team == game.human:
				# his own refits first: "Armour · Flintlock"
				var kt := uu.kit_text()
				if uu.order == "refit" and not uu.refit.is_empty():
					var names := " + ".join(uu.refit.map(func(w: String) -> String: return String(Defs.RESEARCH[w]["name"])))
					kt = ("%s · " % kt if kt != "" else "") + ("refitting: %s..." % names if uu.work == "refitting" else "off to be refitted: %s" % names)
				info = (kt if kt != "" else ("Plain musket" if Defs.MUSKETS.has(uu.kind) else "No armour")) + "  ·  " + info
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
				info = "Haulers %d/%d · Soil: %d%% (%d gold)%s · Saltpetre: %d%% (%d powder)%s · allows 2 Farms and 1 Powder Mill nearby" % [bb.haulers_free(), bb.haulers().size(), int(round(soil * 100)), int(bb.soil),
					" spent: farms pay a third" if soil <= 0.0 else (" running low" if soil < Defs.SOIL_LOW else ""),
					int(round(salt * 100)), int(bb.lode), " spent: the Mill grinds at a quarter" if salt <= 0.0 else (" running low" if salt < Defs.SOIL_LOW else "")]
			elif bb.kind == "clocktower" and (e.team == game.human or game.demo):
				var coal := bb.soil_left()
				if Defs.gear_mode:
					# (no power in gear mode: no batteries, no Boilers, no coal)
					info = "Brass: %d left%s · allows 2 Cog Presses nearby" % [int(bb.lode),
						" (spent: its presses yield a quarter; expand)" if bb.lode <= 0.0 else (" (running low)" if bb.lode_left() < Defs.SOIL_LOW else "")]
				else:
					info = "%d/%d batteries ready (one every %.1f s) · Ore: %d left%s · Coal: %d%%%s · allows 2 Boilers and 2 Ore Crushers nearby" % [
						bb.batteries, int(bb.d["battery"][1]), float(bb.d["battery"][0]), int(bb.lode),
						" (spent: its crushers pay a quarter; expand)" if bb.lode <= 0.0 else (" (running low)" if bb.lode_left() < Defs.SOIL_LOW else ""),
						int(round(coal * 100)), " (spent: its Boilers fill at a third)" if coal <= 0.0 else (" (running low)" if coal < Defs.SOIL_LOW else "")]
			elif bb.kind == "horse_breeder" and bb.built and (e.team == game.human or game.demo):
				info = "%s  ·  " % game.horses_text(bb.team) + info
			elif (bb.kind == "barracks" or bb.kind == "foundry") and bb.built and (e.team == game.human or game.demo):
				info = "Horses here: %d (Horsemen, Dragoons, cannons, mortars and wagons need one each)  ·  " % game.horses_at(bb) + info
			elif bb.kind == "powder_mill":
				var sl := bb.lode_left()
				info = "+%.1f powder/s%s" % [game.lode_pay(bb, Defs.MILL_RATE * bb.working_crew()), " · saltpetre spent: a quarter; expand to a new Town Hall" if sl <= 0.0 else (" · saltpetre running low" if sl < Defs.SOIL_LOW else "")]
			elif bb.kind == "feeding_pit":
				var gl := bb.soil_left()
				info = "Ground: %d%% (%d biomass)%s · each load is worth %.1f" % [int(round(gl * 100)), int(bb.soil),
					" spent: it yields nothing, grow a new pit on fresh ground" if gl <= 0.0 else (" running low" if gl < Defs.SOIL_LOW else ""), game.load_value(bb)]
			elif bb.d.has("battery") and e.team == game.human:
				var bat: Array = bb.d["battery"]
				var coal2 := bb.soil_left()
				info = "%d/%d batteries ready (one every %.1f s)%s" % [bb.batteries, int(bat[1]),
					float(bat[0]) / (1.0 if coal2 > 0.0 else Defs.COAL_SPENT), " · coal spent: a third as fast" if coal2 <= 0.0 else (" · coal running low" if coal2 < Defs.SOIL_LOW else "")]
			elif bb.kind == Defs.GEAR_PRESS:
				var bl := bb.lode_left()
				info = "+%.1f cogs/s · %d/%d Winders winding · %s gear%s" % [bb.press_rate(), bb.working_crew(), bb.crew_max(), "BIG" if bb.gear_big else "SMALL",
					" · brass spent: a quarter; expand to a new Clocktower" if bl <= 0.0 else (" · brass running low" if bl < Defs.SOIL_LOW else "")]
			elif bb.kind == "ore_drill":
				var ol2 := bb.lode_left()
				var q2 := 1.0 if ol2 > 0.0 else Defs.LODE_SPENT
				info = "%d/%d ore waiting for a train · digs %.1f ore/s at this pressure (%s)%s" % [int(bb.stock), int(Defs.RAIL["drill"]["stock"]),
					float(Defs.RAIL["drill"]["rate"]) * game.line_net.speed_mult(bb) * q2, game.line_net.state_of(bb),
					" · ore spent: a quarter" if ol2 <= 0.0 else (" · ore running low" if ol2 < Defs.SOIL_LOW else "")]
			elif bb.kind == "ore_crusher":
				var blue := game.blue_energy(e.team)
				var bi: Dictionary = Defs.BATTERY["blue" if blue else "yellow"]
				var ol := bb.lode_left()
				var q := 1.0 if ol > 0.0 else Defs.LODE_SPENT
				info = "%s batteries: %d ore; after %d s on the road they lose %d%% a second%s" % ["Blue" if blue else "Yellow",
					int(round(Defs.battery_charge(blue, 0.0) * float(Defs.BATTERY["ore"]) * q)), int(Defs.BATTERY["fresh"]), int(round(float(bi["decay"]) * 100)),
					" · ore spent: a quarter" if ol <= 0.0 else (" · ore running low" if ol < Defs.SOIL_LOW else "")]
			elif bb.kind == "brood_pen":
				info = "SACRIFICE Brood creatures here: %d%% of their biomass as essence (a Raptor: %d)." % [int(round(Defs.SACRIFICE * 100.0)), Game.sacrifice_value("raptor")]
			elif bb.uses_eggs() and (e.team == game.human or game.demo):
				var nxt := "" if bb.eggs >= bb.eggs_max() else "  (next in %ds)" % int(ceil(Defs.EGG_TIME - bb.egg_t))
				info = "Eggs: %d / %d%s" % [bb.eggs, bb.eggs_max(), nxt]
				if bb.upgrade_t >= 0.0 and not bb.next_level().is_empty():
					info += " · Growing into a %s: %d s left" % [bb.next_level()["name"], int(ceil(float(bb.next_level()["time"]) - bb.upgrade_t))]
			if bb.kind == Defs.CW_TECH and bb.built and not bb.dead and Defs.gear_mode:
				if game.gear_net.needs_spring(bb):
					info = "NEEDS MAINSPRING: its ring meshes with no Mainspring, so it stands idle (no research, no Springers). Build a Mainspring right beside it."
				elif game.gear_net.speed_mult(bb) > 0.0:
					info = "Working: its ring meshes with a Mainspring. Springers and Netters can be made at a Light Works whose ring meshes with a Mainspring, Pendulums and Spring Ballistas at a Heavy Works%s." % ("" if game.has_tech(bb.team, "high_leap") else "; HIGH LEAP can be researched here")
			if Defs.gear_mode and bb.built and not bb.dead and (e.team == game.human or game.demo):
				var gi := GearEcon.card_info(bb)        # (the Tension rule and the store: scripts/gear_econ.gd)
				if gi != "":
					info = gi + ("  ·  " + info if bb.kind == Defs.CW_WORKS else "")
			if bb.built and not bb.dead and Defs.gear_mode and bb.d["faction"] == "clockwork" and bb.kind != "clocktower" and (e.team == game.human or game.demo):
				var tl := GearEcon.trade_line(bb.kind, bb.gear_big)       # (SIZE SETS THE TEMPO: its ring's trade, one line)
				if tl != "":
					info = tl + ("  ·  " + Loc.t(info) if info != "" else "")      # (first: the about text after it is cut short)
			if bb.built and not bb.dead and Defs.gear_mode and bb.d["faction"] == "clockwork" and (e.team == game.human or game.demo):
				if not game.gear_net.is_linked(bb):
					info = "UNLINKED: its gear ring does not mesh with the field, so it does nothing. Build a linked building beside it, or put it back in reach.  ·  " + info
				elif bb.gear_swap_t >= 0.0:
					info = "Swapping its gear (%d s)  ·  " % int(ceil(bb.gear_swap_t)) + info
			if bb.built and (e.team == game.human or game.demo):
				var ef: Array = bb.efficiency()
				if not ef.is_empty() and Defs.gear_mode and bb.d["faction"] == "clockwork":
					eff_txt = GearEcon.card_text(bb)       # (gear mode: crew x drive x brass, scripts/gear_econ.gd)
					eff_col = game.eff_colour(float(ef[0]))
				elif not ef.is_empty():
					var who := "base Winders" if bb.kind == "ore_crusher" else ("grubs" if bb.kind == "feeding_pit" else ("Winders" if bb.d["faction"] == "clockwork" else "workers"))
					eff_txt = "Efficiency %d%%: %d/%d %s · %s %d%%" % [int(round(float(ef[0]) * 100)), int(ef[1]), int(ef[2]), who, ef[4], int(round(float(ef[3]) * 100))]
					eff_col = game.eff_colour(float(ef[0]))
		if e.team >= 0 and e.team != game.human and not game.demo:
			name += "  (enemy)"            # (watching, or a replay: nobody is the enemy)
		name = Loc.t(name)
		var nsz := 19
		if e is Unit and (e as Unit).kind == "balloon" and not (e as Unit).passengers.is_empty():
			# its passengers' icons take the top right: the plain name, shrunk to fit before them
			name = Loc.t((e as Unit).d["name"] + ("  (enemy)" if e.team >= 0 and e.team != game.human and not game.demo else ""))
			var room := _pass_icon_x(r, (e as Unit).passengers.size(), 0) - 6.0 - (r.position.x + 90.0)
			while nsz > 12 and UiStyle.title_font().get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, nsz).x > room:
				nsz -= 1
		_text(UiStyle.title_font(), r.position + Vector2(90, 28), name, nsz, UiStyle.TEXT)
		var hf := clampf(e.hp / maxf(e.max_hp, 1.0), 0.0, 1.0)
		var hb := Rect2(r.position + Vector2(90, 38), Vector2(170, 12))
		_ci.draw_rect(hb, Color(0, 0, 0, 0.6))
		_ci.draw_rect(Rect2(hb.position, Vector2(hb.size.x * hf, hb.size.y)), UiStyle.GOOD if hf > 0.5 else (Color(0.95, 0.75, 0.25) if hf > 0.25 else UiStyle.BAD))
		_ci.draw_rect(hb, UiStyle.TRIM_DIM, false, 1.0)
		var hpt := "%d / %d" % [int(ceil(e.hp)), int(e.max_hp)]
		_text(font, hb.position + Vector2(hb.size.x + 8, 11), hpt, 15, Color(0.75, 1, 0.7))
		if e is Unit and (e as Unit)._pmax > 0.0 and (e.team == game.human or game.demo):
			# the powder it carries (a balloon: its store), and a Musketeer's reload
			var pu := e as Unit
			var pb := Rect2(hb.position + Vector2(0, hb.size.y + 3), Vector2(hb.size.x, 4))
			_ci.draw_rect(pb, Color(0, 0, 0, 0.6))
			_ci.draw_rect(Rect2(pb.position, Vector2(pb.size.x * clampf(pu.powder / pu._pmax, 0.0, 1.0), pb.size.y)), Unit.POWDER_BAR if pu.powder >= 1.0 else UiStyle.BAD)
			if pu.foot_musket():
				var rb := Rect2(pb.position + Vector2(0, pb.size.y + 2), Vector2(hb.size.x, 2))
				var rf := pu.reload_frac() if pu.powder >= 1.0 else 0.0
				_ci.draw_rect(rb, Color(0, 0, 0, 0.6))
				_ci.draw_rect(Rect2(rb.position, Vector2(rb.size.x * rf, rb.size.y)), Color(1.0, 0.85, 0.3) if rf >= 1.0 else Color(0.92, 0.92, 0.85))
		if e is Unit and (e as Unit).has_pistol() and (e.team == game.human or game.demo):
			# the pistol: a little pistol after the health figures, bright loaded, dim and crossed empty
			_draw_pistol(Vector2(hb.end.x + 16 + font.get_string_size(hpt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, hb.position.y), (e as Unit).pistol)
		if e is Unit and (e as Unit).kills > 0:
			# veterancy: kills and the damage they've earned
			var ku := e as Unit
			var bonus := minf(ku.kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"]))
			var vt := "%s%d kill%s · +%d%% damage" % ["Veteran · " if not ku.is_worker() else "", ku.kills, "" if ku.kills == 1 else "s", int(round(bonus * 100.0))]
			vt = Loc.t(vt)
			var vx := hb.position.x + hb.size.x + 22 + font.get_string_size(hpt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			if ku.has_pistol() and (e.team == game.human or game.demo):
				vx += 30.0           # (after the pistol)
			var room := r.end.x - 36 - vx
			if UiStyle.bold_font().get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > room:
				vt = Loc.t("%d kills +%d%%") % [ku.kills, int(round(bonus * 100.0))]
			if UiStyle.bold_font().get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= room:
				_text(UiStyle.bold_font(), Vector2(vx, hb.position.y + 11), vt, 14, Color(1, 0.82, 0.3))
			else:
				info = vt + " · " + info
		if e is Unit and (e as Unit).friendly_kills > 0:
			var fk := (e as Unit).friendly_kills
			info = "Friendly fire: %d of ours killed. " % fk + info
		var cwi := CwUnits.info(e as Unit) if Defs.cw_roster and e is Unit else ""
		if cwi != "":
			info = Loc.t(cwi) + ("  ·  " + Loc.t(info) if info != "" else "")      # (the experimental roster's state first)
		else:
			info = Loc.t(info)
		eff_txt = Loc.t(eff_txt)
		# (the fitting measures the line again and again, a character at a time: worked out once
		# for each text and card width, it was most of the panel's cost, drawn 20 times a second)
		var fit_key := "%s|%s|%d" % [eff_txt, info, int(r.size.x)]
		var fit: Array = _fit_memo.get(fit_key, [])
		if fit.is_empty():
			var ifs := 15          # (a longer translation shrinks to fit the card)
			while ifs > 10 and font.get_string_size(eff_txt + ("  ·  " if eff_txt != "" else "") + info, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs).x > r.size.x - 130:
				ifs -= 1
			var iroom: float = r.size.x - 110 - (font.get_string_size(eff_txt + "  ·  ", HORIZONTAL_ALIGNMENT_LEFT, -1, ifs).x if eff_txt != "" else 0.0)
			var cut := info
			while cut.length() > 12 and font.get_string_size(cut, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs).x > iroom:
				cut = cut.left(cut.length() - 2).strip_edges() + "…"      # (still too long for the card: cut it)
			fit = [ifs, cut]
			if _fit_memo.size() > 400:
				_fit_memo.clear()
			_fit_memo[fit_key] = fit
		var ifs: int = fit[0]
		info = fit[1]
		if eff_txt != "":
			# the efficiency breakdown first, in its bar's colour, then the rest
			_text(font, r.position + Vector2(90, 72), eff_txt, ifs, eff_col)
			var ew := font.get_string_size(eff_txt + "  ·  ", HORIZONTAL_ALIGNMENT_LEFT, -1, ifs).x
			_text(font, r.position + Vector2(90 + ew, 72), info, ifs, UiStyle.MUTED)
		else:
			_text(font, r.position + Vector2(90, 72), info, ifs, UiStyle.MUTED)
		if e is Unit and (e as Unit).kind == "balloon" and e.team == game.human:
			# who's in the basket: small icons in the top right corner, each with his health
			# and his powder under it (the name shrinks to make room)
			var ps: Array = (e as Unit).passengers
			for i in ps.size():
				if not is_instance_valid(ps[i]):
					continue
				var pic := _icon(ps[i].kind)
				var pqr := Rect2(_pass_icon_x(r, ps.size(), i), r.position.y + 6, 22, 22)
				UiStyle.draw_button(_ci, pqr.grow(1), false, false)
				if pic:
					_ci.draw_texture_rect(pic, pqr, false)
				var pf: float = ps[i].hp / maxf(ps[i].max_hp, 1.0)
				_ci.draw_rect(Rect2(pqr.position.x, pqr.end.y + 1, pqr.size.x * pf, 2), Color(0.3, 0.9, 0.3) if pf > 0.5 else Color(0.95, 0.4, 0.2))
				if ps[i]._pmax > 0.0:
					# his powder, under his health
					var pp := Rect2(pqr.position.x, pqr.end.y + 4, pqr.size.x, 2)
					_ci.draw_rect(pp, Color(0, 0, 0, 0.6))
					_ci.draw_rect(Rect2(pp.position, Vector2(pp.size.x * clampf(ps[i].powder / ps[i]._pmax, 0.0, 1.0), pp.size.y)), Unit.POWDER_BAR if ps[i].powder >= 1.0 else UiStyle.BAD)
		var shq: Array = NetPredict.shown_queue(game, e) if e is Building else [[], [], 0.0]     # (online: an order just given shows at once, pending)
		if e is Building and (e.team == game.human or game.spectating()) and not (shq[0] as Array).is_empty():
			var q: Array = shq[0]
			var pend: Array = shq[1]
			for i in q.size():
				var ic := _icon(_research_icon(String(q[i]).substr(1)) if Building.is_research(q[i]) else (_queue_icon(e as Building, i) if i < (e as Building).queue.size() else String(q[i])))
				var qr := Rect2(r.end.x - 44 - (q.size() - 1 - i) * 40, r.position.y + 8, 36, 36)
				var waiting: bool = i < pend.size() and bool(pend[i])
				if e.team == game.human and not game.spectating():
					_queue_rects.append({"rect": qr, "b": e, "i": i})
					if Settings.pc() and qr.has_point(_mouse()):
						_ci.draw_rect(qr.grow(2), UiStyle.BAD, false, 1.5)
				if ic:
					_ci.draw_texture_rect(ic, qr, false, Color(1, 1, 1, 0.6) if waiting else Color.WHITE)
				if waiting:
					# (not confirmed by the host yet: a faint breathing frame)
					_ci.draw_rect(qr.grow(1), Color(1, 0.88, 0.4, 0.45 + 0.3 * sin(Time.get_ticks_msec() / 160.0)), false, 1.0)
				var eb := e as Building
				if i == 0 or eb.uses_eggs():
					var f: float = (float(eb.morph_t[i]) if eb.uses_eggs() and i < eb.morph_t.size() else (float(shq[2]) if not eb.uses_eggs() else 0.0)) / Building.entry_time(q[i])
					_ci.draw_rect(Rect2(qr.position.x, qr.end.y + 2, qr.size.x * f, 4), Color(0.75, 0.55, 1.0) if Building.is_research(q[i]) else Color(0.4, 0.75, 1))
				if Building.is_research(q[i]):
					_ci.draw_rect(qr, Color(0.75, 0.55, 1.0, 0.9), false, 1.5)     # research: a violet frame
	else:
		var n := mini(sel.size(), 24)
		var per_row := int((r.size.x - 20) / 38)
		var men: Array = sel.filter(func(x: Entity) -> bool: return x is Unit and Defs.ARMOURED.has(x.kind) and x.team == game.human)
		if not men.is_empty():
			# the soldiers' refits, counted, at the right (the portraits make room)
			var cw := 200.0
			var bits: Array = []
			var arm: int = men.filter(func(u: Unit) -> bool: return u.armoured).size()
			if game.has_tech(game.human, "armour") or arm > 0:
				bits.append("Armour %d/%d" % [arm, men.size()])
			var musk: Array = men.filter(func(u: Unit) -> bool: return u.kind == "musketeer")
			var bay: int = musk.filter(func(u: Unit) -> bool: return u.bayonet).size()
			if game.has_tech(game.human, "bayonet") or bay > 0:
				bits.append("Bayonet %d/%d" % [bay, musk.size()])
			var pch: Array = men.filter(func(u: Unit) -> bool: return Defs.MUSKETS.has(u.kind))
			var pn: int = pch.filter(func(u: Unit) -> bool: return u.pouch).size()
			if game.has_tech(game.human, "pouch") or pn > 0:
				bits.append("Pouch %d/%d" % [pn, pch.size()])
			for li in range(Defs.LOCKS.size() - 1, -1, -1):
				var lk: String = Defs.LOCKS[li]
				var c: int = men.filter(func(u: Unit) -> bool: return u.lock == lk).size()
				if c > 0:
					bits.append("%s %d" % [Defs.RESEARCH[lk]["name"], c])
			var plain: int = musk.filter(func(u: Unit) -> bool: return u.lock == "").size()
			if plain > 0 and (plain < musk.size() or game.best_lock(game.human) != ""):
				bits.append("no lock %d" % plain)
			var going: int = men.filter(func(u: Unit) -> bool: return u.order == "refit").size()
			if going > 0:
				bits.append("refitting %d" % going)
			if not bits.is_empty():
				per_row = maxi(4, int((r.size.x - 20 - cw) / 38))
			var lines: Array = [""]
			bits = bits.map(func(x: String) -> String: return Loc.t(x))
			for bt in bits:
				var tryl: String = (lines[-1] + " · " + bt) if lines[-1] != "" else bt
				if font.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > cw - 8 and lines[-1] != "":
					lines.append(bt)
				else:
					lines[-1] = tryl
			for li in mini(lines.size(), 3):
				_text(font, Vector2(r.end.x - cw, r.position.y + 46 + li * 17), lines[li], 14, Color(0.85, 0.88, 0.95))
		_portraits = []
		for i in n:
			var e: Entity = sel[i]
			var ir := Rect2(r.position + Vector2(10 + (i % per_row) * 38, 8 + (i / per_row) * 40), Vector2(34, 34))
			_portraits.append({"rect": ir, "e": e})
			if Settings.pc() and ir.has_point(_mouse()):
				_ci.draw_rect(ir.grow(2), UiStyle.TRIM_DIM, false, 1.0)
			var ic := _unit_icon(e)
			if ic:
				_ci.draw_texture_rect(ic, ir, false)
			var f := e.hp / e.max_hp
			_ci.draw_rect(Rect2(ir.position.x, ir.end.y, ir.size.x * f, 3), Color(0.3, 0.9, 0.3) if f > 0.5 else Color(0.95, 0.4, 0.2))
			if e is Unit and (e as Unit).kills > 0:
				_text(UiStyle.bold_font(), Vector2(ir.end.x - 1, ir.position.y + 11), str((e as Unit).kills), 12, Color(1, 0.82, 0.3), 2)
		if sel.size() > n:
			_text(font, r.end - Vector2(40, 10), "+%d" % (sel.size() - n), 16, Color.WHITE)
	# Deselect button
	var x := Rect2(r.end.x - 30, r.position.y + 2, 28, 28)
	if sel.size() != 1 or not (sel[0] is Building and sel[0].team == game.human and not (sel[0] as Building).queue.is_empty()):
		UiStyle.draw_button(_ci, x, Settings.pc() and x.has_point(_mouse()))
		_text(UiStyle.bold_font(), x.get_center() + Vector2(0, 6), "×", 16, UiStyle.TEXT, 1)
		_buttons_extra = [{"rect": x, "cb": func() -> void: game.set_selection([]), "enabled": true}]
	else:
		_buttons_extra = []
	for qe in _queue_rects:
		var qb: Building = qe["b"]
		var qi: int = qe["i"]
		_buttons_extra.append({"rect": qe["rect"], "enabled": true, "cb": func() -> void:
			if is_instance_valid(qb) and not qb.dead:
				game.cancel_train_at(qb, qi)})
	if sel.size() > 1:
		for pt in _portraits:
			var pe: Entity = pt["e"]
			_buttons_extra.append({"rect": pt["rect"], "enabled": true, "cb": func() -> void: _portrait_pressed(pe)})


var _portraits: Array = []


## The pistol on the unit card: "Pistol LOADED" / "Pistol EMPTY: reloading 2.1 s" ...
static func pistol_text(u: Unit) -> String:
	var t := "Pistol LOADED" if u.pistol else "Pistol EMPTY"
	if not u.pistol:
		if u.is_mounted():
			t += ": reloads on foot"
		elif u.powder < float(Defs.PISTOL["powder"]):
			t += ": no powder to reload"
		elif u.pistol_t > 0.0:
			t += ": reloading %.1f s" % maxf(float(Defs.PISTOL["reload"]) - u.pistol_t, 0.0)
		else:
			t += ": reloads when out of the fight"
	if u.hold_fire:
		t += " (HOLD FIRE)"
	return t


## A small flintlock pistol (barrel, lock, grip) at p, about 24 x 12: bright when loaded,
## grey with a red bar when empty.
func _draw_pistol(p: Vector2, loaded: bool) -> void:
	var steel := Color(0.85, 0.87, 0.9) if loaded else Color(0.45, 0.45, 0.48)
	var wood := Color(0.62, 0.38, 0.18) if loaded else Color(0.35, 0.28, 0.22)
	_ci.draw_rect(Rect2(p + Vector2(6, 1), Vector2(16, 3)), steel)                 # barrel
	_ci.draw_rect(Rect2(p + Vector2(4, 0), Vector2(6, 5)), wood)                   # stock
	_ci.draw_colored_polygon(PackedVector2Array([p + Vector2(4, 3), p + Vector2(9, 3), p + Vector2(5, 11), p + Vector2(0, 10)]), wood)   # grip
	_ci.draw_rect(Rect2(p + Vector2(8, -1), Vector2(3, 2)), steel)                 # the cock
	if loaded:
		_ci.draw_circle(p + Vector2(23, 2.5), 1.5, Color(1.0, 0.8, 0.3))
	else:
		_ci.draw_line(p + Vector2(0, 11), p + Vector2(22, -2), UiStyle.BAD, 2.0)


## A unit's (or building's) portrait: its own, its sprites' (a Guardsman, a Horseman), or the
## one standing in for it (Defs.TEMP_ART, light or armoured).
func _unit_icon(e: Entity) -> Texture2D:
	if e is Unit and Defs.TEMP_ART.has(e.kind):
		return _icon(Defs.icon_for(Defs.train_key(e.kind, (e as Unit).armoured)))
	var icon := _icon(e.kind)
	if e is Building and (e as Building).level > 1 and _icon(String((e as Building).level_info().get("art", ""))):
		icon = _icon(String((e as Building).level_info()["art"]))     # (a Warren, a Broodmound)
	if e is Unit and (e as Unit).art != e.kind and _icon((e as Unit).art):
		icon = _icon((e as Unit).art)      # (a Guardsman, a Horseman)
	return icon


## The instant buttons of a unit card that wait their turn when Shift is held: each man
## gets the button as an order behind his move or attack, and runs it when he gets there
## (the button works on the selection, so it runs with just that man selected).
const SHIFT_QUEUE := ["horse_lead", "horse_release", "horse_mount", "horse_dismount", "horse_unhitch", "horse_harness",
	"stop", "hold", "hold_fire", "fire_at_will", "ab_hold_gas", "ab_spit", "ab_brace", "ab_land", "ab_canister", "ab_round_shot",
	"ab_courier", "ab_limber", "ab_root", "ab_deploy", "ab_mortar_deploy", "ab_supply", "ab_sacrifice", "ab_shield"]


func _shift_queueable(list: Array) -> void:
	for entry in list:
		if not SHIFT_QUEUE.has(String(entry[0])) or not entry[3]:
			continue
		var cb: Callable = entry[2]
		entry[2] = func() -> void:
			if not (Settings.pc() and Input.is_key_pressed(KEY_SHIFT)):
				cb.call()
				return
			for u in game.selected_units():
				u.give({"o": "act", "fn": func(m: Unit) -> void:
					var keep: Array = game.selection
					game.selection = [m]
					cb.call()
					game.selection = keep}, true)


## Horse commands for the men (LEAD, RELEASE, MOUNT, DISMOUNT) and for guns and wagons
## (RELEASE HORSE, HARNESS) in the selection.
func _horse_buttons(list: Array, units: Array) -> void:
	var leaders := units.filter(func(u: Unit) -> bool: return u.can_lead())
	if not leaders.is_empty():
		var near := _free_horse_near(leaders.filter(func(u: Unit) -> bool: return u.lead_count() < int(Defs.HORSES["lead_max"])), true)
		list.append(["horse_lead", "LEAD", func() -> void:
			var n := game.lead_order(game.selected_units())
			toast("Fetching %d horse%s by the reins." % [n, "" if n == 1 else "s"] if n > 0 else "No free horse nearby."), near, "No free horse of yours within %d tiles." % int(Defs.HORSES["fetch"]), ""])
		var held := 0
		for u in leaders:
			held += u.led.size()
		if held > 0:
			list.append(["horse_release", "RELEASE", func() -> void:
				for u in game.selected_units():
					u.release_horses()
				toast("Released: the horses graze where they stand."), true, "", str(held)])
	var riders := units.filter(func(u: Unit) -> bool: return u.can_mount())
	if not riders.is_empty():
		var any := _free_horse_near(riders, false)
		list.append(["horse_mount", "MOUNT", func() -> void:
			var n := game.mount_order(game.selected_units())
			if n == 0:
				toast("No free horse nearby."), any, "No free horse of yours within %d tiles." % int(Defs.HORSES["fetch"]), ""])
	var mounted := units.filter(func(u: Unit) -> bool: return u.is_mounted() and u.order != "dismount")
	if not mounted.is_empty():
		list.append(["horse_dismount", "DISMOUNT", func() -> void:
			for u in game.selected_units():
				if u.is_mounted():
					u.cmd_dismount(), true, "", ""])
	var guns := units.filter(func(u: Unit) -> bool: return Defs.HARNESSED.has(u.kind))
	if not guns.is_empty():
		var hitched := guns.filter(func(u: Unit) -> bool: return u.harnessed)
		if not hitched.is_empty():
			list.append(["horse_unhitch", "RELEASE HORSE", func() -> void:
				for u in game.selected_units():
					if Defs.HARNESSED.has(u.kind):
						u.release_horse(), true, "", ""])
		var roomy := guns.filter(func(u: Unit) -> bool: return u.team_room())
		if not roomy.is_empty():
			# (one more horse for each: up to Defs.HORSES team_max in a team)
			var g0: Unit = roomy[0]
			var free := g0.nearest_free_horse(float(Defs.HORSES["fetch"])) != null
			list.append(["horse_harness", "HARNESS", func() -> void:
				var n := game.harness_order(game.selected_units())
				if n == 0:
					toast("No free horse nearby."), free, "No free horse of yours within %d tiles." % int(Defs.HORSES["fetch"]), ""])
## Has any of these men a free horse within Defs.HORSES "fetch" tiles (Unit.nearest_free_horse, his own led
## ones left out when `skip_led`)? Asked of the horses on the map, not of everyone near each man: with a
## hundred Musketeers selected that took 14 ms, four times a second.
func _free_horse_near(us: Array, skip_led: bool) -> bool:
	if us.is_empty():
		return false
	var horses: Array = []
	for o in game.units:
		if o.kind == "horse" and not o.dead:
			horses.append(o)
	if horses.is_empty():
		return false
	var r := float(Defs.HORSES["fetch"]) * Defs.TILE
	for u in us:
		for o in horses:
			if o.position.distance_to(u.position) < r and not (skip_led and u.led.has(o)) and Unit.horse_free_for(o, u) and (o.leader == null or o.leader == u):
				return true
	return false


var _queue_rects: Array = []        # the production line's pictures in the card: click = cancel that one


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


## More buttons than the card holds (a big mixed selection): pages, with MORE on each.
var _card_page := 0
var _card_sig := ""


func _paged(all: Array) -> Array:
	var slots := _cols() * _rows()
	var sig := "%s|%d|%s" % [page, game.selection.size(), str(game.selection[0].get_instance_id()) if not game.selection.is_empty() and is_instance_valid(game.selection[0]) else ""]
	if sig != _card_sig:
		_card_sig = sig
		_card_page = 0       # a new selection starts on the first page
	if all.size() <= slots:
		return all
	var per := slots - 1
	var pages := int(ceil(all.size() / float(per)))
	_card_page = clampi(_card_page, 0, pages - 1)
	var out: Array = all.slice(_card_page * per, _card_page * per + per)
	out.append(["more", "MORE", func() -> void: _card_page = (_card_page + 1) % pages, true, "", "%d/%d" % [_card_page + 1, pages]])
	return out


## At each look: the command card's buttons (what they are, where, what they do) and a short
## text of how they look (the card is redrawn when it changes).
var _card_look := ""
var _card_fresh := true
var _card_wait := 0


func _refresh_card() -> void:
	var _q := Time.get_ticks_usec()
	var items := _with_keys(_paged(_build_card()))
	_card_items = items
	var buttons: Array = []
	var look := PackedStringArray()
	if not items.is_empty():
		var cr := card_rect()
		var bsz := _btn()
		look.append(str(cr))
		for i in mini(items.size(), _cols() * _rows()):
			var it: Array = items[i]
			var br := Rect2(cr.position + Vector2(2 + (i % _cols()) * bsz, 2 + (i / _cols()) * bsz), Vector2(bsz - 4, bsz - 4))
			var bt := {"rect": br, "cb": it[2], "enabled": it[3], "why": it[4], "item": it}
			var plain := String(it[1]).trim_prefix("> ").trim_prefix("~ ")
			if _alt_for.has(plain):
				bt["alt"] = _alt_for[plain]
			buttons.append(bt)
			look.append("%s|%s|%s|%s|%s" % [it[0], it[1], it[3], it[5], it[6] if it.size() > 6 else ""])
	_card_buttons = buttons
	_card_look = ";".join(look)
	Prof.add("hud/card build", _q)


## Every button the HUD has besides the quick ones: the panel's, MENU and the card's.
func _all_buttons() -> Array:
	var extra: Array = [{"rect": menu_rect(), "cb": func() -> void: toggle_menu(not menu_open), "enabled": true}]
	if _chat_button_on():
		extra.append({"rect": chat_btn_rect(), "cb": func() -> void: quick_open = not quick_open, "enabled": true})
	return _buttons_extra + extra + _card_buttons


func _draw_card(font: Font) -> void:
	if _card_buttons.is_empty():
		return
	var cr := card_rect()
	UiStyle.draw_panel(_ci, cr.grow(4), UiStyle.accent(game.faction_of(game.human)))
	var hover := _mouse() if Settings.pc() else Vector2(-1, -1)
	for bt in _card_buttons:
		var it: Array = bt["item"]
		var br: Rect2 = bt["rect"]
		var enabled: bool = it[3]
		var ic := _icon(it[0])
		var hov := br.has_point(hover)
		var on := String(it[1]).begins_with("> ")
		var pushed := _card_flash != "" and String(it[1]).trim_prefix("> ").trim_prefix("~ ") == _card_flash
		if pushed:
			br = Rect2(br.position + Vector2(0, 2), br.size)
		UiStyle.draw_button(_ci, br, hov, on or pushed, enabled)
		if pushed:
			_ci.draw_rect(br, Color(0, 0, 0, 0.22))
		if ic:
			_ci.draw_texture_rect(ic, br.grow(-3), false, Color.WHITE if enabled else Color(0.4, 0.4, 0.4, 0.8))
		_ci.draw_rect(Rect2(br.position.x + 2, br.end.y - 17, br.size.x - 4, 15), Color(0, 0, 0, 0.62))
		# the label at 11, smaller only when it wouldn't fit the (phone's narrower) button
		var lab := Loc.t(String(it[1]).trim_prefix("> ").trim_prefix("~ "))
		var lsz := 11
		while lsz > 8 and UiStyle.bold_font().get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz).x > br.size.x - 5:
			lsz -= 1
		if UiStyle.bold_font().get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz).x > br.size.x - 5:
			lab = lab.replace(Loc.t("ARMOURED ").strip_edges() + " ", Loc.t("ARM. ").strip_edges() + " ")      # (Armoured Dragoon / Officer: still too long)
		_text(UiStyle.bold_font(), Vector2(br.get_center().x, br.end.y - 5), lab, lsz, (Color(1, 0.9, 0.55) if on else UiStyle.TEXT) if enabled else Color(1, 1, 1, 0.45), 1)
		if it[5] != "":
			var cw := font.get_string_size(it[5], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8
			var cbr := Rect2(br.end.x - cw - 2, br.position.y + 2, cw, 15)
			_ci.draw_rect(cbr, Color(0, 0, 0, 0.7))
			_text(UiStyle.bold_font(), Vector2(cbr.get_center().x, cbr.end.y - 3), it[5], 12, Color(1, 0.86, 0.4) if enabled else Color(1, 0.86, 0.4, 0.5), 1)
		if Settings.pc() and it.size() > 6 and it[6] != "":
			var kr := Rect2(br.position + Vector2(2, 2), Vector2(16, 16))
			if String(it[6]).length() > 1:
				kr.size.x = UiStyle.bold_font().get_string_size(it[6], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 6.0     # (^A)
			_ci.draw_rect(kr, Color(0.1, 0.08, 0.05, 0.85))
			_ci.draw_rect(kr, UiStyle.TRIM_DIM, false, 1.0)
			_text(UiStyle.bold_font(), kr.position + Vector2(kr.size.x * 0.5, 13), it[6], 12, Color(1, 0.92, 0.6), 1)


## Autocast (WORK, PUSH): a golden outline that breathes, with sparks running round it.
func _autocast_glow(br: Rect2) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var a := 0.55 + 0.35 * sin(t * 4.0)
	_ci.draw_rect(br.grow(1), Color(1.0, 0.82, 0.3, a), false, 2.0)
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
		_ci.draw_circle(p, 3.5, Color(1, 0.95, 0.6, 0.95))
		_ci.draw_circle(p, 6.0, Color(1, 0.8, 0.3, 0.3))


## A resource readout in the top bar; returns where the next one starts.
func _pill(font: Font, x: float, dot: Color, value: String, col: Color, box := false, gear := false, pic: Texture2D = null) -> float:
	var vw := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var w := 36.0 + vw + 14.0
	var r := Rect2(x, 4, w, 30)
	UiStyle.draw_panel(_ci, r, Color(0, 0, 0, 0), 0.8)
	if pic:
		_ci.draw_texture_rect(pic, Rect2(x + 6, 7, 24, 24), false)      # (the Clockwork's TENSION: the wound mainspring)
	elif gear:
		# the Clockwork's COGS: a small gear drawn in code (placeholder resource icon: docs/art_style_inconsistency.md)
		_ci.draw_set_transform(Vector2(x + 18, 19), 0.0, Vector2.ONE)
		GearNet.draw_gear(_ci, 9, 9.0, Color(0.93, 0.8, 0.46), Color(0.2, 0.13, 0.06), Color(0, 0, 0, 0), 0.95)
		_ci.draw_circle(Vector2.ZERO, 2.6, Color(0.12, 0.09, 0.05))
		_ci.draw_set_transform(Vector2.ZERO)
	elif box:
		_ci.draw_rect(Rect2(x + 10, 11, 14, 16), dot)
		_ci.draw_rect(Rect2(x + 10, 11, 14, 16), Color(0, 0, 0, 0.5), false, 1.0)
	else:
		_ci.draw_circle(Vector2(x + 18, 19), 8, dot)
		_ci.draw_arc(Vector2(x + 18, 19), 8, 0, TAU, 18, Color(1, 1, 1, 0.45), 1.5)
	_text(font, Vector2(x + 34, 26), value, 20, col)
	return x + w + 8


func _res() -> Array:
	return Defs.res_names(game.faction_of(game.human))


# ------------------------------------------------------------------ tooltips
## Computer: rest the mouse on a card button (briefly), or on a unit, building, resource or
## quick button (a little longer), and a tooltip opens by the cursor. Phone: the "?" button
## in the top bar arms help mode; the next tap explains what it lands on instead of acting.
## Settings > TOOLTIPS switches both off. Clockwork units and buildings in the world have
## none yet. A tooltip is only drawn: it never takes a click.

const TIP_CARD_DELAY := 0.35     # command card: almost at once (it always was)
const TIP_HUD_DELAY := 0.8       # resources, quick buttons
const TIP_WORLD_DELAY := 1.5     # units and buildings on the map
const TIP_HIDE := 0.25           # it lingers this long after the mouse leaves
const TIP_PIN := 7.0             # phone: a tapped tooltip stays this long (or until the next touch)
const TIP_W := 320.0

var help_mode := false           # phone: the next tap explains instead of acting
var _tip := {}                   # shown: {title, key, stats, need, body, hint}
var _tip_at := Vector2.ZERO      # where it hangs from (HUD coordinates)
var _hover_id := ""
var _hover_ms := 0
var _tip_ms := 0                 # last time it was (re)shown
var _pill_rects: Array = []      # top bar: [rect, 0 res / 1 res2 / 2 supply]

const CMD_TIPS := {
	"MOVE": "Then pick where to go: they walk there without stopping to fight.",
	"ATTACK": "Then pick a target, or a place: they walk there fighting everything they meet.",
	"STOP": "Drop every order and stand.",
	"HOLD": "Stand here and fight whatever comes in reach, without chasing.",
	"PATROL": "Then pick a place: they walk there and back, again and again, fighting whatever they meet on the way.",
	"BUILD": "Every building this worker can put up.",
	"RALLY": "Then pick where new units gather when they come out.",
	"GRUBS": "Then pick a Feeding Pit (or a spot) for new grubs.",
	"BACK": "Back to the orders.",
	"MORE": "The next page of buttons.",
	"DEMOLISH": "Pull the building down: press twice. Nothing comes back.",
	"ABANDON": "Cancel the building: three quarters of its cost come back (all of it if work never began).",
	"PLACE": "Build it at the marked spot.",
	"START": "Mark where the wall starts.",
	"END": "Mark where the wall ends (the same spot for a single piece).",
	"ROTATE": "Turn the gate the other way. It stays that way.",
	"SUPPLY": "Keg runs (glowing = on): while the wagon has room, the Town Hall's haulers (right-click Labourers onto the Town Hall) carry kegs to it from the nearest Powder Mill. A Labourer killed with a keg blows up.",
	"UNLIMBER": "Set the gun up to fire (2.5 s). It can't move until it limbers again.",
	"LIMBER": "Hitch the gun to the horse to move it (2.5 s). It can't fire while limbered.",
	"DEPLOY": "Set it up to fire (3 s). It can't move until it packs up.",
	"PACK": "Pack it up to move (3 s). It can't fire while packed.",
	"CANISTER": "Short range, a cone of musket balls: big damage, +50% against Light units, and it hits flyers.",
	"ROUND SHOT": "The longest range in the game. The ball ploughs through a line of men, YOUR OWN TOO, and smashes buildings. Can't hit flyers.",
	"HARVEST": "The grubs wrap every body nearby (friend or foe) in a cocoon and carry it to a Burrow (or Warren, Broodmound) as essence. Bodies rot after 2 minutes.",
	"SACRIFICE": "The selected creatures (not grubs) go to the nearest Brood Pen and are offered up: 12% of their biomass cost as essence.",
	"HOLD GAS": "Stop spitting and keep the sac full: the Bloater drifts in and bursts as a huge acid bomb.",
	"HOLD FIRE": "Pistols (glowing = on): Horsemen, Cuirassiers and Officers keep their one pistol shot and fight with the sabre only, until you turn it off. (HOLD is still stand-ground.)",
	"SPIT": "Lob acid from range. Every glob uses gas, so the final burst gets smaller.",
	"FOG": "50 energy: a fog bank on a spot for 12 s. Shots fired from or into it miss half the time (yours too); units inside see 2 tiles.",
	"TONGUE": "75 energy: mark an enemy on the ground for 3 s, then drag it to the Toad's feet. Heavy engines are only staggered.",
	"MIASMA": "30 essence: a green cloud for 8 s. Brood inside heal up to 30% of their health. Then 18 s to recover.",
	"ROOT": "Dig in (2.5 s): she lobs splashing spit blobs and spreads swamp, but can't move.",
	"UPROOT": "Walk again (2.5 s). Walking, she can't attack.",
	"LAND": "Land (1.2 s) to bite ground units. Landed, anything can hit it, and it can't touch flyers.",
	"TAKE OFF": "Fly again (1.2 s) and hunt flyers with spines.",
	"LOAD": "Then tap Musketeers or Labourers (4 at most): they climb in. Men selected with the balloon climb in at once.",
	"UNLOAD": "Then pick where to drop them: the balloon flies there and lets everyone off.",
	"DROP HERE": "Let everyone off right below the balloon.",
	"LOAD CREW": "Then tap Winders (4 at most): they crew the Spring Ballista, each +10% reload and move speed. Winders selected with it climb on at once.",
	"UNLOAD CREW": "Its crew step off where they stand (its own built-in Winder stays).",
	"BOARD": "These Winders crew your nearest Spring Ballista with room: they push it and crank it (each +10% reload and move speed), and can be shot.",
	"RESTOCK": "Fly to the nearest powder (Wagon, Mill, Barracks or Hall) and haul kegs up until the 40-shot store is full.",
	"ATTACK GROUND": "Then click a spot on the ground (in the fog too), or hold and drag a line to share it out among them: they keep attacking it until you give another order. Bodies have health and rot, faster the longer they lie; hitting them speeds that up, and a body brought to 0 is torn up: the Brood can't harvest it, a Missionary can't raise it (yours too). Guns, mortars and Spore Mothers blast them; shooters shoot along the line; melee units and workers walk up and strike them (workers slowly).",
}

func _cost_text(a: int, b: int) -> String:
	var r := _res()
	var t := "%d %s" % [a, String(r[0]).to_lower()]
	if b > 0:
		t += " + %d %s" % [b, String(r[1]).to_lower()]
	return t


## The price in a card button's corner: the first resource; a Tension price (gear mode's Clockwork) as cogs+tension.
func _price_chip(price: Array, tension: bool) -> String:
	if tension and int(price[1]) > 0:
		return "%d+%d" % [int(price[0]), int(price[1])]
	return str(int(price[0]))


## The tooltip for a command card button (it: the card item, with its key at [6]).
func _card_tip(it: Array) -> Dictionary:
	var lab: String = String(it[1]).trim_prefix("> ").trim_prefix("~ ")
	var k: String = it[0]
	var t := {"title": lab.capitalize(), "key": String(it[6]) if Settings.pc() and it.size() > 6 else ""}
	var b := game.selected_building()
	var rk := _research_of(lab)
	if _tip_for.has(lab):
		t["title"] = _tip_for[lab][0]
		t["body"] = _tip_for[lab][1]
		if (_tip_for[lab] as Array).size() > 2:
			t["stats"] = _tip_for[lab][2]
	elif b and rk != "" and Defs.RESEARCH[rk]["at"] == b.kind:
		var ri: Dictionary = Defs.RESEARCH[rk]
		t["title"] = "Research: %s" % ri["name"]
		t["stats"] = "%s  ·  %d s" % [_cost_text(int(ri["cost"]), int(ri.get("cost2", 0)) + Defs.tension_cost(ri)), int(ri["time"])]
		t["body"] = Defs.tip(rk)
		t["hint"] = "Queued like a unit; CANCEL takes it back out (paid back)."
	elif (Defs.UNITS.has(k) or Defs.TRAIN_AS.has(k)) and lab == Defs.train_name(k).to_upper():
		var kd := Defs.train_kind(k)
		var u: Dictionary = Defs.UNITS[kd]
		var price := game.unit_price(game.human, k)
		var n := int(u.get("spawn", 1))
		var arm := Defs.train_armoured(k)
		t["title"] = Defs.train_name(k)
		t["stats"] = "%s  ·  %d s  ·  %d supply%s" % [_cost_text(price[0], price[1]), int(u["time"]), int(u["supply"]) * n, ("  ·  %d an egg" % n) if n > 1 else ""]
		var tg: Array = ["armored"] if arm else u.get("tags", [])
		t["body"] = ("[%s] " % " ".join(tg.map(func(x: String) -> String: return x.capitalize())) if not tg.is_empty() else "") + Defs.tip(k)
		if Defs.ARMOURED.has(kd):
			var kt := game.kit_for_new(game.human, k)
			var parts: Array = []
			if kt.get("armour", false):
				parts.append("Armour")
			if String(kt.get("lock", "")) != "":
				parts.append(Defs.RESEARCH[kt["lock"]]["name"])
			if kt.get("bayonet", false):
				parts.append("the Socket Bayonet")
			if not parts.is_empty():
				t["body"] += "  Comes out with %s (the refit fees are in the price)." % ", ".join(parts)
		t["hint"] = ("Right-click" if Settings.pc() else "Hold") + ": train it automatically (glows while on)."
	elif Defs.BUILDINGS.has(k) and page in ["build", "advanced"]:
		var bd: Dictionary = Defs.BUILDINGS[k]
		t["title"] = bd["name"]
		var st := "%s  ·  %d s" % [_cost_text(int(bd["cost"]), int(bd.get("cost2", 0)) + Defs.tension_cost(bd)), int(bd["time"])]
		if int(bd.get("supply", 0)) > 0 and k != game.faction_hall(game.human):
			st += "  ·  +%d supply" % int(bd["supply"])
		if Defs.is_econ(k):
			if k == "feeding_pit" and game.faction_of(game.human) == "brood":
				st += "  ·  %d built  ·  reach %d tiles from the capital" % [game.econ_count(game.human, k), int(game.swamp_reach[game.human])]
			else:
				st += "  ·  %d of %d here" % [game.econ_count(game.human, k), game.econ_limit(game.human, k)]
		t["stats"] = st
		t["body"] = Defs.tip(k)
	elif lab == "WORK":
		t["body"] = "Automatic work (glowing = on): idle workers go back to their posts by themselves. Press to switch it off, to scout or keep a builder free."
	elif lab == "REPAIR":
		t["body"] = "Then pick a damaged building or wall: they fix it (a full repair costs a quarter of its price)."
		t["hint"] = ("Right-click" if Settings.pc() else "Hold") + ": automatic repair (glows while on)."
	elif lab == "CANCEL" and controls.mode == "" and b:
		t["body"] = "Take the last thing in the queue back out (paid back)."
	elif lab == "CANCEL":
		t["body"] = "Back out of this without doing it."
	elif Defs.TIPS.has(lab):
		t["body"] = Defs.TIPS[lab]       # (the horse commands)
	elif CMD_TIPS.has(lab):
		t["body"] = CMD_TIPS[lab]
	if not it[3] and String(it[4]) != "":
		t["need"] = it[4]         # what's missing, in red
	return t


func _research_of(lab: String) -> String:
	for rk in Defs.RESEARCH:
		if Defs.research_label(rk) == lab:
			return rk
	return ""


## A unit or building in the world, yours or not: name, health and a line about it.
func _entity_tip(e: Entity) -> Dictionary:
	if not is_instance_valid(e) or e.dead or not (e is Unit or e is Building):
		return {}
	var d: Dictionary = e.d
	if String(d.get("faction", "")) == "clockwork":
		return {}                # (their tooltips come later)
	var name := String(d["name"])
	if int(d.get("spawn", 1)) > 1:
		name = name.trim_suffix("s")      # one of the Raptors is a Raptor
	var t := {"title": name + ("  (enemy)" if e.team >= 0 and e.team != game.human and not game.demo else "")}
	var st := "%d / %d health" % [int(ceil(e.hp)), int(e.max_hp)]
	if int(d.get("armor", 0)) > 0:
		st += "  ·  armour %d" % int(d["armor"])
	var tg: Array = d.get("tags", [])
	if not tg.is_empty():
		st += "  ·  " + " ".join(tg.map(func(x: String) -> String: return x.capitalize()))
	if e is Building and not (e as Building).built:
		st += "  ·  %d%% built" % int((e as Building).progress * 100)
	t["stats"] = st
	t["body"] = Defs.tip(Defs.train_key(e.kind, (e as Unit).armoured) if e is Unit else e.kind)
	return t


## The top bar: the two resources and supply.
func _res_tip(i: int) -> Dictionary:
	var fac := game.faction_of(game.human)
	var pl: Dictionary = game.players[game.human]
	var r := _res()
	if fac == "clockwork":
		if Defs.gear_mode and i == 0:
			return {"title": "Cogs: %d" % int(pl["gold"]), "body": "The Clockwork's money. Winders winding a Cog Press press them out of the Clocktower's brass; the Clocktower takes them in at once. Everything is bought with cogs."}
		if Defs.gear_mode and i == 1:
			return {"title": Loc.t("Tension: %d of %d") % [int(float(pl.get("tension", 0.0))), int(GearEcon.tension_cap(game, game.human))], "body": "The Clockwork's second resource, wound by Winders cranking a Mainspring. Each Mainspring stores 200 Tension (big gear: 400): winding stops when you hold what your Mainsprings store. It pays for the strong things: the Springer, the Swift, the Netter, the Pendulum, the Spring Ballista, the Clock Aviary and the research. Anything that costs Tension is made only at a building whose gear ring meshes with a Mainspring's: the Escapement, the Clock Aviary, the Heavy Works, and a Light Works for its Springers and Netters."}
		if i != 2:
			return {}
	if i == 3:
		var hs: Array = game.horses_of(game.human)
		var led := hs.filter(func(h: Unit) -> bool: return h.leader != null).size()
		return {"title": "%s, %d led" % [game.horses_text(game.human), led],
			"body": "Your free horses (riders' and guns' horses aren't counted); reserved ones are kept for a recruit in a queue. Horse Breeders sell them (40 gold each). Training a Horseman, Cuirassier, Field Cannon, Mortar or Powder Wagon takes a horse standing at its building, else a free one at a breeder, else a breeder trains one for it (40 gold more): one click does both. Any man can MOUNT a free horse. Left alone near an enemy man, a horse is stolen."}
	if i == 2:
		var sup: String = Defs.BUILDINGS[Defs.supply_kind(fac)]["name"]
		var sp := _supply_split(game.human)
		return {"title": "Supply: %d of %d used" % [game.supply_used(game.human), int(pl["cap"])],
			"body": "Workers %d · Army %d · In production %d.\nEvery unit takes supply. Each %s and %s raises the cap, up to %d." % [sp["workers"], sp["army"], sp["queued"], sup, Defs.BUILDINGS[game.faction_hall(game.human)]["name"], game.max_supply(game.human)]}
	var body: String = {
		"crown": ["Pays for everything. Labourers on Farms bring in the harvests; a Town Hall's soil runs out in time.",
			"Black powder for muskets, cannons and mortars, and for refilling soldiers. Labourers grind it at the Powder Mill."],
		"brood": ["Pays for everything. Grubs haul food from Feeding Pits to a Burrow: longer hauls pay more.",
			"Bodies falling near a Brood Pen, grubs on HARVEST, and SACRIFICE at the Pen. Pays for the big creatures."]}[fac][i]
	return {"title": "%s: %d" % [r[i], int(pl["gold"]) if i == 0 else int(pl["res2"])], "body": body}


## What sits at p (HUD coordinates): a candidate {id, delay, item / res / grp / e}, or {}.
func _hover_at(p: Vector2) -> Dictionary:
	for pr in _pill_rects:
		if (pr[0] as Rect2).has_point(p):
			return {"id": "res:%d" % pr[1], "delay": TIP_HUD_DELAY, "res": pr[1]}
	var hid := bar.hit(p)
	if hid >= 0:
		return {"id": "grp:%d" % hid, "delay": TIP_HUD_DELAY, "grp": hid}
	for b in _card_buttons:
		if (b["rect"] as Rect2).has_point(p):
			return {"id": "card:" + String(b["item"][1]), "delay": TIP_CARD_DELAY, "item": b["item"]}
	if _hud_has(p):
		return {}
	var e := game.entity_at(controls.to_world(p * ui_scale))
	if e:
		return {"id": "ent:%d" % e.get_instance_id(), "delay": TIP_WORLD_DELAY, "e": e}
	return {}


func _tip_of(c: Dictionary) -> Dictionary:
	if c.has("item"):
		return _card_tip(c["item"])
	if c.has("res"):
		return _res_tip(int(c["res"]))
	if c.has("e"):
		return _entity_tip(c["e"])
	if c.has("grp"):
		return bar.tip(int(c["grp"]))
	return {}


func help_rect() -> Rect2:
	var d := drag_rect()
	return Rect2(d.position.x - 46, 2, 40, 32)


func _help_on() -> bool:
	return not Settings.pc() and Settings.tooltips and not game.spectating()


## Phone, help mode: explain what the tap landed on.
func _help_tap(p: Vector2) -> void:
	help_mode = false
	var c := _hover_at(p)
	var t := _tip_of(c) if not c.is_empty() else {}
	if t.is_empty():
		toast("Nothing to explain there.", false)
		return
	_tip = t
	_tip_at = p
	_tip_ms = Time.get_ticks_msec()


## Each redraw: what the mouse rests on, and whether its tooltip is due (computer), or
## whether a tapped one has had its time (phone).
## Supply used by workers, by the army, and still in a production queue.
func _supply_split(t: int) -> Dictionary:
	var w := 0
	var a := 0
	for u in game.units:
		if u.team == t and not u.dead:
			if u.is_worker():
				w += int(u.d["supply"])
			else:
				a += int(u.d["supply"])
	var q: int = game.supply_used(t) - w - a
	return {"workers": w, "army": a, "queued": q}


func _update_tip() -> void:
	var now := Time.get_ticks_msec()
	if not Settings.tooltips or paused or menu_open or game.over or countdown > 0.0:
		_tip = {}
		_hover_id = ""
		help_mode = false
		return
	if not Settings.pc():
		if not _tip.is_empty() and now - _tip_ms > TIP_PIN * 1000.0:
			_tip = {}
		return
	var m := _mouse()
	var c := {}
	for b in _card_buttons:
		if (b["rect"] as Rect2).has_point(m):
			c = {"id": "card:" + String(b["item"][1]), "delay": TIP_CARD_DELAY, "item": b["item"]}
			break
	if c.is_empty() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and controls.box_rect().size == Vector2.ZERO:
		c = _hover_at(m)
	var id: String = c.get("id", "")
	if id != _hover_id:
		_hover_id = id
		_hover_ms = now
	if id != "" and now - _hover_ms >= float(c["delay"]) * 1000.0:
		var t := _tip_of(c)
		if not t.is_empty():
			_tip = t
			_tip_at = m
			_tip_ms = now
			return
	if not _tip.is_empty() and now - _tip_ms > TIP_HIDE * 1000.0:
		_tip = {}


## The tooltip: a warm panel by the cursor (above the finger on a phone), kept on screen.
func _draw_tip() -> void:
	if _tip.is_empty():
		return
	var vs := _vs()
	var bold := UiStyle.bold_font()
	var body_f := UiStyle.body_font()
	var title: String = Loc.title(String(_tip.get("title", "")))
	var key: String = _tip.get("key", "")
	var rows: Array = []        # [text, font, size, colour]
	for f in [["stats", bold, 14, UiStyle.TEXT], ["need", bold, 14, UiStyle.BAD], ["body", body_f, 14, Color(0.95, 0.91, 0.82)], ["hint", body_f, 13, UiStyle.MUTED]]:
		if String(_tip.get(f[0], "")) != "":
			rows.append([Loc.t(String(_tip[f[0]])), f[1], f[2], f[3]])
	var key_bw := maxf(17.0, bold.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 6.0) if key.length() > 1 else 17.0     # (^A)
	var key_w := key_bw + 5.0 if key != "" else 0.0
	var w := bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + key_w
	for r in rows:
		w = maxf(w, (r[1] as Font).get_string_size(r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, r[2]).x)
	w = clampf(w + 20.0, 150.0, TIP_W)
	var tw := w - 20.0
	var h := 30.0
	var heights: Array = []
	for r in rows:
		var rh: float = (r[1] as Font).get_multiline_string_size(r[0], HORIZONTAL_ALIGNMENT_LEFT, tw, r[2]).y
		heights.append(rh)
		h += rh + 3.0
	h += 6.0
	var pos: Vector2
	if Settings.pc():
		pos = _tip_at + Vector2(16, 20)
		if pos.x + w > vs.x - 6:
			pos.x = _tip_at.x - w - 10
		if pos.y + h > vs.y - 6:
			pos.y = _tip_at.y - h - 10
	else:
		pos = Vector2(_tip_at.x - w * 0.5, _tip_at.y - h - 28)      # above the finger
		if pos.y < top_rect().end.y + 4:
			pos.y = _tip_at.y + 28
	pos = pos.clamp(Vector2(6, 6), (vs - Vector2(w, h) - Vector2(6, 6)).max(Vector2(6, 6)))
	var rect := Rect2(pos, Vector2(w, h))
	UiStyle.draw_panel(_ci, rect, UiStyle.accent(game.faction_of(game.human)), 0.96)
	var x := rect.position.x + 10
	if key != "":
		var kr := Rect2(x, rect.position.y + 8, key_bw, 17)
		_ci.draw_rect(kr, Color(0.1, 0.08, 0.05, 0.9))
		_ci.draw_rect(kr, UiStyle.TRIM_DIM, false, 1.0)
		_text(bold, kr.position + Vector2(key_bw * 0.5, 13.5), key, 12, Color(1, 0.92, 0.6), 1)
	_ci.draw_string(bold, Vector2(x + key_w, rect.position.y + 22), title, HORIZONTAL_ALIGNMENT_LEFT, tw - key_w, 16, Color(1, 0.88, 0.55))
	var y := rect.position.y + 30.0
	for i in rows.size():
		var r: Array = rows[i]
		var f: Font = r[1]
		_ci.draw_multiline_string(f, Vector2(x, y + f.get_ascent(r[2])), r[0], HORIZONTAL_ALIGNMENT_LEFT, tw, r[2], -1, r[3])
		y += float(heights[i]) + 3.0


func _icon(name: String) -> Texture2D:
	# (looked up once per name: ResourceLoader.exists asks the file system, two or three times
	# an icon, and the army's 24 portraits and the card's 12 buttons are drawn many times a second)
	var key := (game.faction_of(game.human) if game else "") + ":" + name
	if _icon_memo.has(key):
		return _icon_memo[key]
	var ic := _icon_file(name)
	if ic == null and Defs.icon_for(name) != name:
		ic = _icon_file(Defs.icon_for(name))       # (temporary art: Defs.TEMP_ART)
	if ic == null:
		ic = CwArt.icon(name)                      # (the Clockwork roster prototype: drawn in code)
	_icon_memo[key] = ic
	return ic


var _icon_memo := {}
var _fit_memo := {}             # the selection card's info line, fitted: text|width -> [font size, the line]


func _icon_file(name: String) -> Texture2D:
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
	s = Loc.t(s)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var x := p.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	_ci.draw_string_outline(font, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, col.a * 0.8))
	_ci.draw_string(font, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
