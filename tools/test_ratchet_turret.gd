extends SceneTree
## Gear mode has no power and the Clockwork's static defence: no Boiler, Charging Pylon, Engine Hall or Capacitor Works
## in the build list, nothing on a card that needs one or costs energy, no batteries filling, no energy pill (the second
## resource is Tension); the Lab has no Pylon and a Ratchet Turret. A linked Ratchet Turret kills an enemy on the ground
## and one in the air in its range (its head turning to them); an unlinked one does not fire.
##   godot --headless --fixed-fps 30 --script res://tools/test_ratchet_turret.gd
const U := preload("res://tools/gear_test_util.gd")
var fails := 0


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-66s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := U.make(root)
	await process_frame
	await process_frame
	# ---- no power in gear mode
	var bl := Defs.build_list("clockwork")
	for k in Defs.ENERGY_KINDS:
		check("no %s in the gear build list" % k, not bl.has(k))
	check("the Ratchet Turret is in the gear build list", bl.has(Defs.CW_TURRET))
	var bad: Array = []
	for k in bl:
		for u in Defs.train_keys(Defs.BUILDINGS[k]["trains"], false):
			if int(Defs.UNITS[Defs.train_kind(u)].get("cost2", 0)) > 0 or Defs.energy_only(Defs.train_kind(u)):
				bad.append(u)
	check("no card trains anything that costs energy or needs power", bad.is_empty(), str(bad))
	check("the Charging Pylon cannot be built (requirement)", g.requirement_text(0, "charging_pylon") != "")
	check("the second resource is Tension", Defs.res_names("clockwork") == ["Cogs", "Tension"])
	var hall := U.hall(g, 0)
	U.step(g, 8.0)
	check("the Clocktower fills no batteries", hall.batteries == 0 and int(g.energy[0]) == 0, "%d" % hall.batteries)
	# ---- a linked turret, a ground enemy
	g.players[0]["gold"] = 5000
	var tur := U.put(g, 0, Defs.CW_TURRET, hall.cell)
	check("a Ratchet Turret links to the field", tur != null and g.gear_net.is_linked(tur))
	if tur == null:
		_end()
		return
	check("it has a head on its turntable", tur.turret != null and tur.turret.head.visible and tur.turret.head.texture != null)
	var foot := _foe(g, "labourer", tur.center() + Vector2(150, 30))
	var t := _until_dead(g, foot, 20.0)
	check("it kills an enemy on the ground in range", foot.dead, "%.1f s, %d screws" % [t, tur.turret.shots])
	check("its head turned toward it (E/SE)", tur.turret.facing in [0, 1], "facing %d" % tur.turret.facing)
	# ---- an enemy in the air
	var n0: int = tur.turret.shots
	var fly := _foe(g, "balloon", tur.center() + Vector2(-20, -160))
	t = _until_dead(g, fly, 30.0)
	check("it kills an enemy in the air in range", fly.dead, "%.1f s, %d screws" % [t, tur.turret.shots - n0])
	check("its head turned up toward it (NW/N/NE)", tur.turret.facing in [5, 6, 7], "facing %d" % tur.turret.facing)
	var f := tur.turret.facing
	U.step(g, 3.0)
	check("idle, it keeps its last facing", tur.turret.facing == f)
	# ---- unlinked: it does not fire
	var far := U.put_far(g, 0, Defs.CW_TURRET)
	check("an unlinked turret was placed", far != null and not g.gear_net.is_linked(far))
	if far != null:
		var foe := _foe(g, "labourer", far.center() + Vector2(110, 20))
		U.step(g, 6.0)
		check("an UNLINKED turret does not fire", far.turret.shots == 0 and not foe.dead, "%d screws" % far.turret.shots)
	# ---- the Lab: no Pylon, no Boiler, a built and linked turret
	var g2 := U.make(root)
	await process_frame
	await process_frame
	CwLab.setup(g2)
	var kinds := {}
	for b in g2.buildings:
		if b.team == g2.human and not b.dead:
			kinds[b.kind] = b
	check("the Lab has no Charging Pylon and no Boiler", not kinds.has("charging_pylon") and not kinds.has("boiler"), str(kinds.keys()))
	check("the Lab has a built, linked Ratchet Turret", kinds.has(Defs.CW_TURRET) and kinds[Defs.CW_TURRET].built \
			and g2.gear_net.is_linked(kinds[Defs.CW_TURRET]))
	_end()


## An enemy (team 1) standing still at p.
func _foe(g: Game, kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.auto_work = false
	u.cmd_hold()
	return u


func _until_dead(g: Game, u: Unit, limit: float) -> float:
	var t := 0.0
	while t < limit and not u.dead:
		U.step(g, 0.2)
		t += 0.2
	return t


func _end() -> void:
	print("ALL PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
