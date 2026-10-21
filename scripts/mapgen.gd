class_name MapGen
## Map layouts and biomes. Every map is mirrored through its middle so both players get
## the same ground; with 3-4 players it's mirrored both ways and everyone starts in a corner.
## A map is geography (cliffs, ramps, rivers, fords, woods), town-hall spots, and at the back
## of every base site a line of rock outcrops (saltpetre and ore, see plan_deposits).

## name, layout, biome (or "a+b" for a map that mixes two biomes)
const MAPS := {
	"greenhold": ["Greenhold", "crossroads", "grass"],
	"highmoor": ["Highmoor", "highlands", "autumn"],
	"dune_sea": ["Dune Sea", "crossroads", "desert"],
	"frostfang": ["Frostfang", "highlands", "snow"],
	"twin_fords": ["Twin Fords", "rivers", "grass"],
	"ashfall": ["Ashfall", "highlands", "volcanic"],
	"mirewood": ["Mirewood", "rivers", "marsh"],
	"border_march": ["Border March", "rivers", "snow+grass"],
	"red_coast": ["Red Coast", "highlands", "desert+marsh"],
}

## Tile sets per biome (names of assets/terrain/<set>_<n>.png).
const BIOMES := {
	"grass": {"low": ["grass"], "base": "dirt", "high": "grass_flat",
		"face": "grass_face", "ramp": "grass_ramp", "water": "water", "ford": "shallow",
		"trees": 0.8, "tint": Color(1, 1, 1)},
	"autumn": {"low": ["autumn"], "base": "dirt", "high": "autumn_flat",
		"face": "autumn_face", "ramp": "autumn_ramp", "water": "water", "ford": "shallow",
		"trees": 0.75, "tint": Color(1.15, 0.85, 0.55)},
	"desert": {"low": ["sand"], "base": "red", "high": "desert_flat",
		"face": "desert_face", "ramp": "desert_ramp", "water": "water", "ford": "shallow",
		"trees": 0.15, "tint": Color(1.05, 0.95, 0.7)},
	"snow": {"low": ["snow"], "base": "gravel", "high": "snow_rock_flat",
		"face": "snow_rock_face", "ramp": "snow_rock_ramp", "water": "water", "ford": "ice",
		"trees": 0.6, "tint": Color(0.85, 0.95, 1.1)},
	"marsh": {"low": ["moss"], "base": "mud", "high": "moss_flat",
		"face": "moss_face", "ramp": "moss_ramp", "water": "water", "ford": "mud",
		"trees": 0.85, "tint": Color(0.8, 0.95, 0.7)},
	"volcanic": {"low": ["basalt", "basalt", "basalt", "lava_crack"], "base": "gravel", "high": "lava_flat",
		"face": "lava_face", "ramp": "lava_ramp", "water": "lava", "ford": "basalt",
		"trees": 0.0, "tint": Color(0.7, 0.6, 0.55)},
}

var g: Game
var rng: RandomNumberGenerator
var W: int
var H: int
var height := PackedByteArray()     # 1 = high ground
var ramp := PackedByteArray()       # 1 = ramp cell
var ford := PackedByteArray()       # 1 = shallow crossing
var biome_a := ""
var biome_b := ""


func _init(game: Game) -> void:
	g = game
	rng = game.rng
	W = Game.W
	H = Game.H


