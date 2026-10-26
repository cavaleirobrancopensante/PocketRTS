extends SceneTree
## Screenshots of THE AIR (the Clock Aviary, the Swift, the Ticking Owl: scripts/cw_air.gd) in the CLOCKWORK LAB: the Lab's
## start (the Aviary on the field, three Swifts and an Owl over it), the Aviary at work (doors open, a bird flies off), the
## cards (the Swift at the Aviary, MORPH TO OWL), Swifts flying, a Swift lunging at a balloon, a morph in progress, the Owl
## swooping on a soldier, a bomb falling onto a building and bursting, the deaths ending on the ground, a Jack raising its arm
## at a flyer; and a run of frames for a GIF.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_cw_air.gd -- <outdir>
## Writes <outdir>/*.png and <outdir>/gif/f_NNN.png + gif/frames.txt (the caller's PIL script makes air.gif).
var main: Node
var g
var out := ""
var t := 0.0
var started := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out + "/gif")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start_lab()
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
		g.hud.visible = true
	paused = false
	if not started and t > 1.0:
		started = true
		_run()
	return false


func _snap(name: String, wait := 0.5) -> void:
	if wait > 0.0:
		await create_timer(wait).timeout
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _find(kind: String) -> Building:
	for b in g.buildings:
		if b.team == g.human and b.kind == kind and not b.dead:
			return b
	return null


## An enemy of `kind` at p that does not die (a target).
func _dummy(kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.max_hp = 99999.0
	u.hp = 99999.0
	u.cmd_hold()
	u.set_physics_process(false)      # (a still target: it neither moves nor fights)
	return u


func _hint(on: bool) -> void:
	for c in g.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer == 40:
			c.visible = on


func _ui(on: bool) -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = on


func _wait(cond: Callable, limit: float) -> void:
	var w := 0.0
	while not cond.call() and w < limit:
		await process_frame
		w += 1.0 / 60.0


## The game stopped where it is for a screenshot, then let go.
func _frozen(name: String) -> void:
	g.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	await _snap(name, 0.0)
	g.process_mode = Node.PROCESS_MODE_INHERIT


## A unit off the picture: hidden and dead (not freed: buildings' crews and the computer's detachments may still hold it).
func _gone(u: Unit) -> void:
	g.selection.erase(u)
	u.visible = false
	if not u.dead:
		u.set_physics_process(true)
		u.die()
	u.visible = false


## Open low ground near the base (every cell within 6 tiles walkable): where the flyers show off.
func _open_ground(hall: Building) -> Vector2:
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(hall.cell.y - 34, hall.cell.y + 35):
		for x in range(hall.cell.x - 34, hall.cell.x + 35):
			var c := Vector2i(x, y)
			if not g.in_map(c) or c.x < 12 or c.y < 12 or c.x > Game.W - 12 or c.y > Game.H - 12:
				continue
			var d := Vector2(c - hall.cell).length()
			if d >= bd or d < 14.0:
				continue
			var ok := true
			for yy in range(-6, 7):
				for xx in range(-8, 9):
					var cc := c + Vector2i(xx, yy)
					if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)] or g.solid[g.idx(cc)] != 0:
						ok = false
						break
				if not ok:
					break
			if ok:
				best = c
				bd = d
	return g.cell_center(best) if best.x >= 0 else hall.center() + Vector2(0, 260)


## The mouse over the card button labelled `lab` (or for `kind`), so its tooltip shows.
func _hover_card(kind: String, lab: String) -> void:
	for k in 30:
		await create_timer(0.1).timeout
		for b in g.hud._card_buttons:
			var it: Array = b["item"]
			if (kind != "" and String(it[0]) == kind) or (lab != "" and String(it[1]).ends_with(lab)):
				root.get_viewport().warp_mouse((b["rect"] as Rect2).get_center() * g.hud.ui_scale)
				return
	print("no card button for ", kind, lab, ": ", g.hud._card_buttons.map(func(b) -> String: return String(b["item"][1])))


