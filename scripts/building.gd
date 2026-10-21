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
var prod_t := 0.0
var batteries := 0               # Clockwork: full batteries waiting to be carried off
var _bat_t := 0.0
var auto_train := ""             # keep training this unit (right-click / long press on its button)
var _auto_t := 0.0
var rally := Vector2.INF
var rally_target: Entity = null
var worker_rally := Vector2.INF  # Hive: workers and army have separate rally points
var worker_rally_target: Entity = null
var seeded := true               # Brood: a grub has turned into the site
var eggs := 0                    # Brood Hive
var egg_t := 0.0
var morph_t: Array = []          # Brood Hive: time spent on each morphing egg
var swamp_r := 0.0               # Brood: current swamp radius in tiles
var deps: Array = []             # Powder Mill / Ore Crusher: its outcrops within reach (Game.site_deposits)
var deps_done := false
var gold_acc := 0.0
var crew: Array = []             # workers assigned to this economy structure
var growth := 0.0                # Farm: 0..1 until the harvest
var soil := 0.0                  # Town Hall: gold left in its farmland; Hive: biomass left in its ground (full when fresh: reserve())
var soil_warned := 0             # Town Hall: 1 = told the player it's low, 2 = spent
var sprite: Sprite2D
var field: Sprite2D = null       # Farm: its fields, on the ground under the units (they work in them)
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
## fractions of the sprite), seconds between puffs, size, tint]. Only drawn on screen.
const AMBIENT := {
	"town_hall": [["smoke", 0.26, 0.23, 1.6, 0.45, Color(0.85, 0.85, 0.85, 0.6)], ["smoke", 0.87, 0.21, 1.9, 0.4, Color(0.85, 0.85, 0.85, 0.6)]],
	"cottage": [["smoke", 0.45, 0.1, 1.8, 0.4, Color(0.85, 0.85, 0.85, 0.6)]],
	"barracks": [["smoke", 0.16, 0.3, 1.7, 0.4, Color(0.85, 0.85, 0.85, 0.6)], ["smoke", 0.83, 0.05, 2.1, 0.35, Color(0.85, 0.85, 0.85, 0.6)]],
	"foundry": [["smoke", 0.25, 0.06, 0.7, 0.7, Color(0.45, 0.45, 0.45, 0.75)], ["fire", 0.72, 0.68, 1.1, 0.35, Color(1, 1, 1, 0.9)]],
	"powder_mill": [["dust", 0.86, 0.86, 1.4, 0.3, Color(1, 1, 1, 0.6)]],
	"church": [],
	"hive": [["smoke", 0.5, 0.78, 1.3, 0.35, Color(0.6, 1.0, 0.3, 0.55)], ["smoke", 0.22, 0.82, 2.2, 0.3, Color(0.6, 1.0, 0.3, 0.5)], ["smoke", 0.78, 0.82, 2.4, 0.3, Color(0.6, 1.0, 0.3, 0.5)]],
	"warren": [["smoke", 0.5, 0.74, 1.5, 0.35, Color(0.6, 1.0, 0.3, 0.5)]],
	"gorge_pit": [["smoke", 0.5, 0.52, 0.9, 0.45, Color(0.6, 1.0, 0.3, 0.55)]],
	"spore_vent": [["smoke", 0.42, 0.12, 0.8, 0.4, Color(0.75, 1.0, 0.4, 0.6)]],
	"brood_pen": [["smoke", 0.5, 0.45, 1.6, 0.4, Color(0.75, 0.5, 1.0, 0.5)]],
	"feeding_pit": [["acid_splash", 0.5, 0.55, 1.4, 0.5, Color(1, 0.6, 0.6, 0.8)]],
	"clocktower": [["smoke", 0.2, 0.3, 1.1, 0.4, Color(1.2, 1.2, 1.2, 0.6)]],
	"assembly_works": [["smoke", 0.3, 0.04, 0.9, 0.4, Color(1.2, 1.2, 1.2, 0.6)], ["smoke", 0.86, 0.05, 1.1, 0.4, Color(1.2, 1.2, 1.2, 0.6)]],
	"boiler": [["smoke", 0.32, 0.07, 0.7, 0.45, Color(1.2, 1.2, 1.2, 0.65)]],
	"ore_crusher": [["dust", 0.6, 0.55, 1.0, 0.35, Color(0.8, 0.8, 0.8, 0.7)]],
}
## The Farm (5x4 tiles): the farmhouse stands at the back left, its base line this far down
## from the top of the footprint; the fields (tools/make_farm_field.py) fill the rest, and
## each of its labourers works a stretch of one crop row (see field_row).
const FARM_HOUSE_BASE := 60.0
const FARM_HOUSE_X := 56.0
const FARM_ROW := 16.0

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
	if k == "town_hall" or k == "hive":
		soil = reserve()
	if d["faction"] == "brood":
		seeded = complete
		if complete:
			swamp_r = float(d.get("swamp", 0))
		if d.get("eggs", false):
			eggs = Defs.EGGS_MAX if complete else 0
	position = anchor(k, rect())


