class_name Building
extends Entity
## A building: placed on a tile footprint, built up by labourers, trains units
## from a queue, catches fire when damaged and leaves rubble when destroyed.

var d: Dictionary
var cell := Vector2i.ZERO
var size := Vector2i.ONE
var built := false
var progress := 0.0              # 0..1 while under construction
var queue: Array = []            # unit kinds
var prod_t := 0.0
var rally := Vector2.INF
var rally_target: Entity = null
var worker_rally := Vector2.INF  # Hive: workers and army have separate rally points
var worker_rally_target: Entity = null
var seeded := true               # Brood: a grub has turned into the site
var eggs := 0                    # Brood Hive
var egg_t := 0.0
var morph_t: Array = []          # Brood Hive: time spent on each morphing egg
var swamp_r := 0.0               # Brood: current swamp radius in tiles
var rig_mine: GoldMine = null    # Clockwork Drill Rig: the mine it drills
var gold_acc := 0.0
var crew: Array = []             # workers assigned to this economy structure
var growth := 0.0                # Farm: 0..1 until the harvest
var sprite: Sprite2D
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
	"bone_midden": [["smoke", 0.5, 0.3, 1.6, 0.4, Color(0.75, 0.5, 1.0, 0.5)]],
	"feeding_pit": [["acid_splash", 0.5, 0.55, 1.4, 0.5, Color(1, 0.6, 0.6, 0.8)]],
	"clocktower": [["smoke", 0.2, 0.3, 1.1, 0.4, Color(1.2, 1.2, 1.2, 0.6)]],
	"assembly_works": [["smoke", 0.3, 0.04, 0.9, 0.4, Color(1.2, 1.2, 1.2, 0.6)], ["smoke", 0.86, 0.05, 1.1, 0.4, Color(1.2, 1.2, 1.2, 0.6)]],
	"boiler": [["smoke", 0.32, 0.07, 0.7, 0.45, Color(1.2, 1.2, 1.2, 0.65)]],
	"ore_crusher": [["dust", 0.6, 0.55, 1.0, 0.35, Color(0.8, 0.8, 0.8, 0.7)]],
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
	if d["faction"] == "brood":
		seeded = complete
		if complete:
			swamp_r = float(d.get("swamp", 0))
		if d.get("eggs", false):
			eggs = Defs.EGGS_MAX if complete else 0
	var r := rect()
	position = Vector2(r.get_center().x, r.end.y)


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.material = team_material()
	add_child(sprite)
	_update_sprite()


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


func _econ(delta: float) -> void:
	crew = crew.filter(func(u: Unit) -> bool: return is_instance_valid(u) and not u.dead and u.home_mine == self)
	match kind:
		"farm":
			var w := mini(working_crew(), 3)
			growth += (Defs.FARM_BASE + (1.0 - Defs.FARM_BASE) * w / 3.0) / Defs.FARM_GROW * delta
			if growth >= 1.0:
				growth = 0.0
				game.add_gold(team, Defs.FARM_YIELD)
				Sfx.play("work/farm_harvest", center(), -4.0)
				if team == game.human:
					game.float_text(center() + Vector2(0, -30), "+%d harvest" % Defs.FARM_YIELD, Color(1, 0.9, 0.4))
					Sfx.play("done", center())
		"powder_mill":
			game.add_res2(team, Defs.MILL_RATE * working_crew() * delta)
		"bone_midden":
			game.add_res2(team, Defs.MIDDEN_TRICKLE * delta)


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
		if built:
			var rate := 0.0
			if d.get("rig", false) and rig_mine and is_instance_valid(rig_mine):
				rate = Defs.RIG_RATE
			rate += float(d.get("trickle", 0.0))
			gold_acc += rate * delta
			if gold_acc >= 1.0:
				var n := int(gold_acc)
				gold_acc -= n
				if d.get("rig", false) and rig_mine:
					var got := rig_mine.take(n)
					game.add_gold(team, got)
					n -= got
					if rig_mine.gold <= 0:
						rate = 0.0
				if d.get("trickle", 0.0) > 0.0:
					game.add_gold(team, n)
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
		if prod_t >= float(Defs.UNITS[k]["time"]):
			prod_t = 0.0
			queue.pop_front()
			game.spawn_trained(self, k)
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
		fire.position = Vector2(randf_range(-12, 12), -rect().size.y * 0.75)
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
	var t := Game.tex("res://assets/buildings/%s_%s.png" % [kind, state])
	if sprite.texture != t:
		sprite.texture = t
		sprite.offset = Vector2(-t.get_width() * 0.5, -t.get_height() + 6)
	if not seeded and not dead:
		sprite.modulate = Color(1, 1, 1, 0.3)
	else:
		sprite.modulate = Color(1, 1, 1, 0.55 + 0.45 * progress) if not built and not dead else Color.WHITE


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
	if rig_mine and is_instance_valid(rig_mine) and rig_mine.rig == self:
		rig_mine.rig = null
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
		var f: float = (morph_t[0] if uses_eggs() else prod_t) / float(Defs.UNITS[k]["time"])
		draw_rect(Rect2(-w * 0.5, top + 7, w, 4).grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, top + 7, w * f, 4), Color(0.4, 0.75, 1.0))
