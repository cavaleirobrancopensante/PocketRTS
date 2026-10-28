extends SceneTree
## The swarm stress test (docs/swarm_perf.md): huge armies on an open map, every frame's real time measured,
## split by the Prof parts (scripts/prof.gd) as tools/perf_bench.gd does.
##
##   godot --headless --fixed-fps 60 --script res://tools/stress_swarm.gd -- <scenario> [n:200] [secs:30] [map:dune_sea]
##       [mobile] [sound] [spikes] [trace:/abs/file.txt] [out:/abs/file.json] [shot:/abs/file.png] [linger:s]
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 60 --script res://tools/stress_swarm.gd -- melee
##   tools/stress_swarm.sh <outdir> [render] [mobile] [secs:30] [scenarios...]     (all of them, and a table)
##
## Scenarios (n = Raptors a side, 200 by default: a full 200-supply army of them):
##   idle     n Raptors a side standing in their bases (the camera on side 1's)
##   walk     both armies walking across the map to the other base, through each other (move orders, no fighting)
##   melee    the two armies meeting in one big melee in front of the camera (attack-move at each other)
##   offmelee the same melee with the camera far away (nothing of it drawn)
##   grubs    n Grubs + n/2 Raptors a side, the same melee in view
##   muskets  n/2 Musketeers a side (Crown) trading fire in view, the powder smoke as set (THICK by default)
## Side 1's army is selected (its rings, bars and the command card, as a player has them). The armies are made in
## one tick, but their men's timers are spread as an army made over minutes has them.
## --fixed-fps 60: every frame moves the game on 1/60 s whatever it costs, so the frame times are what a frame
## really costs (the game logic runs 30 ticks a second: every other frame). A frame is timed from the start of one
## turn of the engine's loop to the next (_turn). Headless measures the game's side (simulation + the GDScript that
## builds the drawing); rendered adds the drawing itself (on xvfb that is llvmpipe, a software renderer: far slower
## than any graphics card). "the battle" = the frames while both sides still have a tenth of their army.
## trace:FILE writes the whole state every game second (two runs must match: the work must not change the game).
## The sounds are kept silent, the computers off, the music off and the path queue's time limit lifted unless
## "sound" is given (as perf_bench: then a run plays out the same every time). spikes: every frame over 35 ms
## printed with its parts. linger:s keeps running s seconds after the report (tools/gd_script_profiler.py).

var main: Node
var g: Game
var t := 0.0
var begun := false
var started := false
var scen := "melee"
var n := 200
var secs := 30.0
var map := "dune_sea"
var device := "pc"
var sound := false
var out_path := ""
var shot_path := ""
var _trace: FileAccess = null
var _trace_next := 0.0
var _measuring := false
var _game_t := 0.0
var _last_us := 0
var _frames := PackedFloat32Array()
var _ticks := 0
var _prev := {}
var _acc := {}
var _worst_ms := 0.0
var _worst_zones := ""
var _frame := {}
var _cpu0 := 0.0
var _wall0 := 0
var _draw_calls := 0
var _rend_cpu := 0.0
var _rend_gpu := 0.0
var _rend_n := 0
var _cam_at := Vector2.ZERO
var _fight_cam := false
var sides: Array = [[], []]
var _vp_rid: RID
var _fight := PackedFloat32Array()  # the frames while both sides still have a tenth of their army: the battle itself
var _in_fight := false
var linger := 0.0                # (seconds to keep running after the report: tools/gd_script_profiler.py gets its totals late)
var _done := false
var _zmax := {}                  # the most each part took in one frame
var spikes := false              # ("spikes": every frame over 50 ms printed, with what it spent its time on)

const ZONES := ["units", "buildings", "game", "game/unit grid", "game/paths", "game/pathfinder", "game/path smoothing", "game/fog",
	"effects", "projectiles", "unit draw", "building draw", "overlay draw", "hud", "hud draw", "hud/minimap", "hud/selection", "ai", "smoke"]


class SilentSfx extends Sfx:
	func _find(_name: String) -> Array:
		return []


