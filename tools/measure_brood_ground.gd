extends SceneTree
## Brood ground measurement (docs/brood_pit_ground.md): a Hard Balanced Brood computer against a
## Hard Balanced Crown or Clockwork computer, and what the Brood's Feeding Pits earn and how long
## they last.
##
##   godot --headless --fixed-fps 30 --script res://tools/measure_brood_ground.gd -- <opp> map=<id> [minutes=20] [peaceful=1] [seed=1]
##
## peaceful=1 (the default): both computers build their normal economy and army but never attack
## (AI.peaceful), so the economy can be compared minute by minute to 20 minutes. peaceful=0: a real game.
## One line a minute ("MIN"), then "SUMMARY" lines: income per minute, total biomass at 10 / 15 / 20 min,
## pits built, how long a pit lasted (built -> its ground spent, or died), pits on the capital's plateau,
## how far out the pits stood, and the opponent's income for comparison.

var main: Node
var opts := {}
var g: Game = null
var t := 0.0
var started := false
var next_min := 60.0
var last_earned: Array = []
var per_min: Array = []          # [minute, brood income, opp income]
var totals := {}                 # minute -> [brood earned, opp earned]
var pits := {}                   # instance id -> {"built": s, "spent": s or -1, "died": s or -1, "d": tiles, "main": bool}
var max_main := 0
var stop_at := 1200.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _opt(k: String, def: String) -> String:
	return String(opts.get(k, def))


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null and not started:
		started = true
		var opp := "crown"
		for a in OS.get_cmdline_user_args():
			if "=" in a:
				var kv: PackedStringArray = a.split("=", true, 1)
				opts[kv[0]] = kv[1]
			elif a in ["crown", "clockwork", "brood"]:
				opp = a
		stop_at = float(_opt("minutes", "20")) * 60.0 + 1.0
		seed(int(_opt("seed", "1")))
		main.start({"map": _opt("map", "greenhold"), "seed": int(_opt("seed", "1")), "slots": [
			{"who": "hard", "faction": "brood", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": opp, "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	if g == null:
		g = main.game
		if _opt("peaceful", "1") == "1":
			for ai in g.ais:
				ai.peaceful = true
		last_earned = [0, 0]
		print("MEASURE map=%s opp=%s peaceful=%s version=%s" % [g.map_name, g.faction_of(1), _opt("peaceful", "1"), ProjectSettings.get_setting("application/config/version")])
	_track()
	if g.clock >= next_min:
		var m := int(round(next_min / 60.0))
		next_min += 60.0
		var e0 := int(g.stats[0]["gold"])
		var e1 := int(g.stats[1]["gold"])
		per_min.append([m, e0 - int(last_earned[0]), e1 - int(last_earned[1])])
		last_earned = [e0, e1]
		totals[m] = [e0, e1]
		var live := _live_pits()
		var fresh := live.filter(func(b: Building) -> bool: return b.soil_left() > 0.0)
		var on_main := live.filter(func(b: Building) -> bool: return _on_main(b)).size()
		max_main = maxi(max_main, on_main)
		print("MIN %2d brood +%d (total %d) bank %d grubs %d pits %d (%d with ground, %d on the main plateau) | opp +%d (total %d) workers %d" % [m,
			per_min[-1][1], e0, int(g.players[0]["gold"]), g.workers(0).size(), live.size(), fresh.size(), on_main,
			per_min[-1][2], e1, g.workers(1).size()])
	if g.over or g.clock >= stop_at:
		_summary()
		return true
	return false


func _live_pits() -> Array:
	return g.buildings.filter(func(b: Building) -> bool: return b.team == 0 and b.kind == "feeding_pit" and b.built and not b.dead)


func _on_main(b: Building) -> bool:
	var cap := g.capital(0)
	if cap == null:
		return false
	var hc := g.cell_of(cap.center())
	var pc := g.cell_of(b.center())
	return g.in_map(hc) and g.in_map(pc) and int(g.height[g.idx(hc)]) == int(g.height[g.idx(pc)])


func _track() -> void:
	var seen := {}
	for b in g.buildings:
		if b.team != 0 or b.kind != "feeding_pit" or not b.built or b.dead:
			continue
		var k: int = b.get_instance_id()
		seen[k] = true
		if not pits.has(k):
			pits[k] = {"built": g.clock, "spent": -1.0, "died": -1.0, "d": g.capital_dist(0, b.center()), "main": _on_main(b)}
		var p: Dictionary = pits[k]
		if p["spent"] < 0.0 and b.soil_left() <= 0.0:
			p["spent"] = g.clock
	for k in pits:
		if not seen.has(k) and pits[k]["died"] < 0.0 and pits[k]["spent"] < 0.0:
			pits[k]["died"] = g.clock


func _summary() -> void:
	var mins := per_min.size()
	var b_all := 0
	var o_all := 0
	for r in per_min:
		b_all += int(r[1])
		o_all += int(r[2])
	var lives: Array = []
	var dists: Array = []
	var mains := 0
	var spent := 0
	for k in pits:
		var p: Dictionary = pits[k]
		var end: float = p["spent"] if p["spent"] >= 0.0 else (p["died"] if p["died"] >= 0.0 else -1.0)
		if p["spent"] >= 0.0:
			spent += 1
		if end >= 0.0:
			lives.append(end - float(p["built"]))
		dists.append(float(p["d"]))
		if p["main"]:
			mains += 1
	lives.sort()
	dists.sort()
	var tot := func(m: int, i: int) -> String: return str(int(totals[m][i])) if totals.has(m) else "-"
	print("SUMMARY map=%s opp=%s minutes=%d winner=%d" % [g.map_name, g.faction_of(1), mins, g.winner if g.over else -1])
	print("SUMMARY brood income/min %d | totals 10/15/20 min: %s / %s / %s" % [b_all / maxi(mins, 1), tot.call(10, 0), tot.call(15, 0), tot.call(20, 0)])
	print("SUMMARY opp income/min %d | totals 10/15/20 min: %s / %s / %s" % [o_all / maxi(mins, 1), tot.call(10, 1), tot.call(15, 1), tot.call(20, 1)])
	print("SUMMARY pits built %d, spent %d, most standing on the main plateau at once %d, built on the main plateau %d" % [pits.size(), spent, max_main, mains])
	print("SUMMARY pit life (built -> spent or died) median %s s over %d pits; distance from capital median %.1f, farthest %.1f tiles" % [
		str(int(lives[lives.size() / 2])) if not lives.is_empty() else "-", lives.size(),
		float(dists[dists.size() / 2]) if not dists.is_empty() else 0.0, float(dists[-1]) if not dists.is_empty() else 0.0])
	var row := "CSV"
	for r in per_min:
		row += ",%d" % int(r[1])
	print(row)
