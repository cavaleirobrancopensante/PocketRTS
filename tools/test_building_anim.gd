extends SceneTree
## Buildings animate only while they're in use (Building.in_use):
##   godot --headless --fixed-fps 30 --script res://tools/test_building_anim.gd
##  1. the Powder Mill's horse: none while it's built up, none on the ruin; it stands still on
##     its track while nobody works the mill, walks round it (the runner stone and arm turning with it)
##     while a Labourer works there, and comes to a halt again when he leaves; behind the post
##     and millstone on the far half of the track (the runner over it), in front on the near half
##  2. the Farm's sails: still while nobody works its fields, turning while somebody does
##  3. the Foundry's smoke: none while it's idle, puffs while it trains something
##  4. BuildingLife: the Town Hall's bell swings only while it trains; the Barracks' drilling man,
##     the Horse Breeder's paddock horses and the Armoury's inventor show only while they work;
##     the Church's windows glow while a Missionary heals; nothing moves under the fog
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)


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


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _run() -> void:
	origin = _open_area(22, 14)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	g.players[0]["gold"] = 20000
	g.players[0]["res2"] = 5000.0
	g.players[0]["cap"] = 100
	g.camera.position = Vector2(origin + Vector2i(11, 7)) * Defs.TILE
	await _mill()
	await _farm()
	await _foundry()
	# the second-generation buildings (BuildingLife), on fresh ground
	origin = _open_area(30, 14)
	if origin.x < 0:
		check(false, "open ground for the new buildings")
	else:
		await _bell("town_hall", "labourer", Vector2i(1, 2))
		await _drill()
		await _paddock()
		await _yard()
		await _coats()
		await _inventor()
		await _church()
		await _fog()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


func _labourer(b: Building) -> Unit:
	var u: Unit = g._add_unit("labourer", 0, b.center() + Vector2(0, b.rect().size.y * 0.5 + 20))
	await physics_frame
	u.auto_work = false          # (stopped, it stays idle: doesn't go back to a post by itself)
	u.cmd_gather(b)
	return u


func _mill() -> void:
	var site: Building = g._add_building("powder_mill", 0, origin + Vector2i(14, 2), false)
	await wait(0.6)
	check(site._mill_state == "" and not site._mill_horse.visible and not site._mill_run.visible, "no horse or runner while the mill is built up")
	site.die()
	var m: Building = g._add_building("powder_mill", 0, origin + Vector2i(2, 2), true)
	await wait(2.0)
	check(m._mill_state == "built" and m._mill_horse.visible and m._mill_run.visible, "the built mill shows its horse and runner")
	var a0: float = m._mill_a
	await wait(1.0)
	check(m._mill_v == 0.0 and m._mill_a == a0 and m._mill_horse.frame == 0, "nobody working it: the horse stands still")
	var u := await _labourer(m)
	check(await wait_for(func() -> bool: return m.working_crew() > 0, 25.0), "a Labourer works the mill")
	await wait(2.0)
	var a1: float = m._mill_a
	await wait(1.0)
	var step := fposmod(m._mill_a - a1, TAU)
	check(m._mill_v == 1.0 and absf(step - TAU / float(Building.MILL_ART["lap"])) < 0.05,
		"worked: the horse walks round at a lap every %d s (%.2f rad in 1 s)" % [int(Building.MILL_ART["lap"]), step])
	var frames := {}
	for i in 30:
		frames[m._mill_horse.frame] = true
		await physics_frame
	check(frames.size() >= 3, "its walk frames play (%d seen)" % frames.size())
	# the runner turns with the horse: its angle is the horse's, continuously (no snapping)
	var r_ok := true
	var r_seen := {}
	for i in 20:
		r_ok = r_ok and is_equal_approx(fposmod(m._mill_run_top.rotation, TAU), fposmod(m._mill_a, TAU)) \
			and m._mill_run_under.rotation == m._mill_run_top.rotation
		r_seen[snappedf(m._mill_run_top.rotation, 0.001)] = true
		await physics_frame
	check(r_ok and r_seen.size() >= 15, "worked: the runner's angle is the horse's, continuous (%d angles in 20 frames)" % r_seen.size())
	check(is_equal_approx(m._mill_run.scale.y, 9.5 / 18.5) and m._mill_run_top.scale.y > 0.0 and m._mill_run_under.position.y > 0.0,
		"the runner is squashed like the track, its darker copy lower")
	# the far half: behind the post and stone, the sweep in front; the near half: in front
	m._mill_a = PI * 1.5
	m._place_mill_horse(true)
	var hi: int = m._mill_horse.get_index()
	check(m._mill_stone.visible and hi < m._mill_stone.get_index() and m._mill_stone.get_index() < m._mill_run.get_index(),
		"far half: the millstone over the horse, the runner over both")
	m._mill_a = PI * 0.5
	m._place_mill_horse(true)
	check(not m._mill_stone.visible and m._mill_run.get_index() < m._mill_horse.get_index(), "near half: the horse over the runner")
	check(is_equal_approx(m._mill_run_top.rotation, PI * 0.5), "the runner follows the horse to the near half (pointing at it)")
	u.cmd_stop()
	await wait(0.6)
	check(m.working_crew() == 0, "the Labourer leaves")
	await wait(2.0)
	var a2: float = m._mill_a
	await wait(0.5)
	var rot2: float = m._mill_run_top.rotation
	await wait(0.5)
	check(m._mill_v == 0.0 and m._mill_a == a2 and m._mill_horse.frame == 0, "nobody working it: the horse halts")
	check(m._mill_run_top.rotation == rot2 and is_equal_approx(fposmod(rot2, TAU), fposmod(a2, TAU)), "and the runner halts with it at its angle")
	m.hp = m.max_hp * 0.3
	m._update_sprite()
	check(m._mill_state == "damaged" and m._mill_horse.visible and m._mill_run.visible, "damaged: the horse and runner still there")
	m.die()
	check(m._mill_state == "" and not m._mill_horse.visible and not m._mill_run.visible, "destroyed: no horse or runner")


