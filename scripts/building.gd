class_name Building
extends Entity
## A building: placed on a tile footprint, built up by labourers, trains units
## from a queue, catches fire when damaged and leaves rubble when destroyed.

var d: Dictionary
var cell := Vector2i.ZERO
var size := Vector2i.ONE
var built := false
var progress := 0.0              # 0..1 while under construction
var queue: Array = []            # unit kinds, and research as "@key" (Defs.RESEARCH)
var kits: Array = []             # beside `queue`: what a queued Musketeer was paid to come out with ({} for the rest)
var auto_refit := false          # Barracks: AUTO REFIT (idle Musketeers nearby get the upgrades researched)
var prod_t := 0.0
var stock := 0.0                # Ore Drill: ore dug and waiting for a train
var drill_on := false           # Ore Drill: digging this moment
var drill_anim := false         # Ore Drill: showing the working loop
var batteries := 0               # Clockwork: full batteries waiting to be carried off
var gear_big := false            # Clockwork (gear mode): the connecting gear is BIG (else SMALL): Defs.GEAR, scripts/gear.gd
var gear_swap_t := -1.0          # seconds left of a gear swap (-1: none); the building idles meanwhile
var gear_swap_to := false        # the size it swaps to
var press_paid := 0.0            # Cog Press: cogs it has paid in all (statistics)
var _bat_t := 0.0
var auto_train := ""             # keep training this unit (right-click / long press on its button)
var _auto_t := 0.0
var rally := Vector2.INF
var rally_target: Entity = null
var worker_rally := Vector2.INF  # Hive: workers and army have separate rally points
var worker_rally_target: Entity = null
var seeded := true               # Brood: a grub has turned into the site; Clockwork: the crate has landed (or a Winder started it)
# Clockwork: the Winder's crate (Defs.CRATE). "" none (started by hand, or no Clocktower to
# fetch it from); "tower" waiting at a Clocktower for a Winder to fetch it; "carried" on
# crate_carrier's back; "ground" dropped on the way (crate_obj). The site is a ghost until it lands.
var crate := ""
# A placed site is a ghost until its construction actually starts (Crown: the Labourers
# begin; Brood: the grub morphs into it; Clockwork: the crate lands or the Winder starts it
# by hand). A ghost isn't solid, can't be hurt or targeted, gives no sight and doesn't keep
# its player alive; only its own side sees it (Game.try_start_site).
var ghost := false
var block_since := -1.0          # ghost: match clock when its start was first found blocked
var asked := {}                  # ghost: unit instance id -> clock it was told to step out
var crate_carrier: Unit = null
var crate_obj: Crate = null
var unfold_t := -1.0             # seconds since the crate landed, while it unfolds (-1: not unfolding)
var _unfold: Sprite2D = null
var eggs := 0:                   # Brood Hive (shown over it: redrawn when it changes)
	set(v):
		eggs = v
		queue_redraw()
var egg_t := 0.0
var morph_t: Array = []          # Brood Hive: time spent on each morphing egg
var level := 1                   # Brood hall: 1 Burrow, 2 Warren, 3 Broodmound (Defs.HALL_LEVELS)
var upgrade_t := -1.0            # Brood hall: seconds into its upgrade to the next level (-1: none)
var swamp_r := 0.0               # Brood: current swamp radius in tiles
var gold_acc := 0.0
var crew: Array = []             # workers assigned to this economy structure
var growth := 0.0                # Farm: 0..1 until the harvest
var soil := 0.0                  # Town Hall: gold left in its farmland; Hive: biomass left in its ground (full when fresh: reserve())
var soil_warned := 0             # Town Hall: 1 = told the player it's low, 2 = spent
var lode := 0.0                  # Town Hall: saltpetre (in powder) for its Mill; Clocktower: ore for its Crushers (Defs.LODE)
var lode_warned := 0             # 1 = told it's running low, 2 = spent
var sprite: Sprite2D
var field: Sprite2D = null       # Farm: its fields, on the ground under the units (they work in them)
var sails: Sprite2D = null       # Farm: the windmill's sails, turning over the body (FARM_ART)
var _sail_t := 0.0
var _sail_v := 1.0               # Farm: the sails' speed, 0 still .. 1 turning (eased: in_use)
var scarecrow_sprites: Array = []   # Farm: its scarecrows out in the crops
# Powder Mill: the horse walking its track (MILL_ART)
var _mill_horse: Sprite2D = null
var _mill_ground: Sprite2D = null     # the mill's dirt track and grass edge, on the ground under every unit (z_index -1; tools/split_mill_ground.py)
var _mill_stone: Sprite2D = null      # the post and millstone, over the horse behind them
var _mill_run: Node2D = null          # the runner stone and arm: turned by _mill_a, squashed like the track
var _mill_run_top: Sprite2D = null    # (its two sprites: the main one, and its darker copy under it)
var _mill_run_under: Sprite2D = null
var _mill_state := ""                 # the state whose track it walks ("": no horse)
var _mill_a := 0.0                    # where it is on the track (angle)
var _mill_v := 0.0                    # 0 standing .. 1 walking (eased)
var _mill_f := 0.0                    # its walk frames' clock
var _mill_dir := ""
var _mill_far := -1                   # 1: on the far half (behind the post), 0 near, -1 not laid out
# the second-generation buildings' parts: a bell, a drilling man, paddock horses, the inventor,
# lit windows (BuildingLife)
var life: BuildingLife = null
var turret: RatchetTurret = null      # Ratchet Turret (gear mode): its turning head and gun
# in_use, looked at twice a second
var _use_t := 0.0
var _in_use := true
var _seen_now := true
var fire: Effect = null
var rubble_t := 0.0
# Clockwork towers: anti-air lightning
var zap_cd := 0.0
var zap_off_t := 0.0             # field switched off while the tower fights
var _zap_scan := 0.0
# idle animation
var _amb_t := 0.0
var _crackle: Effect = null

## Where each building puffs smoke, steams, sparks or drips spores: [effect, x, y (as
## fractions of the sprite), seconds between puffs, size, tint]. Only drawn on screen, and
## only while the building is in use (in_use: a Foundry's smoke and forge while it works, a
## Powder Mill's dust while it's manned...; halls, homes and the Brood's living buildings always).
const AMBIENT := {
	"town_hall": [["smoke", 0.29, 0.22, 1.6, 0.45, Color(0.85, 0.85, 0.85, 0.6)], ["smoke", 0.72, 0.28, 1.9, 0.4, Color(0.85, 0.85, 0.85, 0.6)]],
	"cottage": [["smoke", 0.45, 0.1, 1.8, 0.4, Color(0.85, 0.85, 0.85, 0.6)]],
	"barracks": [["smoke", 0.21, 0.25, 1.7, 0.4, Color(0.85, 0.85, 0.85, 0.6)], ["smoke", 0.65, 0.06, 2.1, 0.35, Color(0.85, 0.85, 0.85, 0.6)]],
	"foundry": [["smoke", 0.25, 0.06, 0.7, 0.7, Color(0.45, 0.45, 0.45, 0.75)], ["fire", 0.72, 0.68, 1.1, 0.35, Color(1, 1, 1, 0.9)]],
	"powder_mill": [["dust", 0.75, 0.69, 1.4, 0.3, Color(1, 1, 1, 0.6)], ["dust", 0.58, 0.55, 1.0, 0.22, Color(0.85, 0.85, 0.8, 0.5)]],     # (off the millstone, and the hopper's mouth at sprite px 72,65)
	"church": [],
	"hive": [["smoke", 0.5, 0.78, 1.3, 0.35, Color(0.6, 1.0, 0.3, 0.55)], ["smoke", 0.22, 0.82, 2.2, 0.3, Color(0.6, 1.0, 0.3, 0.5)], ["smoke", 0.78, 0.82, 2.4, 0.3, Color(0.6, 1.0, 0.3, 0.5)]],
	"warren": [["smoke", 0.5, 0.74, 1.5, 0.35, Color(0.6, 1.0, 0.3, 0.5)]],
	"gorge_pit": [["smoke", 0.5, 0.52, 0.9, 0.45, Color(0.6, 1.0, 0.3, 0.55)]],
	"clutch_mound": [["smoke", 0.42, 0.22, 1.6, 0.3, Color(0.75, 1.0, 0.4, 0.45)]],
	"brood_pen": [["smoke", 0.5, 0.45, 1.6, 0.4, Color(0.75, 0.5, 1.0, 0.5)]],
	"feeding_pit": [["acid_splash", 0.5, 0.55, 1.4, 0.5, Color(1, 0.6, 0.6, 0.8)]],
	"clocktower": [["smoke", 0.2, 0.3, 1.1, 0.4, Color(1.2, 1.2, 1.2, 0.6)]],
	"assembly_works": [["smoke", 0.3, 0.04, 0.9, 0.4, Color(1.2, 1.2, 1.2, 0.6)], ["smoke", 0.86, 0.05, 1.1, 0.4, Color(1.2, 1.2, 1.2, 0.6)]],
	"boiler": [["smoke", 0.32, 0.07, 0.7, 0.45, Color(1.2, 1.2, 1.2, 0.65)]],
	"ore_crusher": [["dust", 0.6, 0.55, 1.0, 0.35, Color(0.8, 0.8, 0.8, 0.7)]],
}
## The Farm (a true square, 6x6 tiles): a windmill on the 4x2-tile block in the middle (FARM_BLOCK, solid),
## the crop fields (tools/make_farm_field.py) all round it, right up to the tower: rows behind,
## down both sides and in front (no yard, no path). Each labourer works a stretch of
## one crop row (FARM_ROWS). The windmill's door foot (its base line, which sorts it against the
## units) is at FARM_HOUSE_X, FARM_HOUSE_BASE from the footprint's top left corner.
const FARM_HOUSE_BASE := 112.0
const FARM_HOUSE_X := 102.0          # (the tower stands a little left of its door: centred on the block)
const FARM_BLOCK := Rect2i(1, 2, 4, 2)
const FARM_ROW := 16.0
## The labourers' stretches, in the order the crew fills them: [crop row, from x, to x] in px
## of the footprint; row k's furrow is at 13 + 16k. Front rows first (two men to a row),
## then behind the windmill (clear of its sails), then the side plots. None touches FARM_BLOCK.
const FARM_ROWS := [[9, 10, 94], [9, 110, 182], [10, 10, 94], [10, 110, 182],
	[2, 10, 54], [2, 152, 182], [6, 8, 24], [5, 168, 184]]
