extends SceneTree
## The cliff drawing (game.gd _render_ground) must never change the map itself: for every
## named map the height map, cliff cells, ramps and passability (solid) hash to the values
## recorded on main before the cliff work (re-recorded after the tree and rock thinning, which changes `solid`, for the bigger maps of 0.15.0, and for the ramp funnels of 0.15.2 and 0.15.3, which in 0.15.3
## change only `solid`: docs/ramp_funnel.md).
##   godot --headless --script res://tools/test_terrain_same.gd           (checks)
##   godot --headless --script res://tools/test_terrain_same.gd -- record (prints a fresh table)
const HASHES := {
	"ashford_crossing": 57634949782959946,
	"kestrel_rise": 8112362231298935,
	"thornwood_maze": 58158191696373368,
	"redrock_canyon": 17730760160973845,
	"saltmarsh_isles": 56662963320587730,
	"glimmerdeep": 43838494978274017,
	"frostmere": 39104419713066326,
	"cinder_steps": 54821170952227780,
	"hollowfen": 32819180609847611,
	"amberfall_vale": 87688717094654,
	"twin_crowns": 59870995779944258,
	"jade_wilds": 7535621342270837,
	"shattered_coast": 46486758386139366,
	"ember_reach": 61011874605686131,
	"whitecap_pass": 37422135294035728,
	"kingsfield": 50217660882147222,
	"pinewall_marches": 71491316635778114,
	"sundered_realm": 55422619810585474,
	"greenhold": 27928086971046961,
	"highmoor": 47506519190171519,
	"dune_sea": 8511823825813415,
	"frostfang": 49666251348685466,
	"twin_fords": 65006130829491419,
	"ashfall": 32690440179943398,
	"mirewood": 14677240389006586,
	"border_march": 28417626846297477,
	"red_coast": 48357475426414004
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
