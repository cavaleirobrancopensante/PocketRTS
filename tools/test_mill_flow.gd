extends SceneTree
## The Powder Mill workflow: six Crown labourers dig at the three heaps, carry the loaded shovel
## to the hopper, tip it in and walk back:
##   godot --headless --fixed-fps 30 --script res://tools/test_mill_flow.gd
##  every worker visits all three heaps, digs there, carries (walk_shovel) then tips at the
##  hopper's spot, nobody stands still for long or ends up on the shed's solid cells (the work
##  yard, the footprint's front row, is walkable: Building.MILL_YARD), the six do not stack on
##  one spot (two within 3 px for 0.5 s at a stretch at the most, three 0.25 s: crossing), and the
##  powder income is exactly what the working crew earns (Defs.MILL_RATE per worker at work: the
##  workflow is visuals only), with all six at work throughout.
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
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


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
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
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _has_colour(im: Image, x0: int, near: Color, tol: float) -> bool:
	for y in 35:
		for x in 42:
			var c := im.get_pixel(x0 + x, y)
			if c.a > 0.0 and absf(c.r - near.r) + absf(c.g - near.g) + absf(c.b - near.b) < tol:
				return true
	return false


func _run() -> void:
	origin = _open_area(20, 14)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	g.explored.fill(1)
	g.players[0]["gold"] = 20000
	g._add_building("town_hall", 0, origin + Vector2i(1, 1), true)
	var m: Building = g._add_building("powder_mill", 0, origin + Vector2i(8, 4), true)
	var us: Array = []
	for i in 6:
		var u: Unit = g._add_unit("labourer", 0, m.center() + Vector2(-70 + 28 * i, m.rect().size.y * 0.5 + 30))
		us.append(u)
	await physics_frame
	for u in us:
		u.auto_work = false
		u.cmd_gather(m)
	g.camera.position = m.center()
	var r := m.rect()
	var heaps := []
	var tipped := []
	var carried := []
	var dug := []
	var moved := []
	var last := []
	var inside := 0
	var pair_run := {}        # (two on top of each other: how long at a stretch, pair by pair)
	var pair_long := 0.0
	var three_run := 0.0
	var three_long := 0.0
	for i in 6:
		heaps.append({})
		tipped.append(0)
		carried.append(0)
		dug.append({})
		moved.append(0.0)
		last.append(us[i].position)
	var res0: float = g.players[0]["res2"]
	var expect := 0.0
	var all_work := 0
	var samples := 0
	var tip_prev := [false, false, false, false, false, false]
	var t0: float = g.clock
	var loads_seen := {}
	var end: float = g.clock + 75.0
	var dbg := 0
	while g.clock < end:
		await physics_frame
		var dt := 1.0 / 30.0
		dbg += 1
		if dbg % 60 == 0 and OS.get_environment("MILLDBG") != "":
			var line := "%4.1f " % (g.clock - t0)
			for u in us:
				line += " [%d k%d %s %.0f,%.0f]" % [u._mill_ph, u._mill_k, u.anim, u.position.x - r.get_center().x, u.position.y - r.end.y]
			print(line)
		var n: int = m.working_crew()
		expect += Defs.MILL_RATE * float(n) * dt
		if g.clock - t0 > 15.0:
			samples += 1
			if n == 6:
				all_work += 1
		for i in 6:
			var u: Unit = us[i]
			moved[i] += u.position.distance_to(last[i])
			last[i] = u.position
			if u.work != "manning":
				continue
			var cv: int = g.solid[g.idx(g.cell_of(u.position))]
			if g.clock - t0 > 15.0 and r.grow(-2.0).has_point(u.position) and cv != 5 and cv != 0:
				inside += 1        # (on the shed's solid cells; the yard, the front row, is walkable)
			if u.anim == "walk_shovel":
				carried[i] += 1
				loads_seen[u._mill_k] = true
				if u.sprite.frame < u._mill_k * 6 or u.sprite.frame >= u._mill_k * 6 + 6:
					fails += 1
					print("FAIL  walk_shovel frame %d outside load %d" % [u.sprite.frame, u._mill_k])
			if u.anim == "shovel":
				var st: int = Unit.mill_step(u._mill_t)
				if u.position.distance_to(u.mill_station(m, u._mill_k)) < 9.0 and st <= 1:
					heaps[i][u._mill_k] = true
					dug[i][u._mill_k] = true
				var tipping := u.position.distance_to(u.mill_hopper_station(m)) < 9.0 and st >= 2
				if tipping and not tip_prev[i]:
					tipped[i] += 1
				tip_prev[i] = tipping
		if g.clock - t0 > 15.0:
			var most := 0
			for i in 6:
				var c := 0
				for j in 6:
					if us[i].position.distance_to(us[j].position) < 3.0:
						c += 1
					if j > i:
						var pr: float = float(pair_run.get(i * 6 + j, 0.0)) + dt if us[i].position.distance_to(us[j].position) < 3.0 else 0.0
						pair_run[i * 6 + j] = pr
						pair_long = maxf(pair_long, pr)
				most = maxi(most, c)
			three_run = three_run + dt if most >= 3 else 0.0
			three_long = maxf(three_long, three_run)
	var gain: float = g.players[0]["res2"] - res0
	for i in 6:
		check(heaps[i].size() == 3, "worker %d digs at all three heaps (%s)" % [i, str(heaps[i].keys())])
		check(carried[i] > 60, "worker %d walks carrying the loaded shovel (%d ticks)" % [i, carried[i]])
		check(tipped[i] >= 3, "worker %d tips into the hopper (%d times in 75 s)" % [i, tipped[i]])
		check(moved[i] > 400.0, "worker %d is never stuck (%d px walked)" % [i, int(moved[i])])
	check(loads_seen.size() == 3, "all three loads are carried (%s)" % str(loads_seen.keys()))
	check(inside == 0, "nobody walks through the shed (its solid cells: %d samples)" % inside)
	check(pair_long <= 0.5 and three_long <= 0.25, "the six do not stack on one spot (within 3 px: two for %.2f s at the longest, three for %.2f s)" % [pair_long, three_long])
	check(all_work >= samples - 2, "all six are at work throughout (%d of %d ticks)" % [all_work, samples])
	check(expect > 0.0 and absf(gain - expect) < 0.02 * expect + 0.01, "powder income is the crew's rate: %.2f gained, %.2f expected" % [gain, expect])
	print("income %.3f over 75 s" % gain)
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
