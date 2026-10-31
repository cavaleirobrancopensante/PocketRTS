extends SceneTree
## BROOD DISTANCE PAY (brood-far, 0.24.22; docs/brood_new.md "0.24.22 distance pay"). Nobody fights; the Crown side
## is idle and the computers are off.
##   godot --headless --fixed-fps 30 --script res://tools/measure_brood_far.gd -- [map:dune_sea] [seed:1] [d:14] [warm:30] [secs:120]
## One Rootmaw rooted `d` tiles from the Brood Mother (under 9: her own starting one; else a new one, with a rooted
## Mound Turtle beside it for swamp when it is off hers, and her own one's ground emptied), a FULL crew of fresh grubs
## (BroodNew.crew_max). One line: "FAR d=.. crew=.. mult=.. food/min=.. (the steady `secs` after `warm`) per grub=..
## emptied 3,000 in m:ss" (it runs until the Rootmaw's ground and body are empty).
##   ... -- plan:8@0,12@120,21@240,29@420 [secs:900]
## A HUMAN-STYLE build instead: a Rootmaw at each distance (tiles) at each time (s; under 9 tiles = the Mother's own),
## each topped up to a full crew of fresh grubs; a line a minute "PLAN m:00 food <delivered so far> grubs <n>".
var main: Node
var g
var t := 0.0
var opt := {"map": "dune_sea", "seed": "1", "d": "14", "secs": "120", "warm": "30"}
var started := false
var maw = null
var t0 := -1.0
var got0 := 0.0
var got1 := -1.0
var t1 := 0.0
var got := 0.0          # food delivered by the grubs
var crew: Array = []
var plan: Array = []          # [[time, tiles], ...] (plan mode)
var next_min := 60.0
var born := 0.0
var empty_t := -1.0


func _initialize() -> void:
	Settings.load_all()
	Settings.device = "pc"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		var kv := a.split(":", true, 1)
		if kv.size() == 2:
			opt[kv[0]] = kv[1]


func _spot(k: String, p: Vector2, tiles: float, swamp: bool) -> Vector2:
	for r in [tiles, tiles + 0.5, tiles - 0.5, tiles + 1.0, tiles - 1.0, tiles + 1.5, tiles - 1.5]:
		for i in 48:
			var s: Vector2 = BroodRoot.snap(k, p + Vector2.from_angle(TAU * i / 48.0) * maxf(r, 0.0) * Defs.TILE)
			if g.region_of(g.cell_of(s)) == BroodRoot.home_region(g, p) and BroodRoot.place_problem(g, 0, k, s, null, false, 1.0, swamp) == "":
				return s
	return Vector2.INF


func _root_now(k: String, p: Vector2):
	var u = BroodRoot.cocoon(g, 0, k, p)
	u.nb.erase("coc")
	BroodNew.recount(g, 0)
	return u


func _crew_up(m, q) -> void:
	var have := BroodNew.crew(g, m)
	for i in maxi(0, BroodNew.crew_max(g, m) - have):
		var gr = g._add_unit("grub", 0, q.position + Vector2(0, BroodRoot.rect_of(q).size.y * 0.5 + 20.0) + Vector2(i * 10 - 40, 0))
		gr.cmd_gather(m)
		crew.append(gr)


