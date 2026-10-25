extends SceneTree
## How much gold the Crown computer sits on over a long game: a Hard Crown (Balanced by default)
## against a Hard Brood (Balanced), both playing, every 30 s:
##   godot --headless --fixed-fps 30 --script res://tools/measure_crown_bank.gd -- [map:<id>] [seed:<n>] [end:<s>] [plan:<crown plan>] [foeplan:<plan>] [foe:brood|crown|clockwork] [bank:0] [peaceful:1]
## Prints "BANK t=... gold ... supply ... workers ... army ..." lines and a "BANKSUM" line: the mean and
## the peak bank, the seconds with over 500 / 1000 gold unspent, and the mean over the minutes 5-12.
## `bank:0` switches the bank spending (AI._bank_spend) off, for the "before" numbers.
var main: Node
var t := 0.0
var g
var started := false
var map := "frostmere"
var seed_ := 4242
var end_t := 720.0
var plan := "balanced"
var foeplan := "balanced"
var foe_faction := "brood"
var bank_on := true
var peaceful_foe := false
var ai_me
var samples: Array = []
var next_log := 30.0
var over500 := 0.0
var over1000 := 0.0
var peak := 0
var last_clock := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("end:"):
			end_t = float(a.substr(4))
		elif a.begins_with("plan:"):
			plan = a.substr(5)
		elif a.begins_with("foe:"):
			foe_faction = a.substr(4)
		elif a.begins_with("foeplan:"):
			foeplan = a.substr(8)
		elif a == "peaceful:1":
			peaceful_foe = true
		elif a == "bank:0":
			bank_on = false


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": plan},
			{"who": "hard", "faction": foe_faction, "colour": 1, "side": 1, "strategy": foeplan}]})
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
			if a.team == 0:
				ai_me = a
		if peaceful_foe:
			for a in g.ais:
				if a.team == 1:
					a.peaceful = true       # (a foe that defends but never attacks: the Crown reaches its cap)
		if not bank_on:
			ai_me.bank_spend_on = false
		_run()
	return false


func _count(kind: String) -> int:
	return g.buildings.filter(func(b) -> bool: return b.team == 0 and b.kind == kind and b.built and not b.dead).size()


func _value(team: int) -> int:
	var v := 0.0
	for u in g.army(team):
		v += float(u.d.get("cost", 50)) / maxf(1.0, float(u.d.get("spawn", 1)))
	return int(v)


func _run() -> void:
	last_clock = g.clock
	while g.clock < end_t and not g.over:
		await physics_frame
		var dt: float = g.clock - last_clock
		last_clock = g.clock
		var gold: int = g.players[0]["gold"]
		peak = maxi(peak, gold)
		if gold > 500:
			over500 += dt
		if gold > 1000:
			over1000 += dt
		if g.clock >= next_log:
			next_log += 30.0
			samples.append(gold)
			var soil := 0.0
			var n := 0
			for h in g.halls_of(0):
				soil += h.lode_left()
				n += 1
			print("BANK t=%3d gold %4d powder %3d supply %3d/%3d workers %2d army %4d | halls %d barracks %d breeders %d farms %d mills %d armoury %d foundry %d | cottages %d (unbuilt %d) norm %s | soil %d%% | foe army %d" % [int(g.clock), gold, int(g.players[0].get("res2", 0)), g.supply_used(0), int(g.players[0]["cap"]), g.workers(0).size(), _value(0),
				n, _count("barracks"), _count("horse_breeder"), _count("farm"), _count("powder_mill"), _count("armoury"), _count("foundry"), _count("cottage"), g.buildings.filter(func(b) -> bool: return b.team == 0 and b.kind == "cottage" and not b.built and not b.dead).size(), str(ai_me._no_room.keys()), int(100.0 * soil / maxf(1, n)), _value(1)])
	var sum := 0
	var late := 0
	var nl := 0
	for i in samples.size():
		sum += samples[i]
		if i >= 9:
			late += samples[i]
			nl += 1
	print("BANKSUM map=%s seed=%d bank=%s end=%d over=%s mean %d, mean 5:00-12:00 %d, peak %d, secs over 500 %d, secs over 1000 %d" % [map, seed_, str(bank_on), int(g.clock), str(g.over), sum / maxi(1, samples.size()), late / maxi(1, nl), peak, int(over500), int(over1000)])
	quit(0)
