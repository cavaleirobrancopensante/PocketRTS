class_name MapGen
## Map layouts and biomes. Every map is mirrored through its middle so both sides get the
## same ground. The classic maps (MAPS, 110 x 80) are generated anew each match from the
## match's seed: with 3-4 players they're mirrored both ways and everyone starts in a corner.
## The named maps (MapData.NAMED) are hand-made: any size, 1v1 to 4v4, a fixed layout
## (their own seed and pieces) so each one always looks the same; they're turned through
## their middle (180 degrees), so every player has a twin on the other side.
## A map holds no resources: it's geography (cliffs, ramps, rivers, fords, woods),
## decorations and town-hall spots (every hall's land holds its own reserves).

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

## Tile sets per biome (names of assets/terrain/<set>_<n>.png): "low" ground (several sets
## are laid in soft patches when "patches"), "base" (bare ground around the halls), "high"
## (patches on high ground), "face" (cliff faces), "water" and "ford". "trees": the share
## of tree clusters (the rest are rocks); "tint" colours the classic tree and rock art;
## "tree_art" / "bush_art" use decorations for the trees instead (assets/props). "scatter":
## the small decorations strewn over open ground; "kits": the groups of decorations (farm,
## camp, ruins...) that suit it. "amb": its ambience sound (default: its own name).
const BIOMES := {
	# (the bright grass is strong on the eye: a calmer copy of it is the ground and the
	# bright one comes in soft patches, fading in through the mid tiles; make_calm_grass.py)
	"grass": {"low": ["grass_calm", "grass_calm", "grass_calm", "grass_mid", "grass"], "patches": true, "base": "dirt", "high": "grass_flat",
		"face": "grass_face", "ramp": "grass_ramp", "water": "water", "ford": "shallow",
		"trees": 0.8, "tint": Color(1, 1, 1),
		"scatter": ["flowers", "flowers_pink", "grass_flowers", "grass_a", "stump", "shrub", "flowers_yellow"],
		"kits": ["farm", "village", "camp", "grove"]},
	"autumn": {"low": ["autumn"], "base": "dirt", "high": "autumn_flat",
		"face": "autumn_face", "ramp": "autumn_ramp", "water": "water", "ford": "shallow",
		"trees": 0.75, "tint": Color(1.15, 0.85, 0.55),
		"scatter": ["stump", "log_branch", "mushroom_red", "flowers_yellow", "shrub_berry", "sticks"],
		"kits": ["farm", "lumber", "camp"]},
	"desert": {"low": ["sand"], "base": "red", "high": "desert_flat",
		"face": "desert_face", "ramp": "desert_ramp", "water": "water", "ford": "shallow",
		"trees": 0.15, "tint": Color(1.05, 0.95, 0.7),
		"scatter": ["stones", "branches", "antlers", "sticks"],
		"kits": ["camp", "market", "ruins"]},
	"snow": {"low": ["snow"], "base": "gravel", "high": "snow_rock_flat",
		"face": "snow_rock_face", "ramp": "snow_rock_ramp", "water": "water", "ford": "ice",
		"trees": 0.6, "tint": Color(0.85, 0.95, 1.1),
		"scatter": ["stones", "branches", "sticks"],
		"kits": ["snowcamp", "ruins"]},
	"marsh": {"low": ["moss"], "base": "mud", "high": "moss_flat",
		"face": "moss_face", "ramp": "moss_ramp", "water": "water", "ford": "mud",
		"trees": 0.85, "tint": Color(0.8, 0.95, 0.7),
		"scatter": ["reeds", "grass_reed", "log_moss", "mushroom", "stump_moss"],
		"kits": ["lumber", "shrine"]},
	"volcanic": {"low": ["basalt", "basalt", "basalt", "lava_crack"], "base": "gravel", "high": "lava_flat",
		"face": "lava_face", "ramp": "lava_ramp", "water": "lava", "ford": "basalt",
		"trees": 0.0, "tint": Color(0.7, 0.6, 0.55),
		"scatter": ["branches", "antlers", "stones", "sticks"],
		"kits": ["ruins", "forge"]},
	# --- from the second atlas (tools/import_terrain2.py)
	"heath": {"low": ["heath", "heath", "heather"], "patches": true, "base": "dirt", "high": "mossrock",
		"face": "mossrock_face", "ramp": "grass_ramp", "water": "deep", "ford": "shallow",
		"trees": 0.5, "tint": Color(0.95, 1.0, 0.9), "amb": "grass",
		"tree_art": ["oak", "birch", "dead_tree"], "bush_art": ["bush_flower", "shrub_dark", "bush_lilac"],
		"scatter": ["flowers_pink", "flowers", "grass_flowers", "stones", "rocks_moss", "stump", "grass_d"],
		"kits": ["farm", "shrine", "ruins", "camp"]},
	"jungle": {"low": ["fern", "roots"], "patches": true, "base": "dirt", "high": "roots",
		"face": "fern_face", "ramp": "forest_ramp", "water": "deep", "ford": "rapids",
		"trees": 0.95, "tint": Color(0.8, 1.05, 0.8), "amb": "marsh",
		"tree_art": ["oak", "oak", "blossom"], "bush_art": ["bush_berry", "shrub_b", "shrub_dark"],
		"scatter": ["grass_tall", "grass_reed", "shrub_b", "mushroom_red", "mushroom", "log_moss", "stump_moss", "flowers_wild"],
		"kits": ["ruins", "camp", "lumber"]},
	"canyon": {"low": ["clay"], "base": "red", "high": "canyon",
		"face": "canyon_face", "ramp": "desert_ramp", "water": "deep", "ford": "shingle",
		"trees": 0.1, "tint": Color(1.1, 0.9, 0.75), "amb": "desert",
		"tree_art": ["dead_tree"], "bush_art": ["thorns", "brambles"],
		"scatter": ["stones", "branches", "antlers", "sticks"],
		"kits": ["camp", "market", "forge"]},
	"tundra": {"low": ["tundra"], "base": "gravel", "high": "tundra",
		"face": "glacier_face", "ramp": "snow_rock_ramp", "water": "deep", "ford": "glacier",
		"trees": 0.5, "tint": Color(0.85, 0.95, 1.1), "amb": "snow",
		"tree_art": ["pine", "pine", "dead_tree"], "bush_art": ["shrub_dark", "thorns"],
		"scatter": ["stones", "branches", "sticks", "grass_d"],
		"kits": ["snowcamp", "ruins", "watch"]},
	"ashland": {"low": ["cinder", "burnt"], "patches": true, "base": "slate", "high": "slate",
		"face": "slate_face", "ramp": "lava_ramp", "water": "lava", "ford": "basalt",
		"trees": 0.12, "tint": Color(0.55, 0.5, 0.5), "amb": "volcanic",
		"tree_art": ["dead_tree"], "bush_art": ["thorns", "brambles"],
		"scatter": ["branches", "antlers", "stones", "sticks", "log_branch"],
		"kits": ["ruins", "forge", "watch"]},
	"pinewood": {"low": ["pine"], "base": "dirt", "high": "mossrock",
		"face": "mossrock_face", "ramp": "forest_ramp", "water": "deep", "ford": "rapids",
		"trees": 0.9, "tint": Color(0.9, 1.0, 0.9), "amb": "autumn",
		"tree_art": ["pine", "pine", "pine", "birch"], "bush_art": ["shrub_dark", "shrub_b"],
		"scatter": ["stump", "log_moss", "mushroom", "mushroom_red", "grass_a", "shrub_dark", "nest", "sticks"],
		"kits": ["lumber", "camp", "watch"]},
	"steppe": {"low": ["steppe", "scrub"], "patches": true, "base": "dirt", "high": "scrub",
		"face": "steppe_face", "ramp": "desert_ramp", "water": "water", "ford": "shingle",
		"trees": 0.3, "tint": Color(1.1, 1.0, 0.75), "amb": "desert",
		"tree_art": ["dead_tree", "gold_tree"], "bush_art": ["thorns", "brambles", "bush_yellow"],
		"scatter": ["grass_c", "grass_reed", "stones", "branches", "sheaf", "flowers_yellow"],
		"kits": ["camp", "farm", "market"]},
	"coast": {"low": ["shingle", "bone"], "patches": true, "base": "bone", "high": "mossrock",
		"face": "chalk_face", "ramp": "beach_ramp", "water": "deep", "ford": "coral",
		"trees": 0.3, "tint": Color(1.0, 1.0, 0.95), "amb": "grass",
		"tree_art": ["birch", "dead_tree"], "bush_art": ["grass_reed", "shrub_b"],
		"scatter": ["log", "stones", "grass_reed", "rocks_moss", "anchor"],
		"kits": ["wreck", "market", "watch"]},
	"oldkingdom": {"low": ["heath", "heath", "heather"], "patches": true, "base": "ruin", "high": "mossrock",
		"face": "ruin_face", "ramp": "grass_ramp", "water": "deep", "ford": "shallow",
		"trees": 0.55, "tint": Color(1.0, 1.0, 0.95), "amb": "grass",
		"tree_art": ["oak", "blossom", "birch"], "bush_art": ["bush_red", "bush_lilac", "shrub"],
		"scatter": ["stones", "flowers", "rocks_moss", "grass_flowers", "flowers_mix", "stump"],
		"kits": ["ruins", "village", "shrine", "grove"]},
	"bog": {"low": ["bog", "reeds"], "patches": true, "base": "mud", "high": "mossrock",
		"face": "bog_face", "ramp": "moss_ramp", "water": "kelp", "ford": "reeds",
		"trees": 0.7, "tint": Color(0.8, 0.95, 0.7), "amb": "marsh",
		"tree_art": ["dead_tree", "oak"], "bush_art": ["grass_tall", "shrub_dark"],
		"scatter": ["reeds", "grass_reed", "log_moss", "mushroom", "stump_moss", "grass_tall"],
		"kits": ["shrine", "lumber"]},
	"glowwood": {"low": ["glow", "cinder"], "patches": true, "base": "bog", "high": "roots",
		"face": "roots_face", "ramp": "forest_ramp", "water": "deep", "ford": "rapids",
		"trees": 0.85, "tint": Color(0.6, 0.75, 0.85), "amb": "marsh",
		"tree_art": ["dead_tree", "oak", "pine"], "bush_art": ["shrub_dark", "brambles"],
		"scatter": ["mushroom", "mushroom_red", "log_moss", "stump_moss", "rocks_moss", "grass_b"],
		"kits": ["ruins", "shrine"]},
	"fall": {"low": ["leaves"], "base": "dirt", "high": "heath",
		"face": "leaves_face", "ramp": "autumn_ramp", "water": "deep", "ford": "rapids",
		"trees": 0.8, "tint": Color(1.15, 0.85, 0.55), "amb": "autumn",
		"tree_art": ["red_tree", "gold_tree", "gold_tree", "oak"], "bush_art": ["bush_yellow", "bush_red", "shrub_berry"],
		"scatter": ["flowers_yellow", "stump", "log_branch", "mushroom_red", "grass_flowers", "shrub_berry"],
		"kits": ["farm", "lumber", "village"]},
	"badlands": {"low": ["bone", "clay"], "patches": true, "base": "clay", "high": "chalk",
		"face": "bone_face", "ramp": "sand_ramp", "water": "deep", "ford": "shingle",
		"trees": 0.08, "tint": Color(1.05, 0.95, 0.8), "amb": "desert",
		"tree_art": ["dead_tree"], "bush_art": ["thorns"],
		"scatter": ["antlers", "branches", "stones", "sticks"],
		"kits": ["ruins", "camp"]},
}