## Where scarecrows may stand (their pole's foot, px of the footprint): on crop rows nobody
## works (the side plots' far ends, the front row by the windmill). Each
## Farm picks 2 or 3 (and their looks) by its cell.
const FARM_SCARECROW_SPOTS := [Vector2(20, 79), Vector2(178, 127), Vector2(24, 143),
	Vector2(62, 143), Vector2(140, 143), Vector2(174, 143)]
## The farmhouse art, all of it in one place (tools/import_windmill.py makes it): the body,
## body % state ("built", "construction", "damaged", "destroyed"), with its pixel `anchor` on
## the building's base point; the sails, a strip of `sail_frames` frames turned about their
## middle, drawn over the body at `hub` (from the base point) in the `sail_states`, one frame
## every `sail_dt` s (slower as the soil tires; still once it's spent); the scarecrows, a strip
## of `scarecrow_kinds` looks, the pole's foot at the bottom middle. `top`: where the health
## bar goes. (A new farmhouse: new files and numbers here; sails "" for none.)
const FARM_ART := {
	"body": "res://assets/buildings/farm_%s.png", "anchor": Vector2(81, 121), "top": -96.0,
	"sails": "res://assets/buildings/farm_sails.png", "sail_frames": 6, "sail_dt": 0.3,
	"hub": Vector2(7, -54), "sail_states": ["built", "damaged"],
	"scarecrows": "res://assets/buildings/farm_scarecrow.png", "scarecrow_kinds": 4,
}

## The Powder Mill is a horse mill (tools/import_powder_mill.py makes the art): while it is
## worked (in_use) a harnessed horse walks round the dirt track at the front right, turning the
## runner stone by a timber arm from the hub to the horse's harness. Per state that
## shows the track (the others: no horse), from the base point: the track's `centre` (on the
## ground) and `radius` (an ellipse), and the `post`'s top. The horse: a bay team horse shrunk to
## the mill (walk_<dir>, `frames` a strip, its hooves at `anchor`), facing the way it walks
## (Unit.DIR_FLIP, mirrored for the west). The `runner` (a top-down picture, 2x oversampled, its
## `hub` the pivot in texture px, the swingle-bar a track radius from it) is one sprite turned by
## the horse's angle on the track, inside a node squashed like the track (so: turned first,
## squashed after), over its own darker copy `depth` px lower; per state it is `lift` px above
## the track's centre, at harness height. On the far half of the track the horse walks behind
## the post and millstone (`stone`: their pixels alone, drawn over it) and the runner is over it;
## on the near half the horse is in front of both. One lap every `lap` s, walk frames at `fps`;
## it eases into its walk and to a halt over `ease` s.
const MILL_ART := {
	"horse": "res://assets/buildings/mill_horse/walk_%s.png", "frames": 6, "anchor": Vector2(24, 29),
	"stone": "res://assets/buildings/powder_mill_stone_%s.png",
	"states": {
		"built": {"centre": Vector2(31, -24), "radius": Vector2(18.5, 9.5), "post": Vector2(31, -33)},
		"damaged": {"centre": Vector2(32, -22.5), "radius": Vector2(18.5, 9.5), "post": Vector2(32, -33)},
	},
	"runner": "res://assets/buildings/mill_runner.png", "hub": Vector2(21.6, 21.9), "depth": 3.5, "lift": 8.0,
	"lap": 7.0, "fps": 7.0, "ease": 1.5,
}

## The tip of each Clockwork tower, where its lightning lives.
const TOWER_TOP := {"clocktower": Vector2(0.52, 0.03), "spring_tower": Vector2(0.6, 0.05), "charging_pylon": Vector2(0.52, 0.08)}


func is_building() -> bool:
	return true


func setup(g: Game, k: String, t: int, c: Vector2i, complete: bool) -> void:
	game = g
	kind = k
	team = t
	d = Defs.BUILDINGS[k]
	cell = c
	size = d["size"]
	max_hp = d["hp"]
	armor = d["armor"]
	sight = d["sight"]
	built = complete
	progress = 1.0 if complete else 0.0
	hp = max_hp if complete else max_hp * 0.1
	if d["faction"] == "clockwork":
		seeded = complete
	if k == "town_hall" or k == "hive" or k == "clocktower":
		soil = reserve()
	lode = lode_full()
	if d["faction"] == "brood":
		seeded = complete
		if complete:
			swamp_r = swamp_target()
		if d.get("eggs", false):
			eggs = Defs.EGGS_MAX if complete else 0
	if is_leveled():
		d = d.duplicate()            # (its name changes with its level: set_level)
	position = anchor(k, rect())


## A hall with levels (the Brood's: Burrow, Warren, Broodmound).
func is_leveled() -> bool:
	return kind == "hive"


## This hall's level entry (Defs.HALL_LEVELS); {} for other buildings.
func level_info() -> Dictionary:
	return Defs.HALL_LEVELS[clampi(level, 1, Defs.HALL_LEVELS.size()) - 1] if is_leveled() else {}


## The next level's entry, or {} at the top (or for other buildings).
func next_level() -> Dictionary:
	return Defs.HALL_LEVELS[level] if is_leveled() and level < Defs.HALL_LEVELS.size() else {}


## How many eggs it holds.
func eggs_max() -> int:
	return int(level_info().get("eggs", Defs.EGGS_MAX))


## Set the hall's level: its name, health (the health it gains comes on top of what it has)
## and armour.
func set_level(n: int) -> void:
	if not is_leveled():
		return
	level = clampi(n, 1, Defs.HALL_LEVELS.size())
	var li := level_info()
	d["name"] = li["name"]
	d["hp"] = li["hp"]
	d["armor"] = li["armor"]
	var gain := float(li["hp"]) - max_hp
	max_hp = float(li["hp"])
	armor = int(li["armor"])
	if built and not dead:
		hp = clampf(hp + maxf(gain, 0.0), 1.0, max_hp)
	else:
		hp = minf(hp, max_hp)
	_update_sprite()
	queue_redraw()


## Where a building of this kind on this footprint stands (its sprite's base line, which
## also sorts it against the units): the middle of the bottom edge; a Farm's windmill door,
## in the middle of its fields.
static func anchor(k: String, r: Rect2) -> Vector2:
	if k == "farm":
		return Vector2(r.position.x + FARM_HOUSE_X, r.position.y + FARM_HOUSE_BASE)
	return Vector2(r.get_center().x, r.end.y)


func _ready() -> void:
	if kind == "farm":
		field = Sprite2D.new()
		field.centered = false
		field.z_index = -1          # on the ground: the labourers walk the rows on top of it
		field.position = rect().position - position
		add_child(field)
		y_sort_enabled = true       # its scarecrows stand among the labourers
	if kind == "gate":
		y_sort_enabled = true       # its sprite sorts a pixel below it (_update_sprite)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.material = team_material()
	add_child(sprite)
	if kind == "farm":
		_farm_art()
	elif kind == "powder_mill":
		_mill_art()
	elif BuildingLife.has_life(kind):
		life = BuildingLife.new()
		life.setup(self)
	if kind == Defs.CW_TURRET:
		turret = RatchetTurret.new(self)
		turret.head.material = sprite.material
	_update_sprite()


## The Farm's sails (over the body, drawn with it) and scarecrows (out in the crops, each
## sorted by its own foot).
func _farm_art() -> void:
	if String(FARM_ART["sails"]) != "" and ResourceLoader.exists(FARM_ART["sails"]):
		sails = Sprite2D.new()
		sails.texture = Game.tex(FARM_ART["sails"])
		sails.hframes = int(FARM_ART["sail_frames"])
		sails.position = FARM_ART["hub"]
		sails.material = sprite.material
		sails.visible = false
		sails.frame = randi() % sails.hframes      # (not every windmill in step)
		_sail_t = randf() * float(FARM_ART["sail_dt"])
		sprite.add_child(sails)
	var st: Texture2D = Game.tex(FARM_ART["scarecrows"])
	var n := int(FARM_ART["scarecrow_kinds"])
	for sc in scarecrows(cell):
		var s := Sprite2D.new()
		s.texture = st
		s.hframes = n
		s.frame = int(sc[1]) % n
		s.centered = false
		s.offset = Vector2(-st.get_width() / n * 0.5, -st.get_height())
		s.position = rect().position + Vector2(sc[0]) - position
		s.material = sprite.material
		s.visible = false
		add_child(s)
		scarecrow_sprites.append(s)


