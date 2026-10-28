extends SceneTree
## A computer match with the NEW BROOD (experiment, docs/brood_new.md): how its simple plan does. Every 30 s a line per
## side: biomass, supply, what it has; the match log's lines at the end.
##   godot --headless --fixed-fps 30 --script res://tools/sim_brood_new.gd [-- secs:<n> map:<id> seed:<n> foe:<faction> who:<level> plan:<strategy>]
var main: Node
var t := 0.0
var g
var map := "hollowfen"
var seed_ := 4242
var secs := 600.0
var foe := "crown"
var who := "hard"
var plan := "balanced"
var next := 30.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("secs:"):
			secs = float(a.substr(5))
		elif a.begins_with("foe:"):
			foe = a.substr(4)
		elif a.begins_with("who:"):
			who = a.substr(4)
		elif a.begins_with("plan:"):
			plan = a.substr(5)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": who, "faction": Defs.BROOD_NEW, "colour": 0, "side": 0, "strategy": plan},
			{"who": who, "faction": foe, "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if g.clock >= next:
		next += 30.0
		for tm in 2:
			print("%3d s  %s" % [int(g.clock), _line(tm)])
	if g.clock >= secs or g.over:
		print("over: %s, winner %d at %d s" % [g.over, g.winner, int(g.clock)])
		if g.mlog:
			for l in g.mlog.lines:
				print("  LOG ", l)
		quit()
	return false


func _line(tm: int) -> String:
	var counts := {}
	for u in g.units:
		if u.team == tm and not u.dead:
			var k: String = u.kind
			if k == BroodNew.MAW and u.tesla_mode == "deployed":
				k = "rootmaw(rooted)"
			counts[k] = int(counts.get(k, 0)) + 1
	var bl := 0
	for b in g.buildings:
		if b.team == tm and not b.dead:
			bl += 1
	var p: Dictionary = g.players[tm]
	var q = BroodNew.queen(g, tm) if BroodNew.on(g, tm) else null
	var extra := ""
	if q:
		extra = " eggs %d, mother %s %d hp" % [int(q.nb.get("eggs", 0)), q.tesla_mode, int(q.hp)]
	return "t%d gold %d res2 %d supply %d/%d bld %d%s %s" % [tm, int(p["gold"]), int(p["res2"]), g.supply_used(tm), int(p["cap"]), bl, extra, str(counts)]
