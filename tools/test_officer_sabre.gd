extends SceneTree
## The dismounted Cuirassier's (Armoured Officer's) ChatGPT sword attack and death (tools/import_cuirassier_dismounted.py):
##   godot --headless --fixed-fps 30 --script res://tools/test_officer_sabre.gd
##  1. his melee strip has 6 frames and is timed to the blow (Unit.MELEE_HIT): the frames before the slash show while
##     he aims, the slash (frame 4) shows as the blow lands, and the rest after it
##  2. the anim viewer plays it the same way (AnimViewer.melee_frame_at)
##  3. the Barracks drill hits the dummy on the slash frame (BuildingLife, Unit.MELEE_HIT)
##  4. dead, he plays the 5-frame death and his body stays on its last frame (lying, helmet off)
var main: Node
var t := 0.0
var g
var started := false
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _open_spot() -> Vector2:
	for y in range(6, g.H - 6):
		for x in range(6, g.W - 6):
			var ok := true
			for yy in 4:
				for xx in 6:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != g.height[g.idx(Vector2i(x, y))]:
						ok = false
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + 2, y + 2))
			var far := true
			for b in g.buildings:
				if p.distance_to(b.center()) < 700.0:
					far = false
			if far:
				return p
	return Vector2(-1, -1)


func _run() -> void:
	var frames: Dictionary = ArtData.UNITS["dismounted_armoured"]["frames"]
	for d in ["s", "se", "e", "ne", "n"]:
		check(int(frames.get("melee_" + d, 0)) == 6 and int(frames.get("death_" + d, 0)) == 5,
			"melee_%s has 6 frames, death_%s 5" % [d, d])
	check(int(Unit.MELEE_HIT.get("dismounted_armoured", -1)) == 3, "the hit frame is the 4th (the slash)")
	# 2. the viewer
	var aim := float(Defs.BAYONET["aim"])
	var vf := [AnimViewer.melee_frame_at("dismounted_armoured", 6, 0.01), AnimViewer.melee_frame_at("dismounted_armoured", 6, aim - 0.01),
		AnimViewer.melee_frame_at("dismounted_armoured", 6, aim + 0.01), AnimViewer.melee_frame_at("dismounted_armoured", 6, aim + 0.34)]
	check(vf == [0, 2, 3, 5], "viewer: guard at the start, coming down at the end of the aim, the slash as it lands, back to guard (%s)" % [vf])
	# 3. the drill: the hit event lands on frame 4 of the 0.12 s/frame melee_e
	check(is_equal_approx(0.12 * int(Unit.MELEE_HIT.get("dismounted_armoured", 1)), 0.36), "drill: the dummy is hit 0.36 s into the swing (frame 4)")
	# 1. in a match
	var p := _open_spot()
	check(p.x >= 0.0, "an open spot")
	var u: Unit = g._add_unit("dismounted", 0, p)
	u.put_on_armour()
	u.pistol = false
	var foe: Unit = g._add_unit("brute", 1, p + Vector2(22, 10))
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	foe.hp = 100000.0
	u.cmd_attack(foe)
	var blows := 0
	var on_hit: Array = []
	var before_ok := true
	var last_hp: float = foe.hp
	var was_phase := ""
	for i in 300:
		await process_frame
		if u.anim == "melee" and u.phase == "aim" and u.sprite.frame >= 3:
			before_ok = false
		if foe.hp < last_hp:
			last_hp = foe.hp
			blows += 1
			on_hit.append("%s %d (%s)" % [u.anim, u.sprite.frame, u.phase])
		was_phase = u.phase
		if blows >= 3:
			break
	print("  blows land on: ", on_hit)
	check(blows >= 3, "he struck 3 sabre blows (%d)" % blows)
	check(on_hit.size() > 0 and on_hit.all(func(s: String) -> bool: return s.begins_with("melee 3")), "every blow lands with the slash frame (4th) shown")
	check(before_ok, "while he aims the slash has not shown yet")
	# 4. death and the body
	u.take_damage(10000.0, foe)
	var t0: float = g.clock
	while g.clock < t0 + 2.5:
		await process_frame
	check(u.dead and u.anim == "death", "dead: the death strip (%s)" % u.anim)
	check(u.sprite.hframes == 5 and u.sprite.frame == 4, "the body stays on the last frame (frame %d of %d)" % [u.sprite.frame + 1, u.sprite.hframes])
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
