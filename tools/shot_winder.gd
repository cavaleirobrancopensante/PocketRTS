extends SceneTree
## Screenshots of the Winder (tools/import_winder_v2.py, Unit.WINDER_BEAT) in the CLOCKWORK LAB (scripts/cw_lab.gd): the
## crews winding the Cog Presses (with a frame run for a GIF of the beat), Winders walking in all eight views, one fetching
## a crate and carrying it to a site and winding it as it unfolds, one repairing, a fight, deaths and the heaps, and his
## size beside a Clock Soldier and a Jack.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_winder.gd -- <outdir> [frames]
## Writes <outdir>/press.png and press_00.png ... (frames, 1/15 s apart), walk.png and walk_00.png ..., crate.png,
## crate_wind.png, repair.png, attack.png and fight_00.png ..., death_mid.png, death.png, size.png.
var main: Node
var g
var out := ""
var frames := 24
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
	if wait > 0.0:
		await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _find(kind: String) -> Building:
	for b in g.buildings:
		if b.team == g.human and b.kind == kind and not b.dead:
			return b
	return null


func _look(p: Vector2, zoom: float) -> void:
	g.camera.position = p
	g.camera.zoom = Vector2(zoom, zoom)


## Open, flat grass off the gear field with no buildings round it (tools/shot_cw_army.gd).
func _open_spot(tower: Building, skip := 0) -> Vector2:
	var found := 0
	for r in range(8, 34):
		for k in 16:
			var p: Vector2 = tower.center() + Vector2.from_angle(TAU * k / 16.0) * float(r) * Defs.TILE
			var c: Vector2i = g.cell_of(p)
			var ok := true
			for y in range(c.y - 6, c.y + 7):
				for x in range(c.x - 8, c.x + 9):
					var cc := Vector2i(x, y)
					if not g.in_map(cc) or g.solid[g.idx(cc)] != 0 or g.cliff[g.idx(cc)] != 0 or g.ramp[g.idx(cc)] != 0 \
							or g.gear_net.in_field(g.human, Vector2(cc) * Defs.TILE):
						ok = false
						break
				if not ok:
					break
			if ok:
				if found == skip:
					return p
				found += 1
	return tower.center() + Vector2(0, 300 + 200 * skip)


## Free cells in a row on the gear field (a Winder standing there idles instead of winding his own spring).
func _field_row(tower: Building, n: int) -> Vector2:
	var tc: Vector2i = tower.cell
	for r in range(2, 16):
		for y in range(tc.y - r, tc.y + r + 1):
			for x in range(tc.x - r, tc.x + r + 1):
				var ok := true
				for i in n:
					var c := Vector2i(x + i, y)
					if not g.in_map(c) or g.solid[g.idx(c)] != 0 or g.cliff[g.idx(c)] != 0 \
							or not g.gear_net.in_field(g.human, g.cell_center(c)):
						ok = false
						break
				if ok:
					return g.cell_center(Vector2i(x, y))
	return Vector2.INF


## A cell where a Clockwork building of `kind` would mesh with the field (tools/shot_gear_lab.gd).
func _site_cell(tower: Building, kind: String) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	for r in range(4, 24):
		for y in range(tower.cell.y - r, tower.cell.y + r + 1):
			for x in range(tower.cell.x - r, tower.cell.x + r + 1):
				var c := Vector2i(x, y)
				if not g.in_map(c) or not g.margin_free(c, size):
					continue
				if g.placement_problem(g.human, kind, c) != "":
					continue
				return c
	return Vector2i(-1, -1)


func _winders() -> Array:
	return g.units.filter(func(u: Unit) -> bool: return u.team == g.human and u.kind == "winder" and not u.dead)


