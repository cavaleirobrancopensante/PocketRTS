extends SceneTree
## The Horseman and the Cuirassier fight on the move (scripts/ride_by.gd, Defs.RIDE_BY, docs/ride_by.md):
##   godot --headless --fixed-fps 30 --script res://tools/test_ride_by.gd
##  1. a plain move past enemies: he strikes those in reach without slowing, and gets where he was told
##  2. an attack order makes passes: he rides at the target, strikes, rides on past and swings round it (his bearing
##     from it goes right round), never standing beside it (an Armoured Cuirassier too)
##  3. a fleeing man is ridden down: struck again and again on the run
##  4. a building: passes along its side
##  5. the pistol is fired on the move (at a gallop)
##  6. the Cavalry Charge doubles only the first blow after a run, not every pass
##  7. HOLD POSITION, and stopped on guard: he stands and fights (no loops)
##  8. the Dragoon is unchanged (dismounts to fire)
##  9. deterministic: the same fight twice, the same ride to the frame
## 10. a save and load in the middle of a fight keeps the ride's state (its side, heading, the charge clock)
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


func at(dx: float, dy: float) -> Vector2:
	return Vector2(origin) * Defs.TILE + Vector2(dx, dy)


func unit(k: String, p: Vector2, team := 0) -> Unit:
	return g._add_unit(k, team, p)


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


func _clear_units() -> void:
	for u in g.units.duplicate():
		if u.position.distance_to(at(400, 300)) < 1200.0:
			g.consume_unit(u)
	for b in g.buildings.duplicate():
		if b.team >= 0 and b.center().distance_to(at(400, 300)) < 900.0 and not b.dead:
			b.die()
	await physics_frame
	await physics_frame


## A tough enemy that stands still and can't strike back (a dry Musketeer of the other side).
func dummy(p: Vector2) -> Unit:
	var e := unit("musketeer", p, 1)
	e.max_hp = 50000.0
	e.hp = 50000.0
	e.powder = 0.0
	e._pmax = 0.0
	e.cmd_hold()
	e.stun_t = 99999.0
	return e


func rider(p: Vector2, armoured := false, loaded := false) -> Unit:
	var c := unit("cuirassier", p)
	if armoured:
		c.put_on_armour()
	c.pistol = loaded
	c.facing = Vector2.RIGHT
	return c


func _run() -> void:
	origin = _open_area(22, 16)        # (was 30 x 22: no such flat open ground on hollowfen any more)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	seed(7)
	g.players[0]["gold"] = 20000
	g.players[0]["cap"] = 200
	g.players[0]["tech"] = {}
	await _clear_units()
	if OS.get_cmdline_user_args().has("trace"):
		await _trace_only()
		return
	await _move_past()
	await _passes(false)
	await _passes(true)
	await _fleeing()
	await _building()
	await _pistol()
	await _charge()
	await _hold()
	await _dragoon()
	await _save_load()
	await _determinism()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 1

func _move_past() -> void:
	await _clear_units()
	var c := rider(at(80, 300))
	# three men stand by his road, 26 px off its line (well within his reach), 120 px apart
	var men: Array = []
	for i in 3:
		men.append(dummy(at(300 + 120 * i, 300 + (26 if i % 2 == 0 else -26))))
	var hp0: Array = men.map(func(m: Unit) -> float: return m.hp)
	var goal := at(760, 300)
	c.cmd_move(goal)
	var t0: float = g.clock
	var slow := 0
	var frames := 0
	while g.clock - t0 < 12.0 and c.order != "idle":
		await physics_frame
		if g.clock - t0 > 0.6 and c.position.x > at(250, 0).x and c.position.x < at(560, 0).x:
			frames += 1
			if c.velocity.length() < c.speed * 0.8:
				slow += 1
	var arrived: bool = c.order == "idle"
	var took: float = g.clock - t0
	var struck := 0
	for i in men.size():
		if (men[i] as Unit).hp < float(hp0[i]) - 1.0:
			struck += 1
	var ideal: float = at(80, 300).distance_to(goal) / c.speed
	check(struck >= 2, "a move past three men in reach: he struck %d of them on the way" % struck)
	check(slow == 0 and frames > 20, "  without slowing down (%d of %d frames under 80%% of his speed)" % [slow, frames])
	check(arrived and c.position.distance_to(goal) < 40.0 and took < ideal + 1.5,
		"  and he got where he was told (%.1f s; %.1f s at full gallop)" % [took, ideal])
	check(c.ride_n >= 2 and c.phase == "", "  blows struck in passing: %d (no standing attack phase)" % c.ride_n)