## The classic maps' size (84 x 60 before 0.15.0; docs/map_sizes.md).
const CLASSIC := Vector2i(110, 80)


## The version that made the built-in maps bigger: a replay or a saved match of a built-in
## map from before it was played on the old ground, so it can't be shown or resumed.
const RESIZED := "0.15.0"


## Was a match of `map_id` recorded on `version` played on that map's old, smaller layout?
static func old_layout(map_id: String, version: String) -> bool:
	if not (MAPS.has(map_id) or MapData.NAMED.has(map_id)):
		return false
	var a := version.split(".")
	var b := RESIZED.split(".")
	if a.size() < 3 or not a[0].is_valid_int():
		return false              # ("dev" builds)
	for i in 3:
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false


## The size in cells of a map: a named map's own, a custom map's (saved with it; older
## ones are 84 x 60), the editor's blank "blank:WxH", the classic maps CLASSIC.
static func size_of(map_id: String) -> Vector2i:
	if MapData.NAMED.has(map_id):
		var sz: Array = MapData.NAMED[map_id]["size"]
		return Vector2i(int(sz[0]), int(sz[1]))
	if map_id.begins_with("custom:"):
		return custom_size(load_custom(map_id.substr(7)))
	if map_id.begins_with("blank:"):
		var p := map_id.substr(6).split("x")
		if p.size() == 2:
			return Vector2i(clampi(int(p[0]), 16, MAX_SIZE.x), clampi(int(p[1]), 16, MAX_SIZE.y))
	return CLASSIC


## Every built-in map: the classic ones, then the named ones.
static func all_ids() -> Array:
	return MAPS.keys() + MapData.NAMED.keys()


## A built-in map's mode ("1v1", "2v2", "3v3", "4v4") and how many players it holds.
## The classic maps are 1v1 maps that also take 3-4 players in their four corners.
static func mode_of(map_id: String) -> String:
	if MapData.NAMED.has(map_id):
		return String(MapData.NAMED[map_id]["mode"])
	if map_id.begins_with("custom:"):
		return custom_mode(load_custom(map_id.substr(7)))
	return "1v1"


static func max_players(map_id: String) -> int:
	if MapData.NAMED.has(map_id):
		return int(String(MapData.NAMED[map_id]["mode"]).substr(0, 1)) * 2
	if map_id.begins_with("custom:"):
		return (load_custom(map_id.substr(7)).get("starts", []) as Array).size()
	return 4


static func display_name(map_id: String) -> String:
	if MapData.NAMED.has(map_id):
		return String(MapData.NAMED[map_id]["name"])
	if MAPS.has(map_id):
		return String(MAPS[map_id][0])
	return map_id


## The lobby's random choices: [id, label, the modes it draws from].
const POOLS := [
	["random_1v1", "Random 1v1 maps", ["1v1"]],
	["random_2v2", "Random 2v2 maps", ["2v2"]],
	["random_1v1_2v2", "Random 1v1+2v2 maps", ["1v1", "2v2"]],
	["random_3v3", "Random 3v3 maps", ["3v3"]],
	["random_1v1_2v2_3v3", "Random 1v1+2v2+3v3 maps", ["1v1", "2v2", "3v3"]],
	["random_4v4", "Random 4v4 maps", ["4v4"]],
	["random", "Random all maps", ["1v1", "2v2", "3v3", "4v4"]],
]


static func is_pool(map_id: String) -> bool:
	for p in POOLS:
		if p[0] == map_id:
			return true
	return false


## The maps of a random pool that hold `n` players: the built-in ones, and your own maps
## of those modes that passed the editor's CHECK when they were saved.
static func pool_maps(pool_id: String, n: int) -> Array:
	var modes: Array = ["1v1", "2v2", "3v3", "4v4"]
	for p in POOLS:
		if p[0] == pool_id:
			modes = p[2]
	var out: Array = all_ids().filter(func(id: String) -> bool: return modes.has(mode_of(id)) and max_players(id) >= n)
	for nm in custom_names():
		var d := load_custom(nm)
		if bool(d.get("checked", false)) and modes.has(custom_mode(d)) and (d.get("starts", []) as Array).size() >= n:
			out.append("custom:" + nm)
	return out


## "Ashford Crossing (1v1, 96x96)", "My map (your map, 2v2, 120x100)"
static func label(map_id: String) -> String:
	for p in POOLS:
		if p[0] == map_id:
			return String(p[1])
	if map_id.begins_with("custom:"):
		var d := load_custom(map_id.substr(7))
		var cs := custom_size(d)
		return Loc.t("%s (your map, %s, %dx%d)") % [map_id.substr(7), custom_mode(d), cs.x, cs.y]
	var sz := size_of(map_id)
	return "%s (%s, %dx%d)" % [display_name(map_id), mode_of(map_id), sz.x, sz.y]


## A built-in map's biome text ("heath", "snow+grass").
static func biome_of(map_id: String) -> String:
	if MapData.NAMED.has(map_id):
		return String(MapData.NAMED[map_id]["biome"])
	if MAPS.has(map_id):
		return String(MAPS[map_id][2])
	return "grass"


var g: Game
var rng: RandomNumberGenerator
var W: int
var H: int
var height := PackedByteArray()     # 1 = high ground
var ramp := PackedByteArray()       # 1 = ramp cell
var ford := PackedByteArray()       # 1 = shallow crossing
var biome_a := ""
var biome_b := ""
var mix := "diag"                   # how two biomes share the map: "diag", "patch", "middle"
var water_set := ""                 # a named map's own water and ford tiles (the same all over)
var ford_set := ""
var props: Array = []               # decorations: {"name", "pos" (px, its foot), "cells" (solid ones), "dead"}
var _prop_at := {}                  # map index -> the decoration whose foot blocks it


func _init(game: Game) -> void:
	g = game
	rng = game.rng
	W = Game.W
	H = Game.H


## Fills the game's grids. Returns [layout, biome].
func generate(map_id: String) -> Array:
	if map_id == "blank" or map_id.begins_with("blank:"):
		g.map_name = "New map"
		biome_a = "grass"
		biome_b = "grass"
		read_cells("")
		g.height = height
		g.ramp = ramp
		g.starts = []
		g.expansions = []
		g.base_sites = []
		return ["custom", "grass"]
	if map_id.begins_with("custom:"):
		var data := load_custom(map_id.substr(7))
		if not data.is_empty():
			apply_custom(data)
			return ["custom", data.get("biome", "grass")]
		map_id = "random"
	if MapData.NAMED.has(map_id):
		return _named(map_id)
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
		else:
			_symmetrize()       # (the middle hill's two ramps came out a row apart: the halves must match exactly)
		_square_ramps()
		_cliffs()
		var ok := true
		for c in g.starts + g.expansions + extra_sites:
			if not g._connected(g.starts[0], c):
				ok = false
		if ok:
			break
	# every base site (all four corners with 3-4 players, used or not; the thirds of every side)
	g.base_sites = g.starts + g.expansions + extra_sites
	var all_mains: Array = g.starts.duplicate()
	_assign_corners()
	# a light scatter of decorations (their own dice: the map's layout stays as it was)
	var drng := RandomNumberGenerator.new()
	drng.seed = hash(g.rng.seed) + 17
	_decorate(drng, [], 0.6)
	_clear_mains(all_mains)
	_thin_sites(g.base_sites)
	_clear_footprints(g.base_sites)
	_open_ways(g.base_sites)
	g.height = height
	g.ramp = ramp
	return [m[1], m[2]]


