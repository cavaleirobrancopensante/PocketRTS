class_name Unit
extends Entity
## A unit: moves along A* paths with soft separation, follows orders
## (move, attack-move, attack, hold, gather, build) and fights by type.

const WALK_FPS := 8.0

var d: Dictionary
var order := "idle"            # idle, move, amove, attack, hold, gather, build
var order_point := Vector2.ZERO
var target: Entity = null      # who we're fighting
var order_target: Entity = null  # explicit attack target / mine / construction site
var velocity := Vector2.ZERO
var facing := Vector2.DOWN
var radius := 10.0
var speed := 60.0

var path := PackedVector2Array()
var path_i := 0
var path_goal := Vector2.INF
var path_pending := false
var stuck_t := 0.0
var last_pos := Vector2.ZERO
var repath_t := 0.0

var cooldown := 0.0
var phase := ""                # "", "aim", "strike"
var phase_t := 0.0
var scan_t := 0.0
var leash_from := Vector2.ZERO

# workers
var work := ""                 # to_mine, mining, to_hall, to_site, building
var carrying := 0
var work_t := 0.0
var home_mine: Entity = null

var sprite: Sprite2D
var anim := ""
var anim_dir := ""
var anim_flip := false
var anim_t := 0.0
var frame_i := 0
var corpse_t := 0.0


func is_unit() -> bool:
	return true


func setup(g: Game, k: String, t: int, pos: Vector2) -> void:
	game = g
	kind = k
	team = t
	d = Defs.UNITS[k]
	max_hp = d["hp"]
	hp = max_hp
	armor = d["armor"]
	sight = d["sight"]
	radius = d["radius"]
	speed = d["speed"]
	position = pos
	last_pos = pos
	leash_from = pos


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.material = team_material()
	add_child(sprite)
	_set_anim("idle", true)


