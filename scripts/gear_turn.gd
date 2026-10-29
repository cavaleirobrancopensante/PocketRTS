class_name GearTurn
extends RefCounted
## TURNING GEARS (the owner's experiment, 2026-10-28; docs/gear_turn.md). Settings > TURNING GEARS (experiment), on by
## default for now; kept in the match's setup (cfg "gear_turn" -> Defs.gear_turn) so a continued match, an online guest and
## a replay agree. Off: nothing here runs.
##
## Only the OUTER TOOTHED BAND of a Clockwork building's ground ring turns (GearNet.bands: from the edge of the hole, where
## the still floor plate starts, out to the tooth tips; only rings that visibly turn: connected, not stopped for a gear
## swap). A ground unit standing on a turning band is carried round with the teeth (GearNet.carry_at: the teeth's own
## speed, about a tile a second at the pitch circle; meshed rings turn opposite ways, so at a mesh both carry the same way).
## A unit WALKING across drifts by the full, correct amount for the time it spends on the band (the owner's correction,
## 2026-10-28: no damping for walkers; Defs.GEAR_TURN "walk" = 1); its path-following steers it back to its goal, so it
## still arrives. A unit that stays on the band (idle, HOLD, or fighting where it stands) keeps going round.
##
## Not carried: flyers, the big machines (radius >= "max_radius": the Cannon, the Spring Ballista, the Great Winder), a
## limbered gun or wagon, a man aboard a balloon or crewing a Ballista, a Springer in the air. WORKERS at work (any order
## but idle / hold / move / attack-move / attack / follow: going to or from a press, a site, a repair, the hall) cross the
## band without drifting, as the owner asked ("workers step inside the ring to the building so they don't go round").
##
## IDLE units STAY where they are and keep being carried (the owner's correction, 2026-10-28: no automatic step-off; the
## player moves them off with an order). A unit on HOLD stays and is carried too: the micro (an enemy holding on a ring is
## shifted out of position, and a defender can be too). The COMPUTER, though, walks its own idle and HOLD units off a band
## once they have stood on it Defs.GEAR_TURN "step_off" seconds (its AI's choice, so none of its units circles forever):
## to just outside the ring (or the still plate inside), without changing their orders.
## All of it runs in the simulation (unit ticks, sim timers, no randomness), so it is deterministic; an online guest and a
## replay are shown the host's positions.


static func on(game: Game) -> bool:
	return Defs.gear_turn and Defs.gear_mode and game.gear_net != null and not game.gear_net.bands.is_empty()


## Could this unit be carried at all (its kind and state)?
static func carriable(u: Unit) -> bool:
	if u.dead or u.off_field or u.aboard != null or u.crew_of != null or not u.jump.is_empty() or u.is_air():
		return false
	if (float(u.d.get("radius", 10.0)) >= float(Defs.GEAR_TURN["max_radius"]) and u.kind != "brute") or u.kind == "balloon":     # (the Brute, radius 24 since 0.15.x, is a creature: carried)
		return false
	return not u._towed()


const GRIP := 1.5             # s a walker stuck by the ride stands firm (see tick)
const FREE_ORDERS := ["idle", "hold", "move", "amove", "attack", "follow"]


## A worker on its way to or from its work (or at it): it crosses the band without drifting.
static func at_work(u: Unit) -> bool:
	return u.is_worker() and not FREE_ORDERS.has(u.order)


## Does the computer walk this unit off a band (its own idle or HOLD unit, not fighting)? The player's never: they ride
## until he moves them.
static func steps_off(u: Unit) -> bool:
	if u.order != "idle" and u.order != "hold":
		return false
	if u.target != null and is_instance_valid(u.target) and u.order == "idle":
		return false
	return computer_side(u.game, u.team)


static func computer_side(game: Game, t: int) -> bool:
	for a in game.ais:
		if is_instance_valid(a) and a.team == t:
			return true
	return false


