class_name Game
extends Node2D
## The match: map, pathfinding, entities, economy, combat helpers, fog of war,
## selection and commands. UI (hud.gd), input (controls.gd) and the AI (ai.gd)
## all talk to this node.

signal ended(winner: int)

const W := 84
const H := 60
const T := Defs.TILE
const HASH := 64

static var _tex_cache := {}

var human := 0
var factions: Array = ["crown", "crown"]
var swamp: Array = [PackedByteArray(), PackedByteArray()]
var swamp_dirty := true
var swamp_layer: Node2D
var _swamp_t := 0.0
var _notify_t := 0
var difficulty := 1
var demo := false                        # AI controls both sides
var rng := RandomNumberGenerator.new()

var solid := PackedByteArray()           # 0 free, 1 terrain, 2 building/mine
var water := PackedByteArray()
var astar := AStarGrid2D.new()
var units: Array = []
var buildings: Array = []
var mines: Array = []
var players: Array = []
var starts: Array = []                   # town hall cells per team
var expansions: Array = []               # free town hall spots

var world: Node2D
var ground: Sprite2D
var fog_sprite: Sprite2D
var fog_img: Image
var fog_tex: ImageTexture
var vis: Array = [PackedByteArray(), PackedByteArray()]
var explored := PackedByteArray()
var _vis_t := 0.0
var _disk_cache := {}
var minimap_img: Image
var camera: Camera2D
var overlay: Node2D
var controls: Node
var hud: Control
var ais: Array = []

var selection: Array = []
var groups: Array = [[], [], []]
var _hash := {}
var _path_queue: Array = []
var _end_t := 0.0
var over := false
var winner := -1
var clock := 0.0
var stats := [_new_stats(), _new_stats()]
var _sample_t := 0.0


static func _new_stats() -> Dictionary:
	return {"lost": 0, "killed": 0, "gold": 0, "spent": 0, "trained": 0, "built": 0,
		"razed": 0, "bld_lost": 0, "damage": 0.0, "peak_army": 0, "value_killed": 0,
		"kills_by": {}, "army_tl": [0], "gold_tl": [0], "workers_tl": [0]}


static func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func _init() -> void:
	rng.randomize()


func _ready() -> void:
	solid.resize(W * H)
	water.resize(W * H)
	explored.resize(W * H)
	for t in 2:
		vis[t].resize(W * H)
		swamp[t].resize(W * H)
		players.append({"gold": Defs.START_GOLD, "cap": 0, "faction": factions[t]})
	ground = Sprite2D.new()
	ground.centered = false
	ground.z_index = -20
	add_child(ground)
	swamp_layer = Node2D.new()
	swamp_layer.z_index = -19
	swamp_layer.draw.connect(_draw_swamp)
	add_child(swamp_layer)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
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
	_start_positions()
	_init_fog()
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
	# Fixed layout, mirrored for fairness: main base + 2 mines, a natural
	# expansion with 2 mines, and 2 contested mines near the middle.
	var hall := Vector2i(6, 6)
	var base_mines := [Vector2i(14, 4), Vector2i(4, 13)]
	var nat_hall := Vector2i(7, 34)
	var nat_mines := [Vector2i(3, 41), Vector2i(14, 41)]
	var mid_mines := [Vector2i(30, 26)]
	starts = [hall, _mirror(hall, Vector2i(5, 4))]
	expansions = [nat_hall, _mirror(nat_hall, Vector2i(5, 4))]
	var mine_cells: Array = base_mines + nat_mines + mid_mines
	var mirrored: Array = []
	for m in mine_cells:
		mirrored.append(_mirror(m, Vector2i(3, 2)))
	mine_cells += mirrored
	# Keep-clear zones around bases, mines and expansion spots.
	var keep: Array = []
	for s in starts + expansions:
		keep.append([Vector2(s) + Vector2(2.5, 2), 11.0])
	for m in mine_cells:
		keep.append([Vector2(m) + Vector2(1.5, 1), 4.5])
	# Obstacles: try seeds until both bases connect.
	for attempt in 30:
		solid.fill(0)
		water.fill(0)
		_scatter_obstacles(keep)
		if _connected(starts[0], starts[1]) and _connected(starts[0], expansions[1]):
			break
	for m in mine_cells:
		var gm := GoldMine.new()
		gm.setup(self, m)
		world.add_child(gm)
		mines.append(gm)
		_mark(m, Vector2i(3, 2), 2)


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


func _mark(c: Vector2i, size: Vector2i, v: int) -> void:
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if in_map(cc):
				solid[idx(cc)] = v
				if astar.region.size != Vector2i.ZERO:
					astar.set_point_solid(cc, v != 0)


