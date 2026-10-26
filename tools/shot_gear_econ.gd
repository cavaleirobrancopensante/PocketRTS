extends SceneTree
## Screenshots of THE CLOCKWORK'S ECONOMY RULES (scripts/gear_econ.gd) in the CLOCKWORK LAB: the efficiency labels over the
## buildings (crew, bar, %), a building linked two rings out (90%), the cards (a Cog Press's efficiency line, the Movement
## Works' Tension rule line, the Mainspring's store), the top bar's Tension held / stored, and the placement ghost before a
## building is placed (a Cog Press ghost two rings out: "LINKS 90%"; a Mainspring ghost by a Works that has none: "FEEDS 1"),
## and THE LEVEL RULE: a Regulator ghost on the low ground whose ring reaches the field on the high ground: "NO LINK: OTHER
## LEVEL".
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --script res://tools/shot_gear_econ.gd -- <outdir>
## Writes <outdir>/labels.png, labels_close.png, card_press.png, card_works.png, card_spring.png, card_works_far.png,
## ghost_drive.png, ghost_spring.png, ghost_level.png, top_bar.png.
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
		if b.team == g.human and b.kind == kind and not b.dead and b.built:
			return b
	return null


## The Lab's hint line (its own CanvasLayer, 40) on or off.
func _hint(on: bool) -> void:
	for c in g.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer == 40:
			c.visible = on


## The placeable, linking cell for a building of `kind` nearest `near` (px) for which `ok(cell)` holds, else (-1, -1).
func _scan(kind: String, near: Vector2, ok: Callable) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var h0: Vector2i = g.cell_of(near)
	var best := Vector2i(-1, -1)
	var bd := INF
	var n := [0, 0, 0, 0]
	var why := {}
	var steps := {}
	for y in range(h0.y - 18, h0.y + 19):
		for x in range(h0.x - 18, h0.x + 19):
			var c := Vector2i(x, y)
			if not g.in_map(c):
				continue
			var pp: String = g.placement_problem(g.human, kind, c, true)
			if pp != "":
				why[pp] = int(why.get(pp, 0)) + 1
				continue
			n[0] += 1
			if not g.margin_free(c, size):
				continue
			n[1] += 1
			var st := String(g.gear_net.candidate(g.human, kind, c).get("state", ""))
			if st != "ok":
				why[st] = int(why.get(st, 0)) + 1
				continue
			n[2] += 1
			var ps := GearEcon.preview_steps(g.gear_net, g.human, kind, c)
			steps[ps] = int(steps.get(ps, 0)) + 1
			if not ok.call(c):
				continue
			n[3] += 1
			var d := (Vector2(c) * Defs.TILE).distance_to(near)
			if d < bd:
				bd = d
				best = c
	print("scan %s: placeable %d, margin %d, gear ok %d, wanted %d; steps %s; refusals %s" % [kind, n[0], n[1], n[2], n[3], str(steps), str(why)])
	return best


## A cell where a building of `kind` would link two rings out from the nearest driver (90%), nearest `near`; on a crowded
## plateau three or four rings out (80%, 70%).
func _second_ring(kind: String, near: Vector2) -> Vector2i:
	for want in [2, 3, 4]:
		var c := _scan(kind, near, func(cc: Vector2i) -> bool: return GearEcon.preview_steps(g.gear_net, g.human, kind, cc) == want)
		if c.x >= 0:
			return c
	return Vector2i(-1, -1)


## A cell on free ground (no ramp) where a building of `kind` would reach the human's field only across a level change
## (GearNet.candidate: "far" with "level"), nearest the Clocktower; (-1, -1) when none.
func _other_level(kind: String, hall: Building) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(hall.cell.y - 24, hall.cell.y + 25):
		for x in range(hall.cell.x - 24, hall.cell.x + 25):
			var c := Vector2i(x, y)
			if not g.in_map(c) or not g.margin_free(c, size):
				continue
			var ok := true
			for yy in size.y:
				for xx in size.x:
					var cc := c + Vector2i(xx, yy)
					if not g.in_map(cc) or not g.is_free(cc) or g.ramp[g.idx(cc)] == 1:
						ok = false
			if not ok:
				continue
			var st: Dictionary = g.gear_net.candidate(g.human, kind, c)
			if st["state"] != "far" or not st.get("level", false):
				continue
			var d := Vector2(c - hall.cell).length()
			if d < bd:
				bd = d
				best = c
	return best


