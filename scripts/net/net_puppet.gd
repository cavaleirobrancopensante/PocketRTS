class_name NetPuppet
extends RefCounted
## The guest's side of the match: its units and buildings are the real thing (same drawing, same
## HUD, same fog) but nothing is simulated. Each one is moved and animated here from what the last
## snapshots said. (Hooks: Game._tick_game, Unit._physics_process, Building._physics_process.)



static func tick_game(g: Game, delta: float) -> void:
	if g.edit_mode:
		return
	g.clock += delta
	if g.net:
		g.net.tick_rclk(delta)
		if g.net.predict:
			g.net.predict.tick()          # (the clicks' progress bars and timers move on)
	g.line_net.tick_view(delta)
	g.gear_net.tick(delta)           # (the gear field is worked out from the synced buildings: the guest sees the turning gears)
	g.alert_t = maxf(g.alert_t - delta, 0.0)
	var vsz := g.get_viewport().get_visible_rect().size / g.camera.zoom
	g.view_rect = Rect2(g.camera.get_screen_center_position() - vsz * 0.5, vsz).grow(120.0)
	g._body_bar_t -= delta
	if g._body_bar_t <= 0.0 and g.body_bars:
		g._body_bar_t = 0.2
		g.bodies = g.bodies.filter(func(b) -> bool: return is_instance_valid(b) and b.dead)
		g.body_bars.queue_redraw()
	for fl in g._floats:
		fl[3] -= delta
		fl[0] += Vector2(0, -18) * delta
	g._floats = g._floats.filter(func(fl: Array) -> bool: return fl[3] > 0.0)
	g._rebuild_hash()
	g._swamp_t -= delta
	if g.swamp_dirty and g._swamp_t <= 0.0:
		g._swamp_t = Game.SWAMP_STEP      # (the radii come from the host: each source's nb "swr", NetSnapshot)
		g._update_swamp()
	g._vis_t -= delta
	if g._vis_t <= 0.0:
		g._vis_t = 0.25
		g._update_vis()
	for pg in g._pings:
		pg[2] -= delta
	g._pings = g._pings.filter(func(pg: Array) -> bool: return pg[2] > 0.0)
	for tr in g._tracers:
		tr[2] -= delta
	g._tracers = g._tracers.filter(func(tr: Array) -> bool: return tr[2] > 0.0)
	g._overlay_t -= delta
	if g._overlay_t <= 0.0 or g._overlay_moving() or g.view_rect.position.distance_to(g._overlay_view) > 60.0:
		g._overlay_t = 0.25
		g._overlay_view = g.view_rect.position
		g.overlay.queue_redraw()
	g.field_layer.queue_redraw()
	# (no sweep of the sites here: the host drops a site nobody is coming to and the snapshot says so; the guest's copy
	# can't see an enemy's Winder out of sight nor anyone's Shift queue, and dropped the host's sites: playtest 0.24.34)


static func tick_unit(u: Unit, delta: float) -> void:
	u._process_flash(delta)
	if u.dead:
		u.corpse_t += delta
		u._animate(delta)
		if u.corpse_t > 1.5:
			u._rest_in_peace()
		return
	var s: NetSession = u.game.net
	var mo = s.motion.get(u.net_id) if s else null
	if mo != null:
		mo[2] += delta
		var at: Array = s.shown_at(u.net_id) if s.interp_on else []
		if not at.is_empty():
			# (from the buffer: between the two pictures around the shown clock, NetSession.shown_at)
			u.position = at[0]
			u.velocity = at[1]
		else:
			# (the older way: over a little more than the time between snapshots, toward the newest)
			var span := s.glide_span()
			var f := clampf(mo[2] / span, 0.0, 1.0)
			u.position = (mo[0] as Vector2).lerp(mo[1], f)
			u.velocity = ((mo[1] as Vector2) - (mo[0] as Vector2)) / span if f < 1.0 else Vector2.ZERO
		if s.leads.has(u.net_id):
			_lead(s, u, delta)
	if u.kind == "balloon":
		for p in u.passengers:
			if is_instance_valid(p):
				p.position = u.position
	if u.kind == MarchingBand.KIND:
		MarchingBand.look_tick(u, delta)      # (the Marching Band's music and ring, shown from its state)
	u._animate(delta)
	if not u.visible or not u.game.view_rect.has_point(u.position):
		u._draw_key = Vector4i(-1, -1, -1, -1)
	else:
		var key := Vector4i(int(u.selected) + (2 if u.carrying > 0 else 0) + u.kills * 64, int(u.hp),
			int(u.wind * 40.0) + int(u.powder * 2.0) + (1000 if u.supplying else 0) + ((int(u.owl_t * 4.0) + 1) * 100000 if u.owl_t >= 0.0 else 0),
			int(u.max_hp) + int(u.reload_frac() * 16.0) * 10000)      # (a morph under way: its bar and clock hand move)
		if key != u._draw_key:
			u._draw_key = key
			u.queue_redraw()


