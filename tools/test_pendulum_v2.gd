extends SceneTree
## The two-armed Pendulum (v2): its arms CUT IN TURN (right, left, right: Unit.arm, each blow playing its own arm's strip,
## attack_r / attack_l, the hit on the 4th frame); a blow hits the enemies in the ARC IN FRONT and not the one behind;
## a LIGHT unit (tag "light") takes Defs.PENDULUM_SWING "vs_light" times the blow, an armoured one the plain blow less its
## armour; the blows come about every 1.4 s (damage a second about the one-armed Pendulum's 22 every 2.59 s); and the arm
## is streamed to online guests with the unit (NetSnapshot.UNIT_PROPS).
##   godot --headless --fixed-fps 30 --script res://tools/test_pendulum_v2.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-74s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	g.view_rect = Rect2(Vector2(-100000, -100000), Vector2(200000, 200000))     # (units animate only in view)
	var P := Defs.PENDULUM
	var fr: Dictionary = ArtData.UNITS[P]["frames"]
	check("the Pendulum has a strip per arm in every view", ["s", "se", "e", "ne", "n"].all(func(d: String) -> bool:
		return int(fr.get("attack_r_" + d, 0)) == 6 and int(fr.get("attack_l_" + d, 0)) == 6), str(fr))
	check("and no old one-armed swing strip", not fr.has("attack_s"))
	check("the arm of the blow under way goes to online guests", NetSnapshot.UNIT_PROPS.has("arm"))
	var hall := U.hall(g, 0)
	var at := _open_near(g, hall.center() + Vector2(0, 260))
	var pd: Unit = g._add_unit(P, 0, at)
	pd.cmd_stop()
	var polar := func(deg: float, dist: float) -> Vector2: return at + Vector2.from_angle(deg_to_rad(deg)) * dist
	var light: Unit = _foe(g, "labourer", polar.call(0.0, 40.0))          # (light: the bonus)
	var heavy: Unit = _foe(g, "brute", polar.call(-30.0, 50.0))           # (armoured, not light: the plain blow)
	var behind: Unit = _foe(g, "labourer", polar.call(180.0, 40.0))
	for o in [light, heavy, behind]:
		o.max_hp = 5000.0
		o.hp = 5000.0
		o.d = o.d.duplicate()
		o.d["damage"] = 0
	pd.facing = Vector2.RIGHT
	pd.cmd_attack(light)
	var dmg := float(Defs.UNITS[P]["damage"])
	var arms: Array = []
	var strips: Array = []
	var frames: Array = []
	var times: Array = []
	var first: Dictionary = {}
	var n := 0
	var t := 0.0
	while pd.swings < 3 and t < 10.0:
		U.step(g, 1.0 / 30.0)
		t += 1.0 / 30.0
		if String(pd.anim).begins_with("attack") and (strips.is_empty() or strips[-1] != pd.anim):
			strips.append(pd.anim)
		if pd.swings > n:
			n = pd.swings
			arms.append(pd.arm)
			frames.append(pd.frame_i)
			times.append(t)
			if n == 1:
				first = {"light": 5000.0 - light.hp, "heavy": 5000.0 - heavy.hp, "behind": 5000.0 - behind.hp}
	check("it struck three blows", pd.swings == 3, "%d in %.1f s" % [pd.swings, t])
	check("its arms take turns (right, left, right)", arms == [0, 1, 0], str(arms))
	check("each blow plays its own arm's strip", strips.slice(0, 3) == ["attack_r", "attack_l", "attack_r"], str(strips))
	check("every blow lands on the 4th frame of its strip (the sweep's hit)", frames.all(func(f) -> bool: return f == 3), str(frames))
	if times.size() == 3:
		var gap: float = (float(times[2]) - float(times[0])) / 2.0
		check("a blow about every 1.4 s", absf(gap - 1.4) < 0.12, "%.2f s" % gap)
		var dps := dmg / gap
		check("damage a second about the one-armed Pendulum's (22 every 2.59 s)", absf(dps - 22.0 / 2.59) < 1.2, "%.1f vs 8.5" % dps)
	if not first.is_empty():
		var want_l := dmg * float(Defs.PENDULUM_SWING["vs_light"]) - light.armor
		var want_h := dmg - heavy.armor
		check("the light unit in front took the blow with the light bonus", absf(float(first["light"]) - want_l) < 0.6, "%.1f, want %.1f" % [first["light"], want_l])
		check("the armoured unit in the arc took the plain blow (no bonus)", absf(float(first["heavy"]) - want_h) < 0.6, "%.1f, want %.1f" % [first["heavy"], want_h])
		check("the light bonus is a real bonus (> 1)", float(Defs.PENDULUM_SWING["vs_light"]) > 1.0)
		check("the enemy behind it was not hit", float(first["behind"]) == 0.0, "%.1f" % first["behind"])
	check("Pendulum.light_bonus: light %.2f, armoured 1" % Pendulum.light_bonus(light), Pendulum.light_bonus(heavy) == 1.0 and Pendulum.light_bonus(light) > 1.0)
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails else 0)


func _foe(g: Game, kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, _open_near(g, p))
	u.auto_work = false
	u.cmd_hold()
	return u


func _open_near(g: Game, p: Vector2) -> Vector2:
	var c := g.cell_of(g.on_map(p))
	if g.is_free(c):
		return g.cell_center(c)
	return g.cell_center(g.nearest_free(c, 6))
