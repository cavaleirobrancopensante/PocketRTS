class_name Unit
extends Entity
## A unit: moves along A* paths with soft separation, follows orders
## (move, attack-move, attack, hold, gather, build) and fights by type.

const WALK_FPS := 8.0
## Mist Toad: the frame of its tongue strip with the mouth wide open, the tongue not out yet.
const TOAD_MOUTH_OPEN := 2
## Tesla Cart: the glowing sphere on top of the deployed coil, from the feet, per drawn
## direction (facing right; x mirrored when the sprite is flipped). Measured by
## tools/import_round9.py.
const COIL_TOP := {"s": Vector2(0, -53), "se": Vector2(1, -54), "e": Vector2(3, -57),
		"ne": Vector2(1, -57), "n": Vector2(-1, -57)}

var d: Dictionary
var order := "idle"            # idle, move, amove, attack, hold, gather, build
var order_point := Vector2.ZERO
var target: Entity = null      # who we're fighting
var order_target: Entity = null  # explicit attack target / mine / construction site
## Shift-queued orders (computer, as in StarCraft): what this unit does after its current
## order, oldest first. Each is {"o": move/amove/attack/build/repair/gather/wall, "p", "e",
## "pieces"}. A plain order clears it; it isn't kept in saves (units come back without one).
const QUEUE_MAX := 16
var queue: Array = []
var line_rest: Array = []        # a queued wall being built: the pieces still to do after this one
var _keep_queue := false         # set while a queued order is being started (it mustn't clear the queue)
var velocity := Vector2.ZERO
var facing := Vector2.DOWN
var radius := 10.0
var speed := 60.0

var path := PackedVector2Array()
var path_i := 0
var path_goal := Vector2.INF
var path_pending := false
var stuck_t := 0.0
var squeeze_t := 0.0            # > 0: walking out of a sealed pocket through a building's edge (last resort)
var wall_flee_t := 0.0          # (computer) pulled back from a wall that shooters behind it cover
var _wall_chk := 0.0
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
var load_f := 0.0                # (a grub) the exact value of the food it carries (`carrying` is it rounded)
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
var mode := ""                  # musketeer "" (musket) or "bayonet" (chosen by itself); cannon "" (round shot) or "canister"
var _melee_t := 0.0             # musketeer: when it next looks for an enemy close enough for the bayonet
var art := ""                   # whose sprites it wears (an armoured Musketeer: "musketeer_armoured")
var armoured := false           # Musketeer: refitted with Armour (or came out with it)
var lock := ""                  # Musketeer: his musket lock ("", or one of Defs.LOCKS)
var refit: Array = []           # Musketeer on a "refit" order: the upgrades he's going to get (paid)
var refit_paid := [0, 0]        # what was paid for them (back if the refit is called off)
var _refit_t := 0.0
var auto_refit := false         # Powder Wagon: AUTO REFIT (idle Musketeers nearby get the upgrades researched)
# Missionary raising the fallen; a raised soldier's second life
var _body: Unit = null          # (a Missionary) the body he's going to raise
var reviver: Unit = null        # (a body) the Missionary coming to raise it
var died_at := 0.0              # (a body) the game clock when it fell
var final_death := false        # (a body) fell under the cross: it can't be raised again
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
var held_t := 0.0               # a set-up gun holding fire for its own men: it stays set up meanwhile
var auto_repair := false        # REPAIR autocast: idle, it fixes damaged buildings nearby first (Winders: on from the start)
var _cold := false
var slow_t := 0.0              # slowed (Bloater acid)
var kills := 0                  # veterancy
var harvester: Unit = null      # (a body) the grub coming to take it
var cocoon := 0                 # (a grub) essence it carries home
var gas := 100.0                # Bloater: what's left in the sac (spits use it, the burst scales with it)
# A Musketeer in a balloon's basket: its pose up there (gun_state[0], "idle"/"down"/"up") and
# how long it has held it
var gun_cd: Array = [0.0, 1.5]
var gun_state: Array = ["idle", "idle"]
var gun_t: Array = [0.0, 0.0]
var _pilot_spr: Sprite2D        # (a balloon) its basket with the pilot in it (over the envelope and rigging)
var _pass_sprites: Array = []   # (a balloon) the men it carries, shoulder to shoulder in the basket
var _front: Sprite2D
var _hold_note := 0             # when this unit may next say it's holding fire           # workers: go back to work on their own when idle
# Observation Balloon as a dropship
var passengers: Array = []      # (a balloon) the men in its basket
var incoming: Array = []        # (a balloon) men walking over to climb in
var aboard: Unit = null         # (a passenger) the balloon it rides in
var _board_t := 0.0
var _descend := 0.0             # (a balloon) 1 = down low, taking men on or letting them off
var haul_t := -1.0              # (a balloon) a powder keg on the rope: seconds hauled so far (-1: none)
var haul_shots := 0.0           # (a balloon) shots in that keg (already paid for)
var haul_at := Vector2.ZERO     # (a balloon) where the rope reaches the ground, from the balloon
var haul_from: Entity = null    # (a balloon) the wagon or building the keg comes from
# Skywing: "air" (hunts flyers), "to_land" (flying to a spot it can land on), "landing",
# "ground" (walks and bites), "lifting"
var sky := "air"
var sky_t := 0.0
var sky_cd := 0.0               # (the computer) not too many landings and take-offs
var _land_at := Vector2.INF
# Bloater out of gas: "" (normal), "deflating", "flat", "refilling"
var deflate := ""
var deflate_t := 0.0
# Ornithopter: COURIER (fetch batteries, wind up constructs) and the battery it carries
var courier := false
var topter_bat := ""            # "", "yellow" or "blue"
var _wind_target: Unit = null
var _courier_t := 0.0
# Clockwork construct overloaded by an Ornithopter's battery
var overclock_t := 0.0
var _spark_t := 0.0
var _hot := false
# Clockwork rework
var overcharge_t := 0.0         # seconds in overcharge ground (Boiler, Pylon, deployed Tesla Cart)
var _in_ovc := false
var spin := 0.0                 # Thresher: 0..1, how far its saws have spun up
var _spin_idle := 0.0           # Thresher: seconds since its last blow
var braced := false             # Bulwark: the tower shield planted
var brace_t := 0.0              # Bulwark: planting / lifting the shield
var _shield_t := 0.0            # Bulwark: a shot just hit the shield (braced_hit)
var self_wind_t := 0.0          # Winder: stopped to wind itself
var cranked_t := 0.0            # Wind-up Soldier: a Winder is cranking it (wind-up anim)
# Mist Toad (its energy is `charge`): TONGUE
var tongue_victim: Unit = null  # who its tongue is on
var tongue_stage := ""          # "", "windup" (the crosshair), "lash" (the tongue flies out), "pull"
var tongue_t := 0.0             # what's left of this stage
var _tongue_at := Vector2.ZERO  # where it sat when the windup began
var _pull_from := Vector2.ZERO  # where the victim was when the pull began


## Overcharged: long enough in overcharge ground (and still there).
func overcharged() -> bool:
	return _in_ovc and overcharge_t >= float(Defs.OVERCHARGE["time"])


## Bulwark: plant (or lift) the tower shield. Braced it can't move.
func set_brace(on: bool) -> void:
	if kind != "bulwark" or braced == on or aboard:
		return
	if on:
		cmd_hold()         # it stands where it is and pokes at what comes in reach
		var foe := game.find_target(self, sight * Defs.TILE)
		if foe:
			facing = (foe.center() - center()).normalized()
		frame_i = 0
		anim_t = 0.0
	elif order == "hold":
		order = "idle"
	braced = on
	brace_t = float(Defs.BRACE["switch"])
	armor = float(Defs.BRACE["armor"]) if on else float(d["armor"])


## Bulwark: a shot hit the planted shield.
func shield_hit() -> void:
	_shield_t = 0.4
	if visible and game.view_rect.has_point(position):
		game.spawn_effect("hit", center() + facing * 10.0 + Vector2(randf_range(-4, 4), randf_range(-8, 4)), 1.2)


## Wind-up Soldiers (springs) run down; constructs drain their battery.
func runs_on_spring() -> bool:
	return d.get("spring", false)
static var _sky_ground := {}
# Crown powder logistics
var powder := 0.0               # Musketeer / Cannon: shots carried; Powder Wagon: shots in store
var _pmax := 0.0                # how many it can hold (0: it doesn't use personal powder)
var _powder_t := 0.0
var _auto_bayonet := false      # Musketeer: on the bayonet because it ran dry (the musket again once refilled)
var supplying := false          # Powder Wagon: SUPPLY on (labourers bring kegs from the Powder Mill)
var _supply_t := 0.0
var _dispense_t := 0.0          # Powder Wagon: handing out powder (plays its unload pose)
var keg := false                # Labourer: carrying a powder keg (it blows up if he's killed)


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


var _rip: Tween                  # (a body) lying there, then fading away


func _rest_in_peace() -> void:
	queue_redraw()
	set_physics_process(false)
	set_process(false)
	# bodies the Brood can harvest, or a Missionary raise, lie there longer
	var lie := float(Defs.HARVEST["time"]) if game.corpses.has(self) else CORPSE_TIME
	if game.fallen.has(self):
		lie = maxf(lie, float(Defs.REVIVE["window"]) - corpse_t)
	_rip = create_tween()
	_rip.tween_interval(lie)
	_rip.tween_callback(func() -> void:
		game.corpses.erase(self)
		game.fallen.erase(self))
	_rip.tween_property(self, "modulate:a", 0.0, 3.0)
	_rip.tween_callback(queue_free)


## (a body) raised by a Missionary: back on the field with part of its health, under the
## cross for a while (fall again under it and it's for good).
func revive() -> void:
	if _rip and _rip.is_valid():
		_rip.kill()
	_rip = null
	game.corpses.erase(self)
	game.fallen.erase(self)
	dead = false
	reviver = null
	harvester = null
	hp = max_hp * float(Defs.REVIVE["hp"])
	cross_t = float(Defs.REVIVE["cross"])
	acid_t = 0.0
	stun_t = 0.0
	slow_t = 0.0
	knock = Vector2.ZERO
	velocity = Vector2.ZERO
	corpse_t = 0.0
	modulate.a = 1.0
	z_index = 3 if is_air() else 0
	target = null
	phase = ""
	cooldown = 0.0
	_reload = 0.0
	mode = ""
	_auto_bayonet = false
	set_physics_process(true)
	set_process(true)
	cmd_stop()
	frame_i = 0
	anim_t = 0.0
	_set_anim("idle", true)
	_draw_key = Vector4i(-1, -1, -1, -1)
	queue_redraw()
	game.on_unit_revived(self)


## A Musketeer refitted with Armour: +armour, +health, and the armoured sprites.
func put_on_armour() -> void:
	if kind != "musketeer" or armoured:
		return
	var info: Dictionary = Defs.RESEARCH["armour"]
	armoured = true
	armor = float(d["armor"]) + float(info["armor"])
	max_hp = float(d["hp"]) + float(info["hp"])
	hp = minf(max_hp, hp + float(info["hp"]))
	if ArtData.UNITS.has("musketeer_armoured"):
		art = "musketeer_armoured"
	if sprite and not dead:
		_set_anim(anim if anim != "" else "idle", true)
	queue_redraw()


## A Musketeer's kit ({"armour": bool, "lock": key}): a recruit's, or a saved one.
func set_kit(kit: Dictionary) -> void:
	if kind != "musketeer":
		return
	if kit.get("armour", false):
		put_on_armour()
	var lk := String(kit.get("lock", ""))
	if Defs.LOCKS.has(lk) and Defs.LOCKS.find(lk) > lock_level():
		lock = lk
	queue_redraw()


func get_kit() -> Dictionary:
	return {"armour": armoured, "lock": lock}


## His lock as a number: -1 none, 0 matchlock, 1 flintlock, 2 caplock (`pending`: counting
## the one he's on his way to get).
func lock_level(pending := false) -> int:
	var lv := Defs.LOCKS.find(lock)
	if pending:
		for w in refit:
			lv = maxi(lv, Defs.LOCKS.find(w))
	return lv


## The upgrades he has, for the unit card: "Armour · Flintlock" ("" for none).
func kit_text() -> String:
	var parts: Array = []
	if armoured:
		parts.append("Armour")
	if lock != "":
		parts.append(String(Defs.RESEARCH[lock]["name"]))
	return " · ".join(parts)


## Paid for `what` (Game.refit_order / AUTO REFIT): off to `place` to get it, or, already
## on his way to a refit, it's added to that one (a later lock replaces the one he was
## going for, which is paid back).
func add_refit(place: Entity, what: String, fee: Array) -> void:
	if order == "refit" and not refit.is_empty():
		if Defs.LOCKS.has(what):
			for w in refit.duplicate():
				if Defs.LOCKS.has(w):
					var back := Game.refit_fee(w)
					refit.erase(w)
					refit_paid = [int(refit_paid[0]) - back[0], int(refit_paid[1]) - back[1]]
					game.refund_refit(team, back)
		refit.append(what)
		refit_paid = [int(refit_paid[0]) + int(fee[0]), int(refit_paid[1]) + int(fee[1])]
		return
	cmd_refit(place, [what], fee)


func cmd_refit(place: Entity, what: Array, fee: Array) -> void:
	if aboard:
		game.refund_refit(team, fee)
		return
	_reset_work()
	order = "refit"
	order_target = place
	target = null
	refit = what.duplicate()
	refit_paid = [int(fee[0]), int(fee[1])]
	_refit_t = 0.0
	work = "to_refit"
	work_t = 0.0
	repath_t = 0.0


## The refit called off (another order, killed, the place gone): the fees back.
func _cancel_refit() -> void:
	if refit.is_empty():
		return
	game.refund_refit(team, refit_paid)
	refit.clear()
	refit_paid = [0, 0]
	_refit_t = 0.0


func _refit_run(delta: float) -> Vector2:
	var p = order_target
	if p == null or not is_instance_valid(p) or p.dead or (p is Building and not p.built) \
			or (p is Unit and (p.off_field or p.aboard != null)) or refit.is_empty():
		if team == game.human and not refit.is_empty():
			game.notify("Refit called off: the place is gone. Paid back.")
		cmd_stop()          # (the fee goes back)
		return Vector2.ZERO
	var at: Vector2 = p.position if p is Unit else p.center()
	var gap: float = p.edge_distance(position) - radius - (p.radius if p is Unit else 0.0)
	if gap < float(Defs.REFIT["reach"]) or (work == "refitting" and gap < float(Defs.REFIT["reach"]) + 30.0):
		# there: a couple of seconds with the armourer
		path = PackedVector2Array()
		facing = (at - position).normalized() if at != position else facing
		work = "refitting"
		_refit_t += delta
		if _refit_t >= float(Defs.REFIT["time"]):
			var done := refit.duplicate()
			for w in done:
				if w == "armour":
					put_on_armour()
				elif Defs.LOCKS.find(w) > lock_level():
					lock = w
			refit.clear()
			refit_paid = [0, 0]
			game.refit_done(self, done)
			queue_redraw()
			cmd_stop()
		return Vector2.ZERO
	work = "to_refit"
	work_t += delta
	if work_t > float(Defs.REFIT["give_up"]):
		if team == game.human:
			game.notify("A Musketeer couldn't reach the place to be refitted. Paid back.")
		cmd_stop()
		return Vector2.ZERO
	# a wagon may be on the move: head straight for it when close, else find the way there
	if position.distance_to(at) < 140.0 and game.line_clear(position, at):
		path = PackedVector2Array()
		return (at - position).normalized() * speed
	if repath_t <= 0.0 or ((path.is_empty() or path_i >= path.size()) and not path_pending):
		repath_t = 1.5
		_request_path(game.approach_point(p, position) if p is Building else at)
	return _follow(delta)


## Musketeer reload with his own lock.
func musket_cooldown() -> float:
	var m := 1.0
	if kind == "musketeer" and Defs.RESEARCH.has(lock):
		m = float(Defs.RESEARCH[lock]["reload"])
	return float(d["cooldown"]) * m


## A Clockwork construct with no charge left.
func powered_down() -> bool:
	return d["faction"] == "clockwork" and not is_worker() and wind <= 0.0


func is_worker() -> bool:
	return Defs.is_worker(kind)


func is_air() -> bool:
	return d.get("air", false)


## Can this unit attack that one at all?
func can_hit(e: Entity) -> bool:
	if d.get("medic", false) or d.get("no_attack", false) or e.untouchable():
		return false
	if deflate != "" or (kind == "skywing" and sky != "air" and sky != "ground"):
		return false            # a deflated Bloater, a Skywing landing or taking off
	if e.is_air() and d.get("ground_only", false):
		return false
	if not e.is_air() and d.get("air_only", false):
		return false            # (buildings too)
	if e.is_air():
		# the cannon's canister is the Crown's answer to massed flyers; round shot can't
		if kind == "cannon":
			return mode == "canister"
		if not d.get("anti_air", false) or mode == "bayonet":
			return false
	return true


