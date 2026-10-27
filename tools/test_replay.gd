extends SceneTree
## Replays (docs/replays.md), end to end in one process:
##   godot --headless --fixed-fps 30 --script res://tools/test_replay.gd [-- secs:<n> map:<id> seed:<n> spawn:<n> a:<faction> b:<faction>]
## Two Hard computers play for `secs` game seconds while the replay is recorded (as every match is); the true state of
## every unit is kept at each recorded picture. Then the replay is played back (Main.start_replay: the viewer with its
## HUD and bar) and checked: at several times the puppet's units match the match (kind, team, place within a few px,
## health), seeking backwards and forwards leaves nothing stale (units, bodies, effects), pause and speed move the
## clock as they should, a file cut short (a crash) still plays to its last whole chunk, and a replay stamped with
## another version (other field lists, a unit kind that is gone) shows the warning and still plays. Prints the size
## and the recorder's cost. spawn:N adds N Musketeers and N Raptors at 30 s (a big battle).
var main: Node
var t := 0.0
var g: Game
var map := "hollowfen"
var seed_ := 4242
var secs := 150.0
var spawn := 0
var fa := "crown"
var fb := "brood"
var stage := "play"
var truth: Array = []            # one per recorded picture: {"clk", "u": {id: [kind, team, pos, hp]}}
var rec_path := ""
var rec_line := ""
var results := {}
var failed := 0
var _n_seen := 0
var _wait := 0
var _spawned := false
var _bench := {}
var _spawned_units: Array = []
var _march_n := -1
var _marks: Array = [300.0, 600.0, 1200.0]
var _mark_clk := 0.0
var _mark_us := 0
var _mark_n := 0


## The match as it is the moment a picture is taken.
func _capture() -> void:
	var u := {}
	for x in g.units:
		if is_instance_valid(x) and not x.dead and x.net_id != 0:
			u[x.net_id] = [x.kind, x.team, x.position.snapped(Vector2(0.1, 0.1)), snappedf(x.hp, 0.1)]
	truth.append({"clk": snappedf(g.rec.last_clk, 0.01), "u": u, "n": g.units.size()})     # (a picture's clock is to 0.01 s)


## spawn:N: N soldiers a side in the middle of the map (a big battle's worth of units), marching about (_march),
## topped up to N every minute (the fight there goes on all match).
func _spawn() -> void:
	_spawned_units = _spawned_units.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	var mid := Vector2(Game.W, Game.H) * Game.T * 0.5
	for tm in 2:
		var hall: Building = null
		for b in g.buildings:
			if b.team == tm and b.kind == g.faction_hall(tm):
				hall = b
		var c: Vector2 = mid.lerp(hall.center(), 0.25) if hall else mid
		var have := _spawned_units.filter(func(u) -> bool: return u.team == tm).size()
		for i in maxi(0, spawn - have):
			var k := "musketeer" if g.faction_of(tm) == "crown" else ("raptor" if g.faction_of(tm) == "brood" else "windup_soldier")
			var cell := g.nearest_free(g.cell_of(c + Vector2.from_angle(randf() * TAU) * randf_range(80, 400)), 12)
			_spawned_units.append(g._add_unit(k, tm, g.cell_center(cell)))


## Every 4 s half the added soldiers walk somewhere else (the rest stand or fight where they are).
func _march() -> void:
	for u in _spawned_units:
		if is_instance_valid(u) and not u.dead and randf() < 0.5:
			var to := g.cell_center(g.nearest_free(g.cell_of(u.position + Vector2.from_angle(randf() * TAU) * 300.0), 10))
			u.give({"o": "move", "p": to})


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs:"):
			secs = float(a.substr(5))
		elif a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("spawn:"):
			spawn = int(a.substr(6))
		elif a.begins_with("a:"):
			fa = a.substr(2)
		elif a.begins_with("b:"):
			fb = a.substr(2)


func check(name: String, ok: bool, detail := "") -> void:
	results[name] = ok
	if not ok:
		failed += 1
	print("CHECK %s %s %s" % [name, "OK" if ok else "FAILED", detail])


func _process(delta: float) -> bool:
	t += delta
	match stage:
		"play":
			return _play()
		"watch":
			return _watch()
	return false


