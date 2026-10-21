class_name SaveGame
## Keeps a match you closed: every few seconds (and when the app goes to the background)
## the whole state goes to user://autosave.json; the menu offers CONTINUE. The map is
## rebuilt from its seed, then every building, unit, resource and the fog are put back.
## Orders in flight aren't kept: soldiers stand where they were, workers go back to work.

const PATH := "user://autosave.json"


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func clear() -> void:
	if exists():
		DirAccess.remove_absolute(PATH)


static func peek() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _v2(v: Vector2) -> Array:
	return [v.x, v.y]


## Units that are no more: a saved Pikeman comes back as a Musketeer.
## A unit kind from an older save: the Pikeman became a Musketeer (Crown rework), the
## Gearknight a Thresher and the Bolt Automaton an Arc Thrower (Clockwork rework).
static func _kind(k: String) -> String:
	return {"pikeman": "musketeer", "gearknight": "thresher", "bolt": "arc_thrower"}.get(k, k)


static func _to_v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array else Vector2.INF


static func save(game: Game, cfg: Dictionary) -> void:
	if game == null or game.over or game.edit_mode or game.demo:
		return
	var d := {"version": ProjectSettings.get_setting("application/config/version", "dev"),
		"saved_at": Time.get_datetime_string_from_system(false, true), "cfg": cfg, "clock": game.clock,
		"players": game.players, "stats": game.stats, "eliminated": game.eliminated,
		"explored": Marshalls.raw_to_base64(game.explored), "camera": _v2(game.camera.position),
		"zoom": game.camera.zoom.x, "first_of": game._first_of, "big_farms": true,
		"log": Array(game.mlog.lines) if game.mlog else [], "ai": [],
		"soil_scars": game.soil_scars.map(func(sc: Array) -> Array: return [_v2(sc[0]), sc[1], sc[2], sc[3] if sc.size() > 3 else 0.0]), "buildings": [], "units": []}
	for ai in game.ais:
		d["ai"].append({"team": ai.team, "walled": ai._walled, "attack_at": ai._attack_at, "strategy": ai.strategy,
			"failed": ai._failed, "regroup": ai._regroup_until})
	for b in game.buildings:
		if b.dead:
			continue
		d["buildings"].append({"k": b.kind, "t": b.team, "c": [b.cell.x, b.cell.y], "built": b.built,
			"progress": b.progress, "hp": b.hp, "queue": b.queue, "prod_t": b.prod_t, "eggs": b.eggs,
			"egg_t": b.egg_t, "morph_t": b.morph_t, "auto": b.auto_train, "bat": b.batteries, "v": b.vertical, "vl": b.dir_locked,
			"swamp_r": b.swamp_r, "seeded": b.seeded, "growth": b.growth, "gold_acc": b.gold_acc,
			"soil": b.soil, "sw": b.soil_warned, "lode": snappedf(b.lode, 0.01), "lw": b.lode_warned,
			"crate": "ground" if b.crate == "carried" else b.crate,
			"rally": _v2(b.rally) if b.rally != Vector2.INF else null,
			"wrally": _v2(b.worker_rally) if b.worker_rally != Vector2.INF else null})
	for u in game.units:
		if u.dead or u.off_field:
			continue
		var ud := {"k": u.kind, "t": u.team, "p": _v2(u.position), "hp": u.hp, "wind": u.wind,
			# (a Mist Toad's TONGUE windup isn't kept: it comes back with that energy unspent)
			"charge": u.charge + (float(Defs.TONGUE["cost"]) if u.tongue_stage == "windup" else 0.0), "mode": u.mode, "tm": u.tesla_mode, "carry": u.carrying, "lf": u.load_f,
			"auto": u.auto_work, "cross": u.cross_t, "spell_cd": u.spell_cd, "gas": u.gas, "f": _v2(u.facing),
			"kills": u.kills, "defl": u.deflate, "courier": u.courier, "bat": u.topter_bat, "oc": u.overclock_t,
			"sky": u.sky if u.sky != "to_land" else "air",
			"pw": u.powder, "ab": u._auto_bayonet, "sup": u.supplying,
			"spin": u.spin, "brace": u.braced, "ovc": u.overcharge_t, "sw": u.self_wind_t, "ct": u.carry_t}
		# the men in a balloon's basket go with it
		if not u.passengers.is_empty():
			var ps: Array = []
			for p in u.passengers:
				if is_instance_valid(p) and not p.dead:
					ps.append({"k": p.kind, "hp": p.hp, "mode": p.mode, "auto": p.auto_work, "kills": p.kills, "cross": p.cross_t})
			ud["pass"] = ps
		d["units"].append(ud)
	# Clockwork crates on the ground, and the ones on a Winder's back (they come back lying
	# where he stood): [x, y, team, site cell x, site cell y, hp]
	d["crates"] = []
	for c in game.crates:
		if not c.dead and c.wanted():
			d["crates"].append([c.position.x, c.position.y, c.team, c.site.cell.x, c.site.cell.y, c.hp])
	for u in game.units:
		var s: Building = u.crate_site
		if not u.dead and s and is_instance_valid(s) and not s.dead and not s.built and s.crate == "carried" and s.crate_carrier == u:
			d["crates"].append([u.position.x, u.position.y, u.team, s.cell.x, s.cell.y, float(Defs.CRATE["hp"])])
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()


