class_name NetSnapshot
extends RefCounted
## What the host streams to a guest, ten times a second, and how the guest puts it on its puppets.
## A snapshot is a Dictionary: {"t": "snap", "n", "clk", "ack", "u": unit rows, "b": building rows,
## "gone": [[id, is_building, died]], "pl": players, ...}. A row starts with the fixed fields (U_FIXED / B_FIXED:
## id, kind, team, where, health, facing); a whole row goes on with the values of the property lists below (in
## order) and the ids of the entities it points at.
## Only what changed is sent: an entity whose values are the same as in the last snapshot sends a short row (the
## fixed fields: it moved, or its health changed) or nothing at all. Every KEY_EVERY-th snapshot is a keyframe:
## every row whole, and "ids", the list of everything there is (the guest drops what is not on it).
## Two more savings: an enemy unit no guest's side can see is not sent (the guest's fog hides it anyway; it is sent
## again as it comes into sight), and when snapshots go faster than 12 a second a unit's whole row is looked at every
## other one (its place and health every time): what it is doing still reaches the guest ten times a second.
## The values are read and written directly (unit_vals / set_unit_vals ...): by name (`get`/`set`) they were the
## host's biggest cost (5 ms a snapshot with 70 units). The lists stay the spec: check_lists() compares the two.

const UNIT_PROPS := ["order", "phase", "work", "carrying", "mode", "tesla_mode", "braced", "sky", "keg",
	"cocoon", "coat", "armoured", "kills", "art", "powder", "wind", "max_hp", "off_field", "horse_hp", "harnessed",
	"topter_bat", "courier", "supplying", "auto_repair", "hold_fire", "pistol", "bayonet", "pouch", "carry_empty",
	"spin", "overclock_t", "cranked_t", "self_wind_t", "tongue_stage", "tesla_t", "haul_t", "auto_work",
	"owl_t", "net_t", "arm", "shield_up", "shield_t", "loaded", "auto_sweep", "ride_n", "nb", "stun_end", "moult_t", "band"]       # (band: the Marching Band's state, scripts/marching_band.gd)       # (stun_end: the clock a real stun's stars go, scripts/stun_mark.gd; nb: the Brood's own state, scripts/brood_new.gd; (a Clock Soldier's SHIELD FORWARD and its switch; a Swift's morph under way: its clock and bar; a unit caught in a Netter's net; the
	# launcher a Springer fires now, so a guest plays that arm's strip; a Spring Ballista's bolt in or not: loaded or fired, its crew
	# cranking; a Great Winder's SWEEP autocast, for its card; ride_n: a Horseman's blows struck in passing, so a
	# guest draws the sabre arc: scripts/ride_by.gd)
const UNIT_REFS := ["target", "home_mine", "leader", "aboard", "order_target", "crew_of"]      # (crew_of: a Ballista's crewman)
const BLD_PROPS := ["built", "progress", "ghost", "queue", "prod_t", "growth",
	"soil", "lode", "batteries", "auto_train", "auto_refit", "gate_open", "locked", "vertical", "seeded",
	"crate", "unfold_t", "max_hp", "rally", "worker_rally", "stock", "gear_big"]
const BLD_REFS := ["rally_target", "worker_rally_target"]
const U_FIXED := 6      # id, kind, team, position, hp, facing angle
const B_FIXED := 6      # id, kind, team, cell, hp, (spare)
const KEY_EVERY := 30   # a keyframe every 3 s


static func q(v):
	if v is float:
		return snappedf(v, 0.01)
	return v


static func ref(s: NetSession, r) -> int:
	if r == null or not is_instance_valid(r) or not (r is Entity):
		return 0
	if r.net_id == 0:
		s.assign(r)
	return r.net_id