# ------------------------------------------------------------------ the match, recorded

func _play() -> bool:
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": fb, "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	paused = false
	if g.rec == null:
		check("recorder_started", false, "no recorder on a skirmish")
		quit(1)
		return true
	if spawn > 0 and not _spawned and g.clock >= 30.0:
		_spawned = true
		_spawn()
	if _spawned and int(g.clock / 4.0) != _march_n:
		_march_n = int(g.clock / 4.0)
		_march()
		if _march_n % 15 == 0:
			_spawn()
	var rec: ReplayRecorder = g.rec
	if _marks.size() > 0 and g.clock >= float(_marks[0]):
		var at: float = _marks.pop_front()
		var secs_w := maxf(g.clock - _mark_clk, 1.0)
		print("SIZE_AT %s: file %d KB (+ %d KB this chunk), %d units %d buildings, recording %.2f ms per match second since the last mark, %.1f pictures a second" % [
			ReplayPlayer.clock_text(at), (rec.bytes_file + ReplayFile.pack_frames(rec.frames).size()) / 1024, 0, g.units.size(), g.buildings.size(),
			(rec.cost_us - _mark_us) / 1000.0 / secs_w, (rec.n_frames - _mark_n) / secs_w])
		_mark_clk = g.clock
		_mark_us = rec.cost_us
		_mark_n = rec.n_frames
	if not rec.recorded.is_connected(_capture):
		rec.recorded.connect(_capture)
	if g.clock >= secs or g.over:
		rec_line = rec.cost_line()
		print("RECORDER %s" % rec_line)
		rec_path = rec.finish(g.winner if g.over else -1)
		check("replay_written", rec_path != "" and FileAccess.file_exists(rec_path), rec_path)
		var size := FileAccess.get_file_as_bytes(rec_path).size()
		print("SIZE %.0f s of match: %d KB (%.1f KB a minute), %d units at the end" % [g.clock, size / 1024, size / 1024.0 / g.clock * 60.0, g.units.size()])
		var m := ReplayFile.read_meta(rec_path)
		check("replay_listed", ReplayFile.list().any(func(x: Dictionary) -> bool: return String(x["path"]) == rec_path) and String(m.get("result", "")) != "",
			"result %s, %d players, %s" % [m.get("result"), (m.get("players", []) as Array).size(), ReplayPlayer.clock_text(float(m.get("len", 0)))])
		_make_variants()
		stage = "watch"
		main._to_menu()
		main.start_replay(rec_path)
		_wait = 0
	return false


# ------------------------------------------------------------------ playback

var _wstep := 0
var _wt := 0.0
var _p0 := 0.0
var _crash_path := ""
var _old_path := ""


