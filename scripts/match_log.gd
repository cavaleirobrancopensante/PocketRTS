class_name MatchLog
extends Node
## A plain-text log of a match for playtesting: who played, what got built and lost,
## spells, raids on buildings, a snapshot of every player each minute (income, army,
## workers, kills) and the result. The end screen copies it to the clipboard.

var game: Game
var lines := PackedStringArray()
var _snap_t := 0.0
var _last := {}          # team -> {"killed", "lost"} at the last snapshot


## The log of the match being played (for the sound log); null between matches.
static var current: MatchLog = null
var _snd := {}           # second -> {sound name: times}, kept apart and printed at the end


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


## Every sound and music change during a match goes into the SOUND LOG at the end of the
## log: per second, each name once with how many times it played.
static func sound(name: String) -> void:
	if current == null or not is_instance_valid(current) or current.game == null:
		return
	var sec := int(current.game.clock)
	if not current._snd.has(sec):
		current._snd[sec] = {}
	current._snd[sec][name] = int(current._snd[sec].get(name, 0)) + 1


func stamp() -> String:
	var s := int(game.clock)
	return "%02d:%02d" % [s / 60, s % 60]


func who(t: int) -> String:
	if t < 0:
		return "nobody"
	var tag := "YOU" if t == game.human and not game.demo else "P%d" % (t + 1)
	return "%s %s" % [tag, game.faction_of(t).capitalize()]


func add(text: String) -> void:
	lines.append("[%s] %s" % [stamp(), text])


func begin(levels: Dictionary) -> void:
	lines.append("PocketRTS v%s match log  (%s)" % [ProjectSettings.get_setting("application/config/version", "dev"), Time.get_datetime_string_from_system(false, true)])
	lines.append("Map: %s, %d players  (seed %d)" % [game.map_name, game.n_players(), game.rng.seed])
	for t in game.n_players():
		var lv: String = levels.get(t, "")
		lines.append("  %s  side %d  colour %s%s" % [who(t), int(game.sides[t]) + 1, game.team_name(t),
			("  AI: " + lv) if lv != "" else ""])
	lines.append("Device: %s" % ("computer" if Settings.pc() else "phone/tablet"))
	lines.append("")


# ---- lag: real frame times this minute, and what the game was busy with (Prof)
var _ft := PackedFloat32Array()     # frame times (ms) since the last minute
var _phys_ticks := 0                # physics steps since the last minute
var _lag_minutes: Array = []        # [minute, avg fps, 1% low, worst ms]


var _last_us := 0
var _last_frame := -1


## Real frame times from the wall clock (not the physics step, and not `delta`, which the
## engine evens out): only back-to-back frames count, not the gap over a pause.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var fr := Engine.get_process_frames()
	if _last_frame == fr - 1 and game != null and not game.over:
		_ft.append((now - _last_us) / 1000.0)
	_last_us = now
	_last_frame = fr


## "  Performance: 58 fps avg, 1% low 31 fps, worst frame 120 ms, 14 frames over 50 ms ..."
## and where the time went (the busiest parts first), plus how much there is to run.
func _lag_lines() -> void:
	var n := _ft.size()
	if n == 0:
		return
	var tot := 0.0
	var worst := 0.0
	var over33 := 0
	var over50 := 0
	for f in _ft:
		tot += f
		worst = maxf(worst, f)
		if f > 33.4:
			over33 += 1
		if f > 50.0:
			over50 += 1
	var sorted := _ft.duplicate()
	sorted.sort()
	var k := maxi(1, n / 100)
	var low_ms := 0.0
	for i in k:
		low_ms += sorted[n - 1 - i]
	low_ms /= k
	var avg_fps := 1000.0 * n / maxf(tot, 1.0)
	var low_fps := 1000.0 / maxf(low_ms, 0.1)
	_lag_minutes.append([int(round(game.clock / 60.0)), avg_fps, low_fps, worst])
	var bodies := game.bodies.size()
	var fx := 0
	for c in game.get_children():
		if c is Effect:
			fx += 1
	lines.append("  Performance: %d fps avg, 1%% low %d fps, worst frame %d ms, %d frames over 33 ms, %d over 50 ms, %.1f physics steps a frame | units %d, buildings %d, bodies %d, corpses %d, effects %d, nodes %d, objects %d" % [
		int(round(avg_fps)), int(round(low_fps)), int(round(worst)), over33, over50, float(_phys_ticks) / maxf(n, 1),
		game.units.size(), game.buildings.size(), bodies, game.corpses.size(), fx,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT))])
	# where the time went: ms per second of play, busiest first
	Prof.flush()
	var secs := maxf(tot / 1000.0, 0.001)
	var keys := Prof.us.keys()
	keys.sort_custom(func(a, b) -> bool: return int(Prof.us[a]) > int(Prof.us[b]))
	var parts := PackedStringArray()
	for key in keys:
		parts.append("%s %.1f ms/s (%d calls/s)" % [key, float(Prof.us[key]) / 1000.0 / secs, int(round(float(Prof.calls[key]) / secs))])
	lines.append("    busy with: " + ", ".join(parts))
	_ft.clear()
	_phys_ticks = 0
	Prof.reset()