## The Powder Mill's horse, runner and millstone overlay (MILL_ART), over its body; hidden
## until a state with a track shows (_update_sprite).
func _mill_art() -> void:
	_mill_ground = Sprite2D.new()
	_mill_ground.centered = false
	_mill_ground.z_index = -1          # labourers walk the dirt on top of it, behind the shed still hidden by the structure
	add_child(_mill_ground)
	move_child(_mill_ground, 0)
	_mill_horse = Sprite2D.new()
	_mill_horse.centered = false
	_mill_horse.offset = -Vector2(MILL_ART["anchor"])
	_mill_horse.hframes = int(MILL_ART["frames"])
	_mill_stone = Sprite2D.new()
	_mill_stone.centered = false
	_mill_runner()
	for n: CanvasItem in [_mill_horse, _mill_stone, _mill_run]:
		n.visible = false
		add_child(n)
	_mill_a = float(posmod(hash(cell), 360)) * PI / 180.0     # (not every mill in step)


## The runner stone and arm: a node squashed like the track, its sprites turned inside it (so
## the squash comes after the turn), the hub at the node's origin, the darker copy under.
func _mill_runner() -> void:
	_mill_run = Node2D.new()
	_mill_run.scale.y = float(MILL_ART["states"]["built"]["radius"].y) / float(MILL_ART["states"]["built"]["radius"].x)
	var tex := Game.tex(String(MILL_ART["runner"]))
	for i in 2:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.offset = -Vector2(MILL_ART["hub"])
		sp.scale = Vector2(0.5, 0.5)
		if i == 0:
			sp.modulate = Color(0.55, 0.55, 0.55)
			sp.position.y = float(MILL_ART["depth"]) / _mill_run.scale.y
		_mill_run.add_child(sp)
	_mill_run_under = _mill_run.get_child(0)
	_mill_run_top = _mill_run.get_child(1)


## Shows the horse for this state (or hides it).
func _mill_show(state: String) -> void:
	var ms := state if seeded and not dead and Dictionary(MILL_ART["states"]).has(state) else ""
	if ms != _mill_state:
		_mill_state = ms
		_mill_far = -1
		_mill_horse.visible = ms != ""
		_mill_run.visible = ms != ""
		_mill_stone.visible = false
		if ms != "":
			_mill_stone.texture = Game.tex(String(MILL_ART["stone"]) % ms)
			_place_mill_horse(false)
	if ms != "":
		_mill_stone.position = sprite.position
		_mill_stone.offset = sprite.offset


## Walks the horse on (only on screen, and while somebody sees it: a mill remembered under
## the fog stands still): faster into its walk while the mill is in use, to a halt when not.
func _turn_mill(delta: float) -> void:
	if not _seen_now or not game.view_rect.intersects(rect()):
		return
	var target := 1.0 if _in_use else 0.0
	if _mill_v == target and target == 0.0:
		return
	_mill_v = move_toward(_mill_v, target, delta / float(MILL_ART["ease"]))
	var v := smoothstep(0.0, 1.0, _mill_v)
	_mill_a = fmod(_mill_a + v * delta * TAU / float(MILL_ART["lap"]), TAU)
	_mill_f += v * delta * float(MILL_ART["fps"])
	_place_mill_horse(_mill_v > 0.05)


## The horse where _mill_a puts it, facing along the track, the runner turned with it, and
## the draw order for the half of the track it's on.
func _place_mill_horse(walking: bool) -> void:
	var st: Dictionary = MILL_ART["states"][_mill_state]
	var r: Vector2 = st["radius"]
	var p := (Vector2(st["centre"]) + Vector2(r.x * cos(_mill_a), r.y * sin(_mill_a))).round()
	# its heading on the ground (the track is a circle there): the tangent of the circle
	var o := posmod(int(round(Vector2(-sin(_mill_a), cos(_mill_a)).angle() / (PI / 4.0))), 8)
	var df: Array = Unit.DIR_FLIP[o]
	var dr: String = df[0]
	if dr != _mill_dir:
		_mill_dir = dr
		_mill_horse.texture = Game.tex(String(MILL_ART["horse"]) % dr)
	_mill_horse.flip_h = df[1]
	_mill_horse.frame = int(_mill_f) % _mill_horse.hframes if walking else 0
	_mill_horse.position = p
	_mill_run.position = Vector2(st["centre"]) - Vector2(0, float(MILL_ART["lift"]))
	_mill_run_top.rotation = _mill_a
	_mill_run_under.rotation = _mill_a
	var far := 1 if sin(_mill_a) < 0.0 else 0
	if far != _mill_far:
		_mill_far = far
		_mill_stone.visible = far == 1
		# far: the horse, the post and stone over it, the runner in front; near: the runner
		# (its arm meeting the horse's far side), the horse over it
		var order: Array = [_mill_horse, _mill_stone, _mill_run] if far == 1 \
			else [_mill_stone, _mill_run, _mill_horse]
		var i0 := sprite.get_index()
		for i in order.size():
			move_child(order[i], i0 + 1 + i)


## In use (its animations play): an economy building while it's worked, a workshop while it
## trains or researches (a Horse Breeder its horses, an Armoury its research), a Boiler while it
## fills batteries. Others always. (A Town Hall's or Church's bell swings only while it trains:
## BuildingLife.training.)
func in_use() -> bool:
	match kind:
		"farm", "powder_mill":
			return working_crew() > 0
		"feeding_pit":
			return not crew.is_empty()
		"ore_crusher":
			var e := efficiency()
			return not e.is_empty() and int(e[1]) > 0
		"foundry", "barracks", "assembly_works", "engine_hall", "horse_breeder", "armoury":
			return not queue.is_empty()
		"boiler":
			return d.has("battery") and batteries < int(d["battery"][1])
		"ore_drill":
			return OreDrill.working(self)
		"cog_press":
			return working_crew() > 0 and press_rate() > 0.0
		"mainspring":
			return working_crew() > 0 and spring_rate() > 0.0
		"movement_works":
			return not queue.is_empty() and game.gear_net.speed_mult(self) > 0.0
		"regulator":
			return game.gear_net.speed_mult(self) > 0.0
		"escapement":
			return game.gear_net.speed_mult(self) > 0.0       # (linked and meshed with a Mainspring)
	return true


## (twice a second) in_use, and whether the player's side sees it right now (not just
## remembers it under the fog).
func _check_use(delta: float) -> void:
	_use_t -= delta
	if _use_t > 0.0:
		return
	_use_t = 0.5
	_in_use = built and not dead and in_use()
	var ft := game.fog_team()
	_seen_now = game.sees_all() or ft < 0 or game.allied(team, ft) or game.is_visible_to(ft, center())
	if life:
		life.check()


## A Farm's scarecrows: 2 or 3 of FARM_SCARECROW_SPOTS, each [spot, look], picked by its cell
## (the same every time), not two side by side.
static func scarecrows(c: Vector2i) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	var spots: Array = FARM_SCARECROW_SPOTS.duplicate()
	var looks: Array = range(int(FARM_ART["scarecrow_kinds"]))
	var out: Array = []
	var want := 2 + rng.randi() % 2
	while out.size() < want and not spots.is_empty():
		var p: Vector2 = spots.pop_at(rng.randi() % spots.size())
		if out.any(func(o: Array) -> bool: return Vector2(o[0]).distance_to(p) < 40.0):
			continue
		out.append([p, looks.pop_at(rng.randi() % looks.size())])
	return out


## The farmhouse body texture for a state, and where any building's body is drawn from its
## base point.
static func farm_body(state: String) -> Texture2D:
	return Game.tex(String(FARM_ART["body"]) % state)


## Where its body sprite covers the world (for clicks), its scale (an upgraded hall) counted.
func sprite_rect() -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2(global_position, Vector2.ZERO)
	return Rect2(global_position + sprite.position + sprite.offset * sprite.scale, sprite.texture.get_size() * sprite.scale)


static func body_offset(k: String, t: Texture2D) -> Vector2:
	if k == "farm":
		return -Vector2(FARM_ART["anchor"])
	return Vector2(-t.get_width() * 0.5, -t.get_height() + 6)


## The cells of a footprint (from its corner) that stay walkable: a Farm's fields, all round
## the windmill's 4x2 block in the middle.
static func field_cells(k: String) -> Array:
	var out: Array = []
	if k == "farm":
		var sz: Vector2i = Defs.BUILDINGS[k]["size"]
		for y in sz.y:
			for x in sz.x:
				if not FARM_BLOCK.has_point(Vector2i(x, y)):
					out.append(Vector2i(x, y))
	return out


## Farm: the stretch of crop row the crew member number i works (FARM_ROWS), as [from, to]
## in world space.
func field_row(i: int) -> Array:
	return row_stretch(rect(), i)


static func row_stretch(r: Rect2, i: int) -> Array:
	var row: Array = FARM_ROWS[i % FARM_ROWS.size()]
	var y := r.position.y + 13.0 + FARM_ROW * float(row[0])
	return [Vector2(r.position.x + float(row[1]), y), Vector2(r.position.x + float(row[2]), y)]