func _watch() -> bool:
	_wait += 1
	if _wait < 3:
		return false
	g = main.game
	var rp: ReplayPlayer = g.replay if g != null else null
	match _wstep:
		0:
			check("viewer_open", rp != null and g.puppet and g.demo and g.spectator != null, "length %s, %d chunks" % [ReplayPlayer.clock_text(rp.length), rp.chunks.size()])
			var ks := [truth.size() / 5, truth.size() / 2, truth.size() * 4 / 5, truth.size() / 5, truth.size() - 3, 2]
			var worst := 0.0
			var bad := []
			var stale := 0
			var t0 := Time.get_ticks_usec()
			for k in ks:
				var r := _compare_at(rp, k)
				worst = maxf(worst, float(r["worst"]))
				stale += int(r["stale"])
				if not (r["bad"] as Array).is_empty():
					bad.append([k, r["bad"].slice(0, 3)])
			var seek_ms := (Time.get_ticks_usec() - t0) / 1000.0 / ks.size()
			check("units_match_the_match", bad.is_empty() and worst <= 3.0, "at %d times (back and forth): worst place %.2f px, mismatches %s" % [ks.size(), worst, str(bad)])
			check("seek_leaves_nothing_stale", stale == 0, "stale entities %d; a seek takes %.1f ms" % [stale, seek_ms])
			_bench["seek_ms"] = seek_ms
			# pause: the clock stands still
			rp.seek(float(truth[truth.size() / 2]["clk"]))
			rp.set_playing(false)
			_p0 = rp.play_t
			_wt = 0.0
			_wstep = 1
		1:
			_wt += 1.0
			if _wt >= 20.0:
				check("pause_holds", absf(rp.play_t - _p0) < 0.001 and g.world.process_mode == Node.PROCESS_MODE_DISABLED, "clock %.2f -> %.2f" % [_p0, rp.play_t])
				rp.set_playing(true)
				rp.set_speed(4.0)
				_p0 = rp.play_t
				_wt = 0.0
				_wstep = 2
		2:
			_wt += 1.0
			if _wt >= 30.0:
				var adv := rp.play_t - _p0
				check("speed_4x", adv > 3.0 and adv < 5.0, "30 frames at 4x moved the clock %.2f s (1 s at 1x)" % adv)
				var r := _compare_now(rp)
				check("units_match_while_playing", (r["bad"] as Array).is_empty() and float(r["worst"]) <= 4.0, "at %s: worst place %.2f px, mismatches %s" % [ReplayPlayer.clock_text(rp.play_t), r["worst"], str(r["bad"].slice(0, 3))])
				rp.set_speed(1.0)
				_wstep = 3
		3:
			# fog: one player's view hides the other's units out of sight; all vision shows them all
			g.spectator.set_mode("free", 0, true)
			g.refresh_fog()
			var hidden := g.units.filter(func(u: Unit) -> bool: return u.team == 1 and not u.visible).size()
			g.spectator.set_mode("all", 0, true)
			g.refresh_fog()
			var hidden_all := g.units.filter(func(u: Unit) -> bool: return not u.visible and not u.off_field).size()
			check("fog_switch", hidden > 0 and hidden_all == 0, "P1's view hides %d of P2's units, all vision hides %d" % [hidden, hidden_all])
			g.spectator.set_mode("free", 1, true)
			g.refresh_fog()
			var hidden2 := g.units.filter(func(u: Unit) -> bool: return u.team == 0 and not u.visible).size()
			g.spectator.set_mode("all", 0, true)
			g.refresh_fog()
			check("fog_switch_p2", hidden2 > 0, "P2's view hides %d of P1's units" % hidden2)
			# the end: the clock stops there, PLAY starts it again from the beginning
			rp.seek(rp.length)
			check("seek_to_end", rp.at_end and absf(rp.play_t - rp.length) < 0.01, "at %s of %s" % [ReplayPlayer.clock_text(rp.play_t), ReplayPlayer.clock_text(rp.length)])
			# selection: a unit can be selected and read, never commanded
			var u0: Unit = g.units[0] if not g.units.is_empty() else null
			if u0:
				g.selection = [u0]
				check("select_read_only", g.controlled_team() == -1 and g.selected_units().is_empty(), "%s selected, orders go nowhere" % u0.kind)
			main._to_replays()
			_wait = 0
			_wstep = 4
		4:
			# a file cut short (the game closed mid-match): plays to its last whole chunk
			main.start_replay(_crash_path)
			_wait = 0
			_wstep = 5
		5:
			var ok := rp != null and rp.length > 10.0 and rp.footer.is_empty()
			if ok:
				rp.seek(rp.length - 1.0)
				var k := _frame_at(rp.play_t)
				ok = k >= 0 and g.units.size() > 0
			check("crash_keeps_most", ok, "cut file: %s playable of %s" % [ReplayPlayer.clock_text(rp.length if rp else 0.0), ReplayPlayer.clock_text(float(truth.back()["clk"]))])
			main._to_replays()
			main.start_replay(_old_path)
			_wait = 0
			_wstep = 6
		6:
			var note_ok := rp != null and rp.version_note.contains("0.0.1")
			var r := _compare_at(rp, truth.size() / 2, true) if rp else {"bad": ["no viewer"], "worst": 99.0}
			var ph := 0
			for u in g.units:
				if u.modulate.a < 0.9:
					ph += 1
			check("old_version_plays", note_ok and (r["bad"] as Array).is_empty() and float(r["worst"]) <= 3.0 and ph > 0,
				"note '%s', worst place %.2f px, %d drawn as a placeholder, mismatches %s" % [rp.version_note if rp else "", r["worst"], ph, str(r["bad"].slice(0, 3))])
			main._to_replays()
			_wstep = 7
		7:
			for p in [_crash_path, _old_path]:
				ReplayFile.delete(p)
			print("BENCH %s" % str(_bench))
			print("ALL OK" if failed == 0 else "SOME FAILED (%d)" % failed)
			quit(0 if failed == 0 else 1)
			return true
	return false


