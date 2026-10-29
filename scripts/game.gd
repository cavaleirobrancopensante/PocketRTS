class_name Game
extends Node2D
## The match: map, pathfinding, entities, economy, combat helpers, fog of war,
## selection and commands. UI (hud.gd), input (controls.gd) and the AI (ai.gd)
## all talk to this node.

signal ended(winner: int)

## The map's size in cells: set from the map before the match is built (MapGen.size_of);
## 110 x 80 for the classic maps (MapGen.CLASSIC; 84 x 60 before 0.15.0), a custom map's own.
static var W := 110
static var H := 80
const T := Defs.TILE
const HASH := 64

static var _tex_cache := {}

var human := 0
var puppet := false                  # online guest: the host plays the match, this game only shows it (NetPuppet)
var net: NetSession = null           # online: the session (host or guest), else null
var rec: ReplayRecorder = null       # the replay being recorded (scripts/replay/replay_recorder.gd), else null
var net_next := 1                    # the next net id (NetSession.assign: the online session and the recorder share it)
var replay: ReplayPlayer = null      # watching a replay: this game is a puppet fed from the file (replay_player.gd)
var factions: Array = ["crown", "crown"]
var colours: Array = [0, 1]                 # each player's index into Defs.PALETTE
var sides: Array = [0, 1]                   # players on the same side are allies
var income_mult: Array = []                 # the Brutal AI's cheat (1.0 = fair)
## THE NEW BROOD (experiment, scripts/brood_new.gd): per side, true when its slot picked "brood_new" (it plays as the
## Brood: factions[t] is "brood"); the Mother of each such side (looked up), the Rootmaws' ground spots (id -> {p, left,
## maw: the serial of the Rootmaw rooted there or 0}).
var nb_teams: Array = []
var nb_queen := {}
var nb_spots := {}
var nb_spot_next := 0
var nb_walls: Array = []       # (no longer filled: a rooted creature's footprint on the grid does it, nb_fp; BroodNew.push_out kept for old saves)
var nb_fp: Array = []          # the new Brood's ROOTED creatures (and cocoons): each takes its footprint on the grid as a building (scripts/brood_root.gd)
var nb_cells := {}             # cell index -> the team of the rooted new-Brood creature whose footprint holds it (its own side's hatchlings walk through: BroodRoot.pass_move)
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


## A unit that can hurt you back (not a worker, a Missionary, a horse, a Powder Wagon...):
## units on their own go for these first (find_target), then other units, then buildings.
static func fights_back(e) -> bool:
	return e is Unit and not e.dead and not e.is_worker() and not e._d_noatk and not e._d_medic


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
var swamp_layer_b: Node2D      # (the second player's swamp: its own layer so its shimmer takes that player's colour)
var field_layer: Node2D                  # Clockwork fields of the selected / placed building
var line_net: LineNetwork                # the Clockwork Line: pipe segments and pressure (scripts/line.gd; shelved: Defs.line_mode)
var gear_net: GearNet                    # the Clockwork gear field: rings of ground gears, connection graph (scripts/gear.gd)
var swamp_img: Image                     # the swamp of every Brood player, for the minimap
var swamp_tex: ImageTexture
var _swamp_t := 0.0
var _notify_t := 0
var difficulty := 1
var demo := false                        # AI controls both sides
var start_edge_layout := true            # the starting economy buildings hug the edge of the main (false: the old "behind the hall" spot; tests compare)
var edit_mode := false                   # the map editor: just the ground, no players
var sandbox := false                     # the sandbox: spawn anything, any player
var reveal := false                      # sandbox: no fog of war
var rng := RandomNumberGenerator.new()

var solid := PackedByteArray()           # 0 free, 1 terrain, 2 building, 3 gate, 4 wall, 5 farm field (walkable, not buildable)
var water := PackedByteArray()
var height := PackedByteArray()          # 1 = high ground
var ramp := PackedByteArray()
var rails: Array = []                    # the ramp rails (MapGen.ramp_rails): low walls down a ramp's sides that no unit crosses
var rail_bits := PackedByteArray()       # per cell: its sides with a rail (1 east, 2 west, 4 south, 8 north)
var rail_side := {}                      # map index -> true: a cell across a rail from a ramp, shut in the pathfinder grids (path_cell)
var rail_layer: RampRails                # draws the rails
var cliff := PackedByteArray()
var map_id := "random"
var map_name := ""
var mapgen: MapGen
var astar := AStarGrid2D.new()
var astar_siege := AStarGrid2D.new()     # walls and gates counted as open: the way to break in
var units: Array = []
var buildings: Array = []
var crates: Array = []                   # Clockwork crates dropped on the way to their sites (Crate)
var kegs: Array = []                     # powder kegs dropped by haulers who could not deliver them (PowderKeg)
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
var ghost_layer: Node2D        # the placement ghost's pictures, over the overlay, in the side's colours (team shader)
var _ghosts: Array = []        # what it draws: [texture, position, region (size 0: all of it)]
var build_grid := BuildGrid.new()      # the planning grid while placing (BuildGrid)
var controls: Node
var hud: Control
var ais: Array = []

var selection: Array = []
var groups: Array = [[], [], [], [], [], [], [], [], [], []]   # control groups 1-9 and 0 (kept in the autosave)
## The computer keeps spots for buildings it means to lay soon (team -> {kind -> {"cell", "t", "spring"}}): its own other
## buildings are not put where they would take such a spot or cut into its ring (placement_problem with `ai`). Used for the
## Escapement and the Heavy Works' big ring by a Mainspring (AI._keep_heavy, 0.14.94). Not saved: the computer works it
## out again.
var ai_keep := {}
var cam_slots: Array = [null, null, null, null, null, null, null]   # camera hotkeys F4-F10: [position, zoom] or null (kept in the autosave)
var _hash := {}
var _path_queue: Array = []
var _end_t := 0.0
var over := false
var map_view := false                   # VIEW MAP on the battle report: the match is over but the camera and selection work
var winner := -1
var clock := 0.0
var stats: Array = []
var soil_scars: Array = []               # [centre, soil left, hall kind, lode left] where a Town Hall, Hive or Clocktower fell
var pit_spots: Array = []                # OLD GROUND: [centre (px), biomass left, team] where a Feeding Pit fell (Defs.PIT_CLAIM circles)
var _sample_t := 0.0
var mlog: MatchLog              # the playtest log (copied from the end screen)
var chat: Chat                  # the in-game chat (YOU and the computers; the log lines go to mlog)
var end_note := ""              # how the match ended, for the log: "", "player_surrender", "ai_resigned"
var end_ahead := ""             # on a player surrender: "ahead", "behind" or "about even" (worked out at that moment)
var end_quitter := -1           # on a player surrender: the team that gave up
## Online host: while a guest's order runs (NetCommands.apply), the team and relay id it came from (-1: none). The
## order's marker and voice are the guest's own (shown on its screen, not here), its messages go to the guest (tell),
## and what it may click on is what that side sees, not this screen's fog (shown_to_commander).
var net_cmd_team := -1
var net_cmd_peer := -1
## Online: no ring or voice from the order running now (a guest's, or the host's own held one: both were shown at the
## click). input_cmd: the local player's input is being handled (Controls, HUD): with the same delay for both players
## the host's own orders made now wait (NetCommands.hold); the computers' and the game's own never do.
var net_quiet := false
var input_cmd := false
var resigned: Array = []        # computers that resigned after a gg
var _first_of := {}             # "team:kind" -> true once that player has had one


static func _new_stats() -> Dictionary:
	return {"lost": 0, "killed": 0, "gold": 0, "spent": 0, "trained": 0, "built": 0,
		"razed": 0, "bld_lost": 0, "damage": 0.0, "peak_army": 0, "value_killed": 0, "res2_in": 0.0, "sacrificed": 0, "sacrifice_essence": 0, "revived": 0,
		"horses_bolted": 0, "horses_caught": 0, "kills_by": {}, "army_tl": [0], "gold_tl": [0], "workers_tl": [0]}


static func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		# (the Clockwork roster prototype's units with no sheet yet are drawn in code: scripts/cw_art.gd)
		_tex_cache[path] = CwArt.texture(path) if CwArt.is_placeholder(path) else load(path)
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
	swamp_layer.draw.connect(_draw_swamp.bind(0))
	swamp_layer.material = _swamp_material()
	add_child(swamp_layer)
	swamp_layer_b = Node2D.new()
	swamp_layer_b.z_index = -19
	swamp_layer_b.draw.connect(_draw_swamp.bind(1))
	swamp_layer_b.material = _swamp_material()
	add_child(swamp_layer_b)
	field_layer = Node2D.new()
	field_layer.z_index = -18
	field_layer.draw.connect(_draw_fields)
	add_child(field_layer)
	line_net = LineNetwork.new()
	line_net.game = self
	add_child(line_net)
	gear_net = GearNet.new()
	gear_net.game = self
	gear_net.z_index = -17
	add_child(gear_net)
	ground_marks = GroundMarks.new()
	ground_marks.game = self
	ground_marks.z_index = -16          # on the ground: over the gears and fields, under every building and unit
	add_child(ground_marks)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	swipe_marks = GroundMarks.new()
	swipe_marks.game = self
	swipe_marks.top = true
	swipe_marks.z_index = 2             # the Pendulum's smear: over the units it cuts through
	add_child(swipe_marks)
	powder_smoke = PowderSmoke.new()        # black powder smoke (looks only: scripts/powder_smoke.gd)
	powder_smoke.setup(self, 0 if edit_mode else (PowderSmoke.force if PowderSmoke.force >= 0 else Settings.powder_smoke_level()))
	add_child(powder_smoke)
	body_bars = Node2D.new()
	body_bars.z_index = 1
	body_bars.draw.connect(_draw_body_bars)
	add_child(body_bars)
	stun_layer = StunMark.new()          # the stars over stunned units' heads (scripts/stun_mark.gd)
	stun_layer.game = self
	add_child(stun_layer)
	overlay = Node2D.new()
	overlay.z_index = 50
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	ghost_layer = Node2D.new()
	ghost_layer.material = ShaderMaterial.new()
	(ghost_layer.material as ShaderMaterial).shader = Entity.TEAM_SHADER
	ghost_layer.draw.connect(_draw_ghosts)
	overlay.add_child(ghost_layer)
	fog_sprite = Sprite2D.new()
	fog_sprite.centered = false
	fog_sprite.scale = Vector2(T, T)
	fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fog_sprite.z_index = 40
	add_child(fog_sprite)
	camera = Camera2D.new()
	# the view may go CAMERA_MARGIN_TILES past every edge (the dark clear colour out there);
	# the -40 / +170 leave room for the top bar and the bottom HUD as before
	var cm := Defs.CAMERA_MARGIN_TILES * T
	camera.limit_left = -cm
	camera.limit_top = -40 - cm
	camera.limit_right = W * T + cm
	camera.limit_bottom = H * T + 170 + cm
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS      # (physics interpolation is on: Godot forces this anyway, with a WARNING each match)
	add_child(camera)
	camera.make_current()
	_generate_map()
	_setup_astar()
	_render_ground()
	if not edit_mode:
		# the best free hall spots of each side, tinted on the ground (scripts/expansion_spots.gd; rated on the bare map)
		exp_spots = ExpansionSpots.new()
		exp_spots.game = self
		exp_spots.all = ExpansionSpots.rate_all(self)
		exp_spots.spots = exp_spots.all.filter(func(s: Dictionary) -> bool: return int(s["rank"]) > 0)
		exp_spots.z_index = -18
		add_child(exp_spots)
	if edit_mode:
		fog_sprite.visible = false
		camera.position = Vector2(W, H) * T * 0.5
		camera.zoom = Vector2(0.6, 0.6)
		return
	if not puppet:
		_start_positions()          # (an online guest gets everything standing from the host's snapshots)
	_init_fog()
	mlog = MatchLog.new()
	mlog.game = self
	add_child(mlog)
	chat = Chat.new()
	chat.game = self
	add_child(chat)
	var me: Building = _own_hall(human)
	camera.position = me.global_position + Vector2(160, 40) if me else cell_center(starts[human]) + Vector2(160, 40)
	camera.zoom = Vector2(1.5, 1.5)


# ------------------------------------------------------------------ map

func idx(c: Vector2i) -> int:
	return c.y * W + c.x


func in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


## A world point pulled onto the map (half a tile in): the camera may look past the edge
## (Defs.CAMERA_MARGIN_TILES), but orders, rallies and lines always land on the real map.
func on_map(p: Vector2) -> Vector2:
	return p.clamp(Vector2(T, T) * 0.5, Vector2(W * T, H * T) - Vector2(T, T) * 0.5)


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
	_unknown_dirty = true                 # (what each player knows stands where: worked out again)
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if in_map(cc):
				solid[idx(cc)] = v
				# (a building going up over a decoration hides it: _solidify, _cover_decos)
				_region_dirty = true
				if astar.region.size != Vector2i.ZERO:
					astar.set_point_solid(cc, (v != 0 and v != 3 and v != 5) or rail_side.has(idx(cc)))
				if astar_siege.region.size != Vector2i.ZERO:
					astar_siege.set_point_solid(cc, v == 1 or v == 2 or rail_side.has(idx(cc)))


## Gates: map index -> the team that owns it.
var gate_team := {}


## Lock a built gate shut (or unlock it): a locked gate is a plain closed wall to everybody, its
## owner's units included (it leaves `gate_team`, so no side passes it, and the pathfinder's cell is
## solid), and shows a padlock. Returns why it can't be done ("" when it is): nothing may
## stand in the gateway. `force` skips that check (loading a saved game).
func set_gate_locked(b: Building, on: bool, force := false) -> String:
	if net_forward(self, "set_gate_locked", [b, on, force]): return ""
	if b == null or b.kind != "gate" or not b.built or b.dead:
		return "Only a built gate can be locked."
	if b.locked == on:
		return ""
	var i := idx(b.cell)
	if on:
		if not force:
			for u in units_near(b.center(), 90.0):
				if not u.dead and not u.is_air() and b.rect().grow(6.0).has_point(u.position):
					return "Something is in the gateway."
		b.locked = true
		b.queue_redraw()
		gate_team.erase(i)
		b.gate_open = false
		if astar.region.size != Vector2i.ZERO:
			astar.set_point_solid(b.cell, true)
		# whoever meant to go through it finds another way
		for u in units_near(b.center(), 600.0):
			if not u.dead and not u.is_air() and b.crossing(u):
				u.path = PackedVector2Array()
				u.path_i = 0
				u.repath_t = 0.0
	else:
		b.locked = false
		b.queue_redraw()
		gate_team[i] = b.team
		if astar.region.size != Vector2i.ZERO:
			astar.set_point_solid(b.cell, rail_side.has(i))
	_region_dirty = true
	b._update_sprite()
	b.queue_redraw()
	return ""


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
	if net_forward(self, "place_line", [t, k, a, b, builders, queued]): return 0
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
			tell(t, "Not enough gold for the whole wall.")
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
	_setup_rails()
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
	# (no path steps from beside a ramp onto it across a rail: those cells are shut to the
	# pathfinder; a path that starts or ends on one goes by path_cell)
	for i in rail_side:
		astar.set_point_solid(Vector2i(i % W, i / W), true)
		astar_siege.set_point_solid(Vector2i(i % W, i / W), true)
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


# ------------------------------------------------------------------ ramp rails

## The ramp rails (docs/ramp_funnel.md, MapGen.ramp_rails): a low wall down both sides of every
## ramp but its bottom row. A unit gets onto a ramp only straight on at either end, or from the
## side onto its bottom row. The ground beside a rail stays normal ground. The rule is an EDGE
## between cells: rail_cut (walk fills), the pathfinder grids (rail_side, path_cell), the path
## smoothing (line_clear) and movement (rail_fix, in resolve_terrain) all keep to it.
const RAIL_GAP := 6.0                    # (px: the least a unit's middle keeps from a rail's line)
const RAIL_LINE_PAD := 4.0               # (px: a smoothed path keeps this much more than its margin from a rail, so it never runs inside the gap rail_fix keeps: a unit would press on it)


func _setup_rails() -> void:
	rails = mapgen.ramp_rails()
	rail_bits = PackedByteArray()
	rail_bits.resize(W * H)
	_rail_near = PackedByteArray()
	_rail_near.resize(W * H)
	rail_side.clear()
	_rail_box = PackedFloat32Array()
	for rl in rails:
		var rr: Rect2 = rl["rect"]
		_rail_box.append_array([rr.position.x, rr.position.y, rr.end.x, rr.end.y])
		var o: Vector2i = rl["out"]
		var bo := _rail_bit(o)
		var bi := _rail_bit(-o)
		var lanes: Array = rl["lanes"]
		var sides: Array = rl["sides"]
		for n in lanes.size():
			var l: Vector2i = lanes[n]
			var sc: Vector2i = sides[n]
			rail_bits[idx(l)] |= bo
			rail_bits[idx(sc)] |= bi
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nc := l + Vector2i(dx, dy)
					if in_map(nc):
						_rail_near[idx(nc)] = 1
			if cliff[idx(sc)] == 0 and water[idx(sc)] == 0:
				rail_side[idx(sc)] = true
	if rail_layer == null and ground != null:
		rail_layer = RampRails.new()
		rail_layer.game = self
		rail_layer.z_index = -17
		add_child(rail_layer)
	if rail_layer != null:
		rail_layer.queue_redraw()


static func _rail_bit(d: Vector2i) -> int:
	if d.x > 0:
		return 1
	if d.x < 0:
		return 2
	return 4 if d.y > 0 else 8


## A rail between two neighbouring cells (8 ways: a diagonal step is cut when a rail lies on any of
## the four edges round the corner it passes, so no step cuts the corner past a rail's end).
func rail_cut(a: Vector2i, b: Vector2i) -> bool:
	if rails.is_empty() or not in_map(a) or not in_map(b):
		return false
	var d := b - a
	if d.x != 0 and d.y != 0:
		var h := a + Vector2i(d.x, 0)
		var v := a + Vector2i(0, d.y)
		return _rail_edge(a, h) or _rail_edge(a, v) or _rail_edge(h, b) or _rail_edge(v, b)
	return _rail_edge(a, b)


func _rail_edge(a: Vector2i, b: Vector2i) -> bool:
	if not in_map(a) or not in_map(b):
		return false
	return rail_bits[idx(a)] & _rail_bit(b - a) != 0


## The cell to give the pathfinder for a path that starts or ends at `c`: `c` itself, or, for a
## cell beside a rail (shut in the pathfinder grids), the nearest cell open to it that a unit
## walks to from `c` without crossing a rail (along the foot of the cliff, or away from the ramp).
func path_cell(c: Vector2i, siege := false) -> Vector2i:
	if rail_side.is_empty() or not in_map(c) or not rail_side.has(idx(c)):
		return c
	var grid: AStarGrid2D = astar_siege if siege else astar
	var seen := {c: true}
	var q: Array = [c]
	var qi := 0
	while qi < q.size() and qi < 64:
		var cc: Vector2i = q[qi]
		qi += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cc + d
			if seen.has(n) or not in_map(n) or not open_cell(n) or rail_cut(cc, n):
				continue
			seen[n] = true
			if not rail_side.has(idx(n)) and not grid.is_point_solid(n):
				return n
			q.append(n)
	return c


## Movement past the rails: `pos` (a unit of `radius` going there from `before`) moved back to
## before's side of any rail it would cross or come closer to than its own half-width. A unit
## already overlapping a rail (an old save or replay) is pushed out on the side its middle is on.
func rail_fix(pos: Vector2, before: Vector2, radius: float) -> Vector2:
	if rails.is_empty():
		return pos
	# (every moving unit comes here a few times a tick: away from the rails, one look at the
	# cells it is in)
	var ia := clampi(int(pos.y / T), 0, H - 1) * W + clampi(int(pos.x / T), 0, W - 1)
	var ib := clampi(int(before.y / T), 0, H - 1) * W + clampi(int(before.x / T), 0, W - 1)
	if _rail_near[ia] == 0 and _rail_near[ib] == 0:
		return pos
	var rx := maxf(radius * 0.6, RAIL_GAP)
	var ry := rx         # (a kerb running east-west: the same gap, as a unit south of it is drawn up over it)
	for rl in rails:
		var rr: Rect2 = rl["rect"]
		if rl["vertical"]:
			var x := rr.position.x
			var y0 := rr.position.y - RAIL_GAP       # (past its ends: a small cap, so a big machine still turns onto the open bottom row)
			var y1 := rr.end.y + RAIL_GAP
			if maxf(pos.y, before.y) < y0 or minf(pos.y, before.y) > y1 or minf(pos.x, before.x) > x + rx or maxf(pos.x, before.x) < x - rx:
				continue
			var s := signf(before.x - x)
			if s == 0.0:
				s = -signf(float((rl["out"] as Vector2i).x))
			var hit := pos.y >= y0 and pos.y <= y1 and (pos.x - x) * s < rx
			if not hit and (pos.x - x) * s < 0.0:
				var yc := lerpf(before.y, pos.y, (x - before.x) / (pos.x - before.x))
				hit = yc >= y0 and yc <= y1
			if hit:
				pos.x = x + s * rx
		else:
			var y := rr.position.y
			var x0 := rr.position.x - RAIL_GAP
			var x1 := rr.end.x + RAIL_GAP
			if maxf(pos.x, before.x) < x0 or minf(pos.x, before.x) > x1 or minf(pos.y, before.y) > y + ry or maxf(pos.y, before.y) < y - ry:
				continue
			var s := signf(before.y - y)
			if s == 0.0:
				s = -signf(float((rl["out"] as Vector2i).y))
			var hit := pos.x >= x0 and pos.x <= x1 and (pos.y - y) * s < ry
			if not hit and (pos.y - y) * s < 0.0:
				var xc := lerpf(before.x, pos.x, (y - before.y) / (pos.y - before.y))
				hit = xc >= x0 and xc <= x1
			if hit:
				pos.y = y + s * ry
	return pos


## Does the straight line a-b pass a rail closer than `margin`? (the path smoothing's test)
## (line_clear asks it thousands of times: each rail's box is first tested against the line's
## own box, from a flat list)
func rail_blocks_line(a: Vector2, b: Vector2, margin: float) -> bool:
	var lx0 := minf(a.x, b.x) - margin
	var lx1 := maxf(a.x, b.x) + margin
	var ly0 := minf(a.y, b.y) - margin
	var ly1 := maxf(a.y, b.y) + margin
	var n := _rail_box.size()
	var k := 0
	while k < n:
		if lx1 >= _rail_box[k] and lx0 <= _rail_box[k + 2] and ly1 >= _rail_box[k + 1] and ly0 <= _rail_box[k + 3]:
			if _seg_hits_rect(a, b, (rails[k / 4]["rect"] as Rect2).grow(margin)):
				return true
		k += 4
	return false


var _rail_box := PackedFloat32Array()      # each rail's line: x0, y0, x1, y1
var _rail_near := PackedByteArray()        # per cell: 1 within two cells of a rail's ramp cell


static func _seg_hits_rect(a: Vector2, b: Vector2, box: Rect2) -> bool:
	if box.has_point(a) or box.has_point(b):
		return true
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for ax in 2:
		var p0: float = a.x if ax == 0 else a.y
		var dv: float = d.x if ax == 0 else d.y
		var lo: float = box.position.x if ax == 0 else box.position.y
		var hi: float = box.end.x if ax == 0 else box.end.y
		if absf(dv) < 0.0001:
			if p0 < lo or p0 > hi:
				return false
			continue
		var ta := (lo - p0) / dv
		var tb := (hi - p0) / dv
		if ta > tb:
			var tt := ta
			ta = tb
			tb = tt
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true


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


var _cliff_art: CliffArt


func _render_ground() -> void:
	_cliff_art = CliffArt.new(self)
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
				# (a wall only over low ground, not over a ramp: CliffArt.is_wall)
				set_name = b["face"] if in_map(below) and height[idx(below)] == 0 and ramp[idx(below)] == 0 else b["high"]
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
			# cliffs: walls from the low ground, contours, lips and shadows at the rims (CliffArt)
			_cliff_art.paint(img, cr)
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
			var sideways := sa.y != 0      # the ramp runs east-west (down to the east or the west)
			var neg_open := {}
			var pos_open := {}
			# (the bottom row has no rail: it is open from the sides, so no kerb is painted down
			# its sides either; docs/ramp_funnel.md)
			var dg := Vector2i(int(signf(dir.x)), 0) if sa.y != 0 else Vector2i(0, int(signf(dir.y)))
			for c in cells:
				var nn: Vector2i = c - sa
				var pp: Vector2i = c + sa
				var foot := not MapGen.no_funnel and not (in_map(c + dg) and ramp[idx(c + dg)] == 1)
				neg_open[c] = foot or (in_map(nn) and ramp[idx(nn)] == 1)
				pos_open[c] = foot or (in_map(pp) and ramp[idx(pp)] == 1)
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
						# (the planks a touch darker and stronger than the ground round them, so the
						# ramp reads as the only way through: docs/ramp_funnel.md)
						col = col.darkened(0.08 + 0.12 * f)
						var step_d := fmod(p.dot(dir) - lo_p, 8.0)
						if step_d < 1.0:
							col = col.darkened(0.38)
						elif step_d < 2.0:
							col = col.lightened(0.18)
						# clear edges down both sides: a wedge of cliff rock at the top that narrows
						# down the slope, then a stone kerb the whole way down (a dark outer line, a
						# lit stone strip, a dark inner line) and the walls' shadow on the planks
						# beside it, deepest at the top
						# how far this pixel is from the ramp's side edge (the side of its cell
						# that faces a cell which isn't ramp)
						var sd := 99.0
						var along: float = float(px) if sa.x != 0 else float(py)
						if not neg_open.get(c, false):
							sd = minf(sd, along)
						if not pos_open.get(c, false):
							sd = minf(sd, float(T) - 1.0 - along)
						# (a sideways ramp, running east-west: its kerbs are the drawn rails alone
						# (RampRails); no rock wedge and no painted kerb, which slanted across the
						# planks there, only the rails' shadow as an even band along each side)
						if sideways:
							if sd < 6.0:
								col = col.darkened(0.42)
							elif sd < 9.0:
								col = col.darkened(0.42 * (9.0 - sd) / 3.0)
							var td_s := p.dot(dir) - lo_p
							if td_s < 6.0:
								col = col.darkened(0.45 * (1.0 - td_s / 6.0))
							col.a = 1.0
							img.set_pixel((c.x - area.position.x) * T + px, (c.y - area.position.y) * T + py, col)
							continue
						var wedge := 8.0 * (1.0 - f)
						var k := sd - wedge
						if sd < wedge:
							col = face_t.get_pixel(px, py).darkened(0.1 + 0.25 * (1.0 - sd / maxf(wedge, 0.01)))
						elif k < 1.0:
							col = col.darkened(0.7)
						elif k < 4.0:
							var stone: Color = face_t.get_pixel(px, py).lerp(Color(0.62, 0.6, 0.55), 0.55)
							col = stone.lightened(0.3) if k < 2.0 else stone
						elif k < 5.0:
							col = col.darkened(0.55)
						elif k < 12.0:
							col = col.darkened(0.3 * (1.0 - (k - 5.0) / 7.0) * (1.0 - 0.6 * f))
						# a shadow line across the top, where the planks leave the high ground
						var td := p.dot(dir) - lo_p
						if td < 3.0 and sd >= wedge:
							col = col.darkened(0.4 * (1.0 - td / 3.0))
						col.a = 1.0
						img.set_pixel((c.x - area.position.x) * T + px, (c.y - area.position.y) * T + py, col)


func _start_positions() -> void:
	for t in n_players():
		if BroodNew.on(self, t):
			BroodNew.start(self, t, starts[t])       # (the new Brood: the Mother, a Rootmaw, grubs; no buildings)
			continue
		var f: Dictionary = Defs.FACTIONS[factions[t]]
		var b := _add_building(f["hall"], t, starts[t], true)
		players[t]["res2"] = float(Defs.START_POWDER) if factions[t] == "crown" else 0.0
		_update_swamp()
		# Starting economy structures, already standing.
		var sites: Array = []
		for k in Defs.start_list(factions[t]):
			var spot := find_start_spot(t, k, b, sites) if start_edge_layout else Vector2i(-1, -1)
			if spot.x < 0:
				spot = find_spot(t, k, b, 4, 11, "behind")
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
		if factions[t] == "clockwork" and Defs.line_mode:
			line_net.lay_start(t)       # a finished main from the Clocktower to its first buildings
	_update_swamp()


# ------------------------------------------------------------------ start layout

const START_REACH := 13.0         # tiles from the hall's middle: no starting economy building is put farther
const START_SIDE_CLEAR := 2       # free cells kept between a starting building and the hall (workers walk in)
const START_RAMP_CLEAR := 4       # and between it and a ramp
const START_HUG_SCAN := 8         # how far a side looks for the edge it hugs


## Ground a man can walk on (not terrain, buildings, walls, cliffs).
func _walkable(c: Vector2i) -> bool:
	if not in_map(c):
		return false
	var i := idx(c)
	return (solid[i] == 0 or solid[i] == 5) and cliff[i] == 0


## How many free cells lie between a footprint and the nearest edge of the ground it stands on
## (a cliff, the map's rim, a rock or tree, water: anything that isn't level walkable ground).
## 0 = it touches the edge. The tightest of its four sides.
func edge_gap(cell: Vector2i, size: Vector2i, h: int) -> int:
	var best := START_HUG_SCAN
	for side in 4:
		var d := Vector2i.ZERO
		var n := size.x if side < 2 else size.y
		match side:
			0: d = Vector2i(0, -1)
			1: d = Vector2i(0, 1)
			2: d = Vector2i(-1, 0)
			_: d = Vector2i(1, 0)
		for k in n:
			var c: Vector2i
			match side:
				0: c = Vector2i(cell.x + k, cell.y - 1)
				1: c = Vector2i(cell.x + k, cell.y + size.y)
				2: c = Vector2i(cell.x - 1, cell.y + k)
				_: c = Vector2i(cell.x + size.x, cell.y + k)
			var g := 0
			while g < best and _walkable(c) and int(height[idx(c)]) == h and ramp[idx(c)] == 0:
				c += d
				g += 1
			best = mini(best, g)
	return best


## Walkable cells reachable from the cells round a hall (not through `block`, a footprint),
## within START_REACH + 12 tiles of it: [count, ring cells found, whether a ramp was reached].
func _start_flood(hall: Building, block: Rect2i, ring: Dictionary) -> Array:
	var hr := Rect2i(Vector2i(hall.cell), hall.size)
	var hc := hall.rect().get_center() / T
	var seen := {}
	var todo: Array = []
	for y in range(hr.position.y - 1, hr.end.y + 1):
		for x in range(hr.position.x - 1, hr.end.x + 1):
			var c := Vector2i(x, y)
			if not hr.has_point(c) and _walkable(c) and not block.has_point(c):
				seen[c] = true
				todo.append(c)
	var found := 0
	var ramp_seen := false
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if ring.has(c):
			found += 1
		if ramp[idx(c)] == 1:
			ramp_seen = true
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dd
			if seen.has(n) or not _walkable(n) or block.has_point(n) or hr.has_point(n):
				continue
			if (Vector2(n) + Vector2(0.5, 0.5)).distance_to(hc) > START_REACH + 12.0:
				continue
			seen[n] = true
			todo.append(n)
	return [seen.size(), found, ramp_seen]


## Where a starting economy building (farm, pit, crusher...) goes: hugging the edge of the main
## base's ground, on the side away from the enemy and the ramp, as near the hall as such a spot
## gets, with its own room to walk and the hall's room kept clear. (-1, -1): no such spot.
## `placed`: the starting buildings already standing, which the next one packs up against.
func find_start_spot(t: int, kind: String, hall: Building, placed: Array) -> Vector2i:
	if Defs.is_econ(kind) and econ_count(t, kind) >= econ_limit(t, kind):
		return Vector2i(-1, -1)
	_spot_halls = halls_of(t)
	_spot_all_halls = halls_of(t, false)
	_in_spot = true
	var best := _find_start_spot(t, kind, hall, placed)
	_spot_halls = []
	_spot_all_halls = []
	_in_spot = false
	return best


func _find_start_spot(t: int, kind: String, hall: Building, placed: Array) -> Vector2i:
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var hr := Rect2i(Vector2i(hall.cell), hall.size)
	var hc: Vector2 = hall.rect().get_center() / T
	var hcell := cell_of(hall.rect().get_center())
	if not in_map(hcell):
		return Vector2i(-1, -1)
	var h0 := int(height[idx(hcell)])
	var reach := START_REACH
	if kind == "feeding_pit":
		reach = minf(reach, float(Defs.BUILDINGS["hive"]["swamp"]) + 2.0)    # (the pit must stand on the Burrow's swamp)
	# the enemy is the front: the direction the base looks
	var front := Vector2.ZERO
	for o in n_players():
		if hostile(t, o):
			front += Vector2(starts[o]) - Vector2(starts[t])
	front = front.normalized() if front.length() > 0.01 else Vector2.ZERO
	var cands: Array = []
	var keys := PackedInt64Array()
	var r := int(reach) + 2
	for y in range(int(hc.y) - r, int(hc.y) + r + 1):
		for x in range(int(hc.x) - r, int(hc.x) + r + 1):
			var cell := Vector2i(x, y)
			var cc := Vector2(cell) + Vector2(size) * 0.5
			var dd := cc.distance_to(hc)
			if dd > reach or dd < 4.0:
				continue
			if not _on_ground(cell, size, h0):
				continue
			var fp := Rect2i(cell, size)
			if fp.grow(START_SIDE_CLEAR).intersects(hr):
				continue
			if not _footprint_inside_free(cell, size):
				continue
			var gap := edge_gap(cell, size, h0)
			var score := dd + maxi(0, gap - 1) * 4.0     # (one free lane to the edge still hugs it: the start layout test accepts it, and the Clockwork's press meshes one row in from a rim)
			if front != Vector2.ZERO:
				score += maxf(0.0, (cc - hc).dot(front)) * 1.0
			for pb in placed:
				var pc: Vector2 = pb.rect().get_center() / T
				score += maxf(0.0, pc.distance_to(cc) - (Vector2(size) + Vector2(pb.size)).length() * 0.5 - 1.0) * 0.5
			keys.append(int(round((score + 1000.0) * 1000.0)) * 1048576 + cands.size())
			cands.append(cell)
	keys.sort()
	var base := _start_flood(hall, Rect2i(), {})
	var tried := 0
	for k in keys:
		var cell: Vector2i = cands[k % 1048576]
		tried += 1
		if tried > 400:
			break
		if placement_problem(t, kind, cell, true, true) != "":
			continue
		if not _start_room(cell, size):
			continue
		var fp := Rect2i(cell, size)
		var ring := {}
		for y in range(cell.y - 1, cell.y + size.y + 1):
			for x in range(cell.x - 1, cell.x + size.x + 1):
				var c := Vector2i(x, y)
				if not fp.has_point(c) and _walkable(c):
					ring[c] = true
		var fl := _start_flood(hall, fp, ring)
		if int(fl[1]) < 2:
			continue
		if int(base[0]) - int(fl[0]) > size.x * size.y + maxi(4, int(base[0]) / 50):
			continue
		if bool(base[2]) and not bool(fl[2]):
			continue
		return cell
	return Vector2i(-1, -1)


## Every cell of the footprint is bare, free ground (the quick test).
func _footprint_inside_free(cell: Vector2i, size: Vector2i) -> bool:
	for y in range(cell.y, cell.y + size.y):
		for x in range(cell.x, cell.x + size.x):
			if not in_map(Vector2i(x, y)) or solid[y * W + x] != 0:
				return false
	return true


