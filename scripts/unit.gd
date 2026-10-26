class_name Unit
extends Entity
## A unit: moves along A* paths with soft separation, follows orders
## (move, attack-move, attack, hold, gather, build) and fights by type.

const WALK_FPS := 8.0
## The cuirassier's 8-frame gallop at full speed (8 frames / 14 fps = one stride in ~0.57 s;
## at WALK_FPS the horse took a whole second per stride and looked to be trotting on the spot).
const CUIRASSIER_GALLOP_FPS := 14.0
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
var siege_t := 0.0              # (computer) its army is breaking in at a wall: the AI's siege gives the orders
var _wall_chk := 0.0
var _reach_t := 0.0             # (stuck chasing something) when it next asks whether it can get at it at all
var _wall_look_t := 0.0         # (melee) when it next checks whether it's pressed against an enemy wall it must break
var _detour: Building = null    # (melee, told to attack a man walled off from it) the wall piece it breaks first
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
var _anim_art := ""             # whose sheet the sprite shows now (the mounted kind's while getting on)
var _mount_len := 0.0           # (mounting / dismounting) how long it takes: the strip plays over it
var _mount_face := Vector2.ZERO # (mounting / dismounting) the way the horse is turned (mount_face: S, SE, E, N, SW, W)


var _charging := false
var tesla_mode := "packed"     # Tesla Cart: packed, deploying, deployed, packing
var tesla_t := 0.0
var _bob_t := 0.0
var _draw_key := Vector4i(-1, -1, -1, -1)
var _push := Vector2.ZERO
# Crown abilities
var mode := ""                  # musketeer "" (musket) or "bayonet" (chosen by itself); cannon "" (round shot) or "canister"
var _melee_t := 0.0             # musketeer: when it next looks for an enemy close enough for the bayonet
var art := ""                   # whose sprites it wears (a Guardsman: "musketeer_armoured"; a Horseman: "horseman")
var coat := ""                  # its horse's coat (HorseCoat), for the units that have one
var armoured := false           # Musketeer / Horseman: refitted with Armour (or came out with it): Guardsman / Cuirassier
var lock := ""                  # Musketeer: his musket lock ("", or one of Defs.LOCKS)
var bayonet := false            # Musketeer: refitted with the socket bayonet
var refit: Array = []           # soldier on a "refit" order: the upgrades he's going to get (paid)
var refit_paid := [0, 0]        # what was paid for them (back if the refit is called off)
var _refit_t := 0.0
var refit_home := Vector2.INF   # where he was when sent: he walks back there when fitted
var auto_refit := false         # Powder Wagon: AUTO REFIT (idle Musketeers nearby get the upgrades researched)
# Missionary raising the fallen; a raised soldier's second life
var _body: Unit = null          # (a Missionary) the body he's going to raise
var reviver: Unit = null        # (a body) the Missionary coming to raise it
var died_at := 0.0              # (a body) the game clock when it fell
var final_death := false        # (a body) fell under the cross: it can't be raised again
var knock := Vector2.ZERO       # being shoved back
var stun_t := 0.0
var _sep_n := 0
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
var cw := {}                 # Clockwork roster prototype state (scripts/cw_units.gd)
var slow_t := 0.0              # slowed (Bloater acid)
var kills := 0:                 # veterancy: enemy kills only (it shows on the sprite: VetLook)
	set(v):
		var was := VetLook.level(kills)
		kills = v
		if sprite and VetLook.level(v) != was:
			VetLook.apply(self)
var patrol_a := Vector2.INF     # PATROL: the two ends he walks between (INF: not patrolling)
var patrol_b := Vector2.INF
var friendly_kills := 0         # our own men his blows finished off (splash): just for the card
var harvester: Unit = null      # (a body) the grub coming to take it
var cocoon := 0.0               # (a grub) essence it carries home (Game.corpse_value: 1.25 a supply)
var gas := 100.0                # Bloater: what's left in the sac (spits use it, the burst scales with it)
# A Musketeer in a balloon's basket: its pose up there (gun_state[0], "idle"/"down"/"up") and
# how long it has held it
var gun_cd: Array = [0.0, 1.5]
var gun_state: Array = ["idle", "idle"]
var gun_t: Array = [0.0, 0.0]
var _pilot_spr: Sprite2D        # (a balloon) its basket (over the envelope and rigging)
var _pilot_fig: Sprite2D        # (a balloon) its pilot, on his own layer between the basket and the riders
var _haul_node: Node2D          # (a balloon) the haul rope and keg, over the whole balloon
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
var jump := {}                  # Jack: the leap under way ({} on the ground; scripts/jack.gd)
var jump_cd := 0.0              # Jack: seconds before its spring can JUMP again
var jumps := 0                  # Jack: leaps made (tests, the log)
var shots := 0                  # Jack: screws fired (tests)
var last_shot: Shot = null      # Jack: its last screw in flight (tests, screenshots)
var last_tip := Vector2.ZERO    # Jack: where its last screw left from (the drill tip, raised at a flyer; tests)
var _jack_t := 0.0              # Jack (the computer's): when it next thinks of jumping away
var owl_t := -1.0               # Swift: seconds into turning into a Ticking Owl (-1: not; scripts/cw_air.gd)
var bombs := 0                  # Ticking Owl: bombs let go (tests)
var last_bomb: OwlBomb = null   # Ticking Owl: its last bomb (tests, screenshots)
var _owl_bomb := false          # Ticking Owl: this attack is a bomb on a building (else the talon swoop)
var _reach := Vector2.ZERO      # Swift / Ticking Owl: how far its lunge or swoop carries the sprite (CwAir.reach)
var swings := 0                 # Pendulum: swings made (tests)
var last_hits := 0              # Pendulum: the enemies its last swing caught (tests)
var nets := 0                   # Netter: nets fired (tests)
var last_net: ChainNet = null   # Netter: its last net in flight (tests, screenshots)
var net_t := 0.0                # CAUGHT in a Netter's net: s left (it cannot move or fight; a flyer is down on the ground)
var nets_in := 0                # nets flying at it now (Netters pick someone else meanwhile)
var nets_taken := 0             # nets that caught it (tests)
var net_drop := 0.0             # s since the net over it landed (it drops onto it: Netter.update_net)
var _net_spr: Sprite2D          # the spread net over it while caught
var _low := 0.0                 # a flyer brought down by a net: 0 at its flying height, 1 on the ground
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
	if game.net_forward(self, "set_brace", [on]): return
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
## (a hauler: a Labourer assigned to a Town Hall, order "gather" with home_mine the hall) his
## job from Game.haul_dispatch, or {} (waiting by the hall): {"k": "horse" | "team" | "keg",
## "ph": "fetch" | "deliver" | "home" | "to_mill" | "to_wagon", "want": [horses claimed, not yet
## on the leash], "wagon" / "gun": the keg's / the team horses' destination}
var haul_job: Dictionary = {}
var team_want := 0              # (a gun, wagon) horses it should draw: haulers bring spares up to this
# the cavalry's pistol (Defs.PISTOL: Horseman, Cuirassier, Officer, Armoured Officer)
var pistol := false             # loaded (trained loaded; fired, it stays empty until he reloads on foot)
var hold_fire := false          # HOLD FIRE: he never fires the pistol by himself
var pistol_t := 0.0             # (an Officer) how far through reloading it, in seconds
# Horses (Defs.HORSES)
var led: Array = []              # (a man) the horses he leads by the reins, in their string
var leader: Unit = null          # (a horse) who leads it
var claimed: Unit = null         # (a horse) the man walking over to mount or lead it
var into: Entity = null          # (a horse) the building it walks into (training) or the gun it goes to
var _into_t := 0.0
var graze_at := Vector2.INF      # (a horse) where it was left: it grazes round here
var _graze_goal := Vector2.INF
var _graze_t := 0.0
var _steal_t := 0.0
var harnessed := true            # (a cannon, mortar, wagon) its horse is hitched
var horse_hp := 1.0              # (a rider, a gun) his horse's health share, for when it steps off
var horse_miles := 0.0           # (a horse) tiles travelled under a rider or in harness: its veterancy (Defs.HORSE_VET); (a rider, a gun) his horse's
var _heal_remount := false       # (a Missionary, a patient) got off to bandage / be bandaged: back on after
var team_horses: Array = []      # (a gun, wagon) the extra horses in its team beyond the first: {coat, hp share}
var horse_rid := 0               # (a horse) the queue entry or rider it's reserved for; (a rider) the horse reserved for him
var rally_after := Vector2.INF   # (a new rider waiting for his horse) where he goes once mounted
var _res_t := 0.0
var _res_walk := false
var steed: Unit = null           # (a man who got off) the horse he rode
var loose_horse: Unit = null     # (a fallen rider's body) his horse that lived and bolted, belonging to nobody
var bolt_to := Vector2.INF       # (a loose horse) where it gallops off to, away from the fight
var bolt_t := 0.0                # (a loose horse) bolting: seconds it still runs (0: calm, grazing)
## Tests: >= 0 replaces both bolt chances (Defs.HORSES bolt_ranged / bolt_melee; Defs are
## read-only). Blows that never leave a horse (area, the Brood) stay at 0.
static var bolt_force := -1.0
var auto_mount := false          # (on foot after a Dragoon's own dismount, or the computer's) remounts by himself to move
var pouch := false               # (a musket soldier) refitted with the Shot Pouch: 20 shots
var after: Dictionary = {}       # (mounting / dismounting) the order he goes on with afterwards
var _lonely_t := 0.0
var _care_auto := false          # (a Missionary) the patient he walks to is his own pick (Defs.CARE)
var _rein: Node2D                # (a horse) the reins to its leader, drawn over the horse
var _rein_on := false
var _feather: Node2D             # (a dismounted horseman) the plume on his hat (TEMP_ART "feather")


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
var rip_from := 0.0              # (a body) when it settled, and how long it lies (its bar)
var rip_len := 0.0


func _rest_in_peace() -> void:
	queue_redraw()
	set_physics_process(false)
	set_process(false)
	# bodies the Brood can harvest, or a Missionary raise, lie there longer
	var lie := float(Defs.HARVEST["time"]) if game.corpses.has(self) else CORPSE_TIME
	if game.fallen.has(self):
		lie = maxf(lie, float(Defs.REVIVE["window"]) - corpse_t)
	rip_from = game.clock
	rip_len = lie
	if not game.bodies.has(self):
		game.bodies.append(self)
	_rip = create_tween()
	_rip.tween_interval(lie)
	_rip.tween_callback(func() -> void:
		game.corpses.erase(self)
		game.fallen.erase(self))
	_rip.tween_property(self, "modulate:a", 0.0, 3.0)
	_rip.tween_callback(queue_free)


var torn := false               # (a body) torn up by a shell, round shot, canister or bomb (Game.tear_body): going


## (a body) torn up by an area shot (Game.tear_body: already off the harvest and revive lists): it darkens and is gone in
## a moment.
func tear_up() -> void:
	torn = true
	if _rip and _rip.is_valid():
		_rip.kill()
	_rip = null
	set_physics_process(false)
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(0.3, 0.24, 0.2, 0.0), 0.3)
	tw.tween_callback(queue_free)


## (a body) raised by a Missionary: back on the field with part of its health, under the
## cross for a while (fall again under it and it's for good).
func revive() -> void:
	if _rip and _rip.is_valid():
		_rip.kill()
	_rip = null
	game.bodies.erase(self)
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
	if is_mounted():
		_leave_dead_horse()
		morph(String(Defs.FOOT[kind]))     # raised on foot: horses are never raised
	_set_anim("idle", true)
	_draw_key = Vector4i(-1, -1, -1, -1)
	queue_redraw()
	game.on_unit_revived(self)
	# his horse bolted when he fell: still loose close by, he walks over and gets back on
	var lh := loose_horse
	loose_horse = null
	if lh and is_instance_valid(lh) and not lh.dead and lh.team < 0 and can_mount() \
			and lh.position.distance_to(position) <= float(Defs.HORSES["bolt_back"]) * Defs.TILE:
		cmd_mount(lh)


## The chance a rider's horse lives when he's killed by this kind of blow (Entity.BLOW_*).
static func bolt_chance(blow: String) -> float:
	if blow == BLOW_RANGED:
		return bolt_force if bolt_force >= 0.0 else float(Defs.HORSES["bolt_ranged"])
	if blow == BLOW_MELEE:
		return bolt_force if bolt_force >= 0.0 else float(Defs.HORSES["bolt_melee"])
	return 0.0            # the Brood's jaws, splash and area, unknown: it dies with him


## (a rider, killed) his horse may live: it bolts, nobody's, and he lies there on foot (his
## body is only the man now: the Brood gets no horse with him, a Missionary raises him on foot).
func _rider_falls() -> void:
	if horse_hp <= float(Defs.HORSES["bolt_hp"]) or randf() >= bolt_chance(last_blow):
		return               # (a horse nearly dead already goes down with him)
	loose_horse = _loose_horse(coat, horse_miles, horse_hp, position)
	horse_miles = 0.0
	horse_hp = 1.0
	morph(String(Defs.FOOT[kind]))
	coat = ""
	hp = 0.0


## (a cannon or mortar, destroyed) each horse of its team may live and bolt, by the blow
## that did it (a Powder Wagon blows up: its horses never do).
func _team_bolts() -> void:
	var ch := bolt_chance(last_blow)
	if ch <= 0.0:
		return
	if harnessed and horse_hp > float(Defs.HORSES["bolt_hp"]) and randf() < ch:
		_loose_horse(coat, horse_miles, horse_hp, position + Vector2(-facing.y, facing.x) * (radius + 8.0))
	for th in team_horses:
		if float(th.get("hp", 1.0)) > float(Defs.HORSES["bolt_hp"]) and randf() < ch:
			_loose_horse(String(th.get("coat", "")), float(th.get("m", 0.0)), float(th.get("hp", 1.0)),
				position + facing * (radius + 10.0) + Vector2(randf_range(-8, 8), randf_range(-8, 8)))
	team_horses.clear()


## A horse that lived through its rider's (or gun's) end: nobody's, at `at`, bolting away
## from whoever did it.
func _loose_horse(c: String, miles: float, share: float, at: Vector2) -> Unit:
	var spot := game.resolve_terrain(at, position, 11.0, -1)
	var h := game._add_unit("horse", -1, spot)
	h.coat = c if HorseCoat.COATS.has(c) else HorseCoat.pick()
	HorseCoat.apply(h)
	h.horse_miles = miles
	h.apply_horse_vet()
	h.hp = h.max_hp * clampf(share, 0.05, 1.0)
	h.facing = facing if facing != Vector2.ZERO else Vector2.DOWN
	h.visible = visible
	h.bolt_from(_threat_point())
	game.horse_bolted(h, team, kind)
	return h


## Where the blow came from: who dealt it, else the nearest enemy close by (INF: nobody).
func _threat_point() -> Vector2:
	if last_hitter and is_instance_valid(last_hitter) and not last_hitter.is_queued_for_deletion():
		return last_hitter.global_position
	var best := Vector2.INF
	var bd := 10.0 * Defs.TILE
	for o in game.units_near(position, bd):
		if not o.dead and game.hostile(o.team, team):
			var dd: float = o.position.distance_to(position)
			if dd < bd:
				bd = dd
				best = o.position
	return best


## (a loose horse) gallop HORSES.bolt_tiles away from `from` (any way, if INF), then calm
## down and graze where it stops.
func bolt_from(from: Vector2) -> void:
	var away := Vector2.from_angle(randf() * TAU)
	if from != Vector2.INF and from.distance_to(position) > 1.0:
		away = (position - from).normalized()
	var tiles: Array = Defs.HORSES["bolt_tiles"]
	var dist := randf_range(float(tiles[0]), float(tiles[1])) * Defs.TILE
	var here := game.region_of(game.cell_of(position))
	var goal := Vector2.INF
	for a in [0.0, 0.35, -0.35, 0.7, -0.7, 1.1, -1.1, 1.6, -1.6]:
		for f in [1.0, 0.75, 0.5]:
			var q: Vector2 = position + away.rotated(a) * dist * f
			var c: Vector2i = game.cell_of(q)
			if game.in_open_map(c) and game._clear_at(q, radius, team) and game.region_of(c) == here:
				goal = q
				break
		if goal != Vector2.INF:
			break
	bolt_to = goal if goal != Vector2.INF else position
	bolt_t = 8.0
	graze_at = Vector2.INF
	_graze_goal = Vector2.INF
	_steal_t = 0.0
	facing = (bolt_to - position).normalized() if bolt_to.distance_to(position) > 1.0 else facing
	repath_t = 0.0


## A rider raised from his body: his horse stays where it fell, a carcass for the Brood.
func _leave_dead_horse() -> void:
	var f := facing if facing != Vector2.ZERO else Vector2.RIGHT
	var spot := game.resolve_terrain(position - f * (radius + 10.0), position, 11.0, team)
	var h := game._add_unit("horse", team, spot)
	h.coat = coat if coat != "" else HorseCoat.pick()
	HorseCoat.apply(h)
	h.horse_miles = horse_miles
	h.apply_horse_vet()
	h.facing = facing
	h.visible = visible
	h.hp = 0.0
	h.die()
	h.frame_i = 99             # already down: the last frame of its fall
	h.corpse_t = corpse_t
	h.died_at = died_at
	horse_miles = 0.0
	coat = ""


## A soldier refitted with Armour (Defs.ARMOURED): the armoured version, with his own name,
## tag, armour, health, speed and sprites. (His `d` is his own copy: everything that reads
## d["armor"], d["hp"], d["tags"] or d["name"] sees it.)
func put_on_armour() -> void:
	if not Defs.ARMOURED.has(kind) or armoured:
		return
	var info: Dictionary = Defs.ARMOURED[kind]
	armoured = true
	d["armor"] = float(Defs.UNITS[kind]["armor"]) + float(info["armor"])
	d["hp"] = float(Defs.UNITS[kind]["hp"]) + float(info["hp"])
	d["speed"] = float(Defs.UNITS[kind]["speed"]) + float(info.get("speed", 0))
	d["tags"] = ["armored"]
	d["name"] = String(info["name"])
	d["about"] = String(info["about"])
	armor = float(d["armor"])
	max_hp = float(d["hp"])
	hp = minf(max_hp, hp + float(info["hp"]))
	speed = float(d["speed"])
	if ArtData.UNITS.has(Defs.art_for(kind, true)):
		art = Defs.art_for(kind, true)
	if sprite and not dead:
		_set_anim(anim if anim != "" else "idle", true)
	queue_redraw()


## A soldier's kit ({"armour": bool, "lock": key, "bayonet": bool}): a recruit's, or a saved
## one. (A Horseman's is only "armour".)
func set_kit(kit: Dictionary) -> void:
	if not Defs.ARMOURED.has(kind):
		return
	if kit.get("armour", false):
		put_on_armour()
	if Defs.MUSKETS.has(kind):
		var lk := String(kit.get("lock", ""))
		if Defs.LOCKS.has(lk) and Defs.LOCKS.find(lk) > lock_level():
			lock = lk
		if kit.get("bayonet", false):
			bayonet = true
		if kit.get("pouch", false):
			set_pouch()
	queue_redraw()


func get_kit() -> Dictionary:
	if Defs.MUSKETS.has(kind):
		return {"armour": armoured, "lock": lock, "bayonet": bayonet, "pouch": pouch}
	return {"armour": armoured}


## The Shot Pouch: he can carry Defs.POWDER "pouch" shots (what he has stays; he fills up
## at any powder source).
func set_pouch() -> void:
	pouch = true
	_pmax = max_powder()


## Light or armoured, and the rest of its tags (a Guardsman or Cuirassier is "armored").
func has_tag(tag: String) -> bool:
	return (d.get("tags", []) as Array).has(tag)


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
	if bayonet:
		parts.append("Socket Bayonet")
	if pouch:
		parts.append("Shot Pouch")
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
	refit_home = position
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
				elif w == "bayonet":
					bayonet = true
				elif w == "pouch":
					set_pouch()
				elif Defs.LOCKS.find(w) > lock_level():
					lock = w
			refit.clear()
			refit_paid = [0, 0]
			game.refit_done(self, done)
			queue_redraw()
			var home := refit_home
			refit_home = Vector2.INF
			if _next_order():
				pass                        # (a Shift-queued order is next)
			elif home != Vector2.INF and home.distance_to(position) > 40.0:
				cmd_move(home, false)       # (back to where he was sent from)
			else:
				cmd_stop()
		return Vector2.ZERO
	work = "to_refit"
	work_t += delta
	if work_t > float(Defs.REFIT["give_up"]):
		if team == game.human:
			game.notify("A %s couldn't reach the place to be refitted. Paid back." % String(d["name"]))
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
	if Defs.MUSKETS.has(kind) and Defs.RESEARCH.has(lock):
		m = float(Defs.RESEARCH[lock]["reload"])
	if kind == "musketeer" and auto_mount:
		m *= float(Defs.HORSES["dragoon_reload"])     # a Dragoon fighting on foot
	return float(d["cooldown"]) * m


## A soldier on foot with a musket and a blade: picks musket or blade by himself.
func foot_musket() -> bool:
	return kind == "musketeer"


## Carries the cavalry's pistol (Defs.PISTOL): a Horseman, Cuirassier or Officer.
func has_pistol() -> bool:
	return (Defs.PISTOL["kinds"] as Array).has(kind)


## His blade's mode: the Officer's sabre is his "bayonet" (d.sabre), the rider's his plain blow.
func _sabre_mode() -> String:
	return "bayonet" if kind == "dismounted" else ""


## Pistol or sabre, chosen between blows: the loaded pistol at an enemy man (not a building),
## unless HOLD FIRE; else the sabre.
func _pick_pistol() -> void:
	if phase != "":
		return
	var want := _sabre_mode()
	if pistol and not hold_fire and not (target is Building) and not (order_target is Building and order == "attack"):
		want = "pistol"
	if want != mode:
		mode = want
		if target and not _valid_target(target):
			target = null
			phase = ""


## (an Officer) reloading his pistol by himself: Defs.PISTOL reload s, out of a sabre fight,
## spending a charge of his powder (none: he can't).
func _pistol_reload(delta: float) -> void:
	if pistol or kind != "dismounted":
		pistol_t = 0.0
		return
	if powder < float(Defs.PISTOL["powder"]) or phase != "" or aboard:
		return
	if target and is_instance_valid(target) and target.edge_distance(position) - radius < float(Defs.PISTOL["busy"]):
		return
	pistol_t += delta
	if pistol_t >= float(Defs.PISTOL["reload"]):
		pistol_t = 0.0
		pistol = true
		powder -= float(Defs.PISTOL["powder"])


## The Crown's firearms besides the cavalry pistol: the musket (a Musketeer or Guardsman, a
## Dragoon in the saddle or on foot), the guns, and the balloon (its basket's muskets).
const GUN_KINDS := ["musketeer", "dragoon", "cannon", "mortar", "balloon"]


## Fires a gun of some kind (and so has HOLD FIRE).
func has_gun() -> bool:
	return has_pistol() or GUN_KINDS.has(kind)


## The weapon in hand right now is a firearm (not the bayonet or the sabre).
func _shooting() -> bool:
	if has_pistol():
		return mode == "pistol"
	if foot_musket():
		return mode != "bayonet"
	return kind == "cannon" or kind == "mortar"


## HOLD FIRE keeps this shot: he never opens fire by himself (no target of his own, nor firing
## back), only on a target the player told him to attack (ATTACK; attack-move doesn't count).
## The cavalry's pistol is kept even then (their one shot: they fight with the sabre). Blades
## still fight.
func _fire_held(e: Entity) -> bool:
	if not hold_fire or not _shooting():
		return false
	if has_pistol():
		return true
	return not (order == "attack" and order_target == e)