func _farm() -> void:
	var f: Building = g._add_building("farm", 0, origin + Vector2i(2, 7), true)
	await wait(2.5)
	var fr: int = f.sails.frame
	await wait(1.5)
	check(f._sail_v == 0.0 and f.sails.frame == fr, "nobody in the fields: the sails stand still")
	var u := await _labourer(f)
	check(await wait_for(func() -> bool: return f.working_crew() > 0, 25.0), "a Labourer works the farm")
	await wait(2.0)
	var seen := {}
	for i in 60:
		seen[f.sails.frame] = true
		await physics_frame
	check(f._sail_v == 1.0 and seen.size() >= 3, "worked: the sails turn (%d frames in 2 s)" % seen.size())
	u.cmd_stop()
	await wait(0.6)
	var v_mid: float = f._sail_v
	await wait(2.0)
	check(v_mid > 0.0 and v_mid < 1.0 and f._sail_v == 0.0, "left: the sails slow to a stop (%.2f after 0.6 s)" % v_mid)


func _smoke_near(b: Building) -> int:
	var n := 0
	for c in g.get_children():
		if c is Effect and c.position.distance_to(b.global_position + Vector2(0, -50)) < 90.0:
			n += 1
	return n


func _foundry() -> void:
	var f: Building = g._add_building("foundry", 0, origin + Vector2i(14, 8), true)
	g.camera.position = f.center()
	await wait(3.0)
	check(not f._in_use and _smoke_near(f) == 0, "an idle Foundry: no smoke")
	f.queue.append("balloon")
	f.kits.append({})
	var puffs := 0
	for i in 90:
		puffs = maxi(puffs, _smoke_near(f))
		await physics_frame
	check(f._in_use and puffs > 0, "training: it smokes (%d puffs)" % puffs)


## Train `key` at `b` the plain way (paid, queued).
func _train(b: Building, key: String) -> void:
	var err: String = g.train(b, key)
	if err != "":
		print("  (train %s: %s)" % [key, err])


func _bell(kind: String, unit: String, cell: Vector2i) -> void:
	var h: Building = g._add_building(kind, 0, origin + cell, true)
	g.camera.position = h.center()
	await wait(1.5)
	var L: BuildingLife = h.life
	check(L != null and L.bell != null and L.bell.visible and L.belfry.visible, "%s: the bell hangs in its belfry" % kind)
	var f0: int = L.bell.frame
	await wait(1.5)
	check(L.bell.frame == f0 and f0 == 0, "%s idle: the bell hangs still" % kind)
	_train(h, unit)
	var seen := {}
	for i in 90:
		seen[L.bell.frame] = true
		await physics_frame
	check(L.training and seen.size() >= 3, "%s training: the bell swings (%d frames in 3 s)" % [kind, seen.size()])
	h.queue.clear()
	h.kits.clear()
	await wait(3.0)
	check(not L.training and L.bell.frame == 0, "%s: the swing finishes and it hangs still" % kind)
	h.hp = h.max_hp * 0.3
	h._update_sprite()
	check(L.bell_state == "damaged" and L.bell.visible, "%s damaged: the bell is still there" % kind)
	h.die()
	check(L.bell_state == "" and not L.bell.visible and not L.belfry.visible, "%s destroyed: no bell" % kind)