func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(T, T)
	astar.offset = Vector2(T, T) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in H:
		for x in W:
			if solid[y * W + x] != 0:
				astar.set_point_solid(Vector2i(x, y), true)
	# Trees and rocks as sprites
	for i in _terrain_kind:
		var c := Vector2i(i % W, i / W)
		var s := Sprite2D.new()
		var kind: String = _terrain_kind[i]
		var n := rng.randi_range(0, 5)
		if kind == "tree" and rng.randf() < 0.35:
			n = rng.randi_range(4, 5)    # bushes
		s.texture = tex("res://assets/world/%s_%d.png" % [kind, n])
		s.centered = false
		s.offset = Vector2(-s.texture.get_width() * 0.5, -s.texture.get_height() + 4)
		s.position = cell_center(c) + Vector2(rng.randf_range(-3, 3), 14)
		if kind == "rock":
			s.scale = Vector2(0.7, 0.7)
		world.add_child(s)


func _render_ground() -> void:
	var img := Image.create(W * T, H * T, false, Image.FORMAT_RGBA8)
	var tiles := {}
	for n in ["grass_0", "grass_1", "grass_2", "grass_3", "flowers", "dirt_0", "dirt_1", "mud", "water"]:
		var t: Texture2D = tex("res://assets/tiles/%s.png" % n)
		var ti := t.get_image()
		ti.convert(Image.FORMAT_RGBA8)
		tiles[n] = ti
	minimap_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var near_base := func(c: Vector2i) -> bool:
		for s in starts:
			if (Vector2(c) - (Vector2(s) + Vector2(2.5, 2))).length() < 6.5:
				return true
		return false
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var n := "grass_0"
			var r := rng.randf()
			if r < 0.05:
				n = "flowers"
			elif r < 0.12:
				n = "grass_1"
			if near_base.call(c):
				n = "dirt_0"
			if water[idx(c)] == 1:
				n = "water"
			img.blit_rect(tiles[n], Rect2i(0, 0, T, T), Vector2i(x * T, y * T))
			var col := Color(0.29, 0.52, 0.2)
			if n == "water":
				col = Color(0.15, 0.35, 0.75)
			elif n.begins_with("dirt"):
				col = Color(0.5, 0.36, 0.2)
			if _terrain_kind.get(idx(c), "") == "tree":
				col = Color(0.1, 0.3, 0.1)
			elif _terrain_kind.get(idx(c), "") == "rock":
				col = Color(0.45, 0.45, 0.45)
			minimap_img.set_pixel(x, y, col)
	ground.texture = ImageTexture.create_from_image(img)
	for m in mines:
		var mm := m as GoldMine
		for yy in mm.size.y:
			for xx in mm.size.x:
				minimap_img.set_pixelv(mm.cell + Vector2i(xx, yy), Color(0.95, 0.8, 0.2))


func _start_positions() -> void:
	for t in 2:
		var f: Dictionary = Defs.FACTIONS[factions[t]]
		var b := _add_building(f["hall"], t, starts[t], true)
		var hall_center := b.rect().get_center()
		for i in int(f["start_workers"]):
			var u := _add_unit(f["worker"], t, hall_center + Vector2(-60 + i * 30, 80 if t == 0 else -80))
			if u.can_gather():
				var m := nearest_mine(u.position, t)
				if m:
					u.cmd_gather(m)
		if factions[t] == "clockwork":
			# The Clockwork arrive with Drill Rigs already on their home mines.
			for m in mines:
				if m.center().distance_to(hall_center) < 420.0:
					var spot := rig_spot(m, t)
					if spot.x >= 0:
						_add_building("drill_rig", t, spot, true)
		players[t]["gold"] = Defs.START_GOLD
	_update_swamp()


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
	world.add_child(u)
	units.append(u)
	return u


func _add_building(k: String, t: int, c: Vector2i, complete: bool) -> Building:
	var b := Building.new()
	b.setup(self, k, t, c, complete)
	if Defs.BUILDINGS[k].get("rig", false):
		var m := _rig_mine_at(b.rect())
		if m:
			m.rig = b
			b.rig_mine = m
	world.add_child(b)
	buildings.append(b)
	_mark(c, b.size, 2)
	_push_units_out(b.rect())
	_recount_supply(t)
	return b


func _push_units_out(r: Rect2) -> void:
	for u in units:
		if not u.dead and r.grow(u.radius).has_point(u.position):
			u.position = cell_center(nearest_free(cell_of(u.position), 8))


func nearest_free(c: Vector2i, max_r := 10) -> Vector2i:
	if is_free(c):
		return c
	for r in range(1, max_r + 1):
		var best := Vector2i(-1, -1)
		var bd := INF
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if absi(x) != r and absi(y) != r:
					continue
				var cc := c + Vector2i(x, y)
				if is_free(cc):
					var dd := Vector2(x, y).length()
					if dd < bd:
						bd = dd
						best = cc
		if best.x >= 0:
			return best
	return c


func on_unit_died(u: Unit) -> void:
	units.erase(u)
	selection.erase(u)
	for g in groups:
		g.erase(u)
	stats[u.team]["lost"] += 1
	if u.team >= 0:
		var foe: Dictionary = stats[1 - u.team]
		foe["killed"] += 1
		foe["value_killed"] += int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))
		if u.last_hit_by != "" and u.last_hit_team == 1 - u.team:
			foe["kills_by"][u.last_hit_by] = int(foe["kills_by"].get(u.last_hit_by, 0)) + 1