## The unit's values, in UNIT_PROPS order.
static func unit_vals(u: Unit) -> Array:
	return [u.order, u.phase, u.work, u.carrying, u.mode, u.tesla_mode, u.braced, u.sky, u.keg,
		snappedf(u.cocoon, 0.01), u.coat, u.armoured, u.kills, u.art, snappedf(u.powder, 0.01), snappedf(u.wind, 0.01),
		snappedf(u.max_hp, 0.01), u.off_field, snappedf(u.horse_hp, 0.01), u.harnessed,
		u.topter_bat, u.courier, u.supplying, u.auto_repair, u.hold_fire, u.pistol, u.bayonet, u.pouch, u.carry_empty,
		snappedf(u.spin, 0.01), snappedf(u.overclock_t, 0.01), snappedf(u.cranked_t, 0.01),
		snappedf(u.self_wind_t, 0.01), u.tongue_stage, snappedf(u.tesla_t, 0.01), snappedf(u.haul_t, 0.01), u.auto_work,
		snappedf(u.owl_t, 0.01), snappedf(u.net_t, 0.01), u.arm, u.shield_up, snappedf(u.shield_t, 0.01), u.loaded, u.auto_sweep, u.ride_n,
		BroodNew.unit_save(u) if u._k_nb else u.nb, snappedf(u.stun_end, 0.01), snappedf(u.moult_t, 0.01),
		MarchingBand.save(u) if u.kind == MarchingBand.KIND else u.band]


## The building's values, in BLD_PROPS order.
static func bld_vals(b: Building) -> Array:
	return [b.built, snappedf(b.progress, 0.01), b.ghost, b.queue, snappedf(b.prod_t, 0.01),
		snappedf(b.growth, 0.01), snappedf(b.soil, 0.01), snappedf(b.lode, 0.01), b.batteries, b.auto_train, b.auto_refit, b.gate_open, b.locked, b.vertical, b.seeded,
		b.crate, snappedf(b.unfold_t, 0.01), snappedf(b.max_hp, 0.01), b.rally, b.worker_rally, snappedf(b.stock, 0.01),
		b.gear_big]


## Do the direct readers and writers match the lists? "" if so, else what differs (tools/bench_net_snapshot.gd and
## the online test call it on real units and buildings).
static func check_lists(u: Unit, b: Building) -> String:
	var out := PackedStringArray()
	if u:
		var direct := unit_vals(u)
		if direct.size() != UNIT_PROPS.size():
			out.append("unit_vals has %d values, UNIT_PROPS %d" % [direct.size(), UNIT_PROPS.size()])
		else:
			for i in UNIT_PROPS.size():
				if typeof(direct[i]) != typeof(q(u.get(UNIT_PROPS[i]))) or direct[i] != q(u.get(UNIT_PROPS[i])):
					out.append("unit %s: %s != %s" % [UNIT_PROPS[i], str(direct[i]), str(u.get(UNIT_PROPS[i]))])
	if b:
		var bd := bld_vals(b)
		if bd.size() != BLD_PROPS.size():
			out.append("bld_vals has %d values, BLD_PROPS %d" % [bd.size(), BLD_PROPS.size()])
		else:
			for i in BLD_PROPS.size():
				if typeof(bd[i]) != typeof(q(b.get(BLD_PROPS[i]))) or bd[i] != q(b.get(BLD_PROPS[i])):
					out.append("building %s: %s != %s" % [BLD_PROPS[i], str(bd[i]), str(b.get(BLD_PROPS[i]))])
	return "; ".join(out)


# ------------------------------------------------------------------ host