func _drill() -> void:
	g._add_building("powder_mill", 0, origin + Vector2i(24, 2), true)     # (the Musketeer needs one)
	var br: Building = g._add_building("barracks", 0, origin + Vector2i(8, 2), true)
	g.camera.position = br.center()
	await wait(1.5)
	var L: BuildingLife = br.life
	check(L != null and L.man != null and not L.man.visible, "Barracks idle: nobody drills on the yard")
	_train(br, "musketeer")
	await wait(1.5)
	check(L.man.visible, "Barracks training: a Musketeer drills")
	var seen := {}
	var shots := 0
	var smoke0 := 0
	for i in 150:
		seen[L.man.frame + 100 * L._man_shown] = true
		await physics_frame
	check(seen.size() >= 4, "he plays aim, fire and reload (%d frames in 5 s)" % seen.size())
	br.queue.clear()
	br.kits.clear()
	await wait(1.0)
	check(not L.man.visible, "the queue empty: he leaves the yard")
	br.die()
	check(L.man_state == "" and not L.man.visible, "destroyed: nobody there")


func _paddock() -> void:
	var hb: Building = g._add_building("horse_breeder", 0, origin + Vector2i(16, 2), true)
	g.camera.position = hb.center()
	await wait(1.5)
	var L: BuildingLife = hb.life
	check(L != null and L.horses.size() >= 2, "the Horse Breeder has paddock horses")
	check(L.horses_shown() == 1 and L.horses[0].visible and not L.horses[1].visible, "idle: one horse stands in the paddock")
	var p0: Vector2 = L._h_pos[0]
	await wait(2.0)
	check(L._h_pos[0] == p0, "idle: it stands still")
	_train(hb, "horse")
	await wait(1.0)
	check(L.horses_shown() == 2 and L.horses[1].visible, "training: two horses")
	var moved := false
	var inside := true
	for i in 240:
		var d0: Vector2 = L._h_pos[0] - L._pad_c
		var d1: Vector2 = L._h_pos[1] - L._pad_c
		for d in [d0, d1]:
			if pow(d.x / (L._pad_r.x * 1.02), 2.0) + pow(d.y / (L._pad_r.y * 1.02), 2.0) > 1.0:
				inside = false
		moved = moved or L._h_pos[0] != p0
		await physics_frame
	check(moved, "training: a horse walks about")
	check(inside, "they keep to the paddock")
	hb.die()
	check(L.pad_state == "" and L.horses_shown() == 0, "destroyed: no horses")