## Musketeer: the musket at range, the bayonet on an enemy (on the ground) that comes
## close, or on anything once its powder has run dry (the musket again once it has
## POWDER.rearm shots). Chosen between blows, never in the middle of one. The musket keeps
## reloading while it stabs.
var _reload := 0.0              # Musketeer: what's left of the musket's reload


func _pick_weapon(delta: float) -> void:
	_reload = maxf(_reload - delta, 0.0)
	_melee_t -= delta
	if phase != "" or _melee_t > 0.0:
		return
	_melee_t = 0.2
	if powder < 1.0 and not _auto_bayonet:
		_auto_bayonet = true
		game.out_of_powder(self)       # (it fixes bayonets meanwhile)
	elif _auto_bayonet and powder >= float(Defs.POWDER["rearm"]):
		_auto_bayonet = false
	# an enemy on top of us (an ordered target first, then whoever is closest)
	var close: Unit = null
	var reach := float(Defs.BAYONET["close"])
	var cd := INF
	for o in game.units_near(position, reach + radius + 30.0):
		if not game.hostile(o.team, team) or o.dead or o.off_field or o.is_air() or o.untouchable():
			continue
		var gap: float = o.position.distance_to(position) - o.radius - radius
		if gap > reach:
			continue
		if o == order_target or o == target:
			gap -= 100.0
		if gap < cd:
			cd = gap
			close = o
	# (ordered to shoot something else: it keeps shooting while it has powder)
	if close and order == "attack" and close != order_target and not _auto_bayonet:
		close = null
	var want := "bayonet" if close != null or _auto_bayonet else ""
	if want != mode:
		if mode == "":
			_reload = maxf(_reload, cooldown)
			cooldown = minf(cooldown, float(Defs.BAYONET["cooldown"]))
		else:
			cooldown = maxf(cooldown, _reload)
		mode = want
		if target and not _valid_target(target):
			target = null
	if close and target != close and (target == null or not (target is Unit) or target.edge_distance(position) - radius > float(Defs.BAYONET["range"])):
		target = close


## A fighting unit (it gets a reload bar over its head; workers, medics and wagons don't).
func has_attack() -> bool:
	return not is_worker() and float(d["damage"]) > 0.0 and not d.get("medic", false) and not d.get("no_attack", false)


## How far its weapon is through reloading: 0 just fired, 1 ready.
func reload_frac() -> float:
	if phase == "strike":
		return 0.0
	if phase != "":
		return 1.0
	return 1.0 - clampf(cooldown / maxf(_cooldown(), 0.01), 0.0, 1.0)


## Shots of powder this unit can carry (a Powder Wagon: its whole store).
func max_powder() -> float:
	if kind == "powder_wagon":
		return float(Defs.WAGON["store"])
	if kind == "balloon":
		return float(Defs.BALLOON["store"])
	return float(Defs.POWDER.get(kind, 0))


## A finished Powder Mill, Barracks or Town Hall of ours within reach (refills for free).
func _powder_building() -> Building:
	var reach := float(Defs.POWDER["range"]) * Defs.TILE
	for b in game.buildings:
		if b.team == team and b.built and not b.dead and (Defs.POWDER["from"] as Array).has(b.kind) and b.edge_distance(position) < reach:
			return b
	return null


## Personal powder: refill near a powder building or a stocked wagon; a Powder Wagon fills
## its store near a building (paid from the bank) and calls labourers to bring kegs.
func _powder_tick(delta: float) -> void:
	if kind == "balloon":
		_basket_powder(delta)
		return
	_dispense_t = maxf(_dispense_t - delta, 0.0)
	if kind == "powder_wagon" and supplying:
		_supply_t -= delta
		if _supply_t <= 0.0:
			_supply_t = 1.0
			game.call_runners(self)
	_powder_t -= delta
	if _powder_t > 0.0:
		return
	_powder_t = 0.5
	var step := 0.5
	if powder >= _pmax:
		return
	if kind == "powder_wagon":
		if _powder_building() == null:
			return
		var room := minf(float(Defs.WAGON["fill"]) * step, _pmax - powder)
		var bank := float(game.players[team]["res2"])
		room = minf(room, bank * float(Defs.WAGON["per_powder"]))
		if room <= 0.0:
			if team == game.human:
				game.powder_short()
			return
		game.players[team]["res2"] = bank - room / float(Defs.WAGON["per_powder"])
		powder += room
		return
	var amount := minf(float(Defs.POWDER["refill"]) * step, _pmax - powder)
	var cost := float(Defs.POWDER["cost"].get(kind, 0.5))      # powder a shot
	if _powder_building() != null:
		# from the stores: the bank pays; with the bank empty the refill waits
		var bank := float(game.players[team]["res2"])
		amount = minf(amount, bank / cost)
		if amount <= 0.0:
			if team == game.human:
				game.powder_short()
			return
		game.players[team]["res2"] = bank - amount * cost
		powder += amount
		return
	# from a wagon's store (counted in musket shots: a cannon shot takes 3)
	var per := cost / float(Defs.POWDER["cost"]["musketeer"])
	for o in game.units_near(position, float(Defs.POWDER["range"]) * Defs.TILE + 16.0):
		if o.kind == "powder_wagon" and o.team == team and not o.dead and not o.off_field and o.powder > 0.0:
			var take := minf(amount, o.powder / per)
			o.powder -= take * per
			o._dispense_t = 0.8
			powder += take
			return


## Cannon: round shot (long range, splash, smashes buildings) or canister (short range,
## a cone of musket balls that shreds crowds).
## Bloater: HOLD GAS (no spitting, a full-size burst) or SPIT.
func set_hold_gas(on: bool) -> void:
	if kind != "bloater":
		return
	mode = "hold" if on else ""
	phase = ""


## Powder Wagon: SUPPLY on: up to two labourers bring it kegs from the Powder Mill while it
## has room for one. (Runners already carrying a keg still deliver it when it goes off.)
func set_supply(on: bool) -> void:
	if kind != "powder_wagon":
		return
	supplying = on
	_supply_t = 0.0


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
	if kind == "musketeer":
		return musket_cooldown()
	if overclock_t > 0.0:
		return float(d["cooldown"]) * float(Defs.OVERLOAD["cooldown"])
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