# ------------------------------------------------------------------ custom maps (map editor)

## One letter per cell: . low, h high, r ramp, w water (lava in a volcanic biome), f ford,
## t/T tree (low/high), k/K rock. (Maps saved with "deposits", the rock outcrops brought in
## with v0.7.32, still load: they're ignored.)
## A custom map's file (user://maps/<name>.json): name, size [W, H] (older maps have none:
## 84 x 60), cells, biome ("a" or "a+b"), mix, mirror (the editor's symmetry), starts
## [[x, y], ...] (hall top-left cells), teams (each start's team: 0, 1, ...), mode ("2v2"...),
## halls (more hall spots), props [[name, x, y, flip], ...] (decorations at their foot cell),
## checked (it passed the editor's CHECK). A picture for the lobby sits beside it (<name>.png).
const CELL_CODES := ".hrwftTkK"
const MAP_DIR := "user://maps"
const MAX_SIZE := Vector2i(256, 256)


## A custom map's size (older maps were all 84 x 60; a new, empty one is the classic size).
static func custom_size(d: Dictionary) -> Vector2i:
	if d.is_empty():
		return CLASSIC
	var sz: Array = d.get("size", [84, 60])
	if sz.size() < 2:
		return Vector2i(84, 60)
	return Vector2i(clampi(int(sz[0]), 16, MAX_SIZE.x), clampi(int(sz[1]), 16, MAX_SIZE.y))


## Each start's team on a custom map (older maps have none: two starts face each other,
## more are everyone for themselves).
static func custom_teams(d: Dictionary) -> Array:
	var n := (d.get("starts", []) as Array).size()
	var t: Array = d.get("teams", [])
	var out: Array = []
	for i in n:
		if i < t.size():
			out.append(int(t[i]))
		else:
			out.append(i % 2 if n == 2 else i)
	return out


## "1v1", "2v2"... when the starts make two even teams; "FFA" when everyone is alone,
## otherwise e.g. "2v1".
static func mode_from_teams(teams: Array) -> String:
	if teams.size() < 2:
		return "-"
	var count := {}
	for t in teams:
		count[t] = int(count.get(t, 0)) + 1
	var sizes: Array = count.values()
	sizes.sort()
	sizes.reverse()
	if sizes.size() == 2:
		return "%dv%d" % [sizes[0], sizes[1]]
	if sizes[0] == 1:
		return "FFA"
	return "v".join(sizes.map(func(x: int) -> String: return str(x)))


static func custom_mode(d: Dictionary) -> String:
	return mode_from_teams(custom_teams(d))


## Which start each player takes on a custom map: the starts are grouped by their team;
## each lobby team (largest first) takes the group with the most room left, so allies sit
## together. Returns a start index per player (-1: no start left).
static func custom_spot_order(teams: Array, sides: Array) -> Array:
	var groups := {}
	for i in teams.size():
		if not groups.has(teams[i]):
			groups[teams[i]] = []
		groups[teams[i]].append(i)
	var by_side := {}
	for t in sides.size():
		var sd := int(sides[t])
		if not by_side.has(sd):
			by_side[sd] = []
		by_side[sd].append(t)
	var order: Array = by_side.keys()
	order.sort_custom(func(a: int, b: int) -> bool:
		return by_side[a].size() > by_side[b].size() or (by_side[a].size() == by_side[b].size() and a < b))
	var out: Array = []
	out.resize(sides.size())
	out.fill(-1)
	var used := {}
	for sd in order:
		# the group with the most free starts that no other side has taken yet
		var best: Variant = null
		for gk in groups:
			if used.has(gk) or (groups[gk] as Array).is_empty():
				continue
			if best == null or (groups[gk] as Array).size() > (groups[best] as Array).size():
				best = gk
		if best != null:
			used[best] = true
		for t in by_side[sd]:
			if best == null or (groups[best] as Array).is_empty():
				# no room left with the allies: any free start
				best = null
				for gk in groups:
					if not (groups[gk] as Array).is_empty():
						best = gk
						break
				if best == null:
					break
			out[t] = (groups[best] as Array).pop_front()
	return out


## Where each player's hall goes on a custom map (the lobby's preview uses it too).
static func custom_starts(d: Dictionary, sides: Array) -> Array:
	var st: Array = d.get("starts", [])
	var out: Array = []
	for spot in custom_spot_order(custom_teams(d), sides):
		if spot >= 0:
			out.append(Vector2i(int(st[spot][0]), int(st[spot][1])))
		else:
			out.append(Vector2i(6, 6))
	return out


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
	DirAccess.remove_absolute("%s/%s.png" % [MAP_DIR, name])


## A custom map's lobby picture (saved by the editor), or null.
static func custom_picture(name: String) -> Texture2D:
	var path := "%s/%s.png" % [MAP_DIR, name]
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img else null


## Read the grids of a custom map into the game. The players take the starts by team
## (allies together); a start nobody takes is an expansion. Each player's expansion is the
## free hall spot nearest their start.
func apply_custom(data: Dictionary) -> void:
	g.map_name = String(data.get("name", "Custom"))
	var parts: PackedStringArray = String(data.get("biome", "grass")).split("+")
	biome_a = parts[0] if BIOMES.has(parts[0]) else "grass"
	biome_b = parts[1] if parts.size() > 1 and BIOMES.has(parts[1]) else biome_a
	mix = String(data.get("mix", "diag"))
	read_cells(String(data.get("cells", "")))
	_square_ramps()
	_cliffs()
	place_props(data.get("props", []))
	g.height = height
	g.ramp = ramp
	var st: Array = data.get("starts", [])
	var halls: Array = data.get("halls", [])
	var sides: Array = []
	for t in g.n_players():
		sides.append(int(g.sides[t]) if t < g.sides.size() else t)
	g.starts = custom_starts(data, sides) if not st.is_empty() else []
	while g.starts.size() < g.n_players():
		g.starts.append(Vector2i(6, 6))
	var free: Array = []
	g.base_sites = []
	for hs in st + halls:
		var hc := Vector2i(int(hs[0]), int(hs[1]))
		if not g.base_sites.has(hc):
			g.base_sites.append(hc)
		if not g.starts.has(hc):
			free.append(hc)
	g.expansions = []
	for t in g.n_players():
		var best: Vector2i = g.starts[t]
		var bd := INF
		for c in free:
			var dd: float = Vector2(c).distance_to(Vector2(g.starts[t]))
			if dd < bd:
				bd = dd
				best = c
		g.expansions.append(best)


## The cells a decoration's foot blocks when it stands at `c` (none for one walked through).
static func prop_foot(name: String, c: Vector2i) -> Array:
	var w: int = PropData.PROPS[name][2] if PropData.PROPS.has(name) else 0
	var foot: Array = []
	for dx in range(-(w - 1) / 2, w - (w - 1) / 2):
		foot.append(c + Vector2i(dx, 0))
		if w >= 3:
			foot.append(c + Vector2i(dx, -1))
	return foot


## The decorations of a custom map ([name, x, y, flip], placed in the editor): each where
## it was put (not on water, nor a solid foot over a cliff, rock or another solid one).
func place_props(list: Array) -> void:
	props.clear()
	_prop_at.clear()
	for it in list:
		if not (it is Array) or (it as Array).size() < 3 or not PropData.PROPS.has(String(it[0])):
			continue
		var name := String(it[0])
		var c := Vector2i(int(it[1]), int(it[2]))
		if not g.in_map(c) or g.water[g.idx(c)] == 1:
			continue
		var foot := prop_foot(name, c)
		var ok := true
		for fc in foot:
			if not g.in_map(fc) or g.solid[g.idx(fc)] != 0 or ramp[g.idx(fc)] == 1:
				ok = false
		if not ok:
			continue
		var low := c.y
		var sx := 0.0
		for fc in foot:
			sx += fc.x + 0.5
		var px := sx / foot.size() if not foot.is_empty() else c.x + 0.5
		var pos := Vector2(px, low + 1.0) * Defs.TILE + Vector2(0, -5)
		var ix := props.size()
		props.append({"name": name, "pos": pos, "cells": foot, "at": c, "dead": false,
			"flip": it.size() > 3 and bool(it[3])})
		for fc in foot:
			g.solid[g.idx(fc)] = 1
			g._terrain_kind[g.idx(fc)] = "prop"
			_prop_at[g.idx(fc)] = ix


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
	if mix == "patch":
		# soft patches of the second biome, the same on both sides
		var n := _noise(x, y, 9.0) + _noise(W - 1 - x, H - 1 - y, 9.0)
		return biome_b if n > 1.15 else biome_a
	if mix == "middle":
		# the second biome in the middle of the map
		var q := Vector2((x + 0.5) / W - 0.5, (y + 0.5) / H - 0.5)
		return biome_b if q.length() + (_noise(x, y, 5.0) + _noise(W - 1 - x, H - 1 - y, 5.0)) * 0.04 < 0.27 else biome_a
	# split along the long diagonal: each player gets some of both biomes
	var s := float(x) / W - float(y) / H + sin(float(x + y) * 0.35) * 0.04
	return biome_a if s >= 0.0 else biome_b


