class_name MatchLog
extends Node
## A plain-text log of a match for playtesting: who played, what got built and lost,
## spells, raids on buildings, a snapshot of every player each minute (income, army,
## workers, kills) and the result. The end screen copies it to the clipboard.

var game: Game
var lines := PackedStringArray()
var _snap_t := 0.0
var _last := {}          # team -> {"killed", "lost"} at the last snapshot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


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
	lines.append("Map: %s, %d players" % [game.map_name, game.n_players()])
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
			# the deposits each hall's site has left: saltpetre for the Crown, ore for the Clockwork
			var dep := "saltpetre" if game.faction_hall(t) == "town_hall" else "ore"
			var left := PackedStringArray()
			for h in game.halls_of(t):
				var f := game.site_left_at(h.center(), dep)
				left.append(("%d%%" % int(round(f * 100))) if f >= 0.0 else "-")
			if not left.is_empty():
				lines[lines.size() - 1] += " | %s %s" % [dep, " ".join(left)]
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
	return "\n".join(lines)
