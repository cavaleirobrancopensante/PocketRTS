extends SceneTree
## The Jack's two launchers and the Swift's painted peck. A Jack shooting at the ground fires its two arms IN TURN: two
## shots in a row leave from two different drill tips (Defs.JACK_SHOT "tips", one set per arm, mirrored for the west
## views) and each plays its own arm's strip (attack_r, then attack_l); a third shot is the first arm's again. A Swift's
## blow lands on the stab, the 3rd frame of its painted peck strip (art/redraws/cuckoo_peck.png), or the 4th (held in).
##   godot --headless --fixed-fps 30 --script res://tools/test_jack_arms.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	g.view_rect = Rect2(Vector2(-100000, -100000), Vector2(200000, 200000))     # (units animate only in view)
	var hall := U.hall(g, 0)
	check("the Jack has a strip per arm", ArtData.UNITS["jack"]["frames"].has("attack_r_s") and ArtData.UNITS["jack"]["frames"].has("attack_l_s"))
	check("Defs.JACK_SHOT has a tip per arm and view", (Defs.JACK_SHOT["tips"] as Dictionary).has("r") and (Defs.JACK_SHOT["tips"] as Dictionary).has("l"))
	# two cases: the target to its south (the arms far apart on screen) and to its west (a mirrored view)
	for case in [["south", Vector2(0, 140)], ["west", Vector2(-150, 0)]]:
		var at := _open_near(g, hall.center() + Vector2(260, 230))
		var j: Unit = g._add_unit(Defs.JACK, 0, at)
		j.cmd_stop()
		var foe := _foe(g, "labourer", _open_near(g, at + (case[1] as Vector2)))
		foe.max_hp = 99999.0
		foe.hp = 99999.0
		j.cmd_attack(foe)
		var tips: Array = []
		var arms: Array = []
		var strips: Array = []
		var n := j.shots
		var t := 0.0
		while tips.size() < 3 and t < 20.0:
			U.step(g, 1.0 / 30.0)
			t += 1.0 / 30.0
			if String(j.anim).begins_with("attack") and (strips.is_empty() or strips[-1] != j.anim):
				strips.append(j.anim)
			if j.shots > n:
				n = j.shots
				tips.append(j.last_tip - j.position)
				arms.append(j.arm)
		var tag := String(case[0])
		check("%s: it fired three screws" % tag, tips.size() == 3, "%d in %.1f s" % [tips.size(), t])
		if tips.size() == 3:
			check("%s: two shots in a row leave from two different tips" % tag, (tips[0] as Vector2).distance_to(tips[1]) > 3.0, "%s then %s" % [tips[0], tips[1]])
			check("%s: the arms take turns (right, left, right)" % tag, arms == [0, 1, 0], str(arms))
			check("%s: the third screw leaves the first arm's tip again" % tag, (tips[0] as Vector2).distance_to(tips[2]) < 1.0, "%s, %s" % [tips[0], tips[2]])
			var dd: Array = Unit.DIR_FLIP[posmod(int(round(j.facing.angle() / (PI / 4.0))), 8)]
			var want: Vector2 = Defs.JACK_SHOT["tips"]["r"][String(dd[0])]
			if bool(dd[1]):
				want.x = -want.x
			check("%s: the first screw leaves the right arm's tip for its view (%s%s)" % [tag, dd[0], " mirrored" if dd[1] else ""], (tips[0] as Vector2).distance_to(want) < 1.0, "%s, want %s" % [tips[0], want])
		check("%s: each shot plays its own arm's strip" % tag, strips.slice(0, 3) == ["attack_r", "attack_l", "attack_r"], str(strips))
		j.die()
		foe.die()
		U.step(g, 0.5)
	# ---- the Swift: the blow lands on the stab (the 3rd frame of its peck)
	var p := _open_near(g, hall.center() + Vector2(-200, 260))
	var sw: Unit = g._add_unit(Defs.CUCKOO, 0, p)
	sw.cmd_stop()
	var prey := _foe(g, "balloon", p + Vector2(60, -10))
	prey.max_hp = 99999.0
	prey.hp = 99999.0
	check("the Swift's peck strip is the painted one (6 frames)", int(ArtData.UNITS["cuckoo"]["frames"].get("attack_e", 0)) == 6, str(ArtData.UNITS["cuckoo"]["frames"].get("attack_e", 0)))
	sw.cmd_attack(prey)
	var hits: Array = []
	var hp0 := prey.hp
	var tt := 0.0
	while hits.size() < 3 and tt < 20.0:
		U.step(g, 1.0 / 30.0)
		tt += 1.0 / 30.0
		if prey.hp < hp0:
			hp0 = prey.hp
			hits.append([sw.anim, sw.frame_i])
	check("the Swift pecked three times", hits.size() == 3, "%d in %.1f s" % [hits.size(), tt])
	# (frames advance on the 66 ms animation tick: the stab, the 3rd frame, or the stab held, the 4th)
	var on_stab := hits.all(func(h: Array) -> bool: return h[0] == "attack" and int(h[1]) >= 2 and int(h[1]) <= 3)
	check("each blow lands on the stab (the 3rd frame of the peck, or the 4th: held in)", on_stab and not hits.is_empty(), str(hits))
	_end()


func _foe(g: Game, kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.auto_work = false
	u.cmd_hold()
	return u


func _open_near(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 6))


func _end() -> void:
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
