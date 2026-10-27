extends SceneTree
## The Brood computer's swarm groups (AI._swarm) can hold a Raptor that has been freed meanwhile (turned into
## something else, or a corpse cleared). AI._swarm_army filtered each group with a typed lambda (u: Unit), and a freed
## object fails that conversion: an ERROR ("Cannot convert argument 1 from Object to Object", 0.14.53 QA soak, Greenhold
## free-for-all) and the group's living Raptors were not kept (the swarm fell under 6 and the wave was called off). Now the freed ones drop out and the living stay.
##   godot --headless --fixed-fps 30 --script res://tools/test_ai_swarm_freed.gd
const U := preload("res://tools/gear_test_util.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root, ["brood", "crown"])
	await process_frame
	await process_frame
	var ai := AI.new()
	ai.game = g
	ai.team = 0
	ai.difficulty = 2
	ai.process_mode = Node.PROCESS_MODE_DISABLED
	g.add_child(ai)
	g.ais.append(ai)
	var h := U.hall(g, 0)
	var live: Array = []
	for i in 8:
		live.append(g._add_unit("raptor", 0, h.center() + Vector2(150 + 12 * i, 0)))
	var r2: Unit = g._add_unit("raptor", 0, h.center() + Vector2(170, 30))
	await process_frame
	ai._swarm = [[live + [r2], h.center() + Vector2(400, 0)]]
	ai._swarm_phase = "flank"
	g.units.erase(r2)
	r2.free()
	ai._swarm_army(live, 8)
	var grp: Array = ai._swarm[0][0] if not ai._swarm.is_empty() else []
	var ok: bool = grp.size() == 8 and ai._swarm_phase != ""
	print("CHECK the swarm group keeps its 8 living Raptors and drops the freed one: %d left, phase '%s'" % [grp.size(), ai._swarm_phase])
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
