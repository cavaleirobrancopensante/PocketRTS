extends SceneTree
## Screenshots of the new-style Clockwork army in the CLOCKWORK LAB (scripts/cw_lab.gd): the start, a close-up, the
## Movement Works training (its working loop), the Regulator, the floor plates under the rings, Clock Soldiers fighting
## (fight_00.png ... for a GIF), an attack frame and a corpse.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_cw_army.gd -- <outdir> [frames]
var main: Node
var g
var out := ""
var frames := 30
var t := 0.0
var started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		frames = int(a[1])
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
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _find(kind: String) -> Building:
	for b in g.buildings:
		if b.team == g.human and b.kind == kind and not b.dead:
			return b
	return null


## Open, flat grass near the tower with no buildings round it (for the fight).
func _open_spot(tower: Building) -> Vector2:
	for r in range(8, 30):
		for k in 16:
			var p: Vector2 = tower.center() + Vector2.from_angle(TAU * k / 16.0) * float(r) * Defs.TILE
			var c: Vector2i = g.cell_of(p)
			var ok := true
			for y in range(c.y - 5, c.y + 6):
				for x in range(c.x - 7, c.x + 8):
					var cc := Vector2i(x, y)
					if not g.in_map(cc) or g.solid[g.idx(cc)] != 0 or g.cliff[g.idx(cc)] != 0 or g.ramp[g.idx(cc)] != 0 \
							or g.gear_net.in_field(g.human, Vector2(cc) * Defs.TILE):
						ok = false
						break
				if not ok:
					break
			if ok:
				return p
	return tower.center() + Vector2(0, 300)


func _run() -> void:
	var tower := _find("clocktower")
	var works := _find("movement_works")
	var reg := _find("regulator")
	await _snap("lab_start", 2.5)
	g.reveal = true
	var ui := root.find_children("*", "CanvasLayer", true, false)
	for c in ui:
		c.visible = false
	g.camera.position = tower.center() + Vector2(0, 20)
	g.camera.zoom = Vector2(1.4, 1.4)
	await _snap("lab_close", 0.6)
	# the Movement Works training
	if works:
		for i in 3:
			g.train(works, "clock_soldier")
		g.camera.position = works.center() + Vector2(0, -10)
		g.camera.zoom = Vector2(2.6, 2.6)
		await _snap("works_train_a", 1.0)
		await _snap("works_train_b", 0.25)
	# the Regulator and its plate
	if reg:
		g.camera.position = reg.center() + Vector2(0, -10)
		g.camera.zoom = Vector2(3.0, 3.0)
		await _snap("regulator", 0.5)
	# the floor plates: a far view of the rings
	g.camera.position = tower.center() + Vector2(0, 30)
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap("plates_far", 0.5)
	# the fight, on open grass beside the base: the Lab's soldiers walk in against Brood Raptors (which bite back)
	var mine: Array = g.units.filter(func(u: Unit) -> bool: return u.team == g.human and u.kind == "clock_soldier" and not u.dead)
	var foe_t := 1 if g.human == 0 else 0
	var spot := _open_spot(tower)
	for i in mine.size():
		mine[i].position = spot + Vector2(-110, -54 + i * 36)
		mine[i].cmd_stop()
	var foes: Array = []
	for i in 3:
		var f: Unit = g._add_unit("brute" if i == 1 else "raptor", foe_t, spot + Vector2(110, -40 + i * 40))
		f.cmd_stop()
		foes.append(f)
	await create_timer(0.3).timeout
	for i in mine.size():
		mine[i].cmd_attack(foes[[0, 1, 1, 2][i % 4]])
	g.camera.position = spot + Vector2(0, -10)
	g.camera.zoom = Vector2(2.8, 2.8)
	var shot_attack := false
	for i in frames:
		await _snap("fight_%02d" % i, 0.1)
		if not shot_attack:
			for u in mine:
				if is_instance_valid(u) and not u.dead and u.anim == "attack" and u.sprite.frame == 3:
					shot_attack = true
					await _snap("attack_frame", 0.0)
					break
	# a death and the corpse
	var alive: Array = mine.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	if not alive.is_empty():
		var v: Unit = alive[0]
		g.camera.position = v.position + Vector2(0, -10)
		g.camera.zoom = Vector2(4.0, 4.0)
		v.take_damage(9999.0, null)
		await _snap("death_mid", 0.35)
		await _snap("corpse", 1.6)
	quit(0)
