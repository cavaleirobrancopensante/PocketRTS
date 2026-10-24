extends SceneTree
## The cliff drawing (game.gd _render_ground) must never change the map itself: for every
## named map the height map, cliff cells, ramps and passability (solid) hash to the values
## recorded on main before the cliff work (re-recorded after the tree and rock thinning, which changes `solid`).
##   godot --headless --script res://tools/test_terrain_same.gd           (checks)
##   godot --headless --script res://tools/test_terrain_same.gd -- record (prints a fresh table)
const HASHES := {
	"ashford_crossing": 21127261170301842,
	"kestrel_rise": 121070159463820,
	"thornwood_maze": 53273085444550735,
	"redrock_canyon": 63765906812682953,
	"saltmarsh_isles": 3373217922627904,
	"glimmerdeep": 17698455545535844,
	"frostmere": 23194935201241691,
	"cinder_steps": 71025100548959507,
	"hollowfen": 18114729844896497,
	"amberfall_vale": 41711374298363396,
	"twin_crowns": 21183110829599356,
	"jade_wilds": 68398800195243569,
	"shattered_coast": 71738383790403050,
	"ember_reach": 70196919186014510,
	"whitecap_pass": 538643375216470,
	"kingsfield": 24438996543352092,
	"pinewall_marches": 65401966238469119,
	"sundered_realm": 23894700769075698,
	"greenhold": 45120068248564440,
	"highmoor": 66586796606739732,
	"dune_sea": 29916644938338296,
	"frostfang": 64169907657876533,
	"twin_fords": 7442931970561508,
	"ashfall": 43804998276487882,
	"mirewood": 46504888983627315,
	"border_march": 22256288697890725,
	"red_coast": 39931084460171418
}


func _initialize() -> void:
	_run.call_deferred(OS.get_cmdline_user_args())


func _run(args: Array) -> void:
	var record := args.has("record")
	var fails := 0
	var ids: Array = MapData.NAMED.keys() + MapGen.MAPS.keys()
	for id in ids:
		var n := maxi(MapGen.max_players(id), 2)
		var g := Game.new()
		g.map_id = id
		g.demo = true
		g.rng.seed = 4242
		g.edit_mode = true
		var facs: Array = []
		var sides: Array = []
		for i in n:
			facs.append("crown")
			sides.append(0 if i < n / 2 else 1)
		g.factions = facs
		g.sides = sides
		root.add_child(g)
		await process_frame
		var buf := PackedByteArray()
		buf.append_array(g.height)
		buf.append_array(g.ramp)
		buf.append_array(g.cliff)
		buf.append_array(g.solid)
		var h := hash_bytes(buf)
		if record:
			print('\t"%s": %d,' % [id, h])
		else:
			var ok: bool = HASHES.get(id, -1) == h
			print(("PASS  " if ok else "FAIL  ") + "%s terrain hash %d" % [id, h])
			if not ok:
				fails += 1
		g.queue_free()
		await process_frame
	if not record:
		print("%d failures" % fails)
	quit(1 if fails > 0 else 0)


func hash_bytes(b: PackedByteArray) -> int:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(b)
	var d := c.finish()
	var v := 0
	for i in 7:
		v = (v << 8) | d[i]
	return v
