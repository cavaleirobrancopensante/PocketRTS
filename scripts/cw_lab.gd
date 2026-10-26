class_name CwLab
extends RefCounted
## The CLOCKWORK LAB (EDITOR menu): the human Clockwork starts with plenty of cogs and, in gear mode (the default), the
## GEAR FIELD on show: the Clocktower on its big ring with two Cog Presses and a Mainspring meshing round it, Winders
## working them, a Ratchet Turret, the camera on it, and the Lab's other buildings linked beyond. (With the Line on instead: a Line run with
## a Rail Yard, Assembly Works, Engine Hall, Boiler and Pylon beside it.) A hint line says what to try.
## Also holds the Line helpers the cw tests share (run_from_hall, beside).


static func setup(game: Game) -> void:
	var t := game.human
	var cfg: Dictionary = Defs.CW["lab"]
	game.players[t]["gold"] = int(cfg["ore"])
	game.players[t]["res2"] = float(cfg["res2"])
	if Defs.gear_mode:
		game.players[t]["tension"] = float(cfg["res2"])      # (gear mode: no energy; Tension instead)
		_gear_field(game, t, cfg)
		_hint(game)
		return
	var cells := run_from_hall(game, t, 44)
	if cells.is_empty():
		return
	var i := 3
	for k in cfg["buildings"]:
		while i < cells.size():
			var b := beside(game, t, String(k), cells[i])
			i += 3
			if b != null:
				break
	game.line_net.solve()
	_hint(game)


## The showcase, like art/redraws/base_demo.gif: the start's Cog Press is taken away and two presses and a Mainspring are
## put round the Clocktower where their rings mesh with its ring (directly when the grid allows, else through an idler),
## at three set angles (screen: up right, down left, down right).
## Then the new-style army: a Movement Works (training nothing yet) and a Regulator, built and linked, and SOLDIERS Clock
## Soldiers standing in front of the Works; and a Ratchet Turret, the static defence, built and linked on the field's
## edge (no power in gear mode: no Charging Pylon, no Boilers; Defs.ENERGY_KINDS are not in the gear build list).
const SHOWCASE := [["cog_press", -40.0], ["cog_press", 160.0], ["mainspring", 50.0], ["movement_works", -130.0], ["regulator", 105.0],
	["ratchet_turret", 5.0]]
const CREW := {"cog_press": 3, "mainspring": 3, "movement_works": 0, "regulator": 0, "ratchet_turret": 0}
const SOLDIERS := 4


static func _gear_field(game: Game, t: int, cfg: Dictionary) -> void:
	var hall: Building = null
	for b in game.buildings:
		if b.team == t and b.kind == game.faction_hall(t):
			hall = b
			break
	if hall == null:
		return
	for b in game.buildings.duplicate():
		if b.team == t and b.kind == Defs.GEAR_PRESS:
			_take_away(game, b)
	game.gear_net.solve()
	var put: Array = []
	for sc in SHOWCASE:
		var k := String(sc[0])
		var c := _ring_spot(game, t, k, hall, float(sc[1]))
		if c.x >= 0:
			var b := game._add_building(k, t, c, true)
			put.append(b)
			game.gear_net.solve()
	# the Lab's other buildings, linked to the field beyond the showcase
	for k in cfg["buildings"]:
		if not Defs.BUILDINGS.has(k) or not Defs.build_list("clockwork").has(k):
			continue
		var spot := game.find_spot(t, String(k), hall, 3, 24, "near")
		if spot.x >= 0:
			game._add_building(String(k), t, spot, true)
			game.gear_net.solve()
	# Winders on every machine (the start's ones first, then new ones)
	var free: Array = []
	for u in game.units:
		if u.team == t and u.kind == "winder" and not u.dead:
			free.append(u)
	for b in put:
		for i in int(CREW.get(b.kind, 2)):
			var u: Unit = free.pop_back() if not free.is_empty() else game._add_unit("winder", t, b.center() + Vector2(0, 70))
			u.cmd_gather(b)
	for u in free:
		u.cmd_stop()
	# the Clock Soldiers: a short rank in front of the Movement Works (else by the Clocktower)
	var works: Building = null
	for b in put:
		if b.kind == Defs.CW_WORKS:
			works = b
	var at: Vector2 = (works.center() + Vector2(0, float(works.size.y) * Defs.TILE * 0.5 + 70.0)) if works else hall.center() + Vector2(0, 150)
	for i in SOLDIERS:
		game._add_unit("clock_soldier", t, at + Vector2((float(i) - (SOLDIERS - 1) * 0.5) * 36.0, 0.0))
	if game.camera:
		game.camera.position = hall.center() + Vector2(0, 30)
		game.camera.zoom = Vector2(1.3, 1.3)


## Off the map at once (the Lab's start press: the showcase puts its own).
static func _take_away(game: Game, b: Building) -> void:
	for u in b.crew:
		if is_instance_valid(u) and not u.dead:
			u.cmd_stop()
	b.crew.clear()
	game._mark(b.cell, b.size, 0)
	game.selection.erase(b)
	game.buildings.erase(b)
	game._recount_supply(b.team)
	b.queue_free()