func _initialize() -> void:
	Settings.load_all()
	for a in OS.get_cmdline_user_args():
		if a in ["idle", "walk", "melee", "offmelee", "grubs", "muskets"]:
			scen = a
		elif a.begins_with("n:"):
			n = int(a.substr(2))
		elif a.begins_with("secs:"):
			secs = float(a.substr(5))
		elif a.begins_with("map:"):
			map = a.substr(4)
		elif a == "mobile":
			device = "mobile"
		elif a == "sound":
			sound = true
		elif a == "spikes":
			spikes = true
		elif a.begins_with("trace:"):
			_trace = FileAccess.open(a.substr(6), FileAccess.WRITE)
		elif a.begins_with("out:"):
			out_path = a.substr(4)
		elif a.begins_with("linger:"):
			linger = float(a.substr(7))
		elif a.begins_with("shot:"):
			shot_path = a.substr(5)
	Settings.device = device
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


## A frame is one turn of the engine's loop: its game ticks (none or one at 60 frames a second), then everything's
## _process, then the drawing. The loop calls this script's _physics_process first in each tick and its _process
## first in each frame's processing, so a frame starts at the first of them in the turn (_turn): the time from one
## start to the next is what that frame cost, with the parts it spent it on.
var _ticked := false


func _physics_process(_delta: float) -> bool:
	if not _ticked:
		_ticked = true
		_turn()
	return false


func _turn() -> void:
	var now := Time.get_ticks_usec()
	if not _measuring or _done or g == null:
		_last_us = now
		return
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	_frames.append(ms)
	if _in_fight:
		_fight.append(ms)
	_take_frame()
	if _frame.has("units"):
		_ticks += 1
	for z in _frame:
		if int(_frame[z]) > int(_zmax.get(z, 0)):
			_zmax[z] = int(_frame[z])
	if ms > 35.0 and spikes:
		print("SWARM spike %.0f ms at %.2f s: %s" % [ms, g.clock, _zones_text(_frame)])
	if ms > _worst_ms:
		_worst_ms = ms
		_worst_zones = _zones_text(_frame)
	_draw_calls += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _vp_rid.is_valid():
		_rend_cpu += RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid)
		_rend_gpu += RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
		_rend_n += 1


func _process(delta: float) -> bool:
	if not _ticked:
		_turn()
	_ticked = false
	var now := Time.get_ticks_usec()
	t += delta
	if not begun:
		if t > 0.2:
			begun = true
			var fac := "crown" if scen == "muskets" else "brood"
			if not sound:
				root.add_child(SilentSfx.new())
			seed(4242)
			main.start({"map": map, "seed": 4242, "slots": [
				{"who": "you", "faction": fac, "colour": 0, "side": 0},
				{"who": "easy", "faction": fac, "colour": 1, "side": 1}]})
			# (at once, as perf_bench does: the computers off, no music, no time limit on the path queue,
			# so nothing goes by the wall clock and every run plays out the same)
			var g0: Game = main.game
			if g0:
				for ai in g0.ais:
					ai.process_mode = Node.PROCESS_MODE_DISABLED
				if not sound:
					g0.path_budget_us = 1 << 40
					if Music.me:
						Music.me._faction = ""
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started:
		if t > 1.0:
			started = true
			_setup()
			_last_us = Time.get_ticks_usec()
		return false
	_game_t += 1.0 / 60.0
	if _measuring and int(_game_t * 60.0) % 15 == 0:
		_in_fight = _alive(0) >= sides[0].size() / 10 and _alive(1) >= sides[1].size() / 10 and scen != "idle" and scen != "walk"
	if _done:
		linger -= 1.0 / 60.0
		return linger <= 0.0
	if _trace != null and g.clock >= _trace_next:
		_trace_next += 1.0
		_trace_state()
	if _fight_cam:
		_follow_fight()
	if not _measuring:
		if _game_t >= 0.5:
			_measuring = true
			_take_frame()
			_acc.clear()
			_cpu0 = _cpu_ms()
			_wall0 = Time.get_ticks_msec()
			_last_us = now
			print("SWARM measuring")
		return false
	if _game_t >= secs + 0.5:
		_report()
		if _trace != null:
			_trace.close()
		if shot_path != "":
			root.get_viewport().get_texture().get_image().save_png(shot_path)
		_done = true
		return linger <= 0.0
	return false


# ------------------------------------------------------------------ the armies

func _hall(team: int) -> Building:
	for b in g.buildings:
		if b.team == team and not b.dead and b.kind in ["hive", "town_hall", "clocktower"]:
			return b
	return null