func _physics_process(delta: float) -> void:
	if game == null or game.over:
		return
	_phys_ticks += 1
	_snap_t += delta
	if _snap_t >= 60.0:
		_snap_t = 0.0
		snapshot()


## One line per player: what they have and what changed in the last minute.
func snapshot() -> void:
	lines.append("--- minute %d ---" % int(round(game.clock / 60.0)))
	_lag_lines()
	for t in game.n_players():
		if game.eliminated[t]:
			continue
		var st: Dictionary = game.stats[t]
		var counts := {}
		var workers := 0
		var value := 0
		for u in game.units:
			if u.team != t or u.dead:
				continue
			if u.is_worker():
				workers += 1
			else:
				var ck := Defs.train_key(u.kind, u.armoured)     # (Guardsmen and Cuirassiers on their own)
				counts[ck] = int(counts.get(ck, 0)) + 1
				value += int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))
		var army := PackedStringArray()
		for k in counts:
			army.append("%d %s" % [counts[k], Defs.train_name(k)])
		var bl := {}
		for b in game.buildings:
			if b.team == t and not b.dead and b.built:
				bl[b.kind] = int(bl.get(b.kind, 0)) + 1
		var halls := int(bl.get(game.faction_hall(t), 0))
		var last: Dictionary = _last.get(t, {"killed": 0, "lost": 0})
		var res: Array = Defs.FACTIONS[game.faction_of(t)]["res"]
		lines.append("  %s: earned %d %s total, has %d + %d %s | supply %d/%d | workers %d | halls %d | army (%d value): %s | kills +%d (%d) losses +%d (%d)" % [
			who(t), int(st["gold"]), String(res[0]).to_lower(), int(game.players[t]["gold"]), int(game.players[t]["res2"]),
			String(res[1]).to_lower(), game.supply_used(t), int(game.players[t]["cap"]), workers, halls, value,
			", ".join(army) if not army.is_empty() else "none",
			int(st["killed"]) - int(last["killed"]), int(st["killed"]), int(st["lost"]) - int(last["lost"]), int(st["lost"])])
		if t == game.human and not game.demo:
			lines[lines.size() - 1] += " | APM %d (this minute %d actions)" % [game.apm(), game.actions_minute]
			game.apm_minutes.append(game.actions_minute)
			game.actions_minute = 0
		if game.faction_hall(t) == "town_hall" or game.faction_hall(t) == "hive":
			var soil := PackedStringArray()
			for h in game.halls_of(t):
				soil.append("%d%%" % int(round(h.soil_left() * 100)))
			if not soil.is_empty():
				lines[lines.size() - 1] += (" | soil " if game.faction_hall(t) == "town_hall" else " | ground ") + " ".join(soil)
		if game.faction_hall(t) != "hive":
			# what each hall's lode has left: saltpetre for the Crown, ore for the Clockwork
			var left := PackedStringArray()
			for h in game.halls_of(t):
				left.append("%d%%" % int(round(h.lode_left() * 100)))
			if not left.is_empty():
				lines[lines.size() - 1] += " | %s %s" % [Defs.LODE_NAME[game.faction_hall(t)], " ".join(left)]
		# the economy buildings' average efficiency (staffing x reserve, as their bars show)
		var effs: Array = []
		for b in game.buildings:
			if b.team == t and b.built and not b.dead and Defs.is_econ(b.kind):
				var e: Array = b.efficiency()
				if not e.is_empty():
					effs.append(float(e[0]))
		if not effs.is_empty():
			lines[lines.size() - 1] += " | efficiency %d%%" % int(round(effs.reduce(func(x: float, y: float) -> float: return x + y, 0.0) / effs.size() * 100))
		if int(st.get("sacrificed", 0)) > 0:
			lines[lines.size() - 1] += " | sacrificed %d (+%d essence)" % [int(st["sacrificed"]), int(st["sacrifice_essence"])]
		_last[t] = {"killed": st["killed"], "lost": st["lost"]}