## Musketeers carried in the basket shoot: each with its own reload, range, damage and
## powder (topped up from the balloon's store), spreading their fire.
func _basket_fire(delta: float) -> void:
	var taken: Entity = null
	for pi in passengers.size():
		var p = passengers[pi]
		if not is_instance_valid(p) or p.dead or p.kind != "musketeer":
			continue
		p.gun_t[0] = float(p.gun_t[0]) + delta
		if p.gun_state[0] != "idle" and float(p.gun_t[0]) > 0.7:
			p.gun_state[0] = "idle"
		p.cooldown = maxf(p.cooldown - delta, 0.0)
		if p.cooldown > 0.0 or stun_t > 0.0 or p.powder < 1.0:
			continue
		var rng := float(p.d["range"])
		var best: Entity = null
		var bd := INF
		for o in game.units_near(position, rng + 40.0):
			if not game.hostile(o.team, team) or o.dead or o.off_field or not p.can_hit(o) or not game.side_sees(team, o.position):
				continue
			var dd: float = o.center().distance_to(center())
			if dd > rng:
				continue
			if o == taken:
				dd += 80.0
			if dd < bd:
				bd = dd
				best = o
		if best == null:
			continue
		p.powder -= 1.0          # his own powder, as on the ground
		taken = best
		p.cooldown = p.musket_cooldown() + randf_range(0.0, 0.3)
		p.gun_state[0] = "up" if best.is_air() else "down"
		p.gun_t[0] = 0.0
		var muzzle := center() + Vector2(randf_range(-4.0, 4.0), -4.0)
		if _pass_sprites.size() > pi and (_pass_sprites[pi] as Sprite2D).visible:
			muzzle = (_pass_sprites[pi] as Sprite2D).global_position + Vector2(0, -6)
		p.facing = (best.center() - muzzle).normalized()
		if game.fog_blinds(p, best) and randf() < float(Defs.FOG["miss"]):
			game.fog_miss(p, best)
			continue
		var dmg := float(p.d["damage"]) * (1.0 + minf(p.kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"])))
		game.musket_shot(p, best, dmg, muzzle)


## (a balloon) its powder store: the Musketeers aboard top up from it, and hovering still
## near a Powder Wagon or a powder building the pilot hauls kegs up on a rope (Defs.BALLOON).
func _basket_powder(delta: float) -> void:
	var still := velocity.length() < 12.0
	if haul_t >= 0.0:
		if not still:
			_haul_cancel()          # moving off: the rope comes in, the keg goes back
		else:
			haul_t += delta
			if haul_t >= float(Defs.BALLOON["haul"]):
				powder = minf(_pmax, powder + haul_shots)
				if team == game.human and visible:
					game.float_text(position + Vector2(0, -60), "+%d shots" % int(haul_shots), Color(1, 0.85, 0.5))
				haul_t = -1.0
				haul_shots = 0.0
				haul_from = null
	_powder_t -= delta
	if _powder_t > 0.0:
		return
	_powder_t = 0.5
	for p in passengers:
		if is_instance_valid(p) and not p.dead and p._pmax > 0.0 and p.powder < p._pmax and powder > 0.0:
			var take := minf(minf(float(Defs.POWDER["refill"]) * 0.5, p._pmax - p.powder), powder)
			p.powder += take
			powder -= take
			if p.powder >= float(Defs.POWDER["rearm"]):
				p._auto_bayonet = false
	if haul_t < 0.0 and still and _pmax - powder >= 1.0:
		_haul_start()


## (a balloon) the wagon or building within reach it can haul powder up from (null: none).
func haul_source() -> Entity:
	var reach := float(Defs.BALLOON["reach"]) * Defs.TILE
	var best: Entity = null
	var bd := INF
	for o in game.units_near(position, reach + 24.0):
		if o.kind == "powder_wagon" and o.team == team and not o.dead and not o.off_field and o.powder >= 1.0:
			var dd: float = o.position.distance_to(position)
			if dd < reach + o.radius and dd < bd:
				bd = dd
				best = o
	if best:
		return best
	for b in game.buildings:
		if b.team == team and b.built and not b.dead and (Defs.POWDER["from"] as Array).has(b.kind):
			var dd: float = b.edge_distance(position)
			if dd < reach and dd < bd:
				bd = dd
				best = b
	return best


## (a balloon) the pilot lowers the rope: a keg is paid for (bank or wagon) and starts up.
func _haul_start() -> void:
	var src := haul_source()
	if src == null:
		return
	var shots := minf(float(Defs.BALLOON["keg"]), _pmax - powder)
	if src is Unit:
		shots = minf(shots, (src as Unit).powder)
		(src as Unit).powder -= shots
		(src as Unit)._dispense_t = float(Defs.BALLOON["haul"])
	else:
		var bank := float(game.players[team]["res2"])
		shots = minf(shots, bank * float(Defs.WAGON["per_powder"]))
		if shots < 1.0:
			if team == game.human:
				game.powder_short()
			return
		game.players[team]["res2"] = bank - shots / float(Defs.WAGON["per_powder"])
	haul_shots = shots
	haul_from = src
	haul_t = 0.0
	# the rope comes down beside the basket, leaning toward where the keg comes from
	var to: Vector2 = (src.position if src is Unit else src.center()) - position
	haul_at = to.limit_length(26.0) + Vector2(0, 4)


## (a balloon) the rope comes back in without its keg: it goes back where it came from.
func _haul_cancel() -> void:
	if haul_t < 0.0:
		return
	if haul_from is Unit and is_instance_valid(haul_from) and not haul_from.dead:
		var w := haul_from as Unit
		w.powder = minf(w.max_powder(), w.powder + haul_shots)
	elif not dead:
		game.add_res2(team, haul_shots / float(Defs.WAGON["per_powder"]))
	haul_t = -1.0
	haul_shots = 0.0
	haul_from = null


## (a balloon) RESTOCK: fly to the nearest Powder Wagon with powder or powder building and
## hover there while the pilot hauls kegs up, until the store is full.
func cmd_restock() -> bool:
	if kind != "balloon":
		return false
	var best: Entity = null
	var bd := INF
	for o in game.units:
		if o.kind == "powder_wagon" and o.team == team and not o.dead and not o.off_field and o.powder >= float(Defs.BALLOON["keg"]):
			var dd: float = o.position.distance_to(position)
			if dd < bd:
				bd = dd
				best = o
	for b in game.buildings:
		if b.team == team and b.built and not b.dead and (Defs.POWDER["from"] as Array).has(b.kind):
			var dd: float = b.center().distance_to(position)
			if dd < bd:
				bd = dd
				best = b
	if best == null:
		return false
	_reset_work()
	order = "restock"
	order_target = best
	target = null
	order_point = best.position + Vector2(0, -18) if best is Unit else best.center()
	repath_t = 1.5
	if position.distance_to(order_point) > 8.0:
		_request_path(order_point)
	return true


func _restock(delta: float) -> Vector2:
	var src := order_target
	if powder >= _pmax and haul_t < 0.0:
		cmd_stop()
		return Vector2.ZERO
	if src == null or not is_instance_valid(src) or src.dead:
		if haul_t < 0.0:
			cmd_stop()
		return Vector2.ZERO
	if haul_source() != null or haul_t >= 0.0:
		path = PackedVector2Array()
		return Vector2.ZERO        # there: hover while the pilot hauls
	if position.distance_to(order_point) < 10.0:
		cmd_stop()                 # nothing to haul from here (an empty wagon)
		return Vector2.ZERO
	if src is Unit and repath_t <= 0.0:
		order_point = src.position + Vector2(0, -18)      # a wagon may roll on: follow it
		repath_t = 1.5
		_request_path(order_point)
	elif path.is_empty() and not path_pending:
		repath_t = 1.5
		_request_path(order_point)
	return _follow(delta)


## Where the men stand in the basket: offsets (body pixels) from the middle of the basket's
## front rim (ArtData "gunners" point of each facing, from tools/import_balloon2.py), two
## each side of the pilot, packed shoulder to shoulder inside the rim (the wicker is 44 px
## across at the rim; a rider at this scale is about 13 px wide, so the outer two stay inside
## it and the front rim hides their legs); drawn at `scale` of the gunner art, in this order
## (1st man aboard first). New basket art: change these numbers (and the scale) only.
const BASKET := {
	"scale": 0.8,
	"riders": [Vector2(-14.5, -1.0), Vector2(14.5, -1.0), Vector2(-6.5, 0.0), Vector2(6.5, 0.0)],
}


## The pilot's frame of the basket strips (basket_<dir>, basket_front_<dir>): 0 holding the
## rim, 1-2 looking about, 3 pulling the rope while a keg comes up.
func _pilot_frame() -> int:
	if haul_t >= 0.0:
		return 3
	return [0, 0, 1, 0, 0, 2][int(_bob_t / 1.1) % 6]


func _basket_tex(layer: String, dir: String) -> Texture2D:
	var path := "res://assets/units/%s/%s_%s.png" % [kind, layer, dir]
	return Game.tex(path) if ResourceLoader.exists(path) else null


func _update_basket() -> void:
	if _front == null:
		return
	var info: Dictionary = ArtData.UNITS[kind]
	var dead_anim := anim == "death"
	_front.visible = not dead_anim
	if _pilot_spr:
		_pilot_spr.visible = not dead_anim
	for g in _pass_sprites:
		(g as Sprite2D).visible = false
	if dead_anim:
		return
	# the basket with its pilot, and its front wall over the riders' legs: on the body's cell
	var pf := _pilot_frame()
	var nb := int(info.get("basket_frames", 1))
	for pair in [[_pilot_spr, "basket"], [_front, "basket_front"]]:
		var s: Sprite2D = pair[0]
		if s == null:
			continue
		s.texture = _basket_tex(pair[1], anim_dir)
		s.hframes = nb
		s.frame = mini(pf, nb - 1)
		s.offset = sprite.offset
	var slots: Array = info.get("gunners", {}).get(anim_dir, [Vector2.ZERO, Vector2.ZERO])
	var mid: Vector2 = (Vector2(slots[0]) + Vector2(slots[slots.size() - 1])) * 0.5
	var sc := float(BASKET["scale"])
	var anchor := Vector2(info.get("gunner_anchor", Vector2.ZERO))
	var gfr: Dictionary = info.get("gunner_frames", {"idle": 1, "down": 3, "up": 3})
	# the men it carries; Musketeers shoot from there
	var riders: Array = BASKET["riders"]
	for i in mini(passengers.size(), _pass_sprites.size()):
		var p = passengers[i]
		if not is_instance_valid(p):
			continue
		var g: Sprite2D = _pass_sprites[i]
		var st: String = p.gun_state[0]
		g.visible = true
		g.texture = Game.tex("res://assets/units/%s/gunner_%s_%s.png" % [kind, st, anim_dir])
		g.hframes = int(gfr.get(st, 1))
		g.frame = clampi(int(float(p.gun_t[0]) / 0.7 * g.hframes), 0, g.hframes - 1) if st != "idle" else 0
		g.offset = -anchor
		g.scale = Vector2(sc, sc)
		g.position = sprite.offset + mid + Vector2(riders[mini(i, riders.size() - 1)])
		# the others (pikes, picks) are just along for the ride: a little darker
		g.self_modulate = Color.WHITE if p.kind == "musketeer" else Color(0.8, 0.8, 0.8)


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
	elif k == "mist_toad":
		charge = float(Defs.TOAD["start"])
	if Defs.is_worker(k) and d["faction"] == "clockwork":
		wind = randf_range(0.6, 1.0)     # (Winders don't all stop to wind at once)
	_pmax = max_powder()
	powder = _pmax
	auto_repair = k == "winder"      # (Winders always did; Labourers start with it off)
	armor = d["armor"]
	sight = d["sight"]
	radius = d["radius"]
	speed = d["speed"]
	position = pos
	last_pos = pos
	leash_from = pos
	art = k


func _ready() -> void:
	_sep_tick = get_instance_id() % 2 == 0
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.material = team_material()
	add_child(sprite)
	if kind == "cannon" and not ArtData.UNITS["cannon"]["frames"].has("walk_e"):
		_make_wheel()
	if kind == "balloon" and ArtData.UNITS.has(kind):
		# layered: the envelope and rigging, the basket with its pilot, the men it carries,
		# then the basket's front wall over their legs
		_pilot_spr = Sprite2D.new()
		_pilot_spr.centered = false
		_pilot_spr.use_parent_material = true
		sprite.add_child(_pilot_spr)
		for i in int(Defs.DROPSHIP["capacity"]):
			var ps := Sprite2D.new()
			ps.centered = false
			ps.use_parent_material = true
			ps.visible = false
			sprite.add_child(ps)
			_pass_sprites.append(ps)
		_front = Sprite2D.new()
		_front.centered = false
		_front.use_parent_material = true
		sprite.add_child(_front)
	if is_air():
		z_index = 3
	_set_anim("idle", true)


func rect() -> Rect2:
	return Rect2(global_position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


## Where the Tesla Cart's lightning starts: the sphere on its coil.
func coil_point() -> Vector2:
	var p: Vector2 = COIL_TOP.get(anim_dir, Vector2(0, -55))
	if anim_flip:
		p.x = -p.x
	return global_position + p * float(d.get("art_scale", 1.0))


func center() -> Vector2:
	# flyers are drawn hovering 20 px up: shots and zaps go to where they're seen
	return global_position + Vector2(0, -32 if is_air() else -12)


# ------------------------------------------------------------------ orders

func cmd_move(p: Vector2, attack_move := false) -> void:
	if aboard:
		return      # riding in a balloon
	if _ai_keeps_windup():
		return
	if braced:
		set_brace(false)     # a Bulwark lifts its shield to walk
	_reset_work()
	order = "amove" if attack_move else "move"
	order_point = p
	target = null
	order_target = null
	_request_path(p)


func cmd_attack(e: Entity) -> void:
	if aboard:
		return      # riding in a balloon
	if _ai_keeps_windup():
		return
	if braced and e.edge_distance(position) > _range() + radius:
		set_brace(false)     # out of the lance's reach: it lifts the shield and goes
	_reset_work()
	order = "attack"
	order_target = e
	target = e


## Units with two modes: moving (packed) and set up (deployed). The cannon limbers and
## unlimbers, the Tesla Cart packs and deploys, the Spore Mother uproots and roots.
func deploys() -> bool:
	return kind == "tesla_cart" or kind == "cannon" or kind == "spore_mother" or kind == "mortar"


func switch_time() -> float:
	match kind:
		"cannon":
			return Defs.CANNON_SWITCH
		"mortar":
			return Defs.MORTAR_SWITCH
		"spore_mother":
			return Defs.ROOT_SWITCH
	return Defs.TESLA_SWITCH


func cmd_deploy() -> void:
	if aboard:
		return      # riding in a balloon
	if not deploys() or tesla_mode != "packed":
		return
	cmd_stop()
	tesla_mode = "deploying"
	tesla_t = switch_time()
	if kind == "tesla_cart":
		Sfx.play("combat/tesla_deploy", position)


## Go to a spot and cast a spell there (Stormcaller: storm; Spore Mother: miasma).
func cmd_cast(spell: String, p: Vector2) -> void:
	if aboard:
		return      # riding in a balloon
	_reset_work()
	order = "cast"
	cast_spell = spell
	cast_at = p
	target = null
	order_target = null
	if position.distance_to(p) > _spell_range():
		_request_path(p)


func _spell_range() -> float:
	return float(Game.spell_info(cast_spell)["range"])


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
		phase_t = float(Game.spell_info(cast_spell)["cast"])
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


# ------------------------------------------------------------------ Mist Toad: TONGUE

## Can this Toad's tongue go for `e` at all? (One enemy ground unit, not a building or a
## flyer, nor one being bandaged or riding in a balloon.)
func can_tongue(e) -> bool:
	return e is Unit and is_instance_valid(e) and not e.dead and not e.off_field and e.aboard == null \
		and not e.is_air() and game.hostile(e.team, team) and e.is_inside_tree()


## Heavy units can't be pulled, only staggered: supply TONGUE.heavy and up, or tagged massive.
static func too_heavy(e: Unit) -> bool:
	return int(e.d["supply"]) >= int(Defs.TONGUE["heavy"]) or Defs.has_tag(e.kind, "massive")


## TONGUE: walk into range of `e`, then mark it (the windup) and drag it in.
func cmd_tongue(e: Unit) -> void:
	if aboard or kind != "mist_toad" or not can_tongue(e):
		return
	_reset_work()
	order = "tongue"
	order_target = e
	target = null
	if e.position.distance_to(position) > float(Defs.TONGUE["range"]):
		_request_path(e.position)


## The "tongue" order: get within range, then start the windup (it pays the energy).
func _tongue_order(delta: float) -> Vector2:
	if tongue_stage != "":
		return Vector2.ZERO
	var e = order_target
	if not can_tongue(e):
		cmd_stop()
		return Vector2.ZERO
	if charge < float(Defs.TONGUE["cost"]):
		if team == game.human:
			game.notify("Not enough energy: TONGUE needs %d." % int(Defs.TONGUE["cost"]))
		cmd_stop()
		return Vector2.ZERO
	var dist: float = (e as Unit).position.distance_to(position)
	if dist <= float(Defs.TONGUE["range"]):
		if stun_t > 0.0:
			return Vector2.ZERO
		path = PackedVector2Array()
		charge -= float(Defs.TONGUE["cost"])
		tongue_victim = e
		tongue_stage = "windup"
		tongue_t = float(Defs.TONGUE["windup"])
		_tongue_at = position
		velocity = Vector2.ZERO
		facing = ((e as Unit).position - position).normalized()
		game.tongue_marked(self, e)
		return Vector2.ZERO
	if (path.is_empty() or path_i >= path.size()) and not path_pending or repath_t <= 0.0:
		repath_t = 1.0
		_request_path((e as Unit).position)
	return _follow(delta)


## The windup, the lash and the pull, every tick (the pull goes on whatever the Toad is
## told meanwhile).
func _tongue_tick(delta: float) -> void:
	var e := tongue_victim
	match tongue_stage:
		"windup":
			var why := ""
			if not can_tongue(e):
				why = "gone"
			elif stun_t > 0.0:
				why = "stunned"
			elif position.distance_to(_tongue_at) > float(Defs.TONGUE["moved"]):
				why = "moved"
			elif e.position.distance_to(position) > float(Defs.TONGUE["range"]) * float(Defs.TONGUE["break"]):
				why = "out of reach"
			if why != "":
				_break_tongue(why)
				return
			facing = (e.position - position).normalized()
			tongue_t -= delta
			if tongue_t <= 0.0:
				tongue_stage = "lash"
				tongue_t = float(Defs.TONGUE["lash"])
				frame_i = 0
				anim_t = 0.0
				Sfx.play_any(["combat/brute_attack", "roar", "combat/spitter_attack", "acid"], position)
		"lash":
			if e == null or not is_instance_valid(e) or e.dead:
				_end_tongue()
				return
			tongue_t -= delta
			if tongue_t <= 0.0:
				game.tongue_hit(self, e)
				if too_heavy(e):
					e.stun_t = maxf(e.stun_t, float(Defs.TONGUE["stagger"]))
					e.phase = ""
					tongue_stage = "recoil"
					tongue_t = 0.15
				else:
					tongue_stage = "pull"
					tongue_t = float(Defs.TONGUE["pull"])
					_pull_from = e.position
					e.stun_t = maxf(e.stun_t, float(Defs.TONGUE["pull"]) + float(Defs.TONGUE["after"]))
					e.phase = ""
					e.target = null
					e.path = PackedVector2Array()
					e.velocity = Vector2.ZERO
					e.knock = Vector2.ZERO
		"recoil":
			tongue_t -= delta
			if tongue_t <= 0.0:
				_end_tongue()
		"pull":
			if e == null or not is_instance_valid(e) or e.dead:
				_end_tongue()
				return
			tongue_t -= delta
			var f := 1.0 - clampf(tongue_t / float(Defs.TONGUE["pull"]), 0.0, 1.0)
			f = 1.0 - (1.0 - f) * (1.0 - f)      # fast at first, easing in at the end
			var dir := (_pull_from - position).normalized()
			if dir == Vector2.ZERO:
				dir = facing
			var feet := position + dir * (radius + e.radius + 4.0)
			e.position = game.resolve_terrain(_pull_from.lerp(feet, f), e.position, e.radius, e.team)
			e.velocity = Vector2.ZERO
			if tongue_t <= 0.0:
				_end_tongue()


## The windup is over before the lash (its energy is lost): the mark goes.
func _break_tongue(why := "") -> void:
	if tongue_stage == "":
		return
	if tongue_stage == "windup" and why != "" and (team == game.human or (tongue_victim and is_instance_valid(tongue_victim) and tongue_victim.team == game.human)):
		game.float_text(position + Vector2(0, -44), "tongue broken", Color(0.85, 0.75, 0.8))
	if game.mlog and tongue_stage == "windup":
		game.mlog.add("%s's Mist Toad lost its mark (%s)" % [game.mlog.who(team), why if why != "" else "new order"])
	_end_tongue()


func _end_tongue() -> void:
	tongue_stage = ""
	tongue_t = 0.0
	tongue_victim = null
	game.tongues.erase(self)
	if order == "tongue":
		order = "idle"
		order_target = null
		leash_from = position


## Where the tongue comes out: the Toad's mouth, at the front of its head.
func mouth_point() -> Vector2:
	var side := 1.0 if facing.x >= 0.0 else -1.0
	var across := absf(facing.x)
	return global_position + Vector2(side * across * 35.0, -25.0 + (1.0 - across) * 10.0)


## AI orders (its army moving on) don't interrupt a Toad in the middle of its windup.
func _ai_keeps_windup() -> bool:
	return tongue_stage == "windup" and game.ais.any(func(a) -> bool: return a.team == team)


func cmd_pack() -> void:
	if deploys() and tesla_mode == "deployed":
		tesla_mode = "packing"
		tesla_t = switch_time()


func cmd_heal(e: Unit) -> void:
	if aboard:
		return      # riding in a balloon
	_reset_work()
	order = "heal"
	order_target = e
	target = null


## Missionary: go to a fallen soldier's body and raise him (the body is his to raise
## meanwhile: grubs leave it alone).
func cmd_revive(body: Unit) -> void:
	if aboard or not d.get("medic", false) or not game.can_revive(body, self):
		return
	_reset_work()
	order = "revive"
	_body = body
	body.reviver = self
	target = null
	order_target = null


func cmd_stop() -> void:
	_reset_work()
	order = "idle"
	target = null
	order_target = null
	path = PackedVector2Array()
	leash_from = position


func cmd_hold() -> void:
	if aboard:
		return      # riding in a balloon
	cmd_stop()
	order = "hold"


## Go and work at an economy structure (Farm, Powder Mill, Feeding Pit, Boiler).
func cmd_gather(site: Entity) -> void:
	if aboard:
		return      # riding in a balloon
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
		return e.is_building() or (e is Unit and Defs.CROWN_MACHINES.has(e.kind))
	return false


func cmd_repair(e: Entity) -> void:
	if aboard:
		return      # riding in a balloon
	if not can_repair(e):
		return
	_reset_work()
	order = "repair"
	order_target = e
	target = null


func cmd_build(site: Building) -> void:
	if aboard:
		return      # riding in a balloon
	if not is_worker():
		return
	# sent on to the site his crate is for: he keeps it on his back
	var keep := crate_site if crate_site == site else null
	if keep:
		crate_site = null
	_reset_work()
	crate_site = keep
	order = "build"
	order_target = site
	work = "to_site"
	target = null


# ------------------------------------------------------------------ Shift-queued orders

## The orders that end by themselves: Shift-queued orders wait behind them. Behind anything
## else (idle, hold, working at a post...) a queued order starts at once.
const QUEUE_BUSY := ["move", "amove", "attack", "build", "repair"]


## Give an order ({"o": move/amove/attack/build/repair/gather/wall, "p", "e", "pieces"}): a
## plain one now (it clears the queue), a queued one (Shift) after the orders before it.
func give(o: Dictionary, queued := false) -> void:
	if not queued:
		queue.clear()
		line_rest.clear()
		_start(o)
		return
	if queue.size() >= QUEUE_MAX:
		return
	queue.append(o)
	if not QUEUE_BUSY.has(order):
		_next_order()


## Start the next queued order that still makes sense (a dead target or a finished site is
## skipped). False if there was none left.
func _next_order() -> bool:
	while not queue.is_empty():
		var o: Dictionary = queue.pop_front()
		_keep_queue = true
		var ok := _start(o)
		_keep_queue = false
		if ok:
			if o["o"] == "gather":
				queue.clear()       # working at a post never ends: it's the last order
			return true
	return false


## The next piece of a queued wall. False when the wall is done.
func _continue_line() -> bool:
	while not line_rest.is_empty():
		var b = line_rest.pop_front()
		if _site_open(b):
			_keep_queue = true
			cmd_build(b)
			_keep_queue = false
			return true
	return false


## The site this builder was going to is gone (a ghost that couldn't start, or cancelled):
## on to the next Shift-queued order, or idle.
func site_gone() -> void:
	if crate_site and (not is_instance_valid(crate_site) or crate_site.dead):
		crate_site = null
	if not (_continue_line() or _next_order()):
		cmd_stop()


func _site_open(b) -> bool:
	return b is Building and is_instance_valid(b) and not b.dead and not b.built \
		and not (b.seeded and kind != "labourer")


## Start an order. A queued one (_keep_queue) is skipped when it no longer makes sense; a
## plain one is given as it always was.
func _start(o: Dictionary) -> bool:
	var e = o.get("e")
	var plain := not _keep_queue
	match String(o["o"]):
		"move", "amove":
			cmd_move(o["p"], o["o"] == "amove" and not is_worker())
		"attack":
			if e == null or not is_instance_valid(e) or not (plain or _valid_target(e)):
				return false
			cmd_attack(e)
		"build":
			if not (e is Building and is_instance_valid(e)) or not (plain or _site_open(e)):
				return false
			cmd_build(e)
		"wall":
			var pieces: Array = (o["pieces"] as Array).filter(func(b) -> bool: return _site_open(b))
			if pieces.is_empty():
				return false
			cmd_build(pieces[0])
			line_rest = pieces.slice(1)
		"repair":
			if e == null or not is_instance_valid(e) or not (plain or (not e.dead and can_repair(e))):
				return false
			cmd_repair(e)
		"gather":
			if e == null or not is_instance_valid(e) or not (plain or not e.dead):
				return false
			cmd_gather(e)
	return order != "idle"


static func _spot(e: Entity) -> Vector2:
	return e.global_position if e is Unit else e.center()


## Where this unit is going, in order: [kind, point] for its current order and everything
## queued behind it (for the waypoint lines drawn for your selection).
func plan_points() -> Array:
	var pts: Array = []
	if order == "move" or order == "amove":
		pts.append([order, order_point])
	elif (order == "attack" or order == "build" or order == "repair" or order == "gather") \
			and order_target and is_instance_valid(order_target) and not order_target.dead:
		pts.append([order, _spot(order_target)])
	for b in line_rest:
		if is_instance_valid(b) and not b.dead:
			pts.append(["build", b.center()])
	for o in queue:
		var e = o.get("e")
		match String(o["o"]):
			"move", "amove":
				pts.append([o["o"], o["p"]])
			"wall":
				for b in o["pieces"]:
					if is_instance_valid(b) and not b.dead:
						pts.append(["build", b.center()])
			_:
				if e != null and is_instance_valid(e) and not e.dead:
					pts.append([o["o"], _spot(e)])
	return pts


## Has a building to go to, now or queued (a grub can only become one).
func build_pending() -> bool:
	return order == "build" or line_rest.size() > 0 \
		or queue.any(func(o: Dictionary) -> bool: return o["o"] == "build" or o["o"] == "wall")


## Where this unit will be once its queue is done (Shift-queued group moves form up from there).
func plan_end() -> Vector2:
	if queue.is_empty() and line_rest.is_empty() and not QUEUE_BUSY.has(order):
		return position
	var pts := plan_points()
	return pts[pts.size() - 1][1] if not pts.is_empty() else position


func _reset_work() -> void:
	if not _keep_queue:
		queue.clear()          # a new order (not Shift-queued) replaces the queue
		line_rest.clear()
	if tongue_stage == "windup":
		_break_tongue()        # a new order: the Toad lets its mark go
	if _corpse and is_instance_valid(_corpse):
		_corpse.harvester = null
	_corpse = null
	_drop_body()
	_leave_mine()
	_release_patient()
	_cancel_boarding()
	_wind_target = null
	drop_crate()
	if sky == "to_land":
		sky = "air"
	if keg:
		# given another job on the way: the keg goes back into the stores
		keg = false
		game.add_res2(team, _keg_cost())
	_cancel_refit()            # (a refit called off: paid back)
	work = ""
	phase = ""
	path = PackedVector2Array()
	path_goal = Vector2.INF


# ------------------------------------------------------------------ balloon dropship

## Can this unit climb into that balloon?
func can_board(b: Unit) -> bool:
	return not dead and aboard == null and not off_field and b != null and is_instance_valid(b) and b.kind == "balloon" \
		and not b.dead and b.team == team and (Defs.DROPSHIP["kinds"] as Array).has(kind)


## (a balloon) free places in the basket, counting the men already walking over.
func room() -> int:
	incoming = incoming.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead and u.order == "board" and u.order_target == self)
	return int(Defs.DROPSHIP["capacity"]) - passengers.size() - incoming.size()


## Walk to the spot under the balloon and climb in.
func cmd_board(b: Unit) -> void:
	if not can_board(b):
		return
	_reset_work()
	order = "board"
	order_target = b
	target = null
	_board_t = 0.0
	repath_t = 0.0
	if not b.incoming.has(self):
		b.incoming.append(self)


func _board(delta: float) -> Vector2:
	var b := order_target as Unit
	if b == null or not is_instance_valid(b) or b.dead or b.passengers.size() >= int(Defs.DROPSHIP["capacity"]):
		cmd_stop()
		return Vector2.ZERO
	_board_t += delta
	if _board_t > float(Defs.DROPSHIP["give_up"]):
		if team == game.human:
			game.notify("They can't reach the balloon: it must hover over ground they can walk to.")
		cmd_stop()
		return Vector2.ZERO
	if position.distance_to(b.position) < float(Defs.DROPSHIP["board"]):
		b.take_aboard(self)
		return Vector2.ZERO
	if position.distance_to(b.position) < 90.0 and game.line_clear(position, b.position):
		path = PackedVector2Array()
		return (b.position - position).normalized() * speed
	if repath_t <= 0.0 or ((path.is_empty() or path_i >= path.size()) and not path_pending):
		repath_t = 1.5
		_request_path(b.position)
	return _follow(delta)


## (a balloon) a man climbs into the basket: off the field until he's let off.
func take_aboard(u: Unit) -> void:
	incoming.erase(u)
	if dead or u.dead or u.aboard != null or passengers.size() >= int(Defs.DROPSHIP["capacity"]):
		return
	u.cmd_stop()
	u.velocity = Vector2.ZERO
	u.aboard = self
	u.off_field = true
	u.visible = false
	u.selected = false
	u.target = null
	u.phase = ""
	game.selection.erase(u)
	u.position = position
	passengers.append(u)
	if team == game.human:
		Sfx.play_any(["ui/click", "click"], position)


## (a balloon) stop the men still walking over.
func _cancel_boarding() -> void:
	for u in incoming:
		if is_instance_valid(u) and not u.dead and u.order == "board" and u.order_target == self:
			u.order = "idle"
			u.order_target = null
			u.path = PackedVector2Array()
	incoming.clear()


## (a balloon) fly to a spot and let everyone off there (on the nearest open ground).
func cmd_unload(p: Vector2) -> void:
	if passengers.is_empty():
		return
	_reset_work()
	order = "unload"
	order_point = p
	target = null
	order_target = null
	if position.distance_to(p) > 8.0:
		_request_path(p)


func _unload(delta: float) -> Vector2:
	if passengers.is_empty():
		cmd_stop()
		return Vector2.ZERO
	if work == "dropping":
		work_t -= delta
		if work_t <= 0.0:
			drop_passengers(order_point)
			cmd_stop()
		return Vector2.ZERO
	if position.distance_to(order_point) < 10.0 or (_arrived() and position.distance_to(order_point) < 60.0) or path.is_empty() and not path_pending:
		path = PackedVector2Array()
		work = "dropping"
		work_t = 0.6
		return Vector2.ZERO
	return _follow(delta)


## Every man in the basket gets off onto open ground near `at`; a fall (the balloon shot
## down) costs each of them half his health.
func drop_passengers(at: Vector2, fall := false) -> void:
	var list := passengers.duplicate()
	passengers.clear()
	var spots := game.drop_spots(at, list.size(), team)
	var n := 0
	for i in list.size():
		var u = list[i]
		if not is_instance_valid(u) or u.dead:
			continue
		n += 1
		u.aboard = null
		u.off_field = false
		u.visible = game.sees_all() or game.allied(u.team, game.fog_team())
		u.position = spots[i] + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		u.last_pos = u.position
		u.velocity = Vector2.ZERO
		u.cmd_stop()
		u.facing = Vector2.DOWN
		var fx := game.spawn_effect("dust", u.position, 1.6)
		fx.scale = Vector2(0.4, 0.4)
		if fall:
			u.last_hit_by = last_hit_by
			u.last_hit_team = last_hit_team
			u.last_hitter = last_hitter
			u.flash = 0.12
			u.hp -= u.max_hp * float(Defs.DROPSHIP["fall"])
			if u.hp <= 0.0:
				u.hp = 0.0
				u.die()
	if n > 0 and team == game.human and not fall:
		Sfx.play_any(["ui/click", "click"], at)


# ------------------------------------------------------------------ skywing

func _sky_stats() -> void:
	if sky == "ground" or sky == "lifting":
		if _sky_ground.is_empty():
			_sky_ground = Defs.UNITS["skywing"].duplicate()
			_sky_ground.merge(Defs.SKYWING_LANDED, true)
		d = _sky_ground
	else:
		d = Defs.UNITS["skywing"]
	z_index = 3 if is_air() else 0
	speed = float(d["speed"])


## Skywing: come down (on the nearest open ground) and fight on foot.
func cmd_land() -> void:
	if kind != "skywing" or sky != "air":
		return
	_reset_work()
	order = "idle"
	target = null
	order_target = null
	leash_from = position
	if game._clear_at(position, radius, team):
		_start_switch("landing")
		return
	var c := game.nearest_free(game.cell_of(position), 8)
	_land_at = game.cell_center(c)
	sky = "to_land"


func cmd_take_off() -> void:
	if kind != "skywing" or sky != "ground":
		return
	_reset_work()
	order = "idle"
	target = null
	order_target = null
	_start_switch("lifting")


func _start_switch(m: String) -> void:
	sky = m
	sky_t = Defs.SKYWING_SWITCH
	phase = ""
	target = null
	path = PackedVector2Array()
	frame_i = 0
	anim_t = 0.0
	_sky_stats()


## Landing or taking off (it can't do anything else meanwhile); returns where it wants to go.
func _sky_switch(delta: float) -> Vector2:
	if sky == "to_land":
		if position.distance_to(_land_at) < 4.0:
			position = _land_at
			_start_switch("landing")
			return Vector2.ZERO
		return (_land_at - position).normalized() * minf(speed, position.distance_to(_land_at) * 4.0 + 10.0)
	sky_t -= delta
	if sky_t <= 0.0:
		sky = "ground" if sky == "landing" else "air"
		_sky_stats()
		leash_from = position
		if sky == "ground" and not game._clear_at(position, radius, team):
			position = game.resolve_terrain(position, position, radius, team)
	return Vector2.ZERO


# ------------------------------------------------------------------ bloater gas

## Out of gas, a Bloater deflates (no spitting, no burst, slower) and fills up again.
func _bloater_gas(delta: float) -> void:
	match deflate:
		"":
			if mode != "hold" and gas < float(Defs.BLOAT["spit_cost"]):
				deflate = "deflating"
				deflate_t = float(Defs.DEFLATE["anim"])
				frame_i = 0
				anim_t = 0.0
				phase = ""
				target = null
				if order in ["attack", "amove", "hold"]:
					cmd_stop()
				if team == game.human:
					game.float_text(position + Vector2(0, -40), "out of gas", Color(0.75, 0.95, 0.25))
		"deflating", "refilling":
			deflate_t -= delta
			if deflate_t <= 0.0:
				deflate = "flat" if deflate == "deflating" else ""
				frame_i = 0
				anim_t = 0.0
		"flat":
			var rate := float(Defs.DEFLATE["refill"]) * (float(Defs.DEFLATE["swamp"]) if game.on_swamp(team, position) else 1.0)
			gas = minf(100.0, gas + rate * delta)
			speed *= float(Defs.DEFLATE["slow"])
			if gas >= 100.0:
				deflate = "refilling"
				deflate_t = float(Defs.DEFLATE["anim"])
				frame_i = 0
				anim_t = 0.0


# ------------------------------------------------------------------ ornithopter

func _is_construct(e) -> bool:
	return e is Unit and is_instance_valid(e) and not e.dead and not e.off_field and e.d["faction"] == "clockwork" and not e.is_worker()


## Ornithopter: dump its battery into a construct (overloaded for a while).
func cmd_overload(e: Unit) -> void:
	if kind != "ornithopter" or topter_bat == "" or not _is_construct(e) or e == self or e.team != team:
		return
	if aboard:
		return
	_reset_work()
	order = "overload"
	order_target = e
	target = null


func _overload(_delta: float) -> Vector2:
	var c = order_target
	if topter_bat == "" or not _is_construct(c) or c.team != team:
		cmd_stop()
		return Vector2.ZERO
	if position.distance_to(c.position) < float(Defs.OVERLOAD["reach"]) + c.radius:
		c.overclock(self)
		topter_bat = ""
		cmd_stop()
		return Vector2.ZERO
	return (c.position - position).normalized() * speed


## A construct takes an Ornithopter's battery: overloaded (faster, harder hitting, quicker
## to strike), fully wound; when it burns out it's left with little charge.
func overclock(by: Unit) -> void:
	overclock_t = float(Defs.OVERLOAD["time"])
	wind = 1.0
	stun_t = 0.0
	game.spawn_effect("zap_burst_y" if ArtData.EFFECTS.has("zap_burst_y") else "hit", center(), 1.2)
	Sfx.play_any(["combat/tesla_attack", "zap"], position)
	if team == game.human:
		game.float_text(position + Vector2(0, -44), "OVERLOAD!", Color(1, 0.9, 0.35))
	if game.mlog and by != null:
		game.mlog.add("%s overloaded a %s" % [game.mlog.who(team), d["name"]])


## Ornithopter on COURIER, with nothing to do: fetch a battery, or take one to a construct
## that's run down. True if it found a job.
func _courier_scan() -> bool:
	if topter_bat == "":
		var src := _battery_source()
		if src == null:
			return false
		_reset_work()
		order = "courier"
		order_target = src
		work = "to_bat"
		target = null
		return true
	var c := _wind_job()
	if c == null:
		return false
	_reset_work()
	order = "courier"
	_wind_target = c
	order_target = null
	work = "to_unit"
	target = null
	return true


## The nearest of our energy buildings with a full battery waiting.
func _battery_source() -> Building:
	var best: Building = null
	var bd := INF
	for b in game.buildings:
		if b.team != team or b.dead or not b.built or b.batteries <= 0:
			continue
		var dd: float = b.center().distance_to(position)
		if dd < bd:
			bd = dd
			best = b
	return best


## The construct that needs winding most: shut-down ones first, then the lowest charge
## (not in a field, and not one another Ornithopter is already flying to).
func _wind_job() -> Unit:
	var taken := {}
	for o in game.units:
		if o != self and o.kind == "ornithopter" and o.team == team and is_instance_valid(o._wind_target):
			taken[o._wind_target] = true
	var best: Unit = null
	var bs := INF
	for o in game.units:
		if o.team != team or not _is_construct(o) or taken.has(o):
			continue
		var down: bool = o.powered_down()
		if not down and (o.wind >= float(Defs.TOPTER["low"]) or o._in_field or o.overclock_t > 0.0):
			continue
		if o == self and not down and o.wind > 0.25:
			continue
		var s: float = o.wind * 1000.0 + o.position.distance_to(position) * 0.2 - (5000.0 if down else 0.0)
		if s < bs:
			bs = s
			best = o
	return best


func _courier(delta: float) -> Vector2:
	match work:
		"to_bat", "loading":
			var src := order_target as Building
			if src == null or not is_instance_valid(src) or src.dead or src.batteries <= 0 or topter_bat != "":
				cmd_stop()
				return Vector2.ZERO
			if work == "loading":
				work_t -= delta
				if work_t <= 0.0:
					src.batteries -= 1
					topter_bat = "blue" if game.blue_energy(team) else "yellow"
					cmd_stop()
					_courier_t = 0.0
				return Vector2.ZERO
			if src.edge_distance(position) < radius + 10.0:
				work = "loading"
				work_t = float(Defs.TOPTER["load"])
				path = PackedVector2Array()
				return Vector2.ZERO
			return (src.center() - position).normalized() * speed
		"to_unit", "winding":
			var c := _wind_target
			if topter_bat == "" or not _is_construct(c) or (not c.powered_down() and c.wind >= 0.95):
				cmd_stop()
				return Vector2.ZERO
			if c == self:
				work = "winding"
			if work == "winding":
				# it settles onto the construct and winds it up from the battery
				position = position.lerp(c.position, clampf(delta * 6.0, 0.0, 1.0))
				work_t -= delta
				if work_t <= 0.0:
					c.wind = 1.0
					topter_bat = ""
					game.spawn_effect("zap_spark_y" if ArtData.EFFECTS.has("zap_spark_y") else "hit", c.center(), 1.0)
					Sfx.play("ratchet", c.position)
					if team == game.human:
						game.float_text(c.position + Vector2(0, -40), "wound up", Color(1, 0.9, 0.35))
					cmd_stop()
					_courier_t = 0.0
				return Vector2.ZERO
			if position.distance_to(c.position) < float(Defs.TOPTER["reach"]) + c.radius * 0.5:
				work = "winding"
				work_t = float(Defs.TOPTER["wind"])
				return Vector2.ZERO
			return (c.position - position).normalized() * speed
	cmd_stop()
	return Vector2.ZERO


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
	spell_cd = maxf(spell_cd - delta, 0.0)
	if _pmax > 0.0:
		_powder_tick(delta)
	if kind == "cuirassier":
		# a gallop builds up to a charge; standing about loses it
		if velocity.length() > speed * 0.7:
			run_t += delta
		elif phase == "":
			run_t = maxf(run_t - delta * 3.0, 0.0)
	stun_t = maxf(stun_t - delta, 0.0)
	held_t = maxf(held_t - delta, 0.0)
	scan_t -= delta
	_wall_watch(delta)
	repath_t -= delta
	sky_cd = maxf(sky_cd - delta, 0.0)
	_courier_t -= delta
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
	if kind == "bloater":
		_bloater_gas(delta)
	if not game.zones.is_empty() or sight != int(d["sight"]):
		# a fog bank: inside it you see only a couple of tiles
		sight = int(Defs.FOG["sight"]) if game.in_fog(position) else int(d["sight"])
	if kind == "mist_toad":
		var fill := float(Defs.TOAD["fill"]) * (float(Defs.TOAD["swamp"]) if game.on_swamp(team, position) else 1.0)
		charge = minf(float(Defs.TOAD["max"]), charge + fill * delta)
		if tongue_stage != "":
			_tongue_tick(delta)
	if kind == "brute" and target and phase == "" and target.edge_distance(position) < 170.0:
		speed *= 1.6      # charge
		if not _charging:
			_charging = true
			Sfx.play_any(["combat/brute_attack", "roar"], position)
	elif kind == "brute":
		_charging = false
	if kind == "balloon":
		_basket_fire(delta)
		# the men in the basket ride along; it comes down low while they climb in or out
		for p in passengers:
			if is_instance_valid(p):
				p.position = position
		var low := room() < int(Defs.DROPSHIP["capacity"]) - passengers.size() or work == "dropping"
		_descend = move_toward(_descend, 1.0 if low else 0.0, delta * 1.5)
	if overclock_t > 0.0:
		overclock_t -= delta
		wind = 1.0
		speed *= float(Defs.OVERLOAD["speed"])
		_spark_t -= delta
		if _spark_t <= 0.0 and visible and game.view_rect.has_point(position):
			_spark_t = 0.35
			var fx := game.spawn_effect("zap_spark_y" if ArtData.EFFECTS.has("zap_spark_y") else "hit", center() + Vector2(randf_range(-radius, radius), randf_range(-14, 10)), 1.4)
			fx.scale = Vector2(0.7, 0.7)
		if overclock_t <= 0.0:
			overclock_t = 0.0
			wind = float(Defs.OVERLOAD["after"])     # burnt out
			if team == game.human:
				game.float_text(position + Vector2(0, -40), "burnt out", Color(0.7, 0.75, 0.85))
	if d["faction"] == "clockwork":
		_field_t -= delta
		if _field_t <= 0.0:
			_field_t = 0.4
			_in_field = game.in_field(team, position)
			_in_ovc = not is_worker() and game.in_overcharge(team, position)
		# overcharge: a while by a Boiler, in a Pylon's or a deployed Tesla Cart's field
		if _in_ovc:
			overcharge_t = minf(overcharge_t + delta, float(Defs.OVERCHARGE["time"]) + 1.0)
		else:
			overcharge_t = 0.0
		cranked_t = maxf(cranked_t - delta, 0.0)
		if _in_field:
			wind = minf(1.0, wind + 0.3 * delta)
			self_wind_t = 0.0
			if kind == "stormcaller":
				charge = minf(float(Defs.STORM["max"]), charge + float(Defs.STORM["fill"]) * delta)
		elif is_worker():
			# Winders wind themselves: when they run low they stop a few seconds to crank
			if self_wind_t > 0.0:
				self_wind_t -= delta
				if self_wind_t <= 0.0:
					wind = 1.0
			else:
				wind = maxf(0.0, wind - delta / float(Defs.WINDER_SELF["run"]))
				if wind <= float(Defs.WINDER_SELF["low"]) and phase == "":
					self_wind_t = float(Defs.WINDER_SELF["stop"])
		elif runs_on_spring():
			wind = maxf(0.0, wind - delta / float(Defs.SPRING["run"]))
		else:
			var drain := Defs.WIND_DECAY * game.wind_decay_mult(team) * float(d.get("wind_drain", 1.0))
			if kind == "thresher":
				drain += float(Defs.THRESHER["drain"]) * spin
			if braced:
				drain *= float(Defs.BRACE["drain"])
			wind = maxf(0.0, wind - drain * delta)
		if kind == "thresher":
			# the saws spin up while it keeps cutting, and down a second after it stops
			_spin_idle += delta
			if _spin_idle > float(Defs.THRESHER["reset"]):
				spin = maxf(0.0, spin - delta / 0.6)
		if not is_worker():
			speed *= lerpf(0.75, 1.0, wind)
		# out of charge: it shuts down where it stands, like a statue, until a field
		# reaches it or a Winder winds it up again
		if powered_down():
			stun_t = maxf(stun_t, 0.25)
			phase = ""
			target = null
		if d.has("regen") and hp < max_hp:
			hp = minf(max_hp, hp + float(d["regen"]) * delta)

	if kind == "skywing" and sky != "air" and sky != "ground":
		# landing or taking off: it can't do anything else meanwhile
		_move(_sky_switch(delta), delta)
		_animate(delta)
		return
	if kind == "musketeer":
		_pick_weapon(delta)
	if target and not _valid_target(target):
		target = null
		phase = ""
	if order == "idle" and not queue.is_empty():
		_next_order()
	match order:
		"idle":
			if d.get("medic", false) and scan_t <= 0.0:
				# the fallen first (a soldier back), then the wounded
				scan_t = 0.5
				var body := game.find_body(self, float(Defs.REVIVE["scan"]) * Defs.TILE)
				if body:
					cmd_revive(body)
				else:
					var pt := game.find_patient(self, 9 * Defs.TILE)
					if pt:
						cmd_heal(pt)
			# REPAIR autocast: an idle worker fixes what's damaged nearby (before going back to
			# work, when WORK is on too)
			if auto_repair and scan_t <= 0.0 and (kind == "winder" or kind == "labourer"):
				scan_t = 1.0
				var hurt := game.find_repair(self, float(Defs.AUTO_REPAIR) * Defs.TILE)
				if hurt and can_repair(hurt) and game.players[team]["gold"] >= 1:
					cmd_repair(hurt)
				elif auto_work:
					scan_t = 0.0      # nothing to fix: straight on to the WORK check below
			# an idle Winder carries a crate dropped close by on to its site
			if kind == "winder" and order == "idle" and scan_t <= 0.0 and not game.crates.is_empty():
				var cr := game.free_crate(team, position, float(Defs.CRATE["auto"]) * Defs.TILE)
				if cr:
					scan_t = 1.0
					cmd_build(cr.site)
					cr.claimed = self
			# WORK is on by default: an idle worker goes back to its post by itself
			if is_worker() and auto_work and order == "idle" and scan_t <= 0.0:
				scan_t = 1.5
				var post := game.free_site(team, position)
				if post:
					cmd_gather(post)
			# COURIER: an idle Ornithopter fetches batteries and winds up constructs
			if kind == "ornithopter" and courier and _courier_t <= 0.0 and order == "idle":
				_courier_t = 1.0
				if _courier_scan():
					return
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
			elif deploys() and tesla_mode == "deployed" and held_t > 0.0:
				# a set-up gun with only targets it mustn't fire on (its own men where the
				# shot lands) stays set up and waits for a clear shot, instead of limbering
				# up, walking on into the fight and setting up again (and again)
				want = Vector2.ZERO
			else:
				want = _follow(delta)
				if _arrived():
					_finish_move()
		"attack":
			if order_target == null or not _valid_target(order_target):
				if not _next_order():
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
		"revive":
			want = _revive(delta)
		"build":
			want = _build(delta)
		"cast":
			want = _cast(delta)
		"tongue":
			want = _tongue_order(delta)
		"harvest":
			want = _harvest(delta)
		"board":
			want = _board(delta)
		"unload":
			want = _unload(delta)
		"restock":
			want = _restock(delta)
		"courier":
			want = _courier(delta)
		"overload":
			want = _overload(delta)
		"keg":
			want = _keg_run(delta)
		"refit":
			want = _refit_run(delta)
		"sacrifice":
			want = _sacrifice(delta)
	if deploys():
		want = _tesla(want, delta)
	if kind == "balloon" and not incoming.is_empty():
		want = Vector2.ZERO        # holds still while men climb in
	if deflate == "deflating" or deflate == "refilling":
		want = Vector2.ZERO
	if self_wind_t > 0.0:
		want = Vector2.ZERO        # a Winder cranking its own spring
	if tongue_stage != "":
		want = Vector2.ZERO        # a Mist Toad sits still to aim, lash and pull
	if kind == "bulwark":
		brace_t = maxf(brace_t - delta, 0.0)
		_shield_t = maxf(_shield_t - delta, 0.0)
		if braced:
			want = Vector2.ZERO    # the shield is planted
	_move(want, delta)
	_animate(delta)
	if kind == "winder" and (crate_site or _crate_spr):
		_update_crate_spr()
	# redraw the shadow, ring and bars only when something on them changed
	var extra := 0
	if topter_bat != "":
		extra += 500000 + (int(_bob_t * 10.0) % 13) * 1000
	if overclock_t > 0.0:
		extra += int(overclock_t * 8.0) * 1000000
	if kind == "balloon":
		extra += passengers.size() * 100000 + (int(haul_t * 30.0) + 1) * 1000
	var key := Vector4i(int(selected) + (2 if carrying > 0 else 0) + (4 if cross_t > 0.0 else 0) + (8 if work == "feeding" else 0) + (16 if carry_empty else 0) + (32 if cocoon > 0 else 0) + kills * 64,
		int(hp) + int(gas) * 10000, int(wind * 40.0) + (int(carry_t * 4.0) * 100 if carrying > 0 else 0) if d["faction"] == "clockwork" else int(powder * 2.0) + (1000 if supplying else 0),
		int(max_hp) + extra + (int(reload_frac() * 16.0) + 17 * int(tesla_t * 4.0) + 850 * ["packed", "deploying", "deployed", "packing"].find(tesla_mode)) * 10000 if has_attack() else int(max_hp) + extra)
	if key != _draw_key:
		_draw_key = key
		queue_redraw()
	elif selected and (kind == "cannon" or kind == "mortar") and team == game.human:
		# its line of fire on the ground follows the aim and the men around: ten times a second
		_aim_t -= delta
		if _aim_t <= 0.0:
			_aim_t = 0.1
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
	if not queue.is_empty():
		_next_order()


func _valid_target(e: Entity) -> bool:
	return is_instance_valid(e) and not e.dead and e.is_inside_tree() and game.hostile(e.team, team) and can_hit(e)


## How far this unit looks for targets: its sight, or for a cannon its full range (it
## can shoot what any friendly unit sees).
func _scan_range() -> float:
	if kind == "cannon" or kind == "mortar":
		return maxf(sight * Defs.TILE, _range())
	return sight * Defs.TILE


func _range() -> float:
	if kind == "bloater":
		# holding its gas, or about to pop anyway: it goes in to burst (out of gas it
		# deflates instead, and can't attack at all until it has filled up again)
		if mode == "hold" or hp < max_hp * 0.35:
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
	squeeze_t = 0.0
	# shut in a pocket between buildings (nothing that walks can get out): as a last resort
	# it squeezes out through the nearest building edge, then goes on its way
	if game.sealed_in(position) and game.region_of(game.cell_of(path_goal)) != game.region_of(game.cell_of(position)):
		var out := game.escape_point(position)
		if out != Vector2.INF:
			squeeze_t = 3.0
			path = PackedVector2Array([out]) + game.find_path(out, path_goal, not is_worker())


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
	if stun_t > 0.0 or braced or tongue_stage != "":
		v = Vector2.ZERO           # (a Mist Toad aiming its tongue squats: friends flow round it)
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
	elif squeeze_t > 0.0:
		# squeezing out of a sealed pocket: buildings don't stop it, terrain still does
		squeeze_t -= delta
		var sc: Vector2i = game.cell_of(position)
		if not game.in_map(sc) or game.solid[game.idx(sc)] == 1:
			position = before
		elif game.in_open_map(sc) and game._clear_at(position, radius, team):
			squeeze_t = 0.0
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


## Computer players: melee units hacking at a wall weigh it up rather than run at the first
## shot. Time to breach (the wall's hp over the hackers' damage, less any repair) against the
## time the shooters covering it need to kill them all: they push on while the breach comes
## clearly first, and pull back together when it doesn't.
func _wall_watch(delta: float) -> void:
	wall_flee_t = maxf(wall_flee_t - delta, 0.0)
	_wall_chk -= delta
	if _wall_chk > 0.0:
		return
	_wall_chk = 0.5
	if target == null or not is_instance_valid(target) or not (target is Building) \
			or not (target.kind == "wall" or target.kind == "gate") or float(d["range"]) > 40.0 or is_worker():
		return
	if not game.ais.any(func(a) -> bool: return a.team == team):
		return
	var wall: Building = target
	# the hackers: our melee units at this wall
	var hackers: Array = []
	for o in game.units_near(wall.center(), 140.0):
		if not o.dead and o.team == team and o.target == wall and float(o.d["range"]) <= 40.0:
			hackers.append(o)
	if hackers.is_empty():
		return
	# the shooters that can reach any of them
	var shooters := {}
	for h in hackers:
		for o in game.units_near(h.position, 320.0):
			if o.dead or not game.hostile(o.team, team) or float(o.d["range"]) < 100.0 or shooters.has(o):
				continue
			if o.edge_distance(h.position) <= float(o.d["range"]) + 10.0 and o.can_hit(h):
				shooters[o] = true
	if shooters.is_empty():
		return                       # only being repaired: keep draining them
	var hack_dps := 0.0
	var hack_hp := 0.0
	for h in hackers:
		hack_dps += maxf(1.0, float(h.d["damage"]) - wall.armor) / maxf(float(h.d["cooldown"]), 0.1)
		hack_hp += h.hp
	var shoot_dps := 0.0
	for o in shooters:
		shoot_dps += float(o.d["damage"]) / maxf(float(o.d["cooldown"]), 0.1)
	# repairers on the wall
	var rep := 0.0
	for o in game.units_near(wall.center(), 90.0):
		if not o.dead and game.hostile(o.team, team) and o.work == "repairing":
			rep += maxf(float(Defs.REPAIR_RATE), wall.max_hp / maxf(float(wall.d.get("time", 10.0)), 1.0))
	var net := hack_dps - rep
	var breach_t := wall.hp / net if net > 0.5 else INF
	var die_t := hack_hp / maxf(shoot_dps, 0.1)
	if breach_t < die_t * 0.6:
		return                       # we break through well before they shoot us down: push on
	var c := Vector2.ZERO
	for o in shooters:
		c += (o as Unit).position
	c /= shooters.size()
	for h in hackers:
		var away: Vector2 = (h.position - c).normalized()
		h.target = null
		h.cmd_move(h.position + away * 260.0, false)
		h.wall_flee_t = 25.0
		h._wall_chk = 0.5


## Move toward and fight a target. Returns the desired velocity.
func _engage(e: Entity, delta: float, may_move: bool) -> Vector2:
	if braced:
		may_move = false           # a planted Bulwark only pokes at what comes in reach
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
	if kind == "thresher" and stun_t <= 0.0:
		# in reach and cutting: the saws spin up
		spin = minf(1.0, spin + delta / float(Defs.THRESHER["time"]))
		_spin_idle = 0.0
	if braced:
		# the planted shield turns only slowly toward what it fights
		facing = facing.slerp((e.center() - center()).normalized(), clampf(delta * 2.0, 0.0, 1.0)).normalized()
	else:
		facing = (e.center() - center()).normalized()
	if phase == "":
		if cooldown > 0.0 or stun_t > 0.0:
			return
		# out of powder: a gun can't fire (a dry Musketeer has fixed bayonets instead)
		if _pmax > 0.0 and mode != "bayonet" and powder < 1.0:
			cooldown = 0.5
			if Time.get_ticks_msec() > _hold_note:
				_hold_note = Time.get_ticks_msec() + 5000
				game.out_of_powder(self)
			return
		# area attacks hurt friends too: hold fire on our own, unless ordered to shoot (canister
		# never holds: it's the gun's close-range answer, fired whoever is about)
		if order != "attack" and mode != "canister" and not game.aoe_worth_it(self, e):
			cooldown = 0.4
			held_t = 2.0
			if team == game.human and Time.get_ticks_msec() > _hold_note:
				_hold_note = Time.get_ticks_msec() + 5000
				game.float_text(position + Vector2(0, -40), "Holding fire: own men where it lands" if kind == "cannon" else "Holding fire: own men in the blast", Color(1, 0.85, 0.4))
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
	if overclock_t > 0.0:
		dmg *= float(Defs.OVERLOAD["damage"])
	elif overcharged():
		dmg *= float(Defs.OVERCHARGE["damage"])
	if kind == "thresher":
		dmg *= lerpf(float(Defs.THRESHER["low"]), float(Defs.THRESHER["high"]), spin)
	if e.is_building():
		dmg *= float(d.get("building_bonus", 1.0))
	if mode == "bayonet":
		var vet := 1.0 + minf(kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"]))
		e.take_damage(Defs.BAYONET["damage"] * vet * float(Defs.BAYONET["bonus"].get(e.kind, 1.0)), self)
		Sfx.play_any(["combat/pikeman_attack", "clash"], position)
		game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.6)
		return
	# every musket or cannon shot uses one of the shots it carries
	if _pmax > 0.0:
		if powder < 1.0:
			return    # no powder: the shot never goes off
		powder -= 1.0
		if powder < 1.0 and kind != "musketeer":
			game.out_of_powder(self)     # that was the last one (a Musketeer says so as it fixes bayonets)
	# a Mist Toad's fog bank: shots fired from inside it or into it miss half the time. Guns
	# aimed at a spot (round shot, shells, spit blobs) land wide; the others fly off into the murk.
	var wide := Vector2.ZERO
	if mode != "bayonet" and _range() >= 100.0 and game.fog_blinds(self, e) and randf() < float(Defs.FOG["miss"]):
		if (kind == "cannon" and mode != "canister") or kind == "mortar" or kind == "spore_mother":
			wide = Vector2.from_angle(randf() * TAU) * randf_range(55.0, 95.0)
			game.fog_miss_note(e)
		else:
			game.fog_miss(self, e)
			return
	match kind:
		"musketeer":
			game.musket_shot(self, e, dmg)
		"cannon":
			if mode == "canister":
				game.canister_shot(self, e, Defs.CANISTER["damage"])
			else:
				game.cannon_shot(self, e.center() + wide, dmg)
		"mortar":
			game.mortar_shot(self, (e.position if e is Unit else e.center()) + wide, dmg)
		"tesla_cart":
			game.tesla_zap(self, e, dmg)
		"spitter":
			game.acid_shot(self, e, dmg)
		"spore_mother":
			game.blob_shot(self, e.center() + Vector2(0, 12) + wide, dmg)
		"skywing":
			if sky == "air":
				# a volley of spines at a flyer (a braced Bulwark catches them for the men behind it)
				e = game.intercept(self, e)
				e.take_damage(dmg, self)
				var s := Shot.new()
				s.scale = Vector2(0.5, 0.6)
				s.impact = "hit"
				s.impact_scale = 0.6
				s.launch(game, "bolt" if ArtData.EFFECTS.has("bolt") else "acid_ball", center() + facing * 10.0, e.center(), 700.0)
			else:
				e.take_damage(dmg, self)
				game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.6)
			Sfx.play_any(["combat/skywing_attack", "bite"], position)
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
		"arc_thrower":
			# a ball of lightning: every throw takes a bite of its own wind
			game.arc_shot(self, e, dmg)
			if not _in_field and overclock_t <= 0.0:
				wind = maxf(0.0, wind - float(Defs.ARC["drain"]))
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
			if kind == "thresher":
				# the saws bite the enemies standing round its target too
				var n := 0
				for o in game.units_near(e.global_position, float(Defs.THRESHER["reach"]) + 10.0):
					if n >= int(Defs.THRESHER["cleave"]) or o == e or o.dead or o.off_field or o.is_air() or not game.hostile(o.team, team):
						continue
					o.take_damage(dmg * float(Defs.THRESHER["cleave_dmg"]), self)
					n += 1
			if charged and e is Unit and not e.dead and not e.is_air():
				var heavy: float = 0.4 if int(e.d["supply"]) >= 3 else 1.0
				e.knock = (e.position - position).normalized() * float(Defs.CHARGE["force"]) * heavy
				e.stun_t = float(Defs.CHARGE["stun"]) * heavy
				e.phase = ""
				game.spawn_effect("dust", e.position, 1.4).scale = Vector2(0.6, 0.6)
			Sfx.play_any(["combat/%s_attack" % kind, {"raptor": "bite", "brute": "bite", "grub": "bite", "thresher": "gear_hit", "bulwark": "gear_hit", "windup_soldier": "clash", "winder": "gear_hit"}.get(kind, "clash")], position)
			game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.6)
			if kind == "brute" and e is Unit and not e.dead:
				var push: Vector2 = (e.position - position).normalized() * 26.0
				e.position = game.resolve_terrain(e.position + push, e.position, e.radius, e.team)