## Called once a tick from Unit._tick_unit, before it moves: carries it (position, through resolve_terrain: never into a
## cliff, a wall or a building) and, when it should, steers it off the band. Returns the unit's `want` (its own walk).
static func tick(u: Unit, want: Vector2, delta: float) -> Vector2:
	u.gt_carry = Vector2.ZERO
	var game := u.game
	if not on(game):
		u.gt_on = 0.0
		u.gt_off = Vector2.INF
		return want
	# (the band first: most units stand on none, and the band is quicker to ask than carriable; the same outcome)
	var net := game.gear_net
	var i := net.band_at(u.position)
	if i < 0 or not net.band_turning(i):
		if u.gt_on < 0.0 and carriable(u):
			u.gt_on = minf(0.0, u.gt_on + delta)      # (a give-up's rest runs out off the band too)
		else:
			u.gt_on = 0.0
		u.gt_off = Vector2.INF
		return want
	if not carriable(u):
		u.gt_on = 0.0
		u.gt_off = Vector2.INF
		return want
	var k := Defs.GEAR_TURN
	# ---- stepping off
	if u.gt_off != Vector2.INF:
		u.gt_t += delta
		if not steps_off(u) or u.position.distance_to(u.gt_off) < 5.0 or u.gt_t > float(k["give_up"]):
			if u.gt_t > float(k["give_up"]):
				u.gt_on = -2.0          # (pinned: rest a moment before trying again)
				u.steps_failed += 1
			u.gt_off = Vector2.INF
		elif want.length() <= 5.0:
			want = (u.gt_off - u.position).normalized() * u.speed * 0.8
	elif steps_off(u) and want.length() <= 5.0:
		u.gt_on += delta
		if u.gt_on >= float(k["step_off"]):
			var p := net.step_off_point(i, u.position, u.radius, u.team)
			if p == Vector2.INF:
				u.gt_on = -2.0
			else:
				u.gt_off = p
				u.gt_t = 0.0
				u.steps_taken += 1
				if u.order == "idle" and net.band_at(u.leash_from) >= 0:
					u.leash_from = p          # (else, called back to where it was left, it would walk onto the band again)
				want = (p - u.position).normalized() * u.speed * 0.8
	elif u.gt_on > 0.0:
		u.gt_on = 0.0
	elif u.gt_on < 0.0:
		u.gt_on = minf(0.0, u.gt_on + delta)
	# ---- carried
	if at_work(u):
		return want
	var v := net.carry_at(u.position) * float(k["carry"])
	if want.length() > 5.0:
		v *= float(k["walk"])
	if v == Vector2.ZERO:
		return want
	u.gt_carry = v
	u.ride_t += delta
	# A walker the ride keeps pressed into a corner (a squeeze between two buildings' corners, a cliff's step) could be held
	# there for good: the ride pushes it back as fast as it walks round. So once a second its progress toward its next
	# waypoint is checked; under a quarter of its speed made good, it gets a grip on the floor for GRIP seconds (not carried
	# meanwhile: it walks out of the squeeze) and counts as stuck (Unit._move repaths; near its goal, Unit._arrived calls it
	# there).
	if u.gt_grip > 0.0:
		u.gt_grip -= delta
		u.gt_carry = Vector2.ZERO
		return want
	if want.length() > 5.0:
		var wp: Vector2 = u.path[u.path_i] if u.path_i < u.path.size() else u.path_goal
		if u.gt_w <= 0.0 or wp != u.gt_wp:
			u.gt_wp = wp
			u.gt_d = u.position.distance_to(wp) if wp != Vector2.INF else 0.0
			u.gt_w = 0.0
		u.gt_w += delta
		if u.gt_w >= 1.0:
			if wp != Vector2.INF and u.position.distance_to(wp) > u.gt_d - u.speed * 0.25:
				u.gt_grip = GRIP
				u.stuck_t = maxf(u.stuck_t, 1.7)
				u.gripped += 1
			u.gt_w = 0.0
	else:
		u.gt_w = 0.0
	var was := u.position
	u.position = game.resolve_terrain(u.position + v * delta, u.position, u.radius, u.team)
	u.last_pos += u.position - was       # (the ride is not progress of its own: pressed into a corner it is still stuck, and repaths)
	return want