## HOLD FIRE on or off (any unit with a firearm).
func set_hold_fire(on: bool) -> void:
	if game.net_forward(self, "set_hold_fire", [on]): return
	if not has_gun():
		return
	hold_fire = on
	if on and phase == "aim" and _fire_held(target):
		phase = ""              # (not yet fired: he holds it)
		cooldown = maxf(cooldown, 0.2)
	if on and target and not has_pistol() and _fire_held(target):
		target = null           # (a target of his own: let it go)


## On a horse (the horse is part of him: DISMOUNT puts it beside him).
func is_mounted() -> bool:
	return Defs.FOOT.has(kind)


## A horse's rank of veterancy for `m` tiles travelled (Defs.HORSE_VET).
static func horse_rank(m: float) -> int:
	return mini(int(m / float(Defs.HORSE_VET["tiles"])), int(Defs.HORSE_VET["max"]))


## The health a seasoned horse has over a green one.
static func horse_bonus_hp(m: float) -> float:
	return float(Defs.UNITS["horse"]["hp"]) * float(Defs.HORSE_VET["hp"]) * horse_rank(m)


## (a horse) its health for its veterancy, keeping its share.
func apply_horse_vet() -> void:
	var frac := hp / maxf(max_hp, 1.0)
	max_hp = float(d["hp"]) + horse_bonus_hp(horse_miles)
	hp = max_hp * frac


## Is a horse working under him (ridden, or drawing this gun or wagon)?
func horse_working() -> bool:
	return is_mounted() or (harnessed and Defs.HARNESSED.has(kind))


## Horses heal by themselves; a working one gains veterancy with the ground it covers.
func _horse_upkeep(delta: float) -> void:
	var hmax := float(Defs.UNITS["horse"]["hp"])
	if kind == "horse":
		if hp < max_hp:
			hp = minf(max_hp, hp + Defs.HORSE_REGEN * delta)
		return
	if not horse_working():
		return
	var heal := Defs.HORSE_REGEN * delta / hmax
	horse_hp = minf(1.0, horse_hp + heal)
	for th in team_horses:
		th["hp"] = minf(1.0, float(th["hp"]) + heal)
	var moved := velocity.length() * delta / Defs.TILE
	if moved <= 0.0:
		return
	for th in team_horses:
		th["m"] = float(th.get("m", 0.0)) + moved
	var r0 := horse_rank(horse_miles)
	horse_miles += moved
	var r1 := horse_rank(horse_miles)
	if r1 > r0:
		if is_mounted():
			var gain := horse_bonus_hp(horse_miles) - horse_bonus_hp(horse_miles - moved)
			max_hp += gain
			hp += gain
		if team == game.human:
			game.float_text(position + Vector2(0, -44), "seasoned horse (rank %d)" % r1, Color(0.95, 0.85, 0.55))


func is_horse() -> bool:
	return kind == "horse"


## A Clockwork construct with no charge left.
func powered_down() -> bool:
	return d["faction"] == "clockwork" and not is_worker() and wind <= 0.0


func is_worker() -> bool:
	return Defs.is_worker(kind)


## A worker that can hurt (Labourer, Grub) fights when told to ATTACK: an attack-move engages
## what it meets, like a soldier's. Idle workers never pick fights by themselves.
func fights_on_command() -> bool:
	return not is_worker() or float(d["damage"]) > 0.0


## A worker given an attack order stays at war: the fight comes before the automatic WORK and
## REPAIR, and it goes on from enemy to enemy until none is left in sight; only then does it
## go back to work by itself. Any other order ends it.
var war := false


func is_air() -> bool:
	return d.get("air", false) and net_t <= 0.0      # (a flyer caught in a net is down on the ground: scripts/netter.gd)


## Can this unit attack that one at all?
func can_hit(e: Entity) -> bool:
	if Defs.cw_roster and CwUnits.on(kind) and not CwUnits.can_fire(self):
		return false
	if d.get("medic", false) or d.get("no_attack", false) or e.untouchable():
		return false
	if deflate != "" or (kind == "skywing" and sky != "air" and sky != "ground"):
		return false            # a deflated Bloater, a Skywing landing or taking off
	if owl_t >= 0.0:
		return false            # (a Swift turning into a Ticking Owl)
	if kind == Defs.NETTER and (not (e is Unit) or ((e as Unit).net_t > 0.0 and not (order == "attack" and e == order_target))):
		return false            # (its net is for units, and one caught already only when it is told to)
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
	if Defs.MUSKETS.has(kind):
		return float(Defs.POWDER["pouch"] if pouch else Defs.POWDER["musketeer"])
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
	if game.net_forward(self, "set_supply", [on]): return
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
	if _owl_bomb and kind == Defs.OWL:
		return float(Defs.OWL_BOMB["cooldown"])
	if kind == "heavy_loco":
		return float(d["cooldown"]) * CwUnits.cooldown_mult(self)
	if mode == "pistol":
		return float(Defs.PISTOL["after"])
	if mode == "bayonet" and d.has("sabre"):
		return float(d["sabre"]["cooldown"])
	if mode == "bayonet":
		return float(Defs.BAYONET["cooldown"]) * (float(Defs.RESEARCH["bayonet"]["cooldown"]) if bayonet else 1.0)
	if mode == "canister":
		return float(Defs.CANISTER["cooldown"]) * float(d.get("drill_reload", 1.0))
	if Defs.MUSKETS.has(kind):
		return musket_cooldown()
	if overclock_t > 0.0:
		return float(d["cooldown"]) * float(Defs.OVERLOAD["cooldown"])
	return float(d["cooldown"])


## How long a blow's strike phase lasts (the attack strip keeps playing): 0.35 s, or the Swift's and the Owl's own
## (Defs.FLYER "strike", Defs.OWL_BOMB "strike") so their whole lunge, swoop or drop is seen.
func _strike_time() -> float:
	if _owl_bomb and kind == Defs.OWL:
		return float(Defs.OWL_BOMB["strike"])
	if Defs.FLYER.has(kind):
		return float(Defs.FLYER[kind]["strike"])
	if kind == Defs.PENDULUM:
		return float(Defs.PENDULUM_SWING["strike"])      # (the blade swings on through the strip's last frames)
	if kind == Defs.NETTER:
		return float(Defs.NET["strike"])                 # (the recoil eases back)
	return 0.35


func _aim() -> float:
	if _owl_bomb and kind == Defs.OWL:
		return float(Defs.OWL_BOMB["aim"])      # (the weight is let go on the 2nd frame of the drop)
	if mode == "pistol":
		return float(Defs.PISTOL["aim"])
	if mode == "bayonet":
		return Defs.BAYONET["aim"]
	return float(d.get("aim", 0.25))


func can_gather() -> bool:
	return kind == "labourer" or kind == "grub" or kind == "winder"


func take_damage(amount: float, from: Entity, blow := "") -> void:
	if Defs.cw_roster:
		amount = CwUnits.incoming(self, amount, from, blow)
	if work == "feeding":
		amount *= 0.5      # burrowed grubs are hard to hit
	if not team_horses.is_empty() and amount > 0.0 and not dead:
		# the extra horses of a gun's team take a share of the blow, the front one first
		var share := amount * float(Defs.HORSES["team_hit"])
		amount -= share
		var front: Dictionary = team_horses.back()
		front["hp"] = float(front["hp"]) - share / maxf(float(Defs.UNITS["horse"]["hp"]), 1.0)
		if float(front["hp"]) <= 0.0:
			team_horses.pop_back()
			queue_redraw()
			if team == game.human:
				game.float_text(position + Vector2(0, -44), "a horse fell", Color(1.0, 0.6, 0.5))
	super.take_damage(amount, from, blow)
	# a Winder hit while carrying a battery: it blows up
	if kind == "winder" and carrying > 0 and not dead and from != self:
		_battery_blast()


## Musketeers carried in the basket shoot: each with its own reload, range, damage and
## powder (topped up from the balloon's store), spreading their fire.
## A Musketeer firing from a balloon's basket reaches this much further than on the ground.
const BASKET_RANGE := 1.35


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
		# (HOLD FIRE on the balloon, or on the man himself: the basket keeps its fire)
		if p.cooldown > 0.0 or stun_t > 0.0 or p.powder < 1.0 or hold_fire or p.hold_fire:
			continue
		var rng := float(p.d["range"]) * BASKET_RANGE      # shooting down from the sky reaches further
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
	if game.net_forward(self, "cmd_restock", []): return false
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
## How far a rider's feet sit below the basket's floor line (px, before the basket scale):
## his own full-body sprite, sunk so only his top half shows over the front wall.
const RIDER_DROP := 13.0
const BASKET := {
	"scale": 0.8,
	"riders": [Vector2(-14.5, -1.0), Vector2(14.5, -1.0), Vector2(-6.5, 0.0), Vector2(6.5, 0.0)],
}
## With men in the middle two places the pilot steps up on a crate at the back of the
## basket (px): his head and shoulders over theirs. Pulling the rope he stands tall anyway.
const PILOT_LIFT := 0.0          # (tried raising him over a full basket: he looked outside it)


## How high the pilot stands (px up): on his crate when the middle of the basket is full.
func _pilot_lift() -> float:
	return PILOT_LIFT if passengers.size() >= 3 and _pilot_frame() != 3 else 0.0


## The pilot's frame of the basket strips (basket_, pilot_, basket_front_<dir>): 0 holding the
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
	if _pilot_fig:
		_pilot_fig.visible = not dead_anim
	if _haul_node:
		_haul_node.queue_redraw()
	for g in _pass_sprites:
		(g as Sprite2D).visible = false
	if dead_anim:
		return
	# the basket with its pilot, and its front wall over the riders' legs: on the body's cell
	var pf := _pilot_frame()
	var nb := int(info.get("basket_frames", 1))
	for pair in [[_pilot_spr, "basket"], [_pilot_fig, "pilot"], [_front, "basket_front"]]:
		var s: Sprite2D = pair[0]
		if s == null:
			continue
		s.texture = _basket_tex(pair[1], anim_dir)
		if s.texture == null:
			continue
		s.hframes = nb
		s.frame = mini(pf, nb - 1)
		s.offset = sprite.offset
	if _pilot_fig:
		_pilot_fig.offset.y -= _pilot_lift()
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
		# each man in his own clothes (an armoured Musketeer in his morion and breastplate),
		# from the waist up: the basket's front wall hides his legs
		var pa: String = p.art if p.art != "" else p.kind
		var pinfo: Dictionary = ArtData.UNITS.get(pa, {})
		var key: String = {"idle": "idle", "down": "fire", "up": "fireup"}.get(st, "idle") + "_" + anim_dir
		var pframes: Dictionary = pinfo.get("frames", {})
		if not pframes.has(key):
			key = "idle_" + anim_dir
		if pinfo.is_empty() or not pframes.has(key):
			g.texture = Game.tex("res://assets/units/%s/gunner_%s_%s.png" % [kind, st, anim_dir])
			g.hframes = int(gfr.get(st, 1))
			g.offset = -anchor
		else:
			g.texture = Game.tex("res://assets/units/%s/%s.png" % [pa, key])
			g.hframes = int(pframes[key])
			g.offset = -Vector2(pinfo["anchor"]) + Vector2(0, RIDER_DROP)
		g.frame = clampi(int(float(p.gun_t[0]) / 0.7 * g.hframes), 0, g.hframes - 1) if st != "idle" else 0
		g.scale = Vector2(sc, sc)
		g.position = sprite.offset + mid + Vector2(riders[mini(i, riders.size() - 1)])
		g.self_modulate = Color.WHITE
		_gunner_material(g, p)


## A man in the balloon's basket is drawn in his own colours and veterancy trim, but from
## another strip than his own (hidden) sprite's: his own copy of its material, with the trim
## mask of the strip he is drawn from.
func _gunner_material(g: Sprite2D, p: Unit) -> void:
	var src := p.sprite.material as ShaderMaterial if p.sprite else null
	g.use_parent_material = src == null       # (else the balloon's material: no trim)
	if src == null:
		g.material = null
		return
	var gm := g.material as ShaderMaterial
	if gm == null or gm == src:
		gm = ShaderMaterial.new()
		gm.shader = src.shader
		g.material = gm
	for k in ["team", "tint", "flash", "vet_style", "vet_level"]:
		gm.set_shader_parameter(k, src.get_shader_parameter(k))
	gm.set_shader_parameter("vet_mask", VetLook.mask_for(g.texture, VetLook.style_of(p)))


## Workers at work can be heard (near the view; Sfx fades them with distance and GAP keeps
## a crowd from piling up): hammering and sawing on a site, a hoe in a farm, a crank.
const WORK_SOUNDS := {"building": {"labourer": "work/crown_build", "winder": "work/clock_build", "grub": "work/brood_build"},
	"repairing": {"labourer": "work/crown_build", "winder": "work/clock_build", "grub": "work/brood_build"},
	"morphing": {"grub": "work/brood_build"}, "winding": {"winder": "work/winder_crank"},
	"manning": {"labourer": "work/hoe"}}
var _work_snd_t := randf() * 2.0


func _work_sound(delta: float) -> void:
	_work_snd_t -= delta
	if _work_snd_t > 0.0:
		return
	var name: String = WORK_SOUNDS.get(work, {}).get(kind, "")
	if work == "manning" and _mill_walking and home_mine is Building and (home_mine as Building).kind == "powder_mill":
		_work_snd_t = 0.1       # (the bite comes when he is at his heap again)
		return
	if name == "" or (work == "manning" and not ((anim == "mine" and home_mine is Building and (home_mine as Building).kind == "farm") \
			or (anim == "shovel" and home_mine is Building and (home_mine as Building).kind == "powder_mill"))):
		_work_snd_t = 0.5
		return
	_work_snd_t = MILL_CYCLE if anim == "shovel" else randf_range(2.2, 3.2) if work == "manning" else 2.0
	Sfx.play(name, position, -6.0 if work == "manning" else -3.0)
	if kind == "labourer" and name == "work/crown_build" and BUILD_SWING.has(anim_dir):
		_lab_build_t = lab_build_lock(anim_dir)      # (the clip's first big blow lands on a strike)


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
	if Defs.ARMOURED.has(k) or k in ["cannon", "mortar"]:
		d = d.duplicate(true)        # his own: armour (put_on_armour) and drills (Game.apply_drills) change it
	max_hp = d["hp"]
	hp = max_hp
	if k == "powder_wagon":
		supplying = true               # SUPPLY is on from the start (G turns it off)
	if k == "stormcaller":
		charge = float(Defs.STORM["max"]) * 0.5
	elif k == "mist_toad":
		charge = float(Defs.TOAD["start"])
	if Defs.is_worker(k) and d["faction"] == "clockwork":
		wind = randf_range(0.6, 1.0)     # (Winders don't all stop to wind at once)
	_pmax = max_powder()
	powder = _pmax
	pistol = has_pistol()            # (trained loaded)
	auto_repair = k == "winder"      # (Winders always did; Labourers start with it off)
	armor = d["armor"]
	sight = d["sight"]
	radius = d["radius"]
	speed = d["speed"]
	position = pos
	last_pos = pos
	leash_from = pos
	art = k
	if ArtData.UNITS.has(Defs.art_for(k, false)):
		art = Defs.art_for(k, false)      # (the Horseman: the Cuirassier's sprites once armoured; TEMP_ART)
	if HorseCoat.has_horse(k):
		coat = HorseCoat.pick()


func _ready() -> void:
	_sep_n = get_instance_id() % 3
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.material = team_material()
	add_child(sprite)
	if d["faction"] == "crown" or coat != "":
		# each strip of the horse's sprites has its own coat mask (any Crown man may get a horse)
		sprite.texture_changed.connect(func() -> void: HorseCoat.update_mask(self))
		HorseCoat.apply(self)
	if VetLook.style_of(self) > 0:
		# veterancy on the sprite: each strip has its own trim or skin mask
		sprite.texture_changed.connect(func() -> void: VetLook.update_mask(self))
		VetLook.apply(self)
	_apply_tint()
	if kind == "horse":
		_rein = Node2D.new()
		_rein.draw.connect(_draw_rein)
		add_child(_rein)
	_update_feather()
	if kind == "cannon" and not ArtData.UNITS["cannon"]["frames"].has("walk_e"):
		_make_wheel()
	if kind == "balloon" and ArtData.UNITS.has(kind):
		# layered: the envelope and rigging, the basket with its pilot, the men it carries,
		# then the basket's front wall over their legs
		_pilot_spr = Sprite2D.new()
		_pilot_spr.centered = false
		_pilot_spr.use_parent_material = true
		sprite.add_child(_pilot_spr)
		_pilot_fig = Sprite2D.new()
		_pilot_fig.centered = false
		_pilot_fig.use_parent_material = true
		sprite.add_child(_pilot_fig)
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
		# the haul rope runs from the pilot's hand over the front rim: drawn over all of it
		_haul_node = Node2D.new()
		_haul_node.draw.connect(_on_haul_draw)
		add_child(_haul_node)
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
	# flyers are drawn hovering 20 px up: shots and zaps go to where they're seen (the Swift's and the Owl's bodies: Defs.FLYER)
	if Defs.FLYER.has(kind):
		return global_position + Vector2(0, -float(Defs.FLYER[kind]["centre"]) + float(Defs.FLYER[kind]["lift"]) * _low)
	return global_position + Vector2(0, -32 if is_air() else -12)


# ------------------------------------------------------------------ orders

func cmd_move(p: Vector2, attack_move := false) -> void:
	if Defs.cw_roster and CwUnits.hooked(kind):
		if CwUnits.order_follow(self, p, attack_move):
			return
		p = CwUnits.order_point(self, p)
	if aboard:
		return      # riding in a balloon
	if _ai_keeps_windup():
		return
	if not can_roll():
		if team == game.human:
			game.notify("No horse: HARNESS one to move it.")
		return
	# a Dragoon fighting on foot gets back on his horse to move (not with the enemy in range
	# on an attack-move: he goes on shooting)
	if auto_mount and Defs.MOUNTS.has(kind) and order != "mount" and (not attack_move or _musket_target(_range()) == null):
		if _try_remount({"o": "amove" if attack_move else "move", "p": p}):
			return
	if braced:
		set_brace(false)     # a Bulwark lifts its shield to walk
	_reset_work()
	order = "amove" if attack_move else "move"
	war = attack_move and is_worker()
	if kind == "dragoon" and attack_move:
		order = "d_amove"       # rides on, dismounting to shoot what comes in range
	order_point = p
	target = null
	order_target = null
	_request_path(p)


func cmd_attack(e: Entity) -> void:
	if Defs.cw_roster and not CwUnits.target_ok(self, e):
		return
	if aboard:
		return      # riding in a balloon
	if _ai_keeps_windup():
		return
	if braced and e.edge_distance(position) > _range() + radius:
		set_brace(false)     # out of the lance's reach: it lifts the shield and goes
	if auto_mount and Defs.MOUNTS.has(kind) and order != "mount" and e.edge_distance(position) - radius > _range() + 60.0:
		if _try_remount({"o": "attack", "e": e}):
			return
	_reset_work()
	order = "attack"
	war = is_worker()
	if kind == "dragoon":
		order = "d_attack"      # rides up to musket range, dismounts and fires
		order_target = e
		target = null
		return
	order_target = e
	target = e
	_detour = null
	_wall_look_t = 0.0


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
	if game.net_forward(self, "cmd_deploy", []): return
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
	return int(e.d["supply"]) >= int(Defs.TONGUE["heavy"]) or e.has_tag("massive")


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
	if game.net_forward(self, "cmd_pack", []): return
	if not harnessed and Defs.HARNESSED.has(kind):
		if team == game.human:
			game.notify("No horse to limber up: HARNESS one first.")
		return
	if deploys() and tesla_mode == "deployed":
		tesla_mode = "packing"
		tesla_t = switch_time()


## Follow one of ours (a rally on a unit, as in StarCraft 2): keeps a couple of steps behind
## it wherever it goes; when it's gone he stops where he is.
func cmd_follow(e: Unit) -> void:
	if aboard or e == self:
		return
	_reset_work()
	order = "follow"
	order_target = e
	target = null


## PATROL (as in StarCraft 2): attack-move to `p`, then back to where he started, and on
## like that until given another order (fighting whatever comes on the way, then going on).
func cmd_patrol(p: Vector2) -> void:
	var from := plan_end() if not queue.is_empty() else position
	cmd_move(p, fights_on_command())
	if order == "move" or order == "amove" or order == "d_amove":
		patrol_a = from
		patrol_b = p


# ------------------------------------------------------------------ FIRE AT A SPOT (BOMBARD; Defs.BOMBARD)

var _bombard_n := 0             # shots fired at the BOMBARD spot so far (orders Shift-queued behind it wait for Defs.BOMBARD.queued)


## Can it fire at a spot on the ground? (An area weapon: the Defs.BOMBARD kinds; not from a balloon's basket.)
func can_bombard() -> bool:
	return (Defs.BOMBARD["kinds"] as Array).has(kind) and not dead and aboard == null


## BOMBARD (as in Total Annihilation): walk into range of the spot `p`, set up there (a gun unlimbers, a Mortar deploys, a
## Spore Mother roots) and keep firing at it, into the fog too, until another order. Out of shot it waits there (a Powder
## Wagon nearby fills it up again and it goes on). It fires at nothing else meanwhile.
func cmd_bombard(p: Vector2) -> void:
	if not can_bombard():
		return
	_reset_work()
	order = "bombard"
	order_point = p
	target = null
	order_target = null
	_bombard_n = 0
	leash_from = position


## The BOMBARD order, every tick: into range (packing up to move, backing off if too close), set up, fire.
func _bombard(delta: float) -> Vector2:
	var p := order_point
	var dist := position.distance_to(p) - radius
	var rng := _range()
	var min_r := 0.0 if mode == "canister" else float(d.get("min_range", 0.0))
	if phase != "" or (dist <= rng and dist >= min_r):
		path = PackedVector2Array()
		if deploys() and tesla_mode != "deployed":
			if tesla_mode == "packed":
				tesla_mode = "deploying"
				tesla_t = switch_time()
			return Vector2.ZERO          # (setting up)
		_bombard_cycle(delta)
		return Vector2.ZERO
	if deploys() and tesla_mode != "packed":
		if tesla_mode == "deployed":
			tesla_mode = "packing"       # out of range: pack up to move
			tesla_t = switch_time()
		return Vector2.ZERO
	if dist < min_r:
		return (position - p).normalized() * speed      # too close (a Mortar's least range): back off
	if (path.is_empty() or path_i >= path.size()) and not path_pending or repath_t <= 0.0:
		repath_t = 1.5
		_request_path(p)
	return _follow(delta)


## Aim, fire at the spot, reload (as _attack_cycle does for a target). No HOLD FIRE or own-men check: it was ordered.
func _bombard_cycle(delta: float) -> void:
	var p := order_point
	if p.distance_to(position) > 2.0:
		facing = (p - position).normalized()
	if phase == "":
		if cooldown > 0.0 or stun_t > 0.0:
			return
		if _pmax > 0.0 and powder < 1.0:
			cooldown = 0.5               # out of shot: it waits for powder (a Powder Wagon, a Mill...)
			if Time.get_ticks_msec() > _hold_note:
				_hold_note = Time.get_ticks_msec() + 5000
				game.out_of_powder(self)
			return
		phase = "aim"
		phase_t = _aim()
		return
	phase_t -= delta
	if phase == "aim" and phase_t <= 0.0:
		phase = "strike"
		phase_t = _strike_time()
		_fire_at_spot(p)
	elif phase == "strike" and phase_t <= 0.0:
		phase = ""
		cooldown = _cooldown()
		if not queue.is_empty() and _bombard_n >= int(Defs.BOMBARD["queued"]):
			_next_order()                # (Shift-queued orders behind it: on to the next after its few shots)