# ------------------------------------------------------------------ workers

func _repair(delta: float) -> Vector2:
	var e := order_target
	if e == null or not is_instance_valid(e) or e.dead or e.team != team \
			or (e.hp >= e.max_hp and not (e is Unit and (e as Unit).wind < 0.98)) or (e is Building and not e.built):
		# done: the next Shift-queued order, or else the next damaged piece close by (a wall
		# is many pieces)
		if _next_order():
			return Vector2.ZERO
		var next: Entity = null
		if e is Building and is_instance_valid(e):
			next = game.repair_target_near((e as Building).center(), team, e)
		if next and next is Building and can_repair(next):
			cmd_repair(next)
			return Vector2.ZERO
		cmd_stop()
		return Vector2.ZERO
	if e.edge_distance(position) < radius + 20.0:
		work = "repairing"
		path = PackedVector2Array()
		facing = (e.center() - position).normalized()
		# like StarCraft: a full repair takes about as long as building it (never slower than
		# REPAIR_RATE hp/s) and costs a quarter of its price
		var bt: float = maxf(1.0, float(e.d.get("time", 30.0)))
		var rate := maxf(Defs.REPAIR_RATE, e.max_hp / bt)
		var heal := minf(rate * delta, e.max_hp - e.hp)
		var cost := heal * float(e.d.get("cost", 0)) * Defs.REPAIR_COST / maxf(e.max_hp, 1.0)
		if game.players[team]["gold"] < 1:
			if team == game.human:
				game.notify("Not enough ore to repair.")
			if not _next_order():
				cmd_stop()
			return Vector2.ZERO
		game.players[team]["gold_f"] = float(game.players[team].get("gold_f", 0.0)) - cost
		while float(game.players[team]["gold_f"]) <= -1.0:
			game.players[team]["gold_f"] = float(game.players[team]["gold_f"]) + 1.0
			game.players[team]["gold"] -= 1
		e.hp = minf(e.max_hp, e.hp + heal)
		if e is Unit:
			var eu := e as Unit
			if eu.runs_on_spring():
				# a Wind-up Soldier: the Winder cranks its key (it plays its wind-up)
				eu.wind = minf(1.0, eu.wind + float(Defs.SPRING["crank"]) * delta)
				eu.cranked_t = 0.3
			else:
				eu.wind = minf(1.0, eu.wind + 0.15 * delta)     # and winds it up
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
	if work == "manning" and auto_repair and _fix_nearby(delta):
		return Vector2.ZERO
	if kind == "labourer" and site.kind == "farm":
		return _farm(site, delta)
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


