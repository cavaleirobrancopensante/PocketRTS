extends SceneTree
## Pictures of THE NEW BROOD in a match (docs/brood_new.md; docs/shots/brood_new/):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x900 --fixed-fps 30 --script res://tools/shot_brood_new.gd -- <outdir>
## scale.png       in a row with their names: a Rootmaw by a Cottage, the Tyrannosaur by a Barracks, the Brood Mother (rooted) by a
##                 Clocktower and its gear ring, a Mound Turtle (rooted: its stand-in) by a Clutch Mound; scale_mother.png closer
## card_*.png      the command cards: the Mother's (her eggs), a rooted Rootmaw's (UPROOT, HAUL)
## start.png       the start: the Mother and the first Rootmaw finishing their rooting, the grubs
## harvest.png     grubs taking food at a rooted, well-fed Rootmaw's flank and carrying it to the Mother
## rootmaw_fed.png a rooted Rootmaw full of food, close
## laying_NN.png   the Mother walking and laying eggs (a frame every 0.1 s: tools/make the GIF from them)
## fertilise_N.png the Tyrannosaur breathing on the Mother's eggs (red-gold mist, the eggs turning red)
## egg_NN.png      one egg: yellow-green, reddening under the breath, red, cracking, a Raptor on the open shell (the GIF)
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


## The scale row (scale.png, scale_mother.png).
func _scale_row() -> void:
	var area: Vector2i = free_spot(Vector2i(Game.W / 2 - 23, Game.H / 2 - 7), 46, 13)
	if area.x < 0:
		area = free_spot(Vector2i(8, 8), 46, 13)
	var y := area.y + 2
	var cot: Building = g._add_building("cottage", 1, Vector2i(area.x + 1, y + 2), true)
	var bar: Building = g._add_building("barracks", 1, Vector2i(area.x + 8, y + 1), true)
	var tow: Building = g._add_building("clocktower", 1, Vector2i(area.x + 18, y), true)
	var mnd: Building = g._add_building("clutch_mound", 1, Vector2i(area.x + 38, y + 2), true)
	var base_y: float = (y + 4) * Defs.TILE + 2.0
	var mw: Unit = g._add_unit(BroodNew.MAW, 0, Vector2(cot.rect().end.x + 52.0, cot.rect().end.y))
	var ty: Unit = g._add_unit(BroodNew.FATHER, 0, Vector2(bar.rect().end.x + 76.0, bar.rect().end.y))
	var mo: Unit = g._add_unit(BroodNew.QUEEN, 0, Vector2(tow.rect().end.x + 180.0, tow.rect().end.y))
	var tu: Unit = g._add_unit(BroodNew.TURTLE, 0, Vector2(mnd.rect().end.x + 52.0, mnd.rect().end.y))
	mo.tesla_mode = "deployed"
	tu.tesla_mode = "deployed"
	for u in [mw, ty, mo, tu]:
		u.facing = BroodNew.SE
		u.cmd_hold()
	var ring: float = GearNet.ring_r("clocktower", tow.size, false)
	var labels := Node2D.new()
	labels.z_index = 50
	g.world.add_child(labels)
	var items := [[cot, "Cottage"], [bar, "Barracks"], [tow, "Clocktower"], [mnd, "Clutch Mound"], [mw, "Rootmaw"], [ty, "Tyrannosaur"],
		[mo, "Brood Mother"], [tu, "Mound Turtle"]]
	labels.draw.connect(func() -> void:
		var font := ThemeDB.fallback_font
		for it in items:
			var e = it[0]
			var top: Vector2
			if e is Building:
				top = Vector2(e.rect().get_center().x, e.rect().position.y - 70.0 if e.kind != "clocktower" else e.rect().position.y - 130.0)
			else:
				top = e.position - Vector2(0, float(ArtData.UNITS[e.art]["anchor"].y) + 14.0)
			var txt: String = it[1]
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			var col := Color(1.0, 0.95, 0.6) if e is Unit else Color(0.85, 0.9, 1.0)
			labels.draw_string_outline(font, top - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.9))
			labels.draw_string(font, top - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col))
	labels.queue_redraw()
	# the sizes, measured on the pictures in game px (the sprite's drawn width)
	print("SIZES gear ring %d px across; Clocktower %d; Cottage %d; Barracks %d; Clutch Mound %d" % [int(ring * 2.0),
		_bw(tow), _bw(cot), _bw(bar), _bw(mnd)])
	await create_timer(0.8).timeout
	print("SIZES Brood Mother rooted %d (walking %d); Rootmaw %d; Tyrannosaur %d; Mound Turtle rooted %d" % [_uw(mo),
		_strip_w("brood_mother", "walk_se"), _uw(mw), _uw(ty), _uw(tu)])
	g.camera.position = Vector2((cot.rect().position.x + tu.position.x) * 0.5 + 20.0, base_y - 40.0)
	g.camera.zoom = Vector2(1.08, 1.08)
	await _snap("scale", 0.6)
	g.camera.position = Vector2((tow.rect().position.x + mo.position.x + 150.0) * 0.5, base_y - 60.0)
	g.camera.zoom = Vector2(1.6, 1.6)
	await _snap("scale_mother", 0.6)
	labels.queue_free()
	for u in [mw, ty, mo, tu]:
		g.consume_unit(u)
	for b in [cot, bar, tow, mnd]:
		b.take_damage(9999999.0, null)
	g.swamp_dirty = true