## Where a building of this kind on this footprint stands (its sprite's base line, which
## also sorts it against the units): the middle of the bottom edge; a Farm's farmhouse at
## the back, with its fields in front.
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
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.material = team_material()
	add_child(sprite)
	_update_sprite()


## The cells of a footprint (from its corner) that stay walkable: a Farm's fields, all but
## the farmhouse's 4x2 block at the back left.
static func field_cells(k: String) -> Array:
	var out: Array = []
	if k == "farm":
		var sz: Vector2i = Defs.BUILDINGS[k]["size"]
		for y in sz.y:
			for x in sz.x:
				if not (x < 4 and y < 2):
					out.append(Vector2i(x, y))
	return out


## Farm: the stretch of crop row the crew member number i works (two to a row, four rows
## across the front), as [from, to] in world space.
func field_row(i: int) -> Array:
	var r := rect()
	var row := (i / 2) % 4
	var y := r.position.y + FARM_HOUSE_BASE + 4.0 + FARM_ROW * (row + 1) - 3.0
	var half := r.size.x * 0.5
	var x0 := r.position.x + 14.0 + (i % 2) * half
	return [Vector2(x0, y), Vector2(x0 + half - 26.0, y)]


func rect() -> Rect2:
	return Rect2(Vector2(cell) * Defs.TILE, Vector2(size) * Defs.TILE)


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


## A production queue entry that is research ("@armour") rather than a unit.
static func is_research(k: String) -> bool:
	return k.begins_with("@")


## Seconds a queue entry takes (a unit's training or a research's time).
static func entry_time(k: String) -> float:
	if is_research(k):
		return float(Defs.RESEARCH[k.substr(1)]["time"])
	return float(Defs.UNITS[k]["time"])


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


## Farm: share of full growing speed (1.0 with a full crew of 8; every hand counts the same).
func farm_speed() -> float:
	return Defs.FARM_BASE + (1.0 - Defs.FARM_BASE) * mini(working_crew(), int(d["crew"])) / float(d["crew"])


## Town Hall / Hive: the full reserve of its land (Crown soil, Brood ground).
func reserve() -> float:
	return float(Defs.GROUND_RESERVE if kind == "hive" else Defs.SOIL_RESERVE)


## Farm / Feeding Pit: share of its hall's soil (ground) left (0..1); 0 with no hall.
## Town Hall / Hive: its own.
func soil_left() -> float:
	var h: Building = game.soil_hall(self) if kind == "farm" or kind == "feeding_pit" else self
	return clampf(h.soil / h.reserve(), 0.0, 1.0) if h else 0.0


