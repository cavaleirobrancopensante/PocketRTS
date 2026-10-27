extends SceneTree
## Film a computer-against-computer match: screenshots of the fights as they happen and of each side's base at set
## times, plus the match log. For looking closely at a few games (2026-10-27, Crown v Clockwork).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 --script res://tools/shot_ai_match.gd -- \
##       a:crown b:clockwork map:greenhold seed:11 swap:0 out:/abs/dir [end:1800] [da:hard db:normal]
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
var norepair := false        # norepair:1 the walls and gates are never repaired (repair orders cancelled, autocast off)
var noretreat := false       # noretreat:1 a computer's siege is never called off (AI.siege_no_retreat)
var da := "hard"             # da:/db: the computers' difficulty (easy, normal, hard, brutal) for a: and b:
var db := "hard"
var minwave := 0             # minwave:N only a siege by a wave of at least N units is watched (the flags start with it)
var siege_end := false       # siege_end:1 stop once the first siege has played out, writing siege.txt
var _siege_t0 := -1.0
var _siege_next := 0.0
var _siege_wave: Array = []
var _siege_def: Array = []
var _siege_def_w := 0
var _siege_piece: Building = null
var _siege_breach := -1.0
var _siege_cancel := 0
var _siege_team := -1
var _siege_lines: Array = []
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
			"norepair": norepair = kv[1] == "1"
			"noretreat": noretreat = kv[1] == "1"
			"siege_end": siege_end = kv[1] == "1"
			"minwave": minwave = int(kv[1])
			"da": da = kv[1]
			"db": db = kv[1]
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
		var whos := [db, da] if swap else [da, db]
		var slots: Array = []
		for i in 2:
			slots.append({"who": whos[i], "faction": facs[i], "colour": i, "side": i, "strategy": "balanced"})
		main.start({"map": map, "seed": seed_, "slots": slots})
		return false
	if main.game == null:
		return false
	g = main.game
	g.path_budget_us = 1 << 40        # (no time limit on the path queue: the same match every run, like tools/perf_bench.gd)
	if not g.gear_net.draw.is_connected(_count_draw):
		g.gear_net.draw.connect(_count_draw)
	if g.hud:
		g.hud.visible = false
	if g.spectator and g.spectator.process_mode != Node.PROCESS_MODE_DISABLED:
		g.spectator.process_mode = Node.PROCESS_MODE_DISABLED     # (the director camera would move it off the shot)
	if g.controls and g.controls.process_mode != Node.PROCESS_MODE_DISABLED:
		g.controls.process_mode = Node.PROCESS_MODE_DISABLED       # (the mouse sits in a corner under xvfb: edge scrolling)
	_siege_watch()
	if noretreat and _siege_t0 >= 0.0:
		for a in g.ais:
			a.siege_no_retreat = true
	if norepair and _siege_t0 >= 0.0:
		for u in g.units:
			if is_instance_valid(u) and not u.dead and u.is_worker():
				u.auto_repair = false
				if u.order == "repair" and is_instance_valid(u.order_target) and u.order_target is Building:
					u.cmd_stop()
					_siege_cancel += 1
	if siege_end and _siege_t0 >= 0.0 and _siege_over():
		_siege_report()
		_finish()
		return true
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
	_event_shots(c)
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
		_ai_line(c, tm)


## Every 30 s, the Clockwork computer's tech and army (written to <out>/ai.txt): cogs, Tension (and what the Mainsprings
## store), its Works (how many may make Jacks, and why the first one may not), the Escapement, the army by kind, the wave.
var ai_lines: Array = []
var nets_seen := {}          # Netter id -> nets fired (the last count seen)
var jumps_seen := {}         # Jack id -> jumps