## The recorded picture with this clock (or the last one before it).
func _frame_at(clk: float) -> int:
	var k := -1
	for i in truth.size():
		if float(truth[i]["clk"]) <= clk:
			k = i
	return k


## Seek to picture k and compare: every unit of picture k+1 (the one ahead, as shown) is there with its kind, team and
## health, at picture k's place; nothing else is.
func _compare_at(rp: ReplayPlayer, k: int, old := false) -> Dictionary:
	k = clampi(k, 0, truth.size() - 2)
	rp.seek(float(truth[k]["clk"]))
	return _compare(rp, k, 0.0, old)


func _compare_now(rp: ReplayPlayer) -> Dictionary:
	var k := _frame_at(rp.play_t)
	var span := float(truth[k + 1]["clk"]) - float(truth[k]["clk"])
	return _compare(rp, k, clampf((rp.play_t - float(truth[k]["clk"])) / maxf(span, 0.001), 0.0, 1.0), false)


func _compare(rp: ReplayPlayer, k: int, f: float, old: bool) -> Dictionary:
	var a: Dictionary = truth[k]["u"]
	var b: Dictionary = truth[k + 1]["u"]
	var bad: Array = []
	var worst := 0.0
	var seen := {}
	for id in b:
		var want: Array = b[id]
		var u = rp.by_id.get(id)
		if not is_instance_valid(u) or not (u is Unit) or u.dead:
			bad.append("missing %s #%d" % [want[0], id])
			continue
		seen[u] = true
		if u.kind != String(want[0]) and not (old and u.modulate.a < 0.9):
			bad.append("kind %s != %s" % [u.kind, want[0]])
		if u.team != int(want[1]):
			bad.append("team #%d" % id)
		if absf(u.hp - float(want[3])) > 0.11:
			bad.append("hp %s #%d %.1f != %.1f" % [u.kind, id, u.hp, float(want[3])])
			if OS.get_cmdline_user_args().has("debug"):
				var tl: Array = []
				for kk in range(maxi(0, k - 3), mini(truth.size(), k + 3)):
					tl.append([kk, snappedf(float(truth[kk]["clk"]), 0.01), truth[kk]["u"].get(id, [0, 0, null, null])[3]])
				print("DEBUG hp #%d %s at k=%d viewer %.1f fast %s truth %s dead %s" % [id, u.kind, k, u.hp, str(rp._fast.get(id)), str(tl), u.dead])
		if a.has(id):
			var p: Vector2 = (a[id][2] as Vector2).lerp(want[2], f)
			var d: float = u.position.distance_to(p)
			if (a[id][2] as Vector2).distance_to(want[2]) < 200.0:     # (not a jump: a unit leaving or boarding)
				worst = maxf(worst, d)
				if d > 4.0:
					bad.append("place %s #%d off %.1f px" % [u.kind, id, d])
					if OS.get_cmdline_user_args().has("debug"):
						var tl: Array = []
						for kk in range(maxi(0, k - 3), mini(truth.size(), k + 3)):
							tl.append([kk, snappedf(float(truth[kk]["clk"]), 0.01), truth[kk]["u"].get(id, [0, 0, null])[2]])
						print("DEBUG #%d at k=%d f=%.2f shown %s hist %s truth %s motion %s" % [id, k, f, str(u.position), str(rp.hist.get(id)), str(tl), str(rp.motion.get(id))])
	var stale := 0
	for u in g.units:
		if not seen.has(u):
			stale += 1
			bad.append("stale %s #%d" % [u.kind, u.net_id])
	# bodies and rubble left from another time: only deaths since the keyframe may lie there; no effects at all
	var t0 := 0.0
	for c in rp.chunks:
		if float(c["t0"]) <= rp.play_t + 0.001:
			t0 = float(c["t0"])
	for n in g.world.get_children():
		if n is Unit and n.dead and not n.is_queued_for_deletion() and n.died_at < t0 - 0.01:
			stale += 1
			bad.append("old body %s died %.1f" % [n.kind, n.died_at])
	for n in g.get_children():
		if n is Shot and not n.is_queued_for_deletion() and f == 0.0:
			stale += 1              # (right after a seek: it fires no shots from the pictures it runs through, none may be in the air)
			bad.append("left over shot")
	return {"bad": bad, "worst": worst, "stale": stale}


