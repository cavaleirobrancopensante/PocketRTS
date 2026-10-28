class_name SaveGame
## Keeps a match you closed: every few seconds (and when the app goes to the background)
## the whole state goes to user://autosave.json; the menu offers CONTINUE. The map is
## rebuilt from its seed, then every building, unit, resource and the fog are put back.
## Orders in flight aren't kept: soldiers stand where they were, workers go back to work
## (a PATROL and a BOMBARD spot are kept: they go on).

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


## A queue entry's kit as saved: the id of the live horse hitched for it means nothing next
## session (the horse is folded into the kit, its coat and health: Game.spawn_trained).
static func _kit_save(kt):
	if kt is Dictionary and kt.has("hid"):
		var c: Dictionary = kt.duplicate()
		c.erase("hid")
		return c
	return kt


## Units that are no more: a saved Pikeman comes back as a Musketeer.
## A unit kind from an older save: the Pikeman became a Musketeer (Crown rework), the
## Gearknight a Thresher and the Bolt Automaton an Arc Thrower (Clockwork rework); the Jack is
## the Springer (Defs.unit_kind).
static func _kind(k: String) -> String:
	return {"pikeman": "musketeer", "gearknight": "thresher", "bolt": "arc_thrower"}.get(k, Defs.unit_kind(k))


## A dictionary keyed by unit kind (kills by kind) with old kinds as today's.
static func _kinds_keyed(by: Dictionary) -> Dictionary:
	var out := {}
	for k in by:
		var nk := Defs.unit_kind(String(k))
		out[nk] = out.get(nk, 0) + by[k] if out.has(nk) else by[k]
	return out


## A soldier from a save without his kit: a Cuirassier was always armoured; a Musketeer had
## everything researched.
static func _old_kit(game: Game, t: int, k: String) -> Dictionary:
	if k == "cuirassier":
		return {"armour": true}
	return game.kit_all(t, k)


static func _to_v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array else Vector2.INF


static func save(game: Game, cfg: Dictionary) -> void:
	var d := capture(game, cfg)
	if not d.is_empty():
		write(JSON.stringify(d))


## The match as a save, in a few steps (Main's autosave every 15 s): the state is taken at once (capture), then the
## text is written a hundred units a frame (step) and saved (write): with hundreds of units the whole text took up
## to 20 ms in one frame. null when there is nothing to save. The text is the same as save()'s.
static func begin(game: Game, cfg: Dictionary) -> SaveJob:
	var d := capture(game, cfg)
	return SaveJob.new(d) if not d.is_empty() else null


class SaveJob:
	const MARK := "@@UNITS@@"
	var units: Array
	var head := ""
	var parts := PackedStringArray()
	var i := 0

	func _init(d: Dictionary) -> void:
		units = (d["units"] as Array).duplicate(true)     # (its own copy: nothing in it changes meanwhile)
		d["units"] = MARK
		head = JSON.stringify(d)          # (the rest at once: it holds the players' live numbers)

	## Writes up to n units' text; true once the save is written.
	func step(n := 100) -> bool:
		var e := mini(i + n, units.size())
		for k in range(i, e):
			parts.append(JSON.stringify(units[k]))
		i = e
		if i < units.size():
			return false
		SaveGame.write(head.replace("\"%s\"" % MARK, "[" + ",".join(parts) + "]"))
		return true