func _ai_line(c: float, tm: int) -> void:
	var works := 0
	var jack_works := 0
	var why_not := ""
	var esc := "none"
	var queues: Array = []
	var springs := 0
	var store := 0.0
	var army := {}
	for b in g.buildings:
		if b.dead or b.team != tm:
			continue
		if b.kind == Defs.CW_WORKS:
			works += 1
			queues.append("%s%s" % [str(b.queue.size()), ("/" + g.can_train(b, "clock_soldier").left(24)) if b.built and g.can_train(b, "clock_soldier") != "" else ""])
			if b.built:
				var w: String = g.can_train(b, Defs.JACK)
				if w == "" or w.begins_with("Not enough") or w.begins_with("Need more") or w.begins_with("Supply"):
					jack_works += 1
				elif why_not == "":
					why_not = w.left(70)
		elif b.kind == Defs.CW_TECH:
			esc = ("working" if g.has_working(tm, Defs.CW_TECH) else "idle") if b.built else "building"
		elif b.kind == "mainspring":
			springs += 1
	for u in g.units:
		if is_instance_valid(u) and not u.dead and u.team == tm and not u.is_worker():
			army[u.kind] = int(army.get(u.kind, 0)) + 1
			if u.kind == Defs.NETTER:
				nets_seen[u.get_instance_id()] = u.nets
			elif u.kind == Defs.JACK:
				jumps_seen[u.get_instance_id()] = u.jumps
	var nets := 0
	for k in nets_seen:
		nets += int(nets_seen[k])
	var jumps := 0
	for k in jumps_seen:
		jumps += int(jumps_seen[k])
	var ai = null
	for a in g.ais:
		if a.team == tm:
			ai = a
	ai_lines.append("%s cogs %d tension %d | works %d (jacks at %d%s) q %s springs %d escapement %s | army %s | nets %d jumps %d | attacking %s siege %s reserve %d" % [_mmss(c),
		int(g.players[tm]["gold"]), int(g.tension(tm)), works, jack_works, (": " + why_not.left(30)) if why_not != "" else "", str(queues), springs, esc, str(army), nets, jumps,
		str(ai._attacking) if ai else "-", ("on" if ai and not ai._siege.is_empty() else "-"), ai._reserve if ai else 0])


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


## The first siege: who was in the wave and the defence when it began, the piece, when it fell.
func _siege_watch() -> void:
	for a in g.ais:
		var sg = a.get("_siege")
		if _siege_t0 < 0.0 and sg is Dictionary and not sg.is_empty() and is_instance_valid(sg.get("piece")) \
				and a._wave_set.keys().filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).size() >= minwave:
			_siege_t0 = g.clock
			_siege_team = a.team
			_siege_piece = sg["piece"]
			for u in a._wave_set.keys():
				if is_instance_valid(u) and not u.dead:
					_siege_wave.append(u)
			for u in g.units:
				if is_instance_valid(u) and not u.dead and u.team != a.team and u.team >= 0:
					if u.is_worker():
						_siege_def_w += 1
					else:
						_siege_def.append(u)
			_siege_lines.append("%s siege begins: team %d's wave of %d (%s) at the %s (%d hp) at %s; defenders %d soldiers (%s), %d workers" % [_mmss(g.clock), a.team, _siege_wave.size(), _kinds(_siege_wave), _siege_piece.kind, int(_siege_piece.hp), str(_siege_piece.center()), _siege_def.size(), _kinds(_siege_def), _siege_def_w])
	if _siege_t0 >= 0.0 and _siege_breach < 0.0 and g.clock >= _siege_next:
		_siege_next = g.clock + 3.0
		var at_face := 0
		var hitting := 0
		for u in _siege_wave:
			if is_instance_valid(u) and not u.dead and is_instance_valid(_siege_piece):
				if _siege_piece.edge_distance(u.position) < 30.0:
					at_face += 1
				if u.target == _siege_piece and u.phase != "":
					hitting += 1
		var defn := 0
		for u in _siege_def:
			if is_instance_valid(u) and not u.dead and is_instance_valid(_siege_piece) and u.position.distance_to(_siege_piece.center()) < 300.0:
				defn += 1
		_siege_lines.append("  %s +%ds: gate %d hp, wave alive %d, at the gate %d, swinging %d, defenders within 300 px %d" % [_mmss(g.clock), int(g.clock - _siege_t0), int(_siege_piece.hp) if is_instance_valid(_siege_piece) and not _siege_piece.dead else 0, _alive(_siege_wave), at_face, hitting, defn])
	if _siege_t0 >= 0.0 and _siege_breach < 0.0 and (not is_instance_valid(_siege_piece) or _siege_piece.dead):
		_siege_breach = g.clock
		_siege_lines.append("%s the %s falls (%d s after the start); wave alive %d, defenders alive %d" % [_mmss(g.clock), "gate", int(g.clock - _siege_t0), _alive(_siege_wave), _alive(_siege_def)])


