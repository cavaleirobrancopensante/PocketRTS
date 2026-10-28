extends RefCounted
## AI round 5 (docs/ai_round5.md). Two jobs, kept out of scripts/ai.gd's own functions (other jobs edit those):
##  A. The Crown computer against the Clockwork computer plays like the owner's winning games: Musketeers the
##     bulk, Labourers capped once the army falls behind, no idle horses, no endless Missionaries, the army
##     holds BEHIND its ramp wall when a bigger wave comes, no attack into a much bigger army it has seen, no
##     second hall before there is an army to hold it, and a Horseman rush that is rarer and gives up sooner.
##  B. The Clockwork computer against Horsemen: the Winders near a raid group up and fight together (the
##     riders are faster than them: running only feeds them one by one), the nearest Clock Soldiers walk as
##     one group to the workers (never a rider chase), and with enough soldiers a few HOLD the top of the ramp.
##     Fleeing stays the answer to Balloons and to armies they cannot fight.
## Every rule here is the computer's; no unit, building or cost number changes.

var ai = null                   # the AI (scripts/ai.gd)
var on := true                  # (tests switch round 5 off for a "before" number)
var _only := ""                 # (study games: "crown" = part A only, "clock" = part B only)

# ---- B: the Clockwork against Horsemen
const RAIDER_SPEED := 95.0      # an armed ground enemy this fast is a rider (AI.FAST_SPEED)
const ANCHOR_R := 420.0         # the workers fight riders this close to their press / hall, no further
const POOL_R := 340.0           # Winders this close to the raid join the group
const RATIO_HELP := 0.5         # they fight with this share of the riders' strength when soldiers are coming ...
const RATIO_ALONE := 0.9        # ... and with this much when nobody is
const GUARD_PER_RIDER := 3      # Clock Soldiers sent to the workers per rider (a group, never one)
const GUARD_MIN := 3
const GUARD_MAX := 8
const GUARD_LEASH := 330.0      # a guard further than this from the workers walks back (it does not chase)
const GUARD_CALM := 8.0         # s with no rider near the workers before the guard goes home
const RAMP_AT := 10             # Clock Soldiers (not in a wave) before the ramp gets a hold post ...
const RAMP_MORE_AT := 16        # ... and a fourth from this many
const RAMP_WIND := 0.35         # a ramp guard running down below this is swapped for a fresh one
const HORSE_MEMORY := 240.0     # riders seen this long ago still count (the ramp post stays)

var _guards: Dictionary = {}    # Unit -> {"anchor": Vector2, "t": clock of the last rider near}
var _ramp: Array = []           # ramp hold guards
var _ramp_spots: Array = []     # their cells' centres (computed once)
var _ramp_done := false
var _horse_t := -9999.0         # when riders were last seen
var _said := {}                 # (match log lines said once)

# ---- A: the Crown against the Clockwork
const LAB_ARMY_SHARE := 0.6     # from 4:00 no more Labourers while the army's supply is under this share of them ...
const LAB_FLOOR := 30           # ... once there are this many (24 and 0.8 starved the economy: halls fell, soil ran out)
const LAB_CAP := 42             # never more Labourers than this (the owner had 36-45 at 10-13 min)
const ATTACK_EDGE := 1.2        # a wave goes out only worth this much times the biggest army seen lately ...
const ATTACK_ANYWAY := 60       # ... or at this much supply
const HOLD_NEAR := 12.0         # tiles from the ramp: only a wave this close to the wall is waited for behind it
const HOLD_IN := 0.85           # a wave worth this share of our army or more: the army holds behind the wall
const HOLD_OUT := 0.7           # (once holding: until the wave is worth less than this share)
const HALL_ARMY := 14           # the second hall waits for this much army supply ...
const HALL_SEEN := 0.9          # ... worth this share of the biggest enemy army seen
const HALL_DRY := 0.3           # (unless the main's soil is nearly gone)
const BREEDER_VS_CLOCK := 0.1   # the Horse Breeder opening against the Clockwork (it is 0.3 otherwise)