## One shot at the spot (Game.bombard_shot): it spends a shot of powder; in a fog bank it lands wide half the time.
func _fire_at_spot(p: Vector2) -> void:
	var dmg := float(d["damage"]) * (1.0 + minf(kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"])))
	if _pmax > 0.0:
		if powder < 1.0:
			return
		powder -= 1.0
		if powder < 1.0:
			game.out_of_powder(self)
	_bombard_n += 1
	var wide := Vector2.ZERO
	if not game.zones.is_empty() and (game.in_fog(global_position) or game.in_fog(p)) and randf() < float(Defs.FOG["miss"]):
		wide = Vector2.from_angle(randf() * TAU) * randf_range(55.0, 95.0)
	game.bombard_shot(self, p + wide, dmg)


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
	if is_mounted():
		# (a Mounted Missionary gets off to raise the fallen, and stays on foot; the body is
		# his meanwhile)
		if order != "dismount":
			cmd_dismount(false, {"o": "revive", "e": body})
			_body = body
			body.reviver = self
		return
	_reset_work()
	order = "revive"
	_body = body
	body.reviver = self
	target = null
	order_target = null


func cmd_stop() -> void:
	if game.net_forward(self, "cmd_stop", []): return
	_reset_work()
	order = "idle"
	target = null
	order_target = null
	path = PackedVector2Array()
	leash_from = position


func cmd_hold() -> void:
	if aboard:
		return      # riding in a balloon
	if kind == "dragoon":
		cmd_dismount(true, {"o": "hold"})      # a Dragoon holds on foot
		return
	cmd_stop()
	order = "hold"


## Go and work at an economy structure (Farm, Powder Mill, Feeding Pit, Boiler).
func cmd_gather(site: Entity) -> void:
	if game.net_forward(self, "cmd_gather", [site]): return
	if aboard:
		return      # riding in a balloon
	if not can_gather() or not (site is Building):
		cmd_move(site.center())
		return
	var b := site as Building
	if b.team != team or (b.crew_max() == 0 and b.haul_cap() == 0) or (b.haul_cap() > 0 and not can_haul()):
		cmd_move(site.center())
		return
	if b.haul_cap() > 0 and not b.crew.has(self) and b.haulers().size() >= b.haul_cap():
		# (a Town Hall with all its haulers: the worker stands by it)
		if team == game.human:
			game.notify("That Town Hall has all its haulers.")
		cmd_move(b.center())
		return
	if b.barren():
		# spent land takes no crew (Unit._gather would let him go at once, leaving idle
		# workers under a "0/5" that looks like room): the nearest fresh site instead
		var fresh := game.free_site(team, b.center())
		if fresh == null:
			if team == game.human:
				game.notify("That %s's ground is spent: it yields nothing. Work fresh land." % b.d["name"])
			cmd_move(b.center())
			return
		b = fresh
	if not b.crew.has(self) and b.crew.size() >= b.crew_max():
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
		return e.is_unit() and (e as Unit).d["faction"] == "clockwork" or e.is_building() or e is PipeSeg
	if kind == "labourer":
		return e.is_building() or (e is Unit and Defs.CROWN_MACHINES.has(e.kind))
	return false


func cmd_repair(e: Entity) -> void:
	if aboard:
		return      # riding in a balloon
	if not can_repair(e):
		return
	if e is PipeSeg and not e.built:
		return LineWork.cmd_lay(self, e)
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
## (BOMBARD never ends by itself: with orders queued behind it, it hands over after Defs.BOMBARD.queued shots.)
const QUEUE_BUSY := ["move", "amove", "attack", "build", "repair", "d_amove", "d_attack", "lead", "mount", "dismount", "bombard"]


## Give an order ({"o": move/amove/attack/build/repair/gather/wall, "p", "e", "pieces"}): a
## plain one now (it clears the queue), a queued one (Shift) after the orders before it.
func give(o: Dictionary, queued := false) -> void:
	if game.net_forward(self, "give", [o, queued]): return
	if not queued:
		queue.clear()
		line_rest.clear()
		if String(o.get("o", "")) != "patrol":
			patrol_a = Vector2.INF       # a new order ends a patrol
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
			cmd_move(o["p"], o["o"] == "amove" and fights_on_command())
		"patrol":
			cmd_patrol(o["p"])
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
		"hold":
			cmd_hold()
		"act":
			# an instant command card button queued with Shift (release horse, harness...)
			(o["fn"] as Callable).call(self)
			return order != "idle"      # (a command that leaves him idle: on to the next queued order)
		"lead":
			if e == null or not is_instance_valid(e) or not cmd_lead(e):
				return false
		"mount":
			if e == null or not is_instance_valid(e) or not cmd_mount(e):
				return false
		"revive":
			if e == null or not is_instance_valid(e):
				return false
			cmd_revive(e)
		"heal":
			if e == null or not is_instance_valid(e) or not (e is Unit):
				return false
			cmd_heal(e)
		"follow":
			if e == null or not is_instance_valid(e) or not (e is Unit) or e.dead:
				return false
			cmd_follow(e)
		"bombard":
			cmd_bombard(o["p"])
	return order != "idle"


static func _spot(e: Entity) -> Vector2:
	return e.global_position if e is Unit else e.center()


## Where this unit is going, in order: [kind, point] for its current order and everything
## queued behind it (for the waypoint lines drawn for your selection).
func plan_points() -> Array:
	var pts: Array = []
	if order == "move" or order == "amove" or order == "d_amove" or order == "bombard":
		pts.append(["amove" if order == "d_amove" else order, order_point])
	elif (order == "attack" or order == "build" or order == "repair" or order == "gather") \
			and order_target and is_instance_valid(order_target) and not order_target.dead:
		pts.append([order, _spot(order_target)])
	for b in line_rest:
		if is_instance_valid(b) and not b.dead:
			pts.append(["build", b.center()])
	for o in queue:
		var e = o.get("e")
		match String(o["o"]):
			"move", "amove", "bombard":
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
	war = false
	if not _keep_queue:
		queue.clear()          # a new order (not Shift-queued) replaces the queue
		line_rest.clear()
	if tongue_stage == "windup":
		_break_tongue()        # a new order: the Toad lets its mark go
	if _corpse and is_instance_valid(_corpse):
		_corpse.harvester = null
	_corpse = null
	_drop_body()
	_haul_abort()
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
	if (order == "mount" or order == "lead") and order_target is Unit and is_instance_valid(order_target) and order_target.claimed == self:
		order_target.claimed = null    # (he isn't coming for that horse any more)
	if not _keep_queue:
		after = {}
	_care_auto = false
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
	u.release_horses()
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


## Every man in the basket gets off onto open ground near `at`. `fall`: the balloon was shot
## down, so nobody gets off: each rolls his fall (Defs.FALL_ODDS: bruised, hurt, crippled or dead; a body on the nearest open ground,
## spread round the wreck (the Brood can harvest it, a Missionary raise a Crown soldier).
func drop_passengers(at: Vector2, fall := false) -> void:
	var list := passengers.duplicate()
	passengers.clear()
	var spots := game.drop_spots(at, list.size(), team)
	var n := 0
	var survived := 0
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
		u.facing = Vector2.DOWN
		if fall:
			# the fall is a roll: unhurt-ish, yellow health, red health, or dead (the kill is credited
			# to whoever shot the balloon; die() clears what he was doing)
			var roll := randf()
			var left := 0.0
			for o in Defs.FALL_ODDS:
				roll -= float(o[0])
				if roll <= 0.0:
					left = randf_range(float(o[1][0]), float(o[1][1]))
					break
			if left <= 0.0:
				u.last_hit_by = last_hit_by
				u.last_hit_team = last_hit_team
				u.last_hitter = last_hitter
				u.hp = 0.0
				u.die()
			else:
				u.hp = maxf(1.0, u.max_hp * left)
				u.cmd_stop()
				survived += 1
				game.float_text(u.position + Vector2(0, -24), "survived the fall", Color(1, 0.85, 0.5))
			continue
		u.cmd_stop()
		var fx := game.spawn_effect("dust", u.position, 1.6)
		fx.scale = Vector2(0.4, 0.4)
	if fall and n > 0 and game.mlog:
		game.mlog.add("%s's balloon was shot down: %d fell, %d survived the fall" % [game.mlog.who(team), n, survived])
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
	if game.net_forward(self, "cmd_land", []): return
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
	if game.net_forward(self, "cmd_take_off", []): return
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
	if game.puppet:
		return NetPuppet.tick_unit(self, delta)      # (online guest: shown from snapshots, not simulated)
	var _p0 := Time.get_ticks_usec()
	_tick_unit(delta)
	Prof.unit_us += Time.get_ticks_usec() - _p0
	Prof.unit_n += 1


func _tick_unit(delta: float) -> void:
	_process_flash(delta)
	if off_field:
		return
	if not dead and work != "":
		_work_sound(delta)
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
	if kind != "dragoon":
		cooldown = maxf(cooldown - delta, 0.0)     # (a Dragoon's reload waits while he rides)
	spell_cd = maxf(spell_cd - delta, 0.0)
	jump_cd = maxf(jump_cd - delta, 0.0)
	if _pmax > 0.0:
		_powder_tick(delta)
	if kind == "cuirassier" and game.has_tech(team, "charge"):
		# (drilled: Cavalry Charge) a gallop builds up to a charge; standing about loses it
		if velocity.length() > speed * 0.7:
			run_t += delta
		elif phase == "":
			run_t = maxf(run_t - delta * 3.0, 0.0)
	stun_t = maxf(stun_t - delta, 0.0)
	net_t = maxf(net_t - delta, 0.0)      # (caught in a net: its stun_t holds it meanwhile)
	held_t = maxf(held_t - delta, 0.0)
	scan_t -= delta
	_wall_watch(delta)
	repath_t -= delta
	sky_cd = maxf(sky_cd - delta, 0.0)
	_courier_t -= delta
	var want := Vector2.ZERO
	# Brood on swamp: faster, and wounds close up.
	speed = float(d["speed"])
	if kind == "horse" or horse_working():
		_horse_upkeep(delta)
	if not team_horses.is_empty():
		speed *= 1.0 + float(Defs.HORSES["team_speed"]) * team_horses.size()     # a bigger team pulls faster
	if horse_rid != 0 and Defs.RIDERS.values().has(kind):
		_res_t -= delta
		if _res_t <= 0.0:
			_res_t = 0.5
			_wait_horse()
	if slow_t > 0.0:
		slow_t -= delta
		speed *= float(Defs.BLOAT["slow"])
	if Defs.cw_roster and CwUnits.hooked(kind):
		CwUnits.pre_tick(self, delta)
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

	if not jump.is_empty():
		# a Jack's leap: the crouch, the flight along its arc, the landing (scripts/jack.gd); no walking or fighting
		# meanwhile (orders given now are taken up once it has landed)
		Jack.tick(self, delta)
		_animate(delta)
		if visible and game.view_rect.has_point(position):
			queue_redraw()       # (its shadow shrinks as it rises)
		return
	if owl_t >= 0.0:
		# a Swift turning into a Ticking Owl: it hovers where it is (scripts/cw_air.gd); it cannot move or fight meanwhile
		CwAir.morph_tick(self, delta)
		_animate(delta)
		if visible and game.view_rect.has_point(position):
			queue_redraw()       # (the clock hand and the bar)
		return
	if kind == Defs.JACK and jump_cd <= 0.0:
		_jack_t -= delta
		if _jack_t <= 0.0:
			_jack_t = 0.3
			if game.ais.any(func(a) -> bool: return a.team == team):
				Jack.ai_tick(self)      # (the computer's: low and in a melee, it jumps away)
				if not jump.is_empty():
					return
	if kind == "skywing" and sky != "air" and sky != "ground":
		# landing or taking off: it can't do anything else meanwhile
		_move(_sky_switch(delta), delta)
		_animate(delta)
		return
	if foot_musket():
		_pick_weapon(delta)
	elif has_pistol():
		_pistol_reload(delta)
		_pick_pistol()
	if target and not _valid_target(target):
		target = null
		phase = ""
	if order == "idle" and not queue.is_empty():
		_next_order()
	if auto_mount and Defs.MOUNTS.has(kind):
		_foot_dragoon(delta)
	if not led.is_empty():
		_prune_led()
	match order:
		"idle":
			if d.get("medic", false) and scan_t <= 0.0:
				# the fallen first (a soldier back), then the wounded: Defs.CARE
				scan_t = float(Defs.CARE["rescan"])
				var body := game.find_body(self, float(Defs.REVIVE["scan"]) * Defs.TILE)
				if body:
					cmd_revive(body)
				else:
					var pt := game.find_patient(self, 9 * Defs.TILE)
					if pt:
						cmd_heal(pt)
						_care_auto = true      # (his own choice: he may change his mind for a body)
			# REPAIR autocast: an idle worker fixes what's damaged nearby (before going back to
			# work, when WORK is on too)
			if auto_repair and not war and scan_t <= 0.0 and (kind == "winder" or kind == "labourer"):
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
			if is_worker() and auto_work and not war and order == "idle" and scan_t <= 0.0:
				scan_t = 1.5
				var post := game.free_site(team, position)
				if post:
					cmd_gather(post)
			# COURIER: an idle Ornithopter fetches batteries and winds up constructs
			if kind == "ornithopter" and courier and _courier_t <= 0.0 and order == "idle":
				_courier_t = 1.0
				if _courier_scan():
					return
			if (not is_worker() or war) and scan_t <= 0.0:
				scan_t = 0.35
				target = _pick_target(_scan_range())
				if target == null:
					war = false           # nobody left in sight: back to work
			_walled_check(delta)
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
				if better and better != target and not (better is Building and (better.kind == "wall" or better.kind == "gate")) and _can_get_at(better):
					target = better
			# hitting a building (or a man who can't fight back): an enemy unit that comes in
			# reach comes first (as in StarCraft 2: fighters, then other units, then buildings)
			elif is_instance_valid(target) and scan_t <= 0.0 and phase == "" and (target is Building or not Game.fights_back(target)):
				scan_t = 0.5
				var better := game.find_target(self, _scan_range())
				if better and better != target and better.is_unit() and Game.loose_horse(better) == false \
						and (target is Building or Game.fights_back(better)) and _can_get_at(better):
					target = better
			if scan_t <= 0.0 and target == null and fights_on_command():
				scan_t = 0.3
				target = _pick_target(_scan_range())
			_walled_check(delta)
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
				target = _attack_detour(delta)
				want = _engage(target, delta, true)
		"gather":
			want = _gather(delta)
		"repair":
			want = _repair(delta)
		"follow":
			var fe = order_target
			if fe == null or not is_instance_valid(fe) or fe.dead or (fe as Unit).aboard != null:
				cmd_stop()
			elif position.distance_to(fe.position) > radius + fe.radius + 26.0:
				want = _walk_to(fe.position, delta)
			else:
				path = PackedVector2Array()
		"heal":
			# on his way to a patient he looks again now and then: a body to raise comes first
			if _care_auto and work != "bandaging" and scan_t <= 0.0:
				scan_t = float(Defs.CARE["rescan"])
				var body := game.find_body(self, float(Defs.REVIVE["scan"]) * Defs.TILE)
				if body:
					cmd_revive(body)
			if order == "heal":
				want = _heal(delta)
		"revive":
			want = _revive(delta)
		"build":
			want = _build(delta)
		"lay":
			want = LineWork.tick(self, delta)
		"cast":
			want = _cast(delta)
		"tongue":
			want = _tongue_order(delta)
		"bombard":
			want = _bombard(delta)
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
		"refit":
			want = _refit_run(delta)
		"sacrifice":
			want = _sacrifice(delta)
		"d_attack", "d_amove":
			want = _dragoon_tick(delta)
		"mount":
			want = _mount_run(delta)
		"dismount":
			want = _dismount_run(delta)
		"lead":
			want = _lead_run(delta)
	if kind == "horse":
		want = _horse_tick(delta, want)
	if deploys():
		want = _tesla(want, delta)
	if not can_roll():
		want = Vector2.ZERO        # a gun or wagon without its horse stands where it is
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
	if Defs.cw_roster and CwUnits.hooked(kind):
		want = CwUnits.steer(self, want, delta)
	_move(want, delta)
	if Defs.cw_roster and CwUnits.hooked(kind):
		CwUnits.post_move(self)
	_animate(delta)
	if kind == "winder" and (crate_site or _crate_spr):
		_update_crate_spr()
	# redraw the shadow, ring and bars only when something on them changed (off screen: not
	# looked at; it's drawn afresh when it comes into view)
	if not visible or not game.view_rect.has_point(position):
		_draw_key = Vector4i(-1, -1, -1, -1)
	else:
		var extra := 0
		if topter_bat != "":
			extra += 500000 + (int(_bob_t * 10.0) % 13) * 1000
		if overclock_t > 0.0:
			extra += int(overclock_t * 8.0) * 1000000
		if kind == "balloon":
			extra += passengers.size() * 100000 + (int(haul_t * 30.0) + 1) * 1000
		var key := Vector4i(int(selected) + (2 if carrying > 0 else 0) + (4 if cross_t > 0.0 else 0) + (8 if work == "feeding" else 0) + (16 if carry_empty else 0) + (32 if cocoon > 0 else 0) + kills * 64,
			int(hp) + int(gas) * 10000, int(wind * 40.0) + (int(carry_t * 4.0) * 100 if carrying > 0 else 0) if d["faction"] == "clockwork" else int(powder * 2.0) + (1000 if supplying else 0),
			int(max_hp) + extra + (int(reload_frac() * 16.0) + 17 * int(tesla_t * 4.0) + 850 * TESLA_MODES.find(tesla_mode)) * 10000 if has_attack() else int(max_hp) + extra)
		if key != _draw_key:
			_draw_key = key
			queue_redraw()
		elif selected and (kind == "cannon" or kind == "mortar") and team == game.human:
			# its line of fire on the ground follows the aim and the men around: ten times a second
			_aim_t -= delta
			if _aim_t <= 0.0:
				_aim_t = 0.1
				queue_redraw()


const TESLA_MODES := ["packed", "deploying", "deployed", "packing"]


## Tesla Cart: it only rolls when packed and only zaps when deployed; switching takes a while.
func _tesla(want: Vector2, delta: float) -> Vector2:
	if not harnessed and Defs.HARNESSED.has(kind):
		# no horse: straight to the set-up pose, and it stays set up
		if tesla_mode != "deployed":
			tesla_mode = "deployed"
			tesla_t = 0.0
		return Vector2.ZERO
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
	if patrol_a != Vector2.INF and queue.is_empty():
		# patrolling: turn round and go back the other way
		var back := patrol_a
		patrol_a = patrol_b
		patrol_b = back
		var keep_a := patrol_a
		cmd_move(back, fights_on_command())
		patrol_a = keep_a
		patrol_b = back
		return
	order = "idle"
	path = PackedVector2Array()
	leash_from = position
	if not queue.is_empty():
		_next_order()


func _valid_target(e: Entity) -> bool:
	return is_instance_valid(e) and not e.dead and e.is_inside_tree() and game.prey(team, e) and can_hit(e)


## How far this unit looks for targets: its sight, or for a cannon its full range (it
## can shoot what any friendly unit sees).
func _scan_range() -> float:
	if kind == "cannon" or kind == "mortar":
		return maxf(sight * Defs.TILE, _range())
	return sight * Defs.TILE


func _range() -> float:
	if kind == "rail_rifleman":
		return CwUnits.range_of(self)
	if kind == Defs.OWL and target is Building:
		return float(Defs.OWL_BOMB["range"])     # (the bomb: it comes right up to the building's edge to let it fall)
	if kind == "bloater":
		# holding its gas, or about to pop anyway: it goes in to burst (out of gas it
		# deflates instead, and can't attack at all until it has filled up again)
		if mode == "hold" or hp < max_hp * 0.35:
			return float(Defs.BLOAT["reach"])
	if mode == "bayonet":
		return Defs.BAYONET["range"]
	if mode == "canister":
		return Defs.CANISTER["range"]
	if mode == "pistol":
		return float(Defs.PISTOL["range"])
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
	if Defs.cw_roster and CwUnits.on(kind) and CwUnits.plan_path(self, goal):
		return
	path_pending = true
	game.queue_path(self)


## Called by Game when this unit's turn in the path queue comes up.
func compute_path() -> void:
	path_pending = false
	if path_goal == Vector2.INF:
		return
	# the enemy's gates are shut to us: the path goes round (or, walled out, up to the wall
	# to break it), never into a gate it can't open
	var shut := _shut_gates()
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
	_open_gates(shut)


## The pathfinder counts every gate as open (it opens for its own side): while it works out
## this unit's way, the gates of its enemies are shut (then opened again).
func _shut_gates() -> Array:
	var out: Array = []
	if is_air() or game.gate_team.is_empty():
		return out
	for i in game.gate_team:
		if game.solid[i] == 3 and game.hostile(int(game.gate_team[i]), team):
			var c := Vector2i(int(i) % Game.W, int(i) / Game.W)
			game.astar.set_point_solid(c, true)
			out.append(c)
	return out


func _open_gates(cells: Array) -> void:
	for c in cells:
		game.astar.set_point_solid(c, false)


## Can it walk up to `e` (its enemies' gates shut)?
func _walk_reaches(e: Entity) -> bool:
	return _walk_reaches_point(e.position if e.is_unit() else e.center())


func _walk_reaches_point(p: Vector2) -> bool:
	var a: Vector2i = game.cell_of(position)
	if not game.open_cell(a):
		a = game.nearest_free(a, 4)
	var b: Vector2i = game.cell_of(p)
	if not game.open_cell(b):
		b = game.nearest_free(b, 3)
	if a.x < 0 or b.x < 0:
		return false
	var shut := _shut_gates()
	var ok: bool = not game.astar.get_id_path(a, b).is_empty()
	_open_gates(shut)
	return ok


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
	# neighbours only nudge each other: a unit on the move works it out every other tick, one
	# standing still every third
	_sep_n += 1
	if _sep_n >= (2 if want != Vector2.ZERO or velocity != Vector2.ZERO else 3):
		_sep_n = 0
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
		if not game.cw_gates.is_empty():
			position = CwUnits.gate_push(self, before, position)     # a Plate Wagon blocks the track
		# A limbered gun: the horses stand a length ahead of the barrel, so their spot must
		# be clear too (they clipped through walls and palisades): slide along it instead
		if (kind == "cannon" or kind == "mortar" or kind == "powder_wagon") and tesla_mode == "packed" and position != before:
			var lead := facing * (radius + 14.0)
			if not game._clear_at(position + lead, radius * 0.9, team):
				var alt_a := Vector2(position.x, before.y)
				var alt_b := Vector2(before.x, position.y)
				if game._clear_at(alt_a + lead, radius * 0.9, team) and game._clear_at(alt_a, radius, team):
					position = alt_a
				elif game._clear_at(alt_b + lead, radius * 0.9, team) and game._clear_at(alt_b, radius, team):
					position = alt_b
				else:
					position = before
	if want.length() > 5.0 and phase == "":
		facing = facing.lerp(want.normalized(), clampf(delta * 10.0, 0.0, 1.0)).normalized()
	# Stuck detection while trying to move
	if want.length() > 5.0:
		if position.distance_to(last_pos) < speed * delta * 0.25:
			stuck_t += delta
		else:
			stuck_t = maxf(stuck_t - delta * 2.0, 0.0)
		# Walled out: hack at the enemy wall or gate in the way.
		# (or chasing a man it can't get at, on the far side of the wall)
		_reach_t -= delta
		if stuck_t > 1.2 and not is_worker() and order in ["amove", "idle", "attack"] and not (order == "attack" and target == order_target) \
				and (target == null or (_reach_t <= 0.0 and not _can_get_at(target))):
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
	siege_t = maxf(siege_t - delta, 0.0)
	_wall_chk -= delta
	if _wall_chk > 0.0 or siege_t > 0.0:
		return                       # (in a siege the army decides together: ai.gd)
	_wall_chk = 0.5
	if target == null or not is_instance_valid(target) or not (target is Building) \
			or not (target.kind == "wall" or target.kind == "gate") or float(d["range"]) > 40.0 or is_worker():
		return
	# (a unit out with an attacking wave leaves it to its army: AI._siege_tick weighs the wall
	# up for all of them at once)
	if not game.ais.any(func(a) -> bool: return a.team == team and not a.in_wave(self)):
		return
	var wall: Building = target
	# the hackers: our melee units going for this wall (any piece of it here), the ones still
	# on their way too: the first two to arrive mustn't judge the breach by themselves alone
	var hackers: Array = []
	for o in game.units_near(wall.center(), 420.0):
		if not o.dead and o.team == team and float(o.d["range"]) <= 40.0 and is_instance_valid(o.target) and o.target is Building \
				and (o.target.kind == "wall" or o.target.kind == "gate") and o.target.center().distance_to(wall.center()) < 100.0:
			hackers.append(o)
	if hackers.is_empty():
		return
	# the shooters that can reach any of them (at the wall)
	var shooters := {}
	for h in hackers:
		if wall.edge_distance(h.position) > 60.0:
			continue
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
		hack_dps += maxf(1.0, float(h.d["damage"]) * float(h.d.get("building_bonus", 1.0)) - wall.armor) / maxf(float(h.d["cooldown"]), 0.1)
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


## Can it fight `e` from here, or walk up to it? A melee unit can't reach a man standing behind
## a wall (it would only push at the wall: it hacks at the wall instead); a gun only
## switches to a target it can already reach (not walking into the choke after it).
func _can_get_at(e: Entity) -> bool:
	if not is_instance_valid(e) or e.dead:
		return false
	if is_air():
		return true
	var gap := e.edge_distance(position) - radius
	if gap <= _range() + 4.0:
		return true
	if float(d["range"]) > 40.0:
		return false
	_reach_t = 0.5
	return game.line_clear(position, e.center()) or _walk_reaches(e)


## A melee unit up against an enemy wall or gate (idle or on an attack-move) that can't get
## at what it's after (the men behind it, or the point it was sent to) breaks the wall. It
## doesn't wait to count as stuck: in a crowd pressed at a wall the shoving keeps every unit
## jostling, so the stuck timer never fills and they'd stand there under fire for good.
func _walled_check(delta: float) -> void:
	_wall_look_t -= delta
	if _wall_look_t > 0.0:
		return
	_wall_look_t = 0.5
	if is_worker() or is_air() or float(d["range"]) > 40.0 or not has_attack() or siege_t > 0.0:
		return                       # (in a siege its army decides which piece, and who hits it)
	if is_instance_valid(target) and target is Building and (target.kind == "wall" or target.kind == "gate"):
		return
	var near := game.blocking_wall(self)
	if near == null:
		return
	if is_instance_valid(target) and not target.dead:
		if _can_get_at(target):
			return
		var w := _wall_toward(target)
		target = w if w else near
	elif order == "amove" and not _walk_reaches_point(order_point):
		target = near


## Told to attack a man it can't walk up to (behind an enemy wall or shut gate): once at the
## wall it breaks the piece in the way, then goes on after him (the order stands).
func _attack_detour(delta: float) -> Entity:
	if is_air() or is_worker() or float(d["range"]) > 40.0 or not has_attack() or not order_target.is_unit():
		return order_target
	if is_instance_valid(_detour) and not _detour.dead:
		return _detour
	_detour = null
	_wall_look_t -= delta
	if _wall_look_t > 0.0:
		return order_target
	# (at a wall it asks twice a second; out in the open, on the way, once every 1.5 s)
	var at_wall := game.blocking_wall(self) != null
	_wall_look_t = 0.5 if at_wall else 1.5
	if not at_wall and not _any_enemy_wall():
		return order_target
	if _can_get_at(order_target):
		return order_target
	_detour = _wall_toward(order_target)
	return _detour if _detour else order_target


func _any_enemy_wall() -> bool:
	for b in game.buildings:
		if not b.dead and b.built and (b.kind == "wall" or b.kind == "gate") and game.hostile(b.team, team):
			return true
	return false


## Target search for units on their own (idle, attack-move): a melee unit that can't walk up
## to what it sees (men standing behind a wall or a shut gate) goes for the wall or gate in
## the way instead, rather than pushing at the wall trying to reach them.
func _pick_target(r: float) -> Entity:
	if kind == Defs.NETTER:
		return Netter.pick(self, r)      # (the most dangerous enemy not caught already: scripts/netter.gd)
	var e := game.find_target(self, r)
	if e == null or is_air() or float(d["range"]) > 40.0 or not e.is_unit() or _can_get_at(e):
		return e
	if siege_t > 0.0:
		return null                  # (waiting in a siege's reserve: the army sends it to the wall)
	var w := _wall_toward(e)
	return w if w else e


## The enemy wall or gate piece to break to get at `e`: of the pieces in sight it can walk
## up to, the one most on the way (it's beside the unit, or the shortest way round to e).
func _wall_toward(e: Entity) -> Building:
	var near := game.blocking_wall(self)
	if near:
		return near
	var best: Building = null
	var bd := INF
	var reach := sight * Defs.TILE
	var shut := _shut_gates()
	var a: Vector2i = game.cell_of(position)
	if not game.open_cell(a):
		a = game.nearest_free(a, 4)
	for b in game.buildings:
		if b.dead or not b.built or not (b.kind == "wall" or b.kind == "gate") or not game.hostile(b.team, team):
			continue
		var dd: float = b.edge_distance(position)
		if dd > reach or not can_hit(b):
			continue
		var score: float = dd + b.center().distance_to(e.position) * 1.5
		if score >= bd:
			continue
		# it must be able to walk up to that piece (a free cell beside it it can reach)
		var ok := false
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = b.cell + dv
			if game.open_cell(c) and a.x >= 0 and not game.astar.get_id_path(a, c).is_empty():
				ok = true
				break
		if ok:
			bd = score
			best = b
	_open_gates(shut)
	return best


## Move toward and fight a target. Returns the desired velocity.
func _engage(e: Entity, delta: float, may_move: bool) -> Vector2:
	if braced:
		may_move = false           # a planted Bulwark only pokes at what comes in reach
	var dist := e.edge_distance(position) - radius
	var rng := _range()
	var min_r := 0.0 if mode == "canister" else float(d.get("min_range", 0.0))
	if deploys() and tesla_mode != "deployed":
		if tesla_mode == "packed" and dist <= rng and dist >= min_r and game.target_seen(team, e, position):
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
	# no shooting into the dark: a target your side can't see (up a cliff, in the fog) is
	# only fired on once someone sees it; until then the unit closes in (or waits, holding)
	var seen := dist <= 24.0 or game.target_seen(team, e, position)
	if dist <= rng and dist >= min_r and seen:
		path = PackedVector2Array()
		_attack_cycle(e, delta)
		return Vector2.ZERO
	if not seen and dist <= rng and target == e and order != "attack":
		target = null                  # (picked on its own: let it go, look for another)
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
	elif Defs.FLYER.has(kind):
		# (the Swift and the Owl turn to face it on the ground plane: their bodies sit high over their shadows)
		var gp: Vector2 = e.position if e is Unit else e.rect().get_center()
		if gp.distance_to(position) > 2.0:
			facing = (gp - position).normalized()
	else:
		facing = (e.center() - center()).normalized()
	if phase == "":
		if cooldown > 0.0 or stun_t > 0.0:
			return
		# HOLD FIRE: no shot of his own (a target picked by himself is let go)
		if _fire_held(e) and not has_pistol():
			cooldown = 0.3
			if target == e and order != "attack":
				target = null
			return
		# out of powder: a gun can't fire (a dry Musketeer has fixed bayonets instead)
		if _pmax > 0.0 and mode != "bayonet" and powder < 1.0 and not has_pistol():
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
		_owl_bomb = kind == Defs.OWL and e is Building      # (the Owl: a bomb on a building, the talons on a unit)
		phase = "aim"
		phase_t = _aim()
		return
	phase_t -= delta
	if phase == "aim" and mode == "pistol" and (not pistol or hold_fire):
		phase = ""               # (HOLD FIRE came on while he aimed: no shot)
		return
	if phase == "aim" and _fire_held(e):
		phase = ""               # (HOLD FIRE: no shot)
		cooldown = maxf(cooldown, 0.3)
		return
	if phase == "aim" and phase_t <= 0.0:
		phase = "strike"
		phase_t = _strike_time()
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
	if Defs.cw_roster and CwUnits.on(kind) and CwUnits.strike(self, e, dmg):
		return
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
		var bd := float(Defs.BAYONET["damage"]) + (float(Defs.RESEARCH["bayonet"]["damage"]) if bayonet else 0.0)
		if d.has("sabre"):
			bd = float(d["sabre"]["damage"])           # a dismounted horseman's sabre
		e.take_damage(bd * vet * float(Defs.BAYONET["bonus"].get(e.kind, 1.0)), self, BLOW_MELEE)
		Sfx.play_any(["combat/pikeman_attack", "clash"], position)
		game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.6)
		return
	if mode == "pistol":
		# the pistol's one shot (spent even if it flies wide in a fog)
		if not pistol:
			return
		pistol = false
		pistol_t = 0.0
		var vet2 := 1.0 + minf(kills * float(Defs.VET["per_kill"]), float(Defs.VET["max"]))
		if _range() >= 100.0 and game.fog_blinds(self, e) and randf() < float(Defs.FOG["miss"]):
			game.fog_miss(self, e)
			return
		game.note_shot(self, e)
		game.pistol_shot(self, e, float(Defs.PISTOL["damage"]) * vet2)
		return
	# every musket or cannon shot uses one of the shots it carries
	if _pmax > 0.0 and not has_pistol():
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
	if mode != "bayonet" and _range() >= 100.0:
		game.note_shot(self, e)
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
				e.take_damage(dmg, self, BLOW_RANGED)
				var s := Shot.new()
				s.scale = Vector2(0.5, 0.6)
				s.impact = "hit"
				s.impact_scale = 0.6
				s.launch(game, "bolt" if ArtData.EFFECTS.has("bolt") else "acid_ball", center() + facing * 10.0, e.center(), 700.0)
			else:
				e.take_damage(dmg, self, BLOW_BROOD)      # (landed: its bite)
				game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.6)
			Sfx.play_any(["combat/skywing_attack", "bite"], position)
		"jack":
			Jack.shoot(self, e, dmg)       # (a spinning screw from the drill tip, ground or air)
		"pendulum":
			Pendulum.swing(self, e, dmg)   # (the blade through every enemy in the arc in front: scripts/pendulum.gd)
		"netter":
			Netter.fire(self, e)           # (the chain net flies; it catches its target where it lands: scripts/netter.gd)
		"ticking_owl":
			if e is Building:
				CwAir.drop_bomb(self, e)       # (the weight falls onto it: the damage is the bomb's, where it lands)
			else:
				e.take_damage(dmg, self, BLOW_MELEE)      # the talons, swooping down
				game.spawn_effect("hit", e.center() + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.7)
				Sfx.play_any(["combat/ticking_owl_attack", "clash"], position)
		"ornithopter":
			if e.is_air():
				dmg *= float(d.get("vs_air", 1.0))
			e.take_damage(dmg, self, BLOW_RANGED)
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
			# a short zap from the forked hands (one target: a shot, not a chain)
			e.take_damage(dmg, self, BLOW_RANGED)
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
			var charged := kind == "cuirassier" and run_t >= float(Defs.CHARGE["run"]) and game.has_tech(team, "charge")
			if charged:
				dmg *= float(Defs.CHARGE["mult"])
				run_t = 0.0
			# a single blow (the Brood's jaws and claws: nothing left of a horse; the
			# Thresher's saws cleave, like area)
			e.take_damage(dmg, self, "" if kind == "thresher" else (BLOW_BROOD if d["faction"] == "brood" else BLOW_MELEE))
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
		game.stats[team]["repair"] = float(game.stats[team].get("repair", 0.0)) + cost       # (the gold a side spent mending buildings)
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
	_mill_in = false              # (out of a Powder Mill's yard work: Game.separation shoves him again)
	_mill_site = null
	_mill_shed = []
	_mill_walking = false


