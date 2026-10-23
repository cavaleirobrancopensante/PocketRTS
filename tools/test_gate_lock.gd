extends SceneTree
## Gates: LOCK shuts one for everybody (a padlock shows), ROTATE only while it isn't built:
##   godot --headless --fixed-fps 30 --script res://tools/test_gate_lock.gd
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


func _labels(b: Building) -> Array:
	g.selection.clear()
	g.selection.append(b)
	b.selected = true
	var out: Array = []
	for e in g.hud._build_card():
		out.append(String(e[1]))
	b.selected = false
	return out


func _run() -> void:
	g.explored.fill(1)
	g.players[0]["gold"] = 5000
	var hall: Building = g.halls_of(0)[0]
	var spot: Vector2i = g.find_spot(0, "gate", hall, 4, 9, "near")
	check(spot.x >= 0, "a spot for a gate")
	# unbuilt: can be rotated; built: cannot, but can be locked
	var site: Building = g._add_building("gate", 0, spot, false)
	check("ROTATE" in _labels(site), "an unbuilt gate has ROTATE")
	site.die()
	var gate: Building = g._add_building("gate", 0, spot, true)
	await physics_frame
	var labels := _labels(gate)
	check(not ("ROTATE" in labels), "a built gate has no ROTATE")
	check("LOCK" in labels and not ("UNLOCK" in labels), "a built gate has LOCK")
	var i: int = g.idx(spot)
	check(g.passable(spot, 0) and not g.astar.is_point_solid(spot), "open: its owner passes")
	check(g.set_gate_locked(gate, true) == "" and gate.locked, "locked")
	check(not g.passable(spot, 0) and not g.passable(spot, 1) and g.astar.is_point_solid(spot), "locked: nobody passes, its owner included")
	check("UNLOCK" in _labels(gate), "a locked gate has UNLOCK")
	check(not g._gate_lets(i, 3, 0), "locked: the movement check says shut")
	gate.queue_redraw()
	await physics_frame
	check(g.set_gate_locked(gate, false) == "" and not gate.locked, "unlocked")
	check(g.passable(spot, 0) and not g.astar.is_point_solid(spot), "unlocked: its owner passes again")
	# a man standing in the gateway: it cannot be locked
	var u: Unit = g._add_unit("labourer", 0, gate.center())
	await physics_frame
	check(g.set_gate_locked(gate, true) != "" and not gate.locked, "something in the gateway: it will not lock")
	g.consume_unit(u)
	print("gate lock: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)
