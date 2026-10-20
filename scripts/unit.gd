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
var wind := 1.0                # Clockwork: 1 = fully wound; runs down outside a field
var _field_t := 0.0
var _in_field := true

var sprite: Sprite2D
var anim := ""
var anim_dir := ""
var anim_flip := false
var anim_t := 0.0
var frame_i := 0
var corpse_t := 0.0


var _charging := false
var tesla_mode := "packed"     # Tesla Cart: packed, deploying, deployed, packing
var tesla_t := 0.0
var _bob_t := 0.0
var _draw_key := Vector4i(-1, -1, -1, -1)
var _push := Vector2.ZERO
# Crown abilities
var mode := ""                  # musketeer "" (muskets) or "bayonet"; cannon "" (round shot) or "canister"
var push_auto := true           # pikeman: shove enemies back with the pike when it's ready
var push_cd := 0.0
var knock := Vector2.ZERO       # being shoved back
var stun_t := 0.0
var _sep_tick := false
var _anim_dt := 0.0
# New units
var charge := 0.0               # Stormcaller: fills inside a Clockwork field, spent on storms
var run_t := 0.0                # Cuirassier: seconds at the gallop (a charge after Defs.CHARGE.run)
var spell_cd := 0.0             # Spore Mother: miasma cooldown
var cast_spell := ""            # the spell this unit is on its way to cast
var cast_at := Vector2.ZERO
var auto_work := true
var _cold := false
var slow_t := 0.0              # slowed (Bloater acid)
var kills := 0                  # veterancy
var harvester: Unit = null      # (a body) the grub coming to take it
var cocoon := 0                 # (a grub) essence it carries home
var gas := 100.0                # Bloater: what's left in the sac (spits use it, the burst scales with it)
# Observation Balloon: two gunners, each with its own target, reload and pose
var gun_cd: Array = [0.0, 1.5]
var gun_state: Array = ["idle", "idle"]
var gun_t: Array = [0.0, 0.0]
var _gun_sprites: Array = []
var _front: Sprite2D
var _hold_note := 0             # when this unit may next say it's holding fire           # workers: go back to work on their own when idle


func is_unit() -> bool:
	return true


## How long bodies stay on the field before they fade (Settings could change this).
const CORPSE_TIME := 30.0


## A number drawn with the pixel digits (centred on `at`).
func _draw_number(v: int, at: Vector2) -> void:
	var tex: Texture2D = Game.tex("res://assets/effects/digits.png")
	var txt := str(v)
	var x := at.x - txt.length() * 4.0
	for ch in txt:
		draw_texture_rect_region(tex, Rect2(x, at.y, 7, 9), Rect2(int(ch) * 7, 0, 7, 9))
		x += 8.0


func _rest_in_peace() -> void:
	queue_redraw()
	set_physics_process(false)
	set_process(false)
	var tw := create_tween()
	# bodies the Brood can harvest lie there longer
	tw.tween_interval(float(Defs.HARVEST["time"]) if game.corpses.has(self) else CORPSE_TIME)
	tw.tween_callback(func() -> void: game.corpses.erase(self))
	tw.tween_property(self, "modulate:a", 0.0, 3.0)
	tw.tween_callback(queue_free)


## A Clockwork construct with no charge left.
func powered_down() -> bool:
	return d["faction"] == "clockwork" and not is_worker() and wind <= 0.0


func is_worker() -> bool:
	return Defs.is_worker(kind)


func is_air() -> bool:
	return d.get("air", false)


## Can this unit attack that one at all?
func can_hit(e: Entity) -> bool:
	if d.get("medic", false) or e.untouchable():
		return false
	if e.is_air() and d.get("ground_only", false):
		return false
	if e.is_air():
		# the cannon's canister is the Crown's answer to massed flyers; round shot can't
		if kind == "cannon":
			return mode == "canister"
		if not d.get("anti_air", false) or mode == "bayonet":
			return false
	return true


## Musketeer: fix bayonets (melee, no powder) or go back to muskets.
func set_bayonet(on: bool) -> void:
	if kind != "musketeer" or (mode == "bayonet") == on:
		return
	mode = "bayonet" if on else ""
	phase = ""
	target = null


## Cannon: round shot (long range, splash, smashes buildings) or canister (short range,
## a cone of musket balls that shreds crowds).
## Bloater: HOLD GAS (no spitting, a full-size burst) or SPIT.
func set_hold_gas(on: bool) -> void:
	if kind != "bloater":
		return
	mode = "hold" if on else ""
	phase = ""


func set_canister(on: bool) -> void:
	if kind != "cannon" or (mode == "canister") == on:
		return
	mode = "canister" if on else ""
	phase = ""
	target = null


func _cooldown() -> float:
	if mode == "bayonet":
		return Defs.BAYONET["cooldown"]
	if mode == "canister":
		return Defs.CANISTER["cooldown"]
	return float(d["cooldown"])


func _aim() -> float:
	if mode == "bayonet":
		return Defs.BAYONET["aim"]
	return float(d.get("aim", 0.25))


func can_gather() -> bool:
	return kind == "labourer" or kind == "grub" or kind == "winder"


func take_damage(amount: float, from: Entity) -> void:
	if work == "feeding":
		amount *= 0.5      # burrowed grubs are hard to hit
	super.take_damage(amount, from)
	# a Winder hit while carrying a battery: it blows up
	if kind == "winder" and carrying > 0 and not dead and from != self:
		_battery_blast()


## Balloon gunners: each picks its own target in range (the second prefers a different one,
## and flyers if there are any), fires down or up, reloads on its own.
func _gunners(delta: float) -> void:
	var taken: Entity = null
	for i in gun_cd.size():
		gun_cd[i] = float(gun_cd[i]) - delta
		gun_t[i] = float(gun_t[i]) + delta
		if gun_state[i] != "idle" and float(gun_t[i]) > 0.7:
			gun_state[i] = "idle"
		if float(gun_cd[i]) > 0.0 or stun_t > 0.0:
			continue
		var best: Entity = null
		var bd := INF
		for o in game.units_near(position, _range() + 40.0):
			if not game.hostile(o.team, team) or o.dead or o.off_field or not can_hit(o) or not game.side_sees(team, o.position):
				continue
			var dd: float = o.center().distance_to(center())
			if dd > _range():
				continue
			if i == 1 and o.is_air():
				dd -= 150.0          # gunner B watches the sky
			if o == taken:
				dd += 120.0          # spread the fire
			if dd < bd:
				bd = dd
				best = o
		if best == null:
			continue
		if not game.use_powder(team, 1):
			continue
		taken = best
		gun_state[i] = "up" if best.is_air() else "down"
		gun_t[i] = 0.0
		gun_cd[i] = float(d["cooldown"]) + randf_range(0.0, 0.4)
		var muzzle := center() + Vector2(-6.0 if i == 0 else 6.0, -4.0)
		if _gun_sprites.size() > i:
			muzzle = (_gun_sprites[i] as Sprite2D).global_position + Vector2(0, -4)
		game.musket_shot(self, best, float(d["damage"]), muzzle)