## The Barracks' yard: the dummy, the horse prop (with a breeder), and a drill per man trained.
func _yard() -> void:
	var br: Building = g._add_building("barracks", 0, origin + Vector2i(8, 8), true)
	g.camera.position = br.center()
	await wait(1.0)
	var L: BuildingLife = br.life
	check(L.dummy.visible and not L.prop.visible, "the yard: the dummy stands, no prop without a Horse Breeder")
	var path := func(i: int) -> String: return L._seg_tex[i].resource_path
	var cases := [["musketeer", false, "drill_musketeer/aim_e"], ["musketeer", true, "drill_musketeer_armoured/aim_e"],
		["dismounted", false, "drill_dismounted/aim_e"], ["dismounted", true, "drill_dismounted_armoured/aim_e"],
		["cuirassier", false, "drill_dismounted/idle_e"], ["cuirassier", true, "drill_dismounted_armoured/idle_e"],
		["dragoon", false, "drill_musketeer/aim_e"], ["dragoon", true, "drill_musketeer_armoured/aim_e"]]
	for c in cases:
		br.queue.clear()
		br.kits.clear()
		br.add_entry(c[0], {"armour": c[1]})
		await wait(0.7)
		check(L.man.visible and String(path.call(0)).contains(c[2]), "no prop: %s%s drills with %s" % ["armoured " if c[1] else "", c[0], c[2]])
	# a Horse Breeder: the prop stands (twice-a-second check), and goes with the last one
	var hb: Building = g._add_building("horse_breeder", 0, origin + Vector2i(18, 8), true)
	await wait(1.2)
	check(L.prop.visible and L.has_breeder, "a Horse Breeder built: the prop stands in the yard")
	cases = [["musketeer", false, "drill_musketeer/aim_e"], ["musketeer", true, "drill_musketeer_armoured/aim_e"],
		["dismounted", false, "drill_dismounted/aim_e"], ["dismounted", true, "drill_dismounted_armoured/aim_e"],
		["cuirassier", false, "drill_horseman/mount_e"], ["cuirassier", true, "drill_cuirassier/mount_e"],
		["dragoon", false, "drill_dragoon/mount_e"], ["dragoon", true, "drill_dragoon_armoured/mount_e"]]
	for c in cases:
		br.queue.clear()
		br.kits.clear()
		br.add_entry(c[0], {"armour": c[1]})
		await wait(0.4)
		check(L.man.visible and String(path.call(0)).contains(c[2]), "prop: %s%s drills with %s" % ["armoured " if c[1] else "", c[0], c[2]])
	# the horseman climbs on and gets off again (strip played backwards), swinging at the dummy between
	br.queue.clear()
	br.kits.clear()
	br.add_entry("cuirassier", {"armour": false})
	await wait(0.3)
	var back := false
	var hits := false
	var mounted_at_prop := false
	var flashed := false
	var intact := true
	for i in 200:
		for s in L._seg_flag.size():
			back = back or (L._seg_flag[s] & 8) != 0
		mounted_at_prop = mounted_at_prop or (L.man.position == Vector2(DRILL_ART_STATE(L)["prop"]))
		if L._dummy_t > 0.0:
			flashed = true
			hits = hits or L.dummy.texture.resource_path.ends_with("dummy_damaged.png")
		elif flashed:
			intact = intact and L.dummy.texture.resource_path.ends_with("dummy_intact.png")
		await physics_frame
	check(back and mounted_at_prop, "Horseman: mounts the prop and dismounts (backwards)")
	check(hits and intact, "the dummy shows the ripped art on a hit and the intact one after")
	# the Dragoon stands next to the prop to shoot
	br.queue.clear()
	br.kits.clear()
	br.add_entry("dragoon", {"armour": false})
	await wait(0.3)
	var side := false
	var shots := 0
	for i in 200:
		side = side or L.man.position == Vector2(DRILL_ART_STATE(L)["side"])
		await physics_frame
	check(side, "Dragoon: climbs off and stands next to the prop to shoot")
	# the first unit changes: the drill switches at once
	br.queue.clear()
	br.kits.clear()
	br.add_entry("musketeer", {})
	br.add_entry("dragoon", {})
	await wait(0.2)
	check(String(path.call(0)).contains("drill_musketeer/aim_e"), "queue: Musketeer first")
	br.take_entry(0)
	await wait(0.2)
	check(String(path.call(0)).contains("drill_dragoon/mount_e"), "the first one trained: the drill switches to the Dragoon's")
	# idle and fogged: nobody on the yard, the dummy and prop stay
	br.queue.clear()
	br.kits.clear()
	await wait(1.0)
	check(not L.man.visible and L.dummy.visible and L.prop.visible, "idle: nobody drills, the dummy and prop stand")
	hb.die()
	await wait(1.2)
	check(not L.prop.visible and not L.has_breeder, "the last Horse Breeder lost: the prop is gone")
	br.die()
	check(not L.dummy.visible and not L.prop.visible and not L.man.visible, "destroyed: no dummy, no prop")


func DRILL_ART_STATE(L: BuildingLife) -> Dictionary:
	return BuildingLife.DRILL_ART["states"][L.man_state]