## Farm: true if the straight walk from a to b would cross the windmill's block.
func crosses_house(a: Vector2, b: Vector2) -> bool:
	var hr := Rect2(rect().position + Vector2(FARM_BLOCK.position) * Defs.TILE, Vector2(FARM_BLOCK.size) * Defs.TILE).grow(6.0)
	for k in 9:
		if hr.has_point(a.lerp(b, k / 8.0)):
			return true
	return false


func rect() -> Rect2:
	return Rect2(Vector2(cell) * Defs.TILE, Vector2(size) * Defs.TILE)


## A ghost can't be hurt, shot at or targeted.
func untouchable() -> bool:
	return ghost or super()


func supply() -> int:
	return int(d["supply"]) if built and not dead else 0


func add_progress(delta: float) -> void:
	if built or dead:
		return
	var step := delta / float(d["time"])
	progress = minf(progress + step, 1.0)
	hp = minf(hp + max_hp * 0.9 * step, max_hp)
	if progress >= 1.0:
		built = true
		hp = maxf(hp, max_hp * 0.95)
		game.on_building_complete(self)
	_update_sprite()


## Clockwork: the Winder has set the crate down on the site. It unfolds into the building's
## frame (assets/effects/crate_unfold_<n>.png), and the building builds itself from now on.
func land_crate() -> void:
	crate = ""
	crate_carrier = null
	crate_obj = null
	seeded = true
	unfold_t = 0.0
	Sfx.play("ratchet", center())
	_update_sprite()


## How long the unfold takes: frames 0-4, frame 5 held, then the cross-fade.
static func unfold_time() -> float:
	return 5.0 * float(Defs.CRATE["unfold"]) + float(Defs.CRATE["hold"]) + float(Defs.CRATE["fade"])


## The crate unfolding (over the ghost of the site): the closed crate grows from its size on
## the ground as the lid opens and lets out steam, the sides fold flat, the iron plates go
## down, then the frame with its beam stands and fades into the construction sprite.
func _unfold_tick(delta: float) -> void:
	var per := float(Defs.CRATE["unfold"])
	var prev := int(unfold_t / per)
	var done := unfold_t < 0.0
	unfold_t += delta
	var info: Array = ArtData.CRATE.get(kind, [])
	if done or dead or built or unfold_t >= unfold_time() or info.is_empty():
		unfold_t = -1.0
		if _unfold:
			_unfold.queue_free()
			_unfold = null
		_update_sprite()
		return
	if _unfold == null:
		_unfold = Sprite2D.new()
		_unfold.centered = false
		_unfold.texture = Game.tex("res://assets/effects/crate_unfold_%s.png" % kind)
		_unfold.hframes = 6
		_unfold.offset = Vector2(-float(info[0]) * 0.5, -float(info[1]) + 6.0)
		_unfold.material = team_material()
		add_child(_unfold)
	# (a low building fades in from the iron plates: the gantry would tower over it)
	var f := mini(int(unfold_t / per), int(info[3]))
	_unfold.frame = f
	var s0 := float(ArtData.CRATE_GROUND) / float(info[2])
	_unfold.scale = Vector2.ONE * lerpf(s0, 1.0, ease(clampf(unfold_t / per, 0.0, 1.0), 0.4))
	var fade_from := 5.0 * per + float(Defs.CRATE["hold"])
	_unfold.modulate.a = 1.0 - clampf((unfold_t - fade_from) / float(Defs.CRATE["fade"]), 0.0, 1.0)
	if f != prev and f <= 4 and visible and game.view_rect.has_point(global_position):
		if f == 1:
			# steam out of the open lid
			for i in 3:
				var fx := game.spawn_effect("smoke", global_position + Vector2(randf_range(-0.18, 0.18) * float(info[0]), -float(info[1]) * 0.55), 0.9)
				fx.scale = Vector2(0.4, 0.4)
				fx.modulate = Color(1.2, 1.2, 1.2, 0.7)
				fx.z_index = 4
		else:
			Sfx.play("ratchet", center(), -8.0)
		if f == 4:
			var du := game.spawn_effect("dust", global_position + Vector2(0, -6), 1.4)
			du.scale = Vector2.ONE * float(info[0]) / 110.0
	_update_sprite()


## A production queue entry that is research ("@armour") rather than a unit.
static func is_research(k: String) -> bool:
	return k.begins_with("@")


## Seconds a queue entry takes (a unit's training or a research's time).
static func entry_time(k: String) -> float:
	if is_research(k):
		return float(Defs.RESEARCH[k.substr(1)]["time"])
	return float(Defs.UNITS[k]["time"])


## What the queue entry at `i` was paid to come out with ({} if nothing: research, other units).
func kit_at(i: int) -> Dictionary:
	return kits[i] if i >= 0 and i < kits.size() and kits[i] is Dictionary else {}


## Put an entry at the back of the queue, with its kit beside it.
func add_entry(k: String, kit: Dictionary = {}) -> void:
	kits.resize(queue.size())
	queue.append(k)
	kits.append(kit)


## Take the queue entry at `i` out (and its kit beside it); returns the kit.
func take_entry(i: int) -> Dictionary:
	var kit := kit_at(i)
	queue.remove_at(i)
	if i < kits.size():
		kits.remove_at(i)
	return kit


func can_train(k: String) -> bool:
	return built and not dead and (d["trains"] as Array).has(k)


## True when this building trains both workers and soldiers (the Brood Hive).
func dual_rally() -> bool:
	var w := false
	var a := false
	for k in d["trains"]:
		if Defs.is_worker(k):
			w = true
		else:
			a = true
	return w and a


## Crew members actually at their post (labourers and Winders standing at it).
func working_crew() -> int:
	var n := 0
	for u in crew:
		if is_instance_valid(u) and not u.dead and u.work == "manning":
			n += 1
	return n


## Town Hall: how many haulers it takes (0: this building has none).
func haul_cap() -> int:
	return int(d.get("haulers", 0))


## Town Hall: the workers assigned to it as haulers (alive, on the field).
func haulers() -> Array:
	return crew.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and not u.off_field and u.home_mine == self)


## Town Hall: haulers free to take a job now (the counter's first number; a hauler walking
## home with nothing in hand counts: he takes the next request on the way).
func haulers_free() -> int:
	return haulers().filter(func(u) -> bool: return u.haul_job.is_empty() or String(u.haul_job.get("ph", "")) == "home").size()


## How many workers it takes. A Brood Feeding Pit takes more the farther it is from the capital
## (Defs.PIT_CREW_STEP); everything else its `crew`.
func crew_max() -> int:
	if kind == Defs.GEAR_PRESS:
		return int(Defs.GEAR["press"]["big" if gear_big else "small"]["crew"])      # (its connecting gear sets the crew)
	if Defs.gear_mode and d["faction"] == "clockwork" and (kind == "clocktower" or kind == "boiler"):
		return 0        # (gear mode: Winders no longer haul batteries; the Clocktower and Boilers have no crew)
	var base := Defs.crew_cap(d)
	if kind == "feeding_pit" and game != null and game.capital(team) != null:
		var far := game.capital_dist(team, center())
		return mini(base + maxi(0, int((far - Defs.FOOD_NEAR) / Defs.PIT_CREW_STEP)), Defs.PIT_CREW_MAX)
	return base


## Farm: share of full growing speed (1.0 with a full crew of 8; every hand counts the same).
func farm_speed() -> float:
	return Defs.FARM_BASE + (1.0 - Defs.FARM_BASE) * mini(working_crew(), int(d["crew"])) / float(d["crew"])


## Cog Press: cogs a second right now. A trickle by itself (`base` of the full rate, like a farm with nobody on it),
## every Winder winding it adds an equal share up to its crew cap; 0 while it is unlinked, unfinished or swapping gears.
func press_rate() -> float:
	if kind != Defs.GEAR_PRESS or not built or dead:
		return 0.0
	if game.gear_net.speed_mult(self) <= 0.0:
		return 0.0
	var gp: Dictionary = Defs.GEAR["press"]
	var info: Dictionary = gp["big" if gear_big else "small"]
	var cap := int(info["crew"])
	var base := float(gp["base"])
	return float(info["full"]) * (base + (1.0 - base) * float(mini(working_crew(), cap)) / float(cap))


## Mainspring: Tension a second right now (Defs.GEAR "mainspring"): a trickle by itself, every Winder on it adds an equal
## share up to its crew; 0 while it is unlinked or unfinished.
func spring_rate() -> float:
	if kind != "mainspring" or not built or dead or game.gear_net.speed_mult(self) <= 0.0:
		return 0.0
	var info: Dictionary = Defs.GEAR["mainspring"]
	var cap := int(d.get("crew", 3))
	var base := float(info["base"])
	return float(info["full"]) * (base + (1.0 - base) * float(mini(working_crew(), cap)) / float(cap))