## Labourers and Winders stand at their post; grubs haul food from the pit to a Hive.
var _barren_t := 0.0
var _barren_seen := false
var _barren_site: Building = null


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
	# (barren() looks up the site's hall; ask twice a second, not at every tick)
	_barren_t -= delta
	if _barren_t <= 0.0 or _barren_site != site:
		_barren_site = site
		_barren_t = 0.5
		_barren_seen = carrying == 0 and not keg and site.barren() and (kind == "labourer" or kind == "grub" or kind == "winder")
	if _barren_seen and carrying == 0 and not keg:
		# barren land (design_principles 2): let the crew go; WORK sends them to fresh land
		cmd_stop()
		var fresh := game.free_site(team, position) if auto_work else null
		if fresh:
			cmd_gather(fresh)
		return Vector2.ZERO
	if site.haul_cap() > 0:
		return _hauler(site, delta)
	if kind == "grub":
		return _haul(site, delta)
	if kind == "winder" and site.d.has("battery"):
		return _haul_battery(site, delta)
	if work == "manning" and auto_repair and _fix_nearby(delta):
		return Vector2.ZERO
	if kind == "labourer" and site.kind == "farm":
		return _farm(site, delta)
	if kind == "labourer" and site.kind == "powder_mill":
		return _mill_work(site, delta)
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


## The Powder Mill: a real workflow, in the mill's own WORK YARD (Building.MILL_YARD: the front
## row of its footprint, walkable, nothing is built on it), so no neighbour, wall or cliff can
## block it. Each labourer walks to one of the three heaps (saltpetre, sulphur, charcoal: the heap
## centres in art/redraws/powder_mill_shed.png as imported by tools/import_mill_chatgpt.py:
## sprite columns 21, 32, 49 less the base column 62) under the lean-to, DIGS and LIFTS a
## shovelful (shovel strips: dig, lift, swing, tip; 4 frames a load, a load per heap), WALKS
## carrying the loaded shovel (walk_shovel strips) along the front of the yard to the hopper,
## TIPS it in (swing, tip) and walks back to the next heap, forever. All of it is manning: the
## powder the mill grinds only counts the crew at work (Building.working_crew), not where they
## stand, so the output is the same however they walk.
## Six men in a yard three tiles by one: each heap and each of the three tipping spots has two
## places (MILL_DIG_AT, MILL_TIP_AT: no two nearer than 5 px), and each man takes the heap,
## and the tipping spot, that the fewest of the others hold, at the place there nobody holds
## (_mill_pick); they dig at the heaps' feet, behind the two lanes the walkers use. They don't
## shove each other there (Game.separation: shoving in a yard this small only pushed men off
## their places and dragged walkers along): they pass close by, and a man who comes up behind
## another going his way keeps a step behind him, or waits a moment for a man crossing his way
## (_mill_pace), instead of walking on top of him. A leg that makes no headway for MILL_STALL s
## ends where he is, so nobody walks on the spot with a frozen stride. A man outside the yard walks in by its open
## side (the pathfinder); when neighbours shut the yard in on every side he goes up to the shed
## and in through it (_mill_shed_way); only a mill with no free ground round it at all is worked
## from outside, the shovel going round where he stands.
## Places are from the base point (the footprint's front middle), x right and y down: the yard
## is y -32..0 (a man's middle stays 3.3 px inside it), the sprite's row 107 is y 0.
const MILL_PILE_DX := [-40.0, -30.0, -13.0]     # the heaps' columns (21, 32, 49 in the sprite)
const MILL_DIG_AT := [[Vector2(-42.0, -10.0), Vector2(-36.5, -10.0)], [Vector2(-30.5, -10.0), Vector2(-24.5, -10.0)],
	[Vector2(-18.0, -9.5), Vector2(-10.0, -9.5)]]          # (two places a heap, at its foot under the lean-to's eaves)
const MILL_TIP_AT := [[Vector2(-3.0, -16.0), Vector2(1.0, -20.0)], [Vector2(6.0, -23.0), Vector2(9.0, -18.0)],
	[Vector2(13.0, -21.0), Vector2(15.0, -16.0)]]          # (three spots before the hopper's legs, staggered; its mouth: column 72, row 65)
const MILL_MOUTH := Vector2(10.0, -42.0)        # (he tips facing it)
const MILL_LANE_OUT := -3.5                     # the carry lane, along the yard's front edge
const MILL_LANE_BACK := -5.5                    # the way back, a step further in (both well in front of the diggers)
const MILL_WAY := 3.5                           # a crew man this near the line he walks is in his way (_mill_pace)
const MILL_LOOK := 9.0                          # (looked for this far ahead)
const MILL_GAP := 5.0                           # the gap he keeps behind a man walking ahead in his way
const MILL_GAP_K := 10.0                        # (px/s of speed for each px the gap is long or short)
const MILL_HOLD := 0.8                          # held back longer than this (the man ahead doesn't move on): he walks on
const MILL_STALL := 0.4                         # a leg with no headway this long (not held back) ends where he is
const MILL_CYCLE := 2.0                         # dig + tip time (the walks come on top)
const MILL_STEP_ENDS := [0.7, 1.05, 1.35]      # dig, lift, swing end here; tip to MILL_CYCLE
var _mill_k := -1                               # the heap he works (the load's colour)
var _mill_j := 0                                # the tipping spot he takes
var _mill_slot := 0                             # which of the two places at his heap / spot he takes
var _mill_t := 0.0                              # 0..1.05 digging and lifting, 1.05..MILL_CYCLE swinging and tipping
var _mill_walking := false
var _mill_ph := 3                               # 0 dig at the heap, 1 carry to the hopper, 2 tip, 3 back to a heap
var _mill_route: Array = []                     # the waypoints still to walk
var _mill_site: Building = null
var _mill_in := false                           # at work in the yard (Game.separation: the crew there don't shove each other)
var _mill_best := INF                           # this leg's closest approach to its waypoint so far
var _mill_stall := 0.0                          # time without headway on this leg
var _mill_held := 0.0                           # time held back behind another man (_mill_pace)
var _mill_first := true
var _mill_look_t := 0.0                         # outside: the way in is looked at again when this runs out
var _mill_path_t := 0.0                         # (and a new path asked for at most this often)
var _mill_gate := Vector2.INF                   # the yard shut in: the free cell beside the shed he goes in from
var _mill_gate_way: Array = []                  # and from there through the shed into the yard
var _mill_shed: Array = []                      # the way through the shed still to walk
var _mill_edge := false                         # no free ground round the mill at all: he works from outside


static func mill_step(t: float) -> int:
	for i in MILL_STEP_ENDS.size():
		if t < float(MILL_STEP_ENDS[i]):
			return i
	return MILL_STEP_ENDS.size()


## The base point of a mill on footprint `r` (its front middle), where the places are from.
static func mill_base(r: Rect2) -> Vector2:
	return Vector2(r.get_center().x, r.end.y)


## Place `slot` (0, 1) to dig at heap k in the yard of a mill on footprint `r`.
static func mill_heap_spot(r: Rect2, k: int, slot := 0) -> Vector2:
	return mill_base(r) + Vector2(MILL_DIG_AT[k][slot])


## Place `slot` at tipping spot j before the hopper.
static func mill_tip_spot(r: Rect2, j: int, slot := 0) -> Vector2:
	return mill_base(r) + Vector2(MILL_TIP_AT[j][slot])


## Where he digs at heap k.
func mill_station(site: Building, k: int) -> Vector2:
	return mill_heap_spot(site.rect(), clampi(k, 0, 2), _mill_slot)


## Where he stands to tip into the hopper (his place at his tipping spot).
func mill_hopper_station(site: Building) -> Vector2:
	return mill_tip_spot(site.rect(), _mill_j, _mill_slot)


## His next heap (tip false) or tipping spot (tip true): of the three, the one the fewest of the
## others at work in the yard hold right now (going there or working there), `first` first, then
## on in turn; and the place there that is free (two share a heap at the most: six men, three
## heaps, three spots, two places each).
func _mill_pick(site: Building, tip: bool, first: int) -> int:
	var held := [0, 0, 0]
	var taken := [0, 0, 0]          # bit 1: its first place is held, 2: its second
	for o in site.crew:
		if o == self or not is_instance_valid(o) or o.dead or not o._mill_in or o._mill_site != site:
			continue
		var o_tip: bool = o._mill_ph == 1 or o._mill_ph == 2
		var at: int = o._mill_j if o_tip else o._mill_k
		if o_tip != tip or at < 0 or at > 2:
			continue
		held[at] += 1
		taken[at] |= 1 << clampi(o._mill_slot, 0, 1)
	var best := posmod(first, 3)
	for n in 3:
		var c := (first + n) % 3
		if held[c] < held[best]:
			best = c
	match int(taken[best]):
		1:
			_mill_slot = 1
		2:
			_mill_slot = 0
		_:
			_mill_slot = maxi(site.crew.find(self), 0) % 2
	return best


## How fast he may walk (INF: his own pace). They don't shove each other in the yard, and two
## walking together would be drawn on top of each other, so he keeps MILL_GAP behind another of
## the crew walking ahead of him in his way (within MILL_WAY of the line he walks, at most
## MILL_LOOK ahead): no faster than that man goes along it, slower while the gap is short (a
## standstill when it is), faster to close it again. Like traffic: a man stepping onto the lane
## or off it (a leg more up and down than along) waits for the lane's walkers in his way, they
## never wait for him. Between two walking the same kind of leg, who is ahead is measured along
## both their ways together (dir plus his), the same answer for both, and of two level with each
## other the later man (the higher id) drops back: so nobody waits for a man who waits for him
## (the old rule, a little slower than the man ahead, let two walk on top of each other for a
## second and more; a test each man made along his own way alone left two, or three, standing
## stuck together where the lanes meet the hopper's spots). A man standing in his way (at his
## place), or coming the other way, is passed close by: that is a moment.
func _mill_pace(site: Building, dir: Vector2) -> float:
	var cap := INF
	var lane := absf(dir.x) >= absf(dir.y)
	for o in site.crew:
		if o == self or not is_instance_valid(o) or o.dead or not o._mill_in or not o._mill_walking or o._mill_site != site:
			continue
		var rel: Vector2 = o.position - position
		if rel.length_squared() > MILL_LOOK * MILL_LOOK or absf(dir.cross(rel)) > MILL_WAY:
			continue
		var od: Vector2 = o.facing
		if od.dot(dir) < -0.5:
			continue             # coming the other way: they pass
		var o_lane: bool = absf(od.x) >= absf(od.y)
		if lane and not o_lane:
			continue             # (stepping onto the lane or off it: he waits for me)
		var lon := rel.dot(dir)
		if lane == o_lane:
			var ahead := rel.dot(dir + od)
			if ahead < -0.5 or (ahead <= 0.5 and get_instance_id() < o.get_instance_id()):
				continue         # (he is behind, or level and the later man: it's his to keep back)
		elif lon <= 0.0:
			continue             # (a lane walker I have already crossed)
		cap = minf(cap, maxf(0.0, maxf(0.0, o.velocity.dot(dir)) + (lon - MILL_GAP) * MILL_GAP_K))
	return cap


