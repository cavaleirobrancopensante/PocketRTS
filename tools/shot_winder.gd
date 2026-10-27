extends SceneTree
## Screenshots of the Winder (tools/import_winder_v2.py, Unit.WINDER_BEAT) in the CLOCKWORK LAB (scripts/cw_lab.gd): a crew
## winding a Cog Press, Winders walking in all eight views, the five views in a row standing (the clock hands tick) and
## winding (the crank: hammer, hammer, pause), one fetching a crate and carrying it to a site and winding it as it unfolds,
## one repairing a Regulator, four attacking an enemy Cottage, deaths in the five views and the heaps, and his size beside
## a Clock Soldier and a Springer.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_winder.gd -- <outdir> [frames] [old_dir]
## Writes <outdir>/press.png, walk.png, lineup.png, crate.png, crate_wind.png, repair.png, attack.png, death_mid.png,
## death.png, size.png, and frame runs 1/15 s apart (press_00.png ..., walk_..., lineup_..., fight_...; `frames` each).
## old_dir: a folder (outside the project) of the OLD Winder's strips (<anim>_<view>.png, 48 x 47 cells, feet at (24, 43),
## as they were before 0.14.28): they are shown instead of the new ones, for before / after pictures.
var main: Node
var g
var out := ""
var frames := 24
var t := 0.0
var started := false
var used: Array = []           # the open spots the scenes took
const VIEWS := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1)]     # S SE E NE N


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		frames = int(a[1])
	if a.size() > 2:
		_use_old(a[2])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


## The old strips in the texture cache and the old layout in ArtData (nothing in the project is touched).
func _use_old(dir: String) -> void:
	var counts := {}
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".png") or f.begins_with("icon"):
			continue
		var img := Image.load_from_file(dir.path_join(f))
		Game._tex_cache["res://assets/units/winder/" + f] = ImageTexture.create_from_image(img)
		counts[f.trim_suffix(".png")] = img.get_width() / 48
	ArtData.UNITS["winder"] = {"cell": Vector2i(48, 47), "anchor": Vector2(24, 43), "frames": counts}


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
	await process_frame          # (a camera just moved: let it draw there first)
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _find(kind: String) -> Building:
	for b in g.buildings:
		if b.team == g.human and b.kind == kind and not b.dead:
			return b
	return null


func _look(p: Vector2, zoom: float) -> void:
	g.camera.position = p
	g.camera.zoom = Vector2(zoom, zoom)


## Open, flat grass off the gear field with nothing on or near it (no building, tree, rock or water; rows below too: a
## tree's crown stands over the cells above its foot), at least 14 tiles from the spots already used.
func _open_spot(tower: Building) -> Vector2:
	for r in range(8, 44):
		for k in 24:
			var p: Vector2 = tower.center() + Vector2.from_angle(TAU * k / 24.0) * float(r) * Defs.TILE
			if used.any(func(q: Vector2) -> bool: return q.distance_to(p) < 14.0 * Defs.TILE):
				continue
			var c: Vector2i = g.cell_of(p)
			var ok := true
			for y in range(c.y - 6, c.y + 10):
				for x in range(c.x - 8, c.x + 9):
					var cc := Vector2i(x, y)
					if not g.in_map(cc):
						ok = false
						break
					var i: int = g.idx(cc)
					if g.solid[i] != 0 or g.cliff[i] != 0 or g.ramp[i] != 0 or g.water[i] != 0 or String(g._terrain_kind.get(i, "")) in ["tree", "rock"] \
							or g.gear_net.in_field(g.human, Vector2(cc) * Defs.TILE):
						ok = false
						break
				if not ok:
					break
			if ok:
				used.append(p)
				return p
	var far := tower.center() + Vector2(0, 300 + 260 * used.size())
	used.append(far)
	return far


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


## Five Winders in a row facing S, SE, E, NE, N (on open grass they wind their own springs; `idle`: kept on the field's
## footing so they stand idle).
func _lineup(at: Vector2, idle: bool) -> Array:
	var row: Array = []
	for i in VIEWS.size():
		var u: Unit = g._add_unit("winder", g.human, at + Vector2(-96 + i * 48, 0))
		u.cmd_stop()
		row.append(u)
	await create_timer(0.3).timeout
	for i in row.size():
		var u: Unit = row[i]
		u.position = at + Vector2(-96 + i * 48, 0)
		if idle:
			u._in_field = true
			u._field_t = 1.0e9
	return row


func _face(row: Array) -> void:
	for i in row.size():
		if is_instance_valid(row[i]) and not row[i].dead:
			row[i].velocity = Vector2.ZERO
			row[i].facing = (VIEWS[i] as Vector2).normalized()



func _gone(row: Array) -> void:
	for u in row:
		if is_instance_valid(u) and not u.dead:
			u.take_damage(9999.0, null)