## A Rootmaw (and, off her swamp, a Mound Turtle beside it) `d` tiles from her, its circle clear of the others'.
func _plant(d: float):
	var q := BroodNew.queen(g, 0)
	var p := _spot(BroodNew.MAW, q.position, d, true)
	if p == Vector2.INF:
		# a Mound Turtle on the ring (its swamp), the Rootmaw beside it at about the same distance from her
		var home := BroodRoot.home_region(g, q.position)
		for r in [d, d + 2.0, d - 2.0, d + 4.0, d - 4.0]:
			for i in 48:
				var tp: Vector2 = BroodRoot.snap(BroodNew.TURTLE, q.position + Vector2.from_angle(TAU * i / 48.0) * r * Defs.TILE)
				if g.region_of(g.cell_of(tp)) != home or BroodRoot.place_problem(g, 0, BroodNew.TURTLE, tp, null, false, 1.0, false) != "":
					continue
				var best := Vector2.INF
				for j in 24:
					for rr in [4.0, 5.5, 7.0]:
						var mp: Vector2 = BroodRoot.snap(BroodNew.MAW, tp + Vector2.from_angle(TAU * j / 24.0) * rr * Defs.TILE)
						if absf(mp.distance_to(q.position) / Defs.TILE - d) > 1.5 or g.region_of(g.cell_of(mp)) != home:
							continue
						if BroodRoot.place_problem(g, 0, BroodNew.MAW, mp, null, false, 1.0, false) == "" and (BroodRoot.rect_for(BroodNew.TURTLE, tp).grow(4.0)).intersects(BroodRoot.rect_for(BroodNew.MAW, mp)) == false:
							best = mp
							break
					if best != Vector2.INF:
						break
				if best != Vector2.INF:
					_root_now(BroodNew.TURTLE, tp)
					g._update_swamp()
					p = best
					break
			if p != Vector2.INF:
				break
	if p == Vector2.INF:
		return null
	var m = _root_now(BroodNew.MAW, p)
	m.nb["food"] = 0.0
	return m


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(int(opt["seed"]))
		main.start({"map": opt["map"], "seed": int(opt["seed"]), "slots": [
			{"who": "you", "faction": "brood", "colour": 0, "side": 0},
			{"who": "you", "faction": "crown", "colour": 1, "side": 1}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	var q := BroodNew.queen(g, 0)
	if q == null:
		return false
	if not started:
		started = true
		for ai in g.ais:
			ai.process_mode = Node.PROCESS_MODE_DISABLED
		for u in g.units:
			if u.team == 0 and u.kind == "grub":
				crew.append(u)
		if opt.has("plan"):
			for it in String(opt["plan"]).split(","):
				var kv := it.split("@")
				plan.append([float(kv[1]), float(kv[0])])
			return false
		var start_maw = null
		for u in g.units:
			if u.team == 0 and u.kind == BroodNew.MAW:
				start_maw = u
		if float(opt["d"]) < 9.0:
			maw = start_maw          # (the Mother's own: about 8.5 tiles)
		else:
			for u in crew:
				u.cmd_stop()
			start_maw.nb["food"] = 0.0
			g.nb_spots[int(start_maw.nb["spot"])]["left"] = 0.0      # (out of the way: only ours pays)
			maw = _plant(float(opt["d"]))
			if maw == null:
				print("FAR d=%s no spot" % opt["d"])
				quit()
				return false
			maw.nb["food"] = float(Defs.NB["start_food"])
		born = g.clock
		_crew_up(maw, q)
		return false
	# delivered: every grub's loads as they land (load_f drops to 0 at the Mother)
	for gr in crew:
		if not is_instance_valid(gr):
			continue
		var lf: float = float(gr.get_meta("lf", 0.0))
		if lf > 0.0 and gr.load_f <= 0.0 and gr.carrying == 0:
			got += lf
		gr.set_meta("lf", gr.load_f)
	if opt.has("plan"):
		while not plan.is_empty() and g.clock >= float(plan[0][0]):
			var d := float(plan[0][1])
			plan.pop_front()
			var m = null
			if d < 9.0:
				for u in g.units:
					if u.team == 0 and u.kind == BroodNew.MAW:
						m = u
						break
			else:
				m = _plant(d)
			if m:
				_crew_up(m, q)
				print("  %d:%02d Rootmaw at %.1f tiles, crew %d" % [int(g.clock) / 60, int(g.clock) % 60, q.position.distance_to(m.position) / Defs.TILE, BroodNew.crew_max(g, m)])
			else:
				print("  no spot at %.0f tiles" % d)
		if g.clock >= next_min:
			next_min += 60.0
			var grubs := 0
			for u in g.workers(0):
				grubs += 1
			print("PLAN %2d:00 food %d grubs %d" % [int(round(g.clock / 60.0)), int(got), grubs])
		if g.clock >= float(opt["secs"]):
			quit()
		return false
	var warm := float(opt["warm"])
	if t0 < 0.0 and g.clock > born + warm:
		t0 = g.clock
		got0 = got
	if t0 >= 0.0 and g.clock >= t0 + float(opt["secs"]) and got1 < 0.0:
		got1 = got
		t1 = g.clock
	if empty_t < 0.0 and BroodNew.ground_left(g, maw) < 1.0 and float(maw.nb.get("food", 0.0)) < 1.0:
		empty_t = g.clock - born
	if (got1 >= 0.0 and empty_t >= 0.0) or g.clock > born + 1500.0:
		var dd: float = q.position.distance_to(maw.position) / Defs.TILE
		var per_min: float = (got1 - got0) / maxf(1.0, t1 - t0) * 60.0
		print("FAR d=%.1f crew=%d mult=%.2f load=%.1f food/min=%.0f per grub=%.1f emptied 3,000 in %s" % [
			dd, BroodNew.crew_max(g, maw), 1.0 + Defs.FOOD_BONUS * clampf((minf(dd, Defs.FOOD_MAX_D) - Defs.FOOD_NEAR) / (Defs.FOOD_FAR - Defs.FOOD_NEAR), 0.0, 1.0), BroodNew.load_value(g, maw, 0), per_min, per_min / maxf(1.0, BroodNew.crew_max(g, maw)),
			"%d:%02d" % [int(empty_t) / 60, int(empty_t) % 60] if empty_t >= 0.0 else "(not in 25 min)"])
		quit()
	return false
