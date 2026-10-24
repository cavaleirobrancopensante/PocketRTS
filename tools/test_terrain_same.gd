extends SceneTree
## The cliff drawing (game.gd _render_ground) must never change the map itself: for every
## named map the height map, cliff cells, ramps and passability (solid) hash to the values
## recorded on main before the cliff work.
##   godot --headless --script res://tools/test_terrain_same.gd           (checks)
##   godot --headless --script res://tools/test_terrain_same.gd -- record (prints a fresh table)
const HASHES := {
	"ashford_crossing": 18130404140479371,
	"kestrel_rise": 3570367302509629,
	"thornwood_maze": 53946565229260165,
	"redrock_canyon": 42637678294719279,
	"saltmarsh_isles": 36020079369159367,
	"glimmerdeep": 2266455306337709,
	"frostmere": 12191480876104671,
	"cinder_steps": 42957521223102078,
	"hollowfen": 65024561305190868,
	"amberfall_vale": 10451705983043408,
	"twin_crowns": 67568351483748213,
	"jade_wilds": 7831534872228686,
	"shattered_coast": 69422475289896015,
	"ember_reach": 29965780655301933,
	"whitecap_pass": 4763646460405404,
	"kingsfield": 50625282378810397,
	"pinewall_marches": 37313897230606705,
	"sundered_realm": 36174518075392678,
	"greenhold": 6942670009491294,
	"highmoor": 48821132044022361,
	"dune_sea": 45651151041086531,
	"frostfang": 16079832465285447,
	"twin_fords": 67122151329691650,
	"ashfall": 43661798824384973,
	"mirewood": 45588097752198223,
	"border_march": 48150681045411504,
	"red_coast": 42999835823625162,
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
