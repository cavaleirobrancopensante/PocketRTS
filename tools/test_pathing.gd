extends SceneTree
## The pathfinding test bed (docs/pathfinding_audit.md): groups of every faction ordered about real
## maps (up and down cliffs, to a cliff edge, up ramps, through gaps between buildings, a big crowd
## into a small spot, across the map, melee against shooters on high ground, guns and horses round
## corners), with numbers for each case:
##   arrived   units that got there (within R of the click; R grows with the group) / units sent
##   time      when the last one got there, against the ideal (the path's length at the slowest speed)
##   stuck     the longest any unit stood still while it still had somewhere to go (s)
##   cliff/bld units pressed against a cliff / a building at the end
##   far       units at the end that are near in a straight line but far to walk (the wrong level)
##   jitter    how much the units shuffle about once they stand (px/s, average over the group)
##   godot --headless --fixed-fps 30 --script res://tools/test_pathing.gd [-- only=name maps=a,b out=file]
## With "shots=<dir>" (tools/shot_pathing.gd, under xvfb) it saves a picture of every case at the start
## and at the end. It prints one line per case and "pathing: PASS" / "FAIL (n)" by the limits in LIMITS.
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var only := ""
var maps: Array = ["greenhold", "kestrel_rise", "frostmere", "hollowfen", "thornwood_maze"]
var map_i := -1
var out_path := ""
var shots := ""
var lines: Array = []
var results: Array = []
var keep_units := {}
var made_buildings: Array = []
var shot_frames := 30
var spacing := 24.0             # (px between the units of a group as it starts)

## What a case must do to pass (checked on every case unless the case says otherwise).
const LIMITS := {"arrived": 1.0, "stuck": 6.0, "far": 0}

const CROWN := [["musketeer", 8], ["cuirassier", 2], ["cannon", 1]]
const BROOD := [["raptor", 8], ["brute", 3]]
const CLOCK := [["clock_soldier", 8], ["pendulum", 2]]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"only": only = kv[1]
			"maps": maps = Array(kv[1].split(","))
			"out": out_path = kv[1]
			"shots": shots = kv[1]
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if map_i < 0 and t > 0.2:
		_next_map()
		return false
	if main.game == null or started:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		if shots != "":
			g.hud.visible = false
	paused = false
	if t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		if g.controls:
			g.controls.process_mode = Node.PROCESS_MODE_DISABLED
		_run_map()
	return false


func _next_map() -> void:
	map_i += 1
	if map_i >= maps.size():
		_finish()
		return
	started = false
	t = 0.3
	if main.game:
		main.game.queue_free()
		main.game = null
	seed(4242)
	main.start({"map": maps[map_i], "seed": 4242, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})


