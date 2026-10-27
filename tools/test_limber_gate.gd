extends SceneTree
## A limbered gun (the barrel, its horse team drawn ahead of it) crosses a one-tile gate and rounds
## a wall end and a cliff block from many angles without jamming, and its horse end never stands
## on a cell it cannot legally occupy:
##   godot --headless --fixed-fps 30 --script res://tools/test_limber_gate.gd [-- --trace]
##  1. a Field Cannon through a gate in a north-south wall and round the wall's end (one horse, then
##     a team of three);
##  2. a Mortar the same (its own size and art);
##  3. a cannon past a one-tile cliff line from all round;
##  4. an east-west wall: a cannon, a mortar and a Powder Wagon cross its gate north-south;
##  5. starting in the gateway or just short of it (a gun that stopped or re-paths there): it goes
##     on through, never backs out of the gateway.
var fails := 0
var g: Game
var bad_silhouette := 0
var worst_msg := ""
var max_stuck := 0.0
var cur_run := 0
var trace := OS.get_cmdline_user_args().has("--trace")
var rng := RandomNumberGenerator.new()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _setup() -> Dictionary:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	g.explored.fill(1)
	var hall: Building = g.halls_of(0)[0]
	var hc: Vector2i = g.cell_of(hall.center())
	var best := _open_square(hc, 10, [])
	assert(best.x >= 0)
	var second := _open_square(hc, 10, [best])
	assert(second.x >= 0)
	return {"main": main, "c": best, "c2": second}