func _run() -> void:
	var hall := _find("clocktower")
	var av := _find(Defs.CW_AIR)
	var swifts: Array = g.units.filter(func(u: Unit) -> bool: return u.team == g.human and u.kind == Defs.CUCKOO)
	var owls: Array = g.units.filter(func(u: Unit) -> bool: return u.team == g.human and u.kind == Defs.OWL)
	print("lab: aviary %s (linked %s), swifts %d, owls %d, owl research %s" % [str(av != null), str(av != null and g.gear_net.is_linked(av)),
		swifts.size(), owls.size(), str(g.has_tech(g.human, "owl_morph"))])
	if av == null or swifts.is_empty() or owls.is_empty():
		print("LAB NOT SET UP")
		quit(1)
		return
	await _snap("lab_start", 2.5)
	_hint(false)
	# the Aviary with the flyers by it, and the scale against the Jacks and soldiers
	g.camera.position = av.center() + Vector2(0, 10)
	g.camera.zoom = Vector2(1.6, 1.6)
	await _snap("lab_aviary", 0.8)
	g.camera.zoom = Vector2(2.6, 2.6)
	g.camera.position = av.center() + Vector2(0, 20)
	await _snap("lab_aviary_close", 0.5)
	# the cards: the Swift at the Aviary (cogs + Tension), the Swifts' MORPH TO OWL
	for sp in root.find_children("*", "SandboxPanel", true, false):
		sp.open = false
		sp._build()
	g.camera.zoom = Vector2(1.6, 1.6)
	g.set_selection([av])
	await _hover_card(Defs.CUCKOO, "")
	await _snap("card_aviary", 1.4)
	g.set_selection(swifts)
	await _hover_card("", "MORPH TO OWL")
	await _snap("card_morph", 1.4)
	g.set_selection([])
	root.get_viewport().warp_mouse(Vector2(2, 2))
	# the Aviary at work: a Swift ordered, the doors open and birds fly off (four frames)
	g.train(av, Defs.CUCKOO)
	g.camera.position = av.center() + Vector2(0, -30)
	g.camera.zoom = Vector2(2.6, 2.6)
	await create_timer(0.4).timeout
	for i in 4:
		await _wait(func() -> bool: return av.sprite.texture != null and av.sprite.texture.resource_path.ends_with("work_%d.png" % i), 3.0)
		await _frozen("aviary_work_%d" % i)
	av.queue.clear()
	_ui(false)
	g.reveal = true
	# ---- the action on open ground: the flyers are put there
	var open := _open_ground(hall)
	for i in swifts.size():
		var s: Unit = swifts[i]
		s.position = open + Vector2(-120.0 + 46.0 * float(i), -40.0 + 14.0 * float(i % 2))
		s.cmd_stop()
	var owl: Unit = owls[0]
	owl.position = open + Vector2(60, 40)
	owl.cmd_stop()
	g.camera.position = open
	g.camera.zoom = Vector2(2.2, 2.2)
	await create_timer(0.6).timeout
	# Swifts flying across
	for i in swifts.size():
		(swifts[i] as Unit).cmd_move(open + Vector2(160.0, -60.0 + 30.0 * float(i)))
	await create_timer(0.7).timeout
	await _frozen("swifts_flying")
	await create_timer(1.5).timeout
	# ---- a Swift lunges at a balloon
	var sw: Unit = swifts[0]
	var bal := _dummy("balloon", sw.position + Vector2(70, -10))
	g.camera.position = (sw.position + bal.position) * 0.5 + Vector2(0, -30)
	g.camera.zoom = Vector2(3.0, 3.0)
	Engine.time_scale = 0.3
	sw.cmd_attack(bal)
	await _wait(func() -> bool: return sw.anim == "attack" and sw.frame_i >= 2, 20.0)
	await _frozen("swift_lunge")
	await _wait(func() -> bool: return sw.anim != "attack", 10.0)
	await _wait(func() -> bool: return sw.anim == "attack" and sw.frame_i >= 1, 20.0)
	await _frozen("swift_pullback")
	Engine.time_scale = 1.0
	sw.cmd_stop()
	_gone(bal)
	# ---- a morph in progress (another Swift, on its own beside the Owl)
	var ms: Unit = swifts[1]
	ms.position = owl.position + Vector2(-90, -20)
	ms.cmd_stop()
	for i in swifts.size():
		if swifts[i] != ms:
			(swifts[i] as Unit).position = open + Vector2(200.0 + 40.0 * float(i), -160.0)
			(swifts[i] as Unit).cmd_stop()
	await create_timer(0.3).timeout
	g.morph_order([ms])
	g.camera.position = (ms.position + owl.position) * 0.5 + Vector2(0, -25)
	g.camera.zoom = Vector2(3.0, 3.0)
	var mt0: float = g.clock
	await _wait(func() -> bool: return g.clock - mt0 > float(Defs.OWL_MORPH["time"]) * 0.4, 30.0)
	g.set_selection([ms])
	await _frozen("morph")
	g.set_selection([])
	# ---- the Owl swoops on a soldier
	var foot := _dummy("musketeer", owl.position + Vector2(-70, 30))
	g.camera.position = (owl.position + foot.position) * 0.5 + Vector2(0, -30)
	g.camera.zoom = Vector2(3.0, 3.0)
	Engine.time_scale = 0.3
	owl.cmd_attack(foot)
	await _wait(func() -> bool: return owl.anim == "attack" and owl.frame_i >= 3, 20.0)
	await _frozen("owl_swoop")
	await _wait(func() -> bool: return owl.anim != "attack", 10.0)
	await _wait(func() -> bool: return owl.anim == "attack" and owl.frame_i >= 1, 20.0)
	await _frozen("owl_swoop_rise")
	Engine.time_scale = 1.0
	owl.cmd_stop()
	_gone(foot)
	# ---- the Owl bombs a building: the weight falls, bursts, a scorch
	var bc: Vector2i = g.cell_of(owl.position) + Vector2i(-6, -2)
	var target_b: Building = g._add_building("barracks", 1, bc, true)
	props.append(target_b)
	target_b.max_hp = 99999.0
	target_b.hp = 99999.0
	g.camera.position = target_b.center() + Vector2(40, -10)
	g.camera.zoom = Vector2(2.6, 2.6)
	await create_timer(0.5).timeout
	Engine.time_scale = 0.25
	var b0: int = owl.bombs
	owl.cmd_attack(target_b)
	await _wait(func() -> bool: return owl.bombs > b0, 30.0)
	var bomb: OwlBomb = owl.last_bomb
	await _wait(func() -> bool: return not is_instance_valid(bomb) or bomb.t > bomb.duration * 0.45, 10.0)
	await _frozen("bomb_fall")
	var landed0: int = g.bombs_landed
	await _wait(func() -> bool: return g.bombs_landed > landed0, 10.0)
	var c1: float = g.clock
	await _wait(func() -> bool: return g.clock - c1 > 0.12, 5.0)
	await _frozen("bomb_burst")
	await _wait(func() -> bool: return g.clock - c1 > 0.32, 5.0)
	await _frozen("bomb_smoke")
	await _wait(func() -> bool: return g.clock - c1 > 0.62, 5.0)
	await _frozen("bomb_scorch")
	Engine.time_scale = 1.0
	owl.cmd_stop()
	# ---- a Jack raises its arm at a flyer
	var jacks: Array = g.units.filter(func(u: Unit) -> bool: return u.team == g.human and u.kind == Defs.JACK)
	if not jacks.is_empty():
		var j: Unit = jacks[0]
		j.position = open + Vector2(-40, 120)
		j.cmd_stop()
		var fly := _dummy("balloon", j.position + Vector2(80, -70))
		g.camera.position = j.position + Vector2(40, -50)
		g.camera.zoom = Vector2(3.0, 3.0)
		await create_timer(0.4).timeout
		Engine.time_scale = 0.25
		j.cmd_attack(fly)
		var n0: int = j.shots
		await _wait(func() -> bool: return j.shots > n0, 20.0)
		await _frozen("jack_up")
		Engine.time_scale = 1.0
		j.cmd_stop()
		_gone(fly)
	# ---- the GIF (the area cleared of everything else first)
	await _gif(swifts[2], owl, open)
	# ---- deaths: the Swift and the Owl fall and lie on the ground
	var ds: Unit = swifts_spare if swifts_spare else swifts[2]
	ds.position = open + Vector2(-60, 0)
	owl.position = open + Vector2(30, 10)
	owl.cmd_hold()
	ds.cmd_hold()
	g.camera.position = open + Vector2(-15, -20)
	g.camera.zoom = Vector2(3.0, 3.0)
	await create_timer(0.6).timeout
	Engine.time_scale = 0.3
	ds.take_damage(99999.0, null)
	owl.take_damage(99999.0, null)
	await _wait(func() -> bool: return ds.frame_i >= 2, 10.0)
	await _frozen("death_fall")
	await _wait(func() -> bool: return ds.frame_i >= 5 and owl.frame_i >= 5, 10.0)
	Engine.time_scale = 1.0
	await _snap("death_ground", 0.8)
	quit(0)