## REPAIR autocast at work: now and then a worker at its post looks round for a damaged
## building close by and goes to fix it (then WORK brings it back). True if it went.
var _fix_t := 0.0


func _fix_nearby(delta: float) -> bool:
	_fix_t -= delta
	if _fix_t > 0.0:
		return false
	_fix_t = 2.0
	var hurt := game.find_repair(self, 5.0 * Defs.TILE)
	if hurt and can_repair(hurt) and game.players[team]["gold"] >= 1:
		cmd_repair(hurt)
		return true
	return false


## Farm hands work in the fields, each on its own stretch of a crop row (Building.field_row):
## they walk in, hoe a while, step along the row and hoe again, turning at the end.
var _row_goal := Vector2.INF
var _row_t := 0.0
var _row_dir := 1.0


func _farm(site: Building, delta: float) -> Vector2:
	var seg: Array = site.field_row(maxi(site.crew.find(self), 0))
	var a: Vector2 = seg[0]
	var b: Vector2 = seg[1]
	if work != "manning":
		work = "to_site"
		var goal: Vector2 = a if position.distance_to(a) < position.distance_to(b) else b
		var done := (path.is_empty() or path_i >= path.size()) and not path_pending
		if position.distance_to(goal) < 14.0 or (done and path_goal == goal and position.distance_to(goal) < 48.0):
			work = "manning"
			path = PackedVector2Array()
			_row_goal = goal
			_row_dir = 1.0 if goal == a else -1.0
			_row_t = randf_range(1.0, 2.5)
			return Vector2.ZERO
		if done and path_goal != goal:
			_request_path(goal)
		elif done:
			return (goal - position).normalized() * speed
		return _follow(delta)
	# a new stretch (the crew changed): walk over to it through the field
	if _row_goal == Vector2.INF or absf(_row_goal.y - a.y) > 1.0 or _row_goal.x < a.x - 1.0 or _row_goal.x > b.x + 1.0:
		_row_goal = a if position.distance_to(a) < position.distance_to(b) else b
		if site.crosses_house(position, _row_goal):
			work = "to_site"        # (the other side of the windmill: walk round it)
			return Vector2.ZERO
	if position.distance_to(_row_goal) > 3.0:
		return (_row_goal - position).normalized() * speed * 0.45
	# hoeing, facing along the row (a little toward the viewer)
	facing = Vector2(_row_dir, 0.35).normalized()
	_row_t -= delta
	if _row_t <= 0.0:
		_row_t = randf_range(2.0, 3.5)
		var nx := _row_goal.x + _row_dir * randf_range(10.0, 18.0)
		if nx > b.x or nx < a.x:
			_row_dir = -_row_dir
			nx = clampf(nx, a.x, b.x)
		_row_goal = Vector2(nx, a.y)
	return Vector2.ZERO