func _finish() -> void:
	print("")
	for l in lines:
		print(l)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(results, "  "))
		f.close()
	print("pathing: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ the cases

func _run_map() -> void:
	g.explored.fill(1)
	if "visible_cells" in g:
		pass
	# (the other side's starting workers would pick fights with the test groups: they go)
	for u in g.units.duplicate():
		if u.team != 0:
			g.consume_unit(u)
	await physics_frame
	for u in g.units:
		keep_units[u] = true
	var map: String = maps[map_i]
	var edge := _edge_spot(true)
	var ramp := _ramp_spot()
	var area := _open_area(9, 7)
	var sets := {"crown": CROWN, "brood": BROOD, "clock": CLOCK}
	if edge.is_empty():
		lines.append("%s: no cliff edge found" % map)
	else:
		var hi_in: Vector2 = edge["hi_in"]
		var hi_rim: Vector2 = edge["hi_rim"]
		var lo_foot: Vector2 = edge["lo_foot"]
		var lo_out: Vector2 = edge["lo_out"]
		for fk in sets:
			await _case("%s/up_cliff/%s" % [map, fk], sets[fk], lo_out, hi_in, "move")
			await _case("%s/down_cliff/%s" % [map, fk], sets[fk], hi_in, lo_out, "move")
		await _case("%s/edge_high/crown" % map, CROWN, edge["hi_far"], hi_rim, "move")
		await _case("%s/edge_low/brood" % map, BROOD, edge["lo_far"], lo_foot, "move")
		await _case("%s/edge_high_from_low/clock" % map, CLOCK, lo_out, hi_rim, "move")
		await _case("%s/edge_low_from_high/crown" % map, CROWN, hi_in, lo_foot, "move")
		# a click on the rim of the plateau (a cliff cell: it looks like the high ground's edge)
		await _case("%s/rim_click/crown" % map, CROWN, edge["hi_far"], edge["rim"], "move")
		await _case("%s/rim_click_from_low/brood" % map, BROOD, edge["lo_out"], edge["rim"], "move")
		# a group spread out over the high ground sent to the edge
		spacing = 56.0
		await _case("%s/edge_high_spread/clock" % map, CLOCK, edge["hi_far"], hi_rim, "move")
		spacing = 24.0
		await _melee_case("%s/melee_vs_high/open" % map, edge, false)
		await _melee_case("%s/melee_vs_high/walled" % map, edge, true)
	if not ramp.is_empty():
		await _case("%s/ramp_amove/brood" % map, BROOD, ramp["bottom"], ramp["top"], "amove")
		await _case("%s/ramp_up/guns" % map, [["cannon", 2], ["cuirassier", 4], ["mortar", 1]], ramp["bottom"], ramp["top"], "move")
		await _attack_building_case("%s/ramp_attack_bld/brood" % map, ramp)
	if area.x >= 0:
		await _gap_case("%s/gap/crown" % map, area, CROWN)
		await _gap_case("%s/gap/brood" % map, area, BROOD)
		await _gap_case("%s/gap/clock" % map, area, CLOCK)
		await _gap_case("%s/gap/guns" % map, area, [["cannon", 2], ["cuirassier", 3], ["powder_wagon", 1]])
		var mid: Vector2 = g.cell_center(area + Vector2i(4, 3))
		var far := _open_spot_near(mid + Vector2(-500, 0), 1)
		if far != Vector2.INF:
			await _case("%s/crowd40" % map, [["musketeer", 30], ["raptor", 10]], far, mid, "move")
	await _base_case("%s/base/crown" % map)
	# across the map: from one start to the other (through whatever passes lie between)
	var a: Vector2 = Vector2(g.starts[0]) * g.T
	var b: Vector2 = Vector2(g.starts[1]) * g.T
	var sa := _open_spot_near(a + (b - a).normalized() * 260.0, 0)
	var sb := _open_spot_near(b + (a - b).normalized() * 260.0, 0)
	if sa != Vector2.INF and sb != Vector2.INF:
		await _case("%s/across/mixed" % map, [["musketeer", 6], ["raptor", 6], ["clock_soldier", 4], ["cannon", 1], ["brute", 2]], sa, sb, "move", 150.0)
	_next_map()


## n of each kind in `set` start round `from` and are ordered to `to` (a right click; "amove": A + click).
func _case(name: String, set: Array, from: Vector2, to: Vector2, how: String, limit := 70.0) -> void:
	if only != "" and not name.contains(only):
		return
	var us := _spawn(set, from, 0)
	if us.is_empty():
		lines.append("%-42s no room to start" % name)
		return
	await physics_frame
	await physics_frame
	var ideal := _ideal(us, to)
	if how == "amove":
		g.group_move(us, to, true)
	else:
		g.smart_command(us, to, true)
	var m := await _watch(name, us, to, ideal, limit, null)
	_report(name, m)
	await _clear(us)


func _spawn(set: Array, at: Vector2, team: int) -> Array:
	var n := 0
	for s in set:
		n += int(s[1])
	var spots := _blob_spots(at, n)
	var us: Array = []
	var i := 0
	for s in set:
		for k in int(s[1]):
			if i >= spots.size():
				break
			var u: Unit = g._add_unit(s[0], team, spots[i])
			i += 1
			us.append(u)
	return us


## Spots for n units round p, on p's level and reachable from it in a straight line.
func _blob_spots(p: Vector2, n: int) -> Array:
	var out: Array = []
	var lv: int = g.level_of(p)
	var r := 0
	while out.size() < n and r < 14:
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var q := p + Vector2(x, y) * spacing
				var c: Vector2i = g.cell_of(q)
				if g.in_map(c) and g.is_free(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == lv \
						and g.line_clear(p, q) and g._clear_at(q, 16.0, 0):
					out.append(q)
					if out.size() >= n:
						return out
		r += 1
	return out


## The best time: the path's length from the group's middle at its slowest unit's speed.
func _ideal(us: Array, to: Vector2) -> float:
	var c := Vector2.ZERO
	var slow := INF
	for u in us:
		c += u.position
		slow = minf(slow, maxf(u.speed, 10.0))
	c /= us.size()
	return _walk_len(c, to) / slow


func _walk_len(a: Vector2, b: Vector2) -> float:
	var ca: Vector2i = g.cell_of(a)
	var cb: Vector2i = g.cell_of(b)
	if not g.open_cell(ca):
		ca = g.nearest_free(ca, 4)
	if not g.open_cell(cb):
		cb = _free_on_level(cb)
	var pts: PackedVector2Array = g.astar.get_point_path(ca, cb)
	if pts.is_empty():
		return INF
	var l := a.distance_to(pts[0]) + pts[pts.size() - 1].distance_to(b)
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l


## The nearest open cell on c's own height level (a goal on a cliff's rim means the high ground).
func _free_on_level(c: Vector2i) -> Vector2i:
	var lv := int(g.height[g.idx(c)])
	for r in range(1, 6):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var q := c + Vector2i(x, y)
				if maxi(absi(x), absi(y)) == r and g.in_map(q) and g.is_free(q) and int(g.height[g.idx(q)]) == lv and g.ramp[g.idx(q)] == 0:
					return q
	return g.nearest_free(c, 4)


func _arrive_r(n: int) -> float:
	return 40.0 + 12.0 * sqrt(float(n))


## Run the case until every unit is there and standing (or `limit` s), then 3 s more to measure the
## shuffling. `bld`: an attack on a building (a unit is "there" once it is in reach of it).
func _watch(name: String, us: Array, to: Vector2, ideal: float, limit: float, bld: Building) -> Dictionary:
	var n := us.size()
	var R := _arrive_r(n)
	var arr := {}
	var stuck := {}
	var stuck_max := 0.0
	var hist := {}
	var clk := 0.0
	var dt := 1.0 / 30.0
	var settle := -1.0
	var jit := 0.0
	var jit_max := 0.0
	var jsum := {}
	var stuck_who := ""
	var lv_to: int = g.level_of(to)
	var dupes := 0
	for u in us:
		for o in us:
			if o != u and u.order_point.distance_to(o.order_point) < 6.0 and bld == null:
				dupes += 1
				break
	if shots != "":
		await _shot(name, "start", us, to)
	while true:
		await physics_frame
		clk += dt
		for u in us:
			if not is_instance_valid(u) or u.dead:
				continue
			if u.d["faction"] == "clockwork":
				u.wind = 1.0
			var pos: Vector2 = u.position
			var there := false
			if bld:
				there = is_instance_valid(bld) and (bld.dead or bld.edge_distance(pos) - u.radius <= u._range() + 6.0)
			else:
				there = pos.distance_to(to) <= R and g.level_of(pos) == lv_to
			if there and not arr.has(u):
				arr[u] = clk
			var h: Array = hist.get(u, [])
			h.append(pos)
			if h.size() > 30:
				h.pop_front()
			hist[u] = h
			var moving_order: bool = u.order != "idle" and u.order != "hold"
			if h.size() >= 30 and moving_order and not there and h[0].distance_to(pos) < 4.0 and u.phase == "":
				stuck[u] = float(stuck.get(u, 0.0)) + dt
				if float(stuck[u]) + 1.0 > stuck_max:
					stuck_who = "%s at %s order %s path %d/%d goal %s stuck_t %.1f vel %.0f" % [u.kind, str(g.cell_of(pos)), u.order, u.path_i, u.path.size(),
						str(g.cell_of(u.path_goal)) if u.path_goal != Vector2.INF else "-", u.stuck_t, u.velocity.length()]
				stuck_max = maxf(stuck_max, float(stuck[u]) + 1.0)
			else:
				stuck[u] = 0.0
			if settle >= 0.0 and h.size() >= 2:
				var mv: float = h[h.size() - 2].distance_to(pos)
				jit += mv
				jsum[u] = float(jsum.get(u, 0.0)) + mv
				jit_max = maxf(jit_max, mv * 30.0)
		var alive := us.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
		if settle < 0.0:
			var done := true
			for u in alive:
				if not arr.has(u) or (bld == null and u.order != "idle"):
					done = false
			if done or clk >= limit or alive.is_empty() or (bld and (not is_instance_valid(bld) or bld.dead)):
				settle = clk
		elif clk - settle >= 3.0:
			break
	# the end: who got there, who is pressed against what, who is on the wrong side
	var t_all := 0.0
	for u in arr:
		t_all = maxf(t_all, float(arr[u]))
	var alive := us.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var cliff := 0
	var bldn := 0
	var far := 0
	var overlap := 0
	for u in alive:
		for o in alive:
			if o != u and u.position.distance_to(o.position) < (u.radius + o.radius) * 0.55:
				overlap += 1
				break
	var why: Array = []
	for u in alive:
		var pr := _pressed(u)
		if pr == "cliff":
			cliff += 1
		elif pr == "bld":
			bldn += 1
		if bld == null:
			var straight: float = u.position.distance_to(to)
			var walk := _walk_len(u.position, to)
			if straight < R * 2.5 and walk > maxf(R * 2.5, straight * 2.0 + 96.0):
				far += 1
		if not arr.has(u) or float(stuck.get(u, 0.0)) > 0.0:
			why.append("    %s at %s order %s path %d/%d goal %s target %s stuck %.1f" % [u.kind, str(g.cell_of(u.position)), u.order,
				u.path_i, u.path.size(), str(g.cell_of(u.path_goal)) if u.path_goal != Vector2.INF else "-",
				(u.target.kind if is_instance_valid(u.target) else "-"), u.stuck_t])
	var jw: Unit = null
	for u in jsum:
		if jw == null or float(jsum[u]) > float(jsum[jw]):
			jw = u
	if jw and is_instance_valid(jw) and float(jsum[jw]) > 30.0:
		why.append("    most shuffling: %s %.0f px/s at %s order %s target %s vel %.0f push %.0f sep_from %s" % [jw.kind, float(jsum[jw]) / 3.0, str(g.cell_of(jw.position)), jw.order,
			(jw.target.kind if is_instance_valid(jw.target) else "-"), jw.velocity.length(), jw._push.length(), str(g.level_of(jw.position))])
	if stuck_max > 2.0:
		why.append("    stuck longest: " + stuck_who)
	if shots != "":
		await _shot(name, "end", us, to)
	var nn := maxi(alive.size(), 1)
	return {"n": n, "arrived": arr.size(), "alive": alive.size(), "t_all": t_all if arr.size() > 0 else -1.0, "ideal": ideal,
		"stuck": stuck_max, "cliff": cliff, "dupes": dupes, "overlap": overlap, "bld": bldn, "far": far, "jitter": jit / 3.0 / nn, "jit_max": jit_max, "why": why}


func _report(name: String, m: Dictionary, limits := LIMITS) -> void:
	var ok := true
	var miss: Array = []
	if float(m["arrived"]) < float(m["alive"]) * float(limits["arrived"]):
		ok = false
		miss.append("arrived")
	if float(m["stuck"]) > float(limits["stuck"]):
		ok = false
		miss.append("stuck")
	if int(m["far"]) > int(limits["far"]):
		ok = false
		miss.append("far")
	if not ok:
		fails += 1
	var ratio := float(m["t_all"]) / maxf(float(m["ideal"]), 0.1) if float(m["t_all"]) > 0.0 else -1.0
	var l := "%-6s %-42s arrived %2d/%-2d time %5.1f ideal %5.1f (x%.2f) stuck %4.1f cliff %2d bld %2d far %2d jitter %4.1f same-spot %2d overlap %2d%s" % [
		"ok" if ok else "FAIL", name, int(m["arrived"]), int(m["alive"]), float(m["t_all"]), float(m["ideal"]), ratio,
		float(m["stuck"]), int(m["cliff"]), int(m["bld"]), int(m["far"]), float(m["jitter"]), int(m["dupes"]), int(m["overlap"]),
		("  <- " + ", ".join(miss)) if not ok else ""]
	print(l)
	for w in m["why"]:
		print(w)
	lines.append(l)
	var r := m.duplicate()
	r["name"] = name
	r["ok"] = ok
	results.append(r)


## What the unit is pressed against: "cliff", "bld" (building, wall, gate) or "" (nothing).
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
			var q := u.position.clamp(rc.position, rc.end)
			if q.distance_to(u.position) > lim:
				continue
			if g.cliff[i] == 1:
				return "cliff"
			if v >= 2:
				best = "bld"
	return best


func _clear(us: Array) -> void:
	for u in g.units.duplicate():
		if not keep_units.has(u) and is_instance_valid(u) and not u.dead:
			g.consume_unit(u)
	for b in made_buildings:
		if is_instance_valid(b) and not b.dead:
			b.die()
	made_buildings.clear()
	for k in 3:
		await physics_frame


# ------------------------------------------------------------------ special cases

## Brood melee ordered (A + click) at Musketeers on the high ground just over a cliff edge. Open: the
## way is round by a ramp. Walled: the plateau's ramps are shut by a wall with a gate. Measured: the
## unit-seconds spent pressed against the cliff below the shooters (they should go round, or break
## the wall, not stand under the cliff), and how many got up.
func _melee_case(name: String, edge: Dictionary, walled: bool) -> void:
	if only != "" and not name.contains(only):
		return
	var plateau := _plateau(g.cell_of(edge["hi_in"]))
	if plateau.is_empty():
		return
	if walled:
		var n := 0
		for c in plateau["rim"]:
			var b: Building = g._add_building("gate" if n == 0 else "wall", 1, c, true)
			made_buildings.append(b)
			n += 1
		await physics_frame
	var foes := _spawn([["musketeer", 4]], edge["hi_in"], 1)
	var foe_at: Array = []
	for f in foes:
		f.cmd_hold()
		foe_at.append(f.position)
	var us := _spawn(BROOD, edge["lo_out"], 0)
	await physics_frame
	g.group_move(us, edge["hi_in"], true)
	var clk := 0.0
	var under := 0.0
	var up := 0
	var hit_wall := 0
	var mh := {}
	if shots != "":
		await _shot(name, "start", us, edge["hi_in"])
	var shot_mid := false
	while clk < 45.0:
		await physics_frame
		clk += 1.0 / 30.0
		for i in foes.size():
			var f: Unit = foes[i]
			if is_instance_valid(f) and not f.dead:
				f.hp = f.max_hp        # (they never die nor get shoved off: the case measures where the melee goes)
				f.position = foe_at[i]
		for u in us:
			if not is_instance_valid(u) or u.dead:
				continue
			u.hp = u.max_hp
			# (pressed against the cliff below them and not getting anywhere: walking along the foot of it
			# on the way round to the ramp doesn't count)
			var h: Array = mh.get(u, [])
			h.append(u.position)
			if h.size() > 30:
				h.pop_front()
			mh[u] = h
			if g.level_of(u.position) == 0 and _pressed(u) == "cliff" and u.position.distance_to(edge["lo_foot"]) < 260.0 \
					and h.size() >= 30 and h[0].distance_to(u.position) < 12.0:
				under += 1.0 / 30.0
		if OS.get_environment("PATH_DEBUG") != "" and fmod(clk, 5.0) < 1.0 / 30.0:
			for u in us:
				if is_instance_valid(u) and not u.dead:
					print("  t%.0f %s lv%d cell %s order %s target %s path %d/%d goal %s pressed %s stuck %.1f dist-to-target %.0f" % [clk, u.kind, g.level_of(u.position), str(g.cell_of(u.position)), u.order,
						(u.target.kind + str(g.cell_of(u.target.position))) if is_instance_valid(u.target) else "-", u.path_i, u.path.size(),
						str(g.cell_of(u.path_goal)) if u.path_goal != Vector2.INF else "-", _pressed(u), u.stuck_t,
						u.target.edge_distance(u.position) if is_instance_valid(u.target) else -1.0])
		if shots != "" and not shot_mid and clk > 15.0:
			shot_mid = true
			await _shot(name, "mid", us, edge["lo_foot"])
	for u in us:
		if is_instance_valid(u) and not u.dead:
			if g.level_of(u.position) == 1:
				up += 1
			if is_instance_valid(u.target) and u.target is Building:
				hit_wall += 1
	if shots != "":
		await _shot(name, "end", us, edge["lo_foot"])
	var ok := under < 2.0 * us.size() and (up + hit_wall) >= us.size() / 2
	if not ok:
		fails += 1
	var l := "%-6s %-42s under-cliff %5.1f unit-s, on top %d/%d, at the wall %d" % ["ok" if ok else "FAIL", name, under, up, us.size(), hit_wall]
	print(l)
	lines.append(l)
	results.append({"name": name, "ok": ok, "under": under, "up": up, "n": us.size(), "wall": hit_wall})
	for f in foes:
		if is_instance_valid(f):
			g.consume_unit(f)
	await _clear(us)


## Brood melee told to attack an enemy building (a Barracks) at the top of a ramp.
func _attack_building_case(name: String, ramp: Dictionary) -> void:
	if only != "" and not name.contains(only):
		return
	var top: Vector2 = ramp["top"]
	var c: Vector2i = g.cell_of(top) + Vector2i(-1, -1)
	if g.placement_problem(1, "barracks", c, true, true) != "":
		var placed := false
		for r in range(1, 5):
			for y in range(-r, r + 1):
				for x in range(-r, r + 1):
					if not placed and g.placement_problem(1, "barracks", c + Vector2i(x, y), true, true) == "":
						c = c + Vector2i(x, y)
						placed = true
		if not placed:
			lines.append("%-42s no room for the barracks" % name)
			return
	var b: Building = g._add_building("barracks", 1, c, true)
	made_buildings.append(b)
	b.hp = 1e7
	b.max_hp = 1e7
	var us := _spawn(BROOD, ramp["bottom"], 0)
	await physics_frame
	var ideal := _ideal(us, g.approach_point(b, us[0].position))
	g.smart_command(us, b.center())
	var m := await _watch(name, us, b.center(), ideal, 60.0, b)
	_report(name, m)
	await _clear(us)


## Two of our Cottages with a one-cell gap between them on open ground: the group goes through.
func _gap_case(name: String, area: Vector2i, set: Array) -> void:
	if only != "" and not name.contains(only):
		return
	var size: Vector2i = Vector2i(Defs.BUILDINGS["cottage"]["size"][0], Defs.BUILDINGS["cottage"]["size"][1]) if Defs.BUILDINGS["cottage"].has("size") else Vector2i(2, 2)
	var mid := area + Vector2i(4, 3)
	var a: Building = g._add_building("cottage", 0, mid + Vector2i(-size.x, -size.y / 2 - size.y), true)
	var b: Building = g._add_building("cottage", 0, mid + Vector2i(-size.x, 1 + size.y / 2 - size.y + size.y), true)
	made_buildings.append_array([a, b])
	await physics_frame
	var from := _open_spot_near(g.cell_center(mid) + Vector2(-360, 0), 0)
	var to := _open_spot_near(g.cell_center(mid) + Vector2(320, 0), 0)
	if from == Vector2.INF or to == Vector2.INF:
		await _clear([])
		return
	await _case(name, set, from, to, "move")
	await _clear([])


## Round our own base: the hall with Cottages, a Barracks and a wall round them (one-cell lanes
## between), a group sent from one side to the other.
func _base_case(name: String) -> void:
	if only != "" and not name.contains(only):
		return
	var hall: Building = g._own_hall(0)
	if hall == null:
		return
	var hc: Vector2i = hall.cell
	var hs: Vector2i = hall.size
	var spots := [[Vector2i(hs.x + 1, 0), "cottage"], [Vector2i(hs.x + 1, 3), "cottage"], [Vector2i(-3, 0), "cottage"],
		[Vector2i(0, hs.y + 1), "barracks"], [Vector2i(-4, 3), "cottage"]]
	for s in spots:
		var c: Vector2i = hc + s[0]
		if g.placement_problem(0, s[1], c, true, true) == "":
			made_buildings.append(g._add_building(s[1], 0, c, true))
	await physics_frame
	var ctr: Vector2 = hall.center()
	var from := _open_spot_near(ctr + Vector2(-230, -150), -1)
	var to := _open_spot_near(ctr + Vector2(230, 170), -1)
	if from != Vector2.INF and to != Vector2.INF:
		await _case(name, CROWN, from, to, "move")
		await _case(name.replace("crown", "brood"), BROOD, to, from, "move")
	await _clear([])


# ------------------------------------------------------------------ finding places on the map

## A straight stretch of cliff with open ground on both levels, away from buildings, whose ramp is a
## long way round: {hi_rim (high, beside the cliff), hi_in (3 in), hi_far (10 in), lo_foot (low,
## beside the cliff), lo_out (5 out), lo_far (12 out), d (toward the low ground)}.
func _edge_spot(want_detour: bool) -> Dictionary:
	var best := {}
	var best_score := -INF
	for y in range(8, g.H - 8):
		for x in range(8, g.W - 8):
			var c := Vector2i(x, y)
			if not _hi_open(c):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var mid: Vector2i = c + d
				var lo: Vector2i = c + d * 2
				if g.cliff[g.idx(mid)] != 1 or not _lo_open(lo):
					continue
				var side := Vector2i(d.y, d.x)
				# a straight rim: the same two cells beside it on either side
				var straight := true
				for s in [-1, 1]:
					if not _hi_open(c + side * s) or g.cliff[g.idx(mid + side * s)] != 1:
						straight = false
				if not straight:
					continue
				var ok := true
				for k in [3, 6]:
					if not _area(c - d * k, 1, 1):
						ok = false
				for k in [5, 12]:
					if not _area(lo + d * (k - 2) + d * 2 - d * 2, 0, 1):
						ok = false
				if not ok:
					continue
				if _near_building(g.cell_center(c), 150.0) or _near_foe(g.cell_center(c), 640.0):
					continue
				var detour := _walk_len(g.cell_center(lo), g.cell_center(c))
				if detour == INF:
					continue
				var score := minf(detour, 1400.0) - absf(float(x - g.W / 2)) * 0.5
				if score > best_score:
					best_score = score
					best = {"hi_rim": g.cell_center(c), "hi_in": g.cell_center(c - d * 3), "hi_far": g.cell_center(c - d * 6),
						"lo_foot": g.cell_center(lo), "rim": g.cell_center(mid), "lo_out": g.cell_center(lo + d * 5), "lo_far": g.cell_center(lo + d * 12), "d": d}
	return best


func _hi_open(c: Vector2i) -> bool:
	return g.in_map(c) and g.height[g.idx(c)] == 1 and g.solid[g.idx(c)] == 0 and g.ramp[g.idx(c)] == 0 and g.cliff[g.idx(c)] == 0


func _lo_open(c: Vector2i) -> bool:
	return g.in_map(c) and g.height[g.idx(c)] == 0 and g.solid[g.idx(c)] == 0 and g.ramp[g.idx(c)] == 0


## A (2r+1)-square of open ground of level lv round c.
func _area(c: Vector2i, lv: int, r: int) -> bool:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var q := c + Vector2i(x, y)
			if not (_hi_open(q) if lv == 1 else _lo_open(q)):
				return false
	return true


func _near_start(p: Vector2, r: float) -> bool:
	for s in g.starts:
		if p.distance_to(Vector2(s) * g.T) < r:
			return true
	for b in g.buildings:
		if not b.dead and b.center().distance_to(p) < r * 0.6:
			return true
	return false


func _near_foe(p: Vector2, r: float) -> bool:
	for b in g.buildings:
		if not b.dead and b.team != 0 and b.edge_distance(p) < r:
			return true
	return false


func _near_building(p: Vector2, r: float) -> bool:
	for b in g.buildings:
		if not b.dead and b.edge_distance(p) < r:
			return true
	return false


## A ramp with open ground at both ends: {top (4 cells up on the high ground), bottom (4 down)}.
func _ramp_spot() -> Dictionary:
	for y in range(6, g.H - 6):
		for x in range(6, g.W - 6):
			var c := Vector2i(x, y)
			if g.ramp[g.idx(c)] != 1:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var up: Vector2i = c + d
				if not _hi_open(up):
					continue
				var top: Vector2i = c + d * 4
				var bot: Vector2i = c - d * 4
				# (the far end of the ramp, then 3 out on the low ground)
				var k := 1
				while g.in_map(c - d * k) and g.ramp[g.idx(c - d * k)] == 1:
					k += 1
				bot = c - d * (k + 3)
				if _area(top, 1, 1) and _area(bot, 0, 1) and not _near_start(g.cell_center(top), 300.0):
					return {"top": g.cell_center(top), "bottom": g.cell_center(bot)}
	return {}


## The plateau's open cells from c (4-way, high ground, no ramps), and the ones beside a ramp ("rim"):
## {} if the plateau has a building on it (a base).
func _plateau(c: Vector2i) -> Dictionary:
	var seen := {c: true}
	var q: Array = [c]
	var qi := 0
	var rim: Array = []
	while qi < q.size():
		var p: Vector2i = q[qi]
		qi += 1
		var by_ramp := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if not g.in_map(n):
				continue
			if g.ramp[g.idx(n)] == 1:
				by_ramp = true
			if g.solid[g.idx(n)] == 2:
				return {}
			if not seen.has(n) and _hi_open(n):
				seen[n] = true
				q.append(n)
		if by_ramp:
			rim.append(p)
	return {"cells": q, "rim": rim}


## A w x h block of open flat ground away from the bases (its top-left cell), or (-1, -1).
func _open_area(w: int, h: int) -> Vector2i:
	for y in range(6, g.H - h - 6):
		for x in range(6, g.W - w - 6):
			var c := Vector2i(x, y)
			var h0: int = g.height[g.idx(c)]
			var ok := true
			for yy in range(-2, h + 2):
				for xx in range(-14, w + 14):
					var q := c + Vector2i(xx, yy)
					if not g.in_map(q) or g.solid[g.idx(q)] != 0 or g.ramp[g.idx(q)] != 0 or g.height[g.idx(q)] != h0:
						ok = false
						break
				if not ok:
					break
			if ok and not _near_start(g.cell_center(c), 420.0):
				return c
	return Vector2i(-1, -1)


## The nearest spot to p with a 3x3 of open ground round it (level lv, or any when -1).
func _open_spot_near(p: Vector2, lv: int) -> Vector2:
	var c0: Vector2i = g.cell_of(g.on_map(p))
	for r in range(0, 12):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := c0 + Vector2i(x, y)
				if not g.in_map(c):
					continue
				var l := int(g.height[g.idx(c)])
				if lv >= 0 and l != lv:
					continue
				if _area(c, l, 1):
					return g.cell_center(c)
	return Vector2.INF


# ------------------------------------------------------------------ pictures

func _shot(name: String, when: String, us: Array, at: Vector2) -> void:
	var cam: Camera2D = g.camera
	var c := at
	var nn := 1
	for u in us:
		if is_instance_valid(u) and not u.dead:
			c += u.position
			nn += 1
	c /= nn
	cam.position = c
	cam.zoom = Vector2(0.9, 0.9)
	cam.reset_smoothing()
	for i in shot_frames:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(shots.path_join("%s_%s.png" % [name.replace("/", "_"), when]))
