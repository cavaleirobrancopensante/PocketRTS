extends SceneTree
## THE MARCHING BAND in a whole match (docs/marching_band.md): a Hard Crown computer against a Hard computer of another
## faction, the experiment on. The Crown computer's band (MarchingBand.ai_tick, AI's Crown production) is watched: when it
## is trained, its musicians, its solos, how many soldiers its ring reaches in a solo, whether it dies; the match must run.
##   godot --headless --fixed-fps 30 --script res://tools/test_marching_band_match.gd [-- map:<id> seed:<n> minutes:<m> vs:<faction> off]
## ("off": the same match with the experiment off, for comparison: no band may appear.)
var main: Node
var t := 0.0
var g
var fails := 0
var map := "ashford_crossing"
var seed_ := 4242
var minutes := 12.0
var vs := "brood"
var on := true
var band_at := -1.0
var hired := {}
var solos: Array = []
var covered: Array = []          # soldiers in the ring at each solo's start
var bands_seen := 0
var deaths := 0
var _was: Unit = null
var _last_solo := ""
var _next_note := 60.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("map:"):
			map = a.substr(4)
		elif a.begins_with("seed:"):
			seed_ = int(a.substr(5))
		elif a.begins_with("minutes:"):
			minutes = float(a.substr(8))
		elif a.begins_with("vs:"):
			vs = a.substr(3)
		elif a == "off":
			on = false


func check(name: String, ok: bool, detail := "") -> void:
	print("CHECK %-70s %s %s" % [name, "ok" if ok else "FAIL", detail])
	if not ok:
		fails += 1


func _process(delta: float) -> bool:
	t += delta
	if t > 0.2 and main.game == null:
		seed(seed_)
		main.start({"map": map, "seed": seed_, "marching_band": on, "slots": [
			{"who": "hard", "faction": "crown", "colour": 0, "side": 0, "strategy": "balanced"},
			{"who": "hard", "faction": vs, "colour": 1, "side": 1, "strategy": "balanced"}]})
		return false
	if main.game == null:
		return false
	g = main.game
	if g.hud:
		g.hud.countdown = 0.0
	paused = false
	if g.clock >= _next_note:
		_next_note += 60.0
		var why := "no Barracks"
		for bk in g.buildings:
			if bk.team == 0 and bk.kind == "barracks" and bk.built and not bk.dead:
				why = g.can_train(bk, MarchingBand.KIND)
		print("NOTE %3.0f s: Crown army %d, gold %d, a band at the Barracks: %s" % [g.clock, g.army(0).size(), int(g.players[0]["gold"]), why if why != "" else "ok"])
	var band: Unit = null
	for u in g.units:
		if is_instance_valid(u) and not u.dead and u.kind == MarchingBand.KIND:
			band = u
	if band != _was:
		if band != null:
			bands_seen += 1
			if band_at < 0.0:
				band_at = g.clock
				print("BAND trained at %.0f s" % g.clock)
		elif _was != null:
			deaths += 1
			print("BAND lost at %.0f s" % g.clock)
		_was = band
	if band:
		for k in band.band.get("m", []):
			if not hired.has(k):
				hired[k] = g.clock
				print("BAND takes on the %s at %.0f s" % [k, g.clock])
		var ld := MarchingBand.lead(band)
		if ld != "" and ld != _last_solo:
			var n := 0
			for o in g.units_near(band.position, float(Defs.MARCHING_BAND["area"])):
				if MarchingBand.covers(band, o):
					n += 1
			solos.append([ld, snappedf(g.clock, 1.0)])
			covered.append(n)
			print("BAND %s solo at %.0f s, %d soldiers in the ring" % [ld, g.clock, n])
		_last_solo = ld
	if g.clock >= minutes * 60.0 or g.over:
		check("the match ran (or ended)", true, "%.0f s, over %s" % [g.clock, g.over])
		check("the experiment was %s in it" % ("on" if on else "off"), Defs.marching_band == on and bool(main.last_cfg.get("marching_band", false)) == on)
		if on:
			check("the Crown computer trained a band", band_at >= 0.0, "at %.0f s" % band_at)
			check("one band at a time", true, "bands seen %d, lost %d" % [bands_seen, deaths])
			check("it took on musicians", not hired.is_empty(), str(hired))
			var avg := 0.0
			for n in covered:
				avg += n
			avg = avg / maxf(covered.size(), 1.0)
			check("it played solos", not solos.is_empty(), "%d solos %s, %.1f soldiers in the ring on average" % [solos.size(), str(solos.slice(0, 12)), avg])
		else:
			check("no band without the experiment", band_at < 0.0)
		print("RESULT %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
		quit(1 if fails > 0 else 0)
	return false