## Winder: take a full battery from an energy building and carry it to the nearest Ore
## Crusher. Its charge grows on the road; too long and it overloads.
var carry_t := 0.0
var carry_blue := false
var carry_empty := false        # bringing the spent battery back to the source
var crusher: Building = null    # the Ore Crusher the battery on its back is going to
var crate_site: Building = null # Winder: the site the crate on his back is for (Defs.CRATE)
var _crate_spr: Sprite2D = null


func _haul_battery(src: Building, delta: float) -> Vector2:
	match work:
		"loading":
			facing = (src.center() - position).normalized()
			work_t -= delta
			if work_t <= 0.0:
				if src.batteries > 0 and game.can_haul(team, src) and game.best_crusher(position, team) != null:
					src.batteries -= 1
					game.energy[team] = maxi(0, int(game.energy[team]) - 1)
					carrying = 1
					carry_t = 0.0
					carry_blue = game.blue_energy(team)
					crusher = null
					work = "to_crusher"
				else:
					work = "waiting"
			return Vector2.ZERO
		"to_crusher":
			carry_t += delta       # (the charge fades on the road: Defs.battery_charge)
			if crusher == null or not is_instance_valid(crusher) or crusher.dead:
				crusher = game.best_crusher(position, team)
				path = PackedVector2Array()
			var cr := crusher
			if cr == null:
				return Vector2.ZERO
			if cr.edge_distance(position) < radius + 17.0:
				# the charge becomes ore drawn from its Clocktower's ore (a quarter once that's spent)
				var value := game.draw_lode(cr, Defs.battery_charge(carry_blue, carry_t) * float(Defs.BATTERY["ore"]))
				game.add_gold_f(team, value)
				crusher = null
				if team == game.human:
					game.float_text(position + Vector2(0, -30), "+%d" % int(round(value)), Color(0.5, 0.8, 1.0) if carry_blue else Color(1, 0.9, 0.35))
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
			if src.batteries > 0 and game.can_haul(team, src):
				work = "loading"
				work_t = float(Defs.BATTERY["load"])
			return Vector2.ZERO
	work = "to_site"
	if src.edge_distance(position) < radius + 16.0:
		path = PackedVector2Array()
		carry_empty = false
		work = "loading" if src.batteries > 0 and game.can_haul(team, src) else "waiting"
		work_t = float(Defs.BATTERY["load"])
		return Vector2.ZERO
	if (path.is_empty() or path_i >= path.size()) and not path_pending:
		_request_path(game.approach_point(src, position))
	return _follow(delta)


## Brood creature on SACRIFICE: walk (fly) to the nearest Brood Pen and be offered up there
## for essence (Game.sacrifice). Grubs can't be: they're the workforce.
func can_sacrifice() -> bool:
	return Game.sacrifice_value(kind) > 0 and aboard == null and not off_field


func cmd_sacrifice() -> void:
	if not can_sacrifice():
		return
	_reset_work()
	order = "sacrifice"
	target = null
	order_target = game.nearest_of(position, team, "brood_pen")
	if order_target == null:
		if team == game.human:
			game.notify("No Brood Pen to offer them at.")
		cmd_stop()


func _sacrifice(delta: float) -> Vector2:
	var pen := order_target as Building
	if pen == null or not is_instance_valid(pen) or pen.dead:
		pen = game.nearest_of(position, team, "brood_pen")
		order_target = pen
		path = PackedVector2Array()
		if pen == null:
			cmd_stop()
			return Vector2.ZERO
	if deploys() and tesla_mode != "packed":
		if tesla_mode == "deployed":
			cmd_pack()
		return Vector2.ZERO
	var gap := pen.edge_distance(position)
	# (in a crowd at the Pen: close enough once the walk is done)
	if gap < radius + 20.0 or (gap < radius + 64.0 and not path_pending and path_i >= path.size()):
		game.sacrifice(self, pen)
		return Vector2.ZERO
	if (path.is_empty() or path_i >= path.size()) and not path_pending:
		_request_path(game.approach_point(pen, position))
	return _follow(delta)


## Grub on HARVEST: take the bodies of the fallen (friend or foe) near it, wrap each in a
## cocoon and carry it to the nearest Hive for essence; then come back to where it was.
var harvest_home := Vector2.ZERO
var _corpse: Unit = null


func cmd_harvest() -> void:
	if aboard:
		return      # riding in a balloon
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
			game.fallen.erase(_corpse)       # (wrapped up: no raising him now)
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
				load_f = game.pit_load(pit)
				carrying = maxi(1, int(round(load_f)))
				work = "to_hall"
				path = PackedVector2Array()
			return Vector2.ZERO
		"to_hall":
			var hive := game.nearest_hall(pit.center(), team)
			if hive == null:
				return Vector2.ZERO
			if hive.edge_distance(position) < radius + 17.0:
				if load_f > 0.0:
					game.add_gold_f(team, load_f)
				else:
					game.add_gold(team, carrying)     # (a load from an older save)
				if team == game.human and carrying > 0:
					game.float_text(position + Vector2(0, -26), "+%d" % carrying, Color(0.75, 1.0, 0.4))
					Sfx.play("work/grub_deliver", position, -6.0)
				carrying = 0
				load_f = 0.0
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


## Labourer on a keg run for a Powder Wagon with SUPPLY on: take a keg at the nearest Powder
## Mill (paid from the powder bank), carry it to the wagon, and again while it has room.
## (Step 3's keg mines will start from the same keg carry.)
func cmd_keg(wagon: Unit) -> void:
	if kind != "labourer":
		return
	_reset_work()
	order = "keg"
	order_target = wagon
	work = "to_mill"
	target = null


func _keg_cost() -> float:
	return float(Defs.WAGON["keg"]) / float(Defs.WAGON["per_powder"])


func _keg_run(delta: float) -> Vector2:
	var w := order_target as Unit
	if w == null or not is_instance_valid(w) or w.dead:
		cmd_stop()          # (a keg on his back goes back into the stores)
		return Vector2.ZERO
	var room := w.max_powder() - w.powder
	if keg:
		work = "to_wagon"
		if position.distance_to(w.position) < radius + w.radius + 16.0:
			keg = false
			w.powder = minf(w.max_powder(), w.powder + float(Defs.WAGON["keg"]))
			w._dispense_t = 0.8
			if team == game.human:
				game.float_text(position + Vector2(0, -30), "+%d shots" % int(Defs.WAGON["keg"]), Color(1, 0.85, 0.5))
			path = PackedVector2Array()
			work = "to_mill"
			if not w.supplying or w.max_powder() - w.powder < float(Defs.WAGON["keg"]):
				cmd_stop()
			return Vector2.ZERO
		# the wagon may be on the move: head straight for it when close, else path there
		if position.distance_to(w.position) < 140.0 and game.line_clear(position, w.position):
			path = PackedVector2Array()
			return (w.position - position).normalized() * speed
		if repath_t <= 0.0 or (path.is_empty() and not path_pending):
			repath_t = 1.5
			_request_path(w.position)
		return _follow(delta)
	if not w.supplying or room < float(Defs.WAGON["keg"]):
		cmd_stop()
		return Vector2.ZERO
	var mill := game.nearest_of(position, team, "powder_mill")
	if mill == null:
		cmd_stop()
		return Vector2.ZERO
	if mill.edge_distance(position) < radius + 18.0:
		path = PackedVector2Array()
		facing = (mill.center() - position).normalized()
		if work != "loading":
			work = "loading"
			work_t = float(Defs.WAGON["keg_load"])
		work_t -= delta
		if work_t <= 0.0:
			if float(game.players[team]["res2"]) >= _keg_cost():
				game.players[team]["res2"] = float(game.players[team]["res2"]) - _keg_cost()
				keg = true
				work = "to_wagon"
			else:
				work_t = 1.0      # wait for the mill to grind enough
		return Vector2.ZERO
	work = "to_mill"
	if (path.is_empty() or path_i >= path.size()) and not path_pending:
		_request_path(game.approach_point(mill, position))
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
		if p.kind == "cuirassier":
			# a horseman is tended where he stands: horse and rider stay in view
			position = p.position + Vector2(-14, 4)
		else:
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