## Cog Press / Mainspring / Movement Works / Regulator / Escapement: the painted working loop (assets/buildings/<kind>_work_0..7.png,
## `dt` seconds a frame: Defs.GEAR "frame_dt" by default) while it works; the built picture while it idles, and none of it
## once it is damaged (under half its hp).
func _gear_anim(working: bool, dt := -1.0) -> void:
	if sprite == null:
		return
	if not working or hp < max_hp * 0.5:
		if drill_anim:
			drill_anim = false
			_update_sprite()
		return
	var i := int(game.clock / (dt if dt > 0.0 else float(Defs.GEAR["frame_dt"]))) % 8
	var t := Game.tex("res://assets/buildings/%s_work_%d.png" % [kind, i])
	if t == null:
		return
	drill_anim = true
	if sprite.texture != t:
		sprite.texture = t
		sprite.offset = body_offset(kind, t)


## Town Hall / Hive / Clocktower: the full reserve of its land (Crown soil, Brood ground,
## Clockwork coal for its Boilers).
func reserve() -> float:
	if kind == "clocktower":
		return float(Defs.COAL_RESERVE)
	return float(Defs.GROUND_RESERVE if kind == "hive" else Defs.SOIL_RESERVE)


## Farm / Feeding Pit: share of its hall's soil (ground) left (0..1); 0 with no hall.
## Town Hall / Hive: its own.
func soil_left() -> float:
	var h: Building = game.soil_hall(self) if kind == "farm" or kind == "feeding_pit" or kind == "boiler" else self
	return clampf(h.soil / h.reserve(), 0.0, 1.0) if h else 0.0


## Town Hall / Clocktower: its full lode (saltpetre / ore); 0 for anything else.
func lode_full() -> float:
	return float(Defs.LODE.get(kind, 0.0))


## Powder Mill / Ore Crusher / Boiler: share of its hall's lode left (0..1), 0 with no hall;
## a Town Hall / Clocktower: its own.
func lode_left() -> float:
	var h: Building = self if Defs.LODE.has(kind) else game.lode_hall(self)
	return clampf(h.lode / h.lode_full(), 0.0, 1.0) if h else 0.0


## TOTAL EXHAUSTION (design_principles 2: economy forces expansion and is depletable): a Farm,
## Feeding Pit, Powder Mill, Ore Crusher or Boiler whose land is fully spent yields nothing and
## its crew is let go (Unit._gather) to find fresh land. The Clocktower itself is never barren.
func barren() -> bool:
	match kind:
		"farm", "feeding_pit", "boiler":
			return soil_left() <= 0.0
		"powder_mill", "ore_crusher", "ore_drill":
			return lode_left() <= 0.0
	return false      # (a Cog Press is never barren: spent brass pays it a quarter, Defs.GEAR.spent)


## Economy buildings (and the Clocktower): production efficiency right now, as
## [efficiency 0..1, crew at work, full crew, reserve left 0..1, reserve name], or [] for
## anything else. Efficiency = staffing x the reserve's state: 100% fresh, falling to the
## share it still pays once spent (none: spent land is barren). An Ore Crusher has no crew of its own: its staffing is its Clocktower's battery
## carriers (the Winders on the Clocktower and its Boilers) against their full crews.
func efficiency() -> Array:
	var have := 0
	var want := 0
	var left := 0.0
	var res := ""
	var trickle := Defs.SOIL_TIRED
	match kind:
		"farm", "powder_mill":
			have = working_crew()
			want = int(d["crew"])
		"cog_press":
			have = working_crew()
			want = crew_max()
		"feeding_pit", "boiler", "clocktower":
			if Defs.gear_mode:
				return []        # (the Clocktower and Boilers have no crew in gear mode)
			have = crew.size()
			want = crew_max()
		"ore_crusher":
			var h := game.lode_hall(self)
			if h:
				for b in game.battery_sources(h):
					have += b.crew.size()
					want += int(b.d.get("crew", 0))
		"ore_drill":
			have = 1 if game.line_net.speed_mult(self) > 0.0 else 0       # (the Line's pressure is its staff)
			want = 1
		_:
			return []
	match kind:
		"farm", "feeding_pit":
			left = soil_left()
			res = "soil" if kind == "farm" else "ground"
		"boiler":
			# a Boiler burns its Clocktower's coal (nothing once it's spent)
			left = soil_left()
			res = "coal"
			trickle = Defs.COAL_SPENT
		_:
			left = lode_left()
			res = "saltpetre" if kind == "powder_mill" else ("brass" if kind == "cog_press" else "ore")
			trickle = float(Defs.GEAR["spent"]) if kind == "cog_press" else Defs.LODE_SPENT
	var staff := clampf(float(have) / float(want), 0.0, 1.0) if want > 0 else 0.0
	return [staff * (trickle + (1.0 - trickle) * left), have, want, left, res]


func _econ(delta: float) -> void:
	if not crew.is_empty():
		var keep := true
		for u in crew:
			if not is_instance_valid(u) or u.dead or u.home_mine != self:
				keep = false
				break
		if not keep:
			crew = crew.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead and u.home_mine == self)
	match kind:
		"farm":
			if barren():
				return          # barren soil: nothing grows
			growth += farm_speed() / Defs.FARM_GROW * delta
			if growth >= 1.0:
				growth = 0.0
				var pay := game.harvest(self)
				_update_sprite()
				Sfx.play("work/farm_harvest", center(), -4.0)
				if team == game.human:
					game.float_text(center() + Vector2(0, -30), "+%d harvest" % pay, Color(1, 0.9, 0.4) if pay >= Defs.FARM_YIELD else Color(0.85, 0.7, 0.45))
					Sfx.play("done", center())
		"ore_drill":
			OreDrill.tick(self, delta)
		"cog_press":
			# presses cogs from its Clocktower's brass at press_rate() a second (a quarter once the brass is spent)
			while crew.size() > crew_max():
				var extra: Unit = crew.pop_back()
				if is_instance_valid(extra) and not extra.dead:
					extra.cmd_stop()          # (a swap to the small gear lets the extra Winders go: WORK finds them another post)
			var rate := press_rate()
			if rate > 0.0:
				var pay := game.draw_lode(self, rate * delta)
				press_paid += pay
				game.add_gold_f(team, pay)
			_gear_anim(working_crew() > 0 and rate > 0.0)
		"mainspring":
			# winds TENSION (the Clockwork's second resource, nothing spends it yet) while it is linked and crewed
			var sr := spring_rate()
			if sr > 0.0:
				game.players[team]["tension"] = float(game.players[team].get("tension", 0.0)) + sr * delta
			_gear_anim(working_crew() > 0 and sr > 0.0)
		"movement_works":
			# the hanging line runs while it assembles a Clock Soldier and is linked
			_gear_anim(not queue.is_empty() and game.gear_net.speed_mult(self) > 0.0, float(Defs.GEAR["works_dt"]))
		"regulator":
			# a clock: the pendulum swings whenever it is built and linked
			_gear_anim(game.gear_net.speed_mult(self) > 0.0, float(Defs.GEAR["regulator_dt"]))
		"escapement":
			# the anchor rocks and the wheel ticks while it works: linked and meshed with a Mainspring (the Tension rule)
			_gear_anim(game.gear_net.speed_mult(self) > 0.0, float(Defs.GEAR["escapement_dt"]))
		"powder_mill":
			# grinds its Town Hall's saltpetre; once that's spent, nothing
			var n := working_crew()
			if n > 0:
				game.add_res2(team, game.draw_lode(self, Defs.MILL_RATE * n * delta))


var _fetch_t := 0.0


## The front entry is a gun or wagon whose reserved horse hasn't walked in yet.
func _horse_pending(k: String) -> bool:
	return not is_research(k) and not Defs.RIDERS.has(k) and Defs.UNITS[k].get("needs_horse", false) and int(kit_at(0).get("rid", 0)) != 0


func uses_eggs() -> bool:
	return d.get("eggs", false)


var _redraw_t := 0.0
var _was_selected := false


func _physics_process(delta: float) -> void:
	if game.puppet:
		return NetPuppet.tick_building(self, delta)      # (online guest: shown from snapshots, not simulated)
	var _p0 := Time.get_ticks_usec()
	_tick_building(delta)
	Prof.bld_us += Time.get_ticks_usec() - _p0
	Prof.bld_n += 1


