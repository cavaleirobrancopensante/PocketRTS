extends SceneTree
## Performance benchmark: a computer-vs-computer match played at normal speed while every
## frame's real time is measured; prints (and saves) a table per game minute.
##
##   godot --headless --fixed-fps 60 --script res://tools/perf_bench.gd -- [map] [crown crown] [minutes:14] [out:name]
##       [seed:4242] [2v2] [mobile] [trace:/abs/file.txt]
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 60 \
##       --script res://tools/perf_bench.gd -- sundered_realm crown crown
##
## --fixed-fps 60 makes every frame advance the game by 1/60 s whatever it costs, so the
## game minute is always 3600 frames and the frame times are the real cost of a frame (with
## physics at 30 ticks a second, every other frame runs the game logic). Without it the
## game runs in real time and a slow frame runs several physics ticks (as when playing).
## Player 1 is set up as "you" (fog, HUD, log lines as in a real match) but played by a
## Hard computer; the camera follows player 1's army (the fight, when there is one).
## Results: docs/perf/<out>.csv (and .md); the per-system breakdown comes from the Prof parts (scripts/prof.gd).
## "cpu_s" is the processor time the whole program used in that game minute (from /proc, Linux only):
## unlike the frame times it doesn't grow when other programs share the machine.
## seed:N picks the match (default 4242); 2v2 puts the first half of the players against the
## second; mobile sets the phone/tablet profile (Settings.device) instead of the computer's.
## trace:FILE writes the state of the match (every unit and building, everyone's resources)
## every 5 game seconds: two runs of the same match must write the same file (the
## performance work must not change how a match plays out).
## The match plays out the same every time: the sounds and the music, which go by the wall
## clock (a sound isn't repeated within so many ms; a piece of music ends) and draw from the same
## random numbers as the game, are kept silent (SilentSfx below), and the path queue's 6 ms
## limit is lifted (Game.path_budget_us: only its 24 paths a tick are left). Add "sound" to
## keep both as in a real match (then two runs drift apart within seconds).

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
var _prev := {}                  # Prof.us at the end of the last frame
var _prev_calls := {}
var _frame := {}                 # Prof.us added during this frame
var _acc := {}                   # ... and during this minute (Prof itself is reset by the match log)
var _acc_calls := {}
## The same parts per second of play (60 frames): each minute's MEDIAN second is in the CSV
## as "med <part>" (other programs on the machine make a few seconds slow; the median
## shrugs them off, the average doesn't).
var _win := {}
var _win_n := 0
var _wins: Array = []
var _worst_ms := 0.0
var _worst_zones := ""
var mouse := true                # a moving mouse and a changing selection, as a player has (HUD hover and panels)
var _sel_t := 0.0
var _sel_i := 0
var _mouse_a := 0.0
var match_seed := 4242
var teams := false               # 2v2: the first half of the players against the second
var device := "pc"
var _trace: FileAccess = null
var _trace_next := 0.0
var _cpu0 := 0.0                 # the processor time used when this minute began (ms)
var sound := false               # sounds and music as in a real match (and the path queue's time limit)


## The sounds without the wall clock: every name has no sound, so a play stops before it looks at
## the time or draws a random number (Sfx.play, voice, announce...).
class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []

const MED_ZONES := ["units", "buildings", "game", "game/fog", "ai", "hud", "hud draw", "hud/selection", "overlay draw", "effects"]
## The parts (Prof keys) in the CSV; "a/b" is part of "a" (game/fog is inside game).
const ZONES := ["units", "ai", "game", "game/fog", "game/fog/units", "game/fog/buildings", "game/fog/copy", "game/fog/picture", "game/fog/shown",
	"game/paths", "game/pathfinder", "game/path smoothing", "game/unit grid", "game/refit",
	"buildings", "effects", "projectiles", "unit draw", "building draw", "hud", "hud draw", "overlay draw", "autosave",
	"hud/top", "hud/minimap", "hud/map view", "hud/groups", "hud/selection", "hud/command card", "hud/card build", "hud/glow", "hud/rest", "hud/chat", "hud/tooltip", "hud/pause", "hud/look", "hud/hover", "hud/tip check",
	"ai/workers", "ai/econ", "ai/build", "ai/produce", "ai/raid", "ai/army", "ai/horses", "ai/loose", "ai/abil", "ai/micro", "ai/gg"]


