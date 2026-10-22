class_name Game
extends Node2D
## The match: map, pathfinding, entities, economy, combat helpers, fog of war,
## selection and commands. UI (hud.gd), input (controls.gd) and the AI (ai.gd)
## all talk to this node.

signal ended(winner: int)

## The map's size in cells: set from the map before the match is built (MapGen.size_of);
## 84 x 60 for the classic maps and custom ones.
static var W := 84
static var H := 60
const T := Defs.TILE
const HASH := 64

static var _tex_cache := {}

var human := 0
var factions: Array = ["crown", "crown"]
var colours: Array = [0, 1]                 # each player's index into Defs.PALETTE
var sides: Array = [0, 1]                   # players on the same side are allies
var income_mult: Array = []                 # the Brutal AI's cheat (1.0 = fair)
var eliminated: Array = []


func n_players() -> int:
	return factions.size()


func team_colour(t: int) -> Color:
	return Defs.PALETTE[colours[t]][1] if t >= 0 and t < colours.size() else Color.RED


func team_name(t: int) -> String:
	return Defs.PALETTE[colours[t]][0] if t >= 0 and t < colours.size() else ""


## Enemies: both real players and on different sides.
func hostile(a: int, b: int) -> bool:
	return a >= 0 and b >= 0 and a != b and sides[a] != sides[b]


func allied(a: int, b: int) -> bool:
	return a == b or (a >= 0 and b >= 0 and sides[a] == sides[b])


## Can side `t` go for `e`: an enemy, or (the Brood only) a loose horse, belonging to nobody,
## for its essence.
func prey(t: int, e: Entity) -> bool:
	return hostile(e.team, t) or (loose_horse(e) and t >= 0 and t < factions.size() and faction_of(t) == "brood")


## A horse belonging to nobody (its rider fell and it bolted: Unit._rider_falls).
static func loose_horse(e) -> bool:
	return e is Unit and e.team < 0 and e.kind == "horse" and not e.dead


func enemies_of(t: int) -> Array:
	var out: Array = []
	for o in n_players():
		if hostile(t, o) and not eliminated[o]:
			out.append(o)
	return out
var swamp: Array = []
var swamp_dirty := true
var swamp_layer: Node2D
var field_layer: Node2D                  # Clockwork fields of the selected / placed building
var swamp_img: Image                     # the swamp of every Brood player, for the minimap
var swamp_tex: ImageTexture
var _swamp_t := 0.0
var _notify_t := 0
var difficulty := 1
var demo := false                        # AI controls both sides
var edit_mode := false                   # the map editor: just the ground, no players
var sandbox := false                     # the sandbox: spawn anything, any player
var reveal := false                      # sandbox: no fog of war
var rng := RandomNumberGenerator.new()

var solid := PackedByteArray()           # 0 free, 1 terrain, 2 building, 3 gate, 4 wall, 5 farm field (walkable, not buildable)
var water := PackedByteArray()
var height := PackedByteArray()          # 1 = high ground
var ramp := PackedByteArray()
var cliff := PackedByteArray()
var map_id := "random"
var map_name := ""
var mapgen: MapGen
var astar := AStarGrid2D.new()
var astar_siege := AStarGrid2D.new()     # walls and gates counted as open: the way to break in
var units: Array = []
var buildings: Array = []
var crates: Array = []                   # Clockwork crates dropped on the way to their sites (Crate)
var ghost_cells := {}                    # map index -> the ghost sites (Building.ghost) over that cell
var base_sites: Array = []               # hall cells of every base site (all mains and expansions)
var players: Array = []
var starts: Array = []                   # town hall cells per team
var expansions: Array = []               # free town hall spots

var world: Node2D
var ground: Node2D                       # the ground pictures (_render_ground)
var fog_sprite: Sprite2D
var fog_img: Image
var fog_tex: ImageTexture
var vis: Array = []
var explored := PackedByteArray()
var explored_by: Array = []              # demo: what each player has explored (for the spectator's fog)
var view_team := -1                      # demo: whose fog the spectator sees (-1 = all vision)
var spectator: Node                      # demo: the spectator camera (spectator.gd)
var last_placed: Array = []              # per player: {"at", "t", "kind"} of the last building placed
var _vis_t := 0.0
var _disk_cache := {}
var minimap_img: Image
var camera: Camera2D
var overlay: Node2D
var controls: Node
var hud: Control
var ais: Array = []

var selection: Array = []
var groups: Array = [[], [], [], [], [], [], [], [], []]
var _hash := {}
var _path_queue: Array = []
var _end_t := 0.0
var over := false
var winner := -1
var clock := 0.0
var stats: Array = []
var soil_scars: Array = []               # [centre, soil left, hall kind, lode left] where a Town Hall, Hive or Clocktower fell
var _sample_t := 0.0
var mlog: MatchLog              # the playtest log (copied from the end screen)
var _first_of := {}             # "team:kind" -> true once that player has had one


static func _new_stats() -> Dictionary:
	return {"lost": 0, "killed": 0, "gold": 0, "spent": 0, "trained": 0, "built": 0,
		"razed": 0, "bld_lost": 0, "damage": 0.0, "peak_army": 0, "value_killed": 0, "res2_in": 0.0, "sacrificed": 0, "sacrifice_essence": 0, "revived": 0,
		"horses_bolted": 0, "horses_caught": 0, "kills_by": {}, "army_tl": [0], "gold_tl": [0], "workers_tl": [0]}


static func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func _init() -> void:
	rng.randomize()


func _ready() -> void:
	var msz := MapGen.size_of(map_id)
	W = msz.x
	H = msz.y
	solid.resize(W * H)
	water.resize(W * H)
	cliff.resize(W * H)
	height.resize(W * H)
	ramp.resize(W * H)
	explored.resize(W * H)
	var n := n_players()
	while colours.size() < n:
		colours.append(colours.size())
	while sides.size() < n:
		sides.append(sides.size())
	while income_mult.size() < n:
		income_mult.append(1.0)
	for t in n:
		eliminated.append(false)
		energy.append(0.0)
		ore_rate.append(0.0)
		asm_mult.append(1.0)
		wind_e.append(0.0)
		stats.append(_new_stats())
		var v := PackedByteArray()
		v.resize(W * H)
		vis.append(v)
		var sw := PackedByteArray()
		sw.resize(W * H)
		swamp.append(sw)
		var ex := PackedByteArray()
		ex.resize(W * H if demo else 0)
		explored_by.append(ex)
		last_placed.append({})
		players.append({"gold": Defs.START_GOLD, "cap": 0, "faction": factions[t], "res2": 0.0,
			"gold_f": 0.0, "split": Defs.SPLITS["ECONOMY"].duplicate(), "split_name": "ECONOMY", "gold_x": 0.0,
			"tech": {}})
	ground = Node2D.new()
	ground.z_index = -20
	add_child(ground)
	swamp_layer = Node2D.new()
	swamp_layer.z_index = -19
	swamp_layer.draw.connect(_draw_swamp)
	add_child(swamp_layer)
	field_layer = Node2D.new()
	field_layer.z_index = -18
	field_layer.draw.connect(_draw_fields)
	add_child(field_layer)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	body_bars = Node2D.new()
	body_bars.z_index = 1
	body_bars.draw.connect(_draw_body_bars)
	add_child(body_bars)
	overlay = Node2D.new()
	overlay.z_index = 50
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	fog_sprite = Sprite2D.new()
	fog_sprite.centered = false
	fog_sprite.scale = Vector2(T, T)
	fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fog_sprite.z_index = 40
	add_child(fog_sprite)
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = -40
	camera.limit_right = W * T
	camera.limit_bottom = H * T + 170
	add_child(camera)
	camera.make_current()
	_generate_map()
	_setup_astar()
	_render_ground()
	if edit_mode:
		fog_sprite.visible = false
		camera.position = Vector2(W, H) * T * 0.5
		camera.zoom = Vector2(0.6, 0.6)
		return
	_start_positions()
	_init_fog()
	mlog = MatchLog.new()
	mlog.game = self
	add_child(mlog)
	var me: Building = _own_hall(human)
	camera.position = me.global_position + Vector2(160, 40)
	camera.zoom = Vector2(1.5, 1.5)


# ------------------------------------------------------------------ map

func idx(c: Vector2i) -> int:
	return c.y * W + c.x


func in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / T), 0, W - 1), clampi(int(p.y / T), 0, H - 1))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * T + Vector2(T, T) * 0.5


func is_free(c: Vector2i) -> bool:
	return in_map(c) and solid[idx(c)] == 0


func _mirror(c: Vector2i, size: Vector2i) -> Vector2i:
	return Vector2i(W - c.x - size.x, H - c.y - size.y)


func _generate_map() -> void:
	mapgen = MapGen.new(self)
	mapgen.generate(map_id)
	_near_ramp_grid = PackedByteArray()


func _scatter_obstacles(keep: Array) -> void:
	var half_cells: Array = []
	# Lakes
	for lake in [[Vector2(22, 50), Vector2(5, 3)], [Vector2(40, 12), Vector2(3, 2)]]:
		var c: Vector2 = lake[0]
		var r: Vector2 = lake[1]
		for y in range(int(c.y - r.y - 1), int(c.y + r.y + 2)):
			for x in range(int(c.x - r.x - 1), int(c.x + r.x + 2)):
				var q := Vector2((x - c.x) / r.x, (y - c.y) / r.y)
				if q.length() <= 1.0 + rng.randf_range(-0.15, 0.1):
					half_cells.append([Vector2i(x, y), "water"])
	# Tree and rock clusters
	for i in 22:
		var kind := "tree" if rng.randf() < 0.75 else "rock"
		var p := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(2, H - 3))
		var n := rng.randi_range(4, 14) if kind == "tree" else rng.randi_range(2, 5)
		for k in n:
			half_cells.append([p, kind])
			p += [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi() % 4]
	# Map border of trees, with gaps
	for x in W:
		if rng.randf() < 0.7:
			half_cells.append([Vector2i(x, 0), "tree"])
	for y in H:
		if rng.randf() < 0.7:
			half_cells.append([Vector2i(0, y), "tree"])
	for hc in half_cells:
		var c: Vector2i = hc[0]
		if not in_map(c):
			continue
		var bad := false
		for k in keep:
			if (Vector2(c) + Vector2(0.5, 0.5)).distance_to(k[0]) < k[1]:
				bad = true
				break
		if bad:
			continue
		for cc in [c, _mirror(c, Vector2i.ONE)]:
			if hc[1] == "water":
				water[idx(cc)] = 1
			solid[idx(cc)] = 1
			if hc[1] != "water":
				_terrain_kind[idx(cc)] = hc[1]


var _terrain_kind := {}


func _connected(a: Vector2i, b: Vector2i) -> bool:
	var seen := PackedByteArray()
	seen.resize(W * H)
	var start := a + Vector2i(2, 5)
	var goal := b + Vector2i(2, -1)
	var q: Array = [start]
	seen[idx(start)] = 1
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		if c == goal:
			return true
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dd
			if in_map(n) and seen[idx(n)] == 0 and solid[idx(n)] == 0:
				seen[idx(n)] = 1
				q.append(n)
	return false


## solid: 0 open, 1 terrain, 2 building, 3 gate, 4 wall (paths run through gates; only
## units of the gate's side and its allies can actually step on one).
func _mark(c: Vector2i, size: Vector2i, v: int) -> void:
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if in_map(cc):
				solid[idx(cc)] = v
				if v != 0 and _deco_at.has(idx(cc)):
					# a building (wall, field...) goes up over a decoration: it's gone
					for s in _deco_at[idx(cc)]:
						s.visible = false
				_region_dirty = true
				if astar.region.size != Vector2i.ZERO:
					astar.set_point_solid(cc, v != 0 and v != 3 and v != 5)
				if astar_siege.region.size != Vector2i.ZERO:
					astar_siege.set_point_solid(cc, v == 1 or v == 2)


## Gates: map index -> the team that owns it.
var gate_team := {}


## Can a unit of team `t` stand on this cell? (t = -1: nobody may pass gates.)
func passable(c: Vector2i, t: int) -> bool:
	if not in_map(c):
		return false
	var v := solid[idx(c)]
	if v == 0 or v == 5:
		return true
	return v == 3 and t >= 0 and allied(int(gate_team.get(idx(c), -1)), t)