func _tick_building(delta: float) -> void:
	_process_flash(delta)
	_process_acid(delta)
	if rally_target is Unit:
		# a rally on one of ours follows him (gone: it stays where he was last)
		if is_instance_valid(rally_target) and not rally_target.dead:
			if rally.distance_squared_to(rally_target.position) > 16.0:
				rally = rally_target.position
				queue_redraw()
		else:
			rally_target = null
	if dead:
		rubble_t += delta
		if rubble_t > 25.0:
			modulate.a = maxf(0.0, 1.0 - (rubble_t - 25.0) / 3.0)
			if rubble_t > 28.0:
				queue_free()
		return
	if built and not dead and kind == "gate":
		_gate(delta)
	_check_use(delta)
	if sails and sails.visible:
		_turn_sails(delta)
	if _mill_state != "":
		_turn_mill(delta)
	if life:
		life.tick(delta)
	if turret:
		turret.tick(delta)
	if built and not dead:
		_econ(delta)
		if d.has("field") and not Defs.gear_mode:
			_tower(delta)      # (gear mode: no power, so no lightning; the Ratchet Turret is the defence)
		_ambient(delta)
	if d["faction"] == "brood":
		_brood(delta)
	elif d["faction"] == "clockwork":
		if not built and seeded:
			add_progress(delta)
		if unfold_t >= 0.0:
			_unfold_tick(delta)
		if built and d.has("battery") and not Defs.gear_mode:      # (gear mode: no power, no batteries)
			var bat: Array = d["battery"]
			if batteries < int(bat[1]):
				_bat_t += delta
				# a Boiler burns its Clocktower's coal; on spent coal it stops
				var every := float(bat[0])
				var coal: Building = game.soil_hall(self) if kind == "boiler" else null
				if kind == "boiler" and (coal == null or coal.soil < 1.0 or game.gear_net.speed_mult(self) <= 0.0):
					_bat_t = 0.0        # barren coal: no more batteries
					every = INF
				if _bat_t >= every:
					_bat_t = 0.0
					batteries += 1
					if coal and coal.soil >= 1.0:
						coal.soil -= 1.0
						game._soil_check(coal)
	if built and uses_eggs():
		# Every egg morphs at the same time.
		var i := 0
		while i < queue.size():
			morph_t[i] += delta
			if morph_t[i] >= float(Defs.UNITS[queue[i]]["time"]):
				var k: String = queue[i]
				var kit := take_entry(i)
				morph_t.remove_at(i)
				game.spawn_trained(self, k, kit)
			else:
				i += 1
	elif built and not queue.is_empty():
		prod_t += delta * (game.asm_mult[team] * game.line_net.speed_mult(self) if d["faction"] == "clockwork" else 1.0)
		var k: String = queue[0]
		if prod_t >= entry_time(k) and _horse_pending(k):
			# a gun is ready, its horse isn't here yet: it comes out when the horse walks in
			prod_t = entry_time(k)
			_fetch_t -= delta
			if _fetch_t <= 0.0:
				_fetch_t = 1.0
				game.fetch_reserved(self, 0)
		elif prod_t >= entry_time(k):
			prod_t = 0.0
			var kit := take_entry(0)
			if is_research(k):
				game.research_done(self, k.substr(1))
			else:
				game.spawn_trained(self, k, kit)
				if life:
					life.trained()       # (a hall's bell rings)
	if built and auto_train != "" and not dead:
		_auto_t -= delta
		if _auto_t <= 0.0:
			_auto_t = 0.5
			if (uses_eggs() and eggs > 0) or (not uses_eggs() and queue.is_empty()):
				game.train(self, auto_train)
	_update_fire()
	# bars and labels change slowly: redraw 6 times a second, or at once when picked (off
	# screen not at all: at once when it comes into view)
	_redraw_t -= delta
	if not selected and not _was_selected and not game.view_rect.intersects(rect()):
		_redraw_t = 0.0
	elif _redraw_t <= 0.0 or selected != _was_selected:
		_redraw_t = 0.16
		_was_selected = selected
		queue_redraw()


## Gate: swings open while a friendly unit means to go through (its path crosses the gate,
## or it's right at it and walking in) and no enemy is close (the open picture is only for
## show: friends can always pass, enemies never can). Friends idling beside it don't hold it open.
var gate_open := false
var vertical := false            # a gate in a north-south wall: drawn side-on
var dir_locked := false          # turned by hand: stays as it is
var locked := false              # Gate: locked shut by its owner (Game.set_gate_locked): nobody passes, friends included


func set_vertical(v: bool) -> void:
	if vertical != v:
		vertical = v
		_update_sprite()
		if game and not dead:
			game.relink_walls(cell)     # the palisade beside it joins it the other way now
var _gate_t := 0.0
var _swing_t := 0.0              # the gate is swinging (opening or shutting): drawn half open
const GATE_SWING := 0.3


## Palisade (kind "wall"): which neighbours this piece joins (Game.wall_links: N 1, E 2,
## S 4, W 8), and so which picture it shows, like Age of Empires 2's walls.
var links := 2 | 8


func set_links(m: int) -> void:
	if links != m:
		links = m
		_update_sprite()


## The picture of a palisade piece joined to these neighbours (assets/buildings, made by
## tools/import_palisade.py): "wall_<links>_built", links in "nesw" order, "post" for none.
static func wall_piece(m: int) -> String:
	var out := ""
	for i in 4:
		if m & (1 << i):
			out += "nesw"[i]
	return "wall_%s" % (out if out != "" else "post")


## A palisade piece's construction / damaged / destroyed picture: the straight's that runs
## the piece's way (east-west when it joins east or west, else north-south).
static func wall_axis(m: int) -> String:
	return "wall_ew" if m & (2 | 8) else "wall_ns"


func _gate(delta: float) -> void:
	if _swing_t > 0.0:
		_swing_t -= delta
		if _swing_t <= 0.0:
			_update_sprite()
	_gate_t -= delta
	if _gate_t > 0.0:
		return
	_gate_t = 0.25
	var friend := false
	var foe := false
	var c := rect().get_center()
	for u in game.units_near(c, 200.0):
		if u.dead or u.is_air():
			continue
		if not game.allied(u.team, team):
			if u.position.distance_to(c) < 56.0:
				foe = true
		elif not friend and crossing(u):
			friend = true
	var want := friend and not foe and not locked
	if want != gate_open:
		gate_open = want
		_swing_t = GATE_SWING
		_update_sprite()
		queue_redraw()


## Gate: does this friendly unit mean to go through? Standing in the gateway, its path
## (the next few legs) running through the gate cell, or within about half a cell of it
## and walking toward it.
func crossing(u: Unit) -> bool:
	var r := rect()
	if r.has_point(u.position):
		return true
	var c := r.get_center()
	var to := c - u.position
	if r.grow(Defs.TILE * 0.5).has_point(u.position) and u.velocity.length() > 8.0 and u.velocity.dot(to) > 0.0:
		return true
	var hit := r.grow(2.0)
	var from := u.position
	if u.path_pending:
		return u.path_goal != Vector2.INF and _seg_hits(hit, from, u.path_goal)
	for i in range(u.path_i, mini(u.path.size(), u.path_i + 3)):
		if _seg_hits(hit, from, u.path[i]):
			return true
		from = u.path[i]
	return false


static func _seg_hits(r: Rect2, a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 6.0) + 1
	for k in n + 1:
		if r.has_point(a.lerp(b, float(k) / float(n))):
			return true
	return false


## The swamp radius this building grows to. The Brood's capital reaches farther (CAPITAL_SWAMP_BONUS)
## so that a normal main base is swamp from edge to edge; a very big main is not fully covered.
func swamp_target() -> float:
	var r := float(d.get("swamp", 0))
	if r > 0.0 and d.get("eggs", false) and game != null and game.capital(team) == self:
		r += Defs.CAPITAL_SWAMP_BONUS
	return r


func _brood(delta: float) -> void:
	if not built and seeded:
		add_progress(delta)
	if built:
		if hp < max_hp:
			hp = minf(max_hp, hp + 1.5 * delta)
		var target := swamp_target()
		if swamp_r > target + 0.01:
			swamp_r = target
			game.swamp_dirty = true
		if swamp_r < target:
			swamp_r = minf(target, swamp_r + delta / 1.2)
			game.swamp_dirty = true
		# Eggs: the ones already hatching don't stop the Hive laying new ones, and every
		# Clutch Mound makes it lay faster (a swarm's output grows with its economy).
		if uses_eggs() and eggs < eggs_max():
			egg_t += delta * game.egg_rate(team)
			if egg_t >= Defs.EGG_TIME:
				egg_t = 0.0
				eggs += 1
		# growing into the next level (it goes on laying and hatching meanwhile)
		if upgrade_t >= 0.0:
			upgrade_t += delta
			var nl := next_level()
			if nl.is_empty():
				upgrade_t = -1.0
			elif upgrade_t >= float(nl["time"]):
				upgrade_t = -1.0
				game.hall_upgraded(self)
	elif seeded and swamp_r < 2.0:
		swamp_r = 2.0
		game.swamp_dirty = true


func _update_fire() -> void:
	var burning: bool = built and hp < max_hp * 0.5 and d["faction"] != "brood"
	if burning and fire == null:
		var big := randf() < 0.5
		fire = game.spawn_effect("blaze" if big else "fire", Vector2.ZERO, 0.8 if big else 1.0, true)
		if big:
			fire.scale = Vector2(0.75, 0.75)
		fire.reparent(self, false)
		fire.position = Vector2(randf_range(-12, 12), -(50.0 if kind == "farm" else rect().size.y * 0.75))
		fire.z_index = 1
	elif not burning and fire:
		fire.queue_free()
		fire = null
	# the picture only when something it shows changed (its state, a gate's swing, the
	# construction's fade, a farm's crop and tired soil: the soil looked at once a second)
	if kind == "farm" or kind == "feeding_pit":
		_soil_key_t -= get_physics_process_delta_time()
		if _soil_key_t <= 0.0:
			_soil_key_t = 1.0
			_soil_key = int(soil_left() * 200.0)
	var sk := Vector4i(int(dead) + 2 * int(built) + 4 * int(hp < max_hp * 0.5) + 8 * int(seeded) + 16 * int(gate_open) + 32 * int(_swing_t > 0.0) + 64 * int(vertical),
		links, int(progress * 400.0) + (int(unfold_t * 30.0) + 1) * 1000 if unfold_t >= 0.0 else int(progress * 400.0),
		_soil_key + 1000 * (0 if growth < 0.12 else (1 if growth < 0.6 else 2)))
	if sk != _sprite_key:
		_sprite_key = sk
		_update_sprite()


