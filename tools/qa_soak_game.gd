extends SceneTree
## QA soak: ONE computer-only game on any map and any number of players, headless, looking for trouble.
## Measurement only: it never changes the game or the AI (it reads state and hides the HUD).
##   godot --headless --fixed-fps 30 --script res://tools/qa_soak_game.gd -- \
##       map:kingsfield facs:crown,brood,clockwork,crown,brood,clockwork sides:0,0,0,1,1,1 lvls:hard,hard,... \
##       seed:1 end:1800 out:/abs/dir id:s01
## Writes <out>/<id>.json (result and the trouble it saw) and <out>/<id>.log (the match log).
## Trouble watched (per player): idle workers for minutes, no new building for minutes with money in the bank, never
## attacking, units under a move order that stay put for minutes, supply blocks that never end, income at zero while the
## halls still have soil, frames slower than 100 ms.
const TICK := 10.0

var main: Node
var g
var t := 0.0
var map := "kingsfield"
var facs: Array = []
var sides: Array = []
var lvls: Array = []
var seed_ := 1
var end_t := 1800.0
var out_dir := "/tmp"
var gid := "s"
var wall_limit := 0.0           # wall seconds; 0 = none (cause "wall_limit" when hit)
var inited := false
var done := false
var next_tick := TICK
var wall0 := 0
var last_us := 0
var slow_frames: Array = []      # [clock, ms]
var P: Array = []                # per player trackers
var upos: Dictionary = {}        # unit id -> [pos, since clock, order]
var stuck: Array = []            # [clock, team, kind, order, pos]
var stuck_seen: Dictionary = {}
var issues: Array = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"map": map = kv[1]
			"facs": facs = Array(kv[1].split(","))
			"sides": sides = Array(kv[1].split(",")).map(func(x) -> int: return int(x))
			"lvls": lvls = Array(kv[1].split(","))
			"seed": seed_ = int(kv[1])
			"end": end_t = float(kv[1])
			"out": out_dir = kv[1]
			"id": gid = kv[1]
			"wall": wall_limit = float(kv[1])


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var slots: Array = []
		for i in facs.size():
			slots.append({"who": lvls[i] if i < lvls.size() else "hard", "faction": facs[i], "colour": i, "side": sides[i], "strategy": "random"})
		main.start({"map": map, "seed": seed_, "slots": slots})
		wall0 = Time.get_ticks_msec()
		return false
	if main.game == null:
		return false
	g = main.game
	paused = false
	if not inited:
		if g.ais.size() < facs.size():
			return false
		inited = true
		if g.hud:
			g.hud.visible = false
			g.hud.process_mode = Node.PROCESS_MODE_DISABLED
		for i in facs.size():
			P.append({"idle_since": -1.0, "idle_max": 0.0, "bld_n": 0, "bld_t": 0.0, "nobuild_max": 0.0, "first_attack": -1.0,
				"block_since": -1.0, "block_max": 0.0, "earn": 0, "earn_t": 0.0, "noincome_max": 0.0, "out_t": -1.0,
				"strategy": "", "ai_level": ""})
		for a in g.ais:
			P[a.team]["strategy"] = String(a.strategy)
			P[a.team]["ai_level"] = lvls[a.team] if a.team < lvls.size() else "hard"
		last_us = Time.get_ticks_usec()
		return false
	if done:
		return true
	var now := Time.get_ticks_usec()
	var ms := (now - last_us) / 1000.0
	last_us = now
	if ms > 100.0 and g.clock > 1.0:
		slow_frames.append([snappedf(g.clock, 0.1), snappedf(ms, 1.0)])
	if g.over:
		_finish("victory")
		return true
	if g.clock >= next_tick:
		next_tick += TICK
		_tick()
	if wall_limit > 0.0 and (Time.get_ticks_msec() - wall0) / 1000.0 > wall_limit:
		_finish("wall_limit")
		return true
	if g.clock >= end_t:
		_finish("timeout")
		return true
	return false