func _alive(list: Array) -> int:
	return list.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead).size()


func _kinds(list: Array) -> String:
	var n := {}
	for u in list:
		if is_instance_valid(u):
			n[u.kind] = int(n.get(u.kind, 0)) + 1
	var out: Array = []
	for k in n:
		out.append("%d %s" % [n[k], k])
	return ", ".join(out)


## Over: the wave is (almost) gone, or the attacker stopped attacking, or 5 minutes.
func _siege_over() -> bool:
	if g.over or g.clock - _siege_t0 > 300.0:
		return true
	var a = null
	for x in g.ais:
		if x.team == _siege_team:
			a = x
	return _alive(_siege_wave) <= 2 or (a != null and not a._attacking and g.clock - _siege_t0 > 20.0)


func _siege_report() -> void:
	var dead_b: Array = []
	for l in g.mlog.lines:
		var t := str(l)
		if t.contains(" lost a ") and t.contains("to P%d" % (_siege_team + 1)):
			dead_b.append(t)
	_siege_lines.append("%s over (%d s): wave alive %d of %d (%s); defenders alive %d of %d; defender workers now %d; attacker still attacking %s; repairs cancelled %d; defender repair spend %d" % [_mmss(g.clock), int(g.clock - _siege_t0), _alive(_siege_wave), _siege_wave.size(), _kinds(_siege_wave.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)), _alive(_siege_def), _siege_def.size(), g.workers(1 - _siege_team).size(), str(g.ais.filter(func(x) -> bool: return x.team == _siege_team)[0]._attacking), _siege_cancel, int(float(g.stats[1 - _siege_team].get("repair", 0.0)))])
	_siege_lines.append("buildings the attacker destroyed during the game: %d" % dead_b.size())
	for t in dead_b:
		_siege_lines.append("  " + t)
	var f := FileAccess.open(out.path_join("siege.txt"), FileAccess.WRITE)
	for l in _siege_lines:
		f.store_line(l)
	f.close()


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


## A Clockwork computer's moments worth a picture (leap_<MMSS>.png: Jacks leaping up, a second after they set off;
## siege_<MMSS>.png: a siege begun, 8 s on), at most one of each kind every 20 s.
var _leap_n := {}
var _siege_on := {}
var _later: Array = []        # [clock, file, at]
var _event_t := {}


func _event_shots(c: float) -> void:
	for a in g.ais:
		var lp = a.get("_leapt")
		if lp is Dictionary:
			var n: int = lp.size()
			if n > int(_leap_n.get(a.team, 0)) and c - float(_event_t.get("leap", -99.0)) > 20.0:
				for u in lp.keys():
					if is_instance_valid(u) and not u.dead:
						_later.append([c + 1.0, "leap_%s.png" % _mmss(c), u])
						_event_t["leap"] = c
						break
			_leap_n[a.team] = n
		var sg = a.get("_siege")
		var on: bool = sg is Dictionary and not sg.is_empty() and is_instance_valid(sg.get("piece"))
		if on and not bool(_siege_on.get(a.team, false)) and c - float(_event_t.get("siege", -99.0)) > 20.0:
			_later.append([c + 8.0, "siege_%s.png" % _mmss(c), sg["piece"]])
			_event_t["siege"] = c
		_siege_on[a.team] = on
	for i in range(_later.size() - 1, -1, -1):
		var e: Array = _later[i]
		if c >= float(e[0]):
			_later.remove_at(i)
			var who = e[2]
			if is_instance_valid(who) and not who.dead:
				var at: Vector2 = who.position if who is Unit else who.center()
				pending.append([e[1], at, 1.15])


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
	var af := FileAccess.open(out.path_join("ai.txt"), FileAccess.WRITE)
	for l in ai_lines:
		af.store_line(l)
	af.close()
	var r := FileAccess.open(out.path_join("result.txt"), FileAccess.WRITE)
	r.store_line("over %s winner %s clock %.0f" % [str(g.over), str(g.get("winner")), g.clock])
	r.close()
