extends SceneTree
## The cliff drawing (game.gd _render_ground) must never change the map itself: for every
## named map the height map, cliff cells, ramps and passability (solid) hash to the values
## recorded on main before the cliff work (re-recorded after the tree and rock thinning, which changes `solid`, for the bigger maps of 0.15.0, and for the ramp funnels of 0.15.1:
## docs/ramp_funnel.md).
##   godot --headless --script res://tools/test_terrain_same.gd           (checks)
##   godot --headless --script res://tools/test_terrain_same.gd -- record (prints a fresh table)
const HASHES := {
	"ashford_crossing": 11557449087377653,
	"kestrel_rise": 46366436248167375,
	"thornwood_maze": 37438021989680634,
	"redrock_canyon": 158130199967881,
	"saltmarsh_isles": 29559847889917568,
	"glimmerdeep": 12971045699659724,
	"frostmere": 6927435123531186,
	"cinder_steps": 53166151346309966,
	"hollowfen": 47292653965100484,
	"amberfall_vale": 40547778815706763,
	"twin_crowns": 58451772097581279,
	"jade_wilds": 65435416449492597,
	"shattered_coast": 7324553233203083,
	"ember_reach": 20062591519634619,
	"whitecap_pass": 4182228246553748,
	"kingsfield": 14625731985820171,
	"pinewall_marches": 32898450522424254,
	"sundered_realm": 8938596186149017,
	"greenhold": 50702319689320002,
	"highmoor": 59778009627356119,
	"dune_sea": 38694548408481365,
	"frostfang": 35783003768186940,
	"twin_fords": 42795262379287057,
	"ashfall": 16664514057165212,
	"mirewood": 56832849517022092,
	"border_march": 34421415259470636,
	"red_coast": 57565557852955430
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