func _econ(delta: float) -> void:
	crew = crew.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead and u.home_mine == self)
	match kind:
		"farm":
			growth += farm_speed() / Defs.FARM_GROW * delta
			if growth >= 1.0:
				growth = 0.0
				var pay := game.harvest(self)
				_update_sprite()
				Sfx.play("work/farm_harvest", center(), -4.0)
				if team == game.human:
					game.float_text(center() + Vector2(0, -30), "+%d harvest" % pay, Color(1, 0.9, 0.4) if pay >= Defs.FARM_YIELD else Color(0.85, 0.7, 0.45))
					Sfx.play("done", center())
		"powder_mill":
			# grinds the saltpetre beside it; once that's spent, a quarter
			var n := working_crew()
			if n > 0:
				game.add_res2(team, game.draw_deposits(self, Defs.MILL_RATE * n * delta))


func uses_eggs() -> bool:
	return d.get("eggs", false)


var _redraw_t := 0.0
var _was_selected := false


func _physics_process(delta: float) -> void:
	_process_flash(delta)
	_process_acid(delta)
	if dead:
		rubble_t += delta
		if rubble_t > 25.0:
			modulate.a = maxf(0.0, 1.0 - (rubble_t - 25.0) / 3.0)
			if rubble_t > 28.0:
				queue_free()
		return
	if built and not dead and kind == "gate":
		_gate(delta)
	if built and not dead:
		_econ(delta)
		if d.has("field"):
			_tower(delta)
		_ambient(delta)
	if d["faction"] == "brood":
		_brood(delta)
	elif d["faction"] == "clockwork":
		if not built and seeded:
			add_progress(delta)
		if built and d.has("battery"):
			var bat: Array = d["battery"]
			if batteries < int(bat[1]):
				_bat_t += delta
				if _bat_t >= float(bat[0]):
					_bat_t = 0.0
					batteries += 1
	if built and uses_eggs():
		# Every egg morphs at the same time.
		var i := 0
		while i < queue.size():
			morph_t[i] += delta
			if morph_t[i] >= float(Defs.UNITS[queue[i]]["time"]):
				var k: String = queue[i]
				queue.remove_at(i)
				morph_t.remove_at(i)
				game.spawn_trained(self, k)
			else:
				i += 1
	elif built and not queue.is_empty():
		prod_t += delta * (game.asm_mult[team] if d["faction"] == "clockwork" else 1.0)
		var k: String = queue[0]
		if prod_t >= entry_time(k):
			prod_t = 0.0
			queue.pop_front()
			if is_research(k):
				game.research_done(self, k.substr(1))
			else:
				game.spawn_trained(self, k)
	if built and auto_train != "" and not dead:
		_auto_t -= delta
		if _auto_t <= 0.0:
			_auto_t = 0.5
			if (uses_eggs() and eggs > 0) or (not uses_eggs() and queue.is_empty()):
				game.train(self, auto_train)
	_update_fire()
	# bars and labels change slowly: redraw 6 times a second, or at once when picked
	_redraw_t -= delta
	if _redraw_t <= 0.0 or selected != _was_selected:
		_redraw_t = 0.16
		_was_selected = selected
		queue_redraw()


## Gate: swings open while a friendly unit is close and no enemy is (the open picture is
## only for show: friends can always pass, enemies never can).
var gate_open := false
var vertical := false            # a gate in a north-south wall: drawn side-on
var dir_locked := false          # turned by hand: stays as it is


func set_vertical(v: bool) -> void:
	if vertical != v:
		vertical = v
		_update_sprite()
var _gate_t := 0.0


func _gate(delta: float) -> void:
	_gate_t -= delta
	if _gate_t > 0.0:
		return
	_gate_t = 0.25
	var friend := false
	var foe := false
	for u in game.units_near(rect().get_center(), 56.0):
		if u.dead or u.is_air():
			continue
		if game.allied(u.team, team):
			friend = true
		else:
			foe = true
	var want := friend and not foe
	if want != gate_open:
		gate_open = want
		_update_sprite()


