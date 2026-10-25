extends SceneTree
## Screenshots of the Clockwork Line: pipes with the art (or code art with `code`), the pressure overlay,
## a damaged and a destroyed segment with steam, an unpowered building and a relay.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_line_loop.gd -- <outdir> [code]
## Writes <outdir>/loop_*.png: the loops, trains on the two tracks, the ghost preview.
var main: Node
var g
var out := ""
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	LineArt.disabled = a.size() > 1 and a[1] == "code"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "ashford_crossing", "seed": 4242, "slots": [
			{"who": "you", "faction": "clockwork", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = false
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _snap(name: String) -> void:
	await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _run() -> void:
	var U = load("res://tools/line_test_util.gd")
	g.reveal = true
	g.players[0]["gold"] = 5000
	var net = g.line_net
	net.clear()
	var h: Building = U.hall(g, 0)
	for b in g.buildings.duplicate():
		if b.team == 0 and b.kind in ["ore_drill", "ore_crusher"]:
			g._remove_quietly(b)
	var S := {}
	for d in [Vector2i(12, 0), Vector2i(-12, 0), Vector2i(0, 12), Vector2i(0, -12)]:
		for c in net.ring(h):
			if not net.pipeable(0, c) or not net.pipeable(0, c + d):
				continue
			var drill: Building = U.building_beside(g, 0, "ore_drill", c + d)
			if drill == null:
				continue
			var p: Dictionary = net.plan(0, c, c + d)
			if not p["ok"]:
				g._remove_quietly(drill)
				continue
			for q in p["cells"]:
				net.add_built(0, q)
			S = {"drill": drill, "plan": p}
			break
		if not S.is_empty():
			break
	net.solve()
	var drill: Building = S["drill"]
	drill.stock = 150.0
	var cells: Array = S["plan"]["run"]
	var mid: Vector2 = (h.center() + drill.center()) * 0.5
	g.camera.zoom = Vector2(1.6, 1.6)
	g.camera.position = mid
	await _snap("loop_wide")
	for i in 2:
		var tr = net.rails.add_train(0, "ore")
		tr.cargo = 80.0 if i == 0 else 0.0
	var tp = net.rails.add_train(0, "troop")
	for k in 4:
		await create_timer(2.2).timeout
		drill.stock = 150.0
		g.camera.position = mid
		await _snap("loop_trains%d" % k)
	g.camera.zoom = Vector2(2.6, 2.6)
	var t0 = net.rails.trains[0]
	g.camera.position = t0.position
	await _snap("loop_closeup")
	await create_timer(1.3).timeout
	g.camera.position = net.rails.trains[1].position
	await _snap("loop_closeup2")
	# the ghost preview with the loop
	net.clear()
	g._remove_quietly(drill)
	var d2: Building = U.building_beside(g, 0, "ore_drill", cells[cells.size() - 1])
	var c0: Vector2i = cells[0]
	var p2: Dictionary = net.plan(0, c0, cells[cells.size() - 1])
	net.tool_on = true
	net.tool_from = c0
	net.tool_path = p2["cells"]
	net.tool_info = p2
	net.redraw()
	g.camera.zoom = Vector2(1.6, 1.6)
	g.camera.position = mid
	await _snap("loop_ghost")
	quit()
