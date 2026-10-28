extends SceneTree
## TURNING GEARS in a whole match (docs/gear_turn.md): a Hard Clockwork computer against a Hard Crown computer that attacks,
## TURNING GEARS on. Every unit's time riding a band in one go is watched; no computer unit may ride round for long (its AI
## walks idle and HOLD units off; fighting and walking ones pass over), and the match must not stall.
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_turn_match.gd [-- map:<id> seed:<n> minutes:<m> vs:<faction>]
## Prints how many units rode a band at all, the longest ride by order, the step-offs, and a HASH line every minute (run it
## twice and compare them: the same match every time).
var main: Node
var t := 0.0
var g
var fails := 0
var map := "ashford_crossing"
var seed_ := 4242
var minutes := 9.0
var vs := "crown"
var next_at := 60.0
var ride := {}            # unit -> seconds riding in one go
var worst := {}           # order -> [seconds, kind, team]
var riders := {}          # units that rode a band at all
var MAX_RIDE := 20.0      # s: no computer unit rides round longer than this in one go (a fighter standing in its fight may take a while)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("minutes:"):
			minutes = float(a.substr(8))
		elif a.begins_with("vs:"):
			vs = a.substr(3)


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func state_hash() -> int:
	var h := 17
	for u in g.units:
		if is_instance_valid(u):
			h = hash([h, u.kind, u.team, snappedf(u.position.x, 0.001), snappedf(u.position.y, 0.001), snappedf(u.hp, 0.001), u.dead])
	for b in g.buildings:
		if is_instance_valid(b):
			h = hash([h, b.kind, b.team, b.cell, snappedf(b.hp, 0.001), b.built])
	return h


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		Settings.gear_turn = true
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": "clockwork", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": vs, "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for u in g.units:
		if not is_instance_valid(u) or u.dead:
			continue
		if u.gt_carry != Vector2.ZERO:
			riders[u] = true
			ride[u] = float(ride.get(u, 0.0)) + delta
			var o: String = u.order
			if u.target != null and is_instance_valid(u.target):
				o += "+fighting"
			if float(ride[u]) > float(worst.get(o, [0.0])[0]):
				worst[o] = [float(ride[u]), u.kind, u.team]
		elif ride.has(u):
			ride.erase(u)
	if g.clock >= next_at:
		print("HASH %4.0f units=%d riding=%d %d" % [next_at, g.units.size(), ride.size(), state_hash()])
		next_at += 60.0
	if g.clock >= minutes * 60.0 or g.over:
		check("the match ran (or ended)", true, "%.0f s, over %s" % [g.clock, g.over])
		check("TURNING GEARS was on in it", Defs.gear_turn and bool(main.last_cfg.get("gear_turn", false)))
		print("NOTE  %d units rode a band at some point" % riders.size())
		var steps := 0
		var failed := 0
		for u in g.units:
			if is_instance_valid(u):
				steps += u.steps_taken
				failed += u.steps_failed
		print("NOTE  step-offs by the computer: %d (pinned and gave up: %d) among the units alive" % [steps, failed])
		var bad := []
		for o in worst:
			print("NOTE  longest ride in one go, order %-16s %.1f s (%s, team %d)" % [o, worst[o][0], worst[o][1], worst[o][2]])
			if not String(o).contains("+fighting") and float(worst[o][0]) > MAX_RIDE:
				bad.append(o)
		check("no computer unit riding round over %.0f s unless fighting" % MAX_RIDE, bad.is_empty(), str(bad))
		print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
		quit(1 if fails > 0 else 0)
	return false