## The camera on a placement ghost of `kind` at cell c (the ghost stays where it is put: no mouse motion moves it).
func _look_at_ghost(kind: String, c: Vector2i) -> void:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	g.camera.position = Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5 + Vector2(0, 40)
	g.camera.zoom = Vector2(1.4, 1.4)


func _run() -> void:
	var hall := _find("clocktower")
	var press := _find(Defs.GEAR_PRESS)
	var works := _find(Defs.CW_WORKS)
	var spring := _find("mainspring")
	var reg := _find(Defs.CW_SUPPLY)
	print("lab: press %s works %s spring %s regulator %s" % [str(press != null), str(works != null), str(spring != null), str(reg != null)])
	if hall == null or press == null or works == null or spring == null:
		print("LAB NOT SET UP")
		quit(1)
		return
	for sp in root.find_children("*", "SandboxPanel", true, false):
		sp.open = false
		sp._build()
	# a Movement Works two rings out from the Clocktower (hung on a building of its ring, no Mainspring by it: 90%), built
	# at once
	var extra: Building = null
	var c2 := _second_ring(Defs.CW_WORKS, hall.center())
	if c2.x >= 0:
		extra = g._add_building(Defs.CW_WORKS, g.human, c2, true)
		g.gear_net.solve()
	print("a Works two rings out: %s (%s)" % [str(extra != null), str(g.gear_net.drive_of.get(extra, -1)) if extra else "-"])
	await _snap("labels", 2.5)
	_hint(false)
	g.camera.position = hall.center() + Vector2(0, 40)
	g.camera.zoom = Vector2(1.15, 1.15)
	await _snap("labels_close", 0.6)
	# the cards: a Cog Press, the Movement Works (the Tension rule line), the Mainspring (its store), the far Works
	g.set_selection([press])
	g.camera.position = press.center() + Vector2(0, 60)
	await _snap("card_press", 1.0)
	g.set_selection([works])
	g.camera.position = works.center() + Vector2(0, 60)
	await _snap("card_works", 1.0)
	g.set_selection([spring])
	g.camera.position = spring.center() + Vector2(0, 60)
	await _snap("card_spring", 1.0)
	if extra != null:
		g.set_selection([extra])
		g.camera.position = extra.center() + Vector2(0, 60)
		await _snap("card_works_far", 1.0)
	g.set_selection([])
	# the placement ghost: a Movement Works rings out says LINKS 90% (80%...) before it is placed
	var gc := _second_ring(Defs.CW_WORKS, (extra if extra != null else hall).center())
	print("a Works ghost rings out: %s (%d)" % [str(gc), GearEcon.preview_steps(g.gear_net, g.human, Defs.CW_WORKS, gc) if gc.x >= 0 else -1])
	if gc.x >= 0:
		g.controls.begin_place(Defs.CW_WORKS)
		g.controls.ghost_cell = gc
		_look_at_ghost(Defs.CW_WORKS, gc)
		await _snap("ghost_drive", 0.6)
		g.controls.cancel_mode()
	# a Mainspring ghost by the far Works (no Mainspring meshes with it): FEEDS 1
	var sc := Vector2i(-1, -1)
	if extra != null:
		sc = _scan("mainspring", extra.center(), func(c: Vector2i) -> bool: return not GearEcon.would_feed(g.gear_net, g.human, c).is_empty())
	print("a Mainspring ghost that feeds: %s" % str(sc))
	if sc.x >= 0:
		g.controls.begin_place("mainspring")
		g.controls.ghost_cell = sc
		_look_at_ghost("mainspring", sc)
		await _snap("ghost_spring", 0.6)
		g.controls.cancel_mode()
	# THE LEVEL RULE: a ghost on the other ground level whose ring reaches the field (it says NO LINK: OTHER LEVEL)
	var lc := _other_level(Defs.CW_SUPPLY, hall)
	print("a ghost on the other level: %s" % str(lc))
	if lc.x >= 0:
		g.controls.begin_place(Defs.CW_SUPPLY)
		g.controls.ghost_cell = lc
		_look_at_ghost(Defs.CW_SUPPLY, lc)
		g.camera.zoom = Vector2(1.15, 1.15)
		await _snap("ghost_level", 0.6)
		g.controls.cancel_mode()
	# the top bar: Tension held of what the Mainsprings store
	g.players[g.human]["tension"] = 140.0
	g.camera.position = hall.center()
	g.camera.zoom = Vector2(1.0, 1.0)
	await _snap("top_bar", 0.6)
	print("done")
	quit()