## Spots for k units round p on p's level, `sp` px apart (a filled blob).
func _spots(p: Vector2, k: int, sp: float) -> Array:
	var out: Array = []
	var c0: Vector2i = g.cell_of(p)
	var lv := int(g.height[g.idx(c0)])
	var r := 0
	while out.size() < k and r < 60:
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var q := p + Vector2(x, y) * sp
				var c: Vector2i = g.cell_of(q)
				if g.in_map(c) and g.is_free(c) and g.ramp[g.idx(c)] == 0 and int(g.height[g.idx(c)]) == lv and g._clear_at(q, 10.0, 0):
					out.append(q)
					if out.size() >= k:
						return out
		r += 1
	return out


func _army(team: int, at: Vector2, set: Array) -> Array:
	var total := 0
	for s in set:
		total += int(s[1])
	var sp := 18.0 if set[0][0] != "musketeer" else 24.0
	var spots := _spots(at, total, sp)
	var out: Array = []
	var i := 0
	for s in set:
		for k in int(s[1]):
			if i >= spots.size():
				break
			var u: Unit = g._add_unit(s[0], team, spots[i])
			u.auto_work = false
			# (an army made over minutes: its men don't all shove, or look round for a target, on the same tick)
			u._sep_n = i % 3
			u.scan_t = float(i % 10) / 30.0
			i += 1
			out.append(u)
	return out


## A point on open level ground near `p` (the first cell with a 9x9 clear square on one level).
func _open_near(p: Vector2) -> Vector2:
	var c0: Vector2i = g.cell_of(p)
	for r in 40:
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r:
					continue
				var c := c0 + Vector2i(x, y)
				if _open(c, 4):
					return g.cell_center(c)
	return p


func _open(c: Vector2i, r: int) -> bool:
	if not g.in_map(c):
		return false
	var lv := int(g.height[g.idx(c)])
	for yy in range(-r, r + 1):
		for xx in range(-r, r + 1):
			var cc := c + Vector2i(xx, yy)
			if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or int(g.height[g.idx(cc)]) != lv or g.solid[g.idx(cc)] != 0:
				return false
	return true


func _setup() -> void:
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	if not sound:
		g.path_budget_us = 1 << 40
		if Music.me:
			Music.me._faction = ""
	seed(4242)
	var h0 := _hall(0)
	var h1 := _hall(1)
	var mid := (h0.center() + h1.center()) * 0.5
	var dir := (h1.center() - h0.center()).normalized()
	var set: Array = [["raptor", n]]
	if scen == "grubs":
		set = [["grub", n], ["raptor", n / 2]]
	elif scen == "muskets":
		set = [["musketeer", n / 2]]
	var p0: Vector2
	var p1: Vector2
	if scen in ["idle", "walk"]:
		p0 = _open_near(h0.center() + dir * 320.0)
		p1 = _open_near(h1.center() - dir * 320.0)
	else:
		var gap := 420.0 if scen == "muskets" else 360.0
		var m := _open_near(mid)
		p0 = _open_near(m - dir * gap)
		p1 = _open_near(m + dir * gap)
	sides[0] = _army(0, p0, set)
	sides[1] = _army(1, p1, set)
	_vp_rid = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	match scen:
		"idle":
			_cam_at = p0
		"walk":
			g.group_move(sides[0], p1, false)
			g.group_move(sides[1], p0, false)
			_fight_cam = true
		"melee", "grubs", "muskets":
			g.group_move(sides[0], p1, true)
			g.group_move(sides[1], p0, true)
			_cam_at = (p0 + p1) * 0.5
			_fight_cam = true
		"offmelee":
			g.group_move(sides[0], p1, true)
			g.group_move(sides[1], p0, true)
			# the camera on the far side of side 1's base, looking at nothing
			_cam_at = g.on_map(h0.center() - dir * 600.0)
	g.camera.position = _cam_at
	g.set_selection(sides[0])          # (a player has his army selected: rings and health bars)
	print("SWARM setup %s: %d + %d units at %s / %s, map %s (%dx%d), %s, v%s" % [scen, sides[0].size(), sides[1].size(), p0, p1, map, Game.W, Game.H,
		"rendered %s" % RenderingServer.get_video_adapter_name() if DisplayServer.get_name() != "headless" else "headless",
		ProjectSettings.get_setting("application/config/version", "dev")])


## The camera on the middle of side 0's army that is still standing (or where it fights).
func _follow_fight() -> void:
	if int(_game_t * 60.0) % 30 != 0:
		return
	var c := Vector2.ZERO
	var k := 0
	for u in sides[0]:
		if is_instance_valid(u) and not u.dead:
			c += u.position
			k += 1
	if k > 0:
		g.camera.position = c / k


