extends SceneTree
## A limbered gun (cannon + horse art ahead of it) crosses a one-tile gate and rounds a wall end
## and a cliff block from many angles without jamming, and its horse end never stands on a cell
## it cannot legally occupy.
##   godot --headless --fixed-fps 30 --script res://tools/test_limber_gate.gd
var fails := 0
var g: Game
var bad_silhouette := 0
var worst_msg := ""
var max_stuck := 0.0
var cur_run := 0
var trace := OS.get_cmdline_user_args().has("--trace")


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
	var best := Vector2i(-1, -1)
	var hc: Vector2i = g.cell_of(hall.center())
	for r in range(8, 60):
		for k in 24:
			var c: Vector2i = hc + Vector2i((Vector2.RIGHT.rotated(k * TAU / 24.0) * r).round())
			var ok := true
			for y in range(-10, 11):
				for x in range(-10, 11):
					if not g.open_cell(c + Vector2i(x, y)):
						ok = false
						break
				if not ok:
					break
			if ok:
				best = c
				break
		if best.x >= 0:
			break
	assert(best.x >= 0)
	return {"main": main, "c": best}


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


## Orders a limbered cannon from `a` to `b`; returns seconds taken, or -1.
func _go(gun: Unit, a: Vector2, b: Vector2, secs := 30.0, face := Vector2.ZERO) -> float:
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
		if trace and cur_run == 99 and t > 7.0 and t < 7.1:
			var q: Vector2 = gun.position
			var w1: Vector2 = q + Vector2(-1, 0)
			print("   DBG pts body=%s horse=%s at %s r=%s" % [g._clear_at(w1, gun._tow_body(), 0), g._clear_at(w1 + gun.facing * (gun.radius + 22.0), 13.0, 0), w1 + gun.facing * (gun.radius + 22.0), gun.radius])
			print("   DBG west1=%s turnW=%s phase=%s tmode=%s ord=%s" % [gun._tow_clear(q + Vector2(-1, 0), gun.facing), gun._tow_clear(q, Vector2(-1, 0)), gun.phase, gun.tesla_mode, gun.order])
			print("   DBG clear_now=%s turn_south=%s down1=%s body=%s pts=%s" % [gun._tow_clear(q, gun.facing), gun._tow_clear(q, Vector2(0, 1)), gun._tow_clear(q + Vector2(0, 1), gun.facing), g._clear_at(q + Vector2(0, 1), 15.0, 0), [g._clear_at(q + gun.facing * 44.0, 13.0, 0), g._clear_at(q + Vector2(0,1) + gun.facing * 44.0, 13.0, 0)]])
		if trace and cur_run == 99 and int(t * 30.0) % 15 == 0 and t < 16.0:
			print("   t=%.1f pos=%s f=%s v=%s i=%d %s" % [t, gun.position.round(), gun.facing.snapped(Vector2(0.01,0.01)), gun.velocity.round(), gun.path_i, gun.path])
		# (a test start may place the team against the wall: the first moments settle that)
		if t > 0.5 and not _silhouette_ok(gun):
			bad_silhouette += 1
			if worst_msg == "":
				worst_msg = "pos=%s facing=%s" % [gun.position.round(), gun.facing]
		if gun.position.distance_to(b) < 24.0:
			return t
	return -1.0


func _run() -> void:
	var s: Dictionary = await _setup()
	var c: Vector2i = s["c"]
	# a wall with a one-tile gate in the middle (N-S), and a free-standing wall end further east
	for y in range(-8, 9):
		var cc: Vector2i = c + Vector2i(0, y)
		if y == 0:
			var gate: Building = g._add_building("gate", 0, cc, true)
			gate.set_vertical(false)
		else:
			g._add_building("wall", 0, cc, true)
	g._astar_dirty = true
	await physics_frame
	await physics_frame
	if trace:
		print("   c=%s center=%s solid col: %s" % [c, g.cell_center(c), str([g.solid[g.idx(c)], g.solid[g.idx(c + Vector2i(0, 1))], g.solid[g.idx(c + Vector2i(1, 0))], g.solid[g.idx(c + Vector2i(-1, 0))]])])
	var gun: Unit = g._add_unit("cannon", 0, g.cell_center(c + Vector2i(-6, 0)))
	var horse: Unit = g._add_unit("horse", 0, g.cell_center(c + Vector2i(-7, 0)))
	gun.harness(horse)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# one horse (the gun's own), then a team of three; crossings through the gate, then past the wall's end
	for team_extra in [0, 2]:
		gun.team_horses.clear()
		for k in team_extra:
			gun.team_horses.append({"coat": "dark", "hp": 1.0, "m": 0.0})
		for batch in ["gate", "wall end"]:
			max_stuck = 0.0
			var n := 4 if trace else 24
			var ok := 0
			var tsum := 0.0
			for i in n:
				cur_run = i
				var side := 1.0 if i % 2 == 0 else -1.0
				var ylo := -7.0 if batch == "gate" else -10.0
				var yhi := 7.0 if batch == "gate" else -6.0
				var a: Vector2 = g.cell_center(c) + Vector2(-rng.randf_range(2.0, 8.0) * side, rng.randf_range(ylo, yhi)) * 32.0
				var b: Vector2 = g.cell_center(c) + Vector2(rng.randf_range(2.0, 8.0) * side, rng.randf_range(ylo, yhi)) * 32.0
				var t: float = await _go(gun, a, b)
				if t >= 0.0:
					ok += 1
					tsum += t
				else:
					print("  stuck run %d: %s -> %s ended at %s" % [i, a.round(), b.round(), gun.position.round()])
			check(ok == n, "%s, %d team horses: %d/%d (mean %.1fs, longest standstill %.1fs)" % [batch, team_extra + 1, ok, n, tsum / maxf(ok, 1), max_stuck])
	check(bad_silhouette == 0, "gate and wall end: horse end never on an illegal cell (%d bad frames %s)" % [bad_silhouette, worst_msg])
	gun.team_horses.clear()
	# a wall end and a cliff block: run alongside and across at all angles
	bad_silhouette = 0
	worst_msg = ""
	max_stuck = 0.0
	for y in range(-2, 3):
		for x in range(7, 8):
			g._mark(c + Vector2i(x, y), Vector2i.ONE, 1)   # a one-tile cliff line east of the wall
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
	check(bad_silhouette == 0, "rock: horse end never on an illegal cell (%d bad frames %s)" % [bad_silhouette, worst_msg])
	print("limber gate: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
