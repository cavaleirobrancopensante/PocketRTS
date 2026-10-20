class_name SandboxPanel
extends Control
## Sandbox tools during a match: pick a player, spawn any unit or building of any faction
## for them, delete things, hand out resources, lift the fog, switch who you control,
## switch each player's AI on or off and change the game speed.

var game: Game
var acting := 0                 # the player spawns go to
var spawn := ""                 # unit or building kind waiting for a click on the map
var deleting := false
var open := true
var _tab := "crown"
var _panel: PanelContainer
var _toggle: Button
var _ai_off := {}               # player -> the AI node we took out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiStyle.theme()
	acting = game.human
	_tab = game.faction_of(acting)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_toggle = Button.new()
	_toggle.text = "SANDBOX ◂" if open else "SANDBOX ▸"
	var right := get_viewport_rect().size.x - 8.0
	_toggle.position = Vector2(right - 150, 44)
	_toggle.custom_minimum_size = Vector2(150, 40)
	_toggle.add_theme_font_size_override("font_size", 15)
	_toggle.pressed.connect(func() -> void:
		open = not open
		_build())
	add_child(_toggle)
	if not open:
		return
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 272
	_panel.position = Vector2(right - 272, 88)
	_panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.1, 0.085, 0.065, 0.93), UiStyle.TRIM_DIM, 2, 10, 10.0))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_panel.add_child(v)
	# players
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 4)
	v.add_child(pr)
	pr.add_child(UiStyle.text("PLAYER", 13, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	for t in game.n_players():
		var tt: int = t
		var b := Button.new()
		b.text = ("★" if t == game.human else "") + str(t + 1)
		b.custom_minimum_size = Vector2(40, 36)
		var col := game.team_colour(t)
		var sb := UiStyle.box(col.darkened(0.3), Color(1, 1, 1, 0.9) if t == acting else Color(1, 1, 1, 0.25), 3 if t == acting else 1, 6, 4.0)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func() -> void:
			acting = tt
			_tab = game.faction_of(tt)
			_build())
		pr.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	row.add_child(_small("CONTROL", acting == game.human, func() -> void: _control(acting)))
	row.add_child(_small("AI: OFF" if _ai_off.has(acting) or acting == game.human else "AI: ON", false, func() -> void: _toggle_ai(acting)))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	v.add_child(row2)
	var res: Array = Defs.FACTIONS[game.faction_of(acting)]["res"]
	row2.add_child(_small("+1000 " + String(res[0]).to_upper(), false, func() -> void:
		game.players[acting]["gold"] += 1000))
	row2.add_child(_small("+200 " + String(res[1]).to_upper(), false, func() -> void:
		game.players[acting]["res2"] = float(game.players[acting]["res2"]) + 200.0))
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 4)
	v.add_child(row3)
	row3.add_child(_small("FOG: OFF" if game.reveal else "FOG: ON", game.reveal, func() -> void: game.reveal = not game.reveal))
	row3.add_child(_small("SPEED x%d" % int(Engine.time_scale), Engine.time_scale > 1.0, func() -> void:
		Engine.time_scale = {1.0: 2.0, 2.0: 4.0, 4.0: 1.0}.get(Engine.time_scale, 1.0)))
	# spawn lists
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for f in [["crown", "CROWN"], ["brood", "BROOD"], ["clockwork", "CLOCK"]]:
		var ff: String = f[0]
		var b := _small(f[1], _tab == ff, func() -> void:
			_tab = ff
			_build())
		b.add_theme_color_override("font_color", UiStyle.accent(ff).lightened(0.4))
		tabs.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	v.add_child(grid)
	var kinds: Array = []
	for k in Defs.UNITS:
		if Defs.UNITS[k]["faction"] == _tab:
			kinds.append(k)
	for k in Defs.FACTIONS[_tab]["build"]:
		if not kinds.has(k):
			kinds.append(k)
	for k in kinds:
		var kk: String = k
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
		b.icon = load("res://assets/icons/%s.png" % k) if ResourceLoader.exists("res://assets/icons/%s.png" % k) else null
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 34)
		b.tooltip_text = (Defs.UNITS[k]["name"] if Defs.UNITS.has(k) else Defs.BUILDINGS[k]["name"])
		if spawn == k:
			UiStyle.chosen(b)
		b.pressed.connect(func() -> void:
			spawn = "" if spawn == kk else kk
			deleting = false
			_build())
		grid.add_child(b)
	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 4)
	v.add_child(row4)
	row4.add_child(_small("DELETE", deleting, func() -> void:
		deleting = not deleting
		spawn = ""))
	row4.add_child(_small("KILL ALL OF P%d" % (acting + 1), false, func() -> void:
		for u in game.units.duplicate():
			if u.team == acting and not u.dead and not u.is_worker():
				u.die()))
	var hint := "Click the map to place it (Shift: keep placing)." if Settings.pc() else "Tap the map to place it."
	if spawn != "":
		hint = "%s for player %d: %s" % [_name(spawn), acting + 1, hint]
	elif deleting:
		hint = "Click anything to remove it." if Settings.pc() else "Tap anything to remove it."
	else:
		hint = "Pick something to place."
	var l := UiStyle.text(hint, 13, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 240
	v.add_child(l)


func _small(t: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 13)
	if on:
		UiStyle.chosen(b)
	b.pressed.connect(func() -> void:
		Sfx.play_any(["ui/click", "click"])
		cb.call()
		_build())
	return b


func _name(k: String) -> String:
	return Defs.UNITS[k]["name"] if Defs.UNITS.has(k) else Defs.BUILDINGS[k]["name"]


## Take over another player: you see and command for them; their AI stops.
func _control(t: int) -> void:
	if t == game.human:
		return
	var old := game.human
	# the player you leave gets their AI back unless you switched it off
	game.human = t
	_set_ai(t, false)
	if not _ai_off.has(old):
		_set_ai(old, true)
	game.set_selection([])
	for e in game.units + game.buildings:
		e.seen_by_human = false
	game.explored.fill(0)
	var h := game._own_hall(t)
	if h:
		game.camera.position = h.global_position
	if Music.me:
		Music.me.match_started(game.faction_of(t), [])


func _toggle_ai(t: int) -> void:
	if t == game.human:
		return
	if _ai_off.has(t):
		_ai_off.erase(t)
		_set_ai(t, true)
	else:
		_ai_off[t] = true
		_set_ai(t, false)


func _set_ai(t: int, on: bool) -> void:
	for ai in game.ais:
		if ai.team == t:
			ai.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
			return
	if on:
		var ai := AI.new()
		ai.game = game
		ai.team = t
		ai.difficulty = 2
		game.add_child(ai)
		game.ais.append(ai)


# ------------------------------------------------------------------ clicks on the map

func _over_panel(p: Vector2) -> bool:
	return _toggle.get_global_rect().has_point(p) or (open and _panel and _panel.get_global_rect().has_point(p))


func _input(event: InputEvent) -> void:
	if game == null or game.over:
		return
	var p := Vector2.INF
	var shift := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Settings.pc():
		p = event.position
		shift = event.shift_pressed
	elif event is InputEventScreenTouch and event.pressed and not Settings.pc():
		p = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and (spawn != "" or deleting):
		spawn = ""
		deleting = false
		_build()
		get_viewport().set_input_as_handled()
		return
	if p == Vector2.INF or _over_panel(p) or (spawn == "" and not deleting):
		return
	if game.hud and game.hud._hud_has(p):
		return
	var w: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * p
	if deleting:
		var e := game.entity_at(w, false)
		if e and not e.dead:
			if e is Building:
				e.take_damage(999999.0, null)
			else:
				e.die()
	elif Defs.UNITS.has(spawn):
		for n in int(Defs.UNITS[spawn].get("spawn", 1)):
			game._add_unit(spawn, acting, w + Vector2(randf_range(-8, 8), randf_range(-8, 8)))
		Sfx.play_any(["ui/click", "click"])
	else:
		var size: Vector2i = Defs.BUILDINGS[spawn]["size"]
		var c := game.cell_of(w) - size / 2
		var ok := true
		for y in size.y:
			for x in size.x:
				if not game.is_free(c + Vector2i(x, y)):
					ok = false
		if ok:
			var b := game._add_building(spawn, acting, c, true)
			game.on_building_complete(b)
			game.swamp_dirty = true
		else:
			game.notify("No room there.")
	if not shift or not Settings.pc():
		if not Defs.UNITS.has(spawn) and not deleting:
			spawn = ""
			_build()
	get_viewport().set_input_as_handled()