## Missionary: walk to the body and raise the soldier (kneeling over him as for a bandage).
func _revive(delta: float) -> Vector2:
	var b := _body
	if not game.can_revive(b, self):
		_drop_body()
		cmd_stop()
		return Vector2.ZERO
	if work == "reviving":
		facing = (b.position - position).normalized() if b.position != position else facing
		work_t -= delta
		if work_t <= 0.0:
			_body = null
			work = ""
			b.revive()
			if team == game.human:
				game.float_text(b.position + Vector2(0, -34), "risen!", Color(1, 1, 0.85))
			cmd_stop()
		return Vector2.ZERO
	if position.distance_to(b.position) < radius + b.radius + 8.0:
		work = "reviving"
		work_t = float(Defs.REVIVE["time"])
		path = PackedVector2Array()
		Sfx.play("combat/missionary_heal", position)
		return Vector2.ZERO
	if position.distance_to(b.position) < 140.0 and game.line_clear(position, b.position):
		path = PackedVector2Array()
		return (b.position - position).normalized() * speed
	if repath_t <= 0.0 or (path.is_empty() and not path_pending):
		repath_t = 1.0
		_request_path(b.position)
	return _follow(delta)


## (a Missionary) let go of the body he was going to raise.
func _drop_body() -> void:
	if _body and is_instance_valid(_body) and _body.reviver == self:
		_body.reviver = null
	_body = null
	if work == "reviving":
		work = ""


func _release_patient() -> void:
	if _patient and is_instance_valid(_patient):
		_patient.off_field = false
		if not _patient.visible:
			_patient.position = position + Vector2(14, 4)
		_patient.visible = true
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
		# a queued wall's next piece, then the next Shift-queued order
		if _continue_line() or _next_order():
			return Vector2.ZERO
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
	if kind == "winder" and site.crate != "" and crate_site != site:
		return _fetch_crate(site, delta)
	if site.edge_distance(position) < radius + 17.0:
		path = PackedVector2Array()
		facing = (site.center() - position).normalized()
		if site.ghost:
			# the site is a ghost until it starts: its footprint must be clear first
			var st := game.try_start_site(site, self)
			if st <= 0:
				if st == 0:
					work = "waiting"
				return Vector2.ZERO
		if kind == "winder":
			if crate_site == site:
				# sets the crate down: it unfolds and assembles itself from here
				crate_site = null
				site.land_crate()
			else:
				# (no Clocktower to fetch a crate from) winds the frame up himself
				site.seeded = true
				site._update_sprite()
				Sfx.play("ratchet", position)
			if not (_continue_line() or _next_order()):
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


## Winder: the crate for `site` isn't on his back yet. Fetch it from the nearest Clocktower,
## or pick it up where it was dropped; somebody else carrying it: leave it to him.
func _fetch_crate(site: Building, delta: float) -> Vector2:
	if site.crate == "carried":
		var c := site.crate_carrier
		if c and is_instance_valid(c) and not c.dead and c != self and c.crate_site == site:
			if not (_continue_line() or _next_order()):
				cmd_stop()
			return Vector2.ZERO
		site.crate = "tower"         # (its carrier is gone without dropping it: fetch another)
		site.crate_carrier = null
	var src: Entity = null
	var reach := 0.0
	var pause := 0.0
	if site.crate == "ground":
		var cr := site.crate_obj
		if cr == null or not is_instance_valid(cr) or cr.dead:
			site.crate = "tower"
			site.crate_obj = null
			return Vector2.ZERO
		cr.claimed = self
		src = cr
		reach = radius + 10.0
		pause = float(Defs.CRATE["lift"])
	else:
		src = game.crate_tower(team, position, site)
		if src == null:
			site.crate = ""          # no Clocktower left: he starts it by hand (Game.place_building)
			return Vector2.ZERO
		reach = radius + 17.0
		pause = float(Defs.CRATE["pickup"])
	if work == "crate_pickup":
		facing = (src.center() - position).normalized() if src.center() != position else facing
		work_t -= delta
		if work_t <= 0.0:
			if site.crate == "ground":
				site.crate_obj.remove()
			site.crate = "carried"
			site.crate_carrier = self
			site.crate_obj = null
			crate_site = site
			Sfx.play("ratchet", position, -6.0)
			work = "to_site"
			path = PackedVector2Array()
		return Vector2.ZERO
	if src.edge_distance(position) < reach:
		path = PackedVector2Array()
		work = "crate_pickup"
		work_t = pause
		return Vector2.ZERO
	var goal := src.global_position if src is Crate else game.approach_point(src, position)
	var w := "to_crate" if src is Crate else "to_tower"
	if work != w or path_goal.distance_to(goal) > 24.0:
		work = w
		path = PackedVector2Array()
	if (path.is_empty() or path_i >= path.size()) and not path_pending:
		if src is Crate and position.distance_to(goal) < 140.0 and game.line_clear(position, goal):
			return (goal - position).normalized() * speed
		_request_path(goal)
	return _follow(delta)


## Winder: where the crate on his back sits for each view ([x, y from the feet, unflipped art
## (facing east), drawn behind the body]): behind him when he faces us, in front of him when
## he walks away. One picture for every view; it bobs with his steps.
const CRATE_BACK := {"s": [0, -25, true], "se": [-4, -25, true], "e": [-7, -24, true], "ne": [-4, -23, false], "n": [0, -23, false]}


func _update_crate_spr() -> void:
	if crate_site == null or dead:
		if _crate_spr:
			_crate_spr.visible = false
		return
	if _crate_spr == null:
		_crate_spr = Sprite2D.new()
		_crate_spr.texture = Game.tex("res://assets/effects/crate_carried.png")
		_crate_spr.use_parent_material = true
		sprite.add_child(_crate_spr)
	var e: Array = CRATE_BACK.get(anim_dir, [0, -24, true])
	var bob := -1.0 if anim == "walk" and sprite.frame % 2 == 1 else 0.0
	_crate_spr.visible = true
	_crate_spr.position = Vector2(float(e[0]), float(e[1]) + bob)
	_crate_spr.show_behind_parent = e[2]


## Winder: let go of the crate on his back (killed, or given another job on the way): it
## lies where he stood until another Winder carries it on.
func drop_crate() -> void:
	var s := crate_site
	crate_site = null
	if s and is_instance_valid(s) and not s.dead and not s.built and s.crate == "carried" and s.crate_carrier == self:
		game.drop_crate(s, position)
		if team == game.human and not dead:
			game.float_text(position + Vector2(0, -36), "crate dropped", Color(1, 0.85, 0.4))


# ------------------------------------------------------------------ death

func die() -> void:
	if dead:
		return
	dead = true
	selected = false
	velocity = Vector2.ZERO
	queue.clear()
	line_rest.clear()
	_leave_mine()
	_release_patient()
	_drop_body()
	_cancel_boarding()
	_cancel_refit()            # (killed on the way to a refit: the fee goes back)
	drop_crate()               # (a Winder) the crate on his back falls where he stood
	if tongue_stage != "":
		_break_tongue("killed")    # (a Mist Toad) the mark goes, or the tongue lets go
	if _crate_spr:
		_crate_spr.visible = false
	# fallen under the cross (just raised, or just bandaged): gone for good
	final_death = cross_t > 0.0
	died_at = game.clock
	reviver = null
	if not passengers.is_empty():
		drop_passengers(position, true)     # shot down: the men in the basket fall out
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
	Sfx.play_any(["combat/%s_death" % kind, "combat/%s_death" % Sfx.SHORT.get(d["faction"], "crown"), "death_" + Sfx.SHORT.get(d["faction"], "crown")], position)
	_set_anim(_death_anim(), true)
	z_index = -1
	# powder goes up: a keg on a labourer's back, or a whole Powder Wagon
	if keg:
		keg = false
		game.powder_blast(self, position, float(Defs.KEG["blast"]), float(Defs.KEG["radius"]))
	elif kind == "powder_wagon":
		var full := clampf(powder / maxf(_pmax, 1.0), 0.0, 1.0)
		var dmg := maxf(float(Defs.WAGON["blast"]) * full, float(Defs.WAGON["blast_min"]))
		if game.mlog:
			game.mlog.add("%s's Powder Wagon exploded (%d shots aboard)" % [game.mlog.who(team), int(powder)])
		if team == game.human:
			game.notify("Your Powder Wagon blew up!", true)
		powder = 0.0
		game.powder_blast(self, position, dmg, float(Defs.WAGON["radius"]) * (0.85 + 0.15 * full), true)


# ------------------------------------------------------------------ animation

## This unit's sheet has an animation `a` (in any direction)? Else use `fallback`: new art
## (a landed Skywing, a deflated Bloater) may not be in yet.
func _anim_or(a: String, fallback: String) -> String:
	var frames: Dictionary = ArtData.UNITS[art]["frames"]
	for dr in ["s", "se", "e", "ne", "n"]:
		if frames.has(a + "_" + dr):
			return a
	return fallback


func _death_anim() -> String:
	if kind == "grub" and cocoon > 0 and ArtData.UNITS["grub"]["frames"].has("death_cocoon_e"):
		return "death_cocoon"
	if kind == "skywing" and sky != "air" and sky != "to_land":
		return _anim_or("gdeath", "death")
	if kind == "bloater" and deflate != "":
		return _anim_or("ddeath", "death")
	if keg and ArtData.UNITS[art]["frames"].has("death_keg_e"):
		return "death_keg"
	return "death"


func _anim_name() -> String:
	if dead:
		return _death_anim()
	var moving := velocity.length() > 10.0
	match kind:
		"musketeer":
			if mode == "bayonet":
				# the bayonet thrust
				if phase != "":
					return _anim_or("melee", "aim")
				return "walk" if moving else "idle"
			var up := target != null and is_instance_valid(target) and target.is_air()
			if phase == "aim":
				return "aimup" if up else "aim"
			if phase == "strike":
				return "fireup" if up else "fire"
			if cooldown > 0.0 and not moving and target:
				return "reload"
		"mortar":
			if tesla_mode == "deploying" or tesla_mode == "packing":
				return "deploy"
			if tesla_mode == "packed":
				return "walk" if moving else _anim_or("idle_packed", "idle")
			if phase != "":
				return "fire"
			if cooldown > 0.0 and target:
				return "reload"
			return "idle"
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
		"powder_wagon":
			if _dispense_t > 0.0 and not moving:
				return "unload"
		"labourer":
			if keg:
				return "carry_keg" if moving else "idle_keg"
			if work == "loading":
				return "build"
			if work == "manning":
				var site := home_mine as Building
				if site and site.kind == "farm":
					return "walk" if moving else "mine"
				return "build"
			if work == "mining" or phase != "":
				return "mine"
			if work == "building" or work == "repairing":
				return "build"           # (repairing: the same hammering as building)
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
		"thresher":
			if powered_down():
				return "drained"
			if phase != "":
				return "spinup" if spin < 0.35 else "attack"
		"arc_thrower":
			if powered_down():
				return "drained"
			if phase != "":
				return "attack"
		"bulwark":
			if braced or brace_t > 0.0:
				if _shield_t > 0.0 and braced:
					return "braced_hit"
				if phase == "strike":
					return "attack"
				return "brace"
			if phase != "":
				return "attack"
		"windup_soldier":
			if powered_down():
				return "rundown"
			if cranked_t > 0.0:
				return "windup"
			if phase != "":
				return "attack"
		"winder":
			if self_wind_t > 0.0:
				return "wind"
			if work == "manning":
				return "wind"
			if work == "repairing":
				return "repair"
			if phase != "":
				return "attack"
			if not moving and not _in_field:
				return "wind"
		"steam_walker":
			if phase != "":
				return "attack"
			if not moving and cooldown > 0.0 and target:
				return "vent"
		"missionary":
			if work == "bandaging" or work == "reviving":
				return "bandage"
		"skywing":
			if sky == "landing" or sky == "lifting":
				return _anim_or("land", "idle")
			if sky == "ground":
				if phase != "":
					return _anim_or("gattack", "attack")
				return _anim_or("gwalk", "walk") if moving else _anim_or("gidle", "idle")
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
		"mist_toad":
			if tongue_stage == "lash" or tongue_stage == "pull" or tongue_stage == "recoil":
				return _anim_or("tongue", "attack")
			if tongue_stage == "windup":
				return "idle"           # it squats and stares (the crosshair shows the mark)
			if phase == "cast":
				return _anim_or("fog", "idle")
			if phase != "":
				return _anim_or("attack", "tongue")   # the weak lick
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
		"bloater":
			match deflate:
				"deflating":
					return _anim_or("deflate", "idle")
				"refilling":
					return _anim_or("refill", "idle")
				"flat":
					return _anim_or("dwalk", "walk" if moving else "idle")
			if phase != "":
				return "attack"
		"ornithopter":
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
		# the new constructs slump (drained / run down) first, then stand still
		var dn := _anim_name()
		if (dn == "drained" or dn == "rundown") and not _cold:
			_set_anim(dn, false)
			var nd: int = ArtData.UNITS[kind]["frames"].get(anim + "_" + anim_dir, 1)
			anim_t += delta * 6.0
			if anim_t >= 1.0:
				anim_t -= 1.0
				frame_i += 1
			sprite.frame = clampi(mini(frame_i, nd - 1), 0, sprite.hframes - 1)
			if frame_i < nd - 1:
				return
		(sprite.material as ShaderMaterial).set_shader_parameter("tint", Vector3(0.5, 0.52, 0.6))   # a cold statue: no frames move
		_cold = true
		return
	elif _cold:
		_cold = false
		(sprite.material as ShaderMaterial).set_shader_parameter("tint", Vector3.ONE)
	if overclock_t > 0.0 and not dead:
		# overloaded: it glows hot, flickering
		var g := 1.25 + 0.15 * sin(_bob_t * 18.0)
		(sprite.material as ShaderMaterial).set_shader_parameter("tint", Vector3(g, g * 0.95, 0.85))
		_hot = true
	elif overcharged() and not dead:
		# overcharged (a while by a Boiler or in a Pylon's / Tesla Cart's field): a softer glow
		var g2 := 1.1 + 0.06 * sin(_bob_t * 9.0)
		(sprite.material as ShaderMaterial).set_shader_parameter("tint", Vector3(g2, g2 * 0.97, 0.9))
		_hot = true
	elif _hot:
		_hot = false
		(sprite.material as ShaderMaterial).set_shader_parameter("tint", Vector3.ONE)
	_set_anim(_anim_name(), false)
	var key := anim + "_" + anim_dir
	var n: int = ArtData.UNITS[art]["frames"].get(key, 1)
	var fps := WALK_FPS * clampf(velocity.length() / maxf(speed, 1.0), 0.6, 1.3)
	var loop := true
	match anim:
		"idle":
			fps = 2.0
		"death", "death_cocoon", "gdeath", "ddeath", "death_keg":
			fps = 7.0
			loop = false
		"gidle":
			fps = 3.0
		"gattack":
			fps = 9.0
			loop = false
		"land":
			fps = float(n) / Defs.SKYWING_SWITCH
			loop = false
		"deflate", "refill":
			fps = float(n) / float(Defs.DEFLATE["anim"])
			loop = false
		"idle_keg":
			fps = 3.0
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
			fps = float(n) / maxf(_cooldown() * 0.8, 0.5)
			if kind == "cannon" or kind == "mortar":
				loop = false        # the crew loads once, then stands ready on the last frame
		"deploy":
			fps = float(n) / switch_time()
			loop = false
		"brace":
			fps = float(n) / float(Defs.BRACE["switch"])
			loop = false
		"spinup", "windup":
			fps = 10.0
		"braced_hit":
			fps = 10.0
			loop = false
		"deployed":
			fps = 6.0 if kind != "spore_mother" else 3.0
		"cast", "fog":
			fps = float(n) / maxf(phase_t + 0.05, 0.3) if phase == "cast" else 8.0
			loop = false
		"tongue":
			fps = 14.0
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
	if anim == "brace" and not braced:
		shown = n - 1 - frame_i         # lifting the shield plays the brace backwards
	if anim == "land" and sky == "lifting":
		shown = n - 1 - frame_i         # taking off plays the landing backwards
	if kind == "mist_toad" and anim == "tongue" and tongue_stage != "":
		shown = mini(shown, TOAD_MOUTH_OPEN)   # the mouth gapes; the drawn tongue does the reaching
	sprite.frame = clampi(shown, 0, sprite.hframes - 1)
	if _front:
		_update_basket()
	_bob_t += delta
	if kind == "skywing" and (sky == "landing" or sky == "lifting") and not dead:
		# coming down to (or rising from) the ground
		var f := clampf(sky_t / Defs.SKYWING_SWITCH, 0.0, 1.0)
		sprite.position.y = -20.0 * (f if sky == "landing" else 1.0 - f)
	elif is_air():
		# flyers hover above their shadow and drop to the ground when they die
		sprite.position.y = lerpf(sprite.position.y, 0.0, delta * 3.0) if dead else -20.0 + sin(_bob_t * 4.0) * 2.5
		if kind == "balloon" and not dead:
			sprite.position.y += _descend * 14.0     # down low to take men on or let them off
	elif anim == "bandage":
		sprite.position.y = -absf(sin(_bob_t * 5.0)) * 1.0
	elif kind != "cannon":
		sprite.position.y = 0.0
	# Grubs at the pit: gnaw in a loop on the last frames of the burrow.
	if kind == "grub" and anim == "burrow" and n > 3:
		sprite.frame = clampi(2 + int(_bob_t * 6.0) % (n - 2), 0, sprite.hframes - 1)
	sprite.scale.y = float(d.get("art_scale", 1.0))
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
	var frames: Dictionary = ArtData.UNITS[art]["frames"]
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
	sprite.texture = Game.tex("res://assets/units/%s/%s.png" % [art, key])
	sprite.hframes = frames.get(key, 1)
	var anchor: Vector2 = ArtData.UNITS[art]["anchor"]
	# some sheets (aiming up) have extra room on top: the feet stay where they were
	var cell: Vector2i = ArtData.UNITS[art]["cell"]
	sprite.offset = -anchor - Vector2(0, sprite.texture.get_height() - cell.y)
	sprite.scale = Vector2(-1.0 if flip else 1.0, 1.0) * float(d.get("art_scale", 1.0))
	frame_i = mini(frame_i, sprite.hframes - 1)


