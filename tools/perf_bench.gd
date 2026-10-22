extends SceneTree
## Performance benchmark: a computer-vs-computer match played at normal speed while every
## frame's real time is measured; prints (and saves) a table per game minute.
##
##   godot --headless --fixed-fps 60 --script res://tools/perf_bench.gd -- [map] [crown crown] [minutes:14] [out:name]
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 60 \
##       --script res://tools/perf_bench.gd -- sundered_realm crown crown
##
## --fixed-fps 60 makes every frame advance the game by 1/60 s whatever it costs, so the
## game minute is always 3600 frames and the frame times are the real cost of a frame (with
## physics at 30 ticks a second, every other frame runs the game logic). Without it the
## game runs in real time and a slow frame runs several physics ticks (as when playing).
## Player 1 is set up as "you" (fog, HUD, log lines as in a real match) but played by a
## Hard computer; the camera follows player 1's army (the fight, when there is one).
## Results: docs/perf/<out>.csv (and .md); the per-system breakdown comes from Perf zones.

var main: Node
var t := 0.0
var started := false
var stop_at := 14.0 * 60.0
var out_name := ""
var _last_us := 0
var _frames: PackedFloat32Array = PackedFloat32Array()    # ms of every frame this minute
var _minute := 0
var _rows: Array = []
var _cam_t := 0.0
var _wall0 := 0
var _phys_us := 0
var _proc_us := 0
var _cfg_text := ""
var _prev := {}
var _worst_ms := 0.0
var _worst_zones := ""

const ZONES := [&"unit", &"ai", &"game", &"vis", &"path", &"astar", &"smooth", &"hash", &"refit", &"building", &"unit_draw", &"bld_draw", &"hud_draw",
	&"overlay_draw", &"autosave", &"ai_workers", &"ai_econ", &"ai_build", &"ai_produce", &"ai_raid", &"ai_army", &"ai_horses", &"ai_loose", &"ai_abil", &"ai_micro"]


## Zones that ran since the last frame, slowest first: "path 80.1, ai 12.0, ..."
func _diff_zones() -> String:
	var d: Array = []
	for z in Perf.acc:
		var v := (int(Perf.acc[z]) - int(_prev.get(z, 0))) / 1000.0
		if v >= 1.0:
			d.append([v, z])
	d.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return ", ".join(d.map(func(x: Array) -> String: return "%s %.1f" % [x[1], x[0]]))


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


func _start() -> void:
	var args := OS.get_cmdline_user_args()
	var facs: Array = []
	var map := "sundered_realm"
	var level := "hard"
	for a in args:
		if a in ["crown", "brood", "clockwork"]:
			facs.append(a)
		elif MapGen.all_ids().has(a):
			map = a
		elif a.begins_with("minutes:"):
			stop_at = float(a.substr(8)) * 60.0
		elif a.begins_with("out:"):
			out_name = a.substr(4)
		elif a in ["easy", "normal", "hard", "brutal"]:
			level = a
	if facs.size() < 2:
		facs = ["crown", "crown"]
	var render := DisplayServer.get_name() != "headless"
	if out_name == "":
		out_name = "%s_%s_%s" % [map, "_".join(facs), "render" if render else "headless"]
	var slots: Array = []
	for i in facs.size():
		slots.append({"who": "you" if i == 0 else level, "faction": facs[i], "colour": i, "side": i, "strategy": "balanced"})
	main.start({"map": map, "slots": slots, "seed": 4242})
	var g: Game = main.game
	# player 1 is "you", played by a computer
	var ai := AI.new()
	ai.game = g
	ai.team = 0
	ai.difficulty = main.LEVELS.find(level)
	ai.strategy = "balanced"
	g.add_child(ai)
	g.ais.append(ai)
	_cfg_text = "%s, %s, %s AI, %s, Godot %s, %s" % [map, " vs ".join(facs), level, "rendered %s" % RenderingServer.get_video_adapter_name() if render else "headless",
		Engine.get_version_info()["string"], "%d physics ticks a second" % Engine.get_physics_ticks_per_second()]
	print("PERF start: ", _cfg_text)
	Perf.on = true
	Perf.reset()
	_wall0 = Time.get_ticks_msec()


func _process(delta: float) -> bool:
	var now := Time.get_ticks_usec()
	t += delta
	if not started:
		if t > 0.2:
			started = true
			_start()
		_last_us = now
		return false
	var g: Game = main.game
	if g == null:
		return false
	if paused:
		_last_us = now           # (the 3-2-1 countdown)
		return false
	var ms := (now - _last_us) / 1000.0
	_frames.append(ms)
	_last_us = now
	# what the slow frames spent their time on (zones are added up, so take the difference)
	if ms > _worst_ms:
		_worst_ms = ms
		_worst_zones = _diff_zones()
	if ms > 100.0:
		print("PERF spike %.0f ms at %d:%02d: %s" % [ms, int(g.clock) / 60, int(g.clock) % 60, _diff_zones()])
	_prev = Perf.acc.duplicate()
	_cam_t -= delta
	if _cam_t <= 0.0:
		_cam_t = 1.0
		_aim_camera(g)
	if int(g.clock / 60.0) > _minute or g.over or g.clock > stop_at:
		_minute_row(g)
		_minute = int(g.clock / 60.0)
	if g.over or g.clock > stop_at:
		_save()
		return true
	return false