## The way from where he is to his heap (out false) or tipping spot (out true): onto the lane
## (the carry lane along the yard's front, the way back a step further in), along it, and to the
## spot; inside the yard, all of it.
func _mill_walk_route(site: Building, out: bool) -> Array:
	var r := site.rect()
	var goal := mill_hopper_station(site) if out else mill_station(site, _mill_k)
	var ly := r.end.y + (MILL_LANE_OUT if out else MILL_LANE_BACK)
	var pts: Array = []
	if absf(position.y - ly) > 2.0 and absf(position.x - goal.x) > 4.0:
		pts.append(Vector2(position.x, ly))
	if absf(goal.x - position.x) > 4.0:
		pts.append(Vector2(goal.x, ly))
	pts.append(goal)
	_mill_best = INF
	_mill_stall = 0.0
	_mill_held = 0.0
	return pts


func _mill_snd() -> void:
	_work_snd_t = 0.05            # (the bite, or the tip: a sound as the work begins)


func _mill_work(site: Building, delta: float) -> Vector2:
	var idx := maxi(site.crew.find(self), 0)
	if _mill_site != site:
		_mill_site = site
		_mill_in = false
		_mill_k = -1
		_mill_ph = 3
		_mill_route = []
		_mill_shed = []
		_mill_gate = Vector2.INF
		_mill_first = true
		_mill_edge = false
		_mill_look_t = 0.0
	var r := site.rect()
	var yard := Building.mill_yard_rect(r)
	if not _mill_in:
		if not yard.grow(-1.0).has_point(position):
			return _mill_enter(site, idx, delta)
		# in the yard: to work, at the heap fewest of the others hold
		_mill_in = true
		work = "manning"
		path = PackedVector2Array()
		_mill_shed = []
		_mill_gate = Vector2.INF
		_mill_ph = 3
		_mill_k = _mill_pick(site, false, _mill_k if _mill_k >= 0 else idx % 3)
		_mill_route = _mill_walk_route(site, false)
	elif not yard.grow(24.0).has_point(position):
		# taken out of the yard (shoved far, or knocked back): back in, the way he can
		_mill_in = false
		_mill_route = []
		_mill_look_t = 0.0
		return _mill_enter(site, idx, delta)
	work = "manning"
	# the legs: straight from waypoint to waypoint (the yard is all walkable and the crew don't
	# shove each other); a leg that gets no closer for MILL_STALL s ends where he is (time held
	# back behind another man doesn't count: that man moves on)
	while not _mill_route.is_empty():
		var wp: Vector2 = _mill_route[0]
		var d := wp - position
		var dist := d.length()
		var last := _mill_route.size() == 1
		if dist > (1.0 if last else 5.0):
			var dir := d / dist
			# (onto his place he slows down: the eased velocity, Unit._move, would carry him past it)
			var v := minf(speed, dist * 8.0 + 8.0 if last else dist / maxf(delta, 0.001))
			var pace := _mill_pace(site, dir)
			var held := pace < v * 0.7
			_mill_held = _mill_held + delta if held else 0.0
			if _mill_held < MILL_HOLD:
				v = minf(v, pace)
			if dist < _mill_best - 0.3:
				_mill_best = dist
				_mill_stall = 0.0
			elif not held:
				_mill_stall += delta
			if _mill_stall < MILL_STALL:
				_mill_walking = true
				facing = dir
				return dir * v
		_mill_route.remove_at(0)
		_mill_best = INF
		_mill_stall = 0.0
		_mill_held = 0.0
	if _mill_walking:
		# arrived: he stops dead (the eased velocity and a shove taken on the way, Unit._move,
		# would slide him a few px on, onto the next man's place)
		_mill_walking = false
		velocity = Vector2.ZERO
		_push = Vector2.ZERO
	match _mill_ph:
		3:      # at a heap: dig (the first time, each at a different point of the dig: they drift apart)
			_mill_ph = 0
			_mill_t = 0.0
			if _mill_first:
				_mill_t = [0.0, 0.5, 0.9][(idx + idx / 3) % 3]
				_mill_first = false
			_mill_snd()
			facing = Vector2(0.0, -1.0)
		0:
			facing = Vector2(0.0, -1.0)
			_mill_t += delta
			if _mill_t >= float(MILL_STEP_ENDS[1]) + 0.12 * float(idx % 3):
				# lifted: off to the hopper with the load, to the tipping spot fewest hold
				_mill_ph = 1
				_mill_t = float(MILL_STEP_ENDS[1]) - 0.001       # (the lifted load stays on the blade)
				_mill_j = _mill_pick(site, true, idx % 3)
				_mill_route = _mill_walk_route(site, true)
				_mill_walking = true
		1:      # at the hopper
			_mill_ph = 2
			_mill_t = float(MILL_STEP_ENDS[1])
			_mill_snd()
			facing = (mill_base(r) + MILL_MOUTH - position).normalized()
		2:
			facing = (mill_base(r) + MILL_MOUTH - position).normalized()
			_mill_t += delta
			if _mill_t >= MILL_CYCLE:
				# tipped: on to the next heap (the next in turn, unless it's busier)
				_mill_ph = 3
				_mill_t = 0.0
				_mill_k = _mill_pick(site, false, (_mill_k + 1) % 3)
				_mill_route = _mill_walk_route(site, false)
				_mill_walking = true
	return Vector2.ZERO


## Outside the yard: walk in. By its open side when there is one (the pathfinder: the yard's
## cells are walkable); when neighbours shut the yard in on every side, to the free cell beside
## the shed nearest him and in through the shed (_mill_shed_way); with no free ground round the
## mill at all, he works from the nearest spot he can reach.
func _mill_enter(site: Building, idx: int, delta: float) -> Vector2:
	_mill_walking = false
	if _mill_k < 0:
		_mill_k = idx % 3
		_mill_slot = idx % 2
	if not _mill_shed.is_empty():
		return _mill_through_shed(delta)
	_mill_look_t -= delta
	_mill_path_t -= delta
	if _mill_look_t <= 0.0:
		# (which way in: looked at again every couple of seconds, the ground may have changed)
		_mill_look_t = 2.0
		_mill_gate = Vector2.INF
		_mill_edge = false
		var mine := game.region_of(game.cell_of(position))
		if mine >= 0 and mine != game.region_of(game.cell_of(mill_station(site, _mill_k))):
			var way := _mill_shed_way(site, mine)
			if way.is_empty():
				_mill_edge = true
			else:
				_mill_gate = way[0]
				_mill_gate_way = way.slice(1)
	if _mill_edge:
		return _mill_from_edge(site, delta)
	work = "to_site"
	var target := mill_station(site, _mill_k) if _mill_gate == Vector2.INF else _mill_gate
	if _mill_gate != Vector2.INF and position.distance_to(_mill_gate) < 8.0:
		_mill_shed = _mill_gate_way.duplicate()
		_mill_gate = Vector2.INF
		_mill_best = INF
		_mill_stall = 0.0
		return _mill_through_shed(delta)
	if ((path.is_empty() or path_i >= path.size()) or path_goal != target) and not path_pending and _mill_path_t <= 0.0:
		_mill_path_t = 0.5
		_request_path(target)
	return _follow(delta)


## The yard shut in (no cell beside it he can walk to): the free cell beside the shed nearest
## him that he can reach (behind it, or beside its two back rows), then the way from there
## through the mill's own cells into the yard below, as points: [that cell's middle, the shed
## cell he steps into, the yard cell under it]. [] when there is none.
func _mill_shed_way(site: Building, region: int) -> Array:
	var c0 := site.cell
	var row: int = Building.MILL_YARD.position.y
	var cands: Array = []          # [the free cell, the shed cell beside it]
	for x in site.size.x:
		cands.append([c0 + Vector2i(x, -1), c0 + Vector2i(x, 0)])
	for y in row:
		cands.append([c0 + Vector2i(-1, y), c0 + Vector2i(0, y)])
		cands.append([c0 + Vector2i(site.size.x, y), c0 + Vector2i(site.size.x - 1, y)])
	var best: Array = []
	var bd := INF
	for cand in cands:
		var fc: Vector2i = cand[0]
		if not game.is_free(fc) or game.region_of(fc) != region:
			continue
		var p := game.cell_center(fc)
		if p.distance_to(position) < bd:
			bd = p.distance_to(position)
			var sc: Vector2i = cand[1]
			best = [p, game.cell_center(sc), game.cell_center(Vector2i(sc.x, c0.y + row))]
	return best


## In through the shed, waypoint by waypoint (buildings don't stop a man squeezing through,
## Unit._move; the way only crosses the mill's own cells). A way that gets him nowhere is given up.
func _mill_through_shed(delta: float) -> Vector2:
	work = "manning"
	_mill_ph = 3
	while not _mill_shed.is_empty():
		var wp: Vector2 = _mill_shed[0]
		var d := wp - position
		var dist := d.length()
		if dist > 4.0:
			if dist < _mill_best - 0.3:
				_mill_best = dist
				_mill_stall = 0.0
			else:
				_mill_stall += delta
			if _mill_stall > 1.5:
				_mill_shed = []
				_mill_look_t = 0.0
				break
			_mill_walking = true
			squeeze_t = 0.25
			facing = d / dist
			return d / dist * minf(speed, dist / maxf(delta, 0.001))
		_mill_shed.remove_at(0)
		_mill_best = INF
		_mill_stall = 0.0
	_mill_walking = false
	return Vector2.ZERO


## No free ground round the mill to get in from (walled in on every side): he works from the
## nearest spot he can reach, the shovel going round the three loads where he stands.
func _mill_from_edge(site: Building, delta: float) -> Vector2:
	if site.edge_distance(position) < radius + 18.0:
		work = "manning"
		path = PackedVector2Array()
		_mill_ph = 0
		facing = (site.center() - position).normalized()
		_mill_t += delta
		if _mill_t >= MILL_CYCLE:
			_mill_t = 0.0
			_mill_k = (_mill_k + 1) % 3
		return Vector2.ZERO
	if work != "manning":
		work = "to_site"
	var target := game.approach_point(site, position)
	if ((path.is_empty() or path_i >= path.size()) or path_goal != target) and not path_pending and _mill_path_t <= 0.0:
		_mill_path_t = 0.5
		_request_path(target)
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
				var value := game.draw_lode(cr, Defs.battery_charge(carry_blue, carry_t) * float(Defs.BATTERY["ore"]) * game.line_net.speed_mult(cr))
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
	if game.net_forward(self, "cmd_sacrifice", []): return
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
	if game.net_forward(self, "cmd_harvest", []): return
	if aboard:
		return      # riding in a balloon
	_reset_work()
	order = "harvest"
	harvest_home = position
	work = ""
	target = null


func _harvest(delta: float) -> Vector2:
	if cocoon > 0:
		var hive := game.dropoff_hall(position, team)
		if hive == null:
			return Vector2.ZERO
		if hive.edge_distance(position) < radius + 17.0:
			game.add_res2(team, cocoon)
			if team == game.human:
				game.float_text(position + Vector2(0, -26), "+%s essence" % Game.essence_text(cocoon), Color(0.8, 0.5, 1.0))
			cocoon = 0.0
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
			var hive := game.dropoff_hall(pit.center(), team)
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


# ------------------------------------------------------------------ haulers (Defs.HAUL)
## A hauler is a Labourer assigned to a Town Hall (order "gather", home_mine the hall: the same
## right-click as a Farm). Game.haul_dispatch gives him jobs (haul_job); he does nothing else
## (no farming, no building) until the player orders him, which unassigns him and lets go of
## whatever he was doing: horses claimed or on his leash are free again (they keep their
## reservation and are fetched anew), a keg goes back into the stores.

## Can this man be assigned to a Town Hall?
func can_haul() -> bool:
	return kind == "labourer" and aboard == null and not dead and not off_field


## Assigned to a Town Hall as a hauler.
func is_hauler() -> bool:
	return order == "gather" and is_instance_valid(home_mine) and home_mine is Building and (home_mine as Building).haul_cap() > 0


## (a man) on his way to this horse: to mount it, to lead it, or sent for it as a hauler.
func is_coming_for(h) -> bool:
	return order_target == h or (not haul_job.is_empty() and (haul_job.get("want", []) as Array).has(h))


## What a hauler is doing, for his card.
func hauler_text() -> String:
	if haul_job.is_empty():
		return "Hauler: waiting at the Town Hall for a horse or a keg to fetch."
	match String(haul_job["k"]):
		"keg":
			return "Hauler: carrying a powder keg to the wagon (it blows up if he's killed!)" if keg else "Hauler: fetching a powder keg from the Powder Mill."
		"team":
			return "Hauler: bringing horses to a gun."
	return "Hauler: leading %d horse%s to the buildings that need them." % [led.size(), "" if led.size() == 1 else "s"] if not led.is_empty() \
		else "Hauler: going for a horse."


## Start a job (Game.haul_dispatch).
func begin_haul(job: Dictionary) -> void:
	haul_job = job
	path = PackedVector2Array()
	repath_t = 0.0
	work = "hauling"


## The job is over or cut short (a new order, killed, the hall gone): the horses he was sent
## for can be claimed again and those on his leash stay where he stands, still kept for their
## recruits. (The keg is dealt with by _reset_work: back into the stores.)
func _haul_abort() -> void:
	if haul_job.is_empty():
		return
	for h in (haul_job.get("want", []) as Array):
		if is_instance_valid(h) and h.claimed == self:
			h.claimed = null
	if String(haul_job.get("k", "")) != "keg":
		release_horses()
	haul_job = {}


func _hauler(site: Building, delta: float) -> Vector2:
	if haul_job.is_empty():
		# waiting for the next request, by the hall
		work = "waiting"
		if site.edge_distance(position) < radius + Defs.HAUL["reach"] + 10.0:
			path = PackedVector2Array()
			return Vector2.ZERO
		return _walk_to(game.approach_point(site, position), delta)
	if String(haul_job["k"]) == "keg":
		return _haul_keg(site, delta)
	return _haul_horses(site, delta)


## Fetch the horses claimed for him (the Horse Breeder's, spare ones), lead them to the
## buildings (or the gun) that need them and hitch them, then back to the hall.
func _haul_horses(site: Building, delta: float) -> Vector2:
	var j := haul_job
	work = "hauling"
	_prune_led()
	var want: Array = (j.get("want", []) as Array).filter(func(h) -> bool: return is_instance_valid(h) and not h.dead and not h.off_field \
		and h.team == team and h.into == null and (h.leader == null or h.leader == self))
	j["want"] = want
	match String(j["ph"]):
		"fetch":
			if want.is_empty():
				j["ph"] = "deliver" if not led.is_empty() else "home"
				return Vector2.ZERO
			var h: Unit = want[0]
			var bd := INF
			for o in want:
				var dd: float = position.distance_to(o.position)
				if dd < bd:
					bd = dd
					h = o
			if bd < radius + h.radius + 14.0:
				h.claimed = self
				take_reins(h)               # (the leash: he now leads it; the claim is lifted)
				want.erase(h)
				return Vector2.ZERO
			if _haul_stuck(bd, delta) == 2:
				h._snap_to_leader(position)  # (cannot get to it: the horse is brought to his side)
				return Vector2.ZERO
			return _walk_to(h.position, delta)
		"deliver":
			var goal_e: Entity = null
			var pick: Unit = null
			var bd := INF
			for h in led.duplicate():
				var e := game.haul_dest(self, h)
				if e == null:
					# nobody wants it any more (the recruit was cancelled, the gun gone): let it go
					led.erase(h)
					h.leader = null
					h.graze_at = h.position
					h._graze_goal = Vector2.INF
					continue
				var dd: float = e.edge_distance(position)
				if dd < bd:
					bd = dd
					pick = h
					goal_e = e
			if pick == null:
				j["ph"] = "home"
				return Vector2.ZERO
			if bd < float(Defs.HAUL["reach"]):
				_hitch(pick, goal_e)
				return Vector2.ZERO
			if _haul_stuck(bd, delta) == 2:
				# no headway for a long while (a locked gate, a crowd, a pocket between buildings):
				# the horse is put beside its destination and goes in from there
				pick._snap_to_leader(game.approach_point(goal_e, position))
				_hitch(pick, goal_e)
				return Vector2.ZERO
			return _walk_to(game.approach_point(goal_e, position), delta)
		_:
			if site.edge_distance(position) < radius + float(Defs.HAUL["reach"]):
				haul_job = {}
				work = "waiting"
				path = PackedVector2Array()
				return Vector2.ZERO
			if _haul_stuck(site.edge_distance(position), delta) == 2:
				haul_job = {}              # (cannot get home: free for the next job where he stands)
				work = "waiting"
				path = PackedVector2Array()
				return Vector2.ZERO
			return _walk_to(game.approach_point(site, position), delta)


const HAUL_REPATH_AFTER := 6.0     # s without headway: a new path
const HAUL_GIVE_UP_AFTER := 16.0   # s without headway: the fallback (the caller's)
var _hs_best := INF
var _hs_t := 0.0
var _hs_ph := ""


## (a hauler) Stuck-recovery for one leg of a trip, `ref` being the distance still to go. Without
## 8 px of headway for HAUL_REPATH_AFTER s the way is worked out again; for HAUL_GIVE_UP_AFTER s
## this returns 2 (once, then it starts over) and the caller takes its fallback.
func _haul_stuck(ref: float, delta: float) -> int:
	var key := String(haul_job.get("ph", ""))
	if key != _hs_ph:
		_hs_ph = key
		_hs_best = INF
		_hs_t = 0.0
	if ref < _hs_best - 8.0:
		_hs_best = ref
		_hs_t = 0.0
		return 0
	var before := _hs_t
	_hs_t += delta
	if before < HAUL_REPATH_AFTER and _hs_t >= HAUL_REPATH_AFTER:
		path = PackedVector2Array()
		path_i = 0
		repath_t = 0.0
		for h in led:
			if is_instance_valid(h):
				h._lead_stuck = 3.0     # (a led horse jammed behind him is put back beside him now)
	if _hs_t >= HAUL_GIVE_UP_AFTER:
		_hs_best = INF
		_hs_t = 0.0
		return 2
	return 0


## Let the leash go at the destination: a building takes the horse in (for its recruit or
## gun: Game.horse_arrived), a gun or wagon harnesses it, a new rider waiting on foot finds it
## beside him and mounts.
func _hitch(h: Unit, dest: Entity) -> void:
	led.erase(h)
	h.leader = null
	game.haul_done(team, "horse")
	if dest is Building or (dest is Unit and Defs.HARNESSED.has((dest as Unit).kind)):
		h.walk_into(dest)
	else:
		h.graze_at = h.position
		h._graze_goal = Vector2.INF
		h.claimed = null


## A keg for a Powder Wagon: from the nearest Powder Mill (paid from the powder bank when it's
## loaded) to the wagon, wherever it has got to; back to the hall.
func _haul_keg(site: Building, delta: float) -> Vector2:
	var j := haul_job
	var w = j.get("wagon")
	var shots := float(Defs.WAGON["keg"])
	if w == null or not is_instance_valid(w) or w.dead or w.off_field:
		if keg:
			keg = false                 # (back into the stores)
			game.players[team]["res2"] = float(game.players[team]["res2"]) + _keg_cost()
		j["ph"] = "home"
	match String(j["ph"]):
		"to_mill":
			var mill := game.nearest_of(position, team, "powder_mill")
			if mill == null:
				haul_job = {}
				return Vector2.ZERO
			if mill.edge_distance(position) < radius + 18.0:
				path = PackedVector2Array()
				facing = (mill.center() - position).normalized()
				if work != "loading":
					work = "loading"
					work_t = float(Defs.WAGON["keg_load"])
					j["wait"] = 0.0
				work_t -= delta
				if work_t <= 0.0:
					if float(game.players[team]["res2"]) >= _keg_cost():
						game.players[team]["res2"] = float(game.players[team]["res2"]) - _keg_cost()
						keg = true
						work = "hauling"
						j["ph"] = "to_wagon"
					else:
						work_t = 1.0              # wait for the mill to grind enough
						j["wait"] = float(j.get("wait", 0.0)) + 1.0
						if float(j["wait"]) > 30.0:
							j["ph"] = "home"
				return Vector2.ZERO
			work = "hauling"
			return _walk_to(game.approach_point(mill, position), delta)
		"to_wagon":
			work = "hauling"
			if position.distance_to(w.position) < radius + w.radius + 16.0:
				# (a gun counts its powder in its own shots: a cannon shot takes 3 musket shots)
				var per := 1.0 if w.kind == "powder_wagon" else float(Defs.POWDER["cost"].get(w.kind, 0.5)) / float(Defs.POWDER["cost"]["musketeer"])
				var put := minf(w.max_powder() - w.powder, shots / per)
				w.powder += put
				w._dispense_t = 0.8
				if put * per < shots:
					game.players[team]["res2"] = float(game.players[team]["res2"]) + _keg_cost() * (1.0 - put * per / shots)
				keg = false
				game.haul_done(team, "keg")
				if team == game.human and put > 0.0:
					game.float_text(position + Vector2(0, -30), "+%d shots" % int(put), Color(1, 0.85, 0.5))
				path = PackedVector2Array()
				j["ph"] = "home"
				return Vector2.ZERO
			# the wagon may be on the move: head straight for it when close, else path there
			return _walk_to(w.position, delta)
		_:
			if keg:
				keg = false
				game.players[team]["res2"] = float(game.players[team]["res2"]) + _keg_cost()
			work = "hauling"
			if site.edge_distance(position) < radius + float(Defs.HAUL["reach"]):
				haul_job = {}
				work = "waiting"
				path = PackedVector2Array()
				return Vector2.ZERO
			return _walk_to(game.approach_point(site, position), delta)


## (a Field Cannon or Mortar) dry, cannot limber to go and refill (on HOLD, or without a
## horse), and out of reach of a powder building: a hauler brings it a keg.
func needs_keg() -> bool:
	if not (kind == "cannon" or kind == "mortar") or dead or off_field or aboard != null:
		return false
	if powder >= 1.0 or (harnessed and order != "hold"):
		return false
	return _powder_building() == null


func _keg_cost() -> float:
	return float(Defs.WAGON["keg"]) / float(Defs.WAGON["per_powder"])


## Missionary: walk to the wounded soldier, take him off the field, bandage him and send
## him back at full health.
var _patient: Unit = null


func _heal(delta: float) -> Vector2:
	if work == "bandaging":
		work_t -= delta
		if _patient == null or not is_instance_valid(_patient) or _patient.dead:
			_release_patient()
			cmd_stop()
			_heal_back_on()
			return Vector2.ZERO
		if work_t <= 0.0:
			var pt := _patient
			pt.hp = pt.max_hp
			pt.acid_t = 0.0
			pt.cross_t = Defs.CROSS_TIME
			if team == game.human:
				game.float_text(position + Vector2(0, -30), "healed", Color(1, 1, 1))
			_release_patient()
			cmd_stop()
			pt._heal_back_on()
			_heal_back_on()
		return Vector2.ZERO
	var p := order_target as Unit
	if p == null or not is_instance_valid(p) or p.dead or p.off_field or p.cross_t > 0.0 or p.hp >= p.max_hp:
		cmd_stop()
		return Vector2.ZERO
	if position.distance_to(p.position) < radius + p.radius + 10.0:
		# bandaging is done on foot, beside the horses: a Mounted Missionary gets off first,
		# a horseman too (and both get back on after)
		if is_mounted():
			_heal_remount = true
			cmd_dismount(false, {"o": "heal", "e": p})
			return Vector2.ZERO
		if p.is_mounted():
			if p.order != "dismount":
				p._heal_remount = true
				p.cmd_dismount(false, {})
			return Vector2.ZERO          # (waits while he gets off)
		if p.order == "dismount":
			return Vector2.ZERO
		_patient = p
		p.cmd_stop()
		p.velocity = Vector2.ZERO
		p.off_field = true
		p.visible = false
		p.selected = false
		game.selection.erase(p)
		if p.position.distance_to(position) > 1.0:
			facing = (p.position - position).normalized()     # (the patient on the side he came from)
		position = p.position
		if p.kind == "dismounted" and absf(facing.x) < absf(facing.y) * 0.42 and facing.y > 0.0:
			# (no front view of the two of them: kneel to the SE / SW, the patient on that side)
			facing = Vector2(-1.0 if facing.x < 0.0 else 1.0, 1.0).normalized()
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


