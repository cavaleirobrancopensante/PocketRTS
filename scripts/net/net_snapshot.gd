class_name NetSnapshot
extends RefCounted
## What the host streams to a guest, ten times a second, and how the guest puts it on its puppets.
## A snapshot is a Dictionary: {"t": "snap", "n", "clk", "ack", "u": unit rows, "b": building rows,
## "gone": [[id, is_building, died]], "pl": players, ...}. A row is an Array: fixed fields, then the
## values of the property lists below (in order), then the ids of the entities it points at.

const UNIT_PROPS := ["order", "phase", "work", "carrying", "mode", "tesla_mode", "braced", "sky", "deflate", "keg",
	"cocoon", "coat", "armoured", "kills", "art", "powder", "wind", "max_hp", "off_field", "horse_hp", "harnessed",
	"topter_bat", "courier", "supplying", "auto_repair", "hold_fire", "pistol", "bayonet", "pouch", "carry_empty",
	"gas", "spin", "overclock_t", "cranked_t", "self_wind_t", "tongue_stage", "tesla_t", "haul_t", "auto_work"]
const UNIT_REFS := ["target", "home_mine", "leader", "aboard", "order_target"]
const BLD_PROPS := ["built", "progress", "ghost", "level", "queue", "morph_t", "prod_t", "eggs", "upgrade_t", "growth",
	"soil", "lode", "swamp_r", "batteries", "auto_train", "auto_refit", "gate_open", "locked", "vertical", "seeded",
	"crate", "unfold_t", "max_hp", "rally", "worker_rally", "stock"]
const BLD_REFS := ["rally_target", "worker_rally_target"]
const U_FIXED := 6      # id, kind, team, position, hp, facing angle
const B_FIXED := 6      # id, kind, team, cell, hp, (spare)


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


# ------------------------------------------------------------------ host

static func build(s: NetSession) -> Dictionary:
	var g := s.game
	var cur := {}
	var brows: Array = []
	var urows: Array = []
	for b in g.buildings:
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		s.assign(b)
		cur[b.net_id] = b
	for u in g.units:
		if not is_instance_valid(u) or u.is_queued_for_deletion() or u.dead:
			continue
		s.assign(u)
		cur[u.net_id] = u
	for id in cur:
		var e: Entity = cur[id]
		if e is Building:
			var row: Array = [id, e.kind, e.team, e.cell, snappedf(e.hp, 0.1), 0]
			for p in BLD_PROPS:
				row.append(q(e.get(p)))
			for p in BLD_REFS:
				row.append(ref(s, e.get(p)))
			var crew: Array = []
			for c in e.crew:
				var cid := ref(s, c)
				if cid != 0:
					crew.append(cid)
			row.append(crew)
			brows.append(row)
		else:
			var u: Unit = e
			var row: Array = [id, u.kind, u.team, u.position, snappedf(u.hp, 0.1), snappedf(u.facing.angle(), 0.02)]
			for p in UNIT_PROPS:
				row.append(q(u.get(p)))
			row.append(u.cooldown > 0.0)
			for p in UNIT_REFS:
				row.append(ref(s, u.get(p)))
			var pas: Array = []
			for c in u.passengers:
				var pid := ref(s, c)
				if pid != 0:
					pas.append(pid)
			row.append(pas)
			urows.append(row)
	var gone: Array = []
	for id in s.known:
		if not cur.has(id):
			var old = s.known[id]
			var died: bool = is_instance_valid(old) and old.dead
			gone.append([id, old is Building if is_instance_valid(old) else int(id) < 0, died])
	s.known = cur
	s.by_id = cur
	var pl: Array = []
	for t in g.n_players():
		pl.append(g.players[t].duplicate(true))
	var m := {"t": "snap", "n": s.snap_n, "clk": snappedf(g.clock, 0.01), "ack": s.acks.duplicate(), "u": urows, "b": brows,
		"gone": gone, "pl": pl, "en": g.energy, "ore": g.ore_rate, "asm": g.asm_mult, "wind": g.wind_e,
		"elim": g.eliminated, "over": g.over, "win": g.winner, "cnt": [urows.size(), brows.size()]}
	var fp := g.line_net.fingerprint()
	if fp != s.line_fp or s.snap_n % 20 == 0:
		s.line_fp = fp
		m["ln"] = g.line_net.save()            # the Clockwork Line (pipe segments), sent when it changes
	if not g.line_net.rails.trains.is_empty() or s.snap_n % 10 == 0:
		m["tr"] = g.line_net.rails.view_rows()  # the trains (they move every snapshot)
	if not s.fx.is_empty():
		m["fx"] = s.fx
		s.fx = []
	if g.over or s.snap_n % 10 == 0:
		m["stats"] = g.stats           # (about once a second: income, the battle report)
	if g.over:
		m["note"] = g.end_note
	return m


# ------------------------------------------------------------------ guest