static func build(s: NetSession) -> Dictionary:
	var g := s.game
	var key := s.snap_n % KEY_EVERY == 1
	var halves := s.snap_every < 0.08          # (fast snapshots: each unit's whole row every other one)
	var eyes := s.guest_sides()                 # the sides the guests play: what they can see
	var cur := {}
	var brows: Array = []
	var urows: Array = []
	for b in g.buildings:
		if not is_instance_valid(b) or b.is_queued_for_deletion() or s.rec_skip(b):
			continue
		s.assign(b)
		cur[b.net_id] = b
	var n_units := 0
	for u in g.units:
		if not is_instance_valid(u) or u.is_queued_for_deletion() or u.dead or s.rec_skip(u):
			continue
		s.assign(u)
		cur[u.net_id] = u
		n_units += 1
	for id in cur:
		var e: Entity = cur[id]
		if e is Building:
			var b: Building = e
			var hp := snappedf(b.hp, 0.1)
			var slow := bld_vals(b)
			slow.append(ref(s, b.rally_target))
			slow.append(ref(s, b.worker_rally_target))
			var crew: Array = []
			for c in b.crew:
				var cid := ref(s, c)
				if cid != 0:
					crew.append(cid)
			slow.append(crew)
			var hs := hash(slow)
			var row: Array = [id, b.kind, b.team, b.cell, hp, 0]
			if key or int(s.sent_slow.get(id, 0)) != hs:
				row.append_array(slow)
				s.sent_slow[id] = hs
			elif s.sent_fast.get(id) == hp:
				continue               # (nothing changed)
			s.sent_fast[id] = hp
			brows.append(row)
		else:
			var u: Unit = e
			if not key and not _seen_by(g, u, eyes):
				if not s.was_seen.has(id):
					continue           # (fogged for every guest: its row waits until it comes into sight)
				s.was_seen.erase(id)    # (just gone out of sight: one last row, where it went)
			else:
				s.was_seen[id] = true
			var fast: Array = [u.position.snapped(Vector2(0.1, 0.1)), snappedf(u.hp, 0.1), snappedf(u.facing.angle(), 0.02)]
			if halves and not key and (id + s.snap_n) % 2 == 1 and s.sent_slow.has(id):
				if s.sent_fast.get(id) != fast:
					s.sent_fast[id] = fast
					urows.append([id, u.kind, u.team, fast[0], fast[1], fast[2]])
				continue               # (its whole row is looked at in the next one)
			var slow := unit_vals(u)
			slow.append(u.cooldown > 0.0)
			slow.append(ref(s, u.target))
			slow.append(ref(s, u.home_mine))
			slow.append(ref(s, u.leader))
			slow.append(ref(s, u.aboard))
			slow.append(ref(s, u.order_target))
			slow.append(ref(s, u.crew_of))
			var pas: Array = []
			for c in u.passengers:
				var pid := ref(s, c)
				if pid != 0:
					pas.append(pid)
			slow.append(pas)
			var hs := hash(slow)
			var row: Array = [id, u.kind, u.team, fast[0], fast[1], fast[2]]
			if key or int(s.sent_slow.get(id, 0)) != hs:
				row.append_array(slow)
				s.sent_slow[id] = hs
			elif s.sent_fast.get(id) == fast:
				continue               # (it stood still and nothing changed)
			s.sent_fast[id] = fast
			urows.append(row)
	var gone: Array = []
	for id in s.known:
		if not cur.has(id):
			var old = s.known[id]
			var died: bool = is_instance_valid(old) and old.dead
			gone.append([id, old is Building if is_instance_valid(old) else int(id) < 0, died])
			s.sent_slow.erase(id)
			s.sent_fast.erase(id)
			s.was_seen.erase(id)
	s.known = cur
	s.by_id = cur
	var pl: Array = []
	for t in g.n_players():
		pl.append(g.players[t].duplicate(true))
	var m := {"t": "snap", "n": s.snap_n, "clk": snappedf(g.clock, 0.01), "ack": s.acks.duplicate(), "u": urows, "b": brows,
		"gone": gone, "pl": pl, "en": g.energy, "ore": g.ore_rate, "asm": g.asm_mult, "wind": g.wind_e,
		"elim": g.eliminated, "over": g.over, "win": g.winner, "cnt": [n_units, g.buildings.size()]}
	if key:
		m["ids"] = PackedInt32Array(cur.keys())
	var fp := g.line_net.fingerprint()
	if fp != s.line_fp or s.snap_n % 20 == 0:
		s.line_fp = fp
		m["ln"] = g.line_net.save()            # the Clockwork Line (pipe segments), sent when it changes
	# powder kegs on the ground (PowderKeg): [x, y, team, shots, hp], sent when they change (and now and then)
	var krows: Array = []
	for k in g.kegs:
		if not k.dead:
			krows.append([snappedf(k.position.x, 0.1), snappedf(k.position.y, 0.1), k.team, snappedf(k.powder, 0.1), snappedf(k.hp, 0.1)])
	var kfp := hash(krows)
	if kfp != s.keg_fp or key or s.snap_n % 20 == 0:
		s.keg_fp = kfp
		m["kg"] = krows
	if Defs.cw_roster and (not g.cw_consists.is_empty() or s.snap_n % 10 == 0):
		m["cpl"] = CwConsist.net_rows(s, g)     # coupled rail trains (lists of ids; the host moves the cars)
	if not g.line_net.rails.trains.is_empty() or s.snap_n % 10 == 0:
		m["tr"] = g.line_net.rails.view_rows()  # the trains (they move every snapshot)
	if not s.fx.is_empty():
		m["fx"] = s.fx
		s.fx = []
	if g.over or s.snap_n % 10 == 0:
		m["stats"] = g.stats           # (about once a second: income, the battle report)
		m["acc"] = s.applied_by.duplicate(true)     # (each guest: its orders run and refused, for its match log)
	if s.paused():
		m["pz"] = [s.pause_by, s.away]
	if g.over:
		m["note"] = g.end_note
		m["quit"] = g.end_quitter
		m["ahead"] = g.end_ahead
	return m