# ---------------------------------------------------------------- 2

func _passes(armoured: bool) -> void:
	await _clear_units()
	var e := dummy(at(400, 300))
	var c := rider(at(120, 300), armoured)
	c.cmd_attack(e)
	var hp0 := e.hp
	var standing := 0
	var frames := 0
	var far := 0.0
	var sides := {}
	var states := {}
	var t0: float = g.clock
	while g.clock - t0 < 14.0:
		await physics_frame
		if g.clock - t0 > 3.0:
			frames += 1
			if c.velocity.length() < c.speed * 0.5:
				standing += 1
			far = maxf(far, c.position.distance_to(e.position))
			# where he is round it (eight sectors of the compass)
			sides[posmod(int(floor((c.position - e.position).angle() / (PI / 4.0))), 8)] = true
		states[c.rb_state] = true
	var who := "a Cuirassier" if armoured else "a Horseman"
	var blows := c.ride_n
	check(blows >= 4, "%s told to attack: %d blows in 14 s, struck in passing (%.0f damage)" % [who, blows, hp0 - e.hp])
	check(frames > 0 and float(standing) / frames < 0.08, "  never standing beside it (%.0f%% of the time under half speed)" % (100.0 * standing / maxf(frames, 1)))
	check(far > 60.0 and far < 220.0 and states.has("out"), "  he rides on past it and swings round (up to %.0f px away)" % far)
	check(sides.size() == 8, "  he rides right round it (in %d of the 8 directions from it)" % sides.size())
	check(c.order == "attack" and c.order_target == e, "  the order stands")


# ---------------------------------------------------------------- 3

func _fleeing() -> void:
	await _clear_units()
	var w := unit("labourer", at(260, 300), 1)
	w.max_hp = 5000.0
	w.hp = 5000.0
	w.auto_work = false
	w.cmd_move(at(900, 300))
	var c := rider(at(80, 300))
	await wait(0.5)
	c.cmd_attack(w)
	var hp0 := w.hp
	var first := -1.0
	var t0: float = g.clock
	while g.clock - t0 < 8.0:
		await physics_frame
		if first < 0.0 and w.hp < hp0 - 1.0:
			first = g.clock - t0
	check(first > 0.0 and first < 5.0, "a man on the run is caught (first blow after %.1f s)" % first)
	check(c.ride_n >= 2 and w.hp < hp0 - 20.0, "  and struck again and again as he rides him down (%d blows, %.0f damage)" % [c.ride_n, hp0 - w.hp])


# ---------------------------------------------------------------- 4

func _building() -> void:
	await _clear_units()
	var b: Building = g._add_building("cottage", 1, origin + Vector2i(12, 8), true)
	b.max_hp = 50000.0
	b.hp = 50000.0
	var c := rider(at(120, 330))
	c.cmd_attack(b)
	var hp0 := b.hp
	var standing := 0
	var frames := 0
	var t0: float = g.clock
	while g.clock - t0 < 14.0:
		await physics_frame
		if g.clock - t0 > 3.0:
			frames += 1
			if c.velocity.length() < c.speed * 0.5:
				standing += 1
	check(c.ride_n >= 3 and b.hp < hp0, "a building (%s): %d blows in passing (%.0f damage)" % [b.kind, c.ride_n, hp0 - b.hp])
	check(frames > 0 and float(standing) / frames < 0.1, "  riding along its side, not standing (%.0f%% under half speed)" % (100.0 * standing / maxf(frames, 1)))
	b.die()
	await physics_frame