var _vs_clock := -1             # (cache) -1 unknown, 0 no, 1 yes
var _hold_until := -1.0
var _hold_spots: Array = []     # [musket spot, gun spot] behind the wall (computed once)
var _hold_done := false


var _ramps: Array = []          # (cache) AI._ramp_bands(): the ramps up to the main, nearest first
var _ramps_done := false


func _init(owner_ai) -> void:
	ai = owner_ai
	var args := OS.get_cmdline_user_args()
	if args.has("r5:off"):
		on = false              # (study games: `-- ... r5:off` plays the "before" computer, the same as 0.14.90)
	elif args.has("r5:crown"):
		_only = "crown"         # (`r5:crown`: part A only, the Clockwork as before)
	elif args.has("r5:clock"):
		_only = "clock"         # (`r5:clock`: part B only, the Crown as before)


func _bands() -> Array:
	if not _ramps_done:
		_ramps_done = true
		_ramps = ai._ramp_bands()
	return _ramps


func _log(key: String, msg: String) -> void:
	if _said.has(key) or ai.game.mlog == null:
		return
	_said[key] = true
	ai.game.mlog.add("%s %s" % [ai.game.mlog.who(ai.team), msg])


# ============================================================ A. the Crown

## The Crown against a Clockwork enemy (any of its enemies), Normal and up.
func vs_clock() -> bool:
	if not on or _only == "clock" or ai.difficulty < 1 or not ai._crown():
		return false
	if _vs_clock < 0:
		_vs_clock = 0
		_bands()                # (the ramps now, before the wall stands on the band: AI._ramp_bands skips built cells)
		for t in ai.game.enemies_of(ai.team):
			if ai.game.faction_of(t) == "clockwork":
				_vs_clock = 1
	return _vs_clock == 1


## The chance of the Horse Breeder opening (AI._ready). Against the Clockwork the rush lost every game:
## its Clock Soldiers come out at 1:50 and the computer switches to an army on seeing a Horseman.
func breeder_chance(normal: float) -> float:
	if not on or _only == "clock" or ai.game.faction_of(ai.team) != "crown":
		return normal
	var clock_foe := false
	for t in ai.game.enemies_of(ai.team):
		if ai.game.faction_of(t) == "clockwork":
			clock_foe = true
	return BREEDER_VS_CLOCK if clock_foe else normal


## No more Labourers: the army is behind them (the coach's films: 40 workers and 12 Musketeers at 8:00).
func hold_labourers(labs: int) -> bool:
	if not vs_clock():
		return false
	if labs >= LAB_CAP:
		return true
	if ai.game.clock < 240.0 or labs < LAB_FLOOR:
		return false
	var sup: int = ai._army_supply(ai.game.army(ai.team))
	if float(sup) < float(labs) * LAB_ARMY_SHARE:
		_log("labs", "holds its Labourers at %d until the army catches up (the army comes first against the Clockwork)" % labs)
		return true
	return false


## Horsemen in the Barracks' mix: two riders (scouting, picking off Winders) and no more against the Clockwork
## (a Clock Soldier line eats horses; the owner won with Musketeers). Returns -1 when the usual rule applies.
func horsemen_cap() -> int:
	if not vs_clock() or ai._rush_open():
		return -1
	return 2


## The Missionaries a Church trains against the Clockwork: one (it kept one coming forever).
func missionary_ok() -> bool:
	if not vs_clock():
		return true
	var n: int = ai.game.army(ai.team).filter(func(u: Unit) -> bool: return u.kind == "missionary").size()
	for c in ai._mine("church"):
		n += (c as Building).queue.count("missionary")
	return n < 1


## Guns (and the wagon) still wanted from the Foundries: the same counts AI._produce uses.
func guns_wanted() -> bool:
	var army: Array = ai.game.army(ai.team)
	var cannons: int = army.filter(func(u: Unit) -> bool: return u.kind == "cannon").size()
	var mortars: int = army.filter(func(u: Unit) -> bool: return u.kind == "mortar").size()
	var muskets: int = army.filter(func(u: Unit) -> bool: return Defs.MUSKETS.has(u.kind)).size()
	if cannons * 4 < army.size() + 2 or mortars < mini(2, int(muskets / 6.0)):
		return true
	return ai._wagon() == null and muskets >= 6


