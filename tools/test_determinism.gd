extends SceneTree
## How deterministic is the simulation? Two computers play each other on a fixed seed; the state
## hash is printed every 10 game seconds. Run it twice (separate processes) and diff the lines:
##   godot --headless --fixed-fps 30 --script res://tools/test_determinism.gd [-- map:<id> seed:<n> secs:<n> a:crown b:brood]
## Identical "HASH" lines = the same match every time (lockstep needs this).
var main: Node
var t := 0.0
var g
var map := "hollowfen"
var seed_ := 4242
var secs := 180.0
var fa := "crown"
var fb := "brood"
var next_at := 10.0


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
		elif a.begins_with("a:"):
			fa = a.substr(2)
		elif a.begins_with("b:"):
			fb = a.substr(2)


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
		main.start({"map": map, "seed": seed_, "slots": [
			{"who": "hard", "faction": fa, "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": fb, "colour": 1, "side": 1, "strategy": "balanced"}]})
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