## The cells of a wall from a to b: a straight line without diagonal gaps (when it steps
## diagonally it adds a cell, so nothing can slip between two corners).
func line_cells(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = [a]
	var c := a
	var guard := 0
	while c != b and guard < 200:
		guard += 1
		var d := b - c
		var step := Vector2i(signi(d.x), signi(d.y))
		if step.x != 0 and step.y != 0:
			# move along the longer axis first, then the other: no corner-only contact
			var t: float = float(absi(d.x)) / float(maxi(1, absi(d.y)))
			var first := Vector2i(step.x, 0) if t >= 1.0 else Vector2i(0, step.y)
			c += first
			out.append(c)
			if c == b:
				break
			c += step - first
		else:
			c += step
		out.append(c)
	return out


## Your own wall piece (built or not) on this cell, if any.
func _own_wall_at(t: int, c: Vector2i) -> Building:
	for b in buildings:
		if b.kind == "wall" and b.team == t and not b.dead and b.cell == c:
			return b
	return null


## Your own gate (built or not) on this cell, if any.
func _own_gate_at(t: int, c: Vector2i) -> Building:
	for b in buildings:
		if b.kind == "gate" and b.team == t and not b.dead and b.cell == c:
			return b
	return null


## Take a building off the map without a death (a wall piece a gate replaces).
func _remove_quietly(b: Building) -> void:
	if b.ghost:
		_reserve_ghost(b, false)
	else:
		_mark(b.cell, b.size, 0)
		gate_team.erase(idx(b.cell))
	selection.erase(b)
	buildings.erase(b)
	b.dead = true
	b.queue_free()
	_astar_dirty = true
	relink_walls(b.cell)


## Gates turn to match the palisade they're placed in (drawn side-on, gate_v, in a
## north-south line): a side's own walls and gates (built or planned sites) on the gate's
## four sides decide. Only north and/or south: N-S; only east and/or west: E-W; both ways
## or none: `fallback` (the player's last R choice, or for the computer the lie of the
## land, see _terrain_facing). plan: cells -> kind of pieces about to be laid with it.
var gate_pref_vertical := false     # the player's R choice while placing gates (remembered)
var _gate_plan := {}                # place_line: the rest of the line being laid


func gate_facing(t: int, c: Vector2i, plan: Dictionary = {}, fallback := false) -> bool:
	var ns := false
	var ew := false
	for b in buildings:
		if b.team != t or b.dead or not (b.kind == "wall" or b.kind == "gate"):
			continue
		var d: Vector2i = b.cell - c
		if absi(d.x) + absi(d.y) == 1:
			if d.x == 0:
				ns = true
			else:
				ew = true
	for pc in plan:
		var d: Vector2i = pc - c
		if absi(d.x) + absi(d.y) == 1:
			if d.x == 0:
				ns = true
			else:
				ew = true
	if ns != ew:
		return ns
	return fallback


## A gate with no line to follow: the side its blocked neighbours (cliffs, buildings) are
## on, as a wall would run between them.
func _terrain_facing(c: Vector2i) -> bool:
	var ns := 0
	var ew := 0
	for dv in [Vector2i(0, -1), Vector2i(0, 1)]:
		var cc: Vector2i = c + dv
		if in_map(cc) and solid[idx(cc)] != 0 and solid[idx(cc)] != 5:
			ns += 2 if solid[idx(cc)] >= 3 else 1
	for dv in [Vector2i(-1, 0), Vector2i(1, 0)]:
		var cc: Vector2i = c + dv
		if in_map(cc) and solid[idx(cc)] != 0 and solid[idx(cc)] != 5:
			ew += 2 if solid[idx(cc)] >= 3 else 1
	return ns > ew


## Which way a gate side t lays at c faces (see gate_facing).
func new_gate_facing(t: int, c: Vector2i, plan: Dictionary = {}) -> bool:
	return gate_facing(t, c, plan, gate_pref_vertical if t == human else _terrain_facing(c))


## A gate still only planned or being built turns when the palisade beside it changes (its
## first wall neighbour, say). A finished gate never flips by itself, nor one turned by hand.
func _orient_gates(around: Vector2i) -> void:
	for b in buildings:
		if b.kind != "gate" or b.dead or b.built or b.dir_locked or (b.cell - around).abs().x > 1 or (b.cell - around).abs().y > 1:
			continue
		b.set_vertical(gate_facing(b.team, b.cell, {}, b.vertical))


## Palisade auto-tiling (as in Age of Empires 2): each wall piece shows the picture for
## which of its four neighbours (N, E, S, W: bits 1, 2, 4, 8) are its side's walls or
## gates. A gate joins only along its own line: an E-W gate ("gate") on its east and west,
## a N-S gate ("gate_v", drawn side-on) on its north and south (its far and near posts);
## across a gate the line just ends (the stakes would stand in its gateway or in front of
## its doors; its posts take their place). A ghost site joins only in its own side's (and
## allies') eyes. plan: cells -> kind of pieces about to be laid (the placement preview).
const LINK_DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


func _links_from(c: Vector2i, kinds: Dictionary) -> int:
	var m := 0
	for i in 4:
		var k: String = kinds.get(c + LINK_DIRS[i], "")
		if k == "wall" or (k == "gate" and i % 2 == 1) or (k == "gate_v" and i % 2 == 0):
			m |= 1 << i
	return m


## The kinds of side t's wall and gate pieces within `r` cells (Manhattan) of c, as seen
## by whoever is watching.
func _line_kinds(t: int, c: Vector2i, r: int) -> Dictionary:
	var out := {}
	var ft := fog_team()
	for b in buildings:
		if b.team != t or b.dead or not (b.kind == "wall" or b.kind == "gate"):
			continue
		var dc: Vector2i = b.cell - c
		if absi(dc.x) + absi(dc.y) > r or (b.ghost and hidden_ghost(b, ft)):
			continue
		out[b.cell] = "gate_v" if b.kind == "gate" and b.vertical else b.kind
	return out


func wall_links(t: int, c: Vector2i, plan: Dictionary = {}) -> int:
	var kinds := _line_kinds(t, c, 1)
	for pc in plan:
		if not kinds.has(pc):
			kinds[pc] = plan[pc]
	return _links_from(c, kinds)


## Re-pick the pictures of the wall pieces on and round a cell whose piece changed (built,
## placed, lost, abandoned, swapped, or a ghost turned real).
func relink_walls(c: Vector2i) -> void:
	for t in players.size():
		var kinds := _line_kinds(t, c, 2)
		if kinds.is_empty():
			continue
		for b in buildings:
			if b.kind == "wall" and b.team == t and not b.dead and absi(b.cell.x - c.x) + absi(b.cell.y - c.y) <= 1:
				b.set_links(_links_from(b.cell, kinds))


## The picture of a wall or gate about to be laid at c (the placement preview): the
## palisade piece its neighbours (and the rest of the planned line) make; a gate turned
## the way its line runs (new_gate_facing: the R choice where that doesn't say).
func line_ghost_tex(k: String, c: Vector2i, plan: Dictionary) -> Texture2D:
	if k == "wall":
		return tex("res://assets/buildings/%s_built.png" % Building.wall_piece(wall_links(human, c, plan)))
	return tex("res://assets/buildings/%s_built.png" % ("gate_v" if new_gate_facing(human, c, plan) else "gate"))


## Lay a line of walls or gates; returns how many pieces went down.
## queued (Shift): the builders do the whole line, piece after piece, after the orders they
## already have (otherwise the first piece, then whatever is unfinished nearby).
func place_line(t: int, k: String, a: Vector2i, b: Vector2i, builders: Array, queued := false) -> int:
	var n := 0
	var first := true
	var pieces: Array = []
	# gates laid as a line take the line's way (each one sees the whole line planned)
	_gate_plan = {}
	if k == "gate":
		for c in line_cells(a, b):
			if placement_problem(t, k, c) == "":
				_gate_plan[c] = k
	for c in line_cells(a, b):
		if placement_problem(t, k, c) != "":
			continue
		# a wall over one of your gates: only when that one piece is placed on it (a wall
		# dragged past your gates keeps them)
		if k == "wall" and _own_gate_at(t, c) != null and a != b:
			continue
		if players[t]["gold"] < int(Defs.BUILDINGS[k]["cost"]):
			if t == human:
				notify("Not enough gold for the whole wall.")
			break
		var bl := place_building(t, k, c, builders if first and not queued else [])
		if bl:
			n += 1
			first = false
			pieces.append(bl)
	_gate_plan = {}
	if queued and not pieces.is_empty():
		for u in builders:
			if u is Unit and u.is_worker() and not u.dead:
				u.give({"o": "wall", "pieces": pieces}, true)
	if mlog and n > 0:
		mlog.add("%s laid %d piece%s of %s" % [mlog.who(t), n, "" if n == 1 else "s", Defs.BUILDINGS[k]["name"]])
	return n


## The nearest enemy wall or gate right in front of a unit that can't get through.
func blocking_wall(u: Unit) -> Building:
	var best: Building = null
	var bd := 70.0
	for b in buildings:
		if b.dead or not b.built or not (b.kind == "wall" or b.kind == "gate") or not hostile(b.team, u.team):
			continue
		var dd: float = b.edge_distance(u.position)
		if dd < bd and u.can_hit(b):
			bd = dd
			best = b
	return best


## A labourer that finishes a piece picks up the next unfinished piece of fortification
## or building nearby that nobody is working on.
func next_site(u: Unit) -> Building:
	var best: Building = null
	var bd := 8.0 * T
	for b in buildings:
		if b.team != u.team or b.dead or b.built or b.d["faction"] != "crown":
			continue
		var busy := false
		for o in units_near(b.center(), 60.0):
			if o != u and o.team == u.team and o.order == "build" and o.order_target == b:
				busy = true
				break
		if busy:
			continue
		var dd: float = b.center().distance_to(u.position)
		if dd < bd:
			bd = dd
			best = b
	return best


func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(T, T)
	astar.offset = Vector2(T, T) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	astar_siege = AStarGrid2D.new()
	astar_siege.region = astar.region
	astar_siege.cell_size = astar.cell_size
	astar_siege.offset = astar.offset
	astar_siege.diagonal_mode = astar.diagonal_mode
	astar_siege.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_siege.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_siege.update()
	_region_dirty = true
	for y in H:
		for x in W:
			var sv := solid[y * W + x]
			if sv != 0 and sv != 3 and sv != 5:
				astar.set_point_solid(Vector2i(x, y), true)
			if sv == 1 or sv == 2:
				astar_siege.set_point_solid(Vector2i(x, y), true)
	# Trees and rocks as sprites
	for sp in _terrain_sprites:
		sp.queue_free()
	_terrain_sprites.clear()
	_deco_at.clear()
	for i in _terrain_kind:
		var c := Vector2i(i % W, i / W)
		var kind: String = _terrain_kind[i]
		if kind == "prop":
			continue                     # a decoration's foot (drawn below)
		var s := Sprite2D.new()
		var bi: Dictionary = MapGen.BIOMES[mapgen.biome_at(c.x, c.y)]
		var n := rng.randi_range(0, 5)
		var bush := kind == "tree" and rng.randf() < 0.35
		if bush:
			n = rng.randi_range(4, 5)    # bushes
		if kind == "tree" and bi.has("tree_art"):
			# this biome's own trees and bushes (from the decorations)
			var arts: Array = bi["bush_art"] if bush else bi["tree_art"]
			s.texture = tex("res://assets/props/%s.png" % arts[rng.randi() % arts.size()])
			s.flip_h = rng.randf() < 0.5
		else:
			s.texture = tex("res://assets/world/%s_%d.png" % [kind, n])
			s.modulate = bi["tint"]
		s.centered = false
		s.offset = Vector2(-s.texture.get_width() * 0.5, -s.texture.get_height() + 4)
		s.position = cell_center(c) + Vector2(rng.randf_range(-3, 3), 14)
		if kind == "rock":
			s.scale = Vector2(0.7, 0.7)
		world.add_child(s)
		_terrain_sprites.append(s)
	# decorations: drawn among the units (sorted by their foot)
	for pr in mapgen.props:
		if pr["dead"]:
			continue
		var s := Sprite2D.new()
		s.texture = tex("res://assets/props/%s.png" % pr["name"])
		s.centered = false
		s.offset = Vector2(-s.texture.get_width() * 0.5, -s.texture.get_height() + 3)
		s.position = pr["pos"]
		s.flip_h = pr["flip"]
		world.add_child(s)
		_terrain_sprites.append(s)
		if (pr["cells"] as Array).is_empty():
			var at: Vector2i = pr["at"]
			if not _deco_at.has(idx(at)):
				_deco_at[idx(at)] = []
			_deco_at[idx(at)].append(s)


var _terrain_sprites: Array = []
var _deco_at := {}                         # map index -> the walk-through decorations standing there


## Map editor: redo ramps, cliffs, decorations, pathing and the ground picture after
## painting, the same way a custom map is built for a match (MapGen.apply_custom).
func rebuild_map(cells: String, props: Array = []) -> void:
	mapgen.read_cells(cells)
	mapgen._square_ramps()
	mapgen._cliffs()
	mapgen.place_props(props)
	height = mapgen.height
	ramp = mapgen.ramp
	_near_ramp_grid = PackedByteArray()
	astar = AStarGrid2D.new()
	_setup_astar()
	_render_ground()


## Map editor: only the decorations changed (the ground picture stays).
func refresh_props(props: Array) -> void:
	for i in mapgen._prop_at:
		solid[i] = 0
		_terrain_kind.erase(i)
	mapgen.place_props(props)
	astar = AStarGrid2D.new()
	_setup_astar()


var _tile_cache := {}
var _tile_avg := {}


## The variants of a ground set the painter uses (the calm and mid grass are toned copies of
## the grass tiles, so they take its list; without one only variant 0 was used, and one
## picture repeated every cell drew a regular grid). With the seams blended, a few more of the
## plain variants of the commonest grounds join the generated lists (MORE_VARIANTS); the
## desert's sand had only its two banded dune pictures, whose stripes broke off at every
## cell edge, and takes the plainer ones instead (OWN_VARIANTS).
const MORE_VARIANTS := {"grass": [0, 1], "moss": [0, 4]}
const OWN_VARIANTS := {"sand": [5, 1, 8]}


var _good_cache := {}


func _good(set_name: String) -> Array:
	if not _good_cache.has(set_name):
		var base := set_name
		if set_name == "grass_calm" or set_name == "grass_mid":
			base = "grass"
		var good: Array = TerrainData.GOOD.get(base, TerrainData2.GOOD.get(base, [0]))
		if MORE_VARIANTS.has(base):
			good = good + MORE_VARIANTS[base]
		good = OWN_VARIANTS.get(base, good)
		_good_cache[set_name] = good
	return _good_cache[set_name]


func _tile_key(set_name: String, rnd: int) -> String:
	var good := _good(set_name)
	return "%s_%d" % [set_name, good[rnd % good.size()]]


## The second atlas's ground sets are 64 x 64 pictures, each laid over 2 x 2 cells (the
## art's own scale: at one cell a tile its detail repeats too tightly).
static func _is_macro(set_name: String) -> bool:
	return TerrainData2.COUNTS.has(set_name) and not set_name.ends_with("_face") and not set_name.ends_with("_top")


func _tile(set_name: String, rnd: int) -> Image:
	var key := _tile_key(set_name, rnd)
	if not _tile_cache.has(key):
		_load_set(set_name)
	return _tile_cache[key]


## Loads every variant of a ground set at once: each picture's edges mended (_mend_edges) and
## its brightness evened out to the set's mean, so neighbouring cells or blocks don't read as
## a checkerboard of lighter and darker squares. Cliff faces, tops and ramps keep their art.
func _load_set(set_name: String) -> void:
	var good := _good(set_name)
	var sz := T * 2 if _is_macro(set_name) else T
	var ground := not (set_name.ends_with("_face") or set_name.ends_with("_top") or set_name.ends_with("_ramp"))
	var ims := {}
	var lums := {}
	var total := 0.0
	for v in good:
		var key := "%s_%d" % [set_name, v]
		if ims.has(key):
			continue
		var im: Image = tex("res://assets/terrain/%s.png" % key).get_image().duplicate()
		im.convert(Image.FORMAT_RGBA8)
		if im.get_width() != sz or im.get_height() != sz:
			im.resize(sz, sz, Image.INTERPOLATE_NEAREST)
		if ground:
			_mend_edges(im)
			_flatten_edges(im)
		var avg := _mean_colour(im)
		ims[key] = im
		lums[key] = avg.get_luminance()
		total += lums[key]
	var mean := total / maxf(ims.size(), 1)
	for key in ims:
		var im: Image = ims[key]
		if ground and lums[key] > 0.01:
			var gain := clampf(mean / lums[key], 0.8, 1.25)
			if absf(gain - 1.0) > 0.005:
				im.adjust_bcs(gain, 1.0, 1.0)
		_tile_cache[key] = im
		_tile_avg[key] = _mean_colour(im)


## Many pictures are lighter or darker along an edge (a band of glare on ice, a shadowed side):
## side by side such bands lined up into stripes along the grid. Each line in the outer fifth
## of the picture is brought toward the picture's mean brightness, fully at the edge and less
## going in (a dark or light veil over the line, so it's native and quick).
static func _flatten_edges(im: Image) -> void:
	var s := im.get_width()
	var r_n := s / 5
	var mean := _mean_colour(im).get_luminance()
	for e in 4:
		for d in r_n:
			var r: Rect2i
			match e:
				0: r = Rect2i(0, d, s, 1)
				1: r = Rect2i(0, s - 1 - d, s, 1)
				2: r = Rect2i(d, 0, 1, s)
				_: r = Rect2i(s - 1 - d, 0, 1, s)
			var l := _mean_colour(im.get_region(r)).get_luminance()
			if l < 0.02 or l > 0.98:
				continue
			var g := clampf(lerpf(1.0, mean / l, 1.0 - float(d) / r_n), 0.7, 1.4)
			var a := 0.0
			var veil := Color(0, 0, 0)
			if g < 0.995:
				a = 1.0 - g                       # c * g
			elif g > 1.005:
				veil = Color(1, 1, 1)
				a = clampf(l * (g - 1.0) / (1.0 - l), 0.0, 0.6)   # lifts the line's mean to l * g
			else:
				continue
			var ov := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
			ov.fill(Color(veil.r, veil.g, veil.b, a))
			im.blend_rect(ov, Rect2i(Vector2i.ZERO, r.size), r.position)


## The true average colour of a picture (its smallest mipmap).
static func _mean_colour(im: Image) -> Color:
	var m: Image = im.duplicate()
	m.generate_mipmaps()
	var n := m.get_mipmap_count()
	var off := m.get_mipmap_offset(n)
	var d := m.get_data()
	return Color8(d[off], d[off + 1], d[off + 2], 255)


## Many ground pictures were cut from their atlas with a stray line along an edge (a dark or
## bright row of the sheet's grid): laid side by side these drew straight lines across the
## ground. An edge row or column that stands out from the picture just inside it is replaced
## by its mirror image from inside (up to three deep).
static func _mend_edges(im: Image) -> void:
	var s := im.get_width()
	var line := func(e: int, d: int) -> Rect2i:
		match e:
			0: return Rect2i(0, d, s, 1)
			1: return Rect2i(0, s - 1 - d, s, 1)
			2: return Rect2i(d, 0, 1, s)
		return Rect2i(s - 1 - d, 0, 1, s)
	var lum := func(r: Rect2i) -> float:
		var sum := 0.0
		for py in range(r.position.y, r.end.y):
			for px in range(r.position.x, r.end.x):
				sum += im.get_pixel(px, py).get_luminance()
		return sum / (r.size.x * r.size.y)
	var tmp := im.duplicate()
	for e in 4:
		var ref := 0.0
		for d in range(3, 7):
			ref += lum.call(line.call(e, d))
		ref /= 4.0
		var good := 0                      # the first line in from the edge past every stray one
		for d in 3:
			if absf(lum.call(line.call(e, d)) - ref) > 0.055:
				good = d + 1
		if good == 0:
			continue
		for d in good:
			var src: Rect2i = line.call(e, 2 * good - d)
			var dst: Rect2i = line.call(e, d)
			im.blit_rect(tmp, src, dst.position)


const FLIPS := ["heather", "heath", "leaves", "roots", "fern", "cinder", "steppe", "scrub", "pine", "tundra",
	"reeds", "glow", "burnt", "shingle", "deep", "rubble", "slate"]
## One-cell grounds whose pictures may be mirrored left to right (organic ones: more ways to
## lay their few variants, so the same picture doesn't repeat in rows).
const FLIPS1 := ["grass", "grass_calm", "grass_mid", "grass_dark", "moss", "swamp", "autumn", "forest",
	"savanna", "sand", "desert", "snow", "dirt", "mud", "gravel"]
## One-cell waters drawn to tile seamlessly: left as they are among themselves (mirrored or
## blended, their sparse glints made a grid of mirror images).
const NO_SEAM := ["water", "shallow"]


static func _mirrors(set_name: String) -> int:
	return 2 if FLIPS.has(set_name) or FLIPS1.has(set_name) else 1


## The picture for one cell of a ground set: its own tile, or for a 64 x 64 set the quarter
## of the picture laid over its 2 x 2 block. `pick` (_pick_variant) is the variant and,
## for the organic grounds, whether it is mirrored (on cracked or layered ones it shows).
func _cell_tile(set_name: String, x: int, y: int, pick: int) -> Image:
	var m := _mirrors(set_name)
	var v := pick / m
	var flip := pick % m == 1
	if not _is_macro(set_name):
		var one := _tile(set_name, v)
		if not flip:
			return one
		var fkey := _tile_key(set_name, v) + "#m"
		if not _tile_cache.has(fkey):
			var mi: Image = one.duplicate()
			mi.flip_x()
			_tile_cache[fkey] = mi
		return _tile_cache[fkey]
	var key := "%s#%d%d%d" % [_tile_key(set_name, v), x & 1, y & 1, int(flip)]
	if not _tile_cache.has(key):
		var src := _tile(set_name, v)
		if flip:
			src = src.duplicate()
			src.flip_x()
		_tile_cache[key] = src.get_region(Rect2i((x & 1) * T, (y & 1) * T, T, T))
	return _tile_cache[key]


static func _hash2(x: int, y: int, salt: int) -> int:
	var h := ((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0xfffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return (h ^ (h >> 16)) & 0x7fffffff


## Which picture a cell (one-cell grounds) or a 2 x 2 block (64 x 64 grounds) gets: a hashed
## pick, but not the variant of the one left of it or above it (nor, when the set has enough,
## of the two diagonally above): the same picture side by side showed as a repeat, mirrored
## as a mirror line. `near` = the picks [left, up, up-left, up-right] of the same ground
## (-1: none). Returns variant * mirrors + mirrored.
func _pick_variant(set_name: String, h: int, near: Array) -> int:
	var n := _good(set_name).size()
	var m := _mirrors(set_name)
	var vn: Array = []
	for c in near:
		vn.append(-1 if c < 0 else c / m)
	var v0 := h % n
	var flip := (h >> 9) % m
	if n < 3:
		return v0 * m + flip         # (with two, keeping them apart would lay a checkerboard)
	for strict in [4, 2]:
		for k in n:
			var v := (v0 + k) % n
			var clash := false
			for q in mini(strict, vn.size()):
				if vn[q] == v:
					clash = true
			if not clash:
				return v * m + flip
	# too few variants: not the left one's (beside it, mirrored or not, it shows), and not
	# the very picture above it (the same one mirrored below it reads as another)
	for k in n * m:
		var c := (h + k) % (n * m)
		if (vn.size() < 1 or c / m != vn[0]) and (near.size() < 2 or c != near[1]):
			return c
	for k in n * m:
		var c := (h + k) % (n * m)
		if (near.size() < 1 or c != near[0]) and (near.size() < 2 or c != near[1]):
			return c
	return h % (n * m)


## The ground is drawn in square pieces of CHUNK cells (one picture for a whole big map
## would be too large a texture for many phones).
const CHUNK := 64


## Masks for the soft borders between grounds: a ragged band along one side (0 left,
## 1 right, 2 top, 3 bottom) or round one corner (4 top-left, 5 top-right, 6 bottom-left,
## 7 bottom-right), two of each so the edges don't repeat.
var _masks: Array = []


func _edge_masks() -> Array:
	if not _masks.is_empty():
		return _masks
	for v in 2:
		var row: Array = []
		for k in 8:
			var m := Image.create(T, T, false, Image.FORMAT_LA8)
			for py in T:
				for px in T:
					var nz := fposmod(sin((px + v * 37) * 12.9898 + (py + k * 11) * 78.233) * 43758.5453, 1.0)
					var wob := sin((px if k >= 2 else py) * 0.55 + v * 2.0 + k) * 2.5
					var d := 0.0
					match k:
						0: d = px
						1: d = T - 1 - px
						2: d = py
						3: d = T - 1 - py
						4: d = Vector2(px, py).length()
						5: d = Vector2(T - 1 - px, py).length()
						6: d = Vector2(px, T - 1 - py).length()
						7: d = Vector2(T - 1 - px, T - 1 - py).length()
					var reach := 8.0 + wob + nz * 4.0
					m.set_pixel(px, py, Color(1, 1, 1, 1.0 if d < reach else 0.0))
			row.append(m)
		_masks.append(row)
	return _masks


## The same for the borders between patches of plain ground (a biome's low sets, two biomes
## meeting): deeper and meandering, so a patch's outline doesn't follow the cells' squares
## (water and fords keep the shallow borders above). The meander follows the map, not the
## cell: it runs on unbroken from one cell to the next along a border (a 4-cell wave, its
## phase set by which grid line the border is on). [along % 4][line % 4][side 0-3], then
## [4 + corner] for the corners.
var _pmasks: Array = []


func _patch_masks() -> Array:
	if not _pmasks.is_empty():
		return _pmasks
	var reach_at := func(t: float, line: int, nz: float) -> float:
		var a := t / (4.0 * T) * TAU
		return 13.0 + sin(a + line * 1.9) * 6.5 + sin(3.0 * a + line * 2.7 + 1.0) * 3.0 + nz * 3.0
	for along in 4:
		var by_line: Array = []
		for line in 4:
			var sides: Array = []
			for k in 4:
				var m := Image.create(T, T, false, Image.FORMAT_LA8)
				for py in T:
					for px in T:
						var nz := fposmod(sin((px + along * 37 + line * 5) * 12.9898 + (py + k * 11) * 78.233) * 43758.5453, 1.0)
						var t := float(along * T + (px if k >= 2 else py))
						var d := float([px, T - 1 - px, py, T - 1 - py][k])
						m.set_pixel(px, py, Color(1, 1, 1, 1.0 if d < reach_at.call(t, line, nz) else 0.0))
				sides.append(m)
			by_line.append(sides)
		_pmasks.append(by_line)
	for k in range(4, 8):
		var m := Image.create(T, T, false, Image.FORMAT_LA8)
		for py in T:
			for px in T:
				var nz := fposmod(sin(px * 12.9898 + (py + k * 11) * 78.233) * 43758.5453, 1.0)
				var cx := 0 if k == 4 or k == 6 else T - 1
				var cyy := 0 if k == 4 or k == 5 else T - 1
				var d := Vector2(px - cx, py - cyy).length()
				m.set_pixel(px, py, Color(1, 1, 1, 1.0 if d < 14.0 + nz * 3.0 else 0.0))
		_pmasks.append(m)
	return _pmasks


## The patch border mask for side or corner k of cell (x, y) (see _patch_masks).
func _patch_mask(pm: Array, k: int, x: int, y: int) -> Image:
	if k >= 4:
		return pm[k]
	var along := y if k < 2 else x
	var line: int = [x, x + 1, y, y + 1][k]
	return pm[posmod(along, 4)][posmod(line, 4)][k]


## Seam blending between neighbouring cells of one level of ground (the same ground or two
## different ones): no ground picture tiles seamlessly with its neighbours (different variants,
## a 64 x 64 block next to another, a picture next to itself), and laid on a grid their edges
## drew straight lines. Across each cell edge, a band SEAM_W pixels deep on each side is mixed:
## each side shows the other side's picture mirrored over the edge (mirrored, the two meet
## without a jump) past a wavy, dithered cut line, a different one for each edge, so no
## straight line and no regular pattern is left. Done with masked blits (native, quick).
const SEAM_W := 8
var _seam_masks: Array = []      # 8 x [band across a vertical edge, the same turned]


func _seam_mask_set() -> Array:
	if not _seam_masks.is_empty():
		return _seam_masks
	var w := SEAM_W
	var on := Color(1, 1, 1, 1)
	var off := Color(1, 1, 1, 0)
	for k in 8:
		var p1 := k * 1.73 + 0.3
		var p2 := k * 2.91 + 1.1
		var f1 := 0.19 + 0.035 * (k % 3)
		var f2 := 0.45 + 0.05 * (k % 4)
		# one band 2 * SEAM_W across the edge: pixel u (0 = the farthest into side A)
		var v := Image.create(2 * w, T, false, Image.FORMAT_LA8)
		var h := Image.create(T, 2 * w, false, Image.FORMAT_LA8)
		for t in T:
			# where the cut runs, across the edge (negative: into side A)
			var c := 4.5 * (0.62 * sin(t * f1 + p1) + 0.38 * sin(t * f2 + p2))
			for u in 2 * w:
				var j := (fposmod(sin((u + k * 13) * 12.9898 + (t + k * 7) * 78.233) * 43758.5453, 1.0) - 0.5) * 5.0
				var d := u - w + 0.5             # signed distance from the edge
				# on side A, B's mirror image past the cut; on side B, A's before it
				var swap := (d + j >= c) if d < 0.0 else (d + j < c)
				v.set_pixel(u, t, on if swap else off)
				h.set_pixel(t, u, on if swap else off)
		_seam_masks.append([v, h])
	return _seam_masks


## `sid`: each cell's ground set as a number; `macro`, `no_seam`: per set number.
func _blend_seams(img: Image, er: Rect2i, sid: PackedInt32Array, zone: PackedInt32Array,
		macro: PackedByteArray, no_seam: PackedByteArray) -> void:
	var w := SEAM_W
	var sm := _seam_mask_set()
	var rv := Rect2i(0, 0, 2 * w, T)
	var rh := Rect2i(0, 0, T, 2 * w)
	for vert in [true, false]:
		for y in range(er.position.y, er.end.y - (0 if vert else 1)):
			for x in range(er.position.x, er.end.x - (1 if vert else 0)):
				var i := y * W + x
				var j: int = i + 1 if vert else i + W
				var z := zone[i]
				if z < 0 or zone[j] != z or (z == 2 and not vert):
					continue
				var s := sid[i]
				if s == sid[j]:
					# inside one 2 x 2 block the picture runs on
					if macro[s] == 1 and ((x & 1 == 0) if vert else (y & 1 == 0)):
						continue
					if no_seam[s] == 1:
						continue
				var m: Array = sm[(x * 73856093 ^ y * 19349663 ^ (0 if vert else 83492791)) & 7]
				var px := (x - er.position.x) * T
				var py := (y - er.position.y) * T
				# the band across the edge, mirrored over it: its A half now shows B's
				# mirror image and its B half A's; blitted back where the mask says
				if vert:
					px += T - w
					var band := img.get_region(Rect2i(px, py, 2 * w, T))
					band.flip_x()
					img.blit_rect_mask(band, m[0], rv, Vector2i(px, py))
				else:
					py += T - w
					var band := img.get_region(Rect2i(px, py, T, 2 * w))
					band.flip_y()
					img.blit_rect_mask(band, m[1], rh, Vector2i(px, py))


## A plateau's rim (its cliff cells that show no face) darkens smoothly toward the low ground
## beside it: a soft gradient per open side, and round a corner where only the diagonal is open.
var _rim_pieces: Array = []      # 4 sides (left, right, top, bottom), 4 corners (tl, tr, bl, br)


func _shade_rims(img: Image, cr: Rect2i, zone: PackedInt32Array) -> void:
	if _rim_pieces.is_empty():
		var reach := 22.0
		for k in 8:
			var p := Image.create(T, T, false, Image.FORMAT_RGBA8)
			for py in T:
				for px in T:
					var fx := px + 0.5
					var fy := py + 0.5
					var d := 0.0
					match k:
						0: d = fx
						1: d = T - fx
						2: d = fy
						3: d = T - fy
						4: d = Vector2(fx, fy).length()
						5: d = Vector2(T - fx, fy).length()
						6: d = Vector2(fx, T - fy).length()
						7: d = Vector2(T - fx, T - fy).length()
					var a := pow(clampf(1.0 - d / reach, 0.0, 1.0), 1.6) * 0.34
					p.set_pixel(px, py, Color(0, 0, 0, a))
			_rim_pieces.append(p)
	var low := func(c: Vector2i) -> bool:
		return in_map(c) and zone[idx(c)] == 0
	var full := Rect2i(0, 0, T, T)
	for y in range(cr.position.y, cr.end.y):
		for x in range(cr.position.x, cr.end.x):
			var i := y * W + x
			if cliff[i] != 1 or zone[i] != 1:
				continue
			var at := Vector2i(x - cr.position.x, y - cr.position.y) * T
			var l: bool = low.call(Vector2i(x - 1, y))
			var r: bool = low.call(Vector2i(x + 1, y))
			var u: bool = low.call(Vector2i(x, y - 1))
			var dn: bool = low.call(Vector2i(x, y + 1))
			var sides := [l, r, u, dn]
			for k in 4:
				if sides[k]:
					img.blend_rect(_rim_pieces[k], full, at)
			if not l and not u and low.call(Vector2i(x - 1, y - 1)):
				img.blend_rect(_rim_pieces[4], full, at)
			if not r and not u and low.call(Vector2i(x + 1, y - 1)):
				img.blend_rect(_rim_pieces[5], full, at)
			if not l and not dn and low.call(Vector2i(x - 1, y + 1)):
				img.blend_rect(_rim_pieces[6], full, at)
			if not r and not dn and low.call(Vector2i(x + 1, y + 1)):
				img.blend_rect(_rim_pieces[7], full, at)


func _render_ground() -> void:
	minimap_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	for old in ground.get_children():
		ground.remove_child(old)
		old.queue_free()
	var near_base := func(c: Vector2i) -> bool:
		for st in starts:
			if (Vector2(c) - (Vector2(st) + Vector2(2.5, 2))).length() < 6.5:
				return true
		return false
	# every cell's ground set and shade, decided once; `layer` ranks the plain grounds that
	# blend into each other at their borders (water < ford < bare ground < the low sets;
	# 0 = a cell that keeps clean edges: cliffs, high ground, ramps)
	var sets := PackedStringArray()
	sets.resize(W * H)
	var shades := PackedFloat32Array()
	shades.resize(W * H)
	var layer := PackedInt32Array()
	layer.resize(W * H)
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var i := idx(c)
			var bn := mapgen.biome_at(x, y)
			var b: Dictionary = MapGen.BIOMES[bn]
			var rnd := int(abs(sin(x * 12.9898 + y * 78.233) * 43758.5453))
			var set_name: String
			var shade := 1.0
			var lay := 0
			if water[i] == 1:
				set_name = mapgen.water_set if mapgen.water_set != "" else b["water"]
				lay = 1
			elif mapgen.ford.size() > i and mapgen.ford[i] == 1:
				set_name = mapgen.ford_set if mapgen.ford_set != "" else b["ford"]
				lay = 2
			elif ramp[i] == 1:
				set_name = b["high"]       # painted over as a slope below (_paint_ramps)
			elif cliff[i] == 1:
				var below := Vector2i(x, y + 1)
				set_name = b["face"] if in_map(below) and height[idx(below)] == 0 else b["high"]
				shade = 1.0 if set_name == b["face"] else 0.72
				if set_name == b["high"]:
					# the rim of a plateau in a biome whose high-ground patches are bold
					# (boulders, strata...): its own ground, darker, not blocks of them
					var rim: Array = b["low"]
					set_name = rim[int(_value_noise(x + 500, y, 4.0) * rim.size() * 0.999)] if b.get("patches", false) else rim[rnd % rim.size()]
					# lit like the plateau; its outer edge is darkened smoothly (_shade_rims; a
					# darker picture per cell drew a staircase of dark squares)
					shade = 1.07
			elif height[i] == 1:
				# high ground: mostly the calm low-ground tiles, a touch brighter, with
				# patches of the strong high-ground tile here and there (smooth noise, so
				# they come in soft clumps, not a checkerboard)
				# (no blocks of the strong high-ground tile inside plateaus any more: its
				# tiles have a dark edge stripe that showed as hard seams between them)
				if false:
					set_name = b["high"]
					shade = 1.0
					lay = 40
				else:
					var low_h: Array = b["low"]
					var hi := rnd % low_h.size()
					if b.get("patches", false):
						hi = int(_value_noise(x + 500, y, 4.0) * low_h.size() * 0.999)
					set_name = low_h[hi]
					shade = 1.07
					lay = 10 + hi + (0 if bn == mapgen.biome_a else 5)
			elif near_base.call(c):
				set_name = b["base"]
				lay = 3
			else:
				var low: Array = b["low"]
				# a biome with several low sets lays them in soft patches
				var li := rnd % low.size()
				if b.get("patches", false):
					li = int(_value_noise(x + 500, y, 4.0) * low.size() * 0.999)
				set_name = low[li]
				lay = 10 + li + (0 if bn == mapgen.biome_a else 5)
			sets[i] = set_name
			shades[i] = shade
			layer[i] = lay
			var key := _tile_key(set_name, rnd / 7)
			_tile(set_name, rnd / 7)
			var mc: Color = _tile_avg.get(key, Color(0.3, 0.5, 0.2)) * shade
			if cliff[i] == 1 and set_name != b["face"]:
				mc *= 0.73                # the minimap keeps the rim dark (0.78 overall)
			if _terrain_kind.get(i, "") == "tree":
				mc = mc.darkened(0.45)
			elif _terrain_kind.get(i, "") in ["rock", "prop"]:
				mc = Color(0.45, 0.45, 0.45)
			minimap_img.set_pixel(x, y, Color(mc.r, mc.g, mc.b, 1.0))
	var masks := _edge_masks()
	var pmasks := _patch_masks()
	var nb8: Array = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	# which cells' pictures are blended into each other at their shared edge (_blend_seams):
	# the same level of plain ground (0 low, 1 high and its rim), cliff faces only side by side
	# (2), ramps never (-1)
	var zone := PackedInt32Array()
	zone.resize(W * H)
	for i in W * H:
		if ramp[i] == 1:
			zone[i] = -1
		elif cliff[i] == 1:
			var b: Dictionary = MapGen.BIOMES[mapgen.biome_at(i % W, i / W)]
			zone[i] = 2 if sets[i] == b["face"] else 1
		else:
			zone[i] = 1 if height[i] == 1 else 0
	# each cell's (or 2 x 2 block's) picture, unlike its neighbours' (_pick_variant)
	var pick := PackedInt32Array()
	pick.resize(W * H)
	var sid := PackedInt32Array()          # each cell's ground set as a number
	sid.resize(W * H)
	var blocks := {}                       # Vector3i(block x, block y, set) -> pick
	var set_ids := {}
	var set_names: Array = []
	var macro := PackedByteArray()         # per set number: laid in 2 x 2 blocks
	var few := PackedByteArray()           # under 3 variants: a plain hashed pick
	var no_seam := PackedByteArray()
	for y in H:
		for x in W:
			var i := y * W + x
			var s := sets[i]
			if not set_ids.has(s):
				set_ids[s] = set_names.size()
				set_names.append(s)
				macro.append(int(_is_macro(s)))
				few.append(int(_good(s).size() < 3))
				no_seam.append(int(NO_SEAM.has(s)))
			var si: int = set_ids[s]
			sid[i] = si
			if macro[si] == 1:
				var bk := Vector3i(x >> 1, y >> 1, si)
				if not blocks.has(bk):
					var near: Array = []
					for d in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]:
						near.append(blocks.get(Vector3i(bk.x + d.x, bk.y + d.y, si), -1))
					blocks[bk] = _pick_variant(s, _hash2(bk.x, bk.y, 7), near)
				pick[i] = blocks[bk]
			elif few[si] == 1:
				pick[i] = _pick_variant(s, _hash2(x, y, 3), [])
			else:
				var near: Array = []
				for d in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]:
					var n := Vector2i(x + d.x, y + d.y)
					near.append(pick[idx(n)] if in_map(n) and sid[idx(n)] == si else -1)
				pick[i] = _pick_variant(s, _hash2(x, y, 3), near)
	# the pictures, shaded, by set, pick, quarter of the block and shade (one lookup a cell)
	var pics := {}
	var pic := func(si: int, x: int, y: int, p: int, shade: float) -> Image:
		var q := ((x & 1) + 2 * (y & 1)) if macro[si] == 1 else 0
		var key := Vector4i(si, p, q, int(shade * 1000.0))
		if not pics.has(key):
			pics[key] = _shaded(_cell_tile(set_names[si], x, y, p), shade)
		return pics[key]
	# a neighbour's ground spilling over a cell's edge: its picture at this cell's place
	var spill_pick := func(si: int, x: int, y: int) -> int:
		if macro[si] == 1:
			var bk := Vector3i(x >> 1, y >> 1, si)
			if blocks.has(bk):
				return blocks[bk]
			return _pick_variant(set_names[si], _hash2(x >> 1, y >> 1, 7), [])
		return _pick_variant(set_names[si], _hash2(x, y, 5), [])
	for cy in range(0, H, CHUNK):
		for cx in range(0, W, CHUNK):
			var cr := Rect2i(cx, cy, mini(CHUNK, W - cx), mini(CHUNK, H - cy))
			# drawn with a margin of one cell all round (where the map goes on), so the seams on
			# the chunk's own edges blend exactly as they do in the chunk next door
			var er := cr.grow(1).intersection(Rect2i(0, 0, W, H))
			var img := Image.create(er.size.x * T, er.size.y * T, false, Image.FORMAT_RGBA8)
			for y in range(er.position.y, er.end.y):
				for x in range(er.position.x, er.end.x):
					var i := y * W + x
					var at := Vector2i(x - er.position.x, y - er.position.y) * T
					img.blit_rect(pic.call(sid[i], x, y, pick[i], shades[i]), Rect2i(0, 0, T, T), at)
					var lay := layer[i]
					if lay == 0:
						continue
					# a ground ranked higher next door spills over this cell's edge
					for k in 8:
						var n: Vector2i = Vector2i(x, y) + nb8[k]
						if not in_map(n):
							continue
						var j := idx(n)
						var nl := layer[j]
						if nl <= lay or sid[j] == sid[i]:
							continue
						if k >= 4:
							# a corner only where neither side next to it is the same ground
							if sid[idx(Vector2i(n.x, y))] == sid[j] or sid[idx(Vector2i(x, n.y))] == sid[j]:
								continue
						if (height[i] == 1) != (height[j] == 1):
							continue      # (high and low ground meet only at cliffs and ramps)
						var over: Image = pic.call(sid[j], x, y, spill_pick.call(sid[j], x, y), shades[i])
						var mk: Image = masks[(x * 7 + y * 3 + k) % 2][k] if lay < 10 else _patch_mask(pmasks, k, x, y)
						img.blend_rect_mask(over, mk, Rect2i(0, 0, T, T), at)
			_blend_seams(img, er, sid, zone, macro, no_seam)
			if er != cr:
				img = img.get_region(Rect2i((cr.position - er.position) * T, cr.size * T))
			_shade_rims(img, cr, zone)
			_paint_ramps(img, cr)
			# a soft shadow under each cliff face
			for y in range(maxi(cr.position.y - 1, 0), mini(cr.end.y, H - 1)):
				for x in range(cr.position.x, cr.end.x):
					if y + 1 < cr.position.y or y + 1 >= cr.end.y:
						continue
					if cliff[y * W + x] == 1 and height[(y + 1) * W + x] == 0 and cliff[(y + 1) * W + x] == 0:
						for py in 6:
							for px in T:
								var p := Vector2i((x - cx) * T + px, (y + 1 - cy) * T + py)
								var col := img.get_pixelv(p)
								img.set_pixelv(p, col.darkened(0.35 * (1.0 - py / 6.0)))
			var spr := Sprite2D.new()
			spr.centered = false
			spr.position = Vector2(cx, cy) * T
			spr.texture = ImageTexture.create_from_image(img)
			ground.add_child(spr)


## A tile darkened or brightened (cliff tops, high ground), made once.
var _shade_cache := {}


func _shaded(t: Image, shade: float) -> Image:
	if shade == 1.0:
		return t
	var key := [t.get_instance_id(), shade]
	if not _shade_cache.has(key):
		var d: Image = t.duplicate()
		for py in d.get_height():
			for px in d.get_width():
				var col := d.get_pixel(px, py)
				d.set_pixel(px, py, Color(col.r * shade, col.g * shade, col.b * shade, col.a))
		_shade_cache[key] = d
	return _shade_cache[key]


## Smooth value noise in 0..1 (a random value every `cell` tiles, blended between them).
func _value_noise(x: int, y: int, cell: float) -> float:
	var fx := x / cell
	var fy := y / cell
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := smoothstep(0.0, 1.0, fx - ix)
	var ty := smoothstep(0.0, 1.0, fy - iy)
	var h := func(a: int, b: int) -> float:
		return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)
	var top: float = lerpf(h.call(ix, iy), h.call(ix + 1, iy), tx)
	var bot: float = lerpf(h.call(ix, iy + 1), h.call(ix + 1, iy + 1), tx)
	return lerpf(top, bot, ty)


## Ramps: each ramp is painted as one smooth slope, from the high ground's grass at the
## top to the low ground at the bottom, with faint contour steps across it and darker
## edges along its sides (one tile per cell made a saw-toothed staircase).
func _paint_ramps(img: Image, area := Rect2i(0, 0, W, H)) -> void:
	var seen := {}
	for y in H:
		for x in W:
			var c0 := Vector2i(x, y)
			if ramp[idx(c0)] != 1 or seen.has(c0):
				continue
			# the whole ramp: cells joined to this one
			var cells: Array = []
			var todo: Array = [c0]
			seen[c0] = true
			while not todo.is_empty():
				var c: Vector2i = todo.pop_back()
				cells.append(c)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if in_map(n) and ramp[idx(n)] == 1 and not seen.has(n):
						seen[n] = true
						todo.append(n)
			# downhill: from the high ground next to it toward the low ground next to it
			var hi_sum := Vector2.ZERO
			var lo_sum := Vector2.ZERO
			var hi_n := 0
			var lo_n := 0
			for c in cells:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if not in_map(n) or ramp[idx(n)] == 1:
						continue
					if height[idx(n)] == 1 and cliff[idx(n)] == 0:
						hi_sum += Vector2(n)
						hi_n += 1
					elif height[idx(n)] == 0:
						lo_sum += Vector2(n)
						lo_n += 1
			if hi_n == 0 or lo_n == 0:
				continue
			var dir := (lo_sum / lo_n - hi_sum / hi_n).normalized()
			var side := Vector2(-dir.y, dir.x)
			var lo_p := INF
			var hi_p := -INF
			var s_lo := INF
			var s_hi := -INF
			for c in cells:
				var m := (Vector2(c) + Vector2(0.5, 0.5)) * T
				lo_p = minf(lo_p, m.dot(dir) - T * 0.5)
				hi_p = maxf(hi_p, m.dot(dir) + T * 0.5)
				s_lo = minf(s_lo, m.dot(side) - T * 0.5)
				s_hi = maxf(s_hi, m.dot(side) + T * 0.5)
			var b: Dictionary = MapGen.BIOMES[mapgen.biome_at(c0.x, c0.y)]
			var top_t := _tile(String((b["low"] as Array)[0]), 1)
			var low: Array = b["low"]
			var bot_t := _tile(low[0], 2)
			var face_t := _tile(b["face"], 0)
			var path_t := _tile(b["base"], 3)
			# the side axis on the grid, and which cells continue the ramp on each side
			var sa := Vector2i(1, 0) if absf(side.x) >= absf(side.y) else Vector2i(0, 1)
			var neg_open := {}
			var pos_open := {}
			for c in cells:
				var nn: Vector2i = c - sa
				var pp: Vector2i = c + sa
				neg_open[c] = in_map(nn) and ramp[idx(nn)] == 1
				pos_open[c] = in_map(pp) and ramp[idx(pp)] == 1
			for c in cells:
				if not area.has_point(c):
					continue
				for py in T:
					for px in T:
						var p := Vector2(c.x * T + px, c.y * T + py) + Vector2(0.5, 0.5)
						var f := clampf((p.dot(dir) - lo_p) / maxf(hi_p - lo_p, 1.0), 0.0, 1.0)
						# the ramp's own surface: a worn track of the biome's bare ground (dirt,
						# gravel, mud...) cut into steps, fading into the grass at both ends
						var a: Color = top_t.get_pixel(px, py) * 1.07
						var z: Color = bot_t.get_pixel(px, py)
						var ends := a.lerp(z, f)
						var track: Color = path_t.get_pixel(px, py)
						var col := ends.lerp(track, smoothstep(0.0, 0.18, f) * (1.0 - smoothstep(0.82, 1.0, f)))
						col = col.darkened(0.04 + 0.12 * f)
						var step_d := fmod(p.dot(dir) - lo_p, 8.0)
						if step_d < 1.0:
							col = col.darkened(0.3)
						elif step_d < 2.0:
							col = col.lightened(0.15)
						# clear edges down both sides: a dark line with a lit rim inside it,
						# and a wedge of cliff rock at the top that narrows down the slope
						# how far this pixel is from the ramp's side edge (the side of its cell
						# that faces a cell which isn't ramp)
						var sd := 99.0
						var along: float = float(px) if sa.x != 0 else float(py)
						if not neg_open.get(c, false):
							sd = minf(sd, along)
						if not pos_open.get(c, false):
							sd = minf(sd, float(T) - 1.0 - along)
						var wedge := 8.0 * (1.0 - f)
						if sd < wedge:
							col = face_t.get_pixel(px, py).darkened(0.1 + 0.25 * (1.0 - sd / maxf(wedge, 0.01)))
						elif sd < wedge + 2.0 and f < 0.92:
							col = col.darkened(0.6)
						elif sd < wedge + 4.0 and f < 0.92:
							col = col.lightened(0.3)
						col.a = 1.0
						img.set_pixel((c.x - area.position.x) * T + px, (c.y - area.position.y) * T + py, col)


func _start_positions() -> void:
	for t in n_players():
		var f: Dictionary = Defs.FACTIONS[factions[t]]
		var b := _add_building(f["hall"], t, starts[t], true)
		players[t]["res2"] = float(Defs.START_POWDER) if factions[t] == "crown" else 0.0
		_update_swamp()
		# Starting economy structures, already standing.
		var sites: Array = []
		for k in f["start"]:
			var spot := find_spot(t, k, b, 4, 11, "behind")
			if spot.x >= 0:
				var eb := _add_building(k, t, spot, true)
				if k == "farm":
					eb.growth = 0.6     # the starting farm is already well grown: first harvest in seconds
				sites.append(eb)
				_update_swamp()
		var hall_center := b.rect().get_center()
		for i in int(f["start_workers"]):
			var u := _add_unit(f["worker"], t, hall_center + Vector2(-60 + i * 30, 80 if starts[t].y < H / 2 else -80))
			var site := free_site(t, u.position)
			if site:
				u.cmd_gather(site)
		players[t]["gold"] = int(f.get("start_gold", Defs.START_GOLD))
	_update_swamp()


## A free cell for a building of this kind around a building: distance in tiles from
## its middle; "near" picks the closest, "far" the farthest, "toward_middle" the one
## nearest the middle of the map.
func find_spot(t: int, kind: String, around: Building, min_d: int, max_d: int, prefer := "near") -> Vector2i:
	if Defs.is_econ(kind) and econ_count(t, kind) >= econ_limit(t, kind):
		return Vector2i(-1, -1)
	_spot_halls = halls_of(t)
	_spot_all_halls = halls_of(t, false)
	_in_spot = true
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var c0: Vector2 = around.rect().get_center() / T
	var mid := Vector2(W, H) * 0.5
	var best := Vector2i(-1, -1)
	var bs := INF
	for y in range(int(c0.y) - max_d - 2, int(c0.y) + max_d + 2):
		for x in range(int(c0.x) - max_d - 2, int(c0.x) + max_d + 2):
			var cell := Vector2i(x, y)
			var cc := Vector2(cell) + Vector2(size) * 0.5
			var dd := cc.distance_to(c0)
			if dd < min_d or dd > max_d:
				continue
			if not _footprint_open(cell, size) or placement_problem(t, kind, cell, true, true) != "" or not margin_free(cell, size):
				continue
			var score := dd
			if prefer == "far":
				score = -dd
			elif prefer == "far_safe":
				# far from the building, but not toward the enemy's side
				var own := cc.distance_to(Vector2(starts[t]) + Vector2(2.5, 2))
				var foe := INF
				for o in n_players():
					if hostile(t, o):
						foe = minf(foe, cc.distance_to(Vector2(starts[o]) + Vector2(2.5, 2)))
				score = -dd + maxf(0.0, own - foe * 0.8) * 3.0
			elif prefer == "toward_middle":
				score = cc.distance_to(mid) + dd * 0.5
			elif prefer == "behind":
				# tucked behind the hall, away from the middle of the map (like minerals
				# behind a command centre), and close to it
				score = dd - (cc.distance_to(mid) - c0.distance_to(mid)) * 1.5
			if kind == "boiler" or (kind == "ore_crusher" and econ_count(t, "boiler") > 0):
				# Boilers and crushers close together (once there's a Boiler; the starting crusher
				# goes behind the hall): a battery fades on a long road, and a Boiler's Winders
				# must be back for the next one within a few seconds
				var near := INF
				for b in buildings:
					if b.team == t and not b.dead and (b.d.has("battery") if kind == "ore_crusher" else b.kind == "ore_crusher"):
						near = minf(near, b.center().distance_to(cc * T) / T)
				if near < INF:
					score += maxf(0.0, near - SOURCE_NEAR) * 3.0
			if score < bs:
				bs = score
				best = cell
	_spot_halls = []
	_spot_all_halls = []
	_in_spot = false
	return best


var _spot_halls: Array = []
var _spot_all_halls: Array = []      # (find_spot: the halls, unfinished ones too, looked up once)
var _in_spot := false


## find_spot's quick test before the full placement_problem: every cell of the footprint
## and the ring round it on the map and free (placement_problem and margin_free would
## turn the spot down anyway; this is only cheaper).
func _footprint_open(cell: Vector2i, size: Vector2i) -> bool:
	if cell.x < 1 or cell.y < 1 or cell.x + size.x >= W or cell.y + size.y >= H:
		return in_map(cell)       # (at the map's edge: leave it to the full test)
	for y in range(cell.y - 1, cell.y + size.y + 1):
		var row := y * W
		for x in range(cell.x - 1, cell.x + size.x + 1):
			if solid[row + x] != 0:
				return false
	return true
const SOURCE_NEAR := 6.0               # tiles: a crusher further than this from a Boiler (or the reverse) scores worse in find_spot


## A free ring around a footprint (room to walk round it).
func margin_free(cell: Vector2i, size: Vector2i) -> bool:
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			if x >= 0 and y >= 0 and x < size.x and y < size.y:
				continue
			if not is_free(cell + Vector2i(x, y)):
				return false
	return true


# ------------------------------------------------------------------ lodes (saltpetre, ore)