## (a Missionary or his patient, after a bandage) back on the horse he got off for it.
func _heal_back_on() -> void:
	if not _heal_remount:
		return
	_heal_remount = false
	if not is_mounted() and Defs.MOUNTS.has(kind):
		_try_remount({})


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
	if not jump.is_empty():
		jump = {}                  # (a Jack killed in the air falls where it was)
		if sprite:
			sprite.position = Vector2.ZERO
	owl_t = -1.0                   # (a Swift killed while turning into an Owl: the price is lost)
	net_t = 0.0                    # (caught in a net: the net goes with it)
	if _net_spr:
		_net_spr.queue_free()
		_net_spr = null
	if Defs.cw_roster:
		CwUnits.on_death(game, self)
	queue.clear()
	line_rest.clear()
	_haul_abort()              # (a hauler: his claims on horses are let go; the keg still blows)
	_leave_mine()
	_release_patient()
	_drop_body()
	_cancel_boarding()
	_cancel_refit()            # (killed on the way to a refit: the fee goes back)
	drop_crate()               # (a Winder) the crate on his back falls where he stood
	release_horses()           # (his horses stay where they are)
	if claimed and is_instance_valid(claimed) and claimed.order_target == self:
		claimed.cmd_stop()     # (a horse) the man coming for it stops
	if leader and is_instance_valid(leader):
		leader.led.erase(self)
		leader = null
	if tongue_stage != "":
		_break_tongue("killed")    # (a Mist Toad) the mark goes, or the tongue lets go
	if _crate_spr:
		_crate_spr.visible = false
	# fallen under the cross (just raised, or just bandaged): gone for good
	final_death = cross_t > 0.0
	died_at = game.clock
	reviver = null
	if not passengers.is_empty():
		# shot down: the men in the basket die with it and lie where it falls. (Mid-drop, with the
		# balloon down and the men climbing out, they are already off: they get out alive.)
		drop_passengers(position, work != "dropping")
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
	# his horse may live and bolt, nobody's (a gun's team too): by the blow that did it
	if is_mounted():
		_rider_falls()
	elif kind == "cannon" or kind == "mortar":
		_team_bolts()
	game.on_unit_died(self)
	Sfx.play_any(["combat/%s_death" % kind, "combat/%s_death" % Sfx.SHORT.get(d["faction"], "crown"), "death_" + Sfx.SHORT.get(d["faction"], "crown")], position)
	_set_anim(_death_anim(), true)
	z_index = 3 if Defs.FLYER.has(kind) else -1     # (the Swift and the Owl fall first: under the living once down)
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
	if (work == "mounting" or work == "dismounting") and mount_strip_art() != "":
		return "mount"
	var moving := velocity.length() > 10.0
	if kind == "labourer":
		# a crowd shoves him around the 10 px/s line: stay in the walk for a moment instead of
		# flicking walk <-> idle (every switch restarts the pose)
		var now: float = game.clock
		if moving:
			_lab_moved_t = now
		elif now - _lab_moved_t < 0.18:
			moving = true
	match kind:
		"musketeer", "dismounted":
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
			if cooldown > 0.0 and (target or order == "bombard"):
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
			if cooldown > 0.0 and (target or order == "bombard"):
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
				if site and site.kind == "powder_mill":
					if _mill_walking:      # (the Mill: shovels the heaps into the hopper: a loaded shovel on the way there)
						return "walk_shovel" if _mill_ph == 1 else "walk"
					return "shovel"
				return "build"
			if work == "mining" or phase != "":
				return "mine"
			if work == "building" or work == "repairing":
				return "build"           # (repairing: the same hammering as building)
			if carrying > 0:
				return "carry" if moving else "idle_carry"      # (the gold sack on his back, walking or standing)
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
				return _anim_or("pistol", "attack") if mode == "pistol" else "attack"
		"balloon":
			return "drift" if moving else "idle"
		"horse":
			# a horse left to itself grazes (head down) most of the time it stands
			if not moving and leader == null and into == null and (int(_bob_t / 3.0) + get_instance_id()) % 3 != 0:
				return _anim_or("graze", "idle")
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
		"ornithopter", "clock_soldier", "pendulum", "netter":
			if phase != "":
				return "attack"          # (the Pendulum's swing, the Netter's recoil)
		"jack":
			if not jump.is_empty():
				return "jump"            # (crouch, launch, air, landing: Jack.frame picks the frame)
			if phase != "":
				# at a flyer it raises its arm (the attack_up strip: same timing, same shot frame)
				return "attack_up" if Jack.aims_up(self) else "attack"
		"cuckoo":
			if phase != "":
				return "attack"          # (the pecking lunge)
		"ticking_owl":
			if phase != "":
				return "bomb" if _owl_bomb else "attack"     # (the bomb drop on a building, the swoop on a unit)
	return "walk" if moving else "idle"


const GALLOPERS := ["cuirassier", "horseman", "messenger", "dragoon", "dragoon_armoured"]

## Walk cycles of the men on foot at full speed, in frames a second (docs/animation_audit_units.md).
## Their strips draw a step about 10 to 14 px long, and at 62 to 66 px/s the feet slid 2 to 4 times
## that far in a stride at WALK_FPS; 12 fps is the fastest legs that still read as walking (the
## strips' frame counts are as drawn, so the cadence is the only thing code can change).
const WALK_FPS_ART := {"musketeer": 12.0, "musketeer_armoured": 12.0, "dismounted": 12.0,
		"dismounted_armoured": 12.0, "winder": 12.0, "windup_soldier": 12.0, "arc_thrower": 10.0,
		"thresher": 10.0, "clock_soldier": 10.0, "jack": 9.0, "cuckoo": 10.0, "ticking_owl": 7.0,
		# the Pendulum's long strides (90 sheet px a step at 0.284: one 8-frame cycle carries it 51 px, 1.1 s at 46);
		# the Netter's quick trot (its stubby legs step faster than the ground goes by: as fast as reads)
		"pendulum": 7.2, "netter": 14.0}


## Frames a second of art `a`'s walk strip at full speed.
static func walk_fps_for(a: String) -> float:
	return float(WALK_FPS_ART.get(a, WALK_FPS))


## Animation runs at most 15 times a second, and not at all for units nobody can see.
func _animate(delta: float) -> void:
	_anim_dt += delta
	# (a walking or hammering Labourer steps at 30 Hz: his frames follow the ground he covers
	# and the hammer beat, which 15 Hz ticks would make uneven)
	var tick := 0.033 if kind == "labourer" and (anim == "build" or velocity.length() > 10.0) else 0.066
	if _anim_dt < tick and not dead:
		return
	if kind == "horse" and not dead:
		modulate.a = 0.0 if _hidden_for_mount() else 1.0     # (the mounting strip draws it)
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
	var n: int = ArtData.UNITS[_anim_art if _anim_art != "" else art]["frames"].get(key, 1)
	var fps := walk_fps_for(_anim_art if _anim_art != "" else art) * clampf(velocity.length() / maxf(speed, 1.0), 0.6, 1.3)
	if anim == "walk" and GALLOPERS.has(art):
		# 8-frame gallop: one stride ~0.57 s at full speed; the Horseman's strips have 7 to 10
		# frames, played so that his stride takes the same time
		fps *= CUIRASSIER_GALLOP_FPS / WALK_FPS * n / 8.0
	var loop := true
	match anim:
		"idle", "idle_carry":
			fps = 2.0 if not Defs.FLYER.has(kind) else float(Defs.FLYER[kind]["flap"]) * 0.85     # (a flyer flaps in place)
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
			fps = 0.75 * float(n)     # (one breath takes 1.3 s whether the view has 4 frames or 2)
		"wrap":
			fps = 5.0 / float(Defs.HARVEST["take"])
			loop = false
		"idle_cocoon":
			fps = 3.0
		"graze":
			fps = 2.0
		"pistol":
			# draw, aim, fire, lower: over the aim and the shot (Defs.PISTOL)
			fps = float(n) / (float(Defs.PISTOL["aim"]) + 0.35)
			loop = false
		"aim", "fire", "aimup", "fireup", "thrust", "brace", "attack", "melee", "attack_up", "bomb":
			fps = 6.0 if kind == "spore_mother" else 9.0
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
		"mount":
			fps = 0.0           # (set from how far through getting on or off he is, below)
			loop = false
		"jump":
			fps = 0.0           # (a Jack's leap: the frame follows the crouch, flight and landing, below)
			loop = false
	if kind == "labourer" and not dead and _drive_labourer(delta, n):
		pass
	else:
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
	if anim == "mount":
		# getting on plays the strip over the mount time; getting off plays it backwards
		var p := clampf(1.0 - work_t / maxf(_mount_len, 0.01), 0.0, 1.0)
		frame_i = mini(int(p * n), n - 1)
		shown = frame_i if work == "mounting" else n - 1 - frame_i
	if kind == "mist_toad" and anim == "tongue" and tongue_stage != "":
		shown = mini(shown, TOAD_MOUTH_OPEN)   # the mouth gapes; the drawn tongue does the reaching
	if anim == "jump":
		frame_i = mini(Jack.frame(self), n - 1)
		shown = frame_i
	sprite.frame = clampi(shown, 0, sprite.hframes - 1)
	if not team_horses.is_empty() or not _team_sprites.is_empty():
		_update_team(delta, fps)
	if _front:
		_update_basket()
	if _rein and (leader != null or _rein_on):
		_rein_on = leader != null
		_rein.queue_redraw()
	_bob_t += delta
	if (d.get("air", false) or _low > 0.0) and not dead:
		# a flyer caught in a net comes down to the ground (quickly) and rises again once free (scripts/netter.gd); one
		# killed down there stays down
		_low = move_toward(_low, 1.0 if net_t > 0.0 else 0.0, delta * (4.0 if net_t > 0.0 else 2.0))
	if net_t > 0.0 or _net_spr:
		Netter.update_net(self, delta)
	if kind == "skywing" and (sky == "landing" or sky == "lifting") and not dead:
		# coming down to (or rising from) the ground
		var f := clampf(sky_t / Defs.SKYWING_SWITCH, 0.0, 1.0)
		sprite.position.y = -20.0 * (f if sky == "landing" else 1.0 - f)
	elif Defs.FLYER.has(kind):
		# the Swift and the Owl: the hover, their lunge / dive / bob, the fall when they die (scripts/cw_air.gd); the Swift
		# pitches nose down into its peck, turned about its body
		sprite.position = CwAir.sprite_offset(self)
		var tl := CwAir.sprite_tilt(self)
		sprite.rotation = tl
		if tl != 0.0:
			var bc := Vector2(0.0, float(Defs.FLYER[kind]["lift"]) - float(Defs.FLYER[kind]["centre"]))
			sprite.position += bc - bc.rotated(tl)
		if dead:
			if CwAir.falling(self):
				queue_redraw()       # (its shadow fades as it comes down)
			else:
				z_index = -1         # (on the ground now: a wreck under the living)
	elif d.get("air", false):
		# flyers hover above their shadow and drop to the ground when they die (or while a net holds them down: _low)
		sprite.position.y = lerpf(sprite.position.y, 0.0, delta * 3.0) if dead else (-20.0 + sin(_bob_t * 4.0) * 2.5) * (1.0 - _low)
		if kind == "balloon" and not dead:
			sprite.position.y += _descend * 14.0 * (1.0 - _low)     # down low to take men on or let them off
	elif anim == "bandage":
		sprite.position.y = -absf(sin(_bob_t * 5.0)) * 1.0
	elif anim == "mount" and work == "mounting" and is_instance_valid(order_target):
		sprite.position = order_target.position - position     # the strip's horse where the horse is
	elif kind == Defs.JACK and not jump.is_empty() and not dead:
		sprite.position = Vector2(0.0, -Jack.lift(self))      # (in the air: over its shadow, on the arc)
	elif kind != "cannon":
		sprite.position = Vector2.ZERO
	# Grubs at the pit: gnaw in a loop on the last frames of the burrow.
	if kind == "grub" and anim == "burrow" and n > 3:
		sprite.frame = clampi(2 + int(_bob_t * 6.0) % (n - 2), 0, sprite.hframes - 1)
	sprite.scale.y = float(d.get("art_scale", 1.0))
	if kind == "cannon" and anim == "walk" and velocity.length() < 10.0:
		sprite.frame = 0        # the horse stands still
	if kind == "cannon" and not ArtData.UNITS["cannon"]["frames"].has("walk_e"):
		_animate_cannon(delta)   # the old one-frame sheet: rock, recoil and a spinning wheel
	elif kind == "spitter" or kind == "bolt":
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


## Whose strips animation `a` comes from: a Missionary bandaging a dismounted rider kneels
## over the Horseman or the Cuirassier (their own art keys: two men need a wider cell).
func _strip_art(a: String) -> String:
	if a == "bandage" and work == "bandaging" and _patient != null and is_instance_valid(_patient) \
			and _patient.kind == "dismounted":
		return "missionary_bandage_c" if _patient.armoured else "missionary_bandage_h"
	return art


## The Labourer's hammering. Every build strip is four frames drawn in swing order (the redrawn
## art, tools/import_labourer_redraw.py): 0 the hammer raised high, 1 halfway down, 2 on the
## stake with a spark (the strike), 3 lifting. The swing is timed as a held raise, a quick
## drop, a held strike and a slower lift, one swing per BUILD_CYCLE seconds. 5 swings fit
## exactly in the 2.0 s hammering clip (assets/audio/work/crown_build.wav, big blows at 0.46,
## 0.87 and 1.30 s), and each time the clip starts the swing is phased so that its first big
## blow lands on a strike (lab_build_lock). [frame, seconds] steps in swing order starting at
## the raised hammer, and the step that is the strike (the frame where the hammer is lowest).
const BUILD_CYCLE := 0.40
const BUILD_CLIP_BLOW := 0.46
const BUILD_SEQ := {"seq": [[0, 0.12], [1, 0.06], [2, 0.12], [3, 0.10]], "hit": 2}
const BUILD_SWING := {"s": BUILD_SEQ, "se": BUILD_SEQ, "e": BUILD_SEQ, "ne": BUILD_SEQ, "n": BUILD_SEQ}
## Walking: one full stride (every frame of the strip, 6 of them: contact, passing, contact
## with the other foot...) per this many pixels covered, so a foot on the ground stays on the
## ground at any speed. 37 px = 12 frames a second at the labourer's speed 74 (the fastest legs that
## still read as walking, see WALK_FPS_ART); the first value, 22 px, made him look to be running.
const LAB_STRIDE := {"walk": 37.0, "carry": 37.0, "carry_keg": 37.0, "walk_shovel": 37.0}
var _lab_build_t := 0.0
var _lab_dist := 0.0
var _lab_prev := Vector2.ZERO
var _lab_moved_t := -10.0
var _lab_view := -1


## Seconds into the swing at which the strike begins (view `dir`).
static func lab_build_hit_at(dir: String) -> float:
	var sw: Dictionary = BUILD_SWING[dir]
	var t := 0.0
	for i in range(int(sw["hit"])):
		t += float((sw["seq"] as Array)[i][1])
	return t


## The swing clock to set when the hammering clip starts, so its first big blow is a strike.
static func lab_build_lock(dir: String) -> float:
	return fposmod(lab_build_hit_at(dir) - BUILD_CLIP_BLOW, BUILD_CYCLE)


## Frame of the build strip `dir` at swing clock `t`.
static func lab_build_frame(dir: String, t: float) -> int:
	var seq: Array = BUILD_SWING[dir]["seq"]
	var k := fposmod(t, BUILD_CYCLE)
	for st in seq:
		k -= float(st[1])
		if k < 0.0:
			return int(st[0])
	return int(seq[seq.size() - 1][0])


## Frames that follow the work: the stride from the distance walked, the hammer from the beat.
## Returns false for everything else (the usual frame rate).
func _drive_labourer(delta: float, n: int) -> bool:
	var moved := position.distance_to(_lab_prev)
	_lab_prev = position
	if LAB_STRIDE.has(anim):
		if moved < 40.0:      # (a jump, e.g. a teleport or the first tick, is not a stride)
			_lab_dist += moved
		var loads := 3 if anim == "walk_shovel" else 1      # (walk_shovel: 6 frames a load, the load from his heap)
		var per := n / loads
		frame_i = int(_lab_dist / (float(LAB_STRIDE[anim]) / float(per))) % per + (clampi(_mill_k, 0, 2) * per if loads == 3 else 0)
		return true
	if anim == "shovel":
		frame_i = mini(maxi(_mill_k, 0) * 4 + mill_step(_mill_t), n - 1)
		return true
	if anim == "build" and BUILD_SWING.has(anim_dir):
		_lab_build_t += delta
		frame_i = mini(lab_build_frame(anim_dir, _lab_build_t), n - 1)
		return true
	return false


const DIR_FLIP := [["e", false], ["se", false], ["s", false], ["se", true], ["e", true], ["ne", true], ["n", false], ["ne", false]]


func _set_anim(a: String, force: bool) -> void:
	# getting on or off: the mounted kind's mount strip, the way the horse is turned (_mount_face)
	var sa := mount_strip_art() if a == "mount" else ""
	if a == "mount" and sa == "":
		a = "idle"
	var face := _mount_face if sa != "" and _mount_face != Vector2.ZERO else facing
	if sa == "":
		sa = _strip_art(a)       # (a Missionary bandaging a dismounted rider: his own strips)
	var was_mount := anim == "mount"
	var o := int(round(face.angle() / (PI / 4.0)))
	o = posmod(o, 8)
	if kind == "labourer":
		# the view only changes once he has turned clearly past the edge (his path wobbles around
		# the 22.5 degree lines and the drawings of two views never line up frame for frame)
		if _lab_view >= 0 and o != _lab_view and absf(wrapf(face.angle() - float(_lab_view) * PI / 4.0, -PI, PI)) < PI / 4.0 * 0.5 + 0.14:
			o = _lab_view
		_lab_view = o
	var dir_flip: Array = DIR_FLIP[o]
	var dr: String = dir_flip[0]
	var flip: bool = dir_flip[1]
	if not force and a == anim and dr == anim_dir and flip == anim_flip and sa == _anim_art:
		return
	if a != anim:
		frame_i = 0
		anim_t = 0.0
	var frames: Dictionary = ArtData.UNITS[sa]["frames"]
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
			flip = face.x < 0.0
	anim = a
	anim_dir = dr
	anim_flip = flip
	_anim_art = sa
	var key := a + "_" + dr
	sprite.texture = Game.tex("res://assets/units/%s/%s.png" % [sa, key])
	sprite.hframes = frames.get(key, 1)
	var anchor: Vector2 = ArtData.UNITS[sa]["anchor"]
	# some sheets (aiming up) have extra room on top: the feet stay where they were
	var cell: Vector2i = ArtData.UNITS[sa]["cell"]
	sprite.offset = -anchor - Vector2(0, sprite.texture.get_height() - cell.y)
	sprite.scale = Vector2(-1.0 if flip else 1.0, 1.0) * float(d.get("art_scale", 1.0))
	frame_i = mini(frame_i, sprite.hframes - 1)
	if was_mount != (a == "mount"):
		HorseCoat.apply(self)        # (getting on: the horse's coat on the strip, then his own)


var _aim_t := 0.0


## Where a selected gun of the player's is aiming: at its target, else where it faces; on a
## computer, while an ATTACK order is being given, at the mouse.
func _aim_dir() -> Vector2:
	var c = game.controls
	if c and (c.get("mode") == "attack" or c.get("mode") == "bombard") and not game.demo:
		var m := get_global_mouse_position()
		if m.distance_to(global_position) > 8.0:
			return (m - global_position).normalized()
	if order == "bombard" and order_point.distance_to(global_position) > 8.0:
		return (order_point - center()).normalized()
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
		var mc = game.controls
		var at := Vector2.INF
		if mc and mc.get("mode") == "bombard" and not game.demo:
			at = get_global_mouse_position() - global_position       # (choosing the BOMBARD spot)
		elif order == "bombard":
			at = order_point - global_position
		elif target and is_instance_valid(target) and not target.dead:
			at = (target.position if target is Unit else target.center()) - global_position
		if at != Vector2.INF:
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
	if c and (c.get("mode") == "attack" or c.get("mode") == "bombard") and not game.demo and get_global_mouse_position().distance_to(global_position) <= length:
		aim = get_global_mouse_position() - global_position
	elif order == "bombard":
		aim = order_point - global_position
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


func _on_haul_draw() -> void:
	if haul_t >= 0.0 and not dead and kind == "balloon":
		_draw_haul(_haul_node)


## (a balloon) the pilot's rope and the keg coming up it, drawn on `ci` (over the balloon,
## in this unit's space). The rope runs from his hand in the pulling frame (ArtData
## "pilot_hand" of the facing) down over the front rim of the basket, and from there it
## drops (first 20%), its end coils on the ground (to 35%), then the barrel tied on rises to
## the rim (assets/effects/haul_coil.png, haul_barrel.png).
func _draw_haul(ci: CanvasItem) -> void:
	var f := clampf(haul_t / float(Defs.BALLOON["haul"]), 0.0, 1.0)
	var info: Dictionary = ArtData.UNITS[kind]
	var hand := Vector2(0, sprite.position.y - 12.0)
	var rim := Vector2(0, sprite.position.y - 2.0)
	var hp: Array = info.get("pilot_hand", {}).get(anim_dir, [])
	if hp.size() == 2:
		# cell px -> this unit's space, through the body sprite (offset, flip, scale)
		var xf := sprite.transform
		hand = xf * (sprite.offset + Vector2(hp[0]) - Vector2(0, _pilot_lift()))
		rim = xf * (sprite.offset + Vector2(hp[1]) + Vector2(0.5, 0.5))
	# the rope's end on the ground: under the rim, leaning toward where the keg comes from
	var ground := Vector2(rim.x + clampf((haul_at.x - rim.x) * 0.5, -10.0, 10.0), maxf(haul_at.y, 4.0))
	var rope := Color(0.62, 0.42, 0.22, 0.95)
	var rope_dk := Color(0.36, 0.23, 0.12, 0.95)
	# hand to rim: a slack loop over the basket's lip
	ci.draw_line(hand, rim + Vector2(0.5, -1.0), rope, 1.0)
	ci.draw_line(rim + Vector2(0.5, -1.0), rim + Vector2(1.0, 0.5), rope_dk, 1.0)
	var lip := rim + Vector2(1.0, 0.5)
	if f < 0.2:
		ci.draw_line(lip, lip.lerp(ground, f / 0.2), rope, 1.0)
		return
	if f < 0.35:
		ci.draw_line(lip, ground, rope, 1.0)
		var cc: Vector2i = info.get("haul_coil", Vector2i.ZERO)
		var ct: Texture2D = Game.tex("res://assets/effects/haul_coil.png")
		if ct and cc.x > 0:
			var cix := clampi(int((f - 0.2) / 0.15 * 3.0), 0, 2)
			ci.draw_texture_rect_region(ct, Rect2(ground - Vector2(cc.x * 0.5, cc.y - 1), Vector2(cc)), Rect2(cix * cc.x, 0, cc.x, cc.y))
		return
	var k := (f - 0.35) / 0.65
	var bc: Vector2i = info.get("haul_barrel", Vector2i.ZERO)
	var bt: Texture2D = Game.tex("res://assets/effects/haul_barrel.png")
	# the barrel's bottom: from the ground up to just under the lip (its top at the rim)
	var top := lip + Vector2(0, float(bc.y) if bc.y > 0 else 10.0)
	var kp := ground.lerp(top, k) + Vector2(sin(haul_t * 5.0) * 0.8 * (1.0 - k), 0)
	if bt and bc.x > 0:
		ci.draw_line(lip, kp - Vector2(0, bc.y - 1), rope, 1.0)
		var bi := clampi(int(k * 4.0), 0, 3)
		ci.draw_texture_rect_region(bt, Rect2(kp - Vector2(bc.x * 0.5, bc.y), Vector2(bc)), Rect2(bi * bc.x, 0, bc.x, bc.y))
	else:
		ci.draw_line(lip, kp - Vector2(0, 10), rope, 1.0)
		ci.draw_rect(Rect2(kp + Vector2(-4, -10), Vector2(8, 10)), Color(0.45, 0.28, 0.12))


