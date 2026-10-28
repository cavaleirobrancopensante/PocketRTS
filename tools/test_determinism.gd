extends SceneTree
## How deterministic is the simulation? Two computers play each other on a fixed seed; the state
## hash is printed every 10 game seconds. Run it twice (separate processes) and diff the lines:
##   godot --headless --fixed-fps 30 --script res://tools/test_determinism.gd [-- map:<id> seed:<n> secs:<n> f0:<faction> f1:<faction> budget gearturn:0|1]
## Identical "HASH" lines = the same match every time (lockstep needs this).
var main: Node
var t := 0.0
var g
var map := "hollowfen"
var seed_ := 4242
var secs := 180.0
var facs := ["crown", "brood"]          # (f0:<faction> f1:<faction>: e.g. f0:clockwork f1:crown for the Clockwork's units)
var next_at := 10.0
var budget := false                     # (budget: lift the path queue's time limit, as tools/perf_bench.gd does: see docs/pathfinding_audit.md)
var gear_turn := -1                     # (gearturn:0 / gearturn:1: TURNING GEARS off / on for the match; else the setting)


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
		elif a.begins_with("f0:"):
			facs[0] = a.substr(3)
		elif a.begins_with("f1:"):
			facs[1] = a.substr(3)
		elif a == "budget":
			budget = true
		elif a.begins_with("gearturn:"):
			gear_turn = int(a.substr(9))


func state_hash() -> int:
	var h := 17
	for u in g.units:
		if is_instance_valid(u):
			h = hash([h, u.kind, u.team, snappedf(u.position.x, 0.001), snappedf(u.position.y, 0.001), snappedf(u.hp, 0.001), u.dead])
	for b in g.buildings:
		if is_instance_valid(b):
			h = hash([h, b.kind, b.team, b.cell, snappedf(b.hp, 0.001), b.built])
	for p in g.players:
		h = hash([h, int(p["gold"]), snappedf(float(p["res2"]), 0.001)])
	return h


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		var cfg := {"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": facs[0], "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": facs[1], "colour": 1, "side": 1, "strategy": "balanced"}]}
		if gear_turn >= 0:
			cfg["gear_turn"] = gear_turn == 1
		main.start(cfg)
		if budget and main.game:
			main.game.path_budget_us = 1 << 30
		return false
	if main.game == null:
		return false
	g = main.game
	paused = false
	if g.clock >= next_at:
		print("HASH %5.0f units=%d bld=%d %d" % [next_at, g.units.size(), g.buildings.size(), state_hash()])
		next_at += 10.0
	if g.clock >= secs or g.over:
		print("DONE")
		quit(0)
	return false