func _run() -> void:
	var tower := _find("clocktower")
	g.reveal = true
	var ui := root.find_children("*", "CanvasLayer", true, false)
	for c in ui:
		c.visible = false
	# 1. the crews winding the Cog Presses
	var press: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == Defs.GEAR_PRESS and not b.dead and not b.crew.is_empty():
			press = b
			break
	await create_timer(5.0).timeout
	if press:
		_look(press.center() + Vector2(0, 16), 3.0)
		await _snap("press", 0.3)
		for i in frames:
			await _snap("press_%02d" % i, 1.0 / 15.0)
	# 2. walking in all eight views: a ring of Winders on open grass, each walking straight out
	var spot := _open_spot(tower)
	var ring: Array = []
	for k in 8:
		var d := Vector2.from_angle(TAU * k / 8.0)
		var u: Unit = g._add_unit("winder", g.human, spot + d * 26.0)
		ring.append([u, d])
	await create_timer(0.2).timeout
	for e in ring:
		(e[0] as Unit).cmd_move(spot + (e[1] as Vector2) * 600.0)
	_look(spot, 2.6)
	await _snap("walk", 0.75)
	for i in frames:
		await _snap("walk_%02d" % i, 1.0 / 15.0)
	for e in ring:
		(e[0] as Unit).cmd_stop()
	# 3. building: one Winder fetches the crate from the Clocktower, carries it to a Regulator's site and winds it
	var builder: Unit = g._add_unit("winder", g.human, tower.center() + Vector2(0, 90))
	var sc := _site_cell(tower, Defs.CW_SUPPLY)
	var site: Building = null
	if sc.x >= 0:
		site = g.place_building(g.human, Defs.CW_SUPPLY, sc, [builder])
	if site:
		var carried := false
		for i in 200:
			await create_timer(0.1).timeout
			if not carried and builder.crate_site != null and builder.velocity.length() > 10.0:
				carried = true
				await create_timer(0.4).timeout
				_look(builder.position + Vector2(0, -16), 3.2)
				await _snap("crate", 0.0)
			if builder.game.clock < builder._crank_until:
				_look(builder.position + Vector2(0, -16), 3.2)
				await _snap("crate_wind", 0.5)
				break
	# 4. repairing: a damaged Cog Press, a Winder sent to mend it
	if press:
		press.hp = press.max_hp * 0.5
		var fixer: Unit = g._add_unit("winder", g.human, press.center() + Vector2(-60, 70))
		fixer.cmd_repair(press)
		for i in 80:
			await create_timer(0.1).timeout
			if fixer.work == "repairing":
				break
		_look(fixer.position + Vector2(0, -16), 3.2)
		await _snap("repair", 0.5)
	# 5. a fight on open grass: three Winders against a Raptor and a Grub (they bite back)
	var fspot := _open_spot(tower, 1)
	var foe_t := 1 if g.human == 0 else 0
	var mine: Array = []
	for i in 3:
		var w: Unit = g._add_unit("winder", g.human, fspot + Vector2(-60, -36 + i * 36))
		w.cmd_stop()
		mine.append(w)
	var foes: Array = []
	for i in 2:
		var f: Unit = g._add_unit("raptor" if i == 0 else "grub", foe_t, fspot + Vector2(40, -20 + i * 40))
		f.cmd_stop()
		foes.append(f)
	await create_timer(0.3).timeout
	for i in mine.size():
		mine[i].cmd_attack(foes[i % 2])
	_look(fspot + Vector2(0, -10), 2.8)
	var shot_attack := false
	for i in frames:
		await _snap("fight_%02d" % i, 1.0 / 15.0)
		if not shot_attack:
			for u in mine:
				if is_instance_valid(u) and not u.dead and u.anim == "attack" and u.sprite.frame == 2:
					shot_attack = true
					_look(u.position + Vector2(0, -16), 3.4)
					await _snap("attack", 0.0)
					_look(fspot + Vector2(0, -10), 2.8)
					break
	for f in foes:
		if is_instance_valid(f) and not f.dead:
			f.take_damage(9999.0, null)
	# 6. deaths in five views (the ring of walkers, turned and killed where they stand)
	var dspot := _open_spot(tower, 2)
	var dead: Array = []
	var views := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1)]
	for i in 5:
		var u: Unit = ring[i][0]
		u.position = dspot + Vector2(-100 + i * 50, 0)
		u.cmd_stop()
		u.facing = views[i].normalized()
		dead.append(u)
	await create_timer(0.5).timeout
	for u in dead:
		u.facing = views[dead.find(u)].normalized()
		u.take_damage(9999.0, null)
	_look(dspot + Vector2(0, -10), 3.0)
	await _snap("death_mid", 0.3)
	await _snap("death", 1.6)
	# 7. the size: a Winder beside a Clock Soldier and a Jack, all facing us, on the field (so the Winder idles)
	var row := _field_row(tower, 7)
	if row == Vector2.INF:
		row = dspot + Vector2(0, 120)
	var w2: Unit = g._add_unit("winder", g.human, row + Vector2(16, 0))
	var cs: Unit = g._add_unit("clock_soldier", g.human, row + Vector2(80, 0))
	var jk: Unit = g._add_unit(Defs.JACK, g.human, row + Vector2(150, 0))
	for u in [w2, cs, jk]:
		u.cmd_stop()
	await create_timer(0.4).timeout
	for u in [w2, cs, jk]:
		u.position = row + Vector2([16, 80, 150][[w2, cs, jk].find(u)], 0)
		u.facing = Vector2(0, 1)
	_look(row + Vector2(80, -20), 3.0)
	await _snap("size", 0.4)
	quit(0)