func _tick() -> void:
	var c: float = g.clock
	for i in P.size():
		var X: Dictionary = P[i]
		if g.eliminated[i]:
			if X["out_t"] < 0.0:
				X["out_t"] = snappedf(c, 1.0)
			continue
		var ai = null
		for a in g.ais:
			if a.team == i:
				ai = a
		# idle workers (3 or more standing idle at once)
		var idle := 0
		for w in g.workers(i):
			if w.order == "idle":
				idle += 1
		if idle >= 3:
			if X["idle_since"] < 0.0:
				X["idle_since"] = c
			X["idle_max"] = maxf(X["idle_max"], c - X["idle_since"])
		else:
			X["idle_since"] = -1.0
		# new buildings
		var nb := 0
		for b in g.buildings:
			if is_instance_valid(b) and b.team == i and not b.dead:
				nb += 1
		if nb > X["bld_n"] or int(g.players[i]["gold"]) < 400:
			X["bld_t"] = c
		X["bld_n"] = nb
		X["nobuild_max"] = maxf(X["nobuild_max"], c - X["bld_t"])
		# attacks
		if ai and X["first_attack"] < 0.0 and (bool(ai._attacking) or (ai._raiders as Array).size() > 0):
			X["first_attack"] = snappedf(c, 1.0)
		# supply block
		var used: int = g.supply_used(i)
		var cap: int = g.players[i]["cap"]
		if used >= cap - 1 and cap < 200 and int(g.players[i]["gold"]) >= 150:
			if X["block_since"] < 0.0:
				X["block_since"] = c
			X["block_max"] = maxf(X["block_max"], c - X["block_since"])
		else:
			X["block_since"] = -1.0
		# income at zero while a hall still has soil and there are workers
		var earned := int(g.stats[i]["gold"])
		var soil := false
		for h in g.halls_of(i):
			if h.has_method("soil_left") and h.soil_left() > 0.001:
				soil = true
		if earned > X["earn"] or not soil or g.workers(i).size() < 3:
			X["earn_t"] = c
		X["earn"] = earned
		X["noincome_max"] = maxf(X["noincome_max"], c - X["earn_t"])
	# units told to move that stay put for 3 minutes
	var cur := {}
	for u in g.units:
		if not is_instance_valid(u) or u.dead:
			continue
		var id: int = u.get_instance_id()
		cur[id] = true
		var o := String(u.order)
		var moving := o == "move" or o == "amove" or o == "d_amove"
		if not moving or u.position.distance_to(u.order_point) < 96.0:
			upos.erase(id)
			continue
		var r = upos.get(id)
		if r == null or (r[0] as Vector2).distance_to(u.position) > 24.0 or String(r[2]) != o:
			upos[id] = [u.position, c, o]
			continue
		if c - float(r[1]) >= 180.0 and not stuck_seen.has(id):
			stuck_seen[id] = true
			stuck.append([snappedf(c, 1.0), u.team, String(u.kind), o, [int(u.position.x), int(u.position.y)], [int(u.order_point.x), int(u.order_point.y)],
				{"path": u.path.size(), "path_i": u.path_i, "pending": u.path_pending, "stuck_t": snappedf(u.stuck_t, 0.1), "speed": snappedf(u.speed, 0.1),
				"shield": bool(u.get("shield_up")), "wind": snappedf(float(u.get("wind")), 0.1), "down": u.powered_down(), "target": is_instance_valid(u.target) and u.target != null, "goal": [int(u.path_goal.x), int(u.path_goal.y)] if u.path_goal != Vector2.INF else [],
				"vel": [snappedf(u.velocity.x, 0.1), snappedf(u.velocity.y, 0.1)] if "velocity" in u else []}])
	for id in upos.keys():
		if not cur.has(id):
			upos.erase(id)


func _finish(cause: String) -> void:
	done = true
	var row := {"id": gid, "version": ProjectSettings.get_setting("application/config/version", "dev"), "map": map,
		"mode": MapGen.mode_of(map), "facs": facs, "sides": sides, "lvls": lvls, "seed": seed_,
		"cause": cause, "winner": int(g.winner), "winner_side": sides[g.winner] if g.winner >= 0 else -1,
		"end_t": snappedf(g.clock, 1.0), "wall_s": snappedf((Time.get_ticks_msec() - wall0) / 1000.0, 1.0),
		"slow_frames": slow_frames.size(), "slow_worst": slow_frames.map(func(x) -> float: return x[1]).max() if not slow_frames.is_empty() else 0.0,
		"slow_list": slow_frames.slice(0, 20), "stuck": stuck.slice(0, 40), "stuck_n": stuck.size(), "players": []}
	for i in P.size():
		var X: Dictionary = P[i]
		var st: Dictionary = g.standing(i)
		(row["players"] as Array).append({"team": i, "faction": facs[i], "side": sides[i], "level": X["ai_level"], "plan": X["strategy"],
			"out_t": X["out_t"], "idle3_max_s": X["idle_max"], "nobuild_max_s": X["nobuild_max"], "first_attack": X["first_attack"],
			"block_max_s": X["block_max"], "noincome_max_s": X["noincome_max"], "earned": int(g.stats[i]["gold"]),
			"killed": int(g.stats[i]["killed"]), "lost": int(g.stats[i]["lost"]), "end_army": st["army"], "end_workers": st["workers"],
			"end_buildings": st["buildings"], "end_gold": int(g.players[i]["gold"])})
	DirAccess.make_dir_recursive_absolute(out_dir)
	var lines := PackedStringArray()
	if g.mlog:
		lines = g.mlog.lines
	var f := FileAccess.open("%s/%s.log" % [out_dir, gid], FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	f = FileAccess.open("%s/%s.json" % [out_dir, gid], FileAccess.WRITE)
	f.store_string(JSON.stringify(row, " "))
	f.close()
	print("SOAK DONE ", gid, " ", cause, " winner ", row["winner"], " at ", row["end_t"], " wall ", row["wall_s"])
	quit(0)
