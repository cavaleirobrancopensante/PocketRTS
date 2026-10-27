extends SceneTree
## Pathfinding in real games (docs/pathfinding_audit.md): two computer players fight a match and every
## second every ground unit with somewhere to go is looked at. A unit "stuck" has not moved 6 px in the
## last 2 s while it still has a move to make (a move, attack-move or attack order; not fighting, not
## at work, not waiting for its path). The report: stuck unit-seconds per game minute, and the worst
## spots (cell, kind, order, path state, what it's pressed against), for the match log to compare
## before and after a change.
##   godot --headless --fixed-fps 30 --script res://tools/test_pathing_match.gd -- map=greenhold a=crown b=brood end=600 seed=7
var main: Node
var t := 0.0
var g
var map := "greenhold"
var fa := "crown"
var fb := "brood"
var end_t := 600.0
var seed_ := 7
var hist := {}
var stuck_s := 0.0
var cliff_s := 0.0
var spots := {}
var next_s := 0.0
var unit_s := 0.0
var episodes := {}         # unit -> seconds in the current stuck run
var long_runs: Array = []  # [seconds, description] of runs of 10 s or more


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"a": fa = kv[1]
			"b": fb = kv[1]
			"end": end_t = float(kv[1])
			"seed": seed_ = int(kv[1])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": fb, "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	if g.over or g.clock >= end_t:
		_finish()
		return true
	if g.clock >= next_s:
		next_s = g.clock + 1.0
		_sample()
	return false


func _moving(u: Unit) -> bool:
	if u.dead or u.is_air() or u.aboard != null or u.kind == "horse" or u.path_pending:
		return false
	if not (u.order in ["move", "amove", "attack", "d_amove"]):
		return false
	if u.phase != "" or u.stun_t > 0.0 or u.braced:
		return false
	if u.deploys() and u.tesla_mode != "packed":
		return false
	# fighting from where it stands (in reach of its target) is not being stuck
	if is_instance_valid(u.target) and u.target.edge_distance(u.position) - u.radius <= u._range() + 8.0:
		return false
	var goal: Vector2 = u.path_goal
	if goal == Vector2.INF:
		return false
	return goal.distance_to(u.position) > 60.0


func _sample() -> void:
	var seen := {}
	for u in g.units:
		if not is_instance_valid(u) or u.dead:
			continue
		seen[u] = true
		var h: Array = hist.get(u, [])
		h.append(u.position)
		if h.size() > 3:
			h.pop_front()
		hist[u] = h
		if not _moving(u):
			episodes.erase(u)
			continue
		unit_s += 1.0
		if h.size() >= 3 and h[0].distance_to(u.position) < 6.0:
			stuck_s += 1.0
			var pr := _pressed(u)
			if pr == "cliff":
				cliff_s += 1.0
			var c: Vector2i = g.cell_of(u.position)
			var key := "%s %s" % [str(c), u.kind]
			var e: Array = spots.get(key, [0.0, ""])
			e[0] = float(e[0]) + 1.0
			e[1] = "%s order %s target %s path %d/%d goal %s lv %d->%d pressed %s" % [u.kind, u.order,
				(u.target.kind if is_instance_valid(u.target) else "-"), u.path_i, u.path.size(),
				str(g.cell_of(u.path_goal)), g.level_of(u.position), g.level_of(u.path_goal), pr]
			spots[key] = e
			episodes[u] = float(episodes.get(u, 0.0)) + 1.0
			if float(episodes[u]) == 10.0:
				long_runs.append("%5.0fs %s at %s %s" % [g.clock, u.kind, str(c), e[1]])
				if OS.get_environment("PATH_DUMP") != "":
					_dump(u)
		else:
			episodes.erase(u)
	for u in hist.keys():
		if not seen.has(u):
			hist.erase(u)
			episodes.erase(u)


## The ground round a stuck unit (. open, # cliff, T terrain, B building, W wall, G gate, f field,
## upper case = high ground for open cells: ^), its path and what's near.
func _dump(u: Unit) -> void:
	var c0: Vector2i = g.cell_of(u.position)
	print("DUMP %s at %s pos %s radius %.0f order %s path %s goal %s vel %s stuck_t %.1f" % [u.kind, str(c0), str(u.position.round()), u.radius, u.order,
		str(Array(u.path).map(func(q): return g.cell_of(q))), str(u.path_goal.round()), str(u.velocity.round()), u.stuck_t])
	for y in range(c0.y - 5, c0.y + 6):
		var row := ""
		for x in range(c0.x - 7, c0.x + 8):
			var c := Vector2i(x, y)
			if not g.in_map(c):
				row += " "
				continue
			var i: int = g.idx(c)
			var v := int(g.solid[i])
			var ch := "."
			if c == c0:
				ch = "@"
			elif g.cliff[i] == 1:
				ch = "#"
			elif v == 1:
				ch = "T"
			elif v == 2:
				ch = "B"
			elif v == 3:
				ch = "G"
			elif v == 4:
				ch = "W"
			elif v == 5:
				ch = "f"
			elif g.ramp[i] == 1:
				ch = "/"
			elif g.height[i] == 1:
				ch = "^"
			for q in u.path:
				if g.cell_of(q) == c and ch in [".", "^", "/"]:
					ch = "*"
			row += ch
		print("  | " + row)
	for o in g.units_near(u.position, 60.0):
		if o != u:
			print("  near %s team %d order %s vel %s" % [o.kind, o.team, o.order, str(o.velocity.round())])


func _pressed(u: Unit) -> String:
	var c0: Vector2i = g.cell_of(u.position)
	var lim: float = u.radius * 0.75 + 3.0
	var best := ""
	for y in range(-1, 2):
		for x in range(-1, 2):
			var c := c0 + Vector2i(x, y)
			if not g.in_map(c):
				continue
			var i: int = g.idx(c)
			var v := int(g.solid[i])
			if v == 0 or v == 5:
				continue
			var rc := Rect2(Vector2(c) * g.T, Vector2(g.T, g.T))
			if u.position.clamp(rc.position, rc.end).distance_to(u.position) > lim:
				continue
			if g.cliff[i] == 1:
				return "cliff"
			best = "bld" if v >= 2 else "terrain"
	return best


func _finish() -> void:
	var mins := maxf(g.clock / 60.0, 0.1)
	print("MATCH %s %s v %s seed %d: %.1f min, moving unit-s %.0f, stuck unit-s %.0f (%.1f%%, %.1f a minute), at a cliff %.0f, runs of 10 s+ %d" % [
		map, fa, fb, seed_, mins, unit_s, stuck_s, 100.0 * stuck_s / maxf(unit_s, 1.0), stuck_s / mins, cliff_s, long_runs.size()])
	var keys := spots.keys()
	keys.sort_custom(func(a, b) -> bool: return float(spots[a][0]) > float(spots[b][0]))
	for i in mini(keys.size(), 12):
		print("  %4.0fs at %s: %s" % [float(spots[keys[i]][0]), keys[i], spots[keys[i]][1]])
	for r in long_runs.slice(0, 15):
		print("  long: " + r)
	quit(0)