## How many horses a Foundry keeps standing by (AI._horses): against the Clockwork only one, and only while a
## gun or the wagon is wanted or queued there (two Foundries kept four horses idle in the coach's films).
## Returns -1 when the usual rule applies.
func foundry_horses(b: Building) -> int:
	if not vs_clock():
		return -1
	if not b.queue.is_empty() or guns_wanted():
		return 1
	return 0


## A spare horse at the breeders on top of what is wanted: none against the Clockwork (-1 = the usual rule).
func spare_horses() -> int:
	if not vs_clock() or ai._rushing():
		return -1
	return 0


## May a wave go out now? Not into a much bigger army it has seen (the computer's first attack went out at
## 7:37 with 16 supply just before the Clockwork's 40-supply wave).
func attack_ok(ready: Array) -> bool:
	if not vs_clock():
		return true
	if ai._army_supply(ready) >= ATTACK_ANYWAY or ai.strategy == "rush" and not ai._first_wave:
		return true             # (a big army goes anyway; the rush's own first wave is judged by the rush rules)
	ai._horse_watch()           # (counts the enemy army in sight every 3 s, whatever our faction)
	var seen: float = ai._horse_seen_value()
	var mine := 0.0
	for u in ready:
		mine += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
	if mine >= seen * ATTACK_EDGE:
		return true
	_log("wait_attack", "keeps its army home: the enemy army seen (%d) is bigger than its own (%d)" % [int(seen), int(mine)])
	return false


## A wave out against the Clockwork pulls back when it trades badly (AI._losing_trade, the Clockwork's own rule).
func retreat_rule() -> bool:
	return vs_clock()


## The second (third...) hall waits until there is an army to hold it (the expansion on the low ground fell at
## 9:34 in the films), unless the main's soil is nearly gone.
func hold_hall() -> bool:
	if not vs_clock() or ai._halls().is_empty():
		return false
	if ai._best_soil() < HALL_DRY:
		return false
	var army: Array = ai.game.army(ai.team)
	var sup: int = ai._army_supply(army)
	ai._horse_watch()
	var seen: float = ai._horse_seen_value()
	var mine := 0.0
	for u in army:
		mine += float(u.d["cost"]) / maxf(1.0, float(u.d.get("spawn", 1)))
	if sup >= HALL_ARMY and mine >= seen * HALL_SEEN:
		return false
	_log("hold_hall", "puts its next hall off until its army can hold it (%d supply, %d against %d seen)" % [sup, int(mine), int(seen)])
	return true


## While holding behind the wall the new hall's guards come home too (AI._army skips _guard_new_hall).
func holding() -> bool:
	return vs_clock() and ai.game.clock < _hold_until


func _wall_stands() -> bool:
	if not ai._walled:
		return false
	for p in ai._wall_pieces:
		if is_instance_valid(p) and not p.dead:
			return true
	var cot = ai._cw_cottage()
	return cot != null and is_instance_valid(cot) and not cot.dead


## The two spots behind the ramp wall on the high ground: the firing line three tiles in, the guns six.
func _behind() -> Array:
	if _hold_done:
		return _hold_spots
	_hold_done = true
	var bands: Array = _bands()
	if bands.is_empty():
		return _hold_spots
	var g = ai.game
	var home := Vector2(g.starts[ai.team]) + Vector2(2.5, 2.0)
	var hc := Vector2i(int(home.x), int(home.y))
	if not g.in_map(hc):
		return _hold_spots
	var h: int = g.height[g.idx(hc)]
	var band: Array = bands[0]["band"]
	var bc := Vector2.ZERO
	for c in band:
		bc += Vector2(c)
	bc /= float(band.size())
	var dir := (home - bc).normalized()
	var found: Array = []
	for want in [3, 6]:
		var spot := Vector2.INF
		for k in range(want, want + 5):
			var c := Vector2i(int(round(bc.x + dir.x * k)), int(round(bc.y + dir.y * k)))
			if g.in_map(c) and g.open_cell(c) and int(g.height[g.idx(c)]) == h:
				spot = g.cell_center(c)
				break
		if spot == Vector2.INF:
			return _hold_spots
		found.append(spot)
	_hold_spots = found
	return _hold_spots


