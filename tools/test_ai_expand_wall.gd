extends SceneTree
## CROWN WALL EXPAND (the owner, 2026-10-31; scripts/ai_expand_wall.gd, docs/crown_wall_expand.md): the Crown computer's
## expansions are walled in, its buildings first, palisade in the gaps, a gate.
## A Hard Crown computer (Balanced, Powder Mill opening, peaceful: it never attacks) against a Brood that stands still,
## on each map until its first expansion has stood STAND s (or LIMIT s of game time). Then, measured by walking the map:
##  1. most of its ways in are shut STAND s after the hall stood: at least MIN_SHUT of the ways-in cells the plan found
##     (the ring cells the enemy walked to on the map as it was) are under a building, palisade or gate
##  2. SEALED by SEAL_BY s after the hall stood: no enemy walk from the enemy's main (open ground and its own gates; our
##     buildings, palisade and gates block) reaches the expansion's core (CORE tiles round the hall's middle)
##  3. buildings are part of the wall (at least one slot holds a building), and the gate is there
##  4. the workers still reach their farms: every Farm and Mill of the expansion is walked to from the hall (our gates
##     open), it has a Farm, and the hall is walked to from the main
## Pictures: run under xvfb with `shots:1` (each walled expansion into docs/shots/crown_wall_expand/).
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_expand_wall.gd [-- maps:a,b,c seed:n]
##   xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --script res://tools/test_ai_expand_wall.gd -- shots:1
const STAND := 180.0
const SEAL_BY := 240.0
const LIMIT := 1000.0
const CORE := 6.0
const MIN_SHUT := 0.8
const OUT := "res://docs/shots/crown_wall_expand"
var maps: Array = ["ashford_crossing", "kestrel_rise", "cinder_steps"]
var seed_ := 7
var shots := false
var fails := 0
var shut_at := -1.0
var sealed_t := -1.0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("maps:"):
			maps = a.substr(5).split(",")
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a == "shots:1":
			shots = true
	if shots:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
		Engine.max_fps = 0
		RenderingServer.render_loop_enabled = false
	_run.call_deferred()