## Saves from v0.7.32 on had rock outcrops ([x, y, kind, amount left], 2x2 tiles): the share
## of the saltpetre (Town Hall) or ore (Clocktower) left in those within 13 tiles of a hall
## (1.0 when there were none).
static func _outcrops_left(deps: Array, h: Building) -> float:
	var kind: String = Defs.LODE_NAME.get(h.kind, "")
	var full := 0.0
	var left := 0.0
	for sd in deps:
		if sd is Array and sd.size() > 3 and String(sd[2]) == kind:
			var c := (Vector2(float(sd[0]), float(sd[1])) + Vector2.ONE) * Defs.TILE
			if c.distance_to(h.center()) <= 13.0 * Defs.TILE:
				full += 440.0 if kind == "saltpetre" else 3800.0
				left += float(sd[3])
	return clampf(left / full, 0.0, 1.0) if full > 0.0 else 1.0


## Put a saved match back onto a freshly generated map (same seed).
## The nearest corner to `at` (at most 3 tiles off) where a footprint of this size is all
## free ground; `at` itself if there's none.
static func _fit(game: Game, at: Vector2i, size: Vector2i) -> Vector2i:
	var best := at
	var bd := INF
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := at + Vector2i(dx, dy)
			var ok := true
			for y in size.y:
				for x in size.x:
					if not game.is_free(c + Vector2i(x, y)):
						ok = false
			var dd := Vector2(dx, dy).length()
			if ok and dd < bd:
				bd = dd
				best = c
	return best