static func write(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()


## The whole match as one Dictionary (what save() writes as JSON); {} when there is nothing to save.
static func capture(game: Game, cfg: Dictionary) -> Dictionary:
	if game == null or game.over or game.edit_mode or game.demo:
		return {}
	var d := {"version": ProjectSettings.get_setting("application/config/version", "dev"),
		"saved_at": Time.get_datetime_string_from_system(false, true), "cfg": cfg, "clock": game.clock,
		"players": game.players, "stats": game.stats, "eliminated": game.eliminated,
		"explored": Marshalls.raw_to_base64(game.explored), "camera": _v2(game.camera.position),
		"zoom": game.camera.zoom.x, "first_of": game._first_of, "big_farms": true, "armoury": true, "farm_size": _v2(Vector2(Defs.BUILDINGS["farm"]["size"])),
		"log": Array(game.mlog.lines) if game.mlog else [], "ai": [],
		"soil_scars": game.soil_scars.map(func(sc: Array) -> Array: return [_v2(sc[0]), sc[1], sc[2], sc[3] if sc.size() > 3 else 0.0]),
		"pit_spots": game.pit_spots.map(func(sp: Array) -> Array: return [_v2(sp[0]), sp[1], sp[2]]), "buildings": [], "units": []}
	for ai in game.ais:
		d["ai"].append({"team": ai.team, "walled": ai._walled, "attack_at": ai._attack_at, "strategy": ai.strategy,
			"failed": ai._failed, "regroup": ai._regroup_until, "opening": ai.opening})
	for b in game.buildings:
		if b.dead:
			continue
		d["buildings"].append({"k": b.kind, "t": b.team, "c": [b.cell.x, b.cell.y], "built": b.built,
			"progress": b.progress, "hp": b.hp, "queue": b.queue, "kits": b.kits.map(func(kt): return _kit_save(kt)), "ar": b.auto_refit, "prod_t": b.prod_t, "eggs": b.eggs,
			"egg_t": b.egg_t, "morph_t": b.morph_t, "auto": b.auto_train, "bat": b.batteries, "v": b.vertical, "vl": b.dir_locked, "gl": b.locked,
			"swamp_r": b.swamp_r, "seeded": b.seeded, "ghost": b.ghost, "growth": b.growth, "gold_acc": b.gold_acc,
			"stock": snappedf(b.stock, 0.1), "gb": b.gear_big, "gs": snappedf(b.gear_swap_t, 0.01), "gst": b.gear_swap_to, "soil": b.soil, "sw": b.soil_warned, "lode": snappedf(b.lode, 0.01), "lw": b.lode_warned, "lv": b.level, "up": b.upgrade_t,
			"crate": "ground" if b.crate == "carried" else b.crate,
			"rally": _v2(b.rally) if b.rally != Vector2.INF else null,
			"wrally": _v2(b.worker_rally) if b.worker_rally != Vector2.INF else null})
	# every saved unit's number (in this list's order), so horses can name who leads them
	var ids := {}
	for u in game.units:
		if u.dead or u.off_field or (u.kind == "horse" and is_instance_valid(u.into) and u.into is Building and u.horse_rid == 0):
			continue           # (a horse taken to a building, or hitched there, is already in its queue entry; one
			                   # kept for a gun still on its way is saved with its reservation: it is fetched again)
		ids[u] = ids.size()
	for u in game.units:
		if not ids.has(u):
			continue
		var ud := {"k": u.kind, "t": u.team, "p": _v2(u.position), "hp": u.hp, "wind": u.wind,
			# (a Mist Toad's TONGUE windup isn't kept: it comes back with that energy unspent)
			"charge": u.charge + (float(Defs.TONGUE["cost"]) if u.tongue_stage == "windup" else 0.0), "mode": u.mode, "tm": u.tesla_mode, "carry": u.carrying, "lf": u.load_f,
			"auto": u.auto_work, "cross": u.cross_t, "spell_cd": u.spell_cd, "gas": u.gas, "f": _v2(u.facing),
			"kills": u.kills, "ff": u.friendly_kills, "defl": u.deflate, "courier": u.courier, "bat": u.topter_bat, "oc": u.overclock_t,
			"sky": u.sky if u.sky != "to_land" else "air",
			"pw": u.powder, "ab": u._auto_bayonet, "sup": u.supplying, "tw": u.team_want,
			"spin": u.spin, "brace": u.braced, "shd": u.shield_up, "ovc": u.overcharge_t, "sw": u.self_wind_t, "ct": u.carry_t}
		if Defs.ARMOURED.has(u.kind):
			ud["kit"] = u.get_kit()
			if not u.refit.is_empty():
				ud["rf"] = u.refit       # on his way to a refit (paid): he goes again after loading
				ud["rfp"] = u.refit_paid
		if u.auto_refit:
			ud["ar"] = true
		if u.owl_t >= 0.0:
			ud["owl"] = snappedf(u.owl_t, 0.01)      # (a Swift turning into a Ticking Owl, paid)
		if u.net_t > 0.0:
			ud["net"] = snappedf(u.net_t, 0.01)      # (caught in a Netter's net)
		if u.kind == Defs.BALLISTA_KIND and u.cooldown > 0.0:
			ud["rl"] = snappedf(u.cooldown, 0.01)    # (a Spring Ballista's spring still being wound)
		if u.crew_of != null and ids.has(u.crew_of):
			ud["crew"] = ids[u.crew_of]              # (a Winder crewing a Spring Ballista: scripts/ballista.gd)
		if u.kind == Defs.GREAT_WINDER_KIND:
			ud["gw"] = [0, u.auto_repair, u.auto_sweep]     # (a Great Winder: MEND and SWEEP, scripts/great_winder.gd; the first
			# slot held its PARTS until 0.14.102, when the sweep began to pay cogs at once: kept as 0 so the layout stays)
		if u.coat != "":
			ud["coat"] = u.coat
		# horses: who leads it, where it grazes; riders and guns: their horse's health, a gun's
		# harness; a man getting on (or off) a horse, and a Dragoon fighting on foot
		if u.kind == "horse":
			if u.leader and ids.has(u.leader):
				ud["lead"] = ids[u.leader]
			if u.graze_at != Vector2.INF:
				ud["graze"] = _v2(u.graze_at)
		if u.is_mounted() or Defs.HARNESSED.has(u.kind):
			ud["hh"] = snappedf(u.horse_hp, 0.01)
		if u.horse_miles > 0.0:
			ud["hm"] = snappedf(u.horse_miles, 0.1)
		if Defs.HARNESSED.has(u.kind) and not u.harnessed:
			ud["harn"] = false
		if not u.team_horses.is_empty():
			ud["team"] = u.team_horses.map(func(th: Dictionary) -> Array: return [String(th.get("coat", "")), snappedf(float(th.get("hp", 1.0)), 0.01), snappedf(float(th.get("m", 0.0)), 0.1)])
		if u.horse_rid != 0:
			ud["rid"] = u.horse_rid      # a horse kept for a recruit, or the new rider it's kept for
			if u.rally_after != Vector2.INF:
				ud["ra"] = _v2(u.rally_after)
		if u.auto_mount:
			ud["am"] = true
		if u.hold_fire:
			ud["hf"] = true              # HOLD FIRE (any Crown gun)
		if u.has_pistol():
			# the cavalry's pistol: loaded or not, an Officer's reload so far
			ud["pl"] = u.pistol
			if u.pistol_t > 0.0:
				ud["plt"] = snappedf(u.pistol_t, 0.01)
		if u.kind == "cuirassier":
			# the rider's fight on the move (scripts/ride_by.gd) and his gallop toward a charge
			ud["rb"] = [u.rb_state, u.rb_side, snappedf(u.rb_t, 0.01), snappedf(u.rb_last, 0.01), snappedf(u.run_t, 0.01),
				snappedf(u.rb_head.x, 0.001), snappedf(u.rb_head.y, 0.001)]
		if u.patrol_a != Vector2.INF:
			ud["pat"] = [_v2(u.patrol_a), _v2(u.patrol_b)]
		if u.order == "bombard":
			ud["bomb"] = _v2(u.order_point)      # BOMBARD: the spot it keeps firing at (it goes on after a load)
			if u.gnd_a.distance_to(u.gnd_b) >= 1.0:
				ud["bomb_ab"] = [_v2(u.gnd_a), _v2(u.gnd_b)]     # (ATTACK GROUND along a stretch of a dragged line)
		if u.steed and ids.has(u.steed):
			ud["steed"] = ids[u.steed]
		if u.order == "mount" and u.order_target and ids.has(u.order_target):
			ud["mt"] = ids[u.order_target]
		elif u.order == "dismount":
			ud["dm"] = true
		elif u.order == "lead" and u.order_target and ids.has(u.order_target):
			ud["lt"] = ids[u.order_target]
		elif u.is_hauler():
			ud["hallc"] = [(u.home_mine as Building).cell.x, (u.home_mine as Building).cell.y]    # (a hauler: his Town Hall)
		# the men in a balloon's basket go with it
		if not u.passengers.is_empty():
			var ps: Array = []
			for p in u.passengers:
				if is_instance_valid(p) and not p.dead:
					ps.append({"k": p.kind, "hp": p.hp, "mode": p.mode, "auto": p.auto_work, "kills": p.kills, "cross": p.cross_t, "kit": p.get_kit(), "pw": p.powder})
			ud["pass"] = ps
		if u.haul_t >= 0.0:
			# a keg on the balloon's rope (paid for): it keeps climbing after a load
			ud["haul"] = [u.haul_t, u.haul_shots, u.haul_at.x, u.haul_at.y]
		if Defs.cw_roster:
			var cpl = CwConsist.save_tag(u)
			if cpl != null:
				ud["cpl"] = cpl                  # coupled into a train: [train id, place in it]
		d["units"].append(ud)
	# control groups (units by their number in this list, buildings by their cell) and the
	# camera hotkeys
	d["groups"] = game.groups.map(func(g: Array) -> Array:
		var out: Array = []
		for e in g:
			if not is_instance_valid(e) or e.dead:
				continue
			if e is Building:
				out.append(["b", e.cell.x, e.cell.y])
			elif ids.has(e):
				out.append(["u", ids[e]])
		return out)
	d["cams"] = game.cam_slots.map(func(c) -> Variant: return null if c == null else [c[0].x, c[0].y, c[1]])
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
	d["trains"] = game.line_net.rails.save()    # the Clockwork's trains (and the soldiers riding them)
	d["line"] = game.line_net.save()           # the Clockwork Line: [x, y, team, hp, progress, built]
	return d


## Control groups and camera hotkeys back (saves from before them have none).
static func _restore_groups(game: Game, d: Dictionary, made: Array) -> void:
	var gs: Array = d.get("groups", [])
	for gi in mini(gs.size(), game.groups.size()):
		var out: Array = []
		for ent in gs[gi]:
			if ent is Array and String(ent[0]) == "u":
				var i := int(ent[1])
				if i >= 0 and i < made.size() and made[i] != null and is_instance_valid(made[i]):
					out.append(made[i])
			elif ent is Array and String(ent[0]) == "b":
				for b in game.buildings:
					if not b.dead and b.cell == Vector2i(int(ent[1]), int(ent[2])) and b.team == game.human:
						out.append(b)
						break
		game.groups[gi] = out
	var cs: Array = d.get("cams", [])
	for i in mini(cs.size(), game.cam_slots.size()):
		var c = cs[i]
		game.cam_slots[i] = [Vector2(float(c[0]), float(c[1])), float(c[2])] if c is Array and c.size() >= 3 else null


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
	game.ghost_cells.clear()
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
		# (saves from before the Armoury: every Cuirassier charged, so the Crown has the drill)
		if not d.get("armoury", false) and game.faction_of(t) == "crown":
			game.players[t]["tech"]["charge"] = true
	for t in game.stats.size():
		if t < d["stats"].size():
			var st: Dictionary = d["stats"][t]
			for k in st:
				game.stats[t][k] = _kinds_keyed(st[k]) if k == "kills_by" and st[k] is Dictionary else st[k]
	for t in game.eliminated.size():
		game.eliminated[t] = bool(d["eliminated"][t])
	game._first_of = {}
	for fk in d.get("first_of", {}):
		var at := String(fk).find(":")      # ("team:kind": an old kind as today's)
		game._first_of[String(fk).left(at + 1) + Defs.unit_kind(String(fk).substr(at + 1)) if at >= 0 else fk] = d["first_of"][fk]
	var ex := Marshalls.base64_to_raw(String(d["explored"]))
	if ex.size() == game.explored.size():
		game.explored = ex
		game.fog_base_dirty = true
	# (Farms last: in saves from before Farms grew (to 5x4, then 6x5, then 6x6 tiles) each may have to
	# shift a little to fit between what stands round it)
	var blist: Array = Array(d["buildings"]).filter(func(x) -> bool: return String(x["k"]) != "farm") \
		+ Array(d["buildings"]).filter(func(x) -> bool: return String(x["k"]) == "farm")
	for bd in blist:
		var bk := String(bd["k"])
		if bk == "bone_midden":
			bk = "brood_pen"        # (older saves: the Bone Midden became the Brood Pen)
		if not Defs.BUILDINGS.has(bk):
			continue
		var at := Vector2i(int(bd["c"][0]), int(bd["c"][1]))
		if bk == "farm" and Array(d.get("farm_size", [])) != [float(Defs.BUILDINGS["farm"]["size"].x), float(Defs.BUILDINGS["farm"]["size"].y)]:
			at = _fit(game, at, Defs.BUILDINGS[bk]["size"])
		var b := game._add_building(bk, int(bd["t"]), at, bool(bd["built"]), bool(bd.get("ghost", false)))
		b.progress = float(bd["progress"])
		b.set_level(int(bd.get("lv", 1)))      # (a Brood hall's level, before its health; older saves: a Burrow)
		b.upgrade_t = float(bd.get("up", -1.0))
		b.hp = float(bd["hp"])
		# (research is in the queue as "@key")
		# (and beside it what each queued Musketeer was paid to come out with; older saves: nothing)
		var saved_kits: Array = Array(bd.get("kits", []))
		var saved_q: Array = Array(bd["queue"])
		b.queue = []
		b.kits = []
		for qi in saved_q.size():
			var x := String(saved_q[qi]) if String(saved_q[qi]).begins_with("@") else _kind(String(saved_q[qi]))
			if Defs.RESEARCH.has(x.substr(1)) if x.begins_with("@") else Defs.UNITS.has(x):
				b.add_entry(x, saved_kits[qi] if qi < saved_kits.size() and saved_kits[qi] is Dictionary else {})
		b.auto_refit = bool(bd.get("ar", false))
		b.prod_t = float(bd["prod_t"])
		b.eggs = int(bd["eggs"])
		b.egg_t = float(bd["egg_t"])
		b.morph_t = Array(bd["morph_t"]).map(func(x) -> float: return float(x))
		# (older saves: research ran beside the queue; it goes to the front now)
		var old_rs := String(bd.get("research", ""))
		if Defs.RESEARCH.has(old_rs) and not b.queue.has("@" + old_rs):
			b.queue.push_front("@" + old_rs)
			b.kits.push_front({})
			b.prod_t = float(bd.get("research_t", 0.0))
		b.auto_train = _kind(String(bd.get("auto", "")))
		if not d.get("armoury", false) and b.auto_train == "cuirassier" and not game.has_tech(b.team, "armour"):
			b.auto_train = "horseman"      # (before the Armoury, "cuirassier" was the one horseman)
		b.batteries = int(bd.get("bat", 0))
		b.stock = float(bd.get("stock", 0.0))
		b.gear_big = bool(bd.get("gb", false)) or GearNet.big_only(b.kind)      # (the gear field's connecting gear: scripts/gear.gd)
		b.gear_swap_t = float(bd.get("gs", -1.0))
		b.gear_swap_to = bool(bd.get("gst", false))
		b.vertical = bool(bd.get("v", false))
		b.dir_locked = bool(bd.get("vl", false))
		b.locked = bool(bd.get("gl", false))
		b.swamp_r = float(bd["swamp_r"])
		b.seeded = bool(bd["seeded"])
		b.crate = String(bd.get("crate", ""))        # (older saves: no crates)
		b.growth = float(bd["growth"])
		b.gold_acc = float(bd["gold_acc"])
		if b.kind == "town_hall" or b.kind == "clocktower" or (b.kind == "feeding_pit" and d.has("pit_spots")):
			b.soil = float(bd.get("soil", b.reserve()))     # (older saves: fresh soil / coal; a pit's own ground from 0.14.37 on)
			b.soil_warned = int(bd.get("sw", 0))
		elif b.kind == "feeding_pit":
			b.soil = b.reserve()        # (saves from before the pits had their own ground: fresh ground)
			b.soil_warned = 0
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
	for b in game.buildings:
		if b.kind == "gate":
			game.relink_walls(b.cell)     # (the palisade joins its gates the way they were saved)
			if b.locked:
				b.locked = false
				game.set_gate_locked(b, true, true)
	game.soil_scars.clear()
	for sc in d.get("soil_scars", []):
		var sk := String(sc[2]) if sc.size() > 2 else "town_hall"
		game.soil_scars.append([_to_v2(sc[0]), float(sc[1]), sk, float(sc[3]) if sc.size() > 3 else float(Defs.LODE.get(sk, 0.0))])
	game.pit_spots.clear()
	for sp in d.get("pit_spots", []):
		game.pit_spots.append([_to_v2(sp[0]), float(sp[1]), int(sp[2]) if sp.size() > 2 else -1])
	for b in game.buildings:
		if b.kind == "farm" or b.kind == "feeding_pit":
			b._update_sprite()      # (its tired-soil tint needs the halls back first)
	game.line_net.clear()
	if d.has("line"):
		game.line_net.load_rows(d["line"])
	else:
		for t in game.n_players():
			if game.factions[t] == "clockwork":
				game.line_net.lay_start(t)        # (a save from before the Line: a main to the first buildings)
	for cd in d.get("crates", []):
		var cc := Vector2i(int(cd[3]), int(cd[4]))
		for b in game.buildings:
			if b.team == int(cd[2]) and b.cell == cc and not b.built and b.crate_obj == null:
				game.drop_crate(b, Vector2(float(cd[0]), float(cd[1])), float(cd[5]))
				break
	for b in game.buildings:
		if b.crate == "ground" and b.crate_obj == null:
			b.crate = "tower"       # (its crate wasn't found: a Winder fetches another)
	var made: Array = []      # the saved units in order (null where one couldn't be made)
	for ud in d["units"]:
		var uk := _kind(String(ud["k"]))
		if not Defs.UNITS.has(uk):
			made.append(null)
			continue
		var u := game._add_unit(uk, int(ud["t"]), _to_v2(ud["p"]))
		made.append(u)
		if Defs.ARMOURED.has(uk):
			# his own refits (older saves: research applied to every Musketeer, so he has it
			# all; and every Cuirassier was armoured)
			u.set_kit(ud["kit"] if ud.get("kit") is Dictionary else _old_kit(game, u.team, uk))
		u.auto_refit = bool(ud.get("ar", false))
		u.owl_t = float(ud.get("owl", -1.0)) if uk == Defs.CUCKOO else -1.0
		u.net_t = float(ud.get("net", 0.0))
		if u.net_t > 0.0:
			u.stun_t = maxf(u.stun_t, u.net_t)      # (still caught: it stays put; a flyer is down on the ground)
			u._low = 1.0 if u.d.get("air", false) else 0.0
		if uk == Defs.BALLISTA_KIND:
			u.cooldown = float(ud.get("rl", 0.0))
			u.loaded = u.cooldown <= 0.0
		if uk == Defs.GREAT_WINDER_KIND and ud.get("gw") is Array and (ud["gw"] as Array).size() >= 3:
			u.auto_repair = bool(ud["gw"][1])
			u.auto_sweep = bool(ud["gw"][2])
		if u.coat != "" and HorseCoat.COATS.has(String(ud.get("coat", ""))):
			u.coat = String(ud["coat"])      # (older saves: the coat it was just given)
			HorseCoat.apply(u)
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
		u.team_want = int(ud.get("tw", 0))
		u.facing = _to_v2(ud["f"])
		u.kills = int(ud.get("kills", 0))
		u.friendly_kills = int(ud.get("ff", 0))
		u.courier = bool(ud.get("courier", false))
		u.topter_bat = String(ud.get("bat", ""))
		u.overclock_t = float(ud.get("oc", 0.0))
		u.spin = float(ud.get("spin", 0.0))
		u.overcharge_t = float(ud.get("ovc", 0.0))
		u.self_wind_t = float(ud.get("sw", 0.0))
		u.carry_t = float(ud.get("ct", 0.0))
		if bool(ud.get("brace", false)):
			u.set_brace(true)
		if bool(ud.get("shd", false)) and u.kind == ShieldWall.KIND:
			u.shield_up = true          # (SHIELD FORWARD: raised, settled)
			u.armor = float(u.d["armor"]) + float(Defs.SHIELD_WALL["armor"])
		if ud.get("rf") is Array and not (ud["rf"] as Array).is_empty():
			# on his way to a refit he'd paid for: he goes again (or it's paid back)
			var rfp: Array = ud.get("rfp", [0, 0])
			var fee := [int(rfp[0]), int(rfp[1])]
			var place := game.refit_place(u.team, u.position)
			var what: Array = (ud["rf"] as Array).map(func(x) -> String: return String(x)).filter(func(x: String) -> bool: return Defs.RESEARCH.has(x))
			if place and not what.is_empty():
				u.cmd_refit(place, what, fee)
			else:
				game.refund_refit(u.team, fee)
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
			if Defs.ARMOURED.has(pk):
				p.set_kit(pd["kit"] if pd.get("kit") is Dictionary else _old_kit(game, u.team, pk))
			p.hp = minf(float(pd.get("hp", p.max_hp)), p.max_hp)
			p.mode = String(pd.get("mode", ""))
			p.auto_work = bool(pd.get("auto", true))
			p.kills = int(pd.get("kills", 0))
			p.cross_t = float(pd.get("cross", 0.0))
			p.powder = minf(float(pd.get("pw", p.powder)), p._pmax)
			u.take_aboard(p)
		var hl: Array = ud.get("haul", [])
		if u.kind == "balloon" and hl.size() == 4:
			u.haul_t = float(hl[0])
			u.haul_shots = float(hl[1])
			u.haul_at = Vector2(float(hl[2]), float(hl[3]))
		u.horse_hp = float(ud.get("hh", 1.0))
		u.horse_miles = float(ud.get("hm", 0.0))
		if u.horse_miles > 0.0 and (u.kind == "horse" or u.is_mounted()):
			# a seasoned horse's health (the saved hp was capped at a green one's)
			u.max_hp += Unit.horse_bonus_hp(u.horse_miles)
			u.hp = minf(float(ud.get("hp", u.hp)), u.max_hp)
		if Defs.HARNESSED.has(u.kind) and not bool(ud.get("harn", true)):
			u.harnessed = false
			HorseCoat.apply(u)
		if Defs.HARNESSED.has(u.kind) and ud.get("team") is Array:
			for th in ud["team"]:
				if th is Array and th.size() >= 2 and u.horse_count() < int(Defs.HORSES["team_max"]):
					u.team_horses.append({"coat": String(th[0]), "hp": float(th[1]), "m": float(th[2]) if th.size() > 2 else 0.0})
		u.horse_rid = int(ud.get("rid", 0))
		if ud.get("ra") is Array:
			u.rally_after = _to_v2(ud["ra"])
		u.auto_mount = bool(ud.get("am", false))
		u.hold_fire = bool(ud.get("hf", false)) and u.has_gun()
		if u.has_pistol():
			u.pistol = bool(ud.get("pl", true))           # (older saves: loaded)
			u.pistol_t = float(ud.get("plt", 0.0))
			u.powder = minf(u.powder, u._pmax)            # (older saves: an Officer's 10 carbine shots)
		if ud.get("rb") is Array and (ud["rb"] as Array).size() >= 7:
			var rb: Array = ud["rb"]
			u.rb_state = String(rb[0])
			u.rb_side = int(rb[1])
			u.rb_t = float(rb[2])
			u.rb_last = float(rb[3])
			u.run_t = float(rb[4])
			u.rb_head = Vector2(float(rb[5]), float(rb[6]))
		if ud.get("pat") is Array and (ud["pat"] as Array).size() == 2:
			u.patrol_a = _to_v2(ud["pat"][0])
			u.patrol_b = _to_v2(ud["pat"][1])
		if u.kind == "horse" and ud.get("graze") is Array:
			u.graze_at = _to_v2(ud["graze"])
		if ud.get("bomb") is Array and u.can_ground_attack():
			var ab: Array = ud.get("bomb_ab", []) if ud.get("bomb_ab") is Array else []
			if ab.size() == 2:
				u.cmd_bombard(_to_v2(ud["bomb"]), _to_v2(ab[0]), _to_v2(ab[1]))
			else:
				u.cmd_bombard(_to_v2(ud["bomb"]))      # (set up as it was saved: "tm"; it fires on at the spot)
	# the horses' ties: who leads which (in their string's order), a man's own horse, and a
	# man on his way to mount or lead one goes on with it
	var units_d: Array = d["units"]
	for i in units_d.size():
		var ud: Dictionary = units_d[i]
		var u = made[i]
		if u == null:
			continue
		var li := int(ud.get("lead", -1))
		if li >= 0 and li < made.size() and made[li] != null:
			made[li].take_reins(u)
		var si := int(ud.get("steed", -1))
		if si >= 0 and si < made.size() and made[si] != null:
			u.steed = made[si]
		var ci := int(ud.get("crew", -1))
		if ci >= 0 and ci < made.size() and made[ci] != null and made[ci].kind == Defs.BALLISTA_KIND:
			Ballista.take_crew(made[ci], u)       # (back on the Spring Ballista he crewed)
	for i in units_d.size():
		var ud: Dictionary = units_d[i]
		var u = made[i]
		if u == null:
			continue
		var mi := int(ud.get("mt", -1))
		var ti := int(ud.get("lt", -1))
		if mi >= 0 and mi < made.size() and made[mi] != null:
			u.cmd_mount(made[mi])
		elif ti >= 0 and ti < made.size() and made[ti] != null:
			u.cmd_lead(made[ti])
		elif bool(ud.get("dm", false)):
			var am: bool = u.auto_mount
			u.cmd_dismount(am)
		elif ud.get("hallc") is Array:
			for hb in game.buildings:
				if hb.team == u.team and not hb.dead and hb.haul_cap() > 0 and hb.cell == Vector2i(int(ud["hallc"][0]), int(ud["hallc"][1])):
					u.cmd_gather(hb)       # (back at his Town Hall: a hauler again, no job)
	if Defs.cw_roster:
		CwConsist.restore(game, units_d, made)       # coupled rail trains
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
				ai.opening = String(a.get("opening", ai.opening))
	# (saves from before the windmill stood in the middle of its Farm (v0.7.89): a farm hand
	# left on an old crop row inside its block steps out onto the fields)
	for b in game.buildings:
		if b.kind == "farm" and not b.ghost and not b.dead:
			var blk := Rect2(b.rect().position + Vector2(Building.FARM_BLOCK.position) * Defs.TILE, Vector2(Building.FARM_BLOCK.size) * Defs.TILE)
			game._push_units_out(blk)
	for t in game.n_players():
		game._recount_supply(t)
	game._capital.clear()          # (the capital is found again from the loaded Burrows)
	game._capital_had.clear()
	game.swamp_dirty = true
	game._update_swamp()
	game._astar_dirty = true
	game.camera.position = _to_v2(d["camera"])
	game.camera.zoom = Vector2.ONE * float(d.get("zoom", 1.5))
	if d.has("trains"):
		game.line_net.rails.load_rows(d["trains"])
	_restore_groups(game, d, made)
	if game.mlog:
		game.mlog.lines = PackedStringArray(d.get("log", []))
		game.mlog.add("(match continued after it was closed)")