## A high-ground cell on the far side of the ramp wall (between the wall's band and the ramp: an enemy hitting the
## wall from the top of the ramp stands there): its distance to the ramp is under the band's.
func _outside_wall(c: Vector2i) -> bool:
	for b in _bands():
		for rc in b["ramp"]:
			if Vector2(c).distance_to(Vector2(rc)) < 1.6:
				return true
	return false


## A wave at the gate bigger than our army: everyone holds on the high ground behind the wall (Musketeers
## shoot over it, the guns further back) instead of walking out to meet it. Returns true when it took over
## the defence (AI._defend is skipped). An enemy inside the wall, or a wave we are clearly stronger than, is
## fought the usual way.
func hold_behind_wall(army: Array, spots: Array) -> bool:
	if not vs_clock() or not _wall_stands():
		return false
	var hs := _behind()
	if hs.is_empty():
		return false
	var ramp_mid: Vector2 = _bands()[0]["mid"]
	var g = ai.game
	var home := (Vector2(g.starts[ai.team]) + Vector2(2.5, 2.0)) * float(Defs.TILE)
	var hc: Vector2i = g.cell_of(home)
	var h: int = g.height[g.idx(hc)]
	var enemy := 0.0
	for sp in spots:
		var c: Vector2i = g.cell_of(sp)
		if g.in_map(c) and int(g.height[g.idx(c)]) == h and int(g.ramp[g.idx(c)]) == 0 and not _outside_wall(c) \
				and (sp as Vector2).distance_to(home) < 26.0 * float(Defs.TILE):
			return false        # (inside our walls: fight it)
		if Vector2(c).distance_to(ramp_mid) > HOLD_NEAR:
			return false        # (at an expansion or elsewhere: defended the usual way, not left to fall)
		enemy += float(ai._assess(sp)["value"])
	var mine := 0.0
	for u in army:
		mine += ai._unit_value(u)
	var share := HOLD_OUT if g.clock < _hold_until else HOLD_IN
	if enemy < mine * share:
		return false
	if g.clock >= _hold_until and g.mlog:
		g.mlog.add("%s holds behind its wall: the wave (%d) is bigger than its army (%d)" % [g.mlog.who(ai.team), int(enemy), int(mine)])
	_hold_until = g.clock + 8.0
	if not ai._det.is_empty():
		ai._det.clear()
	var line: Vector2 = hs[0]
	var guns: Vector2 = hs[1]
	var i := 0
	for u in army:
		if u.is_air() or u.kind == "powder_wagon":
			continue
		var back: bool = u.kind in ["cannon", "mortar", "missionary"]
		var base: Vector2 = guns if back else line
		# (a fixed spread by index: no random numbers, the match stays the same run to run)
		var spot: Vector2 = base + Vector2(cos(i * 2.4), sin(i * 2.4)) * (14.0 + 9.0 * sqrt(float(i)))
		i += 1
		var c2: Vector2i = g.cell_of(spot)
		if not g.in_map(c2) or not g.open_cell(c2) or int(g.height[g.idx(c2)]) != h:
			spot = base
		if u.position.distance_to(spot) < 70.0:
			continue
		if u.order in ["move", "amove"] and u.order_point.distance_to(spot) < 70.0:
			continue
		u.cmd_move(spot, not back)
	return true


