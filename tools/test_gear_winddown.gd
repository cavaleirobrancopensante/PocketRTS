extends SceneTree
## Constructs stay wound on connected gear ground (inside a connected building's ring) and wind down off it: not inside an
## unlinked building's ring, nor once the building they stood by is lost.
##   godot --headless --fixed-fps 30 --script res://tools/test_gear_winddown.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-64s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	var net: GearNet = g.gear_net
	var tower := U.hall(g, 0)
	g.players[0]["gold"] = 5000
	var spring := U.put(g, 0, "spring_tower", tower.cell)
	var lone := U.put_far(g, 0, "assembly_works", 20)
	check("set-up: a linked Spring Tower and an unlinked works", spring != null and lone != null and net.linked.has(spring) and not net.linked.has(lone))
	check("ground inside the Clocktower's ring is gear ground", g.in_field(0, tower.center() + Vector2(0, 40)))
	check("ground inside a linked building's ring is gear ground", g.in_field(0, spring.center()))
	check("ground inside an UNLINKED building's ring is not", not g.in_field(0, lone.center()))
	check("the map beyond the field is not", not g.in_field(0, tower.center() + Vector2(900, 0)))
	var on: Unit = g._add_unit("thresher", 0, tower.center() + Vector2(0, 60))
	var off: Unit = g._add_unit("thresher", 0, lone.center() + Vector2(0, 80))
	on.wind = 0.5
	off.wind = 0.5
	U.step(g, 6.0)
	check("a construct on connected gear ground winds UP", on.wind > 0.9, "%.2f" % on.wind)
	check("one off the field (even by an unlinked building) winds DOWN", off.wind < 0.5, "%.2f" % off.wind)
	# lose the Spring Tower's link: a unit in its ring winds down afterwards
	var by: Unit = g._add_unit("thresher", 0, spring.center() + Vector2(0, 30))
	by.wind = 1.0
	U.step(g, 2.0)
	check("(by the linked Spring Tower it stays wound)", by.wind > 0.99, "%.3f" % by.wind)
	tower.take_damage(999999.0, null)
	U.step(g, 10.0)
	check("when the Clocktower falls the field is gone: the construct winds down", by.wind < 0.99 and not g.in_field(0, by.position), "%.3f" % by.wind)
	print("RESULT: %d failures" % fails)
	quit(1 if fails > 0 else 0)
