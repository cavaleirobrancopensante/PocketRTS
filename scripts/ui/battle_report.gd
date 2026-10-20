extends Control
## Post-battle screen: headline, side-by-side statistics, a timeline chart
## (army value / gold mined / workers) and each side's top killers.

signal play_again
signal to_menu

var game: Game
var winner := -1
var chart: Chart
var _tab_buttons: Array = []

const ROWS := [
	["Gold mined", "gold"],
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
	shade.color = Color(0.03, 0.05, 0.04, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	# Headline
	var won := winner == game.human
	var title: String
	if game.demo:
		title = "%s WINS" % _side_name(winner).to_upper()
	else:
		title = "VICTORY" if won else "DEFEAT"
	v.add_child(_label(title, 54, Color(1, 0.9, 0.5) if won or game.demo else Color(1, 0.5, 0.45)))
	var secs := int(game.clock)
	v.add_child(_label("%s  vs  %s   ·   %d:%02d   ·   %s" % [_side_name(_left()), _side_name(_right()),
			secs / 60, secs % 60, ["Easy", "Normal", "Hard"][clampi(game.difficulty, 0, 2)]], 18, Color(1, 1, 1, 0.7)))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	v.add_child(body)

	# Statistics table
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 5)
	grid.custom_minimum_size = Vector2(420, 0)
	body.add_child(grid)
	grid.add_child(_label("", 18))
	grid.add_child(_label(_short(_left()), 18, game.team_colour(_left()).lightened(0.3), HORIZONTAL_ALIGNMENT_RIGHT))
	grid.add_child(_label(_short(_right()), 18, game.team_colour(_right()).lightened(0.3), HORIZONTAL_ALIGNMENT_RIGHT))
	for row in ROWS:
		var a := int(game.stats[_left()][row[1]])
		var b := int(game.stats[_right()][row[1]])
		var better_low: bool = row[1] in ["lost", "bld_lost"]
		grid.add_child(_label(row[0], 17, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_LEFT))
		grid.add_child(_num(a, a != b and ((a < b) == better_low)))
		grid.add_child(_num(b, a != b and ((b < a) == better_low)))
	var apm_l := _label("Top killers", 17, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
	grid.add_child(apm_l)
	grid.add_child(_label(_mvp(_left()), 15, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_RIGHT))
	grid.add_child(_label(_mvp(_right()), 15, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_RIGHT))

	# Chart with tabs
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_theme_constant_override("separation", 8)
	body.add_child(cv)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	cv.add_child(tabs)
	for tab in [["ARMY", "army_tl"], ["GOLD", "gold_tl"], ["WORKERS", "workers_tl"]]:
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
	chart.custom_minimum_size = Vector2(440, 300)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.colours = [game.team_colour(_left()).lightened(0.2), game.team_colour(_right()).lightened(0.2)]
	chart.span = game.clock
	cv.add_child(chart)
	_show("army_tl", _tab_buttons[0])

	# Buttons
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	v.add_child(btns)
	for bt in [["PLAY AGAIN", play_again], ["MENU", to_menu]]:
		var b := Button.new()
		b.text = bt[0]
		b.custom_minimum_size = Vector2(220, 56)
		var sig: Signal = bt[1]
		b.pressed.connect(func() -> void: sig.emit())
		btns.add_child(b)


## Left column is always the player (or Blue when watching).
func _left() -> int:
	return game.human if game.human >= 0 and not game.demo else 0


func _right() -> int:
	return 1 - _left()


func _side_name(t: int) -> String:
	var fac: String = Defs.FACTIONS[game.faction_of(t)]["name"]
	if not game.demo and t == game.human:
		return "You (%s)" % fac
	return "%s (%s)" % [game.team_name(t), fac]


func _short(t: int) -> String:
	var fac: String = Defs.FACTIONS[game.faction_of(t)]["name"].replace("The ", "")
	return ("YOU · " if not game.demo and t == game.human else "") + fac.to_upper()


func _mvp(t: int) -> String:
	var kb: Dictionary = game.stats[t]["kills_by"]
	var ks := kb.keys()
	ks.sort_custom(func(a: String, b: String) -> bool: return kb[a] > kb[b])
	var parts: Array = []
	for k in ks.slice(0, 2):
		parts.append("%s %d" % [Defs.UNITS[k]["name"] if Defs.UNITS.has(k) else Defs.BUILDINGS[k]["name"], kb[k]])
	return "\n".join(parts) if not parts.is_empty() else "-"


func _show(key: String, btn: Button) -> void:
	for b in _tab_buttons:
		b.button_pressed = b == btn
	chart.series = [game.stats[_left()][key], game.stats[_right()][key]]
	chart.queue_redraw()


func _num(n: int, best: bool) -> Label:
	return _label(_fmt(n), 18, Color(0.55, 1, 0.55) if best else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)


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
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.04))
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