var _sprite_key := Vector4i(-1, -1, -1, -1)
var _soil_key := 0
var _soil_key_t := 0.0


## A point on the sprite, given as fractions of its size, in world space.
func sprite_point(fx: float, fy: float) -> Vector2:
	if sprite == null or sprite.texture == null:
		return center()
	return global_position + sprite.offset + Vector2(sprite.texture.get_width() * fx, sprite.texture.get_height() * fy)


func top_point() -> Vector2:
	var f: Vector2 = TOWER_TOP.get(kind, Vector2(0.5, 0.1))
	return sprite_point(f.x, f.y)


## Clockwork towers shoot chain lightning up at flyers; while they do, their field is off.
func _tower(delta: float) -> void:
	zap_cd = maxf(zap_cd - delta, 0.0)
	zap_off_t = maxf(zap_off_t - delta, 0.0)
	_zap_scan -= delta
	if _zap_scan > 0.0 or zap_cd > 0.0:
		return
	_zap_scan = 0.3
	var r := float(Defs.TOWER_ZAP["range"]) * Defs.TILE
	var best: Unit = null
	var bd := r
	for u in game.units_near(center(), r):
		if u.is_air() and not u.dead and game.hostile(u.team, team) and not u.off_field:
			var dd: float = u.position.distance_to(center())
			if dd < bd:
				bd = dd
				best = u
	if best:
		zap_cd = Defs.TOWER_ZAP["cooldown"]
		zap_off_t = Defs.TOWER_ZAP["off"]
		game.tower_zap(self, best)


func field_on() -> bool:
	return zap_off_t <= 0.0


## Idle life: smoke, steam, spores and, on Clockwork towers, constant crackle. Only when
## somebody could see it.
func _ambient(delta: float) -> void:
	var shown := (visible or team == game.human) and game.view_rect.has_point(global_position)
	if TOWER_TOP.has(kind) and ArtData.EFFECTS.has("zap_spark"):
		if _crackle == null:
			_crackle = Effect.new()
			_crackle.setup("zap_spark", 1.0, true)
			_crackle.z_index = 2
			add_child(_crackle)
		_crackle.global_position = top_point()
		_crackle.visible = shown
		_crackle.modulate = Color(1, 1, 1, 0.35) if not field_on() else Color.WHITE
	if not shown or not _in_use:
		return            # (a workshop's smoke, a mill's dust: only while it's in use)
	var list: Array = AMBIENT.get(kind, [])
	if list.is_empty():
		return
	_amb_t += delta
	for i in list.size():
		var e: Array = list[i]
		var period: float = e[3]
		# each emitter keeps its own rhythm
		if fmod(_amb_t + i * 0.37 + float(get_instance_id() % 13) * 0.11, period) < delta:
			if not ArtData.EFFECTS.has(e[0]):
				continue
			var fx := game.spawn_effect(e[0], sprite_point(e[1], e[2]) + Vector2(randf_range(-2, 2), 0), 0.8)
			fx.scale = Vector2(e[4], e[4])
			fx.modulate = e[5]
			fx.z_index = 4


static var _hall_art := {}


## A Brood hall level's sprites: [sheet name, scale]. Its own sheet once imported
## (Defs.HALL_LEVELS "art": assets/buildings/<art>_built.png), else the Burrow's drawn bigger.
static func hall_art(lv: int) -> Array:
	if not _hall_art.has(lv):
		var li: Dictionary = Defs.HALL_LEVELS[clampi(lv, 1, Defs.HALL_LEVELS.size()) - 1]
		var own := String(li["art"])
		if ResourceLoader.exists("res://assets/buildings/%s_built.png" % own):
			_hall_art[lv] = [own, 1.0]
		else:
			_hall_art[lv] = ["hive", float(li["scale"])]
	return _hall_art[lv]


func _update_sprite() -> void:
	if sprite == null:
		return
	var state := "built"
	if dead:
		state = "destroyed"
	elif not built:
		state = "construction"
	elif hp < max_hp * 0.5:
		state = "damaged"
	if kind == "gate" and built and not dead and _swing_t > 0.0:
		state = "half"
	elif kind == "gate" and built and not dead and gate_open:
		state = "open_damaged" if state == "damaged" else "open"
	var base := String(Defs.TEMP_ART.get(kind, {}).get("building", kind))    # (temporary art: Defs.TEMP_ART)
	if base != kind and LineArt.has_building(kind):
		base = kind        # (the real picture has been imported: tools/import_line_art.py)
	if kind == "gate" and vertical and ResourceLoader.exists("res://assets/buildings/gate_v_%s.png" % state):
		base = "gate_v"
	if kind == "wall":
		base = wall_piece(links) if state == "built" else wall_axis(links)
	if is_leveled():
		var art := hall_art(level)
		base = String(art[0])
		var sc := float(art[1])
		if sprite.scale.x != sc:
			# (bigger, standing on the same base line)
			sprite.scale = Vector2(sc, sc)
			sprite.position.y = 6.0 * (1.0 - sc)
	var t := farm_body(state) if kind == "farm" else Game.tex("res://assets/buildings/%s_%s.png" % [base, state])
	if t == null and is_leveled():
		# (a level's art not imported yet: draw the Burrow, scaled)
		t = Game.tex("res://assets/buildings/%s_%s.png" % [kind, state])
	if sprite.texture != t and t != null:
		sprite.texture = t
		sprite.offset = body_offset(kind, t)
		if kind == "gate":
			# a gate's posts overlap the palisade beside it: it sorts a pixel lower, so it's
			# drawn over its neighbours on the same row (and still behind units in front)
			sprite.position.y = 1.0
			sprite.offset.y -= 1.0
	if sails:
		sails.visible = seeded and Array(FARM_ART["sail_states"]).has(state)
	if _mill_horse:
		_mill_show(state)
	if _mill_ground and sprite.texture != null:
		var gt := Game.tex("res://assets/buildings/%s_%s_ground.png" % [base, state])
		if _mill_ground.texture != gt:
			_mill_ground.texture = gt
		_mill_ground.position = sprite.position
		_mill_ground.offset = sprite.offset
	if life:
		life.show(state)
	if turret:
		turret.head.visible = built and not dead      # (also on an online guest, whose buildings are not ticked)
	if not seeded and not dead:
		sprite.modulate = Color(1, 1, 1, 0.3)
	elif unfold_t >= 0.0 and not dead:
		# the crate unfolding on the ghost of the site; the scaffold fades in at the end
		var fade_from := 5.0 * float(Defs.CRATE["unfold"]) + float(Defs.CRATE["hold"])
		var k := clampf((unfold_t - fade_from) / float(Defs.CRATE["fade"]), 0.0, 1.0)
		sprite.modulate = Color(1, 1, 1, lerpf(0.0, 0.55 + 0.45 * progress, k))
	else:
		sprite.modulate = Color(1, 1, 1, 0.55 + 0.45 * progress) if not built and not dead else Color.WHITE
		if kind == "farm" and built and not dead and game:
			# tired soil: the fields fade toward a dry yellow-brown
			var tired := clampf(1.0 - soil_left() / Defs.SOIL_LOW, 0.0, 1.0)
			sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.78, 0.5), tired)
			if field:
				field.modulate = sprite.modulate
		if field:
			# bare furrows while it's built (and once it's a ruin), green shoots after each
			# harvest, gold before the next
			var stage := "bare" if not built or dead or growth < 0.12 else ("young" if growth < 0.6 else "ripe")
			var ft := Game.tex("res://assets/buildings/farm_field_%s.png" % stage)
			if field.texture != ft:
				field.texture = ft
			if dead:
				field.modulate = Color(0.55, 0.5, 0.45)
			elif not built:
				field.modulate = sprite.modulate
			for s in scarecrow_sprites:
				s.visible = built or dead
				s.modulate = field.modulate
		if kind == "feeding_pit" and built and not dead and game:
			# spent ground: the pit dries out to a dead grey-brown
			var tired := clampf(1.0 - soil_left() / Defs.SOIL_LOW, 0.0, 1.0)
			sprite.modulate = Color.WHITE.lerp(Color(0.62, 0.56, 0.48), tired)
	if _mill_ground:
		_mill_ground.modulate = sprite.modulate


