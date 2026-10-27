extends SceneTree
## Screenshots of TIER 3 (the Pendulum and the Netter: scripts/pendulum.gd, scripts/netter.gd) in the CLOCKWORK LAB: the Lab's
## start, the big-gear Movement Works with the Pendulums and Netters, the cards (the Pendulum refused at a small-gear Works
## with its reason, offered at the big-gear one; a Netter's line), Pendulums walking, a Pendulum winding up and swinging
## through a crowd, a Netter's recoil with its net in flight, a Brute caught under the net, a balloon brought down by one,
## the deaths; and the air fixes: the Swift's peck (pull back, the stab) and a Swift and an Owl spinning down. Plus a run of
## frames for a GIF.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_cw_tier3.gd -- <outdir>
## Writes <outdir>/*.png and <outdir>/gif/f_NNN.png + gif/frames.txt.
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


## An enemy of `kind` at p that does not die (a target); `still`: it neither moves nor fights.
func _dummy(kind: String, p: Vector2, still := true) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.max_hp = 99999.0
	u.hp = 99999.0
	u.auto_work = false
	u.cmd_hold()
	if still:
		u.d = u.d.duplicate()
		u.d["damage"] = 0
	return u


## A unit off the picture: hidden and dead (not freed: lists may still hold it).
func _gone(u: Unit) -> void:
	if not is_instance_valid(u):
		return
	g.selection.erase(u)
	u.visible = false
	if not u.dead:
		u.die()
	u.visible = false


func _mine(kind: String) -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == g.human and u.kind == kind and not u.dead)


## Open low ground near the base (every cell within 6 tiles walkable): the stage.
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


## The mouse over the card button for `kind` (or labelled `lab`), so its tooltip shows.
func _hover_card(kind: String, lab: String) -> void:
	for k in 30:
		await create_timer(0.1).timeout
		for b in g.hud._card_buttons:
			var it: Array = b["item"]
			if (kind != "" and String(it[0]) == kind) or (lab != "" and String(it[1]).ends_with(lab)):
				root.get_viewport().warp_mouse((b["rect"] as Rect2).get_center() * g.hud.ui_scale)
				return
	print("no card button for ", kind, lab)


