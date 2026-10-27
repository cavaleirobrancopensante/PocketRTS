extends SceneTree
## The Powder Mill crew in a crowded base (the owner, 0.14.26: "the workers on powder mill are
## most of the time stuck, their animation stuck also"):
##   godot --headless --fixed-fps 30 --script res://tools/test_mill_crowded.gd [-- verbose]
## Five mills at once, each with six labourers sent to it from a few tiles away, for a walk-in of
## WALK_IN s and then MEASURE s of game time:
##  A  neighbours tight on the front and the left, a Barracks behind (the owner's screenshot)
##  B  neighbours tight on both sides and behind, the front open
##  C  the front against the plateau's cliff edge, a Cottage on the left
##  D  shut in: Cottages tight on the front and both sides (only the back is open)
##  E  open ground
## Every tick, per worker: his state, where he is, whether his picture changed (frame, strip or
## view) and how long he has stood neither moving nor animating. PASS when every worker works
## (manning, and not frozen) at least 90% of the measured time, none stands frozen more than 3 s
## at a stretch, and each really does the round: digs at all three heaps, tips at least MIN_LOADS
## loads into the hopper, never goes LOAD_GAP s without tipping one and never stays on one spot
## (within 4 px) more than PARKED s (the old fallback had the whole crew shovelling air at the
## mill's side, animated but going nowhere); none stands
## on a solid cell of his mill (going in through the shed when the yard is shut in is allowed),
## and the six don't stack on one spot (two men within STACK px of one another, drawn on top of
## each other, only for a moment as they cross: at most 0.5 s, three at most 0.25 s).
const WALK_IN := 15.0
const MEASURE := 180.0
const FROZEN := 1.0            # (a held frame this long counts as frozen; the longest real hold, the dig, is 0.7 s)
const MIN_LOADS := 20          # (a round takes about 4 s: some 45 in MEASURE s)
const PARKED := 3.0
const LOAD_GAP := 10.0
const STACK := 3.0             # (closer than this, two men are drawn on top of each other)
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var verbose := false
var used: Array = []           # Rect2i areas taken by a scenario


func _initialize() -> void:
	verbose = OS.get_cmdline_user_args().has("verbose")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > WALK_IN + MEASURE + 120.0:
		print("FAIL  the test ran out of time (a script error?)")
		quit(1)
		return true
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


## An open level area of w x h cells (no terrain, ramp or building; one height), away from the
## start bases and from the other scenarios.
func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(3, g.H - h - 3):
		for x in range(3, g.W - w - 3):
			var rr := Rect2i(x, y, w, h)
			var clash := false
			for u in used:
				if (u as Rect2i).grow(2).intersects(rr):
					clash = true
					break
			if clash:
				continue
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 600.0:
					ok = false
			if ok:
				used.append(rr)
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## A mill spot (its corner) on a plateau whose front row stands right on the plateau's cliff
## edge, with level open ground two cells round it on the other three sides, clear of the
## buildings and well away from the enemy; (-1, -1) if the map has none.
func _cliff_spot() -> Vector2i:
	for y in range(4, g.H - 6):
		for x in range(4, g.W - 6):
			var c := Vector2i(x, y)
			var h0: int = g.height[g.idx(c)]
			var ok := true
			for yy in range(-2, 3):
				for xx in range(-2, 5):
					var cc := c + Vector2i(xx, yy)
					if not g.in_map(cc) or g.solid[g.idx(cc)] != 0 or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			for xx in range(0, 3):
				if g.cliff[g.idx(c + Vector2i(xx, 3))] != 1:
					ok = false
			if not ok:
				continue
			var rr := Rect2i(x - 3, y - 5, 9, 9)
			for u in used:
				if (u as Rect2i).grow(2).intersects(rr):
					ok = false
			var p: Vector2 = g.cell_center(c + Vector2i(1, 1))
			for b in g.buildings:
				if p.distance_to(b.center()) < (900.0 if b.team != 0 else 220.0):
					ok = false
			if ok:
				used.append(rr)
				return c
	return Vector2i(-1, -1)