func _run() -> void:
	for m in maps:
		await _case(m)
	print("RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


func _case(map: String) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	seed(seed_)
	main.start({"map": map, "seed": seed_, "slots": [
		{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
		if shots:
			g.hud.visible = false
	paused = false
	var ai = null
	for a in g.ais:
		if a.team == 1:
			a.process_mode = Node.PROCESS_MODE_DISABLED      # (the other side stands still)
		else:
			a.peaceful = true
			a.opening = "mill"
			if OS.get_cmdline_user_args().has("off"):
				a.xw.on = false
			ai = a
	if shots:
		if g.spectator:
			g.spectator.process_mode = Node.PROCESS_MODE_DISABLED
		if g.controls:
			g.controls.process_mode = Node.PROCESS_MODE_DISABLED
	var hall: Building = null
	var built_t := -1.0
	shut_at = -1.0
	sealed_t = -1.0
	var seal_look := 0.0
	var line := 0.0
	while g.clock < LIMIT:
		await physics_frame
		if hall == null or not is_instance_valid(hall) or hall.dead:
			hall = null
			var home := Vector2(g.starts[0]) * Defs.TILE
			for h in g.halls_of(0, false):
				if h.center().distance_to(home) > 10.0 * Defs.TILE:
					hall = h
					built_t = -1.0
					print("  %s %4.0f s: expansion laid at %s" % [map, g.clock, str(hall.cell)])
					break
		if hall != null and hall.built and built_t < 0.0:
			built_t = g.clock
			print("  %s %4.0f s: expansion stands" % [map, g.clock])
		if g.clock > line:
			line = g.clock + 30.0
			var s := ""
			if hall != null and not ai.xw.plan_of(hall).is_empty():
				var p: Dictionary = ai.xw.plan_of(hall)
				s = "plan r %d ways-in %d slots %d (filled %d) pieces %d shut %.2f guards %d" % [int(p["r"]), (p["exposed"] as Array).size(),
					(p["slots"] as Array).size(), _filled(p), (p["pieces"] as Array).size(), ai.xw.closed_share(p), ai._guards.size()]
			if hall != null:
				for b in g.buildings:
					if b.team == 0 and not b.dead and (b.kind == "farm" or b.kind == "powder_mill") and g.nearest_hall(b.center(), 0) == hall:
						s += " %s(built %s crew %d)" % [b.kind, str(b.built), b.working_crew()]
			var idle: int = g.workers(0).filter(func(u: Unit) -> bool: return u.order == "idle").size()
			print("  %s %4.0f s: gold %4d labs %d (idle %d) army %d halls %d %s" % [map, g.clock, g.players[0]["gold"], g.workers(0).size(), idle, g.army(0).size(), g.halls_of(0, false).size(), s])
		if built_t >= 0.0 and g.clock > built_t + STAND:
			if shut_at < 0.0:
				shut_at = ai.xw.closed_share(ai.xw.plan_of(hall))
			if g.clock > seal_look:
				seal_look = g.clock + 5.0
				if _leak(ai, hall) == 0:
					sealed_t = g.clock - built_t
					break
			if g.clock > built_t + SEAL_BY:
				break
	check(hall != null and built_t >= 0.0, "[%s] the Crown expanded (hall stood at %.0f s)" % [map, built_t])
	if hall != null and built_t >= 0.0 and not ai.xw.on:
		for b in g.buildings:
			if b.team == 0 and not b.dead and (b.kind == "farm" or b.kind == "powder_mill") and g.nearest_hall(b.center(), 0) == hall:
				print("  %s (wall plan off): %s at %s built %s crew %d" % [map, b.kind, str(b.cell), str(b.built), b.working_crew()])
	elif hall != null and built_t >= 0.0:
		_judge(g, ai, hall, map)
		if shots:
			await _shot(g, hall, map)
	if g.mlog:
		for l in g.mlog.lines:
			if "wall" in l or "Town Hall" in l or "expanding" in l:
				print("    | " + l)
	main.queue_free()
	await process_frame
	await process_frame


## Core cells (CORE tiles round the hall's middle) the enemy walks to from its main.
func _leak(ai, hall: Building) -> int:
	var hc: Vector2 = hall.center() / Defs.TILE
	var n := 0
	for c in ai.xw._foe_reach():
		if (Vector2(c) + Vector2(0.5, 0.5)).distance_to(hc) < CORE:
			n += 1
	return n


func _filled(p: Dictionary) -> int:
	var n := 0
	for s in p["slots"]:
		var b = s.get("b")
		if b != null and is_instance_valid(b) and not b.dead:
			n += 1
	return n


func _judge(g: Game, ai, hall: Building, map: String) -> void:
	var p: Dictionary = ai.xw.plan_of(hall)
	# 1. ways in shut at STAND
	check(shut_at >= MIN_SHUT, "[%s] %d%% of its %d ways-in cells shut %.0f s after the hall stood (at least %d%%)" % [map, int(shut_at * 100), (p["exposed"] as Array).size(), STAND, int(MIN_SHUT * 100)])
	# 2. sealed: the enemy's walk from its main
	var leak := _leak(ai, hall)
	check(sealed_t >= 0.0, "[%s] no enemy walk into the expansion's core by %.0f s after it stood (sealed at %.0f s; %d core cells reached now)" % [map, SEAL_BY, sealed_t, leak])
	# 3. buildings in the wall, a gate
	var kinds: Array = []
	for s in p["slots"]:
		var b = s.get("b")
		if b != null and is_instance_valid(b) and not b.dead:
			kinds.append(b.kind)
	var gates := 0
	var walls := 0
	for e in p["pieces"]:
		var b: Building = g._own_gate_at(0, e[1]) if e[0] == "gate" else g._own_wall_at(0, e[1])
		if b != null:
			if e[0] == "gate":
				gates += 1
			else:
				walls += 1
	print("  %s: wall of %s + %d palisade + %d gate (radius %d, %d ways-in cells, %d inside)" % [map, str(kinds), walls, gates, int(p["r"]), (p["exposed"] as Array).size(), (p["inside"] as Dictionary).size()])
	check(kinds.size() >= 1 or (p["exposed"] as Array).size() <= 4, "[%s] buildings stand in the wall (%s)" % [map, str(kinds)])
	check(gates >= 1 or (p["exposed"] as Array).is_empty(), "[%s] a gate in the wall (%d)" % [map, gates])
	# 4. the workers' walks
	var own: Dictionary = ai.xw._walk_dist(hall.cell + Vector2i(2, 2))
	var reach_main := false
	var home: Vector2i = g.starts[0]
	for y in range(home.y - 2, home.y + 7):
		for x in range(home.x - 2, home.x + 8):
			if own.has(Vector2i(x, y)):
				reach_main = true
	check(reach_main, "[%s] the expansion walks to the main" % map)
	var farms := 0
	for b in g.buildings:
		if b.team != 0 or b.dead or not (b.kind == "farm" or b.kind == "powder_mill") or g.nearest_hall(b.center(), 0) != hall:
			continue
		var reached := false
		var r := Rect2i(b.cell - Vector2i(1, 1), b.size + Vector2i(2, 2))
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if own.has(Vector2i(x, y)):
					reached = true
		var inside := 0
		for y in b.size.y:
			for x in b.size.x:
				if (p["inside"] as Dictionary).has(b.cell + Vector2i(x, y)):
					inside += 1
		if b.kind == "farm":
			farms += 1
		print("  %s: %s at %s built %s crew %d, %d/%d cells inside the wall" % [map, b.kind, str(b.cell), str(b.built), b.working_crew(), inside, b.size.x * b.size.y])
		check(reached, "[%s] the hall's workers walk to its %s at %s" % [map, b.kind, str(b.cell)])
	check(farms >= 1, "[%s] the expansion has a Farm (%d)" % [map, farms])


func _shot(g: Game, hall: Building, map: String) -> void:
	var cam: Camera2D = g.camera
	cam.position = hall.center()
	cam.zoom = Vector2(0.6, 0.6)
	cam.reset_smoothing()
	g.reveal = true
	g.fog_base_dirty = true
	RenderingServer.render_loop_enabled = true
	for i in 8:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT.path_join("%s.png" % map))
	img.save_png(path)
	print("SHOT " + path)
	# the same with the plan drawn over it: its ways-in cells (orange), the gate cells (cyan), the building slots (white)
	# and the room kept for the Farms and Mill (green)
	var ai = null
	for a in g.ais:
		if a.team == 0:
			ai = a
	var p: Dictionary = ai.xw.plan_of(hall)
	var over := Node2D.new()
	over.z_index = 100
	g.add_child(over)
	var T := float(Defs.TILE)
	over.draw.connect(func() -> void:
		for c in p["exposed"]:
			over.draw_rect(Rect2(Vector2(c) * T, Vector2(T, T)), Color(1.0, 0.55, 0.1, 0.9), false, 3.0)
		for e in p["pieces"]:
			if e[0] == "gate":
				over.draw_rect(Rect2(Vector2(e[1]) * T + Vector2(4, 4), Vector2(T - 8, T - 8)), Color(0.2, 0.9, 1.0, 0.95), false, 3.0)
		for s in p["slots"]:
			over.draw_rect(Rect2(Vector2(s["cell"]) * T, Vector2(s["size"]) * T), Color(1, 1, 1, 0.9), false, 2.0)
		for e in p.get("econ", []):
			over.draw_rect(Rect2(Vector2(e[1]) * T, Vector2(Defs.BUILDINGS[e[0]]["size"]) * T), Color(0.3, 1.0, 0.3, 0.8), false, 2.0))
	over.queue_redraw()
	for i in 4:
		await process_frame
	img = root.get_viewport().get_texture().get_image()
	path = ProjectSettings.globalize_path(OUT.path_join("%s_plan.png" % map))
	img.save_png(path)
	print("SHOT " + path)
	over.queue_free()
	RenderingServer.render_loop_enabled = false
