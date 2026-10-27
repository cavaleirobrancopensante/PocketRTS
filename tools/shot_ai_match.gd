extends SceneTree
## Film a computer-against-computer match: screenshots of the fights as they happen and of each side's base at set
## times, plus the match log. For looking closely at a few games (2026-10-27, Crown v Clockwork).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_ai_match.gd -- \
##       a:crown b:clockwork map:greenhold seed:11 swap:0 out:/abs/dir [end:1800]
## Writes <out>/fight_MMSS_<x>_<y>.png (a fight: where the most units of both sides meet, at most one every FIGHT_GAP s),
## <out>/base_<team>_MMSS.png (each main at BASE_AT), <out>/log.txt (the match log) and <out>/result.txt.
const FIGHT_GAP := 25.0
const FIGHT_MIN := 4            # units of each side near each other
const NEAR := 230.0
const BASE_AT := [180.0, 360.0, 600.0, 900.0]
var main: Node
var g: Game
var fa := "crown"
var fb := "clockwork"
var map := "greenhold"
var seed_ := 1
var swap := false
var out := "/tmp/ai_match"
var end_t := 1800.0
var live := false            # live:1 keeps drawing every frame (slow; for checking the shots)
var t := 0.0
var last_fight := -999.0
var next_check := 0.0
var base_i := 0
var next_wind := 30.0
var wind_lines: Array = []
var pending: Array = []        # [file, camera position, zoom]
var shooting := false
var _draws := 0
var shot_frames := 30
func _count_draw() -> void:
	_draws += 1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"a": fa = kv[1]
			"b": fb = kv[1]
			"map": map = kv[1]
			"seed": seed_ = int(kv[1])
			"swap": swap = kv[1] == "1"
			"out": out = kv[1]
			"end": end_t = float(kv[1])
			"live": live = kv[1] == "1"
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "pc"
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.render_loop_enabled = live     # (drawn only for the shots: the match runs many times faster)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var facs := [fb, fa] if swap else [fa, fb]
		var slots: Array = []
		for i in 2:
			slots.append({"who": "hard", "faction": facs[i], "colour": i, "side": i, "strategy": "balanced"})
		main.start({"map": map, "seed": seed_, "slots": slots})
		return false
	if main.game == null:
		return false
	g = main.game
	if not g.gear_net.draw.is_connected(_count_draw):
		g.gear_net.draw.connect(_count_draw)
	if g.hud:
		g.hud.visible = false
	if g.spectator and g.spectator.process_mode != Node.PROCESS_MODE_DISABLED:
		g.spectator.process_mode = Node.PROCESS_MODE_DISABLED     # (the director camera would move it off the shot)
	if g.controls and g.controls.process_mode != Node.PROCESS_MODE_DISABLED:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED       # (the mouse sits in a corner under xvfb: edge scrolling)
	if shooting:
		return false
	if not pending.is_empty():
		_shoot()
		return false
	var c: float = g.clock
	if base_i < BASE_AT.size() and c >= BASE_AT[base_i]:
		for tm in 2:
			var h: Building = g._own_hall(tm)
			if h:
				pending.append(["base_%d_%s.png" % [tm, _mmss(c)], h.global_position + Vector2(0, -40), 0.8])
		base_i += 1
	if c >= next_check:
		next_check = c + 2.0
		_look_for_fight(c)
	if c >= next_wind:
		next_wind = c + 30.0
		_wind_line(c)
	if g.over or c >= end_t:
		_finish()
		return true
	return false


## Every 30 s, the Clockwork army's wind (a Clock Soldier runs down in ~80 s off its gear ground and then stands still):
## how many are run down (statues), low (under 0.2), on gear ground, and how far the run-down ones are from their main.
func _wind_line(c: float) -> void:
	for tm in 2:
		if g.factions[tm] != "clockwork":
			continue
		var n := 0
		var down := 0
		var low := 0
		var field := 0
		var far := 0.0
		var home: Building = g._own_hall(tm)
		for u in g.units:
			if not is_instance_valid(u) or u.dead or u.team != tm or u.is_worker() or u.is_air():
				continue
			n += 1
			if u.powered_down():
				down += 1
				if home:
					far += u.position.distance_to(home.center()) / Game.T
			elif u.wind < 0.2:
				low += 1
			if u._in_field:
				field += 1
		wind_lines.append("%s clockwork army %d: run down %d (avg %.0f tiles from the main), low %d, on gear ground %d" % [_mmss(c), n, down, far / maxf(1, down), low, field])