## What Prof counted since the last frame (into _frame and the minute's totals).
func _take_frame() -> void:
	Prof.flush()
	_frame.clear()
	for z in Prof.us:
		var cur := int(Prof.us[z])
		var was := int(_prev.get(z, 0))
		var d := cur - was if cur >= was else cur        # (the match log reset Prof)
		var cc := int(Prof.calls.get(z, 0))
		var wc := int(_prev_calls.get(z, 0))
		_acc_calls[z] = int(_acc_calls.get(z, 0)) + (cc - wc if cc >= wc else cc)
		if d > 0:
			_frame[z] = d
			_acc[z] = int(_acc.get(z, 0)) + d
			_win[z] = int(_win.get(z, 0)) + d
	if Prof.us.size() < _prev.size():
		pass
	_prev = Prof.us.duplicate()
	_prev_calls = Prof.calls.duplicate()


## This frame's parts, slowest first: "game/paths 80.1, ai 12.0, ..."
func _diff_zones() -> String:
	var d: Array = []
	for z in _frame:
		var v := int(_frame[z]) / 1000.0
		if v >= 1.0:
			d.append([v, z])
	d.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return ", ".join(d.map(func(x: Array) -> String: return "%s %.1f" % [x[1], x[0]]))


func _initialize() -> void:
	Settings.load_all()
	for a in OS.get_cmdline_user_args():
		if a == "mobile":
			device = "mobile"
	Settings.device = device
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
		elif a == "nomouse":
			mouse = false
		elif a in ["easy", "normal", "hard", "brutal"]:
			level = a
		elif a.begins_with("seed:"):
			match_seed = int(a.substr(5))
		elif a == "2v2":
			teams = true
		elif a.begins_with("trace:"):
			_trace = FileAccess.open(a.substr(6), FileAccess.WRITE)
		elif a == "sound":
			sound = true
	if facs.size() < 2:
		facs = ["crown", "crown"]
	var render := DisplayServer.get_name() != "headless"
	if out_name == "":
		out_name = "%s_%s_%s" % [map, "_".join(facs), "render" if render else "headless"]
	var slots: Array = []
	for i in facs.size():
		var side := i
		if teams:
			side = 0 if i < facs.size() / 2 else 1
		slots.append({"who": "you" if i == 0 else level, "faction": facs[i], "colour": i, "side": side, "strategy": "balanced"})
	if not sound:
		root.add_child(SilentSfx.new())       # (Sfx.me from now on)
	seed(match_seed)              # (before the match is made: setting it up draws random numbers too)
	main.start({"map": map, "slots": slots, "seed": match_seed})
	var g: Game = main.game
	if not sound:
		g.path_budget_us = 1 << 40
		if Music.me:
			Music.me._faction = ""         # (no music in the match: its pieces end by the wall clock)
	# player 1 is "you", played by a computer
	var ai := AI.new()
	ai.game = g
	ai.team = 0
	ai.difficulty = main.LEVELS.find(level)
	ai.strategy = "balanced"
	g.add_child(ai)
	g.ais.append(ai)
	_cfg_text = "%s, %s, %s AI, %s, Godot %s, %s, %s profile, seed %d, v%s" % [map, " vs ".join(facs), level, "rendered %s" % RenderingServer.get_video_adapter_name() if render else "headless",
		Engine.get_version_info()["string"], "%d physics ticks a second" % Engine.get_physics_ticks_per_second(), device, match_seed,
		ProjectSettings.get_setting("application/config/version", "dev")]
	print("PERF start: ", _cfg_text)
	seed(match_seed)
	_cpu0 = _cpu_ms()
	_prev = Prof.us.duplicate()
	_prev_calls = Prof.calls.duplicate()
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
	_take_frame()
	# what the slow frames spent their time on (zones are added up, so take the difference)
	_win_n += 1
	if _win_n >= 60:
		_wins.append(_win)
		_win = {}
		_win_n = 0
	if ms > _worst_ms:
		_worst_ms = ms
		_worst_zones = _diff_zones()
	if ms > 100.0:
		print("PERF spike %.0f ms at %d:%02d: %s" % [ms, int(g.clock) / 60, int(g.clock) % 60, _diff_zones()])
	if mouse:
		_player(g, delta)
	_cam_t -= delta
	if _cam_t <= 0.0:
		_cam_t = 1.0
		_aim_camera(g)
	if _trace != null and g.clock >= _trace_next:
		_trace_next += 5.0
		_trace_state(g)
	if int(g.clock / 60.0) > _minute or g.over or g.clock > stop_at:
		_minute_row(g)
		_minute = int(g.clock / 60.0)
	if g.over or g.clock > stop_at:
		_save()
		if _trace != null:
			_trace.close()
		return true
	return false


## The processor time this program has used so far, in ms (Linux: /proc/self/stat, user + system;
## -1 where there's no /proc).
func _cpu_ms() -> float:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)
	if f == null:
		return -1.0
	var s := f.get_line()
	var rest := s.substr(s.rfind(")") + 2).split(" ")
	if rest.size() < 13:
		return -1.0
	return (float(rest[11]) + float(rest[12])) * 1000.0 / 100.0      # (clock ticks, 100 a second)