func rect() -> Rect2:
	return Rect2(global_position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


func center() -> Vector2:
	return global_position + Vector2(0, -12)


# ------------------------------------------------------------------ orders

func cmd_move(p: Vector2, attack_move := false) -> void:
	_reset_work()
	order = "amove" if attack_move else "move"
	order_point = p
	target = null
	order_target = null
	_request_path(p)


func cmd_attack(e: Entity) -> void:
	_reset_work()
	order = "attack"
	order_target = e
	target = e


func cmd_stop() -> void:
	_reset_work()
	order = "idle"
	target = null
	order_target = null
	path = PackedVector2Array()
	leash_from = position


func cmd_hold() -> void:
	cmd_stop()
	order = "hold"


func cmd_gather(mine: Entity) -> void:
	if kind != "labourer":
		cmd_move(mine.center())
		return
	_reset_work()
	order = "gather"
	home_mine = mine
	order_target = mine
	work = "to_hall" if carrying >= Defs.CARRY else "to_mine"
	target = null


func cmd_build(site: Building) -> void:
	if kind != "labourer":
		return
	_reset_work()
	order = "build"
	order_target = site
	work = "to_site"
	target = null


func _reset_work() -> void:
	work = ""
	phase = ""
	path = PackedVector2Array()
	path_goal = Vector2.INF


# ------------------------------------------------------------------ update

func _physics_process(delta: float) -> void:
	_process_flash(delta)
	if dead:
		corpse_t += delta
		_animate(delta)
		if corpse_t > 6.0:
			modulate.a = maxf(0.0, 1.0 - (corpse_t - 6.0) / 2.0)
			if corpse_t > 8.0:
				queue_free()
		return
	cooldown = maxf(cooldown - delta, 0.0)
	scan_t -= delta
	repath_t -= delta
	var want := Vector2.ZERO

	if target and not _valid_target(target):
		target = null
		phase = ""
	match order:
		"idle":
			if kind != "labourer" and scan_t <= 0.0:
				scan_t = 0.35
				target = game.find_target(self, sight * Defs.TILE)
			if target:
				want = _engage(target, delta, true)
				if position.distance_to(leash_from) > 320.0:
					target = null
					cmd_move(leash_from)
		"hold":
			if scan_t <= 0.0:
				scan_t = 0.3
				target = game.find_target(self, _range() + radius + 8.0)
			if target:
				_engage(target, delta, false)
		"move":
			want = _follow(delta)
			if _arrived():
				_finish_move()
		"amove":
			if scan_t <= 0.0 and target == null and kind != "labourer":
				scan_t = 0.3
				target = game.find_target(self, sight * Defs.TILE)
			if target:
				want = _engage(target, delta, true)
				if target == null or not _valid_target(target):
					_request_path(order_point)
			else:
				want = _follow(delta)
				if _arrived():
					_finish_move()
		"attack":
			if order_target == null or not _valid_target(order_target):
				cmd_stop()
			else:
				target = order_target
				want = _engage(target, delta, true)
		"gather":
			want = _gather(delta)
		"build":
			want = _build(delta)
	_move(want, delta)
	_animate(delta)
	queue_redraw()


func _finish_move() -> void:
	order = "idle"
	path = PackedVector2Array()
	leash_from = position


func _valid_target(e: Entity) -> bool:
	return is_instance_valid(e) and not e.dead and e.is_inside_tree() and e.team != team and e.team >= 0


func _range() -> float:
	return float(d["range"])


# ------------------------------------------------------------------ movement

func _request_path(goal: Vector2) -> void:
	path_goal = goal
	path_pending = true
	game.queue_path(self)


## Called by Game when this unit's turn in the path queue comes up.
func compute_path() -> void:
	path_pending = false
	if path_goal == Vector2.INF:
		return
	path = game.find_path(position, path_goal)
	path_i = 0
	stuck_t = 0.0


func _follow(_delta: float) -> Vector2:
	if path_pending:
		return (path_goal - position).normalized() * speed if path_goal != Vector2.INF else Vector2.ZERO
	if path_i >= path.size():
		return Vector2.ZERO
	var wp := path[path_i]
	var last := path_i == path.size() - 1
	if position.distance_to(wp) < (6.0 if last else 14.0):
		path_i += 1
		if path_i >= path.size():
			return Vector2.ZERO
		wp = path[path_i]
	var to := wp - position
	var spd := speed
	if path_i == path.size() - 1:
		spd = minf(speed, to.length() * 4.0 + 10.0)
	return to.normalized() * spd


func _arrived() -> bool:
	if path_pending:
		return false
	if path_i >= path.size():
		return true
	# Close enough to a crowded goal: stop instead of shoving forever.
	return stuck_t > 0.8 and position.distance_to(path_goal) < 60.0


func _move(want: Vector2, delta: float) -> void:
	var push := game.separation(self)
	var v := want + push
	if want == Vector2.ZERO:
		v = push
	velocity = velocity.lerp(v, clampf(delta * 12.0, 0.0, 1.0))
	if velocity.length() > speed * 1.3:
		velocity = velocity.normalized() * speed * 1.3
	var before := position
	position += velocity * delta
	position = game.resolve_terrain(position, before, radius)
	if want.length() > 5.0 and phase == "":
		facing = facing.lerp(want.normalized(), clampf(delta * 10.0, 0.0, 1.0)).normalized()
	# Stuck detection while trying to move
	if want.length() > 5.0:
		if position.distance_to(last_pos) < speed * delta * 0.25:
			stuck_t += delta
		else:
			stuck_t = maxf(stuck_t - delta * 2.0, 0.0)
		if stuck_t > 1.6 and path_goal != Vector2.INF and not path_pending:
			stuck_t = 0.9
			_request_path(path_goal)
	last_pos = position


## Move toward and fight a target. Returns the desired velocity.
func _engage(e: Entity, delta: float, may_move: bool) -> Vector2:
	var dist := e.edge_distance(position) - radius
	var rng := _range()
	var min_r := float(d.get("min_range", 0.0))
	if phase != "":
		_attack_cycle(e, delta)
		return Vector2.ZERO
	if dist <= rng and dist >= min_r:
		path = PackedVector2Array()
		_attack_cycle(e, delta)
		return Vector2.ZERO
	if not may_move:
		return Vector2.ZERO
	if dist < min_r:
		return (position - e.center()).normalized() * speed   # back off
	# Chase: straight when close and clear, otherwise path.
	var goal := e.center() if e.is_unit() else e.rect().get_center()
	if position.distance_to(goal) < 140.0 and game.line_clear(position, goal):
		path = PackedVector2Array()
		return (goal - position).normalized() * speed
	if repath_t <= 0.0 or path.is_empty():
		repath_t = 1.0
		_request_path(game.approach_point(e, position))
	return _follow(delta)


func _attack_cycle(e: Entity, delta: float) -> void:
	facing = (e.center() - center()).normalized()
	if phase == "":
		if cooldown > 0.0:
			return
		phase = "aim"
		phase_t = float(d.get("aim", 0.25))
		return
	phase_t -= delta
	if phase == "aim" and phase_t <= 0.0:
		phase = "strike"
		phase_t = 0.35
		_strike(e)
	elif phase == "strike" and phase_t <= 0.0:
		phase = ""
		cooldown = float(d["cooldown"])


func _strike(e: Entity) -> void:
	if not _valid_target(e):
		return
	var dmg := float(d["damage"])
	match kind:
		"musketeer":
			game.musket_shot(self, e, dmg)
		"cannon":
			game.cannon_shot(self, e.center(), dmg)
		_:
			var bonus: Dictionary = d.get("bonus", {})
			dmg *= float(bonus.get(e.kind, 1.0))
			e.take_damage(dmg, self)
			game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.6)


