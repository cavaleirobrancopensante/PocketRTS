extends SceneTree
## Screenshots of TIER 2 (the Escapement and the Jack: scripts/jack.gd) in the CLOCKWORK LAB: the Lab's start (the
## Escapement meshing with the Mainspring, the Jacks), the placement ghost saying NEEDS MAINSPRING (and MESHES MAINSPRING
## by the Mainspring), a Jack in the air over its ground shadow, a Jack firing at a balloon (the screw in flight), its death
## and corpse, and a run of frames for a GIF of a Jack hopping, jumping and shooting.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_cw_tier2.gd -- <outdir>
## Writes <outdir>/lab_start.png, lab_close.png, lab_jacks.png, card_jack.png, card_escapement.png, card_jump.png,
## jump_target.png, ghost_needs_mainspring.png, ghost_meshes.png, jump_crouch.png, jump_air.png, jump_land.png,
## fire_air.png, fire_air2.png, fire_ground.png, death.png, corpse.png and
## <outdir>/gif/f_NNN.png + gif/frames.txt (tools/gear_art/frames_to_gif.py or the caller's PIL script makes jack.gif).
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


## An enemy of `kind` at p that does not die (a target to shoot at).
func _dummy(kind: String, p: Vector2) -> Unit:
	var u: Unit = g._add_unit(kind, 1, p)
	u.max_hp = 99999.0
	u.hp = 99999.0
	u.cmd_hold()
	u.set_physics_process(false)      # (a still target: it neither walks nor fights)
	return u


## The Lab's hint line (its own CanvasLayer, 40) on or off.
func _hint(on: bool) -> void:
	for c in g.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer == 40:
			c.visible = on


