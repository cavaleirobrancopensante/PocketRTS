class_name CwLab
extends RefCounted
## The CLOCKWORK LAB (EDITOR menu): the human Clockwork starts with plenty of cogs and, in gear mode (the default), the
## GEAR FIELD on show: the Clocktower on its big ring with two Cog Presses and a Mainspring meshing round it, Winders
## working them, a Ratchet Turret, the Escapement meshing with the Mainspring and three Springers (tier 2), the Clock Aviary
## (internal kind cuckoo_house), three Swifts and a Ticking Owl (TICKING OWL researched), tier 3 (the Movement Works on its BIG
## gear, two Pendulums and two Netters), the camera on it, and the Lab's other buildings linked beyond. (With the Line on instead: a Line run with
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
		# (the Lab's Mainsprings start wound full: what they store, GearEcon.tension_cap)
		var cap := GearEcon.tension_cap(game, t)
		if cap > 0.0:
			game.players[t]["tension"] = minf(float(cfg["res2"]), cap)
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
## Tier 2: the Escapement meshing with the Mainspring's ring (a third entry: the kind it meshes with instead of the
## Clocktower; it tries ESC_ANGLES round it until one fits), working, and SPRINGERS Springers beside the soldiers.
## The Movement Works on the Clocktower's ring (down left) on its BIG gear (tier 3: the Pendulum), and a second Mainspring
## meshing with the Works (THE TENSION RULE, GearEcon: Springers, Pendulums and Netters cost Tension, so they are made only where
## a Mainspring meshes) and with the Clock Aviary (everything the Aviary makes costs Tension); SWIFTS Swifts and OWLS Ticking
## Owls hovering over the Clocktower's ring (in the Lab's first view). An entry that names a kind to mesh with tries
## ESC_ANGLES round the last one of that kind put, then its own angle on the Clocktower's ring.
const SHOWCASE := [["cog_press", -40.0], ["cog_press", 160.0], ["mainspring", 50.0], ["escapement", 0.0, "mainspring"],
	["movement_works", -130.0], ["mainspring", -95.0, "movement_works"], ["cuckoo_house", -95.0, "mainspring"], ["regulator", 105.0],
	["ratchet_turret", 5.0]]