## Room to work round a starting building: no ramp near it, and three of its four sides have a
## free lane (the side on the edge it hugs may be shut).
func _start_room(cell: Vector2i, size: Vector2i) -> bool:
	for y in range(cell.y - START_RAMP_CLEAR, cell.y + size.y + START_RAMP_CLEAR):
		for x in range(cell.x - START_RAMP_CLEAR, cell.x + size.x + START_RAMP_CLEAR):
			var c := Vector2i(x, y)
			if in_map(c) and ramp[idx(c)] == 1:
				return false
	var open := 0
	for side in 4:
		var ok := true
		var n := size.y if side >= 2 else size.x
		for k in n:
			var c: Vector2i
			match side:
				0: c = Vector2i(cell.x + k, cell.y - 1)
				1: c = Vector2i(cell.x + k, cell.y + size.y)
				2: c = Vector2i(cell.x - 1, cell.y + k)
				_: c = Vector2i(cell.x + size.x, cell.y + k)
			if not _walkable(c):
				ok = false
				break
		if ok:
			open += 1
	return open >= 3


## A free cell for a building of this kind around a building: distance in tiles from
## its middle; "near" picks the closest, "far" the farthest, "toward_middle" the one
## nearest the middle of the map. `ground`: only on the building's own ground (its height:
## the computer keeps its buildings up on its main's plateau, inside its walls).
func find_spot(t: int, kind: String, around: Building, min_d: int, max_d: int, prefer := "near", ground := false, anchor := Vector2.INF) -> Vector2i:
	if Defs.is_econ(kind) and econ_count(t, kind) >= econ_limit(t, kind):
		return Vector2i(-1, -1)
	_spot_halls = halls_of(t)
	_spot_all_halls = halls_of(t, false)
	_in_spot = true
	var size: Vector2i = Defs.BUILDINGS[kind]["size"]
	var c0: Vector2 = around.rect().get_center() / T if anchor == Vector2.INF else anchor
	var mid := Vector2(W, H) * 0.5
	var best := Vector2i(-1, -1)
	var hc := cell_of(around.rect().get_center())
	var h0 := int(height[idx(hc)]) if in_map(hc) else -1
	# (ground only: a footprint may also touch cliffs, trees and rocks with its ring, if that
	# leaves every route on the plateau open: the plateau's edge is usable room too)
	var tight_ok := ground and h0 >= 0 and not (kind == "wall" or kind == "gate")
	var tight_flags := PackedByteArray()
	var reach0 := -1
	var reach_from := Vector2i(-1, -1)
	# every open cell is scored first, then the full placement test runs from the best score
	# down until one passes (it used to run on every cell: a hall's search took ~100 ms)
	var keys := PackedInt64Array()
	var cells: Array[Vector2i] = []
	var pair := kind == "boiler" or (kind == "ore_crusher" and econ_count(t, "boiler") > 0)
	var pair_at: Array[Vector2] = []
	var pit_at: Array[Vector2] = []
	if kind == "feeding_pit":
		for b in buildings:
			if b.team == t and not b.dead and b.kind == "feeding_pit":
				pit_at.append(b.center())
	if pair:
		for b in buildings:
			if b.team == t and not b.dead and (b.d.has("battery") if kind == "ore_crusher" else b.kind == "ore_crusher"):
				pair_at.append(b.center())
	for y in range(int(c0.y) - max_d - 2, int(c0.y) + max_d + 2):
		for x in range(int(c0.x) - max_d - 2, int(c0.x) + max_d + 2):
			var cell := Vector2i(x, y)
			var cc := Vector2(cell) + Vector2(size) * 0.5
			var dd := cc.distance_to(c0)
			if dd < min_d or dd > max_d:
				continue
			if ground and h0 >= 0 and not _on_ground(cell, size, h0):
				continue
			var tight := 0
			if not _footprint_open(cell, size):
				if not tight_ok or not _footprint_open_tight(cell, size):
					continue
				tight = 1
			var score := dd + (4.0 if tight == 1 else 0.0)
			var pit_pen := 0.0
			if kind == "feeding_pit":
				# (the ground circles of our own pits: no overlap, checked here first as it rules out most cells)
				var pm := (Vector2(cell) + Vector2(size) * 0.5) * T
				var clash := false
				for pc in pit_at:
					if pit_circles_overlap(pc, pm):
						clash = true
						break
				if clash:
					continue
				# a pit wants fresh ground: never over spent old ground, and tired old ground scores worse
				var gl := pit_ground_at(pm) / float(Defs.PIT_GROUND)
				if gl <= 0.1:
					continue
				pit_pen = (1.0 - gl) * 30.0
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
			score += pit_pen
			if pair:
				# Boilers and crushers close together (once there's a Boiler; the starting crusher
				# goes behind the hall): a battery fades on a long road, and a Boiler's Winders
				# must be back for the next one within a few seconds
				var near := INF
				for pc in pair_at:
					near = minf(near, pc.distance_to(cc * T) / T)
				if near < INF:
					score += maxf(0.0, near - SOURCE_NEAR) * 3.0
			# (sorted by score, then by the order the cells were looked at, as before)
			keys.append(int(round((score + 100000.0) * 1000.0)) * 1048576 + cells.size())
			cells.append(cell)
			tight_flags.append(tight)
	keys.sort()
	for k in keys:
		var ci: int = k % 1048576
		var cell: Vector2i = cells[ci]
		if placement_problem(t, kind, cell, true, true) != "":
			continue
		if tight_flags[ci] == 0:
			if margin_free(cell, size):
				best = cell
				break
		elif margin_free_tight(cell, size):
			if reach0 < 0:
				reach_from = _free_next_to(hc, h0)
				reach0 = _plateau_reach(reach_from, h0, Vector2i(-1, -1), Vector2i.ZERO)
			if _plateau_reach(reach_from, h0, cell, size) >= reach0 - size.x * size.y - 2:
				best = cell
				break
	_spot_halls = []
	_spot_all_halls = []
	_in_spot = false
	return best


## Every cell of a footprint at height h (no ramp): on one plateau (or the low ground).
func _on_ground(cell: Vector2i, size: Vector2i, h: int) -> bool:
	for y in range(cell.y, cell.y + size.y):
		for x in range(cell.x, cell.x + size.x):
			var c := Vector2i(x, y)
			if not in_map(c) or int(height[idx(c)]) != h or ramp[idx(c)] != 0:
				return false
	return true


var _spot_halls: Array = []
var _spot_all_halls: Array = []      # (find_spot: the halls, unfinished ones too, looked up once)
var _in_spot := false


## find_spot's quick test before the full placement_problem: every cell of the footprint
## and the ring round it on the map and free (placement_problem and margin_free would
## turn the spot down anyway; this is only cheaper).
func _footprint_open(cell: Vector2i, size: Vector2i) -> bool:
	if line_net.blocks(cell, size):
		return false
	if cell.x < 1 or cell.y < 1 or cell.x + size.x >= W or cell.y + size.y >= H:
		return in_map(cell)       # (at the map's edge: leave it to the full test)
	for y in range(cell.y - 1, cell.y + size.y + 1):
		var row := y * W
		for x in range(cell.x - 1, cell.x + size.x + 1):
			if solid[row + x] != 0:
				return false
	return true
## The ring of a footprint may be terrain (cliff, tree, rock) but never a building.
func _footprint_open_tight(cell: Vector2i, size: Vector2i) -> bool:
	for y in range(cell.y - 1, cell.y + size.y + 1):
		for x in range(cell.x - 1, cell.x + size.x + 1):
			var c := Vector2i(x, y)
			if not in_map(c):
				continue
			var v := int(solid[idx(c)])
			if v != 0 and v != 1:
				return false
	return true


func margin_free_tight(cell: Vector2i, size: Vector2i) -> bool:
	for y in range(-1, size.y + 1):
		for x in range(-1, size.x + 1):
			if x >= 0 and y >= 0 and x < size.x and y < size.y:
				continue
			var c := cell + Vector2i(x, y)
			if not in_map(c):
				continue
			var v := int(solid[idx(c)])
			if v != 0 and v != 1:
				return false
	return true


## The tile just below the ramp nearest to a building's plateau (where lower-ground
## buildings go when the plateau is full), or INF if its ground has no ramp near.
func ramp_foot(around: Building) -> Vector2:
	var hc := cell_of(around.rect().get_center())
	if not in_map(hc):
		return Vector2.INF
	var h0 := int(height[idx(hc)])
	var best := Vector2.INF
	var bd := INF
	for y in range(hc.y - 30, hc.y + 31):
		for x in range(hc.x - 30, hc.x + 31):
			var r := Vector2i(x, y)
			if not in_map(r) or ramp[idx(r)] != 1:
				continue
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = r + dd
				if not in_map(p) or ramp[idx(p)] != 0 or int(height[idx(p)]) != h0:
					continue
				# p is a plateau cell touching this ramp: walk on through the ramp to its foot
				var f := r
				var steps := 0
				while in_map(f) and ramp[idx(f)] == 1 and steps < 12:
					f += -dd
					steps += 1
				if not in_map(f) or int(height[idx(f)]) == h0:
					continue
				var d := Vector2(p).distance_to(Vector2(hc))
				if d < bd:
					bd = d
					best = Vector2(f) + Vector2(0.5, 0.5)
	return best


## The plateau cell (tile coordinates, centre) where the nearest ramp meets the plateau of a building:
## the top of the ramp. Vector2.INF when there is none within 30 tiles.
func ramp_top(around: Building) -> Vector2:
	var hc := cell_of(around.rect().get_center())
	if not in_map(hc):
		return Vector2.INF
	var h0 := int(height[idx(hc)])
	var best := Vector2.INF
	var bd := INF
	for y in range(hc.y - 30, hc.y + 31):
		for x in range(hc.x - 30, hc.x + 31):
			var r := Vector2i(x, y)
			if not in_map(r) or ramp[idx(r)] != 1:
				continue
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = r + dd
				if not in_map(p) or ramp[idx(p)] != 0 or int(height[idx(p)]) != h0:
					continue
				var d := Vector2(p).distance_to(Vector2(hc))
				if d < bd:
					bd = d
					best = Vector2(p) + Vector2(0.5, 0.5)
	return best


## A free cell of height h near a cell (the nearest, looking outward).
func _free_next_to(c: Vector2i, h: int) -> Vector2i:
	for r in range(1, 12):
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if absi(x - c.x) != r and absi(y - c.y) != r:
					continue
				var m := Vector2i(x, y)
				if in_map(m) and solid[idx(m)] == 0 and ramp[idx(m)] == 0 and int(height[idx(m)]) == h:
					return m
	return c


## How many cells of a plateau (height h, plus its ramps) can be walked to from a cell, within
## 30 tiles, with a footprint (cell, size) taken out: a spot that cuts this much more than its
## own area has shut a route.
func _plateau_reach(start: Vector2i, h: int, cell: Vector2i, size: Vector2i) -> int:
	var seen := {}
	var todo: Array = [start]
	seen[idx(start)] = true
	var n := 0
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		n += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var m: Vector2i = c + dd
			if not in_map(m) or seen.has(idx(m)):
				continue
			if absi(m.x - start.x) > 30 or absi(m.y - start.y) > 30:
				continue
			var v := int(solid[idx(m)])
			if v != 0 and v != 5:
				continue
			if ramp[idx(m)] == 0 and int(height[idx(m)]) != h:
				continue
			if size != Vector2i.ZERO and m.x >= cell.x and m.y >= cell.y and m.x < cell.x + size.x and m.y < cell.y + size.y:
				continue
			seen[idx(m)] = true
			todo.append(m)
	return n


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
	var spent: float = float(Defs.GEAR["spent"]) if b.kind == Defs.GEAR_PRESS else Defs.LODE_SPENT
	return fresh + (v - fresh) * spent


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
	var user := "its Mill grinds" if h.kind == "town_hall" else ("its presses yield" if Defs.gear_mode else "its crushers pay")
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

## An economy structure with room in its crew for this team's workers, nearest first. A real post (Farm, Mill,
## Feeding Pit, Cog Press...) always comes first; a Town Hall's hauler slots only when every post is full (a Town
## Hall counts its haulers as its crew, so without this the nearest hall won: every Crown game started with all
## its labourers hauling and the starting Farm unworked).
func free_site(t: int, p: Vector2) -> Building:
	var best: Building = null
	var bd := INF
	var bt := 99
	var hall: Building = null
	var hd := INF
	for b in buildings:
		if b.team != t or b.dead or not b.built or b.crew_max() == 0:
			continue
		if b.crew.size() >= b.crew_max():
			continue
		var dd: float = b.center().distance_to(p) + b.crew.size() * 40.0
		if b.haul_cap() > 0:
			if dd < hd:         # hauling: the fallback when all the posts are taken
				hd = dd
				hall = b
			continue
		if b.barren():
			continue            # spent land: nobody works a Farm, Pit, Mill or Boiler on it any more
		var tier := int(Defs.CREW_TIER.get(b.kind, 0))      # the primary resource's posts first (Defs.CREW_TIER)
		if tier < bt or (tier == bt and dd < bd):
			bt = tier
			bd = dd
			best = b
	return best if best != null else hall


## Soil fatigue: the Town Hall whose farmland a Farm draws on (the nearest built one);
## a Feeding Pit draws on its own ground (Defs.PIT_GROUND), so it is its own "hall".
func soil_hall(farm: Building) -> Building:
	if farm.kind == "feeding_pit":
		return farm
	return nearest_hall(farm.center(), farm.team)