## Open low ground near the base (every cell within 5 tiles walkable): where the Jacks show off.
func _open_ground(hall: Building) -> Vector2:
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(hall.cell.y - 30, hall.cell.y + 31):
		for x in range(hall.cell.x - 30, hall.cell.x + 31):
			var c := Vector2i(x, y)
			if not g.in_map(c) or g.height[g.idx(c)] != 0 or c.x < 10 or c.y < 10 or c.x > Game.W - 10 or c.y > Game.H - 10:
				continue          # (low ground, away from the map's edges)
			var d := Vector2(c - hall.cell).length()
			if d >= bd:
				continue
			var ok := true
			for yy in range(-5, 6):
				for xx in range(-6, 7):
					var cc := c + Vector2i(xx, yy)
					if not g.in_map(cc) or not g._walkable(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != 0:
						ok = false
						break
				if not ok:
					break
			if ok:
				best = c
				bd = d
	return g.cell_center(best) if best.x >= 0 else hall.center() + Vector2(0, 200)


func _ui(on: bool) -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = on


## A cell where an Escapement would link to the field but mesh with no Mainspring (the ghost says NEEDS MAINSPRING).
func _idle_spot(hall: Building) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(hall.cell.y - 20, hall.cell.y + 21):
		for x in range(hall.cell.x - 20, hall.cell.x + 21):
			var c := Vector2i(x, y)
			if not g.in_map(c) or g.placement_problem(g.human, Defs.CW_TECH, c) != "":
				continue
			var st: Dictionary = g.gear_net.candidate(g.human, Defs.CW_TECH, c)
			if st["state"] != "ok" or st.get("spring") != null:
				continue
			if c.y < 6:
				continue          # (not at the map's edge)
			var centre := Vector2(c) * Defs.TILE + Vector2(48, 48)
			if not g.units_near(centre, 90.0).is_empty():
				continue          # (clear of the soldiers, so the ghost reads)
			var d := Vector2(c - hall.cell).length()
			if d < bd:
				bd = d
				best = c
	return best


func _run() -> void:
	var hall := _find("clocktower")
	var esc := _find(Defs.CW_TECH)
	var spring := _find("mainspring")
	var jacks: Array = g.units.filter(func(u: Unit) -> bool: return u.team == g.human and u.kind == Defs.JACK)
	print("lab: escapement %s, works %s, jacks %d, tension %d" % [str(esc != null and g.gear_net.speed_mult(esc) > 0.0),
		str(_find(Defs.CW_WORKS) != null), jacks.size(), int(g.tension(g.human))])
	if esc == null or spring == null or jacks.is_empty():
		print("LAB NOT SET UP")
		quit(1)
		return
	await _snap("lab_start", 2.5)
	_hint(false)
	# the Escapement, the Mainspring and the Jacks close
	g.camera.position = (esc.center() + spring.center()) * 0.5 + Vector2(-30, 20)
	g.camera.zoom = Vector2(1.5, 1.5)
	await _snap("lab_close", 0.6)
	var mid := Vector2.ZERO
	for o in jacks:
		mid += o.position / float(jacks.size())
	g.camera.position = mid + Vector2(0, -30)
	g.camera.zoom = Vector2(2.4, 2.4)
	await _snap("lab_jacks", 0.4)
	# the Movement Works' card with the Jack (cogs + Tension) and the Escapement's with HIGH LEAP
	var works := _find(Defs.CW_WORKS)
	for sp in root.find_children("*", "SandboxPanel", true, false):
		sp.open = false
		sp._build()
	g.set_selection([works])
	await _hover_card(Defs.JACK, "")
	await _snap("card_jack", 1.4)
	g.set_selection([esc])
	await _hover_card("", "HIGH LEAP")
	await _snap("card_escapement", 1.4)
	# the Jacks' card with JUMP, then the JUMP target under the pointer (their reach, the landing ring and the arc)
	g.set_selection(jacks)
	await _hover_card("", "JUMP")
	await _snap("card_jump", 1.4)
	g.controls.mode = "cast"
	g.controls.cast_spell = "jump"
	var jm := Vector2.ZERO
	for o in jacks:
		jm += o.position / float(jacks.size())
	# (the target is under the pointer on a computer, at the screen's centre on a phone: both are put on the spot)
	var aim := jm + Vector2(-110, 40)
	g.camera.position = aim
	g.camera.zoom = Vector2(1.6, 1.6)
	await create_timer(0.3).timeout
	root.get_viewport().warp_mouse(Vector2(640, 360))
	await _snap("jump_target", 0.5)
	g.controls.cancel_mode()
	g.set_selection([])
	root.get_viewport().warp_mouse(Vector2(640, 300))
	# the ghost: an Escapement that would link but mesh with no Mainspring, then one by the Mainspring
	var c := _idle_spot(hall)
	if c.x >= 0:
		g.controls.begin_place(Defs.CW_TECH)
		g.controls.ghost_cell = c
		g.camera.position = Vector2(c) * Defs.TILE + Vector2(48, 80)
		g.camera.zoom = Vector2(1.6, 1.6)
		await _snap("ghost_needs_mainspring", 0.6)
		var c2 := Vector2i(-1, -1)
		for deg in [180.0, -90.0, 0.0, 90.0, 135.0, -135.0, 45.0, -45.0]:
			c2 = GearNet.ring_spot(g, g.human, Defs.CW_TECH, spring, deg)
			if c2.x >= 0:
				break
		if c2.x >= 0:
			g.controls.ghost_cell = c2
			g.camera.position = Vector2(c2) * Defs.TILE + Vector2(48, 30)
			await _snap("ghost_meshes", 0.6)
		g.controls.cancel_mode()
	_ui(false)
	g.reveal = true
	# ---- the action on open ground below the plateau: the Jacks are put there
	var open := _open_ground(hall)
	for i in jacks.size():
		var o: Unit = jacks[i]
		o.position = open + Vector2(-90.0 + 70.0 * float(i), 60.0 if i > 0 else 0.0)
		o.cmd_stop()
		o.path = PackedVector2Array()
	await create_timer(0.5).timeout
	# ---- a Jack jumps: crouch, in the air over its shadow, landing
	var j: Unit = jacks[0]
	g.players[g.human]["tech"]["high_leap"] = true
	var dest := _jump_dest(j, 4.5)
	g.camera.position = (j.position + dest) * 0.5 + Vector2(0, -30)
	g.camera.zoom = Vector2(2.6, 2.6)
	await create_timer(0.8).timeout
	Engine.time_scale = 0.25
	Jack.jump_order(g, [j], dest)
	await _wait(func() -> bool: return Jack.frame(j) >= 2 or j.jump.is_empty(), 6.0)
	await _frozen("jump_crouch")
	await _wait(func() -> bool: return Jack.lift(j) > float(j.jump.get("peak", 0.0)) * 0.85 or j.jump.is_empty(), 8.0)
	await _frozen("jump_air")
	await _wait(func() -> bool: return Jack.frame(j) >= 6 or j.jump.is_empty(), 8.0)
	await _frozen("jump_land")
	Engine.time_scale = 1.0
	await create_timer(1.0).timeout
	# ---- a Jack fires at a balloon: the screw in flight
	var fly := _dummy("balloon", j.position + Vector2(70, -95))
	g.camera.position = j.position + Vector2(35, -60)
	await create_timer(0.3).timeout
	Engine.time_scale = 0.25
	j.cmd_attack(fly)
	await _shot(j, "fire_air", 0.06)
	await _shot(j, "fire_air2", 0.12)
	_gone(fly)
	# ---- and at a man on the ground
	var foot := _dummy("labourer", j.position + Vector2(-120, 40))
	g.camera.position = j.position + Vector2(-60, 0)
	j.cmd_attack(foot)
	await _shot(j, "fire_ground", 0.05)
	_gone(foot)
	Engine.time_scale = 1.0
	j.cmd_stop()
	await create_timer(0.6).timeout
	# ---- the GIF: hop, jump, shoot (fixed camera; slow motion, frames kept by game time), back on the open ground, the
	# other Jacks out of the picture
	j.position = open + Vector2(-60, 0)
	j.cmd_stop()
	j.jump_cd = 0.0
	for o in jacks:
		if o != j and o != jacks[jacks.size() - 1]:
			_gone(o)
	var last: Unit = jacks[jacks.size() - 1]
	last.position = open + Vector2(-60, 260)
	last.cmd_hold()
	await _gif(j)
	last.position = open + Vector2(0, 0)
	# ---- death and corpse
	var k: Unit = jacks[jacks.size() - 1]
	g.camera.position = k.position + Vector2(0, -20)
	g.camera.zoom = Vector2(3.0, 3.0)
	await create_timer(0.5).timeout
	Engine.time_scale = 0.3
	k.take_damage(99999.0, null)
	await _wait(func() -> bool: return k.sprite.frame >= 3, 10.0)
	await _frozen("death")
	Engine.time_scale = 1.0
	await _snap("corpse", 1.6)
	quit(0)


## A spot about `tiles` tiles from the Jack it may land on, on its own level, toward open ground.
func _jump_dest(j: Unit, tiles: float) -> Vector2:
	for k in 16:
		var a := TAU * float(k) / 16.0
		var p: Vector2 = j.position + Vector2.from_angle(a) * tiles * Defs.TILE
		var l := Jack.landing(j, p)
		if l.has("at") and (l["at"] as Vector2).distance_to(p) < 4.0:
			return l["at"]
	return j.position + Vector2(-100, 0)


func _wait(cond: Callable, limit: float) -> void:
	var w := 0.0
	while not cond.call() and w < limit:
		await process_frame
		w += 1.0 / 60.0


## Wait for the Jack's next screw, then snap `after` s (game time) into its flight, the game frozen.
func _shot(j: Unit, name: String, after: float) -> void:
	var n: int = j.shots
	await _wait(func() -> bool: return j.shots > n, 30.0)
	var c0: float = g.clock
	await _wait(func() -> bool: return g.clock - c0 >= after, 10.0)
	await _frozen(name)


## The game stopped where it is for a screenshot, then let go.
func _frozen(name: String) -> void:
	g.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	await _snap(name, 0.0)
	g.process_mode = Node.PROCESS_MODE_INHERIT


## A dummy taken off the map at once (no body left standing).
func _gone(u: Unit) -> void:
	g.units.erase(u)
	g.selection.erase(u)
	u.queue_free()


## The mouse over the selected building's card button for `kind` (or labelled `lab`), so its tooltip shows.
func _hover_card(kind: String, lab: String) -> void:
	for k in 30:
		await create_timer(0.1).timeout
		for b in g.hud._card_buttons:
			var it: Array = b["item"]
			if (kind != "" and String(it[0]) == kind) or (lab != "" and String(it[1]).ends_with(lab)):
				root.get_viewport().warp_mouse((b["rect"] as Rect2).get_center() * g.hud.ui_scale)
				return
	print("no card button for ", kind, lab, ": ", g.hud._card_buttons.map(func(b) -> String: return String(b["item"][1])))


## Frames for jack.gif: the Jack hops right, jumps back left, then shoots a balloon; every rendered frame is saved with the
## game clock, so the GIF can take them at even game-time steps.
func _gif(j: Unit) -> void:
	var start := j.position
	g.camera.position = start + Vector2(50, -45)
	g.camera.zoom = Vector2(2.6, 2.6)
	root.get_viewport().warp_mouse(Vector2(2, 2))       # (no hover ring on the balloon)
	await create_timer(0.5).timeout
	var log := FileAccess.open(out + "/gif/frames.txt", FileAccess.WRITE)
	var n := [0]
	var cap := func(phase: String) -> void:
		root.get_viewport().get_texture().get_image().save_png("%s/gif/f_%03d.png" % [out, n[0]])
		log.store_line("%d %.4f %s %.1f %.1f %s %d" % [n[0], g.clock, phase, j.position.x, j.position.y, j.anim, j.sprite.frame])
		n[0] += 1
	Engine.time_scale = 0.2
	# hop: walk 120 px to the right
	j.cmd_move(start + Vector2(120, 0))
	var t0: float = g.clock
	while g.clock - t0 < 2.4:
		await process_frame
		cap.call("hop")
	# jump back to the left
	var l := Jack.landing(j, start + Vector2(-20, 10))
	if l.has("at"):
		j.jump_cd = 0.0
		Jack.jump_order(g, [j], l["at"])
	t0 = g.clock
	while g.clock - t0 < 1.6:
		await process_frame
		cap.call("jump")
	# shoot a balloon overhead
	var fly := _dummy("balloon", j.position + Vector2(70, -60))
	j.cmd_attack(fly)
	t0 = g.clock
	while g.clock - t0 < 2.4:
		await process_frame
		cap.call("shoot")
	_gone(fly)
	log.close()
	Engine.time_scale = 1.0
	j.cmd_stop()
	print("gif frames: %d" % n[0])
