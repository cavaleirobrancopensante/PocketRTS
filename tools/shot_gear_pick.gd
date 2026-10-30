extends SceneTree
## Screenshots of the GEAR PICK (0.24.12, docs/gear_rules.md): the placing ghost of a Light Works on its SMALL ring and on
## its BIG ring at the same spot (the card's SMALL GEAR / BIG GEAR button, the size under the ghost's verdict), and a big
## ring refused where the small one fits (CLASH).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_gear_pick.gd -- <outdir>
var main: Node
var g: Game
var out := ""
var t := 0.0
var started := false
const K := "movement_works"


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "clockwork", "colour": 0, "side": 0},
			{"who": "easy", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.5:
		started = true
		_run()
	return false


func _snap(name: String, frames := 30) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _run() -> void:
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.explored.fill(1)
	g.players[0]["gold"] = 5000
	var hall: Building = null
	for b in g.buildings:
		if b.team == 0 and b.kind == "clocktower":
			hall = b
	var both := Vector2i(-1, -1)
	var tight := Vector2i(-1, -1)
	var size: Vector2i = Defs.BUILDINGS[K]["size"]
	var bd := INF
	var td := INF
	for y in range(hall.cell.y - 16, hall.cell.y + 17):
		for x in range(hall.cell.x - 16, hall.cell.x + 17):
			var c := Vector2i(x, y)
			if not g.in_map(c) or c.x < 6 or c.y < 6 or c.x > g.W - 8 or c.y > g.H - 8 or not g.margin_free(c, size):
				continue
			var d := Vector2(c - hall.cell).length()          # (nearest the Clocktower, away from the map's edge)
			g.set_gear_pick(0, K, false)
			var s_ok := g.placement_problem(0, K, c) == ""
			g.set_gear_pick(0, K, true)
			var why_b := g.placement_problem(0, K, c)
			if d < bd and s_ok and why_b == "":
				both = c
				bd = d
			if d < td and s_ok and why_b.contains("clash"):
				tight = c
				td = d
	print("spots: both %s tight %s" % [both, tight])
	g.set_gear_pick(0, K, false)
	# a Winder selected, so the card is the worker's (PLACE, SMALL GEAR, CANCEL)
	for u in g.units:
		if u.team == 0 and u.is_worker():
			g.selection = [u]
			break
	if both.x >= 0:
		g.controls.begin_place(K)
		g.controls.ghost_cell = both
		g.camera.position = Vector2(both) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5 + Vector2(0, -20)
		g.camera.zoom = Vector2(1.3, 1.3)
		await _snap("ghost_small_gear")
		g.hud.toggle_gear_pick()
		g.controls.ghost_cell = both
		await _snap("ghost_big_gear")
		g.set_gear_pick(0, K, false)
	if tight.x >= 0:
		g.set_gear_pick(0, K, true)
		g.controls.begin_place(K)
		g.controls.ghost_cell = tight
		g.camera.position = Vector2(tight) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5
		await _snap("ghost_big_gear_clash")
	g.controls.cancel_mode()
	quit(0)