## The Horse Breeder's queued horses: their coats are decided when queued, the paddock shows
## them, the horse comes out in the same one, a cancelled one gives no horse back.
func _coats() -> void:
	var hb: Building = g._add_building("horse_breeder", 0, origin + Vector2i(18, 8), true)
	g.camera.position = hb.center()
	await wait(1.2)
	var L: BuildingLife = hb.life
	var gold0: int = g.players[0]["gold"]
	_train(hb, "horse")
	_train(hb, "horse")
	var ok := hb.queue.size() == 2
	for i in 2:
		ok = ok and HorseCoat.COATS.has(String(hb.kit_at(i).get("coat", "")))
	check(ok, "a queued horse has its coat decided at queue time")
	hb.kits[0] = {"coat": "white"}
	hb.kits[1] = {"coat": "spotted"}
	await wait(1.0)
	check(L._h_coat[0] == "white" and L._h_coat[1] == "spotted", "the busy paddock horses wear the queued horses' coats (%s, %s)" % [L._h_coat[0], L._h_coat[1]])
	var m0: ShaderMaterial = L.horses[0].material
	check(int(m0.get_shader_parameter("coat")) == HorseCoat.COATS.find("white"), "the first paddock horse's shader shows white")
	# it comes out in the same coat
	var n0: int = g.units.size()
	g.spawn_trained(hb, "horse", hb.kit_at(0))
	var u: Unit = g.units.back()
	check(g.units.size() == n0 + 1 and u.kind == "horse" and u.coat == "white", "the horse comes out white, as queued")
	# a cancelled one: refund, no horse walks out
	var horses0 := 0
	for x in g.units:
		if x.kind == "horse":
			horses0 += 1
	var gold1: int = g.players[0]["gold"]
	g.cancel_train(hb)
	var horses1 := 0
	for x in g.units:
		if x.kind == "horse":
			horses1 += 1
	check(horses1 == horses0 and int(g.players[0]["gold"]) == gold1 + int(Defs.UNITS["horse"]["cost"]), "cancelling a queued horse refunds it and spawns no horse")
	# idle again: the building's own coats
	hb.queue.clear()
	hb.kits.clear()
	await wait(1.0)
	check(L._h_coat[0] == L._h_default[0] and L._h_coat[1] == L._h_default[1], "idle: the paddock keeps its own coats")
	# the odds are the same
	var n := {}
	for i in 4000:
		var c := HorseCoat.pick()
		n[c] = int(n.get(c, 0)) + 1
	check(absi(int(n["dark"]) - 1200) < 150 and absi(int(n["white"]) - 400) < 100, "HorseCoat.pick keeps its odds")
	gold0 = gold0
	hb.die()


func _inventor() -> void:
	var ar: Building = g._add_building("armoury", 0, origin + Vector2i(2, 8), true)
	g.camera.position = ar.center()
	await wait(1.5)
	var L: BuildingLife = ar.life
	check(L != null and L.inv != null and not L.inv.visible, "Armoury idle: no inventor on the roof")
	var key := ""
	for k: String in Defs.RESEARCH:
		if Defs.RESEARCH[k]["at"] == "armoury" and g.research_problem(ar, k) == "":
			key = k
			break
	check(key != "", "an Armoury research to start")
	if key == "":
		return
	g.start_research(ar, key)
	await wait(1.5)
	check(L.inv.visible, "researching: the inventor is at his bench")
	var seen := {}
	for i in 240:
		seen[L.inv.frame] = true
		await physics_frame
	check(seen.size() >= 4 and seen.has(int(BuildingLife.INVENTOR_ART["bang"])), "he tinkers and the barrel goes off (%d frames in 8 s)" % seen.size())
	ar.queue.clear()
	ar.kits.clear()
	await wait(1.0)
	check(not L.inv.visible, "research over: he is gone")
	ar.die()
	check(L.inv_state == "", "destroyed: no inventor")


func _church() -> void:
	var c: Building = g._add_building("church", 0, origin + Vector2i(10, 8), true)
	g.camera.position = c.center()
	await wait(1.5)
	var L: BuildingLife = c.life
	check(L != null and L.lit != null and not L.lit.visible and L.bell.visible, "Church: dark windows, its bell in the belfry")
	var m: Unit = g._add_unit("missionary", 0, c.center() + Vector2(0, c.rect().size.y * 0.5 + 30))
	var w: Unit = g._add_unit("musketeer", 0, m.position + Vector2(24, 0))
	w.hp = w.max_hp * 0.4
	var lit := await wait_for(func() -> bool: return L.lit_v > 0.5 and L.lit.visible, 20.0)
	check(lit, "a Missionary heals: the windows glow (%.2f)" % L.lit_v)
	g.consume_unit(m)
	g.consume_unit(w)
	await wait(4.0)
	check(L.lit_v == 0.0 and not L.lit.visible, "he stops: the glow fades out")
	c.die()
	check(L.lit_state == "" and not L.lit.visible and not L.bell.visible, "destroyed: no glow, no bell")


func _fog() -> void:
	# a building remembered under the fog stands still
	var h: Building = g._add_building("town_hall", 0, origin + Vector2i(22, 8), true)
	g.camera.position = h.center()
	await wait(1.5)
	_train(h, "labourer")
	await wait(1.0)
	var L: BuildingLife = h.life
	h._use_t = 1.0e9          # (stop the twice-a-second look: pretend it isn't seen now)
	h._seen_now = false
	await physics_frame
	var f0: int = L.bell.frame
	await wait(2.0)
	check(L.bell.frame == f0, "under the fog the bell stands still")
	h._seen_now = true
	var seen := {}
	for i in 60:
		seen[L.bell.frame] = true
		await physics_frame
	check(seen.size() >= 2, "seen again: it swings")