# ------------------------------------------------------------------ workers

func _gather(delta: float) -> Vector2:
	if work != "to_hall" and (home_mine == null or not is_instance_valid(home_mine) or home_mine.gold <= 0):
		home_mine = game.nearest_mine(position, team)
		if home_mine == null:
			if carrying > 0:
				work = "to_hall"
			else:
				cmd_stop()
				return Vector2.ZERO
		order_target = home_mine
	match work:
		"to_mine":
			if home_mine.edge_distance(position) < radius + 17.0:
				work = "mining"
				work_t = Defs.MINE_TIME
				path = PackedVector2Array()
				return Vector2.ZERO
			if path.is_empty() and not path_pending:
				_request_path(game.approach_point(home_mine, position))
			elif path_i >= path.size() and not path_pending:
				_request_path(game.approach_point(home_mine, position))
			return _follow(delta)
		"mining":
			facing = (home_mine.center() - position).normalized()
			work_t -= delta
			if work_t <= 0.0:
				carrying = home_mine.take(Defs.CARRY)
				work = "to_hall"
				path = PackedVector2Array()
			return Vector2.ZERO
		"to_hall":
			var hall := game.nearest_hall(position, team)
			if hall == null:
				return Vector2.ZERO
			if hall.edge_distance(position) < radius + 17.0:
				game.add_gold(team, carrying)
				carrying = 0
				work = "to_mine"
				if home_mine == null or not is_instance_valid(home_mine) or home_mine.gold <= 0:
					home_mine = game.nearest_mine(position, team)
				path = PackedVector2Array()
				return Vector2.ZERO
			if (path.is_empty() or path_i >= path.size()) and not path_pending:
				_request_path(game.approach_point(hall, position))
			return _follow(delta)
	work = "to_mine"
	return Vector2.ZERO


func _build(delta: float) -> Vector2:
	var site := order_target as Building
	if site == null or not is_instance_valid(site) or site.dead or site.built:
		# Done: go back to mining, like a sensible labourer would.
		var m := game.nearest_mine(position, team)
		if m:
			cmd_gather(m)
		else:
			cmd_stop()
		return Vector2.ZERO
	if site.edge_distance(position) < radius + 17.0:
		work = "building"
		path = PackedVector2Array()
		facing = (site.center() - position).normalized()
		site.add_progress(delta)
		return Vector2.ZERO
	work = "to_site"
	if (path.is_empty() or path_i >= path.size()) and not path_pending:
		_request_path(game.approach_point(site, position))
	return _follow(delta)


# ------------------------------------------------------------------ death