## Drawn width (px) of a building's picture, of a unit's strip frame on show, of an art's strip's first frame.
func _bw(b: Building) -> int:
	var t: Texture2D = b.sprite.texture if b.sprite else null
	return _alpha_w(t.get_image(), 0, t.get_width()) if t else 0


func _uw(u: Unit) -> int:
	var t: Texture2D = u.sprite.texture
	var n: int = maxi(1, u.sprite.hframes)
	var fw: int = t.get_width() / n
	return _alpha_w(t.get_image(), u.sprite.frame * fw, fw)


func _strip_w(art: String, strip: String) -> int:
	var t: Texture2D = load("res://assets/units/%s/%s.png" % [art, strip])
	var n := int(ArtData.UNITS[art]["frames"][strip])
	return _alpha_w(t.get_image(), 0, t.get_width() / n)


func _alpha_w(img: Image, x0: int, w: int) -> int:
	if img.is_compressed():
		img.decompress()
	var lo := 99999
	var hi := -1
	for x in range(x0, x0 + w):
		for y in range(0, img.get_height(), 2):
			if img.get_pixel(x, y).a > 0.5:
				lo = mini(lo, x)
				hi = maxi(hi, x)
				break
	return hi - lo + 1 if hi >= 0 else 0


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
	# scale: each creature on clear ground beside the building it should match, its name above it (code-drawn text):
	# the Rootmaw by a Cottage (a bit bigger), the Tyrannosaur by a Barracks (the same size), the Brood Mother rooted by a
	# Clocktower (as big as its gear ring), the Mound Turtle rooted by the old Clutch Mound (it is its stand-in picture)
	await _scale_row()
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
	# the father breathes on the eggs: he stands west of the nest, the eggs roll out south-west of her, so he faces them
	# south-east (his breath frames' own view)
	var f: Unit = g._add_unit(BroodNew.FATHER, 0, q.position + Vector2(-140.0, -2.0))
	f.cmd_stop()
	await create_timer(1.0).timeout
	q.nb["eggs"] = 10
	q.cmd_lay("raptor")
	var egg: Unit = g.units.filter(func(u) -> bool: return u.kind == BroodNew.EGG and not u.dead).back()
	g.camera.position = (f.position + egg.position) * 0.5 + Vector2(0, -26)
	g.camera.zoom = Vector2(2.6, 2.6)
	# the GIF: one egg yellow-green, reddening under his breath, red, cracking and a Raptor out on the open shell
	for i in 72:
		if i == 24:
			g.camera.position = egg.position + Vector2(0, -16)
		await _snap("egg_%02d" % i, 0.2)
	for i in 3:
		q.cmd_lay("raptor")
	await create_timer(0.6).timeout
	g.camera.position = (f.position + q.position + Vector2(-34, 60)) * 0.5 + Vector2(0, -20)
	g.camera.zoom = Vector2(2.2, 2.2)
	for i in 4:
		await _snap("fertilise_%d" % i, 0.45)
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