# ------------------------------------------------------------------ layouts

func four() -> bool:
	return g.n_players() > 2


## Hall spots: two opposite corners, or all four corners with 3-4 players. `nat` is each
## main's natural (in front of its ramp), `thirds` the other base sites of the top-left
## player (their twins are added). With four corners the map is the top-left quarter folded
## both ways: `nat4` is that quarter's natural (the 2-player one would sit too close to the
## corner below it) and `thirds4` its other sites.
var extra_sites: Array = []         # base sites that are nobody's start or natural (all sides)


func _base_spots(hall: Vector2i, nat: Vector2i, thirds: Array = [], nat4 := Vector2i(40, 6), thirds4: Array = []) -> void:
	var sz := HALL
	extra_sites = []
	if not four():
		g.starts = [hall, g._mirror(hall, sz)]
		g.expansions = [nat, g._mirror(nat, sz)]
		for c in thirds:
			extra_sites.append(c)
			extra_sites.append(g._mirror(c, sz))
		return
	for c in [hall, nat4] + thirds4:
		var list: Array = [c, Vector2i(c.x, H - c.y - sz.y), Vector2i(W - c.x - sz.x, c.y), g._mirror(c, sz)]   # TL, BL, TR, BR
		if c == hall:
			g.starts = list
		elif c == nat4:
			g.expansions = list
		else:
			extra_sites.append_array(list)


## The hall spots themselves are open ground (no tree, rock or decoration on the footprint
## or the ring round it).
func _clear_footprints(sites: Array) -> void:
	for st in sites:
		for y in range(st.y - 1, st.y + HALL.y + 1):
			for x in range(st.x - 1, st.x + HALL.x + 1):
				var c := Vector2i(x, y)
				if g.in_map(c) and (g._terrain_kind.has(g.idx(c)) or _prop_at.has(g.idx(c))) and g.water[g.idx(c)] == 0 and g.cliff[g.idx(c)] == 0:
					_clear_cell(g.idx(c))


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
	for st in g.starts + g.expansions + extra_sites:
		keep.append([Vector2(st) + Vector2(2.5, 2), 13.0])
	return keep


## Open ground (mains up on high ground), a hill in the middle with two ramps, lakes and woods.
## Each side: the natural below its ramp, a corner beyond it, a site past the pond on its own
## edge and one along the top beside its main (the owner's Greenhold drawing, 2026-10-28).
func _crossroads() -> void:
	_base_spots(Vector2i(10, 8), Vector2i(7, 30), [Vector2i(5, 69), Vector2i(31, 68), Vector2i(36, 5), Vector2i(38, 25)], Vector2i(38, 6), [Vector2i(36, 26)])
	_main_plateau()
	_plateau(Vector2(55, 40), Vector2(6, 5), [Vector2(40, 40), Vector2(70, 40)], false)
	_lake(Vector2(20, 66), Vector2(5, 4))
	_lake(Vector2(54, 15), Vector2(4, 3))
	_woods(38, _keep())


## Each main base sits on high ground with a single ramp down toward its natural.
func _highlands() -> void:
	_base_spots(Vector2i(10, 8), Vector2i(7, 31), [Vector2i(6, 66), Vector2i(27, 69), Vector2i(38, 5), Vector2i(38, 25)], Vector2i(38, 6), [Vector2i(36, 26)])
	_main_plateau()
	_plateau(Vector2(55, 40), Vector2(5, 4), [Vector2(55, 49), Vector2(55, 31)], false)
	_lake(Vector2(42, 61), Vector2(5, 4))
	_lake(Vector2(48, 21), Vector2(4, 3))
	_woods(31, _keep())


## A river splits the map between the two bases (mains up on high ground); three fords are the only crossings.
func _rivers() -> void:
	_base_spots(Vector2i(10, 8), Vector2i(7, 30), [Vector2i(6, 50), Vector2i(38, 5), Vector2i(30, 28), Vector2i(64, 4)])
	_main_plateau()
	var fords: Array = [0.22, 0.5, 0.78]
	for i in 210:
		var f := i / 209.0
		# the river runs from the top-right corner to the bottom-left one
		var c := Vector2(W - 1, 0).lerp(Vector2(0, H - 1), f) + Vector2(sin(f * 9.0) * 3.0, cos(f * 7.0) * 2.0)
		var is_ford := false
		for fd in fords:
			if absf(f - fd) < 0.019:
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
	# and the fords too, open ground on both sides (the river's wiggle is not its own twin: a ford cell's twin was river,
	# and a ford laid over river already drawn stayed water, so the two sides' fords differed; docs/expansion_spots.md)
	for y in H:
		for x in W:
			var i4 := y * W + x
			var j4 := (H - 1 - y) * W + (W - 1 - x)
			if ford[i4] == 1 or ford[j4] == 1:
				for k in [i4, j4]:
					ford[k] = 1
					g.water[k] = 0
					g.solid[k] = 0
	_woods(35, _keep())


## Four players: two rivers cross in the middle, cutting the map into quarters.
func _rivers4() -> void:
	_base_spots(Vector2i(10, 8), Vector2i(7, 30), [], Vector2i(38, 6), [Vector2i(36, 26)])
	_main_plateau()
	for i in 160:
		var f := i / 159.0
		var is_ford := absf(f - 0.25) < 0.027 or absf(f - 0.75) < 0.027
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
	_woods(35, _keep())


# ------------------------------------------------------------------ pieces

## Every main base sits on high ground with one ramp down toward its natural (two with
## four players), so it can be walled off.
func _main_plateau() -> void:
	_plateau(Vector2(11, 9), Vector2(16, 13), [Vector2(17, 29), Vector2(39, 8)] if four() else [Vector2(17, 29)], true)


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


## A 3-wide ramp where the line from the plateau's middle toward `to` leaves it. The ramp
## is a clean rectangle on the grid that runs straight north-south or east-west, whichever
## is nearer the line. It lies in a notch on the low ground below a straight stretch of
## plateau edge, so the 3 high-ground cells just past its top (flanked by cliff) are its
## only way up and can be walled straight across.
func _ramp(from: Vector2, to: Vector2) -> void:
	var dir := (to - from).normalized()
	var p := from
	for i in 60:
		p += dir * 0.5
		var cell := Vector2i(int(p.x), int(p.y))
		if not g.in_map(cell) or height[g.idx(cell)] == 0:
			break
	# p is now just outside the plateau: the ramp runs across the edge, along the grid axis
	var axis := Vector2i(0, 1 if dir.y > 0 else -1) if absf(dir.y) >= absf(dir.x) else Vector2i(1 if dir.x > 0 else -1, 0)
	var side := Vector2i(absi(axis.y), absi(axis.x))
	var pc := Vector2i(int(p.x), int(p.y))
	# where the three lanes leave the high ground (steps downhill from pc; the plateau's
	# edge can be slanted, so they may leave it a step or two apart): the first one sets
	# the straight edge
	var edge := 99
	for w in range(-1, 2):
		var lane := pc + side * w
		var k := -8
		while k < 8 and g.in_map(lane + axis * k) and height[g.idx(lane + axis * k)] == 0:
			k += 1           # skip low ground behind (a plateau narrower than 8 cells)
		if k >= 8:
			continue         # this lane misses the plateau
		while k < 8 and g.in_map(lane + axis * k) and height[g.idx(lane + axis * k)] == 1:
			k += 1
		edge = mini(edge, k)
	if edge == 99:
		return
	# a straight edge five cells across: two rows of high ground above it, low ground below
	for w in range(-2, 3):
		for k in range(edge - 2, edge + 4):
			var cell := pc + side * w + axis * k
			if g.in_map(cell):
				height[g.idx(cell)] = 1 if k < edge else 0
				if w >= -1 and w <= 1 and k >= edge:
					ramp[g.idx(cell)] = 1