func _run() -> void:
	var hall: Building = null
	var works_small: Building = null
	var works_big: Building = null
	for b in g.buildings:
		if b.team != g.human or b.dead:
			continue
		if b.kind == "clocktower":
			hall = b
		elif b.kind == Defs.CW_WORKS:
			if b.gear_big:
				works_big = b
			else:
				works_small = b
	var pends := _mine(Defs.PENDULUM)
	var netters := _mine(Defs.NETTER)
	print("lab: big works %s, small works %s, pendulums %d, netters %d" % [str(works_big != null), str(works_small != null), pends.size(), netters.size()])
	if works_big == null or pends.size() < 2 or netters.size() < 2:
		print("LAB NOT SET UP")
		quit(1)
		return
	await _snap("lab_start", 2.5)
	_hint(false)
	for sp in root.find_children("*", "SandboxPanel", true, false):
		sp.open = false
		sp._build()
	# the tier-3 units by the soldiers, and the big-gear Works
	var mid: Vector2 = (pends[0].position + pends[1].position + netters[0].position) / 3.0
	g.camera.position = mid + Vector2(0, -20)
	g.camera.zoom = Vector2(2.0, 2.0)
	await _snap("lab_tier3", 0.8)
	g.camera.position = works_big.center()
	g.camera.zoom = Vector2(1.4, 1.4)
	await _snap("works_big_gear", 0.6)
	# the cards: the Pendulum refused at a small-gear Works (its reason), offered at the big-gear one; a Netter's line (the
	# Lab's Works runs on its big gear: put on the small one for the first card)
	var ws: Building = works_small if works_small else works_big
	var was_big: bool = ws.gear_big
	ws.gear_big = false
	g.camera.position = ws.center()
	g.set_selection([ws])
	await _hover_card(Defs.PENDULUM, "")
	await _snap("card_works_small", 1.4)
	ws.gear_big = was_big
	g.set_selection([])
	await create_timer(0.3).timeout
	g.camera.position = works_big.center()
	g.set_selection([works_big])
	await _hover_card(Defs.PENDULUM, "")
	await _snap("card_works_big", 1.4)
	await _hover_card(Defs.NETTER, "")
	await _snap("card_netter_train", 1.4)
	g.set_selection([netters[0]])
	root.get_viewport().warp_mouse(Vector2(2, 2))
	await _snap("card_netter_unit", 1.0)
	g.set_selection([])
	_ui(false)
	g.reveal = true
	# ---- the stage
	var open := _open_ground(hall)
	var pd: Unit = pends[0]
	var pd2: Unit = pends[1]
	var nt: Unit = netters[0]
	var nt2: Unit = netters[1]
	pd.position = open + Vector2(-140, -20)
	pd2.position = open + Vector2(-140, 50)
	nt.position = open + Vector2(-220, 10)
	nt2.position = open + Vector2(-230, 70)
	for u in [pd, pd2, nt, nt2]:
		(u as Unit).cmd_stop()
	g.camera.position = open + Vector2(-150, 0)
	g.camera.zoom = Vector2(2.4, 2.4)
	await create_timer(0.5).timeout
	pd.cmd_move(open + Vector2(-40, -20))
	pd2.cmd_move(open + Vector2(-40, 50))
	await create_timer(0.9).timeout
	await _frozen("pendulum_walk")
	await create_timer(1.5).timeout
	# ---- a Pendulum swings through a crowd of Raptors (they stand: no blows back)
	pd2.cmd_stop()
	pd2.position = open + Vector2(-60, 140)
	var crowd: Array = []
	for a in [-40.0, -15.0, 10.0, 35.0, 170.0]:
		crowd.append(_dummy("raptor", pd.position + Vector2.from_angle(deg_to_rad(a)) * 44.0))
	g.camera.position = pd.position + Vector2(20, -30)
	g.camera.zoom = Vector2(3.2, 3.2)
	await create_timer(0.4).timeout
	Engine.time_scale = 0.25
	pd.facing = Vector2.RIGHT
	pd.cmd_attack(crowd[2])
	await _wait(func() -> bool: return String(pd.anim).begins_with("attack") and pd.frame_i >= 2, 20.0)
	await _frozen("pendulum_windup")
	await _wait(func() -> bool: return pd.swings > 0, 10.0)
	await _wait(func() -> bool: return pd.frame_i >= 5, 10.0)
	await _frozen("pendulum_swing")
	Engine.time_scale = 1.0
	print("swing caught %d of the crowd" % pd.last_hits)
	pd.cmd_stop()
	for u in crowd:
		_gone(u)
	# ---- a Netter fires at a Brute: the recoil and the net in flight, then the Brute under the net
	nt.position = open + Vector2(-180, -10)
	nt.cmd_stop()
	var brute := _dummy("brute", open + Vector2(-20, -30), false)
	brute.cmd_move(open + Vector2(-120, -10))
	g.camera.position = (nt.position + brute.position) * 0.5 + Vector2(0, -20)
	g.camera.zoom = Vector2(3.0, 3.0)
	await create_timer(0.3).timeout
	nt.cooldown = 0.0
	Engine.time_scale = 0.2
	nt.cmd_attack(brute)
	await _wait(func() -> bool: return nt.nets > 0 and is_instance_valid(nt.last_net) and nt.last_net.t > nt.last_net.duration * 0.45, 20.0)
	await _frozen("netter_fire")
	await _wait(func() -> bool: return brute.nets_taken > 0, 10.0)
	var c0: float = g.clock
	await _wait(func() -> bool: return g.clock - c0 > 0.2, 5.0)
	Engine.time_scale = 1.0
	g.camera.position = brute.position + Vector2(0, -20)
	await _frozen("net_caught")
	await create_timer(1.0).timeout
	g.set_selection([brute])
	_ui(true)
	_hint(false)
	await _snap("card_caught", 0.4)
	g.set_selection([])
	_ui(false)
	await _wait(func() -> bool: return brute.net_t <= 0.0, 8.0)
	_gone(brute)
	# ---- a balloon brought down by a net (a flyer on the ground)
	nt2.position = open + Vector2(-160, 80)
	nt2.cmd_stop()
	var bal := _dummy("balloon", open + Vector2(-20, 40))
	g.camera.position = bal.position + Vector2(-40, -40)
	g.camera.zoom = Vector2(2.6, 2.6)
	await create_timer(0.6).timeout
	await _frozen("balloon_before")
	nt2.cooldown = 0.0
	nt2.cmd_attack(bal)
	await _wait(func() -> bool: return bal.nets_taken > 0, 10.0)
	await create_timer(0.6).timeout
	await _frozen("balloon_netted")
	nt2.cmd_stop()
	_gone(bal)
	# ---- the Swift's peck (the air fix): pull back, the stab
	var swifts := _mine(Defs.CUCKOO)
	if not swifts.is_empty():
		var sw: Unit = swifts[0]
		sw.position = open + Vector2(60, -60)
		sw.cmd_stop()
		var prey := _dummy("balloon", sw.position + Vector2(64, 6))
		g.camera.position = (sw.position + prey.position) * 0.5 + Vector2(0, -30)
		g.camera.zoom = Vector2(3.4, 3.4)
		await create_timer(0.5).timeout
		Engine.time_scale = 0.2
		sw.cmd_attack(prey)
		await _wait(func() -> bool: return sw.anim == "attack" and sw.frame_i == 1, 20.0)
		await _frozen("swift_peck_1_pullback")
		await _wait(func() -> bool: return sw.anim == "attack" and sw.frame_i == 2, 20.0)
		await _frozen("swift_peck_2_stab")
		await _wait(func() -> bool: return sw.anim == "attack" and sw.frame_i == 4, 20.0)
		await _frozen("swift_peck_3_away")
		Engine.time_scale = 1.0
		sw.cmd_stop()
		_gone(prey)
	# ---- the GIF: the Pendulum swings through Raptors that rush it, a Netter catches a Cuirassier
	await _gif(pd, nt, open, [pd2, nt2])
	# ---- deaths: the Pendulum and the Netter fall; a Swift and an Owl spin down (the air fix)
	pd.position = open + Vector2(-60, 0)
	nt.position = open + Vector2(30, 10)
	pd2.position = open + Vector2(-260, 200)      # (the other Pendulum out of the picture)
	pd2.cmd_hold()
	var owls := _mine(Defs.OWL)
	var ds: Unit = _mine(Defs.CUCKOO)[1] if _mine(Defs.CUCKOO).size() > 1 else null
	if ds:
		ds.position = open + Vector2(-60, -90)
	if not owls.is_empty():
		owls[0].position = open + Vector2(40, -80)
	for u in [pd, nt, ds] + owls:
		if u:
			(u as Unit).cmd_hold()
	g.camera.position = open + Vector2(-10, -40)
	g.camera.zoom = Vector2(2.8, 2.8)
	await create_timer(0.6).timeout
	Engine.time_scale = 0.25
	for u in [pd, nt, ds] + owls:
		if u:
			(u as Unit).take_damage(99999.0, null)
	await _wait(func() -> bool: return pd.frame_i >= 2, 10.0)
	await _frozen("deaths_falling")
	await _wait(func() -> bool: return pd.frame_i >= 5, 10.0)
	Engine.time_scale = 1.0
	await _snap("deaths_ground", 0.8)
	quit(0)


