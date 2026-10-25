class_name LineAI
extends RefCounted
## The Clockwork computer's Line planner (phase 1: the minimum so the faction keeps working).
## Called from AI._think_stage(0) every think:
##  - every finished Clockwork building that uses the Line (and every Boiler) with no pipe beside it gets
##    one main laid from the Line it can reach (the Clocktower's) to a cell touching it, once at a time;
##  - the unfinished segments are laid by the nearest idle Winders (one or two at a time);
##  - repair needs nothing here: Winders repair damaged pipes by themselves (Game.find_repair).
## LEFT FOR PHASE 4: choosing building spots by where the Line goes (find_spot ignores it), branch routes
## to expansions and ore, a second route so that one cut does not starve the base, defending the Line,
## relays where the pressure thins, rebuilding a cut Line first when under attack.

const EVERY := 2.5          # seconds between looks


static func tick(ai: AI) -> void:
	var game := ai.game
	var net := game.line_net
	var t := ai.team
	var now := game.clock
	if now < float(ai.get_meta("line_t", 0.0)):
		return
	ai.set_meta("line_t", now + EVERY)
	var halls: Array = []
	for b in game.buildings:
		if b.team == t and b.kind == "clocktower" and b.built and not b.dead:
			halls.append(b)
	if halls.is_empty():
		return
	var pending := net.unbuilt_count(t)
	# 1. one new main at a time
	if pending == 0:
		for b in game.buildings:
			if b.team != t or b.dead or not b.built or b.kind == "clocktower":
				continue
			if not (net.is_consumer(b) or net.is_source(b)) or net.touches(b):
				continue
			var hall: Building = halls[0]
			var bd := INF
			for h in halls:
				var dd: float = h.center().distance_to(b.center())
				if dd < bd:
					bd = dd
					hall = h
			var workers := _winders(game, t, b.center(), 1)
			var plan := net.connect_building(t, hall, b, false, workers)
			if plan.get("laid", false):
				return
	# 2. hands for the unfinished segments
	if pending > 0:
		var seg := net.next_unbuilt(t, game.cell_center(Vector2i(0, 0)))
		for s in net.segs.values():
			if s.team == t and not s.built:
				seg = s
				break
		if seg != null:
			var busy := 0
			for u in game.units:
				if u.team == t and u.order == "lay" and not u.dead:
					busy += 1
			if busy < 2:
				for u in _winders(game, t, seg.global_position, 2 - busy):
					LineWork.cmd_lay(u, net.next_unbuilt(t, u.position))


## The idle (or hauling, empty-handed) Winders nearest p.
static func _winders(game: Game, t: int, p: Vector2, n: int) -> Array:
	var list: Array = []
	for u in game.workers(t):
		if u.kind != "winder" or u.order == "build" or u.order == "lay" or u.carrying > 0 or u.crate_site != null:
			continue
		list.append(u)
	list.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.position.distance_squared_to(p) + (0.0 if a.order == "idle" else 40000.0) < b.position.distance_squared_to(p) + (0.0 if b.order == "idle" else 40000.0))
	return list.slice(0, n)
