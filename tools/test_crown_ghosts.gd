extends SceneTree
## Crown construction ghosts (you: the Crown, against the Brood):
##   godot --headless --fixed-fps 30 --script res://tools/test_crown_ghosts.gd
## A placed Crown site no Labourer is coming to goes, all of its cost back (Game.sweep_ghosts),
## like Brood and Clockwork ones: the Labourer ordered elsewhere, killed or stopped, or
## nobody sent at all. It stays while a Labourer walks to it, while it is Shift-queued, while
## it is a piece of a wall being built (Labourers go on from piece to piece, Game.next_site),
## and once it has begun (partly built).
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "greenhold", "seed": 4243, "slots": [
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


func _gold() -> int:
	return int(g.players[0]["gold"])


func _lab(p: Vector2) -> Unit:
	return g._add_unit("labourer", 0, p)


## A straight run of `n` free cells on the main (left to right), clear of the hall.
func _row(n: int, hall: Building) -> Array:
	for dy in [8, -7, 10, -9, 12]:
		for dx in range(-14, 6):
			var c0: Vector2i = g.cell_of(hall.center()) + Vector2i(dx, dy)
			var ok := true
			for i in n:
				if g.placement_problem(0, "wall", c0 + Vector2i(i, 0)) != "":
					ok = false
					break
			if ok:
				return [c0, c0 + Vector2i(n - 1, 0)]
	return []


func _run() -> void:
	g.explored.fill(1)
	# (no income: the gold only moves with what's paid and refunded)
	for u in g.units.duplicate():
		if u.team == 0 and u.is_worker():
			g.consume_unit(u)
	await wait(1.0)
	g.players[0]["gold"] = 5000
	var hall: Building = g.halls_of(0)[0]
	var home: Vector2 = hall.center() + Vector2(0, hall.rect().size.y * 0.5 + 40.0)
	var spot: Vector2i = g.find_spot(0, "cottage", hall, 5, 10, "near")
	check(spot.x >= 0, "a spot for a Cottage")
	var cost := int(Defs.BUILDINGS["cottage"]["cost"])

	# a: the Labourer is ordered elsewhere
	var lab := _lab(home + Vector2(-200, 0))
	var g0 := _gold()
	var b: Building = g.place_building(0, "cottage", spot, [lab])
	check(b != null and b.ghost and _gold() == g0 - cost, "placed: a ghost, %d paid" % cost)
	await wait(0.6)
	lab.give({"o": "move", "p": home + Vector2(-260, 0)})
	var gone := await wait_for(func() -> bool: return b.dead, 4.0)
	check(gone and _gold() == g0 and not g.buildings.has(b), "(a) Labourer ordered elsewhere: the ghost goes, all refunded (%d / %d)" % [_gold(), g0])

	# b: the Labourer is killed on the way
	g0 = _gold()
	b = g.place_building(0, "cottage", spot, [lab])
	await wait(0.4)
	lab.take_damage(99999.0, null)
	gone = await wait_for(func() -> bool: return b.dead, 4.0)
	check(gone and _gold() == g0, "(b) Labourer killed: the ghost goes, all refunded (%d / %d)" % [_gold(), g0])

	# c: the Labourer is stopped
	lab = _lab(home + Vector2(-200, 0))
	g0 = _gold()
	b = g.place_building(0, "cottage", spot, [lab])
	await wait(0.4)
	lab.cmd_stop()
	gone = await wait_for(func() -> bool: return b.dead, 4.0)
	check(gone and _gold() == g0, "(c) Labourer stopped: the ghost goes, all refunded (%d / %d)" % [_gold(), g0])

	# d: nobody sent at all
	g0 = _gold()
	b = g.place_building(0, "cottage", spot, [])
	gone = await wait_for(func() -> bool: return b.dead, 4.0)
	check(gone and _gold() == g0, "(d) placed with no Labourer: the ghost goes, refunded")

	# e: Shift-queued behind a long walk: it stays while queued
	g0 = _gold()
	lab.give({"o": "move", "p": home + Vector2(-700, 200)})
	b = g.place_building(0, "cottage", spot, [lab], true)
	await wait(3.0)
	check(b != null and not b.dead and b.ghost, "(e) Shift-queued site: the ghost stays while the Labourer has it queued")
	lab.give({"o": "move", "p": home})
	gone = await wait_for(func() -> bool: return b.dead, 4.0)
	check(gone and _gold() == g0, "(e) a plain order clears the queue: the ghost goes, refunded")

	# f: a long walk to it: it stays all the way, and he starts it
	var far := _lab(home + Vector2(-700, 150))
	g0 = _gold()
	b = g.place_building(0, "cottage", spot, [far])
	await wait(3.0)
	check(not b.dead and b.ghost, "(f) Labourer walking to it: the ghost stays")
	var began := await wait_for(func() -> bool: return not b.ghost, 40.0)
	await wait(1.5)
	check(began and not b.dead and b.progress > 0.0 and _gold() == g0 - cost, "(f) he gets there and it begins (progress %.2f)" % b.progress)

	# g: begun, then left: a partly built site stays (not refunded)
	far.give({"o": "move", "p": home + Vector2(-300, 0)})
	var left := g0 - cost
	await wait(4.0)
	check(not b.dead and not b.built and not b.ghost and b.progress > 0.0 and _gold() == left, "(g) a partly built site the Labourer left stays (progress %.2f)" % b.progress)
	g._remove_quietly(b)

	# h: a wall laid without Shift by one Labourer: the pieces wait for him, piece by piece
	g._add_building("cottage", 0, g.find_spot(0, "cottage", hall, 5, 12, "far"), true)
	var row := _row(12, hall)
	check(not row.is_empty(), "a row of 12 free cells for a palisade")
	if row.is_empty():
		_end()
		return
	var mason := _lab(g.cell_center(row[0]) + Vector2(0, 40))
	var n: int = g.place_line(0, "wall", row[0], row[1], [mason])
	var pieces: Array = g.buildings.filter(func(x: Building) -> bool: return x.kind == "wall" and x.team == 0)
	check(n == 12 and pieces.size() == 12, "(h) 12 pieces laid (%d)" % n)
	await wait(6.0)
	var alive := pieces.filter(func(x: Building) -> bool: return not x.dead).size()
	check(alive == 12, "(h) one Labourer on the wall: no piece swept while he works through it (%d / 12)" % alive)
	var done := await wait_for(func() -> bool:
		return pieces.filter(func(x: Building) -> bool: return x.built).size() >= 4, 60.0)
	alive = pieces.filter(func(x: Building) -> bool: return not x.dead).size()
	check(done and alive == 12, "(h) he goes on from piece to piece (%d built, %d standing)" % [pieces.filter(func(x: Building) -> bool: return x.built).size(), alive])

	# i: sent away from the wall: the pieces not yet begun go (refunded); begun ones stay
	g0 = _gold()
	mason.give({"o": "move", "p": home + Vector2(-400, 0)})
	await wait(4.0)
	var ghosts_gone := pieces.filter(func(x: Building) -> bool: return x.dead).size()
	var standing := pieces.filter(func(x: Building) -> bool: return not x.dead)
	var refunded := _gold() - g0
	check(ghosts_gone > 0 and standing.all(func(x: Building) -> bool: return not x.ghost) \
			and refunded == ghosts_gone * int(Defs.BUILDINGS["wall"]["cost"]),
			"(i) Labourer sent away: the %d unstarted pieces go, %d refunded; %d begun or built stay" % [ghosts_gone, refunded, standing.size()])

	# j: a wall laid with Shift behind a walk: all its pieces stay while queued
	for x in standing:
		g._remove_quietly(x)
	await wait(0.5)
	mason.give({"o": "move", "p": home + Vector2(-600, 100)})
	n = g.place_line(0, "wall", row[0], row[1], [mason], true)
	pieces = g.buildings.filter(func(x: Building) -> bool: return x.kind == "wall" and x.team == 0 and not x.dead)
	await wait(3.0)
	alive = pieces.filter(func(x: Building) -> bool: return not x.dead).size()
	check(n == 12 and alive == 12, "(j) Shift-queued wall: every piece stays while queued (%d / 12)" % alive)
	_end()


func _end() -> void:
	print("crown ghosts: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