## The guest (or a replay) puts the host's kegs on the ground: the rows replace what lay there.
static func apply_kegs(g: Game, rows: Array) -> void:
	var have: Array = g.kegs.duplicate()
	for i in rows.size():
		var r: Array = rows[i]
		var p := Vector2(float(r[0]), float(r[1]))
		if i < have.size() and is_instance_valid(have[i]) and int(have[i].team) == int(r[2]):
			var k: PowderKeg = have[i]
			k.position = p
			k.powder = float(r[3])
			k.hp = float(r[4])
		else:
			if i < have.size() and is_instance_valid(have[i]):
				have[i].remove()
			var k2 := g.drop_keg(int(r[2]), p, float(r[3]), float(r[4]))
			k2.position = p
	for i in range(rows.size(), have.size()):
		if is_instance_valid(have[i]):
			have[i].remove()


## Can a guest see this unit? Its own side's always; another's where a guest's side sees (as the guest's fog will).
static func _seen_by(g: Game, u: Unit, eyes: Array) -> bool:
	if eyes.is_empty() or (u.team >= 0 and eyes.has(int(g.sides[u.team]))):
		return true
	var i := g.idx(g.cell_of(u.position))
	for t in g.n_players():
		if eyes.has(int(g.sides[t])) and (g.vis[t] as PackedByteArray)[i] == 1:
			return true
	return false


# ------------------------------------------------------------------ guest

