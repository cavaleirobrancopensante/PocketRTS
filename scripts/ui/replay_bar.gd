class_name ReplayBar
extends Control
## The replay viewer's controls (docs/replays.md), over the match's own HUD: play / pause, the speed, a timeline to
## seek with the match time, whose fog (everything or one player's view), the camera (free, or following the recording
## player's), and back to the REPLAYS page. Keys (computer): Space play / pause, + and - the speed, Home the start.
## Selecting units and buildings, the minimap and the VIEW menu are the HUD's, as when watching computers play.

signal quit

var game: Game
var player: ReplayPlayer
var _panel: PanelContainer
var _play: Button
var _speeds: Array = []
var _time: Label
var _len: Label
var _slider: HSlider
var _fog: Button
var _cam: Button
var _note: Label
var _dragging := false
var _seek_ms := 0
var _setting := false
var _shown_ft := -2


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiStyle.theme()
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.08, 0.065, 0.05, 0.86), UiStyle.TRIM_DIM, 2, 10, 6.0))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_panel.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	_play = _btn("❚❚", func() -> void: player.set_playing(not player.playing), 52)
	row.add_child(_play)
	for x in ReplayPlayer.SPEEDS:
		var sx: float = x
		var b := _btn(_speed_text(sx), func() -> void: player.set_speed(sx), 50)
		b.toggle_mode = true
		_speeds.append([sx, b])
		row.add_child(b)
	_time = UiStyle.text("0:00", 18, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, true)
	_time.custom_minimum_size.x = 58
	row.add_child(_time)
	_slider = HSlider.new()
	_slider.min_value = player.start_t
	_slider.max_value = maxf(player.length, player.start_t + 0.1)
	_slider.step = 0.1
	_slider.custom_minimum_size = Vector2(240, 40)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.drag_started.connect(func() -> void: _dragging = true)
	_slider.drag_ended.connect(func(_c: bool) -> void:
		_dragging = false
		player.seek(_slider.value))
	_slider.value_changed.connect(_on_slide)
	row.add_child(_slider)
	_len = UiStyle.text(ReplayPlayer.clock_text(player.length), 18, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
	_len.custom_minimum_size.x = 58
	row.add_child(_len)
	_fog = _btn("", func() -> void: _next_fog(), 150)
	row.add_child(_fog)
	_cam = _btn("", func() -> void: _next_camera(), 150)
	_cam.visible = not player.cam_teams().is_empty()
	row.add_child(_cam)
	row.add_child(_btn("QUIT", func() -> void: quit.emit(), 80))
	_note = UiStyle.text("", 14, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_note)
	player.changed.connect(_refresh)
	_refresh()


func _btn(t: String, cb: Callable, w: float) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Sfx.play_any(["ui/click", "click"])
		cb.call())
	return b


static func _speed_text(x: float) -> String:
	return "½x" if x < 1.0 else "%dx" % int(x)


func _on_slide(x: float) -> void:
	if _setting:
		return
	_time.text = ReplayPlayer.clock_text(x)
	var now := Time.get_ticks_msec()
	if not _dragging or now - _seek_ms > 200:
		_seek_ms = now
		player.seek(x)           # (dragging: a picture every 0.2 s or so; the release puts it exactly there)


## The camera: free, then each recorded player's camera in turn.
func _next_camera() -> void:
	var order: Array = [-1] + player.cam_teams()
	player.follow_camera(order[(order.find(player.cam_team) + 1) % order.size()])


## The fog: everything, then each player's view in turn (the HUD's VIEW menu has the same and the follow director).
func _next_fog() -> void:
	var sp: Spectator = game.spectator
	if sp == null:
		return
	var order: Array = [-1]
	for t in game.n_players():
		order.append(t)
	var cur := game.view_team
	var i := order.find(cur)
	var nxt: int = order[(i + 1) % order.size()]
	if nxt < 0:
		sp.set_mode("all", 0)
	else:
		sp.set_mode("free", nxt)
	_refresh()


func _refresh() -> void:
	if player == null:
		return
	_play.text = "▶" if not player.playing else "❚❚"
	for pr in _speeds:
		(pr[1] as Button).button_pressed = is_equal_approx(float(pr[0]), player.speed)
	var ft := game.view_team
	_shown_ft = ft
	_fog.text = Loc.t("FOG: ALL") if ft < 0 else Loc.t("FOG: P%d") % (ft + 1)
	if ft >= 0:
		_fog.add_theme_color_override("font_color", game.team_colour(ft).lightened(0.3))
	else:
		_fog.remove_theme_color_override("font_color")
	_cam.text = Loc.t("CAMERA: P%d") % (player.cam_team + 1) if player.cam_team >= 0 else Loc.t("CAMERA: FREE")
	var bits: Array = []
	if player.view_only:
		bits.append(Loc.t("Your view only: what your side saw."))
	if player.version_note != "":
		bits.append(player.version_note)
	if player.at_end:
		bits.append(Loc.t("The end: %s.") % (Loc.t("%s wins") % game.team_name(player.end_winner).capitalize() if player.end_winner >= 0 else Loc.t("no winner")))
	_note.text = "   ·   ".join(bits)
	_note.visible = not bits.is_empty()


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not _dragging:
		_setting = true
		_slider.value = player.play_t
		_setting = false
		_time.text = ReplayPlayer.clock_text(player.play_t)
	if game.view_team != _shown_ft:
		_refresh()               # (the HUD's VIEW menu changed it)
	_place()


## Above the HUD's bottom panels, centred.
func _place() -> void:
	var vs := get_viewport_rect().size
	var bottom := vs.y - 8.0
	var hud = game.hud
	if hud and is_instance_valid(hud):
		bottom = minf(hud.mini_rect().position.y, hud.panel_rect().position.y) - 8.0
		bottom = minf(bottom, hud.card_rect().position.y - 8.0)
	var w := minf(vs.x - 24.0, 1180.0)
	_panel.size = Vector2(w, 0)
	var h := _panel.get_combined_minimum_size().y
	_panel.position = Vector2((vs.x - w) * 0.5, maxf(bottom - h, 50.0))


func _unhandled_key_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	match ke.keycode:
		KEY_SPACE:
			player.set_playing(not player.playing)
		KEY_EQUAL, KEY_KP_ADD, KEY_PLUS:
			player.step_speed(1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			player.step_speed(-1)
		KEY_HOME:
			player.seek(player.start_t)
		_:
			return
	get_viewport().set_input_as_handled()