## Every ramp a clean rectangle along its slope: an end row narrower than the ramp (a
## single ramp tile straggling past the top or bottom) stops being ramp and becomes the
## high or low ground of that end, and so does a ramp tile sticking out sideways. Then the
## row just past either end can be walled straight across. Runs before _cliffs (ramp cells
## still carry the height they were drawn on; a custom map's are all low).
func _square_ramps() -> void:
	var d4: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var seen := PackedByteArray()
	seen.resize(W * H)
	for y in H:
		for x in W:
			var c0 := Vector2i(x, y)
			if ramp[g.idx(c0)] != 1 or seen[g.idx(c0)] == 1:
				continue
			var cells: Array = []
			var todo: Array = [c0]
			seen[g.idx(c0)] = 1
			while not todo.is_empty():
				var c: Vector2i = todo.pop_back()
				cells.append(c)
				for d in d4:
					var n: Vector2i = c + d
					if g.in_map(n) and ramp[g.idx(n)] == 1 and seen[g.idx(n)] == 0:
						seen[g.idx(n)] = 1
						todo.append(n)
			# downhill: from the high ground beside it toward the low ground beside it
			var hi := Vector2.ZERO
			var lo := Vector2.ZERO
			var hn := 0
			var ln := 0
			for c in cells:
				for d in d4:
					var n: Vector2i = c + d
					if not g.in_map(n) or ramp[g.idx(n)] == 1 or g.water[g.idx(n)] == 1:
						continue
					if height[g.idx(n)] == 1:
						hi += Vector2(n)
						hn += 1
					else:
						lo += Vector2(n)
						ln += 1
			if hn == 0 or ln == 0:
				continue
			var dv := lo / ln - hi / hn
			var vertical := absf(dv.y) >= absf(dv.x)
			var down := (1 if dv.y > 0 else -1) if vertical else (1 if dv.x > 0 else -1)
			# rows across the slope, keyed by their place along it
			var rows := {}
			for c in cells:
				var a: int = c.y if vertical else c.x
				if not rows.has(a):
					rows[a] = []
				rows[a].append(c.x if vertical else c.y)
			var keys: Array = rows.keys()
			keys.sort()
			if down < 0:
				keys.reverse()       # keys[0] is the top row
			# the ramp's width: the commonest row width (the wider on a tie)
			var count := {}
			for a in keys:
				var wv: int = rows[a].size()
				count[wv] = int(count.get(wv, 0)) + 1
			var width := 0
			for wv in count:
				if int(count[wv]) > int(count.get(width, 0)) or (int(count[wv]) == int(count.get(width, 0)) and wv > width):
					width = wv
			var cut: Array = []      # [cell, height it becomes]
			# narrow rows at either end
			while keys.size() > 1 and rows[keys[0]].size() < width:
				for s in rows[keys[0]]:
					cut.append([_cell(vertical, keys[0], s), 1])
				keys.pop_front()
			while keys.size() > 1 and rows[keys[-1]].size() < width:
				for s in rows[keys[-1]]:
					cut.append([_cell(vertical, keys[-1], s), 0])
				keys.pop_back()
			# tiles sticking out sideways: a row wider than the ramp keeps the stretch that
			# lines up best with the other rows
			var lanes := {}
			for a in keys:
				if rows[a].size() == width:
					for s in rows[a]:
						lanes[s] = int(lanes.get(s, 0)) + 1
			for a in keys:
				var r: Array = rows[a]
				if r.size() <= width:
					continue
				r.sort()
				var best: int = r[0]
				var best_v := -1
				for s0 in range(r[0], r[-1] - width + 2):
					var v := 0
					for s in range(s0, s0 + width):
						v += int(lanes.get(s, 0)) * 4 + (1 if r.has(s) else -100)
					if v > best_v:
						best_v = v
						best = s0
				for s in r:
					if s < best or s >= best + width:
						# it takes the ground on its outer side
						var out := _cell(vertical, a, s + (1 if s >= best + width else -1))
						var hgt := 0
						if g.in_map(out) and ramp[g.idx(out)] == 0:
							hgt = height[g.idx(out)]
						cut.append([_cell(vertical, a, s), hgt])
			for ch in cut:
				var i := g.idx(ch[0])
				ramp[i] = 0
				height[i] = ch[1]


func _cell(vertical: bool, a: int, s: int) -> Vector2i:
	return Vector2i(s, a) if vertical else Vector2i(a, s)


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
		if not g.in_map(c) or ramp[g.idx(c)] == 1 or ford[g.idx(c)] == 1 or _by_ramp(c) or _by_ramp(g._mirror(c, Vector2i.ONE)):
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


## A ramp cell within two cells (trees and rocks keep off a ramp and the ground at its ends).
func _by_ramp(c: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var n := c + Vector2i(dx, dy)
			if g.in_map(n) and ramp[g.idx(n)] == 1:
				return true
	return false


## How many rows at a ramp's top have their sides blocked (docs/ramp_funnel.md): the cells beside
## them sit under or against the drawn cliff wall, so a unit there looked as if it floated.
const FUNNEL := 2


## (tools only: the old open ramp sides, for before/after pictures)
static var no_funnel := false


static func funnel_rows(rows: int) -> int:
	return clampi(rows - 1, 0, FUNNEL)


## Every ramp on the map: {"cells", "down" (the grid step downhill), "side" (the step across),
## "rows" (top row first; each row's cells in order along `side`)}. Works before _cliffs (ramp
## cells still on the height they were drawn on) and after (the walkable high ground beside it).
static func ramp_parts(mg: MapGen) -> Array:
	var g: Game = mg.g
	var W: int = g.W
	var H: int = g.H
	var d4: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var seen := PackedByteArray()
	seen.resize(W * H)
	var out: Array = []
	for y in H:
		for x in W:
			var c0 := Vector2i(x, y)
			if mg.ramp[g.idx(c0)] != 1 or seen[g.idx(c0)] == 1:
				continue
			var cells: Array = []
			var todo: Array = [c0]
			seen[g.idx(c0)] = 1
			while not todo.is_empty():
				var c: Vector2i = todo.pop_back()
				cells.append(c)
				for d in d4:
					var n: Vector2i = c + d
					if g.in_map(n) and mg.ramp[g.idx(n)] == 1 and seen[g.idx(n)] == 0:
						seen[g.idx(n)] = 1
						todo.append(n)
			var hi := Vector2.ZERO
			var lo := Vector2.ZERO
			var hn := 0
			var ln := 0
			for c in cells:
				for d in d4:
					var n: Vector2i = c + d
					if not g.in_map(n) or mg.ramp[g.idx(n)] == 1 or g.water[g.idx(n)] == 1:
						continue
					if mg.height[g.idx(n)] == 1:
						if g.cliff[g.idx(n)] == 0:
							hi += Vector2(n)
							hn += 1
					else:
						lo += Vector2(n)
						ln += 1
			if hn == 0 or ln == 0:
				continue
			var dv := lo / ln - hi / hn
			var vertical := absf(dv.y) >= absf(dv.x)
			var down := Vector2i(0, 1 if dv.y > 0 else -1) if vertical else Vector2i(1 if dv.x > 0 else -1, 0)
			var side := Vector2i(1, 0) if vertical else Vector2i(0, 1)
			var by_row := {}
			for c in cells:
				var a: int = c.y if vertical else c.x
				if not by_row.has(a):
					by_row[a] = []
				by_row[a].append(c)
			var keys: Array = by_row.keys()
			keys.sort()
			if (down.y if vertical else down.x) < 0:
				keys.reverse()
			var rows: Array = []
			for a in keys:
				var r: Array = by_row[a]
				r.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return (p.x < q.x) if vertical else (p.y < q.y))
				rows.append(r)
			out.append({"cells": cells, "down": down, "side": side, "rows": rows})
	return out


## The ramp funnel (docs/ramp_funnel.md): beside each ramp's top FUNNEL rows, the low ground
## that lies under or against the drawn cliff wall (the cell past the top row's end is plateau)
## can't be walked on or built on, and no high ground beside a ramp can be walked on either. Only
## the walk and build grid changes (solid 1): the ground, the cliffs and the ramp are drawn as
## before. Run after the map is built and its decorations placed (Game._setup_astar); it can run
## again. Returns the cells it blocked.
func block_ramp_sides() -> Array:
	var out: Array = []
	if no_funnel:
		return out
	for r in ramp_parts(self):
		var side: Vector2i = r["side"]
		var down: Vector2i = r["down"]
		var rows: Array = r["rows"]
		var funnel := funnel_rows(rows.size())
		for k in 2:
			var step: Vector2i = -side if k == 0 else side
			var walled := true        # (the row above is walled on this side)
			for j in rows.size():
				var row: Array = rows[j]
				var c: Vector2i = (row[0] if k == 0 else row[-1]) + step
				if not g.in_map(c):
					continue
				var i := g.idx(c)
				if ramp[i] == 1 or g.water[i] == 1:
					walled = false
					continue
				var block := false
				if height[i] == 1:
					block = true      # high ground beside a ramp: no stepping on from the side
				elif j < funnel and walled:
					var above: Vector2i = c - down
					block = j > 0 or (g.in_map(above) and height[g.idx(above)] == 1 and ramp[g.idx(above)] == 0)
				if j < funnel:
					walled = walled and block
				if block and (g.solid[i] == 0 or g.solid[i] == 5 or g.ramp_block.has(i)):
					g.solid[i] = 1
					g.ramp_block[i] = true
					out.append(c)
	return out


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


# ------------------------------------------------------------------ named maps

const HALL := Vector2i(5, 4)                 # a hall spot's size in cells
var _noise_off := Vector2.ZERO