## What each soldier in a fight shot is doing (written to <out>/why.txt): its order, what it is after, whether it can
## get at it (walk there with the gates shut) and the AI's siege, to see why an army stands where it stands.
var why: Array = []


func _why_lines(file: String, at: Vector2) -> void:
	if not file.begins_with("fight"):
		return
	why.append("== %s" % file)
	for a in g.ais:
		var sg = a.get("_siege")
		why.append("  team %d attacking %s wave_target %s siege %s" % [a.team, str(a.get("_attacking")), str(a.get("_wave_target")),
			("piece %s at %s stage %s" % [sg["piece"].kind, str(sg["piece"].center()), str(sg["stage"])]) if sg is Dictionary and not sg.is_empty() and is_instance_valid(sg.get("piece")) else "-"])
	for u in g.units:
		if not is_instance_valid(u) or u.dead or u.is_worker() or u.position.distance_to(at) > 500.0:
			continue
		var c = g.cell_of(u.position)
		var tg = u.target
		var ts := "-"
		if is_instance_valid(tg) and not tg.dead:
			var tc = g.cell_of(tg.position if tg.is_unit() else tg.center())
			ts = "%s(t%d) h%d d%.0f canget %s walk %s" % [tg.kind, tg.team, g.height[g.idx(tc)] if g.in_map(tc) else -1, tg.edge_distance(u.position), str(u._can_get_at(tg)), str(u._walk_reaches(tg))]
		why.append("  t%d %s %s h%d v%.0f order %s ot %s goal %s path %d/%d siege %.1f wind %.2f -> %s" % [u.team, u.kind, str(u.position.round()), g.height[g.idx(c)] if g.in_map(c) else -1, u.velocity.length(), u.order,
			(u.order_target.kind if is_instance_valid(u.order_target) else "-"), str(u.path_goal.round()) if u.path_goal != Vector2.INF else "-", u.path_i, u.path.size(), u.siege_t, u.wind, ts])


func _mmss(c: float) -> String:
	return "%02d%02d" % [int(c) / 60, int(c) % 60]


func _look_for_fight(c: float) -> void:
	if c - last_fight < FIGHT_GAP:
		return
	var army: Array = []
	for u in g.units:
		if is_instance_valid(u) and not u.dead and u.kind != String(Defs.FACTIONS[g.factions[u.team]]["worker"]):
			army.append(u)
	var best := 0
	var at := Vector2.ZERO
	for u in army:
		var mine := 0
		var theirs := 0
		for o in army:
			if o.position.distance_to(u.position) < NEAR:
				if o.team == u.team:
					mine += 1
				else:
					theirs += 1
		var s := mini(mine, theirs)
		if s > best:
			best = s
			at = u.position
	if best >= FIGHT_MIN:
		last_fight = c
		pending.append(["fight_%s_%d_%d.png" % [_mmss(c), int(at.x), int(at.y)], at, 1.15])


func _shoot() -> void:
	shooting = true
	var p: Array = pending.pop_front()
	var cam: Camera2D = g.camera
	var keep_pos := cam.position
	var keep_zoom := cam.zoom
	cam.position = p[1]
	cam.zoom = Vector2(p[2], p[2])
	cam.reset_smoothing()
	RenderingServer.render_loop_enabled = true     # (drawn normally for a few frames: get_image() gives the last frame drawn)
	for i in shot_frames:
		await process_frame
	print("SHOT %s zoom %s at %s view %s gearvis %s draws %d" % [p[0], str(cam.zoom), str(cam.get_screen_center_position()), str(g.view_rect), str(g.gear_net.is_visible_in_tree()), _draws])
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(p[0]))
	_why_lines(p[0], p[1])
	RenderingServer.render_loop_enabled = live
	cam.position = keep_pos
	cam.zoom = keep_zoom
	shooting = false


func _finish() -> void:
	var f := FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	if g.mlog:
		for l in g.mlog.lines:
			f.store_line(str(l))
	f.close()
	var yf := FileAccess.open(out.path_join("why.txt"), FileAccess.WRITE)
	for l in why:
		yf.store_line(l)
	yf.close()
	var wf := FileAccess.open(out.path_join("wind.txt"), FileAccess.WRITE)
	for l in wind_lines:
		wf.store_line(l)
	wf.close()
	var r := FileAccess.open(out.path_join("result.txt"), FileAccess.WRITE)
	r.store_line("over %s winner %s clock %.0f" % [str(g.over), str(g.get("winner")), g.clock])
	r.close()