## The hall whose lode a Powder Mill (Town Hall: saltpetre) or an Ore Crusher / Boiler
## (Clocktower: ore) draws on: the nearest built one of its team.
func lode_hall(b: Building) -> Building:
	var hk: String = Defs.LODE_FOR.get(b.kind, "")
	if hk == "" or faction_hall(b.team) != hk:
		return null
	return nearest_hall(b.center(), b.team)


## Clockwork: the battery sources that belong to a Clocktower: itself and the Boilers whose
## nearest Clocktower it is.
func battery_sources(h: Building) -> Array:
	var out: Array = [h]
	for b in buildings:
		if b.team == h.team and b.kind == "boiler" and b.built and not b.dead and lode_hall(b) == h:
			out.append(b)
	return out


## Draw `v` worth from the lode of a Mill's (Crusher's) hall: what it still holds pays in
## full, the rest only LODE_SPENT. Returns what it pays.
func draw_lode(b: Building, v: float) -> float:
	if v <= 0.0:
		return 0.0
	var h := lode_hall(b)
	var fresh := 0.0
	if h:
		fresh = minf(h.lode, v)
		h.lode -= fresh
		_lode_check(h)
	return fresh + (v - fresh) * Defs.LODE_SPENT


## What `v` worth would pay right now (no side effects).
func lode_pay(b: Building, v: float) -> float:
	var h := lode_hall(b)
	var fresh := minf(h.lode, v) if h else 0.0
	return fresh + (v - fresh) * Defs.LODE_SPENT


## Running low / spent: once per hall, a match-log line and (for you) a toast.
func _lode_check(h: Building) -> void:
	var left := h.lode / h.lode_full()
	var level := 2 if h.lode <= 0.0 else (1 if left < Defs.SOIL_LOW else 0)
	if level <= h.lode_warned:
		return
	h.lode_warned = level
	var what: String = Defs.LODE_NAME[h.kind]
	var user := "its Mill grinds" if h.kind == "town_hall" else "its crushers pay"
	if mlog:
		mlog.add("%s: the %s at a %s %s" % [mlog.who(h.team), what, h.d["name"], ("is spent (%s at a quarter)" % user) if level == 2 else "is running low (under %d%%)" % int(Defs.SOIL_LOW * 100)])
	if h.team == human and not demo and hud:
		if level == 2:
			hud.toast("The %s at your %s is spent: %s at a quarter. Expand to fresh %s." % [what, h.d["name"], user, what], false)
			Sfx.announce(faction_of(h.team), "depleted", 10.0)
		else:
			hud.toast("The %s at your %s is running low (%d%% left): expand to fresh %s soon." % [what, h.d["name"], int(round(left * 100)), what], false)
		Sfx.play("done", h.center())


## Share (0..1) of the lode a new hall of this kind would find at a spot (cell): fresh, unless
## a hall fell there and left some of it drawn out (see soil_scars).
func lode_at_spot(c: Vector2i, hall_kind: String) -> float:
	var full := float(Defs.LODE.get(hall_kind, 0.0))
	if full <= 0.0:
		return 0.0
	var mid := (Vector2(c) + Vector2(Defs.BUILDINGS[hall_kind]["size"]) * 0.5) * T
	for sc in soil_scars:
		if String(sc[2]) == hall_kind and (sc[0] as Vector2).distance_to(mid) <= Defs.HALL_SPACING * T:
			return clampf(float(sc[3]) / full, 0.0, 1.0) if sc.size() > 3 else 1.0
	return 1.0


## Clockwork: the Ore Crusher a Winder takes a battery to: the nearest, but one whose ore is
## spent (it pays a quarter), or one farther than `reach` px (the battery would burst on the
## way), counts as 40 tiles farther.
func best_crusher(p: Vector2, t: int, reach := INF) -> Building:
	var best: Building = null
	var bs := INF
	for b in buildings:
		if b.team == t and b.kind == "ore_crusher" and b.built and not b.dead:
			var dd: float = b.edge_distance(p)
			var sc: float = dd + (0.0 if b.lode_left() > 0.0 and dd <= reach else 40.0 * T)
			if sc < bs:
				bs = sc
				best = b
	return best


# ------------------------------------------------------------------ economy

## An economy structure with room in its crew for this team's workers, nearest first.
func free_site(t: int, p: Vector2) -> Building:
	var best: Building = null
	var bd := INF
	for b in buildings:
		if b.team != t or b.dead or not b.built or int(b.d.get("crew", 0)) == 0:
			continue
		if b.crew.size() >= int(b.d["crew"]):
			continue
		var dd: float = b.center().distance_to(p) + b.crew.size() * 40.0
		if (b.kind == "farm" or b.kind == "feeding_pit") and b.soil_left() <= 0.0:
			dd += 1500.0        # tired soil (spent ground): new hands go to fresh fields (pits) first
		if dd < bd:
			bd = dd
			best = b
	return best


## Soil fatigue: the Town Hall whose farmland a Farm draws on (the nearest built one);
## for a Feeding Pit, the Hive whose ground it draws on.
func soil_hall(farm: Building) -> Building:
	return nearest_hall(farm.center(), farm.team)


## A Farm's harvest: draws its yield from its hall's soil; tired soil pays a third.
## Adds the gold and returns what it paid.
func harvest(farm: Building) -> int:
	var h := soil_hall(farm)
	var fresh := 0.0
	if h:
		fresh = minf(h.soil, float(Defs.FARM_YIELD))
		h.soil -= fresh
	var pay := int(round(fresh + (Defs.FARM_YIELD - fresh) * Defs.SOIL_TIRED))
	add_gold(farm.team, pay)
	if h:
		_soil_check(h)
	return pay


## What a Farm's next harvest would pay (no side effects).
func harvest_value(farm: Building) -> int:
	var h := soil_hall(farm)
	var fresh := minf(h.soil, float(Defs.FARM_YIELD)) if h else 0.0
	return int(round(fresh + (Defs.FARM_YIELD - fresh) * Defs.SOIL_TIRED))


func _soil_check(h: Building) -> void:
	var left := h.soil / h.reserve()
	var level := 2 if h.soil <= 0.0 else (1 if left < Defs.SOIL_LOW else 0)
	if level <= h.soil_warned:
		return
	h.soil_warned = level
	var hive := h.kind == "hive"
	if h.kind == "clocktower":
		# Clockwork coal: the Boilers around this Clocktower
		if mlog:
			mlog.add("%s: the coal of a Clocktower's Boilers %s" % [mlog.who(h.team), "is spent (they fill batteries at a third)" if level == 2 else "is running low (under %d%%)" % int(Defs.SOIL_LOW * 100)])
		if h.team == human and not demo and hud:
			hud.toast("Your Boilers' coal is spent: they fill batteries at a third. Build a Clocktower on fresh ground." if level == 2
				else "Your Boilers' coal is running low (%d%% left): expand to fresh ground soon." % int(round(left * 100)), false)
			Sfx.play("done", h.center())
		return
	if mlog:
		if hive:
			mlog.add("%s: the ground around a Hive %s" % [mlog.who(h.team), "is spent (its pits yield a third)" if level == 2 else "is running low (under %d%%)" % int(Defs.SOIL_LOW * 100)])
		else:
			mlog.add("%s: the soil around a Town Hall %s" % [mlog.who(h.team), "is spent (its farms pay a third)" if level == 2 else "is running low (under %d%%)" % int(Defs.SOIL_LOW * 100)])
	if h.team == human and not demo and hud:
		if hive:
			hud.toast("The ground around your Hive is spent: its pits yield a third. Grow a Hive on fresh ground." if level == 2
				else "The ground around your Hive is running low (%d%% left): grow a Hive on fresh ground soon." % int(round(left * 100)), false)
		else:
			hud.toast("The soil around your Town Hall is tired: expand to fresh land." if level == 2
				else "The soil around your Town Hall is running low (%d%% left): expand to fresh land soon." % int(round(left * 100)), false)
		Sfx.play("done", h.center())
	var site := "feeding_pit" if hive else "farm"
	for b in buildings:
		if b.kind == site and b.team == h.team and not b.dead and b.built:
			b._update_sprite()


## A Town Hall raised (a Hive grown) where one fell takes over that tired land.
func _take_scar(h: Building) -> void:
	for i in soil_scars.size():
		var sc: Array = soil_scars[i]
		if String(sc[2]) == h.kind and (sc[0] as Vector2).distance_to(h.center()) <= Defs.HALL_SPACING * T:
			h.soil = float(sc[1])
			h.soil_warned = 2 if h.soil <= 0.0 else (1 if h.soil / h.reserve() < Defs.SOIL_LOW else 0)
			if h.lode_full() > 0.0 and sc.size() > 3:
				h.lode = float(sc[3])
				h.lode_warned = 2 if h.lode <= 0.0 else (1 if h.lode / h.lode_full() < Defs.SOIL_LOW else 0)
			soil_scars.remove_at(i)
			return


func halls_of(t: int, built_only := true) -> Array:
	var k := faction_hall(t)
	return buildings.filter(func(b: Building) -> bool: return b.team == t and b.kind == k and not b.dead and (b.built or not built_only))


func econ_count(t: int, kind: String) -> int:
	return buildings.filter(func(b: Building) -> bool: return b.team == t and b.kind == kind and not b.dead).size()


func econ_limit(t: int, kind: String) -> int:
	return int(Defs.FACTIONS[faction_of(t)]["econ"].get(kind, 0)) * maxi(1, halls_of(t).size())


func add_res2(t: int, v: float) -> void:
	if v > 0.0:
		v *= float(income_mult[t])
		stats[t]["res2_in"] += v       # (a statistic only: secondary resource earned)
	players[t]["res2"] = float(players[t]["res2"]) + v


func add_gold_f(t: int, v: float) -> void:
	var acc: float = float(players[t]["gold_f"]) + v
	var n := int(acc)
	players[t]["gold_f"] = acc - n
	if n > 0:
		add_gold(t, n)


## Spend powder for a shot. False when there isn't enough.
func use_powder(t: int, n: int) -> bool:
	if faction_of(t) != "crown":
		return true
	if float(players[t]["res2"]) < n:
		if t == human:
			notify("Powder bank empty: man your Powder Mills.")
		return false
	players[t]["res2"] = float(players[t]["res2"]) - n
	return true


var _short_ms := -99999


## A refill is waiting on an empty powder bank (told now and then, not every tick).
func powder_short() -> void:
	if Time.get_ticks_msec() - _short_ms < 20000:
		return
	_short_ms = Time.get_ticks_msec()
	notify("Powder bank empty: refills wait. Man your Powder Mills.")


## A Musketeer, Cannon or Mortar has used up the powder it carries. Over it: "Out of powder!"
## (once for a whole line running dry: not again within 150 px for 4 s); and now and then a
## word to the player on where they refill.
var _dry_floats: Array = []       # [where, when (ms)]
var _dry_ms := -99999


func out_of_powder(u: Unit) -> void:
	if u.team != human or demo:
		return
	var now := Time.get_ticks_msec()
	_dry_floats = _dry_floats.filter(func(f: Array) -> bool: return now - int(f[1]) < 4000)
	if not _dry_floats.any(func(f: Array) -> bool: return (f[0] as Vector2).distance_to(u.position) < 150.0):
		_dry_floats.append([u.position, now])
		float_text(u.position + Vector2(0, -40), "Out of powder!", Color(1, 0.75, 0.4))
	if now - _dry_ms > 25000 and now - _notify_t > 3000:
		_dry_ms = now
		var who: String = {"musketeer": "Musketeers", "cannon": "Cannons", "mortar": "Mortars"}.get(u.kind, "Men")
		notify("%s out of powder: bring them to a Mill, Barracks, Hall or Powder Wagon." % who)


var energy: Array = []            # Clockwork energy per second
var ore_rate: Array = []
var asm_mult: Array = []          # production speed of Clockwork buildings
var wind_e: Array = []            # energy on wind
var _econ_t := 0.0


func set_split(t: int, name: String) -> void:
	players[t]["split"] = Defs.SPLITS[name].duplicate()
	players[t]["split_name"] = name


func _economy(delta: float) -> void:
	for t in n_players():
		if faction_of(t) != "clockwork":
			continue
		# ore now only comes from batteries Winders deliver; assembly and wind are fixed,
		# a bit better with blue energy
		var blue := blue_energy(t)
		asm_mult[t] = 1.25 if blue else 1.0
		wind_e[t] = 5.0 if blue else 3.0
		var waiting := 0
		for b in buildings:
			if b.team == t and not b.dead and b.built:
				waiting += b.batteries
		energy[t] = waiting
		players[t]["res2"] = waiting
	_econ_t -= delta
	if _econ_t <= 0.0:
		_econ_t = 0.5
		# Charging Pylons slowly mend constructs around them.
		for b in buildings:
			if b.dead or not b.built or not b.d.has("mends") or not b.field_on():
				continue
			var fr := float(b.d["field"]) * T * field_mult(b.team)
			for u in units_near(b.center(), fr):
				if u.team == b.team and not u.dead and u.hp < u.max_hp and in_ellipse(b.center(), u.position, fr):
					u.hp = minf(u.max_hp, u.hp + float(b.d["mends"]) * 0.5)


## Clockwork fields grow with the energy put on wind.
func field_mult(t: int) -> float:
	if faction_of(t) != "clockwork":
		return 1.0
	return 0.8 + minf(wind_e[t] / 12.0, 0.8)


func wind_decay_mult(t: int) -> float:
	return maxf(0.25, 1.0 - wind_e[t] / 10.0)


## Value of one load of food hauled from this pit to the nearest Hive, on fresh ground: it
## pays for the round trip's time at a rate that rises with the pit's distance from the Hive
## (see Defs.FOOD_RATE).
func food_value(pit: Building) -> float:
	var hive := nearest_hall(pit.center(), pit.team)
	if hive == null:
		return 0.0
	var a := hive.rect()
	var b := pit.rect()
	var gx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var gy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return food_at(hive.center().distance_to(pit.center()) / T, Vector2(gx, gy).length() / T)


## The fresh-ground value of a load from a pit `d` tiles (centre to centre) from its Hive,
## with `gap` tiles of open ground between the two buildings: the rate (biomass per
## grub-second) times the round trip's estimated seconds.
static func food_at(d: float, gap: float) -> float:
	d = minf(d, Defs.FOOD_MAX_D)
	gap = minf(gap, Defs.FOOD_MAX_D)
	var rate := Defs.FOOD_RATE * (1.0 + Defs.FOOD_BONUS * clampf((d - Defs.FOOD_NEAR) / (Defs.FOOD_FAR - Defs.FOOD_NEAR), 0.0, 1.0))
	if d > Defs.FOOD_PEAK:
		rate *= 1.0 - Defs.FOOD_FADE * (d - Defs.FOOD_PEAK)
	return rate * (Defs.PIT_TIME + Defs.FOOD_TRIP * maxf(0.0, gap - Defs.FOOD_REACH))


## A grub takes a load at a pit: it draws its value from the Hive's ground; spent ground
## yields a third. Returns the load's value.
func pit_load(pit: Building) -> float:
	var v := food_value(pit)
	var h := soil_hall(pit)
	var fresh := 0.0
	if h:
		fresh = minf(h.soil, v)
		h.soil -= fresh
		_soil_check(h)
	return fresh + (v - fresh) * Defs.SOIL_TIRED


## What the next load from this pit is worth (no side effects).
func load_value(pit: Building) -> float:
	var v := food_value(pit)
	var h := soil_hall(pit)
	var fresh := minf(h.soil, v) if h else 0.0
	return fresh + (v - fresh) * Defs.SOIL_TIRED


## The most wounded soldier nearby that a Missionary may bandage.
## Missionary priorities (Defs.CARE): bodies to raise come first, the wounded second.
## A unit's worth to him: its price, and more for every kill it made (veterancy).
static func care_value(u: Unit) -> float:
	return float(u.d.get("cost", 50)) / maxf(1.0, float(u.d.get("spawn", 1))) + float(Defs.CARE["per_kill"]) * u.kills


## How much a wounded unit is worth bandaging: its worth x the share of its health it lacks,
## a little less the farther it is.
func patient_score(m: Unit, o: Unit) -> float:
	var missing := 1.0 - o.hp / maxf(o.max_hp, 1.0)
	return care_value(o) * missing / (1.0 + o.position.distance_to(m.position) / float(Defs.CARE["near_patient"]))


## The wounded soldier this Missionary should bandage: the best patient_score among ours
## missing at least CARE.hurt of their health, not one another Missionary is going to.
func find_patient(m: Unit, r: float) -> Unit:
	var best: Unit = null
	var bs := 0.0
	for o in units_near(m.position, r):
		if o.team != m.team or o.dead or o.off_field or o.is_worker() or o.is_air() or o.d.get("medic", false) or o.kind == "horse":
			continue
		if o.cross_t > 0.0 or o.d["faction"] == "clockwork" or Defs.CROWN_MACHINES.has(o.kind):
			continue      # guns and wagons are mended by Labourers, not bandaged
		if 1.0 - o.hp / o.max_hp < float(Defs.CARE["hurt"]):
			continue
		var taken := false
		for x in units:
			if x != m and x.order == "heal" and x.order_target == o:
				taken = true
				break
		if taken:
			continue
		var s := patient_score(m, o)
		if s > bs:
			bs = s
			best = o
	return best


func near_enemy_building(t: int, p: Vector2, tiles: float) -> bool:
	for b in buildings:
		if hostile(t, b.team) and not b.dead and not b.ghost and b.edge_distance(p) < tiles * T:
			return true
	return false


var _floats: Array = []           # [position, text, colour, time left]


func float_text(p: Vector2, txt: String, col: Color) -> void:
	_floats.append([p, txt, col, 1.4])


func faction_of(t: int) -> String:
	return factions[t]


func max_supply(t: int) -> int:
	return int(Defs.FACTIONS[factions[t]]["max_supply"])


func _own_hall(t: int) -> Building:
	var hall: String = Defs.FACTIONS[factions[t]]["hall"]
	for b in buildings:
		if b.team == t and b.kind == hall and not b.dead:
			return b
	for b in buildings:
		if b.team == t and not b.dead:
			return b
	return null


# ------------------------------------------------------------------ entities

func _add_unit(k: String, t: int, pos: Vector2) -> Unit:
	var u := Unit.new()
	u.setup(self, k, t, pos)
	apply_drills(u)
	world.add_child(u)
	units.append(u)
	return u


## ghost: a placed site whose construction hasn't started (Building.ghost): it takes no
## ground until it does (_solidify).
func _add_building(k: String, t: int, c: Vector2i, complete: bool, ghost := false) -> Building:
	var b := Building.new()
	b.setup(self, k, t, c, complete)
	b.ghost = ghost and not complete
	if k == "gate":
		b.vertical = new_gate_facing(t, c, _gate_plan)     # (a saved game sets its own after)
	world.add_child(b)
	buildings.append(b)
	if k == "town_hall" or k == "hive" or k == "clocktower":
		_take_scar(b)
	if b.ghost:
		_reserve_ghost(b, true)
		if not sees_all() and hidden_ghost(b, fog_team()):
			b.visible = false              # (another side's plan: never shown)
		if Defs.BUILDINGS[k].get("line", false):
			_orient_gates(c)
			relink_walls(c)
		b._update_sprite()
	else:
		_solidify(b)
	_recount_supply(t)
	return b


## The building takes its ground: its cells turn solid (a gate: passable for its side, a
## Farm's crop rows walkable) and anyone left standing there is pushed out (but `keep`).
func _solidify(b: Building, keep: Array = []) -> void:
	var k := b.kind
	var c := b.cell
	if b.ghost:
		_reserve_ghost(b, false)
		b.ghost = false
		b.block_since = -1.0
		b.asked.clear()
	if Defs.BUILDINGS[k].get("gate", false):
		_mark(c, b.size, 3)
		gate_team[idx(c)] = b.team
	else:
		_mark(c, b.size, 4 if Defs.BUILDINGS[k].get("line", false) else 2)
	for fc in Building.field_cells(k):
		_mark(c + fc, Vector2i.ONE, 5)      # a Farm's crop rows: men walk them, nothing is built on them
	if Defs.BUILDINGS[k].get("line", false):
		_orient_gates(c)
		relink_walls(c)
	_push_units_out(b.rect(), keep)
	_astar_dirty = true
	b._update_sprite()


func _reserve_ghost(b: Building, on: bool) -> void:
	for y in b.size.y:
		for x in b.size.x:
			var cc := b.cell + Vector2i(x, y)
			if not in_map(cc):
				continue
			var i := idx(cc)
			if on:
				if not ghost_cells.has(i):
					ghost_cells[i] = []
				if not (ghost_cells[i] as Array).has(b):
					ghost_cells[i].append(b)
			elif ghost_cells.has(i):
				ghost_cells[i].erase(b)
				if (ghost_cells[i] as Array).is_empty():
					ghost_cells.erase(i)


## A ghost of `t`'s side (its own or an ally's) over this cell, if any.
func side_ghost_at(t: int, c: Vector2i) -> Building:
	if ghost_cells.is_empty() or not in_map(c):
		return null
	for g in ghost_cells.get(idx(c), []):
		if not g.dead and allied(g.team, t):
			return g
	return null


## Hidden from this player: a ghost site of another side.
func hidden_ghost(b: Building, t: int) -> bool:
	return b.ghost and t >= 0 and not allied(b.team, t)


func _push_units_out(r: Rect2, keep: Array = []) -> void:
	for u in units:
		if not u.dead and not u.is_air() and not keep.has(u) and r.grow(u.radius).has_point(u.position) \
				and not _clear_at(u.position, u.radius, u.team):
			u.position = cell_center(nearest_free(cell_of(u.position), 8))


# ------------------------------------------------------------------ ghost sites

const GHOST_WAIT := 5.0                  # seconds a ghost waits for its footprint to clear


## The units (not flyers, not the site's own builders) standing on a ghost's footprint.
func site_blockers(b: Building) -> Array:
	var out: Array = []
	var r := b.rect()
	for u in units_near(r.get_center(), r.size.length() * 0.5 + 24.0):
		if u.dead or u.is_air() or u.aboard or u.off_field:
			continue
		if u.team == b.team and u.order == "build" and u.order_target == b:
			continue
		if r.grow(u.radius * 0.7).has_point(u.position):
			out.append(u)
	return out


## A ghost's cells still free to build on (no terrain or building has come there since).
func site_cells_free(b: Building) -> bool:
	for y in b.size.y:
		for x in b.size.x:
			var cc := b.cell + Vector2i(x, y)
			if not in_map(cc) or solid[idx(cc)] != 0:
				return false
	return true


## The nearest free spot just outside a footprint, for a unit standing on it.
func spot_outside(b: Building, u: Unit) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for ring in range(1, 5):
		for y in range(-ring, b.size.y + ring):
			for x in range(-ring, b.size.x + ring):
				if x > -ring and y > -ring and x < b.size.x + ring - 1 and y < b.size.y + ring - 1:
					continue
				var cc := b.cell + Vector2i(x, y)
				if not passable(cc, u.team) or side_ghost_at(b.team, cc) != null:
					continue
				var p := cell_center(cc)
				var dd := p.distance_to(u.position)
				if dd < bd:
					bd = dd
					best = p
		if best != Vector2.INF:
			return best
	return cell_center(nearest_free(cell_of(u.position), 8))


## An allied unit on a ghost about to start steps out of the way, then carries on with
## what it was doing (a move into the footprint itself is dropped).
func step_aside(u: Unit, b: Building) -> void:
	var r := b.rect()
	var resume := {}
	match u.order:
		"move", "amove":
			if not r.grow(8.0).has_point(u.order_point):
				resume = {"o": u.order, "p": u.order_point}
		"attack", "build", "repair":
			if u.order_target and is_instance_valid(u.order_target) and not u.order_target.dead:
				resume = {"o": u.order, "e": u.order_target}
		"gather":
			var m = u.home_mine if u.home_mine else u.order_target
			if m and is_instance_valid(m) and not m.dead:
				resume = {"o": "gather", "e": m}
	var old_queue: Array = u.queue.duplicate()
	var old_line: Array = u.line_rest.duplicate()
	u.give({"o": "move", "p": spot_outside(b, u)})
	if not resume.is_empty():
		u.queue.append(resume)
	u.queue.append_array(old_queue)
	u.line_rest = old_line


## A worker has come to start a ghost site: 1 it starts now (the cells turn solid), 0 wait
## (units on it: allies are told to step out, enemies stay where they are), -1 it can't be
## built (still blocked after GHOST_WAIT, or the ground is taken): the site is gone, its cost
## refunded in full, and its builders go on to their next order.
func try_start_site(b: Building, worker: Unit) -> int:
	if b == null or b.dead or not b.ghost:
		return 1
	if not site_cells_free(b):
		site_failed(b)
		return -1
	var blockers := site_blockers(b)
	blockers.erase(worker)
	if blockers.is_empty():
		# (a grub is about to become it: it stays where it is)
		_solidify(b, [worker] if worker and worker.kind == "grub" else [])
		return 1
	if b.block_since < 0.0:
		b.block_since = clock
	elif clock - b.block_since > GHOST_WAIT:
		site_failed(b)
		return -1
	for u in blockers:
		if allied(u.team, b.team):
			var id: int = u.get_instance_id()
			if clock - float(b.asked.get(id, -99.0)) > 1.5:
				b.asked[id] = clock
				step_aside(u, b)
	return 0


## A ghost that can't start: full refund (it never began), it goes, and the owner is told.
func site_failed(b: Building) -> void:
	if b.dead:
		return
	var t := b.team
	var cost := int(b.d["cost"])
	players[t]["gold"] += cost
	stats[t]["spent"] -= cost
	stats[t]["built"] = maxi(0, int(stats[t]["built"]) - 1)
	if t == human and not demo and hud:
		_notify_t = Time.get_ticks_msec()
		hud.toast("Can't build there: the spot is blocked.", true)
		Sfx.announce(faction_of(t), "bad_place", 4.0)
	if mlog:
		mlog.add("%s couldn't start a %s: the spot was blocked (refunded)" % [mlog.who(t), b.d["name"]])
	remove_ghost(b)
	for u in units.duplicate():
		if u.team == t and not u.dead and u.order == "build" and u.order_target == b:
			u.site_gone()
	for ai in ais:
		if ai.team == t and ai.has_method("site_failed"):
			ai.site_failed(b)


## Take a ghost off the map (nothing was built: no rubble, no loss counted).
func remove_ghost(b: Building) -> void:
	if b.dead:
		return
	_reserve_ghost(b, false)
	b.dead = true
	b.selected = false
	selection.erase(b)
	buildings.erase(b)
	if b.crate_obj and is_instance_valid(b.crate_obj):
		b.crate_obj.remove()
	b.crate_obj = null
	b.visible = false
	b.rubble_t = 25.0           # (freed a few seconds on, like a wrecked site)
	_recount_supply(b.team)
	if Defs.BUILDINGS[b.kind].get("line", false):
		relink_walls(b.cell)


## The nearest free cell, preferring one on the open map (not a sealed pocket between
## buildings, where a unit put there could never walk out); a pocket only if there's nothing else.
func nearest_free(c: Vector2i, max_r := 10) -> Vector2i:
	if is_free(c) and in_open_map(c):
		return c
	var pocket := Vector2i(-1, -1)
	for r in range(1, max_r + 1):
		var best := Vector2i(-1, -1)
		var bd := INF
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if absi(x) != r and absi(y) != r:
					continue
				var cc := c + Vector2i(x, y)
				if is_free(cc):
					if not in_open_map(cc):
						if pocket.x < 0:
							pocket = cc
						continue
					var dd := Vector2(x, y).length()
					if dd < bd:
						bd = dd
						best = cc
		if best.x >= 0:
			return best
	if is_free(c):
		return c
	return pocket if pocket.x >= 0 else c


## Walkable for everyone: open ground or a Farm's crop rows (not gates).
func open_cell(c: Vector2i) -> bool:
	return in_map(c) and (solid[idx(c)] == 0 or solid[idx(c)] == 5)


## Connected walkable areas (open ground, crop rows and gates, 4-way, as the pathfinder
## goes: it never cuts a corner), worked out again whenever something is built or pulled
## down. An area smaller than POCKET cells is a sealed pocket (say, a gap shut in by houses).
const POCKET := 48
var _region := PackedInt32Array()
var _region_size: Array = []
var _region_dirty := true


func _update_regions() -> void:
	# (flat cell numbers and one preallocated stack: on a big map this runs after every
	# building change, so it has to be quick)
	_region_dirty = false
	var n_cells := W * H
	_region.resize(n_cells)
	_region.fill(-1)
	_region_size.clear()
	var stack := PackedInt32Array()
	stack.resize(n_cells)
	for i in n_cells:
		if _region[i] >= 0:
			continue
		var v := solid[i]
		if v != 0 and v != 3 and v != 5:
			continue
		var id := _region_size.size()
		var n := 0
		var top := 0
		stack[0] = i
		top = 1
		_region[i] = id
		while top > 0:
			top -= 1
			var c := stack[top]
			n += 1
			var x := c % W
			var j := 0
			var vv := 0
			j = c - 1
			if x > 0 and _region[j] < 0:
				vv = solid[j]
				if vv == 0 or vv == 3 or vv == 5:
					_region[j] = id
					stack[top] = j
					top += 1
			j = c + 1
			if x < W - 1 and _region[j] < 0:
				vv = solid[j]
				if vv == 0 or vv == 3 or vv == 5:
					_region[j] = id
					stack[top] = j
					top += 1
			j = c - W
			if j >= 0 and _region[j] < 0:
				vv = solid[j]
				if vv == 0 or vv == 3 or vv == 5:
					_region[j] = id
					stack[top] = j
					top += 1
			j = c + W
			if j < n_cells and _region[j] < 0:
				vv = solid[j]
				if vv == 0 or vv == 3 or vv == 5:
					_region[j] = id
					stack[top] = j
					top += 1
		_region_size.append(n)


## Which walkable area a cell belongs to (-1: not walkable).
func region_of(c: Vector2i) -> int:
	if _region_dirty:
		_update_regions()
	return _region[idx(c)] if in_map(c) else -1


## On walkable ground that's part of the open map, not a sealed pocket.
func in_open_map(c: Vector2i) -> bool:
	var r := region_of(c)
	return r >= 0 and int(_region_size[r]) >= POCKET


## A ground unit at `p` shut in a sealed pocket (by buildings: it can walk out through
## them as a last resort, see escape_point).
func sealed_in(p: Vector2) -> bool:
	var r := region_of(cell_of(p))
	return r >= 0 and int(_region_size[r]) < POCKET


## Last resort for a unit sealed in a pocket: the nearest cell of the open map it can reach
## by walking through buildings (and walls) only, never through cliffs, trees or water.
## Vector2.INF when there's none within reach (terrain shuts it in: it stays put).
func escape_point(p: Vector2) -> Vector2:
	var start := cell_of(p)
	var seen := {start: true}
	var q: Array = [start]
	var qi := 0
	while qi < q.size() and qi < 400:
		var c: Vector2i = q[qi]
		qi += 1
		if c != start and open_cell(c) and in_open_map(c):
			return cell_center(c)
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + dd
			if not in_map(nc) or seen.has(nc):
				continue
			seen[nc] = true
			if solid[idx(nc)] != 1:
				q.append(nc)
	return Vector2.INF


func on_unit_died(u: Unit) -> void:
	units.erase(u)
	selection.erase(u)
	for g in groups:
		g.erase(u)
	if u.kind == "horse":
		# (a horse isn't counted in the losses; the Brood still feeds on its body: a Pen
		# close by takes it at once, else the grubs can harvest it like any other)
		if brood_in_match():
			for t in n_players():
				if faction_of(t) != "brood":
					continue
				for b in buildings:
					if b.team == t and b.kind == "brood_pen" and b.built and not b.dead \
							and b.center().distance_to(u.position) < Defs.PEN_RANGE * T:
						var ess := body_supply(u) * Defs.ESSENCE_PER_SUPPLY
						add_res2(t, ess)
						if t == human:
							float_text(u.position + Vector2(0, -20), "+%d essence" % ess, Color(0.8, 0.5, 1.0))
						return
			corpses.append(u)
		return
	stats[u.team]["lost"] += 1
	# veterancy: the unit that dealt the last blow gets the kill
	var hitter = u.last_hitter
	if is_instance_valid(hitter) and hitter is Unit and not hitter.dead and hostile(hitter.team, u.team):
		(hitter as Unit).kills += 1
	var absorbed := false
	for t in n_players():
		if faction_of(t) == "brood" and not absorbed:
			for b in buildings:
				if b.team == t and b.kind == "brood_pen" and b.built and not b.dead \
						and b.center().distance_to(u.position) < Defs.PEN_RANGE * T:
					var ess := body_supply(u) * Defs.ESSENCE_PER_SUPPLY
					add_res2(t, ess)
					if t == human:
						float_text(u.position + Vector2(0, -20), "+%d essence" % ess, Color(0.8, 0.5, 1.0))
					absorbed = true          # the Pen took it: nothing left to harvest
					break
	if not absorbed and brood_in_match() and not u.is_air():
		corpses.append(u)
	# a Crown soldier's body: a Missionary may raise him (not one who fell under the cross)
	if not absorbed and not u.final_death and (Defs.REVIVE["kinds"] as Array).has(u.kind):
		fallen.append(u)
	var k := _killer(u)
	if k >= 0:
		var foe: Dictionary = stats[k]
		foe["killed"] += 1
		foe["value_killed"] += int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))
		if u.last_hit_by != "" and u.last_hit_team == k:
			foe["kills_by"][u.last_hit_by] = int(foe["kills_by"].get(u.last_hit_by, 0)) + 1


## Bodies on the field that a Brood grub can still harvest.
var corpses: Array = []
## Bodies of Crown soldiers a Missionary can still raise (Defs.REVIVE).
var fallen: Array = []