const ESC_ANGLES := [0.0, 40.0, 80.0, -40.0, 120.0, -80.0, 160.0]
const CREW := {"cog_press": 6, "mainspring": 3, "movement_works": 0, "regulator": 0, "ratchet_turret": 0, "escapement": 0, "cuckoo_house": 0}
const SOLDIERS := 4
const SPRINGERS := 3
const SWIFTS := 3
const OWLS := 1
const PENDULUMS := 2
const NETTERS := 2


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
		var around: Building = hall
		var angles: Array = [float(sc[1])]
		if sc.size() > 2:
			# (meshing with one of the showcase's own buildings: the Escapement, the Aviary and the Works with the Mainspring)
			for b in put:
				if b.kind == String(sc[2]):
					around = b
			angles = ESC_ANGLES
		var placed := false
		for deg in angles:
			var c := _ring_spot(game, t, k, around, float(deg)) if around == hall else GearNet.ring_spot(game, t, k, around, float(deg), true)
			var big := false
			if k == Defs.CW_WORKS:
				# tier 3: the Works on its BIG gear (the Pendulum is made only there), its bigger ring meshing with the
				# Clocktower's (else on its small gear where that fits)
				var cb := _big_ring_spot(game, t, k, around, float(deg))
				if cb.x >= 0:
					c = cb
					big = true
			if c.x >= 0:
				var b := game._add_building(k, t, c, true)
				b.gear_big = big
				put.append(b)
				game.gear_net.solve()
				placed = true
				break
		if not placed and around != hall:
			# (no room round it: on the Clocktower's ring at its own angle; the Works on its big gear where that fits)
			var c2 := _ring_spot(game, t, k, hall, float(sc[1]))
			var big2 := false
			if k == Defs.CW_WORKS:
				var cb2 := _big_ring_spot(game, t, k, hall, float(sc[1]))
				if cb2.x >= 0:
					c2 = cb2
					big2 = true
			if c2.x >= 0:
				var b2 := game._add_building(k, t, c2, true)
				b2.gear_big = big2
				put.append(b2)
				game.gear_net.solve()
				placed = true
		if not placed:
			# (the plateau is crowded: anywhere it links)
			var c3 := game.find_spot(t, k, hall, 3, 24, "near")
			if c3.x >= 0:
				put.append(game._add_building(k, t, c3, true))
				game.gear_net.solve()
	# room in the supply for the Springers (2 each), the flyers (Swifts 2, the Owl 4) and tier 3 (Pendulums 4, Netters 2): five
	# more Regulators, linked, wherever they fit
	for i in 5:
		var rs := game.find_spot(t, Defs.CW_SUPPLY, hall, 3, 24, "near")
		if rs.x >= 0:
			game._add_building(Defs.CW_SUPPLY, t, rs, true)
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
	# the Springers: a rank just behind the soldiers
	for i in SPRINGERS:
		var jp := game.on_map(at + Vector2((float(i) - (SPRINGERS - 1) * 0.5) * 40.0, 44.0))
		game._add_unit(Defs.SPRINGER, t, game.cell_center(game.nearest_free(game.cell_of(jp), 4)) if not game.is_free(game.cell_of(jp)) else jp)
	# tier 3: the Pendulums at the ends of the soldiers' rank, the Netters behind the Springers
	for i in PENDULUMS:
		var pp := game.on_map(at + Vector2((-1.0 if i % 2 == 0 else 1.0) * (SOLDIERS * 18.0 + 40.0), 20.0 + 50.0 * float(i / 2)))
		game._add_unit(Defs.PENDULUM, t, game.cell_center(game.nearest_free(game.cell_of(pp), 4)) if not game.is_free(game.cell_of(pp)) else pp).cmd_stop()
	for i in NETTERS:
		var np := game.on_map(at + Vector2((float(i) - (NETTERS - 1) * 0.5) * 60.0, 92.0))
		game._add_unit(Defs.NETTER, t, game.cell_center(game.nearest_free(game.cell_of(np), 4)) if not game.is_free(game.cell_of(np)) else np).cmd_stop()
	# the air: TICKING OWL researched; the Swifts and the Owl
	game.players[t]["tech"]["owl_morph"] = true
	# (over the Clocktower's ring, up right, where the Lab's first view shows them clear of the soldiers and the hint: a little
	# V of Swifts, the Owl behind them)
	var sky: Vector2 = hall.center() + Vector2(95, -105)
	for i in SWIFTS:
		var k := float(i) - (SWIFTS - 1) * 0.5
		var su: Unit = game._add_unit(Defs.CUCKOO, t, game.on_map(sky + Vector2(k * 40.0, 22.0 * absf(k))))
		su.cmd_stop()
	for i in OWLS:
		var ou: Unit = game._add_unit(Defs.OWL, t, game.on_map(sky + Vector2(-60.0 + 60.0 * float(i), 70.0)))
		ou.cmd_stop()
	# and room left in the supply to train more at once (a Pendulum takes 4): more Regulators while fewer than 12 are free
	# (the big-gear Works' ring crowds the plateau: when no open spot is left, one against the plateau's cliffs or the map's
	# edge that leaves every route open, find_spot's tight ground mode)
	for i in 6:
		game._recount_supply(t)
		if game.supply_used(t) + 12 <= int(game.players[t]["cap"]) or int(game.players[t]["cap"]) >= game.max_supply(t):
			break
		var rs := game.find_spot(t, Defs.CW_SUPPLY, hall, 3, 26, "near")
		if rs.x < 0:
			rs = game.find_spot(t, Defs.CW_SUPPLY, hall, 3, 26, "near", true)
		if rs.x < 0:
			break
		game._add_building(Defs.CW_SUPPLY, t, rs, true)
		game.gear_net.solve()
	game._recount_supply(t)
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


