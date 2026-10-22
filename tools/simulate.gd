extends SceneTree
## AI vs AI test:
##   godot --headless --fixed-fps 30 --script res://tools/simulate.gd -- crown brood [map] [2v2] [brutal]
## Any number of factions (2-8); every player is on its own side unless "2v2", "3v3" or
## "4v4" (half against half; or "1v2", "1v3": the first player alone against the rest).
## "brutal" makes the first player Brutal. The map: any map id or a random pool
## ("random_2v2", ...; see MapGen.POOLS). "minutes:N" stops after N game minutes.
var main: Node
var t := 0.0
var next_report := 30.0
var _earned9: Array = []        # gold earned by each team at 9:00 (for the minute-10 line)
var stop_at := 1500.0           # game seconds before giving up (TIMEOUT)
var _frames := 0
var _wall0 := 0
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		var args := OS.get_cmdline_user_args()
		var facs: Array = []
		var map := "random"
		var mode := "ffa"
		var first := "hard"
		var strats: Array = []
		for a in args:
			if a.begins_with("s:"):
				strats.append(a.substr(2))
				continue
			if a in ["crown", "brood", "clockwork", "random"]:
				facs.append(a)
			elif MapGen.all_ids().has(a) or MapGen.is_pool(a):
				map = a
			elif a in ["2v2", "3v3", "4v4", "1v2", "1v3", "ffa"]:
				mode = a
			elif a.begins_with("minutes:"):
				stop_at = float(a.substr(8)) * 60.0
			elif a in ["easy", "normal", "hard", "brutal"]:
				first = a
		if facs.size() < 2:
			facs = ["crown", "brood"]
		var slots: Array = []
		for i in facs.size():
			var side := i
			if mode in ["2v2", "3v3", "4v4"]:
				side = 0 if i < facs.size() / 2 else 1
			elif mode in ["1v2", "1v3"]:
				side = 0 if i == 0 else 1
			slots.append({"who": first if i == 0 else "hard", "faction": facs[i], "colour": i, "side": side,
				"strategy": strats[i] if i < strats.size() else "balanced"})
		main.start({"map": map, "slots": slots})
	var g = main.game
	if g == null:
		return false
	if _earned9.is_empty() and g.clock >= 540.0:
		for team in g.n_players():
			_earned9.append(int(g.stats[team]["gold"]))
	if _earned9.size() > 0 and _earned9[0] >= 0 and g.clock >= 600.0:
		var m10 := "MIN10"
		for team in g.n_players():
			m10 += " | T%d %s halls=%d income(min 10)=%d bank=%d/%d workers=%d army=%d" % [team, g.faction_of(team), g.halls_of(team).size(),
				int(g.stats[team]["gold"]) - int(_earned9[team]), g.players[team]["gold"], int(g.players[team]["res2"]), g.workers(team).size(), g.army(team).size()]
		print(m10)
		_earned9[0] = -1
	_frames += 1
	if t >= next_report:
		next_report += 30.0
		var now := Time.get_ticks_msec()
		var line := "t=%d (%.1f ms a frame, %d units) " % [int(g.clock), float(now - _wall0) / maxi(_frames, 1), g.units.size()]
		_wall0 = now
		_frames = 0
		for team in g.n_players():
			var counts := {}
			for u in g.units:
				if u.team == team and not u.dead:
					counts[u.kind] = counts.get(u.kind, 0) + 1
			var bl := {}
			for b in g.buildings:
				if b.team == team and not b.dead:
					bl[b.kind] = bl.get(b.kind, 0) + 1
			var ws := {}
			for u in g.workers(team):
				var k: String = u.order + ":" + u.work
				ws[k] = ws.get(k, 0) + 1
			line += "| T%d gold=%d earned=%d r2=%d sup=%d/%d units=%s bld=%s work=%s " % [team, g.players[team]["gold"], g.stats[team]["gold"], int(g.players[team]["res2"]), g.supply_used(team), g.players[team]["cap"], counts, bl, ws]
		print(line)
	if g.over:
		var short: Array = []
		for st in g.stats:
			short.append({"earned": st["gold"], "killed": st["killed"], "lost": st["lost"], "razed": st["razed"], "kills_by": st["kills_by"]})
		var plans := []
		for ai in g.ais:
			plans.append(ai.strategy)
		print("PLANS ", plans)
		print("WINNER team ", g.winner, " at ", int(g.clock), "s on ", g.map_name, "  ", short)
		if g.mlog:
			for l in g.mlog.lines:
				print("LOG ", l)
		return true
	if g.clock > stop_at:
		print("TIMEOUT at ", int(g.clock), "s on ", g.map_name, " (no winner)")
		if g.mlog:
			for l in g.mlog.lines:
				print("LOG ", l)
		return true
	return false