## Can this Missionary raise that body? (Not one a grub is already taking, nor one another
## Missionary is going to raise: whoever claims a body first has it.)
func can_revive(b, m: Unit) -> bool:
	if b == null or not is_instance_valid(b) or not b.dead or b.final_death or not fallen.has(b) or b.team != m.team:
		return false
	if clock - b.died_at > float(Defs.REVIVE["window"]):
		return false
	var r = b.reviver
	if r != null and r != m and is_instance_valid(r) and not r.dead and (r.order == "revive" or r.order == "dismount") and r._body == b:
		return false     # (another Missionary has claimed it, a mounted one getting off for it too)
	var h = b.harvester
	if h != null and is_instance_valid(h) and not h.dead and h.order == "harvest" and h._corpse == b:
		return false
	return true


## How urgent and worthwhile raising this body is for this Missionary: its worth, up to
## three times as urgent as its window runs out, less the farther it lies:
## value x (1 + 2 x (1 - time left / window)) / (1 + distance / CARE.near_body).
## 0 when he couldn't get there and finish before the window closes (or it's out of reach).
func body_score(m: Unit, b: Unit) -> float:
	var window := float(Defs.REVIVE["window"])
	var left := window - (clock - b.died_at)
	var dist: float = b.position.distance_to(m.position)
	var need := dist / maxf(m.speed, 1.0) + float(Defs.REVIVE["time"]) + (float(Defs.HORSES["dismount"]) if m.is_mounted() else 0.0)
	if left <= need:
		return 0.0
	var ra := region_of(cell_of(m.position))
	var rb := region_of(cell_of(b.position))
	if ra >= 0 and rb >= 0 and ra != rb:
		return 0.0       # (walled off, across water)
	return care_value(b) * (1.0 + 2.0 * (1.0 - left / window)) / (1.0 + dist / float(Defs.CARE["near_body"]))


## The body this Missionary should raise (the best body_score within r), or null.
func find_body(m: Unit, r: float) -> Unit:
	var best: Unit = null
	var bs := 0.0
	for b in fallen:
		if not is_instance_valid(b) or not can_revive(b, m) or b.position.distance_to(m.position) > r:
			continue
		var s := body_score(m, b)
		if s > bs:
			bs = s
			best = b
	return best


## A soldier raised by a Missionary is back in the army.
func on_unit_revived(u: Unit) -> void:
	if not units.has(u):
		units.append(u)
	stats[u.team]["revived"] = int(stats[u.team].get("revived", 0)) + 1     # (older saves: no count)
	var fx := spawn_effect("smoke", u.position + Vector2(0, -10), 0.8)
	fx.modulate = Color(1, 1, 0.85, 0.6)
	if mlog:
		mlog.add("%s's Missionary raised a fallen %s" % [mlog.who(u.team), u.d["name"]])


func brood_in_match() -> bool:
	for t in n_players():
		if faction_of(t) == "brood" and not eliminated[t]:
			return true
	return false


func corpse_value(u: Unit) -> int:
	return body_supply(u) * int(Defs.HARVEST["per_supply"]) + u.kills


## What a body is worth to the Brood, in supply: the unit's own, a horse's carcass 1 plus its
## veterancy (Defs.HORSE_VET), and a rider's horse on top of him.
static func body_supply(u: Unit) -> int:
	var hb := 1 + int(Defs.HORSE_VET["body"]) * Unit.horse_rank(u.horse_miles)
	if u.kind == "horse":
		return hb
	return int(u.d["supply"]) + (hb if u.is_mounted() else 0)


## The nearest unclaimed body within reach of a grub.
func find_corpse(g: Unit, r: float) -> Unit:
	var best: Unit = null
	var bd := r
	for c in corpses:
		if not is_instance_valid(c):
			continue
		var h = c.harvester
		if h != null and h != g and is_instance_valid(h) and not h.dead and h.order == "harvest":
			continue
		# a Missionary on his way to raise him: the body is his
		var rv = c.reviver
		if rv != null and is_instance_valid(rv) and not rv.dead and rv.order == "revive" and rv._body == c:
			continue
		var dd: float = c.position.distance_to(g.position)
		if dd < bd:
			bd = dd
			best = c
	return best


## Who gets the credit for a kill: the last enemy to hit it (or the only enemy).
func _killer(e: Entity) -> int:
	if e.team < 0:
		return -1
	if hostile(e.team, e.last_hit_team):
		return e.last_hit_team
	var foes := enemies_of(e.team)
	return foes[0] if foes.size() == 1 else -1


func on_building_died(b: Building) -> void:
	var line: bool = Defs.BUILDINGS[b.kind].get("line", false)
	if b.ghost:
		_reserve_ghost(b, false)
		selection.erase(b)
		buildings.erase(b)
		_recount_supply(b.team)
		if line:
			relink_walls(b.cell)
		return
	# the land stays tired (its soil / ground / coal and its saltpetre / ore drawn out) for the next hall here
	if (b.kind == "town_hall" or b.kind == "hive" or b.kind == "clocktower") and b.built and (b.soil < b.reserve() or (b.lode_full() > 0.0 and b.lode < b.lode_full())):
		soil_scars.append([b.center(), b.soil, b.kind, b.lode])
	_mark(b.cell, b.size, 0)
	gate_team.erase(idx(b.cell))
	selection.erase(b)
	buildings.erase(b)
	_recount_supply(b.team)
	if line:
		relink_walls(b.cell)          # (the ruin keeps the picture it had)
	stats[b.team]["bld_lost"] += 1
	var k := _killer(b)
	if mlog and (b.built or k >= 0):
		mlog.add("%s lost a %s%s%s" % [mlog.who(b.team), b.d["name"], "" if b.built else " (unfinished)", (" to " + mlog.who(k) + (" (" + b.last_hit_by + ")" if b.last_hit_by != "" else "")) if k >= 0 else ""])
	if k >= 0 and b.built:
		stats[k]["razed"] += 1
		stats[k]["value_killed"] += int(b.d["cost"])


func on_building_complete(b: Building) -> void:
	_recount_supply(b.team)
	if mlog and clock > 1.0 and not Defs.BUILDINGS[b.kind].get("line", false):
		mlog.add("%s finished a %s%s" % [mlog.who(b.team), b.d["name"], " (expansion)" if b.kind == faction_hall(b.team) else ""])
	if b.team == human and clock > 1.0 and Defs.BUILDINGS[b.kind].get("line", false):
		Sfx.play_any(["%s/placed" % Sfx.SHORT.get(b.d["faction"], "crown")], b.center(), -6.0)   # a wall piece: just a soft knock
	elif b.team == human and clock > 1.0:
		Sfx.play_f_once("built", b.d["faction"], 4.0)
		Sfx.announce(b.d["faction"], "expansion" if b.kind == faction_hall(b.team) else "building_done", 3.0)


func _recount_supply(t: int) -> void:
	var cap := 0
	for b in buildings:
		if b.team == t:
			cap += b.supply()
	players[t]["cap"] = mini(cap, max_supply(t))


func supply_used(t: int) -> int:
	var n := 0
	for u in units:
		if u.team == t and not u.dead:
			n += int(u.d["supply"])
	for b in buildings:
		if b.team == t:
			for k in b.queue:
				if not Building.is_research(k):
					n += int(Defs.UNITS[k]["supply"]) * int(Defs.UNITS[k].get("spawn", 1))
	return n


func add_gold(t: int, n: int) -> void:
	var v: float = n * float(income_mult[t]) + float(players[t]["gold_x"])
	var k := int(v)
	players[t]["gold_x"] = v - k
	players[t]["gold"] += k
	stats[t]["gold"] += k


## A queue entry paid back (`kit`: what a queued soldier was paid to come out with; its
## horse, if it took one, comes back out of `at`).
func refund(t: int, k: String, kit: Dictionary = {}, at: Building = null) -> void:
	if kit.has("coat") and at != null:
		horse_back(at, kit)
	if int(kit.get("rid", 0)) != 0 and k != "horse":
		release_rid(t, int(kit["rid"]))     # (its horse is free again; one still at the breeder is kept)
	if Building.is_research(k):
		var info: Dictionary = Defs.RESEARCH[k.substr(1)]
		players[t]["gold"] += int(info["cost"])
		add_res2(t, float(info.get("cost2", 0)))
		stats[t]["spent"] -= int(info["cost"])
		return
	var fee := kit_fee(kit, k)
	players[t]["gold"] += int(Defs.UNITS[k]["cost"]) + fee[0]
	if faction_of(t) == "clockwork":
		give_batteries(t, int(Defs.UNITS[k].get("cost2", 0)))
	else:
		add_res2(t, int(Defs.UNITS[k].get("cost2", 0)) + fee[1])


## Clockwork ENERGY: the full batteries waiting at the player's Clocktowers and Boilers.
func energy_stored(t: int) -> int:
	var n := 0
	for b in buildings:
		if b.team == t and not b.dead and b.built:
			n += b.batteries
	return n


## Spend stored batteries (from the fullest buildings first). False (nothing spent) if
## there aren't enough.
func spend_batteries(t: int, n: int) -> bool:
	if n <= 0:
		return true
	if energy_stored(t) < n:
		return false
	var left := n
	while left > 0:
		var best: Building = null
		for b in buildings:
			if b.team == t and not b.dead and b.built and b.batteries > 0 and (best == null or b.batteries > best.batteries):
				best = b
		if best == null:
			break
		best.batteries -= 1
		left -= 1
	players[t]["res2"] = energy_stored(t)
	stats[t]["energy_spent"] = int(stats[t].get("energy_spent", 0)) + n
	return true


## Winders leave the last few batteries in store as energy (Defs.ENERGY_KEEP; the
## computer may ask for more while it saves up for big engines: players[t]["keep"]). A
## source that is full is always emptied (so it never stops filling).
func can_haul(t: int, src: Building = null) -> bool:
	if src and src.d.has("battery") and src.batteries >= int(src.d["battery"][1]):
		return true
	# (nothing to spend energy on before an Engine Hall stands: no reserve kept until then)
	var keep: int = int(players[t].get("keep", Defs.ENERGY_KEEP)) if _has_built(t, "engine_hall") else 0
	return int(energy[t]) > keep


## Batteries back into store (a cancelled order): to a Clocktower, or any energy building.
func give_batteries(t: int, n: int) -> void:
	if n <= 0:
		return
	var to: Building = nearest_hall(center_of_team(t), t)
	if to == null:
		for b in buildings:
			if b.team == t and not b.dead and b.built and b.d.has("battery"):
				to = b
				break
	if to:
		to.batteries += n


# ------------------------------------------------------------------ production & building

## "" if allowed, else the reason. `key`: a unit kind, or a Barracks train button
## (Defs.TRAIN_AS: "guardsman" and "cuirassier" are the armoured recruits).
func can_train(b: Building, key: String) -> String:
	var k := Defs.train_kind(key)
	if not b.can_train(k):
		return "Can't train that here."
	if Defs.train_armoured(key) and not has_tech(b.team, "armour"):
		return "Research Armour at the Armoury first."
	if not ArtData.UNITS.has(k) or Defs.PENDING.has(k):
		return "Coming soon."      # its sprites aren't in (or tested) yet
	var u: Dictionary = Defs.UNITS[k]
	var rs: String = u.get("research", "")
	if rs != "" and not has_tech(b.team, rs):
		var info: Dictionary = Defs.RESEARCH[rs]
		return "Research %s at the %s first." % [info["name"], Defs.BUILDINGS[info["at"]]["name"]]
	# the tech step: the Brood's and the Clockwork's ranged units need their second economy building
	var reqs: Array = u["requires"] if u.get("requires", "") is Array else ([u["requires"]] if u.get("requires", "") != "" else [])
	for req in reqs:
		if not _has_built(b.team, req):
			return "Needs a %s first." % Defs.BUILDINGS[req]["name"]
	if b.uses_eggs():
		if b.eggs < 1:
			return "No eggs ready."
	elif b.queue.size() >= 5:
		return "Queue is full."
	var res: Array = Defs.FACTIONS[factions[b.team]]["res"]
	var price := unit_price(b.team, key)
	var horse_cost := 0
	if u.get("needs_horse", false) and free_horse_at(b) == null and spare_horse(b.team, b) == null:
		# no horse to hand: the nearest Horse Breeder trains one for him (paid now)
		if breeder_with_room(b.team, b.center()) == null:
			if breeders_of(b.team).is_empty():
				return "Needs a horse: build a Horse Breeder."
			return "The Horse Breeders' queues are full."
		horse_cost = int(Defs.UNITS["horse"]["cost"])
	if players[b.team]["gold"] < price[0] + horse_cost:
		if horse_cost > 0 and players[b.team]["gold"] >= price[0]:
			return "Not enough %s for its horse (%d more)." % [res[0].to_lower(), horse_cost]
		return "Not enough %s." % res[0].to_lower()
	if float(players[b.team]["res2"]) < price[1]:
		return "Not enough %s." % res[1].to_lower()
	if u.has("per"):
		var have := units.filter(func(x: Unit) -> bool: return x.team == b.team and not x.dead and (x.kind == k or String(Defs.FOOT.get(x.kind, "")) == k)).size()
		for bb in buildings:
			if bb.team == b.team and not bb.dead:
				have += bb.queue.count(k)
		var allowed := buildings.filter(func(x: Building) -> bool: return x.team == b.team and x.kind == u["per"] and x.built and not x.dead).size()
		if have >= allowed:
			return "Only one %s per %s." % [u["name"], Defs.BUILDINGS[u["per"]]["name"]]
	if supply_used(b.team) + int(u["supply"]) * int(u.get("spawn", 1)) > players[b.team]["cap"]:
		if players[b.team]["cap"] >= max_supply(b.team):
			return "Supply is maxed out."
		var sup: String = Defs.FACTIONS[factions[b.team]]["supply"]
		return "Need more supply: build a %s." % Defs.BUILDINGS[sup]["name"]
	return ""


## How fast a Brood player's Hives lay eggs: +10% for every Clutch Mound, up to +30%.
func egg_rate(t: int) -> float:
	var n := 0
	for b in buildings:
		if b.team == t and b.kind == "clutch_mound" and b.built and not b.dead:
			n += 1
	return 1.0 + minf(0.1 * n, 0.3)


func _has_built(t: int, kind: String) -> bool:
	for b in buildings:
		if b.team == t and b.kind == kind and b.built and not b.dead:
			return true
	return false


func has_tech(t: int, key: String) -> bool:
	return players[t]["tech"].get(key, false) == true


## Research going on, or waiting in a production queue, anywhere for this player?
func researching(t: int, key: String) -> bool:
	for b in buildings:
		if b.team == t and not b.dead and b.queue.has("@" + key):
			return true
	return false


func research_problem(b: Building, key: String) -> String:
	var info: Dictionary = Defs.RESEARCH[key]
	if not b.built or b.kind != info["at"]:
		return "Can't research that here."
	if has_tech(b.team, key):
		return "Already done."
	if researching(b.team, key):
		return "Already in the queue."
	if b.queue.size() >= 5:
		return "Queue is full."
	# a chain (the musket locks): the next one may be queued behind the one before it
	var req: String = info.get("requires", "")
	if req != "" and not has_tech(b.team, req) and not researching(b.team, req):
		return "Research %s first." % Defs.RESEARCH[req]["name"]
	var needs: String = info.get("needs", "")
	if needs != "" and not _has_built(b.team, needs):
		return "Needs a %s first." % Defs.BUILDINGS[needs]["name"]
	var res: Array = Defs.FACTIONS[factions[b.team]]["res"]
	if players[b.team]["gold"] < int(info["cost"]):
		return "Not enough %s." % String(res[0]).to_lower()
	if float(players[b.team]["res2"]) < float(info.get("cost2", 0)):
		return "Not enough %s." % String(res[1]).to_lower()
	return ""


## Research works like training: paid up front, it joins the building's production queue
## (as "@key") and takes its turn there; CANCEL takes it back out, paid back.
func start_research(b: Building, key: String) -> String:
	var why := research_problem(b, key)
	if why != "":
		return why
	players[b.team]["gold"] -= int(Defs.RESEARCH[key]["cost"])
	add_res2(b.team, -float(Defs.RESEARCH[key].get("cost2", 0)))
	stats[b.team]["spent"] += int(Defs.RESEARCH[key]["cost"])
	if b.queue.is_empty():
		b.prod_t = 0.0
	b.add_entry("@" + key)
	if mlog:
		mlog.add("%s queued research: %s" % [mlog.who(b.team), Defs.RESEARCH[key]["name"]])
	return ""


## Research queued after the one taken out that needed it (the next musket lock) comes
## out too, paid back.
func _drop_dependent_research(t: int, key: String) -> void:
	for b in buildings:
		if b.team != t or b.dead:
			continue
		for i in range(b.queue.size() - 1, -1, -1):
			var k: String = b.queue[i]
			if Building.is_research(k) and String(Defs.RESEARCH[k.substr(1)].get("requires", "")) == key:
				b.take_entry(i)
				if i == 0:
					b.prod_t = 0.0
				refund(t, k)
				_drop_dependent_research(t, k.substr(1))


func research_done(b: Building, key: String) -> void:
	players[b.team]["tech"][key] = true
	var info: Dictionary = Defs.RESEARCH[key]
	if info.get("drill", false):
		# a drill, not equipment: every unit of its kinds has it at once
		for u in units:
			if u.team == b.team and not u.dead:
				apply_drills(u)
	# (only unlocked: the soldiers in the field are refitted one by one, REFIT)
	if b.team == human:
		var what := ("%s unlocked." % Defs.UNITS[info["unlocks"]]["name"]) if info.has("unlocks") else String(info["about"])
		notify("%s researched: %s" % [info["name"], what], true)
		Sfx.announce(faction_of(b.team), "research_done", 3.0)
	if mlog:
		mlog.add("%s researched %s" % [mlog.who(b.team), info["name"]])


# ------------------------------------------------------------------ refits and drills

var _refit_t := 0.0


## The drills this unit's side has researched (Defs.RESEARCH "drill"), on its own `d`: the
## guns' reload (Prepared Charges) and range (Gunner's Quadrant). (The Cavalry Charge is
## checked where the blow lands.) Run on every new unit and when a drill is researched.
func apply_drills(u: Unit) -> void:
	if not (u.kind in ["cannon", "mortar"]) or u.team < 0 or u.team >= players.size():
		return
	var base: Dictionary = Defs.UNITS[u.kind]
	var rel := float(Defs.RESEARCH["charges"]["reload"]) if has_tech(u.team, "charges") else 1.0
	u.d["cooldown"] = float(base["cooldown"]) * rel
	u.d["drill_reload"] = rel
	u.d["range"] = float(base["range"]) + (float(Defs.RESEARCH["quadrant"]["range"]) if has_tech(u.team, "quadrant") else 0.0)


## The best musket lock this player has researched ("" for none).
func best_lock(t: int) -> String:
	var best := ""
	for k in Defs.LOCKS:
		if has_tech(t, k):
			best = k
	return best


## What a recruit from this train button (Defs.TRAIN_AS; or a plain kind) comes out with:
## Armour if it's the armoured one, and a Musketeer the best lock and the bayonet
## researched. {} for units without refits.
func kit_for_new(t: int, key: String) -> Dictionary:
	var k := Defs.train_kind(key)
	if not Defs.ARMOURED.has(k):
		return {}
	var kit := {"armour": Defs.train_armoured(key) and has_tech(t, "armour")}
	if k == "musketeer":
		kit["lock"] = best_lock(t)
		kit["bayonet"] = has_tech(t, "bayonet")
	return kit


## Everything this player has researched (a soldier from a save made before kits were kept).
func kit_all(t: int, kind: String) -> Dictionary:
	return kit_for_new(t, Defs.train_key(kind, true))


## One refit's fee: [gold, powder] (Armour's depends on the soldier's kind).
static func refit_fee(what: String, kind := "musketeer") -> Array:
	var info: Dictionary = Defs.RESEARCH[what]
	if info.has("fees"):
		var f: Array = info["fees"].get(kind, [0, 0])
		return [int(f[0]), int(f[1])]
	return [int(info.get("fee", 0)), int(info.get("fee2", 0))]


## The fees for a whole kit ({"armour": bool, "lock": key, "bayonet": bool}) of a soldier
## of this kind; a lock costs only its own fee.
static func kit_fee(kit: Dictionary, kind := "musketeer") -> Array:
	var f := [0, 0]
	var parts: Array = []
	if kit.get("armour", false):
		parts.append("armour")
	if Defs.RESEARCH.has(String(kit.get("lock", ""))):
		parts.append(String(kit["lock"]))
	if kit.get("bayonet", false):
		parts.append("bayonet")
	for w in parts:
		var e := refit_fee(w, kind)
		f[0] += e[0]
		f[1] += e[1]
	return f


## A unit's price now: [first resource, second], for a kind or a train button. A soldier's
## includes the refit fees for everything he comes out with (an armoured recruit: Armour's).
func unit_price(t: int, key: String) -> Array:
	var k := Defs.train_kind(key)
	var u: Dictionary = Defs.UNITS[k]
	var p := [int(u["cost"]), int(u.get("cost2", 0))]
	if Defs.ARMOURED.has(k) and t >= 0:
		var f := kit_fee(kit_for_new(t, key), k)
		p[0] += f[0]
		p[1] += f[1]
	return p


## The refits this soldier can still get: "armour", and a Musketeer the best lock
## researched (when he has neither it nor a later one) and the bayonet, counting what he's
## already on his way to get.
func refit_options(u: Unit) -> Array:
	var out: Array = []
	if u == null or not Defs.ARMOURED.has(u.kind) or u.dead or u.team < 0:
		return out
	if has_tech(u.team, "armour") and not u.armoured and not u.refit.has("armour"):
		out.append("armour")
	if not Defs.MUSKETS.has(u.kind):
		return out
	if has_tech(u.team, "pouch") and not u.pouch and not u.refit.has("pouch"):
		out.append("pouch")
	if u.kind == "dismounted":
		return out                # (a carbine: no locks or bayonet for it)
	var bl := best_lock(u.team)
	if bl != "" and Defs.LOCKS.find(bl) > u.lock_level(true):
		out.append(bl)
	if has_tech(u.team, "bayonet") and not u.bayonet and not u.refit.has("bayonet"):
		out.append("bayonet")
	return out


## Anything to refit with yet (the AUTO REFIT buttons show from then on)?
func has_refits(t: int) -> bool:
	return has_tech(t, "armour") or best_lock(t) != "" or has_tech(t, "bayonet") or has_tech(t, "pouch")


func can_pay(t: int, fee: Array) -> bool:
	return int(players[t]["gold"]) >= int(fee[0]) and float(players[t]["res2"]) >= float(fee[1])


func pay_refit(t: int, fee: Array) -> void:
	players[t]["gold"] -= int(fee[0])
	players[t]["res2"] = float(players[t]["res2"]) - float(fee[1])
	stats[t]["spent"] += int(fee[0])


## A refit cancelled (another order, the place gone): the fee back, exactly.
func refund_refit(t: int, fee: Array) -> void:
	if t < 0 or t >= players.size():
		return
	players[t]["gold"] += int(fee[0])
	players[t]["res2"] = float(players[t]["res2"]) + float(fee[1])
	stats[t]["spent"] -= int(fee[0])


## The nearest place to be refitted: a finished Barracks or Armoury, or a Powder Wagon of ours.
func refit_place(t: int, p: Vector2) -> Entity:
	var best: Entity = null
	var bd := INF
	for k in Defs.REFIT_AT:
		var b: Entity = nearest_of(p, t, k)
		if b and b.edge_distance(p) < bd:
			bd = b.edge_distance(p)
			best = b
	for u in units:
		if u.team == t and u.kind == "powder_wagon" and not u.dead and not u.off_field and u.aboard == null:
			var dd: float = u.position.distance_to(p)
			if dd < bd:
				bd = dd
				best = u
	return best


## REFIT: these soldiers pay `what`'s fee now and go to the nearest Barracks, Armoury or
## Powder Wagon to be fitted (those who have it already, or are on their way for it, are
## skipped). Returns [how many went, why the others didn't ("" if none were held back)].
func refit_order(list: Array, what: String, quiet := false) -> Array:
	var n := 0
	var why := ""
	var t := -1
	for u in list:
		if not (u is Unit) or not is_instance_valid(u) or u.aboard != null or u.off_field or not refit_options(u).has(what):
			continue
		var place := refit_place(u.team, u.position)
		if place == null:
			why = "No Barracks, Armoury or Powder Wagon to refit at."
			break
		var fee := refit_fee(what, u.kind)
		if not can_pay(u.team, fee):
			why = "Not enough %s." % ("gold" if int(players[u.team]["gold"]) < int(fee[0]) else "powder")
			break
		t = u.team
		pay_refit(u.team, fee)
		u.add_refit(place, what, fee)
		n += 1
	if n > 0 and mlog and not quiet:
		mlog.add("%s sent %d soldier%s to refit: %s" % [mlog.who(t), n, "" if n == 1 else "s", Defs.RESEARCH[what]["name"]])
	return [n, why]


## AUTO REFIT (on a Barracks, an Armoury or a Powder Wagon): idle soldiers of ours close to
## it that lack an upgrade go and get it there, if the fee can be paid.
func _auto_refit() -> void:
	var places: Array = []
	for b in buildings:
		if b.auto_refit and Defs.REFIT_AT.has(b.kind) and b.built and not b.dead:
			places.append(b)
	for u in units:
		if u.auto_refit and u.kind == "powder_wagon" and not u.dead and not u.off_field and u.aboard == null:
			places.append(u)
	if places.is_empty():
		return
	var reach := float(Defs.REFIT["auto"]) * Defs.TILE
	var sent := {}
	for u in units:
		if not Defs.ARMOURED.has(u.kind) or u.dead or u.off_field or u.aboard != null or u.order != "idle" or u.target != null:
			continue
		var opts := refit_options(u)
		if opts.is_empty():
			continue
		for pl in places:
			if pl.team != u.team or pl.edge_distance(u.position) > reach:
				continue
			for w in opts:
				var fee := refit_fee(w, u.kind)
				if can_pay(u.team, fee):
					pay_refit(u.team, fee)
					u.add_refit(pl, w, fee)
					sent[u.team] = int(sent.get(u.team, 0)) + 1
			break
	if mlog:
		for t in sent:
			mlog.add("%s auto-refit: %d upgrade%s ordered" % [mlog.who(t), sent[t], "" if sent[t] == 1 else "s"])


## (a soldier) refitted: a word over his head for the player.
func refit_done(u: Unit, what: Array) -> void:
	if u.team == human:
		var names: Array = what.map(func(w: String) -> String: return "+" + String(Defs.RESEARCH[w]["name"]))
		float_text(u.position + Vector2(0, -34), " ".join(names), Color(0.85, 0.9, 1.0))


## Train a unit kind, or a Barracks train button (Defs.TRAIN_AS): the soldier goes in the
## queue as his kind, with the kit he was paid to come out with beside it.
func train(b: Building, key: String) -> String:
	var why := can_train(b, key)
	if why != "":
		return why
	var k := Defs.train_kind(key)
	var price := unit_price(b.team, key)
	players[b.team]["gold"] -= price[0]
	if faction_of(b.team) == "clockwork":
		spend_batteries(b.team, price[1])
	else:
		add_res2(b.team, -price[1])
	stats[b.team]["spent"] += price[0]
	var kit := kit_for_new(b.team, key)
	if Defs.UNITS[k].get("needs_horse", false):
		# the horse at the building is his: it walks in (its coat rides out with him)
		var h := free_horse_at(b)
		kit = kit.duplicate()
		if h:
			kit["coat"] = h.coat
			kit["hh"] = snappedf(h.hp / maxf(h.max_hp, 1.0), 0.01)
			kit["hm"] = snappedf(h.horse_miles, 0.1)
			h.walk_into(b)
		else:
			# one click trains both: a free horse at a breeder is kept for him, or the
			# nearest breeder trains one (paid now); a gun's horse walks over by itself
			kit["rid"] = new_rid()
			_reserve_horse(b, k, int(kit["rid"]), true)
	b.add_entry(k, kit)
	if b.uses_eggs():
		b.eggs -= 1
		b.morph_t.append(0.0)
	return ""


func cancel_train(b: Building) -> void:
	if b.queue.is_empty():
		return
	var kit := b.kit_at(b.queue.size() - 1)
	var k: String = b.queue.pop_back()
	if b.kits.size() > b.queue.size():
		b.kits.resize(b.queue.size())
	if b.uses_eggs():
		b.morph_t.pop_back()
		b.eggs += 1
	if b.queue.is_empty():
		b.prod_t = 0.0
	refund(b.team, k, kit, b)
	if Building.is_research(k):
		_drop_dependent_research(b.team, k.substr(1))


## Cancel one entry of the production line (a click on its picture in the unit card).
func cancel_train_at(b: Building, i: int) -> void:
	if i < 0 or i >= b.queue.size():
		return
	if i == b.queue.size() - 1:
		cancel_train(b)
		return
	var k: String = b.queue[i]
	var kit := b.take_entry(i)
	if b.uses_eggs():
		b.morph_t.remove_at(i)
		b.eggs += 1
	elif i == 0:
		b.prod_t = 0.0               # the next one starts from scratch
	refund(b.team, k, kit, b)
	if Building.is_research(k):
		_drop_dependent_research(b.team, k.substr(1))