static func restore(game: Game, d: Dictionary) -> void:
	# clear what the start placed
	for u in game.units.duplicate():
		u.queue_free()
	game.units.clear()
	for b in game.buildings.duplicate():
		game._mark(b.cell, b.size, 0)
		b.queue_free()
	game.buildings.clear()
	for c in game.crates.duplicate():
		c.queue_free()
	game.crates.clear()
	game.gate_team.clear()
	game.clock = float(d["clock"])
	for t in game.players.size():
		var p: Dictionary = d["players"][t]
		for k in p:
			if k == "split":
				game.players[t][k] = Array(p[k])
			else:
				game.players[t][k] = p[k]
		game.players[t]["gold"] = int(p["gold"])
		game.players[t]["cap"] = int(p["cap"])
	for t in game.stats.size():
		if t < d["stats"].size():
			var st: Dictionary = d["stats"][t]
			for k in st:
				game.stats[t][k] = st[k]
	for t in game.eliminated.size():
		game.eliminated[t] = bool(d["eliminated"][t])
	game._first_of = d.get("first_of", {})
	var ex := Marshalls.base64_to_raw(String(d["explored"]))
	if ex.size() == game.explored.size():
		game.explored = ex
	# (Farms last: in saves from before Farms grew to 5x4 tiles each may have to shift a little
	# to fit between what stands round it)
	var blist: Array = Array(d["buildings"]).filter(func(x) -> bool: return String(x["k"]) != "farm") \
		+ Array(d["buildings"]).filter(func(x) -> bool: return String(x["k"]) == "farm")
	for bd in blist:
		var bk := String(bd["k"])
		if bk == "bone_midden":
			bk = "brood_pen"        # (older saves: the Bone Midden became the Brood Pen)
		if not Defs.BUILDINGS.has(bk):
			continue
		var at := Vector2i(int(bd["c"][0]), int(bd["c"][1]))
		if bk == "farm" and not bool(d.get("big_farms", false)):
			at = _fit(game, at, Defs.BUILDINGS[bk]["size"])
		var b := game._add_building(bk, int(bd["t"]), at, bool(bd["built"]))
		b.progress = float(bd["progress"])
		b.hp = float(bd["hp"])
		# (research is in the queue as "@key")
		b.queue = Array(bd["queue"]).map(func(x) -> String: return String(x) if String(x).begins_with("@") else _kind(String(x))) \
			.filter(func(x: String) -> bool: return Defs.RESEARCH.has(x.substr(1)) if x.begins_with("@") else Defs.UNITS.has(x))
		b.prod_t = float(bd["prod_t"])
		b.eggs = int(bd["eggs"])
		b.egg_t = float(bd["egg_t"])
		b.morph_t = Array(bd["morph_t"]).map(func(x) -> float: return float(x))
		# (older saves: research ran beside the queue; it goes to the front now)
		var old_rs := String(bd.get("research", ""))
		if Defs.RESEARCH.has(old_rs) and not b.queue.has("@" + old_rs):
			b.queue.push_front("@" + old_rs)
			b.prod_t = float(bd.get("research_t", 0.0))
		b.auto_train = _kind(String(bd.get("auto", "")))
		b.batteries = int(bd.get("bat", 0))
		b.vertical = bool(bd.get("v", false))
		b.dir_locked = bool(bd.get("vl", false))
		b.swamp_r = float(bd["swamp_r"])
		b.seeded = bool(bd["seeded"])
		b.crate = String(bd.get("crate", ""))        # (older saves: no crates)
		b.growth = float(bd["growth"])
		b.gold_acc = float(bd["gold_acc"])
		if b.kind == "town_hall" or b.kind == "hive" or b.kind == "clocktower":
			b.soil = float(bd.get("soil", b.reserve()))     # (older saves: fresh soil / ground / coal)
			b.soil_warned = int(bd.get("sw", 0))
		if b.lode_full() > 0.0:
			if bd.has("lode"):
				b.lode = float(bd["lode"])
			else:
				# (older saves: fresh, or what the rock outcrops of v0.7.32 left by this hall)
				b.lode = b.lode_full() * _outcrops_left(d.get("deposits", []), b)
			b.lode_warned = int(bd.get("lw", 2 if b.lode <= 0.0 else (1 if b.lode / b.lode_full() < Defs.SOIL_LOW else 0)))
		if bd["rally"] != null:
			b.rally = _to_v2(bd["rally"])
		if bd["wrally"] != null:
			b.worker_rally = _to_v2(bd["wrally"])
		b._update_sprite()
	game.soil_scars.clear()
	for sc in d.get("soil_scars", []):
		var sk := String(sc[2]) if sc.size() > 2 else "town_hall"
		game.soil_scars.append([_to_v2(sc[0]), float(sc[1]), sk, float(sc[3]) if sc.size() > 3 else float(Defs.LODE.get(sk, 0.0))])
	for b in game.buildings:
		if b.kind == "farm" or b.kind == "feeding_pit":
			b._update_sprite()      # (its tired-soil tint needs the halls back first)
	for cd in d.get("crates", []):
		var cc := Vector2i(int(cd[3]), int(cd[4]))
		for b in game.buildings:
			if b.team == int(cd[2]) and b.cell == cc and not b.built and b.crate_obj == null:
				game.drop_crate(b, Vector2(float(cd[0]), float(cd[1])), float(cd[5]))
				break
	for b in game.buildings:
		if b.crate == "ground" and b.crate_obj == null:
			b.crate = "tower"       # (its crate wasn't found: a Winder fetches another)
	for ud in d["units"]:
		var uk := _kind(String(ud["k"]))
		if not Defs.UNITS.has(uk):
			continue
		var u := game._add_unit(uk, int(ud["t"]), _to_v2(ud["p"]))
		u.hp = minf(float(ud["hp"]), u.max_hp)
		u.cross_t = float(ud.get("cross", 0.0))
		u.wind = float(ud["wind"])
		u.charge = float(ud["charge"])
		u.mode = String(ud["mode"])
		u.tesla_mode = String(ud["tm"])
		u.carrying = int(ud["carry"])
		u.load_f = float(ud.get("lf", 0.0))
		u.auto_work = bool(ud["auto"])
		u.spell_cd = float(ud["spell_cd"])
		u.gas = float(ud.get("gas", 100.0))
		u.powder = float(ud.get("pw", u.powder))      # (older saves: full)
		u._auto_bayonet = bool(ud.get("ab", false))
		u.supplying = bool(ud.get("sup", false))
		u.facing = _to_v2(ud["f"])
		u.kills = int(ud.get("kills", 0))
		u.courier = bool(ud.get("courier", false))
		u.topter_bat = String(ud.get("bat", ""))
		u.overclock_t = float(ud.get("oc", 0.0))
		u.spin = float(ud.get("spin", 0.0))
		u.overcharge_t = float(ud.get("ovc", 0.0))
		u.self_wind_t = float(ud.get("sw", 0.0))
		u.carry_t = float(ud.get("ct", 0.0))
		if bool(ud.get("brace", false)):
			u.set_brace(true)
		u.hp = minf(u.hp, u.max_hp)
		var defl := String(ud.get("defl", ""))
		if u.kind == "bloater" and defl != "":
			u.deflate = "flat" if defl == "deflating" else ("" if defl == "refilling" else defl)
		var sky := String(ud.get("sky", "air"))
		if u.kind == "skywing" and sky in ["ground", "landing", "lifting"]:
			u.sky = "ground"           # (a landing finishes; a take-off starts again from the ground)
			u._sky_stats()
			if sky == "lifting":
				u.cmd_take_off()
		for pd in ud.get("pass", []):
			var pk := _kind(String(pd.get("k", "")))
			if u.kind != "balloon" or not Defs.UNITS.has(pk):
				continue
			var p := game._add_unit(pk, u.team, u.position)
			p.hp = minf(float(pd.get("hp", p.max_hp)), p.max_hp)
			p.mode = String(pd.get("mode", ""))
			p.auto_work = bool(pd.get("auto", true))
			p.kills = int(pd.get("kills", 0))
			p.cross_t = float(pd.get("cross", 0.0))
			u.take_aboard(p)
	for a in d.get("ai", []):
		for ai in game.ais:
			if ai.team == int(a["team"]):
				ai._walled = bool(a["walled"])
				ai._attack_at = int(a["attack_at"])
				# (a failed rush that switched to a balanced game stays switched)
				if AI.STRATEGIES.has(String(a.get("strategy", ""))):
					ai.strategy = String(a["strategy"])
				ai._failed = int(a.get("failed", 0))
				ai._regroup_until = float(a.get("regroup", 0.0))
	for t in game.n_players():
		game._recount_supply(t)
	game.swamp_dirty = true
	game._update_swamp()
	game._astar_dirty = true
	game.camera.position = _to_v2(d["camera"])
	game.camera.zoom = Vector2.ONE * float(d.get("zoom", 1.5))
	if game.mlog:
		game.mlog.lines = PackedStringArray(d.get("log", []))
		game.mlog.add("(match continued after it was closed)")