## Several snapshots that came at once (oldest first) as one: the newest of each row (a short row, only the fixed
## fields, updates the whole one before it), every gone list (and nothing they name is made again), the shots of the
## last few and every body torn up, the newest of the parts sent only now and then (the Line, trains, stats). The ids
## of a keyframe count only if it is the newest.
static func merge(list: Array) -> Dictionary:
	var last: Dictionary = (list[list.size() - 1] as Dictionary).duplicate()
	var urows := {}
	var brows := {}
	var gone: Array = []
	var gone_ids := {}
	var shots: Array = []
	for i in list.size():
		var sm: Dictionary = list[i]
		for gn in sm.get("gone", []):
			gone.append(gn)
			gone_ids[int(gn[0])] = true
		for row in sm.get("b", []):
			brows[int(row[0])] = _newer(brows.get(int(row[0])), row, B_FIXED)
		for row in sm.get("u", []):
			urows[int(row[0])] = _newer(urows.get(int(row[0])), row, U_FIXED)
		var recent := i >= list.size() - 3
		for f in sm.get("fx", []):
			if recent or f[0] == "c" or f[0] == "f" or (f[0] == "g" and bool(f[3][8])):     # (a "+N", a lasting cloud's edge: kept)
				shots.append(f)
	for id in gone_ids:
		urows.erase(id)
		brows.erase(id)
	last["u"] = urows.values()
	last["b"] = brows.values()
	last["gone"] = gone
	if shots.is_empty():
		last.erase("fx")
	else:
		last["fx"] = shots
	for k in ["ln", "cpl", "tr", "stats", "acc"]:
		if last.has(k):
			continue
		for i in range(list.size() - 2, -1, -1):
			if (list[i] as Dictionary).has(k):
				last[k] = list[i][k]
				break
	return last


## A row on top of the one before it for the same entity: a short row only brings the fixed fields.
static func _newer(old, row: Array, fixed: int) -> Array:
	if old == null or row.size() > fixed or (old as Array).size() <= fixed:
		return row
	var r: Array = (old as Array).duplicate()
	for i in fixed:
		r[i] = row[i]
	return r


static func apply(s: NetSession, m: Dictionary) -> void:
	var g := s.game
	g.clock = float(m.get("clk", g.clock))
	# who is gone (before the new ones come: a wall piece swapped for a gate frees its ground first)
	for gn in m.get("gone", []):
		var e = s.by_id.get(int(gn[0]))
		s.by_id.erase(int(gn[0]))
		s.motion.erase(int(gn[0]))
		s.hist.erase(int(gn[0]))
		s.rowhash.erase(int(gn[0]))
		if not is_instance_valid(e):
			continue
		if e is Building:
			_building_gone(g, e, bool(gn[2]))
		elif bool(gn[2]):
			NetPuppet.unit_dies(e)
		else:
			_unit_gone(g, e)
	var whole: Array = []
	for row in m.get("b", []):
		var bb := _building_row(s, row)
		if bb and row.size() > B_FIXED:
			whole.append([bb, row])
	var refs: Array = []
	for row in m.get("u", []):
		var u := _unit_row(s, row)
		if u and row.size() > U_FIXED:
			refs.append([u, row])
	for pr in whole:
		_building_refs(s, pr[0], pr[1])
	for pr in refs:
		_unit_refs(s, pr[0], pr[1])
	# a keyframe lists every id: what is not on it is no longer there (the gone lists say so; this is the net under
	# them, for a snapshot lost on the way)
	if m.has("ids"):
		var ids := {}
		for id in m["ids"]:
			ids[int(id)] = true
		for id in s.by_id.keys():
			if not ids.has(id):
				var e = s.by_id[id]
				s.by_id.erase(id)
				s.motion.erase(id)
				s.hist.erase(id)
				s.rowhash.erase(id)
				if is_instance_valid(e):
					if e is Building:
						_building_gone(g, e, false)
					else:
						_unit_gone(g, e)
	var pl: Array = m.get("pl", [])
	for t in mini(pl.size(), g.players.size()):
		g.players[t] = pl[t]
	for pair in [["en", g.energy], ["ore", g.ore_rate], ["asm", g.asm_mult], ["wind", g.wind_e]]:
		var arr: Array = m.get(pair[0], [])
		for i in mini(arr.size(), (pair[1] as Array).size()):
			pair[1][i] = arr[i]
	var el: Array = m.get("elim", [])
	for i in mini(el.size(), g.eliminated.size()):
		g.eliminated[i] = el[i]
	var cnt: Array = m.get("cnt", [])
	if cnt.size() == 2 and m.has("ids"):
		# a check the tests read: after a keyframe (every row whole, unseen enemies too) the guest must hold exactly as
		# many as the host listed (in between, an enemy made out of sight comes only once seen or at the next keyframe)
		var diff := absi(g.units.size() - int(cnt[0])) + absi(g.buildings.size() - int(cnt[1]))
		s.count_diff_max = maxi(s.count_diff_max, diff)
		if diff > 0:
			s.count_diff_snaps += 1
	if m.has("ln"):
		g.line_net.load_rows(m["ln"])
	if m.has("kg"):
		apply_kegs(g, m["kg"])
	if m.has("cpl") and Defs.cw_roster:
		CwConsist.net_apply(s, g, m["cpl"])
	if m.has("tr"):
		g.line_net.rails.load_view(m["tr"])
	if m.has("stats"):
		g.stats = m["stats"]
	if m.has("fx"):
		s.play_fx(m["fx"])
	if bool(m.get("over", false)) and not g.over:
		g.end_note = String(m.get("note", ""))
		var quitter := int(m.get("quit", -1))
		if g.end_note == "player_surrender" and quitter >= 0 and quitter != g.human:
			g.end_quitter = quitter            # (the other side gave up: the log says so; our own was said at the press)
			g.end_ahead = String(m.get("ahead", ""))
			if g.mlog:
				g.mlog.add("%s surrendered while %s" % [g.mlog.who(quitter), g.end_ahead])
		g.over = true
		g.winner = int(m.get("win", -1))
		g.ended.emit(g.winner)


