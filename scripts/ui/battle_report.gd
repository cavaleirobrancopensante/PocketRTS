extends Control
## Post-battle screen: headline, side-by-side statistics, a timeline chart
## (army value / gold mined / workers) and each side's top killers.

signal play_again
signal to_menu
signal view_map

var game: Game
var winner := -1
var chart: Chart
var _tab_buttons: Array = []

const ROWS := [
	["Income", "gold"],
	["Gold spent", "spent"],
	["Units trained", "trained"],
	["Structures built", "built"],
	["Units killed", "killed"],
	["Units lost", "lost"],
	["Structures razed", "razed"],
	["Structures lost", "bld_lost"],
	["Damage dealt", "damage"],
	["Value destroyed", "value_killed"],
	["Peak army value", "peak_army"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.035, 0.03, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	# Headline
	var won := winner >= 0 and game.allied(winner, game.human)
	var title: String
	if game.demo:
		title = "%s WINS" % _side_name(winner).to_upper() if winner >= 0 else "DRAW"
	else:
		title = "VICTORY" if won else "DEFEAT"
	v.add_child(UiStyle.heading(title, 52, Color(1, 0.85, 0.45) if won or game.demo else UiStyle.BAD))
	var secs := int(game.clock)
	var lvl: String = ["Easy", "Normal", "Hard", "Brutal"][clampi(game.difficulty, 0, 3)]
	v.add_child(UiStyle.text("%s   ·   %d:%02d   ·   %s AI   ·   %d players" % [game.map_name, secs / 60, secs % 60, lvl, game.n_players()], 18, UiStyle.MUTED))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	# Statistics table: one column per player, you first.
	var order := _order()
	var grid := GridContainer.new()
	grid.columns = 1 + order.size()
	grid.add_theme_constant_override("h_separation", 18 if order.size() <= 4 else 8)      # (8 players: tighter)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	grid.add_child(UiStyle.text("", 16))
	for t in order:
		var head := UiStyle.text(_short(t), 15, game.team_colour(t).lightened(0.35), HORIZONTAL_ALIGNMENT_RIGHT, true)
		grid.add_child(head)
	for row in ROWS:
		grid.add_child(UiStyle.text(row[0], 16, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		var vals: Array = order.map(func(t: int) -> int: return int(game.stats[t][row[1]]))
		var better_low: bool = row[1] in ["lost", "bld_lost"]
		var best: int = vals.min() if better_low else vals.max()
		for val in vals:
			grid.add_child(_num(val, vals.size() > 1 and val == best and vals.count(best) == 1))
	grid.add_child(UiStyle.text("Top killers", 16, UiStyle.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	for t in order:
		grid.add_child(UiStyle.text(_mvp(t), 14, UiStyle.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))

	# Chart with tabs
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_theme_constant_override("separation", 8)
	body.add_child(cv)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	cv.add_child(tabs)
	for tab in [["ARMY", "army_tl"], ["INCOME", "gold_tl"], ["WORKERS", "workers_tl"]]:
		var b := Button.new()
		b.text = tab[0]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(110, 44)
		b.add_theme_font_size_override("font_size", 17)
		var key: String = tab[1]
		b.pressed.connect(func() -> void: _show(key, b))
		tabs.add_child(b)
		_tab_buttons.append(b)
	chart = Chart.new()
	chart.custom_minimum_size = Vector2(400 if order.size() <= 4 else 240, 280)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.colours = order.map(func(t: int) -> Color: return game.team_colour(t).lightened(0.2))
	chart.span = game.clock
	cv.add_child(chart)
	_show("army_tl", _tab_buttons[0])

	# Buttons
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	v.add_child(btns)
	for bt in [["PLAY AGAIN", play_again], ["VIEW MAP", view_map], ["MENU", to_menu]]:
		var b := Button.new()
		b.text = bt[0]
		b.custom_minimum_size = Vector2(240, 58)
		if bt[0] == "PLAY AGAIN":
			UiStyle.primary(b)
		var sig: Signal = bt[1]
		b.pressed.connect(func() -> void:
			Sfx.play_any(["ui/click", "click"])
			sig.emit())
		btns.add_child(b)
	# the playtest log, to paste to the developer
	if game.mlog:
		var cb := Button.new()
		cb.text = "COPY LOG"
		cb.custom_minimum_size = Vector2(200, 58)
		cb.pressed.connect(func() -> void:
			Sfx.play_any(["ui/click", "click"])
			DisplayServer.clipboard_set(game.mlog.text())
			cb.text = "COPIED!")
		btns.add_child(cb)


## You first, then your allies, then everyone else.
func _order() -> Array:
	var me := game.human if not game.demo else 0
	var out: Array = [me]
	for t in game.n_players():
		if t != me and game.allied(t, me):
			out.append(t)
	for t in game.n_players():
		if not out.has(t):
			out.append(t)
	return out


func _side_name(t: int) -> String:
	if t < 0:
		return ""
	var fac: String = Defs.FACTIONS[game.faction_of(t)]["name"]
	if not game.demo and t == game.human:
		return "You (%s)" % fac
	return "%s (%s)" % [game.team_name(t), fac]


func _short(t: int) -> String:
	var fac: String = Defs.FACTIONS[game.faction_of(t)]["name"].replace("The ", "")
	return ("YOU · " if not game.demo and t == game.human else game.team_name(t).to_upper() + " · ") + fac.to_upper()


func _mvp(t: int) -> String:
	var kb: Dictionary = game.stats[t]["kills_by"]
	var ks := kb.keys()
	ks.sort_custom(func(a: String, b: String) -> bool: return kb[a] > kb[b])
	var parts: Array = []
	for k in ks.slice(0, 2):
		parts.append("%s %d" % [Defs.UNITS[k]["name"] if Defs.UNITS.has(k) else Defs.BUILDINGS.get(k, {"name": String(k).capitalize()})["name"], kb[k]])
	return "\n".join(parts) if not parts.is_empty() else "-"


func _show(key: String, btn: Button) -> void:
	for b in _tab_buttons:
		b.button_pressed = b == btn
	chart.series = _order().map(func(t: int) -> Array: return game.stats[t][key])
	chart.queue_redraw()


func _num(n: int, best: bool) -> Label:
	return UiStyle.text(_fmt(n), 17, UiStyle.GOOD if best else UiStyle.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, best)


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _label(t: String, sz: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l


## A two-line timeline chart sampled every 5 seconds.
class Chart extends Control:
	var series: Array = []
	var colours: Array = []
	var span := 1.0

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var r := Rect2(Vector2(48, 8), size - Vector2(56, 34))
		var sb := UiStyle.box(Color(0, 0, 0, 0.3), UiStyle.TRIM_DIM, 1, 8, 0.0)
		sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var top := 1.0
		var n := 2
		for s in series:
			n = maxi(n, s.size())
			for x in s:
				top = maxf(top, float(x))
		top = _nice(top)
		for i in 5:
			var y := r.end.y - r.size.y * i / 4.0
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.1))
			draw_string(font, Vector2(2, y + 5), _short_num(top * i / 4.0), HORIZONTAL_ALIGNMENT_LEFT, 44, 13, Color(1, 1, 1, 0.55))
		var mins := int(span / 60.0)
		var step := maxi(1, int(ceil(mins / 8.0)))
		for m in range(0, mins + 1, step):
			var x := r.position.x + r.size.x * (m * 60.0) / maxf(span, 1.0)
			draw_string(font, Vector2(x - 8, size.y - 6), "%dm" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.55))
		for si in series.size():
			var s: Array = series[si]
			if s.size() < 2:
				continue
			var pts := PackedVector2Array()
			for i in s.size():
				var t := minf(i * 5.0, span)
				pts.append(Vector2(r.position.x + r.size.x * t / maxf(span, 1.0), r.end.y - r.size.y * float(s[i]) / top))
			draw_polyline(pts, colours[si], 3.0, true)

	static func _nice(v: float) -> float:
		var p: float = pow(10.0, floor(log(v) / log(10.0)))
		for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
			if v <= m * p:
				return m * p
		return 10.0 * p

	static func _short_num(v: float) -> String:
		if v >= 1000.0:
			return ("%.1fk" % (v / 1000.0)).replace(".0k", "k")
		return str(int(v))