func on_building_died(b: Building) -> void:
	_mark(b.cell, b.size, 0)
	selection.erase(b)
	buildings.erase(b)
	_recount_supply(b.team)
	stats[b.team]["bld_lost"] += 1
	if b.team >= 0 and b.built:
		stats[1 - b.team]["razed"] += 1
		stats[1 - b.team]["value_killed"] += int(b.d["cost"])


func on_building_complete(b: Building) -> void:
	_recount_supply(b.team)
	if b.team == human and clock > 1.0:
		Sfx.play_f("built", b.d["faction"])


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
				n += int(Defs.UNITS[k]["supply"]) * int(Defs.UNITS[k].get("spawn", 1))
	return n


func add_gold(t: int, n: int) -> void:
	players[t]["gold"] += n
	stats[t]["gold"] += n


func refund(t: int, k: String) -> void:
	players[t]["gold"] += int(Defs.UNITS[k]["cost"])


# ------------------------------------------------------------------ production & building

## "" if allowed, else the reason.
func can_train(b: Building, k: String) -> String:
	if not b.can_train(k):
		return "Can't train that here."
	var u: Dictionary = Defs.UNITS[k]
	var req: String = u.get("requires", "")
	if req != "" and not _has_built(b.team, req):
		return "Needs a %s first." % Defs.BUILDINGS[req]["name"]
	if b.uses_eggs():
		if b.eggs < 1:
			return "No eggs ready."
	elif b.queue.size() >= 5:
		return "Queue is full."
	if players[b.team]["gold"] < int(u["cost"]):
		return "Not enough gold."
	if supply_used(b.team) + int(u["supply"]) * int(u.get("spawn", 1)) > players[b.team]["cap"]:
		if players[b.team]["cap"] >= max_supply(b.team):
			return "Supply is maxed out."
		var sup: String = Defs.FACTIONS[factions[b.team]]["supply"]
		return "Need more supply: build a %s." % Defs.BUILDINGS[sup]["name"]
	return ""


func _has_built(t: int, kind: String) -> bool:
	for b in buildings:
		if b.team == t and b.kind == kind and b.built and not b.dead:
			return true
	return false


func train(b: Building, k: String) -> String:
	var why := can_train(b, k)
	if why != "":
		return why
	players[b.team]["gold"] -= int(Defs.UNITS[k]["cost"])
	stats[b.team]["spent"] += int(Defs.UNITS[k]["cost"])
	b.queue.append(k)
	if b.uses_eggs():
		b.eggs -= 1
		b.morph_t.append(0.0)
	return ""


func cancel_train(b: Building) -> void:
	if b.queue.is_empty():
		return
	var k: String = b.queue.pop_back()
	if b.uses_eggs():
		b.morph_t.pop_back()
		b.eggs += 1
	if b.queue.is_empty():
		b.prod_t = 0.0
	refund(b.team, k)


