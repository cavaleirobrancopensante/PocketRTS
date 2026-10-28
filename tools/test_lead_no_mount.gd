extends SceneTree
## LEAD is its own act, never a mount (playtest 0.14.97: "they mount the horse and dismount and then it's leashed"):
##   godot --headless --fixed-fps 30 --script res://tools/test_lead_no_mount.gd
## For a Labourer, a Musketeer and an Officer told to LEAD (the button, Game.lead_order) and a Labourer right-clicked on
## a horse: no frame shows a mount strip or makes him mounted (he stays the same man, on foot); at the horse he stops
## for Unit.REINS_T (work "reins") in his REINS_POSE frame, the horse standing still and turned to him; the rein is
## drawn from then on; he walks off and the horse follows. A Musketeer right-clicked on a horse still MOUNTS it.
## Three horses in one LEAD: a pause at each. Prints PASS / FAIL and "ALL PASS" (exit 1 on a failure).
var fails := 0
var g: Game


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start({"map": "hollowfen", "seed": 4242, "slots": [
		{"who": "you", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "brood", "colour": 1, "side": 1, "strategy": "balanced"}]})
	await process_frame
	await process_frame
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	for a in g.ais:
		a.process_mode = Node.PROCESS_MODE_DISABLED
	var hall: Building = g.halls_of(0)[0]
	var mid: Vector2 = hall.center() + Vector2(0, 230)
	await _case(mid, "labourer", "button")
	await _case(mid, "labourer", "click")
	await _case(mid, "musketeer", "button")
	await _case(mid, "dismounted", "button")
	await _three(mid)
	await _mount_still(mid)
	print("lead no mount: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)


func _clear(around: Vector2) -> void:
	for u in g.units.duplicate():
		if u.position.distance_to(around) < 400.0:
			g.consume_unit(u)
	await physics_frame


func _case(mid: Vector2, kind: String, how: String) -> void:
	await _clear(mid)
	var man: Unit = g._add_unit(kind, 0, mid + Vector2(-110, 10))
	man.auto_work = false
	var horse: Unit = g._add_unit("horse", 0, mid + Vector2(40, -10))
	g.camera.position = mid
	for i in 5:
		await physics_frame
	if how == "button":
		check(g.lead_order([man]) == 1, "%s LEAD: one horse to fetch" % kind)
	else:
		check(g._horse_command([man], horse, horse.position, false) and man.order == "lead", "%s right-click on a horse: he goes to lead it" % kind)
	var mounted := false
	var mount_strip := false
	var reins_f := 0
	var pose_ok := true
	var still := true
	var turned := false
	var rein_in_pause := true
	var rein_before := false
	var t_reach := -1.0
	var p_man := Vector2.ZERO
	var p_horse := Vector2.ZERO
	var t0: float = g.clock
	for f in 150:
		await physics_frame
		if not is_instance_valid(man) or man.kind != kind:
			mounted = true
			break
		if man.is_mounted() or man.work == "mounting" or man.work == "dismounting":
			mounted = true
		if man.anim == "mount":
			mount_strip = true
		if man.work == "reins":
			if t_reach < 0.0:
				t_reach = g.clock - t0
			reins_f += 1
			var want: Array = Unit.REINS_POSE[kind]
			if reins_f > 2 and (man.anim != String(want[0]) or man.sprite.frame != int(want[1])):     # (the strip is set at the next 15 Hz tick)
				pose_ok = false
				print("   pause frame %d: %s:%d (%s)" % [reins_f, man.anim, man.sprite.frame, man.anim_dir])
			if reins_f == 1:
				p_man = man.position
				p_horse = horse.position
			elif man.position.distance_to(p_man) > 4.0 or horse.position.distance_to(p_horse) > 4.0:
				still = false
				print("   moved during the pause: man %.1f px, horse %.1f px" % [man.position.distance_to(p_man), horse.position.distance_to(p_horse)])
			if not horse.rein_shown():
				rein_in_pause = false
			if horse.facing.dot((man.position - horse.position).normalized()) > 0.7:
				turned = true
		elif t_reach < 0.0 and horse.rein_shown():
			rein_before = true
		if t_reach >= 0.0 and man.work != "reins":
			break
	check(not mounted and not mount_strip, "%s (%s): never a mount strip, never mounted, the same man" % [kind, how])
	var want_f := int(Unit.REINS_T * 30.0)
	check(reins_f >= want_f - 2 and reins_f <= want_f + 3, "%s (%s): stops %d frames at the horse's head (%.1f s after the order)" % [kind, how, reins_f, t_reach])
	check(pose_ok, "%s (%s): reaching in %s frame %d while he takes the reins" % [kind, how, Unit.REINS_POSE[kind][0], Unit.REINS_POSE[kind][1]])
	check(still, "%s (%s): he and the horse stand still meanwhile" % [kind, how])
	check(turned, "%s (%s): the horse turns its head to him" % [kind, how])
	check(not rein_before and rein_in_pause, "%s (%s): no rein before he reaches it, a rein from then on" % [kind, how])
	check(is_instance_valid(man) and horse.leader == man and man.led.has(horse) and man.order != "lead", "%s (%s): it is led and the order is done" % [kind, how])
	if not is_instance_valid(man):
		return
	man.cmd_move(man.position + Vector2(-260, 60))
	for i in 150:
		await physics_frame
	var d := horse.position.distance_to(man.position)
	check(d < Unit.LEASH_MAX * 1.6 and horse.leader == man and horse.rein_shown(), "%s (%s): walks off, the horse follows on its rein (%d px)" % [kind, how, d])


## One LEAD, three horses (lead_max): a pause at each, all three led at the end.
func _three(mid: Vector2) -> void:
	await _clear(mid)
	var man: Unit = g._add_unit("labourer", 0, mid + Vector2(-110, 10))
	man.auto_work = false
	var hs: Array = []
	for i in 3:
		hs.append(g._add_unit("horse", 0, mid + Vector2(30 + i * 45, -30 + i * 30)))
	g.camera.position = mid
	await physics_frame
	check(g.lead_order([man]) == 3, "LEAD with three horses near: three to fetch")
	var pauses := 0
	var was := false
	for f in 400:
		await physics_frame
		var now := man.work == "reins"
		if now and not was:
			pauses += 1
		was = now
		if man.led.size() == 3 and man.order != "lead":
			break
	check(pauses == 3, "a pause at each of the three horses (%d)" % pauses)
	check(man.led.size() == 3 and hs.all(func(h) -> bool: return h.leader == man and h.rein_shown()), "all three led, each on its rein")


## A Musketeer right-clicked on a horse still gets on it (mounting is unchanged).
func _mount_still(mid: Vector2) -> void:
	await _clear(mid)
	var man: Unit = g._add_unit("musketeer", 0, mid + Vector2(-110, 10))
	var horse: Unit = g._add_unit("horse", 0, mid + Vector2(40, -10))
	g.camera.position = mid
	await physics_frame
	g._horse_command([man], horse, horse.position, false)
	var mounting := false
	var reins := false
	for f in 200:
		await physics_frame
		if not is_instance_valid(man):
			break
		mounting = mounting or man.work == "mounting"
		reins = reins or man.work == "reins"
	check(mounting and not reins, "a Musketeer right-clicked on a horse mounts it (no reins pause)")