## The Horseman rush gives up sooner against the Clockwork: Clock Soldiers worth 80% of the riders are
## enough to kill them (the riders ride home alive and the Musketeer game takes over).
func rush_beaten(defv: float, mine: float, gained: float, wv: float) -> bool:
	return vs_clock() and defv >= 100.0 and defv > mine * 0.8 and gained < wv * 0.8


# ============================================================ B. the Clockwork

func _clock_on() -> bool:
	if not (on and _only != "crown" and ai.difficulty >= 1 and ai._clock() and not ai.peaceful):
		return false
	_bands()                    # (the ramps while the band is still free of buildings)
	return true


func _rider(o: Unit) -> bool:
	return not o.is_air() and float(o.d.get("speed", 60)) >= RAIDER_SPEED


## The press, Mainspring or hall nearest to p (where the Winders work), within r.
func _anchor(p: Vector2, r: float) -> Building:
	var best: Building = null
	var bd := r
	var halls: Array = ai._halls()
	for b in ai.game.buildings:
		if b.team != ai.team or b.dead or not b.built or b.crew_max() <= 0 and not halls.has(b):
			continue
		var d: float = b.center().distance_to(p)
		if d < bd:
			bd = d
			best = b
	return best


## One raid on the Winders (AI._raid_workers calls this first). Riders only: the Winders near the press group
## up and all hit the same rider (the one nearest the group). Returns false to leave the raid to the old rule
## (flee): flyers, slow armies, too few hands, or the riders away from the workers' post.
func worker_raid(c: Dictionary, labs: Array, stand: Dictionary) -> bool:
	if not _clock_on():
		return false
	var foes: Array = c["foes"]
	if foes.is_empty() or not foes.all(func(o: Unit) -> bool: return _rider(o)):
		return false
	_horse_t = ai.game.clock
	var centre: Vector2 = c["c"]
	var post := _anchor(centre, ANCHOR_R + 150.0)
	if post == null:
		return false
	var at := post.center()
	var near_foes: Array = foes.filter(func(o: Unit) -> bool: return o.position.distance_to(at) < ANCHOR_R)
	if near_foes.is_empty():
		return false            # (they hang about outside: the Winders keep away, the soldiers come)
	var pool: Array = labs.filter(func(w: Unit) -> bool:
		return w.position.distance_to(centre) < POOL_R and w.position.distance_to(at) < ANCHOR_R + 80.0 \
			and float(w.d.get("damage", 0)) > 0.0 and not ai._escort.has(w) and not (ai.scout != null and ai.scout.is_scout(w)))
	if pool.size() < 3:
		return false
	var armor := 0.0
	for o in near_foes:
		armor += float(o.d.get("armor", 0))
	armor /= float(near_foes.size())
	var ratio: float = ai._power(pool, armor) / maxf(ai._power(near_foes, 0.0), 1.0)
	var coming := false
	for u in _guards:
		if is_instance_valid(u) and not u.dead and (_guards[u]["anchor"] as Vector2).distance_to(at) < 200.0:
			coming = true
			break
	if not coming:
		for u in ai.game.army(ai.team):
			if u.kind == "clock_soldier" and u.position.distance_to(at) < 700.0:
				coming = true
				break
	if ratio < (RATIO_HELP if coming else RATIO_ALONE):
		return false
	# the group's centre, and the rider nearest it: everyone on him
	var gc := Vector2.ZERO
	for w in pool:
		gc += w.position
	gc /= float(pool.size())
	var focus: Unit = near_foes[0]
	for o in near_foes:
		if o.position.distance_to(gc) < focus.position.distance_to(gc):
			focus = o
	for w in pool:
		stand[w] = true
		ai._fighters[w] = true
		w.set_meta("guard", true)
		ai._fled.erase(w)
		var t = w.target
		var keep: bool = w.order == "attack" and t != null and is_instance_valid(t) and not t.dead and t != focus \
			and near_foes.has(t) and t.position.distance_to(w.position) < 40.0     # (already trading blows: go on)
		if t != focus and not keep:
			w.cmd_attack(focus)
	_log("winders", "groups its Winders up to fight the riders together (the soldiers are coming)")
	return true


