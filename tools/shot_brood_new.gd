extends SceneTree
## Pictures of THE NEW BROOD in a match (docs/brood_new.md; docs/shots/brood_new/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_brood_new.gd -- <outdir>
## scale.png       the Brood Mother, a Rootmaw and the Tyrannosaur beside a Crown Cottage, a Barracks and a Clocktower
## card_*.png      the command cards: the Mother's (her eggs), a rooted Rootmaw's (UPROOT, HAUL)
## start.png       the start: the Mother and the first Rootmaw finishing their rooting, the grubs
## harvest.png     grubs taking food at a rooted, well-fed Rootmaw's flank and carrying it to the Mother
## rootmaw_fed.png a rooted Rootmaw full of food, close
## laying_NN.png   the Mother walking and laying eggs (a frame every 0.1 s: tools/make the GIF from them)
## fertilise.png   the Tyrannosaur breathing on the Mother's eggs (red-gold mist, the eggs turning red)
## haul.png        a Rootmaw hauling its food, and a spilled pile
## fight.png       the Mother, the Tyrannosaur and Raptors against Crown Musketeers
var main: Node
var g
var out := ""
var t := 0.0
var started := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 7, "slots": [
			{"who": "you", "faction": Defs.BROOD_NEW, "colour": 0, "side": 0},
			{"who": "easy", "faction": "clockwork", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 0.6:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func _snap(name: String, wait := 1.0) -> void:
	await create_timer(wait).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func free_spot(near: Vector2i, w: int, h: int, skip: Array = []) -> Vector2i:
	for r in range(2, 30):
		for y in range(near.y - r, near.y + r + 1):
			for x in range(near.x - r, near.x + r + 1):
				var ok := true
				for yy in range(-1, h + 1):
					for xx in range(-1, w + 1):
						var c := Vector2i(x + xx, y + yy)
						if not g.in_map(c) or not g.is_free(c) or not g._walkable(c):
							ok = false
						for s in skip:
							if (s as Rect2i).has_point(c):
								ok = false
				if ok:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


func walk_spot(p: Vector2, tiles: float) -> Vector2:
	for i in 32:
		var q: Vector2 = p + Vector2.from_angle(TAU * i / 32.0) * tiles * Defs.TILE
		if g._walkable(g.cell_of(q)) and g.region_of(g.cell_of(q)) == g.region_of(g.cell_of(p)):
			return q
	return p


func _run() -> void:
	await create_timer(0.3).timeout
	g.reveal = true
	var q: Unit = BroodNew.queen(g, 0)
	var maw: Unit = g.units.filter(func(u) -> bool: return u.kind == BroodNew.MAW)[0]
	var ui: Array = root.find_children("*", "CanvasLayer", true, false).filter(func(c) -> bool: return c.visible)
	for c in ui:
		c.visible = false
	# the start: their rooting's last frames
	g.camera.position = (q.position + maw.position) * 0.5 + Vector2(0, -20)
	g.camera.zoom = Vector2(1.3, 1.3)
	await _snap("start", 0.6)
	await create_timer(2.0).timeout
	for c in ui:
		c.visible = true
	# the command cards (the HUD on): the Mother's eggs, a Rootmaw's UPROOT and HAUL
	g.players[0]["gold"] = 400
	g.camera.position = q.position + Vector2(0, -20)
	g.camera.zoom = Vector2(1.2, 1.2)
	g.set_selection([q])
	await _snap("card_mother", 0.8)
	g.set_selection([maw])
	g.camera.position = maw.position
	await _snap("card_rootmaw", 0.8)
	g.set_selection([])
	for c in ui:
		c.visible = false
	# grubs at the Rootmaw's flank
	maw.nb["food"] = 260.0
	g.camera.position = (q.position + maw.position) * 0.5 + Vector2(0, -20)
	g.camera.zoom = Vector2(1.5, 1.5)
	await _snap("harvest", 6.0)
	g.camera.position = maw.position + Vector2(0, -30)
	g.camera.zoom = Vector2(3.0, 3.0)
	await _snap("rootmaw_fed", 1.0)
	# scale: the three beside a Cottage, a Barracks and a Clocktower, somewhere open
	# an open stretch 22 x 12 tiles near the middle of the map
	var area: Vector2i = free_spot(Vector2i(Game.W / 2 - 11, Game.H / 2 - 6), 22, 12)
	var b1: Building = g._add_building("cottage", 1, area + Vector2i(1, 2), true)
	var b2: Building = g._add_building("barracks", 1, area + Vector2i(6, 1), true)
	var b3: Building = g._add_building("clocktower", 1, area + Vector2i(14, 1), true)
	g.swamp_dirty = true
	var row_y: float = maxf(b1.rect().end.y, maxf(b2.rect().end.y, b3.rect().end.y)) + 90.0
	var q2: Unit = g._add_unit(BroodNew.QUEEN, 0, Vector2(b1.center().x, row_y + 20.0))
	q2.facing = BroodNew.SE
	var m2: Unit = g._add_unit(BroodNew.MAW, 0, Vector2(b2.center().x, row_y))
	m2.facing = BroodNew.SE
	var f2: Unit = g._add_unit(BroodNew.FATHER, 0, Vector2(b3.center().x, row_y))
	f2.facing = BroodNew.SE
	for u in [q2, m2, f2]:
		u.cmd_hold()
	g.camera.position = Vector2(b2.center().x, (b2.center().y + row_y) * 0.5)
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap("scale", 1.0)
	for u in [q2, m2, f2]:
		g.consume_unit(u)
	# the Mother walks and lays
	g.players[0]["gold"] = 5000
	g.players[0]["res2"] = 500.0
	q.nb["eggs"] = 10
	q.cmd_uproot(true)
	await create_timer(float(Defs.NB["queen_switch"]) + 0.3).timeout
	var to: Vector2 = walk_spot(q.position, 9.0)
	q.cmd_move(to)
	g.camera.zoom = Vector2(1.6, 1.6)
	await create_timer(0.8).timeout
	for i in 36:
		if i % 7 == 0:
			q.cmd_lay("grub")
		g.camera.position = q.position + Vector2(0, -40)
		await _snap("laying_%02d" % i, 0.1)
	await create_timer(3.0).timeout
	q.cmd_deploy()
	await create_timer(float(Defs.NB["queen_switch"]) + 0.5).timeout
	# the father breathes on the eggs
	var f: Unit = g._add_unit(BroodNew.FATHER, 0, walk_spot(q.position + Vector2(-110, -10), 1.5))
	f.cmd_stop()
	await create_timer(1.0).timeout
	q.facing = Vector2(-1, 0.3).normalized()       # (her back to the father: the eggs drop by him)
	for i in 4:
		q.cmd_lay("raptor")
	g.camera.position = (q.position + f.position) * 0.5 + Vector2(0, -20)
	g.camera.zoom = Vector2(1.8, 1.8)
	for i in 6:
		await _snap("fertilise_%d" % i, 0.5)
	# HAUL and a spilled pile
	var m3: Unit = g._add_unit(BroodNew.MAW, 0, walk_spot(q.position, 12.0))
	m3.nb["food"] = 250.0
	var m4: Unit = g._add_unit(BroodNew.MAW, 0, m3.position + Vector2(90, 30))
	m4.nb["food"] = 200.0
	m4.cmd_deploy()
	await create_timer(float(Defs.NB["maw_switch"]) + 0.3).timeout
	m4.cmd_uproot(true)
	m3.cmd_move(m3.position + Vector2(-200, 0))
	await create_timer(float(Defs.NB["maw_switch"]) + 0.3).timeout
	m4.cmd_move(m4.position + Vector2(120, 60))
	g.camera.position = (m3.position + m4.position) * 0.5 + Vector2(0, -30)
	g.camera.zoom = Vector2(2.0, 2.0)
	await _snap("haul", 1.2)
	# a fight
	var at: Vector2 = walk_spot(q.position, 6.0)
	for i in 12:
		var mu: Unit = g._add_unit("musketeer", 1, at + Vector2(140 + (i % 4) * 22, -40 + (i / 4) * 24))
		mu.cmd_move(q.position, true)
	for i in 4:
		for k in 3:
			var r: Unit = g._add_unit("raptor", 0, at + Vector2(-20 - i * 16, -30 + k * 20))
			r.cmd_move(at + Vector2(160, 0), true)
	f.cmd_move(at + Vector2(140, 0), true)
	g.camera.position = at + Vector2(60, -30)
	g.camera.zoom = Vector2(1.4, 1.4)
	await _snap("fight", 3.0)
	await _snap("fight_2", 1.5)
	quit(0)
