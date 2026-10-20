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


static func _to_v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array else Vector2.INF


static func save(game: Game, cfg: Dictionary) -> void:
	if game == null or game.over or game.edit_mode or game.demo:
		return
	var d := {"version": ProjectSettings.get_setting("application/config/version", "dev"),
		"saved_at": Time.get_datetime_string_from_system(false, true), "cfg": cfg, "clock": game.clock,
		"players": game.players, "stats": game.stats, "eliminated": game.eliminated,
		"explored": Marshalls.raw_to_base64(game.explored), "camera": _v2(game.camera.position),
		"zoom": game.camera.zoom.x, "first_of": game._first_of,
		"log": Array(game.mlog.lines) if game.mlog else [], "ai": [], "buildings": [], "units": [], "mines": []}
	for ai in game.ais:
		d["ai"].append({"team": ai.team, "walled": ai._walled, "attack_at": ai._attack_at})
	for m in game.mines:
		d["mines"].append(m.gold)
	for b in game.buildings:
		if b.dead:
			continue
		d["buildings"].append({"k": b.kind, "t": b.team, "c": [b.cell.x, b.cell.y], "built": b.built,
			"progress": b.progress, "hp": b.hp, "queue": b.queue, "prod_t": b.prod_t, "eggs": b.eggs,
			"egg_t": b.egg_t, "morph_t": b.morph_t, "research": b.research, "research_t": b.research_t, "auto": b.auto_train, "bat": b.batteries, "v": b.vertical, "vl": b.dir_locked,
			"swamp_r": b.swamp_r, "seeded": b.seeded, "growth": b.growth, "gold_acc": b.gold_acc,
			"rally": _v2(b.rally) if b.rally != Vector2.INF else null,
			"wrally": _v2(b.worker_rally) if b.worker_rally != Vector2.INF else null})
	for u in game.units:
		if u.dead or u.off_field:
			continue
		var ud := {"k": u.kind, "t": u.team, "p": _v2(u.position), "hp": u.hp, "wind": u.wind,
			"charge": u.charge, "mode": u.mode, "tm": u.tesla_mode, "carry": u.carrying,
			"auto": u.auto_work, "push": u.push_auto, "spell_cd": u.spell_cd, "gas": u.gas, "f": _v2(u.facing),
			"kills": u.kills, "defl": u.deflate, "courier": u.courier, "bat": u.topter_bat, "oc": u.overclock_t,
			"sky": u.sky if u.sky != "to_land" else "air"}
		# the men in a balloon's basket go with it
		if not u.passengers.is_empty():
			var ps: Array = []
			for p in u.passengers:
				if is_instance_valid(p) and not p.dead:
					ps.append({"k": p.kind, "hp": p.hp, "mode": p.mode, "auto": p.auto_work, "push": p.push_auto, "kills": p.kills})
			ud["pass"] = ps
		d["units"].append(ud)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()


## Put a saved match back onto a freshly generated map (same seed).
static func restore(game: Game, d: Dictionary) -> void:
	# clear what the start placed
	for u in game.units.duplicate():
		u.queue_free()
	game.units.clear()
	for b in game.buildings.duplicate():
		game._mark(b.cell, b.size, 0)
		b.queue_free()
	game.buildings.clear()
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
	for i in mini(game.mines.size(), d["mines"].size()):
		game.mines[i].gold = int(d["mines"][i])
	for bd in d["buildings"]:
		var b := game._add_building(String(bd["k"]), int(bd["t"]), Vector2i(int(bd["c"][0]), int(bd["c"][1])), bool(bd["built"]))
		b.progress = float(bd["progress"])
		b.hp = float(bd["hp"])
		b.queue = Array(bd["queue"])
		b.prod_t = float(bd["prod_t"])
		b.eggs = int(bd["eggs"])
		b.egg_t = float(bd["egg_t"])
		b.morph_t = Array(bd["morph_t"]).map(func(x) -> float: return float(x))
		b.research = String(bd["research"])
		b.research_t = float(bd["research_t"])
		b.auto_train = String(bd.get("auto", ""))
		b.batteries = int(bd.get("bat", 0))
		b.vertical = bool(bd.get("v", false))
		b.dir_locked = bool(bd.get("vl", false))
		b.swamp_r = float(bd["swamp_r"])
		b.seeded = bool(bd["seeded"])
		b.growth = float(bd["growth"])
		b.gold_acc = float(bd["gold_acc"])
		if bd["rally"] != null:
			b.rally = _to_v2(bd["rally"])
		if bd["wrally"] != null:
			b.worker_rally = _to_v2(bd["wrally"])
		b._update_sprite()
	for ud in d["units"]:
		var u := game._add_unit(String(ud["k"]), int(ud["t"]), _to_v2(ud["p"]))
		u.hp = float(ud["hp"])
		u.wind = float(ud["wind"])
		u.charge = float(ud["charge"])
		u.mode = String(ud["mode"])
		u.tesla_mode = String(ud["tm"])
		u.carrying = int(ud["carry"])
		u.auto_work = bool(ud["auto"])
		u.push_auto = bool(ud["push"])
		u.spell_cd = float(ud["spell_cd"])
		u.gas = float(ud.get("gas", 100.0))
		u.facing = _to_v2(ud["f"])
		u.kills = int(ud.get("kills", 0))
		u.courier = bool(ud.get("courier", false))
		u.topter_bat = String(ud.get("bat", ""))
		u.overclock_t = float(ud.get("oc", 0.0))
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
			if u.kind != "balloon" or not Defs.UNITS.has(String(pd.get("k", ""))):
				continue
			var p := game._add_unit(String(pd["k"]), u.team, u.position)
			p.hp = float(pd.get("hp", p.max_hp))
			p.mode = String(pd.get("mode", ""))
			p.auto_work = bool(pd.get("auto", true))
			p.push_auto = bool(pd.get("push", true))
			p.kills = int(pd.get("kills", 0))
			u.take_aboard(p)
	for a in d.get("ai", []):
		for ai in game.ais:
			if ai.team == int(a["team"]):
				ai._walled = bool(a["walled"])
				ai._attack_at = int(a["attack_at"])
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