func _run() -> void:
	var tower := _find("clocktower")
	g.reveal = true
	var ui := root.find_children("*", "CanvasLayer", true, false)
	for c in ui:
		c.visible = false
	# 1. a crew winding a Cog Press (the camera on the crew)
	var press: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == Defs.GEAR_PRESS and not b.dead and not b.crew.is_empty():
			press = b
			break
	await create_timer(6.0).timeout
	if press:
		var mid := Vector2.ZERO
		for u in press.crew:
			mid += (u as Unit).position / float(press.crew.size())
		_look(mid + Vector2(0, -14), 4.0)
		await _snap("press", 0.3)
		for i in frames:
			await _snap("press_%02d" % i, 1.0 / 15.0 - 0.033)
	# 2. walking in all eight views: a ring of Winders on open grass, each walking straight out
	var spot := _open_spot(tower)
	var ring: Array = []
	for k in 8:
		var d := Vector2.from_angle(TAU * k / 8.0)
		var u: Unit = g._add_unit("winder", g.human, spot + d * 30.0)
		ring.append([u, d])
	await create_timer(0.2).timeout
	for e in ring:
		(e[0] as Unit).cmd_move(spot + (e[1] as Vector2) * 600.0)
	_look(spot, 3.0)
	await _snap("walk", 0.6)
	for i in frames:
		await _snap("walk_%02d" % i, 1.0 / 15.0 - 0.033)
	for e in ring:
		(e[0] as Unit).take_damage(9999.0, null)
	# 3. the five views standing (idle: the clock hands tick) and winding (the crank turns: hammer, hammer, pause)
	var lspot := _open_spot(tower)
	var idle_row: Array = await _lineup(lspot + Vector2(0, -60), true)
	var wind_row: Array = await _lineup(lspot + Vector2(0, 30), false)
	_face(idle_row)
	_face(wind_row)
	_look(lspot + Vector2(0, -30), 4.2)
	await _snap("lineup", 0.5)
	for i in frames:
		_face(idle_row)
		_face(wind_row)
		await _snap("lineup_%02d" % i, 1.0 / 15.0 - 0.033)
	_gone(idle_row)
	_gone(wind_row)
	# 4. building: one Winder fetches the crate from the Clocktower, carries it to a Regulator's site and winds it
	var builder: Unit = g._add_unit("winder", g.human, tower.center() + Vector2(0, 90))
	var sc := _site_cell(tower, Defs.CW_SUPPLY)
	var site: Building = null
	if sc.x >= 0:
		site = g.place_building(g.human, Defs.CW_SUPPLY, sc, [builder])
	if site:
		var carried := false
		for i in 300:
			await create_timer(0.1).timeout
			if not carried and builder.crate_site != null and builder.velocity.length() > 10.0:
				carried = true
				await create_timer(0.5).timeout
				_look(builder.position + Vector2(0, -16), 4.0)
				await _snap("crate", 0.0)
			if builder.game.clock < builder._crank_until:
				_look(builder.position + Vector2(0, -16), 4.0)
				await _snap("crate_wind", 0.3)
				break
	# 5. repairing: a Regulator nobody works at, half broken, and a Winder sent to mend it
	var reg: Building = null
	for b in g.buildings:
		if b.team == g.human and b.kind == Defs.CW_SUPPLY and b.built and not b.dead and b != site:
			reg = b
			break
	if reg:
		reg.hp = reg.max_hp * 0.5
		var fixer: Unit = g._add_unit("winder", g.human, reg.center() + Vector2(-50, 60))
		fixer.cmd_repair(reg)
		for i in 100:
			await create_timer(0.1).timeout
			if fixer.work == "repairing":
				break
		_look(fixer.position + Vector2(0, -16), 4.0)
		await _snap("repair", 0.4)
	# 6. the attack: four Winders round an enemy Cottage on open grass (it does not hit back)
	var fspot := _open_spot(tower)
	var foe_t := 1 if g.human == 0 else 0
	var hut: Building = g._add_building("cottage", foe_t, g.cell_of(fspot) - Vector2i(1, 1), true)
	var mine: Array = []
	for p in [Vector2(0, -52), Vector2(-50, 0), Vector2(50, 0), Vector2(0, 46)]:
		var w: Unit = g._add_unit("winder", g.human, hut.center() + p * 1.6)
		mine.append(w)
	await create_timer(0.3).timeout
	for w in mine:
		w.cmd_attack(hut)
	_look(hut.center() + Vector2(0, -10), 3.4)
	var shot_attack := false
	for i in frames + 20:
		var thrust := 0
		for w in mine:
			if is_instance_valid(w) and not w.dead and w.anim == "attack" and w.sprite.frame == 2:
				thrust += 1
		if not shot_attack and thrust >= 2:
			shot_attack = true
			await _snap("attack", 0.0)
		if i >= 20:
			await _snap("fight_%02d" % (i - 20), 1.0 / 15.0 - 0.033)
		else:
			await create_timer(1.0 / 15.0).timeout
	if not shot_attack:
		await _snap("attack", 0.0)
	_gone(mine)
	# 7. deaths in the five views, then the heaps
	var dspot := _open_spot(tower)
	var drow: Array = await _lineup(dspot, true)
	_face(drow)
	_look(dspot + Vector2(0, -14), 4.0)
	await create_timer(0.2).timeout
	_face(drow)
	_gone(drow)
	await _snap("death_mid", 0.25)
	await _snap("death", 1.6)
	# 8. the size: a Winder beside a Clock Soldier and a Springer, all facing us
	var zspot := _open_spot(tower)
	var w2: Unit = g._add_unit("winder", g.human, zspot + Vector2(-60, 0))
	var cs: Unit = g._add_unit("clock_soldier", g.human, zspot + Vector2(0, 0))
	var jk: Unit = g._add_unit(Defs.SPRINGER, g.human, zspot + Vector2(66, 0))
	var trio := [w2, cs, jk]
	for u in trio:
		u.cmd_stop()
	await create_timer(0.4).timeout
	w2._in_field = true
	w2._field_t = 1.0e9
	for i in trio.size():
		trio[i].position = zspot + Vector2([-60, 0, 66][i], 0)
		trio[i].facing = Vector2(0, 1)
		trio[i].velocity = Vector2.ZERO
	_look(zspot + Vector2(0, -24), 4.0)
	await _snap("size", 0.4)
	quit(0)
