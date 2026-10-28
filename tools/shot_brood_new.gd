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
## root_NN.png     the Tyrannosaur settling on his nest beside the Mother (the GIF root.gif)
## father_nest.png the Tyrannosaur rooted on his nest beside the Mother, 3 Raptor eggs in it (counted over him)
## fertilise_N.png him rooted, fertilising (close)
## egg_NN.png      his nest's queue counting down, the eggs hatching there (the GIF egg.gif)
## loop_<kind>_NN  each rooted creature's loop, close (the GIFs loop_<kind>.gif)
## lay_NN.png      the rooted Mother laying twice (the GIF lay.gif)
## turtle.png      Mound Turtles beside the Mother: walking, rooting (sinking into the mud), rooted
## haul.png        a Rootmaw hauling its food, and a spilled pile
## fight.png       the Mother, the Tyrannosaur and Raptors against Crown Musketeers
var main: Node
var g
var out := ""
var t := 0.0
var started := false
var scale_o := Vector2i(10, 10)       # the scale picture's clear ground (cells), reused for the turtle's walks


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


## A corner (cells) where the scale picture's 30 x 20 tiles are clear ground: nearest the map's middle.
func _scale_origin() -> Vector2i:
	var mid := Vector2i(Game.W / 2 - 15, Game.H / 2 - 10)
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(1, Game.H - 21, 2):
		for x in range(1, Game.W - 31, 2):
			var c := Vector2i(x, y)
			var dd := Vector2(c - mid).length()
			if dd >= bd:
				continue
			var ok := true
			for yy in range(0, 20, 1):
				for xx in range(0, 30, 1):
					var cc := c + Vector2i(xx, yy)
					if not g._walkable(cc) or not g.is_free(cc) or g.ramp[g.idx(cc)] != 0 or g.height[g.idx(cc)] != g.height[g.idx(c)]:
						ok = false
						break
				if not ok:
					break
			if ok:
				bd = dd
				best = c
	return best if best.x >= 0 else Vector2i(10, 10)


## The scale row (scale.png, scale_mother.png).
func _scale_row() -> void:
	# two rows on clear ground: Cottage + Rootmaw, Barracks + Tyrannosaur, Clutch Mound + Mound Turtle on top; the
	# Clocktower with its gear ring + the Brood Mother below (each pair a few tiles apart, nothing overlapping)
	var o := _scale_origin()
	scale_o = o
	var cot: Building = g._add_building("cottage", 1, o + Vector2i(1, 4), true)
	var bar: Building = g._add_building("barracks", 1, o + Vector2i(9, 3), true)
	var mnd: Building = g._add_building("clutch_mound", 1, o + Vector2i(22, 4), true)
	var tow: Building = g._add_building("clocktower", 1, o + Vector2i(4, 13), true)
	var mw: Unit = g._add_unit(BroodNew.MAW, 0, Vector2((o.x + 6.0) * Defs.TILE, (o.y + 6.0) * Defs.TILE))
	var ty: Unit = g._add_unit(BroodNew.FATHER, 0, Vector2((o.x + 17.5) * Defs.TILE, (o.y + 6.0) * Defs.TILE))
	var tu: Unit = g._add_unit(BroodNew.TURTLE, 0, Vector2((o.x + 27.0) * Defs.TILE, (o.y + 6.0) * Defs.TILE))
	var mo: Unit = g._add_unit(BroodNew.QUEEN, 0, Vector2((o.x + 21.0) * Defs.TILE, (o.y + 18.0) * Defs.TILE))
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
				top = Vector2(e.rect().get_center().x, e.rect().end.y - float(ArtData.BUILDING_SIZE.get(e.kind, Vector2i(64, 64)).y) - 6.0)
			else:
				top = e.position - Vector2(0, _top_h(e) + 10.0)
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
	print("SIZES Brood Mother rooted %d (walking %d); Rootmaw %d; Tyrannosaur %d; Mound Turtle rooted %d (walking %d)" % [
		_strip_w("brood_mother", "rooted_se"), _strip_w("brood_mother", "walk_se"), _strip_w("rootmaw", "walk_se"),
		_strip_w("tyrannosaur", "walk_se"), _strip_w("mound_turtle", "rooted_se"), _strip_w("mound_turtle", "walk_se")])
	g.camera.position = Vector2((o.x + 15.0) * Defs.TILE, (o.y + 11.0) * Defs.TILE)
	g.camera.zoom = Vector2(1.1, 1.1)
	await _snap("scale", 0.6)
	g.camera.position = Vector2((o.x + 13.0) * Defs.TILE, (o.y + 13.5) * Defs.TILE)
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