## The cell for `kind` whose ring meshes with `hall`'s (the Clocktower's, or any building's) nearest to direction `deg`
## (GearNet.ring_spot).
static func _ring_spot(game: Game, t: int, kind: String, hall: Building, deg: float) -> Vector2i:
	return GearNet.ring_spot(game, t, kind, hall, deg)


## The cell for `kind` on its BIG gear whose ring meshes with `around`'s nearest to direction `deg` (GearNet.ring_spot for the
## big ring: within the link gap and no deeper than the overlap; placed as the computer places), or (-1, -1).
static func _big_ring_spot(game: Game, t: int, kind: String, around: Building, deg: float) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var hc := GearNet.b_c(around)
	var hr := GearNet.b_r(around)
	var r := GearNet.ring_r(kind, size, true)
	var want := deg_to_rad(deg)
	var best := Vector2i(-1, -1)
	var bs := INF
	var h0 := game.cell_of(around.center())
	for y in range(h0.y - 16, h0.y + 17):
		for x in range(h0.x - 16, h0.x + 17):
			var c := Vector2i(x, y)
			if not game.in_map(c):
				continue
			var gp := GearNet.gpos(Vector2(c) * Defs.TILE + Vector2(size) * Defs.TILE * 0.5)
			var gap := gp.distance_to(hc) - hr - r
			if gap < -float(Defs.GEAR["overlap"]) * Defs.TILE or gap > float(Defs.GEAR["slack"]) * Defs.TILE:
				continue
			var score := absf(gap) + (0.0 if absf(gap) <= float(Defs.GEAR["mesh_tol"]) else 12.0) + absf(angle_difference(want, (gp - hc).angle())) * 60.0
			if score >= bs:
				continue
			if not GearNet.level_ok(game, kind, c, true, around):
				continue          # (gears mesh only on the same ground level)
			if game.placement_problem(t, kind, c, true) != "" or game.gear_net.candidate(t, kind, c, true)["state"] != "ok" or not game.margin_free(c, size):
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
	# (wide enough that the whole hint stays above the minimap and the control-group bar, clear of the sandbox panel)
	l.custom_minimum_size = Vector2(640, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(l)
	game.add_child(layer)


static func hint_text() -> String:
	if Defs.gear_mode:
		return Loc.t("CLOCKWORK LAB, the GEAR FIELD: every Clockwork building sits on a ring of ground gears that must mesh, ring to ring, back to the Clocktower's big ring, or it stops (UNLINKED); an idler cog fills a small gap between two rings. Winders crank the Cog Presses for cogs and the Mainspring for Tension. The Movement Works trains the army, the Regulator adds supply, the Ratchet Turret shoots at ground and air. TIER 2: the ESCAPEMENT must mesh with the Mainspring (every Tension user must, or it shows NEEDS MAINSPRING); it unlocks the SPRINGER, which hops, shoots at ground and air and can JUMP (E, then tap a spot; up a cliff you can see only after HIGH LEAP, researched at the Escapement). THE AIR: the CLOCK AVIARY makes SWIFTS, fast flyers that peck other flyers; once TICKING OWL is researched there, a Swift's MORPH TO OWL turns it into a Ticking Owl that swoops on units and bombs buildings. TIER 3: PENDULUMS (only from a Movement Works on its BIG gear, as here; a Works' gear is swapped on its card) cut every enemy in the arc in front of them; a NETTER's chain net stops one enemy for 4 s and brings a flyer down. New buildings: the ghost shows its ring turning and LINKS / NO LINK / CLASH. SANDBOX, tab CLOCK, spawns the new units. The enemy never attacks.")
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