## Frames for air.gif, staged on cleared open ground (every rendered frame saved with the game clock; slow motion; the camera
## follows each act): a Swift flies in and pecks a balloon, the Owl swoops on a soldier, then turns on a cottage and lets
## its weight fall (the bomb bursts), then a second bomb, then the Swift is shot down and falls to the ground.
func _gif(sw: Unit, owl: Unit, open: Vector2) -> void:
	# (everything else off the stage: our other flyers and the Jacks, the earlier props and dummies)
	for b in props:
		if is_instance_valid(b):
			g.buildings.erase(b)
			g._mark(b.cell, b.size, 0)
			b.queue_free()
	props.clear()
	for u in g.units.duplicate():
		if u == sw or u == owl or u.position.distance_to(open) > 600.0:
			continue
		if (u.team == g.human and not u.is_worker()) or (u.team == 1 and u.max_hp >= 99999.0):
			_gone(u)
	var centre := open + Vector2(0, -10)
	sw.position = centre + Vector2(-190, -20)
	sw.cmd_stop()
	owl.position = centre + Vector2(-20, 60)
	owl.cmd_stop()
	var bal := _dummy("balloon", centre + Vector2(-70, -40))
	var foot := _dummy("musketeer", centre + Vector2(40, 70))
	var bld: Building = g._add_building("cottage", 1, g.cell_of(centre + Vector2(110, -50)), true)
	bld.max_hp = 99999.0
	bld.hp = 99999.0
	g.camera.position = centre + Vector2(-30, 0)
	g.camera.zoom = Vector2(2.4, 2.4)
	root.get_viewport().warp_mouse(Vector2(2, 2))
	await create_timer(0.6).timeout
	var log := FileAccess.open(out + "/gif/frames.txt", FileAccess.WRITE)
	var n := [0]
	var cap := func(phase: String) -> void:
		root.get_viewport().get_texture().get_image().save_png("%s/gif/f_%03d.png" % [out, n[0]])
		log.store_line("%d %.4f %s" % [n[0], g.clock, phase])
		n[0] += 1
	Engine.time_scale = 0.3
	# act 1: the Swift pecks the balloon (the Owl waits)
	owl.cmd_hold()
	sw.cmd_attack(bal)
	var t0: float = g.clock
	while g.clock - t0 < 2.6:
		await process_frame
		g.camera.position = g.camera.position.lerp((sw.position + bal.position) * 0.5 + Vector2(0, -20), 0.08)
		cap.call("peck")
	# act 2: the Owl swoops on the soldier
	sw.cmd_hold()
	owl.cmd_attack(foot)
	t0 = g.clock
	while g.clock - t0 < 2.4:
		await process_frame
		g.camera.position = g.camera.position.lerp((owl.position + foot.position) * 0.5 + Vector2(0, -25), 0.08)
		cap.call("swoop")
	# act 3: the Owl bombs the cottage, twice
	owl.cmd_attack(bld)
	t0 = g.clock
	while g.clock - t0 < 4.4:
		await process_frame
		g.camera.position = g.camera.position.lerp((owl.position + bld.center()) * 0.5 + Vector2(0, -20), 0.08)
		cap.call("bomb")
	# act 4: the Swift is shot down: it falls to the ground
	owl.cmd_hold()
	g.camera.position = sw.position + Vector2(0, -20)
	sw.take_damage(99999.0, null)
	t0 = g.clock
	while g.clock - t0 < 1.4:
		await process_frame
		cap.call("death")
	log.close()
	Engine.time_scale = 1.0
	_gone(bal)
	_gone(foot)
	g.buildings.erase(bld)
	g._mark(bld.cell, bld.size, 0)
	bld.queue_free()
	print("gif frames: %d" % n[0])
	# (the Swift that died here is replaced for the death shots)
	var ns: Unit = g._add_unit(Defs.CUCKOO, g.human, open + Vector2(-60, 0))
	ns.cmd_hold()
	swifts_spare = ns


var swifts_spare: Unit = null
var props: Array = []            # enemy buildings put up for the shots (taken away again)