static func _unit_gone(g: Game, u: Unit) -> void:
	g.units.erase(u)
	g.selection.erase(u)
	u.queue_free()


static func _building_gone(g: Game, b: Building, died: bool) -> void:
	if died:
		b.queue.clear()
		b.kits.clear()
		b.crew.clear()
		b.die()
		return
	if b.ghost:
		g.on_building_died(b)
	else:
		g._mark(b.cell, b.size, 0)
		g.buildings.erase(b)
		g.selection.erase(b)
	b.queue_free()


static func _building_row(s: NetSession, row: Array) -> Building:
	var g := s.game
	var id := int(row[0])
	var b = s.by_id.get(id)
	var fresh := false
	var whole := row.size() > B_FIXED
	if not is_instance_valid(b):
		if not whole:
			return null                 # (a short row for one we never had: the next keyframe brings it)
		b = g._add_building(String(row[1]), int(row[2]), Vector2i(row[3]), bool(row[B_FIXED]), bool(row[B_FIXED + 2]))
		b.net_id = id
		s.by_id[id] = b
		fresh = true
	b.hp = float(row[4])
	if not whole:
		return b
	var hsh := hash(row.slice(B_FIXED))
	if not fresh and s.rowhash.get(id, 0) == hsh:
		return b
	s.rowhash[id] = hsh
	var was_ghost: bool = b.ghost
	var was_built: bool = b.built
	var o := B_FIXED
	var built: bool = row[o]
	var ghost: bool = row[o + 2]
	_set_bld_vals(b, row, o)
	if was_ghost and not ghost:
		g._solidify(b)
	b.built = built
	if built and not was_built and not fresh:
		g.on_building_complete(b)
		g.swamp_dirty = true
	b._update_sprite()
	b.queue_redraw()
	return b


## A row's values (BLD_PROPS order, from `o`) onto the guest's building ("built" and "ghost" are the caller's).
static func _set_bld_vals(b: Building, row: Array, o: int) -> void:
	b.progress = row[o + 1]
	b.queue = row[o + 3]
	for i in b.queue.size():
		if Defs.OLD_UNIT_KINDS.has(b.queue[i]):
			b.queue[i] = Defs.OLD_UNIT_KINDS[b.queue[i]]      # (an old id, from an older replay)
	b.prod_t = row[o + 4]
	b.growth = row[o + 5]
	b.soil = row[o + 6]
	b.lode = row[o + 7]
	b.batteries = row[o + 8]
	b.auto_train = Defs.unit_kind(String(row[o + 9]))
	b.auto_refit = row[o + 10]
	b.gate_open = row[o + 11]
	b.locked = row[o + 12]
	b.vertical = row[o + 13]
	b.seeded = row[o + 14]
	b.crate = row[o + 15]
	b.unfold_t = row[o + 16]
	b.max_hp = row[o + 17]
	b.rally = row[o + 18]
	b.worker_rally = row[o + 19]
	b.stock = row[o + 20]
	b.gear_big = row[o + 21]