# ------------------------------------------------------------------ a crashed file and an old version's

func _make_variants() -> void:
	var bytes := FileAccess.get_file_as_bytes(rec_path)
	var d := ReplayFile.parse(bytes)
	# the crash: everything up to the middle of the chunk before the last, no footer
	var cut := bytes.size()
	var pos := 4
	var n := 0
	var chunk_starts: Array = []
	while pos < bytes.size():
		var sz := bytes.decode_u32(pos + 1)
		if bytes.decode_u8(pos) == ReplayFile.T_CHUNK:
			chunk_starts.append(pos)
		pos += ReplayFile.REC_HEAD + sz
		n += 1
	cut = int(chunk_starts[chunk_starts.size() - 2]) + 200
	_crash_path = ReplayFile.DIR + "/test_crash.hfr"
	var f := FileAccess.open(_crash_path, FileAccess.WRITE)
	f.store_buffer(bytes.slice(0, cut))
	f.close()
	# an old version: other field lists (a field gone, one that no longer exists), and a unit kind that is gone
	var h: Dictionary = (d["header"] as Dictionary).duplicate(true)
	h["game_version"] = "0.0.1"
	var up: Array = NetSnapshot.UNIT_PROPS.duplicate()
	up.erase("arm")
	up.insert(5, "zz_old")
	h["lists"]["up"] = up
	var gone_kind := ""
	for id in truth[truth.size() / 2]["u"]:
		gone_kind = String(truth[truth.size() / 2]["u"][id][0])
		break
	var out := PackedByteArray(ReplayFile.MAGIC.to_ascii_buffer())
	out.append_array(ReplayFile._record(ReplayFile.T_HEAD, 0, 0, var_to_bytes(h)))
	var ai := NetSnapshot.UNIT_PROPS.find("arm")
	var ex := ReplayPlayer.new()          # (the old version wrote whole rows: the patches undone first)
	for c in d["chunks"]:
		var frames := ReplayFile.unpack_frames(c["data"])
		var nf: Array = []
		for fb in frames:
			var m: Dictionary = bytes_to_var(fb)
			ex.expand(m)
			m = m.duplicate(true)
			for row in m.get("u", []):
				if String(row[1]) == gone_kind:
					row[1] = "zz_gone_unit"
				if row.size() > NetSnapshot.U_FIXED:
					var o := NetSnapshot.U_FIXED
					var vals: Array = row.slice(o, o + NetSnapshot.UNIT_PROPS.size())
					vals.remove_at(ai)
					vals.insert(5, 12345)
					var nr: Array = row.slice(0, o) + vals + row.slice(o + NetSnapshot.UNIT_PROPS.size())
					row.clear()
					row.append_array(nr)
			nf.append(var_to_bytes(m))
		out.append_array(ReplayFile._record(ReplayFile.T_CHUNK, c["t0"], c["t1"], ReplayFile.pack_frames(nf)))
	ex.free()
	out.append_array(ReplayFile._record(ReplayFile.T_EVENTS, 0, 0, var_to_bytes(d["events"])))
	out.append_array(ReplayFile._record(ReplayFile.T_FOOT, 0, 0, var_to_bytes(d["footer"])))
	_old_path = ReplayFile.DIR + "/test_old.hfr"
	var f2 := FileAccess.open(_old_path, FileAccess.WRITE)
	f2.store_buffer(out)
	f2.close()
	print("VARIANTS crash file cut at %d of %d bytes; old version with '%s' renamed to a kind that is gone" % [cut, bytes.size(), gone_kind])