var _aim_t := 0.0


## Where a selected gun of the player's is aiming: at its target, else where it faces; on a
## computer, while an ATTACK order is being given, at the mouse.
func _aim_dir() -> Vector2:
	var c = game.controls
	if c and c.get("mode") == "attack" and not game.demo:
		var m := get_global_mouse_position()
		if m.distance_to(global_position) > 8.0:
			return (m - global_position).normalized()
	if target and is_instance_valid(target) and not target.dead:
		return (target.center() - center()).normalized()
	return facing.normalized() if facing != Vector2.ZERO else Vector2.RIGHT


## A selected Cannon's line of fire on the ground (round shot: the band the ball ploughs
## along, out to full range; canister: its cone), red where it crosses your own or allied men,
## who'd be hit too. Faint while limbered. A selected Mortar: its least and greatest range,
## and the blast at its target.
func _draw_aim() -> void:
	var gold := Color(1.0, 0.9, 0.55)
	var red := Color(1.0, 0.25, 0.2)
	var a := 0.25 if tesla_mode in ["deployed", "deploying"] else 0.1
	if kind == "mortar":
		var lo := float(d["min_range"]) + radius
		var hi := float(d["range"]) + radius
		draw_arc(Vector2.ZERO, hi, 0.0, TAU, 96, Color(gold.r, gold.g, gold.b, a + 0.1), 1.5)
		draw_arc(Vector2.ZERO, lo, 0.0, TAU, 64, Color(red.r, red.g, red.b, a), 1.0)
		if target and is_instance_valid(target) and not target.dead:
			var at: Vector2 = (target.position if target is Unit else target.center()) - global_position
			var sp := float(d["splash"])
			draw_circle(at, sp, Color(red.r, red.g, red.b, 0.12))
			draw_arc(at, sp, 0.0, TAU, 32, Color(red.r, red.g, red.b, 0.5), 1.5)
		return
	var dir := _aim_dir()
	var from := center() + dir * 28.0 - global_position
	var friends: Array = []
	if mode == "canister":
		var reach := float(Defs.CANISTER["range"]) + 30.0
		var half := acos(float(Defs.CANISTER["cone"]))
		var pts := PackedVector2Array([from])
		for i in 13:
			pts.append(from + dir.rotated(lerpf(-half, half, i / 12.0)) * reach)
		draw_colored_polygon(pts, Color(gold.r, gold.g, gold.b, a * 0.5))
		pts.append(from)
		draw_polyline(pts, Color(gold.r, gold.g, gold.b, a + 0.15), 1.0)
		for o in game.units_near(global_position + from, reach + 20.0):
			if o == self or o.dead or o.off_field or game.hostile(o.team, team):
				continue
			var to: Vector2 = o.center() - (global_position + from)
			if to.length() <= reach + o.radius and dir.dot(to.normalized()) > float(Defs.CANISTER["cone"]):
				friends.append(o)
		for o in friends:
			var p: Vector2 = o.position - global_position
			draw_set_transform(p, 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, o.radius + 4.0, Color(red.r, red.g, red.b, 0.45))
			draw_set_transform(Vector2.ZERO)
		return
	# round shot: the ball flies over everything to where it's aimed, lands, and ploughs on
	# through a line of men (Game.round_shot_land). A faint line for its flight out to full
	# range; the stretch it ploughs (30 px short of the aim to ROUND_SHOT.line past it) as a
	# band, red over our own men in it: the same stretch the gun checks before it fires
	# (Game.aoe_worth_it). Men under the flight are safe.
	var w := float(Defs.ROUND_SHOT["width"])
	var length := float(d["range"]) + radius
	var g0 := Vector2(0, 0) + dir * 28.0           # on the ground, under the muzzle
	var g1 := dir * length
	draw_line(g0, g1, Color(gold.r, gold.g, gold.b, a * 0.8), 1.0)
	var aim := Vector2.INF                          # where the ball would land (local)
	var c = game.controls
	if c and c.get("mode") == "attack" and not game.demo and get_global_mouse_position().distance_to(global_position) <= length:
		aim = get_global_mouse_position() - global_position
	elif target and is_instance_valid(target) and not target.dead:
		aim = target.center() - global_position
	if aim == Vector2.INF:
		return
	var gd := (aim - (center() - global_position)).normalized()
	var s0 := aim - gd * 30.0
	var s1 := aim + gd * float(Defs.ROUND_SHOT["line"])
	var n := gd.orthogonal() * w
	draw_colored_polygon(PackedVector2Array([s0 + n, s1 + n, s1 - n, s0 - n]), Color(gold.r, gold.g, gold.b, a + 0.1))
	draw_line(s0 + n, s1 + n, Color(gold.r, gold.g, gold.b, a + 0.25), 1.0)
	draw_line(s0 - n, s1 - n, Color(gold.r, gold.g, gold.b, a + 0.25), 1.0)
	# our own and allied men on that stretch: the bit over each of them goes red
	for o in game.units_near(global_position + (s0 + s1) * 0.5, s0.distance_to(s1) * 0.5 + 40.0):
		if o == self or o.dead or o.off_field or o.is_air() or game.hostile(o.team, team):
			continue
		var gp: Vector2 = o.position - global_position
		var q := Geometry2D.get_closest_point_to_segment(gp, s0, s1)
		if q.distance_to(gp) <= o.radius + w + 10.0:
			var s: Vector2 = gd * (float(o.radius) + 4.0)
			draw_colored_polygon(PackedVector2Array([q - s + n, q + s + n, q + s - n, q - s - n]), Color(red.r, red.g, red.b, 0.5))


## The colour of powder bars on the unit card (its own, and its passengers'): a pale powder blue, apart from
## the green health, the cream / gold reload and the amber Clockwork charge.
const POWDER_BAR := Color(0.55, 0.78, 1.0)


## (a balloon) the pilot's rope from the basket to the ground and the keg coming up it: the
## rope drops (first 20%), its end coils on the ground (to 35%), then the barrel tied on
## rises to the basket (assets/effects/haul_coil.png, haul_barrel.png).
func _draw_haul() -> void:
	var f := clampf(haul_t / float(Defs.BALLOON["haul"]), 0.0, 1.0)
	var top := Vector2(0, sprite.position.y - 2.0)
	var ground := haul_at
	var info: Dictionary = ArtData.UNITS[kind]
	var rope := Color(0.62, 0.42, 0.22, 0.95)
	if f < 0.2:
		draw_line(top, top.lerp(ground, f / 0.2), rope, 1.0)
		return
	if f < 0.35:
		draw_line(top, ground, rope, 1.0)
		var cc: Vector2i = info.get("haul_coil", Vector2i.ZERO)
		var ct: Texture2D = Game.tex("res://assets/effects/haul_coil.png")
		if ct and cc.x > 0:
			var ci := clampi(int((f - 0.2) / 0.15 * 3.0), 0, 2)
			draw_texture_rect_region(ct, Rect2(ground - Vector2(cc.x * 0.5, cc.y - 1), Vector2(cc)), Rect2(ci * cc.x, 0, cc.x, cc.y))
		return
	var k := (f - 0.35) / 0.65
	var kp := ground.lerp(top, k) + Vector2(sin(haul_t * 5.0) * 0.8, 0)     # the barrel's bottom
	var bc: Vector2i = info.get("haul_barrel", Vector2i.ZERO)
	var bt: Texture2D = Game.tex("res://assets/effects/haul_barrel.png")
	if bt and bc.x > 0:
		draw_line(top, kp - Vector2(0, bc.y - 1), rope, 1.0)
		var bi := clampi(int(k * 4.0), 0, 3)
		draw_texture_rect_region(bt, Rect2(kp - Vector2(bc.x * 0.5, bc.y), Vector2(bc)), Rect2(bi * bc.x, 0, bc.x, bc.y))
	else:
		draw_line(top, kp - Vector2(0, 10), rope, 1.0)
		draw_rect(Rect2(kp + Vector2(-4, -10), Vector2(8, 10)), Color(0.45, 0.28, 0.12))


func _draw() -> void:
	if dead:
		# a veteran's body: how much essence it holds, for the Brood to see
		if kills > 0 and game.corpses.has(self):
			_draw_number(game.corpse_value(self), Vector2(0, -26))
		return
	if selected and (kind == "cannon" or kind == "mortar") and team == game.human and aboard == null:
		_draw_aim()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, radius + 2.0, Color(0, 0, 0, 0.25))
	if selected:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 24, Color(0.4, 1.0, 0.4, 0.9), 2.0)
	draw_set_transform(Vector2.ZERO)
	if haul_t >= 0.0 and kind == "balloon":
		_draw_haul()
	var top := -float(ArtData.UNITS[art]["anchor"].y) * float(d.get("art_scale", 1.0)) - 4.0
	if kind == "mortar":
		top = -50.0
	elif kind == "tesla_cart" and tesla_mode != "packed":
		top = -70.0    # above the raised coil's sparks (the packed body: the anchor height)
	elif kind == "cannon":
		top = -64.0 if not ArtData.UNITS["cannon"]["frames"].has("walk_e") else -float(ArtData.UNITS[kind]["anchor"].y) * 0.75
	var bw := radius * 2.4
	draw_health(top, bw, true)
	if has_attack():
		# the reload, only while reloading (or setting up a gun): nothing when ready
		var rf := reload_frac()
		var rcol := Color(0.92, 0.92, 0.85)
		var show := rf < 1.0 and not (_pmax > 0.0 and mode != "bayonet" and powder < 1.0)
		if deploys() and tesla_mode == "deploying":
			rcol = Color(0.45, 0.7, 1.0)           # limbering / rooting / packing
			rf = 1.0 - tesla_t / switch_time()
			show = true
		elif deploys() and tesla_mode != "deployed":
			show = false
		if show:
			var ry := top + 5.0 if hp < max_hp else top + 1.0
			draw_rect(Rect2(-bw * 0.5, ry, bw, 2).grow(0.5), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(-bw * 0.5, ry, bw * clampf(rf, 0.0, 1.0), 2), rcol)
	if work == "feeding":
		return
	if topter_bat != "":
		# the battery it carries, hanging under it
		var tb: Texture2D = Game.tex("res://assets/effects/battery_%s.png" % topter_bat)
		var tf := int(_bob_t * 10.0) % 13
		draw_texture_rect_region(tb, Rect2(-5, -18, 11, 22), Rect2(tf * 11, 0, 11, 22))
	if overclock_t > 0.0:
		# overloaded: a crackling ring at its feet
		var a := 0.55 + 0.3 * sin(overclock_t * 14.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, radius + 7.0, 0, TAU, 28, Color(1.0, 0.85, 0.3, a), 2.5)
		draw_arc(Vector2.ZERO, radius + 11.0, overclock_t * 3.0, overclock_t * 3.0 + 2.0, 10, Color(0.6, 0.85, 1.0, a), 1.5)
		draw_set_transform(Vector2.ZERO)
	if kind == "balloon" and not passengers.is_empty() and game.allied(team, game.human):
		# one pip under the basket for every man aboard
		var np := passengers.size()
		for i in np:
			var pr := Rect2(-np * 4.0 + i * 8.0 + 1.0, 8, 6, 6)
			draw_rect(pr, Color(1, 0.85, 0.4))
			draw_rect(pr, Color(0, 0, 0, 0.7), false, 1.0)
	if d["faction"] == "clockwork" and not is_worker():
		# the battery on its back, for everyone to see: how much charge is left. A cell
		# strapped onto the body sprite (scripts/battery_pack.gd follows the frames and the
		# charge itself); constructs with no pack in ArtData.PACKS carry none.
		if ArtData.PACKS.has(kind) and sprite.get_node_or_null("Pack") == null:
			var pk: Sprite2D = preload("res://scripts/battery_pack.gd").new()
			pk.name = "Pack"
			pk.set("unit", self)
			sprite.add_child(pk)
	if carrying > 0 and kind == "labourer" and anim != "carry":
		draw_circle(Vector2(6, -14), 3, Color(1, 0.85, 0.2))
	if carry_empty and carrying == 0 and kind == "winder":
		var et: Texture2D = Game.tex("res://assets/effects/battery_charge.png")
		draw_texture_rect_region(et, Rect2(-14, top + 10, 10, 22), Rect2(0, 0, 10, 22))
	if carrying > 0 and kind == "winder":
		# the battery on its back, and how much charge it still holds (it fades on the road)
		var f := clampf((1.0 - Defs.battery_charge(carry_blue, carry_t) / Defs.battery_charge(carry_blue, 0.0)) / (1.0 - float(Defs.BATTERY["floor"])), 0.0, 1.0)
		var bt: Texture2D = Game.tex("res://assets/effects/battery_%s.png" % ("blue" if carry_blue else "yellow"))
		var fr := int(_bob_t * 10.0) % 13
		draw_texture_rect_region(bt, Rect2(-14, top + 10, 11, 22), Rect2(fr * 11, 0, 11, 22))
		draw_rect(Rect2(-15, top + 33, 13, 3), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, top + 34, 11 * (1.0 - f), 1), Color(0.4, 1, 0.3).lerp(Color(1, 0.55, 0.1), f))
	if kind == "powder_wagon" and team == game.human:
		# the powder it carries: a little horn and a thin bar (amber; red when empty)
		var pw := bw
		var ph := 3.0 if kind == "powder_wagon" else 1.0
		var py := top + 5.0 if kind == "powder_wagon" else top + 8.5
		var pf := clampf(powder / _pmax, 0.0, 1.0)
		draw_rect(Rect2(-pw * 0.5, py, pw, ph).grow(0.5), Color(0, 0, 0, 0.65))
		if powder >= 1.0:
			draw_rect(Rect2(-pw * 0.5, py, pw * pf, ph), Color(0.95, 0.68, 0.22))
		else:
			draw_rect(Rect2(-pw * 0.5, py, pw, ph), Color(0.75, 0.15, 0.12))     # empty: all red
		var hx := -pw * 0.5 - 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(hx, py - 2), Vector2(hx + 4, py - 1), Vector2(hx + 4, py + ph + 1), Vector2(hx + 1, py + ph)]), Color(0.86, 0.78, 0.6))
		if kind == "powder_wagon" and supplying:
			draw_rect(Rect2(pw * 0.5 + 2.0, py - 1.0, 3, 3), Color(1, 0.85, 0.35))   # SUPPLY on
	if cocoon > 0 and not ArtData.UNITS["grub"]["frames"].has("carry_cocoon_e"):
		# the cocoon on its back (drawn by hand when there's no sheet)
		draw_set_transform(Vector2(0, -17), 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, 6.0, Color(0.86, 0.82, 0.68))
		draw_arc(Vector2.ZERO, 6.0, 0, TAU, 14, Color(0.45, 0.35, 0.25), 1.0)
		draw_line(Vector2(-5, -2), Vector2(5, 2), Color(0.6, 0.5, 0.4), 1.0)
		draw_line(Vector2(-5, 2), Vector2(5, -2), Color(0.6, 0.5, 0.4), 1.0)
		draw_set_transform(Vector2.ZERO)
	if carrying > 0 and kind == "grub":
		draw_circle(Vector2(0, -16), 3.5, Color(0.55, 0.85, 0.3))
		draw_circle(Vector2(0, -16), 3.5, Color(0.2, 0.3, 0.1), false, 1.0)
	if cross_t > 0.0:
		# just bandaged: a little cross over his head
		var y := top - 12.0
		var a := minf(cross_t, 1.0)
		draw_texture(Game.tex("res://assets/effects/cross.png"), Vector2(-6, y - 6), Color(1, 1, 1, a))
