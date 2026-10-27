extends SceneTree
## A Gate laid over part of a planned palisade replaces only the pieces it covers (playtest 0.14.82: "if I set the
## ghost all and then set a gate on that ghost, the entire ghost wall is destroyed"). The same over a wall going up
## and a built wall: the gate takes that one piece; the rest of the wall and its builders' work stay.
##   godot --headless --fixed-fps 30 --script res://tools/test_gate_on_wall_plan.gd
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
		main.start({"map": "greenhold", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "clockwork", "colour": 1, "side": 1}]})
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


func _wait(secs: float) -> void:
	var end: float = g.clock + secs
	while g.clock < end:
		await physics_frame


func _pieces(cells: Array, kind := "wall") -> Array:
	var out: Array = []
	for b in g.buildings:
		if b.team == 0 and not b.dead and b.kind == kind and cells.has(b.cell):
			out.append(b)
	return out


## A straight run of `n` free cells near the hall (E-W), or [] if none.
func _run_cells(hall: Building, n: int) -> Array:
	for dy in [6, -6, 8, -8, 10, -10, 12, -12]:
		for dx in range(-14, 6):
			var a: Vector2i = hall.cell + Vector2i(dx, dy)
			var ok := true
			var cells: Array = []
			for i in n:
				var c := a + Vector2i(i, 0)
				if g.placement_problem(0, "wall", c) != "" or g.placement_problem(0, "gate", c) != "":
					ok = false
					break
				cells.append(c)
			if ok:
				return cells
	return []


func _labourers(n: int) -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "labourer" and not u.dead).slice(0, n)


func _run() -> void:
	g.explored.fill(1)
	g.players[0]["gold"] = 9000
	var hall: Building = g.halls_of(0)[0]
	var cs: Vector2i = g.find_spot(0, "cottage", hall, 4, 12, "far_safe")
	g._add_building("cottage", 0, cs, true)      # (palisades need a Cottage)
	await physics_frame
	var labs := _labourers(3)
	check(labs.size() == 3, "three Labourers")

	# ---- 1. a planned (ghost) wall: a gate on its middle
	var cells := _run_cells(hall, 12)
	check(cells.size() == 12, "a free run of 12 cells by the hall")
	var n: int = g.place_line(0, "wall", cells[0], cells[11], [labs[0]])     # (one Labourer on it)
	check(n == 12, "12 palisade pieces planned (%d)" % n)
	await _wait(0.5)
	# the owner's case: the gate goes on the very piece the Labourers are walking to, laid while no Labourer is
	# selected (the gate has no builder of its own)
	var aim: Building = labs[0].order_target
	check(aim != null and aim.kind == "wall" and aim.ghost and cells.has(aim.cell), "a Labourer is on his way to a planned piece")
	var gold0: int = g.players[0]["gold"]
	var ng: int = g.place_line(0, "gate", aim.cell, aim.cell, [])
	check(ng == 1, "a gate laid on that piece (no builder of its own)")
	var refund: int = g.players[0]["gold"] - (gold0 - int(Defs.BUILDINGS["gate"]["cost"]))
	check(refund == int(Defs.BUILDINGS["wall"]["cost"]), "the replaced planned piece is paid back, nothing else (%d back)" % refund)
	var gate_cell: Vector2i = aim.cell
	# a ghost sweep before the Labourer's next step (Game sweeps every 0.2 s from _process, units move in physics
	# frames: in a real match it often falls between the two)
	g.sweep_ghosts(true)
	await _wait(3.5)            # (several ghost sweeps)
	var walls := _pieces(cells)
	check(walls.size() == 11, "the rest of the planned wall stays (%d of 11 pieces)" % walls.size())
	check(_pieces([gate_cell], "gate").size() == 1, "the gate stays planned where the wall piece was")
	check(not walls.any(func(b: Building) -> bool: return b.cell == gate_cell), "only that one piece was replaced")
	# a second gate, laid with the Labourers selected (non-queued): they build it, then go on with the wall
	var mid: Vector2i = cells[9] if cells[9] != gate_cell else cells[10]
	ng = g.place_line(0, "gate", mid, mid, labs)
	check(ng == 1, "a second gate laid with the Labourers selected")
	await _wait(3.5)
	check(_pieces(cells).size() == 10 and _pieces(cells, "gate").size() == 2, "10 walls and 2 gates planned (%d, %d)" % [_pieces(cells).size(), _pieces(cells, "gate").size()])
	var busy := labs.filter(func(u: Unit) -> bool: return u.build_pending())
	check(busy.size() == 3, "the Labourers are still at work on it (%d of 3)" % busy.size())
	# they build the lot
	await _wait(150.0)
	var left := _pieces(cells).filter(func(b: Building) -> bool: return not b.built).size() + _pieces(cells, "gate").filter(func(b: Building) -> bool: return not b.built).size()
	check(left == 0 and _pieces(cells).size() == 10 and _pieces(cells, "gate").size() == 2, "the wall and its gates get built (%d unfinished, %d walls)" % [left, _pieces(cells).size()])
	var free_cell: Vector2i = cells[0] if cells[0] != gate_cell else cells[1]

	# ---- 2. a built wall: a gate on it replaces that piece only (the rest stands)
	var g2: int = g.place_line(0, "gate", free_cell, free_cell, labs)
	await _wait(2.0)
	check(g2 == 1 and _pieces(cells).size() == 9 and _pieces([free_cell], "gate").size() == 1, "a gate on a built wall takes that piece, the rest stands (%d walls left)" % _pieces(cells).size())

	# ---- 3. a wall going up: a gate dragged across the line replaces only what it covers
	var cells2 := _run_cells(hall, 10)
	check(cells2.size() == 10, "a second free run")
	g.place_line(0, "wall", cells2[0], cells2[9], labs)
	await _wait(6.0)
	var begun := _pieces(cells2).filter(func(b: Building) -> bool: return not b.ghost).size()
	g.place_line(0, "gate", cells2[4], cells2[5], [labs[0]])
	await _wait(3.5)
	check(_pieces(cells2).size() == 8 and _pieces(cells2, "gate").size() == 2, "a 2-piece gate over a wall being built: 8 walls and 2 gates (%d, %d; %d begun)" % [_pieces(cells2).size(), _pieces(cells2, "gate").size(), begun])
	check(labs.filter(func(u: Unit) -> bool: return u.build_pending()).size() >= 2, "its builders still work on it")
	print("DONE  %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