## The whole state of the match, as text: the clock, everyone's resources and supply, every
## unit (kind, side, place, health, order) and building. The same match must give the same lines.
func _trace_state(g: Game) -> void:
	var out := PackedStringArray()
	out.append("T %.4f units %d buildings %d" % [g.clock, g.units.size(), g.buildings.size()])
	for t in g.n_players():
		var p: Dictionary = g.players[t]
		out.append("P%d gold %d res2 %d cap %d supply %d" % [t, int(p["gold"]), int(p["res2"]), int(p["cap"]), g.supply_used(t)])
	for u in g.units:
		if not is_instance_valid(u):
			out.append("U freed")
			continue
		out.append("U %s %d %.3f %.3f %.2f %s %d" % [u.kind, u.team, u.position.x, u.position.y, u.hp, u.order, int(u.dead)])
	for b in g.buildings:
		if not is_instance_valid(b):
			out.append("B freed")
			continue
		out.append("B %s %d %d %d %.2f %d %d" % [b.kind, b.team, b.cell.x, b.cell.y, b.hp, int(b.built), int(b.dead)])
	_trace.store_string("\n".join(out) + "\n")


## A player's hand: the mouse wanders over the screen (map, minimap, command card) and the
## selection changes every few seconds (army, hall, workers, a production building, nothing).
func _player(g: Game, delta: float) -> void:
	_mouse_a += delta * 0.9
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var mm := InputEventMouseMotion.new()
	mm.position = vs * 0.5 + Vector2(cos(_mouse_a) * vs.x * 0.42, sin(_mouse_a * 1.3) * vs.y * 0.42)
	mm.global_position = mm.position
	Input.parse_input_event(mm)
	_sel_t -= delta
	if _sel_t > 0.0:
		return
	_sel_t = 6.0
	_sel_i += 1
	var pick: Array = []
	match _sel_i % 5:
		0:
			pick = g.army(0)
		1:
			pick = g.halls_of(0, false).slice(0, 1)
		2:
			pick = g.labourers(0).slice(0, 6)
		3:
			pick = g.producers(0).slice(0, 1)
	g.set_selection(pick)


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
		"n_units": units, "n_buildings": g.buildings.size(), "n_bodies": g.bodies.size(), "n_effects": counts["effects"],
		"n_projectiles": counts["projectiles"], "floats": g._floats.size(), "pings": g._pings.size(),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"mem_mb": OS.get_static_memory_usage() / 1048576.0, "log_lines": g.mlog.lines.size() if g.mlog else 0,
		"wall_s": (Time.get_ticks_msec() - _wall0) / 1000.0}
	var cpu := _cpu_ms()
	row["cpu_s"] = (cpu - _cpu0) / 1000.0 if cpu >= 0.0 else -1.0
	_cpu0 = cpu
	for z in ZONES:
		row[z] = float(_acc.get(z, 0)) / 1000.0 / arr.size()      # ms a frame
	row["paths"] = int(_acc_calls.get("game/pathfinder", 0))
	for z in MED_ZONES:
		var vals: Array = _wins.map(func(w: Dictionary) -> float: return float(w.get(z, 0)) / 1000.0 / 60.0)
		vals.sort()
		row["med " + z] = float(vals[vals.size() / 2]) if not vals.is_empty() else 0.0
	_wins.clear()
	row["worst_frame_zones"] = "\"%s\"" % _worst_zones
	_acc.clear()
	_acc_calls.clear()
	_rows.append(row)
	var zs := PackedStringArray()
	for z in ZONES:
		zs.append("%s %.2f" % [z, row[z]])
	print("PERF worst frame %.0f ms: %s" % [_worst_ms, _worst_zones])
	_worst_ms = 0.0
	print("PERF min %2d | %5.1f fps avg, 1%% low %5.1f, worst %6.1f ms, >33ms %4d, >50ms %4d | cpu %.1f s | paths %d | units %d bodies %d fx %d proj %d nodes %d objs %d | ms/frame: %s" % [
		row["min"], row["fps"], row["low1_fps"], row["worst_ms"], over33, over50, row["cpu_s"], row["paths"], units, row["n_bodies"], row["n_effects"], row["n_projectiles"],
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
			r["over33"], r["over50"], r["n_units"], r["n_bodies"], r["n_effects"], r["nodes"], r["units"], r["ai"], r["game"], r["game/fog"], r["unit draw"], r["hud draw"]])
	f = FileAccess.open("res://docs/perf/%s.md" % out_name, FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	f.close()
	print("PERF saved docs/perf/%s.csv" % out_name)