static func _building_refs(s: NetSession, b: Building, row: Array) -> void:
	var base := B_FIXED + BLD_PROPS.size()
	b.rally_target = s.by_id.get(int(row[base]))
	b.worker_rally_target = s.by_id.get(int(row[base + 1]))
	var crew: Array = []
	for cid in row[base + BLD_REFS.size()]:
		var c = s.by_id.get(int(cid))
		if is_instance_valid(c):
			crew.append(c)
	b.crew = crew


static func _unit_row(s: NetSession, row: Array) -> Unit:
	var g := s.game
	var id := int(row[0])
	row[1] = Defs.unit_kind(String(row[1]))      # (an old id, from an older replay: Defs.OLD_UNIT_KINDS)
	var pos: Vector2 = row[3]
	var u = s.by_id.get(id)
	var fresh := false
	var whole := row.size() > U_FIXED
	if not is_instance_valid(u):
		if not whole:
			return null                 # (a short row for one we never had: the next keyframe brings it)
		u = g._add_unit(String(row[1]), int(row[2]), pos)
		u.net_id = id
		s.by_id[id] = u
		fresh = true
	if u.dead:
		return null
	if u.kind != String(row[1]):
		u.morph(String(row[1]))
	# movement: glide from where it is to the new spot over about one snapshot interval (NetPuppet.tick_unit)
	var mo = s.motion.get(id)
	var shown: Vector2 = u.position - s.lead_off(id)       # (where the pictures have it: a unit walking off at once is shown ahead)
	var stale: bool = mo != null and float(mo[2]) > s.interval * 3.0 and shown.distance_to(pos) > maxf(24.0, s.interval * 300.0)     # (out of sight a while: it jumps, no glide across; a replay's pictures come 5 a second, a step between them is longer)
	if fresh or mo == null or stale or shown.distance_to(pos) > 260.0:
		s.motion[id] = [pos, pos, 99.0]
		s.push_pos(id, pos, true)
		s.leads.erase(id)
		if not fresh:
			u.position = pos
			u.reset_physics_interpolation()       # (a jump, not a glide across the map)
	else:
		s.push_pos(id, pos, false)
		if s.leads.has(id):
			s.lead_seen(id, mo[1] if mo != null else shown, pos)
		s.motion[id] = [shown, pos, 0.0]
	u.hp = float(row[4])
	if not s.leading(id):
		u.facing = Vector2.from_angle(float(row[5]))
	if not whole:
		return u                        # (NetPuppet.tick_unit redraws it when its health shows a change)
	var hsh := hash(row.slice(U_FIXED))
	if not fresh and s.rowhash.get(id, 0) == hsh:
		return u
	s.rowhash[id] = hsh
	var o := U_FIXED
	var coat_was: String = u.coat
	var art_was: String = u.art
	_set_unit_vals(u, row, o)
	if bool(row[o + 11]) and not u.armoured:
		u.put_on_armour()
		u.hp = float(row[4])            # (putting it on adds health of its own: the row's is the true one)
	var art_row := Defs.unit_kind(String(row[o + 13]))
	if art_row != "" and art_row != u.art and ArtData.UNITS.has(art_row):
		u.art = art_row
	if u.coat != coat_was and u.sprite:
		HorseCoat.apply(u)
	if u.art != art_was and u.sprite:
		u._set_anim(u._anim_name(), true)
	u.max_hp = row[o + 16]
	u.cooldown = 1.0 if bool(row[o + UNIT_PROPS.size()]) else 0.0
	u.queue_redraw()
	return u


