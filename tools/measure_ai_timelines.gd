extends SceneTree
## Measures one AI profile's build timeline against a Hard Crown computer on Balanced that defends but
## never attacks (so the numbers are the profile's own, not a fight it was dragged into):
##   godot --headless --fixed-fps 30 --script res://tools/measure_ai_timelines.gd -- faction:brood plan:rush [map:<id> seed:<n> foe:<faction> foeplan:<plan> end:<s>]
## Prints one line "TL ..." with: the first production building done, the first soldier, the
## first attack leaving, workers and army value (cost of the armed units alive) at 2:00, 3:00,
## 4:00 and 5:00. tools/run_ai_timelines.sh runs every faction and plan and builds the table
## of docs/ai_build_timelines.md.
var main: Node
var t := 0.0
var g
var started := false
var faction := "brood"
var plan := "rush"
var foe_faction := "crown"
var foe_plan := "balanced"
var map := "ashford_crossing"
var seed_ := 4242
var end_t := 420.0
var me := 1
var foe := 0
var ai_me


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("faction:"):
			faction = a.substr(8)
		elif a.begins_with("plan:"):
			plan = a.substr(5)
		elif a.begins_with("foe:"):
			foe_faction = a.substr(4)
		elif a.begins_with("foeplan:"):
			foe_plan = a.substr(8)
		elif a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("end:"):
			end_t = float(a.substr(4))


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": foe_faction, "colour": 0, "side": 0, "strategy": foe_plan},
			{"who": "hard", "faction": faction, "colour": 1, "side": 1, "strategy": plan}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for a in g.ais:
			if a.team == me:
				ai_me = a
			else:
				a.peaceful = true       # (the yardstick foe: a normal economy and a defence, but it never attacks)
		_run()
	return false


func army_value(team: int) -> float:
	var v := 0.0
	for u in g.units:
		if u.team == team and not u.dead and not u.is_worker() and (u.has_attack() or Defs.MUSKETS.has(u.kind)):
			v += float(u.d.get("cost", 50)) / maxf(1.0, float(u.d.get("spawn", 1))) + float(u.d.get("cost2", 0)) * 0.5
	return v


var prod_t := -1.0
var prod_kind := ""
var unit_t := -1.0
var attack_t := -1.0
var rows := {}


var next_dbg := 60.0


func _step() -> void:
	if OS.get_cmdline_user_args().has("debug") and g.clock >= next_dbg:
		next_dbg += 20.0
		var kinds := []
		for b in g.buildings:
			if b.team == me and not b.dead:
				kinds.append(b.kind + ("" if b.built else "*"))
		print("  dbg %d gold %d supply %d/%d workers %d | %s" % [int(g.clock), g.players[me]["gold"], g.supply_used(me), g.players[me]["cap"], g.workers(me).size(), " ".join(kinds)])
	if prod_t < 0.0:
		for b in g.buildings:
			if b.team == me and b.built and not b.dead:
				var tr: Array = b.d.get("trains", [])
				var mil := false
				for k in tr:
					if Defs.UNITS.has(k) and not bool(Defs.UNITS[k].get("worker", false)) and k != "horse":
						mil = true
				if mil and b.d.get("name", "") != "":
					prod_t = g.clock
					prod_kind = b.kind
					break
		if prod_t < 0.0 and faction == "brood" and BroodNew.father(g, me, BroodNew.FATHER) != null and BroodNew.rooted(BroodNew.father(g, me, BroodNew.FATHER)):
			prod_t = g.clock          # (the Brood's barracks: its Tyrant Sire rooted on his nest)
			prod_kind = BroodNew.FATHER
	if unit_t < 0.0 and army_value(me) > 0.0:
		unit_t = g.clock
	if attack_t < 0.0 and ai_me._attacking:
		attack_t = g.clock


func _run() -> void:
	for s in [120.0, 180.0, 240.0, 300.0, 420.0]:
		if s > end_t:
			break
		while g.clock < s and not g.over:
			await physics_frame
			_step()
		rows[int(s)] = "%d/%d" % [g.workers(me).size(), int(army_value(me))]
		if s >= 240.0:
			print("  %d:%02d plan %s attack_at %d army supply %d attacking %s verdict %s" % [int(s) / 60, int(s) % 60, ai_me.strategy, ai_me._attack_at, ai_me._army_supply(g.army(me)), str(ai_me._attacking), ai_me.scout.verdict])
		if g.over:
			break
	print("TL faction=%s plan=%s map=%s seed=%d prod=%s@%s unit=%s attack=%s | workers/army 2:00 %s 3:00 %s 4:00 %s 5:00 %s%s | foe army %d" % [
		faction, plan, map, seed_, prod_kind, _mmss(prod_t), _mmss(unit_t), _mmss(attack_t),
		rows.get(120, "-"), rows.get(180, "-"), rows.get(240, "-"), rows.get(300, "-"), " (match over)" if g.over else "", int(army_value(foe))])
	quit(0)


func _mmss(s: float) -> String:
	return "never" if s < 0.0 else "%d:%02d" % [int(s) / 60, int(s) % 60]