## Fills the game's grids. Returns [layout, biome].
func generate(map_id: String) -> Array:
	if map_id == "blank":
		g.map_name = "New map"
		biome_a = "grass"
		biome_b = "grass"
		read_cells("")
		g.height = height
		g.ramp = ramp
		g.starts = []
		g.expansions = []
		g.base_sites = []
		g.deposit_plan = []
		return ["custom", "grass"]
	if map_id.begins_with("custom:"):
		var data := load_custom(map_id.substr(7))
		if not data.is_empty():
			apply_custom(data)
			return ["custom", data.get("biome", "grass")]
		map_id = "random"
	if not MAPS.has(map_id):
		map_id = MAPS.keys()[rng.randi() % MAPS.size()]
	var m: Array = MAPS[map_id]
	g.map_name = m[0]
	var parts: PackedStringArray = String(m[2]).split("+")
	biome_a = parts[0]
	biome_b = parts[1] if parts.size() > 1 else parts[0]
	for attempt in 30:
		height.resize(W * H)
		ramp.resize(W * H)
		ford.resize(W * H)
		height.fill(0)
		ramp.fill(0)
		ford.fill(0)
		g.solid.fill(0)
		g.water.fill(0)
		g.cliff.fill(0)
		g._terrain_kind.clear()
		match m[1]:
			"highlands":
				_highlands()
			"rivers":
				if four():
					_rivers4()
				else:
					_rivers()
			_:
				_crossroads()
		if four():
			_fold()
		_cliffs()
		var ok := true
		for i in g.starts.size():
			if not g._connected(g.starts[0], g.starts[i]) or not g._connected(g.starts[0], g.expansions[i]):
				ok = false
		if ok:
			break
	# every base site (all four corners with 3-4 players, used or not) gets its deposit line
	g.base_sites = g.starts + g.expansions
	g.deposit_plan = plan_deposits(g.base_sites, "4-way" if four() else "2-way")
	_assign_corners()
	g.height = height
	g.ramp = ramp
	return [m[1], m[2]]


# ------------------------------------------------------------------ custom maps (map editor)

## One letter per cell: . low, h high, r ramp, w water, f ford, t/T tree (low/high), k/K rock.
## Deposits: a list of [x, y, kind] (the top-left cell of each 2x2 outcrop); a map saved
## before deposits existed gets lines laid out behind its start and hall spots.
const CELL_CODES := ".hrwftTkK"
const MAP_DIR := "user://maps"