func spawn_trained(b: Building, k: String, kit: Dictionary = {}) -> void:
	var r := b.rect()
	var toward := b.rally if b.rally != Vector2.INF else r.get_center() + Vector2(0, r.size.y)
	# Spawn on the free cell around the building closest to the rally point.
	var best := cell_of(r.get_center())
	var bd := INF
	for y in range(b.cell.y - 1, b.cell.y + b.size.y + 1):
		for x in range(b.cell.x - 1, b.cell.x + b.size.x + 1):
			var c := Vector2i(x, y)
			if is_free(c):
				var dd := cell_center(c).distance_to(toward)
				if not in_open_map(c):
					dd += 100000.0          # a sealed pocket only if nothing else is free
				if dd < bd:
					bd = dd
					best = c
	stats[b.team]["trained"] += int(Defs.UNITS[k].get("spawn", 1))
	if mlog and not _first_of.has("%d:%s" % [b.team, k]):
		_first_of["%d:%s" % [b.team, k]] = true
		mlog.add("%s got its first %s" % [mlog.who(b.team), Defs.train_name(Defs.train_key(k, bool(kit.get("armour", false))))])
	if b.team == human:
		if b.uses_eggs():
			Sfx.play("hatch", b.global_position)
		else:
			Sfx.play_f_once("ready", b.d["faction"], 6.0, -3.0)
		Sfx.voice(k, "select")
	var rid := int(kit.get("rid", 0))
	var sk := k
	if k == "cuirassier" and rid != 0:
		sk = "dismounted"       # trained on foot: he goes and gets on the horse kept for him
	for n in int(Defs.UNITS[k].get("spawn", 1)):
		var u := _add_unit(sk, b.team, cell_center(best) + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
		if sk == "dismounted":
			u.set_kit(kit)
			u.horse_rid = rid
			u.rally_after = b.rally
			u._res_t = 0.0
			continue
		if not kit.is_empty():
			u.set_kit(kit)          # (a soldier paid to come out armoured, a Musketeer with a better lock)
		if kit.has("coat") and HorseCoat.COATS.has(String(kit["coat"])):
			u.coat = String(kit["coat"])      # the horse that walked in
			u.horse_hp = float(kit.get("hh", 1.0))
			u.horse_miles = float(kit.get("hm", 0.0))
			if u.is_mounted():
				u.max_hp += Unit.horse_bonus_hp(u.horse_miles)    # a seasoned horse under him
				u.hp = u.max_hp
			HorseCoat.apply(u)
		if u.is_worker():
			var site: Building = null
			if b.dual_rally() and b.worker_rally_target is Building:
				site = b.worker_rally_target
			elif not b.dual_rally() and b.rally_target is Building:
				site = b.rally_target
			if site == null or site.dead or site.crew.size() >= int(site.d.get("crew", 0)):
				site = null
				var rp: Vector2 = b.worker_rally if b.dual_rally() else b.rally
				if rp == Vector2.INF:
					site = free_site(b.team, u.position)
				else:
					u.cmd_move(rp + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
					continue
			if site:
				u.cmd_gather(site)
			continue
		if u.kind == "horse":
			# a bought horse grazes where it stands, or walks to the RALLY and grazes there;
			# one bought for a recruit is kept for him (a gun's walks over to its Foundry)
			u.graze_at = u.position
			if rid != 0:
				var owner: Object = rid_owner(b.team, rid)
				if owner != null:
					u.horse_rid = rid
					if owner is Building:
						if not (owner as Building).can_train("cuirassier"):
							u.walk_into(owner)
					continue
			if b.rally != Vector2.INF:
				u.cmd_move(b.rally + Vector2(randf_range(-20, 20), randf_range(-20, 20)))
			continue
		if b.rally_target is Unit and is_instance_valid(b.rally_target) and not b.rally_target.dead:
			u.cmd_follow(b.rally_target)
		elif b.rally != Vector2.INF:
			u.cmd_move(b.rally + Vector2(randf_range(-20, 20), randf_range(-20, 20)), true)


func requirement_met(t: int, k: String) -> bool:
	return requirement_text(t, k) == ""


## "" when every building this one needs stands (finished), else what's missing.
func requirement_text(t: int, k: String) -> String:
	var r = Defs.BUILDINGS[k].get("requires", "")
	var reqs: Array = r if r is Array else ([r] if r != "" else [])
	for req in reqs:
		if not _has_built(t, req):
			return "Needs a %s first." % Defs.BUILDINGS[req]["name"]
	return ""


## "" if the building can go at this cell, else the reason. ai: skip the fog check.
func placement_problem(t: int, k: String, c: Vector2i, ai := false, limits_checked := false) -> String:
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if in_map(cc) and ramp.size() > idx(cc) and ramp[idx(cc)] == 1:
				return "Can't build on a ramp: build at the top or the bottom of it."
			if not in_map(cc) or solid[idx(cc)] != 0:
				if k == "gate" and in_map(cc) and solid[idx(cc)] == 4 and _own_wall_at(t, cc) != null:
					continue     # a gate can replace a piece of your own wall
				if k == "wall" and in_map(cc) and _own_gate_at(t, cc) != null:
					continue     # and a wall piece a gate of yours (place_line: a single piece only)
				return "Blocked."
			var gh := side_ghost_at(t, cc)
			if gh != null and not (gh.team == t and ((k == "gate" and gh.kind == "wall") or (k == "wall" and gh.kind == "gate"))):
				return "Blocked: a building is planned there."
			if not ai and t == human and not demo and explored[idx(cc)] == 0:
				return "Unexplored."
			if needs_swamp(k) and swamp[t][idx(cc)] == 0:
				return "Brood structures must grow on your swamp."
			# the computer keeps its ramps clear (for its own wall and its army)
			if ai and not Defs.BUILDINGS[k].get("line", false) and _near_ramp(cc):
				return "Keep the ramp clear."
	if k == faction_hall(t):
		var mid0 := (Vector2(c) + Vector2(size) * 0.5) * T
		for h in (_spot_all_halls if limits_checked and _in_spot else halls_of(t, false)):
			if h.center().distance_to(mid0) < Defs.HALL_SPACING * T:
				return "Too close to your other %s: it needs its own ground." % Defs.BUILDINGS[k]["name"]
	if Defs.is_econ(k):
		if not limits_checked and econ_count(t, k) >= econ_limit(t, k):
			return "Each %s allows %d %s. Expand for more." % [Defs.BUILDINGS[faction_hall(t)]["name"],
				int(Defs.FACTIONS[faction_of(t)]["econ"][k]), Defs.BUILDINGS[k]["name"] + ("s" if int(Defs.FACTIONS[faction_of(t)]["econ"][k]) > 1 else "")]
		if faction_of(t) != "brood":
			var mid := (Vector2(c) + Vector2(size) * 0.5) * T
			var near := false
			for h in (_spot_halls if limits_checked else halls_of(t)):
				if h.center().distance_to(mid) <= Defs.ECON_RANGE * T:
					near = true
					break
			if not near:
				return "Must be near your %s." % Defs.BUILDINGS[faction_hall(t)]["name"]
	return ""


func _near_ramp(c: Vector2i) -> bool:
	if not in_map(c):
		return _near_ramp_slow(c)
	if _near_ramp_grid.size() != W * H:
		# (worked out once per map: a ramp cell within 2 cells of each cell)
		_near_ramp_grid.resize(W * H)
		for y in H:
			for x in W:
				_near_ramp_grid[y * W + x] = 1 if _near_ramp_slow(Vector2i(x, y)) else 0
	return _near_ramp_grid[c.y * W + c.x] == 1


var _near_ramp_grid := PackedByteArray()     # cleared when the map's ground changes


func _near_ramp_slow(c: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var n := c + Vector2i(dx, dy)
			if in_map(n) and ramp[idx(n)] == 1:
				return true
	return false


## queued (Shift): the builders go to it after the orders they already have.
func place_building(t: int, k: String, c: Vector2i, builders: Array, queued := false) -> Building:
	if placement_problem(t, k, c) != "" or players[t]["gold"] < int(Defs.BUILDINGS[k]["cost"]):
		return null
	if not requirement_met(t, k):
		return null
	if k == "gate":
		var old_wall := _own_wall_at(t, c)
		if old_wall:
			_remove_quietly(old_wall)
	if k == "wall":
		var old_gate := _own_gate_at(t, c)
		if old_gate:
			_remove_quietly(old_gate)
	players[t]["gold"] -= int(Defs.BUILDINGS[k]["cost"])
	stats[t]["spent"] += int(Defs.BUILDINGS[k]["cost"])
	stats[t]["built"] += 1
	var b := _add_building(k, t, c, false, true)     # a ghost until its building starts
	last_placed[t] = {"at": b.center(), "t": clock, "kind": k}
	if Defs.BUILDINGS[k]["faction"] == "clockwork":
		b.seeded = false
		# the Winder fetches its crate from a Clocktower first (none: he starts it by hand)
		b.crate = "tower" if crate_tower(t, b.center(), b) != null else ""
		b._update_sprite()
		builders = builders.slice(0, 1)   # one winder starts it, then it builds itself
	if Defs.BUILDINGS[k]["faction"] == "brood":
		b.seeded = false
		b._update_sprite()
		builders = builders.slice(0, 1)   # one grub becomes the building
	for u in builders:
		if u is Unit and u.is_worker() and not u.dead:
			u.give({"o": "build", "e": b}, queued)
	return b


## Clockwork: the Clocktower a Winder at `from` fetches the crate for `site` from: the one
## that makes the shortest trip (to it, then on to the site). null when there's none.
func crate_tower(t: int, from: Vector2, site: Building) -> Building:
	var best: Building = null
	var bd := INF
	for h in halls_of(t):
		if h == site or h.kind != "clocktower":
			continue
		var dd: float = h.edge_distance(from) + h.edge_distance(site.center())
		if dd < bd:
			bd = dd
			best = h
	return best


## A Winder carrying a crate let go of it (killed, or given another job): it lies at `p`
## until another Winder carries it on.
func drop_crate(site: Building, p: Vector2, hp := -1.0) -> Crate:
	var c := Crate.new()
	c.setup(self, site.team, resolve_terrain(p, p, 8.0), site)
	if hp > 0.0:
		c.hp = minf(hp, c.max_hp)
	world.add_child(c)
	crates.append(c)
	site.crate = "ground"
	site.crate_carrier = null
	site.crate_obj = c
	return c


## The nearest crate of this side on the ground within r that no Winder is going for.
func free_crate(t: int, p: Vector2, r: float) -> Crate:
	var best: Crate = null
	var bd := r
	for c in crates:
		if c.team == t and not c.dead and c.claimed == null and c.wanted():
			var dd: float = c.position.distance_to(p)
			if dd < bd:
				bd = dd
				best = c
	return best


## The crate on the ground under a tap.
func crate_at(p: Vector2) -> Crate:
	for c in crates:
		if not c.dead and c.visible and c.rect().grow(6).has_point(p):
			return c
	return null


## Power fields lie flat on the ground, so seen at the map's angle they are ellipses:
## as wide as the field's radius, squashed top to bottom like the ring art (512×435).
const FIELD_Y := 435.0 / 512.0


## Is `p` inside a field of radius `r` around `c` (the ellipse that is drawn)?
static func in_ellipse(c: Vector2, p: Vector2, r: float) -> bool:
	var d := p - c
	d.y /= FIELD_Y
	return d.length_squared() <= r * r


## Overcharge ground: by a Boiler, inside a Charging Pylon's field or a deployed Tesla Cart's.
func in_overcharge(t: int, p: Vector2) -> bool:
	var m := field_mult(t)
	for b in buildings:
		if b.team != t or not b.built or b.dead:
			continue
		if b.kind == "boiler" and b.edge_distance(p) <= float(Defs.OVERCHARGE["boiler"]) * T:
			return true
		if b.kind == "charging_pylon" and b.field_on() and in_ellipse(b.center(), p, float(b.d["field"]) * T * m):
			return true
	for u in units:
		if u.team == t and not u.dead and u.kind == "tesla_cart" and u.tesla_mode == "deployed":
			if in_ellipse(u.position, p, Defs.TESLA_FIELD * T * m):
				return true
	return false


func in_field(t: int, p: Vector2) -> bool:
	var m := field_mult(t)
	for b in buildings:
		if b.team == t and b.built and not b.dead and b.d.has("field") and b.field_on():
			if in_ellipse(b.center(), p, float(b.d["field"]) * T * m):
				return true
	for u in units:
		if u.team == t and not u.dead and u.kind == "tesla_cart" and u.tesla_mode == "deployed":
			if in_ellipse(u.position, p, Defs.TESLA_FIELD * T * m):
				return true
	return false


func find_repair(u: Unit, r: float) -> Entity:
	var best: Entity = null
	var bd := INF
	for o in units_near(u.position, r):
		if o.team == u.team and not o.dead and o != u and (o.hp < o.max_hp * 0.95 or (o.wind < 0.5 and not o.is_worker())) and o.d["faction"] == "clockwork":
			var dd: float = o.position.distance_to(u.position)
			if dd < bd:
				bd = dd
				best = o
	if best:
		return best
	for b in buildings:
		if b.team == u.team and b.built and not b.dead and b.hp < b.max_hp * 0.95 and b.edge_distance(u.position) < r:
			return b
	return null


func needs_swamp(k: String) -> bool:
	return Defs.BUILDINGS[k]["faction"] == "brood" and not Defs.BUILDINGS[k].get("eggs", false)


## A unit that turned into something else: gone, but not a loss.
func consume_unit(u: Unit) -> void:
	u._leave_mine()
	units.erase(u)
	selection.erase(u)
	for g in groups:
		g.erase(u)
	u.dead = true
	u.queue_free()


## Brood Pen SACRIFICE: essence a creature gives when it's offered up (0: it can't be).
static func sacrifice_value(kind: String) -> int:
	var d: Dictionary = Defs.UNITS[kind]
	if d["faction"] != "brood" or d.get("worker", false):
		return 0
	return maxi(1, int(round(float(d["cost"]) / maxf(1.0, float(d.get("spawn", 1))) * Defs.SACRIFICE)))


## A Brood creature that reached a Pen on SACRIFICE: offered up for essence.
func sacrifice(u: Unit, pen: Building) -> void:
	var ess := sacrifice_value(u.kind)
	if ess <= 0 or u.dead:
		return
	add_res2(u.team, ess)
	var st: Dictionary = stats[u.team]
	st["sacrificed"] = int(st.get("sacrificed", 0)) + 1
	st["sacrifice_essence"] = int(st.get("sacrifice_essence", 0)) + ess
	if is_visible_to(human, pen.center()) or u.team == human or demo:
		var fx := spawn_effect("acid_splash", pen.center() + Vector2(randf_range(-14, 14), randf_range(-8, 8)), 1.2)
		fx.modulate = Color(0.8, 0.45, 1.0, 0.9)
		fx.z_index = 4
		Sfx.play("work/midden_essence", pen.center(), -4.0)
	if u.team == human:
		float_text(pen.center() + Vector2(0, -34), "+%d essence" % ess, Color(0.8, 0.5, 1.0))
	consume_unit(u)


func notify(msg: String, quiet := false) -> void:
	var now := Time.get_ticks_msec()
	if now - _notify_t > 3000 and hud:
		_notify_t = now
		hud.toast(msg, not quiet)


# ------------------------------------------------------------------ swamp

func on_swamp(t: int, p: Vector2) -> bool:
	return swamp[t][idx(cell_of(p))] == 1


func _update_swamp() -> void:
	swamp_dirty = false
	for t in n_players():
		var g: PackedByteArray = swamp[t]
		g.fill(0)
		if faction_of(t) == "brood":
			for b in buildings:
				if b.team != t or b.dead or b.swamp_r <= 0.0:
					continue
				var c: Vector2 = b.rect().get_center() / T
				var r: float = b.swamp_r + maxf(b.size.x, b.size.y) * 0.5
				for y in range(int(c.y - r) - 1, int(c.y + r) + 2):
					for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
						if x < 0 or y < 0 or x >= W or y >= H or water[y * W + x] == 1:
							continue
						var dx: float = (x + 0.5 - c.x)
						var dy: float = (y + 0.5 - c.y) * 1.15
						if dx * dx + dy * dy <= r * r:
							g[y * W + x] = 1
			# a rooted Spore Mother spreads swamp around her
			for u in units:
				if u.team != t or u.dead or u.kind != "spore_mother" or u.tesla_mode != "deployed":
					continue
				var uc: Vector2 = u.position / T
				var ur: float = Defs.ROOT_SWAMP
				for y in range(int(uc.y - ur) - 1, int(uc.y + ur) + 2):
					for x in range(int(uc.x - ur) - 1, int(uc.x + ur) + 2):
						if x < 0 or y < 0 or x >= W or y >= H or water[y * W + x] == 1:
							continue
						var ddx: float = (x + 0.5 - uc.x)
						var ddy: float = (y + 0.5 - uc.y) * 1.15
						if ddx * ddx + ddy * ddy <= ur * ur:
							g[y * W + x] = 1
		swamp[t] = g
	swamp_layer.queue_redraw()
	_swamp_minimap()


## One small picture of every Brood swamp, drawn on the minimap for everyone.
func _swamp_minimap() -> void:
	if swamp_img == null:
		swamp_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	swamp_img.fill(Color(0, 0, 0, 0))
	for t in n_players():
		if faction_of(t) != "brood":
			continue
		var g: PackedByteArray = swamp[t]
		var col := team_colour(t).lerp(Color(0.32, 0.22, 0.38), 0.6)
		col.a = 0.85
		for i in W * H:
			if g[i] == 1:
				swamp_img.set_pixel(i % W, i / W, col)
	if swamp_tex == null:
		swamp_tex = ImageTexture.create_from_image(swamp_img)
	else:
		swamp_tex.update(swamp_img)


## The powered field of Clockwork buildings: the selected one (anyone's), and while you
## place a building, the one you're placing plus your existing fields.
func _draw_fields() -> void:
	var ring: Texture2D = tex("res://assets/world/field_ring.png")
	var draw_ring := func(c: Vector2, r: float, a: float) -> void:
		var half := Vector2(r, r * FIELD_Y)
		field_layer.draw_texture_rect(ring, Rect2(c - half, half * 2.0), false, Color(1, 1, 1, a))
	for e in selection:
		if not is_instance_valid(e) or e.dead:
			continue
		if e is Building and e.d.has("field") and e.built:
			# a tower busy fighting flyers has its field switched off
			draw_ring.call(e.center(), float(e.d["field"]) * T * field_mult(e.team), 0.9 if e.field_on() else 0.18)
		elif e is Unit and e.kind == "tesla_cart" and e.tesla_mode == "deployed":
			draw_ring.call(e.position, Defs.TESLA_FIELD * T * field_mult(e.team), 0.9)
	if controls and controls.mode == "cast" and controls.cast_spell != "tongue":
		var info: Dictionary = spell_info(controls.cast_spell)
		var col: Color = {"storm": Color(0.55, 0.8, 1.0, 0.9), "fog": Color(0.75, 0.85, 0.8, 0.9)}.get(controls.cast_spell, Color(0.6, 1.0, 0.35, 0.9))
		var at: Vector2 = get_global_mouse_position() if Settings.pc() else camera.get_screen_center_position()
		field_layer.draw_set_transform(at, 0.0, Vector2(1.0, FIELD_Y))
		field_layer.draw_circle(Vector2.ZERO, float(info["radius"]), Color(col.r, col.g, col.b, 0.12))
		field_layer.draw_arc(Vector2.ZERO, float(info["radius"]), 0.0, TAU, 48, col, 2.0)
		field_layer.draw_set_transform(Vector2.ZERO)
	if controls and controls.mode == "place":
		var k: String = controls.place_kind
		if faction_of(human) == "clockwork" or Defs.BUILDINGS[k].has("field"):
			for b in buildings:
				if b.team == human and b.built and not b.dead and b.d.has("field") and not selection.has(b):
					draw_ring.call(b.center(), float(b.d["field"]) * T * field_mult(human), 0.35)
		if Defs.BUILDINGS[k].has("field"):
			var size: Vector2i = Defs.BUILDINGS[k]["size"]
			var c := Vector2(controls.ghost_cell) * T + Vector2(size) * T * 0.5
			draw_ring.call(c, float(Defs.BUILDINGS[k]["field"]) * T * field_mult(human), 0.8)


func _draw_swamp() -> void:
	var t: Texture2D = tex("res://assets/tiles/swamp.png")
	for team in 2:
		var g: PackedByteArray = swamp[team]
		# not on cliffs or ramps: the swamp hid the hillsides and slopes (the ground there
		# still counts as swamp; it just isn't painted over)
		var sh := PackedByteArray()
		sh.resize(W * H)
		for j in W * H:
			sh[j] = 1 if g[j] == 1 and cliff[j] == 0 and ramp[j] == 0 else 0
		for i in W * H:
			if sh[i] == 1:
				var x := i % W
				var y := i / W
				var edge := (x > 0 and sh[i - 1] == 0) or (x < W - 1 and sh[i + 1] == 0) \
					or (y > 0 and sh[i - W] == 0) or (y < H - 1 and sh[i + W] == 0)
				swamp_layer.draw_texture(t, Vector2(x * T, y * T), Color(1, 1, 1, 0.55 if edge else 1.0))


var _astar_dirty := false


# ------------------------------------------------------------------ pathfinding

func queue_path(u: Unit) -> void:
	if not _path_queue.has(u):
		_path_queue.append(u)


func find_path(from: Vector2, to: Vector2, siege := false) -> PackedVector2Array:
	# (a Farm's crop rows are walkable: a unit on them starts, or ends, right there)
	var a := cell_of(from) if open_cell(cell_of(from)) else nearest_free(cell_of(from), 6)
	var b := cell_of(to) if open_cell(cell_of(to)) else nearest_free(cell_of(to), 8)
	var pt := Time.get_ticks_usec()
	var pts := astar.get_point_path(a, b, true)
	if pts.is_empty() and siege:
		# walled out: walk up to the wall (the unit then breaks it down)
		pts = astar_siege.get_point_path(a, b, true)
	Prof.add("game/pathfinder", pt)
	if pts.is_empty():
		return PackedVector2Array([to])
	# Use the exact destination when it's on open ground.
	if open_cell(cell_of(to)) and cell_of(to) == b:
		pts[pts.size() - 1] = to
	pt = Time.get_ticks_usec()
	var sm := _smooth(from, pts)
	Prof.add("game/path smoothing", pt)
	return sm


## Drop waypoints that can be skipped with a clear straight line. (It looks at most
## SMOOTH_LOOK cells ahead: trying every later point of a long, winding path cost up to a
## second and a half for one path; a straight run longer than that just keeps a waypoint.)
const SMOOTH_LOOK := 40


func _smooth(from: Vector2, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cur := from
	var i := 0
	while i < pts.size():
		var j := mini(pts.size() - 1, i + SMOOTH_LOOK)
		while j > i and not line_clear(cur, pts[j]):
			j -= 1
		out.append(pts[j])
		cur = pts[j]
		i = j + 1
	return out


## (The same test as open_cell(cell_of(p +- 7, 7)) at every sample, written out: the
## path smoothing calls it thousands of times for a long path.)
func line_clear(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := int(dist / 10.0) + 1
	var w1 := W - 1
	var h1 := H - 1
	for s in steps + 1:
		var p := a.lerp(b, float(s) / float(steps))
		var x0 := clampi(int((p.x - 7.0) / T), 0, w1)
		var x1 := clampi(int((p.x + 7.0) / T), 0, w1)
		var y0 := clampi(int((p.y - 7.0) / T), 0, h1) * W
		var y1 := clampi(int((p.y + 7.0) / T), 0, h1) * W
		var v := solid[y0 + x0]
		if v != 0 and v != 5:
			return false
		v = solid[y1 + x1]
		if v != 0 and v != 5:
			return false
		v = solid[y1 + x0]
		if v != 0 and v != 5:
			return false
		v = solid[y0 + x1]
		if v != 0 and v != 5:
			return false
	return true


## A reachable point next to an entity, on the side nearest to `from`.
func approach_point(e: Entity, from: Vector2) -> Vector2:
	if e.is_unit():
		return e.global_position
	var r := e.rect()
	var c0 := cell_of(r.position) - Vector2i.ONE
	var c1 := cell_of(r.end - Vector2(1, 1)) + Vector2i.ONE
	var best := Vector2.INF
	var bd := INF
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if x != c0.x and x != c1.x and y != c0.y and y != c1.y:
				continue
			var c := Vector2i(x, y)
			if is_free(c):
				var p := cell_center(c)
				var dd := p.distance_to(from)
				var corner := (x == c0.x or x == c1.x) and (y == c0.y or y == c1.y)
				if corner:
					dd += 48.0
				if dd < bd:
					bd = dd
					best = p
	return best if best != Vector2.INF else r.get_center()


func resolve_terrain(pos: Vector2, before: Vector2, radius: float, team := -1) -> Vector2:
	pos = pos.clamp(Vector2(radius, radius), Vector2(W * T, H * T) - Vector2(radius, radius))
	if _clear_at(pos, radius, team):
		return pos
	var a := Vector2(pos.x, before.y)
	if _clear_at(a, radius, team):
		return a
	var b := Vector2(before.x, pos.y)
	if _clear_at(b, radius, team):
		return b
	if not _clear_at(before, radius, team):
		# Wedged inside something (e.g. a new building): pop out.
		return cell_center(nearest_free(cell_of(before), 6))
	return before


func _clear_at(p: Vector2, radius: float, team := -1) -> bool:
	var r := radius * 0.6
	return passable(cell_of(p), team) and passable(cell_of(p + Vector2(r, 0)), team) and passable(cell_of(p - Vector2(r, 0)), team) \
		and passable(cell_of(p + Vector2(0, r * 0.6)), team) and passable(cell_of(p - Vector2(0, r * 0.6)), team)


# ------------------------------------------------------------------ spatial queries

func _rebuild_hash() -> void:
	_hash.clear()
	for u in units:
		var k := Vector2i(int(u.position.x) / HASH, int(u.position.y) / HASH)
		if not _hash.has(k):
			_hash[k] = []
		_hash[k].append(u)


func units_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var c0 := Vector2i(int(p.x - r) / HASH, int(p.y - r) / HASH)
	var c1 := Vector2i(int(p.x + r) / HASH, int(p.y + r) / HASH)
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var lst: Array = _hash.get(Vector2i(x, y), [])
			for u in lst:
				if is_instance_valid(u) and u.position.distance_to(p) <= r:
					out.append(u)
	return out


func separation(u: Unit) -> Vector2:
	var push := Vector2.ZERO
	for o in units_near(u.position, u.radius + 18.0):
		if o == u or o.dead or o.off_field or o.is_air() != u.is_air():
			continue
		if o == u.steed or u == o.steed:
			continue           # (a man beside his own horse: he got off there, close by it)
		var dvec: Vector2 = u.position - o.position
		var dist := dvec.length()
		var min_d: float = (u.radius + o.radius) * 0.85
		if dist < min_d:
			if dist < 0.01:
				dvec = Vector2.from_angle(randf() * TAU)
				dist = 0.01
			var strength := (min_d - dist) / min_d
			var k := 140.0
			# Idle units step aside for friends on the move.
			if o.team == u.team and o.velocity.length() > 15.0 and u.velocity.length() < 15.0:
				k = 260.0
			push += dvec / dist * strength * k
	return push


func find_target(u: Unit, r: float) -> Entity:
	if u.d.get("no_attack", false):
		return null
	var best: Entity = null
	var bd := INF
	# guns with a minimum range (set up) look past what's too close; area guns (round shot,
	# mortar shells) pass over targets with their own men in the way, for another one
	var min_r := 0.0
	if u.deploys() and u.tesla_mode == "deployed" and u.mode != "canister":
		min_r = float(u.d.get("min_range", 0.0))
	var careful := (u.kind == "cannon" and u.mode != "canister") or u.kind == "mortar"
	var picks: Array = []
	for o in units_near(u.position, r):
		if not hostile(o.team, u.team) or o.dead or not u.can_hit(o):
			continue
		if not o.is_air() and on_high(o.position) and not on_high(u.position) and not is_visible_to(u.team, o.position):
			continue
		# beyond its own sight a unit (the cannon) can only shoot what its side can see
		if o.position.distance_to(u.position) > u.sight * T + 8.0 and not side_sees(u.team, o.position):
			continue
		var dd: float = o.position.distance_to(u.position)
		if min_r > 0.0 and o.edge_distance(u.position) - u.radius < min_r:
			continue
		if o.is_worker():
			dd += 60.0   # prefer fighters
		elif o.kind == "horse":
			dd += 150.0  # a horse only when there's nothing else (better stolen than shot)
		if careful:
			picks.append([dd, o])
		elif dd < bd:
			bd = dd
			best = o
	# a Clockwork crate on the ground: smash it (counted like a worker)
	if not careful and not u.d.get("medic", false):
		for c in crates:
			if c.dead or not hostile(c.team, u.team) or not u.can_hit(c):
				continue
			var dc: float = c.position.distance_to(u.position)
			if dc <= r and dc + 60.0 < bd and side_sees(u.team, c.position):
				bd = dc + 60.0
				best = c
	if careful and not picks.is_empty():
		picks.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for i in mini(picks.size(), 6):
			if aoe_worth_it(u, picks[i][1]):
				return picks[i][1]
		u.held_t = maxf(u.held_t, 1.0)     # (set up, it waits for a clear shot: Unit "amove")
		# nothing safe to shoot at: set up, it holds fire (a building may still do); on the
		# move it goes for the nearest and holds fire there if it must
		if not (u.order == "hold" or u.tesla_mode == "deployed"):
			return picks[0][1]
	if best:
		return best
	if u.d.get("medic", false) or u.d.get("air_only", false):
		return null
	for b in buildings:
		if not hostile(b.team, u.team) or b.dead or b.ghost:
			continue
		var dd: float = b.edge_distance(u.position)
		if dd >= r or (min_r > 0.0 and dd - u.radius < min_r):
			continue
		if dd > 24.0 and not target_seen(u.team, b, u.position):
			continue                  # (in the fog, or up a cliff nobody of ours looks over)
		# walls and gates only when nothing else is in reach: once a swarm is through,
		# it floods in and goes for the base, not for the rest of the wall
		if b.kind == "wall" or b.kind == "gate":
			dd += 400.0
		elif Defs.is_econ(b.kind) or b.kind == faction_hall(b.team):
			dd -= 80.0       # the economy first
		if dd < bd:
			bd = dd
			best = b
	if best == null and faction_of(u.team) == "brood":
		# nothing else in reach: a loose horse (nobody's) is cheap essence
		for o in units_near(u.position, r):
			if loose_horse(o) and not o.off_field and u.can_hit(o) and side_sees(u.team, o.position):
				var dh: float = o.position.distance_to(u.position)
				if dh < bd:
					bd = dh
					best = o
	return best


## Clockwork: blue energy while a Capacitor Works stands.
func blue_energy(t: int) -> bool:
	for b in buildings:
		if b.team == t and b.kind == "capacitor_works" and b.built and not b.dead:
			return true
	return false


func nearest_of(p: Vector2, t: int, kind: String) -> Building:
	var best: Building = null
	var bd := INF
	for b in buildings:
		if b.team == t and b.kind == kind and b.built and not b.dead:
			var dd: float = b.edge_distance(p)
			if dd < bd:
				bd = dd
				best = b
	return best


func nearest_hall(p: Vector2, t: int) -> Building:
	var best: Building = null
	var bd := INF
	for b in buildings:
		if b.team == t and b.kind == faction_hall(t) and b.built and not b.dead:
			var dd: float = b.edge_distance(p)
			if dd < bd:
				bd = dd
				best = b
	return best


## (`_any`: kept for its callers; there's nothing on the map but units and buildings to pick.)
func entity_at(p: Vector2, _any := true) -> Entity:
	var best: Entity = null
	var bd := 26.0
	for u in units:
		if u.dead or not u.visible:
			continue
		var dd: float = (u.position + Vector2(0, -12)).distance_to(p)
		if dd < bd:
			bd = dd
			best = u
	if best:
		return best
	for b in buildings:
		if hidden_ghost(b, controlled_team()):
			continue
		if b.visible and b.rect().grow(6).has_point(p + Vector2(0, 10)):
			return b
		if b.visible and b.sprite and b.sprite.texture:
			var sr := Rect2(b.global_position + b.sprite.offset, b.sprite.texture.get_size())
			if sr.grow(-6).has_point(p):
				return b
	return null


## The finished economy building of team t (a Farm with its fields, a Mill, Pit, Boiler...)
## whose footprint or sprite is under p, or null.
func crew_site_at(p: Vector2, t: int) -> Building:
	for b in buildings:
		if b.team != t or b.dead or not b.built or not b.visible or int(b.d.get("crew", 0)) <= 0:
			continue
		if b.rect().grow(4).has_point(p):
			return b
		if b.sprite and b.sprite.texture:
			var sr := Rect2(b.global_position + b.sprite.offset, b.sprite.texture.get_size())
			if sr.grow(-6).has_point(p):
				return b
	return null


# ------------------------------------------------------------------ combat helpers

## A shot (musket ball, spit, arc ball, spines) at `e`: a braced Bulwark of e's side that
## stands between the shooter and e (e inside the cone behind the shield, within reach, the
## shooter in front of it) takes it instead. Returns who gets hit.
func intercept(shooter: Entity, e: Entity) -> Entity:
	if not (e is Unit) or e.is_air() or shooter == null or not is_instance_valid(shooter):
		return e
	var br: Dictionary = Defs.BRACE
	var from: Vector2 = shooter.global_position
	for o in units_near(e.global_position, float(br["reach"]) + 10.0):
		if o.kind != "bulwark" or not o.braced or o.dead or o.off_field or o == e or o.team != e.team:
			continue
		if o.powered_down():
			continue
		var to_shooter: Vector2 = from - o.position
		if to_shooter.length() < 1.0:
			continue
		var front: Vector2 = to_shooter.normalized()
		if o.facing.dot(front) < float(br["front"]):
			continue            # the shield faces the other way
		var behind: Vector2 = e.global_position - o.position
		if behind.length() > float(br["reach"]):
			continue
		if behind.length() < 6.0 or (-front).dot(behind.normalized()) >= float(br["cone"]):
			o.shield_hit()
			return o
	return e


## Arc Thrower: a ball of lightning thrown at one enemy (a braced Bulwark may catch it).
func arc_shot(u: Unit, e: Entity, dmg: float) -> void:
	e = intercept(u, e)
	var from := u.center() + u.facing * 12.0 + Vector2(0, -6)
	var to := e.center()
	var s := Shot.new()
	s.impact = "arc_impact" if ArtData.EFFECTS.has("arc_impact") else "hit"
	s.impact_scale = 0.8
	s.scale = Vector2(0.7, 0.7)
	s.launch(self, "arc_ball" if ArtData.EFFECTS.has("arc_ball") else "acid_ball", from, to, float(Defs.ARC["speed"]))
	e.take_damage(dmg, u, Entity.BLOW_RANGED)
	Sfx.play_any(["combat/tesla_attack", "zap"], u.global_position)


func musket_shot(u: Unit, e: Entity, dmg: float, from := Vector2.INF) -> void:
	e = intercept(u, e)
	var muzzle := u.center() + u.facing * 20.0 + Vector2(0, -2)
	if e.is_air():
		muzzle = u.center() + u.facing * 13.0 + Vector2(0, -15)     # aiming up
	if from != Vector2.INF:
		muzzle = from
	spawn_effect("smoke", muzzle + u.facing * 8.0, 1.2).scale = Vector2(0.7, 0.7)
	var hit := randf() < 0.85
	if hit:
		e.take_damage(dmg, u, Entity.BLOW_RANGED)
	var aim := e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)) if hit \
		else e.center() + Vector2(randf_range(-26, 26), randf_range(-20, 20))
	var s := Shot.new()
	s.face_offset = PI
	s.scale = Vector2(0.45, 0.45)
	s.impact = "hit" if hit else "smoke"
	s.impact_scale = 1.0 if hit else 0.35
	s.launch(self, "ball", muzzle, aim, 950.0)
	Sfx.play_any(["combat/musketeer_attack", "musket"], u.global_position)


var _tracers: Array = []


func bolt_shot(u: Unit, e: Entity, dmg: float) -> void:
	var from := u.center() + u.facing * 16.0 + (Vector2(0, -8) if e.is_air() else Vector2.ZERO)
	var dir := (e.center() - from).normalized()
	var to := from + dir * (float(u.d["range"]) + 40.0)
	var hits := 0
	for o in units_near(from.lerp(to, 0.5), from.distance_to(to) * 0.5 + 20.0):
		if not hostile(o.team, u.team) or o.dead:
			continue
		var q := Geometry2D.get_closest_point_to_segment(o.center(), from, to)
		if q.distance_to(o.center()) < o.radius + 6.0 and hits < 3:
			o.take_damage(dmg * (1.0 if hits == 0 else 0.6), u)
			spawn_effect("hit", o.center(), 1.0)
			hits += 1
	if e.is_building():
		e.take_damage(dmg, u)
		to = e.center()
	var s := Shot.new()
	s.scale = Vector2(0.8, 0.8)
	s.launch(self, "bolt", from, to, 760.0)
	Sfx.play_any(["combat/bolt_attack", "bolt"], u.global_position)


func steam_cone(u: Unit, e: Entity, dmg: float) -> void:
	var from := u.center()
	var dir := (e.center() - from).normalized()
	var reach := float(u.d["range"]) + 24.0
	for o in units_near(from, reach + 20.0):
		if o == u or o.dead or o.off_field or o.is_air():
			continue
		var to: Vector2 = o.center() - from
		if to.length() <= reach + o.radius and dir.dot(to.normalized()) > 0.72:
			o.take_damage(dmg, u)
	if e.is_building():
		e.take_damage(dmg, u)
	Sfx.play_any(["combat/steam_walker_attack", "steam"], from)
	for i in 3:
		var fx := spawn_effect("smoke", from + dir * (20.0 + i * 22.0) + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 1.6)
		fx.modulate = Color(1.3, 1.3, 1.3, 0.85)


## Cannon canister: a cone of musket balls; every enemy in it is hit (buildings barely).
func canister_shot(u: Unit, e: Entity, dmg: float) -> void:
	var from := u.center() + u.facing * 28.0
	var dir := (e.center() - from).normalized()
	var reach := float(Defs.CANISTER["range"]) + 30.0
	# area damage hits whoever is in it, friend or foe (not the gun itself)
	for o in units_near(from, reach + 20.0):
		if o == u or o.dead or o.off_field:
			continue
		var to: Vector2 = o.center() - from
		if to.length() <= reach + o.radius and dir.dot(to.normalized()) > float(Defs.CANISTER["cone"]):
			var bonus: float = Defs.CANISTER["vs_light"] if o.has_tag("light") else 1.0
			o.take_damage(dmg * bonus * (1.3 if to.length() < reach * 0.5 else 1.0), u)
	if e.is_building():
		e.take_damage(dmg * 0.6, u)
	Sfx.play_any(["combat/cannon_canister", "combat/cannon_attack", "cannon"], u.global_position)
	spawn_effect("smoke", from + dir * 12.0, 0.9)
	spawn_effect("smoke", from + dir * 30.0, 1.2).modulate = Color(1, 1, 1, 0.6)
	# a spray of musket balls fanning out of the muzzle
	var spread := acos(float(Defs.CANISTER["cone"]))
	for i in 18:
		var a := randf_range(-spread, spread) * randf_range(0.4, 1.0)
		var end := from + dir.rotated(a) * reach * randf_range(0.45, 1.0)
		var b := Shot.new()
		b.scale = Vector2(0.45, 0.6)
		b.modulate = Color(1, 0.95, 0.8)
		if randf() < 0.35:
			b.impact = "hit"
			b.impact_scale = 0.7
		b.launch(self, "ball", from + dir.rotated(a) * randf_range(0.0, 10.0), end, randf_range(650.0, 950.0))


func tesla_zap(u: Unit, e: Entity, dmg: float) -> void:
	var from := u.coil_point()
	var hit: Array = [e]
	e.take_damage(dmg, u)
	_zap_visual(from, e.center(), false, true)
	var last := e
	for k in int(Defs.TESLA_CHAIN["jumps"]):
		var nxt: Entity = null
		var bd := float(Defs.TESLA_CHAIN["reach"])
		for o in units_near(last.center(), float(Defs.TESLA_CHAIN["reach"])):
			if not hostile(o.team, u.team) or o.dead or o.off_field or hit.has(o):
				continue
			var dd: float = o.center().distance_to(last.center())
			if dd < bd:
				bd = dd
				nxt = o
		if nxt == null:
			break
		nxt.take_damage(dmg * float(Defs.TESLA_CHAIN["falloff"]), u)
		_zap_visual(last.center(), nxt.center(), false)
		hit.append(nxt)
		last = nxt
	Sfx.play_any(["combat/tesla_attack", "zap"], u.global_position)


## A Clockwork tower's chain lightning: straight up from its tip to a flyer, then jumping
## from flyer to flyer.
func tower_zap(b: Building, e: Unit) -> void:
	var z: Dictionary = Defs.TOWER_ZAP
	var dmg: float = z["damage"]
	var from := b.top_point()
	var hit: Array = [e]
	e.take_damage(dmg, b)
	_zap_visual(from, e.center(), true)
	var last: Entity = e
	for k in int(z["chain"]):
		dmg *= float(z["falloff"])
		var nxt: Unit = null
		var bd: float = z["jump"]
		for o in units_near(last.center(), z["jump"]):
			if not o.is_air() or o.dead or o.off_field or hit.has(o) or not hostile(o.team, b.team):
				continue
			var dd: float = o.center().distance_to(last.center())
			if dd < bd:
				bd = dd
				nxt = o
		if nxt == null:
			break
		nxt.take_damage(dmg, b)
		_zap_visual(last.center(), nxt.center(), false)
		hit.append(nxt)
		last = nxt
	Sfx.play_any(["combat/tesla_attack", "zap"], b.global_position)


## The lightning itself: sprite effects when there are any, else a jagged line.
func _zap_visual(a: Vector2, b: Vector2, from_tower: bool, jagged := false) -> void:
	var name := "zap_bolt" if from_tower or jagged else "zap_arc"
	if ArtData.EFFECTS.has(name):
		var fx := spawn_effect(name, a.lerp(b, 0.5), 1.6)
		var effs: Dictionary = ArtData.EFFECTS
		var size: Vector2i = effs[name]["size"]
		fx.rotation = (b - a).angle()
		fx.scale = Vector2(a.distance_to(b) / float(size.x), 1.0)
		fx.z_index = 6
	else:
		_bolt_line(a, b)
	if from_tower and ArtData.EFFECTS.has("zap_strike"):
		var st := spawn_effect("zap_strike", a, 1.4)
		var effs2: Dictionary = ArtData.EFFECTS
		st.offset = Vector2(0, -float(effs2["zap_strike"]["size"].y) * 0.5)
		st.z_index = 6
	if ArtData.EFFECTS.has("zap_burst"):
		spawn_effect("zap_burst", b, 1.3).z_index = 6
	else:
		spawn_effect("hit", b, 1.0)


func _bolt_line(a: Vector2, b: Vector2) -> void:
	var pts := [a]
	for i in range(1, 5):
		pts.append(a.lerp(b, i / 5.0) + Vector2(randf_range(-7, 7), randf_range(-7, 7)))
	pts.append(b)
	for i in pts.size() - 1:
		_tracers.append([pts[i], pts[i + 1], 0.12, Color(0.65, 0.85, 1.0, 0.95), 2.0])


func acid_shot(u: Unit, e: Entity, dmg: float) -> void:
	e = intercept(u, e)
	var mouth := u.center() + u.facing * 14.0 + (Vector2(0, -8) if e.is_air() else Vector2.ZERO)
	e.take_damage(dmg, u, Entity.BLOW_RANGED)      # (a glob on one target: a shot)
	e.acid_t = maxf(e.acid_t, float(u.d.get("acid", 3.0)))
	Sfx.play_any(["combat/spitter_attack", "acid"], mouth)
	var s := Shot.new()
	s.arc = 0.18
	s.scale = Vector2(1.3, 1.3)
	s.impact = "acid_splash"
	s.impact_scale = 0.7
	s.launch(self, "acid_ball", mouth, e.center(), 330.0)


func cannon_shot(u: Unit, p: Vector2, dmg: float) -> void:
	var muzzle := u.center() + u.facing * 30.0
	spawn_effect("smoke", muzzle + u.facing * 10.0, 0.8)
	var pr := Projectile.new()
	pr.game = self
	pr.from = muzzle
	pr.to = p + Vector2(randf_range(-14, 14), randf_range(-10, 10))
	pr.duration = clampf(muzzle.distance_to(p) / 520.0, 0.25, 0.8)
	pr.damage = dmg
	pr.splash = float(u.d["splash"])
	pr.round_shot = true
	pr.team = u.team
	pr.shooter = u
	add_child(pr)
	Sfx.play_any(["combat/cannon_attack", "cannon"], u.global_position)


## A round shot lands: everyone in a line from a little before the spot to well past it
## takes the full blow (more against armour); a small splash where it hits.
func round_shot_land(from: Vector2, p: Vector2, dmg: float, t: int, shooter: Entity) -> void:
	var dir := (p - from).normalized()
	var a := p - dir * 30.0
	var b := p + dir * float(Defs.ROUND_SHOT["line"])
	var w := float(Defs.ROUND_SHOT["width"])
	for o in units_near(p + dir * float(Defs.ROUND_SHOT["line"]) * 0.4, float(Defs.ROUND_SHOT["line"]) + 40.0):
		if o == shooter or o.dead or o.is_air() or o.off_field:
			continue
		var q := Geometry2D.get_closest_point_to_segment(o.position, a, b)
		if q.distance_to(o.position) <= o.radius + w:
			var bonus: float = Defs.ROUND_SHOT["vs_armored"] if o.has_tag("armored") else 1.0
			o.take_damage(dmg * bonus, shooter)
	# a building where it lands takes the whole ball
	for bd in buildings.duplicate():
		if not allied(bd.team, t) and not bd.dead and bd.edge_distance(p) < 18.0:
			bd.take_damage(dmg * float(Defs.UNITS["cannon"].get("building_bonus", 1.0)), shooter)
	for i in 3:
		var fx := spawn_effect("dust", p + dir * (25.0 + i * 28.0), 1.4)
		fx.scale = Vector2(0.45, 0.45)
	explode(p, dmg * float(Defs.ROUND_SHOT["splash_dmg"]), float(Defs.ROUND_SHOT["splash"]), t, shooter)


## Area attacks hurt friends too. Before a unit fires one on its own (not on an explicit
## order), it checks who stands in the blast: it holds fire unless the enemies hit clearly
## outweigh the friends.
func aoe_worth_it(u: Unit, e: Entity) -> bool:
	var foes := 0.0
	var friends := 0.0
	var from := u.center()
	var dir := (e.center() - from).normalized()
	var cone := -2.0
	var reach := 0.0
	var at := e.center()
	var r := 0.0
	var seg := false
	var sa := Vector2.ZERO
	var sb := Vector2.ZERO
	match u.kind:
		"cannon":
			if u.mode == "canister":
				cone = float(Defs.CANISTER["cone"])
				reach = float(Defs.CANISTER["range"]) + 30.0
			else:
				# the line the ball ploughs through (as in round_shot_land, a little wider:
				# it lands within ~14 px of where it's aimed)
				var p := e.center()
				var gd := (p - u.center()).normalized()
				sa = p - gd * 30.0
				sb = p + gd * float(Defs.ROUND_SHOT["line"])
				seg = true
				r = float(Defs.ROUND_SHOT["width"]) + 10.0
				at = (sa + sb) * 0.5
		"mortar":
			r = float(u.d["splash"]) + 10.0
			at = e.position if e is Unit else e.center()
		"steam_walker":
			cone = 0.72
			reach = float(u.d["range"]) + 24.0
		"spore_mother":
			r = float(u.d["splash"]) + 8.0
		_:
			return true
	var centre := from if cone > -2.0 else at
	var look := (reach if cone > -2.0 else r) + 24.0
	if seg:
		look = sa.distance_to(sb) * 0.5 + r + 24.0
	for o in units_near(centre, look):
		if o == u or o.dead or o.off_field or o.untouchable():
			continue
		var inside := false
		if seg:
			inside = not o.is_air() and Geometry2D.get_closest_point_to_segment(o.position, sa, sb).distance_to(o.position) <= o.radius + r
		elif cone > -2.0:
			var to: Vector2 = o.center() - from
			inside = to.length() <= reach + o.radius and dir.dot(to.normalized()) > cone and (u.mode == "canister" or not o.is_air())
		else:
			inside = not o.is_air() and o.position.distance_to(at) <= r + o.radius
		if not inside:
			continue
		var w := float(o.d["supply"])
		if hostile(o.team, u.team):
			foes += w
		else:
			friends += w
	return friends == 0.0 or foes >= friends * 2.0


# ------------------------------------------------------------------ new units: blobs and spells

## Spore Mother: a big spit blob lobbed high onto a spot.
func blob_shot(u: Unit, p: Vector2, dmg: float) -> void:
	var mouth := u.center() + Vector2(0, -14)
	var pr := Projectile.new()
	pr.game = self
	pr.from = mouth
	pr.to = p + Vector2(randf_range(-10, 10), randf_range(-8, 8))
	pr.duration = clampf(mouth.distance_to(p) / 300.0, 0.5, 1.2)
	pr.damage = dmg
	pr.splash = float(u.d["splash"])
	pr.blob = true
	pr.team = u.team
	pr.shooter = u
	add_child(pr)
	Sfx.play_any(["combat/spitter_attack", "acid"], mouth)


## The blob bursts: acid over a whole area (less at the edge), and it keeps burning.
func blob_land(p: Vector2, dmg: float, splash: float, t: int, shooter: Entity) -> void:
	var fx := spawn_effect("acid_splash", p, 0.9)
	fx.scale = Vector2(1.8, 1.5)
	for i in 3:
		var f2 := spawn_effect("acid_splash", p + Vector2(randf_range(-splash, splash) * 0.6, randf_range(-splash, splash) * 0.4), 1.2)
		f2.scale = Vector2(0.9, 0.9)
	Sfx.play_any(["combat/spitter_hit", "acid"], p)
	for u in units_near(p, splash + 12.0):
		if u == shooter or u.dead or u.is_air() or u.off_field:
			continue
		var d2: Vector2 = u.position - p
		d2.y /= FIELD_Y
		if d2.length() > splash + u.radius:
			continue
		var f := 1.0 - 0.5 * clampf(d2.length() / splash, 0.0, 1.0)
		u.take_damage(dmg * f, shooter)
		u.acid_t = maxf(u.acid_t, 2.0)
	for b in buildings.duplicate():
		if not allied(b.team, t) and not b.dead and b.edge_distance(p) < splash * 0.5:
			b.take_damage(dmg, shooter)


## Mortar: a shell lobbed high (over men and walls) onto a spot; it bursts where it lands.
func mortar_shot(u: Unit, p: Vector2, dmg: float) -> void:
	var muzzle := u.position + Vector2(0, -26) + u.facing * 10.0
	var pr := Projectile.new()
	pr.game = self
	pr.from = muzzle
	pr.to = p + Vector2(randf_range(-12, 12), randf_range(-8, 8))
	pr.duration = clampf(muzzle.distance_to(pr.to) / float(Defs.MORTAR["speed"]), 0.8, 1.8)
	pr.damage = dmg
	pr.splash = float(u.d["splash"])
	pr.shell = true
	pr.team = u.team
	pr.shooter = u
	add_child(pr)
	var sm := spawn_effect("smoke", muzzle + Vector2(0, -8), 0.9)
	sm.modulate = Color(1, 1, 1, 0.8)
	Sfx.play_any(["combat/mortar_attack", "combat/cannon_attack", "cannon"], u.global_position)


## The shell bursts: every ground unit inside the blast is hurt, friend or foe (less at the
## edge), and enemy buildings close by.
func mortar_land(p: Vector2, dmg: float, splash: float, t: int, shooter: Entity) -> void:
	var name := "mortar_blast" if ArtData.EFFECTS.has("mortar_blast") else "blast"
	var fx := spawn_effect(name, p, 1.0)
	fx.offset = Vector2(0, -float(ArtData.EFFECTS[name]["size"].y) * 0.4)
	fx.scale = Vector2.ONE * (splash / 36.0)
	Sfx.play_any(["combat/mortar_hit", "combat/cannon_hit", "boom"], p)
	var edge := float(Defs.MORTAR["edge"])
	for u in units_near(p, splash + 24.0):
		if u.dead or u.off_field or u.is_air():
			continue
		var dd: float = u.position.distance_to(p)
		if dd > splash + u.radius:
			continue
		u.take_damage(dmg * lerpf(1.0, edge, clampf(dd / splash, 0.0, 1.0)), shooter)
	var bb := float(Defs.UNITS["mortar"].get("building_bonus", 1.0))
	for b in buildings.duplicate():
		if not allied(b.team, t) and not b.dead and b.edge_distance(p) < splash * 0.6:
			b.take_damage(dmg * bb, shooter)


## Spells on the ground for a while: [{kind, pos, r, t, team, age, fx, healed}]
var zones: Array = []


## A Bloater bursts: a little damage where it pops, and an acid cloud that lingers.
func bloat_burst(u: Unit) -> void:
	var p := u.position
	# everything scales with the gas left in the sac: a full one is a huge bomb
	var full := clampf(u.gas / 100.0, 0.15, 1.0)
	var r := float(Defs.BLOAT["radius"]) * (0.5 + 0.5 * full)
	var dmg := float(Defs.BLOAT["burst"]) * full
	for o in units_near(p, r):
		if not o.dead and not o.is_air() and hostile(o.team, u.team):
			o.take_damage(dmg * (1.0 - 0.4 * clampf(o.position.distance_to(p) / r, 0.0, 1.0)), u)
	for b in buildings.duplicate():
		if not b.dead and hostile(b.team, u.team) and b.edge_distance(p) < r * 0.5:
			b.take_damage(dmg * 2.0, u)
	var z := {"kind": "bloat", "pos": p, "team": u.team, "age": 0.0, "fx": null, "stage": "", "caster": u, "healed": {},
		"r": r, "t": float(Defs.BLOAT["time"]) * (0.4 + 0.6 * full)}
	zones.append(z)
	_zone_fx(z, "loop")
	Sfx.play_any(["combat/spitter_hit", "acid"], p)


## A spell's numbers (range, radius, cast time...) and who casts it.
static func spell_info(spell: String) -> Dictionary:
	return {"storm": Defs.STORM, "miasma": Defs.MIASMA, "fog": Defs.FOG}.get(spell, Defs.MIASMA)


const CASTERS := {"storm": "stormcaller", "miasma": "spore_mother", "fog": "mist_toad"}


## Why this unit can't cast that spell now ("" = it can).
func spell_problem(u: Unit, spell: String) -> String:
	if spell == "fog":
		if u.charge < float(Defs.FOG["cost"]):
			return "Not enough energy: FOG needs %d (it fills over time, faster on swamp)." % int(Defs.FOG["cost"])
	elif spell == "storm":
		if u.charge < float(Defs.STORM["cost"]):
			return "Not enough charge: the Stormcaller recharges inside a Clockwork field."
		if energy_stored(u.team) < int(Defs.STORM["cost2"]):
			return "Not enough energy: a storm burns %d stored batteries." % int(Defs.STORM["cost2"])
	elif spell == "miasma":
		if u.spell_cd > 0.0:
			return "Miasma isn't ready yet (%ds)." % int(ceil(u.spell_cd))
		if float(players[u.team]["res2"]) < float(Defs.MIASMA["cost2"]):
			return "Not enough essence."
	return ""


## Infantry climbs into the balloons (each man into the nearest one with room). The balloon
## must hover over ground they can walk to; it stops and comes down while they board.
## Units that can't ride just walk over.
func load_order(riders: Array, balloons: Array) -> void:
	var bs: Array = balloons.filter(func(b) -> bool: return b is Unit and is_instance_valid(b) and not b.dead and b.kind == "balloon")
	if bs.is_empty():
		return
	var why := ""
	var men: Array = riders.filter(func(u) -> bool: return u is Unit and is_instance_valid(u) and not u.dead and u.kind != "balloon")
	men.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(bs[0].position) < b.position.distance_squared_to(bs[0].position))
	for u in men:
		var best: Unit = null
		var bd := INF
		for b in bs:
			if not u.can_board(b) or b.room() <= 0:
				continue
			if not _clear_at(b.position, 8.0, b.team):
				why = "The balloon must hover over open ground to take men aboard."
				continue
			var dd: float = u.position.distance_to(b.position)
			if dd < bd:
				bd = dd
				best = b
		if best:
			if best.order != "idle" and best.order != "hold" and best.incoming.is_empty():
				best.cmd_stop()        # it stops where it is and comes down
			u.cmd_board(best)
		elif not (Defs.DROPSHIP["kinds"] as Array).has(u.kind):
			if why == "" and u.team == human:
				why = "Only Musketeers and Labourers fit in the basket."
		elif why == "" and bs.all(func(b: Unit) -> bool: return b.room() <= 0):
			why = "The basket is full (%d men)." % int(Defs.DROPSHIP["capacity"])
	if why != "" and not men.is_empty() and men[0].team == human:
		notify(why)


## The selected balloons with men aboard fly to `p` and let them off (here: right below).
func unload_order(list: Array, p: Vector2, here := false) -> void:
	var any := false
	for b in list:
		if b is Unit and not b.dead and b.kind == "balloon" and not b.passengers.is_empty():
			b.cmd_unload(b.position if here else p)
			any = true
	if not any and not list.is_empty() and list[0].team == human:
		notify("Nobody aboard.")


## The nearest selected Ornithopter carrying a battery flies over and overloads `e`.
func overload_order(list: Array, e: Entity) -> void:
	if not (e is Unit) or e.dead or e.team != human or e.d["faction"] != "clockwork" or e.is_worker():
		notify("Pick one of your constructs to overload.")
		return
	var best: Unit = null
	var bd := INF
	for u in list:
		if u is Unit and not u.dead and u.kind == "ornithopter" and u.topter_bat != "" and u != e:
			var dd: float = u.position.distance_to(e.position)
			if dd < bd:
				bd = dd
				best = u
	if best:
		best.cmd_overload(e)
		_ping(e.position, Color(1, 0.85, 0.3))
	else:
		notify("No Ornithopter here carries a battery.")


## Open ground around a spot (or as near as there is) for men let off a balloon: one cell
## each, nearest first.
func drop_spots(at: Vector2, n: int, t: int) -> Array:
	var out: Array = []
	var c0 := cell_of(at)
	for r in range(0, 9):
		var ring: Array = []
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if absi(x) != r and absi(y) != r:
					continue
				var c := c0 + Vector2i(x, y)
				if r == 0 and _clear_at(at, 9.0, t):
					ring.append(c)
				elif in_map(c) and passable(c, t) and _clear_at(cell_center(c), 9.0, t):
					ring.append(c)
		ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a - c0).length() < Vector2(b - c0).length())
		for c in ring:
			out.append(cell_center(c) if r > 0 else at)
			if out.size() >= n:
				return out
	while out.size() < n:
		out.append(cell_center(nearest_free(c0, 12)))
	return out


