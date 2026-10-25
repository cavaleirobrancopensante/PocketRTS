class_name LineWork
extends RefCounted
## A Winder's job on the Line: the "lay" order (walk to an unfinished segment, lay it, go on to the
## next nearest one). Kept out of unit.gd; Unit calls cmd_lay() and tick().


static func cmd_lay(u: Unit, seg: PipeSeg) -> void:
	if u.aboard or not u.is_worker() or seg == null:
		return
	u._reset_work()
	u.order = "lay"
	u.order_target = seg
	u.work = "to_site"
	u.target = null


## One tick of the order; returns the velocity the unit wants.
static func tick(u: Unit, delta: float) -> Vector2:
	var game := u.game
	var seg := u.order_target as PipeSeg
	if seg == null or not is_instance_valid(seg) or seg.dead or seg.built:
		var nxt := game.line_net.next_unbuilt(u.team, u.position, 14.0 * Defs.TILE)
		if nxt != null:
			u.order_target = nxt
			u.path = PackedVector2Array()
			return Vector2.ZERO
		if u._next_order():
			return Vector2.ZERO
		u.cmd_stop()
		return Vector2.ZERO
	if seg.edge_distance(u.position) < u.radius + 18.0:
		u.path = PackedVector2Array()
		u.facing = (seg.center() - u.position).normalized() if seg.center() != u.position else u.facing
		u.work = "building"
		seg.add_progress(delta)
		return Vector2.ZERO
	u.work = "to_site"
	if (u.path.is_empty() or u.path_i >= u.path.size()) and not u.path_pending:
		u._request_path(game.approach_point(seg, u.position))
	return u._follow(delta)