static func apply(s: NetSession, m: Dictionary) -> void:
	var g := s.game
	g.clock = float(m.get("clk", g.clock))
	# who is gone (before the new ones come: a wall piece swapped for a gate frees its ground first)
	for gn in m.get("gone", []):
		var e = s.by_id.get(int(gn[0]))
		s.by_id.erase(int(gn[0]))
		s.motion.erase(int(gn[0]))
		s.rowhash.erase(int(gn[0]))
		if not is_instance_valid(e):
			continue
		if e is Building:
			_building_gone(g, e, bool(gn[2]))
		elif bool(gn[2]):
			NetPuppet.unit_dies(e)
		else:
			g.units.erase(e)
			g.selection.erase(e)
			e.queue_free()
	var seen := {}
	for row in m.get("b", []):
		seen[int(row[0])] = true
		_building_row(s, row)
	var refs: Array = []
	for row in m.get("u", []):
		seen[int(row[0])] = true
		var u := _unit_row(s, row)
		if u:
			refs.append([u, row])
	for br in m.get("b", []):
		var bb = s.by_id.get(int(br[0]))
		if is_instance_valid(bb):
			_building_refs(s, bb, br)
	for pr in refs:
		_unit_refs(s, pr[0], pr[1])
	# what the snapshot no longer lists is no longer there (the 'gone' list covers it, this is the net)
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
	if cnt.size() == 2:
		# a check the tests read: the guest must now hold exactly as many as the host listed
		var diff := absi(g.units.size() - int(cnt[0])) + absi(g.buildings.size() - int(cnt[1]))
		s.count_diff_max = maxi(s.count_diff_max, diff)
		if diff > 0:
			s.count_diff_snaps += 1
	if m.has("ln"):
		g.line_net.load_rows(m["ln"])
	if m.has("tr"):
		g.line_net.rails.load_view(m["tr"])
	if m.has("stats"):
		g.stats = m["stats"]
	if m.has("fx"):
		s.play_fx(m["fx"])
	if bool(m.get("over", false)) and not g.over:
		g.end_note = String(m.get("note", ""))
		g.over = true
		g.winner = int(m.get("win", -1))
		g.ended.emit(g.winner)


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


static func _building_row(s: NetSession, row: Array) -> void:
	var g := s.game
	var id := int(row[0])
	var b = s.by_id.get(id)
	var p0 := B_FIXED
	var built: bool = bool(row[p0])           # (BLD_PROPS[0] is "built", [2] "ghost")
	var ghost: bool = bool(row[p0 + 2])
	var fresh := false
	if not is_instance_valid(b):
		b = g._add_building(String(row[1]), int(row[2]), Vector2i(row[3]), built, ghost)
		b.net_id = id
		s.by_id[id] = b
		fresh = true
	var hsh := hash(row.slice(4))
	if not fresh and s.rowhash.get(id, 0) == hsh:
		return
	s.rowhash[id] = hsh
	var was_ghost: bool = b.ghost
	var was_built: bool = b.built
	var lvl := int(row[p0 + BLD_PROPS.find("level")])
	if b.is_leveled() and lvl != b.level:
		b.set_level(lvl)
	b.hp = float(row[4])
	for i in BLD_PROPS.size():
		var v = row[p0 + i]
		var pn: String = BLD_PROPS[i]
		if pn == "ghost" or pn == "built" or v == null:
			continue
		b.set(pn, v)
	if was_ghost and not ghost:
		g._solidify(b)
	b.built = built
	if built and not was_built and not fresh:
		g.on_building_complete(b)
		g.swamp_dirty = true
	b._update_sprite()
	b.queue_redraw()


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
	var pos: Vector2 = row[3]
	var u = s.by_id.get(id)
	var fresh := false
	if not is_instance_valid(u):
		u = g._add_unit(String(row[1]), int(row[2]), pos)
		u.net_id = id
		s.by_id[id] = u
		fresh = true
	if u.dead:
		return null
	if u.kind != String(row[1]):
		u.morph(String(row[1]))
	# movement: glide from where it is to the new spot over one snapshot interval
	var mo = s.motion.get(id)
	if fresh or mo == null or u.position.distance_to(pos) > 260.0:
		s.motion[id] = [pos, pos, 99.0]
	else:
		s.motion[id] = [u.position, pos, 0.0]
	var hsh := hash(row.slice(4))
	if not fresh and s.rowhash.get(id, 0) == hsh:
		return u
	s.rowhash[id] = hsh
	u.hp = float(row[4])
	u.facing = Vector2.from_angle(float(row[5]))
	var o := U_FIXED
	var coat_was: String = u.coat
	var art_was: String = u.art
	var arm_row: bool = false
	for i in UNIT_PROPS.size():
		var v = row[o + i]
		var pn: String = UNIT_PROPS[i]
		if v == null:
			continue
		if pn == "armoured":
			arm_row = bool(v)
			continue
		if pn == "art":
			continue
		u.set(pn, v)
	if arm_row and not u.armoured:
		u.put_on_armour()
	var art_row := String(row[o + UNIT_PROPS.find("art")])
	if art_row != "" and art_row != u.art and ArtData.UNITS.has(art_row):
		u.art = art_row
	if u.coat != coat_was and u.sprite:
		HorseCoat.apply(u)
	if u.art != art_was and u.sprite:
		u._set_anim(u._anim_name(), true)
	u.max_hp = float(row[o + UNIT_PROPS.find("max_hp")])
	u.cooldown = 1.0 if bool(row[o + UNIT_PROPS.size()]) else 0.0
	u.queue_redraw()
	return u


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
	var pas: Array = []
	for pid in row[base + UNIT_REFS.size()]:
		var p = s.by_id.get(int(pid))
		if is_instance_valid(p):
			pas.append(p)
	u.passengers = pas
