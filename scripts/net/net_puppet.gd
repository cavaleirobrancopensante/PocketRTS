class_name NetPuppet
extends RefCounted
## The guest's side of the match: its units and buildings are the real thing (same drawing, same
## HUD, same fog) but nothing is simulated. Each one is moved and animated here from what the last
## snapshots said. (Hooks: Game._tick_game, Unit._physics_process, Building._physics_process.)


static func tick_game(g: Game, delta: float) -> void:
	if g.edit_mode:
		return
	g.clock += delta
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
		g._swamp_t = 0.5
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
	g._ghost_t -= delta
	if g._ghost_t <= 0.0:
		g._ghost_t = 0.5
		g.sweep_ghosts(true)


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
		var f := clampf(mo[2] / s.interval, 0.0, 1.0)
		u.position = (mo[0] as Vector2).lerp(mo[1], f)
		u.velocity = ((mo[1] as Vector2) - (mo[0] as Vector2)) / s.interval if f < 1.0 else Vector2.ZERO
	if u.kind == "balloon":
		for p in u.passengers:
			if is_instance_valid(p):
				p.position = u.position
	u._animate(delta)
	if not u.visible or not u.game.view_rect.has_point(u.position):
		u._draw_key = Vector4i(-1, -1, -1, -1)
	else:
		var key := Vector4i(int(u.selected) + (2 if u.carrying > 0 else 0) + u.kills * 64, int(u.hp) + int(u.gas) * 10000,
			int(u.wind * 40.0) + int(u.powder * 2.0) + (1000 if u.supplying else 0), int(u.max_hp) + int(u.reload_frac() * 16.0) * 10000)
		if key != u._draw_key:
			u._draw_key = key
			u.queue_redraw()


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
	u._set_anim(u._death_anim(), true)
	u.z_index = -1
	if u.visible:
		Sfx.play_any(["combat/%s_death" % u.kind, "combat/%s_death" % Sfx.SHORT.get(u.d["faction"], "crown"), "death_" + Sfx.SHORT.get(u.d["faction"], "crown")], u.position)
	u.queue_redraw()