func _draw() -> void:
	var _p0 := Time.get_ticks_usec()
	_draw_unit()
	Prof.add("unit draw", _p0)


func _draw_unit() -> void:
	if dead and CwAir.falling(self):
		CwAir.draw_fall_shadow(self)
	if dead:
		# a veteran's body (or a seasoned horse's carcass, or a rider's on one): how much
		# essence it holds, for the Brood to see
		var seasoned := (kind == "horse" or is_mounted()) and horse_rank(horse_miles) > 0
		if (kills > 0 or seasoned) and game.corpses.has(self):
			_draw_number(int(game.corpse_value(self)), Vector2(0, -26))
		return
	if selected and (kind == "cannon" or kind == "mortar") and team == game.human and aboard == null:
		_draw_aim()
	# (a Jack in the air: its shadow stays on the ground under it, a little smaller and darker so the leap reads)
	var lifted := Jack.lift(self) if not jump.is_empty() else 0.0
	var shade := 1.0 - clampf(lifted / 160.0, 0.0, 0.3)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, (radius + 2.0) * shade, Color(0, 0, 0, 0.25 + 0.3 * clampf(lifted / 30.0, 0.0, 1.0)))
	if selected:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 24, Color(0.4, 1.0, 0.4, 0.9), 2.0)
	draw_set_transform(Vector2.ZERO)
	if haul_t >= 0.0 and kind == "balloon" and _haul_node == null:
		_draw_haul(self)
	var top := -float(ArtData.UNITS[art]["anchor"].y) * float(d.get("art_scale", 1.0)) - 4.0 - lifted
	if Defs.FLYER.has(kind):
		top = -float(Defs.FLYER[kind]["bar"])       # (the Swift and the Owl: just over the drawn bird, not its shadow or cell)
	if kind == "mortar":
		top = -50.0
	elif kind == "tesla_cart" and tesla_mode != "packed":
		top = -70.0    # above the raised coil's sparks (the packed body: the anchor height)
	elif kind == "cannon":
		top = -64.0 if not ArtData.UNITS["cannon"]["frames"].has("walk_e") else -float(ArtData.UNITS[kind]["anchor"].y) * 0.75
	var bw := radius * 2.4
	draw_health(top, bw, true)
	if owl_t >= 0.0:
		CwAir.draw_morph(self, top, bw)
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
		var gy := top + 5.0 if hp < max_hp else top + 1.0
		if show:
			var ry := gy
			draw_rect(Rect2(-bw * 0.5, ry, bw, 2).grow(0.5), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(-bw * 0.5, ry, bw * clampf(rf, 0.0, 1.0), 2), rcol)
			gy += 3.5
		if kind == "bloater" and gas < 99.5:
			# its gas, only while the sac isn't full (sickly yellow-green; dimmer while deflated)
			draw_rect(Rect2(-bw * 0.5, gy, bw, 2).grow(0.5), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(-bw * 0.5, gy, bw * clampf(gas / 100.0, 0.0, 1.0), 2),
				Color(0.5, 0.56, 0.2) if deflate != "" else Color(0.72, 0.8, 0.2))
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
	if d["faction"] == "clockwork" and not is_worker():
		# the battery on its back, for everyone to see: how much charge is left. A cell
		# strapped onto the body sprite (scripts/battery_pack.gd follows the frames and the
		# charge itself); constructs with no pack in ArtData.PACKS carry none.
		if ArtData.PACKS.has(kind) and sprite.get_node_or_null("Pack") == null:
			var pk: Sprite2D = preload("res://scripts/battery_pack.gd").new()
			pk.name = "Pack"
			pk.set("unit", self)
			sprite.add_child(pk)
	if carrying > 0 and kind == "labourer" and anim != "carry" and anim != "idle_carry":
		draw_circle(Vector2(6, -14), 3, Color(1, 0.85, 0.2))      # (a gold dot where no strip shows the sack)
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


# ------------------------------------------------------------------ horses (Defs.HORSES)

## A gun or wagon can roll only with its horse hitched (everything else always can).
func can_roll() -> bool:
	return harnessed or not Defs.HARNESSED.has(kind)


## (a gun or wagon) the horses in its team (0 to HORSES.team_max).
func horse_count() -> int:
	if not Defs.HARNESSED.has(kind):
		return 0
	return (1 if harnessed else 0) + team_horses.size()


## (a gun or wagon) room for another horse in its team.
func team_room() -> bool:
	return Defs.HARNESSED.has(kind) and not dead and horse_count() < int(Defs.HORSES["team_max"])


## Can this man lead horses by the reins (Labourers, musket soldiers on foot, Messengers,
## Clockwork Winders)?
func can_lead() -> bool:
	return Defs.LEADERS.has(kind) and aboard == null and not dead and not off_field


## Can this man get on a horse (Defs.MOUNTS)?
func can_mount() -> bool:
	return Defs.MOUNTS.has(kind) and aboard == null and not dead and not off_field


## A horse `u` may take: alive, of his side or loose (nobody's: it's his once he has it),
## nobody else coming for it, not walking into a building or to a gun, and not led by
## someone else.
static func horse_free_for(h, u: Unit) -> bool:
	return h != null and is_instance_valid(h) and h is Unit and h.kind == "horse" and not h.dead and not h.off_field \
		and u.team >= 0 and (h.team == u.team or h.team < 0) and h.into == null and (h.claimed == null or h.claimed == u or not _claim_live(h)) \
		and (h.leader == null or h.leader == u or not is_instance_valid(h.leader)) \
		and (h.horse_rid == 0 or h.horse_rid == u.horse_rid)


## Someone is still on his way to take horse h (a claim left behind by a man who died, or
## who was given another order without letting go, doesn't hold it any more).
static func _claim_live(h) -> bool:
	var c = h.claimed
	return c != null and is_instance_valid(c) and not c.dead and c.is_coming_for(h)


## Horses he leads or is going to fetch.
func lead_count() -> int:
	return led.size() + queue.filter(func(o: Dictionary) -> bool: return o["o"] == "lead").size() + (1 if order == "lead" else 0)


## The nearest free horse of ours within `tiles` (not one of `skip`), or null.
func nearest_free_horse(tiles: float, skip: Array = []) -> Unit:
	var best: Unit = null
	var bd := tiles * Defs.TILE
	for o in game.units_near(position, bd):
		if o.kind == "horse" and not skip.has(o) and horse_free_for(o, self) and (o.leader == null or o.leader == self):
			var dd: float = o.position.distance_to(position)
			if dd < bd:
				bd = dd
				best = o
	return best


# ---- leading

## Walk over to a horse and take it by the reins (it then follows him).
func cmd_lead(h) -> bool:
	if not can_lead() or not horse_free_for(h, self) or (h as Unit).leader == self:
		return false
	if led.size() >= int(Defs.HORSES["lead_max"]):
		return false
	_reset_work()
	order = "lead"
	order_target = h
	h.claimed = self
	target = null
	repath_t = 0.0
	return true


func _lead_run(delta: float) -> Vector2:
	var h := order_target as Unit
	if not horse_free_for(h, self) or led.size() >= int(Defs.HORSES["lead_max"]):
		if not _next_order():
			cmd_stop()
		return Vector2.ZERO
	if position.distance_to(h.position) < radius + h.radius + 14.0:
		h.claimed = null
		take_reins(h)
		if not _next_order():
			cmd_stop()
		return Vector2.ZERO
	return _walk_to(h.position, delta)


## The horse is his to lead from now on (at the end of his string).
func take_reins(h: Unit) -> void:
	if h.team < 0 and team >= 0:
		game.steal_horse(h, self)        # a loose horse: his side's now
	if h.leader and is_instance_valid(h.leader) and h.leader != self:
		h.leader.led.erase(h)
	h.leader = self
	h.claimed = null
	if not led.has(h):
		led.append(h)
	if h.order == "move":
		h.cmd_stop()


## RELEASE: let go of every horse he leads (they stay and graze where they stand).
func release_horses() -> void:
	for h in led:
		if is_instance_valid(h) and not h.dead:
			h.leader = null
			h.graze_at = h.position
			h._graze_goal = Vector2.INF
	led.clear()


func _prune_led() -> void:
	led = led.filter(func(h) -> bool: return is_instance_valid(h) and not h.dead and h.leader == self and h.team == team)


## Straight there when close and clear, else along a path.
func _walk_to(p: Vector2, delta: float) -> Vector2:
	if position.distance_to(p) < 140.0 and game.line_clear(position, p):
		path = PackedVector2Array()
		return (p - position).normalized() * speed
	if repath_t <= 0.0 or ((path.is_empty() or path_i >= path.size()) and not path_pending):
		repath_t = 1.5
		_request_path(p)
	return _follow(delta)


# ---- mounting

## Where the man stands in the mounting strip's first frame (tools/import_mount.py): his
## feet from the horse's (the anchor), the horse facing E, SE, S or N; x mirrored facing W
## or SW. Per sprite set where it differs ("" for the rest): the light Dragoon's remade side
## view has him at the horse's shoulder, on its near side. From the front and from behind he
## stands at the horse's side, on the left of the picture.
const MOUNT_MAN := {"": {"e": Vector2(-14, 1), "se": Vector2(-12, -1), "s": Vector2(-16, -2), "n": Vector2(-17, -2)},
	"dragoon": {"e": Vector2(5, 3)},
	"cuirassier": {"s": Vector2(-13, -1), "n": Vector2(-15, -2)},
	"dragoon_armoured": {"s": Vector2(-14, -3)}}


## MOUNT_MAN of sprite set `a`, the strip facing `dr` ("e", "se", "s" or "n").
static func mount_man(a: String, dr: String) -> Vector2:
	var own: Dictionary = MOUNT_MAN.get(a, {})
	return own.get(dr, MOUNT_MAN[""][dr])


## The nearest way side on (the side-on mounting strips are drawn facing E and SE, mirrored
## for W and SW): E or W by `f`'s x, the diagonal when it points well down.
static func side_on(f: Vector2) -> Vector2:
	var sx := 1.0 if f.x >= 0.0 else -1.0
	return Vector2(sx, 1.0).normalized() if f.normalized().y > 0.38 else Vector2(sx, 0.0)


## The way the horse is turned to get on or off: the nearest drawn mounting direction of
## sprite set `a` (S, SE, E, N and the mirrored SW, W). NE and NW go side on (E, W): the
## climb reads best from the side, and he still faces the way he was heading. Without front
## and back strips: side_on.
static func mount_face(a: String, f: Vector2) -> Vector2:
	if f == Vector2.ZERO:
		f = Vector2.RIGHT
	var fr: Dictionary = ArtData.UNITS[a]["frames"] if ArtData.UNITS.has(a) else {}
	var o := posmod(int(round(f.angle() / (PI / 4.0))), 8)
	if o == 2 and fr.has("mount_s"):
		return Vector2.DOWN
	if o == 6 and fr.has("mount_n"):
		return Vector2.UP
	if o == 5 or o == 6 or o == 7:
		return Vector2(1.0 if f.x >= 0.0 else -1.0, 0.0)
	return side_on(f)


## The mounting strip's direction for a horse turned `face` (mount_face): "e", "se", "s" or "n".
static func mount_dir(face: Vector2) -> String:
	if absf(face.x) < 0.3:
		return "n" if face.y < 0.0 else "s"
	return "se" if absf(face.y) > 0.3 else "e"


## The sprite set whose mount strip plays now (the mounted kind's while a man gets on, his
## own while he gets off), or "" (not getting on or off, or no strip drawn for it).
func mount_strip_art() -> String:
	var a := ""
	if work == "mounting" and Defs.MOUNTS.has(kind):
		a = Defs.art_for(String(Defs.MOUNTS[kind]), armoured)
	elif work == "dismounting" and is_mounted():
		a = art
	return a if ArtData.UNITS.has(a) and ArtData.UNITS[a]["frames"].has("mount_e") else ""


## (a horse) hidden while a man gets on it: the mounting strip draws it.
func _hidden_for_mount() -> bool:
	if claimed == null or not is_instance_valid(claimed):
		return false
	return not claimed.dead and claimed.work == "mounting" and claimed.order_target == self \
		and claimed.mount_strip_art() != ""

## Walk to the horse and get on (Defs.HORSES mount s; a Dragoon's own remount is quick).
## `aft`: the order he goes on with once mounted.
func cmd_mount(h, aft := {}) -> bool:
	if not can_mount() or not horse_free_for(h, self):
		return false
	_reset_work()
	order = "mount"
	order_target = h
	h.claimed = self
	after = aft
	target = null
	repath_t = 0.0
	return true


func _mount_run(delta: float) -> Vector2:
	var h := order_target as Unit
	if not horse_free_for(h, self):
		var aft := after
		cmd_stop()
		if not aft.is_empty():
			auto_mount = false       # (no horse: he carries on on foot)
			give(aft)
		return Vector2.ZERO
	if work == "mounting":
		h.velocity = Vector2.ZERO
		work_t -= delta
		if work_t <= 0.0:
			do_mount(h)
		return Vector2.ZERO
	if position.distance_to(h.position) < radius + h.radius + 10.0:
		work = "mounting"
		work_t = float(Defs.HORSES["quick" if auto_mount else "mount"])
		_mount_len = work_t
		path = PackedVector2Array()
		# a horse facing (roughly) S or N stays so: he gets on at its side, seen from the
		# front or from behind; else he turns it side on, him at its near side (the strip
		# draws him on its left facing E / SE, mirrored for W / SW): the side he came from
		var hf: Vector2 = h.facing if h.facing != Vector2.ZERO else Vector2.RIGHT
		var sa := Defs.art_for(String(Defs.MOUNTS[kind]), armoured) if Defs.MOUNTS.has(kind) else art
		_mount_face = mount_face(sa, hf)
		var md := mount_dir(_mount_face)
		if md != "s" and md != "n":
			_mount_face = side_on(Vector2(1.0 if position.x <= h.position.x else -1.0, hf.y))
		facing = _mount_face
		return Vector2.ZERO
	return _walk_to(h.position, delta)


## On the horse: he becomes the mounted unit (Defs.MOUNTS), riding that horse's coat.
func do_mount(h: Unit) -> void:
	if h.team < 0 and team >= 0:
		game.steal_horse(h, self)        # a loose horse: caught
	if h.leader and is_instance_valid(h.leader):
		h.leader.led.erase(h)
	led.erase(h)
	horse_hp = clampf(h.hp / maxf(h.max_hp, 1.0), 0.05, 1.0)
	horse_miles = h.horse_miles
	coat = h.coat
	if horse_rid != 0 and h.horse_rid != horse_rid:
		game.release_rid(team, horse_rid)     # (another horse: the one kept for him is free again)
	horse_rid = 0
	_res_walk = false
	var at := h.position
	game.consume_unit(h)
	# (in the saddle where the horse stood: the mounting strip is drawn there, its last frame
	# on the mounted idle; without a strip, half way)
	position = at if mount_strip_art() != "" else position.lerp(at, 0.5)
	if _mount_face != Vector2.ZERO:
		facing = _mount_face
	var aft := after
	after = {}
	steed = null
	if game.mlog and team >= 0 and not game._first_of.has("%d:mount_%s" % [team, kind]) and Defs.MOUNTS.has(kind):
		game._first_of["%d:mount_%s" % [team, kind]] = true
		game.mlog.add("%s's first %s mounted (%s)" % [game.mlog.who(team), String(d["name"]), String(Defs.UNITS[Defs.MOUNTS[kind]]["name"])])
	morph(String(Defs.MOUNTS[kind]))
	order = "idle"
	order_target = null
	work = ""
	leash_from = position
	if team == game.human:
		Sfx.play_any(["ui/click", "click"], position)
	if not aft.is_empty():
		give(aft)


## DISMOUNT (Defs.HORSES dismount s; `quick`: a Dragoon's own, to fire). The horse stands
## beside him, of his side, unled. `aft`: what he does once on foot.
func cmd_dismount(quick := false, aft := {}) -> void:
	if game.net_forward(self, "cmd_dismount", [quick, aft]): return
	if not is_mounted() or aboard:
		return
	_reset_work()
	order = "dismount"
	work = "dismounting"
	work_t = float(Defs.HORSES["quick" if quick else "dismount"])
	_mount_len = work_t
	# he turns his horse side on to get off (the strip plays backwards): a Dragoon getting off
	# to fire gets off on the side he's going to shoot at (where his strip has him behind
	# the horse's middle, it turns its tail that way)
	var f := facing if facing != Vector2.ZERO else Vector2.RIGHT
	# (facing roughly S or N he gets off that way, seen from the front or behind)
	var behind: bool = mount_man(art, "e").x < 0.0
	_mount_face = mount_face(art, Vector2(-f.x, f.y) if quick and behind else f)
	facing = _mount_face
	after = aft
	target = null
	order_target = null
	# (the computer's men always get back on by themselves; yours only after a Dragoon's own dismount)
	auto_mount = quick or game.ais.any(func(a) -> bool: return a.team == team)


func _dismount_run(delta: float) -> Vector2:
	work_t -= delta
	if work_t <= 0.0:
		do_dismount()
	return Vector2.ZERO


func do_dismount() -> void:
	var side := Vector2(-facing.y, facing.x)
	if side == Vector2.ZERO:
		side = Vector2.RIGHT
	var f := facing if facing != Vector2.ZERO else Vector2.RIGHT
	var spot: Vector2
	if mount_strip_art() != "":
		# the horse stays where the strip drew it (under him) and he stands where its first
		# frame has him, at its near side
		spot = game.resolve_terrain(position, position, 11.0, team)
		var man: Vector2 = mount_man(art, mount_dir(_mount_face))
		if _mount_face.x < 0.0:
			man.x = -man.x
		position = game.resolve_terrain(position + man, position, radius, team)
	else:
		# (the horse stands a step behind him, a little to one side: clear of his line of fire,
		# and not drawn over him so he looks still mounted)
		spot = game.resolve_terrain(position - f * (radius + 16.0) - side * 6.0, position, 11.0, team)
	var h := game._add_unit("horse", team, spot)
	h.coat = coat if coat != "" else HorseCoat.pick()
	HorseCoat.apply(h)
	h.horse_miles = horse_miles
	h.apply_horse_vet()
	h.hp = h.max_hp * horse_hp
	h.facing = facing
	h._set_anim("idle", true)       # (turned the strip's way at once: not its first frames facing S)
	h.graze_at = spot
	h._graze_t = 4.0
	h.visible = visible
	var aft := after
	after = {}
	horse_miles = 0.0
	morph(String(Defs.FOOT[kind]))
	steed = h
	order = "idle"
	work = ""
	leash_from = position
	if not aft.is_empty():
		give(aft)


## Become another kind in place (mounting, dismounting): he keeps his armour, kit, kills,
## powder, hp share, reload and orders' bookkeeping; his stats and sprites change.
func morph(k: String) -> void:
	var frac := hp / maxf(max_hp, 1.0)
	var arm := armoured
	kind = k
	d = Defs.UNITS[k].duplicate(true)
	armoured = false
	armor = float(d["armor"])
	sight = int(d["sight"])
	radius = float(d["radius"])
	speed = float(d["speed"])
	max_hp = float(d["hp"])
	if is_mounted():
		max_hp += horse_bonus_hp(horse_miles)      # a seasoned horse under him
	art = Defs.art_for(k, false) if ArtData.UNITS.has(Defs.art_for(k, false)) else k
	if arm:
		put_on_armour()
	hp = maxf(1.0, max_hp * frac)
	_pmax = max_powder()
	powder = minf(powder, _pmax)
	mode = ""
	phase = ""
	target = null
	run_t = 0.0
	if not HorseCoat.has_horse(k):
		coat = ""
	game.apply_drills(self)
	_draw_key = Vector4i(-1, -1, -1, -1)
	if sprite:
		HorseCoat.apply(self)
		_apply_tint()
		_set_anim("idle", true)
	_update_feather()
	queue_redraw()


## Back on his own horse (or another free one close by) to carry out `aft`. False: no horse.
func _try_remount(aft: Dictionary) -> bool:
	var h: Unit = steed if horse_free_for(steed, self) and steed.position.distance_to(position) < 5.0 * Defs.TILE else null
	if h == null:
		h = nearest_free_horse(3.0)
	if h == null:
		return false
	return cmd_mount(h, aft)


## A Dragoon on foot after his own dismount: back in the saddle when there's nothing to shoot
## and somewhere to go, or when his target got away.
func _foot_dragoon(delta: float) -> void:
	if order == "amove":
		_lonely_t = _lonely_t + delta if target == null else 0.0
		if _lonely_t > 1.2 and position.distance_to(order_point) > 4.0 * Defs.TILE and _musket_target(_range()) == null:
			_lonely_t = 0.0
			_try_remount({"o": "amove", "p": order_point})
	elif order == "attack":
		var e = order_target
		if e and is_instance_valid(e) and not e.dead and e.edge_distance(position) - radius > _range() + 60.0:
			_try_remount({"o": "attack", "e": e})


## The nearest enemy a musket could fire on from here (in range and seen), or null.
func _musket_target(r: float) -> Entity:
	if hold_fire:
		return null              # HOLD FIRE: nothing to shoot at on his own
	var best: Entity = null
	var bd := INF
	for o in game.units_near(position, r + 60.0):
		if o.dead or o.off_field or not game.hostile(o.team, team) or o.untouchable() or o.kind == "horse":
			continue
		var dd: float = o.edge_distance(position) - radius
		if dd <= r and dd < bd and game.target_seen(team, o, position):
			bd = dd
			best = o
	if best:
		return best
	for b in game.buildings:
		if b.dead or b.ghost or not game.hostile(b.team, team) or b.kind == "wall" or b.kind == "gate":
			continue
		var dd: float = b.edge_distance(position) - radius
		if dd <= r and dd < bd and game.target_seen(team, b, position):
			bd = dd
			best = b
	return best