static func custom_names() -> Array:
	var out: Array = []
	var d := DirAccess.open(MAP_DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	out.sort()
	return out


static func load_custom(name: String) -> Dictionary:
	var f := FileAccess.open("%s/%s.json" % [MAP_DIR, name], FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func save_custom(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(MAP_DIR)
	var f := FileAccess.open("%s/%s.json" % [MAP_DIR, data["name"]], FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


static func delete_custom(name: String) -> void:
	DirAccess.remove_absolute("%s/%s.json" % [MAP_DIR, name])


## Read the grids of a custom map into the game. Starts are used in order; each player's
## expansion is the free hall spot nearest their start.
func apply_custom(data: Dictionary) -> void:
	g.map_name = String(data.get("name", "Custom"))
	var parts: PackedStringArray = String(data.get("biome", "grass")).split("+")
	biome_a = parts[0]
	biome_b = parts[1] if parts.size() > 1 else parts[0]
	read_cells(String(data.get("cells", "")))
	_cliffs()
	g.height = height
	g.ramp = ramp
	var st: Array = data.get("starts", [])
	var halls: Array = data.get("halls", [])
	g.base_sites = []
	for hs in st + halls:
		var hc := Vector2i(int(hs[0]), int(hs[1]))
		if not g.base_sites.has(hc):
			g.base_sites.append(hc)
	if data.has("deposits"):
		g.deposit_plan = (data["deposits"] as Array).map(func(dp: Array) -> Array: return [Vector2i(int(dp[0]), int(dp[1])), String(dp[2])])
	else:
		g.deposit_plan = plan_deposits(g.base_sites, String(data.get("mirror", "2-way")))
	g.starts = []
	g.expansions = []
	for t in g.n_players():
		var s: Array = st[t % maxi(st.size(), 1)] if not st.is_empty() else [6, 6]
		g.starts.append(Vector2i(int(s[0]), int(s[1])))
	for t in g.n_players():
		var best: Vector2i = g.starts[t]
		var bd := INF
		for hspot in halls:
			var c := Vector2i(int(hspot[0]), int(hspot[1]))
			var dd: float = Vector2(c).distance_to(Vector2(g.starts[t]))
			if dd < bd:
				bd = dd
				best = c
		g.expansions.append(best)


func read_cells(cells: String) -> void:
	height.resize(W * H)
	ramp.resize(W * H)
	ford.resize(W * H)
	height.fill(0)
	ramp.fill(0)
	ford.fill(0)
	g.solid.fill(0)
	g.water.fill(0)
	g.cliff.fill(0)
	g._terrain_kind.clear()
	for i in mini(cells.length(), W * H):
		match cells[i]:
			"h":
				height[i] = 1
			"r":
				ramp[i] = 1
			"w":
				g.water[i] = 1
				g.solid[i] = 1
			"f":
				ford[i] = 1
			"t", "T", "k", "K":
				height[i] = 1 if cells[i] in ["T", "K"] else 0
				g.solid[i] = 1
				g._terrain_kind[i] = "tree" if cells[i] in ["t", "T"] else "rock"


func biome_at(x: int, y: int) -> String:
	if biome_a == biome_b:
		return biome_a
	# split along the long diagonal: each player gets some of both biomes
	var s := float(x) / W - float(y) / H + sin(float(x + y) * 0.35) * 0.04
	return biome_a if s >= 0.0 else biome_b


# ------------------------------------------------------------------ layouts

func four() -> bool:
	return g.n_players() > 2


## Hall spots: two opposite corners, or all four corners with 3-4 players.
## `nat4` is the natural expansion used when there are four corners (the 2-player
## natural would sit too close to the corner below it).
func _base_spots(hall: Vector2i, nat: Vector2i, nat4 := Vector2i(30, 6)) -> void:
	var sz := Vector2i(5, 4)
	if not four():
		g.starts = [hall, g._mirror(hall, sz)]
		g.expansions = [nat, g._mirror(nat, sz)]
		return
	for c in [hall, nat4]:
		var list: Array = [c, Vector2i(c.x, H - c.y - sz.y), Vector2i(W - c.x - sz.x, c.y), g._mirror(c, sz)]   # TL, BL, TR, BR
		if c == hall:
			g.starts = list
		else:
			g.expansions = list


## Who starts where: allies share a side of the map (left or right).
func _assign_corners() -> void:
	if not four():
		return
	var order: Array = range(g.n_players())
	order.sort_custom(func(a: int, b: int) -> bool:
		return g.sides[a] < g.sides[b] or (g.sides[a] == g.sides[b] and a < b))
	var corners: Array = [0, 1, 2, 3]       # TL, BL, TR, BR
	if g.n_players() == 3:
		var cnt := {}
		for t in order:
			cnt[g.sides[t]] = int(cnt.get(g.sides[t], 0)) + 1
		corners = [0, 3, 2]                 # free-for-all: spread out
		if cnt.size() == 2:
			corners = [0, 1, 3] if int(cnt[g.sides[order[0]]]) == 2 else [0, 2, 3]
	var st: Array = []
	var ex: Array = []
	for i in order.size():
		st.append(Vector2i.ZERO)
		ex.append(Vector2i.ZERO)
	for i in order.size():
		st[order[i]] = g.starts[corners[i]]
		ex[order[i]] = g.expansions[corners[i]]
	g.starts = st
	g.expansions = ex


## Copy the top-left quarter onto the other three, mirrored.
func _fold() -> void:
	var kinds := {}
	for y in H:
		for x in W:
			var sx := mini(x, W - 1 - x)
			var sy := mini(y, H - 1 - y)
			if sx == x and sy == y:
				continue
			var i := y * W + x
			var j := sy * W + sx
			height[i] = height[j]
			ramp[i] = ramp[j]
			ford[i] = ford[j]
			g.water[i] = g.water[j]
			g.solid[i] = g.solid[j]
			if g._terrain_kind.has(j):
				kinds[i] = g._terrain_kind[j]
			else:
				g._terrain_kind.erase(i)
	for i in kinds:
		g._terrain_kind[i] = kinds[i]


func _keep() -> Array:
	var keep: Array = []
	for st in g.starts + g.expansions:
		keep.append([Vector2(st) + Vector2(2.5, 2), 13.0])
	return keep


## Open ground (mains up on high ground), a hill in the middle with two ramps, lakes and woods.
func _crossroads() -> void:
	_base_spots(Vector2i(10, 8), Vector2i(7, 34))
	_main_plateau()
	_plateau(Vector2(42, 30), Vector2(5, 4), [Vector2(30, 30), Vector2(54, 30)], false)
	_lake(Vector2(22, 50), Vector2(5, 3))
	_lake(Vector2(40, 12), Vector2(3, 2))
	_woods(22, _keep())


## Each main base sits on high ground with a single ramp down toward its natural.
func _highlands() -> void:
	_base_spots(Vector2i(10, 8), Vector2i(8, 38))
	_main_plateau()
	_plateau(Vector2(42, 30), Vector2(4, 3), [Vector2(42, 37), Vector2(42, 23)], false)
	_lake(Vector2(30, 46), Vector2(4, 3))
	_lake(Vector2(36, 16), Vector2(3, 2))
	_woods(18, _keep())


## A river splits the map between the two bases (mains up on high ground); three fords are the only crossings.
func _rivers() -> void:
	_base_spots(Vector2i(10, 8), Vector2i(7, 34))
	_main_plateau()
	var fords: Array = [0.22, 0.5, 0.78]
	for i in 160:
		var f := i / 159.0
		# the river runs from the top-right corner to the bottom-left one
		var c := Vector2(W - 1, 0).lerp(Vector2(0, H - 1), f) + Vector2(sin(f * 9.0) * 3.0, cos(f * 7.0) * 2.0)
		var is_ford := false
		for fd in fords:
			if absf(f - fd) < 0.025:
				is_ford = true
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if dx * dx + dy * dy > 5:
					continue
				var cell := Vector2i(int(c.x) + dx, int(c.y) + dy)
				if not g.in_map(cell):
					continue
				var i2 := g.idx(cell)
				if is_ford:
					ford[i2] = 1
				elif ford[i2] == 0:
					g.water[i2] = 1
					g.solid[i2] = 1
	# mirror so both sides match
	for y in H:
		for x in W:
			var i3 := y * W + x
			var j := (H - 1 - y) * W + (W - 1 - x)
			if g.water[i3] == 1 or g.water[j] == 1:
				if ford[i3] == 0 and ford[j] == 0:
					g.water[i3] = 1
					g.solid[i3] = 1
					g.water[j] = 1
					g.solid[j] = 1
	_woods(20, _keep())


## Four players: two rivers cross in the middle, cutting the map into quarters.
func _rivers4() -> void:
	_base_spots(Vector2i(10, 8), Vector2i(7, 34))
	_main_plateau()
	for i in 120:
		var f := i / 119.0
		var is_ford := absf(f - 0.25) < 0.035 or absf(f - 0.75) < 0.035
		for c in [Vector2(W * 0.5 + sin(f * 11.0) * 1.5, f * H), Vector2(f * W, H * 0.5 + sin(f * 13.0) * 1.5)]:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var cell := Vector2i(int(c.x) + dx, int(c.y) + dy)
					if not g.in_map(cell):
						continue
					var i2 := g.idx(cell)
					if is_ford:
						ford[i2] = 1
						g.water[i2] = 0
						g.solid[i2] = 0
					elif ford[i2] == 0:
						g.water[i2] = 1
						g.solid[i2] = 1
	_woods(20, _keep())


# ------------------------------------------------------------------ pieces

## Every main base sits on high ground with one ramp down toward its natural (two with
## four players), so it can be walled off.
func _main_plateau() -> void:
	_plateau(Vector2(11, 9), Vector2(15, 12), [Vector2(17, 28), Vector2(36, 8)] if four() else [Vector2(17, 28)], true)


## High ground (mirrored too when `mirror`): an ellipse, with ramps toward the given points.
func _plateau(c: Vector2, r: Vector2, ramps: Array, mirror: bool) -> void:
	var sets: Array = [[c, ramps]]
	if mirror:
		var mc := Vector2(W, H) - c
		var mr: Array = []
		for p in ramps:
			mr.append(Vector2(W, H) - p)
		sets.append([mc, mr])
	for st in sets:
		var cc: Vector2 = st[0]
		for y in range(int(cc.y - r.y) - 1, int(cc.y + r.y) + 2):
			for x in range(int(cc.x - r.x) - 1, int(cc.x + r.x) + 2):
				var q := Vector2((x + 0.5 - cc.x) / r.x, (y + 0.5 - cc.y) / r.y)
				if q.length() <= 1.0 and x >= 0 and y >= 0 and x < W and y < H:
					height[y * W + x] = 1
		for p in st[1]:
			_ramp(cc, p)


## A 3-wide ramp where the line from the plateau's middle toward `to` leaves it.
func _ramp(from: Vector2, to: Vector2) -> void:
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	var p := from
	for i in 60:
		p += dir * 0.5
		var cell := Vector2i(int(p.x), int(p.y))
		if not g.in_map(cell) or height[g.idx(cell)] == 0:
			break
	# p is now just outside the plateau: the ramp runs across the edge
	for k in range(-3, 3):
		for w in range(-1, 2):
			var q := p - dir * k * 0.7 + side * w
			var cell := Vector2i(int(q.x), int(q.y))
			if g.in_map(cell):
				ramp[g.idx(cell)] = 1
	# tidy the bottom: ramp cells on the low ground that stick out (one ramp neighbour or
	# none) are just low ground, so the ramp ends in a clean edge
	for pass_i in 2:
		for k in range(-3, 3):
			for w in range(-2, 3):
				var q := p - dir * k * 0.7 + side * w
				var cell := Vector2i(int(q.x), int(q.y))
				if not g.in_map(cell) or ramp[g.idx(cell)] == 0 or height[g.idx(cell)] == 1:
					continue
				var n := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var c2: Vector2i = cell + d
					if g.in_map(c2) and ramp[g.idx(c2)] == 1:
						n += 1
				if n <= 1:
					ramp[g.idx(cell)] = 0


func _lake(c: Vector2, r: Vector2) -> void:
	for cc in [c, Vector2(W, H) - c]:
		for y in range(int(cc.y - r.y - 1), int(cc.y + r.y + 2)):
			for x in range(int(cc.x - r.x - 1), int(cc.x + r.x + 2)):
				var q := Vector2((x - cc.x) / r.x, (y - cc.y) / r.y)
				if q.length() <= 1.0 + rng.randf_range(-0.15, 0.1) and x >= 0 and y >= 0 and x < W and y < H:
					var cell := Vector2i(x, y)
					for m in [cell, g._mirror(cell, Vector2i.ONE)]:
						if height[g.idx(m)] == 0 and ramp[g.idx(m)] == 0:
							g.water[g.idx(m)] = 1
							g.solid[g.idx(m)] = 1


## Clusters of trees and rocks (more rocks where few trees grow), and a ragged border.
func _woods(n: int, keep: Array) -> void:
	var cells: Array = []
	for i in n:
		var p := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(2, H - 3))
		var trees: float = BIOMES[biome_at(p.x, p.y)]["trees"]
		var kind := "tree" if rng.randf() < trees else "rock"
		var count := rng.randi_range(4, 14) if kind == "tree" else rng.randi_range(2, 6)
		for k in count:
			cells.append([p, kind])
			p += [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi() % 4]
	for x in W:
		if rng.randf() < 0.7:
			cells.append([Vector2i(x, 0), "tree" if rng.randf() < BIOMES[biome_at(x, 0)]["trees"] else "rock"])
	for y in H:
		if rng.randf() < 0.7:
			cells.append([Vector2i(0, y), "tree" if rng.randf() < BIOMES[biome_at(0, y)]["trees"] else "rock"])
	for hc in cells:
		var c: Vector2i = hc[0]
		if not g.in_map(c) or ramp[g.idx(c)] == 1 or ford[g.idx(c)] == 1:
			continue
		var bad := false
		for k in keep:
			if (Vector2(c) + Vector2(0.5, 0.5)).distance_to(k[0]) < k[1]:
				bad = true
				break
		if bad:
			continue
		for cc in [c, g._mirror(c, Vector2i.ONE)]:
			if g.water[g.idx(cc)] == 1:
				continue
			g.solid[g.idx(cc)] = 1
			g._terrain_kind[g.idx(cc)] = hc[1]


## The edge ring of every plateau is a cliff (impassable), except across its ramps.
func _cliffs() -> void:
	for y in H:
		for x in W:
			var i := y * W + x
			if height[i] == 0 or ramp[i] == 1:
				continue
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + dd
				if g.in_map(n) and height[g.idx(n)] == 0 and ramp[g.idx(n)] == 0:
					g.solid[i] = 1
					g._terrain_kind.erase(i)
					g.cliff[i] = 1
					break
	# ramps are walkable and count as low ground
	for i in W * H:
		if ramp[i] == 1:
			g.solid[i] = 0
			g.water[i] = 0
			g._terrain_kind.erase(i)
			height[i] = 0


# ------------------------------------------------------------------ deposits

const HALL_SIZE := Vector2i(5, 4)
const DEP_SIZE := Vector2i(2, 2)


## The map's symmetries: 0 itself, 1 turned round its middle, 2 flipped left-right, 3 flipped
## top-bottom. "2-way" maps (two players) have 0 and 1, "4-way" maps all four.
static func symmetries(mode: String) -> Array:
	if mode == "off":
		return [0]
	return [0, 1] if mode != "4-way" else [0, 1, 2, 3]


## A footprint's top-left cell under symmetry t.
static func xf(c: Vector2i, size: Vector2i, t: int) -> Vector2i:
	match t:
		1:
			return Vector2i(Game.W - c.x - size.x, Game.H - c.y - size.y)
		2:
			return Vector2i(Game.W - c.x - size.x, c.y)
		3:
			return Vector2i(c.x, Game.H - c.y - size.y)
	return c


## A line of outcrops ([cell, kind]) behind every base site (hall cells). Sites that are mirror
## images of each other (under the map's symmetry) get mirror-image lines, so every site has
## the same deposits; each line must fit at every one of its images.
func plan_deposits(sites: Array, mode: String) -> Array:
	var plan: Array = []
	var done := {}
	for s in sites:
		if done.has(s):
			continue
		var ts: Array = []
		var imgs: Array = []
		for t in symmetries(mode):
			var s2 := xf(s, HALL_SIZE, t)
			if (t == 0 or sites.has(s2)) and not done.has(s2) and not imgs.has(s2):
				ts.append(t)
				imgs.append(s2)
		for s2 in imgs:
			done[s2] = true
		var line := deposit_line(s, ts, sites)
		for t in ts:
			for dp in line:
				plan.append([xf(dp[0], DEP_SIZE, t), dp[1]])
	return plan


## The best line of `n` outcrops (saltpetre and ore alternating) behind the hall spot `s`: an
## arc 6.5-9.5 tiles from the hall's middle (or a straight row, e.g. along a map edge), as near as it fits to straight behind it (away
## from the ramps of a main on high ground, else away from the middle of the map), on open
## flat ground at the hall's level, clear of ramps, with open ground between it and the hall
## (room for the hall's economy buildings). Fewer outcrops if six don't fit anywhere.
func deposit_line(s: Vector2i, ts: Array, sites: Array, n := 6) -> Array:
	var hc := Vector2(s) + Vector2(HALL_SIZE) * 0.5
	var h0 := _height_at(s + Vector2i(2, 2))
	var back := _back_dir(hc, h0)
	var best: Array = []
	var bs := INF
	for ri in 7:
		var r := 6.5 + ri * 0.5
		for k in range(-12, 13):
			var th := back.angle() + deg_to_rad(7.5) * k
			for v in 4:
				# an arc round the hall (2.1 or 2.5 tiles apart), or a straight row (along a map edge)
				var sp: float = [2.1, 2.5, 2.1, 2.5][v]
				var line := _arc(hc, r, th, sp, n) if v < 2 else _row(hc, r - 1.0, th, sp, n)
				if line.is_empty():
					continue
				var pen := 0.0
				for t in ts:
					var moved: Array = line.map(func(c: Vector2i) -> Vector2i: return xf(c, DEP_SIZE, t))
					var pt := _line_penalty(moved, xf(s, HALL_SIZE, t), h0, sites)
					if pt < 0.0:
						pen = -1.0
						break
					pen += pt / ts.size()
				if pen < 0.0:
					continue
				var score: float = absf(k) * 1.2 + absf(r - 8.0) + (sp - 2.1) * 3.0 + pen + (0.0 if v < 2 else 1.0)
				if score < bs:
					bs = score
					best = line
	if best.is_empty():
		return deposit_line(s, ts, sites, n - 2) if n > 2 else []
	var out: Array = []
	for i in best.size():
		out.append([best[i], "saltpetre" if i % 2 == 0 else "ore"])
	return out


func _height_at(c: Vector2i) -> int:
	return height[g.idx(c)] if g.in_map(c) and height.size() == W * H else 0


## Which way is the back of a base: away from the ramps of the plateau a main stands on, or
## for a site on low ground, away from the middle of the map.
func _back_dir(hc: Vector2, h0: int) -> Vector2:
	var toward := Vector2.ZERO
	if h0 == 1:
		for y in range(int(hc.y) - 22, int(hc.y) + 23):
			for x in range(int(hc.x) - 22, int(hc.x) + 23):
				if x < 0 or y < 0 or x >= W or y >= H or ramp[y * W + x] == 0:
					continue
				var v := Vector2(x + 0.5, y + 0.5) - hc
				if v.length() < 22.0:
					toward += v.normalized()
	if toward.length() < 0.01:
		toward = Vector2(W, H) * 0.5 - hc
	if toward.length() < 0.01:
		toward = Vector2(0, 1)
	return -toward.normalized()


## n outcrops on an arc of radius r round hc, centred on angle th, sp tiles apart ([] if two
## would overlap once snapped to cells).
func _arc(hc: Vector2, r: float, th: float, sp: float, n: int) -> Array:
	var cells: Array = []
	for i in n:
		var a := th + (i - (n - 1) * 0.5) * sp / r
		var c := hc + Vector2(cos(a), sin(a)) * r
		var cell := Vector2i(roundi(c.x - 1.0), roundi(c.y - 1.0))
		for o in cells:
			if Rect2i(o, DEP_SIZE).intersects(Rect2i(cell, DEP_SIZE)):
				return []
		cells.append(cell)
	return cells


## n outcrops in a straight row square to angle th, d tiles from hc, sp tiles apart.
func _row(hc: Vector2, d: float, th: float, sp: float, n: int) -> Array:
	var u := Vector2(cos(th), sin(th))
	var side := Vector2(-u.y, u.x)
	var cells: Array = []
	for i in n:
		var c := hc + u * d + side * (i - (n - 1) * 0.5) * sp
		var cell := Vector2i(roundi(c.x - 1.0), roundi(c.y - 1.0))
		for o in cells:
			if Rect2i(o, DEP_SIZE).intersects(Rect2i(cell, DEP_SIZE)):
				return []
		cells.append(cell)
	return cells


## -1 if the line can't go there; otherwise how cramped it is (lower is better).
func _line_penalty(line: Array, s: Vector2i, h0: int, sites: Array) -> float:
	var hall := Rect2i(s, HALL_SIZE)
	var hc := Vector2(s) + Vector2(HALL_SIZE) * 0.5
	var pen := 0.0
	for c in line:
		var r := Rect2i(c, DEP_SIZE)
		if c.x < 1 or c.y < 1 or c.x + 2 > W - 1 or c.y + 2 > H - 1:
			return -1.0
		for o in sites:
			if Rect2i(o, HALL_SIZE).grow(2).intersects(r):
				return -1.0
		for y in range(c.y - 3, c.y + 5):
			for x in range(c.x - 3, c.x + 5):
				if x < 0 or y < 0 or x >= W or y >= H:
					continue
				var i := y * W + x
				var inside := r.has_point(Vector2i(x, y))
				if ramp[i] == 1:
					return -1.0              # (ramps stay clear)
				if inside and (g.solid[i] != 0 or g.water[i] == 1 or g.cliff[i] == 1 or height[i] != h0):
					return -1.0
				if not inside and x >= c.x - 1 and x <= c.x + 2 and y >= c.y - 1 and y <= c.y + 2 and (g.solid[i] != 0 or g.water[i] == 1):
					pen += 0.15            # hemmed in (a cliff or trees right beside it)
		# open ground between the hall and the outcrop: room for its Mill or Crusher
		var gap := Vector2(Game.tile_gap(hall, r)).length()
		if gap < 3.0:
			return -1.0
		var mid := Vector2(c) + Vector2(1, 1)
		for k in range(1, 8):
			var p := hc.lerp(mid, k / 8.0)
			var q := Vector2i(int(p.x), int(p.y))
			if g.in_map(q) and not hall.has_point(q) and not r.has_point(q) and (g.solid[g.idx(q)] != 0 or g.water[g.idx(q)] == 1):
				pen += 1.0
	return pen