static func _v2i(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


func _reset() -> void:
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
	props.clear()
	_prop_at.clear()


## Smooth value noise in 0..1 (a random value every `cell` cells, blended between them).
func _noise(x: float, y: float, cell: float) -> float:
	var fx := x / cell + _noise_off.x
	var fy := y / cell + _noise_off.y
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := smoothstep(0.0, 1.0, fx - ix)
	var ty := smoothstep(0.0, 1.0, fy - iy)
	var top := lerpf(_hash01(ix, iy), _hash01(ix + 1, iy), tx)
	var bot := lerpf(_hash01(ix, iy + 1), _hash01(ix + 1, iy + 1), tx)
	return lerpf(top, bot, ty)


static func _hash01(a: int, b: int) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)


## The cell turned through the map's middle.
func _twin(c: Vector2i) -> Vector2i:
	return Vector2i(W - 1 - c.x, H - 1 - c.y)


## Build a named map (MapData.NAMED) with its own dice, so it always comes out the same.
## The pieces are drawn where they're listed and again turned through the middle; every
## base listed (side A) has its twin on side B.
func _named(map_id: String) -> Array:
	var m: Dictionary = MapData.NAMED[map_id]
	g.map_name = m["name"]
	var parts: PackedStringArray = String(m["biome"]).split("+")
	biome_a = parts[0]
	biome_b = parts[1] if parts.size() > 1 else parts[0]
	mix = String(m.get("mix", "patch"))
	water_set = String(m.get("water", ""))
	ford_set = String(m.get("ford", ""))
	rng = RandomNumberGenerator.new()
	rng.seed = int(m["seed"])
	_noise_off = Vector2(rng.randf_range(0, 100), rng.randf_range(0, 100))
	_reset()
	# hall spots: side A's, then their twins (in the same order)
	var mains: Array = []
	var nats: Array = []
	for b in m["bases"]:
		mains.append(_v2i(b["hall"]))
		nats.append(_v2i(b["nat"]))
	var k := mains.size()
	for i in k:
		mains.append(g._mirror(mains[i], HALL))
		nats.append(g._mirror(nats[i], HALL))
	var sites: Array = mains + nats
	for t in m.get("thirds", []):
		sites.append(_v2i(t))
		sites.append(g._mirror(_v2i(t), HALL))
	var keep: Array = []
	for st in sites:
		keep.append([Vector2(st) + Vector2(2.5, 2), 9.0])
	# high ground first (hills, mesas, ridges), then each main's plateau and its one ramp
	for f in m.get("pieces", []):
		_piece(f, keep, 0)
	for b in m["bases"]:
		var hall := _v2i(b["hall"])
		var hill: Array = b.get("hill", [])
		var c := Vector2(hall) + Vector2(2.5, 2.0)
		if hill.size() >= 2:
			c = Vector2(hill[0], hill[1])
		var r := Vector2(13, 11)
		if hill.size() >= 4:
			r = Vector2(hill[2], hill[3])
		var rp: Array = b["ramp"]
		_plateau(c, r, [Vector2(rp[0], rp[1])], true)
	# then water, woods and clearings
	for f in m.get("pieces", []):
		_piece(f, keep, 1)
	_woods(int(m.get("woods", 0)), keep)
	for f in m.get("pieces", []):
		_piece(f, keep, 2)
	_symmetrize()
	_square_ramps()
	_cliffs()
	# the hall spots themselves are always open ground
	for st in sites:
		for y in range(st.y - 1, st.y + HALL.y + 1):
			for x in range(st.x - 1, st.x + HALL.x + 1):
				var c := Vector2i(x, y)
				if g.in_map(c) and g._terrain_kind.has(g.idx(c)):
					g.solid[g.idx(c)] = 0
					g._terrain_kind.erase(g.idx(c))
	g.base_sites = sites
	_assign_named(mains, nats)
	_decorate(rng, m.get("sites", []), float(m.get("decor", 1.0)))
	_clear_mains(mains)
	_thin_sites(sites)
	_open_ways(sites)
	g.height = height
	g.ramp = ramp
	return [String(m.get("layout", "named")), String(m["biome"])]


## Who starts where on a named map: side A's bases are one group, their twins the other.
## Each team (largest first) takes the group with the most room, so allies sit together
## and every player's twin spot goes to the other side; spots nobody takes stay free
## (a main nobody starts in is an expansion on high ground). Returns each player's spot
## (0..k-1 side A, k..2k-1 their twins in the same order).
static func spot_order(k: int, sides: Array) -> Array:
	var free: Array = [range(k), range(k, 2 * k)]
	var teams := {}
	for t in sides.size():
		var sd: int = int(sides[t])
		if not teams.has(sd):
			teams[sd] = []
		teams[sd].append(t)
	var order: Array = teams.keys()
	order.sort_custom(func(a: int, b: int) -> bool:
		return teams[a].size() > teams[b].size() or (teams[a].size() == teams[b].size() and a < b))
	var out: Array = []
	out.resize(sides.size())
	out.fill(0)
	for sd in order:
		var gi := 0 if (free[0] as Array).size() >= (free[1] as Array).size() else 1
		for t in teams[sd]:
			if (free[gi] as Array).is_empty():
				gi = 1 - gi
			if (free[gi] as Array).is_empty():
				break         # more players than spots (the lobby doesn't allow it)
			out[t] = (free[gi] as Array).pop_front()
	return out


## Where each player's hall goes on a named map (for the lobby's preview).
static func named_starts(map_id: String, sides: Array) -> Array:
	var m: Dictionary = MapData.NAMED[map_id]
	var sz := size_of(map_id)
	var mains: Array = []
	for b in m["bases"]:
		mains.append(_v2i(b["hall"]))
	var k := mains.size()
	for i in k:
		mains.append(Vector2i(sz.x - mains[i].x - HALL.x, sz.y - mains[i].y - HALL.y))
	var out: Array = []
	for spot in spot_order(k, sides):
		out.append(mains[spot])
	return out


func _assign_named(mains: Array, nats: Array) -> void:
	var sides: Array = []
	for t in g.n_players():
		sides.append(int(g.sides[t]) if t < g.sides.size() else t)
	g.starts = []
	g.expansions = []
	for spot in spot_order(mains.size() / 2, sides):
		g.starts.append(mains[spot])
		g.expansions.append(nats[spot])


## One piece of a named map, drawn where it's listed and turned onto the other side.
## pass 0: high ground ("hill" with ramps, "mesa" without, "ridge": a cliff wall along a
## line); pass 1: "lake", "river" (with fords), "forest" / "rocks" (clumps), "treeline";
## pass 2 (after the random woods): "clear" (open ground).
func _piece(f: Array, keep: Array, pass_no: int) -> void:
	var kind: String = f[0]
	match kind:
		"hill":
			if pass_no == 0:
				var ramps: Array = []
				for p in f[5]:
					ramps.append(Vector2(p[0], p[1]))
				_plateau(Vector2(f[1], f[2]), Vector2(f[3], f[4]), ramps, true)
		"mesa":
			if pass_no == 0:
				_plateau(Vector2(f[1], f[2]), Vector2(f[3], f[4]), [], true)
		"ridge":
			if pass_no == 0:
				for c in _along(f[1], float(f[2])):
					for cc in [c, _twin(c)]:
						height[g.idx(cc)] = 1
		"lake":
			if pass_no == 1:
				_pond(Vector2(f[1], f[2]), Vector2(f[3], f[4]), keep)
		"river":
			if pass_no == 1:
				_river(f[1], float(f[2]), f[3] if f.size() > 3 else [], float(f[4]) if f.size() > 4 else 3.0, keep)
		"forest", "rocks":
			if pass_no == 1:
				_clump(Vector2(f[1], f[2]), Vector2(f[3], f[4]), float(f[5]) if f.size() > 5 else 0.5, "tree" if kind == "forest" else "rock", keep)
		"treeline":
			if pass_no == 1:
				var gaps: Array = f[3] if f.size() > 3 else []
				var gl: float = float(f[4]) if f.size() > 4 else 3.0
				var tk: String = String(f[5]) if f.size() > 5 else "tree"
				for c in _along(f[1], float(f[2]), gaps, gl):
					_solid_at(c, tk, keep)
		"clear":
			if pass_no == 2:
				var c0 := Vector2(f[1], f[2])
				var r: float = f[3]
				for y in range(int(c0.y - r) - 1, int(c0.y + r) + 2):
					for x in range(int(c0.x - r) - 1, int(c0.x + r) + 2):
						var c := Vector2i(x, y)
						if g.in_map(c) and Vector2(c).distance_to(c0) <= r:
							for cc in [c, _twin(c)]:
								if g._terrain_kind.has(g.idx(cc)):
									g.solid[g.idx(cc)] = 0
									g._terrain_kind.erase(g.idx(cc))


