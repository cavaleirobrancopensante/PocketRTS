extends SceneTree
## A man whose order was to mount or lead a horse that has since been freed (killed and gone: seen in the 0.14.53 QA
## soak, a Crown soldier raised by a Missionary) must still have his work reset when he is stopped:
## Unit._reset_work used to test `order_target is Unit` before is_instance_valid, a SCRIPT ERROR that stopped the reset
## half way (his old work and path kept).
##   godot --headless --fixed-fps 30 --script res://tools/test_reset_work_freed_horse.gd
const U := preload("res://tools/gear_test_util.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root, ["crown", "brood"])
	await process_frame
	await process_frame
	var h := U.hall(g, 0)
	var man: Unit = g._add_unit("musketeer", 0, h.center() + Vector2(120, 0))
	var horse: Unit = g._add_unit("horse", 0, h.center() + Vector2(160, 0))
	await process_frame
	man.order = "mount"
	man.order_target = horse
	horse.claimed = man
	horse.free()                     # (gone for good, as a corpse that was cleared)
	man.work = "test"
	man.path = PackedVector2Array([man.position, man.position + Vector2(50, 0)])
	man.path_goal = man.position + Vector2(50, 0)
	man.cmd_stop()
	var ok: bool = man.work == "" and man.path.is_empty() and man.path_goal == Vector2.INF and man.order == "idle"
	print("CHECK stopped with a freed horse as his order target: work '%s', path %d, order %s" % [man.work, man.path.size(), man.order])
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