# ------------------------------------------------------------------ measuring

func _take_frame() -> void:
	Prof.flush()
	_frame.clear()
	for z in Prof.us:
		var cur := int(Prof.us[z])
		var was := int(_prev.get(z, 0))
		var d := cur - was if cur >= was else cur
		if d > 0:
			_frame[z] = d
			_acc[z] = int(_acc.get(z, 0)) + d
	if g and g.powder_smoke:
		var su: int = g.powder_smoke.tick_us
		var d2 := su - int(_prev.get("smoke", 0))
		if d2 > 0:
			_frame["smoke"] = d2
			_acc["smoke"] = int(_acc.get("smoke", 0)) + d2
	_prev = Prof.us.duplicate()
	if g and g.powder_smoke:
		_prev["smoke"] = g.powder_smoke.tick_us


func _zones_text(fr: Dictionary) -> String:
	var d: Array = []
	for z in fr:
		var v := int(fr[z]) / 1000.0
		if v >= 0.5:
			d.append([v, z])
	d.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return ", ".join(d.map(func(x: Array) -> String: return "%s %.1f" % [x[1], x[0]]))


func _cpu_ms() -> float:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)
	if f == null:
		return -1.0
	var s := f.get_line()
	var rest := s.substr(s.rfind(")") + 2).split(" ")
	if rest.size() < 13:
		return -1.0
	return (float(rest[11]) + float(rest[12])) * 1000.0 / 100.0


func _alive(s: int) -> int:
	var k := 0
	for u in sides[s]:
		if is_instance_valid(u) and not u.dead:
			k += 1
	return k


## [avg ms, 1% low ms, worst ms, frames] of a list of frame times.
func _stats(fr: PackedFloat32Array) -> Array:
	if fr.is_empty():
		return [0.0, 0.0, 0.0, 0]
	var a := fr.duplicate()
	a.sort()
	var tot := 0.0
	for f in a:
		tot += f
	var k := maxi(1, a.size() / 100)
	var slow := 0.0
	for i in k:
		slow += a[a.size() - 1 - i]
	return [tot / a.size(), slow / k, a[a.size() - 1], a.size()]