func _crew_at(m: Building, spawn: Vector2i) -> Array:
	var us: Array = []
	for i in 6:
		var c: Vector2i = spawn + Vector2i(i % 3, i / 3)
		if not g.is_free(c):
			c = g.nearest_free(c, 6)
		var u: Unit = g._add_unit("labourer", 0, g.cell_center(c) + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
		us.append(u)
	return us


func _run() -> void:
	seed(7)
	g.reveal = true
	g.explored.fill(1)
	g.players[0]["gold"] = 50000
	var hall: Building = g.nearest_hall(Vector2.ZERO, 0)
	var sc: Array = []     # [name, mill, crew]
	# A: front and left blocked, a Barracks behind (the screenshot)
	var o := _open_area(16, 15)
	if o.x >= 0:
		var mc := o + Vector2i(6, 5)
		var m: Building = g._add_building("powder_mill", 0, mc, true)
		g._add_building("cottage", 0, mc + Vector2i(0, 3), true)
		g._add_building("cottage", 0, mc + Vector2i(2, 3), true)
		g._add_building("cottage", 0, mc + Vector2i(-2, 0), true)
		g._add_building("cottage", 0, mc + Vector2i(-2, 2), true)
		g._add_building("barracks", 0, mc + Vector2i(-1, -3), true)
		sc.append(["A front+left blocked", m, _crew_at(m, mc + Vector2i(7, 1))])
	# B: both sides and the back blocked, the front open
	o = _open_area(16, 15)
	if o.x >= 0:
		var mc := o + Vector2i(6, 5)
		var m: Building = g._add_building("powder_mill", 0, mc, true)
		g._add_building("cottage", 0, mc + Vector2i(-2, 0), true)
		g._add_building("cottage", 0, mc + Vector2i(-2, 2), true)
		g._add_building("cottage", 0, mc + Vector2i(3, 0), true)
		g._add_building("cottage", 0, mc + Vector2i(3, 2), true)
		g._add_building("barracks", 0, mc + Vector2i(-1, -3), true)
		sc.append(["B sides+back blocked", m, _crew_at(m, mc + Vector2i(0, 7))])
	# C: the front on the plateau's cliff edge (a real one if the map has it, else a row of rock)
	var cs := _cliff_spot()
	var real := cs.x >= 0
	if not real:
		o = _open_area(16, 15)
		cs = o + Vector2i(6, 5)
		for xx in range(-4, 7):
			g._mark(cs + Vector2i(xx, 3), Vector2i.ONE, 1)
	if cs.x >= 0:
		var m: Building = g._add_building("powder_mill", 0, cs, true)
		g._add_building("cottage", 0, cs + Vector2i(-2, 1), true)
		sc.append(["C cliff front (%s)" % ("real cliff" if real else "rock row"), m, _crew_at(m, cs + Vector2i(4, -3))])
	# D: shut in on the front and both sides, the back open
	o = _open_area(16, 15)
	if o.x >= 0:
		var mc := o + Vector2i(6, 7)
		var m: Building = g._add_building("powder_mill", 0, mc, true)
		g._add_building("cottage", 0, mc + Vector2i(0, 3), true)
		g._add_building("cottage", 0, mc + Vector2i(2, 3), true)
		g._add_building("cottage", 0, mc + Vector2i(-2, 0), true)
		g._add_building("cottage", 0, mc + Vector2i(-2, 2), true)
		g._add_building("cottage", 0, mc + Vector2i(3, 0), true)
		g._add_building("cottage", 0, mc + Vector2i(3, 2), true)
		sc.append(["D shut in front+sides", m, _crew_at(m, mc + Vector2i(0, -6))])
	# E: open ground
	o = _open_area(16, 15)
	if o.x >= 0:
		var mc := o + Vector2i(6, 4)
		var m: Building = g._add_building("powder_mill", 0, mc, true)
		sc.append(["E open ground", m, _crew_at(m, mc + Vector2i(0, 7))])
	check(sc.size() == 5, "five mill layouts set up (%d)" % sc.size())
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall":
			b.lode = 1.0e7          # (five mills on one hall's saltpetre: it must not run dry in the test)
	# (every unit on screen: units nobody sees don't animate, Unit._animate)
	g.camera.position = Vector2(g.W, g.H) * Defs.TILE * 0.5
	g.camera.zoom = Vector2(0.02, 0.02)
	await physics_frame
	for s in sc:
		for u in s[2]:
			u.auto_work = false
			u.cmd_gather(s[1])
	# per worker: [prev pos, prev frame key, still s, max still, frozen s, work ticks, ticks, bad cell ticks, episodes]
	var st := {}
	for s in sc:
		for u in s[2]:
			st[u] = {"pos": u.position, "key": "", "still": 0.0, "max": 0.0, "frozen": 0.0, "work": 0, "n": 0,
				"solid": 0, "eps": [], "ep_start": -1.0, "anims": {}, "loads": 0, "tipping": false, "heaps": {},
				"anchor": u.position, "park": 0.0, "park_max": 0.0, "last_load": WALK_IN, "gap_max": 0.0}
	var t0: float = g.clock
	var dt := 1.0 / 30.0
	var stack_max := {}
	var stack_run := {}
	var stack_long := {}
	var stack_run3 := {}
	var stack_long3 := {}
	var next_print := 10.0
	while g.clock - t0 < WALK_IN + MEASURE:
		await physics_frame
		var now: float = g.clock - t0
		var measuring := now >= WALK_IN
		for s in sc:
			var m: Building = s[1]
			var r: Rect2 = m.rect()
			for u in s[2]:
				var w: Dictionary = st[u]
				var key := "%s/%s/%s/%d" % [u.anim, u.anim_dir, str(u.anim_flip), u.sprite.frame if u.sprite else -1]
				var moved: float = u.position.distance_to(w["pos"])
				if moved > 0.3 or key != w["key"]:
					if float(w["still"]) > 3.0:
						w["eps"].append([float(w["ep_start"]), float(w["still"])])
					w["still"] = 0.0
					w["ep_start"] = -1.0
				else:
					if float(w["still"]) == 0.0:
						w["ep_start"] = now
						w["ep_state"] = _state(u, m)
					w["still"] = float(w["still"]) + dt
				w["pos"] = u.position
				w["key"] = key
				if verbose:
					var hist: Array = w.get("hist", [])
					hist.append("%.1f:%s r%d" % [now, _state(u, m), u._mill_route.size()])
					if hist.size() > 120:
						hist.pop_front()
					w["hist"] = hist
				if measuring:
					w["n"] = int(w["n"]) + 1
					w["max"] = maxf(float(w["max"]), float(w["still"]))
					if float(w["still"]) > FROZEN:
						w["frozen"] = float(w["frozen"]) + dt
					if u.work == "manning" and float(w["still"]) <= FROZEN:
						w["work"] = int(w["work"]) + 1
					var c: Vector2i = g.cell_of(u.position)
					if r.has_point(u.position) and g.solid[g.idx(c)] != 5 and g.solid[g.idx(c)] != 0 and not _in_shed(u):
						w["solid"] = int(w["solid"]) + 1
					# the round: digging at a heap's spot, tipping at the hopper's
					var step: int = Unit.mill_step(u._mill_t)
					if u.work == "manning" and u.anim == "shovel" and step <= 1 and u.position.distance_to(u.mill_station(m, u._mill_k)) < 9.0:
						w["heaps"][u._mill_k] = true
					var tipping: bool = u.work == "manning" and u.anim == "shovel" and step >= 2 and u.position.distance_to(u.mill_hopper_station(m)) < 9.0
					if tipping and not bool(w["tipping"]):
						w["loads"] = int(w["loads"]) + 1
						w["gap_max"] = maxf(float(w["gap_max"]), now - float(w["last_load"]))
						w["last_load"] = now
					w["gap_max"] = maxf(float(w["gap_max"]), now - float(w["last_load"]))
					w["tipping"] = tipping
					# parked: within 4 px of one spot (the places are 5 px apart at the least)
					if u.position.distance_to(w["anchor"]) > 4.0:
						w["anchor"] = u.position
						w["park"] = 0.0
					else:
						w["park"] = float(w["park"]) + dt
						w["park_max"] = maxf(float(w["park_max"]), float(w["park"]))
						if verbose and float(w["park"]) > 3.0 and float(w["park"]) - dt <= 3.0:
							var hh: Array = w.get("hist", [])
							print("%5.1f %s: a man 3 s on one spot: %s\n    history: %s" % [now, s[0], _state(u, m), " ".join(PackedStringArray(hh))])
					var an := "%s:%s" % [u.work, u.anim]
					w["anims"][an] = int(w["anims"].get(an, 0)) + 1
			if measuring:
				# the most of the six within STACK px of one another (drawn on top of each other)
				var most := 0
				for a in s[2]:
					var k := 0
					for b in s[2]:
						if a.position.distance_to(b.position) < STACK:
							k += 1
					most = maxi(most, k)
				if verbose and most > maxi(1, int(stack_max.get(s[0], 0))):
					var line := "%5.1f %s: %d within %d px:" % [now, s[0], most, int(STACK)]
					for u in s[2]:
						line += " " + _state(u, s[1])
					print(line)
				stack_max[s[0]] = maxi(int(stack_max.get(s[0], 0)), most)
				# (two on top of each other: how long at a stretch, pair by pair; passing each other takes a moment)
				var run := 0.0
				for a in s[2]:
					for b in s[2]:
						if a.get_instance_id() < b.get_instance_id():
							var pk := "%d/%d" % [a.get_instance_id(), b.get_instance_id()]
							var pr: float = float(stack_run.get(pk, 0.0)) + dt if a.position.distance_to(b.position) < STACK else 0.0
							stack_run[pk] = pr
							run = maxf(run, pr)
				var run3: float = float(stack_run3.get(s[0], 0.0)) + dt if most >= 3 else 0.0
				stack_run3[s[0]] = run3
				stack_long3[s[0]] = maxf(float(stack_long3.get(s[0], 0.0)), run3)
				if verbose and run > 0.5 and run - dt <= 0.5:
					var line := "%5.1f %s: two on top of each other for 0.5 s:" % [now, s[0]]
					for a in s[2]:
						for b in s[2]:
							if a != b and a.get_instance_id() < b.get_instance_id() and a.position.distance_to(b.position) < STACK:
								line += " %s+%s k%d/%d j%d/%d" % [_state(a, s[1]), _state(b, s[1]), a._mill_k, b._mill_k, a._mill_j, b._mill_j]
								for v in [a, b]:
									var hh: Array = st[v].get("hist", [])
									print("    history: " + " ".join(PackedStringArray(hh.slice(maxi(0, hh.size() - 40)))))
					print(line)
				stack_long[s[0]] = maxf(float(stack_long.get(s[0], 0.0)), run)
		if verbose and now >= next_print:
			next_print += 10.0
			for s in sc:
				var line := "%5.1f %-24s crew %d/6:" % [now, s[0], (s[1] as Building).working_crew()]
				for u in s[2]:
					line += " " + _state(u, s[1])
				print(line)
	# report
	for s in sc:
		var m: Building = s[1]
		print("--- %s (mill at %s)" % [s[0], str(m.cell)])
		var i := 0
		for u in s[2]:
			var w: Dictionary = st[u]
			var share := float(w["work"]) / maxf(1.0, float(w["n"]))
			if float(w["still"]) > 3.0:
				w["eps"].append([float(w["ep_start"]), float(w["still"])])
			var eps := ""
			for e in (w["eps"] as Array).slice(0, 4):
				eps += " [%.0fs for %.1fs]" % [e[0], e[1]]
			var top := ""
			var keys: Array = (w["anims"] as Dictionary).keys()
			keys.sort_custom(func(a, b) -> bool: return int(w["anims"][a]) > int(w["anims"][b]))
			for k in keys.slice(0, 3):
				top += " %s %d%%" % [k, int(100.0 * float(w["anims"][k]) / maxf(1.0, float(w["n"])))]
			print("  worker %d: works %d%%, frozen %.1fs in all, longest still %.1fs, %d frozen spells >3s%s, %d loads (longest gap %.1fs), heaps %s, longest on one spot %.1fs |%s | now %s" % [i, int(share * 100.0),
				float(w["frozen"]), float(w["max"]), (w["eps"] as Array).size(), eps, int(w["loads"]), float(w["gap_max"]), str((w["heaps"] as Dictionary).keys()),
				float(w["park_max"]), top, _state(u, m)])
			if not (w["eps"] as Array).is_empty() and w.has("ep_state"):
				print("      (a frozen spell began as: %s)" % w["ep_state"])
			check(share >= 0.9, "%s: worker %d works at least 90%% of the time (%d%%)" % [s[0], i, int(share * 100.0)])
			check(float(w["max"]) <= 3.0, "%s: worker %d never stands frozen more than 3 s (longest %.1f s)" % [s[0], i, float(w["max"])])
			check(int(w["solid"]) == 0, "%s: worker %d never stands on a solid cell of the mill (%d ticks)" % [s[0], i, int(w["solid"])])
			check(int(w["loads"]) >= MIN_LOADS and (w["heaps"] as Dictionary).size() == 3, "%s: worker %d does the round: %d loads tipped (%d wanted), heaps %s" % [s[0], i,
				int(w["loads"]), MIN_LOADS, str((w["heaps"] as Dictionary).keys())])
			check(float(w["park_max"]) <= PARKED, "%s: worker %d never stays on one spot more than %d s (%.1f s)" % [s[0], i, int(PARKED), float(w["park_max"])])
			check(float(w["gap_max"]) <= LOAD_GAP, "%s: worker %d never goes %d s without tipping a load (%.1f s at the longest)" % [s[0], i, int(LOAD_GAP), float(w["gap_max"])])
			i += 1
		check(float(stack_long.get(s[0], 0.0)) <= 0.5 and float(stack_long3.get(s[0], 0.0)) <= 0.25, "%s: the six don't stack on one spot (within %d px of one another: two for %.2f s at the longest, three for %.2f s; at most %d at once, crossing)" % [s[0],
			int(STACK), float(stack_long.get(s[0], 0.0)), float(stack_long3.get(s[0], 0.0)), int(stack_max.get(s[0], 0))])
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


## A worker's state for the log: work, the mill phase, strip and frame, and where he stands
## (px from the footprint's front middle: x right, y down).
func _state(u: Unit, m: Building) -> String:
	var r: Rect2 = m.rect()
	return "[%s ph%d %s%s f%d (%+.0f,%+.0f)]" % [u.work, u._mill_ph, u.anim, "~" if u._mill_walking else "", u.sprite.frame if u.sprite else -1,
		u.position.x - r.get_center().x, u.position.y - r.end.y]


## Going in through the shed (the yard shut in on every side): allowed on the shed's cells.
## (read by name: the test also runs on builds from before the work yard)
func _in_shed(u: Unit) -> bool:
	var way = u.get("_mill_shed")
	return way != null and not (way as Array).is_empty()