## The Clock Soldiers busy guarding the workers or holding the ramp (AI._army and AI._defend leave them be).
func busy(u: Unit) -> bool:
	return _guards.has(u) or _ramp.has(u)


## Riders at our buildings (AI._defend calls this first with the assessments): the nearest Clock Soldiers go
## as ONE group to the workers' post (not to the rider, who would lead them about). Returns the spots it took.
func guard_workers(army: Array, spots: Array) -> Array:
	var taken: Array = []
	if not _clock_on():
		return taken
	var g = ai.game
	for sp in spots:
		var riders: Array = g.units_near(sp, 300.0).filter(func(o: Unit) -> bool:
			return g.hostile(o.team, ai.team) and not o.dead and not o.off_field and ai._armed(o) and ai._sighted(o))
		if riders.is_empty() or not riders.all(func(o: Unit) -> bool: return _rider(o)):
			continue
		var post := _anchor(sp, ANCHOR_R + 150.0)
		if post == null:
			continue
		_horse_t = g.clock
		taken.append(sp)
		var at: Vector2 = post.center()
		var have := 0
		for u in _guards:
			if (_guards[u]["anchor"] as Vector2).distance_to(at) < 200.0:
				_guards[u]["t"] = g.clock
				have += 1
		var want := clampi(riders.size() * GUARD_PER_RIDER, GUARD_MIN, GUARD_MAX)
		if have >= want:
			continue
		var pool: Array = army.filter(func(u: Unit) -> bool:
			return u.kind == "clock_soldier" and not busy(u) and not ai._det.has(u) and not (ai._attacking and ai._wave_set.has(u)) \
				and u.position.distance_to(at) < 1600.0)
		pool.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(at) < b.position.distance_to(at))
		var picks: Array = pool.slice(0, want - have)
		if picks.size() + have < 2:
			continue            # (never one alone)
		var k := 0
		for u in picks:
			_guards[u] = {"anchor": at, "t": g.clock}
			# all to the same spot by the workers, a little apart (a fixed spread: no random numbers)
			u.cmd_move(at + Vector2(cos(k * 2.1), sin(k * 2.1)) * (30.0 + 8.0 * k), true)
			k += 1
		_log("guards", "sends its Clock Soldiers as a group to the Winders the riders hit (no chase)")
	return taken


## Every army think: the guards stay by the workers (walking back when a rider leads them off) and go home
## when the riders are gone; the ramp post is kept up.
func tick(army: Array) -> void:
	if not _clock_on():
		if not _guards.is_empty() or not _ramp.is_empty():
			_release_all()
		return
	var g = ai.game
	for u in _guards.keys():
		if not is_instance_valid(u) or u.dead:
			_guards.erase(u)
			continue
		var e: Dictionary = _guards[u]
		var at: Vector2 = e["anchor"]
		var rider_near := false
		for o in g.units_near(at, ANCHOR_R):
			if g.hostile(o.team, ai.team) and not o.dead and not o.off_field and _rider(o):
				rider_near = true
				break
		if rider_near:
			e["t"] = g.clock
		if g.clock - float(e["t"]) > GUARD_CALM:
			_guards.erase(u)
			var post: Vector2 = ai._post_spot()
			if post != Vector2.INF:
				u.cmd_move(post, true)
			continue
		if u.position.distance_to(at) > GUARD_LEASH:
			if not (u.order == "move" and u.order_point.distance_to(at) < 80.0):
				u.cmd_move(at)          # (back to the workers: a plain walk, no chasing on the way)
		elif u.order == "move" and u.order_point.distance_to(at) < 80.0 and u.position.distance_to(at) < 90.0:
			u.cmd_move(at, true)        # (there: fight whatever comes)
	_ramp_tick(army)


func _release_all() -> void:
	for u in _guards.keys():
		if is_instance_valid(u) and not u.dead:
			u.cmd_stop()
	_guards.clear()
	for u in _ramp:
		if is_instance_valid(u) and not u.dead:
			u.cmd_stop()
	_ramp.clear()