func _update_gunners() -> void:
	if _front == null or not ArtData.UNITS[kind].has("gunners"):
		return
	var info: Dictionary = ArtData.UNITS[kind]
	var dead_anim := anim == "death"
	_front.visible = not dead_anim
	for g in _gun_sprites:
		(g as Sprite2D).visible = not dead_anim
	if dead_anim:
		return
	var fk := "front_%s_%s" % [anim, anim_dir]
	if ResourceLoader.exists("res://assets/units/%s/%s.png" % [kind, fk]):
		_front.texture = Game.tex("res://assets/units/%s/%s.png" % [kind, fk])
		_front.hframes = sprite.hframes
		_front.frame = sprite.frame
		_front.offset = sprite.offset
	var slots: Array = info["gunners"].get(anim_dir, [Vector2(-6, 0), Vector2(6, 0)])
	var gfr: Dictionary = info.get("gunner_frames", {"idle": 1, "down": 3, "up": 3})
	for i in _gun_sprites.size():
		var g: Sprite2D = _gun_sprites[i]
		var st: String = gun_state[i]
		g.texture = Game.tex("res://assets/units/%s/gunner_%s_%s.png" % [kind, st, anim_dir])
		g.hframes = int(gfr.get(st, 1))
		g.frame = clampi(int(float(gun_t[i]) / 0.7 * g.hframes), 0, g.hframes - 1) if st != "idle" else 0
		g.offset = -Vector2(info.get("gunner_anchor", Vector2.ZERO))
		g.position = sprite.offset + Vector2(slots[mini(i, slots.size() - 1)])


## The battery on a Winder's back overloads (carried too long, or hit): it bursts.
func _battery_blast() -> void:
	carrying = 0
	carry_t = 0.0
	work = "to_site"
	path = PackedVector2Array()
	game.spawn_effect("zap_burst" if ArtData.EFFECTS.has("zap_burst") else "hit", position + Vector2(0, -16), 1.4)
	Sfx.play_any(["combat/tesla_attack", "zap"], position)
	if team == game.human:
		game.float_text(position + Vector2(0, -30), "battery burst!", Color(1, 0.6, 0.3))
	for o in game.units_near(position, 34.0):
		if o != self and not o.dead and not o.is_air():
			o.take_damage(float(Defs.BATTERY["splash"]), self)
	super.take_damage(float(Defs.BATTERY["blast"]), self)


func setup(g: Game, k: String, t: int, pos: Vector2) -> void:
	game = g
	kind = k
	team = t
	d = Defs.UNITS[k]
	max_hp = d["hp"]
	hp = max_hp
	if k == "stormcaller":
		charge = float(Defs.STORM["max"]) * 0.5
	armor = d["armor"]
	sight = d["sight"]
	radius = d["radius"]
	speed = d["speed"]
	position = pos
	last_pos = pos
	leash_from = pos


func _ready() -> void:
	_sep_tick = get_instance_id() % 2 == 0
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.material = team_material()
	add_child(sprite)
	if kind == "cannon" and not ArtData.UNITS["cannon"]["frames"].has("walk_e"):
		_make_wheel()
	if ArtData.UNITS.has(kind) and ArtData.UNITS[kind].has("gunners"):
		# layered: body, the two gunners, then the basket's front wall over their legs
		for i in int(d.get("gunners", 2)):
			var g := Sprite2D.new()
			g.centered = false
			g.use_parent_material = true
			sprite.add_child(g)
			_gun_sprites.append(g)
		_front = Sprite2D.new()
		_front.centered = false
		_front.use_parent_material = true
		sprite.add_child(_front)
	if is_air():
		z_index = 3
	_set_anim("idle", true)


