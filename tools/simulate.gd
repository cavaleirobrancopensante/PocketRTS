extends SceneTree
## AI vs AI test: godot --headless --fixed-fps 30 --script res://tools/simulate.gd
var main: Node
var t := 0.0
var next_report := 30.0
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start(2, true)
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
			line += "| T%d gold=%d sup=%d/%d units=%s bld=%s " % [team, g.players[team]["gold"], g.supply_used(team), g.players[team]["cap"], counts, bl]
		print(line)
	if g.over:
		print("WINNER team ", g.winner, " at ", int(g.clock), "s  stats ", g.stats)
		return true
	return g.clock > 1500.0