func die() -> void:
	if dead:
		return
	dead = true
	selected = false
	velocity = Vector2.ZERO
	game.on_unit_died(self)
	_set_anim("death", true)
	z_index = -1


# ------------------------------------------------------------------ animation

func _anim_name() -> String:
	if dead:
		return "death"
	var moving := velocity.length() > 10.0
	match kind:
		"musketeer":
			if phase == "aim":
				return "aim"
			if phase == "strike":
				return "fire"
			if cooldown > 0.0 and not moving and target:
				return "reload"
		"pikeman":
			if phase != "":
				return "thrust"
			if order == "hold" and not moving:
				return "brace"
		"cannon":
			if phase != "":
				return "fire"
			if cooldown > 0.0 and target:
				return "reload"
			return "move" if moving else "idle"
		"labourer":
			if work == "mining" or phase != "":
				return "mine"
			if work == "building":
				return "build"
			if moving and carrying > 0:
				return "carry"
	return "walk" if moving else "idle"


func _animate(delta: float) -> void:
	_set_anim(_anim_name(), false)
	var key := anim + "_" + anim_dir
	var n: int = ArtData.UNITS[kind]["frames"].get(key, 1)
	var fps := WALK_FPS * clampf(velocity.length() / maxf(speed, 1.0), 0.6, 1.3)
	var loop := true
	match anim:
		"idle":
			fps = 2.0
			if kind == "pikeman":
				n = 1
		"death":
			fps = 7.0
			loop = false
		"aim", "fire", "thrust", "brace":
			fps = 9.0
			loop = false
		"mine", "build":
			fps = 6.0
		"reload":
			fps = float(n) / maxf(float(d["cooldown"]) * 0.8, 0.5)
	anim_t += delta * fps
	if anim_t >= 1.0:
		anim_t -= 1.0
		frame_i += 1
	frame_i = posmod(frame_i, n) if loop else mini(frame_i, n - 1)
	sprite.frame = mini(frame_i, sprite.hframes - 1)
	# Cannon: fake recoil and a little bounce, since it's one frame per pose.
	if kind == "cannon":
		sprite.position.x = -facing.x * (4.0 if anim == "fire" else 0.0)


func _set_anim(a: String, force: bool) -> void:
	var o := int(round(facing.angle() / (PI / 4.0)))
	o = posmod(o, 8)
	var dir_flip: Array = [["e", false], ["se", false], ["s", false], ["se", true], ["e", true], ["ne", true], ["n", false], ["ne", false]][o]
	var dr: String = dir_flip[0]
	var flip: bool = dir_flip[1]
	if not force and a == anim and dr == anim_dir and flip == anim_flip:
		return
	if a != anim:
		frame_i = 0
		anim_t = 0.0
	var frames: Dictionary = ArtData.UNITS[kind]["frames"]
	if not frames.has(a + "_" + dr):
		for alt in ["s", "se", "e", "ne", "n"]:
			if frames.has(a + "_" + alt):
				dr = alt
				break
		if not frames.has(a + "_" + dr):
			a = "idle"
	anim = a
	anim_dir = dr
	anim_flip = flip
	var key := a + "_" + dr
	sprite.texture = Game.tex("res://assets/units/%s/%s.png" % [kind, key])
	sprite.hframes = frames.get(key, 1)
	var anchor: Vector2 = ArtData.UNITS[kind]["anchor"]
	sprite.offset = -anchor
	sprite.scale.x = -1.0 if flip else 1.0
	frame_i = mini(frame_i, sprite.hframes - 1)


func _draw() -> void:
	if dead:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, radius + 2.0, Color(0, 0, 0, 0.25))
	if selected:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 24, Color(0.4, 1.0, 0.4, 0.9), 2.0)
	draw_set_transform(Vector2.ZERO)
	var top := -float(ArtData.UNITS[kind]["anchor"].y) - 4.0
	if kind == "pikeman":
		top = -40.0
	draw_health(top, radius * 2.4)
	if carrying > 0 and kind == "labourer" and anim != "carry":
		draw_circle(Vector2(6, -14), 3, Color(1, 0.85, 0.2))
