extends SceneTree
## Pictures of the WORKER LABELS (scripts/worker_labels.gd) for docs/shots/worker_labels/:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_worker_labels.gd -- out:/abs/dir
##   (phone: --resolution 915x412 ... -- out:/abs/dir phone:1)
## crown.png (Town Hall HAULERS, Farm FARMERS, Powder Mill POWDER MAKERS), crown_tip.png (the mouse resting on HAULERS),
## clockwork.png (Cog Press and Mainspring WINDERS with the %), clockwork_tip.png, brood.png (old Feeding Pit GRUBS),
## brood_new.png (Rootmaw GRUBS), brood_new_tip.png; phone:1 writes phone_crown.png and phone_crown_tip.png (long press).
var main: Node
var out := ""
var phone := false
var t := 0.0
var busy := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"phone": phone = kv[1] == "1"
	DirAccess.make_dir_recursive_absolute(out)
	Settings.load_all()
	Settings.device = "mobile" if phone else "pc"
	Settings.tooltips = true
	Settings.apply()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.3 and not busy:
		busy = true
		_run()
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _start(me: String) -> Game:
	var slots: Array = [{"who": "you", "faction": me, "colour": 0, "side": 0, "strategy": "balanced"},
		{"who": "easy", "faction": "crown", "colour": 1, "side": 1, "strategy": "balanced"}]
	main.start({"map": "greenhold" if MapGen.all_ids().has("greenhold") else MapGen.all_ids()[0], "seed": 7, "slots": slots})
	await _frames(5)
	var g: Game = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	await _frames(10)
	for ai in g.ais:
		ai.process_mode = Node.PROCESS_MODE_DISABLED
	return g


func _end() -> void:
	var g: Game = main.game
	main.game = null
	g.queue_free()
	await _frames(3)


func _snap(name: String) -> void:
	await _frames(20)
	var img: Image = root.get_viewport().get_texture().get_image()
	if not phone:
		img.resize(img.get_width() * 3 / 4, img.get_height() * 3 / 4, Image.INTERPOLATE_LANCZOS)
	img.save_png("%s/%s.png" % [out, name])
	print("shot ", name)


func _look(g: Game, at: Vector2, z: float) -> void:
	g.camera.zoom = Vector2(z, z)
	g.camera.position = at
	g.camera.reset_smoothing()


func _wait(g: Game, sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await process_frame


func _first(g: Game, kind: String) -> Building:
	for b in g.buildings:
		if b.team == g.human and b.kind == kind and not b.dead:
			return b
	return null


func _put(g: Game, kind: String) -> Building:
	var hall: Building = g._own_hall(g.human)
	if g.faction_of(g.human) == "clockwork":
		return (load("res://tools/gear_test_util.gd")).put(g, g.human, kind, hall.cell)
	var c: Vector2i = g.find_spot(g.human, kind, hall, 2, 12)
	return g._add_building(kind, g.human, c, true) if c.x >= 0 else null


## The label's centre on screen (viewport pixels).
func _screen_of(g: Game, e: Entity) -> Vector2:
	var L := WorkerLabels.layout(g, e)
	var wp: Vector2 = (L["rect"] as Rect2).get_center()
	return g.get_viewport().get_canvas_transform() * wp


## The mouse resting on the label (computer), or a long press (phone): the HUD's tooltip.
func _tip(g: Game, e: Entity, name: String) -> void:
	await _frames(5)
	var sp := _screen_of(g, e)
	if phone:
		g.hud.show_label_tip(e, sp / float(g.hud.ui_scale))
	else:
		root.get_viewport().warp_mouse(sp)
		Input.warp_mouse(sp)
		await _frames(30)
		var c: Dictionary = g.hud._hover_at(sp / float(g.hud.ui_scale))
		if c.has("lab"):      # (in case the warp did not reach the HUD under xvfb)
			g.hud._tip = g.hud._tip_of(c)
			g.hud._tip_at = sp / float(g.hud.ui_scale)
			g.hud._tip_ms = Time.get_ticks_msec() + 100000
	await _snap(name)
	g.hud._tip = {}


func _run() -> void:
	var z := 0.9 if phone else 1.05
	# --- the Crown: Town Hall (haulers), Farm, Powder Mill, a Horse Breeder so the haulers are needed
	var g := await _start("crown")
	var hall: Building = g._own_hall(g.human)
	var mill := _put(g, "powder_mill")
	_put(g, "horse_breeder")
	var labs: Array = g.units.filter(func(u: Unit) -> bool: return u.team == g.human and u.kind == "labourer" and not u.dead)
	if labs.size() >= 2:
		labs[0].cmd_gather(hall)
		labs[1].cmd_gather(mill if mill else hall)
	await _wait(g, 8.0)
	var farm := _first(g, "farm")
	var mid := hall.center()
	if farm:
		mid = (hall.center() + farm.center() + (mill.center() if mill else hall.center())) / 3.0
	_look(g, mid, z)
	await _snap(("phone_" if phone else "") + "crown")
	await _tip(g, hall, ("phone_" if phone else "") + "crown_tip")
	if phone:
		await _end()
		quit(0)
		return
	if farm:
		_look(g, farm.center(), z)
		await _tip(g, farm, "crown_farm_tip")
	await _end()
	# --- the Clockwork: Cog Press and Mainspring
	g = await _start("clockwork")
	var press := _first(g, Defs.GEAR_PRESS)
	var spring := _put(g, "mainspring")
	await _wait(g, 8.0)
	var c2 := g._own_hall(g.human).center()
	if press and spring:
		c2 = (press.center() + spring.center()) * 0.5
	_look(g, c2, z)
	await _snap("clockwork")
	if press:
		await _tip(g, press, "clockwork_tip")
	await _end()
	# --- the old Brood: Feeding Pit
	g = await _start("brood")
	await _wait(g, 8.0)
	var pit := _first(g, "feeding_pit")
	_look(g, pit.center() if pit else g._own_hall(g.human).center(), z)
	await _snap("brood")
	if pit:
		await _tip(g, pit, "brood_tip")
	await _end()
	# --- the new Brood: Rootmaw
	g = await _start(Defs.BROOD_NEW)
	await _wait(g, 8.0)
	var maw: Unit = null
	for u in g.units:
		if u.team == g.human and u.kind == BroodNew.MAW and not u.dead:
			maw = u
	_look(g, maw.position if maw else g.camera.position, z)
	await _snap("brood_new")
	if maw:
		await _tip(g, maw, "brood_new_tip")
	await _end()
	quit(0)