## The camera on player 1's army: where it fights, else its middle.
func _aim_camera(g: Game) -> void:
	var c := Vector2.ZERO
	var n := 0
	for u in g.units:
		if u.team != 0 or u.dead or u.is_worker():
			continue
		if u.target and is_instance_valid(u.target):
			g.camera.position = u.position
			return
		c += u.position
		n += 1
	if n > 0:
		g.camera.position = c / n


func _minute_row(g: Game) -> void:
	if _frames.is_empty():
		return
	var arr := _frames.duplicate()
	arr.sort()
	var tot := 0.0
	var over33 := 0
	var over50 := 0
	for f in arr:
		tot += f
		if f > 33.3:
			over33 += 1
		if f > 50.0:
			over50 += 1
	var avg := tot / arr.size()
	# 1% low: the average of the slowest 1% of frames, as fps
	var k := maxi(1, arr.size() / 100)
	var slow := 0.0
	for i in k:
		slow += arr[arr.size() - 1 - i]
	slow /= k
	var units := 0
	for u in g.units:
		if not u.dead:
			units += 1
	var counts := _count_nodes(g)
	var row := {"min": int(g.clock / 60.0) if int(g.clock / 60.0) > _minute else _minute + 1, "frames": arr.size(), "avg_ms": avg, "fps": 1000.0 / avg,
		"low1_fps": 1000.0 / slow, "worst_ms": arr[arr.size() - 1], "over33": over33, "over50": over50,
		"units": units, "buildings": g.buildings.size(), "bodies": g.bodies.size(), "effects": counts["effects"],
		"projectiles": counts["projectiles"], "floats": g._floats.size(), "pings": g._pings.size(),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"mem_mb": OS.get_static_memory_usage() / 1048576.0, "log_lines": g.mlog.lines.size() if g.mlog else 0,
		"wall_s": (Time.get_ticks_msec() - _wall0) / 1000.0}
	for z in ZONES:
		row[String(z)] = float(Perf.acc.get(z, 0)) / 1000.0 / arr.size()      # ms a frame
	row["paths"] = int(Perf.calls.get(&"astar", 0))
	row["ai_thinks"] = int(Perf.calls.get(&"ai", 0))
	row["worst_frame_zones"] = "\"%s\"" % _worst_zones
	Perf.reset()
	_prev = {}
	_rows.append(row)
	var zs := PackedStringArray()
	for z in ZONES:
		zs.append("%s %.2f" % [z, row[String(z)]])
	print("PERF worst frame %.0f ms: %s" % [_worst_ms, _worst_zones])
	_worst_ms = 0.0
	print("PERF min %2d | %5.1f fps avg, 1%% low %5.1f, worst %6.1f ms, >33ms %4d, >50ms %4d | paths %d | units %d bodies %d fx %d proj %d nodes %d objs %d | ms/frame: %s" % [
		row["min"], row["fps"], row["low1_fps"], row["worst_ms"], over33, over50, row["paths"], units, row["bodies"], row["effects"], row["projectiles"],
		row["nodes"], row["objects"], ", ".join(zs)])
	_frames = PackedFloat32Array()


func _count_nodes(g: Game) -> Dictionary:
	var out := {"effects": 0, "projectiles": 0}
	var stack: Array = [g]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Effect:
			out["effects"] += 1
		elif n is Projectile:
			out["projectiles"] += 1
		stack.append_array(n.get_children())
	return out


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/perf"))
	var cols: Array = _rows[0].keys() if not _rows.is_empty() else []
	var csv := PackedStringArray([",".join(cols)])
	for r in _rows:
		var vals := PackedStringArray()
		for c in cols:
			vals.append(("%.2f" % r[c]) if r[c] is float else str(r[c]))
		csv.append(",".join(vals))
	var f := FileAccess.open("res://docs/perf/%s.csv" % out_name, FileAccess.WRITE)
	f.store_string("\n".join(csv) + "\n")
	f.close()
	var md := PackedStringArray(["# %s" % out_name, "", _cfg_text, "",
		"| min | fps avg | 1% low | worst ms | >33ms | >50ms | units | bodies | fx | nodes | unit ms | ai ms | game ms | vis ms | unit draw ms | hud draw ms |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"])
	for r in _rows:
		md.append("| %d | %.1f | %.1f | %.1f | %d | %d | %d | %d | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |" % [r["min"], r["fps"], r["low1_fps"], r["worst_ms"],
			r["over33"], r["over50"], r["units"], r["bodies"], r["effects"], r["nodes"], r["unit"], r["ai"], r["game"], r["vis"], r["unit_draw"], r["hud_draw"]])
	f = FileAccess.open("res://docs/perf/%s.md" % out_name, FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	f.close()
	print("PERF saved docs/perf/%s.csv" % out_name)