# ---------------------------------------------------------------- 5

func _pistol() -> void:
	await _clear_units()
	var e := dummy(at(520, 300))
	var c := rider(at(80, 300), false, true)
	c.cmd_attack(e)
	var spd_at := -1.0
	var dist_at := -1.0
	var t0: float = g.clock
	while g.clock - t0 < 10.0 and c.pistol:
		await physics_frame
		if not c.pistol:
			spd_at = c.velocity.length()
			dist_at = e.edge_distance(c.position) - c.radius
	check(not c.pistol and spd_at > c.speed * 0.8, "the pistol is fired on the move (at %.0f px/s of his %.0f)" % [spd_at, c.speed])
	check(dist_at > 30.0 and dist_at <= float(Defs.PISTOL["range"]) + 4.0, "  from %.0f px (the pistol reaches %d)" % [dist_at, int(Defs.PISTOL["range"])])


# ---------------------------------------------------------------- 6

func _charge() -> void:
	await _clear_units()
	g.players[0]["tech"] = {"charge": true}
	var e := dummy(at(520, 300))
	e.stun_t = 99999.0
	var c := rider(at(80, 300))
	c.cmd_attack(e)
	var blows: Array = []
	var last := e.hp
	var t0: float = g.clock
	while g.clock - t0 < 16.0:
		await physics_frame
		e.stun_t = 99999.0
		e.knock = Vector2.ZERO
		if e.hp < last - 0.5:
			blows.append(snappedf(last - e.hp, 0.1))
			last = e.hp
	var ok := blows.size() >= 3
	var first: float = blows[0] if ok else 0.0
	var rest: Array = blows.slice(1) if ok else []
	var most := 0.0
	for b in rest:
		most = maxf(most, float(b))
	check(ok and first > most * 1.6, "Cavalry Charge: the first blow after the run hits double (%s)" % [blows])
	check(ok and most > 0.0 and rest.all(func(b) -> bool: return float(b) < first * 0.7), "  the passes after it are plain blows (not a charge every pass)")
	# a fresh run after a lull: the charge again
	c.cmd_move(at(80, 300))
	await wait_for(func() -> bool: return c.order == "idle", 8.0)
	await wait(float(Defs.RIDE_BY["calm"]))
	c.cmd_attack(e)
	last = e.hp
	var again := 0.0
	t0 = g.clock
	while g.clock - t0 < 10.0 and again <= 0.0:
		await physics_frame
		if e.hp < last - 0.5:
			again = last - e.hp
	check(again > most * 1.6, "  after a lull and a new run, the next first blow charges again (%.0f)" % again)
	g.players[0]["tech"] = {}


# ---------------------------------------------------------------- 7

func _hold() -> void:
	await _clear_units()
	var e := dummy(at(400, 300))
	var c := rider(at(400 - e.radius - 15.0 - 16.0, 300))
	c.cmd_hold()
	var p0 := c.position
	var hp0 := e.hp
	var moved := 0.0
	var t0: float = g.clock
	while g.clock - t0 < 6.0:
		await physics_frame
		moved = maxf(moved, c.position.distance_to(p0))
	check(moved < 12.0 and e.hp < hp0 - 20.0 and c.ride_n == 0,
		"HOLD POSITION: he stands and fights as before (moved %.0f px, %.0f damage, %d passing blows)" % [moved, hp0 - e.hp, c.ride_n])
	# stopped (idle, on guard) with an enemy by him: he stands and fights too
	c.cmd_stop()
	p0 = c.position
	hp0 = e.hp
	moved = 0.0
	t0 = g.clock
	while g.clock - t0 < 6.0:
		await physics_frame
		moved = maxf(moved, c.position.distance_to(p0))
	check(c.order == "idle" and moved < 24.0 and e.hp < hp0 - 20.0 and c.ride_n == 0,
		"stopped, on guard: he stands and fights as before (moved %.0f px, %.0f damage)" % [moved, hp0 - e.hp])