## The centre of a free (2 half + 1)-cell square of open ground round `hc` (8 to 60 cells out), away
## from the squares in `avoid`; (-1, -1) if there is none.
func _open_square(hc: Vector2i, half: int, avoid: Array) -> Vector2i:
	for r in range(8, 60):
		for k in 24:
			var c: Vector2i = hc + Vector2i((Vector2.RIGHT.rotated(k * TAU / 24.0) * r).round())
			if avoid.any(func(o: Vector2i) -> bool: return absi(o.x - c.x) <= half * 2 + 6 and absi(o.y - c.y) <= half * 2 + 6):
				continue
			var ok := true
			for y in range(-half, half + 1):
				for x in range(-half, half + 1):
					if not g.open_cell(c + Vector2i(x, y)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return c
	return Vector2i(-1, -1)


## Every point of the limbered silhouette (barrel end to the lead horse) on a legal cell.
func _silhouette_ok(u: Unit) -> bool:
	var f: Vector2 = u.facing.normalized()
	var reach: float = u.radius + 14.0 + 36.0 * float(u.team_horses.size() > 0)
	var d := 0.0
	while d <= reach:
		var p: Vector2 = u.position + f * d
		var cc: Vector2i = g.cell_of(p)
		var v: int = int(g.solid[g.idx(cc)])
		if v != 0 and v != 5 and not g._gate_lets(g.idx(cc), v, u.team):
			return false
		d += 6.0
	return true


## Orders a limbered gun from `a` to `b`; returns seconds taken, or -1. `watch`: called every tick
## with the gun (a run's own extra check).
func _go(gun: Unit, a: Vector2, b: Vector2, secs := 30.0, face := Vector2.ZERO, watch := Callable()) -> float:
	gun.position = a
	gun.facing = (b - a).normalized() if face == Vector2.ZERO else face
	gun.velocity = Vector2.ZERO
	gun.cmd_move(b)
	var t := 0.0
	var stuck := 0.0
	var last := gun.position
	while t < secs:
		await physics_frame
		t += 1.0 / 30.0
		if gun.position.distance_to(last) < 0.8:
			stuck += 1.0 / 30.0
		else:
			stuck = 0.0
		last = gun.position
		max_stuck = maxf(max_stuck, stuck)
		if trace and int(t * 30.0) % 15 == 0 and t < 16.0:
			print("   t=%.1f pos=%s f=%s v=%s i=%d %s" % [t, gun.position.round(), gun.facing.snapped(Vector2(0.01, 0.01)), gun.velocity.round(), gun.path_i, gun.path])
		# (a test start may place the team against the wall: the first moments settle that)
		if t > 0.5 and not _silhouette_ok(gun):
			bad_silhouette += 1
			if worst_msg == "":
				worst_msg = "%s pos=%s facing=%s" % [gun.kind, gun.position.round(), gun.facing]
		if watch.is_valid():
			watch.call(gun)
		if gun.position.distance_to(b) < 24.0:
			return t
	return -1.0


## A limbered gun of kind `k` with its own horse, at `p`.
func _gun(k: String, p: Vector2) -> Unit:
	var gun: Unit = g._add_unit(k, 0, p)
	gun.max_hp = 100000.0
	gun.hp = gun.max_hp
	if not gun.harnessed:
		gun.harness(g._add_unit("horse", 0, p + Vector2(-30, 0)))
	return gun


## Out of the way of the next runs, standing.
func _park(gun: Unit, p: Vector2) -> void:
	gun.cmd_stop()
	gun.position = p
	gun.velocity = Vector2.ZERO


func _team(gun: Unit, extra: int) -> void:
	gun.team_horses.clear()
	for k in extra:
		gun.team_horses.append({"coat": "dark", "hp": 1.0, "m": 0.0})


## `n` crossings of the wall through `mid` (its gate) along `axis` (the way through), from either
## side, starting and ending `lo` to `hi` tiles away along the wall (a gate batch) or past its end.
func _batch(gun: Unit, what: String, mid: Vector2, axis: Vector2, n: int, lo: float, hi: float) -> void:
	max_stuck = 0.0
	var side_v := Vector2(-axis.y, axis.x)
	var ok := 0
	var tsum := 0.0
	for i in n:
		cur_run = i
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var a: Vector2 = mid - axis * rng.randf_range(2.0, 8.0) * sgn * 32.0 + side_v * rng.randf_range(lo, hi) * 32.0
		var b: Vector2 = mid + axis * rng.randf_range(2.0, 8.0) * sgn * 32.0 + side_v * rng.randf_range(lo, hi) * 32.0
		var t: float = await _go(gun, a, b)
		if t >= 0.0:
			ok += 1
			tsum += t
		else:
			print("  stuck run %d: %s -> %s ended at %s" % [i, a.round(), b.round(), gun.position.round()])
	check(ok == n, "%s, %d team horses: %d/%d (mean %.1fs, longest standstill %.1fs)" % [what, gun.horse_count(), ok, n, tsum / maxf(ok, 1), max_stuck])


func _silhouette_check(what: String) -> void:
	check(bad_silhouette == 0, "%s: horse end never on an illegal cell (%d bad frames %s)" % [what, bad_silhouette, worst_msg])
	bad_silhouette = 0
	worst_msg = ""


func _run() -> void:
	rng.seed = 11
	var s: Dictionary = await _setup()
	var c: Vector2i = s["c"]
	# a wall with a one-tile gate in the middle (N-S), and a free-standing wall end further north
	for y in range(-8, 9):
		var cc: Vector2i = c + Vector2i(0, y)
		if y == 0:
			var gate: Building = g._add_building("gate", 0, cc, true)
			gate.set_vertical(true)
		else:
			g._add_building("wall", 0, cc, true)
	g._astar_dirty = true
	await physics_frame
	await physics_frame
	var mid: Vector2 = g.cell_center(c)
	# 1. a Field Cannon: one horse (the gun's own), then a team of three; through the gate, then past the wall's end
	var gun := _gun("cannon", g.cell_center(c + Vector2i(-6, 0)))
	var n := 4 if trace else 24
	for extra in [0, 2]:
		_team(gun, extra)
		await _batch(gun, "cannon, gate", mid, Vector2.RIGHT, n, -7.0, 7.0)
		await _batch(gun, "cannon, wall end", mid, Vector2.RIGHT, n, -10.0, -6.0)
	_silhouette_check("cannon, gate and wall end")
	_team(gun, 0)
	# 2. a Mortar (smaller, its own art)
	var mortar := _gun("mortar", g.cell_center(c + Vector2i(-6, 3)))
	_park(gun, g.cell_center(c + Vector2i(-9, 9)))
	for extra in [0, 2]:
		_team(mortar, extra)
		await _batch(mortar, "mortar, gate", mid, Vector2.RIGHT, n / 2, -7.0, 7.0)
		await _batch(mortar, "mortar, wall end", mid, Vector2.RIGHT, n / 2, -10.0, -6.0)
	_silhouette_check("mortar, gate and wall end")
	_team(mortar, 0)
	_park(mortar, g.cell_center(c + Vector2i(-9, 7)))
	# 3. a wall end and a cliff block: run alongside and across at all angles
	max_stuck = 0.0
	for y in range(-2, 3):
		g._mark(c + Vector2i(7, y), Vector2i.ONE, 1)   # a one-tile cliff line east of the wall
	g._astar_dirty = true
	for i in 4:
		await process_frame
		await physics_frame
	var base: Vector2 = g.cell_center(c + Vector2i(7, 0))
	var ok2 := 0
	var n2 := 8 if trace else 36
	for i in n2:
		var ang := i * TAU / float(n2)
		var a2: Vector2 = base + Vector2.from_angle(ang) * 110.0
		var b2: Vector2 = base - Vector2.from_angle(ang + rng.randf_range(-0.6, 0.6)) * 110.0
		if not g._clear_at(a2, 22.0, 0) or not g._clear_at(b2, 22.0, 0):
			ok2 += 1
			continue
		var t2: float = await _go(gun, a2, b2, 25.0, (a2 - base).normalized())
		if t2 >= 0.0:
			ok2 += 1
		else:
			print("  rock run %d stuck at %s" % [i, gun.position.round()])
	check(ok2 == n2, "past the rock block %d/%d (longest standstill %.1fs)" % [ok2, n2, max_stuck])
	_silhouette_check("rock")
	# 4. an east-west wall with a gate: crossed north-south
	var c2: Vector2i = s["c2"]
	for x in range(-8, 9):
		var cc: Vector2i = c2 + Vector2i(x, 0)
		if x == 0:
			var gate2: Building = g._add_building("gate", 0, cc, true)
			gate2.set_vertical(false)
		else:
			g._add_building("wall", 0, cc, true)
	g._astar_dirty = true
	await physics_frame
	await physics_frame
	var mid2: Vector2 = g.cell_center(c2)
	var wagon := _gun("powder_wagon", mid2 + Vector2(-300, 300))
	wagon.cmd_stop()
	var k := 0
	for u in [gun, mortar, wagon]:
		_team(u, 0)
		await _batch(u, "%s, east-west gate" % u.kind, mid2, Vector2.DOWN, n / 2, -7.0, 7.0)
		_team(u, 2)
		await _batch(u, "%s, east-west gate" % u.kind, mid2, Vector2.DOWN, n / 3, -7.0, 7.0)
		_team(u, 0)
		_park(u, mid2 + Vector2(-300, -300 + 50 * k))
		k += 1
	_silhouette_check("east-west gate")
	# 5. starting in the gateway or just short of it, lined up or a little off: straight on through,
	# never backing out of the gateway (a gun stopped there, or re-pathing there, must not reverse)
	var ok5 := 0
	var n5 := 0
	var backed := 0
	for u in [gun, mortar]:
		for extra in [0, 2]:
			_team(u, extra)
			for along in [-40.0, -22.0, -8.0, 6.0]:
				for lat in [-5.0, 0.0, 5.0]:
					var sgn := 1.0 if n5 % 2 == 0 else -1.0
					var axis := Vector2.DOWN * sgn
					var start: Vector2 = mid2 + axis * along + Vector2(lat, 0)
					var goal: Vector2 = mid2 + axis * 200.0 + Vector2(rng.randf_range(-120.0, 120.0), 0)
					var low := [along]
					var watch := func(q: Unit) -> void: low[0] = minf(low[0], (q.position - mid2).dot(axis))
					n5 += 1
					var t5: float = await _go(u, start, goal, 25.0, axis.rotated(deg_to_rad(rng.randf_range(-8.0, 8.0))), watch)
					if t5 >= 0.0:
						ok5 += 1
					else:
						print("  gateway run %s %d along=%d lat=%d stuck at %s" % [u.kind, extra, along, lat, u.position.round()])
					if float(low[0]) < along - 24.0:
						backed += 1
						print("  gateway run %s %d along=%d lat=%d backed out to %.0f" % [u.kind, extra, along, lat, float(low[0])])
			_team(u, 0)
		_park(u, mid2 + Vector2(-300, -300))
	check(ok5 == n5, "from the gateway: on through %d/%d" % [ok5, n5])
	check(backed == 0, "from the gateway: never backs out of it (%d did)" % backed)
	_silhouette_check("from the gateway")
	print("limber gate: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