## A Farm's harvest: draws its yield from its hall's soil; spent soil pays nothing (barren).
## Adds the gold and returns what it paid.
func harvest(farm: Building) -> int:
	var h := soil_hall(farm)
	var fresh := 0.0
	if h:
		fresh = minf(h.soil, float(Defs.FARM_YIELD))
		h.soil -= fresh
	var pay := int(round(fresh + (Defs.FARM_YIELD - fresh) * Defs.SOIL_TIRED))
	if pay > 0:
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
	if h.kind == "feeding_pit":
		# a Feeding Pit's own ground (each pit warns for itself)
		if mlog:
			mlog.add("%s: the ground of a Feeding Pit %s" % [mlog.who(h.team), "is spent (barren: it yields nothing)" if level == 2 else "is running low (under %d%%)" % int(Defs.SOIL_LOW * 100)])
		if h.team == human and not demo and hud:
			hud.toast("A Feeding Pit's ground is spent: it yields nothing. Grow a new pit on fresh ground, outside the old circles." if level == 2
				else "A Feeding Pit's ground is running low (%d%% left): plan a new pit on fresh ground." % int(round(left * 100)), false)
			Sfx.play("done", h.center())
		h._update_sprite()
		return
	if h.kind == "clocktower":
		# Clockwork coal: the Boilers around this Clocktower
		if mlog:
			mlog.add("%s: the coal of a Clocktower's Boilers %s" % [mlog.who(h.team), "is spent (they fill no more batteries)" if level == 2 else "is running low (under %d%%)" % int(Defs.SOIL_LOW * 100)])
		if h.team == human and not demo and hud:
			hud.toast("Your Boilers' coal is spent: they fill no more batteries. Build a Clocktower on fresh ground." if level == 2
				else "Your Boilers' coal is running low (%d%% left): expand to fresh ground soon." % int(round(left * 100)), false)
			Sfx.play("done", h.center())
		return
	if mlog:
		if hive:
			mlog.add("%s: the ground around a %s %s" % [mlog.who(h.team), h.d["name"], "is spent (barren: its pits yield nothing)" if level == 2 else "is running low (under %d%%)" % int(Defs.SOIL_LOW * 100)])
		else:
			mlog.add("%s: the soil around a Town Hall %s" % [mlog.who(h.team), "is spent (barren: its farms pay nothing)" if level == 2 else "is running low (under %d%%)" % int(Defs.SOIL_LOW * 100)])
	if h.team == human and not demo and hud:
		if hive:
			hud.toast(("The ground around your %s is spent: barren, its pits yield nothing. Grow a Burrow on fresh ground." % h.d["name"]) if level == 2
				else "The ground around your %s is running low (%d%% left): grow a Burrow on fresh ground soon." % [h.d["name"], int(round(left * 100))], false)
		else:
			hud.toast("The soil around your Town Hall is barren: its farms pay nothing. Expand to fresh land." if level == 2
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


# ------------------------------------------------------------------ pit ground (Defs.PIT_GROUND, PIT_CLAIM)

## Where a Feeding Pit placed at cell c would have its centre (px).
func pit_mid(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(Defs.BUILDINGS["feeding_pit"]["size"]) * 0.5) * T


## Two pit circles overlap when their centres are closer than two radii (exactly 2 x PIT_CLAIM apart is fine).
static func pit_circles_overlap(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 2.0 * Defs.PIT_CLAIM * Defs.TILE - 0.5


## Team t's living Feeding Pits (planned, growing or built) whose circle overlaps a circle at p.
func pit_overlaps(t: int, p: Vector2, skip: Building = null) -> Array:
	var out: Array = []
	for b in buildings:
		if b.kind == "feeding_pit" and b.team == t and not b.dead and b != skip and pit_circles_overlap(b.center(), p):
			out.append(b)
	return out


## The old ground spots (pit_spots indexes) a pit circle at p overlaps.
func pit_spots_at(p: Vector2) -> Array:
	var out: Array = []
	for i in pit_spots.size():
		if pit_circles_overlap(pit_spots[i][0], p):
			out.append(i)
	return out


## The ground a new pit with its centre at p would have: the SMALLEST amount left among the old
## spots its circle overlaps (rebuilding by a spent pit can't refresh the ground), else fresh.
func pit_ground_at(p: Vector2) -> float:
	var g := float(Defs.PIT_GROUND)
	for i in pit_spots_at(p):
		g = minf(g, float(pit_spots[i][1]))
	return maxf(g, 0.0)


## A new Feeding Pit takes its ground (when its site starts: _solidify): the old spots under its
## circle merge into its claim, and it keeps the smallest amount left among them.
func claim_pit_ground(b: Building) -> void:
	if puppet:
		return          # (an online guest: the host's snapshot brings each pit's ground and the old spots)
	var p := b.center()
	b.soil = pit_ground_at(p)
	var idxs := pit_spots_at(p)
	idxs.reverse()
	for i in idxs:
		pit_spots.remove_at(i)
	b.soil_warned = 2 if b.soil <= 0.0 else (1 if b.soil / b.reserve() < Defs.SOIL_LOW else 0)


## Why a Feeding Pit can't go at cell c for team t because of the circles ("" if it can).
func pit_claim_problem(t: int, c: Vector2i) -> String:
	if not pit_overlaps(t, pit_mid(c)).is_empty():
		return "Too close to another Feeding Pit: their grounds would overlap."
	return ""


func halls_of(t: int, built_only := true) -> Array:
	var out: Array = []
	for b in _hall_kind_of(t):       # (the same buildings in the same order as a filter over all of them)
		if not b.dead and (b.built or not built_only):
			out.append(b)
	return out


const BROOD_PIT_UNCAPPED := 999


## The Brood's CAPITAL: its first Burrow, the oldest one standing (the starting hall; when it
## falls the next oldest takes over). The only hall grubs unload at, and the only one with
## ground. Null for other factions or with no finished Burrow.
func capital(t: int) -> Building:
	if faction_of(t) != "brood":
		return null
	var c = _capital.get(t)      # (untyped: a freed Burrow, after a load, can't be held in a typed variable)
	var had: bool = c != null
	if had and not is_instance_valid(c):
		c = null
		had = _capital_had.has(t)
	if c != null and not c.dead and c.built:
		_capital_had[t] = true
		return c
	_capital[t] = null
	for b in buildings:        # (creation order: the oldest first)
		if b.team == t and b.kind == "hive" and b.built and not b.dead:
			_capital[t] = b
			b.queue_redraw()
			if had and _capital_had.has(t):
				# (the capital has no ground since the pits own it: nothing passes on)
				if mlog:
					mlog.add("%s: the capital fell; the next Burrow is the new capital" % mlog.who(t))
				tell(t, "Your capital has fallen: the next Burrow is the new capital.")
			_capital_had[t] = true
			return b
	return null


var _capital := {}
var _capital_had := {}          # team -> true once it has had a capital (to tell when one falls)


## Where workers unload: the Brood's capital; for the others the nearest hall.
## Where a worker unloads, any kind: the new Brood's Brood Mother, else dropoff_hall.
func dropoff_ent(p: Vector2, t: int) -> Entity:
	if BroodNew.on(self, t):
		return BroodNew.dropoff(self, t)
	return dropoff_hall(p, t)


## Where a Brood creature is offered up (SACRIFICE): the nearest Brood Pen, or the new Brood's Mother.
func offer_place(p: Vector2, t: int) -> Entity:
	if BroodNew.on(self, t):
		return BroodNew.dropoff(self, t)
	return nearest_of(p, t, "brood_pen")


func dropoff_hall(p: Vector2, t: int) -> Building:
	if faction_of(t) == "brood":
		return capital(t)
	return nearest_hall(p, t)


## Tiles from the capital (centre to centre) to a point; 0 when there's none.
func capital_dist(t: int, p: Vector2) -> float:
	var c := capital(t)
	return c.center().distance_to(p) / T if c else 0.0


## The Brood's resource reach: swamp joined to the capital's, as far from it as the swamp goes
## (capped at Defs.BROOD_RESOURCE_MAX_D). Grows with Clutch Mounds and any other swamp.
var swamp_conn: Array = []        # per team: PackedByteArray, 1 = swamp joined to the capital's
var swamp_reach: Array = []       # per team: farthest such cell from the capital, in tiles
var swamp_hall_conn: Array = []   # per team: PackedByteArray, 1 = swamp joined to the swamp of ANY finished Burrow (Clutch Mound rule)


func _update_conn() -> void:
	while swamp_conn.size() < n_players():
		swamp_conn.append(PackedByteArray())
		swamp_reach.append(0.0)
	while swamp_hall_conn.size() < n_players():
		swamp_hall_conn.append(PackedByteArray())
	for t in n_players():
		swamp_hall_conn[t] = _flood_from_halls(t)
		var conn := PackedByteArray()
		conn.resize(W * H)
		swamp_reach[t] = 0.0
		var cap := capital(t)
		if cap != null:
			var c0 := cell_of(cap.center())
			var g: PackedByteArray = swamp[t]
			var cc := cap.center() / T
			var stack: Array[int] = []
			if in_map(c0) and g[idx(c0)] == 1:
				stack.append(idx(c0))
				conn[idx(c0)] = 1
			var far := 0.0
			while not stack.is_empty():
				var i: int = stack.pop_back()
				var x := i % W
				var y := i / W
				far = maxf(far, Vector2(x + 0.5, y + 0.5).distance_to(cc))
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= W or ny >= H:
						continue
					var j := ny * W + nx
					if g[j] == 1 and conn[j] == 0:
						conn[j] = 1
						stack.append(j)
			swamp_reach[t] = minf(far, Defs.BROOD_RESOURCE_MAX_D)
		swamp_conn[t] = conn


## Swamp cells joined (4-connected) to the swamp under any finished Burrow of side t.
func _flood_from_halls(t: int) -> PackedByteArray:
	var conn := PackedByteArray()
	conn.resize(W * H)
	if faction_of(t) != "brood":
		return conn
	var g: PackedByteArray = swamp[t]
	var stack: Array[int] = []
	for b in buildings:
		if b.team != t or b.dead or not b.built or b.kind != faction_hall(t):
			continue
		for y in b.size.y:
			for x in b.size.x:
				var c: Vector2i = b.cell + Vector2i(x, y)
				if in_map(c) and g[idx(c)] == 1 and conn[idx(c)] == 0:
					conn[idx(c)] = 1
					stack.append(idx(c))
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % W
		var y := i / W
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= W or ny >= H:
				continue
			var j := ny * W + nx
			if g[j] == 1 and conn[j] == 0:
				conn[j] = 1
				stack.append(j)
	return conn


## Why a Clutch Mound can't stand at this spot, or "": it must be planted on swamp joined to a
## finished Burrow's swamp (no distance cap: the chain of swamp is the limit, and it is breakable).
func mound_problem(t: int, c: Vector2i) -> String:
	if faction_of(t) != "brood":
		return ""
	var size: Vector2i = Defs.BUILDINGS["clutch_mound"]["size"]
	if swamp_hall_conn.size() <= t or (swamp_hall_conn[t] as PackedByteArray).size() != W * H:
		_update_conn()
	var join: PackedByteArray = swamp_hall_conn[t]
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if in_map(cc) and join[idx(cc)] == 0:
				return "Must stand on swamp joined to a Burrow's swamp."
	return ""


## Why a Brood resource building (Feeding Pit, Brood Pen) can't stand at this spot, or "".
func brood_reach_problem(t: int, k: String, c: Vector2i) -> String:
	if faction_of(t) != "brood" or not Defs.is_econ(k):
		return ""
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var cap := capital(t)
	if cap == null:
		return "Needs a finished Burrow (your capital) first."
	if swamp_conn.size() <= t or (swamp_conn[t] as PackedByteArray).size() != W * H:
		_update_conn()
	var mid := (Vector2(c) + Vector2(size) * 0.5)
	var d := cap.center().distance_to(mid * T) / T
	if d > Defs.BROOD_RESOURCE_MAX_D or d > float(swamp_reach[t]) + 0.01:
		return "Too far from your capital (reach %d tiles): spread your swamp (plant a Clutch Mound) to reach farther." % int(swamp_reach[t])
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if in_map(cc) and (swamp_conn[t] as PackedByteArray)[idx(cc)] == 0:
				return "Must stand on swamp joined to your capital's."
	return ""


func econ_count(t: int, kind: String) -> int:
	return buildings.filter(func(b: Building) -> bool: return b.team == t and b.kind == kind and not b.dead).size()


func econ_limit(t: int, kind: String) -> int:
	if faction_of(t) == "brood" and kind == "feeding_pit":
		return BROOD_PIT_UNCAPPED       # the Brood's pits are limited by swamp reach, not by halls (placement_problem)
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
		tell(t, "Powder bank empty: man your Powder Mills.")
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
	if net_forward(self, "set_split", [t, name]): return
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
					u.hp = minf(u.max_hp, u.hp + float(b.d["mends"]) * 0.5 * line_net.speed_mult(b))


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
	var hive := capital(pit.team)
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
## yields nothing. Returns the load's value.
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
var exp_spots: ExpansionSpots         # the best expansion spots tinted on the ground (null in the editor)
var ground_marks: GroundMarks         # AREA MARKS on the ground (area_mark; scripts/ground_marks.gd)
var swipe_marks: GroundMarks          # the Pendulum's smear, over the units


## AN AREA MARK (docs/aoe_show.md): the real shape of an area attack laid on the ground where it strikes, fading in
## GroundMarks.STRIKE s (`life`), or a WARNING where a slow shot will land (`warn`: `life` = its flight), or the edge of a
## cloud or storm for as long as it lasts (`zone`). shape "ring" (radius r), "oval" (an ellipse squashed by FIELD_Y, as
## in_ellipse), "wedge" (from p toward the unit vector a, reach r, h radians either side), "band" (from p to a, r either
## side). col: a GroundMarks.COLS key. smear: also the Pendulum's crescent along the blade's low path (arm 0 right, 1
## left). Online, the host sends it to the guests (they lay it by their own fog). Shown to the side that made it (team)
## and to anyone whose side sees that ground now; Settings.area_marks off: none. Returns whether it was laid here.
func area_mark(shape: String, team: int, p: Vector2, a: Vector2, r: float, h: float, col: String, life: float = GroundMarks.STRIKE,
		warn := false, zone := false, arm := -1, smear := false) -> bool:
	if net != null and not puppet:
		net.note_mark([shape, p, a, snappedf(r, 0.1), snappedf(h, 0.001), col, snappedf(life, 0.01), warn, zone, arm, smear, team])
	if not Settings.area_marks or ground_marks == null or r <= 0.0:
		return false
	var probe := p
	if shape == "wedge":
		probe = p + a * r * 0.6
	elif shape == "band":
		probe = (p + a) * 0.5
	if not mark_seen(team, p) and not mark_seen(team, probe):
		return false
	var c: Color = GroundMarks.COLS.get(col, Color(1, 1, 1))
	ground_marks.add({"s": shape, "c": c, "p": p, "a": a, "r": r, "h": h, "life": life, "warn": warn, "zone": zone, "team": team})
	if smear:
		swipe_marks.add({"s": "smear", "c": c, "p": p, "a": a, "r": r * 0.7, "h": h, "life": GroundMarks.SMEAR, "arm": arm, "team": team})
	return true


## Would the watching side see an area mark at p made by `team`? Its own side's always (it fired it); else only where its
## side sees the ground now (the fog), or everywhere with no fog drawn.
func mark_seen(team: int, p: Vector2) -> bool:
	if sees_all():
		return true
	var me := fog_team()
	if team >= 0 and allied(team, me):
		return true
	return side_sees(me, p)


## A float_text "+N" for an income the owner of `team` collects: shown only to that side (as the Farm's harvest and the
## grub's drop); online, the host sends it to a guest playing that side.
func own_float(team: int, p: Vector2, txt: String, col: Color) -> void:
	if team == human and not demo:
		float_text(p, txt, col)
	elif net != null and not puppet and net.peer_team.values().has(team):
		net.note_float(team, p, txt, col)


func float_text(p: Vector2, txt: String, col: Color) -> void:
	_floats.append([p, Loc.t(txt), col, 1.4])


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

## Online guest: send this call to the host instead of running it (true: it was sent, the caller
## returns). Everywhere else (the host, single player) false and the call runs as always.
func net_forward(who: Object, fn: String, args: Array) -> bool:
	if net == null:
		return false
	if puppet:
		return NetCommands.forward(net, who, fn, args)
	if input_cmd and net_cmd_team < 0 and net.hold_ms() > 0:
		return NetCommands.hold(net, who, fn, args)     # (online host, the same delay for both: it waits as a guest's order does)
	return false


## Set a command-card setting (auto repair, auto training ...) on something of yours; an online
## guest asks the host too.
func net_set(e: Object, prop: String, v) -> void:
	if puppet and net != null and net.predict != null and net.predict.on:
		NetCommands.forward(net, e, "@" + prop, [v])     # (shown at once by the click's prediction, taken back if refused)
		return
	e.set(prop, v)
	if puppet and net != null:
		NetCommands.forward(net, e, "@" + prop, [v])


var _serial := 0                 # Entity.serial of the last unit or building made
## A Tesla Cart or Tesla Locomotive has been made this match (or morphed into): until then
## in_field and in_overcharge, asked by every Clockwork unit, needn't look through the units.
var tesla_made := false


func _add_unit(k: String, t: int, pos: Vector2) -> Unit:
	var u := Unit.new()
	if k == "tesla_cart" or k == "tesla_loco":
		tesla_made = true
	_serial += 1
	u.serial = _serial
	u.setup(self, k, t, pos)
	apply_drills(u)
	world.add_child(u)
	units.append(u)
	if Defs.cw_roster:
		CwUnits.on_created(self, u)
	return u


## ghost: a placed site whose construction hasn't started (Building.ghost): it takes no
## ground until it does (_solidify).
func _add_building(k: String, t: int, c: Vector2i, complete: bool, ghost := false) -> Building:
	var b := Building.new()
	_serial += 1
	b.serial = _serial
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
## Farm's crop rows and a Powder Mill's work yard walkable) and anyone left standing there is
## pushed out (but `keep`).
func _solidify(b: Building, keep: Array = []) -> void:
	var k := b.kind
	var c := b.cell
	if b.ghost:
		_reserve_ghost(b, false)
		b.ghost = false
		b.block_since = -1.0
		b.asked.clear()
	if k == "feeding_pit":
		claim_pit_ground(b)      # (its own ground, or what old ground under its circle has left)
	if Defs.BUILDINGS[k].get("gate", false):
		_mark(c, b.size, 3)
		gate_team[idx(c)] = b.team
	else:
		_mark(c, b.size, 4 if Defs.BUILDINGS[k].get("line", false) else 2)
	for fc in Building.field_cells(k):
		_mark(c + fc, Vector2i.ONE, 5)      # a Farm's crop rows, a Mill's yard: men walk them, nothing is built on them
	_cover_decos(b)
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
			note_move(u)
			if u._k_fac == "brood" and BroodNew.on(self, u.team):
				BroodRoot.start_pass(self, u)      # (put in a pocket between its own rooted creatures: it walks out through them)


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


## A ghost's cells still free to build on (no terrain or building has come there since, nor
## one its player hadn't seen when it ordered it: there is no black fog to stop that order).
func site_cells_free(b: Building) -> bool:
	if line_net.blocks(b.cell, b.size):
		return false
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
## why: "blocked" (the footprint stayed blocked), "unreachable" (its grub or Winder can't
## get there), "abandoned" (nobody is coming to start it any more: no toast, it's the
## player's own doing or the worker died).
func site_failed(b: Building, why := "blocked") -> void:
	if b.dead:
		return
	var t := b.team
	var cost := int(b.d["cost"])
	players[t]["gold"] += cost
	add_tension(t, float(Defs.tension_cost(b.d)))          # (and its Tension price, all of it)
	stats[t]["spent"] -= cost
	stats[t]["built"] = maxi(0, int(stats[t]["built"]) - 1)
	if t == human and not demo and hud and why != "abandoned":
		_notify_t = Time.get_ticks_msec()
		hud.toast("Can't build there: the spot is blocked." if why == "blocked" else "Can't build there: it can't be reached.", true)
		Sfx.announce(faction_of(t), "bad_place", 4.0)
	elif t != human and not demo and why != "abandoned":
		tell(t, "Can't build there: the spot is blocked." if why == "blocked" else "Can't build there: it can't be reached.")
	if mlog:
		var wl: String = {"blocked": "the spot was blocked", "unreachable": "it couldn't be reached", "abandoned": "nobody was coming to start it"}.get(why, why)
		mlog.add("%s %s a %s: %s (refunded)" % [mlog.who(t), "dropped" if why == "abandoned" else "couldn't start", b.d["name"], wl])
	if b.ghost:
		remove_ghost(b)
	else:
		# (a Brood site its grub never finished turning into: it was already solid)
		_remove_quietly(b)
		_recount_supply(t)
	for u in units.duplicate():
		if u.team == t and not u.dead and u.order == "build" and u.order_target == b:
			u.site_gone()
	for ai in ais:
		if ai.team == t and ai.has_method("site_failed"):
			ai.site_failed(b, why)


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


## The nearest free cell to a goal, on the goal cell's own height level when there is one close
## by (a click on the rim of a plateau, which is a cliff cell, or on a tree on the high ground
## means the high ground; the nearest free cell by distance alone was as often the low ground
## below the cliff, and the units went all the way round to stand under it). Else nearest_free.
func nearest_free_level(c: Vector2i, max_r := 8) -> Vector2i:
	if not in_map(c) or (is_free(c) and in_open_map(c)):
		return nearest_free(c, max_r)
	var lv := int(height[idx(c)])
	for r in range(1, max_r + 1):
		var best := Vector2i(-1, -1)
		var bd := INF
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if absi(x) != r and absi(y) != r:
					continue
				var cc := c + Vector2i(x, y)
				if is_free(cc) and int(height[idx(cc)]) == lv and ramp[idx(cc)] == 0 and in_open_map(cc):
					var dd := Vector2(x, y).length()
					if dd < bd:
						bd = dd
						best = cc
		if best.x >= 0:
			return best
	return nearest_free(c, max_r)


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
		# (a horse isn't counted in the losses; the Brood still feeds on its body: the grubs
		# can harvest it like any other)
		if brood_in_match():
			corpses.append(u)
		return
	stats[u.team]["lost"] += 1
	# veterancy: the unit that dealt the last blow gets the kill
	var hitter = u.last_hitter
	if is_instance_valid(hitter) and hitter is Unit and not hitter.dead and hostile(hitter.team, u.team):
		(hitter as Unit).kills += 1
	# (the fallen lie for the Brood's grubs to harvest; a Brood Pen no longer takes bodies by itself)
	if brood_in_match() and not u.is_air():
		corpses.append(u)
	# a Crown soldier's body: a Missionary may raise him (not one who fell under the cross)
	if not u.final_death and (Defs.REVIVE["kinds"] as Array).has(u.kind):
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


## The essence a harvested body gives: Defs.HARVEST per_supply (2) for each point of its body_supply, plus 1 a kill up
## to the kills veterancy counts (Defs.VET max / per_kill: 50, the owner, 0.14.41; it had no cap before).
## A float (essence is kept as one): a Musketeer or a Raptor 2, a Brute 6, a Horseman on his horse 8.
func corpse_value(u: Unit) -> float:
	var vet_kills := float(Defs.VET["max"]) / float(Defs.VET["per_kill"])
	return float(body_supply(u)) * float(Defs.HARVEST["per_supply"]) + minf(float(u.kills), roundf(vet_kills))


## An amount of essence as text: "5", "1.25", "2.5".
static func essence_text(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.2f" % v).trim_suffix("0")


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
	# a Feeding Pit's ground stays on the land as an OLD GROUND spot (its circle, what was left)
	if b.kind == "feeding_pit" and not puppet and (b.built or b.soil < b.reserve() - 0.5):
		pit_spots.append([b.center(), maxf(b.soil, 0.0), b.team])
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
	var cap := BroodNew.supply_cap(self, t)
	for b in buildings:
		if b.team == t:
			cap += b.supply()
	players[t]["cap"] = mini(cap, max_supply(t))


func supply_used(t: int) -> int:
	var n := 0
	for u in units:
		if u.team == t and not u.dead:
			n += int(u.d["supply"])
			if u._k_still and u.kind == BroodNew.EGG and not u.nb.has("out"):
				var ek := String(u.nb.get("k", "grub"))      # (a new-Brood egg holds its creature's supply)
				n += int(Defs.UNITS[ek]["supply"]) * int(Defs.UNITS[ek].get("spawn", 1))
			if u.owl_t >= 0.0:
				n += int(Defs.UNITS[Defs.OWL]["supply"]) - int(u.d["supply"])     # (a Swift turning into an Owl holds its supply)
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
	if kit.has("coat") and at != null and k != "horse":      # (a queued horse's coat is its own: no second horse)
		var hh := _kit_horse(kit, at)
		if hh != null:
			hh._unhitch()           # (the horse hitched beside the building, or still on its way, is free again where it stands)
			hh.horse_rid = 0
		else:
			horse_back(at, kit)     # (a loaded game's entry: its horse comes back out)
	if int(kit.get("rid", 0)) != 0 and k != "horse":
		release_rid(t, int(kit["rid"]))     # (its horse is free again; one still at the breeder is kept)
	if Building.is_research(k):
		var info: Dictionary = Defs.RESEARCH[k.substr(1)]
		players[t]["gold"] += int(info["cost"])
		add_res2(t, float(info.get("cost2", 0)))
		add_tension(t, float(Defs.tension_cost(info)))
		stats[t]["spent"] -= int(info["cost"])
		return
	var fee := kit_fee(kit, k)
	players[t]["gold"] += int(Defs.UNITS[k]["cost"]) + fee[0]
	if Defs.tension_cost(Defs.UNITS[k]) > 0:
		add_tension(t, float(Defs.tension_cost(Defs.UNITS[k])))      # (gear mode's Clockwork: its Tension back)
	elif faction_of(t) == "clockwork":
		give_batteries(t, int(Defs.UNITS[k].get("cost2", 0)))
	else:
		add_res2(t, int(Defs.UNITS[k].get("cost2", 0)) + fee[1])


## TENSION (gear mode's Clockwork, wound by the Mainsprings: Defs.GEAR "mainspring"): what player t holds, and adding to
## it (spending: a negative v; never below 0). Spent on the Springer and the Escapement's research (their `tension` price).
func tension(t: int) -> float:
	return float(players[t].get("tension", 0.0))


func add_tension(t: int, v: float) -> void:
	if v != 0.0:
		players[t]["tension"] = maxf(0.0, tension(t) + v)


## "" when player t can pay `n` Tension, else the refusal.
func tension_problem(t: int, n: int) -> String:
	if n > 0 and tension(t) < float(n):
		return "Not enough Tension: it needs %d. Winders cranking a Mainspring wind more." % n
	return ""


## Does player t have a finished `kind` that is WORKING (gear mode: linked, and a Tension user meshed with a Mainspring)?
func has_working(t: int, kind: String) -> bool:
	for b in buildings:
		if b.team == t and b.kind == kind and b.built and not b.dead and gear_net.speed_mult(b) > 0.0:
			return true
	return false


## Why a Tension user (the Escapement) of player t does not unlock or research now: "" when one works.
func tension_user_problem(t: int, kind: String) -> String:
	if has_working(t, kind):
		return ""
	if not _has_built(t, kind):
		return "Needs an Escapement first." if kind == Defs.CW_TECH else "Needs a %s first." % Defs.BUILDINGS[kind]["name"]
	for b in buildings:
		if b.team == t and b.kind == kind and b.built and not b.dead and gear_net.needs_spring(b):
			return _idle_text(kind)
	return _unlinked_text(kind)


## A Tension user's refusals (the Escapement's, the Clock Aviary's).
func _idle_text(kind: String) -> String:
	if kind == Defs.CW_AIR:
		return "The Clock Aviary stands idle: mesh its gear ring with a Mainspring's."
	if kind == Defs.CW_HEAVY:
		return "The Heavy Works stands idle: mesh its gear ring with a Mainspring's."
	return "The Escapement stands idle: mesh its gear ring with a Mainspring's."


func _unlinked_text(kind: String) -> String:
	if kind == Defs.CW_AIR:
		return "The Clock Aviary is unlinked: its gear ring must mesh with the gear field."
	if kind == Defs.CW_HEAVY:
		return "The Heavy Works is unlinked: its gear ring must mesh with the gear field."
	return "The Escapement is unlinked: its gear ring must mesh with the gear field."


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
	if Defs.energy_only(k):
		return "No power on the gear field."      # (gear mode: Defs.ENERGY_KINDS)
	var u: Dictionary = Defs.UNITS[k]
	var rs: String = u.get("research", "")
	if rs != "" and not has_tech(b.team, rs):
		var info: Dictionary = Defs.RESEARCH[rs]
		return "Research %s at the %s first." % [info["name"], Defs.BUILDINGS[info["at"]]["name"]]
	# the tech step: the Brood's and the Clockwork's ranged units need their second economy building
	var reqs: Array = u["requires"] if u.get("requires", "") is Array else ([u["requires"]] if u.get("requires", "") != "" else [])
	for req in reqs:
		if Defs.gear_mode and Defs.TENSION_USERS.has(req):
			# (tier 2: the Springer needs an Escapement that WORKS: linked and meshed with a Mainspring)
			var tp := tension_user_problem(b.team, req)
			if tp != "":
				return tp
		elif not _has_built(b.team, req):
			return "Needs a %s first." % Defs.BUILDINGS[req]["name"]
	if u.get("big_gear", false):
		var gp := Pendulum.gear_problem(b)      # (tier 3: the Pendulum, only on the Works' BIG gear: the heavy torque)
		if gp != "":
			return gp
	if Defs.tension_cost(u) > 0:
		var spp := GearEcon.spend_problem(self, b)      # (THE TENSION RULE: made only where a Mainspring meshes, GearEcon)
		if spp != "":
			return spp
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
	if Defs.tension_cost(u) > 0:
		var tw := tension_problem(b.team, price[1])      # (gear mode's Clockwork: the second price is Tension)
		if tw != "":
			return tw
	elif float(players[b.team]["res2"]) < price[1]:
		return "Not enough %s." % res[1].to_lower()
	if u.has("per"):
		var have := units.filter(func(x: Unit) -> bool: return x.team == b.team and not x.dead and (x.kind == k or String(Defs.FOOT.get(x.kind, "")) == k)).size()
		for bb in buildings:
			if bb.team == b.team and not bb.dead:
				have += bb.queue.count(k)
		var allowed := buildings.filter(func(x: Building) -> bool: return x.team == b.team and x.kind == u["per"] and x.built and not x.dead).size()
		if have >= allowed:
			return "Only one %s per %s." % [u["name"], Defs.BUILDINGS[u["per"]]["name"]]
	if Defs.cw_roster and Defs.CW_KINDS.has(k):
		var cwp := CwUnits.limit_problem(self, b.team, k, b.queue.count(k))
		if cwp != "":
			return cwp
	if supply_used(b.team) + int(u["supply"]) * int(u.get("spawn", 1)) + CwUnits.extra_supply(k) > players[b.team]["cap"]:
		if players[b.team]["cap"] >= max_supply(b.team):
			return "Supply is maxed out."
		var sup: String = Defs.supply_kind(factions[b.team])
		return "Need more supply: build a %s." % Defs.BUILDINGS[sup]["name"]
	return ""


## How fast a Brood player's Hives lay eggs: +10% for every Clutch Mound, up to +30%.
func egg_rate(t: int) -> float:
	var n := 0
	for b in buildings:
		if b.team == t and b.kind == "clutch_mound" and b.built and not b.dead:
			n += 1
	return 1.0 + minf(0.1 * n, 0.3)


## LINE tool for a SIDING (CwRail): toggles a side arm on a straight piece of the team's Line; "" or why not.
func siding_order(t: int, c: Vector2i) -> String:
	return CwRail.toggle_siding(self, t, c)


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
	if Defs.gear_mode and Defs.TENSION_USERS.has(b.kind) and gear_net.speed_mult(b) <= 0.0:
		# (a Tension user researches only while it works: linked and meshed with a Mainspring)
		if gear_net.needs_spring(b):
			return _idle_text(b.kind)
		return _unlinked_text(b.kind)
	if Defs.tension_cost(info) > 0:
		var sp := GearEcon.spend_problem(self, b)       # (THE TENSION RULE: made only where a Mainspring meshes)
		if sp != "":
			return sp
	var res: Array = Defs.res_names(factions[b.team])
	if players[b.team]["gold"] < int(info["cost"]):
		return "Not enough %s." % String(res[0]).to_lower()
	if Defs.tension_cost(info) > 0:
		return tension_problem(b.team, Defs.tension_cost(info))
	if float(players[b.team]["res2"]) < float(info.get("cost2", 0)):
		return "Not enough %s." % String(res[1]).to_lower()
	return ""


## Research works like training: paid up front, it joins the building's production queue
## (as "@key") and takes its turn there; CANCEL takes it back out, paid back.
func start_research(b: Building, key: String) -> String:
	if net_forward(self, "start_research", [b, key]): return ""
	var why := research_problem(b, key)
	if why != "":
		return why
	players[b.team]["gold"] -= int(Defs.RESEARCH[key]["cost"])
	add_res2(b.team, -float(Defs.RESEARCH[key].get("cost2", 0)))
	add_tension(b.team, -float(Defs.tension_cost(Defs.RESEARCH[key])))
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
		# (the Clockwork rings its old clock bell once, clock/research)
		Sfx.announce(faction_of(b.team), "research_done", 3.0, "research" if faction_of(b.team) == "clockwork" else "")
	elif not demo:
		var what2 := ("%s unlocked." % Defs.UNITS[info["unlocks"]]["name"]) if info.has("unlocks") else String(info["about"])
		tell(b.team, "%s researched: %s" % [info["name"], what2], true)      # (online: the guest who researched it)
	if mlog:
		mlog.add("%s researched %s" % [mlog.who(b.team), info["name"]])


# ------------------------------------------------------------------ Brood hall levels

## "" if this hall can start growing into its next level (Defs.HALL_LEVELS), else why not.
func hall_upgrade_problem(b: Building) -> String:
	if not b.is_leveled() or not b.built or b.dead:
		return "Can't upgrade that."
	var nl := b.next_level()
	if nl.is_empty():
		return "Already a %s." % b.level_info()["name"]
	if b.upgrade_t >= 0.0:
		return "Already upgrading."
	var needs := String(nl.get("needs", ""))
	if needs != "" and not _has_built(b.team, needs):
		return "Needs a %s first." % Defs.BUILDINGS[needs]["name"]
	var res: Array = Defs.FACTIONS[factions[b.team]]["res"]
	if players[b.team]["gold"] < int(nl["cost"]):
		return "Not enough %s." % String(res[0]).to_lower()
	if float(players[b.team]["res2"]) < float(nl.get("cost2", 0)):
		return "Not enough %s." % String(res[1]).to_lower()
	return ""


## Start growing the hall into its next level: paid up front; it keeps laying, hatching and
## taking food meanwhile. "" when started, else why not.
func start_hall_upgrade(b: Building) -> String:
	if net_forward(self, "start_hall_upgrade", [b]): return ""
	var why := hall_upgrade_problem(b)
	if why != "":
		return why
	var nl := b.next_level()
	players[b.team]["gold"] -= int(nl["cost"])
	add_res2(b.team, -float(nl.get("cost2", 0)))
	stats[b.team]["spent"] += int(nl["cost"])
	b.upgrade_t = 0.0
	b.queue_redraw()
	if mlog:
		mlog.add("%s started upgrading a %s to a %s" % [mlog.who(b.team), b.d["name"], nl["name"]])
	return ""


## Stop the hall's upgrade, paid back (`dying`: it was destroyed, nothing said).
func cancel_hall_upgrade(b: Building, dying := false) -> void:
	if b.upgrade_t < 0.0:
		return
	b.upgrade_t = -1.0
	var nl := b.next_level()
	if nl.is_empty():
		return
	players[b.team]["gold"] += int(nl["cost"])
	add_res2(b.team, float(nl.get("cost2", 0)))
	stats[b.team]["spent"] -= int(nl["cost"])
	b.queue_redraw()
	if mlog and not dying:
		mlog.add("%s cancelled upgrading a %s to a %s" % [mlog.who(b.team), b.d["name"], nl["name"]])


## The hall has grown into its next level.
func hall_upgraded(b: Building) -> void:
	var was := String(b.d["name"])
	b.set_level(b.level + 1)
	tell(b.team, "Your %s has grown into a %s: up to %d eggs." % [was, b.d["name"], b.eggs_max()], true)
	if b.team == human:
		Sfx.announce(faction_of(b.team), "research_done", 3.0)
	if mlog:
		mlog.add("%s upgraded a %s to a %s" % [mlog.who(b.team), was, b.d["name"]])


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
	if k == "musketeer" or k == "dragoon":
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
	if Defs.tension_cost(u) > 0:
		p[1] = Defs.tension_cost(u)          # (gear mode's Clockwork: the second price is Tension)
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
	if net_forward(self, "refit_order", [list, what, quiet]): return []
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
	if Defs.tension_cost(Defs.UNITS[k]) > 0:
		add_tension(b.team, -float(price[1]))      # (gear mode's Clockwork: Tension)
	elif faction_of(b.team) == "clockwork":
		spend_batteries(b.team, price[1])
	else:
		add_res2(b.team, -price[1])
	stats[b.team]["spent"] += price[0]
	var kit := kit_for_new(b.team, key)
	if Defs.UNITS[k].get("needs_horse", false):
		# the horse at the building is his: it stands hitched beside it till he comes out on it
		var h := free_horse_at(b)
		kit = kit.duplicate()
		if h:
			kit["coat"] = h.coat
			kit["hh"] = snappedf(h.hp / maxf(h.max_hp, 1.0), 0.01)
			kit["hm"] = snappedf(h.horse_miles, 0.1)
			kit["hid"] = h.get_instance_id()     # (the live horse: Game._kit_horse)
			h.walk_into(b)
		else:
			# one click trains both: a free horse at a breeder is kept for him, or the
			# nearest breeder trains one (paid now); a gun's horse walks over by itself
			kit["rid"] = new_rid()
			_reserve_horse(b, k, int(kit["rid"]), true)
	if k == "horse":
		kit = kit.duplicate()
		kit["coat"] = HorseCoat.pick()      # (decided now: the paddock shows it, the horse comes out in it)
	b.add_entry(k, kit)
	if b.uses_eggs():
		b.eggs -= 1
		b.morph_t.append(0.0)
	return ""


func cancel_train(b: Building) -> void:
	if net_forward(self, "cancel_train", [b]): return
	if b.queue.is_empty():
		return
	var kit := b.kit_at(b.queue.size() - 1)
	var k: String = b.queue.pop_back()
	if b.kits.size() > b.queue.size():
		b.kits.resize(b.queue.size())
	if b.uses_eggs():
		b.morph_t.pop_back()        # (the egg is lost: cancelling gives back the cost, not the egg)
	if b.queue.is_empty():
		b.prod_t = 0.0
	refund(b.team, k, kit, b)
	if Building.is_research(k):
		_drop_dependent_research(b.team, k.substr(1))


## Cancel one entry of the production line (a click on its picture in the unit card).
func cancel_train_at(b: Building, i: int) -> void:
	if net_forward(self, "cancel_train_at", [b, i]): return
	if i < 0 or i >= b.queue.size():
		return
	if i == b.queue.size() - 1:
		cancel_train(b)
		return
	var k: String = b.queue[i]
	var kit := b.take_entry(i)
	if b.uses_eggs():
		b.morph_t.remove_at(i)      # (the egg is lost)
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
		elif not Sfx.recruit(b.kind, b.d["faction"]):
			Sfx.play_f_once("ready", b.d["faction"], 6.0, -3.0)
		Sfx.voice(k, "select")
	var rid := int(kit.get("rid", 0))
	var sk := k
	var spawn_at := cell_center(best)
	var hh := _kit_horse(kit, b)
	if hh != null:
		# the horse waiting hitched beside the building (or still on its way to it): the rider
		# comes out in its place, on its coat and health as they are now; a gun is drawn by it
		kit = kit.duplicate()
		kit.erase("hid")
		kit["coat"] = hh.coat
		kit["hh"] = snappedf(hh.hp / maxf(hh.max_hp, 1.0), 0.01)
		kit["hm"] = snappedf(hh.horse_miles, 0.1)
		if hh.hitch_p != Vector2.INF and Defs.FOOT.has(k) and hh.position.distance_to(hh.hitch_p) < 8.0 \
				and in_open_map(cell_of(hh.position)):
			spawn_at = hh.position
		consume_unit(hh)
	if Defs.RIDERS.has(k) and rid != 0:
		sk = String(Defs.RIDERS[k])    # trained on foot: he goes and gets on the horse kept for him
	for n in int(Defs.UNITS[k].get("spawn", 1)):
		var u := _add_unit(sk, b.team, spawn_at + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
		if sk != k:
			u.set_kit(kit)
			u.horse_rid = rid
			u.rally_after = b.rally
			u._res_t = 0.0
			continue
		if not kit.is_empty():
			u.set_kit(kit)          # (a soldier paid to come out armoured, a Musketeer with a better lock)
		if kit.has("coat") and HorseCoat.COATS.has(String(kit["coat"])):
			u.coat = String(kit["coat"])      # the horse hitched for him
			u.horse_hp = float(kit.get("hh", 1.0))
			u.horse_miles = float(kit.get("hm", 0.0))
			if u.is_mounted():
				u.max_hp += Unit.horse_bonus_hp(u.horse_miles)    # a seasoned horse under him
				u.hp = u.max_hp
			HorseCoat.apply(u)
		if u.is_worker():
			var site: Building = null
			if b.dual_rally() and is_instance_valid(b.worker_rally_target) and b.worker_rally_target is Building:
				site = b.worker_rally_target
			elif not b.dual_rally() and is_instance_valid(b.rally_target) and b.rally_target is Building:
				site = b.rally_target
			if site != null and not site.dead and site.haul_cap() > 0:
				# A rally point on the Town Hall is no order to haul: a real post (farm, mine,
				# pit) comes first; he hauls only when every other job is taken and the hall has room.
				var post := free_site(b.team, u.position)
				if post != null:
					site = post
			if site == null or site.dead or site.crew.size() >= site.crew_max() or site.barren():
				var was_site := site != null and not site.dead
				site = null
				var rp: Vector2 = b.worker_rally if b.dual_rally() else b.rally
				if rp == Vector2.INF or was_site:
					# (its rally's pit or farm is full: the next one with room instead of
					# standing idle beside it)
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
						if not (owner as Building).can_train("cuirassier") and not hauler_serves_rid(b.team, rid):
							u.walk_into(owner)
					continue
			if b.rally != Vector2.INF:
				u.cmd_move(b.rally + Vector2(randf_range(-20, 20), randf_range(-20, 20)))
			continue
		if is_instance_valid(b.rally_target) and b.rally_target is Unit and not b.rally_target.dead:
			u.cmd_follow(b.rally_target)
		elif b.rally != Vector2.INF:
			u.cmd_move(b.rally + Vector2(randf_range(-20, 20), randf_range(-20, 20)), true)


func requirement_met(t: int, k: String) -> bool:
	return requirement_text(t, k) == ""


var _sweep_pos := {}       # sweep_ghosts: a ghost's instance id -> where its worker was last time
var _ghost_t := 0.2
var _crown_orphan := {}    # sweep_ghosts: a Crown ghost's instance id -> sweeps in a row nobody was coming


## Ghosts need a worker to start them (a grub turns into it, a Winder brings its crate, the
## Labourers begin it). So a ghost whose worker is no longer coming (re-ordered, stopped,
## killed) goes, all of its cost back, as in StarCraft 2. A Clockwork crate dropped on the
## ground or carried keeps its site (any Winder can carry it on). A worker that can't get to
## its site (stuck in the same spot over two sweeps, and no walking path there) gives it up
## too. Crown: a Labourer that finishes a site takes up the nearest unfinished Crown site
## within 8 tiles (Game.next_site: how a wall laid without Shift gets built piece by piece),
## so a Crown ghost is kept while it is in such a chain from a site a Labourer is coming to;
## it goes after two sweeps in a row with nobody coming. Sites already begun (Crown: any
## progress) are never swept. Run about once a second (from the tick).
func sweep_ghosts(quick := false) -> void:
	var sites: Array = []
	if not _sweep_pos.is_empty():
		for id in _sweep_pos.keys():
			if not is_instance_id_valid(id):
				_sweep_pos.erase(id)
	var any_crown := false
	for b in buildings:
		if b.dead or b.built or b.team < 0 or not (b.ghost or not b.seeded):
			continue
		var f: String = b.d["faction"]
		if Defs.cw_roster and f == "clockwork" and CwUnits.car_claims(self, b):
			continue                                    # (a Work Car has this site: its crew come out to it)
		if f == "brood" or (f == "clockwork" and b.ghost and (b.crate == "" or b.crate == "tower")) \
				or (f == "crown" and b.ghost):
			sites.append(b)
			any_crown = any_crown or f == "crown"
	if sites.is_empty():
		_crown_orphan.clear()
		return
	var crown_kept := _crown_chain() if any_crown else {}
	var orphans := {}
	for b in sites:
		if b.d["faction"] == "crown":
			var cid: int = b.get_instance_id()
			if crown_kept.has(b):
				continue
			# a Crown ghost only exists while a Labourer is on his way to it (or has it
			# queued): nobody coming, it's gone at once (refunded). A computer's wall piece
			# first finds a labourer (AI.adopt_site): a builder killed or pulled off must not
			# cost it the wall.
			var adopted := false
			for ai in ais:
				if ai.team == b.team and ai.has_method("adopt_site") and ai.adopt_site(b):
					adopted = true
					break
			if not adopted:
				site_failed(b, "abandoned")
			continue
		var coming: Unit = null
		for u in units:
			if u.team != b.team or u.dead or not u.is_worker():
				continue
			if u.order == "build" and u.order_target == b:
				coming = u
				break
			if u.line_rest.has(b):
				coming = u
				break
			for o in u.queue:
				if (o.get("e") == b and String(o["o"]) == "build") or (String(o["o"]) == "wall" and (o["pieces"] as Array).has(b)):
					coming = u
					break
			if coming:
				break
		if coming == null:
			if b.ghost or b.d["faction"] == "brood":
				site_failed(b, "abandoned")
			continue
		if quick:
			continue
		var id: int = b.get_instance_id()
		if not b.ghost or coming.order != "build" or coming.order_target != b or coming.work != "to_site":
			_sweep_pos.erase(id)
			continue
		# its worker on the way: the same spot over two sweeps, far from the site: can it get there?
		var last = _sweep_pos.get(id)
		_sweep_pos[id] = coming.position
		if last is Vector2 and (last as Vector2).distance_to(coming.position) < 6.0 \
				and b.edge_distance(coming.position) > coming.radius + 24.0 \
				and not coming._walk_reaches_point(approach_point(b, coming.position)):
			# (its worker goes on to its next order; a site planned over a building its player
			# hadn't seen, which he can't get into: blocked)
			site_failed(b, "unreachable" if site_cells_free(b) else "blocked")
	_crown_orphan = orphans


## The unfinished Crown sites (ghosts or begun) a Labourer is coming to: going there now,
## with it next in his wall (line_rest) or Shift-queued; and every other unfinished Crown
## site of that side within next_site's reach (8 tiles) of one of those, and so on (the
## Labourers go on from one to the next). A set: site -> true.
func _crown_chain() -> Dictionary:
	var kept := {}
	var todo: Array = []
	var anchors: Array = []
	for u in units:
		if u.dead or u.kind != "labourer":
			continue
		var mine: Array = []
		if u.order == "build" and u.order_target is Building:
			var cur: Building = u.order_target
			if cur.built and not cur.dead and cur.d["faction"] == "crown":
				# just finished, not yet moved on (the sweep can run between the two):
				# the chain goes on from here, as next_site will take him to the next piece
				anchors.append(cur)
			mine.append(u.order_target)
		mine.append_array(u.line_rest)
		for o in u.queue:
			if String(o["o"]) == "build" and o.get("e") is Building:
				mine.append(o["e"])
			elif String(o["o"]) == "wall":
				mine.append_array(o["pieces"])
		for b in mine:
			if b is Building and is_instance_valid(b) and not b.dead and not b.built \
					and b.d["faction"] == "crown" and not kept.has(b):
				kept[b] = true
				todo.append(b)
	if todo.is_empty() and anchors.is_empty():
		return kept
	var open: Array = buildings.filter(func(b: Building) -> bool:
		return not b.dead and not b.built and b.team >= 0 and b.d["faction"] == "crown")
	var reach := 8.0 * T
	for a in anchors:
		for b in open:
			if not kept.has(b) and b.team == a.team and b.center().distance_to(a.center()) < reach:
				kept[b] = true
				todo.append(b)
	while not todo.is_empty():
		var a: Building = todo.pop_back()
		for b in open:
			if not kept.has(b) and b.team == a.team and b.center().distance_to(a.center()) < reach:
				kept[b] = true
				todo.append(b)
	return kept


## "" when every building this one needs stands (finished), else what's missing.
func requirement_text(t: int, k: String) -> String:
	if Defs.energy_only(k):
		return "No power on the gear field."      # (gear mode: Defs.ENERGY_KINDS)
	var r = Defs.BUILDINGS[k].get("requires", "")
	var reqs: Array = r if r is Array else ([r] if r != "" else [])
	for req in reqs:
		if Defs.gear_mode and Defs.TENSION_USERS.has(req):
			# (the Clock Aviary needs an Escapement that WORKS: linked and meshed with a Mainspring)
			var tp := tension_user_problem(t, req)
			if tp != "":
				return tp
		elif not _has_built(t, req):
			return "Needs a %s first." % Defs.BUILDINGS[req]["name"]
	return ""


## "" if the building can go at this cell, else the reason. ai: the computer's rules (it
## keeps its ramps clear, and sees the map as it is). Anywhere on the map will do, seen or not;
## a player who plans by sight (you) isn't stopped by an enemy building it has never seen:
## the worker finds the spot blocked when he gets there (_plans_by_sight).
func placement_problem(t: int, k: String, c: Vector2i, ai := false, limits_checked := false) -> String:
	var size: Vector2i = Defs.BUILDINGS[k]["size"]
	var by_sight := not ai and _plans_by_sight(t)
	if _pipe_in_way(t, c, size, by_sight):
		return "A pipe is in the way."
	var unk: PackedByteArray = _unknown_grid(t) if by_sight else _EMPTY
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
				if unk.is_empty() or not in_map(cc) or unk[idx(cc)] == 0:
					return "Blocked."
			var gh := side_ghost_at(t, cc)
			if gh != null and not (gh.team == t and ((k == "gate" and gh.kind == "wall") or (k == "wall" and gh.kind == "gate"))):
				return "Blocked: a building is planned there."
			if needs_swamp(k) and swamp[t][idx(cc)] == 0:
				return "Brood structures must grow on your swamp."
			# the computer keeps its ramps clear (for its own wall and its army)
			if ai and not Defs.BUILDINGS[k].get("line", false) and _near_ramp(cc):
				return "Keep the ramp clear."
	if Defs.gear_mode and Defs.BUILDINGS[k]["faction"] == "clockwork" and not _gear_relax:
		var gp := gear_net.placement_problem(t, k, c)      # (the gear ring must touch the connected field: scripts/gear.gd)
		if gp != "":
			return gp
	if k == "clutch_mound":
		var mp := mound_problem(t, c)
		if mp != "":
			return mp
	if k == "feeding_pit":
		var pp := pit_claim_problem(t, c)      # (each pit claims a circle of ground: they may not overlap)
		if pp != "":
			return pp
	if k == Defs.CW_TURRET:
		var tp := GearNet.turret_problem(self, t, c)      # (THE TURRET CIRCLE: each turret claims a circle; no overlap)
		if tp != "":
			return tp
	if ai and ai_keep.has(t):
		for kk in ai_keep[t]:
			if String(kk) != k and _takes_kept(t, k, c, String(kk)):
				return "Kept for a building the computer lays next."
	if k == faction_hall(t):
		var mid0 := (Vector2(c) + Vector2(size) * 0.5) * T
		# (the Brood has no spacing rule: Burrows own no ground and deliveries go to the capital,
		# so only the usual footprint and margin rules keep two apart)
		var spacing: int = 0 if faction_of(t) == "brood" else Defs.HALL_SPACING
		for h in (_spot_all_halls if limits_checked and _in_spot else halls_of(t, false)):
			if h.center().distance_to(mid0) < spacing * T:
				return "Too close to your other %s: it needs its own ground." % Defs.BUILDINGS[k]["name"]
	if Defs.is_econ(k):
		var rp := brood_reach_problem(t, k, c)
		if rp != "":
			return rp
		if not limits_checked and econ_count(t, k) >= econ_limit(t, k):
			if faction_of(t) == "brood":
				return "Each Burrow allows one Brood Pen: raise another Burrow at home for more."
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


## A pipe of the Line under a building at c (shelved: Defs.line_mode). By sight: another
## side's pipes only where t sees them now (they aren't drawn under the fog).
func _pipe_in_way(t: int, c: Vector2i, size: Vector2i, by_sight: bool) -> bool:
	if not line_net.blocks(c, size):
		return false
	if not by_sight:
		return true
	for y in size.y:
		for x in size.x:
			var s: PipeSeg = line_net.seg_at(c + Vector2i(x, y))
			if s != null and (allied(s.team, t) or is_visible_to(t, s.center())):
				return true
	return false


var _gear_relax := false             # the starting layout may skip the gear rule when no linked spot is found


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
	if net_forward(self, "place_building", [t, k, c, builders, queued]): return null
	if placement_problem(t, k, c) != "" or players[t]["gold"] < int(Defs.BUILDINGS[k]["cost"]):
		return null
	if tension(t) < float(Defs.tension_cost(Defs.BUILDINGS[k])):
		return null          # (gear mode: a building's Tension price, the Clock Aviary's)
	if not requirement_met(t, k):
		return null
	var old_wall: Building = null
	if k == "gate":
		old_wall = _own_wall_at(t, c)
		if old_wall:
			if old_wall.ghost:
				players[t]["gold"] += int(old_wall.d["cost"])      # (a planned piece never began: its price back)
				stats[t]["spent"] -= int(old_wall.d["cost"])
				stats[t]["built"] = maxi(0, int(stats[t]["built"]) - 1)
			_remove_quietly(old_wall)
	if k == "wall":
		var old_gate := _own_gate_at(t, c)
		if old_gate:
			_remove_quietly(old_gate)
	players[t]["gold"] -= int(Defs.BUILDINGS[k]["cost"])
	add_tension(t, -float(Defs.tension_cost(Defs.BUILDINGS[k])))
	stats[t]["spent"] += int(Defs.BUILDINGS[k]["cost"])
	stats[t]["built"] += 1
	var b := _add_building(k, t, c, false, true)     # a ghost until its building starts
	last_placed[t] = {"at": b.center(), "t": clock, "kind": k}
	if Defs.BUILDINGS[k]["faction"] == "clockwork":
		b.seeded = false
		# the Winder fetches its crate from a Clocktower first (none: he starts it by hand)
		b.crate = "tower" if crate_tower(t, b.center(), b) != null else ""
		b._update_sprite()
		if Defs.cw_roster:
			builders = CwUnits.assign_builders(self, builders, b)      # a Work Car's crew start it from the car
		builders = _one_builder(builders, b, queued)   # one winder starts it, then it builds itself
	if Defs.BUILDINGS[k]["faction"] == "brood":
		b.seeded = false
		b._update_sprite()
		builders = _one_builder(builders, b, queued)   # one grub becomes the building
	if old_wall:
		_wall_piece_to_gate(old_wall, b)
	for u in builders:
		if u is Unit and u.is_worker() and not u.dead:
			# a gate laid over a wall a worker is building: the gate first, then on with the rest of his wall
			var rest: Array = _wall_work(u, b) if old_wall and not queued else []
			u.give({"o": "build", "e": b}, queued)
			if not rest.is_empty():
				u.line_rest = rest
	return b


## A gate takes the place of a wall piece: every worker who had that piece in his work (going to it, next in his
## wall, Shift-queued) has the gate there instead, so the rest of the wall stays planned with its builders. (The piece
## used to vanish from under them: a Labourer on his way to it stopped, nobody was coming to the other planned pieces
## and the whole ghost wall went, the gate too, playtest 0.14.82.)
func _wall_piece_to_gate(old: Building, gate: Building) -> void:
	for u in units:
		if u.dead or u.team != gate.team or not u.is_worker():
			continue
		for i in u.line_rest.size():
			if u.line_rest[i] == old:
				u.line_rest[i] = gate
		for o in u.queue:
			if String(o["o"]) == "build" and o.get("e") == old:
				o["e"] = gate
			elif String(o["o"]) == "wall":
				var ps: Array = o["pieces"]
				for i in ps.size():
					if ps[i] == old:
						ps[i] = gate
		if u.order == "build" and u.order_target == old:
			var rest: Array = u.line_rest.duplicate()
			var q: Array = u.queue.duplicate()
			u.cmd_build(gate)
			u.line_rest = rest
			u.queue = q


## The unfinished wall pieces and gates a worker still has to build (where he's going, the rest of his wall, his
## queued walls), without `skip`: what he goes on with after a gate laid over his wall.
func _wall_work(u: Unit, skip: Building) -> Array:
	var out: Array = []
	var all: Array = []
	if u.order == "build" and u.order_target is Building:
		all.append(u.order_target)
	all.append_array(u.line_rest)
	for o in u.queue:
		if String(o["o"]) == "wall":
			all.append_array(o["pieces"])
		elif String(o["o"]) == "build":
			all.append(o.get("e"))
	for p in all:
		if p is Building and is_instance_valid(p) and p != skip and not p.dead and not p.built \
				and (p.kind == "wall" or p.kind == "gate") and not out.has(p):
			out.append(p)
	return out


## Winders and grubs build one site each: of the selected workers the one with the least to do
## (idle first, then the shortest queue, then the nearest) takes this site, so a shift-queue of
## several buildings is shared out between them instead of piling onto the first worker.
func _one_builder(builders: Array, site: Building, queued: bool) -> Array:
	var best: Unit = null
	var bs := INF
	for u in builders:
		if not (u is Unit) or u.dead or not u.is_worker():
			continue
		var load_n: float = float(u.queue.size()) + (1.0 if Unit.QUEUE_BUSY.has(u.order) else 0.0)
		if not queued:
			load_n = 0.0        # an immediate order: the nearest worker takes it
		var score: float = load_n * 100000.0 + u.position.distance_to(site.center())
		if score < bs:
			bs = score
			best = u
	return [] if best == null else [best]


func _redraw_line() -> void:
	line_net.redraw()


## Lay the Clockwork Line along `cells` (routed by LineNetwork.plan) with these Winders.
func lay_line(t: int, cells: Array, builders: Array, queued := false) -> void:
	if net_forward(self, "lay_line", [t, cells, builders, queued]): return
	line_net.lay(t, cells, builders, queued)


## Buy a train at the team's Clocktower ("ore" or "troop"). Returns "" or the reason it was refused.
func buy_train(t: int, kind: String) -> String:
	if net_forward(self, "buy_train", [t, kind]): return ""
	return line_net.rails.buy(t, kind)


## RIDE: these soldiers board a Troop Train (the nearest idle one of their team) at the Line cell nearest
## to the first of them and are set down at the Line cell nearest `to`. Returns "" or the reason it was refused.
func ride_order(units_in: Array, to: Vector2) -> String:
	if net_forward(self, "ride_order", [units_in, to]): return ""
	var men: Array = units_in.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and u.is_unit() and Defs.UNITS.has(u.kind) and not u.is_worker() and u.kind != "horse" and not u.is_air() and not Defs.CROWN_MACHINES.has(u.kind) and not u.d.get("needs_horse", false) and u.aboard == null and not u.is_mounted())
	if men.is_empty():
		return "Only soldiers can ride a train."
	var t: int = men[0].team
	var rails := line_net.rails
	var pick := rails.nearest_cell(t, men[0].position, 14)
	var drop := rails.nearest_cell(t, to, 8)
	if pick.x < 0:
		return "No Line near these soldiers."
	if drop.x < 0:
		return "Tap a spot beside the Line."
	var best: Train = null
	var bd := INF
	for tr in rails.trains:
		if tr.team != t or tr.tkind != "troop" or tr.dead or not (tr.state in ["idle", "returning"]):
			continue
		var dd: float = tr.global_position.distance_to(men[0].position)
		if dd < bd:
			bd = dd
			best = tr
	if best == null:
		return "No idle Troop Train (buy one at the Clocktower)."
	men = men.slice(0, best.seats())
	for u in men:
		u.give({"o": "move", "p": cell_center(pick) + Vector2(randf_range(-10, 10), randf_range(-8, 8))}, false)
	best.send_for(men, pick, drop)
	return ""


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


## A hauler could not deliver his keg: it lies at `p` with `shots` in it (PowderKeg; kegs never go back into the stores).
func drop_keg(t: int, p: Vector2, shots: float, hp := -1.0) -> PowderKeg:
	var k := PowderKeg.new()
	k.setup(self, t, resolve_terrain(p, p, 8.0), shots)
	if hp > 0.0:
		k.hp = minf(hp, k.max_hp)
	world.add_child(k)
	kegs.append(k)
	if not sees_all() and not allied(t, fog_team()):
		k.visible = false
	return k


## The nearest keg of side t on the ground (unclaimed, with powder) within r of p.
func free_keg(t: int, p: Vector2, r: float) -> PowderKeg:
	var best: PowderKeg = null
	var bd := r
	for k in kegs:
		if k.team == t and not k.dead and k.claimed == null and k.powder >= 1.0:
			var dd: float = k.position.distance_to(p)
			if dd < bd:
				bd = dd
				best = k
	return best


## The keg on the ground under a tap.
func keg_at(p: Vector2) -> PowderKeg:
	for k in kegs:
		if not k.dead and k.visible and k.rect().grow(6).has_point(p):
			return k
	return null


## The crate on the ground under a tap.
func crate_at(p: Vector2) -> Crate:
	for c in crates:
		if not c.dead and shown_to_commander(c) and c.rect().grow(6).has_point(p):
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
	if not tesla_made:
		return false
	var cw := Defs.cw_roster
	for u in units:
		if u.team != t or u.dead:
			continue                # (asked of every Clockwork unit a few times a second: the cheap tests first)
		if u.kind == "tesla_cart" and u.tesla_mode == "deployed":
			if in_ellipse(u.position, p, Defs.TESLA_FIELD * T * m):
				return true
		if cw and u.kind == "tesla_loco" and u.position.distance_to(p) <= float(Defs.CW["tesla"]["pass"]):
			return true             # (the Tesla Locomotive overcharges what it passes)
	return false


func in_field(t: int, p: Vector2) -> bool:
	if Defs.gear_mode and faction_of(t) == "clockwork":
		# gear mode: constructs stay wound on CONNECTED GEAR GROUND (inside a connected building's ring), Defs.GEAR
		if gear_net.in_field(t, p):
			return true
		if not tesla_made:
			return false
		for u in units:
			if u.team != t or u.dead:
				continue
			if u.kind == "tesla_cart" and u.tesla_mode == "deployed":
				if in_ellipse(u.position, p, Defs.TESLA_FIELD * T * field_mult(t)):
					return true
		return false
	var m := field_mult(t)
	for b in buildings:
		if b.team == t and b.built and not b.dead and b.d.has("field") and b.field_on():
			if in_ellipse(b.center(), p, float(b.d["field"]) * T * m):
				return true
	if not tesla_made:
		return false
	for u in units:
		if u.team != t or u.dead:
			continue
		if u.kind == "tesla_cart" and u.tesla_mode == "deployed":
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
	return line_net.damaged_near(u.team, u.position, r)


func needs_swamp(k: String) -> bool:
	return Defs.BUILDINGS[k]["faction"] == "brood" and not Defs.BUILDINGS[k].get("eggs", false)


## A unit that turned into something else: gone, but not a loss.
func consume_unit(u: Unit) -> void:
	u._leave_mine()
	if u._k_nb and BroodRoot.has_fp(u):
		BroodRoot.footprint_off(self, u)      # (a rooted new-Brood creature taken off the map: its ground is free again)
	units.erase(u)
	selection.erase(u)
	for g in groups:
		g.erase(u)
	u.dead = true
	u.queue_free()


## Brood Pen SACRIFICE: essence a creature gives when it's offered up (0: it can't be).
static func sacrifice_value(kind: String) -> int:
	var d: Dictionary = Defs.UNITS[kind]
	if d["faction"] != "brood" or d.get("worker", false) or d.get("new_brood", false):
		return 0
	return maxi(1, int(round(float(d["cost"]) / maxf(1.0, float(d.get("spawn", 1))) * Defs.SACRIFICE)))


## A Brood creature that reached a Pen on SACRIFICE: offered up for essence.
func sacrifice(u: Unit, pen: Entity) -> void:
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
		float_text(pen.center() + Vector2(0, -34), "+%d spoils" % ess, Color(0.8, 0.5, 1.0))
	if pen is Unit and (pen as Unit).kind == BroodNew.QUEEN:
		BroodNew.devour(pen, u)          # (the new Brood: the Mother devours it, a swipe)
	consume_unit(u)


func notify(msg: String, quiet := false) -> void:
	var now := Time.get_ticks_msec()
	if now - _notify_t > 3000 and hud:
		_notify_t = now
		hud.toast(msg, not quiet)


## A message for the player of team t: on this screen if it is ours; online, the host sends it to the guest who plays
## t (a guest's order refused, a guest's unit that can't do what it was told). Nobody else's: nothing.
func tell(t: int, msg: String, quiet := false) -> void:
	if t == human and net_cmd_team < 0:
		notify(msg, quiet)
	elif net != null and not puppet:
		net.tell(t, msg, quiet)


## Is the player whose order is being worked out allowed to have meant this entity (on their screen)? Normally its
## visibility on this screen; while a guest's order runs on the host, what the guest's side sees (its own and its
## allies' things always; others where its side sees now, a building once its side has spotted it: seen_mask).
func shown_to_commander(e: Node2D) -> bool:
	if net_cmd_team < 0:
		return e.visible
	var t := net_cmd_team
	var et := int(e.get("team")) if e.get("team") != null else -1
	if et >= 0 and allied(et, t):
		return not (e is Unit and (e as Unit).off_field)
	if e is Building:
		var mask := 0
		for o in n_players():
			if allied(o, t):
				mask |= 1 << o
		return not (e as Building).ghost and ((e as Building).seen_mask & mask) != 0
	return side_sees(t, e.global_position) and not (e is Unit and (e as Unit).off_field)


# ------------------------------------------------------------------ swamp

func on_swamp(t: int, p: Vector2) -> bool:
	return swamp[t][idx(cell_of(p))] == 1


func _update_swamp() -> void:
	swamp_dirty = false
	for t in n_players():
		var old: PackedByteArray = (swamp[t] as PackedByteArray).duplicate()
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
			# the new Brood: the rooted Brood Mother and Rootmaws (scripts/brood_new.gd)
			for src in BroodNew.swamp_sources(self, t):
				var nc: Vector2 = src[0]
				var nr: float = src[1]
				for y in range(int(nc.y - nr) - 1, int(nc.y + nr) + 2):
					for x in range(int(nc.x - nr) - 1, int(nc.x + nr) + 2):
						if x < 0 or y < 0 or x >= W or y >= H or water[y * W + x] == 1:
							continue
						var ndx: float = (x + 0.5 - nc.x)
						var ndy: float = (y + 0.5 - nc.y) * 1.15
						if ndx * ndx + ndy * ndy <= nr * nr:
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
		# Swamp that lost its building does not vanish at once: it retreats one ring of tiles every swamp
		# update (every half second), the outermost unsupported tiles first
		# (nothing to do where the grid came out as it was, as for every side without swamp:
		# the whole-map loop ran for every player every half second)
		for i in (W * H if old != g else 0):
			if old[i] == 1 and g[i] == 0:
				var x := i % W
				var y := i / W
				if x > 0 and x < W - 1 and y > 0 and y < H - 1 and old[i - 1] == 1 and old[i + 1] == 1 and old[i - W] == 1 and old[i + W] == 1:
					g[i] = 1
					swamp_dirty = true
		swamp[t] = g
	_swamp_any = _all_swamp()
	_update_conn()
	swamp_layer.queue_redraw()
	swamp_layer_b.queue_redraw()
	_swamp_minimap()


## One small picture of every Brood swamp, drawn on the minimap for everyone (another side's
## only where your side has looked: _known_ground).
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
		var known: PackedByteArray = _EMPTY if allied(t, fog_team()) else _known_ground()
		var hide := known.size() == W * H
		var i := g.find(1)              # (the swamp's cells only, found by the native find)
		while i >= 0:
			if not hide or known[i] == 1:
				swamp_img.set_pixel(i % W, i / W, col)
			i = g.find(1, i + 1)
	if swamp_tex == null:
		swamp_tex = ImageTexture.create_from_image(swamp_img)
	else:
		swamp_tex.update(swamp_img)


## The powered field of Clockwork buildings: the selected one (anyone's), and while you
## place a building, the one you're placing plus your existing fields.
func _draw_fields() -> void:
	_draw_pit_circles()
	var ring: Texture2D = tex("res://assets/world/field_ring.png")
	var draw_ring := func(c: Vector2, r: float, a: float) -> void:
		var half := Vector2(r, r * FIELD_Y)
		field_layer.draw_texture_rect(ring, Rect2(c - half, half * 2.0), false, Color(1, 1, 1, a))
	for e in selection:
		if not is_instance_valid(e) or e.dead:
			continue
		if e is Building and e.d.has("field") and e.built and not Defs.gear_mode:
			# a tower busy fighting flyers has its field switched off
			draw_ring.call(e.center(), float(e.d["field"]) * T * field_mult(e.team), 0.9 if e.field_on() else 0.18)
		elif e is Unit and e.kind == "tesla_cart" and e.tesla_mode == "deployed":
			draw_ring.call(e.position, Defs.TESLA_FIELD * T * field_mult(e.team), 0.9)
	if controls and controls.mode == "cast" and controls.cast_spell != "tongue" and controls.cast_spell != "jump":
		var info: Dictionary = spell_info(controls.cast_spell)
		var col: Color = {"storm": Color(0.55, 0.8, 1.0, 0.9), "fog": Color(0.75, 0.85, 0.8, 0.9)}.get(controls.cast_spell, Color(0.6, 1.0, 0.35, 0.9))
		var at: Vector2 = get_global_mouse_position() if Settings.pc() else camera.get_screen_center_position()
		field_layer.draw_set_transform(at, 0.0, Vector2(1.0, FIELD_Y))
		field_layer.draw_circle(Vector2.ZERO, float(info["radius"]), Color(col.r, col.g, col.b, 0.12))
		field_layer.draw_arc(Vector2.ZERO, float(info["radius"]), 0.0, TAU, 48, col, 2.0)
		field_layer.draw_set_transform(Vector2.ZERO)
	if controls and controls.mode == "place":
		var k: String = controls.place_kind
		if Defs.gear_mode and Defs.BUILDINGS[k]["faction"] == "clockwork":
			pass       # (its ring and whether it links: GearNet draws it over the other rings, scripts/gear.gd)
		elif faction_of(human) == "clockwork" or Defs.BUILDINGS[k].has("field"):
			for b in buildings:
				if b.team == human and b.built and not b.dead and b.d.has("field") and not selection.has(b):
					draw_ring.call(b.center(), float(b.d["field"]) * T * field_mult(human), 0.35)
		if Defs.BUILDINGS[k].has("field") and not Defs.gear_mode:
			var size: Vector2i = Defs.BUILDINGS[k]["size"]
			var c := Vector2(controls.ghost_cell) * T + Vector2(size) * T * 0.5
			draw_ring.call(c, float(Defs.BUILDINGS[k]["field"]) * T * field_mult(human), 0.8)


## PIT GROUND circles (Defs.PIT_CLAIM), flat on the ground under the buildings: while you place a
## Feeding Pit, the circle of every pit of yours and of every old ground spot you know of, plus the
## ghost's own circle (green when it's free, red where it overlaps one of your pits, whose circle turns
## red too); a selected pit shows its own. Fresh ground is a soft green, tiring toward a grey-brown;
## old ground is dashed and dimmer. Labels: _draw_pit_labels (on the overlay).
const PIT_FRESH := Color(0.62, 0.86, 0.42)
const PIT_SPENT := Color(0.52, 0.44, 0.36)

static func pit_colour(left: float) -> Color:
	return PIT_SPENT.lerp(PIT_FRESH, clampf(left, 0.0, 1.0))


func _pit_placing() -> bool:
	return controls != null and controls.mode == "place" and controls.place_kind == "feeding_pit" and controls.ghost_cell.x >= 0


## The old ground spots this player may be shown: its own, and others' where its side has looked.
func _known_pit_spots() -> Array:
	var known := _known_ground()
	var out: Array = []
	for sp in pit_spots:
		var c := cell_of(sp[0])
		if int(sp[2]) == human or known.size() != W * H or (in_map(c) and known[idx(c)] == 1):
			out.append(sp)
	return out


func _draw_pit_circles() -> void:
	var r := Defs.PIT_CLAIM * T
	var circle := func(c: Vector2, col: Color, fill_a: float, w: float, dashed: bool) -> void:
		field_layer.draw_circle(c, r, Color(col.r, col.g, col.b, fill_a))
		if dashed:
			var n := 28
			for i in n:
				var a0 := TAU * i / n
				field_layer.draw_arc(c, r, a0, a0 + TAU / n * 0.55, 4, Color(col, 0.55), w, true)
		else:
			field_layer.draw_arc(c, r, 0.0, TAU, 64, Color(col, 0.8), w, true)
	if _pit_placing():
		var gc := pit_mid(controls.ghost_cell)
		var hits := pit_overlaps(human, gc)
		for sp in _known_pit_spots():
			circle.call(sp[0], pit_colour(float(sp[1]) / float(Defs.PIT_GROUND)), 0.05, 1.5, true)
		for b in buildings:
			if b.kind == "feeding_pit" and b.team == human and not b.dead:
				var col := Color(1.0, 0.35, 0.3) if hits.has(b) else pit_colour(b.soil_left() if b.built else 1.0)
				circle.call(b.center(), col, 0.10 if hits.has(b) else 0.07, 2.0, false)
		var ok := hits.is_empty()
		circle.call(gc, Color(0.45, 1.0, 0.45) if ok else Color(1.0, 0.35, 0.3), 0.14, 2.5, false)
		return
	for e in selection:
		if e is Building and is_instance_valid(e) and not e.dead and e.kind == "feeding_pit" and (e.team == human or demo):
			circle.call(e.center(), pit_colour(e.soil_left() if e.built else 1.0), 0.07, 2.0, false)


## The labels of the pit circles (on the overlay, over the buildings): the ground left in each
## (% of PIT_GROUND), and under the ghost what a pit there would have.
func _draw_pit_labels() -> void:
	var font := ThemeDB.fallback_font
	var r := Defs.PIT_CLAIM * T
	# (on the circle's top edge, inside it, in the small dark box the economy labels use)
	var label := func(c: Vector2, txt: String, col: Color, sz: int) -> void:
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var p := c + Vector2(-w * 0.5, -r + sz + 8.0)
		overlay.draw_rect(Rect2(p + Vector2(-4, -sz), Vector2(w + 8, sz + 5)), Color(0, 0, 0, 0.55))
		overlay.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
	if _pit_placing():
		for sp in _known_pit_spots():
			var left := float(sp[1]) / float(Defs.PIT_GROUND)
			label.call(sp[0], Loc.t("Old ground: %d%%") % int(round(left * 100)) if float(sp[1]) > 0.0 else Loc.t("Old ground: spent"), Color(pit_colour(left), 0.85), 13)
		for b in buildings:
			if b.kind == "feeding_pit" and b.team == human and not b.dead and b.built:
				label.call(b.center(), "%d%%" % int(round(b.soil_left() * 100)), pit_colour(b.soil_left()), 13)
		var gc := pit_mid(controls.ghost_cell)
		var txt := ""
		var col := Color(0.55, 1.0, 0.55)
		if not pit_overlaps(human, gc).is_empty():
			txt = Loc.t("Too close: the grounds would overlap")
			col = Color(1.0, 0.5, 0.45)
		else:
			var gv := pit_ground_at(gc)
			if gv >= float(Defs.PIT_GROUND):
				txt = Loc.t("Fresh ground: %d biomass") % Defs.PIT_GROUND
			elif gv <= 0.0:
				txt = Loc.t("Old ground, spent: this pit would yield nothing")
				col = Color(0.85, 0.65, 0.45)
			else:
				txt = Loc.t("Old ground: %d biomass left") % int(gv)
				col = pit_colour(gv / float(Defs.PIT_GROUND))
		label.call(gc, txt, col, 15)
		return
	for e in selection:
		if e is Building and is_instance_valid(e) and not e.dead and e.kind == "feeding_pit" and e.built and (e.team == human or demo):
			label.call(e.center(), Loc.t("Ground: %d%%") % int(round(e.soil_left() * 100)), pit_colour(e.soil_left()), 14)


## A slow, cheap shimmer on the swamp: big soft waves of brightness and a little teal drift over
## it (one tiny shader on the whole layer; the tiles themselves are drawn once), so the swamp
## reads as alive and never as a flat dark patch next to green ground.
const SWAMP_SHADER := """
shader_type canvas_item;
uniform vec3 team_col = vec3(0.3, 0.8, 0.4);
varying vec2 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec4 c = COLOR;       // (already the texture times the modulate)
	float a = sin(wpos.x * 0.045 + TIME * 0.55) * sin(wpos.y * 0.055 - TIME * 0.42);
	float b = sin((wpos.x + wpos.y) * 0.03 - TIME * 0.3);
	float w = 0.6 * a + 0.4 * b;
	c.rgb *= 0.94 + 0.13 * w;
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	float k = 0.10 + 0.34 * max(w, 0.0);
	c.rgb = mix(c.rgb, team_col * (0.25 + 1.6 * lum), k);       // (the player's colour rides the waves)
	COLOR = c;
}
"""


func _swamp_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SWAMP_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _draw_swamp(team: int) -> void:
	var layer: Node2D = swamp_layer if team == 0 else swamp_layer_b
	(layer.material as ShaderMaterial).set_shader_parameter("team_col", Vector3(team_colour(team).r, team_colour(team).g, team_colour(team).b))
	var t: Texture2D = tex("res://assets/tiles/swamp.png")
	var g: PackedByteArray = swamp[team]
	# not on cliffs or ramps: the swamp hid the hillsides and slopes (the ground there
	# still counts as swamp; it just isn't painted over); another side's only where your
	# side has looked (_known_ground: it would give its base away under the grey fog)
	var known: PackedByteArray = _EMPTY if allied(team, fog_team()) else _known_ground()
	var hide := known.size() == W * H
	var sh := PackedByteArray()
	sh.resize(W * H)
	# (only the swamp's own cells are visited, found by the native find: a side without swamp,
	# or with a little, no longer costs two loops over the whole map; the same tiles, in the
	# same order)
	var cells := PackedInt32Array()
	var j := g.find(1)
	while j >= 0:
		if cliff[j] == 0 and ramp[j] == 0 and (not hide or known[j] == 1):
			sh[j] = 1
			cells.append(j)
		j = g.find(1, j + 1)
	for i in cells:
		var x := i % W
		var y := i / W
		var edge := (x > 0 and sh[i - 1] == 0) or (x < W - 1 and sh[i + 1] == 0) \
			or (y > 0 and sh[i - W] == 0) or (y < H - 1 and sh[i + W] == 0)
		layer.draw_texture(t, Vector2(x * T, y * T), Color(1, 1, 1, 0.55 if edge else 1.0))


var _astar_dirty := false


# ------------------------------------------------------------------ pathfinding

func queue_path(u: Unit) -> void:
	if not _path_queue.has(u):
		_path_queue.append(u)


## `margin`: how far the straight stretches of the path keep from anything solid (px; about the
## unit's own half-width: a big Brute or a gun keeps further from corners than a man).
func find_path(from: Vector2, to: Vector2, siege := false, margin := 7.0) -> PackedVector2Array:
	# (a Farm's crop rows are walkable: a unit on them starts, or ends, right there)
	var a := cell_of(from) if open_cell(cell_of(from)) else nearest_free(cell_of(from), 6)
	var b := cell_of(to) if open_cell(cell_of(to)) else nearest_free_level(cell_of(to), 8)
	var pt := Time.get_ticks_usec()
	# (beside a ramp's rail: the pathfinder starts or ends at the nearest cell open to it, and
	# the last step is walked from there; docs/ramp_funnel.md)
	var pa := path_cell(a)
	var pb := path_cell(b)
	var pts := astar.get_point_path(pa, pb, true)
	# (allow_partial_path: when b can't be reached the path ends at the reachable cell nearest to it)
	var whole := not pts.is_empty() and cell_of(pts[pts.size() - 1]) == pb
	if not whole and siege:
		# walled out: walk up to the wall (the unit then breaks it down)
		var sp := astar_siege.get_point_path(path_cell(a, true), path_cell(b, true), false)
		if not sp.is_empty():
			pts = sp
			whole = true
	if whole and pb != b:
		pts.append(cell_center(b))
	Prof.add("game/pathfinder", pt)
	if pts.is_empty():
		return PackedVector2Array([to])
	# Use the exact destination when it's on open ground, and only when the path gets there: the end
	# of a path that can't (the goal up a cliff with no way round, on an island) is the nearest spot
	# it can walk to. (It used to be swapped for the goal too: the unit then walked on from there in a
	# straight line, into the cliff, and pushed at it for good.)
	if whole and open_cell(cell_of(to)) and cell_of(to) == b:
		pts[pts.size() - 1] = to
	pt = Time.get_ticks_usec()
	var sm := _smooth(from, pts, margin)
	Prof.add("game/path smoothing", pt)
	return sm


## Drop waypoints that can be skipped with a clear straight line. (It looks at most
## SMOOTH_LOOK cells ahead: trying every later point of a long, winding path cost up to a
## second and a half for one path; a straight run longer than that just keeps a waypoint.)
const SMOOTH_LOOK := 40


func _smooth(from: Vector2, pts: PackedVector2Array, margin := 7.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cur := from
	var i := 0
	while i < pts.size():
		var j := mini(pts.size() - 1, i + SMOOTH_LOOK)
		while j > i and not line_clear(cur, pts[j], margin):
			j -= 1
		out.append(pts[j])
		cur = pts[j]
		i = j + 1
	return out


## (The same test as open_cell(cell_of(p +- 7, 7)) at every sample, written out: the
## path smoothing calls it thousands of times for a long path. Every 4th sample is looked at
## first, then the others: anything solid covers several samples in a row, so a blocked line
## is usually found out in a quarter of the work, and a clear one still has every sample
## looked at. The same samples, so the same answer.)
func line_clear(a: Vector2, b: Vector2, margin := 7.0) -> bool:
	var dist := a.distance_to(b)
	var steps := int(dist / 10.0) + 1
	var w1 := W - 1
	var h1 := H - 1
	var s := 0
	var first := true
	while true:
		if s > steps:
			if not first:
				break
			first = false
			s = 1
		if not first and s % 4 == 0:
			s += 1
			continue
		var p := a.lerp(b, float(s) / float(steps))
		var x0 := clampi(int((p.x - margin) / T), 0, w1)
		var x1 := clampi(int((p.x + margin) / T), 0, w1)
		var y0 := clampi(int((p.y - margin) / T), 0, h1) * W
		var y1 := clampi(int((p.y + margin) / T), 0, h1) * W
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
		s += 4 if first else 1
	if not _rail_box.is_empty() and rail_blocks_line(a, b, margin + RAIL_LINE_PAD):
		return false              # (past a ramp's rail: docs/ramp_funnel.md)
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
	var home := region_of(cell_of(from))
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
				if home >= 0 and region_of(c) != home:
					dd += 100000.0      # (a pocket shut in by a palisade or other buildings, the far side of a wall: he can't walk there, so a side he can reach first)
				if dd < bd:
					bd = dd
					best = p
	return best if best != Vector2.INF else r.get_center()


## The height level (the map's height array) of the ground at a point.
func level_of(p: Vector2) -> int:
	return int(height[idx(cell_of(p))])


## A spot for something let go beside `from` (a horse unhitched from a gun): `want` if it is free,
## on the SAME height level as `from` and reachable in a straight line (not across a cliff
## edge down to the low ground), else the nearest of a few other spots round `from` that are,
## else `from` itself.
func level_spot(from: Vector2, want: Vector2, radius: float, team := -1) -> Vector2:
	var lv := level_of(from)
	var d := want - from
	var cands: Array = [want, from + d * 0.6, from - d, from - d * 0.6, from + d.orthogonal() * 0.8,
			from - d.orthogonal() * 0.8, from + d * 0.3, from - d * 0.3]
	var lo := Vector2(radius, radius)
	var hi := Vector2(W * T, H * T) - lo
	for c: Vector2 in cands:
		var p := c.clamp(lo, hi)
		if _clear_at(p, radius, team) and level_of(p) == lv and line_clear(from, p):
			return p
	return resolve_terrain(from, from, radius, team)


const CORNER_SLIP := [0.6, -0.6, 1.1, -1.1]       # (radians: the angles tried to slip round a corner)


func resolve_terrain(pos: Vector2, before: Vector2, radius: float, team := -1) -> Vector2:
	if rails.is_empty():
		return _resolve_terrain(pos, before, radius, team)
	# the ramp rails (docs/ramp_funnel.md): kept to before the cells are looked at, and again
	# after (a slide along x or y, or round a corner, mustn't take it over one)
	before = rail_fix(before, before, radius)
	pos = rail_fix(pos, before, radius)
	return rail_fix(_resolve_terrain(pos, before, radius, team), before, radius)


func _resolve_terrain(pos: Vector2, before: Vector2, radius: float, team := -1) -> Vector2:
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
	# a corner (a step of a cliff, a building's corner) blocks the move and both slides along x and y:
	# it slips round it at an angle instead of stopping dead there
	var mv := pos - before
	if mv.length_squared() > 0.01:
		for ang: float in CORNER_SLIP:
			var q := before + mv.rotated(ang) * 0.8
			if _clear_at(q, radius, team):
				return q
	return before


## (every moving unit asks this a few times a tick: the cells are worked out here, without
## calling cell_of and passable for each of the five points)
func _clear_at(p: Vector2, radius: float, team := -1) -> bool:
	var r := radius * 0.6
	var ry := r * 0.6
	var cx := clampi(int(p.x / T), 0, W - 1)
	var cy := clampi(int(p.y / T), 0, H - 1)
	var row := cy * W
	var v := solid[row + cx]
	if v != 0 and v != 5 and not _gate_lets(row + cx, v, team):
		return false
	var c := clampi(int((p.x + r) / T), 0, W - 1)
	v = solid[row + c]
	if v != 0 and v != 5 and not _gate_lets(row + c, v, team):
		return false
	c = clampi(int((p.x - r) / T), 0, W - 1)
	v = solid[row + c]
	if v != 0 and v != 5 and not _gate_lets(row + c, v, team):
		return false
	c = clampi(int((p.y + ry) / T), 0, H - 1) * W + cx
	v = solid[c]
	if v != 0 and v != 5 and not _gate_lets(c, v, team):
		return false
	c = clampi(int((p.y - ry) / T), 0, H - 1) * W + cx
	v = solid[c]
	if v != 0 and v != 5 and not _gate_lets(c, v, team):
		return false
	return true


## A solid cell (value v) a unit of team t may still walk through: its own side's gate.
func _gate_lets(i: int, v: int, t: int) -> bool:
	return v == 3 and t >= 0 and allied(int(gate_team.get(i, -1)), t)


# ------------------------------------------------------------------ spatial queries

## The units by HASH-px cell, rebuilt every tick, packed: every unit on the map in one list sorted by cell
## (row by row) and, inside a cell, in the order of `units`; cell i holds _gunits[_gstart[i] .. _gend[i] - 1]
## (_gstart -1: nobody). Beside each its position, team and radius as they were at the rebuild (_gpos,
## _gteam, _grad: packed, so a search skips the men too far away without touching them, which is most of
## them in a crowd). The few off the map (a unit past the edge) are in a dictionary by cell (_hash).
## Units move during the tick, after the rebuild, by a step at most (GRID_SLACK allows it; the most any
## moved is checked at each rebuild: grid_drift): a search that skips by the packed positions finds the
## same units, in the same order, as one that looked at every unit of the cells.
var _gunits: Array = []
var _gpos := PackedVector2Array()
var _gteam := PackedInt32Array()
var _grad := PackedFloat32Array()
var _gstart := PackedInt32Array()
var _gend := PackedInt32Array()
var _gused := PackedInt32Array()          # (the cells filled at the last rebuild: cleared at the next)
var _gkeys := PackedInt64Array()
var _tpos := PackedVector2Array()         # (the rebuild's scratch: position, team and radius by place in `units`)
var _tteam := PackedInt32Array()
var _trad := PackedFloat32Array()
var grid_jumpers: Array = []              # (the units that jumped this tick: Unit._physics_process)
var _grid_w := 0
var _grid_h := 0
var _tsuper := PackedInt32Array()        # how many of each side (slot team + 1) stand in each block of SUPER x SUPER cells
var _super_w := 0
var _super_n := 0
var _super_slots := 0
const SUPER := 8
## How far a unit may have moved since the units' grid was rebuilt at the start of the tick (a tick's
## walk at the fastest, a knock-back): the searches allow this much. grid_drift_max is the most any unit
## on the field moved between two rebuilds (Unit._grid_p); grid_drift_over counts the times it was more.
const GRID_SLACK := 7.0
## GRID_SLACK, or more once a unit has moved farther than that since the rebuild (a Grub snapping onto the
## site it turns into, a man getting off his horse: Unit._physics_process): the searches allow that much
## till the next rebuild. (An online guest's and a replay's pictures: no limit, they look at everyone.)
var grid_slack := GRID_SLACK
var grid_drift_max := 0.0
var grid_drift_over := 0


func _rebuild_hash() -> void:
	_hash.clear()
	grid_slack = GRID_SLACK if not puppet else INF
	var gw := int(W * T) / HASH + 2
	var gh := int(H * T) / HASH + 2
	if gw != _grid_w or gh != _grid_h or _gstart.size() != gw * gh:
		_grid_w = gw
		_grid_h = gh
		_gstart = PackedInt32Array()
		_gstart.resize(gw * gh)
		_gstart.fill(-1)
		_gend = PackedInt32Array()
		_gend.resize(gw * gh)
		_gused = PackedInt32Array()
	for i in _gused:
		_gstart[i] = -1
	var nt := sides.size() + 1
	var sw := gw / SUPER + 1
	var sh := gh / SUPER + 1
	if _tsuper.size() != nt * sw * sh:
		_tsuper = PackedInt32Array()
		_tsuper.resize(nt * sw * sh)
	_tsuper.fill(0)
	_super_w = sw
	_super_n = sw * sh
	_super_slots = nt
	var n := units.size()
	_gkeys.resize(n)
	_tpos.resize(n)
	_tteam.resize(n)
	_trad.resize(n)
	var k := 0
	var hi := 0
	var slack2 := GRID_SLACK * GRID_SLACK
	var d2max := grid_drift_max * grid_drift_max
	for u in units:
		var p: Vector2 = u.position
		var gp: Vector2 = u._grid_p
		if gp != p:
			if gp.x != INF and not u.dead and not u.off_field:
				var d2 := p.distance_squared_to(gp)
				if d2 > d2max:
					d2max = d2
				if d2 > slack2 and not u._jumped:
					grid_drift_over += 1      # (moved that far without its own tick noticing: Unit._physics_process)
			u._grid_p = p
		u._hash_i = hi
		var tm: int = u.team
		_tpos[hi] = p
		_tteam[hi] = tm
		_trad[hi] = u.radius
		var kx := int(p.x) / HASH
		var ky := int(p.y) / HASH
		if kx >= 0 and ky >= 0 and kx < gw and ky < gh:
			_gkeys[k] = (ky * gw + kx) * 1048576 + hi
			k += 1
			_tsuper[clampi(tm + 1, 0, nt - 1) * _super_n + (ky / SUPER) * sw + kx / SUPER] += 1
		else:
			var c := Vector2i(kx, ky)
			var lst = _hash.get(c)
			if lst == null:
				_hash[c] = [u]
			else:
				lst.append(u)
		hi += 1
	grid_drift_max = sqrt(d2max)
	for u in grid_jumpers:
		if is_instance_valid(u):
			u._jumped = false
	grid_jumpers.clear()
	_gkeys.resize(k)
	_gkeys.sort()
	_gunits.resize(k)
	_gpos.resize(k)
	_gteam.resize(k)
	_grad.resize(k)
	_gused = PackedInt32Array()
	var last := -1
	for j in k:
		var key: int = _gkeys[j]
		var gi := key >> 20
		var ti := key & 1048575
		_gunits[j] = units[ti]
		_gpos[j] = _tpos[ti]
		_gteam[j] = _tteam[ti]
		_grad[j] = _trad[ti]
		if gi != last:
			if last >= 0:
				_gend[last] = j
			_gstart[gi] = j
			_gused.append(gi)
			last = gi
	if last >= 0:
		_gend[last] = k


## Another unit (a tongue's pull, a charge's shove, a Balloon letting men off...) moved `u` during the tick:
## if that took it farther from its grid place than the searches allow, they allow that much more.
func note_move(u: Unit) -> void:
	if u._grid_p.x == INF:
		return
	var d2 := u.position.distance_squared_to(u._grid_p)
	if d2 > grid_slack * grid_slack:
		grid_slack = sqrt(d2) + 1.0
	if d2 > GRID_SLACK * GRID_SLACK and not u._jumped:
		u._jumped = true
		grid_jumpers.append(u)


## The units in grid cell (x, y) at the last rebuild (in order), or null.
func _hash_cell(x: int, y: int):
	if x >= 0 and y >= 0 and x < _grid_w and y < _grid_h:
		var s := _gstart[y * _grid_w + x]
		return null if s < 0 else _gunits.slice(s, _gend[y * _grid_w + x])
	return _hash.get(Vector2i(x, y))


func units_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var c0 := Vector2i(int(p.x - r) / HASH, int(p.y - r) / HASH)
	var c1 := Vector2i(int(p.x + r) / HASH, int(p.y + r) / HASH)
	var gw := _grid_w
	var lim := (r + grid_slack) * (r + grid_slack)
	if _hash.is_empty():
		# (nobody off the grid: the cells past its edges are empty, so only the ones on it are looked at)
		for y in range(maxi(c0.y, 0), mini(c1.y, _grid_h - 1) + 1):
			var row := y * gw
			for x in range(maxi(c0.x, 0), mini(c1.x, gw - 1) + 1):
				var s := _gstart[row + x]
				if s < 0:
					continue
				for j in range(s, _gend[row + x]):
					if _gpos[j].distance_squared_to(p) > lim:
						continue          # (too far even if it walked a step this way since the rebuild)
					var u = _gunits[j]
					if is_instance_valid(u) and u.position.distance_to(p) <= r:
						out.append(u)
		return out
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var lst = _hash_cell(x, y)
			if lst == null:
				continue
			for u in lst:
				if is_instance_valid(u) and u.position.distance_to(p) <= r:
					out.append(u)
	return out


## (as units_near(u.position, u.radius + 18), in the same order, without building the list)
func separation(u: Unit) -> Vector2:
	var push := Vector2.ZERO
	var p := u.position
	var rr := u.radius + 18.0
	var air := u.is_air()
	var c0 := Vector2i(int(p.x - rr) / HASH, int(p.y - rr) / HASH)
	var c1 := Vector2i(int(p.x + rr) / HASH, int(p.y + rr) / HASH)
	# (one pass, in the grid's order, without a list of the neighbours: every unit asks this
	# every second or third tick. What it asks of itself is worked out once, before the loop.)
	var u_rail := Defs.cw_roster and Defs.CW_RAIL.has(u.kind)
	var mu := (12.0 if u.kind == "cannon" or u.kind == "mortar" or u_rail else 1.0) * u.nb_mass
	var u_still := u.velocity.length() < 15.0
	var u_mill: bool = u._mill_in
	var ur: float = u.radius
	var gw := _grid_w
	if not _hash.is_empty():
		# (anyone off the grid: every cell is looked up the slow way)
		for y in range(c0.y, c1.y + 1):
			for x in range(c0.x, c1.x + 1):
				var lst = _hash_cell(x, y)
				if lst == null:
					continue
				for o in lst:
					push = _sep_push(u, o, p, rr, air, u_rail, mu, u_still, u_mill, push)
		return push
	# (a man pushes only from closer than (both radii) * 0.85, at most rr: the packed positions tell who
	# can't be that close, even after a step since the rebuild, without looking at him)
	var slack := grid_slack
	var lim := rr + slack
	var lim2 := lim * lim
	for y in range(maxi(c0.y, 0), mini(c1.y, _grid_h - 1) + 1):
		var row := y * gw
		for x in range(maxi(c0.x, 0), mini(c1.x, gw - 1) + 1):
			var s := _gstart[row + x]
			if s < 0:
				continue
			for j in range(s, _gend[row + x]):
				var d2: float = _gpos[j].distance_squared_to(p)
				if d2 > lim2:
					continue
				var md: float = (ur + _grad[j]) * 0.85 + slack
				if d2 > md * md:
					continue
				# (_sep_push, written out: this is the hottest loop of a big fight)
				var o = _gunits[j]
				if o == u or not is_instance_valid(o):
					continue
				var dvec: Vector2 = p - o.position
				var dist := dvec.length()
				var min_d: float = (ur + o.radius) * 0.85
				if dist >= min_d or dist > rr:
					continue
				if o.dead or o.off_field or (o._air_k and o.net_t <= 0.0) != air:      # (o.is_air())
					continue
				if o._k_still:
					continue          # (a new-Brood egg or food pile lies on the ground: it shoves nobody)
				if o._k_shell and o.team == u.team and o.tesla_mode != "packed":
					continue          # (a rooted Mound Turtle: its own side climbs over the shell, BroodNew.push_out)
				if o == u.steed or u == o.steed:
					continue
				if (u.crew_of != null and (o == u.crew_of or o.crew_of == u.crew_of)) or (o.crew_of != null and o.crew_of == u):
					continue
				if u_rail and o.team == u.team and Defs.CW_RAIL.has(o.kind):
					continue
				if u_mill and o._mill_in and o.home_mine == u.home_mine:
					continue
				if dist < 0.01:
					dvec = Vector2.from_angle(randf() * TAU)
					dist = 0.01
				var strength := (min_d - dist) / min_d
				var k := 140.0
				if o.team == u.team and o.velocity.length() > 15.0 and u_still:
					k = 260.0
				var mo: float = (12.0 if o.kind == "cannon" or o.kind == "mortar" or (Defs.cw_roster and Defs.CW_RAIL.has(o.kind)) else 1.0) * o.nb_mass
				push += dvec / dist * strength * k * (2.0 * mo / (mu + mo))
	return push


## One neighbour's shove (separation): push plus what `o` adds to it.
func _sep_push(u: Unit, o, p: Vector2, rr: float, air: bool, u_rail: bool, mu: float, u_still: bool, u_mill: bool, push: Vector2) -> Vector2:
	if o == u or not is_instance_valid(o) or o.position.distance_to(p) > rr:
		return push
	if o.dead or o.off_field or o.is_air() != air:
		return push
	if o._k_still:
		return push           # (a new-Brood egg or food pile lies on the ground: it shoves nobody)
	if o._k_shell and o.team == u.team and o.tesla_mode != "packed":
		return push           # (a rooted Mound Turtle: its own side climbs over the shell, BroodNew.push_out)
	if o == u.steed or u == o.steed:
		return push           # (a man beside his own horse: he got off there, close by it)
	if (u.crew_of != null and (o == u.crew_of or o.crew_of == u.crew_of)) or (o.crew_of != null and o.crew_of == u):
		return push           # (a Spring Ballista and its crew: they stand pressed to it, scripts/ballista.gd)
	if u_rail and o.team == u.team and Defs.CW_RAIL.has(o.kind):
		return push           # (rail vehicles of one side pass through each other: the sidings decide who waits)
	if u_mill and o._mill_in and o.home_mine == u.home_mine:
		return push           # (a Powder Mill's crew share its small yard: they pass close by each other, never shove, Unit._mill_work)
	var dvec: Vector2 = p - o.position
	var dist := dvec.length()
	var min_d: float = (u.radius + o.radius) * 0.85
	if dist < min_d:
		if dist < 0.01:
			dvec = Vector2.from_angle(randf() * TAU)
			dist = 0.01
		var strength := (min_d - dist) / min_d
		var k := 140.0
		# Idle units step aside for friends on the move.
		if o.team == u.team and o.velocity.length() > 15.0 and u_still:
			k = 260.0
		# MASS: a gun is not shoved by the men walking up behind it (they go round it, and
		# anything light that bumps it gives way); equal masses push each other as before
		var mo: float = (12.0 if o.kind == "cannon" or o.kind == "mortar" or (Defs.cw_roster and Defs.CW_RAIL.has(o.kind)) else 1.0) * o.nb_mass
		push += dvec / dist * strength * k * (2.0 * mo / (mu + mo))
	return push


## hostile(o, t) for every team o (1 = enemy), as bytes indexed by team; t's own row.
func _foe_table(t: int) -> PackedByteArray:
	var n := sides.size()
	var out := PackedByteArray()
	out.resize(n)
	for o in n:
		out[o] = 1 if hostile(o, t) else 0
	return out


func find_target(u: Unit, r: float) -> Entity:
	if u._d_noatk:
		return null
	# HOLD FIRE (a gun other than the cavalry's pistol): nothing to shoot at on its own; a
	# Musketeer still takes on a man right on top of him with the bayonet
	var held := u.hold_fire and not u.has_pistol() and u.has_gun()
	if held:
		if not u.foot_musket():
			return null
		r = minf(r, float(Defs.BAYONET["close"]) + u.radius + 24.0)
	var best: Entity = null
	var bd := INF
	# guns with a minimum range (set up) look past what's too close; area guns (round shot,
	# mortar shells) pass over targets with their own men in the way, for another one
	var min_r := 0.0
	if u.deploys() and u.tesla_mode == "deployed" and u.mode != "canister":
		min_r = float(u.d.get("min_range", 0.0))
	var careful := (u.kind == "cannon" and u.mode != "canister") or u.kind == "mortar"
	var picks: Array = []
	# (who is an enemy, by team, worked out once: hostile() was asked of every unit and building)
	var foe := _foe_table(u.team)
	if not careful and _hash.is_empty() and _super_slots > 0:
		# (the same pick, found faster: only the enemies' cells, nearest ring first: _near_foe)
		var nf := _near_foe(u, r, foe, held, min_r)
		best = nf[0]
		bd = nf[1]
	else:
		for o in units_near(u.position, r):
			if o.team < 0 or foe[o.team] == 0 or o.dead or not u.can_hit(o) or (held and o.is_air()):
				continue
			if not o.is_air() and on_high(o.position) and not on_high(u.position) and not is_visible_to(u.team, o.position):
				continue
			# beyond its own sight a unit (the cannon) can only shoot what its side can see
			if o.position.distance_to(u.position) > u.sight * T + 8.0 and not side_sees(u.team, o.position):
				continue
			var dd: float = o.position.distance_to(u.position)
			if min_r > 0.0 and o.edge_distance(u.position) - u.radius < min_r:
				continue
			if o.kind == "horse":
				dd += 150.0  # a horse only when there's nothing else (better stolen than shot)
			elif not fights_back(o):
				dd += 60.0   # prefer fighters (workers, Missionaries, wagons after them)
			if careful:
				picks.append([dd, o])
			elif dd < bd:
				bd = dd
				best = o
	if held:
		return best              # (no crates or buildings: they'd be shot)
	# a Clockwork crate on the ground: smash it (counted like a worker)
	if not careful and not u._d_medic:
		for c in crates:
			if c.dead or not hostile(c.team, u.team) or not u.can_hit(c):
				continue
			var dc: float = c.position.distance_to(u.position)
			if dc <= r and dc + 60.0 < bd and side_sees(u.team, c.position):
				bd = dc + 60.0
				best = c
		# an enemy powder keg on the ground: a bomb in their midst, shot when nothing that fights back is nearer
		for k in kegs:
			if k.dead or not hostile(k.team, u.team) or not u.can_hit(k):
				continue
			var dk: float = k.position.distance_to(u.position)
			if dk <= r and dk + 90.0 < bd and side_sees(u.team, k.position):
				bd = dk + 90.0
				best = k
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
	if u._d_medic or u._d_aironly:
		return null
	for b in buildings:
		if b.team < 0 or foe[b.team] == 0 or b.dead or b.ghost:
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
	if best == null:
		best = line_net.pipe_target(u, r)       # the Clockwork Line: the lowest priority
	if best == null and faction_of(u.team) == "brood":
		# nothing else in reach: a loose horse (nobody's) is cheap essence
		for o in (_units_near_nobody(u.position, r) if _hash.is_empty() and _super_slots > 0 else units_near(u.position, r)):
			if loose_horse(o) and not o.off_field and u.can_hit(o) and side_sees(u.team, o.position):
				var dh: float = o.position.distance_to(u.position)
				if dh < bd:
					bd = dh
					best = o
	return best


## find_target's search of the units, as its plain loop over units_near would find it (the same unit: the
## nearest by its rule, and of the equally near the first in the grid's order), looking only at the
## enemies (_gteam), ring by ring out from the unit's cell, and stopping once a ring can't hold anyone
## nearer than the best so far. [best, its distance by the rule]
func _near_foe(u: Unit, r: float, foe: PackedByteArray, held: bool, min_r: float) -> Array:
	var p := u.position
	var gw := _grid_w
	var x0 := maxi(int(p.x - r) / HASH, 0)
	var y0 := maxi(int(p.y - r) / HASH, 0)
	var x1 := mini(int(p.x + r) / HASH, gw - 1)
	var y1 := mini(int(p.y + r) / HASH, _grid_h - 1)
	var px := int(p.x) / HASH
	var py := int(p.y) / HASH
	var best: Entity = null
	var bd := INF
	var bkey := 0
	var any := false
	for t in foe.size():
		if foe[t] == 1 and _slot_in(t + 1, x0, y0, x1, y1):
			any = true
			break
	if not any:
		return [best, bd]
	var u_high := on_high(p)
	var sight_r := u.sight * T + 8.0
	var kmax := maxi(maxi(px - x0, x1 - px), maxi(py - y0, y1 - py))
	var nf := foe.size()
	for k in kmax + 1:
		# (anyone in ring k was at least (k - 1) cells away at the rebuild, and has moved less than
		# GRID_SLACK since)
		if k >= 2 and float((k - 1) * HASH) - grid_slack > bd:
			break
		var ring := PackedInt32Array()
		for y in range(maxi(py - k, y0), mini(py + k, y1) + 1):
			if y == py - k or y == py + k:
				for x in range(maxi(px - k, x0), mini(px + k, x1) + 1):
					ring.append(y * gw + x)
			else:
				if px - k >= x0:
					ring.append(y * gw + px - k)
				if px + k <= x1 and k > 0:
					ring.append(y * gw + px + k)
		for gi in ring:
			var s := _gstart[gi]
			if s < 0:
				continue
			# (nobody there can have come nearer than the best so far: its rebuild place plus a step)
			var lim := minf(r, bd) + grid_slack
			var lim2 := lim * lim
			# (and a cell wholly farther than that is passed over)
			var cx := float((gi % gw) * HASH)
			var cy := float((gi / gw) * HASH)
			var ex := maxf(maxf(cx - p.x, p.x - cx - HASH), 0.0)
			var ey := maxf(maxf(cy - p.y, p.y - cy - HASH), 0.0)
			if ex * ex + ey * ey > lim2:
				continue
			for j in range(s, _gend[gi]):
				var tm: int = _gteam[j]
				if tm < 0 or tm >= nf or foe[tm] == 0:
					continue
				if _gpos[j].distance_squared_to(p) > lim2:
					continue
				var o = _gunits[j]
				if not is_instance_valid(o):
					continue
				var dd: float = o.position.distance_to(p)
				# (the rule only adds to the distance: one farther than the best so far can't win)
				if dd > r or dd > bd:
					continue
				if o.dead or not u.can_hit(o) or (held and o.is_air()):
					continue
				if not o.is_air() and not u_high and on_high(o.position) and not is_visible_to(u.team, o.position):
					continue
				if dd > sight_r and not side_sees(u.team, o.position):
					continue
				if min_r > 0.0 and o.edge_distance(p) - u.radius < min_r:
					continue
				if o.kind == "horse":
					dd += 150.0
				elif not fights_back(o):
					dd += 60.0
				var key: int = gi * 1048576 + int(o._hash_i)
				if dd < bd or (dd == bd and key < bkey):
					bd = dd
					best = o
					bkey = key
					lim = minf(r, bd) + grid_slack
					lim2 = lim * lim
	return [best, bd]


## Does anyone of slot `slot` (team + 1) stand in the cells x0..x1, y0..y1 (or near them: by blocks)?
func _slot_in(slot: int, x0: int, y0: int, x1: int, y1: int) -> bool:
	if slot >= _super_slots:
		return false
	var base := slot * _super_n
	for sy in range(y0 / SUPER, y1 / SUPER + 1):
		for sx in range(x0 / SUPER, x1 / SUPER + 1):
			if _tsuper[base + sy * _super_w + sx] > 0:
				return true
	return false


## The units of nobody's (team < 0: loose horses) of units_near(p, r), in the same order. (Only with nobody off the grid.)
func _units_near_nobody(p: Vector2, r: float) -> Array:
	var out: Array = []
	var gw := _grid_w
	var x0 := maxi(int(p.x - r) / HASH, 0)
	var y0 := maxi(int(p.y - r) / HASH, 0)
	var x1 := mini(int(p.x + r) / HASH, gw - 1)
	var y1 := mini(int(p.y + r) / HASH, _grid_h - 1)
	if not _slot_in(0, x0, y0, x1, y1):
		return out
	var lim := (r + grid_slack) * (r + grid_slack)
	for y in range(y0, y1 + 1):
		var row := y * gw
		for x in range(x0, x1 + 1):
			var s := _gstart[row + x]
			if s < 0:
				continue
			for j in range(s, _gend[row + x]):
				if _gteam[j] >= 0 or _gpos[j].distance_squared_to(p) > lim:
					continue
				var o = _gunits[j]
				if is_instance_valid(o) and o.position.distance_to(p) <= r:
					out.append(o)
	return out


## Clockwork: blue energy while a Capacitor Works stands.
func blue_energy(t: int) -> bool:
	for b in buildings:
		if b.team == t and b.kind == "capacitor_works" and b.built and not b.dead and line_net.speed_mult(b) > 0.0:
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
	for b in _hall_kind_of(t):      # (every Farm, Mill and Press asks this every tick)
		if b.built and not b.dead:
			var dd: float = b.edge_distance(p)
			if dd < bd:
				bd = dd
				best = b
	return best


## Team t's buildings of its faction's hall kind (built or not, standing or not), in the order of
## `buildings`. A building's team and kind never change, so the lists hold until a building
## is added or taken out: the list's length and last building are the check (an addition is
## always at the end, and a removal shortens it).
var _hall_lists := {}
var _hall_lists_key: Array = []


func _hall_kind_of(t: int) -> Array:
	var n := buildings.size()
	var last = buildings[n - 1] if n > 0 else null      # (untyped: it may have been freed)
	if _hall_lists_key.size() != 2 or int(_hall_lists_key[0]) != n or _hall_lists_key[1] != last:
		_hall_lists_key = [n, last]
		_hall_lists.clear()
	var lst = _hall_lists.get(t)
	if lst == null:
		lst = []
		if t >= 0 and t < factions.size():
			var hk := faction_hall(t)
			for b in buildings:
				if b.team == t and b.kind == hk:
					lst.append(b)
		_hall_lists[t] = lst
	return lst


## (`_any`: kept for its callers; there's nothing on the map but units and buildings to pick.)
func entity_at(p: Vector2, _any := true) -> Entity:
	var best: Entity = null
	var bd := 26.0
	var who := net_cmd_team if net_cmd_team >= 0 else controlled_team()
	# (the mouse asks this whenever it moves: a unit more than 26 px away on either axis can't
	# be the nearest within 26 px, so it's passed over before anything else is asked of it)
	for u in units:
		if absf(u.position.x - p.x) >= 26.5 or absf(u.position.y - 12.0 - p.y) >= 26.5:
			continue
		if u.dead or not shown_to_commander(u):
			continue
		var dd: float = (u.position + Vector2(0, -12)).distance_to(p)
		if dd < bd:
			var rider := Unit.mounting_onto(u)
			if rider != null and (rider.dead or not shown_to_commander(rider)):
				continue
			bd = dd
			best = rider if rider != null else u    # (a horse a man is getting on: the strip there is him)
	if best:
		return best
	# a new-Brood creature that roots (the Mother, a Rootmaw, a turtle, a father), rooted or walking, at every growth stage:
	# picked anywhere on its drawn body (the owner, 21:28: "a click anywhere on her sprite"), or on its footprint, as a
	# building; units standing over it were looked at first (a unit on top wins); of two bodies, the one drawn in front
	var nbest: Unit = null
	var nkey := -INF
	for u in units:
		if not u._k_nb or u.dead or not BroodNew.ROOTERS.has(u.kind) or absf(u.position.x - p.x) > 420.0 or absf(u.position.y - p.y) > 420.0:
			continue
		if not shown_to_commander(u):
			continue
		if BroodRoot.body_hit(u, p) or (BroodRoot.has_fp(u) and u.rect().grow(6).has_point(p + Vector2(0, 10))):
			var ky := BroodRoot.sort_y(u)
			if ky > nkey:
				nkey = ky
				nbest = u
	if nbest != null:
		return nbest
	if net_cmd_team < 0:
		# a click on a worker label ("FARMERS 3/8", drawn over everything) picks its building, even over another's drawing
		var lab := WorkerLabels.at(self, p)
		if lab != null:
			return lab
	for b in buildings:
		if hidden_ghost(b, who) or not shown_to_commander(b):
			continue                  # (both tests below need it on show to whoever gave the order)
		if b.rect().grow(6).has_point(p + Vector2(0, 10)):
			return b
		if b.sprite and b.sprite.texture:
			var sr: Rect2 = b.sprite_rect()
			if sr.grow(-6).has_point(p):
				return b
	return null


## The finished economy building of team t (a Farm with its fields, a Mill, Pit, Boiler...)
## whose footprint or sprite is under p, or null.
func crew_site_at(p: Vector2, t: int) -> Building:
	for b in buildings:
		if b.team != t or b.dead or not b.built or not shown_to_commander(b) or b.crew_max() <= 0:
			continue
		if b.rect().grow(4).has_point(p):
			return b
		if b.sprite and b.sprite.texture:
			var sr: Rect2 = b.sprite_rect()
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
	powder("musket", muzzle + u.facing * 6.0, u.facing)
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


## The cavalry's pistol (Defs.PISTOL): one ball, a single ranged blow like a musket's (so a
## rider it kills may leave his horse loose); from the saddle it leaves the rider's hand.
func pistol_shot(u: Unit, e: Entity, dmg: float) -> void:
	var muzzle := u.center() + u.facing * 18.0 + Vector2(0, -16.0)
	if not u.is_mounted():
		# on foot: at his raised hand, where the drawn flash is (the Armoured Officer's fire strips: ~16 px out, 26 up)
		muzzle = u.center() + u.facing * 16.0 + Vector2(0, -24.0)
	musket_shot(u, e, dmg, muzzle)
	if mlog and not _first_of.has("%d:pistol" % u.team):
		_first_of["%d:pistol" % u.team] = true
		mlog.add("%s's first pistol shot (%s)" % [mlog.who(u.team), Defs.train_name(Defs.train_key(u.kind, u.armoured))])


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
	area_mark("wedge", u.team, from, dir, reach, acos(0.72), "steam")
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
	canister_at(u, e.center(), dmg, e)


## Canister toward `aim` (an enemy's centre, or a spot on the ground: BOMBARD); `e`: the building aimed at, if any. It tears
## up the bodies lying in its cone too (Defs.BODY_BLAST), before the balls strike (the men it kills fall as bodies).
func canister_at(u: Unit, aim: Vector2, dmg: float, e: Entity = null) -> void:
	var from := u.center() + u.facing * 28.0
	var dir := (aim - from).normalized()
	if dir == Vector2.ZERO:
		dir = u.facing.normalized()
	var reach := float(Defs.CANISTER["range"]) + 30.0
	blast_bodies_cone(from, dir, reach, float(Defs.CANISTER["cone"]), u.order == "bombard", dmg)
	area_mark("wedge", u.team, from, dir, reach, acos(float(Defs.CANISTER["cone"])), "powder")
	# area damage hits whoever is in it, friend or foe (not the gun itself)
	for o in units_near(from, reach + 20.0):
		if o == u or o.dead or o.off_field:
			continue
		var to: Vector2 = o.center() - from
		if to.length() <= reach + o.radius and dir.dot(to.normalized()) > float(Defs.CANISTER["cone"]):
			var bonus: float = Defs.CANISTER["vs_light"] if o.has_tag("light") else 1.0
			o.take_damage(dmg * bonus * (1.3 if to.length() < reach * 0.5 else 1.0), u)
	if e != null and is_instance_valid(e) and e.is_building():
		e.take_damage(dmg * 0.6, u)
	Sfx.play_any(["combat/cannon_canister", "combat/cannon_attack", "cannon"], u.global_position)
	spawn_effect("smoke", from + dir * 12.0, 0.9)
	spawn_effect("smoke", from + dir * 30.0, 1.2).modulate = Color(1, 1, 1, 0.6)
	powder("canister", from + dir * 14.0, dir)
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


## The Ratchet Turret's screw (RatchetTurret, Defs.TURRET), and the Springer's (Defs.SPRINGER_SHOT: `sc` / `ms` scale the screw
## and its burst, `speed` its flight): the damage lands now (like a musket ball); the screw flies from the barrel or drill
## tip `from`, turned toward the target and spinning (its 4 frames looping), a muzzle burst at the tip and sparks where it
## hits. Ground and air alike. Returns the screw (tests watch it fly).
func screw_shot(src: Entity, e: Entity, dmg: float, from: Vector2, _dir: Array, sc := -1.0, ms := -1.0, speed := -1.0, barrel := Vector2.ZERO) -> Shot:
	e = intercept(src, e)
	var to := e.center()
	e.take_damage(dmg, src, Entity.BLOW_RANGED)
	if sc <= 0.0:
		sc = float(Defs.TURRET["shot_scale"])
	if ms <= 0.0:
		ms = float(Defs.TURRET["muzzle_scale"])
	if speed <= 0.0:
		speed = float(Defs.TURRET["speed"])
	var ang := (to - from).angle()
	if ArtData.EFFECTS.has("screw_muzzle"):
		var mz := spawn_effect("screw_muzzle", from, 1.2)
		# (the burst's brass rings, 0.366 of its cell from the left, sit on the barrel tip; the smoke blows forward)
		mz.offset = Vector2(float(ArtData.EFFECTS["screw_muzzle"]["size"].x) * (0.5 - 0.366), 0.0)
		mz.rotation = barrel.angle() if barrel != Vector2.ZERO else ang      # (along a raised barrel: the Springer shooting up)
		mz.scale = Vector2(ms, ms)
		mz.z_index = 6
	var s := Shot.new()
	s.scale = Vector2(sc, sc)
	s.impact = "screw_impact" if ArtData.EFFECTS.has("screw_impact") else "hit"
	s.impact_scale = sc
	s.launch(self, "screw" if ArtData.EFFECTS.has("screw") else "bolt", from, to, speed)
	Sfx.play_any(["combat/%s_attack" % (src.kind if src is Unit else "ratchet_turret"), "combat/bolt_attack", "bolt"], src.global_position)
	return s


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
	powder("cannon", muzzle + u.facing * 12.0, u.facing)
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
	pr.aimed = u.order == "bombard"
	add_child(pr)
	Sfx.play_any(["combat/cannon_attack", "cannon"], u.global_position)


## A round shot lands: everyone in a line from a little before the spot to well past it
## takes the full blow (more against armour); a small splash where it hits. The bodies in
## that splash and on that line are torn up (Defs.BODY_BLAST; `aimed`: a BOMBARD shot).
func round_shot_land(from: Vector2, p: Vector2, dmg: float, t: int, shooter: Entity, aimed := false) -> void:
	var dir := (p - from).normalized()
	var a := p - dir * 30.0
	var b := p + dir * float(Defs.ROUND_SHOT["line"])
	var w := float(Defs.ROUND_SHOT["width"])
	blast_bodies(p, float(Defs.ROUND_SHOT["splash"]), aimed, a, b, w, dmg)
	area_mark("band", t, a, b, w, 0.0, "powder")
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
	pr.aimed = u.order == "bombard"
	add_child(pr)
	area_mark("oval", u.team, pr.to, Vector2.ZERO, pr.splash, 0.0, "acid", pr.duration, true)     # (where it will land)
	Sfx.play_any(["combat/spitter_attack", "acid"], mouth)


## The blob bursts: acid over a whole area (less at the edge), and it keeps burning.
func blob_land(p: Vector2, dmg: float, splash: float, t: int, shooter: Entity, aimed := false) -> void:
	blast_bodies(p, splash, aimed, Vector2.INF, Vector2.INF, 0.0, dmg)      # (spit at the ground eats the bodies too)
	area_mark("oval", t, p, Vector2.ZERO, splash, 0.0, "acid")
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
	pr.aimed = u.order == "bombard"
	add_child(pr)
	area_mark("ring", u.team, pr.to, Vector2.ZERO, pr.splash, 0.0, "powder", pr.duration, true)     # (where it will land)
	var sm := spawn_effect("smoke", muzzle + Vector2(0, -8), 0.9)
	sm.modulate = Color(1, 1, 1, 0.8)
	powder("mortar", muzzle + Vector2(0, -6), u.facing * 0.3 + Vector2(0, -0.7))
	Sfx.play_any(["combat/mortar_attack", "combat/cannon_attack", "cannon"], u.global_position)


## The shell bursts: every ground unit inside the blast is hurt, friend or foe (less at the
## edge), and enemy buildings close by. The bodies lying in the blast are torn up first
## (Defs.BODY_BLAST; `aimed`: a BOMBARD shell): the men it kills fall as bodies.
func mortar_land(p: Vector2, dmg: float, splash: float, t: int, shooter: Entity, aimed := false) -> void:
	var name := "mortar_blast" if ArtData.EFFECTS.has("mortar_blast") else "blast"
	var fx := spawn_effect(name, p, 1.0)
	fx.offset = Vector2(0, -float(ArtData.EFFECTS[name]["size"].y) * 0.4)
	fx.scale = Vector2.ONE * (splash / 36.0)
	powder("shell", p)
	Sfx.play_any(["combat/mortar_hit", "combat/cannon_hit", "boom"], p)
	blast_bodies(p, splash, aimed, Vector2.INF, Vector2.INF, 0.0, dmg)
	area_mark("ring", t, p, Vector2.ZERO, splash, 0.0, "powder")
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


## The Ticking Owl's bomb lands (OwlBomb, Defs.OWL_BOMB): every enemy building within "radius" px of the impact (edge
## distance) takes `dmg`, enemy ground units within "unit_radius" px a little ("unit_damage", in step with dmg); the
## explosion plays there (its strip has the impact point in the middle of every cell).
func owl_bomb_land(p: Vector2, dmg: float, t: int, shooter: Entity) -> void:
	var ob: Dictionary = Defs.OWL_BOMB
	var fx := spawn_effect("owl_blast" if ArtData.EFFECTS.has("owl_blast") else "explosion", p, 1.0)
	fx.z_index = 6
	Sfx.play_any(["combat/owl_bomb", "combat/mortar_hit", "combat/cannon_hit", "boom"], p)
	var ud := float(ob["unit_damage"]) * dmg / maxf(float(ob["damage"]), 1.0)
	var ur := float(ob["unit_radius"])
	area_mark("ring", t, p, Vector2.ZERO, float(ob["radius"]), 0.0, "brass")
	blast_bodies(p, ur, false)          # (ordinary fire: tears bodies only with a Defs.BODY_BLAST combat share above 0)
	for u in units_near(p, ur + 30.0):
		if u.dead or u.off_field or u.is_air() or not hostile(u.team, t):
			continue
		if u.position.distance_to(p) <= ur + u.radius:
			u.take_damage(ud, shooter)
	for b in buildings.duplicate():
		if not b.dead and hostile(b.team, t) and b.edge_distance(p) <= float(ob["radius"]):
			b.take_damage(dmg, shooter)
	bombs_landed += 1


var bombs_landed := 0       # Ticking Owl bombs that went off (tests)


# ------------------------------------------------------------------ FIRE AT A SPOT (BOMBARD) and AREA SHOTS DESTROY BODIES

## BOMBARD (Ctrl+A or the card's button, then a spot): every unit in the list that can attack the ground keeps attacking
## `p` until another order (Game.ground_order); the others are left as they are. queued: Shift, after their orders. How
## many took it.
func bombard_order(list: Array, p: Vector2, queued := false) -> int:
	return ground_order(list, PackedVector2Array([p]), queued)


## ATTACK GROUND (Ctrl+A, then a click or a held left-drag; Defs.GROUND): one point: everyone attacks that spot; a line:
## it is shared out among the units like the formation drag (Game.line_stretches, in order along it so their paths don't
## cross) and each attacks the ground along its own stretch. They keep at it until another order. queued: Shift.
func ground_order(list: Array, pts: PackedVector2Array, queued := false) -> int:
	var line := PackedVector2Array()
	for q in pts:
		line.append(on_map(q))
	if line.is_empty():
		return 0
	var one := line.size() < 2 or _poly_len(line) < 1.0
	if puppet and not queued:
		var ss := line_stretches(line, list.size()) if not one else []
		for i in list.size():
			var e = list[i]
			if e is Unit and is_instance_valid(e) and e.can_ground_attack():
				# (online guest: its copy shows the spot or stretch; the host sends the order back)
				e.order_point = line[0] if one else ss[i][2]
				e.gnd_a = line[0] if one else ss[i][0]
				e.gnd_b = line[0] if one else ss[i][1]
	if net_forward(self, "ground_order", [list, line, queued]): return 0
	var us: Array = list.filter(func(e) -> bool: return e is Unit and is_instance_valid(e) and not e.dead and e.can_ground_attack())
	if one:
		for u in us:
			u.give({"o": "bombard", "p": line[0]}, queued)
	else:
		var dir := (line[line.size() - 1] - line[0]).normalized()
		us.sort_custom(func(a: Unit, b: Unit) -> bool: return a.plan_end().dot(dir) < b.plan_end().dot(dir))
		var ss := line_stretches(line, us.size())
		for i in us.size():
			us[i].give({"o": "bombard", "p": ss[i][2], "a": ss[i][0], "b": ss[i][1]}, queued)
	if not us.is_empty() and us[0].team == human:
		command_sound(us, "attack", "attack")
		_ping(line[line.size() - 1] if not one else line[0], BOMBARD_COL)
	return us.size()


static func _poly_len(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l


## The point `l` px along a drawn line.
static func _poly_at(pts: PackedVector2Array, l: float) -> Vector2:
	for i in range(1, pts.size()):
		var sl := pts[i - 1].distance_to(pts[i])
		if l <= sl or i == pts.size() - 1:
			return pts[i - 1].lerp(pts[i], clampf(l / maxf(sl, 0.001), 0.0, 1.0))
		l -= sl
	return pts[pts.size() - 1]


## A drawn line shared out among n units, in order along it: [start, end, middle] of each one's stretch.
static func line_stretches(pts: PackedVector2Array, n: int) -> Array:
	var total := _poly_len(pts)
	var out: Array = []
	for k in maxi(n, 1):
		var a := _poly_at(pts, total * float(k) / float(maxi(n, 1)))
		var b := _poly_at(pts, total * float(k + 1) / float(maxi(n, 1)))
		out.append([a, b, _poly_at(pts, total * (float(k) + 0.5) / float(maxi(n, 1)))])
	return out


# ------------------------------------------------------------------ BODIES HAVE HEALTH (Defs.ROT, Defs.GROUND)

## A body still lying there that can be hit (not torn up, not wrapped and fading, not raised).
static func lying(b) -> bool:
	return b != null and is_instance_valid(b) and b is Unit and b.dead and not b.torn and not b.off_field \
		and b.modulate.a > 0.99 and b.is_inside_tree()


## A body takes `dmg` (a ground attack's blow or shot, an area shot fired at the ground): its rot end comes sooner; at 0
## it is torn up (no harvest, no raising). True if that tore it up. The guest is told its health (fx "h").
func hit_body(b: Unit, dmg: float, aimed := true) -> bool:
	if not lying(b) or dmg <= 0.0:
		return false
	b.body_dmg += dmg
	bodies_hit += 1
	if b.body_left() <= 0.0:
		tear_body(b, aimed)
		return true
	if b._rip and b._rip.is_valid():
		b._schedule_rot()
	if net != null and not puppet and net.fx.size() < NetSession.FX_MAX:
		net.fx.append(["h", "", b.position, b.body_left()])
	if rec != null and not puppet and rec.fx.size() < NetSession.FX_MAX:
		rec.fx.append(["h", "", b.position, b.body_left()])
	return false


var bodies_hit := 0           # blows and blasts that hurt a body (tests)


## Guest: the host says the body lying at p has `left` health now (Game.hit_body): its damage is set to match (the rot it
## works out itself).
func body_health_at(p: Vector2, left: float) -> void:
	var best: Unit = null
	var bd := 12.0
	for b in bodies:
		if lying(b) and (b as Unit).position.distance_to(p) < bd:
			bd = (b as Unit).position.distance_to(p)
			best = b
	if best == null:
		return
	best.body_dmg = maxf(0.0, best.body_size() - Unit.rot_lost(clock - best.died_at) - left)
	if best._rip and best._rip.is_valid():
		best._schedule_rot()


## How long a grub takes to wrap this body: Defs.HARVEST take x sqrt(its health / ref), within take_min..take_max (its
## size, not what is left of it).
func harvest_time(b: Unit) -> float:
	var hv: Dictionary = Defs.HARVEST
	var k := sqrt(b.body_size() / float(hv["ref"])) if b != null and is_instance_valid(b) else 1.0
	return clampf(float(hv["take"]) * k, float(hv["take_min"]), float(hv["take_max"]))


## The body lying nearest to `from` within `r` of the segment a..b (a == b: of a point), or null.
func ground_body(from: Vector2, a: Vector2, b: Vector2, r: float) -> Unit:
	var best: Unit = null
	var bd := INF
	for body in bodies:
		if not lying(body):
			continue
		var bp: Vector2 = body.position
		var q := Geometry2D.get_closest_point_to_segment(bp, a, b)
		if q.distance_to(bp) > r + body.radius * 0.5:
			continue
		var dd := from.distance_to(bp)
		if dd < bd:
			bd = dd
			best = body
	return best


## An enemy of u's (one it could hit) standing at p: where a ranged shot at the ground lands.
func foe_at(u: Unit, p: Vector2) -> Unit:
	for o in units_near(p, 40.0):
		if not o.dead and not o.off_field and hostile(o.team, u.team) and o.position.distance_to(p) <= o.radius + 4.0 \
				and u.can_hit(o):
			return o
	return null


## The look and sound of a single ranged shot at the ground (the damage is the caller's): a musket ball, a glob of acid,
## a zap, a screw, a gust of steam (the units' own art and sounds).
func ground_shot_fx(u: Unit, to: Vector2) -> void:
	var from := u.center() + u.facing * 16.0
	match u.kind:
		"spitter", "skywing", "bloater", BroodNew.DILO:
			var s := Shot.new()
			s.arc = 0.18
			s.scale = Vector2(1.3, 1.3)
			s.impact = "acid_splash"
			s.impact_scale = 0.7
			s.launch(self, "acid_ball", from, to, 330.0)
			Sfx.play_any(["combat/%s_attack" % u.kind, "combat/spitter_attack", "acid"], from)
		"tesla_cart", "stormcaller", "ornithopter", "arc_thrower", "tesla_loco":
			_zap_visual(u.coil_point() if u.kind == "tesla_cart" else from, to, false, true)
			Sfx.play_any(["combat/tesla_attack", "zap"], from)
		"steam_walker":
			var dir := (to - from).normalized()
			for i in 3:
				var fx := spawn_effect("smoke", from + dir * (20.0 + i * 22.0), 1.6)
				fx.modulate = Color(1.3, 1.3, 1.3, 0.85)
			Sfx.play_any(["combat/steam_walker_attack", "steam"], from)
		_:
			spawn_effect("smoke", from + u.facing * 8.0, 1.2).scale = Vector2(0.7, 0.7)
			if powder_gun(u):
				powder("musket", from + u.facing * 6.0, u.facing)
			var s := Shot.new()
			s.face_offset = PI
			s.scale = Vector2(0.45, 0.45)
			s.impact = "smoke"
			s.impact_scale = 0.35
			s.launch(self, "bolt" if u.kind == Defs.SPRINGER and ArtData.EFFECTS.has("bolt") else "ball", from, to, 950.0)
			Sfx.play_any(["combat/%s_attack" % u.kind, "combat/musketeer_attack", "musket"], u.global_position)


## One shot of a BOMBARD at the spot p: the gun's round shot or canister, the Mortar's shell, the Spore Mother's blob. The
## enemies standing where it lands may see who fired (as for a shot at them: note_shot).
func bombard_shot(u: Unit, p: Vector2, dmg: float) -> void:
	match u.kind:
		"cannon":
			if u.mode == "canister":
				canister_at(u, p, float(Defs.CANISTER["damage"]))
			else:
				cannon_shot(u, p, dmg)
		"mortar":
			mortar_shot(u, p, dmg)
		"spore_mother":
			blob_shot(u, p, dmg)
		"ballista":
			Ballista.fire_at(u, p, dmg)       # (the bolt through the spot and on: scripts/ballista.gd)
	var told := {}
	for o in units_near(p, float(u.d.get("splash", 40.0)) + 40.0):
		if not o.dead and not o.off_field and hostile(o.team, u.team) and not told.has(o.team):
			told[o.team] = true
			note_shot(u, o)


var bodies_blasted := {"aimed": 0, "combat": 0}     # bodies torn up so far: by BOMBARD shots, by ordinary fire (tests, measurements)
var body_combat := -1.0           # (measurements) this match's share of the blast for ordinary fire; < 0: Defs.BODY_BLAST.combat


func _combat_share(aimed: bool) -> float:
	if aimed:
		return 1.0
	return body_combat if body_combat >= 0.0 else float(Defs.BODY_BLAST["combat"])


## The bodies that matter lying near p (the Brood's to harvest, the Crown's to raise) and the others still lying there.
func _bodies_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	for group in [corpses, fallen, bodies]:
		for b in group:
			if is_instance_valid(b) and b.position.distance_to(p) <= r and b.dead and not b.torn and not out.has(b):
				out.append(b)
	return out


## A blast at p (a shell's splash r, round shot's splash plus the line a..b it ploughs, `w` wide) tears up the bodies lying
## in it (Defs.BODY_BLAST): no harvest, no raising. `aimed`: a BOMBARD shot; ordinary fire tears only the `combat` share of
## the blast (its middle). Returns how many.
func blast_bodies(p: Vector2, r: float, aimed: bool, a := Vector2.INF, b := Vector2.INF, w := 0.0, dmg := -1.0) -> int:
	var k := _combat_share(aimed)
	if k <= 0.0:
		return 0
	r *= k
	var look := r
	if a != Vector2.INF:
		look = maxf(look, maxf(p.distance_to(a), p.distance_to(b)) + w)
	var n := 0
	for body in _bodies_near(p, look + 12.0):
		var reach: float = body.radius * 0.5
		var inside: bool = body.position.distance_to(p) <= r + reach
		if not inside and a != Vector2.INF and w * k > 0.0:
			# the line it ploughs (a combat shot: only the middle of its width, and only near where it lands)
			var aa := p + (a - p) * k
			var bb := p + (b - p) * k
			inside = Geometry2D.get_closest_point_to_segment(body.position, aa, bb).distance_to(body.position) <= w * k + reach
		if inside and _blast_body(body, dmg, aimed):
			n += 1
	return n


## A body in an area shot's blast: hurt by the shot's damage x Defs.BODY_BLAST.body (torn up at 0: true), or torn up
## outright when no damage is given (dmg < 0).
func _blast_body(body: Unit, dmg: float, aimed: bool) -> bool:
	if dmg < 0.0:
		tear_body(body, aimed)
		return true
	return hit_body(body, dmg * float(Defs.BODY_BLAST["body"]), aimed)


## Canister's cone (from the muzzle along dir, `reach` long, cos of its half-angle `cone`) tears up the bodies in it.
func blast_bodies_cone(from: Vector2, dir: Vector2, reach: float, cone: float, aimed: bool, dmg := -1.0) -> int:
	var k := _combat_share(aimed)
	if k <= 0.0:
		return 0
	reach *= k
	var n := 0
	for body in _bodies_near(from, reach + 12.0):
		var to: Vector2 = body.position - from
		if to.length() <= reach + body.radius * 0.5 and to.length() > 1.0 and dir.dot(to.normalized()) > cone \
				and _blast_body(body, dmg, aimed):
			n += 1
	return n


## A body torn up by a shell, round shot, canister or bomb: off the harvest and revive lists at once (a grub wrapping it or
## a Missionary raising it lets go), a puff of earth and scraps where it lay, and it is gone in a moment.
func tear_body(b: Unit, aimed := false) -> void:
	if b == null or not is_instance_valid(b) or not b.dead or b.torn:
		return
	corpses.erase(b)
	fallen.erase(b)
	bodies.erase(b)
	bodies_blasted["aimed" if aimed else "combat"] += 1
	if net != null and not puppet and net.fx.size() < NetSession.FX_MAX:
		net.fx.append(["c", "", b.position, 0.0])       # (online: the guest's copy of it goes too)
	if rec != null and not puppet and rec.fx.size() < NetSession.FX_MAX:
		rec.fx.append(["c", "", b.position, 0.0])       # (and the replay's)
	torn_fx(b.position)
	b.tear_up()


## A Clockwork wreck swept into a Great Winder's hopper (GreatWinder.take): off the harvest and revive lists, gone from
## the field like a torn-up body (online and in replays too: the same "c" effect, the guest's copy goes), with a puff of
## dust where it lay.
var bodies_swept := 0          # wrecks swept up so far (tests)
func sweep_body(b: Unit) -> void:
	if b == null or not is_instance_valid(b) or not b.dead or b.torn:
		return
	corpses.erase(b)
	fallen.erase(b)
	bodies.erase(b)
	bodies_swept += 1
	if net != null and not puppet and net.fx.size() < NetSession.FX_MAX:
		net.fx.append(["c", "", b.position, 0.0])
	if rec != null and not puppet and rec.fx.size() < NetSession.FX_MAX:
		rec.fx.append(["c", "", b.position, 0.0])
	torn_fx(b.position)
	b.tear_up()


## The little effect of a body torn up (code-made: the dust puff tinted to earth and scraps, docs/art_style_inconsistency.md).
func torn_fx(p: Vector2) -> void:
	var e := Effect.new()
	e.setup("dust", 1.7, false)
	e.position = p + Vector2(0, -2)
	e.scale = Vector2(0.55, 0.42)
	e.modulate = Color(0.58, 0.42, 0.34, 0.95)
	e.z_index = 3
	e.visible = ground_seen(p)          # (a body torn up where your side has never looked: unseen)
	add_child(e)


## Online guest: the host tore up the body lying at p: the nearest body there goes too (only the look).
func torn_at(p: Vector2) -> void:
	var best: Unit = null
	var bd := 12.0
	for n in world.get_children():
		if n is Unit and n.dead and not n.torn and (n as Unit).position.distance_to(p) < bd:
			bd = (n as Unit).position.distance_to(p)
			best = n
	torn_fx(p)
	if best:
		bodies.erase(best)
		best.tear_up()


## MORPH TO OWL: the selected Swifts that can start turning into Ticking Owls (CwAir.morph_order). "" or why none did.
func morph_order(list: Array) -> String:
	if net_forward(self, "morph_order", [list]): return ""
	return CwAir.morph_order(self, list)


## CANCEL MORPH: the selected Swifts that are turning into Owls stop, paid back.
func cancel_morph(list: Array) -> void:
	if net_forward(self, "cancel_morph", [list]): return
	CwAir.cancel_order(list)


## Spells on the ground for a while: [{kind, pos, r, t, team, age, fx, healed}]
var zones: Array = []


## A Bloater bursts: a little damage where it pops, and an acid cloud that lingers.
func bloat_burst(u: Unit) -> void:
	var p := u.position
	# everything scales with the gas left in the sac: a full one is a huge bomb
	var full := clampf(u.gas / 100.0, 0.15, 1.0)
	var r := float(Defs.BLOAT["radius"]) * (0.5 + 0.5 * full)
	var dmg := float(Defs.BLOAT["burst"]) * full
	area_mark("ring", u.team, p, Vector2.ZERO, r, 0.0, "acid")
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
	area_mark("oval", u.team, p, Vector2.ZERO, r, 0.0, "acid", float(z["t"]), false, true)     # (the gas cloud's edge)
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
			return "Not enough spoils."
	return ""


## Infantry climbs into the balloons (each man into the nearest one with room). The balloon
## must hover over ground they can walk to; it stops and comes down while they board.
## Units that can't ride just walk over.
func load_order(riders: Array, balloons: Array) -> void:
	if net_forward(self, "load_order", [riders, balloons]): return
	var bs: Array = balloons.filter(func(b) -> bool: return b is Unit and is_instance_valid(b) and not b.dead and Unit.carrier(b.kind))
	if bs.is_empty():
		return
	var why := ""
	var men: Array = riders.filter(func(u) -> bool: return u is Unit and is_instance_valid(u) and not u.dead and not Unit.carrier(u.kind) and u.crew_of == null)
	men.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_squared_to(bs[0].position) < b.position.distance_squared_to(bs[0].position))
	for u in men:
		var best: Unit = null
		var bd := INF
		for b in bs:
			if not u.can_board(b) or b.room() <= 0:
				continue
			if b.kind == "balloon" and not _clear_at(b.position, 8.0, b.team):
				why = "The balloon must hover over open ground to take men aboard."
				continue
			var dd: float = u.position.distance_to(b.position)
			if dd < bd:
				bd = dd
				best = b
		if best:
			if best.kind == "balloon" and best.order != "idle" and best.order != "hold" and best.incoming.is_empty():
				best.cmd_stop()        # it stops where it is and comes down (a Ballista rolls on: its crew catch it up)
			u.cmd_board(best)
		elif bs.all(func(b: Unit) -> bool: return b.kind == Defs.BALLISTA_KIND):
			if why == "":
				why = "Only Winders crew a Spring Ballista." if u.kind != "winder" else "The Ballista's crew is full (%d Winders and its own)." % int(Defs.BALLISTA["crew"])
		elif not (Defs.DROPSHIP["kinds"] as Array).has(u.kind):
			if why == "":
				why = "Only Musketeers and Labourers fit in the basket."
		elif why == "" and bs.all(func(b: Unit) -> bool: return b.room() <= 0):
			why = "The basket is full (%d men)." % int(Defs.DROPSHIP["capacity"])
	if why != "" and not men.is_empty():
		tell(men[0].team, why)


## The selected balloons with men aboard fly to `p` and let them off (here: right below).
func unload_order(list: Array, p: Vector2, here := false) -> void:
	if net_forward(self, "unload_order", [list, p, here]): return
	var any := false
	for b in list:
		if b is Unit and not b.dead and b.kind == "balloon" and not b.passengers.is_empty():
			b.cmd_unload(b.position if here else p)
			any = true
		elif b is Unit and not b.dead and b.kind == Defs.BALLISTA_KIND and not Ballista.crew_of(b).is_empty():
			b.cmd_unload(b.position)      # (its crew step off where they stand)
			any = true
	if not any and not list.is_empty() and list[0] is Unit:
		tell(list[0].team, "Nobody aboard.")


## The nearest selected Ornithopter carrying a battery flies over and overloads `e`.
func overload_order(list: Array, e: Entity) -> void:
	if net_forward(self, "overload_order", [list, e]): return
	var me: int = list[0].team if not list.is_empty() and list[0] is Unit else human      # (online: the guest who ordered it)
	if not (e is Unit) or e.dead or e.team != me or e.d["faction"] != "clockwork" or e.is_worker():
		tell(me, "Pick one of your constructs to overload.")
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
		tell(me, "No Ornithopter here carries a battery.")


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


## The selected casters: the nearest one that can cast goes and does it. ("jump": every selected Springer that can jumps, each
## to its own spot of the group round p: Springer.jump_order.)
func cast_order(list: Array, spell: String, p: Vector2) -> void:
	if net_forward(self, "cast_order", [list, spell, p]): return
	if spell == "jump":
		var why := Springer.jump_order(self, list, p)
		if why != "" and not list.is_empty() and list[0] is Unit:
			tell(list[0].team, why)
		return
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
	elif list.size() > 0 and list[0] is Unit:
		tell(list[0].team, why)


func cast_spell(u: Unit, spell: String, p: Vector2) -> void:
	var w := spell_problem(u, spell)
	if w != "":
		tell(u.team, w)
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
	area_mark("oval", u.team, p, Vector2.ZERO, float(z["r"]), 0.0, {"storm": "storm", "fog": "fog"}.get(spell, "miasma"), float(z["t"]), false, true)
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
		"spitter", "bloater", BroodNew.DILO:
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
	if powder_gun(u):
		powder("cannon" if u.kind == "cannon" else "musket", from + u.facing * 8.0, u.facing)
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
	if net_forward(self, "tongue_order", [list, e]): return
	var toads := list.filter(func(u) -> bool: return u is Unit and not u.dead and u.kind == "mist_toad")
	if toads.is_empty():
		return
	if not (e is Unit) or not toads[0].can_tongue(e):
		tell(toads[0].team, "Pick an enemy unit (on the ground or a flyer; not a building).")
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
	else:
		tell(toads[0].team, "Not enough energy: TONGUE needs %d." % int(Defs.TONGUE["cost"]))


## A Toad has marked its victim: the crosshair goes up (its owner is warned).
func tongue_marked(toad: Unit, e: Unit) -> void:
	if not tongues.has(toad):
		tongues.append(toad)
	tell(e.team, "A Mist Toad is aiming its tongue at your %s: move it away or stun the Toad!" % String(e.d["name"]), true)
	if e.team == human:
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
			# enemy buildings in the cloud are eaten too, at a share of the rate (BLOAT.buildings)
			var bdps := float(Defs.BLOAT["dps"]) * float(Defs.BLOAT["buildings"]) * delta
			for b in buildings.duplicate():
				if b.dead or b.ghost or not hostile(b.team, int(z["team"])):
					continue
				var r2: Rect2 = b.rect()
				if not in_ellipse(p, p.clamp(r2.position, r2.end), r):
					continue
				b.take_damage(bdps, null)
			continue
		if z["kind"] == "storm":
			for u in units_near(p, r + 20.0):
				if u.dead or u.off_field or not in_ellipse(p, u.position, r + u.radius):
					continue
				# (topped up every tick while it stands in the storm: its mark lasts to the storm's end, StunMark)
				u.stun(0.2, true, clock + maxf(float(z["t"]) - float(z["age"]), 0.0) + 0.2)
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


## A line spot that fell on a blocked cell: the nearest free cell on that cell's height level that
## fewer than two others were given already (else nearest_free_level's cell), a little to one side
## of its middle for the second man there.
func _line_spot_free(c: Vector2i, taken: Dictionary) -> Vector2:
	var lv := int(height[idx(c)])
	for r in range(1, 7):
		var best := Vector2i(-1, -1)
		var bd := INF
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if absi(x) != r and absi(y) != r:
					continue
				var cc := c + Vector2i(x, y)
				if is_free(cc) and int(height[idx(cc)]) == lv and ramp[idx(cc)] == 0 and int(taken.get(cc, 0)) < 2 and in_open_map(cc):
					var dd := Vector2(x, y).length()
					if dd < bd:
						bd = dd
						best = cc
		if best.x >= 0:
			var nth := int(taken.get(best, 0))
			taken[best] = nth + 1
			return cell_center(best) + (Vector2(-7, -5) if nth == 0 else Vector2(7, 5))
	return cell_center(nearest_free_level(c, 6))


## Line move: every selected unit takes its own spot along the line. Units are matched to
## spots in order along the line, so their paths don't cross.
func line_move(list: Array, pts: PackedVector2Array, attack: bool, queued := false) -> void:
	if net_forward(self, "line_move", [list, pts, attack, queued]): return
	var us: Array = list.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead)
	if us.is_empty() or pts.size() < 2:
		return
	var spots := line_spots(pts, us.size())
	var dir := (pts[pts.size() - 1] - pts[0]).normalized()
	us.sort_custom(func(a: Unit, b: Unit) -> bool: return a.plan_end().dot(dir) < b.plan_end().dot(dir))
	var taken := {}
	for i in us.size():
		var u: Unit = us[i]
		var sp: Vector2 = spots[i]
		if in_map(cell_of(sp)) and not open_cell(cell_of(sp)):
			sp = _line_spot_free(cell_of(sp), taken)     # (a spot on a cliff's rim, a tree: free ground beside it on its own level)
		u.give({"o": "amove" if attack else "move", "p": sp}, queued)
	_ping(pts[pts.size() - 1], Color(1, 0.4, 0.3) if attack else Color(0.4, 1, 0.4))


func explode(p: Vector2, dmg: float, splash: float, t: int, shooter: Entity) -> void:
	area_mark("ring", t, p, Vector2.ZERO, splash, 0.0, "brass" if t >= 0 and t < factions.size() and factions[t] == "clockwork" else "powder")
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
	powder("wagon" if big else "keg", p)
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
	area_mark("ring", src.team if src != null else -1, p, Vector2.ZERO, r, 0.0, "powder")
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


# ------------------------------------------------------------------ haulers (Defs.HAUL)
## Workers assigned to a Town Hall carry what the base asks for. A request exists as long as
## its demand does (a queue entry holding a horse reservation, a Powder Wagon on SUPPLY with
## room for a keg, a gun with fewer horses than its team_want) and is served in order, oldest
## first, by the nearest hauler who is free. A horse is claimed (Unit.claimed, kept by the
## hauler's haul_job) and a keg counted against the wagon's room the moment it is given out, so
## two haulers never take the same one; whatever cuts a job short (the hauler killed or ordered
## elsewhere, the building gone) lifts the claim: the request is simply served again.

## A side's Town Halls (finished, standing) that take haulers.
func haul_halls(t: int) -> Array:
	return buildings.filter(func(b: Building) -> bool: return b.team == t and b.built and not b.dead and b.haul_cap() > 0)


## A side's haulers (assigned to its Town Halls, alive).
func haulers_of(t: int) -> Array:
	var out: Array = []
	for b in haul_halls(t):
		out.append_array(b.haulers())
	return out


## Has this side a hauler at all?
func hauler_serves(t: int) -> bool:
	for b in buildings:
		if b.team == t and b.built and not b.dead and b.haul_cap() > 0 and not b.haulers().is_empty():
			return true
	return false


## Is the horse kept for `rid` brought by a hauler (one is free to come, or already has a hold
## of the horse)? If not, its recruit or gun fetches it itself at once.
func hauler_serves_rid(t: int, rid: int) -> bool:
	if not hauler_serves(t):
		return false
	var h := reserved_horse(t, rid)
	if h != null and Unit._claim_live(h):
		return true
	return haulers_of(t).any(func(u: Unit) -> bool: return u.haul_job.is_empty() \
		or (String(u.haul_job.get("ph", "")) == "home" and u.led.is_empty() and not u.keg))


## A horse nobody has a hold of.
func horse_unclaimed(h: Unit) -> bool:
	return h.into == null and h.leader == null and h.bolt_t <= 0.0 and not h.off_field and not Unit._claim_live(h)


## Where a led horse goes: the building holding its reservation, the new rider waiting on foot
## for it, or (a team job) the gun; null once nobody wants it.
func haul_dest(u: Unit, h: Unit) -> Entity:
	if String(u.haul_job.get("k", "")) == "team":
		var g = u.haul_job.get("gun")
		if g != null and is_instance_valid(g) and not g.dead and g.team_room():
			return g
		return null
	return rid_owner(h.team, h.horse_rid) as Entity


## The horses asked for by reservations: [{key, k: "horse", rid, dest, horse (or null: still
## being trained), ready}].
func horse_requests(t: int) -> Array:
	var out: Array = []
	for b in buildings:
		if b.team != t or b.dead or not b.built or b.kind == "horse_breeder":
			continue
		for kt in b.kits:
			if kt is Dictionary and int(kt.get("rid", 0)) != 0:
				var rid := int(kt["rid"])
				var h := reserved_horse(t, rid)
				out.append({"key": "h%d" % rid, "k": "horse", "rid": rid, "dest": b, "horse": h, "ready": h != null and horse_unclaimed(h)})
	for u in units:
		if u.team == t and not u.dead and u.horse_rid != 0 and u.kind != "horse" and Defs.RIDERS.values().has(u.kind):
			var h2 := reserved_horse(t, u.horse_rid)
			out.append({"key": "h%d" % u.horse_rid, "k": "horse", "rid": u.horse_rid, "dest": u, "horse": h2, "ready": h2 != null and horse_unclaimed(h2)})
	return out


## Guns and wagons with fewer horses (and none on the way) than their team_want.
func team_requests(t: int) -> Array:
	var out: Array = []
	for g in units:
		if g.team != t or g.dead or g.team_want <= 0 or not Defs.HARNESSED.has(g.kind) or g.off_field or g.aboard != null:
			continue
		var home := nearest_hall(g.position, t)
		if home == null or home.edge_distance(g.position) > 16.0 * T:
			continue                 # (out in the field: not worth the walk)
		var coming := units.filter(func(h: Unit) -> bool: return h.kind == "horse" and not h.dead and h.into == g).size()
		for u in haulers_of(t):
			if String(u.haul_job.get("k", "")) == "team" and u.haul_job.get("gun") == g:
				coming += (u.haul_job.get("want", []) as Array).size() + u.led.size()
		var missing: int = g.team_want - g.horse_count() - coming
		if missing > 0:
			out.append({"key": "t%d" % g.get_instance_id(), "k": "team", "gun": g, "n": missing})
	return out


## Powder Wagons on SUPPLY (out of reach of a filling building) whose powder use calls for more kegs than are already
## on the way (WorkerLabels.wagon_need; the owner, 2026-10-29: no limit of kegs in flight, not even the wagon's room), and dry Field Cannons / Mortars that cannot limber (on HOLD, or no
## horse) and so cannot drive to a refill; the powder bank must have a keg's worth.
func keg_requests(t: int) -> Array:
	var out: Array = []
	var shots := float(Defs.WAGON["keg"])
	if float(players[t]["res2"]) < shots / float(Defs.WAGON["per_powder"]):
		return out
	var mills := buildings.filter(func(b: Building) -> bool: return b.team == t and b.kind == "powder_mill" and b.built and not b.dead)
	if mills.is_empty():
		return out
	var hs := haulers_of(t)
	for w in units:
		if w.team != t or w.dead or w.off_field:
			continue
		var flying := hs.filter(func(u: Unit) -> bool: return String(u.haul_job.get("k", "")) == "keg" and u.haul_job.get("wagon") == w).size()
		if w.kind == "powder_wagon":
			if not w.supplying or w._powder_building() != null:
				continue
			# as many kegs on the way as its powder use calls for (WorkerLabels.wagon_need: kegs a second x the round trip),
			# whatever its room: the haulers wait by a full wagon, keg in hand (the owner, 08:05). With no recent use, one
			# keg while it has room for one (filling up), none when it is full: an idle full wagon pulls nothing.
			var wn := WorkerLabels.wagon_need(self, w)
			var want := 0
			if float(wn["rate"]) > 0.0:
				want = maxi(1, ceili(float(wn["want"]) - 0.05))
			elif w.max_powder() - w.powder >= shots:
				want = 1
			var n := want - flying
			if n > 0:
				out.append({"key": "k%d" % w.get_instance_id(), "k": "keg", "wagon": w, "n": n})
		elif w.needs_keg() and flying == 0:
			out.append({"key": "k%d" % w.get_instance_id(), "k": "keg", "wagon": w, "n": 1})
	return out


var _haul_t := 0.0
var _haul_seen := {}                # request key -> clock it first appeared (oldest is served first)
var worker_label_state := {}        # the haulers' need (WorkerLabels: the wagons' powder use, read by keg_requests; the labels' smoothed numbers)


## Every Defs.HAUL.scan s: give the free haulers of each side the requests of its base.
func haul_dispatch(delta: float) -> void:
	WorkerLabels.tick(self, delta)        # (the wagons' powder use and the haulers' need: the kegs sent below, the HAULERS label)
	_haul_t -= delta
	if _haul_t > 0.0:
		return
	_haul_t = float(Defs.HAUL["scan"])
	var live := {}
	for t in n_players():
		var free: Array = haulers_of(t).filter(func(u: Unit) -> bool: return u.haul_job.is_empty() \
			or (String(u.haul_job.get("ph", "")) == "home" and u.led.is_empty() and not u.keg))
		if haulers_of(t).is_empty():
			continue
		var reqs: Array = horse_requests(t) + team_requests(t) + keg_requests(t)
		for r in reqs:
			live[r["key"]] = true
			if not _haul_seen.has(r["key"]):
				_haul_seen[r["key"]] = clock
			r["age"] = _haul_seen[r["key"]]
		if free.is_empty():
			continue
		reqs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["age"]) < float(b["age"]))
		var taken := {}
		for r in reqs:
			if free.is_empty():
				break
			if taken.has(r["key"]):
				continue
			match String(r["k"]):
				"horse":
					if not r["ready"]:
						continue
					var h: Unit = r["horse"]
					var u := _nearest_free_hauler(free, h.position)
					free.erase(u)
					var want: Array = [h]
					taken[r["key"]] = true
					for r2 in reqs:
						if want.size() >= int(Defs.HAUL["horses"]):
							break
						if r2["k"] == "horse" and r2["ready"] and not taken.has(r2["key"]) \
								and (r2["horse"] as Unit).position.distance_to(h.position) < float(Defs.HAUL["batch"]) * T:
							want.append(r2["horse"])
							taken[r2["key"]] = true
					u.begin_haul({"k": "horse", "ph": "fetch", "want": want})
					for x in want:
						x.claimed = u
				"team":
					var g: Unit = r["gun"]
					var sp := spare_horse(t, g)
					if sp == null:
						continue
					var u2 := _nearest_free_hauler(free, sp.position)
					free.erase(u2)
					var want2: Array = [sp]
					u2.begin_haul({"k": "team", "ph": "fetch", "want": want2, "gun": g})
					sp.claimed = u2
					while want2.size() < mini(int(r["n"]), int(Defs.HAUL["horses"])):
						var more := spare_horse(t, g)
						if more == null:
							break
						want2.append(more)
						more.claimed = u2
				"keg":
					for i in int(r["n"]):
						if free.is_empty():
							break
						var u3 := _nearest_free_hauler(free, (r["wagon"] as Unit).position)
						free.erase(u3)
						# a keg dropped on the ground is carried on first (PowderKeg), before a new one from the Mill
						var pk := free_keg(t, u3.position, 60.0 * T)
						if pk:
							pk.claimed = u3
							u3.begin_haul({"k": "keg", "ph": "to_pick", "pk": pk, "wagon": r["wagon"]})
						else:
							u3.begin_haul({"k": "keg", "ph": "to_mill", "wagon": r["wagon"]})
	for k in _haul_seen.keys():
		if not live.has(k):
			_haul_seen.erase(k)


func _nearest_free_hauler(free: Array, p: Vector2) -> Unit:
	var best: Unit = free[0]
	var bd := INF
	for u in free:
		var dd: float = u.position.distance_squared_to(p)
		if dd < bd:
			bd = dd
			best = u
	return best


## A hauler has delivered something (a statistic and the match log's first of each).
func haul_done(t: int, what: String) -> void:
	if t < 0 or t >= stats.size():
		return
	stats[t]["hauled_" + what] = int(stats[t].get("hauled_" + what, 0)) + 1
	if mlog and not _first_of.has("%d:hauled_%s" % [t, what]):
		_first_of["%d:hauled_%s" % [t, what]] = true
		mlog.add("%s's first %s hauled by a hauler" % [mlog.who(t), what])


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
	if net != null and not puppet:
		net.note_effect(name, p, speed, looping)         # (online host: the guest sees it too)
	if rec != null and not puppet:
		rec.note_effect(name, p, speed, looping)         # (and the replay)
	var e := Effect.new()
	e.setup(name, speed, looping)
	e.position = p
	e.z_index = 3
	if not ground_seen(p):
		# (ground your side has never looked at: what happens there stays out of sight, as
		# under the old black fog; a lasting one shows once that ground is seen, _show_waiting)
		e.visible = false
		if looping:
			_fx_hidden.append(e)
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


## Demo: what this player's side has explored, for when the spectator looks through its
## eyes (the same cells _reveal / _reveal_air just lit). One map per side, kept in the slot of
## the side's first player (side_slot): nothing to merge when it's looked at.
func _explore(t: int, c: Vector2i, r: int, low: bool) -> void:
	var s := side_slot(t)
	var ex: PackedByteArray = explored_by[s]
	explored_by[s] = _EMPTY
	var sw := _swamp_any
	var watch := sw.size() == W * H and view_team >= 0 and allied(t, view_team)
	for o in _disk(r):
		var cc: Vector2i = c + o
		if cc.x >= 0 and cc.y >= 0 and cc.x < W and cc.y < H:
			var i := cc.y * W + cc.x
			if low and height[i] == 1 and o.length_squared() > 2:
				continue
			if watch and ex[i] == 0 and sw[i] == 1:
				_swamp_seen = true
			ex[i] = 1
	explored_by[s] = ex


## The player whose explored_by slot holds this player's side's map (the side's first).
func side_slot(t: int) -> int:
	for o in n_players():
		if allied(o, t):
			return o
	return t




## Mark a disk of cells seen in the team's and its side's grid (and explored, on your side:
## the ground your side has ever looked at, where another side's swamp and the like may show).
## Seen from low ground, high ground is hidden beyond the next cells. (The disk as flat
## offsets with no bounds tests when it lies inside the map (_stamp_inside), else by rows cut
## to the map: this runs for every unit and building four times a second.)
func _stamp(v: PackedByteArray, sv: PackedByteArray, c: Vector2i, r: int, low: bool, mine: bool) -> void:
	var inside := c.x - r >= 0 and c.y - r >= 0 and c.x + r < W and c.y + r < H
	if inside:
		_stamp_inside(v, sv, c, r, low, mine)
		return
	var w := W
	var h := H
	var mode := _fog_mode if mine and _fog_base.size() == w * h * 2 else 0
	# (the fog picture being cut is taken out of its member while it's written: see above)
	var fw: PackedByteArray = _EMPTY
	if mode == 1:
		fw = _fog_bld
		_fog_bld = _EMPTY
	elif mode == 2:
		fw = _fog_w
		_fog_w = _EMPTY
	var ex := explored
	explored = _EMPTY
	var sw := _swamp_any
	var swn := sw.size() == w * h
	var new_swamp := false
	# (by rows: each row of the disk is one run of cells, cut to the map; the cells right next
	# to the middle are the near ones, seen even up a cliff)
	var spans := _disk_rows(r)
	for si in range(0, spans.size(), 2):
		var dy := spans[si]
		var y := c.y + dy
		if y < 0 or y >= h:
			continue
		var hw := spans[si + 1]
		var row := y * w
		var near_row := dy >= -1 and dy <= 1
		for x in range(maxi(c.x - hw, 0), mini(c.x + hw, w - 1) + 1):
			var i := row + x
			if low and height[i] == 1 and not (near_row and x >= c.x - 1 and x <= c.x + 1):
				continue
			v[i] = 1
			sv[i] = 1
			if mine:
				if ex[i] == 0:
					ex[i] = 1
					if swn and sw[i] == 1:
						new_swamp = true
				if mode != 0:
					fw[i * 2 + 1] = 0
	explored = ex
	if new_swamp:
		_swamp_seen = true       # (swamp looked at for the first time: drawn under the fog from now on)
	if mode == 1:
		_fog_bld = fw
	elif mode == 2:
		_fog_w = fw


## The disk of radius r as rows: [dy, half width] pairs (each row of _disk(r) is one run
## of cells, -half width .. +half width).
var _disk_row_cache := {}


func _disk_rows(r: int) -> PackedInt32Array:
	if not _disk_row_cache.has(r):
		var hw := {}
		for o in _disk(r):
			hw[o.y] = maxi(int(hw.get(o.y, 0)), absi(o.x))
		var out := PackedInt32Array()
		for y in range(-r, r + 1):
			if hw.has(y):
				out.append(y)
				out.append(int(hw[y]))
		_disk_row_cache[r] = out
	return _disk_row_cache[r]


## _stamp for a disk that lies wholly inside the map: the same cells, as flat offsets from
## the middle cell (no x / y or bounds work per cell), the cells next to the middle apart
## from the far ones (only the far ones can be high ground hidden from low ground).
var _disk_flat := {}                     # r + W * 1000 -> [near offsets, far offsets]


func _stamp_inside(v: PackedByteArray, sv: PackedByteArray, c: Vector2i, r: int, low: bool, mine: bool) -> void:
	var key := r + W * 1000
	if not _disk_flat.has(key):
		var near := PackedInt32Array()
		var far := PackedInt32Array()
		for o in _disk(r):
			if o.length_squared() > 2:
				far.append(o.y * W + o.x)
			else:
				near.append(o.y * W + o.x)
		_disk_flat[key] = [near, far]
	var lists: Array = _disk_flat[key]
	var near_o: PackedInt32Array = lists[0]
	var far_o: PackedInt32Array = lists[1]
	var base := c.y * W + c.x
	if not mine:
		for o in near_o:
			v[base + o] = 1
			sv[base + o] = 1
		if low:
			for o in far_o:
				var i := base + o
				if height[i] != 1:
					v[i] = 1
					sv[i] = 1
		else:
			for o in far_o:
				v[base + o] = 1
				sv[base + o] = 1
		return
	var w := W
	var h := H
	var mode := _fog_mode if _fog_base.size() == w * h * 2 else 0
	# (the grids being written are taken out of their members meanwhile: see _reveal)
	var fw: PackedByteArray = _EMPTY
	if mode == 1:
		fw = _fog_bld
		_fog_bld = _EMPTY
	elif mode == 2:
		fw = _fog_w
		_fog_w = _EMPTY
	var ex := explored
	explored = _EMPTY
	var sw := _swamp_any
	var swn := sw.size() == w * h
	var new_swamp := false
	for pass_i in 2:
		var lst: PackedInt32Array = near_o if pass_i == 0 else far_o
		var check := low and pass_i == 1
		for o in lst:
			var i := base + o
			if check and height[i] == 1:
				continue
			v[i] = 1
			sv[i] = 1
			if ex[i] == 0:
				ex[i] = 1
				if swn and sw[i] == 1:
					new_swamp = true
			if mode != 0:
				fw[i * 2 + 1] = 0
	explored = ex
	if new_swamp:
		_swamp_seen = true       # (swamp looked at for the first time: drawn under the fog from now on)
	if mode == 1:
		_fog_bld = fw
	elif mode == 2:
		_fog_w = fw


## Your fog picture (LA8: alpha FOG_GREY where your side doesn't see now, 0 where it does).
## One grey only, as in StarCraft 2: the whole map's ground (cliffs, ramps, water, trees, rocks,
## the resource spots) is known from the start and shows under it; what an enemy has put there
## shows once seen (buildings, remembered as last seen) or only while seen (units). Kept up as
## it's seen instead of worked out cell by cell four times a second: _fog_base is the plain
## grey, _fog_bld that with what the buildings see cut out (made again when they change), _fog_w
## this update's (with what the units see cut out as they're stamped). Watching computers play,
## the picture is still worked out cell by cell (it's whose eyes the spectator picks).
const FOG_GREY := 140
var _fog_base := PackedByteArray()
var _fog_bld := PackedByteArray()
var _fog_w := PackedByteArray()
var _fog_shown := PackedByteArray()      # the picture last sent to fog_tex (the same again: not sent)
var _fog_mode := 0                       # what _stamp also cuts the seen cells out of: 1 _fog_bld, 2 _fog_w
var fog_base_dirty := true               # explored or whose side you are changed outside _stamp (a load, the sandbox)


func _rebuild_fog_base() -> void:
	fog_base_dirty = false
	var n := W * H
	var fb := PackedByteArray()
	fb.resize(n * 2)
	for i in n:
		fb[i * 2 + 1] = FOG_GREY
	_fog_base = fb
	_fog_bld = fb.duplicate()
	_bvis_key = PackedInt64Array()        # (the buildings' sight is cut out again)


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
	if _fog_base.size() == W * H * 2:
		_fog_bld = _fog_base.duplicate()
		_fog_mode = 1
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
	_fog_mode = 0


func _update_vis() -> void:
	var _z := Time.get_ticks_usec()
	var fast := not demo
	if fog_base_dirty:
		_swamp_seen = true                # (what was explored changed from outside: the swamp under the fog too)
		_unknown_dirty = true
	if fast and (fog_base_dirty or _fog_base.size() != W * H * 2):
		_rebuild_fog_base()
	elif not fast:
		_fog_base = PackedByteArray()
		fog_base_dirty = false
	_building_vis()
	Prof.add("game/fog/buildings", _z)
	_z = Time.get_ticks_usec()
	for t in n_players():
		vis[t] = (_bvis[t] as PackedByteArray).duplicate()
	for t in n_players():
		_side_vis[sides[t]] = (_bside[sides[t]] as PackedByteArray).duplicate()
	for sd in _side_vis.keys():
		if not _bside.has(sd):
			_side_vis.erase(sd)
	if fast:
		_fog_w = _fog_bld.duplicate()
		_fog_mode = 2
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
	_stamp_shot_reveals()
	_fog_mode = 0
	Prof.add("game/fog/units", _z)
	_z = Time.get_ticks_usec()
	# (the buildings' sight came in with _building_vis)
	# what your side sees (the explored map was marked as it was seen)
	var hv: PackedByteArray = (_side_vis[sides[human]] as PackedByteArray).duplicate()
	_human_vis = hv
	if demo or (net != null and not puppet):
		# enemy buildings stay on screen once spotted: remember who has spotted each one
		# (watching computers: for whose eyes the spectator picks; online, the host: what each
		# guest knows stands there, knows_building)
		for b in buildings:
			if not b.dead and not b.ghost:
				var bi := idx(cell_of(b.rect().get_center()))
				for t in n_players():
					if vis[t][bi] == 1 and (b.seen_mask & (1 << t)) == 0:
						b.seen_mask |= 1 << t
						_unknown_dirty = true
	_swamp_view()
	if sees_all():
		fog_sprite.visible = false
		for u in units:
			u.visible = not u.off_field
		for b in buildings:
			b.visible = true
		for c in crates:
			c.visible = true
		for k in kegs:
			k.visible = true
		if line_net and line_net.rails:
			for tr in line_net.rails.trains:
				if is_instance_valid(tr):
					tr.visible = true
		_show_waiting()
		return
	fog_sprite.visible = true
	# whose eyes: yours, or (watching computers) the player the spectator picked, with
	# everything their side sees, exactly as you'd see it on that side
	var ft := fog_team()
	if ft != human:
		hv = (_side_vis[sides[ft]] as PackedByteArray).duplicate()
	Prof.add("game/fog/copy", _z)
	_z = Time.get_ticks_usec()
	if fast and ft == human:
		if _fog_w != _fog_shown:
			_fog_shown = _fog_w
			fog_img.set_data(W, H, false, Image.FORMAT_LA8, _fog_w)
			fog_tex.update(fog_img)
	else:
		if _fog_bytes.size() != W * H * 2:
			_fog_bytes.resize(W * H * 2)
		for i in W * H:
			_fog_bytes[i * 2 + 1] = 0 if hv[i] == 1 else FOG_GREY
		fog_img.set_data(W, H, false, Image.FORMAT_LA8, _fog_bytes)
		fog_tex.update(fog_img)
		_fog_shown = PackedByteArray()
	Prof.add("game/fog/picture", _z)
	_z = Time.get_ticks_usec()
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
	for k in kegs:
		if not allied(k.team, ft):
			k.visible = hv[idx(cell_of(k.position))] == 1
		elif demo:
			k.visible = true
	if line_net and line_net.rails:
		for tr in line_net.rails.trains:
			if is_instance_valid(tr):
				tr.visible = allied(tr.team, ft) or hv[idx(cell_of(tr.global_position))] == 1     # (the Line's trains: like units)
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
					_unknown_dirty = true
			b.visible = b.seen_by_human
		elif demo:
			b.visible = true
	_show_waiting()
	Prof.add("game/fog/shown", _z)


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


## The ground the watching side has looked at at least once (yours; watching computers, the
## side of the player the spectator looks through), or empty when nothing is hidden. The ground
## itself is known from the start; this keeps what another side has put on ground you have
## never looked at out of sight under the grey (its swamp, a puff of smoke: what the old black
## fog hid there).
func _known_ground() -> PackedByteArray:
	if edit_mode or sees_all():
		return _EMPTY
	if demo:
		return explored_by[side_slot(fog_team())]
	return explored


## Has the watching side ever looked at the ground at p? (Effects and missiles where it never
## has stay hidden: Effect, Shot, Projectile...)
func ground_seen(p: Vector2) -> bool:
	var kg := _known_ground()
	return kg.size() != W * H or kg[idx(cell_of(p))] == 1


## A missile or effect from a to b that nobody on the watching side would see: both ends on
## ground it has never looked at.
func fx_hidden(a: Vector2, b: Vector2) -> bool:
	return not ground_seen(a) and not ground_seen(b)


## The swamp drawn under the fog (and on the minimap): another side's only where your side has
## looked (it would give its base away). Redrawn when whose eyes, or what they have seen of
## it, change.
var _swamp_any := PackedByteArray()      # every Brood swamp cell, whoever's (_update_swamp)
var _swamp_seen := false                 # swamp looked at for the first time since the last redraw
var _swamp_key := Vector3i(-9, -9, -9)


func _swamp_view() -> void:
	var key := Vector3i(fog_team(), int(sees_all()), human)
	if key != _swamp_key:
		_swamp_key = key
		_swamp_seen = true
	if _swamp_seen and swamp_layer:
		_swamp_seen = false
		swamp_layer.queue_redraw()
		swamp_layer_b.queue_redraw()
		_swamp_minimap()


## Every Brood swamp cell, whoever's (a lone Brood player's own grid, shared).
func _all_swamp() -> PackedByteArray:
	var any := PackedByteArray()
	for t in n_players():
		if faction_of(t) != "brood":
			continue
		if any.is_empty():
			any = swamp[t]
			continue
		var g: PackedByteArray = swamp[t]
		for i in W * H:
			if g[i] == 1:
				any[i] = 1
	return any


## Looping effects that started where the watching side had never looked (spawn_effect), and
## the walk-through decorations under a building it hasn't seen yet (_cover_decos): shown, or
## gone, once it does.
var _fx_hidden: Array = []
var _deco_wait := {}                     # Building -> the decorations it covers


func _show_waiting() -> void:
	for i in range(_fx_hidden.size() - 1, -1, -1):
		var e = _fx_hidden[i]
		if not is_instance_valid(e):
			_fx_hidden.remove_at(i)
		elif e.get_parent() != self or ground_seen(e.global_position):
			e.visible = true             # (seen now; or carried by a building, which shows or hides it)
			_fx_hidden.remove_at(i)
	if _deco_wait.is_empty():
		return
	for b in _deco_wait.keys():
		if not is_instance_valid(b) or b.dead:
			_deco_wait.erase(b)          # (gone before you saw it: the flowers were never trodden flat for you)
		elif b.visible or sees_all():
			for s in _deco_wait[b]:
				if is_instance_valid(s):
					s.visible = false
			_deco_wait.erase(b)


## A building going up over walk-through decorations hides them; where the watching side
## hasn't seen it, only once it does (flowers vanishing under the fog would give it away).
func _cover_decos(b: Building) -> void:
	if _deco_at.is_empty():
		return
	var list: Array = []
	var cells: Array = []
	for y in b.size.y:
		for x in b.size.x:
			cells.append(b.cell + Vector2i(x, y))
	for fc in Building.field_cells(b.kind):
		cells.append(b.cell + fc)
	for cc in cells:
		if in_map(cc) and _deco_at.has(idx(cc)):
			list.append_array(_deco_at[idx(cc)])
	if list.is_empty():
		return
	var ft := fog_team()
	if edit_mode or sees_all() or allied(b.team, ft) or is_visible_to(ft, b.center()):
		for s in list:
			s.visible = false
	else:
		_deco_wait[b] = list


## Does player t know this building stands there: its own side's, or one its side has seen
## (an enemy building, once seen, is remembered under the grey fog). Ghost sites of another
## side are never known.
func knows_building(t: int, b: Building) -> bool:
	if allied(b.team, t):
		return true
	if b.ghost:
		return false
	if t == human and not demo:
		return b.seen_by_human or reveal
	for o in n_players():
		if (b.seen_mask & (1 << o)) != 0 and allied(o, t):
			return true
	return false


## A player who plans by what it has seen (you, or an online guest; not a computer, nor
## anyone while the computers play or the fog is lifted): an enemy building it has never seen
## doesn't stop it ordering a building there; the worker finds the spot blocked when he gets
## there (try_start_site), as in StarCraft 2.
func _plans_by_sight(t: int) -> bool:
	if demo or reveal or t < 0:
		return false
	if t == human:
		return true
	if net != null and not puppet:
		for pr in net.peer_team:
			if int(net.peer_team[pr]) == t and not net.lost_peers.has(pr):
				return true            # (a guest's side; once it has left, a computer plays it)
	return false


## Per player: 1 on the cells taken by a building it doesn't know is there (knows_building).
## Worked out when asked, again after the ground or what is known changes.
var _unknown := {}
var _unknown_dirty := true


func _unknown_grid(t: int) -> PackedByteArray:
	if _unknown_dirty:
		_unknown_dirty = false
		_unknown.clear()
	if not _unknown.has(t):
		var g := PackedByteArray()
		g.resize(W * H)
		g.fill(0)
		for b in buildings:
			if b.dead or b.ghost or knows_building(t, b):
				continue
			for y in b.size.y:
				for x in b.size.x:
					var cc: Vector2i = b.cell + Vector2i(x, y)
					if in_map(cc):
						g[idx(cc)] = 1
			for fc in Building.field_cells(b.kind):
				var fcc: Vector2i = b.cell + fc
				if in_map(fcc):
					g[idx(fcc)] = 1
		_unknown[t] = g
	return _unknown[t]


## Open ground as far as player t knows: free, or taken only by an enemy building it has never
## seen (when it plans by sight).
func looks_free(t: int, c: Vector2i) -> bool:
	if not in_map(c):
		return false
	var v := solid[idx(c)]
	if v == 0:
		return true
	return v != 1 and _plans_by_sight(t) and _unknown_grid(t)[idx(c)] == 1


## A ranged unit on HIGH ground that fires at a target on LOW ground shows itself to the side
## shot at: a small spot of sight (SHOT_REVEAL_R cells) around the shooter only, for
## SHOT_REVEAL_T seconds after each shot. Goes through the normal vis grids, so the AI sees it too.
const SHOT_REVEAL_T := 2.0
const SHOT_REVEAL_R := 2
var _shot_reveals := {}                  # shooter id * 16 + victim team -> [shooter, until, victim team]


func note_shot(shooter: Unit, e: Entity) -> void:
	if shooter == null or e == null or e.team < 0 or shooter.team < 0 or allied(shooter.team, e.team):
		return
	var sc := cell_of(shooter.position)
	var tc := cell_of(e.position if e is Unit else e.center())
	if not in_map(sc) or not in_map(tc) or height[idx(sc)] != 1 or ramp[idx(sc)] != 0 or height[idx(tc)] != 0:
		return
	var key: int = shooter.get_instance_id() * 16 + e.team
	var fresh := not _shot_reveals.has(key)
	_shot_reveals[key] = [shooter, clock + SHOT_REVEAL_T, e.team]
	if fresh:
		_vis_t = 0.0     # show the shooter at the next tick


func _stamp_shot_reveals() -> void:
	for key in _shot_reveals.keys():
		var r: Array = _shot_reveals[key]
		var u = r[0]
		if not is_instance_valid(u) or u.dead or clock >= float(r[1]):
			_shot_reveals.erase(key)
			continue
		_reveal_air(int(r[2]), cell_of(u.position), SHOT_REVEAL_R)


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
var stun_layer: StunMark = null        # the stun marks (StunMark)
var bodies: Array = []                   # the fallen still lying there (Unit._rest_in_peace)
var _body_bar_t := 0.0


## Over every body still lying on the field, a thin bar: its health (Defs.ROT), running down faster the longer it lies,
## and with every blow it takes (for everyone, where they can see).
func _draw_body_bars() -> void:
	for b in bodies:
		if not is_instance_valid(b) or not b.visible or b.modulate.a < 0.99 or not view_rect.has_point(b.position):
			continue
		var f := clampf(b.body_left() / maxf(b.body_size(), 1.0), 0.0, 1.0)      # (its health: rot and damage)
		var w := clampf(12.0 * sqrt(b.body_size() / 70.0), 9.0, 20.0)      # (a little longer over a beefy body)
		var p: Vector2 = b.position + Vector2(-w * 0.5, -8.0 - maxf(float(b.radius), 8.0))      # (over a beefy body, higher)
		body_bars.draw_rect(Rect2(p, Vector2(w, 2.0)).grow(0.5), Color(0, 0, 0, 0.5))
		body_bars.draw_rect(Rect2(p, Vector2(w * f, 2.0)), Color(0.88, 0.84, 0.72, 0.8))


var view_rect := Rect2()                 # what the camera sees (a bit bigger), for culling


# ------------------------------------------------------------------ black powder smoke (looks only)

var powder_smoke: PowderSmoke = null


## A black powder shot's smoke (PowderSmoke.KINDS: musket, cannon, canister, mortar, shell, keg,
## wagon) at p, pushed along dir. Looks only: no random numbers of the game's, nothing read back.
## Online the guests, and the replay, get it as an effect "powder:<kind>" (its speed field: the
## direction's angle, or 9 for none; a version without it drops the unknown effect).
func powder(kind: String, p: Vector2, dir := Vector2.ZERO) -> void:
	if not puppet:
		var f := ["e", "powder:" + kind, p, dir.angle() if dir != Vector2.ZERO else 9.0]
		# (shots and blows first: the smoke takes only what room is left in a snapshot's effects)
		if net != null and net.fx.size() < NetSession.FX_MAX - 15:
			net.fx.append(f)
		if rec != null and rec.fx.size() < NetSession.FX_MAX - 15:
			rec.fx.append(f)
	if powder_smoke != null:
		powder_smoke.puff(kind, p, dir)


## Guest / replay: a powder effect from the host's list (powder above).
func powder_fx(name: String, p: Vector2, a: float) -> void:
	if powder_smoke != null:
		powder_smoke.puff(name.trim_prefix("powder:"), p, Vector2.ZERO if a > 8.0 else Vector2.from_angle(a))


## Does this unit fire black powder (its musket, the cavalry's pistol, a gun, a mortar)?
func powder_gun(u: Unit) -> bool:
	return u.mode == "pistol" or u.kind in ["musketeer", "cannon", "mortar", "balloon"]


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


var cw_gates: Array = []                 # Plate Wagons (blocking the track against the enemy's ground units)
var cw_storms: Array = []                # Storm Engine storms in the field
var cw_fx: Node2D = null
var cw_consists: Array = []              # coupled rail trains (scripts/cw_consist.gd)
var cw_cons_next := 1
var cw_links: Node2D = null              # draws the steel links between coupled cars
var cw_bump_t := 0.0


## The world rect the camera shows, plus a margin: what gets drawn (gear rings, effects... skip what's outside it). The
## game's tick keeps it current; the HUD calls it too while the 3-2-1 countdown holds the game paused.
func update_view_rect() -> void:
	var vsz := get_viewport().get_visible_rect().size / camera.zoom
	view_rect = Rect2(camera.get_screen_center_position() - vsz * 0.5, vsz).grow(120.0)


## The path queue's time limit in a tick, past its first 6 paths (µs). A tool that needs a match to
## play out the same every time lifts it (tools/perf_bench.gd): then only the count, 24 a tick, limits it.
var path_budget_us := 6000
var anim_steps := 0              # (the units that stepped their pictures this tick: Unit._animate)
var anim_crowd := false


func _tick_game(delta: float) -> void:
	# (a big battle on screen: the units step their pictures 10 times a second instead of 15, Unit._animate; it
	# changes only what is drawn. On over about 160 units in view, off under about 110.)
	anim_crowd = anim_steps > (55 if anim_crowd else 80)
	anim_steps = 0
	if over or edit_mode:
		return
	if Defs.cw_roster:
		CwUnits.tick_game(self, delta)
	if puppet:
		return NetPuppet.tick_game(self, delta)
	clock += delta
	alert_t = maxf(alert_t - delta, 0.0)
	_body_bar_t -= delta
	if _body_bar_t <= 0.0 and body_bars:
		_body_bar_t = 0.2
		bodies = bodies.filter(func(b) -> bool: return is_instance_valid(b) and b.dead)
		body_bars.queue_redraw()
		for t in n_players():
			income_rates(t)            # (keeps each side's income log going)
	update_view_rect()
	_economy(delta)
	line_net.tick(delta)
	gear_net.tick(delta)
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
	# (at most 24 a tick, and past the first 6 only while under 6 ms: a crowd ordered at once
	# gets its paths over a few ticks instead of in one long frame)
	var budget := 24
	while budget > 0 and not _path_queue.is_empty() and (budget > 18 or Time.get_ticks_usec() - pt < path_budget_us):
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
	# the overlay: every tick while something on it moves, else (the economy labels) 4 times a second
	_overlay_t -= delta
	if _overlay_t <= 0.0 or _overlay_moving() or view_rect.position.distance_to(_overlay_view) > 60.0:
		_overlay_t = 0.25
		_overlay_view = view_rect.position
		overlay.queue_redraw()
	field_layer.queue_redraw()
	_end_t -= delta
	if _end_t <= 0.0:
		_end_t = 1.0
		_check_end()
		sweep_ghosts()
		_ghost_t = 0.2
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = 0.2
		sweep_ghosts(true)       # (between the full sweeps: orphaned ghosts go at once)
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
		if BroodNew.on(self, t):
			alive[t] = 1 if BroodNew.queen(self, t) != null else 0     # (the new Brood: it lives while its Mother does)
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
	var human_out: bool = not demo and eliminated[human] and (net == null or net.humans_out())     # (online: while a friend still plays, the match goes on)
	if sides_left.size() <= 1 or human_out:
		over = true
		winner = -1
		for t in sides_left.values():
			if winner < 0 or (human_out and not allied(t, human)):
				winner = t
		ended.emit(winner)


# ------------------------------------------------------------------ selection & commands (used by input and HUD)

## Which voice answers a pick: a Crown army of two or more kinds of fighting men (musketeers,
## cannons, pikes ...) answers with the marching column ("crown_army"); one kind answers with its own.
func _select_voice_kind(list: Array, first: Unit) -> String:
	var kinds := {}
	for e in list:
		if is_instance_valid(e) and e is Unit and e.team == human and not e.dead and not e.is_worker():
			kinds[e.kind] = true
	if kinds.size() >= 2:
		var crown := true
		for k in kinds:
			if String(Defs.UNITS[k].get("faction", "")) != "crown":
				crown = false
		if crown:
			return "crown_army"
	return first.kind


func set_selection(list: Array) -> void:
	if Defs.cw_roster and not cw_consists.is_empty():
		list = CwConsist.expand_selection(list)          # tapping one coupled car selects the whole train
	# a unit or building you pick answers you (once per new pick)
	for e in list:
		if is_instance_valid(e) and (e is Unit or e is Building) and e.team == human and not e.dead and not selection.has(e):
			if e is Building:
				Sfx.building_selected(e.kind, e.d["faction"])
			else:
				Sfx.voice(_select_voice_kind(list, e), "select")
			break
	for e in selection:
		if is_instance_valid(e):
			e.selected = false
	selection = []
	for e in list:
		if e is Unit and is_instance_valid(e) and (e as Unit).crew_of != null and is_instance_valid((e as Unit).crew_of):
			e = (e as Unit).crew_of      # (a Spring Ballista's crewman is part of it: picking him picks the machine)
		if is_instance_valid(e) and not e.dead and not e.off_field and not selection.has(e):
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


## Own buildings of mixed kinds selected together (a Barracks with an Armoury...): the list, else [].
## (One kind alone is selected_buildings; a mix gets one merged command card.)
func selected_mixed() -> Array:
	if selection.size() < 2:
		return []
	var me := controlled_team()
	var kinds := {}
	for e in selection:
		if not is_instance_valid(e) or not (e is Building) or e.team != me or e.dead:
			return []
		kinds[e.kind] = true
	return selection.duplicate() if kinds.size() > 1 else []


## Every finished building of a team that trains fighting units.
func producers(t: int) -> Array:
	return buildings.filter(func(b: Building) -> bool:
		return b.team == t and not b.dead and b.built and (b.d["trains"] as Array).any(func(k: String) -> bool: return not Defs.UNITS[k].get("worker", false)))


## The buildings a rally order goes to: the selected ones of one kind, or a MAKE selection.
func rally_buildings() -> Array:
	var bs := selected_buildings()
	if bs.is_empty():
		bs = selected_producers()
	if bs.is_empty():
		# a mixed selection (Barracks + Armoury ...): the ones that train
		bs = selected_mixed().filter(func(x: Building) -> bool: return x.built and not (x.d["trains"] as Array).is_empty())
	return bs


## Train at the least busy of several buildings (or the only one).
func train_any(list: Array, k: String) -> String:
	if net_forward(self, "train_any", [list, k]): return ""
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
	if net_forward(self, "abandon", [b]): return
	if b.built or b.dead:
		return
	if b.ghost:
		# it never began: all of it comes back (its Tension too)
		players[b.team]["gold"] += int(b.d["cost"])
		add_tension(b.team, float(Defs.tension_cost(b.d)))
		stats[b.team]["spent"] -= int(b.d["cost"])
		stats[b.team]["built"] = maxi(0, int(stats[b.team]["built"]) - 1)
		remove_ghost(b)
		for u in units.duplicate():
			if u.team == b.team and not u.dead and u.order == "build" and u.order_target == b:
				u.site_gone()
		return
	players[b.team]["gold"] += int(int(b.d["cost"]) * 0.75)
	add_tension(b.team, float(int(Defs.tension_cost(b.d) * 0.75)))      # (a begun building: three quarters, like the cogs)
	b.take_damage(9999999.0, null)
	if b.crate_obj and is_instance_valid(b.crate_obj):
		b.crate_obj.remove()            # (a Clockwork crate waiting for this site goes too)


## Would a building of kind k at cell c take the spot the computer keeps for a `kk` (ai_keep): its footprint on the kept
## one (a tile of margin), or its gear ring cutting into the kept ring?
func _takes_kept(t: int, k: String, c: Vector2i, kk: String) -> bool:
	var keep: Dictionary = ai_keep[t][kk]
	var kc: Vector2i = keep["cell"]
	var ks: Vector2i = Defs.BUILDINGS[kk]["size"]
	var sz: Vector2i = Defs.BUILDINGS[k]["size"]
	if Rect2i(kc, ks).grow(1).intersects(Rect2i(c, sz)):
		return true
	if Defs.gear_mode and String(Defs.BUILDINGS[k]["faction"]) == "clockwork" and String(Defs.BUILDINGS[kk]["faction"]) == "clockwork":
		var ga := GearNet.gpos(Vector2(c) * T + Vector2(sz) * T * 0.5)
		var gb := GearNet.gpos(Vector2(kc) * T + Vector2(ks) * T * 0.5)
		if ga.distance_to(gb) - GearNet.ring_r(k, sz, false) - GearNet.ring_r(kk, ks, false) < -float(Defs.GEAR["overlap"]) * T:
			return true
	return false


## Pull down a finished building of your own (nothing comes back).
## GEAR SWAP (Clockwork, gear mode): a building's connecting gear changes between SMALL and BIG. Costs Defs.GEAR.swap_cost
## cogs, takes Defs.GEAR.swap_time seconds; the building idles meanwhile and its ring visibly changes size. Returns "" or
## why it can't be done (the card's tooltip).
func gear_swap_problem(b: Building) -> String:
	if not Defs.gear_mode or b.d["faction"] != "clockwork" or b.kind == "clocktower":
		return "Only a Clockwork building's connecting gear can be swapped (not the Clocktower's)."
	if not b.built or b.dead:
		return "Wait until it is built."
	if b.gear_swap_t >= 0.0:
		return "Its gear is already being swapped."
	if GearNet.big_only(b.kind):
		return "The %s runs only on its big gear: the heavy torque." % String(b.d["name"])
	var pw := Pendulum.swap_problem(b)       # (a Pendulum in its queue keeps the Works on the big gear)
	if pw != "":
		return pw
	if int(players[b.team]["gold"]) < int(Defs.GEAR["swap_cost"]):
		return "Not enough %s." % String(Defs.FACTIONS[faction_of(b.team)]["res"][0]).to_lower()
	return ""


## THE GEAR VIEW (owner, 2026-10-27; the ` key, or GEAR VIEW on a Clockwork building's card): the whole gear network at a
## glance (GearNet._draw_view). A view only: nothing in the match changes, nothing is sent online.
func toggle_gear_view() -> void:
	gear_net.view = not gear_net.view
	gear_net.queue_redraw()
	if hud != null:
		hud.toast("GEAR VIEW: green full speed, yellow 90%, orange 80%, red 70% or idle." if gear_net.view else "Gear view off.")


func swap_gear(b: Building) -> String:
	if net_forward(self, "swap_gear", [b]): return ""
	var why := gear_swap_problem(b)
	if why != "":
		return why
	players[b.team]["gold"] = int(players[b.team]["gold"]) - int(Defs.GEAR["swap_cost"])
	stats[b.team]["spent"] += int(Defs.GEAR["swap_cost"])
	b.gear_swap_to = not b.gear_big
	b.gear_swap_t = float(Defs.GEAR["swap_time"])
	Sfx.play_any(["ui/click", "click"], b.center())
	return ""


func demolish(b: Building) -> void:
	if net_forward(self, "demolish", [b]): return
	if b.dead:
		return
	b.take_damage(9999999.0, null)


## Tap/right-click on the map with units selected: do the obvious thing.
## queued (Shift on a computer): after the orders they already have, not instead of them.
func smart_command(list: Array, p: Vector2, force_move := false, queued := false) -> void:
	p = on_map(p)
	if net_forward(self, "smart_command", [list, p, force_move, queued]): return
	# (a horse takes no orders: only a leash or a rider moves it)
	var us: Array = list.filter(func(e: Entity) -> bool: return e is Unit and not e.dead and e.kind != "horse")
	# THE NEW BROOD: a rooted creature is a building and an egg stands where it lies: a right-click sets their RALLY POINT
	# (it never uproots: only the UPROOT button does, the owner 19:19; scripts/brood_root.gd)
	var fixed: Array = us.filter(func(u: Unit) -> bool: return BroodRoot.fixed(u))
	if not fixed.is_empty():
		for u in fixed:
			BroodRoot.set_rally(u, p)
			u.queue_redraw()
		us = us.filter(func(u: Unit) -> bool: return not BroodRoot.fixed(u))
		if us.is_empty():
			_ping(p, Color(0.4, 1.0, 0.4))
			return
	if not us.is_empty() and us[0].team == human:
		var tgt := entity_at(p)
		var atk: bool = tgt != null and hostile(tgt.team, human) and not force_move
		command_sound(us, "attack" if atk else "move", "charge" if atk else "move")
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
	if not force_move and not (e is Unit):
		var kg := keg_at(p)
		if kg and hostile(kg.team, us[0].team):
			e = kg             # (an enemy powder keg on the ground: attack it, it blows up)
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
	if e is Unit and Unit.carrier(e.kind) and e.team == us[0].team and us.any(func(u: Unit) -> bool: return u.can_board(e)):
		load_order(us, [e])
		_ping(p, Color(0.4, 1, 0.4))
		return
	if e is Building and e.team == us[0].team and e.built and Defs.crew_cap(e.d) > 0 \
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


## Online guest: the ring and the answer smart_command gives, worked out on this screen at the click (the host runs
## the order itself a round trip later); plain walks start at once here (NetSession.lead). Keep in step with
## smart_command: _smart_choice follows its branches without doing anything.
func smart_feedback(list: Array, p: Vector2, force_move: bool) -> void:
	p = on_map(p)
	var us: Array = list.filter(func(e) -> bool: return e is Unit and is_instance_valid(e) and not e.dead and e.kind != "horse")
	if us.is_empty() or us[0].team != human:
		return
	var tgt := entity_at(p)
	var atk: bool = tgt != null and hostile(tgt.team, human) and not force_move
	command_sound(us, "attack" if atk else "move", "charge" if atk else "move")
	var ch := _smart_choice(us, p, force_move)
	_ping(p, ch[0])
	if net != null and (ch[1] == "move" or ch[1] == "amove"):
		net.lead(us, p, ch[1] == "amove")


## What smart_command would do with these units for a click at p: [ring colour, "move" / "amove" / "other"].
func _smart_choice(us: Array, p: Vector2, force_move: bool) -> Array:
	var yellow := Color(1, 0.85, 0.3)
	var e := null if force_move else entity_at(p)
	var cr: Crate = null
	if not force_move and not (e is Unit):
		cr = crate_at(p)
	if cr and cr.team == us[0].team and us.any(func(u: Unit) -> bool: return u.kind == "winder"):
		return [yellow, "other"]
	if cr and hostile(cr.team, us[0].team):
		e = cr
	if not force_move and not (e is Unit):
		var kg := keg_at(p)
		if kg and hostile(kg.team, us[0].team):
			e = kg             # (an enemy powder keg on the ground: attack it, it blows up)
	if e is Unit and e.team == us[0].team and us.any(func(u: Unit) -> bool: return u.can_gather()) \
			and not (e.hp < e.max_hp and us.any(func(u: Unit) -> bool: return u.can_repair(e))):
		var site := crew_site_at(p, us[0].team)
		if site:
			e = site
	if e != null and (e.team == us[0].team or loose_horse(e)):
		if e is Unit and e.kind == "horse" and us.any(func(u: Unit) -> bool: return u.can_mount() or u.can_lead()):
			return [Color(0.9, 0.8, 0.5), "other"]
		if e is Unit and Defs.HARNESSED.has(e.kind) and e.team_room() and us.any(func(u: Unit) -> bool: return not u.led.is_empty()):
			return [Color(0.9, 0.8, 0.5), "other"]
	if e is Unit and Unit.carrier(e.kind) and e.team == us[0].team and us.any(func(u: Unit) -> bool: return u.can_board(e)):
		return [Color(0.4, 1, 0.4), "other"]
	if e is Building and e.team == us[0].team and e.built and Defs.crew_cap(e.d) > 0 \
			and us.any(func(u: Unit) -> bool: return u.can_gather()):
		return [yellow, "other"]
	if e and e.team == us[0].team and e.hp < e.max_hp and (e.is_unit() or e.built) \
			and us.any(func(u: Unit) -> bool: return u.can_repair(e)):
		return [Color(0.95, 0.7, 0.25), "other"]
	if e is Building and e.team == us[0].team and not e.built:
		return [yellow, "other"]
	if e and prey(us[0].team, e):
		return [Color(1, 0.3, 0.3), "other"]
	var amove := not force_move and not Settings.pc()
	return [Color(1, 0.3, 0.3) if amove else Color(0.4, 1, 0.4), "amove" if amove else "move"]


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
	# the same alarm for every faction and every kind of attack, then (once it has rung) the faction's voice says what;
	# the Clockwork's alarm is an alarm clock ringing (its own base: another ring; tools/audio/make_clockwork_sounds.py)
	if fac == "clockwork":
		Sfx.play_any((["clock/base_alert"] if e is Building and e.team == human else []) + ["clock/alert", "ui/alert_all"])
	else:
		Sfx.play_any(["ui/alert_all"])
	var line := "under_attack"
	var gap := 20.0
	var text := "Your forces are under attack!"
	if e.team != human:
		# an ally's men or buildings (allies_hit: only when no fight of ours is on screen)
		line = "ally_attack"
		gap = 25.0
		text = "Our allies are under attack!"
	elif e is Building:
		line = "base_attack"
		gap = 15.0
		text = "Your base is under attack!"
	elif e is Unit and (e as Unit).kind == BroodNew.QUEEN:
		line = "base_attack"          # (the new Brood: she is its base, and its losing condition)
		gap = 15.0
		text = "Your Brood Mother is under attack!"
	elif e is Unit and (e as Unit)._k_nb and BroodNew.ROOTERS.has((e as Unit).kind) and (e as Unit).tesla_mode != "packed":
		line = "base_attack"          # (a rooted creature is the new Brood's building: it says so)
		gap = 15.0
		text = "Your rooted creatures are under attack!"
	elif e is Unit and (e as Unit).is_worker():
		line = "workers_attack"
		text = "Your workers are under attack!"
	notify(text, true)
	await get_tree().create_timer(3.1).timeout
	if is_inside_tree():
		Sfx.announce(fac, line, gap)


## Where each unit of a group goes for a move to p (the bunch-up rule of group_move): a group
## already together keeps its shape, one spread out closes in to a blob about its size round p.
## A man whose spot lands where he can't stand, or where he'd have to walk the long way round to
## from p (over a cliff edge, behind a wall or a building, in a wood), gets the nearest free spot
## round p on p's side instead: the group spreads out on the ground where it was sent (it used to
## pile up on p itself, pressed against the cliff when p was near the edge).
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
	var blob := 8.0 * sqrt(float(n)) + 4.0            # the radius a bunched group takes (shoulder to shoulder)
	var k := 1.0 if spread <= blob * 1.5 else blob / spread
	if n == 1:
		out[us[0]] = p
		return out
	var team: int = us[0].team
	var start := cell_of(p)
	if not passable(start, team):
		start = nearest_free_level(start, 4)
		p = cell_center(start)
	# the cells round p by how far a man walks to them from p (4-way, as the pathfinder goes)
	var fill := _walk_fill(start, team, maxi(n * 3, 24), 10)
	var used := {}
	var bad: Array = []
	for u in us:
		var sp: Vector2 = p + ((from[u] as Vector2) - c) * k
		var sc := cell_of(sp)
		var ok: bool = fill.has(sc) and open_cell(sc) and float(fill[sc]) <= sp.distance_to(p) / T * 1.5 + 1.5 and line_clear(p, sp)
		if ok:
			out[u] = sp
			used[sc] = int(used.get(sc, 0)) + 1
		else:
			out[u] = p
			bad.append(u)
	if bad.is_empty() or fill.is_empty():
		return out
	# the others: the free cell of the fill nearest to where each wanted to be (a small man shares
	# a cell with one more, a big one has it to himself), close to p first
	var cells: Array = fill.keys()
	used[start] = int(used.get(start, 0)) + 1           # (p itself: someone stands on it)
	for u in bad:
		var want: Vector2 = p + ((from[u] as Vector2) - c) * k
		var cap := 2 if float(u.radius) <= 12.0 else 1
		var best := Vector2i(-1, -1)
		var bd := INF
		for cc: Vector2i in cells:
			if int(used.get(cc, 0)) >= cap or not open_cell(cc):
				continue                                  # (full, or a gate: nobody stands in a gateway)
			var dd := cell_center(cc).distance_to(want) + float(fill[cc]) * T * 0.75
			if dd < bd:
				bd = dd
				best = cc
		if best.x < 0:
			continue                                      # (no room left: he goes to p)
		var nth := int(used.get(best, 0))
		used[best] = nth + 1
		# (two in a cell: a little to either side of its middle)
		out[u] = cell_center(best) + (Vector2(-7, -5) if nth == 0 and cap > 1 else (Vector2(7, 5) if nth == 1 else Vector2.ZERO))
	return out


## The cells a unit of `team` can walk to from `start` (4-way, through open ground, crop rows and
## its own side's gates), with how many steps away each is: the nearest `limit` cells, no further
## than `max_steps`.
func _walk_fill(start: Vector2i, team: int, limit: int, max_steps: int) -> Dictionary:
	var out := {}
	if not passable(start, team):
		return out
	out[start] = 0
	var q: Array = [start]
	var qi := 0
	while qi < q.size() and out.size() < limit:
		var cc: Vector2i = q[qi]
		qi += 1
		var st: int = out[cc]
		if st >= max_steps:
			continue
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cc + dv
			if out.has(nb) or not passable(nb, team) or (not rails.is_empty() and rail_cut(cc, nb)):
				continue
			out[nb] = st + 1
			q.append(nb)
			if out.size() >= limit:
				break
	return out


## The sound of an order, one thing speaks (StarCraft style): one kind of unit answers with its own
## voice (the Crown's bugle only now and then, for the calls that mean something: attack, patrol);
## a mixed Crown group is answered by the bugle alone; whatever has no voice falls back to the bugle.
func command_sound(us: Array, what: String, call: String) -> void:
	if us.is_empty() or net_cmd_team >= 0 or net_quiet:
		return
	var kinds := {}
	for u in us:
		if u is Unit and not u.is_worker():
			kinds[u.kind] = true
	var crown := faction_of(human) == "crown"
	if crown and kinds.size() >= 2:
		Sfx.bugle("crown", call)
		return
	Sfx.voice(us[0].kind, what)
	if crown and call != "move" and randf() < 0.4:
		Sfx.bugle("crown", call)


func group_move(us: Array, p: Vector2, attack_move: bool, queued := false) -> void:
	p = on_map(p)
	if net_forward(self, "group_move", [us, p, attack_move, queued]): return
	us = us.filter(func(u) -> bool: return not (u is Unit and u.kind == "horse"))
	if us.is_empty():
		return
	if not us.is_empty() and us[0].team == human:
		command_sound(us, "attack" if attack_move else "move", "amove" if attack_move else "move")
	# No pre-made formation (StarCraft / Beyond All Reason style): a group already together
	# keeps its shape and moves as one blob; a group spread out bunches up into a clump at
	# the point (each man keeps his side of it, closed in to a blob about its size).
	# (queued: from where their queues end)
	var spots := group_points(us, p, queued)
	for u in us:
		u.give({"o": "amove" if attack_move and u.fights_on_command() else "move", "p": spots[u]}, queued)
	_ping(p, Color(1, 0.3, 0.3) if attack_move else Color(0.4, 1, 0.4))


var _pings: Array = []


## A ring where an order was given (it fades in half a second). Only the player who gave the order sees it: a guest's
## order run on the host makes none here (the guest drew its own at the click: NetCommands.feedback).
func _ping(p: Vector2, col: Color) -> void:
	if net_cmd_team >= 0 or net_quiet:
		return
	_pings.append([p, col, 0.5])


func command_all(list: Array, what: String) -> void:
	if net_forward(self, "command_all", [list, what]): return
	var belled := false
	for u in list:
		if u is Unit and not u.dead and u.kind != "horse":
			u.patrol_a = Vector2.INF
			if u.team == human and not belled:
				belled = true
				Sfx.bugle(faction_of(human), what)
			if what == "stop":
				u.cmd_stop()
			elif what == "hold":
				u.cmd_hold()


## which: "auto" (a Hive sends workers to a tapped mine, the army anywhere else),
## "army" or "worker".
func set_rally(b: Building, p: Vector2, which := "auto") -> void:
	p = on_map(p)
	if net_forward(self, "set_rally", [b, p, which]): return
	var e := entity_at(p)
	if b.dual_rally():
		var site: bool = e is Building and e.team == b.team and Defs.crew_cap(e.d) > 0
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
	b.rally_target = e if e is Building and e.team == b.team and Defs.crew_cap(e.d) > 0 else null
	if e is Unit and e.team == b.team and not e.dead and e.kind != "horse":
		b.rally_target = e        # (a unit of ours: the rally follows it, new ones follow it)


func army(t: int) -> Array:
	# (a plain loop: the same units in the same order as a filter with a lambda, at about half
	# the cost; the computer players ask for it dozens of times a second)
	var out: Array = []
	for u in units:
		if u.team == t and not u.dead and not u.is_worker() and u.aboard == null and u.kind != "horse" and u.kind != "messenger":
			out.append(u)
	return out


## A player's horses (bred, released, stolen; not the ones under riders or hitched to guns).
func horses_of(t: int) -> Array:
	var out: Array = []
	for u in units:
		if u.team == t and not u.dead and u.kind == "horse":
			out.append(u)
	return out


## "Horses: 3 (1 reserved)" for the top bar and the breeder's card (reserved: kept for a recruit
## or a gun, or taken to its building and hitched there).
func horses_text(t: int) -> String:
	var hs := horses_of(t)
	var r := hs.filter(func(h: Unit) -> bool: return h.horse_rid != 0 or h.into is Building).size()
	return "Horses: %d%s" % [hs.size(), (" (%d reserved)" % r) if r > 0 else ""]


func labourers(t: int) -> Array:
	return workers(t)


## Workers not tied to a Town Hall (the haulers are counted by their hall: Building.haulers).
func workers(t: int) -> Array:
	var out: Array = []
	for u in units:
		if u.team == t and not u.dead and u.is_worker() and u.aboard == null and u.crew_of == null and not u.is_hauler():
			out.append(u)
	return out


func center_of_team(t: int) -> Vector2:
	if BroodNew.on(self, t) and BroodNew.queen(self, t) != null:
		return BroodNew.queen(self, t).position      # (the new Brood: where its Mother is)
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


# ------------------------------------------------------------------ standing (surrender, resign, chat)

## What a soldier is worth in an army tally: its cost per unit made (a pair counts once each).
static func unit_value(u: Unit) -> int:
	return int(u.d["cost"]) / maxi(1, int(u.d.get("spawn", 1)))


## The value of everything a player has that is not a worker (the match log's "army value").
func army_value(t: int) -> int:
	var v := 0
	for u in units:
		if u.team == t and not u.dead and not u.is_worker():
			v += unit_value(u)
	return v


func worker_count(t: int) -> int:
	var n := 0
	for u in units:
		if u.team == t and not u.dead and u.is_worker():
			n += 1
	return n


## Finished buildings standing (walls and gates do not count).
func building_count(t: int) -> int:
	var n := 0
	for b in buildings:
		if b.team == t and not b.dead and not b.ghost and b.built and not Defs.BUILDINGS[b.kind].get("line", false):
			n += 1
	return n


## A player's army, workers and buildings as a dictionary (the truth, for the log).
func standing(t: int) -> Dictionary:
	return {"army": army_value(t), "workers": worker_count(t), "buildings": building_count(t)}


## `t` against every enemy still in the game, summed: {me: standing, foe: standing}.
func standing_vs(t: int) -> Dictionary:
	var foe := {"army": 0, "workers": 0, "buildings": 0}
	for o in n_players():
		if hostile(o, t) and not eliminated[o]:
			var s := standing(o)
			for k in foe:
				foe[k] += int(s[k])
	return {"me": standing(t), "foe": foe}


## One number for how strong a position is (for "ahead / behind" in the log only).
static func power(s: Dictionary) -> int:
	return int(s["army"]) + 50 * int(s["workers"]) + 30 * int(s["buildings"])


## "ahead", "behind" or "about even" (within 10%) for `t` against its enemies.
func lead_of(t: int) -> String:
	var sv := standing_vs(t)
	var a := float(power(sv["me"]))
	var b := float(power(sv["foe"]))
	if a > b * 1.1:
		return "ahead"
	if a < b * 0.9:
		return "behind"
	return "about even"


## "army 250 vs 0, workers 6 vs 7, buildings 4 vs 11" (t first).
func standing_text(t: int) -> String:
	var sv := standing_vs(t)
	var m: Dictionary = sv["me"]
	var f: Dictionary = sv["foe"]
	return "army %d vs %d, workers %d vs %d, buildings %d vs %d" % [m["army"], f["army"], m["workers"], f["workers"], m["buildings"], f["buildings"]]


## The player gives up (the menu's SURRENDER): every building falls, the log says who was ahead. Online the host
## runs it for a guest too (`team`: the side that gives up; the guest's log says it at the press).
func player_surrender(team := -1) -> void:
	if team < 0:
		team = human
	if puppet and net != null:
		_note_surrender(team)
	if net_forward(self, "player_surrender", [team]): return
	_note_surrender(team)
	for b in buildings.duplicate():
		if b.team == team:
			b.take_damage(99999, null)


func _note_surrender(team: int) -> void:
	var ahead := lead_of(team)
	# (it ends the match unless an ally of theirs plays on: co-op, a friend still in)
	var ends := true
	for o in n_players():
		if o != team and allied(o, team) and not eliminated[o]:
			ends = false
	if ends:
		end_ahead = ahead
		end_note = "player_surrender"
		end_quitter = team
	if mlog:
		mlog.add("%s surrendered while %s (%s)" % [mlog.who(team), ahead, standing_text(team)])


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


## Over your economy buildings: the workers' job word and count ("HAULERS 2/4", "FARMERS 3/8"; the Town Hall's is
## assigned / needed), and the efficiency bar with its % (see Building.efficiency): one compact strip, readable on a
## phone; the new Brood's Rootmaws and food piles too. Resting the mouse on one (a long press on a phone) explains it:
## scripts/worker_labels.gd.
func _draw_mine_labels() -> void:
	var font := ThemeDB.fallback_font
	WorkerLabels.draw_all(self, font)
	if exp_spots:
		exp_spots.draw_labels(overlay)          # ("OPTIMAL EXPANSION SPOT" / "EXPANSION SPOT" on the gold spots)
	for fl in _floats:
		var a: float = minf(float(fl[3]), 1.0)
		var w2: float = font.get_string_size(fl[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		overlay.draw_string_outline(font, fl[0] - Vector2(w2 * 0.5, 0), fl[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, a * 0.8))
		overlay.draw_string(font, fl[0] - Vector2(w2 * 0.5, 0), fl[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(fl[2], a))


## Shift-queued orders of your selected units: a faint line from each unit through its
## waypoints, with a small marker at each (green move, red attack, yellow build / work).
const QUEUE_COLS := {"move": Color(0.4, 1.0, 0.4), "amove": Color(1.0, 0.35, 0.3), "attack": Color(1.0, 0.35, 0.3),
	"build": Color(1.0, 0.85, 0.3), "repair": Color(1.0, 0.85, 0.3), "gather": Color(1.0, 0.85, 0.3), "bombard": Color(1.0, 0.55, 0.2)}


func _draw_queues() -> void:
	var me := controlled_team()
	if me < 0:
		return
	for e in selection:
		if not (e is Unit) or not is_instance_valid(e) or e.dead or e.team != me:
			continue
		var u := e as Unit
		if u.patrol_a != Vector2.INF:
			_draw_patrol(u.patrol_a, u.patrol_b, u.global_position)
		if u.order == "bombard":
			if u.gnd_a != Vector2.INF and u.gnd_a.distance_to(u.gnd_b) >= 1.0:
				_draw_ground_stretch(u.gnd_a, u.gnd_b)
			_draw_bombard_spot(u.order_point, u.global_position)
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


const PATROL_COL := Color(0.45, 0.85, 1.0)
const BOMBARD_COL := Color(1.0, 0.55, 0.2)


## An ATTACK GROUND line being dragged (Ctrl+A, then a held left-drag), in the style of the formation preview: the line,
## faint, and each unit's own stretch of it in turn darker and lighter, with a tick between them and a dot where its
## middle is (the order's spot). Short of the drag length it is still a click.
func _draw_ground_line(pts: PackedVector2Array) -> void:
	var n := selected_units().filter(func(u: Unit) -> bool: return u.can_ground_attack()).size()
	var long := Game._poly_len(pts) > 40.0
	overlay.draw_polyline(pts, Color(0, 0, 0, 0.45), 4.0)
	overlay.draw_polyline(pts, Color(BOMBARD_COL, 0.55 if long else 0.3), 2.0)
	if n <= 0 or not long:
		return
	var lane := float(Defs.GROUND["lane"]) * Defs.TILE
	var i := 0
	for st in line_stretches(pts, n):
		var a: Vector2 = st[0]
		var b: Vector2 = st[1]
		var dv := (b - a).normalized() if a.distance_to(b) > 0.5 else Vector2.RIGHT
		var nv := dv.orthogonal() * lane
		var col := Color(BOMBARD_COL, 0.22 if i % 2 == 0 else 0.12)
		overlay.draw_colored_polygon(PackedVector2Array([a + nv, b + nv, b - nv, a - nv]), col)
		overlay.draw_line(a + nv, a - nv, Color(BOMBARD_COL, 0.8), 1.5)
		overlay.draw_circle(st[2], 4.0, Color(0, 0, 0, 0.45))
		overlay.draw_circle(st[2], 2.8, Color(BOMBARD_COL, 0.95))
		i += 1
	var last: Vector2 = pts[pts.size() - 1]
	var lv := (last - pts[pts.size() - 2]).normalized().orthogonal() * lane
	overlay.draw_line(last + lv, last - lv, Color(BOMBARD_COL, 0.8), 1.5)


## A selected unit's ATTACK GROUND stretch (a dragged line): a band along it.
func _draw_ground_stretch(a: Vector2, b: Vector2) -> void:
	var dv := (b - a).normalized()
	var nv := dv.orthogonal() * float(Defs.GROUND["lane"]) * Defs.TILE
	overlay.draw_colored_polygon(PackedVector2Array([a + nv, b + nv, b - nv, a - nv]), Color(BOMBARD_COL, 0.14))
	overlay.draw_line(a, b, Color(BOMBARD_COL, 0.6), 1.5)


## A selected unit's BOMBARD spot: a faint dashed line from it and a target ring with four ticks on the spot.
func _draw_bombard_spot(p: Vector2, from: Vector2) -> void:
	overlay.draw_dashed_line(from, p, Color(BOMBARD_COL, 0.35), 1.5, 8.0)
	overlay.draw_set_transform(p, 0.0, Vector2(1.0, FIELD_Y))
	overlay.draw_arc(Vector2.ZERO, 14.0, 0, TAU, 28, Color(0, 0, 0, 0.55), 4.0)
	overlay.draw_arc(Vector2.ZERO, 14.0, 0, TAU, 28, Color(BOMBARD_COL, 0.9), 2.0)
	for k in 4:
		var dv := Vector2.from_angle(k * PI * 0.5)
		overlay.draw_line(dv * 8.0, dv * 20.0, Color(BOMBARD_COL, 0.9), 2.0)
	overlay.draw_set_transform(Vector2.ZERO)

var hover_target: Entity = null          # what the mouse is over (set by the cursor, computer only)


## Hover feedback: a ring round the unit under the mouse (red an enemy, green yours or an ally's,
## yellow a loose horse), a corner frame round a building, so you see what an order will hit.
func _draw_hover() -> void:
	var e := hover_target
	if e == null or not is_instance_valid(e) or e.dead or not e.visible:
		return
	var col := Color(1.0, 0.85, 0.3)
	if e.team >= 0:
		col = Color(1.0, 0.3, 0.25) if hostile(human, e.team) else Color(0.4, 1.0, 0.4)
	var pulse := 0.75 + 0.25 * sin(clock * 8.0)
	if e is Unit and (e as Unit)._k_nb and (e as Unit).nb.has("fpx") and (e as Unit).get_node_or_null(BroodRoot.SORT + "/" + BroodRoot.FP_NODE) != null:
		return          # (a rooted new-Brood creature: its building's frame is drawn under its pictures, BroodRoot._draw_frame)
	if e is Unit and not ((e as Unit)._k_nb and (e as Unit).nb.has("fpx")):      # (a rooted new-Brood creature: a building's frame)
		var r: float = (e as Unit).radius
		overlay.draw_set_transform(e.position, 0.0, Vector2(1.0, 0.45))
		overlay.draw_circle(Vector2.ZERO, r + 9.0, Color(col, 0.18 * pulse))
		overlay.draw_arc(Vector2.ZERO, r + 9.0, 0, TAU, 32, Color(0, 0, 0, 0.7), 6.0)
		overlay.draw_arc(Vector2.ZERO, r + 9.0, 0, TAU, 32, Color(col, pulse), 3.4)
		overlay.draw_set_transform(Vector2.ZERO)
		# a small marker over its head
		var top: Vector2 = e.position + Vector2(0, -(r * 2.0 + 10.0))
		top.y -= 4.0 + 3.0 * sin(clock * 8.0)       # (the marker bobs)
		overlay.draw_colored_polygon(PackedVector2Array([top, top + Vector2(-8, -13), top + Vector2(8, -13)]), Color(0, 0, 0, 0.8))
		overlay.draw_colored_polygon(PackedVector2Array([top + Vector2(0, -2.5), top + Vector2(-5.2, -11), top + Vector2(5.2, -11)]), Color(col, 1.0))
	elif e is Building or e is Unit:
		var rc: Rect2 = e.rect().grow(4)
		var L := 12.0
		for c in [[rc.position, Vector2(1, 0), Vector2(0, 1)], [rc.position + Vector2(rc.size.x, 0), Vector2(-1, 0), Vector2(0, 1)],
				[rc.position + Vector2(0, rc.size.y), Vector2(1, 0), Vector2(0, -1)], [rc.end, Vector2(-1, 0), Vector2(0, -1)]]:
			var p0: Vector2 = c[0]
			overlay.draw_polyline(PackedVector2Array([p0 + c[1] * L, p0, p0 + c[2] * L]), Color(0, 0, 0, 0.6), 5.0)
			overlay.draw_polyline(PackedVector2Array([p0 + c[1] * L, p0, p0 + c[2] * L]), Color(col, pulse), 2.5)


## A patrol path: a dashed line between its two ends with an arrowhead pointing in at each,
## and a ring on the end the unit is walking to (the other end is where he came from).
func _draw_patrol(a: Vector2, b: Vector2, from: Vector2, alpha := 0.75) -> void:
	var c := Color(PATROL_COL, alpha)
	overlay.draw_dashed_line(a, b, Color(0, 0, 0, alpha * 0.5), 4.0, 10.0)
	overlay.draw_dashed_line(a, b, c, 2.2, 10.0)
	var d := (b - a)
	if d.length() < 4.0:
		return
	d = d.normalized()
	for end in [[a, -d], [b, d]]:
		var tip: Vector2 = end[0]
		var dir: Vector2 = end[1]
		var side := dir.orthogonal()
		var tri := PackedVector2Array([tip + dir * 7.0, tip - dir * 5.0 + side * 6.0, tip - dir * 5.0 - side * 6.0])
		overlay.draw_colored_polygon(tri, Color(0, 0, 0, alpha * 0.6))
		var tri2 := PackedVector2Array([tip + dir * 5.0, tip - dir * 4.0 + side * 4.4, tip - dir * 4.0 - side * 4.4])
		overlay.draw_colored_polygon(tri2, c)
	overlay.draw_arc(a if a.distance_to(from) > b.distance_to(from) else b, 9.0, 0, TAU, 20, c, 1.6)


var _overlay_t := 0.0
var _overlay_was := false
var _hover_was := false
var _overlay_view := Vector2.ZERO     # the camera's view when it was last drawn (labels on screen only)


## Something on the overlay moves (floating numbers, pings, shots, tongues, a line or a
## building being placed, the queued orders of the selected units) or just stopped.
func _overlay_moving() -> bool:
	var m := not _floats.is_empty() or not _pings.is_empty() or not _tracers.is_empty() or not tongues.is_empty()
	if not m and (hover_target != null or _hover_was):
		m = true
	_hover_was = hover_target != null
	if not m and controls and (controls.line.size() >= 2 or controls.mode == "place" or controls.mode == "patrol" or (controls.mode == "cast" and controls.cast_spell == "jump")):
		m = true
	if not m and not nb_teams.is_empty() and BroodRoot.overlay_wanted(self):
		m = true          # (the new Brood: a ROOT ghost, the father's range)
	if not m:
		for e in selection:
			if e is Unit and is_instance_valid(e) and (not (e as Unit).queue.is_empty() or not (e as Unit).line_rest.is_empty() or (e as Unit).patrol_a != Vector2.INF):
				m = true
				break
	var r := m or _overlay_was
	_overlay_was = m
	return r


func _draw_overlay() -> void:
	var pt := Time.get_ticks_usec()
	var had := not _ghosts.is_empty()
	_ghosts.clear()
	if not nb_teams.is_empty():
		BroodRoot.draw_overlay(self, overlay)       # (the new Brood: the father's range, a ROOT ghost)
	_draw_overlay_all()
	if had or not _ghosts.is_empty():
		ghost_layer.queue_redraw()
	Prof.add("overlay draw", pt)


## A building about to be placed where it may go: drawn faintly on the ghost layer, so its flags
## and cloth wear the side's colour like the building will (a red-tinted ghost stays on the overlay).
func _ghost(t: Texture2D, pos: Vector2, region := Rect2()) -> void:
	_ghosts.append([t, pos, region])


func _draw_ghosts() -> void:
	if _ghosts.is_empty():
		return
	(ghost_layer.material as ShaderMaterial).set_shader_parameter("team", team_colour(human))
	for g in _ghosts:
		var rg: Rect2 = g[2]
		if rg.size == Vector2.ZERO:
			ghost_layer.draw_texture(g[0], g[1], Color(1, 1, 1, 0.6))
		else:
			ghost_layer.draw_texture_rect_region(g[0], Rect2(g[1], rg.size), rg, Color(1, 1, 1, 0.6))


func _draw_overlay_all() -> void:
	_draw_mine_labels()
	_draw_pit_labels()
	_draw_queues()
	_draw_hover()
	if controls and controls.mode == "cast" and controls.cast_spell == "jump":
		# a Springer's JUMP target: its reach, where it would land and the arc (over the rings and buildings, so it reads)
		Springer.draw_target(self, overlay, overlay.get_global_mouse_position() if Settings.pc() else camera.get_screen_center_position())
	if controls and controls.mode == "patrol":
		# choosing the patrol point: show the walk there and back from each selected unit
		var mp := overlay.get_global_mouse_position()
		for e in selection:
			if e is Unit and is_instance_valid(e) and not e.dead and e.team == controlled_team():
				# (Shift held: the patrol goes after its orders, from where they end)
				var pa: Vector2 = e.plan_end() if Settings.pc() and Input.is_key_pressed(KEY_SHIFT) else e.global_position
				_draw_patrol(pa, mp, pa, 0.55)
	if not tongues.is_empty():
		_draw_tongues()
	for tr in _tracers:
		var col: Color = tr[3] if tr.size() > 3 else Color(1, 0.95, 0.7, 0.8)
		overlay.draw_line(tr[0], tr[1], col, tr[4] if tr.size() > 4 else 1.0)
	for pg in _pings:
		var f: float = pg[2] / 0.5
		overlay.draw_arc(pg[0], 16.0 * (1.5 - f), 0, TAU, 20, Color(pg[1], f), 2.0)
	# an ATTACK GROUND line being drawn: the line, shared out into each unit's stretch
	if controls and controls.line.size() >= 2 and controls.line_ground:
		_draw_ground_line(controls.line)
	# a line move being drawn: the line and where each unit will stand
	elif controls and controls.line.size() >= 2:
		var lc := Color(1.0, 0.45, 0.35, 0.9) if controls.line_attack else Color(0.45, 1.0, 0.45, 0.9)
		overlay.draw_polyline(controls.line, lc, 2.0)
		var n := selected_units().size()
		if n > 0:
			for sp in line_spots(controls.line, n):
				overlay.draw_circle(sp, 4.0, lc)
	if controls and controls.mode == "place" and Settings.build_grid and controls.ghost_cell.x >= 0 and Defs.BUILDINGS.has(controls.place_kind):
		build_grid.update(self, controls.place_kind, controls.ghost_cell, clock)
		var half := get_viewport().get_visible_rect().size * 0.5 / camera.zoom
		build_grid.draw(overlay, self, Rect2(camera.get_screen_center_position() - half, half * 2.0))
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
			var lp := Vector2(lc) * T + Vector2(T * 0.5, T) + Vector2(-lt.get_width() * 0.5, -lt.get_height() + 6)
			if lok:
				_ghost(lt, lp)
			else:
				overlay.draw_texture(lt, lp, Color(1, 0.5, 0.5, 0.4))
	elif controls and controls.mode == "place":
		var k: String = controls.place_kind
		var size: Vector2i = Defs.BUILDINGS[k]["size"]
		var c: Vector2i = controls.ghost_cell
		var ok := placement_problem(human, k, c) == ""
		if Defs.gear_mode and Defs.BUILDINGS[k]["faction"] == "clockwork":
			gear_net.draw_ghost_label(overlay, human, k, c)
		for y in size.y:
			for x in size.x:
				var cc := c + Vector2i(x, y)
				var free: bool = looks_free(human, cc) and (not needs_swamp(k) or swamp[human][idx(cc)] == 1) if in_map(cc) else false
				overlay.draw_rect(Rect2(Vector2(cc) * T, Vector2(T, T)).grow(-1), Color(0.3, 1, 0.3, 0.3) if free else Color(1, 0.3, 0.3, 0.4))
		var t: Texture2D = Building.farm_body("built") if k == "farm" else tex("res://assets/buildings/%s_built.png" % k)
		if Defs.BUILDINGS[k].get("line", false):
			t = line_ghost_tex(k, c, {c: k})
		var r := Rect2(Vector2(c) * T, Vector2(size) * T)
		if k == "farm":
			overlay.draw_texture(tex("res://assets/buildings/farm_field_young.png"), r.position, Color(1, 1, 1, 0.5) if ok else Color(1, 0.5, 0.5, 0.4))
		var pos := Building.anchor(k, r) + Building.body_offset(k, t)
		if ok:
			_ghost(t, pos)
		else:
			overlay.draw_texture(t, pos, Color(1, 0.5, 0.5, 0.5))
		if k == "farm" and String(Building.FARM_ART["sails"]) != "":
			# the windmill's sails, standing still
			var st: Texture2D = tex(Building.FARM_ART["sails"])
			var fw := st.get_width() / int(Building.FARM_ART["sail_frames"])
			var hub: Vector2 = Building.anchor(k, r) + Vector2(Building.FARM_ART["hub"])
			var sr := Rect2(0, 0, fw, st.get_height())
			if ok:
				_ghost(st, hub - sr.size * 0.5, sr)
			else:
				overlay.draw_texture_rect_region(st, Rect2(hub - sr.size * 0.5, sr.size), sr, Color(1, 0.5, 0.5, 0.5))


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
		if u.claimed != null and is_instance_valid(u.claimed) and not u.claimed.dead and u.claimed.is_coming_for(u):
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
func spare_horse(t: int, to: Entity) -> Unit:
	var brs := breeders_of(t)
	if brs.is_empty():
		return null
	var reach := float(Defs.HORSES["near_breeder"]) * T
	var best: Unit = null
	var bd := INF
	for h in horses_of(t):
		if h.off_field or h.into != null or h.horse_rid != 0 or h.leader != null or h.order == "move":
			continue
		if h.claimed != null and is_instance_valid(h.claimed) and not h.claimed.dead and h.claimed.is_coming_for(h):
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
		if not Defs.RIDERS.has(k) and not hauler_serves_rid(b.team, rid):
			h.walk_into(b)           # (with haulers about, one fetches it: haul_dispatch)
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
	br.add_entry("horse", {"rid": rid, "coat": HorseCoat.pick()})
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
			h._unhitch()
	for b in breeders_of(t):
		for i in b.kits.size():
			if b.kits[i] is Dictionary and int(b.kits[i].get("rid", 0)) == rid:
				b.kits[i] = {}


## A reserved horse has reached its building (a gun's Foundry, or a hauler brought it to the
## Barracks): its queue entry gets that horse, hitched beside the building (Game.hitch_horse).
func horse_arrived(b: Building, h: Unit) -> void:
	for i in b.kits.size():
		var kt = b.kits[i]
		if kt is Dictionary and int(kt.get("rid", 0)) == h.horse_rid:
			var nk: Dictionary = kt.duplicate()
			nk.erase("rid")
			nk["hid"] = h.get_instance_id()
			nk["coat"] = h.coat
			nk["hh"] = snappedf(h.hp / maxf(h.max_hp, 1.0), 0.01)
			nk["hm"] = snappedf(h.horse_miles, 0.1)
			b.kits[i] = nk
			return


## The live horse a queue entry's kit holds at `b` (on its way there or hitched beside it), or null.
func _kit_horse(kit: Dictionary, b: Building) -> Unit:
	var id := int(kit.get("hid", 0))
	if id == 0 or not is_instance_id_valid(id):
		return null
	var h = instance_from_id(id)
	if h is Unit and is_instance_valid(h) and (h as Unit).kind == "horse" and not (h as Unit).dead and (h as Unit).into == b:
		return h
	return null


## Does a queue entry of `b` hold this horse (so it is still wanted there)?
func entry_holds(b: Building, h: Unit) -> bool:
	var id := h.get_instance_id()
	for kt in b.kits:
		if kt is Dictionary and int(kt.get("hid", 0)) == id:
			return true
	return false


## The horse has reached the building: its queue entry takes it (a reserved one: horse_arrived)
## and it stands hitched on its own spot beside the building until the recruit comes out on it
## (or the gun is drawn out by it), untouchable; cancelled, it is free again where it stands.
func hitch_horse(b: Building, h: Unit) -> void:
	if h.horse_rid != 0:
		horse_arrived(b, h)
		h.horse_rid = 0
	h.hitch_p = hitch_spot(b, h)
	h._hitch_t = 0.0
	h.velocity = Vector2.ZERO
	h.path = PackedVector2Array()
	h.order = "idle"


## A spot beside the building for a hitched horse: round its rim, clear ground the horse can walk
## to, on the side away from the rally (where the recruits come out), a body's width from the
## others hitched there; the horse's own spot if there is none.
func hitch_spot(b: Building, h: Unit) -> Vector2:
	var r := b.rect()
	var out := r.grow(22.0)
	var toward: Vector2 = b.rally if b.rally != Vector2.INF else r.get_center() + Vector2(0, r.size.y)
	var taken: Array = []
	for u in units:
		if u != h and u.kind == "horse" and not u.dead and u.hitch_p != Vector2.INF and u.into == b:
			taken.append(u.hitch_p)
	var cands: Array = []
	var step := 26.0
	var x := out.position.x
	while x <= out.end.x:
		cands.append(Vector2(x, out.position.y))
		cands.append(Vector2(x, out.end.y))
		x += step
	var y := out.position.y + step
	while y < out.end.y:
		cands.append(Vector2(out.position.x, y))
		cands.append(Vector2(out.end.x, y))
		y += step
	var home := region_of(cell_of(h.position))
	var best := Vector2.INF
	var bs := -INF
	for p: Vector2 in cands:
		var c := cell_of(p)
		if not in_map(c) or not open_cell(c) or not _clear_at(p, h.radius, h.team):
			continue
		var clash := false
		for q: Vector2 in taken:
			if q.distance_to(p) < 24.0:
				clash = true
				break
		if clash:
			continue
		var sc: float = p.distance_to(toward) - 0.5 * p.distance_to(h.position)
		if not in_open_map(c):
			sc -= 200000.0           # (a pocket shut in by buildings: only if there is nothing else)
		elif region_of(c) != home:
			sc -= 100000.0           # (the far side of a wall from the horse: it would be put there)
		if sc > bs:
			bs = sc
			best = p
	if best == Vector2.INF:
		return h.position
	return best


## A Foundry's gun is ready but its horse isn't there yet: make sure one is coming (its own,
## or a new spare one if it was killed or stolen, or a new one bought when there's gold).
func fetch_reserved(b: Building, i: int) -> void:
	var kt = b.kit_at(i)
	var rid := int(kt.get("rid", 0)) if kt is Dictionary else 0
	if rid == 0:
		return
	var h := reserved_horse(b.team, rid)
	if h:
		if h.into != b and h.leader == null and not Unit._claim_live(h) and not hauler_serves_rid(b.team, rid):
			h.walk_into(b)           # (no hauler to bring it, or none came in time: it walks by itself)
		return
	if rid_breeder(b.team, rid) != null:
		return
	_reserve_horse(b, String(b.queue[i]), rid, true)


var _res_chk := 0.0

## Every 2 s: a horse kept for a recruit that's gone (cancelled, killed, mounted elsewhere)
## is free again.
func _horse_res_tick(delta: float) -> void:
	haul_dispatch(delta)
	_res_chk -= delta
	if _res_chk > 0.0:
		return
	_res_chk = 2.0
	for h in units:
		if h.kind == "horse" and not h.dead and h.horse_rid != 0 and rid_owner(h.team, h.horse_rid) == null:
			h.horse_rid = 0
			if h.into is Building:
				h._unhitch()


## A cancelled recruit's horse (its coat and health in the queue entry's kit) that is no longer
## on the field (an entry from a loaded game: Game.refund) walks back out.
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
	h.hitch_p = Vector2.INF
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
	tell(was, "A horse was stolen!")
	if was == human:
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
	if net_forward(self, "lead_order", [list]): return 0
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
	if net_forward(self, "mount_order", [list]): return 0
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
	if net_forward(self, "harness_order", [list]): return 0
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
