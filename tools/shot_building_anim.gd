extends SceneTree
## Frame strips of the buildings' animations (for looking at them):
##   xvfb-run -a godot --rendering-driver opengl3 --script res://tools/shot_building_anim.gd -- <outdir>
## Writes <outdir>/<name>_<n>.png (the screen around each building, zoomed); tools/strip.py cuts and joins them.
var main: Node
var g
var out := ""
var t := 0.0
var started := false
var origin := Vector2i(-1, -1)


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
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
		g.hud.visible = false
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


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


func snap(b: Building, name: String, n: int, dt: float) -> void:
	g.camera.position = b.center() + Vector2(0, -40)
	for i in n:
		await create_timer(dt).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [out, name, i])


func snap_at(pos: Vector2, name: String, n: int, dt: float) -> void:
	g.camera.position = pos
	for i in n:
		await create_timer(dt).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [out, name, i])


## Barracks drills, one strip per man trained (zoomed on the yard, the Horse Breeder standing: the prop is up).
const DRILLS := [["musketeer", false, "musketeer"], ["musketeer", true, "guardsman"], ["dismounted", false, "officer"],
	["dismounted", true, "armoured_officer"], ["cuirassier", false, "horseman"], ["cuirassier", true, "cuirassier"],
	["dragoon", false, "dragoon"], ["dragoon", true, "armoured_dragoon"]]


func _drills(br: Building, hb: Building) -> void:
	g.camera.zoom = Vector2(5.0, 5.0)
	var yard: Vector2 = br.global_position + Vector2(32, -28)
	for d in DRILLS:
		br.queue.clear()
		br.kits.clear()
		br.prod_t = 0.0
		br.add_entry(String(d[0]), {"armour": d[1]})
		await create_timer(0.3).timeout
		await snap_at(yard, "drill_" + String(d[2]), 12, 0.4)
	br.queue.clear()
	br.kits.clear()
	# no Horse Breeder: no prop (the Horseman swings the Officer's sabre, the Dragoon just shoots)
	var team := hb.team
	hb.team = 1
	await create_timer(0.8).timeout
	for d in [DRILLS[4], DRILLS[6]]:
		br.add_entry(String(d[0]), {"armour": false})
		await create_timer(0.8).timeout
		await snap_at(yard, "drill_noprop_" + String(d[2]), 10, 0.3)
		br.queue.clear()
		br.kits.clear()
	hb.team = team
	await create_timer(0.8).timeout
	# the paddock's coats
	g.camera.zoom = Vector2(5.0, 5.0)
	hb.queue.clear()
	hb.kits.clear()
	hb.add_entry("horse", {"coat": "spotted"})
	hb.add_entry("horse", {"coat": "white"})
	await create_timer(1.0).timeout
	await snap_at(hb.global_position + Vector2(15, -35), "coats_spotted_white", 4, 1.0)
	hb.kits[0] = {"coat": "bay"}
	hb.kits[1] = {"coat": "grey"}
	await create_timer(1.0).timeout
	await snap_at(hb.global_position + Vector2(15, -35), "coats_bay_grey", 4, 1.0)
	hb.queue.clear()
	hb.kits.clear()
	await create_timer(1.0).timeout
	await snap_at(hb.global_position + Vector2(15, -35), "coats_idle", 2, 1.0)


func _run() -> void:
	origin = _open_area(32, 14)
	g.reveal = true
	g.players[0]["gold"] = 20000
	g.players[0]["res2"] = 5000.0
	g.players[0]["cap"] = 100
	g.camera.zoom = Vector2(3.0, 3.0)
	g._add_building("powder_mill", 0, origin + Vector2i(26, 2), true)
	var th: Building = g._add_building("town_hall", 0, origin + Vector2i(1, 2), true)
	var br: Building = g._add_building("barracks", 0, origin + Vector2i(9, 2), true)
	var hb: Building = g._add_building("horse_breeder", 0, origin + Vector2i(17, 2), true)
	var ar: Building = g._add_building("armoury", 0, origin + Vector2i(2, 8), true)
	var ch: Building = g._add_building("church", 0, origin + Vector2i(12, 8), true)
	await create_timer(1.5).timeout
	if OS.get_cmdline_user_args().size() > 1:
		ch.life.belfry.visible = false        # (debug: the bell without the pillars over it)
	g.train(th, "labourer")
	g.train(th, "labourer")
	await snap(th, "town_hall", 8, 0.25)
	g.train(br, "musketeer")
	await create_timer(0.5).timeout
	await snap(br, "barracks", 10, 0.3)
	g.train(hb, "horse")
	g.train(hb, "horse")
	g.train(ch, "missionary")
	await create_timer(1.0).timeout
	await snap(hb, "horse_breeder", 8, 1.0)
	# the Armoury's nine experiments, one research at a time (a head of the queue each)
	for id: String in ["armour", "matchlock", "flintlock", "caplock", "bayonet", "pouch", "charges", "quadrant", "charge"]:
		ar.queue.clear()
		ar.kits.clear()
		ar.prod_t = 0.0
		ar.add_entry("@" + id)
		await create_timer(0.8).timeout
		await snap(ar, "armoury_" + id, 12, 0.45)
	var m: Unit = g._add_unit("missionary", 0, ch.center() + Vector2(0, ch.rect().size.y * 0.5 + 30))
	var w: Unit = g._add_unit("musketeer", 0, m.position + Vector2(24, 0))
	w.hp = w.max_hp * 0.3
	await create_timer(2.0).timeout
	await snap(ch, "church", 8, 0.6)
	await _drills(br, hb)
	quit()