## How high (px) a creature's picture stands over its feet: its rooted or walking south-east frame's top row.
func _top_h(u: Unit) -> float:
	var strip := "rooted_se" if u.tesla_mode == "deployed" and ArtData.UNITS[u.art]["frames"].has("rooted_se") else "walk_se"
	var t: Texture2D = load("res://assets/units/%s/%s.png" % [u.art, strip])
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	var fw: int = t.get_width() / int(ArtData.UNITS[u.art]["frames"][strip])
	for y in img.get_height():
		for x in range(0, fw, 2):
			if img.get_pixel(x, y).a > 0.5:
				return float(ArtData.UNITS[u.art]["anchor"].y - y)
	return 40.0


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
	# the rooted Mother LAYING (in code until her sheet comes: a heave, her clutch flaring, the egg popping out to the
	# nest's rim): lay_NN every 0.06 s (tools/brood_new_gif.py: lay.gif)
	g.camera.position = q.position + Vector2(-10.0, -110.0)
	g.camera.zoom = Vector2(1.6, 1.6)
	await create_timer(0.5).timeout
	q.nb["eggs"] = 10
	for j in 2:
		q.cmd_lay("grub")
		for i in 22:
			await _snap("lay_%02d" % (j * 22 + i), 0.06)
	# the father ROOTED on his nest beside her (the Brood's barracks): he walks up west of her, settles (the cross-fade
	# until his rooting frames come: root_NN), her Raptor eggs go into his nest, he fertilises them, they hatch there
	# (the eggs laid on the walk and what hatched from them out of the way first)
	for u in g.units.duplicate():
		if not u.dead and u.team == 0 and (u.kind == BroodNew.EGG or u.kind == "grub") and u.position.distance_to(q.position) < 600.0:
			g.consume_unit(u)
	var f: Unit = g._add_unit(BroodNew.FATHER, 0, q.position + Vector2(-205.0, 60.0))
	f.cmd_stop()
	await create_timer(0.5).timeout
	f.cmd_deploy()
	g.camera.position = q.position + Vector2(-90.0, -10.0)
	g.camera.zoom = Vector2(1.5, 1.5)
	for i in 30:
		await _snap("root_%02d" % i, 0.1)
	await create_timer(0.5).timeout
	print("FATHER rooted %s near %s" % [f.tesla_mode, BroodNew.father_near(g, 0)])
	q.nb["eggs"] = 10
	for i in 3:
		print("LAY %s" % q.cmd_lay("raptor"))
	await create_timer(0.3).timeout
	await _snap("father_nest", 0.4)
	g.camera.position = f.position + Vector2(10.0, -50.0)
	g.camera.zoom = Vector2(2.4, 2.4)
	for i in 4:
		await _snap("fertilise_%d" % i, 0.45)
	# the GIF: the nest's queue counting down and the eggs hatching there (egg_NN every 0.25 s)
	for i in 64:
		if i % 8 == 0:
			var eggs := BroodNew.nest_eggs(g, f)
			print("NEST %d %d %s" % [i, eggs.size(), str(eggs[0].nb) if not eggs.is_empty() else "-"])
		await _snap("egg_%02d" % i, 0.25)
	# each rooted creature's loop, close (loop_<kind>_NN every 0.1 s: tools/brood_new_gif.py makes loop_<kind>.gif):
	# the Mother (her breathing row, her eggs glowing), the Tyrannosaur (breathing, his fire and eggs flickering), a
	# Rootmaw half full (breathing, its food glowing)
	for c in [[q, Vector2(0, -90), 1.6], [f, Vector2(0, -60), 2.6]]:
		var u: Unit = c[0]
		g.camera.position = u.position + c[1]
		g.camera.zoom = Vector2(c[2], c[2])
		await create_timer(0.4).timeout
		for i in 30:
			await _snap("loop_%s_%02d" % [u.kind, i], 0.1)
	maw.nb["food"] = 160.0
	g.camera.position = maw.position + Vector2(0, -30)
	g.camera.zoom = Vector2(3.4, 3.4)
	await create_timer(0.4).timeout
	for i in 30:
		await _snap("loop_rootmaw_%02d" % i, 0.1)
	# the Mound Turtle beside the Mother: one walking up, one rooting (sinking into the mud), one rooted
	var tw: Unit = g._add_unit(BroodNew.TURTLE, 0, walk_spot(q.position + Vector2(-60.0, 190.0), 1.0))
	var tr: Unit = g._add_unit(BroodNew.TURTLE, 0, walk_spot(q.position + Vector2(70.0, 200.0), 1.0))
	var td: Unit = g._add_unit(BroodNew.TURTLE, 0, walk_spot(q.position + Vector2(200.0, 150.0), 1.0))
	td.cmd_deploy()
	await create_timer(float(Defs.NB["turtle_switch"]) + 0.3).timeout
	tw.cmd_move(tw.position + Vector2(-160.0, 60.0))
	tr.cmd_deploy()
	await create_timer(float(Defs.NB["turtle_switch"]) * 0.4).timeout
	g.camera.position = q.position + Vector2(40.0, 120.0)
	g.camera.zoom = Vector2(1.4, 1.4)
	await _snap("turtle", 0.4)      # (the camera needs a few frames to get there)
	await create_timer(float(Defs.NB["turtle_switch"])).timeout
	g.camera.position = td.position + Vector2(0, -30)
	g.camera.zoom = Vector2(3.4, 3.4)
	await create_timer(0.4).timeout
	for i in 30:
		await _snap("loop_mound_turtle_%02d" % i, 0.1)
	for u in [tw, tr, td]:
		g.consume_unit(u)
	# the turtle walking every way (the JPEG sheets' S, NE, N beside the PNG SE and E; west mirrored), at normal and
	# close zoom: turtle_dirs.png, turtle_dirs_close.png
	# (on the scale picture's clear ground: S, SE, E, NE, N, NW, W, SW left to right, 3 tiles apart)
	var row0: Vector2 = Vector2((scale_o.x + 15.0) * Defs.TILE, (scale_o.y + 10.0) * Defs.TILE)
	var walkers: Array = []
	var ways := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1)]
	for i in ways.size():
		var t: Unit = g._add_unit(BroodNew.TURTLE, 0, row0 + Vector2((i - 3.5) * 3.0 * Defs.TILE, 0.0))
		walkers.append(t)
	await create_timer(0.3).timeout
	for i in ways.size():
		walkers[i].cmd_move(walkers[i].position + Vector2(ways[i]).normalized() * 400.0)
	await create_timer(0.7).timeout
	g.camera.position = row0 + Vector2(0, -30)
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap("turtle_dirs", 0.4)
	g.camera.zoom = Vector2(2.4, 2.4)
	g.camera.position = row0 + Vector2(-1.5 * 3.0 * Defs.TILE, -30)
	await _snap("turtle_dirs_close", 0.4)
	for u in walkers:
		g.consume_unit(u)
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
