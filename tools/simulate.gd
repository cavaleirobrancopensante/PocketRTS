extends SceneTree
## AI vs AI test: godot --headless --fixed-fps 30 --script res://tools/simulate.gd -- crown brood
var main: Node
var t := 0.0
var next_report := 30.0
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		var args := OS.get_cmdline_user_args()
		var fs: Array = [args[0], args[1]] if args.size() >= 2 else ["crown", "brood"]
		main.start(2, true, fs)
	var g = main.game
	if g == null:
		return false
	if t >= next_report:
		next_report += 30.0
		var line := "t=%d " % int(g.clock)
		for team in 2:
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
		print("WINNER team ", g.winner, " at ", int(g.clock), "s  ", short)
		return true
	return g.clock > 1500.0
