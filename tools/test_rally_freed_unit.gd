extends SceneTree
## A building rallied on one of its own units (the rally follows him) when that unit is freed without dying first
## (a grub turned into a building, a man who mounts and becomes a rider): the building's tick tested
## `rally_target is Unit` on the freed object, a SCRIPT ERROR that stopped the rest of the tick, every frame.
## Now the rally lets go and stays where he was last, and the tick runs on (seen here by its rubble timer, which only
## the end of the tick moves).
##   godot --headless --fixed-fps 30 --script res://tools/test_rally_freed_unit.gd
const U := preload("res://tools/gear_test_util.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root, ["crown", "brood"])
	await process_frame
	await process_frame
	var h := U.hall(g, 0)
	var man: Unit = g._add_unit("labourer", 0, h.center() + Vector2(150, 40))
	await process_frame
	h.rally_target = man
	h._tick_building(1.0 / 30.0)
	var at := h.rally
	g.units.erase(man)
	man.free()                          # (gone without dying)
	h.dead = true                       # (only so the tick's last part shows it ran: the rubble timer)
	h.rubble_t = 0.0
	h._tick_building(0.5)
	var ran: bool = h.rubble_t > 0.4
	h.dead = false
	h.rubble_t = 0.0
	var ok: bool = ran and not is_instance_valid(h.rally_target) and h.rally == at
	print("CHECK the rally lets go of a freed unit and the tick runs on: ran %s, rally %s (he was at %s)" % [ran, h.rally, at])
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
