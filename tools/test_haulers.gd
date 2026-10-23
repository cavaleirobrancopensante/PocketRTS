extends SceneTree
## Town Hall haulers (Defs.HAUL), end to end:
##   godot --headless --fixed-fps 30 --script res://tools/test_haulers.gd
## A Crown player (you) against a Brood player whose AI is switched off; everything is set up
## by hand on open ground. Prints PASS / FAIL per check and "ALL PASS" at the end (exit 1 on
## a failure).
##  1. assigning haulers: the same right-click as a Farm; free/assigned counter; unassigning
##  2. a Horseman queued with a Horse Breeder training his horse: the hauler fetches it by the
##     leash when it spawns, hitches it at the Barracks, and walks home (the recruit comes out
##     riding it, or mounts it where the hauler left it)
##  3. two horses wanted far apart: two haulers, never the same horse; close together: one
##     hauler leads both on one trip
##  4. interrupted trips: an ordered-away hauler and a killed hauler release the reservation, the
##     other hauler serves it again
##  5. a Powder Wagon on SUPPLY: kegs from the Mill (paid from the bank), never more haulers than
##     room, farm and mill workers stay at their posts
##  6. a gun's horse is hitched at the Foundry by a hauler
##  7. no hauler: the old fallback (the recruit fetches his own horse, a gun's walks over)
var main: Node
var t := 0.0
var g
var started := false
var fails := 0
var origin := Vector2i(-1, -1)
var hall: Building
var bar: Building
var fdy: Building
var br: Building
var mill: Building
var farm: Building


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	t += _delta
	if t > 0.2 and main.game == null:
		main.start({"map": "hollowfen", "seed": 4242, "slots": [
			{"who": "you", "faction": "crown", "colour": 0, "side": 0},
			{"who": "easy", "faction": "brood", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if not started and t > 1.0:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		_run()
	return false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func wait(sec: float) -> void:
	var end: float = g.clock + sec
	while g.clock < end:
		await physics_frame


func wait_for(cond: Callable, sec: float) -> bool:
	var end: float = g.clock + sec
	while g.clock < end:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func at(dx: float, dy: float) -> Vector2:
	return Vector2(origin) * Defs.TILE + Vector2(dx, dy)


func unit(k: String, p: Vector2, team := 0) -> Unit:
	return g._add_unit(k, team, p)


func _open_area(w: int, h: int) -> Vector2i:
	var starts: Array = []
	for b in g.buildings:
		starts.append(b.center())
	for y in range(4, g.H - h - 4):
		for x in range(4, g.W - w - 4):
			var ok := true
			var h0: int = g.height[g.idx(Vector2i(x, y))]
			for yy in h:
				for xx in w:
					var c := Vector2i(x + xx, y + yy)
					if g.solid[g.idx(c)] != 0 or g.ramp[g.idx(c)] != 0 or g.height[g.idx(c)] != h0:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var p: Vector2 = g.cell_center(Vector2i(x + w / 2, y + h / 2))
			for s in starts:
				if p.distance_to(s) < 700.0:
					ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func labourer(p: Vector2) -> Unit:
	var u := unit("labourer", p)
	u.auto_work = false
	return u


## Assign by the player's right-click on the Town Hall.
func assign(us: Array) -> void:
	g.smart_command(us, hall.center())


func haulers() -> Array:
	return hall.haulers()


func _run() -> void:
	origin = _open_area(26, 20)
	if origin.x < 0:
		print("FAIL: no open ground for the test")
		quit(1)
		return
	g.reveal = true
	g.players[0]["gold"] = 20000
	g.players[0]["res2"] = 5000.0
	g.players[0]["cap"] = 200
	for u in g.units.duplicate():
		if u.position.distance_to(at(500, 400)) < 1100.0:
			g.consume_unit(u)
	await physics_frame
	g._add_building("cottage", 0, origin + Vector2i(23, 17), true)
	hall = g._add_building("town_hall", 0, origin + Vector2i(1, 1), true)
	br = g._add_building("horse_breeder", 0, origin + Vector2i(9, 1), true)
	bar = g._add_building("barracks", 0, origin + Vector2i(19, 1), true)
	fdy = g._add_building("foundry", 0, origin + Vector2i(19, 8), true)
	mill = g._add_building("powder_mill", 0, origin + Vector2i(1, 8), true)
	farm = g._add_building("farm", 0, origin + Vector2i(1, 14), true)
	for b in g.buildings:
		if b.team == 0:
			b.supply()
	bar.rally = at(700, 330)
	fdy.rally = at(700, 560)
	await _counter()
	await _horseman()
	await _two_horses()
	await _interrupt()
	await _kegs()
	await _gun()
	await _save_load()
	await _fallback()
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	quit(0 if fails == 0 else 1)


func _clear_horses() -> void:
	for h in g.horses_of(0).duplicate():
		g.consume_unit(h)
	for b in [br, bar, fdy]:
		b.queue.clear()
		b.kits.clear()
		b.prod_t = 0.0
	await physics_frame


# ---------------------------------------------------------------- 1. assigning

func _counter() -> void:
	check(hall.haul_cap() == 6 and hall.haulers().is_empty(), "a Town Hall takes haulers (cap %d), none yet" % hall.haul_cap())
	check("%d/%d" % [hall.haulers_free(), hall.haulers().size()] == "0/0", "the counter reads 0/0")
	var a := labourer(at(150, 260))
	var b := labourer(at(190, 260))
	assign([a])
	check(hall.haulers().size() == 1 and a.is_hauler() and a.home_mine == hall, "right-click on the Town Hall assigns a hauler")
	check("%d/%d" % [hall.haulers_free(), hall.haulers().size()] == "1/1", "1 worker: 1/1")
	assign([b])
	check("%d/%d" % [hall.haulers_free(), hall.haulers().size()] == "2/2", "2 workers: 2/2")
	check(g.workers(0).filter(func(u: Unit) -> bool: return u == a or u == b).is_empty(), "haulers aren't counted among the free workers")
	await wait(3.0)
	check(a.order == "gather" and a.haul_job.is_empty() and a.keg == false, "idle haulers wait by the hall and do not go farming")
	check(a.position.distance_to(hall.center()) < 200.0, "…they stand by the hall (%.0f px)" % a.position.distance_to(hall.center()))
	# unassigning is an order away
	b.cmd_move(at(300, 500))
	check(hall.haulers().size() == 1 and not b.is_hauler(), "ordering a hauler elsewhere unassigns him (1/1)")
	assign([b])
	check(hall.haulers().size() == 2, "and the right-click assigns him again")


# ---------------------------------------------------------------- 2. a Horseman's horse

func _horseman() -> void:
	await _clear_horses()
	var gold0: int = g.players[0]["gold"]
	check(g.train(bar, "horseman") == "", "HORSEMAN queued (%s)" % g.can_train(bar, "horseman"))
	var rid := int(bar.kit_at(bar.queue.size() - 1).get("rid", 0))
	check(rid != 0 and g.rid_breeder(0, rid) == br, "the Horse Breeder trains his horse, kept for him")
	check(g.hauler_serves_rid(0, rid), "with haulers the horse is brought, not walked")
	await wait_for(func() -> bool: return g.reserved_horse(0, rid) != null, 25.0)
	var horse: Unit = g.reserved_horse(0, rid)
	check(horse != null, "the horse spawns at the Breeder")
	if horse == null:
		return
	await wait_for(func() -> bool: return horse.leader != null, 15.0)
	check(horse.leader != null and horse.leader is Unit and (horse.leader as Unit).is_hauler(), "a hauler takes it by the leash")
	var hl: Unit = horse.leader
	check(hl != null and hl.led.has(horse) and String(hl.haul_job.get("k", "")) == "horse", "…it is on his leash, his job is 'horse' (work: %s)" % (hl.work if hl else "?"))
	check("%d/%d" % [hall.haulers_free(), hall.haulers().size()] == "1/2", "one hauler out: the counter reads 1/2")
	await wait_for(func() -> bool: return horse.into == bar or not is_instance_valid(horse) or horse.dead, 30.0)
	var delivered: bool = horse.into == bar or not is_instance_valid(horse) or horse.dead or (bar.kit_at(0).has("coat") and int(bar.kit_at(0).get("rid", 0)) == 0)
	check(delivered, "he leads it to the Barracks and hitches it")
	await wait_for(func() -> bool: return hl.haul_job.is_empty(), 30.0)
	check(hl.haul_job.is_empty() and hl.is_hauler() and hl.position.distance_to(hall.center()) < 260.0, "then he is back at the Town Hall (%.0f px)" % hl.position.distance_to(hall.center()))
	check("%d/%d" % [hall.haulers_free(), hall.haulers().size()] == "2/2", "counter back to 2/2")
	var riders := func() -> Array: return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cuirassier" and not u.dead)
	await wait_for(func() -> bool: return not riders.call().is_empty(), 40.0)
	check(not riders.call().is_empty(), "the Horseman rides out on the horse the hauler brought")
	check(int(g.stats[0].get("hauled_horse", 0)) >= 1, "counted: %d horse(s) hauled" % int(g.stats[0].get("hauled_horse", 0)))
	for r in riders.call():
		g.consume_unit(r)


# ---------------------------------------------------------------- 3. two horses

func _two_horses() -> void:
	await _clear_horses()
	# two spare horses at the Breeder, far apart (more than the batch distance)
	var h1 := unit("horse", br.center() + Vector2(-170, 110))
	var h2 := unit("horse", br.center() + Vector2(170, 110))
	h1.graze_at = h1.position
	h2.graze_at = h2.position
	await physics_frame
	check(g.spare_horse(0, bar) != null, "spare horses stand about the Breeder")
	check(g.train(bar, "horseman") == "" and g.train(bar, "horseman") == "", "two Horsemen queued")
	var rids: Array = []
	for i in bar.kits.size():
		rids.append(int(bar.kit_at(i).get("rid", 0)))
	check(rids.size() == 2 and rids[0] != rids[1] and rids[0] != 0, "each holds its own reservation")
	var seen := {}
	var dup := false
	await wait_for(func() -> bool:
		var cl: Array = []
		for h in [h1, h2]:
			if is_instance_valid(h) and h.claimed != null and is_instance_valid(h.claimed):
				cl.append(h.claimed)
			elif is_instance_valid(h) and h.leader != null:
				cl.append(h.leader)
		return cl.size() == 2, 10.0)
	var c1: Unit = h1.claimed if h1.claimed != null else h1.leader
	var c2: Unit = h2.claimed if h2.claimed != null else h2.leader
	check(c1 != null and c2 != null and c1 != c2, "far apart: two different haulers, never the same horse")
	for i in 600:
		await physics_frame
		for h in [h1, h2]:
			if is_instance_valid(h) and not h.dead and h.leader != null:
				var key: int = h.get_instance_id()
				seen[key] = h.leader
		if seen.size() == 2 and (seen.values()[0] == seen.values()[1]):
			dup = true
		if not is_instance_valid(h1) and not is_instance_valid(h2):
			break
	check(not dup, "each horse was led by its own hauler")
	await wait_for(func() -> bool: return haulers().all(func(u: Unit) -> bool: return u.haul_job.is_empty()), 40.0)
	check(haulers().all(func(u: Unit) -> bool: return u.haul_job.is_empty()), "both haulers are back (2/2)")
	await wait_for(func() -> bool: return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cuirassier" and not u.dead).size() == 2, 70.0)
	var rs: Array = g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cuirassier" and not u.dead)
	check(rs.size() == 2, "both Horsemen came out riding (%d)" % rs.size())
	for r in rs:
		g.consume_unit(r)
	await _clear_horses()
	# close together: one hauler, one trip, both on the leash
	var h3 := unit("horse", br.center() + Vector2(-100, 110))
	var h4 := unit("horse", br.center() + Vector2(-60, 130))
	h3.graze_at = h3.position
	h4.graze_at = h4.position
	g.train(bar, "horseman")
	g.train(bar, "horseman")
	await wait_for(func() -> bool: return haulers().any(func(u: Unit) -> bool: return u.led.size() == 2), 20.0)
	var two: Array = haulers().filter(func(u: Unit) -> bool: return u.led.size() == 2)
	check(two.size() == 1 and "%d/%d" % [hall.haulers_free(), hall.haulers().size()] == "1/2", "close together: one hauler leads both (counter 1/2)")
	await wait_for(func() -> bool: return haulers().all(func(u: Unit) -> bool: return u.haul_job.is_empty()), 50.0)
	check(haulers().all(func(u: Unit) -> bool: return u.haul_job.is_empty()), "…delivers both and goes home")
	await wait_for(func() -> bool: return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cuirassier" and not u.dead).size() == 2, 70.0)
	for r in g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cuirassier"):
		g.consume_unit(r)


# ---------------------------------------------------------------- 4. interrupted trips

func _interrupt() -> void:
	await _clear_horses()
	var h1 := unit("horse", br.center() + Vector2(-170, 110))
	h1.graze_at = h1.position
	g.train(bar, "horseman")
	var rid := int(bar.kit_at(0).get("rid", 0))
	await wait_for(func() -> bool: return h1.leader != null, 15.0)
	var first: Unit = h1.leader
	check(first != null and h1.horse_rid == rid, "a hauler has the horse kept for the Horseman")
	var n_before: int = haulers().size()
	first.cmd_move(at(500, 700))              # the player orders him away
	await physics_frame
	check(h1.leader == null and h1.claimed != first and h1.horse_rid == rid, "ordered away: the leash is let go, the reservation stays")
	check(haulers().size() == n_before - 1 and not first.is_hauler(), "…and he is no longer a hauler (%d/%d)" % [hall.haulers_free(), haulers().size()])
	await wait_for(func() -> bool: return h1.leader != null and h1.leader != first, 15.0)
	var second: Unit = h1.leader
	check(second != null and second != first and second.is_hauler(), "the other hauler takes the horse instead")
	# killed mid-trip
	second.take_damage(99999.0, g.units[0])
	await physics_frame
	check(second.dead and h1.leader == null and h1.claimed != second and h1.horse_rid == rid, "hauler killed: the horse is let go, still reserved")
	check(g.reserved_horse(0, rid) == h1, "…and still kept for its Horseman")
	check(haulers().is_empty(), "no haulers left")
	assign([first])
	await wait_for(func() -> bool: return h1.leader == first or h1.into == bar, 20.0)
	check(h1.leader == first or h1.into == bar or not is_instance_valid(h1), "re-assigned, he fetches it again")
	await wait_for(func() -> bool: return first.haul_job.is_empty(), 40.0)
	g.cancel_train(bar)
	await _clear_horses()
	# a second hauler for the later tests
	var extra := labourer(hall.center() + Vector2(0, 150))
	assign([extra])
	check(haulers().size() == 2, "two haulers again")


# ---------------------------------------------------------------- 5. kegs

func _kegs() -> void:
	await _clear_horses()
	# farm and mill workers
	var fw: Array = []
	var mw: Array = []
	for i in 3:
		var f := labourer(farm.center() + Vector2(i * 20, 80))
		f.cmd_gather(farm)
		fw.append(f)
		var m := labourer(mill.center() + Vector2(i * 20, 60))
		m.cmd_gather(mill)
		mw.append(m)
	await wait(2.0)
	var wagon := unit("powder_wagon", at(480, 500))
	wagon.powder = 0.0
	wagon.set_supply(true)
	check(wagon._powder_building() == null, "the wagon is out in the field (no filling building near)")
	var bank0: float = float(g.players[0]["res2"])
	var picked := {}
	var farm_ok := true
	for i in 1500:
		await physics_frame
		for h in haulers():
			if h.keg:
				picked[h.get_instance_id()] = true
		for f in fw:
			if f.keg or f.order != "gather" or f.home_mine != farm:
				farm_ok = false
		for m in mw:
			if m.keg or m.order != "gather" or m.home_mine != mill:
				farm_ok = false
		if wagon.powder >= 60.0:
			break
	check(wagon.powder >= 30.0, "kegs reached the wagon (%d shots)" % int(wagon.powder))
	check(picked.size() == 2, "two haulers each carried a keg (never more than the room: %d carriers)" % picked.size())
	check(farm_ok, "farm and mill workers stayed at their posts, none carried a keg")
	check(farm.crew.size() == 3 and mill.crew.size() == 3, "crews unchanged (farm %d, mill %d)" % [farm.crew.size(), mill.crew.size()])
	check(float(g.players[0]["res2"]) < bank0, "kegs are paid from the powder bank (%.0f -> %.0f)" % [bank0, float(g.players[0]["res2"])])
	await wait_for(func() -> bool: return wagon.powder >= 120.0 or haulers().all(func(u: Unit) -> bool: return u.haul_job.is_empty()), 120.0)
	check(wagon.powder <= wagon.max_powder() + 0.1, "never over the store (%d/%d)" % [int(wagon.powder), int(wagon.max_powder())])
	await wait_for(func() -> bool: return haulers().all(func(u: Unit) -> bool: return u.haul_job.is_empty() and not u.keg), 60.0)
	check(haulers().all(func(u: Unit) -> bool: return u.haul_job.is_empty() and not u.keg), "haulers are home with empty hands")
	# a hauler pulled off mid-run puts the keg back
	wagon.powder = 0.0
	await wait_for(func() -> bool: return haulers().any(func(u: Unit) -> bool: return u.keg), 40.0)
	var carrier: Unit = null
	for h in haulers():
		if h.keg:
			carrier = h
	var bank1: float = float(g.players[0]["res2"])
	if carrier:
		carrier.cmd_move(at(700, 100))
		await physics_frame
		check(not carrier.keg and float(g.players[0]["res2"]) > bank1, "ordered away with a keg: it goes back into the stores")
		assign([carrier])
	# the wagon stops needing: SUPPLY off, no more runs
	wagon.set_supply(false)
	await wait(2.0)
	g.consume_unit(wagon)
	for u in fw + mw:
		g.consume_unit(u)
	await wait(3.0)
	check(haulers().all(func(u: Unit) -> bool: return not u.keg), "wagon gone: nobody keeps a keg")


# ---------------------------------------------------------------- 6. a gun's horse

func _gun() -> void:
	await _clear_horses()
	for h in haulers():
		h.haul_job = {}
	var sp := unit("horse", br.center() + Vector2(-120, 130))
	sp.graze_at = sp.position
	await physics_frame
	check(g.train(fdy, "cannon") == "", "CANNON queued (%s)" % g.can_train(fdy, "cannon"))
	var rid := int(fdy.kit_at(0).get("rid", 0))
	check(rid != 0 and sp.horse_rid == rid, "the spare is kept for it")
	await physics_frame
	check(sp.into == null, "the horse does not walk off by itself with haulers about")
	await wait_for(func() -> bool: return sp.leader != null, 15.0)
	check(sp.leader != null and (sp.leader as Unit).is_hauler(), "a hauler leads it")
	await wait_for(func() -> bool: return sp.into == fdy or fdy.kit_at(0).has("coat"), 40.0)
	check(sp.into == fdy or fdy.kit_at(0).has("coat") or not is_instance_valid(sp), "…and hitches it at the Foundry")
	var cn := func() -> Array: return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cannon" and not u.dead)
	await wait_for(func() -> bool: return not cn.call().is_empty(), 60.0)
	check(not cn.call().is_empty(), "the gun rolls out with its horse")
	for c in cn.call():
		# the gun asks for a team: a hauler brings a spare
		var sp2 := unit("horse", br.center() + Vector2(-100, 120))
		sp2.graze_at = sp2.position
		c.position = hall.center() + Vector2(120, 210)
		c.team_want = 2
		await wait_for(func() -> bool: return c.horse_count() == 2, 50.0)
		check(c.horse_count() == 2, "team_want 2: a hauler brought the second horse (%d)" % c.horse_count())
		g.consume_unit(c)


# ---------------------------------------------------------------- 6b. save and load

func _save_load() -> void:
	await _clear_horses()
	var n: int = haulers().size()
	SaveGame.save(g, {"map": "random", "seed": 4242})
	var d := SaveGame.peek()
	SaveGame.restore(g, d)
	await physics_frame
	for b in g.buildings:
		if b.team == 0 and b.kind == "town_hall" and not b.dead and b.cell == origin + Vector2i(1, 1):
			hall = b
		elif b.team == 0 and b.kind == "barracks" and not b.dead:
			bar = b
		elif b.team == 0 and b.kind == "foundry" and not b.dead:
			fdy = b
		elif b.team == 0 and b.kind == "horse_breeder" and not b.dead:
			br = b
	await physics_frame
	check(n >= 1 and hall.haulers().size() == n, "saved and loaded: the Town Hall still has its %d haulers (%d)" % [n, hall.haulers().size()])
	SaveGame.clear()


# ---------------------------------------------------------------- 7. no hauler

func _fallback() -> void:
	await _clear_horses()
	for h in haulers():
		h.cmd_stop()
	await physics_frame
	check(haulers().is_empty() and not g.hauler_serves(0), "no haulers assigned")
	# a rider fetches his own horse
	check(g.train(bar, "horseman") == "", "HORSEMAN queued")
	var rid := int(bar.kit_at(0).get("rid", 0))
	var foot := func() -> Array: return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "dismounted" and u.horse_rid == rid)
	await wait_for(func() -> bool: return not foot.call().is_empty(), 50.0)
	check(foot.call().size() == 1, "he comes out on foot, going for his horse")
	var riders := func() -> Array: return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cuirassier" and not u.dead)
	await wait_for(func() -> bool: return not riders.call().is_empty(), 40.0)
	check(not riders.call().is_empty(), "no hauler: he walked to the Breeder, got on, and rode")
	for r in riders.call():
		g.consume_unit(r)
	await _clear_horses()
	# a gun's horse walks over by itself
	var sp := unit("horse", br.center() + Vector2(-120, 130))
	sp.graze_at = sp.position
	await physics_frame
	g.train(fdy, "cannon")
	check(sp.into == fdy, "no hauler: a gun's horse walks to the Foundry by itself")
	var cn := func() -> Array: return g.units.filter(func(u: Unit) -> bool: return u.team == 0 and u.kind == "cannon" and not u.dead)
	await wait_for(func() -> bool: return not cn.call().is_empty(), 80.0)
	check(not cn.call().is_empty(), "…and the gun rolls out")
	# a hauler that never comes (all busy / unreachable) is waited for only so long
	var late := labourer(hall.center() + Vector2(0, 120))
	assign([late])
	late.begin_haul({"k": "keg", "ph": "to_mill", "wagon": null})   # (busy with something else for good)
	late.haul_job["ph"] = "to_mill"
	late.haul_job["wagon"] = unit("powder_wagon", at(700, 100))
	await _clear_horses()
	var sp3 := unit("horse", br.center() + Vector2(-120, 130))
	sp3.graze_at = sp3.position
	await physics_frame
	g.train(fdy, "cannon")
	check(sp3.into == null, "a busy hauler is about: the horse waits for him at first")
	g._rid_wait[sp3.horse_rid] = 99.0
	check(not g.hauler_serves_rid(0, sp3.horse_rid), "…but not for ever (after %d s it goes by itself)" % int(Defs.HAUL["stale"]))
	g.fetch_reserved(fdy, 0)
	check(sp3.into == fdy, "the stale reservation is fetched by the horse itself")