## A mounted Dragoon on ATTACK or attack-move: rides to musket range, then dismounts (quick)
## to fire on foot.
func _dragoon_tick(delta: float) -> Vector2:
	var rng := float(Defs.UNITS[Defs.FOOT[kind]]["range"])
	if order == "d_attack":
		var e = order_target
		if e == null or not is_instance_valid(e) or e.dead or not game.hostile(e.team, team) or e.untouchable():
			if not _next_order():
				cmd_stop()
			return Vector2.ZERO
		if e.edge_distance(position) - radius <= rng - 8.0 and game.target_seen(team, e, position):
			cmd_dismount(true, {"o": "attack", "e": e})
			return Vector2.ZERO
		return _walk_to(e.position if e is Unit else game.approach_point(e, position), delta)
	if scan_t <= 0.0:
		scan_t = 0.3
		if _musket_target(rng - 8.0) != null:
			cmd_dismount(true, {"o": "amove", "p": order_point})
			return Vector2.ZERO
	var want := _follow(delta)
	if _arrived():
		_finish_move()
	return want


# ---- the horse itself

func _horse_tick(delta: float, want: Vector2) -> Vector2:
	if bolt_t > 0.0:
		# bolting (its rider just fell): it gallops off, then calms down and grazes there
		var held := leader != null or into != null or order == "move" \
			or (claimed != null and is_instance_valid(claimed) and not claimed.dead and claimed.is_coming_for(self))
		bolt_t -= delta
		if held or bolt_t <= 0.0 or position.distance_to(bolt_to) < 10.0:
			bolt_t = 0.0
			bolt_to = Vector2.INF
			graze_at = position
			_graze_t = randf_range(1.5, 3.0)
			_steal_t = 0.0
		else:
			speed = float(d["speed"]) * float(Defs.HORSES["bolt_speed"])
			return _walk_to(bolt_to, delta)
	_steal_t -= delta
	if _steal_t <= 0.0:
		_steal_t = float(Defs.HORSES["scan"])
		_steal_check()
		if dead:
			return Vector2.ZERO
	if into != null:
		return _horse_into(delta)
	if leader != null:
		if not is_instance_valid(leader) or leader.dead or leader.team != team or leader.aboard != null or not leader.led.has(self):
			leader = null
			graze_at = position
		else:
			return _follow_leader(delta)
	if order == "move":
		graze_at = order_point
		_graze_goal = Vector2.INF
		return want
	if claimed != null and is_instance_valid(claimed) and not claimed.dead and claimed.is_coming_for(self):
		return Vector2.ZERO          # stands still for the man coming to take it
	claimed = null
	# grazing: a few steps now and then round where it was left
	if graze_at == Vector2.INF:
		graze_at = position
	_graze_t -= delta
	if _graze_t <= 0.0:
		_graze_t = randf_range(3.0, 7.0)
		var w := float(Defs.HORSES["wander"])
		_graze_goal = graze_at + Vector2(randf_range(-w, w), randf_range(-w * 0.6, w * 0.6))
		if not game._clear_at(_graze_goal, radius, team):
			_graze_goal = Vector2.INF
	if _graze_goal != Vector2.INF and position.distance_to(_graze_goal) > 4.0:
		return (_graze_goal - position).normalized() * 26.0
	return Vector2.ZERO


## Led: the first horse walks at the man's side, the others in a string behind it.
func _follow_leader(delta: float) -> Vector2:
	var i := leader.led.find(self)
	var goal: Vector2
	var lf: Vector2 = leader.facing if leader.facing != Vector2.ZERO else Vector2.DOWN
	if i <= 0:
		goal = leader.position + Vector2(-lf.y, lf.x) * (leader.radius + radius + 4.0) - lf * 6.0
	else:
		var ahead: Unit = leader.led[i - 1]
		var af: Vector2 = ahead.facing if ahead.facing != Vector2.ZERO else lf
		goal = ahead.position - af * (radius * 2.0 + 4.0)
	speed = maxf(float(d["speed"]), leader.speed * 1.35)
	# the spot beside him may lie inside a wall or a gate post (he is in a gateway one tile wide,
	# the horse at his side is not): take the spot behind him, else his own
	if not game._clear_at(goal, radius, team):
		goal = leader.position - lf * (leader.radius + radius + 6.0)
		if not game._clear_at(goal, radius, team):
			goal = leader.position
	var to := goal - position
	var dist := to.length()
	# the leash has a length: a horse that is too far, or has made no headway for a while (jammed
	# behind a crowd or a building), is brought back beside its leader instead of stretching the rope
	if dist > LEASH_MAX or (dist > 40.0 and position.distance_to(_lead_last) < 6.0 * delta + 1.0):
		_lead_stuck += delta
	else:
		_lead_stuck = 0.0
	_lead_last = position if _lead_stuck == 0.0 or position.distance_to(_lead_last) > 6.0 else _lead_last
	if dist > LEASH_MAX * 1.5 or _lead_stuck > 2.5:
		_lead_stuck = 0.0
		_snap_to_leader(goal)
		return Vector2.ZERO
	if dist > 180.0 or not _walk_straight(goal):
		# far behind, or a wall corner or gate post between it and its leader (a gate is a gap one
		# tile wide: a straight line from the side of the road runs into the wall): find the way
		if repath_t <= 0.0 or ((path.is_empty() or path_i >= path.size()) and not path_pending):
			repath_t = 0.4 if dist <= 180.0 else 1.5
			_request_path(leader.position if dist > 40.0 else goal)
		if path_pending and dist <= 180.0:
			return Vector2.ZERO
		return _follow(delta)
	if not path.is_empty():
		path = PackedVector2Array()
		path_i = 0
	if dist < 3.0:
		facing = facing.lerp(lf, clampf(delta * 4.0, 0.0, 1.0)).normalized()
		return Vector2.ZERO
	return to.normalized() * minf(speed, dist * 3.0 + 6.0)


## Can it walk the straight line to `p` (its own side's gates open to it, walls and cliffs not)?
func _walk_straight(p: Vector2) -> bool:
	var dist := position.distance_to(p)
	var steps := int(dist / 8.0) + 1
	for s in steps + 1:
		if not game._clear_at(position.lerp(p, float(s) / float(steps)), radius, team):
			return false
	return true


const LEASH_MAX := 170.0
var _lead_stuck := 0.0
var _lead_last := Vector2.ZERO


## Put a led horse back beside its leader on the nearest clear spot.
func _snap_to_leader(goal: Vector2) -> void:
	var best := Vector2.INF
	for r in [0.0, 20.0, 36.0, 52.0, 72.0]:
		for k in 8:
			var p: Vector2 = goal + Vector2.RIGHT.rotated(k * TAU / 8.0) * r
			if game._clear_at(p, radius, team):
				best = p
				break
		if best != Vector2.INF:
			break
	if best != Vector2.INF:
		position = best
		path.clear()
		path_i = 0


## Walking into a building (taken for a recruit or a gun) or to a gun (to be harnessed).
func _horse_into(delta: float) -> Vector2:
	var e := into
	_into_t += delta
	if e == null or not is_instance_valid(e) or e.dead or e.team != team:
		into = null
		graze_at = position
		return Vector2.ZERO
	if e is Building:
		if horse_rid != 0 and game.rid_owner(team, horse_rid) != e:
			into = null              # (its recruit was cancelled: it stays where it is, free; or he came out
			graze_at = position      # on foot meanwhile: it stays kept for him, he mounts it)
			if game.rid_owner(team, horse_rid) == null:
				horse_rid = 0
			return Vector2.ZERO
		var far: float = e.edge_distance(position)
		if far < 4.0 or (_into_t > 4.0 and far < 40.0) or _into_t > 90.0:
			if horse_rid != 0:
				game.horse_arrived(e, self)
			game.consume_unit(self)
			return Vector2.ZERO
		if far >= 40.0:
			return _walk_to(game.approach_point(e, position), delta)    # (a reserved horse comes by itself from the breeder)
		speed = 60.0
		return (e.center() - position).normalized() * speed
	var g := e as Unit
	if not g.team_room():
		into = null
		graze_at = position
		return Vector2.ZERO
	if position.distance_to(g.position) < radius + g.radius + 12.0:
		g.harness(self)
		return Vector2.ZERO
	return _walk_to(g.position, delta)


## Taken for a recruit at this building: it walks in and is gone (Game.train).
func walk_into(e: Entity) -> void:
	if team < 0 and e.team >= 0:
		game.steal_horse(self, e)        # a loose horse sent for by a gun (HARNESS): its side's now
	if leader and is_instance_valid(leader):
		leader.led.erase(self)
	leader = null
	claimed = null
	into = e
	_into_t = 0.0
	order = "idle"
	path = PackedVector2Array()
	if selected:
		game.selection.erase(self)
		selected = false


## Who can take a horse that's left alone: Crown men (on foot or riding; not guns, wagons
## or balloons) and Clockwork Winders. Never the Brood.
static func can_steal(o: Unit) -> bool:
	if o.kind == "winder":
		return true
	return o.d["faction"] == "crown" and o.kind != "horse" and not Defs.HARNESSED.has(o.kind) and o.kind != "balloon"


## Left alone (nobody leading it or coming for it, none of its side within HORSES.guard
## tiles) with an enemy man right beside it: it changes hands.
func _steal_check() -> void:
	if leader != null or into != null or (claimed and is_instance_valid(claimed) and not claimed.dead and claimed.is_coming_for(self)):
		return
	if team < 0:
		# a loose horse (nobody's): the first man who can lead horses to walk up takes it
		var near: Unit = null
		var nd := INF
		for o in game.units_near(position, float(Defs.HORSES["steal"]) + radius + 24.0):
			if o == self or o.dead or o.off_field or o.team < 0 or o.is_air() or not can_steal(o):
				continue
			var dd: float = o.position.distance_to(position)
			if dd <= float(Defs.HORSES["steal"]) + o.radius + radius and dd < nd:
				nd = dd
				near = o
		if near:
			game.steal_horse(self, near)
		return
	var guard := float(Defs.HORSES["guard"]) * Defs.TILE
	var thief: Unit = null
	for o in game.units_near(position, guard + radius):
		if o == self or o.dead or o.off_field or o.kind == "horse":
			continue
		if game.allied(o.team, team):
			return                   # guarded
		if thief == null and game.hostile(o.team, team) and can_steal(o) and not o.is_air() \
				and o.position.distance_to(position) <= float(Defs.HORSES["steal"]) + o.radius + radius:
			thief = o
	if thief:
		game.steal_horse(self, thief)


# ---- guns and wagons

## (a gun or wagon) a horse is hitched: it can move again.
func harness(h: Unit) -> void:
	if dead or not team_room():
		return
	if harnessed:
		# another horse for the team (in front of the others)
		team_horses.append({"coat": h.coat, "hp": clampf(h.hp / maxf(h.max_hp, 1.0), 0.05, 1.0), "m": h.horse_miles})
		game.consume_unit(h)
		if game.mlog and not game._first_of.has("%d:team" % team):
			game._first_of["%d:team" % team] = true
			game.mlog.add("%s's first %s with a team of %d horses" % [game.mlog.who(team), String(d["name"]), horse_count()])
		queue_redraw()
		if team == game.human:
			game.float_text(position + Vector2(0, -40), "%d horses" % horse_count(), Color(0.9, 0.85, 0.6))
		return
	harnessed = true
	coat = h.coat
	horse_hp = clampf(h.hp / maxf(h.max_hp, 1.0), 0.05, 1.0)
	horse_miles = h.horse_miles
	game.consume_unit(h)
	HorseCoat.apply(self)
	if team == game.human:
		game.float_text(position + Vector2(0, -40), "harnessed", Color(0.9, 0.85, 0.6))


## RELEASE HORSE: the horse is unhitched and stands beside it, free (for a rider). The gun
## or wagon can't move without one; a gun goes straight to its set-up pose and still fires.
func release_horse() -> Unit:
	if not Defs.HARNESSED.has(kind) or not harnessed or dead or aboard:
		return null
	var side := Vector2(-facing.y, facing.x)
	if side == Vector2.ZERO:
		side = Vector2.DOWN
	var spot := game.level_spot(position, position + side * (radius + 30.0), 11.0, team)   # (never down a cliff)
	var h := game._add_unit("horse", team, spot)
	h.graze_at = spot
	h.visible = visible
	if not team_horses.is_empty():
		# one of the extra horses first (the front one): it keeps rolling, a little slower
		var th: Dictionary = team_horses.pop_back()
		h.coat = String(th.get("coat", "")) if HorseCoat.COATS.has(String(th.get("coat", ""))) else HorseCoat.pick()
		HorseCoat.apply(h)
		h.horse_miles = float(th.get("m", 0.0))
		h.apply_horse_vet()
		h.hp = h.max_hp * clampf(float(th.get("hp", 1.0)), 0.05, 1.0)
		queue_redraw()
		return h
	h.coat = coat if coat != "" else HorseCoat.pick()
	HorseCoat.apply(h)
	h.horse_miles = horse_miles
	h.apply_horse_vet()
	h.hp = h.max_hp * horse_hp
	horse_miles = 0.0
	harnessed = false
	if order in ["move", "amove"]:
		cmd_stop()
	path = PackedVector2Array()
	HorseCoat.apply(self)
	return h


## A gun's / wagon's extra team horses (team_horses) drawn as harnessed horses
## (assets/units/horse_team: tools/import_horse_team.py), hitched in pairs: the vehicle's own
## horse (in its sprite) is the left horse of the wheel pair; extra horse 1 walks at its right,
## 2 and 3 are the leading pair one horse length ahead (with only 2 extras the one leader
## walks in the middle, ahead of the pair). team_horses[i] is slot i: the front one (popped
## first when it falls or is released) is the last. Each keeps its own coat (team shader +
## the strip's coat mask). Hidden while a gun is set up (its own horse is led off then too).
## Per vehicle: the team's size (its own horse is drawn smaller than the riderless horse), the
## strip shown for each drawn direction (side-on cannon art for SE / NE), and where its own
## horse's hooves stand per animation and direction (from its coat masks, unflipped; the
## wagon's back view draws its horse below the wagon: its team goes ahead of the wagon's top).
const TEAM_LOOK := {
	"cannon": {"scale": 0.85, "view": {"se": "e", "ne": "e"},
		"own": {"walk": {"s": Vector2(-2, 9), "e": Vector2(49, -7), "n": Vector2(-2, -36)}}},
	"mortar": {"scale": 0.82, "view": {},
		"own": {"walk": {"s": Vector2(0, 10), "se": Vector2(15, 10), "e": Vector2(24, -3), "ne": Vector2(15, -8), "n": Vector2(-2, 3)},
			"idle_packed": {"s": Vector2(2, -2), "se": Vector2(-2, -3), "e": Vector2(6, -1), "ne": Vector2(6, -8), "n": Vector2(-2, -17)}}},
	"powder_wagon": {"scale": 0.62, "view": {"ne": "e"},
		"own": {"walk": {"s": Vector2(4, 7), "se": Vector2(6, 7), "e": Vector2(12, 5), "n": Vector2(-6, -50)}}},
}
## Per strip direction (unflipped, at the team horse's full size): one horse length ahead in
## the direction of travel, and from a horse to its pair-mate on its right.
const TEAM_STEP := {
	"s": [Vector2(0, 34), Vector2(-22, 0)],
	"se": [Vector2(38, 22), Vector2(-15, 9)],
	"e": [Vector2(54, 0), Vector2(-10, 10)],
	"ne": [Vector2(38, -22), Vector2(15, 9)],
	"n": [Vector2(0, -30), Vector2(22, 0)],
}
var _team_sprites: Array[Sprite2D] = []
var _team_shown: PackedStringArray = []     # the coat each team sprite was made with
var _team_dir := ""                          # the layout the sprites stand in: direction,
var _team_flip := false                      # mirrored,
var _team_pose := ""                         # and which own-horse table (walk / idle_packed)
var _team_t := 0.0


func _update_team(delta: float, fps: float) -> void:
	var look: Dictionary = TEAM_LOOK.get(kind, {})
	var n := team_horses.size()
	var show := not look.is_empty() and not dead and n > 0 \
		and not ((kind == "cannon" or kind == "mortar") and tesla_mode != "packed")
	if not show:
		for s in _team_sprites:
			s.visible = false
		if n == 0 and not _team_sprites.is_empty():
			_clear_team()
		return
	# the sprites, one per extra horse in its coat (remade when the team changes)
	var changed := n != _team_sprites.size()
	if not changed:
		for i in n:
			if String(team_horses[i].get("coat", "")) != _team_shown[i]:
				changed = true
				break
	var pose := "idle_packed" if kind == "mortar" and anim != "walk" else "walk"
	var view: String = look["view"].get(anim_dir, anim_dir)
	if changed or view != _team_dir or anim_flip != _team_flip or pose != _team_pose:
		_layout_team(look, view, pose, changed)
	var moving := anim == "walk" and velocity.length() >= 10.0
	if moving:
		_team_t += delta * fps
	for i in n:
		var s := _team_sprites[i]
		s.visible = true
		s.frame = (int(_team_t) + i * 2) % s.hframes if moving else 0


func _clear_team() -> void:
	for s in _team_sprites:
		s.queue_free()
	_team_sprites.clear()
	_team_shown.clear()
	_team_dir = ""


func _layout_team(look: Dictionary, view: String, pose: String, remake: bool) -> void:
	if remake:
		_clear_team()
		for th in team_horses:
			var s := Sprite2D.new()
			s.centered = false
			var m := ShaderMaterial.new()
			m.shader = TEAM_SHADER
			var c := String(th.get("coat", ""))
			m.set_shader_parameter("coat", -1 if c == "dark" or not HorseCoat.COATS.has(c) else HorseCoat.COATS.find(c))
			m.set_shader_parameter("coat_ramps", HorseCoat.RAMPS)
			s.material = m
			add_child(s)
			_team_sprites.append(s)
			_team_shown.append(c)
	_team_dir = view
	_team_flip = anim_flip
	_team_pose = pose
	var sc: float = look["scale"]
	var own_tab: Dictionary = look["own"].get(pose, look["own"]["walk"])
	var own: Vector2 = own_tab.get(view, own_tab.get(anim_dir, Vector2.ZERO))
	var step: Array = TEAM_STEP[view]
	var fwd: Vector2 = step[0] * sc
	var side: Vector2 = step[1] * sc
	var n := _team_sprites.size()
	var tex := Game.tex("res://assets/units/horse_team/walk_%s.png" % view)
	var anchor: Vector2 = ArtData.UNITS["horse_team"]["anchor"]
	var nf: int = ArtData.UNITS["horse_team"]["frames"].get("walk_" + view, 1)
	var mask := HorseCoat.mask_for(tex)
	for i in n:
		var p := own + side          # the wheel horse's pair-mate
		if i == 1:
			p = own + fwd + (side * 0.5 if n == 2 else Vector2.ZERO)    # a lone leader in the middle
		elif i == 2:
			p = own + fwd + side
		if anim_flip:
			p.x = -p.x
		var s := _team_sprites[i]
		s.texture = tex
		s.hframes = nf
		s.offset = -anchor
		s.position = p
		s.scale = Vector2(-sc if anim_flip else sc, sc)
		(s.material as ShaderMaterial).set_shader_parameter("horse_mask", mask)
	# draw order by depth (y), farther first: those standing farther back than the vehicle's
	# feet (ahead of a gun facing north) behind its sprite, the others over it
	var order: Array[Sprite2D] = _team_sprites.duplicate()
	order.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.position.y < b.position.y)
	for s in order:
		move_child(s, get_child_count() - 1)
	for s in order:
		if s.position.y < -2.0:
			move_child(s, sprite.get_index())


## A new Horseman, trained on foot: he goes to the horse kept for him (to its breeder while
## it's still being trained), gets on and rides to his Barracks' rally point. With no horse
## left for him (killed, stolen, its breeder lost) he stays on foot (MOUNT another).
func _wait_horse() -> void:
	if order == "mount" or work == "mounting":
		return
	var mine := game.ais.any(func(a) -> bool: return a.team == team)     # (the computer's always go)
	if not (order == "idle" or (order == "move" and _res_walk) or mine):
		return                           # (sent somewhere else meanwhile: he goes on when idle)
	var h: Unit = game.reserved_horse(team, horse_rid)
	if h:
		# (with haulers about the horse is brought to him: he gets on once it stands beside him)
		if horse_free_for(h, self) and (h.position.distance_to(position) < 100.0 or not game.hauler_serves_rid(team, horse_rid)):
			_res_walk = false
			cmd_mount(h, {"o": "amove", "p": rally_after} if rally_after != Vector2.INF else {})
		return
	var br: Building = game.rid_breeder(team, horse_rid)
	if br == null:
		horse_rid = 0
		_res_walk = false
		return
	if game.hauler_serves_rid(team, horse_rid):
		return                           # (a hauler fetches it from the breeder when it's trained)
	var going := order == "move" and br.edge_distance(order_point) < 3.0 * Defs.TILE + 40.0
	if (order == "idle" or mine) and not going and br.edge_distance(position) > 3.0 * Defs.TILE:
		cmd_move(game.approach_point(br, position))
		_res_walk = true


# ---- drawing

## (a horse) where its bridle is, from its feet, per drawn facing (art/crown/horse_riderless.png
## as tools/import_horse_units.py places it; facing right, x mirrored when flipped).
const BRIDLE := {"e": Vector2(19, -36), "se": Vector2(8, -37), "s": Vector2(0, -36), "ne": Vector2(5, -44), "n": Vector2(0, -44)}


func _draw_rein() -> void:
	if leader == null or not is_instance_valid(leader) or dead or not visible:
		return
	var b: Vector2 = BRIDLE.get(anim_dir, Vector2(10, -27))
	if anim_flip:
		b.x = -b.x
	var i := leader.led.find(self)
	var hand: Vector2
	if i <= 0:
		var up := -34.0 if leader.is_mounted() else -15.0
		hand = leader.position + Vector2(5.0 if leader.facing.x >= 0.0 else -5.0, up) - position
	else:
		var ahead: Unit = leader.led[i - 1]
		hand = ahead.position + Vector2(0, -18) - position      # tied to the saddle of the one ahead
	if b.distance_to(hand) > 70.0:
		hand = b + (hand - b).normalized() * 70.0      # (the rope has a length: never a huge line across the map)
	var mid := (b + hand) * 0.5 + Vector2(0, minf(6.0, b.distance_to(hand) * 0.12))
	var col := Color(0.42, 0.27, 0.13, 0.95)
	_rein.draw_polyline(PackedVector2Array([b, mid, hand]), col, 1.0)


## A stand-in sprite's tint (Defs.TEMP_ART "tint", for a unit borrowing another's sprites).
func _apply_tint() -> void:
	var m := sprite.material as ShaderMaterial if sprite else null
	if m:
		m.set_shader_parameter("tint", Defs.TEMP_ART.get(kind, {}).get("tint", Vector3.ONE))


## (a dismounted horseman, TEMP_ART "feather") a plume on his hat, so he can be told from a
## Musketeer until his own sprites come.
func _update_feather() -> void:
	var want: bool = Defs.TEMP_ART.get(kind, {}).get("feather_armoured" if armoured else "feather", false) and sprite != null
	if want and _feather == null:
		_feather = Node2D.new()
		_feather.draw.connect(func() -> void:
			var top := -float(ArtData.UNITS[art]["anchor"].y) + 2.0
			_feather.draw_line(Vector2(1, top + 3), Vector2(5, top - 3), Color(0.95, 0.95, 0.9), 2.0)
			_feather.draw_line(Vector2(4, top - 2), Vector2(7, top - 5), Color(0.85, 0.15, 0.12), 2.0))
		sprite.add_child(_feather)
	if _feather:
		_feather.visible = want
		_feather.queue_redraw()
