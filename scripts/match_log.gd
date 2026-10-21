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


func _physics_process(delta: float) -> void:
	if game == null or game.over:
		return
	_snap_t += delta
	if _snap_t >= 60.0:
		_snap_t = 0.0
		snapshot()


## One line per player: what they have and what changed in the last minute.
func snapshot() -> void:
	lines.append("--- minute %d ---" % int(round(game.clock / 60.0)))
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
				counts[u.kind] = int(counts.get(u.kind, 0)) + 1
				value += int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))
		var army := PackedStringArray()
		for k in counts:
			army.append("%d %s" % [counts[k], Defs.UNITS[k]["name"]])
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
	for t in game.n_players():
		var st: Dictionary = game.stats[t]
		var kb := PackedStringArray()
		for k in st["kills_by"]:
			kb.append("%s %d" % [Defs.UNITS[k]["name"] if Defs.UNITS.has(k) else Defs.BUILDINGS.get(k, {"name": k})["name"], st["kills_by"][k]])
		lines.append("  %s: earned %d, spent %d, trained %d, built %d, killed %d, lost %d, razed %d, buildings lost %d, peak army %d. Kills by: %s" % [
			who(t), int(st["gold"]), int(st["spent"]), int(st["trained"]), int(st["built"]), int(st["killed"]),
			int(st["lost"]), int(st["razed"]), int(st["bld_lost"]), int(st["peak_army"]), ", ".join(kb) if not kb.is_empty() else "-"])


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