## The selected casters: the nearest one that can cast goes and does it.
func cast_order(list: Array, spell: String, p: Vector2) -> void:
	var kind: String = CASTERS.get(spell, "spore_mother")
	var best: Unit = null
	var bd := INF
	var why := "Nobody here can cast that."
	for u in list:
		if not (u is Unit) or u.dead or u.kind != kind:
			continue
		if u.order == "cast":
			continue           # already busy with one
		var w := spell_problem(u, spell)
		if w != "":
			why = w
			continue
		var dd: float = u.position.distance_to(p)
		if dd < bd:
			bd = dd
			best = u
	if best:
		best.cmd_cast(spell, p)
	elif list.size() > 0 and list[0].team == human:
		notify(why)


func cast_spell(u: Unit, spell: String, p: Vector2) -> void:
	var w := spell_problem(u, spell)
	if w != "":
		if u.team == human:
			notify(w)
		return
	var z := {"kind": spell, "pos": p, "team": u.team, "age": 0.0, "fx": null, "stage": "", "caster": u, "healed": {}}
	if spell == "fog":
		u.charge -= float(Defs.FOG["cost"])
		z["r"] = float(Defs.FOG["radius"])
		z["t"] = float(Defs.FOG["time"])
		z["puffs"] = []
		Sfx.play_any(["combat/steam_walker_attack", "steam"], p)
	elif spell == "storm":
		u.charge -= float(Defs.STORM["cost"])
		spend_batteries(u.team, int(Defs.STORM["cost2"]))
		z["r"] = float(Defs.STORM["radius"])
		z["t"] = float(Defs.STORM["time"])
		Sfx.play_any(["combat/tesla_attack", "zap"], p)
	else:
		players[u.team]["res2"] = float(players[u.team]["res2"]) - float(Defs.MIASMA["cost2"])
		u.spell_cd = float(Defs.MIASMA["cooldown"])
		z["r"] = float(Defs.MIASMA["radius"])
		z["t"] = float(Defs.MIASMA["time"])
		Sfx.play_any(["combat/spitter_attack", "acid"], p)
	zones.append(z)
	_zone_fx(z, "in")
	if mlog:
		var inside := 0
		for o in units_near(p, float(z["r"])):
			if not o.dead and hostile(o.team, u.team):
				inside += 1
		mlog.add("%s cast %s (%d enemies inside)" % [mlog.who(u.team), {"storm": "a storm", "fog": "a fog bank"}.get(spell, "miasma"), inside])


## Show the zone's effect for a stage ("in", "loop", "out"); falls back to sparks when the
## effect art isn't there.
func _zone_fx(z: Dictionary, stage: String) -> void:
	var name: String = ("storm_" if z["kind"] == "storm" else "miasma_") + stage
	if z["kind"] == "bloat":
		name = "bloat_cloud" if stage == "loop" else ""
	if z["kind"] == "fog":
		_fog_fx(z, stage)
		return
	if z["fx"] and is_instance_valid(z["fx"]):
		(z["fx"] as Node).queue_free()
	z["fx"] = null
	z["stage"] = stage
	if name == "" or not ArtData.EFFECTS.has(name):
		return
	var info: Dictionary = ArtData.EFFECTS[name]
	var fx := spawn_effect(name, z["pos"], 1.4 if stage != "loop" else 1.0, stage == "loop")
	var want_w: float = float(z["r"]) * 2.1
	var sc := want_w / maxf(1.0, float(info["size"].x))
	fx.scale = Vector2(sc, sc)
	# the storm lies on the ground under the units it stuns; the cloud drifts over them
	fx.z_index = -1 if z["kind"] == "storm" else 2
	fx.modulate.a = 0.85 if z["kind"] == "storm" else 0.65
	z["fx"] = fx
	z["in_t"] = float(info["frames"]) / 14.0


## Mist Toad's FOG: the miasma cloud turned murky grey-green (a shader greys it), with a
## few smaller banks drifting slowly round inside it.
var _fog_mat: ShaderMaterial


func _fog_material() -> ShaderMaterial:
	if _fog_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
