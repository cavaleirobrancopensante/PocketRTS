extends SceneTree
## Where the Brood AI plants its Clutch Mounds: the first by the ramp on the capital's plateau, later ones on the low
## ground, each nearer the enemy than the one before (the swamp walks forward):
##   godot --headless --fixed-fps 30 --script res://tools/test_mound_ramp.gd [-- map:<id>]
var main: Node
var g: Game
var t := 0.0
var map := "greenhold"
var fails := 0
var started := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": map, "seed": 4242, "slots": [
			{"who": "hard", "faction": "brood", "colour": 0, "side": 0, "strategy": "economy"},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for a in g.ais:
			if a.team == 1:
				a.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _run() -> void:
	Engine.time_scale = 6.0
	var foe_hall: Building = g.halls_of(1)[0]
	var cap: Building = g.capital(0)
	var h0 := int(g.height[g.idx(g.cell_of(cap.center()))])
	var top := g.ramp_top(cap)
	var seen: Array = []
	var end := 600.0
	var nxt := 60.0
	while g.clock < end and seen.size() < 4:
		await physics_frame
		if g.clock >= nxt:
			nxt += 60.0
			var st := []
			for b in g.buildings:
				if b.team == 0 and b.kind == "clutch_mound" and not b.dead:
					st.append("%s%s" % [str(b.cell), "G" if b.ghost else ("B" if b.built else "u")])
			print("  t=%d s: supply %d/%d gold %d mounds %s" % [int(g.clock), g.supply_used(0), int(g.players[0]["cap"]), int(g.players[0]["gold"]), str(st)])
		for b in g.buildings:
			if b.team == 0 and b.kind == "clutch_mound" and not seen.has(b) and not b.dead and not b.ghost:
				seen.append(b)
	Engine.time_scale = 1.0
	print("map %s clock %.0f s: %d mounds, ramp top %s, capital height %d" % [map, g.clock, seen.size(), str(top), h0])
	check(seen.size() >= 2, "the AI planted at least two mounds")
	var prev := INF
	for k in seen.size():
		var b: Building = seen[k]
		var hh := int(g.height[g.idx(g.cell_of(b.center()))])
		var dr: float = b.center().distance_to(top * float(Defs.TILE)) / float(Defs.TILE) if top != Vector2.INF else -1.0
		var df: float = b.center().distance_to(foe_hall.center()) / float(Defs.TILE)
		print("  mound %d at %s built %s ghost %s: height %d (capital %d), %.1f tiles from the ramp top, %.1f tiles from the enemy hall" % [k + 1, str(b.cell), str(b.built), str(b.ghost), hh, h0, dr, df])
		if k == 0 and top != Vector2.INF:
			check(hh == h0 and dr <= 12.0, "the first mound is on the capital's plateau, by the ramp")
		if k >= 1:
			check(hh != h0 or top == Vector2.INF, "mound %d is on the low ground" % (k + 1))
			check(df < prev + 1.0, "mound %d is not farther from the enemy than the one before" % (k + 1))
		prev = df
	print("DONE %d failure(s)" % fails)
	quit(1 if fails else 0)