## The cells within half of `width` of a line through `pts`, but for the stretches around
## each of `gaps` (fractions along its length, each `gap_len` cells long): a cell belongs to
## the stretch of the line nearest to it, so a gap runs clean across.
func _along(pts: Array, width: float, gaps: Array = [], gap_len := 3.0) -> Array:
	var segs: Array = []
	var total := 0.0
	for i in pts.size() - 1:
		var a := Vector2(pts[i][0], pts[i][1])
		var b := Vector2(pts[i + 1][0], pts[i + 1][1])
		segs.append([a, b, total])
		total += a.distance_to(b)
	var best := {}          # cell -> [distance to the line, how far along it]
	var hw := width * 0.5
	var d := 0.0
	while d <= total:
		var p := Vector2.ZERO
		for sg in segs:
			var sl: float = (sg[0] as Vector2).distance_to(sg[1])
			if d >= float(sg[2]) - 0.001 and d <= float(sg[2]) + sl + 0.001:
				p = (sg[0] as Vector2).lerp(sg[1], clampf((d - float(sg[2])) / maxf(sl, 0.001), 0.0, 1.0))
				break
		for y in range(int(p.y - hw) - 1, int(p.y + hw) + 2):
			for x in range(int(p.x - hw) - 1, int(p.x + hw) + 2):
				var c := Vector2i(x, y)
				var dd := (Vector2(c) + Vector2(0.5, 0.5)).distance_to(p)
				if g.in_map(c) and dd <= hw + 0.15 and (not best.has(c) or dd < float(best[c][0])):
					best[c] = [dd, d]
		d += 0.4
	var out: Array = []
	for c in best:
		var skip := false
		for gp in gaps:
			if absf(float(best[c][1]) - float(gp) * total) < gap_len * 0.5:
				skip = true
		if not skip:
			out.append(c)
	return out


func _in_keep(c: Vector2i, keep: Array) -> bool:
	for k in keep:
		if (Vector2(c) + Vector2(0.5, 0.5)).distance_to(k[0]) < k[1]:
			return true
	return false


## A tree or rock on this cell and its twin (not on ramps, fords, water or by a hall).
func _solid_at(c: Vector2i, kind: String, keep: Array) -> void:
	if not g.in_map(c) or ramp[g.idx(c)] == 1 or ford[g.idx(c)] == 1 or _by_ramp(c) or _by_ramp(_twin(c)) or _in_keep(c, keep):
		return
	for cc in [c, _twin(c)]:
		if g.water[g.idx(cc)] == 1:
			continue
		g.solid[g.idx(cc)] = 1
		g._terrain_kind[g.idx(cc)] = kind


## A lake with a ragged shore, on low ground away from the halls.
func _pond(c: Vector2, r: Vector2, keep: Array) -> void:
	for y in range(int(c.y - r.y) - 2, int(c.y + r.y) + 3):
		for x in range(int(c.x - r.x) - 2, int(c.x + r.x) + 3):
			var cell := Vector2i(x, y)
			if not g.in_map(cell):
				continue
			var q := Vector2((x + 0.5 - c.x) / r.x, (y + 0.5 - c.y) / r.y)
			if q.length() > 0.85 + _noise(x, y, 2.5) * 0.3:
				continue
			for m in [cell, _twin(cell)]:
				if height[g.idx(m)] == 0 and ramp[g.idx(m)] == 0 and not _in_keep(m, keep):
					g.water[g.idx(m)] = 1
					g.solid[g.idx(m)] = 1


## A river along `pts`, `width` across, with fords (fractions along it) `ford_len` long.
func _river(pts: Array, width: float, fords: Array, ford_len: float, keep: Array) -> void:
	var dry := {}
	for c in _along(pts, width, fords, ford_len):
		dry[c] = true
	for c in _along(pts, width):
		var is_ford := not dry.has(c)
		for m in [c, _twin(c)]:
			var i := g.idx(m)
			if height[i] == 1 or ramp[i] == 1 or _in_keep(m, keep):
				continue
			if is_ford:
				ford[i] = 1
				g.water[i] = 0
				g.solid[i] = 0
			elif ford[i] == 0:
				g.water[i] = 1
				g.solid[i] = 1


## A clump of trees (or rocks) filling part of an ellipse, in noisy blobs.
func _clump(c: Vector2, r: Vector2, density: float, kind: String, keep: Array) -> void:
	for y in range(int(c.y - r.y) - 1, int(c.y + r.y) + 2):
		for x in range(int(c.x - r.x) - 1, int(c.x + r.x) + 2):
			var cell := Vector2i(x, y)
			if not g.in_map(cell):
				continue
			var q := Vector2((x + 0.5 - c.x) / r.x, (y + 0.5 - c.y) / r.y).length()
			if q > 1.0:
				continue
			if _noise(x, y, 2.2) * (1.15 - q * 0.5) > 1.0 - density:
				_solid_at(cell, kind, keep)


## Every cell takes the value of its twin in the first half (the pieces were drawn on
## both sides; this just makes the two halves match exactly).
func _symmetrize() -> void:
	var n := W * H
	for i in n:
		var j := n - 1 - i
		if j >= i:
			continue
		height[i] = height[j]
		ramp[i] = ramp[j]
		ford[i] = ford[j]
		g.water[i] = g.water[j]
		g.solid[i] = g.solid[j]
		if g._terrain_kind.has(j):
			g._terrain_kind[i] = g._terrain_kind[j]
		else:
			g._terrain_kind.erase(i)


## Every hall spot can be walked to from the first: where trees, rocks or decorations shut
## a way (never water or cliffs), the fewest of them are cleared (and their twins).
func _open_ways(sites: Array) -> void:
	var from: Vector2i = sites[0] + Vector2i(2, 2)
	for st in sites:
		var to: Vector2i = st + Vector2i(2, 2)
		# 0-1 search: open ground costs nothing, a removable obstacle costs one
		var dist := PackedInt32Array()
		dist.resize(W * H)
		dist.fill(1 << 30)
		var par := PackedInt32Array()
		par.resize(W * H)
		par.fill(-1)
		var later: Array = [from]
		var now: Array = []
		dist[g.idx(from)] = 0
		var head := 0
		var found := false
		while not found and (head < later.size() or not now.is_empty()):
			var c: Vector2i
			if not now.is_empty():
				c = now.pop_back()
			else:
				c = later[head]
				head += 1
			if c == to:
				found = true
				break
			var dc := dist[g.idx(c)]
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dd
				if not g.in_map(n):
					continue
				var i := g.idx(n)
				var cost := 0
				if g.solid[i] != 0:
					if g.water[i] == 1 or g.cliff[i] == 1 or not g._terrain_kind.has(i):
						continue
					cost = 1
				if dc + cost < dist[i]:
					dist[i] = dc + cost
					par[i] = g.idx(c)
					if cost == 0:
						now.append(n)
					else:
						later.append(n)
		var ti := g.idx(to)
		if dist[ti] >= 1 << 30:
			push_warning("%s: hall spot %s can't be reached" % [g.map_name, st])
			continue
		var i := ti
		while i >= 0:
			if g.solid[i] != 0 and g._terrain_kind.has(i):
				for cc in [Vector2i(i % W, i / W), _twin(Vector2i(i % W, i / W))]:
					_clear_cell(g.idx(cc))
			i = par[i]


## Every main base is all buildable: no tree, rock or solid decoration anywhere on the
## plateau a main hall spot stands on (the high ground joined to it, up to MAIN_REACH cells
## from the hall; cliffs and ramps stay as they are), or within MAIN_REACH - 4 cells of a
## main on low ground. Walk-through decorations (grass...) may stay.
const MAIN_REACH := 22.0


func main_area(st: Vector2i) -> Array:
	var c0 := st + Vector2i(2, 2)
	var mid := Vector2(st) + Vector2(2.5, 2.0)
	var out: Array = []
	if not g.in_map(c0):
		return out
	if height[g.idx(c0)] == 1:
		var seen := {g.idx(c0): true}
		var todo: Array = [c0]
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			out.append(c)
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dd
				if not g.in_map(n) or seen.has(g.idx(n)) or height[g.idx(n)] != 1 or ramp[g.idx(n)] == 1:
					continue
				if (Vector2(n) + Vector2(0.5, 0.5)).distance_to(mid) > MAIN_REACH:
					continue
				seen[g.idx(n)] = true
				todo.append(n)
		return out
	var r := MAIN_REACH - 4.0
	for y in range(int(mid.y - r) - 1, int(mid.y + r) + 2):
		for x in range(int(mid.x - r) - 1, int(mid.x + r) + 2):
			var c := Vector2i(x, y)
			if g.in_map(c) and (Vector2(c) + Vector2(0.5, 0.5)).distance_to(mid) <= r:
				out.append(c)
	return out


var main_cleared := 0              # blocking cells _clear_mains took off the main bases (tests)


func _clear_mains(mains: Array) -> void:
	main_cleared = 0
	for st in mains:
		for c in main_area(st):
			var i := g.idx(c)
			if g._terrain_kind.has(i) and g.cliff[i] == 0 and g.water[i] == 0:
				main_cleared += 1
				_clear_cell(i)


## Around every base and expansion spot the woods are thinned: within THIN_REACH cells of a
## hall spot only about one tree or rock in THIN_KEEP stays (picked by a hash of the cell and
## its twin, so both sides keep the same ones), scattered, so the ground is open to build on.
const THIN_REACH := 15.0
const THIN_KEEP := 5
var thinned := 0                   # blocking cells _thin_sites took off (tests)