func spawn_trained(b: Building, k: String) -> void:
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
				if dd < bd:
					bd = dd
					best = c
	stats[b.team]["trained"] += int(Defs.UNITS[k].get("spawn", 1))
	if b.team == human:
		if b.uses_eggs():
			Sfx.play("hatch", b.global_position)
		else:
			Sfx.play_f("ready", b.d["faction"])
	for n in int(Defs.UNITS[k].get("spawn", 1)):
		var u := _add_unit(k, b.team, cell_center(best) + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
		if u.can_gather():
			var m: Entity = b.rally_target if b.rally_target is GoldMine else nearest_mine(u.position, b.team)
			if m and (b.rally == Vector2.INF or b.rally_target is GoldMine):
				u.cmd_gather(m)
				continue
		if b.rally != Vector2.INF:
			u.cmd_move(b.rally + Vector2(randf_range(-20, 20), randf_range(-20, 20)), not u.is_worker())


func requirement_met(t: int, k: String) -> bool:
	var req: String = Defs.BUILDINGS[k].get("requires", "")
	if req == "":
		return true
	for b in buildings:
		if b.team == t and b.kind == req and b.built:
			return true
	return false


## "" if the building can go at this cell, else the reason.
func placement_problem(t: int, k: String, c: Vector2i) -> String:
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if not in_map(cc) or solid[idx(cc)] != 0:
				return "Blocked."
			if t == human and not demo and explored[idx(cc)] == 0:
				return "Unexplored."
			if needs_swamp(k) and swamp[t][idx(cc)] == 0:
				return "Brood structures must grow on your swamp."
	var r := Rect2(Vector2(c) * T, Vector2(size) * T)
	if Defs.BUILDINGS[k].get("rig", false):
		return "" if _rig_mine_at(r) else "Must be right next to a gold mine without a rig."
	# Keep a lane open beside gold mines so labourers don't get boxed in.
	for m in mines:
		if r.grow(T * 1.5).intersects((m as GoldMine).rect()):
			return "Too close to a gold mine."
	return ""


func place_building(t: int, k: String, c: Vector2i, builders: Array) -> Building:
	if placement_problem(t, k, c) != "" or players[t]["gold"] < int(Defs.BUILDINGS[k]["cost"]):
		return null
	if not requirement_met(t, k):
		return null
	players[t]["gold"] -= int(Defs.BUILDINGS[k]["cost"])
	stats[t]["spent"] += int(Defs.BUILDINGS[k]["cost"])
	stats[t]["built"] += 1
	var b := _add_building(k, t, c, false)
	_astar_dirty = true
	if Defs.BUILDINGS[k]["faction"] == "clockwork":
		b.seeded = false
		b._update_sprite()
		builders = builders.slice(0, 1)   # one winder starts it, then it builds itself
	if Defs.BUILDINGS[k]["faction"] == "brood":
		b.seeded = false
		b._update_sprite()
		builders = builders.slice(0, 1)   # one grub becomes the building
	for u in builders:
		if u is Unit and u.is_worker() and not u.dead:
			u.cmd_build(b)
	return b


func _rig_mine_at(r: Rect2) -> GoldMine:
	for m in mines:
		if m.rig == null and m.gold > 0 and r.grow(T * 0.6).intersects(m.rect()):
			return m
	return null


## A free spot for a Drill Rig beside this mine, or (-1, -1).
func rig_spot(m: GoldMine, t: int) -> Vector2i:
	if m.rig != null:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var bd := INF
	var hall := _own_hall(t)
	var toward: Vector2 = hall.center() if hall else m.center()
	for y in range(m.cell.y - 2, m.cell.y + m.size.y + 1):
		for x in range(m.cell.x - 2, m.cell.x + m.size.x + 1):
			var c := Vector2i(x, y)
			if placement_problem(t, "drill_rig", c) == "":
				var dd := (Vector2(c) * T + Vector2(T, T)).distance_to(toward)
				if dd < bd:
					bd = dd
					best = c
	return best


func in_field(t: int, p: Vector2) -> bool:
	for b in buildings:
		if b.team == t and b.built and not b.dead and b.d.has("field"):
			if b.center().distance_to(p) <= float(b.d["field"]) * T:
				return true
	return false


func find_repair(u: Unit, r: float) -> Entity:
	var best: Entity = null
	var bd := INF
	for o in units_near(u.position, r):
		if o.team == u.team and not o.dead and o != u and o.hp < o.max_hp * 0.95 and o.d["faction"] == "clockwork":
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


func notify(msg: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _notify_t > 3000 and hud:
		_notify_t = now
		hud.toast(msg)


# ------------------------------------------------------------------ swamp

func on_swamp(t: int, p: Vector2) -> bool:
	return swamp[t][idx(cell_of(p))] == 1


func mine_on_swamp(m: GoldMine, t: int) -> bool:
	if faction_of(t) != "brood":
		return true
	for y in range(-1, m.size.y + 1):
		for x in range(-1, m.size.x + 1):
			var c := m.cell + Vector2i(x, y)
			if in_map(c) and swamp[t][idx(c)] == 1:
				return true
	return false


func _update_swamp() -> void:
	swamp_dirty = false
	for t in 2:
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
		swamp[t] = g
	swamp_layer.queue_redraw()


func _draw_swamp() -> void:
	var t: Texture2D = tex("res://assets/tiles/swamp.png")
	for team in 2:
		var g: PackedByteArray = swamp[team]
		for i in W * H:
			if g[i] == 1:
				var x := i % W
				var y := i / W
				var edge := (x > 0 and g[i - 1] == 0) or (x < W - 1 and g[i + 1] == 0) \
					or (y > 0 and g[i - W] == 0) or (y < H - 1 and g[i + W] == 0)
				swamp_layer.draw_texture(t, Vector2(x * T, y * T), Color(1, 1, 1, 0.55 if edge else 1.0))


var _astar_dirty := false


# ------------------------------------------------------------------ pathfinding

func queue_path(u: Unit) -> void:
	if not _path_queue.has(u):
		_path_queue.append(u)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_free(cell_of(from), 6)
	var b := nearest_free(cell_of(to), 8)
	var pts := astar.get_point_path(a, b, true)
	if pts.is_empty():
		return PackedVector2Array([to])
	# Use the exact destination when it's on open ground.
	if is_free(cell_of(to)) and cell_of(to) == b:
		pts[pts.size() - 1] = to
	return _smooth(from, pts)


## Drop waypoints that can be skipped with a clear straight line.
func _smooth(from: Vector2, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cur := from
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i and not line_clear(cur, pts[j]):
			j -= 1
		out.append(pts[j])
		cur = pts[j]
		i = j + 1
	return out


func line_clear(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := int(dist / 10.0) + 1
	for s in steps + 1:
		var p := a.lerp(b, float(s) / float(steps))
		for off in [Vector2(-7, -7), Vector2(7, 7), Vector2(-7, 7), Vector2(7, -7)]:
			if not is_free(cell_of(p + off)):
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


func resolve_terrain(pos: Vector2, before: Vector2, radius: float) -> Vector2:
	pos = pos.clamp(Vector2(radius, radius), Vector2(W * T, H * T) - Vector2(radius, radius))
	if _clear_at(pos, radius):
		return pos
	var a := Vector2(pos.x, before.y)
	if _clear_at(a, radius):
		return a
	var b := Vector2(before.x, pos.y)
	if _clear_at(b, radius):
		return b
	if not _clear_at(before, radius):
		# Wedged inside something (e.g. a new building): pop out.
		return cell_center(nearest_free(cell_of(before), 6))
	return before


func _clear_at(p: Vector2, radius: float) -> bool:
	var r := radius * 0.6
	return is_free(cell_of(p)) and is_free(cell_of(p + Vector2(r, 0))) and is_free(cell_of(p - Vector2(r, 0))) \
		and is_free(cell_of(p + Vector2(0, r * 0.6))) and is_free(cell_of(p - Vector2(0, r * 0.6)))


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
				if u.position.distance_to(p) <= r:
					out.append(u)
	return out


func separation(u: Unit) -> Vector2:
	var push := Vector2.ZERO
	for o in units_near(u.position, u.radius + 18.0):
		if o == u or o.dead:
			continue
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
	var best: Entity = null
	var bd := INF
	for o in units_near(u.position, r):
		if o.team == u.team or o.dead or o.team < 0:
			continue
		var dd: float = o.position.distance_to(u.position)
		if o.is_worker():
			dd += 60.0   # prefer fighters
		if dd < bd:
			bd = dd
			best = o
	if best:
		return best
	for b in buildings:
		if b.team == u.team or b.dead:
			continue
		var dd: float = b.edge_distance(u.position)
		if dd < r and dd < bd:
			bd = dd
			best = b
	return best


## Best mine for a labourer: close to it, and above all close to one of
## our town halls (so trips are short). Mines far from any hall are a last resort.
func nearest_mine(p: Vector2, t: int) -> GoldMine:
	var best: GoldMine = null
	var bd := INF
	var brood := faction_of(t) == "brood"
	for m in mines:
		if m.gold <= 0:
			continue
		var score: float
		if brood:
			# Grubs: mines on our swamp with room left, nearest first.
			if not mine_on_swamp(m, t) or m.feeders.size() >= Defs.FEEDERS_PER_MINE:
				continue
			score = m.center().distance_to(p)
		else:
			var hall := nearest_hall(m.center(), t)
			var trip := hall.edge_distance(m.center()) if hall else 3000.0
			score = m.center().distance_to(p) * 0.5 + trip * 2.0
		if score < bd:
			bd = score
			best = m
	return best


func nearest_hall(p: Vector2, t: int) -> Building:
	var best: Building = null
	var bd := INF
	for b in buildings:
		if b.team == t and b.kind == "town_hall" and b.built and not b.dead:
			var dd: float = b.edge_distance(p)
			if dd < bd:
				bd = dd
				best = b
	return best


func entity_at(p: Vector2, include_mines := true) -> Entity:
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
		if b.visible and b.rect().grow(6).has_point(p + Vector2(0, 10)):
			return b
		if b.visible and b.sprite and b.sprite.texture:
			var sr := Rect2(b.global_position + b.sprite.offset, b.sprite.texture.get_size())
			if sr.grow(-6).has_point(p):
				return b
	if include_mines:
		for m in mines:
			if m.rect().grow(8).has_point(p):
				return m
	return null


# ------------------------------------------------------------------ combat helpers

func musket_shot(u: Unit, e: Entity, dmg: float) -> void:
	var muzzle := u.center() + u.facing * 20.0 + Vector2(0, -2)
	spawn_effect("smoke", muzzle + u.facing * 8.0, 1.2).scale = Vector2(0.7, 0.7)
	var hit := randf() < 0.85
	if hit:
		e.take_damage(dmg, u)
		spawn_effect("hit", e.center() + Vector2(randf_range(-5, 5), randf_range(-5, 5)), 1.0)
	_tracers.append([muzzle, e.center() + Vector2(randf_range(-8, 8), randf_range(-8, 8)) * (0.2 if hit else 1.6), 0.07])
	Sfx.play("musket", u.global_position)


var _tracers: Array = []


func bolt_shot(u: Unit, e: Entity, dmg: float) -> void:
	var from := u.center() + u.facing * 16.0
	var dir := (e.center() - from).normalized()
	var to := from + dir * (float(u.d["range"]) + 40.0)
	var hits := 0
	for o in units_near(from.lerp(to, 0.5), from.distance_to(to) * 0.5 + 20.0):
		if o.team == u.team or o.dead or o.team < 0:
			continue
		var q := Geometry2D.get_closest_point_to_segment(o.center(), from, to)
		if q.distance_to(o.center()) < o.radius + 6.0:
			o.take_damage(dmg * (1.0 if hits == 0 else 0.75), u)
			spawn_effect("hit", o.center(), 1.0)
			hits += 1
	if e.is_building():
		e.take_damage(dmg, u)
		to = e.center()
	_tracers.append([from, to, 0.1, Color(0.85, 0.7, 0.45), 2.0])
	Sfx.play("bolt", u.global_position)


func steam_cone(u: Unit, e: Entity, dmg: float) -> void:
	var from := u.center()
	var dir := (e.center() - from).normalized()
	var reach := float(u.d["range"]) + 24.0
	for o in units_near(from, reach + 20.0):
		if o.team == u.team or o.dead or o.team < 0:
			continue
		var to: Vector2 = o.center() - from
		if to.length() <= reach + o.radius and dir.dot(to.normalized()) > 0.72:
			o.take_damage(dmg, u)
	if e.is_building():
		e.take_damage(dmg, u)
	Sfx.play("steam", from)
	for i in 3:
		var fx := spawn_effect("smoke", from + dir * (20.0 + i * 22.0) + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 1.6)
		fx.modulate = Color(1.3, 1.3, 1.3, 0.85)


func acid_shot(u: Unit, e: Entity, dmg: float) -> void:
	var mouth := u.center() + u.facing * 14.0
	e.take_damage(dmg, u)
	e.acid_t = maxf(e.acid_t, float(u.d.get("acid", 3.0)))
	Sfx.play("acid", mouth)
	_tracers.append([mouth, e.center(), 0.12, Color(0.75, 0.95, 0.2), 3.0])


func cannon_shot(u: Unit, p: Vector2, dmg: float) -> void:
	var muzzle := u.center() + u.facing * 26.0
	spawn_effect("smoke", muzzle + u.facing * 10.0, 0.8)
	var pr := Projectile.new()
	pr.game = self
	pr.from = muzzle
	pr.to = p + Vector2(randf_range(-14, 14), randf_range(-10, 10))
	pr.duration = clampf(muzzle.distance_to(p) / 520.0, 0.25, 0.8)
	pr.damage = dmg
	pr.splash = float(u.d["splash"])
	pr.team = u.team
	pr.shooter = u
	add_child(pr)
	Sfx.play("cannon", u.global_position)


func explode(p: Vector2, dmg: float, splash: float, t: int, shooter: Entity) -> void:
	spawn_effect("blast", p, 1.0)
	Sfx.play("boom", p)
	for u in units_near(p, splash + 12.0):
		if u.team != t and not u.dead:
			var f := 1.0 - 0.5 * clampf(u.position.distance_to(p) / splash, 0.0, 1.0)
			u.take_damage(dmg * f, shooter)
	for b in buildings.duplicate():
		if b.team != t and not b.dead and b.edge_distance(p) < splash * 0.6:
			b.take_damage(dmg * 2.5, shooter)


func spawn_effect(name: String, p: Vector2, speed := 1.0, looping := false) -> Effect:
	var e := Effect.new()
	e.setup(name, speed, looping)
	e.position = p
	e.z_index = 3
	add_child(e)
	return e


# ------------------------------------------------------------------ fog of war

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


func _reveal(t: int, c: Vector2i, r: int) -> void:
	var v: PackedByteArray = vis[t]
	for o in _disk(r):
		var cc: Vector2i = c + o
		if cc.x >= 0 and cc.y >= 0 and cc.x < W and cc.y < H:
			v[cc.y * W + cc.x] = 1
	vis[t] = v


func _update_vis() -> void:
	for t in 2:
		vis[t].fill(0)
	for u in units:
		if not u.dead:
			_reveal(u.team, cell_of(u.position), u.sight)
	for b in buildings:
		if not b.dead:
			_reveal(b.team, cell_of(b.rect().get_center()), b.sight)
	var hv: PackedByteArray = vis[human]
	for i in W * H:
		if hv[i] == 1:
			explored[i] = 1
	if demo:
		fog_sprite.visible = false
		for u in units:
			u.visible = true
		return
	for y in H:
		for x in W:
			var i := y * W + x
			var a := 0 if hv[i] == 1 else (140 if explored[i] == 1 else 250)
			fog_img.set_pixel(x, y, Color(0, 0, 0, a / 255.0))
	fog_tex.update(fog_img)
	for u in units:
		if u.team != human:
			u.visible = hv[idx(cell_of(u.position))] == 1
	for b in buildings:
		if b.team != human:
			if not b.seen_by_human:
				var cc := cell_of(b.rect().get_center())
				if hv[idx(cc)] == 1:
					b.seen_by_human = true
			b.visible = b.seen_by_human


func is_visible_to(t: int, p: Vector2) -> bool:
	return vis[t][idx(cell_of(p))] == 1


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if over:
		return
	clock += delta
	_sample_t += delta
	if _sample_t >= 5.0:
		_sample_t = 0.0
		_sample_stats()
	_rebuild_hash()
	if _astar_dirty:
		_astar_dirty = false
	# Path budget per frame
	var budget := 24
	while budget > 0 and not _path_queue.is_empty():
		var u = _path_queue.pop_front()
		if is_instance_valid(u) and not u.dead:
			u.compute_path()
			budget -= 1
	_swamp_t -= delta
	if swamp_dirty and _swamp_t <= 0.0:
		_swamp_t = 0.5
		_update_swamp()
	_vis_t -= delta
	if _vis_t <= 0.0:
		_vis_t = 0.2
		_update_vis()
	for pg in _pings:
		pg[2] -= delta
	_pings = _pings.filter(func(pg: Array) -> bool: return pg[2] > 0.0)
	for tr in _tracers:
		tr[2] -= delta
	_tracers = _tracers.filter(func(tr: Array) -> bool: return tr[2] > 0.0)
	overlay.queue_redraw()
	_end_t -= delta
	if _end_t <= 0.0:
		_end_t = 1.0
		_check_end()


func _check_end() -> void:
	var alive := [0, 0]
	for b in buildings:
		if not b.dead:
			alive[b.team] += 1
	for t in 2:
		if alive[t] == 0:
			over = true
			winner = 1 - t
			ended.emit(winner)
			return


# ------------------------------------------------------------------ selection & commands (used by input and HUD)

func set_selection(list: Array) -> void:
	for e in selection:
		if is_instance_valid(e):
			e.selected = false
	selection = []
	for e in list:
		if is_instance_valid(e) and not e.dead:
			e.selected = true
			selection.append(e)


func selected_units() -> Array:
	return selection.filter(func(e: Entity) -> bool: return e is Unit and not e.dead and e.team == human)


func selected_building() -> Building:
	if selection.size() == 1 and selection[0] is Building and selection[0].team == human:
		return selection[0]
	return null


## Tap/right-click on the map with units selected: do the obvious thing.
func smart_command(list: Array, p: Vector2, force_move := false) -> void:
	var us: Array = list.filter(func(e: Entity) -> bool: return e is Unit and not e.dead)
	if us.is_empty():
		return
	var e := null if force_move else entity_at(p)
	if e is GoldMine:
		for u in us:
			if u.can_gather():
				u.cmd_gather(e)
			else:
				u.cmd_move(p, true)
		_ping(p, Color(1, 0.85, 0.3))
		return
	if e and e.team == us[0].team and e.hp < e.max_hp and (e.is_unit() or e.built) \
			and us.any(func(u: Unit) -> bool: return u.kind == "winder"):
		for u in us:
			if u.kind == "winder":
				u.cmd_repair(e)
			else:
				u.cmd_move(p)
		_ping(p, Color(0.95, 0.7, 0.25))
		return
	if e is Building and e.team == us[0].team and not e.built:
		for u in us:
			if u.is_worker():
				u.cmd_build(e)
			else:
				u.cmd_move(p)
		_ping(p, Color(1, 0.85, 0.3))
		return
	if e is Building and e.team == us[0].team and e.kind == "town_hall":
		for u in us:
			if u.kind == "labourer" and u.carrying > 0:
				u.order = "gather"
				u.work = "to_hall"
				u.home_mine = nearest_mine(u.position, u.team)
			else:
				u.cmd_move(p)
		return
	if e and e.team >= 0 and e.team != us[0].team:
		for u in us:
			u.cmd_attack(e)
		_ping(p, Color(1, 0.3, 0.3))
		return
	group_move(us, p, not force_move)


## Spread a group around the destination so they don't fight for one spot.
func group_move(us: Array, p: Vector2, attack_move: bool) -> void:
	var n := us.size()
	var cols := int(ceil(sqrt(float(n))))
	var spacing := 24.0
	var c := Vector2.ZERO
	for u in us:
		c += u.position
	c /= n
	var dir := (p - c).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x)
	var slots: Array = []
	for i in n:
		var row := i / cols
		var col := i % cols
		slots.append(p + side * (col - (cols - 1) * 0.5) * spacing - dir * row * spacing)
	# Nearest unit takes the nearest slot (greedy).
	var left := us.duplicate()
	for s in slots:
		var best: Unit = null
		var bd := INF
		for u in left:
			var dd: float = u.position.distance_to(s)
			if dd < bd:
				bd = dd
				best = u
		left.erase(best)
		var sp: Vector2 = s
		if not is_free(cell_of(sp)):
			sp = p
		best.cmd_move(sp, attack_move and not best.is_worker())
	_ping(p, Color(1, 0.3, 0.3) if attack_move else Color(0.4, 1, 0.4))


var _pings: Array = []


func _ping(p: Vector2, col: Color) -> void:
	_pings.append([p, col, 0.5])


func command_all(list: Array, what: String) -> void:
	for u in list:
		if u is Unit and not u.dead:
			if what == "stop":
				u.cmd_stop()
			elif what == "hold":
				u.cmd_hold()


func set_rally(b: Building, p: Vector2) -> void:
	b.rally = p
	var e := entity_at(p)
	b.rally_target = e if e is GoldMine else null


func army(t: int) -> Array:
	return units.filter(func(u: Unit) -> bool: return u.team == t and not u.dead and not u.is_worker())


func labourers(t: int) -> Array:
	return workers(t)


func workers(t: int) -> Array:
	return units.filter(func(u: Unit) -> bool: return u.team == t and not u.dead and u.is_worker())


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
	for t in 2:
		var s: Dictionary = stats[t]
		var value := 0
		for u in army(t):
			value += int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))
		s["army_tl"].append(value)
		s["gold_tl"].append(s["gold"])
		s["workers_tl"].append(workers(t).size())
		s["peak_army"] = maxi(s["peak_army"], value)


## Workers on a mine and how many it wants, as SC2 shows over resources.
## Returns [team, have, want] or [] when no label should be shown.
func mine_saturation(m: GoldMine) -> Array:
	if m.gold <= 0:
		return []
	var teams := [human] if not demo else [0, 1]
	for t in teams:
		if t < 0:
			continue
		var f := faction_of(t)
		if f == "clockwork":
			if m.rig and is_instance_valid(m.rig) and m.rig.team == t:
				return [t, 1 if m.rig.built else 0, 1]
			if _hall_near(m, t):
				return [t, 0, 1]
			continue
		var have := 0
		for u in units:
			if u.team == t and not u.dead and u.can_gather() and u.order == "gather" and u.home_mine == m:
				have += 1
		var want := Defs.FEEDERS_PER_MINE if f == "brood" else Defs.MINE_IDEAL
		if have > 0 or _hall_near(m, t):
			if f == "brood" and not mine_on_swamp(m, t) and have == 0:
				continue
			return [t, have, want]
	return []


func _hall_near(m: GoldMine, t: int) -> bool:
	for b in buildings:
		if b.team == t and b.built and not b.dead and b.kind == faction_hall(t) and b.center().distance_to(m.center()) < 430.0:
			return true
	return false


func faction_hall(t: int) -> String:
	return Defs.FACTIONS[faction_of(t)]["hall"]


func _draw_mine_labels() -> void:
	var font := ThemeDB.fallback_font
	for m in mines:
		if not demo and explored[idx(cell_of(m.center()))] == 0:
			continue
		var sat := mine_saturation(m)
		if sat.is_empty():
			continue
		var have: int = sat[1]
		var want: int = sat[2]
		var col := Color(1, 1, 1) if have < want else (Color(0.45, 1, 0.45) if have == want else Color(1, 0.75, 0.3))
		var txt := "%d/%d" % [have, want]
		var tex_h := 40.0
		if m.sprite and m.sprite.texture:
			tex_h = m.sprite.texture.get_height() - 8.0
		var sz := 13
		var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var p: Vector2 = m.global_position + Vector2(-w * 0.5, -tex_h - 6)
		overlay.draw_rect(Rect2(p + Vector2(-4, -sz), Vector2(w + 8, sz + 5)), Color(0, 0, 0, 0.55))
		overlay.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _draw_overlay() -> void:
	_draw_mine_labels()
	for tr in _tracers:
		var col: Color = tr[3] if tr.size() > 3 else Color(1, 0.95, 0.7, 0.8)
		overlay.draw_line(tr[0], tr[1], col, tr[4] if tr.size() > 4 else 1.0)
	for pg in _pings:
		var f: float = pg[2] / 0.5
		overlay.draw_arc(pg[0], 16.0 * (1.5 - f), 0, TAU, 20, Color(pg[1], f), 2.0)
	if controls and controls.mode == "place":
		var k: String = controls.place_kind
		var size: Vector2i = Defs.BUILDINGS[k]["size"]
		var c: Vector2i = controls.ghost_cell
		var ok := placement_problem(human, k, c) == ""
		for y in size.y:
			for x in size.x:
				var cc := c + Vector2i(x, y)
				var free: bool = is_free(cc) and (demo or explored[idx(cc)] == 1) and (not needs_swamp(k) or swamp[human][idx(cc)] == 1) if in_map(cc) else false
				overlay.draw_rect(Rect2(Vector2(cc) * T, Vector2(T, T)).grow(-1), Color(0.3, 1, 0.3, 0.3) if free else Color(1, 0.3, 0.3, 0.4))
		var t: Texture2D = tex("res://assets/buildings/%s_built.png" % k)
		var r := Rect2(Vector2(c) * T, Vector2(size) * T)
		var pos := Vector2(r.get_center().x, r.end.y) + Vector2(-t.get_width() * 0.5, -t.get_height() + 6)
		overlay.draw_texture(t, pos, Color(1, 1, 1, 0.6) if ok else Color(1, 0.5, 0.5, 0.5))