# ---------------------------------------------------------------- 8

func _dragoon() -> void:
	await _clear_units()
	var e := dummy(at(500, 300))
	var d := unit("dragoon", at(150, 300))
	d.cmd_attack(e)
	var hp0 := e.hp
	var on_foot := await wait_for(func() -> bool: return d.kind == "musketeer", 10.0)
	await wait(4.0)
	check(on_foot and e.hp < hp0 and d.ride_n == 0 and d.rb_state == "", "the Dragoon is unchanged: he rides up, dismounts and fires (%.0f damage)" % (hp0 - e.hp))


# ---------------------------------------------------------------- 9

func _trace() -> String:
	await _clear_units()
	var e := dummy(at(400, 300))
	var w := unit("labourer", at(430, 380), 1)
	w.auto_work = false
	g.players[0]["tech"] = {"charge": true}
	var c := rider(at(170, 300), false, true)
	var c2 := rider(at(120, 360), true)
	await physics_frame
	c.cmd_attack(e)
	c2.cmd_move(at(700, 380), true)
	var s := PackedStringArray()
	for i in 450:
		await physics_frame
		s.append("%.2f,%.2f,%.2f,%.2f,%d,%d,%.1f,%.1f" % [c.position.x - at(0, 0).x, c.position.y - at(0, 0).y,
			c2.position.x - at(0, 0).x, c2.position.y - at(0, 0).y, c.ride_n, c2.ride_n, e.hp, w.hp])
	return "\n".join(s)


# ---------------------------------------------------------------- 10

func _save_load() -> void:
	await _clear_units()
	var e := dummy(at(400, 300))
	var c := rider(at(160, 300))
	c.cmd_attack(e)
	await wait(4.0)
	# (a save keeps no attack order: he loads standing, idle; what carries over is his side, heading and charge clock)
	var was := [c.rb_side, snappedf(c.rb_last, 0.01), snappedf(c.run_t, 0.01), c.rb_head.snapped(Vector2(0.001, 0.001))]
	SaveGame.save(g, {"map": "random", "seed": 4242})
	SaveGame.restore(g, SaveGame.peek())
	await physics_frame
	var cs: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cuirassier" and not u.dead)
	var ok := cs.size() == 1
	var now := []
	if ok:
		var d: Unit = cs[0]
		now = [d.rb_side, snappedf(d.rb_last, 0.01), snappedf(d.run_t, 0.01), d.rb_head.snapped(Vector2(0.001, 0.001))]
	check(ok and str(now) == str(was), "save and load in a fight keep the ride (%s / %s; order %s)" % [was, now, cs[0].order if ok else "-"])
	SaveGame.clear()
	await _clear_units()


## Two separate runs of the game (fresh processes, as test_determinism does) ride the same fight: the same trace.
func _determinism() -> void:
	var hashes: Array = []
	for i in 2:
		var out: Array = []
		OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", "30", "--script", "res://tools/test_ride_by.gd", "--", "trace"], out, true)
		var h := ""
		for line in String("".join(out)).split("\n"):
			if line.begins_with("RIDEHASH "):
				h = line.substr(9)
		hashes.append(h)
	check(hashes[0] != "" and hashes[0] == hashes[1], "deterministic: two separate runs ride the same fight to the frame (%s / %s)" % hashes)


func _trace_only() -> void:
	var tr := await _trace()
	print("RIDEHASH %d frames %s" % [tr.split("\n").size(), tr.md5_text()])
	quit(0)