## The cell for `kind` whose ring meshes with the Clocktower's nearest to direction `deg` (screen degrees, 0 = right,
## clockwise): placeable, its ring links, the pitch-circle gap as small as possible (a direct mesh) and the angle close.
static func _ring_spot(game: Game, t: int, kind: String, hall: Building, deg: float) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var hc := GearNet.b_c(hall)
	var hr := GearNet.b_r(hall)
	var r := GearNet.ring_r(kind, size, false)
	var want := deg_to_rad(deg)
	var best := Vector2i(-1, -1)
	var bs := INF
	var h0 := game.cell_of(hall.center())
	for y in range(h0.y - 14, h0.y + 15):
		for x in range(h0.x - 14, h0.x + 15):
			var c := Vector2i(x, y)
			if not game.in_map(c):
				continue
			var g := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
			var gap := g.distance_to(hc) - hr - r
			if gap < -float(Defs.GEAR["overlap"]) * Defs.TILE or gap > float(Defs.GEAR["slack"]) * Defs.TILE:
				continue
			var da := absf(angle_difference(want, (g - hc).angle()))
			var score := absf(gap) + (0.0 if absf(gap) <= float(Defs.GEAR["mesh_tol"]) else 12.0) + da * 60.0
			if score >= bs:
				continue
			if game.placement_problem(t, kind, c) != "" or not game.margin_free(c, size):
				continue
			best = c
			bs = score
	return best


static func _hint(game: Game) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	var l := Label.new()
	l.text = hint_text()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.position = Vector2(14, 62)
	l.custom_minimum_size = Vector2(420, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(l)
	game.add_child(layer)


static func hint_text() -> String:
	if Defs.gear_mode:
		return Loc.t("CLOCKWORK LAB, the GEAR FIELD: every Clockwork building sits on a ring of ground gears that must mesh, ring to ring, back to the Clocktower's big ring, or it stops (UNLINKED). Where two rings do not quite touch, a small idler cog fills the gap. Winders crank the Cog Presses for cogs and the Mainspring for Tension. The new army: the Movement Works trains Clock Soldiers, the Regulator adds supply, the Ratchet Turret shoots screws at ground and air. Place more buildings: the ghost shows its ring turning and LINKS / NO LINK / CLASH. SANDBOX, tab CLOCK, spawns the new units. The enemy never attacks.")
	return Loc.t("CLOCKWORK LAB: open SANDBOX, tab CLOCK, to spawn the new units (rail vehicles land on the Line). The Rail Yard and Assembly Works train them too. The enemy never attacks.")


## A built straight-ish run of n segments for team t leaving its hall; returns the cells in order from the hall.
static func run_from_hall(g: Game, t: int, n: int) -> Array:
	var h: Building = null
	for b in g.buildings:
		if b.team == t and b.kind == g.faction_hall(t):
			h = b
			break
	if h == null:
		return []
	var ring: Array = g.line_net.ring(h)
	for c in ring:
		if not g.line_net.pipeable(t, c):
			continue
		var dist := {c: 0}
		var prev := {}
		var q: Array = [c]
		var i := 0
		var goal := Vector2i(-1, -1)
		while i < q.size() and goal.x < 0:
			var cur: Vector2i = q[i]
			i += 1
			for d in LineNetwork.DIRS:
				var nb: Vector2i = cur + d
				if not dist.has(nb) and g.line_net.pipeable(t, nb) and not ring.has(nb):
					dist[nb] = dist[cur] + 1
					prev[nb] = cur
					q.append(nb)
					if dist[nb] == n - 1:
						goal = nb
						break
		if goal.x < 0:
			continue
		var cells: Array = [goal]
		while cells[cells.size() - 1] != c:
			cells.append(prev[cells[cells.size() - 1]])
		cells.reverse()
		for cc in cells:
			g.line_net.add_built(t, cc)
		return cells
	return []


## A finished building of `kind` whose footprint touches the Line cell c.
static func beside(g: Game, t: int, kind: String, c: Vector2i) -> Building:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	for d in LineNetwork.DIRS:
		for off in range(-size.x + 1, 1):
			for off2 in range(-size.y + 1, 1):
				var origin := c
				if d == Vector2i(1, 0):
					origin = Vector2i(c.x + 1, c.y + off2)
				elif d == Vector2i(-1, 0):
					origin = Vector2i(c.x - size.x, c.y + off2)
				elif d == Vector2i(0, 1):
					origin = Vector2i(c.x + off, c.y + 1)
				else:
					origin = Vector2i(c.x + off, c.y - size.y)
				if _free(g, origin, size):
					return g._add_building(kind, t, origin, true)
	return null


static func _free(g: Game, origin: Vector2i, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			var cc := origin + Vector2i(x, y)
			if not g.in_map(cc) or g.solid[g.idx(cc)] != 0 or g.line_net.has_cell(cc) or g.ramp[g.idx(cc)] != 0 or g.cliff[g.idx(cc)] != 0:
				return false
	return true