func die() -> void:
	if dead:
		return
	var was_site := not built
	dead = true
	selected = false
	if turret:
		turret.head.visible = false      # (the ruin has the head lying in its rubble)
	if team == game.human and built and not game.over:
		Sfx.announce(d["faction"], "building_lost", 6.0)
	elif team == game.human and not built and not ghost and not game.over and hp <= 0.0:
		Sfx.announce(d["faction"], "site_lost", 6.0)     # (destroyed, not cancelled)
	for i in queue.size():
		game.refund(team, queue[i], kit_at(i), self)
	queue.clear()
	kits.clear()
	if upgrade_t >= 0.0:
		game.cancel_hall_upgrade(self, true)
	for u in crew:
		if is_instance_valid(u) and not u.dead:
			u.cmd_stop()
	crew.clear()
	morph_t.clear()
	unfold_t = -1.0
	if _unfold:
		_unfold.queue_free()
		_unfold = null
	swamp_r = 0.0
	game.swamp_dirty = true
	if fire:
		fire.queue_free()
		fire = null
	game.on_building_died(self)
	Sfx.play_any(["combat/building_collapse", "collapse"], global_position)
	Sfx.play("combat/explosion_big", global_position, -4.0)
	_update_sprite()
	z_index = -1
	game.spawn_effect("dust", global_position + Vector2(0, -rect().size.y * 0.4), 2.2)
	if d["faction"] != "brood":
		for i in 3:
			var fx := game.spawn_effect(["explosion", "burst", "flame"][i], global_position + Vector2(randf_range(-0.35, 0.35) * rect().size.x, -randf_range(0.2, 0.7) * rect().size.y), 1.5 + i * 0.3)
			fx.scale = Vector2(0.9, 0.9)
		var sm := game.spawn_effect("smoke_big", global_position + Vector2(0, -rect().size.y * 0.5), 0.9)
		sm.modulate.a = 0.8
	# a site that never got finished (abandoned or wrecked) leaves nothing behind
	if was_site:
		if sprite:
			sprite.visible = false
		if field:
			field.visible = false
		if _mill_ground:
			_mill_ground.visible = false
		rubble_t = 27.5


## The windmill's sails: a frame every sail_dt s, slower as the soil tires, still once spent;
## only while the Farm is worked (in_use): they ease to a stop over SAIL_EASE s when nobody
## works its fields, and back up to speed when work starts again.
const SAIL_EASE := 1.5


func _turn_sails(delta: float) -> void:
	_sail_v = move_toward(_sail_v, 1.0 if _in_use else 0.0, delta / SAIL_EASE)
	if _sail_v <= 0.0:
		return
	_sail_t += delta * smoothstep(0.0, 1.0, _sail_v)
	var dt := float(FARM_ART["sail_dt"])
	if _sail_t < dt:
		return
	_sail_t -= dt
	if not built or dead or not game:
		return
	var tired := clampf(1.0 - soil_left() / Defs.SOIL_LOW, 0.0, 1.0)
	if tired >= 1.0 or randf() < tired * 0.75:
		return
	sails.frame = (sails.frame + 1) % sails.hframes


func _draw() -> void:
	var _p0 := Time.get_ticks_usec()
	_draw_building()
	Prof.add("building draw", _p0)


## Where its bars go (local y): just above the top of the drawing itself, not the picture's
## empty margin (the Farm: its windmill's top).
func bar_top() -> float:
	if kind == "farm":
		return float(FARM_ART["top"])
	if sprite and sprite.texture:
		return sprite.position.y + (sprite.offset.y + game._tex_top(sprite.texture)) * sprite.scale.y + 2.0
	return -rect().size.y


## A gate's state, as a padlock ABOVE the gate (drawn here, no picture, big enough to read at
## once): a RED closed lock when it is locked shut, a YELLOW open lock (the shackle swung up
## and out to the side) when it is unlocked. No words.
func _draw_lock(top: float) -> void:
	var c := Vector2(0.0, top - 16.0)
	var dark := Color(0.06, 0.04, 0.04, 0.95)
	var body := Color(0.88, 0.16, 0.14) if locked else Color(1.0, 0.82, 0.18)
	var lite := body.lightened(0.35)
	var shade := body.darkened(0.35)
	var steel := Color(0.8, 0.84, 0.88)
	var s := 0.8
	# the shackle
	if locked:
		draw_arc(c + Vector2(0, -6) * s, 6.4 * s, PI, TAU, 16, dark, 6.0 * s)
		draw_arc(c + Vector2(0, -6) * s, 6.4 * s, PI, TAU, 16, steel, 3.0 * s)
		draw_line(c + Vector2(-6.4, -6) * s, c + Vector2(-6.4, -1) * s, steel, 3.0 * s)
		draw_line(c + Vector2(6.4, -6) * s, c + Vector2(6.4, -1) * s, steel, 3.0 * s)
	else:
		# open: the right leg lifted clear of the body, the whole bar swung up and to the side
		var o := Vector2(9.0, -6.0) * s
		draw_arc(c + o, 6.4 * s, PI, TAU, 16, dark, 6.0 * s)
		draw_arc(c + o, 6.4 * s, PI, TAU, 16, steel, 3.0 * s)
		draw_line(c + o + Vector2(-6.4, 0) * s, c + o + Vector2(-6.4, 5) * s, steel, 3.0 * s)
		draw_line(c + o + Vector2(-6.4, 5) * s, c + Vector2(-6.4, -1) * s, steel, 3.0 * s)
	# the body, with its keyhole
	draw_rect(Rect2(c + Vector2(-9.5, -1.5) * s, Vector2(19, 15) * s).grow(1.5), dark)
	draw_rect(Rect2(c + Vector2(-9.5, -1.5) * s, Vector2(19, 15) * s), body)
	draw_rect(Rect2(c + Vector2(-9.5, -1.5) * s, Vector2(19, 4) * s), lite)
	draw_rect(Rect2(c + Vector2(-9.5, 10.0) * s, Vector2(19, 3.5) * s), shade)
	draw_circle(c + Vector2(0, 5.0) * s, 2.3 * s, dark)
	draw_rect(Rect2(c + Vector2(-1.1, 5.5) * s, Vector2(2.2, 5.0) * s), dark)


func _draw_building() -> void:
	if dead:
		return
	var r := rect()
	var local := Rect2(r.position - global_position, r.size)
	if selected:
		draw_rect(local.grow(3), Color(0.4, 1.0, 0.4, 0.8), false, 2.0)
		if rally != Vector2.INF and (team == game.human or game.spectating()):
			draw_dashed_line(Vector2(0, -r.size.y * 0.5), rally - global_position, Color(0.4, 1, 0.4, 0.6), 2.0, 8.0)
			draw_circle(rally - global_position, 4, Color(0.4, 1, 0.4, 0.9))
		if worker_rally != Vector2.INF and (team == game.human or game.spectating()):
			draw_dashed_line(Vector2(0, -r.size.y * 0.5), worker_rally - global_position, Color(1, 0.85, 0.3, 0.6), 2.0, 6.0)
			draw_circle(worker_rally - global_position, 4, Color(1, 0.85, 0.3, 0.9))
	var top := bar_top()
	if not ghost:
		draw_health(top, r.size.x * 0.7)
	if kind == "gate" and built and (team == game.human or game.demo or game.reveal):
		_draw_lock(top)
	if built and uses_eggs() and (team == game.human or game.demo):
		# its eggs ready, over it: "3/5" (the number every Brood unit hatches from)
		var font := ThemeDB.fallback_font
		var txt := "%d/%d" % [eggs, eggs_max()]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var p := Vector2(-w * 0.5, top - 6.0)
		draw_rect(Rect2(p + Vector2(-4, -14), Vector2(w + 8, 18)), Color(0, 0, 0, 0.6))
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 1.0, 0.55) if eggs > 0 else Color(1.0, 0.55, 0.45))
		if game.capital(team) == self:
			# the CAPITAL (the only Burrow grubs unload at; where the Queen sits)
			var cap_txt := Loc.t("CAPITAL")
			var cw := font.get_string_size(cap_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var cp := Vector2(-cw * 0.5, top - 28.0)
			draw_rect(Rect2(cp + Vector2(-4, -12), Vector2(cw + 8, 16)), Color(0.35, 0.2, 0.0, 0.75))
			draw_string(font, cp, cap_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.3))
	# full batteries waiting at an energy building
	if built and batteries > 0 and (team == game.human or game.demo or game.reveal):
		var bt: Texture2D = Game.tex("res://assets/effects/battery_%s.png" % ("blue" if game.blue_energy(team) else "yellow"))
		var fw := 11.0
		for i in batteries:
			draw_texture_rect_region(bt, Rect2(-r.size.x * 0.5 + 2 + i * 8, -18, 8, 16), Rect2(0, 0, fw, 22))
	if not built:
		var w := r.size.x * 0.7
		draw_rect(Rect2(-w * 0.5, top + 7, w, 4).grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, top + 7, w * progress, 4), Color(0.95, 0.8, 0.3))
	elif kind == "farm" and (team == game.human or game.spectating()):
		var w := r.size.x * 0.7
		# (just under the crew label and above the windmill's top: lower it hid behind the mill)
		draw_rect(Rect2(-w * 0.5, top - 1, w, 4).grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, top - 1, w * growth, 4), Color(0.95, 0.85, 0.3))
	elif not queue.is_empty() and team == game.human:
		var w := r.size.x * 0.7
		var k: String = queue[0]
		var f: float = (morph_t[0] if uses_eggs() else prod_t) / entry_time(k)
		draw_rect(Rect2(-w * 0.5, top + 7, w, 4).grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, top + 7, w * f, 4), Color(0.75, 0.55, 1.0) if is_research(k) else Color(0.4, 0.75, 1.0))
	if built and upgrade_t >= 0.0 and not next_level().is_empty() and (team == game.human or game.spectating()):
		# growing into the next level: a violet bar under the others
		var w := r.size.x * 0.7
		var f := clampf(upgrade_t / float(next_level()["time"]), 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5, top + 13, w, 4).grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, top + 13, w * f, 4), Color(0.75, 0.55, 1.0))
