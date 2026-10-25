extends SceneTree
## Screenshots of the Clockwork Line: pipes with the art (or code art with `code`), the pressure overlay,
## a damaged and a destroyed segment with steam, an unpowered building and a relay.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_line.gd -- <outdir> [code]
## Writes <outdir>/line_pipes.png, line_overlay.png, line_wide.png
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
	g.players[0]["ore"] = 5000
	var h: Building = U.hall(g, 0)
	var cells: Array = U.run_from_hall(g, 0, 26)
	# a branch in the middle and a building at the end, one more building off the Line
	var asm: Building = U.building_beside(g, 0, "assembly_works", cells[cells.size() - 1])
	var relay: Building = U.building_beside(g, 0, "pressure_relay", cells[13])
	var far: Building = U.building_beside(g, 0, "engine_hall", cells[6])
	if far:
		# move it off the Line: a lone engine hall elsewhere on the plateau
		g._remove_quietly(far)
	var lone: Building = g._add_building("capacitor_works", 0, h.cell + Vector2i(-8, 6), true)
	# damage one segment, destroy the look of another
	var segs: Array = g.line_net.segs.values()
	if segs.size() > 8:
		segs[5].hp = segs[5].max_hp * 0.3
		segs[9].hp = segs[9].max_hp * 0.1
	g.line_net.solve()
	g.camera.zoom = Vector2(2.2, 2.2)
	g.camera.position = g.cell_center(cells[cells.size() / 2])
	await _snap("line_pipes")
	g.line_net.overlay_on = true
	g.line_net.redraw()
	await _snap("line_overlay")
	g.line_net.overlay_on = false
	g.line_net.redraw()
	# the Drill, two ore trains (one loaded) and a troop train on the run
	var drill: Building = U.building_beside(g, 0, "ore_drill", cells[9])
	if drill:
		drill.stock = 120.0
	for sg in segs:
		sg.hp = sg.max_hp
	g.line_net.solve()
	g.line_net.rails.add_train(0, "ore")
	var t2: Train = g.line_net.rails.add_train(0, "ore")
	if t2:
		t2.cargo = 80.0
	g.line_net.rails.add_train(0, "troop")
	g.camera.zoom = Vector2(2.2, 2.2)
	g.camera.position = g.cell_center(cells[8]) + Vector2(60, 0)
	await create_timer(5.0).timeout
	await _snap("line_trains")
	await create_timer(1.5).timeout
	await _snap("line_trains2")
	g.camera.zoom = Vector2(1.4, 1.4)
	g.camera.position = (h.center() + (lone.center() if lone else h.center())) * 0.5 + Vector2(120, 0)
	await _snap("line_wide")
	print("cells ", cells.size(), " asm ", asm, " relay ", relay, " lone ", lone)
	quit()