func finish(winner: int) -> void:
	snapshot()
	lines.append("")
	lines.append("RESULT at %s: %s" % [stamp(), ("winner " + who(winner)) if winner >= 0 else "no winner"])
	if not _lag_minutes.is_empty():
		var pm := PackedStringArray()
		var worst_m: Array = _lag_minutes[0]
		for m in _lag_minutes:
			pm.append("m%d %d fps (1%% low %d)" % [m[0], int(round(m[1])), int(round(m[2]))])
			if float(m[2]) < float(worst_m[2]):
				worst_m = m
		lines.append("  Performance per minute: " + ", ".join(pm) + ". Worst: minute %d (1%% low %d fps, worst frame %d ms)." % [worst_m[0], int(round(worst_m[2])), int(round(worst_m[3]))])
	for t in game.n_players():
		var st: Dictionary = game.stats[t]
		var kb := PackedStringArray()
		for k in st["kills_by"]:
			kb.append("%s %d" % [Defs.UNITS[k]["name"] if Defs.UNITS.has(k) else Defs.BUILDINGS.get(k, {"name": k})["name"], st["kills_by"][k]])
		lines.append("  %s: earned %d, spent %d, trained %d, built %d, killed %d, lost %d, razed %d, buildings lost %d, peak army %d. Kills by: %s" % [
			who(t), int(st["gold"]), int(st["spent"]), int(st["trained"]), int(st["built"]), int(st["killed"]),
			int(st["lost"]), int(st["razed"]), int(st["bld_lost"]), int(st["peak_army"]), ", ".join(kb) if not kb.is_empty() else "-"])
		if int(st.get("hauled_horse", 0)) + int(st.get("hauled_keg", 0)) > 0:
			lines[lines.size() - 1] += " Haulers brought %d horses and %d powder kegs." % [int(st.get("hauled_horse", 0)), int(st.get("hauled_keg", 0))]
		if int(st.get("horses_bolted", 0)) + int(st.get("horses_caught", 0)) > 0:
			lines[lines.size() - 1] += " Loose horses: %d of its own bolted, %d caught." % [int(st.get("horses_bolted", 0)), int(st.get("horses_caught", 0))]
		if t == game.human and not game.demo:
			lines[lines.size() - 1] += " APM: average %d, peak %d, %d actions." % [game.apm_average(), maxi(game.apm_peak, game.apm()), game.actions_total]
			# peaks and lows: whole minutes only (the last snapshot may be a part minute)
			var mins: Array = game.apm_minutes
			if mins.size() > 1 and fmod(game.clock, 60.0) > 2.0:
				mins = mins.slice(0, mins.size() - 1)      # (the last one is only part of a minute)
			if not mins.is_empty():
				var hi := 0
				var lo := 0
				for i in mins.size():
					if int(mins[i]) > int(mins[hi]):
						hi = i
					if int(mins[i]) < int(mins[lo]):
						lo = i
				lines.append("  APM peaks and lows: busiest minute %d (%d actions), quietest minute %d (%d actions); busiest 10 seconds: %d actions, ending at %02d:%02d (a pace of %d APM). Per minute: %s" % [
					hi + 1, int(mins[hi]), lo + 1, int(mins[lo]), game.burst_best, int(game.burst_at) / 60, int(game.burst_at) % 60,
					game.burst_best * 6, ", ".join(mins.map(func(x) -> String: return str(x)))])


func text() -> String:
	var out := lines.duplicate()
	if not _snd.is_empty():
		out.append("")
		out.append("--- SOUND LOG (every sound and music change, per second; x2 = played twice) ---")
		var secs: Array = _snd.keys()
		secs.sort()
		for sec in secs:
			var parts := PackedStringArray()
			for n in _snd[sec]:
				var c: int = _snd[sec][n]
				parts.append(n if c == 1 else "%s x%d" % [n, c])
			out.append("[%02d:%02d] %s" % [int(sec) / 60, int(sec) % 60, ", ".join(parts)])
	return "\n".join(out)