void fragment() {
	vec4 c = COLOR;     // (the texture already multiplied by the modulate)
	float l = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	COLOR = vec4(mix(c.rgb, vec3(l) * vec3(0.74, 0.9, 0.76), 0.82), c.a);
}"""
		_fog_mat = ShaderMaterial.new()
		_fog_mat.shader = sh
	return _fog_mat


func _fog_fx(z: Dictionary, stage: String) -> void:
	if z["fx"] and is_instance_valid(z["fx"]):
		(z["fx"] as Node).queue_free()
	z["fx"] = null
	z["stage"] = stage
	var name := "miasma_" + stage
	if not ArtData.EFFECTS.has(name):
		return
	var info: Dictionary = ArtData.EFFECTS[name]
	var fx := spawn_effect(name, z["pos"], 1.0 if stage == "loop" else 1.2, stage == "loop")
	var sc := float(z["r"]) * 2.3 / maxf(1.0, float(info["size"].x))
	fx.scale = Vector2(sc, sc * 0.9)
	fx.material = _fog_material()
	fx.z_index = 4            # over the units it hides
	fx.modulate.a = 0.72
	z["fx"] = fx
	z["in_t"] = float(info["frames"]) / 12.0
	var puffs: Array = z.get("puffs", [])
	if stage == "in" and puffs.is_empty() and ArtData.EFFECTS.has("bloat_cloud"):
		for i in 4:
			var a := TAU * float(i) / 4.0 + randf() * 0.6
			var pf := spawn_effect("bloat_cloud", z["pos"], 0.5, true)
			pf.material = _fog_material()
			pf.z_index = 4
			pf.modulate.a = 0.0
			pf.scale = Vector2(0.62, 0.42) * randf_range(0.85, 1.1)
			pf.set_meta("ang", a)
			pf.set_meta("spin", randf_range(0.18, 0.3) * (1.0 if i % 2 == 0 else -1.0))
			puffs.append(pf)
		z["puffs"] = puffs
	elif stage == "out":
		for pf in puffs:
			if is_instance_valid(pf):
				var tw := (pf as Node2D).create_tween()
				tw.tween_property(pf, "modulate:a", 0.0, 0.8)
				tw.tween_callback((pf as Node).queue_free)
		z["puffs"] = []


## The fog banks drift slowly round inside the fog.
func _drift_fog(z: Dictionary, delta: float) -> void:
	var p: Vector2 = z["pos"]
	var r: float = z["r"]
	var fade := clampf(float(z["age"]) / 0.8, 0.0, 1.0)
	for pf in z.get("puffs", []):
		if not is_instance_valid(pf):
			continue
		var a := float(pf.get_meta("ang")) + float(pf.get_meta("spin")) * delta
		pf.set_meta("ang", a)
		pf.position = p + Vector2(cos(a), sin(a) * FIELD_Y) * r * 0.48 + Vector2(0, -10)
		pf.modulate.a = 0.5 * fade
	if z["fx"] and is_instance_valid(z["fx"]):
		(z["fx"] as Node2D).position = p + Vector2(sin(float(z["age"]) * 0.7) * 5.0, cos(float(z["age"]) * 0.5) * 3.0)


## Inside a Mist Toad's fog bank?
func in_fog(p: Vector2) -> bool:
	for z in zones:
		if z["kind"] == "fog" and in_ellipse(z["pos"], p, float(z["r"])):
			return true
	return false


## A shot from `u` at `e` is fired from inside a fog bank or into one.
func fog_blinds(u: Entity, e: Entity) -> bool:
	if zones.is_empty() or u == null or e == null:
		return false
	return in_fog(u.global_position) or in_fog(e.global_position if e is Unit else e.center())


## A ranged attack lost in the fog: the shot flies off into the murk and hits nothing.
func fog_miss(u: Unit, e: Entity) -> void:
	var from := u.center() + u.facing * 14.0
	var to := e.center() + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 55.0)
	var sname := "ball"
	var snd: Array = ["combat/musketeer_attack", "musket"]
	match u.kind:
		"spitter", "bloater":
			sname = "acid_ball"
			snd = ["combat/spitter_attack", "acid"]
		"arc_thrower":
			sname = "arc_ball" if ArtData.EFFECTS.has("arc_ball") else "acid_ball"
			snd = ["combat/tesla_attack", "zap"]
		"tesla_cart", "stormcaller", "ornithopter":
			_bolt_line(from, to)
			sname = ""
			snd = ["combat/tesla_attack", "zap"]
		"skywing":
			sname = "bolt" if ArtData.EFFECTS.has("bolt") else "acid_ball"
			snd = ["combat/skywing_attack", "bite"]
		"cannon":
			snd = ["combat/cannon_attack", "cannon"]
			spawn_effect("smoke", from + u.facing * 12.0, 0.9)
		"balloon", "musketeer":
			spawn_effect("smoke", from + u.facing * 8.0, 1.2).scale = Vector2(0.7, 0.7)
	if sname != "":
		var s := Shot.new()
		s.scale = Vector2(0.45, 0.45) if sname == "ball" else Vector2(0.8, 0.8)
		if sname == "ball":
			s.face_offset = PI
		s.impact = "smoke"
		s.impact_scale = 0.35
		s.launch(self, sname, from, to, 700.0)
	Sfx.play_any(snd, u.global_position)
	fog_miss_note(e)


## "miss" over the target now and then, so the fog's work can be seen.
var _miss_note_t := 0.0


func fog_miss_note(e: Entity) -> void:
	if clock < _miss_note_t or not is_instance_valid(e) or not view_rect.has_point(e.global_position):
		return
	_miss_note_t = clock + 0.6
	float_text(e.center() + Vector2(randf_range(-10, 10), -26), "miss", Color(0.75, 0.82, 0.78))


# ------------------------------------------------------------------ Mist Toad: TONGUE

## Mist Toads with their tongue on someone (windup, lash or pull): drawn on the overlay.
var tongues: Array = []


## The selected Toads: the nearest one with the energy goes for `e`.
func tongue_order(list: Array, e) -> void:
	var toads := list.filter(func(u) -> bool: return u is Unit and not u.dead and u.kind == "mist_toad")
	if toads.is_empty():
		return
	if not (e is Unit) or not toads[0].can_tongue(e):
		if toads[0].team == human:
			notify("Pick an enemy unit on the ground (not a building or a flyer).")
		return
	var best: Unit = null
	var bd := INF
	for u in toads:
		if u.tongue_stage != "" or u.charge < float(Defs.TONGUE["cost"]):
			continue
		var dd: float = u.position.distance_to(e.position)
		if dd < bd:
			bd = dd
			best = u
	if best:
		best.cmd_tongue(e)
		_ping(e.position, Color(1.0, 0.45, 0.6))
	elif toads[0].team == human:
		notify("Not enough energy: TONGUE needs %d." % int(Defs.TONGUE["cost"]))


## A Toad has marked its victim: the crosshair goes up (its owner is warned).
func tongue_marked(toad: Unit, e: Unit) -> void:
	if not tongues.has(toad):
		tongues.append(toad)
	if e.team == human:
		notify("A Mist Toad is aiming its tongue at your %s: move it away or stun the Toad!" % String(e.d["name"]), true)
		_ping(e.position, Color(1.0, 0.3, 0.3))
	Sfx.play_any(["combat/spitter_hit", "acid"], toad.position)


## The tongue lands: "Tongue!" over the victim.
func tongue_hit(toad: Unit, e: Unit) -> void:
	var heavy := Unit.too_heavy(e)
	if toad.visible or e.visible or toad.team == human or e.team == human:
		float_text(e.center() + Vector2(0, -30), "Tongue!" if not heavy else "Tongue! (staggered)", Color(1.0, 0.55, 0.7))
	Sfx.play_any(["combat/brute_hit", "combat/spitter_hit", "acid"], e.position)
	spawn_effect("hit", e.center(), 1.0)
	if mlog:
		mlog.add("%s's Mist Toad %s %s's %s" % [mlog.who(toad.team), "staggered" if heavy else "pulled in", mlog.who(e.team), String(e.d["name"])])


## The crosshairs and tongues, over everything.
func _draw_tongues() -> void:
	for toad in tongues.duplicate():
		if not is_instance_valid(toad) or toad.tongue_stage == "":
			tongues.erase(toad)
			continue
		var e = toad.tongue_victim
		if e == null or not is_instance_valid(e):
			continue
		var mine: bool = allied(toad.team, human)
		var theirs: bool = allied(e.team, human)
		if toad.tongue_stage == "windup":
			# the victim's owner (and the Toad's) sees the mark: that's the counterplay
			if not (mine or theirs or demo or reveal):
				continue
			var c: Vector2 = e.center()
			var left: float = toad.tongue_t / float(Defs.TONGUE["windup"])
			var pulse := 0.5 + 0.5 * sin(clock * 10.0)
			var col := Color(1.0, 0.25, 0.3, 0.75 + 0.25 * pulse)
			var rr: float = maxf(14.0, e.radius + 8.0) + 4.0 * left
			var rot := clock * 1.6
			overlay.draw_arc(c, rr, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 4.0)
			overlay.draw_arc(c, rr, 0.0, TAU, 32, col, 2.0)
			for k in 4:
				var a := rot + k * PI * 0.5
				var dir := Vector2.from_angle(a)
				overlay.draw_line(c + dir * (rr - 6.0), c + dir * (rr + 7.0), Color(0, 0, 0, 0.6), 4.0)
				overlay.draw_line(c + dir * (rr - 6.0), c + dir * (rr + 7.0), col, 2.0)
			overlay.draw_circle(c, 2.0, col)
			# how long until it lashes: the arc that's left
			overlay.draw_arc(c, rr + 11.0, -PI * 0.5, -PI * 0.5 + TAU * left, 24, Color(1.0, 0.75, 0.8, 0.9), 2.0)
			if mine:
				# its owner sees the line of aim, faintly
				overlay.draw_dashed_line(toad.mouth_point(), c, Color(1.0, 0.55, 0.7, 0.35), 1.0, 6.0)
			continue
		if not (toad.visible or e.visible):
			continue
		var from: Vector2 = toad.mouth_point()
		var to: Vector2 = e.center()
		if toad.tongue_stage == "lash":
			to = from.lerp(to, 1.0 - clampf(toad.tongue_t / float(Defs.TONGUE["lash"]), 0.0, 1.0))
		elif toad.tongue_stage == "recoil":
			to = from.lerp(to, clampf(toad.tongue_t / 0.15, 0.0, 1.0))
		_draw_tongue(from, to)


## A fleshy pink tongue: a sagging curve with a dark edge and a fat tip.
func _draw_tongue(a: Vector2, b: Vector2) -> void:
	var dist := a.distance_to(b)
	if dist < 2.0:
		return
	var n := (b - a).normalized().orthogonal()
	if n.y < 0.0:
		n = -n
	var ctrl := a.lerp(b, 0.5) + n * minf(dist * 0.18, 26.0)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	overlay.draw_polyline(pts, Color(0.35, 0.08, 0.14), 6.0, true)
	overlay.draw_polyline(pts, Color(0.9, 0.42, 0.55), 3.6, true)
	overlay.draw_polyline(pts.slice(0, 7), Color(1.0, 0.7, 0.78, 0.8), 1.2, true)
	overlay.draw_circle(b, 5.0, Color(0.35, 0.08, 0.14))
	overlay.draw_circle(b, 3.6, Color(0.95, 0.48, 0.6))


func _tick_zones(delta: float) -> void:
	if zones.is_empty():
		return
	var mended := {}       # clouds don't stack: one cloud heals a unit per tick
	for z in zones:
		z["age"] = float(z["age"]) + delta
		var p: Vector2 = z["pos"]
		var r: float = z["r"]
		if z["stage"] == "in" and z["age"] >= float(z.get("in_t", 0.4)):
			_zone_fx(z, "loop")
		if z["kind"] == "fog":
			_drift_fog(z, delta)
			continue
		if z["kind"] == "bloat":
			for u in units_near(p, r + 20.0):
				if u.dead or u.off_field or u.is_air() or not hostile(u.team, int(z["team"])) or not in_ellipse(p, u.position, r + u.radius):
					continue
				u.acid_t = maxf(u.acid_t, 0.4)
				u.slow_t = maxf(u.slow_t, 0.4)
				u.take_damage(float(Defs.BLOAT["dps"]) * delta, null)
			continue
		if z["kind"] == "storm":
			for u in units_near(p, r + 20.0):
				if u.dead or u.off_field or not in_ellipse(p, u.position, r + u.radius):
					continue
				u.stun_t = maxf(u.stun_t, 0.2)
				u.phase = ""
				var c = z["caster"]
				if u != c and float(Defs.STORM["dps"]) > 0.0:
					u.take_damage(float(Defs.STORM["dps"]) * delta, c if is_instance_valid(c) else null)
			z["bolt_t"] = float(z.get("bolt_t", 0.0)) - delta
			if z["bolt_t"] <= 0.0:
				z["bolt_t"] = 0.18
				var a := randf() * TAU
				var q := p + Vector2(cos(a), sin(a) * FIELD_Y) * r * sqrt(randf())
				if ArtData.EFFECTS.has("zap_strike"):
					var fx := spawn_effect("zap_strike", q, 1.6)
					var sinfo: Dictionary = ArtData.EFFECTS["zap_strike"]
					fx.offset = Vector2(0, -float(sinfo["size"].y) * 0.45)
				else:
					spawn_effect("hit", q, 1.0)
		else:
			for u in units_near(p, r + 20.0):
				if u.dead or not allied(u.team, int(z["team"])) or u.d["faction"] != "brood" or u.hp >= u.max_hp:
					continue
				if mended.has(u) or not in_ellipse(p, u.position, r + u.radius):
					continue
				var done: float = z["healed"].get(u, 0.0)
				var cap: float = u.max_hp * float(Defs.MIASMA["cap"])
				if done >= cap:
					continue
				var h := minf(float(Defs.MIASMA["hps"]) * delta, cap - done)
				u.hp = minf(u.max_hp, u.hp + h)
				z["healed"][u] = done + h
				mended[u] = true
	for z in zones.duplicate():
		if float(z["age"]) >= float(z["t"]):
			_zone_fx(z, "out")
			var fx = z["fx"]
			if fx and is_instance_valid(fx):
				(fx as Effect).loop = false
			zones.erase(z)


## Spots spread evenly along a drawn line, one per unit.
func line_spots(pts: PackedVector2Array, n: int) -> Array:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var out: Array = []
	for k in n:
		var want := total * (float(k) + 0.5) / float(n) if n > 1 else total
		var seg := 1
		var acc := 0.0
		while seg < pts.size() - 1 and acc + pts[seg - 1].distance_to(pts[seg]) < want:
			acc += pts[seg - 1].distance_to(pts[seg])
			seg += 1
		var l := pts[seg - 1].distance_to(pts[seg])
		var f := clampf((want - acc) / maxf(l, 0.001), 0.0, 1.0)
		out.append(pts[seg - 1].lerp(pts[seg], f))
	return out


## Line move: every selected unit takes its own spot along the line. Units are matched to
## spots in order along the line, so their paths don't cross.
func line_move(list: Array, pts: PackedVector2Array, attack: bool, queued := false) -> void:
	var us: Array = list.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead)
	if us.is_empty() or pts.size() < 2:
		return
	var spots := line_spots(pts, us.size())
	var dir := (pts[pts.size() - 1] - pts[0]).normalized()
	us.sort_custom(func(a: Unit, b: Unit) -> bool: return a.plan_end().dot(dir) < b.plan_end().dot(dir))
	for i in us.size():
		var u: Unit = us[i]
		u.give({"o": "amove" if attack else "move", "p": spots[i]}, queued)
	_ping(pts[pts.size() - 1], Color(1, 0.4, 0.3) if attack else Color(0.4, 1, 0.4))


func explode(p: Vector2, dmg: float, splash: float, t: int, shooter: Entity) -> void:
	match randi() % 3:
		0:
			spawn_effect("blast", p, 1.0)
		1:
			spawn_effect("explosion", p, 1.8).scale = Vector2(0.8, 0.8)
		_:
			spawn_effect("burst", p, 1.3)
	if randf() < 0.5:
		var sm := spawn_effect("smoke_big", p + Vector2(0, -6), 1.2)
		sm.scale = Vector2(0.6, 0.6)
		sm.modulate.a = 0.7
	Sfx.play_any(["combat/cannon_hit", "boom"], p)
	for u in units_near(p, splash + 12.0):
		if u != shooter and not u.dead and not u.off_field:
			var f := 1.0 - 0.5 * clampf(u.position.distance_to(p) / splash, 0.0, 1.0)
			u.take_damage(dmg * f, shooter)
	for b in buildings.duplicate():
		if not allied(b.team, t) and not b.dead and b.edge_distance(p) < splash * 0.6:
			b.take_damage(dmg * 2.5, shooter)


## Black powder going up (a keg, a Powder Wagon; later keg mines): a blast that hurts every
## ground unit inside it, friend or foe, less at the edge, and enemy buildings close by.
func powder_blast(src: Entity, p: Vector2, dmg: float, r: float, big := false) -> void:
	var name := "keg_mine_blast" if ArtData.EFFECTS.has("keg_mine_blast") else "blast"
	var fx := spawn_effect(name, p, 1.0)
	var sc := r / (40.0 if big else 30.0)
	fx.scale = Vector2(sc, sc)
	fx.offset = Vector2(0, -float(ArtData.EFFECTS[name]["size"].y) * 0.4)
	if big:
		spawn_effect("explosion", p + Vector2(0, -10), 1.4).scale = Vector2(2.2, 2.2)
		for i in 4:
			var a := TAU * i / 4.0 + randf() * 0.6
			spawn_effect("explosion", p + Vector2(cos(a), sin(a) * 0.6) * r * 0.45, randf_range(1.0, 1.3)).scale = Vector2(1.2, 1.2)
		for i in 6:
			var sm := spawn_effect("smoke_big", p + Vector2(randf_range(-r, r) * 0.6, randf_range(-30, 10)), 0.8)
			sm.scale = Vector2(1.3, 1.3)
			sm.modulate.a = 0.8
		Sfx.play_any(["combat/mortar_hit", "combat/cannon_hit", "boom"], p)
	Sfx.play_any(["combat/cannon_hit", "boom"], p)
	for u in units_near(p, r + 24.0):
		if u == src or u.dead or u.off_field or u.is_air():
			continue
		var dd: float = u.position.distance_to(p)
		if dd > r + u.radius:
			continue
		u.take_damage(dmg * (1.0 - (0.3 if big else 0.5) * clampf(dd / r, 0.0, 1.0)), src)
	for b in buildings.duplicate():
		if not allied(b.team, src.team) and not b.dead and b.edge_distance(p) < r * 0.5:
			b.take_damage(dmg, src)


## A Powder Wagon on SUPPLY wants kegs: up to WAGON.runners labourers (idle or working,
## those grinding at the mill last) run them from the nearest Powder Mill.
func call_runners(w: Unit) -> void:
	if w.max_powder() - w.powder < float(Defs.WAGON["keg"]):
		return
	if w._powder_building() != null:
		return                         # (by a Mill, Barracks or Hall it fills by itself)
	var have := 0
	for u in units:
		if u.team == w.team and not u.dead and u.order == "keg" and u.order_target == w:
			have += 1
	if have >= int(Defs.WAGON["runners"]):
		return
	if nearest_of(w.position, w.team, "powder_mill") == null:
		return
	# who goes: idle labourers first, nearest the wagon; with none idle, men taken off the
	# work the side can best spare: the farms or the mills, whichever resource is better
	# off counting what's banked and what comes in a minute (powder worth 3 gold)
	var spare := _spare_job(w.team)
	for i in int(Defs.WAGON["runners"]) - have:
		var best: Unit = null
		var bd := INF
		for u in units:
			if u.team != w.team or u.dead or u.off_field or u.kind != "labourer" or u.keg \
					or not ((u.order == "idle" and u.auto_work) or u.order == "gather"):
				continue
			var dd: float = u.position.distance_to(w.position)
			if u.order == "gather":
				var job: String = (u.home_mine as Building).kind if u.home_mine is Building else ""
				dd += 2000.0 if job == spare else 6000.0
			if dd < bd:
				bd = dd
				best = u
		if best == null:
			return
		best.cmd_keg(w)


## Which labourers' work a side can best spare for a while: "farm" (gold) or
## "powder_mill" (powder), whichever resource is better off, bank plus a minute's income.
func _spare_job(t: int) -> String:
	var r := income_rates(t)
	var gold := float(players[t]["gold"]) + r.x * 60.0
	var powder := (float(players[t]["res2"]) + r.y * 60.0) * 3.0
	return "farm" if gold >= powder else "powder_mill"


var _income_log := {}                    # team -> [[clock, gold earned, res2 earned], ...]


## A side's income, gold and second resource a second, over about the last minute.
func income_rates(t: int) -> Vector2:
	var log: Array = _income_log.get(t, [])
	var now := [clock, float(stats[t]["gold"]), float(stats[t]["res2_in"])]
	if log.is_empty() or clock - float(log.back()[0]) >= 5.0:
		log.append(now)
		while log.size() > 13:
			log.pop_front()
		_income_log[t] = log
	var first: Array = log[0]
	var dt: float = maxf(clock - float(first[0]), 1.0)
	return Vector2((float(now[1]) - float(first[1])) / dt, (float(now[2]) - float(first[2])) / dt)


func spawn_effect(name: String, p: Vector2, speed := 1.0, looping := false) -> Effect:
	var e := Effect.new()
	e.setup(name, speed, looping)
	e.position = p
	e.z_index = 3
	add_child(e)
	return e


# ------------------------------------------------------------------ fog of war

var _fog_bytes := PackedByteArray()


func _init_fog() -> void:
	fog_img = Image.create(W, H, false, Image.FORMAT_LA8)
	fog_tex = ImageTexture.create_from_image(fog_img)
	fog_sprite.texture = fog_tex
	_update_vis()


func _disk(r: int) -> Array:
	if not _disk_cache.has(r):
		var lst: Array = []
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if x * x + y * y <= r * r + r:
					lst.append(Vector2i(x, y))
		_disk_cache[r] = lst
	return _disk_cache[r]


## (Each grid is taken out of its list while it's written: a copy still held by the list
## would make every write copy the whole grid first, and on a big map that adds up.)
func _reveal(t: int, c: Vector2i, r: int) -> void:
	var v: PackedByteArray = vis[t]
	vis[t] = _EMPTY
	var sd: int = sides[t]
	var sv: PackedByteArray = _side_vis[sd]
	_side_vis[sd] = _EMPTY
	var mine := allied(t, human)
	var low := in_map(c) and height[idx(c)] == 0
	_stamp(v, sv, c, r, low, mine)
	vis[t] = v
	_side_vis[sd] = sv
	if demo:
		_explore(t, c, r, low)


## Demo: what this player has explored, for when the spectator looks through its eyes
## (the same cells _reveal / _reveal_air just lit).
func _explore(t: int, c: Vector2i, r: int, low: bool) -> void:
	var ex: PackedByteArray = explored_by[t]
	explored_by[t] = _EMPTY
	for o in _disk(r):
		var cc: Vector2i = c + o
		if cc.x >= 0 and cc.y >= 0 and cc.x < W and cc.y < H:
			var i := cc.y * W + cc.x
			if low and height[i] == 1 and o.length_squared() > 2:
				continue
			ex[i] = 1
	explored_by[t] = ex


## The cells of a disk of radius r as (dx, dy, far) triples; far = 1 beyond the cells
## right next to the middle (those are seen even up a cliff).
var _disk_ofs := {}


## Mark a disk of cells seen in the team's and its side's grid (and explored, on your side).
## Seen from low ground, high ground is hidden beyond the next cells. (The disk as flat
## int offsets, and no bounds tests when it lies inside the map: this runs for every unit
## and building four times a second.)
func _stamp(v: PackedByteArray, sv: PackedByteArray, c: Vector2i, r: int, low: bool, mine: bool) -> void:
	if not _disk_ofs.has(r):
		var ofs := PackedInt32Array()
		for o in _disk(r):
			ofs.append(o.x)
			ofs.append(o.y)
			ofs.append(1 if o.length_squared() > 2 else 0)
		_disk_ofs[r] = ofs
	var d: PackedInt32Array = _disk_ofs[r]
	var inside := c.x - r >= 0 and c.y - r >= 0 and c.x + r < W and c.y + r < H
	var n := d.size()
	var k := 0
	var w := W
	var h := H
	while k < n:
		var x := c.x + d[k]
		var y := c.y + d[k + 1]
		if inside or (x >= 0 and y >= 0 and x < w and y < h):
			var i := y * w + x
			if not (low and d[k + 2] == 1 and height[i] == 1):
				v[i] = 1
				sv[i] = 1
				if mine:
					explored[i] = 1
		k += 3


var _EMPTY := PackedByteArray()          # (a stand-in while a grid is out being written)
var _side_vis := {}                      # side -> what all its players see (filled with vis)


## What the buildings see (they don't move): worked out again only when a building is
## added, finished, lost or changes, and copied in at the start of every update.
var _bvis: Array = []                    # per team
var _bside := {}                         # per side
var _bvis_key := PackedInt64Array()


func _building_vis() -> void:
	var key := PackedInt64Array()
	for b in buildings:
		if not b.dead and not b.ghost:
			var c := cell_of(b.rect().get_center())
			key.append(b.get_instance_id())
			key.append(((b.team + 1) * 4096 + b.sight) * 1048576 + c.y * W + c.x)
	if key == _bvis_key and _bvis.size() == n_players():
		return
	_bvis_key = key
	_bvis.clear()
	for t in n_players():
		var nb := PackedByteArray()
		nb.resize(W * H)
		_bvis.append(nb)
	_bside.clear()
	for t in n_players():
		if not _bside.has(sides[t]):
			var nb := PackedByteArray()
			nb.resize(W * H)
			_bside[sides[t]] = nb
	for b in buildings:
		if not b.dead and not b.ghost:
			var c := cell_of(b.rect().get_center())
			var t: int = b.team
			if t < 0:
				continue
			var v: PackedByteArray = _bvis[t]
			_bvis[t] = _EMPTY
			var sv: PackedByteArray = _bside[sides[t]]
			_bside[sides[t]] = _EMPTY
			_stamp(v, sv, c, b.sight, in_map(c) and height[idx(c)] == 0, allied(t, human))
			_bvis[t] = v
			_bside[sides[t]] = sv
			if demo:
				_explore(t, c, b.sight, in_map(c) and height[idx(c)] == 0)


func _update_vis() -> void:
	_building_vis()
	for t in n_players():
		vis[t] = (_bvis[t] as PackedByteArray).duplicate()
	for t in n_players():
		_side_vis[sides[t]] = (_bside[sides[t]] as PackedByteArray).duplicate()
	for sd in _side_vis.keys():
		if not _bside.has(sd):
			_side_vis.erase(sd)
	# units standing in the same cell see the same thing: stamp each spot once
	var done := {}
	for u in units:
		if not u.dead and not u.off_field and u.team >= 0:      # (a loose horse is nobody's eyes)
			var c := cell_of(u.position)
			var key: int = ((u.team * 64 + u.sight) * 2 + int(u.is_air())) * 1048576 + c.y * W + c.x
			if done.has(key):
				continue
			done[key] = true
			if u.is_air():
				_reveal_air(u.team, c, u.sight)
			else:
				_reveal(u.team, c, u.sight)
	# (the buildings' sight came in with _building_vis)
	# what your side sees (the explored map was marked as it was seen)
	var hv: PackedByteArray = (_side_vis[sides[human]] as PackedByteArray).duplicate()
	_human_vis = hv
	if demo:
		# enemy buildings stay on screen once spotted: remember who has spotted each one
		for b in buildings:
			if not b.dead and not b.ghost:
				var bi := idx(cell_of(b.rect().get_center()))
				for t in n_players():
					if vis[t][bi] == 1:
						b.seen_mask |= 1 << t
	if sees_all():
		fog_sprite.visible = false
		for u in units:
			u.visible = not u.off_field
		for b in buildings:
			b.visible = true
		for c in crates:
			c.visible = true
		return
	fog_sprite.visible = true
	# whose eyes: yours, or (watching computers) the player the spectator picked, with
	# everything their side sees and has explored, exactly as you'd see it on that side
	var ft := fog_team()
	var ex := explored
	if ft != human:
		hv = (_side_vis[sides[ft]] as PackedByteArray).duplicate()
		ex = (explored_by[ft] as PackedByteArray).duplicate()
		for o in n_players():
			if o != ft and allied(o, ft):
				var oe: PackedByteArray = explored_by[o]
				for i in W * H:
					if oe[i] == 1:
						ex[i] = 1
	if _fog_bytes.size() != W * H * 2:
		_fog_bytes.resize(W * H * 2)
	for i in W * H:
		_fog_bytes[i * 2 + 1] = 0 if hv[i] == 1 else (140 if ex[i] == 1 else 250)
	fog_img.set_data(W, H, false, Image.FORMAT_LA8, _fog_bytes)
	fog_tex.update(fog_img)
	var side_mask := 0
	for o in n_players():
		if allied(o, ft):
			side_mask |= 1 << o
	for u in units:
		if not allied(u.team, ft):
			u.visible = hv[idx(cell_of(u.position))] == 1 and not u.off_field
		elif demo:
			u.visible = not u.off_field     # (the side looked through before may have been hidden)
	for c in crates:
		if not allied(c.team, ft):
			c.visible = hv[idx(cell_of(c.position))] == 1
		elif demo:
			c.visible = true
	for b in buildings:
		if not allied(b.team, ft):
			if b.ghost:
				b.visible = false            # another side's planned site: unseen
				continue
			if demo:
				b.visible = (b.seen_mask & side_mask) != 0
				continue
			if not b.seen_by_human:
				var cc := cell_of(b.rect().get_center())
				if hv[idx(cc)] == 1:
					b.seen_by_human = true
			b.visible = b.seen_by_human
		elif demo:
			b.visible = true


## Whose fog of war is drawn: yours, or in a computers-only match the player the
## spectator looks through (-1: none, all vision).
func fog_team() -> int:
	return view_team if demo else human


## No fog drawn at all (the sandbox's FOG: OFF, or watching with all vision).
func sees_all() -> bool:
	return reveal or fog_team() < 0


## Redraw the fog now (after the spectator switches whose eyes it uses).
func refresh_fog() -> void:
	_vis_t = 0.25
	_update_vis()


func _reveal_air(t: int, c: Vector2i, r: int) -> void:
	var v: PackedByteArray = vis[t]
	vis[t] = _EMPTY
	var sd: int = sides[t]
	var sv: PackedByteArray = _side_vis[sd]
	_side_vis[sd] = _EMPTY
	var mine := allied(t, human)
	_stamp(v, sv, c, r, false, mine)
	vis[t] = v
	_side_vis[sd] = sv
	if demo:
		_explore(t, c, r, false)


func on_high(p: Vector2) -> bool:
	var c := cell_of(p)
	return in_map(c) and height[idx(c)] == 1


var _human_vis := PackedByteArray()
var body_bars: Node2D
var bodies: Array = []                   # the fallen still lying there (Unit._rest_in_peace)
var _body_bar_t := 0.0


## Over every body still lying on the field, a thin bar running down to the moment it
## fades away (for everyone, where they can see).
func _draw_body_bars() -> void:
	var now := clock
	for b in bodies:
		if not is_instance_valid(b) or not b.visible or b.modulate.a < 0.99 or not view_rect.has_point(b.position):
			continue
		var f := clampf(1.0 - (now - float(b.rip_from)) / maxf(float(b.rip_len), 0.1), 0.0, 1.0)
		var w := 12.0
		var p: Vector2 = b.position + Vector2(-w * 0.5, -16.0)
		body_bars.draw_rect(Rect2(p, Vector2(w, 1.5)).grow(0.5), Color(0, 0, 0, 0.45))
		body_bars.draw_rect(Rect2(p, Vector2(w * f, 1.5)), Color(0.85, 0.82, 0.72, 0.6))


var view_rect := Rect2()                 # what the camera sees (a bit bigger), for culling


## Can side `t` see this target (to shoot at it from `from`)? A unit: where it stands. A
## building: its centre or the part of it nearest the shooter.
func target_seen(t: int, e: Entity, from: Vector2) -> bool:
	if e is Building:
		var r: Rect2 = (e as Building).rect()
		var near := Vector2(clampf(from.x, r.position.x + 2.0, r.end.x - 2.0), clampf(from.y, r.position.y + 2.0, r.end.y - 2.0))
		return side_sees(t, r.get_center()) or side_sees(t, near)
	return side_sees(t, e.position)


## Anyone on this player's side sees it.
func side_sees(t: int, p: Vector2) -> bool:
	var i := idx(cell_of(p))
	for o in n_players():
		if allied(o, t) and vis[o][i] == 1:
			return true
	return false


func is_visible_to(t: int, p: Vector2) -> bool:
	if t == human and not _human_vis.is_empty():
		return _human_vis[idx(cell_of(p))] == 1
	return vis[t][idx(cell_of(p))] == 1


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	var _p0 := Time.get_ticks_usec()
	_tick_game(delta)
	Prof.add("game", _p0)


func _tick_game(delta: float) -> void:
	if over or edit_mode:
		return
	clock += delta
	alert_t = maxf(alert_t - delta, 0.0)
	_body_bar_t -= delta
	if _body_bar_t <= 0.0 and body_bars:
		_body_bar_t = 0.2
		bodies = bodies.filter(func(b) -> bool: return is_instance_valid(b) and b.dead)
		body_bars.queue_redraw()
		for t in n_players():
			income_rates(t)            # (keeps each side's income log going)
	var vsz := get_viewport().get_visible_rect().size / camera.zoom
	view_rect = Rect2(camera.get_screen_center_position() - vsz * 0.5, vsz).grow(120.0)
	_economy(delta)
	_horse_res_tick(delta)
	for fl in _floats:
		fl[3] -= delta
		fl[0] += Vector2(0, -18) * delta
	_floats = _floats.filter(func(fl: Array) -> bool: return fl[3] > 0.0)
	_sample_t += delta
	if _sample_t >= 5.0:
		_sample_t = 0.0
		_sample_stats()
	var pt := Time.get_ticks_usec()
	_rebuild_hash()
	Prof.add("game/unit grid", pt)
	if _astar_dirty:
		_astar_dirty = false
	# Path budget per frame
	pt = Time.get_ticks_usec()
	var budget := 24
	while budget > 0 and not _path_queue.is_empty():
		var u = _path_queue.pop_front()
		if is_instance_valid(u) and not u.dead:
			u.compute_path()
			budget -= 1
	Prof.add("game/paths", pt)
	_tick_zones(delta)
	_swamp_t -= delta
	if swamp_dirty and _swamp_t <= 0.0:
		_swamp_t = 0.5
		_update_swamp()
	_vis_t -= delta
	if _vis_t <= 0.0:
		_vis_t = 0.25
		pt = Time.get_ticks_usec()
		_update_vis()
		Prof.add("game/fog", pt)
	for pg in _pings:
		pg[2] -= delta
	_pings = _pings.filter(func(pg: Array) -> bool: return pg[2] > 0.0)
	for tr in _tracers:
		tr[2] -= delta
	_tracers = _tracers.filter(func(tr: Array) -> bool: return tr[2] > 0.0)
	overlay.queue_redraw()
	field_layer.queue_redraw()
	_end_t -= delta
	if _end_t <= 0.0:
		_end_t = 1.0
		_check_end()
	_refit_t -= delta
	if _refit_t <= 0.0:
		_refit_t = float(Defs.REFIT["scan"])
		pt = Time.get_ticks_usec()
		_auto_refit()
		Prof.add("game/refit", pt)


## A player with no buildings left is out; the match ends when one side is left
## (or, when you're playing, when you're out).
func _check_end() -> void:
	var alive: Array = []
	alive.resize(n_players())
	alive.fill(0)
	for b in buildings:
		if not b.dead and not b.ghost and b.team >= 0:
			alive[b.team] += 1
	for t in n_players():
		if alive[t] == 0 and not eliminated[t]:
			eliminated[t] = true
			for b in buildings.duplicate():
				if b.team == t and b.ghost:
					remove_ghost(b)
			for u in units:
				if u.team == t and not u.dead:
					u.last_blow = ""         # (beaten: no horse bolts)
					u.die()
			if t != human and not demo and n_players() > 2:
				notify("%s is defeated!" % team_name(t).capitalize(), true)
			if mlog:
				mlog.add("%s is out" % mlog.who(t))
	var sides_left := {}
	for t in n_players():
		if not eliminated[t]:
			sides_left[sides[t]] = t
	var human_out: bool = not demo and eliminated[human]
	if sides_left.size() <= 1 or human_out:
		over = true
		winner = -1
		for t in sides_left.values():
			if winner < 0 or (human_out and not allied(t, human)):
				winner = t
		ended.emit(winner)


# ------------------------------------------------------------------ selection & commands (used by input and HUD)

func set_selection(list: Array) -> void:
	# a unit or building you pick answers you (once per new pick)
	for e in list:
		if is_instance_valid(e) and (e is Unit or e is Building) and e.team == human and not e.dead and not selection.has(e):
			if e is Building:
				Sfx.building_selected(e.kind, e.d["faction"])
			else:
				Sfx.voice(e.kind, "select")
			break
	for e in selection:
		if is_instance_valid(e):
			e.selected = false
	selection = []
	for e in list:
		if is_instance_valid(e) and not e.dead and not e.off_field:
			e.selected = true
			selection.append(e)


## APM (actions per minute) of the player at this screen: every click, tap and key press
## during the match counts as one action, as in StarCraft.
var actions: Array = []          # game-clock times of your actions in the last minute
var actions_total := 0
var actions_minute := 0          # actions since the last per-minute log line
var apm_peak := 0

var apm_minutes: Array = []      # actions in each whole minute of the match, in order (the log's peaks and lows)
var _burst: Array = []           # action times in the last 10 s
var burst_best := 0              # most actions in any 10 s, and when that burst ended
var burst_at := 0.0

func note_action() -> void:
	actions.append(clock)
	actions_total += 1
	actions_minute += 1
	_burst.append(clock)
	while not _burst.is_empty() and clock - float(_burst[0]) > 10.0:
		_burst.pop_front()
	if _burst.size() > burst_best:
		burst_best = _burst.size()
		burst_at = clock


## Your APM over the last minute (scaled up while the match is younger than a minute).
func apm() -> int:
	while not actions.is_empty() and clock - float(actions[0]) > 60.0:
		actions.pop_front()
	var span := minf(maxf(clock, 10.0), 60.0)
	var v := int(round(actions.size() * 60.0 / span))
	apm_peak = maxi(apm_peak, v) if clock >= 60.0 else apm_peak
	return v


## Your average APM over the whole match.
func apm_average() -> int:
	return int(round(actions_total * 60.0 / maxf(clock, 1.0)))


## Watching computers play: the only time the spectator tools (VIEW, PRODUCTION, other
## players' resources, queues and rally points, their fog) exist. Never while you play a
## side, so they can never be used against an opponent.
func spectating() -> bool:
	return demo and spectator != null


## The team your orders go to: none while watching computers play (you can select and
## read anything, but never command it).
func controlled_team() -> int:
	return -1 if demo else human


func selected_units() -> Array:
	var me := controlled_team()
	return selection.filter(func(e: Entity) -> bool: return e is Unit and not e.dead and e.team == me)


## The selected building, or the first of several of the same kind (they act together:
## training goes to whichever is least busy, rally points go to all of them).
func selected_building() -> Building:
	var bs := selected_buildings()
	return bs[0] if not bs.is_empty() else null


func selected_buildings() -> Array:
	var me := controlled_team()
	if selection.is_empty() or not (selection[0] is Building) or selection[0].team != me:
		return []
	var k: String = selection[0].kind
	for e in selection:
		if not (e is Building) or e.team != me or e.kind != k or e.dead:
			return []
	return selection.duplicate()


## The damaged building (or construct) of a team that a REPAIR tap at p means: the one under
## the finger, else the most damaged of its finished buildings within 3 tiles (walls are small).
func repair_target_near(p: Vector2, t: int, exclude: Entity = null) -> Entity:
	var e := entity_at(p, false)
	if e and e != exclude and e.team == t and not e.dead and e.hp < e.max_hp and (e.is_unit() or (e as Building).built):
		return e
	var best: Entity = null
	var bf := 1.0
	for b in buildings:
		if b == exclude or b.team != t or b.dead or not b.built or b.hp >= b.max_hp:
			continue
		if b.edge_distance(p) > 3.0 * T:
			continue
		var f: float = b.hp / b.max_hp
		if f < bf:
			bf = f
			best = b
	return best


## Several of your finished buildings that train an army, of different kinds (the MAKE
## quick button), or [] when the selection is anything else.
func selected_producers() -> Array:
	if selection.size() < 2:
		return []
	for e in selection:
		if not (e is Building) or e.team != controlled_team() or e.dead or not e.built or (e.d["trains"] as Array).is_empty():
			return []
	return selection.duplicate()


## Every finished building of a team that trains fighting units.
func producers(t: int) -> Array:
	return buildings.filter(func(b: Building) -> bool:
		return b.team == t and not b.dead and b.built and (b.d["trains"] as Array).any(func(k: String) -> bool: return not Defs.UNITS[k].get("worker", false)))


## The buildings a rally order goes to: the selected ones of one kind, or a MAKE selection.
func rally_buildings() -> Array:
	var bs := selected_buildings()
	return bs if not bs.is_empty() else selected_producers()


## Train at the least busy of several buildings (or the only one).
func train_any(list: Array, k: String) -> String:
	var best: Building = null
	var why := "Can't train that here."
	for b in list:
		if not is_instance_valid(b) or b.dead:
			continue
		var w := can_train(b, k)
		if w != "":
			why = w
			continue
		if best == null or b.queue.size() < best.queue.size() or (b.uses_eggs() and b.eggs > best.eggs):
			best = b
	if best == null:
		return why
	return train(best, k)


## Cancel a building that isn't finished: most of its cost comes back.
func abandon(b: Building) -> void:
	if b.built or b.dead:
		return
	if b.ghost:
		# it never began: all of it comes back
		players[b.team]["gold"] += int(b.d["cost"])
		stats[b.team]["spent"] -= int(b.d["cost"])
		stats[b.team]["built"] = maxi(0, int(stats[b.team]["built"]) - 1)
		remove_ghost(b)
		for u in units.duplicate():
			if u.team == b.team and not u.dead and u.order == "build" and u.order_target == b:
				u.site_gone()
		return
	players[b.team]["gold"] += int(int(b.d["cost"]) * 0.75)
	b.take_damage(9999999.0, null)
	if b.crate_obj and is_instance_valid(b.crate_obj):
		b.crate_obj.remove()            # (a Clockwork crate waiting for this site goes too)


## Pull down a finished building of your own (nothing comes back).
func demolish(b: Building) -> void:
	if b.dead:
		return
	b.take_damage(9999999.0, null)


## Tap/right-click on the map with units selected: do the obvious thing.
## queued (Shift on a computer): after the orders they already have, not instead of them.
func smart_command(list: Array, p: Vector2, force_move := false, queued := false) -> void:
	var us: Array = list.filter(func(e: Entity) -> bool: return e is Unit and not e.dead)
	if not us.is_empty() and us[0].team == human:
		var tgt := entity_at(p)
		Sfx.voice(us[0].kind, "attack" if tgt and hostile(tgt.team, human) and not force_move else "move")
	if us.is_empty():
		return
	var e := null if force_move else entity_at(p)
	# a crate on the ground: Winders of its side carry it on (the nearest one), enemies smash it
	var cr: Crate = null
	if not force_move and not (e is Unit):
		cr = crate_at(p)
	if cr and cr.team == us[0].team and us.any(func(u: Unit) -> bool: return u.kind == "winder"):
		var winders: Array = us.filter(func(u: Unit) -> bool: return u.kind == "winder")
		winders.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(cr.position) < b.position.distance_squared_to(cr.position))
		winders[0].give({"o": "build", "e": cr.site}, queued)
		cr.claimed = winders[0]
		for u in us:
			if u != winders[0]:
				u.give({"o": "move", "p": p}, queued)
		_ping(p, Color(1, 0.85, 0.3))
		return
	if cr and hostile(cr.team, us[0].team):
		e = cr
	# a right click on a Farm's fields (Pit, Boiler...) usually lands on one of the men
	# working it: workers sent there go to work the farm, not to that man
	if e is Unit and e.team == us[0].team and us.any(func(u: Unit) -> bool: return u.can_gather()) \
			and not (e.hp < e.max_hp and us.any(func(u: Unit) -> bool: return u.can_repair(e))):
		var site := crew_site_at(p, us[0].team)
		if site:
			e = site
	# horses: men right-clicking one of ours lead it (Labourers, Winders) or mount it
	# (soldiers); a gun without its horse gets one hitched; horses sent to a building stand by it
	if _horse_command(us, e, p, queued):
		return
	# infantry sent to one of our balloons: they climb in
	if e is Unit and e.kind == "balloon" and e.team == us[0].team and us.any(func(u: Unit) -> bool: return u.can_board(e)):
		load_order(us, [e])
		_ping(p, Color(0.4, 1, 0.4))
		return
	if e is Building and e.team == us[0].team and e.built and int(e.d.get("crew", 0)) > 0 \
			and us.any(func(u: Unit) -> bool: return u.can_gather()):
		for u in us:
			if u.can_gather():
				u.give({"o": "gather", "e": e}, queued)
			else:
				u.give({"o": "move", "p": p}, queued)
		_ping(p, Color(1, 0.85, 0.3))
		return
	if e and e.team == us[0].team and e.hp < e.max_hp and (e.is_unit() or e.built) \
			and us.any(func(u: Unit) -> bool: return u.can_repair(e)):
		for u in us:
			if u.can_repair(e):
				u.give({"o": "repair", "e": e}, queued)
			else:
				u.give({"o": "move", "p": p}, queued)
		_ping(p, Color(0.95, 0.7, 0.25))
		return
	if e is Building and e.team == us[0].team and not e.built:
		for u in us:
			if u.is_worker():
				u.give({"o": "build", "e": e}, queued)
			else:
				u.give({"o": "move", "p": p}, queued)
		_ping(p, Color(1, 0.85, 0.3))
		return
	if e and prey(us[0].team, e):        # (an enemy; for the Brood a loose horse too)
		for u in us:
			u.give({"o": "attack", "e": e}, queued)
		_ping(p, Color(1, 0.3, 0.3))
		return
	# right-click on the ground (as in StarCraft 2): a plain move, they go where they're told
	# and don't stop to fight on the way (A, then click, for an attack-move). (On a phone a tap
	# on the ground stays an attack-move: there's no right button to tell them apart.)
	group_move(us, p, not force_move and not Settings.pc(), queued)


## Spread a group around the destination so they don't fight for one spot.
## You're being hit: an alert (not too often) and a flashing spot on the minimap.
var alert_at := Vector2.INF
var alert_t := 0.0
var _alert_ms := -99999


func under_attack(e: Entity) -> void:
	if demo:
		return
	var now := Time.get_ticks_msec()
	alert_at = e.global_position if e is Unit else e.center()
	alert_t = 3.0
	if now - _alert_ms < 15000:
		return
	# no alarm while you're looking at the fight
	if camera and camera.get_screen_center_position().distance_to(alert_at) < 420.0:
		return
	_alert_ms = now
	var fac := faction_of(human)
	if e.team != human:
		# an ally's men or buildings (allies_hit: only when no fight of ours is on screen)
		Sfx.announce(fac, "ally_attack", 25.0, "alert")
		notify("Our allies are under attack!", true)
	elif e is Building:
		Sfx.announce(fac, "base_attack", 15.0, "base_alert")
		notify("Your base is under attack!", true)
	elif e is Unit and (e as Unit).is_worker():
		Sfx.announce(fac, "workers_attack", 20.0, "alert")
		notify("Your workers are under attack!", true)
	else:
		Sfx.announce(fac, "under_attack", 20.0, "alert")
		notify("Your forces are under attack!", true)


## Where each unit of a group goes for a move to p (the bunch-up rule of group_move).
func group_points(us: Array, p: Vector2, queued := false) -> Dictionary:
	var out := {}
	var n := us.size()
	if n == 0:
		return out
	var from := {}
	for u in us:
		from[u] = u.plan_end() if queued else u.position
	var c := Vector2.ZERO
	for u in us:
		c += from[u]
	c /= n
	var spread := 0.0
	for u in us:
		spread = maxf(spread, (from[u] as Vector2).distance_to(c))
	var blob := 8.0 * sqrt(float(n)) + 4.0
	var k := 1.0 if spread <= blob * 1.5 else blob / spread
	for u in us:
		var sp: Vector2 = p + ((from[u] as Vector2) - c) * k
		if n == 1 or not is_free(cell_of(sp)) or not line_clear(p, sp):
			sp = p
		out[u] = sp
	return out


func group_move(us: Array, p: Vector2, attack_move: bool, queued := false) -> void:
	if not us.is_empty() and us[0].team == human:
		Sfx.voice(us[0].kind, "attack" if attack_move else "move")
	# No pre-made formation (StarCraft / Beyond All Reason style): a group already together
	# keeps its shape and moves as one blob; a group spread out bunches up into a clump at
	# the point (each man keeps his side of it, closed in to a blob about its size).
	# (queued: from where their queues end)
	var n := us.size()
	var from := {}
	for u in us:
		from[u] = u.plan_end() if queued else u.position
	var c := Vector2.ZERO
	for u in us:
		c += from[u]
	c /= n
	var spread := 0.0
	for u in us:
		spread = maxf(spread, (from[u] as Vector2).distance_to(c))
	var blob := 8.0 * sqrt(float(n)) + 4.0            # the radius a bunched group takes (shoulder to shoulder)
	var k := 1.0 if spread <= blob * 1.5 else blob / spread
	for u in us:
		var sp: Vector2 = p + ((from[u] as Vector2) - c) * k
		if n == 1 or not is_free(cell_of(sp)) or not line_clear(p, sp):
			sp = p
		u.give({"o": "amove" if attack_move and not u.is_worker() else "move", "p": sp}, queued)
	_ping(p, Color(1, 0.3, 0.3) if attack_move else Color(0.4, 1, 0.4))


var _pings: Array = []


func _ping(p: Vector2, col: Color) -> void:
	_pings.append([p, col, 0.5])


func command_all(list: Array, what: String) -> void:
	for u in list:
		if u is Unit and not u.dead:
			u.patrol_a = Vector2.INF
			if what == "stop":
				u.cmd_stop()
			elif what == "hold":
				u.cmd_hold()


## which: "auto" (a Hive sends workers to a tapped mine, the army anywhere else),
## "army" or "worker".
func set_rally(b: Building, p: Vector2, which := "auto") -> void:
	var e := entity_at(p)
	if b.dual_rally():
		var site: bool = e is Building and e.team == b.team and int(e.d.get("crew", 0)) > 0
		if which == "auto":
			which = "worker" if site else "army"
		if which == "worker":
			b.worker_rally = p
			b.worker_rally_target = e if site else null
			return
		b.rally = p
		b.rally_target = e if e is Unit and e.team == b.team and not e.dead and e.kind != "horse" else null
		return
	b.rally = p
	b.rally_target = e if e is Building and e.team == b.team and int(e.d.get("crew", 0)) > 0 else null
	if e is Unit and e.team == b.team and not e.dead and e.kind != "horse":
		b.rally_target = e        # (a unit of ours: the rally follows it, new ones follow it)


func army(t: int) -> Array:
	return units.filter(func(u: Unit) -> bool: return u.team == t and not u.dead and not u.is_worker() and u.aboard == null \
		and u.kind != "horse" and u.kind != "messenger")


## A player's horses (bred, released, stolen; not the ones under riders or hitched to guns).
func horses_of(t: int) -> Array:
	return units.filter(func(u: Unit) -> bool: return u.team == t and not u.dead and u.kind == "horse")


## "Horses: 3 (1 reserved)" for the top bar and the breeder's card.
func horses_text(t: int) -> String:
	var hs := horses_of(t)
	var r := hs.filter(func(h: Unit) -> bool: return h.horse_rid != 0).size()
	return "Horses: %d%s" % [hs.size(), (" (%d reserved)" % r) if r > 0 else ""]


func labourers(t: int) -> Array:
	return workers(t)


func workers(t: int) -> Array:
	return units.filter(func(u: Unit) -> bool: return u.team == t and not u.dead and u.is_worker() and u.aboard == null)


func center_of_team(t: int) -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for b in buildings:
		if b.team == t and not b.dead:
			c += b.center()
			n += 1
	return c / n if n > 0 else Vector2(starts[t]) * T


# ------------------------------------------------------------------ overlay (world space)

func _sample_stats() -> void:
	for t in n_players():
		var s: Dictionary = stats[t]
		var value := 0
		for u in army(t):
			value += int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))
		s["army_tl"].append(value)
		s["gold_tl"].append(s["gold"])
		s["workers_tl"].append(workers(t).size())
		s["peak_army"] = maxi(s["peak_army"], value)


func faction_hall(t: int) -> String:
	return Defs.FACTIONS[faction_of(t)]["hall"]


## Efficiency colour: green from Defs.EFF_GOOD, through yellow, to red at Defs.EFF_POOR.
static func eff_colour(f: float) -> Color:
	var green := Color(0.35, 0.95, 0.35)
	var yellow := Color(1.0, 0.85, 0.25)
	var red := Color(1.0, 0.3, 0.22)
	if f >= Defs.EFF_GOOD:
		return green
	var mid := (Defs.EFF_GOOD + Defs.EFF_POOR) * 0.5
	if f >= mid:
		return yellow.lerp(green, (f - mid) / (Defs.EFF_GOOD - mid))
	return red.lerp(yellow, clampf((f - Defs.EFF_POOR) / (mid - Defs.EFF_POOR), 0.0, 1.0))


var _tex_tops := {}


## The first row of a texture with anything drawn in it (cached).
func _tex_top(tex: Texture2D) -> float:
	var k := tex.get_rid()
	if not _tex_tops.has(k):
		var img := tex.get_image()
		_tex_tops[k] = float(img.get_used_rect().position.y) if img else 0.0
	return _tex_tops[k]


## Over your economy buildings: the crew (X/Y) and the efficiency bar with its % (see
## Building.efficiency): one compact strip, readable on a phone.
func _draw_mine_labels() -> void:
	var font := ThemeDB.fallback_font
	for b in buildings:
		if b.dead or not b.built or not b.visible or (b.team != human and not demo):
			continue
		var crew_max := int(b.d.get("crew", 0))
		var eff: Array = b.efficiency()
		if crew_max == 0 and eff.is_empty():
			continue
		# just above its bars, which sit on top of the drawing itself (Building.bar_top)
		var top: float = b.global_position.y + b.bar_top() - 3.0
		var sz := 15
		var txt := ""
		var w1 := 0.0
		if crew_max > 0:
			txt = "%d/%d" % [b.crew.size(), crew_max]
			w1 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var bar_w := 40.0
		var pct := ""
		var w2 := 0.0
		if not eff.is_empty():
			pct = "%d%%" % int(round(float(eff[0]) * 100))
			w2 = font.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var gap := 4.0
		var total := w1 + ((gap + bar_w + gap + w2) if pct != "" else 0.0)
		if txt == "":
			total -= gap
		var p := Vector2(b.global_position.x - total * 0.5, top - 4)
		overlay.draw_rect(Rect2(p + Vector2(-4, -sz), Vector2(total + 8, sz + 5)), Color(0, 0, 0, 0.6))
		if txt != "":
			var have: int = b.crew.size()
			overlay.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1, 1, 1) if have < crew_max else Color(0.45, 1, 0.45))
		if pct != "":
			var f := float(eff[0])
			var col := eff_colour(f)
			var bx := p.x + w1 + (gap if txt != "" else 0.0)
			var bar := Rect2(bx, p.y - 10.0, bar_w, 8.0)
			overlay.draw_rect(bar, Color(0.12, 0.12, 0.12, 0.95))
			overlay.draw_rect(Rect2(bar.position, Vector2(bar_w * clampf(f, 0.0, 1.0), 8.0)), col)
			overlay.draw_rect(bar.grow(0.5), Color(0, 0, 0, 0.9), false, 1.0)
			overlay.draw_string(font, Vector2(bx + bar_w + gap, p.y), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
	for fl in _floats:
		var a: float = minf(float(fl[3]), 1.0)
		var w2: float = font.get_string_size(fl[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		overlay.draw_string_outline(font, fl[0] - Vector2(w2 * 0.5, 0), fl[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, a * 0.8))
		overlay.draw_string(font, fl[0] - Vector2(w2 * 0.5, 0), fl[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(fl[2], a))


## Shift-queued orders of your selected units: a faint line from each unit through its
## waypoints, with a small marker at each (green move, red attack, yellow build / work).
const QUEUE_COLS := {"move": Color(0.4, 1.0, 0.4), "amove": Color(1.0, 0.35, 0.3), "attack": Color(1.0, 0.35, 0.3),
	"build": Color(1.0, 0.85, 0.3), "repair": Color(1.0, 0.85, 0.3), "gather": Color(1.0, 0.85, 0.3)}


func _draw_queues() -> void:
	var me := controlled_team()
	if me < 0:
		return
	for e in selection:
		if not (e is Unit) or not is_instance_valid(e) or e.dead or e.team != me:
			continue
		var u := e as Unit
		if u.queue.is_empty() and u.line_rest.is_empty():
			continue
		var pts := u.plan_points()
		var from: Vector2 = u.global_position
		for pt in pts:
			var col: Color = QUEUE_COLS.get(pt[0], Color(1, 1, 1))
			overlay.draw_line(from, pt[1], Color(col, 0.4), 1.5)
			from = pt[1]
		for pt in pts:
			var col: Color = QUEUE_COLS.get(pt[0], Color(1, 1, 1))
			overlay.draw_circle(pt[1], 4.0, Color(0, 0, 0, 0.45))
			overlay.draw_circle(pt[1], 2.8, Color(col, 0.85))


func _draw_overlay() -> void:
	var pt := Time.get_ticks_usec()
	_draw_overlay_all()
	Prof.add("overlay draw", pt)


func _draw_overlay_all() -> void:
	_draw_mine_labels()
	_draw_queues()
	if not tongues.is_empty():
		_draw_tongues()
	for tr in _tracers:
		var col: Color = tr[3] if tr.size() > 3 else Color(1, 0.95, 0.7, 0.8)
		overlay.draw_line(tr[0], tr[1], col, tr[4] if tr.size() > 4 else 1.0)
	for pg in _pings:
		var f: float = pg[2] / 0.5
		overlay.draw_arc(pg[0], 16.0 * (1.5 - f), 0, TAU, 20, Color(pg[1], f), 2.0)
	# a line move being drawn: the line and where each unit will stand
	if controls and controls.line.size() >= 2:
		var lc := Color(1.0, 0.45, 0.35, 0.9) if controls.line_attack else Color(0.45, 1.0, 0.45, 0.9)
		overlay.draw_polyline(controls.line, lc, 2.0)
		var n := selected_units().size()
		if n > 0:
			for sp in line_spots(controls.line, n):
				overlay.draw_circle(sp, 4.0, lc)
	if controls and controls.mode == "place" and controls.line_from.x >= 0:
		# laying a wall: every piece from the start to here
		var lk: String = controls.place_kind
		var gold := int(players[human]["gold"])
		var cells := line_cells(controls.line_from, controls.ghost_cell)
		var plan := {}
		var oks := []
		for lc in cells:
			var lok := placement_problem(human, lk, lc) == "" and gold >= int(Defs.BUILDINGS[lk]["cost"])
			if lok:
				gold -= int(Defs.BUILDINGS[lk]["cost"])
				plan[lc] = lk
			oks.append(lok)
		for i in cells.size():
			var lc: Vector2i = cells[i]
			var lok: bool = oks[i]
			var lt := line_ghost_tex(lk, lc, plan)
			overlay.draw_rect(Rect2(Vector2(lc) * T, Vector2(T, T)).grow(-1), Color(0.3, 1, 0.3, 0.3) if lok else Color(1, 0.3, 0.3, 0.4))
			overlay.draw_texture(lt, Vector2(lc) * T + Vector2(T * 0.5, T) + Vector2(-lt.get_width() * 0.5, -lt.get_height() + 6), Color(1, 1, 1, 0.6) if lok else Color(1, 0.5, 0.5, 0.4))
	elif controls and controls.mode == "place":
		var k: String = controls.place_kind
		var size: Vector2i = Defs.BUILDINGS[k]["size"]
		var c: Vector2i = controls.ghost_cell
		var ok := placement_problem(human, k, c) == ""
		for y in size.y:
			for x in size.x:
				var cc := c + Vector2i(x, y)
				var free: bool = is_free(cc) and (demo or explored[idx(cc)] == 1) and (not needs_swamp(k) or swamp[human][idx(cc)] == 1) if in_map(cc) else false
				overlay.draw_rect(Rect2(Vector2(cc) * T, Vector2(T, T)).grow(-1), Color(0.3, 1, 0.3, 0.3) if free else Color(1, 0.3, 0.3, 0.4))
		var t: Texture2D = Building.farm_body("built") if k == "farm" else tex("res://assets/buildings/%s_built.png" % k)
		if Defs.BUILDINGS[k].get("line", false):
			t = line_ghost_tex(k, c, {c: k})
		var r := Rect2(Vector2(c) * T, Vector2(size) * T)
		if k == "farm":
			overlay.draw_texture(tex("res://assets/buildings/farm_field_young.png"), r.position, Color(1, 1, 1, 0.5) if ok else Color(1, 0.5, 0.5, 0.4))
		var pos := Building.anchor(k, r) + Building.body_offset(k, t)
		overlay.draw_texture(t, pos, Color(1, 1, 1, 0.6) if ok else Color(1, 0.5, 0.5, 0.5))
		if k == "farm" and String(Building.FARM_ART["sails"]) != "":
			# the windmill's sails, standing still
			var st: Texture2D = tex(Building.FARM_ART["sails"])
			var fw := st.get_width() / int(Building.FARM_ART["sail_frames"])
			var hub: Vector2 = Building.anchor(k, r) + Vector2(Building.FARM_ART["hub"])
			overlay.draw_texture_rect_region(st, Rect2(hub - Vector2(fw, st.get_height()) * 0.5, Vector2(fw, st.get_height())), Rect2(0, 0, fw, st.get_height()), Color(1, 1, 1, 0.6) if ok else Color(1, 0.5, 0.5, 0.5))


# ------------------------------------------------------------------ horses (Defs.HORSES)

## A horse of this building's side standing within HORSES.at_building tiles of it that a
## recruit can take (led ones too; not one walking in already or wanted by a rider), or null.
func free_horse_at(b: Building) -> Unit:
	var reach := float(Defs.HORSES["at_building"]) * T
	var best: Unit = null
	var bd := INF
	for u in units_near(b.center(), maxf(b.rect().size.x, b.rect().size.y) * 0.75 + reach + 20.0):
		if u.kind != "horse" or u.dead or u.off_field or u.team != b.team or u.into != null or u.horse_rid != 0:
			continue
		if u.claimed != null and is_instance_valid(u.claimed) and not u.claimed.dead and u.claimed.order_target == u:
			continue
		var dd: float = b.edge_distance(u.position)
		if dd <= reach + u.radius and dd < bd:
			bd = dd
			best = u
	return best


## The horses of a player standing within HORSES.at_building tiles of a building (for the card).
func horses_at(b: Building) -> int:
	var n := 0
	var reach := float(Defs.HORSES["at_building"]) * T
	for u in horses_of(b.team):
		if u.into == null and b.edge_distance(u.position) <= reach + u.radius:
			n += 1
	return n


## ---- one click trains the rider and his horse (Defs.HORSES near_breeder)

## Our finished Horse Breeders.
func breeders_of(t: int) -> Array:
	return buildings.filter(func(b: Building) -> bool: return b.team == t and b.kind == "horse_breeder" and b.built and not b.dead)


## The finished breeder nearest `p` with room in its queue, or null.
func breeder_with_room(t: int, p: Vector2) -> Building:
	var best: Building = null
	for b in breeders_of(t):
		if b.queue.size() < 5 and (best == null or b.center().distance_to(p) < best.center().distance_to(p)):
			best = b
	return best


## A free horse of ours (not reserved, led, claimed or walking anywhere) standing within
## HORSES.near_breeder tiles of one of our breeders, nearest `to`; or null.
func spare_horse(t: int, to: Building) -> Unit:
	var brs := breeders_of(t)
	if brs.is_empty():
		return null
	var reach := float(Defs.HORSES["near_breeder"]) * T
	var best: Unit = null
	var bd := INF
	for h in horses_of(t):
		if h.off_field or h.into != null or h.horse_rid != 0 or h.leader != null or h.order == "move":
			continue
		if h.claimed != null and is_instance_valid(h.claimed) and not h.claimed.dead and h.claimed.order_target == h:
			continue
		if not brs.any(func(br: Building) -> bool: return br.edge_distance(h.position) <= reach + h.radius):
			continue
		var dd: float = h.position.distance_to(to.center())
		if dd < bd:
			bd = dd
			best = h
	return best


var _rid_n := 0

## A fresh horse reservation id (never 0).
func new_rid() -> int:
	_rid_n += 1
	return int(Time.get_ticks_usec() % 1000000000) * 8 + (_rid_n % 8) + 1


## Keep a horse for queue entry `rid` of building b (unit kind k): a spare one at a breeder,
## else the nearest breeder queues one (`pay`: 40 gold now). A gun's horse walks over to
## its Foundry by itself; a rider's waits at the breeder for him. False: none to be had.
func _reserve_horse(b: Building, k: String, rid: int, pay: bool) -> bool:
	var h := spare_horse(b.team, b)
	if h:
		h.horse_rid = rid
		h.cmd_stop()
		if k != "cuirassier":
			h.walk_into(b)
		return true
	var br := breeder_with_room(b.team, b.center())
	if br == null:
		return false
	if pay:
		var c := int(Defs.UNITS["horse"]["cost"])
		if int(players[b.team]["gold"]) < c:
			return false
		players[b.team]["gold"] -= c
		stats[b.team]["spent"] += c
	br.add_entry("horse", {"rid": rid})
	return true


## Who a horse reservation is for: the Barracks or Foundry whose queue entry holds it, or
## the new rider waiting for it; null once that's gone (cancelled, dead, mounted).
func rid_owner(t: int, rid: int) -> Object:
	if rid == 0:
		return null
	for b in buildings:
		if b.team == t and not b.dead and b.kind != "horse_breeder":
			for kt in b.kits:
				if kt is Dictionary and int(kt.get("rid", 0)) == rid:
					return b
	for u in units:
		if u.team == t and not u.dead and u.kind != "horse" and u.horse_rid == rid:
			return u
	return null


## The horse kept for reservation `rid`, or null.
func reserved_horse(t: int, rid: int) -> Unit:
	if rid == 0:
		return null
	for h in horses_of(t):
		if h.horse_rid == rid and not h.off_field:
			return h
	return null


## The breeder still training the horse for `rid`, or null.
func rid_breeder(t: int, rid: int) -> Building:
	for b in breeders_of(t):
		for kt in b.kits:
			if kt is Dictionary and int(kt.get("rid", 0)) == rid:
				return b
	return null


## The reservation is over (its recruit cancelled): its horse is free again (one walking to
## a Foundry stops where it is). A horse still in a breeder's queue comes out a spare.
func release_rid(t: int, rid: int) -> void:
	var h := reserved_horse(t, rid)
	if h:
		h.horse_rid = 0
		if h.into is Building:
			h.into = null
			h.graze_at = h.position
	for b in breeders_of(t):
		for i in b.kits.size():
			if b.kits[i] is Dictionary and int(b.kits[i].get("rid", 0)) == rid:
				b.kits[i] = {}


## A gun's reserved horse has walked into its Foundry: its queue entry gets that horse.
func horse_arrived(b: Building, h: Unit) -> void:
	for i in b.kits.size():
		var kt = b.kits[i]
		if kt is Dictionary and int(kt.get("rid", 0)) == h.horse_rid:
			var nk: Dictionary = kt.duplicate()
			nk.erase("rid")
			nk["coat"] = h.coat
			nk["hh"] = snappedf(h.hp / maxf(h.max_hp, 1.0), 0.01)
			nk["hm"] = snappedf(h.horse_miles, 0.1)
			b.kits[i] = nk
			return


## A Foundry's gun is ready but its horse isn't there yet: make sure one is coming (its own,
## or a new spare one if it was killed or stolen, or a new one bought when there's gold).
func fetch_reserved(b: Building, i: int) -> void:
	var kt = b.kit_at(i)
	var rid := int(kt.get("rid", 0)) if kt is Dictionary else 0
	if rid == 0:
		return
	var h := reserved_horse(b.team, rid)
	if h:
		if h.into != b and h.leader == null:
			h.walk_into(b)
		return
	if rid_breeder(b.team, rid) != null:
		return
	_reserve_horse(b, String(b.queue[i]), rid, true)


var _res_chk := 0.0

## Every 2 s: a horse kept for a recruit that's gone (cancelled, killed, mounted elsewhere)
## is free again.
func _horse_res_tick(delta: float) -> void:
	_res_chk -= delta
	if _res_chk > 0.0:
		return
	_res_chk = 2.0
	for h in units:
		if h.kind == "horse" and not h.dead and h.horse_rid != 0 and rid_owner(h.team, h.horse_rid) == null:
			h.horse_rid = 0
			if h.into is Building:
				h.into = null
				h.graze_at = h.position


## A cancelled recruit's horse (its coat and health in the queue entry's kit) walks back out.
func horse_back(b: Building, kit: Dictionary) -> void:
	var c := nearest_free(cell_of(b.rect().get_center() + Vector2(0, b.rect().size.y * 0.5 + 16.0)), 6)
	var p := cell_center(c) if c.x >= 0 else b.center()
	var h := _add_unit("horse", b.team, p + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
	if HorseCoat.COATS.has(String(kit.get("coat", ""))):
		h.coat = String(kit["coat"])
		HorseCoat.apply(h)
	h.horse_miles = float(kit.get("hm", 0.0))
	h.apply_horse_vet()
	h.hp = h.max_hp * clampf(float(kit.get("hh", 1.0)), 0.05, 1.0)
	h.graze_at = h.position


## An unattended horse taken by an enemy man (Unit._steal_check), or a loose one (nobody's)
## caught by any man who can lead horses, or sent for by a gun (`by` a Unit, or the gun):
## it's his side's now.
func steal_horse(h: Unit, by: Entity) -> void:
	var was := h.team
	if by.team < 0 or by.team == was:
		return
	h.team = by.team
	h.leader = null
	h.claimed = null
	h.into = null
	h.horse_rid = 0
	h.bolt_t = 0.0
	h.bolt_to = Vector2.INF
	h.cmd_stop()
	h.graze_at = h.position
	h._graze_goal = Vector2.INF
	if h._mat:
		h._mat.set_shader_parameter("team", h.cloth_colour())
	selection.erase(h)
	h.selected = false
	for g in groups:
		g.erase(h)
	if was < 0:
		stats[by.team]["horses_caught"] = int(stats[by.team].get("horses_caught", 0)) + 1
		if mlog and not _first_of.has("%d:caught" % by.team):
			_first_of["%d:caught" % by.team] = true
			mlog.add("%s caught a loose horse (its first; by a %s)" % [mlog.who(by.team), String(by.d["name"]) if by is Unit else "gun"])
		if by.team == human:
			float_text(h.position + Vector2(0, -34), "loose horse caught", Color(0.85, 1.0, 0.7))
		return
	stats[by.team]["horses_stolen"] = int(stats[by.team].get("horses_stolen", 0)) + 1
	if mlog:
		mlog.add("%s stole a horse from %s" % [mlog.who(by.team), mlog.who(was)])
	if was == human:
		notify("A horse was stolen!")
		Sfx.announce("crown", "horse_stolen", 8.0)
	if by.team == human:
		float_text(h.position + Vector2(0, -34), "horse taken", Color(0.85, 1.0, 0.7))


## A rider (or a gun) of side `t` fell and his horse `h` lived: it bolted, nobody's now.
func horse_bolted(h: Unit, t: int, k: String) -> void:
	if t < 0 or t >= stats.size():
		return
	stats[t]["horses_bolted"] = int(stats[t].get("horses_bolted", 0)) + 1
	if mlog and not _first_of.has("%d:bolted" % t):
		_first_of["%d:bolted" % t] = true
		mlog.add("%s's %s was killed and a horse bolted loose (the first: anyone's to catch)" %[mlog.who(t), String(Defs.UNITS[k]["name"]) if Defs.UNITS.has(k) else k])
	if is_visible_to(human, h.position) and not demo:
		float_text(h.position + Vector2(0, -34), "loose horse", Color(0.95, 0.85, 0.6))


## Right-click with units on a horse, a gun or (horses only) a building. True if handled.
func _horse_command(us: Array, e, p: Vector2, queued: bool) -> bool:
	if e == null or (e.team != us[0].team and not loose_horse(e)):
		return false
	if e is Unit and e.kind == "horse":
		var mounts: Array = us.filter(func(u: Unit) -> bool: return u.can_mount() and not u.is_worker() and Unit.horse_free_for(e, u))
		var leaders: Array = us.filter(func(u: Unit) -> bool: return u.can_lead() and (u.is_worker() or mounts.is_empty()) and u.lead_count() < int(Defs.HORSES["lead_max"]) and Unit.horse_free_for(e, u))
		var who: Array = mounts if not mounts.is_empty() else leaders
		if who.is_empty():
			return false
		who.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(e.position) < b.position.distance_squared_to(e.position))
		var u: Unit = who[0]
		u.give({"o": "mount" if not mounts.is_empty() else "lead", "e": e}, queued)
		_ping(p, Color(0.9, 0.8, 0.5))
		return true
	if e is Unit and Defs.HARNESSED.has(e.kind) and e.team_room():
		# a horse selected, or led by a man selected, goes and is hitched
		var h: Unit = null
		for u in us:
			if u.kind == "horse" and u.into == null:
				h = u
				break
			if not u.led.is_empty():
				h = u.led[0]
				break
		if h == null:
			return false
		h.walk_into(e)
		_ping(p, Color(0.9, 0.8, 0.5))
		return true
	if e is Building and us.all(func(u: Unit) -> bool: return u.kind == "horse"):
		for u in us:
			u.give({"o": "move", "p": approach_point(e, u.position) + Vector2(randf_range(-10, 10), randf_range(-10, 10))}, queued)
		_ping(p, Color(0.4, 1, 0.4))
		return true
	return false


## LEAD: each man takes up to HORSES.lead_max free horses of ours within HORSES.fetch tiles.
## Returns how many horses are being fetched.
func lead_order(list: Array) -> int:
	var taken: Array = []
	var n := 0
	for u in list:
		if not (u is Unit) or not u.can_lead():
			continue
		var first := true
		while u.lead_count() < int(Defs.HORSES["lead_max"]):
			var h: Unit = u.nearest_free_horse(float(Defs.HORSES["fetch"]), taken + u.led)
			if h == null:
				break
			taken.append(h)
			u.give({"o": "lead", "e": h}, not first)
			first = false
			n += 1
	return n


## MOUNT: each man walks to the nearest free horse of ours (a different one each).
func mount_order(list: Array) -> int:
	var taken: Array = []
	var n := 0
	for u in list:
		if not (u is Unit) or not u.can_mount():
			continue
		var h: Unit = u.nearest_free_horse(float(Defs.HORSES["fetch"]), taken)
		if h and u.cmd_mount(h):
			taken.append(h)
			n += 1
	return n


## HARNESS: each gun or wagon with room in its team (those without a horse first) gets the
## nearest free horse walking over: one more each time.
func harness_order(list: Array) -> int:
	var taken: Array = []
	var n := 0
	var guns: Array = list.filter(func(g) -> bool: return g is Unit and Defs.HARNESSED.has(g.kind) and g.team_room() \
		and not units.any(func(h: Unit) -> bool: return h.kind == "horse" and h.into == g))
	guns.sort_custom(func(a: Unit, c: Unit) -> bool: return a.horse_count() < c.horse_count())
	for g in guns:
		var h: Unit = g.nearest_free_horse(float(Defs.HORSES["fetch"]), taken)
		if h:
			taken.append(h)
			h.walk_into(g)
			n += 1
	return n
