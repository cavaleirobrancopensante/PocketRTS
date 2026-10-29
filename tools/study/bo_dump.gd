extends SceneTree
## Build-order study (docs/build_orders_study.md): the numbers the timing calculator (tools/study/bo_calc.py)
## needs, read from the game itself. Measurement only: it never changes the game, the AI or a balance number.
##
##   godot --headless --fixed-fps 30 --script res://tools/study/bo_dump.gd -- defs out:/abs/defs.json
##       every unit, building, research and faction entry of Defs (gear mode's build lists), the economy
##       constants, as JSON (Vector2 -> [x, y], Color -> "#rrggbb").
##   godot --headless --fixed-fps 30 --script res://tools/study/bo_dump.gd -- map:<id> seed:<n> out:/abs/map.json
##       one map: the two starting halls, their ramps, and the WALKING distance (the game's own pathfinder,
##       smoothed as a unit walks it) from each side's rally point to the other's ramp foot, ramp top and hall,
##       plus the straight line between the halls (flyers and balloons).
## tools/study/bo_data.py merges the outputs into tools/study/bo_data.json.

var main: Node
var t := 0.0
var mode := "defs"
var map := "ashford_crossing"
var seed_ := 1
var out := ""
var started := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "defs":
			mode = "defs"
		elif a.begins_with("map:"):
			mode = "map"
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("out:"):
			out = a.substr(4)
	if mode == "defs":
		_dump_defs()
		quit(0)
		return
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


static func _j(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_COLOR:
			return "#" + (v as Color).to_html(false)
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _j(v[k])
			return d
		TYPE_ARRAY:
			var a: Array = []
			for x in v:
				a.append(_j(x))
			return a
		TYPE_FLOAT:
			if is_inf(v) or is_nan(v):
				return null
			return v
	return v


func _dump_defs() -> void:
	var d := {
		"version": ProjectSettings.get_setting("application/config/version", "dev"),
		"gear_mode": Defs.gear_mode, "line_mode": Defs.line_mode,
		"UNITS": _j(Defs.UNITS), "BUILDINGS": _j(Defs.BUILDINGS), "RESEARCH": _j(Defs.RESEARCH),
		"FACTIONS": _j(Defs.FACTIONS), "GEAR": _j(Defs.GEAR),
		"OWL_MORPH": _j(Defs.OWL_MORPH), "SPRINGER_JUMP": _j(Defs.SPRINGER_JUMP), "TURRET": _j(Defs.TURRET),
		"OWL_BOMB": _j(Defs.OWL_BOMB), "POWDER": _j(Defs.POWDER), "PISTOL": _j(Defs.PISTOL), "BAYONET": _j(Defs.BAYONET),
		"CRATE": _j(Defs.CRATE), "HORSES": _j(Defs.HORSES), "DROPSHIP": _j(Defs.DROPSHIP), "BALLOON": _j(Defs.BALLOON),
		"econ": {
			"START_GOLD": Defs.START_GOLD, "START_POWDER": Defs.START_POWDER,
			"FARM_GROW": Defs.FARM_GROW, "FARM_BASE": Defs.FARM_BASE, "FARM_YIELD": Defs.FARM_YIELD, "SOIL_RESERVE": Defs.SOIL_RESERVE,
			"MILL_RATE": Defs.MILL_RATE, "LODE": _j(Defs.LODE), "PIT_TIME": Defs.PIT_TIME, "FOOD_RATE": Defs.FOOD_RATE,
			"FOOD_NEAR": Defs.FOOD_NEAR, "FOOD_FAR": Defs.FOOD_FAR, "FOOD_PEAK": Defs.FOOD_PEAK, "FOOD_BONUS": Defs.FOOD_BONUS,
			"FOOD_FADE": Defs.FOOD_FADE, "FOOD_TRIP": Defs.FOOD_TRIP, "FOOD_REACH": Defs.FOOD_REACH, "PIT_GROUND": Defs.PIT_GROUND,
			"PIT_CREW_STEP": Defs.PIT_CREW_STEP, "PIT_CREW_MAX": Defs.PIT_CREW_MAX, "HARVEST_PER_SUPPLY": Defs.HARVEST["per_supply"],
			"SACRIFICE": Defs.SACRIFICE, "WIND_DECAY": Defs.WIND_DECAY, "ECON_RANGE": Defs.ECON_RANGE, "HALL_SPACING": Defs.HALL_SPACING,
		},
		"build_list": {}, "start_list": {}, "supply_kind": {}, "res_names": {},
	}
	for f in Defs.FACTIONS:
		d["build_list"][f] = Defs.build_list(f)
		d["start_list"][f] = Defs.start_list(f)
		d["supply_kind"][f] = Defs.supply_kind(f)
		d["res_names"][f] = Defs.res_names(f)
	_write(JSON.stringify(d, " "))


func _write(text: String) -> void:
	if out == "":
		print(text)
		return
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("wrote ", out)


func _process(delta: float) -> bool:
	if mode != "map":
		return true
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	var g = main.game
	if g.ais.size() < 2 or g.halls_of(0).is_empty() or g.halls_of(1).is_empty():
		return false
	if not started:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_measure(g)
		return true
	return false


func _plen(g, a: Vector2, b: Vector2) -> float:
	var pts: PackedVector2Array = g.find_path(a, b)
	var n := 0.0
	var cur := a
	for p in pts:
		n += cur.distance_to(p)
		cur = p
	return n


func _measure(g) -> void:
	var T := float(Defs.TILE)
	var halls := [g.halls_of(0)[0], g.halls_of(1)[0]]
	var ai0 = null
	for ai in g.ais:
		if ai.team == 0:
			ai0 = ai
	var sides: Array = []
	for i in 2:
		var h = halls[i]
		var foot: Vector2 = g.ramp_foot(h)
		var top: Vector2 = g.ramp_top(h)
		sides.append({"hall": _j(h.center()), "front": _j(ai0._rally_front(h)),
			"ramp_foot": _j(foot * T) if foot != Vector2.INF else null, "ramp_top": _j(top * T) if top != Vector2.INF else null})
	var rows: Array = []
	for i in 2:
		var me = halls[i]
		var foe = halls[1 - i]
		var front: Vector2 = ai0._rally_front(me)
		var foot: Vector2 = g.ramp_foot(foe)
		var top: Vector2 = g.ramp_top(foe)
		var r := {"from": i,
			"to_hall": _plen(g, front, g.approach_point(foe, front)),
			"to_ramp_foot": _plen(g, front, foot * T) if foot != Vector2.INF else null,
			"to_ramp_top": _plen(g, front, top * T) if top != Vector2.INF else null,
			"hall_to_hall_walk": _plen(g, g.approach_point(me, foe.center()), g.approach_point(foe, me.center())),
			"air": me.center().distance_to(foe.center()),
			"own_ramp_top": _plen(g, front, g.ramp_top(me) * T) if g.ramp_top(me) != Vector2.INF else null}
		rows.append(r)
	var data := {"map": map, "seed": seed_, "size": [g.W, g.H], "tile": T, "sides": sides, "routes": rows,
		"version": ProjectSettings.get_setting("application/config/version", "dev")}
	_write(JSON.stringify(data, " "))