## The cells at the top of the main's ramp where the hold post stands (spread across its width).
func _ramp_cells() -> Array:
	if _ramp_done:
		return _ramp_spots
	_ramp_done = true
	var bands: Array = _bands()
	if bands.is_empty():
		return _ramp_spots
	var mid: Vector2 = bands[0]["mid"]
	var band: Array = (bands[0]["band"] as Array).duplicate()
	band.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Vector2(a).distance_to(mid)
		var db := Vector2(b).distance_to(mid)
		if absf(da - db) > 0.01:
			return da < db
		return a.x * 1000 + a.y < b.x * 1000 + b.y)
	var picked: Array = []
	for c in band:
		if picked.size() >= 4:
			break
		var ok := true
		for p in picked:
			if Vector2(c).distance_to(Vector2(p)) < 1.5:
				ok = false
				break
		if ok:
			picked.append(c)
	for c in picked:
		_ramp_spots.append(ai.game.cell_center(c))
	return _ramp_spots


## A few Clock Soldiers on HOLD at the top of the ramp once riders have been seen and the army is big enough:
## they stop riders riding in, and catch them riding out. Run-down guards are swapped for fresh ones. A real
## army at the ramp: the post joins the defence (AI._defend) and is set up again afterwards.
func _ramp_tick(army: Array) -> void:
	var g = ai.game
	_ramp = _ramp.filter(func(u) -> bool: return is_instance_valid(u) and not u.dead)
	if ai.scout != null and ai.scout.rush_units_seen() > 0 and ai.scout._foe_faction() == "crown":
		_horse_t = maxf(_horse_t, g.clock - 1.0)
	var soldiers: Array = army.filter(func(u: Unit) -> bool:
		return u.kind == "clock_soldier" and not (ai._attacking and ai._wave_set.has(u)))
	var n := soldiers.size() + _ramp.size()
	var want := 0
	if g.clock - _horse_t <= HORSE_MEMORY:
		want = 4 if n >= RAMP_MORE_AT else (3 if n >= RAMP_AT else 0)
	var spots := _ramp_cells()
	if spots.is_empty():
		want = 0
	if want > 0:
		# a real army at the top of the ramp: the post joins the fight
		var c: Vector2 = spots[0]
		for o in g.units_near(c, 360.0):
			if g.hostile(o.team, ai.team) and not o.dead and not o.off_field and ai._armed(o) and not _rider(o):
				want = 0
				break
	# run-down guards go back to a field (the army's rule) and fresh ones take their place
	for u in _ramp.duplicate():
		if _ramp.size() > want or (u.wind < RAMP_WIND and not u.runs_on_spring()):
			_ramp.erase(u)
			u.cmd_stop()
	if _ramp.size() < want:
		var pool: Array = soldiers.filter(func(u: Unit) -> bool: return not busy(u) and not ai._det.has(u) and (u.wind >= 0.6 or u.runs_on_spring()))
		var c0: Vector2 = spots[0]
		pool.sort_custom(func(a: Unit, b: Unit) -> bool: return a.position.distance_to(c0) < b.position.distance_to(c0))
		for u in pool:
			if _ramp.size() >= want:
				break
			_ramp.append(u)
		if not _ramp.is_empty():
			_log("ramp", "posts %d Clock Soldiers on HOLD at the top of its ramp against the riders" % want)
	for i in _ramp.size():
		var u: Unit = _ramp[i]
		# (a narrow ramp top has fewer spots than guards: the extra ones stand a little to the side)
		var spot: Vector2 = spots[i % spots.size()] + Vector2(cos(i * 2.4), sin(i * 2.4)) * (16.0 * int(i / spots.size()))
		if u.position.distance_to(spot) > 14.0:
			if u.order == "hold" or not (u.order == "move" and u.order_point.distance_to(spot) < 6.0):
				if u.target == null or u.position.distance_to(spot) > 60.0:
					u.cmd_move(spot)
		elif u.order != "hold":
			u.cmd_hold()