func _thin_sites(sites: Array) -> void:
	thinned = 0
	for st in sites:
		var mid := Vector2(st) + Vector2(2.5, 2.0)
		var r := int(THIN_REACH) + 1
		for y in range(int(mid.y) - r, int(mid.y) + r + 1):
			for x in range(int(mid.x) - r, int(mid.x) + r + 1):
				var c := Vector2i(x, y)
				if not g.in_map(c) or (Vector2(c) + Vector2(0.5, 0.5)).distance_to(mid) > THIN_REACH:
					continue
				var i := g.idx(c)
				if not g._terrain_kind.has(i) or g.cliff[i] != 0 or g.water[i] != 0:
					continue
				var t := _twin(c)
				var key := mini(i, g.idx(t)) if g.in_map(t) else i
				if hash(key * 7919 + 13) % THIN_KEEP == 0:
					continue
				thinned += 1
				_clear_cell(i)


func _clear_cell(i: int) -> void:
	if _prop_at.has(i):
		var pr: Dictionary = props[_prop_at[i]]
		pr["dead"] = true
		for c in pr["cells"]:
			g.solid[g.idx(c)] = 0
			g._terrain_kind.erase(g.idx(c))
			_prop_at.erase(g.idx(c))
		return
	g.solid[i] = 0
	g._terrain_kind.erase(i)


# ------------------------------------------------------------------ decorations

## Groups of decorations: [prop, dx, dy] in cells from the group's middle.
const KITS := {
	"farm": [["cottage", 0, 0], ["haystack", 3, 1], ["well", -3, 1], ["fence", -1, 2], ["fence_b", 1, 2], ["cart_a", 3, -2],
		["scarecrow", 5, 2], ["beehive", -2, -2], ["sacks", 2, 0], ["haybales", 4, 3]],
	"village": [["chapel", 0, 0], ["cottage", 4, 1], ["windmill", -4, -1], ["well", 1, 3], ["stall", -3, 3], ["cart_b", 4, 4],
		["sacks_pile", 6, 0], ["crates_pair", -1, 5], ["barrel_a", 2, 2], ["banner_a", -2, 1]],
	"camp": [["tent_white", 0, 0], ["tent_red", 3, -1], ["tent_blue", -3, 1], ["campfire", 0, 2], ["spit_roast", 2, 2],
		["crate_b", -2, -1], ["barrel_a", -2, 3], ["flag", 5, 1], ["wagon", 4, 3], ["table", -1, 4], ["cannonballs", 1, 4]],
	"ruins": [["ruin_keep", 0, 0], ["arch", 4, 1], ["ruin_pillar", -3, 2], ["column", 2, 3], ["ruin_wall", -4, -1],
		["stones", 1, 2], ["rocks_moss", -1, 3], ["cross_stone", 4, -2], ["stone_block", -5, 2]],
	"shrine": [["shrine", 0, 0], ["cross_stone", 2, 0], ["flowers", -1, 1], ["banner_b", -2, -1], ["stones", 1, 1],
		["flowers_pink", 2, 2], ["column", -3, 1]],
	"market": [["stall", 0, 0], ["stall_small", 3, 0], ["table_long", -3, 1], ["crate_apples", 1, 2], ["barrel_b", -1, 2],
		["sacks", 4, 2], ["cart_c", -4, 3], ["crate_greens", 2, 3], ["jar", -2, 3], ["signpost", 5, -1]],
	"snowcamp": [["snow_rocks_b", 0, 0], ["tent_white", 3, 1], ["campfire", 1, 2], ["barrel_a", -1, 2], ["crate_a", 4, 3],
		["dead_trunk", -3, 1], ["snow_rocks_a", -4, 3], ["sticks", 2, 4]],
	"wreck": [["boat", 0, 0], ["anchor", 2, 1], ["barrel_e", -1, 1], ["crate_e", 1, -1], ["drying_rack", -2, -1],
		["log", 3, -1], ["crate_long", -3, 2]],
	"grove": [["flower_arch", 0, 0], ["bush_lilac", 2, 0], ["flowers_pink", -1, 1], ["bench", 1, 2], ["beehive", -2, 2],
		["flowers_mix", 3, 2], ["bush_flower", -3, 0]],
	"watch": [["watch_frame", 0, 0], ["banner_pole", 2, 0], ["campfire", 0, 2], ["crate_c", -2, 1], ["barrel_c", 2, 2], ["firewood", -1, 3]],
	"lumber": [["stump_big", 0, 0], ["log", 2, 1], ["log_moss", -2, 1], ["firewood", 1, -1], ["sticks", -1, 2], ["cart_a", 3, 3],
		["stump", -3, -1], ["stump_moss", 4, -1]],
	"forge": [["forge", 0, 0], ["oven", 3, 0], ["cannonballs", -2, 1], ["barrel_tall", 1, 2], ["crate_d", -1, 3], ["chest", 3, 2]],
}


## Can a decoration stand on this cell? Open ground only: not water, a ford, a cliff or a
## ramp, nor next to a ramp, nor on any hall's land (solid ones keep further off).
func _deco_ok(c: Vector2i, solid: bool) -> bool:
	if c.x < 1 or c.y < 1 or c.x > W - 2 or c.y > H - 2:
		return false
	var i := g.idx(c)
	if g.solid[i] != 0 or g.water[i] == 1 or ford[i] == 1 or ramp[i] == 1 or g.cliff[i] == 1:
		return false
	var rr := 3 if solid else 2
	for dy in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var n := c + Vector2i(dx, dy)
			if g.in_map(n) and (ramp[g.idx(n)] == 1 or (solid and (ford[g.idx(n)] == 1 or g.cliff[g.idx(n)] == 1))):
				return false
	for st in g.base_sites:
		if (Vector2(c) + Vector2(0.5, 0.5)).distance_to(Vector2(st) + Vector2(2.5, 2.0)) < (13.0 if solid else 12.0):
			return false
	return true


## Put a decoration on this cell, and its twin on the twin cell. Solid ones block the
## cells under their foot, like rocks.
func _put(name: String, c: Vector2i, drng: RandomNumberGenerator) -> bool:
	if not PropData.PROPS.has(name):
		return false
	var w: int = PropData.PROPS[name][2]
	var foot: Array = []
	if w > 0:
		for dx in range(-(w - 1) / 2, w - (w - 1) / 2):
			foot.append(c + Vector2i(dx, 0))
			if w >= 3:
				foot.append(c + Vector2i(dx, -1))
	else:
		foot = [c]
	for fc in foot:
		if not _deco_ok(fc, w > 0) or not _deco_ok(_twin(fc), w > 0):
			return false
	var jit := Vector2(drng.randf_range(-6, 6), drng.randf_range(-4, 4)) if w == 0 else Vector2.ZERO
	var flip := drng.randf() < 0.5
	for side in 2:
		var cells: Array = []
		var sx := 0.0
		var low := -1
		for fc in foot:
			var cc: Vector2i = fc if side == 0 else _twin(fc)
			cells.append(cc)
			sx += cc.x + 0.5
			low = maxi(low, cc.y)
		var pos := Vector2(sx / foot.size(), low + 1.0) * Defs.TILE + Vector2(0, -5) + jit
		var pr := {"name": name, "pos": pos, "cells": cells if w > 0 else [], "at": cells[0], "dead": false, "flip": flip != (side == 1)}
		var ix := props.size()
		props.append(pr)
		if w > 0:
			for cc in cells:
				g.solid[g.idx(cc)] = 1
				g._terrain_kind[g.idx(cc)] = "prop"
				_prop_at[g.idx(cc)] = ix
		if c == _twin(c):
			break
	return true


## Decorate the map: the listed groups ([x, y, kit] on side A), a couple of the biome's
## own groups when none are listed, and small things strewn over open ground;
## `density` 1 = normal.
func _decorate(drng: RandomNumberGenerator, sites: Array, density: float) -> void:
	if density <= 0.0:
		return
	var groups: Array = []
	for s in sites:
		groups.append([Vector2i(int(s[0]), int(s[1])), String(s[2])])
	if sites.is_empty():
		for n in 2:
			for attempt in 40:
				var c := Vector2i(drng.randi_range(6, W - 7), drng.randi_range(6, H - 7))
				var kits: Array = BIOMES[biome_at(c.x, c.y)].get("kits", [])
				if kits.is_empty() or not _deco_ok(c, true):
					continue
				var far := Vector2(c).distance_to(Vector2(_twin(c))) >= 12.0
				for gp in groups:
					if Vector2(gp[0]).distance_to(Vector2(c)) < 14.0 or Vector2(_twin(gp[0])).distance_to(Vector2(c)) < 14.0:
						far = false
				if far:
					groups.append([c, kits[drng.randi() % kits.size()]])
					break
	for gp in groups:
		for it in KITS.get(gp[1], []):
			_put(String(it[0]), gp[0] + Vector2i(int(it[1]), int(it[2])), drng)
	var n := int(W * H / 55.0 * density)
	for k in n:
		var c := Vector2i(drng.randi_range(1, W - 2), drng.randi_range(1, H - 2))
		var sc: Array = BIOMES[biome_at(c.x, c.y)].get("scatter", [])
		if sc.is_empty():
			continue
		var name: String = sc[drng.randi() % sc.size()]
		_put(name, c, drng)