## A unit told to walk, shown ahead of the snapshots (NetSession.lead): until the host's snapshot shows the order it
## walks toward its spot here at its own speed (LEAD_MAX seconds of it at most); after, the lead is taken back at
## LEAD_BACK of its speed while the host's own walk carries it on: it slows a little for a moment, no jump.
static func _lead(s: NetSession, u: Unit, delta: float) -> void:
	var ld: Dictionary = s.leads[u.net_id]
	var off: Vector2 = ld["off"]
	var kind := String(ld.get("kind", "walk"))
	if kind == "stop" and not ld.get("go", false) and s.last_ack >= int(ld["seq"]) and u.velocity.length() < 1.0:
		ld["go"] = true                         # (a stop: the pictures after the order show it standing)
		ld["go_clk"] = s.rclk
	if kind == "chase" and s.leading(u.net_id) and s.last_ack >= int(ld["seq"]):
		var e = ld.get("e")
		if is_instance_valid(e) and (u.target == e or u.order_target == e) and u.velocity.length() < 1.0:
			ld["go"] = true                     # (the host's picture has it on the job, standing: in range already)
			ld["go_clk"] = s.prev_clk
	if s.leading(u.net_id):
		match kind:
			"face":
				u.facing = ld["dir"]
			"stop":
				# (stands where it was shown at the click while the pictures still have it walking on)
				off = (ld["hold"] as Vector2) - u.position
				off = off.limit_length(u.speed * NetSession.LEAD_STOP_MAX)
				u.velocity = Vector2.ZERO
			"chase":
				var e = ld.get("e")
				var at: Vector2 = u.position + off
				var goal: Vector2
				var gap: float
				if e == null:
					var box: Rect2 = ld["box"]
					goal = at.clamp(box.position, box.end)
					gap = goal.distance_to(at)
				elif is_instance_valid(e) and not e.dead:
					if e is Building:
						goal = at.clamp((e as Building).rect().position, (e as Building).rect().end)
						gap = goal.distance_to(at)
					else:
						goal = (e as Entity).position
						gap = goal.distance_to(at) - float(e.get("radius") if e.get("radius") != null else 8.0)
				else:
					ld["t"] = 0                 # (its target is gone: the lead is taken back)
					goal = at
					gap = 0.0
				var dir: Vector2 = goal - at
				if dir.length() > 0.5:
					u.facing = dir.normalized()
				if gap > float(ld["reach"]) and off.length() < u.speed * NetSession.LEAD_MAX:
					off += dir.normalized() * u.speed * NetSession.LEAD_PACE * delta
					u.velocity = dir.normalized() * u.speed
				else:
					u.velocity = Vector2.ZERO
				ld["to"] = goal
			_:
				var dir: Vector2 = (ld["to"] as Vector2) - (u.position + off)
				if dir.length() > 4.0 and off.length() < u.speed * NetSession.LEAD_MAX:
					dir = dir.normalized()
					off += dir * u.speed * NetSession.LEAD_PACE * delta
					u.facing = dir
					u.velocity = dir * u.speed          # (the walk)
	else:
		# Taken back as gently as the host's walk allows: walking the same way as the lead, a little at a time (it
		# shows at about 90% of its speed for a moment); turning off it (a path round a corner), faster; stopped on the
		# host (there, or held up), at once over a few frames, so it never stands off where the host has it.
		var v := u.velocity
		var rate := 1.2
		if v.length() > 1.0 and off.length() > 0.01:
			var align := clampf(off.normalized().dot(v.normalized()), 0.0, 1.0)
			rate = lerpf(NetSession.LEAD_BACK_TURN, NetSession.LEAD_BACK, align)
		if kind == "stop" and off.length() > 1.0 and v.length() < 1.0:
			rate = 0.8                          # (it closes up to where the host stopped it at a walk, a few steps)
			u.velocity = -off.normalized() * u.speed * rate
			u.facing = -off.normalized()
		off = off.move_toward(Vector2.ZERO, u.speed * rate * delta)
		if off == Vector2.ZERO:
			s.leads.erase(u.net_id)
	ld["off"] = off
	u.position += off


static func tick_building(b: Building, delta: float) -> void:
	b._process_flash(delta)
	if b.dead:
		b.rubble_t += delta
		if b.rubble_t > 25.0:
			b.modulate.a = maxf(0.0, 1.0 - (b.rubble_t - 25.0) / 3.0)
			if b.rubble_t > 28.0:
				b.queue_free()
		return
	b._check_use(delta)
	if b.sails and b.sails.visible:
		b._turn_sails(delta)
	if b._mill_state != "":
		b._turn_mill(delta)
	if b.life:
		b.life.tick(delta)
	var ft: float = float(b.get_meta("fire_t", 0.0)) - delta
	if ft <= 0.0:
		ft = 0.25
		b._update_fire()
	b.set_meta("fire_t", ft)


## A unit the host says fell: it plays its death, then lies there and fades (as Unit.die would,
## without the fighting side of it: the host has already worked out the losses and the horse).
static func unit_dies(u: Unit) -> void:
	if u.dead:
		return
	var g := u.game
	u.dead = true
	u.selected = false
	u.velocity = Vector2.ZERO
	g.units.erase(u)
	g.selection.erase(u)
	for grp in g.groups:
		grp.erase(u)
	u.corpse_t = 0.0
	u.died_at = g.clock
	u.body_dmg = 0.0          # (its body rots here as on the host: Unit.rot_end; hits come in the snapshot's fx, "h")
	u.body_max = 0.0
	u._set_anim(u._death_anim(), true)
	u.z_index = -1
	if u.visible:
		Sfx.play_any(["combat/%s_death" % u.kind, "combat/%s_death" % Sfx.SHORT.get(u.d["faction"], "crown"), "death_" + Sfx.SHORT.get(u.d["faction"], "crown")], u.position)
	u.queue_redraw()