func _report() -> void:
	var arr := _frames.duplicate()
	arr.sort()
	var tot := 0.0
	var o16 := 0
	var o33 := 0
	for f in arr:
		tot += f
		if f > 16.7:
			o16 += 1
		if f > 33.3:
			o33 += 1
	var nf := arr.size()
	var avg := tot / nf
	var k := maxi(1, nf / 100)
	var slow := 0.0
	for i in k:
		slow += arr[nf - 1 - i]
	slow /= k
	var alive := [0, 0]
	for s in 2:
		for u in sides[s]:
			if is_instance_valid(u) and not u.dead:
				alive[s] += 1
	var cpu := _cpu_ms()
	var row := {"scenario": scen, "n": n, "device": device, "map": map, "rendered": DisplayServer.get_name() != "headless",
		"frames": nf, "avg_ms": avg, "fps": 1000.0 / avg, "median_ms": arr[nf / 2], "low1_ms": slow, "low1_fps": 1000.0 / slow,
		"worst_ms": arr[nf - 1], "over16": o16, "over33": o33, "ticks": _ticks,
		"cpu_s": (cpu - _cpu0) / 1000.0, "wall_s": (Time.get_ticks_msec() - _wall0) / 1000.0,
		"draw_calls": float(_draw_calls) / nf, "render_cpu_ms": _rend_cpu / maxf(_rend_n, 1), "render_gpu_ms": _rend_gpu / maxf(_rend_n, 1),
		"fight_frames": _stats(_fight)[3], "fight_avg_ms": _stats(_fight)[0], "fight_low1_ms": _stats(_fight)[1], "fight_worst_ms": _stats(_fight)[2],
		"alive0": alive[0], "alive1": alive[1], "units_total": g.units.size(), "worst_zones": _worst_zones}
	var zs := PackedStringArray()
	var per_tick := PackedStringArray()
	var all_z: Array = ZONES.duplicate()
	for z in _acc:
		# (parts timed for a look inside, Prof.add("z/..."), while hunting a cost: printed too)
		if not all_z.has(z) and (String(z).begins_with("u/") or String(z).begins_with("z/")):
			all_z.append(z)
	for z in all_z:
		var v := float(_acc.get(z, 0)) / 1000.0
		row["ms/frame " + z] = v / nf
		row["ms/tick " + z] = v / maxf(_ticks, 1)
		if v / nf >= 0.01:
			zs.append("%s %.2f" % [z, v / nf])
			per_tick.append("%s %.2f" % [z, v / maxf(_ticks, 1)])
	var sim := 0.0
	for z in ["units", "buildings", "game", "effects", "projectiles", "ai"]:
		sim += float(_acc.get(z, 0)) / 1000.0
	row["sim_ms_per_tick"] = sim / maxf(_ticks, 1)
	print("SWARM %s n=%d %s %s | %.1f fps avg (%.2f ms), median %.2f ms, 1%% low %.1f fps (%.1f ms), worst %.1f ms (%s) | >16.7ms %d, >33ms %d of %d | sim %.2f ms a tick | cpu %.1f s for %.0f s of play | draw calls %.0f, render cpu %.2f gpu %.2f ms | alive %d v %d" % [
		scen, n, device, "rendered" if row["rendered"] else "headless", row["fps"], avg, row["median_ms"], row["low1_fps"], slow, row["worst_ms"], _worst_zones,
		o16, o33, nf, row["sim_ms_per_tick"], row["cpu_s"], secs, row["draw_calls"], row["render_cpu_ms"], row["render_gpu_ms"], alive[0], alive[1]])
	if not _fight.is_empty():
		var fs := _stats(_fight)
		print("SWARM the battle (%d frames, %.1f s): %.1f fps avg (%.2f ms), 1%% low %.1f fps (%.1f ms), worst %.1f ms" % [fs[3], fs[3] / 60.0, 1000.0 / fs[0], fs[0], 1000.0 / fs[1], fs[1], fs[2]])
	if g.get("grid_drift_max") != null:
		row["grid_drift_max"] = g.get("grid_drift_max")
		row["grid_drift_over"] = g.get("grid_drift_over")
		print("SWARM grid drift: the most a unit moved in a tick %.1f px; moved more than the grid allows without noticing: %d times" % [g.get("grid_drift_max"), g.get("grid_drift_over")])
	var zm: Array = []
	for z in _zmax:
		if int(_zmax[z]) >= 2000 and not String(z).contains("/") or String(z) in ["hud/card build", "hud/look", "game/fog", "game/paths"]:
			zm.append([int(_zmax[z]) / 1000.0, z])
	zm.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("SWARM the most in one frame (ms): ", ", ".join(zm.map(func(x: Array) -> String: return "%s %.1f" % [x[1], x[0]])))
	row["frame_max"] = {}
	for x in zm:
		row["frame_max"][x[1]] = x[0]
	var rec = g.find_child("ReplayRecorder", true, false)
	if rec == null:
		rec = root.find_child("ReplayRecorder", true, false)
	if rec != null and int(rec.n_frames) > 0:
		print("SWARM replay recorder: %d pictures, %.2f ms each (snapshot %.2f, compact %.2f), %d keyframes" % [rec.n_frames, rec.cost_us / 1000.0 / rec.n_frames,
			rec.build_us / 1000.0 / rec.n_frames, rec.compact_us / 1000.0 / rec.n_frames, rec.n_keys])
	var cb_n := int(Prof.calls.get("hud/card build", 0))
	if cb_n > 0:
		print("SWARM command card: built %d times, %.2f ms each on average" % [cb_n, float(Prof.us.get("hud/card build", 0)) / 1000.0 / cb_n])
	print("SWARM ms a frame: ", ", ".join(zs))
	print("SWARM ms a tick:  ", ", ".join(per_tick))
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(row, "  "))
		f.close()


func _trace_state() -> void:
	var out := PackedStringArray()
	out.append("T %.4f units %d buildings %d" % [g.clock, g.units.size(), g.buildings.size()])
	for u in g.units:
		if not is_instance_valid(u):
			out.append("U freed")
			continue
		out.append("U %s %d %.3f %.3f %.2f %s %d" % [u.kind, u.team, u.position.x, u.position.y, u.hp, u.order, int(u.dead)])
	for b in g.buildings:
		if not is_instance_valid(b):
			out.append("B freed")
			continue
		out.append("B %s %d %.2f %d" % [b.kind, b.team, b.hp, int(b.dead)])
	_trace.store_string("\n".join(out) + "\n")