func rect() -> Rect2:
	return Rect2(global_position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


func center() -> Vector2:
	# flyers are drawn hovering 20 px up: shots and zaps go to where they're seen
	return global_position + Vector2(0, -32 if is_air() else -12)


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


## Units with two modes: moving (packed) and set up (deployed). The cannon limbers and
## unlimbers, the Tesla Cart packs and deploys, the Spore Mother uproots and roots.
func deploys() -> bool:
	return kind == "tesla_cart" or kind == "cannon" or kind == "spore_mother"


func switch_time() -> float:
	match kind:
		"cannon":
			return Defs.CANNON_SWITCH
		"spore_mother":
			return Defs.ROOT_SWITCH
	return Defs.TESLA_SWITCH


func cmd_deploy() -> void:
	if not deploys() or tesla_mode != "packed":
		return
	cmd_stop()
	tesla_mode = "deploying"
	tesla_t = switch_time()
	if kind == "tesla_cart":
		Sfx.play("combat/tesla_deploy", position)


## Go to a spot and cast a spell there (Stormcaller: storm; Spore Mother: miasma).
func cmd_cast(spell: String, p: Vector2) -> void:
	_reset_work()
	order = "cast"
	cast_spell = spell
	cast_at = p
	target = null
	order_target = null
	if position.distance_to(p) > _spell_range():
		_request_path(p)


func _spell_range() -> float:
	return float((Defs.STORM if cast_spell == "storm" else Defs.MIASMA)["range"])


func _cast(delta: float) -> Vector2:
	if phase == "cast":
		if stun_t <= 0.0:
			phase_t -= delta
		if phase_t <= 0.0:
			phase = ""
			game.cast_spell(self, cast_spell, cast_at)
			cmd_stop()
		return Vector2.ZERO
	var why := game.spell_problem(self, cast_spell)
	if why != "":
		if team == game.human:
			game.notify(why)
		cmd_stop()
		return Vector2.ZERO
	if position.distance_to(cast_at) <= _spell_range():
		if tesla_mode == "deploying" or tesla_mode == "packing":
			return Vector2.ZERO
		path = PackedVector2Array()
		phase = "cast"
		phase_t = float((Defs.STORM if cast_spell == "storm" else Defs.MIASMA)["cast"])
		facing = (cast_at - position).normalized() if cast_at != position else facing
		frame_i = 0
		anim_t = 0.0
		return Vector2.ZERO
	if deploys() and tesla_mode != "packed":
		if tesla_mode == "deployed":
			tesla_mode = "packing"
			tesla_t = switch_time()
		return Vector2.ZERO
	if path.is_empty() and not path_pending:
		_request_path(cast_at)
	return _follow(delta)


func cmd_pack() -> void:
	if deploys() and tesla_mode == "deployed":
		tesla_mode = "packing"
		tesla_t = switch_time()


func cmd_heal(e: Unit) -> void:
	_reset_work()
	order = "heal"
	order_target = e
	target = null


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


## Go and work at an economy structure (Farm, Powder Mill, Feeding Pit, Boiler).
func cmd_gather(site: Entity) -> void:
	if not can_gather() or not (site is Building):
		cmd_move(site.center())
		return
	var b := site as Building
	if b.team != team or int(b.d.get("crew", 0)) == 0:
		cmd_move(site.center())
		return
	if not b.crew.has(self) and b.crew.size() >= int(b.d["crew"]):
		var alt := game.free_site(team, b.center())
		if alt == null:
			if team == game.human:
				game.notify("That %s is fully crewed." % b.d["name"])
			cmd_move(b.center())
			return
		b = alt
	_reset_work()
	order = "gather"
	home_mine = b
	order_target = b
	b.crew.append(self)
	work = "to_hall" if kind == "grub" and carrying > 0 else "to_site"
	target = null


## Winders fix constructs and Clockwork buildings; Labourers fix buildings. It costs gold/ore.
func can_repair(e: Entity) -> bool:
	if kind == "winder":
		return e.is_unit() and (e as Unit).d["faction"] == "clockwork" or e.is_building()
	if kind == "labourer":
		return e.is_building()
	return false


func cmd_repair(e: Entity) -> void:
	if not can_repair(e):
		return
	_reset_work()
	order = "repair"
	order_target = e
	target = null


func cmd_build(site: Building) -> void:
	if not is_worker():
		return
	_reset_work()
	order = "build"
	order_target = site
	work = "to_site"
	target = null


func _reset_work() -> void:
	if _corpse and is_instance_valid(_corpse):
		_corpse.harvester = null
	_corpse = null
	_leave_mine()
	_release_patient()
	work = ""
	phase = ""
	path = PackedVector2Array()
	path_goal = Vector2.INF


# ------------------------------------------------------------------ update

func _physics_process(delta: float) -> void:
	_process_flash(delta)
	if off_field:
		return
	cross_t = maxf(cross_t - delta, 0.0)
	if dead:
		corpse_t += delta
		_animate(delta)
		# once it has fallen, the body is just a picture: stop updating it and let a
		# timer fade it out (thousands of still bodies cost almost nothing)
		if corpse_t > 1.5:
			_rest_in_peace()
		return
	_process_acid(delta)
	if dead:
		return
	cooldown = maxf(cooldown - delta, 0.0)
	push_cd = maxf(push_cd - delta, 0.0)
	spell_cd = maxf(spell_cd - delta, 0.0)
	if kind == "cuirassier":
		# a gallop builds up to a charge; standing about loses it
		if velocity.length() > speed * 0.7:
			run_t += delta
		elif phase == "":
			run_t = maxf(run_t - delta * 3.0, 0.0)
	stun_t = maxf(stun_t - delta, 0.0)
	scan_t -= delta
	repath_t -= delta
	var want := Vector2.ZERO
	# Brood on swamp: faster, and wounds close up.
	speed = float(d["speed"])
	if slow_t > 0.0:
		slow_t -= delta
		speed *= float(Defs.BLOAT["slow"])
	if d["faction"] == "brood" and game.on_swamp(team, position):
		speed *= 1.3
		if hp < max_hp:
			hp = minf(max_hp, hp + 2.0 * delta)
	if kind == "brute" and target and phase == "" and target.edge_distance(position) < 170.0:
		speed *= 1.6      # charge
		if not _charging:
			_charging = true
			Sfx.play_any(["combat/brute_attack", "roar"], position)
	elif kind == "brute":
		_charging = false
	if d.has("gunners"):
		_gunners(delta)
	if d["faction"] == "clockwork":
		_field_t -= delta
		if _field_t <= 0.0:
			_field_t = 0.4
			_in_field = game.in_field(team, position)
		if _in_field:
			wind = minf(1.0, wind + 0.3 * delta)
			if kind == "stormcaller":
				charge = minf(float(Defs.STORM["max"]), charge + float(Defs.STORM["fill"]) * delta)
		elif not is_worker():
			wind = maxf(0.0, wind - Defs.WIND_DECAY * game.wind_decay_mult(team) * delta)
		speed *= lerpf(0.75, 1.0, wind)
		# out of charge: it shuts down where it stands, like a statue, until a field
		# reaches it or a Winder winds it up again
		if powered_down():
			stun_t = maxf(stun_t, 0.25)
			phase = ""
			target = null
		if d.has("regen") and hp < max_hp:
			hp = minf(max_hp, hp + float(d["regen"]) * delta)

	if target and not _valid_target(target):
		target = null
		phase = ""
	match order:
		"idle":
			if d.get("medic", false) and scan_t <= 0.0:
				scan_t = 0.5
				var pt := game.find_patient(self, 9 * Defs.TILE)
				if pt:
					cmd_heal(pt)
			if kind == "winder" and scan_t <= 0.0:
				scan_t = 1.0
				var hurt := game.find_repair(self, 6 * Defs.TILE)
				if hurt:
					cmd_repair(hurt)
			# WORK is on by default: an idle worker goes back to its post by itself
			if is_worker() and auto_work and order == "idle" and scan_t <= 0.0:
				scan_t = 1.5
				var post := game.free_site(team, position)
				if post:
					cmd_gather(post)
			if not is_worker() and scan_t <= 0.0:
				scan_t = 0.35
				target = game.find_target(self, _scan_range())
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
			# hacking at a wall: look again now and then, and leave it for anything better
			if is_instance_valid(target) and target is Building and (target.kind == "wall" or target.kind == "gate") and scan_t <= 0.0 and stuck_t < 0.5:
				scan_t = 0.6
				var better := game.find_target(self, _scan_range())
				if better and better != target and not (better is Building and (better.kind == "wall" or better.kind == "gate")):
					target = better
			if scan_t <= 0.0 and target == null and not is_worker():
				scan_t = 0.3
				target = game.find_target(self, _scan_range())
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
		"repair":
			want = _repair(delta)
		"heal":
			want = _heal(delta)
		"build":
			want = _build(delta)
		"cast":
			want = _cast(delta)
		"harvest":
			want = _harvest(delta)
	if deploys():
		want = _tesla(want, delta)
	_move(want, delta)
	_animate(delta)
	# redraw the shadow, ring and bars only when something on them changed
	var key := Vector4i(int(selected) + (2 if carrying > 0 else 0) + (4 if cross_t > 0.0 else 0) + (8 if work == "feeding" else 0) + (16 if carry_empty else 0) + (32 if cocoon > 0 else 0) + kills * 64,
		int(hp) + int(gas) * 10000, int(wind * 40.0) + (int(carry_t * 4.0) * 100 if carrying > 0 else 0) if d["faction"] == "clockwork" else 0, int(max_hp))
	if key != _draw_key:
		_draw_key = key
		queue_redraw()


## Tesla Cart: it only rolls when packed and only zaps when deployed; switching takes a while.
func _tesla(want: Vector2, delta: float) -> Vector2:
	match tesla_mode:
		"deploying", "packing":
			tesla_t -= delta
			if tesla_t <= 0.0:
				tesla_mode = "deployed" if tesla_mode == "deploying" else "packed"
				if kind == "spore_mother":
					game.swamp_dirty = true
			return Vector2.ZERO
		"deployed":
			if want.length() > 5.0 and order in ["move", "amove", "gather", "build", "cast"]:
				tesla_mode = "packing"
				tesla_t = switch_time()
			return Vector2.ZERO
	return want


func _finish_move() -> void:
	order = "idle"
	path = PackedVector2Array()
	leash_from = position


func _valid_target(e: Entity) -> bool:
	return is_instance_valid(e) and not e.dead and e.is_inside_tree() and game.hostile(e.team, team) and can_hit(e)


## How far this unit looks for targets: its sight, or for a cannon its full range (it
## can shoot what any friendly unit sees).
func _scan_range() -> float:
	if kind == "cannon":
		return maxf(sight * Defs.TILE, _range())
	return sight * Defs.TILE


func _range() -> float:
	if kind == "bloater":
		# holding its gas, out of it, or about to pop anyway: it goes in to burst
		if mode == "hold" or gas < float(Defs.BLOAT["spit_cost"]) or hp < max_hp * 0.35:
			return float(Defs.BLOAT["reach"])
	if mode == "bayonet":
		return Defs.BAYONET["range"]
	if mode == "canister":
		return Defs.CANISTER["range"]
	return float(d["range"])


# ------------------------------------------------------------------ movement

func _request_path(goal: Vector2) -> void:
	if is_air():
		path_goal = goal
		path = PackedVector2Array([goal])
		path_i = 0
		path_pending = false
		return
	path_goal = goal
	path_pending = true
	game.queue_path(self)


## Called by Game when this unit's turn in the path queue comes up.
func compute_path() -> void:
	path_pending = false
	if path_goal == Vector2.INF:
		return
	path = game.find_path(position, path_goal, not is_worker())
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
	if work == "feeding" or work == "morphing":
		velocity = Vector2.ZERO
		return
	# neighbours only nudge each other: half the units work it out on each tick
	_sep_tick = not _sep_tick
	if _sep_tick:
		_push = game.separation(self)
	var push := _push
	var v := want + push
	if want == Vector2.ZERO:
		v = push
	if stun_t > 0.0:
		v = Vector2.ZERO
	velocity = velocity.lerp(v, clampf(delta * 12.0, 0.0, 1.0))
	if knock.length_squared() > 25.0:
		position = game.resolve_terrain(position + knock * delta, position, radius, team)
		knock *= exp(-7.0 * delta)
	if velocity.length() > speed * 1.3:
		velocity = velocity.normalized() * speed * 1.3
	if velocity.length_squared() < 1.0:
		velocity = Vector2.ZERO
		return
	var before := position
	position += velocity * delta
	if is_air():
		position = position.clamp(Vector2(8, 8), Vector2(Game.W, Game.H) * Game.T - Vector2(8, 8))
	else:
		position = game.resolve_terrain(position, before, radius, team)
	if want.length() > 5.0 and phase == "":
		facing = facing.lerp(want.normalized(), clampf(delta * 10.0, 0.0, 1.0)).normalized()
	# Stuck detection while trying to move
	if want.length() > 5.0:
		if position.distance_to(last_pos) < speed * delta * 0.25:
			stuck_t += delta
		else:
			stuck_t = maxf(stuck_t - delta * 2.0, 0.0)
		# Walled out: hack at the enemy wall or gate in the way.
		if stuck_t > 1.2 and target == null and not is_worker() and order in ["amove", "idle", "attack"]:
			var wall := game.blocking_wall(self)
			if wall:
				target = wall
		if stuck_t > 1.6 and path_goal != Vector2.INF and not path_pending:
			stuck_t = 0.9
			_request_path(path_goal)
	last_pos = position


## Move toward and fight a target. Returns the desired velocity.
func _engage(e: Entity, delta: float, may_move: bool) -> Vector2:
	var dist := e.edge_distance(position) - radius
	var rng := _range()
	var min_r := 0.0 if mode == "canister" else float(d.get("min_range", 0.0))
	if deploys() and tesla_mode != "deployed":
		if tesla_mode == "packed" and dist <= rng and dist >= min_r:
			tesla_mode = "deploying"
			tesla_t = switch_time()
			path = PackedVector2Array()
			return Vector2.ZERO
		if tesla_mode != "packed":
			return Vector2.ZERO
	elif deploys() and (dist > rng or dist < min_r) and phase == "":
		target = null         # set-up guns don't chase
		return Vector2.ZERO
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
	# A swarm surrounds its prey: each Brood melee unit runs for its own side of the
	# target, so one blast or cone can't catch them all.
	if (kind == "raptor" or kind == "brute") and e is Unit:
		var ang := float(get_instance_id() % 628) * 0.01
		goal = (e as Unit).position + Vector2.from_angle(ang) * ((e as Unit).radius + radius + 4.0)
	if is_air() or (position.distance_to(goal) < 140.0 and game.line_clear(position, goal)):
		path = PackedVector2Array()
		return (goal - position).normalized() * speed
	if repath_t <= 0.0 or path.is_empty():
		repath_t = 1.0
		_request_path(game.approach_point(e, position))
	return _follow(delta)


func _attack_cycle(e: Entity, delta: float) -> void:
	if d.has("gunners"):
		facing = (e.center() - center()).normalized()
		return          # its gunners do the shooting
	facing = (e.center() - center()).normalized()
	if phase == "":
		if cooldown > 0.0 or stun_t > 0.0:
			return
		# area attacks hurt friends too: hold fire on our own, unless ordered to shoot
		if order != "attack" and not game.aoe_worth_it(self, e):
			cooldown = 0.4
			if team == game.human and Time.get_ticks_msec() > _hold_note:
				_hold_note = Time.get_ticks_msec() + 5000
				game.float_text(position + Vector2(0, -40), "Holding fire: own men in the way", Color(1, 0.85, 0.4))
			if order != "hold":
				target = null
			return
		phase = "aim"
		phase_t = _aim()
		return
	phase_t -= delta
	if phase == "aim" and phase_t <= 0.0:
		phase = "strike"
		phase_t = 0.35
		_strike(e)
	elif phase == "strike" and phase_t <= 0.0:
		phase = ""
		cooldown = _cooldown()


func _strike(e: Entity) -> void:
	if not _valid_target(e):
		return
	var dmg := float(d["damage"]) * (1.0 + minf(kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"])))
	if d["faction"] == "clockwork":
		dmg *= lerpf(0.7, 1.0, wind)
	if e.is_building():
		dmg *= float(d.get("building_bonus", 1.0))
	if mode == "bayonet":
		e.take_damage(Defs.BAYONET["damage"] * float(Defs.BAYONET["bonus"].get(e.kind, 1.0)), self)
		Sfx.play_any(["combat/pikeman_attack", "clash"], position)
		game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.6)
		return
	var powder := int(Defs.POWDER_SHOT.get(kind, 0))
	if mode == "canister":
		powder = int(Defs.CANISTER["powder"])
	if powder > 0 and not game.use_powder(team, powder):
		return    # no powder: the shot never goes off
	match kind:
		"musketeer":
			game.musket_shot(self, e, dmg)
		"cannon":
			if mode == "canister":
				game.canister_shot(self, e, Defs.CANISTER["damage"])
			else:
				game.cannon_shot(self, e.center(), dmg)
		"tesla_cart":
			game.tesla_zap(self, e, dmg)
		"spitter":
			game.acid_shot(self, e, dmg)
		"spore_mother":
			game.blob_shot(self, e.center() + Vector2(0, 12), dmg)
		"ornithopter":
			if e.is_air():
				dmg *= float(d.get("vs_air", 1.0))
			e.take_damage(dmg, self)
			game._zap_visual(center() + Vector2(0, 6), e.center(), false, true)
			Sfx.play_any(["combat/tesla_attack", "zap"], position)
		"bloater":
			if _range() > float(Defs.BLOAT["reach"]):
				# spit a glob of acid (uses gas)
				gas -= float(Defs.BLOAT["spit_cost"])
				game.acid_shot(self, e, dmg)
			else:
				game.bloat_burst(self)
				die()
		"stormcaller":
			# a short zap from the forked hands
			e.take_damage(dmg, self)
			game._zap_visual(center() + facing * 14.0 + Vector2(0, -4), e.center(), false, true)
			Sfx.play_any(["combat/tesla_attack", "zap"], position)
		"bolt":
			game.bolt_shot(self, e, dmg)
		"steam_walker":
			game.steam_cone(self, e, dmg)
		_:
			var bonus: Dictionary = d.get("bonus", {})
			dmg *= float(bonus.get(e.kind, 1.0))
			var charged := kind == "cuirassier" and run_t >= float(Defs.CHARGE["run"])
			if charged:
				dmg *= float(Defs.CHARGE["mult"])
				run_t = 0.0
			e.take_damage(dmg, self)
			if charged and e is Unit and not e.dead and not e.is_air():
				var heavy: float = 0.4 if int(e.d["supply"]) >= 3 else 1.0
				e.knock = (e.position - position).normalized() * float(Defs.CHARGE["force"]) * heavy
				e.stun_t = float(Defs.CHARGE["stun"]) * heavy
				e.phase = ""
				game.spawn_effect("dust", e.position, 1.4).scale = Vector2(0.6, 0.6)
			Sfx.play_any(["combat/%s_attack" % kind, {"raptor": "bite", "brute": "bite", "grub": "bite", "gearknight": "gear_hit", "winder": "gear_hit"}.get(kind, "clash")], position)
			game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.6)
			if kind == "brute" and e is Unit and not e.dead:
				var push: Vector2 = (e.position - position).normalized() * 26.0
				e.position = game.resolve_terrain(e.position + push, e.position, e.radius, e.team)
			# Pikeman: when the shove is ready, the thrust drives the enemy back and staggers it.
			if kind == "pikeman" and push_auto and push_cd <= 0.0 and e is Unit and not e.dead and not e.is_air():
				push_cd = Defs.PIKE_PUSH["cooldown"]
				var heavy: float = 0.4 if int(e.d["supply"]) >= 3 else 1.0
				e.knock = (e.position - position).normalized() * Defs.PIKE_PUSH["force"] * heavy
				e.stun_t = Defs.PIKE_PUSH["stun"] * heavy
				e.phase = ""
				e.take_damage(Defs.PIKE_PUSH["damage"], self)
				game.spawn_effect("smoke", e.position + Vector2(0, -4), 1.5).modulate = Color(0.85, 0.75, 0.6, 0.7)


# ------------------------------------------------------------------ workers

func _repair(delta: float) -> Vector2:
	var e := order_target
	if e == null or not is_instance_valid(e) or e.dead or e.team != team \
			or (e.hp >= e.max_hp and not (e is Unit and (e as Unit).wind < 0.98)) or (e is Building and not e.built):
		cmd_stop()
		return Vector2.ZERO
	if e.edge_distance(position) < radius + 20.0:
		work = "repairing"
		path = PackedVector2Array()
		facing = (e.center() - position).normalized()
		# repairs cost ore
		var heal := minf(Defs.REPAIR_RATE * delta, e.max_hp - e.hp)
		var cost := heal * Defs.REPAIR_COST
		if game.players[team]["gold"] < 1:
			if team == game.human:
				game.notify("Not enough ore to repair.")
			cmd_stop()
			return Vector2.ZERO
		game.players[team]["gold_f"] = float(game.players[team].get("gold_f", 0.0)) - cost
		while float(game.players[team]["gold_f"]) <= -1.0:
			game.players[team]["gold_f"] = float(game.players[team]["gold_f"]) + 1.0
			game.players[team]["gold"] -= 1
		e.hp = minf(e.max_hp, e.hp + heal)
		if e is Unit:
			(e as Unit).wind = minf(1.0, (e as Unit).wind + 0.15 * delta)     # and winds it up
		return Vector2.ZERO
	work = ""
	if e.is_unit() and position.distance_to(e.global_position) < 140.0:
		return (e.global_position - position).normalized() * speed
	if (path.is_empty() or path_i >= path.size()) and not path_pending:
		_request_path(game.approach_point(e, position))
	return _follow(delta)


func _leave_mine() -> void:
	if home_mine and is_instance_valid(home_mine):
		if home_mine is Building:
			(home_mine as Building).crew.erase(self)
		elif home_mine is GoldMine:
			home_mine.feeders.erase(self)


## Labourers and Winders stand at their post; grubs haul food from the pit to a Hive.
func _gather(delta: float) -> Vector2:
	var site := home_mine as Building
	if site == null or not is_instance_valid(site) or site.dead or not site.built:
		_leave_mine()
		var alt := game.free_site(team, position)
		if alt:
			cmd_gather(alt)
		else:
			cmd_stop()
		return Vector2.ZERO
	if kind == "grub":
		return _haul(site, delta)
	if kind == "winder" and site.d.has("battery"):
		return _haul_battery(site, delta)
	if work == "manning":
		facing = (site.center() - position).normalized()
		return Vector2.ZERO
	work = "to_site"
	if site.edge_distance(position) < radius + 18.0:
		work = "manning"
		path = PackedVector2Array()
		return Vector2.ZERO
	if (path.is_empty() or path_i >= path.size()) and not path_pending:
		_request_path(game.approach_point(site, position))
	return _follow(delta)


## Winder: take a full battery from an energy building and carry it to the nearest Ore
## Crusher. Its charge grows on the road; too long and it overloads.
var carry_t := 0.0
var carry_blue := false
var carry_empty := false        # bringing the spent battery back to the source


func _haul_battery(src: Building, delta: float) -> Vector2:
	var info: Dictionary = Defs.BATTERY["blue" if carry_blue else "yellow"]
	match work:
		"loading":
			facing = (src.center() - position).normalized()
			work_t -= delta
			if work_t <= 0.0:
				if src.batteries > 0 and game.nearest_of(position, team, "ore_crusher") != null:
					src.batteries -= 1
					carrying = 1
					carry_t = 0.0
					carry_blue = game.blue_energy(team)
					work = "to_crusher"
				else:
					work = "waiting"
			return Vector2.ZERO
		"to_crusher":
			carry_t += delta
			if carry_t >= float(info["overload"]):
				_battery_blast()
				return Vector2.ZERO
			var cr := game.nearest_of(position, team, "ore_crusher")
			if cr == null:
				return Vector2.ZERO
			if cr.edge_distance(position) < radius + 17.0:
				var value := int(round(float(info["base"]) + float(info["gain"]) * carry_t))
				game.add_gold(team, value)
				if team == game.human:
					game.float_text(position + Vector2(0, -30), "+%d" % value, Color(0.5, 0.8, 1.0) if carry_blue else Color(1, 0.9, 0.35))
				carrying = 0
				carry_t = 0.0
				carry_empty = true          # swaps it for the spent one and takes that back
				work = "to_site"
				path = PackedVector2Array()
				return Vector2.ZERO
			if (path.is_empty() or path_i >= path.size()) and not path_pending:
				_request_path(game.approach_point(cr, position))
			return _follow(delta)
		"waiting":
			facing = (src.center() - position).normalized()
			if src.batteries > 0:
				work = "loading"
				work_t = float(Defs.BATTERY["load"])
			return Vector2.ZERO
	work = "to_site"
	if src.edge_distance(position) < radius + 16.0:
		path = PackedVector2Array()
		carry_empty = false
		work = "loading" if src.batteries > 0 else "waiting"
		work_t = float(Defs.BATTERY["load"])
		return Vector2.ZERO
	if (path.is_empty() or path_i >= path.size()) and not path_pending:
		_request_path(game.approach_point(src, position))
	return _follow(delta)


## Grub on HARVEST: take the bodies of the fallen (friend or foe) near it, wrap each in a
## cocoon and carry it to the nearest Hive for essence; then come back to where it was.
var harvest_home := Vector2.ZERO
var _corpse: Unit = null


func cmd_harvest() -> void:
	_reset_work()
	order = "harvest"
	harvest_home = position
	work = ""
	target = null


func _harvest(delta: float) -> Vector2:
	if cocoon > 0:
		var hive := game.nearest_hall(position, team)
		if hive == null:
			return Vector2.ZERO
		if hive.edge_distance(position) < radius + 17.0:
			game.add_res2(team, cocoon)
			if team == game.human:
				game.float_text(position + Vector2(0, -26), "+%d essence" % cocoon, Color(0.8, 0.5, 1.0))
			cocoon = 0
			path = PackedVector2Array()
			_request_path(harvest_home)
			return Vector2.ZERO
		if (path.is_empty() or path_i >= path.size()) and not path_pending:
			_request_path(game.approach_point(hive, position))
		return _follow(delta)
	if _corpse == null or not is_instance_valid(_corpse) or not game.corpses.has(_corpse):
		_corpse = null
		work = ""
		if scan_t <= 0.0:
			scan_t = 0.8
			_corpse = game.find_corpse(self, float(Defs.HARVEST["range"]) * Defs.TILE)
			if _corpse:
				_corpse.harvester = self
				_request_path(_corpse.position)
		if _corpse == null:
			if position.distance_to(harvest_home) > 40.0:
				if (path.is_empty() or path_i >= path.size()) and not path_pending:
					_request_path(harvest_home)
				return _follow(delta)
			return Vector2.ZERO
	if position.distance_to(_corpse.position) < radius + 14.0:
		path = PackedVector2Array()
		facing = (_corpse.position - position).normalized()
		if work != "wrapping":
			work = "wrapping"
			work_t = float(Defs.HARVEST["take"])
		work_t -= delta
		if work_t <= 0.0:
			cocoon = game.corpse_value(_corpse)
			game.corpses.erase(_corpse)
			var body := _corpse
			_corpse = null
			work = ""
			var tw := body.create_tween()
			tw.tween_property(body, "modulate:a", 0.0, 0.4)
			tw.tween_callback(body.queue_free)
		return Vector2.ZERO
	if (path.is_empty() or path_i >= path.size()) and not path_pending:
		_request_path(_corpse.position)
	return _follow(delta)


func _haul(pit: Building, delta: float) -> Vector2:
	match work:
		"feeding":
			facing = (pit.center() - position).normalized()
			work_t -= delta
			if work_t <= 0.0:
				carrying = game.food_value(pit)
				work = "to_hall"
				path = PackedVector2Array()
			return Vector2.ZERO
		"to_hall":
			var hive := game.nearest_hall(pit.center(), team)
			if hive == null:
				return Vector2.ZERO
			if hive.edge_distance(position) < radius + 17.0:
				game.add_gold(team, carrying)
				if team == game.human and carrying > 0:
					game.float_text(position + Vector2(0, -26), "+%d" % carrying, Color(0.75, 1.0, 0.4))
					Sfx.play("work/grub_deliver", position, -6.0)
				carrying = 0
				work = "to_site"
				path = PackedVector2Array()
				return Vector2.ZERO
			if (path.is_empty() or path_i >= path.size()) and not path_pending:
				_request_path(game.approach_point(hive, position))
			return _follow(delta)
	work = "to_site"
	if pit.edge_distance(position) < radius + 16.0:
		work = "feeding"
		work_t = Defs.PIT_TIME
		path = PackedVector2Array()
		return Vector2.ZERO
	if (path.is_empty() or path_i >= path.size()) and not path_pending:
		_request_path(game.approach_point(pit, position))
	return _follow(delta)


## Missionary: walk to the wounded soldier, take him off the field, bandage him and send
## him back at full health.
var _patient: Unit = null


func _heal(delta: float) -> Vector2:
	if work == "bandaging":
		work_t -= delta
		if _patient == null or not is_instance_valid(_patient) or _patient.dead:
			_release_patient()
			cmd_stop()
			return Vector2.ZERO
		if work_t <= 0.0:
			_patient.hp = _patient.max_hp
			_patient.acid_t = 0.0
			_patient.cross_t = Defs.CROSS_TIME
			if team == game.human:
				game.float_text(position + Vector2(0, -30), "healed", Color(1, 1, 1))
			_release_patient()
			cmd_stop()
		return Vector2.ZERO
	var p := order_target as Unit
	if p == null or not is_instance_valid(p) or p.dead or p.off_field or p.cross_t > 0.0 or p.hp >= p.max_hp:
		cmd_stop()
		return Vector2.ZERO
	if position.distance_to(p.position) < radius + p.radius + 10.0:
		_patient = p
		p.cmd_stop()
		p.velocity = Vector2.ZERO
		p.off_field = true
		p.visible = false
		p.selected = false
		game.selection.erase(p)
		position = p.position
		work = "bandaging"
		work_t = Defs.BANDAGE_TIME
		Sfx.play("combat/missionary_heal", position)
		path = PackedVector2Array()
		return Vector2.ZERO
	if position.distance_to(p.position) < 140.0:
		return (p.position - position).normalized() * speed
	if repath_t <= 0.0 or path.is_empty():
		repath_t = 0.8
		_request_path(p.position)
	return _follow(delta)


func _release_patient() -> void:
	if _patient and is_instance_valid(_patient):
		_patient.off_field = false
		_patient.visible = true
		_patient.position = position + Vector2(14, 4)
	_patient = null
	if work == "bandaging":
		work = ""


func _build(delta: float) -> Vector2:
	var site := order_target as Building
	if work == "morphing":
		work_t -= delta
		if work_t <= 0.0:
			if site and is_instance_valid(site) and not site.dead:
				site.seeded = true
			game.consume_unit(self)
		return Vector2.ZERO
	if site == null or not is_instance_valid(site) or site.dead or site.built or (site.seeded and kind != "labourer"):
		if kind == "labourer":
			# on to the next piece of the wall (or any unfinished building close by)
			var nxt := game.next_site(self)
			if nxt:
				cmd_build(nxt)
				return Vector2.ZERO
		if kind == "winder":
			cmd_stop()
			return Vector2.ZERO
		var m := game.free_site(team, position)
		if m:
			cmd_gather(m)
		else:
			cmd_stop()
		return Vector2.ZERO
	if site.edge_distance(position) < radius + 17.0:
		path = PackedVector2Array()
		facing = (site.center() - position).normalized()
		if kind == "winder":
			# Winds the frame up; it assembles itself from here.
			site.seeded = true
			site._update_sprite()
			Sfx.play("ratchet", position)
			cmd_stop()
			return Vector2.ZERO
		if kind == "grub":
			# The grub becomes the building.
			work = "morphing"
			work_t = 1.6
			Sfx.play("burrow", position)
			position = site.rect().get_center() + Vector2(0, site.rect().size.y * 0.3)
			return Vector2.ZERO
		work = "building"
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
	_leave_mine()
	_release_patient()
	if kind == "winder" and carry_empty:
		# the spent battery drops and lies there for a while
		var b := Sprite2D.new()
		b.texture = Game.tex("res://assets/effects/battery_charge.png")
		b.hframes = 14
		b.frame = 0
		b.rotation = randf_range(1.2, 1.9)
		b.position = position + Vector2(randf_range(-8, 8), -4)
		b.z_index = -1
		game.add_child(b)
		var tw := b.create_tween()
		tw.tween_interval(CORPSE_TIME)
		tw.tween_property(b, "modulate:a", 0.0, 3.0)
		tw.tween_callback(b.queue_free)
	game.on_unit_died(self)
	Sfx.play_any(["combat/%s_death" % Sfx.SHORT.get(d["faction"], "crown"), "death_" + Sfx.SHORT.get(d["faction"], "crown")], position)
	_set_anim("death_cocoon" if kind == "grub" and cocoon > 0 and ArtData.UNITS["grub"]["frames"].has("death_cocoon_e") else "death", true)
	z_index = -1


# ------------------------------------------------------------------ animation

func _anim_name() -> String:
	if dead:
		return "death"
	var moving := velocity.length() > 10.0
	match kind:
		"musketeer":
			if mode == "bayonet":
				return "melee" if phase != "" else ("walk" if moving else "idle")
			var up := target != null and is_instance_valid(target) and target.is_air()
			if phase == "aim":
				return "aimup" if up else "aim"
			if phase == "strike":
				return "fireup" if up else "fire"
			if cooldown > 0.0 and not moving and target:
				return "reload"
		"pikeman":
			if phase != "":
				return "thrust"
			if order == "hold" and not moving:
				return "brace"
		"cannon":
			var new_art: bool = ArtData.UNITS["cannon"]["frames"].has("walk_e")
			if tesla_mode == "deploying" or tesla_mode == "packing":
				return "deploy" if ArtData.UNITS["cannon"]["frames"].has("deploy_e") else "idle"
			if tesla_mode == "packed":
				return "walk" if new_art else ("move" if moving else "idle")
			if phase != "":
				return "fire"
			if cooldown > 0.0 and target:
				return "reload"
			return "idle"
		"labourer":
			if work == "manning":
				var site := home_mine as Building
				return "mine" if site and site.kind == "farm" else "build"
			if work == "mining" or phase != "":
				return "mine"
			if work == "building":
				return "build"
			if moving and carrying > 0:
				return "carry"
		"grub":
			if work == "wrapping":
				return "wrap"
			if cocoon > 0:
				return "carry_cocoon" if moving else "idle_cocoon"
			if work == "feeding":
				return "burrow"
			if work == "morphing":
				return "morph"
			if phase != "":
				return "attack"
		"raptor", "spitter":
			if phase != "":
				return "attack"
			if kind == "raptor" and moving and target and target.edge_distance(position) < 90.0:
				return "leap"
		"brute":
			if phase != "":
				return "attack"
			if moving and target and target.edge_distance(position) < 170.0:
				return "charge"
		"winder":
			if work == "manning":
				return "wind"
			if work == "repairing":
				return "repair"
			if phase != "":
				return "attack"
			if not moving and not _in_field:
				return "wind"
		"gearknight":
			if phase != "":
				return "attack"
			if not moving and flash > 0.0:
				return "block"
		"bolt":
			if phase == "aim":
				return "crank"
			if phase == "strike":
				return "attack"
		"steam_walker":
			if phase != "":
				return "attack"
			if not moving and cooldown > 0.0 and target:
				return "vent"
		"missionary":
			if work == "bandaging":
				return "bandage"
		"skywing":
			if phase != "":
				return "attack"
		"tesla_cart":
			if tesla_mode == "deploying" or tesla_mode == "packing":
				return "deploy"
			if tesla_mode == "deployed":
				return "attack" if phase != "" else "deployed"
			return "walk" if moving else "idle"
		"spore_mother":
			if tesla_mode == "deploying" or tesla_mode == "packing":
				return "deploy"
			if phase == "cast" or (tesla_mode == "deployed" and phase != ""):
				return "fire"
			if tesla_mode == "deployed":
				return "deployed"
		"stormcaller":
			if phase == "cast":
				return "cast"
			if phase != "":
				return "attack"
		"cuirassier":
			if phase != "":
				return "attack"
		"balloon":
			return "drift" if moving else "idle"
		"ornithopter", "bloater":
			if phase != "":
				return "attack"
	return "walk" if moving else "idle"


## Animation runs at most 15 times a second, and not at all for units nobody can see.
func _animate(delta: float) -> void:
	_anim_dt += delta
	if _anim_dt < 0.066 and not dead:
		return
	if not dead and (not visible or not game.view_rect.has_point(position)):
		if _anim_dt > 0.5:
			_anim_dt = 0.0     # (keeps the clock from running away)
		return
	delta = _anim_dt
	_anim_dt = 0.0
	if powered_down() and not dead:
		(sprite.material as ShaderMaterial).set_shader_parameter("tint", Vector3(0.5, 0.52, 0.6))   # a cold statue: no frames move
		_cold = true
		return
	elif _cold:
		_cold = false
		(sprite.material as ShaderMaterial).set_shader_parameter("tint", Vector3.ONE)
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
		"death", "death_cocoon":
			fps = 7.0
			loop = false
		"wrap":
			fps = 5.0 / float(Defs.HARVEST["take"])
			loop = false
		"idle_cocoon":
			fps = 3.0
		"aim", "fire", "aimup", "fireup", "thrust", "brace", "attack", "melee":
			if kind == "spore_mother":
				fps = 6.0
			fps = 9.0
			loop = false
		"burrow":
			fps = 7.0
			loop = false
		"morph":
			fps = 3.2
			loop = false
		"leap", "charge":
			fps = 10.0
		"crank":
			fps = 6.0
			loop = false
		"repair", "wind", "vent":
			fps = 5.0
		"block":
			fps = 12.0
			loop = false
		"mine", "build":
			fps = 6.0
		"reload":
			fps = float(n) / maxf(float(d["cooldown"]) * 0.8, 0.5)
		"deploy":
			fps = float(n) / switch_time()
			loop = false
		"deployed":
			fps = 6.0 if kind != "spore_mother" else 3.0
		"cast":
			fps = float(n) / maxf(phase_t + 0.05, 0.3) if phase == "cast" else 8.0
			loop = false
		"bandage":
			fps = 4.0
	anim_t += delta * fps
	if anim_t >= 1.0:
		anim_t -= 1.0
		frame_i += 1
	frame_i = posmod(frame_i, n) if loop else mini(frame_i, n - 1)
	var shown := frame_i
	if anim == "deploy" and tesla_mode == "packing":
		shown = n - 1 - frame_i         # packing plays the deploy frames backwards
	sprite.frame = clampi(shown, 0, sprite.hframes - 1)
	if _front:
		_update_gunners()
	_bob_t += delta
	if is_air():
		# flyers hover above their shadow and drop to the ground when they die
		sprite.position.y = lerpf(sprite.position.y, 0.0, delta * 3.0) if dead else -20.0 + sin(_bob_t * 4.0) * 2.5
	elif anim == "bandage":
		sprite.position.y = -absf(sin(_bob_t * 5.0)) * 1.0
	elif kind != "cannon":
		sprite.position.y = 0.0
	# Grubs at the pit: gnaw in a loop on the last frames of the burrow.
	if kind == "grub" and anim == "burrow" and n > 3:
		sprite.frame = clampi(2 + int(_bob_t * 6.0) % (n - 2), 0, sprite.hframes - 1)
	sprite.scale.y = 1.0
	if kind == "cannon" and anim == "walk" and velocity.length() < 10.0:
		sprite.frame = 0        # the horse stands still
	if kind == "cannon" and not ArtData.UNITS["cannon"]["frames"].has("walk_e"):
		_animate_cannon(delta)   # the old one-frame sheet: rock, recoil and a spinning wheel
	elif kind in ["spitter", "bolt"]:
		# rear up / tilt the crossbow at a flyer
		var at_air: bool = target != null and is_instance_valid(target) and target.is_air() and phase != ""
		sprite.rotation = (-0.32 if not anim_flip else 0.32) if at_air else 0.0


## The cannon sheet has one frame per pose, so the crew's work is faked: the gun rocks and
## bumps along while it's pushed, recoils when it fires, and the rammer works the barrel
## (reload and idle poses swapped) while it reloads.
var _gun_t := 0.0


## The cannon's near wheel, measured on each frame (from the feet): x, y, width radius,
## height radius. Side views show it round; the diagonal views as an upright ellipse.
## Head-on and back views see the wheels edge-on, so nothing spins there.
const WHEEL_AT := {
	"idle_e": [-0.8, -13.8, 12.0, 12.0], "move_e": [-1.7, -11.7, 11.5, 11.0],
	"fire_e": [10.0, -13.0, 13.0, 13.0], "reload_e": [-4.9, -13.4, 12.4, 12.4],
	"idle_se": [-11.0, -15.0, 9.4, 14.6], "move_se": [-14.0, -13.5, 9.7, 12.7],
	"fire_se": [-2.0, -13.0, 10.0, 13.5], "reload_se": [-15.0, -12.5, 10.5, 13.5],
	"idle_ne": [7.5, -13.0, 7.5, 13.5], "move_ne": [17.5, -15.0, 7.5, 14.3],
	"fire_ne": [20.0, -15.0, 8.7, 14.0], "reload_ne": [17.0, -16.5, 8.0, 15.0],
}
var _wheel: Node2D
var _wheel_spin: Sprite2D
var _wheel_angle := 0.0
var _gun_key := ""


func _make_wheel() -> void:
	_wheel = Node2D.new()
	var back := Sprite2D.new()
	back.texture = Game.tex("res://assets/units/cannon_wheel_back.png")
	_wheel.add_child(back)
	_wheel_spin = Sprite2D.new()
	_wheel_spin.texture = Game.tex("res://assets/units/cannon_wheel.png")
	_wheel.add_child(_wheel_spin)
	sprite.add_child(_wheel)
	_wheel.visible = false


func _update_wheel(delta: float) -> void:
	if _wheel == null:
		return
	var w: Array = WHEEL_AT.get(_gun_key, [])
	_wheel.visible = not w.is_empty() and not dead
	if w.is_empty():
		return
	_wheel.position = Vector2(w[0], w[1])
	_wheel.scale = Vector2(w[2], w[3]) / 15.0
	# Rolling: the wheel turns by distance / radius (always forward: the sprite flips
	# with the cannon, and the wheel with it).
	_wheel_angle += velocity.length() * delta / maxf(w[3], 1.0)
	_wheel_spin.rotation = _wheel_angle


func _animate_cannon(delta: float) -> void:
	_gun_t += delta
	_gun_key = anim + "_" + anim_dir
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	match anim:
		"move":
			var k := _gun_t * 9.0
			sprite.rotation = sin(k * 0.5) * 0.02 * (1.0 if facing.x >= 0.0 else -1.0)
			if int(_gun_t * 4.0) != int((_gun_t - delta) * 4.0) and randf() < 0.5:
				var fx := game.spawn_effect("dust", global_position - facing * 16.0 + Vector2(randf_range(-6, 6), randf_range(-2, 2)), 1.6)
				fx.scale = Vector2(0.3, 0.3)
				fx.modulate.a = 0.55
		"fire":
			sprite.position.x = -facing.x * 5.0 * maxf(0.0, 1.0 - _gun_t * 3.0)
		"reload":
			var ram := int(_gun_t * 2.6) % 2 == 0
			var key := ("reload_" if ram else "idle_") + anim_dir
			_gun_key = key
			sprite.texture = Game.tex("res://assets/units/%s/%s.png" % [kind, key])
			sprite.position.x = facing.x * (1.0 if ram else 0.0)
		_:
			pass
	if anim != _last_gun_anim:
		_last_gun_anim = anim
		_gun_t = 0.0
		if anim != "reload":
			sprite.texture = Game.tex("res://assets/units/%s/%s.png" % [kind, anim + "_" + anim_dir])
	_update_wheel(delta)


var _last_gun_anim := ""


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
		# Closest drawn direction; side-only animations face the way we're heading.
		var near: Dictionary = {"s": ["se", "e"], "se": ["s", "e"], "e": ["se", "ne"], "ne": ["n", "e"], "n": ["ne", "e"]}
		for alt in near[dr] + ["s", "se", "e", "ne", "n"]:
			if frames.has(a + "_" + alt):
				dr = alt
				break
		if not frames.has(a + "_" + dr):
			a = "idle"
			dr = "e" if frames.has("idle_e") else "s"
		if dr == "e":
			flip = facing.x < 0.0
	anim = a
	anim_dir = dr
	anim_flip = flip
	var key := a + "_" + dr
	sprite.texture = Game.tex("res://assets/units/%s/%s.png" % [kind, key])
	sprite.hframes = frames.get(key, 1)
	var anchor: Vector2 = ArtData.UNITS[kind]["anchor"]
	# some sheets (aiming up) have extra room on top: the feet stay where they were
	var cell: Vector2i = ArtData.UNITS[kind]["cell"]
	sprite.offset = -anchor - Vector2(0, sprite.texture.get_height() - cell.y)
	sprite.scale.x = -1.0 if flip else 1.0
	frame_i = mini(frame_i, sprite.hframes - 1)


func _draw() -> void:
	if dead:
		# a veteran's body: how much essence it holds, for the Brood to see
		if kills > 0 and game.corpses.has(self):
			_draw_number(game.corpse_value(self), Vector2(0, -26))
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, radius + 2.0, Color(0, 0, 0, 0.25))
	if selected:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 24, Color(0.4, 1.0, 0.4, 0.9), 2.0)
	draw_set_transform(Vector2.ZERO)
	var top := -float(ArtData.UNITS[kind]["anchor"].y) - 4.0
	if kind == "pikeman":
		top = -44.0
	elif kind == "cannon":
		top = -64.0 if not ArtData.UNITS["cannon"]["frames"].has("walk_e") else -float(ArtData.UNITS[kind]["anchor"].y) * 0.75
	draw_health(top, radius * 2.4)
	if work == "feeding":
		return
	if d["faction"] == "clockwork" and not is_worker():
		# the battery on its back, for everyone to see: how much charge is left
		var bt: Texture2D = Game.tex("res://assets/effects/battery_charge.png")
		var fr := clampi(int(round(wind * 13.0)), 0, 13)
		var bx := -radius - 7.0 if not anim_flip else radius - 5.0
		draw_texture_rect_region(bt, Rect2(bx, top * 0.6 - 4.0, 12, 26), Rect2(fr * 10, 0, 10, 22), Color(1, 1, 1) if wind > 0.0 else Color(0.6, 0.6, 0.6))
	if carrying > 0 and kind == "labourer" and anim != "carry":
		draw_circle(Vector2(6, -14), 3, Color(1, 0.85, 0.2))
	if carry_empty and carrying == 0 and kind == "winder":
		var et: Texture2D = Game.tex("res://assets/effects/battery_charge.png")
		draw_texture_rect_region(et, Rect2(-14, top + 10, 10, 22), Rect2(0, 0, 10, 22))
	if carrying > 0 and kind == "winder":
		# the battery on its back, and how close it is to overloading
		var info: Dictionary = Defs.BATTERY["blue" if carry_blue else "yellow"]
		var f := clampf(carry_t / float(info["overload"]), 0.0, 1.0)
		var bt: Texture2D = Game.tex("res://assets/effects/battery_%s.png" % ("blue" if carry_blue else "yellow"))
		var fr := int(_bob_t * 10.0) % 13
		draw_texture_rect_region(bt, Rect2(-14, top + 10, 11, 22), Rect2(fr * 11, 0, 11, 22))
		draw_rect(Rect2(-15, top + 33, 13, 3), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, top + 34, 11 * f, 1), Color(0.4, 1, 0.3).lerp(Color(1, 0.2, 0.1), f))
	if kind == "bloater" and team == game.human:
		var w := radius * 2.0
		draw_rect(Rect2(-w * 0.5, top + 7.0, w, 2), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w * 0.5, top + 7.0, w * gas / 100.0, 2), Color(0.75, 0.95, 0.25))
	if cocoon > 0 and not ArtData.UNITS["grub"]["frames"].has("carry_cocoon_e"):
		# the cocoon on its back (drawn by hand when there's no sheet)
		draw_set_transform(Vector2(0, -17), 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, 6.0, Color(0.86, 0.82, 0.68))
		draw_arc(Vector2.ZERO, 6.0, 0, TAU, 14, Color(0.45, 0.35, 0.25), 1.0)
		draw_line(Vector2(-5, -2), Vector2(5, 2), Color(0.6, 0.5, 0.4), 1.0)
		draw_line(Vector2(-5, 2), Vector2(5, -2), Color(0.6, 0.5, 0.4), 1.0)
		draw_set_transform(Vector2.ZERO)
	if kills > 0 and not is_worker():
		# veteran pips: a gold one per kill, up to 5 (a red one after 10)
		var pips := mini(kills, 5)
		for i in pips:
			draw_rect(Rect2(-pips * 2.5 + i * 5.0, top - 6.0, 3, 3), Color(1, 0.82, 0.3) if kills < 10 else Color(1, 0.35, 0.25))
	if carrying > 0 and kind == "grub":
		draw_circle(Vector2(0, -16), 3.5, Color(0.55, 0.85, 0.3))
		draw_circle(Vector2(0, -16), 3.5, Color(0.2, 0.3, 0.1), false, 1.0)
	if cross_t > 0.0:
		# just bandaged: a little cross over his head
		var y := top - 12.0
		var a := minf(cross_t, 1.0)
		draw_texture(Game.tex("res://assets/effects/cross.png"), Vector2(-6, y - 6), Color(1, 1, 1, a))
