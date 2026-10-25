extends SceneTree
## The Crown computer's gold sinks (AI._bank_spend), isolated:
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_crown_bank.gd
## A Hard Crown (peaceful, nobody attacks it) at 1:30.
## (a) 800 gold (under reserve + step) is left alone: the bank logs nothing.
## (b) Supply-blocked (cap faked down to what is used) with 2,500 gold: a Cottage goes up, and the pile
##     is spent down (more than 800 gone in 40 s) rather than banked.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "greenhold", "seed": 5, "slots": [
		{"who": "human", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "hard", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var ai: AI
	for a in g.ais:
		if a.team == 1:
			ai = a
	ai.peaceful = true
	while g.clock < 90.0:
		await physics_frame
	# (b) under the threshold: nothing is bought by the bank
	g.players[1]["gold"] = 800
	await _wait(30 * 30)
	check(ai.bank_log.is_empty(), "800 gold (under reserve + step) is not touched by the bank (%s)" % str(ai.bank_log))
	# (a) supply-blocked with a pile
	await _wait(30 * 20)
	g.players[1]["gold"] = 2500
	g.players[1]["cap"] = g.supply_used(1)
	var cottages0: int = ai._mine("cottage").size()
	var gold0: int = g.players[1]["gold"]
	await _wait(30 * 40)
	check(ai._mine("cottage").size() > cottages0, "supply-blocked with a pile: a Cottage goes up (%d -> %d)" % [cottages0, ai._mine("cottage").size()])
	check(gold0 - int(g.players[1]["gold"]) > 800, "the pile is spent, not banked (%d -> %d)" % [gold0, int(g.players[1]["gold"])])
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)