func _brood(delta: float) -> void:
	if not built and seeded:
		add_progress(delta)
	if built:
		if hp < max_hp:
			hp = minf(max_hp, hp + 1.5 * delta)
		var target := float(d.get("swamp", 0))
		if swamp_r < target:
			swamp_r = minf(target, swamp_r + delta / 1.2)
			game.swamp_dirty = true
		# Eggs: the ones already hatching don't stop the Hive laying new ones, and every
		# Clutch Mound makes it lay faster (a swarm's output grows with its economy).
		if uses_eggs() and eggs < Defs.EGGS_MAX:
			egg_t += delta * game.egg_rate(team)
			if egg_t >= Defs.EGG_TIME:
				egg_t = 0.0
				eggs += 1
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
	_update_sprite()


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
	if not shown:
		return
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
	if kind == "gate" and built and not dead and gate_open:
		state = "open_damaged" if state == "damaged" else "open"
	var base := kind
	if kind == "gate" and vertical and ResourceLoader.exists("res://assets/buildings/gate_v_%s.png" % state):
		base = "gate_v"
	var t := Game.tex("res://assets/buildings/%s_%s.png" % [base, state])
	if sprite.texture != t:
		sprite.texture = t
		sprite.offset = Vector2(-t.get_width() * 0.5, -t.get_height() + 6)
	if not seeded and not dead:
		sprite.modulate = Color(1, 1, 1, 0.3)
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
		if kind == "feeding_pit" and built and not dead and game:
			# spent ground: the pit dries out to a dead grey-brown
			var tired := clampf(1.0 - soil_left() / Defs.SOIL_LOW, 0.0, 1.0)
			sprite.modulate = Color.WHITE.lerp(Color(0.62, 0.56, 0.48), tired)


func die() -> void:
	if dead:
		return
	dead = true
	selected = false
	if team == game.human and built and not game.over:
		Sfx.announce(d["faction"], "building_lost", 6.0)
	for k in queue:
		game.refund(team, k)
	queue.clear()
	for u in crew:
		if is_instance_valid(u) and not u.dead:
			u.cmd_stop()
	crew.clear()
	morph_t.clear()
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


func _draw() -> void:
	if dead:
		return
	var r := rect()
	var local := Rect2(r.position - global_position, r.size)
	if selected:
		draw_rect(local.grow(3), Color(0.4, 1.0, 0.4, 0.8), false, 2.0)
		if rally != Vector2.INF and team == game.human:
			draw_dashed_line(Vector2(0, -r.size.y * 0.5), rally - global_position, Color(0.4, 1, 0.4, 0.6), 2.0, 8.0)
			draw_circle(rally - global_position, 4, Color(0.4, 1, 0.4, 0.9))
		if worker_rally != Vector2.INF and team == game.human:
			draw_dashed_line(Vector2(0, -r.size.y * 0.5), worker_rally - global_position, Color(1, 0.85, 0.3, 0.6), 2.0, 6.0)
			draw_circle(worker_rally - global_position, 4, Color(1, 0.85, 0.3, 0.9))
	var top := -sprite.texture.get_height() + 2.0 if sprite and sprite.texture else -r.size.y
	draw_health(top, r.size.x * 0.7)
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
	elif kind == "farm" and (team == game.human or game.demo):
		var w := r.size.x * 0.7
		draw_rect(Rect2(-w * 0.5, top + 7, w, 4).grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, top + 7, w * growth, 4), Color(0.95, 0.85, 0.3))
	elif not queue.is_empty() and team == game.human:
		var w := r.size.x * 0.7
		var k: String = queue[0]
		var f: float = (morph_t[0] if uses_eggs() else prod_t) / entry_time(k)
		draw_rect(Rect2(-w * 0.5, top + 7, w, 4).grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, top + 7, w * f, 4), Color(0.75, 0.55, 1.0) if is_research(k) else Color(0.4, 0.75, 1.0))
