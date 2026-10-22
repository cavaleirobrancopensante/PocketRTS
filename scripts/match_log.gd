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


# ------------------------------------------------------------------ performance
# Real frame times (wall clock, not the physics step), counted cheaply every frame into a
# histogram of whole milliseconds; each minute block gets a Performance line from them.
const HIST := 251                # 0..249 ms, and 250+ in the last bucket
var _hist := PackedInt32Array()
var _f_n := 0                    # frames this minute
var _f_ms := 0.0                 # their total time (ms)
var _f_worst := 0.0
var _f_over50 := 0
var _last_us := 0
var _last_frame := -1
var _perf_min: Array = []        # per minute: [minute, avg fps, 1% low fps, worst ms]
var _all_n := 0
var _all_ms := 0.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var fr := Engine.get_process_frames()
	# (only back-to-back frames count: not the gap over a pause or a minimised window)
	if _last_frame == fr - 1 and game != null and not game.over:
		var ms := (now - _last_us) / 1000.0
		if _hist.is_empty():
			_hist.resize(HIST)
		_hist[mini(int(ms), HIST - 1)] += 1
		_f_n += 1
		_f_ms += ms
		if ms > _f_worst:
			_f_worst = ms
		if ms > 50.0:
			_f_over50 += 1
	_last_us = now
	_last_frame = fr


## "58 fps avg, 1% low 31 fps, worst frame 120 ms, 14 frames over 50 ms | units 214, ..."
## for the frames since the last call (and starts counting afresh).
func perf_line(minute: int) -> String:
	if _f_n == 0:
		return ""
	var avg := _f_ms / _f_n
	# 1% low: the average frame time of the slowest 1% of frames, as fps
	var want := maxi(1, _f_n / 100)
	var got := 0
	var sum := 0.0
	for i in range(HIST - 1, -1, -1):
		var c := mini(_hist[i], want - got)
		if c <= 0:
			continue
		# (a bucket holds frames of i..i+1 ms; the open-ended last one counts as the worst)
		sum += c * (_f_worst if i == HIST - 1 else i + 0.5)
		got += c
		if got >= want:
			break
	var low := 1000.0 / maxf(sum / maxi(got, 1), 0.1)
	var units := 0
	for u in game.units:
		if not u.dead:
			units += 1
	var fps := 1000.0 / maxf(avg, 0.01)
	_perf_min.append([minute, fps, low, _f_worst])
	_all_n += _f_n
	_all_ms += _f_ms
	var out := "  Performance: %d fps avg, 1%% low %d fps, worst frame %d ms, %d frames over 50 ms | units %d, bodies %d, effects %d, nodes %d" % [
		int(round(fps)), int(round(low)), int(round(_f_worst)), _f_over50, units, game.bodies.size(), Effect.live,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
	_hist.fill(0)
	_f_n = 0
	_f_ms = 0.0
	_f_worst = 0.0
	_f_over50 = 0
	return out


## The RESULT's summary: the whole match's average and its slowest minute.
func perf_summary() -> String:
	if _perf_min.is_empty() or _all_n == 0:
		return ""
	var worst: Array = _perf_min[0]
	for m in _perf_min:
		if float(m[2]) < float(worst[2]):
			worst = m
	return "  Performance: %d fps average over the match; slowest minute %d (%d fps avg, 1%% low %d fps, worst frame %d ms)" % [
		int(round(1000.0 / maxf(_all_ms / _all_n, 0.01))), int(worst[0]), int(round(float(worst[1]))), int(round(float(worst[2]))), int(round(float(worst[3])))]


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


func _physics_process(delta: float) -> void:
	if game == null or game.over:
		return
	_snap_t += delta
	if _snap_t >= 60.0:
		_snap_t = 0.0
		snapshot()


## One line per player: what they have and what changed in the last minute.
func snapshot() -> void:
	var minute := int(round(game.clock / 60.0))
	lines.append("--- minute %d ---" % minute)
	var pl := perf_line(minute)
	if pl != "":
		lines.append(pl)
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
	var ps := perf_summary()
	if ps != "":
		lines.append(ps)
	for t in game.n_players():
		var st: Dictionary = game.stats[t]
		var kb := PackedStringArray()
		for k in st["kills_by"]:
			kb.append("%s %d" % [Defs.UNITS[k]["name"] if Defs.UNITS.has(k) else Defs.BUILDINGS.get(k, {"name": k})["name"], st["kills_by"][k]])
		lines.append("  %s: earned %d, spent %d, trained %d, built %d, killed %d, lost %d, razed %d, buildings lost %d, peak army %d. Kills by: %s" % [
			who(t), int(st["gold"]), int(st["spent"]), int(st["trained"]), int(st["built"]), int(st["killed"]),
			int(st["lost"]), int(st["razed"]), int(st["bld_lost"]), int(st["peak_army"]), ", ".join(kb) if not kb.is_empty() else "-"])
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