## Frames for tier3.gif on the open ground (every rendered frame saved with the game clock; slow motion): Raptors rush a
## Pendulum and it swings through them; a Cuirassier charges in and the Netter catches it.
func _gif(pd: Unit, nt: Unit, open: Vector2, away: Array) -> void:
	var centre := open + Vector2(-60, 10)
	pd.position = centre
	pd.cmd_hold()
	nt.position = centre + Vector2(-110, 40)
	nt.cmd_hold()
	nt.cooldown = 0.0
	for i in away.size():      # (the other Pendulum and Netter out of the picture)
		(away[i] as Unit).position = open + Vector2(-300.0 - 40.0 * float(i), 220.0)
		(away[i] as Unit).cmd_hold()
	var raptors: Array = []
	for i in 6:
		var r: Unit = g._add_unit("raptor", 1, centre + Vector2(170.0 + 14.0 * float(i % 3), -40.0 + 30.0 * float(i / 3)))
		r.max_hp = 99999.0
		r.hp = 99999.0
		r.d = r.d.duplicate()
		r.d["damage"] = 0
		r.cmd_attack(pd)
		raptors.append(r)
	var cav: Unit = g._add_unit("cuirassier", 1, centre + Vector2(220, 90))
	cav.max_hp = 99999.0
	cav.hp = 99999.0
	cav.d = cav.d.duplicate()
	cav.d["damage"] = 0
	cav.cmd_attack(nt)
	nt.cmd_attack(cav)      # (its own pick would be the Raptors, nearer: the GIF shows the charge stopped)
	g.camera.position = centre + Vector2(30, 10)
	g.camera.zoom = Vector2(2.4, 2.4)
	root.get_viewport().warp_mouse(Vector2(2, 2))
	var log := FileAccess.open(out + "/gif/frames.txt", FileAccess.WRITE)
	var n := [0]
	var cap := func(phase: String) -> void:
		root.get_viewport().get_texture().get_image().save_png("%s/gif/f_%03d.png" % [out, n[0]])
		log.store_line("%d %.4f %s" % [n[0], g.clock, phase])
		n[0] += 1
	Engine.time_scale = 0.35
	var t0: float = g.clock
	while g.clock - t0 < 5.5:
		await process_frame
		cap.call("fight")
	log.close()
	Engine.time_scale = 1.0
	for r in raptors:
		_gone(r)
	_gone(cav)
	print("gif frames: %d" % n[0])