## A row's values (UNIT_PROPS order, from `o`) onto the guest's unit; "armoured", "art" and "max_hp" are the
## caller's (armour goes on with put_on_armour, which sets its own health; an art only if there is such a picture).
static func _set_unit_vals(u: Unit, row: Array, o: int) -> void:
	u.order = row[o]
	u.phase = row[o + 1]
	u.work = row[o + 2]
	u.carrying = row[o + 3]
	u.mode = row[o + 4]
	u.tesla_mode = row[o + 5]
	u.braced = row[o + 6]
	u.sky = row[o + 7]
	u.keg = row[o + 8]
	u.cocoon = row[o + 9]
	u.coat = row[o + 10]
	u.kills = row[o + 12]
	u.powder = row[o + 14]
	u.wind = row[o + 15]
	u.off_field = row[o + 17]
	u.horse_hp = row[o + 18]
	u.harnessed = row[o + 19]
	u.topter_bat = row[o + 20]
	u.courier = row[o + 21]
	u.supplying = row[o + 22]
	u.auto_repair = row[o + 23]
	u.hold_fire = row[o + 24]
	u.pistol = row[o + 25]
	u.bayonet = row[o + 26]
	u.pouch = row[o + 27]
	u.carry_empty = row[o + 28]
	u.spin = row[o + 29]
	u.overclock_t = row[o + 30]
	u.cranked_t = row[o + 31]
	u.self_wind_t = row[o + 32]
	u.tongue_stage = row[o + 33]
	u.tesla_t = row[o + 34]
	u.haul_t = row[o + 35]
	u.auto_work = row[o + 36]
	u.owl_t = row[o + 37]
	u.net_t = row[o + 38]
	u.arm = row[o + 39]
	u.shield_up = row[o + 40]
	u.shield_t = row[o + 41]
	u.loaded = row[o + 42]
	u.auto_sweep = row[o + 43]
	u.ride_n = row[o + 44]
	if row.size() > o + 45 and row[o + 45] is Dictionary:
		var keep_fe = u.nb.get("fe")
		u.nb = row[o + 45]
		if keep_fe != null:
			u.nb["fe"] = keep_fe
	if row.size() > o + 46:
		u.stun_end = float(row[o + 46])
		if u.stun_end > float(u.game.clock):
			StunMark.add(u.game, u)      # (the host's stars: scripts/stun_mark.gd)
	if row.size() > o + 47:
		u.moult_t = float(row[o + 47])        # (a young Brood unit maturing: its shimmer and bar, scripts/brood_mature.gd)
	if row.size() > o + 48 and row[o + 48] is Dictionary and u.kind == MarchingBand.KIND:
		var mhp := u.max_hp
		MarchingBand.load_state(u, row[o + 48])      # (the Marching Band: its musicians, solo and cooldowns, for its ring and card)
		u.max_hp = mhp


static func _unit_refs(s: NetSession, u: Unit, row: Array) -> void:
	var base := U_FIXED + UNIT_PROPS.size() + 1
	var vals: Array = []
	for i in UNIT_REFS.size():
		var e = s.by_id.get(int(row[base + i]))
		vals.append(e if is_instance_valid(e) else null)
	u.target = vals[0]
	u.home_mine = vals[1]
	u.leader = vals[2]
	u.aboard = vals[3]
	u.order_target = vals[4]
	var co: Unit = vals[5] as Unit
	if u.crew_of != co:
		# (a Ballista's crew list, on the guest: kept from its crewmen's rows, for where its own crewman stands)
		if u.crew_of != null and is_instance_valid(u.crew_of):
			u.crew_of.crew.erase(u)
		if co != null and not co.crew.has(u):
			co.crew.append(u)
		u.crew_of = co
	var pas: Array = []
	for pid in row[base + UNIT_REFS.size()]:
		var p = s.by_id.get(int(pid))
		if is_instance_valid(p):
			pas.append(p)
	u.passengers = pas
